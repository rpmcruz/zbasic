#!/usr/bin/env node
// Turn ZBasic (Macintosh) tokenized source files back into text listings.
//
//   node zbasic-detokenize.js [file …]
//
// With no arguments it scans progs/extracted for tokenized sources and writes
// each one's listing next to it as "<name>.detok.txt".
//
// Why: the archives ship each program both as ZBasic's own saved (tokenized)
// source and as a text listing, and the listings are later exports that are not
// always faithful. CDraw's (from 2000, nine years after the program) is half
// translated into another BASIC: every PLOT became `PSet (x,y)` / `LINE (…)-(…)`,
// `PEN 1,1,,10` became `DrawWidth=1:DrawMode=7`, menu calls became
// `SaveFile.Enabled=True`, and four statements lost their beginning. The
// tokenized file is what the compiled program was actually built from.
//
// File format: a run of line records
//   u16 len · u16 line number · i16 (listing indent) · u16 0 · content · NUL [· pad]
// The next record starts at start+len+2. Keywords in the content are two-byte
// tokens whose first byte is >= 0xF0 (FF introduces a line number instead);
// everything else (names, numbers,
// operators, strings, comments) is stored as text. A token's second byte can
// be 0 (LONG is F0 00), so the content is not simply NUL-terminated.
//
// The token table was recovered by aligning the three tokenized programs here
// with their text listings line by line (MacPThy's lines up 1:1); the handful
// of tokens no listing line covered were named from their context.
const fs = require("fs");
const path = require("path");

