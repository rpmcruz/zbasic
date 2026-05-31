{
let progressCallback = options.progressCallback || (() => {});
}

start = block:block EOF { return block; }

//////////////////////// statements ////////////////////////

block
  = _ &'"' stmt:statementWithProgress __ rest:block
    { return stmt ? [stmt, ...rest] : rest; }
  / _ stmt:statementWithProgress _ separator rest:block
    { return stmt ? [stmt, ...rest] : rest; }
  / _ stmt:statementWithProgress _
    { return stmt ? [stmt] : []; }
separator = ":" / newline / comment newline

statementWithProgress = s:statement
  { progressCallback(location().start.line, s); return s; }
statement = comment { return null; }
  / inlineAsm
  / declareStmt / defFn / definition / defCmd / typeBlock / dimVar / commonStmt / defTypeStmt / assignVar
  / userProcCall / userFuncCall / userLongFuncDef / userLocalFuncDef / printStmt / pokeStmt / sysFuncCall / dataStmt
  / includeStmt
  / forLoop / whileLoop / doLoop
  / blockIfCond / ifCond / longIfConf / selectStmt
  / onStmt / endStmt
  / label
  / exprStmt
  / nop

inlineAsm = "`" code:(!newline .)*
  { return {type: "inlineAsm", code: code.map(c => c[1]).join("")}; }

exprStmt = e:expression { return {type: "exprStmt", expr: e}; }

sysFuncCall = cmd:sysCmds ![a-zA-Z0-9_%&!$] chan:("#" expression)? keyword:(__ sysKeyword)? _ args:sysArgs trailer:(_ sysKeyword _ sysArgs)*
  { return {type: "sysFuncCall", cmd: cmd.toUpperCase(), chan: chan ? chan[1] : null,
    keyword: keyword ? keyword[1] : null, args,
    trailer: trailer.map(t => ({keyword: t[1], args: t[3]})) }; }
