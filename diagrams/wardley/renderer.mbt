///|
const PI : Double = 3.141592653589793

///|
/// The stages of evolution of a map that names none.
let default_stages : Array[String] = [
  "Genesis", "Custom Built", "Product", "Commodity",
]

///|
/// The colors of a map: upstream's `getTheme`.
priv struct Colors {
  background : String
  axis : String
  axis_text : String
  grid : String
  component_fill : String
  component_stroke : String
  component_label : String
  link_stroke : String
  evolution_stroke : String
}

///|
/// A variable as an attribute holds it; nothing when it is not set.
fn variable_text(value : Json) -> String? {
  match value {
    String(text) => Some(text)
    Number(number, ..) => Some(@dom.number(number))
    True => Some("true")
    False => Some("false")
    _ => None
  }
}

///|
fn Colors::new(context : @diagram.Context) -> Colors {
  let theme = context.theme()
  // `themeVariables.wardley?.name ?? themeVariables[fallback] ?? default`
  let color = (name : String, fallback : String, default : String) => {
    match variable_text(theme.nested("wardley", name)) {
      Some(text) => text
      None =>
        if fallback == "" {
          default
        } else {
          variable_text(theme.get(fallback)).unwrap_or(default)
        }
    }
  }
  {
    background: color("backgroundColor", "background", "#fff"),
    axis: color("axisColor", "", "#000"),
    axis_text: color("axisTextColor", "primaryTextColor", "#222"),
    grid: color("gridColor", "", "rgba(100, 100, 100, 0.2)"),
    component_fill: color("componentFill", "", "#fff"),
    component_stroke: color("componentStroke", "", "#000"),
    component_label: color("componentLabelColor", "primaryTextColor", "#222"),
    link_stroke: color("linkStroke", "", "#000"),
    evolution_stroke: color("evolutionStroke", "", "#dc3545"),
  }
}

///|
/// The settings of the `wardley-beta` section of the configuration:
/// upstream's `getConfigValues`.
priv struct Settings {
  width : Double
  height : Double
  padding : Double
  node_radius : Double
  node_label_offset : Double
  axis_font_size : Double
  label_font_size : Double
  show_grid : Bool
  use_max_width : Bool
}

///|
fn Settings::new(context : @diagram.Context) -> Settings raise WardleyError {
  let config = context.config
  // `wardleyConfig?.name ?? default`; anything but a number would be
  // computed with as JavaScript coerces it, which is not ported.
  let number = (name : String, default : Double) => {
    match config.get("wardley-beta." + name) {
      Null => default
      Number(value, ..) => value
      _ => raise Unsupported("wardley-beta.\{name} is not a number")
    }
  }
  let flag = (name : String, default : Bool) => {
    match config.get("wardley-beta." + name) {
      Null => default
      _ => config.flag("wardley-beta." + name)
    }
  }
  {
    width: number("width", 900.0),
    height: number("height", 600.0),
    padding: number("padding", 48.0),
    node_radius: number("nodeRadius", 6.0),
    node_label_offset: number("nodeLabelOffset", 8.0),
    axis_font_size: number("axisFontSize", 12.0),
    label_font_size: number("labelFontSize", 10.0),
    show_grid: flag("showGrid", false),
    use_max_width: flag("useMaxWidth", true),
  }
}

///|
/// Where a node is drawn. The parent of a pipeline is moved onto the box
/// of its pipeline.
priv struct Position {
  mut x : Double
  mut y : Double
}

///|
/// What the parts of the drawing share.
priv struct Scene {
  map : Wardley
  id : String
  settings : Settings
  colors : Colors
  width : Double
  height : Double
  chart_width : Double
  chart_height : Double
  /// The side of the square that stands for the parent of a pipeline.
  square_size : Double
  /// The `<g class="wardley-map">` everything is drawn in.
  root : @dom.Element
  positions : Map[String, Position]
}

