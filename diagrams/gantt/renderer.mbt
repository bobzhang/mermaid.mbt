// A port of `ganttRenderer.js`. The arithmetic follows the original
// operation by operation; the comments say what the chart shows.

///|
/// The ticks above this number of which a custom tick interval is ignored.
const MAX_TICK_COUNT : Double = 10000.0

///|
/// The names every JavaScript object answers to, which upstream's
/// lookup tables keyed by section name trip over.
let object_members : Array[String] = [
  "__proto__", "constructor", "hasOwnProperty", "isPrototypeOf", "propertyIsEnumerable",
  "toLocaleString", "toString", "valueOf", "__defineGetter__", "__defineSetter__",
  "__lookupGetter__", "__lookupSetter__",
]

///|
/// Whether a property name is an array index, which JavaScript objects
/// enumerate first and in numeric order.
fn index_key(key : String) -> Double? {
  if key.is_empty() || key.length() > 10 {
    return None
  }
  let mut value = 0.0
  for c in key {
    guard c is ('0'..<='9') else { return None }
    value = value * 10.0 + (c.to_int() - '0').to_double()
  }
  if (key.length() > 1 && key.has_prefix("0")) || value > 4294967294.0 {
    None
  } else {
    Some(value)
  }
}

///|
/// The keys of a JavaScript object in enumeration order: array indexes
/// ascending, then the other keys in the order they were added.
fn object_keys(added : Array[String]) -> Array[String] {
  let indexes = []
  let names = []
  for key in added {
    match index_key(key) {
      Some(index) => indexes.push((index, key))
      None => names.push(key)
    }
  }
  indexes.sort_by((a, b) => a.0.compare(b.0))
  let keys = indexes.map(entry => entry.1)
  keys.append(names)
  keys
}

