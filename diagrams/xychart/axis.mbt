// A port of the chart builder's axes (baseAxis.ts, bandAxis.ts,
// linearAxis.ts): one type for both, since they differ only in their
// scale and tick values.

///|
const BAR_WIDTH_TO_TICK_WIDTH_RATIO : Double = 0.7

///|
const MAX_OUTER_PADDING_PERCENT_FOR_WRT_LABEL : Double = 0.2

///|
priv enum Scale {
  BandScale(@d3.BandScale)
  LinearScale(@d3.LinearScale)
}

///|
/// A tick: its label and where it is on the axis.
priv struct Tick {
  label : String
  position : Double
}

///|
priv struct Axis {
  config : AxisConfig
  title : String
  theme : AxisTheme
  measure : Measurer
  data : AxisData
  bounding_rect : Rect
  /// `left`, `bottom` or `top`.
  mut position : String
  mut show_title : Bool
  mut show_label : Bool
  mut show_tick : Bool
  mut show_axis_line : Bool
  mut outer_padding : Double
  mut title_text_height : Double
  /// The rotation of the labels in radians; none outside a quarter turn
  /// either way.
  label_rotation : Double
  mut range : (Double, Double)
  mut scale : Scale
}

///|
fn Axis::new(
  data : AxisData,
  config : AxisConfig,
  theme : AxisTheme,
  title : String,
  measure : Measurer,
) -> Axis {
  let label_rotation = if config.label_rotation >= -90.0 &&
    config.label_rotation <= 90.0 {
    config.label_rotation * PI / 180.0
  } else {
    0.0
  }
  let axis = {
    config,
    title,
    theme,
    measure,
    data,
    bounding_rect: Rect::new(),
    position: "left",
    show_title: false,
    show_label: false,
    show_tick: false,
    show_axis_line: false,
    outer_padding: 0.0,
    title_text_height: 0.0,
    label_rotation,
    range: (0.0, 10.0),
    scale: LinearScale(
      @d3.LinearScale::new(domain=(0.0, 1.0), range=(0.0, 1.0)),
    ),
  }
  // The scale an axis starts with: its domain as given, whatever side
  // the axis ends up on.
  axis.scale = match data {
    Band(categories) =>
      BandScale(@d3.BandScale::new(domain=categories, range=axis.get_range()))
    Linear(min, max) =>
      LinearScale(
        @d3.LinearScale::new(domain=(min, max), range=axis.get_range()),
      )
  }
  axis
}

///|
const PI : Double = 3.141592653589793

///|
fn Axis::is_vertical(self : Axis) -> Bool {
  self.position == "left" || self.position == "right"
}

///|
fn Axis::recalculate_scale(self : Axis) -> Unit {
  self.scale = match self.data {
    Band(categories) =>
      // Points rather than bands: the first and last category sit on the
      // ends of the range.
      BandScale(
        @d3.BandScale::new(
          domain=categories,
          range=self.get_range(),
          padding_inner=1.0,
          padding_outer=0.0,
          align=0.5,
        ),
      )
    Linear(min, max) => {
      // Upwards on a vertical axis is towards smaller coordinates.
      let domain = if self.position == "left" { (max, min) } else { (min, max) }
      LinearScale(@d3.LinearScale::new(domain~, range=self.get_range()))
    }
  }
}

///|
fn Axis::set_range(self : Axis, range : (Double, Double)) -> Unit {
  self.range = range
  if self.is_vertical() {
    self.bounding_rect.height = range.1 - range.0
  } else {
    self.bounding_rect.width = range.1 - range.0
  }
  self.recalculate_scale()
}

///|
/// The range the scale maps to: the axis without its outer padding.
fn Axis::get_range(self : Axis) -> (Double, Double) {
  (self.range.0 + self.outer_padding, self.range.1 - self.outer_padding)
}

///|
fn Axis::set_position(self : Axis, position : String) -> Unit {
  self.position = position
  self.set_range(self.range)
}

///|
/// Where `value` — a category, or a number as text — is on the axis.
/// A linear axis has no place for what is not a number; a band axis puts
/// what is not one of its categories at its start.
fn Axis::scale_value(self : Axis, value : String) -> Double? {
  match self.scale {
    BandScale(scale) =>
      match scale.apply(value) {
        Some(position) => Some(position)
        None => Some(self.get_range().0)
      }
    LinearScale(scale) => scale.apply(@journeycommon.js_number(value))
  }
}

