///|
/// The parsed map as JSON, or the error.
fn dump(source : String) -> Json {
  let map = @wardley.parse(source) catch {
    @langium.ParseError(message~, ..) =>
      return Json::string("syntax: " + message)
    @wardley.Invalid(message) => return Json::string("invalid: " + message)
    _ => return Json::string("error")
  }
  let flow = (flow : @wardley.Flow?) => {
    match flow {
      Some(Forward) => ">"
      Some(Backward) => "<"
      Some(Bidirectional) => "<>"
      None => "-"
    }
  }
  {
    "nodes": map.nodes.map(node => {
      let strategy = node.source_strategy.unwrap_or("")
      let flags = (if node.inertia { "i" } else { "" }) +
        (if node.is_pipeline_parent { "P" } else { "" }) +
        (if node.in_pipeline { "p" } else { "" })
      "\{node.id}=\{node.label} \{node.class_name} \{node.x},\{node.y} \{strategy}\{flags}"
    }),
    "links": map.links.map(link => {
      let dashed = if link.dashed { " dashed" } else { "" }
      "\{link.source} \{flow(link.flow)} \{link.target} [\{link.label.unwrap_or("")}]\{dashed}"
    }),
    "trends": map.trends.map(trend => {
      "\{trend.node_id} \{trend.target_x},\{trend.target_y}"
    }),
    "pipelines": map.pipelines.map(pipeline => {
      "\{pipeline.node_id}: \{pipeline.component_ids.join(" ")}"
    }),
    "stages": Json(map.stages),
    "title": map.title,
  }
}

///|
/// One part of a dump.
fn part(source : String, key : String) -> Json {
  match dump(source) {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    other => other
  }
}

///|
test "statements are filled in by kind, positions become percentages" {
  json_inspect(
    dump(
      (
        #|wardley-beta
        #|title  Tea   Shop
        #|Business -> Cup of Tea
        #|evolve Kettle 0.62
        #|component Cup of Tea [0.79, 0.61] label [19, -4] (buy) inertia
        #|component Kettle [43.5, 35.0]
        #|anchor Business [0.95, 0.63]
      ),
    ),
    content={
      "nodes": [
        "Business=Business anchor 63,95 ", "Cup of Tea=Cup of Tea component 61,79 buyi",
        "Kettle=Kettle component 35,43.5 ",
      ],
      "links": ["Business - Cup of Tea []"],
      "trends": ["Kettle 62,43.5"],
      "pipelines": [],
      "stages": [],
      "title": "Tea Shop",
    },
  )
}

///|
test "links: ports, arrows with a label, annotations, dashes" {
  json_inspect(
    part(
      (
        #|wardley-beta
        #|A +> B
        #|A +<> B +>
        #|A +'via'< B; ignored
        #|A -.-> B;  noted
        #|A-->B
        #|"A" "B"
      ),
      "links",
    ),
    content=[
      "A > B []", "A <> B []", "A < B [via]", "A - B [noted] dashed", "A- - B []",
      "A - B []",
    ],
  )
}

///|
test "the components of a pipeline get ids of their own and are linked to by label" {
  json_inspect(
    dump(
      (
        #|wardley-beta
        #|component Database [0.40, 0.60]
        #|pipeline Database {
        #|  component "SQL DB" [0.50]
        #|
        #|  component NoSQL [0.70]
        #|}
        #|NoSQL -> Database
      ),
    ),
    content={
      "nodes": [
        "Database=Database component 60,40 P", "Database_SQL DB=SQL DB pipeline-component 50,40 p",
        "Database_NoSQL=NoSQL pipeline-component 70,40 p",
      ],
      "links": ["Database_NoSQL - Database []"],
      "trends": [],
      "pipelines": ["Database: Database_SQL DB Database_NoSQL"],
      "stages": [],
      "title": "",
    },
  )
}

///|
test "stages with two names and boundaries" {
  json_inspect(
    part(
      "wardley-beta\nevolution Genesis@0.2 / Concept -> \" Custom \" -> x_1", "stages",
    ),
    content=["Genesis / Concept", "Custom", "x_1"],
  )
}

///|
test "keywords are cut out of the start of a name" {
  json_inspect(
    dump("wardley-beta\ncomponent notebook [0.5, 0.5]"),
    content="syntax: Expecting a name but found 'note'",
  )
  json_inspect(
    part("wardley-beta\ncomponent Online notebook [0.5, 0.5]", "nodes"),
    content=["Online notebook=Online notebook component 50,50 "],
  )
}

///|
test "positions outside the map are refused with upstream's message" {
  json_inspect(
    dump("wardley-beta\ncomponent A [50.5, 125.25]"),
    content="invalid: Component \"A\" evolution must be between 0-1 (decimal) or 0-100 (percentage). Received: 125.25",
  )
  json_inspect(
    dump("wardley-beta\npipeline Nope {\n component a [0.1]\n}"),
    content="invalid: Pipeline \"Nope\" must reference an existing component with coordinates.",
  )
}
