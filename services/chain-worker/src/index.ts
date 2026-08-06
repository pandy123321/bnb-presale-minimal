// PANGU2 Chain Worker — Entry Point
// Verifies schema version before starting any workers.

import { verifySchemaVersion } from "./db/client";
import { start } from "./workers/event-scanner";
import { startConfirmationWorker } from "./workers/confirmation-worker";
import { startProjectionWorker } from "./workers/projection-worker";
import { startReorgDetection } from "./workers/reorg-detector";

async function main() {
  console.log("═════════════════════════════════");
  console.log("  PANGU2 Chain Worker");
  console.log("═════════════════════════════════");

  await verifySchemaVersion();
  console.log("[Startup] Schema version OK");

  await start();
  await startConfirmationWorker();
  await startProjectionWorker();
  await startReorgDetection();
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
