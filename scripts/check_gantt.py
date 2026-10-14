#!/usr/bin/env python3
"""Compare the port's Gantt charts with upstream's on random charts.

Charts from `scripts/gantt_corpus.py` — date formats, durations,
dependencies, excluded days, tags, tick intervals, themes, configuration —
are rendered by the oracle and by `cmd/mermaid`, both with the clock
stopped at `--now` so that the today marker and everything else that
reads the clock agree. Differences are reported with their first
diverging position.

Usage: python3 scripts/check_gantt.py [--count N] [--seed S] [--now MS] [-v]
"""

import argparse
import pathlib
import random
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import compare  # noqa: E402
import gantt_corpus  # noqa: E402
import oracle  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--count", type=int, default=200)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--now", type=int, default=1700000000000)
    parser.add_argument("-v", "--verbose", action="store_true", help="show the source of each differing chart")
    args = parser.parse_args()
    rng = random.Random(args.seed)
    charts = [gantt_corpus.chart(rng, index, rich=True) for index in range(args.count)]
    expected = []
    for start in range(0, len(charts), compare.BATCH):
        jobs = [{"id": compare.SVG_ID, "text": text} for text in charts[start:start + compare.BATCH]]
        expected += oracle.run(jobs, {}, None, args.now)
    binary = compare.build()
    failures = 0
    errors = 0
    with tempfile.TemporaryDirectory() as tmp:
        for index, (text, want) in enumerate(zip(charts, expected)):
            path = pathlib.Path(tmp) / "chart.mmd"
            path.write_text(text)
            done = subprocess.run([str(binary), "render", str(path), "--id", compare.SVG_ID, "--now", str(args.now)],
                                  capture_output=True, text=True)
            got = done.stdout.removesuffix("\n")
            if "svg" not in want:
                errors += 1
                if got.startswith("<svg"):
                    failures += 1
                    print(f"chart {index}: upstream fails ({want['error'][:80]!r}), the port renders")
                continue
            if got == want["svg"]:
                continue
            failures += 1
            if not got.startswith("<svg"):
                print(f"chart {index}: the port fails: {got.strip()[:120]}")
            else:
                at = compare.first_difference(got, want["svg"])
                print(f"chart {index}: differs at byte {at}")
                print("    port  :", repr(got[max(0, at - 80):at + 100]))
                print("    oracle:", repr(want["svg"][max(0, at - 80):at + 100]))
            if args.verbose:
                print(text)
    print(f"{len(charts) - failures}/{len(charts)} charts identical ({errors} rejected by upstream)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
