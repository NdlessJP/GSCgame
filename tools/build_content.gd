extends SceneTree
## Content authoring tool.
##
## Run with:
##   godot --headless --path . --script res://tools/build_content.gd
##
## It generates every .tres definition in res://resources from the tables
## below.  The generated resources are the real source of truth for the game
## (they can be hand edited in the Godot editor afterwards); this tool exists
## so the initial content set is consistent and quick to regenerate.

const RES: String = "res://resources"

var _statuses: Dictionary = {}
var _abilities: Dictionary = {}


func _initialize() -> void:
	_make_directories()
	_build_statuses()
	_build_abilities()
	_build_characters()
	_build_enemies()
	_build_equipment()
	_build_quests()
	_build_balance()
	print("[build_content] finished. statuses=%d abilities=%d" % [_statuses.size(), _abilities.size()])
	quit()


# --------------------------------------------------------------------------
# Infrastructure
# --------------------------------------------------------------------------

func _make_directories() -> void:
	for sub: String in ["characters", "abilities", "equipment", "enemies", "quests", "statuses"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [RES, sub])


func _save(res: Resource, subdir: String, file_name: String) -> Resource:
	var path: String = "%s/%s/%s" % [RES, subdir, file_name]
	var error: int = ResourceSaver.save(res, path)
	if error != OK:
		push_error("Could not save %s (error %d)" % [path, error])
		return null
	var loaded: Resource = load(path)
	if loaded == null:
		push_error("Could not reload %s" % path)
	return loaded


# --------------------------------------------------------------------------
# Effect helpers
# --------------------------------------------------------------------------

func _damage(power: float, kind: int = EffectDef.DamageKind.PHYSICAL, element: int = -1,
		target_mode: int = -1, crit: bool = true, lifesteal: float = 0.0, flat: float = 0.0) -> EffectDef:
	var e: EffectDef = EffectDef.new()
	e.effect_type = EffectDef.EffectType.DAMAGE
	e.power = power
	e.flat_amount = flat
	e.damage_kind = kind
	e.element_override = element
	e.target_mode_override = target_mode
	e.can_crit = crit
	e.lifesteal_percent = lifesteal
	return e


func _heal(power: float, target_mode: int = -1, flat: float = 0.0, full_on_broken: bool = false) -> EffectDef:
	var e: EffectDef = EffectDef.new()
	e.effect_type = EffectDef.EffectType.HEAL
	e.heal_power = power
	e.heal_flat = flat
	e.target_mode_override = target_mode
	e.full_heal_on_broken = full_on_broken
	return e


func _shield(percent: float = 0.0, flat: float = 0.0, duration: float = 8.0, target_mode: int = -1) -> EffectDef:
	var e: EffectDef = EffectDef.new()
	e.effect_type = EffectDef.EffectType.SHIELD
	e.shield_flat = flat
	e.shield_percent_of_max_hp = percent
	e.shield_duration = duration
	e.target_mode_override = target_mode
	return e


func _status(status_id: String, target_mode: int = -1, duration: float = -1.0, chance: float = 1.0) -> EffectDef:
	var e: EffectDef = EffectDef.new()
	e.effect_type = EffectDef.EffectType.STATUS
	e.status = _statuses.get(status_id, null)
	e.target_mode_override = target_mode
	e.duration_override = duration
	e.chance = chance
	return e


func _arts(amount: float, target_mode: int = -1) -> EffectDef:
	var e: EffectDef = EffectDef.new()
	e.effect_type = EffectDef.EffectType.ARTS_GAIN
	e.arts_amount = amount
	e.target_mode_override = target_mode
	return e


func _break(amount: float, target_mode: int = -1) -> EffectDef:
	var e: EffectDef = EffectDef.new()
	e.effect_type = EffectDef.EffectType.BREAK_DAMAGE
	e.break_amount = amount
	e.target_mode_override = target_mode
	return e


func _ability(id: String, display_name: String, kind: int, cooldown: float,
		target_mode: int, effects: Array[EffectDef], opts: Dictionary = {}) -> AbilityDef:
	var a: AbilityDef = AbilityDef.new()
	a.id = StringName(id)
	a.display_name = display_name
	a.kind = kind
	a.cooldown = cooldown
	a.target_mode = target_mode
	a.effects = effects
	a.arts_cost = float(opts.get("arts_cost", 0.0))
	a.arts_generated = float(opts.get("arts_generated", 0.0))
	a.windup = float(opts.get("windup", 0.0))
	a.description = String(opts.get("description", ""))
	a.color = opts.get("color", Color(0.6, 0.82, 1.0))
	a.show_projectile = bool(opts.get("projectile", false))
	return a


# --------------------------------------------------------------------------
# Statuses
# --------------------------------------------------------------------------

func _build_statuses() -> void:
	# Venom: damage over time, stacks up to three times.
	var venom: StatusDef = StatusDef.new()
	venom.id = &"status_venom"
	venom.display_name = "Venom"
	venom.description = "Poison damage over time."
	venom.duration = 6.0
	venom.stack_policy = StatusDef.StackPolicy.STACK
	venom.max_stacks = 3
	venom.periodic_damage = 7.0
	venom.periodic_interval = 1.0
	venom.periodic_element = -1
	venom.color = Color(0.45, 0.85, 0.35)
	venom.icon = "V"
	venom = _save(venom, "statuses", "status_venom.tres")
	_statuses["status_venom"] = venom

	# Stun: blocks all actions.
	var stun: StatusDef = StatusDef.new()
	stun.id = &"status_stun"
	stun.display_name = "Stunned"
	stun.description = "Cannot act."
	stun.duration = 2.0
	stun.stack_policy = StatusDef.StackPolicy.REFRESH
	stun.blocks_actions = true
	stun.color = Color(1.0, 0.86, 0.3)
	stun.icon = "!"
	stun = _save(stun, "statuses", "status_stun.tres")
	_statuses["status_stun"] = stun

	# Might: attack buff.
	var might: StatusDef = StatusDef.new()
	might.id = &"status_might"
	might.display_name = "Might"
	might.description = "Attack increased."
	might.duration = 8.0
	might.attack_percent = 0.25
	might.color = Color(1.0, 0.55, 0.25)
	might.icon = "+"
	might = _save(might, "statuses", "status_might.tres")
	_statuses["status_might"] = might

	# Sundered: defence debuff.
	var sundered: StatusDef = StatusDef.new()
	sundered.id = &"status_sundered"
	sundered.display_name = "Sundered"
	sundered.description = "Defence reduced."
	sundered.duration = 8.0
	sundered.defense_percent = -0.3
	sundered.color = Color(0.8, 0.3, 0.5)
	sundered.icon = "-"
	sundered = _save(sundered, "statuses", "status_sundered.tres")
	_statuses["status_sundered"] = sundered

	# Wane: magic defence debuff.
	var wane: StatusDef = StatusDef.new()
	wane.id = &"status_wane"
	wane.display_name = "Wane"
	wane.description = "Magic defence reduced."
	wane.duration = 8.0
	wane.magic_defense_percent = -0.3
	wane.color = Color(0.65, 0.35, 0.85)
	wane.icon = "-"
	wane = _save(wane, "statuses", "status_wane.tres")
	_statuses["status_wane"] = wane

	# Bulwark: defence buff (used by the tank).
	var bulwark: StatusDef = StatusDef.new()
	bulwark.id = &"status_bulwark"
	bulwark.display_name = "Bulwark"
	bulwark.description = "Defence greatly increased."
	bulwark.duration = 8.0
	bulwark.defense_percent = 0.4
	bulwark.color = Color(0.55, 0.75, 0.95)
	bulwark.icon = "O"
	bulwark = _save(bulwark, "statuses", "status_bulwark.tres")
	_statuses["status_bulwark"] = bulwark

	# Ward: the shell used for every shield.
	var ward: StatusDef = StatusDef.new()
	ward.id = &"status_ward"
	ward.display_name = "Ward"
	ward.description = "Absorbs incoming damage."
	ward.duration = 8.0
	ward.shield_absorb_ratio = 1.0
	ward.color = Color(0.6, 0.9, 1.0)
	ward.icon = "S"
	ward = _save(ward, "statuses", "status_ward.tres")
	_statuses["status_ward"] = ward

	# Resonance: arts generation over time.
	var resonance: StatusDef = StatusDef.new()
	resonance.id = &"status_resonance"
	resonance.display_name = "Resonance"
	resonance.description = "Arts gauge regenerates."
	resonance.duration = 6.0
	resonance.arts_per_tick = 9.0
	resonance.arts_tick_interval = 1.0
	resonance.color = Color(0.45, 0.85, 1.0)
	resonance.icon = "A"
	resonance = _save(resonance, "statuses", "status_resonance.tres")
	_statuses["status_resonance"] = resonance

	# Renewal: regeneration over time.
	var renewal: StatusDef = StatusDef.new()
	renewal.id = &"status_renewal"
	renewal.display_name = "Renewal"
	renewal.description = "Restores health over time."
	renewal.duration = 8.0
	renewal.periodic_heal = 12.0
	renewal.periodic_interval = 1.0
	renewal.color = Color(0.5, 0.9, 0.6)
	renewal.icon = "H"
	renewal = _save(renewal, "statuses", "status_renewal.tres")
	_statuses["status_renewal"] = renewal

	# Enraged: the boss phase change buff.
	var enraged: StatusDef = StatusDef.new()
	enraged.id = &"status_enraged"
	enraged.display_name = "Enraged"
	enraged.description = "Attack greatly increased."
	enraged.duration = 9999.0
	enraged.attack_percent = 0.45
	enraged.color = Color(1.0, 0.35, 0.2)
	enraged.icon = "!"
	enraged = _save(enraged, "statuses", "status_enraged.tres")
	_statuses["status_enraged"] = enraged


