///|
test "the ticket is put into the first placeholder of the address" {
  inspect(
    js_replace_first("https://x/#TICKET#/#TICKET#", "#TICKET#", "MC-1"),
    content="https://x/MC-1/#TICKET#",
  )
  // The `$` patterns of a replacement that need no capture.
  inspect(
    js_replace_first("a#T#b", "#T#", "[$$|$&|$`|$'|$1]"),
    content="a[$|#T#|a|b|$1]b",
  )
  inspect(js_replace_first("none", "#T#", "x"), content="none")
}
