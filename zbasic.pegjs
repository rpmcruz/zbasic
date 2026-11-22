{
let progressCallback = options.progressCallback || (() => {});
}

start = block:block EOF { return block; }

//////////////////////// statements ////////////////////////

// A sequence of statements, written as a repetition rather than as right
// recursion: one nested parse frame per statement put a 3,600-line listing
// within a few frames of the JS stack limit, so whether MacPThy parsed at all
// depended on how deep the call stack already was when the parser was entered.
block = stmts:blockStmt* last:(_ s:statementWithProgress _ { return s; })
  { return [...stmts, last].filter(s => s); }
blockStmt
  // A label written as "Name" may be followed by a statement on the same line
  // with only a space between them, so it needs no separator.
  = _ &'"' stmt:statementWithProgress __ { return stmt; }
  / _ stmt:statementWithProgress _ separator { return stmt; }
separator = ":" / newline / comment newline

statementWithProgress = s:statement
  { progressCallback(location().start.line, s); return s; }
statement = comment { return null; }
  / inlineAsm
  / declareStmt / defFn / definition / defCmd / typeBlock / dimVar / commonStmt / defTypeStmt / assignVar
  / userProcCall / userFuncCall / userLongFuncDef / userLocalFuncDef / printStmt / pokeStmt / gotoStmt
  / eventLabel / sysFuncCall / dataStmt
  / includeStmt
  / forLoop / whileLoop / doLoop
  / blockIfCond / ifCond / longIfConf / selectStmt
  / onStmt / endStmt
  / label
  / exprStmt
  / nop

inlineAsm = "`" code:(!newline .)*
  { return {type: "inlineAsm", code: code.map(c => c[1]).join("")}; }

exprStmt = e:expression { return {type: "exprStmt", expr: e}; }

gotoStmt = cmd:branchCmd ![a-zA-Z0-9_%&!$] __ target:labelRef
  { return {type: "sysFuncCall", cmd, keyword: null, args: [target]}; }
// A branch target. ZBasic label names are free text, and the spelling at the
// branch need not match the spelling at the definition — canonLabel() in the
// interpreter folds away case, blanks, quotes and punctuation. CDraw relies on
// that throughout: it defines `Format_Wnd:` and branches to `gosub Format Wnd"`,
// lists `Canned_Functions:` as `Canned Functions`, reaches `Average:_f/x:` as
// `Average_f/x`, and writes its File menu as `GOTO New","Open","X",…`. So the
// target is simply everything up to the end of the statement. A colon ends the
// statement unless it belongs to a composite label (`Average:_f/x`), and ELSE
// ends it because a one-line IF continues there.
// A quoted target is taken whole — those routinely contain a colon
// (Supermarket's `GOSUB "Action:Menu"`, PG:PRO's `GOSUB "PG:WUpd"`).
labelRef = s:string { return {type: "lineRef", label: s.value}; }
  / &[a-zA-Z_] chars:labelChar+
  { return {type: "lineRef", label: chars.join("").trim()}; }
  / expression
