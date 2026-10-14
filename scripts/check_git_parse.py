#!/usr/bin/env python3
"""Compare the port's git graph parser and database with mermaid's.

Takes git graph sources from the given `.mmd` files, from the ```mermaid
blocks of the given Markdown files, and from JSON files holding an array of
sources; renders each with upstream (through the oracle page) and reads its
database, parses it with `cmd/mermaid git-db`, and reports every database
that differs. A source upstream rejects must be rejected by the port too.

Generated commit ids come from the same generator on both sides (see
testdata/gitgraph/generated-ids/oracle-prelude.js).

Usage: scripts/check_git_parse.py [file.mmd | docs.md | cases.json | directory] ...
"""

import json
import pathlib
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import compare  # noqa: E402
import oracle  # noqa: E402

ROOT = oracle.ROOT
PRELUDE = ROOT / "testdata" / "gitgraph" / "generated-ids" / "oracle-prelude.js"

DUMP = """(async () => {
  %s;
  const sources = %s;
  const plain = (value) => JSON.parse(JSON.stringify(value));
  // The database is one object for all git graphs. Rendering, unlike
  // getDiagramFromText, applies the diagram's own configuration first,
  // which decides the name and order of the main branch.
  const db = (await mermaid.mermaidAPI.getDiagramFromText('gitGraph')).db;
  const out = [];
  for (const source of sources) {
    try {
      await mermaid.render('probe', source);
      out.push(plain({
        // The renderer reverses every commit's tags in place.
        commits: [...db.getCommits().values()].map((commit) => ({ ...commit, tags: [...commit.tags].reverse() })),
        branches: Object.fromEntries(db.getBranches()),
        branchOrder: db.getBranchesAsObjArray().map((branch) => branch.name),
        currentBranch: db.getCurrentBranch(),
        direction: db.getDirection(),
        title: db.getDiagramTitle(),
        accTitle: db.getAccTitle(),
        accDescription: db.getAccDescription(),
      }));
    } catch (error) {
      out.push({ error: String(error && error.message || error) });
    }
  }
  return out;
})()"""


def sources(paths):
    found = []
    for path in paths:
        path = pathlib.Path(path)
        files = sorted(path.rglob("*.mmd")) if path.is_dir() else [path]
        for file in files:
            text = file.read_text()
            if file.suffix == ".md":
                for index, block in enumerate(re.findall(r"```mermaid[^\n]*\n(.*?)```", text, re.S)):
                    if re.search(r"^\s*gitGraph", block, re.M):
                        found.append((f"{file.name}#{index}", block))
            elif file.suffix == ".json":
                for index, source in enumerate(json.loads(text)):
                    found.append((f"{file.name}#{index}", source))
            else:
                found.append((file.name, text))
    return found


def main():
    cases = sources(sys.argv[1:])
    expression = DUMP % (PRELUDE.read_text().strip(), json.dumps([text for _, text in cases]))
    expected = oracle.run([], {}, expression)[0]["value"]
    binary = compare.build()
    with tempfile.TemporaryDirectory() as tmp:
        files = []
        for index, (_, text) in enumerate(cases):
            file = pathlib.Path(tmp) / f"{index}.mmd"
            file.write_text(text)
            files.append(str(file))
        actual = []
        for start in range(0, len(files), 200):
            out = subprocess.run([str(binary), "git-db", *files[start:start + 200]], capture_output=True, text=True)
            actual += [json.loads(line) for line in out.stdout.splitlines() if line.startswith("{")]
    if len(actual) != len(cases):
        sys.exit(out.stdout[-2000:] + out.stderr[-2000:])
    bad = 0
    for (name, text), want, got in zip(cases, expected, actual):
        if "error" in want:
            if "error" not in got:
                bad += 1
                print(f"FAIL {name}: upstream rejects it ({want['error'][:80]!r}), the port accepts it\n    {text!r}")
            continue
        if want != got:
            bad += 1
            print(f"FAIL {name}" + (f": {got['error'][:200]!r}" if "error" in got else "") + f"\n    {text!r}")
            if "error" in got:
                continue
            for key in sorted(set(want) | set(got)):
                if want.get(key) != got.get(key):
                    a, b = json.dumps(want.get(key), sort_keys=True), json.dumps(got.get(key), sort_keys=True)
                    at = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
                    print(f"    {key}: upstream ...{a[max(0, at - 60):at + 90]}")
                    print(f"    {' ' * len(key)}  port     ...{b[max(0, at - 60):at + 90]}")
    print(f"{len(cases) - bad}/{len(cases)} git graphs parse identically")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
