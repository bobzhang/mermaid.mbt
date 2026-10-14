// The grid layout of a block diagram: mermaid's `layout.ts`. The
// arithmetic is upstream's, operation for operation.

///|
/// The column and row of the block at `position` in a grid of `columns`
/// columns: mermaid's `calculateBlockPosition`.
fn block_position(
  columns : Double,
  position : Double,
) -> (Double, Double) raise BlockError {
  if columns == 0.0 || columns != columns.floor() || columns.is_inf() {
    raise BlockError("Columns must be an integer !== 0.")
  }
  if !(position >= 0.0) || position != position.floor() || position.is_inf() {
    raise BlockError(
      "Position must be a non-negative integer.\{@dom.number(position)}",
    )
  }
  if columns < 0.0 {
    // Auto columns: one row.
    return (position, 0.0)
  }
  if columns == 1.0 {
    return (0.0, position)
  }
  (position % columns, (position / columns).floor())
}

///|
/// `block.size.width`, with 0 for a block without a size.
fn Block::width(self : Block) -> Double {
  match self.size {
    Some(size) => size.width
    None => 0.0
  }
}

///|
/// The widest child, per column it spans, and the tallest; spaces do not
/// count.
fn max_child_size(block : Block) -> (Double, Double) {
  let mut max_width = 0.0
  let mut max_height = 0.0
  for child in block.children {
    let (width, height) = match child.size {
      Some(size) => (size.width, size.height)
      None => (0.0, 0.0)
    }
    if child.type_ == Some("space") {
      continue
    }
    let normalized = width / child.width_in_columns.unwrap_or(1.0)
    if normalized > max_width {
      max_width = normalized
    }
    if height > max_height {
      max_height = height
    }
  }
  (max_width, max_height)
}

///|
/// JavaScript's truthiness of a number.
fn truthy(value : Double) -> Bool {
  value != 0.0 && !value.is_nan()
}

///|
/// Give every block of a level the size of the largest and size the
/// level around them: mermaid's `setBlockSizes`.
fn set_block_sizes(
  block : Block,
  sibling_width : Double,
  sibling_height : Double,
  padding : Double,
) -> Unit {
  if !truthy(block.width()) {
    block.size = Some({
      width: sibling_width,
      height: sibling_height,
      x: 0.0,
      y: 0.0,
    })
  }
  guard block.children.length() > 0 else { return }
  for child in block.children {
    set_block_sizes(child, 0.0, 0.0, padding)
  }
  let (max_width, max_height) = max_child_size(block)
  for child in block.children {
    if child.size is Some(size) {
      let span = child.width_in_columns.unwrap_or(1.0)
      size.width = max_width * span + padding * (span - 1.0)
      size.height = max_height
      size.x = 0.0
      size.y = 0.0
    }
  }
  for child in block.children {
    set_block_sizes(child, max_width, max_height, padding)
  }
  let columns = block.columns.unwrap_or(-1.0)
  let mut num_items = 0.0
  for child in block.children {
    num_items += child.width_in_columns.unwrap_or(1.0)
  }
  // The width and height in number of blocks.
  let mut x_size = block.children.length().to_double()
  if columns > 0.0 && columns < num_items {
    x_size = columns
  }
  let y_size = (num_items / x_size).ceil()
  let mut width = x_size * (max_width + padding) + padding
  let mut height = y_size * (max_height + padding) + padding
  if width < sibling_width {
    // Too small next to its siblings: take their size and spread it over
    // the children.
    width = sibling_width
    height = sibling_height
    let child_width = (sibling_width - x_size * padding - padding) / x_size
    let child_height = (sibling_height - y_size * padding - padding) / y_size
    for child in block.children {
      if child.size is Some(size) {
        size.width = child_width
        size.height = child_height
        size.x = 0.0
        size.y = 0.0
      }
    }
  }
  let own_width = if truthy(block.width()) { block.width() } else { 0.0 }
  if width < own_width {
    width = own_width
    // Grow the children to fit.
    let count = block.children.length().to_double()
    let num = if columns > 0.0 { count.min(columns) } else { count }
    if num > 0.0 {
      let child_width = (width - num * padding - padding) / num
      for child in block.children {
        if child.size is Some(size) {
          size.width = child_width
        }
      }
    }
  }
  block.size = Some({ width, height, x: 0.0, y: 0.0, })
}

