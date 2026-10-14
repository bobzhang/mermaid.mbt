///|
/// The upper of two numbers, as `Math.max`: `NaN` if either is.
fn js_max(a : Double, b : Double) -> Double {
  if a != a || b != b {
    @journeycommon.js_number("NaN")
  } else if a > b {
    a
  } else {
    b
  }
}

///|
/// The `timeline` settings both renderers read.
priv struct Conf {
  left_margin : Double
  padding : Double
  use_max_width : Bool
  disable_multicolor : Bool
}

///|
fn Conf::new(config : @config.Config) -> Conf raise TimelineError {
  let number = (name : String, fallback : Double) => {
    match config.get("timeline.\{name}") {
      Number(n, ..) => n
      Null => fallback
      _ => raise TimelineError("timeline.\{name} must be a number")
    }
  }
  {
    left_margin: number("leftMargin", 50.0),
    padding: number("padding", 50.0),
    use_max_width: match config.get("timeline.useMaxWidth") {
      Null => false
      _ => config.flag("timeline.useMaxWidth")
    },
    disable_multicolor: config.flag("timeline.disableMulticolor"),
  }
}

///|
/// The description upstream measures a period's height with before
/// drawing it: it passes the task object where its text was meant.
const TASK_OBJECT : String = "[object Object]"

///|
/// Draw the timeline into the context's `<svg>` element, in the
/// direction the diagram text asks for.
pub fn draw(timeline : Timeline, context : @diagram.Context) -> Unit raise {
  if timeline.direction == "TD" {
    draw_vertical(timeline, context)
  } else {
    draw_horizontal(timeline, context)
  }
}

///|
/// timelineRenderer's `draw`: periods left to right along an axis, their
/// events hanging below, sections spanning their periods above.
fn draw_horizontal(
  timeline : Timeline,
  context : @diagram.Context,
) -> Unit raise {
  let n = @dom.number
  let conf = Conf::new(context.config)
  let theme = context.theme()
  let svg = context.svg
  let id = context.id
  let env = Env::new(context, id)
  svg.append("g") |> ignore
  env.init_graphics()
  let tasks = timeline.tasks
  let sections = timeline.sections
  // Heights are settled on scratch text first, so that every node of a
  // row can be as tall as the tallest.
  let mut max_section_height = 0.0
  for section in sections {
    let height = env.virtual_node_height(section, width=150.0, padding=20.0)
    max_section_height = js_max(max_section_height, height + 20.0)
  }
  let mut max_task_height = 0.0
  let mut max_event_line_length = 0.0
  for task in tasks {
    let height = env.virtual_node_height(TASK_OBJECT, width=150.0, padding=20.0)
    max_task_height = js_max(max_task_height, height + 20.0)
    let mut length = 0.0
    for event in task.events {
      length += env.virtual_node_height(event, width=150.0, padding=20.0)
    }
    if task.events.length() > 0 {
      length += (task.events.length() - 1).to_double() * 10.0
    }
    max_event_line_length = js_max(max_event_line_length, length)
  }
  let mut master_x = 50.0 + conf.left_margin
  let section_begin_y = 50.0
  let has_sections = sections.length() > 0
  if has_sections {
    for section_number, section in sections {
      let own = tasks.filter(task => task.section == section)
      let count = own.length().to_double()
      let wrapper = svg.append("g")
      env.draw_node(
        wrapper,
        section,
        section=section_number,
        width=200.0 * js_max(count, 1.0) - 50.0,
        padding=20.0,
        max_height=max_section_height,
      )
      |> ignore
      wrapper.attr(
        "transform",
        "translate(\{n(master_x)}, \{n(section_begin_y)})",
      )
      |> ignore
      if own.length() > 0 {
        draw_tasks(
          env,
          conf,
          own,
          section_number,
          master_x,
          section_begin_y + (max_section_height + 50.0),
          max_task_height,
          max_event_line_length,
          false,
        )
      }
      master_x += 200.0 * js_max(count, 1.0)
    }
  } else {
    draw_tasks(
      env, conf, tasks, 0, master_x, 50.0, max_task_height, max_event_line_length,
      true,
    )
  }
  let box = svg.bbox()
  if timeline.title != "" {
    let x = if env.look == "neo" {
      box.x * 2.0 + conf.left_margin
    } else {
      box.width / 2.0 - conf.left_margin
    }
    env.append_title(timeline.title, x)
  }
  let depth_y = if has_sections {
    max_section_height + max_task_height + 150.0
  } else {
    max_task_height + 100.0
  }
  svg
  .append("g")
  .attr("class", "lineWrapper")
  .append("line")
  .attr_number("x1", conf.left_margin)
  .attr_number("y1", depth_y)
  .attr_number("x2", box.width + 3.0 * conf.left_margin)
  .attr_number("y2", depth_y)
  .attr_number("stroke-width", 4.0)
  .attr("stroke", "black")
  .attr("marker-end", "url(#\{id}-arrowhead)")
  |> ignore
  // The neo look strokes nodes with a gradient of the theme's colours.
  if env.look == "neo" &&
    theme.flag("useGradient") &&
    env.theme_name != "neutral" {
    let defs = match svg.descendants(["defs"]) {
      [defs, ..] => defs
      [] => svg.append("defs")
    }
    let gradient = defs
      .append("linearGradient")
      .attr("id", "\{id}-gradient")
      .attr("gradientUnits", "objectBoundingBox")
      .attr("x1", "0%")
      .attr("y1", "0%")
      .attr("x2", "100%")
      .attr("y2", "0%")
    for stop in [("0%", "gradientStart"), ("100%", "gradientStop")] {
      let element = gradient.append("stop").attr("offset", stop.0)
      match theme.get(stop.1) {
        Null => ()
        _ => element.attr("stop-color", theme.text(stop.1)) |> ignore
      }
      element.attr("stop-opacity", "1") |> ignore
    }
  }
  setup_graph_viewbox(svg, conf.padding, conf.use_max_width)
}

