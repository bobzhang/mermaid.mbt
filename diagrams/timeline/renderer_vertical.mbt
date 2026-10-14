///|
/// The width of a period's text in the vertical layout.
const NODE_WIDTH : Double = 200.0

///|
const NODE_PADDING : Double = 5.0

///|
/// The width of an event's text.
const EVENT_WIDTH : Double = 300.0

///|
/// Between the events of one period.
const EVENT_SPACING : Double = 10.0

///|
/// Between a section's box and its first period.
const SECTION_TASK_GAP : Double = 20.0

///|
/// Between a period and the axis on its right.
const TASK_AXIS_GAP : Double = 20.0

///|
/// Between one period's block and the next.
const TASK_VERTICAL_GAP : Double = 30.0

///|
/// Between the axis and the events on its right.
const EVENT_AXIS_GAP : Double = 50.0

///|
/// timelineRendererVertical's `draw`: the axis runs down, periods on its
/// left, their events on its right, sections across both.
///
/// Upstream passes no diagram id to its drawing helpers here, so ids read
/// `undefined-...` and the lines point at an `#arrowhead` nothing
/// defines.
fn draw_vertical(timeline : Timeline, context : @diagram.Context) -> Unit raise {
  let n = @dom.number
  let conf = Conf::new(context.config)
  let svg = context.svg
  let env = Env::new(context, "undefined")
  svg.append("g") |> ignore
  env.init_graphics()
  let tasks = timeline.tasks
  let sections = timeline.sections
  let master_x = 50.0 + conf.left_margin
  let content_top_y = 50.0
  let left_width = NODE_WIDTH + NODE_PADDING * 2.0 + TASK_AXIS_GAP
  let right_width = EVENT_WIDTH + NODE_PADDING * 2.0 + EVENT_AXIS_GAP
  let has_sections = sections.length() > 0
  let timeline_x = master_x + left_width
  let section_width = js_max(
    50.0,
    left_width + right_width - NODE_PADDING * 2.0,
  )
  let mut max_section_height = 0.0
  for section in sections {
    let height = env.virtual_node_height(
      section,
      width=section_width,
      padding=NODE_PADDING,
    )
    max_section_height = js_max(max_section_height, height)
  }
  let mut max_task_height = 0.0
  let mut max_event_stack_height = 0.0
  for task in tasks {
    let height = env.virtual_node_height(
      TASK_OBJECT,
      width=NODE_WIDTH,
      padding=NODE_PADDING,
    )
    max_task_height = js_max(max_task_height, height)
    let mut stack = 0.0
    for event in task.events {
      stack += env.virtual_node_height(
        event,
        width=EVENT_WIDTH,
        padding=NODE_PADDING,
      )
    }
    if task.events.length() > 0 {
      stack += (task.events.length() - 1).to_double() * EVENT_SPACING
    }
    max_event_stack_height = js_max(max_event_stack_height, stack)
  }
  let task_spacing = js_max(max_task_height, max_event_stack_height) +
    TASK_VERTICAL_GAP
  let mut master_y = 50.0
  if has_sections {
    for section_number, section in sections {
      let own = tasks.filter(task => task.section == section)
      let wrapper = svg.append("g")
      let node = env.draw_node(
        wrapper,
        section,
        section=section_number,
        width=section_width,
        padding=NODE_PADDING,
        max_height=max_section_height,
      )
      wrapper.attr(
        "transform",
        "translate(\{n(timeline_x - left_width)}, \{n(master_y)})",
      )
      |> ignore
      if own.length() > 0 {
        draw_tasks_vertical(
          env,
          conf,
          own,
          section_number,
          timeline_x,
          master_y + node.height + SECTION_TASK_GAP,
          max_task_height,
          task_spacing,
          false,
        )
      }
      let count = own.length().to_double()
      master_y += node.height +
        SECTION_TASK_GAP +
        task_spacing * js_max(count, 1.0) -
        (if own.length() > 0 { TASK_VERTICAL_GAP * 2.0 } else { 0.0 })
    }
  } else {
    draw_tasks_vertical(
      env, conf, tasks, 0, timeline_x, master_y, max_task_height, task_spacing, true,
    )
  }
  let mut box = svg.bbox()
  if timeline.title != "" {
    env.append_title(timeline.title, box.width / 2.0 - conf.left_margin)
    box = svg.bbox()
  }
  // The axis starts two lines of text above the content and ends below
  // everything drawn.
  let font_size = match context.config.get("fontSize") {
    Number(size, ..) => size
    String(size) => @diagram.parse_font_size(size).unwrap_or(16.0)
    _ => 16.0
  }
  let line_wrapper = @dom.Element::new("g").attr("class", "lineWrapper")
  line_wrapper
  .append("line")
  .attr_number("x1", timeline_x)
  .attr_number("y1", content_top_y - font_size * 2.0)
  .attr_number("x2", timeline_x)
  .attr_number("y2", box.y + box.height + (font_size * 0.5 + 20.0))
  .attr_number("stroke-width", 4.0)
  .attr("stroke", "black")
  .attr("marker-end", "url(#arrowhead)")
  |> ignore
  // `lower()`: the axis goes first, before even the stylesheet.
  match svg.child_elements() {
    [first, ..] => svg.insert_before(line_wrapper, first)
    [] => svg.append_child(line_wrapper)
  }
  setup_graph_viewbox(svg, conf.padding, conf.use_max_width)
}

///|
/// The periods of one section, or all of them, stacked from `master_y`
/// with their events beside them.
fn draw_tasks_vertical(
  env : Env,
  conf : Conf,
  tasks : Array[Task],
  section_color : Int32,
  timeline_x : Double,
  master_y : Double,
  max_task_height : Double,
  task_spacing : Double,
  without_sections : Bool,
) -> Unit raise {
  let n = @dom.number
  let svg = env.svg
  let mut section_color = section_color
  let mut master_y = master_y
  let mut max_task_height = max_task_height
  for task in tasks {
    let wrapper = svg.append("g").attr("class", "taskWrapper")
    let node = env.draw_node(
      wrapper,
      task.task,
      section=section_color,
      width=NODE_WIDTH,
      padding=NODE_PADDING,
      max_height=max_task_height,
    )
    let task_x = timeline_x - TASK_AXIS_GAP - node.width
    wrapper.attr("transform", "translate(\{n(task_x)}, \{n(master_y)})")
    |> ignore
    max_task_height = js_max(max_task_height, node.height)
    // Each event is joined to the axis by a dashed line at its middle.
    let events_x = timeline_x + EVENT_AXIS_GAP
    let mut y = master_y
    for event in task.events {
      let wrapper = svg.append("g").attr("class", "eventWrapper")
      let node = env.draw_node(
        wrapper,
        event,
        section=section_color,
        width=EVENT_WIDTH,
        padding=NODE_PADDING,
        max_height=0.0,
      )
      wrapper.attr("transform", "translate(\{n(events_x)}, \{n(y)})") |> ignore
      let line_y = y + node.height / 2.0
      svg
      .append("g")
      .attr("class", "lineWrapper")
      .append("line")
      .attr_number("x1", timeline_x)
      .attr_number("y1", line_y)
      .attr_number("x2", events_x)
      .attr_number("y2", line_y)
      .attr_number("stroke-width", 2.0)
      .attr("stroke", "black")
      .attr("marker-end", "url(#arrowhead)")
      .attr("stroke-dasharray", "5,5")
      |> ignore
      y = y + node.height + EVENT_SPACING
    }
    master_y = master_y + task_spacing
    if without_sections && !conf.disable_multicolor {
      section_color += 1
    }
  }
}
