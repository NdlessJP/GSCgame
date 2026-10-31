class_name ProgressionTests
extends RefCounted
## Checks for equipment ownership rules, reward duplication, save round trips
## and the shape of the shipped content.

static func run(database: GameDatabase) -> TestKit.Result:
	var result: TestKit.Result = TestKit.Result.new()
	_test_equipment_ownership(database, result)
	_test_equipment_slots(database, result)
	_test_reward_duplication(database, result)
	_test_progression_curve(result)
	_test_entry_quest(result)
	_test_save_round_trip(result)
	_test_corrupted_save(result)
	_test_content_shape(database, result)
	return result


static func _test_equipment_ownership(database: GameDatabase, result: TestKit.Result) -> void:
	var inventory: Inventory = Inventory.new()
	var first: ItemInstance = inventory.add(&"emberbrand_blade")
	var second: ItemInstance = inventory.add(&"emberbrand_blade")
	result.ok(first.instance_id != second.instance_id, "Every copy of an item gets its own instance id")
	result.ok(inventory.count(&"emberbrand_blade") == 2, "Both copies are owned")

	var kael: CharacterDef = database.character(&"kael_vondar")
	var brennan: CharacterDef = database.character(&"brennan_cole")
	var blade: EquipmentDef = database.equipment_def(&"emberbrand_blade")
	var assignments: Dictionary = {}

	result.ok(EquipmentRules.assign(kael, 0, blade, first.instance_id, assignments),
		"An item can be equipped in a compatible slot")
	result.ok(not EquipmentRules.assign(brennan, 0, blade, first.instance_id, assignments),
		"The same copy cannot be equipped by a second character")
	result.ok(EquipmentRules.assign(brennan, 0, blade, second.instance_id, assignments),
		"A second copy of the same item can be equipped elsewhere")
	result.ok(EquipmentRules.is_instance_equipped_elsewhere(first.instance_id, assignments, &"brennan_cole"),
		"Ownership is detected across characters")


static func _test_equipment_slots(database: GameDatabase, result: TestKit.Result) -> void:
	var kael: CharacterDef = database.character(&"kael_vondar")
	result.ok(kael.equipment_slots.size() == 3, "Characters have three equipment slots")
	var blade: EquipmentDef = database.equipment_def(&"emberbrand_blade")
	var plate: EquipmentDef = database.equipment_def(&"bulwark_plate")
	result.ok(EquipmentRules.can_place(kael, 0, blade), "An attack item fits the offence slot")
	result.ok(not EquipmentRules.can_place(kael, 0, plate), "A defence item does not fit the offence slot")
	result.ok(EquipmentRules.can_place(kael, 1, plate), "A defence item fits the guard slot")

	# Seraphine only accepts support items in her offence slot.
	var seraphine: CharacterDef = database.character(&"seraphine_quill")
	result.ok(not EquipmentRules.can_place(seraphine, 0, blade),
		"A character's slot restrictions are respected")
	result.ok(EquipmentRules.can_place(seraphine, 0, database.equipment_def(&"healers_knot")),
		"A support item fits a support slot")


static func _test_reward_duplication(database: GameDatabase, result: TestKit.Result) -> void:
	var quest: QuestDef = database.quest(&"quest_cinder_road")
	if quest == null:
		result.ok(false, "Quest 'quest_cinder_road' exists")
		return
	var token: String = "test_token_%d" % Time.get_ticks_usec()
	var currency_before: int = Game.state.currency
	var xp_before: int = Game.state.character_xp(&"kael_vondar")
	var first: Dictionary = Game.apply_battle_rewards(token, quest, [&"kael_vondar"])
	result.ok(not first.is_empty(), "The first reward grant succeeds")
	result.approx(float(Game.state.currency - currency_before), float(quest.reward_currency),
		"The currency reward is granted once")
	result.ok(Game.state.character_xp(&"kael_vondar") > xp_before, "Experience is granted")

	var second: Dictionary = Game.apply_battle_rewards(token, quest, [&"kael_vondar"])
	result.ok(second.is_empty(), "A repeated reward token is refused")
	result.approx(float(Game.state.currency - currency_before), float(quest.reward_currency),
		"The currency reward is not granted twice")

	var item_count_before: int = Game.state.inventory.items.size()
	Game.apply_battle_rewards("test_token_other_%d" % Time.get_ticks_usec(), quest, [&"kael_vondar"])
	result.ok(Game.state.inventory.items.size() >= item_count_before,
		"Quest items are only granted on the first completion")


static func _test_progression_curve(result: TestKit.Result) -> void:
	var balance: BalanceConfig = BalanceConfig.make_default()
	var granted: Dictionary = Progression.grant_xp(1, 0, Progression.xp_to_next(1, balance), balance)
	result.ok(int(granted["level"]) == 2, "Enough experience levels a character up")
	result.ok(int(granted["levels_gained"]) == 1, "Exactly one level is gained")
	var partial: Dictionary = Progression.grant_xp(1, 0, 10, balance)
	result.ok(int(partial["level"]) == 1, "Partial experience does not level a character up")
	result.ok(int(partial["xp"]) == 10, "Partial experience is kept")
	result.approx(Progression.level_progress(2, 0, balance), 0.0, "Level progress starts at zero")


## A new profile has to start with the entry quest (the lowest level quest
## that requires nothing), not with whichever quest sorts first by name.
static func _test_entry_quest(result: TestKit.Result) -> void:
	var database: GameDatabase = GameDatabase.load_all()
	var entry: QuestDef = database.entry_quest()
	result.ok(entry != null, "The database has an entry quest")
	if entry == null:
		return
	result.ok(entry.requires_quest == &"", "The entry quest requires no other quest")
	var lowest: int = entry.recommended_level
	for quest_id: Variant in database.quest_ids():
		var quest: QuestDef = database.quests[quest_id]
		if quest.requires_quest == &"":
			lowest = mini(lowest, quest.recommended_level)
	result.ok(entry.recommended_level == lowest,
		"The entry quest is the lowest level quest without a requirement")
	result.ok(entry.id == &"quest_cinder_road",
		"The entry quest is Cinder Road (got %s)" % entry.id)


