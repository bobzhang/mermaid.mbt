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

///|
test "length attributes keep seven decimals" {
  // 377.72996520996094 is halfway between two floats; cut to seven
  // decimals it lands on the lower one, as in the browser.
  let rect = @dom.Element::new("rect")
    .attr("x", "377.72996520996094")
    .attr("width", "1.00000049")
    .attr("height", "1")
  let box = rect.bbox()
  inspect(box.x, content="377.7299499511719")
  inspect(box.width, content="1.0000003576278687")
}

///|
test "declarations as the CSSOM serializes them" {
  inspect(
    @dom.serialize_declarations(
      "fill:#f96 !important; stroke-dasharray: 5 5; animation: dash 25s linear infinite",
    ),
    content="fill: rgb(255, 153, 102) !important; stroke-dasharray: 5, 5; animation: 25s linear 0s infinite normal none running dash;",
  )
}

///|
test "a box built from edges still covers its far edge" {
  // 475.1377258300781 - 155.06886291503906 rounds down as a float; added
  // back to the origin it would stop short of the right edge, so the
  // width takes the next float, as in the browser.
  let path = @dom.Element::new("path").attr(
    "d", "M155.06886291503906,83L475.1377258300781,109",
  )
  inspect(path.bbox().width, content="320.0688781738281")
}

///|
test "bounding boxes of curves, and sizes that lose precision" {
  // Expected values are `getBBox()` in Chrome.
  let box = (element : @dom.Element) => {
    let b = element.bbox()
    "\{b.x} \{b.y} \{b.width} \{b.height}"
  }
  let path = (d : String) => @dom.Element::new("path").attr("d", d)
  // The far edge is not origin plus size in floats, so the size grows.
  inspect(
    box(path("M-77.2620999227555 0 L77.24899843587303 0")),
    content="-77.26210021972656 0 154.51112365722656 0",
  )
  // A cubic turns inside its control points.
  inspect(
    box(
      path(
        "M111.97801537018165 -228.44996749454515 C163.6962945294681 151.26646089651956, -48.467741942810164 285.810341109, -171.4908796168238 -21.22984280638002",
      ),
    ),
    content="-171.49087524414062 -228.44996643066406 291.4410705566406 376.7292785644531",
  )
  // Two cubics in a row.
  inspect(
    box(
      path(
        "M-190.9763765561687 47.01169119962162 C232.37896140000908 -53.94684631876456, 129.96863614898564 -140.86731731959964, -152.90001048379617 187.5489759530529 C-1.0191707871600215 -50.47673943342576, 136.65548093163062 277.94978865143867, -114.28247298077417 122.4358692626891",
      ),
    ),
    content="-190.97637939453125 -44.37568283081055 284.4175720214844 231.92466735839844",
  )
  // A group unites its children after their translations.
  let group = @dom.Element::new("g")
  group
  .append("path")
  .attr(
    "d", "M297.8692865280327 -147.40125681995073 L-88.71412726549013 226.09939329491408 L62.448110554479115 240.5827139313826 L197.80889773789903 283.7247307891016 L265.1240026639301 32.4492572785453 L151.85947148870525 235.41046151496948",
  )
  |> ignore
  group
  .append("path")
  .attr(
    "d", "M132.84526380917669 -236.64207234937936 C-30.30718296061974 34.99717010089114, 162.5328216293263 -242.917111428956, 16.223624482380615 171.52069906640327 L179.5561678913814 208.57469591786736 L95.2920484038226 155.05373581425079 C261.2886495937661 284.2517054986122, 158.64948124447795 -10.969010175044048, 193.22186977343534 62.91109965464443 L30.709222435161905 151.5182619159126 Z",
  )
  .attr("transform", "translate(-16.643146610414327, 1.642530231428708)")
  |> ignore
  inspect(
    box(group),
    content="-88.71412658691406 -234.99954223632812 386.58343505859375 518.7243041992188",
  )
  // Uniting two boxes rounds the far edge inwards; the size grows again.
  let pair = @dom.Element::new("g")
  pair
  .append("rect")
  .attr("x", "77.92963409423828125")
  .attr("y", "175.7861175537109375")
  .attr("width", "28.327625274658203125")
  .attr("height", "91.0900421142578125")
  |> ignore
  pair
  .append("rect")
  .attr("x", "-245.5976715087890625")
  .attr("y", "185.7867279052734375")
  .attr("width", "208.06219482421875")
  .attr("height", "12.65991306304931640625")
  |> ignore
  inspect(
    box(pair),
    content="-245.59767150878906 175.78611755371094 351.8549499511719 91.09004211425781",
  )
}

