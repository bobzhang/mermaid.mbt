///|
/// An actor of the journey: where it sorts among the actors, which also
/// picks its colour.
priv struct Actor {
  name : String
  position : Int32
  colour : String?
}

///|
/// The actors in the order upstream walks them: the keys of a JavaScript
/// object, where names that are array indices come first, in numeric
/// order, and the rest follow as inserted — sorted.
fn legend_order(names : Array[String], conf : Conf) -> Array[Actor] {
  let colours = conf.actor_colours
  let actors = names.mapi((position, name) => {
    name,
    position,
    colour: if colours.is_empty() {
      None
    } else {
      Some(colours[position % colours.length()])
    },
  })
  let indices = []
  let others = []
  for actor in actors {
    match array_index(actor.name) {
      Some(index) => indices.push((index, actor))
      None => others.push(actor)
    }
  }
  indices.sort_by((a, b) => a.0.compare(b.0))
  indices.map(pair => pair.1) + others
}

///|
/// The value of a property name that is an array index: a canonical
/// decimal integer below 2^32 - 1.
fn array_index(name : String) -> Double? {
  if name == "" ||
    name.length() > 10 ||
    !name.iter().all(c => c is ('0'..<='9')) {
    return None
  }
  if name.length() > 1 && name.has_prefix("0") {
    return None
  }
  let value = js_number(name)
  if value < 4294967295.0 {
    Some(value)
  } else {
    None
  }
}

///|
/// Where the diagram's `<svg>` sits in the reference page: mermaid renders
/// into a block at the top of a body with the default margin.
const PAGE_OFFSET : Double = 8.0

///|
/// The width `getBoundingClientRect()` reports for a line of SVG text
/// whose glyphs start at `x`: the bounding box in page coordinates, with
/// the single precision arithmetic the browser does on the way.
fn client_width(
  font : @font.Stack,
  text : String,
  size : Double,
  x : Double,
) -> Double {
  let f = Float::from_double
  // White space collapses as in any SVG text.
  let blank = try! @jsregex.Regex::compile("\\s+", flags="g")
  let text = blank.replace_all(text, _ => " ").trim(chars=" ").to_owned()
  let (ascent, descent) = font.line_metrics(size)
  ignore((ascent, descent))
  let advance = f(font.advance(text, size))
  let ink = font.ink(text, size)
  // The box is the cell united with the ink, which may overhang it.
  let mut left = f(x)
  let mut right = f(x) + advance
  if ink.width > 0.0 && ink.height > 0.0 {
    let ink_left = f(x) + f(ink.x)
    let ink_right = ink_left + f(ink.width)
    if advance > 0.0 {
      left = if ink_left < left { ink_left } else { left }
      right = if ink_right > right { ink_right } else { right }
    } else {
      left = ink_left
      right = ink_right
    }
  }
  // `RectF::SetByBounds` keeps origin and size, and the far edge is
  // computed from them again.
  let mut width = right - left
  if left + width < right {
    width = next_float(width)
  }
  let page_left = left + f(PAGE_OFFSET)
  let page_right = left + width + f(PAGE_OFFSET)
  (page_right - page_left).to_double()
}

///|
/// The next single precision number above a positive `value`.
fn next_float(value : Float) -> Float {
  Float::reinterpret_from_int(value.reinterpret_as_int() + 1)
}

///|
/// Break an actor's name into legend lines no wider than
/// `journey.maxLabelWidth`: at blanks where possible, inside a word, with
/// a hyphen, where one word alone is too wide.
fn legend_lines(
  person : String,
  conf : Conf,
  measure : (String) -> Double,
) -> Array[String] {
  let limit = conf.max_label_width
  if measure(person) <= limit {
    return [person]
  }
  let lines = []
  let mut current = ""
  for word in person.split(" ") {
    let word = word.to_owned()
    let candidate = if current != "" { "\{current} \{word}" } else { word }
    if measure(candidate) > limit {
      if current != "" {
        lines.push(current)
      }
      current = word
      if measure(word) > limit {
        let mut broken = ""
        for char in word {
          broken = broken + char.to_string()
          if measure(broken + "-") > limit {
            // `slice(0, -1)` drops one UTF-16 unit, not one character.
            lines.push(broken[:broken.length() - 1].to_owned() + "-")
            broken = char.to_string()
          }
        }
        current = broken
      }
    } else {
      current = candidate
    }
  }
  if current != "" {
    lines.push(current)
  }
  lines
}

