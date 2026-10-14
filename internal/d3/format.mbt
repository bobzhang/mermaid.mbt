// d3-format 3.1.0 with its default locale: thousands separated by commas
// in groups of three, `$` for currency, a point for decimals.

///|
/// d3-format refuses a specifier it cannot parse.
pub(all) suberror FormatError {
  InvalidFormat(String)
} derive(Eq, Debug)

///|
/// A number format: `d3.format(specifier)`.
pub struct Format {
  priv fill : String
  priv align : String
  priv sign : String
  priv zero : Bool
  priv width : Int32?
  priv comma : Bool
  priv precision : Int32
  priv trim : Bool
  /// The type after defaults are applied: a key of d3's `formatTypes`.
  priv kind : String
  priv prefix : String
  priv suffix : String
}

///|
/// d3-format's `formatSpecifier` expression:
/// `[[fill]align][sign][symbol][0][width][,][.precision][~][type]`.
let specifier_pattern : @jsregex.Regex = try! @jsregex.Regex::compile(
  (
    #|^(?:(.)?([<>=^]))?([+\-( ])?([$#])?(0)?(\d+)?(,)?(\.\d+)?(~)?([a-z%])?$
  ),
  flags="i",
)

///|
/// SI prefixes, from yocto to yotta; the empty one is at index 8.
let si_prefixes : Array[String] = [
  "y", "z", "a", "f", "p", "n", "\u{b5}", "m", "", "k", "M", "G", "T", "P", "E",
  "Z", "Y",
]

///|
/// `d3.format(specifier)`.
pub fn format(specifier : String) -> Format raise FormatError {
  guard specifier_pattern.exec(specifier) is Some(found) else {
    raise InvalidFormat("invalid format: \{specifier}")
  }
  let fill = found.group(1).unwrap_or(" ")
  let align = found.group(2).unwrap_or(">")
  let sign = found.group(3).unwrap_or("-")
  let symbol = found.group(4).unwrap_or("")
  let zero = found.group(5) is Some(_)
  // Widths and precisions beyond any use are as good as the largest.
  let to_int = (digits : String) => {
    @string.parse_int(digits) catch {
      _ => 1000000
    }
  }
  let width = found.group(6).map(to_int)
  let mut comma = found.group(7) is Some(_)
  let mut precision = found.group(8).map(text => to_int(text[1:].to_owned()))
  let mut trim = found.group(9) is Some(_)
  let mut kind = found.group(10).unwrap_or("")
  // The "n" format is an alias for ",g".
  if kind == "n" {
    comma = true
    kind = "g"
  } else if !(kind
    is ("%"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "o"
    | "p"
    | "r"
    | "s"
    | "X"
    | "x")) {
    // The "" format, and unknown types: "~g" with a precision of 12.
    if precision is None {
      precision = Some(12)
    }
    trim = true
    kind = "g"
  }
  // If zero fill is specified, padding goes after sign and before digits.
  let (zero, fill, align) = if zero || (fill == "0" && align == "=") {
    (true, "0", "=")
  } else {
    (zero, fill, align)
  }
  let prefix = if symbol == "$" {
    "$"
  } else if symbol == "#" && kind is ("b" | "o" | "x" | "X") {
    "0" + kind.to_lower()
  } else {
    ""
  }
  let suffix = if symbol == "$" {
    ""
  } else if kind is ("%" | "p") {
    "%"
  } else {
    ""
  }
  // Significant digits for g, p, r and s; digits after the point for
  // the others.
  let precision = match precision {
    None => 6
    Some(precision) =>
      if kind is ("g" | "p" | "r" | "s") {
        @cmp.maximum(1, @cmp.minimum(21, precision))
      } else {
        @cmp.maximum(0, @cmp.minimum(20, precision))
      }
  }
  {
    fill,
    align,
    sign,
    zero,
    width,
    comma,
    precision,
    trim,
    kind,
    prefix,
    suffix,
  }
}