labelChar = !("," / "'" / newline / (__ "ELSE"i ![a-zA-Z0-9_%&!#$]))
            c:(":" &"_" { return ":"; } / [^:,'\r\n]) { return c; }
// Event handlers are conventionally named after the event they serve, so
// "Mouse:" / "Menu:" / "Dialog:" appear as labels. None of these commands is
// meaningful bare (they need ON/OFF or arguments), so a name directly followed
// by ":" is unambiguously a label and must not be parsed as a statement.
eventLabel = name:("MOUSE"i / "MENU"i / "DIALOG"i / "TIMER"i / "EVENT"i) _ &":"
  { return {type: "label", label: name.toLowerCase()}; }
sysFuncCall = cmd:sysCmds ![a-zA-Z0-9_%&!$] chan:("#" expression)? keyword:(__ sysKeyword)? _ args:sysArgs trailer:(_ sysKeyword _ sysArgs)*
  { return {type: "sysFuncCall", cmd: cmd.toUpperCase(), chan: chan ? chan[1] : null,
    keyword: keyword ? keyword[1] : null, args,
    trailer: trailer.map(t => ({keyword: t[1], args: t[3]})) }; }
// The modifier word in a two-word statement (WINDOW OUTPUT, BOX FILL,
// EDIT FIELD, GET VOLUME INFO, ...). This has to be a fixed vocabulary rather
// than "any identifier": `sysArg` is allowed to be empty (so that `PEN ,,,,3`
// works), which means `args:sysArgs` can never fail and PEG therefore never
// backtracks a wrongly-taken keyword. Matching any identifier silently ate the
// first argument of a great many statements —
//   BUTTON Level+2,2                     -> keyword LEVEL, id = +2
//   CURSOR NewCsr                        -> keyword NEWCSR, no cursor argument
//   PEN ,,,,DPatternPlus                 -> keyword DPATTERNPLUS, no pattern
//   TEXT TxFont,TxSize,TxFace,TxMode     -> keyword TXMODE, mode dropped
//   SCROLL BUTTON b,0,0,NumLines+1,...   -> keyword NUMLINES, args truncated
// An unknown two-word form now fails to parse loudly instead of being
// mis-executed, which is the safer direction.
sysKeyword = kw:sysKeywordWord ![a-zA-Z0-9_%&!$,/*(=<>^.]
  { return kw.toUpperCase(); }
sysKeywordWord
  = $("OUTPUT"i / "PICTURE"i / "PRESET"i / "VOLUME"i / "WINDOW"i / "BUTTON"i
    / "DEVICE"i / "SCROLL"i / "ARROW"i / "FIELD"i / "GOSUB"i / "INDEX"i
    / "LPRINT"i / "PSTR"i / "PSET"i / "PLOT"i / "FILL"i / "FILE"i / "GOTO"i / "INFO"i
    / "MENU"i / "MOUSE"i / "TEXT"i / "WORD"i / "CLOSE"i / "EVENT"i
    / "RETURN"i / "OFF"i / "REF"i / "ON"i / "TO"i / "XA"i)
sysCmds = "GOTO"i / "GOSUB"i / "RETURN"i
  / "RESOURCES"i / "COMPILE"i / "WIDTH"i / "GLOBALS"i
  / "COORDINATE"i / "DIALOG"i / "MENU"i / "MOUSE"i / "CURSOR"i
  / "PEN"i / "GET"i / "PUT"i / "PLOT"i / "BOX"i / "TEXT"i
  / "COLOR"i / "CIRCLE"i / "CLS"i / "WINDOW"i / "SCROLL"i / "DELAY"i
  / "CLEAR LOCAL"i / "CLEAR"i / "BUTTON"i / "SOUND"i / "WAVE"i / "SEGMENT"i
  / "DEFSTR"i / "READ"i / "RESTORE"i / "INPUT"i / "OPEN"i / "CLOSE"i
  / "RANDOM"i / "SWAP"i / "BREAK"i / "APPLE"i / "ROUTE"i / "RATIO"i
  / "BEEP"i / "HOME"i / "INVERSE"i / "NORMAL"i / "FLASH"i / "VTAB"i / "HTAB"i
  / "LOCATE"i
  / "POKE"i / "RESUME"i / "POP"i / "TRACE"i / "NOTRACE"i / "SPEED"i
  / "LPRINT"i / "LLIST"i / "STOP"i / "WAIT"i / "HPLOT"i
  / "HCOLOR"i / "HGRAPH"i / "SCRN"i / "WRITE"i / "%" / "&" / "EDIT"i
  / "SETSELECT"i / "INC"i / "DEC"i / "KILL"i / "PT"i
  / "BLOCKMOVE"i / "LIBRARY"i / "TOOLBOX"i / "INLINE"i / "CHAIN"i
  / "TALK"i / "LINE"i / "PICTURE"i
  / "MINWINDOW"i / "MAXWINDOW"i / "FLUSHEVENTS"i / "SETZOOM"i / "PUSH"i
  / "TIMER"i / "EVENT"i / "LOCAL"i
sysArgs = first:sysArg rest:(_ "," _ sysArg)* {
  return [first, ...rest.map(r => r[3])];
}
sysArg = numFromTo / exprFromTo / exprRect / lineRelPoint / exprPoint / channelNum
       / !sysKeyword e:expression { return e; }
       / nop
lineRelPoint = "-" _ to:exprPoint { return {type: "lineRel", to}; }
channelNum = "#" n:expression { return {type: "channel", n}; }
exprRect = from:exprPoint _ "-" _ to:exprPoint
  { return {from: [from.x, from.y], to: [to.x, to.y]}; }
numFromTo = "(" fromX:integer "," fromY:integer ")-(" toX:integer "," toY:integer ")"
  { return {from: [fromX, fromY], to: [toX, toY] }; }
// x1,y1 TO x2,y2 [TO x3,y3 …]
// Group indices: 0:__  1:"TO"  2:__  3:x  4:_  5:","  6:_  7:y
exprFromTo = fromX:expression _ "," _ fromY:expression segs:(__ "TO"i __ expression _ "," _ expression)+
  { const points = [[fromX, fromY], ...segs.map(s => [s[3], s[7]])];
    return {type: "polyline", from: points[0], to: points[points.length-1], points}; }
exprPoint = "(" _ x:expression _ "," _ y:expression _ ")"
  { return {x, y}; }
nop = _ { return null; }

pokeStmt = "POKE"i __ type:("LONG"i / "WORD"i / "BYTE"i) __ addr:expression _ "," _ val:expression
  { return {type: "sysFuncCall", cmd: "POKE " + type.toUpperCase(), args: [addr, val]}; }
printStmt = "PRINT"i mode:printMode _ list:printList?
  { return {type: "print", mode, items: list ? list.items : [],
            seps: list ? list.seps : [], trailing: list ? list.trailing : null}; }
printMode = _ mode:("%" / "@") _ coord:exprPoint _ ";"?
  { return {type: mode, coord}; }
  / _ "#" _ chan:expression _ ","?
  { return {type: "#", chan}; }
  / "" { return {type: "plain"}; }
printList = head:printItem tail:(printSep? printItem)* trail:printSep?
  { return {items: [head, ...tail.map(t => t[1])],
            seps: tail.map(t => t[0]), trailing: trail}; }
printItem = "USING"i _ format:expression _ ";" _ expr:expression
  { return {type: "using", format, expr}; }
  / expression
printSep = _ sep:(";" / ",") _ { return sep; }

label = '"' chars:char* '"'
  { return {type: "label", label: chars.join("")}; }
  / a:labelIdent ":" b:identifier "/" c:identifier _ ":"
  { return {type: "label", label: a + ":" + b + "/" + c}; }
  / a:labelIdent ":" b:identifier _ ":"
  { return {type: "label", label: a + ":" + b}; }
  / first:labelIdent rest:(__ labelIdent)+ _ ":"
  { return {type: "label", label: first + rest.map(r => "_" + r[1]).join("")}; }
  / name:labelIdent _ &":"
  { return {type: "label", label: name}; }
labelIdent = !(("END"i / "NEXT"i / "WEND"i / "UNTIL"i / "XELSE"i / "ELSE"i / "THEN"i / "CASE"i / "FOR"i / "IF"i / "LONG"i / "WHILE"i / "DO"i / "LOCAL"i / "DEF"i / "DIM"i / "ON"i) ![a-zA-Z0-9_%&!#$]) name:identifier { return name; }

declareStmt = "DECLARE"i __ ("SUB"i / "FUNCTION"i) __ identifier _ ("(" _ declareArgs? _ ")")? _
  { return null; }
declareArgs = head:declareArg tail:(_ "," _ declareArg)*
  { return [head, ...tail.map(t => t[3])]; }
declareArg = name:identifier _ ("AS"i __ identifier)? { return name; }

funcParams = head:funcParam tail:(_ "," _ funcParam)*
  { return [head, ...tail.map(t => t[3])]; }
funcParam = ref:"@"? name:identifier size:(";" _ integer)?
  { return {name, ref: !!ref, size: size ? size[2] : null}; }

dimVar = "DIM"i __ "END"i __ "RECORD"i _ "." name:identifier
  { return {type: "dimEndRecord", name}; }
  / "DIM"i __ "END"i __ "RECORD"i __ name:identifier
  { return {type: "dimEndRecord", name}; }
  / "DIM"i __ "RECORD"i __ name:identifier
  { return {type: "dimRecord", name}; }
  / "DIM"i __ args:dimArgs
  { return {type: "dim", args}; }
dimArgs = head:dimPart tail:(_ "," _ dimPart)*
  { return [head, ...tail.map(t => t[3])]; }
dimPart = prefix:number? _ name:identifier dotType:("." (identifier / integer))? dims:("(" exprArgs ")")? size:(_ ";" _ number)? typeDecl:(__ "AS"i __ identifier)?
  { return { name, prefix, dotType: dotType ? dotType[1] : null, dims: dims ? dims[1] : [], size: size ? size[3] : null, typeName: typeDecl ? typeDecl[3] : null }; }

typeBlock = "TYPE"i __ name:identifier _ newline fields:typeField* _ "END"i __ "TYPE"i _
  { return null; }
typeField = _ name:identifier __ "AS"i __ typeName:identifier _ (newline / comment newline)
  { return {name, typeName}; }

commonStmt = "COMMON"i __ head:commonVar tail:(_ "," _ commonVar)*
  { return null; }
commonVar = name:identifier _ ("(" _ ")")?

defTypeStmt = ("DEFINT"i / "DEFDBL"i / "DEFSNG"i) __ head:defTypeRange tail:(_ "," _ defTypeRange)*
  { return null; }
defTypeRange = [A-Za-z] (_ "-" _ [A-Za-z])? { return text(); }

userProcCall = "CALL"i __ name:identifier _ args:(_ "(" _ exprArgs _ ")")?
  { return {type: "procedureCall", name, args: args ? args[3] : []}; }
userFuncCall = "FN"i __ name:identifier args:(_ "(" _ exprArgs _ ")")?
  { return {type: "userFuncCall", name, args: args ? args[3] : []}; }

defFn = "DEF"i __ "FN"i __ name:identifier _ args:("(" _ funcParams _ ")")? _ "=" _ value:expression
  { return {type: "defFn", name, args: args ? args[2] : [], value}; }
  / "DEF"i __ "FN"i __ name:identifier _ args:("(" _ funcParams _ ")")? _ "USING"i __ globalRef:expression
  { return {type: "defFn", name, args: args ? args[2] : [], using: globalRef}; }
definition = "DEF"i __ name:identifier __ "=" __ value:expression
  { return {type: "def", name, value}; }
defCmd = "DEF"i __ keyword:identifier _ "=" _ arg:expression
  { return {type: "defCmd", keyword, arg}; }
  / "DEF"i __ keyword:identifier _ "(" _ args:exprOptArgs? _ ")"
  { return {type: "defCmd", keyword, args: args || []}; }
  / "DEF"i __ keyword:identifier arg:(_ expression)?
  { return {type: "defCmd", keyword, arg: arg ? arg[1] : null}; }
assignVar = name:identifier fields:("." identifier)* field:(";" _ (integer / variable))? _ idx:("(" _ exprArgs _ ")")? _ "=" _ value:expression
  { return {type: "assign", name, fields: fields.map(f => f[1]), field: field ? field[2] : null, idx: idx ? idx[2] : null, value}; }

// The body is optional: "LONG FN F(A,B) : END FN = A+B" is a legal one-liner.
userLongFuncDef
  = "LONG FN"i __ name:identifier args:(_ "(" _ funcParams _ ")")? _ separator body:(!"END FN"i b:block {return b;})? _ "END FN"i ret:(_ "=" _ expression)?
    { return {type: "function", name, args: args ? (args[3] || []) : [], body: body || [], ret: ret ? ret[3] : null}; }
userLocalFuncDef
  = "LOCAL FN"i __ name:identifier args:(_ "(" _ funcParams _ ")")? _ separator body:(!"END FN"i b:block {return b;})? _ "END FN"i ret:(_ "=" _ expression)?
    { return {type: "localFunction", name, args: args ? (args[3] || []) : [], body: body || [], ret: ret ? ret[3] : null}; }

blockIfCond = "IF"i _ condition:multiLineCondition _ "THEN"i _ separator !"END IF"i body:block maybeElse:(_ "ELSE"i _ separator block)? _ "END IF"i
  { return {type: "if", condition, body, else: maybeElse ? maybeElse[4] : null}; }
ifCond = "IF"i _ condition:multiLineCondition _ ("THEN"i _)? action:singleLineBody maybeElse:(_ "ELSE"i __ singleLineBody)?
  { return {type: "if", condition, body: action, else: maybeElse ? maybeElse[3] : null}; }
multiLineCondition = head:expression tail:(newline white+ !("IF"i ![a-zA-Z0-9_%&!$]) expression)*
  { return tail.reduce((acc, t) => ({type: "binop", op: "AND", left: acc, right: t[3]}), head); }
singleLineBody = head:statement tail:(_ ":" _ !"ELSE"i statement)*
  { return [head, ...tail.map(t => t[4])].filter(s => s !== null); }
longIfConf = "LONG IF"i __ condition:expression _ separator body:block maybeElse:(_ "XELSE"i _ block)?  _ "END IF"i
  { return {type: "if", condition, body, else: maybeElse ? maybeElse[3] : null}; }

// The STEP clause was matched but never captured, so every counted loop in
// every program ran with a step of 1. Grglflx redraws its curve with
// `FOR Xtmp=Xmin TO X-DeltaX STEP DeltaX`, which then walked over the array
// slots between plotted points and drew the curve as a picket fence.
forLoop = "FOR"i __ variable:identifier _ "=" _ start:expression __ "TO"i __ end:expression step:(__ "STEP"i __ e:expression { return e; })? _ separator body:block _ "NEXT"i (__ identifier)?
  { return {type: "for", variable, start, end, step, body}; }
whileLoop = "WHILE"i __ condition:expression _ separator body:block _ "WEND"i
  { return {type: "while", condition, body}; }
doLoop = "DO"i _ separator body:block _ "UNTIL"i __ condition:expression
  { return {type: "do_while", condition, body}; }
// ON <event> GOSUB handler installs a trap; ON <expr> GOSUB a,b,c is the
// computed branch. Only ON TIMER carries an argument. ON ERROR GOSUB 65535
// turns disk-error trapping over to the program and ON ERROR RETURN gives it
// back to ZBasic (manual, "Disk Errors").
onStmt = "ON"i __ "TIMER"i _ "(" _ interval:expression _ ")" __ cmd:branchCmd _ target:labelRef
  { return {type: "onEvent", event: "TIMER", cmd, handler: target, interval}; }
  / "ON"i __ "ERROR"i __ "RETURN"i ![a-zA-Z0-9_%&!#$]
  { return {type: "onEvent", event: "ERROR", cmd: "RETURN", handler: null}; }
  / "ON"i __ event:trapEvent ![a-zA-Z0-9_%&!#$] __ cmd:branchCmd _ target:labelRef
  { return {type: "onEvent", event, cmd, handler: target}; }
  / "ON"i __ expr:expression __ "RETURN"i ![a-zA-Z0-9_%&!#$]
  { return {type: "on", expr, cmd: "RETURN", targets: []}; }
  / "ON"i __ expr:expression __ cmd:branchCmd _ targets:gotoTargets
  { return {type: "on", expr, cmd, targets}; }
trapEvent = e:("MENU"i / "DIALOG"i / "MOUSE"i / "STOP"i / "TIMER"i / "EVENT"i / "EDIT"i / "BREAK"i / "ERROR"i)
  { return e.toUpperCase(); }
branchCmd = c:("GOSUB"i / "GOTO"i) { return c.toUpperCase(); }
gotoTargets = head:labelRef tail:(_ "," _ labelRef)*
  { return [head, ...tail.map(t => t[3])]; }
endStmt = "END"i __ "GLOBALS"i { return {type: "endGlobals"}; }
  / "END"i !(__ "FN"i) !(__ "IF"i) !(__ "GLOBALS"i) !(__ "SELECT"i) { return {type: "end"}; }
dataStmt = "DATA"i __ items:dataArgs
  { return {type: "data", items}; }
dataArgs = head:dataItem tail:(_ "," _ dataItem)* last:(_ ",")?
  { return [head, ...tail.map(t => t[3]), ...(last ? [{type:'literal',value:''}] : [])]; }
dataItem = string / float / integer / dataStr
dataStr = chars:(!("," / newline / comment) .)+ { return {type: "literal", value: text().trim()}; }

includeStmt = "INCLUDE"i __ "FILE"i __ n:expression
  { return {type: "includeFile", n}; }
  / "INCLUDE"i __ filename:string
  { const body = options.parseFile ? options.parseFile(filename.value) : [];
    return {type: "include", filename: filename.value, body}; }

selectStmt = "SELECT"i __ "CASE"i __ "CASE"i __ expr:expression _ separator cases:selectCase* _ "END SELECT"i
  { return {type: "select", expr, cases}; }
  / "SELECT"i __ ("CASE"i __)? expr:expression _ separator cases:selectCase* _ "END SELECT"i
  { return {type: "select", expr, cases}; }
selectCase = (_ separator)* _ "CASE"i _ "ELSE"i _ separator body:block
  { return {type: "case", values: "else", body}; }
  / (_ separator)* _ "CASE"i _ values:caseValues _ separator body:block
  { return {type: "case", values, body}; }
caseValues = head:caseValue tail:(_ "," _ caseValue)*
  { return [head, ...tail.map(t => t[3])]; }
caseValue = from:expression __ "TO"i __ to:expression
  { return {type: "range", from, to}; }
  / ("IS"i __)? op:compOp _ expr:expression
  { return {type: "relational", op, expr}; }
  / expression

//////////////////////// expressions ////////////////////////

// All of these are LEFT-associative. Writing them right-recursively
// (`left:x op right:sameRule`) is the natural-looking PEG shape but it makes
// them right-associative, so `a - b + c` becomes `a - (b + c)` and `a / b / c`
// becomes `a / (b / c)`. Supermarket's
//   VDeviation = gCheckout.Cv%(t) - gShopper.SLoc.v%(Shp) + _COffset
// then came out 52 too low and drove every shopper into the top wall.
// The fold below is the standard left-associative PEG idiom.
// `^` stays right-associative, which is correct: 2^3^2 = 2^(3^2).
expression = logicalOr
logicalOr
  = head:logicalAnd tail:(_ op:(("OR"i / "XOR"i) ![a-zA-Z0-9_%&!#$]) _ right:logicalAnd { return {operator: op[0].toUpperCase(), right}; })*
  { return tail.reduce((left, t) => ({type: "binary", operator: t.operator, left, right: t.right}), head); }
logicalAnd
  = head:not tail:(_ "AND"i ![a-zA-Z0-9_%&!#$] _ right:not { return right; })*
  { return tail.reduce((left, right) => ({type: "binary", operator: "AND", left, right}), head); }
not = "NOT"i _ expression:not
  { return {type: "unary", operator: "NOT", expression}; }
  / comparison
compOp = "=" / "<>" / "<=" / ">=" / "<" / ">"
comparison
  = head:concat tail:(_ operator:compOp _ right:concat { return {operator, right}; })*
  { return tail.reduce((left, t) => ({type: "binary", operator: t.operator, left, right: t.right}), head); }
concat
  = head:shift tail:(_ "&" _ right:shift { return right; })*
  { return tail.reduce((left, right) => ({type: "binary", operator: "&", left, right}), head); }
shift
  = head:additive tail:(_ op:("<<" / ">>") _ right:additive { return {operator: op, right}; })*
  { return tail.reduce((left, t) => ({type: "binary", operator: t.operator, left, right: t.right}), head); }
additive
  = head:multiplicative tail:(_ operator:("+" / "-") _ right:multiplicative { return {operator, right}; })*
  { return tail.reduce((left, t) => ({type: "binary", operator: t.operator, left, right: t.right}), head); }
multiplicative
  = head:power tail:(_ operator:mulOp _ right:power { return {operator, right}; })*
  { return tail.reduce((left, t) => ({type: "binary", operator: t.operator, left, right: t.right}), head); }
mulOp = "MOD"i ![a-zA-Z0-9_%&!#$] { return "MOD"; } / "*" / "/" / "\\"
power = base:unary _ "^" _ exp:power
  { return {type: "binary", operator: "^", left: base, right: exp}; }
  / unary
unary
  = "-" _ expression:unary
  { return { type: "unary", operator: "-", expression}; }
  / "+" _ expression:unary
  { return { type: "unary", operator: "+", expression}; }
  / "&H"i digits:[0-9a-fA-F]+ ![a-zA-Z_]
  { return {type: "constant", value: parseInt(digits.join(""), 16)}; }
  / "&O"i digits:[0-7]+ ![a-zA-Z_]
  { return {type: "constant", value: parseInt(digits.join(""), 8)}; }
  / "&X"i digits:[01]+ ![a-zA-Z_]
  { return {type: "constant", value: parseInt(digits.join(""), 2)}; }
  / "&" digits:([0-9a-fA-F]+) ![a-zA-Z_]
  { return {type: "constant", value: parseInt(digits.join(""), 16)}; }
  / "&" _ expression:unary
  { return { type: "unary", operator: "&", expression}; }
  / "@" _ expression:unary
  { return { type: "unary", operator: "@", expression}; }
  / "%" _ expression:unary
  { return { type: "unary", operator: "%", expression}; }
  / "#" _ expression:unary
  { return { type: "unary", operator: "#", expression}; }
  / primary
primary
  = userFuncCall / peekCall / lineLiteral / chainAccess / callable / namedConst / string / hexLiteral / float / integer / boolean / variable
lineLiteral = "LINE"i _ s:string
  { return {type: "lineRef", label: s.value}; }
  // Parentheses are marked so the expression evaluator can tell which
  // operators belong to the same "level". ZBasic evaluates a level as integer
  // unless that level itself contains a real marker, and it examines only the
  // outermost portion: in X*(2*(4.03+4))*5 the inner level is real but the
  // whole expression still comes back an integer (manual, "Parentheses in
  // Optimized Integer Expression Evaluation").
  / "(" _ expr:expression _ ")" { return Object.assign({}, expr, {paren: true}); }
  / "[" _ expr:expression _ "]" { return {type: "deref", expr}; }
  / "{" _ expr:expression _ "}" { return {type: "compileConst", expr}; }
chainAccess = name:identifier fields:("." identifier)+ args:(_ "(" _ exprOptArgs? _ ")")?
  { return {type: "chainAccess", name, fields: fields.map(f => f[1]), args: args ? (args[3] || []) : null}; }
hexLiteral = "&H" digits:[0-9a-fA-F]+ { return {type: "constant", value: parseInt(digits.join(""), 16)}; }
  / "&O" digits:[0-7]+ { return {type: "constant", value: parseInt(digits.join(""), 8)}; }

namedConst = "_" s:string
  { return {type: "namedConst", name: s.value}; }

// ambiguous: can be array or built-in function call
// e.g., A(0) can be access index=0 of A or call built-in function A
callable = name:identifier _ "(" _ args:exprOptArgs? _ ")"
  { return {type: "callable", name, args: args || []}; }
peekCall = "PEEK"i __ type:("WORD"i / "LONG"i / "BYTE"i) _ "(" _ args:exprArgs? _ ")"
  { return {type: "callable", name: "PEEK " + type.toUpperCase(), args: args || []}; }
  / "PEEK"i _ "(" _ args:exprArgs? _ ")"
  { return {type: "callable", name: "PEEK", args: args || []}; }
  / "USR"i __ n:integer _ "(" _ args:exprArgs? _ ")"
  { return {type: "callable", name: "USR", args: [n, ...(args || [])]}; }
  / "USR"i __ name:identifier _ "(" _ args:exprArgs? _ ")"
  { return {type: "callable", name: "USR_" + name, args: args || []}; }

exprArgs = head:expression tail:(_ "," _ expression)*
  { return [head, ...tail.map(t => t[3])]; }
exprOptArgs = head:(expression / nop) tail:(_ "," _ (expression / nop))*
  { return [head, ...tail.map(t => t[3])]; }

//////////////////////// tokens ////////////////////////

// ZBasic ignores blanks inside a name, so a tab left in the middle of one by the
// editor is not an error: Grglflx's Font handler reads
//   FontName$ = FN Chk1Item$(FontMHndl&, Item<TAB>ID)
// which is simply the variable ItemID. The tab only counts as part of the name
// when more of the name follows it, so it can still separate two operands.
identifier = [a-zA-Z_] ([a-zA-Z0-9_] / "\t" &[a-zA-Z0-9_])* ([%&!#$])?
  { return text().replace(/\t/g, "").toLowerCase(); }
number = sign:"-"? digits:[0-9]+ { return parseInt((sign || "") + digits.join(""), 10); }
string = '"' chars:char* '"' { return {type: "literal", value: chars.join("")}; }
  / '"' chars:char* &(newline / EOF) { return {type: "literal", value: chars.join("")}; }
integer = value:number suffix:[&!%#]? { return {type: "constant", value, real: (suffix === "!" || suffix === "#") || undefined}; }
// ZBasic has no boolean type: TRUE is -1 and FALSE is 0, the same values the
// _true / _false equates carry. Yielding JS booleans made them non-numeric, so
// e.g. CDraw's ShowFlag(I)=True stored `true` and every later
// `IF ShowFlag(Function)` read it back as 0 — the curves were never drawn.
boolean = "True"i ![a-zA-Z0-9_%&!#$] { return {type: "constant", value: -1}; }
  / "False"i ![a-zA-Z0-9_%&!#$] { return {type: "constant", value: 0}; }
// `real: true` records that the literal was *written* with a decimal point.
// "32000." is integer-valued but still forces the level to floating point.
float = int:[0-9]+ "." frac:[0-9]* [&!%#]? { return {type: "constant", value: parseFloat(int.join("") + "." + frac.join("")), real: true}; }
  / "." frac:[0-9]+ [&!%#]? { return {type: "constant", value: parseFloat("." + frac.join("")), real: true}; }
variable = !(("ELSE"i / "THEN"i / "AND"i / "OR"i / "NOT"i / "RETURN"i / "GOSUB"i / "GOTO"i / "END"i / "NEXT"i / "WEND"i / "UNTIL"i / "XELSE"i / "FOR"i / "WHILE"i / "DO"i / "CALL"i / "DEF"i / "DIM"i / "REM"i / "FN"i / "IF"i / "DATA"i / "ON"i / "STEP"i / "TO"i / "USING"i / "SELECT"i / "CASE"i / "LOCAL"i) ![a-zA-Z0-9_%&!#$]) name:identifier { return {type: "variable", name}; }
char = '\\' c:['"\\'] { return c; }
  / !'"' !newline c:. { return text(); }

newline = "\r\n" / "\n" / "\r"
comment = ("REM"i ![a-zA-Z] / "'") (!newline .)*
_  = white*  // optional
__ = white+  // mandatory
white = [ \t]+
EOF = !.
