// Values of declarations as Blink parses and serializes them: numbers with
// six significant digits, units in lower case, `calc()` simplified, colors
// resolved.

///|
/// Units of length, in lower case.
let length_units : Set[String] = Set::from_array([
  "px", "cm", "mm", "q", "in", "pt", "pc", "em", "rem", "ex", "rex", "ch", "rch",
  "ic", "ric", "cap", "rcap", "lh", "rlh", "vw", "vh", "vi", "vb", "vmin", "vmax",
  "svw", "svh", "svi", "svb", "svmin", "svmax", "lvw", "lvh", "lvi", "lvb", "lvmin",
  "lvmax", "dvw", "dvh", "dvi", "dvb", "dvmin", "dvmax", "cqw", "cqh", "cqi", "cqb",
  "cqmin", "cqmax",
])

///|
/// Units of angle.
let angle_units : Set[String] = Set::from_array(["deg", "rad", "grad", "turn"])

///|
/// What a numeric value may be.
priv struct NumericKind {
  /// Lengths.
  length : Bool
  /// Percentages.
  percentage : Bool
  /// Angles.
  angle : Bool
  /// Plain numbers (for a length: SVG's unitless lengths).
  number : Bool
  /// A bare 0 is a length, `0px`.
  zero_length : Bool
  /// Negative values are allowed.
  negative : Bool
  /// Only integers.
  integer : Bool
}

///|
fn number_text(value : Double) -> String {
  @dom.css_number_text(value)
}

///|
/// A numeric component as `kind` takes it, serialized.
fn numeric(item : Component, kind : NumericKind) -> String raise CssomError {
  match item {
    Preserved(Number(value, integer, _), _) => {
      guard kind.negative || value >= 0.0 else { raise Invalid }
      if kind.number {
        guard integer || !kind.integer else { raise Invalid }
        number_text(value)
      } else if kind.zero_length && value == 0.0 {
        "0px"
      } else {
        raise Invalid
      }
    }
    Preserved(Percentage(value), _) => {
      guard kind.percentage && (kind.negative || value >= 0.0) else {
        raise Invalid
      }
      number_text(value) + "%"
    }
    Preserved(Dimension(value, _, unit, _), _) => {
      let unit = ascii_lower(unit)
      guard (kind.length && length_units.contains(unit)) ||
        (kind.angle && angle_units.contains(unit)) else {
        raise Invalid
      }
      guard kind.negative || value >= 0.0 else { raise Invalid }
      number_text(value) + unit
    }
    Func(name, arguments, _, _) if ascii_lower(name) == "calc" =>
      calc(arguments, kind)
    Func(name, _, _, _) if ascii_lower(name)
      is ("min"
      | "max"
      | "clamp"
      | "round"
      | "mod"
      | "rem"
      | "abs"
      | "sign"
      | "sin"
      | "cos"
      | "tan"
      | "asin"
      | "acos"
      | "atan"
      | "atan2"
      | "pow"
      | "sqrt"
      | "hypot"
      | "log"
      | "exp"
      | "var"
      | "env"
      | "attr"
      | "anchor"
      | "anchor-size"
      | "calc-size") => raise Unported("\{ascii_lower(name)}()")
    _ => raise Invalid
  }
}

///|
/// A sum of terms by unit (`""` for numbers, `"%"`), canonical units
/// for absolute lengths (px) and angles (deg).
priv struct CalcSum {
  terms : Map[String, Double]
}

///|
fn canonical_unit(value : Double, unit : String) -> (Double, String) {
  match unit {
    "cm" => (value * 96.0 / 2.54, "px")
    "mm" => (value * 96.0 / 25.4, "px")
    "q" => (value * 96.0 / 101.6, "px")
    "in" => (value * 96.0, "px")
    "pt" => (value * 96.0 / 72.0, "px")
    "pc" => (value * 16.0, "px")
    "rad" => (value * 180.0 / @math.PI, "deg")
    "grad" => (value * 0.9, "deg")
    "turn" => (value * 360.0, "deg")
    _ => (value, unit)
  }
}

///|
fn CalcSum::is_number(self : CalcSum) -> Bool {
  self.terms.keys().all(unit => unit == "")
}

///|
fn CalcSum::number(self : CalcSum) -> Double {
  self.terms.get("").unwrap_or(0.0)
}

///|
fn CalcSum::scaled(self : CalcSum, factor : Double) -> CalcSum {
  let terms = Map([])
  for unit, value in self.terms {
    terms[unit] = value * factor
  }
  { terms, }
}

///|
fn CalcSum::plus(self : CalcSum, other : CalcSum, sign : Double) -> CalcSum {
  let terms = Map::from_iter(self.terms.iter())
  for unit, value in other.terms {
    terms[unit] = terms.get(unit).unwrap_or(0.0) + sign * value
  }
  { terms, }
}

