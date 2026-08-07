// PANGU2 Chain Worker — ABI Loader
// Loads compiled Foundry ABI files for event signature extraction.

import { resolve, isAbsolute } from "path";
import { readFileSync, existsSync } from "fs";

export interface AbiEntry {
  type: string;
  name?: string;
  inputs?: Array<{ name: string; type: string; indexed?: boolean }>;
  outputs?: Array<{ name: string; type: string }>;
  stateMutability?: string;
}

export interface AbiArtifact {
  abi: AbiEntry[];
  bytecode?: { object: string };
  deployedBytecode?: { object: string };
}

import { keccak256, toHex } from "viem";

/**
 * ABI directory pointing at Foundry build output (V2 contracts).
 *
 * Default resolves to <repo>/contracts-v2/out from __dirname.
 * Override via PANGU2_ABI_DIR for CI/Docker/staging.
 *
 * ⚠️  contracts-v2/out/ is .gitignored — new checkouts must build it first:
 *     cd contracts-v2 && forge build --lib-paths ../contracts/lib
 */
const DEFAULT_ABI_DIR = resolve(__dirname, "../../../../contracts-v2/out");

/** Resolve the ABI directory — lazy so env check doesn't block pure-type imports. */
export function getAbiDir(): string {
  const configuredDir = process.env.PANGU2_ABI_DIR?.trim();
  if (!configuredDir) return DEFAULT_ABI_DIR;
  if (!isAbsolute(configuredDir)) {
    throw new Error(
      `PANGU2_ABI_DIR must be an absolute path, got: ${configuredDir}`,
    );
  }
  return resolve(configuredDir);
}

/**
 * Contracts whose ABIs the chain-worker requires at startup.
 * Derived from STREAMS in event-scanner.ts — only contracts with active scan streams.
 * Add entries here when a new scan stream is added.
 */
export const REQUIRED_ABI_NAMES = [
  "Pangu2TradeRouter",
  "DividendDistributor",
  "Pangu2Staking",
  "BuybackLocker",
  "SupportPool",
  "FeeVault",
] as const;

/**
 * Load a Foundry-compiled ABI JSON file.
 * Returns parsed artifact or null if file doesn't exist.
 */
export function loadAbi(contractName: string): AbiArtifact | null {
  const path = resolve(getAbiDir(), `${contractName}.sol`, `${contractName}.json`);
  if (!existsSync(path)) {
    console.warn(`[ABI] Contract ABI not found: ${path}`);
    return null;
  }
  try {
    return JSON.parse(readFileSync(path, "utf-8")) as AbiArtifact;
  } catch (err) {
    console.error(`[ABI] Failed to parse ABI: ${path}`, err);
    return null;
  }
}

/**
 * Load all required ABIs.  Throws if any are missing or unparseable.
 * Use this at worker startup and in CI to enforce Fail Closed.
 */
export function loadRequiredAbis(): Map<string, AbiArtifact> {
  const loaded = new Map<string, AbiArtifact>();
  const failures: string[] = [];

  for (const name of REQUIRED_ABI_NAMES) {
    const artifact = loadAbi(name);
    if (!artifact) {
      failures.push(name);
      continue;
    }
    loaded.set(name, artifact);
  }

  if (failures.length > 0) {
    throw new Error(
      `REQUIRED_ABIS_UNAVAILABLE: ${failures.join(", ")}`,
    );
  }

  return loaded;
}

/**
 * Extract event signatures (topic0 hashes) from an ABI artifact.
 * Returns a Map of topic0 hex → event name.
 */
export function extractEventSignatures(abi: AbiArtifact): Map<string, string> {
  const signatures = new Map<string, string>();

  for (const entry of abi.abi) {
    if (entry.type !== "event" || !entry.name) continue;

    const paramTypes = (entry.inputs ?? []).map((i) => i.type).join(",");
    const sig = `${entry.name}(${paramTypes})`;
    // viem keccak256: returns 0x-prefixed hex
    const hash = keccak256(toHex(sig));
    signatures.set(hash, entry.name);
  }

  return signatures;
}

/**
 * Get event topic names for all required contracts.
 * Calls loadRequiredAbis() to enforce Fail Closed — worker must exit on missing ABIs.
 */
export function getAllEventSignatures(): {
  topicToName: Map<string, string>;
  nameToContract: Map<string, string>;
} {
  const topicToName = new Map<string, string>();
  const nameToContract = new Map<string, string>();

  const artifacts = loadRequiredAbis();

  for (const [name, artifact] of artifacts) {
    const sigs = extractEventSignatures(artifact);
    for (const [topic, eventName] of sigs) {
      topicToName.set(topic, eventName);
      nameToContract.set(eventName, name);
    }
  }

  return { topicToName, nameToContract };
}
