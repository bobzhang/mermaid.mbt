///|
/// A time zone as JavaScript's `Date` sees it: the UTC offset in force at
/// every instant.
///
/// `Date` has no zone of its own; local-time methods use the zone of the
/// machine. The reference renderings come from a machine in
/// `Asia/Shanghai`, so that is the zone the port emulates (`Zone::reference`).
pub struct Zone {
  name : String
  /// UTC instants (milliseconds since the epoch) at which the offset
  /// changes, ascending.
  starts : Array[Double]
  /// `offsets[i]` (local minus UTC, in milliseconds) applies from
  /// `starts[i - 1]` up to `starts[i]`; there is one more offset than
  /// there are transitions.
  offsets : Array[Double]
}

///|
const MINUTE : Double = 60000.0

///|
const HOUR : Double = 3600000.0

///|
/// The zone with no offset.
pub fn Zone::utc() -> Zone {
  { name: "UTC", starts: [], offsets: [0.0], }
}

///|
/// `Asia/Shanghai` as Chrome (ICU) reports it: local mean time until 1901,
/// UTC+8 since, with the daylight saving periods of 1919, 1940-1949 and
/// 1986-1991.
///
/// The table was read out of the reference browser by scanning
/// `new Date(t).getTimezoneOffset()` hour by hour from 1800 to 2500 and
/// bisecting each change down to the millisecond; the mean-time offset
/// (which `getTimezoneOffset` truncates to minutes) comes from
/// `new Date(1800, 0, 1).getTime()`.
pub fn Zone::shanghai() -> Zone {
  let standard = 8.0 * HOUR
  let daylight = 9.0 * HOUR
  let starts = [
    -2177481943000.0, -1600675200000.0, -1585904400000.0, -933667200000.0, -922093200000.0,
    -908870400000.0, -888829200000.0, -881049600000.0, -767869200000.0, -745833600000.0,
    -733827600000.0, -716889600000.0, -699613200000.0, -683884800000.0, -670669200000.0,
    -652348800000.0, -650019600000.0, 515527200000.0, 527014800000.0, 545162400000.0,
    558464400000.0, 577216800000.0, 589914000000.0, 608666400000.0, 621968400000.0,
    640116000000.0, 653418000000.0, 671565600000.0, 684867600000.0,
  ]
  // Local mean time of Shanghai: 8:05:43 ahead of Greenwich.
  let offsets = [8.0 * HOUR + 5.0 * MINUTE + 43000.0]
  for i in 0..<starts.length() {
    offsets.push(if i % 2 == 0 { standard } else { daylight })
  }
  { name: "Asia/Shanghai", starts, offsets, }
}

///|
/// The zone local times are computed in: the one of the machine the
/// reference renderings were made on.
pub fn Zone::reference() -> Zone {
  shanghai_zone
}

///|
let shanghai_zone : Zone = Zone::shanghai()

///|
/// The IANA name of the zone.
pub fn Zone::name(self : Zone) -> String {
  self.name
}

///|
/// Local time minus UTC, in milliseconds, at the UTC instant `time`.
pub fn Zone::offset_at(self : Zone, time : Double) -> Double {
  let mut index = 0
  while index < self.starts.length() && time >= self.starts[index] {
    index += 1
  }
  self.offsets[index]
}

///|
/// The UTC instant of a local time, as V8 resolves it: a local time that
/// occurs twice (clocks set back) or never (clocks set forward) is read
/// with the offset in force before the change.
pub fn Zone::to_utc(self : Zone, wall : Double) -> Double {
  let count = self.starts.length()
  for index in 0..<count {
    if wall - self.offsets[index] < self.starts[index] {
      return wall - self.offsets[index]
    }
    // Not before this change by the old offset, yet before it by the new
    // one: the local time was skipped.
    if wall - self.offsets[index + 1] < self.starts[index] {
      return wall - self.offsets[index]
    }
  }
  wall - self.offsets[count]
}
