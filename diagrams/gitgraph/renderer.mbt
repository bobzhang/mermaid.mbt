///|
const LAYOUT_OFFSET : Double = 10.0

///|
const COMMIT_STEP : Double = 40.0

///|
const PX : Double = 4.0

///|
const PY : Double = 2.0

///|
/// The number of branch color classes the classic themes cycle through.
const THEME_COLOR_LIMIT : Int32 = 8

///|
const REDUX_BRANCH_LABEL_PADDING_Y : Double = 12.0

///|
/// Where the first commit of a vertical graph sits.
const DEFAULT_POS : Double = 30.0

///|
/// The color class of branch number `raw_index`. The color themes keep
/// class 0 for the main branch and cycle the others through the rest.
fn color_index(
  raw_index : Int32,
  limit : Int32,
  avoid_default : Bool,
) -> String {
  if avoid_default && raw_index > 0 {
    // Upstream computes with numbers: a limit of 1 divides by zero.
    if limit == 1 {
      return "NaN"
    }
    return ((raw_index - 1) % (limit - 1) + 1).to_string()
  }
  if limit == 0 {
    return "NaN"
  }
  (raw_index % limit).to_string()
}

///|
priv struct Point {
  x : Double
  y : Double
}

///|
/// Where a commit is drawn: `along` is its position on the axis commits
/// advance on, which is `x` in a horizontal graph and `y` in a vertical
/// one.
priv struct CommitPosition {
  x : Double
  y : Double
  along : Double
}

///|
/// The state of one rendering: mermaid's `gitGraphRenderer.ts` keeps it in
/// module variables.
priv struct Renderer {
  graph : GitGraph
  config : @config.Config
  id : String
  theme_name : String
  dir : String
  /// The position and index of every branch, by name.
  branch_pos : Map[String, (Double, Int32)]
  commit_pos : Map[String, Point]
  /// Coordinates already taken by branch lines and rerouted arrows.
  lanes : Array[Double]
  mut max_pos : Double
  /// The family the `<svg>` element sets, which all text inherits.
  family : String
  /// The font size of the `<svg>` element: that of branch labels.
  font_size : Double
  commit_label_size : Double
  tag_label_size : Double
}

///|
fn Renderer::vertical(self : Renderer) -> Bool {
  self.dir is ("TB" | "BT")
}

///|
fn Renderer::setting(self : Renderer, name : String) -> Bool {
  self.config.flag("gitGraph.\{name}")
}

///|
fn Renderer::font(self : Renderer, bold~ : Bool = false) -> @font.Stack {
  @font.Stack::for_family(self.family, bold~)
}

///|
/// The weight the neo and redux themes give commit labels, and the redux
/// themes branch labels.
fn Renderer::note_weight_is_bold(self : Renderer) -> Bool {
  is_bold_weight(self.config.theme().get("noteFontWeight"))
}

///|
fn Renderer::branch(
  self : Renderer,
  name : String,
) -> (Double, Int32) raise GitError {
  match self.branch_pos.get(name) {
    Some(position) => position
    None => raise GitError("Position not found for branch \{name}")
  }
}
