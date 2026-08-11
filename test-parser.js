const peg = require("pegjs");
const fs = require("fs");
const path = require("path");

// Read and compile the grammar
const grammar = fs.readFileSync("zbasic.pegjs", "utf8");
const parser = peg.generate(grammar, {cache: true});

const inputFile = process.argv[2];
if (!inputFile) {
    console.error('Usage: node parser.js <file>');
    process.exit(1);
}

function parseFile(filePath) {
    const content = fs.readFileSync(filePath, 'latin1');
    const dir = path.dirname(path.resolve(filePath));
    try {
        return parser.parse(content, {
            progressCallback: (line, s) => {
                console.log(`Progress: ${line}`);
            },
            parseFile: (includeName) => {
                const includePath = path.resolve(dir, includeName);
                try {
                    return parseFile(includePath);
                } catch(e) {
                    console.error(`Warning: could not include "${includeName}": ${e.message}`);
                    return [];
                }
            }
        });
    } catch(error) {
        if (error.location != null) {
            const offset = error.location.start.offset;
            const before = content.slice(0, offset).split(/\r\n|\n|\r/);
            const line = before.length;
            const column = before[before.length - 1].length + 1;
            const errorLine = content.split(/\r\n|\n|\r/)[line - 1] || '';
            console.error(`Parsing Error in ${filePath} (line: ${line}, column: ${column})`);
            console.error(`${String(line).padStart(4, ' ')}: ${errorLine}`);
            console.error(' '.repeat(4+2+column-1) + '^');
        } else {
            console.error('Grammar error:');
        }
        console.error(error.message);
        process.exit(1);
    }
}

console.log(JSON.stringify(parseFile(inputFile), null, 2));
