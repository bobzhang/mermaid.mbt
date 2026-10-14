///|
/// `new Date(year, month, date, hours, minutes, seconds, ms)`: the time
/// value of a local date and time. Arguments are truncated to integers and
/// may be out of range, as in JavaScript; the result is NaN for an invalid
/// date.
pub fn Zone::make(
  self : Zone,
  year : Double,
  month : Double,
  date~ : Double = 1.0,
  hours~ : Double = 0.0,
  minutes~ : Double = 0.0,
  seconds~ : Double = 0.0,
  ms~ : Double = 0.0,
) -> Double {
  self.from_local(
    make_date(
      make_day(two_digit_year(year), month, date),
      make_time(hours, minutes, seconds, ms),
    ),
  )
}

///|
/// The time value of a local time value (V8's `SetLocalDateValue`).
fn Zone::from_local(self : Zone, wall : Double) -> Double {
  if wall >= -MAX_LOCAL_TIME && wall <= MAX_LOCAL_TIME {
    time_clip(self.to_utc(wall))
  } else {
    @double.not_a_number
  }
}

///|
fn Zone::civil(self : Zone, time : Double) -> Civil {
  civil(time + self.offset_at(time))
}

///|
/// `getFullYear()`.
pub fn Zone::full_year(self : Zone, time : Double) -> Double {
  if time.is_nan() {
    return time
  }
  self.civil(time).year.to_double()
}

///|
/// `getMonth()`: zero-based.
pub fn Zone::month(self : Zone, time : Double) -> Double {
  if time.is_nan() {
    return time
  }
  self.civil(time).month.to_double()
}

///|
/// `getDate()`: the day of the month.
pub fn Zone::date(self : Zone, time : Double) -> Double {
  if time.is_nan() {
    return time
  }
  self.civil(time).day.to_double()
}

///|
/// `getDay()`: the day of the week, Sunday being 0.
pub fn Zone::day(self : Zone, time : Double) -> Double {
  if time.is_nan() {
    return time
  }
  self.civil(time).weekday.to_double()
}

///|
/// `getHours()`.
pub fn Zone::hours(self : Zone, time : Double) -> Double {
  if time.is_nan() {
    return time
  }
  (self.civil(time).time / HOUR).floor()
}

///|
/// `getMinutes()`.
pub fn Zone::minutes(self : Zone, time : Double) -> Double {
  if time.is_nan() {
    return time
  }
  (self.civil(time).time / MINUTE).floor() % 60.0
}

///|
/// `getSeconds()`.
pub fn Zone::seconds(self : Zone, time : Double) -> Double {
  if time.is_nan() {
    return time
  }
  (self.civil(time).time / 1000.0).floor() % 60.0
}

///|
/// `getMilliseconds()`.
pub fn Zone::milliseconds(self : Zone, time : Double) -> Double {
  if time.is_nan() {
    return time
  }
  self.civil(time).time % 1000.0
}

///|
/// `getUTCSeconds()`.
pub fn utc_seconds(time : Double) -> Double {
  if time.is_nan() {
    return time
  }
  (civil(time).time / 1000.0).floor() % 60.0
}

///|
/// `getTimezoneOffset()`: UTC minus local time in whole minutes (V8
/// truncates the seconds of a local mean time).
pub fn Zone::timezone_offset(self : Zone, time : Double) -> Double {
  if time.is_nan() {
    return time
  }
  (-self.offset_at(time) / MINUTE).trunc() + 0.0
}

///|
/// `setDate(date)`, returning the new time value.
pub fn Zone::set_date(self : Zone, time : Double, date : Double) -> Double {
  if time.is_nan() {
    return time
  }
  let c = self.civil(time)
  self.from_local(
    make_date(make_day(c.year.to_double(), c.month.to_double(), date), c.time),
  )
}

///|
/// `setMonth(month[, date])`, returning the new time value.
pub fn Zone::set_month(
  self : Zone,
  time : Double,
  month : Double,
  date? : Double,
) -> Double {
  if time.is_nan() {
    return time
  }
  let c = self.civil(time)
  let date = date.unwrap_or(c.day.to_double())
  self.from_local(make_date(make_day(c.year.to_double(), month, date), c.time))
}

///|
/// `setFullYear(year[, month[, date]])`, returning the new time value. An
/// invalid date is treated as midnight UTC of the epoch.
pub fn Zone::set_full_year(
  self : Zone,
  time : Double,
  year : Double,
  month? : Double,
  date? : Double,
) -> Double {
  let c = if time.is_nan() { civil(0.0) } else { self.civil(time) }
  let month = month.unwrap_or(c.month.to_double())
  let date = date.unwrap_or(c.day.to_double())
  self.from_local(make_date(make_day(year, month, date), c.time))
}

///|
/// `setHours(hours[, minutes[, seconds[, ms]]])`, returning the new time
/// value.
pub fn Zone::set_hours(
  self : Zone,
  time : Double,
  hours : Double,
  minutes? : Double,
  seconds? : Double,
  ms? : Double,
) -> Double {
  if time.is_nan() {
    return time
  }
  let wall = time + self.offset_at(time)
  let day = (wall / MS_PER_DAY).floor()
  let within = wall - day * MS_PER_DAY
  let minutes = minutes.unwrap_or((within / MINUTE).floor() % 60.0)
  let seconds = seconds.unwrap_or((within / 1000.0).floor() % 60.0)
  let ms = ms.unwrap_or(within % 1000.0)
  self.from_local(make_date(day, make_time(hours, minutes, seconds, ms)))
}