# --------------------------------------------------------------------------
# Abilities
# --------------------------------------------------------------------------

func _build_abilities() -> void:
	var fire: int = Elements.Element.FIRE
	var earth: int = Elements.Element.EARTH
	var water: int = Elements.Element.WATER
	var light: int = Elements.Element.LIGHT
	var dark: int = Elements.Element.DARK

	# --- Kael Vondar -------------------------------------------------------
	var kael_basic: AbilityDef = _ability("kael_basic", "Cinder Slash", AbilityDef.Kind.BASIC, 1.8, Targeting.Mode.SINGLE_TARGET, [_damage(100.0, EffectDef.DamageKind.PHYSICAL, fire), _break(9.0)], {"description": "A quick burning cut.", "color": Elements.element_color(fire)})
	_abilities["kael_basic"] = _save(kael_basic, "abilities", "kael_basic.tres")

	var kael_skill: AbilityDef = _ability("kael_skill", "Flame Cleave", AbilityDef.Kind.SKILL, 7.0, Targeting.Mode.SINGLE_TARGET, [_damage(170.0, EffectDef.DamageKind.PHYSICAL, fire), _break(10.0)], {"arts_generated": 15.0, "description": "A heavy strike that chips the break meter.", "color": Elements.element_color(fire)})
	_abilities["kael_skill"] = _save(kael_skill, "abilities", "kael_skill.tres")

	var kael_arts: AbilityDef = _ability("kael_arts", "Ember Rush", AbilityDef.Kind.ARTS, 0.0, Targeting.Mode.SINGLE_TARGET, [_damage(220.0, EffectDef.DamageKind.MAGICAL, fire), _status("status_venom")], {"arts_cost": 100.0, "description": "Bursts the target in flame and poisons it.", "color": Elements.element_color(fire), "projectile": true})
	_abilities["kael_arts"] = _save(kael_arts, "abilities", "kael_arts.tres")

	var kael_true: AbilityDef = _ability("kael_true", "Blazing Verdict", AbilityDef.Kind.TRUE_ARTS, 0.0, Targeting.Mode.ALL_ENEMIES, [_damage(180.0, EffectDef.DamageKind.MAGICAL, fire), _break(15.0)], {"arts_cost": 200.0, "description": "Judges every enemy on the field with a wave of fire.", "color": Elements.element_color(fire)})
	_abilities["kael_true"] = _save(kael_true, "abilities", "kael_true.tres")

	# --- Seraphine Quill ---------------------------------------------------
	var sera_basic: AbilityDef = _ability("sera_basic", "Staff Smite", AbilityDef.Kind.BASIC, 2.0, Targeting.Mode.SINGLE_TARGET, [_damage(90.0, EffectDef.DamageKind.MAGICAL, light), _break(6.0)], {"description": "A measured strike of light.", "color": Elements.element_color(light)})
	_abilities["sera_basic"] = _save(sera_basic, "abilities", "sera_basic.tres")

	var sera_skill: AbilityDef = _ability("sera_skill", "Mending Light", AbilityDef.Kind.SKILL, 6.0, Targeting.Mode.LOWEST_HP_ALLY, [_heal(180.0)], {"arts_generated": 15.0, "description": "Heals the most wounded ally.", "color": Elements.element_color(light)})
	_abilities["sera_skill"] = _save(sera_skill, "abilities", "sera_skill.tres")

	var sera_arts: AbilityDef = _ability("sera_arts", "Aegis Prayer", AbilityDef.Kind.ARTS, 0.0, Targeting.Mode.ALL_ALLIES, [_heal(130.0, Targeting.Mode.ALL_ALLIES), _shield(0.12, 0.0, 8.0, Targeting.Mode.ALL_ALLIES)], {"arts_cost": 100.0, "description": "Heals and shields the whole party.", "color": Elements.element_color(light)})
	_abilities["sera_arts"] = _save(sera_arts, "abilities", "sera_arts.tres")

	var sera_true: AbilityDef = _ability("sera_true", "Dawnlit Communion", AbilityDef.Kind.TRUE_ARTS, 0.0, Targeting.Mode.ALL_ALLIES, [
			_heal(200.0, Targeting.Mode.ALL_ALLIES),
			_shield(0.2, 0.0, 10.0, Targeting.Mode.ALL_ALLIES),
			_arts(60.0, Targeting.Mode.ALL_ALLIES),
			_status("status_might", Targeting.Mode.ALL_ALLIES),
		], {"arts_cost": 200.0, "description": "A radiant rite: healing, wards, focus and courage.", "color": Elements.element_color(light)})
	_abilities["sera_true"] = _save(sera_true, "abilities", "sera_true.tres")

	# --- Torvald Grim ------------------------------------------------------
	var torv_basic: AbilityDef = _ability("torv_basic", "Shield Bash", AbilityDef.Kind.BASIC, 2.2, Targeting.Mode.SINGLE_TARGET, [_damage(90.0, EffectDef.DamageKind.PHYSICAL, earth), _break(13.0)], {"description": "A heavy bash that stresses the guard.", "color": Elements.element_color(earth)})
	_abilities["torv_basic"] = _save(torv_basic, "abilities", "torv_basic.tres")

	var torv_skill: AbilityDef = _ability("torv_skill", "Bulwark Stance", AbilityDef.Kind.SKILL, 9.0, Targeting.Mode.SELF, [_status("status_bulwark", Targeting.Mode.SELF), _shield(0.15, 0.0, 8.0, Targeting.Mode.SELF)], {"arts_generated": 15.0, "description": "Raises a defensive stance and a shield.", "color": Elements.element_color(earth)})
	_abilities["torv_skill"] = _save(torv_skill, "abilities", "torv_skill.tres")

	var torv_arts: AbilityDef = _ability("torv_arts", "Seismic Anchor", AbilityDef.Kind.ARTS, 0.0, Targeting.Mode.ALL_ENEMIES, [_damage(160.0, EffectDef.DamageKind.PHYSICAL, earth), _status("status_stun", Targeting.Mode.ALL_ENEMIES, -1.0, 0.4)], {"arts_cost": 100.0, "description": "Shakes the ground; may stun the enemies.", "color": Elements.element_color(earth)})
	_abilities["torv_arts"] = _save(torv_arts, "abilities", "torv_arts.tres")

	var torv_true: AbilityDef = _ability("torv_true", "Mountain's Decree", AbilityDef.Kind.TRUE_ARTS, 0.0, Targeting.Mode.ALL_ALLIES, [
			_shield(0.25, 0.0, 10.0, Targeting.Mode.ALL_ALLIES),
			_status("status_bulwark", Targeting.Mode.ALL_ALLIES),
			_arts(40.0, Targeting.Mode.ALL_ALLIES),
		], {"arts_cost": 200.0, "description": "Calls down a mountain's protection over the party.", "color": Elements.element_color(earth)})
	_abilities["torv_true"] = _save(torv_true, "abilities", "torv_true.tres")

	# --- Lysa Venne --------------------------------------------------------
	var lysa_basic: AbilityDef = _ability("lysa_basic", "Arcane Dart", AbilityDef.Kind.BASIC, 2.4, Targeting.Mode.SINGLE_TARGET, [_damage(85.0, EffectDef.DamageKind.MAGICAL, water), _break(6.0)], {"description": "A dart of compressed water.", "color": Elements.element_color(water), "projectile": true})
	_abilities["lysa_basic"] = _save(lysa_basic, "abilities", "lysa_basic.tres")

	var lysa_skill: AbilityDef = _ability("lysa_skill", "Tidal Gift", AbilityDef.Kind.SKILL, 8.0, Targeting.Mode.ALL_ALLIES, [_arts(45.0, Targeting.Mode.ALL_ALLIES), _arts(20.0, Targeting.Mode.SELF)], {"arts_generated": 15.0, "description": "Shares her focus with the whole party.", "color": Elements.element_color(water)})
	_abilities["lysa_skill"] = _save(lysa_skill, "abilities", "lysa_skill.tres")

	var lysa_arts: AbilityDef = _ability("lysa_arts", "Cleansing Mist", AbilityDef.Kind.ARTS, 0.0, Targeting.Mode.ALL_ALLIES, [_heal(120.0, Targeting.Mode.ALL_ALLIES), _status("status_sundered", Targeting.Mode.ALL_ENEMIES)], {"arts_cost": 100.0, "description": "Heals the party and weakens the enemy guard.", "color": Elements.element_color(water)})
	_abilities["lysa_arts"] = _save(lysa_arts, "abilities", "lysa_arts.tres")

	var lysa_true: AbilityDef = _ability("lysa_true", "Tide of Resonance", AbilityDef.Kind.TRUE_ARTS, 0.0, Targeting.Mode.ALL_ALLIES, [
			_status("status_might", Targeting.Mode.ALL_ALLIES),
			_status("status_resonance", Targeting.Mode.ALL_ALLIES),
			_arts(50.0, Targeting.Mode.ALL_ALLIES),
		], {"arts_cost": 200.0, "description": "A tide of power: courage, focus and momentum.", "color": Elements.element_color(water)})
	_abilities["lysa_true"] = _save(lysa_true, "abilities", "lysa_true.tres")

	# --- Rune Ashmaw -------------------------------------------------------
	var rune_basic: AbilityDef = _ability("rune_basic", "Rend", AbilityDef.Kind.BASIC, 1.6, Targeting.Mode.SINGLE_TARGET, [_damage(95.0, EffectDef.DamageKind.PHYSICAL, dark), _break(18.0)], {"description": "A vicious cut that shakes the enemy's guard.", "color": Elements.element_color(dark)})
	_abilities["rune_basic"] = _save(rune_basic, "abilities", "rune_basic.tres")

	var rune_skill: AbilityDef = _ability("rune_skill", "Sunder Mark", AbilityDef.Kind.SKILL, 7.0, Targeting.Mode.SINGLE_TARGET, [_status("status_sundered"), _break(30.0)], {"arts_generated": 15.0, "description": "Marks the target: less defence, much less guard.", "color": Elements.element_color(dark)})
	_abilities["rune_skill"] = _save(rune_skill, "abilities", "rune_skill.tres")

	var rune_arts: AbilityDef = _ability("rune_arts", "Rift Burst", AbilityDef.Kind.ARTS, 0.0, Targeting.Mode.SINGLE_TARGET, [_damage(200.0, EffectDef.DamageKind.MAGICAL, dark), _break(40.0), _status("status_venom")], {"arts_cost": 100.0, "description": "Tears a rift in the target's guard.", "color": Elements.element_color(dark)})
	_abilities["rune_arts"] = _save(rune_arts, "abilities", "rune_arts.tres")

	var rune_true: AbilityDef = _ability("rune_true", "Eventide Nail", AbilityDef.Kind.TRUE_ARTS, 0.0, Targeting.Mode.SINGLE_TARGET, [_break(90.0), _damage(150.0, EffectDef.DamageKind.MAGICAL, dark), _status("status_sundered"), _arts(40.0, Targeting.Mode.SELF)], {"arts_cost": 200.0, "description": "Drives a nail of night through the enemy's resolve.", "color": Elements.element_color(dark)})
	_abilities["rune_true"] = _save(rune_true, "abilities", "rune_true.tres")

	# --- Brennan Cole ------------------------------------------------------
	var bren_basic: AbilityDef = _ability("bren_basic", "Quick Shot", AbilityDef.Kind.BASIC, 1.3, Targeting.Mode.SINGLE_TARGET, [_damage(80.0, EffectDef.DamageKind.PHYSICAL, fire), _break(7.0)], {"description": "A fast, well placed arrow.", "color": Elements.element_color(fire), "projectile": true})
	_abilities["bren_basic"] = _save(bren_basic, "abilities", "bren_basic.tres")

	var bren_skill: AbilityDef = _ability("bren_skill", "Cinder Volley", AbilityDef.Kind.SKILL, 5.5, Targeting.Mode.SINGLE_TARGET, [_damage(140.0, EffectDef.DamageKind.PHYSICAL, fire), _break(12.0)], {"arts_generated": 15.0, "description": "A burning volley of arrows.", "color": Elements.element_color(fire), "projectile": true})
	_abilities["bren_skill"] = _save(bren_skill, "abilities", "bren_skill.tres")

	var bren_arts: AbilityDef = _ability("bren_arts", "Scorching Rain", AbilityDef.Kind.ARTS, 0.0, Targeting.Mode.ALL_ENEMIES, [_damage(130.0, EffectDef.DamageKind.MAGICAL, fire), _status("status_venom", Targeting.Mode.ALL_ENEMIES)], {"arts_cost": 100.0, "description": "Calls down a rain of fire.", "color": Elements.element_color(fire)})
	_abilities["bren_arts"] = _save(bren_arts, "abilities", "bren_arts.tres")

	var bren_true: AbilityDef = _ability("bren_true", "Phoenix Fall", AbilityDef.Kind.TRUE_ARTS, 0.0, Targeting.Mode.SINGLE_TARGET, [_damage(260.0, EffectDef.DamageKind.MAGICAL, fire), _break(30.0), _status("status_might", Targeting.Mode.SELF)], {"arts_cost": 200.0, "description": "One burning arrow, and the hunter burns brighter.", "color": Elements.element_color(fire), "projectile": true})
	_abilities["bren_true"] = _save(bren_true, "abilities", "bren_true.tres")

	# --- Enemy abilities ---------------------------------------------------
	var wisp_basic: AbilityDef = _ability("wisp_basic", "Ember Lash", AbilityDef.Kind.BASIC, 2.1, Targeting.Mode.SINGLE_TARGET, [_damage(70.0, EffectDef.DamageKind.MAGICAL, fire), _break(4.0)], {"description": "A whip of flame.", "color": Elements.element_color(fire)})
	_abilities["wisp_basic"] = _save(wisp_basic, "abilities", "wisp_basic.tres")

	var wisp_ability: AbilityDef = _ability("wisp_ability", "Flare Burst", AbilityDef.Kind.SKILL, 6.0, Targeting.Mode.SINGLE_TARGET, [_damage(110.0, EffectDef.DamageKind.MAGICAL, fire)], {"windup": 0.8, "description": "Charges and erupts.", "color": Elements.element_color(fire)})
	_abilities["wisp_ability"] = _save(wisp_ability, "abilities", "wisp_ability.tres")

	var slime_basic: AbilityDef = _ability("slime_basic", "Squelch", AbilityDef.Kind.BASIC, 2.1, Targeting.Mode.SINGLE_TARGET, [_damage(85.0, EffectDef.DamageKind.PHYSICAL, water), _break(6.0)], {"description": "A heavy slap.", "color": Elements.element_color(water)})
	_abilities["slime_basic"] = _save(slime_basic, "abilities", "slime_basic.tres")

	var slime_ability: AbilityDef = _ability("slime_ability", "Tidal Slap", AbilityDef.Kind.SKILL, 7.5, Targeting.Mode.SINGLE_TARGET, [_damage(115.0, EffectDef.DamageKind.PHYSICAL, water), _status("status_sundered", -1.0, -1.0, 0.5)], {"windup": 0.7, "description": "A crushing wave of water.", "color": Elements.element_color(water)})
	_abilities["slime_ability"] = _save(slime_ability, "abilities", "slime_ability.tres")

	var husk_basic: AbilityDef = _ability("husk_basic", "Rock Fist", AbilityDef.Kind.BASIC, 2.3, Targeting.Mode.SINGLE_TARGET, [_damage(90.0, EffectDef.DamageKind.PHYSICAL, earth), _break(12.0)], {"description": "A hammer blow.", "color": Elements.element_color(earth)})
	_abilities["husk_basic"] = _save(husk_basic, "abilities", "husk_basic.tres")

	var husk_ability: AbilityDef = _ability("husk_ability", "Quake", AbilityDef.Kind.SKILL, 9.0, Targeting.Mode.ALL_ENEMIES, [_damage(95.0, EffectDef.DamageKind.PHYSICAL, earth)], {"windup": 1.0, "description": "Shatters the ground beneath the party.", "color": Elements.element_color(earth)})
	_abilities["husk_ability"] = _save(husk_ability, "abilities", "husk_ability.tres")

	var shade_basic: AbilityDef = _ability("shade_basic", "Shadow Cut", AbilityDef.Kind.BASIC, 2.0, Targeting.Mode.SINGLE_TARGET, [_damage(75.0, EffectDef.DamageKind.MAGICAL, dark), _break(5.0)], {"description": "A blade of night.", "color": Elements.element_color(dark)})
	_abilities["shade_basic"] = _save(shade_basic, "abilities", "shade_basic.tres")

	var shade_ability: AbilityDef = _ability("shade_ability", "Drain Essence", AbilityDef.Kind.SKILL, 8.0, Targeting.Mode.SINGLE_TARGET, [_damage(85.0, EffectDef.DamageKind.MAGICAL, dark), _arts(-40.0)], {"windup": 0.9, "description": "Steals vitality and focus.", "color": Elements.element_color(dark)})
	_abilities["shade_ability"] = _save(shade_ability, "abilities", "shade_ability.tres")

	# --- Boss abilities ----------------------------------------------------
	var boss_basic: AbilityDef = _ability("boss_basic", "Cinder Sweep", AbilityDef.Kind.BASIC, 2.0, Targeting.Mode.SINGLE_TARGET, [_damage(105.0, EffectDef.DamageKind.PHYSICAL, fire), _break(10.0)], {"description": "A wide sweep of burning steel.", "color": Elements.element_color(fire)})
	_abilities["boss_basic"] = _save(boss_basic, "abilities", "boss_basic.tres")

	var boss_cataclysm: AbilityDef = _ability("boss_cataclysm", "Cataclysm", AbilityDef.Kind.SKILL, 12.0, Targeting.Mode.ALL_ENEMIES, [_damage(110.0, EffectDef.DamageKind.MAGICAL, fire), _break(20.0, Targeting.Mode.ALL_ENEMIES)], {"windup": 1.8, "description": "A burning sky that falls on the whole party.", "color": Color(1.0, 0.35, 0.15)})
	_abilities["boss_cataclysm"] = _save(boss_cataclysm, "abilities", "boss_cataclysm.tres")

	var boss_bulwark: AbilityDef = _ability("boss_bulwark", "Iron Bulwark", AbilityDef.Kind.SKILL, 14.0, Targeting.Mode.SELF, [_status("status_bulwark", Targeting.Mode.SELF), _shield(0.18, 0.0, 8.0, Targeting.Mode.SELF)], {"windup": 0.6, "description": "Raises an iron guard.", "color": Color(0.75, 0.75, 0.8)})
	_abilities["boss_bulwark"] = _save(boss_bulwark, "abilities", "boss_bulwark.tres")

	var boss_phase: AbilityDef = _ability("boss_phase", "Ashen Ascension", AbilityDef.Kind.SKILL, 0.0, Targeting.Mode.SELF, [_status("status_enraged", Targeting.Mode.SELF)], {"description": "The warden rises, burning with anger.", "color": Color(1.0, 0.25, 0.1)})
	_abilities["boss_phase"] = _save(boss_phase, "abilities", "boss_phase.tres")

	var boss_eruption: AbilityDef = _ability("boss_eruption", "Eruption", AbilityDef.Kind.SKILL, 7.0, Targeting.Mode.ALL_ENEMIES, [_damage(130.0, EffectDef.DamageKind.MAGICAL, fire)], {"windup": 1.2, "description": "Magma erupts beneath the party.", "color": Color(1.0, 0.45, 0.1)})
	_abilities["boss_eruption"] = _save(boss_eruption, "abilities", "boss_eruption.tres")

	var boss_chains: AbilityDef = _ability("boss_chains", "Magma Chains", AbilityDef.Kind.SKILL, 5.0, Targeting.Mode.SINGLE_TARGET, [_damage(170.0, EffectDef.DamageKind.MAGICAL, fire), _status("status_venom", -1.0, -1.0, 0.6)], {"windup": 0.9, "description": "Chains of magma seize one ally.", "color": Color(1.0, 0.55, 0.15)})
	_abilities["boss_chains"] = _save(boss_chains, "abilities", "boss_chains.tres")

	# --- Equipment actives -------------------------------------------------
	var eq_ember_strike: AbilityDef = _ability("eq_ember_strike", "Emberbrand Strike", AbilityDef.Kind.SKILL, 8.0, Targeting.Mode.SINGLE_TARGET, [_damage(160.0, EffectDef.DamageKind.MAGICAL, fire)], {"description": "A branded blade that erupts on impact.", "color": Elements.element_color(fire)})
	_abilities["eq_ember_strike"] = _save(eq_ember_strike, "abilities", "eq_ember_strike.tres")

	var eq_twin_fang: AbilityDef = _ability("eq_twin_fang", "Twin Fang", AbilityDef.Kind.SKILL, 5.0, Targeting.Mode.SINGLE_TARGET, [_damage(190.0, EffectDef.DamageKind.PHYSICAL, fire)], {"description": "Two quick bites.", "color": Elements.element_color(fire)})
	_abilities["eq_twin_fang"] = _save(eq_twin_fang, "abilities", "eq_twin_fang.tres")

	var eq_arc_discharge: AbilityDef = _ability("eq_arc_discharge", "Arc Discharge", AbilityDef.Kind.SKILL, 9.0, Targeting.Mode.SINGLE_TARGET, [_damage(170.0, EffectDef.DamageKind.MAGICAL, water), _arts(25.0, Targeting.Mode.SELF)], {"description": "Discharges stored charge into a foe.", "color": Elements.element_color(water)})
	_abilities["eq_arc_discharge"] = _save(eq_arc_discharge, "abilities", "eq_arc_discharge.tres")

	var eq_bulwark_up: AbilityDef = _ability("eq_bulwark_up", "Bulwark", AbilityDef.Kind.SKILL, 12.0, Targeting.Mode.SELF, [_shield(0.2, 0.0, 8.0, Targeting.Mode.SELF)], {"description": "Raises the plate into a guard.", "color": Color(0.6, 0.8, 1.0)})
	_abilities["eq_bulwark_up"] = _save(eq_bulwark_up, "abilities", "eq_bulwark_up.tres")

	var eq_warding_veil: AbilityDef = _ability("eq_warding_veil", "Warding Veil", AbilityDef.Kind.SKILL, 14.0, Targeting.Mode.SELF, [_shield(0.12, 0.0, 8.0, Targeting.Mode.SELF), _status("status_bulwark", Targeting.Mode.SELF)], {"description": "A veil that turns aside harm.", "color": Color(0.65, 0.85, 1.0)})
	_abilities["eq_warding_veil"] = _save(eq_warding_veil, "abilities", "eq_warding_veil.tres")

	var eq_aegis_pulse: AbilityDef = _ability("eq_aegis_pulse", "Aegis Pulse", AbilityDef.Kind.SKILL, 13.0, Targeting.Mode.SELF, [_shield(0.15, 0.0, 8.0, Targeting.Mode.SELF), _status("status_renewal", Targeting.Mode.SELF)], {"description": "A pulse of protection and renewal.", "color": Color(0.6, 0.9, 0.75)})
	_abilities["eq_aegis_pulse"] = _save(eq_aegis_pulse, "abilities", "eq_aegis_pulse.tres")

	var eq_vital_surge: AbilityDef = _ability("eq_vital_surge", "Vital Surge", AbilityDef.Kind.SKILL, 11.0, Targeting.Mode.SELF, [_heal(0.0, Targeting.Mode.SELF, 60.0), _arts(30.0, Targeting.Mode.SELF)], {"description": "A rush of life and focus.", "color": Color(0.55, 0.95, 0.6)})
	_abilities["eq_vital_surge"] = _save(eq_vital_surge, "abilities", "eq_vital_surge.tres")

	var eq_mending_weave: AbilityDef = _ability("eq_mending_weave", "Mending Weave", AbilityDef.Kind.SKILL, 7.0, Targeting.Mode.LOWEST_HP_ALLY, [_heal(200.0)], {"description": "Knits wounds closed.", "color": Color(0.7, 1.0, 0.8)})
	_abilities["eq_mending_weave"] = _save(eq_mending_weave, "abilities", "eq_mending_weave.tres")

	var eq_resonant_chime: AbilityDef = _ability("eq_resonant_chime", "Resonant Chime", AbilityDef.Kind.SKILL, 10.0, Targeting.Mode.ALL_ALLIES, [_arts(55.0, Targeting.Mode.ALL_ALLIES)], {"description": "A chime that refills the party's focus.", "color": Color(0.5, 0.85, 1.0)})
	_abilities["eq_resonant_chime"] = _save(eq_resonant_chime, "abilities", "eq_resonant_chime.tres")

	var eq_warcry: AbilityDef = _ability("eq_warcry", "War Cry", AbilityDef.Kind.SKILL, 14.0, Targeting.Mode.ALL_ALLIES, [_status("status_might", Targeting.Mode.ALL_ALLIES), _arts(30.0, Targeting.Mode.ALL_ALLIES)], {"description": "A shout that sharpens every blade.", "color": Color(1.0, 0.6, 0.3)})
	_abilities["eq_warcry"] = _save(eq_warcry, "abilities", "eq_warcry.tres")

	var eq_venom_splash: AbilityDef = _ability("eq_venom_splash", "Venom Splash", AbilityDef.Kind.SKILL, 9.0, Targeting.Mode.SINGLE_TARGET, [_damage(80.0, EffectDef.DamageKind.MAGICAL, dark), _status("status_venom")], {"description": "A thrown flask of venom.", "color": Color(0.45, 0.85, 0.35)})
	_abilities["eq_venom_splash"] = _save(eq_venom_splash, "abilities", "eq_venom_splash.tres")


