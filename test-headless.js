#!/usr/bin/env node
// Run a program from progs/programs.json headlessly, with index.html's own
// interpreter, and report what it did.
//
//   node test-headless.js <Program> [seconds] [script.js]
//   node test-headless.js --all [seconds]          smoke-test every program
//   node test-headless.js path/to/file.bas [seconds] runs one source file
//
// The interpreter runs in a worker thread against a stub DOM (no pixels are
// drawn; getImageData reads back white). Every statement it executes writes its
// id into shared memory, so when the worker stops making progress — a
// synchronous infinite loop that would freeze a browser tab — the main thread
// can name the statement it is stuck in. At the end it prints the open windows,
// menus and controls, and the statements that ran most often.
//
// The optional script is the body of an async function receiving `h` (the
// interpreter's state and a few input hooks — see the end of the worker),
// `sleep(ms)` and `log(text)`, and runs alongside the program, e.g.
//   await sleep(3000); h.controlStore['1:1'].el.listeners.keydown[0]({key: '2', preventDefault() {}});
// h.menu(menu, item) picks a menu item, and h.modal() is the alert or file
// dialog on top, if any: its text, click(label), pick(name) and type(text).
// Documents last for the run (h.disk() lists them).
const {Worker, isMainThread, workerData, parentPort} = require("worker_threads");
const fs = require("fs"), path = require("path"), vm = require("vm");
const ROOT = __dirname;

if (isMainThread) {
  const args = process.argv.slice(2);
  if (!args.length) { console.error("usage: node test-headless.js <Program>|--all [seconds] [script.js]"); process.exit(1); }
  const programs = JSON.parse(fs.readFileSync(path.join(ROOT, "progs/programs.json"), "utf8")).map(p => p.name);
  const names = args[0] === "--all" ? programs : [fs.existsSync(args[0]) ? path.resolve(args[0]) : args[0]];
  const secs = Number(args[1]) || 8;
  (async () => {
    let failed = false;
    for (const name of names) failed = !(await runOne(name, secs, args[2], names.length > 1)) || failed;
    process.exit(failed ? 1 : 0);
  })();
} else {
  worker();
}

