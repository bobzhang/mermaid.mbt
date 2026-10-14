// The property order of JavaScript objects. graphlib keeps its nodes and
// their neighbours as the properties of plain objects, so the order in
// which a graph lists them is the order `Object.keys` gives: the keys that
// are array indices first, in ascending numeric order, then the others in
// the order they were added. A layout that iterates over nodes inherits
// that order, and a diagram whose nodes are called `1`, `2`, `10` is laid
// out differently from one whose nodes are called `a`, `b`, `c`.

///|
/// The own enumerable string-keyed properties of a JavaScript object.
pub struct JsObject[V] {
  /// The properties whose keys are array indices.
  priv indices : Map[String, V]
  /// The other properties, in the order they were added.
  priv names : Map[String, V]
}

///|
pub fn[V] JsObject::new() -> JsObject[V] {
  { indices: Map([]), names: Map([]), }
}

///|
/// Whether `key` is an array index: the canonical decimal form of an
/// integer from 0 to 2^32 - 2.
fn is_array_index(key : String) -> Bool {
  let n = key.length()
  if n == 0 || n > 10 {
    return false
  }
  if n > 1 && key[0] == '0' {
    return false
  }
  let mut value = 0.0
  for unit in key {
    guard unit is ('0'..<='9') else { return false }
    value = value * 10.0 + (unit.to_int() - '0').to_double()
  }
  value <= 4294967294.0
}

///|
/// Canonical array indices in ascending numeric order: shorter first, then
/// by digits.
fn compare_indices(a : String, b : String) -> Int32 {
  if a.length() != b.length() {
    return a.length() - b.length()
  }
  compare_strings(a, b)
}

///|
/// The order of two strings as JavaScript's `<` has it: by UTF-16 code
/// units, a prefix before the longer string.
pub fn compare_strings(a : String, b : String) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let x = a[i].to_int()
    let y = b[i].to_int()
    if x != y {
      return x - y
    }
  }
  a.length() - b.length()
}

///|
fn[V] JsObject::part(self : JsObject[V], key : String) -> Map[String, V] {
  if is_array_index(key) {
    self.indices
  } else {
    self.names
  }
}

///|
pub fn[V] JsObject::get(self : JsObject[V], key : String) -> V? {
  self.part(key).get(key)
}

///|
pub fn[V] JsObject::contains(self : JsObject[V], key : String) -> Bool {
  self.part(key).contains(key)
}

///|
/// Set a property. One that exists keeps its place.
pub fn[V] JsObject::set(self : JsObject[V], key : String, value : V) -> Unit {
  self.part(key)[key] = value
}

///|
/// `delete object[key]`.
pub fn[V] JsObject::remove(self : JsObject[V], key : String) -> Unit {
  self.part(key).remove(key)
}

///|
pub fn[V] JsObject::length(self : JsObject[V]) -> Int32 {
  self.indices.length() + self.names.length()
}

///|
pub fn[V] JsObject::is_empty(self : JsObject[V]) -> Bool {
  self.length() == 0
}

///|
/// `Object.keys(object)`.
pub fn[V] JsObject::keys(self : JsObject[V]) -> Array[String] {
  let keys = []
  if !self.indices.is_empty() {
    for key, _ in self.indices {
      keys.push(key)
    }
    keys.sort_by(compare_indices)
  }
  for key, _ in self.names {
    keys.push(key)
  }
  keys
}

///|
/// `Object.values(object)`.
pub fn[V] JsObject::values(self : JsObject[V]) -> Array[V] {
  let values = []
  if !self.indices.is_empty() {
    for key in self.keys() {
      if self.get(key) is Some(value) {
        values.push(value)
      }
    }
    return values
  }
  for _, value in self.names {
    values.push(value)
  }
  values
}
