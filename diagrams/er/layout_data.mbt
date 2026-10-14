///|
/// The nodes and edges to lay out: mermaid's `ErDB.getData`. `dagre` says
/// whether dagre lays them out, which draws an edge without a style of its
/// own with the style `undefined`.
fn ErDb::layout_data(
  self : ErDb,
  dagre~ : Bool = false,
) -> (Array[@rendering.Node], Array[@rendering.Edge]) {
  let look = self.config.text("look").unwrap_or("default")
  let nodes : Array[@rendering.Node] = []
  let edges : Array[@rendering.Edge] = []
  let sub_graphs = self.sub_graphs
  let parent_db : Map[String, String] = Map([])
  for i = sub_graphs.length() - 1; i >= 0; i = i - 1 {
    for id in sub_graphs[i].nodes {
      parent_db[id] = sub_graphs[i].id
    }
  }
  for i = sub_graphs.length() - 1; i >= 0; i = i - 1 {
    let sub_graph = sub_graphs[i]
    nodes.push(
      @rendering.Node::new(
        id=sub_graph.id,
        label=sub_graph.title,
        label_type=sub_graph.label_type,
        parent_id?=parent_db.get(sub_graph.id),
        padding=8.0,
        css_compiled_styles=self.compiled_styles(sub_graph.classes),
        css_styles=sub_graph.css_styles,
        css_classes=sub_graph.classes.join(" "),
        shape="rect",
        dir?=sub_graph.dir,
        is_group=true,
        look~,
      ),
    )
  }
  let mut color_index = 0
  for name, entity in self.entities {
    // A subgraph of the same name stands in for the entity.
    if sub_graphs.iter().any(sub_graph => sub_graph.id == name) {
      continue
    }
    let class_names = entity.css_classes
      .split(" ")
      .map(name => name.to_owned())
      .collect()
    nodes.push(
      @rendering.Node::new(
        id=entity.id,
        label=entity.label,
        label_type="markdown",
        parent_id?=parent_db.get(name),
        // Entities have no padding of their own.
        padding=0.0,
        css_styles=entity.css_styles,
        css_compiled_styles=self.compiled_styles(class_names),
        css_classes=entity.css_classes,
        look~,
        shape="erBox",
        color_index~,
        data=Entity(
          alias_name=entity.alias_name,
          attributes=entity.attributes.map(attribute => {
            type_: attribute.type_,
            name: attribute.name,
            keys: attribute.keys,
            comment: attribute.comment,
          }),
        ),
      ),
    )
    color_index += 1
  }
  for count, relationship in self.relationships {
    edges.push(
      @rendering.Edge::new(
        id="id_\{relationship.entity_a}_\{relationship.entity_b}_\{count}",
        start=relationship.entity_a,
        end=relationship.entity_b,
        label=relationship.role_a,
        label_type="markdown",
        thickness="normal",
        pattern=if relationship.rel_type == "IDENTIFYING" {
          "solid"
        } else {
          "dashed"
        },
        classes="relationshipLine",
        arrow_type_start=relationship.card_b.to_lower(),
        arrow_type_end=relationship.card_a.to_lower(),
        // What the layout gives an edge that brings no style of its own.
        style=[if dagre { "undefined" } else { "fill:none" }],
        look~,
        labelpos="c",
        curve="basis",
      ),
    )
  }
  (nodes, edges)
}
