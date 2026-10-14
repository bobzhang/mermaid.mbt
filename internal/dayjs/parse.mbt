// The customParseFormat plugin: `dayjs(text, format, true)`.
//
// Its parser is lenient in surprising ways — literal parts of the format
// are skipped by length without being compared, values are searched for
// rather than expected in place — and the strict mode makes up for it by
// formatting the result and comparing it with the input. Both halves are
// ported as they are.

///|
/// What the token parsers collect.
priv struct Parts {
  mut year : Double?
  mut month : Double?
  /// The day; the flag is its JavaScript truthiness (an ordinal that is
  /// not a proper one leaves a string, and "0" is truthy).
  mut day : (Double, Bool)?
  mut hours : Double?
  mut minutes : Double?
  mut seconds : Double?
  mut milliseconds : Double?
  /// The UTC offset in minutes, sign reversed, as the plugin keeps it.
  mut zone_offset : Double?
  mut week : Double?
  mut afternoon : Bool?
}

///|
/// One piece of a compiled format: literal text of a given length, or a
/// token with the pattern that finds its value.
priv enum Piece {
  Literal(Int32)
  Token(String)
}

///|
let locale_formats : @jsregex.Regex = regex(
  "(\\[[^\\]]+])|(LTS?|l{1,4}|L{1,4})",
)

///|
let format_pieces : @jsregex.Regex = regex(
  "(\\[[^[]*\\])|([-_:/.,()\\s]+)|(A|a|Q|YYYY|YY?|ww?|MM?M?M?|Do|DD?|hh?|HH?|mm?|ss?|S{1,3}|z|ZZ?)",
)

///|
let match_1 : @jsregex.Regex = regex("\\d")

///|
let match_2 : @jsregex.Regex = regex("\\d\\d")

///|
let match_3 : @jsregex.Regex = regex("\\d{3}")

///|
let match_4 : @jsregex.Regex = regex("\\d{4}")

///|
let match_1_to_2 : @jsregex.Regex = regex("\\d\\d?")

///|
let match_signed : @jsregex.Regex = regex("[+-]?\\d+")

///|
let match_word : @jsregex.Regex = regex("\\d*[^-_:/,()\\s\\d]+")

///|
let match_offset : @jsregex.Regex = regex("[+-]\\d\\d:?(\\d\\d)?|Z")

///|
let digits : @jsregex.Regex = regex("\\d+")

///|
let offset_parts : @jsregex.Regex = regex("([+-]|\\d\\d)")

///|
/// The pattern that finds a token's value, if the token is one the plugin
/// parses.
fn token_pattern(token : String) -> @jsregex.Regex? {
  match token {
    "A" | "a" | "Do" | "MMM" | "MMMM" => Some(match_word)
    "Q" | "S" => Some(match_1)
    "SS" | "DD" | "ww" | "MM" | "YY" => Some(match_2)
    "SSS" => Some(match_3)
    "s" | "ss" | "m" | "mm" | "H" | "h" | "HH" | "hh" | "D" | "w" | "M" =>
      Some(match_1_to_2)
    "Y" => Some(match_signed)
    "YYYY" => Some(match_4)
    "Z" | "ZZ" => Some(match_offset)
    _ => None
  }
}

///|
/// A string of digits (with an optional sign) as a number.
fn to_number(text : String) -> Double {
  let mut value = 0.0
  let mut negative = false
  for i, c in text {
    if i == 0 && (c == '+' || c == '-') {
      negative = c == '-'
    } else {
      value = value * 10.0 + (c.to_int() - '0').to_double()
    }
  }
  if negative {
    -value
  } else {
    value
  }
}

