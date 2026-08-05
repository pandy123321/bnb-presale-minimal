-- Migration: add log_index to transaction_projections primary key
-- Purpose: allow multiple events in the same block+tx to be projected correctly.
-- Without log_index, the (chain_id, transaction_hash, block_number) unique constraint
-- would silently drop subsequent logs from the same transaction.

BEGIN;

-- 1. Drop the old primary key (or unique constraint)
ALTER TABLE transaction_projections
  DROP CONSTRAINT IF EXISTS transaction_projections_pkey;

-- 2. Add the log_index column if missing (default 0 for legacy rows)
ALTER TABLE transaction_projections
  ADD COLUMN IF NOT EXISTS log_index INTEGER DEFAULT 0;

-- 3. Set the new composite primary key
ALTER TABLE transaction_projections
  ADD PRIMARY KEY (chain_id, transaction_hash, block_number, log_index);

COMMIT;
