///|
test "rounded corners" {
  let points = [
    { x: 114.0, y: 57.0, },
    { x: 114.0, y: 77.0, },
    { x: 88.0, y: 77.0, },
    { x: 88.0, y: 97.0, },
  ]
  inspect(
    rounded_path(points, 5.0),
    content="M114,57L114,69.92893218813452Q114,77 106.92893218813452,77L95.07106781186548,77Q88,77 88,84.07106781186548L88,97",
  )
  // Straight runs and repeated points get no curve.
  inspect(
    rounded_path(
      [{ x: 0.0, y: 0.0, }, { x: 10.0, y: 0.0, }, { x: 20.0, y: 0.0, }],
      5.0,
    ),
    content="M0,0L10,0L20,0",
  )
}

///|
test "route attribute" {
  let points = [{ x: 88.0, y: 57.0, }, { x: 88.0, y: 97.0, }]
  inspect(
    points_json(points),
    content="[{\"x\":88,\"y\":57},{\"x\":88,\"y\":97}]",
  )
  inspect(
    base64(points_json(points)),
    content="W3sieCI6ODgsInkiOjU3fSx7IngiOjg4LCJ5Ijo5N31d",
  )
  inspect(base64("a"), content="YQ==")
  inspect(base64("ab"), content="YWI=")
}

///|
test "dash pattern of dotted edges" {
  inspect(dash_array(22.0, 0.0, 4.0), content="0 0 2 2 2 2 2 2 2 2 4")
  inspect(dash_array(3.0, 0.0, 4.0), content="0 0  4")
}

///|
test "clipping against a rectangle" {
  let bounds : Bounds = { x: 100.0, y: 50.0, width: 40.0, height: 20.0, }
  debug_inspect(
    intersect_rect(100.0, 50.0, 40.0, 20.0, { x: 100.0, y: 200.0, }),
    content="{ x: 100, y: 60 }",
  )
  debug_inspect(
    box_intersection(bounds, { x: 200.0, y: 50.0, }, { x: 100.0, y: 50.0, }),
    content="{ x: 120, y: 50 }",
  )
  inspect(on_border(bounds, { x: 120.0, y: 55.0, }), content="true")
  inspect(outside_node(bounds, { x: 119.0, y: 55.0, }), content="false")
}

///|
test "terminal jogs are straightened" {
  let points = [
    { x: 0.0, y: 0.0, },
    { x: 0.0, y: 10.0, },
    { x: 6.0, y: 10.0, },
    { x: 6.0, y: 60.0, },
    { x: 80.0, y: 60.0, },
    { x: 80.0, y: 100.0, },
  ]
  guard straighten_terminal_jogs(points) is Some((moved, runs)) else {
    fail("expected the jog to be straightened")
  }
  debug_inspect(
    moved,
    content="[{ x: 0, y: 0 }, { x: 0, y: 60 }, { x: 80, y: 60 }, { x: 80, y: 100 }]",
  )
  inspect(runs.length(), content="1")
}

///|
test "line breaks in edge labels" {
  inspect(normalize_breaks("a<br>b<BR/>c<br />d"), content="a\nb\nc\nd")
  inspect(non_markdown_to_html("a\nb"), content="<p>a<br />b</p>")
  inspect(non_markdown_to_html(""), content="")
}

///|
test "icons in labels" {
  inspect(
    replace_icons("<p>fa:fa-car Car and fab:fa-github</p>"),
    content="<p><i class='fa fa-car'></i> Car and <i class='fab fa-github'></i></p>",
  )
  inspect(replace_icons("sofa: fa-x"), content="sofa: fa-x")
}

///|
test "styles after a line hop" {
  inspect(
    replace_dasharray(
      "stroke-dasharray: 0 0 32 4; stroke-dashoffset: 0;stroke:red;;;stroke:red",
      "0 0 40.5 4",
    ),
    content="stroke-dasharray: 0 0 40.5 4; stroke-dashoffset: 0;stroke:red;stroke:red",
  )
  debug_inspect(
    dash_gaps("stroke-dasharray: 0 0 2 2 2 2 4; stroke-dashoffset: 0;"),
    content="Some((\"0\", \"2\"))",
  )
  debug_inspect(dash_gaps("fill:none"), content="None")
  inspect(fmt3(115.33333333333334), content="115.333")
  inspect(fmt3(-0.0001), content="0")
}

