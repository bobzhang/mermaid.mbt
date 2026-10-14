///|
/// jison's `performAction` for timeline.jison: run the semantic action of
/// one production. `None` keeps the default value, that of the first
/// symbol.
fn Timeline::reduce(
  self : Timeline,
  reduction : @jison.Reduction[String],
) -> String? raise {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  match reduction.production {
    3 => {
      self.direction = "LR"
      None
    }
    4 => {
      self.direction = "TD"
      None
    }
    11 => {
      // The keyword and the one blank after it are dropped; the rest is
      // kept as written.
      let title = v(0)[6:].to_owned()
      self.title = @journeycommon.sanitize_text(title)
      Some(title)
    }
    12 => {
      let title = @journeycommon.js_trim(v(0))
      self.acc_title = @journeycommon.acc_title(title)
      Some(title)
    }
    13 | 14 => {
      let description = @journeycommon.js_trim(v(0))
      self.acc_description = @journeycommon.acc_description(description)
      Some(description)
    }
    15 => {
      let section = v(0)[8:].to_owned()
      self.current_section = section
      self.sections.push(section)
      Some(section)
    }
    18 => {
      self.tasks.push({ section: self.current_section, task: v(0), events: [], })
      None
    }
    19 => {
      // The colon and the blank after it are dropped. Upstream fails on
      // an event before the first period, reading `events` of nothing.
      guard self.tasks.last() is Some(task) else {
        raise TimelineError(
          "Cannot read properties of undefined (reading 'events')",
        )
      }
      task.events.push(v(0)[2:].to_owned())
      None
    }
    _ => None
  }
}

///|
/// Parse the text of a timeline diagram.
pub fn parse(source : String) -> Timeline raise {
  let timeline = Timeline::new()
  timeline_grammar.parse(source, empty="", token=text => text, reduce=reduction => {
    timeline.reduce(reduction)
  })
  |> ignore
  timeline
}
