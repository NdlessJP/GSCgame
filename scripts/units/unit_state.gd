class_name UnitState
extends RefCounted
## Mutable runtime state for one combat unit (ally character or enemy).
##
## Everything that changes during a battle lives here; the static UnitDef
## resource is never modified.  Stats are *derived* from the definition, the
## level, the equipped items and the currently active statuses, so an expired
## buff can never leave a permanent stat change behind.

var def: UnitDef = null
var level: int = 1
var hp: float = 0.0
var arts: float = 0.0
var is_dead: bool = false
## Set once the death signal has been emitted, so it is never emitted twice.
var death_reported: bool = false
var is_ally: bool = true
var statuses: Array[StatusInstance] = []
## Ability id -> remaining cooldown in seconds.
var cooldowns: Dictionary = {}
## Equipped items as { "def": EquipmentDef, "instance_id": String }.
var equipment: Array[Dictionary] = []
## View node used for presentation only.
var view: Node2D = null

# Break meter (enemies only, but kept on the shared class for simplicity).
var break_max: float = 100.0
var break_meter: float = 100.0
var is_broken: bool = false
var break_timer: float = 0.0
var phase_two: bool = false

# Attack timer for automatic basic attacks.
var attack_timer: float = 0.0
## Counter used by enemies that rotate their target over the party.
var target_index: int = 0
# Display name of the currently preferred target, kept for UI.
var target_hint: StringName = &""


func _init(unit_def: UnitDef = null, unit_level: int = 1) -> void:
	def = unit_def
	level = maxi(unit_level, 1)
	if def != null:
		hp = def.max_hp_at(level)
		break_max = (def as EnemyDef).break_max if def is EnemyDef else 100.0
		break_meter = break_max


# --------------------------------------------------------------------------
# Identity helpers
# --------------------------------------------------------------------------

func id() -> StringName:
	return def.id if def != null else &""


func display_name() -> String:
	return def.display_name if def != null else "Unknown"


func element() -> int:
	return def.element if def != null else Elements.Element.FIRE


func is_enemy() -> bool:
	return not is_ally


func is_targetable() -> bool:
	return not is_dead


# --------------------------------------------------------------------------
# Derived stats
# --------------------------------------------------------------------------

func _equip_sum(field: StringName) -> float:
	var total: float = 0.0
	for entry: Dictionary in equipment:
		var item: EquipmentDef = entry.get("def")
		if item == null:
			continue
		total += float(item.get(field))
	return total


func _status_percent(field: StringName) -> float:
	var total: float = 0.0
	for inst: StatusInstance in statuses:
		if inst.def == null:
			continue
		total += float(inst.def.get(field)) * float(inst.stacks)
	return total


func _status_flat(field: StringName) -> float:
	var total: float = 0.0
	for inst: StatusInstance in statuses:
		if inst.def == null:
			continue
		total += float(inst.def.get(field)) * float(inst.stacks)
	return total


func max_hp() -> float:
	var base: float = def.max_hp_at(level) if def != null else 1.0
	return maxf(1.0, base + _equip_sum(&"max_hp_flat"))


## Recomputes the maximum HP after equipment changed and keeps the current HP
## inside the new bounds.
func refresh_max_hp() -> void:
	var ceiling: float = max_hp()
	if hp <= 0.0:
		hp = ceiling
	else:
		hp = minf(hp, ceiling)


func attack_stat() -> float:
	var base: float = def.attack_at(level) if def != null else 0.0
	var flat: float = base + _equip_sum(&"attack_flat") + _status_flat(&"attack_flat")
	var percent: float = _equip_sum(&"attack_percent") + _status_percent(&"attack_percent")
	return maxf(1.0, flat * (1.0 + percent))


func defense_stat() -> float:
	var base: float = def.defense_at(level) if def != null else 0.0
	var flat: float = base + _equip_sum(&"defense_flat") + _status_flat(&"defense_flat")
	var percent: float = _equip_sum(&"defense_percent") + _status_percent(&"defense_percent")
	return maxf(0.0, flat * (1.0 + percent))


