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

const configuredDir = process.env.PANGU2_ABI_DIR?.trim();
let ABI_DIR: string;
if (configuredDir) {
  if (!isAbsolute(configuredDir)) {
    throw new Error(
      `PANGU2_ABI_DIR must be an absolute path, got: ${configuredDir}`,
    );
  }
  ABI_DIR = configuredDir;
} else {
  ABI_DIR = DEFAULT_ABI_DIR;
}

/** List of contracts whose ABIs the chain-worker depends on. Single source of truth. */
export const REQUIRED_ABI_NAMES = [
  "Pangu2TradeRouter",
  "DividendDistributor",
  "SupportPool",
  "BuybackLocker",
  "FeeVault",
  "Pangu2Token",
  "CostBasisManager",
] as const;

/**
 * Load a Foundry-compiled ABI JSON file.
 * Returns parsed artifact or null if file doesn't exist.
 */
export function loadAbi(contractName: string): AbiArtifact | null {
  const path = resolve(ABI_DIR, `${contractName}.sol`, `${contractName}.json`);
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
 * Get event topic names for all known contracts.
 */
export function getAllEventSignatures(): {
  topicToName: Map<string, string>;
  nameToContract: Map<string, string>;
} {
  const topicToName = new Map<string, string>();
  const nameToContract = new Map<string, string>();

  for (const name of REQUIRED_ABI_NAMES) {
    const abi = loadAbi(name);
    if (!abi) continue;

    const sigs = extractEventSignatures(abi);
    for (const [topic, eventName] of sigs) {
      topicToName.set(topic, eventName);
      nameToContract.set(eventName, name);
    }
  }

  return { topicToName, nameToContract };
}
