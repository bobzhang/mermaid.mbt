// The `@{ ... }` block after a node: YAML, read the way js-yaml does
// under its JSON schema.

///|
/// A value of a metadata block.
priv enum Meta {
  Null
  Bool(Bool)
  Number(Double)
  Text(String)
  List(Array[Meta])
  Record(Map[String, Meta])
} derive(Eq, Debug)

///|
/// JavaScript's truthiness.
fn Meta::truthy(self : Meta) -> Bool {
  match self {
    Null => false
    Bool(value) => value
    Number(value) => value != 0.0 && !value.is_nan()
    Text(text) => text != ""
    List(_) | Record(_) => true
  }
}

///|
/// JavaScript's `String(value)`.
fn Meta::js_string(self : Meta) -> String {
  match self {
    Null => "null"
    Bool(value) => if value { "true" } else { "false" }
    Number(value) =>
      if value.is_nan() {
        "NaN"
      } else if value.is_inf() {
        if value > 0.0 {
          "Infinity"
        } else {
          "-Infinity"
        }
      } else {
        @dom.number(value)
      }
    Text(text) => text
    // `Array.prototype.join`, in which `null` is nothing.
    List(items) =>
      items
      .map(item => {
        match item {
          Null => ""
          item => item.js_string()
        }
      })
      .join(",")
    Record(_) => "[object Object]"
  }
}

///|
/// The digits of an integer in `radix`, as `parseInt` reads them.
fn parse_digits(digits : StringView, radix : Double) -> Double? {
  // Decimal digits are rounded once, however many there are.
  if radix == 10.0 {
    return Some(@string.parse_double(digits.to_owned() + ".0")) catch {
      _ => None
    }
  }
  let mut value = 0.0
  for c in digits {
    let digit = match c {
      '0'..<='9' => c.to_int() - '0'
      'a'..<='f' => c.to_int() - 'a' + 10
      'A'..<='F' => c.to_int() - 'A' + 10
      _ => return None
    }
    value = value * radix + digit.to_double()
    // Past this every step would round, and not as one rounding does.
    guard value < 9007199254740992.0 else { return None }
  }
  Some(value)
}

///|
/// js-yaml's `resolveYamlInteger` and `constructYamlInteger`: the integer
/// a plain scalar stands for. `Err` is an integer the port cannot read
/// exactly.
fn yaml_integer(data : String) -> Result[Double?, Unit] {
  let chars = data.to_array()
  let max = chars.length()
  guard max > 0 else { return Ok(None) }
  let mut index = 0
  let negative = chars[0] == '-'
  if chars[0] is ('-' | '+') {
    index = 1
  }
  guard index < max else { return Ok(None) }
  let digits_from = (start : Int32, accepts : (Char) -> Bool) => {
    start < max && chars[start:].iter().all(accepts)
  }
  let (start, radix) = if chars[index] == '0' {
    if index + 1 == max {
      return Ok(Some(0.0))
    }
    match chars[index + 1] {
      'b' => {
        guard digits_from(index + 2, c => c is ('0' | '1')) else {
          return Ok(None)
        }
        (index + 2, 2.0)
      }
      'x' => {
        guard digits_from(index + 2, c => {
          c is ('0'..<='9' | 'a'..<='f' | 'A'..<='F')
        }) else {
          return Ok(None)
        }
        (index + 2, 16.0)
      }
      'o' => {
        guard digits_from(index + 2, c => c is ('0'..<='7')) else {
          return Ok(None)
        }
        (index + 2, 8.0)
      }
      _ => (index, 10.0)
    }
  } else {
    (index, 10.0)
  }
  if radix == 10.0 {
    guard digits_from(start, c => c is ('0'..<='9')) else { return Ok(None) }
  }
  let digits = String::from_array(chars[start:])
  match parse_digits(digits, radix) {
    // An integer too large to be finite is no integer.
    Some(value) if value.is_inf() => Ok(None)
    Some(value) => Ok(Some(if negative { -value } else { value }))
    None => Err(())
  }
}

///|
/// js-yaml's float pattern without the special values: digits with an
/// optional fraction and exponent, or a fraction alone.
let yaml_float_pattern : @jsregex.Regex = try! @jsregex.Regex::compile(
  "^(?:[-+]?(?:[0-9]+)(?:\\.[0-9]*)?(?:[eE][-+]?[0-9]+)?|\\.[0-9]+(?:[eE][-+]?[0-9]+)?)$",
)

///|
/// js-yaml's `resolveYamlFloat` and `constructYamlFloat`.
fn yaml_float(data : String) -> Double? {
  match data {
    ".inf" | ".Inf" | ".INF" | "+.inf" | "+.Inf" | "+.INF" =>
      return Some(@double.infinity)
    "-.inf" | "-.Inf" | "-.INF" => return Some(@double.neg_infinity)
    ".nan" | ".NaN" | ".NAN" => return Some(@double.not_a_number)
    _ => ()
  }
  guard yaml_float_pattern.matches(data) else { return None }
  // `parseFloat` of the text without its sign: a number may start or end
  // at its point.
  let (negative, text) = match data {
    ['-', .. rest] => (true, rest.to_owned())
    ['+', .. rest] => (false, rest.to_owned())
    _ => (false, data)
  }
  let text = if text.has_prefix(".") { "0" + text } else { text }
  let text = match text.find(".") {
    Some(point) =>
      if point + 1 == text.length() || text[point + 1] is ('e' | 'E') {
        text[:point + 1].to_owned() + "0" + text[point + 1:].to_owned()
      } else {
        text
      }
    None => text
  }
  let value = @string.parse_double(text) catch { _ => return None }
  // A number too large to be finite is no number.
  guard !value.is_inf() else { return None }
  Some(if negative { -value } else { value })
}