///|
/// Where a value of a plot is on the axis; an absent one has no place on
/// a linear axis.
fn Axis::scale_number(self : Axis, value : Double?) -> Double? {
  match (self.scale, value) {
    (LinearScale(scale), Some(value)) => scale.apply(value)
    (LinearScale(_), None) => None
    // A value where a category is expected: `undefined` is no category.
    (BandScale(_), Some(value)) => self.scale_value(@dom.number(value))
    (BandScale(_), None) => Some(self.get_range().0)
  }
}

///|
fn Axis::ticks(self : Axis) -> Array[Tick] {
  match self.scale {
    BandScale(_) => {
      guard self.data is Band(categories) else { [] }
      categories.map(category => {
        label: category,
        position: or_nan(self.scale_value(category)),
      })
    }
    LinearScale(scale) =>
      scale
      .ticks()
      .map(tick => {
        label: @dom.number(tick),
        position: or_nan(scale.apply(tick)),
      })
  }
}

///|
fn Axis::tick_distance(self : Axis) -> Double {
  let range = self.get_range()
  (range.0 - range.1).abs() / self.ticks().length().to_double()
}

///|
/// The largest width and height among the labels.
fn Axis::label_dimension(self : Axis) -> (Double, Double) raise Unsupported {
  self.measure.max_dimension(
    self.ticks().map(tick => tick.label),
    self.config.label_font_size,
  )
}

///|
/// Make room at both ends of the axis for half a bar.
fn Axis::recalculate_outer_padding_to_draw_bar(self : Axis) -> Unit {
  if BAR_WIDTH_TO_TICK_WIDTH_RATIO * self.tick_distance() >
    self.outer_padding * 2.0 {
    self.outer_padding = (BAR_WIDTH_TO_TICK_WIDTH_RATIO *
    self.tick_distance() /
    2.0).floor()
  }
  self.recalculate_scale()
}

///|
fn Axis::calculate_space_if_drawn_horizontally(
  self : Axis,
  available_width : Double,
  available_space_height : Double,
) -> Unit raise Unsupported {
  let config = self.config
  let mut available_height = available_space_height
  if config.show_axis_line && available_height > config.axis_line_width {
    available_height -= config.axis_line_width
    self.show_axis_line = true
  }
  if config.show_label {
    let (width, height) = self.label_dimension()
    let max_padding = MAX_OUTER_PADDING_PERCENT_FOR_WRT_LABEL * available_width
    self.outer_padding = (width / 2.0).min(max_padding)
    let mut height_required = height
    if self.position == "bottom" && self.label_rotation != 0.0 {
      height_required = height_required.max(
        (@jsmath.sin(self.label_rotation) * width).abs() +
        (@jsmath.cos(self.label_rotation) * height).abs(),
      )
    }
    height_required += config.label_padding * 2.0
    if height_required <= available_height {
      available_height -= height_required
      self.show_label = true
    }
  }
  if config.show_tick && available_height >= config.tick_length {
    self.show_tick = true
    available_height -= config.tick_length
  }
  if config.show_title && self.title != "" {
    let (_, height) = self.measure.max_dimension(
      [self.title],
      config.title_font_size,
    )
    let height_required = height + config.title_padding * 2.0
    self.title_text_height = height
    if height_required <= available_height {
      available_height -= height_required
      self.show_title = true
    }
  }
  self.bounding_rect.width = available_width
  self.bounding_rect.height = available_space_height - available_height
}

///|
fn Axis::calculate_space_if_drawn_vertical(
  self : Axis,
  available_space_width : Double,
  available_height : Double,
) -> Unit raise Unsupported {
  let config = self.config
  let mut available_width = available_space_width
  if config.show_axis_line && available_width > config.axis_line_width {
    available_width -= config.axis_line_width
    self.show_axis_line = true
  }
  if config.show_label {
    let (width, height) = self.label_dimension()
    let max_padding = MAX_OUTER_PADDING_PERCENT_FOR_WRT_LABEL * available_height
    self.outer_padding = (height / 2.0).min(max_padding)
    let width_required = width + config.label_padding * 2.0
    if width_required <= available_width {
      available_width -= width_required
      self.show_label = true
    }
  }
  if config.show_tick && available_width >= config.tick_length {
    self.show_tick = true
    available_width -= config.tick_length
  }
  if config.show_title && self.title != "" {
    let (_, height) = self.measure.max_dimension(
      [self.title],
      config.title_font_size,
    )
    let width_required = height + config.title_padding * 2.0
    self.title_text_height = height
    if width_required <= available_width {
      available_width -= width_required
      self.show_title = true
    }
  }
  self.bounding_rect.width = available_space_width - available_width
  self.bounding_rect.height = available_height
}

