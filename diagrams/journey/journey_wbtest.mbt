///|
test "legend order follows JavaScript's object keys" {
  let conf = Conf::new(@config.Config::new())
  let order = legend_order(["007", "10", "2", "4294967295", "Bob", "bob"], conf)
  // Array indices first, by value; the rest as sorted. The position — and
  // with it the colour — is the one in the sorted list.
  json_inspect(order.map(actor => "\{actor.name}@\{actor.position}"), content=[
    "2@2", "10@1", "007@0", "4294967295@3", "Bob@4", "bob@5",
  ])
  inspect(order[0].colour.unwrap_or(""), content="#00FFFF")
}

///|
test "legend lines break at blanks, and inside a word too long alone" {
  let conf = Conf::new(@config.Config::new())
  // Ten pixels a character.
  let measure = (text : String) => text.length().to_double() * 10.0
  json_inspect(legend_lines("short name", conf, measure), content=["short name"])
  let words = "aaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbb cccccccccc"
  json_inspect(legend_lines(words, conf, measure), content=[
    "aaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbb cccccccccc",
  ])
  let long = "x".repeat(80)
  json_inspect(legend_lines(long, conf, measure).map(line => line.length()), content=[
    36, 36, 10,
  ])
}

///|
test "font declarations as the CSSOM serializes them" {
  inspect(
    css_font_family("'Open Sans',  SANS-SERIF,Times New Roman"),
    content="\"Open Sans\", sans-serif, \"Times New Roman\"",
  )
  inspect(css_font_size("16").unwrap_or(""), content="16px")
  inspect(css_font_size("1.50em").unwrap_or(""), content="1.5em")
}
