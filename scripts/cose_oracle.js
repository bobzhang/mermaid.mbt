#!/usr/bin/env node
// Lay out a graph with the cose-bilkent that mermaid bundles (layout-base
// 1.0.2 and cose-base 1.0.3): the reference for `internal/cose`.
//
// The two libraries are cut out of the mermaid bundle that scripts/oracle.py
// uses, so the references cannot drift apart. The driver repeats what
// cytoscape-cose-bilkent does with the options mermaid passes (`quality:
// "proof"`, `animate: false`, the rest defaults), without cytoscape: the
// positions it computes are those `cy.nodes().position()` has in the
// browser, which scripts/check_cose.py verifies against Chrome.
//
// Under node the result is NOT the reference for every graph: the layout
// starts from `Math.cos` and `Math.sin`, and node's are not Chrome's in the
// last bit for some angles. `--expression` therefore prints a JavaScript
// expression that computes the same in a page (scripts/check_cose.py
// evaluates it in the oracle's Chrome); node is for quick looks and traces.
//
// Usage: node scripts/cose_oracle.js [--trace] graph.json [more.json ...]
//        node scripts/cose_oracle.js --expression [--trace] graph.json ...
//        A graph is {"nodes": [{"id", "width", "height"}],
//        "edges": [{"id", "source", "target"}]}. Prints one line of JSON per
//        graph: {"nodes": [{"id", "x", "y"}]}; with --trace also "ticks",
//        the rectangles' corners before the first iteration and after
//        every iteration.

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '.repos', 'oracle');

// The source of a function that returns cose-base (with layout-base as its
// `layoutBase`), cut out of the chunk.
function librarySource() {
  const chunks = path.join(root, 'package', 'dist', 'chunks', 'mermaid.esm');
  const chunk = fs.readdirSync(chunks).find((name) => /^cose-bilkent-.*\.mjs$/.test(name));
  if (!chunk) {
    throw new Error(`no cose-bilkent chunk in ${chunks}; see the setup notes in scripts/oracle.py`);
  }
  const text = fs.readFileSync(path.join(chunks, chunk), 'utf8');
  const start = text.indexOf('var require_layout_base = __commonJS(');
  const end = text.indexOf('var require_cytoscape_cose_bilkent = __commonJS(');
  if (start < 0 || end < 0) {
    throw new Error('cannot find layout-base and cose-base inside the mermaid chunk');
  }
  // The bundler's helpers are the only outside references.
  const prelude =
    'var __name = (target) => target;\n' +
    'var __commonJS = (cb, mod) => () => (mod || (0, cb[Object.keys(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports);\n';
  return prelude + text.slice(start, end) + '\nreturn require_cose_base();';
}

// cytoscape-cose-bilkent's defaults, overridden as mermaid's
// `cytoscape-setup.ts` does.
const options = {
  quality: 'proof',
  nodeDimensionsIncludeLabels: false,
  randomize: true,
  nodeRepulsion: 4500,
  idealEdgeLength: 50,
  edgeElasticity: 0.45,
  nestingFactor: 0.1,
  gravity: 0.25,
  numIter: 2500,
  tile: true,
  animate: false,
  tilingPaddingVertical: 10,
  tilingPaddingHorizontal: 10,
  gravityRangeCompound: 1.5,
  gravityCompound: 1.0,
  gravityRange: 3.8,
  initialEnergyOnIncremental: 0.5,
};

