// Natural sizes of synthetic images, as Chrome reports them for an `<img>`
// with the image as a `data:` URL (the full set, and how they are made, is
// in scripts/check_images.py).

///|
/// The cases whose size differs from Chrome's: name, port, Chrome.
fn differences(cases : Array[(String, String, String)]) -> Array[String] {
  let failed = []
  for case in cases {
    let (name, url, expected) = case
    let actual = match @image.data_url_size(url) {
      Some(Size(width, height)) => "\{width}x\{height}"
      Some(Undecodable) => "undecodable"
      Some(Unknown(reason)) => "unknown: \{reason}"
      None => "not a data: URL"
    }
    if actual != expected {
      failed.push("\{name}: \{actual}, Chrome \{expected}")
    }
  }
  failed
}

///|
test "PNG" {
  let cases = [
    (
      "png 37x23", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACUAAAAXCAIAAAADThHyAAAAGElEQVR4nO3BAQEAAACCIP+vbkhAAQDwbAoQAAG+8Z3BAAAAAElFTkSuQmCC",
      "37x23",
    ),
    (
      "png 1x1", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYGAAAAAEAAH2FzhVAAAAAElFTkSuQmCC",
      "1x1",
    ),
    (
      "png 151x7", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAJcAAAAHCAIAAACKm0htAAAAGklEQVR4nO3BMQEAAADCoPVPbQlPoAAAAN4GDGoAATq7T/AAAAAASUVORK5CYII=",
      "151x7",
    ),
    (
      "png 3x1000", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAMAAAPoCAIAAACUIdM0AAAAIUlEQVR4nO3BAQ0AAADCoPdPbQ43oAAAAAAAAAAAAODfACcQAAEU2DjZAAAAAElFTkSuQmCC",
      "3x1000",
    ),
    (
      "png palette 2-bit", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFAgMAAADqPS74AAAABlBMVEUAAAD///+l2Z/dAAAAC0lEQVR4nGNggAEAAAoAAX+AdF4AAAAASUVORK5CYII=",
      "9x5",
    ),
    (
      "png grey 16-bit", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFEAAAAADiqEX0AAAADElEQVR4nGNgoCkAAABfAAE9y46ZAAAAAElFTkSuQmCC",
      "9x5",
    ),
    (
      "png bad depth", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFBAIAAADdwbw9AAAADElEQVR4nGNgIBUAAAAyAAFBPJwWAAAAAElFTkSuQmCC",
      "undecodable",
    ),
    (
      "png zero width", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAAAAAAFCAIAAADkJHr2AAAAC0lEQVR4nGNggAEAAAoAAX+AdF4AAAAASUVORK5CYII=",
      "undecodable",
    ),
    (
      "png ihdr crc", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAZMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCC",
      "undecodable",
    ),
    (
      "png truncated ihdr", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAY",
      "undecodable",
    ),
    (
      "png no idat", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAAAElFTkSuQmCC",
      "undecodable",
    ),
    (
      "png no iend", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuL",
      "9x5",
    ),
    (
      "png ancillary crc", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAAA3RFWHRhAGLcSaIAAAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCC",
      "9x5",
    ),
    (
      "png exif 6", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAAGmVYSWZJSSoACAAAAAEAEgEDAAEAAAAGAAAAAAAAALdIESkAAAAMSURBVHicY2AYPAAAAIwAAYLxe4sAAAAASUVORK5CYII=",
      "5x9",
    ),
    (
      "png exif 3", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAAGmVYSWZJSSoACAAAAAEAEgEDAAEAAAADAAAAAAAAAP+oH00AAAAMSURBVHicY2AYPAAAAIwAAYLxe4sAAAAASUVORK5CYII=",
      "9x5",
    ),
    (
      "png exif density", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACUAAAAXCAIAAAADThHyAAAAbGVYSWZJSSoACAAAAAQAGgEFAAEAAABcAAAAGwEFAAEAAABkAAAAKAEDAAEAAAACAAAAaYcEAAEAAAA+AAAAAAAAAAIAAqAEAAEAAAATAAAAA6AEAAEAAAAMAAAAAAAAAJAAAAABAAAAkAAAAAEAAAAKqKhhAAAAGElEQVR4nO3BAQEAAACCIP+vbkhAAQDwbAoQAAG+8Z3BAAAAAElFTkSuQmCC",
      "37x23",
    ),
    (
      "png phys", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAACXBIWXMAABYlAAAWJQFJUiTwAAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCC",
      "9x5",
    ),
    (
      "png served as text", "data:text/plain;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCC",
      "9x5",
    ),
    (
      "png served as svg", "data:image/svg+xml;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCC",
      "undecodable",
    ),
    ("text", "data:image/png;base64,bm90IGFuIGltYWdl", "undecodable"),
    ("empty", "data:image/png;base64,", "undecodable"),
  ]
  json_inspect(differences(cases), content=[])
}

