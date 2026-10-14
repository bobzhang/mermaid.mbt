// Expected values were read out of the reference browser; see
// scripts/check_dates.py for the random comparison.

///|
test "local dates around the offset changes of Asia/Shanghai" {
  let zone = @jsdate.Zone::reference()
  // 2:30 on the night the clocks went forward in 1986 does not exist; it
  // is read with the offset before the change.
  inspect(
    zone.make(1986.0, 4.0, date=4.0, hours=2.0, minutes=30.0),
    content="515529000000",
  )
  // 1:30 on the night they went back happened twice; the first one counts.
  inspect(
    zone.make(1986.0, 8.0, date=14.0, hours=1.0, minutes=30.0),
    content="527013000000",
  )
  // Local mean time before 1901.
  inspect(zone.make(1800.0, 0.0), content="-5364691543000")
  inspect(zone.timezone_offset(-5364691543000.0), content="-485")
  inspect(zone.make(50.0, 0.0), content="-631180800000")
  inspect(zone.make(2014.9, 0.0, date=-1.9), content="1388332800000")
  inspect(
    zone.make(275760.0, 8.0, date=13.0, hours=8.0, ms=1.0).is_nan(),
    content="true",
  )
}

///|
test "fields and setters" {
  let zone = @jsdate.Zone::reference()
  let time = zone.make(2014.0, 0.0, date=31.0, hours=13.0, minutes=5.0)
  let fields : Json = [
    zone.full_year(time),
    zone.month(time),
    zone.date(time),
    zone.day(time),
    zone.hours(time),
    zone.minutes(time),
  ]
  json_inspect(fields, content=[2014, 0, 31, 5, 13, 5])
  // January 31st plus one month overflows into March.
  inspect(zone.month(zone.set_month(time, 1.0)), content="2")
  inspect(zone.date(zone.set_date(time, 0.0)), content="31")
  inspect(zone.month(zone.set_date(time, 0.0)), content="11")
  inspect(
    zone.set_hours(time, 0.0, minutes=0.0, seconds=0.0, ms=0.0),
    content="1391097600000",
  )
}

///|
test "date strings" {
  let zone = @jsdate.Zone::reference()
  // A date alone is UTC, a date with a time is local.
  inspect(zone.parse("2014-01-01"), content="1388534400000")
  inspect(zone.parse("2014-01-01T00:00"), content="1388505600000")
  // The legacy forms are local.
  inspect(zone.parse("2014-1-1"), content="1388505600000")
  inspect(zone.parse("Jan 5, 2014 17:49"), content="1388915340000")
  inspect(zone.parse("1/1"), content="978278400000")
  inspect(zone.parse("50"), content="-631180800000")
  inspect(zone.parse("56 UT 05::25"), content="-441831575000")
  inspect(zone.parse("2014-13-01").is_nan(), content="true")
  inspect(zone.parse("").is_nan(), content="true")
}
