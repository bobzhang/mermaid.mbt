// The database's layout: every frame becomes a box in a swimlane, placed
// to the right of what is there, and is related to the box it follows
// from. Upstream phrases this as commands and events folded over a state;
// what the folding does is here in the order it happens.

///|
const SWIMLANE_MIN_HEIGHT : Double = 70.0

///|
const SWIMLANE_PADDING : Double = 15.0

///|
const SWIMLANE_GAP : Double = 10.0

///|
const BOX_PADDING : Double = 10.0

///|
const BOX_OVERLAP : Double = 90.0

///|
const BOX_MIN_WIDTH : Double = 80.0

///|
const BOX_MAX_WIDTH : Double = 450.0

///|
const BOX_MIN_HEIGHT : Double = 80.0

///|
const BOX_MAX_HEIGHT : Double = 750.0

///|
const CONTENT_START_X : Double = 250.0

///|
const TEXT_MAX_WIDTH : Double = 430.0

///|
const BOX_TEXT_PADDING : Double = 10.0

///|
/// A row of the diagram. Boxes hold on to their swimlane, whose place is
/// only settled once every frame is in.
priv struct Swimlane {
  index : Int32
  label : String
  /// The right edge of its last box.
  mut r : Double
  mut y : Double
  mut height : Double
  mut max_height : Double
}

///|
priv struct Box {
  x : Double
  /// The right edge, with the padding after it.
  r : Double
  width : Double
  height : Double
  swimlane : Swimlane
  fill : String
  stroke : String
  /// The content, as HTML.
  text : String
  frame : Frame
}

///|
priv struct State {
  boxes : Array[Box]
  /// By index.
  swimlanes : Map[Int32, Swimlane]
  /// Source and target.
  relations : Array[(Box, Box)]
  mut previous_swimlane : Int32?
  mut max_r : Double
}

///|
/// The swimlanes from the top down: in the order of their indices.
fn State::sorted_swimlanes(self : State) -> Array[Swimlane] {
  let swimlanes = self.swimlanes.values().collect()
  swimlanes.sort_by_key(swimlane => swimlane.index)
  swimlanes
}

///|
/// The namespace of `Namespace.Name`.
fn extract_namespace(entity_identifier : String) -> String? {
  match entity_identifier.split(".").collect() {
    [space, _] => Some(space.to_owned())
    _ => None
  }
}

///|
/// The name of `Namespace.Name`; an identifier of any other shape is its
/// own name.
fn extract_name(entity_identifier : String) -> String {
  match entity_identifier.split(".").collect() {
    [_, name] => name.to_owned()
    _ => entity_identifier
  }
}

///|
/// `findNextAvailableIndex`: one more than the highest index in use
/// between the bounds, both excluded.
fn State::next_available_index(self : State, min : Int32, max : Int32) -> Int32 {
  let mut highest = min
  for index in self.swimlanes.keys() {
    if index > min && index < max && index > highest {
      highest = index
    }
  }
  highest + 1
}

///|
/// `calculateSwimlaneProps`: the index and the label of the swimlane a
/// frame goes to. The three kinds of entities have a swimlane each, a
/// hundred indices apart; a frame with a namespace opens one more after
/// those of its kind. (Upstream looks for a swimlane of that namespace
/// first, and never finds one, since no swimlane records its namespace.)
fn State::swimlane_props(self : State, frame : Frame) -> (Int32, String) {
  let (base, label, prefix) = match frame.entity_type {
    Ui | Processor => (0, "UI/Automation", "UI/A: ")
    ReadModel | Command => (100, "Command/Read Model", "C/RM: ")
    Event => (200, "Events", "Stream: ")
  }
  match extract_namespace(frame.entity_identifier) {
    // An empty namespace is none.
    Some(space) if space != "" =>
      (self.next_available_index(base, base + 100), prefix + space)
    _ => (base, label)
  }
}

///|
/// `calculateEntityVisualProps`: fill and stroke.
fn visual_props(frame : Frame, theme : @theme.Theme) -> (String, String) {
  let variable = (name : String, fallback : String) => {
    match theme.get(name) {
      Null => fallback
      _ => theme.text(name)
    }
  }
  let (kind, fill, stroke) = match frame.entity_type {
    Ui => ("Ui", "white", "#dbdada")
    Processor => ("Processor", "#edb3f6", "#b88cbf")
    ReadModel => ("ReadModel", "#d3f1a2", "#a3b732")
    Command => ("Command", "#bcd6fe", "#679ac3")
    Event => ("Event", "#ffb778", "#c19a0f")
  }
  (variable("em\{kind}Fill", fill), variable("em\{kind}Stroke", stroke))
}

