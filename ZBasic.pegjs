{
let progressCallback = options.progressCallback || (() => {});
}

start = block:block EOF { return block; }

//////////////////////// statements ////////////////////////

block
  = _ stmt:statementWithProgress _ separator rest:block
    { return stmt ? [stmt, ...rest] : rest; }
  / _ stmt:statementWithProgress _
    { return stmt ? [stmt] : []; }
separator = ":" / newline / comment newline

statementWithProgress = s:statement
  { progressCallback(location().start.line, s); return s; }
statement = comment { return null; }
  / defFn / definition / defCmd / dimVar / assignVar
  / userProcCall / userFuncCall / userLongFuncDef / userLocalFuncDef / printStmt / pokeStmt / sysFuncCall / dataStmt
  / includeStmt
  / forLoop / whileLoop / doLoop
  / blockIfCond / ifCond / longIfConf / selectStmt
  / onStmt / endStmt
  / label
  / exprStmt
  / nop

exprStmt = e:expression { return {type: "exprStmt", expr: e}; }

sysFuncCall = cmd:sysCmds ![a-zA-Z0-9_%&!$] chan:("#" expression)? keyword:(__ sysKeyword)? _ args:sysArgs trailer:(_ sysKeyword _ sysArgs)*
  { return {type: "sysFuncCall", cmd, chan: chan ? chan[1] : null,
    keyword: keyword ? keyword[1] : null, args,
    trailer: trailer.map(t => ({keyword: t[1], args: t[3]})) }; }
sysKeyword = !("ELSE" / "THEN" / "AND" / "OR" / "NOT" / "NEXT" / "WEND" / "UNTIL" / "XELSE" / "FOR" / "WHILE" / "DO" / "CALL" / "DEF" / "DIM" / "REM" / "FN" / "IF" / "END" / "LONG" / "SELECT" / "CASE" / "LOCAL") [A-Z][A-Z]+ ![a-zA-Z0-9_%&!$]
  { return text(); }
sysCmds = "GOTO" / "GOSUB" / "RETURN"
  / "RESOURCES" / "COMPILE" / "WIDTH" / "GLOBALS"
  / "COORDINATE" / "DIALOG" / "MENU" / "MOUSE" / "CURSOR"
  / "PEN" / "GET" / "PUT" / "PLOT" / "BOX" / "TEXT"
  / "COLOR" / "CIRCLE" / "CLS" / "WINDOW" / "SCROLL" / "DELAY"
  / "CLEAR" / "BUTTON" / "SOUND" / "WAVE" / "SEGMENT"
  / "DEFSTR" / "READ" / "RESTORE" / "INPUT" / "OPEN" / "CLOSE"
  / "RANDOM" / "SWAP" / "BREAK" / "APPLE" / "ROUTE" / "RATIO"
  / "BEEP" / "HOME" / "INVERSE" / "NORMAL" / "FLASH" / "VTAB" / "HTAB"
  / "POKE" / "RESUME" / "POP" / "TRACE" / "NOTRACE" / "SPEED"
  / "LPRINT" / "LLIST" / "STOP" / "WAIT" / "HPLOT"
  / "HCOLOR" / "HGRAPH" / "SCRN" / "WRITE" / "%" / "EDIT"
  / "SETSELECT" / "INC" / "DEC" / "KILL" / "PT"
  / "BLOCKMOVE" / "LIBRARY" / "TOOLBOX" / "INLINE" / "CHAIN"
  / "TALK" / "LINE" / "PICTURE"
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
exprFromTo = fromX:expression _ "," _ fromY:expression segs:(__ "TO" __ expression _ "," _ expression)+
  { const points = [[fromX, fromY], ...segs.map(s => [s[3], s[5]])];
    return {type: "polyline", from: points[0], to: points[points.length-1], points}; }
exprPoint = "(" _ x:expression _ "," _ y:expression _ ")"
  { return {x, y}; }
nop = _ { return null; }

pokeStmt = "POKE" __ type:("LONG" / "WORD" / "BYTE") __ addr:expression _ "," _ val:expression
  { return {type: "sysFuncCall", cmd: "POKE " + type, args: [addr, val]}; }