///|
test "markdown labels" {
  inspect(
    markdown_to_html("This is **bold**, *italic*, _also_ and ***both***", true),
    content="<p>This is <strong>bold</strong>, <em>italic</em>, <em>also</em> and <em><strong>both</strong></em></p>",
  )
  inspect(
    markdown_to_html("Line one\n    Line two with a \\*literal\\* star", true),
    content="<p>Line one<br/>Line two with a *literal* star</p>",
  )
  inspect(
    markdown_to_html("snake_case_name stays and 2 * 3 * 4 too", true),
    content="<p>snake_case_name stays and 2 * 3 * 4 too</p>",
  )
  inspect(
    markdown_to_html("First\n\nSecond <b>kept</b>", true),
    content="<p>First</p><p>Second <b>kept</b></p>",
  )
  inspect(markdown_to_html("a b", false), content="<p>a&nbsp;b</p>")
  // Blocks other than paragraphs pass through as written.
  inspect(markdown_to_html("# Heading", true), content="# Heading")
  // marked's results (checked in Chrome): emphasis nests, a heading is
  // one line, a rule keeps the line break after it, a list or quote ends
  // at a blank line, two spaces before a line break are a break token.
  inspect(
    markdown_to_html("*a **b** c*", true),
    content="<p><em>a <strong>b</strong> c</em></p>",
  )
  inspect(
    markdown_to_html("**a *b***", true),
    content="<p><strong>a <em>b</em></strong></p>",
  )
  inspect(
    markdown_to_html("*foo**bar*", true),
    content="<p><em>foo**bar</em></p>",
  )
  inspect(
    markdown_to_html("# h\n**b**", true),
    content="# h\n<p><strong>b</strong></p>",
  )
  inspect(markdown_to_html("***\nb", true), content="***\n<p>b</p>")
  inspect(markdown_to_html("- a\n- b\n\nc", true), content="- a\n- b<p>c</p>")
  inspect(markdown_to_html("a\n---", true), content="a\n---")
  inspect(markdown_to_html("a  \nb", true), content="<p>a  \nb</p>")
}

///|
test "line break opportunities" {
  inspect(breaks_between(Some('l'), '-', 'k'), content="true")
  inspect(breaks_between(Some('a'), '-', '1'), content="true")
  inspect(breaks_between(Some('('), '-', '1'), content="false")
  inspect(breaks_between(None, '?', 'x'), content="true")
  inspect(breaks_between(None, '/', 'b'), content="false")
  inspect(breaks_between(None, '_', 'b'), content="false")
  inspect(breaks_between(None, ')', '('), content="true")
}

///|
test "text labels split into lines of words" {
  let words = (lines : Array[Array[Word]]) => {
    lines.map(line => {
      line.map(word => {
        if word.kind == "normal" {
          word.content
        } else {
          "\{word.kind}:\{word.content}"
        }
      })
    })
  }
  json_inspect(words(non_markdown_to_lines("one two<br/>three <b>four</b>")), content=[
    ["one", "two"],
    ["three", "<b>", "four", "</b>"],
  ])
  json_inspect(words(non_markdown_to_lines(" ")), content=[[]])
  json_inspect(words(markdown_to_lines("The **cat**\n  in the *hat* \\*")), content=[
    ["The", "strong:cat"],
    ["in", "the", "em:hat"],
  ])
  inspect(
    drop_declarations("fill:red;color:blue;stroke-width:2px", [
      "stroke", "stroke-width", "fill",
    ]),
    content="color:blue;",
  )
}

///|
test "SVG labels keep the character references of text without markup" {
  let env = Env::new(@config.Config::new(), "id")
  let words = (text : String) => {
    let parent = @dom.Element::new("g")
    let label = create_svg_label(parent, text, env)
    label.lines.map(line => line_items_text(line).map(item => item.text))
  }
  // The sanitizer returns such text as it is; writing the words resolves
  // `&amp;`, `&lt;` and `&gt;` and nothing else.
  debug_inspect(
    words("5 ﬂ°gt¶ß 3 ﬂ°quot¶ßxﬂ°quot¶ß ﬂ°°35¶ß"),
    content=(
      #|[["5", " >", " 3", " &quot;x&quot;", " &#35;"]]
    ),
  )
  // With markup the text goes through the HTML parser, which resolves
  // every reference.
  debug_inspect(
    words("ﬂ°quot¶ßxﬂ°quot¶ß<br/>ﬂ°°35¶ß"),
    content=(
      #|[["\"x\""], ["#"]]
    ),
  )
}

///|
test "a person: a head above a body, sized around the stacked label" {
  let node = Node::new(
    id="a",
    label="Alice",
    label_type="string",
    padding=20.0,
    css_styles=["fill:#08427B", "color:#FFFFFF"],
    css_classes="c4-shape c4-person",
    dom_id="id-a",
    look="classic",
    shape="person",
    data=C4(
      stereotype="[Person]",
      font_family="\"Open Sans\", sans-serif",
      font_size=14.0,
      bold=false,
    ),
    description=["A customer of the bank"],
  ).placed(x=100.0, y=100.0, width=216.0, label_style="")
  let parent = @dom.Element::new("g")
  let painter = Painter::new(
    @config.Config::new(),
    diagram_type="c4",
    diagram_id="id",
  )
  let element = painter.draw_shape(parent, node)
  // The head's radius is 0.23 of the width; the body holds the label and
  // its padding.
  inspect(
    element.child_elements()[0].to_html(),
    content=(
      #|<g class="basic label-container"><rect x="-108" y="-1.0598810546875068" width="216" height="88.066162109375" rx="38.232" ry="38.232" style="fill:#08427B !important"></rect><circle cx="0" cy="-37.326281054687506" r="49.68" style="fill:#08427B !important"></circle></g>
    ),
  )
  debug_inspect(
    (node.width, node.height),
    content=(
      #|(Some(216), Some(174.0125732421875))
    ),
  )
  // Lines leave the silhouette, not the bounding box: straight up through
  // the top of the head, sideways through the body.
  debug_inspect(
    node.leaves_at({ x: 100.0, y: -500.0, }),
    content=(
      #|Some({ x: 100, y: 12.993713378906248 })
    ),
  )
  debug_inspect(
    node.leaves_at({ x: 900.0, y: 143.0, }),
    content=(
      #|Some({ x: 190.60976725860306, y: 104.87027499014991 })
    ),
  )
}
