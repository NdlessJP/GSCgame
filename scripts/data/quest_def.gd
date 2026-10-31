class_name QuestDef
extends Resource
## Static definition of a quest: a sequence of waves plus the rewards for
## clearing it.

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var recommended_level: int = 1
## Quest that must be completed first.  Empty means unlocked from the start.
@export var requires_quest: StringName = &""

@export_group("Encounter")
@export var waves: Array[WaveDef] = []

@export_group("Rewards")
@export var reward_xp: int = 120
@export var reward_currency: int = 60
## Equipment ids granted on first completion.
@export var reward_items: Array[StringName] = []


func wave_count() -> int:
	return waves.size()
