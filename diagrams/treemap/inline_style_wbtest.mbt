///|
test "an untouched style keeps its text" {
  let style = InlineStyle::parse(
    "text-anchor: middle; dominant-baseline: middle; font-size: 38px;fill:#ffffff;",
  )
  style.set("font-size", "38px")
  inspect(style.changed, content="false")
  inspect(
    style.text(),
    content="text-anchor: middle; dominant-baseline: middle; font-size: 38px;fill:#ffffff;",
  )
}

///|
test "a change serializes the declarations as the CSSOM holds them" {
  let style = InlineStyle::parse(
    "text-anchor: middle; dominant-baseline: middle; font-size: 38px;fill:#ffffff;fill:blue !important;font-size:20px !important",
  )
  // Of two declarations the important one counts, and comes last.
  inspect(style.get("font-size").unwrap_or(""), content="20px")
  style.set("font-size", "19px")
  style.set("display", "none")
  inspect(
    style.text(),
    content="text-anchor: middle; dominant-baseline: middle; fill: blue !important; font-size: 19px; display: none;",
  )
  let hsl = InlineStyle::parse(
    "font-size: 28px;fill:hsl(0, 100%, 6.7647058824%);",
  )
  hsl.set("font-size", "23px")
  inspect(hsl.text(), content="font-size: 23px; fill: rgb(35, 0, 0);")
}

///|
test "a declaration the port cannot vouch for is refused when it must be written" {
  let style = InlineStyle::parse(
    "font-size: 38px;fill:black;text-decoration:underline !important",
  )
  inspect(
    style.text(),
    content="font-size: 38px;fill:black;text-decoration:underline !important",
  )
  style.set("font-size", "30px")
  let refused = try {
    style.text() |> ignore
    false
  } catch {
    Unsupported(_) => true
    _ => false
  }
  inspect(refused, content="true")
}

///|
test "class styles are sorted into those for text and those for shapes" {
  let split = split_styles([
    "fill:#f00", "color : blue", "stroke-width:3px", "", "fill:red",
  ])
  inspect(split.label_styles, content="color:blue !important")
  inspect(
    split.node_styles,
    content="fill:red !important;stroke-width:3px !important;: !important",
  )
  json_inspect(split.border_styles, content=["stroke-width:3px !important"])
}

///|
test "the scale the reference browser displays a diagram at" {
  // 1000 wide in a 740 pixel page.
  inspect(display_scale(1000.0, 400.0, true), content="0.7400000095367432")
  // With a title the height is cut to a layout unit, and decides.
  inspect(display_scale(1000.0, 430.0, true), content="0.7399709224700928")
  // Tall enough for a scrollbar, which narrows the page.
  inspect(display_scale(1000.0, 607.5, true), content="0.7250000238418579")
  // Narrower than the page, or of a fixed size: as drawn.
  inspect(display_scale(500.0, 300.0, true), content="1")
  inspect(display_scale(1000.0, 400.0, false), content="1")
}
