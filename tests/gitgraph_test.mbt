///|
test "gitgraph" {
  json_inspect(mismatches("gitgraph"), content=[])
}

///|
/// Commits without an `id:`, merges and cherry-picks get generated ids.
/// Their references are rendered with the port's id generator installed
/// as `Math.random` (see `oracle-prelude.js` in the directory).
test "gitgraph with generated ids" {
  json_inspect(mismatches("gitgraph/generated-ids"), content=[])
}
