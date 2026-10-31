class_name Progression
extends RefCounted
## Level curve and stat growth for party members.
##
## xp needed to go from `level` to `level + 1`:
##   xp_base + xp_per_level * (level - 1)
## Every level adds the growth values stored on the character definition to its
## maximum HP, attack, defense, magic and magic defense.

## XP required to advance from `level` to `level + 1`.
static func xp_to_next(level: int, balance: BalanceConfig) -> int:
	var l: int = maxi(level, 1)
	return balance.xp_base + balance.xp_per_level * (l - 1)


## Total XP required to reach `level` from level 1.
static func xp_total_for_level(level: int, balance: BalanceConfig) -> int:
	var total: int = 0
	for l in range(1, maxi(level, 1)):
		total += xp_to_next(l, balance)
	return total


## Adds experience and returns the number of levels gained.
static func grant_xp(current_level: int, current_xp: int, amount: int, balance: BalanceConfig) -> Dictionary:
	var level: int = maxi(current_level, 1)
	var xp: int = maxi(current_xp, 0) + maxi(amount, 0)
	var levels_gained: int = 0
	while xp >= xp_to_next(level, balance):
		xp -= xp_to_next(level, balance)
		level += 1
		levels_gained += 1
	return {"level": level, "xp": xp, "levels_gained": levels_gained}


## Progress towards the next level as a 0..1 value.
static func level_progress(level: int, xp: int, balance: BalanceConfig) -> float:
	var needed: float = float(xp_to_next(level, balance))
	if needed <= 0.0:
		return 0.0
	return clampf(float(xp) / needed, 0.0, 1.0)
