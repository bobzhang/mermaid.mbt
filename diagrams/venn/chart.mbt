// The chart of venn.js (`VennDiagram()` called on a selection), as far
// as mermaid uses it: a detached `<svg>` with a group per area.

///|
/// The colours venn.js gives the sets in turn. mermaid replaces them, but
/// a fill the browser does not accept leaves them standing.
let colour_scheme : Array[String] = [
  "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b", "#e377c2", "#7f7f7f",
  "#bcbd22", "#17becf",
]

///|
/// The group of an area in the chart.
priv struct ChartNode {
  area : Area
  group : @dom.Element
  path : @dom.Element
  text : @dom.Element
}

///|
/// A laid out diagram: the circles by set and the places of the labels
/// by area.
priv struct Solution {
  circles : Dict[Circle]
  text_centres : Map[String, TextCentre]
}

///|
/// Lay the areas out in a chart of the given size: `venn`, then
/// `normalizeSolution`, `scaleSolution` and `computeTextCentres`.
fn solve(
  data : Array[Area],
  width : Double,
  height : Double,
  padding : Double,
  random : Random,
) -> Solution raise VennError {
  let solution = venn_layout(data, random)
  let solution = normalize_solution(solution, PI / 2.0)
  let circles = scale_solution(solution, width, height, padding)
  { circles, text_centres: compute_text_centres(circles, data), }
}

///|
/// `String.prototype.split(/\s+/)`
fn split_white_space(text : String) -> Array[String] {
  let words = []
  let word = StringBuilder()
  let mut in_space = false
  for c in text {
    if @diagram.is_js_space(c) {
      if !in_space {
        words.push(word.to_string())
        word.reset()
      }
      in_space = true
    } else {
      in_space = false
      word.write_char(c)
    }
  }
  words.push(word.to_string())
  words
}

///|
/// `wrapText`: the label as `<tspan>`s. The chart is drawn outside the
/// document, where no text has a length, so nothing is ever too long for
/// its line: the label is one `<tspan>`, holding its words up to the
/// first empty one with single spaces between them.
fn wrap_text(text : @dom.Element, label : String) -> Unit {
  let words = split_white_space(label)
  let line = [words[0]]
  for i in 1..<words.length() {
    if words[i] == "" {
      break
    }
    line.push(words[i])
  }
  text.text("") |> ignore
  let x = text.get_attr("x").unwrap_or("")
  let y = text.get_attr("y").unwrap_or("")
  text
  .append("tspan")
  .text(line.join(" "))
  .attr("x", x)
  .attr("y", y)
  .attr("dy", "0.35em")
  |> ignore
}

///|
/// Draw the chart: the `<svg>` venn.js appends to its selection and the
/// groups in it, one per area in the order of the data.
fn chart(
  data : Array[Area],
  width : Double,
  height : Double,
  random : Random,
) -> (@dom.Element, Array[ChartNode]) raise VennError {
  let n = @dom.number
  // A set without a size is left out, with every overlap it is part of.
  let to_remove : Map[String, Unit] = Map([])
  for datum in data {
    if datum.size == 0.0 && datum.sets.length() == 1 {
      to_remove[datum.sets[0]] = ()
    }
  }
  let data = data.filter(datum => {
    !datum.sets.iter().any(set => to_remove.contains(set))
  })
  let solution = if data.length() > 0 {
    // The chart's own padding is 15.
    solve(data, width, height, 15.0, random)
  } else {
    { circles: Dict::new(), text_centres: Map([]), }
  }
  let labels : Map[String, String] = Map([])
  for datum in data {
    if datum.label is Some(label) && label != "" {
      labels[datum.key()] = label
    }
  }
  let label = (area : Area) => {
    match labels.get(area.key()) {
      Some(label) => label
      None => if area.sets.length() == 1 { area.sets[0] } else { "" }
    }
  }
  let colour_map : Map[String, String] = Map([])
  let colours = (key : String) => {
    match colour_map.get(key) {
      Some(colour) => colour
      None => {
        let colour = colour_scheme[colour_map.length() % colour_scheme.length()]
        colour_map[key] = colour
        colour
      }
    }
  }
  let svg = @dom.Element::new("svg")
    .attr("width", n(width))
    .attr("height", n(height))
  let nodes : Array[ChartNode] = []
  for area in data {
    let single = area.sets.length() == 1
    let group = svg
      .append("g")
      .attr(
        "class",
        if single {
          "venn-area venn-circle"
        } else {
          "venn-area venn-intersection"
        },
      )
      .attr("data-venn-sets", area.sets.join("_"))
    let path = group.append("path")
    let text = group
      .append("text")
      .attr("class", "label")
      .text(label(area))
      .attr("text-anchor", "middle")
      .attr("dy", ".35em")
      .attr("x", n(width / 2.0))
      .attr("y", n(height / 2.0))
    path.style("fill-opacity", "0") |> ignore
    if single {
      path.style("fill", colours(area.key())).style("fill-opacity", "0.25")
      |> ignore
    }
    text.style("fill", if single { colours(area.key()) } else { "#444" })
    |> ignore
    nodes.push({ area, group, path, text, })
  }
  for node in nodes {
    let circles = node.area.sets.map(set => circle_of(solution.circles, set))
    // The line breaks before every command but the first survive; the
    // first goes when the attribute is sanitized.
    let d = intersection_area_path(circles)
    node.path.attr("d", if d.has_prefix("\n") { d[1:].to_owned() } else { d })
    |> ignore
  }
  for node in nodes {
    guard solution.text_centres.get(node.area.key()) is Some(centre) else {
      continue
    }
    node.text.attr("x", n(centre.x.floor())).attr("y", n(centre.y.floor()))
    |> ignore
    wrap_text(node.text, label(node.area))
  }
  (svg, nodes)
}
