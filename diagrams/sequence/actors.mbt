// The eight ways a participant is drawn (svgDraw.js). Each draws the top
// instance with its lifeline, or the mirrored one at the foot.

///|
const ACTOR_TYPE_WIDTH : Double = 36.0

///|
const ACTOR_GLYPH_TOP : Double = -5.0

///|
const ACTOR_GLYPH_BOTTOM : Double = 60.0

///|
const ACTOR_GLYPH_HEIGHT : Double = ACTOR_GLYPH_BOTTOM - ACTOR_GLYPH_TOP

///|
/// Where the parts of a figure participant go in the neo look: the figure
/// above its label at the top, the other way round at the foot.
priv struct Bands {
  lifeline_start_y : Double
  glyph_bottom_y : Double
  label_center_y : Double
}

///|
fn Renderer::neo_bands(
  self : Renderer,
  actor : Actor,
  is_footer : Bool,
  actor_y : Double,
) -> Bands? raise SequenceError {
  guard self.conf.is_neo() else { return None }
  let text_height = match actor.text_height {
    Some(height) => height
    None => text_dimensions(actor.description, self.conf.actor_font).height
  }
  if is_footer {
    let glyph_top_y = actor_y + LABEL_LIFELINE_GAP
    let glyph_bottom_y = glyph_top_y + GLYPH_BAND_HEIGHT
    Some({
      lifeline_start_y: @double.not_a_number,
      glyph_bottom_y,
      label_center_y: glyph_bottom_y + GLYPH_LABEL_GAP + text_height / 2.0,
    })
  } else {
    let lifeline_start_y = actor_y + actor.height
    Some({
      lifeline_start_y,
      glyph_bottom_y: lifeline_start_y -
      LABEL_LIFELINE_GAP -
      text_height -
      GLYPH_LABEL_GAP,
      label_center_y: lifeline_start_y - LABEL_LIFELINE_GAP - text_height / 2.0,
    })
  }
}

///|
fn Renderer::drop_shadow(self : Renderer) -> String {
  "url(#\{self.id}-drop-shadow)"
}

///|
/// Color an element from the theme's palettes when the theme has them:
/// the participant's place in the diagram picks the color.
fn Renderer::paint(
  self : Renderer,
  element : @dom.Element,
  actor_name : String?,
  fallback_fill? : String,
) -> Unit {
  let index = match actor_name {
    Some(name) => self.actor_index.get(name).unwrap_or(0)
    None => 0
  }
  let pick = (palette : String) => {
    match self.theme.get(palette) {
      Array(colors) if colors.length() > 0 =>
        match colors[index % colors.length()] {
          String(color) => Some(color)
          _ => None
        }
      _ => None
    }
  }
  if pick("borderColorArray") is Some(color) {
    element.style("stroke", color) |> ignore
  }
  match (pick("bkgColorArray"), fallback_fill) {
    (Some(color), _) | (None, Some(color)) =>
      element.style("fill", color) |> ignore
    _ => ()
  }
}

///|
/// A theme color as a style value; an unset variable sets nothing.
fn Renderer::style_from_theme(
  self : Renderer,
  element : @dom.Element,
  property : String,
  variable : String,
) -> Unit {
  if self.theme.get(variable) is String(color) {
    element.style(property, color) |> ignore
  }
}

///|
/// The lifeline of a participant, drawn far down and cut to length once
/// the diagram's height is known.
fn Renderer::draw_lifeline(
  self : Renderer,
  parent : @dom.Element,
  actor : Actor,
  center : Double,
  center_y : Double,
) -> Unit {
  let line = parent
    .append("line")
    .attr("id", "actor\{self.actor_cnt}")
    .attr_number("x1", center)
    .attr_number("y1", center_y)
    .attr_number("x2", center)
    .attr_number("y2", 2000.0)
    .attr("class", "actor-line 200")
    .attr("stroke-width", "0.5px")
    .attr("stroke", "#999")
  set_name(line, actor.name)
  line.attr("data-et", "life-line").attr("data-id", actor.name) |> ignore
}

///|
fn mark_participant(
  element : @dom.Element,
  kind : String,
  actor : Actor,
) -> Unit {
  element
  .attr("data-et", "participant")
  .attr("data-type", kind)
  .attr("data-id", actor.name)
  |> ignore
}

