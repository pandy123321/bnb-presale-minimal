-- BingGoPlus Go Backend V2 runtime privilege freeze candidate.
-- Apply after 0001_binggoplus_v2_schema.sql as role bgp_migrator.
-- Login roles, passwords, CONNECT privileges and secret distribution are provisioned
-- by the deployment platform and are intentionally outside this repository.

BEGIN;

DO $$
DECLARE
  required_role text;
BEGIN
  IF current_user <> 'bgp_migrator' THEN
    RAISE EXCEPTION 'runtime privilege migration must run as bgp_migrator, current_user=%', current_user;
  END IF;

  FOREACH required_role IN ARRAY ARRAY[
    'bgp_api',
    'bgp_indexer',
    'bgp_projector',
    'bgp_dividend',
    'bgp_reconciler',
    'bgp_auditor',
    'bgp_readonly'
  ]
  LOOP
    IF to_regrole(required_role) IS NULL THEN
      RAISE EXCEPTION 'required runtime role % does not exist', required_role;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM pg_roles
      WHERE rolname = required_role
        AND (rolsuper OR rolcreaterole OR rolcreatedb OR rolbypassrls)
    ) THEN
      RAISE EXCEPTION 'runtime role % has forbidden cluster-level privileges', required_role;
    END IF;

    IF pg_has_role(required_role, 'bgp_migrator', 'MEMBER') THEN
      RAISE EXCEPTION 'runtime role % must not inherit bgp_migrator', required_role;
    END IF;
  END LOOP;
END;
$$;

REVOKE ALL PRIVILEGES ON SCHEMA binggoplus_v2 FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA binggoplus_v2 FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION binggoplus_v2.reject_admin_audit_log_mutation() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION binggoplus_v2.enforce_dividend_snapshot_block() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION binggoplus_v2.enforce_dividend_epoch_writer_boundary() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION binggoplus_v2.reject_projection_receipt_identity_mutation() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION binggoplus_v2.reject_dividend_evidence_mutation() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION binggoplus_v2.reject_governance_command_binding_mutation() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION binggoplus_v2.enforce_governance_command_state_transition() FROM PUBLIC;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA binggoplus_v2
  FROM bgp_api, bgp_indexer, bgp_projector, bgp_dividend,
       bgp_reconciler, bgp_auditor, bgp_readonly;

GRANT USAGE ON SCHEMA binggoplus_v2
  TO bgp_api, bgp_indexer, bgp_projector, bgp_dividend,
     bgp_reconciler, bgp_auditor, bgp_readonly;

-- API: serves read models and owns HTTP/session/idempotency/governance intake.
GRANT SELECT ON
  binggoplus_v2.environments,
  binggoplus_v2.deployment_sets,
  binggoplus_v2.contract_instances,
  binggoplus_v2.deployment_actions,
  binggoplus_v2.contract_evidence_checks,
  binggoplus_v2.chain_cursors,
  binggoplus_v2.token_balances_current,
  binggoplus_v2.cost_basis_current,
  binggoplus_v2.trades,
  binggoplus_v2.staking_positions,
  binggoplus_v2.staking_events,
  binggoplus_v2.dividend_epochs,
  binggoplus_v2.dividend_artifacts,
  binggoplus_v2.dividend_allocations,
  binggoplus_v2.dividend_publish_preflights,
  binggoplus_v2.dividend_claims,
  binggoplus_v2.buybacks,
  binggoplus_v2.locker_batches,
  binggoplus_v2.fee_vault_movements,
  binggoplus_v2.oracle_events,
  binggoplus_v2.protocol_control_events,
  binggoplus_v2.role_events,
  binggoplus_v2.governance_tx_attempts,
  binggoplus_v2.job_runs,
  binggoplus_v2.system_anomalies
TO bgp_api;

GRANT SELECT, INSERT, UPDATE, DELETE ON
  binggoplus_v2.admin_users,
  binggoplus_v2.admin_sessions,
  binggoplus_v2.wallet_challenges,
  binggoplus_v2.wallet_sessions,
  binggoplus_v2.idempotency_records
TO bgp_api;

GRANT SELECT, INSERT ON
  binggoplus_v2.governance_commands
TO bgp_api;

GRANT UPDATE (state, updated_at)
ON binggoplus_v2.governance_commands TO bgp_api;