///|
/// Take what the axis needs of the space on offer; returns what it took.
fn Axis::calculate_space(
  self : Axis,
  width : Double,
  height : Double,
) -> (Double, Double) raise Unsupported {
  if self.is_vertical() {
    self.calculate_space_if_drawn_vertical(width, height)
  } else {
    self.calculate_space_if_drawn_horizontally(width, height)
  }
  self.recalculate_scale()
  (self.bounding_rect.width, self.bounding_rect.height)
}

///|
fn Axis::set_bounding_box_xy(self : Axis, x : Double, y : Double) -> Unit {
  self.bounding_rect.x = x
  self.bounding_rect.y = y
}

///|
/// How far rotated labels move so that they still start under their
/// tick: half the labels' width or height, by the sine of the rotation.
fn Axis::offset_by_rotation(
  self : Axis,
  width : Bool,
) -> Double raise Unsupported {
  if self.label_rotation == 0.0 {
    return 0.0
  }
  let dimension = self.label_dimension()
  @jsmath.sin(self.label_rotation) *
  (if width { dimension.0 } else { dimension.1 }) /
  2.0
}

///|
fn Axis::axis_line(self : Axis, class : String, path : String) -> Drawable {
  {
    groups: ["\{self.position}-axis", class],
    shapes: Paths([
      {
        path,
        stroke_fill: self.theme.axis_line_color,
        stroke_width: self.config.axis_line_width,
      },
    ]),
  }
}

///|
fn Axis::tick_paths(self : Axis, paths : Array[String]) -> Drawable {
  {
    groups: ["\{self.position}-axis", "ticks"],
    shapes: Paths(
      paths.map(path => {
        path,
        stroke_fill: self.theme.tick_color,
        stroke_width: self.config.tick_width,
      }),
    ),
  }
}

///|
fn Axis::label_text(
  self : Axis,
  tick : Tick,
  x : Double,
  y : Double,
  rotation : Double,
  vertical_pos : String,
  horizontal_pos : String,
) -> TextData {
  {
    text: tick.label,
    x: @dom.number(x),
    y: @dom.number(y),
    fill: self.theme.label_color,
    font_size: self.config.label_font_size,
    rotation,
    vertical_pos,
    horizontal_pos,
  }
}

///|
fn Axis::title_text(
  self : Axis,
  x : Double,
  y : Double,
  rotation : Double,
) -> Drawable {
  {
    groups: ["\{self.position}-axis", "title"],
    shapes: Texts([
      {
        text: self.title,
        x: @dom.number(x),
        y: @dom.number(y),
        fill: self.theme.title_color,
        font_size: self.config.title_font_size,
        rotation,
        vertical_pos: "top",
        horizontal_pos: "center",
      },
    ]),
  }
}

///|
fn Axis::drawable_elements_for_left(self : Axis) -> Array[Drawable] {
  let n = @dom.number
  let config = self.config
  let rect = self.bounding_rect
  let elements = []
  if self.show_axis_line {
    let x = rect.x + rect.width - config.axis_line_width / 2.0
    elements.push(
      // The class is misspelt upstream.
      self.axis_line(
        "axisl-line",
        "M \{n(x)},\{n(rect.y)} L \{n(x)},\{n(rect.y + rect.height)} ",
      ),
    )
  }
  if self.show_label {
    let x = rect.x +
      rect.width -
      (if self.show_label { config.label_padding } else { 0.0 }) -
      (if self.show_tick { config.tick_length } else { 0.0 }) -
      (if self.show_axis_line { config.axis_line_width } else { 0.0 })
    elements.push({
      groups: ["left-axis", "label"],
      shapes: Texts(
        self
        .ticks()
        .map(tick => {
          self.label_text(tick, x, tick.position, 0.0, "middle", "right")
        }),
      ),
    })
  }
  if self.show_tick {
    let x = rect.x +
      rect.width -
      (if self.show_axis_line { config.axis_line_width } else { 0.0 })
    elements.push(
      self.tick_paths(
        self
        .ticks()
        .map(tick => {
          let y = n(tick.position)
          "M \{n(x)},\{y} L \{n(x - config.tick_length)},\{y}"
        }),
      ),
    )
  }
  if self.show_title {
    elements.push(
      self.title_text(
        rect.x + config.title_padding,
        rect.y + rect.height / 2.0,
        270.0,
      ),
    )
  }
  elements
}

