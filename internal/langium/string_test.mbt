///|
test "a string keeps characters outside the basic plane" {
  inspect(
    @langium.Lexer::new("\"😀 \\\"x\\\" 𝒳\"").string().unwrap_or(""),
    content=(
      #|😀 "x" 𝒳
    ),
  )
}