sysKeyword = !("ELSE"i / "THEN"i / "AND"i / "OR"i / "NOT"i / "NEXT"i / "WEND"i / "UNTIL"i / "XELSE"i / "FOR"i / "WHILE"i / "DO"i / "CALL"i / "DEF"i / "DIM"i / "REM"i / "FN"i / "IF"i / "END"i / "LONG"i / "SELECT"i / "CASE"i / "LOCAL"i) [A-Za-z][A-Za-z]+ ![a-zA-Z0-9_%&!$,/*(=<>^.]
  { return text().toUpperCase(); }
sysCmds = "GOTO"i / "GOSUB"i / "RETURN"i
  / "RESOURCES"i / "COMPILE"i / "WIDTH"i / "GLOBALS"i
  / "COORDINATE"i / "DIALOG"i / "MENU"i / "MOUSE"i / "CURSOR"i
  / "PEN"i / "GET"i / "PUT"i / "PLOT"i / "BOX"i / "TEXT"i
  / "COLOR"i / "CIRCLE"i / "CLS"i / "WINDOW"i / "SCROLL"i / "DELAY"i
  / "CLEAR LOCAL"i / "CLEAR"i / "BUTTON"i / "SOUND"i / "WAVE"i / "SEGMENT"i
  / "DEFSTR"i / "READ"i / "RESTORE"i / "INPUT"i / "OPEN"i / "CLOSE"i
  / "RANDOM"i / "SWAP"i / "BREAK"i / "APPLE"i / "ROUTE"i / "RATIO"i
  / "BEEP"i / "HOME"i / "INVERSE"i / "NORMAL"i / "FLASH"i / "VTAB"i / "HTAB"i
  / "POKE"i / "RESUME"i / "POP"i / "TRACE"i / "NOTRACE"i / "SPEED"i
  / "LPRINT"i / "LLIST"i / "STOP"i / "WAIT"i / "HPLOT"i
  / "HCOLOR"i / "HGRAPH"i / "SCRN"i / "WRITE"i / "%" / "&" / "EDIT"i
  / "SETSELECT"i / "INC"i / "DEC"i / "KILL"i / "PT"i
  / "BLOCKMOVE"i / "LIBRARY"i / "TOOLBOX"i / "INLINE"i / "CHAIN"i
  / "TALK"i / "LINE"i / "PICTURE"i
  / "MINWINDOW"i / "MAXWINDOW"i / "FLUSHEVENTS"i / "SETZOOM"i / "PUSH"i
  / "TIMER"i / "EVENT"i
sysArgs = first:sysArg rest:(_ "," _ sysArg)* {
  return [first, ...rest.map(r => r[3])];
}
sysArg = numFromTo / exprFromTo / exprRect / lineRelPoint / exprPoint / channelNum / (!sysKeyword expression) / nop
lineRelPoint = "-" _ to:exprPoint { return {type: "lineRel", to}; }
channelNum = "#" n:expression { return {type: "channel", n}; }
exprRect = from:exprPoint _ "-" _ to:exprPoint
  { return {from: [from.x, from.y], to: [to.x, to.y]}; }
numFromTo = "(" fromX:integer "," fromY:integer ")-(" toX:integer "," toY:integer ")"
  { return {from: [fromX, fromY], to: [toX, toY] }; }
exprFromTo = fromX:expression _ "," _ fromY:expression segs:(__ "TO"i __ expression _ "," _ expression)+
  { const points = [[fromX, fromY], ...segs.map(s => [s[3], s[5]])];
    return {type: "polyline", from: points[0], to: points[points.length-1], points}; }
exprPoint = "(" _ x:expression _ "," _ y:expression _ ")"
  { return {x, y}; }
nop = _ { return null; }

pokeStmt = "POKE"i __ type:("LONG"i / "WORD"i / "BYTE"i) __ addr:expression _ "," _ val:expression
  { return {type: "sysFuncCall", cmd: "POKE " + type.toUpperCase(), args: [addr, val]}; }
printStmt = "PRINT"i mode:printMode _ items:printList?
  { return {type: "print", mode, items: items || []}; }
printMode = _ mode:("%" / "@") _ coord:exprPoint _ ";"?
  { return {type: mode, coord}; }
  / _ "#" _ chan:expression _ ","?
  { return {type: "#", chan}; }
  / "" { return {type: "plain"}; }
printList = head:printItem tail:(printSep? printItem)* printSep?
  { return [head, ...tail.map(t => t[1])]; }
printItem = "USING"i _ format:expression _ ";" _ expr:expression
  { return {type: "using", format, expr}; }
  / expression
printSep = _ (";" / ",") _

label = '"' chars:char* '"'
  { return {type: "label", label: chars.join("")}; }
  / a:labelIdent ":" b:identifier "/" c:identifier _ ":"
  { return {type: "label", label: a + ":" + b + "/" + c}; }
  / a:labelIdent ":" b:identifier _ ":"
  { return {type: "label", label: a + ":" + b}; }
  / first:labelIdent rest:(__ labelIdent)+ _ ":"
  { return {type: "label", label: first + rest.map(r => "_" + r[1]).join("")}; }
  / name:labelIdent _ &":"
  { return {type: "label", label: name}; }
labelIdent = !(("END"i / "NEXT"i / "WEND"i / "UNTIL"i / "XELSE"i / "ELSE"i / "THEN"i / "CASE"i / "FOR"i / "IF"i / "LONG"i / "WHILE"i / "DO"i / "LOCAL"i / "DEF"i / "DIM"i / "ON"i) ![a-zA-Z0-9_%&!#$]) name:identifier { return name; }

declareStmt = "DECLARE"i __ ("SUB"i / "FUNCTION"i) __ identifier _ ("(" _ declareArgs? _ ")")? _
  { return null; }
declareArgs = head:declareArg tail:(_ "," _ declareArg)*
  { return [head, ...tail.map(t => t[3])]; }
declareArg = name:identifier _ ("AS"i __ identifier)? { return name; }

funcParams = head:funcParam tail:(_ "," _ funcParam)*
  { return [head, ...tail.map(t => t[3])]; }
funcParam = ref:"@"? name:identifier size:(";" _ integer)?
  { return {name, ref: !!ref, size: size ? size[2] : null}; }

dimVar = "DIM"i __ "END"i __ "RECORD"i _ "." name:identifier
  { return {type: "dimEndRecord", name}; }
  / "DIM"i __ "END"i __ "RECORD"i __ name:identifier
  { return {type: "dimEndRecord", name}; }
  / "DIM"i __ "RECORD"i __ name:identifier
  { return {type: "dimRecord", name}; }
  / "DIM"i __ args:dimArgs
  { return {type: "dim", args}; }
dimArgs = head:dimPart tail:(_ "," _ dimPart)*
  { return [head, ...tail.map(t => t[3])]; }
dimPart = prefix:number? _ name:identifier dotType:("." (identifier / integer))? dims:("(" exprArgs ")")? size:(_ ";" _ number)? typeDecl:(__ "AS"i __ identifier)?
  { return { name, prefix, dotType: dotType ? dotType[1] : null, dims: dims ? dims[1] : [], size: size ? size[3] : null, typeName: typeDecl ? typeDecl[3] : null }; }

typeBlock = "TYPE"i __ name:identifier _ newline fields:typeField* _ "END"i __ "TYPE"i _
  { return null; }
typeField = _ name:identifier __ "AS"i __ typeName:identifier _ (newline / comment newline)
  { return {name, typeName}; }

commonStmt = "COMMON"i __ head:commonVar tail:(_ "," _ commonVar)*
  { return null; }
commonVar = name:identifier _ ("(" _ ")")?

defTypeStmt = ("DEFINT"i / "DEFDBL"i / "DEFSNG"i) __ head:defTypeRange tail:(_ "," _ defTypeRange)*
  { return null; }
defTypeRange = [A-Za-z] (_ "-" _ [A-Za-z])? { return text(); }

userProcCall = "CALL"i __ name:identifier _ args:(_ "(" _ exprArgs _ ")")?
  { return {type: "procedureCall", name, args: args ? args[3] : []}; }
userFuncCall = "FN"i __ name:identifier args:(_ "(" _ exprArgs _ ")")?
  { return {type: "userFuncCall", name, args: args ? args[3] : []}; }

defFn = "DEF"i __ "FN"i __ name:identifier _ args:("(" _ funcParams _ ")")? _ "=" _ value:expression
  { return {type: "defFn", name, args: args ? args[2] : [], value}; }
  / "DEF"i __ "FN"i __ name:identifier _ args:("(" _ funcParams _ ")")? _ "USING"i __ globalRef:expression
  { return {type: "defFn", name, args: args ? args[2] : [], using: globalRef}; }
definition = "DEF"i __ name:identifier __ "=" __ value:expression
  { return {type: "def", name, value}; }
defCmd = "DEF"i __ keyword:identifier _ "=" _ arg:expression
  { return {type: "defCmd", keyword, arg}; }
  / "DEF"i __ keyword:identifier _ "(" _ args:exprOptArgs? _ ")"
  { return {type: "defCmd", keyword, args: args || []}; }
  / "DEF"i __ keyword:identifier arg:(_ expression)?
  { return {type: "defCmd", keyword, arg: arg ? arg[1] : null}; }
assignVar = name:identifier fields:("." identifier)* field:(";" _ (integer / variable))? _ idx:("(" _ exprArgs _ ")")? _ "=" _ value:expression
  { return {type: "assign", name, fields: fields.map(f => f[1]), field: field ? field[2] : null, idx: idx ? idx[2] : null, value}; }

userLongFuncDef
  = "LONG FN"i __ name:identifier args:(_ "(" _ funcParams _ ")")? _ separator !"END FN"i body:block _ "END FN"i ret:(_ "=" _ expression)?
    { return {type: "function", name, args: args ? (args[3] || []) : [], body, ret: ret ? ret[3] : null}; }
userLocalFuncDef
  = "LOCAL FN"i __ name:identifier args:(_ "(" _ funcParams _ ")")? _ separator !"END FN"i body:block _ "END FN"i ret:(_ "=" _ expression)?
    { return {type: "localFunction", name, args: args ? (args[3] || []) : [], body, ret: ret ? ret[3] : null}; }

blockIfCond = "IF"i _ condition:multiLineCondition _ "THEN"i _ separator !"END IF"i body:block maybeElse:(_ "ELSE"i _ separator block)? _ "END IF"i
  { return {type: "if", condition, body, else: maybeElse ? maybeElse[4] : null}; }
ifCond = "IF"i _ condition:multiLineCondition _ ("THEN"i _)? action:singleLineBody maybeElse:(_ "ELSE"i __ singleLineBody)?
  { return {type: "if", condition, body: action, else: maybeElse ? maybeElse[3] : null}; }
multiLineCondition = head:expression tail:(newline white+ !("IF"i ![a-zA-Z0-9_%&!$]) expression)*
  { return tail.reduce((acc, t) => ({type: "binop", op: "AND", left: acc, right: t[3]}), head); }
singleLineBody = head:statement tail:(_ ":" _ !"ELSE"i statement)*
  { return [head, ...tail.map(t => t[4])].filter(s => s !== null); }
longIfConf = "LONG IF"i __ condition:expression _ separator body:block maybeElse:(_ "XELSE"i _ block)?  _ "END IF"i
  { return {type: "if", condition, body, else: maybeElse ? maybeElse[3] : null}; }

forLoop = "FOR"i __ variable:identifier _ "=" _ start:expression __ "TO"i __ end:expression (__ "STEP"i __ expression)? _ separator body:block _ "NEXT"i (__ identifier)?
  { return {type: "for", variable, start, end, body}; }
whileLoop = "WHILE"i __ condition:expression _ separator body:block _ "WEND"i
  { return {type: "while", condition, body}; }
doLoop = "DO"i _ separator body:block _ "UNTIL"i __ condition:expression
  { return {type: "do_while", condition, body}; }
onStmt = "ON"i __ expr:expression __ "RETURN"i ![a-zA-Z0-9_%&!#$]
  { return {type: "on", expr, cmd: "RETURN", targets: []}; }
  / "ON"i __ expr:expression __ cmd:("GOSUB"i / "GOTO"i) _ targets:gotoTargets
  { return {type: "on", expr, cmd: cmd.toUpperCase(), targets}; }
gotoTargets = head:gotoTarget tail:(_ "," _ gotoTarget)*
  { return [head, ...tail.map(t => t[3])]; }
gotoTargetName = [a-zA-Z_À-ɏ][a-zA-Z0-9_À-ɏ]* { return text().toLowerCase(); }
gotoTarget = a:gotoTargetName ":" b:gotoTargetName "/" c:gotoTargetName
  { return {type: "variable", name: a + ":" + b + "/" + c}; }
  / a:gotoTargetName ":" b:gotoTargetName
  { return {type: "variable", name: a + ":" + b}; }
  / first:gotoTargetName rest:(__ gotoTargetName)+
  { return {type: "variable", name: first + rest.map(r => "_" + r[1]).join("")}; }
  / expression
endStmt = "END"i __ "GLOBALS"i { return {type: "endGlobals"}; }
  / "END"i !(__ "FN"i) !(__ "IF"i) !(__ "GLOBALS"i) !(__ "SELECT"i) { return {type: "end"}; }
dataStmt = "DATA"i __ items:dataArgs
  { return {type: "data", items}; }
dataArgs = head:dataItem tail:(_ "," _ dataItem)* _ ","?
  { return [head, ...tail.map(t => t[3])]; }
dataItem = string / float / integer / dataStr
dataStr = chars:(!("," / newline / comment) .)+ { return {type: "literal", value: text().trim()}; }

includeStmt = "INCLUDE"i __ "FILE"i __ n:expression
  { return {type: "includeFile", n}; }
  / "INCLUDE"i __ filename:string
  { const body = options.parseFile ? options.parseFile(filename.value) : [];
    return {type: "include", filename: filename.value, body}; }

selectStmt = "SELECT"i __ "CASE"i __ "CASE"i __ expr:expression _ separator cases:selectCase* _ "END SELECT"i
  { return {type: "select", expr, cases}; }
  / "SELECT"i __ ("CASE"i __)? expr:expression _ separator cases:selectCase* _ "END SELECT"i
  { return {type: "select", expr, cases}; }
selectCase = (_ separator)* _ "CASE"i _ "ELSE"i _ separator body:block
  { return {type: "case", values: "else", body}; }
  / (_ separator)* _ "CASE"i _ values:caseValues _ separator body:block
  { return {type: "case", values, body}; }
caseValues = head:caseValue tail:(_ "," _ caseValue)*
  { return [head, ...tail.map(t => t[3])]; }
caseValue = from:expression __ "TO"i __ to:expression
  { return {type: "range", from, to}; }
  / ("IS"i __)? op:compOp _ expr:expression
  { return {type: "relational", op, expr}; }
  / expression

//////////////////////// expressions ////////////////////////

expression = logicalOr
logicalOr = left:logicalAnd _ "OR"i _ right:logicalOr
  { return {type: "binary", operator: "OR", left, right}; }
  / logicalAnd
logicalAnd = left:not _ "AND"i _ right:logicalAnd
  { return {type: "binary", operator: "AND", left, right}; }
  / not
not = "NOT"i _ expression:not
  { return {type: "unary", operator: "NOT", expression}; }
  / comparison
compOp = "=" / "<>" / "<=" / ">=" / "<" / ">"
comparison
  = left:concat _ operator:compOp _ right:comparison
  { return {type: "binary", operator, left, right}; }
  / concat
concat = left:shift _ "&" _ right:concat
  { return {type: "binary", operator: "&", left, right}; }
  / shift
shift = left:additive _ op:("<<" / ">>") _ right:shift
  { return {type: "binary", operator: op, left, right}; }
  / additive
additive = left:multiplicative _ operator:("+" / "-") _ right:additive
  { return {type: "binary", operator, left, right}; }
  / multiplicative
multiplicative = left:power _ operator:mulOp _ right:multiplicative
  { return {type: "binary", operator, left, right}; }
  / power
mulOp = "MOD"i ![a-zA-Z0-9_%&!#$] { return "MOD"; } / "*" / "/" / "\\"
power = base:unary _ "^" _ exp:power
  { return {type: "binary", operator: "^", left: base, right: exp}; }
  / unary
unary
  = "-" _ expression:unary
  { return { type: "unary", operator: "-", expression}; }
  / "+" _ expression:unary
  { return { type: "unary", operator: "+", expression}; }
  / "&" digits:([0-9a-fA-F]+) ![a-zA-Z_]
  { return {type: "constant", value: parseInt(digits.join(""), 16)}; }
  / "&" _ expression:unary
  { return { type: "unary", operator: "&", expression}; }
  / "@" _ expression:unary
  { return { type: "unary", operator: "@", expression}; }
  / "%" _ expression:unary
  { return { type: "unary", operator: "%", expression}; }
  / "#" _ expression:unary
  { return { type: "unary", operator: "#", expression}; }
  / primary
primary
  = userFuncCall / peekCall / lineLiteral / chainAccess / callable / namedConst / string / hexLiteral / float / integer / boolean / variable
lineLiteral = "LINE"i _ s:string
  { return {type: "lineRef", label: s.value}; }
  / "(" _ expr:expression _ ")" { return expr; }
  / "[" _ expr:expression _ "]" { return {type: "deref", expr}; }
  / "{" _ expr:expression _ "}" { return {type: "compileConst", expr}; }
chainAccess = name:identifier fields:("." identifier)+ args:(_ "(" _ exprOptArgs? _ ")")?
  { return {type: "chainAccess", name, fields: fields.map(f => f[1]), args: args ? (args[3] || []) : null}; }
hexLiteral = "&H" digits:[0-9a-fA-F]+ { return {type: "constant", value: parseInt(digits.join(""), 16)}; }
  / "&O" digits:[0-7]+ { return {type: "constant", value: parseInt(digits.join(""), 8)}; }

namedConst = "_" s:string
  { return {type: "namedConst", name: s.value}; }

// ambiguous: can be array or built-in function call
// e.g., A(0) can be access index=0 of A or call built-in function A
callable = name:identifier _ "(" _ args:exprOptArgs? _ ")"
  { return {type: "callable", name, args: args || []}; }
peekCall = "PEEK"i __ type:("WORD"i / "LONG"i / "BYTE"i) _ "(" _ args:exprArgs? _ ")"
  { return {type: "callable", name: "PEEK " + type.toUpperCase(), args: args || []}; }
  / "PEEK"i _ "(" _ args:exprArgs? _ ")"
  { return {type: "callable", name: "PEEK", args: args || []}; }
  / "USR"i __ n:integer _ "(" _ args:exprArgs? _ ")"
  { return {type: "callable", name: "USR", args: [n, ...(args || [])]}; }
  / "USR"i __ name:identifier _ "(" _ args:exprArgs? _ ")"
  { return {type: "callable", name: "USR_" + name, args: args || []}; }

exprArgs = head:expression tail:(_ "," _ expression)*
  { return [head, ...tail.map(t => t[3])]; }
exprOptArgs = head:(expression / nop) tail:(_ "," _ (expression / nop))*
  { return [head, ...tail.map(t => t[3])]; }

//////////////////////// tokens ////////////////////////

identifier = [a-zA-Z_][a-zA-Z0-9_]*([%&!#$])? { return text().toLowerCase(); }
number = sign:"-"? digits:[0-9]+ { return parseInt((sign || "") + digits.join(""), 10); }
string = '"' chars:char* '"' { return {type: "literal", value: chars.join("")}; }
  / '"' chars:char* &(newline / EOF) { return {type: "literal", value: chars.join("")}; }
integer = value:number [&!%#]? { return {type: "constant", value}; }
boolean = "True"i ![a-zA-Z0-9_%&!#$] { return {type: "constant", value: true}; }
  / "False"i ![a-zA-Z0-9_%&!#$] { return {type: "constant", value: false}; }
float = int:[0-9]+ "." frac:[0-9]* [&!%#]? { return {type: "constant", value: parseFloat(int.join("") + "." + frac.join(""))}; }
  / "." frac:[0-9]+ [&!%#]? { return {type: "constant", value: parseFloat("." + frac.join(""))}; }
variable = !(("ELSE"i / "THEN"i / "AND"i / "OR"i / "NOT"i / "RETURN"i / "GOSUB"i / "GOTO"i / "END"i / "NEXT"i / "WEND"i / "UNTIL"i / "XELSE"i / "FOR"i / "WHILE"i / "DO"i / "CALL"i / "DEF"i / "DIM"i / "REM"i / "FN"i / "IF"i / "DATA"i / "ON"i / "STEP"i / "TO"i / "USING"i / "SELECT"i / "CASE"i / "LOCAL"i) ![a-zA-Z0-9_%&!#$]) name:identifier { return {type: "variable", name}; }
char = '\\' c:['"\\'] { return c; }
  / !'"' !newline c:. { return text(); }

newline = "\r\n" / "\n" / "\r"
comment = ("REM"i ![a-zA-Z] / "'") (!newline .)*
_  = white*  // optional
__ = white+  // mandatory
white = [ \t]+
EOF = !.
