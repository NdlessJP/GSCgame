extends Node
## The single application level coordinator (autoloaded as `Game`).
##
## It owns the persistent profile, the content database and the balance
## configuration.  It deliberately does *not* own combat logic: the battle
## controller and the UI talk to each other through signals.

signal progress_changed
signal party_changed
signal inventory_changed
signal notice(text: String)

const DEFAULT_PARTY: Array[StringName] = [
	&"kael_vondar", &"seraphine_quill", &"torvald_grim", &"lysa_venne",
]
## Starter items handed out with a new profile (duplicates on purpose so that
## multi-copy equipping can be exercised).
const STARTER_ITEMS: Array[StringName] = [
	&"emberbrand_blade", &"emberbrand_blade", &"bulwark_plate", &"bulwark_plate",
	&"healers_knot", &"resonance_bell", &"stormcaller_rod", &"wardens_cloak",
]
## Default loadout: character id -> [instance id per slot]
const STARTER_LOADOUT: Dictionary = {
	&"kael_vondar": ["inst_0001", "inst_0003", ""],
	&"seraphine_quill": ["inst_0005", "", "inst_0006"],
	&"torvald_grim": ["inst_0004", "", ""],
	&"lysa_venne": ["inst_0007", "", ""],
}

var database: GameDatabase = null
var balance: BalanceConfig = null
var state: GameState = null
## Summary of the last battle, shown on the results screen.
var last_results: Dictionary = {}
## Quest the player is about to run / just ran.
var pending_quest_id: StringName = &""
## Outcome of the last battle.
var last_battle_victory: bool = false
## Tokens of battles whose rewards have already been granted this session.
var _granted_battles: Dictionary = {}
var _last_save_message: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	database = GameDatabase.load_all()
	balance = database.balance
	if not database.load_issues.is_empty():
		for issue: String in database.load_issues:
			push_warning("GameDatabase: %s" % issue)
	load_or_create_profile()


# --------------------------------------------------------------------------
# Profile lifecycle
# --------------------------------------------------------------------------

func load_or_create_profile() -> void:
	var result: Dictionary = SaveService.load_state()
	state = result.get("state", GameState.new())
	_last_save_message = String(result.get("message", ""))
	if not bool(result.get("ok", true)):
		push_warning("SaveService: %s" % _last_save_message)
	var problems: Array[String] = database.validate_loaded_state(state)
	for problem: String in problems:
		push_warning("SaveService repaired save: %s" % problem)
	if state.characters.is_empty():
		_populate_new_profile()
	save_game()
	_emit_changed()


## Creates a fresh profile with every character available (prototype build).
func new_game() -> void:
	state = GameState.new()
	_populate_new_profile()
	save_game()
	_emit_changed()


func _populate_new_profile() -> void:
	for id: Variant in database.characters.keys():
		state.characters[id] = {"level": 1, "xp": 0}
	for item_id: StringName in STARTER_ITEMS:
		state.inventory.add(item_id, "starter")
	for character_id: StringName in DEFAULT_PARTY:
		if database.character(character_id) != null:
			state.party.append(character_id)
	for character_id: StringName in DEFAULT_PARTY:
		var loadout: Array = STARTER_LOADOUT.get(character_id, [])
		if loadout.is_empty():
			continue
		var list: Array = []
		for value: Variant in loadout:
			list.append(String(value))
		state.equipment[character_id] = list
	# Only the first quest is unlocked; the others unlock by completion.
	var quest_ids: Array = database.quest_ids()
	if not quest_ids.is_empty():
		state.quests_unlocked.append(StringName(String(quest_ids[0])))


func save_game() -> bool:
	var ok: bool = SaveService.save_state(state)
	if not ok:
		_last_save_message = "Saving failed."
		push_error("Game: could not save the profile.")
	else:
		_last_save_message = "Profile saved."
	return ok


func last_save_message() -> String:
	return _last_save_message


func _emit_changed() -> void:
	progress_changed.emit()
	party_changed.emit()
	inventory_changed.emit()


# --------------------------------------------------------------------------
# Party helpers
# --------------------------------------------------------------------------

func party_ids() -> Array[StringName]:
	return state.party.duplicate()


func party_size() -> int:
	return state.party.size()


func is_in_party(character_id: StringName) -> bool:
	return state.party.has(character_id)


func add_to_party(character_id: StringName) -> bool:
	if state.party.has(character_id):
		return false
	if state.party.size() >= 4:
		return false
	if database.character(character_id) == null:
		return false
	state.party.append(character_id)
	party_changed.emit()
	return true


