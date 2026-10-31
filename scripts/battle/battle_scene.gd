class_name BattleScene
extends Node2D
## The playable battlefield.
##
## Owns the world (background, unit views, effects) and forwards player input
## to the BattleController.  All combat rules live in the controller; this
## scene is presentation only.

const GROUND_Y: float = 430.0
const ALLY_START_X: float = 150.0
const ALLY_SPACING: float = 118.0
const ENEMY_START_X: float = 1130.0
const ENEMY_SPACING: float = 118.0

var battle: BattleController = null
var hud: BattleHUD = null
var pause_menu: PauseMenu = null

var _ally_views: Array[Unit] = []
var _enemy_views: Array[Unit] = []
var _effects_layer: Node2D = null
var _end_timer: float = -1.0
var _connected: bool = false
var _victory: bool = false


func _ready() -> void:
	_build_world()
	battle = BattleController.new()
	add_child(battle)
	hud = BattleHUD.new()
	add_child(hud)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.resume_pressed.connect(_on_resume)
	pause_menu.retry_pressed.connect(_on_retry)
	pause_menu.quit_pressed.connect(_on_quit)
	hud.pause_pressed.connect(_on_pause_pressed)

	var quest: QuestDef = Game.database.quest(Game.pending_quest_id)
	if quest == null:
		push_error("BattleScene: no quest to run, returning to the quest board.")
		Game.goto_scene("res://scenes/quests/quest_select.tscn")
		return
	# Bind before starting the battle so the reset signal is not missed.
	hud.bind(battle)
	_connect_battle()
	battle.setup(quest, Game.party_ids(), Game.balance)
	queue_redraw()


func _build_world() -> void:
	_effects_layer = Node2D.new()
	_effects_layer.z_index = 5
	add_child(_effects_layer)


# --------------------------------------------------------------------------
# Background
# --------------------------------------------------------------------------

func _draw() -> void:
	# Sky.
	var top: Color = Color(0.07, 0.08, 0.13)
	var bottom: Color = Color(0.16, 0.12, 0.16)
	var bands: int = 24
	for i in range(bands):
		var t: float = float(i) / float(bands - 1)
		var y: float = t * GROUND_Y
		draw_rect(Rect2(0, y, 1280, GROUND_Y / float(bands) + 1.0), top.lerp(bottom, t))
	# Distant ridge.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, GROUND_Y), Vector2(120, GROUND_Y - 90), Vector2(260, GROUND_Y - 40),
		Vector2(420, GROUND_Y - 130), Vector2(560, GROUND_Y - 60), Vector2(700, GROUND_Y - 150),
		Vector2(860, GROUND_Y - 55), Vector2(980, GROUND_Y - 120), Vector2(1120, GROUND_Y - 45),
		Vector2(1280, GROUND_Y - 95), Vector2(1280, GROUND_Y),
	]), Color(0.09, 0.09, 0.14))
	# Ground.
	draw_rect(Rect2(0, GROUND_Y, 1280, 720 - GROUND_Y), Color(0.11, 0.10, 0.13))
	draw_rect(Rect2(0, GROUND_Y, 1280, 3), Color(0.30, 0.26, 0.30))
	# Field markers.
	for i in range(7):
		var x: float = 120.0 + i * 170.0
		draw_rect(Rect2(x, GROUND_Y + 18, 70, 3), Color(0.2, 0.19, 0.24))


# --------------------------------------------------------------------------
# Signal wiring
# --------------------------------------------------------------------------

func _connect_battle() -> void:
	if _connected:
		return
	_connected = true
	battle.warning.connect(_on_warning)
	battle.ability_windup.connect(_on_ability_windup)
	battle.battle_reset.connect(_on_battle_reset)
	battle.wave_started.connect(_on_wave_started)
	battle.ability_used.connect(_on_ability_used)
	battle.damage_dealt.connect(_on_damage_dealt)
	battle.healed.connect(_on_healed)
	battle.shield_granted.connect(_on_shield_granted)
	battle.break_started.connect(_on_break_started)
	battle.unit_died.connect(_on_unit_died)
	battle.target_changed.connect(_on_target_changed)
	battle.battle_finished.connect(_on_battle_finished)


func _on_warning(text: String) -> void:
	Audio.play(AudioDirector.Sfx.WARNING, -6.0)


func _on_ability_windup(caster: UnitState, ability: AbilityDef, duration: float) -> void:
	if caster == null or ability == null:
		return
	if caster.view != null and is_instance_valid(caster.view):
		caster.view.start_telegraph(ability.color, duration)
		_spawn_text("! %s" % ability.display_name,
			caster.view.global_position + Vector2(0, -120), Color(1.0, 0.62, 0.35), 14)


