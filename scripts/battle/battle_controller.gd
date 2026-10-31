class_name BattleController
extends Node
## The battle state machine and combat loop.
##
## Responsibilities:
##   * own the battle state (preparation, combat, wave transition, victory,
##     defeat, pause),
##   * run the combat clock (attack timers, cooldowns, status durations),
##   * drive the enemy AI,
##   * resolve which unit an ability hits,
##   * emit signals describing everything that happened.
##
## The controller never touches the UI directly and never stores permanent
## player data; rewards are handed to the Game autoload exactly once.

enum State {
	PREPARATION,
	COMBAT,
	WAVE_TRANSITION,
	VICTORY,
	DEFEAT,
	PAUSED,
}

const STATE_NAMES: Dictionary = {
	State.PREPARATION: "Preparation",
	State.COMBAT: "Combat",
	State.WAVE_TRANSITION: "Wave Break",
	State.VICTORY: "Victory",
	State.DEFEAT: "Defeat",
	State.PAUSED: "Paused",
}

signal battle_reset(allies: Array)
signal state_changed(new_state: int, old_state: int)
signal wave_started(wave_index: int, wave_count: int)
signal wave_cleared(wave_index: int)
signal hp_changed(unit: UnitState)
signal arts_changed(unit: UnitState)
signal status_changed(unit: UnitState)
signal cooldown_changed(unit: UnitState, ability_id: StringName)
signal damage_dealt(source: UnitState, target: UnitState, result: Dictionary)
signal healed(unit: UnitState, amount: float)
signal shield_granted(unit: UnitState, amount: float)
signal shield_absorbed(unit: UnitState, amount: float)
signal ability_used(caster: UnitState, ability: AbilityDef, targets: Array)
signal ability_failed(caster: UnitState, ability: AbilityDef, reason: String)
signal unit_died(unit: UnitState)
signal break_started(unit: UnitState)
signal break_ended(unit: UnitState)
signal warning(text: String)
signal log_message(text: String)
signal target_changed(unit: UnitState)
## Emitted when a unit starts winding up an ability, so the UI can show the
## telegraph before the attack lands.
signal ability_windup(caster: UnitState, ability: AbilityDef, duration: float)
signal battle_finished(victory: bool, results: Dictionary)

var quest: QuestDef = null
var party_ids: Array[StringName] = []
var allies: Array[UnitState] = []
var enemies: Array[UnitState] = []
var preferred_target: UnitState = null
## Simulation speed multiplier.  1.0 is real time; the HUD cycles through
## 1x / 2x / 3x.  It only affects the battle clock, never the engine clock,
## so it does not interfere with anything else running in the tree.
var speed: float = 1.0
var state: int = State.PREPARATION
var wave_index: int = -1
var pending: Array[PendingAction] = []
var balance: BalanceConfig = null
var rewards_granted: bool = false
var battle_token: String = ""
var last_results: Dictionary = {}

var _state_before_pause: int = State.COMBAT
var _prep_timer: float = 0.0
var _transition_timer: float = 0.0
var _results_announced: bool = false


func _ready() -> void:
	set_process(true)


# --------------------------------------------------------------------------
# Setup
# --------------------------------------------------------------------------

## Starts a battle.  `party` is a list of character ids.
func setup(quest_def: QuestDef, party: Array, balance_config: BalanceConfig = null) -> void:
	quest = quest_def
	party_ids.clear()
	for id: Variant in party:
		party_ids.append(StringName(String(id)))
	balance = balance_config if balance_config != null else Game.balance
	_clear_battle()
	for character_id: StringName in party_ids:
		var ally: UnitState = _create_ally(character_id, allies.size())
		if ally != null:
			allies.append(ally)
	battle_token = "%s_%d_%d" % [quest.id if quest != null else &"battle", Time.get_ticks_msec(), randi()]
	_enter_state(State.PREPARATION)
	_prep_timer = balance.wave_break_seconds if balance != null else 2.0
	battle_reset.emit(allies)
	log_message.emit("Battle started: %s" % (quest.display_name if quest != null else "Unknown quest"))


## Rebuilds the battle from scratch (used by "retry").
func restart() -> void:
	if quest == null:
		return
	setup(quest, party_ids, balance)


func _clear_battle() -> void:
	allies.clear()
	enemies.clear()
	pending.clear()
	preferred_target = null
	wave_index = -1
	rewards_granted = false
	last_results = {}
	_results_announced = false


