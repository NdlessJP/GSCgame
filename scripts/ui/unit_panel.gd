class_name UnitPanel
extends PanelContainer
## The battle HUD panel of one party member.
##
## Shows the name and element, the HP bar, the arts gauge, the skill / arts /
## true arts buttons with their cooldowns, the three equipment buttons and the
## active status indicators.  Disabled states are explained in the button
## label and the tooltip.

signal ability_pressed(unit: UnitState, ability: AbilityDef)
signal equipment_pressed(unit: UnitState, ability_id: StringName)

var unit: UnitState = null
var battle: BattleController = null

var _name_label: Label = null
var _element_chip: PanelContainer = null
var _level_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _arts_bar: ProgressBar = null
var _arts_label: Label = null
var _status_row: HBoxContainer = null
var _skill_button: Button = null
var _arts_button: Button = null
var _true_button: Button = null
var _equipment_buttons: Array[Button] = []
var _status_signature: String = ""


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	custom_minimum_size = Vector2(240, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()


func bind(unit_state: UnitState, battle_controller: BattleController) -> void:
	unit = unit_state
	battle = battle_controller
	_status_signature = ""
	refresh()


func _build() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 3)
	add_child(root)

	# --- header -----------------------------------------------------------
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	root.add_child(header)
	_name_label = UiStyle.make_label("—", 14)
	header.add_child(_name_label)
	_element_chip = UiStyle.make_chip("—", Color.WHITE)
	header.add_child(_element_chip)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_level_label = UiStyle.make_label("Lv 1", 11, UiStyle.TEXT_DIM)
	header.add_child(_level_label)

	# --- hp ----------------------------------------------------------------
	var hp_row: HBoxContainer = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 4)
	root.add_child(hp_row)
	hp_row.add_child(UiStyle.make_label("HP", 10, UiStyle.TEXT_DIM))
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0, 13)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.add_theme_stylebox_override("background", UiStyle.bar_style(UiStyle.HP))
	_hp_bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(UiStyle.HP))
	hp_row.add_child(_hp_bar)
	_hp_label = UiStyle.make_label("0/0", 10)
	hp_row.add_child(_hp_label)

	# --- arts --------------------------------------------------------------
	var arts_row: HBoxContainer = HBoxContainer.new()
	arts_row.add_theme_constant_override("separation", 4)
	root.add_child(arts_row)
	arts_row.add_child(UiStyle.make_label("Arts", 10, UiStyle.TEXT_DIM))
	_arts_bar = ProgressBar.new()
	_arts_bar.show_percentage = false
	_arts_bar.custom_minimum_size = Vector2(0, 11)
	_arts_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arts_bar.add_theme_stylebox_override("background", UiStyle.bar_style(UiStyle.ARTS))
	_arts_bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(UiStyle.ARTS))
	arts_row.add_child(_arts_bar)
	_arts_label = UiStyle.make_label("0/200", 10)
	arts_row.add_child(_arts_label)

	# --- statuses ----------------------------------------------------------
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 3)
	_status_row.custom_minimum_size = Vector2(0, 18)
	root.add_child(_status_row)

	# --- ability buttons ---------------------------------------------------
	var ability_row: HBoxContainer = HBoxContainer.new()
	ability_row.add_theme_constant_override("separation", 3)
	root.add_child(ability_row)
	_skill_button = UiStyle.make_button("Skill", 11, 34)
	_skill_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_button.pressed.connect(_on_skill_pressed)
	ability_row.add_child(_skill_button)
	_arts_button = UiStyle.make_button("Arts", 11, 34)
	_arts_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arts_button.pressed.connect(_on_arts_pressed)
	ability_row.add_child(_arts_button)
	_true_button = UiStyle.make_button("True Arts", 11, 34)
	_true_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_true_button.pressed.connect(_on_true_pressed)
	ability_row.add_child(_true_button)

	# --- equipment ----------------------------------------------------------
	var equipment_row: HBoxContainer = HBoxContainer.new()
	equipment_row.add_theme_constant_override("separation", 3)
	root.add_child(equipment_row)
	for index in range(3):
		var button: Button = UiStyle.make_button("Empty", 10, 24)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_equipment_pressed.bind(index))
		equipment_row.add_child(button)
		_equipment_buttons.append(button)


func _process(_delta: float) -> void:
	refresh()


# --------------------------------------------------------------------------
# Refresh
# --------------------------------------------------------------------------

func refresh() -> void:
	if unit == null or unit.def == null:
		return
	var def: CharacterDef = unit.def as CharacterDef
	_name_label.text = def.display_name
	_level_label.text = "Lv %d" % unit.level
	var element_color: Color = Elements.element_color(unit.element())
	_element_chip.add_theme_stylebox_override("panel", UiStyle.panel(
		element_color.darkened(0.6), element_color, 4, 1))
	var chip_label: Label = _element_chip.get_child(0) as Label
	if chip_label != null:
		chip_label.text = Elements.element_name(unit.element())
		chip_label.add_theme_color_override("font_color", element_color)

	var hp_max: float = maxf(1.0, unit.max_hp())
	_hp_bar.max_value = hp_max
	_hp_bar.value = unit.hp
	_hp_label.text = "%d/%d" % [int(round(unit.hp)), int(round(hp_max))]

	var arts_max: float = Game.balance.arts_max if Game.balance != null else 200.0
	_arts_bar.max_value = arts_max
	_arts_bar.value = unit.arts
	_arts_label.text = "%d/%d" % [int(unit.arts), int(arts_max)]

	_refresh_statuses()
	_refresh_abilities(def)
	_refresh_equipment()


