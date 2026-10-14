// Sizes and positions worked out before drawing: how far apart the
// participants stand, and where every note, message and block will go.

///|
/// The state of one rendering.
priv struct Renderer {
  conf : Conf
  db : SequenceDb
  /// The root `<svg>` element.
  svg : @dom.Element
  id : String
  theme : @theme.Theme
  bounds : Bounds
  /// The number of the last participant drawn; lifelines and popup menus
  /// are named after it.
  mut actor_cnt : Int32
  /// The participants to draw, in order.
  mut actor_keys : Array[String]
  /// The place of each of them in that order, by name.
  actor_index : Map[String, Int32]
}

///|
/// A value that JavaScript would find falsy stands for "not set".
fn or_default(value : Double, default : Double) -> Double {
  if value != value || value == 0.0 {
    default
  } else {
    value
  }
}

///|
fn Renderer::actor(self : Renderer, key : String?) -> Actor? {
  match key {
    Some(key) => self.db.actors.get(key)
    None => None
  }
}

///|
/// KaTeX needs the browser's MathML layout; nothing of it is ported.
fn reject_katex(text : String) -> Unit raise SequenceError {
  let katex = try! @jsregex.Regex::compile("\\$\\$(.*?)\\$\\$")
  if katex.exec(text) is Some(_) {
    raise SequenceError("Unsupported: KaTeX math in a sequence diagram")
  }
}

///|
/// The room each participant needs to its right for the widest message
/// or note between it and its neighbour (`getMaxMessageWidthPerActor`).
fn Renderer::max_message_width_per_actor(
  self : Renderer,
) -> Map[String, Double] raise SequenceError {
  let conf = self.conf
  let widths : Map[String, Double] = Map([])
  let widen = (key : String?, width : Double) => {
    // An undefined key would only matter to a participant of that name.
    guard key is Some(key) else { return }
    widths[key] = get_max([widths.get(key).unwrap_or(0.0), width])
  }
  for msg in self.db.messages {
    guard self.actor(msg.to) is Some(actor) && self.actor(msg.from) is Some(_) else {
      continue
    }
    if msg.placement == Some(LEFT_OF) && actor.prev_actor is None {
      continue
    }
    if msg.placement == Some(RIGHT_OF) && actor.next_actor is None {
      continue
    }
    let is_message = msg.placement is None
    let font = if is_message { conf.message_font } else { conf.note_font }
    let wrapped = if msg.wrap {
      wrap_label(msg.message, conf.width - 2.0 * conf.wrap_padding, font)
    } else {
      msg.message
    }
    reject_katex(wrapped)
    let message_width = text_dimensions(wrapped, font).width +
      2.0 * conf.wrap_padding
    if is_message && msg.from == actor.next_actor {
      widen(msg.to, message_width)
    } else if is_message && msg.from == actor.prev_actor {
      widen(msg.from, message_width)
    } else if is_message && msg.from == msg.to {
      widen(msg.from, message_width / 2.0)
      widen(msg.to, message_width / 2.0)
    } else if msg.placement == Some(RIGHT_OF) {
      widen(msg.from, message_width)
    } else if msg.placement == Some(LEFT_OF) {
      widen(actor.prev_actor, message_width)
    } else if msg.placement == Some(OVER) {
      if actor.prev_actor is Some(_) {
        widen(actor.prev_actor, message_width / 2.0)
      }
      if actor.next_actor is Some(_) {
        widen(msg.from, message_width / 2.0)
      }
    }
  }
  widths
}

///|
/// The height of a participant drawn as a figure in the neo look: the
/// figure, its label, and the gaps around them.
fn actor_stack_height(text_height : Double) -> Double {
  GLYPH_BAND_HEIGHT + GLYPH_LABEL_GAP + text_height + LABEL_LIFELINE_GAP
}

///|
const GLYPH_BAND_HEIGHT : Double = 44.0

///|
const GLYPH_LABEL_GAP : Double = 6.0

///|
const LABEL_LIFELINE_GAP : Double = 6.0

