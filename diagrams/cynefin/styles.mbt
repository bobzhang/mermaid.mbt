///|
/// The `cynefin` block of the theme variables as the diagram reads it:
/// the current theme's, and for what that lacks — some themes have no
/// such block at all — the default theme's.
priv struct CynefinTheme {
  current : @theme.Theme
  fallback : @theme.Theme?
}

///|
fn CynefinTheme::new(theme : @theme.Theme) -> CynefinTheme {
  let fallback = @theme.Theme::new("default") catch { _ => None }
  { current: theme, fallback, }
}

///|
fn CynefinTheme::get(self : CynefinTheme, key : String) -> Json {
  match self.current.nested("cynefin", key) {
    Null =>
      match self.fallback {
        Some(theme) => theme.nested("cynefin", key)
        None => Json::null()
      }
    value => value
  }
}

///|
/// A value in a JavaScript template literal.
fn js_text(value : Json) -> String {
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
/// `value - 1`, which makes a number of text first.
fn js_minus_one(value : Json) -> String {
  match value {
    Number(number, ..) => @dom.number(number - 1.0)
    String(text) =>
      match js_number(text) {
        Some(number) => @dom.number(number - 1.0)
        None => "NaN"
      }
    _ => "NaN"
  }
}

///|
/// `value + 2`, which appends to text.
fn js_plus_two(value : Json) -> String {
  match value {
    Number(number, ..) => @dom.number(number + 2.0)
    other => js_text(other) + "2"
  }
}

///|
/// `Number(text)` for plain decimal text; nothing for what is not.
fn js_number(text : String) -> Double? {
  let text = @journeycommon.js_trim(text)
  if text == "" {
    return Some(0.0)
  }
  let digits = text
    .strip_prefix("-")
    .map(rest => rest.to_owned())
    .unwrap_or(text)
  if digits == "" ||
    !digits.iter().all(c => c is ('0'..<='9' | '.')) ||
    digits.iter().filter(c => c == '.').count() > 1 ||
    digits == "." {
    return None
  }
  Some(@string.parse_double(text)) catch {
    _ => None
  }
}

///|
/// The Cynefin diagram's stylesheet, before it is scoped to the diagram.
pub fn styles(theme : @theme.Theme) -> String {
  let block = CynefinTheme::new(theme)
  let t = (key : String) => js_text(block.get(key))
  (
    $|
    $|	.cynefinDomain {
    $|		stroke: none;
    $|	}
    $|	.cynefinDomainLabel {
    $|		font-size: \{t("domainFontSize")}px;
    $|		font-weight: bold;
    $|		fill: \{t("labelColor")};
    $|	}
    $|	.cynefinSubtitle {
    $|		font-size: \{js_minus_one(block.get("itemFontSize"))}px;
    $|		fill: \{t("textColor")};
    $|		font-style: italic;
    $|	}
    $|	.cynefinItem {
    $|		fill-opacity: 0.95;
    $|		stroke: \{t("boundaryColor")};
    $|		stroke-width: 1;
    $|	}
    $|	.cynefinItemText {
    $|		font-size: \{t("itemFontSize")}px;
    $|		fill: \{t("textColor")};
    $|	}
    $|	.cynefinItemOverflow {
    $|		fill-opacity: 0.6;
    $|		stroke: \{t("boundaryColor")};
    $|		stroke-width: 1;
    $|		stroke-dasharray: 3 2;
    $|	}
    $|	.cynefinBoundary {
    $|		stroke: \{t("boundaryColor")};
    $|		stroke-width: \{t("boundaryWidth")};
    $|		stroke-dasharray: 6 3;
    $|	}
    $|	.cynefinCliff {
    $|		stroke: \{t("cliffColor")};
    $|		stroke-width: \{t("cliffWidth")};
    $|	}
    $|	.cynefinConfusion {
    $|		stroke: \{t("boundaryColor")};
    $|		stroke-width: 1.5;
    $|		stroke-dasharray: 4 2;
    $|	}
    $|	.cynefinArrowLine {
    $|		stroke: \{t("arrowColor")};
    $|		stroke-width: \{t("arrowWidth")};
    $|		fill: none;
    $|	}
    $|	.cynefinArrowHead {
    $|		fill: \{t("arrowColor")};
    $|		stroke: none;
    $|	}
    $|	.cynefinArrowLabel {
    $|		font-size: \{js_minus_one(block.get("itemFontSize"))}px;
    $|		fill: \{t("textColor")};
    $|	}
    $|	.cynefinTitle {
    $|		font-size: \{js_plus_two(block.get("domainFontSize"))}px;
    $|		font-weight: bold;
    $|		fill: \{t("labelColor")};
    $|	}
    $|	
  )
}
