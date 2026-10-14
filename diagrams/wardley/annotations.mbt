///|
/// Text as SVG lays it out without `xml:space="preserve"`: line breaks
/// and tabs are spaces, runs of spaces collapse, and the spaces at both
/// ends go.
fn collapse_spaces(text : String) -> String {
  let out = StringBuilder()
  let mut pending = false
  for c in text {
    if c is (' ' | '\t' | '\n' | '\r') {
      pending = true
      continue
    }
    if pending && !out.is_empty() {
      out.write_char(' ')
    }
    pending = false
    out.write_char(c)
  }
  out.to_string()
}

///|
/// The numbered marks on the map, and the box that explains them when
/// the map places one.
fn Scene::draw_annotations(
  self : Scene,
  context : @diagram.Context,
) -> Unit raise WardleyError {
  let n = @dom.number
  let { map, colors, width, height, .. } = self
  if map.annotations.length() == 0 {
    return
  }
  let group = self.root.append("g").attr("class", "wardley-annotations")
  for annotation in map.annotations {
    let x = n(self.project_x(annotation.x))
    let y = n(self.project_y(annotation.y))
    let mark = group.append("g").attr("class", "wardley-annotation")
    mark
    .append("circle")
    .attr("cx", x)
    .attr("cy", y)
    .attr("r", "10")
    .attr("fill", "white")
    .attr("stroke", colors.axis)
    .attr("stroke-width", "1.5")
    |> ignore
    mark
    .append("text")
    .attr("x", x)
    .attr("y", y)
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "central")
    .attr("font-size", "10")
    .attr("fill", colors.axis_text)
    .attr("font-weight", "bold")
    .text(n(annotation.number))
    |> ignore
  }
  guard map.annotations_box is Some((box_x, box_y)) else { return }
  let mut box_x = self.project_x(box_x)
  let mut box_y = self.project_y(box_y)
  let padding = 10.0
  let line_height = 16.0
  let font_size = 11.0
  let box = group.append("g").attr("class", "wardley-annotations-box")
  // The annotations that have a text, by number; those with the same
  // number stay in the order they were written.
  let sorted : Array[Annotation] = []
  for annotation in map.annotations {
    guard annotation.text != "" else { continue }
    let mut at = sorted.length()
    while at > 0 && sorted[at - 1].number > annotation.number {
      at -= 1
    }
    sorted.insert(at, annotation)
  }
  guard sorted.length() > 0 else { return }
  // The box is as wide as its longest line, measured in the page as it
  // is displayed at this point: the stylesheet is gone, so the text is
  // in the browser's standard font, and the map is scaled to the page.
  let scale = context.view_box_scale(
    width,
    height,
    max_width=width,
    fixed=!self.settings.use_max_width,
  )
  if !(scale > 0.0) || scale.is_inf() {
    raise Unsupported("the annotations of a Wardley map without a size")
  }
  let font = @font.Stack::page_default()
  let lines = sorted.map(annotation => {
    "\{n(annotation.number)}. \{annotation.text}"
  })
  let mut max_width = 0.0
  let mut max_height = 0.0
  for index, line in lines {
    let text = collapse_spaces(line)
    if !font.covers(text) {
      raise Unsupported(
        "an annotation with characters outside the embedded fonts: \{line}",
      )
    }
    max_width = js_max(max_width, font.svg_text_length(text, font_size, scale~))
    let measured = font.svg_text_box(
      text,
      font_size,
      x=box_x + padding,
      y=box_y + padding + (index + 1).to_double() * line_height,
      baseline=@font.Baseline::Middle,
      scale~,
    )
    max_height = js_max(max_height, measured.height)
  }
  // 105 more than the text needs, "for safety".
  let box_width = max_width + padding * 2.0 + 105.0
  let box_height = sorted.length().to_double() * line_height +
    padding * 2.0 +
    max_height / 2.0
  // The box stays inside the map.
  let map_padding = self.settings.padding
  box_x = js_max(map_padding, js_min(box_x, width - map_padding - box_width))
  box_y = js_max(map_padding, js_min(box_y, height - map_padding - box_height))
  box
  .append("rect")
  .attr("x", n(box_x))
  .attr("y", n(box_y))
  .attr("width", n(box_width))
  .attr("height", n(box_height))
  .attr("fill", "white")
  .attr("stroke", colors.axis)
  .attr("stroke-width", "1.5")
  .attr("rx", "4")
  .attr("ry", "4")
  |> ignore
  for index, line in lines {
    box
    .append("text")
    .attr("x", n(box_x + padding))
    .attr("y", n(box_y + padding + (index + 1).to_double() * line_height))
    .attr("font-size", n(font_size))
    .attr("fill", colors.axis_text)
    .attr("text-anchor", "start")
    .attr("dominant-baseline", "middle")
    .text(line)
    |> ignore
  }
}

