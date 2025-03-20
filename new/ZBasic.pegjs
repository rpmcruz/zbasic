start = statements
statements
  = statement:statement EOF { return [statement]; }
  / statement:statement newline statements:statements { return [statement].concat(statements); }
  / statement:statement opt_space ":" opt_space statements:statements { return [statement].concat(statements); }
  / comment* { return []; }

statement = dim_statement / call_statement

dim_statement
  = "DIM" force_space memsize:integer force_space name:name dtype:dtype shape:shape { return {cmd: "DIM", params: {name, dtype, shape}}; }
  / "DIM" force_space name:name dtype:dtype shape:shape { return {cmd: "DIM", params: {name, dtype, shape}}; }
  / "DIM" force_space name:name dtype:dtype { return {cmd: "DIM", params: {name, dtype, shape: []}}; }
  / "DIM" force_space name:name shape:shape { return {cmd: "DIM", params: {name, dtype: "integer", shape}}; }
  / "DIM" force_space name:name { return {cmd: "DIM", params: {name, dtype: "integer", shape: []}}; }

call_statement = name:name force_space params:params { return {cmd: name, params}; }

comment = ("REM" / "'") .* newline? { return null; }

shape = "(" dims:dims ")" { return dims; }
dims
  = integer:integer "," dims:dims { return [integer].concat(dims); }
  / integer:integer { return [integer]; }
  / "" { return []; }

dtype
  = "%" / "&" { return "int"; }
  / "!" / "#" { return "real"; }
  / "$" { return "string"; }

params
  = param:param opt_space "," opt_space params:params { return [param].concat(params); }
  / param:param { return [param]; }
  / "" { return []; }

param
  = constant:integer { return {type: "integer", value: constant}; }
  / literal:string { return {type: "literal", value: literal}; }
  / variable:name { return {type: "variable", value: variable}; }

name = [a-zA-Z_][a-zA-Z0-9_]* { return text(); }
integer = [0-9]+ { return parseInt(text()); }
string = "\"" chars:[^\"]* "\"" { return chars.join(""); }

force_space = " "+
opt_space = " "*
newline = [\n\r]+
EOF = !.