///|
/// Draw the legend: a dot and the name of every actor. Returns the width
/// the legend needs beyond the configured left margin.
fn draw_actor_legend(
  svg : @dom.Element,
  actors : Array[Actor],
  conf : Conf,
  font : @font.Stack,
  font_size : Double,
) -> Double {
  let mut max_width = 0.0
  let mut y = 60.0
  for actor in actors {
    draw_circle(svg, cx=20.0, cy=y, fill=actor.colour, position=actor.position)
    // The name is measured in a scratch element without a position.
    let lines = legend_lines(actor.name, conf, text => {
      client_width(font, text, font_size, 0.0)
    })
    for index, line in lines {
      let x = 40.0
      draw_text(
        svg,
        x~,
        y=y + 7.0 + index.to_double() * 20.0,
        text=line,
        text_margin=conf.box_text_margin,
      )
      |> ignore
      let line_break = try! @jsregex.Regex::compile("<br\\s*/?>", flags="gi")
      let line_width = client_width(
        font,
        line_break.replace_all(line, _ => " "),
        font_size,
        x + conf.box_text_margin * 2.0,
      )
      // The margin only grows for lines wider than half of it.
      if line_width > max_width && line_width > conf.left_margin - line_width {
        max_width = line_width
      }
    }
    y += (lines.length().to_double() * 20.0).max(20.0)
  }
  max_width
}

///|
/// The extent of everything drawn, as upstream's `bounds` tracks it.
priv struct Bounds {
  mut start_x : Double
  mut stop_x : Double
  mut start_y : Double
  mut stop_y : Double
  mut empty : Bool
}

///|
fn Bounds::insert(
  self : Bounds,
  start_x : Double,
  start_y : Double,
  stop_x : Double,
  stop_y : Double,
) -> Unit {
  let (x0, x1) = (js_min(start_x, stop_x), js_max(start_x, stop_x))
  let (y0, y1) = (js_min(start_y, stop_y), js_max(start_y, stop_y))
  if self.empty {
    self.empty = false
    self.start_x = x0
    self.start_y = y0
    self.stop_x = x1
    self.stop_y = y1
  } else {
    self.start_x = js_min(x0, self.start_x)
    self.start_y = js_min(y0, self.start_y)
    self.stop_x = js_max(x1, self.stop_x)
    self.stop_y = js_max(y1, self.stop_y)
  }
}

///|
/// `Math.min`, which is `NaN` as soon as one argument is.
fn js_min(a : Double, b : Double) -> Double {
  if a != a || b != b {
    @double.not_a_number
  } else if a < b {
    a
  } else {
    b
  }
}

///|
/// `Math.max`, which is `NaN` as soon as one argument is.
fn js_max(a : Double, b : Double) -> Double {
  if a != a || b != b {
    @double.not_a_number
  } else if a > b {
    a
  } else {
    b
  }
}

///|
/// Draw the sections and their tasks, left to right.
fn draw_tasks(
  svg : @dom.Element,
  journey : Journey,
  actors : Array[Actor],
  conf : Conf,
  left_margin : Double,
  bounds : Bounds,
  id : String,
) -> Unit {
  let tasks = journey.tasks
  let task_y = conf.height * 2.0 + conf.diagram_margin_y
  let fills = conf.section_fills
  let colours = conf.section_colours
  let mut last_section = ""
  let mut section_number = 0
  let mut fill = Some("#CCC")
  let mut colour = Some("black")
  // The remainder by the number of fills, `NaN` when there are none.
  let mut num = "0"
  for i, task in tasks {
    let x = i.to_double() * conf.task_margin +
      i.to_double() * conf.width +
      left_margin
    if last_section != task.section {
      if fills.is_empty() {
        fill = None
        num = "NaN"
      } else {
        fill = Some(fills[section_number % fills.length()])
        num = (section_number % fills.length()).to_string()
      }
      colour = if colours.is_empty() {
        None
      } else {
        Some(colours[section_number % colours.length()])
      }
      // A section spans the tasks that follow it under the same name.
      let mut count = 0
      for other in tasks[i:] {
        if other.section != task.section {
          break
        }
        count += 1
      }
      let count = count.to_double()
      let group = svg.append("g")
      let width = conf.width * count + conf.diagram_margin_x * (count - 1.0)
      let class = "journey-section section-type-\{num}"
      draw_rect(group, x~, y=50.0, width~, height=conf.height, fill~, class~)
      draw_boxed_text(
        conf,
        task.section,
        group,
        x,
        50.0,
        width,
        conf.height,
        class~,
        colour~,
      )
      last_section = task.section
      section_number += 1
    }
    // The task: a dashed line down to the baseline, the face on it at the
    // height of the score, the box, the actors' dots and the text.
    let center = x + conf.width / 2.0
    let group = svg.append("g")
    group
    .append("line")
    .attr("id", "\{id}-task\{i}")
    .attr_number("x1", center)
    .attr_number("y1", task_y)
    .attr_number("x2", center)
    .attr_number("y2", 450.0)
    .attr("class", "task-line")
    .attr("stroke-width", "1px")
    .attr("stroke-dasharray", "4 2")
    .attr("stroke", "#666")
    |> ignore
    draw_face(
      group,
      cx=center,
      cy=300.0 + (5.0 - task.score) * 30.0,
      score=task.score,
    )
    draw_rect(
      group,
      x~,
      y=task_y,
      width=conf.width,
      height=conf.height,
      fill~,
      class="task task-type-\{num}",
    )
    let mut dot_x = x + 14.0
    for person in task.people {
      guard actors.search_by(actor => actor.name == person) is Some(index) else {
        continue
      }
      let actor = actors[index]
      draw_circle(
        group,
        cx=dot_x,
        cy=task_y,
        fill=actor.colour,
        position=actor.position,
        title=person,
      )
      dot_x += 10.0
    }
    draw_boxed_text(
      conf,
      task.task,
      group,
      x,
      task_y,
      conf.width,
      conf.height,
      class="task",
      colour~,
    )
    bounds.insert(
      x,
      task_y,
      x + conf.diagram_margin_x + conf.task_margin,
      450.0,
    )
  }
}

