// d3-time-format's `timeFormat` in the default (en-US) locale.

///|
let time_periods : Array[String] = ["AM", "PM"]

///|
let time_days : Array[String] = [
  "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
]

///|
let time_months : Array[String] = [
  "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December",
]

///|
/// d3's `pad`: a number as text, padded on the left to `width` with
/// `fill` (nothing when `fill` is empty).
fn pad(value : Double, fill : String, width : Int32) -> String {
  let negative = value < 0.0
  let text = number(if negative { -value } else { value })
  let padding = if text.length() < width {
    fill.repeat(width - text.length())
  } else {
    ""
  }
  (if negative { "-" } else { "" }) + padding + text
}

///|
/// An entry of a name table; an invalid date has no name, which
/// JavaScript prints as nothing.
fn name_at(names : Array[String], index : Double, length? : Int32) -> String {
  if index.is_nan() {
    return ""
  }
  let name = names[index.to_int()]
  match length {
    Some(length) => name.unsafe_substring(start=0, end=length)
    None => name
  }
}

///|
/// JavaScript's `value | 0` for the numbers that occur here.
fn truncate(value : Double) -> Double {
  if value.is_nan() {
    0.0
  } else {
    value.trunc() + 0.0
  }
}

///|
/// The Thursday that decides the ISO week and year of a date.
fn iso_thursday(zone : @jsdate.Zone, date : Double) -> Double {
  let thursday = time_week(zone, 4)
  let day = zone.day(date)
  if day >= 4.0 || day == 0.0 {
    thursday.floor(date)
  } else {
    thursday.ceil(date)
  }
}

///|
/// Format one directive, or `None` for a letter that is not one.
fn format_directive(
  zone : @jsdate.Zone,
  directive : Char,
  date : Double,
  fill : String,
) -> String? {
  let year = time_year(zone)
  let text = match directive {
    'a' => name_at(time_days, zone.day(date), length=3)
    'A' => name_at(time_days, zone.day(date))
    'b' => name_at(time_months, zone.month(date), length=3)
    'B' => name_at(time_months, zone.month(date))
    'c' => time_format(zone, "%x, %X")(date)
    'd' | 'e' => pad(zone.date(date), fill, 2)
    'f' => pad(zone.milliseconds(date), fill, 3) + "000"
    'g' => pad(zone.full_year(iso_thursday(zone, date)) % 100.0, fill, 2)
    'G' => pad(zone.full_year(iso_thursday(zone, date)) % 10000.0, fill, 4)
    'H' => pad(zone.hours(date), fill, 2)
    'I' => {
      let hours = zone.hours(date) % 12.0
      pad(if hours == 0.0 { 12.0 } else { hours }, fill, 2)
    }
    'j' => pad(1.0 + time_day(zone).count(year.floor(date), date), fill, 3)
    'L' => pad(zone.milliseconds(date), fill, 3)
    'm' => pad(zone.month(date) + 1.0, fill, 2)
    'M' => pad(zone.minutes(date), fill, 2)
    'p' =>
      if zone.hours(date) >= 12.0 {
        time_periods[1]
      } else {
        time_periods[0]
      }
    'q' => number(1.0 + truncate(zone.month(date) / 3.0))
    'Q' => number(date)
    's' => number((date / 1000.0).floor())
    'S' => pad(zone.seconds(date), fill, 2)
    'u' => {
      let day = zone.day(date)
      number(if day == 0.0 { 7.0 } else { day })
    }
    'U' => pad(time_week(zone, 0).count(year.floor(date) - 1.0, date), fill, 2)
    'V' => {
      let thursday = iso_thursday(zone, date)
      let first = year.floor(thursday)
      pad(
        time_week(zone, 4).count(first, thursday) +
        (if zone.day(first) == 4.0 { 1.0 } else { 0.0 }),
        fill,
        2,
      )
    }
    'w' => number(zone.day(date))
    'W' => pad(time_week(zone, 1).count(year.floor(date) - 1.0, date), fill, 2)
    'x' => time_format(zone, "%-m/%-d/%Y")(date)
    'X' => time_format(zone, "%-I:%M:%S %p")(date)
    'y' => pad(zone.full_year(date) % 100.0, fill, 2)
    'Y' => pad(zone.full_year(date) % 10000.0, fill, 4)
    'Z' => {
      let offset = zone.timezone_offset(date)
      let (sign, offset) = if offset > 0.0 {
        ("-", offset)
      } else {
        ("+", -offset)
      }
      sign + pad(truncate(offset / 60.0), "0", 2) + pad(offset % 60.0, "0", 2)
    }
    '%' => "%"
    _ => return None
  }
  Some(text)
}

///|
/// d3's `timeFormat(specifier)`: a function writing a time value according
/// to `strftime`-like directives. A letter that is no directive is copied
/// without its percent sign, and so is a trailing percent sign dropped.
pub fn time_format(
  zone : @jsdate.Zone,
  specifier : String,
) -> (Double) -> String {
  date => {
    let date = @jsdate.time_clip(date)
    let out = StringBuilder()
    let n = specifier.length()
    let mut i = 0
    let mut j = 0
    while i < n {
      if specifier.unsafe_get(i) == '%' {
        out.write_string(specifier.unsafe_substring(start=j, end=i))
        i += 1
        // A flag chooses the padding: none, spaces or zeros.
        let mut fill : String? = None
        if i < n {
          fill = match specifier.unsafe_get(i) {
            '-' => Some("")
            '_' => Some(" ")
            '0' => Some("0")
            _ => None
          }
        }
        if fill is Some(_) {
          i += 1
        }
        if i < n {
          let c = specifier.unsafe_get(i).to_int().unsafe_to_char()
          let fill = fill.unwrap_or(if c == 'e' { " " } else { "0" })
          match format_directive(zone, c, date, fill) {
            Some(text) => out.write_string(text)
            None =>
              out.write_string(specifier.unsafe_substring(start=i, end=i + 1))
          }
        }
        j = i + 1
      }
      i += 1
    }
    if j < n {
      out.write_string(specifier.unsafe_substring(start=j, end=n))
    }
    out.to_string()
  }
}