///|
/// `formatDecimalParts`: the significant digits of `x` and its decimal
/// exponent, read off `toExponential`; nothing for a number that is not
/// finite.
fn decimal_parts(x : Double, p : Int32) -> (String, Int32)? {
  let text = if p > 0 {
    to_exponential(x, digits=p - 1)
  } else {
    to_exponential(x)
  }
  guard text.find("e") is Some(at) else { return None }
  let coefficient = text[:at].to_owned()
  let exponent = @string.parse_int(
    text[at + 1:].to_owned().replace(old="+", new=""),
  ) catch {
    _ => 0
  }
  let coefficient = if coefficient.length() > 1 {
    coefficient[:1].to_owned() + coefficient[2:].to_owned()
  } else {
    coefficient
  }
  Some((coefficient, exponent))
}

///|
/// `formatRounded`: `x` to `p` significant digits, in decimal notation.
fn format_rounded(x : Double, p : Int32) -> String {
  guard decimal_parts(x, p) is Some((coefficient, exponent)) else {
    return number(x)
  }
  if exponent < 0 {
    "0." + "0".repeat(-exponent - 1) + coefficient
  } else if coefficient.length() > exponent + 1 {
    coefficient[:exponent + 1].to_owned() +
    "." +
    coefficient[exponent + 1:].to_owned()
  } else {
    coefficient + "0".repeat(exponent - coefficient.length() + 1)
  }
}

///|
/// `formatPrefixAuto`: `x` to `p` significant digits, scaled to an SI
/// prefix, whose exponent is returned with the text.
fn format_prefix_auto(x : Double, p : Int32) -> (String, Int32) {
  guard decimal_parts(x, p) is Some((coefficient, exponent)) else {
    return (number(x), 0)
  }
  let third = (exponent.to_double() / 3.0).floor().to_int()
  let prefix_exponent = @cmp.maximum(-8, @cmp.minimum(8, third)) * 3
  let i = exponent - prefix_exponent + 1
  let n = coefficient.length()
  let text = if i == n {
    coefficient
  } else if i > n {
    coefficient + "0".repeat(i - n)
  } else if i > 0 {
    coefficient[:i].to_owned() + "." + coefficient[i:].to_owned()
  } else {
    // Less than 1y.
    "0." +
    "0".repeat(-i) +
    decimal_parts(x, @cmp.maximum(0, p + i - 1))
    .map(parts => parts.0)
    .unwrap_or("")
  }
  (text, prefix_exponent)
}

///|
/// `formatTrim`: insignificant zeros after the point go, and the point
/// with them when nothing is left: `1.500` is `1.5`, `2.0e+3` is `2e+3`.
fn format_trim(s : String) -> String {
  let n = s.length()
  let mut i0 = -1
  let mut i1 = 0
  for i in 1..<n {
    match s[i] {
      '.' => {
        i0 = i
        i1 = i
      }
      '0' => {
        if i0 == 0 {
          i0 = i
        }
        i1 = i
      }
      '1'..<='9' => if i0 > 0 { i0 = 0 }
      _ => break
    }
  }
  if i0 > 0 {
    s[:i0].to_owned() + s[i1 + 1:].to_owned()
  } else {
    s
  }
}

///|
/// `formatGroup` for groups of three separated by commas. `width` limits
/// the length of the result; `None` is no limit.
fn format_group(value : String, width : Int32?) -> String {
  let mut i = value.length()
  let parts = []
  let mut g = 3
  let mut length = 0
  while i > 0 && g > 0 {
    if width is Some(width) && length + g + 1 > width {
      g = @cmp.maximum(1, width - length)
    }
    i -= g
    // `substring` takes a negative start for zero.
    parts.push(value[@cmp.maximum(0, i):@cmp.maximum(0, i + g)].to_owned())
    length += g + 1
    if width is Some(width) && length > width {
      break
    }
    g = 3
  }
  parts.rev_in_place()
  parts.join(",")
}

