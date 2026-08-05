// PANGU2 Chain Worker — Entry Point
// Starts Scanner, Confirmation Worker, Projection Worker, and Reorg Detector.

import { start } from "./workers/event-scanner";
import { startConfirmationWorker } from "./workers/confirmation-worker";
import { startProjectionWorker } from "./workers/projection-worker";
import { startReorgDetection } from "./workers/reorg-detector";

async function main() {
  console.log("═════════════════════════════════");
  console.log("  PANGU2 Chain Worker");
  console.log("═════════════════════════════════");

  await start();                    // Scanner
  await startConfirmationWorker();  // Confirmation
  await startProjectionWorker();    // Projection
  await startReorgDetection();      // Reorg Detection
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
