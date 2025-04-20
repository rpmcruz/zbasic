{
let progressCallback = options.progressCallback || (() => {});
}

start = block:block EOF { return block; }
block
  = _ stmt:statementWithProgress _ separator rest:block
    { return stmt ? [stmt, ...rest] : rest; }
  / _ stmt:statementWithProgress _
    { return stmt ? [stmt] : []; }
separator = ":" / newline / comment newline

statementWithProgress = s:statement
  { progressCallback(location().start.line, s); return s; }
statement = comment { return null; }
  / definition / dimVar / assignVar / label
  / userProcCall / userFuncCall / userLongFuncDef / sysFuncCall
  / forLoop / whileLoop
  / ifCond / longIfConf
  / nop

sysFuncCall = cmd:sysCmds keyword:(__ [A-Z]+)? args:(__ sysArgs)?
  { return {type: "sysFuncCall", cmd, keyword: keyword ? keyword[1] : null,
    args: args ? args[1] : null }; }
sysCmds = "GOTO" / "GOSUB" / "RETURN"
  / "COORDINATE" / "DIALOG" / "MENU" / "MOUSE"
  / "GET" / "PUT" / "PLOT"
sysArgs = first:sysArg rest:(_ "," _ sysArg)* {
  return [first, ...rest.map(r => r[3])];
}
sysArg = numFromTo / exprFromTo / expression / nop
numFromTo = "(" fromX:integer "," fromY:integer ")-(" toX:integer "," toY:integer ")"
  { return {from: [fromX, fromY], to: [toX, toY] }; }
exprFromTo = fromX:expression _ "," _ fromY:expression __ "TO" __ toX:expression _ "," _ toY:expression
  { return {from: [fromX, fromY], to: [toX, toY]}; }
nop = _ { return null; }

label = '"' chars:char* '"'
  {     console.log("chars =", chars);
    console.log("joined =", chars.join(""));
return {type: "label", label: chars.join("")}; }

dimVar = "DIM" __ args:dimArgs
  { return {type: "dim", args}; }
dimArgs = head:dimPart tail:(_ "," _ dimPart)*
  { return [head, ...tail.map(t => t[3])]; }
dimPart = prefix:number? _ name:identifier dims:("(" intArgs ")")? {
  return { name, prefix, dims: dims ? dims[1] : []}; }
intArgs = head:number tail:(_ "," _ number)*
  { return [head, ...tail.map(t => t[3])]; }

userProcCall = "CALL" __ name:identifier _ "(" _ args:exprArgs? _ ")"
  { return {type: "procedureCall", name, args: args || []}; }

definition = "DEF" __ name:identifier __ "=" __ value:expression
  { return {type: "def", name, value}; }
assignVar = name:variable _ "=" _ value:expression
  { return {type: "assign", name, value}; }

userLongFuncDef
  = "LONG FN" __ name:identifier args:(_ "(" _ exprArgs _ ")")? _ separator !"END FN" body:block _ "END FN"
    { return {type: "function", name, args: args ? (args[3] || []) : [], body: body[1]}; }
exprArgs = head:expression tail:(_ "," _ expression)*
  { return [head, ...tail.map(t => t[3])]; }
ifCond = "IF" __ condition:expression __ ("THEN" __)? action:statement maybeElse:(_ "ELSE" __ statement)?
  { return {type: "if", condition, body: [action], else: maybeElse ? maybeElse[3] : null}; }
longIfConf = "LONG IF" __ condition:expression _ separator body:block maybeElse:(_ "XELSE" _ block)?  _ "END IF"
  { return {type: "if", condition, body, else: maybeElse ? maybeElse[3] : null}; }

forLoop = "FOR" __ variable:identifier _ "=" _ start:expression __ "TO" __ end:expression (__ "STEP" __ number)? _ separator !"NEXT" body:block _ "NEXT" __ identifier
  { return {type: "for", variable, start, end, body}; }
whileLoop = "WHILE" __ condition:expression _ separator !"WEND" body:block _ "WEND"
  { return {type: "while", condition, body}; }

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
shift = left:additive _ "<<" _ right:shift
  { return {type: "binary", operator: "<<", left, right}; }
  / additive
additive = left:multiplicative _ operator:("+" / "-") _ right:additive
  { return {type: "binary", operator, left, right}; }
  / multiplicative
multiplicative = left:unary _ operator:("*" / "/") _ right:multiplicative
  { return {type: "binary", operator, left, right}; }
  / unary
unary
  = "-" _ expression:unary
  { return { type: "unary", operator: "-", expression}; }
  / "+" _ expression:unary
  { return { type: "unary", operator: "+", expression}; }
  / primary
primary
  = userFuncCall / callable / string / float / integer / variable
  / "(" _ expr:expression _ ")" { return expr; }

userFuncCall = "FN" __ name:identifier args:(_ "(" _ exprArgs _ ")")?
  { return {type: "userFuncCall", name, args: args ? args[3] : []}; }

// ambiguous: can be array or built-in function call
// e.g., A(0) can be access index=0 of A or call built-in function A
callable = name:identifier _ "(" args:exprArgs? ")"
  { return {type: "callable", name, args: args || []}; }

//////////////////////// mid-level ////////////////////////

identifier = [a-zA-Z_][a-zA-Z0-9_]*([%&!#$])? { return text(); }
number = sign:"-"? digits:[0-9]+ { return parseInt((sign || "") + digits.join(""), 10); }
string = '"' chars:char* '"' { return {type: "literal", value: chars.join("")}; }
integer = value:number { return {type: "constant", value}; }
boolean = "True" { return {type: "constant", value: true}; }
  / "False" { return {type: "constant", value: false}; }
float = int:[0-9]+ "." frac:[0-9]+ { return {type: "constant", value: parseFloat(int.join("") + "." + frac.join(""))}; }
variable = name:identifier { return {type: "variable", name}; }
char = '\\' c:['"\\'] { return c; }
  / !'"' c:. { return c; }

//////////////////////// low-level ////////////////////////

newline = "\r\n" / "\n" / "\r"
comment = ("REM " / "'") (!newline .)*
_  = white*  // optional
__ = white+  // mandatory
white = [ \t]+
EOF = !.