///|
/// The horizontal place of an evolution, a percentage.
fn Scene::project_x(self : Scene, value : Double) -> Double {
  self.settings.padding + value / 100.0 * self.chart_width
}

///|
/// The vertical place of a visibility, a percentage.
fn Scene::project_y(self : Scene, value : Double) -> Double {
  self.height - self.settings.padding - value / 100.0 * self.chart_height
}

///|
/// Draw the map into the context's `<svg>` element.
pub fn draw(
  map : Wardley,
  context : @diagram.Context,
) -> Unit raise WardleyError {
  let n = @dom.number
  let settings = Settings::new(context)
  let colors = Colors::new(context)
  let id = context.id
  let svg = context.svg
  let (width, height) = match map.size {
    Some(size) => size
    None => (settings.width, settings.height)
  }
  // `svg.selectAll('*').remove()`: the stylesheet goes too, so nothing
  // but the attributes below styles the map, and its text is in the
  // browser's standard font.
  for child in svg.child_elements() {
    child.remove()
  }
  @diagram.configure_svg_size(svg, height, width, settings.use_max_width)
  svg.attr("viewBox", "0 0 \{n(width)} \{n(height)}") |> ignore
  let root = svg.append("g").attr("class", "wardley-map")
  let defs = svg.append("defs")
  let marker = (
    marker_id : String,
    ref_x : String,
    size : String,
    orient : String,
    path : String,
    fill : String,
  ) => {
    defs
    .append("marker")
    .attr("id", marker_id)
    .attr("viewBox", "0 0 10 10")
    .attr("refX", ref_x)
    .attr("refY", "5")
    .attr("markerWidth", size)
    .attr("markerHeight", size)
    .attr("orient", orient)
    .append("path")
    .attr("d", path)
    .attr("fill", fill)
    .attr("stroke", "none")
    |> ignore
  }
  // The head of an evolution arrow, then those of the flows along links.
  marker(
    "arrow-\{id}",
    "9",
    "6",
    "auto-start-reverse",
    "M 0 0 L 10 5 L 0 10 z",
    colors.evolution_stroke,
  )
  marker(
    "link-arrow-end-\{id}",
    "9",
    "5",
    "auto",
    "M 0 0 L 10 5 L 0 10 z",
    colors.link_stroke,
  )
  marker(
    "link-arrow-start-\{id}",
    "1",
    "5",
    "auto",
    "M 10 0 L 0 5 L 10 10 z",
    colors.link_stroke,
  )
  root
  .append("rect")
  .attr("class", "wardley-background")
  .attr("width", n(width))
  .attr("height", n(height))
  .attr("fill", colors.background)
  |> ignore
  let padding = settings.padding
  let chart_width = width - padding * 2.0
  let chart_height = height - padding * 2.0
  if map.title != "" {
    root
    .append("text")
    .attr("class", "wardley-title")
    .attr("x", n(width / 2.0))
    .attr("y", n(padding / 2.0))
    .attr("fill", colors.axis_text)
    .attr("font-size", n(settings.axis_font_size * 1.05))
    .attr("font-weight", "bold")
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "middle")
    .text(map.title)
    |> ignore
  }
  let scene : Scene = {
    map,
    id,
    settings,
    colors,
    width,
    height,
    chart_width,
    chart_height,
    square_size: settings.node_radius * 1.6,
    root,
    positions: Map([]),
  }
  scene.draw_axes()
  scene.draw_stages()
  if settings.show_grid {
    scene.draw_grid()
  }
  for node in map.nodes {
    scene.positions[node.id] = {
      x: scene.project_x(node.x),
      y: scene.project_y(node.y),
    }
  }
  scene.draw_pipelines()
  scene.draw_links()
  scene.draw_trends()
  scene.draw_nodes()
  scene.draw_annotations(context)
  scene.draw_notes()
  scene.draw_accelerators()
}