///|
test "JPEG" {
  let cases = [
    (
      "jpeg 37x23", "data:image/jpeg;base64,/9j/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "37x23",
    ),
    (
      "jpeg 1x1", "data:image/jpeg;base64,/9j/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AP//Z",
      "1x1",
    ),
    (
      "jpeg 8x8", "data:image/jpeg;base64,/9j/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAIAAgBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AP//Z",
      "8x8",
    ),
    (
      "jpeg 9x1000", "data:image/jpeg;base64,/9j/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAPoAAkBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/9k=",
      "9x1000",
    ),
    (
      "jpeg progressive header", "data:image/jpeg;base64,/9j/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wgALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "37x23",
    ),
    (
      "jpeg orientation 1", "data:image/jpeg;base64,/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAAAQAAAAAAAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "37x23",
    ),
    (
      "jpeg orientation 2", "data:image/jpeg;base64,/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAAAgAAAAAAAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "37x23",
    ),
    (
      "jpeg orientation 3", "data:image/jpeg;base64,/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAAAwAAAAAAAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "37x23",
    ),
    (
      "jpeg orientation 4", "data:image/jpeg;base64,/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAABAAAAAAAAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "37x23",
    ),
    (
      "jpeg orientation 5", "data:image/jpeg;base64,/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAABQAAAAAAAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "23x37",
    ),
    (
      "jpeg orientation 6", "data:image/jpeg;base64,/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAABgAAAAAAAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "23x37",
    ),
    (
      "jpeg orientation 7", "data:image/jpeg;base64,/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAABwAAAAAAAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "23x37",
    ),
    (
      "jpeg orientation 8", "data:image/jpeg;base64,/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAACAAAAAAAAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "23x37",
    ),
    (
      "jpeg orientation 0", "data:image/jpeg;base64,/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAAAAAAAAAAAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "37x23",
    ),
    (
      "jpeg orientation 9", "data:image/jpeg;base64,/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAACQAAAAAAAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "37x23",
    ),
    (
      "jpeg orientation 6 big-endian", "data:image/jpeg;base64,/9j/4QAiRXhpZgAATU0AKgAAAAgAAQESAAMAAAABAAYAAAAAAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "23x37",
    ),
    (
      "jpeg orientation after app0", "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAABgAAAAAAAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "23x37",
    ),
    (
      "jpeg first exif wins", "data:image/jpeg;base64,/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAAAQAAAAAAAAD/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAABgAAAAAAAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "37x23",
    ),
    (
      "jpeg xmp app1 first", "data:image/jpeg;base64,/9j/4QAjaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLwA8eC8+/+EAIkV4aWYAAElJKgAIAAAAAQASAQMAAQAAAAYAAAAAAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "23x37",
    ),
    (
      "jpeg exif after frame", "data:image/jpeg;base64,/9j/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/+EAIkV4aWYAAElJKgAIAAAAAQASAQMAAQAAAAYAAAAAAAAA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAA//Z",
      "23x37",
    ),
    (
      "jpeg density 144", "data:image/jpeg;base64,/9j/4QB0RXhpZgAASUkqAAgAAAAEABoBBQABAAAAXAAAABsBBQABAAAAZAAAACgBAwABAAAAAgAAAGmHBAABAAAAPgAAAAAAAAACAAKgBAABAAAAEwAAAAOgBAABAAAADAAAAAAAAACQAAAAAQAAAJAAAAABAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "19x12",
    ),
    (
      "jpeg density floor", "data:image/jpeg;base64,/9j/4QB0RXhpZgAASUkqAAgAAAAEABoBBQABAAAAXAAAABsBBQABAAAAZAAAACgBAwABAAAAAgAAAGmHBAABAAAAPgAAAAAAAAACAAKgBAABAAAAEgAAAAOgBAABAAAACwAAAAAAAACQAAAAAQAAAJAAAAABAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "37x23",
    ),
    (
      "jpeg density 144 orientation 6", "data:image/jpeg;base64,/9j/4QCARXhpZgAASUkqAAgAAAAFABIBAwABAAAABgAAABoBBQABAAAAaAAAABsBBQABAAAAcAAAACgBAwABAAAAAgAAAGmHBAABAAAASgAAAAAAAAACAAKgBAABAAAAEwAAAAOgBAABAAAADAAAAAAAAACQAAAAAQAAAJAAAAABAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "12x19",
    ),
    (
      "jpeg density turned dimensions", "data:image/jpeg;base64,/9j/4QCARXhpZgAASUkqAAgAAAAFABIBAwABAAAABgAAABoBBQABAAAAaAAAABsBBQABAAAAcAAAACgBAwABAAAAAgAAAGmHBAABAAAASgAAAAAAAAACAAKgBAABAAAADAAAAAOgBAABAAAAEwAAAAAAAACQAAAAAQAAAJAAAAABAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "23x37",
    ),
    (
      "jpeg density 36", "data:image/jpeg;base64,/9j/4QB0RXhpZgAASUkqAAgAAAAEABoBBQABAAAAXAAAABsBBQABAAAAZAAAACgBAwABAAAAAgAAAGmHBAABAAAAPgAAAAAAAAACAAKgBAABAAAASgAAAAOgBAABAAAALgAAAAAAAAAkAAAAAQAAACQAAAABAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "74x46",
    ),
    (
      "jpeg density cm", "data:image/jpeg;base64,/9j/4QB0RXhpZgAASUkqAAgAAAAEABoBBQABAAAAXAAAABsBBQABAAAAZAAAACgBAwABAAAAAwAAAGmHBAABAAAAPgAAAAAAAAACAAKgBAABAAAAEwAAAAOgBAABAAAADAAAAAAAAACQAAAAAQAAAJAAAAABAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "37x23",
    ),
    (
      "jpeg density no unit", "data:image/jpeg;base64,/9j/4QBoRXhpZgAASUkqAAgAAAADABoBBQABAAAAUAAAABsBBQABAAAAWAAAAGmHBAABAAAAMgAAAAAAAAACAAKgBAABAAAAEwAAAAOgBAABAAAADAAAAAAAAACQAAAAAQAAAJAAAAABAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "37x23",
    ),
    (
      "jpeg density mixed", "data:image/jpeg;base64,/9j/4QB0RXhpZgAASUkqAAgAAAAEABoBBQABAAAAXAAAABsBBQABAAAAZAAAACgBAwABAAAAAgAAAGmHBAABAAAAPgAAAAAAAAACAAKgBAABAAAAEwAAAAOgBAABAAAAFwAAAAAAAACQAAAAAQAAAEgAAAABAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "19x23",
    ),
    (
      "jpeg density rational", "data:image/jpeg;base64,/9j/4QB0RXhpZgAASUkqAAgAAAAEABoBBQABAAAAXAAAABsBBQABAAAAZAAAACgBAwABAAAAAgAAAGmHBAABAAAAPgAAAAAAAAACAAKgBAABAAAAEwAAAAOgBAABAAAADAAAAAAAAAAgAQAAAgAAACABAAACAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "19x12",
    ),
    (
      "jpeg density short dimensions", "data:image/jpeg;base64,/9j/4QB0RXhpZgAASUkqAAgAAAAEABoBBQABAAAAXAAAABsBBQABAAAAZAAAACgBAwABAAAAAgAAAGmHBAABAAAAPgAAAAAAAAACAAKgAwABAAAAEwAAAAOgAwABAAAADAAAAAAAAACQAAAAAQAAAJAAAAABAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "19x12",
    ),
    (
      "jpeg density zero", "data:image/jpeg;base64,/9j/4QB0RXhpZgAASUkqAAgAAAAEABoBBQABAAAAXAAAABsBBQABAAAAZAAAACgBAwABAAAAAgAAAGmHBAABAAAAPgAAAAAAAAACAAKgBAABAAAAEwAAAAOgBAABAAAADAAAAAAAAAAAAAAAAQAAAJAAAAABAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "37x23",
    ),
    (
      "jpeg density zero denominator", "data:image/jpeg;base64,/9j/4QB0RXhpZgAASUkqAAgAAAAEABoBBQABAAAAXAAAABsBBQABAAAAZAAAACgBAwABAAAAAgAAAGmHBAABAAAAPgAAAAAAAAACAAKgBAABAAAAEwAAAAOgBAABAAAADAAAAAAAAACQAAAAAAAAAJAAAAABAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "37x23",
    ),
    (
      "jpeg density no dimensions", "data:image/jpeg;base64,/9j/4QBKRXhpZgAASUkqAAgAAAADABoBBQABAAAAMgAAABsBBQABAAAAOgAAACgBAwABAAAAAgAAAAAAAACQAAAAAQAAAJAAAAABAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "37x23",
    ),
    (
      "jpeg density 100", "data:image/jpeg;base64,/9j/4QB0RXhpZgAASUkqAAgAAAAEABoBBQABAAAAXAAAABsBBQABAAAAZAAAACgBAwABAAAAAgAAAGmHBAABAAAAPgAAAAAAAAACAAKgBAABAAAAGwAAAAOgBAABAAAAEQAAAAAAAABkAAAAAQAAAGQAAAABAAAA/9sAQwABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB/8AACwgAFwAlAQERAP/EABQAAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AAAAAAP/2Q==",
      "27x17",
    ),
    (
      "jpeg no eoi", "data:image/jpeg;base64,/9j/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AAAAAAw==",
      "37x23",
    ),
    (
      "jpeg no scan", "data:image/jpeg;base64,/9j/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAXACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAA=",
      "undecodable",
    ),
    (
      "jpeg zero height", "data:image/jpeg;base64,/9j/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAAACUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8A/9k=",
      "undecodable",
    ),
    (
      "jpeg served as text", "data:text/plain;base64,/9j/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAAJAAUBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AD//Z",
      "5x9",
    ),
  ]
  json_inspect(differences(cases), content=[])
}

