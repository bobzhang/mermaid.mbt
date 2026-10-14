///|
/// The frames of a model, one string each, or why it does not parse.
fn dump(source : String) -> Json {
  let model = @eventmodeling.parse(source) catch {
    @langium.ParseError(message~, ..) =>
      return Json::string("syntax: " + message)
    @eventmodeling.Invalid(message) =>
      return Json::string("invalid: " + message)
    _ => return Json::string("error")
  }
  let frames : Array[Json] = []
  for frame in model.frames {
    let out = StringBuilder()
    out.write_string(if frame.reset { "rf " } else { "tf " })
    out.write_string(frame.name)
    out.write_string(
      match frame.entity_type {
        Ui => " ui "
        Processor => " pcr "
        ReadModel => " rmo "
        Command => " cmd "
        Event => " evt "
      },
    )
    out.write_string(frame.entity_identifier)
    for source in frame.source_frames {
      out.write_string(" <- \{source}")
    }
    if frame.data_reference is Some(reference) {
      out.write_string(" [[\{reference}]]")
    }
    if frame.data_inline is Some(data) {
      out.write_string(" \{data}")
    }
    frames.push(Json::string(out.to_string()))
  }
  for entity in model.data_entities {
    frames.push(Json::string("data \{entity.0} \{entity.1}"))
  }
  Json::array(frames)
}

///|
test "frames in both notations" {
  json_inspect(
    dump(
      "eventmodeling\ntf 01 ui CartUI\ntimeframe 02 command Cart . AddItem ->> 01 ->> 7 [[Data]] `json`{ a: 1 }\nresetframe 3 readmodel Items \"quoted\"\nrf 004 pcr P\n",
    ),
    content=[
      "tf 01 ui CartUI", "tf 02 cmd Cart.AddItem <- 01 <- 7 [[Data]] { a: 1 }", "rf 3 rmo Items \"quoted\"",
      "rf 004 pcr P",
    ],
  )
}

///|
test "data: one line is inline data, several are a block" {
  json_inspect(
    dump(
      "eventmodeling\ntf 1 ui A { a } { b }\ndata D {\n  x: {\n    y\n  }\n}\ntf 2 cmd B\n",
    ),
    content=[
      "tf 1 ui A { a } { b }", "tf 2 cmd B", "data D {\n  x: {\n    y\n  }\n}\n",
    ],
  )
  json_inspect(
    dump("eventmodeling\ntf 1 ui A\ndata D { x }\n"),
    content="syntax: Expecting token of type 'DATA_BLOCK' but found '{ x }'",
  )
}

///|
test "keywords are no names, unless they go on" {
  json_inspect(dump("eventmodeling\ntf 1 ui texts\ntf 2 evt tfx\n"), content=[
    "tf 1 ui texts", "tf 2 evt tfx",
  ])
  json_inspect(
    dump("eventmodeling\ntf 1 ui text\n"),
    content="syntax: Expecting token of type 'ID' but found 'text'",
  )
}

///|
test "a title is only one behind another token of its line" {
  json_inspect(dump("eventmodeling title The title\ntf 1 ui A accTitle: T\n"), content=[
    "tf 1 ui A",
  ])
  // At the start of a line `title` is an identifier.
  json_inspect(
    dump("eventmodeling\ntitle The title\ntf 1 ui A\n"),
    content="syntax: Expecting a frame, data, a note or an entity but found 'title'",
  )
}

///|
test "what is parsed and not drawn" {
  json_inspect(
    dump(
      "eventmodeling\nentity Shop.Cart\nnote 1 `md`{\n# hi\n}\ngwt 1 given evt X cmd Y when cmd Z then evt W\ntf 1 ui A\n",
    ),
    content=["tf 1 ui A"],
  )
}

///|
test "a frame number may be used once" {
  json_inspect(
    dump("eventmodeling\ntf 01 ui A\nrf 01 cmd B\n"),
    content="invalid: Duplicate event modeling frame ID \"01\"",
  )
  json_inspect(dump("eventmodeling\ntf 01 ui A\nrf 1 cmd B\n"), content=[
    "tf 01 ui A", "rf 1 cmd B",
  ])
}
