// Drawing a block diagram: mermaid's `blockRenderer.ts` and
// `renderHelpers.ts`.

///|
/// `getStylesFromArray`: the declarations of a `style` statement, those
/// for the label apart from those for the shape.
fn split_styles(styles : Array[String]) -> (String, String) {
  let style = StringBuilder()
  let label_style = StringBuilder()
  for element in styles {
    if element.has_prefix("color:") || element.has_prefix("text-align:") {
      label_style.write_string(element + ";")
    } else {
      style.write_string(element + ";")
    }
  }
  (style.to_string(), label_style.to_string())
}

///|
/// The node the shared shapes draw for `block`: mermaid's
/// `getNodeFromBlock`. A `positioned` node is drawn where and as large as
/// the layout decided; otherwise it is drawn to be measured.
fn BlockDb::node_of(
  self : BlockDb,
  block : Block,
  positioned : Bool,
) -> @rendering.Node {
  let config = self.config
  let class_str = (if block.classes.length() > 0 {
      block.classes.join(" ")
    } else {
      "default"
    }) +
    " flowchart-label"
  let compiled = []
  for class_name in block.classes {
    if self.classes.get(class_name) is Some(found) {
      compiled.append(found.styles)
    }
  }
  let block_padding = config.number("block.padding").unwrap_or(0.0)
  let (shape, radius, padding) = match block.type_ {
    Some("round") => ("rect", 5.0, block_padding)
    Some("composite") => ("composite", 0.0, 0.0)
    Some("diamond") => ("question", 0.0, block_padding)
    Some("odd") => ("rect_left_inv_arrow", 0.0, block_padding)
    Some(
      "hexagon"
      | "block_arrow"
      | "lean_right"
      | "lean_left"
      | "trapezoid"
      | "inv_trapezoid"
      | "rect_left_inv_arrow"
      | "circle"
      | "ellipse"
      | "stadium"
      | "subroutine"
      | "cylinder"
      | "doublecircle" as shape
    ) => (shape, 0.0, block_padding)
    _ => ("rect", 0.0, block_padding)
  }
  let (style, label_style) = split_styles(block.styles)
  let (width, height, x, y) = match block.size {
    Some(size) => (size.width, size.height, size.x, size.y)
    None => (0.0, 0.0, 0.0, 0.0)
  }
  let id = block.id_text()
  // `bounds.width || undefined`: no width is no width to draw at, and
  // then the label does not wrap either.
  let width = if truthy(width) { Some(width) } else { None }
  let height = if truthy(height) { Some(height) } else { None }
  @rendering.Node::new(
    id~,
    label=block.label.unwrap_or(""),
    padding~,
    css_styles=block.styles,
    css_compiled_styles=compiled,
    css_classes=class_str,
    dom_id="\{self.diagram_id}-\{id}",
    look=config.text("look").unwrap_or("classic"),
    shape~,
    color_index?=block.color_index,
    data=Block(
      positioned~,
      directions=block.directions.unwrap_or([]),
      width_in_columns=block.width_in_columns.unwrap_or(1.0),
      style~,
    ),
    rx=radius,
    ry=radius,
    wrapping_width=width.unwrap_or(@double.infinity),
  ).placed(x~, y~, width?, height?, label_style~)
}

///|
/// Every block of a level before the blocks inside it, as mermaid's
/// `performOperations` visits them.
fn each_block(
  blocks : Array[Block],
  operation : (Block) -> Unit raise,
) -> Unit raise {
  for block in blocks {
    operation(block)
    each_block(block.children, operation)
  }
}

///|
/// The themes whose palettes colour composites by slot.
fn is_color_theme(config : @config.Config) -> Bool {
  config.text("theme") is Some("redux-color" | "redux-dark-color") &&
  config.theme().get("borderColorArray") is Array([_, ..])
}

