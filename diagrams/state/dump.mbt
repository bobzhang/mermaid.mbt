///|
/// The database as JSON, with upstream's field names, for comparing
/// against mermaid's own parse (scripts/check_state_parse.py).
pub fn StateDb::dump(self : StateDb) -> Json {
  let optional = (fields : Map[String, Json], key : String, value : String?) => {
    if value is Some(value) {
      fields[key] = Json::string(value)
    }
  }
  let nodes : Array[Json] = self.nodes.map(node => {
    let fields : Map[String, Json] = {
      "id": Json::string(node.id),
      "shape": Json::string(node.shape),
      "cssClasses": Json::string(node.css_classes),
      "cssCompiledStyles": Json(node.css_compiled_styles),
      "cssStyles": Json(node.css_styles),
      "domId": Json::string(node.dom_id),
      "isGroup": Json::boolean(node.is_group),
    }
    if node.label is One(label) {
      fields["label"] = Json::string(label)
    }
    if node.description.length() > 0 {
      fields["description"] = Json(node.description)
    }
    optional(fields, "dir", node.dir)
    optional(fields, "type", node.node_type)
    optional(fields, "parentId", node.parent_id)
    optional(fields, "labelType", node.label_type)
    optional(fields, "position", node.position)
    if node.color_index is Some(index) {
      fields["colorIndex"] = Json::number(index.to_double())
    }
    if node.padding is Some(padding) {
      fields["padding"] = Json::number(padding)
    }
    if node.rounded {
      fields["rx"] = 10
    }
    if node.center_label {
      fields["centerLabel"] = true
    }
    Json::object(fields)
  })
  let edges : Array[Json] = self.edges.map(edge => {
    let fields : Map[String, Json] = {
      "id": Json::string(edge.id),
      "start": Json::string(edge.start),
      "end": Json::string(edge.end),
      "arrowTypeEnd": Json::string(edge.arrow_type_end),
      "classes": Json::string(edge.classes),
    }
    if edge.label != "" {
      fields["label"] = Json::string(edge.label)
    }
    optional(fields, "pattern", edge.pattern)
    Json::object(fields)
  })
  let classes : Array[Json] = []
  for _, style_class in self.classes {
    classes.push({
      "id": Json::string(style_class.id),
      "styles": Json(style_class.styles),
      "textStyles": Json(style_class.text_styles),
    })
  }
  let links : Array[Json] = self.links.map(link => {
    let json : Json = {
      "id": Json::string(link.id),
      "url": Json::string(link.url),
      "tooltip": Json::string(link.tooltip),
    }
    json
  })
  {
    "nodes": Json::array(nodes),
    "edges": Json::array(edges),
    "classes": Json::array(classes),
    "links": Json::array(links),
    "accTitle": Json::string(self.acc_title),
    "accDescription": Json::string(self.acc_description),
    "direction": Json::string(document_direction(Some(self.root_doc))),
  }
}
