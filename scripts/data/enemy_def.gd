class_name EnemyDef
extends UnitDef
## Static definition of an enemy, including its AI behaviour.

enum TargetPreference {
	## Prefer the first living ally (deterministic, but focuses one hero).
	FIRST,
	## Prefer the living ally with the lowest HP percentage.
	LOWEST_HP,
	## Prefer the living ally with the highest attack stat.
	STRONGEST,
	## Spread the damage over the party by rotating through the living allies.
	## This is the default so a whole group never focuses a single hero.
	ROTATE,
}

@export_group("Attacks")
## Index 0 is the basic attack (its cooldown is the attack interval).
## Remaining entries are abilities used on their own cooldowns.
@export var attacks: Array[AbilityDef] = []

@export_group("Break")
@export var break_max: float = 100.0
@export var break_duration: float = 4.0

@export_group("Boss")
@export var is_boss: bool = false
## HP fraction (0-1) at which the boss changes phase exactly once.
@export var phase_change_threshold: float = 0.5
## Ability used for the phase change (self buff).
@export var phase_change_ability: AbilityDef = null
## Additional attacks unlocked by the phase change.
@export var phase_two_attacks: Array[AbilityDef] = []

@export_group("AI")
@export var target_preference: TargetPreference = TargetPreference.ROTATE
## Extra delay (seconds) before the first attack so waves do not all fire at once.
@export var attack_start_delay: float = 0.6
