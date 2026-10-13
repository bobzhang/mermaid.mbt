///|
/// Defaults that upstream sets in `defaultConfig.ts` on top of the schema:
/// values the schema cannot express, and diagram sections built by hand.
fn handwritten_defaults() -> Map[String, Json] {
  {
    "elk": {
      "mergeEdges": false,
      "straightenEdges": true,
      "lineHops": true,
      "preset": "default",
      "layeringLayerBound": 4,
      "forceNodeModelOrder": false,
      "considerModelOrder": "NODES_AND_EDGES",
      "keepEntryNodeOnTop": false,
      "orientFeedbackEdges": true,
    },
    "pie": { "useWidth": 984 },
    "railroad": {},
    "treemap": {
      "useMaxWidth": true,
      "padding": 10,
      "diagramPadding": 8,
      "showValues": true,
      "nodeWidth": 100,
      "nodeHeight": 40,
      "borderWidth": 1,
      "valueFontSize": 12,
      "labelFontSize": 14,
      "valueFormat": ",",
    },
  }
}

///|
/// The `class` section is built from scratch upstream: only the appearance
/// defaults are carried over from the schema.
fn class_defaults(schema : Json) -> Json {
  let section : Map[String, Json] = Map([])
  for key in ["theme", "look", "layout"] {
    if schema is Object({ "class": Object(fields), .. }) &&
      fields.get(key) is Some(value) {
      section[key] = value
    }
  }
  section["hideEmptyMembersBox"] = false
  section["hierarchicalNamespaces"] = true
  Json::object(section)
}

///|
/// Keys that `defaultConfig.ts` lists with an `undefined` value. They carry
/// no default but are still accepted in directives.
let undefined_keys : Array[String] = [
  "deterministicIDSeed", "themeCSS", "nodePlacementStrategy", "layeringStrategy",
  "cycleBreakingStrategy", "nodePlacementAlignment", "tickInterval", "useWidth",
  "fontSize", "fontFamily", "terminalFill", "terminalStroke", "terminalTextColor",
  "nonTerminalFill", "nonTerminalStroke", "nonTerminalTextColor", "lineColor", "markerFill",
  "commentFill", "commentStroke", "commentTextColor", "specialFill", "specialStroke",
  "ruleNameColor", "nodeColors",
]

///|
/// Font accessors that upstream defines as functions on the `sequence` and
/// `c4` sections; they count as known configuration keys.
let font_function_keys : Array[String] = [
  "messageFont", "noteFont", "actorFont", "personFont", "external_personFont", "systemFont",
  "external_systemFont", "system_dbFont", "external_system_dbFont", "system_queueFont",
  "external_system_queueFont", "containerFont", "external_containerFont", "container_dbFont",
  "external_container_dbFont", "container_queueFont", "external_container_queueFont",
  "componentFont", "external_componentFont", "component_dbFont", "external_component_dbFont",
  "component_queueFont", "external_component_queueFont", "boundaryFont",
]

///|
/// The complete default configuration, `themeVariables` included.
fn build_defaults() -> Map[String, Json] {
  let schema = schema_defaults()
  guard assign_with_depth(schema, Json::object(handwritten_defaults()))
    is Object(config) else {
    {}
  }
  config["class"] = class_defaults(schema)
  // Upstream nests a copy of the flowchart defaults under `c4`.
  if config.get("flowchart") is Some(flowchart) &&
    config.get("c4") is Some(Object(c4)) {
    c4["flowchart"] = assign_with_depth(clone(flowchart), {
      "inheritDir": false,
    })
  }
  if (try! @theme.Theme::new("default")) is Some(variables) {
    config["themeVariables"] = Json(variables)
  }
  config
}

///|
let default_data : Map[String, Json] = build_defaults()

///|
/// Collect the keys of `value` at every depth, skipping arrays.
fn collect_keys(value : Json, keys : Map[String, Unit]) -> Unit {
  guard value is Object(fields) else { return }
  for key, item in fields {
    keys[key] = ()
    collect_keys(item, keys)
  }
}

///|
/// Every key that appears anywhere in the default configuration. A
/// directive may only set these.
let config_keys : Map[String, Unit] = {
  let keys : Map[String, Unit] = Map([])
  collect_keys(Json::object(default_data), keys)
  for key in undefined_keys {
    keys[key] = ()
  }
  for key in font_function_keys {
    keys[key] = ()
  }
  keys
}
