// The grid elements are placed on: upstream's `Bounds`.

///|
/// The box drawn so far inside one boundary, and the row being filled.
priv struct Bounds {
  // The whole content.
  mut startx : Double
  mut stopx : Double
  mut starty : Double
  mut stopy : Double
  /// Shapes do not start or end right of this.
  mut width_limit : Double
  // The row being filled.
  mut next_startx : Double
  mut next_stopx : Double
  mut next_starty : Double
  mut next_stopy : Double
  /// How many shapes the row holds.
  mut count : Int32
}

///|
fn Bounds::new() -> Bounds {
  {
    startx: 0.0,
    stopx: 0.0,
    starty: 0.0,
    stopy: 0.0,
    width_limit: 0.0,
    next_startx: 0.0,
    next_stopx: 0.0,
    next_starty: 0.0,
    next_stopy: 0.0,
    count: 0,
  }
}

///|
/// Start over from a box, which is also the row.
fn Bounds::set_data(
  self : Bounds,
  startx : Double,
  stopx : Double,
  starty : Double,
  stopy : Double,
) -> Unit {
  self.startx = startx
  self.next_startx = startx
  self.stopx = stopx
  self.next_stopx = stopx
  self.starty = starty
  self.next_starty = starty
  self.stopy = stopy
  self.next_stopy = stopy
}

///|
/// Place a shape of the given size: next in the row, or first in a new
/// row when the row is full or the shape would cross the width limit.
/// Returns the top left corner.
fn Bounds::insert(
  self : Bounds,
  width : Double,
  height : Double,
  margin : Double,
  conf : Conf,
  shapes_in_row : Int32,
) -> (Double, Double) {
  self.count += 1
  let mut startx = if self.next_startx == self.next_stopx {
    self.next_stopx + margin
  } else {
    self.next_stopx + margin * 2.0
  }
  let mut stopx = startx + width
  let mut starty = self.next_starty + margin * 2.0
  let mut stopy = starty + height
  if startx >= self.width_limit ||
    stopx >= self.width_limit ||
    self.count > shapes_in_row {
    startx = self.next_startx + margin + conf.next_line_padding_x
    starty = self.next_stopy + margin * 2.0
    stopx = startx + width
    self.next_stopx = stopx
    self.next_starty = self.next_stopy
    stopy = starty + height
    self.next_stopy = stopy
    self.count = 1
  }
  self.startx = startx.min(self.startx)
  self.starty = starty.min(self.starty)
  self.stopx = stopx.max(self.stopx)
  self.stopy = stopy.max(self.stopy)
  self.next_startx = startx.min(self.next_startx)
  self.next_starty = starty.min(self.next_starty)
  self.next_stopx = stopx.max(self.next_stopx)
  self.next_stopy = stopy.max(self.next_stopy)
  (startx, starty)
}

///|
fn Bounds::bump_last_margin(self : Bounds, margin : Double) -> Unit {
  self.stopx += margin
  self.stopy += margin
}
