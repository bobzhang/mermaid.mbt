// A port of the parts of dayjs 1.11 that mermaid's Gantt chart uses, with
// the plugins it loads: isoWeek, customParseFormat, advancedFormat and
// duration. The English locale and local (not UTC) mode only.

///|
/// A point in time as dayjs wraps it. `time` is the time value of the
/// underlying `Date` (NaN for an invalid date); the calendar fields are
/// those of `zone`.
pub struct Dayjs {
  zone : @jsdate.Zone
  time : Double
}

///|
/// Where upstream fails with a JavaScript `TypeError`: mermaid does not
/// load the plugins some format tokens need (`w`, `gggg`, `z`, ...).
pub(all) suberror DayjsError {
  DayjsError(String)
} derive(Eq, Debug)

///|
/// `dayjs(date)` for a `Date` (or a time value).
pub fn Dayjs::new(zone : @jsdate.Zone, time : Double) -> Dayjs {
  { zone, time: @jsdate.time_clip(time), }
}

///|
/// `isValid()`.
pub fn Dayjs::is_valid(self : Dayjs) -> Bool {
  !self.time.is_nan()
}

///|
/// `valueOf()`, also the time value of `toDate()`.
pub fn Dayjs::value_of(self : Dayjs) -> Double {
  self.time
}

///|
fn Dayjs::with_time(self : Dayjs, time : Double) -> Dayjs {
  { zone: self.zone, time: @jsdate.time_clip(time), }
}

///|
/// `Math.round`.
fn js_round(value : Double) -> Double {
  if value.is_nan() || value == value.floor() {
    value
  } else {
    (value + 0.5).floor()
  }
}

///|
/// The unit a name or abbreviation stands for (dayjs's `prettyUnit`).
fn pretty_unit(unit : String) -> String {
  match unit {
    "M" => "month"
    "y" => "year"
    "w" => "week"
    "d" => "day"
    "D" => "date"
    "h" => "hour"
    "m" => "minute"
    "s" => "second"
    "ms" => "millisecond"
    "Q" => "quarter"
    _ => {
      let lower = unit.to_lower()
      match lower.strip_suffix("s") {
        Some(stem) => stem.to_owned()
        None => lower
      }
    }
  }
}

///|
/// `daysInMonth()`: the date of the last moment of the month.
fn Dayjs::days_in_month(self : Dayjs) -> Double {
  let zone = self.zone
  let last = zone.make(
    zone.full_year(self.time),
    zone.month(self.time) + 1.0,
    date=0.0,
  )
  zone.date(zone.set_hours(last, 23.0, minutes=59.0, seconds=59.0, ms=999.0))
}

///|
/// `set('date', value)`.
fn Dayjs::set_date(self : Dayjs, value : Double) -> Dayjs {
  self.with_time(self.zone.set_date(self.time, value))
}

///|
/// `set('month', value)` or `set('year', value)`: move to the first of the
/// month, change the month or year, then go back to the original day,
/// capped at the length of the new month.
fn Dayjs::set_month_or_year(
  self : Dayjs,
  value : Double,
  year~ : Bool,
) -> Dayjs {
  let zone = self.zone
  let first = self.set_date(1.0)
  let moved = first.with_time(
    if year {
      zone.set_full_year(first.time, value)
    } else {
      zone.set_month(first.time, value)
    },
  )
  moved.set_date(zone.date(self.time).min(moved.days_in_month()))
}

///|
/// `add(amount, unit)`. Months and years keep the day of the month when
/// they can; days and weeks are calendar days (so a day may last 23 or 25
/// hours); smaller units are exact durations.
pub fn Dayjs::add(self : Dayjs, amount : Double, unit : String) -> Dayjs {
  let zone = self.zone
  let days = (factor : Double) => {
    self.set_date(zone.date(self.time) + js_round(factor * amount))
  }
  match pretty_unit(unit) {
    "month" =>
      self.set_month_or_year(zone.month(self.time) + amount, year=false)
    "year" =>
      self.set_month_or_year(zone.full_year(self.time) + amount, year=true)
    "day" => days(1.0)
    "week" => days(7.0)
    other => {
      let factor = match other {
        "minute" => 60000.0
        "hour" => 3600000.0
        "second" => 1000.0
        _ => 1.0
      }
      self.with_time(self.time + amount * factor)
    }
  }
}

