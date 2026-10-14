// The blocks of a block diagram: mermaid's `blockTypes.ts`.
//
// Upstream builds its blocks as plain JavaScript objects and lets missing
// properties stand for themselves: a chain such as `a --> b --> c` yields a
// block whose id is `undefined`, and the layout reads `undefined` sizes.
// The fields here are optional wherever upstream tells an absent value
// from a present one.

///|
/// Where a block is and how large: its centre and its extent.
priv struct Size {
  mut width : Double
  mut height : Double
  mut x : Double
  mut y : Double
}

///|
/// One statement of the diagram: a block, an edge, or a statement about
/// styling or columns, told apart by `type_`.
priv struct Block {
  /// `None` is JavaScript's `undefined`, which a block made from a chain
  /// of links has for an id.
  mut id : String?
  mut label : String?
  /// `square`, `round`, ..., `composite`, `space`, `edge`, `na` for a
  /// block named without a shape, or one of the statement kinds
  /// `column-setting`, `classDef`, `applyClass`, `applyStyles`.
  mut type_ : String?
  /// The blocks inside a composite. Empty stands for no children at all,
  /// which upstream never tells apart.
  mut children : Array[Block]
  /// The number of columns a `columns` statement sets, -1 for `auto`.
  mut columns : Double?
  /// How many columns the block spans (`id:3`).
  width_in_columns : Double?
  /// How many columns a `space` statement leaves empty.
  space_width : Double?
  /// The directions a block arrow points in.
  directions : Array[String]?
  classes : Array[String]
  mut styles : Array[String]
  /// The declarations of a `classDef`.
  css : String
  /// The class a `class` statement applies.
  style_class : String
  /// The declarations of a `style` statement.
  styles_str : String
  // For an edge: the ids of the blocks it joins and how it is drawn.
  start : String?
  end : String?
  arrow_type_start : String
  arrow_type_end : String
  thickness : String
  pattern : String
  /// Filled in by measuring and layout.
  mut size : Size?
  /// Where a line from the block's centre towards a point leaves it.
  mut intersect : ((@rendering.Point) -> @rendering.Point)?
  /// The palette slot of a composite, in declaration order.
  mut color_index : Int32?
}

///|
fn Block::new(
  id? : String,
  label? : String,
  type_? : String,
  children~ : Array[Block] = [],
  columns? : Double,
  width_in_columns? : Double,
  space_width? : Double,
  directions? : Array[String],
  css~ : String = "",
  style_class~ : String = "",
  styles_str~ : String = "",
  start? : String,
  end? : String,
  arrow_type_start~ : String = "",
  arrow_type_end~ : String = "",
  thickness~ : String = "",
  pattern~ : String = "",
) -> Block {
  {
    id,
    label,
    type_,
    children,
    columns,
    width_in_columns,
    space_width,
    directions,
    classes: [],
    styles: [],
    css,
    style_class,
    styles_str,
    start,
    end,
    arrow_type_start,
    arrow_type_end,
    thickness,
    pattern,
    size: None,
    intersect: None,
    color_index: None,
  }
}

///|
/// The id as JavaScript prints it into a string.
fn Block::id_text(self : Block) -> String {
  self.id.unwrap_or("undefined")
}

///|
/// A class defined with `classDef`.
pub struct ClassDef {
  id : String
  styles : Array[String]
  text_styles : Array[String]
}
