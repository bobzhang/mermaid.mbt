#!/usr/bin/env python3
"""Check the port's `Date` emulation against Chrome on a random corpus.

Generates date strings (ISO forms, legacy forms, garbage), constructor
arguments, time values and setter calls — many of them around the
daylight saving changes of the emulated time zone — evaluates each in the
oracle browser and with `cmd/mermaid dates`, and reports every difference.

Usage: python3 scripts/check_dates.py [--count N] [--seed S]
"""

import argparse
import json
import pathlib
import random
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import compare  # noqa: E402
import oracle  # noqa: E402

EVALUATE = """(() => %s.map((c) => {
  const clean = (v) => (Number.isNaN(v) ? null : v);
  if ('parse' in c) return clean(new Date(c.parse).getTime());
  if ('make' in c) return clean(new Date(...c.make).getTime());
  if ('fields' in c) {
    const d = new Date(c.fields);
    return [d.getFullYear(), d.getMonth(), d.getDate(), d.getDay(), d.getHours(), d.getMinutes(),
            d.getSeconds(), d.getMilliseconds(), d.getTimezoneOffset()].map(clean);
  }
  const d = new Date(c.time === null ? NaN : c.time);
  const name = { date: 'setDate', month: 'setMonth', fullYear: 'setFullYear', hours: 'setHours' }[c.set];
  return clean(d[name](...c.args));
}))()"""

# Offset changes of Asia/Shanghai (UTC milliseconds), to aim cases at.
CHANGES = [-2177481943000, -1600675200000, -1585904400000, -933667200000, -650019600000,
           515527200000, 527014800000, 671565600000, 684867600000]
MONTHS = ["Jan", "feb", "March", "APR", "may", "June", "jul", "Aug", "Sept", "oct", "November", "Dec", "Janu", "ma"]
WORDS = MONTHS + ["Mon", "Tuesday", "am", "PM", "pm", "UTC", "GMT", "Z", "z", "T", "t", "EST", "pdt", "UT", "foo",
                  "at", "of", "é", "(comment)", "((a)b)", "(", ")"]
SEPARATORS = ["-", "/", " ", ".", ":", ",", "T", "+", "", "  ", "::", " -", "Z", "\t", "\n", " "]


def number(rng):
    kind = rng.random()
    if kind < 0.35:
        return str(rng.randint(0, 31)).zfill(rng.choice([1, 2, 2, 2, 3]))
    if kind < 0.6:
        return str(rng.randint(0, 99)).zfill(2)
    if kind < 0.9:
        return str(rng.choice([1899, 1900, 1949, 1950, 1969, 1970, 1986, 1999, 2000, 2014, 2023, 2024, 2026, 9999, 275760]))
    return str(rng.randint(0, 10 ** rng.randint(1, 12)))


def iso(rng):
    year = rng.choice(["2014", "1986", "0001", "0099", "+002014", "-000001", "-000000", "+275760", "99", "20140"])
    text = year
    if rng.random() < 0.9:
        text += "-" + rng.choice(["01", "05", "09", "12", "13", "00", "1", "4"])
        if rng.random() < 0.9:
            text += "-" + rng.choice(["01", "04", "14", "28", "31", "32", "00", "5"])
    if rng.random() < 0.7:
        text += rng.choice(["T", "T", "T", " ", "t"]) + rng.choice(["00", "02", "12", "23", "24", "25", "2"])
        text += ":" + rng.choice(["00", "30", "59", "60", "5"])
        if rng.random() < 0.6:
            text += ":" + rng.choice(["00", "30", "59", "60"])
            if rng.random() < 0.5:
                text += "." + rng.choice(["0", "5", "12", "123", "1234", "999999999999", "000"])
        text += rng.choice(["", "", "Z", "z", "+08:00", "-0530", "+08", "+8", "+0800", " +08:00", "+24:00", "+08:60", "UTC", " GMT"])
    return text


def legacy(rng):
    parts = []
    for _ in range(rng.randint(1, 7)):
        parts.append(rng.choice(WORDS) if rng.random() < 0.3 else number(rng))
        parts.append(rng.choice(SEPARATORS))
    if rng.random() < 0.7:
        parts.pop()
    return "".join(parts)