///|
/// Draw the diagram into the context's `<svg>` element: mermaid's `draw`.
pub fn draw(db : BlockDb, context : @diagram.Context) -> Unit raise {
  let config = context.config
  let svg = context.svg
  db.diagram_id = context.id
  // What the port cannot draw yet is refused rather than drawn differently.
  if config.text("look") == Some("handDrawn") {
    raise @rendering.LayoutError("The hand-drawn look is not supported yet.")
  }
  each_block(db.root.children, block => {
    // Its width is divided by the columns it spans, and everything is
    // infinitely wide; what the browser makes of that is not ported.
    if block.width_in_columns == Some(0.0) {
      raise @rendering.LayoutError(
        "A block that spans no columns is not supported.",
      )
    }
  })
  let painter = @rendering.Painter::new(
    config,
    diagram_type="block",
    diagram_id=context.id,
  )
  painter.insert_look_defs(svg)
  @rendering.insert_markers(
    svg,
    ["point", "circle", "cross"],
    "block",
    context.id,
  )
  let nodes = svg.append("g").attr("class", "block")
  // Measure: every block is drawn once, unplaced, to learn its size.
  each_block(db.root.children, block => {
    let node = db.node_of(block, false)
    if block.type_ == Some("group") {
      return
    }
    let element = painter.insert_node(nodes, node)
    let box = element.bbox()
    if db.get_block(block.id) is Some(found) {
      found.size = Some({
        width: box.width,
        height: box.height,
        x: 0.0,
        y: 0.0,
      })
    }
    element.remove()
  })
  let bounds = db.layout()
  // Draw every block in its place.
  let n = @dom.number
  each_block(db.root.children, block => {
    let node = db.node_of(block, true)
    guard db.get_block(block.id) is Some(found) && found.type_ != Some("space") else {
      return
    }
    let element = painter.insert_node(nodes, node)
    // Only composites take a palette slot.
    if node.color_index is Some(color_index) &&
      is_color_theme(config) &&
      config.theme().get("borderColorArray") is Array(palette) {
      element.attr("data-color-id", "color-\{color_index % palette.length()}")
      |> ignore
    }
    block.node = Some(node)
    element.attr("transform", "translate(\{n(node.x)}, \{n(node.y)})") |> ignore
  })
  db.insert_edges(nodes, painter)
  // The size of the diagram is that of what was drawn.
  let rendered = nodes.bbox()
  let (x, y, width, height) = if rendered.width.is_inf() ||
    rendered.width.is_nan() ||
    rendered.height.is_inf() ||
    rendered.height.is_nan() {
    (bounds.x, bounds.y, bounds.width, bounds.height)
  } else {
    (rendered.x, rendered.y, rendered.width, rendered.height)
  }
  let magic_factor = 1.0.max(@d3.js_round(0.125 * (width / height)))
  @diagram.configure_svg_size(
    svg,
    height + magic_factor + 10.0,
    width + 10.0,
    match config.get("block.useMaxWidth") {
      Null => false
      value => @config.evaluate(value)
    },
  )
  svg.attr(
    "viewBox",
    "\{n(x - 5.0)} \{n(y - 5.0)} \{n(width + 10.0)} \{n(height + 10.0)}",
  )
  |> ignore
}

///|
/// `JSON.stringify` of a number.
fn json_number(value : Double) -> String {
  if value.is_nan() || value.is_inf() {
    "null"
  } else {
    @dom.number(value)
  }
}