# --------------------------------------------------------------------------
# Characters
# --------------------------------------------------------------------------

func _slot(id: String, display_name: String, categories: Array[int]) -> EquipmentSlotDef:
	var slot: EquipmentSlotDef = EquipmentSlotDef.new()
	slot.id = StringName(id)
	slot.display_name = display_name
	slot.allowed_categories = categories
	return slot


func _build_characters() -> void:
	var attack: int = EquipmentDef.Category.ATTACK
	var defense: int = EquipmentDef.Category.DEFENSE
	var support: int = EquipmentDef.Category.SUPPORT

	# Kael Vondar - Fire vanguard.
	var kael: CharacterDef = CharacterDef.new()
	kael.id = &"kael_vondar"
	kael.display_name = "Kael Vondar"
	kael.element = Elements.Element.FIRE
	kael.role = "Vanguard"
	kael.description = "A frontline swordfighter who trades safety for pressure."
	kael.lore = "Former shield captain of the Ember Watch. He fights to keep the line, and the line keeps him."
	kael.roster_order = 0
	kael.base_max_hp = 260.0
	kael.base_attack = 30.0
	kael.base_defense = 16.0
	kael.base_magic = 12.0
	kael.base_magic_defense = 12.0
	kael.hp_growth = 22.0
	kael.attack_growth = 3.4
	kael.defense_growth = 2.0
	kael.magic_growth = 1.2
	kael.magic_defense_growth = 1.5
	kael.body_color = Color(0.85, 0.33, 0.22)
	kael.accent_color = Color(1.0, 0.85, 0.4)
	kael.body_size = Vector2(34, 76)
	kael.body_shape = 0
	kael.basic_attack = _abilities["kael_basic"]
	kael.skill = _abilities["kael_skill"]
	kael.arts = _abilities["kael_arts"]
	kael.true_arts = _abilities["kael_true"]
	kael.equipment_slots = [
		_slot("offence", "Offence", [attack]),
		_slot("guard", "Guard", [defense]),
		_slot("aux", "Auxiliary", [attack, support]),
	]
	_save(kael, "characters", "kael_vondar.tres")

	# Seraphine Quill - Light cleric.
	var sera: CharacterDef = CharacterDef.new()
	sera.id = &"seraphine_quill"
	sera.display_name = "Seraphine Quill"
	sera.element = Elements.Element.LIGHT
	sera.role = "Cleric"
	sera.description = "A gentle scholar who keeps the party upright."
	sera.lore = "She catalogues the last songs of a fallen order. Her wards are the reason the Ember Watch still exists."
	sera.roster_order = 1
	sera.base_max_hp = 210.0
	sera.base_attack = 12.0
	sera.base_defense = 12.0
	sera.base_magic = 28.0
	sera.base_magic_defense = 22.0
	sera.hp_growth = 17.0
	sera.attack_growth = 1.2
	sera.defense_growth = 1.6
	sera.magic_growth = 3.3
	sera.magic_defense_growth = 2.6
	sera.body_color = Color(0.95, 0.9, 0.65)
	sera.accent_color = Color(1.0, 1.0, 0.85)
	sera.body_size = Vector2(30, 70)
	sera.body_shape = 3
	sera.basic_attack = _abilities["sera_basic"]
	sera.skill = _abilities["sera_skill"]
	sera.arts = _abilities["sera_arts"]
	sera.true_arts = _abilities["sera_true"]
	sera.equipment_slots = [
		_slot("offence", "Offence", [support]),
		_slot("guard", "Guard", [defense]),
		_slot("aux", "Auxiliary", [support]),
	]
	_save(sera, "characters", "seraphine_quill.tres")

	# Torvald Grim - Earth guardian.
	var torv: CharacterDef = CharacterDef.new()
	torv.id = &"torvald_grim"
	torv.display_name = "Torvald Grim"
	torv.element = Elements.Element.EARTH
	torv.role = "Guardian"
	torv.description = "A wall of a person who absorbs punishment."
	torv.lore = "He was carved out of mountain stone and finished with stubbornness. Nothing gets past him twice."
	torv.roster_order = 2
	torv.base_max_hp = 340.0
	torv.base_attack = 18.0
	torv.base_defense = 26.0
	torv.base_magic = 10.0
	torv.base_magic_defense = 20.0
	torv.hp_growth = 30.0
	torv.attack_growth = 1.8
	torv.defense_growth = 3.0
	torv.magic_growth = 1.0
	torv.magic_defense_growth = 2.2
	torv.body_color = Color(0.55, 0.42, 0.28)
	torv.accent_color = Color(0.85, 0.75, 0.5)
	torv.body_size = Vector2(40, 80)
	torv.body_shape = 2
	torv.basic_attack = _abilities["torv_basic"]
	torv.skill = _abilities["torv_skill"]
	torv.arts = _abilities["torv_arts"]
	torv.true_arts = _abilities["torv_true"]
	torv.equipment_slots = [
		_slot("offence", "Offence", [defense]),
		_slot("guard", "Guard", [defense]),
		_slot("aux", "Auxiliary", [support]),
	]
	_save(torv, "characters", "torvald_grim.tres")

	# Lysa Venne - Water arcanist.
	var lysa: CharacterDef = CharacterDef.new()
	lysa.id = &"lysa_venne"
	lysa.display_name = "Lysa Venne"
	lysa.element = Elements.Element.WATER
	lysa.role = "Arcanist"
	lysa.description = "A support caster who keeps the arts gauge spinning."
	lysa.lore = "She reads tides in teacups. Nothing in the party runs out of focus while she is breathing."
	lysa.roster_order = 3
	lysa.base_max_hp = 195.0
	lysa.base_attack = 11.0
	lysa.base_defense = 11.0
	lysa.base_magic = 26.0
	lysa.base_magic_defense = 20.0
	lysa.hp_growth = 15.0
	lysa.attack_growth = 1.1
	lysa.defense_growth = 1.5
	lysa.magic_growth = 3.1
	lysa.magic_defense_growth = 2.4
	lysa.body_color = Color(0.3, 0.6, 0.95)
	lysa.accent_color = Color(0.7, 0.95, 1.0)
	lysa.body_size = Vector2(28, 72)
	lysa.body_shape = 3
	lysa.basic_attack = _abilities["lysa_basic"]
	lysa.skill = _abilities["lysa_skill"]
	lysa.arts = _abilities["lysa_arts"]
	lysa.true_arts = _abilities["lysa_true"]
	lysa.equipment_slots = [
		_slot("offence", "Offence", [support, attack]),
		_slot("guard", "Guard", [defense]),
		_slot("aux", "Auxiliary", [support]),
	]
	_save(lysa, "characters", "lysa_venne.tres")

	# Rune Ashmaw - Dark saboteur (break specialist).
	var rune: CharacterDef = CharacterDef.new()
	rune.id = &"rune_ashmaw"
	rune.display_name = "Rune Ashmaw"
	rune.element = Elements.Element.DARK
	rune.role = "Saboteur"
	rune.description = "A break specialist who wrecks enemy guards."
	rune.lore = "Nobody remembers her real name. They only remember the sound a guard makes when it gives up."
	rune.roster_order = 4
	rune.base_max_hp = 205.0
	rune.base_attack = 26.0
	rune.base_defense = 12.0
	rune.base_magic = 20.0
	rune.base_magic_defense = 16.0
	rune.hp_growth = 16.0
	rune.attack_growth = 3.1
	rune.defense_growth = 1.6
	rune.magic_growth = 2.4
	rune.magic_defense_growth = 1.9
	rune.body_color = Color(0.45, 0.25, 0.6)
	rune.accent_color = Color(0.9, 0.4, 0.95)
	rune.body_size = Vector2(30, 72)
	rune.body_shape = 4
	rune.basic_attack = _abilities["rune_basic"]
	rune.skill = _abilities["rune_skill"]
	rune.arts = _abilities["rune_arts"]
	rune.true_arts = _abilities["rune_true"]
	rune.equipment_slots = [
		_slot("offence", "Offence", [attack, support]),
		_slot("guard", "Guard", [defense]),
		_slot("aux", "Auxiliary", [attack, support]),
	]
	_save(rune, "characters", "rune_ashmaw.tres")

	# Brennan Cole - Fire ranger.
	var bren: CharacterDef = CharacterDef.new()
	bren.id = &"brennan_cole"
	bren.display_name = "Brennan Cole"
	bren.element = Elements.Element.FIRE
	bren.role = "Ranger"
	bren.description = "A fast archer who breaks guards and keeps the pace."
	bren.lore = "He range the burning roads before the Ember Watch did, and he still runs ahead of trouble."
	bren.roster_order = 5
	bren.base_max_hp = 215.0
	bren.base_attack = 24.0
	bren.base_defense = 13.0
	bren.base_magic = 18.0
	bren.base_magic_defense = 15.0
	bren.hp_growth = 17.0
	bren.attack_growth = 2.9
	bren.defense_growth = 1.7
	bren.magic_growth = 2.2
	bren.magic_defense_growth = 1.8
	bren.body_color = Color(0.9, 0.5, 0.25)
	bren.accent_color = Color(0.6, 0.85, 0.4)
	bren.body_size = Vector2(30, 74)
	bren.body_shape = 1
	bren.basic_attack = _abilities["bren_basic"]
	bren.skill = _abilities["bren_skill"]
	bren.arts = _abilities["bren_arts"]
	bren.true_arts = _abilities["bren_true"]
	bren.equipment_slots = [
		_slot("offence", "Offence", [attack]),
		_slot("guard", "Guard", [defense]),
		_slot("aux", "Auxiliary", [support]),
	]
	_save(bren, "characters", "brennan_cole.tres")


