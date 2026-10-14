///|
let weekdays : Array[String] = [
  "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
]

///|
let months : Array[String] = [
  "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December",
]

///|
fn regex(source : String) -> @jsregex.Regex {
  @jsregex.Regex::compile(source) catch {
    _ => abort("invalid pattern \{source}")
  }
}

///|
/// The tokens of the advancedFormat plugin (brackets protect literal
/// text).
let advanced_tokens : @jsregex.Regex = regex(
  "\\[([^\\]]+)]|Q|wo|ww|w|WW|W|zzz|z|gggg|GGGG|Do|X|x|k{1,2}|S",
)

///|
/// The tokens of dayjs proper.
let base_tokens : @jsregex.Regex = regex(
  "\\[([^\\]]+)]|YYYY|YY|M{1,4}|D{1,2}|d{1,4}|H{1,2}|h{1,2}|a|A|m{1,2}|s{1,2}|Z{1,2}|SSS",
)

///|
/// An integer-valued number as JavaScript prints it.
fn integer(value : Double) -> String {
  value.to_int64().to_string()
}

///|
/// dayjs's `padStart`.
fn pad_start(text : String, length : Int32, fill : Char) -> String {
  if text.length() >= length {
    text
  } else {
    String::make(length - text.length(), fill) + text
  }
}

///|
/// The English ordinal of a number, in brackets so that the base formatter
/// copies it.
fn ordinal(n : Double) -> String {
  let n = n.to_int()
  let rest = n % 100
  let suffixes = ["th", "st", "nd", "rd"]
  let pick = (index : Int32) => {
    if index >= 0 && index < 4 {
      Some(suffixes[index])
    } else {
      None
    }
  }
  let suffix = match pick((rest - 20) % 10) {
    Some(suffix) => suffix
    None => pick(rest).unwrap_or("th")
  }
  "[\{n}\{suffix}]"
}

///|
/// `format(template)` with the advancedFormat plugin. Tokens that need a
/// plugin mermaid does not load fail as they do upstream.
pub fn Dayjs::format(
  self : Dayjs,
  template : String,
) -> String raise DayjsError {
  if !self.is_valid() {
    return "Invalid Date"
  }
  let zone = self.zone
  let time = self.time
  let template = if template == "" { "YYYY-MM-DDTHH:mm:ssZ" } else { template }
  let mut missing : String? = None
  let advanced = advanced_tokens.replace_all(template, found => {
    let token = found.text()
    match token {
      "Q" => integer(((zone.month(time) + 1.0) / 3.0).ceil())
      "Do" => ordinal(zone.date(time))
      "gggg" => {
        missing = Some("t2.weekYear is not a function")
        token
      }
      "wo" | "w" | "ww" => {
        missing = Some("t2.week is not a function")
        token
      }
      "z" | "zzz" => {
        missing = Some("t2.offsetName is not a function")
        token
      }
      "GGGG" => integer(self.iso_week_year())
      "W" => integer(self.iso_week())
      "WW" => pad_start(integer(self.iso_week()), 2, '0')
      "k" | "kk" => {
        let hours = zone.hours(time)
        let text = integer(if hours == 0.0 { 24.0 } else { hours })
        pad_start(text, if token == "k" { 1 } else { 2 }, '0')
      }
      "X" => integer((time / 1000.0).floor())
      "x" => integer(time)
      _ => token
    }
  })
  if missing is Some(message) {
    raise DayjsError(message)
  }
  let offset = -self.utc_offset()
  let magnitude = offset.abs()
  let zone_text = (if offset <= 0.0 { "+" } else { "-" }) +
    pad_start(integer((magnitude / 60.0).floor()), 2, '0') +
    ":" +
    pad_start(integer(magnitude % 60.0), 2, '0')
  let year = zone.full_year(time)
  let month = zone.month(time).to_int()
  let date = zone.date(time)
  let weekday = zone.day(time).to_int()
  let hours = zone.hours(time)
  let hours12 = if hours % 12.0 == 0.0 { 12.0 } else { hours % 12.0 }
  let minutes = zone.minutes(time)
  let seconds = zone.seconds(time)
  let two = (value : Double) => pad_start(integer(value), 2, '0')
  base_tokens.replace_all(advanced, found => {
    if found.group(1) is Some(literal) {
      return literal
    }
    match found.text() {
      "YY" => {
        let text = integer(year)
        if text.length() > 2 {
          text.unsafe_substring(start=text.length() - 2, end=text.length())
        } else {
          text
        }
      }
      "YYYY" => pad_start(integer(year), 4, '0')
      "M" => (month + 1).to_string()
      "MM" => two((month + 1).to_double())
      "MMM" => months[month].unsafe_substring(start=0, end=3)
      "MMMM" => months[month]
      "D" => integer(date)
      "DD" => two(date)
      "d" => weekday.to_string()
      "dd" => weekdays[weekday].unsafe_substring(start=0, end=2)
      "ddd" => weekdays[weekday].unsafe_substring(start=0, end=3)
      "dddd" => weekdays[weekday]
      "H" => integer(hours)
      "HH" => two(hours)
      "h" => integer(hours12)
      "hh" => two(hours12)
      "a" => if hours < 12.0 { "am" } else { "pm" }
      "A" => if hours < 12.0 { "AM" } else { "PM" }
      "m" => integer(minutes)
      "mm" => two(minutes)
      "s" => integer(seconds)
      "ss" => two(seconds)
      "SSS" => pad_start(integer(zone.milliseconds(time)), 3, '0')
      "Z" => zone_text
      // "ZZ": the offset without its colon.
      _ => zone_text.replace(old=":", new="")
    }
  })
}