///|
test "WebP" {
  let cases = [
    (
      "webp lossy", "data:image/webp;base64,UklGRkAAAABXRUJQVlA4IDQAAAAwAwCdASolABcAPtFmrVCoJaQipWgBABoJaQDNSBBF2G4AAP7whQwm7DtOCf7tVQGAAAAA",
      "37x23",
    ),
    (
      "webp lossless", "data:image/webp;base64,UklGRh4AAABXRUJQVlA4TBEAAAAvBAACAAdQkUZ0pv+BiOh/AAA=",
      "5x9",
    ),
    (
      "webp extended", "data:image/webp;base64,UklGRlIAAABXRUJQVlA4WAoAAAAAAAAAJAAAFgAAVlA4IDQAAAAwAwCdASolABcAPtFmrVCoJaQipWgBABoJaQDNSBBF2G4AAP7whQwm7DtOCf7tVQGAAAAA",
      "37x23",
    ),
    (
      "webp extended exif 6", "data:image/webp;base64,UklGRnQAAABXRUJQVlA4WAoAAAAIAAAAJAAAFgAAVlA4IDQAAAAwAwCdASolABcAPtFmrVCoJaQipWgBABoJaQDNSBBF2G4AAP7whQwm7DtOCf7tVQGAAAAARVhJRhoAAABJSSoACAAAAAEAEgEDAAEAAAAGAAAAAAAAAA==",
      "37x23",
    ),
    (
      "webp extended larger canvas", "data:image/webp;base64,UklGRlIAAABXRUJQVlA4WAoAAAAAAAAAJwAAFgAAVlA4IDQAAAAwAwCdASolABcAPtFmrVCoJaQipWgBABoJaQDNSBBF2G4AAP7whQwm7DtOCf7tVQGAAAAA",
      "undecodable",
    ),
    (
      "webp extended smaller canvas", "data:image/webp;base64,UklGRjAAAABXRUJQVlA4WAoAAAAAAAAABAAABAAAVlA4TBEAAAAvBAACAAdQkUZ0pv+BiOh/AAA=",
      "undecodable",
    ),
    (
      "webp extended no bitstream", "data:image/webp;base64,UklGRhYAAABXRUJQVlA4WAoAAAAAAAAAJAAAFgAA",
      "undecodable",
    ),
    (
      "webp truncated", "data:image/webp;base64,UklGRkAAAABXRUJQVlA4IDQAAAAwAwCdASolABcAPtFmrVCoJaQipWgBABoJaQDNSBBF2G4AAP7whQwm7DtOCf7t",
      "undecodable",
    ),
    (
      "webp extra bytes", "data:image/webp;base64,UklGRh4AAABXRUJQVlA4TBEAAAAvBAACAAdQkUZ0pv+BiOh/AAAAAAAA",
      "5x9",
    ),
    (
      "webp served as text", "data:text/plain;base64,UklGRh4AAABXRUJQVlA4TBEAAAAvBAACAAdQkUZ0pv+BiOh/AAA=",
      "5x9",
    ),
  ]
  json_inspect(differences(cases), content=[])
}

///|
test "GIF" {
  let cases = [
    (
      "gif 1x1", "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAkQBADs=",
      "1x1",
    ),
    (
      "gif frame beyond screen", "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAABQAHAAACAkQBADs=",
      "5x7",
    ),
    (
      "gif frame inside screen", "data:image/gif;base64,R0lGODlhCQAEAIAAAAAAAP///ywAAAAAAQABAAACAkQBADs=",
      "9x4",
    ),
    (
      "gif zero screen", "data:image/gif;base64,R0lGODlhAAAAAIAAAAAAAP///ywAAAAAAwACAAACAkQBADs=",
      "3x2",
    ),
    (
      "gif offset frame", "data:image/gif;base64,R0lGODlhBAAEAIAAAAAAAP///ywDAAMAAgACAAACAkQBADs=",
      "5x5",
    ),
    (
      "gif second frame larger", "data:image/gif;base64,R0lGODlhAgACAIAAAAAAAP///ywAAAAAAQABAAACAkQBACwAAAAABgAIAAACAkQBADs=",
      "2x2",
    ),
    (
      "gif extensions", "data:image/gif;base64,R0lGODlhAgACAIAAAAAAAP///yH5BAAAAAAAIf4DYWJjACwAAAAAAwADAAACAkQBADs=",
      "3x3",
    ),
    (
      "gif 87a", "data:image/gif;base64,R0lGODdhAgADAIAAAAAAAP///ywAAAAAAgADAAACAkQBADs=",
      "2x3",
    ),
    (
      "gif 88a", "data:image/gif;base64,R0lGODhhAgADAIAAAAAAAP///ywAAAAAAgADAAACAkQBADs=",
      "undecodable",
    ),
    ("gif no frames", "data:image/gif;base64,R0lGODlhAwAEAAAAADs=", "3x4"),
    (
      "gif no frames zero screen", "data:image/gif;base64,R0lGODlhAAAAAAAAADs=",
      "undecodable",
    ),
    (
      "gif header only", "data:image/gif;base64,R0lGODlhAwAEAAAAAA==", "undecodable",
    ),
    (
      "gif truncated colour table", "data:image/gif;base64,R0lGODlhAgACAIAAAAAAAA==",
      "undecodable",
    ),
    ("gif unknown block", "data:image/gif;base64,R0lGODlhAgACAAAAAFU7", "2x2"),
    (
      "gif descriptor only", "data:image/gif;base64,R0lGODlhAgACAAAAACwAAAAAAwADAAA=",
      "3x3",
    ),
    (
      "gif short descriptor", "data:image/gif;base64,R0lGODlhAgACAAAAACwAAAAAAwADAA==",
      "3x3",
    ),
  ]
  json_inspect(differences(cases), content=[])
}

