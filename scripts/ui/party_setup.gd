class_name PartySetup
extends Control
## Party screen: inspect characters, assign the four active slots and manage
## equipment and inventory.

var _selected_id: StringName = &""
var _roster_box: VBoxContainer = null
var _party_box: VBoxContainer = null
var _detail_box: VBoxContainer = null
var _currency_label: Label = null
var _inventory_box: VBoxContainer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	if Game.database.character_ids().is_empty():
		return
	_selected_id = StringName(String(Game.database.character_ids()[0]))
	_refresh_all()


func _build() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = UiStyle.BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# Header.
	var header: HBoxContainer = HBoxContainer.new()
	root.add_child(header)
	header.add_child(UiStyle.make_label("Party & Gear", 28, UiStyle.ACCENT))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_currency_label = UiStyle.make_label("", 14, UiStyle.TEXT_DIM)
	header.add_child(_currency_label)
	var quests: Button = UiStyle.make_button("Quest Board", 13, 30)
	quests.pressed.connect(func() -> void: Game.goto_scene("res://scenes/quests/quest_select.tscn"))
	header.add_child(quests)
	var menu: Button = UiStyle.make_button("Main Menu", 13, 30)
	menu.pressed.connect(func() -> void: Game.goto_scene("res://scenes/main_menu/main_menu.tscn"))
	header.add_child(menu)

	# Body.
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	_roster_box = _column(body, "Roster", 300)
	_party_box = _column(body, "Active Party (4 slots)", 250)
	_detail_box = _column(body, "Character", 520)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var inventory_column: VBoxContainer = _column(body, "Inventory", 320)
	_inventory_box = VBoxContainer.new()
	_inventory_box.add_theme_constant_override("separation", 3)
	inventory_column.add_child(_inventory_box)


func _column(parent: HBoxContainer, title: String, width: int) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PANEL, UiStyle.BORDER, 8, 1))
	panel.custom_minimum_size = Vector2(width, 0)
	parent.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var label: Label = UiStyle.make_label(title, 16, UiStyle.ACCENT)
	box.add_child(label)
	box.add_child(UiStyle.separator(2))

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content


# --------------------------------------------------------------------------
# Refresh
# --------------------------------------------------------------------------

func _refresh_all() -> void:
	_currency_label.text = "Sigil shards: %d" % Game.state.currency
	_refresh_roster()
	_refresh_party()
	_refresh_detail()
	_refresh_inventory()


func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()


func _refresh_roster() -> void:
	_clear(_roster_box)
	var ids: Array = Game.database.character_ids()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var da: CharacterDef = Game.database.characters[a]
		var db: CharacterDef = Game.database.characters[b]
		return da.roster_order < db.roster_order)
	for id: Variant in ids:
		var character_id: StringName = StringName(String(id))
		var def: CharacterDef = Game.database.characters[id]
		var level: int = Game.state.character_level(character_id)
		var xp: int = Game.state.character_xp(character_id)
		var button: Button = UiStyle.make_button("", 13, 42)
		button.custom_minimum_size = Vector2(0, 42)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s   Lv %d\n%s   %d XP" % [def.display_name, level, def.role, xp]
		button.add_theme_color_override("font_color", Elements.element_color(def.element))
		if character_id == _selected_id:
			button.add_theme_stylebox_override("normal", UiStyle.panel(UiStyle.PANEL_SOFT, UiStyle.ACCENT, 6, 2))
			button.add_theme_stylebox_override("hover", UiStyle.panel(UiStyle.PANEL_SOFT, UiStyle.ACCENT, 6, 2))
		button.pressed.connect(func() -> void:
			_selected_id = character_id
			_refresh_all())
		_roster_box.add_child(button)


func _refresh_party() -> void:
	_clear(_party_box)
	for index in range(4):
		var slot_panel: PanelContainer = PanelContainer.new()
		slot_panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PANEL_SOFT, UiStyle.BORDER, 6, 1))
		_party_box.add_child(slot_panel)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		slot_panel.add_child(row)

		var character_id: StringName = &""
		if index < Game.state.party.size():
			character_id = Game.state.party[index]
		var def: CharacterDef = Game.database.character(character_id) if character_id != &"" else null
		var name_label: Label = UiStyle.make_label(
			def.display_name if def != null else "Empty slot",
			13, Elements.element_color(def.element) if def != null else UiStyle.TEXT_DIM)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		if def != null:
			var inspect: Button = UiStyle.make_button("View", 11, 24)
			inspect.pressed.connect(func() -> void:
				_selected_id = character_id
				_refresh_all())
			row.add_child(inspect)
			var remove: Button = UiStyle.make_button("X", 11, 24)
			remove.pressed.connect(func() -> void:
				Game.remove_from_party(character_id)
				Game.save_game()
				_refresh_all())
			row.add_child(remove)

		if def != null:
			var stats: Label = UiStyle.make_label(
				"HP %d   ATK %d   DEF %d" % [int(def.max_hp_at(Game.state.character_level(character_id))),
					int(def.attack_at(Game.state.character_level(character_id))),
					int(def.defense_at(Game.state.character_level(character_id)))],
				11, UiStyle.TEXT_DIM)
			_party_box.add_child(stats)


