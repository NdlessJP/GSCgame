class_name HelpOverlay
extends Control
## Reusable "Controls" panel.
##
## The game is fully playable with the mouse; the keyboard shortcuts are
## optional extras.  The overlay lists both so a new player can find them.

const ROWS: Array = [
	["Everything", "Mouse: click an enemy to target it, click the panel buttons"],
	["Skill", "Q  W  E  R   (party member 1 - 4)"],
	["Arts (100)", "A  S  D  F   (party member 1 - 4)"],
	["True Arts (200)", "Z  X  C  V   (party member 1 - 4)"],
	["Equipment actives", "1  2  3   (party member 1)"],
	["Cycle target", "T"],
	["Pause", "P  or  Esc"],
	["Battle speed", "The 1x / 2x / 3x button in the top bar"],
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The preset is computed against the parent size, so the offsets have to be
	# cleared explicitly when the overlay is added to an already sized parent.
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.05, 0.78)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PANEL, UiStyle.ACCENT, 10, 2))
	panel.custom_minimum_size = Vector2(560, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title: Label = UiStyle.make_label("Controls", 22, UiStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var hint: Label = UiStyle.make_label(
		"Every action can be done with the mouse.  The keys below are shortcuts.",
		12, UiStyle.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	box.add_child(UiStyle.separator(4))

	for row: Array in ROWS:
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		box.add_child(line)
		var action: Label = UiStyle.make_label(String(row[0]), 13, UiStyle.TEXT)
		action.custom_minimum_size = Vector2(170, 0)
		line.add_child(action)
		var keys: Label = UiStyle.make_label(String(row[1]), 13, UiStyle.TEXT_DIM)
		keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(keys)

	box.add_child(UiStyle.separator(4))

	var close: Button = UiStyle.make_button("Close", 13, 32)
	close.pressed.connect(func() -> void: visible = false)
	var close_row: HBoxContainer = HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close_row.add_child(close)
	box.add_child(close_row)