///|
test "data: URLs" {
  let cases = [
    (
      "url base64 with spaces", "data:image/png;base64,iVBO Rw0K GgoA AAAN SUhE UgAA AAkA AAAF CAIA AAAY MVE8 AAAA DElE QVR4 nGNg GDwA AACM AAGC 8XuL AAAA AElF TkSu QmCC",
      "9x5",
    ),
    (
      "url base64 without padding", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCCAA",
      "9x5",
    ),
    (
      "url base64 one padding", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCCAAA=",
      "9x5",
    ),
    (
      "url base64 url-safe", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCC-_",
      "undecodable",
    ),
    (
      "url base64 junk", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCC!!",
      "undecodable",
    ),
    (
      "url base64 percent", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCC",
      "9x5",
    ),
    (
      "url base64 upper case", "data:image/png;BASE64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCC",
      "9x5",
    ),
    (
      "url base64 space before", "data:image/png; base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCC",
      "9x5",
    ),
    (
      "url scheme upper case", "DATA:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCC",
      "9x5",
    ),
    ("url no comma", "data:image/png;base64", "undecodable"),
    (
      "url leading space", "  data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCC",
      "9x5",
    ),
    (
      "url newline inside", "data:image/png;base64,iVBORw0KGg\noAAAANSUhEUgAAAAkAAAAFCAIAAAAYMVE8AAAADElEQVR4nGNgGDwAAACMAAGC8XuLAAAAAElFTkSuQmCC",
      "9x5",
    ),
    (
      "url svg plain", "data:image/svg+xml,<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"13\"/>",
      "12x13",
    ),
    (
      "url svg percent-encoded", "data:image/svg+xml,%3C%73%76%67%20%78%6D%6C%6E%73%3D%22%68%74%74%70%3A%2F%2F%77%77%77%2E%77%33%2E%6F%72%67%2F%32%30%30%30%2F%73%76%67%22%20%77%69%64%74%68%3D%22%31%32%22%20%68%65%69%67%68%74%3D%22%31%33%22%2F%3E",
      "12x13",
    ),
    (
      "url svg fragment", "data:image/svg+xml,<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"13\"><g fill=\"#fff\"/></svg>",
      "undecodable",
    ),
    (
      "url svg utf8 parameter", "data:image/svg+xml;utf8,<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"13\"/>",
      "12x13",
    ),
    (
      "url svg charset", "data:image/svg+xml;charset=utf-8;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPg==",
      "12x13",
    ),
    (
      "url svg type spaces", "data: image/svg+xml ;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPg==",
      "12x13",
    ),
    (
      "url svg type upper case", "data:IMAGE/SVG+XML;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPg==",
      "12x13",
    ),
    (
      "url svg as text", "data:text/plain;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPg==",
      "undecodable",
    ),
    (
      "url svg no type", "data:;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPg==",
      "undecodable",
    ),
    (
      "url svg non-ascii", "data:image/svg+xml,<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"13\"><text>\u{e9}</text></svg>",
      "12x13",
    ),
  ]
  json_inspect(differences(cases), content=[])
}