///|
/// Size the participants and the boxes around them, and set the margins
/// between neighbours so that the widest message fits
/// (`calculateActorMargins`). Returns the height of the tallest
/// participant.
fn Renderer::calculate_actor_margins(
  self : Renderer,
  message_widths : Map[String, Double],
) -> Double raise SequenceError {
  let conf = self.conf
  let mut max_height = 0.0
  for _, actor in self.db.actors {
    if actor.wrap {
      actor.description = wrap_label(
        actor.description,
        conf.width - 2.0 * conf.wrap_padding,
        conf.actor_font,
      )
    }
    reject_katex(actor.description)
    let dims = text_dimensions(actor.description, conf.actor_font)
    actor.width = if actor.wrap {
      conf.width
    } else {
      get_max([conf.width, dims.width + 2.0 * conf.wrap_padding])
    }
    if conf.is_neo() {
      actor.text_height = Some(dims.height)
      actor.height = get_max([actor_stack_height(dims.height), conf.height])
    } else {
      actor.height = if actor.wrap {
        get_max([dims.height, conf.height])
      } else {
        conf.height
      }
    }
    max_height = get_max([max_height, actor.height])
  }
  for key, message_width in message_widths {
    guard self.db.actors.get(key) is Some(actor) else { continue }
    let actor_width = match self.actor(actor.next_actor) {
      None => message_width + conf.actor_margin - actor.width / 2.0
      Some(next) =>
        message_width + conf.actor_margin - actor.width / 2.0 - next.width / 2.0
    }
    actor.margin = get_max([actor_width, conf.actor_margin])
  }
  let mut max_box_height = 0.0
  for box in self.db.boxes {
    let font = conf.message_font
    let mut total_width = 0.0
    for key in box.actor_keys {
      guard self.db.actors.get(key) is Some(actor) else { continue }
      total_width += actor.width + or_default(actor.margin, 0.0)
    }
    total_width += conf.box_margin * 8.0
    total_width -= 2.0 * conf.box_text_margin
    if box.wrap && box.name is Some(name) {
      box.name = Some(
        wrap_label(name, total_width - 2.0 * conf.wrap_padding, font),
      )
    }
    let dims = text_dimensions(box.name.unwrap_or(""), font)
    max_box_height = get_max([dims.height, max_box_height])
    let min_width = get_max([total_width, dims.width + 2.0 * conf.wrap_padding])
    box.margin = conf.box_text_margin
    if total_width < min_width {
      box.margin += (min_width - total_width) / 2.0
    }
  }
  for box in self.db.boxes {
    box.text_max_height = max_box_height
  }
  get_max([max_height, conf.height])
}

///|
/// Place the participants side by side, and the boxes around them
/// (`addActorRenderingData`).
fn Renderer::add_actor_rendering_data(self : Renderer) -> Unit {
  let conf = self.conf
  let bounds = self.bounds
  let vertical_pos = 0.0
  let mut prev_width = 0.0
  let mut prev_margin = 0.0
  let mut prev_box : Box? = None
  let mut max_height = 0.0
  let same_box = (a : Box?, b : Box?) => {
    match (a, b) {
      (Some(a), Some(b)) => physical_equal(a, b)
      (None, None) => true
      _ => false
    }
  }
  for key in self.actor_keys {
    guard self.db.actors.get(key) is Some(actor) else { continue }
    let box = actor.box
    // The previous box ends here.
    if prev_box is Some(previous) && !same_box(prev_box, box) {
      bounds.boxes.push(previous)
      prev_margin += conf.box_margin + previous.margin
    }
    // A new box starts here.
    if box is Some(box) && !same_box(Some(box), prev_box) {
      box.x = prev_width + prev_margin
      box.y = vertical_pos
      prev_margin += box.margin
    }
    actor.width = get_max([or_default(actor.width, conf.width), conf.width])
    actor.height = get_max([or_default(actor.height, conf.height), conf.height])
    actor.margin = or_default(actor.margin, conf.actor_margin)
    max_height = get_max([max_height, actor.height])
    // A participant created by a message stands further off.
    if self.db.created_actors.get(actor.name) is Some(index) && index != 0 {
      prev_margin += actor.width / 2.0
    }
    actor.x = prev_width + prev_margin
    actor.starty = bounds.vertical_pos
    bounds.insert(actor.x, vertical_pos, actor.x + actor.width, actor.height)
    prev_width += actor.width + prev_margin
    if box is Some(box) {
      box.width = prev_width + box.margin - box.x
    }
    prev_margin = actor.margin
    prev_box = actor.box
  }
  if prev_box is Some(previous) {
    bounds.boxes.push(previous)
  }
  // Messages start below the participants.
  bounds.bump_vertical_pos(max_height)
}

