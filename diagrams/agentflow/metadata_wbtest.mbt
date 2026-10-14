///|
test "trailing commas go, except inside quotes, collections and block scalars" {
  let body =
    #|
    #|  shape: tool,
    #|  label: "x, y",
    #|  tags: [a,
    #|    b],
    #|  note: |
    #|    keep,
    #|    these,
    #|  retry: 2, # a comment,
    #|
  inspect(
    strip_line_trailing_commas(body),
    content=(
      #|
      #|  shape: tool
      #|  label: "x, y"
      #|  tags: [a,
      #|    b]
      #|  note: |
      #|    keep,
      #|    these,
      #|  retry: 2 # a comment,
      #|
    ),
  )
}

///|
test "prototype keys are dropped at every level" {
  let doc : Json = {
    "constructor": 1,
    "a": { "prototype": 2, "b": [{ "__proto__": 3, "c": 4 }] },
  }
  json_inspect(strip_prototype_keys(doc), content={ "a": { "b": [{ "c": 4 }] } })
}

///|
test "a multi-line block written like an object still reads" {
  // Plain scalars may end with a comma in YAML: only a block that is not
  // YAML as written loses its commas.
  json_inspect(parse_shape_data("\n  shape: tool,\n"), content={
    "shape": "tool,",
  })
  json_inspect(parse_shape_data("\n  label: \"A\",\n  shape: tool,\n"), content={
    "label": "A",
    "shape": "tool",
  })
}
