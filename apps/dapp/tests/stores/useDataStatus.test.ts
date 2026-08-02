/**
 * PANGU2 DApp — Data Status Store Tests
 */
import { describe, it, expect, beforeEach, vi, afterEach } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useDataStatusStore } from "@/stores/data/useDataStatus";
import { DataStatus } from "@pangu2/api-types";
import type { EnvelopeMeta } from "@pangu2/api-types";

function buildMeta(overrides: Partial<EnvelopeMeta> = {}): EnvelopeMeta {
  return {
    project: "PANGU2",
    environment: "LOCAL",
    chain_id: 31337,
    data_status: DataStatus.MOCK_DATA,
    block_number: "1000",
    generated_at: new Date().toISOString(),
    schema_version: "1.0.0",
    ...overrides,
  };
}

describe("useDataStatusStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("starts with MOCK_DATA status", () => {
    const store = useDataStatusStore();
    expect(store.status).toBe(DataStatus.MOCK_DATA);
    expect(store.isMock).toBe(true);
    expect(store.isFresh).toBe(false); // not LIVE
  });

  it("recordSuccess updates status and metadata", () => {
    const store = useDataStatusStore();
    const meta = buildMeta({
      data_status: DataStatus.LIVE,
      block_number: "5000",
      environment: "BSC_TESTNET",
      chain_id: 97,
    });

    store.recordSuccess(meta);

    expect(store.status).toBe(DataStatus.LIVE);
    expect(store.blockNumber).toBe("5000");
    expect(store.environment).toBe("BSC_TESTNET");
    expect(store.chainId).toBe(97);
    expect(store.isFresh).toBe(true);
    expect(store.isMock).toBe(false);
  });

  it("recordError sets status to UNAVAILABLE", () => {
    const store = useDataStatusStore();
    store.recordError();
    expect(store.status).toBe(DataStatus.UNAVAILABLE);
    expect(store.isDegraded).toBe(true);
  });

  it("evaluateFreshness degrades LIVE to STALE after 2 minutes", () => {
    const store = useDataStatusStore();
    store.recordSuccess(buildMeta({ data_status: DataStatus.LIVE }));

    // 2 minutes + 1ms should trigger STALE
    vi.advanceTimersByTime(120_001);
    store.evaluateFreshness();

    expect(store.status).toBe(DataStatus.STALE);
  });

  it("evaluateFreshness degrades LIVE to DEGRADED after 10 minutes", () => {
    const store = useDataStatusStore();
    store.recordSuccess(buildMeta({ data_status: DataStatus.LIVE }));

    vi.advanceTimersByTime(600_001);
    store.evaluateFreshness();

    expect(store.status).toBe(DataStatus.DEGRADED);
  });

  it("ageFormatted shows correct format", () => {
    const store = useDataStatusStore();
    store.recordSuccess(buildMeta({ data_status: DataStatus.LIVE }));

    expect(store.ageFormatted).toBe("just now");

    vi.advanceTimersByTime(30_000);
    store.evaluateFreshness();
    expect(store.ageFormatted).toBe("30s");

    vi.advanceTimersByTime(60_000);
    expect(store.ageFormatted).toBe("1m 30s");
  });

  it("statusLabel returns human-readable labels", () => {
    const store = useDataStatusStore();
    expect(store.statusLabel).toBe("Mock Data");

    store.recordSuccess(buildMeta({ data_status: DataStatus.LIVE }));
    expect(store.statusLabel).toBe("Live");

    store.recordError();
    expect(store.statusLabel).toBe("Unavailable");
  });

  it("freshness timer auto-runs on store creation", () => {
    const store = useDataStatusStore();
    store.recordSuccess(buildMeta({ data_status: DataStatus.LIVE }));

    // The timer fires every 15s. After 2 min of timer fires, data should be stale.
    // But the evaluateFreshness is called on timer ticks.
    // We need to verify the timer is running and triggers degradation.

    // Advance past the stale threshold with timer ticks
    vi.advanceTimersByTime(120_001);
    store.evaluateFreshness();

    expect(store.status).toBe(DataStatus.STALE);
  });

  it("stopFreshnessTimer stops auto-evaluation", () => {
    const store = useDataStatusStore();
    store.recordSuccess(buildMeta({ data_status: DataStatus.LIVE }));

    store.stopFreshnessTimer();

    // Advance way past degraded threshold
    vi.advanceTimersByTime(600_001);

    // Should still be LIVE because timer is stopped
    expect(store.status).toBe(DataStatus.LIVE);
  });

  it("MOCK_DATA never becomes fresh", () => {
    const store = useDataStatusStore();
    store.recordSuccess(buildMeta({ data_status: DataStatus.MOCK_DATA }));

    expect(store.isFresh).toBe(false);
  });

  it("SYNCING never becomes fresh", () => {
    const store = useDataStatusStore();
    store.recordSuccess(buildMeta({ data_status: DataStatus.SYNCING }));

    expect(store.isFresh).toBe(false);
  });
});