///|
/// A participant's label (`_drawTextCandidateFunc`): one `<text>` per
/// line, centered in the given rectangle.
fn Renderer::draw_actor_text(
  self : Renderer,
  content : String,
  parent : @dom.Element,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  class_name : String,
) -> Unit raise SequenceError {
  let font = self.conf.actor_font
  match self.conf.text_placement {
    "fo" =>
      raise SequenceError(
        "Unsupported: sequence.textPlacement 'fo' (HTML participant labels)",
      )
    "old" => {
      parent
      .append("text")
      .attr_number("x", x + width / 2.0)
      .attr_number("y", y + height / 2.0 + 5.0)
      .style("text-anchor", "middle")
      .text(content)
      .attr("class", class_name)
      |> ignore
      return
    }
    _ => ()
  }
  let (font_size, _) = parse_font_size(font.size)
  let font_size = font_size.unwrap_or(@double.not_a_number)
  let lines = split_breaks(content)
  let count = lines.length().to_double()
  for i, line in lines {
    let dy = i.to_double() * font_size - font_size * (count - 1.0) / 2.0
    let text = parent
      .append("text")
      .attr_number("x", x + width / 2.0)
      .attr_number("y", y)
      .style("text-anchor", "middle")
    style_font(text, font, ["font-size", "font-weight", "font-family"])
    text
    .append("tspan")
    .attr_number("x", x + width / 2.0)
    .attr_number("dy", dy)
    .text(line)
    |> ignore
    text
    .attr_number("y", y + height / 2.0)
    .attr("dominant-baseline", "central")
    .attr("alignment-baseline", "central")
    .attr("class", class_name)
    |> ignore
  }
}

///|
/// The group a boxed participant is drawn into. At the top it also holds
/// the lifeline, and the group is numbered for the popup menu.
fn Renderer::boxed_group(
  self : Renderer,
  actor : Actor,
  is_footer : Bool,
  center : Double,
  center_y : Double,
) -> @dom.Element {
  let outer = self.svg.insert_first("g")
  guard !is_footer else { return outer }
  self.actor_cnt += 1
  // A participant with links also gets a click handler and a pointer
  // cursor here; the sanitizer removes both attributes.
  self.draw_lifeline(outer, actor, center, center_y)
  let group = outer.append("g")
  actor.actor_cnt = Some(self.actor_cnt)
  group.attr("id", "root-\{self.actor_cnt}") |> ignore
  if self.conf.is_neo() {
    group.attr("data-look", "neo") |> ignore
  }
  group
}

///|
/// The rectangle of a boxed participant, before it is drawn.
fn actor_rect(actor : Actor, actor_y : Double, is_footer : Bool) -> RectSpec {
  let rect = RectSpec::new()
  let mut class_name = "actor"
  match actor.properties.get("class") {
    Some(String(custom)) if custom != "" => class_name = custom
    _ => rect.fill = Some("#eaeaea")
  }
  class_name += if is_footer { " actor-bottom" } else { " actor-top" }
  rect.x = actor.x
  rect.y = actor_y
  rect.width = actor.width
  rect.height = actor.height
  rect.class_name = Some(class_name)
  rect.name = Some(actor.name)
  rect
}

///|
/// The icon a participant's `properties` ask for, in the corner of its
/// box. `@name` refers to one of the symbols every diagram defines, but
/// the `<use>` element that would show it does not survive the output
/// sanitizer; anything else is the address of an image.
fn draw_icon(
  group : @dom.Element,
  rect : RectSpec,
  actor : Actor,
) -> Unit raise SequenceError {
  guard actor.properties.get("icon") is Some(icon) && truthy(icon) else {
    return
  }
  guard icon is String(icon) else {
    raise SequenceError("actor.properties.icon.trim is not a function")
  }
  let source = js_trim(icon)
  if source.has_prefix("@") {
    return
  }
  let image = group
    .append("image")
    .attr_number("x", rect.x + rect.width - 20.0)
    .attr_number("y", rect.y + 10.0)
  let link = sanitize_url(source)
  if @dom.is_allowed_uri(link) {
    image.attr("xlink:href", link) |> ignore
  }
}

