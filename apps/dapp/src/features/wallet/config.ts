// ═══════════════════════════════════════════
// PANGU2 DApp — Wagmi Configuration
// Single wagmi config shared by entire DApp.
// Supported chains: Anvil (local), BSC Testnet, BSC Mainnet
// ═══════════════════════════════════════════

import { createConfig, http } from "@wagmi/core";
import { anvil, bscTestnet, bsc } from "viem/chains";
import { injected } from "@wagmi/connectors";

export const wagmiConfig = createConfig({
  chains: [anvil, bscTestnet, bsc],
  connectors: [injected()],
  transports: {
    [anvil.id]: http(),
    [bscTestnet.id]: http("https://data-seed-prebsc-1-s1.binance.org:8545"),
    [bsc.id]: http(),
  },
});

/** Chain IDs the DApp officially supports for trading.
 *  Chain 56 (BSC Mainnet) is explicitly excluded — trading is NO-GO.
 *  Fork testing may reference mainnet state but never broadcasts mainnet transactions. */
export const SUPPORTED_CHAIN_IDS: readonly number[] = [
  anvil.id,      // 31337 — local dev
  bscTestnet.id, // 97    — BSC Testnet
] as const;

/** Map chain ID → human-readable label. */
export const CHAIN_LABELS: Record<number, { name: string; env: string }> = {
  [anvil.id]: { name: "Anvil", env: "LOCAL" },
  [bscTestnet.id]: { name: "BSC Testnet", env: "BSC_TESTNET" },
  [bsc.id]: { name: "BSC Mainnet", env: "MAINNET" },
};

/** Check whether a chain ID is in the supported set. */
export function isSupportedChain(chainId: number | null | undefined): boolean {
  if (chainId == null) return false;
  return (SUPPORTED_CHAIN_IDS as readonly number[]).includes(chainId);
}
