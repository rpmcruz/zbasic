start = statements
statements
  = statement:statement EOF { console.log('EOF'); return [statement]; }
  / statement:statement newline statements:statements { console.log("new line, statement: " + (typeof statement) + " statements: " + (typeof statement)); return [statement].concat(statements); }
  / statement:statement optional_whitespace ":" optional_whitespace statements:statements { console.log("colon, statement: " + (typeof statement) + " statements: " + (typeof statement)); return [statement].concat(statements); }

statement
    = s:dim_statement { console.log("statement dim"); return s; }
    / s:call_statement { console.log("statement call"); return s; }

dim_statement
  = "DIM" mandatory_whitespace name:name dtype:dtype shape:shape { console.log("return DIM dict with name " + name); return {cmd: "DIM", parameters: {name, dtype, shape}}; }

call_statement = name:name mandatory_whitespace parameters:parameters { console.log("return call dict"); return {cmd: name, parameters}; }

shape = "(" dims:dims ")" { return dims; }
dims
  = integer:integer "," dims:dims { return [integer].concat(dims); }
  / integer:integer { return [integer]; }
  / "" { return []; }

dtype
  = "%" / "&" { return "int"; }
  / "!" / "#" { return "real"; }
  / "$" { return "string"; }

parameters
  = parameter:parameter optional_whitespace "," optional_whitespace parameters:parameters { return [parameter].concat(parameters); }
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
