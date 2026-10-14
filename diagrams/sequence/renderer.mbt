// sequenceRenderer.ts: walk the entries top to bottom, keeping track of
// the vertical position, then draw participants, messages and frames.

///|
/// A note with its text (`drawNote`).
fn Renderer::draw_note(
  self : Renderer,
  note : NoteModel,
  id : Int32,
) -> Unit raise SequenceError {
  let conf = self.conf
  let bounds = self.bounds
  bounds.bump_vertical_pos(conf.box_margin)
  note.starty = bounds.vertical_pos
  let rect = RectSpec::new()
  rect.x = note.startx
  rect.y = note.starty
  rect.width = or_default(note.width, conf.width)
  rect.class_name = Some("note")
  let group = self.svg.append("g")
  group.attr("data-et", "note").attr("data-id", "i\{id}") |> ignore
  let rect_element = self.draw_rect(group, rect)
  let text = TextData::new(conf.note_font, width=100.0)
  text.x = note.startx
  text.y = note.starty
  text.width = Some(rect.width)
  text.dy = Some("1em")
  text.text = note.message
  text.class_name = Some("noteText")
  text.anchor = Some(conf.note_align)
  text.text_margin = conf.note_margin
  text.valign = Some("center")
  let lines = self.draw_text(group, text)
  let text_height = js_round(lines.fold(init=0.0, (sum, line) => sum + line.1))
  rect_element.attr_number("height", text_height + 2.0 * conf.note_margin)
  |> ignore
  bounds.bump_vertical_pos(text_height + 2.0 * conf.note_margin)
  note.stopy = note.starty + text_height + 2.0 * conf.note_margin
  note.stopx = note.startx + rect.width
  bounds.insert(note.startx, note.starty, note.stopx, note.stopy)
}

///|
/// Make room for a message and return the height its line is drawn at
/// (`boundMessage`). The line itself is drawn later, over the activation
/// bars.
fn Renderer::bound_message(
  self : Renderer,
  model : MsgModel,
) -> Double raise SequenceError {
  let conf = self.conf
  let bounds = self.bounds
  bounds.bump_vertical_pos(10.0)
  let lines = split_breaks(model.message).length().to_double()
  reject_katex(model.message)
  let dims = text_dimensions(model.message, conf.message_font)
  let line_height = dims.height / lines
  model.height += line_height
  bounds.bump_vertical_pos(line_height)
  let mut total_offset = dims.height - 10.0
  let line_start_y = if model.startx == model.stopx {
    let mut line_start_y = bounds.vertical_pos + total_offset
    if !conf.right_angles {
      total_offset += conf.box_margin
      line_start_y = bounds.vertical_pos + total_offset
    }
    total_offset += 30.0
    let dx = get_max([dims.width / 2.0, conf.width / 2.0])
    bounds.insert(
      model.startx - dx,
      bounds.vertical_pos - 10.0 + total_offset,
      model.stopx + dx,
      bounds.vertical_pos + 30.0 + total_offset,
    )
    line_start_y
  } else {
    total_offset += conf.box_margin
    let line_start_y = bounds.vertical_pos + total_offset
    bounds.insert(model.startx, line_start_y - 10.0, model.stopx, line_start_y)
    line_start_y
  }
  bounds.bump_vertical_pos(total_offset)
  model.height += total_offset
  model.stopy = model.starty + model.height
  bounds.insert(model.from_bounds, model.starty, model.to_bounds, model.stopy)
  line_start_y
}