func remove_from_party(character_id: StringName) -> bool:
	var index: int = state.party.find(character_id)
	if index < 0:
		return false
	state.party.remove_at(index)
	party_changed.emit()
	return true


func swap_party_member(slot: int, character_id: StringName) -> bool:
	if slot < 0 or slot >= 4:
		return false
	if database.character(character_id) == null:
		return false
	while state.party.size() < 4:
		state.party.append(&"")
	var existing: int = state.party.find(character_id)
	if existing >= 0 and existing != slot:
		var previous: StringName = state.party[slot]
		state.party[slot] = character_id
		state.party[existing] = previous
	else:
		state.party[slot] = character_id
	# Clean up empty slots at the end.
	while state.party.size() > 0 and state.party[state.party.size() - 1] == &"":
		state.party.pop_back()
	party_changed.emit()
	return true


# --------------------------------------------------------------------------
# Equipment helpers
# --------------------------------------------------------------------------

func equip_item(character_id: StringName, slot_index: int, instance_id: String) -> bool:
	var def: CharacterDef = database.character(character_id)
	var instance: ItemInstance = state.inventory.find(instance_id)
	if def == null or instance == null:
		return false
	var item: EquipmentDef = database.equipment_def(instance.item_id)
	if not EquipmentRules.assign(def, slot_index, item, instance_id, state.equipment):
		return false
	inventory_changed.emit()
	return true


func unequip_item(character_id: StringName, slot_index: int) -> bool:
	var def: CharacterDef = database.character(character_id)
	if def == null:
		return false
	var ok: bool = EquipmentRules.clear(def, slot_index, state.equipment)
	if ok:
		inventory_changed.emit()
	return ok


func equipped_instances(character_id: StringName) -> Array:
	return EquipmentRules.slot_list(database.character(character_id), state.equipment)


# --------------------------------------------------------------------------
# Quest helpers
# --------------------------------------------------------------------------

func is_quest_unlocked(quest_id: StringName) -> bool:
	return state.quests_unlocked.has(quest_id)


func unlock_quest(quest_id: StringName) -> void:
	if database.quest(quest_id) == null:
		return
	if not state.quests_unlocked.has(quest_id):
		state.quests_unlocked.append(quest_id)
		progress_changed.emit()


func is_quest_completed(quest_id: StringName) -> bool:
	return state.quests_completed.has(quest_id)


# --------------------------------------------------------------------------
# Rewards
# --------------------------------------------------------------------------

## Grants the rewards of a finished battle exactly once.
## `token` identifies the battle instance; granting the same token twice is
## refused, which protects against double rewards from duplicated signals.
func apply_battle_rewards(token: String, quest: QuestDef, character_ids: Array) -> Dictionary:
	if token == "" or _granted_battles.has(token):
		return {}
	if quest == null:
		return {}
	_granted_battles[token] = true

	var summary: Dictionary = {
		"xp": 0,
		"currency": 0,
		"levels": {},
		"items": [],
	}
	var total_xp: int = quest.reward_xp
	var per_character: int = int(round(float(total_xp) / maxf(1.0, float(character_ids.size()))))
	if character_ids.is_empty():
		per_character = 0
	for character_id: Variant in character_ids:
		var id: StringName = StringName(String(character_id))
		if database.character(id) == null:
			continue
		var level: int = state.character_level(id)
		var xp: int = state.character_xp(id)
		var result: Dictionary = Progression.grant_xp(level, xp, per_character, balance)
		state.set_character_progress(id, int(result["level"]), int(result["xp"]))
		summary["levels"][id] = {
			"level": int(result["level"]),
			"xp": int(result["xp"]),
			"levels_gained": int(result["levels_gained"]),
		}
		summary["xp"] = int(summary["xp"]) + per_character

	state.currency += quest.reward_currency
	summary["currency"] = quest.reward_currency

	if not state.quests_unlocked.has(quest.id):
		state.quests_unlocked.append(quest.id)
	var first_completion: bool = not state.quests_completed.has(quest.id)
	if first_completion:
		state.quests_completed.append(quest.id)
		for item_id: StringName in quest.reward_items:
			var instance: ItemInstance = state.inventory.add(item_id, String(quest.id))
			summary["items"].append(instance.instance_id)
		# Unlock the next quest if it requires this one.
		for quest_id: Variant in database.quests.keys():
			var next_quest: QuestDef = database.quests[quest_id]
			if next_quest.requires_quest == quest.id and not state.quests_unlocked.has(next_quest.id):
				state.quests_unlocked.append(next_quest.id)

	last_results = summary
	save_game()
	_emit_changed()
	return summary


# --------------------------------------------------------------------------
# Scene helpers
# --------------------------------------------------------------------------

func goto_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
