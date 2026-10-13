#!/usr/bin/env python3
"""Check the port's text measurement against Chrome on a random corpus.

Builds strings from words and random characters, measures each as an SVG
`<text>` element in the oracle browser and with `cmd/mermaid measure`, and
reports every case whose advance or bounding box differs.

Usage: python3 scripts/check_metrics.py [--count N] [--seed S]
"""

import argparse
import json
import pathlib
import random
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import oracle  # noqa: E402

ROOT = oracle.ROOT
WORDS = (
    "Start End Is it? Yes No OK Dogs Cats Rats Pets adopted by volunteers AV To WA fi fl "
    "Hello, World! (parentheses) [brackets] {braces} <angle> a/b a\\b 100% $9.99 #tag @user "
    "x_y x-y x+y x=y 'quoted' \"double\" naïve café Ærø ß ¿Qué? — – … “smart” ‘quotes’ → ← ± × ÷ "
    "The quick brown fox jumps over the lazy dog 0123456789 Type. Wave, Yo. P. T; f) f] Va Te"
).split()
SIZES = [10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 24, 25, 32, 12.5, 13.3333, 16.5, 11.7, 13.4, 14.2, 15.99, 9.6, 19.2, 13.33, 13.34]

MEASURE = """(() => {
  const NS = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(NS, 'svg');
  document.body.appendChild(svg);
  return %s.map((c) => {
    const text = document.createElementNS(NS, 'text');
    text.setAttribute('style', `font-family:"trebuchet ms",verdana,arial,sans-serif;font-size:${c.size}px;` +
      `font-weight:${c.bold ? 'bold' : 'normal'};font-style:${c.italic ? 'italic' : 'normal'};white-space:pre`);
    text.textContent = c.text;
    svg.appendChild(text);
    const box = text.getBBox();
    const out = { len: text.getComputedTextLength(), x: box.x, y: box.y, w: box.width, h: box.height };
    text.remove();
    return out;
  });
})()"""


def corpus(count, rng, sizes):
    cases = []
    alphabet = [chr(c) for c in range(0x20, 0x7F)] + list("àéîõüçñßÆøÅ€£¥©®™°±×÷“”‘’–—…•→←")
    for index in range(count):
        if index % 3 == 0:
            text = "".join(rng.choice(alphabet) for _ in range(rng.randint(1, 12)))
        else:
            text = " ".join(rng.choice(WORDS) for _ in range(rng.randint(1, 6)))
        cases.append({
            "text": text.strip() or "x",
            "size": rng.choice(sizes),
            "bold": rng.random() < 0.25,
            "italic": rng.random() < 0.2,
        })
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--count", type=int, default=2000)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--sizes", help="comma-separated font sizes to draw from")
    args = parser.parse_args()

    sizes = [float(v) for v in args.sizes.split(",")] if args.sizes else SIZES
    cases = corpus(args.count, random.Random(args.seed), sizes)
    expected = oracle.run([], {}, MEASURE % json.dumps(cases))[0]["value"]
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump(cases, handle)
    out = subprocess.run(
        ["moon", "run", "--target", "native", "cmd/mermaid", "--", "measure", handle.name],
        cwd=ROOT, check=True, capture_output=True, text=True,
    ).stdout
    actual = json.loads(out.strip().splitlines()[-1])
    bad = 0
    by_size = {}
    for case, want, got in zip(cases, expected, actual):
        if want != got:
            bad += 1
            by_size[case["size"]] = by_size.get(case["size"], 0) + 1
            if bad <= 15:
                keys = [k for k in want if want[k] != got[k]]
                detail = ", ".join(f"{k}: chrome {want[k]} port {got[k]}" for k in keys)
                print(f"{case['text']!r} size {case['size']} bold {case['bold']} italic {case['italic']}: {detail}")
    if by_size:
        print("mismatches by size:", dict(sorted(by_size.items())))
    print(f"{len(cases) - bad}/{len(cases)} cases identical")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