func magic_stat() -> float:
	var base: float = def.magic_at(level) if def != null else 0.0
	var flat: float = base + _status_flat(&"magic_flat")
	var percent: float = _equip_sum(&"magic_percent") + _status_percent(&"magic_percent")
	return maxf(1.0, flat * (1.0 + percent))


func magic_defense_stat() -> float:
	var base: float = def.magic_defense_at(level) if def != null else 0.0
	var flat: float = base + _status_flat(&"magic_defense_flat")
	var percent: float = _equip_sum(&"magic_defense_percent") + _status_percent(&"magic_defense_percent")
	return maxf(0.0, flat * (1.0 + percent))


func arts_generated_per_attack(balance: BalanceConfig) -> float:
	var total: float = balance.arts_per_basic_attack
	for entry: Dictionary in equipment:
		var item: EquipmentDef = entry.get("def")
		if item != null:
			total += item.arts_per_attack
	return total


# --------------------------------------------------------------------------
# Vitals
# --------------------------------------------------------------------------

func take_damage(amount: float) -> Dictionary:
	## Applies damage to this unit.
	## Shields absorb damage *before* HP is lost.
	## Returns { "absorbed": float, "hp_lost": float }.
	if is_dead or amount <= 0.0:
		return {"absorbed": 0.0, "hp_lost": 0.0}
	var remaining: float = amount
	var absorbed: float = 0.0
	for inst: StatusInstance in statuses:
		if remaining <= 0.0:
			break
		if inst.shield_pool <= 0.0:
			continue
		var take: float = minf(remaining, inst.shield_pool)
		inst.shield_pool -= take
		remaining -= take
		absorbed += take
		if inst.shield_pool < 0.0:
			inst.shield_pool = 0.0
	var hp_lost: float = minf(remaining, hp)
	hp -= hp_lost
	if hp <= 0.0:
		hp = 0.0
		is_dead = true
	return {"absorbed": absorbed, "hp_lost": hp_lost}


func heal(amount: float, full_on_broken: bool = false) -> float:
	## Heals this unit.  Broken units only receive 30% of healing unless the
	## effect explicitly ignores the penalty.  Returns the amount healed.
	if is_dead or amount <= 0.0:
		return 0.0
	var effective: float = amount
	if is_broken and not full_on_broken:
		effective *= 0.3
	var ceiling: float = max_hp()
	var before: float = hp
	hp = minf(ceiling, hp + effective)
	return hp - before


func gain_arts(amount: float, balance: BalanceConfig) -> float:
	if amount <= 0.0:
		return 0.0
	var before: float = arts
	arts = clampf(arts + amount, 0.0, balance.arts_max)
	return arts - before


func spend_arts(amount: float) -> bool:
	## Spends arts.  Returns false (and spends nothing) when the cost cannot
	## be paid, so a partially applied activation is impossible.
	if amount <= 0.0:
		return true
	if arts < amount:
		return false
	arts -= amount
	return true


## Removes arts from the unit (enemy drain effects).  Returns the amount taken.
func drain_arts(amount: float) -> float:
	if amount <= 0.0 or is_dead:
		return 0.0
	var before: float = arts
	arts = maxf(0.0, arts - amount)
	return before - arts


## Fraction of incoming damage ignored thanks to active statuses.
func damage_reduction() -> float:
	var total: float = 0.0
	for inst: StatusInstance in statuses:
		if inst.def != null:
			total += inst.def.damage_reduction * float(inst.stacks)
	return clampf(total, 0.0, 0.75)


func arts_percent(balance: BalanceConfig) -> float:
	return clampf(arts / maxf(balance.arts_max, 1.0), 0.0, 1.0)


# --------------------------------------------------------------------------
# Statuses
# --------------------------------------------------------------------------

func has_status(status_id: StringName) -> bool:
	for inst: StatusInstance in statuses:
		if inst.def != null and inst.def.id == status_id:
			return true
	return false


func status_instances(status_id: StringName) -> Array[StatusInstance]:
	var result: Array[StatusInstance] = []
	for inst: StatusInstance in statuses:
		if inst.def != null and inst.def.id == status_id:
			result.append(inst)
	return result