///|
fn Renderer::draw_participant(
  self : Renderer,
  actor : Actor,
  is_footer : Bool,
) -> Double raise SequenceError {
  let conf = self.conf
  let actor_y = if is_footer { actor.stopy } else { actor.starty }
  let center = actor.x + actor.width / 2.0
  let center_y = actor_y + actor.height
  let group = self.boxed_group(actor, is_footer, center, center_y)
  let rect = actor_rect(actor, actor_y, is_footer)
  rect.rx = 3.0
  rect.ry = 3.0
  if conf.is_neo() {
    rect.rx = 6.0
    rect.ry = 6.0
  }
  let rect_element = self.draw_rect(group, rect)
  if conf.is_color_theme() {
    self.paint(rect_element, Some(actor.name))
  }
  if conf.is_neo() {
    rect_element.attr("filter", self.drop_shadow()) |> ignore
  }
  actor.rect_data = Some(rect.data())
  draw_icon(group, rect, actor)
  if !is_footer {
    mark_participant(group, "participant", actor)
  }
  self.draw_actor_text(
    actor.description,
    group,
    rect.x,
    rect.y,
    rect.width,
    rect.height,
    "actor actor-box",
  )
  let mut height = actor.height
  if !conf.is_neo() {
    actor.height = rect_element.bbox().height
    height = actor.height
  }
  height
}

///|
fn Renderer::draw_collections(
  self : Renderer,
  actor : Actor,
  is_footer : Bool,
) -> Double raise SequenceError {
  let conf = self.conf
  let actor_y = if is_footer { actor.stopy } else { actor.starty }
  let center = actor.x + actor.width / 2.0
  let center_y = actor_y + actor.height
  let group = self.boxed_group(actor, is_footer, center, center_y)
  let rect = actor_rect(actor, actor_y, is_footer)
  let offset = 6.0
  if conf.is_neo() {
    rect.height = actor.height - offset
  }
  let rect_element = self.draw_rect(group, rect)
  // A second sheet, shifted, makes the stack.
  let shadow : RectSpec = {
    ..rect,
    x: rect.x - offset,
    y: rect.y + offset,
    class_name: Some("actor"),
  }
  let stacked = self.draw_rect(group, shadow)
  actor.rect_data = Some(rect.data())
  if conf.is_neo() {
    group.attr("filter", self.drop_shadow()) |> ignore
  }
  if conf.is_color_theme() {
    self.paint(rect_element, Some(actor.name))
    self.paint(stacked, Some(actor.name))
  }
  draw_icon(group, rect, actor)
  self.draw_actor_text(
    actor.description,
    group,
    rect.x - offset,
    rect.y + offset,
    rect.width,
    rect.height,
    "actor actor-box",
  )
  let mut height = actor.height
  if !conf.is_neo() {
    actor.height = rect_element.bbox().height
    height = actor.height
  }
  if !is_footer {
    mark_participant(group, "collections", actor)
  }
  height
}

///|
fn Renderer::draw_queue(
  self : Renderer,
  actor : Actor,
  is_footer : Bool,
) -> Double raise SequenceError {
  let n = @dom.number
  let conf = self.conf
  let actor_y = if is_footer { actor.stopy } else { actor.starty }
  let center = actor.x + actor.width / 2.0
  let center_y = actor_y + actor.height
  let group = self.boxed_group(actor, is_footer, center, center_y)
  let rect = actor_rect(actor, actor_y, is_footer)
  // The class goes on the group; the rectangle itself is never drawn.
  group.attr("class", rect.class_name.unwrap_or("")) |> ignore
  rect.class_name = None
  let ry = rect.height / 2.0
  let rx = ry / (2.5 + rect.height / 50.0)
  let cylinder = group.append("g")
  let arc = group.append("g")
  let path = cylinder
    .append("path")
    .attr(
      "d",
      "M \{n(rect.x)},\{n(rect.y + ry)}\n    a \{n(rx)},\{n(ry)} 0 0 0 0,\{n(rect.height)}\n    h \{n(rect.width - 2.0 * rx)}\n    a \{n(rx)},\{n(ry)} 0 0 0 0,-\{n(rect.height)}\n    Z\n  ",
    )
  arc
  .append("path")
  .attr(
    "d",
    "M \{n(rect.x)},\{n(rect.y + ry)}\n      a \{n(rx)},\{n(ry)} 0 0 0 0,\{n(rect.height)}",
  )
  |> ignore
  cylinder.attr("transform", "translate(\{n(rx)}, \{n(-(rect.height / 2.0))})")
  |> ignore
  arc.attr(
    "transform",
    "translate(\{n(rect.width - rx)}, \{n(-rect.height / 2.0)})",
  )
  |> ignore
  actor.rect_data = Some(rect.data())
  if conf.is_neo() {
    cylinder.attr("filter", self.drop_shadow()) |> ignore
  }
  if conf.is_color_theme() {
    self.paint(cylinder, Some(actor.name))
    self.paint(arc, Some(actor.name))
  }
  draw_icon(group, rect, actor)
  self.draw_actor_text(
    actor.description,
    group,
    rect.x,
    rect.y,
    rect.width,
    rect.height,
    "actor actor-box",
  )
  let mut height = actor.height
  if !conf.is_neo() {
    actor.height = path.bbox().height
    height = actor.height
  }
  if !is_footer {
    mark_participant(group, "queue", actor)
  }
  height
}