///|
test "SVG sizes" {
  let cases = [
    (
      "svg width '150'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxNTAiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "150x20",
    ),
    (
      "svg width '10.5'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMC41IiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "11x20",
    ),
    (
      "svg width '11.5'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMS41IiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "12x20",
    ),
    (
      "svg width '0.5'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIwLjUiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "1x20",
    ),
    (
      "svg width '2.5'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyLjUiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "3x20",
    ),
    (
      "svg width '0.49'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIwLjQ5IiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "0x20",
    ),
    (
      "svg width '1.4999'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxLjQ5OTkiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "1x20",
    ),
    (
      "svg width '10.25'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMC4yNSIgaGVpZ2h0PSIyMCI+PC9zdmc+",
      "10x20",
    ),
    (
      "svg width '0'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIwIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "0x20",
    ),
    (
      "svg width '-5'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSItNSIgaGVpZ2h0PSIyMCI+PC9zdmc+",
      "0x20",
    ),
    (
      "svg width '-0'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSItMCIgaGVpZ2h0PSIyMCI+PC9zdmc+",
      "0x20",
    ),
    (
      "svg width 'abc'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSJhYmMiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "300x20",
    ),
    (
      "svg width '10px'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMHB4IiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "10x20",
    ),
    (
      "svg width '10PX'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMFBYIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "10x20",
    ),
    (
      "svg width ' 10 '", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIgMTAgIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "10x20",
    ),
    (
      "svg width '\\t12\\t'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIJMTIJIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "12x20",
    ),
    (
      "svg width '10 px'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMCBweCIgaGVpZ2h0PSIyMCI+PC9zdmc+",
      "300x20",
    ),
    (
      "svg width '1e1'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxZTEiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "10x20",
    ),
    (
      "svg width '1E1'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxRTEiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "10x20",
    ),
    (
      "svg width '1e+1'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxZSsxIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "10x20",
    ),
    (
      "svg width '1e-1'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxZS0xIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "0x20",
    ),
    (
      "svg width '+10'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIrMTAiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "10x20",
    ),
    (
      "svg width '.5'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIuNSIgaGVpZ2h0PSIyMCI+PC9zdmc+",
      "1x20",
    ),
    (
      "svg width '10.'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMC4iIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "300x20",
    ),
    (
      "svg width '10e'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMGUiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "300x20",
    ),
    (
      "svg width '10in'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMGluIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "960x20",
    ),
    (
      "svg width '1in '", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxaW4gIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "96x20",
    ),
    (
      "svg width '1cm'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxY20iIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "38x20",
    ),
    (
      "svg width '10mm'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMG1tIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "38x20",
    ),
    (
      "svg width '1q'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxcSIgaGVpZ2h0PSIyMCI+PC9zdmc+",
      "1x20",
    ),
    (
      "svg width '10Q'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMFEiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "9x20",
    ),
    (
      "svg width '10pt'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMHB0IiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "13x20",
    ),
    (
      "svg width '1pc'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxcGMiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "16x20",
    ),
    (
      "svg width '2em'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyZW0iIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "32x20",
    ),
    (
      "svg width '1rem'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxcmVtIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "16x20",
    ),
    (
      "svg width '100em'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDBlbSIgaGVpZ2h0PSIyMCI+PC9zdmc+",
      "1600x20",
    ),
    (
      "svg width '10vw'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMHZ3IiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "0x20",
    ),
    (
      "svg width '10vh'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMHZoIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "0x20",
    ),
    (
      "svg width '10vmin'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMHZtaW4iIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "0x20",
    ),
    (
      "svg width '10svw'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMHN2dyIgaGVpZ2h0PSIyMCI+PC9zdmc+",
      "0x20",
    ),
    (
      "svg width '10cqw'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMGNxdyIgaGVpZ2h0PSIyMCI+PC9zdmc+",
      "0x20",
    ),
    (
      "svg width '10%'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMCUiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "300x20",
    ),
    (
      "svg width '100%'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "300x20",
    ),
    (
      "svg width 'auto'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSJhdXRvIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "300x20",
    ),
    (
      "svg width '10x'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMHgiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "300x20",
    ),
    (
      "svg width '1e400'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxZTQwMCIgaGVpZ2h0PSIyMCI+PC9zdmc+",
      "33554428x20",
    ),
    (
      "svg width '1e7'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxZTciIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "10000000x20",
    ),
    (
      "svg width '100000000'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAwMDAwMDAiIGhlaWdodD0iMjAiPjwvc3ZnPg==",
      "33554428x20",
    ),
    (
      "svg width '33554431'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIzMzU1NDQzMSIgaGVpZ2h0PSIyMCI+PC9zdmc+",
      "33554428x20",
    ),
    (
      "svg width '\\xa012'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSLCoDEyIiBoZWlnaHQ9IjIwIj48L3N2Zz4=",
      "300x20",
    ),
    (
      "svg viewBox '0 0 100 50'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxMDAgNTAiPjwvc3ZnPg==",
      "300x150",
    ),
    (
      "svg viewBox '0 0 50 100'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA1MCAxMDAiPjwvc3ZnPg==",
      "75x150",
    ),
    (
      "svg viewBox '0 0 7 3'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA3IDMiPjwvc3ZnPg==",
      "300x129",
    ),
    (
      "svg viewBox '0,0,7,3'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAsMCw3LDMiPjwvc3ZnPg==",
      "300x129",
    ),
    (
      "svg viewBox '0, 0, 7, 3'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAsIDAsIDcsIDMiPjwvc3ZnPg==",
      "300x129",
    ),
    (
      "svg viewBox '0 0 7.5 3'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA3LjUgMyI+PC9zdmc+",
      "300x120",
    ),
    (
      "svg viewBox '0 0 3 7'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAzIDciPjwvc3ZnPg==",
      "64x150",
    ),
    (
      "svg viewBox '0 0 1000 1'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxMDAwIDEiPjwvc3ZnPg==",
      "300x0",
    ),
    (
      "svg viewBox '0 0 1 1000'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxIDEwMDAiPjwvc3ZnPg==",
      "0x150",
    ),
    (
      "svg viewBox '  0 0 10 5  '", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IiAgMCAwIDEwIDUgICI+PC9zdmc+",
      "300x150",
    ),
    (
      "svg viewBox '0 0 2 1'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyIDEiPjwvc3ZnPg==",
      "300x150",
    ),
    (
      "svg viewBox '0 0 2.0001 1'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyLjAwMDEgMSI+PC9zdmc+",
      "300x150",
    ),
    (
      "svg viewBox '0 0 1.9999 1'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxLjk5OTkgMSI+PC9zdmc+",
      "300x150",
    ),
    (
      "svg viewBox '-5 -5 30 10'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9Ii01IC01IDMwIDEwIj48L3N2Zz4=",
      "300x100",
    ),
    (
      "svg viewBox '0 0 3e1 1e1'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAzZTEgMWUxIj48L3N2Zz4=",
      "300x100",
    ),
    (
      "svg viewBox '0 0 0 10'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAwIDEwIj48L3N2Zz4=",
      "300x150",
    ),
    (
      "svg viewBox '0 0 -1 10'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAtMSAxMCI+PC9zdmc+",
      "300x150",
    ),
    (
      "svg viewBox '0 0 10'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxMCI+PC9zdmc+",
      "300x150",
    ),
    (
      "svg viewBox '1 2 3 4 5'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjEgMiAzIDQgNSI+PC9zdmc+",
      "300x150",
    ),
    (
      "svg viewBox '0 0 30 10 x'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAzMCAxMCB4Ij48L3N2Zz4=",
      "300x150",
    ),
    (
      "svg viewBox 'none'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9Im5vbmUiPjwvc3ZnPg==",
      "300x150",
    ),
    (
      "svg viewBox '0,,0,7,3'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAsLDAsNywzIj48L3N2Zz4=",
      "300x150",
    ),
    (
      "svg viewBox '0 0 7 3,'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA3IDMsIj48L3N2Zz4=",
      "300x150",
    ),
    (
      "svg attributes 'width=\"150\" height=\"150\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxNTAiIGhlaWdodD0iMTUwIj48L3N2Zz4=",
      "150x150",
    ),
    (
      "svg attributes ''", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciID48L3N2Zz4=",
      "300x150",
    ),
    (
      "svg attributes 'width=\"40\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI0MCI+PC9zdmc+",
      "40x150",
    ),
    (
      "svg attributes 'height=\"40\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iNDAiPjwvc3ZnPg==",
      "300x40",
    ),
    (
      "svg attributes 'width=\"40\" viewBox=\"0 0 100 50\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI0MCIgdmlld0JveD0iMCAwIDEwMCA1MCI+PC9zdmc+",
      "40x20",
    ),
    (
      "svg attributes 'height=\"40\" viewBox=\"0 0 100 50\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCAxMDAgNTAiPjwvc3ZnPg==",
      "80x40",
    ),
    (
      "svg attributes 'width=\"50%\" height=\"20\" viewBox=\"0 0 100 50\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI1MCUiIGhlaWdodD0iMjAiIHZpZXdCb3g9IjAgMCAxMDAgNTAiPjwvc3ZnPg==",
      "40x20",
    ),
    (
      "svg attributes 'width=\"50%\" height=\"50%\" viewBox=\"0 0 30 10\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI1MCUiIGhlaWdodD0iNTAlIiB2aWV3Qm94PSIwIDAgMzAgMTAiPjwvc3ZnPg==",
      "300x100",
    ),
    (
      "svg attributes 'width=\"50%\" height=\"50%\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI1MCUiIGhlaWdodD0iNTAlIj48L3N2Zz4=",
      "300x150",
    ),
    (
      "svg attributes 'width=\"0\" viewBox=\"0 0 30 10\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIwIiB2aWV3Qm94PSIwIDAgMzAgMTAiPjwvc3ZnPg==",
      "0x0",
    ),
    (
      "svg attributes 'width=\"33\" viewBox=\"0 0 7 3\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIzMyIgdmlld0JveD0iMCAwIDcgMyI+PC9zdmc+",
      "33x14",
    ),
    (
      "svg attributes 'height=\"33\" viewBox=\"0 0 7 3\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMzMiIHZpZXdCb3g9IjAgMCA3IDMiPjwvc3ZnPg==",
      "77x33",
    ),
    (
      "svg attributes 'width=\"33\" viewBox=\"0 0 3 7\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIzMyIgdmlld0JveD0iMCAwIDMgNyI+PC9zdmc+",
      "33x77",
    ),
    (
      "svg attributes 'height=\"33\" viewBox=\"0 0 3 7\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMzMiIHZpZXdCb3g9IjAgMCAzIDciPjwvc3ZnPg==",
      "14x33",
    ),
    (
      "svg attributes 'width=\"33\" viewBox=\"0 0 1000 1\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIzMyIgdmlld0JveD0iMCAwIDEwMDAgMSI+PC9zdmc+",
      "33x0",
    ),
    (
      "svg attributes 'height=\"33\" viewBox=\"0 0 1000 1\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMzMiIHZpZXdCb3g9IjAgMCAxMDAwIDEiPjwvc3ZnPg==",
      "33000x33",
    ),
    (
      "svg attributes 'height=\"1em\" viewBox=\"0 0 30 10\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMWVtIiB2aWV3Qm94PSIwIDAgMzAgMTAiPjwvc3ZnPg==",
      "48x16",
    ),
    (
      "svg attributes 'width=\"2em\" height=\"2em\" font-size=\"20\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyZW0iIGhlaWdodD0iMmVtIiBmb250LXNpemU9IjIwIj48L3N2Zz4=",
      "40x40",
    ),
    (
      "svg attributes 'width=\"2em\" height=\"13\" style=\"fill:red\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyZW0iIGhlaWdodD0iMTMiIHN0eWxlPSJmaWxsOnJlZCI+PC9zdmc+",
      "32x13",
    ),
    (
      "svg attributes 'style=\"width: 50px; height: 60px\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHN0eWxlPSJ3aWR0aDogNTBweDsgaGVpZ2h0OiA2MHB4Ij48L3N2Zz4=",
      "300x150",
    ),
    (
      "svg attributes 'style=\"width: 50px\" width=\"12\" height=\"13\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHN0eWxlPSJ3aWR0aDogNTBweCIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEzIj48L3N2Zz4=",
      "12x13",
    ),
    (
      "svg attributes 'xmlns:q=\"urn:q\" q:width=\"40\" width=\"12\" height=\"13\"'",
      "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnE9InVybjpxIiBxOndpZHRoPSI0MCIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEzIj48L3N2Zz4=",
      "12x13",
    ),
    (
      "svg attributes 'viewBox=\"0 0 7 3\" preserveAspectRatio=\"none\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA3IDMiIHByZXNlcnZlQXNwZWN0UmF0aW89Im5vbmUiPjwvc3ZnPg==",
      "300x150",
    ),
    (
      "svg attributes 'viewBox=\"0 0 7 3\" preserveAspectRatio=\" none \"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA3IDMiIHByZXNlcnZlQXNwZWN0UmF0aW89IiBub25lICI+PC9zdmc+",
      "300x150",
    ),
    (
      "svg attributes 'viewBox=\"0 0 7 3\" preserveAspectRatio=\"none meet\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA3IDMiIHByZXNlcnZlQXNwZWN0UmF0aW89Im5vbmUgbWVldCI+PC9zdmc+",
      "300x150",
    ),
    (
      "svg attributes 'viewBox=\"0 0 7 3\" preserveAspectRatio=\"none slice\"'",
      "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA3IDMiIHByZXNlcnZlQXNwZWN0UmF0aW89Im5vbmUgc2xpY2UiPjwvc3ZnPg==",
      "300x150",
    ),
    (
      "svg attributes 'viewBox=\"0 0 7 3\" preserveAspectRatio=\"defer none\"'",
      "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA3IDMiIHByZXNlcnZlQXNwZWN0UmF0aW89ImRlZmVyIG5vbmUiPjwvc3ZnPg==",
      "300x129",
    ),
    (
      "svg attributes 'viewBox=\"0 0 7 3\" preserveAspectRatio=\"xMinYMin slice\"'",
      "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA3IDMiIHByZXNlcnZlQXNwZWN0UmF0aW89InhNaW5ZTWluIHNsaWNlIj48L3N2Zz4=",
      "300x129",
    ),
    (
      "svg attributes 'viewBox=\"0 0 7 3\" preserveAspectRatio=\"NONE\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA3IDMiIHByZXNlcnZlQXNwZWN0UmF0aW89Ik5PTkUiPjwvc3ZnPg==",
      "300x129",
    ),
    (
      "svg attributes 'viewBox=\"0 0 7 3\" preserveAspectRatio=\"none garbage\"'",
      "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA3IDMiIHByZXNlcnZlQXNwZWN0UmF0aW89Im5vbmUgZ2FyYmFnZSI+PC9zdmc+",
      "300x129",
    ),
    (
      "svg attributes 'width=\"70\" viewBox=\"0 0 7 3\" preserveAspectRatio=\"none\"'",
      "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI3MCIgdmlld0JveD0iMCAwIDcgMyIgcHJlc2VydmVBc3BlY3RSYXRpbz0ibm9uZSI+PC9zdmc+",
      "300x150",
    ),
    (
      "svg attributes 'height=\"20\" viewBox=\"0 0 7 3\" preserveAspectRatio=\"none\"'",
      "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMjAiIHZpZXdCb3g9IjAgMCA3IDMiIHByZXNlcnZlQXNwZWN0UmF0aW89Im5vbmUiPjwvc3ZnPg==",
      "300x150",
    ),
    (
      "svg attributes 'width=\"70\" height=\"20\" viewBox=\"0 0 7 3\" preserveAspectRatio=\"none\"'",
      "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI3MCIgaGVpZ2h0PSIyMCIgdmlld0JveD0iMCAwIDcgMyIgcHJlc2VydmVBc3BlY3RSYXRpbz0ibm9uZSI+PC9zdmc+",
      "70x20",
    ),
    (
      "svg attributes 'width=\"70\" preserveAspectRatio=\"none\"'", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI3MCIgcHJlc2VydmVBc3BlY3RSYXRpbz0ibm9uZSI+PC9zdmc+",
      "300x150",
    ),
    (
      "svg attributes 'width=\"70\" height=\"20\" preserveAspectRatio=\"none\"'",
      "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI3MCIgaGVpZ2h0PSIyMCIgcHJlc2VydmVBc3BlY3RSYXRpbz0ibm9uZSI+PC9zdmc+",
      "70x20",
    ),
  ]
  json_inspect(differences(cases), content=[])
}

