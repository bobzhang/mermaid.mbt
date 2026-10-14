///|
/// Remove the first child of `self` if it is text, and return the text:
/// what is left of moving that node elsewhere with `insertBefore` or
/// `appendChild`.
pub fn Element::take_first_text(self : Element) -> String? {
  guard self.children is [Text(text), ..] else { return None }
  ignore(self.children.remove(0))
  Some(text)
}
