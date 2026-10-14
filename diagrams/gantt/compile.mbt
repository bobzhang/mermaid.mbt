// Working out the dates of the tasks: `getTasks` of `ganttDb.js` and what
// it calls.

///|
let after_statement : @jsregex.Regex = regex("^after\\s+([\\d\\w- ]+)")

///|
let until_statement : @jsregex.Regex = regex("^until\\s+([\\d\\w- ]+)")

///|
let all_digits : @jsregex.Regex = regex("^\\d+$")

///|
let duration : @jsregex.Regex = regex("^(\\d+(?:\\.\\d+)?)([Mdhmswy]|ms)$")

///|
/// The moment the chart is drawn at, and midnight of that day: what an
/// `after` or `until` falls back to when it names no known task.
fn GanttDb::today(self : GanttDb, now : Double) -> Double {
  self.zone.set_hours(now, 0.0, minutes=0.0, seconds=0.0, ms=0.0)
}

///|
fn GanttDb::parse_date(
  self : GanttDb,
  text : String,
  format : String,
  now : Double,
) -> @dayjs.Dayjs raise GanttError {
  @dayjs.Dayjs::parse(self.zone, text, format, now~) catch {
    @dayjs.DayjsError(message) => raise GanttError(message)
  }
}

///|
/// The ids an `after` or `until` statement refers to.
fn referenced_ids(found : @jsregex.Match) -> Array[String] {
  found
  .group(1)
  .unwrap_or("")
  .split(" ")
  .filter(id => !id.is_empty())
  .map(id => id.to_owned())
  .collect()
}

///|
/// The start a task's data asks for: a timestamp, the latest end of the
/// tasks it comes `after`, a date in the chart's format, or failing that
/// whatever `new Date(text)` makes of it.
fn GanttDb::start_date(
  self : GanttDb,
  text : String,
  now : Double,
) -> Double? raise GanttError {
  let text = js_trim(text)
  let format = js_trim(self.date_format)
  if (format == "x" || format == "X") && all_digits.matches(text) {
    let value = @string.parse_double(text) catch { _ => @double.not_a_number }
    return Some(@jsdate.time_clip(value))
  }
  if after_statement.exec(text) is Some(found) {
    let mut latest : Task? = None
    for id in referenced_ids(found) {
      guard self.find_task(id) is Some(task) else { continue }
      match latest {
        None => latest = Some(task)
        Some(other) =>
          if task.end_time is Some(end) &&
            other.end_time is Some(other_end) &&
            end > other_end {
            latest = Some(task)
          }
      }
    }
    return match latest {
      Some(task) => task.end_time
      None => Some(self.today(now))
    }
  }
  let parsed = self.parse_date(text, format, now)
  if parsed.is_valid() {
    return Some(parsed.value_of())
  }
  let date = self.zone.parse(text)
  // Beyond the year 10000 either way counts as a typo.
  if date.is_nan() ||
    self.zone.full_year(date) < -10000.0 ||
    self.zone.full_year(date) > 10000.0 {
    raise GanttError("Invalid date:" + text)
  }
  Some(date)
}

///|
/// `parseDuration`: the amount and unit of a duration such as `3d`, NaN
/// when the text is none.
fn parse_duration(text : String) -> (Double, String) {
  match duration.exec(js_trim(text)) {
    Some(found) => {
      let amount = @string.parse_double(found.group(1).unwrap_or("")) catch {
        _ => @double.not_a_number
      }
      (amount, found.group(2).unwrap_or("ms"))
    }
    None => (@double.not_a_number, "ms")
  }
}

///|
/// The end a task's data asks for: the earliest start of the tasks it
/// lasts `until`, a date in the chart's format, or the start plus a
/// duration (nothing added when the text is neither).
fn GanttDb::end_date(
  self : GanttDb,
  start : Double,
  text : String,
  now : Double,
) -> Double? raise GanttError {
  let text = js_trim(text)
  if until_statement.exec(text) is Some(found) {
    let mut earliest : Task? = None
    for id in referenced_ids(found) {
      guard self.find_task(id) is Some(task) else { continue }
      match earliest {
        None => earliest = Some(task)
        Some(other) =>
          if task.start_time is Some(start) &&
            other.start_time is Some(other_start) &&
            start < other_start {
            earliest = Some(task)
          }
      }
    }
    return match earliest {
      Some(task) => task.start_time
      None => Some(self.today(now))
    }
  }
  let parsed = self.parse_date(text, js_trim(self.date_format), now)
  if parsed.is_valid() {
    let parsed = if self.inclusive_end_dates {
      parsed.add(1.0, "d")
    } else {
      parsed
    }
    return Some(parsed.value_of())
  }
  let end = @dayjs.Dayjs::new(self.zone, start)
  let (amount, unit) = parse_duration(text)
  if amount.is_nan() {
    return Some(end.value_of())
  }
  let moved = end.add(amount, unit)
  Some(if moved.is_valid() { moved.value_of() } else { end.value_of() })
}

