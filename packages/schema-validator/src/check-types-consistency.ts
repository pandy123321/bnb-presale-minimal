#!/usr/bin/env tsx
// PANGU2 — TypeScript types vs OpenAPI Consistency Checker
import { readFileSync } from "fs";
import { resolve } from "path";
import { parse as parseYaml } from "yaml";

const OPENAPI_PATH = resolve(__dirname, "../../../docs/schemas/openapi/pangu2-api-v1.yaml");
const API_TYPES_DIR = resolve(__dirname, "../../api-types/src");
const STATE_MACHINES_PATH = resolve(__dirname, "../../../docs/schemas/state-machines/pangu2-state-machines-v1.json");
const ERRORS_PATH = resolve(__dirname, "../../../docs/schemas/errors/pangu2-errors-v1.json");

function loadYaml(p: string) { return parseYaml(readFileSync(p, "utf-8")); }
function loadJson(p: string) { return JSON.parse(readFileSync(p, "utf-8")); }

function parseTsFile(p: string) {
  const c = readFileSync(p, "utf-8");
  const enums = new Map<string, string[]>();
  const ifaces = new Map<string, string[]>();
  for (const m of c.matchAll(/export const (\w+)\s*=\s*\{([^}]*)\}/g)) {
    enums.set(m[1], m[2].split(/[\n,]+/).map(s=>s.trim().split(":")[0]?.trim()).filter(Boolean).map(s=>s.replace(/^["']|["']$/g,"")));
  }
  for (const m of c.matchAll(/export interface (\w+)\s*\{([^}]*)\}/g)) {
    ifaces.set(m[1], (m[2].match(/(\w+)\??\s*:/g)??[]).map(s=>s.replace(/[?:]/g,"").trim()).filter(Boolean));
  }
  return { enums, ifaces };
}

const results: Array<{check:string, passed:boolean, detail:string}> = [];
function r(c: string, p: boolean, d: string) { results.push({check:c,passed:p,detail:d}); console.log(`  ${p?"✓":"✗"} ${c}${d?` — ${d}`:""}`); }

function checkEnum(oa: string[], ts: string[], name: string) {
  const o=new Set(oa), t=new Set(ts);
  const m=[...o].filter(v=>!t.has(v)), e=[...t].filter(v=>!o.has(v));
  r(`${name} enum`, m.length===0&&e.length===0, m.length?`Missing in TS: [${m}]`:e.length?`Extra in TS: [${e}]`:``);
}

function checkFields(oa: string[], ts: string[], name: string) {
  const o=new Set(oa), t=new Set(ts);
  const m=[...o].filter(v=>!t.has(v));
  r(`${name} fields`, m.length===0, m.length?`Missing in TS: [${m}]`:`match`);
}

function main() {
  console.log("═══ PANGU2 TypeScript ↔ OpenAPI Consistency Check ═══\n");
  const api = loadYaml(OPENAPI_PATH);
  const s = api.components?.schemas ?? {};
  const sm = loadJson(STATE_MACHINES_PATH);
  const er = loadJson(ERRORS_PATH);
  const { enums: e, ifaces: i } = parseTsFile(resolve(API_TYPES_DIR, "enums.ts"));
  const { ifaces: ai } = parseTsFile(resolve(API_TYPES_DIR, "api.ts"));
  const { enums: se } = parseTsFile(resolve(API_TYPES_DIR, "states.ts"));

  console.log("── Enums ──");
  checkEnum(s.DataStatus?.enum??[], e.get("DataStatus")??[], "DataStatus");
  checkEnum(s.TransactionInfo?.properties?.type?.enum??[], e.get("TransactionType")??[], "TransactionType");
  checkEnum(s.TransactionInfo?.properties?.status?.enum??[], e.get("TransactionStatus")??[], "TransactionStatus");
  checkEnum(["CONTRACT_PREVIEW","MOCK","UNAVAILABLE"], e.get("QuoteSource")??[], "QuoteSource");
  checkEnum(["PENDING","SNAPSHOT_COMPLETE","PROOF_GENERATED","CLAIM_OPEN","CLOSED"], e.get("EpochStatus")??[], "EpochStatus");
  checkEnum(s.EnvironmentConfig?.properties?.rpc_status?.enum??[], e.get("RpcStatus")??[], "RpcStatus");
  checkEnum(s.ContractInfo?.properties?.status?.enum??[], e.get("ContractStatus")??[], "ContractStatus");

  console.log("\n── API Interfaces ──");
  const m: Array<[string,string]> = [
    ["EnvelopeMeta","EnvelopeMeta"],["EnvironmentConfig","EnvironmentConfig"],["SystemStatus","SystemStatus"],
    ["ContractInfo","ContractInfo"],["NonceResponse","NonceResponse"],["SessionInfo","SessionInfo"],
    ["WalletSummary","WalletSummary"],["TransactionInfo","TransactionInfo"],["BuyQuote","BuyQuote"],
    ["SellQuote","SellQuote"],["EpochInfo","EpochInfo"],["PaginationMeta","PaginationMeta"]
  ];
  for (const [oa,ts] of m) {
    const of = Object.keys(s[oa]?.properties??{});
    const tf = ai.get(ts);
    if (!tf) { r(ts, false, "TS interface not found"); continue; }
    checkFields(of, tf, ts);
  }

  console.log("\n── State Machines ──");
  for (const [mn,tn] of [["wallet","WalletState"],["network","NetworkState"],["quote","QuoteState"],["approval","ApprovalState"],["chain_transaction","ChainTxState"],["claim","ClaimState"]]) {
    const j = (sm.machines?.[mn]?.states ?? []) as string[];
    const t = se.get(tn)??[];
    checkEnum(j, t, `${mn}/${tn}`);
  }

  console.log("\n── Error Codes ──");
  const ec = Object.keys(er.errors??{});
  r("26 error codes defined", ec.length===26, `found ${ec.length}`);
  r("All have categories", ec.every(k=>er.errors[k].category), "");
  r("All have http_status", ec.every(k=>typeof er.errors[k].http_status==="number"), "");

  const p = results.filter(x=>x.passed).length;
  console.log(`\n── Total: ${results.length} | Passed: ${p} | Failed: ${results.length-p} ──`);
  process.exit(results.length-p > 0 ? 1 : 0);
}
main();