///|
/// The size text is measured at: the theme's font size, in pixels.
fn theme_font_size(theme : @theme.Theme) -> Double raise JourneyError {
  let text = theme.text("fontSize")
  let number = match text.strip_suffix("px") {
    Some(number) => number.to_owned()
    None => text
  }
  let value = js_number(number)
  if value != value || js_trim(number) == "" {
    raise JourneyError("font size \{text} is not in pixels")
  }
  value
}

///|
/// Draw the journey into the context's `<svg>` element.
pub fn draw(
  journey : Journey,
  context : @diagram.Context,
) -> Unit raise JourneyError {
  let n = @dom.number
  let conf = Conf::new(context.config)
  let theme = context.theme()
  let svg = context.svg
  let id = context.id
  svg
  .append("defs")
  .append("marker")
  .attr("id", "\{id}-arrowhead")
  .attr_number("refX", 5.0)
  .attr_number("refY", 2.0)
  .attr_number("markerWidth", 6.0)
  .attr_number("markerHeight", 4.0)
  .attr("orient", "auto")
  .append("path")
  .attr("d", "M 0,0 V 4 L6,2 Z")
  |> ignore
  let actors = legend_order(journey.actors(), conf)
  let font = @font.Stack::for_family(theme.text("fontFamily"))
  let max_width = draw_actor_legend(
    svg,
    actors,
    conf,
    font,
    theme_font_size(theme),
  )
  let left_margin = conf.left_margin + max_width
  let bounds : Bounds = {
    start_x: 0.0,
    stop_x: 0.0,
    start_y: 0.0,
    stop_y: 0.0,
    empty: true,
  }
  bounds.insert(0.0, 0.0, left_margin, actors.length().to_double() * 50.0)
  draw_tasks(svg, journey, actors, conf, left_margin, bounds, id)
  if journey.title != "" {
    let title = svg
      .append("text")
      .text(journey.title)
      .attr_number("x", left_margin)
    attr_json(title, "font-size", conf.title_font_size)
    title.attr("font-weight", "bold").attr_number("y", 25.0) |> ignore
    attr_json(title, "fill", conf.title_color)
    attr_json(title, "font-family", conf.title_font_family)
  }
  let height = bounds.stop_y - bounds.start_y + 2.0 * conf.diagram_margin_y
  let width = left_margin + bounds.stop_x + 2.0 * conf.diagram_margin_x
  @diagram.configure_svg_size(svg, height, width, conf.use_max_width)
  // The activity line; its stroke width is taken off the end so that the
  // arrow head stays inside.
  svg
  .append("line")
  .attr_number("x1", left_margin)
  .attr_number("y1", conf.height * 4.0)
  .attr_number("x2", width - left_margin - 4.0)
  .attr_number("y2", conf.height * 4.0)
  .attr_number("stroke-width", 4.0)
  .attr("stroke", "black")
  .attr("marker-end", "url(#\{id}-arrowhead)")
  |> ignore
  let extra = if journey.title != "" { 70.0 } else { 0.0 }
  svg
  .attr("viewBox", "\{n(bounds.start_x)} -25 \{n(width)} \{n(height + extra)}")
  .attr("preserveAspectRatio", "xMinYMin meet")
  .attr_number("height", height + extra + 25.0)
  |> ignore
}
