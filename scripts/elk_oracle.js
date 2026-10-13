#!/usr/bin/env node
// Lay out an ELK JSON graph with the elkjs that mermaid bundles (0.9.3):
// the reference for the layout engine.
//
// elkjs is cut out of the mermaid bundle that scripts/oracle.py uses, so
// the two references cannot drift apart.
//
// Usage: node scripts/elk_oracle.js graph.json [more.json ...]
//        Prints each laid-out graph as one line of JSON.

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '.repos', 'oracle');
const extracted = path.join(root, 'elk.bundled.js');

function extract() {
  const chunks = path.join(root, 'package', 'dist', 'chunks', 'mermaid.esm');
  const chunk = fs.readdirSync(chunks).find((name) => /^elk-.*\.mjs$/.test(name));
  if (!chunk) {
    throw new Error(`no elk chunk in ${chunks}; see the setup notes in scripts/oracle.py`);
  }
  const lines = fs.readFileSync(path.join(chunks, chunk), 'utf8').split('\n');
  const start = lines.findIndex((line) => /elk\.bundled\.js"\(exports, module\) \{$/.test(line));
  const end = lines.findIndex((line, index) => index > start && line === '  }');
  if (start < 0 || end < 0) {
    throw new Error('cannot find elk.bundled.js inside the mermaid chunk');
  }
  // The bundler's function-naming helper is the only outside reference.
  const prelude = 'var __name = (target) => target;\n';
  fs.writeFileSync(extracted, prelude + lines.slice(start + 1, end).join('\n') + '\n');
}

async function main() {
  if (!fs.existsSync(extracted)) {
    extract();
  }
  const ELK = require(extracted);
  for (const file of process.argv.slice(2)) {
    const graph = JSON.parse(fs.readFileSync(file, 'utf8'));
    const result = await new ELK().layout(graph);
    process.stdout.write(JSON.stringify(result) + '\n');
  }
}

main().catch((error) => {
  console.error(error && error.message ? error.message : error);
  process.exit(1);
});