///|
/// The group a figure participant is drawn into, after its lifeline went
/// into a group of its own behind everything.
fn Renderer::figure_group(
  self : Renderer,
  actor : Actor,
  is_footer : Bool,
  class_name : String,
) -> @dom.Element {
  let group = self.svg.append("g")
  group.attr(
    "class",
    class_name + (if is_footer { " actor-bottom" } else { " actor-top" }),
  )
  |> ignore
  set_name(group, actor.name)
  group
}

///|
fn Renderer::draw_control(
  self : Renderer,
  actor : Actor,
  is_footer : Bool,
) -> Double raise SequenceError {
  let n = @dom.number
  let conf = self.conf
  let actor_y = if is_footer { actor.stopy } else { actor.starty }
  let center = actor.x + actor.width / 2.0
  let bands = self.neo_bands(actor, is_footer, actor_y)
  let center_y = match bands {
    Some(bands) => bands.lifeline_start_y
    None => actor_y + 75.0
  }
  let line = self.svg.insert_first("g")
  if !is_footer {
    self.actor_cnt += 1
    self.draw_lifeline(line, actor, center, center_y)
    actor.actor_cnt = Some(self.actor_cnt)
  }
  let group = self.figure_group(actor, is_footer, "actor-man")
  // The label is laid out in the rectangle as it was before the figure
  // was measured.
  let rect_height = actor.height
  let cx = actor.x + actor.width / 2.0
  let cy = match bands {
    Some(bands) => bands.glyph_bottom_y - 22.0
    None => actor_y + 32.0
  }
  let r = 22.0
  group
  .append("defs")
  .append("marker")
  .attr("id", self.id + "-filled-head-control")
  .attr_number("refX", 11.0)
  .attr_number("refY", 5.8)
  .attr_number("markerWidth", 20.0)
  .attr_number("markerHeight", 28.0)
  .attr("orient", "172.5")
  .attr_number("stroke-width", 1.2)
  .append("path")
  .attr("d", "M 14.4 5.6 L 7.2 10.4 L 8.8 5.6 L 7.2 0.8 Z")
  |> ignore
  group
  .append("circle")
  .attr_number("cx", cx)
  .attr_number("cy", cy)
  .attr_number("r", r)
  .attr("filter", if conf.is_neo() { self.drop_shadow() } else { "" })
  |> ignore
  group
  .append("line")
  .attr("marker-end", "url(#\{self.id}-filled-head-control)")
  .attr("transform", "translate(\{n(cx)}, \{n(cy - r)})")
  |> ignore
  if conf.is_color_theme() {
    self.paint(group, Some(actor.name))
  } else {
    self.style_from_theme(group, "stroke", "actorBorder")
    self.style_from_theme(group, "fill", "actorBkg")
  }
  if bands is None {
    actor.height = group.bbox().height + 2.0 * conf.label_box_height
  }
  self.draw_actor_text(
    actor.description,
    group,
    actor.x,
    match bands {
      Some(bands) => bands.label_center_y - rect_height / 2.0
      None => actor_y + r + (if is_footer { 5.0 } else { 12.0 })
    },
    actor.width,
    rect_height,
    "actor actor-man",
  )
  if !is_footer {
    mark_participant(group, "control", actor)
  }
  actor.height
}

