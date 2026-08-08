-- RT-GATE-01 State Protection Tests (SP-01 ~ SP-11) — Final v5
\echo '=== STATE PROTECTION TESTS (SP-01 ~ SP-11) ==='

-- Test data setup (all as postgres to avoid column-level GRANT constraints)
INSERT INTO binggoplus_v2.admin_users(id, username, password_hash, role, active, created_at, updated_at)
VALUES ('55555555-5555-5555-5555-555555555555', 'sp_test', '$2a$t', 'SUPER_ADMIN', true, now(), now());
INSERT INTO binggoplus_v2.environments(id, code, project, chain_id, rpc_alias, write_enabled, created_at, updated_at)
VALUES ('aaaa1111-aaaa-1111-aaaa-111111111111', 'sp-test', 'binggoplus', 97, 'rpc-sp', false, now(), now());
INSERT INTO binggoplus_v2.deployment_sets(id, environment_id, version, source_commit, status, created_at, updated_at)
VALUES ('bbbb2222-bbbb-2222-bbbb-222222222222', 'aaaa1111-aaaa-1111-aaaa-111111111111', 'sp-v1', '0000000000000000000000000000000000000000', 'ACTIVE', now(), now());
INSERT INTO binggoplus_v2.chain_blocks(id, environment_id, number, hash, parent_hash, block_time, canonical, finalized, observed_at)
VALUES
('cc11cc11-cc11-cc11-cc11-cc11cc11cc11', 'aaaa1111-aaaa-1111-aaaa-111111111111', 10000001, '0x0000000000000000000000000000000000000000000000000000000000000011', '0x0000000000000000000000000000000000000000000000000000000000000010', now(), true, true, now()),
('cc22cc22-cc22-cc22-cc22-cc22cc22cc22', 'aaaa1111-aaaa-1111-aaaa-111111111111', 20000001, '0x0000000000000000000000000000000000000000000000000000000000000022', '0x0000000000000000000000000000000000000000000000000000000000000020', now(), true, true, now());

-- Dividend epochs (bgp_migrator owns schema)
SET ROLE bgp_migrator; SET search_path TO binggoplus_v2;
INSERT INTO dividend_epochs(id, environment_id, epoch_id, state, created_at, updated_at)
VALUES ('ee01ee01-ee01-ee01-ee01-ee01ee01ee01', 'aaaa1111-aaaa-1111-aaaa-111111111111', 1, 'CANCELLED', now(), now());
INSERT INTO dividend_epochs(id, environment_id, epoch_id, state, snapshot_block_number, snapshot_block_hash, total_reward_raw, merkle_root, claim_start, claim_end, created_at, updated_at)
VALUES ('ee02ee02-ee02-ee02-ee02-ee02ee02ee02', 'aaaa1111-aaaa-1111-aaaa-111111111111', 2, 'CLOSED', 10000001, '0x0000000000000000000000000000000000000000000000000000000000000011', 0, '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1', now()-interval '60 days', now()-interval '30 days', now(), now());
INSERT INTO dividend_epochs(id, environment_id, epoch_id, state, snapshot_block_number, snapshot_block_hash, total_reward_raw, merkle_root, claim_start, claim_end, created_at, updated_at)
VALUES ('ee03ee03-ee03-ee03-ee03-ee03ee03ee03', 'aaaa1111-aaaa-1111-aaaa-111111111111', 3, 'CLAIM_OPEN', 20000001, '0x0000000000000000000000000000000000000000000000000000000000000022', 0, '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1', now(), now()+interval '30 days', now(), now());
RESET ROLE;

