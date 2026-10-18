#!/usr/bin/env python3
"""Check the port's CSSOM (`internal/css/cssom*.mbt`) against Chrome.

Every style sheet of `scripts/cssom_corpus.txt` (one JSON string per line)
is given to `new CSSStyleSheet().replaceSync()` in the oracle's Chrome, and
the `cssText` of its rules compared with what `cmd/mermaid cssom` prints.
A style sheet the port declines (`unported: ...`) is listed apart; one it
serializes differently is a failure.

Usage: python3 scripts/check_cssom.py [-v] [corpus.txt]
"""

import argparse
import json
import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import compare  # noqa: E402
import oracle  # noqa: E402

ROOT = compare.ROOT
CORPUS = ROOT / "scripts" / "cssom_corpus.txt"

PROBE = """(() => {
  const out = [];
  for (const text of %s) {
    const sheet = new CSSStyleSheet();
    sheet.replaceSync(text);
    out.push([...sheet.cssRules].map((rule) => rule.cssText));
  }
  return out;
})()"""


def read_corpus(path):
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip() and not line.startswith("#")]


def chrome(sheets):
    return oracle.run([], {}, PROBE % json.dumps(sheets))[0]["value"]


def port(sheets):
    binary = compare.build()
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump(sheets, handle)
    done = subprocess.run([str(binary), "cssom", handle.name], capture_output=True, text=True, check=True)
    return json.loads(done.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("corpus", nargs="?", type=pathlib.Path, default=CORPUS)
    parser.add_argument("-v", "--verbose", action="store_true", help="list the style sheets the port declines")
    args = parser.parse_args()
    sheets = read_corpus(args.corpus)
    expected = chrome(sheets)
    actual = port(sheets)
    differ = unported = 0
    for sheet, want, got in zip(sheets, expected, actual):
        if isinstance(got, str):
            unported += 1
            if args.verbose:
                print(f"{got}: {json.dumps(sheet)}\n    Chrome: {json.dumps(want)}")
        elif got != want:
            differ += 1
            print(f"differs: {json.dumps(sheet)}\n    port  : {json.dumps(got)}\n    Chrome: {json.dumps(want)}")
    print(f"{len(sheets) - differ - unported}/{len(sheets)} style sheets serialized as Chrome does, "
          f"{unported} unported")
    return 1 if differ else 0


if __name__ == "__main__":
    sys.exit(main())