# --------------------------------------------------------------------------
# Enemies
# --------------------------------------------------------------------------

func _build_enemies() -> void:
	# Cinder Wisp.
	var wisp: EnemyDef = EnemyDef.new()
	wisp.id = &"cinder_wisp"
	wisp.display_name = "Cinder Wisp"
	wisp.element = Elements.Element.FIRE
	wisp.role = "Skirmisher"
	wisp.description = "A fast ember spirit."
	wisp.base_max_hp = 85.0
	wisp.base_attack = 17.0
	wisp.base_defense = 8.0
	wisp.base_magic = 16.0
	wisp.base_magic_defense = 10.0
	wisp.break_max = 60.0
	wisp.break_duration = 3.5
	wisp.attacks = [_abilities["wisp_basic"], _abilities["wisp_ability"]]
	wisp.body_color = Color(0.95, 0.45, 0.2)
	wisp.accent_color = Color(1.0, 0.9, 0.5)
	wisp.body_size = Vector2(28, 58)
	wisp.body_shape = 1
	wisp.attack_start_delay = 0.5
	_save(wisp, "enemies", "cinder_wisp.tres")

	# Marsh Slime.
	var slime: EnemyDef = EnemyDef.new()
	slime.id = &"marsh_slime"
	slime.display_name = "Marsh Slime"
	slime.element = Elements.Element.WATER
	slime.role = "Bruiser"
	slime.description = "A slow, heavy blob of the causeway."
	slime.base_max_hp = 150.0
	slime.base_attack = 19.0
	slime.base_defense = 18.0
	slime.base_magic = 10.0
	slime.base_magic_defense = 16.0
	slime.break_max = 90.0
	slime.break_duration = 4.0
	slime.attacks = [_abilities["slime_basic"], _abilities["slime_ability"]]
	slime.body_color = Color(0.25, 0.55, 0.75)
	slime.accent_color = Color(0.6, 0.95, 0.9)
	slime.body_size = Vector2(42, 58)
	slime.body_shape = 1
	slime.attack_start_delay = 0.9
	_save(slime, "enemies", "marsh_slime.tres")

	# Stone Husk.
	var husk: EnemyDef = EnemyDef.new()
	husk.id = &"stone_husk"
	husk.display_name = "Stone Husk"
	husk.element = Elements.Element.EARTH
	husk.role = "Colossus"
	husk.description = "An armoured husk of packed earth."
	husk.base_max_hp = 200.0
	husk.base_attack = 22.0
	husk.base_defense = 28.0
	husk.base_magic = 8.0
	husk.base_magic_defense = 24.0
	husk.break_max = 120.0
	husk.break_duration = 4.5
	husk.attacks = [_abilities["husk_basic"], _abilities["husk_ability"]]
	husk.body_color = Color(0.5, 0.4, 0.3)
	husk.accent_color = Color(0.75, 0.65, 0.45)
	husk.body_size = Vector2(46, 78)
	husk.body_shape = 2
	husk.attack_start_delay = 1.1
	_save(husk, "enemies", "stone_husk.tres")

	# Night Shade.
	var shade: EnemyDef = EnemyDef.new()
	shade.id = &"night_shade"
	shade.display_name = "Night Shade"
	shade.element = Elements.Element.DARK
	shade.role = "Duelist"
	shade.description = "A swift shadow that drinks focus."
	shade.base_max_hp = 105.0
	shade.base_attack = 21.0
	shade.base_defense = 12.0
	shade.base_magic = 20.0
	shade.base_magic_defense = 18.0
	shade.break_max = 70.0
	shade.break_duration = 3.5
	shade.attacks = [_abilities["shade_basic"], _abilities["shade_ability"]]
	shade.body_color = Color(0.35, 0.2, 0.5)
	shade.accent_color = Color(0.85, 0.45, 0.95)
	shade.body_size = Vector2(32, 70)
	shade.body_shape = 4
	shade.attack_start_delay = 0.7
	_save(shade, "enemies", "night_shade.tres")

	# Boss: Aurelith, the Ashen Warden.
	var boss: EnemyDef = EnemyDef.new()
	boss.id = &"aurelith_warden"
	boss.display_name = "Aurelith, the Ashen Warden"
	boss.element = Elements.Element.FIRE
	boss.role = "Boss"
	boss.description = "The warden of the vault. It breaks only once, but it breaks hard."
	boss.base_max_hp = 950.0
	boss.base_attack = 30.0
	boss.base_defense = 24.0
	boss.base_magic = 28.0
	boss.base_magic_defense = 22.0
	boss.break_max = 120.0
	boss.break_duration = 5.0
	boss.is_boss = true
	boss.phase_change_threshold = 0.5
	boss.phase_change_ability = _abilities["boss_phase"]
	boss.attacks = [_abilities["boss_basic"], _abilities["boss_cataclysm"], _abilities["boss_bulwark"]]
	boss.phase_two_attacks = [_abilities["boss_eruption"], _abilities["boss_chains"]]
	boss.body_color = Color(0.55, 0.18, 0.12)
	boss.accent_color = Color(1.0, 0.55, 0.2)
	boss.body_size = Vector2(60, 104)
	boss.body_shape = 2
	boss.attack_start_delay = 1.5
	boss.target_preference = EnemyDef.TargetPreference.STRONGEST
	_save(boss, "enemies", "aurelith_warden.tres")


