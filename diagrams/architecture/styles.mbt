///|
/// A theme variable as a template literal writes it.
fn css_value(value : Json) -> String {
  match value {
    String(text) => text
    Number(number, ..) => @dom.number(number)
    True => "true"
    False => "false"
    Null => "undefined"
    _ => "[object Object]"
  }
}

///|
/// The architecture diagram's stylesheet, before it is scoped to the
/// diagram: upstream's `architectureStyles.ts`.
pub fn styles(theme : @theme.Theme) -> String {
  let v = (name : String) => css_value(theme.get(name))
  (
    $|
    $|  .edge {
    $|    stroke-width: \{v("archEdgeWidth")};
    $|    stroke: \{v("archEdgeColor")};
    $|    fill: none;
    $|  }
    $|
    $|  .arrow {
    $|    fill: \{v("archEdgeArrowColor")};
    $|  }
    $|
    $|  .node-bkg {
    $|    fill: none;
    $|    stroke: \{v("archGroupBorderColor")};
    $|    stroke-width: \{v("archGroupBorderWidth")};
    $|    stroke-dasharray: 8;
    $|  }
    $|  .node-icon-text {
    $|    display: flex;
    $|    align-items: center;
    $|  }
    $|
    $|  .node-icon-text > div {
    $|    color: #fff;
    $|    margin: 1px;
    $|    height: fit-content;
    $|    text-align: center;
    $|    overflow: hidden;
    $|    display: -webkit-box;
    $|    -webkit-box-orient: vertical;
    $|  }
    $|
  )
}
