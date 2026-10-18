///|
test "flowcharts the port refuses rather than draw differently" {
  // Label styles that change how the text lays out, and so the size of
  // the node upstream measures with them.
  inspect(
    refusal("flowchart TD\nA((AA))\nstyle A letter-spacing:10px\n"),
    content="Unsupported: the label style `letter-spacing:10px` changes the label's size, which is not ported",
  )
  inspect(
    refusal("flowchart TD\nA((AA))\nstyle A font-size:2em\n"),
    content="Unsupported: the label style `font-size:2em` changes the label's size, which is not ported",
  )
  inspect(
    refusal("flowchart TD\nclassDef c text-transform:uppercase\nA:::c --> B\n"),
    content="Unsupported: the label style `text-transform:uppercase` changes the label's size, which is not ported",
  )
  inspect(
    refusal("flowchart TD\nA -->|x| B\nlinkStyle 0 word-spacing:4px\n"),
    content="Unsupported: the label style `word-spacing:4px` changes the label's size, which is not ported",
  )
}

///|
test "image sizes that are not numbers" {
  // `Number("abc")` is `NaN`, which upstream's geometry carries on.
  inspect(
    refusal("flowchart TD\nA@{ icon: \"fa:fa-car\", w: \"abc\" }\n"),
    content="Unsupported: the image or icon size of A is not a number, which is not ported",
  )
}

///|
test "links the browser's URL parser would rewrite in ways not ported" {
  inspect(
    refusal("flowchart TD\nA\nclick A \"https://user@x.com/\"\n"),
    content="Unsupported: Unsupported link address: https://user@x.com/",
  )
}