///|
/// Format `value`.
pub fn Format::apply(self : Format, value : Double) -> String {
  let mut value_prefix = self.prefix
  let mut value_suffix = self.suffix
  let mut text = ""
  if self.kind == "c" {
    value_suffix = number(value) + value_suffix
  } else {
    // Whether the number is negative, counting negative zero.
    let mut negative = value < 0.0 || 1.0 / value < 0.0
    let magnitude = value.abs()
    let mut prefix_exponent = 0
    text = if value.is_nan() {
      "NaN"
    } else {
      match self.kind {
        "%" => to_fixed(magnitude * 100.0, self.precision)
        "b" => rounded_to_radix(magnitude, 2)
        "d" => {
          let rounded = js_round(magnitude)
          if rounded >= 1.0e21 {
            locale_digits(rounded)
          } else {
            number(rounded)
          }
        }
        "e" => to_exponential(magnitude, digits=self.precision)
        "f" => to_fixed(magnitude, self.precision)
        "g" => to_precision(magnitude, self.precision)
        "o" => rounded_to_radix(magnitude, 8)
        "p" => format_rounded(magnitude * 100.0, self.precision)
        "r" => format_rounded(magnitude, self.precision)
        "s" => {
          let (text, exponent) = format_prefix_auto(magnitude, self.precision)
          prefix_exponent = exponent
          text
        }
        "X" => rounded_to_radix(magnitude, 16).to_upper()
        _ => rounded_to_radix(magnitude, 16)
      }
    }
    if self.trim {
      text = format_trim(text)
    }
    // A number that rounds to zero is not negative, unless a sign is
    // asked for. (`+value === 0`)
    if negative && self.sign != "+" && is_zero_text(text) {
      negative = false
    }
    value_prefix = (if negative {
        if self.sign == "(" {
          "("
        } else {
          "\u{2212}"
        }
      } else if self.sign is ("-" | "(") {
        ""
      } else {
        self.sign
      }) +
      value_prefix
    value_suffix = (if self.kind == "s" {
        si_prefixes[8 + prefix_exponent / 3]
      } else {
        ""
      }) +
      value_suffix +
      (if negative && self.sign == "(" { ")" } else { "" })
    // Break the formatted value into the integer "value" part that can
    // be grouped, and fractional or exponential "suffix" part that is
    // not.
    if self.kind is ("d" | "e" | "f" | "g" | "p" | "r" | "s" | "%") {
      for i in 0..<text.length() {
        let c = text[i]
        if c < '0' || c > '9' {
          value_suffix = (if c == '.' {
              "." + text[i + 1:].to_owned()
            } else {
              text[i:].to_owned()
            }) +
            value_suffix
          text = text[:i].to_owned()
          break
        }
      }
    }
  }
  // If the fill character is not "0", grouping is applied before
  // padding.
  if self.comma && !self.zero {
    text = format_group(text, None)
  }
  // Compute the padding.
  let length = value_prefix.length() + text.length() + value_suffix.length()
  let mut padding = match self.width {
    Some(width) if length < width => self.fill.repeat(width - length)
    _ => ""
  }
  // If the fill character is "0", grouping is applied after padding.
  if self.comma && self.zero {
    text = format_group(
      padding + text,
      if padding.length() > 0 {
        Some(self.width.unwrap_or(0) - value_suffix.length())
      } else {
        None
      },
    )
    padding = ""
  }
  // Reconstruct the final output based on the desired alignment.
  match self.align {
    "<" => value_prefix + text + value_suffix + padding
    "=" => value_prefix + padding + text + value_suffix
    "^" => {
      let half = padding.length() >> 1
      padding[:half].to_owned() +
      value_prefix +
      text +
      value_suffix +
      padding[half:].to_owned()
    }
    _ => padding + value_prefix + text + value_suffix
  }
}

///|
/// Whether JavaScript converts `text` to zero: `+text === 0`, for the
/// texts the format types produce.
fn is_zero_text(text : String) -> Bool {
  let mantissa = match text.find("e") {
    Some(at) => text[:at].to_owned()
    None => text
  }
  // Hexadecimal digits are no decimal number, and never zero unless all
  // are.
  mantissa != "" && mantissa.iter().all(c => c is ('0' | '.'))
}
