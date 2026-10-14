#!/usr/bin/env python3
"""Capture what mermaid hands to cose-bilkent in Chrome, and what comes back.

Each diagram (a mindmap, or anything else laid out by `cose-bilkent`) is
rendered by the oracle with debug logging; the sizes of the nodes, the
positions the layout gave them and the end points cytoscape gave the edges
are read from the log and written as one JSON graph per diagram:

    {"nodes": [{"id", "width", "height"}],
     "edges": [{"id", "source", "target"}],
     "expected": {"nodes": [{"id", "x", "y"}],
                  "edges": [{"id", "startX", "startY", "midX", "midY", "endX", "endY"}]}}

Usage: scripts/cose_corpus.py -o DIR a.mmd b.mmd ...
"""

import argparse
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import oracle  # noqa: E402

DIMENSIONS = re.compile(r"^Node (.*) dimensions: ([^x]+)x(.+)$")
POSITIONED = re.compile(r"^Positioned node (.*) at center \(([^,]+), ([^)]+)\)$")


def number(text):
    return float(text) if text not in ("NaN", "undefined") else None


def graph_of(lines):
    """The graph in the console `lines` of one render."""
    nodes, positions, edges, expected_edges = [], [], [], []
    for line in lines:
        words = [word for word in line if isinstance(word, str)]
        for word in words:
            match = DIMENSIONS.match(word)
            if match:
                nodes.append({"id": match.group(1), "width": float(match.group(2)), "height": float(match.group(3))})
            match = POSITIONED.match(word)
            if match:
                positions.append({"id": match.group(1), "x": number(match.group(2)), "y": number(match.group(3))})
        if "APA01 positionedEdge" in words:
            edge = json.loads(line[-1]) if isinstance(line[-1], str) else line[-1]
            edges.append({"id": edge["id"], "source": edge["source"], "target": edge["target"]})
            expected_edges.append({key: edge.get(key) for key in ("id", "startX", "startY", "midX", "midY", "endX", "endY")})
    # Nodes are measured concurrently; the layout sees them in the order
    # of the diagram, which is the order they are positioned in.
    order = {node["id"]: index for index, node in enumerate(positions)}
    nodes.sort(key=lambda node: order.get(node["id"], len(order)))
    return {"nodes": nodes, "edges": edges, "expected": {"nodes": positions, "edges": expected_edges}}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("inputs", nargs="+", type=pathlib.Path)
    parser.add_argument("-o", "--out", type=pathlib.Path, required=True)
    parser.add_argument("--config", default="{}", help="JSON passed to mermaid.initialize")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    config = dict(json.loads(args.config), logLevel="debug")
    # One page per diagram: the layout's state must not depend on what was
    # laid out before.
    for path in args.inputs:
        result = oracle.run_page([{"id": "mermaid-svg", "text": path.read_text()}], config)[0]
        if "error" in result:
            print(f"{path}: {result['error']}", file=sys.stderr)
            continue
        (args.out / (path.stem + ".json")).write_text(json.dumps(graph_of(result["console"])) + "\n")


if __name__ == "__main__":
    main()
