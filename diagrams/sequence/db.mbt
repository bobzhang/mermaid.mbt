///|
/// Why a sequence diagram was rejected after it parsed.
pub(all) suberror SequenceError {
  SequenceError(String)
} derive(Eq, Debug)

///|
/// A `box` around participants.
priv struct Box {
  /// The title, when the box has one.
  mut name : String?
  wrap : Bool
  fill : String
  actor_keys : Array[String]
  // Set by the renderer.
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
  mut margin : Double
  mut text_max_height : Double
}

///|
/// A participant. Upstream calls every kind of participant an actor.
priv struct Actor {
  mut box : Box?
  name : String
  mut description : String
  wrap : Bool
  prev_actor : String?
  mut next_actor : String?
  /// The popup menu: labels and their targets.
  links : Map[String, Json]
  properties : Map[String, Json]
  /// `participant`, `actor`, `boundary`, ...
  kind : String
  // Set by the renderer. `NaN` stands for JavaScript's `undefined`.
  mut actor_cnt : Int32?
  mut rect_data : RectData?
  mut x : Double
  mut width : Double
  mut height : Double
  mut margin : Double
  mut starty : Double
  mut stopy : Double
  mut text_height : Double?
}

///|
/// One entry of the diagram, in source order: a message, a note, or a
/// marker that starts or ends an activation, a block or numbering.
priv struct Message {
  id : Int32
  from : String?
  to : String?
  mut message : String
  mut wrap : Bool
  kind : Int32
  activate : Bool
  central_connection : Int32
  /// Notes only.
  placement : Int32?
  /// `autonumber` only: where to start, the step, and whether numbers
  /// show.
  sequence_start : Double?
  sequence_step : Double?
  sequence_visible : Bool
  // Set by the renderer.
  mut note_model : NoteModel?
  mut msg_model : MsgModel?
}

///|
/// The parsed sequence diagram (`SequenceDB` upstream).
pub struct SequenceDb {
  priv config : @config.Config
  priv mut prev_actor : String?
  priv actors : Map[String, Actor]
  /// Participants made by `create`, with the index of the entry after
  /// their declaration.
  priv created_actors : Map[String, Int32]
  priv destroyed_actors : Map[String, Int32]
  priv boxes : Array[Box]
  priv messages : Array[Message]
  priv mut sequence_numbers_enabled : Bool
  priv mut current_box : Box?
  priv mut last_created : String?
  priv mut last_destroyed : String?
  mut title : String
  mut acc_title : String
  mut acc_description : String
}

///|
fn SequenceDb::new(config : @config.Config) -> SequenceDb {
  {
    config,
    prev_actor: None,
    actors: Map([]),
    created_actors: Map([]),
    destroyed_actors: Map([]),
    boxes: [],
    messages: [],
    sequence_numbers_enabled: false,
    current_box: None,
    last_created: None,
    last_destroyed: None,
    title: "",
    acc_title: "",
    acc_description: "",
  }
}

///|
/// The same diagram under another title.
pub fn SequenceDb::set_title(self : SequenceDb, title : String) -> Unit {
  self.title = title
}

///|
/// Whether text wraps when it does not say so itself: the top-level `wrap`
/// setting, else the diagram's own.
fn SequenceDb::auto_wrap(self : SequenceDb) -> Bool {
  match self.config.get("wrap") {
    Null => self.config.flag("sequence.wrap")
    _ => self.config.flag("wrap")
  }
}

///|
/// `String.prototype.trim`.
fn js_trim(text : StringView) -> String {
  text
  .trim(
    chars=" \t\n\u{0b}\u{0c}\r\u{a0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200a}\u{2028}\u{2029}\u{202f}\u{205f}\u{3000}\u{feff}",
  )
  .to_owned()
}

///|
/// Split a leading `wrap:` or `nowrap:` off a text (`extractWrap`).
fn extract_wrap(text : String) -> (String, Bool?) {
  let text = js_trim(text)
  for
    prefix, wrap in {
      ":wrap:": true,
      "wrap:": true,
      ":nowrap:": false,
      "nowrap:": false,
    } {
    if text.strip_prefix(prefix) is Some(rest) {
      return (js_trim(rest), Some(wrap))
    }
  }
  (text, None)
}

