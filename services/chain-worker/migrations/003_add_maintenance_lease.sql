-- Migration v3: add global maintenance lease, hash-scoped reorg, checkpoint no-overwrite
-- This replaces the broken v2 approach in 002_add_block_checkpoints.sql
-- Rollback-safe: wrap in transaction

BEGIN;

-- 1. Add maintenance_lease_active column to chain_cursors (scanner checks before commit)
ALTER TABLE chain_cursors
  ADD COLUMN IF NOT EXISTS maintenance_lease_active BOOLEAN DEFAULT false;

-- 2. Rebuild chain_block_checkpoints with hash history (DO NOT silently overwrite)
DROP TABLE IF EXISTS chain_block_checkpoints;
CREATE TABLE chain_block_checkpoints (
  chain_id INTEGER NOT NULL,
  block_number INTEGER NOT NULL,
  block_hash VARCHAR NOT NULL,
  previous_hash VARCHAR,
  created_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (chain_id, block_number)
);

-- 3. Build checkpoint history table for detecting hash changes
CREATE TABLE IF NOT EXISTS chain_block_checkpoint_history (
  id SERIAL PRIMARY KEY,
  chain_id INTEGER NOT NULL,
  block_number INTEGER NOT NULL,
  old_block_hash VARCHAR NOT NULL,
  new_block_hash VARCHAR NOT NULL,
  detected_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cp_history_chain_block
  ON chain_block_checkpoint_history(chain_id, block_number);

-- 4. Reset schema version
INSERT INTO chain_cursors_settings (id, schema_version, updated_at)
  VALUES (1, 3, NOW())
  ON CONFLICT (id) DO UPDATE SET schema_version = 3, updated_at = NOW();

COMMIT;

-- Rollback:
-- ALTER TABLE chain_cursors DROP COLUMN IF EXISTS maintenance_lease_active;
-- DROP TABLE IF EXISTS chain_block_checkpoints;
-- DROP TABLE IF EXISTS chain_block_checkpoint_history;
-- UPDATE chain_cursors_settings SET schema_version = 2 WHERE id = 1;
