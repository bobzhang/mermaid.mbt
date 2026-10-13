// Line hops: where one edge crosses another, the horizontal one jumps over
// with a small arc. Mermaid's `rendering-elements/lineJump.ts`, applied to
// the edges after they are drawn.

///|
const JUMP_RADIUS : Double = 6.0

///|
/// The radius of the rounded corners of edge paths.
const CORNER_RADIUS : Double = 5.0

///|
/// A place where an edge has to jump over another.
priv struct Crossing {
  edge : Int32
  seg_index : Int32
  t : Double
  point : Point
}

///|
/// Where two segments cross strictly inside both.
fn segment_crossing(
  a1 : Point,
  a2 : Point,
  b1 : Point,
  b2 : Point,
) -> (Point, Double, Double)? {
  let dx_a = a2.x - a1.x
  let dy_a = a2.y - a1.y
  let dx_b = b2.x - b1.x
  let dy_b = b2.y - b1.y
  let denom = dx_a * dy_b - dy_a * dx_b
  if denom == 0.0 {
    return None
  }
  let dx = b1.x - a1.x
  let dy = b1.y - a1.y
  let t_a = (dx * dy_b - dy * dx_b) / denom
  let t_b = (dx * dy_a - dy * dx_a) / denom
  let eps = 1.0e-6
  if t_a <= eps || t_a >= 1.0 - eps || t_b <= eps || t_b >= 1.0 - eps {
    return None
  }
  Some(({ x: a1.x + t_a * dx_a, y: a1.y + t_a * dy_a, }, t_a, t_b))
}

///|
/// The curve that rounds the corner at `curr`.
priv struct RoundedCorner {
  start : Point
  end : Point
  ctrl : Point
  cut_len : Double
}

///|
fn rounded_corner(
  prev : Point,
  curr : Point,
  next : Point,
  radius : Double,
) -> RoundedCorner? {
  let dx1 = curr.x - prev.x
  let dy1 = curr.y - prev.y
  let dx2 = next.x - curr.x
  let dy2 = next.y - curr.y
  let len1 = @jsmath.hypot(dx1, dy1)
  let len2 = @jsmath.hypot(dx2, dy2)
  if len1 < 1.0e-5 || len2 < 1.0e-5 {
    return None
  }
  let nx1 = dx1 / len1
  let ny1 = dy1 / len1
  let nx2 = dx2 / len2
  let ny2 = dy2 / len2
  let dot = nx1 * nx2 + ny1 * ny2
  let angle = @jsmath.acos((-1.0).max(dot.min(1.0)))
  if angle < 1.0e-5 || (3.141592653589793 - angle).abs() < 1.0e-5 {
    return None
  }
  let cut_len = (radius / @jsmath.sin(angle / 2.0))
    .min(len1 / 2.0)
    .min(len2 / 2.0)
  Some({
    start: { x: curr.x - nx1 * cut_len, y: curr.y - ny1 * cut_len, },
    end: { x: curr.x + nx2 * cut_len, y: curr.y + ny2 * cut_len, },
    ctrl: curr,
    cut_len,
  })
}

///|
/// A crossing inside the curve of a rounded corner is left alone: the
/// path is not straight there.
fn crossing_in_rounded_corner(
  edge : Edge,
  seg_index : Int32,
  t : Double,
) -> Bool {
  if edge.curve != "rounded" {
    return false
  }
  let pts = edge.points
  let a = pts[seg_index]
  let b = pts[seg_index + 1]
  let seg_len = @jsmath.hypot(b.x - a.x, b.y - a.y)
  let d = t * seg_len
  if seg_index > 0 &&
    rounded_corner(pts[seg_index - 1], a, b, CORNER_RADIUS) is Some(entering) &&
    d < entering.cut_len {
    return true
  }
  seg_index + 2 < pts.length() &&
  rounded_corner(a, b, pts[seg_index + 2], CORNER_RADIUS) is Some(leaving) &&
  seg_len - d < leaving.cut_len
}

///|
fn is_horizontal(a : Point, b : Point) -> Bool {
  (b.x - a.x).abs() >= (b.y - a.y).abs()
}

///|
/// Every crossing between two edges, assigned to the edge that jumps: the
/// horizontal one of an orthogonal pair, else the later edge.
fn find_crossings(edges : Array[Edge]) -> Array[Crossing] {
  let crossings = []
  for i, edge_a in edges {
    for j in (i + 1)..<edges.length() {
      let edge_b = edges[j]
      for si in 0..<(edge_a.points.length() - 1) {
        let a1 = edge_a.points[si]
        let a2 = edge_a.points[si + 1]
        for sj in 0..<(edge_b.points.length() - 1) {
          let b1 = edge_b.points[sj]
          let b2 = edge_b.points[sj + 1]
          guard segment_crossing(a1, a2, b1, b2) is Some((point, t_a, t_b)) else {
            continue
          }
          if crossing_in_rounded_corner(edge_a, si, t_a) ||
            crossing_in_rounded_corner(edge_b, sj, t_b) {
            continue
          }
          let a_horizontal = is_horizontal(a1, a2)
          let b_horizontal = is_horizontal(b1, b2)
          if a_horizontal != b_horizontal && a_horizontal {
            crossings.push({ edge: i, seg_index: si, t: t_a, point, })
          } else {
            crossings.push({ edge: j, seg_index: sj, t: t_b, point, })
          }
        }
      }
    }
  }
  crossings
}

