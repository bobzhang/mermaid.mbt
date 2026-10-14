///|
/// Values printed by the JavaScript the functions are ported from.
test "the seeded generator and the hash that seeds it" {
  inspect(seeded_random(0.0), content="0.26642920868471265")
  inspect(seeded_random(1.0), content="0.6270739405881613")
  inspect(seeded_random(42.0), content="0.6011037519201636")
  // Seeds are taken modulo 2^32 after dropping their fraction.
  inspect(seeded_random(-5.0), content="0.48384718922898173")
  inspect(seeded_random(2.5), content="0.7342509443406016")
  inspect(seeded_random(1.0e12), content="0.9827820791397244")
  inspect(seeded_random(4294967303.0), content="0.011704753153026104")
  inspect(hash_string("mermaid-svg"), content="-877398752")
  inspect(hash_string(""), content="0")
  inspect(
    hash_string("a much longer identifier than usual"),
    content="-759157993",
  )
}

///|
test "the seed is the configured one unless it is zero" {
  inspect(resolve_seed(Some(42.0), "mermaid-svg"), content="42")
  inspect(resolve_seed(Some(0.0), "mermaid-svg"), content="-877398752")
  inspect(resolve_seed(None, "mermaid-svg"), content="-877398752")
}

///|
test "the cliff and the confusion ellipse" {
  inspect(
    cliff_path(800.0, 600.0),
    content="M400,300 C424,360 364,465 412,525 C376,555 407.2,585 400,600",
  )
  inspect(
    confusion_path(400.0, 300.0, 120.0, 90.0),
    content="M280,300 A120,90 0 1,1 520,300 A120,90 0 1,1 280,300 Z",
  )
}

///|
test "theme values in template arithmetic" {
  // A number is a number; text makes `- 1` numeric but `+ 2` a
  // concatenation.
  inspect(js_minus_one(Json::number(12.0)), content="11")
  inspect(js_plus_two(Json::number(16.0)), content="18")
  inspect(js_minus_one(Json::string("12")), content="11")
  inspect(js_plus_two(Json::string("16")), content="162")
  inspect(js_minus_one(Json::string("big")), content="NaN")
}

///|
/// The domains with their items, then the transitions.
fn outline(source : String) -> String raise {
  let diagram = parse(source)
  let out = StringBuilder()
  for name, items in diagram.domains {
    out.write_string("\{name}: \{items.join(" | ")}\n")
  }
  for transition in diagram.transitions {
    out.write_string(
      "\{transition.from} -> \{transition.to} \{transition.label.unwrap_or("-")}\n",
    )
  }
  out.to_string()
}

///|
test "domain blocks and transitions" {
  let source =
    #|cynefin-beta:
    #|  title A   title
    #|  complex "on the same line"
    #|    "next \"line\""
    #|
    #|  clear
    #|  complex --> clear : "codified"
    #|  clear --> clear : "dropped"
    #|  chaotic --> complex : ""
    #|  complex
    #|    "replaces the first block"
    #|
  inspect(
    outline(source),
    content=(
      #|complex: replaces the first block
      #|clear: 
      #|complex -> clear codified
      #|chaotic -> complex -
      #|
    ),
  )
  inspect(parse(source).title, content="A title")
}

///|
test "what the lexer and the grammar refuse" {
  let rejected = (source : String) => {
    try parse(source) catch {
      _ => true
    } noraise {
      _ => false
    }
  }
  // Domain names are a terminal without a word boundary: what follows
  // one must be a token too.
  inspect(rejected("cynefin-beta\n  complexity\n"), content="true")
  inspect(rejected("cynefin-beta\n  Complex\n"), content="true")
  inspect(rejected("cynefin-beta :\n  complex\n"), content="true")
  inspect(rejected("cynefin-beta\n  complex --> clear \"x\"\n"), content="true")
  inspect(rejected("cynefin-beta\n  complex -->\n  clear\n"), content="true")
  inspect(rejected("cynefin-beta\n  title T\n  complex\n"), content="false")
  // A title takes the rest of its line.
  inspect(outline("cynefin-beta\n  title T complex\n"), content="")
}
