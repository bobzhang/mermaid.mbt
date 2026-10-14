// The expected dates come from upstream's database run under Node
// (scripts/gantt_node.mjs); scripts/check_time.py compares the two on
// random charts.

///|
fn dates(db : GanttDb, now : Double) -> String raise {
  let zone = @jsdate.Zone::system()
  let stamp = (time : Double?) => {
    match time {
      None => "-"
      Some(time) => @d3.time_format(zone, "%Y-%m-%d %H:%M")(time)
    }
  }
  db
  .compile(now)
  .map(task => {
    "\{task.id} \{task.order}: \{stamp(task.start_time)} .. \{stamp(task.end_time)} (bar to \{stamp(task.render_end_time)})"
  })
  .join("\n")
}

///|
test "dates of tasks: durations, dependencies, excluded days" {
  let db = parse(
    (
      #|gantt
      #|    dateFormat YYYY-MM-DD
      #|    excludes weekends
      #|    section One
      #|    First :done, a, 2024-01-05, 3d
      #|    Second :after a, 12h
      #|    Third :crit, c, 2024-01-02, until a
      #|    Marker :vert, v, after zz_unknown, 0d
      #|    click a href "https://example.com"
      #|
    ),
  )
  // Three days from Friday the 5th skip the weekend. A reference to an
  // unknown task falls back to midnight of the day of rendering (the
  // 15th in the reference time zone).
  inspect(
    dates(db, 1700000000000.0),
    content=(
      #|a 0: 2024-01-05 00:00 .. 2024-01-10 00:00 (bar to 2024-01-10 00:00)
      #|task1 1: 2024-01-10 00:00 .. 2024-01-10 12:00 (bar to -)
      #|c 2: 2024-01-02 00:00 .. 2024-01-05 00:00 (bar to 2024-01-05 00:00)
      #|v -1: 2023-11-15 00:00 .. 2023-11-15 00:00 (bar to -)
    ),
  )
  inspect(db.tasks[0].classes.join(" "), content="clickable")
  inspect(db.tasks[0].done, content="true")
  inspect(db.links.get("a").unwrap_or(""), content="https://example.com")
}

///|
test "a task may refer to one written after it" {
  let db = parse(
    (
      #|gantt
      #|    dateFormat YYYY-MM-DD
      #|    Later :l, after e, 2d
      #|    Earlier :e, 2024-03-01, 1w
      #|    Loop :x, after y, 1d
      #|    Back :y, after x, 1d
      #|
    ),
  )
  // The pair that waits on each other never gets its dates.
  inspect(
    dates(db, 0.0),
    content=(
      #|l 0: 2024-03-08 00:00 .. 2024-03-10 00:00 (bar to -)
      #|e 1: 2024-03-01 00:00 .. 2024-03-08 00:00 (bar to -)
      #|x 2: - .. - (bar to -)
      #|y 3: - .. - (bar to -)
    ),
  )
}

///|
test "what upstream fails on fails here" {
  let message = (source : String) => {
    try {
      let db = parse(source)
      db.compile(0.0) |> ignore
      "no error"
    } catch {
      GanttError(message) => message
      @jison.ParseError(..) => "parse error"
      _ => "another error"
    }
  }
  inspect(message("gantt\n  topAxis\n"), content="yy.TopAxis is not a function")
  inspect(
    message("gantt\n  A :done\n"),
    content="Cannot read properties of undefined (reading 'match')",
  )
  inspect(
    message("gantt\n  dateFormat YYYY-MM-DD\n  A :a, tomorrow, 1d\n"),
    content="Invalid date:tomorrow",
  )
  inspect(
    message("gantt\n  A :3d\n"),
    content="Cannot read properties of undefined (reading 'endTime')",
  )
  inspect(
    message("gantt\n  A :a, 2024-01-01, 1d # no\n"),
    content="parse error",
  )
}

///|
test "titles go through the sanitizer's eyes" {
  // Untouched without a "<"; parsed and written back as HTML with one.
  inspect(
    sanitize_text("R&D &copy; 2024 > 2023"),
    content="R&D &copy; 2024 > 2023",
  )
  inspect(
    sanitize_text("a < b & c &copy; > d &amp; e"),
    content="a &lt; b &amp; c © &gt; d &amp; e",
  )
  try sanitize_text("<b>bold</b>") catch {
    Unsupported(_) => ()
    _ => fail("expected Unsupported")
  } noraise {
    _ => fail("expected Unsupported")
  }
}

///|
test "sorting as V8 does when the comparison is no ordering" {
  // 0 stands for a task without a start: equal to everything.
  let compare = (a : Int32, b : Int32) => {
    if a == 0 || b == 0 {
      0.0
    } else {
      (a - b).to_double()
    }
  }
  // Binary insertion for short arrays: 7 goes before 8 and 15, which it
  // is compared with, and so jumps over the unknown in between.
  let show = (items : ArrayView[Int32]) => {
    items.map(item => item.to_string()).join(" ")
  }
  let short = [8, 15, 0, 7, 0]
  v8_sort_small(short, compare)
  inspect(show(short), content="7 8 15 0 0")
  // From 16 elements on, the leading run is taken as it is first.
  let long = [8, 15, 0, 7, 0, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
  v8_sort_small(long, compare)
  inspect(show(long), content="8 15 0 7 0 20 21 22 23 24 25 26 27 28 29 30")
  let many = Array::makei(100, i => (i * 37 + 11) % 100)
  stable_sort(many, (a, b) => (a / 10 - b / 10).to_double())
  // Stable: equal tens keep the order they came in.
  inspect(show(many[0:12]), content="7 3 6 2 9 5 1 8 4 0 11 18")
}

///|
test "object keys enumerate indexes first" {
  inspect(
    object_keys(["b", "10", "9", "a", "01", "4294967295", "-1"]).join(" "),
    content="9 10 b a 01 4294967295 -1",
  )
}

///|
test "label widths depend on the scale and, in the last digits, on the position" {
  let font = @font.Stack::default()
  // Unscaled: the advance.
  inspect(bbox_width(font, "Completed task", 11.0, 0.0, 1.0), content="76.9375")
  // In a chart 508 units tall the reference page has a scrollbar and the
  // chart is drawn at about 0.98: measured in Chrome.
  let scale = text_scaling_factor(497.6875 / 508.0)
  inspect(
    bbox_width(font, "Completed task", 11.0, 134.0, scale),
    content="76.88898468017578",
  )
  inspect(
    bbox_width(font, "Active task", 11.0, 222.5, scale),
    content="54.24176025390625",
  )
  inspect(collapsed("  A   B\t C  "), content="A B C")
}
