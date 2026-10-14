///|
/// The size of a label, as `getBoundingClientRect()` reports it.
priv struct LabelBox {
  width : Double
  height : Double
}

///|
/// Text labels are wrapped in a paragraph; line breaks become `<br />`.
fn non_markdown_to_html(text : String) -> String {
  if text == "" {
    return ""
  }
  "<p>" +
  text.replace_all(old="\\n", new="<br />").replace_all(old="\n", new="<br />") +
  "</p>"
}

///|
/// mermaid's `createText` for HTML labels: a `foreignObject` holding a
/// `div` sized by the browser. Returns the `foreignObject` and the box of
/// its `div`.
fn create_html_label(
  parent : @dom.Element,
  text : String,
  env : Env,
  width? : Double,
  min_width~ : Double = 0.0,
  classes~ : String = "",
  style~ : String = "",
  is_node~ : Bool = true,
  add_background~ : Bool = false,
  markdown~ : Bool = false,
  padding_x~ : Double = 0.0,
  auto_wrap? : Bool,
) -> (@dom.Element, LabelBox) {
  // Callers that do not hand `createText` the configuration wrap
  // markdown whatever it says.
  let auto_wrap = auto_wrap.unwrap_or(
    !(env.config.get("markdownAutoWrap") is False),
  )
  let html = if markdown {
    markdown_to_html(text, auto_wrap)
  } else {
    non_markdown_to_html(text)
  }
  let html = replace_icons(@dom.placeholders_to_references(html))
  let fo = parent.append("foreignObject")
  // No width means no limit: the label never wraps.
  let initial = match width {
    Some(width) => @dom.number((10.0 * width).min(16384.0)) + "px"
    None => "16384px"
  }
  fo.attr("width", initial).attr("height", initial) |> ignore
  let div = fo.append("div")
  let span = div.append("span")
  span.set_inner_html(html)
  let label_style = style.replace(old="fill:", new="color:")
  // The style is written on the label, so its text is laid out with it.
  let env = env.styled(label_style)
  if label_style != "" {
    span.attr("style", label_style) |> ignore
  }
  let label_class = if is_node { "nodeLabel" } else { "edgeLabel" }
  span.attr("class", "\{label_class} \{classes}") |> ignore
  if label_style != "" {
    div.attr("style", label_style) |> ignore
  }
  div
  .style("display", "table-cell")
  .style("white-space", "nowrap")
  .style("line-height", "1.5")
  |> ignore
  if width is Some(width) {
    // A negative length is no value for `max-width`, and is dropped.
    if width >= 0.0 {
      div.style("max-width", @dom.number(width) + "px") |> ignore
    }
    div.style("text-align", "center") |> ignore
  }
  // Without the declaration nothing limits the label.
  let width = width.filter(width => width >= 0.0)
  div.attr("xmlns", "http://www.w3.org/1999/xhtml") |> ignore
  if add_background {
    div.attr("class", "labelBkg") |> ignore
  }
  // What the browser lays out: every line on its own unless the label
  // has to wrap. The label's own style can change the face and the size.
  let font = label_font(label_style)
  let env = match font.size {
    Some(size) => { ..env, font_size: size, }
    None => env
  }
  let styled = (line : Array[Run]) => {
    line.map(run => {
      ..run,
      bold: run.bold || font.bold,
      // A bold element in a label that is bold as a whole, by its own
      // style or by that of what it is in.
      heavy: run.heavy || (run.bold && (font.bold || env.bold)),
      italic: run.italic || font.italic,
    })
  }
  let lines = label_lines(span).map(collapse_runs).map(styled)
  let line_height = 1.5 * env.font_size
  let natural = lines.fold(init=0.0, (widest, line) => {
    widest.max(runs_width(line, env))
  })
  // A line break makes a line, even with nothing on it.
  let empty = lines.all(line => line.is_empty()) &&
    span.descendants(["br"]).is_empty()
  // A label wider than its limit is as wide as the limit, which the
  // browser holds in layout units: a single precision number of pixels
  // cut to a 64th.
  // The box measured is the border box: `padding_x` is the horizontal
  // padding the stylesheet gives the `div`, around its text.
  let mut box : LabelBox = {
    width: padding_x +
    (match width {
      Some(width) =>
        natural.min(
          (Float::from_double(width) * 64.0).to_double().floor() / 64.0,
        )
      None => natural
    }),
    height: if empty {
      0.0
    } else {
      line_height * lines.length().to_double()
    },
  }
  if width is Some(width) && box.width == width {
    div
    .style("display", "table")
    .style("white-space", "break-spaces")
    .style("width", @dom.number(width) + "px")
    |> ignore
    // A table is as wide as its widest piece that cannot be broken, and
    // the lines are then broken in the width it has.
    let lines = label_lines(span).map(styled)
    let mut box_width = width
    let mut rows = 0
    if keeps_on_one_line(label_style) {
      // The label's own style reaches the text through the `span` and
      // keeps it from wrapping; the table grows to hold it.
      box_width = box_width.max(natural)
      rows = lines.length()
    } else {
      for line in lines {
        box_width = box_width.max(wrapped_rows(line, width, env).1)
      }
      for line in lines {
        rows += wrapped_rows(line, box_width, env).0
      }
    }
    box = { width: box_width, height: line_height * rows.to_double(), }
  } else if box.width < min_width {
    div
    .style("display", "table")
    .style("width", @dom.number(min_width) + "px")
    .style("text-align", "center")
    |> ignore
    box = { ..box, width: min_width, }
  }
  (fo, box)
}

