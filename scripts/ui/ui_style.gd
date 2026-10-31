class_name UiStyle
extends RefCounted
## Shared colours and style box helpers so every screen looks the same.

const BG: Color = Color(0.055, 0.06, 0.086)
const PANEL: Color = Color(0.115, 0.125, 0.17, 0.96)
const PANEL_SOFT: Color = Color(0.15, 0.16, 0.21, 0.95)
const BORDER: Color = Color(0.28, 0.30, 0.39)
const TEXT: Color = Color(0.91, 0.92, 0.95)
const TEXT_DIM: Color = Color(0.62, 0.64, 0.72)
const ACCENT: Color = Color(0.95, 0.72, 0.35)
const HP: Color = Color(0.80, 0.26, 0.30)
const ARTS: Color = Color(0.38, 0.76, 1.0)
const BREAK: Color = Color(0.35, 0.86, 0.95)
const DANGER: Color = Color(0.95, 0.40, 0.35)
const GOOD: Color = Color(0.45, 0.88, 0.55)
const DISABLED: Color = Color(0.40, 0.41, 0.48)


static func panel(bg: Color = PANEL, border: Color = BORDER, radius: int = 6, width: int = 1) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func fill(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style


## A thin bar used for HP, arts and break meters.
static func bar_style(color: Color, background: Color = Color(0.05, 0.05, 0.08, 0.9)) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(3)
	style.border_color = color.darkened(0.4)
	style.set_border_width_all(1)
	return style


static func bar_fill(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style


static func make_label(text: String, size: int = 14, color: Color = TEXT) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


static func make_button(text: String, size: int = 12, min_height: int = 26) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", size)
	button.focus_mode = Control.FOCUS_NONE
	# Long labels are trimmed with an ellipsis instead of stretching the
	# button, which keeps the layout stable.  The minimum width is derived
	# from the text so short buttons ("X", "View") stay compact.
	if "text_overrun_behavior" in button:
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var font: Font = ThemeDB.fallback_font
	var width: float = 0.0
	if font != null:
		width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	button.custom_minimum_size = Vector2(minf(width + 14.0, 112.0), min_height)
	return button


## A small coloured chip used for elements and statuses.
static func make_chip(text: String, color: Color, size: int = 11) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = panel(color.darkened(0.55), color, 4, 1)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = make_label(text, size, color)
	panel.add_child(label)
	return panel


static func separator(height: int = 6) -> Control:
	var control: Control = Control.new()
	control.custom_minimum_size = Vector2(0, height)
	return control
