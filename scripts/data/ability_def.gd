class_name AbilityDef
extends Resource
## A reusable ability: basic attack, Skill, Arts, True Arts or an equipment active.
##
## Abilities are pure data.  Execution lives in scripts/battle/ability_executor.gd.

enum Kind {
	BASIC,     ## Automatic attack performed on a timer.
	SKILL,     ## Manually activated, has a cooldown.
	ARTS,      ## Manually activated, costs the Arts cost.
	TRUE_ARTS, ## Manually activated, costs the True Arts cost.
}

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var kind: Kind = Kind.SKILL

@export_group("Cost & Timing")
## Cooldown in seconds.  Basic attacks use this as their attack interval.
@export var cooldown: float = 6.0
## Arts gauge cost.  Arts abilities use 100, True Arts use 200.
@export var arts_cost: float = 0.0
## Arts granted to the caster when the ability resolves.
@export var arts_generated: float = 0.0
## Telegraph time before the ability resolves.  Zero means instant.
@export var windup: float = 0.0

@export_group("Targeting")
@export var target_mode: Targeting.Mode = Targeting.Mode.SINGLE_TARGET

@export_group("Effects")
@export var effects: Array[EffectDef] = []

@export_group("Presentation")
@export var color: Color = Color(0.6, 0.82, 1.0)
## Spawns a simple travelling projectile on the battlefield.
@export var show_projectile: bool = false
@export var projectile_speed: float = 460.0
## Scale of the impact burst drawn on the battlefield.
@export var impact_scale: float = 1.0


func is_arts() -> bool:
	return kind == Kind.ARTS or kind == Kind.TRUE_ARTS


func kind_label() -> String:
	match kind:
		Kind.BASIC: return "Basic Attack"
		Kind.SKILL: return "Skill"
		Kind.ARTS: return "Arts"
		Kind.TRUE_ARTS: return "True Arts"
	return "Ability"