///|
/// The left and right edge of a participant's lifeline, including the
/// activation bars stacked on it (`activationBounds`).
fn Renderer::activation_bounds(
  self : Renderer,
  key : String?,
) -> (Double, Double) raise SequenceError {
  guard self.actor(key) is Some(actor) else {
    raise SequenceError("Cannot read properties of undefined (reading 'x')")
  }
  let activations = self.bounds.actor_activations(key)
  let mut left = actor.x + actor.width / 2.0 - 1.0
  let mut right = actor.x + actor.width / 2.0 + 1.0
  for activation in activations {
    left = get_min([left, activation.startx.unwrap_or(@double.not_a_number)])
    right = get_max([right, activation.stopx.unwrap_or(@double.not_a_number)])
  }
  (left, right)
}

///|
/// Where a note goes and how wide it is (`buildNoteModel`).
fn Renderer::build_note_model(
  self : Renderer,
  msg : Message,
) -> NoteModel raise SequenceError {
  let conf = self.conf
  guard self.actor(msg.from) is Some(from) && self.actor(msg.to) is Some(to) else {
    raise SequenceError("Cannot read properties of undefined (reading 'x')")
  }
  let font = conf.note_font
  let startx = from.x
  let stopx = to.x
  let should_wrap = msg.wrap && msg.message != ""
  reject_katex(msg.message)
  let mut dims = text_dimensions(
    if should_wrap {
      wrap_label(msg.message, conf.width, font)
    } else {
      msg.message
    },
    font,
  )
  let model : NoteModel = {
    width: if should_wrap {
      conf.width
    } else {
      get_max([conf.width, dims.width + 2.0 * conf.note_margin])
    },
    startx: from.x,
    stopx: 0.0,
    starty: 0.0,
    stopy: 0.0,
    message: msg.message,
  }
  if msg.placement == Some(RIGHT_OF) {
    model.width = if should_wrap {
      get_max([conf.width, dims.width])
    } else {
      get_max([
        from.width / 2.0 + to.width / 2.0,
        dims.width + 2.0 * conf.note_margin,
      ])
    }
    model.startx = startx + (from.width + conf.actor_margin) / 2.0
  } else if msg.placement == Some(LEFT_OF) {
    model.width = if should_wrap {
      get_max([conf.width, dims.width + 2.0 * conf.note_margin])
    } else {
      get_max([
        from.width / 2.0 + to.width / 2.0,
        dims.width + 2.0 * conf.note_margin,
      ])
    }
    model.startx = startx - model.width + (from.width - conf.actor_margin) / 2.0
  } else if msg.to == msg.from {
    dims = text_dimensions(
      if should_wrap {
        wrap_label(msg.message, get_max([conf.width, from.width]), font)
      } else {
        msg.message
      },
      font,
    )
    model.width = if should_wrap {
      get_max([conf.width, from.width])
    } else {
      get_max([from.width, conf.width, dims.width + 2.0 * conf.note_margin])
    }
    model.startx = startx + (from.width - model.width) / 2.0
  } else {
    model.width = (startx + from.width / 2.0 - (stopx + to.width / 2.0)).abs() +
      conf.actor_margin
    model.startx = if startx < stopx {
      startx + from.width / 2.0 - conf.actor_margin / 2.0
    } else {
      stopx + to.width / 2.0 - conf.actor_margin / 2.0
    }
  }
  if should_wrap {
    model.message = wrap_label(
      msg.message,
      model.width - 2.0 * conf.wrap_padding,
      font,
    )
  }
  model
}

///|
const CENTRAL_CONNECTION_BASE_OFFSET : Double = 4.0

///|
const CENTRAL_CONNECTION_BIDIRECTIONAL_OFFSET : Double = 6.0

