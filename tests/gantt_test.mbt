///|
test "gantt" {
  json_inspect(mismatches("gantt"), content=[])
}

///|
/// The part of a rendering between two markers, the first included.
fn excerpt(svg : String, from : String, to : String) -> String {
  guard svg.find(from) is Some(start) else { return "" }
  let rest = svg[start:]
  match rest.find(to) {
    Some(end) => rest[:end].to_owned()
    None => rest.to_owned()
  }
}

///|
/// The today marker moves with the clock, so the fixtures switch it off;
/// here the clock is set. The expected markup is upstream's, rendered
/// with its clock stopped at the same moment (scripts/oracle.py --now).
test "gantt today marker" {
  let now = 1700000000000.0
  let chart =
    #|gantt
    #|    dateFormat YYYY-MM-DD
    #|    title Today inside
    #|    Task one :a, 2023-11-01, 30d
    #|    Task two :b, after a, 10d
    #|
  inspect(
    excerpt(@mermaid.render(chart, now~), "<g class=\"today\">", "<text"),
    content=(
      #|<g class="today"><line x1="285" x2="285" y1="25" y2="123" class="today"></line></g>
    ),
  )
  let styled =
    #|gantt
    #|    dateFormat YYYY-MM-DD
    #|    todayMarker stroke-width:5px,stroke:#0f0,opacity:0.5
    #|    Task one :a, 2023-11-01, 30d
    #|
  inspect(
    excerpt(@mermaid.render(styled, now~), "<g class=\"today\">", "<text"),
    content=(
      #|<g class="today"><line x1="355" x2="355" y1="25" y2="99" class="today" style="stroke-width:5px;stroke:#0f0;opacity:0.5"></line></g>
    ),
  )
  // A task after or until an unknown task starts or ends on the day of
  // rendering, at midnight.
  let dangling =
    #|gantt
    #|    dateFormat YYYY-MM-DD
    #|    A :a, after zzz_unknown_1, 3d
    #|    B :b, 2023-11-10, until zzz_unknown_2
    #|
  inspect(
    excerpt(@mermaid.render(dangling, now~), "<rect id=\"mermaid-svg-a\"", ">"),
    content=(
      #|<rect id="mermaid-svg-a" rx="3" ry="3" x="444" y="50" width="221" height="20" transform-origin="554.5px 60px" class="task task0"
    ),
  )
}