func _create_ally(character_id: StringName, index: int = 0) -> UnitState:
	var def: CharacterDef = Game.database.character(character_id)
	if def == null:
		return null
	var level: int = Game.state.character_level(character_id)
	var unit: UnitState = UnitState.new(def, level)
	unit.is_ally = true
	var instances: Array = Game.equipped_instances(character_id)
	for slot_index in range(def.equipment_slots.size()):
		var instance_id: String = ""
		if slot_index < instances.size():
			instance_id = String(instances[slot_index])
		if instance_id == "":
			continue
		var item: ItemInstance = Game.state.inventory.find(instance_id)
		if item == null:
			continue
		unit.equipment.append({
			"def": Game.database.equipment_def(item.item_id),
			"instance_id": instance_id,
		})
	unit.refresh_max_hp()
	if def.basic_attack != null:
		# Stagger the party so the attacks do not all land on the same frame.
		unit.attack_timer = def.basic_attack.cooldown * (0.35 + 0.22 * float(index))
	return unit


func _create_enemy(enemy_id: StringName, enemy_level: int = 1, stat_scale: float = 1.0) -> UnitState:
	var def: EnemyDef = Game.database.enemy(enemy_id)
	if def == null:
		push_warning("BattleController: unknown enemy id '%s'" % enemy_id)
		return null
	var unit: UnitState = UnitState.new(def, enemy_level)
	# The multiplier is applied after construction, so the starting HP has to
	# be recomputed to match the scaled ceiling.
	unit.stat_multiplier = stat_scale
	unit.hp = unit.max_hp()
	unit.is_ally = false
	if def.attack_start_delay > 0.0:
		unit.attack_timer = def.attack_start_delay
	return unit


# --------------------------------------------------------------------------
# State machine
# --------------------------------------------------------------------------

func _enter_state(new_state: int) -> void:
	if state == new_state:
		return
	var old_state: int = state
	state = new_state
	state_changed.emit(new_state, old_state)


func state_name() -> String:
	return STATE_NAMES.get(state, "Unknown")


func is_combat_active() -> bool:
	return state == State.COMBAT


func pause() -> void:
	if state == State.PAUSED or state == State.VICTORY or state == State.DEFEAT:
		return
	_state_before_pause = state
	_enter_state(State.PAUSED)
	get_tree().paused = true


func resume() -> void:
	if state != State.PAUSED:
		return
	get_tree().paused = false
	_enter_state(_state_before_pause)


func toggle_pause() -> void:
	if state == State.PAUSED:
		resume()
	else:
		pause()


# --------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	delta *= clampf(speed, 0.25, 4.0)
	match state:
		State.PREPARATION:
			_prep_timer -= delta
			if _prep_timer <= 0.0:
				_start_wave(0)
		State.COMBAT:
			_tick_allies(delta)
			_tick_enemies(delta)
			_tick_pending(delta)
			_check_end_conditions()
		State.WAVE_TRANSITION:
			# The battle clock keeps running between waves: cooldowns and
			# status durations tick down, HP and arts are preserved.
			_tick_allies(delta, true)
			_tick_enemies(delta, true)
			_transition_timer -= delta
			if _transition_timer <= 0.0:
				_start_wave(wave_index + 1)


func _start_wave(index: int) -> void:
	if quest == null or index < 0 or index >= quest.wave_count():
		return
	wave_index = index
	var wave: WaveDef = quest.waves[index]
	for enemy_id: StringName in wave.enemy_ids:
		var enemy: UnitState = _create_enemy(enemy_id, wave.enemy_level, wave.stat_scale)
		if enemy != null:
			enemies.append(enemy)
	_enter_state(State.COMBAT)
	wave_started.emit(index, quest.wave_count())
	log_message.emit("%s - %s" % [wave.label, wave.enemy_ids.size()])
	if wave.break_delay > 0.0:
		_prep_timer = wave.break_delay


func _tick_allies(delta: float, idle_only: bool = false) -> void:
	for unit: UnitState in allies:
		_tick_unit(unit, delta)
		if idle_only or unit.is_dead:
			continue
		if unit.status_blocks_actions() or unit.is_broken:
			continue
		if unit.attack_timer > 0.0:
			unit.attack_timer -= delta
		if unit.attack_timer <= 0.0:
			var def: CharacterDef = unit.def as CharacterDef
			if def != null and def.basic_attack != null:
				_activate(unit, def.basic_attack, &"basic")
				unit.attack_timer = def.basic_attack.cooldown