func _refresh_detail() -> void:
	_clear(_detail_box)
	if _selected_id == &"":
		_detail_box.add_child(UiStyle.make_label("Select a character.", 13, UiStyle.TEXT_DIM))
		return
	var def: CharacterDef = Game.database.character(_selected_id)
	if def == null:
		return
	var level: int = Game.state.character_level(_selected_id)
	var xp: int = Game.state.character_xp(_selected_id)

	# Header.
	var header: HBoxContainer = HBoxContainer.new()
	_detail_box.add_child(header)
	header.add_child(UiStyle.make_label(def.display_name, 20, Elements.element_color(def.element)))
	header.add_child(UiStyle.make_chip(Elements.element_name(def.element), Elements.element_color(def.element), 11))
	header.add_child(UiStyle.make_chip(def.role, UiStyle.TEXT_DIM, 11))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(UiStyle.make_label("Level %d" % level, 14, UiStyle.ACCENT))

	var lore: Label = UiStyle.make_label(def.description, 12, UiStyle.TEXT_DIM)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.custom_minimum_size = Vector2(260, 0)
	_detail_box.add_child(lore)

	# XP bar.
	var xp_row: HBoxContainer = HBoxContainer.new()
	_detail_box.add_child(xp_row)
	xp_row.add_child(UiStyle.make_label("XP", 11, UiStyle.TEXT_DIM))
	var xp_bar: ProgressBar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 12)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.max_value = float(Progression.xp_to_next(level, Game.balance))
	xp_bar.value = float(xp)
	xp_bar.add_theme_stylebox_override("background", UiStyle.bar_style(UiStyle.ACCENT))
	xp_bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(UiStyle.ACCENT))
	xp_row.add_child(xp_bar)
	xp_row.add_child(UiStyle.make_label("%d / %d" % [xp, Progression.xp_to_next(level, Game.balance)], 11))

	# Stats.
	_detail_box.add_child(UiStyle.make_label("Stats", 14, UiStyle.ACCENT))
	var stats: Label = UiStyle.make_label(
		"HP %d      ATK %d      DEF %d      MAG %d      MAG DEF %d" % [
			int(def.max_hp_at(level)), int(def.attack_at(level)), int(def.defense_at(level)),
			int(def.magic_at(level)), int(def.magic_defense_at(level))],
		12, UiStyle.TEXT)
	_detail_box.add_child(stats)
	var growth: Label = UiStyle.make_label(
		"Growth per level:  +%d HP   +%.1f ATK   +%.1f DEF   +%.1f MAG   +%.1f MAG DEF" % [
			int(def.hp_growth), def.attack_growth, def.defense_growth,
			def.magic_growth, def.magic_defense_growth], 11, UiStyle.TEXT_DIM)
	_detail_box.add_child(growth)

	# Abilities.
	_detail_box.add_child(UiStyle.make_label("Abilities", 14, UiStyle.ACCENT))
	_add_ability_row(def.basic_attack, "Basic Attack", "auto")
	_add_ability_row(def.skill, "Skill", "%ds" % int(def.skill.cooldown) if def.skill != null else "")
	_add_ability_row(def.arts, "Arts", "%d arts" % int(Game.balance.arts_cost))
	_add_ability_row(def.true_arts, "True Arts", "%d arts" % int(Game.balance.true_arts_cost))

	# Party assignment.
	_detail_box.add_child(UiStyle.make_label("Assign to party", 14, UiStyle.ACCENT))
	var assign_row: HBoxContainer = HBoxContainer.new()
	_detail_box.add_child(assign_row)
	for index in range(4):
		var button: Button = UiStyle.make_button("Slot %d" % (index + 1), 12, 28)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			Game.swap_party_member(index, _selected_id)
			Game.save_game()
			_refresh_all())
		assign_row.add_child(button)
	var remove: Button = UiStyle.make_button("Leave party", 12, 28)
	remove.disabled = not Game.is_in_party(_selected_id)
	remove.pressed.connect(func() -> void:
		Game.remove_from_party(_selected_id)
		Game.save_game()
		_refresh_all())
	assign_row.add_child(remove)

	# Equipment.
	_detail_box.add_child(UiStyle.make_label("Equipment", 14, UiStyle.ACCENT))
	for index in range(def.equipment_slots.size()):
		_add_equipment_row(def, index)


