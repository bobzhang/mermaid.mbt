// `new Date(string)` as V8 parses it: a port of `src/date/dateparser*`.
//
// The string is first read as an ECMAScript date-time string
// (`YYYY-MM-DDTHH:mm:ss.sssZ` and its shorter forms); whatever that leaves
// unread goes to the "legacy" parser, a forgiving reader of numbers, month
// names and time zone abbreviations shared in spirit with other browsers.

///|
/// A missing component (`kNone`).
const NONE : Int32 = 0x7fffffff

///|
priv enum Keyword {
  Garbage
  MonthName
  AmPm
  TimeZoneName
  TimeSeparator
} derive(Eq)

///|
priv enum Token {
  Invalid
  Unknown
  WhiteSpace
  Number(Int32, Int32)
  Symbol(Char)
  EndOfInput
  /// A word: its kind, the value of a recognized keyword, its length.
  Word(Keyword, Int32, Int32)
}

///|
fn Token::is_symbol(self : Token, symbol : Char) -> Bool {
  self is Symbol(c) && c == symbol
}

///|
fn Token::is_sign(self : Token) -> Bool {
  self is Symbol('+' | '-')
}

///|
/// Whether the token is a number written with exactly `length` digits.
fn Token::is_fixed_number(self : Token, length : Int32) -> Bool {
  self is Number(_, digits) && digits == length
}

///|
/// The value of a number token, or -1.
fn Token::number(self : Token) -> Int32 {
  match self {
    Number(value, _) => value
    _ => -1
  }
}

///|
fn Token::is_keyword_z(self : Token) -> Bool {
  self is Word(TimeZoneName, 0, 1)
}

///|
/// The first three letters (lower case, zero padded), kind and value of
/// every word the parser knows.
let keywords : Array[(String, Keyword, Int32)] = [
  ("jan", MonthName, 1),
  ("feb", MonthName, 2),
  ("mar", MonthName, 3),
  ("apr", MonthName, 4),
  ("may", MonthName, 5),
  ("jun", MonthName, 6),
  ("jul", MonthName, 7),
  ("aug", MonthName, 8),
  ("sep", MonthName, 9),
  ("oct", MonthName, 10),
  ("nov", MonthName, 11),
  ("dec", MonthName, 12),
  ("am\u{0}", AmPm, 0),
  ("pm\u{0}", AmPm, 12),
  ("ut\u{0}", TimeZoneName, 0),
  ("utc", TimeZoneName, 0),
  ("z\u{0}\u{0}", TimeZoneName, 0),
  ("gmt", TimeZoneName, 0),
  ("cdt", TimeZoneName, -5),
  ("cst", TimeZoneName, -6),
  ("edt", TimeZoneName, -4),
  ("est", TimeZoneName, -5),
  ("mdt", TimeZoneName, -6),
  ("mst", TimeZoneName, -7),
  ("pdt", TimeZoneName, -7),
  ("pst", TimeZoneName, -8),
  ("t\u{0}\u{0}", TimeSeparator, 0),
]

///|
/// Look a word up by its three-letter prefix. A word longer than its
/// keyword only counts for month names ("September").
fn lookup_keyword(
  prefix : FixedArray[Int32],
  length : Int32,
) -> (Keyword, Int32) {
  for entry in keywords {
    let (name, kind, value) = entry
    let mut matched = 0
    while matched < 3 && prefix[matched] == name.unsafe_get(matched).to_int() {
      matched += 1
    }
    if matched == 3 && (length <= 3 || kind == MonthName) {
      return (kind, value)
    }
  }
  (Garbage, 0)
}

///|
/// ECMAScript's WhiteSpace: tab, vertical tab, form feed, the byte order
/// mark and the Unicode space separators.
fn is_white_space(c : Int32) -> Bool {
  c == 0x09 ||
  c == 0x0b ||
  c == 0x0c ||
  c == 0x20 ||
  c == 0xa0 ||
  c == 0x1680 ||
  (c >= 0x2000 && c <= 0x200a) ||
  c == 0x202f ||
  c == 0x205f ||
  c == 0x3000 ||
  c == 0xfeff
}

///|
fn is_white_space_or_line_terminator(c : Int32) -> Bool {
  is_white_space(c) || c == 0x0a || c == 0x0d || c == 0x2028 || c == 0x2029
}

