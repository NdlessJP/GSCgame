class_name ItemInstance
extends RefCounted
## A single owned copy of an item.  Equipment assignments point at an instance
## id, so the same copy can never be equipped twice, while a second copy of an
## item can legitimately be equipped by another character.

var instance_id: String = ""
var item_id: StringName = &""
var acquired_from: String = ""


func _init(p_instance_id: String = "", p_item_id: StringName = &"") -> void:
	instance_id = p_instance_id
	item_id = p_item_id


func to_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"item_id": String(item_id),
		"acquired_from": acquired_from,
	}


static func from_dict(data: Dictionary) -> ItemInstance:
	return ItemInstance.new(
		String(data.get("instance_id", "")),
		StringName(String(data.get("item_id", ""))))
