///|
/// The renderer's `PathBuilder`: path data with every number written as
/// JavaScript writes it, a blank after each.
priv struct PathBuilder {
  data : StringBuilder
}

///|
fn PathBuilder::new() -> PathBuilder {
  { data: StringBuilder(), }
}

///|
fn PathBuilder::move_to(
  self : PathBuilder,
  x : Double,
  y : Double,
) -> PathBuilder {
  let n = @dom.number
  self.data.write_string("M \{n(x)} \{n(y)} ")
  self
}

///|
fn PathBuilder::line_to(
  self : PathBuilder,
  x : Double,
  y : Double,
) -> PathBuilder {
  let n = @dom.number
  self.data.write_string("L \{n(x)} \{n(y)} ")
  self
}

///|
/// A quarter of a circle of `radius` to `x`, `y`, clockwise when `sweep`.
fn PathBuilder::arc_to(
  self : PathBuilder,
  radius : Double,
  sweep : Bool,
  x : Double,
  y : Double,
) -> PathBuilder {
  let n = @dom.number
  let r = n(radius)
  let sweep = if sweep { 1 } else { 0 }
  self.data.write_string("A \{r} \{r} 0 0 \{sweep} \{n(x)} \{n(y)} ")
  self
}

///|
/// The path data, without the blank at its end.
fn PathBuilder::build(self : PathBuilder) -> String {
  self.data.to_string().trim_end(chars=" ").to_owned()
}
