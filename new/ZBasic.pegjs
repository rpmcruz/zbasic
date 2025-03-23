// low-level
force_space = " "+
opt_space = " "*
newline = [\n\r]+
EOF = !.

// generic values
integer = [0-9]+ { return parseInt(text()); }
name = [a-zA-Z_][a-zA-Z0-9_]* { return text(); }

// leaf values
constant_int = i:integer { return {type: 'integer', value: i}; }
constant_real = [0-9]+.[0-9]+ { return {type: 'real',  value: parseFloat(text())}; }
literal = "\"" chars:[^\"]* "\"" { return {type: 'literal', value: chars.join("")}; }
variable = v:name { return {type: 'variable', value: v}; }
value = constant_int / constant_real / literal / variable

// expression: composition of values
binary_op = "+" / "-" / "*" / "/" / "<=" / ">=" / "<" / ">" / "==" / "!=" / ">>"
expression = v:value opt_space op:binary_op opt_space e:expression { return {cmd: op, params: [v, e]}; }

// statement: composition of expression
statements
  = statement:statement EOF { return [statement]; }
  / statement:statement newline statements:statements { return [statement].concat(statements); }
  / statement:statement opt_space ":" opt_space statements:statements { return [statement].concat(statements); }
  / comment { return null; }

comment = ("REM" / "'") [^\n]* newline? { return null; }
statement = dim_statement / call_statement
dim_statement
  = "DIM" force_space memsize:integer force_space name:name dtype:dtype shape:shape { return {cmd: "DIM", params: {name, dtype, shape}}; }
  / "DIM" force_space name:name dtype:dtype shape:shape { return {cmd: "DIM", params: {name, dtype, shape}}; }
  / "DIM" force_space name:name dtype:dtype { return {cmd: "DIM", params: {name, dtype, shape: []}}; }
  / "DIM" force_space name:name shape:shape { return {cmd: "DIM", params: {name, dtype: "integer", shape}}; }
  / "DIM" force_space name:name { return {cmd: "DIM", params: {name, dtype: "integer", shape: []}}; }
shape = "(" dims:dims ")" { return dims; }
dims
  = integer:integer "," dims:dims { return [integer].concat(dims); }
  / integer:integer { return [integer]; }
  / "" { return []; }
dtype
  = "%" / "&" { return "int"; }
  / "!" / "#" { return "real"; }
  / "$" { return "string"; }
call_statement = name:name force_space params:params { return {cmd: name, params}; }
params
  = v:value opt_space "," opt_space params:params { return [v].concat(params); }
  / v:value { return [v]; }
  / "" { return []; }

// start
start = statements