///|
/// What `label_helper` hands a shape: the node's group, its label group
/// and the label's box.
priv struct Labelled {
  shape_svg : @dom.Element
  label : @dom.Element
  bbox : LabelBox
  /// `bbox.x - bbox.left` and `bbox.y - bbox.top` of upstream's label box:
  /// zero for HTML labels, whose box has `left` and `top`; the origin of
  /// the text box for SVG labels, whose box does not.
  offset_x : Double
  offset_y : Double
}

///|
/// mermaid's `labelHelper`: create the node's group with its label inside
/// and measure the label.
fn label_helper(
  parent : @dom.Element,
  node : Node,
  classes : String,
  env : Env,
  unlimited~ : Bool = false,
  ignore_min_width~ : Bool = false,
  html_labels? : Bool,
) -> Labelled {
  // Nodes carrying a stereotype have a label of stacked sections.
  if node.data is C4(..) {
    return c4_label_helper(parent, node, classes, env)
  }
  let shape_svg = parent
    .append("g")
    .attr("class", classes)
    .attr("id", node.dom_id)
  let label = shape_svg
    .append("g")
    .attr("class", "label")
    .attr("style", node.label_style)
  let wrapping_width = match node.wrapping_width {
    Some(width) if width != 0.0 => width
    _ => env.config.number("flowchart.wrappingWidth").unwrap_or(200.0)
  }
  let min_label_width = if node.label != "" &&
    node.width is None &&
    !unlimited &&
    !ignore_min_width {
    node.min_width.unwrap_or(0.0)
  } else {
    0.0
  }
  // `node.width || node.wrappingWidth || ...`: a width of zero is none,
  // and a label told to wrap at infinity never does.
  let label_width = match node.width {
    _ if unlimited => None
    Some(width) if width != 0.0 && !width.is_nan() => Some(width)
    _ => if wrapping_width.is_inf() { None } else { Some(wrapping_width) }
  }
  let markdown = node.label_type == "markdown"
  let n = @dom.number
  let mut offset_x = 0.0
  let mut offset_y = 0.0
  // Node labels follow the root `htmlLabels` setting alone, whatever the
  // deprecated flowchart one says, unless the shape decides for itself.
  let html_labels = match (html_labels, env.config.get("htmlLabels")) {
    (Some(html_labels), _) => html_labels
    (None, Null) => true
    (None, value) => @config.evaluate(value)
  }
  let box = if html_labels {
    let (fo, box) = create_html_label(
      label,
      node.label,
      env,
      width?=label_width,
      min_width=min_label_width,
      classes=if markdown { "markdown-node-label" } else { "" },
      markdown~,
      style=node.label_style,
    )
    let box = if box.width < min_label_width {
      { ..box, width: min_label_width, }
    } else {
      box
    }
    fo.attr_number("width", box.width).attr_number("height", box.height)
    |> ignore
    label.attr(
      "transform",
      "translate(\{n(-box.width / 2.0)}, \{n(-box.height / 2.0)})",
    )
    |> ignore
    box
  } else {
    // Text centred by its anchor needs only its height shifted.
    let text = create_svg_label(
      label,
      node.label,
      env.styled(node.label_style, faces=false),
      width?=label_width,
      style=node.label_style,
      markdown~,
      anchor_middle=env.node_text_centred,
    )
    let box : LabelBox = {
      width: text.text_box.width.max(min_label_width),
      height: text.text_box.height,
    }
    // A box widened to the minimum width is centred on the text.
    offset_x = if text.text_box.width < min_label_width {
      text.text_box.x - (min_label_width - text.text_box.width) / 2.0
    } else {
      text.text_box.x
    }
    offset_y = text.text_box.y
    label.attr("transform", "translate(0, \{n(-box.height / 2.0)})") |> ignore
    box
  }
  if node.center_label {
    label.attr(
      "transform",
      "translate(\{n(-box.width / 2.0)}, \{n(-box.height / 2.0)})",
    )
    |> ignore
  }
  label.insert_first("rect") |> ignore
  { shape_svg, label, bbox: box, offset_x, offset_y, }
}

