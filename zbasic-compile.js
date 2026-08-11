#!/usr/bin/env node
const peg = require("pegjs");
const fs = require("fs");
const path = require("path");

// ── The parser ────────────────────────────────────────────────
const grammar = fs.readFileSync("zbasic.pegjs", "utf8");
const parserSource = peg.generate(grammar, {cache: true, output: "source"});
fs.writeFileSync("zbasic-compiled.js", `var ZBasicParser = ${parserSource};\n`);
console.log("Written zbasic-compiled.js");

// ── The program list ──────────────────────────────────────────
// Served over HTTP there is no directory listing, so the picker in index.html
// needs the set of programs and each one's files written down. "Open Folder"
// does not need this and keeps working for anything not in the list.
const ROOT = "progs/extracted";

// Same rule the interpreter's autoSelectFile() uses: prefer a .MAIN, otherwise
// take the sole .txt. A directory with neither is not a program we can start.
function pickMain(files) {
  const main = files.find(f => f.toUpperCase().endsWith(".MAIN"));
  if (main) return main;
  const txt = files.filter(f => f.toLowerCase().endsWith(".txt"));
  return txt.length === 1 ? txt[0] : null;
}

function listFiles(dir, base = "") {
  const out = [];
  for (const e of fs.readdirSync(path.join(dir, base), {withFileTypes: true})) {
    const rel = base ? `${base}/${e.name}` : e.name;
    if (e.isDirectory()) out.push(...listFiles(dir, rel));
    else out.push(rel);
  }
  return out;
}

const programs = [];
if (fs.existsSync(ROOT)) {
  for (const name of fs.readdirSync(ROOT).sort()) {
    const dir = path.join(ROOT, name);
    if (!fs.statSync(dir).isDirectory()) continue;
    const files = listFiles(dir);
    const main = pickMain(files.map(f => path.basename(f)));
    if (!main) { console.log(`  skipping ${name} — no .MAIN and no single .txt`); continue; }
    programs.push({name, dir: `${ROOT}/${name}`, main, files});
  }
}
fs.writeFileSync("progs/programs.json", JSON.stringify(programs, null, 2) + "\n");
console.log(`Written progs/programs.json — ${programs.map(p => p.name).join(", ")}`);