///|
/// A text with its wrap setting, as the grammar's actions pass it around:
/// `{ text, wrap }` with `wrap` left out when the text does not say.
fn parse_message(text : String) -> Json {
  let (cleaned, wrap) = extract_wrap(js_trim(text))
  let fields : Map[String, Json] = { "text": Json::string(cleaned) }
  if wrap is Some(wrap) {
    fields["wrap"] = Json::boolean(wrap)
  }
  Json::object(fields)
}

///|
/// mermaid's `sanitizeText`. The HTML sanitizer hands text without a `<`
/// back untouched. With one, the text is parsed as HTML and written out
/// again; only text whose `<` cannot start a tag is handled here.
fn sanitize_text(text : String) -> String raise SequenceError {
  guard text.contains("<") else { return text }
  let markup = try! @jsregex.Regex::compile("<[/!?a-zA-Z]")
  if markup.exec(text) is Some(_) {
    raise SequenceError("Unsupported: HTML markup in sequence diagram text")
  }
  // Character references are resolved, and the three characters HTML
  // cannot write literally come back as references.
  let amp = try! @jsregex.Regex::compile("&(?![a-zA-Z0-9#]+;)", flags="g")
  @dom.sanitized_text(
    amp
    .replace_all(text, _ => "&amp;")
    .replace_all(old="<", new="&lt;")
    .replace_all(old=">", new="&gt;"),
  )
}

///|
/// The color and title of a `box` line: the color comes first when the
/// line starts with one, the rest is the title.
fn parse_box_data(text : String) -> Json raise SequenceError {
  let pattern = try! @jsregex.Regex::compile(
    "^((?:rgba?|hsla?)\\s*\\(.*\\)|\\w*)(.*)$",
  )
  let (first, rest) = match pattern.exec(text) {
    Some(found) => (found.group(1).unwrap_or(""), found.group(2).unwrap_or(""))
    None => ("", "")
  }
  let mut color = if first == "" { "transparent" } else { js_trim(first) }
  let mut title = if rest == "" { None } else { Some(js_trim(rest)) }
  if !css_supports_color(color) {
    color = "transparent"
    title = Some(js_trim(text))
  }
  let fields : Map[String, Json] = { "color": Json::string(color) }
  if title is Some(title) {
    let (cleaned, wrap) = extract_wrap(title)
    if cleaned != "" {
      fields["text"] = Json::string(sanitize_text(cleaned))
    }
    if wrap is Some(wrap) {
      fields["wrap"] = Json::boolean(wrap)
    }
  }
  Json::object(fields)
}

///|
fn field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn text_field(value : Json, key : String) -> String? {
  match field(value, key) {
    String(text) => Some(text)
    _ => None
  }
}

///|
/// JavaScript truthiness.
fn truthy(value : Json) -> Bool {
  match value {
    Null | False => false
    String(s) => s != ""
    Number(n, ..) => n != 0.0 && n == n
    _ => true
  }
}

///|
/// Parse the body of a participant's `@{ ... }` block as YAML.
fn parse_metadata(metadata : String) -> Json raise {
  let source = if metadata.contains("\n") {
    metadata + "\n"
  } else {
    "{\n" + metadata + "\n}"
  }
  match @yaml.Yaml::load_from_string(source) {
    [document, ..] => Json(document)
    [] => Json::null()
  }
}

///|
fn SequenceDb::add_box(self : SequenceDb, data : Json) -> Unit {
  let box : Box = {
    name: text_field(data, "text"),
    wrap: match field(data, "wrap") {
      Null => self.auto_wrap()
      wrap => truthy(wrap)
    },
    fill: text_field(data, "color").unwrap_or("transparent"),
    actor_keys: [],
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    margin: 0.0,
    text_max_height: 0.0,
  }
  self.boxes.push(box)
  self.current_box = Some(box)
}

