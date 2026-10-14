///|
/// The parsed chart as JSON, or the error.
fn dump(source : String) -> Json {
  let radar = @radar.parse(source) catch {
    @langium.ParseError(message~, ..) =>
      return Json::string("syntax: " + message)
    @radar.Invalid(message) => return Json::string("invalid: " + message)
    _ => return Json::string("error")
  }
  {
    "axes": radar.axes.map(axis => "\{axis.name}=\{axis.label}"),
    "curves": radar.curves.map(curve => {
      let entries : Json = Json(curve.entries)
      let label : Json = "\{curve.name}=\{curve.label}"
      [label, entries]
    }),
    "options": [
      Json(radar.show_legend),
      Json(radar.ticks),
      Json(radar.max),
      Json(radar.min),
      Json::string(
        if radar.graticule == @radar.Polygon {
          "polygon"
        } else {
          "circle"
        },
      ),
    ],
    "title": radar.title,
  }
}

///|
test "axes, curves and options, in any order and on any line" {
  json_inspect(
    dump(
      "radar-beta: curve x{1, 2.5} axis a[\"A\"], b max 5, ticks 3 graticule polygon\ntitle  The   title\nshowLegend false",
    ),
    content={
      "axes": ["a=A", "b=b"],
      "curves": [["x=x", [1, 2.5]]],
      "options": [false, 3, [5], 0, "polygon"],
      "title": "The title",
    },
  )
}

///|
test "entries named after axes are put in the order of the axes" {
  json_inspect(
    dump("radar-beta\naxis a, b, c\ncurve x[\"X\"]{ c: 3, a 1,\n b: 2 }"),
    content={
      "axes": ["a=a", "b=b", "c=c"],
      "curves": [["x=X", [1, 2, 3]]],
      "options": [true, 5, null, 0, "circle"],
      "title": "",
    },
  )
  json_inspect(
    dump("radar-beta\naxis a, b[\"B\"]\ncurve x{ a: 1 }"),
    content="invalid: Missing entry for axis B",
  )
  json_inspect(
    dump("radar-beta\ncurve x{ a: 1 }"),
    content="invalid: Axes must be populated before curves for reference entries",
  )
}

///|
test "keywords are not names, but names may start with them" {
  json_inspect(
    dump("radar-beta\naxis max"),
    content="syntax: Expecting token of type 'ID' but found 'max'",
  )
  json_inspect(dump("radar-beta\naxis maximum, axis-1, curved"), content={
    "axes": ["maximum=maximum", "axis-1=axis-1", "curved=curved"],
    "curves": [],
    "options": [true, 5, null, 0, "circle"],
    "title": "",
  })
  // `title` swallows the rest of its line, even in the middle of one.
  json_inspect(
    dump("radar-beta\naxis a, titled"),
    content="syntax: Expecting token of type 'ID' but found ' title'",
  )
}

///|
test "the last option of a name wins, and ticks are capped" {
  json_inspect(dump("radar-beta\nmax 1\nmax 2, min 1\nticks 99"), content={
    "axes": [],
    "curves": [],
    "options": [true, 32, [2], 1, "circle"],
    "title": "",
  })
}

///|
test "numbers: no sign, no leading zero, no trailing dot" {
  json_inspect(
    dump("radar-beta\naxis a\ncurve x{-1}"),
    content="syntax: unexpected character: ->-<- at offset: 26",
  )
  json_inspect(
    dump("radar-beta\naxis a\ncurve x{01}"),
    content="syntax: Expecting token of type '}' but found '1'",
  )
  json_inspect(
    dump("radar-beta\naxis a\ncurve x{1.}"),
    content="syntax: unexpected character: ->.<- at offset: 27",
  )
  json_inspect(dump("radar-beta\naxis a\ncurve x{0.50}"), content={
    "axes": ["a=a"],
    "curves": [["x=x", [0.5]]],
    "options": [true, 5, null, 0, "circle"],
    "title": "",
  })
}
