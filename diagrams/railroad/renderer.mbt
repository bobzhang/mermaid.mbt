///|
/// A drawn expression: its element, not yet placed, and how far it
/// reaches above and below the line that runs through it.
priv struct Rendered {
  element : @dom.Element
  width : Double
  height : Double
  up : Double
  down : Double
}

///|
priv struct Renderer {
  options : Options
  font : @font.Stack
}

///|
/// The font the browser measures text in, for the `font-family` the text
/// is given.
fn measuring_font(family : String) -> @font.Stack raise Unsupported {
  @journeycommon.family_font(family) catch {
    @journeycommon.MeasureError(message) => raise Unsupported(message)
  }
}

///|
/// The renderer's `measureText`: the size of the box `getBBox()` reports
/// for the text alone in a `<text>` element, nothing when it is blank.
fn Renderer::measure(
  self : Renderer,
  text : String,
) -> (Double, Double) raise Unsupported {
  let text = @journeycommon.collapse_white_space(text)
  if text == "" {
    return (0.0, 0.0)
  }
  @journeycommon.require_glyphs(self.font, text) catch {
    @journeycommon.MeasureError(message) => raise Unsupported(message)
  }
  let box = self.font.bbox(text, self.options.font_size)
  (box.width, box.height)
}

///|
/// A box with text in the middle: a terminal, a non-terminal or special
/// text. Only a terminal's corners are rounded.
fn Renderer::boxed(
  self : Renderer,
  class_name : String,
  text : String,
) -> Rendered raise Unsupported {
  let padding = self.options.padding
  let (text_width, text_height) = self.measure(text)
  let width = text_width + padding * 2.0
  let height = text_height + padding * 2.0
  let group = @dom.Element::new("g").attr("class", class_name)
  let rect = group
    .append("rect")
    .attr_number("x", 0.0)
    .attr_number("y", 0.0)
    .attr_number("width", width)
    .attr_number("height", height)
  if class_name == "railroad-terminal" {
    rect.attr_number("rx", 10.0).attr_number("ry", 10.0) |> ignore
  }
  group
  .append("text")
  .attr_number("x", width / 2.0)
  .attr_number("y", height / 2.0)
  .text(text)
  |> ignore
  { element: group, width, height, up: height / 2.0, down: height / 2.0, }
}

///|
/// `translate(x, y)` as the renderer writes it.
fn place(element : @dom.Element, x : Double, y : Double) -> Unit {
  let n = @dom.number
  element.attr("transform", "translate(\{n(x)}, \{n(y)})") |> ignore
}

///|
/// A track.
fn line(group : @dom.Element, path : PathBuilder) -> Unit {
  group.append("path").attr("class", "railroad-line").attr("d", path.build())
  |> ignore
}

///|
/// `renderSequence`: the elements side by side on one line, joined by
/// short tracks.
fn Renderer::sequence(
  self : Renderer,
  elements : Array[Node],
) -> Rendered raise Unsupported {
  let separation = self.options.horizontal_separation
  let rendered = elements.map(element => self.expression(element))
  let mut total_width = 0.0
  let mut max_up = 0.0
  let mut max_down = 0.0
  for r in rendered {
    total_width += r.width
    max_up = max(max_up, r.up)
    max_down = max(max_down, r.down)
  }
  total_width += (rendered.length() - 1).to_double() * separation
  let group = @dom.Element::new("g").attr("class", "railroad-sequence")
  let mut x = 0.0
  for i, r in rendered {
    let y = max_up - r.up
    group.append_child(r.element)
    place(r.element, x, y)
    if i < rendered.length() - 1 {
      let line_x1 = x + r.width
      let line_x2 = line_x1 + separation
      line(
        group,
        PathBuilder::new().move_to(line_x1, max_up).line_to(line_x2, max_up),
      )
    }
    x += r.width + separation
  }
  {
    element: group,
    width: total_width,
    height: max_up + max_down,
    up: max_up,
    down: max_down,
  }
}