///|
/// Store the value a token's pattern found. `None` stands for the
/// exception upstream throws on an unknown month name.
fn Parts::store(self : Parts, token : String, found : String) -> Unit? {
  match token {
    "A" => self.afternoon = Some(found == "PM")
    "a" => self.afternoon = Some(found == "pm")
    "Q" => self.month = Some(3.0 * (to_number(found) - 1.0) + 1.0)
    "S" => self.milliseconds = Some(100.0 * to_number(found))
    "SS" => self.milliseconds = Some(10.0 * to_number(found))
    "SSS" => self.milliseconds = Some(to_number(found))
    "s" | "ss" => self.seconds = Some(to_number(found))
    "m" | "mm" => self.minutes = Some(to_number(found))
    "H" | "h" | "HH" | "hh" => self.hours = Some(to_number(found))
    "D" | "DD" => {
      let day = to_number(found)
      self.day = Some((day, day != 0.0))
    }
    "Do" => {
      // The leading digits, unless the whole is a proper ordinal.
      guard digits.exec(found) is Some(number) else { return None }
      self.day = Some((to_number(number.text()), true))
      for day in 1..<32 {
        let name = ordinal(day.to_double())
        if name.unsafe_substring(start=1, end=name.length() - 1) == found {
          self.day = Some((day.to_double(), true))
        }
      }
    }
    "w" | "ww" => self.week = Some(to_number(found))
    "M" | "MM" => self.month = Some(to_number(found))
    "MMM" => {
      guard months.search_by(name => {
          name.unsafe_substring(start=0, end=3) == found
        })
        is Some(index) else {
        return None
      }
      self.month = Some((index + 1).to_double())
    }
    "MMMM" => {
      guard months.search(found) is Some(index) else { return None }
      self.month = Some((index + 1).to_double())
    }
    "Y" | "YYYY" => self.year = Some(to_number(found))
    "YY" => {
      let year = to_number(found)
      self.year = Some(year + (if year > 68.0 { 1900.0 } else { 2000.0 }))
    }
    _ =>
      // "Z" and "ZZ".
      self.zone_offset = Some(
        if found == "Z" {
          0.0
        } else {
          let parts = []
          let mut from = 0
          while offset_parts.exec(found, from~) is Some(part) {
            parts.push(part.text())
            from = part.end
          }
          let minutes = 60.0 * to_number(parts[1]) +
            (if parts.length() > 2 { to_number(parts[2]) } else { 0.0 })
          if minutes == 0.0 {
            0.0
          } else if parts[0] == "+" {
            -minutes
          } else {
            minutes
          }
        },
      )
  }
  Some(())
}

///|
/// Split a format into literal runs and tokens. `None` where upstream
/// throws: a locale-dependent token (`L`, `LT`, ...), for which the
/// English locale has no definition, or a format with nothing in it.
fn compile_format(format : String) -> Array[Piece]? {
  let mut from = 0
  while locale_formats.exec(format, from~) is Some(found) {
    if found.group(1) is None {
      return None
    }
    from = found.end
  }
  let pieces = []
  let mut from = 0
  while format_pieces.exec(format, from~) is Some(found) {
    let text = found.text()
    pieces.push(
      if token_pattern(text) is Some(_) {
        Token(text)
      } else {
        // The brackets around literal text do not count.
        let mut length = text.length()
        if text.has_prefix("[") {
          length -= 1
        }
        if length > 0 && text.has_suffix("]") {
          length -= 1
        }
        Literal(length)
      },
    )
    from = found.end
  }
  if pieces.is_empty() {
    None
  } else {
    Some(pieces)
  }
}

///|
/// `text.slice(start)`.
fn tail(text : String, start : Int32) -> String {
  if start >= text.length() {
    ""
  } else {
    text.unsafe_substring(start~, end=text.length())
  }
}

///|
/// `text.replace(part, "")`: drop the first occurrence.
fn remove_first(text : String, part : String) -> String {
  match text.find(part) {
    Some(at) =>
      text.unsafe_substring(start=0, end=at) +
      text.unsafe_substring(start=at + part.length(), end=text.length())
    None => text
  }
}