printStmt = "PRINT" mode:printMode _ items:printList?
  { return {type: "print", mode, items: items || []}; }
printMode = _ mode:("%" / "@") _ coord:exprPoint _ ";"?
  { return {type: mode, coord}; }
  / _ "#" _ chan:expression _ ","?
  { return {type: "#", chan}; }
  / "" { return {type: "plain"}; }
printList = head:printItem tail:(printSep? printItem)* printSep?
  { return [head, ...tail.map(t => t[1])]; }
printItem = "USING" _ format:expression _ ";" _ expr:expression
  { return {type: "using", format, expr}; }
  / expression
printSep = _ (";" / ",") _

label = '"' chars:char* '"'
  { return {type: "label", label: chars.join("")}; }
  / a:identifier ":" b:identifier "/" c:identifier _ ":"
  { return {type: "label", label: a + ":" + b + "/" + c}; }
  / a:identifier ":" b:identifier _ ":"
  { return {type: "label", label: a + ":" + b}; }
  / name:identifier _ ":"
  { return {type: "label", label: name}; }

dimVar = "DIM" __ args:dimArgs
  { return {type: "dim", args}; }
dimArgs = head:dimPart tail:(_ "," _ dimPart)*
  { return [head, ...tail.map(t => t[3])]; }
dimPart = prefix:number? _ name:identifier dims:("(" intArgs ")")? {
  return { name, prefix, dims: dims ? dims[1] : []}; }
intArgs = head:number tail:(_ "," _ number)*
  { return [head, ...tail.map(t => t[3])]; }

userProcCall = "CALL" __ name:identifier _ args:(_ "(" _ exprArgs _ ")")?
  { return {type: "procedureCall", name, args: args ? args[3] : []}; }
userFuncCall = "FN" __ name:identifier args:(_ "(" _ exprArgs _ ")")?
  { return {type: "userFuncCall", name, args: args ? args[3] : []}; }

defFn = "DEF" __ "FN" __ name:identifier _ args:("(" _ exprArgs _ ")")? _ "=" _ value:expression
  { return {type: "defFn", name, args: args ? args[2] : [], value}; }
definition = "DEF" __ name:identifier __ "=" __ value:expression
  { return {type: "def", name, value}; }
defCmd = "DEF" __ keyword:identifier _ "=" _ arg:expression
  { return {type: "defCmd", keyword, arg}; }
  / "DEF" __ keyword:identifier arg:(__ expression)?
  { return {type: "defCmd", keyword, arg: arg ? arg[1] : null}; }
assignVar = name:identifier dotField:("." identifier)? field:(";" _ integer)? _ idx:("(" _ exprArgs _ ")")? _ "=" _ value:expression
  { return {type: "assign", name, dotField: dotField ? dotField[1] : null, field: field ? field[2] : null, idx: idx ? idx[2] : null, value}; }

userLongFuncDef
  = "LONG FN" __ name:identifier args:(_ "(" _ exprArgs _ ")")? _ separator !"END FN" body:block _ "END FN" ret:(_ "=" _ expression)?
    { return {type: "function", name, args: args ? (args[3] || []) : [], body, ret: ret ? ret[3] : null}; }
userLocalFuncDef
  = "LOCAL FN" __ name:identifier args:(_ "(" _ exprArgs _ ")")? _ separator !"END FN" body:block _ "END FN" ret:(_ "=" _ expression)?
    { return {type: "localFunction", name, args: args ? (args[3] || []) : [], body, ret: ret ? ret[3] : null}; }

blockIfCond = "IF" _ condition:expression _ "THEN" _ separator !"END IF" body:block maybeElse:(_ "ELSE" _ separator block)? _ "END IF"
  { return {type: "if", condition, body, else: maybeElse ? maybeElse[4] : null}; }
ifCond = "IF" _ condition:expression _ ("THEN" _)? action:singleLineBody maybeElse:(_ "ELSE" __ singleLineBody)?
  { return {type: "if", condition, body: action, else: maybeElse ? maybeElse[3] : null}; }
