"""Random Gantt charts, for scripts/check_time.py (databases against the
bundled code under Node) and scripts/check_gantt.py (SVG against Chrome).

The charts stay within what both sides can be compared on: a task only
refers to ids its own chart defines or to ids no chart defines (upstream
keeps its id table from one chart to the next on the same page), and
nothing depends on the time of day the check runs at — the clock is fixed
by the caller.
"""

import datetime

MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

# Date formats (dayjs tokens) and how to write a date in each.
FORMATS = {
    "YYYY-MM-DD": lambda t: t.strftime("%Y-%m-%d"),
    "DD.MM.YYYY": lambda t: t.strftime("%d.%m.%Y"),
    "MM/DD/YYYY": lambda t: t.strftime("%m/%d/%Y"),
    "YYYY-MM-DD HH:mm": lambda t: t.strftime("%Y-%m-%d %H:%M"),
    "YYYY-MM-DDTHH:mm:ss": lambda t: t.strftime("%Y-%m-%dT%H:%M:%S"),
    "HH:mm": lambda t: t.strftime("%H:%M"),
    "HH:mm:ss": lambda t: t.strftime("%H:%M:%S"),
    "YYYY": lambda t: t.strftime("%Y"),
    "YYYY-MM": lambda t: t.strftime("%Y-%m"),
    "D/M/YY": lambda t: f"{t.day}/{t.month}/{t.year % 100:02}",
    "D MMM YYYY": lambda t: f"{t.day} {MONTHS[t.month - 1]} {t.year}",
    "YYYYMMDD": lambda t: t.strftime("%Y%m%d"),
    "x": lambda t: str(int(t.replace(tzinfo=datetime.timezone.utc).timestamp() * 1000) - 8 * 3600000),
    "X": lambda t: str(int(t.replace(tzinfo=datetime.timezone.utc).timestamp()) - 8 * 3600),
    "D": lambda t: str(t.day),
    "": lambda t: t.strftime("%Y-%m-%d"),
    "none": lambda t: t.strftime("%Y-%m-%d %H:%M"),
}
DURATIONS = ["1d", "2d", "3d", "5d", "10d", "30d", "1w", "2w", "1M", "3M", "1y", "12h", "36h", "90m", "45s", "500ms",
             "1.5d", "0.5w", "0d", "24h", "7d", "100d", "2.5h"]
BAD_ENDS = ["3x", "soon", "d", "", "1 d", "1D"]
AXIS_FORMATS = ["%Y-%m-%d", "%d/%m", "%b %e", "%H:%M", "%a %d", "%B", "W%U", "%j", "%m-%d %H:%M", "%Y", "%e %b %y",
                "%I:%M %p", "%x", "%M:%S", "week %V"]
TICK_INTERVALS = ["1day", "2day", "3day", "7day", "1week", "2week", "1month", "2month", "6hour", "12hour", "1hour",
                  "30minute", "15second", "500millisecond", "1decade", "0day", "10week", "1 week", "3month", "100day"]
WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
WORDS = ["Design", "Build", "Test", "Ship", "Review the plan", "Write documentation for the feature",
         "A", "Kick-off", "Deploy to production (final)", "QA", "Research & development", "Milestone reached",
         "Very long task name that will never fit inside of its bar whatever happens", "Fix #42", "x_y", "é à ü"]
THEMES = ["default", "dark", "forest", "neutral", "base", "neo", "neo-dark", "redux", "redux-dark", "redux-color",
          "redux-dark-color"]


