///|
const PI : Double = 3.141592653589793

///|
/// A point of a curve.
priv struct Point {
  x : Double
  y : Double
}

///|
/// Where a value falls between the centre and the rim: values outside
/// `min_value..max_value` are clipped.
fn relative_radius(
  value : Double,
  min_value : Double,
  max_value : Double,
  radius : Double,
) -> Double {
  let clipped = if value > min_value { value } else { min_value }
  let clipped = if clipped < max_value { clipped } else { max_value }
  radius * (clipped - min_value) / (max_value - min_value)
}

///|
/// A closed Catmull-Rom spline through the points, as cubic Bézier
/// segments.
fn closed_round_curve(points : Array[Point], tension : Double) -> String {
  let n = @dom.number
  let count = points.length()
  let out = StringBuilder()
  out.write_string("M\{n(points[0].x)},\{n(points[0].y)}")
  for i in 0..<count {
    let p0 = points[(i - 1 + count) % count]
    let p1 = points[i]
    let p2 = points[(i + 1) % count]
    let p3 = points[(i + 2) % count]
    let cp1 = {
      x: p1.x + (p2.x - p0.x) * tension,
      y: p1.y + (p2.y - p0.y) * tension,
    }
    let cp2 = {
      x: p2.x - (p3.x - p1.x) * tension,
      y: p2.y - (p3.y - p1.y) * tension,
    }
    out.write_string(
      " C\{n(cp1.x)},\{n(cp1.y)} \{n(cp2.x)},\{n(cp2.y)} \{n(p2.x)},\{n(p2.y)}",
    )
  }
  out.write_string(" Z")
  out.to_string()
}

///|
/// Draw the radar chart into the context's `<svg>` element.
pub fn draw(radar : Radar, context : @diagram.Context) -> Unit {
  let n = @dom.number
  let config = context.config
  let svg = context.svg
  let setting = (name : String, default : Double) => {
    config.number("radar." + name).unwrap_or(default)
  }
  let width = setting("width", 600.0)
  let height = setting("height", 600.0)
  let margin_top = setting("marginTop", 50.0)
  let margin_right = setting("marginRight", 50.0)
  let margin_bottom = setting("marginBottom", 50.0)
  let margin_left = setting("marginLeft", 50.0)
  let axis_scale_factor = setting("axisScaleFactor", 1.0)
  let axis_label_factor = setting("axisLabelFactor", 1.05)
  let curve_tension = setting("curveTension", 0.17)
  // `drawFrame`: the size, and a group centred on the chart.
  let total_width = width + margin_left + margin_right
  let total_height = height + margin_top + margin_bottom
  @diagram.configure_svg_size(
    svg,
    total_height,
    total_width,
    config.flag("radar.useMaxWidth"),
  )
  svg
  .attr("viewBox", "0 0 \{n(total_width)} \{n(total_height)}")
  .attr("overflow", "visible")
  |> ignore
  let g = svg
    .append("g")
    .attr(
      "transform",
      "translate(\{n(margin_left + width / 2.0)}, \{n(margin_top + height / 2.0)})",
    )
  // The rim stands for the `max` option, or else for the largest entry.
  let max_value = match radar.max {
    Some(max) => max
    None => {
      let mut largest = @double.neg_infinity
      for curve in radar.curves {
        for entry in curve.entries {
          if entry > largest {
            largest = entry
          }
        }
      }
      largest
    }
  }
  let min_value = radar.min
  let radius = (if width < height { width } else { height }) / 2.0
  let axis_count = radar.axes.length().to_double()
  // `drawGraticule`
  let mut tick = 0.0
  while tick < radar.ticks {
    let r = radius * (tick + 1.0) / radar.ticks
    match radar.graticule {
      Circle =>
        g.append("circle").attr("r", n(r)).attr("class", "radarGraticule")
        |> ignore
      Polygon => {
        let points = []
        for j in 0..<radar.axes.length() {
          let angle = 2.0 * j.to_double() * PI / axis_count - PI / 2.0
          let x = r * @jsmath.cos(angle)
          let y = r * @jsmath.sin(angle)
          points.push("\{n(x)},\{n(y)}")
        }
        g
        .append("polygon")
        .attr("points", points.join(" "))
        .attr("class", "radarGraticule")
        |> ignore
      }
    }
    tick += 1.0
  }
  // `drawAxes`
  for i, axis in radar.axes {
    let angle = 2.0 * i.to_double() * PI / axis_count - PI / 2.0
    let cos_a = @jsmath.cos(angle)
    let sin_a = @jsmath.sin(angle)
    g
    .append("line")
    .attr("x1", "0")
    .attr("y1", "0")
    .attr("x2", n(radius * axis_scale_factor * cos_a))
    .attr("y2", n(radius * axis_scale_factor * sin_a))
    .attr("class", "radarAxisLine")
    |> ignore
    // Labels extend away from the centre.
    let text_anchor = if cos_a > 0.01 {
      "start"
    } else if cos_a < -0.01 {
      "end"
    } else {
      "middle"
    }
    let dominant_baseline = if sin_a > 0.01 {
      "hanging"
    } else if sin_a < -0.01 {
      "auto"
    } else {
      "central"
    }
    let label_pad = 4.0
    g
    .append("text")
    .text(axis.label)
    .attr("x", n(radius * axis_label_factor * cos_a + label_pad * cos_a))
    .attr("y", n(radius * axis_label_factor * sin_a + label_pad * sin_a))
    .attr("text-anchor", text_anchor)
    .attr("dominant-baseline", dominant_baseline)
    .attr("class", "radarAxisLabel")
    |> ignore
  }
  // `drawCurves`: a curve without an entry for each axis is left out.
  for index, curve in radar.curves {
    if curve.entries.length() != radar.axes.length() {
      continue
    }
    let points = []
    for i, entry in curve.entries {
      let angle = 2.0 * PI * i.to_double() / axis_count - PI / 2.0
      let r = relative_radius(entry, min_value, max_value, radius)
      points.push({ x: r * @jsmath.cos(angle), y: r * @jsmath.sin(angle), })
    }
    match radar.graticule {
      Circle =>
        g
        .append("path")
        .attr("d", closed_round_curve(points, curve_tension))
        .attr("class", "radarCurve-\{index}")
        |> ignore
      Polygon =>
        g
        .append("polygon")
        .attr("points", points.map(p => "\{n(p.x)},\{n(p.y)}").join(" "))
        .attr("class", "radarCurve-\{index}")
        |> ignore
    }
  }
  // `drawLegend`, in the top right corner.
  if radar.show_legend {
    let legend_x = (width / 2.0 + margin_right) * 3.0 / 4.0
    let legend_y = -(height / 2.0 + margin_top) * 3.0 / 4.0
    let line_height = 20.0
    for index, curve in radar.curves {
      let item = g
        .append("g")
        .attr(
          "transform",
          "translate(\{n(legend_x)}, \{n(legend_y + index.to_double() * line_height)})",
        )
      item
      .append("rect")
      .attr("width", "12")
      .attr("height", "12")
      .attr("class", "radarLegendBox-\{index}")
      |> ignore
      item
      .append("text")
      .attr("x", "16")
      .attr("y", "0")
      .attr("class", "radarLegendText")
      .text(curve.label)
      |> ignore
    }
  }
  g
  .append("text")
  .attr("class", "radarTitle")
  .text(radar.title)
  .attr("x", "0")
  .attr("y", n(-height / 2.0 - margin_top))
  |> ignore
}