///|
/// The tokenizer, one token ahead of the parser.
priv struct Scanner {
  text : String
  /// One past the current character, as in V8's `InputReader`.
  mut index : Int32
  /// The current UTF-16 code unit, 0 at the end.
  mut ch : Int32
  mut next : Token
}

///|
fn Scanner::new(text : String) -> Scanner {
  let scanner = { text, index: 0, ch: 0, next: EndOfInput, }
  scanner.advance()
  scanner.next = scanner.scan()
  scanner
}

///|
fn Scanner::advance(self : Scanner) -> Unit {
  self.ch = if self.index < self.text.length() {
    self.text.unsafe_get(self.index).to_int()
  } else {
    0
  }
  self.index += 1
}

///|
fn Scanner::skip(self : Scanner, c : Char) -> Bool {
  if self.ch == c.to_int() {
    self.advance()
    true
  } else {
    false
  }
}

///|
fn Scanner::is_digit(self : Scanner) -> Bool {
  self.ch >= '0' && self.ch <= '9'
}

///|
/// Skip a parenthesized comment, nested ones included.
fn Scanner::skip_parentheses(self : Scanner) -> Bool {
  if self.ch != '(' {
    return false
  }
  let mut balance = 0
  while true {
    if self.ch == ')' {
      balance -= 1
    } else if self.ch == '(' {
      balance += 1
    }
    self.advance()
    if !(balance > 0 && self.ch != 0) {
      break
    }
  }
  true
}

///|
fn Scanner::scan(self : Scanner) -> Token {
  let start = self.index
  if self.ch == 0 {
    return EndOfInput
  }
  if self.is_digit() {
    // Leading zeros count as digits but not as significant ones; digits
    // past the ninth significant one are dropped.
    let mut n = 0
    let mut significant = 0
    while self.ch == '0' {
      self.advance()
    }
    while self.is_digit() {
      if significant < 9 {
        n = n * 10 + self.ch - '0'
      }
      significant += 1
      self.advance()
    }
    return Number(n, self.index - start)
  }
  for symbol in [':', '-', '+', '.', ')'] {
    if self.skip(symbol) {
      return Symbol(symbol)
    }
  }
  if self.ch >= 'A' && !is_white_space(self.ch) {
    let prefix : FixedArray[Int32] = [0, 0, 0]
    let mut length = 0
    while self.ch >= 'A' && !is_white_space(self.ch) {
      if length < 3 {
        prefix[length] = self.ch | 0x20
      }
      length += 1
      self.advance()
    }
    let (kind, value) = lookup_keyword(prefix, length)
    return Word(kind, value, length)
  }
  if is_white_space_or_line_terminator(self.ch) {
    self.advance()
    return WhiteSpace
  }
  if self.skip_parentheses() {
    return Unknown
  }
  self.advance()
  Unknown
}

///|
fn Scanner::peek(self : Scanner) -> Token {
  self.next
}

///|
fn Scanner::take(self : Scanner) -> Token {
  let result = self.next
  self.next = self.scan()
  result
}

///|
fn Scanner::skip_symbol(self : Scanner, symbol : Char) -> Bool {
  if self.next.is_symbol(symbol) {
    self.next = self.scan()
    true
  } else {
    false
  }
}

///|
fn between(x : Int32, low : Int32, high : Int32) -> Bool {
  x >= low && x <= high
}

///|
fn is_minute(x : Int32) -> Bool {
  between(x, 0, 59)
}

///|
fn is_hour(x : Int32) -> Bool {
  between(x, 0, 23)
}

///|
fn is_month(x : Int32) -> Bool {
  between(x, 1, 12)
}

///|
fn is_day(x : Int32) -> Bool {
  between(x, 1, 31)
}

///|
/// Collects the numbers of the date: up to three, plus a named month.
priv struct DayComposer {
  comp : Array[Int32]
  mut named_month : Int32
  /// Set by a date-time string: the numbers are year, month, day.
  mut is_iso_date : Bool
}

///|
fn DayComposer::add(self : DayComposer, n : Int32) -> Bool {
  if self.comp.length() < 3 {
    self.comp.push(n)
    true
  } else {
    false
  }
}

