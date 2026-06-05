# ZBasic web interpreter

Interpreter for old ZBasic programs. ZBasic was a programming language from the 80s that was easy-to-use, cross-plataform, and had many GUI elements. The motivation for this interpreter was mainly to run [David D. Friedman's educational games](http://daviddfriedman.com/Living_Paper/living_paper.htm) to teach economics, which were probably the first educational games to be bundled together with a textbook.

## How to run:

1. We need to build the pegjs parser. While node.js is not necessary to run this interpreter, we use it to build the parser. You first need to install pegjs: `npm install pegjs` and then `node build.js`.
2. Now you just need to run `index.html`.

Some of the old David D. Friedman's game seem to have syntax errors. To fix those, we have `fix-*.py` to patch the errors.
