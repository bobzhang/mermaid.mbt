///|
/// The variables of a mermaid theme: colors, fonts and sizes that diagram
/// stylesheets and renderers read by name (`primaryColor`, `pie1`, ...).
pub struct Theme {
  priv vars : Map[String, Json]
}

///|
/// The value of `name`, or `Json::null()` when the theme does not define it.
pub fn Theme::get(self : Theme, name : String) -> Json {
  self.vars.get(name).unwrap_or(Json::null())
}

///|
fn Theme::set(self : Theme, name : String, value : Json) -> Unit {
  self.vars[name] = value
}

///|
/// The value of `name` as text, converted the way a JavaScript template
/// literal would: a missing variable reads `undefined`.
pub fn Theme::text(self : Theme, name : String) -> String {
  to_string(self.get(name))
}

///|
/// The value of `name` when it is a number.
pub fn Theme::number(self : Theme, name : String) -> Double? {
  match self.get(name) {
    Number(n, ..) => Some(n)
    _ => None
  }
}

///|
/// Whether `name` is set to a truthy value.
pub fn Theme::flag(self : Theme, name : String) -> Bool {
  truthy(self.get(name))
}

///|
/// A field of an object-valued variable such as `xyChart` or `radar`.
pub fn Theme::nested(self : Theme, name : String, key : String) -> Json {
  field(self.get(name), key)
}

///|
/// The names of all variables, in definition order.
pub fn Theme::names(self : Theme) -> Array[String] {
  self.vars.keys().collect()
}

///|
pub impl ToJson for Theme with fn to_json(self) {
  Json::object(self.vars.copy())
}

///|
/// The names accepted by `Theme::new`.
pub let theme_names : Array[String] = [
  "base", "dark", "default", "forest", "neutral", "neo", "neo-dark", "redux", "redux-dark",
  "redux-color", "redux-dark-color",
]

///|
/// The value a variable takes once the user's override is applied. An
/// object-valued variable keeps every generated field and takes the user's
/// fields on top.
fn apply_override(generated : Json, user : Json) -> Json {
  match (generated, user) {
    (Object(base), Object(extra)) => {
      let merged = base.copy()
      for key, value in extra {
        merged[key] = value
      }
      Json::object(merged)
    }
    _ => user
  }
}

///|
/// Build the variables of the theme called `name`, applying `overrides`
/// (the user's `themeVariables`) both before and after derived colors are
/// computed. Returns `None` for an unknown theme name.
pub fn Theme::new(
  name : String,
  overrides? : Map[String, Json],
) -> Theme? raise @color.ColorError {
  guard theme_names.contains(name) else { return None }
  let theme = { vars: {}, }
  construct(name, theme)
  if name == "default" {
    // Placeholders left by the constructor are recomputed from scratch.
    for key in theme.names() {
      if theme.get(key) == str("calculated") {
        theme.set(key, Json::null())
      }
    }
  }
  guard overrides is Some(overrides) else {
    update_colors(name, theme)
    return Some(theme)
  }
  // Base colors first, so derived colors are computed from them...
  for key, value in overrides {
    theme.set(key, value)
  }
  update_colors(name, theme)
  // ...then again, so an override of a derived color wins.
  for key, value in overrides {
    theme.set(key, apply_override(theme.get(key), value))
  }
  if name == "base" &&
    overrides.contains("nodeBorder") &&
    !overrides.contains("useGradient") {
    // An explicit node border must not be painted over by the gradient.
    theme.set("useGradient", boolean(false))
  }
  Some(theme)
}

///|
/// Run the constructor of the theme class called `name`.
fn construct(name : String, theme : Theme) -> Unit raise @color.ColorError {
  match name {
    "base" => base_init(theme)
    "dark" => dark_init(theme)
    "default" => default_init(theme)
    "forest" => forest_init(theme)
    "neutral" => neutral_init(theme)
    "neo" => neo_init(theme)
    "neo-dark" => neo_dark_init(theme)
    "redux" => redux_init(theme)
    "redux-dark" => redux_dark_init(theme)
    "redux-color" => redux_color_init(theme)
    "redux-dark-color" => redux_dark_color_init(theme)
    _ => ()
  }
}

///|
/// Run `updateColors` of the theme class called `name`.
fn update_colors(name : String, theme : Theme) -> Unit raise @color.ColorError {
  match name {
    "base" => base_update_colors(theme)
    "dark" => dark_update_colors(theme)
    "default" => default_update_colors(theme)
    "forest" => forest_update_colors(theme)
    "neutral" => neutral_update_colors(theme)
    "neo" => neo_update_colors(theme)
    "neo-dark" => neo_dark_update_colors(theme)
    "redux" => redux_update_colors(theme)
    "redux-dark" => redux_dark_update_colors(theme)
    "redux-color" => redux_color_update_colors(theme)
    "redux-dark-color" => redux_dark_color_update_colors(theme)
    _ => ()
  }
}
