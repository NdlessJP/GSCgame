class_name BattleHUD
extends CanvasLayer
## The battle interface: top bar, boss meters, warnings, party panels and the
## combat log.
##
## The HUD never mutates game state; it only reads it and forwards button
## presses to the battle controller.

signal pause_pressed()

const PANEL_COUNT: int = 4

var battle: BattleController = null

var _root: Control = null
var _quest_label: Label = null
var _wave_label: Label = null
var _state_label: Label = null
var _pause_button: Button = null
var _target_label: Label = null
var _speed_button: Button = null
var _help_button: Button = null
var _help_overlay: HelpOverlay = null
var _boss_panel: PanelContainer = null
var _boss_name: Label = null
var _boss_hp_bar: ProgressBar = null
var _boss_hp_label: Label = null
var _boss_break_bar: ProgressBar = null
var _boss_break_label: Label = null
var _warning_panel: PanelContainer = null
var _warning_label: Label = null
var _log_label: RichTextLabel = null
var _panel_row: HBoxContainer = null
var _panels: Array[UnitPanel] = []
var _warning_timer: float = 0.0
var _bound: bool = false
var _log_lines: Array[String] = []


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_top_bar()
	_build_boss_panel()
	_build_warning()
	_build_log()
	_build_panels()


func _build_top_bar() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.offset_left = 10
	margin.offset_right = -10
	margin.offset_top = 8
	margin.offset_bottom = 46
	_root.add_child(margin)

	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PANEL, UiStyle.BORDER, 6, 1))
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_child(bar)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)

	_quest_label = UiStyle.make_label("Quest", 14, UiStyle.ACCENT)
	row.add_child(_quest_label)
	_wave_label = UiStyle.make_label("Wave 1/3", 13)
	row.add_child(_wave_label)
	_state_label = UiStyle.make_label("Preparation", 12, UiStyle.TEXT_DIM)
	row.add_child(_state_label)
	_target_label = UiStyle.make_label("Target: -", 12, UiStyle.TEXT_DIM)
	row.add_child(_target_label)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_help_button = UiStyle.make_button("?", 12, 26)
	_help_button.tooltip_text = "Show the controls"
	_help_button.pressed.connect(_on_help_pressed)
	row.add_child(_help_button)
	_speed_button = UiStyle.make_button("1x", 12,  26)
	_speed_button.tooltip_text = "Battle speed (1x, 2x, 3x)"
	_speed_button.pressed.connect(_on_speed_pressed)
	row.add_child(_speed_button)
	_pause_button = UiStyle.make_button("Pause", 12, 26)
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	row.add_child(_pause_button)


func _on_help_pressed() -> void:
	if _help_overlay == null:
		_help_overlay = HelpOverlay.new()
		_help_overlay.visible = false
		_root.add_child(_help_overlay)
	_help_overlay.visible = not _help_overlay.visible


func _build_boss_panel() -> void:
	var area: MarginContainer = MarginContainer.new()
	area.set_anchors_preset(Control.PRESET_TOP_WIDE)
	area.offset_top = 50
	area.offset_bottom = 148
	_root.add_child(area)

	var centre: HBoxContainer = HBoxContainer.new()
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	area.add_child(centre)

	_boss_panel = PanelContainer.new()
	_boss_panel.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.16, 0.09, 0.09, 0.95), Color(0.75, 0.3, 0.2), 6, 2))
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.visible = false
	centre.add_child(_boss_panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_boss_panel.add_child(box)

	var name_row: HBoxContainer = HBoxContainer.new()
	box.add_child(name_row)
	_boss_name = UiStyle.make_label("Boss", 14, Color(1.0, 0.75, 0.6))
	name_row.add_child(_boss_name)
	var name_spacer: Control = Control.new()
	name_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_spacer)
	_boss_hp_label = UiStyle.make_label("0/0", 12)
	name_row.add_child(_boss_hp_label)

	_boss_hp_bar = ProgressBar.new()
	_boss_hp_bar.show_percentage = false
	_boss_hp_bar.custom_minimum_size = Vector2(420, 16)
	_boss_hp_bar.add_theme_stylebox_override("background", UiStyle.bar_style(UiStyle.HP))
	_boss_hp_bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(UiStyle.HP))
	box.add_child(_boss_hp_bar)

	var break_row: HBoxContainer = HBoxContainer.new()
	box.add_child(break_row)
	break_row.add_child(UiStyle.make_label("Break", 10, UiStyle.BREAK))
	_boss_break_bar = ProgressBar.new()
	_boss_break_bar.show_percentage = false
	_boss_break_bar.custom_minimum_size = Vector2(0, 10)
	_boss_break_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_break_bar.add_theme_stylebox_override("background", UiStyle.bar_style(UiStyle.BREAK))
	_boss_break_bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(UiStyle.BREAK))
	break_row.add_child(_boss_break_bar)
	_boss_break_label = UiStyle.make_label("100%", 10, UiStyle.BREAK)
	break_row.add_child(_boss_break_label)