///|
fn Renderer::draw_entity(
  self : Renderer,
  actor : Actor,
  is_footer : Bool,
) -> Double raise SequenceError {
  let n = @dom.number
  let conf = self.conf
  let actor_y = if is_footer { actor.stopy } else { actor.starty }
  let center = actor.x + actor.width / 2.0
  let bands = self.neo_bands(actor, is_footer, actor_y)
  let center_y = match bands {
    Some(bands) => bands.lifeline_start_y
    None => actor_y + 75.0
  }
  let line = self.svg.insert_first("g")
  let group = self.figure_group(actor, is_footer, "actor")
  // The label is laid out in the rectangle as it was before the figure
  // was measured.
  let rect_height = actor.height
  let cx = actor.x + actor.width / 2.0
  let cy = match bands {
    Some(bands) => bands.glyph_bottom_y - 22.0
    None => actor_y + (if is_footer { 10.0 } else { 25.0 })
  }
  let r = 22.0
  group
  .append("circle")
  .attr_number("cx", cx)
  .attr_number("cy", cy)
  .attr_number("r", r)
  .attr_number("width", actor.width)
  .attr_number("height", actor.height)
  |> ignore
  group
  .append("line")
  .attr_number("x1", cx - r)
  .attr_number("x2", cx + r)
  .attr_number("y1", cy + r)
  .attr_number("y2", cy + r)
  .attr_number("stroke-width", 2.0)
  |> ignore
  if conf.is_neo() {
    group.attr("filter", self.drop_shadow()) |> ignore
  }
  if conf.is_color_theme() {
    self.paint(group, Some(actor.name))
  }
  if bands is None {
    actor.height = group.bbox().height + conf.label_box_height
  }
  if !is_footer {
    self.actor_cnt += 1
    self.draw_lifeline(line, actor, center, center_y)
    actor.actor_cnt = Some(self.actor_cnt)
  }
  self.draw_actor_text(
    actor.description,
    group,
    actor.x,
    match bands {
      Some(bands) => bands.label_center_y - rect_height / 2.0
      None => actor_y + (if is_footer { 15.0 } else { 30.0 })
    },
    actor.width,
    rect_height,
    "actor actor-man",
  )
  if bands is None {
    group.attr(
      "transform",
      "translate(0, \{n(if is_footer { r } else { r / 2.0 - 5.0 })})",
    )
    |> ignore
  }
  if !is_footer {
    mark_participant(group, "entity", actor)
  }
  actor.height
}

///|
fn Renderer::draw_database(
  self : Renderer,
  actor : Actor,
  is_footer : Bool,
) -> Double raise SequenceError {
  let n = @dom.number
  let conf = self.conf
  let actor_y = if is_footer { actor.stopy } else { actor.starty }
  let center = actor.x + actor.width / 2.0
  let bands = self.neo_bands(actor, is_footer, actor_y)
  let center_y = match bands {
    Some(bands) => bands.lifeline_start_y
    None => actor_y + actor.height + 2.0 * conf.box_text_margin
  }
  let group = self.boxed_group(actor, is_footer, center, center_y)
  let rect = actor_rect(actor, actor_y, is_footer)
  let w = rect.width / 3.0
  let rx = w / 2.0
  let ry = rx / (2.5 + w / 50.0)
  let h = if bands is Some(_) { GLYPH_BAND_HEIGHT } else { rect.width / 3.0 }
  let cylinder_y = match bands {
    Some(bands) => bands.glyph_bottom_y - h - ry
    None => rect.y
  }
  let cylinder = group.append("g")
  cylinder.attr("class", rect.class_name.unwrap_or("")) |> ignore
  let path = cylinder
    .append("path")
    .attr(
      "d",
      "\n  M \{n(rect.x)},\{n(cylinder_y + ry)}\n  a \{n(rx)},\{n(ry)} 0 0 0 \{n(w)},0\n  a \{n(rx)},\{n(ry)} 0 0 0 -\{n(w)},0\n  l 0,\{n(h - 2.0 * ry)}\n  a \{n(rx)},\{n(ry)} 0 0 0 \{n(w)},0\n  l 0,-\{n(h - 2.0 * ry)}\n",
    )
  if conf.is_neo() {
    cylinder.attr("filter", self.drop_shadow()) |> ignore
  }
  if conf.is_color_theme() {
    self.paint(cylinder, Some(actor.name))
  } else {
    self.style_from_theme(cylinder, "stroke", "actorBorder")
  }
  cylinder.attr("transform", "translate(\{n(w)}, \{n(ry)})") |> ignore
  actor.rect_data = Some(rect.data())
  self.draw_actor_text(
    actor.description,
    group,
    rect.x,
    match bands {
      Some(bands) => bands.label_center_y - rect.height / 2.0
      None => rect.y + 35.0
    },
    rect.width,
    rect.height,
    "actor actor-box",
  )
  if bands is None {
    actor.height = path.bbox().height + conf.label_box_height
  }
  if !is_footer {
    mark_participant(group, "database", actor)
  }
  actor.height
}

