start = statements
statements
  = statement:statement EOF { return [statement]; }
  / statement:statement newline statements:statements { return [statement] + statements; }
  / statement:statement optional_whitespace ":" optional_whitespace statements:statements { return [statement] + statements; }

statement = dim_statement / call_statement

dim_statement
  = "DIM" mandatory_whitespace name:name dtype:dtype shape:shape { return {cmd: "DIM", name, dtype, shape}; }

call_statement = name:name mandatory_whitespace parameters:parameters { return {cmd: name, parameters}; }

shape = "(" dims:dims ")" { return dims; }
dims
  = integer:integer "," dims:dims { return [integer] + dims; }
  / integer:integer { return [integer]; }
  / "" { return []; }

dtype
  = "%" / "&" { return "int"; }
  / "!" / "#" { return "real"; }
  / "$" { return "string"; }

parameters
  = parameter:parameter optional_whitespace "," optional_whitespace parameters:parameters { return [parameter] + parameters; }
  / parameter:parameter { return [parameter]; }
  / "" { return []; }

parameter
  = constant:integer { return {type: "integer", value: constant}; }
  / literal:string { return {type: "literal", value: literal}; }
  / variable:name { return {type: "variable", value: variable}; }

name = [a-zA-Z_][a-zA-Z0-9_]* { return text(); }
integer = [0-9]+ { return parseInt(text()); }
string = "\"" chars:[^\"]* "\"" { return chars.join(""); }

mandatory_whitespace = " "+
optional_whitespace = " "*
newline = [\n\r]+
EOF = !.
