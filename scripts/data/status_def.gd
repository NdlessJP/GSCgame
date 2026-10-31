class_name StatusDef
extends Resource
## Reusable status effect definition (buff, debuff, damage-over-time, stun, shield).
##
## A StatusDef is static data.  Mutable runtime data (remaining time, stacks,
## remaining shield pool) lives in a StatusInstance so that shared resources
## are never modified during a battle.

enum StackPolicy {
	REFRESH, ## Re-applying refreshes the duration and keeps the stack count.
	STACK,   ## Re-applying adds a stack (capped by max_stacks) and refreshes time.
	REPLACE, ## Re-applying replaces the existing instance entirely.
}

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var color: Color = Color(0.8, 0.8, 0.8)
@export var icon: String = "*"

@export_group("Timing")
@export var duration: float = 5.0
@export var stack_policy: StackPolicy = StackPolicy.REFRESH
@export var max_stacks: int = 1

@export_group("Stat Modifiers")
## Percentage modifiers, summed across all active statuses.
@export var attack_percent: float = 0.0
@export var defense_percent: float = 0.0
@export var magic_percent: float = 0.0
@export var magic_defense_percent: float = 0.0
## Flat modifiers, summed across all active statuses.
@export var attack_flat: float = 0.0
@export var defense_flat: float = 0.0
@export var magic_flat: float = 0.0
@export var magic_defense_flat: float = 0.0

@export_group("Behaviour")
## While true the unit cannot perform any action (stun, freeze, ...).
@export var blocks_actions: bool = false
## Fraction of incoming damage ignored (0.25 == 25% damage reduction).
@export var damage_reduction: float = 0.0
## Arts granted to the holder every tick interval.
@export var arts_per_tick: float = 0.0
@export var arts_tick_interval: float = 1.0

@export_group("Periodic Damage")
@export var periodic_damage: float = 0.0
@export var periodic_interval: float = 1.0
@export var periodic_is_magical: bool = false
## Elements.Element value, or -1 to use the source's element.
@export var periodic_element: int = -1
## HP restored to the holder on every periodic tick.
@export var periodic_heal: float = 0.0

@export_group("Shield")
@export var shield_flat: float = 0.0
@export var shield_percent_of_max_hp: float = 0.0
@export var shield_absorb_ratio: float = 1.0