func _tick_enemies(delta: float, idle_only: bool = false) -> void:
	for unit: UnitState in enemies:
		_tick_unit(unit, delta)
		if idle_only or unit.is_dead:
			continue
		var def: EnemyDef = unit.def as EnemyDef
		if def == null:
			continue
		# The phase check runs even while the boss is broken or stunned.
		_check_boss_phase(unit, def)
		if unit.status_blocks_actions() or unit.is_broken:
			continue
		# Basic attack.
		if unit.attack_timer > 0.0:
			unit.attack_timer -= delta
		if unit.attack_timer <= 0.0 and def.attacks.size() > 0:
			var basic: AbilityDef = def.attacks[0]
			var target: UnitState = EnemyAI.pick_target(unit, allies)
			if target != null:
				_activate_with_target(unit, basic, target, &"basic")
			unit.attack_timer = basic.cooldown
		# Abilities on their own cooldowns.
		var ability: AbilityDef = EnemyAI.choose_ability(unit, allies, def.is_boss)
		if ability != null:
			var chosen: UnitState = EnemyAI.pick_target(unit, allies)
			_start_windup(unit, ability, chosen)


func _tick_unit(unit: UnitState, delta: float) -> void:
	unit.tick_cooldowns(delta)
	var events: Array[Dictionary] = unit.tick_statuses(delta)
	for event: Dictionary in events:
		var kind: StringName = StringName(String(event.get("type", "")))
		match kind:
			&"periodic_damage":
				_apply_periodic_damage(unit, event)
			&"periodic_heal":
				var healed_amount: float = unit.heal(float(event.get("amount", 0.0)))
				if healed_amount > 0.0:
					healed.emit(unit, healed_amount)
					hp_changed.emit(unit)
			&"arts":
				var gained: float = unit.gain_arts(float(event.get("amount", 0.0)), balance)
				if gained > 0.0:
					arts_changed.emit(unit)
			&"expired":
				status_changed.emit(unit)
	if unit.is_broken:
		if unit.tick_break(delta):
			break_ended.emit(unit)
			log_message.emit("%s recovered from Break." % unit.display_name())


func _apply_periodic_damage(unit: UnitState, event: Dictionary) -> void:
	var amount: float = float(event.get("amount", 0.0))
	if amount <= 0.0:
		return
	var source: UnitState = event.get("source", null)
	var element: int = int(event.get("element", -1))
	if element < 0:
		element = source.element() if source != null else unit.element()
	var magical: bool = bool(event.get("magical", false))
	var params: DamageCalculator.DamageParams = DamageCalculator.DamageParams.new()
	params.source = source if source != null else unit
	params.target = unit
	params.base_amount = amount
	params.damage_kind = EffectDef.DamageKind.MAGICAL if magical else EffectDef.DamageKind.PHYSICAL
	params.element = element
	params.can_crit = false
	# Damage over time ignores defence.
	params.ignore_defense = true
	var result: DamageCalculator.DamageResult = DamageCalculator.apply(params, balance)
	var payload: Dictionary = result.to_dict()
	payload["source"] = source
	payload["target"] = unit
	payload["dot"] = true
	damage_dealt.emit(source if source != null else unit, unit, payload)
	hp_changed.emit(unit)
	_check_death(unit)


func _check_boss_phase(unit: UnitState, def: EnemyDef) -> void:
	## Bosses change phase exactly once, when they drop below their threshold.
	if not def.is_boss or unit.phase_two or unit.is_dead:
		return
	var ratio: float = unit.hp / maxf(1.0, unit.max_hp())
	if ratio > def.phase_change_threshold:
		return
	unit.phase_two = true
	if def.phase_change_ability != null:
		# The phase change is scripted, so it applies even while the boss is
		# broken or stunned - it is not an action the boss chooses.
		for effect: EffectDef in def.phase_change_ability.effects:
			var event: Dictionary = EffectApplier.apply(effect, unit, unit, balance)
			if not event.is_empty():
				event["ability_id"] = def.phase_change_ability.id
				event["ability_name"] = def.phase_change_ability.display_name
				_handle_event(event)
		ability_used.emit(unit, def.phase_change_ability, [unit])
	warning.emit("%s enters its second phase!" % unit.display_name())
	log_message.emit("%s changed phase." % unit.display_name())


