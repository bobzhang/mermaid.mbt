// d3-time: calendar intervals in local time. Dates are time values
// (milliseconds since the epoch, NaN when invalid); the functions that
// mutate a `Date` in d3 return the new value here.

///|
/// A calendar interval: how to round a date down to it and how to step.
pub struct TimeInterval {
  priv floori : (Double) -> Double
  priv offseti : (Double, Double) -> Double
  /// Whole intervals between two interval boundaries.
  priv counter : ((Double, Double) -> Double)?
  /// The number of the interval within its parent (the month of the
  /// year, the hour of the day).
  priv field : ((Double) -> Double)?
  /// `every` where d3 overrides it (milliseconds and years).
  priv multiples : ((Double) -> TimeInterval?)?
}

///|
const SECOND : Double = 1000.0

///|
const MINUTE : Double = 60000.0

///|
const HOUR : Double = 3600000.0

///|
const DAY : Double = 86400000.0

///|
const WEEK : Double = 604800000.0

///|
/// The nominal month and year of d3-time: 30 and 365 days.
const MONTH : Double = 2592000000.0

///|
const YEAR : Double = 31536000000.0

///|
fn TimeInterval::new(
  floori : (Double) -> Double,
  offseti : (Double, Double) -> Double,
  counter? : (Double, Double) -> Double,
  field? : (Double) -> Double,
  multiples? : (Double) -> TimeInterval?,
) -> TimeInterval {
  { floori, offseti, counter, field, multiples, }
}

///|
/// `interval(date)` and `interval.floor(date)`: the boundary at or before
/// the date.
pub fn TimeInterval::floor(self : TimeInterval, date : Double) -> Double {
  (self.floori)(@jsdate.time_clip(date))
}

///|
/// `interval.ceil(date)`: the boundary at or after the date.
pub fn TimeInterval::ceil(self : TimeInterval, date : Double) -> Double {
  let date = (self.floori)(@jsdate.time_clip(date - 1.0))
  (self.floori)((self.offseti)(date, 1.0))
}

///|
/// `interval.offset(date, step)`.
pub fn TimeInterval::offset(
  self : TimeInterval,
  date : Double,
  step : Double,
) -> Double {
  (self.offseti)(@jsdate.time_clip(date), step.floor())
}

///|
/// `interval.range(start, stop, step)`: the boundaries from `start`
/// (inclusive) to `stop` (exclusive).
pub fn TimeInterval::range(
  self : TimeInterval,
  start : Double,
  stop : Double,
  step~ : Double = 1.0,
) -> Array[Double] {
  let range = []
  let mut start = self.ceil(start)
  let step = step.floor()
  if !(start < stop) || !(step > 0.0) {
    return range
  }
  while true {
    let previous = start
    range.push(previous)
    start = (self.floori)((self.offseti)(start, step))
    if !(previous < start && start < stop) {
      break
    }
  }
  range
}

///|
/// `interval.filter(keep)`: the interval reduced to the boundaries that
/// pass `keep`.
pub fn TimeInterval::filter(
  self : TimeInterval,
  keep : (Double) -> Bool,
) -> TimeInterval {
  TimeInterval::new(
    date => {
      let mut date = date
      if !date.is_nan() {
        while true {
          date = (self.floori)(date)
          if keep(date) {
            break
          }
          date = @jsdate.time_clip(date - 1.0)
        }
      }
      date
    },
    (date, step) => {
      let mut date = date
      if !date.is_nan() {
        let direction = if step < 0.0 { -1.0 } else { 1.0 }
        let mut remaining = step.abs()
        while remaining > 0.0 {
          remaining -= 1.0
          while true {
            date = (self.offseti)(date, direction)
            if keep(date) {
              break
            }
          }
        }
      }
      date
    },
  )
}

///|
/// `interval.count(start, end)`: the boundaries after `start` up to `end`.
pub fn TimeInterval::count(
  self : TimeInterval,
  start : Double,
  end : Double,
) -> Double {
  guard self.counter is Some(counter) else { return @double.not_a_number }
  counter(
    (self.floori)(@jsdate.time_clip(start)),
    (self.floori)(@jsdate.time_clip(end)),
  ).floor()
}

///|
/// `interval.every(step)`: every `step`-th boundary, counted within the
/// parent interval where there is one (every other day restarts on the
/// first of each month) and from the epoch otherwise. `None` for a step
/// that is not a positive number.
pub fn TimeInterval::every(self : TimeInterval, step : Double) -> TimeInterval? {
  if self.multiples is Some(multiples) {
    return multiples(step)
  }
  let step = step.floor()
  if step.is_nan() || step.is_inf() || !(step > 0.0) {
    return None
  }
  if !(step > 1.0) {
    return Some(self)
  }
  Some(
    match self.field {
      Some(field) => self.filter(date => field(date) % step == 0.0)
      None => self.filter(date => self.count(0.0, date) % step == 0.0)
    },
  )
}