func _on_battle_reset(allies: Array) -> void:
	for view: Unit in _ally_views + _enemy_views:
		if is_instance_valid(view):
			view.queue_free()
	_ally_views.clear()
	_enemy_views.clear()
	for index in range(allies.size()):
		var unit: UnitState = allies[index]
		var view: Unit = Unit.new()
		view.setup(unit)
		view.position = Vector2(ALLY_START_X + ALLY_SPACING * float(index), GROUND_Y)
		add_child(view)
		_ally_views.append(view)
	queue_redraw()


func _on_wave_started(_wave_index: int, _wave_count: int) -> void:
	Audio.play(AudioDirector.Sfx.WAVE, -6.0)
	for index in range(battle.enemies.size()):
		var unit: UnitState = battle.enemies[index]
		var view: Unit = Unit.new()
		view.setup(unit)
		view.position = Vector2(ENEMY_START_X - ENEMY_SPACING * float(index), GROUND_Y)
		add_child(view)
		_enemy_views.append(view)


# --------------------------------------------------------------------------
# Feedback
# --------------------------------------------------------------------------

func _on_ability_used(caster: UnitState, ability: AbilityDef, targets: Array) -> void:
	# Ability name banner above the caster.
	if caster.view != null and is_instance_valid(caster.view):
		_spawn_text(ability.display_name, caster.view.global_position + Vector2(0, -110), ability.color, 13)
		caster.view.play_attack(_target_position(targets))
	if ability.show_projectile and caster.view != null and is_instance_valid(caster.view):
		for target: UnitState in targets:
			if target.view == null or not is_instance_valid(target.view):
				continue
			var shot: Projectile = Projectile.new()
			shot.setup(caster.view.global_position, target.view, ability.color, 900.0)
			_effects_layer.add_child(shot)


func _target_position(targets: Array) -> Vector2:
	if targets.is_empty():
		return Vector2.ZERO
	var first: UnitState = targets[0]
	if first.view != null and is_instance_valid(first.view):
		return first.view.global_position
	return Vector2.ZERO


func _on_damage_dealt(source: UnitState, target: UnitState, result: Dictionary) -> void:
	var amount: float = float(result.get("amount", 0.0))
	var absorbed: float = float(result.get("absorbed", 0.0))
	var is_crit: bool = bool(result.get("is_crit", false))
	var multiplier: float = float(result.get("element_multiplier", 1.0))
	if target != null and target.view != null and is_instance_valid(target.view):
		target.view.play_hit()
	if amount <= 0.0 and absorbed <= 0.0:
		return
	if is_crit:
		Audio.play(AudioDirector.Sfx.CRIT, -5.0)
	else:
		Audio.play(AudioDirector.Sfx.HIT, -9.0, 1.0)
	if target == null or target.view == null or not is_instance_valid(target.view):
		return
	var label: String = "-%d" % int(round(amount))
	var color: Color = Color(1.0, 0.45, 0.4)
	if is_crit:
		label += "!"
		color = Color(1.0, 0.85, 0.3)
	if multiplier > 1.0:
		label += " x%.1f" % multiplier
		color = Color(1.0, 0.6, 0.85)
	if absorbed > 0.0:
		label += " (%d shield)" % int(round(absorbed))
	_spawn_text(label, target.view.global_position + Vector2(0, -70), color, 17 if is_crit else 15)


func _on_healed(unit: UnitState, amount: float) -> void:
	Audio.play(AudioDirector.Sfx.HEAL, -8.0)
	if unit == null or amount <= 0.0:
		return
	if unit.view == null or not is_instance_valid(unit.view):
		return
	_spawn_text("+%d" % int(round(amount)), unit.view.global_position + Vector2(0, -70), Color(0.5, 0.95, 0.6), 15)


func _on_shield_granted(unit: UnitState, amount: float) -> void:
	Audio.play(AudioDirector.Sfx.SHIELD, -8.0)
	if unit == null or unit.view == null or not is_instance_valid(unit.view):
		return
	_spawn_text("+%d ward" % int(round(amount)), unit.view.global_position + Vector2(0, -88), Color(0.6, 0.9, 1.0), 13)


func _on_break_started(unit: UnitState) -> void:
	Audio.play(AudioDirector.Sfx.BREAK, -3.0)
	if unit == null or unit.view == null or not is_instance_valid(unit.view):
		return
	_spawn_text("BROKEN", unit.view.global_position + Vector2(0, -95), Color(1.0, 0.85, 0.3), 18)


func _on_unit_died(unit: UnitState) -> void:
	if unit == null or unit.view == null or not is_instance_valid(unit.view):
		return
	_spawn_text("Defeated", unit.view.global_position + Vector2(0, -60), Color(0.7, 0.7, 0.75), 13)