///|
/// Year, zero-based month and day, when the numbers make a date.
///
/// Missing numbers are filled in with 1 before the order of the numbers
/// is decided, so a lone "5" is May 1st of the year 1 (hence 2001) and
/// "1950" is January 1st, 1950.
fn DayComposer::write(self : DayComposer) -> (Int32, Int32, Int32)? {
  if self.comp.length() < 1 {
    return None
  }
  let comp = self.comp.copy()
  while comp.length() < 3 {
    comp.push(1)
  }
  let mut year = 0
  let mut month = NONE
  let mut day = NONE
  if self.named_month == NONE {
    if self.is_iso_date || !is_day(comp[0]) {
      year = comp[0]
      month = comp[1]
      day = comp[2]
    } else {
      month = comp[0]
      day = comp[1]
      year = comp[2]
    }
  } else {
    month = self.named_month
    if !is_day(comp[0]) {
      year = comp[0]
      day = comp[1]
    } else {
      day = comp[0]
      year = comp[1]
    }
  }
  if !self.is_iso_date {
    if between(year, 0, 49) {
      year += 2000
    } else if between(year, 50, 99) {
      year += 1900
    }
  }
  if !is_month(month) || !is_day(day) {
    return None
  }
  Some((year, month - 1, day))
}

///|
/// Collects hour, minute, second and millisecond.
priv struct TimeComposer {
  comp : Array[Int32]
  mut hour_offset : Int32
}

///|
fn TimeComposer::is_expecting(self : TimeComposer, n : Int32) -> Bool {
  (self.comp.length() == 1 && is_minute(n)) ||
  (self.comp.length() == 2 && is_minute(n)) ||
  (self.comp.length() == 3 && between(n, 0, 999))
}

///|
fn TimeComposer::add(self : TimeComposer, n : Int32) -> Bool {
  if self.comp.length() < 4 {
    self.comp.push(n)
    true
  } else {
    false
  }
}

///|
fn TimeComposer::add_final(self : TimeComposer, n : Int32) -> Bool {
  if !self.add(n) {
    return false
  }
  while self.comp.length() < 4 {
    self.comp.push(0)
  }
  true
}

///|
fn TimeComposer::write(self : TimeComposer) -> (Int32, Int32, Int32, Int32)? {
  let comp = self.comp.copy()
  while comp.length() < 4 {
    comp.push(0)
  }
  let mut hour = comp[0]
  let minute = comp[1]
  let second = comp[2]
  let millisecond = comp[3]
  if self.hour_offset != NONE {
    if !between(hour, 0, 12) {
      return None
    }
    hour = hour % 12 + self.hour_offset
  }
  if !is_hour(hour) ||
    !is_minute(minute) ||
    !is_minute(second) ||
    !between(millisecond, 0, 999) {
    // Midnight at the end of the day may be written 24:00:00.000.
    if hour != 24 || minute != 0 || second != 0 || millisecond != 0 {
      return None
    }
  }
  Some((hour, minute, second, millisecond))
}

///|
/// Collects the UTC offset.
priv struct TimeZoneComposer {
  mut sign : Int32
  mut hour : Int32
  mut minute : Int32
}

///|
fn TimeZoneComposer::set(self : TimeZoneComposer, hours : Int32) -> Unit {
  self.sign = if hours < 0 { -1 } else { 1 }
  self.hour = hours * self.sign
  self.minute = 0
}

///|
fn TimeZoneComposer::is_expecting(self : TimeZoneComposer, n : Int32) -> Bool {
  self.hour != NONE && self.minute == NONE && is_minute(n)
}

///|
fn TimeZoneComposer::is_utc(self : TimeZoneComposer) -> Bool {
  self.hour == 0 && self.minute == 0
}

///|
/// The offset in seconds; `None` inside when the string names no zone, and
/// no result at all when the offset is absurd.
fn TimeZoneComposer::write(self : TimeZoneComposer) -> Int32?? {
  if self.sign == NONE {
    return Some(None)
  }
  let hour = if self.hour == NONE { 0 } else { self.hour }
  let minute = if self.minute == NONE { 0 } else { self.minute }
  // Unsigned 32-bit arithmetic, then V8's small-integer limit (31 bits
  // with pointer compression).
  let total = hour.reinterpret_as_uint() * 3600U +
    minute.reinterpret_as_uint() * 60U
  if total > 0x3fffffffU {
    return None
  }
  let total = total.reinterpret_as_int()
  Some(Some(if self.sign < 0 { -total } else { total }))
}