func status_blocks_actions() -> bool:
	for inst: StatusInstance in statuses:
		if inst.def != null and inst.def.blocks_actions:
			return true
	return false


func add_status(status_def: StatusDef, status_source: UnitState = null, duration: float = -1.0) -> StatusInstance:
	## Applies a status, honouring the stack policy of the definition.
	if status_def == null:
		return null
	var existing: StatusInstance = null
	for inst: StatusInstance in statuses:
		if inst.def != null and inst.def.id == status_def.id:
			existing = inst
			break
	if existing != null:
		match status_def.stack_policy:
			StatusDef.StackPolicy.REPLACE:
				existing.def = status_def
				existing.source = status_source
				existing.stacks = 1
				existing.remaining = duration if duration >= 0.0 else status_def.duration
				existing.expired = false
				existing.tick_timer = status_def.periodic_interval
				existing.shield_pool = status_def.shield_flat
				return existing
			StatusDef.StackPolicy.STACK:
				existing.add_stack(1)
				existing.refresh(duration)
				existing.source = status_source
				return existing
			StatusDef.StackPolicy.REFRESH:
				existing.refresh(duration)
				existing.source = status_source
				return existing
	var instance: StatusInstance = StatusInstance.new(status_def, status_source)
	if duration >= 0.0:
		instance.remaining = duration
	statuses.append(instance)
	return instance


func remove_status(status_id: StringName) -> void:
	for i in range(statuses.size() - 1, -1, -1):
		if statuses[i].def != null and statuses[i].def.id == status_id:
			statuses[i].expired = true
			statuses.remove_at(i)


func clear_statuses() -> void:
	for inst: StatusInstance in statuses:
		inst.expired = true
	statuses.clear()


# --------------------------------------------------------------------------
# Break
# --------------------------------------------------------------------------

func add_break(amount: float) -> bool:
	## Reduces the break meter.  Returns true when the unit just became Broken.
	if amount <= 0.0 or is_dead or is_broken:
		return false
	break_meter = maxf(0.0, break_meter - amount)
	if break_meter <= 0.0:
		is_broken = true
		break_timer = break_duration()
		return true
	return false


func break_duration() -> float:
	if def is EnemyDef:
		return (def as EnemyDef).break_duration
	return 4.0


func break_ratio() -> float:
	if break_max <= 0.0:
		return 0.0
	return clampf(1.0 - break_meter / break_max, 0.0, 1.0)


## Advances the broken state timer.  Returns true when the broken state ended,
## in which case the break meter is reset to full.
func tick_break(delta: float) -> bool:
	if not is_broken:
		return false
	break_timer -= delta
	if break_timer > 0.0:
		return false
	is_broken = false
	break_timer = 0.0
	break_meter = break_max
	return true


# --------------------------------------------------------------------------
# Cooldowns
# --------------------------------------------------------------------------

func start_cooldown(ability_id: StringName, seconds: float) -> void:
	if ability_id == &"":
		return
	cooldowns[ability_id] = maxf(0.0, seconds)


func cooldown_remaining(ability_id: StringName) -> float:
	return float(cooldowns.get(ability_id, 0.0))


func is_cooldown_ready(ability_id: StringName) -> bool:
	return cooldown_remaining(ability_id) <= 0.0


func tick_cooldowns(delta: float) -> void:
	for key: Variant in cooldowns.keys():
		var value: float = float(cooldowns[key]) - delta
		cooldowns[key] = maxf(0.0, value)


# --------------------------------------------------------------------------
# Ticking
# --------------------------------------------------------------------------

## Advances status timers.  Returns event dictionaries:
##   { "type": "periodic_damage" | "arts" | "expired", ... }
func tick_statuses(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in range(statuses.size() - 1, -1, -1):
		var inst: StatusInstance = statuses[i]
		for event: Dictionary in inst.tick(delta):
			event["status_id"] = inst.id()
			event["status_name"] = inst.display_name()
			events.append(event)
		if inst.expired:
			statuses.remove_at(i)
	return events
