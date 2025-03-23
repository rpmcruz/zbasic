const peg = require("pegjs");
const fs = require("fs");

// Read and compile the grammar
const grammar = fs.readFileSync("ZBasic.pegjs", "utf8");
const parser = peg.generate(grammar);

// ZBasic code to parse
//const code = fs.readFileSync('pthy1.1.txt', 'utf8');
//const code = 'REM:***Price Theory Programs Ver 1.1, May 2, 1991***';
const code = `REM This is a comment
DIM X&(10) ' Another comment
PRINT "Hello"`

// Parse and print the result
try {
    const ast = parser.parse(code);
    console.log("Parsed AST:", JSON.stringify(ast, null, 2));
} catch (error) {
    console.error("Parsing Error:", error.message);
}
