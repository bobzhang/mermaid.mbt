///|
/// `Array.prototype.sort` with a comparator, as V8 sorts arrays shorter
/// than 64 elements: the leading run is found (and reversed when strictly
/// descending), the rest is inserted by binary search. The sort is stable,
/// and a comparator returning `NaN` counts as returning zero.
///
/// Longer arrays are sorted the same way. V8 merges runs there, which
/// gives the same result whenever the comparator is a consistent order.
pub fn[T] js_sort(items : Array[T], compare : (T, T) -> Double) -> Unit {
  let n = items.length()
  if n < 2 {
    return
  }
  // `CountAndMakeRun`
  let mut run = 2
  let descending = compare(items[1], items[0]) < 0.0
  let mut previous = items[1]
  for i in 2..<n {
    let current = items[i]
    let order = compare(current, previous)
    if descending {
      if !(order < 0.0) {
        break
      }
    } else if order < 0.0 {
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
  // `BinaryInsertionSort`
  for start in run..<n {
    let pivot = items[start]
    let mut left = 0
    let mut right = start
    while left < right {
      let mid = left + ((right - left) >> 1)
      if compare(pivot, items[mid]) < 0.0 {
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
