///|
const ICON_SIZE : Double = 14.0

///|
const ICON_GAP : Double = 4.0

///|
/// The gap between the widest label and the column of descriptions.
const DESC_GAP : Double = 16.0

///|
/// The `treeView` configuration.
priv struct Layout {
  row_indent : Double
  padding_x : Double
  padding_y : Double
  line_thickness : Double
  icons : IconConfig
  /// The font size of labels and descriptions.
  font_size : Double
  regular : @font.Stack
  bold : @font.Stack
  italic : @font.Stack
  bold_italic : @font.Stack
}

///|
/// Where a node's row is: its left edge, top, width and height.
priv struct Row {
  node : Node
  group : @dom.Element
  x : Double
  y : Double
  width : Double
  height : Double
  label_right_edge : Double
  highlighted : Bool
}

///|
/// The size `getBBox()` reports for a `<text>` of one line at `x`, `y`,
/// aligned on its middle baseline. The stylesheet's `white-space: pre`
/// keeps the text as written.
fn text_size(
  font : @font.Stack,
  text : String,
  size : Double,
  x~ : Double = 0.0,
  y~ : Double = 0.0,
) -> (Double, Double) raise Unsupported {
  if text == "" {
    return (0.0, 0.0)
  }
  if text.iter().any(c => c is ('\n' | '\r' | '\t')) {
    raise Unsupported("a tree view label with a line break or a tab")
  }
  if !font.covers(text) {
    raise Unsupported("text outside the fonts the port can measure: \{text}")
  }
  let box = font.svg_text_box(text, size, x~, y~, baseline=Middle)
  (box.width, box.height)
}

///|
/// The font size the browser computes for the theme's `labelFontSize`.
/// `parent` is the size inherited when the declaration is invalid, as a
/// bare number is, and the size relative units refer to.
fn css_font_size(value : Json, parent : Double) -> Double raise Unsupported {
  let text = match value {
    String(text) => text.trim(chars=" \t\n").to_owned().to_lower()
    Null => return 16.0
    // Written without a unit: not a length.
    _ => return parent
  }
  let unsupported = Unsupported(
    "labelFontSize is not a font size the port measures: \{text}",
  )
  guard @dom.css_dimension(text) is Some((number, unit)) else {
    raise unsupported
  }
  let size = match unit {
    "px" => number
    "em" => number * parent
    "rem" => number * 16.0
    "%" => number / 100.0 * parent
    "pt" => number * 4.0 / 3.0
    "" => return parent
    _ => raise unsupported
  }
  if size > 0.0 {
    size
  } else {
    raise unsupported
  }
}

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
/// Whether a node's class list names `class_name`.
fn has_class(node : Node, class_name : String) -> Bool {
  // A class annotation is a single name, so there is nothing to split.
  node.css_class == Some(class_name)
}

///|
/// Draw one node: its icon, its label and, for a highlighted node, the
/// background that is sized once the width of the tree is known.
fn Layout::position_label(
  self : Layout,
  x : Double,
  y : Double,
  node : Node,
  parent : @dom.Element,
) -> Row raise {
  let n = @dom.number
  let group = parent.append("g")
  let mut classes = "treeView-node-label"
  if node.directory {
    classes += " treeView-node-dir"
  }
  if node.css_class is Some(css_class) {
    classes += " \{css_class}"
  }
  let icon_offset = ICON_SIZE + ICON_GAP
  let icon = node_icon(node, self.icons)
  if icon is Some(icon) {
    group
    .append("g")
    .attr("class", "treeView-node-icon")
    .attr(
      "transform",
      "translate(\{n(x + self.padding_x)}, \{n(y + self.padding_y)})",
    )
    .append_child(icon_svg(icon))
  }
  let label = group
    .append("text")
    .text(node.name)
    .attr("dominant-baseline", "middle")
    .attr("class", classes)
  // The stylesheet's own classes can be given to any node, and then
  // change how its label is measured: bold as for a directory, italic as
  // for a description.
  let bold = node.directory || has_class(node, "treeView-node-dir")
  let font = match (bold, has_class(node, "treeView-node-description")) {
    (false, false) => self.regular
    (true, false) => self.bold
    (false, true) => self.italic
    (true, true) => self.bold_italic
  }
  let (label_width, label_height) = text_size(font, node.name, self.font_size)
  let height = label_height + self.padding_y * 2.0
  let label_x = x +
    self.padding_x +
    (if icon is Some(_) { icon_offset } else { 0.0 })
  label.attr_number("x", label_x).attr_number("y", y + height / 2.0) |> ignore
  let width = label_width +
    self.padding_x * 2.0 +
    (if icon is Some(_) { icon_offset } else { 0.0 })
  let highlighted = has_class(node, "highlight")
  if highlighted {
    group
    .insert_first("rect")
    .attr_number("x", x)
    .attr_number("y", y + 1.0)
    .attr_number("width", 0.0)
    .attr_number("height", height - 2.0)
    .attr_number("rx", 3.0)
    .attr("class", "treeView-highlight-bg")
    |> ignore
  }
  {
    node,
    group,
    x,
    y,
    width,
    height,
    label_right_edge: label_x + label_width,
    highlighted,
  }
}

