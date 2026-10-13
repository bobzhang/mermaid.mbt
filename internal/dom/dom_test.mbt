///|
test "elements serialize with ordered attributes and explicit end tags" {
  let svg = @dom.Element::new("svg").attr("id", "x").attr("width", "100%")
  let group = svg.append("g").attr("transform", "translate(1,2)")
  group.append("circle").attr_number("cx", 0.0).attr_number("r", 186.5)
  |> ignore
  group.append("text").text("a < b & c") |> ignore
  svg.insert_first("style").text(".a>.b{fill:red;}") |> ignore
  svg.attr("id", "y") |> ignore
  inspect(
    svg.to_html(),
    content=(
      #|<svg id="y" width="100%"><style>.a&gt;.b{fill:red;}</style><g transform="translate(1,2)"><circle cx="0" r="186.5"></circle><text>a &lt; b &amp; c</text></g></svg>
    ),
  )
}

///|
test "inline styles are normalized like the browser's CSSOM" {
  let rect = @dom.Element::new("rect")
    .style("fill", "#ECECFF")
    .style("stroke", "hsl(80, 100%, 56.2745098039%)")
    .style("text-anchor", "middle")
    .style("fill", "rgba(232,232,232, 0.8)")
    .style("color", "Red")
  inspect(
    rect.to_html(),
    content=(
      #|<rect style="fill: rgba(232, 232, 232, 0.8); stroke: rgb(181, 255, 32); text-anchor: middle; color: red;"></rect>
    ),
  )
}

///|
test "tree edits" {
  let root = @dom.Element::new("g")
  let a = root.append("a")
  let b = root.append("b")
  a.remove()
  b.append_child(a)
  inspect(root.to_html(), content="<g><b><a></a></b></g>")
  inspect(a.parent() is Some(_), content="true")
  inspect(root.append("text").text("hi").text_content(), content="hi")
  inspect(@dom.number(-0.0), content="0")
}

///|
test "the style attribute materializes when the document is serialized" {
  // Declarations set through `style` are written back lazily, so the
  // attribute lands after ones that were set later.
  let text = @dom.Element::new("text")
    .attr("transform", "translate(1,2)")
    .style("text-anchor", "middle")
    .attr("class", "slice")
  inspect(
    text.to_html(),
    content=(
      #|<text transform="translate(1,2)" class="slice" style="text-anchor: middle;"></text>
    ),
  )
  // An explicit style attribute keeps its position and its raw text until
  // a declaration changes.
  let svg = @dom.Element::new("svg")
    .attr("style", "max-width: 10px;")
    .attr("role", "img")
  inspect(
    svg.to_html(),
    content=(
      #|<svg style="max-width: 10px;" role="img"></svg>
    ),
  )
  inspect(
    svg.style("fill", "#fff").to_html(),
    content=(
      #|<svg style="max-width: 10px; fill: rgb(255, 255, 255);" role="img"></svg>
    ),
  )
}