///|
/// Where the first block of a row starts.
fn row_start(block : Block, padding : Double) -> Double {
  match block.size {
    Some(size) if truthy(size.x) => {
      let half = -size.width / 2.0
      size.x + (if truthy(half) { half } else { 0.0 })
    }
    _ => -padding
  }
}

///|
/// Place the children of `block` in its grid, row by row: mermaid's
/// `layoutBlocks`.
fn layout_blocks(block : Block, padding : Double) -> Unit raise BlockError {
  let columns = block.columns.unwrap_or(-1.0)
  guard block.children.length() > 0 else { return }
  // The tallest block of every row, so that rows of different heights
  // stack.
  let row_heights : Map[Double, Double] = Map([])
  let mut col_pos = 0.0
  for child in block.children {
    guard child.size is Some(size) else { continue }
    let (_, py) = block_position(columns, col_pos)
    if size.height > row_heights.get(py).unwrap_or(0.0) {
      row_heights[py] = size.height
    }
    let mut filled = child.width_in_columns.unwrap_or(1.0)
    if columns > 0.0 {
      filled = js_min(filled, columns - col_pos % columns)
    }
    col_pos += filled
  }
  let row_offsets : Map[Double, Double] = Map([])
  let rows = row_heights.keys().collect()
  rows.sort_by((a, b) => a.compare(b))
  let mut offset = 0.0
  for row in rows {
    row_offsets[row] = offset
    offset += row_heights.get(row).unwrap_or(0.0) + padding
  }
  let mut column_pos = 0.0
  let mut starting_x = row_start(block, padding)
  let mut row_pos = 0.0
  for child in block.children {
    guard child.size is Some(size) else { continue }
    let width = size.width
    let height = size.height
    let (_, py) = block_position(columns, column_pos)
    if py != row_pos {
      row_pos = py
      starting_x = row_start(block, padding)
    }
    if block.size is Some(parent) {
      let half_width = width / 2.0
      size.x = starting_x + padding + half_width
      starting_x = size.x + half_width
      let row_offset = row_offsets.get(py).unwrap_or(0.0)
      let row_height = row_heights.get(py).unwrap_or(height)
      size.y = parent.y -
        parent.height / 2.0 +
        row_offset +
        row_height / 2.0 +
        padding
    }
    layout_blocks(child, padding)
    let mut filled = child.width_in_columns.unwrap_or(1.0)
    if columns > 0.0 {
      // Overflowing lines do not affect later lines.
      filled = js_min(filled, columns - column_pos % columns)
    }
    column_pos += filled
  }
}

///|
/// `Math.min`, which is NaN when either argument is.
fn js_min(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else {
    a.min(b)
  }
}

///|
/// The box around every block: left, top, width, height.
priv struct Bounds {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
/// Extend the extremes `(min_x, min_y, max_x, max_y)` by `block` and what
/// is inside it: mermaid's `findBounds`.
fn find_bounds(
  block : Block,
  extremes : (Double, Double, Double, Double),
) -> (Double, Double, Double, Double) {
  let mut min_x = extremes.0
  let mut min_y = extremes.1
  let mut max_x = extremes.2
  let mut max_y = extremes.3
  if block.size is Some(size) && block.id != Some("root") {
    if size.x - size.width / 2.0 < min_x {
      min_x = size.x - size.width / 2.0
    }
    if size.y - size.height / 2.0 < min_y {
      min_y = size.y - size.height / 2.0
    }
    if size.x + size.width / 2.0 > max_x {
      max_x = size.x + size.width / 2.0
    }
    if size.y + size.height / 2.0 > max_y {
      max_y = size.y + size.height / 2.0
    }
  }
  let mut result = (min_x, min_y, max_x, max_y)
  for child in block.children {
    result = find_bounds(child, result)
  }
  result
}

///|
/// Size and place every block: mermaid's `layout`. Returns the box around
/// them all.
fn BlockDb::layout(self : BlockDb) -> Bounds raise BlockError {
  let padding = self.config.number("block.padding").unwrap_or(8.0)
  set_block_sizes(self.root, 0.0, 0.0, padding)
  layout_blocks(self.root, padding)
  let (min_x, min_y, max_x, max_y) = find_bounds(
    self.root,
    (0.0, 0.0, 0.0, 0.0),
  )
  { x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y, }
}
