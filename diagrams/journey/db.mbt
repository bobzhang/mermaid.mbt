///|
/// One step of a journey: what is done, how it felt and who took part.
pub struct Task {
  /// The section the task was declared under; empty before any section.
  section : String
  /// The task's description, exactly as written before the first colon.
  task : String
  /// The satisfaction score. Upstream reads it with `Number(..)`, so
  /// anything that is not a number is `NaN`.
  score : Double
  /// The actors, in the order written.
  people : Array[String]
}

///|
/// A parsed user journey.
pub struct Journey {
  mut title : String
  mut acc_title : String
  mut acc_description : String
  tasks : Array[Task]
  /// The section following statements belong to.
  priv mut current_section : String
}

///|
fn Journey::new() -> Journey {
  {
    title: "",
    acc_title: "",
    acc_description: "",
    tasks: [],
    current_section: "",
  }
}

///|
/// Use `title` as the diagram title, as a frontmatter `title` does.
pub fn Journey::set_title(self : Journey, title : String) -> Unit {
  self.title = title
}

///|
/// journeyDb's `addTask`: `data` is everything from the first colon on,
/// `: score` or `: score: actor, actor`.
fn Journey::add_task(
  self : Journey,
  description : String,
  data : String,
) -> Unit {
  let pieces = data[1:].split(":").map(piece => piece.to_owned()).collect()
  let score = js_number(pieces[0])
  // Pieces after the second are ignored, as upstream ignores them.
  let people = if pieces.length() == 1 {
    []
  } else {
    pieces[1].split(",").map(name => js_trim(name.to_owned())).collect()
  }
  self.tasks.push({
    section: self.current_section,
    task: description,
    score,
    people,
  })
}

///|
/// The distinct actors of the journey, sorted as JavaScript sorts strings
/// by default: by UTF-16 code unit.
pub fn Journey::actors(self : Journey) -> Array[String] {
  let unique = []
  for task in self.tasks {
    for person in task.people {
      if !unique.contains(person) {
        unique.push(person)
      }
    }
  }
  unique.sort_by(compare_code_units)
  unique
}

///|
fn compare_code_units(a : String, b : String) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let difference = a[i].to_int() - b[i].to_int()
    if difference != 0 {
      return difference
    }
  }
  a.length() - b.length()
}
