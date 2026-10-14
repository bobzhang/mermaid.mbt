///|
/// The padding around the children of a section.
const SECTION_INNER_PADDING : Double = 10.0

///|
const SECTION_HEADER_HEIGHT : Double = 25.0

///|
/// How values are written: `treemap.valueFormat`, a d3-format specifier
/// with an optional leading `$`.
priv enum ValueFormat {
  /// A format made when the diagram is drawn.
  Ready(@d3.Format)
  /// A `$`, then a format made when a value is formatted: an invalid
  /// specifier fails the diagram only if it has a value to show.
  Dollar(String)
}

///|
fn ValueFormat::new(config : @config.Config) -> ValueFormat {
  let specifier = match config.get("treemap.valueFormat") {
    String("") | Null | False => ","
    String(specifier) => specifier
    // Not a string: upstream fails to read it and falls back.
    _ => return Ready(try! @d3.format(","))
  }
  if specifier == "$0,0" {
    Dollar(",")
  } else if specifier.has_prefix("$") && specifier.contains(",") {
    // The precision is all that is kept of such a format.
    let precision = try! @jsregex.Regex::compile("\\.\\d+")
    Dollar(
      "," + precision.exec(specifier).map(found => found.text()).unwrap_or(""),
    )
  } else if specifier.has_prefix("$") {
    Dollar(specifier[1:].to_owned())
  } else {
    Ready(@d3.format(specifier) catch { _ => try! @d3.format(",") })
  }
}

///|
fn ValueFormat::apply(
  self : ValueFormat,
  value : Double,
) -> String raise TreemapError {
  match self {
    Ready(format) => format.apply(value)
    Dollar(specifier) => {
      let format = @d3.format(specifier) catch {
        @d3.InvalidFormat(message) => raise Invalid(message)
      }
      "$" + format.apply(value)
    }
  }
}

///|
/// A color scale over the theme variables `prefix0` to `prefix11`.
fn color_scale(
  theme : @theme.Theme,
  prefix : String,
  first? : String,
) -> @d3.Ordinal[String] {
  let range = []
  if first is Some(first) {
    range.push(first)
  }
  for i in 0..<12 {
    range.push(css_value(theme.get("\{prefix}\{i}")))
  }
  @d3.Ordinal::new(range)
}

///|
/// The sizes leaf labels start from and may shrink to: smaller in a
/// treemap with many leaves.
priv struct LeafSizes {
  base_label : Double
  base_value : Double
  min_label : Double
  min_value : Double
  label_padding : Double
  min_display_threshold : Double
  spacing : Double
  complex : Bool
}

///|
/// The size of a value under a label of `label_size`.
fn LeafSizes::value_size(self : LeafSizes, label_size : Double) -> Double {
  let scaled = @d3.js_round(label_size * 0.6)
  let capped = if scaled < self.base_value { scaled } else { self.base_value }
  if capped > self.min_value {
    capped
  } else {
    self.min_value
  }
}

///|
/// JavaScript's `parseInt` of a length such as `38px`.
fn parse_int(text : String) -> Double {
  @diagram.parse_float(text).floor()
}

///|
/// Refuse what the stylesheet of the classes cannot be trusted with. A
/// class of the diagram that is also a class of one of its elements: the rules mermaid writes for it (`.name > *`) would reach
/// that element's children, and with them the fonts texts are measured
/// in. A leaf of class `c` is given the class `cx`, of all things.
fn check_classes(treemap : Treemap) -> Unit raise TreemapError {
  let taken : Array[String] = [
    "treemapContainer", "treemapSection", "treemapNode", "treemapLeafGroup", "flowchart",
  ]
  fn collect(nodes : Array[Node]) {
    for node in nodes {
      if node.class_selector is Some(selector) {
        taken.push(selector + "x")
      }
      if node.children is Some(children) {
        collect(children)
      }
    }
  }

  collect(treemap.outer_nodes)
  let leaf = try! @jsregex.Regex::compile("^leaf\\d+x?$")
  for name, style_class in treemap.classes {
    if taken.contains(name) || leaf.matches(name) {
      raise Unsupported(
        "a treemap class called \{name}, which is also a class of the diagram's own elements",
      )
    }
    // `classDef` cuts its styles at commas, also inside `rgb(1,2,3)`.
    // What the browser makes of the pieces is not reproduced.
    for style in style_class.styles {
      let opened = style.iter().filter(c => c == '(').count()
      let closed = style.iter().filter(c => c == ')').count()
      if opened != closed {
        raise Unsupported("the treemap class style \{style}, cut at a comma")
      }
    }
  }
}

