///|
fn number_or_null(value : Double) -> Json {
  if value.is_nan() {
    Json::null()
  } else {
    Json::number(value)
  }
}

///|
fn numbers(values : Array[Json]) -> Array[Double] {
  values.map(value => {
    match value {
      Number(n, ..) => n
      _ => @double.not_a_number
    }
  })
}

///|
/// Evaluate `Date` operations in the emulated time zone, for comparing
/// with the reference browser. Each case is one of
/// `{"parse": text}`, `{"make": [year, month, ...]}`,
/// `{"fields": time}`, `{"set": name, "time": time, "args": [...]}`,
/// `{"log10": bits}` (the floor of the logarithm of the double with these
/// bits, in hexadecimal) and `{"pow10": n}` (the bits of `10 ** n`).
fn dates(path : String) -> Unit raise CliError {
  guard read_json(path) is Array(cases) else {
    raise CliError("\{path} must hold an array of cases", status=2)
  }
  let zone = @jsdate.Zone::system()
  let results : Array[Json] = []
  for item in cases {
    let result = match item {
      { "parse": String(text), .. } => number_or_null(zone.parse(text))
      { "make": Array(args), .. } => {
        let a = numbers(args)
        let get = (i : Int32, default : Double) => {
          if i < a.length() {
            a[i]
          } else {
            default
          }
        }
        number_or_null(
          zone.make(
            get(0, 0.0),
            get(1, 0.0),
            date=get(2, 1.0),
            hours=get(3, 0.0),
            minutes=get(4, 0.0),
            seconds=get(5, 0.0),
            ms=get(6, 0.0),
          ),
        )
      }
      { "fields": Number(time, ..), .. } =>
        Json::array(
          [
            zone.full_year(time),
            zone.month(time),
            zone.date(time),
            zone.day(time),
            zone.hours(time),
            zone.minutes(time),
            zone.seconds(time),
            zone.milliseconds(time),
            zone.timezone_offset(time),
          ].map(number_or_null),
        )
      { "set": String(name), "time": time, "args": Array(args), .. } => {
        let time = match time {
          Number(n, ..) => n
          _ => @double.not_a_number
        }
        let a = numbers(args)
        let optional = (i : Int32) => {
          if i < a.length() {
            Some(a[i])
          } else {
            None
          }
        }
        number_or_null(
          match name {
            "date" => zone.set_date(time, a[0])
            "month" => zone.set_month(time, a[0], date?=optional(1))
            "fullYear" =>
              zone.set_full_year(
                time,
                a[0],
                month?=optional(1),
                date?=optional(2),
              )
            _ =>
              zone.set_hours(
                time,
                a[0],
                minutes?=optional(1),
                seconds?=optional(2),
                ms?=optional(3),
              )
          },
        )
      }
      { "log10": String(bits), .. } => {
        let x = (@string.parse_int64(bits, base=16) catch { _ => 0L }).reinterpret_as_double()
        number_or_null(@jsmath.floor_log10(x))
      }
      { "pow10": Number(n, ..), .. } =>
        Json::string(
          @jsmath.pow10(n.to_int()).reinterpret_as_int64().to_string(radix=16),
        )
      _ => Json::null()
    }
    results.push(result)
  }
  println(Json::array(results).stringify())
}

///|
fn field_number(item : Json, name : String) -> Double {
  match item {
    Object(fields) =>
      match fields.get(name) {
        Some(Number(n, ..)) => n
        _ => @double.not_a_number
      }
    _ => @double.not_a_number
  }
}

///|
fn field_text(item : Json, name : String) -> String {
  match item {
    Object(fields) =>
      match fields.get(name) {
        Some(String(text)) => text
        _ => ""
      }
    _ => ""
  }
}

///|
/// Evaluate one dayjs or d3 time operation; the cases are those of
/// scripts/gantt_node.mjs.
fn time_case(item : Json) -> Json raise {
  let zone = @jsdate.Zone::system()
  let now = match field_number(item, "now") {
    n if n.is_nan() => 0.0
    n => n
  }
  let at = (name : String) => @dayjs.Dayjs::new(zone, field_number(item, name))
  match field_text(item, "op") {
    "parse" =>
      number_or_null(
        @dayjs.Dayjs::parse(
          zone,
          field_text(item, "text"),
          field_text(item, "format"),
          now~,
        ).value_of(),
      )
    "format" => Json::string(at("time").format(field_text(item, "format")))
    "add" =>
      number_or_null(
        at("time")
        .add(field_number(item, "amount"), field_text(item, "unit"))
        .value_of(),
      )
    "startOfDay" => number_or_null(at("time").start_of_day().value_of())
    "endOfDay" => number_or_null(at("time").end_of_day().value_of())
    "diffYears" => number_or_null(at("a").diff_years(at("b")))
    "isoWeekday" => number_or_null(at("time").iso_weekday())
    "duration" =>
      number_or_null(
        @dayjs.duration_milliseconds(
          field_text(item, "unit"),
          field_number(item, "amount"),
        ),
      )
    other => fail("unknown op \{other}")
  }
}

///|
/// Evaluate dayjs and d3 time operations, for comparing with the bundled
/// libraries (scripts/check_time.py).
fn time_cases(path : String) -> Unit raise CliError {
  guard read_json(path) is Array(cases) else {
    raise CliError("\{path} must hold an array of cases", status=2)
  }
  let results : Array[Json] = []
  for item in cases {
    results.push(
      time_case(item) catch {
        @dayjs.DayjsError(message) => { "error": message }
        error => { "error": Repr(error).to_string() }
      },
    )
  }
  println(Json::array(results).stringify())
}
