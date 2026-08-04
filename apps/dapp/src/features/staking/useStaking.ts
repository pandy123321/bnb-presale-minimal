// ═══════════════════════════════════════════
// PANGU2 DApp — useStaking Composable
// 读取仓位/收益 + 钱包签名锁仓操作
// 硬规则:
//  - MIN_STAKE = 1 token, MAX_LOCK = 730 days
//  - 金额全部十进制整数字符串，禁止 float
//  - approve → stake；链上操作由钱包签名
// ═══════════════════════════════════════════

import { computed, ref, watch, type Ref } from "vue";
import { isAddress, zeroAddress, parseAbi } from "viem";
import {
  writeContract,
  waitForTransactionReceipt,
  readContract,
  getPublicClient,
} from "@wagmi/core";
import type { WeiAmount, EvmAddress, EnvelopeMeta } from "@pangu2/api-types";
import { DataStatus } from "@pangu2/api-types";
import { fetchGet } from "@/api";
import { wagmiConfig } from "@/features/wallet/config";
import { useWalletStore } from "@/stores/useWallet";
import {
  useStakingStore,
  type PositionStatus,
  type StakePositionSnapshot,
  type StakingGlobalStatus,
} from "@/stores/useStaking";

// ── Contract constants ──────────────────────

export const MIN_STAKE_RAW = "1000000000000000000";
export const MAX_LOCK_SECONDS = 730 * 86400;
export const EARLY_PENALTY_BPS = 1000;
export const SECONDS_PER_DAY = 86400;

export const LOCK_PRESETS = [
  { id: "30", label: "30天", days: 30, seconds: 30 * SECONDS_PER_DAY },
  { id: "90", label: "90天", days: 90, seconds: 90 * SECONDS_PER_DAY },
  { id: "180", label: "180天", days: 180, seconds: 180 * SECONDS_PER_DAY },
  { id: "365", label: "365天", days: 365, seconds: 365 * SECONDS_PER_DAY },
  { id: "custom", label: "自定义", days: 0, seconds: 0 },
] as const;

export type StakingTxPhase =
  | "idle"
  | "approving"
  | "staking"
  | "unstaking"
  | "early_unstaking"
  | "claiming"
  | "confirming"
  | "success"
  | "rejected"
  | "failed";

export type TxErrorCode =
  | "USER_REJECTED"
  | "NETWORK_ERROR"
  | "CONTRACT_REVERT"
  | "INSUFFICIENT_GAS"
  | "UNKNOWN";

// ── API response shapes ──────────

interface EarnedResponse { address: string; earned: WeiAmount; }

interface PositionApiItem {
  positionId: number | null;
  amount: WeiAmount;
  lockedAt: string;
  unlockAt: string;
  claimed: boolean;
  /** per-position earned (API-provided, authoritative) */
  earned?: WeiAmount;
}

interface PositionsResponse { address: string; positions: PositionApiItem[]; count: number; }

interface StatusResponse {
  totalStaked: WeiAmount; rewardRate: WeiAmount;
  periodFinish: string; availableRewardReserve: WeiAmount;
  serverTime?: number;
}

// ── ABI ────────────────────────────

const TOKEN_ABI = parseAbi([
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
]);

const STAKING_ABI = parseAbi([
  "function stake(uint256 amount, uint64 lockSeconds) returns (uint256 positionId)",
  "function unstake(uint256 positionId) returns (uint256 amount)",
  "function earlyUnstake(uint256 positionId) returns (uint256 amount, uint256 penalty)",
  "function claimRewards() returns (uint256 reward)",
]);

// ── Address helpers ────────────────

function requireAddress(v: string | undefined, name: string): `0x${string}` {
  if (!v || !isAddress(v)) throw new Error(`${name} missing or invalid.`);
  if (v.toLowerCase() === zeroAddress.toLowerCase()) throw new Error(`${name} is zero address.`);
  return v as `0x${string}`;
}

function stakingAddress(): `0x${string}` {
  return requireAddress(import.meta.env.VITE_STAKING_ADDRESS as string | undefined, "VITE_STAKING_ADDRESS");
}

