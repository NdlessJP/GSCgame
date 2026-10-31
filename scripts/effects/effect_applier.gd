class_name EffectApplier
extends RefCounted
## Applies a single EffectDef to a target.
##
## This is the shared vocabulary of the whole game: damage, healing, shields,
## status effects, arts generation and break damage all funnel through here, so
## a new character or item is only a matter of picking effects.
##
## Every call returns an event dictionary describing what happened.  The battle
## controller turns those events into signals for the UI.

const EVENT_DAMAGE: StringName = &"damage"
const EVENT_HEAL: StringName = &"heal"
const EVENT_SHIELD: StringName = &"shield"
const EVENT_STATUS: StringName = &"status"
const EVENT_ARTS: StringName = &"arts"
const EVENT_BREAK: StringName = &"break"

static var _shield_template: StatusDef = null


static func shield_template() -> StatusDef:
	if _shield_template == null:
		_shield_template = StatusDef.new()
		_shield_template.id = &"status_ward"
		_shield_template.display_name = "Ward"
		_shield_template.description = "Absorbs incoming damage."
		_shield_template.duration = 8.0
		_shield_template.stack_policy = StatusDef.StackPolicy.REFRESH
		_shield_template.color = Color(0.6, 0.9, 1.0)
		_shield_template.icon = "S"
	return _shield_template


## Applies an effect.  Returns an empty dictionary when the effect did
## nothing (for example when the chance roll failed).
static func apply(effect: EffectDef, caster: UnitState, target: UnitState, balance: BalanceConfig) -> Dictionary:
	if effect == null or target == null or target.is_dead:
		return {}
	if effect.chance < 1.0 and randf() > effect.chance:
		return {}
	match effect.effect_type:
		EffectDef.EffectType.DAMAGE:
			return _apply_damage(effect, caster, target, balance)
		EffectDef.EffectType.HEAL:
			return _apply_heal(effect, caster, target)
		EffectDef.EffectType.SHIELD:
			return _apply_shield(effect, caster, target)
		EffectDef.EffectType.STATUS:
			return _apply_status(effect, caster, target)
		EffectDef.EffectType.ARTS_GAIN:
			return _apply_arts(effect, caster, target, balance)
		EffectDef.EffectType.BREAK_DAMAGE:
			return _apply_break(effect, caster, target)
	return {}


static func _apply_damage(effect: EffectDef, caster: UnitState, target: UnitState, balance: BalanceConfig) -> Dictionary:
	var stat: float = caster.attack_stat()
	if effect.damage_kind == EffectDef.DamageKind.MAGICAL:
		stat = caster.magic_stat()
	var base: float = stat * effect.power / 100.0 + effect.flat_amount
	var params: DamageCalculator.DamageParams = DamageCalculator.DamageParams.new()
	params.source = caster
	params.target = target
	params.base_amount = base
	params.damage_kind = effect.damage_kind
	params.element = effect.resolved_element(caster.element())
	params.can_crit = effect.can_crit
	params.ignore_defense = effect.ignore_defense
	params.lifesteal_percent = effect.lifesteal_percent
	var result: DamageCalculator.DamageResult = DamageCalculator.apply(params, balance)
	return {
		"type": EVENT_DAMAGE,
		"source": caster,
		"target": target,
		"amount": result.amount,
		"absorbed": result.absorbed,
		"hp_lost": result.hp_lost,
		"is_crit": result.is_crit,
		"element": result.element,
		"element_multiplier": result.element_multiplier,
		"lifesteal": result.lifesteal,
	}


static func _apply_heal(effect: EffectDef, caster: UnitState, target: UnitState) -> Dictionary:
	var amount: float = effect.heal_flat + caster.magic_stat() * effect.heal_power / 100.0
	var healed: float = target.heal(amount, effect.full_heal_on_broken)
	return {
		"type": EVENT_HEAL,
		"source": caster,
		"target": target,
		"amount": healed,
	}


static func _apply_shield(effect: EffectDef, caster: UnitState, target: UnitState) -> Dictionary:
	var amount: float = effect.shield_flat + target.max_hp() * effect.shield_percent_of_max_hp
	if amount <= 0.0:
		return {}
	var instance: StatusInstance = target.add_status(shield_template(), caster, effect.shield_duration)
	instance.shield_pool = amount
	return {
		"type": EVENT_SHIELD,
		"source": caster,
		"target": target,
		"amount": amount,
		"status_id": instance.id(),
	}


static func _apply_status(effect: EffectDef, caster: UnitState, target: UnitState) -> Dictionary:
	if effect.status == null:
		return {}
	var duration: float = effect.duration_override if effect.duration_override > 0.0 else -1.0
	var instance: StatusInstance = target.add_status(effect.status, caster, duration)
	return {
		"type": EVENT_STATUS,
		"source": caster,
		"target": target,
		"status_id": instance.id(),
		"status_name": instance.display_name(),
		"duration": instance.remaining,
		"stacks": instance.stacks,
	}


static func _apply_arts(effect: EffectDef, caster: UnitState, target: UnitState, balance: BalanceConfig) -> Dictionary:
	if effect.arts_amount >= 0.0:
		var gained: float = target.gain_arts(effect.arts_amount, balance)
		return {
			"type": EVENT_ARTS,
			"source": caster,
			"target": target,
			"amount": gained,
			"drained": false,
		}
	# Negative arts drain the target and hand half of it to the caster.
	var drained: float = target.drain_arts(-effect.arts_amount)
	var stolen: float = caster.gain_arts(drained * 0.5, balance)
	return {
		"type": EVENT_ARTS,
		"source": caster,
		"target": target,
		"amount": drained,
		"stolen": stolen,
		"drained": true,
	}


static func _apply_break(effect: EffectDef, caster: UnitState, target: UnitState) -> Dictionary:
	var broke: bool = target.add_break(effect.break_amount)
	return {
		"type": EVENT_BREAK,
		"source": caster,
		"target": target,
		"amount": effect.break_amount,
		"broke": broke,
	}