///|
/// How far a message line starts off its lifeline to leave room for the
/// circle of a central connection.
fn central_connection_offset(msg : Message, is_arrow_to_right : Bool) -> Double {
  let mut offset = 0.0
  let at_source = msg.central_connection
    is (CENTRAL_CONNECTION_REVERSE | CENTRAL_CONNECTION_DUAL)
  if at_source {
    offset += CENTRAL_CONNECTION_BASE_OFFSET
  }
  if at_source && is_bidirectional(msg.kind) {
    offset += if is_arrow_to_right {
      0.0
    } else {
      -CENTRAL_CONNECTION_BIDIRECTIONAL_OFFSET
    }
  }
  offset
}

///|
/// Where a message line starts and stops (`buildMessageModel`). Entries
/// that are not message lines have no model.
fn Renderer::build_message_model(
  self : Renderer,
  msg : Message,
) -> MsgModel? raise SequenceError {
  let conf = self.conf
  guard is_message_line(msg.kind) else { return None }
  let (from_left, from_right) = self.activation_bounds(msg.from)
  let (to_left, to_right) = self.activation_bounds(msg.to)
  let is_arrow_to_right = from_left <= to_left
  let mut startx = if is_arrow_to_right { from_right } else { from_left }
  let mut stopx = if is_arrow_to_right { to_left } else { to_right }
  if conf.is_neo() {
    let offset = 3.0
    if msg.kind != SOLID_OPEN {
      stopx += if is_arrow_to_right { -offset } else { offset }
    }
    if is_bidirectional(msg.kind) {
      startx += if is_arrow_to_right { offset } else { -offset }
    }
  }
  startx += central_connection_offset(msg, is_arrow_to_right)
  let is_arrow_to_activation = (to_left - to_right).abs() > 2.0
  let adjust = (value : Double) => {
    if is_arrow_to_right {
      -value
    } else {
      value
    }
  }
  if msg.from == msg.to {
    stopx = startx
  } else {
    if msg.activate && !is_arrow_to_activation {
      stopx += adjust(conf.activation_width / 2.0 - 1.0)
    }
    let keeps_tip = msg.kind
      is (SOLID_OPEN
      | DOTTED_OPEN
      | STICK_TOP
      | STICK_BOTTOM
      | STICK_TOP_DOTTED
      | STICK_BOTTOM_DOTTED
      | SOLID_ARROW_TOP_REVERSE_DOTTED
      | SOLID_ARROW_BOTTOM_REVERSE_DOTTED
      | STICK_ARROW_TOP_REVERSE
      | STICK_ARROW_BOTTOM_REVERSE
      | STICK_ARROW_TOP_REVERSE_DOTTED
      | STICK_ARROW_BOTTOM_REVERSE_DOTTED
      | SOLID_ARROW_TOP_REVERSE
      | SOLID_ARROW_BOTTOM_REVERSE)
    if !keeps_tip {
      stopx += adjust(3.0)
    }
    let head_at_start = msg.kind
      is (BIDIRECTIONAL_SOLID
      | BIDIRECTIONAL_DOTTED
      | SOLID_ARROW_TOP_REVERSE_DOTTED
      | SOLID_ARROW_BOTTOM_REVERSE_DOTTED
      | SOLID_ARROW_TOP_REVERSE
      | SOLID_ARROW_BOTTOM_REVERSE)
    if head_at_start {
      startx -= adjust(3.0)
    }
  }
  let bounded_width = (startx - stopx).abs()
  if msg.wrap && msg.message != "" {
    msg.message = wrap_label(
      msg.message,
      get_max([bounded_width + 2.0 * conf.wrap_padding, conf.width]),
      conf.message_font,
    )
  }
  let dims = text_dimensions(msg.message, conf.message_font)
  Some({
    width: get_max([
      if msg.wrap {
        0.0
      } else {
        dims.width + 2.0 * conf.wrap_padding
      },
      bounded_width + 2.0 * conf.wrap_padding,
      conf.width,
    ]),
    height: 0.0,
    startx,
    stopx,
    starty: 0.0,
    stopy: 0.0,
    message: msg.message,
    kind: msg.kind,
    from_bounds: get_min_strict([from_left, from_right, to_left, to_right]),
    to_bounds: get_max_strict([from_left, from_right, to_left, to_right]),
    sequence_index: 0.0,
    sequence_visible: false,
  })
}

