// ═══════════════════════════════════════════
// PANGU2 DApp — Composable for API data fetching
// Handles: loading / error / retry / refresh / cancellation
// ═══════════════════════════════════════════

import { ref, type Ref, onUnmounted } from "vue";
import type { EnvelopeMeta } from "@pangu2/api-types";
import { DataStatus } from "@pangu2/api-types";
import { apiClient, ApiError, NetworkError, SchemaVersionError, RequestCancelledError } from "@/api/client";
import type { ClientState } from "@/api/client";

export interface AsyncDataState<T> {
  data: T | null;
  meta: EnvelopeMeta | null;
  /** Current data status from the last successful response */
  dataStatus: DataStatus;
  isLoading: boolean;
  error: string | null;
  errorCode: string | null;
  errorRetryable: boolean;
  /** Number of consecutive failures for auto-retry logic */
  failureCount: number;
  /** Timestamp of last successful fetch */
  lastFetchedAt: number | null;
}

type FetchFn<T> = (signal: AbortSignal) => Promise<{ data: T; meta: EnvelopeMeta }>;

/**
 * Composable for async data with full lifecycle management.
 * Provides: loading state, error handling, retry, cancellation, freshness tracking.
 */
export function useAsyncData<T>(
  fetchFn: FetchFn<T>,
  options: {
    /** Auto-fetch on creation */
    immediate?: boolean;
    /** Auto-refresh interval in ms (0 = disabled) */
    refreshIntervalMs?: number;
  } = {},
) {
  const state = ref<AsyncDataState<T>>({
    data: null,
    meta: null,
    dataStatus: DataStatus.MOCK_DATA,
    isLoading: false,
    error: null,
    errorCode: null,
    errorRetryable: false,
    failureCount: 0,
    lastFetchedAt: null,
  });

  let controller: AbortController | null = null;
  let refreshTimer: ReturnType<typeof setInterval> | null = null;
  let requestVersion = 0;

  function cancel(): void {
    if (controller) {
      controller.abort();
      controller = null;
    }
  }

  async function execute(): Promise<boolean> {
    const version = ++requestVersion;
    cancel();

    controller = new AbortController();
    const signal = controller.signal;

    state.value.isLoading = true;
    state.value.error = null;
    state.value.errorCode = null;
    state.value.errorRetryable = false;

    try {
      const result = await fetchFn(signal);

      if (version !== requestVersion) return false;

      state.value.data = result.data;
      state.value.meta = result.meta;
      state.value.dataStatus = result.meta.data_status;
      state.value.lastFetchedAt = Date.now();
      state.value.failureCount = 0;
      state.value.isLoading = false;

      return true;
    } catch (err: unknown) {
      if (version !== requestVersion) return false;

      if (err instanceof RequestCancelledError || (err instanceof DOMException && err.name === "AbortError")) {
        state.value.isLoading = false;
        return false;
      }

      state.value.failureCount++;

      if (err instanceof ApiError) {
        state.value.error = err.message;
        state.value.errorCode = err.code;
        state.value.errorRetryable = err.retryable;
      } else if (err instanceof SchemaVersionError) {
        state.value.error = err.message;
        state.value.errorCode = "SCHEMA_VERSION_MISMATCH";
        state.value.errorRetryable = false;
      } else if (err instanceof NetworkError) {
        state.value.error = err.message;
        state.value.errorCode = "NETWORK_ERROR";
        state.value.errorRetryable = true;
      } else {
        state.value.error = err instanceof Error ? err.message : "Unknown error.";
        state.value.errorCode = "UNKNOWN";
        state.value.errorRetryable = false;
      }

      state.value.isLoading = false;
      state.value.dataStatus = DataStatus.UNAVAILABLE;

      return false;
    }
  }

  /** Retry the last fetch (max 3 attempts) */
  async function retry(): Promise<boolean> {
    if (state.value.failureCount > 3) {
      // Too many failures — reset counter so retry is fresh
      state.value.failureCount = 0;
    }
    return execute();
  }

  /** Force refresh (cancels current, executes new) */
  function refresh(): void {
    execute();
  }

  // Auto-fetch on creation
  if (options.immediate !== false) {
    execute();
  }

  // Auto-refresh interval
  if (options.refreshIntervalMs && options.refreshIntervalMs > 0) {
    refreshTimer = setInterval(() => {
      execute();
    }, options.refreshIntervalMs);
  }

  // Cleanup on unmount
  onUnmounted(() => {
    cancel();
    if (refreshTimer) clearInterval(refreshTimer);
  });

  return {
    state,
    execute,
    retry,
    refresh,
    cancel,
  };
}

/**
 * Quick helper: GET a path and return the data + meta.
 */
export async function fetchGet<T>(
  path: string,
  signal: AbortSignal,
): Promise<{ data: T; meta: EnvelopeMeta }> {
  return apiClient.get<T>(path, signal);
}

/**
 * Quick helper: POST to a path and return the data + meta.
 */
export async function fetchPost<T>(
  path: string,
  body: unknown,
  signal?: AbortSignal,
): Promise<{ data: T; meta: EnvelopeMeta }> {
  return apiClient.post<T>(path, body, signal);
}