///|
/// A calculation's operand: a value, a parenthesized sum, or a nested
/// `calc()`.
fn calc_value(item : Component) -> CalcSum raise CssomError {
  match item {
    Preserved(Number(value, _, _), _) => { terms: Map([("", value)]), }
    Preserved(Percentage(value), _) => { terms: Map([("%", value)]), }
    Preserved(Dimension(value, _, unit, _), _) => {
      let unit = ascii_lower(unit)
      guard length_units.contains(unit) || angle_units.contains(unit) else {
        if unit
          is ("s" | "ms" | "hz" | "khz" | "dpi" | "dpcm" | "dppx" | "x" | "fr") {
          raise Unported("calc() with \{unit}")
        }
        raise Invalid
      }
      let (value, unit) = canonical_unit(value, unit)
      { terms: Map([(unit, value)]), }
    }
    Block('(', contents, _, _) => calc_sum(trim_components(contents[:]))
    Func(name, arguments, _, _) if ascii_lower(name) == "calc" =>
      calc_sum(trim_components(arguments[:]))
    Func(name, _, _, _) => raise Unported("\{ascii_lower(name)}() in calc()")
    Preserved(Ident(name), _) if ascii_lower(name)
      is ("e" | "pi" | "infinity" | "-infinity" | "nan") =>
      raise Unported("the constant \{name} in calc()")
    _ => raise Invalid
  }
}

///|
/// `a * b` or `a / b` chains.
fn calc_product(items : Array[Component]) -> CalcSum raise CssomError {
  let operands = []
  let operators = []
  for item in items {
    match item {
      Preserved(Whitespace, _) => ()
      Preserved(Delim('*' | '/' as c), _) => operators.push(c)
      _ => {
        guard operands.length() == operators.length() else { raise Invalid }
        operands.push(calc_value(item))
      }
    }
  }
  guard operands.length() == operators.length() + 1 else { raise Invalid }
  let mut result = operands[0]
  for i, operator in operators {
    let right = operands[i + 1]
    if operator == '*' {
      if right.is_number() {
        result = result.scaled(right.number())
      } else if result.is_number() {
        result = right.scaled(result.number())
      } else {
        raise Invalid
      }
    } else {
      guard right.is_number() else { raise Invalid }
      result = result.scaled(1.0 / right.number())
    }
  }
  result
}

///|
/// A sum: products joined by `+` and `-`, which need white space on both
/// sides.
fn calc_sum(items : Array[Component]) -> CalcSum raise CssomError {
  guard !items.is_empty() else { raise Invalid }
  let mut result : CalcSum? = None
  let mut sign = 1.0
  let mut start = 0
  let flush = (end : Int32) => {
    let product = calc_product(trim_components(items[start:end]))
    result = Some(
      match result {
        Some(sum) => sum.plus(product, sign)
        None => product
      },
    )
  }
  for i, item in items {
    if item is Preserved(Delim('+' | '-' as c), _) {
      guard i > 0 &&
        items[i - 1].is_whitespace() &&
        i + 1 < items.length() &&
        items[i + 1].is_whitespace() else {
        raise Invalid
      }
      flush(i)
      sign = if c == '+' { 1.0 } else { -1.0 }
      start = i + 1
    }
  }
  flush(items.length())
  result.unwrap()
}

///|
/// A `calc()` as `kind` takes it: simplified, then serialized with the
/// number first, then the percentage, then the units in ASCII order.
fn calc(
  arguments : Array[Component],
  kind : NumericKind,
) -> String raise CssomError {
  let sum = calc_sum(trim_components(arguments[:]))
  let units = sum.terms.keys().collect()
  guard !units.is_empty() else { raise Invalid }
  for unit in units {
    let allowed = match unit {
      "" => kind.number
      "%" => kind.percentage
      _ if angle_units.contains(unit) => kind.angle
      _ => kind.length
    }
    guard allowed else { raise Invalid }
  }
  // A plain number mixed with anything else has no type.
  if units.length() > 1 && units.contains("") {
    raise Invalid
  }
  units.sort_by((a, b) => {
    let rank = (unit : String) => {
      match unit {
        "" => 0
        "%" => 1
        _ => 2
      }
    }
    if rank(a) != rank(b) {
      rank(a) - rank(b)
    } else {
      ascii_compare(a, b)
    }
  })
  let out = StringBuilder()
  out.write_string("calc(")
  for i, unit in units {
    let value = sum.terms[unit]
    if i == 0 {
      out.write_string(number_text(value))
    } else if value < 0.0 {
      out.write_string(" - \{number_text(-value)}")
    } else {
      out.write_string(" + \{number_text(value)}")
    }
    out.write_string(unit)
  }
  out.write_string(")")
  out.to_string()
}

///|
/// Strings in code point order.
fn ascii_compare(a : String, b : String) -> Int32 {
  let a = a.to_array()
  let b = b.to_array()
  for i in 0..<a.length().min(b.length()) {
    if a[i] != b[i] {
      return a[i].to_int() - b[i].to_int()
    }
  }
  a.length() - b.length()
}
