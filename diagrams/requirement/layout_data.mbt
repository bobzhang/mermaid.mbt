///|
/// The nodes and edges to lay out: mermaid's `RequirementDB.getData`.
fn RequirementDb::layout_data(
  self : RequirementDb,
) -> (Array[@rendering.Node], Array[@rendering.Edge]) {
  let look = self.config.text("look").unwrap_or("classic")
  let nodes : Array[@rendering.Node] = []
  let edges : Array[@rendering.Edge] = []
  for _, requirement in self.requirements {
    nodes.push(
      @rendering.Node::new(
        id=requirement.name,
        // The box draws its own texts.
        label="",
        padding=0.0,
        css_styles=requirement.css_styles,
        css_classes=requirement.classes.join(" "),
        look~,
        shape="requirementBox",
        color_index=nodes.length(),
        data=Requirement(
          name=requirement.name,
          type_=requirement.type_,
          requirement_id=requirement.requirement_id,
          text=requirement.text,
          risk=requirement.risk,
          verify_method=requirement.verify_method,
        ),
      ),
    )
  }
  for _, element in self.elements {
    nodes.push(
      @rendering.Node::new(
        id=element.name,
        label="",
        padding=0.0,
        css_styles=element.css_styles,
        css_classes=element.classes.join(" "),
        look~,
        shape="requirementBox",
        color_index=nodes.length(),
        data=RequirementElement(
          name=element.name,
          type_=element.type_,
          doc_ref=element.doc_ref,
        ),
      ),
    )
  }
  for counter, relation in self.relations {
    let contains = relation.type_ == "contains"
    edges.push(
      @rendering.Edge::new(
        id="\{relation.src}-\{relation.dst}-\{counter}",
        start=relation.src,
        end=relation.dst,
        label="&lt;&lt;\{relation.type_}&gt;&gt;",
        label_type="markdown",
        thickness="normal",
        pattern=if contains { "normal" } else { "dashed" },
        classes="relationshipLine",
        arrow_type_start=if contains { "requirement_contains" } else { "" },
        arrow_type_end=if contains { "" } else { "requirement_arrow" },
        style=[
          "fill:none",
          if contains {
            ""
          } else {
            "stroke-dasharray: 10,7"
          },
        ],
        look~,
        labelpos="c",
      ),
    )
  }
  (nodes, edges)
}