# --------------------------------------------------------------------------
# Equipment
# --------------------------------------------------------------------------

func _build_equipment() -> void:
	# --- Attack category ---
	var blade: EquipmentDef = EquipmentDef.new()
	blade.id = &"emberbrand_blade"
	blade.display_name = "Emberbrand Blade"
	blade.description = "A warm blade that bites deep."
	blade.category = EquipmentDef.Category.ATTACK
	blade.attack_percent = 0.15
	blade.arts_per_attack = 3.0
	blade.active_ability = _abilities["eq_ember_strike"]
	blade.icon_color = Color(0.95, 0.45, 0.25)
	_save(blade, "equipment", "emberbrand_blade.tres")

	var fangs: EquipmentDef = EquipmentDef.new()
	fangs.id = &"twin_fangs"
	fangs.display_name = "Twin Fangs"
	fangs.description = "Two blades, one rhythm."
	fangs.category = EquipmentDef.Category.ATTACK
	fangs.attack_percent = 0.12
	fangs.arts_per_attack = 5.0
	fangs.active_ability = _abilities["eq_twin_fang"]
	fangs.icon_color = Color(0.9, 0.7, 0.4)
	_save(fangs, "equipment", "twin_fangs.tres")

	var rod: EquipmentDef = EquipmentDef.new()
	rod.id = &"stormcaller_rod"
	rod.display_name = "Stormcaller Rod"
	rod.description = "A rod that never quite runs dry."
	rod.category = EquipmentDef.Category.ATTACK
	rod.magic_percent = 0.18
	rod.active_ability = _abilities["eq_arc_discharge"]
	rod.icon_color = Color(0.4, 0.75, 1.0)
	_save(rod, "equipment", "stormcaller_rod.tres")

	# --- Defense category ---
	var plate: EquipmentDef = EquipmentDef.new()
	plate.id = &"bulwark_plate"
	plate.display_name = "Bulwark Plate"
	plate.description = "Heavy plate with a raised guard."
	plate.category = EquipmentDef.Category.DEFENSE
	plate.defense_percent = 0.25
	plate.max_hp_flat = 40.0
	plate.active_ability = _abilities["eq_bulwark_up"]
	plate.icon_color = Color(0.6, 0.75, 0.9)
	_save(plate, "equipment", "bulwark_plate.tres")

	var cloak: EquipmentDef = EquipmentDef.new()
	cloak.id = &"wardens_cloak"
	cloak.display_name = "Warden's Cloak"
	cloak.description = "Woven to turn aside arrows and worse."
	cloak.category = EquipmentDef.Category.DEFENSE
	cloak.defense_percent = 0.15
	cloak.magic_defense_percent = 0.2
	cloak.active_ability = _abilities["eq_warding_veil"]
	cloak.icon_color = Color(0.55, 0.65, 0.85)
	_save(cloak, "equipment", "wardens_cloak.tres")

	var cuirass: EquipmentDef = EquipmentDef.new()
	cuirass.id = &"aegis_cuirass"
	cuirass.display_name = "Aegis Cuirass"
	cuirass.description = "It remembers every blow it has taken."
	cuirass.category = EquipmentDef.Category.DEFENSE
	cuirass.defense_percent = 0.2
	cuirass.magic_defense_percent = 0.15
	cuirass.max_hp_flat = 25.0
	cuirass.active_ability = _abilities["eq_aegis_pulse"]
	cuirass.icon_color = Color(0.5, 0.85, 0.75)
	_save(cuirass, "equipment", "aegis_cuirass.tres")

	var belt: EquipmentDef = EquipmentDef.new()
	belt.id = &"vigor_belt"
	belt.display_name = "Vigor Belt"
	belt.description = "A simple belt that keeps the wearer going."
	belt.category = EquipmentDef.Category.DEFENSE
	belt.defense_percent = 0.1
	belt.max_hp_flat = 20.0
	belt.active_ability = _abilities["eq_vital_surge"]
	belt.icon_color = Color(0.8, 0.6, 0.35)
	_save(belt, "equipment", "vigor_belt.tres")

	# --- Support category ---
	var knot: EquipmentDef = EquipmentDef.new()
	knot.id = &"healers_knot"
	knot.display_name = "Healer's Knot"
	knot.description = "Tied on a battlefield, once, for a friend."
	knot.category = EquipmentDef.Category.SUPPORT
	knot.magic_percent = 0.12
	knot.active_ability = _abilities["eq_mending_weave"]
	knot.icon_color = Color(0.65, 0.95, 0.7)
	_save(knot, "equipment", "healers_knot.tres")

	var bell: EquipmentDef = EquipmentDef.new()
	bell.id = &"resonance_bell"
	bell.display_name = "Resonance Bell"
	bell.description = "Rings only when someone needs focus."
	bell.category = EquipmentDef.Category.SUPPORT
	bell.active_ability = _abilities["eq_resonant_chime"]
	bell.icon_color = Color(0.5, 0.85, 1.0)
	_save(bell, "equipment", "resonance_bell.tres")

	var tonic: EquipmentDef = EquipmentDef.new()
	tonic.id = &"warpaint_tonic"
	tonic.display_name = "Warpaint Tonic"
	tonic.description = "Bitter. Effective."
	tonic.category = EquipmentDef.Category.SUPPORT
	tonic.attack_percent = 0.05
	tonic.active_ability = _abilities["eq_warcry"]
	tonic.icon_color = Color(1.0, 0.6, 0.3)
	_save(tonic, "equipment", "warpaint_tonic.tres")

	var flask: EquipmentDef = EquipmentDef.new()
	flask.id = &"venom_flask"
	flask.display_name = "Venom Flask"
	flask.description = "Do not drink it."
	flask.category = EquipmentDef.Category.SUPPORT
	flask.attack_percent = 0.05
	flask.active_ability = _abilities["eq_venom_splash"]
	flask.icon_color = Color(0.45, 0.8, 0.35)
	_save(flask, "equipment", "venom_flask.tres")