///|
/// The circles of a central connection, at the ends the message names
/// (`drawCentralConnection`).
fn Renderer::draw_central_connection(
  self : Renderer,
  msg : Message,
  model : MsgModel,
  line_start_y : Double,
) -> Unit {
  guard self.actor(msg.from) is Some(from) && self.actor(msg.to) is Some(to) else {
    return
  }
  let mut from_center = from.x + from.width / 2.0
  let mut to_center = to.x + to.width / 2.0
  let is_left_to_right = from_center <= to_center
  let is_reverse = is_reverse_arrow(msg.kind)
  let group = self.svg.append("g")
  let circle_offset = (reverse : Bool) => {
    let base = if is_left_to_right { 16.5 } else { -16.5 }
    if reverse {
      -base
    } else {
      base
    }
  }
  let draw_circle = (cx : Double) => {
    group
    .append("circle")
    .attr_number("cx", cx)
    .attr_number("cy", line_start_y)
    .attr_number("r", 5.0)
    .attr_number("width", 10.0)
    .attr_number("height", 10.0)
    |> ignore
  }
  // A sequence number takes the place of a circle next to it.
  if model.sequence_visible {
    match msg.central_connection {
      CENTRAL_CONNECTION => if is_reverse { to_center += circle_offset(true) }
      CENTRAL_CONNECTION_REVERSE =>
        if !is_reverse {
          from_center += circle_offset(false)
        }
      CENTRAL_CONNECTION_DUAL =>
        if is_reverse {
          to_center += circle_offset(true)
        } else {
          from_center += circle_offset(false)
        }
      _ => ()
    }
  }
  match msg.central_connection {
    CENTRAL_CONNECTION => draw_circle(to_center)
    CENTRAL_CONNECTION_REVERSE => draw_circle(from_center)
    CENTRAL_CONNECTION_DUAL => {
      draw_circle(from_center)
      draw_circle(to_center)
    }
    _ => ()
  }
}

///|
/// A sequence number as JavaScript prints it.
fn sequence_label(index : Double) -> String {
  @dom.number(index)
}

