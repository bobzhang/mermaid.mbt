#!/usr/bin/env python3
"""Compare the port's flowchart parser with mermaid's.

Takes flowchart sources from the given `.mmd` files and from the
```mermaid blocks of the given Markdown files, parses each with upstream
(through the oracle page) and with `cmd/mermaid flow-db`, and reports
every database that differs.

Usage: scripts/check_flow_parse.py [file.mmd | docs.md | directory] ...
"""

import json
import pathlib
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import oracle  # noqa: E402

ROOT = oracle.ROOT

DUMP = """(async () => {
  const sources = %s;
  const plain = (value) => JSON.parse(JSON.stringify(value));
  const out = [];
  for (const source of sources) {
    try {
      const diagram = await mermaid.mermaidAPI.getDiagramFromText(source);
      const db = diagram.db;
      const edges = db.getEdges();
      const result = {
        vertices: [...db.getVertices().values()].map(plain),
        edges: edges.map(plain),
        subGraphs: db.getSubGraphs().map(plain),
        classes: [...db.getClasses().values()].map(plain),
        tooltips: Object.fromEntries(db.tooltips ?? []),
        accTitle: db.getAccTitle(),
        accDescription: db.getAccDescription(),
        direction: db.getDirection(),
        defaultInterpolate: edges.defaultInterpolate,
        defaultStyle: edges.defaultStyle,
      };
      out.push(plain(result));
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
                    if re.match(r"\s*(---.*?---\s*)?(%%\{.*?\}%%\s*)?(flowchart|graph)\b", block, re.S):
                        found.append((f"{file.name}#{index}", block))
            else:
                found.append((file.name, text))
    return found


def normalize(db):
    """Drop fields the port does not model."""
    for vertex in db.get("vertices", []):
        vertex.pop("props", None)
    for edge in db.get("edges", []):
        if edge.get("interpolate") is None:
            edge.pop("interpolate", None)
    return {key: value for key, value in db.items() if value is not None}


def main():
    cases = sources(sys.argv[1:])
    expected = oracle.run([], {}, DUMP % json.dumps([text for _, text in cases]))[0]["value"]
    with tempfile.TemporaryDirectory() as tmp:
        files = []
        for index, (_, text) in enumerate(cases):
            file = pathlib.Path(tmp) / f"{index}.mmd"
            # The port's CLI parses what the preprocessor hands the parser.
            file.write_text(text)
            files.append(str(file))
        out = subprocess.run(["moon", "run", "--target", "native", "cmd/mermaid", "--", "flow-db", *files],
                             cwd=ROOT, capture_output=True, text=True)
    actual = [json.loads(line) for line in out.stdout.splitlines() if line.startswith("{")]
    if len(actual) != len(cases):
        sys.exit(out.stdout[-2000:] + out.stderr[-2000:])
    bad = 0
    for (name, text), want, got in zip(cases, expected, actual):
        if "error" in want:
            if "error" not in got:
                bad += 1
                print(f"FAIL {name}: upstream rejects it ({want['error'][:60]!r}), the port accepts it")
            continue
        want, got = normalize(want), normalize(got)
        if want != got:
            bad += 1
            print(f"FAIL {name}" + (f": {got['error'][:160]!r}" if "error" in got else ""))
            if "error" in got:
                continue
            for key in sorted(set(want) | set(got)):
                if want.get(key) != got.get(key):
                    a, b = json.dumps(want.get(key), sort_keys=True), json.dumps(got.get(key), sort_keys=True)
                    at = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
                    print(f"    {key}: upstream ...{a[max(0, at - 60):at + 90]}")
                    print(f"    {' ' * len(key)}  port     ...{b[max(0, at - 60):at + 90]}")
    print(f"{len(cases) - bad}/{len(cases)} flowcharts parse identically")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
