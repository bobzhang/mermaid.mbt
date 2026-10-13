// Shapes and their SVG: rough.js's generator and `RoughSVG`.

///|
/// Keep the first move only, so that a fill is one closed outline.
fn merged_shape(ops : Array[Op]) -> Array[Op] {
  let out = []
  for i, op in ops {
    if i == 0 || !(op is Move(_, _)) {
      out.push(op)
    }
  }
  out
}

///|
fn ops_to_path(ops : Array[Op]) -> String {
  let n = @dom.number
  let out = StringBuilder()
  for op in ops {
    match op {
      Move(x, y) => out.write_string("M\{n(x)} \{n(y)} ")
      CurveTo(a, b, c, d, e, f) =>
        out.write_string("C\{n(a)} \{n(b)}, \{n(c)} \{n(d)}, \{n(e)} \{n(f)} ")
      LineTo(x, y) => out.write_string("L\{n(x)} \{n(y)} ")
    }
  }
  out.to_string().trim().to_owned()
}

///|
/// The `<g>` rough.js draws a shape as: one `<path>` per set.
fn draw(sets : Array[OpSet], o : Options, even_odd : Bool) -> @dom.Element {
  let group = @dom.Element::new("g")
  for set in sets {
    let path = group.append("path").attr("d", ops_to_path(set.ops))
    match set.kind {
      Stroke => {
        path
        .attr("stroke", o.stroke)
        .attr("stroke-width", o.stroke_width)
        .attr("fill", "none")
        |> ignore
        if o.stroke_line_dash is Some(dash) {
          path.attr(
            "stroke-dasharray",
            dash.map(@dom.number).join(" ").trim().to_owned(),
          )
          |> ignore
        }
      }
      FillPath => {
        path
        .attr("stroke", "none")
        .attr("stroke-width", "0")
        .attr("fill", o.fill)
        |> ignore
        if even_odd {
          path.attr("fill-rule", "evenodd") |> ignore
        }
      }
    }
  }
  group
}

///|
fn has_fill(o : Options) -> Bool {
  o.fill != ""
}

///|
fn has_stroke(o : Options) -> Bool {
  o.stroke != "none"
}

///|
/// Only plain fills are ported; the sketchy fill styles belong to the
/// hand-drawn look.
fn solid(o : Options) -> Bool {
  o.fill_style == "solid"
}

///|
/// Draw path data: `rough.svg(...).path(d, options)`.
pub fn path(d : String, options : Options) -> @dom.Element {
  let o = options.fresh()
  let sets = []
  if d == "" {
    return draw(sets, o, false)
  }
  let d = d.replace_all(old="\n", new=" ")
  let filled = has_fill(o) && o.fill != "transparent" && o.fill != "none"
  let polygons = points_on_path(d, (1.0 + o.roughness) / 2.0)
  let shape = svg_path(d, o)
  if filled && solid(o) {
    if polygons.length() == 1 {
      let fill_options = {
        ..o,
        disable_multi_stroke: true,
        roughness: if o.roughness != 0.0 {
          o.roughness + o.fill_shape_roughness_gain
        } else {
          0.0
        },
      }
      sets.push({
        kind: FillPath,
        ops: merged_shape(svg_path(d, fill_options)),
      })
    } else {
      sets.push({ kind: FillPath, ops: solid_fill_polygon(polygons, o), })
    }
  }
  if has_stroke(o) {
    sets.push({ kind: Stroke, ops: shape, })
  }
  draw(sets, o, false)
}

///|
/// Draw a rectangle: `rough.svg(...).rectangle(x, y, width, height)`.
pub fn rectangle(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  options : Options,
) -> @dom.Element {
  let o = options.fresh()
  let points = [
    (x, y),
    (x + width, y),
    (x + width, y + height),
    (x, y + height),
  ]
  let sets = []
  let outline = linear_path(points, true, o)
  if has_fill(o) && solid(o) {
    sets.push({ kind: FillPath, ops: solid_fill_polygon([points], o), })
  }
  if has_stroke(o) {
    sets.push({ kind: Stroke, ops: outline, })
  }
  draw(sets, o, false)
}

///|
/// Draw a closed polygon: `rough.svg(...).polygon(points)`.
pub fn polygon(
  points : Array[(Double, Double)],
  options : Options,
) -> @dom.Element {
  let o = options.fresh()
  let sets = []
  let outline = linear_path(points, true, o)
  if has_fill(o) && solid(o) {
    sets.push({ kind: FillPath, ops: solid_fill_polygon([points], o), })
  }
  if has_stroke(o) {
    sets.push({ kind: Stroke, ops: outline, })
  }
  draw(sets, o, true)
}

///|
/// Draw a line: `rough.svg(...).line(x1, y1, x2, y2)`.
pub fn line(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  options : Options,
) -> @dom.Element {
  let o = options.fresh()
  draw([{ kind: Stroke, ops: double_line(x1, y1, x2, y2, o), }], o, false)
}

///|
/// Draw an ellipse: `rough.svg(...).ellipse(x, y, width, height)`.
pub fn ellipse(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  options : Options,
) -> @dom.Element {
  let o = options.fresh()
  let sets = []
  let params = ellipse_params(width, height, o)
  let outline = ellipse_ops(x, y, o, params)
  if has_fill(o) && solid(o) {
    sets.push({ kind: FillPath, ops: ellipse_ops(x, y, o, params), })
  }
  if has_stroke(o) {
    sets.push({ kind: Stroke, ops: outline, })
  }
  draw(sets, o, false)
}

///|
/// Draw a circle: `rough.svg(...).circle(x, y, diameter)`.
pub fn circle(
  x : Double,
  y : Double,
  diameter : Double,
  options : Options,
) -> @dom.Element {
  ellipse(x, y, diameter, diameter, options)
}
