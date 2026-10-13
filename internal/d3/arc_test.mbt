// Expected values are taken from mermaid's rendering of a pie chart with
// slices 386, 85 and 15.

///|
test "pie slices as arc paths" {
  let arcs = @d3.pie([386.0, 85.0, 15.0])
  let paths = arcs.map(arc => {
    @d3.arc_path(
      inner_radius=0.0,
      outer_radius=185.0,
      start_angle=arc.start_angle,
      end_angle=arc.end_angle,
    )
  })
  inspect(
    paths.join("\n"),
    content=(
      #|M0,-185A185,185,0,1,1,-177.899,-50.763L0,0Z
      #|M-177.899,-50.763A185,185,0,0,1,-35.652,-181.532L0,0Z
      #|M-35.652,-181.532A185,185,0,0,1,0,-185L0,0Z
    ),
  )
}

///|
test "arc centroids keep full precision" {
  let arcs = @d3.pie([386.0, 85.0, 15.0])
  let centroids = arcs.map(arc => {
    let (x, y) = @d3.arc_centroid(
      inner_radius=138.75,
      outer_radius=138.75,
      start_angle=arc.start_angle,
      end_angle=arc.end_angle,
    )
    "\{@d3.number(x)},\{@d3.number(y)}"
  })
  inspect(
    centroids.join("\n"),
    content=(
      #|83.57344705444068,110.75667676234512
      #|-93.90333582091016,-102.14561185731559
      #|-13.432508310066218,-138.09826291630174
    ),
  )
}

///|
test "degenerate arcs" {
  // A full circle is two half arcs; a donut adds the inner ring.
  inspect(
    @d3.arc_path(
      inner_radius=0.0,
      outer_radius=10.0,
      start_angle=0.0,
      end_angle=6.283185307179586,
    ),
    content="M0,-10A10,10,0,1,1,0,10A10,10,0,1,1,0,-10Z",
  )
  inspect(
    @d3.arc_path(
      inner_radius=5.0,
      outer_radius=10.0,
      start_angle=0.0,
      end_angle=1.5707963267948966,
    ),
    content="M0,-10A10,10,0,0,1,10,0L5,0A5,5,0,0,0,0,-5Z",
  )
  inspect(@d3.js_round(2.5), content="3")
  inspect(@d3.js_round(-2.5), content="-2")
  inspect(@d3.js_round(0.49999999999999994), content="0")
}