singleLineBody = head:statement tail:(_ ":" _ !"ELSE" statement)*
  { return [head, ...tail.map(t => t[4])].filter(s => s !== null); }
longIfConf = "LONG IF" __ condition:expression _ separator body:block maybeElse:(_ "XELSE" _ block)?  _ "END IF"
  { return {type: "if", condition, body, else: maybeElse ? maybeElse[3] : null}; }

forLoop = "FOR" __ variable:identifier _ "=" _ start:expression __ "TO" __ end:expression (__ "STEP" __ expression)? _ separator body:block _ "NEXT" (__ identifier)?
  { return {type: "for", variable, start, end, body}; }
whileLoop = "WHILE" __ condition:expression _ separator body:block _ "WEND"
  { return {type: "while", condition, body}; }
doLoop = "DO" _ separator body:block _ "UNTIL" __ condition:expression
  { return {type: "do_while", condition, body}; }
onStmt = "ON" __ expr:expression __ "RETURN" ![a-zA-Z0-9_%&!#$]
  { return {type: "on", expr, cmd: "RETURN", targets: []}; }
  / "ON" __ expr:expression __ cmd:("GOSUB" / "GOTO") _ targets:gotoTargets
  { return {type: "on", expr, cmd, targets}; }
gotoTargets = head:gotoTarget tail:(_ "," _ gotoTarget)*
  { return [head, ...tail.map(t => t[3])]; }
gotoTargetName = [a-zA-Z_À-ɏ][a-zA-Z0-9_À-ɏ]* { return text(); }
gotoTarget = a:gotoTargetName ":" b:gotoTargetName "/" c:gotoTargetName
  { return {type: "variable", name: a + ":" + b + "/" + c}; }
  / a:gotoTargetName ":" b:gotoTargetName
  { return {type: "variable", name: a + ":" + b}; }
  / first:gotoTargetName rest:(__ gotoTargetName)+
  { return {type: "variable", name: first + rest.map(r => "_" + r[1]).join("")}; }
  / expression
endStmt = "END" __ "GLOBALS" { return {type: "endGlobals"}; }
  / "END" !(__ "FN") !(__ "IF") !(__ "GLOBALS") !(__ "SELECT") { return {type: "end"}; }
dataStmt = "DATA" __ items:dataArgs
  { return {type: "data", items}; }
dataArgs = head:dataItem tail:(_ "," _ dataItem)* _ ","?
  { return [head, ...tail.map(t => t[3])]; }
dataItem = string / float / integer / dataStr
dataStr = chars:(!("," / newline / comment) .)+ { return {type: "literal", value: text().trim()}; }

includeStmt = "INCLUDE" __ "FILE" __ n:expression
  { return {type: "includeFile", n}; }
  / "INCLUDE" __ filename:string
  { const body = options.parseFile ? options.parseFile(filename.value) : [];
    return {type: "include", filename: filename.value, body}; }

selectStmt = "SELECT" __ "CASE" __ "CASE" __ expr:expression _ separator cases:selectCase* _ "END SELECT"
  { return {type: "select", expr, cases}; }
  / "SELECT" __ ("CASE" __)? expr:expression _ separator cases:selectCase* _ "END SELECT"
  { return {type: "select", expr, cases}; }
selectCase = (_ separator)* _ "CASE" _ "ELSE" _ separator body:block
  { return {type: "case", values: "else", body}; }
  / (_ separator)* _ "CASE" _ values:caseValues _ separator body:block
  { return {type: "case", values, body}; }
caseValues = head:caseValue tail:(_ "," _ caseValue)*
  { return [head, ...tail.map(t => t[3])]; }
caseValue = from:expression __ "TO" __ to:expression
  { return {type: "range", from, to}; }
  / ("IS" __)? op:compOp _ expr:expression
  { return {type: "relational", op, expr}; }
  / expression

//////////////////////// expressions ////////////////////////

expression = logicalOr
logicalOr = left:logicalAnd _ "OR" _ right:logicalOr
  { return {type: "binary", operator: "OR", left, right}; }
  / logicalAnd
logicalAnd = left:not _ "AND" _ right:logicalAnd
  { return {type: "binary", operator: "AND", left, right}; }
  / not
not = "NOT" _ expression:not
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
mulOp = "MOD" ![a-zA-Z0-9_%&!#$] { return "MOD"; } / "*" / "/" / "\\"
power = base:unary _ "^" _ exp:power
  { return {type: "binary", operator: "^", left: base, right: exp}; }
  / unary
unary
  = "-" _ expression:unary
  { return { type: "unary", operator: "-", expression}; }
  / "+" _ expression:unary
  { return { type: "unary", operator: "+", expression}; }
  / "&" _ expression:unary
  { return { type: "unary", operator: "&", expression}; }
  / "@" _ expression:unary
  { return { type: "unary", operator: "@", expression}; }
  / primary
primary
  = userFuncCall / peekCall / callable / namedConst / string / float / integer / boolean / variable
  / "(" _ expr:expression _ ")" { return expr; }
  / "[" _ expr:expression _ "]" { return {type: "deref", expr}; }

namedConst = "_" s:string
  { return {type: "namedConst", name: s.value}; }

// ambiguous: can be array or built-in function call
// e.g., A(0) can be access index=0 of A or call built-in function A
callable = name:identifier _ "(" _ args:exprOptArgs? _ ")"
  { return {type: "callable", name, args: args || []}; }
peekCall = "PEEK" __ type:("WORD" / "LONG" / "BYTE") _ "(" _ args:exprArgs? _ ")"
  { return {type: "callable", name: "PEEK " + type, args: args || []}; }
  / "PEEK" _ "(" _ args:exprArgs? _ ")"
  { return {type: "callable", name: "PEEK", args: args || []}; }
  / "USR" __ n:integer _ "(" _ args:exprArgs? _ ")"
  { return {type: "callable", name: "USR", args: [n, ...(args || [])]}; }

exprArgs = head:expression tail:(_ "," _ expression)*
  { return [head, ...tail.map(t => t[3])]; }
exprOptArgs = head:(expression / nop) tail:(_ "," _ (expression / nop))*
  { return [head, ...tail.map(t => t[3])]; }

//////////////////////// tokens ////////////////////////

identifier = [a-zA-Z_][a-zA-Z0-9_]*([%&!#$])? { return text(); }
number = sign:"-"? digits:[0-9]+ { return parseInt((sign || "") + digits.join(""), 10); }
string = '"' chars:char* '"' { return {type: "literal", value: chars.join("")}; }
  / '"' chars:char* &(newline / EOF) { return {type: "literal", value: chars.join("")}; }
integer = value:number { return {type: "constant", value}; }
boolean = "True" ![a-zA-Z0-9_%&!#$] { return {type: "constant", value: true}; }
  / "False" ![a-zA-Z0-9_%&!#$] { return {type: "constant", value: false}; }
float = int:[0-9]+ "." frac:[0-9]* { return {type: "constant", value: parseFloat(int.join("") + "." + frac.join(""))}; }
  / "." frac:[0-9]+ { return {type: "constant", value: parseFloat("." + frac.join(""))}; }
variable = !(("ELSE" / "THEN" / "AND" / "OR" / "NOT" / "RETURN" / "GOSUB" / "GOTO" / "END" / "NEXT" / "WEND" / "UNTIL" / "XELSE" / "FOR" / "WHILE" / "DO" / "CALL" / "DEF" / "DIM" / "REM" / "FN" / "IF" / "DATA" / "ON" / "STEP" / "TO" / "USING" / "SELECT" / "CASE" / "LOCAL") ![a-zA-Z0-9_%&!#$]) name:identifier { return {type: "variable", name}; }
char = '\\' c:['"\\'] { return c; }
  / !'"' !newline c:. { return text(); }

newline = "\r\n" / "\n" / "\r"
comment = ("REM" ![a-zA-Z] / "'") (!newline .)*
_  = white*  // optional
__ = white+  // mandatory
white = [ \t]+
EOF = !.