GRANT SELECT, INSERT ON
  binggoplus_v2.governance_approvals,
  binggoplus_v2.dividend_approvals
TO bgp_api;

GRANT INSERT (
  id,
  environment_id,
  epoch_id,
  snapshot_block_number,
  snapshot_block_hash,
  total_reward_raw,
  created_at,
  updated_at
) ON binggoplus_v2.dividend_epochs TO bgp_api;

-- Audit logs are append-only for every runtime writer.
GRANT SELECT, INSERT ON binggoplus_v2.admin_audit_logs TO bgp_api;
GRANT INSERT ON binggoplus_v2.job_runs TO bgp_api;

-- Indexer: may advance scanner state and mark reorged raw facts, but cannot delete them.
GRANT SELECT ON
  binggoplus_v2.environments,
  binggoplus_v2.deployment_sets,
  binggoplus_v2.contract_instances,
  binggoplus_v2.chain_streams,
  binggoplus_v2.chain_stream_contracts
TO bgp_indexer;

GRANT SELECT, INSERT, UPDATE ON
  binggoplus_v2.chain_leases,
  binggoplus_v2.chain_cursors,
  binggoplus_v2.system_anomalies
TO bgp_indexer;

GRANT SELECT, INSERT ON
  binggoplus_v2.chain_blocks,
  binggoplus_v2.chain_raw_events
TO bgp_indexer;

GRANT UPDATE (canonical, finalized)
  ON binggoplus_v2.chain_blocks TO bgp_indexer;

GRANT UPDATE (event_name, decoded, status, canonical, confirmed_at)
  ON binggoplus_v2.chain_raw_events TO bgp_indexer;

-- Projector: rebuildable derived state only. Raw chain facts remain read-only here.
GRANT SELECT ON
  binggoplus_v2.environments,
  binggoplus_v2.deployment_sets,
  binggoplus_v2.contract_instances,
  binggoplus_v2.chain_streams,
  binggoplus_v2.chain_cursors,
  binggoplus_v2.chain_blocks,
  binggoplus_v2.chain_raw_events
TO bgp_projector;

GRANT SELECT, INSERT ON
  binggoplus_v2.projection_receipts
TO bgp_projector;

GRANT UPDATE (status, result_refs, error, applied_at)
ON binggoplus_v2.projection_receipts TO bgp_projector;

GRANT SELECT, INSERT ON
  binggoplus_v2.token_balance_ledger,
  binggoplus_v2.staking_events
TO bgp_projector;

GRANT SELECT ON
  binggoplus_v2.dividend_epochs
TO bgp_projector;

GRANT UPDATE (
  state,
  merkle_root,
  claim_start,
  claim_end,
  carry_raw,
  updated_at
) ON binggoplus_v2.dividend_epochs TO bgp_projector;

GRANT SELECT, INSERT, UPDATE, DELETE ON
  binggoplus_v2.token_balances_current,
  binggoplus_v2.cost_basis_events,
  binggoplus_v2.cost_basis_current,
  binggoplus_v2.trades,
  binggoplus_v2.staking_positions,
  binggoplus_v2.dividend_claims,
  binggoplus_v2.buybacks,
  binggoplus_v2.locker_batches,
  binggoplus_v2.fee_vault_movements,
  binggoplus_v2.oracle_events,
  binggoplus_v2.protocol_control_events,
  binggoplus_v2.role_events
TO bgp_projector;

GRANT SELECT, INSERT, UPDATE ON
  binggoplus_v2.job_runs,
  binggoplus_v2.system_anomalies
TO bgp_projector;

-- Dividend builder: replays narrow, canonical historical views at a fixed finalized block.
-- Current-state tables are intentionally excluded from artifact construction.
GRANT SELECT ON
  binggoplus_v2.environments,
  binggoplus_v2.deployment_sets,
  binggoplus_v2.contract_instances,
  binggoplus_v2.dividend_finalized_blocks_v1,
  binggoplus_v2.dividend_projection_coverage_v1,
  binggoplus_v2.dividend_token_balance_history_v1,
  binggoplus_v2.dividend_staking_history_v1,
  binggoplus_v2.dividend_claims,
  binggoplus_v2.dividend_approvals
TO bgp_dividend;

GRANT SELECT ON
  binggoplus_v2.dividend_epochs