function tokenAddress(): `0x${string}` {
  return requireAddress(import.meta.env.VITE_TOKEN_ADDRESS as string | undefined, "VITE_TOKEN_ADDRESS");
}

async function contractsDeployed(): Promise<boolean> {
  try {
    const client = getPublicClient(wagmiConfig);
    if (!client) return false;
    const [sCode, tCode] = await Promise.all([
      client.getBytecode({ address: stakingAddress() }),
      client.getBytecode({ address: tokenAddress() }),
    ]);
    return !!sCode && sCode !== "0x" && !!tCode && tCode !== "0x";
  } catch { return false; }
}

// ── Amount helpers (all int strings) ──

export function tokenToRaw(amount: string): string {
  const t = amount.trim();
  if (!t || !/^\d+(\.\d+)?$/.test(t)) return "0";
  const [i, f = ""] = t.split(".");
  const p = (i.replace(/^0+(?=\d)/, "") || "0") + f.padEnd(18, "0").slice(0, 18);
  return p.replace(/^0+(?=\d)/, "") || "0";
}

export function weiToDisplay(wei: string, decimals = 18): string {
  if (!wei || wei === "0") return "0";
  const neg = wei.startsWith("-");
  const abs = neg ? wei.slice(1) : wei;
  const s = abs.padStart(decimals + 1, "0");
  const intPart = s.slice(0, -decimals) || "0";
  const fracPart = s.slice(-decimals).replace(/0+$/, "");
  const body = fracPart ? `${intPart}.${fracPart}` : intPart;
  return neg ? `-${body}` : body;
}

export function formatTokenRaw(raw: string): string {
  const v = BigInt(raw || "0");
  const ONE = 10n ** 18n;
  if (v === 0n) return "0 P2";
  const whole = v / ONE;
  if (whole >= 1_000_000n) { const m = whole / 1_000_000n; const fr = (whole % 1_000_000n) / 100_000n; return `${m}.${fr}M P2`; }
  if (whole >= 1_000n) return `${whole.toLocaleString()} P2`;
  return `${weiToDisplay(raw)} P2`;
}

export function compareWei(a: string, b: string): number {
  const A = BigInt(a || "0"); const B = BigInt(b || "0");
  if (A < B) return -1; if (A > B) return 1; return 0;
}

export function computeApyPercent(rewardRate: string, totalStaked: string): string {
  const rate = BigInt(rewardRate || "0"); const total = BigInt(totalStaked || "0");
  if (rate === 0n || total === 0n) return "0.00";
  const YEAR = 365n * BigInt(SECONDS_PER_DAY);
  const h = (rate * YEAR * 10000n) / total; const w = h / 100n; const f = h % 100n;
  return `${w}.${f.toString().padStart(2, "0")}`;
}

export function estimateLockReward(amountRaw: string, lockSeconds: number, rewardRate: string, totalStaked: string): string {
  const a = BigInt(amountRaw || "0"); const r = BigInt(rewardRate || "0"); const t = BigInt(totalStaked || "0");
  const d = t + a;
  if (a === 0n || r === 0n || d === 0n || lockSeconds <= 0) return "0";
  return ((r * BigInt(lockSeconds) * a) / d).toString();
}

export function computePenalty(amountRaw: string): string {
  return ((BigInt(amountRaw || "0") * BigInt(EARLY_PENALTY_BPS)) / 10000n).toString();
}

export function validateStakeAmount(amountHuman: string): string | null {
  const raw = tokenToRaw(amountHuman);
  if (raw === "0") return "请输入有效的锁仓数量";
  if (compareWei(raw, MIN_STAKE_RAW) < 0) return "最小锁仓数量为 1 P2";
  return null;
}

export function validateLockSeconds(seconds: number): string | null {
  if (!Number.isFinite(seconds) || seconds <= 0) return "请选择有效的锁仓时长";
  if (seconds > MAX_LOCK_SECONDS) return "锁仓时长不能超过 730 天";
  return null;
}

