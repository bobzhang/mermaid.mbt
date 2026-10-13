///|
/// A deep copy, so merges never alias the maps of their inputs.
fn clone(value : Json) -> Json {
  match value {
    Object(fields) => {
      let copy : Map[String, Json] = Map([])
      for key, item in fields {
        copy[key] = clone(item)
      }
      Json::object(copy)
    }
    Array(items) => Json::array(items.map(clone))
    other => other
  }
}

///|
/// Merge `src` into `dst` and return the result, following mermaid's
/// `assignWithDepth`: objects merge recursively down to `depth` levels and
/// are shallowly assigned below that; arrays gain the elements they lack;
/// an array merged into an object merges each of its elements in turn.
/// `Json::null()` plays the role of both `undefined` and `null`.
pub fn assign_with_depth(dst : Json, src : Json, depth~ : Int32 = 2) -> Json {
  match (dst, src) {
    (Array(target), Array(items)) => {
      let merged = target.copy()
      for item in items {
        if !merged.contains(item) {
          merged.push(clone(item))
        }
      }
      return Json::array(merged)
    }
    (_, Array(items)) => {
      let mut merged = dst
      for item in items {
        merged = assign_with_depth(merged, item, depth~)
      }
      return merged
    }
    _ => ()
  }
  if dst is Null || depth <= 0 {
    return match (dst, src) {
      (Object(target), Object(fields)) => {
        let merged = target.copy()
        for key, value in fields {
          merged[key] = clone(value)
        }
        Json::object(merged)
      }
      (Object(_) | Array(_), Null) => dst
      _ => clone(src)
    }
  }
  guard (dst, src) is (Object(target), Object(fields)) else { return dst }
  let merged = target.copy()
  for key, value in fields {
    let current = merged.get(key).unwrap_or(Json::null())
    match value {
      Null => ()
      Object(_) | Array(_) => {
        let current = match (current, value) {
          (Null, Array(_)) => Json::array([])
          (Null, _) => Json::object({})
          _ => current
        }
        if current is (Object(_) | Array(_)) {
          merged[key] = assign_with_depth(current, value, depth=depth - 1)
        }
      }
      _ => if !(current is (Object(_) | Array(_))) { merged[key] = value }
    }
  }
  Json::object(merged)
}
