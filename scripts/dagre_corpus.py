#!/usr/bin/env python3
"""Build the corpus of graphs `internal/dagre` is checked against.

Three sources, each written as one JSON array of graphs in the format
scripts/dagre_oracle.js reads:

    capture   the graphs mermaid hands to dagre while it renders diagrams
              in the oracle page (scripts/dagre_capture.js): the examples
              of documentation pages, or diagram files, with `layout: dagre`
              forced through the site configuration
    flowcharts
              the same for generated flowcharts: subgraphs, self loops,
              labels, the four directions, parallel edges
    synthetic graphs generated here, with no browser involved, that use
              what mermaid never asks of dagre as well (label positions,
              the greedy acyclicer, the other rankers, alignments)

Usage:
    scripts/dagre_corpus.py capture OUT.json --docs PAGE.md --keywords flowchart graph
    scripts/dagre_corpus.py capture OUT.json a.mmd b.mmd
    scripts/dagre_corpus.py flowcharts OUT.json --count 200 --seed 1
    scripts/dagre_corpus.py synthetic OUT.json --count 300 --seed 1
"""

import argparse
import json
import pathlib
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_examples  # noqa: E402
import compare  # noqa: E402
import oracle  # noqa: E402

CAPTURE = pathlib.Path(__file__).resolve().parent / "dagre_capture.js"
MARK = "DAGRE_GRAPH"


def capture(sources, config):
    """Render diagram texts with the oracle and return the graphs dagre saw."""
    graphs = []
    expression = CAPTURE.read_text()
    for start in range(0, len(sources), compare.BATCH):
        jobs = [{"id": compare.SVG_ID, "text": text} for text in sources[start:start + compare.BATCH]]
        results = oracle.run(jobs, config, expression)
        probe = results[0].get("value")
        if probe != "capturing dagre graphs":
            sys.exit(f"the capture script failed: {results[0]}")
        for result in results[1:]:
            for line in result.get("console", []):
                if line and line[0] == MARK:
                    graphs.append(json.loads(line[1]))
    return graphs


SHAPES = ["{id}", "{id}[{text}]", "{id}({text})", "{id}{{{text}}}", "{id}(({text}))", "{id}[/{text}/]",
          "{id}([{text}])", "{id}[[{text}]]", "{id}>{text}]", "{id}{{{{{text}}}}}"]
WORDS = ["Start", "Check the input", "Yes", "No", "Go shopping", "A", "Something much longer than the rest",
         "Laptop", "fa:fa-car Car", "Decide", "End", "x", "One two three", "Result"]
ARROWS = ["-->", "---", "-.->", "==>", "--->", "---->", "--o", "--x", "<-->", "-.-", "==="]


def flowchart(rng):
    """A random flowchart: nodes in nested subgraphs, edges of every kind."""
    direction = rng.choice(["TB", "TD", "BT", "LR", "RL"])
    lines = [f"flowchart {direction}"]
    count = rng.randint(2, 12)
    numeric = rng.random() < 0.15
    ids = [str(i + 1) if numeric else f"n{i}" for i in range(count)]
    declared = set()

    def node(index):
        name = ids[index]
        if name in declared or rng.random() < 0.3:
            return name
        declared.add(name)
        return rng.choice(SHAPES).format(id=name, text=rng.choice(WORDS))

    # Subgraphs take consecutive runs of nodes; some nest.
    groups = []
    if count >= 3 and rng.random() < 0.6:
        position = 0
        while position < count and len(groups) < 4:
            if rng.random() < 0.5:
                size = rng.randint(1, min(4, count - position))
                groups.append((f"sg{len(groups)}", list(range(position, position + size))))
                position += size
            else:
                position += rng.randint(1, 3)
    nested = len(groups) >= 2 and rng.random() < 0.4
    indent = "  "
    for index, (name, members) in enumerate(groups):
        if nested and index == 1:
            continue
        title = rng.choice(["", " [Group]", " [A longer group title]"])
        lines.append(f"{indent}subgraph {name}{title}")
        if rng.random() < 0.3:
            lines.append(f"{indent}  direction {rng.choice(['TB', 'BT', 'LR', 'RL'])}")
        for member in members:
            lines.append(f"{indent}  {node(member)}")
        for _ in range(rng.randint(0, len(members))):
            a, b = rng.choice(members), rng.choice(members)
            lines.append(f"{indent}  {ids[a]} {rng.choice(ARROWS)} {ids[b]}")
        if nested and index == 0:
            inner, inner_members = groups[1]
            lines.append(f"{indent}  subgraph {inner}")
            for member in inner_members:
                lines.append(f"{indent}    {node(member)}")
            lines.append(f"{indent}  end")
        lines.append(f"{indent}end")
    ends = ids + [name for name, _ in groups]
    for _ in range(rng.randint(1, count + 3)):
        kind = rng.random()
        a = rng.randrange(count)
        if kind < 0.08:
            # A self loop, with or without a label.
            label = rng.choice(["", "|again|"])
            lines.append(f"{indent}{node(a)} -->{label} {ids[a]}")
            continue
        b = rng.randrange(count)
        arrow = rng.choice(ARROWS)
        label = f"|{rng.choice(WORDS)}|" if rng.random() < 0.3 else ""
        if kind < 0.2 and groups:
            # An edge that starts or ends at a subgraph.
            source, target = rng.choice(ends), rng.choice(ends)
            lines.append(f"{indent}{source} {arrow}{label} {target}")
        else:
            lines.append(f"{indent}{node(a)} {arrow}{label} {node(b)}")
        if kind > 0.92:
            # The same edge once more.
            lines.append(f"{indent}{ids[a]} {arrow} {ids[b]}")
    return "\n".join(lines) + "\n"