func _start_windup(caster: UnitState, ability: AbilityDef, target: UnitState) -> void:
	if ability == null or caster == null:
		return
	if not AbilityExecutor.pay(caster, ability):
		return
	var action: PendingAction = PendingAction.new(caster, ability, target, &"enemy")
	pending.append(action)
	if ability.windup > 0.0:
		ability_windup.emit(caster, ability, ability.windup)
		if ability.target_mode == Targeting.Mode.ALL_ENEMIES:
			warning.emit("%s is preparing %s!" % [caster.display_name(), ability.display_name])
		else:
			warning.emit("%s winds up %s!" % [caster.display_name(), ability.display_name])


func _tick_pending(delta: float) -> void:
	for i in range(pending.size() - 1, -1, -1):
		var action: PendingAction = pending[i]
		action.remaining -= delta
		if action.remaining > 0.0:
			continue
		pending.remove_at(i)
		var caster: UnitState = action.caster
		if caster == null or caster.is_dead:
			continue
		if caster.status_blocks_actions() or caster.is_broken:
			continue
		var targets: Array = AbilityExecutor.resolve_targets(
			action.ability.target_mode, caster, allies, enemies, preferred_target, action.target)
		var events: Array[Dictionary] = AbilityExecutor.execute(action.ability, caster, targets, balance)
		ability_used.emit(caster, action.ability, targets)
		for event: Dictionary in events:
			_handle_event(event)


# --------------------------------------------------------------------------
# Activating abilities
# --------------------------------------------------------------------------

## Player triggered activation.  Returns true when the ability was used.
func use_ability(caster: UnitState, ability: AbilityDef) -> bool:
	if state != State.COMBAT:
		if caster != null and ability != null:
			ability_failed.emit(caster, ability, "Not in combat")
		return false
	if caster == null or ability == null:
		return false
	var reason: String = AbilityExecutor.blocked_reason(caster, ability, balance)
	if reason != "":
		ability_failed.emit(caster, ability, reason)
		return false
	var target: UnitState = _preferred_for(caster)
	return _activate_with_target(caster, ability, target, &"manual")


## Player triggered activation of an equipped item's active ability.
func use_equipment(caster: UnitState, ability_id: StringName) -> bool:
	if state != State.COMBAT:
		return false
	if caster == null or caster.is_dead:
		return false
	for entry: Dictionary in caster.equipment:
		var item: EquipmentDef = entry.get("def")
		if item == null or item.active_ability == null:
			continue
		if item.active_ability.id != ability_id:
			continue
		var reason: String = AbilityExecutor.blocked_reason(caster, item.active_ability, balance)
		if reason != "":
			ability_failed.emit(caster, item.active_ability, reason)
			return false
		return _activate_with_target(caster, item.active_ability, _preferred_for(caster), &"equipment")
	return false


func _preferred_for(caster: UnitState) -> UnitState:
	if caster == null:
		return null
	if caster.is_ally:
		return preferred_target
	return EnemyAI.pick_target(caster, allies)


func _activate(caster: UnitState, ability: AbilityDef, source_kind: StringName) -> bool:
	return _activate_with_target(caster, ability, _preferred_for(caster), source_kind)


func _activate_with_target(caster: UnitState, ability: AbilityDef, chosen: UnitState, source_kind: StringName) -> bool:
	if caster == null or ability == null or caster.is_dead:
		return false
	if caster.status_blocks_actions() or caster.is_broken:
		return false
	if not AbilityExecutor.can_use(caster, ability, balance):
		return false
	var targets: Array = AbilityExecutor.resolve_targets(
		ability.target_mode, caster, allies, enemies, preferred_target, chosen)
	if targets.is_empty() and ability.target_mode != Targeting.Mode.SELF:
		ability_failed.emit(caster, ability, "No valid target")
		return false
	# Pay first: a refused cost never leaves a half applied activation.
	if not AbilityExecutor.pay(caster, ability):
		ability_failed.emit(caster, ability, "Not enough arts")
		return false
	if ability.arts_generated > 0.0:
		caster.gain_arts(ability.arts_generated, balance)
	if ability.kind == AbilityDef.Kind.BASIC:
		caster.gain_arts(caster.arts_generated_per_attack(balance), balance)
	var events: Array[Dictionary] = AbilityExecutor.execute(ability, caster, targets, balance)
	ability_used.emit(caster, ability, targets)
	cooldown_changed.emit(caster, ability.id)
	arts_changed.emit(caster)
	for event: Dictionary in events:
		_handle_event(event)
	return true


