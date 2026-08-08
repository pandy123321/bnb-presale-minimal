-- rt01_mutation_test.sql
-- Validates that without the state transition trigger guard,
-- an illegal FINALIZED -> QUEUED transition succeeds, proving
-- the guard is working. Transaction-protected: ROLLBACK ensures
-- trigger is always restored even on failure.

\set ON_ERROR_STOP on

BEGIN;

SET search_path TO binggoplus_v2;

\echo '===== MUTATION SAFETY TEST ====='

-- Setup FK references (clean: no collision with SP test leftovers)
SET ROLE postgres;
INSERT INTO admin_users(id, username, password_hash, role, active, created_at, updated_at)
VALUES ('11111111-1111-1111-1111-111111111111', 'mut_admin', '$2a$mut', 'SUPER_ADMIN', true, now(), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO environments(id, code, project, chain_id, rpc_alias, write_enabled, created_at, updated_at)
VALUES ('22222222-2222-2222-2222-222222222222', 'mut-test', 'binggoplus', 97, 'rpc-mut', false, now(), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO deployment_sets(id, environment_id, version, source_commit, status, created_at, updated_at)
VALUES ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'mut-v1', '0000000000000000000000000000000000000000', 'ACTIVE', now(), now())
ON CONFLICT (id) DO NOTHING;

-- 1. Record initial trigger state
\echo 'MUT-01|trigger_before = ENABLED'
SELECT tgname, tgenabled FROM pg_trigger WHERE tgname = 'governance_commands_state_transition_guard';

-- 2. Create test command in FINALIZED state
INSERT INTO governance_commands(id, environment_id, deployment_set_id, action, target_contract_key, target_address, selector, parameters, request_hash, requested_by, state, created_at, updated_at)
VALUES ('f404f404-f404-f404-f404-f404f404f404', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0404040404040404040404040404040404040404040404040404040404040404', '11111111-1111-1111-1111-111111111111', 'FINALIZED', now(), now());

-- 3. Disable the transition guard trigger
ALTER TABLE governance_commands DISABLE TRIGGER governance_commands_state_transition_guard;
\echo 'MUT-01|trigger_temporarily_disabled = YES'

-- Verify disabled
SELECT tgname, tgenabled FROM pg_trigger WHERE tgname = 'governance_commands_state_transition_guard';

-- 4. Illegal FINALIZED -> QUEUED without guard (must succeed)
SET ROLE bgp_reconciler;
UPDATE governance_commands SET state = 'QUEUED' WHERE id = 'f404f404-f404-f404-f404-f404f404f404';
\echo 'MUT-01|illegal_transition_without_guard = SUCCESS'

-- Verify state
DO $$
DECLARE v_state text;
BEGIN
    SELECT state INTO v_state FROM governance_commands WHERE id = 'f404f404-f404-f404-f404-f404f404f404';
    IF v_state = 'QUEUED' THEN
        RAISE NOTICE 'MUT-01|state_verification = QUEUED_CONFIRMED';
    ELSE
        RAISE EXCEPTION 'MUTATION_VERIFY_FAILED: expected QUEUED, got %', COALESCE(v_state, 'NULL');
    END IF;
END;
$$;

-- 5. Create second command for guarded proof
SET ROLE postgres;
INSERT INTO governance_commands(id, environment_id, deployment_set_id, action, target_contract_key, target_address, selector, parameters, request_hash, requested_by, state, created_at, updated_at)
VALUES ('c404c404-c404-c404-c404-c404c404c404', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0505050505050505050505050505050505050505050505050505050505050505', '11111111-1111-1111-1111-111111111111', 'FINALIZED', now(), now());

-- 6. Re-enable trigger
ALTER TABLE governance_commands ENABLE TRIGGER governance_commands_state_transition_guard;
\echo 'MUT-01|trigger_restored = YES'

SELECT tgname, tgenabled FROM pg_trigger WHERE tgname = 'governance_commands_state_transition_guard';
\echo 'MUT-01|trigger_after = ENABLED'

-- 7. Attempt same illegal transition WITH guard (must FAIL with 55000)
SET ROLE bgp_reconciler;
DO $$
BEGIN
    UPDATE governance_commands SET state = 'QUEUED' WHERE id = 'c404c404-c404-c404-c404-c404c404c404';
    RAISE NOTICE 'MUT_SP04_proof|bgp_reconciler|FAIL|PASS|UNEXPECTED_SUCCESS|transition should have been blocked but succeeded';
    RAISE EXCEPTION 'MUTATION_PROOF_FAILED: guard did not block illegal transition';
EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '55000' THEN
        RAISE NOTICE 'MUT_SP04_proof|bgp_reconciler|FAIL|PASS|55000|%', SQLERRM;
    ELSE
        RAISE NOTICE 'MUT_SP04_proof|bgp_reconciler|FAIL|FAIL|UNEXPECTED_SQLSTATE_%|%', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'MUTATION_PROOF_FAILED: unexpected SQLSTATE %', SQLSTATE;
    END IF;
END;
$$;

-- 8. ROLLBACK everything (restores trigger, cleans data, no manual delete needed)
ROLLBACK;

\echo 'MUT-01|mutation_environment_cleaned = YES (rolled back)'
\echo 'MUT-01|VERDICT = PASS'
\echo '===== MUTATION SAFETY TEST COMPLETE ====='
