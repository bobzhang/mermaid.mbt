///|
/// The intervals of one time zone that the time scale picks its ticks
/// from.
priv struct Calendar {
  second : TimeInterval
  minute : TimeInterval
  hour : TimeInterval
  day : TimeInterval
  week : TimeInterval
  month : TimeInterval
  year : TimeInterval
}

///|
fn Calendar::new(zone : @jsdate.Zone) -> Calendar {
  {
    second: time_second(zone),
    minute: time_minute(zone),
    hour: time_hour(zone),
    day: time_day(zone),
    week: time_week(zone, 0),
    month: time_month(zone),
    year: time_year(zone),
  }
}

///|
/// The steps d3-time chooses ticks from, with their nominal lengths.
fn Calendar::tick_intervals(
  self : Calendar,
) -> Array[(TimeInterval, Double, Double)] {
  [
    (self.second, 1.0, SECOND),
    (self.second, 5.0, 5.0 * SECOND),
    (self.second, 15.0, 15.0 * SECOND),
    (self.second, 30.0, 30.0 * SECOND),
    (self.minute, 1.0, MINUTE),
    (self.minute, 5.0, 5.0 * MINUTE),
    (self.minute, 15.0, 15.0 * MINUTE),
    (self.minute, 30.0, 30.0 * MINUTE),
    (self.hour, 1.0, HOUR),
    (self.hour, 3.0, 3.0 * HOUR),
    (self.hour, 6.0, 6.0 * HOUR),
    (self.hour, 12.0, 12.0 * HOUR),
    (self.day, 1.0, DAY),
    (self.day, 2.0, 2.0 * DAY),
    (self.week, 1.0, WEEK),
    (self.month, 1.0, MONTH),
    (self.month, 3.0, 3.0 * MONTH),
    (self.year, 1.0, YEAR),
  ]
}

///|
/// d3-time's `timeTickInterval`: the interval whose ticks come closest to
/// `count` of them between `start` and `stop`.
fn Calendar::tick_interval(
  self : Calendar,
  start : Double,
  stop : Double,
  count : Double,
) -> TimeInterval? {
  let intervals = self.tick_intervals()
  let target = (stop - start).abs() / count
  // bisector(step).right; a NaN target sorts after everything.
  let mut i = intervals.length()
  if !target.is_nan() {
    let mut low = 0
    let mut high = intervals.length()
    while low < high {
      let mid = (low + high) / 2
      if intervals[mid].2 <= target {
        low = mid + 1
      } else {
        high = mid
      }
    }
    i = low
  }
  if i == intervals.length() {
    return self.year.every(tick_step(start / YEAR, stop / YEAR, count))
  }
  if i == 0 {
    return time_millisecond().every(js_max(tick_step(start, stop, count), 1.0))
  }
  let (interval, step, _) = intervals[if target / intervals[i - 1].2 <
      intervals[i].2 / target {
      i - 1
    } else {
      i
    }]
  interval.every(step)
}

///|
/// `Math.max` on two numbers: NaN if either is.
fn js_max(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a > b {
    a
  } else {
    b
  }
}

///|
/// d3's `scaleTime()` with a two-point domain and range: a linear map from
/// time values to positions, with calendar-aware ticks.
pub struct TimeScale {
  priv zone : @jsdate.Zone
  priv calendar : Calendar
  priv mut domain : (Double, Double)
  priv mut range : (Double, Double)
  /// Whether positions are rounded to integers (`rangeRound`).
  priv mut round : Bool
}

///|
/// `scaleTime()`: the domain is January 1st to 2nd, 2000, the range 0 to 1.
pub fn TimeScale::new(zone : @jsdate.Zone) -> TimeScale {
  {
    zone,
    calendar: Calendar::new(zone),
    domain: (zone.make(2000.0, 0.0, date=1.0), zone.make(2000.0, 0.0, date=2.0)),
    range: (0.0, 1.0),
    round: false,
  }
}

///|
/// `scale.domain([start, end])`. An invalid or missing date is NaN.
pub fn TimeScale::set_domain(
  self : TimeScale,
  start : Double,
  end : Double,
) -> TimeScale {
  self.domain = (@jsdate.time_clip(start), @jsdate.time_clip(end))
  self
}