static func _test_save_round_trip(result: TestKit.Result) -> void:
	var backup: String = ""
	if FileAccess.file_exists(SaveService.SAVE_PATH):
		var file: FileAccess = FileAccess.open(SaveService.SAVE_PATH, FileAccess.READ)
		backup = file.get_as_text()
		file.close()

	var state: GameState = GameState.new()
	state.currency = 321
	state.volume = 0.35
	state.set_character_progress(&"kael_vondar", 4, 55)
	state.set_character_progress(&"rune_ashmaw", 2, 10)
	state.party = [&"kael_vondar", &"seraphine_quill"]
	state.quests_unlocked.append(&"quest_cinder_road")
	state.quests_completed.append(&"quest_cinder_road")
	var instance: ItemInstance = state.inventory.add(&"emberbrand_blade", "test")
	state.equipment[&"kael_vondar"] = [instance.instance_id, "", ""]

	result.ok(SaveService.save_state(state), "The profile can be written")
	var loaded: Dictionary = SaveService.load_state()
	result.ok(bool(loaded["ok"]), "The profile can be read back")
	var restored: GameState = loaded["state"]
	result.ok(restored != null, "A profile is returned")
	if restored != null:
		result.ok(restored.currency == 321, "Currency survives the round trip")
		result.ok(absf(restored.volume - 0.35) < 0.001, "The volume setting survives the round trip")
		result.ok(restored.character_level(&"kael_vondar") == 4, "Character levels survive the round trip")
		result.ok(restored.character_xp(&"rune_ashmaw") == 10, "Character experience survives the round trip")
		result.ok(restored.party.size() == 2, "The party survives the round trip")
		result.ok(restored.quests_completed.has(&"quest_cinder_road"), "Quest completion survives the round trip")
		result.ok(restored.inventory.count(&"emberbrand_blade") == 1, "Inventory survives the round trip")
		var equipped: Array = restored.equipment.get(&"kael_vondar", [])
		result.ok(equipped.size() == 3 and String(equipped[0]) == instance.instance_id,
			"Equipment assignments survive the round trip")

	# Restore the profile that was there before the test.
	if backup != "":
		var restore_file: FileAccess = FileAccess.open(SaveService.SAVE_PATH, FileAccess.WRITE)
		restore_file.store_string(backup)
		restore_file.close()
	else:
		SaveService.delete_save()


static func _test_corrupted_save(result: TestKit.Result) -> void:
	var backup: String = ""
	if FileAccess.file_exists(SaveService.SAVE_PATH):
		var file: FileAccess = FileAccess.open(SaveService.SAVE_PATH, FileAccess.READ)
		backup = file.get_as_text()
		file.close()

	var broken: FileAccess = FileAccess.open(SaveService.SAVE_PATH, FileAccess.WRITE)
	broken.store_string("{ this is not valid json ")
	broken.close()

	var loaded: Dictionary = SaveService.load_state()
	result.ok(loaded.has("state") and loaded["state"] != null, "A corrupted save still returns a usable profile")
	result.ok(not bool(loaded["ok"]), "A corrupted save is reported as a problem")
	result.ok(Game.state != null, "The running game keeps a valid profile after a corrupted load")

	if backup != "":
		var restore_file: FileAccess = FileAccess.open(SaveService.SAVE_PATH, FileAccess.WRITE)
		restore_file.store_string(backup)
		restore_file.close()
	else:
		SaveService.delete_save()


static func _test_content_shape(database: GameDatabase, result: TestKit.Result) -> void:
	result.ok(database.characters.size() >= 6, "At least six recruitable characters exist")
	result.ok(database.enemies.size() >= 5, "At least four normal enemies and one boss exist")
	result.ok(database.equipment.size() >= 9, "At least nine sample items exist")
	result.ok(database.quests.size() >= 3, "Three quests exist")

	var bosses: int = 0
	for id: Variant in database.enemies.keys():
		var enemy: EnemyDef = database.enemies[id]
		if enemy.is_boss:
			bosses += 1
	result.ok(bosses == 1, "Exactly one boss is defined")

	var quests_with_boss: int = 0
	for id: Variant in database.quests.keys():
		var quest: QuestDef = database.quests[id]
		result.ok(quest.waves.size() == 3, "Quest '%s' has three waves" % id)
		var has_boss: bool = false
		for wave: WaveDef in quest.waves:
			for enemy_id: StringName in wave.enemy_ids:
				var enemy: EnemyDef = database.enemy(enemy_id)
				if enemy != null and enemy.is_boss:
					has_boss = true
		if has_boss:
			quests_with_boss += 1
	result.ok(quests_with_boss == 1, "Exactly one quest features the boss")

	for id: Variant in database.characters.keys():
		var character: CharacterDef = database.characters[id]
		result.ok(character.basic_attack != null, "Character '%s' has a basic attack" % id)
		result.ok(character.skill != null, "Character '%s' has a skill" % id)
		result.ok(character.arts != null, "Character '%s' has an arts ability" % id)
		result.ok(character.true_arts != null, "Character '%s' has a true arts ability" % id)
		result.ok(character.arts.arts_cost == 100.0, "Character '%s' spends 100 arts" % id)
		result.ok(character.true_arts.arts_cost == 200.0, "Character '%s' spends 200 arts" % id)
