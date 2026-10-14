///|
/// A time period and what happened in it.
pub struct Task {
  /// The section the period was declared under; empty before any section.
  section : String
  /// The period's text, exactly as written before the first colon.
  task : String
  events : Array[String]
}

///|
/// A parsed timeline.
pub struct Timeline {
  mut title : String
  /// `LR` for a timeline running left to right, `TD` for top down.
  mut direction : String
  /// The sections in the order declared; a name may repeat.
  sections : Array[String]
  tasks : Array[Task]
  /// The section following periods belong to.
  priv mut current_section : String
}

///|
/// An event without a period to belong to.
pub(all) suberror TimelineError {
  TimelineError(String)
} derive(Eq, Debug)

///|
fn Timeline::new() -> Timeline {
  { title: "", direction: "LR", sections: [], tasks: [], current_section: "", }
}