///|
fn Renderer::draw_boundary(
  self : Renderer,
  actor : Actor,
  is_footer : Bool,
) -> Double raise SequenceError {
  let n = @dom.number
  let conf = self.conf
  let actor_y = if is_footer { actor.stopy } else { actor.starty }
  let center = actor.x + actor.width / 2.0
  let bands = self.neo_bands(actor, is_footer, actor_y)
  let center_y = match bands {
    Some(bands) => bands.lifeline_start_y
    None => actor_y + 80.0
  }
  let radius = 22.0
  let icon_center_y = match bands {
    Some(bands) => bands.glyph_bottom_y - radius
    None => actor_y + 12.0
  }
  let line = self.svg.insert_first("g")
  if !is_footer {
    self.actor_cnt += 1
    self.draw_lifeline(line, actor, center, center_y)
    actor.actor_cnt = Some(self.actor_cnt)
  }
  let group = self.figure_group(actor, is_footer, "actor-man")
  let rect_height = actor.height
  group
  .append("line")
  .attr("id", "actor-man-torso\{self.actor_cnt}")
  .attr_number("x1", actor.x + actor.width / 2.0 - radius * 2.5)
  .attr_number("y1", icon_center_y)
  .attr_number("x2", actor.x + actor.width / 2.0 - 15.0)
  .attr_number("y2", icon_center_y)
  |> ignore
  group
  .append("line")
  .attr("id", "actor-man-arms\{self.actor_cnt}")
  .attr_number("x1", actor.x + actor.width / 2.0 - radius * 2.5)
  .attr_number("y1", icon_center_y - 10.0)
  .attr_number("x2", actor.x + actor.width / 2.0 - radius * 2.5)
  .attr_number("y2", icon_center_y + 10.0)
  |> ignore
  group
  .append("circle")
  .attr_number("cx", actor.x + actor.width / 2.0)
  .attr_number("cy", icon_center_y)
  .attr_number("r", radius)
  |> ignore
  if conf.is_neo() {
    group.attr("filter", self.drop_shadow()) |> ignore
  }
  if conf.is_color_theme() {
    self.paint(group, Some(actor.name))
  } else {
    self.style_from_theme(group, "stroke", "actorBorder")
  }
  if bands is None {
    actor.height = group.bbox().height + conf.label_box_height
  }
  self.draw_actor_text(
    actor.description,
    group,
    actor.x,
    match bands {
      Some(bands) => bands.label_center_y - rect_height / 2.0
      None => actor_y + 15.0
    },
    actor.width,
    rect_height,
    "actor actor-man",
  )
  if bands is None {
    group.attr("transform", "translate(0,\{n(radius / 2.0 + 10.0)})") |> ignore
  }
  if !is_footer {
    mark_participant(group, "boundary", actor)
  }
  actor.height
}

