// venn.js keeps its circles in plain JavaScript objects keyed by set
// name, and walks them with `Object.keys` and `for ... in`. The order of
// those walks decides the order of the coordinates the optimiser works
// on, so it is reproduced here: keys that are array indices come first,
// in numeric order, then the others in the order they were first set.

///|
/// A JavaScript object used as a dictionary.
priv struct Dict[V] {
  /// The keys in the order they were first set.
  inserted : Array[String]
  values : Map[String, V]
}

///|
fn[V] Dict::new() -> Dict[V] {
  { inserted: [], values: Map([]), }
}

///|
/// `object[key] = value`
fn[V] Dict::set(self : Dict[V], key : String, value : V) -> Unit {
  if !self.values.contains(key) {
    self.inserted.push(key)
  }
  self.values[key] = value
}

///|
/// `object[key]`
fn[V] Dict::get(self : Dict[V], key : String) -> V? {
  self.values.get(key)
}

///|
/// The number a key stands for when it is an array index: a canonical
/// decimal integer below 2^32 - 1.
fn array_index(key : String) -> Double? {
  if key == "" || key.length() > 10 {
    return None
  }
  if key.length() > 1 && key.code_unit_at(0) == '0' {
    return None
  }
  let mut value = 0.0
  for c in key {
    guard c is ('0'..<='9') else { return None }
    value = value * 10.0 + (c.to_int() - '0').to_double()
  }
  if value < 4294967295.0 {
    Some(value)
  } else {
    None
  }
}

///|
/// `Object.keys(object)`
fn[V] Dict::keys(self : Dict[V]) -> Array[String] {
  let indices : Array[(Double, String)] = []
  let names = []
  for key in self.inserted {
    match array_index(key) {
      Some(index) => indices.push((index, key))
      None => names.push(key)
    }
  }
  indices.sort_by((a, b) => a.0.compare(b.0))
  let keys = indices.map(entry => entry.1)
  keys.append(names)
  keys
}

///|
/// The names every JavaScript object inherits. venn.js asks `name in
/// object` of objects keyed by set name, which these names answer for
/// sets that are not there; the port refuses them instead.
let inherited_names : Array[String] = [
  "constructor", "hasOwnProperty", "isPrototypeOf", "propertyIsEnumerable", "toLocaleString",
  "toString", "valueOf", "__proto__", "__defineGetter__", "__defineSetter__", "__lookupGetter__",
  "__lookupSetter__",
]