///|
/// The text of an SVG `<text>` as it is laid out: white space collapsed,
/// none at either end.
fn collapsed(text : String) -> String {
  let out = StringBuilder()
  let mut pending = false
  for c in text {
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u{0c}' {
      pending = true
    } else {
      if pending && !out.is_empty() {
        out.write_char(' ')
      }
      pending = false
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
let line_break : @jsregex.Regex = @jsregex.Regex::compile(
  "<\\/?br\\s*\\/?>",
  flags="i",
) catch {
  _ => abort("invalid pattern")
}

///|
let tick_interval_pattern : @jsregex.Regex = regex(
  "^([1-9]\\d*)(millisecond|second|minute|hour|day|week|month)$",
)

///|
/// `parseInt` of a string of digits.
fn parse_int(text : String) -> Double {
  @string.parse_double(text) catch {
    _ => @double.not_a_number
  }
}

///|
/// For the compact display mode: lay the tasks of one section out on as
/// few rows as their overlaps allow, numbering rows from `order_offset`.
/// Returns the index of the last row used.
fn max_intersections(
  tasks : Array[Task],
  order_offset : Int32,
) -> Int32 raise GanttError {
  let timeline = tasks.map(_ => @double.neg_infinity)
  let sorted = tasks.copy()
  // `a.startTime - b.startTime || a.order - b.order`
  sort_tasks(
    sorted,
    (a, b) => {
      let by_start = time_or_nan(a.start_time) - time_or_nan(b.start_time)
      if by_start.is_nan() || by_start == 0.0 {
        (a.order - b.order).to_double()
      } else {
        by_start
      }
    },
    consistent=tasks.iter().all(has_start),
  )
  let mut max = 0
  for task in sorted {
    for j in 0..<timeline.length() {
      // A task without a start never finds a row, and one without an
      // end blocks its row for good.
      if time_or_nan(task.start_time) >= timeline[j] {
        timeline[j] = time_or_nan(task.end_time)
        task.order = j + order_offset
        if j > max {
          max = j
        }
        break
      }
    }
  }
  max
}

///|
/// A time as a number: NaN for a missing or invalid one.
fn time_or_nan(time : Double?) -> Double {
  time.unwrap_or(@double.not_a_number)
}

///|
/// Whether the task's start is known and valid.
fn has_start(task : Task) -> Bool {
  !time_or_nan(task.start_time).is_nan()
}

///|
/// The ticks of the axis: those of the chart's `tickInterval` when it has
/// a usable one, d3's own choice otherwise.
fn axis_ticks(
  db : GanttDb,
  config : @config.Config,
  zone : @jsdate.Zone,
  scale : @d3.TimeScale,
) -> Array[Double] {
  let setting = match db.tick_interval {
    Some(interval) if interval != "" => interval
    _ => config.text("gantt.tickInterval").unwrap_or("undefined")
  }
  guard tick_interval_pattern.exec(setting) is Some(found) else {
    return scale.ticks()
  }
  let every = parse_int(found.group(1).unwrap_or(""))
  let unit = found.group(2).unwrap_or("")
  let weekday = if db.weekday != "" {
    db.weekday
  } else {
    config.text("gantt.weekday").unwrap_or("sunday")
  }
  // An interval that would yield an absurd number of ticks is ignored.
  let (min_time, max_time) = scale.domain()
  let estimate = if min_time > max_time {
    @double.infinity
  } else {
    let length = @dayjs.duration_milliseconds(unit, every)
    if length <= 0.0 {
      @double.infinity
    } else {
      ((max_time - min_time) / length).ceil()
    }
  }
  if estimate > MAX_TICK_COUNT {
    return scale.ticks()
  }
  let interval = match unit {
    "millisecond" => @d3.time_millisecond()
    "second" => @d3.time_second(zone)
    "minute" => @d3.time_minute(zone)
    "hour" => @d3.time_hour(zone)
    "day" => @d3.time_day(zone)
    "week" =>
      @d3.time_week(
        zone,
        [
          "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
        ]
        .search(weekday)
        .unwrap_or(0),
      )
    _ => @d3.time_month(zone)
  }
  match interval.every(every) {
    Some(interval) => scale.ticks_every(interval)
    None => scale.ticks()
  }
}

///|
/// Draw the chart into the context's `<svg>` element.
pub fn draw(db : GanttDb, context : @diagram.Context) -> Unit raise GanttError {
  let n = @dom.number
  let config = context.config
  let svg = context.svg
  let id = context.id
  let zone = db.zone
  if config.text("securityLevel") == Some("sandbox") {
    // Upstream renders into an <iframe> and wraps linked tasks in <a>.
    raise Unsupported("the sandbox security level")
  }
  let conf = (name : String, default : Double) => {
    config.number("gantt." + name).unwrap_or(default)
  }
  let bar_height = conf("barHeight", 20.0)
  let bar_gap = conf("barGap", 4.0)
  let top_padding = conf("topPadding", 50.0)
  let left_padding = conf("leftPadding", 75.0)
  let right_padding = conf("rightPadding", 75.0)
  let grid_line_start_padding = conf("gridLineStartPadding", 35.0)
  let font_size = conf("fontSize", 11.0)
  let section_font_size = conf("sectionFontSize", 11.0)
  let title_top_margin = conf("titleTopMargin", 25.0)
  let number_section_styles = conf("numberSectionStyles", 4.0).to_int()
  // The chart is as wide as the element the diagram sits in.
  let w = config.number("gantt.useWidth").unwrap_or(context.container_width())
  let tasks = db.compile(context.now)
  let tasks_without_vert = tasks.filter(task => !task.vert)
  let categories : Array[String] = []
  for task in tasks_without_vert {
    if !categories.contains(task.section) {
      categories.push(task.section)
    }
  }
  let section_class = (section : String) => {
    categories.search(section).map(i => i % number_section_styles)
  }
  // Rows per section, keyed like a JavaScript object.
  let category_heights : Map[String, Int32] = Map([])
  let mut h = 2.0 * top_padding
  if config.text("gantt.displayMode") == Some("compact") {
    let elements : Map[String, Array[Task]] = Map([])
    for task in tasks_without_vert {
      if object_members.contains(task.section) {
        raise GanttError(
          "categoryElements[element.section].push is not a function",
        )
      }
      match elements.get(task.section) {
        Some(list) => list.push(task)
        None => elements[task.section] = [task]
      }
    }
    let mut intersections = 0
    for category in object_keys(elements.keys().collect()) {
      let height = max_intersections(elements[category], intersections) + 1
      intersections += height
      h += height.to_double() * (bar_height + bar_gap)
      category_heights[category] = height
    }
  } else {
    h += tasks_without_vert.length().to_double() * (bar_height + bar_gap)
    for category in categories {
      if category != "__proto__" {
        category_heights[category] = tasks_without_vert
          .filter(task => task.section == category)
          .length()
      }
    }
  }
  svg.attr("viewBox", "0 0 \{n(w)} \{n(h)}") |> ignore
  // The time scale spans the earliest start to the latest end.
  let mut domain_start = @double.not_a_number
  let mut domain_end = @double.not_a_number
  for task in tasks {
    if task.start_time is Some(start) &&
      !start.is_nan() &&
      (domain_start.is_nan() || domain_start > start) {
      domain_start = start
    }
    if task.end_time is Some(end) &&
      !end.is_nan() &&
      (domain_end.is_nan() || domain_end < end) {
      domain_end = end
    }
  }
  let time_scale = @d3.TimeScale::new(zone)
    .set_domain(domain_start, domain_end)
    .set_range_round(0.0, w - left_padding - right_padding)
  let scale = (time : Double?) => time_scale.apply(time_or_nan(time))
  // Tasks are drawn in the order of their start; one whose start is not
  // known compares equal to all others.
  sort_tasks(
    tasks,
    (a, b) => {
      let a = time_or_nan(a.start_time)
      let b = time_or_nan(b.start_time)
      if a > b {
        1.0
      } else if a < b {
        -1.0
      } else {
        0.0
      }
    },
    consistent=tasks.iter().all(has_start),
  )
  let gap = bar_height + bar_gap
  // The days excluded from the chart, as bands behind everything else.
  if !(db.excludes.is_empty() && db.includes.is_empty()) {
    draw_exclude_days(
      db, svg, id, time_scale, tasks, left_padding, top_padding, gap, h, grid_line_start_padding,
    )
  }
  // The grid: an axis whose ticks run the height of the chart.
  let axis_format = if db.axis_format != "" {
    db.axis_format
  } else if db.date_format == "D" {
    "%d"
  } else {
    config.text("gantt.axisFormat").unwrap_or("%Y-%m-%d")
  }
  let format = @d3.time_format(zone, axis_format)
  let tick_size = -h + top_padding + grid_line_start_padding
  let ticks = axis_ticks(db, config, zone, time_scale).map(tick => {
    (time_scale.apply(tick), format(tick))
  })
  let bottom = svg
    .append("g")
    .attr("class", "grid")
    .attr("transform", "translate(\{n(left_padding)}, \{n(h - 50.0)})")
  @d3.axis(
    bottom,
    Bottom,
    ticks,
    time_scale.range(),
    tick_size_inner=tick_size,
    tick_size_outer=tick_size,
  )
  for text in bottom.descendants(["text"]) {
    text
    .style("text-anchor", "middle")
    .attr("fill", "#000")
    .attr("stroke", "none")
    .attr("font-size", "10")
    .attr("dy", "1em")
    |> ignore
  }
  if config.flag("gantt.topAxis") {
    let top = svg
      .append("g")
      .attr("class", "grid")
      .attr("transform", "translate(\{n(left_padding)}, \{n(top_padding)})")
    @d3.axis(
      top,
      Top,
      ticks,
      time_scale.range(),
      tick_size_inner=tick_size,
      tick_size_outer=tick_size,
    )
    for text in top.descendants(["text"]) {
      text
      .style("text-anchor", "middle")
      .attr("fill", "#000")
      .attr("stroke", "none")
      .attr("font-size", "10")
      |> ignore
    }
  }
  // Vertical markers are drawn last and take no row.
  let bars = tasks.filter(task => !task.vert)
  let markers = tasks.filter(task => task.vert)
  let drawn = bars.copy()
  drawn.append(markers)
  let rows = bars.length().to_double()
  // One background band per row, colored by section.
  let bands = svg.append("g")
  let seen_orders : Array[Int32] = []
  for task in bars {
    if seen_orders.contains(task.order) {
      continue
    }
    seen_orders.push(task.order)
    bands
    .append("rect")
    .attr("x", "0")
    .attr_number("y", task.order.to_double() * gap + top_padding - 2.0)
    .attr_number("width", w - right_padding / 2.0)
    .attr_number("height", gap)
    .attr("class", "section section\{section_class(task.section).unwrap_or(0)}")
    |> ignore
  }
  let group = svg.append("g")
  for task in drawn {
    let order = task.order.to_double()
    let start_x = scale(task.start_time)
    let end_x = scale(task.end_time)
    let center = start_x + left_padding + 0.5 * (end_x - start_x)
    let section = section_class(task.section).unwrap_or(0)
    let mut task_class = ""
    if task.active {
      if task.crit {
        task_class += " activeCrit"
      } else {
        task_class = " active"
      }
    } else if task.done {
      if task.crit {
        task_class = " doneCrit"
      } else {
        task_class = " done"
      }
    } else if task.crit {
      task_class += " crit"
    }
    if task_class.is_empty() {
      task_class = " task"
    }
    if task.milestone {
      task_class = " milestone " + task_class
    }
    if task.vert {
      task_class = " vert " + task_class
    }
    group
    .append("rect")
    .attr("id", "\{id}-\{task.id}")
    .attr("rx", "3")
    .attr("ry", "3")
    .attr_number(
      "x",
      if task.milestone {
        center - 0.5 * bar_height
      } else {
        start_x + left_padding
      },
    )
    .attr_number(
      "y",
      if task.vert {
        grid_line_start_padding
      } else {
        order * gap + top_padding
      },
    )
    .attr_number(
      "width",
      if task.milestone {
        bar_height
      } else if task.vert {
        0.08 * bar_height
      } else {
        scale(task.bar_end()) - start_x
      },
    )
    .attr_number(
      "height",
      if task.vert {
        rows * (bar_height + bar_gap) + bar_height * 2.0
      } else {
        bar_height
      },
    )
    .attr(
      "transform-origin",
      "\{n(center)}px \{n(order * gap + top_padding + 0.5 * bar_height)}px",
    )
    .attr("class", "task\{task_class}\{section} \{task.classes.join(" ")}")
    |> ignore
  }
  // The labels: inside the bar when they fit, else beside it, on the
  // right unless that would leave the chart.
  //
  // The browser measures the labels in the `<svg>` as it stands in the
  // page, already scaled to its view box: with the font scaled to match,
  // and the result scaled back.
  let font = @font.Stack::for_family(context.theme().text("fontFamily"))
  let text_scale = text_scaling_factor(context.view_box_scale(w, h))
  for task in drawn {
    let order = task.order.to_double()
    let text = group
      .append("text")
      .attr("id", "\{id}-\{task.id}-text")
      .text(task.task)
      .attr_number("font-size", font_size)
    let label = collapsed(task.task)
    // Measured once to place the label, with no position yet.
    let text_width = bbox_width(font, label, font_size, 0.0, text_scale)
    let mut start_x = scale(task.start_time)
    let mut end_x = scale(task.bar_end())
    if task.milestone {
      start_x += 0.5 * (scale(task.end_time) - scale(task.start_time)) -
        0.5 * bar_height
      end_x = start_x + bar_height
    }
    let x = if task.vert {
      scale(task.start_time) + left_padding
    } else if text_width > end_x - start_x {
      if end_x + text_width + 1.5 * left_padding > w {
        start_x + left_padding - 5.0
      } else {
        end_x + left_padding + 5.0
      }
    } else {
      (end_x - start_x) / 2.0 + start_x + left_padding
    }
    text
    .attr_number("x", x)
    .attr_number(
      "y",
      if task.vert {
        grid_line_start_padding + rows * (bar_height + bar_gap) + 60.0
      } else {
        order * gap + bar_height / 2.0 + (font_size / 2.0 - 2.0) + top_padding
      },
    )
    |> ignore
    // The class is decided anew: from the real end of the task this time,
    // and from a second measurement, of the label in its place.
    let text_width = bbox_width(font, label, font_size, x, text_scale)
    let start_x = scale(task.start_time)
    let end_x = if task.milestone {
      start_x + bar_height
    } else {
      scale(task.end_time)
    }
    let section = section_class(task.section).unwrap_or(0)
    let mut task_type = ""
    if task.active {
      task_type = if task.crit {
        "activeCritText\{section}"
      } else {
        "activeText\{section}"
      }
    }
    if task.done {
      task_type += if task.crit {
        " doneCritText\{section}"
      } else {
        " doneText\{section}"
      }
    } else if task.crit {
      task_type += " critText\{section}"
    }
    if task.milestone {
      task_type += " milestoneText"
    }
    if task.vert {
      task_type += " vertText"
    }
    let class_names = task.classes.join(" ")
    text.attr(
      "class",
      if text_width > end_x - start_x {
        if end_x + text_width + 1.5 * left_padding > w {
          "\{class_names} taskTextOutsideLeft taskTextOutside\{section} \{task_type}"
        } else {
          "\{class_names} taskTextOutsideRight taskTextOutside\{section} \{task_type} width-\{n(text_width)}"
        }
      } else {
        "\{class_names} taskText taskText\{section} \{task_type} width-\{n(text_width)}"
      },
    )
    |> ignore
  }
  // The section names down the left side, each centered on its rows.
  let labels = svg.append("g")
  let occurrences = object_keys(category_heights.keys().collect()).map(key => {
    (key, category_heights[key].to_double())
  })
  let mut previous_rows = 0.0
  for i, entry in occurrences {
    let (name, count) = entry
    let lines = line_break.split(name)
    let label = labels
      .append("text")
      .attr("dy", n(-(lines.length().to_double() - 1.0) / 2.0) + "em")
    for j, line in lines {
      let tspan = label
        .append("tspan")
        .attr("alignment-baseline", "central")
        .attr("x", "10")
      if j > 0 {
        tspan.attr("dy", "1em") |> ignore
      }
      tspan.text(line) |> ignore
    }
    if i > 0 {
      previous_rows += occurrences[i - 1].1
    }
    label
    .attr("x", "10")
    .attr_number(
      "y",
      if i > 0 {
        count * gap / 2.0 + previous_rows * gap + top_padding
      } else {
        count * gap / 2.0 + top_padding
      },
    )
    .attr_number("font-size", section_font_size)
    .attr(
      "class",
      match section_class(name) {
        Some(index) => "sectionTitle sectionTitle\{index}"
        None => "sectionTitle"
      },
    )
    |> ignore
  }
  // A line at the present moment.
  if db.today_marker != "off" {
    let today = time_scale.apply(context.now) + left_padding
    let line = svg.append("g").attr("class", "today").append("line")
    line
    .attr_number("x1", today)
    .attr_number("x2", today)
    .attr_number("y1", title_top_margin)
    .attr_number("y2", h - title_top_margin)
    .attr("class", "today")
    |> ignore
    if db.today_marker != "" {
      line.attr("style", db.today_marker.replace_all(old=",", new=";"))
      |> ignore
    }
  }
  @diagram.configure_svg_size(svg, h, w, config.flag("gantt.useMaxWidth"))
  svg
  .append("text")
  .text(db.title)
  .attr_number("x", w / 2.0)
  .attr_number("y", title_top_margin)
  .attr("class", "titleText")
  |> ignore
}

///|
/// The bands of excluded days: one rectangle per run of excluded days
/// between the first start and the last end.
fn draw_exclude_days(
  db : GanttDb,
  svg : @dom.Element,
  id : String,
  time_scale : @d3.TimeScale,
  tasks : Array[Task],
  left_padding : Double,
  top_padding : Double,
  gap : Double,
  h : Double,
  grid_line_start_padding : Double,
) -> Unit raise GanttError {
  let zone = db.zone
  let mut min_time : Double? = None
  let mut max_time : Double? = None
  for task in tasks {
    if min_time is None ||
      (task.start_time is Some(start) && min_time is Some(min) && start < min) {
      min_time = task.start_time
    }
    if max_time is None ||
      (task.end_time is Some(end) && max_time is Some(max) && end > max) {
      max_time = task.end_time
    }
  }
  guard min_time is Some(min_time) && max_time is Some(max_time) else { return }
  let first = @dayjs.Dayjs::new(zone, min_time)
  // Day by day would take too long over more than five years.
  if @dayjs.Dayjs::new(zone, max_time).diff_years(first) > 5.0 {
    return
  }
  let ranges : Array[(@dayjs.Dayjs, @dayjs.Dayjs)] = []
  let mut range : (@dayjs.Dayjs, @dayjs.Dayjs)? = None
  let mut day = first
  while day.value_of() <= max_time {
    if db.is_excluded(day) {
      range = match range {
        None => Some((day, day))
        Some((start, _)) => Some((start, day))
      }
    } else if range is Some(found) {
      ranges.push(found)
      range = None
    }
    day = day.add(1.0, "d")
  }
  // A run still open at the end of the chart is left out, as upstream.
  let n = @dom.number
  let group = svg.append("g")
  for i, entry in ranges {
    let (start, end) = entry
    let name = start.format("YYYY-MM-DD") catch {
      @dayjs.DayjsError(message) => raise GanttError(message)
    }
    let left = time_scale.apply(start.start_of_day().value_of())
    let origin_x = time_scale.apply(start.value_of()) +
      left_padding +
      0.5 *
      (time_scale.apply(end.value_of()) - time_scale.apply(start.value_of()))
    group
    .append("rect")
    .attr("id", "\{id}-exclude-\{name}")
    .attr_number("x", left + left_padding)
    .attr_number("y", grid_line_start_padding)
    .attr_number("width", time_scale.apply(end.end_of_day().value_of()) - left)
    .attr_number("height", h - top_padding - grid_line_start_padding)
    .attr(
      "transform-origin",
      "\{n(origin_x)}px \{n(i.to_double() * gap + 0.5 * h)}px",
    )
    .attr("class", "exclude-range")
    |> ignore
  }
}

///|
/// Where the task's bar ends: `renderEndTime || endTime`.
fn Task::bar_end(self : Task) -> Double? {
  match self.render_end_time {
    Some(end) => Some(end)
    None => self.end_time
  }
}

///|
/// Blink's scaling factor for SVG text: the font is laid out at the size
/// it has on screen, here under a uniform scale.
fn text_scaling_factor(scale : Double) -> Float {
  Float::from_double(((scale * scale + scale * scale) / 2.0).sqrt())
}

///|
/// The width `getBBox()` reports for a line of SVG text starting at `x`,
/// in an `<svg>` drawn at `scale` (as a text scaling factor).
///
/// Blink lays the text out with the font scaled to the screen, unites the
/// text's cell with its ink in those coordinates, and scales the box
/// back, all in single precision — so the width depends, in its last
/// digits, on where the text is.
fn bbox_width(
  font : @font.Stack,
  text : String,
  font_size : Double,
  x : Double,
  scale : Float,
) -> Double {
  let f = Float::from_double
  let size = (f(font_size) * scale).to_double()
  // A position that is not a number is no position: the text stays at 0.
  let x = if x.is_nan() { 0.0 } else { x }
  let left = f(x) * scale
  let advance = f(font.advance(text, size))
  let ink = font.ink(text, size)
  let ink_left = f(ink.x) + left
  let ink_right = ink_left + f(ink.width)
  let cell_right = left + advance
  let has_ink = ink.width > 0.0 && ink.height > 0.0
  let (low, high) = if !has_ink {
    (left, cell_right)
  } else if !(advance > 0) {
    (ink_left, ink_right)
  } else {
    (
      if ink_left < left {
        ink_left
      } else {
        left
      },
      if ink_right > cell_right {
        ink_right
      } else {
        cell_right
      },
    )
  }
  // A box set by its edges: the width grows by one step when the origin
  // plus the rounded width falls short of the far edge.
  let mut width = high - low
  if low + width < high {
    width = Float::reinterpret_from_uint(width.reinterpret_as_uint() + 1)
  }
  (width * (1 / scale)).to_double()
}
