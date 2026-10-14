// Markers, activations, blocks, boxes and popup menus (svgDraw.js).

///|
/// The icon symbols and arrow heads every diagram defines.
fn Renderer::insert_definitions(self : Renderer) -> Unit {
  let svg = self.svg
  let id = self.id
  let symbol = (name : String, path : String) => {
    svg
    .append("defs")
    .append("symbol")
    .attr("id", "\{id}-\{name}")
    .attr("width", "24")
    .attr("height", "24")
    .append("path")
    .attr("transform", "scale(.5)")
    .attr("d", path)
    |> ignore
  }
  symbol("computer", computer_icon)
  svg
  .append("defs")
  .append("symbol")
  .attr("id", "\{id}-database")
  .attr("fill-rule", "evenodd")
  .attr("clip-rule", "evenodd")
  .append("path")
  .attr("transform", "scale(.5)")
  .attr("d", database_icon)
  |> ignore
  symbol("clock", clock_icon)
}

///|
fn Renderer::insert_markers(self : Renderer) -> Unit {
  let svg = self.svg
  let id = self.id
  // A half or full arrow head that turns with the line's direction.
  let head = (name : String, ref_y : Double, path : String) => {
    svg
    .append("defs")
    .append("marker")
    .attr("id", "\{id}-\{name}")
    .attr_number("refX", 7.9)
    .attr_number("refY", ref_y)
    .attr("markerUnits", "userSpaceOnUse")
    .attr_number("markerWidth", 12.0)
    .attr_number("markerHeight", 12.0)
    .attr("orient", "auto-start-reverse")
    .append("path")
    .attr("d", path)
    |> ignore
  }
  let stick = (name : String, ref_y : Double, path : String) => {
    svg
    .append("defs")
    .append("marker")
    .attr("id", "\{id}-\{name}")
    .attr_number("refX", 7.5)
    .attr_number("refY", ref_y)
    .attr("markerUnits", "userSpaceOnUse")
    .attr_number("markerWidth", 12.0)
    .attr_number("markerHeight", 12.0)
    .attr("orient", "auto-start-reverse")
    .append("path")
    .attr("d", path)
    .attr("stroke", "black")
    .attr_number("stroke-width", 1.5)
    .attr("fill", "none")
    |> ignore
  }
  head("arrowhead", 5.0, "M -1 0 L 10 5 L 0 10 z")
  svg
  .append("defs")
  .append("marker")
  .attr("id", "\{id}-crosshead")
  .attr_number("markerWidth", 15.0)
  .attr_number("markerHeight", 8.0)
  .attr("orient", "auto")
  .attr_number("refX", 4.0)
  .attr_number("refY", 4.5)
  .append("path")
  .attr("fill", "none")
  .attr("stroke", "#000000")
  .style("stroke-dasharray", "0, 0")
  .attr("stroke-width", "1pt")
  .attr("d", "M 1,2 L 6,7 M 6,2 L 1,7")
  |> ignore
  svg
  .append("defs")
  .append("marker")
  .attr("id", "\{id}-filled-head")
  .attr_number("refX", 15.5)
  .attr_number("refY", 7.0)
  .attr_number("markerWidth", 20.0)
  .attr_number("markerHeight", 28.0)
  .attr("orient", "auto")
  .append("path")
  .attr("d", "M 18,7 L9,13 L14,7 L9,1 Z")
  |> ignore
  svg
  .append("defs")
  .append("marker")
  .attr("id", "\{id}-sequencenumber")
  .attr_number("refX", 15.0)
  .attr_number("refY", 15.0)
  .attr_number("markerWidth", 60.0)
  .attr_number("markerHeight", 40.0)
  .attr("orient", "auto")
  .append("circle")
  .attr_number("cx", 15.0)
  .attr_number("cy", 15.0)
  .attr_number("r", 6.0)
  |> ignore
  head("solidTopArrowHead", 7.25, "M 0 0 L 10 8 L 0 8 z")
  head("solidBottomArrowHead", 0.75, "M 0 0 L 10 0 L 0 8 z")
  stick("stickTopArrowHead", 7.0, "M 0 0 L 7 7")
  stick("stickBottomArrowHead", 0.0, "M 0 7 L 7 0")
  if self.conf.is_neo() {
    svg
    .append("defs")
    .append("filter")
    .attr("id", "\{id}-drop-shadow")
    .attr("height", "130%")
    .attr("width", "130%")
    .append("feDropShadow")
    .attr("dx", "4")
    .attr("dy", "4")
    .attr_number("stdDeviation", 0.0)
    .attr("flood-opacity", "0.06")
    .attr(
      "flood-color",
      if self.conf.theme is ("redux" | "redux-color") {
        "#000000"
      } else {
        "#FFFFFF"
      },
    )
    |> ignore
  }
}