///|
/// Declare a participant, or mention one in a message. `description` is
/// the `{ text, wrap }` of an `as` alias, `kind` what the declaring keyword
/// draws, and `metadata` the text of a `@{ ... }` block.
fn SequenceDb::add_actor(
  self : SequenceDb,
  id : String,
  description : Json,
  kind : String?,
  metadata : String?,
) -> Unit raise {
  let name = id
  let mut assigned_box = self.current_box
  let mut kind = kind
  // The text shown instead of the name, and whether it wraps; `None`
  // while there is none.
  let mut shown : (String, Bool?)? = match description {
    Object(_) =>
      Some(
        (
          text_field(description, "text").unwrap_or(""),
          match field(description, "wrap") {
            Null => None
            wrap => Some(truthy(wrap))
          },
        ),
      )
    _ => None
  }
  if metadata is Some(metadata) {
    let doc = parse_metadata(metadata)
    match field(doc, "type") {
      Null => ()
      String(text) => kind = Some(text)
      other =>
        raise SequenceError(
          "Unsupported participant type: \{other.stringify()}",
        )
    }
    if truthy(field(doc, "alias")) &&
      (shown is None || (shown is Some((text, _)) && text == name)) {
      guard field(doc, "alias") is String(text) else {
        raise SequenceError("content.split is not a function")
      }
      shown = Some((text, shown.bind(pair => pair.1)))
    }
  }
  if self.actors.get(id) is Some(old) {
    if self.current_box is Some(current) &&
      old.box is Some(box) &&
      !physical_equal(current, box) {
      raise SequenceError(
        "A same participant should only be defined in one Box: \{old.name} can't be in '\{box.name.unwrap_or("undefined")}' and in '\{current.name.unwrap_or("undefined")}' at the same time.",
      )
    }
    assigned_box = match old.box {
      Some(box) => Some(box)
      None => self.current_box
    }
    old.box = assigned_box
    if name == old.name && shown is None {
      return
    }
  }
  // Without a declared kind the name is shown, alias or not.
  let (text, wrap) = match (shown, kind) {
    (Some(shown), Some(_)) => shown
    _ => (name, None)
  }
  self.actors[id] = {
    box: assigned_box,
    name,
    description: text,
    wrap: wrap.unwrap_or(self.auto_wrap()),
    prev_actor: self.prev_actor,
    next_actor: None,
    links: Map([]),
    properties: Map([]),
    kind: kind.unwrap_or("participant"),
    actor_cnt: None,
    rect_data: None,
    x: @double.not_a_number,
    width: @double.not_a_number,
    height: @double.not_a_number,
    margin: @double.not_a_number,
    starty: @double.not_a_number,
    stopy: @double.not_a_number,
    text_height: None,
  }
  if self.prev_actor is Some(previous) &&
    self.actors.get(previous) is Some(previous) {
    previous.next_actor = Some(id)
  }
  if self.current_box is Some(box) {
    box.actor_keys.push(id)
  }
  self.prev_actor = Some(id)
}

///|
/// How many activations of `actor` are open after the entries so far.
fn SequenceDb::activation_count(self : SequenceDb, actor : String?) -> Int32 {
  guard actor is Some(actor) && actor != "" else { return 0 }
  let mut count = 0
  for message in self.messages {
    if message.from == Some(actor) {
      if message.kind == ACTIVE_START {
        count += 1
      }
      if message.kind == ACTIVE_END {
        count -= 1
      }
    }
  }
  count
}

///|
fn SequenceDb::add_signal(
  self : SequenceDb,
  from : String?,
  to : String?,
  message : Json,
  kind : Int32,
  activate~ : Bool = false,
  central_connection~ : Int32 = 0,
  placement? : Int32,
  sequence_start? : Double,
  sequence_step? : Double,
  sequence_visible~ : Bool = false,
) -> Unit raise {
  if kind == ACTIVE_END && self.activation_count(from) < 1 {
    raise SequenceError(
      "Trying to inactivate an inactive participant (\{from.unwrap_or("undefined")})",
    )
  }
  self.messages.push({
    id: self.messages.length(),
    from,
    to,
    message: text_field(message, "text").unwrap_or(""),
    wrap: match field(message, "wrap") {
      Null => self.auto_wrap()
      wrap => truthy(wrap)
    },
    kind,
    activate,
    central_connection,
    placement,
    sequence_start,
    sequence_step,
    sequence_visible,
    note_model: None,
    msg_model: None,
  })
}

