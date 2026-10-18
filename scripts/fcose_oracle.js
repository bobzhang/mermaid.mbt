#!/usr/bin/env node
// Lay out architecture diagrams with the cytoscape and cytoscape-fcose that
// mermaid bundles: the reference for `internal/fcose` and for the
// cytoscape geometry the architecture renderer reads back.
//
// The libraries (cytoscape 3.34.0; layout-base 2.0.1, cose-base 2.2.0 and
// cytoscape-fcose 2.2.0 from the architecture chunk) and the renderer's own
// layout code (`layoutArchitecture` and its helpers, the database, the
// seeded `Math.random`) are cut out of the mermaid bundle that
// scripts/oracle.py uses, so the reference cannot drift from it. The
// driver parses each diagram with the page's mermaid, fills a database of
// the cut-out code with what mermaid parsed, and runs `layoutArchitecture`
// as `draw` does; it prints what the renderer reads from cytoscape: node
// positions, group boxes, edge endpoints and midpoints.
//
// The layout uses `Math.sin`-free arithmetic, but cytoscape measures labels
// with a canvas, so the reference only exists in a page: the script prints
// a JavaScript expression that scripts/check_fcose.py evaluates in the
// oracle's Chrome.
//
// Usage: node scripts/fcose_oracle.js [--trace] diagram.mmd [more.mmd ...]
//        With --trace, every run of fcose also reports the graph it starts
//        from, the positions after the constraints are enforced and after
//        every iteration.

const fs = require('fs');
const path = require('path');

const chunks = path.resolve(__dirname, '..', '.repos', 'oracle', 'package', 'dist', 'chunks', 'mermaid.esm');

function chunk(prefix) {
  const name = fs.readdirSync(chunks).find((file) => file.startsWith(prefix) && file.endsWith('.mjs'));
  if (!name) {
    throw new Error(`no ${prefix}*.mjs in ${chunks}; see the setup notes in scripts/oracle.py`);
  }
  return fs.readFileSync(path.join(chunks, name), 'utf8');
}

// The text between two markers of a chunk.
function cut(text, start, end) {
  const from = text.indexOf(start);
  const to = end === null ? text.length : text.indexOf(end, from);
  if (from < 0 || to < 0) {
    throw new Error(`cannot find ${start} .. ${end} in the bundle`);
  }
  return text.slice(from, to);
}

// An ES module chunk as plain statements: its imports and exports go.
function statements(text) {
  return text.replace(/^import[\s\S]*?from\s+"[^"]+";\s*$/gm, '').replace(/^export\s*\{[\s\S]*?\};\s*$/gm, '');
}

function librarySource() {
  const helpers = statements(chunk('chunk-35ZOQMXA'));
  const cytoscape = statements(chunk('chunk-GBM4U3XT'));
  const architecture = chunk('architectureDiagram-');
  const libraries = cut(architecture, 'var require_layout_base = __commonJS(', '// src/diagrams/architecture/architectureDb.ts');
  const db = cut(architecture, '// src/diagrams/architecture/architectureDb.ts', '// src/diagrams/architecture/architectureParser.ts');
  const renderer = cut(architecture, 'var import_cytoscape_fcose = ', '// src/diagrams/architecture/architectureIcons.ts');
  const layout = cut(architecture, 'cytoscape2.use(import_cytoscape_fcose.default);', 'var draw = ');
  // What the cut-out code takes from the rest of mermaid.
  const stubs = `
    var log = { info() {}, debug() {}, warn() {}, error() {} };
    var select_default = (selector) => {
      const wrap = (node) => ({
        append(tag) { const child = document.createElement(tag); node.appendChild(child); return wrap(child); },
        attr(name, value) { node.setAttribute(name, value); return this; },
        remove() { node.remove(); return this; },
      });
      return wrap(document.querySelector(selector));
    };
    var defaultConfig_default = { architecture: {} };
    var harnessConfig = {};
    var getConfig = () => ({ architecture: harnessConfig });
    var cleanAndMerge = (config) => config;
    var clear = () => {}, setAccTitle = () => {}, getAccTitle = () => '', setDiagramTitle = () => {},
      getDiagramTitle = () => '', getAccDescription = () => '', setAccDescription = () => {};
    var cytoscape2 = cytoscape;
  `;
  return [helpers, cytoscape, stubs, libraries, db, renderer, layout].join('\n');
}

