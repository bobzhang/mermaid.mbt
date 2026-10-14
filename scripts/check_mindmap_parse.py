#!/usr/bin/env python3
"""Compare the port's mindmap parser with mermaid's.

Takes mindmap sources from the given `.mmd` files and from the ```mermaid
blocks of the given Markdown files, parses each with upstream (through the
oracle page) and with `cmd/mermaid mindmap-db`, and reports every tree of
nodes that differs.

Usage: scripts/check_mindmap_parse.py [file.mmd | docs.md | directory] ...
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
      out.push(JSON.parse(JSON.stringify(diagram.db.getMindmap())));
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
                    if re.match(r"\s*(---.*?---\s*)?(%%\{.*?\}%%\s*)?mindmap\b", block, re.S):
                        found.append((f"{file.name}#{index}", block))
            else:
                found.append((file.name, text))
    return found


def main():
    cases = sources(sys.argv[1:])
    expected = oracle.run([], {}, DUMP % json.dumps([text for _, text in cases]))[0]["value"]
    binary = max((path for path in (ROOT / "_build" / "native").rglob("mermaid.exe") if "dSYM" not in str(path)),
                 key=lambda path: path.stat().st_mtime)
    with tempfile.TemporaryDirectory() as tmp:
        files = []
        for index, (_, text) in enumerate(cases):
            file = pathlib.Path(tmp) / f"{index}.mmd"
            file.write_text(text)
            files.append(str(file))
        out = subprocess.run([str(binary), "mindmap-db", *files], capture_output=True, text=True)
    actual = [json.loads(line) for line in out.stdout.splitlines() if line.strip()]
    if len(actual) != len(cases):
        sys.exit(out.stdout[-2000:] + out.stderr[-2000:])
    bad = 0
    for (name, text), want, got in zip(cases, expected, actual):
        want_error = isinstance(want, dict) and "error" in want and "nodeId" not in want
        got_error = isinstance(got, dict) and "error" in got and "nodeId" not in got
        if want_error or got_error:
            if want_error != got_error:
                bad += 1
                print(f"FAIL {name}: upstream {want.get('error') if want_error else 'accepts'!r:.80}, "
                      f"port {got.get('error') if got_error else 'accepts'!r:.80}")
            continue
        if want != got:
            bad += 1
            a, b = json.dumps(want, sort_keys=True), json.dumps(got, sort_keys=True)
            at = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
            print(f"FAIL {name}\n    upstream ...{a[max(0, at - 80):at + 80]}\n    port     ...{b[max(0, at - 80):at + 80]}")
    print(f"{len(cases) - bad}/{len(cases)} mindmaps parse identically")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
