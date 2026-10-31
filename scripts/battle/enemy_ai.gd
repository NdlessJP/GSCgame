class_name EnemyAI
extends RefCounted
## Enemy behaviour: target selection and ability choice.
##
## The AI only *decides*; the battle controller executes.  Keeping the decision
## separate makes the behaviour easy to test and to tune.

## Picks the ally an enemy should attack.
static func pick_target(unit: UnitState, candidates: Array) -> UnitState:
	var living: Array = []
	for other: UnitState in candidates:
		if other.is_targetable():
			living.append(other)
	if living.is_empty():
		return null
	var preference: int = EnemyDef.TargetPreference.FIRST
	if unit.def is EnemyDef:
		preference = (unit.def as EnemyDef).target_preference
	match preference:
		EnemyDef.TargetPreference.LOWEST_HP:
			var lowest: UnitState = living[0]
			for other: UnitState in living:
				if other.hp / maxf(1.0, other.max_hp()) < lowest.hp / maxf(1.0, lowest.max_hp()):
					lowest = other
			return lowest
		EnemyDef.TargetPreference.STRONGEST:
			var strongest: UnitState = living[0]
			for other: UnitState in living:
				if other.attack_stat() > strongest.attack_stat():
					strongest = other
			return strongest
		EnemyDef.TargetPreference.ROTATE:
			# Spread the damage over the party instead of focusing one hero.
			var index: int = unit.target_index % living.size()
			unit.target_index += 1
			return living[index]
	return living[0]


## Returns the ability the enemy wants to use right now, or null.
##
## Only abilities whose cooldown is ready are considered.  Boss abilities that
## hit the whole party are preferred so the player has to react to them.
static func choose_ability(unit: UnitState, candidates: Array, is_boss: bool) -> AbilityDef:
	if not (unit.def is EnemyDef):
		return null
	var def: EnemyDef = unit.def
	var pool: Array[AbilityDef] = []
	for ability: AbilityDef in def.attacks:
		if ability.kind == AbilityDef.Kind.BASIC:
			continue
		pool.append(ability)
	if unit.phase_two:
		for ability: AbilityDef in def.phase_two_attacks:
			pool.append(ability)
	for ability: AbilityDef in pool:
		if unit.is_cooldown_ready(ability.id) and not unit.status_blocks_actions():
			if is_boss and ability.target_mode == Targeting.Mode.ALL_ENEMIES:
				return ability
	for ability: AbilityDef in pool:
		if unit.is_cooldown_ready(ability.id) and not unit.status_blocks_actions():
			return ability
	return null
