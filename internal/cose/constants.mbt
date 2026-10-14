// The CoSE layout of compound graphs (Dogrusoz et al.), as mermaid runs it
// for mindmaps: cytoscape-cose-bilkent 4.1.0 over cose-base 1.0.3 and
// layout-base 1.0.2. A literal transcription: every sum, product and
// comparison is made in upstream's order, and every list is walked in
// upstream's order, so the positions are the same doubles.
//
// The constants are layout-base's `LayoutConstants` and `FDLayoutConstants`
// and cose-base's `CoSEConstants` after cytoscape-cose-bilkent's
// `getUserOptions` has written its defaults over them, with the two options
// mermaid sets: `quality: "proof"` and `animate: false`.

///|
/// The layout does not cover this graph, or cannot be exact for it.
pub(all) suberror Unsupported {
  Unsupported(String)
} derive(Eq, Debug)

///|
/// `Integer.MAX_VALUE` and `MIN_VALUE`, the library's infinities.
let integer_max : Double = 2147483647.0

///|
let integer_min : Double = -2147483648.0

///|
/// `DEFAULT_GRAPH_MARGIN`: what the bounds of a graph add around its nodes.
let graph_margin : Double = 15.0

///|
/// `EMPTY_COMPOUND_NODE_SIZE`.
let empty_compound_node_size : Double = 40.0

///|
/// `WORLD_BOUNDARY`: coordinates are clamped to it when transformed.
let world_boundary : Double = 1.0e6

///|
/// `WORLD_CENTER_X` and `WORLD_CENTER_Y`.
let world_center_x : Double = 1200.0

///|
let world_center_y : Double = 900.0

///|
/// `MAX_ITERATIONS` (the option `numIter`).
let max_iterations : Int32 = 2500

///|
/// `DEFAULT_EDGE_LENGTH` (the option `idealEdgeLength`).
let edge_length : Double = 50.0

///|
/// `DEFAULT_SPRING_STRENGTH` (the option `edgeElasticity`).
let spring_strength : Double = 0.45

///|
/// `DEFAULT_REPULSION_STRENGTH` (the option `nodeRepulsion`).
let repulsion_strength : Double = 4500.0

///|
/// `DEFAULT_GRAVITY_STRENGTH` (the option `gravity`).
let gravity_strength : Double = 0.25

///|
/// `DEFAULT_GRAVITY_RANGE_FACTOR` (the option `gravityRange`).
let gravity_range_factor : Double = 3.8

///|
/// `COOLING_ADAPTATION_FACTOR`, `ADAPTATION_LOWER_NODE_LIMIT` and
/// `ADAPTATION_UPPER_NODE_LIMIT`: graphs larger than the lower limit start
/// cooler.
let adaptation_lower_node_limit : Int32 = 1000

///|
/// `MAX_NODE_DISPLACEMENT`: three times the incremental one.
let max_node_displacement : Double = 100.0 * 3.0

///|
/// `MIN_REPULSION_DIST`: a tenth of the edge length the library is loaded
/// with.
let min_repulsion_dist : Double = 50.0 / 10.0

///|
/// `CONVERGENCE_CHECK_PERIOD`.
let convergence_check_period : Int32 = 100

///|
/// `GRID_CALCULATION_CHECK_PERIOD`.
let grid_calculation_check_period : Int32 = 10

///|
/// `DEFAULT_RADIAL_SEPARATION`, the edge length the library is loaded with,
/// and `DEFAULT_COMPONENT_SEPERATION`.
let radial_separation : Double = 50.0

///|
let component_separation : Double = 60.0

///|
/// The temperature the layout cools down to:
/// `CONVERGENCE_CHECK_PERIOD / maxIterations`, computed before the number
/// of iterations is raised for large graphs.
let final_temperature : Double = 100.0 / 2500.0

///|
/// The cooling factor after each cooling cycle of a layout that starts
/// at 1, as Chrome computes it:
///
///     Math.max(1 - Math.pow(cycle, Math.log(100 * (1 - 0.04)) / Math.log(25)) / 100, 0.04)
///
/// `Math.pow` and `Math.log` are not correctly rounded in V8 and are not
/// ported; the 25 values the schedule takes before it reaches the final
/// temperature are measured instead (`scripts/oracle.py --eval`).
let cooling_schedule : FixedArray[Double] = [
  0.99, 0.9732786204428374, 0.9525151236535068, 0.9285967874562051, 0.9020204102886729,
  0.8731138595920421, 0.8421137294634122, 0.8092007656016499, 0.774518651835825,
  0.738185019446856, 0.7002983789437909, 0.6609427281615525, 0.6201907491560341,
  0.5781061038126976, 0.5347451298077495, 0.4901581238425645, 0.4443903325565851,
  0.39748273126443445, 0.34947264538900424, 0.3003942530888285, 0.2502789966761161,
  0.19915592298601115, 0.14705196767651163, 0.09399219475887743, 0.04,
]

///|
/// `IMath.sign`.
fn sign(value : Double) -> Double {
  if value > 0.0 {
    1.0
  } else if value < 0.0 {
    -1.0
  } else {
    0.0
  }
}
