///|
/// Why a tree view could not be parsed.
pub(all) suberror TreeViewError {
  TreeViewError(String)
} derive(Eq, Debug)

///|
/// A feature the port does not reproduce exactly.
pub(all) suberror Unsupported {
  Unsupported(String)
} derive(Eq, Debug)

///|
let blank_runs : @jsregex.Regex = regex("[\\t ]{2,}")

///|
/// Single-line `title`, `accTitle` and `accDescr` values: trimmed, with
/// runs of blanks collapsed.
fn single_line(text : String) -> String {
  blank_runs.replace_all(@journeycommon.js_trim(text), _ => " ")
}

///|
/// The common value converter reads `accTitle` and `accDescr` tokens again
/// with its own patterns.
let acc_title_pattern : @jsregex.Regex = regex("accTitle[\\t ]*:([^\\n\\r]*)")

///|
let acc_descr_pattern : @jsregex.Regex = regex(
  "accDescr(?:[\\t ]*:([^\\n\\r]*)|\\s*{([^}]*)})",
)

///|
fn multiline(source : String) -> @jsregex.Regex {
  try! @jsregex.Regex::compile(source, flags="gm")
}

///|
/// The value of an ACC_TITLE or ACC_DESCR token: one line, or the lines of
/// a `{ ... }` block without their indentation and blank lines.
fn metadata_value(pattern : @jsregex.Regex, token : String) -> String {
  guard pattern.exec(token) is Some(found) else { return "" }
  if found.group(1) is Some(line) {
    return single_line(line)
  }
  guard found.group(2) is Some(block) else { return "" }
  let block = multiline("^\\s*").replace_all(block, _ => "")
  let block = multiline("\\s+$").replace_all(block, _ => "")
  let block = blank_runs.replace_all(block, _ => " ")
  multiline("[\\n\\r]{2,}").replace_all(block, _ => "\n")
}

///|
/// Parse a tree view:
///
/// ```text
/// TreeView: "treeView-beta" (ACC_DESCR | ACC_TITLE | TITLE)* TreeNode*
/// TreeNode: INDENTATION? (QUOTED_NAME | BARE_NAME)
///           (CLASS_ANNOTATION | ICON_ANNOTATION | DESC_ANNOTATION)*
/// ```
pub fn parse(source : String) -> TreeView raise {
  let text = preprocess_box_drawing(source)
  let tokens = @langium.TokenStream::new(
    @langium.tokenize(text, token_types),
    text.length(),
  )
  let tree = TreeView::new()
  tokens.expect("treeView-beta") |> ignore
  while true {
    if tokens.accept("ACC_DESCR") is Some(token) {
      tree.acc_description = @journeycommon.acc_description(
        metadata_value(acc_descr_pattern, token.text),
      )
    } else if tokens.accept("ACC_TITLE") is Some(token) {
      tree.acc_title = @journeycommon.acc_title(
        metadata_value(acc_title_pattern, token.text),
      )
    } else if tokens.accept("TITLE") is None {
      // The renderer draws no title.
      break
    }
  }
  while !tokens.at("EOF") {
    let level = match tokens.accept("INDENTATION") {
      Some(indentation) => indentation.text.length()
      None => 0
    }
    let name = if tokens.accept("QUOTED_NAME") is Some(token) {
      token.text[1:token.text.length() - 1].to_owned()
    } else if tokens.accept("BARE_NAME") is Some(token) {
      // Blanks at the end are not part of the name; those inside are.
      regex("[\\t ]+$").replace(token.text, _ => "")
    } else {
      tokens.fail("Expecting a QUOTED_NAME or a BARE_NAME")
    }
    let mut css_class : String? = None
    let mut icon : String? = None
    let mut description : String? = None
    // Each annotation may be repeated; the last one counts.
    while true {
      if tokens.accept("CLASS_ANNOTATION") is Some(token) {
        let text = @journeycommon.js_trim(token.text)
        css_class = Some(@journeycommon.js_trim(text[3:].to_owned()))
      } else if tokens.accept("ICON_ANNOTATION") is Some(token) {
        let text = @journeycommon.js_trim(token.text)
        icon = Some(text[5:text.length() - 1].to_owned())
      } else if tokens.accept("DESC_ANNOTATION") is Some(token) {
        let text = @journeycommon.js_trim(token.text)
        description = Some(@journeycommon.js_trim(text[2:].to_owned()))
      } else {
        break
      }
    }
    // A trailing slash makes a directory.
    let (name, directory) = match name.strip_suffix("/") {
      Some(stem) => (stem.to_owned(), true)
      None => (name, false)
    }
    // `icon()` hides the icon, like `icon(none)`.
    let icon = icon.map(icon => if icon == "" { "none" } else { icon })
    // An empty class or description is as good as none.
    let css_class = css_class.filter(text => text != "")
    let description = match description {
      Some("") | None => None
      Some(text) =>
        Some(
          @journeycommon.sanitize_text(text) catch {
            @journeycommon.SanitizeError(message) => raise Unsupported(message)
          },
        )
    }
    tree.add_node(level, name, directory, css_class, icon, description)
  }
  tree
}
