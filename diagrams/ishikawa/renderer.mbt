///|
/// The font size lines are spaced by when the configuration has none.
const FONT_SIZE_DEFAULT : Double = 14.0

///|
/// The length of a main bone when no cause has causes of its own, and the
/// least height of the spine.
const SPINE_BASE_LENGTH : Double = 250.0

///|
/// The length of a horizontal bone without children.
const BONE_STUB : Double = 30.0

///|
/// The length of a horizontal bone with children, before `BONE_PER_CHILD`
/// for each of them.
const BONE_BASE : Double = 60.0

///|
const BONE_PER_CHILD : Double = 5.0

///|
/// `Math.PI`
const PI : Double = 3.141592653589793

///|
/// The angle between the spine and the diagonal bones, in radians.
let angle : Double = 82.0 * PI / 180.0

///|
let cos_a : Double = @jsmath.cos(angle)

///|
let sin_a : Double = @jsmath.sin(angle)

///|
/// `Math.max` of two numbers.
fn max(a : Double, b : Double) -> Double {
  if b > a {
    b
  } else {
    a
  }
}

///|
/// What drawing needs besides the tree.
priv struct Drawing {
  /// The configured `fontSize`, which spaces lines and causes.
  font_size : Double
  head : TextStyle
  cause : TextStyle
  /// Labels of horizontal bones.
  aligned : TextStyle
  /// Labels of diagonal bones above and below the spine.
  up : TextStyle
  down : TextStyle
  /// The boxes of the labels drawn in the current pair of causes.
  mut labels : Array[@dom.Rect]
  /// Set for the hand-drawn look, where rough.js draws every shape.
  rough : RoughContext?
}

///|
/// What the hand-drawn look draws with.
priv struct RoughContext {
  /// `handDrawnSeed`; rough.js is random when it is 0.
  seed : Int32
  line_color : String
  fill_color : String
}

///|
/// The options of the sketchy outlines with a hachure fill: the head and
/// the boxes of the causes.
fn RoughContext::filled(self : RoughContext) -> @rough.Options {
  let options = @rough.Options::new()
  options.roughness = 1.5
  options.seed = self.seed
  options.fill = self.fill_color
  options.fill_style = "hachure"
  options.fill_weight = 2.5
  options.hachure_gap = 5.0
  options.stroke = self.line_color
  options.stroke_width = "2"
  options
}

///|
/// rough.js draws no markers, so the arrow head at the start of a bone is
/// a filled triangle: its tip at `x`, `y`, pointing along `dx`, `dy`.
fn RoughContext::draw_arrow_marker(
  self : RoughContext,
  parent : @dom.Element,
  x : Double,
  y : Double,
  dx : Double,
  dy : Double,
) -> Unit {
  let n = @dom.number
  let len = (dx * dx + dy * dy).sqrt()
  if len == 0.0 {
    return
  }
  let ux = dx / len
  let uy = dy / len
  let s = 6.0
  let px = -uy * s
  let py = ux * s
  let d = "M \{n(x)} \{n(y)} L \{n(x - ux * s * 2.0 + px)} \{n(y - uy * s * 2.0 + py)} L \{n(x - ux * s * 2.0 - px)} \{n(y - uy * s * 2.0 - py)} Z"
  let options = @rough.Options::new()
  options.roughness = 1.0
  options.seed = self.seed
  options.fill = self.line_color
  options.fill_style = "solid"
  options.stroke = self.line_color
  options.stroke_width = "1"
  parent.append_child(@rough.path(d, options))
}

///|
/// The font size the browser computes for the theme's `fontSize`, which
/// the stylesheet writes after `font-size:` for the diagram and again for
/// its text. `parent` is the size inherited when the declaration is
/// invalid, as a bare number is, and the size relative units refer to.
fn css_font_size(value : Json, parent : Double) -> Double raise Unsupported {
  let text = match value {
    String(text) => text.trim(chars=" \t\n").to_owned().to_lower()
    // Written without a unit: not a length.
    _ => return parent
  }
  let unsupported = Unsupported(
    "fontSize is not a font size the port measures: \{text}",
  )
  guard @dom.css_dimension(text) is Some((number, unit)) else {
    raise unsupported
  }
  // A negative size is invalid, whatever its unit.
  if number < 0.0 {
    return parent
  }
  let size = match unit {
    "px" => number
    "em" => number * parent
    "rem" => number * 16.0
    "%" => number / 100.0 * parent
    "pt" => number * 4.0 / 3.0
    // A number without a unit is no length, but for zero.
    "" if number == 0.0 => 0.0
    "" => return parent
    _ => raise unsupported
  }
  // Zero is a size: text set in it takes no room.
  size
}

