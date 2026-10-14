#!/usr/bin/env python3
"""Compare the port's state diagram layout data with mermaid's.

Takes state diagram sources from the given `.mmd` files and from the
```mermaid blocks of the given Markdown files, builds the nodes and edges
of each with upstream (through the oracle page) and with
`cmd/mermaid state-db`, and reports every difference.

Usage: scripts/check_state_parse.py [file.mmd | docs.md | directory] ...
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
      db.extract(db.getRootDocV2());
      const data = db.getData();
      const links = [];
      db.getLinks().forEach((link, key) => links.push({
        id: typeof key === 'string' ? key : key.id, url: link.url, tooltip: link.tooltip,
      }));
      out.push(plain({
        nodes: data.nodes,
        edges: data.edges,
        classes: [...db.getClasses().values()],
        links,
        accTitle: db.getAccTitle(),
        accDescription: db.getAccDescription(),
        direction: data.direction,
      }));
    } catch (error) {
      out.push({ error: String(error && error.message || error) });
    }
  }
  return out;
})()"""

NODE_FIELDS = ["id", "shape", "label", "description", "cssClasses", "cssCompiledStyles", "cssStyles", "dir",
               "domId", "type", "isGroup", "colorIndex", "padding", "rx", "parentId", "centerLabel", "labelType",
               "position"]
EDGE_FIELDS = ["id", "start", "end", "label", "arrowTypeEnd", "classes", "pattern"]


def sources(paths):
    found = []
    for path in paths:
        path = pathlib.Path(path)
        files = sorted(path.rglob("*.mmd")) if path.is_dir() else [path]
        for file in files:
            text = file.read_text()
            if file.suffix == ".md":
                for index, block in enumerate(re.findall(r"```mermaid[^\n]*\n(.*?)```", text, re.S)):
                    if re.match(r"\s*(---.*?---\s*)?(%%\{.*?\}%%\s*)?stateDiagram", block, re.S):
                        found.append((f"{file.name}#{index}", block))
            else:
                found.append((file.name, text))
    return found


def normalize(db):
    """Keep the fields the port models; name the random region ids alike."""
    def pick(item, fields):
        kept = {}
        for field in fields:
            value = item.get(field)
            if value in (None, "", []) and field not in ("label", "cssClasses", "cssCompiledStyles", "cssStyles"):
                continue
            if field == "description" and not isinstance(value, list):
                continue
            kept[field] = value
        if kept.get("label") in (None, ""):
            kept.pop("label", None)
        return kept
    out = dict(db)
    out["nodes"] = [pick(node, NODE_FIELDS) for node in db.get("nodes", [])]
    out["edges"] = [pick(edge, EDGE_FIELDS) for edge in db.get("edges", [])]
    # Parsing alone does not apply the diagram's default look, rendering does.
    text = json.dumps(out, sort_keys=True).replace("arrow_barb_neo", "arrow_barb")
    # Upstream draws the id of a trailing region from Math.random().
    names = {}
    def canonical(match):
        return names.setdefault(match.group(0), f"id-i-{len(names) + 1}")
    return json.loads(re.sub(r"\bid-[0-9a-z]{1,12}-\d+", canonical, text))


def main():
    cases = sources(sys.argv[1:])
    expected = oracle.run([], {}, DUMP % json.dumps([text for _, text in cases]))[0]["value"]
    with tempfile.TemporaryDirectory() as tmp:
        files = []
        for index, (_, text) in enumerate(cases):
            file = pathlib.Path(tmp) / f"{index}.mmd"
            file.write_text(text)
            files.append(str(file))
        out = subprocess.run(["moon", "run", "--target", "native", "cmd/mermaid", "--", "state-db", *files],
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
        if "error" in got:
            bad += 1
            print(f"FAIL {name}: {got['error'][:200]!r}")
            continue
        want, got = normalize(want), normalize(got)
        if want != got:
            bad += 1
            print(f"FAIL {name}")
            for key in sorted(set(want) | set(got)):
                if want.get(key) != got.get(key):
                    a, b = json.dumps(want.get(key), sort_keys=True), json.dumps(got.get(key), sort_keys=True)
                    at = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
                    print(f"    {key}: upstream ...{a[max(0, at - 100):at + 120]}")
                    print(f"    {' ' * len(key)}  port     ...{b[max(0, at - 100):at + 120]}")
    print(f"{len(cases) - bad}/{len(cases)} state diagrams parse identically")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
