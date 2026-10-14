///|
/// Where an axis sits relative to what it measures, which is also the
/// side its ticks and labels point to.
pub(all) enum Orient {
  Top
  Right
  Bottom
  Left
} derive(Eq)

///|
/// d3-axis: draw an axis into `group`, as `group.call(axis)` does on an
/// empty selection.
///
/// `ticks` are the position of each tick along the axis (the scale applied
/// to the tick value) and its label; `range` is the extent of the scale.
/// `offset` is the half pixel d3 shifts lines by on a display with a
/// device pixel ratio of 1, as in the reference browser.
pub fn axis(
  group : @dom.Element,
  orient : Orient,
  ticks : Array[(Double, String)],
  range : (Double, Double),
  tick_size_inner~ : Double = 6.0,
  tick_size_outer~ : Double = 6.0,
  tick_padding~ : Double = 3.0,
  offset~ : Double = 0.5,
) -> Unit {
  let k = if orient == Top || orient == Left { -1.0 } else { 1.0 }
  let horizontal = orient == Top || orient == Bottom
  let x = if horizontal { "y" } else { "x" }
  let spacing = (if tick_size_inner > 0.0 { tick_size_inner } else { 0.0 }) +
    tick_padding
  let range0 = range.0 + offset
  let range1 = range.1 + offset
  let n = number
  // The domain line is inserted before the ticks.
  let path = group
    .append("path")
    .attr("class", "domain")
    .attr("stroke", "currentColor")
  let outer = n(k * tick_size_outer)
  path.attr(
    "d",
    if horizontal {
      if tick_size_outer != 0.0 {
        "M\{n(range0)},\{outer}V\{n(offset)}H\{n(range1)}V\{outer}"
      } else {
        "M\{n(range0)},\{n(offset)}H\{n(range1)}"
      }
    } else if tick_size_outer != 0.0 {
      "M\{outer},\{n(range0)}H\{n(offset)}V\{n(range1)}H\{outer}"
    } else {
      "M\{n(offset)},\{n(range0)}V\{n(range1)}"
    },
  )
  |> ignore
  for tick in ticks {
    let (position, label) = tick
    let tick = group.append("g").attr("class", "tick")
    tick
    .append("line")
    .attr("stroke", "currentColor")
    .attr(x + "2", n(k * tick_size_inner))
    |> ignore
    tick
    .append("text")
    .attr("fill", "currentColor")
    .attr(x, n(k * spacing))
    .attr(
      "dy",
      match orient {
        Top => "0em"
        Bottom => "0.71em"
        _ => "0.32em"
      },
    )
    .text(label)
    |> ignore
    let at = n(position + offset)
    tick
    .attr("opacity", "1")
    .attr(
      "transform",
      if horizontal {
        "translate(\{at},0)"
      } else {
        "translate(0,\{at})"
      },
    )
    |> ignore
  }
  group
  .attr("fill", "none")
  .attr("font-size", "10")
  .attr("font-family", "sans-serif")
  .attr(
    "text-anchor",
    match orient {
      Right => "start"
      Left => "end"
      _ => "middle"
    },
  )
  |> ignore
}
