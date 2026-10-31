class_name MainMenu
extends Control
## Title screen.

var _currency_label: Label = null
var _status_label: Label = null


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

	var quit: Button = UiStyle.make_button("Quit", 16, 42)
	quit.custom_minimum_size = Vector2(320, 42)
	quit.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(quit)

	root.add_child(UiStyle.separator(10))

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

	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _currency_label != null and Game.state != null:
		_currency_label.text = "Sigil shards: %d" % Game.state.currency
	if _status_label != null and Game.state != null:
		var message: String = Game.last_save_message()
		if message != "":
			_status_label.text = message
