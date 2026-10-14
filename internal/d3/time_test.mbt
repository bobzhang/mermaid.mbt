// Expected values come from the bundled d3 (scripts/gantt_node.mjs);
// scripts/check_time.py compares the two on random cases.

///|
fn stamps(times : Array[Double]) -> String {
  let zone = @jsdate.Zone::reference()
  times.map(@d3.time_format(zone, "%Y-%m-%d %H:%M:%S.%L")).join("\n")
}

///|
test "default ticks pick a calendar step" {
  let zone = @jsdate.Zone::reference()
  let scale = @d3.TimeScale::new(zone)
  // Two months: weeks.
  scale.set_domain(1388505600000.0, 1393603200000.0) |> ignore
  inspect(
    stamps(scale.ticks()),
    content=(
      #|2014-01-05 00:00:00.000
      #|2014-01-12 00:00:00.000
      #|2014-01-19 00:00:00.000
      #|2014-01-26 00:00:00.000
      #|2014-02-02 00:00:00.000
      #|2014-02-09 00:00:00.000
      #|2014-02-16 00:00:00.000
      #|2014-02-23 00:00:00.000
    ),
  )
  // Thirty years: every other year, through d3-array's tick step.
  scale.set_domain(946656000000.0, 1893427200000.0) |> ignore
  inspect(scale.ticks().length(), content="16")
  inspect(
    stamps(scale.ticks()[1:2].to_owned()),
    content="2002-01-01 00:00:00.000",
  )
  // Four milliseconds: every one of them.
  scale.set_domain(1388505600000.0, 1388505600004.0) |> ignore
  inspect(scale.ticks().length(), content="5")
}

///|
test "ticks of a given interval" {
  let zone = @jsdate.Zone::reference()
  let scale = @d3.TimeScale::new(zone).set_domain(
    1388505600000.0, 1393603200000.0,
  )
  // Every other Monday, counted from the epoch.
  inspect(
    stamps(scale.ticks_every(@d3.time_week(zone, 1).every(2.0).unwrap())),
    content=(
      #|2014-01-13 00:00:00.000
      #|2014-01-27 00:00:00.000
      #|2014-02-10 00:00:00.000
      #|2014-02-24 00:00:00.000
    ),
  )
  // Every other day restarts on the first of the month.
  let days = scale.ticks_every(@d3.time_day(zone).every(2.0).unwrap())
  inspect(
    stamps(days[14:18].to_owned()),
    content=(
      #|2014-01-29 00:00:00.000
      #|2014-01-31 00:00:00.000
      #|2014-02-01 00:00:00.000
      #|2014-02-03 00:00:00.000
    ),
  )
}

///|
test "time format directives" {
  let zone = @jsdate.Zone::reference()
  // An unknown directive loses its percent sign; so does a trailing one.
  inspect(
    @d3.time_format(zone, "%Y-%m-%d %H:%M %a %b %e %j %U %V %p %Z %% %k %")(
      1388915340000.0,
    ),
    content="2014-01-05 17:49 Sun Jan  5 005 01 01 PM +0800 % k ",
  )
}

///|
test "rounded positions" {
  let zone = @jsdate.Zone::reference()
  let scale = @d3.TimeScale::new(zone)
    .set_domain(1388505600000.0, 1393603200000.0)
    .set_range_round(0.0, 590.0)
  let positions : Json = [
    scale.apply(1388505600000.0),
    scale.apply(1391097600000.0),
    scale.apply(1393603200000.0),
    scale.apply(1396000000000.0),
  ]
  json_inspect(positions, content=[0, 300, 590, 867])
}

///|
test "tick steps of 1, 2 and 5" {
  let steps : Json = [
    @d3.tick_step(0.0, 1.0, 10.0),
    @d3.tick_step(0.0, 45.0, 10.0),
    @d3.tick_step(0.0, 30.0, 10.0),
    @d3.tick_step(0.0, 1000.0, 3.0),
  ]
  json_inspect(steps, content=[0.1, 5, 2, 500])
  let ticks = Json::array(@d3.ticks(0.0, 1.0, 5.0).map(x => Json::number(x)))
  json_inspect(ticks, content=[0, 0.2, 0.4, 0.6, 0.8, 1])
}

///|
test "axis markup" {
  let group = @dom.Element::new("g")
  @d3.axis(
    group,
    Bottom,
    [(47.0, "a"), (130.0, "b")],
    (0.0, 590.0),
    tick_size_inner=-111.0,
    tick_size_outer=-111.0,
  )
  inspect(
    group.to_html(),
    content=(
      #|<g fill="none" font-size="10" font-family="sans-serif" text-anchor="middle"><path class="domain" stroke="currentColor" d="M0.5,-111V0.5H590.5V-111"></path><g class="tick" opacity="1" transform="translate(47.5,0)"><line stroke="currentColor" y2="-111"></line><text fill="currentColor" y="3" dy="0.71em">a</text></g><g class="tick" opacity="1" transform="translate(130.5,0)"><line stroke="currentColor" y2="-111"></line><text fill="currentColor" y="3" dy="0.71em">b</text></g></g>
    ),
  )
}
