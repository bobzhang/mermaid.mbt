///|
/// Why a Gantt chart cannot be drawn: where upstream throws while it
/// parses a task or works out its dates.
pub(all) suberror GanttError {
  GanttError(String)
  /// Something upstream renders that the port does not reproduce.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// Where a task's start comes from.
priv enum RawStart {
  /// The end of the task written before it (none for the first task).
  PrevTaskEnd
  /// A date, or `after <ids>`.
  StartDate(String)
}

///|
/// One task of the chart. Dates are time values; `None` stands for
/// JavaScript's `undefined` (not worked out yet), NaN for an invalid date.
pub struct Task {
  section : String
  /// The task's name, as written (spaces before the colon included).
  task : String
  id : String
  priv prev_task_id : String?
  /// The start and end as written; `None` when the task data has no or
  /// too many fields, which upstream stumbles over when compiling.
  priv raw : (RawStart, String)?
  active : Bool
  done : Bool
  crit : Bool
  milestone : Bool
  /// A vertical marker rather than a bar.
  vert : Bool
  classes : Array[String]
  /// The row of the task: its position in the text, vertical markers not
  /// counting. Compact mode reassigns it.
  mut order : Int32
  mut processed : Bool
  /// Whether the end was written as a date (YYYY-MM-DD), which excluded
  /// days do not push back.
  mut manual_end_time : Bool
  mut start_time : Double?
  mut end_time : Double?
  /// Where the bar ends when excluded days extend the task: the end it
  /// would have had without the trailing excluded days.
  mut render_end_time : Double?
}

///|
/// The state the parser builds and the renderer reads: a port of
/// `ganttDb.js`.
pub struct GanttDb {
  priv zone : @jsdate.Zone
  mut date_format : String
  mut axis_format : String
  mut tick_interval : String?
  mut today_marker : String
  mut includes : Array[String]
  mut excludes : Array[String]
  mut title : String
  mut acc_title : String
  mut acc_description : String
  sections : Array[String]
  priv mut current_section : String
  mut inclusive_end_dates : Bool
  mut weekday : String
  priv mut weekend : String
  priv mut last_order : Int32
  priv mut task_count : Int32
  priv mut last_task_id : String?
  /// The tasks in the order of the text, until `compile` sorts them.
  tasks : Array[Task]
  /// Position in `tasks` by id.
  priv positions : Map[String, Int32]
  /// The link of each task that has one.
  links : Map[String, String]
}

///|
fn GanttDb::new() -> GanttDb {
  {
    zone: @jsdate.Zone::system(),
    date_format: "",
    axis_format: "",
    tick_interval: None,
    today_marker: "",
    includes: [],
    excludes: [],
    title: "",
    acc_title: "",
    acc_description: "",
    sections: [],
    current_section: "",
    inclusive_end_dates: false,
    weekday: "sunday",
    weekend: "saturday",
    last_order: 0,
    task_count: 0,
    last_task_id: None,
    tasks: [],
    positions: Map([]),
    links: Map([]),
  }
}

///|
/// JavaScript's `String.prototype.trim`.
fn js_trim(text : String) -> String {
  text
  .trim(
    chars=" \t\n\r\u{0b}\u{0c}\u{a0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200a}\u{2028}\u{2029}\u{202f}\u{205f}\u{3000}\u{feff}",
  )
  .to_owned()
}

///|
fn regex(source : String) -> @jsregex.Regex {
  @jsregex.Regex::compile(source) catch {
    _ => abort("invalid pattern \{source}")
  }
}

///|
let token_separator : @jsregex.Regex = regex("[\\s,]+")

///|
/// Add the words of an `includes` or `excludes` statement to a list,
/// lower-cased and without duplicates.
fn merge_tokens(existing : Array[String], text : String) -> Array[String] {
  let merged = existing.copy()
  for token in token_separator.split(text.to_lower()) {
    if token != "" && !merged.contains(token) {
      merged.push(token)
    }
  }
  merged
}

///|
fn GanttDb::add_section(self : GanttDb, text : String) -> Unit {
  self.current_section = text
  self.sections.push(text)
}

///|
/// The task with this id, the way upstream looks it up: in a plain object
/// keyed by id, which `__proto__` can never be a key of.
fn GanttDb::find_task(self : GanttDb, id : String) -> Task? {
  match self.positions.get(id) {
    Some(position) => Some(self.tasks[position])
    None => None
  }
}

///|
let tags : Array[(String, @jsregex.Regex)] = [
  "active", "done", "crit", "milestone", "vert",
].map(tag => (tag, regex("^\\s*\{tag}\\s*$")))

///|
/// A task statement: `text` is the task's name, `data` what follows it,
/// colon included.
fn GanttDb::add_task(
  self : GanttDb,
  text : String,
  data : String,
) -> Unit raise GanttError {
  let data = match data.strip_prefix(":") {
    Some(rest) => rest.to_owned()
    None => data
  }
  let fields = data.split(",").map(field => field.to_owned()).collect()
  // Leading fields that are tags, in any order.
  let found : Map[String, Bool] = Map([])
  let mut matched = true
  while matched {
    matched = false
    for entry in tags {
      let (tag, pattern) = entry
      // Upstream reads the first field without checking there is one.
      guard fields.get(0) is Some(first) else {
        raise GanttError(
          "Cannot read properties of undefined (reading 'match')",
        )
      }
      if pattern.matches(first) {
        found[tag] = true
        fields.remove(0) |> ignore
        matched = true
      }
    }
  }
  let fields = fields.map(js_trim)
  let mut id : String? = None
  let raw = match fields {
    [end] => {
      id = Some(self.next_id())
      Some((PrevTaskEnd, end))
    }
    [start, end] => {
      id = Some(self.next_id())
      Some((StartDate(start), end))
    }
    [name, start, end] => {
      id = Some(name)
      Some((StartDate(start), end))
    }
    _ => None
  }
  let vert = found.contains("vert")
  let order = if vert {
    -1
  } else {
    self.last_order += 1
    self.last_order - 1
  }
  // A task without an id is filed under "undefined".
  let id = id.unwrap_or("undefined")
  let task : Task = {
    section: self.current_section,
    task: text,
    id,
    prev_task_id: self.last_task_id,
    raw,
    active: found.contains("active"),
    done: found.contains("done"),
    crit: found.contains("crit"),
    milestone: found.contains("milestone"),
    vert,
    classes: [],
    order,
    processed: false,
    manual_end_time: false,
    start_time: None,
    end_time: None,
    render_end_time: None,
  }
  self.tasks.push(task)
  self.last_task_id = Some(id)
  if id != "__proto__" {
    self.positions[id] = self.tasks.length() - 1
  }
}

///|
fn GanttDb::next_id(self : GanttDb) -> String {
  self.task_count += 1
  "task\{self.task_count}"
}

///|
/// `click <ids> href "<link>"`: the tasks become clickable. The link
/// itself only shows in the output of the sandbox security level.
fn GanttDb::set_link(self : GanttDb, ids : String, link : String) -> Unit {
  for id in ids.split(",") {
    let id = id.to_owned()
    if self.find_task(id) is Some(_) {
      self.links[id] = link
    }
  }
  self.set_class(ids, "clickable")
}

///|
fn GanttDb::set_class(self : GanttDb, ids : String, name : String) -> Unit {
  for id in ids.split(",") {
    if self.find_task(id.to_owned()) is Some(task) {
      task.classes.push(name)
    }
  }
}
