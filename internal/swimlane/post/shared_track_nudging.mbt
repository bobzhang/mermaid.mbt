// `swimlanes/direction/sharedTrackNudging.ts`: routes that run along each
// other too closely are moved apart.

///|
/// How long two segments must run side by side to count as sharing a track.
const NUDGE_MIN_SHARED : Double = 8.0

///|
/// The step a segment moves by, and the gap that counts as crowded.
const TRACK_SHIFT : Double = 7.0

///|
/// How far from its source a rerouted route turns onto the new track.
const SOURCE_DETOUR_STUB : Double = 20.0

///|
/// How much the boxes of nodes and labels shrink when testing hits.
const NUDGE_BUFFER : Double = 2.0

///|
/// The passes over all pairs of segments.
const NUDGE_MAX_ITERATIONS : Int32 = 12

///|
/// The shifts tried in turn.
let nudge_shifts : Array[Double] = [
  -TRACK_SHIFT,
  TRACK_SHIFT,
  -2.0 * TRACK_SHIFT,
  2.0 * TRACK_SHIFT,
  -3.0 * TRACK_SHIFT,
  3.0 * TRACK_SHIFT,
]

///|
/// A segment of a route with its edge, and whether it is neither the
/// first nor the last segment.
priv struct TrackSeg {
  seg : @model.Seg
  edge : @model.Edge
  interior : Bool
}

///|
/// `segmentsFor`.
fn track_segments_for(
  edge : @model.Edge,
  points : Array[@model.Pt],
) -> Array[TrackSeg] {
  @model.orthogonal_segments_for_points(points).map(seg => {
    seg,
    edge,
    interior: seg.index >= 1 && seg.index <= points.length() - 3,
  })
}

///|
/// Whether two parallel segments share at least `NUDGE_MIN_SHARED` of
/// their extent less than `TRACK_SHIFT` apart.
fn has_crowded_parallel_track(a : @model.Seg, b : @model.Seg) -> Bool {
  if a.horizontal && b.horizontal {
    return @model.overlap_length(a.a.x, a.b.x, b.a.x, b.b.x) >= NUDGE_MIN_SHARED &&
      (a.a.y - b.a.y).abs() < TRACK_SHIFT
  }
  if a.vertical && b.vertical {
    return @model.overlap_length(a.a.y, a.b.y, b.a.y, b.b.y) >= NUDGE_MIN_SHARED &&
      (a.a.x - b.a.x).abs() < TRACK_SHIFT
  }
  false
}

///|
/// The route with the segment moved across by `shift`, when it stays
/// orthogonal: `shiftedCandidate`.
fn shifted_candidate(segment : TrackSeg, shift : Double) -> Array[@model.Pt]? {
  let points = @model.dedupe_consecutive_points(
    segment.edge.points.unwrap_or([]),
  )
  if points.length() < 4 || segment.seg.index >= points.length() - 1 {
    return None
  }
  let candidate = points.map(p => p.copy())
  let index = segment.seg.index
  if segment.seg.horizontal {
    candidate[index].y += shift
    candidate[index + 1].y += shift
  } else if segment.seg.vertical {
    candidate[index].x += shift
    candidate[index + 1].x += shift
  } else {
    return None
  }
  if track_segments_for(segment.edge, candidate).length() ==
    candidate.length() - 1 {
    Some(candidate)
  } else {
    None
  }
}

///|
/// The centre of a node, that of its box when it has none: `nodeCenter`.
fn node_center(node : @model.Node, rect : @model.Rect) -> @model.Pt {
  @model.pt(
    node.x.unwrap_or((rect.left + rect.right) / 2.0),
    node.y.unwrap_or((rect.top + rect.bottom) / 2.0),
  )
}

///|
/// What rerouting the second segment of a four-point route needs:
/// `sourceDetourContextFor`.
priv struct SourceDetourContext {
  source_center : @model.Pt
  target_center : @model.Pt
  source_rect : @model.Rect
  tail : Array[@model.Pt]
}

///|
fn source_detour_context_for(
  segment : TrackSeg,
  node_by_id : Map[String, @model.Node],
) -> SourceDetourContext? {
  let edge = segment.edge
  let points = @model.dedupe_consecutive_points(edge.points.unwrap_or([]))
  if points.length() != 4 || segment.seg.index != 1 {
    return None
  }
  let source_node = if edge.start != "" {
    node_by_id.get(edge.start)
  } else {
    None
  }
  let target_node = if edge.end != "" { node_by_id.get(edge.end) } else { None }
  let source_rect = source_node.bind(@model.rect_of_node_bounds)
  let target_rect = target_node.bind(@model.rect_of_node_bounds)
  let tail = points[segment.seg.index + 2:].to_owned()
  guard source_node is Some(source_node) &&
    target_node is Some(target_node) &&
    source_rect is Some(source_rect) &&
    target_rect is Some(target_rect) &&
    tail.length() != 0 else {
    return None
  }
  Some({
    source_center: node_center(source_node, source_rect),
    target_center: node_center(target_node, target_rect),
    source_rect,
    tail,
  })
}

///|
/// Leave the source straight towards the target for `SOURCE_DETOUR_STUB`,
/// then run the vertical segment `shift` aside: `verticalSourceDetour`.
fn vertical_source_detour(
  segment : TrackSeg,
  shift : Double,
  context : SourceDetourContext,
) -> Array[@model.Pt]? {
  let source_center = context.source_center
  let target_below = context.target_center.y >= source_center.y
  let source_port_y = if target_below {
    context.source_rect.bottom
  } else {
    context.source_rect.top
  }
  let stub_y = source_port_y +
    (if target_below { SOURCE_DETOUR_STUB } else { -SOURCE_DETOUR_STUB })
  if (target_below && segment.seg.b.y <= stub_y + @model.EPS) ||
    (!target_below && segment.seg.b.y >= stub_y - @model.EPS) {
    return None
  }
  let rail_x = segment.seg.a.x + shift
  Some(
    @model.dedupe_consecutive_points(
      [
        @model.pt(source_center.x, source_port_y),
        @model.pt(source_center.x, stub_y),
        @model.pt(rail_x, stub_y),
        @model.pt(rail_x, segment.seg.b.y),
        ..context.tail,
      ],
    ),
  )
}