func _handle_event(event: Dictionary) -> void:
	var kind: StringName = StringName(String(event.get("type", "")))
	match kind:
		EffectApplier.EVENT_DAMAGE:
			var target: UnitState = event.get("target", null)
			var source: UnitState = event.get("source", null)
			var payload: Dictionary = event.get("result", event)
			damage_dealt.emit(source, target, payload)
			if float(payload.get("absorbed", 0.0)) > 0.0:
				shield_absorbed.emit(target, float(payload.get("absorbed", 0.0)))
			hp_changed.emit(target)
			_check_death(target)
		EffectApplier.EVENT_HEAL:
			var healed_unit: UnitState = event.get("target", null)
			healed.emit(healed_unit, float(event.get("amount", 0.0)))
			hp_changed.emit(healed_unit)
		EffectApplier.EVENT_SHIELD:
			var shielded_unit: UnitState = event.get("target", null)
			shield_granted.emit(shielded_unit, float(event.get("amount", 0.0)))
			status_changed.emit(shielded_unit)
		EffectApplier.EVENT_STATUS:
			var status_unit: UnitState = event.get("target", null)
			status_changed.emit(status_unit)
		EffectApplier.EVENT_ARTS:
			var arts_unit: UnitState = event.get("target", null)
			arts_changed.emit(arts_unit)
		EffectApplier.EVENT_BREAK:
			var break_unit: UnitState = event.get("target", null)
			if bool(event.get("broke", false)):
				break_started.emit(break_unit)
				log_message.emit("%s is Broken!" % break_unit.display_name())


func _check_death(unit: UnitState) -> void:
	if unit == null or not unit.is_dead or unit.death_reported:
		return
	unit.death_reported = true
	unit_died.emit(unit)
	log_message.emit("%s was defeated." % unit.display_name())


# --------------------------------------------------------------------------
# Targeting
# --------------------------------------------------------------------------

func set_preferred_target(unit: UnitState) -> void:
	if unit == null or unit.is_dead:
		return
	if not enemies.has(unit):
		return
	preferred_target = unit
	target_changed.emit(unit)
	log_message.emit("Target: %s" % unit.display_name())


func living_allies() -> Array:
	var result: Array = []
	for unit: UnitState in allies:
		if unit.is_targetable():
			result.append(unit)
	return result


func living_enemies() -> Array:
	var result: Array = []
	for unit: UnitState in enemies:
		if unit.is_targetable():
			result.append(unit)
	return result


func boss_unit() -> UnitState:
	for unit: UnitState in enemies:
		if unit.def is EnemyDef and (unit.def as EnemyDef).is_boss:
			return unit
	return null


# --------------------------------------------------------------------------
# End of battle
# --------------------------------------------------------------------------

func _check_end_conditions() -> void:
	if state != State.COMBAT:
		return
	if living_allies().is_empty():
		_defeat()
		return
	if living_enemies().is_empty():
		_wave_cleared()


func _wave_cleared() -> void:
	_cleanup_dead_enemies()
	# Nothing may carry over into the next wave: no pending actions, no
	# delayed damage, no orphaned enemy views.
	pending.clear()
	wave_cleared.emit(wave_index)
	if quest != null and wave_index + 1 >= quest.wave_count():
		_victory()
	else:
		_enter_state(State.WAVE_TRANSITION)
		_transition_timer = balance.wave_break_seconds if balance != null else 2.0


func _cleanup_dead_enemies() -> void:
	var kept: Array[UnitState] = []
	for unit: UnitState in enemies:
		if unit.is_dead:
			if unit.view != null and is_instance_valid(unit.view):
				unit.view.queue_free()
			unit.view = null
		else:
			kept.append(unit)
	enemies = kept
	if preferred_target != null and (preferred_target.is_dead or not enemies.has(preferred_target)):
		preferred_target = null
		# The UI shows the current target, so it has to hear about the change.
		target_changed.emit(null)


func _victory() -> void:
	_enter_state(State.VICTORY)
	pending.clear()
	if not rewards_granted:
		rewards_granted = true
		last_results = Game.apply_battle_rewards(battle_token, quest, party_ids)
	_announce_result(true)


func _defeat() -> void:
	_enter_state(State.DEFEAT)
	pending.clear()
	_announce_result(false)


func _announce_result(victory: bool) -> void:
	if _results_announced:
		return
	_results_announced = true
	battle_finished.emit(victory, last_results)


## Aborts the battle without granting rewards (used when the player quits).
func abandon() -> void:
	pending.clear()
	_enter_state(State.DEFEAT)
	_results_announced = true
