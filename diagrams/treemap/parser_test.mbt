///|
/// The tree as JSON: a section is `[name, children]`, a leaf
/// `[name, value]`, each with its class when it has one.
fn tree(nodes : Array[@treemap.Node]) -> Json {
  let out : Array[Json] = []
  for node in nodes {
    let item : Array[Json] = [Json::string(node.name)]
    match node.children {
      Some(children) => item.push(tree(children))
      None => {
        let value = node.value.unwrap_or(0.0)
        item.push(if value.is_nan() { "NaN" } else { Json::number(value) })
      }
    }
    if node.class_selector is Some(selector) {
      item.push(Json::string(":::" + selector))
    }
    out.push(Json::array(item))
  }
  Json::array(out)
}

///|
fn dump(source : String) -> Json {
  let treemap = @treemap.parse(source) catch {
    @langium.ParseError(message~, ..) =>
      return Json::string("syntax: " + message)
    _ => return Json::string("error")
  }
  tree(treemap.outer_nodes)
}

///|
test "indentation makes the tree, whatever its width" {
  json_inspect(
    dump(
      "treemap-beta\n\"A\"\n        \"B\"\n            \"C\": 3\n    \"D\", 4\n  \"E\" :5\n\"F\": 6:::cls\n",
    ),
    content=[["A", [["B", [["C", 3]]], ["D", 4], ["E", 5]]], ["F", 6, ":::cls"]],
  )
}

///|
test "numbers: commas group digits, anything else ends the number" {
  json_inspect(
    dump(
      "treemap\n\"a\": 1,000.5\n\"b\": 1_000\n\"c\": .\n\"d\": 5,\n\"e\": 1.2.3\n",
    ),
    content=[["a", 1000.5], ["b", 1], ["c", "NaN"], ["d", 5], ["e", 1.2]],
  )
}

///|
test "white space is a token: it may not trail a section" {
  // The space after "A" could only start another row.
  json_inspect(
    dump("treemap\n\"A\"  \n    \"B\": 3\n"),
    content="syntax: Expecting an item or a class definition but found '    '",
  )
  json_inspect(
    dump("treemap\n\"A\": 5 :::c\n"),
    content="syntax: Expecting an item or a class definition but found ':::'",
  )
  // On one line every item is indented by the space before it.
  json_inspect(dump("treemap \"A\" \"B\": 3\n"), content=[["A", []], ["B", 3]])
}

///|
test "a class definition without styles takes the next line for them" {
  let treemap = @treemap.parse(
    "treemap\nclassDef one fill:red,color:blue;\nclassDef two\n\"A\": 1:::two\n",
  )
  json_inspect(treemap.classes["one"].styles, content=["fill:red", "color:blue"])
  json_inspect(treemap.classes["two"].styles, content=["\"A\": 1:::two"])
  inspect(treemap.outer_nodes.length(), content="0")
}

///|
test "the last title counts, even an empty one" {
  inspect(
    @treemap.parse("treemap\ntitle One\ntitle  Two   words\n").title,
    content="Two words",
  )
  inspect(@treemap.parse("treemap\ntitle One\ntitle\n").title, content="")
}