///|
/// The keys of a JavaScript object in enumeration order: integer-like
/// keys ascending, then the others as inserted.
fn js_keys(object : Map[String, Json]) -> Array[String] {
  let integers : Array[(Double, String)] = []
  let others = []
  for key, _ in object {
    let is_index = key != "" &&
      key.iter().all(c => c is ('0'..<='9')) &&
      (key == "0" || !key.has_prefix("0")) &&
      key.length() <= 9
    if is_index {
      integers.push((@string.parse_double(key) catch { _ => 0.0 }, key))
    } else {
      others.push(key)
    }
  }
  integers.sort_by((a, b) => a.0.compare(b.0))
  integers.map(pair => pair.1) + others
}

///|
/// Merge the fields of a parsed JSON object into `target`, as a `for in`
/// loop over it would. Text that is not a JSON object is ignored, as
/// upstream only logs the error.
fn insert_json(target : Map[String, Json], text : String) -> Unit {
  let parsed = @json.parse(text) catch { _ => return }
  if parsed is Object(fields) {
    for key in js_keys(fields) {
      target[key] = fields[key]
    }
  }
}

///|
/// `links Alice: {"label": "url", ...}`.
fn SequenceDb::add_links(
  self : SequenceDb,
  actor : String,
  text : Json,
) -> Unit raise SequenceError {
  guard self.actors.get(actor) is Some(actor) else { return }
  let text = sanitize_text(text_field(text, "text").unwrap_or(""))
    .replace_all(old="&equals;", new="=")
    .replace_all(old="&amp;", new="&")
  insert_json(actor.links, text)
}

///|
/// `link Alice: label @ url`.
fn SequenceDb::add_a_link(
  self : SequenceDb,
  actor : String,
  text : Json,
) -> Unit raise SequenceError {
  guard self.actors.get(actor) is Some(actor) else { return }
  let sanitized = sanitize_text(text_field(text, "text").unwrap_or(""))
  // The separator is looked for before the entities are put back, and the
  // position is used after.
  let separator = match sanitized.find("@") {
    Some(index) => index
    None => -1
  }
  let text = sanitized
    .replace_all(old="&equals;", new="=")
    .replace_all(old="&amp;", new="&")
  let slice = (start : Int32, end : Int32) => {
    let length = text.length()
    let clamp = (index : Int32) => {
      let index = if index < 0 { length + index } else { index }
      index.max(0).min(length)
    }
    let (start, end) = (clamp(start), clamp(end))
    if start >= end {
      ""
    } else {
      text[start:end].to_owned()
    }
  }
  let label = js_trim(slice(0, separator - 1))
  let link = js_trim(slice(separator + 1, text.length()))
  actor.links[label] = Json::string(link)
}

///|
/// `properties Alice: {"class": "internal", ...}`.
fn SequenceDb::add_properties(
  self : SequenceDb,
  actor : String,
  text : Json,
) -> Unit raise SequenceError {
  guard self.actors.get(actor) is Some(actor) else { return }
  insert_json(
    actor.properties,
    sanitize_text(text_field(text, "text").unwrap_or("")),
  )
}

