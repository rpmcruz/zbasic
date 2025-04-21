const peg = require("pegjs");
const fs = require("fs");

// Read and compile the grammar
const grammar = fs.readFileSync("ZBasic.pegjs", "utf8");
const parser = peg.generate(grammar);

// ZBasic code to parse
//const code = fs.readFileSync('test.txt', 'utf8');
const code = fs.readFileSync('progs/extracted/pthy/pthy1.1.txt', 'utf8');

// Parse and print the result
try {
    const ast = parser.parse(code,
        {  // progress bar
            progressCallback: (line, s) => {
              //const percent = Math.round(progressRatio * 100);
              console.log(`Progress: ${line}`);
              while(Array.isArray(s))
                s = s[0];
              //console.log(s);
            }
        }
    );
    console.log(JSON.stringify(ast, null, 2));
} catch(error) {
    if(error.location != null) {
        const lines = code.split('\n');
        const { line, column } = error.location.start;
        const errorLine = lines[line - 1];
        console.error(`Parsing Error (line: ${line}, column: ${column})`);
        console.error(`${String(line).padStart(4, ' ')}: ${errorLine}`);
        console.error(' '.repeat(4+2+column-1) + '^');
    }
    else
        console.error('Grammar error:')
    console.error(error.message);
}