///|
/// `JSON.stringify` of a string.
fn json_string(text : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  for i in 0..<text.length() {
    let unit = text[i].to_int()
    match unit {
      0x22 => out.write_string("\\\"")
      0x5c => out.write_string("\\\\")
      0x08 => out.write_string("\\b")
      0x0c => out.write_string("\\f")
      0x0a => out.write_string("\\n")
      0x0d => out.write_string("\\r")
      0x09 => out.write_string("\\t")
      _ =>
        // Control characters and halves of a pair on their own are
        // written as escapes.
        if unit < 0x20 ||
          (unit >= 0xdc00 && unit <= 0xdfff && !paired_before(text, i)) ||
          (unit >= 0xd800 && unit <= 0xdbff && !paired_after(text, i)) {
          let digits = "0123456789abcdef"
          out.write_string("\\u")
          for shift in [12, 8, 4, 0] {
            let digit = (unit >> shift) & 15
            out.write_view(digits[digit:digit + 1])
          }
        } else {
          out.write_view(text[i:i + 1])
        }
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
/// Whether the low surrogate at `i` follows a high one.
fn paired_before(text : String, i : Int32) -> Bool {
  i > 0 && text[i - 1].to_int() >= 0xd800 && text[i - 1].to_int() <= 0xdbff
}

///|
/// Whether the high surrogate at `i` is followed by a low one.
fn paired_after(text : String, i : Int32) -> Bool {
  i + 1 < text.length() &&
  text[i + 1].to_int() >= 0xdc00 &&
  text[i + 1].to_int() <= 0xdfff
}

///|
fn json_strings(values : Array[String]) -> String {
  "[" + values.map(json_string).join(",") + "]"
}

///|
/// `JSON.stringify` of a point of a route.
fn point_json(point : @rendering.Point) -> String {
  "{\"x\":\{json_number(point.x)},\"y\":\{json_number(point.y)}}"
}

///|
/// `JSON.stringify` of the node upstream drew `block` as, which is what
/// its route holds where the line to a block does not leave it: the
/// properties `getNodeFromBlock` gives the node, in its order, as the
/// shape left them. Those that are `undefined` or functions are left out.
fn BlockDb::node_json(
  self : BlockDb,
  block : Block,
  node : @rendering.Node,
) -> String {
  let fields : Array[String] = []
  let field = (name : String, value : String) => {
    fields.push("\"\{name}\":\{value}")
  }
  let number = (name : String, value : Double?) => {
    if value is Some(value) {
      field(name, json_number(value))
    }
  }
  let (style, _) = split_styles(block.styles)
  let width = block.width()
  field("labelStyle", json_string(node.label_style))
  field("shape", json_string(node.shape))
  if block.label is Some(label) {
    field("label", json_string(label))
    field("labelText", json_string(label))
  }
  number("rx", node.rx)
  number("ry", node.ry)
  field("class", json_string(node.css_classes))
  field("cssClasses", json_string(node.css_classes))
  field("cssStyles", json_strings(node.css_styles))
  field("cssCompiledStyles", json_strings(node.css_compiled_styles))
  field("style", json_string(style))
  if block.id is Some(id) {
    field("id", json_string(id))
  }
  field("domId", json_string("\{self.diagram_id}-\{block.id_text()}"))
  field("isGroup", "false")
  if block.directions is Some(directions) {
    field("directions", json_strings(directions))
  }
  number("width", node.width)
  number("height", node.height)
  field(
    "wrappingWidth",
    if truthy(width) {
      json_number(width)
    } else {
      "null"
    },
  )
  number("x", Some(node.x))
  number("y", Some(node.y))
  field("positioned", "true")
  number("padding", Some(node.padding))
  number("widthInColumns", Some(block.width_in_columns.unwrap_or(1.0)))
  if block.color_index is Some(index) {
    field("colorIndex", index.to_string())
  }
  field("look", json_string(node.look))
  "{" + fields.join(",") + "}"
}

///|
/// Draw the edges, each a line between the centres of two blocks cut off
/// at their outlines, and their labels: mermaid's `insertEdges`.
fn BlockDb::insert_edges(
  self : BlockDb,
  parent : @dom.Element,
  painter : @rendering.Painter,
) -> Unit raise {
  let n = @dom.number
  let look = ""
  for edge in self.edges {
    guard edge.start is Some(start_id) &&
      start_id != "" &&
      edge.end is Some(end_id) &&
      end_id != "" else {
      continue
    }
    guard self.get_block(Some(start_id)) is Some(start_block) &&
      self.get_block(Some(end_id)) is Some(end_block) &&
      start_block.size is Some(start) &&
      end_block.size is Some(end) else {
      continue
    }
    let centre : @rendering.Point = { x: start.x, y: start.y, }
    let middle : @rendering.Point = {
      x: start.x + (end.x - start.x) / 2.0,
      y: start.y + (end.y - start.y) / 2.0,
    }
    let mut points : Array[@rendering.Point] = [
      centre,
      middle,
      { x: end.x, y: end.y, },
    ]
    let mut points_json : String? = None
    if start_block.node is Some(tail) && end_block.node is Some(head) {
      // A diamond clips an edge through a method of the node it was
      // drawn for, which upstream calls on another object: the edge
      // cannot be drawn.
      if tail.shape == "question" || head.shape == "question" {
        raise BlockError("this.calcIntersect is not a function")
      }
      // The ends give way to where the line leaves and enters the blocks.
      let first = tail.leaves_at(middle)
      let last = head.leaves_at(middle)
      points = [
        first.unwrap_or({ x: tail.x, y: tail.y, }),
        middle,
        last.unwrap_or({ x: head.x, y: head.y, }),
      ]
      if first is None || last is None {
        // A block the line does not leave stands in the route itself.
        let written = (point : @rendering.Point?, block : Block, node) => {
          match point {
            Some(point) => point_json(point)
            None => self.node_json(block, node)
          }
        }
        let json = "[" +
          written(first, start_block, tail) +
          "," +
          point_json(middle) +
          "," +
          written(last, end_block, head) +
          "]"
        if json.iter().any(c => c.to_int() > 0xff) {
          raise BlockError(
            "Failed to execute 'btoa' on 'Window': The string to be encoded contains characters outside of the Latin1 range.",
          )
        }
        points_json = Some(json)
      }
    }
    let id = edge.id_text()
    let thickness_class = if edge.thickness == "thick" {
      "edge-thickness-thick"
    } else {
      "edge-thickness-normal"
    }
    let pattern_class = if edge.pattern == "dotted" {
      "edge-pattern-dotted"
    } else {
      "edge-pattern-solid"
    }
    let classes = "\{thickness_class} \{pattern_class} flowchart-link LS-a1 LE-b1"
    painter.insert_edge(
      parent,
      @rendering.Edge::new(
        id="\{self.diagram_id}-\{id}",
        start=start_id,
        end=end_id,
        thickness=edge.thickness,
        pattern=edge.pattern,
        classes~,
        arrow_type_start=edge.arrow_type_start,
        arrow_type_end=edge.arrow_type_end,
        // The edge has no `style`, which upstream writes out as it is.
        style=["undefined"],
        look~,
      ),
      points,
      points_json?,
    )
    |> ignore
    if edge.label is Some(label) && label != "" {
      let element = painter.insert_edge_label(
        parent,
        @rendering.Edge::new(id~, start=start_id, end=end_id, label~, look~),
      )
      let margin = self.config
        .number("flowchart.subGraphTitleMargin.top")
        .unwrap_or(0.0) +
        self.config
        .number("flowchart.subGraphTitleMargin.bottom")
        .unwrap_or(0.0)
      element.attr(
        "transform",
        "translate(\{n(points[1].x)}, \{n(points[1].y + margin / 2.0)})",
      )
      |> ignore
    }
  }
}
