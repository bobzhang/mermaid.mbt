///|
/// jison's `performAction` for ishikawa.jison. `None` keeps the default
/// value, that of the first symbol.
fn Ishikawa::reduce(
  self : Ishikawa,
  reduction : @jison.Reduction[String],
) -> String? raise {
  let values = reduction.values
  let n = values.length()
  match reduction.production {
    // statement: SPACELIST TEXT — the width of the indentation is the level.
    15 => {
      self.add_node(
        values[n - 2].length(),
        @journeycommon.js_trim(values[n - 1]),
      )
      None
    }
    // statement: TEXT
    16 => {
      self.add_node(0, @journeycommon.js_trim(values[n - 1]))
      None
    }
    _ => None
  }
}

///|
/// Parse the text of an Ishikawa diagram.
pub fn parse(source : String) -> Ishikawa raise {
  let diagram = Ishikawa::new()
  ishikawa_grammar.parse(source, empty="", token=text => text, reduce=reduction => {
    diagram.reduce(reduction)
  })
  |> ignore
  diagram
}