function runOne(name, secs, script, quiet) {
  return new Promise(resolve => {
    console.log(`=== ${name}`);
    const shared = new Int32Array(new SharedArrayBuffer(8));
    const summaries = [];
    let ok = true, ended = false;
    const w = new Worker(__filename, {workerData: {name, shared, script}});
    w.on("message", m => {
      if (m.stmt) summaries[m.stmt.id] = m.stmt.text;
      if (m.ended) ended = true;   // the program finished: no statements is no hang
      if (m.log) {
        if (/^(ERROR|WARN)/.test(m.log) && !/skipped \d+ unparsable/.test(m.log)) ok = false;
        if (!quiet || /^(ERROR|WARN|\[)/.test(m.log)) console.log(m.log);
      }
      if (m.done) { clearInterval(iv); w.terminate(); resolve(ok); }
    });
    w.on("error", e => { console.log("WORKER ERROR", e); ok = false; });
    let last = -1, still = 0;
    const t0 = Date.now();
    const iv = setInterval(() => {
      const id = Atomics.load(shared, 0), count = Atomics.load(shared, 1);
      still = count === last && count > 0 && !ended ? still + 1 : 0;
      last = count;
      if (still >= 6) {
        console.log(`*** HUNG for ${still / 2}s in statement: ${summaries[id] ?? "?"}`);
        clearInterval(iv); w.terminate(); resolve(false);
      } else if ((Date.now() - t0) / 1000 > secs) {
        console.log(`[${secs}s, ${count} statements]`);
        w.postMessage({report: true});
      }
    }, 500);
  });
}

function worker() {
  const {name, shared, script} = workerData;
  const log = s => parentPort.postMessage({log: s});

  // ── stub DOM ──
  class ClassList {
    constructor() { this.s = new Set(); }
    add(...c) { c.forEach(x => this.s.add(x)); }
    remove(...c) { c.forEach(x => this.s.delete(x)); }
    toggle(c, f) { const on = f ?? !this.s.has(c); on ? this.s.add(c) : this.s.delete(c); return on; }
    contains(c) { return this.s.has(c); }
  }
  const makeCtx = canvas => {
    const ctx = {
      canvas, font: "12px x", fillStyle: "#000", strokeStyle: "#000", lineWidth: 1,
      measureText: t => ({width: String(t).length * (parseFloat(ctx.font) || 12) * 0.6}),
      getImageData: (x, y, w, h) => {
        w = Math.max(1, w | 0); h = Math.max(1, h | 0);
        return {width: w, height: h, data: new Uint8ClampedArray(w * h * 4).fill(255)};
      },
      createImageData: (w, h) => ({width: w, height: h, data: new Uint8ClampedArray(w * h * 4)}),
    };
    for (const f of ["fillRect", "strokeRect", "clearRect", "putImageData", "save", "restore", "beginPath",
      "closePath", "moveTo", "lineTo", "stroke", "fill", "arc", "ellipse", "rect", "roundRect", "clip",
      "scale", "setTransform", "fillText", "drawImage", "translate"]) ctx[f] = () => {};
    return ctx;
  };
  class El {
    constructor(tag) {
      Object.assign(this, {tagName: String(tag).toUpperCase(), children: [], style: {setProperty() {}},
        classList: new ClassList(), dataset: {}, value: "", textContent: "", disabled: false, hidden: false,
        clientWidth: 1000, clientHeight: 700, listeners: {}, width: 300, height: 150});
    }
    set className(v) { this.classList = new ClassList(); String(v).split(/\s+/).filter(Boolean).forEach(c => this.classList.add(c)); }
    get className() { return [...this.classList.s].join(" "); }
    set innerHTML(v) { this.children = []; }
    get innerHTML() { return ""; }
    appendChild(c) { this.children.push(c); c.parentNode = this; return c; }
    append(...cs) { cs.forEach(c => this.appendChild(c)); }
    remove() { if (this.parentNode) this.parentNode.children = this.parentNode.children.filter(x => x !== this); }
    get firstChild() { return this.children[0] ?? null; }
    addEventListener(t, f) { (this.listeners[t] ??= []).push(f); }
    removeEventListener() {}
    querySelector() { return null; }
    querySelectorAll() { return []; }
    closest() { return null; }
    getBoundingClientRect() { return {left: 0, top: 0, width: 1000, height: 700}; }
    focus() {} blur() {} click() {} select() {} setSelectionRange() {}
    getContext() { return this._ctx ??= makeCtx(this); }
  }
  const els = {};
  const document = {
    title: "", body: new El("body"), activeElement: null,
    getElementById: id => els[id] ??= new El("div"),
    createElement: t => new El(t),
    querySelector: () => null, querySelectorAll: () => [],
    addEventListener() {}, removeEventListener() {},
  };
  const fmt = a => a.map(x => x && x.stack ? x.stack.split("\n").slice(0, 4).join(" | ")
    : typeof x === "object" ? JSON.stringify(x)?.slice(0, 300) : String(x)).join(" ");
  const context = vm.createContext({
    document,
    console: {log: (...a) => log(fmt(a)), warn: (...a) => log("WARN " + fmt(a)), error: (...a) => log("ERROR " + fmt(a))},
    window: {addEventListener() {}, devicePixelRatio: 1, prompt: m => (log(`[prompt] ${m}`), ""), alert: m => log(`[alert] ${m}`)},
    location: {search: ""},
    setTimeout, clearTimeout, setInterval, clearInterval, structuredClone,
    // Node drains MessagePort messages back to back and starves its timers,
    // which browsers do not; setImmediate gives the browser's behaviour.
    MessageChannel: class {
      constructor() {
        const p1 = this.port1 = {onmessage: null, start() {}};
        this.port2 = {postMessage() { setImmediate(() => p1.onmessage?.({})); }};
      }
    },
    fetch: async () => ({ok: false}),
    atob, btoa,
    localStorage: (() => { const m = new Map(); return {getItem: k => m.get(k) ?? null, setItem: (k, v) => m.set(k, String(v))}; })(),
  });
  context.window.document = document;

  // ── the parser and the interpreter, straight out of index.html ──
  vm.runInContext(fs.readFileSync(path.join(ROOT, "zbasic-compiled.js"), "utf8"), context);
  const html = fs.readFileSync(path.join(ROOT, "index.html"), "utf8");
  let src = html.slice(html.indexOf("<script>\n") + 9, html.lastIndexOf("</script>"));
  src = src.replace("async function execStmt(stmt, env) {", "async function execStmt(stmt, env) { __probe(stmt);");
  const ids = new WeakMap(), hot = new Map(), text = [];
  context.__probe = stmt => {
    let id = ids.get(stmt);
    if (id === undefined) {
      ids.set(stmt, id = text.length);
      text.push(JSON.stringify(stmt).slice(0, 300));
      parentPort.postMessage({stmt: {id, text: text[id]}});
    }
    Atomics.store(shared, 0, id); Atomics.add(shared, 1, 1);
    hot.set(id, (hot.get(id) || 0) + 1);
  };
  src += `\n;globalThis.__h = { get running() { return running; }, windowDefs, controlStore, menuDefs,
    get globalVars() { return globalVars; }, get eventQueue() { return eventQueue; },
    get outputWindowId() { return outputWindowId; }, get frontWindowId() { return frontWindowId; },
    pushEvent, notePress, noteRelease, setMouse(x, y) { mouseX = x; mouseY = y; } };`;
  vm.runInContext(src, context, {filename: "index.html"});
  const h = context.__h;
  const descendants = (e, out = []) => { for (const c of e.children) { out.push(c); descendants(c, out); } return out; };
  h.menu = (menu, item) => h.pushEvent('menu', {menu, item});
  h.disk = () => Object.values(context.disk()).map(f => `${f.name} (${f.type}, ${f.data.length} bytes)`);
  h.modal = () => {
    const back = document.body.children.filter(c => c.classList.contains('mac-alert-back')).pop();
    if (!back) return null;
    const els = descendants(back), find = p => els.find(p);
    return {
      text: els.map(e => e.textContent).filter(Boolean).join(' | '),
      click: label => find(e => e.tagName === 'BUTTON' && e.textContent === label).onclick(),
      pick: name => find(e => e.classList.contains('sf-item') && e.children[0].textContent === name).onclick(),
      type: text => { find(e => e.classList.contains('sf-name')).value = text; },
    };
  };

  // ── load and run the program ──
  const prog = fs.existsSync(name) ? {dir: path.dirname(name), files: [path.basename(name)], main: path.basename(name)}
    : JSON.parse(fs.readFileSync(path.join(ROOT, "progs/programs.json"), "utf8")).find(p => p.name === name);
  if (!prog) { log(`ERROR no program "${name}"`); parentPort.postMessage({done: true}); return; }
  context.resetFileStore();
  for (const f of prog.files) {
    const buf = fs.readFileSync(path.resolve(ROOT, prog.dir, f));
    context.addFile(f.split("/").pop(), buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength));
  }
  context.parseAndLoad(prog.main);
  context.runProgram().then(() => parentPort.postMessage({ended: true}));
  if (script) {
    const body = fs.readFileSync(script, "utf8");
    new Function("h", "sleep", "log", `return (async () => { ${body} })();`)(h, ms => new Promise(r => setTimeout(r, ms)), log)
      .catch(e => log(`ERROR in script: ${e.stack}`));
  }

  parentPort.on("message", m => {
    if (!m.report) return;
    const top = [...hot.entries()].sort((a, b) => b[1] - a[1]).slice(0, 6);
    log(`[windows] ${Object.entries(h.windowDefs).map(([k, w]) => `${k}:"${w.title}" ${w.logW}x${w.logH}`).join(", ")}`);
    log(`[menus] ${Object.entries(h.menuDefs).map(([k, m]) => `${k}:${m.title}`).join(", ")}`);
    log(`[controls] ${Object.keys(h.controlStore).join(" ")}`);
    log(`[hottest]\n${top.map(([id, n]) => `  ${n}x ${text[id].slice(0, 150)}`).join("\n")}`);
    parentPort.postMessage({done: true});
  });
}
