class_name DamageCalculator
extends RefCounted
## Centralised damage maths.  Every formula in the game goes through here.
##
## Formula (all multipliers configurable in BalanceConfig):
##
##   base      = flat_amount + stat * power / 100
##               stat = attack for physical damage, magic for magical damage
##   mitigated = base * (defense_constant / (defense_constant + target_defense))
##               (physical uses defense, magical uses magic defense,
##                TRUE damage ignores mitigation entirely)
##   mitigated *= element_multiplier(attacker_element, defender_element)
##   mitigated *= critical_multiplier      (only on a critical hit)
##   mitigated *= broken_damage_multiplier (only when the target is Broken)
##   mitigated *= random spread            (damage_variance, 0 by default)
##   final     = max(minimum_damage, mitigated)

class DamageParams:
	var source: UnitState = null
	var target: UnitState = null
	var base_amount: float = 0.0
	var damage_kind: int = EffectDef.DamageKind.PHYSICAL
	var element: int = Elements.Element.FIRE
	var can_crit: bool = true
	var ignore_defense: bool = false
	var lifesteal_percent: float = 0.0
	var bonus_multiplier: float = 1.0


class DamageResult:
	var amount: float = 0.0
	var is_crit: bool = false
	var element: int = Elements.Element.FIRE
	var element_multiplier: float = 1.0
	var absorbed: float = 0.0
	var hp_lost: float = 0.0
	var lifesteal: float = 0.0

	func to_dict() -> Dictionary:
		return {
			"amount": amount,
			"is_crit": is_crit,
			"element": element,
			"element_multiplier": element_multiplier,
			"absorbed": absorbed,
			"hp_lost": hp_lost,
			"lifesteal": lifesteal,
		}


## Computes the final damage without applying it.
static func compute(params: DamageParams, balance: BalanceConfig) -> DamageResult:
	var result: DamageResult = DamageResult.new()
	result.element = params.element
	var amount: float = params.base_amount * params.bonus_multiplier

	if not params.ignore_defense:
		match params.damage_kind:
			EffectDef.DamageKind.PHYSICAL:
				var defense: float = params.target.defense_stat() if params.target != null else 0.0
				amount *= balance.defense_constant / maxf(1.0, balance.defense_constant + defense)
			EffectDef.DamageKind.MAGICAL:
				var magic_defense: float = params.target.magic_defense_stat() if params.target != null else 0.0
				amount *= balance.defense_constant / maxf(1.0, balance.defense_constant + magic_defense)
			EffectDef.DamageKind.TRUE:
				pass

	result.element_multiplier = Elements.multiplier(
		params.element, params.target.element() if params.target != null else params.element,
		balance.element_advantage_multiplier, balance.element_neutral_multiplier)
	amount *= result.element_multiplier

	if params.can_crit and balance.critical_rate > 0.0 and randf() < balance.critical_rate:
		result.is_crit = true
		amount *= balance.critical_multiplier

	if params.target != null and params.target.is_broken:
		amount *= balance.broken_damage_multiplier

	if params.target != null:
		var reduction: float = params.target.damage_reduction()
		if reduction > 0.0:
			amount *= maxf(0.0, 1.0 - reduction)

	if balance.damage_variance > 0.0:
		amount *= randf_range(1.0 - balance.damage_variance, 1.0 + balance.damage_variance)

	result.amount = maxf(balance.minimum_damage, amount)
	return result


## Computes and applies damage to the target, healing the source on lifesteal.
static func apply(params: DamageParams, balance: BalanceConfig) -> DamageResult:
	var result: DamageResult = compute(params, balance)
	if params.target == null:
		return result
	var applied: Dictionary = params.target.take_damage(result.amount)
	result.absorbed = applied.get("absorbed", 0.0)
	result.hp_lost = applied.get("hp_lost", 0.0)
	result.amount = result.hp_lost
	if params.lifesteal_percent > 0.0 and params.source != null and not params.source.is_dead:
		result.lifesteal = params.source.heal(result.amount * params.lifesteal_percent)
	return result
