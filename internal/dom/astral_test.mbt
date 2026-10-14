///|
test "innerHTML keeps characters outside the basic plane" {
  let element = @dom.Element::new("p")
  element.set_inner_html("😀 <b>𝒳</b> a")
  inspect(element.to_html(), content="<p>😀 <b>𝒳</b> a</p>")
}
