/**
 * Verify that all required contract ABIs exist, are parseable,
 * and contain valid event signatures.
 *
 * Called by CI after forge build to prove the chain-worker
 * can actually load and use the generated artifacts.
 *
 * Usage: npx tsx scripts/verify-abi-artifacts.ts
 */

import { loadAbi, extractEventSignatures, REQUIRED_ABI_NAMES } from "../src/abi/loader";

function fail(msg: string): never {
  console.error(`\nABI SMOKE FAIL: ${msg}`);
  process.exit(1);
}

function main() {
  let ok = 0;
  let missing: string[] = [];

  for (const name of REQUIRED_ABI_NAMES) {
    const artifact = loadAbi(name);

    if (!artifact) {
      missing.push(name);
      continue;
    }

    // --- Validate ABI structure ---
    if (!Array.isArray(artifact.abi)) {
      fail(`"${name}" artifact has no "abi" array`);
    }
    if (artifact.abi.length === 0) {
      fail(`"${name}" artifact has empty "abi" array`);
    }

    // --- Validate event signatures ---
    const sigs = extractEventSignatures(artifact);
    if (sigs.size === 0) {
      console.warn(`  ⚠  ${name}: no events found in ABI (may be intentional)`);
    } else {
      console.log(`  ✓  ${name}: ${sigs.size} event(s), ${artifact.abi.length} ABI entries`);
    }

    ok++;
  }

  // --- Report ---
  console.log(`\n${ok}/${REQUIRED_ABI_NAMES.length} contract ABIs loaded successfully`);

  if (missing.length > 0) {
    fail(`Missing ABIs: ${missing.join(", ")}`);
  }

  console.log("✓ ABI smoke test passed\n");
}

main();
