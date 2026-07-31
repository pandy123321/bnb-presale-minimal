const fs = require('fs');
const path = require('path');
const solc = require('solc');

const root = path.resolve(__dirname, '..');
const sources = {};
const importPattern = /import\s+(?:[^"']*?from\s+)?["']([^"']+)["']\s*;/g;

function fsPathForSourceKey(key) {
  if (key.startsWith('@openzeppelin/contracts/')) {
    return path.join(root, 'lib/openzeppelin-contracts', key.slice('@openzeppelin/contracts/'.length));
  }
  return path.join(root, key);
}

function normalizeImport(fromKey, imported) {
  if (imported.startsWith('@openzeppelin/contracts/')) return imported;
  if (imported.startsWith('.')) return path.posix.normalize(path.posix.join(path.posix.dirname(fromKey), imported));
  return imported;
}

function addSource(key) {
  if (sources[key]) return;
  const filePath = fsPathForSourceKey(key);
  if (!fs.existsSync(filePath)) throw new Error(`Missing source ${key} -> ${filePath}`);
  const content = fs.readFileSync(filePath, 'utf8');
  sources[key] = { content };
  for (const match of content.matchAll(importPattern)) addSource(normalizeImport(key, match[1]));
}

function addProjectTree(dir) {
  const full = path.join(root, dir);
  for (const ent of fs.readdirSync(full, { withFileTypes: true })) {
    const rel = path.posix.join(dir, ent.name);
    if (ent.isDirectory()) addProjectTree(rel);
    else if (ent.isFile() && ent.name.endsWith('.sol')) addSource(rel);
  }
}

for (const dir of ['src', 'test', 'script']) addProjectTree(dir);

const input = {
  language: 'Solidity',
  sources,
  settings: {
    optimizer: { enabled: true, runs: 200 },
    evmVersion: 'paris',
    metadata: { bytecodeHash: 'none', appendCBOR: false },
    outputSelection: { '*': { '*': ['abi', 'evm.bytecode.object', 'evm.deployedBytecode.object'] } },
  },
};

const output = JSON.parse(solc.compile(JSON.stringify(input)));
const diagnostics = output.errors || [];
for (const diagnostic of diagnostics) console.log(`${diagnostic.severity.toUpperCase()}: ${diagnostic.formattedMessage}`);
if (diagnostics.some((diagnostic) => diagnostic.severity === 'error')) process.exit(1);

const contract = output.contracts['src/BNBPresale.sol'].BNBPresale;
const summary = {
  solc: solc.version(),
  source_units: Object.keys(output.contracts).length,
  warnings: diagnostics.filter((diagnostic) => diagnostic.severity === 'warning').map((diagnostic) => diagnostic.formattedMessage),
  creation_bytes: contract.evm.bytecode.object.length / 2,
  runtime_bytes: contract.evm.deployedBytecode.object.length / 2,
};

const outputDir = path.join(root, 'reports/remediation-build');
fs.mkdirSync(outputDir, { recursive: true });
fs.writeFileSync(path.join(outputDir, 'solc-output-summary.json'), `${JSON.stringify(summary, null, 2)}\n`);
fs.writeFileSync(path.join(outputDir, 'BNBPresale.abi.json'), `${JSON.stringify(contract.abi, null, 2)}\n`);
console.log(`BNBPresale creation bytes=${summary.creation_bytes}`);
console.log(`BNBPresale runtime bytes=${summary.runtime_bytes}`);
console.log(`compiled source units=${summary.source_units}`);