///|
/// `parseFontSize(config.fontSize)[0]`: a number as it is, the leading
/// integer of a string.
fn config_font_size(value : Json) -> Double {
  match value {
    Number(size, ..) => size
    String(text) => @diagram.parse_font_size(text).unwrap_or(FONT_SIZE_DEFAULT)
    _ => FONT_SIZE_DEFAULT
  }
}

///|
/// A `<line>`, or its sketch in the hand-drawn look.
fn draw_line(
  parent : @dom.Element,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  class_name : String,
  rough~ : RoughContext? = None,
) -> @dom.Element {
  if rough is Some(rough) {
    let options = @rough.Options::new()
    options.roughness = 1.5
    options.seed = rough.seed
    options.stroke = rough.line_color
    options.stroke_width = "2"
    let node = @rough.line(x1, y1, x2, y2, options)
    parent.append_child(node)
    return node.attr("class", class_name)
  }
  parent
  .append("line")
  .attr("class", class_name)
  .attr_number("x1", x1)
  .attr_number("y1", y1)
  .attr_number("x2", x2)
  .attr_number("y2", y2)
}

///|
/// `sideStats`: how many descendants the causes on one side of the spine
/// have together, and the most any one of them has.
fn side_stats(nodes : Array[Node]) -> (Double, Double) {
  fn count(node : Node) -> Double {
    let mut sum = 0.0
    for child in node.children {
      sum = sum + 1.0 + count(child)
    }
    sum
  }

  let mut total = 0.0
  let mut most = 0.0
  for node in nodes {
    let descendants = count(node)
    total += descendants
    most = max(most, descendants)
  }
  (total, most)
}

///|
/// The fish's head: the effect in a shape bulging to the right of the
/// spine's end, as tall and as wide as its text asks for.
fn Drawing::draw_head(
  self : Drawing,
  parent : @dom.Element,
  x : Double,
  y : Double,
  label : String,
) -> Unit raise Unsupported {
  let n = @dom.number
  let max_chars = max(6.0, (110.0 / (self.font_size * 0.6)).floor()).to_int()
  let group = parent
    .append("g")
    .attr("class", "ishikawa-head-group")
    .attr("transform", "translate(\{n(x)},\{n(y)})")
  let (text, tb) = draw_multiline_text(
    group,
    wrap_text(label, max_chars),
    0.0,
    0.0,
    "ishikawa-head-label",
    "start",
    self.font_size,
    self.head,
  )
  let w = max(60.0, tb.width + 6.0)
  let h = max(40.0, tb.height * 2.0 + 40.0)
  let head_path = "M 0 \{n(-h / 2.0)} L 0 \{n(h / 2.0)} Q \{n(w * 2.4)} 0 0 \{n(-h / 2.0)} Z"
  match self.rough {
    Some(rough) => {
      let node = @rough.path(head_path, rough.filled())
      group.insert_before(node, text)
      node.attr("class", "ishikawa-head") |> ignore
    }
    None =>
      group
      .insert_first("path")
      .attr("class", "ishikawa-head")
      .attr("d", head_path)
      |> ignore
  }
  text.attr(
    "transform",
    "translate(\{n((w - tb.width) / 2.0 - tb.x + 3.0)},\{n(-tb.y - tb.height / 2.0)})",
  )
  |> ignore
}

///|
/// The name of a main cause, boxed, at the far end of its bone.
fn Drawing::draw_cause_label(
  self : Drawing,
  parent : @dom.Element,
  text : String,
  x : Double,
  y : Double,
  direction : Double,
) -> Unit raise Unsupported {
  let group = parent.append("g").attr("class", "ishikawa-label-group")
  let (label, tb) = draw_multiline_text(
    group,
    text,
    x,
    y + 11.0 * direction,
    "ishikawa-label cause",
    "middle",
    self.font_size,
    self.cause,
  )
  self.labels.push(tb)
  match self.rough {
    Some(rough) => {
      let node = @rough.rectangle(
        tb.x - 20.0,
        tb.y - 2.0,
        tb.width + 40.0,
        tb.height + 4.0,
        rough.filled(),
      )
      group.insert_before(node, label)
      node.attr("class", "ishikawa-label-box") |> ignore
    }
    None =>
      group
      .insert_first("rect")
      .attr("class", "ishikawa-label-box")
      .attr_number("x", tb.x - 20.0)
      .attr_number("y", tb.y - 2.0)
      .attr_number("width", tb.width + 40.0)
      .attr_number("height", tb.height + 4.0)
      |> ignore
  }
}

