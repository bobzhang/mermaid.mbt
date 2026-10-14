///|
/// The boxes of a model: swimlane index, label, position and size.
fn boxes(source : String, relations_only~ : Bool = false) -> Json {
  let model = parse(source) catch { _ => return Json::string("parse error") }
  let theme = @theme.Theme::from_variables(Map([]))
  let state = layout(model, theme) catch {
    Invalid(message) => return Json::string("invalid: " + message)
    Unsupported(message) => return Json::string("unsupported: " + message)
    _ => return Json::string("error")
  }
  let out : Array[Json] = []
  for box in state.boxes {
    if relations_only {
      break
    }
    out.push(
      Json::string(
        "\{box.swimlane.index} \{box.swimlane.label}: x \{box.x} y \{box.swimlane.y} \{box.width}x\{box.height}",
      ),
    )
  }
  for relation in state.relations {
    out.push(
      Json::string("\{relation.0.frame.name} -> \{relation.1.frame.name}"),
    )
  }
  Json::array(out)
}

///|
test "swimlanes: one per kind, one more for every frame with a namespace" {
  json_inspect(
    boxes(
      "eventmodeling\ntf 1 ui A\ntf 2 cmd B\ntf 3 evt X.C\ntf 4 evt X.D\ntf 5 evt E\n",
    ),
    content=[
      "0 UI/Automation: x 250 y 0 112x100", "100 Command/Read Model: x 292 y 140 112x100",
      "201 Stream: X: x 334 y 420 112x100", "202 Stream: X: x 376 y 560 113x100",
      "200 Events: x 419 y 280 111x100", "1 -> 2", "2 -> 3", "3 -> 4", "4 -> 5",
    ],
  )
}

///|
test "relations: from the nearest box of another swimlane, or as told" {
  json_inspect(
    boxes(
      "eventmodeling\ntf 1 ui A\ntf 2 ui B\ntf 3 cmd C\nrf 4 evt D\ntf 5 evt E ->> 1 ->> 9 ->> 6\ntf 6 ui F\n",
      relations_only=true,
    ),
    content=["2 -> 3", "1 -> 5", "5 -> 6"],
  )
}

///|
test "names: wider than a box they are cut and hyphenated" {
  inspect(wrap_label("Short", TEXT_MAX_WIDTH), content="Short")
  inspect(
    wrap_label("W".repeat(40), TEXT_MAX_WIDTH),
    content=(
      #|WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW-<br/>WWWWWWWWW
    ),
  )
  inspect(wrap_label("a  b   c", TEXT_MAX_WIDTH), content="a b c")
  inspect(wrap_label("kept <br> as it is", 10.0), content="kept <br> as it is")
}

///|
test "data: between the braces, less the character before the closing one" {
  inspect(data_html("{ a: 1 }", "{"), content="a:&nbsp;1")
  inspect(data_html("{a}", "{"), content="")
  inspect(data_html("\"quoted\"", "{"), content="")
  inspect(
    data_html("{\n  a: 1\n  b: 2\n}\n", "{\n"),
    content="a:&nbsp;1\n&nbsp;b:&nbsp;2",
  )
}

///|
test "a word of nothing but line breaks cannot be measured" {
  json_inspect(
    boxes("eventmodeling\ntf 1 ui A [[D]]\ndata D {\n  a \n  b\n}\n"),
    content="invalid: svg element not in render tree",
  )
  // Nor can the line break a blank after the opening brace leaves.
  json_inspect(
    boxes("eventmodeling\ntf 1 ui A [[D]]\ndata D { \n  a\n}\n"),
    content="invalid: svg element not in render tree",
  )
}
