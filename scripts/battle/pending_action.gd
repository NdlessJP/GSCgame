class_name PendingAction
extends RefCounted
## A telegraphed action that is still winding up.
##
## Enemy windups (for example the boss' party wide Cataclysm) are represented
## by pending actions.  They are cleared when a wave ends so no damage can
## leak into the next wave.

var caster: UnitState = null
var ability: AbilityDef = null
var target: UnitState = null
var remaining: float = 0.0
var total: float = 0.0
var kind: StringName = &"enemy"


func _init(p_caster: UnitState = null, p_ability: AbilityDef = null,
		p_target: UnitState = null, p_kind: StringName = &"enemy") -> void:
	caster = p_caster
	ability = p_ability
	target = p_target
	kind = p_kind
	total = p_ability.windup if p_ability != null else 0.0
	remaining = total


func progress() -> float:
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - remaining / total, 0.0, 1.0)


func is_ready() -> bool:
	return remaining <= 0.0
