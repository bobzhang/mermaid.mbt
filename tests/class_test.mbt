///|
test "class" {
  json_inspect(mismatches("class"), content=[])
}

///|
/// Labels at the ends of edges.
test "class: terminal labels" {
  json_inspect(mismatches("class/terminal-labels"), content=[])
}
