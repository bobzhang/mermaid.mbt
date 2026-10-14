///|
/// Where a domain is: its centre and, for the four quadrants, its
/// rectangle.
priv struct Layout {
  cx : Double
  cy : Double
  x : Double
  y : Double
  w : Double
  h : Double
}

///|
/// The four quadrants in drawing order.
let quadrant_domains : Array[String] = [
  "complex", "complicated", "chaotic", "clear",
]

///|
/// The Confusion ellipse shows this many items and counts the rest in a
/// `+N more` badge.
const MAX_CONFUSION_ITEMS : Int32 = 3

///|
const ITEM_HEIGHT : Double = 26.0

///|
const ITEM_PADDING_X : Double = 10.0

///|
/// The decision model and the kind of practice of a domain, shown under
/// its name.
fn domain_meta(name : String) -> (String, String) {
  match name {
    "complex" => ("Probe \u{2192} Sense \u{2192} Respond", "Emergent Practices")
    "complicated" =>
      ("Sense \u{2192} Analyse \u{2192} Respond", "Good Practices")
    "clear" => ("Sense \u{2192} Categorise \u{2192} Respond", "Best Practices")
    "chaotic" => ("Act \u{2192} Sense \u{2192} Respond", "Novel Practices")
    _ => ("", "Disorder")
  }
}

///|
/// Complex top-left, Complicated top-right, Chaotic bottom-left, Clear
/// bottom-right, Confusion over the centre.
fn domain_layout(name : String, width : Double, height : Double) -> Layout {
  let hw = width / 2.0
  let hh = height / 2.0
  match name {
    "complex" => { cx: hw / 2.0, cy: hh / 2.0, x: 0.0, y: 0.0, w: hw, h: hh, }
    "complicated" =>
      { cx: hw + hw / 2.0, cy: hh / 2.0, x: hw, y: 0.0, w: hw, h: hh, }
    "chaotic" =>
      { cx: hw / 2.0, cy: hh + hh / 2.0, x: 0.0, y: hh, w: hw, h: hh, }
    "clear" =>
      { cx: hw + hw / 2.0, cy: hh + hh / 2.0, x: hw, y: hh, w: hw, h: hh, }
    _ => { cx: hw, cy: hh, x: hw * 0.7, y: hh * 0.7, w: hw * 0.6, h: hh * 0.6, }
  }
}

///|
/// Text as SVG lays it out: line breaks and tabs are spaces, runs of
/// spaces collapse, and the spaces at both ends go.
fn collapse_spaces(text : String) -> String {
  let out = StringBuilder()
  let mut pending = false
  for c in text {
    if c is (' ' | '\t' | '\n' | '\r') {
      pending = true
      continue
    }
    if pending && !out.is_empty() {
      out.write_char(' ')
    }
    pending = false
    out.write_char(c)
  }
  out.to_string()
}

///|
/// How item badges are measured: their text in the diagram's font at the
/// theme's `itemFontSize`.
priv struct ItemText {
  font : @font.Stack
  size : Double
  /// The scale the diagram is shown at when the badges are measured: the
  /// `viewBox` is set by then.
  scale : Double
}

///|
/// The width `getBBox()` reports for the text of a badge, which is
/// centred on x = 0 and on its central baseline when measured. Text that
/// lays out nothing is taken as seven pixels per character.
fn ItemText::width(self : ItemText, label : String) -> Double raise Unsupported {
  let text = collapse_spaces(label)
  if text == "" {
    return label.length().to_double() * 7.0
  }
  if !self.font.covers(text) {
    raise Unsupported("text outside the fonts the port can measure: \{text}")
  }
  self.font.chunks_box(
    [{ text, x: 0.0, y: ITEM_HEIGHT / 2.0, }],
    self.size,
    anchor="middle",
    baseline=Central,
    scale=self.scale,
  ).width
}

///|
/// A badge: the label in a rounded rectangle as wide as its text plus
/// padding, centred on `cx` with its top at `y`.
fn ItemText::draw_badge(
  self : ItemText,
  parent : @dom.Element,
  label : String,
  cx : Double,
  y : Double,
  class_name : String,
  fill : String,
  fill_opacity : Double,
) -> Unit raise Unsupported {
  let n = @dom.number
  let group = parent.append("g")
  let badge_width = self.width(label) + ITEM_PADDING_X * 2.0
  let item_x = cx - badge_width / 2.0
  group.attr("transform", "translate(\{n(item_x)}, \{n(y)})") |> ignore
  group
  .append("rect")
  .attr("class", class_name)
  .attr_number("x", 0.0)
  .attr_number("y", 0.0)
  .attr_number("width", badge_width)
  .attr_number("height", ITEM_HEIGHT)
  .attr_number("rx", 4.0)
  .attr_number("ry", 4.0)
  .attr("fill", fill)
  .attr_number("fill-opacity", fill_opacity)
  |> ignore
  group
  .append("text")
  .attr("class", "cynefinItemText")
  .attr_number("x", badge_width / 2.0)
  .attr_number("y", ITEM_HEIGHT / 2.0)
  .attr("text-anchor", "middle")
  .attr("dominant-baseline", "central")
  .text(label)
  |> ignore
}

