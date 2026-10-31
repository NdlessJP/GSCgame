class_name EquipmentRules
extends RefCounted
## Validation and assignment rules for equipment.
##
## Rules enforced:
##  * the item must exist in the inventory (one copy per instance),
##  * the item's category must be accepted by the target slot,
##  * the same instance cannot be equipped by two characters at once,
##  * a character never has more items than it has slots.

static func can_place(def: CharacterDef, slot_index: int, item: EquipmentDef) -> bool:
	if def == null or item == null:
		return false
	if slot_index < 0 or slot_index >= def.equipment_slots.size():
		return false
	var slot: EquipmentSlotDef = def.equipment_slots[slot_index]
	return slot.accepts_category(item.category)


static func is_instance_equipped_elsewhere(instance_id: String, assignments: Dictionary, except_character: StringName) -> bool:
	for character_id: Variant in assignments.keys():
		if character_id == except_character:
			continue
		var list: Array = assignments.get(character_id, [])
		if list.has(instance_id):
			return true
	return false


## Assigns an item instance to a character slot.  Returns true on success.
static func assign(
	def: CharacterDef,
	slot_index: int,
	item: EquipmentDef,
	instance_id: String,
	assignments: Dictionary
) -> bool:
	if not can_place(def, slot_index, item):
		return false
	if is_instance_equipped_elsewhere(instance_id, assignments, def.id):
		return false
	var list: Array = assignments.get(def.id, [])
	if list.size() <= slot_index:
		while list.size() <= slot_index:
			list.append("")
	list[slot_index] = instance_id
	assignments[def.id] = list
	return true


## Clears a slot.  Returns true when something was removed.
static func clear(def: CharacterDef, slot_index: int, assignments: Dictionary) -> bool:
	var list: Array = assignments.get(def.id, [])
	if slot_index < 0 or slot_index >= list.size():
		return false
	if String(list[slot_index]) == "":
		return false
	list[slot_index] = ""
	assignments[def.id] = list
	return true


## Returns the list of instance ids assigned to a character, padded to the
## character's slot count so indexes always line up.
static func slot_list(def: CharacterDef, assignments: Dictionary) -> Array:
	var list: Array = assignments.get(def.id, [])
	var result: Array = []
	for i in range(def.equipment_slots.size()):
		var value: String = ""
		if i < list.size():
			value = String(list[i])
		result.append(value)
	return result