def chart(rng, index, rich=False):
    """One chart. `rich` adds what only shows in the drawing: titles,
    themes, configuration."""
    name = rng.choice(list(FORMATS))
    write = FORMATS[name]
    # Charts span hours, days or years depending on the format.
    base = datetime.datetime(rng.choice([1987, 1999, 2014, 2023, 2024, 2026]), rng.randint(1, 12), rng.randint(1, 28),
                             rng.randint(0, 23), rng.choice([0, 15, 30, 49]))
    if name in ("HH:mm", "HH:mm:ss"):
        step = datetime.timedelta(minutes=rng.choice([1, 7, 30]))
    elif name in ("YYYY", "YYYY-MM"):
        step = datetime.timedelta(days=rng.choice([40, 200, 400]))
    elif name in ("x", "X"):
        step = datetime.timedelta(seconds=rng.choice([20, 3600, 86400]))
    else:
        step = datetime.timedelta(hours=rng.choice([5, 24, 60, 24 * 9]))
    lines = ["gantt"]
    if name == "none":
        pass
    else:
        lines.append(f"    dateFormat {name}" if name else "    dateFormat  ")
    if rich and rng.random() < 0.6:
        lines.append("    title " + rng.choice(WORDS) + rng.choice(["", " 2024", " — plan"]))
    if rng.random() < 0.3:
        lines.append("    axisFormat " + rng.choice(AXIS_FORMATS))
    if rng.random() < 0.3:
        lines.append("    tickInterval " + rng.choice(TICK_INTERVALS))
    if rng.random() < 0.2:
        lines.append("    weekday " + rng.choice(WEEKDAYS))
    if rng.random() < 0.25:
        tokens = rng.sample(["weekends", "monday", "friday", "sunday", write(base + 2 * step), write(base + 5 * step),
                             (base + 3 * step).strftime("%Y-%m-%d"), "Weekends"], rng.randint(1, 3))
        lines.append("    excludes " + rng.choice([" ", ", ", ","]).join(tokens))
        if rng.random() < 0.3:
            lines.append("    includes " + (base + rng.randint(0, 9) * step).strftime("%Y-%m-%d"))
        if rng.random() < 0.3:
            lines.append("    weekend " + rng.choice(["friday", "saturday"]))
    if rng.random() < 0.15:
        lines.append("    inclusiveEndDates")
    if rng.random() < 0.15:
        lines.append("    todayMarker " + rng.choice(["off", "stroke-width:5px,stroke:#0f0,opacity:0.5", "stroke:blue"]))
    ids = []
    count = rng.randint(1, 9)
    for number in range(count):
        if rng.random() < 0.25:
            lines.append("    section " + rng.choice(["Planning", "Work", "2", "1", "Launch<br>day", "Ünïcode", "A long section name"]))
        fields = []
        tags = [tag for tag in ["active", "done", "crit", "milestone", "vert"] if rng.random() < 0.15]
        rng.shuffle(tags)
        fields += tags
        task_id = None
        when = base + rng.randint(0, 12) * step
        start = rng.random()
        if start < 0.55 or (number == 0 and start < 0.9):
            start_text = write(when)
        elif start < 0.85 and ids:
            start_text = "after " + " ".join(rng.sample(ids, min(len(ids), rng.randint(1, 2))))
        elif start < 0.9:
            start_text = f"after nobody{index}x{number}"
        else:
            start_text = None
        end = rng.random()
        if end < 0.65:
            end_text = rng.choice(DURATIONS)
        elif end < 0.85:
            end_text = write(when + rng.randint(0, 6) * step)
        elif end < 0.93 and ids:
            end_text = "until " + rng.choice(ids)
        else:
            end_text = rng.choice(BAD_ENDS)
        if start_text is not None:
            if rng.random() < 0.6:
                task_id = f"t{number}"
                fields.append(task_id)
            fields.append(start_text)
        fields.append(end_text)
        text = rng.choice(WORDS) + rng.choice(["", " ", "    "])
        lines.append(f"    {text}:" + rng.choice([", ", ",", " , "]).join(fields))
        if task_id:
            ids.append(task_id)
    if ids and rng.random() < 0.2:
        lines.append(f'    click {rng.choice(ids)} href "https://example.com/{index}"')
    if ids and rng.random() < 0.1:
        lines.append(f"    click {','.join(rng.sample(ids, min(2, len(ids))))} call go()")
    text = "\n".join(lines) + "\n"
    if rich:
        config = []
        if rng.random() < 0.4:
            config.append(f"  theme: {rng.choice(THEMES)}")
        gantt = []
        if rng.random() < 0.2:
            gantt.append("    displayMode: compact")
        if rng.random() < 0.2:
            gantt.append("    topAxis: true")
        if rng.random() < 0.15:
            gantt.append(f"    useWidth: {rng.choice([400, 600, 1000, 1500])}")
        if rng.random() < 0.15:
            gantt.append(f"    barHeight: {rng.choice([12, 30, 45])}")
        if rng.random() < 0.1:
            gantt.append(f"    fontSize: {rng.choice([9, 14, 16])}")
        if rng.random() < 0.1:
            gantt.append(f"    numberSectionStyles: {rng.choice([1, 2, 3])}")
        if rng.random() < 0.1:
            gantt.append("    useMaxWidth: false")
        if gantt:
            config += ["  gantt:"] + gantt
        if config:
            text = "---\nconfig:\n" + "\n".join(config) + "\n---\n" + text
    return text