function classifyTxError(e: unknown): TxErrorCode {
  const err = e as { code?: string | number; message?: string; name?: string };
  if (err.code === 4001 || err.code === "4001") return "USER_REJECTED";
  const msg = (err.message ?? "").toLowerCase();
  if (msg.includes("rejected") || msg.includes("denied")) return "USER_REJECTED";
  if (msg.includes("network") || msg.includes("fetch") || msg.includes("timeout")) return "NETWORK_ERROR";
  if ((msg.includes("insufficient") || msg.includes("intrinsic")) && msg.includes("gas")) return "INSUFFICIENT_GAS";
  if (msg.includes("revert") || msg.includes("execution reverted")) return "CONTRACT_REVERT";
  return "UNKNOWN";
}

// ── P2-002 fix: use server-time, not client clock ──

function deriveStatus(claimed: boolean, unlockAt: string, store: ReturnType<typeof useStakingStore>): PositionStatus {
  if (claimed) return "claimed";
  const unlock = Number(unlockAt);
  if (!Number.isFinite(unlock)) return "locked";
  if (store.serverNow() >= unlock) return "matured";
  return "locked";
}

function remainingDays(unlockAt: string, claimed: boolean, store: ReturnType<typeof useStakingStore>): number {
  if (claimed) return 0;
  const unlock = Number(unlockAt);
  if (!Number.isFinite(unlock)) return 0;
  const rem = unlock - store.serverNow();
  if (rem <= 0) return 0;
  return Math.floor((rem + SECONDS_PER_DAY - 1) / SECONDS_PER_DAY);
}

// ── P2-001 fix: per-position earned from API, not proportional estimate ──

function toWeiAmount(v: string | undefined | null): WeiAmount {
  return (v && /^\d+$/.test(v) ? v : "0") as WeiAmount;
}

function mapPositions(
  items: PositionApiItem[],
  accountEarned: string,
  store: ReturnType<typeof useStakingStore>,
): StakePositionSnapshot[] {
  // P2-001: prefer per-position earned from API. Only fallback to proportional
  // if the API does NOT supply per-position earned.
  const hasPerPositionEarned = items.some((i) => i.earned !== undefined && i.earned !== "0");
  const earned = BigInt(accountEarned || "0");
  let totalUnclaimed = 0n;
  if (!hasPerPositionEarned) {
    for (const item of items) {
      if (!item.claimed) totalUnclaimed += BigInt(item.amount || "0");
    }
  }

  return items.map((item, index) => {
    const amount = toWeiAmount(item.amount);
    const claimed = !!item.claimed;
    let earnedEstimate: WeiAmount = "0" as WeiAmount;

    // P2-001: API per-position earned takes priority
    if (item.earned !== undefined) {
      earnedEstimate = toWeiAmount(item.earned);
    } else if (!claimed && totalUnclaimed > 0n) {
      earnedEstimate = ((earned * BigInt(amount)) / totalUnclaimed).toString() as WeiAmount;
    }

    const status = deriveStatus(claimed, item.unlockAt, store);
    return {
      positionId: item.positionId ?? index,
      amount,
      lockedAt: item.lockedAt ?? "0",
      unlockAt: item.unlockAt ?? "0",
      claimed,
      earnedEstimate,
      status,
      remainingDays: remainingDays(item.unlockAt, claimed, store),
    };
  });
}

function isUserRejected(e: unknown): boolean {
  return classifyTxError(e) === "USER_REJECTED";
}

// ── Composable ─────────────────────

