// The body of a `json` declaration: mermaid's `usecaseJson.ts`, which
// parses it with `JSON.parse` and walks it once more for the order the
// properties are written in.

///|
/// A JSON value. An object lists its properties where each first
/// appears, with the value given last.
priv enum JsonValue {
  Null
  Flag(Bool)
  Number(Double)
  Text(String)
  List(Array[JsonValue])
  Object(Array[(String, JsonValue)])
}

///|
priv struct JsonReader {
  text : String
  mut offset : Int32
}

///|
fn JsonReader::fail(self : JsonReader) -> UsecaseError {
  Invalid("Invalid JSON: unexpected token at position \{self.offset}")
}

///|
fn JsonReader::peek(self : JsonReader) -> Int32 {
  code_at(self.text, self.offset)
}

///|
fn JsonReader::skip_whitespace(self : JsonReader) -> Unit {
  while self.peek() is (' ' | '\t' | '\n' | '\r') {
    self.offset += 1
  }
}

///|
fn JsonReader::value(self : JsonReader) -> JsonValue raise UsecaseError {
  self.skip_whitespace()
  match self.peek() {
    '{' => self.object()
    '[' => self.list()
    '"' => Text(self.string())
    't' => {
      self.literal("true")
      Flag(true)
    }
    'f' => {
      self.literal("false")
      Flag(false)
    }
    'n' => {
      self.literal("null")
      Null
    }
    '-' | '0'..<='9' => self.number()
    _ => raise self.fail()
  }
}

///|
fn JsonReader::object(self : JsonReader) -> JsonValue raise UsecaseError {
  self.offset += 1
  let properties : Array[(String, JsonValue)] = []
  self.skip_whitespace()
  if self.peek() == '}' {
    self.offset += 1
    return Object(properties)
  }
  while self.offset < self.text.length() {
    guard self.peek() == '"' else { raise self.fail() }
    let key = self.string()
    self.skip_whitespace()
    guard self.peek() == ':' else { raise self.fail() }
    self.offset += 1
    let value = self.value()
    // A property written again keeps its place and takes the new value.
    match properties.search_by(property => property.0 == key) {
      Some(index) => properties[index] = (key, value)
      None => properties.push((key, value))
    }
    self.skip_whitespace()
    if self.peek() == '}' {
      self.offset += 1
      return Object(properties)
    }
    guard self.peek() == ',' else { raise self.fail() }
    self.offset += 1
    self.skip_whitespace()
  }
  raise self.fail()
}

///|
fn JsonReader::list(self : JsonReader) -> JsonValue raise UsecaseError {
  self.offset += 1
  let items = []
  self.skip_whitespace()
  if self.peek() == ']' {
    self.offset += 1
    return List(items)
  }
  while self.offset < self.text.length() {
    items.push(self.value())
    self.skip_whitespace()
    if self.peek() == ']' {
      self.offset += 1
      return List(items)
    }
    guard self.peek() == ',' else { raise self.fail() }
    self.offset += 1
    self.skip_whitespace()
  }
  raise self.fail()
}

///|
fn JsonReader::string(self : JsonReader) -> String raise UsecaseError {
  self.offset += 1
  let value = StringBuilder()
  while self.offset < self.text.length() {
    let character = self.text.unsafe_get(self.offset)
    self.offset += 1
    if character == '"' {
      return value.to_string()
    }
    if character.to_int() < 32 {
      self.offset -= 1
      raise self.fail()
    }
    if character != '\\' {
      value.write_string(self.text[self.offset - 1:self.offset].to_owned())
      continue
    }
    let escape = self.peek()
    self.offset += 1
    match escape {
      '"' => value.write_char('"')
      '\\' => value.write_char('\\')
      '/' => value.write_char('/')
      'b' => value.write_char('\u{08}')
      'f' => value.write_char('\u{0c}')
      'n' => value.write_char('\n')
      'r' => value.write_char('\r')
      't' => value.write_char('\t')
      'u' => {
        let mut unit = 0
        for index in 0..<4 {
          let digit = match code_at(self.text, self.offset + index) {
            '0'..<='9' as c => c - '0'
            'a'..<='f' as c => c - 'a' + 10
            'A'..<='F' as c => c - 'A' + 10
            _ => raise self.fail()
          }
          unit = unit * 16 + digit
        }
        // One UTF-16 code unit, which may be half of a pair.
        value.write_string(String::from_array([unit.unsafe_to_char()]))
        self.offset += 4
      }
      _ => {
        self.offset -= 1
        raise self.fail()
      }
    }
  }
  raise self.fail()
}

