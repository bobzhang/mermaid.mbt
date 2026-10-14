///|
/// What separates the rows of a branch name: a backslash and `n`, a line
/// break, or `<br>`.
let row_break : @jsregex.Regex = try! @jsregex.Regex::compile(
  "\\\\n|\\n|<br\\s*/?>",
  flags="gi",
)

///|
/// What `String.prototype.trim` removes.
const JS_WHITESPACE : String = " \t\n\r\u{0b}\u{0c}\u{a0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200a}\u{2028}\u{2029}\u{202f}\u{205f}\u{3000}\u{feff}"

///|
/// A branch name as SVG text and the box `getBBox()` reports for it:
/// mermaid's `drawText`. Every row is a `<tspan>` one `em` below the
/// previous one, starting at x = 0.
fn branch_label(
  name : String,
  font : @font.Stack,
  size : Double,
) -> (@dom.Element, @dom.Rect) {
  let label = @dom.Element::new("text")
  let f = Float::from_double
  let em = f(1.0) * f(size)
  let mut baseline : Float = 0
  let mut edges : (Float, Float, Float, Float)? = None
  for row in row_break.split(name) {
    let row = row.trim(chars=JS_WHITESPACE).to_owned()
    label
    .append("tspan")
    .attr("xml:space", "preserve")
    .attr("dy", "1em")
    .attr("x", "0")
    .attr("class", "row")
    .text(row)
    |> ignore
    // An empty row lays out nothing, and its `dy` moves nothing.
    if row == "" {
      continue
    }
    baseline = baseline + em
    // Preserved white space keeps every space; a tab is one of them.
    let row = row.replace_all(old="\t", new=" ").replace_all(old="\r", new=" ")
    let box = font.bbox(row, size)
    let left = f(box.x)
    let top = baseline + f(box.y)
    let right = left + f(box.width)
    let bottom = top + f(box.height)
    edges = match edges {
      None => Some((left, top, right, bottom))
      Some((l, t, r, b)) =>
        Some(
          (
            if left < l {
              left
            } else {
              l
            },
            if top < t {
              top
            } else {
              t
            },
            if right > r {
              right
            } else {
              r
            },
            if bottom > b {
              bottom
            } else {
              b
            },
          ),
        )
    }
  }
  let box : @dom.Rect = match edges {
    Some((left, top, right, bottom)) =>
      {
        x: left.to_double(),
        y: top.to_double(),
        width: (right - left).to_double(),
        height: (bottom - top).to_double(),
      }
    None => { x: 0.0, y: 0.0, width: 0.0, height: 0.0, }
  }
  if box.width > 0.0 {
    label.set_text_box(box)
  }
  (label, box)
}
