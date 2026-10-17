#!/usr/bin/env python3
"""Capture what upstream's swimlane layout is given, for the layout harness.

For every diagram, the oracle page renders it with mermaid's debug log on and
with `globalThis.mermaidCaptureSizes` set: the flowchart renderer logs the
layout data before rendering ("REF1:"), and the swimlane layout reports the
measured size of every node (label nodes of edges included) once it has
drawn them. Together they are the input of the layout core:

    {"data": <data4Layout as logged>, "sizes": {"<node id>": [width, height]}}

A diagram upstream fails to render is written as `<name>.error.json`, with
the error, when the layout data was logged before the failure.

Usage:
    scripts/swimlane_capture.py -o DIR a.mmd b.mmd ...   # DIR/a.json, ...
"""

import argparse
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import oracle  # noqa: E402

PRELUDE = (
    "globalThis.mermaidCaptureSizes = true;"
    "Object.defineProperty(globalThis, 'mermaidLastCapturedSizes', "
    "{set(v) { console.log('SWIMLANE-SIZES', v); }, get() { return undefined; }});"
    "true"
)


def capture(paths, config=None):
    """Return one capture (or an error string) per path."""
    site = dict(config or {})
    site["logLevel"] = "debug"
    jobs = [{"id": "mermaid-svg", "text": path.read_text()} for path in paths]
    results = oracle.run(jobs, site, PRELUDE)[1:]
    captures = []
    for result in results:
        data, sizes = None, {}
        for line in result.get("console", []):
            if "REF1:" in line and isinstance(line[-1], str):
                try:
                    data = json.loads(line[-1])
                except ValueError:
                    pass
            if line and line[0] == "SWIMLANE-SIZES":
                for node in json.loads(line[1])["sizes"]["nodes"]:
                    sizes[node["id"]] = [node["width"], node["height"]]
        if "error" in result:
            # Upstream failed; what it was given is kept for reproducing it.
            captures.append({"data": data, "sizes": sizes, "error": result["error"]} if data else result["error"])
        elif data is None:
            captures.append("no layout data was logged")
        else:
            captures.append({"data": data, "sizes": sizes, "svg": result["svg"]})
    return captures


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("inputs", nargs="+", type=pathlib.Path)
    parser.add_argument("-o", "--out", type=pathlib.Path, required=True)
    parser.add_argument("--config", default="{}", help="JSON passed to mermaid.initialize")
    parser.add_argument("--svg", action="store_true", help="also write the oracle's SVG beside each capture")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    failed = False
    for path, result in zip(args.inputs, capture(args.inputs, json.loads(args.config))):
        if isinstance(result, str):
            failed = True
            print(f"{path}: {result}", file=sys.stderr)
            continue
        if "error" in result:
            failed = True
            print(f"{path}: {result['error']}", file=sys.stderr)
            (args.out / (path.stem + ".error.json")).write_text(json.dumps(result))
            continue
        svg = result.pop("svg")
        (args.out / (path.stem + ".json")).write_text(json.dumps(result))
        if args.svg:
            (args.out / (path.stem + ".svg")).write_text(svg)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
