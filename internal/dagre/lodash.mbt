// The pieces of lodash and of JavaScript itself the layout leans on, with
// the behaviour it depends on: which of several equal minima is taken,
// what an empty collection gives, how numbers that are not numbers compare.

///|
/// `_.uniqueId`'s counter, which lives as long as the page does.
let id_counter : Ref[Int32] = Ref(0)

///|
/// `_.uniqueId(prefix)`.
fn unique_id(prefix : String) -> String {
  id_counter.val += 1
  prefix + id_counter.val.to_string()
}

///|
/// `Math.max` of two numbers.
pub fn js_max(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a > b {
    a
  } else if b > a {
    b
  } else if a == 0.0 && 1.0 / a < 0.0 {
    // Of two zeros, the positive one.
    b
  } else {
    a
  }
}

///|
/// `Math.min` of two numbers.
pub fn js_min(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a < b {
    a
  } else if b < a {
    b
  } else if a == 0.0 && 1.0 / a < 0.0 {
    a
  } else {
    b
  }
}

///|
/// Whether a number is truthy: neither zero nor not a number.
fn truthy(value : Double) -> Bool {
  !(value == 0.0 || value.is_nan())
}

///|
/// `_.min` of numbers: the first of the smallest, none of an empty array
/// or of one that holds no number.
fn lodash_min(values : Array[Double]) -> Double? {
  let mut result : Double? = None
  for value in values {
    match result {
      None => if !value.is_nan() { result = Some(value) }
      Some(current) => if value < current { result = Some(value) }
    }
  }
  result
}

///|
/// `_.max` of numbers.
fn lodash_max(values : Array[Double]) -> Double? {
  let mut result : Double? = None
  for value in values {
    match result {
      None => if !value.is_nan() { result = Some(value) }
      Some(current) => if value > current { result = Some(value) }
    }
  }
  result
}

///|
/// `_.min` of integers, where `None` is a value that is undefined.
fn min_int(values : Array[Int32?]) -> Int32? {
  let mut result : Int32? = None
  for value in values {
    guard value is Some(value) else { continue }
    match result {
      None => result = Some(value)
      Some(current) => if value < current { result = Some(value) }
    }
  }
  result
}

///|
/// `_.max` of integers.
fn max_int(values : Array[Int32?]) -> Int32? {
  let mut result : Int32? = None
  for value in values {
    guard value is Some(value) else { continue }
    match result {
      None => result = Some(value)
      Some(current) => if value > current { result = Some(value) }
    }
  }
  result
}

///|
/// `_.range(start, end)` counting up, empty when `end` is not above
/// `start`.
fn range(start : Int32, end : Int32) -> Array[Int32] {
  let result = []
  for i in start..<end {
    result.push(i)
  }
  result
}

///|
/// lodash's `compareAscending` for numbers: one that is not a number
/// sorts after every other.
fn compare_ascending(a : Double, b : Double) -> Int32 {
  if a == b {
    0
  } else if a > b || a.is_nan() {
    1
  } else if a < b || b.is_nan() {
    -1
  } else {
    0
  }
}

///|
/// `_.sortBy(items, key)`: ascending by key, items with equal keys in the
/// order they came.
fn[T] sort_by(items : Array[T], key : (T) -> Double) -> Array[T] {
  let keyed = items.mapi((index, item) => (key(item), index, item))
  js_sort(keyed, (a, b) => {
    let order = compare_ascending(a.0, b.0)
    if order != 0 {
      order
    } else {
      a.1 - b.1
    }
  })
  keyed.map(entry => entry.2)
}

///|
/// `Array.prototype.sort` with a comparator, as V8 sorts short arrays: the
/// leading run is found (and reversed when strictly descending), the rest
/// is inserted by binary search. The sort is stable; V8 merges runs in
/// longer arrays, which gives the same result for a consistent comparator.
fn[T] js_sort(items : Array[T], compare : (T, T) -> Int32) -> Unit {
  let n = items.length()
  if n < 2 {
    return
  }
  let mut run = 2
  let descending = compare(items[1], items[0]) < 0
  let mut previous = items[1]
  for i in 2..<n {
    let current = items[i]
    let order = compare(current, previous)
    if descending {
      if !(order < 0) {
        break
      }
    } else if order < 0 {
      break
    }
    previous = current
    run += 1
  }
  if descending {
    let mut low = 0
    let mut high = run - 1
    while low < high {
      let t = items[low]
      items[low] = items[high]
      items[high] = t
      low += 1
      high -= 1
    }
  }
  for start in run..<n {
    let pivot = items[start]
    let mut left = 0
    let mut right = start
    while left < right {
      let mid = left + ((right - left) >> 1)
      if compare(pivot, items[mid]) < 0 {
        right = mid
      } else {
        left = mid + 1
      }
    }
    let mut p = start
    while p > left {
      items[p] = items[p - 1]
      p -= 1
    }
    items[left] = pivot
  }
}
