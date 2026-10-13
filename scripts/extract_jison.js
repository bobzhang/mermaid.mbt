#!/usr/bin/env node
// Extract the jison parsers that mermaid ships.
//
// mermaid's grammars (`*.jison`) are compiled to LALR tables and lexer rules
// at build time, and the published bundle carries the result. This script
// evaluates each generated parser found in the bundle's chunks and prints
// its tables as JSON: the port then drives them with its own LALR and lexer
// engine (internal/jison) instead of reimplementing jison's table
// construction.
//
// Usage: node scripts/extract_jison.js            # list grammars
//        node scripts/extract_jison.js flow       # JSON for one grammar

const fs = require('fs');
const path = require('path');

const chunks = path.resolve(__dirname, '..', '.repos', 'oracle', 'package', 'dist', 'chunks', 'mermaid.esm');

function findParsers() {
  const found = {};
  for (const file of fs.readdirSync(chunks)) {
    if (!file.endsWith('.mjs')) continue;
    const lines = fs.readFileSync(path.join(chunks, file), 'utf8').split('\n');
    for (let i = 0; i < lines.length; i++) {
      const match = /^\/\/ src\/diagrams\/.*\/([\w-]+)\.jison$/.exec(lines[i]);
      if (!match) continue;
      const end = lines.findIndex((line, index) => index > i && line === '})();');
      found[match[1]] = { file, source: lines.slice(i + 1, end + 1).join('\n') };
    }
  }
  return found;
}

function load(source) {
  // The generated code only needs esbuild's function-naming helper.
  const __name = (target) => target;
  return new Function('__name', source.replace(/^var parser = /, 'return ') )(__name);
}

function describe(name, entry) {
  const parser = load(entry.source);
  const lexer = parser.lexer;
  return {
    name,
    chunk: entry.file,
    symbols: parser.symbols_,
    terminals: parser.terminals_,
    productions: parser.productions_,
    table: parser.table,
    defaultActions: parser.defaultActions,
    action: parser.performAction.toString(),
    lexer: {
      options: lexer.options || {},
      rules: lexer.rules.map((rule) => ({ source: rule.source, flags: rule.flags })),
      conditions: lexer.conditions,
      action: lexer.performAction.toString(),
    },
  };
}

const parsers = findParsers();
const wanted = process.argv[2];
if (!wanted) {
  for (const name of Object.keys(parsers).sort()) {
    const info = describe(name, parsers[name]);
    console.log(`${name}: ${info.table.length} states, ${info.productions.length} productions, ` +
      `${info.lexer.rules.length} lexer rules (${parsers[name].file})`);
  }
} else if (!parsers[wanted]) {
  console.error(`no grammar named ${wanted}; run without arguments for the list`);
  process.exit(1);
} else {
  process.stdout.write(JSON.stringify(describe(wanted, parsers[wanted])) + '\n');
}
