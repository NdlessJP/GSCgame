class_name MainMenu
extends Control
## Title screen.

var _currency_label: Label = null
var _status_label: Label = null
var _help_overlay: HelpOverlay = null
var _volume_slider: HSlider = null
var _volume_label: Label = null
var _reset_confirm: HBoxContainer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = UiStyle.BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title: Label = UiStyle.make_label("ASHEN VANGUARD", 54, UiStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var subtitle: Label = UiStyle.make_label(
		"A party based real-time RPG prototype  -  break gauges, arts and equipment actives",
		14, UiStyle.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)

	root.add_child(UiStyle.separator(18))

	var center: CenterContainer = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	center.add_child(buttons)

	var adventure: Button = UiStyle.make_button("Enter the Ember Watch", 16, 42)
	adventure.custom_minimum_size = Vector2(320, 42)
	adventure.pressed.connect(func() -> void: Game.goto_scene("res://scenes/party/party_setup.tscn"))
	buttons.add_child(adventure)

	var quests: Button = UiStyle.make_button("Quest Board", 16, 42)
	quests.custom_minimum_size = Vector2(320, 42)
	quests.pressed.connect(func() -> void: Game.goto_scene("res://scenes/quests/quest_select.tscn"))
	buttons.add_child(quests)

	var party: Button = UiStyle.make_button("Party & Gear", 16, 42)
	party.custom_minimum_size = Vector2(320, 42)
	party.pressed.connect(func() -> void: Game.goto_scene("res://scenes/party/party_setup.tscn"))
	buttons.add_child(party)

	var help: Button = UiStyle.make_button("Controls", 16, 42)
	help.pressed.connect(_on_help_pressed)
	buttons.add_child(help)

	var quit: Button = UiStyle.make_button("Quit", 16, 42)
	quit.custom_minimum_size = Vector2(320, 42)
	quit.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(quit)

	root.add_child(UiStyle.separator(10))

	# --- settings ---------------------------------------------------------
	var settings: HBoxContainer = HBoxContainer.new()
	settings.add_theme_constant_override("separation", 10)
	settings.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(settings)
	settings.add_child(UiStyle.make_label("Volume", 13, UiStyle.TEXT_DIM))
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.custom_minimum_size = Vector2(180, 20)
	_volume_slider.value = Game.state.volume if Game.state != null else 0.8
	_volume_slider.value_changed.connect(_on_volume_changed)
	settings.add_child(_volume_slider)
	_volume_label = UiStyle.make_label("", 13, UiStyle.TEXT_DIM)
	_volume_label.custom_minimum_size = Vector2(46, 0)
	settings.add_child(_volume_label)

	var reset: Button = UiStyle.make_button("Reset profile", 12, 26)
	reset.tooltip_text = "Erase all progress and start over"
	reset.pressed.connect(_on_reset_pressed)
	settings.add_child(reset)

	# The confirmation row stays hidden until the reset button is used.
	_reset_confirm = HBoxContainer.new()
	_reset_confirm.alignment = BoxContainer.ALIGNMENT_CENTER
	_reset_confirm.add_theme_constant_override("separation", 8)
	_reset_confirm.visible = false
	root.add_child(_reset_confirm)
	_reset_confirm.add_child(UiStyle.make_label("Erase all progress?", 13, UiStyle.DANGER))
	var erase: Button = UiStyle.make_button("Erase", 12, 26)
	erase.pressed.connect(_on_reset_confirmed)
	_reset_confirm.add_child(erase)
	var cancel: Button = UiStyle.make_button("Cancel", 12, 26)
	cancel.pressed.connect(func() -> void: _reset_confirm.visible = false)
	_reset_confirm.add_child(cancel)

	var footer: HBoxContainer = HBoxContainer.new()
	root.add_child(footer)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_currency_label = UiStyle.make_label("", 13, UiStyle.TEXT_DIM)
	footer.add_child(_currency_label)

	_status_label = UiStyle.make_label("", 12, UiStyle.TEXT_DIM)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status_label)

	_help_overlay = HelpOverlay.new()
	_help_overlay.visible = false
	add_child(_help_overlay)

	_refresh()


## Stores the new master volume in the profile.
func _on_volume_changed(value: float) -> void:
	Game.set_volume(value)
	_refresh_volume_label()


func _on_reset_pressed() -> void:
	if _reset_confirm != null:
		_reset_confirm.visible = true


func _on_reset_confirmed() -> void:
	if _reset_confirm != null:
		_reset_confirm.visible = false
	Game.new_game()
	if _volume_slider != null and Game.state != null:
		_volume_slider.value = Game.state.volume
	_refresh_volume_label()


func _refresh_volume_label() -> void:
	if _volume_label == null or Game.state == null:
		return
	_volume_label.text = "%d%%" % int(round(Game.state.volume * 100.0))


## Shows or hides the controls overlay.
func _on_help_pressed() -> void:
	if _help_overlay != null:
		_help_overlay.visible = not _help_overlay.visible


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _currency_label != null and Game.state != null:
		_currency_label.text = "Sigil shards: %d" % Game.state.currency
	_refresh_volume_label()
	if _status_label != null and Game.state != null:
		var message: String = Game.last_save_message()
		if message != "":
			_status_label.text = message