///|
/// The fraction of a second as milliseconds, truncated.
fn read_milliseconds(token : Token) -> Int32 {
  guard token is Number(number, length) else { return -1 }
  if length == 1 {
    number * 100
  } else if length == 2 {
    number * 10
  } else if length > 3 {
    let mut length = if length > 9 { 9 } else { length }
    let mut factor = 1
    while true {
      factor *= 10
      length -= 1
      if !(length > 3) {
        break
      }
    }
    number / factor
  } else {
    number
  }
}

///|
/// Read an ECMAScript date-time string. Returns the first token it could
/// not use: `EndOfInput` when the whole string was one, `Invalid` when the
/// string is malformed beyond what the legacy parser may rescue.
fn parse_es5_date_time(
  scanner : Scanner,
  day : DayComposer,
  time : TimeComposer,
  tz : TimeZoneComposer,
) -> Token {
  if scanner.peek().is_sign() {
    // An expanded year: a sign and six digits.
    let sign_token = scanner.take()
    if !scanner.peek().is_fixed_number(6) {
      return sign_token
    }
    let sign = if sign_token.is_symbol('-') { -1 } else { 1 }
    let year = scanner.take().number()
    if sign < 0 && year == 0 {
      return sign_token
    }
    day.add(sign * year) |> ignore
  } else if scanner.peek().is_fixed_number(4) {
    day.add(scanner.take().number()) |> ignore
  } else {
    return scanner.take()
  }
  if scanner.skip_symbol('-') {
    if !scanner.peek().is_fixed_number(2) || !is_month(scanner.peek().number()) {
      return scanner.take()
    }
    day.add(scanner.take().number()) |> ignore
    if scanner.skip_symbol('-') {
      if !scanner.peek().is_fixed_number(2) || !is_day(scanner.peek().number()) {
        return scanner.take()
      }
      day.add(scanner.take().number()) |> ignore
    }
  }
  if !(scanner.peek() is Word(TimeSeparator, _, _)) {
    if !(scanner.peek() is EndOfInput) {
      return scanner.take()
    }
  } else {
    scanner.take() |> ignore
    if !scanner.peek().is_fixed_number(2) ||
      !between(scanner.peek().number(), 0, 24) {
      return Invalid
    }
    // 24:00[:00[.000]] is allowed, no other time starting with 24.
    let hour_is_24 = scanner.peek().number() == 24
    time.add(scanner.take().number()) |> ignore
    if !scanner.skip_symbol(':') {
      return Invalid
    }
    if !scanner.peek().is_fixed_number(2) ||
      !is_minute(scanner.peek().number()) ||
      (hour_is_24 && scanner.peek().number() > 0) {
      return Invalid
    }
    time.add(scanner.take().number()) |> ignore
    if scanner.skip_symbol(':') {
      if !scanner.peek().is_fixed_number(2) ||
        !is_minute(scanner.peek().number()) ||
        (hour_is_24 && scanner.peek().number() > 0) {
        return Invalid
      }
      time.add(scanner.take().number()) |> ignore
      if scanner.skip_symbol('.') {
        if !(scanner.peek() is Number(_, _)) ||
          (hour_is_24 && scanner.peek().number() > 0) {
          return Invalid
        }
        time.add(read_milliseconds(scanner.take())) |> ignore
      }
    }
    if scanner.peek().is_keyword_z() {
      scanner.take() |> ignore
      tz.set(0)
    } else if scanner.peek().is_sign() {
      tz.sign = if scanner.take().is_symbol('+') { 1 } else { -1 }
      if scanner.peek().is_fixed_number(4) {
        // hhmm, an extension.
        let hourmin = scanner.take().number()
        let hour = hourmin / 100
        let minute = hourmin % 100
        if !is_hour(hour) || !is_minute(minute) {
          return Invalid
        }
        tz.hour = hour
        tz.minute = minute
      } else {
        if !scanner.peek().is_fixed_number(2) ||
          !is_hour(scanner.peek().number()) {
          return Invalid
        }
        tz.hour = scanner.take().number()
        if !scanner.skip_symbol(':') {
          return Invalid
        }
        if !scanner.peek().is_fixed_number(2) ||
          !is_minute(scanner.peek().number()) {
          return Invalid
        }
        tz.minute = scanner.take().number()
      }
    }
    if !(scanner.peek() is EndOfInput) {
      return Invalid
    }
  }
  // A date without a time is UTC; a date with a time and no zone is local.
  if tz.hour == NONE && time.comp.is_empty() {
    tz.set(0)
  }
  day.is_iso_date = true
  EndOfInput
}

