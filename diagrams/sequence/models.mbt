///|
/// Where a note goes and what it says, worked out before anything is
/// drawn.
priv struct NoteModel {
  mut width : Double
  mut startx : Double
  mut stopx : Double
  mut starty : Double
  mut stopy : Double
  mut message : String
}

///|
/// The same for a message line.
priv struct MsgModel {
  width : Double
  mut height : Double
  mut startx : Double
  mut stopx : Double
  mut starty : Double
  mut stopy : Double
  message : String
  kind : Int32
  from_bounds : Double
  to_bounds : Double
  mut sequence_index : Double
  mut sequence_visible : Bool
}

///|
/// The rectangle a participant was drawn with; its popup menu reuses it.
priv struct RectData {
  x : Double
  fill : String
  stroke : String
  width : Double
  height : Double
  rx : Double
  ry : Double
  class_name : String?
}
