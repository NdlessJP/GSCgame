class_name EquipmentSlotDef
extends Resource
## One of a character's three equipment slots.
##
## The allowed categories decide which items may be placed in the slot.  A slot
## with an empty allow list accepts every category.

@export var id: StringName = &"slot"
@export var display_name: String = "Slot"
## EquipmentDef.Category values accepted by this slot.
@export var allowed_categories: Array[int] = []


func accepts_category(category: int) -> bool:
	if allowed_categories.is_empty():
		return true
	return allowed_categories.has(category)


## Human readable list of the categories this slot accepts.
func description_for_categories() -> String:
	if allowed_categories.is_empty():
		return "Accepts any category"
	var names: Array = []
	for category: int in allowed_categories:
		names.append(EquipmentDef.CATEGORY_NAMES.get(category, "Unknown"))
	return "Accepts: %s" % ", ".join(names)
