// ═══════════════════════════════════════════
// PANGU2 DApp — API Client
// Communicates with Mock Server via Vite proxy (localhost:4000)
// ═══════════════════════════════════════════

import type { Envelope, EnvelopeMeta } from "@pangu2/api-types";
import { DataStatus, isLive } from "@pangu2/api-types";

// ── Configuration ──────────────────────────

/** Matches the backend `schema_version`. Mismatch = hard fail. */
const REQUIRED_SCHEMA_VERSION = "1.0.0";

const BASE_URL = "/api";

// ── Error Types ────────────────────────────

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly httpStatus: number,
    public readonly retryable: boolean,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export class SchemaVersionError extends Error {
  constructor(public readonly received: string, public readonly expected: string) {
    super(
      `Schema version mismatch: received ${received}, expected ${expected}. ` +
        `Please refresh the page or check for updates.`
    );
    this.name = "SchemaVersionError";
  }
}

export class NetworkError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "NetworkError";
  }
}

// ── Client State ───────────────────────────

export interface ClientState {
  dataStatus: DataStatus;
  blockNumber: string | null;
  schemaVersion: string | null;
  freshnessTimestamp: number;
}

// ── Core Client ────────────────────────────

class Pangu2ApiClient {
  private controller: AbortController | null = null;

  /** Cancel all in-flight requests. */
  cancelAll(): void {
    if (this.controller) {
      this.controller.abort();
      this.controller = null;
    }
  }

  /**
   * Low-level request. Returns the unwrapped Envelope data.
   * Callers use the typed convenience methods instead.
   */
  async request<T>(
    path: string,
    options: RequestInit = {},
    signal?: AbortSignal,
  ): Promise<{ data: T; meta: EnvelopeMeta; envelope: Envelope<T> }> {
    const url = `${BASE_URL}${path}`;

    // Create or reuse an AbortController
    const ctrl = signal ? undefined : new AbortController();
    const sig = signal ?? ctrl?.signal;
    if (!signal && ctrl) this.controller = ctrl;

    let response: Response;
    try {
      response = await fetch(url, {
        ...options,
        signal: sig,
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          ...options.headers,
        },
      });
    } catch (err: unknown) {
      if (err instanceof DOMException && err.name === "AbortError") {
        throw new NetworkError("Request was cancelled.");
      }
      throw new NetworkError(
        err instanceof Error ? err.message : "Network request failed."
      );
    }

    // Parse envelope
    let envelope: Envelope<T>;
    try {
      envelope = (await response.json()) as Envelope<T>;
    } catch {
      throw new ApiError(
        "Failed to parse response.",
        "PARSE_ERROR",
        response.status,
        false,
      );
    }

    // Error envelope
    if (envelope.error) {
      throw new ApiError(
        envelope.error.message,
        envelope.error.code,
        response.status >= 400 ? response.status : 400,
        envelope.error.retryable,
      );
    }

    if (!response.ok) {
      throw new ApiError(
        "Request failed.",
        "HTTP_ERROR",
        response.status,
        response.status >= 500,
      );
    }

    // Schema version gate
    if (envelope.meta.schema_version !== REQUIRED_SCHEMA_VERSION) {
      throw new SchemaVersionError(
        envelope.meta.schema_version,
        REQUIRED_SCHEMA_VERSION,
      );
    }

    return { data: envelope.data, meta: envelope.meta, envelope };
  }

  // ── Convenience methods ────────────────────

  async get<T>(path: string, signal?: AbortSignal) {
    return this.request<T>(path, { method: "GET" }, signal);
  }

  async post<T>(path: string, body?: unknown, signal?: AbortSignal) {
    return this.request<T>(
      path,
      { method: "POST", body: body ? JSON.stringify(body) : undefined },
      signal,
    );
  }
}

export const apiClient = new Pangu2ApiClient();