///|
/// A message's text, line, arrow heads and number (`drawMessage`).
fn Renderer::draw_message(
  self : Renderer,
  model : MsgModel,
  line_start_y : Double,
  msg : Message,
) -> Unit raise SequenceError {
  let n = @dom.number
  let conf = self.conf
  let svg = self.svg
  let id = self.id
  let startx = model.startx
  let stopx = model.stopx
  let kind = model.kind
  let dims = text_dimensions(model.message, conf.message_font)
  let text = TextData::new(conf.message_font, width=100.0)
  text.x = js_min(startx, stopx)
  text.y = model.starty + 10.0
  text.width = Some((stopx - startx).abs())
  text.class_name = Some("messageText")
  text.dy = Some("1em")
  text.text = model.message
  text.anchor = Some(conf.message_align)
  text.valign = Some("center")
  text.text_margin = conf.wrap_padding
  text.tspan = false
  self.draw_text(svg, text) |> ignore
  let text_width = dims.width
  let shows_number = model.sequence_visible || conf.show_sequence_numbers
  let line = if startx == stopx {
    let line_start_x = startx +
      (if shows_number &&
        (is_reverse_arrow(msg.kind) || is_bidirectional(msg.kind)) {
        10.0
      } else {
        0.0
      })
    let line = if conf.right_angles {
      svg
      .append("path")
      .attr(
        "d",
        "M  \{n(line_start_x)},\{n(line_start_y)} H \{n(startx + get_max([conf.width / 2.0, text_width / 2.0]))} V \{n(line_start_y + 25.0)} H \{n(startx)}",
      )
    } else {
      svg
      .append("path")
      .attr(
        "d",
        "M \{n(line_start_x)},\{n(line_start_y)} C \{n(line_start_x + 60.0)},\{n(line_start_y - 10.0)} \{n(startx + 60.0)},\{n(line_start_y + 30.0)} \{n(startx)},\{n(line_start_y + 20.0)}",
      )
    }
    if has_central_connection(msg.central_connection) {
      self.draw_central_connection(msg, model, line_start_y)
    }
    line
  } else {
    let line = svg.append("line")
    line
    .attr_number("x1", startx)
    .attr_number("y1", line_start_y)
    .attr_number("x2", stopx)
    .attr_number("y2", line_start_y)
    |> ignore
    if has_central_connection(msg.central_connection) {
      self.draw_central_connection(msg, model, line_start_y)
    }
    line
  }
  let dotted = kind
    is (DOTTED
    | DOTTED_CROSS
    | DOTTED_POINT
    | DOTTED_OPEN
    | BIDIRECTIONAL_DOTTED
    | SOLID_TOP_DOTTED
    | SOLID_BOTTOM_DOTTED
    | STICK_TOP_DOTTED
    | STICK_BOTTOM_DOTTED
    | SOLID_ARROW_TOP_REVERSE_DOTTED
    | SOLID_ARROW_BOTTOM_REVERSE_DOTTED
    | STICK_ARROW_TOP_REVERSE_DOTTED
    | STICK_ARROW_BOTTOM_REVERSE_DOTTED)
  if dotted {
    line.style("stroke-dasharray", "3, 3").attr("class", "messageLine1")
    |> ignore
  } else {
    line.attr("class", "messageLine0") |> ignore
  }
  line
  .attr("data-et", "message")
  .attr("data-id", "i\{msg.id}")
  .attr("data-from", msg.from.unwrap_or("undefined"))
  .attr("data-to", msg.to.unwrap_or("undefined"))
  .attr_number("stroke-width", 2.0)
  .attr("stroke", "none")
  .style("fill", "none")
  |> ignore
  let marker = (name : String) => "url(#\{id}-\{name})"
  match kind {
    SOLID_TOP | SOLID_TOP_DOTTED =>
      line.attr("marker-end", marker("solidTopArrowHead")) |> ignore
    SOLID_BOTTOM | SOLID_BOTTOM_DOTTED =>
      line.attr("marker-end", marker("solidBottomArrowHead")) |> ignore
    STICK_TOP | STICK_TOP_DOTTED =>
      line.attr("marker-end", marker("stickTopArrowHead")) |> ignore
    STICK_BOTTOM | STICK_BOTTOM_DOTTED =>
      line.attr("marker-end", marker("stickBottomArrowHead")) |> ignore
    // A head at the sending end is the mirrored one.
    SOLID_ARROW_TOP_REVERSE | SOLID_ARROW_TOP_REVERSE_DOTTED =>
      line.attr("marker-start", marker("solidBottomArrowHead")) |> ignore
    SOLID_ARROW_BOTTOM_REVERSE | SOLID_ARROW_BOTTOM_REVERSE_DOTTED =>
      line.attr("marker-start", marker("solidTopArrowHead")) |> ignore
    STICK_ARROW_TOP_REVERSE | STICK_ARROW_TOP_REVERSE_DOTTED =>
      line.attr("marker-start", marker("stickBottomArrowHead")) |> ignore
    STICK_ARROW_BOTTOM_REVERSE | STICK_ARROW_BOTTOM_REVERSE_DOTTED =>
      line.attr("marker-start", marker("stickTopArrowHead")) |> ignore
    SOLID | DOTTED => line.attr("marker-end", marker("arrowhead")) |> ignore
    BIDIRECTIONAL_SOLID | BIDIRECTIONAL_DOTTED =>
      line
      .attr("marker-start", marker("arrowhead"))
      .attr("marker-end", marker("arrowhead"))
      |> ignore
    SOLID_POINT | DOTTED_POINT =>
      line.attr("marker-end", marker("filled-head")) |> ignore
    SOLID_CROSS | DOTTED_CROSS =>
      line.attr("marker-end", marker("crosshead")) |> ignore
    _ => ()
  }
  guard shows_number else { return }
  // The number sits on the sending lifeline, and the line makes room for
  // its circle.
  let radius = 6.0
  let at_source = msg.central_connection
    is (CENTRAL_CONNECTION_DUAL | CENTRAL_CONNECTION_REVERSE)
  let has_connection = has_central_connection(msg.central_connection)
  let mut line_start_x = startx
  if is_bidirectional(kind) {
    if startx < stopx {
      line_start_x = startx + radius * 2.0
    } else {
      line_start_x = startx - radius + (if has_connection { -5.0 } else { 0.0 })
      line_start_x += if at_source { -7.5 } else { 0.0 }
    }
    line.attr_number("x1", line_start_x) |> ignore
  } else if is_reverse_arrow(kind) {
    let mut line_stop_x = if stopx > startx {
      stopx - 2.0 * radius
    } else {
      line_start_x += if at_source { -7.5 } else { 0.0 }
      stopx - radius
    }
    line_stop_x += if has_connection { 15.0 } else { 0.0 }
    line.attr_number("x2", line_stop_x).attr_number("x1", line_start_x)
    |> ignore
  } else {
    line.attr_number("x1", startx + radius) |> ignore
  }
  let is_left_to_right = startx <= stopx
  let number_x = if startx == stopx {
    model.from_bounds + 1.0
  } else if is_reverse_arrow(kind) {
    if is_left_to_right {
      model.to_bounds - 1.0
    } else {
      model.from_bounds + 1.0
    }
  } else if is_left_to_right {
    model.from_bounds + 1.0
  } else {
    model.to_bounds - 1.0
  }
  let label = sequence_label(model.sequence_index)
  let font_size = if label.length() > 5 {
    "7px"
  } else if label.length() > 3 {
    "9px"
  } else {
    "12px"
  }
  svg
  .append("line")
  .attr_number("x1", number_x)
  .attr_number("y1", line_start_y)
  .attr_number("x2", number_x)
  .attr_number("y2", line_start_y)
  .attr_number("stroke-width", 0.0)
  .attr("marker-start", marker("sequencenumber"))
  |> ignore
  svg
  .append("text")
  .attr_number("x", number_x)
  .attr_number("y", line_start_y + 4.0)
  .attr("font-family", "sans-serif")
  .attr("font-size", font_size)
  .attr("text-anchor", "middle")
  .attr("class", "sequenceNumber")
  .text(label)
  |> ignore
}

