class_name Inventory
extends RefCounted
## Player owned items.  Every copy of an item is tracked as its own instance so
## that equipment assignments stay unambiguous.

var items: Array[ItemInstance] = []
var _next_index: int = 1


func add(item_id: StringName, source: String = "") -> ItemInstance:
	var instance: ItemInstance = ItemInstance.new(_make_instance_id(), item_id)
	instance.acquired_from = source
	items.append(instance)
	return instance


func add_instance(instance: ItemInstance) -> void:
	if instance != null:
		items.append(instance)


func remove_instance(instance_id: String) -> bool:
	for i in range(items.size()):
		if items[i].instance_id == instance_id:
			items.remove_at(i)
			return true
	return false


func find(instance_id: String) -> ItemInstance:
	for item: ItemInstance in items:
		if item.instance_id == instance_id:
			return item
	return null


func count(item_id: StringName) -> int:
	var total: int = 0
	for item: ItemInstance in items:
		if item.item_id == item_id:
			total += 1
	return total


func all_of(item_id: StringName) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item: ItemInstance in items:
		if item.item_id == item_id:
			result.append(item)
	return result


func has(item_id: StringName) -> bool:
	return count(item_id) > 0


func clear() -> void:
	items.clear()
	_next_index = 1


func to_array() -> Array:
	var result: Array = []
	for item: ItemInstance in items:
		result.append(item.to_dict())
	return result


func from_array(data: Array) -> void:
	items.clear()
	_next_index = 1
	for entry: Variant in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var instance: ItemInstance = ItemInstance.from_dict(entry)
		if instance.instance_id == "" or instance.item_id == &"":
			continue
		add_instance(instance)


func _make_instance_id() -> String:
	var id: String = "inst_%04d" % _next_index
	_next_index += 1
	while find(id) != null:
		id = "inst_%04d" % _next_index
		_next_index += 1
	return id