///|
/// `Math.max`, for numbers that are never `NaN`.
fn max(a : Double, b : Double) -> Double {
  if b > a {
    b
  } else {
    a
  }
}

///|
/// `renderChoice`: the alternatives stacked, each reached by a track that
/// leaves the line through the middle and comes back to it.
fn Renderer::choice(
  self : Renderer,
  alternatives : Array[Node],
) -> Rendered raise Unsupported {
  let rendered = alternatives.map(alternative => self.expression(alternative))
  let mut max_width = 0.0
  let mut total_height = 0.0
  for r in rendered {
    max_width = max(max_width, r.width)
    total_height += r.height
  }
  total_height += (rendered.length() - 1).to_double() *
    self.options.vertical_separation
  let arc_radius = self.options.arc_radius
  let arc_width = arc_radius * 4.0
  let total_width = max_width + arc_width
  let group = @dom.Element::new("g").attr("class", "railroad-choice")
  let mut y = 0.0
  let center_y = total_height / 2.0
  for r in rendered {
    let elem_y = y
    let elem_center_y = elem_y + r.up
    let elem_x = arc_radius * 2.0 + (max_width - r.width) / 2.0
    group.append_child(r.element)
    place(r.element, elem_x, elem_y)
    // From the middle to this alternative.
    let left = PathBuilder::new()
    let below = elem_center_y > center_y
    let toward = if below { arc_radius } else { -arc_radius }
    if elem_center_y == center_y {
      left.move_to(0.0, center_y).line_to(elem_x, elem_center_y) |> ignore
    } else {
      left
      .move_to(0.0, center_y)
      .arc_to(arc_radius, below, arc_radius, center_y + toward)
      .line_to(arc_radius, elem_center_y - toward)
      .arc_to(arc_radius, !below, arc_radius * 2.0, elem_center_y)
      .line_to(elem_x, elem_center_y)
      |> ignore
    }
    line(group, left)
    // And back.
    let right = PathBuilder::new()
    let right_start = elem_x + r.width
    let right_lane_x = total_width - arc_radius * 2.0
    if elem_center_y == center_y {
      right.move_to(right_start, elem_center_y).line_to(total_width, center_y)
      |> ignore
    } else {
      right
      .move_to(right_start, elem_center_y)
      .line_to(right_lane_x, elem_center_y)
      .arc_to(
        arc_radius,
        !below,
        total_width - arc_radius,
        elem_center_y + (if below { -arc_radius } else { arc_radius }),
      )
      .line_to(total_width - arc_radius, center_y + toward)
      .arc_to(arc_radius, below, total_width, center_y)
      |> ignore
    }
    line(group, right)
    y += r.height + self.options.vertical_separation
  }
  {
    element: group,
    width: total_width,
    height: total_height,
    up: center_y,
    down: total_height - center_y,
  }
}

///|
/// The track that passes an element by, above it: from the line at
/// `center_y` up to the top of the group and down again at the far end.
fn bypass(
  arc_radius : Double,
  total_width : Double,
  center_y : Double,
) -> PathBuilder {
  PathBuilder::new()
  .move_to(0.0, center_y)
  .arc_to(arc_radius, false, arc_radius, center_y - arc_radius)
  .line_to(arc_radius, arc_radius)
  .arc_to(arc_radius, true, arc_radius * 2.0, 0.0)
  .line_to(total_width - arc_radius * 2.0, 0.0)
  .arc_to(arc_radius, true, total_width - arc_radius, arc_radius)
  .line_to(total_width - arc_radius, center_y - arc_radius)
  .arc_to(arc_radius, false, total_width, center_y)
}