///|
/// The bar of an activation that just ended (`drawActivation`), drawn
/// into the group reserved when it began.
fn Renderer::draw_activation(
  self : Renderer,
  activation : Activation,
  vertical_pos : Double,
  stacked : Int32,
) -> Unit {
  guard activation.anchored is Some(group) else { return }
  let nan = @double.not_a_number
  let startx = activation.startx.unwrap_or(nan)
  let starty = activation.starty.unwrap_or(nan)
  let rect = RectSpec::new()
  rect.x = startx
  rect.y = starty
  rect.class_name = Some("activation\{stacked % 3}")
  rect.width = activation.stopx.unwrap_or(nan) - startx
  rect.height = vertical_pos - starty
  let element = self.draw_rect(group, rect)
  if self.conf.is_color_theme() {
    let fallback_fill = match self.theme.get("mainBkg") {
      String(color) => Some(color)
      _ => None
    }
    self.paint(element, activation.actor, fallback_fill?)
  }
}

///|
/// A block's frame, label and titles (`drawLoop`).
fn Renderer::draw_loop(
  self : Renderer,
  model : LoopModel,
  label : String,
  msg : Message,
) -> Unit raise SequenceError {
  let n = @dom.number
  let conf = self.conf
  let nan = @double.not_a_number
  let startx = model.startx.unwrap_or(nan)
  let starty = model.starty.unwrap_or(nan)
  let stopx = model.stopx.unwrap_or(nan)
  let group = self.svg
    .append("g")
    .attr("data-et", "control-structure")
    .attr("data-id", "i\{msg.id}")
  // An edge nothing ever grew is undefined, and an undefined attribute
  // is not set at all.
  let draw_line = (x1 : Double?, y1 : Double?, x2 : Double?, y2 : Double?) => {
    let line = group.append("line")
    for name, value in { "x1": x1, "y1": y1, "x2": x2, "y2": y2 } {
      if value is Some(value) {
        line.attr_number(name, value) |> ignore
      }
    }
    line.attr("class", "loopLine")
  }
  draw_line(model.startx, model.starty, model.stopx, model.starty) |> ignore
  draw_line(model.stopx, model.starty, model.stopx, model.stopy) |> ignore
  draw_line(model.startx, model.stopy, model.stopx, model.stopy) |> ignore
  draw_line(model.startx, model.starty, model.startx, model.stopy) |> ignore
  for section in model.sections {
    draw_line(model.startx, Some(section.y), model.stopx, Some(section.y)).style(
      "stroke-dasharray", "3, 3",
    )
    |> ignore
  }
  // The label in its box with a cut corner (`drawLabel`).
  let font = conf.message_font
  let txt = TextData::new(font, width=100.0)
  txt.text = label
  txt.x = startx
  txt.y = starty
  txt.anchor = Some("middle")
  txt.valign = Some("middle")
  txt.tspan = false
  txt.width = Some(get_max_strict([conf.label_box_width, 50.0]))
  txt.height = match
    conf.label_box_height + (if conf.is_neo() { 15.0 } else { 0.0 }) {
    0.0 => 20.0
    height => height
  }
  txt.text_margin = conf.box_text_margin
  txt.class_name = Some("labelText")
  let width = txt.width.unwrap_or(nan)
  let cut = 7.0
  // Written into the point list as JavaScript prints them.
  let or_undefined = (value : Double?) => {
    match value {
      Some(value) => n(value)
      None => "undefined"
    }
  }
  let left = or_undefined(model.startx)
  let top = or_undefined(model.starty)
  group
  .append("polygon")
  .attr(
    "points",
    "\{left},\{top} \{n(txt.x + width)},\{top} \{n(txt.x + width)},\{n(txt.y + txt.height - cut)} \{n(txt.x + width - cut * 1.2)},\{n(txt.y + txt.height)} \{left},\{n(txt.y + txt.height)}",
  )
  .attr("class", "labelBox")
  |> ignore
  txt.y = txt.y + txt.height / 2.0
  self.draw_text(group, txt) |> ignore
  // The title beside it.
  let txt = TextData::new(font)
  txt.text = match model.title {
    Some(title) => title
    None =>
      raise SequenceError(
        "Cannot read properties of undefined (reading 'match')",
      )
  }
  reject_katex(txt.text)
  txt.x = startx + conf.label_box_width / 2.0 + (stopx - startx) / 2.0
  txt.y = starty + conf.box_margin + conf.box_text_margin
  txt.anchor = Some("middle")
  txt.valign = Some("middle")
  txt.text_margin = conf.box_text_margin
  txt.class_name = Some("loopText")
  self.draw_text(group, txt) |> ignore
  for index, item in model.section_titles {
    guard item.message != "" else { continue }
    reject_katex(item.message)
    txt.text = item.message
    txt.x = startx + (stopx - startx) / 2.0
    txt.y = model.sections[index].y + conf.box_margin + conf.box_text_margin
    txt.class_name = Some("sectionTitle")
    txt.anchor = Some("middle")
    txt.valign = Some("middle")
    txt.tspan = false
    self.draw_text(group, txt) |> ignore
  }
}

