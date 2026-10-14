///|
test "hex colors round-trip unchanged" {
  inspect(
    @color.Channels::parse("#ECECFF").stringify(),
    content=(
      #|#ECECFF
    ),
  )
  inspect(
    @color.lighten("#fff", 0.0),
    content=(
      #|#fff
    ),
  )
  let c = @color.Channels::parse("#1234")
  debug_inspect(
    (c.r(), c.g(), c.b(), c.a()),
    content=(
      #|(17, 34, 51, 0.26666666666666666)
    ),
  )
  let c = @color.Channels::parse("#11223380")
  debug_inspect(
    (c.r(), c.g(), c.b(), c.a()),
    content=(
      #|(17, 34, 51, 0.5019607843137255)
    ),
  )
}

///|
test "keywords resolve through the hex table" {
  inspect(
    @color.darken("White", 0.0),
    content=(
      #|#ffffff
    ),
  )
  inspect(
    @color.to_rgba("transparent"),
    content=(
      #|rgba(0, 0, 0, 0)
    ),
  )
  inspect(
    @color.invert("navy"),
    content=(
      #|#ffff7f
    ),
  )
}

///|
test "rgb and hsl functions" {
  let c = @color.Channels::parse("rgba(232,232,232, 0.8)")
  debug_inspect(
    (c.r(), c.g(), c.b(), c.a()),
    content=(
      #|(232, 232, 232, 0.8)
    ),
  )
  let c = @color.Channels::parse("rgb(100% 50% 0% / 50%)")
  debug_inspect(
    (c.r(), c.g(), c.b(), c.a()),
    content=(
      #|(254.99999999999997, 127.49999999999999, 0, 0.5)
    ),
  )
  let c = @color.Channels::parse("hsl(0.5turn, 100%, 50%)")
  debug_inspect(
    (c.h(), c.r(), c.g(), c.b()),
    content=(
      #|(180, 0, 254.99999999999994, 255)
    ),
  )
  inspect(
    @color.to_rgba("hsl(120, 100%, 25%)"),
    content=(
      #|rgb(0, 127.5, 0)
    ),
  )
}

///|
test "unsupported colors raise" {
  try @color.Channels::parse("calculated") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|Unsupported("calculated")
        ),
      )
  } noraise {
    _ => fail("expected to raise")
  }
  try @color.adjust("#fff", h=10.0, r=10.0) catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|MixedChannels
        ),
      )
  } noraise {
    _ => fail("expected to raise")
  }
}

///|
test "adjust derives the default theme colors" {
  // tertiaryColor, primaryBorderColor and pie3 of mermaid's default theme.
  inspect(
    @color.adjust("#ECECFF", h=-160.0),
    content=(
      #|hsl(80, 100%, 96.2745098039%)
    ),
  )
  inspect(
    @color.adjust("#ECECFF", s=-40.0, l=-10.0),
    content=(
      #|hsl(240, 60%, 86.2745098039%)
    ),
  )
  inspect(
    @color.adjust("hsl(80, 100%, 96.2745098039%)", l=-40.0),
    content=(
      #|hsl(80, 100%, 56.2745098039%)
    ),
  )
  inspect(
    @color.adjust("#ECECFF", r=5.0, g=5.0, b=5.0),
    content=(
      #|#f1f1ff
    ),
  )
  inspect(
    @color.adjust("#ffffde", h=-64.0),
    content=(
      #|hsl(-4, 100%, 93.5294117647%)
    ),
  )
}

///|
test "lighten, darken, invert, rgba" {
  inspect(
    @color.darken("#ECECFF", 10.0),
    content=(
      #|hsl(240, 100%, 86.2745098039%)
    ),
  )
  inspect(
    @color.lighten("#ECECFF", 75.0),
    content=(
      #|hsl(240, 100%, 100%)
    ),
  )
  inspect(
    @color.invert("#f4f4f4"),
    content=(
      #|#0b0b0b
    ),
  )
  inspect(
    @color.invert("#ECECFF"),
    content=(
      #|#131300
    ),
  )
  inspect(
    @color.rgba(102.0, 102.0, 255.0, a=0.49),
    content=(
      #|rgba(102, 102, 255, 0.49)
    ),
  )
  inspect(
    @color.rgba(1.5, 2.0, 3.0),
    content=(
      #|rgb(1.5, 2, 3)
    ),
  )
  inspect(
    @color.transparentize("#ff0000", 0.5),
    content=(
      #|rgba(255, 0, 0, 0.5)
    ),
  )
  inspect(
    @color.mix("#ff0000", "#0000ff"),
    content=(
      #|rgb(127.5, 0, 127.5)
    ),
  )
}

///|
test "luminance and darkness" {
  inspect(
    @color.is_dark("#1f2020"),
    content=(
      #|true
    ),
  )
  inspect(
    @color.is_dark("#ECECFF"),
    content=(
      #|false
    ),
  )
  inspect(
    @color.luminance("white"),
    content=(
      #|1
    ),
  )
  inspect(
    @color.hue("#ECECFF"),
    content=(
      #|240
    ),
  )
}

///|
/// What `element.style.stroke = color` reads back as in Chrome, for
/// colors whose channels land on or next to a half.
test "hsl colors as the browser resolves them" {
  let rgb = (color : String) => {
    let (r, g, b) = @color.Channels::parse(color).to_css_rgb()
    "\{r} \{g} \{b}"
  }
  inspect(rgb("hsl(247.5, 0%, 9.2156862745%)"), content="24 24 24")
  inspect(rgb("hsl(0, 0%, 9.0196078431%)"), content="23 23 23")
  inspect(rgb("hsl(235.3404, 100%, 65.0%)"), content="77 90 255")
  inspect(rgb("hsl(176.0, 100%, 65.0%)"), content="77 255 243")
  inspect(rgb("hsl(216.2, 28.25%, 34.7055%)"), content="63 83 114")
  inspect(rgb("hsl(120, 40%, 2.9411764706%)"), content="5 11 5")
  inspect(rgb("hsl(120, 40%, 10.7843137255%)"), content="17 39 17")
  inspect(rgb("hsl(247.5, 0%, 3.3333333333%)"), content="9 9 9")
}
