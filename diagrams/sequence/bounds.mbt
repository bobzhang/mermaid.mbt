// The renderer's own bookkeeping of where things are (`bounds` in
// sequenceRenderer.ts). The size of the diagram comes from here, not from
// measuring what was drawn.

///|
/// A horizontal divider inside a block: `else`, `and`, `option`.
priv struct Section {
  y : Double
}

///|
/// A block being laid out: a loop, an alternative, a highlighted rect...
/// The edges start out undefined and grow around what the block holds.
priv struct LoopModel {
  mut startx : Double?
  mut starty : Double?
  mut stopx : Double?
  mut stopy : Double?
  title : String?
  fill : String?
  sections : Array[Section]
  section_titles : Array[Message]
}

///|
/// An activation bar that has started and not yet ended.
priv struct Activation {
  startx : Double?
  mut starty : Double?
  stopx : Double?
  mut stopy : Double?
  actor : String?
  /// The group the bar is drawn into, placed where the activation began.
  anchored : @dom.Element?
}

///|
priv struct Bounds {
  mut startx : Double?
  mut stopx : Double?
  mut starty : Double?
  mut stopy : Double?
  mut vertical_pos : Double
  /// Open blocks, innermost last.
  sequence_items : Array[LoopModel]
  activations : Array[Activation]
  /// Participant boxes to draw, in the order they close.
  boxes : Array[Box]
  box_margin : Double
}

///|
fn Bounds::new(box_margin : Double) -> Bounds {
  {
    startx: None,
    stopx: None,
    starty: None,
    stopy: None,
    vertical_pos: 0.0,
    sequence_items: [],
    activations: [],
    boxes: [],
    box_margin,
  }
}

///|
/// `Math.min`, which is `NaN` as soon as an argument is.
fn js_min(a : Double, b : Double) -> Double {
  if a != a || b != b {
    @double.not_a_number
  } else if a < b {
    a
  } else {
    b
  }
}

///|
fn js_max(a : Double, b : Double) -> Double {
  if a != a || b != b {
    @double.not_a_number
  } else if a > b {
    a
  } else {
    b
  }
}

///|
/// mermaid's `getMax`: the largest of the values that are numbers.
fn get_max(values : Array[Double]) -> Double {
  let mut result = @double.neg_infinity
  for value in values {
    if value == value && value > result {
      result = value
    }
  }
  result
}

///|
fn get_min(values : Array[Double]) -> Double {
  let mut result = @double.infinity
  for value in values {
    if value == value && value < result {
      result = value
    }
  }
  result
}

///|
/// `updateVal`: an undefined edge takes the value, a defined one is
/// combined with it.
fn update(
  edge : Double?,
  value : Double,
  combine : (Double, Double) -> Double,
) -> Double? {
  match edge {
    None => Some(value)
    Some(old) => Some(combine(value, old))
  }
}

///|
/// Grow the open blocks, the open activations and the diagram around a
/// rectangle. Outer blocks keep one more margin than the blocks inside
/// them.
fn Bounds::update_bounds(
  self : Bounds,
  startx : Double,
  starty : Double,
  stopx : Double,
  stopy : Double,
) -> Unit {
  let mut count = 0
  let depth = self.sequence_items.length()
  for item in self.sequence_items {
    count += 1
    let margin = (depth - count + 1).to_double() * self.box_margin
    item.starty = update(item.starty, starty - margin, js_min)
    item.stopy = update(item.stopy, stopy + margin, js_max)
    self.startx = update(self.startx, startx - margin, js_min)
    self.stopx = update(self.stopx, stopx + margin, js_max)
    item.startx = update(item.startx, startx - margin, js_min)
    item.stopx = update(item.stopx, stopx + margin, js_max)
    self.starty = update(self.starty, starty - margin, js_min)
    self.stopy = update(self.stopy, stopy + margin, js_max)
  }
  // Activations go on counting where the blocks stopped, and only widen
  // the diagram.
  for item in self.activations {
    count += 1
    let margin = (depth - count + 1).to_double() * self.box_margin
    item.starty = update(item.starty, starty - margin, js_min)
    item.stopy = update(item.stopy, stopy + margin, js_max)
    self.startx = update(self.startx, startx - margin, js_min)
    self.stopx = update(self.stopx, stopx + margin, js_max)
  }
}

///|
/// Make room for a rectangle given by two corners, in any order.
fn Bounds::insert(
  self : Bounds,
  startx : Double,
  starty : Double,
  stopx : Double,
  stopy : Double,
) -> Unit {
  let left = get_min([startx, stopx])
  let right = get_max([startx, stopx])
  let top = get_min([starty, stopy])
  let bottom = get_max([starty, stopy])
  self.startx = update(self.startx, left, js_min)
  self.starty = update(self.starty, top, js_min)
  self.stopx = update(self.stopx, right, js_max)
  self.stopy = update(self.stopy, bottom, js_max)
  self.update_bounds(left, top, right, bottom)
}

///|
/// Move down, taking the diagram's lower edge along.
fn Bounds::bump_vertical_pos(self : Bounds, bump : Double) -> Unit {
  self.vertical_pos = self.vertical_pos + bump
  self.stopy = Some(
    get_max([self.stopy.unwrap_or(@double.not_a_number), self.vertical_pos]),
  )
}

///|
/// Open a block at the current height.
fn Bounds::new_loop(self : Bounds, title? : String, fill? : String) -> Unit {
  self.sequence_items.push({
    startx: None,
    starty: Some(self.vertical_pos),
    stopx: None,
    stopy: None,
    title,
    fill,
    sections: [],
    section_titles: [],
  })
}

///|
/// Start a further section of the innermost block.
fn Bounds::add_section_to_loop(self : Bounds, message : Message) -> Unit {
  guard self.sequence_items.last() is Some(item) else { return }
  item.sections.push({ y: self.vertical_pos, })
  item.section_titles.push(message)
}

///|
/// The open activations of a participant, oldest first.
fn Bounds::actor_activations(
  self : Bounds,
  actor : String?,
) -> Array[Activation] {
  self.activations.filter(activation => activation.actor == actor)
}

///|
/// Close the most recent activation of a participant and hand it over.
fn Bounds::end_activation(self : Bounds, actor : String?) -> Activation? {
  let mut index = -1
  for i, activation in self.activations {
    if activation.actor == actor {
      index = i
    }
  }
  // `splice(-1, 1)` takes the last one, whoever it belongs to.
  if index < 0 {
    self.activations.pop()
  } else {
    Some(self.activations.remove(index))
  }
}