///|
/// `Math.round`.
fn js_round(x : Double) -> Double {
  let ceiling = x.ceil()
  if ceiling - 0.5 > x {
    ceiling - 1.0
  } else {
    ceiling
  }
}

///|
/// A coordinate with at most three decimals.
fn fmt3(value : Double) -> String {
  @dom.number(js_round(value * 1000.0) / 1000.0)
}

///|
priv struct Jump {
  t : Double
  point : Point
  d : Double
  mut r : Double
}

///|
/// The path of an edge with its jumps: mermaid's `rewriteEdgePath`.
fn rewrite_edge_path(edge : Edge, jumps : Array[Crossing]) -> String {
  let raw = edge.points
  if raw.length() < 2 {
    return ""
  }
  let points = apply_marker_offsets(raw, edge)
  let rounded = edge.curve == "rounded"
  let segment_count = points.length() - 1
  let by_segment : Map[Int32, Array[Jump]] = Map([])
  for jump in jumps {
    guard jump.seg_index >= 0 && jump.seg_index < segment_count else {
      continue
    }
    let a = points[jump.seg_index]
    let b = points[jump.seg_index + 1]
    let seg_len = @jsmath.hypot(b.x - a.x, b.y - a.y)
    let entry = {
      t: jump.t,
      point: jump.point,
      d: jump.t * seg_len,
      r: JUMP_RADIUS,
    }
    match by_segment.get(jump.seg_index) {
      Some(list) => list.push(entry)
      None => by_segment[jump.seg_index] = [entry]
    }
  }
  let point_text = (p : Point) => "\{fmt3(p.x)},\{fmt3(p.y)}"
  let parts = ["M" + point_text(points[0])]
  for i in 0..<segment_count {
    let a = points[i]
    let b = points[i + 1]
    let seg_len = @jsmath.hypot(b.x - a.x, b.y - a.y)
    let ux = if seg_len == 0.0 { 0.0 } else { (b.x - a.x) / seg_len }
    let uy = if seg_len == 0.0 { 0.0 } else { (b.y - a.y) / seg_len }
    let dx = b.x - a.x
    let dy = b.y - a.y
    let sweep = if dx.abs() >= dy.abs() {
      if dx >= 0.0 {
        1
      } else {
        0
      }
    } else if dy >= 0.0 {
      1
    } else {
      0
    }
    let mut start_consumed = 0.0
    if rounded &&
      i > 0 &&
      rounded_corner(points[i - 1], points[i], points[i + 1], CORNER_RADIUS)
      is Some(corner) {
      start_consumed = corner.cut_len
    }
    let mut end_stop = seg_len
    let mut upcoming : RoundedCorner? = None
    if rounded && i < segment_count - 1 {
      upcoming = rounded_corner(
        points[i],
        points[i + 1],
        points[i + 2],
        CORNER_RADIUS,
      )
      if upcoming is Some(corner) {
        end_stop = seg_len - corner.cut_len
      }
    }
    let min_useful = JUMP_RADIUS * 0.6
    let sorted = by_segment.get(i).unwrap_or([]).copy()
    // A stable sort by position along the segment.
    let keyed = sorted.mapi((index, jump) => (index, jump))
    keyed.sort_by((x, y) => {
      let order = x.1.t.compare(y.1.t)
      if order != 0 {
        order
      } else {
        x.0.compare(y.0)
      }
    })
    let seg_jumps = []
    for entry in keyed {
      let jump = entry.1
      // Keep clear of the rounded corners at both ends.
      let room = (jump.d - start_consumed).min(end_stop - jump.d) - 2.0
      jump.r = jump.r.min(room)
      if jump.r >= min_useful {
        seg_jumps.push(jump)
      }
    }
    for k in 0..<(seg_jumps.length() - 1) {
      let gap = seg_jumps[k + 1].d - seg_jumps[k].d
      if seg_jumps[k].r + seg_jumps[k + 1].r > gap {
        let half = gap / 2.0
        seg_jumps[k].r = seg_jumps[k].r.min(half)
        seg_jumps[k + 1].r = seg_jumps[k + 1].r.min(half)
      }
    }
    for jump in seg_jumps {
      if jump.r < min_useful {
        continue
      }
      let pre = {
        x: jump.point.x - ux * jump.r,
        y: jump.point.y - uy * jump.r,
      }
      let post = {
        x: jump.point.x + ux * jump.r,
        y: jump.point.y + uy * jump.r,
      }
      parts.push("L" + point_text(pre))
      parts.push(
        "A\{fmt3(jump.r)},\{fmt3(jump.r)} 0 0 \{sweep} \{point_text(post)}",
      )
    }
    match upcoming {
      Some(corner) if rounded => {
        parts.push("L" + point_text(corner.start))
        parts.push("Q\{point_text(corner.ctrl)} \{point_text(corner.end)}")
      }
      _ => parts.push("L" + point_text(b))
    }
  }
  parts.join(" ")
}

