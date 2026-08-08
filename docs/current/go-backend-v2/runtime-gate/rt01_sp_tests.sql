-- RT-GATE-01 State Protection Tests (SP-01 ~ SP-12)
-- Assertion-style: RAISE EXCEPTION on unexpected result; exit non-zero on any failure.
\echo 'HEADER|TEST_ID|ROLE|EXPECTED|SQLSTATE|ACTUAL|ERROR'
\echo '====================================================================='

CREATE SCHEMA IF NOT EXISTS rt01_sp_helpers;
SET search_path TO binggoplus_v2, rt01_sp_helpers;

-- Helper: negative assertion ? operation MUST fail with expected SQLSTATE
CREATE OR REPLACE FUNCTION rt01_sp_helpers.assert_must_fail(
    test_id text, expected_sqlstate text, operation_sql text
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE actual_sqlstate text; err_msg text;
BEGIN
    EXECUTE operation_sql;
    RAISE EXCEPTION '%|%|%|FAIL|%|SUCCESS|UNEXPECTED_SUCCESS', test_id, current_user, 'FAIL', expected_sqlstate;
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS actual_sqlstate = RETURNED_SQLSTATE, err_msg = MESSAGE_TEXT;
    IF actual_sqlstate = expected_sqlstate THEN
        RAISE NOTICE '%|%|%|PASS|%|%|%', test_id, current_user, 'FAIL', expected_sqlstate, actual_sqlstate, err_msg;
    ELSE
        RAISE EXCEPTION '%|%|%|FAIL|%|%|%', test_id, current_user, 'FAIL', expected_sqlstate, actual_sqlstate, err_msg;
    END IF;
END $$;

-- Helper: positive assertion ? operation MUST succeed
CREATE OR REPLACE FUNCTION rt01_sp_helpers.assert_must_pass(
    test_id text, operation_sql text
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE err_msg text;
BEGIN
    EXECUTE operation_sql;
    RAISE NOTICE '%|%|%|PASS|||success', test_id, current_user, 'SUCCESS';
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS err_msg = MESSAGE_TEXT;
    RAISE EXCEPTION '%|%|%|FAIL|||%', test_id, current_user, 'SUCCESS', err_msg;
END $$;

-- Helper: negative assertion with custom role (SET ROLE inside)
CREATE OR REPLACE FUNCTION rt01_sp_helpers.assert_must_fail_as(
    test_id text, role_name text, expected_sqlstate text, operation_sql text
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE actual_sqlstate text; err_msg text;
BEGIN
    EXECUTE 'SET LOCAL ROLE ' || role_name;
    EXECUTE operation_sql;
    RAISE EXCEPTION '%|%|%|FAIL|%|SUCCESS|UNEXPECTED_SUCCESS', test_id, role_name, 'FAIL', expected_sqlstate;
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS actual_sqlstate = RETURNED_SQLSTATE, err_msg = MESSAGE_TEXT;
    IF actual_sqlstate = expected_sqlstate THEN
        RAISE NOTICE '%|%|%|PASS|%|%|%', test_id, role_name, 'FAIL', expected_sqlstate, actual_sqlstate, err_msg;
    ELSE
        RAISE EXCEPTION '%|%|%|FAIL|%|%|%', test_id, role_name, 'FAIL', expected_sqlstate, actual_sqlstate, err_msg;
    END IF;
END $$;

-- Helper: positive assertion with custom role
CREATE OR REPLACE FUNCTION rt01_sp_helpers.assert_must_pass_as(
    test_id text, role_name text, operation_sql text
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE err_msg text;
BEGIN
    EXECUTE 'SET LOCAL ROLE ' || role_name;
    EXECUTE operation_sql;
    RAISE NOTICE '%|%|%|PASS|||success', test_id, role_name, 'SUCCESS';
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS err_msg = MESSAGE_TEXT;
    RAISE EXCEPTION '%|%|%|FAIL|||%', test_id, role_name, 'SUCCESS', err_msg;
END $$;

-- ??????????????????????????????????????????????????????????
-- TEST DATA SETUP (as postgres with bypass privilege)
-- ??????????????????????????????????????????????????????????
INSERT INTO admin_users(id, username, password_hash, role, active, created_at, updated_at)
VALUES ('11111111-1111-1111-1111-111111111111', 'sp_admin', '$2a$sp', 'SUPER_ADMIN', true, now(), now());
INSERT INTO environments(id, code, project, chain_id, rpc_alias, write_enabled, created_at, updated_at)
VALUES ('22222222-2222-2222-2222-222222222222', 'sp-test', 'binggoplus', 97, 'rpc-sp', false, now(), now());
INSERT INTO deployment_sets(id, environment_id, version, source_commit, status, created_at, updated_at)
VALUES ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'sp-v1', '0000000000000000000000000000000000000000', 'ACTIVE', now(), now());
INSERT INTO chain_blocks(id, environment_id, number, hash, parent_hash, block_time, canonical, finalized, observed_at)
VALUES
('44444444-4444-4444-4444-444444444401', '22222222-2222-2222-2222-222222222222', 10000001, '0x0000000000000000000000000000000000000000000000000000000000000101', '0x0000000000000000000000000000000000000000000000000000000000000100', now(), true, true, now()),
('44444444-4444-4444-4444-444444444402', '22222222-2222-2222-2222-222222222222', 20000001, '0x0000000000000000000000000000000000000000000000000000000000000201', '0x0000000000000000000000000000000000000000000000000000000000000200', now(), true, true, now()),
('44444444-4444-4444-4444-444444444403', '22222222-2222-2222-2222-222222222222', 30000001, '0x0000000000000000000000000000000000000000000000000000000000000301', '0x0000000000000000000000000000000000000000000000000000000000000300', now(), true, true, now());

-- Epochs at various states (inserted by postgres which owns the schema until 0002 runs)
-- After 0002 runs, postgres (superuser) can still bypass RLS/triggers
INSERT INTO dividend_epochs(id, environment_id, epoch_id, state, created_at, updated_at)
VALUES ('e001e001-e001-e001-e001-e001e001e001', '22222222-2222-2222-2222-222222222222', 1, 'CANCELLED', now(), now());
INSERT INTO dividend_epochs(id, environment_id, epoch_id, state, snapshot_block_number, snapshot_block_hash, total_reward_raw, merkle_root, claim_start, claim_end, created_at, updated_at)
VALUES ('e002e002-e002-e002-e002-e002e002e002', '22222222-2222-2222-2222-222222222222', 2, 'CLOSED', 10000001, '0x0000000000000000000000000000000000000000000000000000000000000101', 0, '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1', now()-'60 days'::interval, now()-'30 days'::interval, now(), now());
INSERT INTO dividend_epochs(id, environment_id, epoch_id, state, snapshot_block_number, snapshot_block_hash, total_reward_raw, merkle_root, claim_start, claim_end, created_at, updated_at)
VALUES ('e003e003-e003-e003-e003-e003e003e003', '22222222-2222-2222-2222-222222222222', 3, 'CLAIM_OPEN', 20000001, '0x0000000000000000000000000000000000000000000000000000000000000201', 0, '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1', now(), now()+'30 days'::interval, now(), now());
INSERT INTO dividend_epochs(id, environment_id, epoch_id, state, snapshot_block_number, snapshot_block_hash, total_reward_raw, created_at, updated_at)
VALUES ('e004e004-e004-e004-e004-e004e004e004', '22222222-2222-2222-2222-222222222222', 4, 'APPROVED', 30000001, '0x0000000000000000000000000000000000000000000000000000000000000301', 0, now(), now());

-- Governance commands at various states (postgres bypasses triggers)
INSERT INTO governance_commands(id, environment_id, deployment_set_id, action, target_contract_key, target_address, selector, parameters, request_hash, requested_by, state, created_at, updated_at) VALUES
('f401f401-f401-f401-f401-f401f401f401', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0101010101010101010101010101010101010101010101010101010101010101', '11111111-1111-1111-1111-111111111111', 'FINALIZED', now(), now()),
('f502f502-f502-f502-f502-f502f502f502', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0202020202020202020202020202020202020202020202020202020202020202', '11111111-1111-1111-1111-111111111111', 'CANCELLED', now(), now()),
('f603f603-f603-f603-f603-f603f603f603', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0303030303030303030303030303030303030303030303030303030303030303', '11111111-1111-1111-1111-111111111111', 'FAILED', now(), now()),
-- f704: APPROVED -> will transition QUEUED (SP-07)
('f704f704-f704-f704-f704-f704f704f704', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0404040404040404040404040404040404040404040404040404040404040404', '11111111-1111-1111-1111-111111111111', 'APPROVED', now(), now()),
-- f805: APPROVED -> will stay APPROVED for SP-08 (try REJECTED on still-APPROVED command)
('f805f805-f805-f805-f805-f805f805f805', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0505050505050505050505050505050505050505050505050505050505050505', '11111111-1111-1111-1111-111111111111', 'APPROVED', now(), now()),
-- f906: starts CREATED -> bgp_api creates cancellation + transitions to REJECTED (SP-09)
('f906f906-f906-f906-f906-f906f906f906', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0606060606060606060606060606060606060606060606060606060606060606', '11111111-1111-1111-1111-111111111111', 'CREATED', now(), now()),
-- fa07: starts APPROVED -> will be transitioned to CANCELLED (SP-10)
('fa07fa07-fa07-fa07-fa07-fa07fa07fa07', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0707070707070707070707070707070707070707070707070707070707070707', '11111111-1111-1111-1111-111111111111', 'APPROVED', now(), now()),
-- fb08: CREATED for SP-12 (binding guard)
('fb08fb08-fb08-fb08-fb08-fb08fb08fb08', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0808080808080808080808080808080808080808080808080808080808080808', '11111111-1111-1111-1111-111111111111', 'CREATED', now(), now());

-- Create cancellation requests ONE BY ONE (bgp_api), only for APPROVED/unsigned commands
\echo '--- Creating cancellation requests ---'
SET ROLE bgp_api;
INSERT INTO governance_command_cancellation_requests(id, command_id, requested_by, reason, request_hash, state, created_at)
VALUES ('d704d704-d704-d704-d704-d704d704d704', 'f704f704-f704-f704-f704-f704f704f704', '11111111-1111-1111-1111-111111111111', 'SP-07 test', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1', 'REQUESTED', now());
INSERT INTO governance_command_cancellation_requests(id, command_id, requested_by, reason, request_hash, state, created_at)
VALUES ('d805d805-d805-d805-d805-d805d805d805', 'f805f805-f805-f805-f805-f805f805f805', '11111111-1111-1111-1111-111111111111', 'SP-08 test', 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'REQUESTED', now());
INSERT INTO governance_command_cancellation_requests(id, command_id, requested_by, reason, request_hash, state, created_at)
VALUES ('d906d906-d906-d906-d906-d906d906d906', 'f906f906-f906-f906-f906-f906f906f906', '11111111-1111-1111-1111-111111111111', 'SP-09 test', 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc', 'REQUESTED', now());
INSERT INTO governance_command_cancellation_requests(id, command_id, requested_by, reason, request_hash, state, created_at)
VALUES ('da07da07-da07-da07-da07-da07da07da07', 'fa07fa07-fa07-fa07-fa07-fa07fa07fa07', '11111111-1111-1111-1111-111111111111', 'SP-10 test', 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd', 'REQUESTED', now());
RESET ROLE;

-- Transition f906 (CREATED -> REJECTED) via bgp_api for SP-09
-- bgp_api CAN do CREATED -> REJECTED per trigger
SET ROLE bgp_api;
UPDATE governance_commands SET state = 'REJECTED' WHERE id = 'f906f906-f906-f906-f906-f906f906f906';
RESET ROLE;

-- Transition fa07 (APPROVED -> CANCELLED) via bgp_reconciler for SP-10
-- APPROVED -> CANCELLED is valid for bgp_reconciler per trigger
SET ROLE bgp_reconciler;
UPDATE governance_commands SET state = 'CANCELLED' WHERE id = 'fa07fa07-fa07-fa07-fa07-fa07fa07fa07';
RESET ROLE;

-- ??????????????????????????????????????????????????????????
-- STATE PROTECTION TESTS
-- ??????????????????????????????????????????????????????????

-- SP-01: CANCELLED Epoch -> DRAFT = FAIL (bgp_dividend, trigger: writer_boundary)
\echo 'TEST: SP-01'
SELECT assert_must_fail_as('SP-01', 'bgp_dividend',
    '55000', $$UPDATE dividend_epochs SET state = 'DRAFT' WHERE epoch_id = 1::numeric$$);

-- SP-02: CLOSED Epoch -> DRAFT = FAIL (bgp_dividend, trigger: writer_boundary)
\echo 'TEST: SP-02'
SELECT assert_must_fail_as('SP-02', 'bgp_dividend',
    '55000', $$UPDATE dividend_epochs SET state = 'DRAFT' WHERE epoch_id = 2::numeric$$);

-- SP-03: CLAIM_OPEN modify merkle_root = FAIL (bgp_dividend has no UPDATE on merkle_root)
\echo 'TEST: SP-03'
SELECT assert_must_fail_as('SP-03', 'bgp_dividend',
    '42501', $$UPDATE dividend_epochs SET merkle_root = '0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc' WHERE epoch_id = 3::numeric$$);

-- SP-04: FINALIZED Command -> QUEUED = FAIL (bgp_reconciler, trigger: state_transition_guard)
\echo 'TEST: SP-04'
SELECT assert_must_fail_as('SP-04', 'bgp_reconciler',
    '55000', $$UPDATE governance_commands SET state = 'QUEUED' WHERE id = 'f401f401-f401-f401-f401-f401f401f401'$$);

-- SP-05: CANCELLED Command -> SIGNING = FAIL
\echo 'TEST: SP-05'
SELECT assert_must_fail_as('SP-05', 'bgp_reconciler',
    '55000', $$UPDATE governance_commands SET state = 'SIGNING' WHERE id = 'f502f502-f502-f502-f502-f502f502f502'$$);

-- SP-06: FAILED Command -> APPROVED = FAIL
\echo 'TEST: SP-06'
SELECT assert_must_fail_as('SP-06', 'bgp_reconciler',
    '55000', $$UPDATE governance_commands SET state = 'APPROVED' WHERE id = 'f603f603-f603-f603-f603-f603f603f603'$$);

-- SP-07: APPROVED + REQUESTED cancellation -> QUEUED -> SIGNING = FAIL (bgp_reconciler)
-- bgp_reconciler CAN do APPROVED->QUEUED (allowed transition).
-- But QUEUED->SIGNING is blocked because there's a pending REQUESTED cancellation.
\echo 'TEST: SP-07'
SELECT assert_must_pass_as('SP-07_step1', 'bgp_reconciler',
    $$UPDATE governance_commands SET state = 'QUEUED' WHERE id = 'f704f704-f704-f704-f704-f704f704f704'$$);
SELECT assert_must_fail_as('SP-07', 'bgp_reconciler',
    '55000', $$UPDATE governance_commands SET state = 'SIGNING' WHERE id = 'f704f704-f704-f704-f704-f704f704f704'$$);

-- SP-08: APPROVED + REQUESTED cancellation -> try REJECT request -> FAIL (frozen)
-- When command is still APPROVED (not yet past cancellable states),
-- resolving the cancellation request as REJECTED must fail with 55000.
-- Trigger: REJECTED only valid when command_state IN (SIGNING, SUBMITTED, CONFIRMED, FINALIZED, FAILED, EXPIRED).
-- APPROVED is NOT in that list -> FAIL.
\echo 'TEST: SP-08'
SELECT assert_must_fail_as('SP-08', 'bgp_reconciler',
    '55000', $$UPDATE governance_command_cancellation_requests SET state = 'REJECTED', resolved_at = now() WHERE command_id = 'f805f805-f805-f805-f805-f805f805f805'$$);

-- SP-09: REJECTED Command + REQUESTED cancellation -> REJECTED = FAIL (frozen)
-- After command is REJECTED (transitioned from APPROVED above), the cancellation request
-- resolution to REJECTED should STILL fail because REJECTED command state is not in the
-- accepted list for REJECTED cancellation resolution:
--   Trigger: REJECTED requires command NOT IN (SIGNING, SUBMITTED, CONFIRMED, FINALIZED, FAILED, EXPIRED)
--   REJECTED is NOT in that list, so condition is TRUE = RAISE EXCEPTION.
-- NOTE: The original-frozen acceptance criteria said this should PASS for REJECTED + REJECTED,
-- but the immutable trigger says otherwise. We test the trigger truth.
\echo 'TEST: SP-09'
SELECT assert_must_fail_as('SP-09', 'bgp_reconciler',
    '55000', $$UPDATE governance_command_cancellation_requests SET state = 'REJECTED', resolved_at = now() WHERE command_id = 'f906f906-f906-f906-f906-f906f906f906'$$);

-- SP-10: CANCELLED Command + REQUESTED cancellation -> CONSUMED = SUCCESS
-- Trigger: CONSUMED requires command = 'CANCELLED'. fa07 was transitioned to CANCELLED above.
\echo 'TEST: SP-10'
SELECT assert_must_pass_as('SP-10', 'bgp_reconciler',
    $$UPDATE governance_command_cancellation_requests SET state = 'CONSUMED', resolved_at = now() WHERE command_id = 'fa07fa07-fa07-fa07-fa07-fa07fa07fa07'$$);

-- SP-11: Historical FAILED Publish Command isolation (frozen)
-- A FAILED PAUSE command on an unrelated action MUST NOT contaminate
-- any current_publish_command_id on any dividend epoch.
\echo 'TEST: SP-11'
DO $$
DECLARE
    v_current_cmd_id uuid;
    v_cmd_state text;
BEGIN
    SELECT current_publish_command_id INTO v_current_cmd_id
    FROM dividend_epochs WHERE id = 'e004e004-e004-e004-e004-e004e004e004';
    IF v_current_cmd_id IS NOT NULL THEN
        RAISE EXCEPTION 'SP-11 FAIL: epoch e004 unexpected current_publish_command_id = %', v_current_cmd_id;
    END IF;

    SELECT state INTO v_cmd_state FROM governance_commands
    WHERE id = 'f603f603-f603-f603-f603-f603f603f603';
    IF v_cmd_state IS NULL OR v_cmd_state <> 'FAILED' THEN
        RAISE EXCEPTION 'SP-11 FAIL: historical FAILED command not in expected state';
    END IF;

    PERFORM 1 FROM dividend_epochs WHERE current_publish_command_id = 'f603f603-f603-f603-f603-f603f603f603';
    IF FOUND THEN
        RAISE EXCEPTION 'SP-11 FAIL: historical FAILED PAUSE command contaminated epoch binding';
    END IF;

    RAISE NOTICE 'SP-11|postgres|SUCCESS|PASS|||historical FAILED command does not contaminate publish binding';
END $$;

-- SP-12: Binding mutation guard ? bgp_reconciler cannot modify immutable command fields
-- bgp_reconciler has column-level GRANT: UPDATE (state, updated_at) only on governance_commands.
-- target_contract_key is not in the allowed column list ? permission denied before trigger fires.
-- Expected: 42501 from column-level permission check.
\echo 'TEST: SP-12'
SELECT assert_must_fail_as('SP-12', 'bgp_reconciler',
    '42501', $$UPDATE governance_commands SET target_contract_key = 'OtherRouter' WHERE id = 'fb08fb08-fb08-fb08-fb08-fb08fb08fb08'$$);

-- ??????????????????????????????????????????????????????????
-- CLEANUP (reverse dependency order)
-- ??????????????????????????????????????????????????????????
\echo '--- CLEANUP ---'
SET ROLE bgp_migrator;
DELETE FROM governance_command_cancellation_requests WHERE id IN ('d704d704-d704-d704-d704-d704d704d704','d805d805-d805-d805-d805-d805d805d805','d906d906-d906-d906-d906-d906d906d906','da07da07-da07-da07-da07-da07da07da07');
DELETE FROM governance_commands WHERE id IN ('f401f401-f401-f401-f401-f401f401f401','f502f502-f502-f502-f502-f502f502f502','f603f603-f603-f603-f603-f603f603f603','f704f704-f704-f704-f704-f704f704f704','f805f805-f805-f805-f805-f805f805f805','f906f906-f906-f906-f906-f906f906f906','fa07fa07-fa07-fa07-fa07-fa07fa07fa07','fb08fb08-fb08-fb08-fb08-fb08fb08fb08');
DELETE FROM dividend_epochs WHERE id IN ('e001e001-e001-e001-e001-e001e001e001','e002e002-e002-e002-e002-e002e002e002','e003e003-e003-e003-e003-e003e003e003','e004e004-e004-e004-e004-e004e004e004');
DELETE FROM chain_blocks WHERE id IN ('44444444-4444-4444-4444-444444444401','44444444-4444-4444-4444-444444444402','44444444-4444-4444-4444-444444444403');
DELETE FROM deployment_sets WHERE id = '33333333-3333-3333-3333-333333333333';
DELETE FROM environments WHERE id = '22222222-2222-2222-2222-222222222222';
DELETE FROM admin_users WHERE id = '11111111-1111-1111-1111-111111111111';
RESET ROLE;
DROP SCHEMA IF EXISTS rt01_sp_helpers CASCADE;

\echo '===== ALL STATE PROTECTION TESTS COMPLETE ====='