///|
/// A cause below a main cause, flattened for drawing.
priv struct LabelEntry {
  text : String
  /// 2 for the children of a main cause: even depths are horizontal
  /// bones, odd ones diagonal.
  depth : Int32
  /// The index of the parent's entry, -1 for a main cause.
  parent_index : Int32
  child_count : Int32
}

///|
/// A bone others attach to.
priv struct Bone {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
  child_count : Int32
  mut children_drawn : Int32
}

///|
/// `flattenTree`: the descendants of a main cause in drawing order, and
/// the order they take their heights in. Horizontal bones come before
/// their children (closer to the spine), diagonal ones after, which keeps
/// them within their parent's wedge.
fn flatten_tree(
  children : Array[Node],
  direction : Double,
) -> (Array[LabelEntry], Array[Int32]) {
  let entries : Array[LabelEntry] = []
  let y_order : Array[Int32] = []
  fn walk(nodes : Array[Node], parent_index : Int32, depth : Int32) -> Unit {
    let ordered = if direction == -1.0 { nodes.rev() } else { nodes }
    for child in ordered {
      let index = entries.length()
      entries.push({
        depth,
        text: wrap_text(child.text, 15),
        parent_index,
        child_count: child.children.length(),
      })
      if depth % 2 == 0 {
        y_order.push(index)
        if child.children.length() > 0 {
          walk(child.children, index, depth + 1)
        }
      } else {
        if child.children.length() > 0 {
          walk(child.children, index, depth + 1)
        }
        y_order.push(index)
      }
    }
  }

  walk(children, -1, 2)
  (entries, y_order)
}

///|
fn lerp(a : Double, b : Double, t : Double) -> Double {
  a + (b - a) * t
}

///|
/// A main cause: its bone from the spine at `start_x`, upwards or
/// downwards by `direction`, its label, and the bones of its descendants.
fn Drawing::draw_branch(
  self : Drawing,
  parent : @dom.Element,
  node : Node,
  start_x : Double,
  start_y : Double,
  direction : Double,
  length : Double,
) -> Unit raise Unsupported {
  let children = node.children
  let line_len = length * (if children.length() > 0 { 1.0 } else { 0.2 })
  let dx = -cos_a * line_len
  let dy = sin_a * line_len * direction
  let end_x = start_x + dx
  let end_y = start_y + dy
  draw_line(
    parent,
    start_x,
    start_y,
    end_x,
    end_y,
    "ishikawa-branch",
    rough=self.rough,
  )
  |> ignore
  if self.rough is Some(rough) {
    rough.draw_arrow_marker(
      parent,
      start_x,
      start_y,
      start_x - end_x,
      start_y - end_y,
    )
  }
  self.draw_cause_label(parent, node.text, end_x, end_y, direction)
  if children.is_empty() {
    return
  }
  let (entries, y_order) = flatten_tree(children, direction)
  let entry_count = entries.length()
  let ys = Array::make(entry_count, 0.0)
  for slot, entry_index in y_order {
    ys[entry_index] = start_y +
      dy * ((slot + 1).to_double() / (entry_count + 1).to_double())
  }
  let bones : Map[Int32, Bone] = Map([])
  bones[-1] = {
    x0: start_x,
    y0: start_y,
    x1: end_x,
    y1: end_y,
    child_count: children.length(),
    children_drawn: 0,
  }
  let diagonal_x = -cos_a
  let diagonal_y = sin_a * direction
  for i, entry in entries {
    let y = ys[i]
    guard bones.get(entry.parent_index) is Some(par) else { continue }
    let group = parent.append("g").attr("class", "ishikawa-sub-group")
    let mut bx0 = 0.0
    let mut by0 = 0.0
    let mut bx1 = 0.0
    if entry.depth % 2 == 0 {
      // A horizontal bone: from the parent's diagonal at its height,
      // leftwards.
      let dy_parent = par.y1 - par.y0
      bx0 = lerp(
        par.x0,
        par.x1,
        if dy_parent != 0.0 {
          (y - par.y0) / dy_parent
        } else {
          0.5
        },
      )
      by0 = y
      bx1 = bx0 -
        (if entry.child_count > 0 {
          BONE_BASE + entry.child_count.to_double() * BONE_PER_CHILD
        } else {
          BONE_STUB
        })
      draw_line(group, bx0, y, bx1, y, "ishikawa-sub-branch", rough=self.rough)
      |> ignore
      if self.rough is Some(rough) {
        rough.draw_arrow_marker(group, bx0, y, 1.0, 0.0)
      }
      let (_, box) = draw_multiline_text(
        group,
        entry.text,
        bx1,
        y,
        "ishikawa-label align",
        "end",
        self.font_size,
        self.aligned,
      )
      self.labels.push(box)
    } else {
      // A diagonal bone: from a point on the parent's horizontal, evenly
      // spaced with its siblings, slanting to its height.
      let k = par.children_drawn
      par.children_drawn += 1
      bx0 = lerp(
        par.x0,
        par.x1,
        (par.child_count - k).to_double() / (par.child_count + 1).to_double(),
      )
      by0 = par.y0
      bx1 = bx0 + diagonal_x * ((y - by0) / diagonal_y)
      draw_line(
        group,
        bx0,
        by0,
        bx1,
        y,
        "ishikawa-sub-branch",
        rough=self.rough,
      )
      |> ignore
      if self.rough is Some(rough) {
        rough.draw_arrow_marker(group, bx0, by0, bx0 - bx1, by0 - y)
      }
      let (_, box) = draw_multiline_text(
        group,
        entry.text,
        bx1,
        y,
        if direction < 0.0 {
          "ishikawa-label up"
        } else {
          "ishikawa-label down"
        },
        "end",
        self.font_size,
        if direction < 0.0 {
          self.up
        } else {
          self.down
        },
      )
      self.labels.push(box)
    }
    if entry.child_count > 0 {
      bones[i] = {
        x0: bx0,
        y0: by0,
        x1: bx1,
        y1: y,
        child_count: entry.child_count,
        children_drawn: 0,
      }
    }
  }
}

