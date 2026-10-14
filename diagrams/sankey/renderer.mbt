///|
/// Text as SVG lays it out without `xml:space="preserve"`: line breaks
/// and tabs are spaces, runs of spaces collapse, and the spaces at both
/// ends go.
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
/// Record the box the browser reports for a label: a `<text>` at its `x`
/// and `y` attributes, shifted down by `dy` ems, starting or ending at
/// `x`. Positions are single precision in the browser.
fn place_label(
  element : @dom.Element,
  font : @font.Stack,
  size : Double,
  dy : Double,
  anchor_end : Bool,
) -> Unit {
  let text = collapse_spaces(element.text_content())
  if text == "" {
    return
  }
  let f = Float::from_double
  let x = f(element.length_attr("x").unwrap_or(0.0))
  let y = f(element.length_attr("y").unwrap_or(0.0)) + f(dy) * f(size)
  let start = if anchor_end {
    let end = x + f(font.advance(text, size))
    x + (x - end)
  } else {
    x
  }
  let box = font.bbox(text, size)
  element.set_text_box({
    x: (start + f(box.x)).to_double(),
    y: (y + f(box.y)).to_double(),
    width: box.width,
    height: box.height,
  })
}

///|
/// What `nodeColors[id]` finds on a plain object without a property `id`:
/// a member of `Object.prototype`, as the string it is written as when it
/// becomes an attribute. Upstream looks colors up without asking whether
/// the property is the object's own, so a node called `toString` is
/// filled with a function.
fn inherited_member(id : String) -> String? {
  match id {
    "constructor" => Some("function Object() { [native code] }")
    "__proto__" => Some("[object Object]")
    "__defineGetter__"
    | "__defineSetter__"
    | "__lookupGetter__"
    | "__lookupSetter__"
    | "hasOwnProperty"
    | "isPrototypeOf"
    | "propertyIsEnumerable"
    | "toLocaleString"
    | "toString"
    | "valueOf" => Some("function \{id}() { [native code] }")
    _ => None
  }
}

///|
/// The font size of the labels, set on their group.
const LABEL_SIZE : Double = 14.0

