-- RT-GATE-01 Object Validation
-- Execute as bgp_migrator (schema owner) against binggoplus_go / binggoplus_v2

\echo '=== SCHEMA OBJECTS ==='
\echo '--- TABLES ---'
SELECT tablename FROM pg_tables WHERE schemaname='binggoplus_v2' ORDER BY tablename;

\echo '--- VIEWS ---'
SELECT viewname FROM pg_views WHERE schemaname='binggoplus_v2' ORDER BY viewname;

\echo '--- FUNCTIONS ---'
SELECT proname, pronargs, prorettype::regtype FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace=n.oid
WHERE n.nspname='binggoplus_v2' ORDER BY proname;

\echo '--- TRIGGERS ---'
SELECT tgname, tgtype, tgenabled, tgrelid::regclass AS table_name
FROM pg_trigger
WHERE tgrelid::regclass::text LIKE 'binggoplus_v2.%' AND tgisinternal = false
ORDER BY tgname;

\echo '--- CONSTRAINTS (FK, Unique, Check) ---'
SELECT conname, contype, conrelid::regclass AS table_name, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE connamespace = (SELECT oid FROM pg_namespace WHERE nspname='binggoplus_v2')
ORDER BY contype, conname;

\echo '--- SEQUENCES ---'
SELECT sequencename FROM pg_sequences WHERE schemaname='binggoplus_v2' ORDER BY sequencename;

\echo '=== ROLE CLUSTER PRIVILEGES ==='
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolbypassrls, rolinherit
FROM pg_roles
WHERE rolname LIKE 'bgp_%'
ORDER BY rolname;

\echo '=== ROLE MEMBERSHIP (check no bgp_migrator inheritance) ==='
SELECT r.rolname AS member, rm.rolname AS role, m.admin_option
FROM pg_auth_members m
JOIN pg_roles r ON m.member = r.oid
JOIN pg_roles rm ON m.roleid = rm.oid
WHERE r.rolname LIKE 'bgp_%' OR rm.rolname LIKE 'bgp_%';

\echo '=== TABLE COUNT ==='
SELECT count(*) AS table_count FROM pg_tables WHERE schemaname='binggoplus_v2';
