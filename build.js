#!/usr/bin/env node
const peg = require("pegjs");
const fs = require("fs");

const grammar = fs.readFileSync("zbasic.pegjs", "utf8");
const parserSource = peg.generate(grammar, {cache: true, output: "source"});
const wrapped = `var ZBasicParser = ${parserSource};\n`;
fs.writeFileSync("zbasic-parser.js", wrapped);
console.log("Written zbasic-parser.js");
