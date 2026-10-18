///|
/// The effective configuration of one diagram: mermaid's defaults, the
/// site configuration and the diagram's own frontmatter and directives,
/// merged the way `mermaid.initialize` and `mermaidAPI.render` do.
pub struct Config {
  priv data : Map[String, Json]
  priv variables : @theme.Theme
  /// What the site configuration and the diagram's directives set, without
  /// the defaults: mermaid's `getUserDefinedConfig`.
  priv user : Json
}

///|
/// A configuration error.
pub(all) suberror ConfigError {
  /// A theme variable is not a color mermaid can compute with.
  InvalidColor(String)
} derive(Eq, Debug)

///|
/// Map a diagram type to the configuration key holding its section.
pub fn diagram_config_key(diagram_type : String) -> String {
  match diagram_type {
    "flowchart-v2" | "flowchart-elk" => "flowchart"
    "classDiagram" => "class"
    "stateDiagram" => "state"
    "xychart" => "xyChart"
    "railroadAbnf" | "railroadEbnf" | "railroadPeg" => "railroad"
    other => other
  }
}

///|
fn theme_variables(name : String, overrides : Json) -> Json? raise ConfigError {
  let overrides = match overrides {
    Object(fields) => Some(fields)
    _ => None
  }
  let theme = try {
    match overrides {
      Some(overrides) => @theme.Theme::new(name, overrides~)
      None => @theme.Theme::new(name)
    }
  } catch {
    @color.Unsupported(text) => raise InvalidColor(text)
    @color.MixedChannels => raise InvalidColor(name)
  }
  theme.map(theme => Json(theme))
}

