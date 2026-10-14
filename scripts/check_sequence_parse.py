#!/usr/bin/env python3
"""Compare the port's sequence diagram parser with mermaid's.

Takes sequence diagram sources from the given `.mmd` files and from the
```mermaid blocks of the given Markdown files, parses each with upstream
(through the oracle page) and with `cmd/mermaid sequence-db`, and reports
every database that differs.

Upstream is asked through `getDiagramFromText`, which does not apply a
diagram's own configuration: a diagram that turns on `wrap` in its
frontmatter or directives is reported as differing in `wrap` only.

Usage: scripts/check_sequence_parse.py [file.mmd | docs.md | directory] ...
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

DUMP = """(async () => {
  const sources = %s;
  const plain = (value) => JSON.parse(JSON.stringify(value));
  const out = [];
  for (const source of sources) {
    try {
      const diagram = await mermaid.mermaidAPI.getDiagramFromText(source);
      const db = diagram.db;
      const actors = [...db.getActors().entries()].map(([id, actor]) => ({
        id,
        name: actor.name,
        description: actor.description,
        wrap: actor.wrap,
        prevActor: actor.prevActor ?? null,
        nextActor: actor.nextActor ?? null,
        type: actor.type,
        box: actor.box ? actor.box.name ?? '' : null,
        links: actor.links,
        properties: actor.properties,
      }));
      const messages = db.getMessages().map((message) => {
        const entry = {
          id: message.id,
          from: message.from ?? null,
          to: message.to ?? null,
          wrap: message.wrap,
          type: message.type,
          message: message.message,
        };
        if (message.placement !== undefined) {
          entry.placement = message.placement;
        } else if (message.type !== db.LINETYPE.AUTONUMBER) {
          entry.activate = message.activate;
          entry.centralConnection = message.centralConnection;
        } else {
          entry.message = {
            start: message.message.start ?? null,
            step: message.message.step ?? null,
            visible: message.message.visible,
          };
        }
        return entry;
      });
      out.push(plain({
        actors,
        messages,
        boxes: db.getBoxes().map((box) => ({
          name: box.name ?? null, wrap: box.wrap, fill: box.fill, actorKeys: box.actorKeys,
        })),
        createdActors: Object.fromEntries(db.getCreatedActors()),
        destroyedActors: Object.fromEntries(db.getDestroyedActors()),
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
                    if re.match(r"\s*(---.*?---\s*)?(%%\{.*?\}%%\s*)?sequenceDiagram\b", block, re.S):
                        found.append((f"{file.name}#{index}", block))
            else:
                found.append((file.name, text))
    return found


def main():
    cases = sources(sys.argv[1:])
    expected = oracle.run([], {}, DUMP % json.dumps([text for _, text in cases]))[0]["value"]
    binary = compare.build()
    with tempfile.TemporaryDirectory() as tmp:
        files = []
        for index, (_, text) in enumerate(cases):
            file = pathlib.Path(tmp) / f"{index}.mmd"
            file.write_text(text)
            files.append(str(file))
        out = subprocess.run([str(binary), "sequence-db", *files], capture_output=True, text=True)
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
    print(f"{len(cases) - bad}/{len(cases)} sequence diagrams parse identically")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