///|
/// `renderOptional`: the element, and a track that passes it by.
fn Renderer::optional(
  self : Renderer,
  element : Node,
) -> Rendered raise Unsupported {
  let inner = self.expression(element)
  let arc_radius = self.options.arc_radius
  let arc_height = arc_radius * 2.0
  let total_width = inner.width + arc_radius * 4.0
  let total_height = inner.height + arc_height
  let group = @dom.Element::new("g").attr("class", "railroad-optional")
  let elem_x = arc_radius * 2.0
  let elem_y = arc_height
  group.append_child(inner.element)
  place(inner.element, elem_x, elem_y)
  let center_y = elem_y + inner.up
  line(
    group,
    PathBuilder::new()
    .move_to(0.0, center_y)
    .line_to(arc_radius * 2.0, center_y),
  )
  line(
    group,
    PathBuilder::new()
    .move_to(elem_x + inner.width, center_y)
    .line_to(total_width, center_y),
  )
  line(group, bypass(arc_radius, total_width, center_y))
  {
    element: group,
    width: total_width,
    height: total_height,
    up: center_y,
    down: total_height - center_y,
  }
}

///|
/// `renderRepetition`: the element and a track that leads back under it;
/// when it may be left out altogether, one that passes it by as well.
fn Renderer::repetition(
  self : Renderer,
  element : Node,
  has_bypass : Bool,
) -> Rendered raise Unsupported {
  let inner = self.expression(element)
  let arc_radius = self.options.arc_radius
  let arc_height = arc_radius * 2.0
  let total_width = inner.width + arc_radius * 4.0
  let total_height = inner.height +
    arc_height +
    (if has_bypass { arc_height } else { 0.0 })
  let group = @dom.Element::new("g").attr("class", "railroad-repetition")
  let elem_x = arc_radius * 2.0
  let elem_y = if has_bypass { arc_height } else { 0.0 }
  group.append_child(inner.element)
  place(inner.element, elem_x, elem_y)
  let center_y = elem_y + inner.up
  line(
    group,
    PathBuilder::new()
    .move_to(0.0, center_y)
    .line_to(arc_radius * 2.0, center_y),
  )
  let end_x = elem_x + inner.width
  line(
    group,
    PathBuilder::new().move_to(end_x, center_y).line_to(total_width, center_y),
  )
  let loop_y = elem_y + inner.height + arc_radius
  line(
    group,
    PathBuilder::new()
    .move_to(end_x, center_y)
    .arc_to(arc_radius, true, end_x + arc_radius, center_y + arc_radius)
    .line_to(end_x + arc_radius, loop_y)
    .arc_to(arc_radius, true, end_x, loop_y + arc_radius)
    .line_to(arc_radius * 2.0, loop_y + arc_radius)
    .arc_to(arc_radius, true, arc_radius, loop_y)
    .line_to(arc_radius, center_y + arc_radius)
    .arc_to(arc_radius, true, arc_radius * 2.0, center_y),
  )
  if has_bypass {
    line(group, bypass(arc_radius, total_width, center_y))
  }
  {
    element: group,
    width: total_width,
    height: total_height,
    up: center_y,
    down: total_height - center_y,
  }
}

///|
/// `renderExpression`.
fn Renderer::expression(
  self : Renderer,
  node : Node,
) -> Rendered raise Unsupported {
  match node {
    Terminal(value) => self.boxed("railroad-terminal", value)
    NonTerminal(name) => self.boxed("railroad-nonterminal", name)
    Sequence(elements) => self.sequence(elements)
    Choice(alternatives) => self.choice(alternatives)
    Optional(element) => self.optional(element)
    Repetition(element, min~, ..) => self.repetition(element, min == 0.0)
    Special(text) => self.boxed("railroad-special", "? " + text + " ?")
  }
}