///|
/// `applyPaddedViewBox`: fit the `<svg>` to its content plus `pad` on
/// every side.
fn apply_padded_view_box(
  svg : @dom.Element,
  pad : Double,
  use_max_width : Bool,
) -> Unit {
  let n = @dom.number
  let bbox = svg.bbox()
  let w = bbox.width + pad * 2.0
  let h = bbox.height + pad * 2.0
  @diagram.configure_svg_size(svg, h, w, use_max_width)
  svg.attr("viewBox", "\{n(bbox.x - pad)} \{n(bbox.y - pad)} \{n(w)} \{n(h)}")
  |> ignore
}

///|
/// Draw the Ishikawa diagram into the context's `<svg>` element.
pub fn draw(
  diagram : Ishikawa,
  context : @diagram.Context,
) -> Unit raise Unsupported {
  guard diagram.root is Some(root) else { return }
  let n = @dom.number
  let config = context.config
  let theme = context.theme()
  let color = (name : String, default : String) => {
    match theme.get(name) {
      Null => default
      _ => theme.text(name)
    }
  }
  let rough : RoughContext? = if config.text("look") is Some("handDrawn") {
    Some({
      seed: config.number("handDrawnSeed").unwrap_or(0.0).to_int(),
      line_color: color("lineColor", "#333"),
      fill_color: color("mainBkg", "#fff"),
    })
  } else {
    None
  }
  // The diagram's root and its text both take the theme's font size, so
  // a relative size applies twice.
  let root_size = css_font_size(theme.get("fontSize"), 16.0)
  let text_size = css_font_size(theme.get("fontSize"), root_size)
  let regular = context.font()
  let style = (anchor : String, baseline : @font.Baseline) => {
    let style : TextStyle = {
      font: regular,
      size: text_size,
      anchor,
      baseline,
    }
    style
  }
  let drawing : Drawing = {
    font_size: config_font_size(config.get("fontSize")),
    // Weight 600 takes the bold face.
    head: {
      font: context.font(bold=true),
      size: 14.0,
      anchor: "middle",
      baseline: Middle,
    },
    cause: style("middle", Middle),
    aligned: style("end", Middle),
    // `dominant-baseline: baseline` is not a value: the default stays.
    up: style("end", Alphabetic),
    down: style("end", Hanging),
    labels: [],
    rough,
  }
  let causes = root.children
  let padding = config.number("ishikawa.diagramPadding").unwrap_or(20.0)
  let use_max_width = config.flag("ishikawa.useMaxWidth")
  let svg = context.svg
  let g = svg.append("g").attr("class", "ishikawa")
  let marker_id = "ishikawa-arrow-\{context.id}"
  if rough is None {
    g
    .append("defs")
    .append("marker")
    .attr("id", marker_id)
    .attr("viewBox", "0 0 10 10")
    .attr_number("refX", 0.0)
    .attr_number("refY", 5.0)
    .attr_number("markerWidth", 6.0)
    .attr_number("markerHeight", 6.0)
    .attr("orient", "auto")
    .append("path")
    .attr("d", "M 10 0 L 0 5 L 10 10 Z")
    .attr("class", "ishikawa-arrow")
    |> ignore
  }
  let mut spine_x = 0.0
  let mut spine_y = SPINE_BASE_LENGTH
  // The sketched spine is drawn last, when its ends are known.
  let spine = if rough is None {
    Some(draw_line(g, spine_x, spine_y, spine_x, spine_y, "ishikawa-spine"))
  } else {
    None
  }
  drawing.draw_head(g, spine_x, spine_y, root.text)
  if causes.is_empty() {
    if rough is Some(_) {
      draw_line(g, spine_x, spine_y, spine_x, spine_y, "ishikawa-spine", rough~)
      |> ignore
    }
    apply_padded_view_box(svg, padding, use_max_width)
    return
  }
  spine_x -= 20.0
  let upper : Array[Node] = []
  let lower : Array[Node] = []
  for i, cause in causes {
    if i % 2 == 0 {
      upper.push(cause)
    } else {
      lower.push(cause)
    }
  }
  let (upper_total, upper_max) = side_stats(upper)
  let (lower_total, lower_max) = side_stats(lower)
  let descendant_total = upper_total + lower_total
  let mut upper_len = SPINE_BASE_LENGTH
  let mut lower_len = SPINE_BASE_LENGTH
  // The sides share twice the base length by their numbers of
  // descendants, neither getting less than three tenths of it.
  if descendant_total > 0.0 {
    let pool = SPINE_BASE_LENGTH * 2.0
    let min_len = SPINE_BASE_LENGTH * 0.3
    upper_len = max(min_len, pool * (upper_total / descendant_total))
    lower_len = max(min_len, pool * (lower_total / descendant_total))
  }
  let min_spacing = drawing.font_size * 2.0
  upper_len = max(upper_len, upper_max * min_spacing)
  lower_len = max(lower_len, lower_max * min_spacing)
  spine_y = max(upper_len, SPINE_BASE_LENGTH)
  if spine is Some(spine) {
    spine.attr_number("y1", spine_y).attr_number("y2", spine_y) |> ignore
  }
  for group in g.child_elements() {
    if group.get_attr("class") is Some("ishikawa-head-group") {
      group.attr("transform", "translate(0,\{n(spine_y)})") |> ignore
    }
  }
  // Causes come in pairs, one above and one below the spine; each pair
  // starts left of everything the one before it has drawn.
  let pair_count = (causes.length() + 1) / 2
  for p in 0..<pair_count {
    let pair = g.append("g").attr("class", "ishikawa-pair")
    drawing.labels = []
    drawing.draw_branch(pair, causes[p * 2], spine_x, spine_y, -1.0, upper_len)
    if causes.get(p * 2 + 1) is Some(cause) {
      drawing.draw_branch(pair, cause, spine_x, spine_y, 1.0, lower_len)
    }
    let mut left = 1.0 / 0.0
    for box in drawing.labels {
      if box.x < left {
        left = box.x
      }
    }
    spine_x = left
  }
  match spine {
    Some(spine) => {
      spine.attr_number("x1", spine_x) |> ignore
      let marker_url = "url(#\{marker_id})"
      for line in g.descendants(["line"]) {
        if line.get_attr("class")
          is Some("ishikawa-branch" | "ishikawa-sub-branch") {
          line.attr("marker-start", marker_url) |> ignore
        }
      }
    }
    None =>
      draw_line(g, spine_x, spine_y, 0.0, spine_y, "ishikawa-spine", rough~)
      |> ignore
  }
  apply_padded_view_box(svg, padding, use_max_width)
}
