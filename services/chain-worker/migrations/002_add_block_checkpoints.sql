-- Migration: add block checkpoints and schema versioning
-- Enables empty-block reorg detection and schema-aware startup.

BEGIN;

-- 1. Create settings table with schema version
CREATE TABLE IF NOT EXISTS chain_cursors_settings (
  id INTEGER PRIMARY KEY DEFAULT 1,
  schema_version INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO chain_cursors_settings (id, schema_version, updated_at)
  VALUES (1, 2, NOW())
  ON CONFLICT (id) DO UPDATE SET schema_version = 2, updated_at = NOW();

-- 2. Create block checkpoints table
CREATE TABLE IF NOT EXISTS chain_block_checkpoints (
  chain_id INTEGER NOT NULL,
  block_number INTEGER NOT NULL,
  block_hash VARCHAR NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (chain_id, block_number)
);

-- 3. Add log_index column to chain_cursors if it doesn't exist (for multi-stream support)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'chain_cursors' AND column_name = 'updated_at') THEN
    ALTER TABLE chain_cursors ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();
  END IF;
END $$;

COMMIT;

-- Rollback:
-- DROP TABLE IF EXISTS chain_block_checkpoints;
-- DROP TABLE IF EXISTS chain_cursors_settings;
