#!/usr/bin/env python3
"""Check the dayjs and d3 time ports against the libraries mermaid bundles.

Random dates are formatted, parsed back (also after being damaged), added
to, and turned into scales, ticks and tick labels, by `scripts/gantt_node.mjs`
(the bundled dayjs and d3 under Node, in the reference time zone) and by
`cmd/mermaid time`; every difference is reported.

Usage: python3 scripts/check_time.py [--count N] [--seed S]
"""

import argparse
import json
import os
import pathlib
import random
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import compare  # noqa: E402

ROOT = compare.ROOT
FORMATS = [
    "YYYY-MM-DD", "DD.MM.YYYY", "MM/DD/YYYY", "YYYY-MM-DD HH:mm", "HH:mm", "YYYY-MM-DDTHH:mm:ss", "D/M/YY", "YYYY",
    "MMM D, YYYY", "MMMM Do YYYY", "dddd, MMMM D YYYY", "YYYY-MM-DD HH:mm:ss.SSS", "h:mm A", "hh:mm a", "YYYYMMDD",
    "x", "X", "YYYY-[W]WW", "Q/YYYY", "YYYY-MM-DD Z", "YYYY-MM-DDTHH:mm:ssZZ", "DD MMM YY", "YYYY-DDD",
    "[Day] D [of] MMMM", "ss", "H", "YYYY-MM-DD ww", "L", "LT", "", "kk:mm", "Y", "YYYY M D", "gggg", "S", "SS", "z",
    "MM-DD", "D", "M", "YY", "YYYY-MM", "HH:mm:ss", "D MMM", "Do MMM YYYY", "YYYY-MM-DD dd ddd d", "GGGG W", "k",
    "YYYY/MM/DD hh:mm:ss A", "DD-MM-YYYY [at] HH[h]", "MMMM", "YYYY-M-D H:m:s", "wo", "zzz", "YYYY-MM-DD w",
]
UNITS = ["M", "d", "h", "m", "s", "w", "y", "ms", "day", "month", "year", "weeks", "hour", "minutes", "seconds"]
# Offset changes of Asia/Shanghai (UTC milliseconds), to aim cases at.
CHANGES = [-2177481943000, -1600675200000, -933667200000, 515527200000, 527014800000, 671565600000, 684867600000]
SPECIFIERS = [
    "%Y-%m-%d", "%d", "%H:%M", "%b %e, %Y", "%a %d %B %y", "%j %U %W %V %G %g %u %w", "%I:%M:%S.%L %p", "%Z %%",
    "%x %X", "%c", "%-d/%-m %_H %0e", "%f %Q %s", "%q", "week %U", "%Y w%W", "%e. %b", "%A", "plain", "%", "%k %l",
]
INTERVALS = ["millisecond", "second", "minute", "hour", "day", "month", "sunday", "monday", "tuesday", "wednesday",
             "thursday", "friday", "saturday"]
SPANS = [1, 7, 500, 3000, 20000, 90000, 600000, 4e6, 2e7, 9e7, 4e8, 1.3e9, 6e9, 2.5e10, 1e11, 4e11, 2e12, 9e12]


def time_value(rng):
    kind = rng.random()
    if kind < 0.2:
        return rng.choice(CHANGES) + rng.randint(-3, 3) * rng.choice([1, 1000, 3600000, 86400000, 30 * 86400000])
    if kind < 0.95:
        return rng.randint(0, 2_300_000_000_000)
    return rng.randint(-70_000_000_000_000, 70_000_000_000_000)


def damage(text, rng):
    if not text or rng.random() < 0.5:
        return text
    at = rng.randrange(len(text))
    kind = rng.random()
    if kind < 0.3:
        return text[:at] + text[at + 1:]
    if kind < 0.6:
        return text[:at] + rng.choice("0159 -/:.TZapx") + text[at:]
    if kind < 0.8:
        return text[:at] + rng.choice("0123456789") + text[at + 1:]
    return text + rng.choice(["0", " ", "x", "th", "Z"])


def run_node(cases):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump(cases, handle)
    done = subprocess.run(["node", str(ROOT / "scripts" / "gantt_node.mjs"), handle.name], capture_output=True, text=True,
                          env=dict(os.environ, TZ="Asia/Shanghai"))
    if done.returncode != 0:
        sys.exit(done.stderr)
    return json.loads(done.stdout)