///|
/// Carry out what the grammar collected: a statement object, or a list of
/// them (`SequenceDB.apply`).
fn SequenceDb::apply(self : SequenceDb, param : Json) -> Unit raise {
  if param is Array(items) {
    for item in items {
      self.apply(item)
    }
    return
  }
  let text = (key : String) => text_field(param, key)
  let kind = match field(param, "signalType") {
    Number(n, ..) => n.to_int()
    _ => -1
  }
  match text("type") {
    Some("sequenceIndex") =>
      self.add_signal(
        None,
        None,
        Json::null(),
        kind,
        sequence_start?=number_field(param, "sequenceIndex"),
        sequence_step?=number_field(param, "sequenceIndexStep"),
        sequence_visible=truthy(field(param, "sequenceVisible")),
      )
    Some("addParticipant") =>
      self.add_actor(
        text("actor").unwrap_or(""),
        field(param, "description"),
        text("draw"),
        text("config"),
      )
    Some("createParticipant") => {
      let actor = text("actor").unwrap_or("")
      if self.actors.contains(actor) {
        raise SequenceError(
          "It is not possible to have actors with the same id, even if one is destroyed before the next is created. Use 'AS' aliases to simulate the behavior",
        )
      }
      self.last_created = Some(actor)
      self.add_actor(
        actor,
        field(param, "description"),
        text("draw"),
        text("config"),
      )
      self.created_actors[actor] = self.messages.length()
    }
    Some("destroyParticipant") => {
      let actor = text("actor").unwrap_or("")
      self.last_destroyed = Some(actor)
      self.destroyed_actors[actor] = self.messages.length()
    }
    Some(
      "activeStart"
      | "centralConnection"
      | "centralConnectionReverse"
      | "activeEnd"
    ) => self.add_signal(text("actor"), None, Json::null(), kind)
    Some("addNote") => {
      // One participant, or the two a note spans.
      let (from, to) = match field(param, "actor") {
        Array([String(from), String(to), ..]) => (from, to)
        String(actor) => (actor, actor)
        _ => ("", "")
      }
      let placement = match field(param, "placement") {
        Number(n, ..) => n.to_int()
        _ => OVER
      }
      self.add_signal(
        Some(from),
        Some(to),
        field(param, "text"),
        NOTE,
        placement~,
      )
    }
    Some("addLinks") =>
      self.add_links(text("actor").unwrap_or(""), field(param, "text"))
    Some("addALink") =>
      self.add_a_link(text("actor").unwrap_or(""), field(param, "text"))
    Some("addProperties") =>
      self.add_properties(text("actor").unwrap_or(""), field(param, "text"))
    // `details` reads an element of the host page, which has none.
    Some("addDetails") => ()
    Some("addMessage") => {
      let (from, to) = (text("from"), text("to"))
      if self.last_created is Some(created) {
        if to != Some(created) {
          raise SequenceError(
            "The created participant undefined does not have an associated creating message after its declaration. Please check the sequence diagram.",
          )
        }
        self.last_created = None
      } else if self.last_destroyed is Some(destroyed) {
        if to != Some(destroyed) && from != Some(destroyed) {
          raise SequenceError(
            "The destroyed participant undefined does not have an associated destroying message after its declaration. Please check the sequence diagram.",
          )
        }
        self.last_destroyed = None
      }
      self.add_signal(
        from,
        to,
        field(param, "msg"),
        kind,
        activate=truthy(field(param, "activate")),
        central_connection=match field(param, "centralConnection") {
          Number(n, ..) => n.to_int()
          _ => 0
        },
      )
    }
    Some("boxStart") => self.add_box(field(param, "boxData"))
    Some("boxEnd") => self.current_box = None
    Some("loopStart") =>
      self.add_signal(None, None, field(param, "loopText"), kind)
    Some("rectStart") =>
      self.add_signal(None, None, field(param, "color"), kind)
    Some("optStart") =>
      self.add_signal(None, None, field(param, "optText"), kind)
    Some("altStart" | "else") =>
      self.add_signal(None, None, field(param, "altText"), kind)
    Some("parStart" | "and") =>
      self.add_signal(None, None, field(param, "parText"), kind)
    Some("criticalStart") =>
      self.add_signal(None, None, field(param, "criticalText"), kind)
    Some("option") =>
      self.add_signal(None, None, field(param, "optionText"), kind)
    Some("breakStart") =>
      self.add_signal(None, None, field(param, "breakText"), kind)
    Some(
      "loopEnd"
      | "rectEnd"
      | "optEnd"
      | "altEnd"
      | "parEnd"
      | "criticalEnd"
      | "breakEnd"
    ) => self.add_signal(None, None, Json::null(), kind)
    _ => ()
  }
}

///|
fn number_field(value : Json, key : String) -> Double? {
  match field(value, key) {
    Number(n, ..) => Some(n)
    _ => None
  }
}
