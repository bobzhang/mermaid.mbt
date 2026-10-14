// `swimlanes/direction/lrTransform.ts`: the layout is made top to bottom;
// the other directions turn or mirror it.

///|
/// `applyLrDirectionTransform`: false when there is nothing to transform.
pub fn apply_lr_direction_transform(
  layout : @model.Layout,
  direction : String,
) -> Bool {
  ignore(layout)
  ignore(direction)
  abort("applyLrDirectionTransform is not ported yet")
}

///|
/// `applyBtDirectionTransform`.
pub fn apply_bt_direction_transform(layout : @model.Layout) -> Bool {
  ignore(layout)
  abort("applyBtDirectionTransform is not ported yet")
}