def corpus(count, rng):
    # Texts to parse are dates formatted by the reference, then damaged.
    samples = [{"op": "format", "time": time_value(rng), "format": rng.choice(FORMATS)} for _ in range(count // 4)]
    cases = []
    for sample, text in zip(samples, run_node(samples)):
        if isinstance(text, str):
            cases.append({"op": "parse", "text": damage(text, rng), "format": sample["format"], "now": time_value(rng)})
    cases += samples
    # Formats whose tokens need plugins mermaid does not load fail in
    # different places depending on the value parsed.
    for text, template in [
        ("2014-01-05 00", "YYYY-MM-DD ww"), ("2014-01-05 02", "YYYY-MM-DD ww"), ("2014-01-05 0", "YYYY-MM-DD w"),
        ("2014-01-05 3", "YYYY-MM-DD w"), ("2014", "gggg"), ("z", "z"), ("5th", "wo"), ("0000-01-01", "YYYY-MM-DD"),
        ("0099-01-01", "YYYY-MM-DD"), ("2014-02-30", "YYYY-MM-DD"), ("31", "D"), ("12:30 PM", "h:mm A"),
        ("12:30 AM", "h:mm A"), ("Invalid Date", "YYYY"), ("1388851200000", "x"), ("-1388851200", "X"),
        ("01388851200000", "x"), ("1e3", "x"), ("8640000000000001", "x"), ("8640000000000000", "x"),
        ("2014-01-05", "L"), ("2014-01-05", "[L]YYYY-MM-DD"), ("L2014-01-05", "[L]YYYY-MM-DD"), ("", "YYYY"),
        ("2014-01-05", ""), ("0th Jan 2014", "Do MMM YYYY"), ("3rd Jan 2014", "Do MMM YYYY"), ("3th Jan 2014", "Do MMM YYYY"),
        ("2014-01-05 +08:00", "YYYY-MM-DD Z"), ("2014-01-05 +09:00", "YYYY-MM-DD Z"), ("2014-01-05 Z", "YYYY-MM-DD Z"),
    ]:
        cases.append({"op": "parse", "text": text, "format": template, "now": time_value(rng)})
    for _ in range(count // 8):
        amount = rng.choice([0, 1, 2, 3, 7, 12, 30, 31, 365, 1.5, 0.5, 2.4, 1000, 100000])
        cases.append({"op": "add", "time": time_value(rng), "amount": amount, "unit": rng.choice(UNITS)})
        cases.append({"op": rng.choice(["startOfDay", "endOfDay", "isoWeekday"]), "time": time_value(rng)})
        a = time_value(rng)
        cases.append({"op": "diffYears", "a": a, "b": a + rng.randint(-10, 10) * rng.choice([86400000, 31536000000, 2592000000])})
        cases.append({"op": "duration", "unit": rng.choice(INTERVALS[:6] + ["week"]), "amount": rng.randint(1, 50)})
    for _ in range(count // 8):
        start = time_value(rng)
        span = rng.choice(SPANS) * (0.5 + rng.random())
        stop = start + int(span) * rng.choice([1, 1, 1, 1, -1, 0])
        cases.append({"op": "ticks", "start": start, "stop": stop})
        # A custom interval, kept to a number of ticks the chart would accept.
        name = rng.choice(INTERVALS)
        length = {"millisecond": 1, "second": 1e3, "minute": 6e4, "hour": 36e5, "day": 864e5, "month": 2592e6}.get(name, 6048e5)
        every = max(1, int(span / length / rng.choice([3, 10, 40, 300])))
        if rng.random() < 0.5:
            every = rng.choice([1, 2, 3, 4, 5, 7, 10, 15, 30])
        # Steps of seconds to months restart in every minute to year, so a
        # step beyond that still yields one tick per parent interval.
        effective = min(every, {"second": 60, "minute": 60, "hour": 24, "day": 31, "month": 12}.get(name, every))
        if span / (length * effective) < 3000:
            cases.append({"op": "ticks", "start": start, "stop": stop, "interval": [name, every]})
        cases.append({"op": "timeFormat", "specifier": rng.choice(SPECIFIERS), "time": time_value(rng)})
        values = [start, stop, start + span / 3, start - span, time_value(rng), None]
        cases.append({"op": "scale", "domain": [start, stop], "range": [0, rng.choice([590, 1125, 333.5])], "values": values})
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--count", type=int, default=4000)
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args()
    cases = corpus(args.count, random.Random(args.seed))
    expected = run_node(cases)
    binary = compare.build()
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump(cases, handle)
    actual = json.loads(subprocess.run([str(binary), "time", handle.name], capture_output=True, text=True, check=True).stdout)
    failures = 0
    for case, want, got in zip(cases, expected, actual):
        # Upstream's failures are JavaScript errors; only their presence is compared.
        if isinstance(want, dict) and isinstance(got, dict):
            continue
        if want != got:
            failures += 1
            if failures <= 40:
                print(f"{json.dumps(case, ensure_ascii=False)}: reference {want}, port {got}")
    print(f"{len(cases) - failures}/{len(cases)} time cases identical")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
