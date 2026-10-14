///|
const MS_PER_DAY : Double = 86400000.0

///|
/// The largest magnitude of a time value (ECMAScript's `TimeClip`).
const MAX_TIME : Double = 8.64e15

///|
/// How far a local time may lie beyond `MAX_TIME` and still be converted
/// to UTC (V8's `kMaxTimeBeforeUTCInMs`: a month of slack).
const MAX_LOCAL_TIME : Double = 8.64e15 + 30.0 * 86400000.0

///|
/// ECMAScript's `ToIntegerOrInfinity` for a finite number.
fn to_integer(value : Double) -> Double {
  if value.is_nan() {
    0.0
  } else {
    value.trunc() + 0.0
  }
}

///|
/// Floored division of integers.
fn div_floor(a : Int32, b : Int32) -> Int32 {
  let q = a / b
  if a % b != 0 && (a < 0) != (b < 0) {
    q - 1
  } else {
    q
  }
}

///|
/// The day number (days since 1970-01-01) of a proleptic Gregorian date;
/// `month` is zero-based.
fn days_from_civil(year : Int32, month : Int32, day : Int32) -> Int32 {
  let m = month + 1
  let y = if m <= 2 { year - 1 } else { year }
  let era = div_floor(y, 400)
  let yoe = y - era * 400
  let mp = if m > 2 { m - 3 } else { m + 9 }
  let doy = (153 * mp + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

///|
/// The inverse of `days_from_civil`: year, zero-based month and day of the
/// month.
fn civil_from_days(days : Int32) -> (Int32, Int32, Int32) {
  let z = days + 719468
  let era = div_floor(z, 146097)
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let day = doy - (153 * mp + 2) / 5 + 1
  let m = if mp < 10 { mp + 3 } else { mp - 9 }
  let year = yoe + era * 400 + (if m <= 2 { 1 } else { 0 })
  (year, m - 1, day)
}

///|
/// ECMAScript's `MakeDay` within V8's limits: a million years and ten
/// million months either way.
fn make_day(year : Double, month : Double, date : Double) -> Double {
  if !(-1000000.0 <= year && year <= 1000000.0) ||
    !(-10000000.0 <= month && month <= 10000000.0) ||
    date.is_nan() ||
    date.is_inf() {
    return @double.not_a_number
  }
  let m = month.to_int()
  let y = year.to_int() + div_floor(m, 12)
  let m = m - div_floor(m, 12) * 12
  days_from_civil(y, m, 1).to_double() + to_integer(date) - 1.0
}

///|
/// ECMAScript's `MakeTime`.
fn make_time(
  hour : Double,
  minute : Double,
  second : Double,
  millisecond : Double,
) -> Double {
  for value in [hour, minute, second, millisecond] {
    if value.is_nan() || value.is_inf() {
      return @double.not_a_number
    }
  }
  to_integer(hour) * HOUR +
  to_integer(minute) * MINUTE +
  to_integer(second) * 1000.0 +
  to_integer(millisecond)
}

///|
/// ECMAScript's `MakeDate`.
fn make_date(day : Double, time : Double) -> Double {
  if day.is_nan() || day.is_inf() || time.is_nan() || time.is_inf() {
    @double.not_a_number
  } else {
    time + day * MS_PER_DAY
  }
}

///|
/// ECMAScript's `TimeClip`: a time value, or NaN when out of range.
pub fn time_clip(time : Double) -> Double {
  if time.is_nan() || time.abs() > MAX_TIME {
    @double.not_a_number
  } else {
    to_integer(time)
  }
}

///|
/// `Date.UTC(year, month, date, hours, minutes, seconds, ms)`.
pub fn utc(
  year : Double,
  month : Double,
  date~ : Double = 1.0,
  hours~ : Double = 0.0,
  minutes~ : Double = 0.0,
  seconds~ : Double = 0.0,
  ms~ : Double = 0.0,
) -> Double {
  time_clip(
    make_date(
      make_day(two_digit_year(year), month, date),
      make_time(hours, minutes, seconds, ms),
    ),
  )
}

///|
/// Years 0 to 99 mean 1900 to 1999 in the `Date` constructor and
/// `Date.UTC`.
fn two_digit_year(year : Double) -> Double {
  if year.is_nan() {
    return year
  }
  let y = to_integer(year)
  if 0.0 <= y && y <= 99.0 {
    1900.0 + y
  } else {
    year
  }
}

///|
/// The broken-down fields of a time value that already includes its UTC
/// offset.
priv struct Civil {
  year : Int32
  month : Int32
  day : Int32
  weekday : Int32
  /// Milliseconds since midnight.
  time : Double
}

///|
fn civil(wall : Double) -> Civil {
  let days = (wall / MS_PER_DAY).floor()
  let time = wall - days * MS_PER_DAY
  let days = days.to_int()
  let (year, month, day) = civil_from_days(days)
  // 1970-01-01 was a Thursday.
  let weekday = days + 4 - div_floor(days + 4, 7) * 7
  { year, month, day, weekday, time, }
}