// cytoscape-cose-bilkent's `getUserOptions`.
function applyOptions(coseBase) {
  const { CoSEConstants } = coseBase;
  const { FDLayoutConstants, LayoutConstants } = coseBase.layoutBase;
  CoSEConstants.DEFAULT_REPULSION_STRENGTH = FDLayoutConstants.DEFAULT_REPULSION_STRENGTH = options.nodeRepulsion;
  CoSEConstants.DEFAULT_EDGE_LENGTH = FDLayoutConstants.DEFAULT_EDGE_LENGTH = options.idealEdgeLength;
  CoSEConstants.DEFAULT_SPRING_STRENGTH = FDLayoutConstants.DEFAULT_SPRING_STRENGTH = options.edgeElasticity;
  CoSEConstants.PER_LEVEL_IDEAL_EDGE_LENGTH_FACTOR = FDLayoutConstants.PER_LEVEL_IDEAL_EDGE_LENGTH_FACTOR =
    options.nestingFactor;
  CoSEConstants.DEFAULT_GRAVITY_STRENGTH = FDLayoutConstants.DEFAULT_GRAVITY_STRENGTH = options.gravity;
  CoSEConstants.MAX_ITERATIONS = FDLayoutConstants.MAX_ITERATIONS = options.numIter;
  CoSEConstants.DEFAULT_GRAVITY_RANGE_FACTOR = FDLayoutConstants.DEFAULT_GRAVITY_RANGE_FACTOR = options.gravityRange;
  CoSEConstants.DEFAULT_COMPOUND_GRAVITY_STRENGTH = FDLayoutConstants.DEFAULT_COMPOUND_GRAVITY_STRENGTH =
    options.gravityCompound;
  CoSEConstants.DEFAULT_COMPOUND_GRAVITY_RANGE_FACTOR = FDLayoutConstants.DEFAULT_COMPOUND_GRAVITY_RANGE_FACTOR =
    options.gravityRangeCompound;
  CoSEConstants.DEFAULT_COOLING_FACTOR_INCREMENTAL = FDLayoutConstants.DEFAULT_COOLING_FACTOR_INCREMENTAL =
    options.initialEnergyOnIncremental;
  LayoutConstants.QUALITY = options.quality === 'draft' ? 0 : options.quality === 'proof' ? 2 : 1;
  CoSEConstants.NODE_DIMENSIONS_INCLUDE_LABELS =
    FDLayoutConstants.NODE_DIMENSIONS_INCLUDE_LABELS =
    LayoutConstants.NODE_DIMENSIONS_INCLUDE_LABELS =
      options.nodeDimensionsIncludeLabels;
  CoSEConstants.DEFAULT_INCREMENTAL =
    FDLayoutConstants.DEFAULT_INCREMENTAL =
    LayoutConstants.DEFAULT_INCREMENTAL =
      !options.randomize;
  CoSEConstants.ANIMATE = FDLayoutConstants.ANIMATE = LayoutConstants.ANIMATE = options.animate;
  CoSEConstants.TILE = options.tile;
  CoSEConstants.TILING_PADDING_VERTICAL = options.tilingPaddingVertical;
  CoSEConstants.TILING_PADDING_HORIZONTAL = options.tilingPaddingHorizontal;
}

// cytoscape-cose-bilkent's `run` for a graph without compound nodes, every
// node starting at the origin as mermaid adds them.
function layout(coseBase, graph, trace) {
  const { CoSELayout, CoSENode } = coseBase;
  const { PointD, DimensionD } = coseBase.layoutBase;
  applyOptions(coseBase);
  const engine = new CoSELayout();
  const gm = engine.newGraphManager();
  const rootGraph = gm.addRoot();
  const byId = {};
  for (const node of graph.nodes) {
    const x = node.x ?? 0;
    const y = node.y ?? 0;
    const lNode = rootGraph.add(
      new CoSENode(
        engine.graphManager,
        new PointD(x - node.width / 2, y - node.height / 2),
        new DimensionD(parseFloat(node.width), parseFloat(node.height))
      )
    );
    lNode.id = node.id;
    lNode.paddingLeft = lNode.paddingTop = lNode.paddingRight = lNode.paddingBottom = 0;
    byId[node.id] = lNode;
  }
  for (const edge of graph.edges) {
    const source = byId[edge.source];
    const target = byId[edge.target];
    if (source !== target && source.getEdgesBetween(target).length == 0) {
      gm.add(engine.newEdge(), source, target).id = edge.id;
    }
  }
  const ticks = [];
  if (trace) {
    const tick = engine.tick;
    const corners = () => graph.nodes.map((node) => [byId[node.id].rect.x, byId[node.id].rect.y]);
    engine.tick = function () {
      if (ticks.length === 0) {
        // Where the spring embedder starts from.
        ticks.push(corners());
      }
      const done = tick.call(this);
      ticks.push(corners());
      return done;
    };
  }
  engine.runLayout();
  const result = {
    nodes: graph.nodes.map((node) => ({
      id: node.id,
      x: byId[node.id].getRect().getCenterX(),
      y: byId[node.id].getRect().getCenterY(),
    })),
  };
  if (trace) {
    result.ticks = ticks;
  }
  return result;
}

function main() {
  let args = process.argv.slice(2);
  const expression = args[0] === '--expression';
  args = expression ? args.slice(1) : args;
  const trace = args[0] === '--trace';
  args = trace ? args.slice(1) : args;
  const graphs = args.map((file) => JSON.parse(fs.readFileSync(file, 'utf8')));
  if (expression) {
    // Everything the layout needs, as one expression for a page.
    process.stdout.write(
      `(() => {
        const coseBase = (function () { ${librarySource()} })();
        const options = ${JSON.stringify(options)};
        ${applyOptions}
        ${layout}
        return ${JSON.stringify(graphs.map(({ nodes, edges }) => ({ nodes, edges })))}.map((graph) => layout(coseBase, graph, ${trace}));
      })()`
    );
    return;
  }
  const coseBase = new Function(librarySource())();
  for (const graph of graphs) {
    process.stdout.write(JSON.stringify(layout(coseBase, graph, trace)) + '\n');
  }
}

main();
