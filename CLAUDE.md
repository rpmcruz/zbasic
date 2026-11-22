# Working on the ZBasic interpreter

A browser interpreter for Macintosh ZBasic (c. 1990), built to run four of
David Friedman's economics programs in `progs/`. Read `README.md` for the
layout, build and extraction steps. This file is about how the interpreter is
put together and how to work on it.

## Ground rules

- **Never edit the programs.** The `.sit` archives are the source of truth.
  If a program misbehaves, the interpreter, the grammar or the extraction is
  wrong. Re-extract (`README.md`, "Where the programs come from") rather than
  touching `progs/extracted/`.
- **Check the manual before "fixing" a symptom.** Most bugs here were the
  interpreter doing the plausible JavaScript thing instead of the documented
  ZBasic thing. `docs/ZBasic-0-manual.pdf` (user manual) and
  `docs/ZBasic-1-reference.pdf` (statement reference) extract cleanly with
  `pdftotext -layout`. They cover generic ZBasic; Mac-specific behaviour
  (event traps, EDIT FIELD, Toolbox calls) has to be inferred from the
  programs themselves, and their own comments are good evidence.
- **The programs carry their own documentation.** PG:PRO's sources
  (`Supermarket/…/PG PRO.INCL`, `.GLBL`) show what its runtime calls mean;
  resource forks ship `TMPL` templates for PG:PRO's private resource types.
- On NixOS, node comes from `nix-shell -p nodejs --run "…"`.

## Testing

- `node test-headless.js --all` — every program starts, with no errors and no
  hang. It reports the statement a program is stuck in if it stops making
  progress, which is how a frozen browser tab gets diagnosed. Run it after any
  interpreter change, and after `node zbasic-compile.js` for grammar changes.
- `node test-headless.js <Program> <seconds> <script.js>` drives a program
  (clicks, keys, menu picks, answering file dialogs) from a script; see the
  comment at the top. `<Program>` can also be the path of a single source
  file, which is the quickest way to test a statement in isolation.
- Then look at it in a real browser: serve the directory
  (`python3 -m http.server`) and open `index.html?prog=<Program>`. The page's
  functions (`loadProgram`, `runProgram`, `stopProgram`, `pushEvent`,
  `notePress`/`noteRelease`, `globalVars`, `controlStore`, …) are globals, so
  a console or a browser-automation script can drive and inspect a run.
- `DIALOG n, msg$` and `INPUT` use `window.alert`/`prompt`, which block an
  automated browser; avoid them when driving the page from a script.

## How `index.html` is organised

One file, top to bottom:

1. **Emulated Mac memory** — `fakeMalloc` and the read/write helpers
   (`fakeRead`/`fakeWrite`) back VARPTR, PEEK/POKE, BLOCKMOVE and resource
   handles. Strings are Mac Roman there (`strToMacRoman`, `macRomanToStr`);
   everywhere else they are Unicode. **Variable memory** gives every global
   variable an address (see below).
2. **Resources** — `parseRsrcFile` reads the AppleDouble `.rsrc` files into
   `macResources`; PICT decoding, PG:PRO's `pG3w`/`pG3c`/`pG3t` windows and
   objects, menus (`MBAR`/`MENU`), alerts (`ALRT`/`DITL`).
3. **Windows and canvases** — one canvas per ZBasic window. Programs draw in
   window coordinates through the context transform; the backing store is
   `CANVAS_SCALE` device pixels per window pixel, which follows the size the
   windows are shown at (`rescaleCanvases`). Code that touches pixels directly
   converts with `dev()`.
4. **Loading** — `addFile` (sources are decoded from Mac Roman),
   `loadProgram`, `autoSelectFile`, `parseTolerant`.
5. **Events** — `pushEvent` queues; `fireEventHandlers` delivers to the
   `ON … GOSUB` handlers (see "Event traps" below); `waitForEvent` serves
   `DIALOG(0)` and friends.
6. **Interpreter** — `runProgram`, `execBlock`/`runFrom` (statement lists,
   GOTO/GOSUB/RETURN as exceptions), `execStmt`, `execSysCall` (statements),
   `execProcCall` (CALL — Toolbox procedures and user functions),
   `execUserFuncCall` (FN), `evalExpr`/`evalCallable` (expressions, built-in
   and Toolbox functions in one table).
7. **Disk files** — the documents programs save (`disk()`, kept in
   localStorage), OPEN/CLOSE/PRINT#/INPUT#/READ FILE/WRITE FILE on open file
   numbers, disk errors and ON ERROR (`diskError`), and the Standard File
   dialog FILES$ puts up (`fileDialog`), which is also the toolbar's
   Documents manager.

