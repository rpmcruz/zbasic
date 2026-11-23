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
5. **Events** — `pushEvent` queues; `lineEnd`/`fireEventHandlers` deliver to
   the `ON … GOSUB` handlers (see "Event traps" below); `waitForEvent` serves
   `DIALOG(0)` and friends.
6. **Interpreter** — `runProgram`, `execBlock`/`runFrom` (statement lists,
   GOTO/GOSUB/RETURN as exceptions), `execStmt`, `execSysCall` (statements),
   `execProcCall` (CALL — Toolbox procedures and user functions),
   `execUserFuncCall` (FN), `evalExpr`/`evalCallable` (expressions, built-in
   and Toolbox functions in one table).
7. **Disk files** — the documents programs save (`disk()`, kept in
   localStorage), OPEN/CLOSE/PRINT#/INPUT#/READ FILE/WRITE FILE on open file
   numbers, disk errors and ON ERROR (`diskError`), and the Standard File
   dialog FILES$ puts up (`fileDialog`).

## ZBasic semantics that are easy to get wrong

Each of these was a bug; the code comments carry the details and evidence.

- **Integer arithmetic.** An expression *level* is integer unless it contains
  a decimal point, `!`/`#` (a variable, array element or FN), a scientific
  function, `\` or a constant > 65535, and then `/` is integer division
  (`levelIsReal`). Plain, `%` and `&` variables truncate and wrap on
  assignment (`coerceVar`). `<<`/`>>` multiply and divide by 2^n, keeping
  the fraction on a real level (MacPThy's fixed point, `Y!<<10`).
- **The suffix is part of the name.** `X`, `X!`, `X#`, `X&` and `X$` are
  different variables; only `X%` is `X`, integer being the default type
  (`normVarName`). MacPThy sets `Rate!=.2:Rate=20`. Record fields are the
  exception: Supermarket declares `STargetLine%` and writes `STargetLine`
  (`normFieldName`).
- **FOR/NEXT** runs at least once and keeps its counter in the variable:
  programs exit loops by assigning to it, and it ends at limit+STEP.
- **All variables are global**, LONG FN parameters included; only LOCAL FN
  (ZBasic Mac) has locals (`makeLocalScope`, `bindArgs`).
- **Consecutive DIMmed scalars are one block of memory.** `DIM T,L,B,R` is
  passed as a Rect and `DIM My,Mx` as a Point (`dimGroups`, `resolveRect`,
  `readPoint`/`writePoint`).
- **Labels** are matched loosely (`canonLabel`): the spelling at a GOSUB need
  not match the definition.
- **Event traps act on the text, at line ends.** ZBasic compiles an event
  check at the end of every line written between `X ON` and `X OFF` — by
  position in the source, not by what ran last — and none between the
  statements of one line. MacPThy writes unreachable `MOUSE OFF:DIALOG OFF`
  after RETURNs just to switch checks off for the routine below. The grammar
  marks line ends (`eol`, `headEol`), `markTrapRegions` gives statements their
  regions, `lineEnd` delivers. Nothing is delivered before the first runtime
  `X ON`. The Stop button always stops; `ON STOP` is the clean-up routine run
  on the way out.
- **MOUSE(0)**: -1 while a single press is held (drags); a double or triple
  click is reported once as a finished +2/+3, even while held — the Mac was
  rarely back in time to see it held, and MacPThy's Monopoly waits for M=2.
  A click on a control is the control's (a DIALOG event), never a mouse click.
