/**
 * PANGU2 DApp — API Client Tests
 */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { ApiError, SchemaVersionError, NetworkError, apiClient } from "@/api/client";

describe("ApiError", () => {
  it("has correct name and properties", () => {
    const err = new ApiError("test message", "TEST_CODE", 400, true);
    expect(err.name).toBe("ApiError");
    expect(err.message).toBe("test message");
    expect(err.code).toBe("TEST_CODE");
    expect(err.httpStatus).toBe(400);
    expect(err.retryable).toBe(true);
  });
});

describe("SchemaVersionError", () => {
  it("has correct name and message", () => {
    const err = new SchemaVersionError("0.9.0", "1.0.0");
    expect(err.name).toBe("SchemaVersionError");
    expect(err.message).toContain("0.9.0");
    expect(err.message).toContain("1.0.0");
    expect(err.received).toBe("0.9.0");
    expect(err.expected).toBe("1.0.0");
  });
});

describe("NetworkError", () => {
  it("has correct name", () => {
    const err = new NetworkError("offline");
    expect(err.name).toBe("NetworkError");
    expect(err.message).toBe("offline");
  });
});

describe("apiClient", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  describe("cancelAll", () => {
    it("cancels in-flight requests", async () => {
      // Start a request that we will abort
      const promise = apiClient.get("/v1/projects/pangu2/config");

      // Cancel it
      apiClient.cancelAll();

      await expect(promise).rejects.toThrow(NetworkError);
      await expect(promise).rejects.toThrow("cancelled");
    });
  });
});
