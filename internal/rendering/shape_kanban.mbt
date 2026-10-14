// The card of a kanban item: mermaid's `shapes/kanbanItem.ts`.

///|
/// What `insert_label` hands back: the label's group and its box.
priv struct InsertedLabel {
  label : @dom.Element
  bbox : LabelBox
}

///|
/// mermaid's `insertLabel`: a label of its own in `parent`, as markdown,
/// wrapped at `width`.
fn insert_label(
  parent : @dom.Element,
  text : String,
  env : Env,
  style~ : String,
  width~ : Double,
) -> InsertedLabel {
  let label = parent.append("g").attr("class", "label").attr("style", style)
  // `options.width || wrappingWidth`
  let width = if width != 0.0 && !width.is_nan() {
    width
  } else {
    env.config.number("flowchart.wrappingWidth").unwrap_or(200.0)
  }
  let n = @dom.number
  let bbox : LabelBox = if env.html_labels {
    let (fo, box) = create_html_label(
      label,
      text,
      env,
      width~,
      style~,
      markdown=true,
      auto_wrap=true,
    )
    fo.attr_number("width", box.width).attr_number("height", box.height)
    |> ignore
    label.attr(
      "transform",
      "translate(\{n(-box.width / 2.0)}, \{n(-box.height / 2.0)})",
    )
    |> ignore
    box
  } else {
    let text = create_svg_label(
      label,
      text,
      env,
      width~,
      style~,
      markdown=true,
      anchor_middle=env.node_text_centred,
    )
    let box : LabelBox = {
      width: text.text_box.width,
      height: text.text_box.height,
    }
    label.attr("transform", "translate(0, \{n(-box.height / 2.0)})") |> ignore
    box
  }
  label.insert_first("rect") |> ignore
  { label, bbox, }
}

///|
/// The colour of the bar that marks a priority, if it has one.
fn priority_color(priority : String) -> String? {
  match priority {
    "Very High" => Some("red")
    "High" => Some("orange")
    "Low" => Some("blue")
    "Very Low" => Some("lightblue")
    // `Medium` asks for none, and anything else is no priority.
    _ => None
  }
}

///|
/// JavaScript's `text.replace(pattern, replacement)` for a pattern that
/// is a string: the first occurrence, with the `$` patterns of the
/// replacement that need no capture.
fn js_replace_first(
  text : String,
  pattern : String,
  replacement : String,
) -> String {
  guard text.find(pattern) is Some(at) else { return text }
  let before = text[:at]
  let after = text[at + pattern.length():]
  let out = StringBuilder()
  out.write_view(before)
  let chars = replacement.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '$' && i + 1 < chars.length() {
      match chars[i + 1] {
        '$' => out.write_char('$')
        '&' => out.write_string(pattern)
        '`' => out.write_view(before)
        '\'' => out.write_view(after)
        other => {
          out.write_char('$')
          out.write_char(other)
        }
      }
      i += 2
    } else {
      out.write_char(chars[i])
      i += 1
    }
  }
  out.write_view(after)
  out.to_string()
}

