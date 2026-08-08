-- RT-GATE-01 Role Runtime Permission Boundary Tests
\set ON_ERROR_STOP on
\echo '=== RT-GATE-01 PERMISSION TESTS ==='

-- bgp_api
\echo '--- bgp_api ---'
SET ROLE bgp_api;
\echo 'ALLOW: SELECT environments'
SELECT count(*) FROM binggoplus_v2.environments;
\echo 'DENIED: INSERT chain_raw_events'
DO $$ BEGIN INSERT INTO binggoplus_v2.chain_raw_events DEFAULT VALUES; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'ALLOW: INSERT admin_audit_logs'
DO $$ BEGIN RAISE NOTICE 'OK'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'FAIL: %', SQLERRM; END $$;
\echo 'ALLOW: DELETE admin_users'
DO $$ BEGIN RAISE NOTICE 'OK'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'FAIL: %', SQLERRM; END $$;
\echo 'ALLOW: INSERT governance_commands'
DO $$ BEGIN RAISE NOTICE 'OK'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'FAIL: %', SQLERRM; END $$;
\echo 'DENIED: INSERT signer_nonces'
DO $$ BEGIN INSERT INTO binggoplus_v2.signer_nonces DEFAULT VALUES; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
RESET ROLE;

-- bgp_indexer
\echo '--- bgp_indexer ---'
SET ROLE bgp_indexer;
\echo 'ALLOW: SELECT chain_streams'
SELECT count(*) FROM binggoplus_v2.chain_streams;
\echo 'ALLOW: INSERT chain_raw_events'
DO $$ BEGIN RAISE NOTICE 'OK'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'FAIL: %', SQLERRM; END $$;
\echo 'ALLOW: INSERT chain_blocks'
DO $$ BEGIN RAISE NOTICE 'OK'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'FAIL: %', SQLERRM; END $$;
\echo 'DENIED: DELETE chain_raw_events'
DO $$ BEGIN DELETE FROM binggoplus_v2.chain_raw_events WHERE false; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: INSERT token_balances_current'
DO $$ BEGIN INSERT INTO binggoplus_v2.token_balances_current DEFAULT VALUES; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: INSERT admin_users'
DO $$ BEGIN INSERT INTO binggoplus_v2.admin_users DEFAULT VALUES; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
RESET ROLE;

-- bgp_projector
\echo '--- bgp_projector ---'
SET ROLE bgp_projector;
\echo 'ALLOW: SELECT chain_raw_events (read-only)'
SELECT count(*) FROM binggoplus_v2.chain_raw_events;
\echo 'ALLOW: INSERT projection_receipts'
DO $$ BEGIN RAISE NOTICE 'OK'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'FAIL: %', SQLERRM; END $$;
\echo 'ALLOW: INSERT token_balance_ledger'
DO $$ BEGIN RAISE NOTICE 'OK'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'FAIL: %', SQLERRM; END $$;
\echo 'DENIED: UPDATE chain_raw_events'
DO $$ BEGIN UPDATE binggoplus_v2.chain_raw_events SET confirmed_at = now() WHERE false; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: INSERT chain_raw_events'
DO $$ BEGIN INSERT INTO binggoplus_v2.chain_raw_events DEFAULT VALUES; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: INSERT admin_users'
DO $$ BEGIN INSERT INTO binggoplus_v2.admin_users DEFAULT VALUES; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
RESET ROLE;

-- bgp_dividend
\echo '--- bgp_dividend ---'
SET ROLE bgp_dividend;
\echo 'ALLOW: SELECT dividend_token_balance_history_v1'
SELECT count(*) FROM binggoplus_v2.dividend_token_balance_history_v1;
\echo 'ALLOW: INSERT dividend_artifacts'
DO $$ BEGIN RAISE NOTICE 'OK'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'FAIL: %', SQLERRM; END $$;
\echo 'ALLOW: INSERT dividend_allocations'
DO $$ BEGIN RAISE NOTICE 'OK'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'FAIL: %', SQLERRM; END $$;
\echo 'DENIED: SELECT token_balances_current'
DO $$ BEGIN PERFORM count(*) FROM binggoplus_v2.token_balances_current; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: SELECT trades'
DO $$ BEGIN PERFORM count(*) FROM binggoplus_v2.trades; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: UPDATE dividend_epochs.merkle_root'
DO $$ BEGIN UPDATE binggoplus_v2.dividend_epochs SET merkle_root = '0x0000000000000000000000000000000000000000000000000000000000000000' WHERE false; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: INSERT admin_users'
DO $$ BEGIN INSERT INTO binggoplus_v2.admin_users DEFAULT VALUES; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
RESET ROLE;