func _refresh_statuses() -> void:
	var signature: String = ""
	for instance: StatusInstance in unit.statuses:
		signature += "%s:%d:" % [instance.id(), instance.stacks]
	if signature == _status_signature:
		return
	_status_signature = signature
	for child: Node in _status_row.get_children():
		child.queue_free()
	if unit.statuses.is_empty():
		var none_label: Label = UiStyle.make_label("no statuses", 10, UiStyle.TEXT_DIM)
		_status_row.add_child(none_label)
		return
	for instance: StatusInstance in unit.statuses:
		var color: Color = instance.def.color if instance.def != null else Color.WHITE
		var text: String = instance.display_name()
		if instance.stacks > 1:
			text += " x%d" % instance.stacks
		text += " %ds" % int(ceil(instance.remaining))
		_status_row.add_child(UiStyle.make_chip(text, color, 10))


func _refresh_abilities(def: CharacterDef) -> void:
	var battle_ready: bool = battle != null and battle.is_combat_active()
	_skill_button.text = _ability_text(def.skill, "Skill", battle_ready)
	_skill_button.disabled = not _can_use(def.skill, battle_ready)
	_skill_button.tooltip_text = _tooltip(def.skill, battle_ready)

	_arts_button.text = _ability_text(def.arts, "Arts %d" % int(Game.balance.arts_cost), battle_ready)
	_arts_button.disabled = not _can_use(def.arts, battle_ready)
	_arts_button.tooltip_text = _tooltip(def.arts, battle_ready)

	_true_button.text = _ability_text(def.true_arts, "True %d" % int(Game.balance.true_arts_cost), battle_ready)
	_true_button.disabled = not _can_use(def.true_arts, battle_ready)
	_true_button.tooltip_text = _tooltip(def.true_arts, battle_ready)


## The button shows the ability name on the first line and its cost or
## remaining cooldown on the second, so the player never has to guess.
func _ability_text(ability: AbilityDef, label: String, battle_ready: bool) -> String:
	if ability == null:
		return "-"
	var remaining: float = unit.cooldown_remaining(ability.id)
	if remaining > 0.0:
		return "%s\n%.1fs" % [ability.display_name, remaining]
	return "%s\n%s" % [ability.display_name, label]


func _can_use(ability: AbilityDef, battle_ready: bool) -> bool:
	if ability == null or not battle_ready or unit.is_dead:
		return false
	return AbilityExecutor.blocked_reason(unit, ability, Game.balance) == ""


func _tooltip(ability: AbilityDef, battle_ready: bool) -> String:
	if ability == null:
		return "No ability"
	var lines: String = ability.display_name
	if not ability.description.is_empty():
		lines += "\n" + ability.description
	if ability.arts_cost > 0.0:
		lines += "\nCosts %d arts" % int(ability.arts_cost)
	if ability.cooldown > 0.0:
		lines += "\nCooldown %.0fs" % ability.cooldown
	if not battle_ready:
		lines += "\nNot available right now"
	elif unit.is_dead:
		lines += "\nThis character is defeated"
	else:
		var reason: String = AbilityExecutor.blocked_reason(unit, ability, Game.balance)
		if reason != "":
			lines += "\n" + reason
	return lines


func _refresh_equipment() -> void:
	for index in range(_equipment_buttons.size()):
		var button: Button = _equipment_buttons[index]
		if index >= unit.equipment.size():
			button.text = "Empty"
			button.disabled = true
			button.tooltip_text = "No item equipped"
			continue
		var entry: Dictionary = unit.equipment[index]
		var item: EquipmentDef = entry.get("def")
		if item == null:
			button.text = "Empty"
			button.disabled = true
			continue
		var ability: AbilityDef = item.active_ability
		if ability == null:
			button.text = item.display_name
			button.disabled = true
			button.tooltip_text = item.description
			continue
		var remaining: float = unit.cooldown_remaining(ability.id)
		var battle_ready: bool = battle != null and battle.is_combat_active()
		# Only the first word of the item name fits in the narrow button.
		var short_name: String = item.display_name.split(" ")[0]
		button.text = "%s %s" % [short_name, ("%.0fs" % remaining) if remaining > 0.0 else ""]
		button.disabled = not battle_ready or unit.is_dead or remaining > 0.0
		button.tooltip_text = "%s\n%s" % [item.description, ability.description]


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _on_skill_pressed() -> void:
	if unit == null:
		return
	var def: CharacterDef = unit.def as CharacterDef
	if def != null and def.skill != null:
		ability_pressed.emit(unit, def.skill)


func _on_arts_pressed() -> void:
	if unit == null:
		return
	var def: CharacterDef = unit.def as CharacterDef
	if def != null and def.arts != null:
		ability_pressed.emit(unit, def.arts)


func _on_true_pressed() -> void:
	if unit == null:
		return
	var def: CharacterDef = unit.def as CharacterDef
	if def != null and def.true_arts != null:
		ability_pressed.emit(unit, def.true_arts)


func _on_equipment_pressed(index: int) -> void:
	if unit == null or index >= unit.equipment.size():
		return
	var entry: Dictionary = unit.equipment[index]
	var item: EquipmentDef = entry.get("def")
	if item == null or item.active_ability == null:
		return
	equipment_pressed.emit(unit, item.active_ability.id)
