///|
/// A node of the concrete syntax tree: what one rule matched. Tokens are
/// filed under the name of the type the rule asked for, sub-rules under
/// their own name, each list in the order of the input.
pub struct CstNode {
  name : String
  children : Map[String, Array[CstElement]]
  /// Where the first token of the node starts, -1 for a node without.
  mut start : Int32
}

///|
pub(all) enum CstElement {
  Leaf(Token)
  Node(CstNode)
}

///|
/// The sub-rules of `self` filed under `key`.
pub fn CstNode::nodes(self : CstNode, key : String) -> Array[CstNode] {
  let found = []
  for element in self.children.get(key).unwrap_or([]) {
    if element is Node(node) {
      found.push(node)
    }
  }
  found
}

///|
/// The tokens of `self` filed under `key`.
pub fn CstNode::tokens(self : CstNode, key : String) -> Array[Token] {
  let found = []
  for element in self.children.get(key).unwrap_or([]) {
    if element is Leaf(token) {
      found.push(token)
    }
  }
  found
}

///|
fn CstNode::collect(self : CstNode, into : Array[Token]) -> Unit {
  for _, elements in self.children {
    for element in elements {
      match element {
        Leaf(token) => into.push(token)
        Node(node) => node.collect(into)
      }
    }
  }
}

///|
/// Every token under `self`, in the order of the input.
pub fn CstNode::all_tokens(self : CstNode) -> Array[Token] {
  let found = []
  self.collect(found)
  found.sort_by_key(token => token.start)
  found
}

///|
/// A parse in progress, as predicates see it.
pub struct Parser {
  priv grammar : Grammar
  priv input : Array[Token]
  priv mut position : Int32
  priv end_of_input : Token
  priv gate : (String, Parser) -> Bool
}

///|
/// The token `distance` ahead: chevrotain's `LA`. `la(1)` is the next
/// token and `la(0)` the last one consumed; past either end of the input
/// it is the end-of-input token, named `EOF`.
pub fn Parser::la(self : Parser, distance : Int32) -> Token {
  let index = self.position + distance - 1
  if index < 0 || index >= self.input.length() {
    self.end_of_input
  } else {
    self.input[index]
  }
}

///|
/// Whether the input starts with one of the token sequences.
fn Parser::starts_with(self : Parser, paths : Array[Array[Int32]]) -> Bool {
  for path in paths {
    let mut matches = true
    for index, expected in path {
      if !self.grammar.accepts[expected][self.la(index + 1).kind] {
        matches = false
        break
      }
    }
    if matches {
      return true
    }
  }
  false
}

///|
fn Parser::unexpected(self : Parser, what : String) -> ParseError {
  let token = self.la(1)
  ParseError(message="\{what} but found: '\{token.image}'", offset=token.start)
}

///|
fn Parser::run(
  self : Parser,
  steps : Array[Step],
  node : CstNode,
) -> Unit raise ParseError {
  for step in steps {
    match step {
      Consume(expected, key) => {
        let token = self.la(1)
        guard self.grammar.accepts[expected][token.kind] else {
          raise ParseError(
            message="Expecting token of type --> \{key} <-- but found --> '\{token.image}' <--",
            offset=token.start,
          )
        }
        self.position += 1
        // The end of the input has no place in the tree.
        if token.kind != self.grammar.eof {
          if node.start < 0 {
            node.start = token.start
          }
          match node.children.get(key) {
            Some(elements) => elements.push(Leaf(token))
            None => node.children[key] = [Leaf(token)]
          }
        }
      }
      Call(rule) => {
        let child = self.rule(rule)
        if node.start < 0 {
          node.start = child.start
        }
        match node.children.get(child.name) {
          Some(elements) => elements.push(Node(child))
          None => node.children[child.name] = [Node(child)]
        }
      }
      Maybe(key, paths, body) =>
        if (self.gate)(key, self) && self.starts_with(paths) {
          self.run(body, node)
        }
      Many(key, paths, body) =>
        while (self.gate)(key, self) && self.starts_with(paths) {
          let before = self.position
          self.run(body, node)
          // An iteration that consumes nothing would never end.
          if self.position == before {
            break
          }
        }
      AtLeastOne(key, paths, body) => {
        guard (self.gate)(key, self) && self.starts_with(paths) else {
          raise self.unexpected(
            "Expecting: expecting at least one iteration which starts with one of these possible Token sequences",
          )
        }
        self.run(body, node)
        while (self.gate)(key, self) && self.starts_with(paths) {
          let before = self.position
          self.run(body, node)
          if self.position == before {
            break
          }
        }
      }
      Choose(alternatives) => {
        let mut chosen : Array[Step]? = None
        for alternative in alternatives {
          let (key, paths, body) = alternative
          if (self.gate)(key, self) && self.starts_with(paths) {
            chosen = Some(body)
            break
          }
        }
        guard chosen is Some(body) else {
          raise self.unexpected(
            "Expecting: one of these possible Token sequences",
          )
        }
        self.run(body, node)
      }
    }
  }
}

///|
fn Parser::rule(self : Parser, index : Int32) -> CstNode raise ParseError {
  let node : CstNode = {
    name: self.grammar.rule_names[index],
    children: Map([]),
    start: -1,
  }
  self.run(self.grammar.rules[index], node)
  node
}

///|
/// Parse tokens with the grammar's first rule into a syntax tree. The
/// parser does not recover: the first token that does not fit is an
/// error, as is input left over once the rule is done.
///
/// `gate` stands for the predicates (`GATE`) of the grammar. It is asked
/// before a choice is made, with `<rule>:<Option|Repetition|
/// RepetitionMandatory><occurrence>` for something optional or repeated
/// and `<rule>:Alternation<occurrence>:<alternative>` for an alternative
/// of an `OR`, counting from zero.
pub fn Grammar::parse(
  self : Grammar,
  tokens : Array[Token],
  gate~ : (String, Parser) -> Bool = (_, _) => true,
) -> CstNode raise ParseError {
  let end = match tokens.last() {
    Some(token) => token.end
    None => 0
  }
  let parser : Parser = {
    grammar: self,
    input: tokens,
    position: 0,
    end_of_input: {
      name: EOF_NAME,
      image: "",
      start: end,
      end,
      kind: self.eof,
    },
    gate,
  }
  let tree = parser.rule(0)
  if parser.position < tokens.length() {
    let token = parser.la(1)
    raise ParseError(
      message="Redundant input, expecting EOF but found: \{token.image}",
      offset=token.start,
    )
  }
  tree
}

///|
/// Whether `token` satisfies a request for the token type named
/// `expected`: chevrotain's `tokenMatcher`.
pub fn Grammar::accepts(
  self : Grammar,
  expected : String,
  token : Token,
) -> Bool {
  match self.token_index.get(expected) {
    Some(index) => self.accepts[index][token.kind]
    None => false
  }
}