///|
test "XML well-formedness" {
  let cases = [
    (
      "xml prolog", "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPCEtLSBjIC0tPgo8IURPQ1RZUEUgc3ZnIFBVQkxJQyAiLS8vVzNDLy9EVEQgU1ZHIDEuMS8vRU4iICJodHRwOi8vd3d3LnczLm9yZy9HcmFwaGljcy9TVkcvMS4xL0RURC9zdmcxMS5kdGQiPgo8c3ZnIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEzIi8+",
      "12x13",
    ),
    (
      "xml standalone", "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBzdGFuZGFsb25lPSJ5ZXMiPz48c3ZnIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEzIi8+",
      "12x13",
    ),
    (
      "xml standalone maybe", "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im1heWJlIj8+PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPg==",
      "undecodable",
    ),
    (
      "xml version 1.1", "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4xIj8+PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPg==",
      "12x13",
    ),
    (
      "xml version 2.0", "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMi4wIj8+PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPg==",
      "undecodable",
    ),
    (
      "xml declaration after space", "data:image/svg+xml;base64,IDw/eG1sIHZlcnNpb249IjEuMCI/PjxzdmcgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB3aWR0aD0iMTIiIGhlaWdodD0iMTMiLz4=",
      "undecodable",
    ),
    (
      "xml declaration without version", "data:image/svg+xml;base64,PD94bWwgZW5jb2Rpbmc9IlVURi04Ij8+PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPg==",
      "undecodable",
    ),
    (
      "xml stylesheet instruction first", "data:image/svg+xml;base64,PD94bWwtc3R5bGVzaGVldCBocmVmPSJhLmNzcyI/PjxzdmcgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB3aWR0aD0iMTIiIGhlaWdodD0iMTMiLz4=",
      "12x13",
    ),
    (
      "xml prefixed root", "data:image/svg+xml;base64,PHM6c3ZnIHhtbG5zOnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB3aWR0aD0iMTIiIGhlaWdodD0iMTMiLz4=",
      "12x13",
    ),
    (
      "xml no namespace", "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAiIGhlaWdodD0iMTAiPjwvc3ZnPg==",
      "undecodable",
    ),
    (
      "xml wrong namespace", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMTk5OS94aHRtbCIgd2lkdGg9IjEwIiBoZWlnaHQ9IjEwIj48L3N2Zz4=",
      "undecodable",
    ),
    (
      "xml g root", "data:image/svg+xml;base64,PGcgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB3aWR0aD0iMTIiIGhlaWdodD0iMTMiLz4=",
      "undecodable",
    ),
    (
      "xml html root", "data:image/svg+xml;base64,PGh0bWwgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGh0bWwiPjxib2R5Png8L2JvZHk+PC9odG1sPg==",
      "undecodable",
    ),
    (
      "xml unclosed", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMCIgaGVpZ2h0PSIxMCI+PGc+PC9zdmc+",
      "undecodable",
    ),
    (
      "xml mismatched", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PGc+PC9oPjwvc3ZnPg==",
      "undecodable",
    ),
    ("xml not xml", "data:image/svg+xml;base64,aGVsbG8=", "undecodable"),
    ("xml empty document", "data:image/svg+xml;base64,", "undecodable"),
    (
      "xml character reference", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSImIzQ5OzIiIGhlaWdodD0iMTMiLz4=",
      "12x13",
    ),
    (
      "xml hex character reference", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSImI3gzMTsyIiBoZWlnaHQ9IjEzIi8+",
      "12x13",
    ),
    (
      "xml null character reference", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PHRleHQ+JiMwOzwvdGV4dD48L3N2Zz4=",
      "undecodable",
    ),
    (
      "xml duplicate attribute", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgd2lkdGg9IjE0IiBoZWlnaHQ9IjEzIi8+",
      "undecodable",
    ),
    (
      "xml undefined entity", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PHRleHQ+Jm5ic3A7PC90ZXh0Pjwvc3ZnPg==",
      "undecodable",
    ),
    (
      "xml undefined entity with external subset", "data:image/svg+xml;base64,PCFET0NUWVBFIHN2ZyBTWVNURU0gInN2Zy5kdGQiPjxzdmcgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB3aWR0aD0iMTIiIGhlaWdodD0iMTMiPjx0ZXh0PiZuYnNwOzwvdGV4dD48L3N2Zz4=",
      "12x13",
    ),
    (
      "xml internal entity", "data:image/svg+xml;base64,PCFET0NUWVBFIHN2ZyBbPCFFTlRJVFkgdyAiMTIiPl0+PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSImdzsiIGhlaWdodD0iMTMiLz4=",
      "12x13",
    ),
    (
      "xml internal entity namespace", "data:image/svg+xml;base64,PCFET0NUWVBFIHN2ZyBbPCFFTlRJVFkgbnNfc3ZnICJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PCFFTEVNRU5UIHN2ZyBBTlk+PCFBVFRMSVNUIHN2ZyB3aWR0aCBDREFUQSAjSU1QTElFRD5dPjxzdmcgeG1sbnM9IiZuc19zdmc7IiB3aWR0aD0iMTIiIGhlaWdodD0iMTMiLz4=",
      "12x13",
    ),
    (
      "xml text after root", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPmp1bms=",
      "undecodable",
    ),
    (
      "xml two roots", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPjxzdmcgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIi8+",
      "undecodable",
    ),
    (
      "xml comment after root", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPjwhLS0geCAtLT4K",
      "12x13",
    ),
    (
      "xml doctype after root", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPjwhRE9DVFlQRSBzdmc+",
      "undecodable",
    ),
    (
      "xml double hyphen in comment", "data:image/svg+xml;base64,PCEtLSBhIC0tIGIgLS0+PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPg==",
      "undecodable",
    ),
    (
      "xml unquoted attribute", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPTEyIGhlaWdodD0iMTMiLz4=",
      "undecodable",
    ),
    (
      "xml single quotes", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPScxMicgaGVpZ2h0PScxMycvPg==",
      "12x13",
    ),
    (
      "xml spaces around equals", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoID0gIjEyIiAgaGVpZ2h0PQoiMTMiIC8+",
      "12x13",
    ),
    (
      "xml leading white space", "data:image/svg+xml;base64,ICAKPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPg==",
      "12x13",
    ),
    (
      "xml less-than in attribute", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIgZGF0YS14PSJhPGIiLz4=",
      "undecodable",
    ),
    (
      "xml greater-than in attribute", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIgZGF0YS14PSJhPmIiLz4=",
      "12x13",
    ),
    (
      "xml bare ampersand", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PHRleHQ+YSAmIGI8L3RleHQ+PC9zdmc+",
      "undecodable",
    ),
    (
      "xml cdata", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PCFbQ0RBVEFbIHggPCB5IF1dPjwvc3ZnPg==",
      "12x13",
    ),
    (
      "xml cdata end in text", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+YSBdXT4gYjwvc3ZnPg==",
      "undecodable",
    ),
    (
      "xml instruction inside", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PD9mb28gYmFyPz48L3N2Zz4=",
      "12x13",
    ),
    (
      "xml xml instruction inside", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PD94bWwgdmVyc2lvbj0iMS4wIj8+PC9zdmc+",
      "undecodable",
    ),
    (
      "xml digit name", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PDFhLz48L3N2Zz4=",
      "undecodable",
    ),
    (
      "xml non-ascii name", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PMOpLz48L3N2Zz4=",
      "12x13",
    ),
    (
      "xml control character", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+ATwvc3ZnPg==",
      "undecodable",
    ),
    (
      "xml undeclared prefix", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PGE6Yi8+PC9zdmc+",
      "undecodable",
    ),
    (
      "xml undeclared xlink", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PHVzZSB4bGluazpocmVmPSIjYSIvPjwvc3ZnPg==",
      "undecodable",
    ),
    (
      "xml declared xlink", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB3aWR0aD0iMTIiIGhlaWdodD0iMTMiPjx1c2UgeGxpbms6aHJlZj0iI2EiLz48L3N2Zz4=",
      "12x13",
    ),
    (
      "xml empty default namespace", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PGcgeG1sbnM9IiIvPjwvc3ZnPg==",
      "12x13",
    ),
    (
      "xml xml prefix", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIvPg==",
      "12x13",
    ),
    (
      "xml empty prefix binding", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOmE9IiIgd2lkdGg9IjEyIiBoZWlnaHQ9IjEzIi8+",
      "undecodable",
    ),
    (
      "xml duplicate expanded attribute", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOmE9InVybjp4IiB4bWxuczpiPSJ1cm46eCIgYTpjPSIxIiBiOmM9IjIiIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPg==",
      "undecodable",
    ),
    (
      "xml two colons", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PGE6YjpjIHhtbG5zOmE9InVybjp4Ii8+PC9zdmc+",
      "undecodable",
    ),
    (
      "xml nested svg", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIvPjwvc3ZnPg==",
      "12x13",
    ),
    (
      "xml newline in attribute", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIKMTIKIiBoZWlnaHQ9IjEzIi8+",
      "12x13",
    ),
    (
      "xml bom", "data:image/svg+xml;base64,77u/PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyIvPg==",
      "12x13",
    ),
    (
      "xml utf-16le", "data:image/svg+xml;base64,//48AHMAdgBnACAAeABtAGwAbgBzAD0AIgBoAHQAdABwADoALwAvAHcAdwB3AC4AdwAzAC4AbwByAGcALwAyADAAMAAwAC8AcwB2AGcAIgAgAHcAaQBkAHQAaAA9ACIAMQAyACIAIABoAGUAaQBnAGgAdAA9ACIAMQAzACIALwA+AA==",
      "12x13",
    ),
    (
      "xml utf-16be", "data:image/svg+xml;base64,/v8APABzAHYAZwAgAHgAbQBsAG4AcwA9ACIAaAB0AHQAcAA6AC8ALwB3AHcAdwAuAHcAMwAuAG8AcgBnAC8AMgAwADAAMAAvAHMAdgBnACIAIAB3AGkAZAB0AGgAPQAiADEAMgAiACAAaABlAGkAZwBoAHQAPQAiADEAMwAiAC8APg==",
      "12x13",
    ),
    (
      "xml latin-1 ascii", "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iSVNPLTg4NTktMSI/PjxzdmcgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB3aWR0aD0iMTIiIGhlaWdodD0iMTMiLz4=",
      "12x13",
    ),
    (
      "xml latin-1 non-ascii", "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iSVNPLTg4NTktMSI/PjxzdmcgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB3aWR0aD0iMTIiIGhlaWdodD0iMTMiPjx0ZXh0Puk8L3RleHQ+PC9zdmc+",
      "undecodable",
    ),
    (
      "xml invalid utf-8", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMyI+PHRleHQ+6TwvdGV4dD48L3N2Zz4=",
      "undecodable",
    ),
    (
      "xml crlf", "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciDQp3aWR0aD0iMTIiDQpoZWlnaHQ9IjEzIi8+",
      "12x13",
    ),
  ]
  json_inspect(differences(cases), content=[])
}