///|
/// The two axes and their names.
fn Scene::draw_axes(self : Scene) -> Unit {
  let n = @dom.number
  let { width, height, colors, chart_width, chart_height, .. } = self
  let padding = self.settings.padding
  let font_size = n(self.settings.axis_font_size)
  let group = self.root.append("g").attr("class", "wardley-axes")
  group
  .append("line")
  .attr("x1", n(padding))
  .attr("x2", n(width - padding))
  .attr("y1", n(height - padding))
  .attr("y2", n(height - padding))
  .attr("stroke", colors.axis)
  .attr("stroke-width", "1")
  |> ignore
  group
  .append("line")
  .attr("x1", n(padding))
  .attr("x2", n(padding))
  .attr("y1", n(padding))
  .attr("y2", n(height - padding))
  .attr("stroke", colors.axis)
  .attr("stroke-width", "1")
  |> ignore
  group
  .append("text")
  .attr("class", "wardley-axis-label wardley-axis-label-x")
  .attr("x", n(padding + chart_width / 2.0))
  .attr("y", n(height - padding / 4.0))
  .attr("fill", colors.axis_text)
  .attr("font-size", font_size)
  .attr("font-weight", "bold")
  .attr("text-anchor", "middle")
  .text("Evolution")
  |> ignore
  let label_x = n(padding / 3.0)
  let label_y = n(padding + chart_height / 2.0)
  group
  .append("text")
  .attr("class", "wardley-axis-label wardley-axis-label-y")
  .attr("x", label_x)
  .attr("y", label_y)
  .attr("fill", colors.axis_text)
  .attr("font-size", font_size)
  .attr("font-weight", "bold")
  .attr("text-anchor", "middle")
  .attr("transform", "rotate(-90 \{label_x} \{label_y})")
  .text("Visibility")
  |> ignore
}

///|
/// The stages of evolution along the horizontal axis: a name under each
/// and a dashed line between two.
fn Scene::draw_stages(self : Scene) -> Unit {
  let n = @dom.number
  let { height, colors, chart_width, .. } = self
  let padding = self.settings.padding
  let stages = if self.map.stages.length() > 0 {
    self.map.stages
  } else {
    default_stages
  }
  let group = self.root.append("g").attr("class", "wardley-stages")
  // Where each stage starts and ends, as fractions of the axis: at the
  // boundaries given, when every stage has one, or else evenly.
  let spans : Array[(Double, Double)] = []
  match self.map.stage_boundaries {
    Some(boundaries) if boundaries.length() == stages.length() => {
      let mut previous = 0.0
      for boundary in boundaries {
        spans.push((previous, boundary))
        previous = boundary
      }
    }
    _ => {
      let stage_width = 1.0 / stages.length().to_double()
      for index in 0..<stages.length() {
        spans.push(
          (
            index.to_double() * stage_width,
            (index + 1).to_double() * stage_width,
          ),
        )
      }
    }
  }
  for index, stage in stages {
    let (start, end) = spans[index]
    let start_x = padding + start * chart_width
    let end_x = padding + end * chart_width
    let center_x = (start_x + end_x) / 2.0
    if index > 0 {
      group
      .append("line")
      .attr("x1", n(start_x))
      .attr("x2", n(start_x))
      .attr("y1", n(padding))
      .attr("y2", n(height - padding))
      .attr("stroke", "#000")
      .attr("stroke-width", "1")
      .attr("stroke-dasharray", "5 5")
      .attr("opacity", "0.8")
      |> ignore
    }
    group
    .append("text")
    .attr("class", "wardley-stage-label")
    .attr("x", n(center_x))
    .attr("y", n(height - padding / 1.5))
    .attr("fill", colors.axis_text)
    .attr("font-size", n(self.settings.axis_font_size - 2.0))
    .attr("text-anchor", "middle")
    .text(stage)
    |> ignore
  }
}

