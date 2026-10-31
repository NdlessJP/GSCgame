class_name GameState
extends RefCounted
## The persistent player profile.  Only data that should survive a restart
## lives here; battle temporaries never touch it.

var currency: int = 0
## character id -> { "level": int, "xp": int }
var characters: Dictionary = {}
## character id -> array of equipment instance ids (indexed by slot)
var equipment: Dictionary = {}
var inventory: Inventory = Inventory.new()
## Ordered list of character ids, max 4.
var party: Array[StringName] = []
var quests_unlocked: Array[StringName] = []
var quests_completed: Array[StringName] = []


func character_data(character_id: StringName) -> Dictionary:
	if not characters.has(character_id):
		characters[character_id] = {"level": 1, "xp": 0}
	return characters[character_id]


func character_level(character_id: StringName) -> int:
	return int(character_data(character_id).get("level", 1))


func character_xp(character_id: StringName) -> int:
	return int(character_data(character_id).get("xp", 0))


func set_character_progress(character_id: StringName, level: int, xp: int) -> void:
	characters[character_id] = {"level": maxi(level, 1), "xp": maxi(xp, 0)}


func add_character(character_id: StringName) -> void:
	character_data(character_id)


func is_quest_unlocked(quest_id: StringName) -> bool:
	return quests_unlocked.has(quest_id)


func is_quest_completed(quest_id: StringName) -> bool:
	return quests_completed.has(quest_id)


func to_dict() -> Dictionary:
	var character_data_map: Dictionary = {}
	for key: Variant in characters.keys():
		var entry: Dictionary = characters[key]
		character_data_map[String(key)] = {
			"level": int(entry.get("level", 1)),
			"xp": int(entry.get("xp", 0)),
		}
	var equipment_map: Dictionary = {}
	for key: Variant in equipment.keys():
		var list: Array = equipment[key]
		var cleaned: Array = []
		for value: Variant in list:
			cleaned.append(String(value))
		equipment_map[String(key)] = cleaned
	var party_ids: Array = []
	for value: StringName in party:
		party_ids.append(String(value))
	var unlocked: Array = []
	for value: StringName in quests_unlocked:
		unlocked.append(String(value))
	var completed: Array = []
	for value: StringName in quests_completed:
		completed.append(String(value))
	return {
		"currency": currency,
		"characters": character_data_map,
		"equipment": equipment_map,
		"inventory": inventory.to_array(),
		"party": party_ids,
		"quests_unlocked": unlocked,
		"quests_completed": completed,
	}


static func from_dict(data: Dictionary) -> GameState:
	var state: GameState = GameState.new()
	state.currency = int(data.get("currency", 0))
	var characters: Dictionary = data.get("characters", {})
	for key: Variant in characters.keys():
		if typeof(characters[key]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = characters[key]
		state.characters[StringName(String(key))] = {
			"level": maxi(int(entry.get("level", 1)), 1),
			"xp": maxi(int(entry.get("xp", 0)), 0),
		}
	var equipment: Dictionary = data.get("equipment", {})
	for key: Variant in equipment.keys():
		if typeof(equipment[key]) != TYPE_ARRAY:
			continue
		var list: Array = []
		for value: Variant in equipment[key]:
			list.append(String(value))
		state.equipment[StringName(String(key))] = list
	var inventory_data: Array = data.get("inventory", [])
	state.inventory.from_array(inventory_data)
	var party: Array = data.get("party", [])
	for value: Variant in party:
		state.party.append(StringName(String(value)))
	var unlocked: Array = data.get("quests_unlocked", [])
	for value: Variant in unlocked:
		state.quests_unlocked.append(StringName(String(value)))
	var completed: Array = data.get("quests_completed", [])
	for value: Variant in completed:
		state.quests_completed.append(StringName(String(value)))
	return state
