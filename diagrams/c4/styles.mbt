///|
/// The font rules of the element types, from the `c4` configuration
/// (`personFontFamily` and friends). Upstream builds them through the
/// CSSOM, which serializes each value and drops what is not valid for its
/// property.
fn element_font_styles(config : @config.Config) -> String raise Unsupported {
  let rules = []
  for kind in element_types {
    let declarations = []
    match config.get("c4.\{kind}FontFamily") {
      Null | False | String("") => ()
      String(family) =>
        match serialize_font_family(family) {
          Some(family) => declarations.push("font-family: \{family};")
          None => raise Unsupported("C4: c4.\{kind}FontFamily \{family}")
        }
      other =>
        raise Unsupported("C4: c4.\{kind}FontFamily \{other.stringify()}")
    }
    match config.get("c4.\{kind}FontSize") {
      Null | False | String("") => ()
      Number(size, ..) if size == 0.0 => ()
      value =>
        match font_size_px(value) {
          Some(size) => declarations.push("font-size: \{@dom.number(size)}px;")
          None =>
            raise Unsupported("C4: c4.\{kind}FontSize \{value.stringify()}")
        }
    }
    match config.get("c4.\{kind}FontWeight") {
      Null | False | String("") => ()
      Number(weight, ..) if weight == 0.0 => ()
      value =>
        match serialize_font_weight(value) {
          Some(weight) => declarations.push("font-weight: \{weight};")
          None =>
            raise Unsupported("C4: c4.\{kind}FontWeight \{value.stringify()}")
        }
    }
    if !declarations.is_empty() {
      rules.push("  .c4-shape.c4-\{kind} .label { \{declarations.join(" ")} }")
    }
  }
  rules.join("\n")
}

///|
/// The C4 stylesheet, before it is scoped to the diagram.
pub fn styles(config : @config.Config) -> String raise Unsupported {
  let theme = config.theme()
  let v = (name : String) => theme.text(name)
  let fonts = element_font_styles(config)
  (
    $|.person {
    $|    stroke: \{v("personBorder")};
    $|    fill: \{v("personBkg")};
    $|  }
    $|\{fonts}
    $|
    $|  /* The element font colour is set inline per element (default white); the
    $|     label text takes it via currentColor. */
    $|  .c4-shape .label,
    $|  .c4-shape .label text {
    $|    color: inherit;
    $|    fill: currentColor;
    $|  }
    $|  /* Structurizr typography: bold name, smaller stereotype/type and description lines. */
    $|  .c4-shape .label .c4-name {
    $|    font-weight: bold;
    $|  }
    $|  .c4-shape .label .c4-type {
    $|    font-size: 0.75em;
    $|  }
    $|  .c4-shape .label .c4-descr {
    $|    font-size: 0.82em;
    $|  }
    $|  .c4-shape .basic,
    $|  .c4-shape rect,
    $|  .c4-shape path,
    $|  .c4-shape circle,
    $|  .c4-shape ellipse,
    $|  .c4-shape line {
    $|    stroke-width: 2px;
    $|  }
    $|
  )
}
