// Tree views drawn with box-drawing characters (`├──`, `└──`, `│`, or the
// heavy `┣━━`, `┗━━`, `┃`) are rewritten into the indentation-based form
// the grammar reads. A port of `boxDrawingPreprocessor.ts`.

///|
fn regex(source : String) -> @jsregex.Regex {
  try! @jsregex.Regex::compile(source)
}

///|
let all_box_chars : @jsregex.Regex = regex("[─━│┃└┗├┣]")

///|
let branch_char : @jsregex.Regex = regex("[└┗├┣]")

///|
let decoration_only : @jsregex.Regex = regex("^[\\s│┃]+$")

///|
let metadata_line : @jsregex.Regex = regex(
  "^\\s*(title[\\t ]|accTitle[\\t ]*:|accDescr[\\t ]*[:{])",
)

///|
let comment_line : @jsregex.Regex = regex("^\\s*%%")

///|
let box_and_space_only : @jsregex.Regex = regex(
  "^[\\s─━│┃└┗├┣]+$",
)

///|
let leading_space : @jsregex.Regex = regex("^\\s+")

///|
let trailing_space : @jsregex.Regex = regex("\\s+$")

///|
/// Spaces per depth level in the rewritten text.
const INDENT_UNIT : String = "    "

///|
/// Tabs count as four columns, so that depth can be read off the column of
/// the branch character.
fn expand_tabs(line : String) -> String {
  line.replace_all(old="\t", new="    ")
}

///|
/// The text with box-drawing prefixes turned into indentation, or the text
/// itself when it does not use them.
///
/// Upstream also keeps a map from rewritten to original line numbers, to
/// correct the positions in the grammar's error messages; the port's
/// messages carry no line numbers, so it is not kept here.
fn preprocess_box_drawing(input : String) -> String raise TreeViewError {
  let lines : Array[String] = input.split("\n").map(l => l.to_owned()).collect()
  let mut keyword_index = -1
  for i, line in lines {
    if @journeycommon.js_trim(line) == "treeView-beta" {
      keyword_index = i
      break
    }
  }
  if keyword_index == -1 {
    return input
  }
  let passes_through = (line : String) => {
    @journeycommon.js_trim(line) == "" ||
    comment_line.matches(line) ||
    metadata_line.matches(line)
  }
  // The lines that hold nodes decide whether this is the box-drawing form
  // and how many columns one level takes.
  let content : Array[String] = []
  for i in (keyword_index + 1)..<lines.length() {
    let line = lines[i]
    if passes_through(line) || decoration_only.matches(line) {
      continue
    }
    content.push(expand_tabs(line))
  }
  if !content.iter().any(line => all_box_chars.matches(line)) {
    return input
  }
  // The first branch character away from the margin gives the width of a
  // level; four columns when every branch is at the margin.
  let mut segment_width = 4
  for line in content {
    if branch_char.exec(line) is Some(found) && found.start > 0 {
      segment_width = found.start
      break
    }
  }
  let output : Array[String] = []
  for i in 0..<=keyword_index {
    output.push(lines[i])
  }
  for i in (keyword_index + 1)..<lines.length() {
    let line = lines[i]
    if passes_through(line) {
      output.push(line)
      continue
    }
    if decoration_only.matches(line) {
      continue
    }
    let normalized = expand_tabs(line)
    if branch_char.exec(normalized) is Some(branch) {
      // `Math.round` of the column over the level width.
      let depth = (branch.start.to_double() / segment_width.to_double() + 0.5)
        .floor()
        .to_int() +
        1
      let n = normalized.length()
      let mut position = branch.start + 1
      while position < n && normalized[position] is ('─' | '━') {
        position += 1
      }
      while position < n && normalized[position] == ' ' {
        position += 1
      }
      let content = trailing_space.replace(normalized[position:].to_owned(), _ => {
        ""
      })
      if content == "" {
        raise TreeViewError(
          "Line \{i + 1}: Empty node — expected a filename or directory name after the box-drawing prefix",
        )
      }
      output.push(INDENT_UNIT.repeat(depth) + content)
    } else if box_and_space_only.matches(normalized) {
      continue
    } else if all_box_chars.matches(normalized) {
      // A box character inside a name (`Section ─ A.txt`): a root item.
      output.push(line)
    } else if leading_space.matches(normalized) {
      raise TreeViewError(
        "Line \{i + 1}: Unexpected indentation without box-drawing characters. " +
        "In box-drawing format, use ├── or └── prefixes for indented nodes.",
      )
    } else {
      output.push(line)
    }
  }
  output.join("\n")
}