///|
/// `Math.min.apply(null, values)`.
fn get_min_strict(values : Array[Double]) -> Double {
  values.fold(init=@double.infinity, js_min)
}

///|
fn get_max_strict(values : Array[Double]) -> Double {
  values.fold(init=@double.neg_infinity, js_max)
}

///|
/// The horizontal extent of a block's content, collected while the
/// entries inside it are measured.
priv struct LoopWidth {
  mut from : Double
  mut to : Double
  mut width : Double
}

///|
/// Build the model of every note and message, and find how wide each
/// block's content is, so its title can wrap to it
/// (`calculateLoopBounds`). The result maps the id of a block's opening
/// and section entries to the block's width.
fn Renderer::calculate_loop_bounds(
  self : Renderer,
) -> Map[Int32, LoopWidth] raise SequenceError {
  let conf = self.conf
  let bounds = self.bounds
  let loops : Map[Int32, LoopWidth] = Map([])
  let stack : Array[(Int32, LoopWidth)] = []
  for msg in self.db.messages {
    match msg.kind {
      LOOP_START
      | ALT_START
      | OPT_START
      | PAR_START
      | PAR_OVER_START
      | CRITICAL_START
      | BREAK_START =>
        stack.push(
          (
            msg.id,
            { from: 9007199254740991.0, to: -9007199254740991.0, width: 0.0, },
          ),
        )
      ALT_ELSE | PAR_AND | CRITICAL_OPTION =>
        if msg.message != "" {
          guard stack.last() is Some((id, current)) else {
            raise SequenceError(
              "Cannot read properties of undefined (reading 'id')",
            )
          }
          loops[id] = current
          loops[msg.id] = current
        }
      LOOP_END | ALT_END | OPT_END | PAR_END | CRITICAL_END | BREAK_END => {
        guard stack.pop() is Some((id, current)) else {
          raise SequenceError(
            "Cannot read properties of undefined (reading 'id')",
          )
        }
        loops[id] = current
      }
      ACTIVE_START => {
        guard self.actor(msg.from) is Some(actor) else {
          raise SequenceError(
            "Cannot read properties of undefined (reading 'x')",
          )
        }
        let stacked = bounds.actor_activations(msg.from).length().to_double()
        let x = actor.x +
          actor.width / 2.0 +
          (stacked - 1.0) * conf.activation_width / 2.0
        bounds.activations.push({
          startx: Some(x),
          starty: None,
          stopx: Some(x + conf.activation_width),
          stopy: None,
          actor: msg.from,
          anchored: None,
        })
      }
      ACTIVE_END => ignore(bounds.end_activation(msg.from))
      _ => ()
    }
    if msg.placement is Some(_) {
      let note = self.build_note_model(msg)
      msg.note_model = Some(note)
      for entry in stack {
        let current = entry.1
        current.from = get_min([current.from, note.startx])
        current.to = get_max([current.to, note.startx + note.width])
        current.width = get_max([
            current.width,
            (current.from - current.to).abs(),
          ]) -
          conf.label_box_width
      }
    } else {
      let model = self.build_message_model(msg)
      msg.msg_model = model
      // A line that starts or stops at zero counts as none here.
      guard model is Some(model) &&
        model.startx != 0.0 &&
        model.stopx != 0.0 &&
        model.startx == model.startx &&
        model.stopx == model.stopx else {
        continue
      }
      for entry in stack {
        let current = entry.1
        if model.startx == model.stopx {
          guard self.actor(msg.from) is Some(from) &&
            self.actor(msg.to) is Some(to) else {
            continue
          }
          current.from = get_min([
            from.x - model.width / 2.0,
            from.x - from.width / 2.0,
            current.from,
          ])
          current.to = get_max([
            to.x + model.width / 2.0,
            to.x + from.width / 2.0,
            current.to,
          ])
          current.width = get_max([
              current.width,
              (current.to - current.from).abs(),
            ]) -
            conf.label_box_width
        } else {
          current.from = get_min([model.startx, current.from])
          current.to = get_max([model.stopx, current.to])
          current.width = get_max([current.width, model.width]) -
            conf.label_box_width
        }
      }
    }
  }
  bounds.activations.clear()
  loops
}