///|
fn Layout::position_line(
  self : Layout,
  parent : @dom.Element,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Unit {
  parent
  .append("line")
  .attr_number("x1", x1)
  .attr_number("y1", y1)
  .attr_number("x2", x2)
  .attr_number("y2", y2)
  .attr_number("stroke-width", self.line_thickness)
  .attr("class", "treeView-node-line")
  |> ignore
}

///|
/// Draw the tree view into the context's `<svg>` element.
pub fn draw(tree : TreeView, context : @diagram.Context) -> Unit raise {
  let n = @dom.number
  let config = context.config
  let setting = (name : String, default : Double) => {
    config.number("treeView.\{name}").unwrap_or(default)
  }
  let theme = context.theme()
  let inherited = css_font_size(theme.get("fontSize"), 16.0)
  let layout : Layout = {
    row_indent: setting("rowIndent", 10.0),
    padding_x: setting("paddingX", 5.0),
    padding_y: setting("paddingY", 5.0),
    line_thickness: setting("lineThickness", 1.0),
    icons: {
      show_icons: config.flag("treeView.showIcons"),
      default_pack: config.text("treeView.defaultIconPack").unwrap_or(""),
      filename_icons: config.get("treeView.filenameIcons"),
      extension_icons: config.get("treeView.extensionIcons"),
    },
    font_size: css_font_size(
      theme.nested("treeView", "labelFontSize"),
      inherited,
    ),
    regular: context.font(),
    bold: context.font(bold=true),
    italic: context.font(italic=true),
    bold_italic: context.font(bold=true, italic=true),
  }
  let svg = context.svg
  let elem = svg.append("g").attr("class", "tree-view")
  let mut total_height = 0.0
  let mut total_width = 0.0
  let rows : Array[Row] = []
  // Rows in document order, each followed by the horizontal stub that
  // joins it to its parent's vertical line; then, once its children are
  // drawn, the vertical line down to the last of them.
  fn process(node : Node, depth : Int32) -> Row raise {
    let indent = depth.to_double() * (layout.row_indent + layout.padding_x)
    let row = layout.position_label(indent, total_height, node, elem)
    rows.push(row)
    layout.position_line(
      elem,
      indent - layout.row_indent,
      total_height + row.height / 2.0,
      indent,
      total_height + row.height / 2.0,
    )
    total_width = max(total_width, indent + row.width)
    total_height += row.height
    let mut last : Row? = None
    for child in node.children {
      last = Some(process(child, depth + 1))
    }
    if last is Some(last) {
      layout.position_line(
        elem,
        row.x + layout.padding_x,
        row.y + row.height,
        row.x + layout.padding_x,
        last.y + last.height / 2.0 + layout.line_thickness / 2.0,
      )
    }
    row
  }

  process(tree.root, 0) |> ignore
  // Descriptions share a column to the right of the widest label.
  if rows.iter().any(row => row.node.description is Some(_)) {
    let mut max_label_right = -1.0 / 0.0
    for row in rows {
      max_label_right = max(max_label_right, row.label_right_edge)
    }
    let desc_x = max_label_right + DESC_GAP
    for row in rows {
      guard row.node.description is Some(description) else { continue }
      row.group
      .append("text")
      .text(description)
      .attr("dominant-baseline", "middle")
      .attr("class", "treeView-node-description")
      .attr_number("x", desc_x)
      .attr_number("y", row.y + row.height / 2.0)
      |> ignore
      // Measured where it stands, unlike the labels.
      let (width, _) = text_size(
        layout.italic,
        description,
        layout.font_size,
        x=desc_x,
        y=row.y + row.height / 2.0,
      )
      total_width = max(total_width, desc_x + width + layout.padding_x)
    }
  }
  // Highlights span the tree from the node's indentation to its right
  // edge, each widening the tree for the ones after it.
  for row in rows {
    guard row.highlighted else { continue }
    guard row.group.child_elements().get(0) is Some(rect) else { continue }
    let rect_width = total_width - row.x + 8.0
    rect.attr_number("width", rect_width) |> ignore
    total_width = max(total_width, row.x + rect_width + 2.0)
  }
  // A line at x = 0 is centred on it, so half of it lies to the left.
  svg.attr(
    "viewBox",
    "-\{n(layout.line_thickness / 2.0)} 0 \{n(total_width)} \{n(total_height)}",
  )
  |> ignore
  @diagram.configure_svg_size(
    svg,
    total_height,
    total_width,
    config.flag("treeView.useMaxWidth"),
  )
}