///|
/// The plugin's lenient parse: the time value, NaN where upstream ends up
/// with an invalid date.
fn parse_lenient(
  zone : @jsdate.Zone,
  text : String,
  format : String,
  now : Double,
) -> Double {
  let nan = @double.not_a_number
  guard compile_format(format) is Some(pieces) else { return nan }
  let parts : Parts = {
    year: None,
    month: None,
    day: None,
    hours: None,
    minutes: None,
    seconds: None,
    milliseconds: None,
    zone_offset: None,
    week: None,
    afternoon: None,
  }
  let mut rest = text
  let mut start = 0
  for piece in pieces {
    match piece {
      Literal(length) => start += length
      Token(token) => {
        guard token_pattern(token) is Some(pattern) else { return nan }
        // The value is searched for from the current position on, then
        // cut out of the string wherever it first occurs.
        guard pattern.exec(tail(rest, start)) is Some(found) else { return nan }
        guard parts.store(token, found.text()) is Some(_) else { return nan }
        rest = remove_first(rest, found.text())
      }
    }
  }
  if parts.afternoon is Some(afternoon) && parts.hours is Some(hours) {
    if afternoon {
      if hours < 12.0 {
        parts.hours = Some(hours + 12.0)
      }
    } else if hours == 12.0 {
      parts.hours = Some(0.0)
    }
  }
  // Zero counts as missing (JavaScript's `||`).
  let truthy = (value : Double?) => {
    match value {
      Some(v) if v != 0.0 => Some(v)
      _ => None
    }
  }
  let year = truthy(parts.year)
  let month = truthy(parts.month)
  // What the string does not say comes from today's date.
  let day = match parts.day {
    Some((day, true)) => day
    _ => if year is Some(_) || month is Some(_) { 1.0 } else { zone.date(now) }
  }
  let full_year = year.unwrap_or(zone.full_year(now))
  let month_index = if year is Some(_) && month is None {
    0.0
  } else {
    match parts.month {
      Some(m) if m > 0.0 => m - 1.0
      _ => zone.month(now)
    }
  }
  let hours = truthy(parts.hours).unwrap_or(0.0)
  let minutes = truthy(parts.minutes).unwrap_or(0.0)
  let seconds = truthy(parts.seconds).unwrap_or(0.0)
  let ms = truthy(parts.milliseconds).unwrap_or(0.0)
  if parts.zone_offset is Some(offset) {
    return @jsdate.utc(
      full_year,
      month_index,
      date=day,
      hours~,
      minutes~,
      seconds~,
      ms=ms + 60.0 * offset * 1000.0,
    )
  }
  // A week number needs the weekOfYear plugin, which is not loaded: the
  // call fails and the date is invalid.
  if truthy(parts.week) is Some(_) {
    return nan
  }
  zone.make(full_year, month_index, date=day, hours~, minutes~, seconds~, ms~)
}

///|
/// A canonical decimal integer, as `String(number)` prints one.
let canonical_integer : @jsregex.Regex = regex("^(?:0|-?[1-9]\\d*)$")

///|
/// `dayjs(text, format, true)`: parse `text` strictly according to
/// `format`. The result is invalid unless formatting it gives `text`
/// back. `now` supplies the date parts the format leaves out.
pub fn Dayjs::parse(
  zone : @jsdate.Zone,
  text : String,
  format : String,
  now~ : Double,
) -> Dayjs raise DayjsError {
  let invalid : Dayjs = { zone, time: @double.not_a_number, }
  if format == "x" || format == "X" {
    // A Unix timestamp; strictness leaves only the canonical spelling.
    if !canonical_integer.matches(text) || text.length() > 17 {
      return invalid
    }
    let scale = if format == "X" { 1000.0 } else { 1.0 }
    return Dayjs::new(zone, to_number(text) * scale)
  }
  let parsed = Dayjs::new(zone, parse_lenient(zone, text, format, now))
  if parsed.format(format) != text {
    return invalid
  }
  parsed
}
