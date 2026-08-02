// ═══════════════════════════════════════════
// PANGU2 — Solidity Compilation Script v2
// Uses solc with import callback for remappings.
// ═══════════════════════════════════════════

const fs = require("fs");
const path = require("path");
const solc = require("solc");

const CONTRACTS_DIR = __dirname;
const SRC_DIR = path.join(CONTRACTS_DIR, "src");
const OUT_DIR = path.join(CONTRACTS_DIR, "out");
const REMAPPINGS_FILE = path.join(CONTRACTS_DIR, "remappings.txt");
const OZ_DIR = path.join(CONTRACTS_DIR, "lib", "openzeppelin-contracts", "contracts");
const FOUNDRY_LIB = path.join(CONTRACTS_DIR, "lib");

function parseRemappings() {
  const lines = fs.readFileSync(REMAPPINGS_FILE, "utf8").split("\n").filter(Boolean);
  const map = {};
  for (const line of lines) {
    const parts = line.split("=");
    if (parts.length >= 2) {
      map[parts[0]] = path.resolve(CONTRACTS_DIR, parts[1]).replace(/\\/g, "/");
    }
  }
  return map;
}

function findSolFiles(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return findSolFiles(full);
    if (entry.name.endsWith(".sol")) return [full];
    return [];
  });
}

function readAllSources() {
  const sources = {};
  const allDirs = [SRC_DIR];
  if (fs.existsSync(OZ_DIR)) allDirs.push(OZ_DIR);

  if (fs.existsSync(FOUNDRY_LIB)) {
    for (const lib of fs.readdirSync(FOUNDRY_LIB)) {
      const contractsDir = path.join(FOUNDRY_LIB, lib, "contracts");
      if (fs.existsSync(contractsDir)) allDirs.push(contractsDir);
      const srcDir = path.join(FOUNDRY_LIB, lib, "src");
      if (fs.existsSync(srcDir)) allDirs.push(srcDir);
    }
  }

  for (const dir of allDirs) {
    for (const file of findSolFiles(dir)) {
      const rel = path.relative(CONTRACTS_DIR, file).replace(/\\/g, "/");
      sources[rel] = { content: fs.readFileSync(file, "utf8") };
    }
  }
  return sources;
}

function resolveImport(importPath, remappings, fileSystem) {
  for (const [prefix, dest] of Object.entries(remappings)) {
    if (importPath.startsWith(prefix)) {
      const resolved = path.resolve(dest, importPath.slice(prefix.length)).replace(/\\/g, "/");
      const rel = path.relative(CONTRACTS_DIR, resolved).replace(/\\/g, "/");
      if (fileSystem[rel]) return rel;
    }
  }

  const rootRel = path.relative(CONTRACTS_DIR, path.resolve(CONTRACTS_DIR, importPath)).replace(/\\/g, "/");
  if (fileSystem[rootRel]) return rootRel;

  const ozRel = path.relative(CONTRACTS_DIR, path.resolve(OZ_DIR, importPath)).replace(/\\/g, "/");
  if (fileSystem[ozRel]) return ozRel;

  return null;
}

function main() {
  const remappings = parseRemappings();
  console.log("[compile] Remappings:", JSON.stringify(remappings, null, 2));

  const sources = readAllSources();
  const sourceKeys = Object.keys(sources);
  console.log(`[compile] Total source files: ${sourceKeys.length}`);

  const srcOnly = sourceKeys.filter((k) => k.startsWith("src/"));
  console.log(`[compile] Project contracts (${srcOnly.length}):`, srcOnly);

  const fileSystem = {};
  for (const key of sourceKeys) fileSystem[key] = sources[key];

  function findImports(importPath) {
    const resolved = resolveImport(importPath, remappings, fileSystem);
    if (resolved) {
      return { contents: fileSystem[resolved].content };
    }
    console.error(`[compile] Import NOT FOUND: ${importPath}`);
    return { error: `File not found: ${importPath}` };
  }

  const input = {
    language: "Solidity",
    sources,
    settings: {
      optimizer: { enabled: true, runs: 200 },
      viaIR: true,
      evmVersion: "paris",
      outputSelection: {
        "*": {
          "*": ["abi", "evm.bytecode.object", "evm.deployedBytecode.object"],
        },
      },
    },
  };

  console.log("[compile] Compiling...");
  const output = JSON.parse(
    solc.compile(JSON.stringify(input), { import: findImports }),
  );

  if (output.errors) {
    const errors = output.errors.filter((e) => e.severity === "error");
    const warnings = output.errors.filter((e) => e.severity === "warning");
    if (warnings.length) {
      console.warn(`[compile] ${warnings.length} warning(s)`);
      for (const w of warnings.slice(0, 5)) console.warn("  ", w.formattedMessage);
    }
    if (errors.length) {
      console.error(`[compile] ${errors.length} error(s):`);
      for (const err of errors) console.error(err.formattedMessage);
      return;
    }
  }

  if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });

  let contractCount = 0;
  for (const [sourceName, sourceOutput] of Object.entries(output.contracts || {})) {
    for (const [contractName, contractData] of Object.entries(sourceOutput)) {
      const contractDir = path.join(OUT_DIR, contractName + ".sol");
      if (!fs.existsSync(contractDir)) fs.mkdirSync(contractDir, { recursive: true });

      fs.writeFileSync(
        path.join(contractDir, contractName + ".json"),
        JSON.stringify({
          abi: contractData.abi,
          bytecode: { object: contractData.evm?.bytecode?.object || "" },
          deployedBytecode: { object: contractData.evm?.deployedBytecode?.object || "" },
        }, null, 2),
      );
      contractCount++;
      console.log(`[compile] ✓ ${contractName} — ${contractData.abi.length} ABI entries`);
    }
  }

  console.log(`\n[compile] Done! ${contractCount} contracts → ${OUT_DIR}`);
}

main();
