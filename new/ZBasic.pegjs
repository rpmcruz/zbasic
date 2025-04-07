start = stmts:(_ separator _ statement?)* _ EOF {
  return stmts.flatMap(t => Array.isArray(t[3]) ? t[3] : [t[3]])
    .filter(s => s !== null && s !== undefined); }
separator = ":" / newline

//////////////////////// statements ////////////////////////

statement
  = declaration
  / functionCall
  / coordinate
  / definition

declaration = "DIM" _ head:dimsPart tail:(_ "," _ dimsPart)*
  { return [head, ...tail.map(t => t[3])]; }
dimsPart =
  sizePart:(_ number _)?
  name:identifier _
  dimsPart:("(" _ dims:dimensions _ ")")?
  { return {type: "declaration", name, dtype: "!#".includes(name[name.length-1]) ? "float" :  "$" == name[name.length-1] ? "string" : "int", size: sizePart ? sizePart[2] : null, dimensions: dimsPart ? dimsPart[2] : []}; }
functionCall = name:identifier _ "(" _ args:arguments? _ ")"
  { return {type: "functionCall", name, args: args || []};}
arguments = head:expression tail:(_ "," _ expression)*
  { return [head, ...tail.map(t => t[3])]; }
dimensions = arguments  // same format as args
coordinate = "COORDINATE" _ "WINDOW" { return {type: "coordinate", horizontal: 0, vertical: 0}; }
  / "COORDINATE" _ horizontal:number "," vertical:number { return {type: "coordinate", horizontal, vertical}; }
definition = "DEF" _ variable:identifier valuePart:(_ "=" _ integer)? { return {type: "definition", variable, value: valuePart ? valuePart[3] : null}; }

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
comment = ("REM" / "'") (!newline .)* (newline / EOF)
// optional whitespace or comments
_  = (white / comment)*
__ = white+
white = [ \t]+
EOF = !.