const TOKENS = {
  0xf000: "LONG", 0xf001: "FOR", 0xf002: "COLOR", 0xf003: "PLOT", 0xf004: "CLS", 0xf005: "XELSE",
  0xf007: "NEXT", 0xf008: "DATA", 0xf009: "INPUT", 0xf00a: "DIM", 0xf00b: "READ", 0xf00d: "GOTO",
  0xf00f: "IF", 0xf010: "RESTORE", 0xf011: "GOSUB", 0xf012: "RETURN", 0xf013: "REM",
  0xf014: "STOP", 0xf015: "ELSE", 0xf018: "DEFSTR", 0xf01c: "FILL", 0xf01d: "SWAP",
  0xf01e: "SOUND", 0xf01f: "END", 0xf020: "ON", 0xf021: "OPEN", 0xf022: "ROUTE", 0xf023: "RATIO",
  0xf024: "CIRCLE", 0xf025: "CLOSE", 0xf028: "WIDTH", 0xf029: "KILL", 0xf02a: "BOX",
  0xf02c: "CALL", 0xf02e: "LPRINT", 0xf02f: "DEF", 0xf030: "POKE", 0xf031: "PRINT",
  0xf032: "WRITE", 0xf033: "DO", 0xf034: "UNTIL", 0xf035: "DELAY", 0xf036: "CLEAR",
  0xf037: "WHILE", 0xf038: "WEND", 0xf03c: "GET", 0xf03f: "TEXT", 0xf040: "PEN", 0xf041: "TALK",
  0xf043: "PUT", 0xf044: "COORDINATE", 0xf045: "SCROLL", 0xf046: "EDIT", 0xf047: "BEEP",
  0xf048: "SEGMENT", 0xf04c: "BREAK", 0xf04d: "APPLE", 0xf04e: "CURSOR", 0xf051: "WAVE",
  0xf052: "BLOCKMOVE", 0xf053: "SELECT", 0xf054: "CASE", 0xf055: "RANDOM", 0xf059: "FLUSHEVENTS",
  0xf05a: "'", 0xf200: "PAGE", 0xf202: "FN", 0xf203: "USR", 0xf204: "ERROR", 0xf205: "MENU",
  0xf206: "BUTTON", 0xf207: "PICTURE", 0xf208: "WINDOW", 0xf209: "DIALOG", 0xf20a: "TIMER",
  0xf20b: "MOUSE", 0xf20d: "TEHANDLE", 0xf401: "VARPTR", 0xf402: "INSTR", 0xf404: "MEM",
  0xf405: "NOT", 0xf407: "PEEK", 0xf409: "PRHANDLE", 0xf40c: "FINDERINFO", 0xf40f: "LEN",
  0xf410: "VAL", 0xf411: "ASC", 0xf412: "SGN", 0xf413: "INT", 0xf414: "ABS", 0xf416: "SQR",
  0xf417: "RND", 0xf418: "LOG", 0xf419: "EXP", 0xf41b: "SIN", 0xf41d: "ATN", 0xf41e: "CVI",
  0xf425: "CHR$", 0xf426: "HEX$", 0xf42a: "STR$", 0xf42b: "EDIT$", 0xf430: "LEFT$", 0xf432: "MID$",
  0xf436: "FILES$", 0xf437: "INDEX$", 0xf601: "USING", 0xf603: "WORD", 0xf604: "TO",
  0xf605: "THEN", 0xf606: "STEP", 0xf607: "AND", 0xf608: "OR", 0xf60a: "MOD", 0xf610: "OFF",
  0xf611: "PSET", 0xf613: "OUTPUT", 0xf614: "FIELD", 0xf615: "PRCANCEL", 0xf616: "VOLUME",
  0xf617: "FILE", 0xf618: "INFO", 0xf802: "CLOSERESFILE", 0xf803: "USERESFILE",
  0xf807: "RELEASERESOURCE", 0xf80d: "ADDRESOURCE", 0xf80e: "RMVERESOURCE",
  0xf80f: "UPDATERESFILE", 0xf81d: "SETCLIP", 0xf81e: "GETCLIP", 0xf81f: "CLIPRECT",
  0xf821: "INITCURSOR", 0xf822: "SETCURSOR", 0xf828: "GETPENSTATE", 0xf829: "SETPENSTATE",
  0xf82a: "PENSIZE", 0xf82b: "PENMODE", 0xf82d: "PENNORMAL", 0xf82e: "MOVETO", 0xf82f: "LINETO",
  0xf837: "DRAWSTRING", 0xf839: "GETFONTINFO", 0xf83d: "OFFSETRECT", 0xf83e: "INSETRECT",
  0xf842: "FRAMERECT", 0xf843: "PAINTRECT", 0xf844: "ERASERECT", 0xf845: "INVERTRECT",
  0xf84c: "FRAMEROUNDRECT", 0xf856: "DISPOSERGN", 0xf859: "SETRECTRGN", 0xf85a: "RECTRGN",
  0xf85b: "OPENRGN", 0xf85c: "CLOSERGN", 0xf85e: "INSETRGN", 0xf85f: "SECTRGN", 0xf861: "DIFFRGN",
  0xf863: "FRAMERGN", 0xf864: "PAINTRGN", 0xf865: "ERASERGN", 0xf867: "FILLRGN", 0xf883: "GETFNUM",
  0xf885: "GETMOUSE", 0xf886: "GETKEYS", 0xf888: "GETWMGRPORT", 0xf8a9: "GETCTITLE",
  0xf8ac: "DRAWCONTROLS", 0xf8b7: "DISPOSEMENU", 0xf8b8: "APPENDMENU", 0xf8b9: "ADDRESMENU",
  0xf8bb: "INSERTMENU", 0xf8bc: "DRAWMENUBAR", 0xf8bd: "DELETEMENU", 0xf8be: "CLEARMENUBAR",
  0xf8bf: "SETMENUBAR", 0xf8c1: "DISABLEITEM", 0xf8c2: "ENABLEITEM", 0xf8c3: "CHECKITEM",
  0xf8c8: "SETITEMSTYLE", 0xf8ce: "TEDISPOSE", 0xf8cf: "TESETTEXT", 0xf8d5: "TEKEY",
  0xf8d9: "TEDELETE", 0xf8da: "TEINSERT", 0xf8dc: "TEUPDATE", 0xf8dd: "TEXTBOX",
  0xf8de: "TESCROLL", 0xf8df: "TECALTEXT", 0xf8ea: "PARAMTEXT", 0xf90b: "GETPEN",
  0xf90e: "SETRECT", 0xf90f: "SETITEM", 0xf910: "GETITEM", 0xf91a: "TEAUTOVIEW",
  0xfa01: "OPENRESFILE", 0xfa03: "CURRESFILE", 0xfa08: "GETRESOURCE", 0xfa09: "GETNAMEDRESOURCE",
  0xfa0b: "SIZERESOURCE", 0xfa0e: "STRINGWIDTH", 0xfa11: "PTINRECT", 0xfa14: "NEWRGN",
  0xfa16: "RECTINRGN", 0xfa1e: "REALFONT", 0xfa25: "TICKCOUNT", 0xfa34: "FINDCONTROL",
  0xfa3b: "NEWMENU", 0xfa3d: "GETMENUBAR", 0xfa41: "COUNTMITEMS", 0xfa42: "GETMHANDLE",
  0xfa43: "TENEW", 0xfa44: "TEGETTEXT", 0xfa4a: "STOPALERT", 0xfa4b: "NOTEALERT",
  0xfa4c: "CAUTIONALERT", 0xfa54: "ZEROSCRAP", 0xfa55: "PUTSCRAP", 0xfa5c: "BITTST",
  0xfa93: "GETHANDLESIZE", 0xfa94: "NEWHANDLE", 0xfa95: "DISPOSHANDLE", 0xfa9f: "HLOCK",
  0xfaa0: "HUNLOCK", 0xfacf: "SNDPLAY", 0xfad4: "SYSENVIRONS", 0xfc03: "SHADOWBOX",
};
const REM_TOKENS = new Set([0xf05a, 0xf013]);   // ' and REM: the rest of the line is text
const ELSE = 0xf015;                             // stored as ":ELSE", listed as "ELSE"

