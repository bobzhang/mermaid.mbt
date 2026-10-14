// The semantic actions of mermaid's `block.jison`.

///|
/// What a grammar symbol stands for while parsing.
priv enum Value {
  /// No value: jison's `undefined`.
  Nothing
  /// The text of a token.
  Text(String)
  /// A link between two blocks: the characters it was drawn with and its
  /// label.
  Link(edge_type~ : String, label~ : String)
  /// A block as named in a statement: its id and what its brackets hold.
  NodeRef(
    id~ : String,
    label~ : String?,
    type_str~ : String?,
    directions~ : Array[String]?
  )
  /// The brackets after an id, their label and, for a block arrow, the
  /// directions it points in.
  Shape(type_str~ : String, label~ : String, directions~ : Array[String]?)
  Directions(Array[String])
  /// One statement.
  Statement(Block)
  /// A document, or the three statements a link stands for. Upstream
  /// nests the latter in the former and flattens before use.
  Statements(Array[Block])
}

///|
/// `parseInt` of a token made of digits, possibly signed.
fn parse_int(text : String) -> Double {
  @string.parse_double(text) catch {
    _ => @double.not_a_number
  }
}

///|
/// The grammar's custom lexer code, by number (see the head of
/// `gen_block_grammar.mbt`).
fn lexer_hook(hook : Int32, lexer : @jison.Lexer) -> @jison.HookResult {
  let text = lexer.text()
  let after = (prefix : String) => {
    let pattern = try! @jsregex.Regex::compile(prefix)
    pattern.replace(text, _ => "")
  }
  match hook {
    0 => lexer.set_text("-1")
    1 => lexer.set_text(after("columns\\s+"))
    2 => lexer.set_text(after("space\\:"))
    3 => lexer.set_text("1")
    4..<=9 => lexer.set_text(after("^,\\s*"))
    10 => lexer.set_text("]>")
    11 => lexer.set_text(text[1:].to_owned())
    _ => ()
  }
  Continue
}

///|
/// jison's `performAction` for block.jison: run the semantic action of one
/// production. `None` keeps the default value, that of the first symbol.
fn BlockDb::reduce(
  self : BlockDb,
  reduction : @jison.Reduction[Value],
) -> Value? raise BlockError {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  let s = (k : Int32) => {
    match v(k) {
      Text(text) => text
      _ => ""
    }
  }
  // The statements a symbol holds, flattened as upstream does later.
  let statements = (value : Value) => {
    match value {
      Statement(block) => [block]
      Statements(blocks) => blocks
      _ => []
    }
  }
  match reduction.production {
    7 => {
      self.set_hierarchy(statements(v(1)))
      None
    }
    12 => Some(Statements(statements(v(0))))
    13 => Some(Statements([..statements(v(1)), ..statements(v(0))]))
    14 => Some(Link(edge_type=s(0), label=""))
    15 => Some(Link(edge_type=s(0), label=s(1)))
    18 => {
      let width = parse_int(s(0))
      Some(
        Statement(
          Block::new(
            id=self.generate_id(),
            type_="space",
            label="",
            space_width=width,
          ),
        ),
      )
    }
    23 => {
      guard v(1) is Link(edge_type~, label~) &&
        v(0) is NodeRef(id~, label=node_label, type_str~, directions~) else {
        return None
      }
      // A chain of links has an array for its left side, whose `id`,
      // `label`, `type` and `directions` are all undefined.
      let first = match v(2) {
        Statement(block) =>
          Block::new(
            id?=block.id,
            label?=block.label,
            type_?=block.type_,
            directions?=block.directions,
          )
        _ => Block::new()
      }
      let edge = Block::new(
        id=first.id_text() + "-" + id,
        start?=first.id,
        end=id,
        label~,
        type_="edge",
        thickness=edge_thickness(edge_type),
        pattern=edge_pattern(edge_type),
        directions?,
        arrow_type_end=edge_end_type(edge_type),
        arrow_type_start=edge_start_type(edge_type),
      )
      let last = Block::new(
        id~,
        label?=node_label,
        type_=type_of_brackets(type_str),
        directions?,
      )
      Some(Statements([first, edge, last]))
    }
    24 | 25 => {
      let node = if reduction.production == 24 { v(1) } else { v(0) }
      guard node is NodeRef(id~, label~, type_str~, directions~) else {
        return None
      }
      let width_in_columns = if reduction.production == 24 {
        parse_int(s(0))
      } else {
        1.0
      }
      Some(
        Statement(
          Block::new(
            id~,
            label?,
            type_=type_of_brackets(type_str),
            directions?,
            width_in_columns~,
          ),
        ),
      )
    }
    26 =>
      Some(
        Statement(Block::new(type_="column-setting", columns=parse_int(s(0)))),
      )
    27 => {
      // The id it draws is never used, but it is drawn.
      self.generate_id() |> ignore
      let children = statements(v(1))
      // `{ ...$2, type: 'composite', children: $3 }`: spreading the array
      // a chain of links stands for leaves none of the properties below.
      let block = match v(2) {
        Statement(block) =>
          Block::new(
            id?=block.id,
            label?=block.label,
            type_="composite",
            directions?=block.directions,
            width_in_columns?=block.width_in_columns,
            children~,
          )
        _ => Block::new(type_="composite", children~)
      }
      Some(Statement(block))
    }
    28 =>
      Some(
        Statement(
          Block::new(
            id=self.generate_id(),
            type_="composite",
            label="",
            children=statements(v(1)),
          ),
        ),
      )
    29 => Some(NodeRef(id=s(0), label=None, type_str=None, directions=None))
    30 => {
      guard v(0) is Shape(type_str~, label~, directions~) else { return None }
      Some(
        NodeRef(
          id=s(1),
          label=Some(label),
          type_str=Some(type_str),
          directions~,
        ),
      )
    }
    31 => Some(Directions([s(0)]))
    32 => {
      let rest = match v(0) {
        Directions(rest) => rest
        _ => []
      }
      Some(Directions([s(1), ..rest]))
    }
    33 => Some(Shape(type_str=s(2) + s(0), label=s(1), directions=None))
    34 => {
      let directions = match v(1) {
        Directions(directions) => directions
        _ => []
      }
      Some(Shape(type_str=s(3) + s(0), label=s(2), directions=Some(directions)))
    }
    35 | 36 =>
      Some(
        Statement(
          Block::new(type_="classDef", id=js_trim(s(1)), css=js_trim(s(0))),
        ),
      )
    37 =>
      Some(
        Statement(
          Block::new(
            type_="applyClass",
            id=js_trim(s(1)),
            style_class=js_trim(s(0)),
          ),
        ),
      )
    38 =>
      Some(
        Statement(
          Block::new(
            type_="applyStyles",
            id=js_trim(s(1)),
            styles_str=js_trim(s(0)),
          ),
        ),
      )
    _ => None
  }
}

///|
/// Parse block diagram source into its database.
pub fn parse(source : String, config : @config.Config) -> BlockDb raise {
  let db = BlockDb::new(config)
  block_grammar.parse(
    source,
    empty=Nothing,
    token=text => Text(text),
    reduce=reduction => db.reduce(reduction),
    hook=lexer_hook,
  )
  |> ignore
  db
}