///|
/// The theme's `itemFontSize` in pixels: the stylesheet writes it before
/// `px`.
fn item_font_size(value : Json) -> Double raise Unsupported {
  let size = match value {
    Number(size, ..) => Some(size)
    String(text) => js_number(text).filter(_ => text != "")
    _ => None
  }
  match size {
    Some(size) if size > 0.0 => size
    _ =>
      raise Unsupported(
        "itemFontSize is not a font size the port measures: \{js_text(value)}",
      )
  }
}

///|
/// Draw the Cynefin diagram into the context's `<svg>` element.
pub fn draw(
  diagram : Cynefin,
  context : @diagram.Context,
) -> Unit raise Unsupported {
  let n = @dom.number
  let config = context.config
  let setting = (name : String, default : Double) => {
    config.number("cynefin.\{name}").unwrap_or(default)
  }
  let block = CynefinTheme::new(context.theme())
  let width = setting("width", 800.0)
  let height = setting("height", 600.0)
  let padding = setting("padding", 40.0)
  let show_descriptions = config.flag("cynefin.showDomainDescriptions")
  let total_width = width + padding * 2.0
  let total_height = height + padding * 2.0
  let background = (name : String) => js_text(block.get("\{name}Bg"))
  let svg = context.svg
  let use_max_width = config.get("cynefin.useMaxWidth") is Null ||
    config.flag("cynefin.useMaxWidth")
  @diagram.configure_svg_size(svg, total_height, total_width, use_max_width)
  svg.attr("viewBox", "0 0 \{n(total_width)} \{n(total_height)}") |> ignore
  // The renderer's own accessibility elements, besides the ones every
  // diagram gets.
  if diagram.acc_title != "" {
    svg.append("title").text(diagram.acc_title) |> ignore
  }
  if diagram.acc_description != "" {
    svg.append("desc").text(diagram.acc_description) |> ignore
  }
  let root = svg
    .append("g")
    .attr("transform", "translate(\{n(padding)}, \{n(padding)})")
  let layout = (name : String) => domain_layout(name, width, height)
  let seed = resolve_seed(config.number("cynefin.seed"), context.id)
  // 1. The quadrants' backgrounds.
  let backgrounds = root.append("g").attr("class", "cynefin-backgrounds")
  for name in quadrant_domains {
    let layout = layout(name)
    backgrounds
    .append("rect")
    .attr("class", "cynefinDomain")
    .attr_number("x", layout.x)
    .attr_number("y", layout.y)
    .attr_number("width", layout.w)
    .attr_number("height", layout.h)
    .attr("fill", background(name))
    .attr_number("fill-opacity", 0.4)
    .attr("stroke", "none")
    |> ignore
  }
  // 2. The wavy boundaries and 3. the cliff.
  let amplitude = config.number("cynefin.boundaryAmplitude")
  let boundaries = root.append("g").attr("class", "cynefin-boundaries")
  boundaries
  .append("path")
  .attr("class", "cynefinBoundary")
  .attr("d", fold_path(width, height, seed, amplitude.unwrap_or(width * 0.015)))
  .attr("fill", "none")
  |> ignore
  boundaries
  .append("path")
  .attr("class", "cynefinBoundary")
  .attr(
    "d",
    horizontal_boundary(
      width,
      height,
      seed + 100.0,
      amplitude.unwrap_or(height * 0.015),
    ),
  )
  .attr("fill", "none")
  |> ignore
  boundaries
  .append("path")
  .attr("class", "cynefinCliff")
  .attr("d", cliff_path(width, height))
  .attr("fill", "none")
  |> ignore
  // 4. The Confusion ellipse over the centre.
  root
  .append("path")
  .attr("class", "cynefinConfusion")
  .attr(
    "d",
    confusion_path(width / 2.0, height / 2.0, width * 0.15, height * 0.15),
  )
  .attr("fill", background("confusion"))
  .attr_number("fill-opacity", 0.5)
  |> ignore
  // 5. The names of the domains.
  let labels = root.append("g").attr("class", "cynefin-labels")
  let centred = (
    parent : @dom.Element,
    class_name : String,
    x : Double,
    y : Double,
    text : String,
  ) => {
    parent
    .append("text")
    .attr("class", class_name)
    .attr_number("x", x)
    .attr_number("y", y)
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "middle")
    .text(text)
    |> ignore
  }
  for name in quadrant_domains {
    let layout = layout(name)
    centred(
      labels,
      "cynefinDomainLabel",
      layout.cx,
      if show_descriptions {
        layout.cy - 30.0
      } else {
        layout.cy
      },
      name[:1].to_owned().to_upper() + name[1:].to_owned(),
    )
  }
  centred(
    labels,
    "cynefinDomainLabel",
    width / 2.0,
    if show_descriptions {
      height / 2.0 - 10.0
    } else {
      height / 2.0
    },
    "Confusion",
  )
  // 6. What each domain asks for.
  if show_descriptions {
    let subtitles = root.append("g").attr("class", "cynefin-subtitles")
    for name in quadrant_domains {
      let layout = layout(name)
      let (model, practice) = domain_meta(name)
      centred(subtitles, "cynefinSubtitle", layout.cx, layout.cy - 10.0, model)
      centred(
        subtitles,
        "cynefinSubtitle",
        layout.cx,
        layout.cy + 5.0,
        practice,
      )
    }
    centred(
      subtitles,
      "cynefinSubtitle",
      width / 2.0,
      height / 2.0 + 8.0,
      domain_meta("confusion").1,
    )
  }
  // 7. The items of each domain as badges, stacked below its name.
  let items = root.append("g").attr("class", "cynefin-items")
  let item_text : ItemText = {
    font: context.font(),
    size: item_font_size(block.get("itemFontSize")),
    scale: context.view_box_scale(
      total_width,
      total_height,
      max_width=total_width,
      fixed=!use_max_width,
    ),
  }
  for name in [..quadrant_domains, "confusion"] {
    guard diagram.domains.get(name) is Some(domain_items) &&
      !domain_items.is_empty() else {
      continue
    }
    let layout = layout(name)
    let confusion = name == "confusion"
    let shown = if confusion && domain_items.length() > MAX_CONFUSION_ITEMS {
      domain_items[:MAX_CONFUSION_ITEMS].to_owned()
    } else {
      domain_items
    }
    let overflow = domain_items.length() - shown.length()
    let start_y = if confusion {
      layout.cy + (if show_descriptions { 22.0 } else { 14.0 })
    } else {
      layout.cy + (if show_descriptions { 25.0 } else { 15.0 })
    }
    for index, label in shown {
      item_text.draw_badge(
        items,
        label,
        layout.cx,
        start_y + index.to_double() * (ITEM_HEIGHT + 4.0),
        "cynefinItem",
        background(name),
        0.95,
      )
    }
    if overflow > 0 {
      item_text.draw_badge(
        items,
        "+\{overflow} more",
        layout.cx,
        start_y + shown.length().to_double() * (ITEM_HEIGHT + 4.0),
        "cynefinItemOverflow",
        background(name),
        0.6,
      )
    }
  }
  // 8. Transitions: arrows between the centres of two domains, bent
  // sideways by 15% of their length.
  if !diagram.transitions.is_empty() {
    let marker_id = "cynefin-arrow-\{context.id}"
    svg
    .append("defs")
    .append("marker")
    .attr("id", marker_id)
    .attr("viewBox", "0 0 10 10")
    .attr_number("refX", 9.0)
    .attr_number("refY", 5.0)
    .attr_number("markerWidth", 6.0)
    .attr_number("markerHeight", 6.0)
    .attr("orient", "auto-start-reverse")
    .append("path")
    .attr("d", "M 0 0 L 10 5 L 0 10 z")
    .attr("class", "cynefinArrowHead")
    |> ignore
    let arrows = root.append("g").attr("class", "cynefin-arrows")
    for transition in diagram.transitions {
      let from = layout(transition.from)
      let to = layout(transition.to)
      let x1 = from.cx
      let y1 = from.cy
      let x2 = to.cx
      let y2 = to.cy
      let mx = (x1 + x2) / 2.0
      let my = (y1 + y2) / 2.0
      let dx = x2 - x1
      let dy = y2 - y1
      let len = (dx * dx + dy * dy).sqrt()
      let offset = len * 0.15
      let nx = -dy / len
      let ny = dx / len
      let cpx = mx + nx * offset
      let cpy = my + ny * offset
      arrows
      .append("path")
      .attr("class", "cynefinArrowLine")
      .attr("d", "M\{n(x1)},\{n(y1)} Q\{n(cpx)},\{n(cpy)} \{n(x2)},\{n(y2)}")
      .attr("fill", "none")
      .attr("marker-end", "url(#\{marker_id})")
      |> ignore
      if transition.label is Some(label) {
        arrows
        .append("text")
        .attr("class", "cynefinArrowLabel")
        .attr_number("x", cpx)
        .attr_number("y", cpy - 6.0)
        .attr("text-anchor", "middle")
        .attr("dominant-baseline", "auto")
        .text(label)
        |> ignore
      }
    }
  }
  if diagram.title != "" {
    centred(root, "cynefinTitle", width / 2.0, -padding / 2.0, diagram.title)
  }
}
