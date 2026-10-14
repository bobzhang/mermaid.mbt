#!/usr/bin/env python3
"""Compare the port's output with upstream mermaid, byte for byte.

Every `testdata/**/<name>.mmd` is rendered by the oracle (see oracle.py);
the result is stored next to it as `<name>.svg` and reused until the input
changes. The port then renders the same inputs through `cmd/mermaid`, and
any difference is reported with its first diverging position.

A fixture the oracle itself rejects stores `<name>.error` instead, and the
port is expected to fail on it too.

A directory may hold `oracle-prelude.js`: JavaScript evaluated in the oracle
page before its fixtures are rendered. That is how output upstream leaves to
`Math.random()` (the ids of git graph commits) is made reproducible.

A directory holding a file `FRESH-PAGE` has each of its fixtures rendered in
a page of its own, for diagrams whose output depends on what the page
rendered before: Sankey numbers its nodes and gradients with a counter that
lives as long as the page. The port renders like a page's first diagram.

Usage:
    scripts/compare.py                 # all fixtures
    scripts/compare.py testdata/pie    # one directory or file
    scripts/compare.py --refresh ...   # re-render with the oracle
    scripts/compare.py -v ...          # show context around each difference
"""

import argparse
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import oracle  # noqa: E402

ROOT = oracle.ROOT
SVG_ID = "mermaid-svg"
BATCH = 40
PRELUDE = "oracle-prelude.js"
FRESH_PAGE = "FRESH-PAGE"


def collect(paths):
    inputs = []
    for path in paths:
        path = pathlib.Path(path)
        if not path.is_dir():
            inputs.append(path)
            continue
        for file in sorted(path.rglob("*.mmd")):
            # A directory marked PENDING holds inputs for a diagram that
            # does not render yet; it is only compared when asked for.
            if (file.parent / "PENDING").exists() and file.parent != path:
                continue
            inputs.append(file)
    return inputs


def refresh(inputs, force):
    """Render fixtures whose reference is missing or older than the input."""
    stale = []
    for path in inputs:
        references = [path.with_suffix(".svg"), path.with_suffix(".error")]
        newest = max((r.stat().st_mtime for r in references if r.exists()), default=0)
        if force or newest < path.stat().st_mtime:
            stale.append(path)
    # Fixtures of a directory holding PRELUDE are rendered after that
    # JavaScript has run in the page.
    groups = {}
    for path in stale:
        prelude = path.parent / PRELUDE
        fresh = (path.parent / FRESH_PAGE).exists()
        groups.setdefault((prelude if prelude.exists() else None, fresh), []).append(path)
    for (prelude, fresh), paths in groups.items():
        expression = prelude.read_text() if prelude else None
        size = 1 if fresh else BATCH
        for start in range(0, len(paths), size):
            batch = paths[start:start + size]
            jobs = [{"id": SVG_ID, "text": path.read_text()} for path in batch]
            results = oracle.run(jobs, {}, expression)
            if expression is not None:
                results = results[1:]
            for path, result in zip(batch, results):
                svg, error = path.with_suffix(".svg"), path.with_suffix(".error")
                svg.unlink(missing_ok=True)
                error.unlink(missing_ok=True)
                if "svg" in result:
                    svg.write_text(result["svg"])
                else:
                    error.write_text(result["error"] + "\n")
    return len(stale)


def build():
    done = subprocess.run(["moon", "build", "--target", "native", "cmd/mermaid"], cwd=ROOT, capture_output=True, text=True)
    if done.returncode != 0:
        sys.exit(done.stdout + done.stderr)
    # The path depends on whether the module is built inside a workspace;
    # take the executable this build just produced.
    candidates = [candidate for candidate in (ROOT / "_build" / "native").rglob("mermaid.exe")
                  if candidate.is_file() and candidate.parent.name == "mermaid"]
    if not candidates:
        sys.exit("cannot find the built cmd/mermaid executable")
    return max(candidates, key=lambda candidate: candidate.stat().st_mtime)


def render(binary, path):
    done = subprocess.run([str(binary), "render", str(path), "--id", SVG_ID], capture_output=True, text=True)
    if done.returncode != 0:
        return None, done.stdout.strip()
    return done.stdout.removesuffix("\n"), None


def first_difference(a, b):
    for index, (x, y) in enumerate(zip(a, b)):
        if x != y:
            return index
    return min(len(a), len(b))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="*", default=[ROOT / "testdata"])
    parser.add_argument("--refresh", action="store_true", help="re-render every fixture with the oracle")
    parser.add_argument("-v", "--verbose", action="store_true", help="show context around differences")
    args = parser.parse_args()

    inputs = collect(args.paths)
    rendered = refresh(inputs, args.refresh)
    if rendered:
        print(f"oracle rendered {rendered} fixture(s)")
    binary = build()
    failures = 0
    for path in inputs:
        name = path.relative_to(ROOT) if path.is_absolute() else path
        actual, error = render(binary, path)
        expected_path = path.with_suffix(".svg")
        if not expected_path.exists():
            if actual is None:
                continue
            failures += 1
            print(f"FAIL {name}: the oracle rejects this diagram, the port renders it")
            continue
        expected = expected_path.read_text()
        if actual == expected:
            continue
        failures += 1
        if actual is None:
            print(f"FAIL {name}: {error}")
            continue
        at = first_difference(actual, expected)
        print(f"FAIL {name}: differs at byte {at} (port {len(actual)}, oracle {len(expected)})")
        if args.verbose:
            print(f"    port  : ...{actual[max(0, at - 80):at + 120]!r}")
            print(f"    oracle: ...{expected[max(0, at - 80):at + 120]!r}")
    print(f"{len(inputs) - failures}/{len(inputs)} fixtures identical")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