///|
/// Draw the Sankey diagram into the context's `<svg>` element.
pub fn draw(
  sankey : Sankey,
  context : @diagram.Context,
) -> Unit raise SankeyError {
  let n = @dom.number
  let config = context.config
  let svg = context.svg
  let setting = (name : String, default : Double) => {
    config.number("sankey." + name).unwrap_or(default)
  }
  let width = setting("width", 600.0)
  let height = setting("height", 400.0)
  let use_max_width = config.flag("sankey.useMaxWidth")
  let prefix = config.text("sankey.prefix").unwrap_or("")
  let suffix = config.text("sankey.suffix").unwrap_or("")
  let show_values = config.flag("sankey.showValues")
  let node_width = setting("nodeWidth", 10.0)
  let node_padding = setting("nodePadding", 12.0)
  let outlined = config.text("sankey.labelStyle") == Some("outlined")
  let node_colors : Map[String, String] = Map([])
  if config.get("sankey.nodeColors") is Object(colors) {
    for id, color in colors {
      if color is String(color) {
        node_colors[id] = color
      }
    }
  }
  let align : @d3.SankeyAlign = match config.text("sankey.nodeAlignment") {
    Some("left") => Left
    Some("right") => Right
    Some("center") => Center
    Some("justify") | None => Justify
    Some(other) =>
      // Upstream calls an alignment function that does not exist.
      raise Invalid("unknown node alignment: \{other}")
  }
  let graph = @d3.sankey(
    sankey.nodes.length(),
    sankey.links,
    node_width~,
    node_padding=node_padding + (if show_values { 15.0 } else { 0.0 }),
    align~,
    extent=(0.0, 0.0, width, height),
  ) catch {
    @d3.CircularLink => raise Invalid("circular link")
  }
  // `findCentralNodeLayer`: the column of the largest node.
  let mut max_value = 0.0
  let mut central_layer = 0
  for node in graph.nodes {
    if node.value > max_value {
      max_value = node.value
      central_layer = node.layer
    }
  }
  let scheme = @d3.Ordinal::new(@d3.scheme_tableau10)
  let node_color = (index : Int32) => {
    let id = sankey.nodes[index]
    match node_colors.get(id) {
      Some(color) => color
      None =>
        match inherited_member(id) {
          Some(inherited) => inherited
          None => scheme.get(id)
        }
    }
  }
  // `Uid.next`: one counter for the nodes and the gradients.
  let mut uid = 0
  let nodes = svg.append("g").attr("class", "nodes")
  for node in graph.nodes {
    uid += 1
    nodes
    .append("g")
    .attr("class", "node")
    .attr("id", "node-\{uid}")
    .attr("transform", "translate(\{n(node.x0)},\{n(node.y0)})")
    .attr("x", n(node.x0))
    .attr("y", n(node.y0))
    .append("rect")
    .attr("height", n(node.y1 - node.y0))
    .attr("width", n(node.x1 - node.x0))
    .attr("fill", node_color(node.index))
    |> ignore
  }
  let labels = svg
    .append("g")
    .attr("class", "node-labels")
    .attr("font-size", "14")
  let font = context.font()
  let append_labels = (class_name : String?) => {
    for node in graph.nodes {
      let label = labels.append("text")
      if class_name is Some(class_name) {
        label.attr("class", class_name) |> ignore
      }
      // Outlined labels go by column, on the outer side of the largest
      // node's; legacy ones by which half of the diagram the node is in.
      let anchor_end = if outlined {
        node.layer < central_layer
      } else {
        !(node.x0 < width / 2.0)
      }
      let x = if anchor_end { node.x0 - 6.0 } else { node.x1 + 6.0 }
      let id = sankey.nodes[node.index]
      let text = if show_values {
        "\{id}\n\{prefix}\{n(@d3.js_round(node.value * 100.0) / 100.0)}\{suffix}"
      } else {
        id
      }
      label
      .attr("x", n(x))
      .attr("y", n((node.y1 + node.y0) / 2.0))
      .attr("dy", if show_values { "0em" } else { "0.35em" })
      .attr("text-anchor", if anchor_end { "end" } else { "start" })
      .text(text)
      |> ignore
      place_label(
        label,
        font,
        LABEL_SIZE,
        if show_values {
          0.0
        } else {
          0.35
        },
        anchor_end,
      )
    }
  }
  if outlined {
    append_labels(Some("sankey-label-bg"))
    append_labels(Some("sankey-label-fg"))
  } else {
    append_labels(None)
  }
  let links = svg
    .append("g")
    .attr("class", "links")
    .attr("fill", "none")
    .attr("stroke-opacity", "0.5")
  let link_color = config.text("sankey.linkColor").unwrap_or("gradient")
  let groups = []
  for _ in graph.links {
    groups.push(
      links
      .append("g")
      .attr("class", "link")
      .style("mix-blend-mode", "multiply"),
    )
  }
  let gradients = []
  if link_color == "gradient" {
    for index, link in graph.links {
      uid += 1
      let id = "linearGradient-\{uid}"
      gradients.push(id)
      let gradient = groups[index]
        .append("linearGradient")
        .attr("id", id)
        .attr("gradientUnits", "userSpaceOnUse")
        .attr("x1", n(graph.nodes[link.source].x1))
        .attr("x2", n(graph.nodes[link.target].x0))
      gradient
      .append("stop")
      .attr("offset", "0%")
      .attr("stop-color", node_color(link.source))
      |> ignore
      gradient
      .append("stop")
      .attr("offset", "100%")
      .attr("stop-color", node_color(link.target))
      |> ignore
    }
  }
  for index, link in graph.links {
    let stroke = match link_color {
      "gradient" => "url(#\{gradients[index]})"
      "source" => node_color(link.source)
      "target" => node_color(link.target)
      color => color
    }
    // `Math.max(1, width)`
    let stroke_width = if link.width.is_nan() {
      link.width
    } else if link.width > 1.0 {
      link.width
    } else {
      1.0
    }
    groups[index]
    .append("path")
    .attr("d", graph.link_horizontal(link))
    .attr("stroke", stroke)
    .attr("stroke-width", n(stroke_width))
    |> ignore
  }
  // `setupGraphViewbox` without padding.
  let bounds = svg.bbox()
  @diagram.configure_svg_size(svg, bounds.height, bounds.width, use_max_width)
  svg.attr(
    "viewBox",
    "\{n(bounds.x)} \{n(bounds.y)} \{n(bounds.width)} \{n(bounds.height)}",
  )
  |> ignore
}
