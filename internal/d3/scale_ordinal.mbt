///|
/// d3-scale-chromatic's `schemeTableau10`.
pub let scheme_tableau10 : Array[String] = [
  "#4e79a7", "#f28e2c", "#e15759", "#76b7b2", "#59a14f", "#edc949", "#af7aa1", "#ff9da7",
  "#9c755f", "#bab0ab",
]

///|
/// A port of d3-scale's `scaleOrdinal` with an implicit domain: every key
/// asked for the first time joins the domain and takes the next value of
/// the range, cycling.
pub struct Ordinal[T] {
  priv index : Map[String, Int32]
  priv range : Array[T]
}

///|
/// `scaleOrdinal(range)`.
pub fn[T] Ordinal::new(range : Array[T]) -> Ordinal[T] {
  { index: Map([]), range, }
}

///|
/// `scaleOrdinal().domain(domain).range(range)`: the keys of `domain` take
/// the first values, in order; a repeated key keeps its first place.
pub fn[T] Ordinal::with_domain(
  domain : Array[String],
  range : Array[T],
) -> Ordinal[T] {
  let index : Map[String, Int32] = Map([])
  for key in domain {
    if !index.contains(key) {
      index[key] = index.length()
    }
  }
  { index, range, }
}

///|
/// The value for `key`. The range must not be empty.
pub fn[T] Ordinal::get(self : Ordinal[T], key : String) -> T {
  let i = match self.index.get(key) {
    Some(i) => i
    None => {
      let i = self.index.length()
      self.index[key] = i
      i
    }
  }
  self.range[i % self.range.length()]
}