///|
/// `scale.domain()`.
pub fn TimeScale::domain(self : TimeScale) -> (Double, Double) {
  self.domain
}

///|
/// `scale.range([start, end])`.
pub fn TimeScale::set_range(
  self : TimeScale,
  start : Double,
  end : Double,
) -> TimeScale {
  self.range = (start, end)
  self.round = false
  self
}

///|
/// `scale.rangeRound([start, end])`.
pub fn TimeScale::set_range_round(
  self : TimeScale,
  start : Double,
  end : Double,
) -> TimeScale {
  self.range = (start, end)
  self.round = true
  self
}

///|
/// `scale.range()`.
pub fn TimeScale::range(self : TimeScale) -> (Double, Double) {
  self.range
}

///|
/// `scale(date)`: the position of a time value. NaN stands for the
/// `undefined` d3 returns for an invalid date; either becomes NaN in the
/// arithmetic that follows.
pub fn TimeScale::apply(self : TimeScale, date : Double) -> Double {
  if date.is_nan() {
    return date
  }
  let (d0, d1) = self.domain
  let (r0, r1) = self.range
  // bimap: a descending domain is turned around together with its range.
  let (a, b, r0, r1) = if d1 < d0 { (d1, d0, r1, r0) } else { (d0, d1, r0, r1) }
  let span = b - a
  let t = if span.is_nan() {
    span
  } else if span == 0.0 {
    0.5
  } else {
    (date - a) / span
  }
  let value = r0 * (1.0 - t) + r1 * t
  if self.round {
    js_round(value)
  } else {
    value
  }
}

///|
/// `scale.ticks()`, `scale.ticks(count)`: about `count` ticks at round
/// calendar boundaries.
pub fn TimeScale::ticks(
  self : TimeScale,
  count~ : Double = 10.0,
) -> Array[Double] {
  let (start, stop) = self.domain
  let reverse = stop < start
  let (start, stop) = if reverse { (stop, start) } else { (start, stop) }
  let ticks = match self.calendar.tick_interval(start, stop, count) {
    Some(interval) => interval.range(start, stop + 1.0)
    None => []
  }
  if reverse {
    ticks.rev_in_place()
  }
  ticks
}

///|
/// `scale.ticks(interval)`: the boundaries of `interval` in the domain.
pub fn TimeScale::ticks_every(
  self : TimeScale,
  interval : TimeInterval,
) -> Array[Double] {
  let (start, stop) = self.domain
  let reverse = stop < start
  let (start, stop) = if reverse { (stop, start) } else { (start, stop) }
  let ticks = interval.range(start, stop + 1.0)
  if reverse {
    ticks.rev_in_place()
  }
  ticks
}

///|
/// `scale.nice()`: extend the domain to the tick boundaries around it.
pub fn TimeScale::nice(self : TimeScale, count~ : Double = 10.0) -> TimeScale {
  let (d0, d1) = self.domain
  guard self.calendar.tick_interval(d0, d1, count) is Some(interval) else {
    return self
  }
  self.domain = if d1 < d0 {
    (interval.ceil(d0), interval.floor(d1))
  } else {
    (interval.floor(d0), interval.ceil(d1))
  }
  self
}

///|
/// `scale.tickFormat()`: d3's multi-scale label — the largest unit a
/// tick is not a round value of decides how it is written.
pub fn TimeScale::tick_format(self : TimeScale) -> (Double) -> String {
  let zone = self.zone
  let calendar = self.calendar
  date => {
    let specifier = if calendar.second.floor(date) < date {
      ".%L"
    } else if calendar.minute.floor(date) < date {
      ":%S"
    } else if calendar.hour.floor(date) < date {
      "%I:%M"
    } else if calendar.day.floor(date) < date {
      "%I %p"
    } else if calendar.month.floor(date) < date {
      if calendar.week.floor(date) < date {
        "%a %d"
      } else {
        "%b %d"
      }
    } else if calendar.year.floor(date) < date {
      "%B"
    } else {
      "%Y"
    }
    time_format(zone, specifier)(date)
  }
}