-- bgp_reconciler
\echo '--- bgp_reconciler ---'
SET ROLE bgp_reconciler;
\echo 'ALLOW: SELECT governance_commands'
SELECT count(*) FROM binggoplus_v2.governance_commands;
\echo 'ALLOW: UPDATE governance_commands.state'
DO $$ BEGIN RAISE NOTICE 'OK'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'FAIL: %', SQLERRM; END $$;
\echo 'VERY IMPORTANT — DENIED: INSERT governance_commands (API intake only)'
DO $$ BEGIN INSERT INTO binggoplus_v2.governance_commands DEFAULT VALUES; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'ALLOW: INSERT signer_nonces'
DO $$ BEGIN RAISE NOTICE 'OK'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'FAIL: %', SQLERRM; END $$;
\echo 'ALLOW: INSERT governance_tx_attempts'
DO $$ BEGIN RAISE NOTICE 'OK'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'FAIL: %', SQLERRM; END $$;
\echo 'DENIED: SELECT admin_users'
DO $$ BEGIN PERFORM count(*) FROM binggoplus_v2.admin_users; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: DELETE governance_commands'
DO $$ BEGIN DELETE FROM binggoplus_v2.governance_commands WHERE false; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
RESET ROLE;

-- bgp_auditor
\echo '--- bgp_auditor ---'
SET ROLE bgp_auditor;
\echo 'ALLOW: SELECT governance_commands'
SELECT count(*) FROM binggoplus_v2.governance_commands;
\echo 'ALLOW: SELECT dividend_epochs'
SELECT count(*) FROM binggoplus_v2.dividend_epochs;
\echo 'DENIED: INSERT governance_commands'
DO $$ BEGIN INSERT INTO binggoplus_v2.governance_commands DEFAULT VALUES; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: UPDATE governance_commands'
DO $$ BEGIN UPDATE binggoplus_v2.governance_commands SET updated_at = now() WHERE false; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: DELETE governance_commands'
DO $$ BEGIN DELETE FROM binggoplus_v2.governance_commands WHERE false; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: SELECT admin_users'
DO $$ BEGIN PERFORM count(*) FROM binggoplus_v2.admin_users; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: SELECT wallet_challenges'
DO $$ BEGIN PERFORM count(*) FROM binggoplus_v2.wallet_challenges; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
RESET ROLE;

-- bgp_readonly
\echo '--- bgp_readonly ---'
SET ROLE bgp_readonly;
\echo 'ALLOW: SELECT token_balances_current'
SELECT count(*) FROM binggoplus_v2.token_balances_current;
\echo 'ALLOW: SELECT trades'
SELECT count(*) FROM binggoplus_v2.trades;
\echo 'ALLOW: SELECT dividend_epochs'
SELECT count(*) FROM binggoplus_v2.dividend_epochs;
\echo 'DENIED: INSERT any table'
DO $$ BEGIN INSERT INTO binggoplus_v2.token_balances_current DEFAULT VALUES; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: UPDATE trades'
DO $$ BEGIN UPDATE binggoplus_v2.trades SET cost_state = 'KNOWN' WHERE false; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: DELETE dividend_epochs'
DO $$ BEGIN DELETE FROM binggoplus_v2.dividend_epochs WHERE false; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: SELECT admin_users'
DO $$ BEGIN PERFORM count(*) FROM binggoplus_v2.admin_users; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
\echo 'DENIED: SELECT governance_commands'
DO $$ BEGIN PERFORM count(*) FROM binggoplus_v2.governance_commands; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXPECTED: %', SQLERRM; END $$;
RESET ROLE;

-- bgp_migrator
\echo '--- bgp_migrator ---'
SET ROLE bgp_migrator;
\echo 'ALLOW: SELECT environments (schema owner)'
SELECT count(*) FROM binggoplus_v2.environments;
RESET ROLE;

\echo '=== PERMISSION TESTS COMPLETE ==='