///|
/// timelineRenderer's `drawTasks`: the periods of one section, or all of
/// them when there are no sections, side by side from `master_x`, each
/// with its events and the dashed line down through them.
fn draw_tasks(
  env : Env,
  conf : Conf,
  tasks : Array[Task],
  section_color : Int32,
  master_x : Double,
  master_y : Double,
  max_task_height : Double,
  max_event_line_length : Double,
  without_sections : Bool,
) -> Unit raise {
  let n = @dom.number
  let svg = env.svg
  let mut section_color = section_color
  let mut master_x = master_x
  let mut master_y = master_y
  let mut max_task_height = max_task_height
  for task in tasks {
    let wrapper = svg.append("g").attr("class", "taskWrapper")
    let node = env.draw_node(
      wrapper,
      task.task,
      section=section_color,
      width=150.0,
      padding=20.0,
      max_height=max_task_height,
    )
    wrapper.attr("transform", "translate(\{n(master_x)}, \{n(master_y)})")
    |> ignore
    max_task_height = js_max(max_task_height, node.height)
    // The line is added before the events it runs behind. Stepping down
    // to the events and back is kept as upstream does it: the round trip
    // can move `master_y` by a rounding error, for good.
    let line_wrapper = svg.append("g").attr("class", "lineWrapper")
    master_y += 100.0
    draw_events(env, task.events, section_color, master_x, master_y)
    master_y -= 100.0
    line_wrapper
    .append("line")
    .attr_number("x1", master_x + 190.0 / 2.0)
    .attr_number("y1", master_y + max_task_height)
    .attr_number("x2", master_x + 190.0 / 2.0)
    .attr_number(
      "y2",
      master_y + max_task_height + 100.0 + max_event_line_length + 100.0,
    )
    .attr_number("stroke-width", 2.0)
    .attr("stroke", "black")
    .attr("marker-end", "url(#\{env.id_prefix}-arrowhead)")
    .attr("stroke-dasharray", "5,5")
    |> ignore
    master_x += 200.0
    if without_sections && !conf.disable_multicolor {
      section_color += 1
    }
  }
}

///|
/// timelineRenderer's `drawEvents`: the events of one period, stacked
/// from 100 below `master_y` with a gap of 10.
fn draw_events(
  env : Env,
  events : Array[String],
  section_color : Int32,
  master_x : Double,
  master_y : Double,
) -> Unit raise {
  let n = @dom.number
  let mut y = master_y + 100.0
  for event in events {
    let wrapper = env.svg.append("g").attr("class", "eventWrapper")
    let node = env.draw_node(
      wrapper,
      event,
      section=section_color,
      width=150.0,
      padding=20.0,
      max_height=50.0,
      is_event=true,
    )
    wrapper.attr("transform", "translate(\{n(master_x)}, \{n(y)})") |> ignore
    y = y + 10.0 + node.height
  }
}
