# ZBasic web interpreter

Interpreter for old ZBasic programs. ZBasic was a programming language from the 80s that was easy-to-use, cross-plataform, and had many GUI elements. The motivation for this interpreter was mainly to run [David D. Friedman's educational games](http://daviddfriedman.com/Living_Paper/living_paper.htm) to teach economics, which were probably the first educational games to be bundled together with a textbook.

## How to run

1. Compile the pegjs grammar. node.js is not needed to *run* the interpreter,
   only to build it: `npm install pegjs`, then `node zbasic-compile.js`. That
   writes `zbasic-compiled.js` (the parser) and `progs/programs.json` (the list
   of programs the picker offers).
2. Open `index.html` — either straight off the disk, or over HTTP.

Pick a program from the dropdown, or use **Open Folder** to point at any
directory of ZBasic sources. The dropdown needs `progs/programs.json`, so it is
hidden when you open `index.html` as a `file://` URL; Open Folder always works.

## Layout

| | |
|---|---|
| `index.html` | the whole interpreter — parser driver, runtime, and the Mac UI |
| `zbasic.pegjs` | the grammar |
| `zbasic-compile.js` | build step: grammar → `zbasic-compiled.js`, plus `progs/programs.json` |
| `zbasic-compiled.js` | generated parser, loaded by `index.html` |
| `test-parser.js` | CLI helper: `node test-parser.js <file>` dumps one file's AST |
| `progs/*.sit` | the original archives |
| `docs/` | the ZBasic manuals |
