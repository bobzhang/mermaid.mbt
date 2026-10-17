///|
test "nodes go on a grid by the sides of their edges" {
  let db = parse(
    (
      #|architecture-beta
      #|    group api(cloud)[API]
      #|    service db(database)[Database] in api
      #|    service disk1(disk)[Storage] in api
      #|    service server(server)[Server] in api
      #|    db:L -- R:server
      #|    disk1:T -- B:server
    ),
  )
  let { spatial_maps, .. } = db.data_structures()
  let grid = spatial_maps.map(map => {
    map.ids
    .map(id => {
      let (x, y) = map.positions[id]
      "\{id} \{x},\{y}"
    })
    .join("; ")
  })
  inspect(grid.join(" | "), content="db 0,0; server -1,0; disk1 -1,-1")
}

///|
test "identifiers cannot start with a side" {
  let failed = try {
    parse("architecture-beta\n  service Backend[B]\n") |> ignore
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "titles lose their brackets and quotes" {
  inspect(convert_title("[ \"a \\\"b\\\" c\" ]"), content="a \"b\" c")
  inspect(convert_title("[Plain title]"), content="Plain title")
  inspect(convert_icon("(logos:aws)"), content="logos:aws")
}

///|
test "a service in a node is refused" {
  let message = try {
    parse("architecture-beta\n  service a[A]\n  service b[B] in a\n") |> ignore
    ""
  } catch {
    Invalid(message) => message
    _ => ""
  }
  inspect(message, content="The service [b]'s parent is not a group")
}
