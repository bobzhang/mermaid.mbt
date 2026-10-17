#!/usr/bin/env python3
"""Compare the port's architecture layout with upstream's cytoscape-fcose.

Every given `.mmd` architecture diagram is laid out by upstream's code cut
out of the bundle (scripts/fcose_oracle.js, evaluated in the oracle's
Chrome) and by the port (`mermaid architecture-layout`). Both report what
the renderer reads from cytoscape: node positions, group boxes, edge
endpoints and midpoints; they must be the same doubles. With `--trace`,
the first run of fcose that differs is shown step by step: the graph it
starts from, the positions once the constraints are enforced, and after
every iteration.

Usage:
    scripts/check_fcose.py file.mmd|directory ...      # compare
    scripts/check_fcose.py --reference file.mmd        # print upstream's JSON
    scripts/check_fcose.py --trace file.mmd            # find the first step that differs

Build the CLI first: moon build --target native cmd/mermaid
"""

import argparse
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import oracle  # noqa: E402


def binary():
    found = [path for path in (ROOT / "_build" / "native").rglob("mermaid.exe") if "dSYM" not in str(path)]
    if not found:
        sys.exit("build the CLI first: moon build --target native cmd/mermaid")
    return max(found, key=lambda path: path.stat().st_mtime)


def reference(paths, trace=False):
    """Upstream's layouts, evaluated in the oracle's page."""
    out = []
    for start in range(0, len(paths), 50):
        batch = [str(path) for path in paths[start : start + 50]]
        command = ["node", str(ROOT / "scripts" / "fcose_oracle.js")] + (["--trace"] if trace else []) + batch
        expression = subprocess.run(command, capture_output=True, text=True, check=True).stdout
        result = oracle.run_page([], {}, expression)[0]
        if "value" not in result:
            sys.exit(f"fcose_oracle.js failed in Chrome: {result}")
        out.extend(result["value"])
    return out


def port(paths, trace=False):
    out = []
    for path in paths:
        command = [str(binary()), "architecture-layout"] + (["--trace"] if trace else []) + [str(path)]
        done = subprocess.run(command, capture_output=True, text=True)
        if done.returncode != 0:
            out.append({"error": (done.stdout + done.stderr).strip()})
        else:
            out.append(json.loads(done.stdout))
    return out


def collect(paths):
    files = []
    for path in map(pathlib.Path, paths):
        files.extend(sorted(path.rglob("*.mmd")) if path.is_dir() else [path])
    return files


def first_difference(a, b, where=""):
    """The path to the first value that differs between two JSON values."""
    if isinstance(a, dict) and isinstance(b, dict):
        for key in list(a) + [k for k in b if k not in a]:
            if key not in a or key not in b:
                return f"{where}.{key}", a.get(key), b.get(key)
            found = first_difference(a[key], b[key], f"{where}.{key}")
            if found:
                return found
        return None
    if isinstance(a, list) and isinstance(b, list):
        for index, (x, y) in enumerate(zip(a, b)):
            found = first_difference(x, y, f"{where}[{index}]")
            if found:
                return found
        if len(a) != len(b):
            return f"{where}.length", len(a), len(b)
        return None
    return None if a == b else (where, a, b)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="+")
    parser.add_argument("--reference", action="store_true", help="print upstream's result")
    parser.add_argument("--trace", action="store_true", help="compare run by run, step by step")
    args = parser.parse_args()
    paths = collect(args.paths)
    upstream = reference(paths, args.trace)
    if args.reference:
        for path, result in zip(paths, upstream):
            print(json.dumps({"file": str(path), **result}))
        return
    mine = port(paths, args.trace)
    identical = 0
    for path, theirs, ours in zip(paths, upstream, mine):
        if "error" in theirs or "error" in ours:
            if "error" in theirs and "error" in ours:
                identical += 1
                continue
            print(f"{path}: upstream {theirs.get('error', 'renders')}; port {ours.get('error', 'renders')}")
            continue
        keys = ["runs", "nodes", "edges"] if args.trace else ["nodes", "edges"]
        found = first_difference({k: ours.get(k) for k in keys}, {k: theirs.get(k) for k in keys})
        if found:
            where, a, b = found
            print(f"{path}: {where}: port {json.dumps(a)[:300]} upstream {json.dumps(b)[:300]}")
        else:
            identical += 1
    print(f"{identical}/{len(paths)} layouts identical")
    sys.exit(0 if identical == len(paths) else 1)


if __name__ == "__main__":
    main()