///|
/// Measure the title of a group the way its frame paints it: unwrapped.
/// Mermaid's `measureGroupLabel`.
fn measure_group_label(parent : @dom.Element, node : Node, env : Env) -> Unit {
  if node.label == "" {
    node.label_box = Some((0.0, 0.0))
    return
  }
  let labelled = label_helper(
    parent,
    node,
    "node default",
    env,
    unlimited=node.label_type != "markdown",
  )
  node.label_box = Some((labelled.bbox.width, labelled.bbox.height))
  labelled.shape_svg.remove()
}

///|
/// Turn `<br>` tags into newlines, as mermaid does for edge labels.
fn normalize_breaks(text : String) -> String {
  guard text.contains("<") else { return text }
  let out = StringBuilder()
  let chars = text.to_array()
  let n = chars.length()
  let mut i = 0
  while i < n {
    // <br>, <br/>, <br /> in any case.
    if chars[i] == '<' &&
      i + 2 < n &&
      chars[i + 1] is ('b' | 'B') &&
      chars[i + 2] is ('r' | 'R') {
      let mut j = i + 3
      while j < n && chars[j] is (' ' | '\t' | '\n' | '\r') {
        j += 1
      }
      if j < n && chars[j] == '/' {
        j += 1
      }
      if j < n && chars[j] == '>' {
        out.write_char('\n')
        i = j + 1
        continue
      }
    }
    out.write_char(chars[i])
    i += 1
  }
  out.to_string()
}

///|
/// Turn Font Awesome references such as `fa:fa-car` into the markup that
/// shows the icon: mermaid's `replaceIconSubstring` without registered
/// icon packs.
fn replace_icons(text : String) -> String {
  guard text.contains(":fa-") else { return text }
  let chars = text.to_array()
  let n = chars.length()
  let out = StringBuilder()
  let is_word = (c : Char) => {
    c is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_' | '-')
  }
  let mut i = 0
  while i < n {
    // (fa[bklrs]?):fa-([\w-]+)
    if chars[i] == 'f' && i + 1 < n && chars[i + 1] == 'a' {
      let mut j = i + 2
      if j < n && chars[j] is ('b' | 'k' | 'l' | 'r' | 's') {
        j += 1
      }
      if j + 3 < n &&
        chars[j] == ':' &&
        chars[j + 1] == 'f' &&
        chars[j + 2] == 'a' &&
        chars[j + 3] == '-' {
        let mut end = j + 4
        while end < n && is_word(chars[end]) {
          end += 1
        }
        if end > j + 4 {
          let prefix = String::from_array(chars[i:j])
          let name = String::from_array(chars[j + 1:end])
          out.write_string("<i class='\{prefix} \{name}'></i>")
          i = end
          continue
        }
      }
    }
    out.write_char(chars[i])
    i += 1
  }
  out.to_string()
}