TO bgp_dividend;

GRANT UPDATE (
  state,
  claim_start,
  claim_end,
  updated_at
) ON binggoplus_v2.dividend_epochs TO bgp_dividend;

GRANT SELECT, INSERT, UPDATE ON
  binggoplus_v2.job_runs,
  binggoplus_v2.system_anomalies
TO bgp_dividend;

GRANT SELECT, INSERT ON
  binggoplus_v2.dividend_artifacts,
  binggoplus_v2.dividend_publish_preflights
TO bgp_dividend;

GRANT SELECT, INSERT ON
  binggoplus_v2.dividend_allocations
TO bgp_dividend;

-- Transaction reconciler: serializes nonces and reconciles approved governance submissions.
-- Command creation remains API intake only; Reconciler may only advance runtime state.
GRANT SELECT ON
  binggoplus_v2.environments,
  binggoplus_v2.deployment_sets,
  binggoplus_v2.contract_instances,
  binggoplus_v2.governance_commands,
  binggoplus_v2.governance_approvals,
  binggoplus_v2.dividend_epochs,
  binggoplus_v2.dividend_artifacts,
  binggoplus_v2.dividend_allocations,
  binggoplus_v2.dividend_approvals,
  binggoplus_v2.dividend_publish_preflights,
  binggoplus_v2.dividend_finalized_blocks_v1,
  binggoplus_v2.dividend_projection_coverage_v1,
  binggoplus_v2.dividend_token_balance_history_v1,
  binggoplus_v2.dividend_staking_history_v1
TO bgp_reconciler;

GRANT UPDATE (state, updated_at)
ON binggoplus_v2.governance_commands TO bgp_reconciler;

GRANT SELECT, INSERT, UPDATE ON
  binggoplus_v2.signer_nonces,
  binggoplus_v2.governance_tx_attempts,
  binggoplus_v2.job_runs,
  binggoplus_v2.system_anomalies
TO bgp_reconciler;

GRANT SELECT, INSERT ON binggoplus_v2.admin_audit_logs TO bgp_reconciler;

-- Auditor: operational evidence without session/challenge/signer-secret tables.
GRANT SELECT ON
  binggoplus_v2.environments,
  binggoplus_v2.deployment_sets,
  binggoplus_v2.contract_instances,
  binggoplus_v2.deployment_actions,
  binggoplus_v2.contract_evidence_checks,
  binggoplus_v2.chain_streams,
  binggoplus_v2.chain_cursors,
  binggoplus_v2.governance_commands,
  binggoplus_v2.governance_approvals,
  binggoplus_v2.governance_tx_attempts,
  binggoplus_v2.dividend_epochs,
  binggoplus_v2.dividend_artifacts,
  binggoplus_v2.dividend_allocations,
  binggoplus_v2.dividend_approvals,
  binggoplus_v2.dividend_publish_preflights,
  binggoplus_v2.admin_audit_logs,
  binggoplus_v2.job_runs,
  binggoplus_v2.system_anomalies
TO bgp_auditor;

-- Read-only product/operations views; excludes authentication and signing state.
GRANT SELECT ON
  binggoplus_v2.environments,
  binggoplus_v2.deployment_sets,
  binggoplus_v2.contract_instances,
  binggoplus_v2.chain_cursors,
  binggoplus_v2.token_balances_current,
  binggoplus_v2.cost_basis_current,
  binggoplus_v2.trades,
  binggoplus_v2.staking_positions,
  binggoplus_v2.staking_events,
  binggoplus_v2.dividend_epochs,
  binggoplus_v2.dividend_artifacts,
  binggoplus_v2.dividend_allocations,
  binggoplus_v2.dividend_approvals,
  binggoplus_v2.dividend_publish_preflights,
  binggoplus_v2.dividend_claims,
  binggoplus_v2.buybacks,
  binggoplus_v2.locker_batches,
  binggoplus_v2.fee_vault_movements,
  binggoplus_v2.oracle_events,
  binggoplus_v2.protocol_control_events,
  binggoplus_v2.role_events,
  binggoplus_v2.system_anomalies
TO bgp_readonly;

-- Future objects created by bgp_migrator are private until an explicit grant is added.
ALTER DEFAULT PRIVILEGES IN SCHEMA binggoplus_v2
  REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA binggoplus_v2
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

COMMIT;