///|
fn JsonReader::literal(
  self : JsonReader,
  literal : String,
) -> Unit raise UsecaseError {
  guard spelled_at(self.text, self.offset, literal) else { raise self.fail() }
  self.offset += literal.length()
}

///|
fn JsonReader::number(self : JsonReader) -> JsonValue raise UsecaseError {
  let start = self.offset
  let digits = () => {
    while self.peek() is ('0'..<='9') {
      self.offset += 1
    }
  }
  if self.peek() == '-' {
    self.offset += 1
  }
  match self.peek() {
    '0' => self.offset += 1
    '1'..<='9' => digits()
    _ => raise self.fail()
  }
  if self.peek() == '.' {
    self.offset += 1
    guard self.peek() is ('0'..<='9') else { raise self.fail() }
    digits()
  }
  if self.peek() is ('e' | 'E') {
    self.offset += 1
    if self.peek() is ('+' | '-') {
      self.offset += 1
    }
    guard self.peek() is ('0'..<='9') else { raise self.fail() }
    digits()
  }
  let spelled = self.text[start:self.offset].to_owned()
  let value = @string.parse_double(spelled) catch { _ => raise self.fail() }
  Number(value)
}

///|
/// Parse the text of a JSON object: `parseOrderedJsonObject`.
fn parse_json_object(text : String) -> JsonValue raise UsecaseError {
  let reader : JsonReader = { text, offset: 0, }
  let value = reader.value()
  reader.skip_whitespace()
  guard reader.offset == text.length() else { raise reader.fail() }
  guard value is Object(_) else {
    raise Invalid("JSON value must have an object root")
  }
  value
}

///|
/// A row of a JSON table: the path of a leaf, as shown and as read out,
/// and its value.
priv struct JsonRow {
  key : String
  accessible_key : String
  value : String
}

///|
/// How a leaf is shown: strings bare, the rest as JSON spells it.
fn display_scalar(value : JsonValue) -> String {
  match value {
    Text(text) => text
    Null => "null"
    Flag(flag) => flag.to_string()
    Number(number) => js_number(number)
    _ => ""
  }
}

///|
/// JavaScript's `String(number)`.
fn js_number(number : Double) -> String {
  if number.is_nan() {
    "NaN"
  } else if number.is_inf() {
    if number > 0.0 {
      "Infinity"
    } else {
      "-Infinity"
    }
  } else {
    @dom.number(number)
  }
}

///|
/// The rows of a JSON table, one per leaf: `flattenJsonRows`. An array of
/// scalars takes one row per item under a key shown once.
fn flatten_json_rows(value : JsonValue) -> Array[JsonRow] {
  let rows : Array[JsonRow] = []
  fn visit(current : JsonValue, path : String) {
    match current {
      List(items) => {
        if items.is_empty() {
          rows.push({ key: path, accessible_key: path, value: "[]", })
          return
        }
        if items.all(item => !(item is (List(_) | Object(_)))) {
          for index, item in items {
            rows.push({
              key: if index == 0 {
                path
              } else {
                ""
              },
              accessible_key: path,
              value: display_scalar(item),
            })
          }
          return
        }
        for index, item in items {
          visit(item, "\{path}[\{index}]")
        }
      }
      Object(properties) => {
        if properties.is_empty() {
          rows.push({ key: path, accessible_key: path, value: "{}", })
          return
        }
        for property in properties {
          let (key, child) = property
          visit(child, if path != "" { "\{path}.\{key}" } else { key })
        }
      }
      scalar =>
        rows.push({
          key: path,
          accessible_key: path,
          value: display_scalar(scalar),
        })
    }
  }

  visit(value, "")
  rows
}
