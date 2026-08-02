// PANGU2 Admin — P2-A04 Feature Tests
import { describe, it, expect, beforeEach, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";

// Mock fetch globally
vi.stubGlobal("fetch", vi.fn());

// Mock the admin auth store
vi.mock("@/stores/useAdminAuth", () => ({
  useAdminAuthStore: vi.fn(() => ({
    token: "test-token",
    isAuthenticated: true,
    role: "SUPER_ADMIN",
    checkSession: async () => true,
  })),
}));

describe("useEpochs", () => {
  it("starts with empty epochs and loading false", async () => {
    const { useEpochs } = await import("@/features/epochs/useEpochs");
    const eps = useEpochs();
    expect(eps.epochs.value).toEqual([]);
    expect(eps.tiers).toHaveLength(4);
    expect(eps.statusLabel("claim_open")).toBe("领取开放");
    expect(eps.statusLabel("closed")).toBe("已关闭");
    expect(eps.statusLabel("unknown")).toBe("unknown");
  });

  it("statusLabel returns correct Chinese labels", async () => {
    const { useEpochs } = await import("@/features/epochs/useEpochs");
    const eps = useEpochs();
    expect(eps.statusLabel("pending")).toBe("待快照");
    expect(eps.statusLabel("snapshot_complete")).toBe("快照完成");
    expect(eps.statusLabel("proof_generated")).toBe("Proof就绪");
  });
});

describe("useJobs", () => {
  it("starts with empty jobs array", async () => {
    const { useJobs } = await import("@/features/jobs/useJobs");
    const jp = useJobs();
    expect(jp.jobs.value).toEqual([]);
  });

  it("statusLabel maps correctly", async () => {
    const { useJobs } = await import("@/features/jobs/useJobs");
    const jp = useJobs();
    expect(jp.statusLabel("RUNNING")).toBe("运行中");
    expect(jp.statusLabel("FAILED")).toBe("失败");
    expect(jp.statusLabel("IDLE")).toBe("空闲");
    expect(jp.statusLabel("UNKNOWN")).toBe("UNKNOWN");
  });

  it("requestRetry sets retryConfirm", async () => {
    const { useJobs } = await import("@/features/jobs/useJobs");
    const jp = useJobs();
    jp.requestRetry("chain-sync");
    expect(jp.retryConfirm.value).toBe("chain-sync");
    jp.cancelRetry();
    expect(jp.retryConfirm.value).toBeNull();
  });
});

describe("useAudit", () => {
  it("starts with empty logs", async () => {
    const { useAudit } = await import("@/features/audit/useAudit");
    const ap = useAudit();
    expect(ap.logs.value).toEqual([]);
    expect(ap.page.value).toBe(1);
    expect(ap.resultLabel("SUCCESS")).toBe("成功");
    expect(ap.resultLabel("FAILED")).toBe("失败");
    expect(ap.resultLabel("UNKNOWN")).toBe("UNKNOWN");
  });
});