///|
/// `isInvalidDate`: whether a day is excluded from the chart.
fn GanttDb::is_excluded(
  self : GanttDb,
  date : @dayjs.Dayjs,
) -> Bool raise GanttError {
  let formatted = date.format(js_trim(self.date_format)) catch {
    @dayjs.DayjsError(message) => raise GanttError(message)
  }
  let date_only = date.format("YYYY-MM-DD") catch {
    @dayjs.DayjsError(message) => raise GanttError(message)
  }
  if self.includes.contains(formatted) || self.includes.contains(date_only) {
    return false
  }
  let weekend_start = if self.weekend == "friday" { 5.0 } else { 6.0 }
  if self.excludes.contains("weekends") &&
    (
      date.iso_weekday() == weekend_start ||
      date.iso_weekday() == weekend_start + 1.0
    ) {
    return true
  }
  let weekday = date.format("dddd") catch {
    @dayjs.DayjsError(message) => raise GanttError(message)
  }
  if self.excludes.contains(weekday.to_lower()) {
    return true
  }
  self.excludes.contains(formatted) || self.excludes.contains(date_only)
}

///|
/// `checkTaskDates`: push the end of a task back by one day for every
/// excluded day it spans, unless its end was given as a date.
fn GanttDb::check_task_dates(
  self : GanttDb,
  task : Task,
) -> Unit raise GanttError {
  if self.excludes.is_empty() || task.manual_end_time {
    return
  }
  guard task.start_time is Some(start) && task.end_time is Some(end) else {
    return
  }
  let mut day = @dayjs.Dayjs::new(self.zone, start).add(1.0, "d")
  let mut end = @dayjs.Dayjs::new(self.zone, end)
  let mut invalid = false
  let mut render_end : Double? = None
  let limit = end.add(10000.0, "d")
  while day.value_of() <= end.value_of() {
    if !invalid {
      render_end = Some(end.value_of())
    }
    invalid = self.is_excluded(day)
    if invalid {
      end = end.add(1.0, "d")
      if end.value_of() > limit.value_of() {
        raise GanttError(
          "Failed to find a valid date that was not excluded by `excludes` after 10,000 iterations.",
        )
      }
    }
    day = day.add(1.0, "d")
  }
  task.end_time = Some(end.value_of())
  task.render_end_time = render_end
}

///|
/// One pass over the tasks in order, each from the state the others are
/// in at that moment. Returns whether every task has its dates.
fn GanttDb::compile_tasks(
  self : GanttDb,
  now : Double,
) -> Bool raise GanttError {
  let mut all_processed = true
  for task in self.tasks {
    guard task.raw is Some((raw_start, raw_end)) else {
      raise GanttError("Cannot read properties of undefined (reading 'type')")
    }
    match raw_start {
      PrevTaskEnd => {
        guard self.find_task(task.prev_task_id.unwrap_or("undefined"))
          is Some(previous) else {
          raise GanttError(
            "Cannot read properties of undefined (reading 'endTime')",
          )
        }
        task.start_time = previous.end_time
      }
      StartDate(text) =>
        if self.start_date(text, now) is Some(start) {
          task.start_time = Some(start)
        }
    }
    if task.start_time is Some(start) {
      task.end_time = self.end_date(start, raw_end, now)
      if task.end_time is Some(_) {
        task.processed = true
        task.manual_end_time = self
          .parse_date(raw_end, "YYYY-MM-DD", now)
          .is_valid()
        self.check_task_dates(task)
      }
    }
    all_processed = all_processed && task.processed
  }
  all_processed
}

///|
/// `getTasks`: work out every task's dates. A task may refer to one
/// written after it, so the pass is repeated until all are settled, ten
/// more times at most.
pub fn GanttDb::compile(
  self : GanttDb,
  now : Double,
) -> Array[Task] raise GanttError {
  let mut all_processed = self.compile_tasks(now)
  let mut iterations = 0
  while !all_processed && iterations < 10 {
    all_processed = self.compile_tasks(now)
    iterations += 1
  }
  self.tasks
}