///|
/// The notes: bold text at a place of the map.
fn Scene::draw_notes(self : Scene) -> Unit {
  let n = @dom.number
  if self.map.notes.length() == 0 {
    return
  }
  let group = self.root.append("g").attr("class", "wardley-notes")
  for note in self.map.notes {
    group
    .append("text")
    .attr("x", n(self.project_x(note.x)))
    .attr("y", n(self.project_y(note.y)))
    .attr("text-anchor", "start")
    .attr("font-size", "11")
    .attr("fill", self.colors.axis_text)
    .attr("font-weight", "bold")
    .text(note.text)
    |> ignore
  }
}

///|
/// The accelerators, block arrows pointing right, and the deaccelerators,
/// pointing left, each with its name underneath.
fn Scene::draw_accelerators(self : Scene) -> Unit {
  let n = @dom.number
  let arrow_width = 60.0
  let arrow_height = 30.0
  let head_width = 20.0
  // The path is a template literal upstream, line breaks and indentation
  // included.
  let path = (points : Array[(Double, Double)]) => {
    let out = StringBuilder()
    for index, point in points {
      out.write_string(if index == 0 { "M " } else { "\n        L " })
      out.write_string("\{n(point.0)} \{n(point.1)}")
    }
    out.write_string("\n        Z")
    out.to_string()
  }
  let draw = (
    class_name : String,
    items : Array[Placed],
    outline : (Double, Double) -> Array[(Double, Double)],
  ) => {
    if items.length() == 0 {
      return
    }
    let group = self.root.append("g").attr("class", class_name)
    for item in items {
      let x = self.project_x(item.x)
      let y = self.project_y(item.y)
      group
      .append("path")
      .attr("d", path(outline(x, y)))
      .attr("fill", "white")
      .attr("stroke", self.colors.component_stroke)
      .attr("stroke-width", "1")
      |> ignore
      group
      .append("text")
      .attr("x", n(x + arrow_width / 2.0))
      .attr("y", n(y + arrow_height / 2.0 + 15.0))
      .attr("text-anchor", "middle")
      .attr("font-size", "10")
      .attr("fill", self.colors.axis_text)
      .attr("font-weight", "bold")
      .text(item.text)
      |> ignore
    }
  }
  draw("wardley-accelerators", self.map.accelerators, (x, y) => {
    [
      (x, y - arrow_height / 2.0),
      (x + arrow_width - head_width, y - arrow_height / 2.0),
      (x + arrow_width - head_width, y - arrow_height / 2.0 - 8.0),
      (x + arrow_width, y),
      (x + arrow_width - head_width, y + arrow_height / 2.0 + 8.0),
      (x + arrow_width - head_width, y + arrow_height / 2.0),
      (x, y + arrow_height / 2.0),
    ]
  })
  draw("wardley-deaccelerators", self.map.deaccelerators, (x, y) => {
    [
      (x + arrow_width, y - arrow_height / 2.0),
      (x + head_width, y - arrow_height / 2.0),
      (x + head_width, y - arrow_height / 2.0 - 8.0),
      (x, y),
      (x + head_width, y + arrow_height / 2.0 + 8.0),
      (x + head_width, y + arrow_height / 2.0),
      (x + arrow_width, y + arrow_height / 2.0),
    ]
  })
}
