///|
/// `drawCommitLabel`: the commit id on a translucent background, under
/// the bullet and turned 45 degrees unless `rotateCommitLabel` is off.
fn Renderer::draw_label(
  self : Renderer,
  labels : @dom.Element,
  commit : Commit,
  position : CommitPosition,
  pos : Double,
) -> Unit {
  // Cherry-picks have no label, merges only one that was asked for.
  if commit.kind == CherryPick ||
    (commit.kind == Merge && !commit.custom_id) ||
    !self.setting("showCommitLabel") {
    return
  }
  let n = @dom.number
  let neo = is_neo_theme(self.theme_name) || is_redux_theme(self.theme_name)
  let font = self.font(bold=neo && self.note_weight_is_bold())
  let size = self.commit_label_size
  let wrapper = labels.append("g")
  let background = wrapper.append("rect").attr("class", "commit-label-bkg")
  let text = wrapper
    .append("text")
    .attr_number("x", pos)
    .attr_number("y", position.y + 25.0)
    .attr("class", "commit-label")
    .text(commit.id)
  let (width, height) = text_size(font, commit.id, size)
  background
  .attr_number("x", position.along - width / 2.0 - PY)
  .attr_number("y", position.y + 13.5)
  .attr_number("width", width + 2.0 * PY)
  .attr_number("height", height + 2.0 * PY)
  |> ignore
  let (text_x, text_y) = if self.vertical() {
    background
    .attr_number("x", position.x - (width + 4.0 * PX + 5.0))
    .attr_number("y", position.y - 12.0)
    |> ignore
    (position.x - (width + 4.0 * PX), position.y + height - 12.0)
  } else {
    (position.along - width / 2.0, position.y + 25.0)
  }
  text.attr_number("x", text_x).attr_number("y", text_y) |> ignore
  place_text(text, font, size)
  if self.setting("rotateCommitLabel") {
    if self.vertical() {
      let rotation = "rotate(-45, \{n(position.x)}, \{n(position.y)})"
      text.attr("transform", rotation) |> ignore
      background.attr("transform", rotation) |> ignore
    } else {
      let r_x = -7.5 - (width + 10.0) / 25.0 * 9.5
      let r_y = 10.0 + width / 25.0 * 8.5
      wrapper.attr(
        "transform",
        "translate(\{n(r_x)}, \{n(r_y)}) rotate(-45, \{n(pos)}, \{n(position.y)})",
      )
      |> ignore
    }
  }
}

///|
/// `drawCommitTags`: tags stacked above the bullet, the last one nearest
/// to it, all as wide as the widest.
fn Renderer::draw_tags(
  self : Renderer,
  labels : @dom.Element,
  commit : Commit,
  position : CommitPosition,
  pos : Double,
) -> Unit {
  if commit.tags.is_empty() {
    return
  }
  let n = @dom.number
  let font = self.font()
  let size = self.tag_label_size
  let mut y_offset = 0.0
  let mut max_width = 0.0
  let mut max_height = 0.0
  let elements = []
  // Reversed in place, as upstream does.
  commit.tags.rev_in_place()
  for value in commit.tags {
    let polygon = labels.append("polygon")
    let hole = labels.append("circle")
    let y = position.y - 16.0 - y_offset
    let tag = labels
      .append("text")
      .attr_number("y", y)
      .attr("class", "tag-label")
      .text(value)
    let (width, height) = text_size(font, value, size)
    max_width = if width > max_width { width } else { max_width }
    max_height = if height > max_height { height } else { max_height }
    let x = position.along - width / 2.0
    tag.attr_number("x", x) |> ignore
    place_text(tag, font, size)
    elements.push((tag, hole, polygon, y_offset))
    y_offset += 20.0
  }
  let along = position.along
  for element in elements {
    let (tag, hole, polygon, y_offset) = element
    let h2 = max_height / 2.0
    let ly = position.y - 19.2 - y_offset
    // The points are written as upstream's template literal lays them
    // out, line breaks and indentation included.
    let points = (indent : String, corners : Array[(Double, Double)]) => {
      corners.map(corner => "\n\{indent}\{n(corner.0)},\{n(corner.1)}")
    }
    let tail = pos - max_width / 2.0 - PX / 2.0
    let near = along - max_width / 2.0 - PX
    let far = along + max_width / 2.0 + PX
    let horizontal = points("      ", [
      (tail, ly + PY),
      (tail, ly - PY),
      (near, ly - h2 - PY),
      (far, ly - h2 - PY),
      (far, ly + h2 + PY),
      (near, ly + h2 + PY),
    ])
    // The first corner is followed by two spaces.
    horizontal[0] = horizontal[0] + "  "
    polygon.attr("class", "tag-label-bkg").attr("points", horizontal.join(""))
    |> ignore
    hole
    .attr_number("cy", ly)
    .attr_number("cx", pos - max_width / 2.0 + PX / 2.0)
    .attr_number("r", 1.5)
    .attr("class", "tag-hole")
    |> ignore
    if self.vertical() {
      let y_origin = pos + y_offset
      let x = position.x
      let far = x + LAYOUT_OFFSET + max_width + 4.0
      let rotation = "rotate(45, \{n(x)},\{n(pos)})"
      polygon
      .attr("class", "tag-label-bkg")
      .attr(
        "points",
        points("        ", [
          (x, y_origin + 2.0),
          (x, y_origin - 2.0),
          (x + LAYOUT_OFFSET, y_origin - h2 - 2.0),
          (far, y_origin - h2 - 2.0),
          (far, y_origin + h2 + 2.0),
          (x + LAYOUT_OFFSET, y_origin + h2 + 2.0),
        ]).join(""),
      )
      .attr("transform", "translate(12,12) \{rotation}")
      |> ignore
      hole
      .attr_number("cx", x + PX / 2.0)
      .attr_number("cy", y_origin)
      .attr("transform", "translate(12,12) \{rotation}")
      |> ignore
      tag
      .attr_number("x", x + 5.0)
      .attr_number("y", y_origin + 3.0)
      .attr("transform", "translate(14,14) \{rotation}")
      |> ignore
      place_text(tag, font, size)
    }
  }
}