///|
/// `new Date(text).getTime()` (also `Date.parse`): NaN when V8 does not
/// recognize the string.
pub fn Zone::parse(self : Zone, text : String) -> Double {
  let scanner = Scanner::new(text)
  let day : DayComposer = { comp: [], named_month: NONE, is_iso_date: false, }
  let time : TimeComposer = { comp: [], hour_offset: NONE, }
  let tz : TimeZoneComposer = { sign: NONE, hour: NONE, minute: NONE, }
  let nan = @double.not_a_number
  let mut token = parse_es5_date_time(scanner, day, time, tz)
  if token is Invalid {
    return nan
  }
  let mut has_read_number = !day.comp.is_empty()
  while !(token is EndOfInput) {
    match token {
      Number(n, _) => {
        has_read_number = true
        if scanner.skip_symbol(':') {
          if scanner.skip_symbol(':') {
            // n "::" stands for n ":00:".
            if !time.comp.is_empty() {
              return nan
            }
            time.add(n) |> ignore
            time.add(0) |> ignore
          } else {
            if !time.add(n) {
              return nan
            }
            if scanner.peek().is_symbol('.') {
              scanner.take() |> ignore
            }
          }
        } else if scanner.skip_symbol('.') && time.is_expecting(n) {
          time.add(n) |> ignore
          if !(scanner.peek() is Number(_, _)) {
            return nan
          }
          let ms = read_milliseconds(scanner.take())
          if ms < 0 {
            return nan
          }
          time.add_final(ms) |> ignore
        } else if tz.is_expecting(n) {
          tz.minute = n
        } else if time.is_expecting(n) {
          time.add_final(n) |> ignore
          // The time must end here: nothing but white space, "Z" or a
          // sign may follow.
          let peek = scanner.peek()
          if !(peek is EndOfInput) &&
            !(peek is WhiteSpace) &&
            !peek.is_keyword_z() &&
            !peek.is_sign() {
            return nan
          }
        } else {
          if !day.add(n) {
            return nan
          }
          scanner.skip_symbol('-') |> ignore
        }
      }
      Word(kind, value, _) =>
        if kind == AmPm && !time.comp.is_empty() {
          time.hour_offset = value
        } else if kind == MonthName {
          day.named_month = value
          scanner.skip_symbol('-') |> ignore
        } else if kind == TimeZoneName && has_read_number {
          tz.set(value)
        } else {
          // Other words are only tolerated before the first number, and
          // not right against it.
          if has_read_number {
            return nan
          }
          if scanner.peek() is Number(_, _) {
            return nan
          }
        }
      Symbol('+' | '-' as sign) if tz.is_utc() || !time.comp.is_empty() => {
        // A UTC offset, only after "UTC" or a time.
        tz.sign = if sign == '-' { -1 } else { 1 }
        let mut n = 0
        let mut length = 0
        if scanner.peek() is Number(value, digits) {
          scanner.take() |> ignore
          n = value
          length = digits
        }
        has_read_number = true
        if scanner.peek().is_symbol(':') {
          tz.hour = n
          tz.minute = NONE
        } else if length == 2 || length == 1 {
          tz.hour = n
          tz.minute = 0
        } else if length == 4 || length == 3 {
          tz.hour = n / 100
          tz.minute = n % 100
        } else {
          return nan
        }
      }
      Symbol('+' | '-' | ')') if has_read_number => return nan
      _ => ()
    }
    token = scanner.take()
  }
  guard day.write() is Some((year, month, date)) else { return nan }
  guard time.write() is Some((hour, minute, second, millisecond)) else {
    return nan
  }
  guard tz.write() is Some(offset) else { return nan }
  let date = make_date(
    make_day(year.to_double(), month.to_double(), date.to_double()),
    make_time(
      hour.to_double(),
      minute.to_double(),
      second.to_double(),
      millisecond.to_double(),
    ),
  )
  match offset {
    None => self.from_local(date)
    Some(seconds) => time_clip(date - seconds.to_double() * 1000.0)
  }
}