///|
/// A participant box: its background, and its title when it has one
/// (`drawBox`).
fn Renderer::draw_box(self : Renderer, box : Box) -> Unit raise SequenceError {
  let conf = self.conf
  let group = self.svg.append("g")
  let padding = conf.box_margin * 2.0
  let startx = box.x - padding
  let starty = box.y - padding * 0.25
  let stopx = startx + box.width + 2.0 * padding
  let stopy = starty + box.height + padding * 0.75
  draw_background_rect(
    group,
    Some(startx),
    Some(starty),
    Some(stopx),
    Some(stopy),
    Some(box.fill),
    Some("rgb(0,0,0, 0.5)"),
  )
  if box.name is Some(name) && name != "" {
    self.draw_actor_text(
      name,
      group,
      box.x,
      box.y + conf.box_text_margin + or_default(box.text_max_height, 0.0) / 2.0,
      box.width,
      0.0,
      "text",
    )
  }
  lower(group)
}

///|
/// The widest label of a participant's popup menu, with its padding
/// (`getRequiredPopupWidth`).
fn Renderer::required_popup_width(
  self : Renderer,
  actor : Actor,
) -> Double raise SequenceError {
  let conf = self.conf
  let mut required = 0.0
  for key in js_keys(actor.links) {
    let label_width = text_dimensions(key, conf.actor_font).width +
      2.0 * conf.wrap_padding +
      2.0 * conf.box_margin
    if required < label_width {
      required = label_width
    }
  }
  required
}

///|
/// The popup menu of a participant's links, hidden until the participant
/// is clicked (`drawPopup`). Returns the menu's height and width.
fn Renderer::draw_popup(
  self : Renderer,
  actor : Actor,
  min_menu_width : Double,
) -> (Double, Double) raise SequenceError {
  if actor.links.is_empty() {
    return (0.0, 0.0)
  }
  // Only boxed participants keep the rectangle the menu hangs from.
  guard actor.rect_data is Some(rect) else {
    raise SequenceError("Cannot read properties of null (reading 'class')")
  }
  let conf = self.conf
  let actor_cnt = match actor.actor_cnt {
    Some(count) => count.to_string()
    None => "null"
  }
  let group = self.svg.append("g")
  group
  .attr("id", "actor\{actor_cnt}_popup")
  .attr("class", "actorPopupMenu")
  .attr("display", if conf.force_menus { "block !important" } else { "none" })
  |> ignore
  let actor_class = match rect.class_name {
    Some(class_name) => " " + class_name
    None => ""
  }
  let menu_width = if rect.width > min_menu_width {
    rect.width
  } else {
    min_menu_width
  }
  let panel = group.append("rect")
  panel
  .attr("class", "actorPopupMenuPanel" + actor_class)
  .attr_number("x", rect.x)
  .attr_number("y", rect.height)
  .attr("fill", rect.fill)
  .attr("stroke", rect.stroke)
  .attr_number("width", menu_width)
  .attr_number("height", rect.height)
  .attr_number("rx", rect.rx)
  .attr_number("ry", rect.ry)
  |> ignore
  let font = conf.actor_font
  let mut link_y = 20.0
  for key in js_keys(actor.links) {
    let link = group.append("a")
    let target = match actor.links[key] {
      String(url) => sanitize_url(url)
      value =>
        if truthy(value) {
          raise SequenceError("url.trim is not a function")
        } else {
          BLANK_URL
        }
    }
    // The output sanitizer only lets web, mail and phone addresses and
    // relative ones through; a blanked link ends up without target.
    if @dom.is_allowed_uri(target) {
      link.attr("xlink:href", target) |> ignore
    }
    // The menu item (`_drawMenuItemTextCandidateFunc`): the font size is
    // used as configured here, a bare number included.
    let x = rect.x + 10.0
    let y = rect.height + link_y
    let lines = split_breaks(key)
    // The size as JavaScript coerces it in arithmetic, and as the style
    // takes it: a bare number is pixels there, an SVG quirk.
    let (size, css_size) = match font.size {
      Number(size, ..) => (size, @dom.number(size) + "px")
      String(text) => {
        let number = @string.parse_double(js_trim(text)) catch {
          _ => @double.not_a_number
        }
        if number == number {
          (number, @dom.number(number) + "px")
        } else {
          (number, @dom.number(css_pixels(Some(text))) + "px")
        }
      }
      _ => raise SequenceError("Unsupported font size in a popup menu")
    }
    for i, line in lines {
      let dy = i.to_double() * size -
        size * (lines.length().to_double() - 1.0) / 2.0
      let text = link
        .append("text")
        .attr_number("x", x)
        .attr_number("y", y)
        .style("text-anchor", "start")
      text.style("font-size", css_size) |> ignore
      if serialize_font_weight(font.weight) is Some(weight) {
        text.style("font-weight", weight) |> ignore
      }
      if font.family.bind(serialize_font_family) is Some(family) {
        text.style("font-family", family) |> ignore
      }
      text.append("tspan").attr_number("x", x).attr_number("dy", dy).text(line)
      |> ignore
      text
      .attr_number("y", y + 20.0 / 2.0)
      .attr("dominant-baseline", "central")
      .attr("alignment-baseline", "central")
      .attr("class", "actor")
      |> ignore
    }
    link_y += 30.0
  }
  panel.attr_number("height", link_y) |> ignore
  (rect.height + link_y, menu_width)
}
