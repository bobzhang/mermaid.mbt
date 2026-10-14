#!/usr/bin/env python3
"""Render diagrams with upstream mermaid, as the reference for this port.

The published mermaid bundle is loaded into headless Chrome, so the SVG is
what a browser user of mermaid gets: real DOM text measurement included.
Byte-identical output is therefore defined against this environment —
Chrome on macOS with the system fonts.

Setup (once):
    mkdir -p .repos/oracle && cd .repos/oracle
    npm pack mermaid@12.2.0 && tar xzf mermaid-12.2.0.tgz

Usage:
    scripts/oracle.py diagram.mmd                # SVG on stdout
    scripts/oracle.py -o out/ a.mmd b.mmd        # out/a.svg, out/b.svg
    scripts/oracle.py --eval 'mermaid.version()' # evaluate in the page

Environment: CHROME overrides the Chrome binary.
"""

import argparse
import base64
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
BUNDLE = ROOT / ".repos" / "oracle" / "package" / "dist" / "mermaid.js"
CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")

PAGE = """<!doctype html>
<html><head><meta charset="utf-8"></head><body>
<script src="%(bundle)s"></script>
<script>
const jobs = %(jobs)s;
const expression = %(expression)s;
// Console output is captured so mermaid's debug logging can be inspected.
const consoleLines = [];
for (const level of ['debug', 'info', 'log', 'warn', 'error']) {
  console[level] = (...args) => {
    consoleLines.push(args.map((arg) => {
      if (typeof arg === 'string') return arg;
      try { return JSON.stringify(arg); } catch { return String(arg); }
    }));
  };
}
const encode = (value) => {
  const bytes = new TextEncoder().encode(JSON.stringify(value));
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
};
(async () => {
  const results = [];
  try {
    mermaid.initialize(Object.assign({ startOnLoad: false }, %(config)s));
    await document.fonts.ready;
    if (expression !== null) {
      results.push({ value: await (0, eval)(expression) });
    }
    for (const job of jobs) {
      try {
        consoleLines.length = 0;
        const { svg } = await mermaid.render(job.id, job.text);
        results.push({ svg, console: consoleLines.slice() });
      } catch (error) {
        results.push({ error: String(error && error.message || error) });
      }
    }
  } catch (error) {
    results.push({ error: String(error && error.stack || error) });
  }
  const out = document.createElement('pre');
  out.id = 'oracle-output';
  out.textContent = encode(results);
  document.body.replaceChildren(out);
})();
</script></body></html>
"""


RANDOM_STATE_ID = re.compile(r"(?<=state-)id-[0-9a-z]{1,12}-(\d+)")


def pin_random_ids(svg):
    """Name the randomly named regions of a state diagram as the port does.

    The last region of a composite state split by `--` has no name in the
    diagram text; mermaid calls it `id-<Math.random() in base 36>-<count>`,
    counting over the lifetime of the page. The port takes every draw to be
    0.5 (`i` in base 36) and counts per diagram, which is what a fresh page
    with that draw prints; the reference is rewritten to the same names.
    """
    if 'aria-roledescription="stateDiagram"' not in svg:
        return svg
    counts = sorted({int(match.group(1)) for match in RANDOM_STATE_ID.finditer(svg)})
    names = {}
    for match in RANDOM_STATE_ID.finditer(svg):
        names[match.group(0)] = f"id-i-{counts.index(int(match.group(1))) + 1}"
    return RANDOM_STATE_ID.sub(lambda match: names[match.group(0)], svg)


def run(jobs, config, expression=None):
    """Render `jobs` (dicts with `id` and `text`) and return one result each."""
    if not BUNDLE.exists():
        sys.exit(f"missing {BUNDLE}; see the setup notes in {__file__}")
    page = PAGE % {
        "bundle": BUNDLE.as_uri(),
        "jobs": json.dumps(jobs).replace("</", "<\\/"),
        "config": json.dumps(config),
        "expression": json.dumps(expression).replace("</", "<\\/"),
    }
    with tempfile.TemporaryDirectory() as tmp:
        path = pathlib.Path(tmp) / "oracle.html"
        path.write_text(page)
        dom = subprocess.run(
            [
                CHROME,
                "--headless=new",
                "--disable-gpu",
                "--no-first-run",
                "--allow-file-access-from-files",
                f"--user-data-dir={tmp}/profile",
                "--virtual-time-budget=30000",
                "--dump-dom",
                path.as_uri(),
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
    match = re.search(r'<pre id="oracle-output">([^<]*)</pre>', dom)
    if not match:
        sys.exit("oracle page produced no output:\n" + dom[:2000])
    results = json.loads(base64.b64decode(match.group(1)).decode("utf-8"))
    for result in results:
        if isinstance(result.get("svg"), str):
            result["svg"] = pin_random_ids(result["svg"])
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("inputs", nargs="*", type=pathlib.Path, help="diagram source files")
    parser.add_argument("-o", "--out", type=pathlib.Path, help="directory for <name>.svg outputs")
    parser.add_argument("--id", default="mermaid-svg", help="id of the rendered <svg> element")
    parser.add_argument("--config", default="{}", help="JSON passed to mermaid.initialize")
    parser.add_argument("--eval", dest="expression", help="JavaScript expression to evaluate in the page")
    parser.add_argument("--console", type=pathlib.Path, help="write captured console output here as JSON lines")
    args = parser.parse_args()

    jobs = [{"id": args.id, "text": path.read_text()} for path in args.inputs]
    results = run(jobs, json.loads(args.config), args.expression)
    if args.expression is not None:
        value = results.pop(0)
        print(json.dumps(value.get("value", value), indent=2, ensure_ascii=False))
    failed = False
    if args.console:
        with args.console.open("w") as handle:
            for path, result in zip(args.inputs, results):
                for line in result.get("console", []):
                    handle.write(json.dumps({"input": path.name, "args": line}, ensure_ascii=False) + "\n")
    for path, result in zip(args.inputs, results):
        if "error" in result:
            failed = True
            print(f"{path}: {result['error']}", file=sys.stderr)
        elif args.out:
            args.out.mkdir(parents=True, exist_ok=True)
            (args.out / (path.stem + ".svg")).write_text(result["svg"])
        else:
            sys.stdout.write(result["svg"])
            if len(args.inputs) > 1:
                sys.stdout.write("\n")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
