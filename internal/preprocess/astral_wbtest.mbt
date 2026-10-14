///|
test "characters outside the basic plane survive the cleanup" {
  inspect(
    cleanup_text("pie\n \"😀 a\": 1\n<b class=\"x😀\">y</b>"),
    content=(
      #|pie
      #| "😀 a": 1
      #|<b class='x😀'>y</b>
    ),
  )
}
