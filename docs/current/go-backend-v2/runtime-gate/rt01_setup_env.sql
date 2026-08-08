-- RT-GATE-01 Environment Setup: Create database and roles
-- Run as postgres superuser

-- Create isolated database
DROP DATABASE IF EXISTS binggoplus_go;
CREATE DATABASE binggoplus_go;

-- Create 8 LOGIN roles with minimal cluster privileges
-- All roles: NO SUPERUSER, NO CREATEDB, NO CREATEROLE, NO BYPASSRLS

DROP ROLE IF EXISTS bgp_migrator;
CREATE ROLE bgp_migrator LOGIN PASSWORD 'bgp_migrator_pwd_rt_gate_01' NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

DROP ROLE IF EXISTS bgp_api;
CREATE ROLE bgp_api LOGIN PASSWORD 'bgp_api_pwd_rt_gate_01' NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

DROP ROLE IF EXISTS bgp_indexer;
CREATE ROLE bgp_indexer LOGIN PASSWORD 'bgp_indexer_pwd_rt_gate_01' NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

DROP ROLE IF EXISTS bgp_projector;
CREATE ROLE bgp_projector LOGIN PASSWORD 'bgp_projector_pwd_rt_gate_01' NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

DROP ROLE IF EXISTS bgp_dividend;
CREATE ROLE bgp_dividend LOGIN PASSWORD 'bgp_dividend_pwd_rt_gate_01' NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

DROP ROLE IF EXISTS bgp_reconciler;
CREATE ROLE bgp_reconciler LOGIN PASSWORD 'bgp_reconciler_pwd_rt_gate_01' NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

DROP ROLE IF EXISTS bgp_auditor;
CREATE ROLE bgp_auditor LOGIN PASSWORD 'bgp_auditor_pwd_rt_gate_01' NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

DROP ROLE IF EXISTS bgp_readonly;
CREATE ROLE bgp_readonly LOGIN PASSWORD 'bgp_readonly_pwd_rt_gate_01' NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

-- Grant CONNECT and minimal privileges to bgp_migrator on binggoplus_go
-- bgp_migrator must own the schema for migration
GRANT CONNECT ON DATABASE binggoplus_go TO bgp_migrator;
ALTER DATABASE binggoplus_go OWNER TO bgp_migrator;

-- Grant CONNECT to all runtime roles
GRANT CONNECT ON DATABASE binggoplus_go TO bgp_api, bgp_indexer, bgp_projector, bgp_dividend, bgp_reconciler, bgp_auditor, bgp_readonly;