func _build_warning() -> void:
	var area: MarginContainer = MarginContainer.new()
	area.set_anchors_preset(Control.PRESET_TOP_WIDE)
	area.offset_top = 156
	area.offset_bottom = 216
	_root.add_child(area)

	var centre: HBoxContainer = HBoxContainer.new()
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	area.add_child(centre)

	_warning_panel = PanelContainer.new()
	_warning_panel.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.35, 0.08, 0.08, 0.92), Color(1.0, 0.4, 0.3), 8, 2))
	_warning_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_panel.visible = false
	centre.add_child(_warning_panel)
	_warning_label = UiStyle.make_label("", 20, Color(1.0, 0.85, 0.75))
	_warning_panel.add_child(_warning_label)


func _build_log() -> void:
	var area: Control = Control.new()
	area.set_anchors_preset(Control.PRESET_TOP_LEFT)
	area.offset_left = 10
	area.offset_right = 330
	area.offset_top = 52
	area.offset_bottom = 172
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(area)

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.09, 0.10, 0.14, 0.85), UiStyle.BORDER, 6, 1))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.add_child(panel)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.fit_content = false
	_log_label.scroll_active = false
	_log_label.custom_minimum_size = Vector2(300, 108)
	_log_label.add_theme_font_size_override("normal_font_size", 11)
	_log_label.add_theme_color_override("default_color", UiStyle.TEXT_DIM)
	panel.add_child(_log_label)


func _build_panels() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_left = 10
	margin.offset_right = -10
	margin.offset_top = -224
	margin.offset_bottom = -10
	_root.add_child(margin)

	_panel_row = HBoxContainer.new()
	_panel_row.add_theme_constant_override("separation", 8)
	margin.add_child(_panel_row)

	for index in range(PANEL_COUNT):
		var panel: UnitPanel = UnitPanel.new()
		panel.ability_pressed.connect(_on_ability_pressed)
		panel.equipment_pressed.connect(_on_equipment_pressed)
		_panel_row.add_child(panel)
		_panels.append(panel)


# --------------------------------------------------------------------------
# Binding
# --------------------------------------------------------------------------

func bind(battle_controller: BattleController) -> void:
	if battle == battle_controller and _bound:
		return
	battle = battle_controller
	_bound = true
	if battle == null:
		return
	battle.battle_reset.connect(_on_battle_reset)
	battle.state_changed.connect(_on_state_changed)
	battle.wave_started.connect(_on_wave_started)
	battle.wave_cleared.connect(_on_wave_cleared)
	battle.log_message.connect(add_log)
	battle.target_changed.connect(_on_target_changed)
	battle.warning.connect(show_warning)
	battle.status_changed.connect(func(_unit: UnitState) -> void: pass)
	_on_battle_reset(battle.allies)


func _on_battle_reset(allies: Array) -> void:
	for index in range(_panels.size()):
		var panel: UnitPanel = _panels[index]
		if index < allies.size():
			panel.visible = true
			panel.bind(allies[index], battle)
		else:
			panel.visible = false
			panel.bind(null, battle)
	if battle != null and battle.quest != null:
		_quest_label.text = battle.quest.display_name
	_target_label.text = "Target: -"


