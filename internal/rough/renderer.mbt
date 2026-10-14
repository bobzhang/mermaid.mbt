// Turning geometry into drawing operations: rough.js's `renderer.ts`.

///|
/// One drawing operation.
priv enum Op {
  Move(Double, Double)
  LineTo(Double, Double)
  CurveTo(Double, Double, Double, Double, Double, Double)
}

///|
/// What a set of operations is painted as.
priv enum SetKind {
  Stroke
  FillPath
  /// The lines of a hachure fill.
  FillSketch
}

///|
priv struct OpSet {
  kind : SetKind
  ops : Array[Op]
}

///|
/// A straight line as a single cubic curve: rough.js's `_line`.
fn line_ops(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  o : Options,
  with_move : Bool,
  overlay : Bool,
) -> Array[Op] {
  let length_sq = (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)
  let length = length_sq.sqrt()
  let gain = if length < 200.0 {
    1.0
  } else if length > 500.0 {
    0.4
  } else {
    -0.0016668 * length + 1.233334
  }
  let mut offset = o.max_randomness_offset
  if offset * offset * 100.0 > length_sq {
    offset = length / 10.0
  }
  let half_offset = offset / 2.0
  let diverge_point = 0.2 + 0.2 * o.random()
  let mid_x = o.bowing * o.max_randomness_offset * (y2 - y1) / 200.0
  let mid_y = o.bowing * o.max_randomness_offset * (x1 - x2) / 200.0
  let mid_x = o.offset_opt(mid_x, gain~)
  let mid_y = o.offset_opt(mid_y, gain~)
  let ops = []
  let jitter = () => {
    if overlay {
      o.offset_opt(half_offset, gain~)
    } else {
      o.offset_opt(offset, gain~)
    }
  }
  let vertex = () => if o.preserve_vertices { 0.0 } else { jitter() }
  if with_move {
    let mx = x1 + vertex()
    let my = y1 + vertex()
    ops.push(Move(mx, my))
  }
  let c1x = mid_x + x1 + (x2 - x1) * diverge_point + jitter()
  let c1y = mid_y + y1 + (y2 - y1) * diverge_point + jitter()
  let c2x = mid_x + x1 + 2.0 * (x2 - x1) * diverge_point + jitter()
  let c2y = mid_y + y1 + 2.0 * (y2 - y1) * diverge_point + jitter()
  let ex = x2 + vertex()
  let ey = y2 + vertex()
  ops.push(CurveTo(c1x, c1y, c2x, c2y, ex, ey))
  ops
}

///|
/// A line drawn twice unless multi-stroke is off (for the lines of a
/// fill, `disable_multi_stroke_fill`): `_doubleLine`.
fn double_line(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  o : Options,
  fill~ : Bool = false,
) -> Array[Op] {
  let first = line_ops(x1, y1, x2, y2, o, true, false)
  if (if fill { o.disable_multi_stroke_fill } else { o.disable_multi_stroke }) {
    return first
  }
  first.append(line_ops(x1, y1, x2, y2, o, true, true))
  first
}

///|
/// A cubic curve from `current`: `_bezierTo`.
fn bezier_to(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x : Double,
  y : Double,
  current : (Double, Double),
  o : Options,
) -> Array[Op] {
  let ops = []
  let base = if o.max_randomness_offset != 0.0 {
    o.max_randomness_offset
  } else {
    1.0
  }
  let ros = [base, base + 0.3]
  let iterations = if o.disable_multi_stroke { 1 } else { 2 }
  for i in 0..<iterations {
    if i == 0 {
      ops.push(Move(current.0, current.1))
    } else {
      let mx = current.0 +
        (if o.preserve_vertices { 0.0 } else { o.offset_opt(ros[0]) })
      let my = current.1 +
        (if o.preserve_vertices { 0.0 } else { o.offset_opt(ros[0]) })
      ops.push(Move(mx, my))
    }
    let (fx, fy) = if o.preserve_vertices {
      (x, y)
    } else {
      let fx = x + o.offset_opt(ros[i])
      let fy = y + o.offset_opt(ros[i])
      (fx, fy)
    }
    let c1x = x1 + o.offset_opt(ros[i])
    let c1y = y1 + o.offset_opt(ros[i])
    let c2x = x2 + o.offset_opt(ros[i])
    let c2y = y2 + o.offset_opt(ros[i])
    ops.push(CurveTo(c1x, c1y, c2x, c2y, fx, fy))
  }
  ops
}

