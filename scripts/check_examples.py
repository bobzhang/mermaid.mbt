#!/usr/bin/env python3
"""Compare the port with upstream on the examples of mermaid's own docs.

Collects the ```mermaid blocks of the given Markdown files (default: the
flowchart syntax page of the upstream checkout), keeps those whose first
keyword is one of `--keywords`, renders each with the oracle and with
`cmd/mermaid`, and reports the ones that differ, grouped by cause.

Shapes drawn through rough.js are random per render unless a seed is set,
so both sides get `handDrawnSeed` from `--seed`.

`--prelude` names JavaScript to evaluate in the oracle page first, for
diagrams whose output upstream leaves to `Math.random()`.

`--fresh-page` renders every example in a page of its own, for diagrams
whose output depends on what the page rendered before (see compare.py).

Usage: scripts/check_examples.py [docs.md ...] [--keywords flowchart graph]
                                 [--seed 1] [--cache DIR] [--prelude FILE]
                                 [--fresh-page] [-v]
"""

import argparse
import collections
import hashlib
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
DEFAULT_DOCS = [ROOT / ".repos" / "mermaid" / "docs" / "syntax" / "flowchart.md"]


def examples(paths, keywords):
    found = []
    pattern = re.compile(r"^\s*(%s)\b" % "|".join(map(re.escape, keywords)), re.M)
    for path in paths:
        text = pathlib.Path(path).read_text()
        for block in re.findall(r"```mermaid(?:-example)?\n(.*?)```", text, re.S):
            if block not in found and pattern.search(block):
                found.append(block)
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("docs", nargs="*", type=pathlib.Path, default=DEFAULT_DOCS)
    parser.add_argument("--keywords", nargs="+", default=["flowchart", "graph"])
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--cache", type=pathlib.Path, default=ROOT / ".repos" / "oracle" / "examples")
    parser.add_argument("--prelude", type=pathlib.Path,
                        help="JavaScript evaluated in the oracle page before rendering (see compare.py)")
    parser.add_argument("--fresh-page", action="store_true",
                        help="render every example in an oracle page of its own")
    parser.add_argument("-v", "--verbose", action="store_true", help="show the first difference of each example")
    args = parser.parse_args()

    config = json.dumps({"handDrawnSeed": args.seed})
    prelude = args.prelude.read_text() if args.prelude else ""
    sources = examples(args.docs, args.keywords)
    args.cache.mkdir(parents=True, exist_ok=True)
    inputs = []
    for source in sources:
        fresh = "fresh page" if args.fresh_page else ""
        digest = hashlib.sha256((config + prelude + fresh + source).encode()).hexdigest()[:16]
        path = args.cache / f"{digest}.mmd"
        path.write_text(source)
        inputs.append(path)
    missing = [path for path in inputs if not path.with_suffix(".svg").exists()]
    size = 1 if args.fresh_page else compare.BATCH
    for start in range(0, len(missing), size):
        batch = missing[start:start + size]
        subprocess.run([sys.executable, str(ROOT / "scripts" / "oracle.py"), "--config", config,
                        "-o", str(args.cache)] + (["--eval", prelude] if prelude else [])
                       + [str(path) for path in batch], check=True, stdout=subprocess.DEVNULL)

    binary = compare.build()
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        handle.write(config)
    causes = collections.defaultdict(list)
    identical = 0
    for index, path in enumerate(inputs):
        expected = path.with_suffix(".svg").read_text()
        done = subprocess.run([str(binary), "render", str(path), "--id", compare.SVG_ID, "--config", handle.name],
                              capture_output=True, text=True)
        actual = done.stdout.removesuffix("\n")
        if actual == expected:
            identical += 1
        elif not expected.startswith("<svg"):
            # Upstream rejects the example; the port should too.
            if actual.startswith("<svg"):
                causes["upstream fails, the port renders"].append(index)
            else:
                identical += 1
        elif not actual.startswith("<svg"):
            causes[actual.strip()[:100]].append(index)
        else:
            at = compare.first_difference(actual, expected)
            causes["output differs"].append(index)
            if args.verbose:
                print(f"example {index} ({path.name}) differs at byte {at}")
                print("    port  :", repr(actual[max(0, at - 80):at + 80]))
                print("    oracle:", repr(expected[max(0, at - 80):at + 80]))
    for cause, indexes in sorted(causes.items(), key=lambda item: -len(item[1])):
        print(f"{len(indexes):3}  {cause}  (examples {', '.join(map(str, indexes[:8]))}{'…' if len(indexes) > 8 else ''})")
    print(f"{identical}/{len(inputs)} examples identical")
    return 0 if identical == len(inputs) else 1


if __name__ == "__main__":
    sys.exit(main())
