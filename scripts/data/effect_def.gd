class_name EffectDef
extends Resource
## A single reusable effect inside an AbilityDef.
##
## Effects are the shared vocabulary of the combat system: every character,
## enemy and piece of equipment is built from the same small set of effects,
## which is what makes distinct characters possible without writing bespoke
## combat code for each one.

enum EffectType {
	DAMAGE,      ## Physical, magical or true damage.
	HEAL,        ## Restores HP to the target.
	SHIELD,      ## Grants an absorb pool that expires with its status.
	STATUS,      ## Applies a reusable status effect (buff, debuff, poison, stun).
	ARTS_GAIN,   ## Adds arts gauge to the target.
	BREAK_DAMAGE ## Reduces the target's break meter without dealing HP damage.
}

enum DamageKind { PHYSICAL, MAGICAL, TRUE }

@export_group("Identity")
@export var effect_type: EffectType = EffectType.DAMAGE
## Optional per-effect targeting override; -1 means "use the ability default".
@export var target_mode_override: int = -1
## 0.0 - 1.0 chance for the effect to apply at all.
@export var chance: float = 1.0

@export_group("Damage")
## Percentage of the relevant attack stat (attack for physical, magic for magical).
@export var power: float = 100.0
@export var flat_amount: float = 0.0
@export var damage_kind: DamageKind = DamageKind.PHYSICAL
## Elements.Element value, or -1 to inherit the caster's element.
@export var element_override: int = -1
@export var can_crit: bool = true
@export var ignore_defense: bool = false
## Fraction of damage dealt returned to the caster as HP.
@export var lifesteal_percent: float = 0.0

@export_group("Healing")
## Percentage of the caster's magic stat restored.
@export var heal_power: float = 0.0
@export var heal_flat: float = 0.0
## True healing ignores the 30% effectiveness penalty that heals apply to
## broken targets.
@export var full_heal_on_broken: bool = false

@export_group("Shield")
@export var shield_flat: float = 0.0
@export var shield_percent_of_max_hp: float = 0.0
@export var shield_duration: float = 8.0
## Fraction of incoming damage the shield soaks up (1.0 = absorbs everything
## until the pool is empty).
@export var shield_absorb_ratio: float = 1.0

@export_group("Arts / Break")
@export var arts_amount: float = 0.0
@export var break_amount: float = 0.0

@export_group("Status")
## The status applied by EffectType.STATUS.
@export var status: StatusDef = null
## Overrides the status duration when greater than zero.
@export var duration_override: float = 0.0


func is_offensive() -> bool:
	return effect_type == EffectType.DAMAGE or effect_type == EffectType.BREAK_DAMAGE


func resolved_element(caster_element: int) -> int:
	return caster_element if element_override < 0 else element_override
