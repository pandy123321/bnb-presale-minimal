// PANGU2 Chain Worker — Projection Worker
// Projects CONFIRMED raw events into transaction_projections table.
// Each CONFIRMED raw event projects independently.
// Unique key includes log_index. Skips REORGED events.

import { getPool } from "../db/client";
import { CHAIN_ID } from "../config";

export async function startProjectionWorker(): Promise<void> {
  console.log("[Projection] Starting");
  await processProjections();
  setInterval(() => processProjections().catch(e => console.error("[Projection]", e)), 20_000);
}

async function processProjections(): Promise<void> {
  const pool = getPool();
  const db = await pool.connect();
  try {
    // Find unprojected CONFIRMED events — ignores REORGED
    const { rows } = await db.query(
      `SELECT e.* FROM chain_raw_events e
       WHERE e.chain_id = $1 AND e.status = 'CONFIRMED'
         AND NOT EXISTS (
           SELECT 1 FROM transaction_projections p
           WHERE p.chain_id = e.chain_id
             AND p.transaction_hash = e.transaction_hash
             AND p.block_number = e.block_number
             AND p.log_index = e.log_index
         )
       ORDER BY e.block_number ASC, e.log_index ASC`,
      [CHAIN_ID],
    );

    if (rows.length === 0) return;

    let projected = 0;
    for (const row of rows) {
      const decoded = row.decoded_data as Record<string, unknown>;
      const eventName = row.event_name as string;

      let fromAddress = ""; let toAddress = ""; let amountRaw = "0";
      if (eventName === "BuyExecuted") {
        fromAddress = (decoded.buyer as string) ?? "";
        toAddress = row.contract_address as string;
        amountRaw = (decoded.bnbIn ?? decoded.netTokens ?? "0") as string;
      } else if (eventName === "SellExecuted") {
        fromAddress = (decoded.seller as string) ?? "";
        toAddress = row.contract_address as string;
        amountRaw = (decoded.bnbOut ?? decoded.tokenIn ?? "0") as string;
      } else if (eventName === "DividendClaimed") {
        fromAddress = row.contract_address as string;
        toAddress = (decoded.account as string) ?? "";
        amountRaw = (decoded.amount as string) ?? "0";
      } else {
        fromAddress = row.contract_address as string;
        toAddress = "";
        amountRaw = "0";
      }

      const logIndex = parseInt(row.log_index ?? "0");
      await db.query(
        `INSERT INTO transaction_projections
         (chain_id, transaction_hash, block_number, block_hash, event_name,
          contract_address, from_address, to_address, amount_raw, timestamp, status, log_index, created_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'CONFIRMED',$11,NOW())
         ON CONFLICT (chain_id, transaction_hash, block_number, log_index) DO NOTHING`,
        [CHAIN_ID, row.transaction_hash, row.block_number, row.block_hash, eventName,
         row.contract_address, fromAddress, toAddress, String(amountRaw), row.block_timestamp, logIndex],
      );
      projected++;
    }

    if (projected > 0) console.log(`[Projection] ${projected} events projected`);
  } catch (e) {
    console.error("[Projection]", e);
    throw e;
  } finally { db.release(); }
}
