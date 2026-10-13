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

///|
test "shielded entity codes come back as characters" {
  // What `#quot;`, `#9829;` and `#nosuch;` look like after encode_entities.
  let text = @dom.Element::new("text")
    .attr("title", "say ﬂ°quot¶ßhiﬂ°quot¶ß")
    .text("I ﬂ°°9829¶ß ﬂ°lt¶ßbﬂ°gt¶ß ﬂ°nosuch¶ß")
  inspect(
    text.to_html(),
    content=(
      #|<text title="say &quot;hi&quot;">I ♥ &lt;b&gt; &amp;nosuch;</text>
    ),
  )
}

///|
test "bounding boxes follow translated groups" {
  let svg = @dom.Element::new("svg")
  let group = svg.append("g").attr("transform", "translate(88, 34.5)")
  group
  .append("rect")
  .attr_number("x", -76.0)
  .attr_number("y", -22.5)
  .attr_number("width", 152.0)
  .attr_number("height", 45.0)
  |> ignore
  // An unsized rectangle renders nothing and does not count.
  group.append("rect") |> ignore
  debug_inspect(
    group.bbox(),
    content="{ x: -76, y: -22.5, width: 152, height: 45 }",
  )
  debug_inspect(svg.bbox(), content="{ x: 12, y: 12, width: 152, height: 45 }")
  svg.append("path").attr("d", "M88,57L88,93Q88,100 95,100L200,100") |> ignore
  debug_inspect(svg.bbox(), content="{ x: 12, y: 12, width: 188, height: 88 }")
}

///|
test "path length as getTotalLength reports it" {
  inspect(@dom.path_length("M88,57L88,93"), content="36")
  // Values from Chrome: rounded corners are measured almost exactly.
  inspect(
    @dom.path_length(
      "M114,57L114,69.92893218813452Q114,77 106.92893218813452,77L95.07106781186548,77Q88,77 88,84.07106781186548L88,93",
    ),
    content="56.671630859375",
  )
  inspect(
    @dom.path_length(
      "M88,142L88,154.92893218813452Q88,162 95.07106781186548,162L106.92893218813452,162Q114,162 114,169.07106781186548L114,178",
    ),
    content="56.67163848876953",
  )
}

///|
test "inner HTML" {
  let span = @dom.Element::new("span")
  span.set_inner_html("<p>a &amp; b<br />c</p>")
  // Void elements come out the way the final HTML serialization has them.
  inspect(span.to_html(), content="<span><p>a &amp; b<br>c</p></span>")
  inspect(span.text_content(), content="a & bc")
}

///|
test "attribute values are trimmed" {
  let g = @dom.Element::new("g").attr("class", " node default ")
  inspect(g.to_html(), content="<g class=\"node default\"></g>")
}

///|
test "arcs are measured as the cubics Blink walks" {
  // Values from Chrome.
  inspect(
    @dom.path_length(
      "M164,115.333 L176.929,115.333 Q184,115.333 184,108.262 L184,84.071 Q184,77 191.071,77 L198,77 A6,6 0 0 1 210,77 L216.929,77 Q224,77 224,69.929 L224,45.738 Q224,38.667 231.071,38.667 L240,38.667",
    ),
    content="148.86178588867188",
  )
}
