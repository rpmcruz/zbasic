#!/usr/bin/env node
const peg = require("pegjs");
const fs = require("fs");
const path = require("path");

// ── The parser ────────────────────────────────────────────────
const grammar = fs.readFileSync("zbasic.pegjs", "utf8");
const parserSource = peg.generate(grammar, {cache: true, output: "source"});
const compiled = `var ZBasicParser = ${parserSource};\n`;
fs.writeFileSync("zbasic-compiled.js", compiled);
console.log("Written zbasic-compiled.js");
// index.html loads the parser as zbasic-compiled.js?v=<hash of it>. Browsers
// cache scripts (GitHub Pages for ten minutes), and a cached parser of an older
// grammar with a newer index.html misreads programs; a new hash forces a fresh copy.
const hash = require("crypto").createHash("sha1").update(compiled).digest("hex").slice(0, 10);
const html = fs.readFileSync("index.html", "utf8");
const tagged = html.replace(/<script src="zbasic-compiled\.js(\?v=[0-9a-f]*)?"><\/script>/, `<script src="zbasic-compiled.js?v=${hash}"></script>`);
if (tagged !== html) { fs.writeFileSync("index.html", tagged); console.log(`index.html now loads zbasic-compiled.js?v=${hash}`); }

// ── The program list ──────────────────────────────────────────
// Served over HTTP there is no directory listing, so the picker in index.html
// needs the set of programs and each one's files written down. "Open Folder"
// does not need this and keeps working for anything not in the list.
const ROOT = "progs/extracted";

// Which file a program starts from — the same rule as autoSelectFile() in
// index.html. A PG:PRO project starts from its .MAIN. Otherwise the candidates
// are the text listings: the archives' own .txt exports and the listings
// recovered from ZBasic's tokenized sources (.detok.txt, see
// zbasic-detokenize.js). The windows, menus and pictures come from the
// application's resource fork, so prefer a listing of the version the
// application was built from ("grglflx27.exe" runs grglflx27, not the later
// grglflx28 work in progress), and among those the recovered one — the .txt
// exports are later and not always faithful (CDraw's is not even ZBasic).
function versionOf(name) {
  const m = name.replace(/\.(detok\.txt|txt|bas|exe|rsrc)$/gi, "").match(/(\d+(?:\.\d+)*)\D*$/);
  return m ? m[1] : null;
}
function pickMain(files) {
  const main = files.find(f => f.toUpperCase().endsWith(".MAIN"));
  if (main) return main;
  const app = files.find(f => f.toLowerCase().endsWith(".rsrc"));
  const want = app && versionOf(app);
  let txt = files.filter(f => f.toLowerCase().endsWith(".txt"));
  if (want && txt.some(f => versionOf(f) === want)) txt = txt.filter(f => versionOf(f) === want);
  const detok = txt.filter(f => f.toLowerCase().endsWith(".detok.txt"));
  if (detok.length === 1) return detok[0];
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