///|
/// JavaScript's `substring` from `start` to `end`, both clamped.
fn substring(
  text : String,
  start : Int32,
  end : Int32,
) -> String raise Unsupported {
  let length = text.length()
  let clamp = (index : Int32) => {
    if index < 0 {
      0
    } else if index > length {
      length
    } else {
      index
    }
  }
  let (start, end) = (clamp(start), clamp(end))
  let (start, end) = if start > end { (end, start) } else { (start, end) }
  // A cut through a character outside the basic plane leaves half of it.
  let splits = (index : Int32) => {
    index > 0 &&
    index < length &&
    text[index].to_int() >= 0xDC00 &&
    text[index].to_int() < 0xE000
  }
  if splits(start) || splits(end) {
    raise Unsupported("data cut in the middle of a character")
  }
  text[start:end].to_owned()
}

///|
/// The index of the last `}`, or -1.
fn last_closing_brace(text : String) -> Int32 {
  for index = text.length() - 1; index >= 0; index = index - 1 {
    if text[index] == '}' {
      return index
    }
  }
  -1
}

///|
/// mermaid's `sanitizeText`, with a check that what comes out is HTML the
/// port reads as the browser does: of the character references only the
/// common ones written out in full.
fn sanitize(text : String) -> String raise Unsupported {
  let text = @journeycommon.sanitize_text(text) catch {
    @journeycommon.SanitizeError(message) => raise Unsupported(message)
  }
  let mut rest = text[:]
  while rest.find("&") is Some(at) {
    rest = rest[at + 1:]
    guard rest is ['A'..<='Z' | 'a'..<='z' | '0'..<='9' | '#', ..] else {
      continue
    }
    let known = ["lt;", "gt;", "amp;", "quot;", "nbsp;"]
    if !known.iter().any(reference => rest.has_prefix(reference)) {
      raise Unsupported("character references in data: \{text}")
    }
  }
  text
}

///|
/// The data of a frame as HTML: what is between the braces, less the
/// character before the closing one, wrapped, with every blank made a
/// no-break space.
fn data_html(data : String, opening : String) -> String raise {
  let start = match data.find(opening) {
    Some(index) => index
    None => -1
  }
  let inner = substring(data, start + opening.length(), data.length())
  let inner = substring(inner, 0, last_closing_brace(inner) - 1)
  wrap_label(sanitize(inner), TEXT_MAX_WIDTH).replace_all(old=" ", new="&nbsp;")
}

///|
/// `calculateTextProps`: the content of a frame's box as HTML, and its
/// size as text.
fn text_props(
  frame : Frame,
  model : EventModel,
) -> (String, Double, Double) raise {
  let name = sanitize(extract_name(frame.entity_identifier))
  let content = StringBuilder()
  content.write_string("<b>\{wrap_label(name, TEXT_MAX_WIDTH)}</b>")
  let mut data : String? = None
  if frame.data_inline is Some(inline) {
    data = Some(data_html(inline, "{"))
  }
  // A data block takes the place of data on the line.
  if frame.data_reference is Some(reference) &&
    model.data_entities.search_by(entity => entity.0 == reference)
    is Some(index) {
    data = Some(data_html(model.data_entities[index].1, "{\n") + "<br/>")
  }
  if data is Some(data) {
    content.write_string(
      "<br/><br/><code style=\"text-align: left; display: block;max-width:\{@dom.number(TEXT_MAX_WIDTH)}px\">\{data}</code>",
    )
  }
  let content = content.to_string()
  // The markup is measured as the text it is written as, which makes a
  // box with data far too wide: upstream takes a third.
  let (width, height) = text_dimensions(content)
  (content, if data is Some(_) { width / 3.0 } else { width }, height)
}

///|
/// `calculateX`: where the next box starts. After a box of the same
/// swimlane, behind it; after one of another swimlane, under or above its
/// right end.
fn State::next_x(self : State, swimlane : Swimlane) -> Double {
  guard self.previous_swimlane is Some(previous) else { return CONTENT_START_X }
  if previous == swimlane.index && swimlane.r != 0.0 {
    return swimlane.r + BOX_PADDING
  }
  match self.boxes.last() {
    Some(last) => last.r - BOX_OVERLAP + BOX_PADDING
    None => CONTENT_START_X
  }
}

