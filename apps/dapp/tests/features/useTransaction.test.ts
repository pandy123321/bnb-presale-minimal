// PANGU2 DApp — Transaction Feature Tests
import { describe, it, expect, beforeEach } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { ApprovalState, ChainTxState } from "@pangu2/api-types";
import { useTransaction } from "@/features/transactions/useTransaction";

describe("useTransaction", () => {
  beforeEach(() => setActivePinia(createPinia()));

  it("starts in NOT_STARTED phase", () => {
    const tx = useTransaction();
    expect(tx.state.value.phase).toBe("NOT_STARTED");
    expect(tx.state.value.approvalState).toBe(ApprovalState.NOT_REQUIRED);
    expect(tx.state.value.chainTxState).toBe(ChainTxState.CREATED);
    expect(tx.isInProgress.value).toBe(false);
    expect(tx.isTerminal.value).toBe(false);
  });

  it("recoverFromReject resets to READY on USER_REJECTED", () => {
    const tx = useTransaction();
    tx.state.value.phase = "REJECTED";
    tx.state.value.error = "Transaction rejected in wallet.";
    tx.state.value.errorCode = "USER_REJECTED";
    tx.state.value.errorRecoverable = true;
    tx.state.value.approvalState = ApprovalState.REJECTED;

    tx.recoverFromReject();

    expect(tx.state.value.phase).toBe("READY");
    expect(tx.state.value.error).toBeNull();
    expect(tx.state.value.errorCode).toBeNull();
    expect(tx.state.value.approvalState).toBe(ApprovalState.NOT_REQUIRED);
  });

  it("recoverFromReject does nothing for non-USER_REJECTED", () => {
    const tx = useTransaction();
    tx.state.value.phase = "FAILED";
    tx.state.value.error = "Transaction reverted.";
    tx.state.value.errorCode = "TX_REVERTED";
    tx.recoverFromReject();
    expect(tx.state.value.phase).toBe("FAILED");
    expect(tx.state.value.errorCode).toBe("TX_REVERTED");
  });

  it("reset returns to initial NOT_STARTED", () => {
    const tx = useTransaction();
    tx.state.value.phase = "CONFIRMED";
    tx.state.value.sellTxHash = "0x" + "ab".repeat(32);
    tx.state.value.blockNumber = "100";
    tx.reset();
    expect(tx.state.value.phase).toBe("NOT_STARTED");
    expect(tx.state.value.sellTxHash).toBeNull();
    expect(tx.state.value.blockNumber).toBeNull();
    expect(tx.state.value.error).toBeNull();
  });

  it("isInProgress is true for non-terminal phases", () => {
    const tx = useTransaction();
    for (const p of ["FETCHING_QUOTE","SIGNING","SUBMITTING","PENDING","READY"]) {
      tx.state.value.phase = p as any;
      expect(tx.isInProgress.value).toBe(true);
    }
  });

  it("isInProgress is false for terminal phases", () => {
    const tx = useTransaction();
    for (const p of ["NOT_STARTED","CONFIRMED","FAILED","REJECTED"]) {
      tx.state.value.phase = p as any;
      expect(tx.isInProgress.value).toBe(false);
    }
  });

  it("isTerminal is true only for CONFIRMED/FAILED/REJECTED", () => {
    const tx = useTransaction();
    tx.state.value.phase = "CONFIRMED"; expect(tx.isTerminal.value).toBe(true);
    tx.state.value.phase = "FAILED"; expect(tx.isTerminal.value).toBe(true);
    tx.state.value.phase = "REJECTED"; expect(tx.isTerminal.value).toBe(true);
    tx.state.value.phase = "PENDING"; expect(tx.isTerminal.value).toBe(false);
    tx.state.value.phase = "SIGNING"; expect(tx.isTerminal.value).toBe(false);
  });

  it("needsApproval is true when approvalState is REQUIRED", () => {
    const tx = useTransaction();
    tx.state.value.approvalState = ApprovalState.REQUIRED;
    expect(tx.needsApproval.value).toBe(true);
  });

  it("ChainTxState validates all 8 states unique", () => {
    const s = [
      ChainTxState.CREATED, ChainTxState.SUBMITTED, ChainTxState.PENDING,
      ChainTxState.CONFIRMED, ChainTxState.FAILED, ChainTxState.REPLACED,
      ChainTxState.DROPPED, ChainTxState.REORGED,
    ];
    expect(s).toHaveLength(8);
    expect(new Set(s).size).toBe(8);
  });

  it("errorRecoverable defaults to false", () => {
    const tx = useTransaction();
    expect(tx.state.value.errorRecoverable).toBe(false);
  });
});