func _on_state_changed(new_state: int, _old_state: int) -> void:
	if battle == null:
		return
	_state_label.text = battle.state_name()


func _on_wave_started(wave_index: int, wave_count: int) -> void:
	_wave_label.text = "Wave %d/%d" % [wave_index + 1, wave_count]


func _on_target_changed(unit: UnitState) -> void:
	if unit == null or unit.is_dead:
		_target_label.text = "Target: -"
		return
	_target_label.text = "Target: %s%s" % [unit.display_name(), _weak_to_text(unit)]


## Lists the elements that hit this target harder, so the player can see at a
## glance which hero to send in.
func _weak_to_text(unit: UnitState) -> String:
	var strong: Array[String] = []
	for element: int in Elements.ALL_ELEMENTS:
		if Elements.multiplier(element, unit.element()) > 1.0:
			strong.append(Elements.element_name(element))
	if strong.is_empty():
		return ""
	return "  (weak to %s)" % ", ".join(strong)


func _on_speed_pressed() -> void:
	if battle == null:
		return
	var next_speed: float = battle.speed + 1.0
	if next_speed > 3.0:
		next_speed = 1.0
	battle.speed = next_speed
	_speed_button.text = "%dx" % int(battle.speed)


func _on_wave_cleared(wave_index: int) -> void:
	_log_lines.append("[color=#7fd6a0]Wave %d cleared.[/color]" % (wave_index + 1))
	_trim_log()


# --------------------------------------------------------------------------
# Feedback
# --------------------------------------------------------------------------

func add_log(text: String) -> void:
	if text.is_empty():
		return
	_log_lines.append(text)
	_trim_log()


func _trim_log() -> void:
	while _log_lines.size() > 6:
		_log_lines.pop_front()
	if _log_label != null:
		_log_label.text = "\n".join(_log_lines)


func show_warning(text: String) -> void:
	if _warning_label == null:
		return
	_warning_label.text = text
	_warning_panel.visible = true
	_warning_panel.modulate = Color(1, 1, 1, 1)
	_warning_timer = 2.2


func _process(delta: float) -> void:
	if _warning_timer > 0.0:
		_warning_timer -= delta
		if _warning_timer <= 0.6:
			_warning_panel.modulate = Color(1, 1, 1, clampf(_warning_timer / 0.6, 0.0, 1.0))
		if _warning_timer <= 0.0:
			_warning_panel.visible = false
	_update_boss_panel()


func _update_boss_panel() -> void:
	if battle == null:
		return
	var boss: UnitState = battle.boss_unit()
	if boss == null:
		_boss_panel.visible = false
		return
	_boss_panel.visible = true
	_boss_name.text = boss.display_name()
	var hp_max: float = maxf(1.0, boss.max_hp())
	_boss_hp_bar.max_value = hp_max
	_boss_hp_bar.value = boss.hp
	_boss_hp_label.text = "%d/%d" % [int(round(boss.hp)), int(round(hp_max))]
	var break_ratio: float = 1.0 - boss.break_ratio()
	_boss_break_bar.max_value = 1.0
	_boss_break_bar.value = break_ratio
	_boss_break_label.text = "%d%%" % int(round(break_ratio * 100.0))
	if boss.is_broken:
		_boss_break_label.text = "BROKEN"
		_boss_break_label.add_theme_color_override("font_color", UiStyle.ACCENT)
	else:
		_boss_break_label.add_theme_color_override("font_color", UiStyle.BREAK)


# --------------------------------------------------------------------------
# Input forwarding
# --------------------------------------------------------------------------

func _on_ability_pressed(unit: UnitState, ability: AbilityDef) -> void:
	if battle != null:
		battle.use_ability(unit, ability)


func _on_equipment_pressed(unit: UnitState, ability_id: StringName) -> void:
	if battle != null:
		battle.use_equipment(unit, ability_id)
