///|
/// `drawBranches`: for every branch a dashed line along its commits and
/// its name in a colored box.
fn Renderer::draw_branches(
  self : Renderer,
  svg : @dom.Element,
  branches : Array[String],
) -> Unit raise GitError {
  let n = @dom.number
  let theme = self.config.theme()
  let neo_look = self.config.text("look") == Some("neo")
  let redux = is_redux_theme(self.theme_name)
  let rotate = self.config.get("gitGraph.rotateCommitLabel") is True
  // The redux themes give branch names the weight of notes.
  let font = self.font(bold=redux && self.note_weight_is_bold())
  let limit = if redux {
    match theme.number("THEME_COLOR_LIMIT") {
      Some(limit) => limit.to_int()
      None => 0
    }
  } else {
    THEME_COLOR_LIMIT
  }
  let group = svg.append("g")
  for index, name in branches {
    let color = color_index(index, limit, is_color_theme(self.theme_name))
    let (pos, _) = self.branch(name)
    let spine_y = if self.vertical() {
      pos
    } else if redux {
      pos + REDUX_BRANCH_LABEL_PADDING_Y / 2.0 + 1.0
    } else {
      pos - 2.0
    }
    let line = group
      .append("line")
      .attr_number("x1", 0.0)
      .attr_number("y1", spine_y)
      .attr_number("x2", self.max_pos)
      .attr_number("y2", spine_y)
      .attr("class", "branch branch\{color}")
    if self.dir == "TB" {
      line
      .attr_number("y1", DEFAULT_POS)
      .attr_number("x1", pos)
      .attr_number("y2", self.max_pos)
      .attr_number("x2", pos)
      |> ignore
    } else if self.dir == "BT" {
      line
      .attr_number("y1", self.max_pos)
      .attr_number("x1", pos)
      .attr_number("y2", DEFAULT_POS)
      .attr_number("x2", pos)
      |> ignore
    }
    self.lanes.push(spine_y)
    let background = group.append("rect")
    let label = group
      .append("g")
      .attr("class", "branchLabel")
      .append("g")
      .attr("class", "label branch-label\{color}")
    let (text, box) = branch_label(name, font, self.font_size)
    label.append_child(text)
    let border_radius = if redux { 0.0 } else { 4.0 }
    let padding_x = if redux { 16.0 } else { 0.0 }
    let padding_y = if redux { REDUX_BRANCH_LABEL_PADDING_Y } else { 0.0 }
    let rotation = if rotate { 30.0 } else { 0.0 }
    if neo_look {
      background.attr("data-look", "neo") |> ignore
    }
    let shadow = if !neo_look {
      ""
    } else if redux {
      "filter:url(#\{self.id}-drop-shadow)"
    } else {
      "filter:\{theme.text("dropShadow")}"
    }
    background
    .attr("class", "branchLabelBkg label\{color}")
    .attr("style", shadow)
    .attr_number("rx", border_radius)
    .attr_number("ry", border_radius)
    .attr_number("x", -box.width - 4.0 - rotation)
    .attr_number("y", -box.height / 2.0 + 10.0)
    .attr_number("width", box.width + 18.0 + padding_x)
    .attr_number("height", box.height + 4.0 + padding_y)
    |> ignore
    label.attr(
      "transform",
      "translate(\{n(-box.width - 14.0 - rotation + padding_x / 2.0)}, \{n(spine_y - box.height / 2.0 - 2.0)})",
    )
    |> ignore
    let centered = n(pos - box.width / 2.0 - 5.0)
    if self.dir == "TB" {
      background
      .attr_number("x", pos - box.width / 2.0 - 10.0)
      .attr_number("y", 0.0)
      |> ignore
      label.attr("transform", "translate(\{centered}, 0)") |> ignore
      if redux {
        background.attr(
          "transform",
          "translate(\{n(-padding_x / 2.0 - 3.0)}, \{n(-padding_y - 10.0)})",
        )
        |> ignore
        label.attr(
          "transform",
          "translate(\{centered}, \{n(-padding_y * 2.0 + 7.0)})",
        )
        |> ignore
      }
    } else if self.dir == "BT" {
      background
      .attr_number("x", pos - box.width / 2.0 - 10.0)
      .attr_number("y", self.max_pos)
      |> ignore
      label.attr("transform", "translate(\{centered}, \{n(self.max_pos)})")
      |> ignore
      if redux {
        background.attr(
          "transform",
          "translate(\{n(-padding_x / 2.0 - 3.0)}, \{n(padding_y + 10.0)})",
        )
        |> ignore
        label.attr(
          "transform",
          "translate(\{centered}, \{n(self.max_pos + padding_y * 2.0 + 4.0)})",
        )
        |> ignore
      }
    } else {
      background.attr(
        "transform",
        "translate(-19, \{n(spine_y - 12.0 - padding_y / 2.0)})",
      )
      |> ignore
    }
  }
}