///|
fn Axis::drawable_elements_for_bottom(
  self : Axis,
) -> Array[Drawable] raise Unsupported {
  let n = @dom.number
  let config = self.config
  let rect = self.bounding_rect
  let elements = []
  if self.show_axis_line {
    let y = rect.y + config.axis_line_width / 2.0
    elements.push(
      self.axis_line(
        "axis-line",
        "M \{n(rect.x)},\{n(y)} L \{n(rect.x + rect.width)},\{n(y)}",
      ),
    )
  }
  if self.show_label {
    let x_offset = self.offset_by_rotation(false)
    let y = rect.y +
      config.label_padding +
      (if self.show_tick { config.tick_length } else { 0.0 }) +
      (if self.show_axis_line { config.axis_line_width } else { 0.0 }) +
      self.offset_by_rotation(true).abs()
    let rotation = self.label_rotation * 180.0 / PI
    elements.push({
      groups: ["bottom-axis", "label"],
      shapes: Texts(
        self
        .ticks()
        .map(tick => {
          self.label_text(
            tick,
            tick.position + x_offset,
            y,
            rotation,
            "top",
            "center",
          )
        }),
      ),
    })
  }
  if self.show_tick {
    let y = rect.y +
      (if self.show_axis_line { config.axis_line_width } else { 0.0 })
    elements.push(
      self.tick_paths(
        self
        .ticks()
        .map(tick => {
          let x = n(tick.position)
          "M \{x},\{n(y)} L \{x},\{n(y + config.tick_length)}"
        }),
      ),
    )
  }
  if self.show_title {
    elements.push(
      self.title_text(
        self.range.0 + (self.range.1 - self.range.0) / 2.0,
        rect.y + rect.height - config.title_padding - self.title_text_height,
        0.0,
      ),
    )
  }
  elements
}

///|
fn Axis::drawable_elements_for_top(self : Axis) -> Array[Drawable] {
  let n = @dom.number
  let config = self.config
  let rect = self.bounding_rect
  let elements = []
  if self.show_axis_line {
    let y = rect.y + rect.height - config.axis_line_width / 2.0
    elements.push(
      self.axis_line(
        "axis-line",
        "M \{n(rect.x)},\{n(y)} L \{n(rect.x + rect.width)},\{n(y)}",
      ),
    )
  }
  if self.show_label {
    let y = rect.y +
      (if self.show_title {
        self.title_text_height + config.title_padding * 2.0
      } else {
        0.0
      }) +
      config.label_padding
    elements.push({
      groups: ["top-axis", "label"],
      shapes: Texts(
        self
        .ticks()
        .map(tick => {
          self.label_text(tick, tick.position, y, 0.0, "top", "center")
        }),
      ),
    })
  }
  if self.show_tick {
    let y = rect.y
    let line_width = if self.show_axis_line {
      config.axis_line_width
    } else {
      0.0
    }
    elements.push(
      self.tick_paths(
        self
        .ticks()
        .map(tick => {
          let x = n(tick.position)
          "M \{x},\{n(y + rect.height - line_width)} L \{x},\{n(y + rect.height - config.tick_length - line_width)}"
        }),
      ),
    )
  }
  if self.show_title {
    elements.push(
      self.title_text(
        rect.x + rect.width / 2.0,
        rect.y + config.title_padding,
        0.0,
      ),
    )
  }
  elements
}

///|
fn Axis::drawable_elements(self : Axis) -> Array[Drawable] raise Unsupported {
  match self.position {
    "left" => self.drawable_elements_for_left()
    "bottom" => self.drawable_elements_for_bottom()
    "top" => self.drawable_elements_for_top()
    _ => []
  }
}
