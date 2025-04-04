start = _ statements:statements _ EOF { return statements; }

//////////////////////// statements ////////////////////////

statements
  = head:statement tail:(_ separator _ statement)* {
      return [head, ...tail.map(t => t[3])];
    }
separator = ":" / newline

statement
  = declaration
  / functionCall

declaration
  = "DIM"i _
    sizePart:("(" _ size:number _ ")")?
    _ name:identifier 
    dtypePart:dtype?
    _ dimsPart:("(" _ dims:dimensions _ ")")?
    { return {type: "declaration", name, size: sizePart ? sizePart[2] : null, dtype: dtypePart !== null ? dtypePart : "int", dimensions: dimsPart ? dimsPart[2] : []}; }
functionCall
  = name:identifier _ "(" _ args:arguments? _ ")"
    { return {type: "functionCall", name, args: args || []};}
arguments
  = head:expression tail:(_ "," _ expression)* {return [head, ...tail.map(t => t[3])];}
dimensions = arguments  // same format as args
dtype
  = "%" / "&" { return "int"; }
  / "!" / "#" { return "real"; }
  / "$" { return "string"; }

//////////////////////// expressions ////////////////////////

expression = concat
concat = left:shift _ "&" _ right:concat { return {type: "binary", operator: "&", left, right}; }
  / shift
shift = left:additive _ "<<" _ right:shift { return {type: "binary", operator: "<<", left, right}; }
  / additive
additive = left:multiplicative _ op:("+" / "-") _ right:additive { return {type: "binary", operator: op, left, right}; }
  / multiplicative
multiplicative = left:primary _ op:("*" / "/") _ right:multiplicative { return {type: "binary", operator: op, left, right}; }
  / primary
primary = string / float / integer / variable
  / "(" _ expr:expression _ ")" { return expr; }

//////////////////////// mid-level ////////////////////////

identifier = [a-zA-Z_][a-zA-Z0-9_]* { return text(); }
number = digits:[0-9]+ { return parseInt(digits.join(""), 10); }
string = '"' chars:char* '"' { return {type: "string", value: chars.join("")}; }
integer = digits:[0-9]+ { return {type: "number", value: parseInt(digits.join(""), 10)}; }
boolean = "True" { return {type: "number", value: true}; }
  / "False" { return {type: "number", value: false}; }
float = int:[0-9]+ "." frac:[0-9]+ { return {type: "number", value: parseFloat(int.join("") + "." + frac.join(""))}; }
variable = name:identifier { return {type: "variable", name}; }
char = ('\\' ['"\\']) / (!'"' .)

//////////////////////// low-level ////////////////////////

newline = "\r\n" / "\n" / "\r"
comment = ("REM"i / "'") (!newline .)*
// optional whitespace or comments
_  = (white / comment)*
__ = white+
white = [ \t]+
EOF = !.