const peg = require("pegjs");
const fs = require("fs");
const path = require("path");

// Read and compile the grammar
const grammar = fs.readFileSync("ZBasic.pegjs", "utf8");
const parser = peg.generate(grammar, {cache: true});

const inputFile = process.argv[2];
if (!inputFile) {
    console.error('Usage: node parser.js <file>');
    process.exit(1);
}

// Uppercase everything outside string literals (ZBasic is case-insensitive)
function normalizeCase(src) {
    let out = '';
    let i = 0;
    while (i < src.length) {
        if (src[i] === '"') {
            out += src[i++];
            while (i < src.length && src[i] !== '"' && src[i] !== '\r' && src[i] !== '\n') {
                if (src[i] === '\\' && i + 1 < src.length) { out += src[i++]; }
                out += src[i++];
            }
            if (i < src.length) out += src[i++];
        } else {
            out += src[i++].toUpperCase();
        }
    }
    return out;
}

// Convert multi-word labels (lines that are ONLY words + colon, no trailing comment) to underscore-joined form
// e.g. "SELECT WITH SHIFT:" -> "SELECT_WITH_SHIFT:"
function normalizeMultiWordLabels(src) {
    const linePattern = /^([ \t]*)([A-Z_][A-Z0-9_]*)( [A-Z_][A-Z0-9_]*)+[ \t]*:[ \t]*$/;
    const parts = src.split(/(\r\n|\n|\r)/);
    for (let i = 0; i < parts.length; i += 2) {
        const m = linePattern.exec(parts[i]);
        if (m) {
            const indent = m[1];
            const labelEnd = parts[i].lastIndexOf(':');
            const labelWords = parts[i].slice(indent.length, labelEnd).trim();
            parts[i] = indent + labelWords.replace(/ /g, '_') + ':';
        }
    }
    return parts.join('');
}

// Fix ON...GOTO/GOSUB lines that use "," (string commas) as target separators instead of plain commas
// e.g. ON x GOTO New","Open","X","Quit"  ->  ON x GOTO New,Open,X,Quit
function normalizeOnGotoTargets(src) {
    const parts = src.split(/(\r\n|\n|\r)/);
    for (let i = 0; i < parts.length; i += 2) {
        const line = parts[i];
        if (!/\bON\b.+\b(GOTO|GOSUB)\b/.test(line)) continue;
        // Match lines where first GOTO target is an unquoted identifier immediately followed by ","
        const m = line.match(/^(.*\b(?:GOTO|GOSUB)\s+)([A-Z_][A-Z0-9_]*)","(.*)$/);
        if (!m) continue;
        let prefix = m[1] + m[2] + ',';
        let rest = m[3];
        let result = '';
        let inStr = false;
        for (let j = 0; j < rest.length; j++) {
            const c = rest[j];
            if (c === '"' && !inStr) {
                if (rest[j+1] === ',' && rest[j+2] === '"') {
                    result += ','; j += 2;
                } else if (j === rest.length - 1) {
                    // trailing lone " — drop it
                } else {
                    inStr = true; result += c;
                }
            } else if (c === '"' && inStr) {
                inStr = false; result += c;
            } else {
                result += c;
            }
        }
        parts[i] = prefix + result;
    }
    return parts.join('');
}

// Insert ':' between a string label and statement code on same line (e.g. "Label" RETURN -> "Label":RETURN)
// Only matches "string" when it appears at the start of a line (after optional indent)
function insertLabelColons(src) {
    const parts = src.split(/(\r\n|\n|\r)/);
    for (let i = 0; i < parts.length; i += 2) {
        parts[i] = parts[i].replace(/^([ \t]*)"([^"]*)"([ \t]+)([A-Z'])/, '$1"$2":$4');
    }
    return parts.join('');
}

// Join lines where an IF condition continues on the next line ending with THEN
// Pattern: line N has no statement-ending marker, line N+1 ends with THEN
function joinThenContinuations(src) {
    const parts = src.split(/(\r\n|\n|\r)/);
    let i = 0;
    while (i < parts.length - 2) {
        const line = parts[i];
        const sep = parts[i + 1];
        const next = parts[i + 2];
        // next line ends with THEN (optionally followed by spaces/comment start)
        if (/^[ \t]+\S.*\bTHEN\b\s*$/.test(next) && !/^\s*IF\b/.test(next) && line.trim().length > 0) {
            parts[i] = line + ' AND ' + next.trim();
            parts.splice(i + 1, 2);
        } else {
            i += 2;
        }
    }
    return parts.join('');
}

let lastNormalizedContent = null;

function parseFile(filePath) {
    const content = insertLabelColons(normalizeOnGotoTargets(normalizeMultiWordLabels(joinThenContinuations(normalizeCase(fs.readFileSync(filePath, 'latin1'))))));
    lastNormalizedContent = content;
    const dir = path.dirname(path.resolve(filePath));
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
}

try {
    const ast = parseFile(inputFile);
    console.log(JSON.stringify(ast, null, 2));
} catch(error) {
    if (error.location != null && lastNormalizedContent) {
        const src = lastNormalizedContent;
        const offset = error.location.start.offset;
        const before = src.slice(0, offset).split(/\r\n|\n|\r/);
        const line = before.length;
        const column = before[before.length - 1].length + 1;
        const lines = src.split(/\r\n|\n|\r/);
        const errorLine = lines[line - 1] || '';
        console.error(`Parsing Error (line: ${line}, column: ${column})`);
        console.error(`${String(line).padStart(4, ' ')}: ${errorLine}`);
        console.error(' '.repeat(4+2+column-1) + '^');
    } else {
        console.error('Grammar error:');
    }
    console.error(error.message);
}