///|
/// The stick figure.
fn Renderer::draw_actor_figure(
  self : Renderer,
  actor : Actor,
  is_footer : Bool,
) -> Double raise SequenceError {
  let conf = self.conf
  let actor_y = if is_footer { actor.stopy } else { actor.starty }
  let center = actor.x + actor.width / 2.0
  let bands = self.neo_bands(actor, is_footer, actor_y)
  let center_y = match bands {
    Some(bands) => bands.lifeline_start_y
    None => actor_y + 80.0
  }
  let line = self.svg.insert_first("g")
  if !is_footer {
    self.actor_cnt += 1
    self.draw_lifeline(line, actor, center, center_y)
    actor.actor_cnt = Some(self.actor_cnt)
  }
  let group = self.figure_group(actor, is_footer, "actor-man")
  if !is_footer {
    mark_participant(group, "actor", actor)
  }
  // In the neo look the figure is scaled into its band.
  let glyph_scale = if bands is Some(_) {
    GLYPH_BAND_HEIGHT / ACTOR_GLYPH_HEIGHT
  } else {
    1.0
  }
  let gy = (offset : Double) => {
    match bands {
      Some(bands) =>
        bands.glyph_bottom_y - (ACTOR_GLYPH_BOTTOM - offset) * glyph_scale
      None => actor_y + offset
    }
  }
  let gx = (offset : Double) => center + offset * glyph_scale
  group
  .append("line")
  .attr("id", "actor-man-torso\{self.actor_cnt}")
  .attr_number("x1", center)
  .attr_number("y1", gy(25.0))
  .attr_number("x2", center)
  .attr_number("y2", gy(45.0))
  |> ignore
  group
  .append("line")
  .attr("id", "actor-man-arms\{self.actor_cnt}")
  .attr_number("x1", gx(-ACTOR_TYPE_WIDTH / 2.0))
  .attr_number("y1", gy(33.0))
  .attr_number("x2", gx(ACTOR_TYPE_WIDTH / 2.0))
  .attr_number("y2", gy(33.0))
  |> ignore
  group
  .append("line")
  .attr_number("x1", gx(-ACTOR_TYPE_WIDTH / 2.0))
  .attr_number("y1", gy(60.0))
  .attr_number("x2", center)
  .attr_number("y2", gy(45.0))
  |> ignore
  group
  .append("line")
  .attr_number("x1", center)
  .attr_number("y1", gy(45.0))
  .attr_number("x2", gx(ACTOR_TYPE_WIDTH / 2.0 - 2.0))
  .attr_number("y2", gy(60.0))
  |> ignore
  group
  .append("circle")
  .attr_number("cx", actor.x + actor.width / 2.0)
  .attr_number("cy", gy(10.0))
  .attr_number("r", 15.0 * glyph_scale)
  .attr_number("width", actor.width)
  .attr_number("height", actor.height)
  |> ignore
  if bands is None {
    actor.height = ACTOR_GLYPH_HEIGHT
  }
  if conf.is_color_theme() {
    self.paint(group, Some(actor.name))
  } else {
    self.style_from_theme(group, "stroke", "actorBorder")
  }
  self.draw_actor_text(
    actor.description,
    group,
    actor.x,
    match bands {
      Some(bands) => bands.label_center_y - actor.height / 2.0
      None => actor_y + 35.0
    },
    actor.width,
    actor.height,
    "actor actor-man",
  )
  actor.height
}

///|
/// Draw one participant, at the top or mirrored at the foot, and return
/// its height (`drawActor`).
fn Renderer::draw_actor(
  self : Renderer,
  actor : Actor,
  is_footer : Bool,
) -> Double raise SequenceError {
  match actor.kind {
    "actor" => self.draw_actor_figure(actor, is_footer)
    "participant" => self.draw_participant(actor, is_footer)
    "boundary" => self.draw_boundary(actor, is_footer)
    "control" => self.draw_control(actor, is_footer)
    "entity" => self.draw_entity(actor, is_footer)
    "database" => self.draw_database(actor, is_footer)
    "collections" => self.draw_collections(actor, is_footer)
    "queue" => self.draw_queue(actor, is_footer)
    // An unknown kind draws nothing and has no height to report.
    _ => @double.not_a_number
  }
}

///|
/// `sanitizeUrl`, with the addresses the port cannot normalize reported as
/// sequence errors.
fn sanitize_url(url : String) -> String raise SequenceError {
  @sanitizeurl.sanitize_url(url) catch {
    @sanitizeurl.Unsupported(message) => raise SequenceError(message)
  }
}