///|
/// The two gaps a neo edge's dash pattern leaves for its markers, read
/// back from its style: `0 <start> <on> <end>`.
fn dash_gaps(style : String) -> (String, String)? {
  guard style.find("stroke-dasharray") is Some(at) else { return None }
  let rest = style[at + 16:].trim_start(chars=" \t\n")
  guard rest.strip_prefix(":") is Some(rest) else { return None }
  let end = rest.find(";").unwrap_or(rest.length())
  let tokens = []
  for token in rest[:end].split(" ") {
    if !token.is_empty() {
      tokens.push(token.to_owned())
    }
  }
  guard tokens is ["0", start, _, end, ..] else { return None }
  let numeric = (text : String) => {
    text != "" && text.iter().all(c => c is ('0'..<='9' | '.'))
  }
  if numeric(start) && numeric(tokens[2]) && numeric(end) {
    Some((start, end))
  } else {
    None
  }
}

///|
/// A number as `Number.parseFloat` reads a run of digits and dots.
fn parse_number(text : String) -> Double {
  let mut value = 0.0
  let mut scale = 0.0
  for c in text {
    if c == '.' {
      if scale != 0.0 {
        break
      }
      scale = 1.0
    } else {
      let digit = (c.to_int() - '0').to_double()
      if scale == 0.0 {
        value = value * 10.0 + digit
      } else {
        scale = scale * 10.0
        value = value + digit / scale
      }
    }
  }
  value
}

///|
/// Replace the dash pattern in a style and tidy doubled semicolons, as
/// the two regular expressions upstream do.
fn replace_dasharray(style : String, pattern : String) -> String {
  // /stroke-dasharray\s*:[^;]*;?/g
  let replaced = StringBuilder()
  let mut rest = style[:]
  while rest.find("stroke-dasharray") is Some(at) {
    let after = rest[at + 16:]
    let trimmed = after.trim_start(chars=" \t\n")
    guard trimmed.strip_prefix(":") is Some(value) else {
      replaced.write_view(rest[:at + 16])
      rest = after
      continue
    }
    let end = match value.find(";") {
      Some(end) => end + 1
      None => value.length()
    }
    replaced.write_view(rest[:at])
    replaced.write_string("stroke-dasharray: \{pattern};")
    rest = value[end:]
  }
  replaced.write_view(rest)
  // /;\s*;+/g
  let text = replaced.to_string().to_array()
  let out = StringBuilder()
  let n = text.length()
  let mut i = 0
  while i < n {
    if text[i] == ';' {
      let mut j = i + 1
      while j < n && text[j] is (' ' | '\t' | '\n' | '\r') {
        j += 1
      }
      if j < n && text[j] == ';' {
        while j < n && text[j] == ';' {
          j += 1
        }
        out.write_char(';')
        i = j
        continue
      }
    }
    out.write_char(text[i])
    i += 1
  }
  out.to_string()
}

///|
/// Redraw the edges that have to jump over others: mermaid's
/// `applyLineJumpsToSvg`.
fn apply_line_jumps(
  data : LayoutData,
  paths : Map[String, @dom.Element],
) -> Unit {
  if data.config.get("elk.lineHops") is False {
    return
  }
  let edges = data.edges.filter(edge => {
    edge.points.length() >= 2 && paths.contains(edge.id)
  })
  let crossings = find_crossings(edges)
  if crossings.is_empty() {
    return
  }
  for index, edge in edges {
    let jumps = crossings.filter(crossing => crossing.edge == index)
    if jumps.is_empty() {
      continue
    }
    guard edge.curve
      is ("linear" | "rounded" | "step" | "stepBefore" | "stepAfter") else {
      continue
    }
    guard paths.get(edge.id) is Some(path) else { continue }
    let original_style = path.get_attr("style").unwrap_or("")
    let new_d = rewrite_edge_path(edge, jumps)
    path.attr("d", new_d) |> ignore
    if dash_gaps(original_style) is Some((start, end)) {
      let start = parse_number(start)
      let end = parse_number(end)
      let on = (@dom.path_length(new_d) - start - end).max(0.0)
      let n = @dom.number
      path.attr(
        "style",
        replace_dasharray(original_style, "0 \{n(start)} \{n(on)} \{n(end)}"),
      )
      |> ignore
    }
  }
}