///|
/// The outline of path data: rough.js's `svgPath`.
fn svg_path(d : String, o : Options) -> Array[Op] {
  let ops = []
  let mut first = (0.0, 0.0)
  let mut current = (0.0, 0.0)
  for segment in normalize(absolutize(parse_path(d))) {
    let data = segment.data
    match segment.key {
      'M' => {
        current = (data[0], data[1])
        first = (data[0], data[1])
      }
      'L' => {
        ops.append(double_line(current.0, current.1, data[0], data[1], o))
        current = (data[0], data[1])
      }
      'C' => {
        ops.append(
          bezier_to(
            data[0],
            data[1],
            data[2],
            data[3],
            data[4],
            data[5],
            current,
            o,
          ),
        )
        current = (data[4], data[5])
      }
      _ => {
        ops.append(double_line(current.0, current.1, first.0, first.1, o))
        current = first
      }
    }
  }
  ops
}

///|
/// Connected lines through points, closed or not: `linearPath`.
fn linear_path(
  points : Array[(Double, Double)],
  close : Bool,
  o : Options,
) -> Array[Op] {
  let n = points.length()
  if n > 2 {
    let ops = []
    for i in 0..<(n - 1) {
      ops.append(
        double_line(
          points[i].0,
          points[i].1,
          points[i + 1].0,
          points[i + 1].1,
          o,
        ),
      )
    }
    if close {
      ops.append(
        double_line(
          points[n - 1].0,
          points[n - 1].1,
          points[0].0,
          points[0].1,
          o,
        ),
      )
    }
    ops
  } else if n == 2 {
    double_line(points[0].0, points[0].1, points[1].0, points[1].1, o)
  } else {
    []
  }
}

///|
/// Polygons filled with a plain colour: `solidFillPolygon`.
fn solid_fill_polygon(
  polygons : Array[Array[(Double, Double)]],
  o : Options,
) -> Array[Op] {
  let ops = []
  for points in polygons {
    if points.length() > 2 {
      let offset = o.max_randomness_offset
      let mx = points[0].0 + o.offset_opt(offset)
      let my = points[0].1 + o.offset_opt(offset)
      ops.push(Move(mx, my))
      for i in 1..<points.length() {
        let lx = points[i].0 + o.offset_opt(offset)
        let ly = points[i].1 + o.offset_opt(offset)
        ops.push(LineTo(lx, ly))
      }
    }
  }
  ops
}

///|
/// A smooth curve through points: rough.js's `_curve`.
fn curve_ops(points : Array[(Double, Double)], o : Options) -> Array[Op] {
  let n = points.length()
  let ops = []
  if n > 3 {
    let s = 1.0 - o.curve_tightness
    ops.push(Move(points[1].0, points[1].1))
    for i = 1; i + 2 < n; i = i + 1 {
      let p = points[i]
      let before = points[i - 1]
      let after = points[i + 1]
      let beyond = points[i + 2]
      ops.push(
        CurveTo(
          p.0 + (s * after.0 - s * before.0) / 6.0,
          p.1 + (s * after.1 - s * before.1) / 6.0,
          after.0 + (s * p.0 - s * beyond.0) / 6.0,
          after.1 + (s * p.1 - s * beyond.1) / 6.0,
          after.0,
          after.1,
        ),
      )
    }
  } else if n == 3 {
    ops.push(Move(points[1].0, points[1].1))
    ops.push(
      CurveTo(
        points[1].0,
        points[1].1,
        points[2].0,
        points[2].1,
        points[2].0,
        points[2].1,
      ),
    )
  } else if n == 2 {
    ops.append(
      line_ops(
        points[0].0,
        points[0].1,
        points[1].0,
        points[1].1,
        o,
        true,
        true,
      ),
    )
  }
  ops
}