///|
/// What the port needs to know of a drawn text to report its box.
priv struct DrawnText {
  element : @dom.Element
  style : InlineStyle
  anchor : String
  baseline : String
  bold : Bool
  italic : Bool
}

///|
/// Draw the treemap into the context's `<svg>` element.
pub fn draw(
  treemap : Treemap,
  context : @diagram.Context,
) -> Unit raise TreemapError {
  let n = @dom.number
  let config = context.config
  let theme = context.theme()
  let svg = context.svg
  let id = context.id
  let inner_padding = config.number("treemap.padding").unwrap_or(10.0)
  let title = treemap.title
  let title_height = if title != "" { 30.0 } else { 0.0 }
  // `config.nodeWidth ? config.nodeWidth * SECTION_INNER_PADDING : 960`
  let width = match config.number("treemap.nodeWidth") {
    Some(node_width) if node_width != 0.0 && !node_width.is_nan() =>
      node_width * SECTION_INNER_PADDING
    _ => 960.0
  }
  let height = match config.number("treemap.nodeHeight") {
    Some(node_height) if node_height != 0.0 && !node_height.is_nan() =>
      node_height * SECTION_INNER_PADDING
    _ => 500.0
  }
  let show_values = !(config.get("treemap.showValues") is False)
  let use_max_width = config.flag("treemap.useMaxWidth")
  let svg_width = width
  let svg_height = height + title_height
  svg.attr("viewBox", "0 0 \{n(svg_width)} \{n(svg_height)}") |> ignore
  @diagram.configure_svg_size(svg, svg_height, svg_width, use_max_width)
  // Text is measured in the diagram as the page displays it at this
  // point: the view box is set, and the size limited to it or fixed.
  let scale = context.view_box_scale(
    svg_width,
    svg_height,
    max_width=svg_width,
    fixed=!use_max_width,
  )
  if !(scale > 0.0) || scale.is_inf() {
    raise Unsupported("a treemap without a size")
  }
  let value_format = ValueFormat::new(config)
  let color = color_scale(theme, "cScale", first="transparent")
  let color_peer = color_scale(theme, "cScalePeer", first="transparent")
  let color_label = color_scale(theme, "cScaleLabel")
  check_classes(treemap)
  let texts : Array[DrawnText] = []
  if title != "" {
    let element = svg
      .append("text")
      .attr("x", n(svg_width / 2.0))
      .attr("y", n(title_height / 2.0))
      .attr("class", "treemapTitle")
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", "middle")
      .text(title)
    texts.push({
      element,
      style: InlineStyle::parse("font-size: \{title_font_size(theme)}"),
      anchor: "middle",
      baseline: "middle",
      bold: false,
      italic: false,
    })
  }
  let g = svg
    .append("g")
    .attr("transform", "translate(0, \{n(title_height)})")
    .attr("class", "treemapContainer")
  // The outer nodes hang from a root without a name, which is not drawn.
  let root_data : Node = {
    name: "",
    children: Some(treemap.outer_nodes),
    value: None,
    class_selector: None,
    css_compiled_styles: [],
  }
  let root = @d3.hierarchy(root_data, node => node.children.unwrap_or([]))
  for node in root.descendants() {
    if node.data.value is Some(value) && value.is_inf() {
      raise Unsupported("an infinite value in a treemap")
    }
  }
  root.sum(node => node.value.unwrap_or(0.0))
  root.sort((a, b) => b.value - a.value)
  let layout : @d3.TreemapLayout[Node] = {
    width,
    height,
    padding_inner: _ => inner_padding,
    padding_top: _ => SECTION_HEADER_HEIGHT + SECTION_INNER_PADDING,
    padding_right: _ => SECTION_INNER_PADDING,
    padding_bottom: _ => SECTION_INNER_PADDING,
    padding_left: _ => SECTION_INNER_PADDING,
    round: true,
  }
  layout.layout(root)
  // What a truthy number is to JavaScript.
  let truthy = (value : Double) => value != 0.0 && !value.is_nan()
  // The label styles of a node's class, as they are appended to the
  // style of its texts: `color` becomes `fill`, the first time it occurs.
  let label_styles = (node : Node) => {
    let split = split_styles(node.css_compiled_styles)
    for key in split.label_keys {
      if unmeasured.contains(key) {
        raise Unsupported("the style \{key} on a treemap label")
      }
    }
    split.label_styles.replace(old="color:", new="fill:")
  }
  // d3 sets one attribute on every element before it sets the next, and
  // the color scales give out their colors in the order they are asked.
  let branches = root.descendants().filter(node => node.children is Some(_))
  let sections = branches.map(node => {
    g
    .append("g")
    .attr("class", "treemapSection")
    .attr("transform", "translate(\{n(node.x0)},\{n(node.y0)})")
  })
  for i, node in branches {
    sections[i]
    .append("rect")
    .attr("width", n(node.x1 - node.x0))
    .attr("height", n(SECTION_HEADER_HEIGHT))
    .attr("class", "treemapSectionHeader")
    .attr("fill", "none")
    .attr("fill-opacity", "0.6")
    .attr("stroke-width", "0.6")
    .attr("style", if node.depth == 0 { "display: none;" } else { "" })
    |> ignore
  }
  for i, node in branches {
    let clip_width = node.x1 - node.x0 - 12.0
    sections[i]
    .append("clipPath")
    .attr("id", "clip-section-\{id}-\{i}")
    .append("rect")
    .attr("width", n(if clip_width > 0.0 { clip_width } else { 0.0 }))
    .attr("height", n(SECTION_HEADER_HEIGHT))
    |> ignore
  }
  let section_fills = branches.map(node => color.get(node.data.name))
  let section_strokes = branches.map(node => color_peer.get(node.data.name))
  for i, node in branches {
    let style = if node.depth == 0 {
      "display: none;"
    } else {
      let split = split_styles(node.data.css_compiled_styles)
      split.node_styles + ";" + split.border_styles.join(";")
    }
    sections[i]
    .append("rect")
    .attr("width", n(node.x1 - node.x0))
    .attr("height", n(node.y1 - node.y0))
    .attr("class", "treemapSection section\{i}")
    .attr("fill", section_fills[i])
    .attr("fill-opacity", "0.6")
    .attr("stroke", section_strokes[i])
    .attr("stroke-width", "2")
    .attr("stroke-opacity", "0.4")
    .attr("style", style)
    |> ignore
  }
  // Section labels, cut short with an ellipsis where the header is too
  // narrow for them.
  let section_label_styles = branches.map(node => {
    if node.depth == 0 {
      "display: none;"
    } else {
      "dominant-baseline: middle; font-size: 12px; fill:" +
      color_label.get(node.data.name) +
      "; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" +
      label_styles(node.data)
    }
  })
  for i, node in branches {
    let label = sections[i]
      .append("text")
      .attr("class", "treemapSectionLabel")
      .attr("x", "6")
      .attr("y", n(SECTION_HEADER_HEIGHT / 2.0))
      .attr("dominant-baseline", "middle")
      .text(if node.depth == 0 { "" } else { node.data.name })
      .attr("font-weight", "bold")
      .attr("clip-path", "url(#clip-section-\{id}-\{i})")
      .attr("style", section_label_styles[i])
    if node.depth == 0 {
      continue
    }
    let style = InlineStyle::parse(section_label_styles[i])
    let (font, size) = style.font(context, bold=true)
    let original = node.data.name
    let total_header_width = node.x1 - node.x0
    let label_x = 6.0
    let space = if show_values && truthy(node.value) {
      let value_ends_at = total_header_width - 10.0
      let estimated_value_width = 30.0
      let gap = 10.0
      value_ends_at - estimated_value_width - gap - label_x
    } else {
      let own_right_padding = 6.0
      total_header_width - label_x - own_right_padding
    }
    let minimum_width = 15.0
    let available = if space > minimum_width { space } else { minimum_width }
    if text_length(font, original, size, scale) > available {
      let ellipsis = "..."
      let mut length = original.length()
      while length > 0 {
        length -= 1
        if length == 0 {
          label.text(ellipsis) |> ignore
          if text_length(font, ellipsis, size, scale) > available {
            label.text("") |> ignore
          }
          break
        }
        // The text is cut by UTF-16 units, which may split a character.
        if original[length - 1] is (0xd800..<=0xdbff) {
          raise Unsupported(
            "a treemap section name cut inside a character: \{original}",
          )
        }
        let truncated = original[:length].to_owned() + ellipsis
        label.text(truncated) |> ignore
        if text_length(font, truncated, size, scale) <= available {
          break
        }
      }
    }
    texts.push({
      element: label,
      style,
      anchor: "start",
      baseline: "middle",
      bold: true,
      italic: false,
    })
  }
  if show_values {
    let value_styles = branches.map(node => {
      if node.depth == 0 {
        "display: none;"
      } else {
        "text-anchor: end; dominant-baseline: middle; font-size: 10px; fill:" +
        color_label.get(node.data.name) +
        "; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" +
        label_styles(node.data)
      }
    })
    let value_texts = []
    for node in branches {
      value_texts.push(
        if truthy(node.value) {
          value_format.apply(node.value)
        } else {
          ""
        },
      )
    }
    for i, node in branches {
      let element = sections[i]
        .append("text")
        .attr("class", "treemapSectionValue")
        .attr("x", n(node.x1 - node.x0 - 10.0))
        .attr("y", n(SECTION_HEADER_HEIGHT / 2.0))
        .attr("text-anchor", "end")
        .attr("dominant-baseline", "middle")
        .text(value_texts[i])
        .attr("font-style", "italic")
        .attr("style", value_styles[i])
      if node.depth != 0 {
        texts.push({
          element,
          style: InlineStyle::parse(value_styles[i]),
          anchor: "end",
          baseline: "middle",
          bold: false,
          italic: true,
        })
      }
    }
  }
  // The leaves.
  let leaves = root.leaves()
  let complex = leaves.length() > 20
  let sizes : LeafSizes = if complex {
    {
      base_label: 16.0,
      base_value: 14.0,
      min_label: 4.0,
      min_value: 4.0,
      label_padding: 2.0,
      min_display_threshold: 8.0,
      spacing: 1.0,
      complex,
    }
  } else {
    {
      base_label: 38.0,
      base_value: 28.0,
      min_label: 8.0,
      min_value: 6.0,
      label_padding: 4.0,
      min_display_threshold: 10.0,
      spacing: 2.0,
      complex,
    }
  }
  let cells = []
  for i, node in leaves {
    let selector = match node.data.class_selector {
      Some(selector) if selector != "" => " \{selector}"
      _ => ""
    }
    cells.push(
      g
      .append("g")
      .attr("class", "treemapNode treemapLeafGroup leaf\{i}\{selector}x")
      .attr("transform", "translate(\{n(node.x0)},\{n(node.y0)})"),
    )
  }
  // A leaf takes the color of its section.
  let leaf_color = (node : @d3.HierarchyNode[Node]) => {
    match node.parent {
      Some(parent) => color.get(parent.data.name)
      None => color.get(node.data.name)
    }
  }
  let leaf_fills = leaves.map(leaf_color)
  let leaf_strokes = leaves.map(leaf_color)
  for i, node in leaves {
    cells[i]
    .append("rect")
    .attr("width", n(node.x1 - node.x0))
    .attr("height", n(node.y1 - node.y0))
    .attr("class", "treemapLeaf")
    .attr("fill", leaf_fills[i])
    .attr("style", split_styles(node.data.css_compiled_styles).node_styles)
    .attr("fill-opacity", "0.3")
    .attr("stroke", leaf_strokes[i])
    .attr("stroke-width", "3")
    |> ignore
  }
  for i, node in leaves {
    let clip_width = node.x1 - node.x0 - 4.0
    let clip_height = node.y1 - node.y0 - 4.0
    cells[i]
    .append("clipPath")
    .attr("id", "clip-\{id}-\{i}")
    .append("rect")
    .attr("width", n(if clip_width > 0.0 { clip_width } else { 0.0 }))
    .attr("height", n(if clip_height > 0.0 { clip_height } else { 0.0 }))
    |> ignore
  }
  let label_style_texts = leaves.map(node => {
    "text-anchor: middle; dominant-baseline: middle; font-size: \{n(sizes.base_label)}px;fill:" +
    color_label.get(node.data.name) +
    ";" +
    label_styles(node.data)
  })
  let labels : Array[DrawnText] = []
  for i, node in leaves {
    let element = cells[i]
      .append("text")
      .attr("class", "treemapLabel")
      .attr("x", n((node.x1 - node.x0) / 2.0))
      .attr("y", n((node.y1 - node.y0) / 2.0))
      .attr("style", label_style_texts[i])
      .attr("clip-path", "url(#clip-\{id}-\{i})")
      .text(node.data.name)
    labels.push({
      element,
      style: InlineStyle::parse(label_style_texts[i]),
      anchor: "middle",
      baseline: "middle",
      bold: false,
      italic: false,
    })
  }
  // Shrink every label until it fits its cell, or hide it.
  for i, node in leaves {
    let label = labels[i]
    let style = label.style
    let node_width = node.x1 - node.x0
    let node_height = node.y1 - node.y0
    let available_width = node_width - 2.0 * sizes.label_padding
    let available_height = node_height - 2.0 * sizes.label_padding
    if available_width < sizes.min_display_threshold ||
      available_height < sizes.min_display_threshold {
      style.set("display", "none")
      continue
    }
    let length = () => {
      let (font, size) = style.font(context)
      text_length(font, node.data.name, size, scale)
    }
    let mut current = parse_int(style.get("font-size").unwrap_or(""))
    while length() > available_width && current > sizes.min_label {
      current -= 1.0
      style.set("font-size", "\{n(current)}px")
    }
    let mut prospective = sizes.value_size(current)
    let mut combined = current + sizes.spacing + prospective
    while combined > available_height && current > sizes.min_label {
      current -= 1.0
      prospective = sizes.value_size(current)
      if prospective < sizes.min_value && current == sizes.min_label {
        break
      }
      style.set("font-size", "\{n(current)}px")
      combined = current + sizes.spacing + prospective
    }
    style.set("font-size", "\{n(current)}px")
    if sizes.complex {
      if current < sizes.min_label || available_height < sizes.min_label {
        style.set("display", "none")
      }
    } else if length() > available_width ||
      current < sizes.min_label ||
      available_height < current {
      style.set("display", "none")
    }
  }
  if show_values {
    let value_style_texts = leaves.map(node => {
      "text-anchor: middle; dominant-baseline: hanging; font-size: \{n(sizes.base_value)}px;fill:" +
      color_label.get(node.data.name) +
      ";" +
      label_styles(node.data)
    })
    let value_texts = []
    for node in leaves {
      value_texts.push(
        if truthy(node.value) {
          value_format.apply(node.value)
        } else {
          ""
        },
      )
    }
    let values : Array[DrawnText] = []
    for i, node in leaves {
      let element = cells[i]
        .append("text")
        .attr("class", "treemapValue")
        .attr("x", n((node.x1 - node.x0) / 2.0))
        .attr("y", n((node.y1 - node.y0) / 2.0))
        .attr("style", value_style_texts[i])
        .attr("clip-path", "url(#clip-\{id}-\{i})")
        .text(value_texts[i])
      values.push({
        element,
        style: InlineStyle::parse(value_style_texts[i]),
        anchor: "middle",
        baseline: "hanging",
        bold: false,
        italic: false,
      })
    }
    // A value sits under its label, in a size that follows the label's.
    for i, node in leaves {
      let style = values[i].style
      let label_style = labels[i].style
      if label_style.get("display") == Some("none") {
        style.set("display", "none")
        continue
      }
      let final_label_size = @diagram.parse_float(
        label_style.get("font-size").unwrap_or(""),
      )
      let actual = sizes.value_size(final_label_size)
      style.set("font-size", "\{n(actual)}px")
      let label_center_y = (node.y1 - node.y0) / 2.0
      let value_top = label_center_y + final_label_size / 2.0 + sizes.spacing
      values[i].element.attr("y", n(value_top)) |> ignore
      let node_width = node.x1 - node.x0
      let node_total_height = node.y1 - node.y0
      let cell_bottom_padding = 4.0
      let max_value_bottom = node_total_height - cell_bottom_padding
      let available_width = node_width - 2.0 * sizes.label_padding
      let (font, size) = style.font(context)
      if text_length(font, value_texts[i], size, scale) > available_width ||
        value_top + actual > max_value_bottom ||
        actual < sizes.min_value {
        style.set("display", "none")
      }
    }
    for value in values {
      texts.push(value)
    }
  }
  for label in labels {
    texts.push(label)
  }
  // Write the styles the way the document serializes them, and give
  // every text that is displayed its box.
  for text in texts {
    let style = text.style
    if style.changed {
      text.element.attr("style", style.text()) |> ignore
    }
    if style.get("display") == Some("none") {
      continue
    }
    let (font, size) = style.font(context, bold=text.bold, italic=text.italic)
    place_text(
      text.element,
      font,
      size,
      anchor=text.anchor,
      baseline=text.baseline,
      scale~,
    )
  }
  let diagram_padding = config.number("treemap.diagramPadding").unwrap_or(8.0)
  @rendering.setup_viewport(svg, diagram_padding, "flowchart", use_max_width)
}
