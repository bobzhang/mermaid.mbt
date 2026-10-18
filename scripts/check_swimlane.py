#!/usr/bin/env python3
"""Compare the port's swimlane layout with upstream's engine, step by step.

Every input is a capture of `scripts/swimlane_capture.py` (the layout data
mermaid hands the layout and the measured node sizes). Both engines run on
it with `--stages` (`node scripts/swimlane_oracle.js`, `cmd/mermaid
swimlane`), and the snapshots after each step are compared exactly; a case
is reported with the first step whose snapshot differs.

With `--isolate`, every step is instead run alone by the port on upstream's
snapshot before it, so that one step can be checked while the others are
not exact yet (`--steps` picks the steps by name, `f1.`/`f2.` prefixes and
trailing `2`s ignored). Snapshots do not keep points shared between routes,
so a step that moves shared points in place can differ here and still be
right in the whole run.

Usage: scripts/check_swimlane.py CAPTURE.json|DIR ... [--isolate]
                                 [--steps route ...] [-v]
"""

import argparse
import collections
import concurrent.futures
import json
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
HARNESS = ROOT / "scripts" / "swimlane_oracle.js"


def binary():
    subprocess.run(["moon", "build", "--target", "native", "cmd/mermaid"], cwd=ROOT, check=True,
                   capture_output=True)
    candidates = [p for p in (ROOT / "_build" / "native").rglob("mermaid.exe") if "dSYM" not in str(p)]
    return max(candidates, key=lambda p: p.stat().st_mtime)


def run_json(command):
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        return {"error": (result.stderr or result.stdout).strip().splitlines()[-1:] or ["failed"]}
    try:
        return json.loads(result.stdout)
    except ValueError:
        return {"error": [result.stdout[:200]]}


def first_difference(a, b, path=""):
    """The path of the first difference between two JSON values, or None."""
    if isinstance(a, dict) and isinstance(b, dict):
        for key in list(a.keys()) + [k for k in b.keys() if k not in a]:
            if key not in a or key not in b:
                return f"{path}.{key} (only in {'port' if key in a else 'upstream'})"
            found = first_difference(a[key], b[key], f"{path}.{key}")
            if found:
                return found
        return None
    if isinstance(a, list) and isinstance(b, list):
        for i, (x, y) in enumerate(zip(a, b)):
            label = x.get("id") if isinstance(x, dict) and "id" in x else i
            found = first_difference(x, y, f"{path}[{label}]")
            if found:
                return found
        if len(a) != len(b):
            return f"{path} (length {len(a)} vs {len(b)})"
        return None
    if a != b or type(a) is bool and type(b) is not bool:
        return f"{path}: port {json.dumps(a)} upstream {json.dumps(b)}"
    return None


def captures(inputs):
    found = []
    for path in inputs:
        if path.is_dir():
            found.extend(sorted(path.glob("*.json")))
        else:
            found.append(path)
    return found


def check_whole(exe, path):
    upstream = run_json(["node", str(HARNESS), str(path), "--stages"])
    port = run_json([str(exe), "swimlane", str(path), "--stages"])
    if "error" in upstream:
        return ("upstream error", " ".join(upstream["error"]))
    if "error" in port:
        return ("port error", " ".join(port["error"]))
    ours = {s["name"]: s for s in port["stages"]}
    for stage in upstream["stages"]:
        mine = ours.get(stage["name"])
        if mine is None:
            return (stage["name"], "missing in the port")
        found = first_difference(
            {"nodes": mine["nodes"], "edges": mine["edges"]},
            {"nodes": stage["nodes"], "edges": stage["edges"]},
        )
        if found:
            return (stage["name"], found)
    if len(port["stages"]) != len(upstream["stages"]):
        return ("stages", f"{len(port['stages'])} vs {len(upstream['stages'])}")
    return None


def base_step(name):
    name = name.split(".", 1)[-1]
    return name[:-1] if name.endswith("2") else name


def check_isolated(exe, path, steps):
    upstream = run_json(["node", str(HARNESS), str(path), "--stages"])
    if "error" in upstream:
        return [("upstream error", " ".join(upstream["error"]))]
    direction = json.loads(path.read_text())["data"].get("direction") or "TB"
    problems = []
    stages = upstream["stages"]
    with tempfile.TemporaryDirectory() as tmp:
        for before, after in zip(stages, stages[1:]):
            if after["name"] in ("prepare", "sugiyama"):
                continue
            if steps and base_step(after["name"]) not in steps:
                continue
            source = pathlib.Path(tmp) / "before.json"
            source.write_text(json.dumps(before))
            port = run_json([str(exe), "swimlane", "--from", str(source), "--run", after["name"],
                             "--direction", direction])
            if "error" in port:
                problems.append((after["name"], "port error " + " ".join(port["error"])))
                continue
            found = first_difference(port, {"nodes": after["nodes"], "edges": after["edges"]})
            problems.append((after["name"], found))
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("inputs", nargs="+", type=pathlib.Path)
    parser.add_argument("--isolate", action="store_true")
    parser.add_argument("--steps", nargs="*", default=[])
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()
    exe = binary()
    paths = captures(args.inputs)
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        if args.isolate:
            results = list(pool.map(lambda p: check_isolated(exe, p, set(args.steps)), paths))
            tally = collections.OrderedDict()
            for path, problems in zip(paths, results):
                for step, found in problems:
                    good, bad = tally.get(step, (0, []))
                    if found:
                        bad.append((path.name, found))
                    else:
                        good += 1
                    tally[step] = (good, bad)
            for step, (good, bad) in tally.items():
                print(f"{step}: {good}/{good + len(bad)} identical")
                for name, found in bad[: (len(bad) if args.verbose else 3)]:
                    print(f"    {name}: {found}")
            return
        results = list(pool.map(lambda p: check_whole(exe, p), paths))
    by_stage = collections.Counter()
    for path, result in zip(paths, results):
        if result:
            by_stage[result[0]] += 1
            if args.verbose or by_stage[result[0]] <= 3:
                print(f"{path.name}: {result[0]}: {result[1]}")
    for stage, count in by_stage.most_common():
        print(f"  first difference at {stage}: {count}")
    same = sum(1 for result in results if not result)
    print(f"{same}/{len(paths)} layouts identical")


if __name__ == "__main__":
    main()
