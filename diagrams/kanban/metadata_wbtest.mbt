///|
/// The text of a scalar as upstream turns it into a ticket or assignee:
/// `String(value)` of what js-yaml's JSON schema makes of it.
fn shown(data : String) -> String raise {
  resolve_scalar(data).js_string()
}

///|
test "plain scalars resolve as under js-yaml's JSON schema" {
  json_inspect(
    [
      shown("007"),
      shown("1.50"),
      shown("1e3"),
      shown("0x1F"),
      shown("0o17"),
      shown("0b101"),
      shown("+12"),
      shown("-0"),
      shown(".5"),
      shown("5."),
      shown(".inf"),
      shown("-.Inf"),
      shown(".NaN"),
      shown("1e21"),
      shown("12345678901234567890"),
      shown("NULL"),
      shown("True"),
      // Not numbers or booleans in this schema.
      shown("yes"),
      shown("1_000"),
      shown("0X1F"),
      shown("inf"),
      shown("1e400"),
    ],
    content=[
      "7", "1.5", "1000", "31", "15", "5", "12", "0", "0.5", "5", "Infinity", "-Infinity",
      "NaN", "1e+21", "12345678901234567000", "null", "true", "yes", "1_000", "0X1F",
      "inf", "1e400",
    ],
  )
}

///|
test "collections as text" {
  let list : Meta = List([Number(1.0), Null, Text("x"), List([Bool(true)])])
  inspect(list.js_string(), content="1,,x,true")
  inspect(Record(Map([])).js_string(), content="[object Object]")
}

///|
test "metadata documents" {
  debug_inspect(
    load_yaml("{\n assigned: knsv, ticket: 'MC-1' \n}"),
    content=(
      #|Some(Record({ "assigned": Text("knsv"), "ticket": Text("MC-1") }))
    ),
  )
  debug_inspect(load_yaml("\n  \n"), content="None")
  debug_inspect(
    load_yaml("{\n a: &x 1, b: *x, c: !!str 2 \n}"),
    content=(
      #|Some(Record({ "a": Number(1), "b": Number(1), "c": Text("2") }))
    ),
  )
}