func _on_target_changed(unit: UnitState) -> void:
	for view: Unit in _enemy_views:
		if is_instance_valid(view):
			view.selected = unit != null and view.state == unit
	for view: Unit in _ally_views:
		if is_instance_valid(view):
			view.selected = false


func _spawn_text(text: String, position: Vector2, color: Color, size: int) -> void:
	var label: FloatingText = FloatingText.new()
	label.setup(text, color, size)
	label.position = position
	_effects_layer.add_child(label)


# --------------------------------------------------------------------------
# Flow
# --------------------------------------------------------------------------

func _on_battle_finished(victory: bool, results: Dictionary) -> void:
	_victory = victory
	Game.last_battle_victory = victory
	Game.last_results = results
	_end_timer = 1.4
	if victory:
		Audio.play(AudioDirector.Sfx.VICTORY, -3.0)
	else:
		Audio.play(AudioDirector.Sfx.DEFEAT, -3.0)
		hud.show_warning("The party was defeated.")


func _process(delta: float) -> void:
	if _end_timer < 0.0:
		return
	_end_timer -= delta
	if _end_timer <= 0.0:
		_end_timer = -1.0
		Game.goto_scene("res://scenes/battle/results_screen.tscn")


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_handle_click(mouse.position)
		return
	if event is InputEventKey:
		var key: InputEventKey = event
		if not key.pressed or key.echo:
			return
		_handle_key(key)


func _handle_click(position: Vector2) -> void:
	if battle == null or not battle.is_combat_active():
		return
	var world_position: Vector2 = get_global_mouse_position()
	var best: UnitState = null
	var best_distance: float = 60.0
	for unit: UnitState in battle.enemies:
		if unit.is_dead or unit.view == null or not is_instance_valid(unit.view):
			continue
		var distance: float = unit.view.global_position.distance_to(world_position)
		if distance < best_distance:
			best_distance = distance
			best = unit
	if best != null:
		battle.set_preferred_target(best)


func _handle_key(key: InputEventKey) -> void:
	if battle == null:
		return
	match key.keycode:
		KEY_P, KEY_ESCAPE:
			_on_pause_pressed()
			return
		KEY_T:
			_cycle_target()
			return
	var index: int = _ability_index(key.keycode)
	if index < 0:
		return
	var allies: Array = battle.allies
	if index >= allies.size():
		return
	var unit: UnitState = allies[index]
	var def: CharacterDef = unit.def as CharacterDef
	if def == null:
		return
	match key.keycode:
		KEY_Q, KEY_W, KEY_E, KEY_R:
			if def.skill != null:
				battle.use_ability(unit, def.skill)
		KEY_A, KEY_S, KEY_D, KEY_F:
			if def.arts != null:
				battle.use_ability(unit, def.arts)
		KEY_Z, KEY_X, KEY_C, KEY_V:
			if def.true_arts != null:
				battle.use_ability(unit, def.true_arts)
		KEY_1, KEY_2, KEY_3:
			var slot: int = key.keycode - KEY_1
			if slot < unit.equipment.size():
				var item: EquipmentDef = unit.equipment[slot].get("def")
				if item != null and item.active_ability != null:
					battle.use_equipment(unit, item.active_ability.id)


func _ability_index(keycode: int) -> int:
	match keycode:
		KEY_Q, KEY_A, KEY_Z: return 0
		KEY_W, KEY_S, KEY_X: return 1
		KEY_E, KEY_D, KEY_C: return 2
		KEY_R, KEY_F, KEY_V: return 3
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
	return -1


func _cycle_target() -> void:
	if battle == null:
		return
	var living: Array = battle.living_enemies()
	if living.is_empty():
		return
	var current: int = living.find(battle.preferred_target)
	var next: int = (current + 1) % living.size()
	if current < 0:
		next = 0
	battle.set_preferred_target(living[next])


# --------------------------------------------------------------------------
# Pause menu
# --------------------------------------------------------------------------

func _on_pause_pressed() -> void:
	if battle == null:
		return
	if battle.state == BattleController.State.PAUSED:
		_on_resume()
	else:
		battle.pause()
		pause_menu.open()


func _on_resume() -> void:
	if battle != null:
		battle.resume()
	pause_menu.close()


func _on_retry() -> void:
	pause_menu.close()
	if battle != null:
		battle.resume()
		battle.restart()
		hud.bind(battle)
		_connect_battle()


func _on_quit() -> void:
	pause_menu.close()
	if battle != null:
		battle.resume()
		battle.abandon()
	Game.goto_scene("res://scenes/quests/quest_select.tscn")