///|
test "what the port does not size" {
  let svg = (attributes : String, content : String) => {
    "data:image/svg+xml,<svg xmlns=\"http://www.w3.org/2000/svg\" \{attributes}>\{content}</svg>"
  }
  // Chrome: 1x1, 36x20, 16x20, 15x20, 60x60, 60x13.
  let cases = [
    (
      "bmp", "data:image/bmp;base64,Qk06AAAAAAAAADYAAAAoAAAAAQAAAAEAAAABABgAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/wA=",
      "unknown: BMP images are not read",
    ),
    (
      "ex",
      svg("width=\"5ex\" height=\"20\"", ""),
      "unknown: an SVG image whose length in ex depends on the default font",
    ),
    (
      "ch",
      svg("width=\"2ch\" height=\"20\"", ""),
      "unknown: an SVG image whose length in ch depends on the default font",
    ),
    (
      "calc",
      svg("width=\"calc(10px + 5px)\" height=\"20\"", ""),
      "unknown: an SVG image whose length is a CSS function",
    ),
    (
      "styled font size",
      svg("width=\"2em\" height=\"2em\" style=\"font-size:30px\"", ""),
      "unknown: an SVG image whose length in em has a font size set",
    ),
    (
      "style sheet",
      svg("width=\"2em\" height=\"13\"", "<style>svg{font-size:30px}</style>"),
      "unknown: an SVG image whose length in em has a font size set",
    ),
  ]
  json_inspect(differences(cases), content=[])
}

///|
test "bytes without a type" {
  // A loader's bytes have no type: raster formats by signature, else SVG.
  let svg = @utf8.encode(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 150 150\"/>",
  )
  debug_inspect(@image.natural_size(svg), content="Size(150, 150)")
  debug_inspect(
    @image.natural_size(svg, mime="image/png"),
    content="Undecodable",
  )
  debug_inspect(
    @image.natural_size(@utf8.encode("<html><body>Not found</body></html>")),
    content="Undecodable",
  )
  debug_inspect(@image.natural_size(b""), content="Undecodable")
  debug_inspect(
    @image.data_url_size("https://example.com/a.png"),
    content="None",
  )
}
