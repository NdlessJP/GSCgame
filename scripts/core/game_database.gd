class_name GameDatabase
extends RefCounted
## Loads and indexes every static definition in the project.
##
## The database is built from .tres resources on disk, which keeps the content
## designer friendly: add a file, it shows up in the game.  Nothing here is
## mutated at runtime.

var characters: Dictionary = {}
var enemies: Dictionary = {}
var equipment: Dictionary = {}
var quests: Dictionary = {}
var statuses: Dictionary = {}
var abilities: Dictionary = {}
var balance: BalanceConfig = null
## Non fatal problems found while loading (missing ids, bad references...).
var load_issues: Array[String] = []


static func load_all(base_dir: String = "res://resources") -> GameDatabase:
	var db: GameDatabase = GameDatabase.new()
	db.balance = _load_balance(base_dir)
	db._load_directory(base_dir + "/characters", "character", db.characters)
	db._load_directory(base_dir + "/enemies", "enemy", db.enemies)
	db._load_directory(base_dir + "/equipment", "equipment", db.equipment)
	db._load_directory(base_dir + "/quests", "quest", db.quests)
	db._load_directory(base_dir + "/statuses", "status", db.statuses)
	db._load_directory(base_dir + "/abilities", "ability", db.abilities)
	db._validate_references()
	return db


static func _load_balance(base_dir: String) -> BalanceConfig:
	var path: String = base_dir + "/balance.tres"
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is BalanceConfig:
			return res
	return BalanceConfig.make_default()


func _load_directory(path: String, kind: String, target: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(path):
		load_issues.append("Missing content directory: %s" % path)
		return
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		load_issues.append("Could not open content directory: %s" % path)
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "tres":
			var full: String = path + "/" + file_name
			var res: Resource = load(full)
			if res == null:
				load_issues.append("Could not load %s (%s)" % [full, kind])
			elif res.get("id") == null or String(res.get("id")) == "":
				load_issues.append("%s has no id" % full)
			else:
				var id: StringName = StringName(String(res.get("id")))
				if target.has(id):
					load_issues.append("Duplicate %s id '%s' in %s" % [kind, id, file_name])
				target[id] = res
		file_name = dir.get_next()
	dir.list_dir_end()


func _validate_references() -> void:
	for id: Variant in characters.keys():
		var def: CharacterDef = characters[id]
		if def.basic_attack == null:
			load_issues.append("Character '%s' has no basic attack." % id)
		if def.skill == null:
			load_issues.append("Character '%s' has no skill." % id)
		if def.arts == null:
			load_issues.append("Character '%s' has no arts." % id)
		if def.true_arts == null:
			load_issues.append("Character '%s' has no true arts." % id)
		if def.equipment_slots.is_empty():
			load_issues.append("Character '%s' has no equipment slots." % id)
	for id: Variant in quests.keys():
		var quest: QuestDef = quests[id]
		for wave: WaveDef in quest.waves:
			for enemy_id: StringName in wave.enemy_ids:
				if not enemies.has(enemy_id):
					load_issues.append("Quest '%s' references unknown enemy '%s'." % [id, enemy_id])


# --------------------------------------------------------------------------
# Lookups
# --------------------------------------------------------------------------

func character(id: StringName) -> CharacterDef:
	return characters.get(id, null)


func enemy(id: StringName) -> EnemyDef:
	return enemies.get(id, null)


func equipment_def(id: StringName) -> EquipmentDef:
	return equipment.get(id, null)


func quest(id: StringName) -> QuestDef:
	return quests.get(id, null)


func status(id: StringName) -> StatusDef:
	return statuses.get(id, null)


func character_ids() -> Array:
	var result: Array = []
	for id: Variant in characters.keys():
		result.append(id)
	result.sort()
	return result


func quest_ids() -> Array:
	var result: Array = []
	for id: Variant in quests.keys():
		result.append(id)
	result.sort()
	return result


func equipment_ids() -> Array:
	var result: Array = []
	for id: Variant in equipment.keys():
		result.append(id)
	result.sort()
	return result


# --------------------------------------------------------------------------
# Validation of loaded save data
# --------------------------------------------------------------------------

## Removes unknown ids from a loaded profile so a damaged save can never
## produce an invalid game state.  Returns the list of problems that were
## repaired.
func validate_loaded_state(state: GameState) -> Array[String]:
	var problems: Array[String] = []
	if state == null:
		return problems

	for id: Variant in state.characters.keys():
		if not characters.has(id):
			problems.append("Dropped unknown character '%s'." % id)
			state.characters.erase(id)

	for id: Variant in state.equipment.keys():
		if not characters.has(id):
			problems.append("Dropped equipment assignment for unknown character '%s'." % id)
			state.equipment.erase(id)
			continue
		var def: CharacterDef = characters[id]
		var list: Array = state.equipment[id]
		var cleaned: Array = []
		for index in range(list.size()):
			var instance_id: String = String(list[index])
			if instance_id == "":
				cleaned.append("")
				continue
			var instance: ItemInstance = state.inventory.find(instance_id)
			if instance == null:
				problems.append("Dropped assignment of missing item '%s'." % instance_id)
				cleaned.append("")
				continue
			if not EquipmentRules.can_place(def, index, equipment_def(instance.item_id)):
				problems.append("Item '%s' is not compatible with slot %d of '%s'." % [instance.item_id, index + 1, id])
				cleaned.append("")
				continue
			cleaned.append(instance_id)
		state.equipment[id] = cleaned

	# Remove duplicate assignments of the same instance.
	var seen: Dictionary = {}
	for id: Variant in state.equipment.keys():
		var list: Array = state.equipment[id]
		for index in range(list.size()):
			var instance_id: String = String(list[index])
			if instance_id == "":
				continue
			if seen.has(instance_id):
				problems.append("Item '%s' was assigned more than once; the duplicate was removed." % instance_id)
				list[index] = ""
			else:
				seen[instance_id] = true

	var valid_inventory: Array[ItemInstance] = []
	for item: ItemInstance in state.inventory.items:
		if equipment.has(item.item_id):
			valid_inventory.append(item)
		else:
			problems.append("Dropped unknown item '%s' from the inventory." % item.item_id)
	state.inventory.items = valid_inventory

	var valid_party: Array[StringName] = []
	for character_id: StringName in state.party:
		if characters.has(character_id) and not valid_party.has(character_id):
			valid_party.append(character_id)
		else:
			problems.append("Dropped invalid party member '%s'." % character_id)
	while valid_party.size() > 4:
		problems.append("Party had more than four members; the extra member was removed.")
		valid_party.pop_back()
	state.party = valid_party

	for quest_id: StringName in state.quests_completed:
		if not quests.has(quest_id):
			problems.append("Dropped unknown completed quest '%s'." % quest_id)
			state.quests_completed.erase(quest_id)
	for quest_id: StringName in state.quests_unlocked:
		if not quests.has(quest_id):
			problems.append("Dropped unknown unlocked quest '%s'." % quest_id)
			state.quests_unlocked.erase(quest_id)
	return problems
