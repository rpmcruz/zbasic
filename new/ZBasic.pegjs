start = expression

//////////////////////// low-level ////////////////////////

_ = " "*
newline = [\n\r]+
EOF = !.
integer = [0-9]+ { return parseInt(text()); }
real = [0-9]+ "." [0-9]+ { return parseFloat(text()); }
name = [a-zA-Z_][a-zA-Z0-9_]*
literal = "\"" [^\"]* "\""

//////////////////////// expressions ////////////////////////

binary_op = "+" / "-" / "*" / "/" / "<=" / ">=" / "<" / ">" / "==" / "!=" / ">>"
value = real / integer / name / literal
expression = e1:value _ op:binary_op _ e2:expression { return {op, e1, e2}; } / v:value

//////////////////////// statements ////////////////////////

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