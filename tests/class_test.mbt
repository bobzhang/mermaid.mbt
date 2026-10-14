///|
test "class" {
  json_inspect(mismatches("class"), content=[])
}

///|
/// Labels at the ends of edges. They wait for moon_elk to write edge
/// labels back by origin: see testdata/class/terminal-labels/PENDING.
#skip
test "class: terminal labels" {
  json_inspect(mismatches("class/terminal-labels"), content=[])
}
