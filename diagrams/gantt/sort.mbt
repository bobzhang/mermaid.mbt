// `Array.prototype.sort` as V8 runs it, for the cases where it shows: a
// task whose start is unknown compares equal to every other task, which
// is no ordering at all, and the result is whatever the algorithm makes of
// it.

///|
/// V8's sort for arrays of fewer than 64 elements. Up to 15 elements are
/// sorted by binary insertion alone; from 16 on it is TimSort, which
/// handles an array this short as a single run: the ascending or strictly
/// descending stretch the array starts with, then the remaining elements
/// inserted one by one by binary search. (The limit of 15 was measured in
/// Chrome by counting the comparisons spent on sorted arrays.)
/// `compare` is the comparison function's result, NaN counting as 0.
fn[T] v8_sort_small(items : Array[T], compare : (T, T) -> Double) -> Unit {
  let n = items.length()
  if n < 2 {
    return
  }
  let order = (a : T, b : T) => {
    let result = compare(a, b)
    if result.is_nan() {
      0.0
    } else {
      result
    }
  }
  let mut run = 1
  if n >= 16 {
    // The initial run.
    let descending = order(items[1], items[0]) < 0.0
    run = 2
    while run < n {
      let step = order(items[run], items[run - 1])
      if descending {
        if step >= 0.0 {
          break
        }
      } else if step < 0.0 {
        break
      }
      run += 1
    }
    if descending {
      let mut low = 0
      let mut high = run - 1
      while low < high {
        let held = items[low]
        items[low] = items[high]
        items[high] = held
        low += 1
        high -= 1
      }
    }
  }
  // Binary insertion of the rest.
  for start in run..<n {
    let pivot = items[start]
    let mut left = 0
    let mut right = start
    while left < right {
      let mid = left + (right - left) / 2
      if order(pivot, items[mid]) < 0.0 {
        right = mid
      } else {
        left = mid + 1
      }
    }
    let mut at = start
    while at > left {
      items[at] = items[at - 1]
      at -= 1
    }
    items[left] = pivot
  }
}

///|
/// A stable sort by a consistent ordering (a merge sort), which is all
/// any correct sort can produce for one.
fn[T] stable_sort(items : Array[T], compare : (T, T) -> Double) -> Unit {
  let n = items.length()
  if n < 2 {
    return
  }
  let mut source = items.copy()
  let mut target = items.copy()
  let mut width = 1
  while width < n {
    let mut low = 0
    while low < n {
      let mid = if low + width < n { low + width } else { n }
      let high = if low + 2 * width < n { low + 2 * width } else { n }
      let mut i = low
      let mut j = mid
      for k in low..<high {
        if i < mid && (j >= high || compare(source[j], source[i]) >= 0.0) {
          target[k] = source[i]
          i += 1
        } else {
          target[k] = source[j]
          j += 1
        }
      }
      low += 2 * width
    }
    let swap = source
    source = target
    target = swap
    width *= 2
  }
  for k in 0..<n {
    items[k] = source[k]
  }
}

///|
/// Sort tasks the way upstream's `sort` call does. `consistent` says
/// whether `compare` is a proper ordering of these tasks; when it is not,
/// only V8's own algorithm gives V8's result, and its merging of longer
/// arrays is not ported.
fn sort_tasks(
  tasks : Array[Task],
  compare : (Task, Task) -> Double,
  consistent~ : Bool,
) -> Unit raise GanttError {
  if tasks.length() < 64 {
    v8_sort_small(tasks, compare)
  } else if consistent {
    stable_sort(tasks, compare)
  } else {
    raise Unsupported(
      "64 tasks or more, some of them without a start time to sort by",
    )
  }
}