## ZBasic semantics that are easy to get wrong

Each of these was a bug; the code comments carry the details and evidence.

- **Integer arithmetic.** An expression *level* is integer unless it contains
  a decimal point, `!`/`#`, a scientific function, `\` or a constant > 65535,
  and then `/` is integer division (`levelIsReal`). `%`/`&` variables
  truncate and wrap on assignment (`coerceVar`).
- **FOR/NEXT** runs at least once and keeps its counter in the variable:
  programs exit loops by assigning to it, and it ends at limit+STEP.
- **All variables are global**, LONG FN parameters included; only LOCAL FN
  (ZBasic Mac) has locals (`makeLocalScope`, `bindArgs`).
- **Consecutive DIMmed scalars are one block of memory.** `DIM T,L,B,R` is
  passed as a Rect and `DIM My,Mx` as a Point (`dimGroups`, `resolveRect`,
  `readPoint`/`writePoint`).
- **Labels** are matched loosely (`canonLabel`): the spelling at a GOSUB need
  not match the definition.
- **Event traps.** Events queue until the program turns the trap on with
  `X ON`, which also delivers whatever is pending; after that `X OFF` does not
  stop delivery. See the comment above `trappedBy` for why. The Stop button
  always stops; `ON STOP` is the clean-up routine run on the way out.
- **EDIT FIELD**: types 1-4 editable and 5+ static, odd types framed;
  justification 1/2/3 = left/centre/right in the low bits of the last
  argument; the field uses the TEXT font in force when it was built.
- **QuickDraw pen**: a line drags the pen rectangle, hanging right and down
  from the path; frames are drawn inside their rectangle (`penLine`,
  `penFrame`). Pen modes: 10 is XOR, 11/12 erase (`penPaint`); XOR is done on
  a 1-bit mask so drawing twice restores exactly (`paintXor`, `gfxTextXor`).
- **Text**: `PRINT`/`STR$` put a blank before non-negative numbers.
  `CHR$`/`ASC` use Mac Roman codes.
- **Variables have addresses.** ZBasic lays every variable out at compile time,
  simple variables and then arrays, in the order the source first mentions
  them. CDraw and Grglflx save a document by writing the bytes from
  `VARPTR(FirstVar)` to `VARPTR(LastVar)`, and BLOCKMOVE copies rects and
  string bytes into variables. `layoutVariables` gives each global the same
  place in emulated memory, and every memory read or write syncs the
  variables it touches (`varsToMem`, `memToVars`). `@var` still yields a
  handle into `fnPtrTable`, not an address — PG:PRO's uses of it rely on that.
- **Files**: `PRINT #n` writes exactly what `PRINT` would show, ending in a
  CR; `INPUT #n` reads up to a comma or CR. A file is one byte stream, so
  CDraw's `PRINT #` lengths and `WRITE FILE` blocks share it. Disk errors are
  `code + 256 × file number` (259: file not found, file #1); `ON ERROR GOSUB
  65535` lets the program check `ERROR` itself, otherwise ZBasic's
  Continue/Stop box comes up. Closing a FILES$ dialog sends the window an
  update event, as on the Mac — that is what makes CDraw draw a document it
  has just opened.

## The programs

| Program | Starts from | Notes |
|---|---|---|
| CDraw | `CurveDraw45.bas.detok.txt` | `CDraw45.txt` is a 2000 export half-translated to another BASIC — do not use it |
| Grglflx | `grglflx27.txt` | the application is v27; `grglflx28.bas` is later work in progress |
| MacPThy | `PThy 1.1.detok.txt` | identical to `PThy 1.1.txt`, which lost the final RETURN |
| Supermarket | `Supermarket.MAIN` | a PG:PRO project: `INCLUDE`s and `GLOBALS` files, windows built from `pG3*` resources |

`progs/extracted/DosPThy` is GW-BASIC (the DOS edition), not ZBasic.

## Not implemented

Printing, the clipboard, random-access files (`READ#`/`WRITE#`, `RECORD`),
`LINE INPUT#`, and colour beyond what the programs use. These end up in the
`unsupported` / `undefined:` console messages, which are the first thing to
look at when a program misbehaves.

Supermarket's File menu does nothing: PG:PRO recognises it by reading the
menu's title out of its MenuInfo record (`PSTR$([mHndl&] + _menuData)`), and
menu handles here are bare menu ids (`menuDefs[id]`) with no record behind
them. Its Open and Save would do nothing anyway — the program's own
`"Action:Main"` leaves `_mainOpen` and `_mainSave` empty, and its unused
`FN openFile` tests a misspelt `fldHnld&`.