///|
/// Draw the participants: the top row with lifelines, or the mirrored
/// row at the foot (`drawActors`).
fn Renderer::draw_actors(
  self : Renderer,
  is_footer : Bool,
) -> Unit raise SequenceError {
  let conf = self.conf
  let bounds = self.bounds
  if !is_footer {
    for key in self.actor_keys {
      guard self.db.actors.get(key) is Some(actor) else { continue }
      self.draw_actor(actor, false) |> ignore
    }
    return
  }
  let mut max_height = 0.0
  bounds.bump_vertical_pos(conf.box_margin * 2.0)
  for key in self.actor_keys {
    guard self.db.actors.get(key) is Some(actor) else { continue }
    // A destroyed participant already knows where it ends.
    if actor.stopy != actor.stopy || actor.stopy == 0.0 {
      actor.stopy = bounds.vertical_pos
    }
    let height = self.draw_actor(actor, true)
    max_height = get_max([max_height, height])
  }
  bounds.bump_vertical_pos(max_height + conf.box_margin)
}

///|
/// Shorten the lifelines to where their participants end
/// (`fixLifeLineHeights`).
fn Renderer::fix_life_line_heights(self : Renderer) -> Unit {
  for key in self.actor_keys {
    guard self.db.actors.get(key) is Some(actor) &&
      actor.actor_cnt is Some(count) &&
      self.svg.find_by_id("actor\{count}") is Some(line) else {
      continue
    }
    let ends = actor.stopy == actor.stopy && actor.stopy != 0.0
    if !self.conf.mirror_actors && ends {
      line.attr_number("y2", actor.stopy + actor.height / 2.0) |> ignore
    } else if self.conf.mirror_actors {
      line.attr_number("y2", actor.stopy) |> ignore
    }
  }
}

///|
/// Open a block or one of its sections: move down, wrap the title to the
/// width of the block's content, and make room for it
/// (`adjustLoopHeightForWrap`).
fn Renderer::adjust_loop_height_for_wrap(
  self : Renderer,
  loop_widths : Map[Int32, LoopWidth],
  msg : Message,
  pre_margin : Double,
  post_margin : Double,
  add : (Message) -> Unit,
) -> Unit raise SequenceError {
  let conf = self.conf
  let bounds = self.bounds
  bounds.bump_vertical_pos(pre_margin)
  let mut height_adjust = post_margin
  if msg.message != "" && loop_widths.get(msg.id) is Some(found) {
    let font = conf.message_font
    msg.message = wrap_label(
      "[\{msg.message}]",
      found.width - 2.0 * conf.wrap_padding,
      font,
    )
    msg.wrap = true
    let dims = text_dimensions(msg.message, font)
    height_adjust = post_margin + get_max([dims.height, conf.label_box_height])
  }
  add(msg)
  bounds.bump_vertical_pos(height_adjust)
}

