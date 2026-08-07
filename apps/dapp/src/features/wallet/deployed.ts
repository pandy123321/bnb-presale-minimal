// PANGU2 DApp — Deployed Contract Addresses (BSC Testnet)
// Updated: 2026-08-07 — matches contracts-v2/.env authoritative registry (Stage 1 deployment)

export const TOKEN    = "0x49a4a6EcAACC5D9AE60df7717f62e0605F591bc3" as const;
export const ROUTER   = "0xB0b5b52cB99ee7ea055669ba49aFD02cF69c71b5" as const;
export const DIVIDEND = "0x917705D794EC31144F7B2C4d62bfaAb4fE327385" as const;
export const SUPPORT  = "0xe6d37841B13D78e9Ae759b77eCFAeBEDdB90589B" as const;
export const VAULT    = "0xF82313Eb70d24250d541c26796fE1615BEB15D29" as const;
export const LOCKER   = "0x0a2283Cd52523889fcb333596C3f0a14741B1cce" as const;
export const STAKING  = "0xf1D27Ef1037c38B6752bAE449fd3a460b49775a8" as const;
export const ORACLE   = "0x11C39DB60A95B232C6c303C1869aA81886694D9c" as const;
export const ADAPTER  = "0xC3BB2129Cb362B82Cc15Ec63a8355E80D4198E3a" as const;
export const PAIR     = "0x07d481b52c27941f6Daaeb53AaA879c588408F32" as const;
export const COSTBASIS = "0x695660310AFB747589D415d24f20a3eEF05693D0" as const;

/** All deployed PANGU2 V2 addresses on BSC Testnet */
export const DEPLOYED = {
  token: TOKEN, router: ROUTER, dividend: DIVIDEND,
  support: SUPPORT, vault: VAULT, locker: LOCKER,
  adapter: ADAPTER, oracle: ORACLE, pair: PAIR,
  staking: STAKING, costbasis: COSTBASIS,
} as const;
