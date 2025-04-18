start = scope EOF
scope = stmts:(statement? _ separator _)*

separator = ":" / newline / comment
statement = assignment
  / functionDefinition
  / forLoop
  / ifStatement
  / returnStatement
  / comment / definition / syscall / functionCall

syscall = [A-Z]+ __ params
functionCall
  = name:identifier _ "(" _ args:funcArgs? _ ")" {
      return { type: "functionCall", name, args: args || [] };
    }
definition = "DEF" __ name:identifier __ "=" __ value:expression
  { return { cmd: "DEF", name, value }; }

assignment = variable __ "=" __ expression

funcArgs
  = head:expression tail:(_ "," _ expression)* {
      return [head, ...tail.map(t => t[3])];
    }

params = first:param rest:(_ "," _ param)* {
  return [first, ...rest.map(r => r[3])];
}
param = vardim / line / expression
vardim = (number __)? identifier ("(" params ")")?
line = "(" number "," number ")-(" number "," number ")"

functionDefinition
  = long:"LONG" __ "FN" __ name:identifier
    (_ "(" _ args:funcArgs _ ")")? _ separator
    statements:scope
    _ "END" __ "FN" {
      return { type: "function", name, args: args || [], statements };
    }
ifStatement
  = "IF" __ cond:expression __ "THEN" __ action:statement {
      return { type: "if", condition: cond, action };
    }
returnStatement = "RETURN" { return { type: "return" }; }

forLoop
  = "FOR" __ variable:identifier _ "=" _ start:expression _ "TO" _ end:expression _ separator
    body:scope
    _ "NEXT" __ endVar:identifier {
      return {
        type: "for",
        variable,
        start,
        end,
        body,
        endVar
      };
    }

//////////////////////// expressions ////////////////////////

expression = logicalOr

logicalOr
  = left:logicalAnd _ "OR"i _ right:logicalOr
    { return { type: "binary", operator: "OR", left, right }; }
  / logicalAnd

logicalAnd
  = left:not _ "AND"i _ right:logicalAnd
    { return { type: "binary", operator: "AND", left, right }; }
  / not

not
  = "NOT"i _ expr:not
    { return { type: "unary", operator: "NOT", expression: expr }; }
  / comparison

comparison
  = left:concat _ op:compOp _ right:comparison
    { return { type: "binary", operator: op, left, right }; }
  / concat

compOp = "=" / "<>" / "<=" / ">=" / "<" / ">"

concat
  = left:shift _ "&" _ right:concat
    { return { type: "binary", operator: "&", left, right }; }
  / shift

shift
  = left:additive _ "<<" _ right:shift
    { return { type: "binary", operator: "<<", left, right }; }
  / additive

additive
  = left:multiplicative _ op:("+" / "-") _ right:additive
    { return { type: "binary", operator: op, left, right }; }
  / multiplicative

multiplicative
  = left:primary _ op:("*" / "/") _ right:multiplicative
    { return { type: "binary", operator: op, left, right }; }
  / primary

primary
  = functionCall / string / float / integer / variable
  / "(" _ expr:expression _ ")" { return expr; }

//////////////////////// mid-level ////////////////////////

identifier = [a-zA-Z_][a-zA-Z0-9_]*([%&!#$])? { return text(); }
number = digits:[0-9]+ { return parseInt(digits.join(""), 10); }
string = '"' chars:char* '"' { return {type: "literal", value: chars.join("")}; }
integer = digits:[0-9]+ { return {type: "constant", value: parseInt(digits.join(""), 10)}; }
boolean = "True" { return {type: "constant", value: true}; }
  / "False" { return {type: "constant", value: false}; }
float = int:[0-9]+ "." frac:[0-9]+ { return {type: "constant", value: parseFloat(int.join("") + "." + frac.join(""))}; }
variable = name:identifier { return {type: "variable", name}; }
char = ('\\' ['"\\']) / (!'"' .)

//////////////////////// low-level ////////////////////////

newline = "\r\n" / "\n" / "\r"
comment = ("REM" / "'") (!newline .)*
_  = white*  // optional
__ = white+  // mandatory
white = [ \t]+
EOF = !.