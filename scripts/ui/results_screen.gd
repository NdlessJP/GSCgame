class_name ResultsScreen
extends Control
## End of battle screen: outcome, rewards and the way back into the loop.

var _outcome_label: Label = null
var _quest_label: Label = null
var _summary_box: VBoxContainer = null
var _party_box: VBoxContainer = null
var _report_box: VBoxContainer = null


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
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	_outcome_label = UiStyle.make_label("", 44, UiStyle.ACCENT)
	_outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_outcome_label)

	_quest_label = UiStyle.make_label("", 15, UiStyle.TEXT_DIM)
	_quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_quest_label)

	root.add_child(UiStyle.separator(6))

	var center: CenterContainer = CenterContainer.new()
	root.add_child(center)

	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	center.add_child(columns)

	# Rewards.
	var reward_panel: PanelContainer = PanelContainer.new()
	reward_panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PANEL, UiStyle.BORDER, 8, 1))
	reward_panel.custom_minimum_size = Vector2(330, 0)
	columns.add_child(reward_panel)
	var reward_box: VBoxContainer = VBoxContainer.new()
	reward_box.add_theme_constant_override("separation", 5)
	reward_panel.add_child(reward_box)
	reward_box.add_child(UiStyle.make_label("Rewards", 18, UiStyle.ACCENT))
	_summary_box = VBoxContainer.new()
	_summary_box.add_theme_constant_override("separation", 4)
	reward_box.add_child(_summary_box)

	# Battle report.
	var report_panel: PanelContainer = PanelContainer.new()
	report_panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PANEL, UiStyle.BORDER, 8, 1))
	report_panel.custom_minimum_size = Vector2(300, 0)
	columns.add_child(report_panel)
	var report_box: VBoxContainer = VBoxContainer.new()
	report_box.add_theme_constant_override("separation", 5)
	report_panel.add_child(report_box)
	report_box.add_child(UiStyle.make_label("Battle Report", 18, UiStyle.ACCENT))
	_report_box = VBoxContainer.new()
	_report_box.add_theme_constant_override("separation", 4)
	report_box.add_child(_report_box)

	# Party progress.
	var party_panel: PanelContainer = PanelContainer.new()
	party_panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PANEL, UiStyle.BORDER, 8, 1))
	party_panel.custom_minimum_size = Vector2(380, 0)
	columns.add_child(party_panel)
	var party_box: VBoxContainer = VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 5)
	party_panel.add_child(party_box)
	party_box.add_child(UiStyle.make_label("Party Progress", 18, UiStyle.ACCENT))
	_party_box = VBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 4)
	party_box.add_child(_party_box)

	root.add_child(UiStyle.separator(8))

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 10)
	root.add_child(button_row)

	var party_button: Button = UiStyle.make_button("Party Setup", 15, 40)
	party_button.custom_minimum_size = Vector2(190, 40)
	party_button.pressed.connect(func() -> void: Game.goto_scene("res://scenes/party/party_setup.tscn"))
	button_row.add_child(party_button)

	var retry: Button = UiStyle.make_button("Retry Quest", 15, 40)
	retry.custom_minimum_size = Vector2(190, 40)
	retry.pressed.connect(func() -> void: Game.goto_scene("res://scenes/battle/battle.tscn"))
	button_row.add_child(retry)

	var quests: Button = UiStyle.make_button("Quest Board", 15, 40)
	quests.custom_minimum_size = Vector2(190, 40)
	quests.pressed.connect(func() -> void: Game.goto_scene("res://scenes/quests/quest_select.tscn"))
	button_row.add_child(quests)

	var menu: Button = UiStyle.make_button("Main Menu", 15, 40)
	menu.custom_minimum_size = Vector2(190, 40)
	menu.pressed.connect(func() -> void: Game.goto_scene("res://scenes/main_menu/main_menu.tscn"))
	button_row.add_child(menu)

	_populate()


## Fills the battle report column from the statistics the controller kept
## during the fight.
func _populate_report(stats: Dictionary) -> void:
	for child: Node in _report_box.get_children():
		child.queue_free()
	if stats.is_empty():
		_report_box.add_child(UiStyle.make_label("No battle data.", 12, UiStyle.TEXT_DIM))
		return
	var duration: float = float(stats.get("duration", 0.0))
	_report_box.add_child(UiStyle.make_label("Time: %.1fs" % duration, 13))
	_report_box.add_child(UiStyle.make_label("Damage dealt: %d" % int(round(float(stats.get("damage_dealt", 0.0)))), 13))
	_report_box.add_child(UiStyle.make_label("Damage taken: %d" % int(round(float(stats.get("damage_taken", 0.0)))), 13))
	_report_box.add_child(UiStyle.make_label("Abilities used: %d" % int(stats.get("abilities", 0)), 13))
	_report_box.add_child(UiStyle.make_label("Breaks triggered: %d" % int(stats.get("breaks", 0)), 13, UiStyle.BREAK))
	_report_box.add_child(UiStyle.make_label("Enemies defeated: %d" % int(stats.get("defeated", 0)), 13))


func _populate() -> void:
	var victory: bool = Game.last_battle_victory
	_outcome_label.text = "Victory" if victory else "Defeat"
	_outcome_label.add_theme_color_override("font_color", UiStyle.GOOD if victory else UiStyle.DANGER)
	var quest: QuestDef = Game.database.quest(Game.pending_quest_id)
	_quest_label.text = quest.display_name if quest != null else "Unknown quest"

	var results: Dictionary = Game.last_results
	if not victory or results.is_empty():
		_summary_box.add_child(UiStyle.make_label("No rewards were granted.", 13, UiStyle.TEXT_DIM))
	else:
		_summary_box.add_child(UiStyle.make_label("Sigil shards:  +%d" % int(results.get("currency", 0)), 14, UiStyle.ACCENT))
		_summary_box.add_child(UiStyle.make_label("Experience:  +%d" % int(results.get("xp", 0)), 14, UiStyle.ACCENT))
		var items: Array = results.get("items", [])
		if items.is_empty():
			_summary_box.add_child(UiStyle.make_label("No new equipment.", 12, UiStyle.TEXT_DIM))
		else:
			for instance_id: Variant in items:
				var instance: ItemInstance = Game.state.inventory.find(String(instance_id))
				if instance == null:
					continue
				var item_def: EquipmentDef = Game.database.equipment_def(instance.item_id)
				if item_def != null:
					_summary_box.add_child(UiStyle.make_label("New item: %s" % item_def.display_name, 13, UiStyle.GOOD))

	_populate_report(results.get("stats", {}) as Dictionary)

	var levels: Dictionary = results.get("levels", {})
	if levels.is_empty():
		_party_box.add_child(UiStyle.make_label("No experience was gained.", 13, UiStyle.TEXT_DIM))
		return
	for character_id: Variant in levels.keys():
		var def: CharacterDef = Game.database.character(StringName(String(character_id)))
		if def == null:
			continue
		var entry: Dictionary = levels[character_id]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_party_box.add_child(row)
		var name_label: Label = UiStyle.make_label(def.display_name, 13, Elements.element_color(def.element))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var level_text: String = "Level %d" % int(entry.get("level", 1))
		var gained: int = int(entry.get("levels_gained", 0))
		if gained > 0:
			level_text += "  (+%d)" % gained
		row.add_child(UiStyle.make_label(level_text, 13, UiStyle.ACCENT))
