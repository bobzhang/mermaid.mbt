///|
/// Why a radar chart cannot be rendered.
pub(all) suberror RadarError {
  /// The chart is invalid, with upstream's message.
  Invalid(String)
  /// What the port cannot reproduce exactly and therefore refuses.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// An axis: a spoke of the chart.
pub struct Axis {
  name : String
  label : String
} derive(Debug)

///|
/// A curve: one value per axis, in the order of the axes.
pub struct Curve {
  name : String
  label : String
  entries : Array[Double]
} derive(Debug)

///|
/// How the grid behind the curves is drawn.
pub(all) enum Graticule {
  Circle
  Polygon
} derive(Eq, Debug)

///|
/// A parsed radar chart.
pub struct Radar {
  axes : Array[Axis]
  curves : Array[Curve]
  show_legend : Bool
  ticks : Double
  /// The value at the rim; the largest entry when not given.
  max : Double?
  min : Double
  graticule : Graticule
  title : String
  acc_title : String
  acc_description : String
}

///|
/// The same chart under another title.
pub fn Radar::with_title(self : Radar, title : String) -> Radar {
  { ..self, title, }
}

///|
/// More ticks than this make the chart unreadable; upstream caps them.
const MAX_TICKS : Double = 32.0

///|
/// An entry of a curve as written: a value, for a named axis or for the
/// next one.
priv struct Entry {
  axis : String?
  value : Double
}

///|
/// A curve as written.
priv struct RawCurve {
  name : String
  label : String?
  entries : Array[Entry]
}

///|
/// The grammar's `Label` fragment: `[` STRING `]`.
fn label(tokens : @langium.TokenStream) -> String? raise @langium.ParseError {
  guard tokens.accept("[") is Some(_) else { return None }
  let text = tokens.expect("STRING").text
  tokens.expect("]") |> ignore
  // The value converter resolves the quotes and escapes.
  @langium.Lexer::new(text).string()
}

///|
fn number(tokens : @langium.TokenStream) -> Double raise @langium.ParseError {
  let text = tokens.expect("NUMBER").text
  @string.parse_double(text) catch {
    _ => tokens.fail("Expecting a number")
  }
}

///|
/// The grammar's `Entries` fragment: values in the order of the axes, or
/// values named after their axes; not both.
fn entries(
  tokens : @langium.TokenStream,
) -> Array[Entry] raise @langium.ParseError {
  let skip_newlines = () => {
    while tokens.accept("NEWLINE") is Some(_) {

    }
  }
  skip_newlines()
  let detailed = tokens.at("ID")
  let entries = []
  while true {
    if detailed {
      let axis = tokens.expect("ID").text
      tokens.accept(":") |> ignore
      entries.push({ axis: Some(axis), value: number(tokens), })
    } else {
      entries.push({ axis: None, value: number(tokens), })
    }
    guard tokens.accept(",") is Some(_) else { break }
    skip_newlines()
  }
  skip_newlines()
  entries
}

///|
/// Parse radar chart source, following the Langium grammar:
///
/// ```text
/// Radar: NEWLINE* ("radar-beta" | "radar-beta:" | "radar-beta" ":") NEWLINE*
///        ( TitleAndAccessibilities
///        | "axis" Axis ("," Axis)*
///        | "curve" Curve ("," Curve)*
///        | Option ("," Option)*
///        | NEWLINE )*
/// Axis: ID ("[" STRING "]")?
/// Curve: ID ("[" STRING "]")? "{" Entries "}"
/// Option: "showLegend" BOOLEAN | "ticks" NUMBER | "max" NUMBER
///       | "min" NUMBER | "graticule" GRATICULE
/// ```
pub fn parse(source : String) -> Radar raise {
  let tokens = @langium.TokenStream::new(
    @langium.tokenize(source, token_types),
    source.length(),
  )
  while tokens.accept("NEWLINE") is Some(_) {

  }
  if tokens.accept("radar-beta:") is None {
    tokens.expect("radar-beta") |> ignore
    tokens.accept(":") |> ignore
  }
  let axes : Array[Axis] = []
  let raw_curves : Array[RawCurve] = []
  let mut show_legend = true
  let mut ticks = 5.0
  let mut max : Double? = None
  let mut min = 0.0
  let mut graticule = Circle
  let mut title = ""
  let mut acc_title = ""
  let mut acc_description = ""
  // An empty title or description leaves an earlier one in place, as
  // `populateCommonDb` only sets what is not empty.
  let common = (text : String, name : String) => {
    if text.contains("<") {
      raise Unsupported("markup in the \{name} of a radar chart: \{text}")
    }
    text
  }
  while !tokens.at("EOF") {
    match tokens.peek() {
      "NEWLINE" => tokens.expect("NEWLINE") |> ignore
      "ACC_DESCR" | "ACC_TITLE" | "TITLE" as kind => {
        let text = tokens.expect(kind).text
        let lexer = @langium.Lexer::new(text)
        match kind {
          "ACC_DESCR" => acc_description = lexer.acc_descr().unwrap_or("")
          "ACC_TITLE" => acc_title = lexer.acc_title().unwrap_or("")
          _ => title = lexer.title().unwrap_or("")
        }
        // EOL: line breaks, or the end.
        if !tokens.at("EOF") {
          tokens.expect("NEWLINE") |> ignore
        }
      }
      "axis" => {
        tokens.expect("axis") |> ignore
        while true {
          let name = tokens.expect("ID").text
          // `axis.label ?? axis.name`
          let label = label(tokens).unwrap_or(name)
          axes.push({ name, label, })
          guard tokens.accept(",") is Some(_) else { break }
        }
      }
      "curve" => {
        tokens.expect("curve") |> ignore
        while true {
          let name = tokens.expect("ID").text
          let label = label(tokens)
          tokens.expect("{") |> ignore
          let entries = entries(tokens)
          tokens.expect("}") |> ignore
          raw_curves.push({ name, label, entries, })
          guard tokens.accept(",") is Some(_) else { break }
        }
      }
      "showLegend" | "ticks" | "max" | "min" | "graticule" =>
        while true {
          match tokens.peek() {
            "showLegend" => {
              tokens.expect("showLegend") |> ignore
              show_legend = tokens.expect("BOOLEAN").text == "true"
            }
            "ticks" => {
              tokens.expect("ticks") |> ignore
              ticks = number(tokens)
            }
            "max" => {
              tokens.expect("max") |> ignore
              max = Some(number(tokens))
            }
            "min" => {
              tokens.expect("min") |> ignore
              min = number(tokens)
            }
            "graticule" => {
              tokens.expect("graticule") |> ignore
              graticule = if tokens.expect("GRATICULE").text == "polygon" {
                Polygon
              } else {
                Circle
              }
            }
            _ => tokens.fail("Expecting an option")
          }
          guard tokens.accept(",") is Some(_) else { break }
        }
      _ => tokens.fail("Expecting an axis, a curve, an option or a title")
    }
  }
  // `setCurves`, once every axis is known: entries named after axes are
  // put in the order of the axes.
  let curves : Array[Curve] = []
  for curve in raw_curves {
    let values = if curve.entries[0].axis is None {
      curve.entries.map(entry => entry.value)
    } else {
      if axes.is_empty() {
        raise Invalid(
          "Axes must be populated before curves for reference entries",
        )
      }
      let values = []
      for axis in axes {
        guard curve.entries.search_by(entry => entry.axis == Some(axis.name))
          is Some(index) else {
          raise Invalid("Missing entry for axis \{axis.label}")
        }
        values.push(curve.entries[index].value)
      }
      values
    }
    curves.push({
      name: curve.name,
      label: curve.label.unwrap_or(curve.name),
      entries: values,
    })
  }
  {
    axes,
    curves,
    show_legend,
    ticks: if ticks > MAX_TICKS {
      MAX_TICKS
    } else {
      ticks
    },
    max,
    min,
    graticule,
    title: common(title, "title"),
    acc_title: common(acc_title, "accessible title"),
    acc_description: common(acc_description, "accessible description"),
  }
}