///|
/// A message that creates or destroys a participant stops at the
/// participant's box rather than at its lifeline, and the box sits at the
/// height of the message (`adjustCreatedDestroyedData`).
fn Renderer::adjust_created_destroyed_data(
  self : Renderer,
  msg : Message,
  model : MsgModel,
  line_start_y : Double,
  index : Int32,
) -> Unit {
  let conf = self.conf
  let bounds = self.bounds
  let is_figure = (actor : Actor) => {
    actor.kind is ("actor" | "control" | "entity" | "database")
  }
  let receiver_adjustment = (actor : Actor, adjustment : Double) => {
    guard self.actor(msg.from) is Some(from) else { return }
    if actor.x < from.x {
      bounds.insert(
        model.stopx - adjustment,
        model.starty,
        model.startx,
        model.stopy + actor.height / 2.0 + conf.note_margin,
      )
      model.stopx = model.stopx + adjustment
    } else {
      bounds.insert(
        model.startx,
        model.starty,
        model.stopx + adjustment,
        model.stopy + actor.height / 2.0 + conf.note_margin,
      )
      model.stopx = model.stopx - adjustment
    }
  }
  let sender_adjustment = (actor : Actor, adjustment : Double) => {
    guard self.actor(msg.to) is Some(to) else { return }
    if actor.x < to.x {
      bounds.insert(
        model.startx - adjustment,
        model.starty,
        model.stopx,
        model.stopy + actor.height / 2.0 + conf.note_margin,
      )
      model.startx = model.startx + adjustment
    } else {
      bounds.insert(
        model.stopx,
        model.starty,
        model.startx + adjustment,
        model.stopy + actor.height / 2.0 + conf.note_margin,
      )
      model.startx = model.startx - adjustment
    }
  }
  let half_width = (actor : Actor) => {
    if is_figure(actor) {
      ACTOR_TYPE_WIDTH / 2.0
    } else {
      actor.width / 2.0
    }
  }
  let created = msg.to.bind(to => self.db.created_actors.get(to))
  let destroyed_from = msg.from.bind(from => self.db.destroyed_actors.get(from))
  let destroyed_to = msg.to.bind(to => self.db.destroyed_actors.get(to))
  if created == Some(index) {
    guard self.actor(msg.to) is Some(actor) else { return }
    receiver_adjustment(actor, half_width(actor) + 3.0)
    actor.starty = line_start_y - actor.height / 2.0
    bounds.bump_vertical_pos(actor.height / 2.0)
  } else if destroyed_from == Some(index) {
    guard self.actor(msg.from) is Some(actor) else { return }
    if conf.mirror_actors {
      sender_adjustment(actor, half_width(actor))
    }
    actor.stopy = line_start_y - actor.height / 2.0
    bounds.bump_vertical_pos(actor.height / 2.0)
  } else if destroyed_to == Some(index) {
    guard self.actor(msg.to) is Some(actor) else { return }
    if conf.mirror_actors {
      receiver_adjustment(actor, half_width(actor) + 3.0)
    }
    actor.stopy = line_start_y - actor.height / 2.0
    bounds.bump_vertical_pos(actor.height / 2.0)
  }
}

