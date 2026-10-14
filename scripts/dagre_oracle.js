#!/usr/bin/env node
// Lay out a graph with the dagre that mermaid bundles (dagre-d3-es 7.0.14):
// the reference for `internal/dagre`.
//
// dagre and graphlib are cut out of the mermaid bundle that
// scripts/oracle.py uses, so the two references cannot drift apart.
//
// Usage: node scripts/dagre_oracle.js graph.json [more.json ...]
//        Prints each laid-out graph as one line of JSON.
//
// A graph is what dagre reads of the graph it is handed, in the order it
// reads it:
//   { "graph": { "rankdir": "TB", "nodesep": 50, "ranksep": 50,
//                "marginx": 8, "marginy": 8, ... },
//     "nodes": [ { "id": "a", "width": 10, "height": 10, "parent": "p" } ],
//     "edges": [ { "v": "a", "w": "b", "name": "e1", "minlen": 1,
//                  "width": 0, "height": 0, "labelpos": "c", ... } ] }
// A file may also hold an array of such graphs, laid out one after the
// other. Numbers that JSON cannot write are the strings "NaN", "Infinity"
// and "-Infinity", in the input and in the output; an attribute that is
// left out is one the graph does not have.
//
// The result lists the nodes and the edges in the order of the input:
//   { "width": .., "height": ..,
//     "nodes": [ { "id", "x", "y", "width", "height" } ],
//     "edges": [ { "v", "w", "name", "points": [..], "x", "y" } ] }

const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');

const root = path.resolve(__dirname, '..', '.repos', 'oracle');
const chunks = path.join(root, 'package', 'dist', 'chunks', 'mermaid.esm');
const extracted = path.join(root, 'dagre.extracted.mjs');

// The module of the bundle that holds dagre's layout also holds mermaid's
// adapter, which needs a DOM; only the library part of it is kept.
function extract() {
  const chunk = fs.readdirSync(chunks).find((name) => /^dagre-.*\.mjs$/.test(name));
  if (!chunk) {
    throw new Error(`no dagre chunk in ${chunks}; see the setup notes in scripts/oracle.py`);
  }
  const text = fs.readFileSync(path.join(chunks, chunk), 'utf8');
  const lines = text.split('\n');
  const start = lines.findIndex((line) => /^\/\/ .*dagre-d3-es\/src\/dagre\//.test(line));
  const end = lines.findIndex((line) => /^\/\/ src\/rendering-util\//.test(line));
  const lodash = text.match(/import \{[^}]*\bGraph,[^}]*\} from "(\.\/chunk-[^"]+)";/);
  if (start < 0 || end < 0 || !lodash) {
    throw new Error('cannot find dagre inside the mermaid chunk');
  }
  // The helpers it imports (lodash and graphlib) stay where they are.
  const helpers = pathToFileURL(path.join(chunks, lodash[1])).href;
  const prelude = lodash[0].replace(lodash[1], helpers) + '\nvar __name = (target) => target;\n';
  const exports = '\nexport { layout, Graph };\n';
  fs.writeFileSync(extracted, prelude + lines.slice(start, end).join('\n') + exports);
}

const special = { NaN: NaN, Infinity: Infinity, '-Infinity': -Infinity };
const decode = (value) => (typeof value === 'string' && value in special ? special[value] : value);
const encode = (value) => (typeof value === 'number' && !Number.isFinite(value) ? String(value) : value);

function layoutOne(dagre, input) {
  const graph = new dagre.Graph({ multigraph: true, compound: true });
  const label = {};
  for (const [key, value] of Object.entries(input.graph || {})) {
    label[key] = decode(value);
  }
  graph.setGraph(label);
  for (const node of input.nodes) {
    const attrs = {};
    for (const [key, value] of Object.entries(node)) {
      if (key !== 'id' && key !== 'parent') {
        attrs[key] = decode(value);
      }
    }
    graph.setNode(node.id, attrs);
  }
  // Parents are set once every node exists, so that the nodes keep the
  // order they are listed in.
  for (const node of input.nodes) {
    if (node.parent !== undefined) {
      graph.setParent(node.id, node.parent);
    }
  }
  for (const edge of input.edges) {
    const attrs = {};
    for (const [key, value] of Object.entries(edge)) {
      if (key !== 'v' && key !== 'w' && key !== 'name') {
        attrs[key] = decode(value);
      }
    }
    graph.setEdge(edge.v, edge.w, attrs, edge.name);
  }
  dagre.layout(graph);
  const point = (p) => ({ x: encode(p.x), y: encode(p.y) });
  return {
    width: encode(graph.graph().width),
    height: encode(graph.graph().height),
    nodes: input.nodes.map((node) => {
      const out = graph.node(node.id);
      return {
        id: node.id,
        x: encode(out.x),
        y: encode(out.y),
        width: encode(out.width),
        height: encode(out.height),
      };
    }),
    edges: input.edges.map((edge) => {
      const out = graph.edge(edge.v, edge.w, edge.name);
      const result = { v: edge.v, w: edge.w };
      if (edge.name !== undefined) {
        result.name = edge.name;
      }
      result.points = (out.points || []).map(point);
      if (Object.hasOwn(out, 'x')) {
        result.x = encode(out.x);
        result.y = encode(out.y);
      }
      return result;
    }),
  };
}

async function main() {
  if (!fs.existsSync(extracted)) {
    extract();
  }
  const dagre = await import(pathToFileURL(extracted).href);
  for (const file of process.argv.slice(2)) {
    const input = JSON.parse(fs.readFileSync(file, 'utf8'));
    for (const graph of Array.isArray(input) ? input : [input]) {
      let result;
      try {
        result = layoutOne(dagre, graph);
      } catch (error) {
        result = { error: String((error && error.message) || error) };
      }
      process.stdout.write(JSON.stringify(result) + '\n');
    }
  }
}

main().catch((error) => {
  console.error(error && error.message ? error.message : error);
  process.exit(1);
});