-- Governance commands (postgres to set all columns)
SET search_path TO binggoplus_v2;
INSERT INTO governance_commands(id, environment_id, deployment_set_id, action, target_contract_key, target_address, selector, parameters, request_hash, requested_by, state, created_at, updated_at) VALUES
('c401c401-c401-c401-c401-c401c401c401', 'aaaa1111-aaaa-1111-aaaa-111111111111', 'bbbb2222-bbbb-2222-bbbb-222222222222', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0101010101010101010101010101010101010101010101010101010101010101', '55555555-5555-5555-5555-555555555555', 'FINALIZED', now(), now()),
('c502c502-c502-c502-c502-c502c502c502', 'aaaa1111-aaaa-1111-aaaa-111111111111', 'bbbb2222-bbbb-2222-bbbb-222222222222', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0202020202020202020202020202020202020202020202020202020202020202', '55555555-5555-5555-5555-555555555555', 'CANCELLED', now(), now()),
('c603c603-c603-c603-c603-c603c603c603', 'aaaa1111-aaaa-1111-aaaa-111111111111', 'bbbb2222-bbbb-2222-bbbb-222222222222', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0303030303030303030303030303030303030303030303030303030303030303', '55555555-5555-5555-5555-555555555555', 'FAILED', now(), now()),
('c704c704-c704-c704-c704-c704c704c704', 'aaaa1111-aaaa-1111-aaaa-111111111111', 'bbbb2222-bbbb-2222-bbbb-222222222222', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0404040404040404040404040404040404040404040404040404040404040404', '55555555-5555-5555-5555-555555555555', 'APPROVED', now(), now()),
('c805c805-c805-c805-c805-c805c805c805', 'aaaa1111-aaaa-1111-aaaa-111111111111', 'bbbb2222-bbbb-2222-bbbb-222222222222', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0505050505050505050505050505050505050505050505050505050505050505', '55555555-5555-5555-5555-555555555555', 'APPROVED', now(), now()),
('c906c906-c906-c906-c906-c906c906c906', 'aaaa1111-aaaa-1111-aaaa-111111111111', 'bbbb2222-bbbb-2222-bbbb-222222222222', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0606060606060606060606060606060606060606060606060606060606060606', '55555555-5555-5555-5555-555555555555', 'REJECTED', now(), now()),
('ca07ca07-ca07-ca07-ca07-ca07ca07ca07', 'aaaa1111-aaaa-1111-aaaa-111111111111', 'bbbb2222-bbbb-2222-bbbb-222222222222', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0707070707070707070707070707070707070707070707070707070707070707', '55555555-5555-5555-5555-555555555555', 'CANCELLED', now(), now()),
('cb08cb08-cb08-cb08-cb08-cb08cb08cb08', 'aaaa1111-aaaa-1111-aaaa-111111111111', 'bbbb2222-bbbb-2222-bbbb-222222222222', 'PAUSE', 'TradeRouter', '0x0000000000000000000000000000000000000001', '0x12345678', '{}', '0808080808080808080808080808080808080808080808080808080808080808', '55555555-5555-5555-5555-555555555555', 'CREATED', now(), now());

-- Cancellation requests (postgres to bypass trigger boundary for setup)
INSERT INTO governance_command_cancellation_requests(id, command_id, requested_by, reason, request_hash, state, created_at) VALUES
('d014d014-d014-d014-d014-d014d014d014', 'c704c704-c704-c704-c704-c704c704c704', '55555555-5555-5555-5555-555555555555', 'SP-07 test', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1', 'REQUESTED', now()),
('d025d025-d025-d025-d025-d025d025d025', 'c805c805-c805-c805-c805-c805c805c805', '55555555-5555-5555-5555-555555555555', 'SP-08 test', 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'REQUESTED', now()),
('d036d036-d036-d036-d036-d036d036d036', 'c906c906-c906-c906-c906-c906c906c906', '55555555-5555-5555-5555-555555555555', 'SP-09 test', 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc', 'REQUESTED', now()),
('d047d047-d047-d047-d047-d047d047d047', 'ca07ca07-ca07-ca07-ca07-ca07ca07ca07', '55555555-5555-5555-5555-555555555555', 'SP-10 test', 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd', 'REQUESTED', now());
RESET ROLE;

-- === TESTS ===
-- SP-01: CANCELLED Epoch -> DRAFT = FAIL (by bgp_dividend, which has UPDATE on state)
\echo 'SP-01: CANCELLED -> DRAFT = FAIL'
SET search_path TO binggoplus_v2; SET ROLE bgp_dividend;
DO $$ BEGIN UPDATE dividend_epochs SET state = 'DRAFT' WHERE epoch_id = 1::numeric; RAISE NOTICE 'SP-01: UNEXPECTED PASS'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'SP-01: PASS %', SQLERRM; END $$;

-- SP-02: CLOSED Epoch -> DRAFT = FAIL
\echo 'SP-02: CLOSED -> DRAFT = FAIL'
DO $$ BEGIN UPDATE dividend_epochs SET state = 'DRAFT' WHERE epoch_id = 2::numeric; RAISE NOTICE 'SP-02: UNEXPECTED PASS'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'SP-02: PASS %', SQLERRM; END $$;

-- SP-03: CLAIM_OPEN modify merkle_root = FAIL (bgp_dividend doesn't have UPDATE on merkle_root — projector-only column)
\echo 'SP-03: CLAIM_OPEN modify merkle_root = FAIL'
DO $$ BEGIN UPDATE dividend_epochs SET merkle_root = '0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc' WHERE epoch_id = 3::numeric; RAISE NOTICE 'SP-03: UNEXPECTED PASS'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'SP-03: PASS %', SQLERRM; END $$;
RESET ROLE;

-- SP-04: FINALIZED -> QUEUED = FAIL (bgp_reconciler)
\echo 'SP-04: FINALIZED -> QUEUED = FAIL'
SET ROLE bgp_reconciler;
DO $$ BEGIN UPDATE governance_commands SET state = 'QUEUED' WHERE id = 'c401c401-c401-c401-c401-c401c401c401'; RAISE NOTICE 'SP-04: UNEXPECTED PASS'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'SP-04: PASS %', SQLERRM; END $$;

-- SP-05: CANCELLED -> SIGNING = FAIL
\echo 'SP-05: CANCELLED -> SIGNING = FAIL'
DO $$ BEGIN UPDATE governance_commands SET state = 'SIGNING' WHERE id = 'c502c502-c502-c502-c502-c502c502c502'; RAISE NOTICE 'SP-05: UNEXPECTED PASS'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'SP-05: PASS %', SQLERRM; END $$;

-- SP-06: FAILED -> APPROVED = FAIL
\echo 'SP-06: FAILED -> APPROVED = FAIL'
DO $$ BEGIN UPDATE governance_commands SET state = 'APPROVED' WHERE id = 'c603c603-c603-c603-c603-c603c603c603'; RAISE NOTICE 'SP-06: UNEXPECTED PASS'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'SP-06: PASS %', SQLERRM; END $$;

-- SP-07: APPROVED + REQUESTED cancellation -> SIGNING = FAIL
\echo 'SP-07: APPROVED + REQUESTED cancel -> SIGNING = FAIL'
DO $$ BEGIN UPDATE governance_commands SET state = 'SIGNING' WHERE id = 'c704c704-c704-c704-c704-c704c704c704'; RAISE NOTICE 'SP-07: UNEXPECTED PASS'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'SP-07: PASS %', SQLERRM; END $$;

-- SP-08: APPROVED + REQUESTED cancel -> CONSUMED = SUCCESS
\echo 'SP-08: APPROVED + REQUESTED cancel -> CONSUMED'
DO $$ BEGIN UPDATE governance_command_cancellation_requests SET state = 'CONSUMED', resolved_at = now() WHERE command_id = 'c805c805-c805-c805-c805-c805c805c805'; RAISE NOTICE 'SP-08: PASS'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'SP-08: FAIL %', SQLERRM; END $$;

-- SP-09: REJECTED + REQUESTED cancel -> REJECTED = SUCCESS
\echo 'SP-09: REJECTED + REQUESTED cancel -> REJECTED'
DO $$ BEGIN UPDATE governance_command_cancellation_requests SET state = 'REJECTED', resolved_at = now() WHERE command_id = 'c906c906-c906-c906-c906-c906c906c906'; RAISE NOTICE 'SP-09: PASS'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'SP-09: FAIL %', SQLERRM; END $$;

-- SP-10: CANCELLED + REQUESTED cancel -> CONSUMED = SUCCESS
\echo 'SP-10: CANCELLED + REQUESTED cancel -> CONSUMED'
DO $$ BEGIN UPDATE governance_command_cancellation_requests SET state = 'CONSUMED', resolved_at = now() WHERE command_id = 'ca07ca07-ca07-ca07-ca07-ca07ca07ca07'; RAISE NOTICE 'SP-10: PASS'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'SP-10: FAIL %', SQLERRM; END $$;

-- SP-11: Binding mutation guard (bgp_reconciler cannot modify target_contract_key)
\echo 'SP-11: Binding mutation guard'
DO $$ BEGIN UPDATE governance_commands SET target_contract_key = 'OtherRouter' WHERE id = 'cb08cb08-cb08-cb08-cb08-cb08cb08cb08'; RAISE NOTICE 'SP-11: UNEXPECTED PASS'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'SP-11: PASS %', SQLERRM; END $$;
RESET ROLE;

-- Cleanup (remove child rows first, then parent)
\echo '--- CLEANUP ---'
DELETE FROM binggoplus_v2.governance_command_cancellation_requests WHERE id IN ('d014d014-d014-d014-d014-d014d014d014','d025d025-d025-d025-d025-d025d025d025','d036d036-d036-d036-d036-d036d036d036','d047d047-d047-d047-d047-d047d047d047');
DELETE FROM binggoplus_v2.governance_commands WHERE id IN ('c401c401-c401-c401-c401-c401c401c401','c502c502-c502-c502-c502-c502c502c502','c603c603-c603-c603-c603-c603c603c603','c704c704-c704-c704-c704-c704c704c704','c805c805-c805-c805-c805-c805c805c805','c906c906-c906-c906-c906-c906c906c906','ca07ca07-ca07-ca07-ca07-ca07ca07ca07','cb08cb08-cb08-cb08-cb08-cb08cb08cb08');
DELETE FROM binggoplus_v2.dividend_epochs WHERE id IN ('ee01ee01-ee01-ee01-ee01-ee01ee01ee01','ee02ee02-ee02-ee02-ee02-ee02ee02ee02','ee03ee03-ee03-ee03-ee03-ee03ee03ee03');
DELETE FROM binggoplus_v2.chain_blocks WHERE id IN ('cc11cc11-cc11-cc11-cc11-cc11cc11cc11','cc22cc22-cc22-cc22-cc22-cc22cc22cc22');
DELETE FROM binggoplus_v2.deployment_sets WHERE id = 'bbbb2222-bbbb-2222-bbbb-222222222222';
DELETE FROM binggoplus_v2.environments WHERE id = 'aaaa1111-aaaa-1111-aaaa-111111111111';
DELETE FROM binggoplus_v2.admin_users WHERE id = '55555555-5555-5555-5555-555555555555';

\echo '=== STATE PROTECTION TESTS COMPLETE ==='