///|
fn max(a : Double, b : Double) -> Double {
  if b > a {
    b
  } else {
    a
  }
}

///|
fn min(a : Double, b : Double) -> Double {
  if b < a {
    b
  } else {
    a
  }
}

///|
/// `evolveFramePositioned`: put the frame's box in its swimlane.
fn State::position_frame(
  self : State,
  frame : Frame,
  model : EventModel,
  theme : @theme.Theme,
) -> Unit raise {
  let (content, text_width, text_height) = text_props(frame, model)
  let (fill, stroke) = visual_props(frame, theme)
  let (index, label) = self.swimlane_props(frame)
  let swimlane = match self.swimlanes.get(index) {
    Some(swimlane) => swimlane
    None =>
      {
        index,
        label,
        r: 0.0,
        y: index.to_double() * SWIMLANE_MIN_HEIGHT + SWIMLANE_GAP,
        height: SWIMLANE_MIN_HEIGHT,
        max_height: SWIMLANE_MIN_HEIGHT,
      }
  }
  let width = max(
      BOX_MIN_WIDTH,
      min(BOX_MAX_WIDTH, text_width + 2.0 * BOX_TEXT_PADDING),
    ) +
    2.0 * BOX_PADDING
  let height = max(
      BOX_MIN_HEIGHT,
      min(BOX_MAX_HEIGHT, text_height + 2.0 * BOX_TEXT_PADDING),
    ) +
    2.0 * BOX_PADDING
  let x = self.next_x(swimlane)
  let r = x + width + BOX_PADDING
  // The right end of the diagram: that of this box or of a swimlane as
  // it was before the box came, whichever is further.
  let mut max_r = r
  for other in self.swimlanes.values() {
    max_r = max(max_r, other.r)
  }
  swimlane.r = x + width
  swimlane.max_height = max(swimlane.max_height, height)
  swimlane.height = max(SWIMLANE_MIN_HEIGHT, swimlane.max_height) +
    2.0 * SWIMLANE_PADDING
  self.boxes.push({
    x,
    r,
    width,
    height,
    swimlane,
    fill,
    stroke,
    text: content,
    frame,
  })
  self.swimlanes[index] = swimlane
  self.previous_swimlane = Some(index)
  self.max_r = max_r
  // Stack the swimlanes anew.
  let mut y = 0.0
  for index, swimlane in self.sorted_swimlanes() {
    if index > 0 {
      y += SWIMLANE_GAP
    }
    swimlane.y = y
    y += swimlane.height
  }
}

///|
/// `findBoxByLineIndex`: the nearest box at or before `line` that is in
/// another swimlane than `swimlane`.
fn State::box_before(self : State, swimlane : Int32, line : Int32) -> Box? {
  for i = line; i >= 0; i = i - 1 {
    if self.boxes[i].swimlane.index != swimlane {
      return Some(self.boxes[i])
    }
  }
  None
}

///|
fn State::box_of(self : State, name : String) -> Box? {
  for box in self.boxes {
    if box.frame.name == name {
      return Some(box)
    }
  }
  None
}

///|
/// `decidePositionRelation`: relate the box of the frame at `index` to
/// the box of `source`, or without one to the box it follows from.
fn State::position_relation(
  self : State,
  index : Int32,
  frame : Frame,
  source : Frame?,
) -> Unit {
  // The first frame follows from nothing.
  if index == 0 && frame.source_frames.is_empty() {
    return
  }
  let target = self.boxes[index]
  let source_box = match source {
    Some(source) => self.box_of(source.name)
    None => {
      if frame.reset {
        return
      }
      self.box_before(target.swimlane.index, index - 1)
    }
  }
  // A source further down the timeline has no box yet.
  if source_box is Some(source_box) {
    self.relations.push((source_box, target))
  }
}

///|
/// The database's `getState`: lay out the model.
fn layout(model : EventModel, theme : @theme.Theme) -> State raise {
  let state = {
    boxes: [],
    swimlanes: Map([]),
    relations: [],
    previous_swimlane: None,
    max_r: 0.0,
  }
  for index, frame in model.frames {
    state.position_frame(frame, model, theme)
    if frame.source_frames.is_empty() {
      state.position_relation(index, frame, None)
    } else {
      // In the order of the timeline, each frame once.
      for source in model.frames {
        if frame.source_frames.contains(source.name) {
          state.position_relation(index, frame, Some(source))
        }
      }
    }
  }
  state
}