def common(rng):
    y, m, d = rng.choice([2014, 1986, 1991, 2024, 99, 49, 50]), rng.randint(1, 12), rng.randint(1, 31)
    h, mi, s = rng.randint(0, 24), rng.randint(0, 60), rng.randint(0, 60)
    month = rng.choice(MONTHS)
    return rng.choice([
        f"{y}-{m}-{d}", f"{y}/{m}/{d}", f"{m}/{d}/{y}", f"{d} {month} {y}", f"{month} {d}, {y}",
        f"{month} {d} {y} {h}:{mi}", f"{y}-{m:02}-{d:02} {h:02}:{mi:02}", f"{y}-{m:02}-{d:02} {h}:{mi}:{s}",
        f"{h}:{mi}", f"{h}:{mi}:{s}", f"{y}{m:02}{d:02}", f"{y}-{m:02}", f"{y}", f"{d}.{m}.{y}",
        f"{y}-{m:02}-{d:02}T{h:02}:{mi:02}", f"{m}-{d}-{y}", f"{month} {y}", f"{d} {month}",
        f"{y}-{m:02}-{d:02} {h}:{mi} pm", f"Tue {month} {d} {y} {h:02}:{mi:02}:{s:02} GMT+0800 (China Standard Time)",
        f"{y}-{m:02}-{d:02}T{h:02}:{mi:02}:{s:02}+08:00", f"{d}/{m}", f"{y}.{m}.{d}", f"{h}:{mi} {y}-{m}-{d}",
    ])


def time_value(rng):
    kind = rng.random()
    if kind < 0.5:
        return rng.choice(CHANGES) + rng.choice([-1, 0, 1]) * rng.choice([0, 1, 999, 1000, 60000, 1800000, 3600000, 3599999, 86400000])
    if kind < 0.9:
        return rng.randint(-3_000_000_000_000, 4_000_000_000_000)
    return rng.choice([0, -1, 1, 8.64e15, -8.64e15, 8.64e15 - 1, 253402300799999, -62198755200000])


def argument(rng, low, high):
    kind = rng.random()
    if kind < 0.8:
        return rng.randint(low, high)
    if kind < 0.95:
        return rng.randint(low, high) + rng.random() * rng.choice([1, -1])
    return rng.choice([1e9, -1e9, 1e21, 0.5, -0.5])


def corpus(count, rng):
    cases = []
    for index in range(count):
        kind = index % 8
        if kind == 0:
            cases.append({"parse": iso(rng)})
        elif kind == 1:
            cases.append({"parse": legacy(rng)})
        elif kind == 2:
            cases.append({"parse": common(rng)})
        elif kind == 3 or kind == 4:
            year = rng.choice([1900, 1901, 1919, 1940, 1949, 1986, 1987, 1991, 2014, 2024, 50, 99, 100, -1, 0, 275760, -271821, 1986.7])
            args = [year, argument(rng, -3, 14)]
            for low, high in [(-3, 34), (-2, 26), (-70, 70), (-70, 70), (-1500, 1500)][:rng.randint(0, 5)]:
                args.append(argument(rng, low, high))
            cases.append({"make": args})
        elif kind == 5:
            cases.append({"fields": time_value(rng)})
        else:
            name = rng.choice(["date", "month", "fullYear", "hours"])
            limits = {"date": [(-40, 70)], "month": [(-14, 26), (-3, 34)], "fullYear": [(1890, 2030), (-3, 14), (-3, 34)],
                      "hours": [(-30, 50), (-70, 70), (-70, 70), (-1500, 1500)]}[name]
            args = [argument(rng, low, high) for low, high in limits[:rng.randint(1, len(limits))]]
            time = None if rng.random() < 0.03 else time_value(rng)
            cases.append({"set": name, "time": time, "args": args})
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--count", type=int, default=4000)
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args()
    cases = corpus(args.count, random.Random(args.seed))
    expected = oracle.run([], {}, EVALUATE % json.dumps(cases))[0]
    if "value" not in expected:
        sys.exit(str(expected))
    expected = expected["value"]
    binary = compare.build()
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump(cases, handle)
    actual = json.loads(subprocess.run([str(binary), "dates", handle.name], capture_output=True, text=True, check=True).stdout)
    failures = 0
    for case, want, got in zip(cases, expected, actual):
        if want != got:
            failures += 1
            if failures <= 40:
                print(f"{json.dumps(case, ensure_ascii=False)}: chrome {want}, port {got}")
    print(f"{len(cases) - failures}/{len(cases)} date cases identical")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