///|
/// A card: its title over its ticket, on the left, and whom it is
/// assigned to, on the right, with a bar down its left side for its
/// priority.
fn kanban_item(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  guard node.data is KanbanItem(ticket~, assigned~, priority~, icon~) else {
    raise LayoutError("A kanban item without its data.")
  }
  let styles = shape_styles(node)
  let label_padding_x = 10.0
  let org_width = node.width
  node.width = Some(node.width.unwrap_or(200.0) - 10.0)
  // The title follows the root `htmlLabels` setting alone.
  let html_title = match env.config.get("htmlLabels") {
    Null => true
    value => @config.evaluate(value)
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let shape_svg = labelled.shape_svg
  let mut bbox = labelled.bbox
  // An icon is not drawn, but gives the title a background.
  if icon {
    if html_title {
      for fo in labelled.label.child_elements() {
        guard fo.tag == "foreignObject" else { continue }
        for div in fo.child_elements() {
          div.attr("class", "labelBkg") |> ignore
        }
      }
    } else if node.label != "" {
      // The text comes in a group with a rectangle behind it, which is
      // then what is styled and measured.
      for group in labelled.label.child_elements() {
        guard group.tag == "g" else { continue }
        for child in group.child_elements() {
          match child.tag {
            "rect" =>
              child
              .attr_number("x", labelled.offset_x - 2.0)
              .attr_number("y", labelled.offset_y - 2.0)
              .attr_number("width", bbox.width + 4.0)
              .attr_number("height", bbox.height + 4.0)
              |> ignore
            "text" =>
              if child.get_attr("style") is Some(style) {
                child.remove_attr("style") |> ignore
                group.attr("style", style) |> ignore
              }
            _ => ()
          }
        }
        let box = group.bbox()
        bbox = { width: box.width, height: box.height, }
      }
    }
  }
  let padding = if node.padding != 0.0 { node.padding } else { 10.0 }
  // A ticket links to where the configuration says tickets are.
  let link = match env.config.text("kanban.ticketBaseUrl") {
    Some(base) if base != "" && ticket != "" => {
      let url = js_replace_first(base, "#TICKET#", ticket)
      let link = shape_svg.insert_first("a").attr("class", "kanban-ticket-link")
      // Upstream also sets `target`, which the final sanitizing pass
      // strips from SVG anchors again, as it does an address it does not
      // allow.
      if allowed_uri(url) {
        link.attr("xlink:href", url) |> ignore
      }
      Some(link)
    }
    _ => None
  }
  let label_width = node.width.unwrap_or(0.0)
  let style = node.label_style
  let ticket_label = insert_label(
    link.unwrap_or(shape_svg),
    ticket,
    env,
    style~,
    width=label_width,
  )
  let assigned_label = insert_label(
    shape_svg,
    assigned,
    env,
    style~,
    width=label_width,
  )
  node.width = org_width
  let label_padding_y = 10.0
  let total_width = node.width.unwrap_or(0.0)
  let height_adj = ticket_label.bbox.height.max(assigned_label.bbox.height) /
    2.0
  let total_height = (bbox.height + label_padding_y * 2.0).max(
      node.height.unwrap_or(0.0),
    ) +
    height_adj
  let x = -total_width / 2.0
  let y = -total_height / 2.0
  let n = @dom.number
  labelled.label.attr(
    "transform",
    "translate(\{n(padding - total_width / 2.0)}, \{n(-height_adj - bbox.height / 2.0)})",
  )
  |> ignore
  ticket_label.label.attr(
    "transform",
    "translate(\{n(padding - total_width / 2.0)}, \{n(-height_adj + bbox.height / 2.0)})",
  )
  |> ignore
  assigned_label.label.attr(
    "transform",
    "translate(\{n(padding + total_width / 2.0 - assigned_label.bbox.width - 2.0 * label_padding_x)}, \{n(-height_adj + bbox.height / 2.0)})",
  )
  |> ignore
  // The items of a board are never drawn by hand: they come without a
  // look.
  let rect = shape_svg
    .insert_first("rect")
    .attr("class", "basic label-container __APA__")
    .attr("style", styles.node_styles)
    .attr_number("rx", node.rx.unwrap_or(5.0))
    .attr_number("ry", node.ry.unwrap_or(5.0))
    .attr_number("x", x)
    .attr_number("y", y)
    .attr_number("width", total_width)
    .attr_number("height", total_height)
  if priority is Some(priority) {
    let line_x = x + 2.0
    let inset = (node.rx.unwrap_or(0.0) / 2.0).floor()
    let line = shape_svg
      .append("line")
      .attr_number("x1", line_x)
      .attr_number("y1", y + inset)
      .attr_number("x2", line_x)
      .attr_number("y2", y + total_height - inset)
      .attr("stroke-width", "4")
    if priority_color(priority) is Some(color) {
      line.attr("stroke", color) |> ignore
    }
  }
  update_node_bounds(node, rect)
  node.height = Some(total_height)
  node.intersect = Some(point => {
    intersect_rect(
      node.x,
      node.y,
      node.width.unwrap_or(0.0),
      node.height.unwrap_or(0.0),
      point,
    )
  })
  shape_svg
}