///|
/// How an ellipse is sampled: `generateEllipseParams`.
priv struct EllipseParams {
  increment : Double
  rx : Double
  ry : Double
}

///|
fn ellipse_params(
  width : Double,
  height : Double,
  o : Options,
) -> EllipseParams {
  let half_w = width / 2.0
  let half_h = height / 2.0
  let two_pi = 2.0 * 3.141592653589793
  let psq = (two_pi * ((half_w * half_w + half_h * half_h) / 2.0).sqrt()).sqrt()
  let step_count = o.curve_step_count
    .max(o.curve_step_count / 200.0.sqrt() * psq)
    .ceil()
  let increment = two_pi / step_count
  let mut rx = half_w.abs()
  let mut ry = half_h.abs()
  let fit = 1.0 - o.curve_fitting
  rx += o.offset_opt(rx * fit)
  ry += o.offset_opt(ry * fit)
  { increment, rx, ry, }
}

///|
/// The points an ellipse is drawn through: `_computeEllipsePoints`.
fn ellipse_points(
  increment : Double,
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
  offset : Double,
  overlap : Double,
  o : Options,
) -> Array[(Double, Double)] {
  let points = []
  let cos = @jsmath.cos
  let sin = @jsmath.sin
  let two_pi = 2.0 * 3.141592653589793
  if o.roughness == 0.0 {
    let increment = increment / 4.0
    points.push((cx + rx * cos(-increment), cy + ry * sin(-increment)))
    for angle = 0.0; angle <= two_pi; angle = angle + increment {
      points.push((cx + rx * cos(angle), cy + ry * sin(angle)))
    }
    points.push((cx + rx * cos(0.0), cy + ry * sin(0.0)))
    points.push((cx + rx * cos(increment), cy + ry * sin(increment)))
  } else {
    let rad_offset = o.offset_opt(0.5) - 3.141592653589793 / 2.0
    let point = (scale : Double, angle : Double) => {
      let x = o.offset_opt(offset) + cx + scale * rx * cos(angle)
      let y = o.offset_opt(offset) + cy + scale * ry * sin(angle)
      (x, y)
    }
    points.push(point(0.9, rad_offset - increment))
    let end_angle = two_pi + rad_offset - 0.01
    for angle = rad_offset; angle < end_angle; angle = angle + increment {
      points.push(point(1.0, angle))
    }
    points.push(point(1.0, rad_offset + two_pi + overlap * 0.5))
    points.push(point(0.98, rad_offset + overlap))
    points.push(point(0.9, rad_offset + overlap * 0.5))
  }
  points
}

///|
/// The outline of an ellipse: `ellipseWithParams`.
fn ellipse_ops(
  x : Double,
  y : Double,
  o : Options,
  params : EllipseParams,
) -> Array[Op] {
  let inner = o.offset(0.4, 1.0)
  let overlap = params.increment * o.offset(0.1, inner)
  let ops = curve_ops(
    ellipse_points(
      params.increment,
      x,
      y,
      params.rx,
      params.ry,
      1.0,
      overlap,
      o,
    ),
    o,
  )
  if !o.disable_multi_stroke && o.roughness != 0.0 {
    ops.append(
      curve_ops(
        ellipse_points(
          params.increment,
          x,
          y,
          params.rx,
          params.ry,
          1.5,
          0.0,
          o,
        ),
        o,
      ),
    )
  }
  ops
}