export function useStaking(address: Ref<string | null>) {
  const wallet = useWalletStore();
  const store = useStakingStore();

  const txPhase = ref<StakingTxPhase>("idle");
  const txError = ref<string | null>(null);
  const txErrorCode = ref<TxErrorCode | null>(null);
  const lastTxHash = ref<`0x${string}` | null>(null);

  const isBusy = computed(() =>
    txPhase.value !== "idle" && txPhase.value !== "success"
    && txPhase.value !== "rejected" && txPhase.value !== "failed");

  const apyPercent = computed(() => {
    const s = store.globalStatus;
    if (!s) return "0.00";
    return computeApyPercent(s.rewardRate, s.totalStaked);
  });

  const claimableDisplay = computed(() => formatTokenRaw(store.earnedRaw));
  const totalStakedDisplay = computed(() => formatTokenRaw(store.totalStakedRaw));
  const totalEarnedDisplay = computed(() => formatTokenRaw(store.earnedRaw));

  // ── Fetch ─────────────────────────

  async function refresh(): Promise<void> {
    store.setLoading(true);
    store.setError(null);
    try {
      const statusRes = await fetchGet<StatusResponse>(
        "/v1/projects/pangu2/staking/status", new AbortController().signal,
      );

      // P2-002: capture server time
      if (statusRes.data.serverTime) {
        store.setServerTime(statusRes.data.serverTime);
      } else if (statusRes.meta?.generated_at) {
        store.setServerTime(Math.floor(new Date(statusRes.meta.generated_at).getTime() / 1000));
      }

      const gs: StakingGlobalStatus = {
        totalStaked: toWeiAmount(statusRes.data.totalStaked),
        rewardRate: toWeiAmount(statusRes.data.rewardRate),
        periodFinish: statusRes.data.periodFinish ?? "0",
        availableRewardReserve: toWeiAmount(statusRes.data.availableRewardReserve),
      };
      store.setGlobalStatus(gs);
      applyMeta(statusRes.meta);

      if (!address.value) {
        store.setAddress(null);
        store.setPositions([]);
        store.setEarned("0" as WeiAmount);
        return;
      }

      const addr = address.value.toLowerCase();
      store.setAddress(addr as EvmAddress);

      const [earnedRes, positionsRes] = await Promise.all([
        fetchGet<EarnedResponse>(`/v1/projects/pangu2/staking/earned?address=${addr}`, new AbortController().signal),
        fetchGet<PositionsResponse>(`/v1/projects/pangu2/staking/positions?address=${addr}`, new AbortController().signal),
      ]);

      const earnedV = toWeiAmount(earnedRes.data.earned);
      store.setEarned(earnedV);
      store.setPositions(mapPositions(positionsRes.data.positions ?? [], earnedV, store));
      applyMeta(positionsRes.meta);
    } catch (e: unknown) {
      store.setError(e instanceof Error ? e.message : "加载锁仓数据失败");
    } finally { store.setLoading(false); }
  }

  function applyMeta(meta: EnvelopeMeta | null | undefined): void {
    if (!meta) return;
    store.setMeta(meta.data_status ?? DataStatus.MOCK_DATA, meta.block_number);
  }

  watch(address, (addr) => { if (!addr) store.reset(); refresh(); }, { immediate: true });

  // ── On-chain actions ──────────────

  async function ensureReady(): Promise<boolean> {
    txError.value = null; txErrorCode.value = null;
    if (!wallet.canTransact) {
      txPhase.value = "failed"; txError.value = "请先连接钱包并切换到支持的网络";
      txErrorCode.value = "NETWORK_ERROR"; return false;
    }
    try { stakingAddress(); tokenAddress(); }
    catch (e: unknown) { txPhase.value = "failed"; txError.value = e instanceof Error ? e.message : "合约地址未配置"; txErrorCode.value = "UNKNOWN"; return false; }
    const ok = await contractsDeployed();
    if (!ok) { txPhase.value = "failed"; txError.value = "合约未部署到当前网络"; txErrorCode.value = "NETWORK_ERROR"; return false; }
    return true;
  }

  async function approveIfNeeded(amountRaw: string): Promise<boolean> {
    const owner = wallet.address as `0x${string}`;
    const spender = stakingAddress();
    const token = tokenAddress();
    const needed = BigInt(amountRaw);
    const allowance = (await readContract(wagmiConfig, { address: token, abi: TOKEN_ABI, functionName: "allowance", args: [owner, spender] })) as bigint;
    if (allowance >= needed) return true;
    txPhase.value = "approving";
    const hash = await writeContract(wagmiConfig, { address: token, abi: TOKEN_ABI, functionName: "approve", args: [spender, needed] });
    lastTxHash.value = hash; txPhase.value = "confirming";
    await waitForTransactionReceipt(wagmiConfig, { hash });
    return true;
  }

  function handleTxError(e: unknown): void {
    const code = classifyTxError(e);
    txErrorCode.value = code;
    if (code === "USER_REJECTED") { txPhase.value = "rejected"; txError.value = "已在钱包中拒绝交易"; }
    else { txPhase.value = "failed"; txError.value = e instanceof Error ? e.message : "交易失败"; }
  }

  async function handleTx<R>(phase: StakingTxPhase, fn: () => Promise<R>): Promise<R> {
    txPhase.value = phase;
    try {
      const r = await fn();
      lastTxHash.value = r as unknown as `0x${string}`;
      txPhase.value = "confirming";
      const receipt = await waitForTransactionReceipt(wagmiConfig, { hash: lastTxHash.value! });
      if (receipt.status !== "success") throw new Error("tx reverted");
      txPhase.value = "success";
      await refresh();
      return r;
    } catch (e: unknown) { handleTxError(e); throw e; }
  }

  async function stake(amountHuman: string, lockSeconds: number): Promise<boolean> {
    const ae = validateStakeAmount(amountHuman);
    if (ae) { txPhase.value = "failed"; txError.value = ae; txErrorCode.value = "UNKNOWN"; return false; }
    const le = validateLockSeconds(lockSeconds);
    if (le) { txPhase.value = "failed"; txError.value = le; txErrorCode.value = "UNKNOWN"; return false; }
    if (!(await ensureReady())) return false;
    try {
      const raw = tokenToRaw(amountHuman);
      await approveIfNeeded(raw);
      await handleTx("staking", async () => {
        return writeContract(wagmiConfig, { address: stakingAddress(), abi: STAKING_ABI, functionName: "stake", args: [BigInt(raw), BigInt(lockSeconds)] });
      });
      return true;
    } catch { return false; }
  }

  async function unstake(positionId: number): Promise<boolean> {
    if (!(await ensureReady())) return false;
    try {
      await handleTx("unstaking", async () => {
        return writeContract(wagmiConfig, { address: stakingAddress(), abi: STAKING_ABI, functionName: "unstake", args: [BigInt(positionId)] });
      });
      return true;
    } catch { return false; }
  }

  async function earlyUnstake(positionId: number): Promise<boolean> {
    if (!(await ensureReady())) return false;
    try {
      await handleTx("early_unstaking", async () => {
        return writeContract(wagmiConfig, { address: stakingAddress(), abi: STAKING_ABI, functionName: "earlyUnstake", args: [BigInt(positionId)] });
      });
      return true;
    } catch { return false; }
  }

  async function claimRewards(): Promise<boolean> {
    if (!(await ensureReady())) return false;
    if (compareWei(store.earnedRaw, "0") <= 0) {
      txPhase.value = "failed"; txError.value = "暂无可领取收益"; txErrorCode.value = "UNKNOWN"; return false;
    }
    try {
      await handleTx("claiming", async () => {
        return writeContract(wagmiConfig, { address: stakingAddress(), abi: STAKING_ABI, functionName: "claimRewards", args: [] });
      });
      return true;
    } catch { return false; }
  }

  function resetTx(): void { txPhase.value = "idle"; txError.value = null; txErrorCode.value = null; lastTxHash.value = null; }

  function estimateUnlockAt(lockSeconds: number): Date {
    return new Date((store.serverNow() + Math.max(0, lockSeconds)) * 1000);
  }

  function estimateNewStakeReward(amountHuman: string, lockSeconds: number): string {
    const raw = tokenToRaw(amountHuman);
    const rate = store.globalStatus?.rewardRate ?? ("0" as WeiAmount);
    const total = store.globalStatus?.totalStaked ?? ("0" as WeiAmount);
    return estimateLockReward(raw, lockSeconds, rate, total);
  }

  return {
    store, txPhase, txError, txErrorCode, lastTxHash, isBusy,
    apyPercent, claimableDisplay, totalStakedDisplay, totalEarnedDisplay,
    refresh, stake, unstake, earlyUnstake, claimRewards, resetTx,
    estimateUnlockAt, estimateNewStakeReward,
    formatTokenRaw, weiToDisplay, computePenalty, tokenToRaw,
  };
}