///|
/// `renderRule`: the rule's name, a marker, its definition and a marker,
/// `y` down the diagram. Returns the width and the height taken.
fn Renderer::rule(
  self : Renderer,
  svg : @dom.Element,
  rule : Rule,
  y : Double,
) -> (Double, Double) raise Unsupported {
  let n = @dom.number
  let marker_radius = self.options.marker_radius
  let group = svg
    .append("g")
    .attr("class", "railroad-rule")
    .attr("transform", "translate(0, \{n(y)})")
  let rule_name = rule.name + " ="
  let name_width = self.measure(rule_name).0 + 20.0
  let definition_x = name_width + 20.0
  let definition_group = group.append("g")
  let result = self.expression(rule.definition)
  definition_group.append_child(result.element)
  let baseline_y = max(20.0, result.up)
  let definition_y = baseline_y - result.up
  place(definition_group, definition_x, definition_y)
  group
  .append("g")
  .attr("class", "railroad-rule-name-group")
  .append("text")
  .attr("class", "railroad-rule-name")
  .attr_number("x", 0.0)
  .attr_number("y", baseline_y)
  .text(rule_name)
  |> ignore
  group
  .append("g")
  .attr("class", "railroad-start")
  .append("circle")
  .attr_number("cx", name_width)
  .attr_number("cy", baseline_y)
  .attr_number("r", marker_radius)
  |> ignore
  group
  .append("g")
  .attr("class", "railroad-end")
  .append("circle")
  .attr_number("cx", definition_x + result.width + 10.0)
  .attr_number("cy", baseline_y)
  .attr_number("r", marker_radius)
  |> ignore
  line(
    group,
    PathBuilder::new()
    .move_to(name_width + marker_radius, baseline_y)
    .line_to(definition_x, baseline_y),
  )
  line(
    group,
    PathBuilder::new()
    .move_to(definition_x + result.width, baseline_y)
    .line_to(definition_x + result.width + 10.0 - marker_radius, baseline_y),
  )
  (
    definition_x + result.width + 10.0 + marker_radius,
    max(40.0, definition_y + result.height + self.options.padding * 2.0),
  )
}

///|
/// Draw the diagram into the context's `<svg>` element.
pub fn draw(
  railroad : Railroad,
  context : @diagram.Context,
) -> Unit raise Unsupported {
  let n = @dom.number
  match context.config.text("securityLevel") {
    None | Some("strict" | "antiscript") => ()
    // The output is then not sanitized, which is where entity codes are
    // resolved.
    Some("loose") =>
      if railroad.entities {
        raise Unsupported("entity codes under securityLevel loose")
      }
    // Text is sanitized otherwise, and a sandbox wraps the diagram.
    Some(level) => raise Unsupported("securityLevel \{level}")
  }
  let svg = context.svg
  svg.attr("class", "railroad-diagram") |> ignore
  // `railroadConfig?.useMaxWidth ?? true`
  let use_max_width = match context.config.get("railroad.useMaxWidth") {
    Null => true
    _ => context.config.flag("railroad.useMaxWidth")
  }
  let size = (width : Double, height : Double) => {
    @diagram.configure_svg_size(svg, height, width, use_max_width)
    svg.attr("viewBox", "0 0 \{n(width)} \{n(height)}") |> ignore
  }
  if railroad.rules.is_empty() {
    size(200.0, 100.0)
    return
  }
  if theme_css_restyles_text(context.config) {
    raise Unsupported("themeCSS that restyles the text measured")
  }
  let options = Options::new(context.config)
  let renderer = { options, font: measuring_font(options.font_family), }
  let mut y = options.padding
  let mut max_width = 0.0
  for rule in railroad.rules {
    let (width, height) = renderer.rule(svg, rule, y)
    y += height + options.vertical_separation
    max_width = max(max_width, width)
  }
  size(max_width + options.padding * 2.0, y + options.padding)
}

///|
/// Whether the user's `themeCSS` could change how text the renderer
/// measures is laid out: a rule of it beats what the renderer sets.
fn theme_css_restyles_text(config : @config.Config) -> Bool {
  guard config.text("themeCSS") is Some(css) else { return false }
  let css = css.to_lower()
  ["font", "spacing", "text-transform", "white-space", "writing-mode"]
  .iter()
  .any(property => css.contains(property))
}
