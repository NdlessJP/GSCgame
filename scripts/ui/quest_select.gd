class_name QuestSelect
extends Control
## Quest board: pick one of the three quests and start it.

var _quest_list: VBoxContainer = null
var _currency_label: Label = null
var _hint_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()


func _build() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = UiStyle.BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# Header.
	var header: HBoxContainer = HBoxContainer.new()
	root.add_child(header)
	var title: Label = UiStyle.make_label("Quest Board", 28, UiStyle.ACCENT)
	header.add_child(title)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_currency_label = UiStyle.make_label("", 14, UiStyle.TEXT_DIM)
	header.add_child(_currency_label)
	var party_button: Button = UiStyle.make_button("Party & Gear", 13, 30)
	party_button.pressed.connect(func() -> void: Game.goto_scene("res://scenes/party/party_setup.tscn"))
	header.add_child(party_button)
	var menu_button: Button = UiStyle.make_button("Main Menu", 13, 30)
	menu_button.pressed.connect(func() -> void: Game.goto_scene("res://scenes/main_menu/main_menu.tscn"))
	header.add_child(menu_button)

	_hint_label = UiStyle.make_label(
		"All six heroes are available for testing.  Press U to unlock every quest.",
		12, UiStyle.TEXT_DIM)
	root.add_child(_hint_label)

	root.add_child(UiStyle.separator(4))

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_quest_list = VBoxContainer.new()
	_quest_list.add_theme_constant_override("separation", 10)
	_quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_quest_list)


func _refresh() -> void:
	if _quest_list == null:
		return
	_currency_label.text = "Sigil shards: %d" % Game.state.currency
	for child: Node in _quest_list.get_children():
		child.queue_free()
	var ordered: Array = Game.database.quest_ids()
	ordered.sort_custom(func(a: Variant, b: Variant) -> bool:
		var qa: QuestDef = Game.database.quests[a]
		var qb: QuestDef = Game.database.quests[b]
		return qa.recommended_level < qb.recommended_level)
	for quest_id: Variant in ordered:
		var quest: QuestDef = Game.database.quests[quest_id]
		_quest_list.add_child(_build_quest_card(quest))


func _build_quest_card(quest: QuestDef) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var unlocked: bool = Game.is_quest_unlocked(quest.id)
	var completed: bool = Game.is_quest_completed(quest.id)
	var border: Color = UiStyle.BORDER if unlocked else Color(0.35, 0.32, 0.30)
	panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PANEL, border, 8, 2))

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var header: HBoxContainer = HBoxContainer.new()
	box.add_child(header)
	var title: Label = UiStyle.make_label(quest.display_name, 22, UiStyle.ACCENT if unlocked else UiStyle.TEXT_DIM)
	header.add_child(title)
	var level: Label = UiStyle.make_label("Recommended level %d" % quest.recommended_level, 12, UiStyle.TEXT_DIM)
	header.add_child(level)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var status_text: String = "Completed" if completed else ("Available" if unlocked else "Locked")
	var status_color: Color = UiStyle.GOOD if completed else (UiStyle.TEXT if unlocked else UiStyle.DISABLED)
	header.add_child(UiStyle.make_chip(status_text, status_color, 11))

	var description: Label = UiStyle.make_label(quest.description, 13, UiStyle.TEXT)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(600, 0)
	box.add_child(description)

	# Enemy composition.
	var composition: String = _composition_text(quest)
	var comp_label: Label = UiStyle.make_label("Encounter: %s" % composition, 12, UiStyle.TEXT_DIM)
	comp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comp_label.custom_minimum_size = Vector2(600, 0)
	box.add_child(comp_label)

	var footer: HBoxContainer = HBoxContainer.new()
	box.add_child(footer)
	var rewards: Label = UiStyle.make_label(
		"Rewards: %d XP   %d sigil shards%s" % [
			quest.reward_xp, quest.reward_currency,
			("   + " + _items_text(quest)) if not quest.reward_items.is_empty() else "",
		], 12, UiStyle.ACCENT)
	footer.add_child(rewards)
	var spacer2: Control = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer2)

	var start_text: String = "Locked"
	if unlocked:
		start_text = "Replay Quest" if completed else "Start Quest"
	var start: Button = UiStyle.make_button(start_text, 14, 34)
	start.custom_minimum_size = Vector2(150, 34)
	start.disabled = not unlocked
	if unlocked:
		start.pressed.connect(func() -> void: _start_quest(quest))
	else:
		var required: QuestDef = Game.database.quest(quest.requires_quest)
		start.tooltip_text = "Complete %s first." % (required.display_name if required != null else "the previous quest")
	footer.add_child(start)
	return panel


func _composition_text(quest: QuestDef) -> String:
	var counts: Dictionary = {}
	var order: Array = []
	for wave: WaveDef in quest.waves:
		for enemy_id: StringName in wave.enemy_ids:
			if not counts.has(enemy_id):
				counts[enemy_id] = 0
				order.append(enemy_id)
			counts[enemy_id] = int(counts[enemy_id]) + 1
	var parts: Array = []
	for enemy_id: Variant in order:
		var def: EnemyDef = Game.database.enemy(enemy_id)
		var name: String = def.display_name if def != null else String(enemy_id)
		parts.append("%s x%d" % [name, int(counts[enemy_id])])
	return ",  ".join(parts)


func _items_text(quest: QuestDef) -> String:
	var names: Array = []
	for item_id: StringName in quest.reward_items:
		var item: EquipmentDef = Game.database.equipment_def(item_id)
		names.append(item.display_name if item != null else String(item_id))
	return ", ".join(names)


func _start_quest(quest: QuestDef) -> void:
	Game.pending_quest_id = quest.id
	Game.goto_scene("res://scenes/battle/battle.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event
		if key.keycode == KEY_U:
			for quest_id: Variant in Game.database.quest_ids():
				Game.unlock_quest(StringName(String(quest_id)))
			Game.save_game()
			_refresh()
