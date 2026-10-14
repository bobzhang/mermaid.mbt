///|
/// The settings the renderer works with: the `sequence` section with the
/// top-level configuration laid over it, as `setConf` leaves it.
priv struct Conf {
  look : String
  theme : String
  use_max_width : Bool
  hide_unused_participants : Bool
  activation_width : Double
  diagram_margin_x : Double
  diagram_margin_y : Double
  actor_margin : Double
  width : Double
  /// The height of the tallest participant once they are measured.
  mut height : Double
  box_margin : Double
  box_text_margin : Double
  note_margin : Double
  message_align : String
  mirror_actors : Bool
  force_menus : Bool
  bottom_margin_adj : Double
  right_angles : Bool
  show_sequence_numbers : Bool
  actor_font : TextFont
  note_font : TextFont
  message_font : TextFont
  note_align : String
  wrap_padding : Double
  label_box_width : Double
  label_box_height : Double
  /// How participant labels are drawn: `tspan` unless configured.
  text_placement : String
}

///|
/// Read the configuration the way the renderer sees it. `setConf` merges
/// the whole configuration into the `sequence` section, so a top-level key
/// with the name of a sequence setting overrides it, and the top-level
/// font settings replace the fonts of all three kinds of text.
fn Conf::new(config : @config.Config) -> Conf raise SequenceError {
  let value = (key : String) => {
    let own = config.get("sequence.\{key}")
    match (config.get(key), own) {
      (_, Object(_) | Array(_)) => own
      (String(_) | Number(_, ..) | True | False as top, _) => top
      _ => own
    }
  }
  let number = (key : String) => {
    match value(key) {
      Number(n, ..) => n
      other =>
        raise SequenceError(
          "Unsupported value for sequence.\{key}: \{other.stringify()}",
        )
    }
  }
  let text = (key : String, default : String) => {
    match value(key) {
      String(text) => text
      _ => default
    }
  }
  let flag = (key : String) => truthy(value(key))
  if flag("arrowMarkerAbsolute") {
    // Marker references would carry the address of the page.
    raise SequenceError("Unsupported: arrowMarkerAbsolute")
  }
  let font = (kind : String) => {
    let pick = (shared : String, own : String) => {
      let shared = config.get(shared)
      if truthy(shared) {
        shared
      } else {
        value(own)
      }
    }
    let font : TextFont = {
      family: match pick("fontFamily", "\{kind}FontFamily") {
        String(family) => Some(family)
        _ => None
      },
      size: pick("fontSize", "\{kind}FontSize"),
      weight: pick("fontWeight", "\{kind}FontWeight"),
    }
    font
  }
  {
    look: text("look", ""),
    theme: text("theme", ""),
    use_max_width: flag("useMaxWidth"),
    hide_unused_participants: value("hideUnusedParticipants") is True,
    activation_width: number("activationWidth"),
    diagram_margin_x: number("diagramMarginX"),
    diagram_margin_y: number("diagramMarginY"),
    actor_margin: number("actorMargin"),
    width: number("width"),
    height: number("height"),
    box_margin: number("boxMargin"),
    box_text_margin: number("boxTextMargin"),
    note_margin: number("noteMargin"),
    message_align: text("messageAlign", ""),
    mirror_actors: flag("mirrorActors"),
    force_menus: flag("forceMenus"),
    bottom_margin_adj: number("bottomMarginAdj"),
    right_angles: flag("rightAngles"),
    show_sequence_numbers: flag("showSequenceNumbers"),
    actor_font: font("actor"),
    note_font: font("note"),
    message_font: font("message"),
    note_align: text("noteAlign", ""),
    wrap_padding: number("wrapPadding"),
    label_box_width: number("labelBoxWidth"),
    label_box_height: number("labelBoxHeight"),
    text_placement: text("textPlacement", "tspan"),
  }
}

///|
/// Themes that color each participant from a palette.
fn Conf::is_color_theme(self : Conf) -> Bool {
  self.theme is ("redux-color" | "redux-dark-color")
}

///|
fn Conf::is_neo(self : Conf) -> Bool {
  self.look == "neo"
}
