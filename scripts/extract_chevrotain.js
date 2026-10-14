#!/usr/bin/env node
// Extract a chevrotain parser that mermaid ships.
//
// Some of mermaid's diagrams are parsed with chevrotain: a lexer made of
// token patterns tried in order, and an LL(k) parser whose rules are
// JavaScript methods. chevrotain records the rules as a grammar tree at
// start-up and computes, for every choice in it, the token sequences that
// select each branch. This script evaluates the chunk of the published
// bundle that holds such a parser and prints its tokens, lexer modes,
// grammar and lookahead sequences as JSON: the port interprets them
// (internal/chevrotain) instead of reimplementing chevrotain's analysis.
//
// Predicates (`GATE`) and custom token patterns are JavaScript; they are
// listed by position so that they can be ported by hand.
//
// Usage: node scripts/extract_chevrotain.js usecase

const fs = require('fs');
const path = require('path');

const chunks = path.resolve(__dirname, '..', '.repos', 'oracle', 'package', 'dist', 'chunks', 'mermaid.esm');

function load(name) {
  const file = fs.readdirSync(chunks).find((entry) => entry.startsWith(`${name}Diagram-`) && entry.endsWith('.mjs'));
  if (!file) {
    throw new Error(`no chunk for ${name}`);
  }
  let source = fs.readFileSync(path.join(chunks, file), 'utf8');
  // The parser needs nothing of what the chunk imports, except names to
  // exist while the module initializes.
  const imported = [];
  source = source.replace(/^import\s*(?:\{([^}]*)\}\s*from\s*)?"[^"]+";\n/gm, (_, names) => {
    for (const item of (names || '').split(',')) {
      const local = item.trim().split(/\s+as\s+/).pop();
      if (local) imported.push(local);
    }
    return '';
  });
  source = source.replace(/^export\s*\{[^}]*\};?\s*$/m, '');
  const stubs = imported
    .filter((local) => local !== '__name')
    .map((local) => `var ${local} = new Proxy(function () {}, { get: () => ({}), apply: () => ({}) });`)
    .join('\n');
  const tail = `
return {
  lexer: ${name}Lexer, modes: ${name}LexerModes, tokens: ${name}Tokens, parser: ${name}Parser, EOF,
  getLookaheadPathsForOr, getLookaheadPathsForOptionalProd, PROD_TYPE, collectMethods,
  serializeGrammar, tokenStructuredMatcher,
};`;
  const __name = (target) => target;
  return { file, ...new Function('__name', `${stubs}\n${source}\n${tail}`)(__name) };
}

function describePattern(pattern) {
  if (pattern instanceof RegExp) return { regex: pattern.source, flags: pattern.flags };
  if (typeof pattern === 'function') return { custom: true };
  if (typeof pattern === 'string') return { text: pattern };
  return { none: true };
}

function describe(name) {
  const loaded = load(name);
  const all = [...loaded.tokens, loaded.EOF];
  const nameOf = new Map(all.map((token) => [token.tokenTypeIdx, token.name]));
  const tokens = all.map((token) => ({
    name: token.name,
    pattern: describePattern(token.PATTERN),
    skipped: token.GROUP === loaded.lexer.constructor.SKIPPED || undefined,
    longerAlt: token.LONGER_ALT ? [].concat(token.LONGER_ALT).map((alt) => alt.name) : undefined,
    pushMode: token.PUSH_MODE,
    popMode: token.POP_MODE,
    // Every token type that satisfies a request for this one, itself excluded.
    matchedBy: token.categoryMatches.map((index) => nameOf.get(index)),
  }));
  const modes = {};
  for (const [mode, list] of Object.entries(loaded.modes.modes)) {
    modes[mode] = list.map((token) => token.name);
  }
  const rules = loaded.parser.getGAstProductions();
  const maxLookahead = loaded.parser.maxLookahead;
  const names = (paths) => paths.map((alt) => alt.map((sequence) => sequence.map((token) => token.name)));
  const lookahead = {};
  for (const [ruleName, rule] of Object.entries(rules)) {
    const methods = loaded.collectMethods(rule);
    const entry = {};
    for (const production of methods.alternation) {
      const paths = loaded.getLookaheadPathsForOr(production.idx, rule, production.maxLookahead || maxLookahead);
      entry[`Alternation${production.idx}`] = names(paths);
    }
    const optional = [
      ['option', 'Option', loaded.PROD_TYPE.OPTION],
      ['repetition', 'Repetition', loaded.PROD_TYPE.REPETITION],
      ['repetitionMandatory', 'RepetitionMandatory', loaded.PROD_TYPE.REPETITION_MANDATORY],
    ];
    for (const [key, type, prodType] of optional) {
      for (const production of methods[key]) {
        const paths = loaded.getLookaheadPathsForOptionalProd(
          production.idx,
          rule,
          prodType,
          production.maxLookahead || maxLookahead
        );
        // Only the sequences that enter the production are tested.
        entry[`${type}${production.idx}`] = names(paths)[0];
      }
    }
    for (const key of ['repetitionWithSeparator', 'repetitionMandatoryWithSeparator']) {
      if (methods[key].length > 0) {
        throw new Error(`${ruleName}: ${key} is not supported`);
      }
    }
    lookahead[ruleName] = entry;
  }
  return {
    name,
    chunk: loaded.file,
    defaultMode: loaded.modes.defaultMode,
    tokens,
    modes,
    maxLookahead,
    grammar: loaded.serializeGrammar(Object.values(rules)),
    lookahead,
  };
}

const [, , name] = process.argv;
if (!name) {
  console.error('usage: extract_chevrotain.js <diagram>');
  process.exit(2);
}
console.log(JSON.stringify(describe(name), null, 1));