def synthetic(rng):
    """A random compound multigraph with every attribute dagre reads."""
    count = rng.randint(1, 14)
    numeric = rng.random() < 0.2
    ids = [str(rng.randint(0, 30)) if numeric else f"v{i}" for i in range(count)]
    ids = list(dict.fromkeys(ids))
    count = len(ids)
    graph = {"rankdir": rng.choice(["TB", "BT", "LR", "RL", "TB", "LR"])}
    for key, values in (("nodesep", [50, 50, 30, 75.5]), ("ranksep", [50, 50, 75, 25]),
                        ("edgesep", [20, 10]), ("marginx", [8, 0, 20]), ("marginy", [8, 0, 20])):
        if rng.random() < 0.8:
            graph[key] = rng.choice(values)
    if rng.random() < 0.15:
        graph["acyclicer"] = "greedy"
    if rng.random() < 0.15:
        graph["ranker"] = rng.choice(["tight-tree", "longest-path", "network-simplex"])
    if rng.random() < 0.15:
        graph["align"] = rng.choice(["UL", "UR", "DL", "DR"])
    nodes = [{"id": name, "width": rng.choice([10, 40, 80.5, 152, 171, 23.84375, 0.1]),
              "height": rng.choice([10, 21, 45, 171, 63.5, 0.1])} for name in ids]
    # Compound nodes hold runs of the others, one level or two deep.
    clusters = []
    if count >= 3 and rng.random() < 0.6:
        for index in range(rng.randint(1, 3)):
            name = f"c{index}"
            members = rng.sample(ids, rng.randint(1, max(1, count // 2)))
            clusters.append(name)
            nodes.insert(rng.randint(0, len(nodes)), {"id": name})
            for node in nodes:
                if node["id"] in members and "parent" not in node:
                    node["parent"] = name
        if len(clusters) >= 2 and rng.random() < 0.5:
            for node in nodes:
                if node["id"] == clusters[1]:
                    node["parent"] = clusters[0]
        # A compound node without a child is a node like any other.
        parents = {node.get("parent") for node in nodes}
        for node in nodes:
            if node["id"] in clusters and node["id"] not in parents:
                node["width"], node["height"] = 60, 40
    leaves = [node["id"] for node in nodes if "width" in node]
    edges = []
    names = set()
    for index in range(rng.randint(0, 2 * count + 1)):
        v, w = rng.choice(leaves), rng.choice(leaves)
        if rng.random() > 0.1 and v == w:
            w = rng.choice(leaves)
        edge = {"v": v, "w": w}
        if rng.random() < 0.9:
            edge["name"] = f"e{index}"
        key = (v, w, edge.get("name"))
        if key in names:
            continue
        names.add(key)
        if rng.random() < 0.5:
            edge["minlen"] = rng.choice([1, 1, 2, 3])
        if rng.random() < 0.2:
            edge["weight"] = rng.choice([1, 2, 5])
        if rng.random() < 0.4:
            edge["width"] = rng.choice([22.84375, 60, 104.5])
            edge["height"] = rng.choice([21, 42])
        if rng.random() < 0.6:
            edge["labelpos"] = rng.choice(["c", "c", "l", "r"])
        if rng.random() < 0.1:
            edge["labeloffset"] = rng.choice([0, 5, 10])
        edges.append(edge)
    return {"graph": graph, "nodes": nodes, "edges": edges}


def write(path, graphs):
    with path.open("w") as handle:
        handle.write("[\n")
        handle.write(",\n".join(json.dumps(graph, ensure_ascii=False, separators=(",", ":")) for graph in graphs))
        handle.write("\n]\n")
    print(f"{len(graphs)} graphs in {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", choices=["capture", "flowcharts", "synthetic"])
    parser.add_argument("out", type=pathlib.Path)
    parser.add_argument("inputs", nargs="*", type=pathlib.Path, help="diagram files to capture")
    parser.add_argument("--docs", nargs="*", type=pathlib.Path, default=[], help="documentation pages to capture")
    parser.add_argument("--keywords", nargs="+", default=["flowchart", "graph"])
    parser.add_argument("--config", default='{"layout":"dagre"}', help="site configuration of the captured renders")
    parser.add_argument("--count", type=int, default=200)
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    if args.source == "synthetic":
        graphs = [synthetic(rng) for _ in range(args.count)]
    else:
        if args.source == "flowcharts":
            sources = [flowchart(rng) for _ in range(args.count)]
        else:
            sources = [path.read_text() for path in args.inputs]
            sources += check_examples.examples(args.docs, args.keywords)
        graphs = capture(sources, json.loads(args.config))
    write(args.out, graphs)


if __name__ == "__main__":
    main()
