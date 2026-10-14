#!/usr/bin/env python3
"""Compare the port's use case parser with mermaid's.

Takes use case diagrams from the given `.mmd` files, from the ```mermaid
blocks of the given Markdown files, and from JSON files holding a list of
sources; parses each with upstream (through the oracle page) and with
`cmd/mermaid usecase-db`, and reports every diagram whose layout data
differs, or that one side rejects and the other accepts.

Usage: scripts/check_usecase_parse.py [file.mmd | docs.md | cases.json | directory] ...
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
  const out = [];
  for (const source of sources) {
    try {
      const diagram = await mermaid.mermaidAPI.getDiagramFromText(source);
      const data = diagram.db.getData();
      out.push(JSON.parse(JSON.stringify({
        nodes: data.nodes,
        edges: data.edges,
        direction: data.direction,
        accTitle: diagram.db.getAccTitle(),
        accDescription: diagram.db.getAccDescription(),
      })));
    } catch (error) {
      out.push({ error: String(error && error.message || error) });
    }
  }
  return out;
})()"""

NODE_KEYS = [
    "id", "label", "labelType", "shape", "isGroup", "padding", "colorIndex", "cssClasses", "cssStyles",
    "cssCompiledStyles", "actorType", "business", "icon", "stereotype", "parentId", "noteTarget", "jsonRows",
    "boundaryType", "wrappingWidth", "minWidth", "spreadPorts",
]
EDGE_KEYS = [
    "id", "source", "target", "relationshipType", "internal", "arrowTypeStart", "arrowTypeEnd", "pattern",
    "label", "labelType", "classes", "style", "cssCompiledStyles", "animate", "animation", "minlen",
    "isUserDefinedId",
]
# What upstream leaves out where the port writes a value.
DEFAULTS = {"business": False, "jsonRows": [], "spreadPorts": False}


def sources(paths):
    found = []
    for path in paths:
        path = pathlib.Path(path)
        files = sorted(path.rglob("*.mmd")) if path.is_dir() else [path]
        for file in files:
            text = file.read_text()
            if file.suffix == ".md":
                for index, block in enumerate(re.findall(r"```mermaid[^\n]*\n(.*?)```", text, re.S)):
                    if re.match(r"\s*(---.*?---\s*)?usecase-beta\b", block, re.S):
                        found.append((f"{file.name}#{index}", block))
            elif file.suffix == ".json":
                for index, block in enumerate(json.loads(text)):
                    found.append((f"{file.name}#{index}", block))
            else:
                found.append((file.name, text))
    return found


def normalize(db):
    if "error" in db:
        return db
    pick = lambda item, keys: {key: item.get(key, DEFAULTS.get(key)) for key in keys}
    return {
        **{key: value for key, value in db.items() if key not in ("nodes", "edges")},
        "nodes": [pick(node, NODE_KEYS) for node in db["nodes"]],
        "edges": [pick(edge, EDGE_KEYS) for edge in db["edges"]],
    }


def main():
    cases = sources(sys.argv[1:])
    expected = oracle.run([], {}, DUMP % json.dumps([text for _, text in cases]))[0]["value"]
    binary = max(
        (path for path in (ROOT / "_build" / "native").rglob("mermaid.exe") if "dSYM" not in str(path)),
        key=lambda path: path.stat().st_mtime,
    )
    actual = []
    with tempfile.TemporaryDirectory() as tmp:
        files = []
        for index, (_, text) in enumerate(cases):
            file = pathlib.Path(tmp) / f"{index}.mmd"
            file.write_text(text)
            files.append(str(file))
        for start in range(0, len(files), 200):
            out = subprocess.run([str(binary), "usecase-db", *files[start:start + 200]],
                                 cwd=ROOT, capture_output=True, text=True)
            actual += [json.loads(line) for line in out.stdout.splitlines() if line.startswith("{")]
    if len(actual) != len(cases):
        sys.exit(f"the port printed {len(actual)} results for {len(cases)} diagrams")
    bad = 0
    for (name, text), want, got in zip(cases, expected, actual):
        if "error" in want:
            if "error" not in got:
                bad += 1
                print(f"FAIL {name}: upstream rejects it ({want['error'][:100]!r}), the port accepts it")
                print("    " + text.replace("\n", "\n    "))
            continue
        want, got = normalize(want), normalize(got)
        if want != got:
            bad += 1
            print(f"FAIL {name}" + (f": {got['error'][:200]!r}" if "error" in got else ""))
            print("    " + text.replace("\n", "\n    "))
            if "error" in got:
                continue
            for key in sorted(set(want) | set(got)):
                if want.get(key) != got.get(key):
                    a, b = json.dumps(want.get(key), sort_keys=True), json.dumps(got.get(key), sort_keys=True)
                    at = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
                    print(f"    {key}: upstream ...{a[max(0, at - 60):at + 90]}")
                    print(f"    {' ' * len(key)}  port     ...{b[max(0, at - 60):at + 90]}")
    print(f"{len(cases) - bad}/{len(cases)} use case diagrams parse identically")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