///|
test "bounding boxes of arcs" {
  // Expected values are `getBBox()` in Chrome on macOS: Skia turns arcs
  // into conics with the system's trigonometry.
  let box = (d : String) => {
    let b = @dom.Element::new("path").attr("d", d).bbox()
    "\{b.x} \{b.y} \{b.width} \{b.height}"
  }
  // Half an ellipse over the top overshoots its ends by a hair, because
  // the angle of the negative x axis is the float below pi.
  inspect(
    box(
      "M-153.98362679895644,-25.078441135218753 L-110.86821129524863,37.07844113521875 A110.86821129524863,12 0 0 0 110.86821129524863,37.07844113521875 L153.98362679895644,-25.078441135218753 A153.98362679895644,12 0 0 0 -153.98362679895644,-25.078441135218753 Z",
    ),
    content="-153.98362731933594 -37.07844161987305 307.9673156738281 86.15689849853516",
  )
  inspect(
    box(
      "M0,13.792400321006971 a76.91432998616759,13.792400321006971 0,0,0 153.82865997233517,0 a76.91432998616759,13.792400321006971 0,0,0 -153.82865997233517,0",
    ),
    content="0 -8.220912377510103e-7 153.8286590576172 27.584800720214844",
  )
  // A rotated ellipse.
  inspect(
    box(
      "M-24.04875609683708 -76.79505773550784 a245.49697502080326,161.09179053669672 -95.37116834113249 1,0 98.44038936223407,62.28005076197567",
    ),
    content="-186.13119506835938 -77.59929656982422 324.0448913574219 489.767578125",
  )
}

///|
test "lengths of elliptical arcs" {
  // Values from Chrome: rotated, scaled-up and large arcs.
  inspect(
    @dom.path_length("M24.516,17.722 A148.074,21.336 0 0 1 127.258,-44.994"),
    content="460.391357421875",
  )
  inspect(
    @dom.path_length(
      "M-199.782,-116.113 A136.631,71.028 172.929 1 0 -173.285,-236.717",
    ),
    content="486.3040466308594",
  )
  inspect(
    @dom.path_length("M169.026,5.682 A57.462,1.245 0 1 1 -8.43,-66.519"),
    content="3341.4716796875",
  )
}

///|
test "what the output sanitizer removes" {
  // Names that shadow a property of the document or of a form.
  inspect(@dom.is_clobbering_name("title"), content="true")
  inspect(@dom.is_clobbering_name("links"), content="true")
  inspect(@dom.is_clobbering_name("URL"), content="true")
  inspect(@dom.is_clobbering_name("Title"), content="false")
  inspect(@dom.is_clobbering_name("Alice"), content="false")
  // Addresses with a scheme other than the well-known ones.
  inspect(@dom.is_allowed_uri("https://x.example/"), content="true")
  inspect(@dom.is_allowed_uri("mailto:a@b.example"), content="true")
  inspect(@dom.is_allowed_uri("relative/path"), content="true")
  inspect(@dom.is_allowed_uri("rgb(0, 0, 0)"), content="true")
  inspect(@dom.is_allowed_uri("#fragment"), content="true")
  inspect(@dom.is_allowed_uri(""), content="true")
  inspect(@dom.is_allowed_uri("about:blank"), content="false")
  inspect(@dom.is_allowed_uri("java script:alert(1)"), content="false")
  inspect(@dom.is_allowed_uri("my:color"), content="false")
}