// Mac Roman → the byte itself. The interpreter reads listings byte for byte
// (latin1) and does its own Mac Roman mapping, so the bytes pass straight through.
function parseRecords(buf) {
  const out = [];
  let p = 0;
  while (p + 8 <= buf.length) {
    const len = buf.readUInt16BE(p);
    if (len < 6 || buf.readUInt16BE(p + 6) !== 0) return null;
    let c = buf.subarray(p + 8, Math.min(buf.length, p + len + 1));
    if (c.length && c[c.length - 1] === 0 && !endsInToken(c)) c = c.subarray(0, c.length - 1);
    out.push(c);
    p += len + 2;
  }
  return p === buf.length ? out : null;
}

// Does the content's final byte belong to a two-byte token (… F0 00)?
function endsInToken(c) {
  let inStr = false;
  for (let i = 0; i < c.length; i++) {
    const b = c[i];
    if (inStr) { if (b === 0x22) inStr = false; continue; }
    if (b === 0x22) { inStr = true; continue; }
    if (b >= 0xf0 && i + 1 < c.length) {
      if (i + 1 === c.length - 1) return true;
      if (REM_TOKENS.has((b << 8) | c[i + 1])) return false;
      i++;
    }
  }
  return false;
}

function detokenizeLine(c, unknown) {
  const out = [];
  let inStr = false;
  for (let i = 0; i < c.length; i++) {
    const b = c[i];
    if (inStr) { out.push(b); if (b === 0x22) inStr = false; continue; }
    if (b === 0x22) { inStr = true; out.push(b); continue; }
    // A line-number reference: FF then the number as a word (ON ERROR GOSUB 65535).
    if (b === 0xff && i + 2 < c.length) {
      out.push(...Buffer.from(String((c[i + 1] << 8) | c[i + 2])));
      i += 2;
      continue;
    }
    if (b >= 0xf0 && i + 1 < c.length) {
      const tok = (b << 8) | c[i + 1];
      i++;
      if (tok === ELSE && out[out.length - 1] === 0x3a) out.pop();
      const word = TOKENS[tok];
      if (word === undefined) {
        unknown.add(tok.toString(16));
        out.push(...Buffer.from(`{?${tok.toString(16)}}`));
      } else out.push(...Buffer.from(word, "latin1"));
      if (REM_TOKENS.has(tok)) { out.push(...c.subarray(i + 1)); break; }
      continue;
    }
    out.push(b);
  }
  return Buffer.from(out);
}

function detokenize(file) {
  const recs = parseRecords(fs.readFileSync(file));
  if (!recs || recs.length < 5) return false;
  const unknown = new Set();
  const lines = recs.map(c => detokenizeLine(c, unknown));
  const outFile = `${file}.detok.txt`;
  fs.writeFileSync(outFile, Buffer.concat(lines.flatMap(l => [l, Buffer.from("\r")])));
  console.log(`${outFile}: ${lines.length} lines` + (unknown.size ? `; unknown tokens ${[...unknown].join(" ")}` : ""));
  return true;
}

function scan(dir) {
  for (const e of fs.readdirSync(dir, {withFileTypes: true})) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) scan(p);
    else if (!/\.(txt|rsrc)$/i.test(e.name)) detokenize(p);
  }
}

const args = process.argv.slice(2);
if (args.length) args.forEach(f => detokenize(f) || console.error(`${f}: not a tokenized ZBasic source`));
else scan("progs/extracted");