///|
/// Draw the sequence diagram into the context's `<svg>` element.
pub fn draw(
  db : SequenceDb,
  context : @diagram.Context,
) -> Unit raise SequenceError {
  let n = @dom.number
  let conf = Conf::new(context.config)
  let svg = context.svg
  let theme = context.theme()
  let bounds = Bounds::new(conf.box_margin)
  let self : Renderer = {
    conf,
    db,
    svg,
    id: context.id,
    theme,
    bounds,
    actor_cnt: -1,
    actor_keys: db.actors.keys().collect(),
    actor_index: Map([]),
  }
  let messages = db.messages
  let has_boxes = db.boxes.length() > 0
  let has_box_titles = db.boxes
    .iter()
    .any(box => box.name is Some(name) && name != "")
  let message_widths = self.max_message_width_per_actor()
  conf.height = self.calculate_actor_margins(message_widths)
  self.insert_definitions()
  if has_boxes {
    bounds.bump_vertical_pos(conf.box_margin)
    if has_box_titles {
      bounds.bump_vertical_pos(db.boxes[0].text_max_height)
    }
  }
  if conf.hide_unused_participants {
    let used : Map[String, Unit] = Map([])
    for message in messages {
      if message.from is Some(from) {
        used[from] = ()
      }
      if message.to is Some(to) {
        used[to] = ()
      }
    }
    self.actor_keys = self.actor_keys.filter(key => used.contains(key))
  }
  for index, key in self.actor_keys {
    self.actor_index[key] = index
  }
  self.add_actor_rendering_data()
  let loop_widths = self.calculate_loop_bounds()
  self.insert_markers()
  // An activation ends: draw its bar up to here.
  let active_end = (msg : Message, vertical_pos : Double) => {
    guard bounds.end_activation(msg.from) is Some(activation) else { return }
    let mut vertical_pos = vertical_pos
    let nan = @double.not_a_number
    if activation.starty.unwrap_or(nan) + 18.0 > vertical_pos {
      activation.starty = Some(vertical_pos - 6.0)
      vertical_pos += 12.0
    }
    self.draw_activation(
      activation,
      vertical_pos,
      bounds.actor_activations(msg.from).length(),
    )
    bounds.insert(
      activation.startx.unwrap_or(nan),
      vertical_pos - 10.0,
      activation.stopx.unwrap_or(nan),
      vertical_pos,
    )
  }
  let new_activation = (msg : Message) => {
    guard self.actor(msg.from) is Some(actor) else {
      raise SequenceError("Cannot read properties of undefined (reading 'x')")
    }
    let stacked = bounds.actor_activations(msg.from).length().to_double()
    let x = actor.x +
      actor.width / 2.0 +
      (stacked - 1.0) * conf.activation_width / 2.0
    bounds.activations.push({
      startx: Some(x),
      starty: Some(bounds.vertical_pos + 2.0),
      stopx: Some(x + conf.activation_width),
      stopy: None,
      actor: msg.from,
      anchored: Some(svg.append("g")),
    })
  }
  let start_block = (msg : Message) => {
    self.adjust_loop_height_for_wrap(
      loop_widths,
      msg,
      conf.box_margin,
      conf.box_margin + conf.box_text_margin,
      message => bounds.new_loop(title=message.message),
    )
  }
  let start_section = (msg : Message) => {
    self.adjust_loop_height_for_wrap(
      loop_widths,
      msg,
      conf.box_margin + conf.box_text_margin,
      conf.box_margin,
      message => bounds.add_section_to_loop(message),
    )
  }
  let end_block = (msg : Message, label : String) => {
    guard bounds.sequence_items.pop() is Some(model) else {
      raise SequenceError(
        "Cannot read properties of undefined (reading 'startx')",
      )
    }
    self.draw_loop(model, label, msg)
    bounds.bump_vertical_pos(
      model.stopy.unwrap_or(@double.not_a_number) - bounds.vertical_pos,
    )
  }
  let mut sequence_index = 1.0
  let mut sequence_index_step = 1.0
  let to_draw : Array[(MsgModel, Double, Message)] = []
  let backgrounds : Array[LoopModel] = []
  for index, msg in messages {
    match msg.kind {
      NOTE => if msg.note_model is Some(note) { self.draw_note(note, msg.id) }
      ACTIVE_START | CENTRAL_CONNECTION | CENTRAL_CONNECTION_REVERSE =>
        new_activation(msg)
      ACTIVE_END => active_end(msg, bounds.vertical_pos)
      LOOP_START
      | OPT_START
      | ALT_START
      | PAR_START
      | PAR_OVER_START
      | CRITICAL_START
      | BREAK_START => start_block(msg)
      LOOP_END => end_block(msg, "loop")
      OPT_END => end_block(msg, "opt")
      ALT_END => end_block(msg, "alt")
      PAR_END => end_block(msg, "par")
      CRITICAL_END => end_block(msg, "critical")
      BREAK_END => end_block(msg, "break")
      ALT_ELSE | PAR_AND | CRITICAL_OPTION => start_section(msg)
      RECT_START =>
        self.adjust_loop_height_for_wrap(
          loop_widths,
          msg,
          conf.box_margin,
          conf.box_margin,
          message => {
            // Without a color of its own the rect takes one the theme
            // has for it.
            let mut fill = message.message
            if fill == "" {
              fill = "rgba(128, 128, 128, 0.5)"
              for variable in ["actorBkg", "rectBkgColor"] {
                if theme.get(variable) is String(color) && color != "" {
                  fill = color
                }
              }
            }
            bounds.new_loop(fill~)
          },
        )
      RECT_END => {
        guard bounds.sequence_items.pop() is Some(model) else {
          raise SequenceError(
            "Cannot read properties of undefined (reading 'stopy')",
          )
        }
        backgrounds.push(model)
        bounds.bump_vertical_pos(
          model.stopy.unwrap_or(@double.not_a_number) - bounds.vertical_pos,
        )
      }
      AUTONUMBER => {
        sequence_index = match msg.sequence_start {
          Some(start) if start != 0.0 => start
          _ => sequence_index
        }
        sequence_index_step = match msg.sequence_step {
          Some(step) if step != 0.0 => step
          _ => sequence_index_step
        }
        db.sequence_numbers_enabled = msg.sequence_visible
      }
      _ =>
        // A failure here is logged upstream and the entry skipped; there
        // is nothing to fail for a message that has its model.
        if msg.msg_model is Some(model) {
          model.starty = bounds.vertical_pos
          model.sequence_index = sequence_index
          model.sequence_visible = db.sequence_numbers_enabled
          let line_start_y = self.bound_message(model)
          self.adjust_created_destroyed_data(msg, model, line_start_y, index)
          to_draw.push((model, line_start_y, msg))
        }
    }
    if is_message_line(msg.kind) {
      // Rounded to two decimals, against floating point drift.
      sequence_index = js_round((sequence_index + sequence_index_step) * 100.0) /
        100.0
    }
  }
  self.draw_actors(false)
  for entry in to_draw {
    self.draw_message(entry.0, entry.1, entry.2)
  }
  if conf.mirror_actors {
    self.draw_actors(true)
  }
  for model in backgrounds {
    draw_background_rect(
      svg,
      model.startx,
      model.starty,
      model.stopx,
      model.stopy,
      model.fill,
      None,
    )
  }
  self.fix_life_line_heights()
  for box in bounds.boxes {
    box.height = bounds.vertical_pos - box.y
    bounds.insert(box.x, box.y, box.x + box.width, box.height)
    self.draw_box(box)
  }
  if has_boxes {
    bounds.bump_vertical_pos(conf.box_margin)
  }
  // Popup menus hang from the top row of participants.
  let mut popup_height = 0.0
  let mut popup_width = 0.0
  for key in self.actor_keys {
    guard db.actors.get(key) is Some(actor) else { continue }
    let (height, width) = self.draw_popup(
      actor,
      self.required_popup_width(actor),
    )
    if height > popup_height {
      popup_height = height
    }
    if width + actor.x > popup_width {
      popup_width = width + actor.x
    }
  }
  let box_startx = bounds.startx.unwrap_or(0.0)
  let box_starty = bounds.starty.unwrap_or(0.0)
  let box_stopx = bounds.stopx.unwrap_or(0.0)
  let box_stopy = bounds.stopy.unwrap_or(0.0)
  // Tall or wide menus need room too.
  let mut box_height = box_stopy - box_starty
  if box_height < popup_height {
    box_height = popup_height
  }
  let mut height = box_height + 2.0 * conf.diagram_margin_y
  if conf.mirror_actors {
    height = height - conf.box_margin + conf.bottom_margin_adj
  }
  let mut box_width = box_stopx - box_startx
  if box_width < popup_width {
    box_width = popup_width
  }
  let width = box_width + 2.0 * conf.diagram_margin_x
  if db.title != "" {
    svg
    .append("text")
    .text(db.title)
    .attr_number(
      "x",
      (box_stopx - box_startx) / 2.0 - 2.0 * conf.diagram_margin_x,
    )
    .attr_number("y", -25.0)
    |> ignore
  }
  @diagram.configure_svg_size(svg, height, width, conf.use_max_width)
  let extra_for_title = if db.title != "" { 40.0 } else { 0.0 }
  let extra_for_neo = if db.actors.length() > 0 && conf.is_neo() {
    30.0
  } else {
    0.0
  }
  svg.attr(
    "viewBox",
    "\{n(box_startx - conf.diagram_margin_x)} -\{n(conf.diagram_margin_y + extra_for_title)} \{n(width)} \{n(height + extra_for_title + extra_for_neo)}",
  )
  |> ignore
}