// The driver, run in the page with the libraries above in scope.
function driver(sources, trace) {
  const coseBase = require_cose_base();
  const runs = [];
  let current = null;
  const snapshot = (layout) =>
    layout.getAllNodes().map((node) => ({
      id: node.id,
      x: node.rect.x,
      y: node.rect.y,
      width: node.rect.width,
      height: node.rect.height,
    }));
  const runLayout = coseBase.CoSELayout.prototype.runLayout;
  coseBase.CoSELayout.prototype.runLayout = function () {
    current = {
      nodes: this.getAllNodes().map((node) => ({
        id: node.id,
        x: node.rect.x,
        y: node.rect.y,
        width: node.rect.width,
        height: node.rect.height,
        padding: node.paddingLeft,
        repulsion: node.nodeRepulsion,
        parent: node.getParent() && node.getParent().id !== undefined ? node.getParent().id : null,
      })),
      edges: this.getAllEdges().map((edge) => ({
        id: edge.id,
        source: edge.source.id,
        target: edge.target.id,
        idealLength: edge.idealLength,
        elasticity: edge.edgeElasticity,
      })),
      constraints: JSON.parse(JSON.stringify(this.constraints)),
      ticks: [],
    };
    runs.push(current);
    const result = runLayout.apply(this, arguments);
    current.final = snapshot(this);
    current.iterations = this.totalIterations;
    return result;
  };
  const handleConstraints = coseBase.ConstraintHandler.handleConstraints;
  coseBase.ConstraintHandler.handleConstraints = function (layout) {
    const result = handleConstraints.apply(this, arguments);
    current.enforced = snapshot(layout);
    return result;
  };
  if (trace) {
    const tick = coseBase.CoSELayout.prototype.tick;
    coseBase.CoSELayout.prototype.tick = function () {
      const done = tick.apply(this, arguments);
      current.ticks.push(snapshot(this));
      return done;
    };
  }
  // The centre each run moves its result to.
  const fcose = cytoscape('layout', 'fcose');
  const run = fcose.prototype.run;
  fcose.prototype.run = function () {
    const box = this.options.eles.boundingBox();
    const before = runs.length;
    const result = run.apply(this, arguments);
    if (runs[before]) {
      runs[before].center = { x: box.x1 + box.w / 2, y: box.y1 + box.h / 2, box };
    }
    return result;
  };
  // The `architecture` options of a diagram's frontmatter, which
  // `getDiagramFromText` leaves to `render`: flat `key: value` lines.
  const frontmatterArchitecture = (source) => {
    const match = /^---\s*\n([\s\S]*?)\n---/.exec(source);
    const out = {};
    if (!match) return out;
    let inside = null;
    for (const line of match[1].split('\n')) {
      const indent = line.length - line.trimStart().length;
      if (/^\s*architecture:\s*$/.test(line)) {
        inside = indent;
        continue;
      }
      if (inside === null) continue;
      if (indent <= inside) {
        inside = null;
        continue;
      }
      const [, key, value] = /^\s*(\w+):\s*(.*)$/.exec(line) || [];
      if (key) out[key] = value === 'true' ? true : value === 'false' ? false : isNaN(+value) ? value : +value;
    }
    return out;
  };
  return (async () => {
    const results = [];
    for (const source of sources) {
      runs.length = 0;
      try {
        const diagram = await mermaid.mermaidAPI.getDiagramFromText(source);
        const parsed = diagram.db;
        harnessConfig = { ...parsed.getConfig(), ...frontmatterArchitecture(source) };
        const db = new ArchitectureDB();
        parsed.getGroups().forEach((group) => db.addGroup(group));
        parsed.getServices().forEach((service) => db.addService({ ...service }));
        parsed.getJunctions().forEach((junction) => db.addJunction({ ...junction }));
        parsed.getEdges().forEach((edge) => db.addEdge({ ...edge }));
        parsed.getLayoutHints().forEach((hint) => db.addLayoutHint({ direction: hint.direction, members: [...hint.members] }));
        const ds = db.getDataStructures();
        const cy = await layoutArchitecture(db.getServices(), db.getJunctions(), db.getGroups(), db.getEdges(), db, ds);
        const nodes = cy.nodes().map((node) => {
          const out = { id: node.id(), x: node.position().x, y: node.position().y };
          if (node.data('type') === 'group') {
            const { x1, y1, w, h } = node.boundingBox();
            Object.assign(out, { x1, y1, w, h });
          }
          return out;
        });
        const edges = cy.edges().map((edge) => ({
          id: edge.id(),
          source: edge[0].sourceEndpoint(),
          mid: edge[0].midpoint(),
          target: edge[0].targetEndpoint(),
        }));
        results.push({ nodes, edges, runs: JSON.parse(JSON.stringify(runs)) });
      } catch (error) {
        results.push({ error: String((error && error.stack) || error) });
      }
    }
    return results;
  })();
}

function main() {
  let args = process.argv.slice(2);
  const trace = args[0] === '--trace';
  args = trace ? args.slice(1) : args;
  const sources = args.map((file) => fs.readFileSync(file, 'utf8'));
  process.stdout.write(
    `(() => {
      ${librarySource()}
      return (${driver})(${JSON.stringify(sources)}, ${trace});
    })()`
  );
}

main();