///|
fn field(object : Json, key : String) -> Json {
  match object {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
/// JavaScript truthiness.
fn truthy(value : Json) -> Bool {
  match value {
    Null | False => false
    True | Array(_) | Object(_) => true
    Number(n, ..) => n != 0.0 && n == n
    String(s) => s != ""
  }
}

///|
/// Whether `value` may be used for the appearance key `key`: an unknown
/// theme or look is passed over rather than applied.
fn is_usable_appearance(key : String, value : Json) -> Bool {
  match (key, value) {
    (_, Null) => false
    ("theme", String(name)) => name == "null" || @theme.is_theme_name(name)
    ("theme", _) => false
    ("look", String(name)) => ["classic", "handDrawn", "neo"].contains(name)
    ("look", _) => false
    _ => true
  }
}

///|
/// The value `layer` gives the appearance key: the diagram's own section
/// wins over the top level.
fn read_appearance(layer : Json, section : String, key : String) -> Json {
  for candidate in [field(field(layer, section), key), field(layer, key)] {
    if is_usable_appearance(key, candidate) {
      return candidate
    }
  }
  Json::null()
}

///|
/// Build the configuration for a diagram.
///
/// - `site` is the configuration an application would pass to
///   `mermaid.initialize`.
/// - `directive` is the diagram's own configuration: its frontmatter
///   `config` merged with its `%%{init}%%` directive.
/// - `diagram_type` scopes `theme`, `look` and `layout`, which a diagram
///   section may set for that diagram type only.
pub fn Config::new(
  site~ : Json = Json::object(Map([])),
  directive~ : Json = Json::object(Map([])),
  diagram_type? : String,
) -> Config raise ConfigError {
  let defaults = Json::object(default_data)
  // The legacy place of the font family: `initialize` copies it into the
  // theme variables unless they name one.
  let site = if site is Object(fields) &&
    truthy(field(site, "fontFamily")) &&
    !truthy(field(field(site, "themeVariables"), "fontFamily")) {
    let fields = fields.copy()
    let variables = match fields.get("themeVariables") {
      Some(Object(variables)) => variables.copy()
      _ => Map([])
    }
    variables["fontFamily"] = field(site, "fontFamily")
    fields["themeVariables"] = Json::object(variables)
    Json::object(fields)
  } else {
    site
  }
  let mut site_config = assign_with_depth(clone(defaults), site)
  // `initialize` derives the theme variables from the site's overrides
  // whatever the theme: an unknown theme (other than "null") becomes the
  // default one, and so does a missing one. Without overrides the default
  // theme's variables are those of the defaults already.
  let site_theme = match field(site, "theme") {
    String(name) if @theme.is_theme_name(name) => Some(name)
    Null | String("null") =>
      if field(site, "themeVariables") is Null {
        None
      } else {
        Some("default")
      }
    _ => {
      if site_config is Object(fields) {
        fields["theme"] = Json::string("default")
      }
      Some("default")
    }
  }
  if site_theme is Some(name) &&
    theme_variables(name, field(site, "themeVariables")) is Some(variables) &&
    site_config is Object(fields) {
    fields["themeVariables"] = variables
    site_config = Json::object(fields)
  }
  // A directive may only touch known keys, never the secure ones.
  let mut directive = sanitize_directive(clone(directive))
  if directive is Object(fields) &&
    truthy(field(directive, "fontFamily")) &&
    !truthy(field(field(directive, "themeVariables"), "fontFamily")) {
    let variables = match fields.get("themeVariables") {
      Some(Object(variables)) => variables.copy()
      _ => Map([])
    }
    variables["fontFamily"] = field(directive, "fontFamily")
    fields["themeVariables"] = Json::object(variables)
  }
  let secure = match field(site_config, "secure") {
    Array(keys) =>
      keys.filter_map(key => if key is String(s) { Some(s) } else { None })
    _ => []
  }
  directive = sanitize(directive, secure)
  let sum = assign_with_depth(Json::object(Map([])), directive)
  let user = assign_with_depth(
    assign_with_depth(Json::object(Map([])), clone(site)),
    sum,
  )
  guard assign_with_depth(clone(site_config), sum) is Object(config) else {
    { data: Map([]), variables: @theme.Theme::from_variables(Map([])), user, }
  }
  // Resolve theme, look and layout onto the top level, where renderers
  // read them: most specific layer first.
  if diagram_type is Some(diagram_type) {
    let section = diagram_config_key(diagram_type)
    for key in ["theme", "look", "layout"] {
      for layer in [sum, directive, site, defaults] {
        let value = read_appearance(layer, section, key)
        if value is Null {
          continue
        }
        config[key] = value
        if config.get(section) is Some(Object(fields)) && fields.contains(key) {
          fields[key] = value
        }
        break
      }
    }
  }
  let theme = config.get("theme").unwrap_or(Json::null())
  let overridden = truthy(field(sum, "theme")) ||
    theme != field(site_config, "theme")
  if overridden && theme is String(name) {
    let overrides = assign_with_depth(
      match field(site, "themeVariables") {
        Null => Json::object(Map([]))
        variables => clone(variables)
      },
      field(sum, "themeVariables"),
    )
    if theme_variables(name, overrides) is Some(variables) {
      config["themeVariables"] = variables
    }
  }
  let variables = match config.get("themeVariables") {
    Some(Object(variables)) => @theme.Theme::from_variables(variables)
    _ => @theme.Theme::from_variables(Map([]))
  }
  { data: config, variables, user, }
}

///|
/// The value at a dotted path such as `layout` as the site configuration
/// and the diagram's directives set it, `Json::null()` where they leave
/// it to the defaults: mermaid's `getUserDefinedConfig`.
pub fn Config::user_defined(self : Config, path : String) -> Json {
  let mut value = self.user
  for key in path.split(".") {
    value = field(value, key.to_owned())
  }
  value
}

///|
/// The theme variables in effect.
pub fn Config::theme(self : Config) -> @theme.Theme {
  self.variables
}

///|
/// The value at a dotted path such as `pie.textPosition`, or
/// `Json::null()` when unset.
pub fn Config::get(self : Config, path : String) -> Json {
  let mut value = Json::object(self.data)
  for key in path.split(".") {
    value = field(value, key.to_owned())
  }
  value
}

///|
/// The number at `path`, if it is one.
pub fn Config::number(self : Config, path : String) -> Double? {
  match self.get(path) {
    Number(n, ..) => Some(n)
    _ => None
  }
}

///|
/// The string at `path`, if it is one.
pub fn Config::text(self : Config, path : String) -> String? {
  match self.get(path) {
    String(s) => Some(s)
    _ => None
  }
}

///|
/// Whether the value at `path` is truthy in the JavaScript sense.
pub fn Config::flag(self : Config, path : String) -> Bool {
  truthy(self.get(path))
}

///|
/// mermaid's `evaluate`: everything is true except `false` and the strings
/// `false`, `null` and `0`.
pub fn evaluate(value : Json) -> Bool {
  match value {
    False => false
    String(s) =>
      !["false", "null", "0"].contains(s.trim().to_owned().to_lower())
    Null => false
    Number(n, ..) => n != 0.0
    _ => true
  }
}

///|
pub impl ToJson for Config with fn to_json(self) {
  clone(Json::object(self.data))
}