///|
/// What a plain scalar stands for under js-yaml's JSON schema: null, a
/// boolean, an integer, a float, or else its text.
fn resolve_scalar(data : String) -> Meta raise KanbanError {
  match data {
    "" | "~" | "null" | "Null" | "NULL" => return Null
    "true" | "True" | "TRUE" => return Bool(true)
    "false" | "False" | "FALSE" => return Bool(false)
    _ => ()
  }
  match yaml_integer(data) {
    Ok(Some(value)) => return Number(value)
    Ok(None) => ()
    Err(_) => raise Unsupported("an integer this large in metadata: \{data}")
  }
  match yaml_float(data) {
    Some(value) => Number(value)
    None => Text(data)
  }
}

///|
/// Builds the documents of a YAML stream from the parser's events.
priv struct Loader {
  /// What was loaded: one entry per document, `None` for an empty one.
  docs : Array[Meta?]
  /// The collections being filled, innermost last, with their anchors.
  stack : Array[(Meta, Int32)]
  /// For every mapping being filled, the key waiting for its value.
  keys : Array[String?]
  anchors : Map[Int32, Meta]
  mut error : KanbanError?
}

///|
impl @yaml.MarkedEventReceiver for Loader with fn on_event(self, event, _) {
  guard self.error is None else { return }
  self.receive(event) catch {
    error => self.error = Some(error)
  }
}

///|
fn Loader::receive(
  self : Loader,
  event : @yaml.Event,
) -> Unit raise KanbanError {
  // What the port does not resolve the way js-yaml does is refused.
  let untagged = (tag : @yaml.Tag?) => {
    if tag is Some(_) {
      raise Unsupported("tags in metadata")
    }
  }
  match event {
    StreamStart | StreamEnd => ()
    DocumentStart => ()
    DocumentEnd =>
      match self.stack.pop() {
        Some((node, _)) => self.docs.push(Some(node))
        None => self.docs.push(None)
      }
    SequenceStart(id~, tag~) => {
      untagged(tag)
      self.stack.push((List([]), id))
    }
    MappingStart(id~, tag~) => {
      untagged(tag)
      self.stack.push((Record(Map([])), id))
      self.keys.push(None)
    }
    SequenceEnd => if self.stack.pop() is Some(node) { self.insert(node) }
    MappingEnd => {
      self.keys.pop() |> ignore
      if self.stack.pop() is Some(node) {
        self.insert(node)
      }
    }
    Scalar(value~, style~, id~, tag~) => {
      untagged(tag)
      let node = match style {
        Plain => resolve_scalar(value)
        _ => Text(value)
      }
      self.insert((node, id))
    }
    Alias(id~) =>
      match self.anchors.get(id) {
        Some(node) => self.insert((node, 0))
        None => raise Invalid("unidentified alias in metadata")
      }
  }
}

///|
/// Put a finished node where it belongs: in the collection being filled,
/// or at the root of its document.
fn Loader::insert(
  self : Loader,
  node : (Meta, Int32),
) -> Unit raise KanbanError {
  if node.1 > 0 {
    self.anchors[node.1] = node.0
  }
  match self.stack.last() {
    None => self.stack.push(node)
    Some((List(items), _)) => items.push(node.0)
    Some((Record(fields), _)) => {
      let slot = self.keys.length() - 1
      match self.keys[slot] {
        None =>
          // A key is the text of its node.
          self.keys[slot] = match node.0 {
            List(_) | Record(_) =>
              raise Unsupported("a collection as a key in metadata")
            key => Some(key.js_string())
          }
        Some(key) => {
          self.keys[slot] = None
          if fields.contains(key) {
            raise Invalid("duplicated mapping key in metadata: \{key}")
          }
          fields[key] = node.0
        }
      }
    }
    Some(_) => ()
  }
}

///|
/// `yaml.load(source, { schema: JSON_SCHEMA })`: the single document of
/// `source`, `None` when there is none (js-yaml's `undefined`).
fn load_yaml(source : String) -> Meta? raise KanbanError {
  let loader : Loader = {
    docs: [],
    stack: [],
    keys: [],
    anchors: Map([]),
    error: None,
  }
  let parser = @yaml.Parser::new(source)
  parser.load(loader, true) catch {
    @yaml.YamlError(info~, ..) => raise Invalid("bad metadata: \{info}")
  }
  if loader.error is Some(error) {
    raise error
  }
  match loader.docs {
    [] => None
    [doc] => doc
    _ =>
      raise Invalid("expected a single document in the stream, but found more")
  }
}
