///|
/// The class naming how a commit is drawn: `getCommitClassType`.
fn type_class(kind : CommitType) -> String {
  match kind {
    Normal => "commit-normal"
    Reverse => "commit-reverse"
    Highlight => "commit-highlight"
    Merge => "commit-merge"
    CherryPick => "commit-cherry-pick"
  }
}

///|
/// `drawCommitBullet`
fn Renderer::draw_bullet(
  self : Renderer,
  bullets : @dom.Element,
  commit : Commit,
  position : CommitPosition,
) -> Unit {
  let redux = is_redux_theme(self.theme_name)
  let symbol = commit.custom_type.unwrap_or(commit.kind)
  let type_class = type_class(symbol)
  let branch_index = match self.branch_pos.get(commit.branch) {
    Some((_, index)) => index
    None => 0
  }
  let color = color_index(
    branch_index,
    THEME_COLOR_LIMIT,
    is_color_theme(self.theme_name),
  )
  let pick = (redux_value : Double, classic : Double) => {
    if redux {
      redux_value
    } else {
      classic
    }
  }
  let { x, y, .. } = position
  match symbol {
    Highlight => {
      bullets
      .append("rect")
      .attr_number("x", x - 10.0 + pick(3.0, 0.0))
      .attr_number("y", y - 10.0 + pick(3.0, 0.0))
      .attr_number("width", pick(14.0, 20.0))
      .attr_number("height", pick(14.0, 20.0))
      .attr(
        "class",
        "commit \{commit.id} commit-highlight\{color} \{type_class}-outer",
      )
      |> ignore
      bullets
      .append("rect")
      .attr_number("x", x - 6.0 + pick(2.0, 0.0))
      .attr_number("y", y - 6.0 + pick(2.0, 0.0))
      .attr_number("width", pick(8.0, 12.0))
      .attr_number("height", pick(8.0, 12.0))
      .attr("class", "commit \{commit.id} commit\{color} \{type_class}-inner")
      |> ignore
    }
    CherryPick => {
      let class_name = "commit \{commit.id} \{type_class}"
      let ink = if is_dark_theme(self.theme_name) { "#000000" } else { "#fff" }
      bullets
      .append("circle")
      .attr_number("cx", x)
      .attr_number("cy", y)
      .attr_number("r", pick(7.0, 10.0))
      .attr("class", class_name)
      |> ignore
      for dx in [-3.0, 3.0] {
        bullets
        .append("circle")
        .attr_number("cx", x + dx)
        .attr_number("cy", y + 2.0)
        .attr_number("r", pick(2.5, 2.75))
        .attr("fill", ink)
        .attr("class", class_name)
        |> ignore
      }
      for dx in [3.0, -3.0] {
        bullets
        .append("line")
        .attr_number("x1", x + dx)
        .attr_number("y1", y + 1.0)
        .attr_number("x2", x)
        .attr_number("y2", y - 5.0)
        .attr("stroke", ink)
        .attr("class", class_name)
        |> ignore
      }
    }
    _ => {
      bullets
      .append("circle")
      .attr_number("cx", x)
      .attr_number("cy", y)
      .attr_number("r", pick(7.0, 10.0))
      .attr("class", "commit \{commit.id} commit\{color}")
      |> ignore
      let marked = "commit \{type_class} \{commit.id} commit\{color}"
      if symbol == Merge {
        bullets
        .append("circle")
        .attr_number("cx", x)
        .attr_number("cy", y)
        .attr_number("r", pick(5.0, 6.0))
        .attr("class", marked)
        |> ignore
      }
      if symbol == Reverse {
        let n = @dom.number
        let c = pick(4.0, 5.0)
        bullets
        .append("path")
        .attr(
          "d",
          "M \{n(x - c)},\{n(y - c)}L\{n(x + c)},\{n(y + c)}M\{n(x - c)},\{n(y + c)}L\{n(x + c)},\{n(y - c)}",
        )
        .attr("class", marked)
        |> ignore
      }
    }
  }
}
