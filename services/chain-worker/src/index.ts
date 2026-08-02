// PANGU2 Chain Worker — Entry Point
// Starts the event scanner, reorg detector, and projector.

import { start } from "./workers/event-scanner";
import { startReorgDetection } from "./workers/reorg-detector";

async function main() {
  console.log("═════════════════════════════════");
  console.log("  PANGU2 Chain Worker");
  console.log("═════════════════════════════════");

  await start();
  await startReorgDetection();
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