///|
/// The grid of `showGrid`: three lines each way.
fn Scene::draw_grid(self : Scene) -> Unit {
  let n = @dom.number
  let { width, height, colors, chart_width, chart_height, .. } = self
  let padding = self.settings.padding
  let group = self.root.append("g").attr("class", "wardley-grid")
  for i in 1..<4 {
    let ratio = i.to_double() / 4.0
    let x = padding + chart_width * ratio
    group
    .append("line")
    .attr("x1", n(x))
    .attr("x2", n(x))
    .attr("y1", n(padding))
    .attr("y2", n(height - padding))
    .attr("stroke", colors.grid)
    .attr("stroke-dasharray", "2 6")
    |> ignore
    let y = n(height - padding - chart_height * ratio)
    group
    .append("line")
    .attr("x1", n(padding))
    .attr("x2", n(width - padding))
    .attr("y1", y)
    .attr("y2", y)
    .attr("stroke", colors.grid)
    .attr("stroke-dasharray", "2 6")
    |> ignore
  }
}

///|
/// The boxes of the pipelines and the dotted lines between their
/// components. The parent of each pipeline moves to the top of its box.
fn Scene::draw_pipelines(self : Scene) -> Unit {
  let n = @dom.number
  let { map, colors, positions, .. } = self
  if map.pipelines.length() == 0 {
    return
  }
  let boxes = self.root.append("g").attr("class", "wardley-pipelines")
  let links = self.root.append("g").attr("class", "wardley-pipeline-links")
  for pipeline in map.pipelines {
    if pipeline.component_ids.length() == 0 {
      continue
    }
    // The components from left to right; those in the same place stay in
    // the order they were written (`Array.prototype.sort` is stable).
    let sorted : Array[(Position, Node)] = []
    for component_id in pipeline.component_ids {
      guard positions.get(component_id) is Some(position) &&
        map.node(component_id) is Some(node) else {
        continue
      }
      let mut at = sorted.length()
      while at > 0 && sorted[at - 1].1.x > node.x {
        at -= 1
      }
      sorted.insert(at, (position, node))
    }
    for i in 0..<(sorted.length() - 1) {
      let current = sorted[i].0
      let next = sorted[i + 1].0
      links
      .append("line")
      .attr("class", "wardley-pipeline-evolution-link")
      .attr("x1", n(current.x))
      .attr("y1", n(current.y))
      .attr("x2", n(next.x))
      .attr("y2", n(next.y))
      .attr("stroke", colors.link_stroke)
      .attr("stroke-width", "1")
      .attr("stroke-dasharray", "4 4")
      |> ignore
    }
    let mut min_x = @double.infinity
    let mut max_x = @double.neg_infinity
    let mut y = 0.0
    for component_id in pipeline.component_ids {
      if positions.get(component_id) is Some(position) {
        min_x = js_min(min_x, position.x)
        max_x = js_max(max_x, position.x)
        y = position.y
      }
    }
    if min_x != @double.infinity && max_x != @double.neg_infinity {
      let padding = 15.0
      let height = self.settings.node_radius * 4.0
      let box_top = y - height / 2.0
      // The parent sits astride the top edge of the box, a third of it
      // inside.
      if positions.get(pipeline.node_id) is Some(parent) {
        parent.x = (min_x + max_x) / 2.0
        parent.y = box_top - self.square_size / 6.0
      }
      boxes
      .append("rect")
      .attr("class", "wardley-pipeline-box")
      .attr("x", n(min_x - padding))
      .attr("y", n(box_top))
      .attr("width", n(max_x - min_x + padding * 2.0))
      .attr("height", n(height))
      .attr("fill", "none")
      .attr("stroke", colors.axis)
      .attr("stroke-width", "1.5")
      .attr("rx", "4")
      .attr("ry", "4")
      |> ignore
    }
  }
}

///|
/// `Math.min` of two numbers.
fn js_min(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a < b {
    a
  } else {
    b
  }
}

///|
/// `Math.max` of two numbers.
fn js_max(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a > b {
    a
  } else {
    b
  }
}
