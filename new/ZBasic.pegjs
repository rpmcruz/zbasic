{
  let positionCallback = options.positionCallback || (() => {});
}

start = scope EOF
scope = stmts:(statementWithProgress _ separator _)*

separator = ":" / newline / comment

statementWithProgress
  = s:statement {
      positionCallback(location().start.line);
      return s;
    }

statement = assignment
  / declaration
  / labelDefinition
  / functionDefinition
  / forLoop
  / whileLoop
  / ifStatement
  / longIfStatement
  / comment / definition / usercall / syscall
  / none

// does return need to be explicit?
//  / returnStatement

// ZBasic has functions like:
// (1) FUNC a, b
// built-in statements or commands, like PRINT
// (2) c = FUNC(a, b)
// built-in functions that return values, like math or string operations
// (3) c = FN FUNC(a, b)
// user-defined functions
// (4) CALL FUNC(a, b)
// I think these are user-defined functions that do not return anything (i.e., procedures)
//
// we treat (1) and (4) as statements. (2) and (3) as expressions.

syscall
  = cmd:[A-Z]+ _ keyword:([A-Z]+)? _ args:syscallArgs? {
      return {
        type: "syscall",
        cmd,
        keyword,
        args: args || []
      };
    }

syscallArgs = first:syscallArg rest:(_ "," _ syscallArg)* {
  return [first, ...rest.map(r => r[3])];
}
syscallArg = numFromTo / exprFromTo / expression / none
numFromTo = "(" number "," number ")-(" number "," number ")"
exprFromTo = expression _ "," _ expression __ "TO" __ expression _ "," _ expression
none = ""

labelDefinition = '"' chars:char* '"'

declaration
  = "DIM" __ head:dimPart tail:(_ "," _ dimPart)* {
      return {
        type: "declaration",
        vars: [head, ...tail.map(t => t[3])]
      };
    }
dimPart
  = prefix:number? _ name:identifier dims:("(" intArgs ")")? {
      return {
        name,
        prefix: prefix ?? null,
        dimensions: dims ? dims[1] : []
      };
    }
intArgs
  = head:number tail:(_ "," _ number)* {
      return [head, ...tail.map(t => t[3])];
    }

usercall
  = "CALL" __ name:identifier _ "(" _ args:funcArgs? _ ")" {
      return { type: "procedureCall", name, args: args || [] };
    }

definition = "DEF" __ name:identifier __ "=" __ value:expression
  { return { cmd: "DEF", name, value }; }

assignment = variable _ "=" _ expression

functionDefinition
  = "LONG FN" __ name:identifier
    (_ "(" _ args:funcArgs _ ")")? _ separator
// FIXME: stop scope on END FN
// scope = stmts:(!(("XELSE" / "END IF") _) statement _ separator)*
// it's possible to pass parameters to rules, such as:
//thenScope = scopeUntil(["XELSE", "END IF"])
//elseScope = _ "XELSE" _ scopeUntil(["END IF"])
//scopeUntil[terminators] = stmts:(!terminatorLine statement _ separator)* { return stmts.map(s => s[0]); }
// ..but we need to be careful when terminating using lookaheads because of nested statements
//   like LONG IF
    statements:scope
    _ "END FN" {
      return { type: "function", name, args: args || [], statements };
    }
ifStatement
  = "IF" __ cond:expression __ ("THEN" __)? action:statement elsePart:(_ "ELSE" __ elseAction:statement)? {
      return {
        type: "if",
        condition: cond,
        action,
        else: elsePart ? elsePart[3] : null
      };
    }
longIfStatement
  = "LONG IF" __ cond:expression _ separator
// FIXME: stop scope on XELSE OR END IF
// scope = stmts:(!(("XELSE" / "END IF") _) statement _ separator)*
  thenBlock:scope
    elseBlock:(_ "XELSE" _ elseScope:scope)? 
    _ "END IF" {
      return {
        type: "longIf",
        condition: cond,
        then: thenBlock,
        else: elseBlock ? elseBlock[3] : null
      };
    }
returnStatement = "RETURN" { return { type: "return" }; }

forLoop
  = "FOR" __ variable:identifier _ "=" _ start:expression __ "TO" __ end:expression (__ "STEP" __ number)? _ separator
// FIXME: stop scope on NEXT
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

whileLoop
  = "WHILE" __ condition:expression _ separator
// FIXME: stop scope on WEND
    body:scope
    _ "WEND" {
      return {
        type: "while",
        condition,
        body,
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
  = left:unary _ op:("*" / "/") _ right:multiplicative
    { return { type: "binary", operator: op, left, right }; }
  / unary

unary
  = "-" _ expr:unary
    { return { type: "unary", operator: "-", expression: expr }; }
  / "+" _ expr:unary
    { return { type: "unary", operator: "+", expression: expr }; }
  / primary

primary
  = functionCall / callable / string / float / integer / variable
  / "(" _ expr:expression _ ")" { return expr; }

// function expressions

funcArgs
  = head:expression tail:(_ "," _ expression)* {
      return [head, ...tail.map(t => t[3])];
    }


// FN func = user defined function
functionCall
  = "FN" __ name:identifier _ "(" _ args:funcArgs? _ ")" {
      return { type: "functionCall", name, args: args || [] };
    }

// ambiguous: can be array or built-in function call
// e.g., A(0) can be access index=0 of A or call built-in function A
callable
  = name:identifier _ "(" args:funcArgs? ")" {
      return { type: "callable", name, args: args || [] };
    }


//////////////////////// mid-level ////////////////////////

identifier = [a-zA-Z_][a-zA-Z0-9_]*([%&!#$])? { return text(); }
number = sign:"-"? digits:[0-9]+ { return parseInt((sign || "") + digits.join(""), 10); }
string = '"' chars:char* '"' { return {type: "literal", value: chars.join("")}; }
integer = value:number { return {type: "constant", value}; }
boolean = "True" { return {type: "constant", value: true}; }
  / "False" { return {type: "constant", value: false}; }
float = int:[0-9]+ "." frac:[0-9]+ { return {type: "constant", value: parseFloat(int.join("") + "." + frac.join(""))}; }
variable = name:identifier { return {type: "variable", name}; }
char = '\\' ['"\\'] / !'"' .

//////////////////////// low-level ////////////////////////

newline = "\r\n" / "\n" / "\r"
comment = ("REM" / "'") (!newline .)*
_  = white*  // optional
__ = white+  // mandatory
white = [ \t]+
EOF = !.