///|
/// `startOf('day')`.
pub fn Dayjs::start_of_day(self : Dayjs) -> Dayjs {
  self.with_time(
    self.zone.set_hours(self.time, 0.0, minutes=0.0, seconds=0.0, ms=0.0),
  )
}

///|
/// `endOf('day')`.
pub fn Dayjs::end_of_day(self : Dayjs) -> Dayjs {
  self.with_time(
    self.zone.set_hours(self.time, 23.0, minutes=59.0, seconds=59.0, ms=999.0),
  )
}

///|
/// `utcOffset()`: minutes east of UTC, rounded to a quarter of an hour.
fn Dayjs::utc_offset(self : Dayjs) -> Double {
  15.0 * -js_round(self.zone.timezone_offset(self.time) / 15.0) + 0.0
}

///|
/// dayjs's `monthDiff`: whole and fractional months from `a` to `b`.
fn month_diff(a : Dayjs, b : Dayjs) -> Double {
  let zone = a.zone
  if zone.date(a.time) < zone.date(b.time) {
    return -month_diff(b, a)
  }
  let whole = 12.0 * (zone.full_year(b.time) - zone.full_year(a.time)) +
    (zone.month(b.time) - zone.month(a.time))
  let anchor = a.add(whole, "month")
  let before = b.time - anchor.time < 0.0
  let anchor2 = a.add(whole + (if before { -1.0 } else { 1.0 }), "month")
  let span = if before {
    anchor.time - anchor2.time
  } else {
    anchor2.time - anchor.time
  }
  let result = -(whole + (b.time - anchor.time) / span)
  if result.is_nan() || result == 0.0 {
    0.0
  } else {
    result
  }
}

///|
/// dayjs's `absFloor`: truncate toward zero.
fn abs_floor(value : Double) -> Double {
  if value < 0.0 {
    value.ceil() + 0.0
  } else {
    value.floor()
  }
}

///|
/// `diff(other, 'year')`: whole years from `other` to `self`.
pub fn Dayjs::diff_years(self : Dayjs, other : Dayjs) -> Double {
  abs_floor(month_diff(self, other) / 12.0)
}

///|
/// `diff(other, 'week')`: whole weeks from `other` to `self`, a change of
/// UTC offset between the two not counting.
fn Dayjs::diff_weeks(self : Dayjs, other : Dayjs) -> Double {
  let zone_delta = (other.utc_offset() - self.utc_offset()) * 60000.0
  abs_floor((self.time - other.time - zone_delta) / 604800000.0)
}

///|
/// `isoWeekday()`: Monday is 1, Sunday is 7.
pub fn Dayjs::iso_weekday(self : Dayjs) -> Double {
  let day = self.zone.day(self.time)
  if day == 0.0 {
    7.0
  } else {
    day
  }
}

///|
/// The Thursday of this date's ISO week.
fn Dayjs::nearest_thursday(self : Dayjs) -> Dayjs {
  self.add(4.0 - self.iso_weekday(), "day")
}

///|
/// `isoWeekYear()`.
fn Dayjs::iso_week_year(self : Dayjs) -> Double {
  let thursday = self.nearest_thursday()
  self.zone.full_year(thursday.time)
}

///|
/// `isoWeek()`.
fn Dayjs::iso_week(self : Dayjs) -> Double {
  let thursday = self.nearest_thursday()
  let start = self.with_time(self.zone.make(self.iso_week_year(), 0.0))
  let mut offset = 4.0 - start.iso_weekday()
  if start.iso_weekday() > 4.0 {
    offset += 7.0
  }
  thursday.diff_weeks(start.add(offset, "day")) + 1.0
}

///|
/// `dayjs.duration({ [unit]: amount }).asMilliseconds()`: the nominal
/// length of a unit, a month being 365 days / 12 and a year 365 days.
pub fn duration_milliseconds(unit : String, amount : Double) -> Double {
  let length = match pretty_unit(unit) + "s" {
    "years" => 31536000000.0
    "months" => 2628000000.0
    "weeks" => 604800000.0
    "days" => 86400000.0
    "hours" => 3600000.0
    "minutes" => 60000.0
    "seconds" => 1000.0
    "milliseconds" => 1.0
    _ => @double.not_a_number
  }
  amount * length
}