func _add_ability_row(ability: AbilityDef, label: String, cost_text: String) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PANEL_SOFT, UiStyle.BORDER, 5, 1))
	_detail_box.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var name_label: Label = UiStyle.make_label(label, 12, UiStyle.TEXT_DIM)
	name_label.custom_minimum_size = Vector2(92, 0)
	row.add_child(name_label)
	if ability == null:
		row.add_child(UiStyle.make_label("-", 12, UiStyle.DISABLED))
		return
	row.add_child(UiStyle.make_label(ability.display_name, 12, ability.color))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	if cost_text != "":
		row.add_child(UiStyle.make_label(cost_text, 11, UiStyle.TEXT_DIM))
	var description: Label = UiStyle.make_label(ability.description, 11, UiStyle.TEXT_DIM)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(220, 0)
	box.add_child(description)


func _add_equipment_row(def: CharacterDef, index: int) -> void:
	var slot: EquipmentSlotDef = def.equipment_slots[index]
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_detail_box.add_child(row)
	var slot_label: Label = UiStyle.make_label(slot.display_name, 12, UiStyle.TEXT_DIM)
	slot_label.custom_minimum_size = Vector2(92, 0)
	row.add_child(slot_label)

	var assigned: Array = Game.equipped_instances(def.id)
	var current_id: String = ""
	if index < assigned.size():
		current_id = String(assigned[index])

	var option: OptionButton = OptionButton.new()
	option.add_theme_font_size_override("font_size", 12)
	option.custom_minimum_size = Vector2(220, 26)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_item("None", 0)
	option.set_item_metadata(0, "")
	var item_index: int = 1
	for item: ItemInstance in Game.state.inventory.items:
		var item_def: EquipmentDef = Game.database.equipment_def(item.item_id)
		if item_def == null:
			continue
		if not slot.accepts_category(item_def.category):
			continue
		var owner_id: String = _owner_of(item.instance_id)
		if owner_id != "" and owner_id != String(def.id):
			continue
		option.add_item("%s (%s)" % [item_def.display_name, item_def.category_name()], item_index)
		option.set_item_metadata(item_index, item.instance_id)
		if item.instance_id == current_id:
			option.select(item_index)
		item_index += 1
	row.add_child(option)
	option.item_selected.connect(func(index: int) -> void:
		var instance_id: String = String(option.get_item_metadata(index))
		if instance_id == "":
			Game.unequip_item(def.id, index)
		else:
			Game.equip_item(def.id, index, instance_id)
		Game.save_game()
		_refresh_all())

	var description: Label = UiStyle.make_label(slot.description_for_categories(), 11, UiStyle.TEXT_DIM)
	row.add_child(description)


func _owner_of(instance_id: String) -> String:
	for character_id: Variant in Game.state.equipment.keys():
		var list: Array = Game.state.equipment[character_id]
		if list.has(instance_id):
			return String(character_id)
	return ""


func _refresh_inventory() -> void:
	_clear(_inventory_box)
	if Game.state.inventory.items.is_empty():
		_inventory_box.add_child(UiStyle.make_label("No items.", 12, UiStyle.TEXT_DIM))
		return
	for item: ItemInstance in Game.state.inventory.items:
		var item_def: EquipmentDef = Game.database.equipment_def(item.item_id)
		if item_def == null:
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_inventory_box.add_child(row)
		var dot: ColorRect = ColorRect.new()
		dot.color = item_def.icon_color
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var label: Label = UiStyle.make_label(item_def.display_name, 12, UiStyle.TEXT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var owner_id: String = _owner_of(item.instance_id)
		if owner_id != "":
			var owner_def: CharacterDef = Game.database.character(StringName(owner_id))
			row.add_child(UiStyle.make_chip(
				"worn by %s" % (owner_def.display_name if owner_def != null else owner_id),
				UiStyle.GOOD, 10))
		else:
			row.add_child(UiStyle.make_chip("stored", UiStyle.TEXT_DIM, 10))
