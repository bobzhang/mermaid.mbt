///|
/// jison's `performAction` for journey.jison: run the semantic action of
/// one production. `None` keeps the default value, that of the first
/// symbol.
fn Journey::reduce(
  self : Journey,
  reduction : @jison.Reduction[String],
) -> String? raise @journeycommon.SanitizeError {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  match reduction.production {
    8 => {
      // The keyword and the one blank after it are dropped; the rest is
      // kept as written.
      let title = v(0)[6:].to_owned()
      self.title = @journeycommon.sanitize_text(title)
      Some(title)
    }
    9 => {
      let title = @journeycommon.js_trim(v(0))
      self.acc_title = @journeycommon.acc_title(title)
      Some(title)
    }
    10 | 11 => {
      let description = @journeycommon.js_trim(v(0))
      self.acc_description = @journeycommon.acc_description(description)
      Some(description)
    }
    12 => {
      let section = v(0)[8:].to_owned()
      self.current_section = section
      Some(section)
    }
    13 => {
      self.add_task(v(1), v(0))
      Some("task")
    }
    _ => None
  }
}

///|
/// Parse the text of a journey diagram.
pub fn parse(source : String) -> Journey raise {
  let journey = Journey::new()
  journey_grammar.parse(source, empty="", token=text => text, reduce=reduction => {
    journey.reduce(reduction)
  })
  |> ignore
  journey
}
