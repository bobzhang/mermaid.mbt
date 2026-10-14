///|
/// The sequence diagram's stylesheet, before it is scoped to the diagram
/// (styles.js). `look` is the look in effect, which decides whether label
/// boxes cast a shadow.
pub fn styles(theme : @theme.Theme, look : String) -> String {
  let v = (name : String) => theme.text(name)
  let drop_shadow = match theme.get("dropShadow") {
    Null => "none"
    _ => v("dropShadow")
  }
  let stroke_width = match theme.get("strokeWidth") {
    Null => "1"
    _ => v("strokeWidth")
  }
  let label_shadow = if look == "neo" { drop_shadow } else { "none" }
  (
    $|.actor {
    $|    stroke: \{v("actorBorder")};
    $|    fill: \{v("actorBkg")};
    $|    stroke-width: \{stroke_width};
    $|  }
    $|
    $|  rect.actor.outer-path[data-look="neo"] {
    $|      filter: \{drop_shadow};
    $|  }
    $|
    $|  rect.note[data-look="neo"] {
    $|      stroke:\{v("noteBorderColor")};
    $|      fill:\{v("noteBkgColor")};
    $|      filter: \{drop_shadow};
    $|  }
    $|
    $|  text.actor > tspan {
    $|    fill: \{v("actorTextColor")};
    $|    stroke: none;
    $|  }
    $|
    $|  .actor-line {
    $|    stroke: \{v("actorLineColor")};
    $|  }
    $|
    $|  .innerArc {
    $|    stroke-width: 1.5;
    $|    stroke-dasharray: none;
    $|  }
    $|
    $|  .messageLine0 {
    $|    stroke-width: 1.5;
    $|    stroke-dasharray: none;
    $|    stroke: \{v("signalColor")};
    $|  }
    $|
    $|  .messageLine1 {
    $|    stroke-width: 1.5;
    $|    stroke-dasharray: 2, 2;
    $|    stroke: \{v("signalColor")};
    $|  }
    $|
    $|  [id$="-arrowhead"] path {
    $|    fill: \{v("signalColor")};
    $|    stroke: \{v("signalColor")};
    $|  }
    $|
    $|  .sequenceNumber {
    $|    fill: \{v("sequenceNumberColor")};
    $|  }
    $|
    $|  [id$="-sequencenumber"] {
    $|    fill: \{v("signalColor")};
    $|  }
    $|
    $|  [id$="-crosshead"] path {
    $|    fill: \{v("signalColor")};
    $|    stroke: \{v("signalColor")};
    $|  }
    $|
    $|  .messageText {
    $|    fill: \{v("signalTextColor")};
    $|    stroke: none;
    $|  }
    $|
    $|  .labelBox {
    $|    stroke: \{v("labelBoxBorderColor")};
    $|    fill: \{v("labelBoxBkgColor")};
    $|    filter: \{label_shadow};
    $|  }
    $|
    $|  .labelText, .labelText > tspan {
    $|    fill: \{v("labelTextColor")};
    $|    stroke: none;
    $|  }
    $|
    $|  .loopText, .loopText > tspan {
    $|    fill: \{v("loopTextColor")};
    $|    stroke: none;
    $|  }
    $|
    $|  .sectionTitle, .sectionTitle > tspan {
    $|    fill: \{v("loopTextColor")};
    $|    stroke: none;
    $|  }
    $|
    $|  .loopLine {
    $|    stroke-width: 2px;
    $|    stroke-dasharray: 2, 2;
    $|    stroke: \{v("labelBoxBorderColor")};
    $|    fill: \{v("labelBoxBorderColor")};
    $|  }
    $|
    $|  .note {
    $|    //stroke: #decc93;
    $|    stroke: \{v("noteBorderColor")};
    $|    fill: \{v("noteBkgColor")};
    $|  }
    $|
    $|  /*
    $|   * No font-weight here, deliberately. Note text renders inside tspan elements, and a weight emitted at
    $|   * tspan level outranks the inline style drawText puts on the parent text element from the
    $|   * sequence.noteFontWeight config key -- so that documented key would never reach the glyphs.
    $|   * The theme variable formerly emitted here is a different value from that config key, and
    $|   * git/styles.js reads it as its own bold-label weight under redux and neo, so it cannot be
    $|   * lowered there either.
    $|   */
    $|  .noteText, .noteText > tspan {
    $|    fill: \{v("noteTextColor")};
    $|    stroke: none;
    $|  }
    $|
    $|  .activation0 {
    $|    fill: \{v("activationBkgColor")};
    $|    stroke: \{v("activationBorderColor")};
    $|  }
    $|
    $|  .activation1 {
    $|    fill: \{v("activationBkgColor")};
    $|    stroke: \{v("activationBorderColor")};
    $|  }
    $|
    $|  .activation2 {
    $|    fill: \{v("activationBkgColor")};
    $|    stroke: \{v("activationBorderColor")};
    $|  }
    $|
    $|  .actorPopupMenu {
    $|    position: absolute;
    $|  }
    $|
    $|  .actorPopupMenuPanel {
    $|    position: absolute;
    $|    fill: \{v("actorBkg")};
    $|    box-shadow: 0px 8px 16px 0px rgba(0,0,0,0.2);
    $|    filter: drop-shadow(3px 5px 2px rgb(0 0 0 / 0.4));
    $|}
    $|  .actor-man circle, line {
    $|    fill: \{v("actorBkg")};
    $|    stroke-width: 2px;
    $|  }
    $|
    $|  g rect.rect {
    $|    filter: \{drop_shadow};
    $|    stroke: \{v("nodeBorder")};
    $|  }
    $|
  )
}