- **`RESTORE n`** counts DATA items from 0 (the reference's example).
- **EDIT FIELD**: types 1-4 editable and 5+ static, odd types framed;
  justification 1/2/3 = left/centre/right in the low bits of the last
  argument; the field uses the TEXT font in force when it was built.
- **QuickDraw pen**: a line drags the pen rectangle, hanging right and down
  from the path; frames are drawn inside their rectangle (`penLine`,
  `penFrame`). `PEN` keeps every value it leaves out, the mode included. Its
  5th argument picks a pattern from PAT# 0 (`penPattern`), and modes 8–15 do
  what QuickDraw does with each pattern bit (`PEN_MODES`); XOR is done on a
  1-bit mask so drawing twice restores exactly (`paintXor`, `gfxTextXor`).
  FRAME/PAINT of rects, ovals and round rects use the pen.
- **SELECT**: `CASE =x` is a case, not an assignment to a variable CASE.
- **SWAP** takes any two variables — MacPThy swaps arrays element by element.
- **GETKEYS/BITTST**: the KeyMap bit of key k is bit k AND 7 of byte k\8
  (Shift is 56); BITTST reads memory high bit first.
- **Text**: `PRINT`/`STR$` put a blank before non-negative numbers.
  `CHR$`/`ASC` use Mac Roman codes.
- **RETURN inside an FN leaves the function** (compiled ZBasic calls an FN
  as a subroutine); it must not reach the caller's GOSUB.
- **Controls make update events.** `BUTTON CLOSE`, and re-issuing a button
  with its title, queue DIALOG(0) = 5 for the window (`queueUpdate`).
  MacPThy's dialogs wait `WHILE D0<>1` without clearing D0 and rely on it.
- **Toolbox records are written into the argument.** GETFONTINFO, GETPEN,
  GETMOUSE fill the variables that start the record — a DIMmed run or array
  elements — not fixed names (`writeWords`).
- **Regions have shapes**: a bounding box plus a pixel mask (`rgnCombine`,
  `rgnInset`, `rgnFromSegments` for OPENRGN/CLOSERGN outlines). FILLRGN takes
  the program's 8x8 pattern; PAINTRGN uses the pen.
- **Pixels.** Window canvases run at a fractional scale; rectangles and
  images are snapped to device pixels (`windowContext`) so painting and
  erasing cancel.
  Text uses Geneva stand-ins of Geneva's width (`GENEVA`, `--geneva`) because
  programs size boxes for it. GET copies canvas to canvas and skips windows
  that have not changed — MacPThy snapshots the window on every loop pass.
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
| Supermarket | `Supermarket.MAIN` | a PG:PRO project: `INCLUDE`s and `GLOBALS` files, windows built from `pG3*` resources; see "PG:PRO" below |

`progs/extracted/DosPThy` is GW-BASIC (the DOS edition), not ZBasic.

## PG:PRO

Supermarket is built on PG:PRO, a framework whose runtime is ZBasic source
shipped with the program (`PG PRO.INCL`, `.GLBL`, `@Header.INCL`). Most of it
runs as written: its event dispatch, menus (`pGautoMenu`, `pGfixMenus`), the
File menu, closing windows (`pGcloseWindow`, `pGcloseAll`). Two parts are
emulated in `index.html` instead, and their PG:PRO functions are not run:
building windows (`pGbuild`, in `execUserFuncCall`) and the object layer — the
buttons, fields and pictures of `pG3c` resources, which `buildPgObjects` turns
into real controls (the `PG_NATIVE` list). Things that came up getting the
rest to run:

- `DEF FN name USING ptr&` declares a function called through a pointer;
  PG:PRO declares all 43 of its functions that way and then defines each with
  a `LOCAL FN` of the same name. The declaration must not replace the
  function (`isPrototypeOf`).
- `GLOBALS GOSUB label` inside a LOCAL FN returns to the next statement.
- Menu handles are real (`menuHandle`): PG:PRO reads a menu's id and title
  out of its MenuInfo record. Menu calls accept a handle or an id (`menuIdOf`).
- Its compiled runtime's constants are not in any source. Where a value is
  only a selector, a stand-in is used, as for the `WINDOW()` selectors; see
  the comments in the constant table in `runProgram`.

## Not implemented

Printing, the clipboard, random-access files (`READ#`/`WRITE#`, `RECORD`),
`LINE INPUT#`, and colour beyond what the programs use. These end up in the
`unsupported` / `undefined:` console messages, which are the first thing to
look at when a program misbehaves.

Supermarket's Open and Save put up their dialogs and then do nothing, as on
the Mac: the program's own `"Action:Main"` leaves `_mainOpen` and `_mainSave`
empty (and its unused `FN openFile` tests a misspelt `fldHnld&`).
