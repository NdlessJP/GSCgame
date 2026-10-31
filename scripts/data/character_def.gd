class_name CharacterDef
extends UnitDef
## Static definition of a recruitable party member.

@export_group("Abilities")
@export var basic_attack: AbilityDef = null
@export var skill: AbilityDef = null
@export var arts: AbilityDef = null
@export var true_arts: AbilityDef = null

@export_group("Equipment")
## The three configurable slots this character may equip items into.
@export var equipment_slots: Array[EquipmentSlotDef] = []

@export_group("Lore")
@export var lore: String = ""

@export_group("Roster")
## Controls the order characters appear in the party screen.
@export var roster_order: int = 0


## Returns the ability that occupies a given slot kind, or null.
func ability_for_kind(kind: int) -> AbilityDef:
	match kind:
		AbilityDef.Kind.BASIC: return basic_attack
		AbilityDef.Kind.SKILL: return skill
		AbilityDef.Kind.ARTS: return arts
		AbilityDef.Kind.TRUE_ARTS: return true_arts
	return null


func slot_count() -> int:
	return equipment_slots.size()
