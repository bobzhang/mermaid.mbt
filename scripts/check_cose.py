#!/usr/bin/env python3
"""Compare the port of cose-bilkent (`internal/cose`) with upstream.

Every `*.json` graph in the given directories (the format of
scripts/cose_oracle.js) is laid out by the port (`mermaid cose`) and by the
libraries cut out of the mermaid bundle (scripts/cose_oracle.js), run in the
oracle's Chrome; the positions must be the same doubles. A graph captured
from mermaid itself by scripts/cose_corpus.py also carries what cytoscape
computed in the page: both layouts are checked against it, and the port's
edge points against cytoscape's.

Usage:
    scripts/check_cose.py DIR...               # compare
    scripts/check_cose.py --generate N DIR     # write N random trees first
        [--seed S] [--max-nodes M]
    scripts/check_cose.py --node DIR...        # reference under node: faster,
                                               # but node's Math.cos and Math.sin
                                               # are not Chrome's in the last bit

Build the CLI first: moon build --target native cmd/mermaid
"""

import argparse
import json
import pathlib
import random
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


def random_tree(rng, count):
    """A tree of `count` nodes with sizes like those of mindmap nodes."""
    shape = rng.choice(["random", "random", "path", "star", "wide", "deep", "binary"])
    widths = [rng.choice([34, 58, 82]) + 0.0 for _ in range(3)]
    nodes = []
    for index in range(count):
        kind = rng.random()
        if kind < 0.15:
            # A circle: the float32 diameter `getBBox` reports.
            import struct

            size = struct.unpack("f", struct.pack("f", rng.uniform(40, 160)))[0]
            width, height = size, size
        elif kind < 0.3:
            # Several nodes of one size make ties and exact slopes.
            width, height = 100.0, 34.0
        elif kind < 0.9:
            # A label measured in 64ths of a pixel plus padding.
            width = 40 + rng.randrange(0, 200 * 64) / 64
            height = rng.choice(widths)
        else:
            width, height = rng.uniform(20, 400), rng.uniform(20, 200)
        nodes.append({"id": str(index), "width": width, "height": height})
    edges = []
    for index in range(1, count):
        if shape == "path":
            parent = index - 1
        elif shape == "star":
            parent = 0
        elif shape == "wide":
            parent = rng.randrange(0, max(1, index // 4 + 1))
        elif shape == "deep":
            parent = rng.randrange(max(0, index - 3), index)
        elif shape == "binary":
            parent = (index - 1) // 2
        else:
            parent = rng.randrange(0, index)
        edges.append({"id": f"edge_{parent}_{index}", "source": str(parent), "target": str(index)})
    if shape != "binary" and rng.random() < 0.5:
        # Mindmaps list a subtree right after its root.
        children = {}
        for edge in edges:
            children.setdefault(edge["source"], []).append(edge)
        ordered = []

        def walk(node):
            for edge in children.get(node, []):
                ordered.append(edge)
                walk(edge["target"])

        sys.setrecursionlimit(10000)
        walk("0")
        edges = ordered
    return {"nodes": nodes, "edges": edges}


def generate(directory, count, seed, max_nodes):
    rng = random.Random(seed)
    directory.mkdir(parents=True, exist_ok=True)
    for index in range(count):
        size = index + 1 if index < 60 else rng.randrange(1, max_nodes + 1)
        graph = random_tree(rng, min(size, max_nodes))
        (directory / f"tree-{seed}-{index:04d}.json").write_text(json.dumps(graph) + "\n")


def lines(command, paths):
    """One JSON document per path from `command`, or the error text."""
    out = []
    for start in range(0, len(paths), 200):
        batch = [str(path) for path in paths[start : start + 200]]
        done = subprocess.run(command + batch, capture_output=True, text=True)
        if done.returncode != 0:
            sys.exit(f"{' '.join(command)} failed:\n{done.stdout[-2000:]}{done.stderr[-2000:]}")
        out.extend(json.loads(line) for line in done.stdout.splitlines())
    return out


def in_chrome(paths):
    """The layouts of scripts/cose_oracle.js evaluated in the oracle's page."""
    out = []
    for start in range(0, len(paths), 100):
        batch = [str(path) for path in paths[start : start + 100]]
        expression = subprocess.run(
            ["node", str(ROOT / "scripts" / "cose_oracle.js"), "--expression"] + batch,
            capture_output=True, text=True, check=True,
        ).stdout
        result = oracle.run_page([], {}, expression)[0]
        if "value" not in result:
            sys.exit(f"cose_oracle.js failed in Chrome: {result}")
        out.extend(result["value"])
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("directories", nargs="+", type=pathlib.Path)
    parser.add_argument("--generate", type=int, metavar="N", help="write N random trees into the directory first")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--max-nodes", type=int, default=120)
    parser.add_argument("--node", action="store_true", help="run the reference under node instead of Chrome")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()
    if args.generate:
        generate(args.directories[0], args.generate, args.seed, args.max_nodes)
    paths = sorted(path for directory in args.directories for path in directory.glob("*.json"))
    if not paths:
        sys.exit("no graphs")
    if args.node:
        reference = lines(["node", str(ROOT / "scripts" / "cose_oracle.js")], paths)
    else:
        reference = in_chrome(paths)
    port = lines([str(binary()), "cose"], paths)
    identical = 0
    for path, upstream, mine in zip(paths, reference, port):
        graph = json.loads(path.read_text())
        problems = []
        if mine["nodes"] != upstream["nodes"]:
            wrong = sum(a != b for a, b in zip(mine["nodes"], upstream["nodes"]))
            problems.append(f"{wrong}/{len(upstream['nodes'])} positions differ from upstream")
        expected = graph.get("expected")
        if expected:
            if upstream["nodes"] != expected["nodes"]:
                problems.append("cose_oracle.js differs from Chrome")
            if mine["nodes"] != expected["nodes"]:
                problems.append("positions differ from Chrome")
            if mine["edges"] != expected["edges"]:
                wrong = sum(a != b for a, b in zip(mine["edges"], expected["edges"]))
                problems.append(f"{wrong}/{len(expected['edges'])} edges differ from Chrome")
        if problems:
            print(f"{path.name}: {'; '.join(problems)}")
            if args.verbose:
                for a, b in zip(mine["nodes"], upstream["nodes"]):
                    if a != b:
                        print("   mine    ", a)
                        print("   upstream", b)
                        break
        else:
            identical += 1
    print(f"{identical}/{len(paths)} graphs identical")
    sys.exit(0 if identical == len(paths) else 1)


if __name__ == "__main__":
    main()