# --------------------------------------------------------------------------
# Quests
# --------------------------------------------------------------------------

func _wave(label: String, enemies: Array[StringName], delay: float = 1.5) -> WaveDef:
	var wave: WaveDef = WaveDef.new()
	wave.label = label
	wave.enemy_ids = enemies
	wave.break_delay = delay
	return wave


func _build_quests() -> void:
	var q1: QuestDef = QuestDef.new()
	q1.id = &"quest_cinder_road"
	q1.display_name = "Cinder Road"
	q1.description = "Scorched trade roads outside the Ember Watch. Something is still burning out there."
	q1.recommended_level = 1
	q1.reward_xp = 120
	q1.reward_currency = 60
	q1.reward_items = [&"bulwark_plate"]
	q1.waves = [
		_wave("Wave 1", [&"cinder_wisp", &"cinder_wisp"]),
		_wave("Wave 2", [&"cinder_wisp", &"cinder_wisp", &"stone_husk"]),
		_wave("Wave 3", [&"stone_husk", &"stone_husk", &"stone_husk", &"cinder_wisp"]),
	]
	_save(q1, "quests", "quest_cinder_road.tres")

	var q2: QuestDef = QuestDef.new()
	q2.id = &"quest_sunken_causeway"
	q2.display_name = "Sunken Causeway"
	q2.description = "The old road under the marsh floods every season. This time something came back with it."
	q2.recommended_level = 3
	q2.requires_quest = &"quest_cinder_road"
	q2.reward_xp = 190
	q2.reward_currency = 90
	q2.reward_items = [&"resonance_bell"]
	q2.waves = [
		_wave("Wave 1", [&"marsh_slime", &"marsh_slime"]),
		_wave("Wave 2", [&"marsh_slime", &"marsh_slime", &"night_shade"]),
		_wave("Wave 3", [&"night_shade", &"night_shade", &"marsh_slime", &"cinder_wisp"]),
	]
	_save(q2, "quests", "quest_sunken_causeway.tres")

	var q3: QuestDef = QuestDef.new()
	q3.id = &"quest_ashen_vault"
	q3.display_name = "The Ashen Vault"
	q3.description = "The Ember Watch sealed something in the vault. The seal is failing."
	q3.recommended_level = 5
	q3.requires_quest = &"quest_sunken_causeway"
	q3.reward_xp = 340
	q3.reward_currency = 180
	q3.reward_items = [&"stormcaller_rod", &"venom_flask"]
	q3.waves = [
		_wave("Wave 1", [&"stone_husk", &"stone_husk", &"night_shade"]),
		_wave("Wave 2", [&"marsh_slime", &"marsh_slime", &"cinder_wisp", &"cinder_wisp"]),
		_wave("Wave 3", [&"aurelith_warden", &"cinder_wisp"], 2.5),
	]
	_save(q3, "quests", "quest_ashen_vault.tres")


func _build_balance() -> void:
	var balance: BalanceConfig = BalanceConfig.new()
	balance.arts_max = 200.0
	balance.arts_cost = 100.0
	balance.true_arts_cost = 200.0
	balance.arts_per_basic_attack = 12.0
	balance.arts_per_skill = 15.0
	balance.break_damage_per_basic_attack = 5.0
	balance.break_duration = 4.0
	balance.critical_rate = 0.08
	balance.critical_multiplier = 1.6
	balance.broken_damage_multiplier = 1.25
	balance.defense_constant = 100.0
	balance.damage_variance = 0.0
	balance.element_advantage_multiplier = 1.5
	balance.element_neutral_multiplier = 1.0
	balance.xp_base = 80
	balance.xp_per_level = 60
	balance.currency_per_quest = 60
	balance.wave_break_seconds = 2.0
	_save(balance, "", "balance.tres")
