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

Diagrams that show the present (the today marker of a Gantt chart) need
both sides to agree on what time it is: `--now` stops both clocks.

Usage: scripts/check_examples.py [docs.md ...] [--keywords flowchart graph]
                                 [--seed 1] [--now MS] [--cache DIR]
                                 [--prelude FILE] [-v]
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
    parser.add_argument("--now", type=int, help="the clock of both sides, in milliseconds since the epoch")
    parser.add_argument("--cache", type=pathlib.Path, default=ROOT / ".repos" / "oracle" / "examples")
    parser.add_argument("--prelude", type=pathlib.Path,
                        help="JavaScript evaluated in the oracle page before rendering (see compare.py)")
    parser.add_argument("-v", "--verbose", action="store_true", help="show the first difference of each example")
    args = parser.parse_args()

    config = json.dumps({"handDrawnSeed": args.seed})
    prelude = args.prelude.read_text() if args.prelude else ""
    sources = examples(args.docs, args.keywords)
    args.cache.mkdir(parents=True, exist_ok=True)
    inputs = []
    for source in sources:
        clock = "" if args.now is None else f"now={args.now}"
        digest = hashlib.sha256((config + clock + prelude + source).encode()).hexdigest()[:16]
        path = args.cache / f"{digest}.mmd"
        path.write_text(source)
        inputs.append(path)
    missing = [path for path in inputs if not path.with_suffix(".svg").exists()]
    for start in range(0, len(missing), compare.BATCH):
        batch = missing[start:start + compare.BATCH]
        clock = [] if args.now is None else ["--now", str(args.now)]
        # A diagram upstream rejects makes the oracle exit with an error
        # after rendering the others; its place is taken by the message.
        done = subprocess.run([sys.executable, str(ROOT / "scripts" / "oracle.py"), "--config", config,
                               "-o", str(args.cache)] + clock + (["--eval", prelude] if prelude else [])
                              + [str(path) for path in batch], capture_output=True, text=True)
        for path in batch:
            if not path.with_suffix(".svg").exists():
                errors = [line for line in done.stderr.splitlines() if line.startswith(f"{path}:")]
                if not errors:
                    sys.exit(done.stderr or f"the oracle rendered nothing for {path}")
                path.with_suffix(".svg").write_text("error: " + errors[0] + "\n")

    binary = compare.build()
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        handle.write(config)
    causes = collections.defaultdict(list)
    identical = 0
    for index, path in enumerate(inputs):
        expected = path.with_suffix(".svg").read_text()
        clock = [] if args.now is None else ["--now", str(args.now)]
        done = subprocess.run([str(binary), "render", str(path), "--id", compare.SVG_ID, "--config", handle.name] + clock,
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