///|
/// `timeMillisecond`.
pub fn time_millisecond() -> TimeInterval {
  TimeInterval::new(
    date => date,
    (date, step) => @jsdate.time_clip(date + step),
    counter=(start, end) => end - start,
    multiples=k => {
      let k = k.floor()
      if k.is_nan() || k.is_inf() || !(k > 0.0) {
        None
      } else if !(k > 1.0) {
        Some(time_millisecond())
      } else {
        Some(
          TimeInterval::new(
            date => @jsdate.time_clip((date / k).floor() * k),
            (date, step) => @jsdate.time_clip(date + step * k),
            counter=(start, end) => (end - start) / k,
          ),
        )
      }
    },
  )
}

///|
/// `timeSecond`.
pub fn time_second(zone : @jsdate.Zone) -> TimeInterval {
  TimeInterval::new(
    date => @jsdate.time_clip(date - zone.milliseconds(date)),
    (date, step) => @jsdate.time_clip(date + step * SECOND),
    counter=(start, end) => (end - start) / SECOND,
    field=date => @jsdate.utc_seconds(date),
  )
}

///|
/// `timeMinute`.
pub fn time_minute(zone : @jsdate.Zone) -> TimeInterval {
  TimeInterval::new(
    date => {
      @jsdate.time_clip(
        date - zone.milliseconds(date) - zone.seconds(date) * SECOND,
      )
    },
    (date, step) => @jsdate.time_clip(date + step * MINUTE),
    counter=(start, end) => (end - start) / MINUTE,
    field=date => zone.minutes(date),
  )
}

///|
/// `timeHour`.
pub fn time_hour(zone : @jsdate.Zone) -> TimeInterval {
  TimeInterval::new(
    date => {
      @jsdate.time_clip(
        date -
        zone.milliseconds(date) -
        zone.seconds(date) * SECOND -
        zone.minutes(date) * MINUTE,
      )
    },
    (date, step) => @jsdate.time_clip(date + step * HOUR),
    counter=(start, end) => (end - start) / HOUR,
    field=date => zone.hours(date),
  )
}

///|
fn midnight(zone : @jsdate.Zone, date : Double) -> Double {
  zone.set_hours(date, 0.0, minutes=0.0, seconds=0.0, ms=0.0)
}

///|
/// `timeDay`.
pub fn time_day(zone : @jsdate.Zone) -> TimeInterval {
  TimeInterval::new(
    date => midnight(zone, date),
    (date, step) => zone.set_date(date, zone.date(date) + step),
    counter=(start, end) => {
      (
        end -
        start -
        (zone.timezone_offset(end) - zone.timezone_offset(start)) * MINUTE
      ) /
      DAY
    },
    field=date => zone.date(date) - 1.0,
  )
}

///|
/// `timeSunday` (0) to `timeSaturday` (6): weeks starting on the given day.
pub fn time_week(zone : @jsdate.Zone, weekday : Int32) -> TimeInterval {
  let weekday = weekday.to_double()
  TimeInterval::new(
    date => {
      let date = zone.set_date(
        date,
        zone.date(date) - (zone.day(date) + 7.0 - weekday) % 7.0,
      )
      midnight(zone, date)
    },
    (date, step) => zone.set_date(date, zone.date(date) + step * 7.0),
    counter=(start, end) => {
      (
        end -
        start -
        (zone.timezone_offset(end) - zone.timezone_offset(start)) * MINUTE
      ) /
      WEEK
    },
  )
}

///|
/// `timeMonth`.
pub fn time_month(zone : @jsdate.Zone) -> TimeInterval {
  TimeInterval::new(
    date => midnight(zone, zone.set_date(date, 1.0)),
    (date, step) => zone.set_month(date, zone.month(date) + step),
    counter=(start, end) => {
      zone.month(end) -
      zone.month(start) +
      (zone.full_year(end) - zone.full_year(start)) * 12.0
    },
    field=date => zone.month(date),
  )
}

///|
/// `timeYear`.
pub fn time_year(zone : @jsdate.Zone) -> TimeInterval {
  TimeInterval::new(
    date => midnight(zone, zone.set_month(date, 0.0, date=1.0)),
    (date, step) => zone.set_full_year(date, zone.full_year(date) + step),
    counter=(start, end) => zone.full_year(end) - zone.full_year(start),
    field=date => zone.full_year(date),
    multiples=k => {
      let k = k.floor()
      if k.is_nan() || k.is_inf() || !(k > 0.0) {
        None
      } else {
        Some(
          TimeInterval::new(
            date => {
              let date = zone.set_full_year(
                date,
                (zone.full_year(date) / k).floor() * k,
              )
              midnight(zone, zone.set_month(date, 0.0, date=1.0))
            },
            (date, step) => {
              zone.set_full_year(date, zone.full_year(date) + step * k)
            },
          ),
        )
      }
    },
  )
}
