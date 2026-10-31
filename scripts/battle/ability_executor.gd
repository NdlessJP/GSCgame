class_name AbilityExecutor
extends RefCounted
## Validation, cost handling, target resolution and execution of abilities.
##
## The executor is deliberately free of any dependency on the battle
## controller: it works on UnitState objects and returns event dictionaries.
## That keeps it fully unit testable without a scene tree.

## True when the caster may use the ability right now.
static func can_use(caster: UnitState, ability: AbilityDef, balance: BalanceConfig) -> bool:
	if caster == null or ability == null:
		return false
	if caster.is_dead:
		return false
	if caster.status_blocks_actions():
		return false
	if caster.is_broken:
		return false
	if not caster.is_cooldown_ready(ability.id):
		return false
	if ability.arts_cost > 0.0 and caster.arts < ability.arts_cost:
		return false
	return true


## Why an ability cannot be used.  Used by the UI to explain a disabled
## button.  Returns an empty string when the ability can be used.
static func blocked_reason(caster: UnitState, ability: AbilityDef, balance: BalanceConfig) -> String:
	if caster == null or ability == null:
		return "Unavailable"
	if caster.is_dead:
		return "Defeated"
	if caster.status_blocks_actions():
		return "Stunned"
	if caster.is_broken:
		return "Broken"
	if not caster.is_cooldown_ready(ability.id):
		return "Cooling down"
	if ability.arts_cost > 0.0 and caster.arts < ability.arts_cost:
		return "Not enough arts"
	return ""


## Pays the cost of an ability.  The arts gauge is spent *first* and the
## whole activation is refused when it cannot be paid, so a half executed
## ability is impossible.
static func pay(caster: UnitState, ability: AbilityDef) -> bool:
	if ability.arts_cost > 0.0 and not caster.spend_arts(ability.arts_cost):
		return false
	# Basic attacks run on their own attack timer, so they get no cooldown.
	if ability.cooldown > 0.0 and ability.kind != AbilityDef.Kind.BASIC:
		caster.start_cooldown(ability.id, ability.cooldown)
	return true


## Resolves the targets of an ability.
##
## `preferred` is the party's chosen enemy (allies), `chosen` is the target an
## enemy AI picked.
static func resolve_targets(mode: int, caster: UnitState, allies: Array, enemies: Array,
		preferred: UnitState = null, chosen: UnitState = null) -> Array:
	var result: Array = []
	var own_side: Array = allies if caster.is_ally else enemies
	var other_side: Array = enemies if caster.is_ally else allies
	match mode:
		Targeting.Mode.SELF:
			if not caster.is_dead:
				result.append(caster)
		Targeting.Mode.SINGLE_TARGET:
			var pick: UnitState = null
			if caster.is_ally:
				if preferred != null and preferred.is_targetable() and other_side.has(preferred):
					pick = preferred
				elif chosen != null and chosen.is_targetable():
					pick = chosen
			else:
				if chosen != null and chosen.is_targetable():
					pick = chosen
				elif preferred != null and preferred.is_targetable() and other_side.has(preferred):
					pick = preferred
			if pick == null:
				for unit: UnitState in other_side:
					if unit.is_targetable():
						pick = unit
						break
			if pick != null:
				result.append(pick)
		Targeting.Mode.ALL_ENEMIES:
			for unit: UnitState in other_side:
				if unit.is_targetable():
					result.append(unit)
		Targeting.Mode.SINGLE_ALLY:
			var ally_pick: UnitState = null
			if chosen != null and chosen.is_targetable() and own_side.has(chosen):
				ally_pick = chosen
			if ally_pick == null:
				for unit: UnitState in own_side:
					if unit.is_targetable():
						ally_pick = unit
						break
			if ally_pick != null:
				result.append(ally_pick)
		Targeting.Mode.LOWEST_HP_ALLY:
			var lowest: UnitState = null
			var lowest_ratio: float = 2.0
			for unit: UnitState in own_side:
				if not unit.is_targetable():
					continue
				var ratio: float = unit.hp / maxf(1.0, unit.max_hp())
				if ratio < lowest_ratio:
					lowest_ratio = ratio
					lowest = unit
			if lowest != null:
				result.append(lowest)
		Targeting.Mode.ALL_ALLIES:
			for unit: UnitState in own_side:
				if unit.is_targetable():
					result.append(unit)
	return result


## Executes an ability on a set of targets.  Costs must already be paid.
static func execute(ability: AbilityDef, caster: UnitState, targets: Array,
		balance: BalanceConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if ability == null or caster == null:
		return events
	for effect: EffectDef in ability.effects:
		var mode: int = effect.target_mode_override if effect.target_mode_override >= 0 else ability.target_mode
		var effect_targets: Array = targets
		if effect.target_mode_override >= 0:
			effect_targets = _targets_for_effect(mode, caster, targets)
		for target: UnitState in effect_targets:
			if target == null or target.is_dead:
				continue
			var event: Dictionary = EffectApplier.apply(effect, caster, target, balance)
			if not event.is_empty():
				event["ability_id"] = ability.id
				event["ability_name"] = ability.display_name
				events.append(event)
	return events


static func _targets_for_effect(mode: int, caster: UnitState, fallback: Array) -> Array:
	match mode:
		Targeting.Mode.SELF:
			return [caster]
		Targeting.Mode.ALL_ALLIES, Targeting.Mode.ALL_ENEMIES:
			return fallback
	return fallback
