#!/usr/bin/env python3
"""Check @jsregex against V8 on random patterns over a small alphabet:
groups, alternatives, greedy and lazy quantifiers, lookaheads, back
references and anchors, each matched at the start of a few short subjects
(with `cmd/mermaid regex`, against a sticky RegExp in node). Prints the
differences and how many cases agree.

Usage: SEED=1 N=3000 scripts/check_regex_fuzz.py
"""
import json, os, pathlib, random, subprocess, sys, tempfile
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import compare  # noqa: E402
BIN = os.environ.get('BIN') or str(compare.build())
random.seed(int(os.environ.get('SEED', '1')))
groups = 0
def atom(d):
    global groups
    r = random.random()
    if d > 3 or r < 0.35: return random.choice(['a', 'b', 'c', '.', '[ab]', '[^a]', '\\n', 'a', 'b'])
    if r < 0.5:
        groups += 1; return '(' + alt(d + 1) + ')'
    if r < 0.62: return '(?:' + alt(d + 1) + ')'
    if r < 0.7: return random.choice(['(?=', '(?!']) + alt(d + 1) + ')'
    if r < 0.76 and groups: return '\\' + str(random.randint(1, groups))
    if r < 0.8: return random.choice(['^', '$', '\\b', '\\B'])
    return random.choice(['a', 'b'])
def quant(d):
    a = atom(d)
    if a in ('^', '$', '\\b', '\\B'): return a
    r = random.random()
    if r < 0.55: return a
    q = random.choice(['*', '+', '?', '{2}', '{0,2}', '{1,3}', '{2,}'])
    if random.random() < 0.35: q += '?'
    return a + q
def seq(d): return ''.join(quant(d) for _ in range(random.randint(0, 3)))
def alt(d): return '|'.join(seq(d) for _ in range(random.choice([1, 1, 2, 3])))
cases = []
for _ in range(int(os.environ.get('N', '3000'))):
    groups = 0
    p = alt(0)
    if groups > 9: continue
    for _ in range(6):
        s = ''.join(random.choice('aabbc\n') for _ in range(random.randint(0, 8)))
        cases.append({'source': p, 'flags': random.choice(['', '', 'i', 'm']), 'input': s})
inp = os.path.join(tempfile.mkdtemp(), 'cases.json'); json.dump(cases, open(inp, 'w'))
js = json.loads(subprocess.run(['node', '-e', r'''
const cs = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); const out = [];
for (const c of cs) { let re; try { re = new RegExp(c.source, c.flags + "y"); } catch (e) { out.push("BAD"); continue; }
  const m = re.exec(c.input); out.push(m ? Array.from(m, x => x === undefined ? null : x) : null); }
console.log(JSON.stringify(out));''', inp], capture_output=True, text=True).stdout)
for c, e in zip(cases, js): c['groups'] = len(e) - 1 if isinstance(e, list) else 0
json.dump(cases, open(inp, 'w'))
port = json.loads(subprocess.run([BIN, 'regex', inp], capture_output=True, text=True).stdout)
bad = skip = 0
for c, e, g in zip(cases, js, port):
    if e == 'BAD': skip += 1; continue
    if isinstance(g, str): g = [g]
    if e != g:
        bad += 1
        if bad <= 12: print('DIFF', json.dumps(c['source']), c['flags'], json.dumps(c['input']), 'js', json.dumps(e), 'port', json.dumps(g))
print(f'{len(cases) - bad - skip}/{len(cases) - skip} agree')
