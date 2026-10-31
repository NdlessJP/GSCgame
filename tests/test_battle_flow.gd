class_name BattleFlowTests
extends RefCounted
## Integration checks: whole quests are fought through the real battle
## controller with an auto-pilot that plays the party like a human would.
##
## Covered: waves advance, the party survives between waves, the boss changes
## phase exactly once, pausing freezes the clock and retrying rebuilds the
## battle from scratch.

const FRAME_LIMIT: int = 6000


static func run(host: Node) -> TestKit.Result:
	var result: TestKit.Result = TestKit.Result.new()
	var saved_levels: Dictionary = {}
	for character_id: Variant in Game.state.characters.keys():
		saved_levels[character_id] = Game.state.characters[character_id]
	# A fixed party keeps the check deterministic: damage, healing, tanking
	# and break damage are all represented.
	var saved_party: Array[StringName] = Game.state.party.duplicate()
	Game.state.party = [&"kael_vondar", &"seraphine_quill", &"torvald_grim", &"rune_ashmaw"]

	await _run_quest(host, &"quest_cinder_road", result, false)
	await _run_quest(host, &"quest_ashen_vault", result, true)
	await _run_quest(host, &"quest_pale_gate", result, false)

	for character_id: Variant in saved_levels.keys():
		var entry: Dictionary = saved_levels[character_id]
		Game.state.set_character_progress(StringName(String(character_id)),
			int(entry.get("level", 1)), int(entry.get("xp", 0)))
	Game.state.party = saved_party
	return result


## Sets every known character to the given level.
static func _set_party_level(level: int) -> void:
	for character_id: Variant in Game.state.characters.keys():
		Game.state.set_character_progress(StringName(String(character_id)), maxi(level, 1), 0)


## Fights one quest with the auto-pilot and checks the flow.
static func _run_quest(host: Node, quest_id: StringName, result: TestKit.Result, expect_boss: bool) -> void:
	var quest: QuestDef = Game.database.quest(quest_id)
	if quest == null:
		result.ok(false, "Quest '%s' exists" % quest_id)
		return

	var controller: BattleController = BattleController.new()
	host.add_child(controller)
	# Arrays are captured by reference, plain integers are not.
	var waves_started: Array[int] = []
	var phase_changes: Array[int] = []
	var break_events: Array[int] = []
	var windup_events: Array[int] = []
	var windup_durations: Array[float] = []
	controller.wave_started.connect(func(index: int, _count: int) -> void: waves_started.append(index))
	controller.break_started.connect(func(_unit: UnitState) -> void: break_events.append(1))
	controller.ability_windup.connect(func(_caster: UnitState, ability: AbilityDef, duration: float) -> void:
		windup_events.append(1)
		windup_durations.append(duration))
	controller.ability_used.connect(func(_caster: UnitState, ability: AbilityDef, _targets: Array) -> void:
		if ability.id == &"boss_phase":
			phase_changes.append(1))

	# Each quest is fought by a party at its recommended level, which is what
	# the quest board promises the player.  Quest 1 is fought at level 1, the
	# boss quest at its recommended level.
	_set_party_level(quest.recommended_level)

	var previous_scale: float = Engine.time_scale
	Engine.time_scale = 6.0
	controller.setup(quest, Game.party_ids(), Game.balance)

	var frames: int = 0
	while controller.state != BattleController.State.VICTORY \
			and controller.state != BattleController.State.DEFEAT \
			and frames < FRAME_LIMIT:
		_auto_pilot(controller)
		await host.get_tree().process_frame
		frames += 1

	result.ok(controller.state == BattleController.State.VICTORY,
		"The party clears '%s' (state was %s after %d frames)" % [quest.display_name, controller.state_name(), frames])
	result.ok(waves_started.size() == 3, "'%s' fights all three waves" % quest.display_name)
	result.ok(controller.pending.is_empty(), "'%s' leaves no pending actions" % quest.display_name)
	result.ok(windup_events.size() > 0,
		"'%s' shows at least one ability wind-up telegraph (%d)" % [quest.display_name, windup_events.size()])
	var all_telegraphed: bool = true
	for duration: float in windup_durations:
		if duration <= 0.0:
			all_telegraphed = false
	result.ok(all_telegraphed, "'%s' telegraphs every wind-up with a duration" % quest.display_name)
	result.ok(controller.living_allies().size() > 0, "'%s' ends with heroes standing" % quest.display_name)

	if expect_boss:
		var boss: UnitState = controller.boss_unit()
		result.ok(phase_changes.size() == 1, "The boss changes phase exactly once (was %d)" % phase_changes.size())
		result.ok(boss == null or boss.phase_two, "The boss reached its second phase")
		result.ok(break_events.size() > 0, "The party triggered at least one break (%d)" % break_events.size())

	# --- pause freezes the combat clock -----------------------------------
	if controller.state == BattleController.State.VICTORY and not controller.enemies.is_empty():
		var enemy: UnitState = controller.enemies[0]
		enemy.attack_timer = 5.0
		controller.pause()
		result.ok(controller.state == BattleController.State.PAUSED, "Pausing switches the battle state")
		var before_timer: float = enemy.attack_timer
		var before_hp: float = enemy.hp
		for i in range(20):
			await host.get_tree().process_frame
		result.approx(enemy.attack_timer, before_timer, "Pausing freezes the attack timers")
		result.approx(enemy.hp, before_hp, "Pausing freezes all damage")
		controller.resume()
		result.ok(controller.state != BattleController.State.PAUSED, "Resuming returns to the previous state")

	# --- retry rebuilds the battle ---------------------------------------
	controller.restart()
	result.ok(controller.state == BattleController.State.PREPARATION,
		"Retrying starts a fresh battle in the preparation phase")
	result.ok(controller.enemies.is_empty(), "Retrying clears the enemies")
	result.ok(controller.wave_index == -1, "Retrying resets the wave counter")
	result.ok(controller.pending.is_empty(), "Retrying clears pending actions")
	var full_health: bool = true
	for ally: UnitState in controller.allies:
		if not is_equal_approx(ally.hp, ally.max_hp()):
			full_health = false
	result.ok(full_health, "Retrying restores the party to full health")
	for ally: UnitState in controller.allies:
		result.ok(ally.arts <= Game.balance.arts_max, "The arts gauge stays within its bounds")

	Engine.time_scale = previous_scale
	controller.free()


## Plays the party the way a human would: arts when the gauge allows it,
## otherwise the skill, and equipment actives whenever they are ready.
static func _auto_pilot(controller: BattleController) -> void:
	for ally: UnitState in controller.allies:
		if ally.is_dead or not controller.is_combat_active():
			continue
		var def: CharacterDef = ally.def as CharacterDef
		if def == null:
			continue
		if def.true_arts != null and ally.arts >= Game.balance.true_arts_cost:
			if controller.use_ability(ally, def.true_arts):
				continue
		if def.arts != null and ally.arts >= Game.balance.arts_cost:
			if controller.use_ability(ally, def.arts):
				continue
		if def.skill != null and controller.use_ability(ally, def.skill):
			continue
		for entry: Dictionary in ally.equipment:
			var item: EquipmentDef = entry.get("def")
			if item == null or item.active_ability == null:
				continue
			controller.use_equipment(ally, item.active_ability.id)
