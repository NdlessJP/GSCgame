class_name PauseMenu
extends CanvasLayer
## Pause overlay with resume, retry and return options.
##
## The overlay keeps processing while the tree is paused so the buttons stay
## usable, while the battle timers stay frozen.

signal resume_pressed()
signal retry_pressed()
signal quit_pressed()

var _root: Control = null
var _panel: PanelContainer = null


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.13, 0.14, 0.19, 0.99), UiStyle.ACCENT, 10, 2))
	center.add_child(_panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	var title: Label = UiStyle.make_label("Paused", 22, UiStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume: Button = UiStyle.make_button("Resume", 14, 38)
	resume.custom_minimum_size = Vector2(260, 38)
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	box.add_child(resume)

	var retry: Button = UiStyle.make_button("Retry Battle", 14, 38)
	retry.custom_minimum_size = Vector2(260, 38)
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	box.add_child(retry)

	var quit: Button = UiStyle.make_button("Return to Quest Board", 14, 38)
	quit.custom_minimum_size = Vector2(260, 38)
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	box.add_child(quit)

	var hint: Label = UiStyle.make_label(
		"Controls: Q W E R = Skills   A S D F = Arts\nZ X C V = True Arts   T = cycle target   P = pause",
		11, UiStyle.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	_root.visible = false


func open() -> void:
	_root.visible = true


func close() -> void:
	_root.visible = false
