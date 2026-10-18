///|
/// The database as JSON, with upstream's field names, for comparing
/// against mermaid's own parse.
pub fn FlowDb::dump(self : FlowDb) -> Json {
  let optional = (fields : Map[String, Json], key : String, value : String?) => {
    if value is Some(value) {
      fields[key] = Json::string(value)
    }
  }
  let vertices : Array[Json] = []
  for _, vertex in self.vertices {
    let fields : Map[String, Json] = {
      "id": Json::string(vertex.id),
      "labelType": Json::string(vertex.label_type),
      "domId": Json::string(vertex.dom_id),
      "styles": Json(vertex.styles),
      "classes": Json(vertex.classes),
    }
    optional(fields, "text", vertex.text)
    optional(fields, "type", vertex.shape)
    optional(fields, "link", vertex.link)
    optional(fields, "linkTarget", vertex.link_target)
    optional(fields, "icon", vertex.icon)
    optional(fields, "form", vertex.form)
    optional(fields, "pos", vertex.pos)
    optional(fields, "img", vertex.img)
    optional(fields, "constraint", vertex.constraint)
    if vertex.asset_width is Some(width) {
      fields["assetWidth"] = Json::number(width)
    }
    if vertex.asset_height is Some(height) {
      fields["assetHeight"] = Json::number(height)
    }
    if vertex.have_callback {
      fields["haveCallback"] = true
    }
    vertices.push(Json::object(fields))
  }
  let edges : Array[Json] = []
  for edge in self.edges {
    let fields : Map[String, Json] = {
      "start": Json::string(edge.start),
      "end": Json::string(edge.end),
      "text": Json::string(edge.text),
      "labelType": Json::string(edge.label_type),
      "classes": Json(edge.classes),
      "isUserDefinedId": Json::boolean(edge.is_user_defined_id),
      "id": Json::string(edge.id),
    }
    optional(fields, "type", edge.kind)
    optional(fields, "stroke", edge.stroke)
    optional(fields, "interpolate", edge.interpolate)
    optional(fields, "animation", edge.animation)
    if edge.length is Some(length) {
      fields["length"] = Json::number(length.to_double())
    }
    if edge.style is Some(style) {
      fields["style"] = Json(style)
    }
    if edge.animate is Some(animate) {
      // `JSON.stringify` writes numbers that are not finite as `null`.
      fields["animate"] = match animate {
        Number(n, ..) if n.is_nan() || n.is_inf() => Json::null()
        _ => animate
      }
    }
    edges.push(Json::object(fields))
  }
  let sub_graphs : Array[Json] = []
  for sub_graph in self.sub_graphs {
    let fields : Map[String, Json] = {
      "id": Json::string(sub_graph.id),
      "nodes": Json(sub_graph.nodes),
      "title": Json::string(sub_graph.title),
      "classes": Json(sub_graph.classes),
      "labelType": Json::string(sub_graph.label_type),
    }
    optional(fields, "dir", sub_graph.dir)
    if !sub_graph.metadata.is_empty() {
      fields["metadata"] = Json::object(sub_graph.metadata)
    }
    sub_graphs.push(Json::object(fields))
  }
  let classes : Array[Json] = []
  for _, style_class in self.classes {
    classes.push({
      "id": Json::string(style_class.id),
      "styles": Json(style_class.styles),
      "textStyles": Json(style_class.text_styles),
    })
  }
  let result : Map[String, Json] = {
    "vertices": Json::array(vertices),
    "edges": Json::array(edges),
    "subGraphs": Json::array(sub_graphs),
    "classes": Json::array(classes),
    "tooltips": Json(self.tooltips),
    "accTitle": Json::string(self.acc_title),
    "accDescription": Json::string(self.acc_description),
  }
  optional(result, "direction", self.direction())
  optional(result, "defaultInterpolate", self.default_interpolate)
  if self.default_style is Some(style) {
    result["defaultStyle"] = Json(style)
  }
  Json::object(result)
}
