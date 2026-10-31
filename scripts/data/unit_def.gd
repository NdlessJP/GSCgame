class_name UnitDef
extends Resource
## Shared static definition for anything that can fight: characters and enemies.
##
## This resource is never mutated during battle.  Runtime values (current HP,
## arts gauge, cooldowns, statuses) live in scripts/units/unit_state.gd.

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
## Elements.Element value.
@export var element: int = Elements.Element.FIRE
@export var role: String = "Fighter"
@export var description: String = ""

@export_group("Base Stats (level 1)")
@export var base_max_hp: float = 120.0
@export var base_attack: float = 22.0
@export var base_defense: float = 12.0
@export var base_magic: float = 14.0
@export var base_magic_defense: float = 12.0

@export_group("Per Level Growth")
@export var hp_growth: float = 14.0
@export var attack_growth: float = 2.6
@export var defense_growth: float = 1.7
@export var magic_growth: float = 2.1
@export var magic_defense_growth: float = 1.6

@export_group("Placeholder Visual")
@export var body_color: Color = Color(0.8, 0.4, 0.4)
@export var accent_color: Color = Color(1, 1, 1)
@export var body_size: Vector2 = Vector2(32.0, 72.0)
## 0 = capsule, 1 = round, 2 = angular, 3 = robed, 4 = winged.
@export var body_shape: int = 0


## Maximum HP for the given level.
func max_hp_at(level: int) -> float:
	return base_max_hp + hp_growth * float(maxi(level, 1) - 1)


func attack_at(level: int) -> float:
	return base_attack + attack_growth * float(maxi(level, 1) - 1)


func defense_at(level: int) -> float:
	return base_defense + defense_growth * float(maxi(level, 1) - 1)


func magic_at(level: int) -> float:
	return base_magic + magic_growth * float(maxi(level, 1) - 1)


func magic_defense_at(level: int) -> float:
	return base_magic_defense + magic_defense_growth * float(maxi(level, 1) - 1)