///|
/// The same with a horizontal segment: `horizontalSourceDetour`.
fn horizontal_source_detour(
  segment : TrackSeg,
  shift : Double,
  context : SourceDetourContext,
) -> Array[@model.Pt]? {
  let source_center = context.source_center
  let target_right = context.target_center.x >= source_center.x
  let source_port_x = if target_right {
    context.source_rect.right
  } else {
    context.source_rect.left
  }
  let stub_x = source_port_x +
    (if target_right { SOURCE_DETOUR_STUB } else { -SOURCE_DETOUR_STUB })
  if (target_right && segment.seg.b.x <= stub_x + @model.EPS) ||
    (!target_right && segment.seg.b.x >= stub_x - @model.EPS) {
    return None
  }
  let rail_y = segment.seg.a.y + shift
  Some(
    @model.dedupe_consecutive_points(
      [
        @model.pt(source_port_x, source_center.y),
        @model.pt(stub_x, source_center.y),
        @model.pt(stub_x, rail_y),
        @model.pt(segment.seg.b.x, rail_y),
        ..context.tail,
      ],
    ),
  )
}

///|
/// `sourceDetourCandidate`.
fn source_detour_candidate(
  segment : TrackSeg,
  shift : Double,
  node_by_id : Map[String, @model.Node],
) -> Array[@model.Pt]? {
  guard source_detour_context_for(segment, node_by_id) is Some(context) else {
    return None
  }
  if segment.seg.vertical {
    return vertical_source_detour(segment, shift, context)
  }
  if segment.seg.horizontal {
    return horizontal_source_detour(segment, shift, context)
  }
  None
}

///|
/// `nudgeSharedInteriorSubpaths`: while two routes share a track, move an
/// interior segment of one of them aside (or reroute it from its source)
/// to where it hits no node or label, crowds no route and crosses none;
/// one move per pass, up to `NUDGE_MAX_ITERATIONS` passes.
pub fn nudge_shared_interior_subpaths(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
) -> Unit {
  let (real_node_rects, label_rects) = @model.collect_node_rect_entries(
    node_by_id.values(),
  )
  let all_segments = () => {
    let result = []
    for edge in edges {
      if edge.is_layout_only {
        continue
      }
      guard edge.points is Some(points) && points.length() >= 2 else {
        continue
      }
      result.push_iter(
        track_segments_for(edge, @model.dedupe_consecutive_points(points)).iter(),
      )
    }
    result
  }
  let candidate_is_safe = (edge : @model.Edge, candidate : Array[@model.Pt]) => {
    let source_id = edge.start
    let target_id = edge.end
    let candidate_segments = track_segments_for(edge, candidate)
    if candidate_segments.length() != candidate.length() - 1 {
      return false
    }
    let endpoint_ids = [source_id, target_id].filter(id => id != "")
    let own_label_ids = match edge.label_node_id {
      Some(id) if id != "" => [id]
      _ => []
    }
    for segment in candidate_segments {
      if @model.segment_hits_any_rect(
          segment.seg.a,
          segment.seg.b,
          real_node_rects,
          exclude_ids=endpoint_ids,
          shrink=-NUDGE_BUFFER,
        ) {
        return false
      }
      if @model.segment_hits_any_rect(
          segment.seg.a,
          segment.seg.b,
          label_rects,
          exclude_ids=own_label_ids,
          shrink=-NUDGE_BUFFER,
        ) {
        return false
      }
    }
    for other in edges {
      if physical_equal(other, edge) || other.is_layout_only {
        continue
      }
      guard other.points is Some(other_points) && other_points.length() >= 2 else {
        continue
      }
      for candidate_segment in candidate_segments {
        for
          other_segment in track_segments_for(
            other,
            @model.dedupe_consecutive_points(other_points),
          ) {
          if has_crowded_parallel_track(
              candidate_segment.seg,
              other_segment.seg,
            ) {
            return false
          }
          if @model.orthogonal_segments_strictly_cross(
              candidate_segment.seg.a,
              candidate_segment.seg.b,
              other_segment.seg.a,
              other_segment.seg.b,
            ) {
            return false
          }
        }
      }
    }
    true
  }
  for _iteration in 0..<NUDGE_MAX_ITERATIONS {
    let segments = all_segments()
    let mut fixed = false
    let mut i = 0
    while i < segments.length() && !fixed {
      let mut j = i + 1
      while j < segments.length() && !fixed {
        let first = segments[i]
        let second = segments[j]
        j += 1
        if physical_equal(first.edge, second.edge) ||
          !has_crowded_parallel_track(first.seg, second.seg) {
          continue
        }
        let candidates = [first, second].filter(segment => segment.interior)
        for segment in candidates {
          for shift in nudge_shifts {
            if shifted_candidate(segment, shift) is Some(direct) &&
              candidate_is_safe(segment.edge, direct) {
              segment.edge.points = Some(direct)
              fixed = true
              break
            }
            if source_detour_candidate(segment, shift, node_by_id)
              is Some(detoured) &&
              candidate_is_safe(segment.edge, detoured) {
              segment.edge.points = Some(detoured)
              fixed = true
              break
            }
          }
          if fixed {
            break
          }
        }
      }
      i += 1
    }
    if !fixed {
      return
    }
  }
}
