#!/usr/bin/env python3
"""Compare the port of dagre with dagre itself on a corpus of graphs.

Every graph of the given JSON files (default: `testdata/dagre/*.json`, see
scripts/dagre_corpus.py) is laid out by scripts/dagre_oracle.js, which runs
the dagre of the mermaid bundle under node, and by `cmd/mermaid dagre`. The
two results must be the same JSON: every coordinate the same double.

Usage: scripts/check_dagre.py [graphs.json ...] [-v]
"""

import argparse
import json
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import compare  # noqa: E402

ROOT = compare.ROOT


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("files", nargs="*", type=pathlib.Path)
    parser.add_argument("-v", "--verbose", action="store_true", help="show the first difference of each graph")
    args = parser.parse_args()
    files = args.files or sorted((ROOT / "testdata" / "dagre").glob("*.json"))
    binary = compare.build()
    identical = total = 0
    for file in files:
        # One process a file on both sides: the names dagre gives its dummy
        # nodes count up for as long as the process lives.
        expected = subprocess.run(["node", str(ROOT / "scripts" / "dagre_oracle.js"), str(file)],
                                  capture_output=True, text=True, check=True).stdout.splitlines()
        actual = subprocess.run([str(binary), "dagre", str(file)], capture_output=True, text=True).stdout.splitlines()
        graphs = json.loads(file.read_text())
        count = len(graphs) if isinstance(graphs, list) else 1
        failed = []
        for index in range(count):
            total += 1
            want = json.loads(expected[index]) if index < len(expected) else None
            try:
                got = json.loads(actual[index]) if index < len(actual) else None
            except json.JSONDecodeError:
                got = None
            # A graph dagre throws on has to fail in the port as well; the
            # messages are JavaScript's and are not compared.
            if want is not None and "error" in want:
                same = got is not None and "error" in got
            else:
                same = want == got
            if same:
                identical += 1
                continue
            failed.append(index)
            if args.verbose:
                print(f"{file.name}[{index}] differs")
                print("    port  :", (actual[index] if index < len(actual) else "nothing")[:300])
                print("    dagre :", (expected[index] if index < len(expected) else "nothing")[:300])
        if failed:
            shown = ", ".join(map(str, failed[:12])) + ("…" if len(failed) > 12 else "")
            print(f"{file.name}: {len(failed)} of {count} graphs differ ({shown})")
    print(f"{identical}/{total} graphs identical")
    return 0 if identical == total else 1


if __name__ == "__main__":
    sys.exit(main())
