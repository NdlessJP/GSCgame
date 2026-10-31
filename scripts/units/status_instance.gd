class_name StatusInstance
extends RefCounted
## Runtime instance of a StatusDef.
##
## Holds the mutable part of a status: remaining time, stack count, the
## remaining shield pool and who applied it.  The shared StatusDef resource is
## only ever read.

var def: StatusDef = null
var source: UnitState = null
var stacks: int = 1
var remaining: float = 0.0
var shield_pool: float = 0.0
var tick_timer: float = 0.0
## Set once the status has been removed so late references can detect it.
var expired: bool = false


func _init(status_def: StatusDef = null, status_source: UnitState = null) -> void:
	def = status_def
	source = status_source
	if def != null:
		remaining = def.duration
		tick_timer = def.periodic_interval
		shield_pool = def.shield_flat


func id() -> StringName:
	return def.id if def != null else &""


func display_name() -> String:
	return def.display_name if def != null else "Status"


func has_shield() -> bool:
	return shield_pool > 0.0


func refresh(duration: float = -1.0) -> void:
	if duration >= 0.0:
		remaining = duration
	else:
		remaining = def.duration if def != null else remaining


func add_stack(count: int = 1) -> void:
	stacks = mini(stacks + count, maxi(def.max_stacks, 1) if def != null else stacks + count)


## Advances timers.  Returns a list of event dictionaries:
##   { "type": "periodic_damage", "amount": float, "element": int }
##   { "type": "arts", "amount": float }
##   { "type": "expired" }
func tick(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if def == null:
		expired = true
		return events

	remaining -= delta

	if def.arts_per_tick > 0.0:
		tick_timer -= delta
		while tick_timer <= 0.0:
			tick_timer += maxf(def.arts_tick_interval, 0.05)
			events.append({"type": "arts", "amount": def.arts_per_tick * stacks})

	if def.periodic_damage > 0.0 or def.periodic_heal > 0.0:
		tick_timer -= delta
		while tick_timer <= 0.0:
			tick_timer += maxf(def.periodic_interval, 0.1)
			if def.periodic_damage > 0.0:
				events.append({
					"type": "periodic_damage",
					"amount": def.periodic_damage * stacks,
					"element": def.periodic_element,
					"magical": def.periodic_is_magical,
				})
			if def.periodic_heal > 0.0:
				events.append({
					"type": "periodic_heal",
					"amount": def.periodic_heal * stacks,
				})

	if remaining <= 0.0:
		remaining = 0.0
		expired = true
		events.append({"type": "expired"})
	return events
