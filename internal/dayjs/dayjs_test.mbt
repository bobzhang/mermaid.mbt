// Expected values come from the bundled dayjs; scripts/check_time.py
// compares the two on random cases.

///|
test "strict parsing gives the text back or nothing" {
  let zone = @jsdate.Zone::reference()
  let parse = (text : String, format : String) => {
    @dayjs.Dayjs::parse(zone, text, format, now=1700000000000.0).value_of()
  }
  inspect(parse("2014-01-05", "YYYY-MM-DD"), content="1388851200000")
  inspect(parse("2014-1-5", "YYYY-MM-DD").is_nan(), content="true")
  inspect(parse("2014-02-30", "YYYY-MM-DD").is_nan(), content="true")
  // What the format leaves out is today's.
  inspect(parse("17:49", "HH:mm"), content="1700041740000")
  // Locale-dependent tokens and the empty format are never valid.
  inspect(parse("2014-01-05", "L").is_nan(), content="true")
  inspect(parse("2014-01-05", "").is_nan(), content="true")
  inspect(parse("1388851200000", "x"), content="1388851200000")
}

///|
test "week tokens need a plugin mermaid does not load" {
  let zone = @jsdate.Zone::reference()
  let date = @dayjs.Dayjs::new(zone, 1388851200000.0)
  inspect(
    date.format("YYYY-MM-DD Do Q W GGGG"),
    content="2014-01-05 5th 1 1 2014",
  )
  inspect(
    date.format("dddd [the] D, hh:mm a Z ZZ"),
    content="Sunday the 5, 12:00 am +08:00 +0800",
  )
  try date.format("w") catch {
    @dayjs.DayjsError(message) =>
      inspect(message, content="t2.week is not a function")
  } noraise {
    _ => fail("expected the week token to fail")
  }
}

///|
test "calendar arithmetic" {
  let zone = @jsdate.Zone::reference()
  let date = @dayjs.Dayjs::new(zone, zone.make(2014.0, 0.0, date=31.0))
  // A month after January 31st is the last day of February.
  inspect(date.add(1.0, "M").format("YYYY-MM-DD"), content="2014-02-28")
  inspect(
    date.add(1.5, "d").format("YYYY-MM-DD HH:mm"),
    content="2014-02-02 00:00",
  )
  inspect(
    date.add(1.5, "h").format("YYYY-MM-DD HH:mm"),
    content="2014-01-31 01:30",
  )
  inspect(
    date.end_of_day().value_of() - date.start_of_day().value_of(),
    content="86399999",
  )
  inspect(date.add(6.0, "y").diff_years(date), content="6")
  inspect(@dayjs.duration_milliseconds("month", 2.0), content="5256000000")
}
