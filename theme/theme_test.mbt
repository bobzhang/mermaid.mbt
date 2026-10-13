///|
test "every theme builds" {
  for name in @theme.theme_names {
    guard @theme.Theme::new(name) is Some(theme) else {
      fail("theme \{name} is missing")
    }
    assert_true(theme.names().length() > 200)
    assert_true(theme.text("primaryColor") != "undefined")
  }
  assert_true(@theme.Theme::new("nope") is None)
}

///|
test "default theme variables" {
  guard @theme.Theme::new("default") is Some(theme) else {
    fail("missing theme")
  }
  let names = [
    "primaryColor", "secondaryColor", "tertiaryColor", "primaryBorderColor", "primaryTextColor",
    "lineColor", "textColor", "mainBkg", "nodeBorder", "clusterBkg", "titleColor",
    "edgeLabelBackground", "actorBorder", "labelTextColor", "noteBkgColor", "sectionBkgColor",
    "taskTextColor", "cScale0", "cScale11", "cScalePeer1", "cScaleInv3", "cScaleLabel0",
    "surface0", "surfacePeer4", "pie1", "pie2", "pie3", "pie12", "pieTitleTextSize",
    "pieOuterStrokeWidth", "pieOpacity", "quadrantPointFill", "git0", "gitInv0",
    "gitBranchLabel0", "rowOdd", "rowEven", "fontFamily", "fontSize", "THEME_COLOR_LIMIT",
    "useGradient", "missing",
  ]
  inspect(
    names.map(name => "\{name}: \{theme.text(name)}").join("\n"),
    content=(
      #|primaryColor: #ECECFF
      #|secondaryColor: #ffffde
      #|tertiaryColor: hsl(80, 100%, 96.2745098039%)
      #|primaryBorderColor: hsl(240, 60%, 86.2745098039%)
      #|primaryTextColor: #131300
      #|lineColor: #333333
      #|textColor: #333
      #|mainBkg: #ECECFF
      #|nodeBorder: #9370DB
      #|clusterBkg: #ffffde
      #|titleColor: #333
      #|edgeLabelBackground: rgba(232,232,232, 0.8)
      #|actorBorder: #9370DB
      #|labelTextColor: black
      #|noteBkgColor: #fff5ad
      #|sectionBkgColor: rgba(102, 102, 255, 0.49)
      #|taskTextColor: white
      #|cScale0: hsl(240, 100%, 76.2745098039%)
      #|cScale11: hsl(210, 100%, 76.2745098039%)
      #|cScalePeer1: hsl(60, 100%, 48.5294117647%)
      #|cScaleInv3: hsl(90, 100%, 86.2745098039%)
      #|cScaleLabel0: #ffffff
      #|surface0: hsl(270, 100%, 91.2745098039%)
      #|surfacePeer4: hsl(270, 100%, 69.2745098039%)
      #|pie1: #ECECFF
      #|pie2: #ffffde
      #|pie3: hsl(80, 100%, 56.2745098039%)
      #|pie12: hsl(0, 100%, 66.2745098039%)
      #|pieTitleTextSize: 25px
      #|pieOuterStrokeWidth: 2px
      #|pieOpacity: 0.7
      #|quadrantPointFill: hsl(240, 100%, NaN%)
      #|git0: hsl(240, 100%, 46.2745098039%)
      #|gitInv0: hsl(60, 100%, 3.7254901961%)
      #|gitBranchLabel0: #ffffff
      #|rowOdd: hsl(240, 100%, 100%)
      #|rowEven: hsl(240, 100%, 97.2745098039%)
      #|fontFamily: "trebuchet ms", verdana, arial, sans-serif
      #|fontSize: 16px
      #|THEME_COLOR_LIMIT: 12
      #|useGradient: false
      #|missing: undefined
    ),
  )
  inspect(
    theme.nested("xyChart", "plotColorPalette").stringify(),
    content=(
      #|"#ECECFF,#8493A6,#FFC3A0,#DCDDE1,#B8E994,#D1A36F,#C3CDE6,#FFB6C1,#496078,#F8F3E3"
    ),
  )
  inspect(
    theme.nested("radar", "curveOpacity").stringify(),
    content=(
      #|0.5
    ),
  )
}

///|
test "overrides feed derived colors and win over them" {
  let overrides : Map[String, Json] = {
    "primaryColor": "#ff0000",
    "pie2": "#00ff00",
    "xyChart": { "titleColor": "#123456" },
  }
  guard @theme.Theme::new("base", overrides~) is Some(theme) else {
    fail("missing theme")
  }
  inspect(
    ["primaryColor", "pie1", "pie2", "primaryBorderColor", "mainBkg"]
    .map(name => "\{name}: \{theme.text(name)}")
    .join("\n"),
    content=(
      #|primaryColor: #ff0000
      #|pie1: #ff0000
      #|pie2: #00ff00
      #|primaryBorderColor: hsl(0, 60%, 40%)
      #|mainBkg: #ff0000
    ),
  )
  // The other generated fields of `xyChart` survive the override.
  inspect(
    theme.nested("xyChart", "titleColor").stringify(),
    content=(
      #|"#123456"
    ),
  )
  inspect(
    theme.nested("xyChart", "backgroundColor").stringify(),
    content=(
      #|"#f4f4f4"
    ),
  )
}

///|
test "base theme drops the gradient for an explicit node border" {
  guard @theme.Theme::new("base") is Some(plain) else { fail("missing theme") }
  inspect(plain.flag("useGradient"), content="true")
  guard @theme.Theme::new("base", overrides={ "nodeBorder": "#000" })
    is Some(bordered) else {
    fail("missing theme")
  }
  inspect(bordered.flag("useGradient"), content="false")
}
