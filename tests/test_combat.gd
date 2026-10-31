class_name CombatTests
extends RefCounted
## Focused checks for the combat maths and the ability rules.

static func run(database: GameDatabase) -> TestKit.Result:
	var result: TestKit.Result = TestKit.Result.new()
	var balance: BalanceConfig = BalanceConfig.make_default()
	balance.critical_rate = 0.0
	balance.damage_variance = 0.0

	_test_damage_formula(database, balance, result)
	_test_element_table(result)
	_test_arts_spending(database, balance, result)
	_test_cooldown_cannot_be_bypassed(database, balance, result)
	_test_status_expiration(database, result)
	_test_shield_absorbs_before_hp(database, result)
	_test_stun_blocks_actions(database, balance, result)
	_test_break_lifecycle(database, result)
	_test_retargeting(database, result)
	_test_healing_and_arts_generation(database, result)
	return result


static func _test_damage_formula(database: GameDatabase, balance: BalanceConfig, result: TestKit.Result) -> void:
	var attacker: CharacterDef = database.character(&"kael_vondar")
	var defender: CharacterDef = database.character(&"torvald_grim")
	var source: UnitState = UnitState.new(attacker, 1)
	var target: UnitState = UnitState.new(defender, 1)

	var params: DamageCalculator.DamageParams = DamageCalculator.DamageParams.new()
	params.source = source
	params.target = target
	params.base_amount = 100.0
	params.damage_kind = EffectDef.DamageKind.PHYSICAL
	params.element = Elements.Element.FIRE
	params.can_crit = false
	var physical: DamageCalculator.DamageResult = DamageCalculator.compute(params, balance)
	var expected: float = 100.0 * (balance.defense_constant / (balance.defense_constant + target.defense_stat()))
	expected *= balance.element_advantage_multiplier
	result.approx(physical.amount, expected, "Physical damage uses the defence curve and the element bonus")

	# Magical damage is mitigated by magic defence instead.
	params.damage_kind = EffectDef.DamageKind.MAGICAL
	params.element = Elements.Element.LIGHT
	var magical: DamageCalculator.DamageResult = DamageCalculator.compute(params, balance)
	var expected_magic: float = 100.0 * (balance.defense_constant / (balance.defense_constant + target.magic_defense_stat()))
	expected_magic *= balance.element_neutral_multiplier
	result.approx(magical.amount, expected_magic, "Magical damage uses the magic defence curve")

	# True damage ignores mitigation.
	params.damage_kind = EffectDef.DamageKind.TRUE
	var true_damage: DamageCalculator.DamageResult = DamageCalculator.compute(params, balance)
	result.approx(true_damage.amount, 100.0, "True damage ignores defence")

	# Broken targets take extra damage.
	params.damage_kind = EffectDef.DamageKind.PHYSICAL
	params.element = Elements.Element.FIRE
	var unbroken: float = DamageCalculator.compute(params, balance).amount
	target.is_broken = true
	var broken: float = DamageCalculator.compute(params, balance).amount
	result.approx(broken, unbroken * balance.broken_damage_multiplier, "Broken targets take increased damage")

	# Damage is actually applied to HP.
	var fresh_target: UnitState = UnitState.new(defender, 1)
	var hp_before: float = fresh_target.hp
	var apply_params: DamageCalculator.DamageParams = DamageCalculator.DamageParams.new()
	apply_params.source = source
	apply_params.target = fresh_target
	apply_params.base_amount = 50.0
	apply_params.damage_kind = EffectDef.DamageKind.PHYSICAL
	apply_params.element = Elements.Element.FIRE
	apply_params.can_crit = false
	DamageCalculator.apply(apply_params, balance)
	result.ok(fresh_target.hp < hp_before, "Applying damage reduces HP")


static func _test_element_table(result: TestKit.Result) -> void:
	var fire: int = Elements.Element.FIRE
	var earth: int = Elements.Element.EARTH
	var water: int = Elements.Element.WATER
	var light: int = Elements.Element.LIGHT
	var dark: int = Elements.Element.DARK
	result.approx(Elements.multiplier(fire, earth), 1.5, "Fire beats Earth")
	result.approx(Elements.multiplier(earth, water), 1.5, "Earth beats Water")
	result.approx(Elements.multiplier(water, fire), 1.5, "Water beats Fire")
	result.approx(Elements.multiplier(light, dark), 1.5, "Light beats Dark")
	result.approx(Elements.multiplier(dark, light), 1.5, "Dark beats Light")
	result.approx(Elements.multiplier(fire, water), 1.0, "Fire against Water is neutral")
	result.approx(Elements.multiplier(earth, fire), 1.0, "Earth against Fire is neutral")
	result.approx(Elements.multiplier(water, earth), 1.0, "Water against Earth is neutral")
	result.approx(Elements.multiplier(light, fire), 1.0, "Light against Fire is neutral")
	result.approx(Elements.multiplier(dark, earth), 1.0, "Dark against Earth is neutral")
	result.approx(Elements.multiplier(fire, fire), 1.0, "Fire against Fire is neutral")
	result.approx(Elements.multiplier(dark, dark), 1.0, "Dark against Dark is neutral")
	result.approx(Elements.multiplier(light, light), 1.0, "Light against Light is neutral")
	result.approx(Elements.multiplier(water, water), 1.0, "Water against Water is neutral")
	result.approx(Elements.multiplier(earth, earth), 1.0, "Earth against Earth is neutral")


static func _test_arts_spending(database: GameDatabase, balance: BalanceConfig, result: TestKit.Result) -> void:
	var def: CharacterDef = database.character(&"kael_vondar")
	var unit: UnitState = UnitState.new(def, 1)

	unit.arts = 100.0
	var arts: AbilityDef = def.arts
	result.ok(AbilityExecutor.pay(unit, arts), "Arts activation is allowed with exactly 100 arts")
	result.approx(unit.arts, 0.0, "Arts spends only the arts cost (100)")

	unit.arts = 200.0
	var true_arts: AbilityDef = def.true_arts
	result.ok(AbilityExecutor.pay(unit, true_arts), "True Arts activation is allowed with exactly 200 arts")
	result.approx(unit.arts, 0.0, "True Arts spends only the true arts cost (200)")

	unit.arts = 199.0
	result.ok(not AbilityExecutor.pay(unit, true_arts), "True Arts is refused with 199 arts")
	result.approx(unit.arts, 199.0, "A refused activation spends nothing")

	unit.arts = 0.0
	result.ok(not AbilityExecutor.pay(unit, arts), "Arts is refused without arts")


static func _test_cooldown_cannot_be_bypassed(database: GameDatabase, balance: BalanceConfig, result: TestKit.Result) -> void:
	var def: CharacterDef = database.character(&"kael_vondar")
	var unit: UnitState = UnitState.new(def, 1)
	unit.arts = 500.0
	var skill: AbilityDef = def.skill
	result.ok(AbilityExecutor.can_use(unit, skill, balance), "A ready skill can be used")
	AbilityExecutor.pay(unit, skill)
	result.ok(not AbilityExecutor.can_use(unit, skill, balance), "A skill on cooldown cannot be used again")
	result.ok(unit.cooldown_remaining(skill.id) > 0.0, "Using a skill starts its cooldown")
	unit.tick_cooldowns(skill.cooldown + 0.1)
	result.ok(AbilityExecutor.can_use(unit, skill, balance), "The skill is usable again once the cooldown ends")


static func _test_status_expiration(database: GameDatabase, result: TestKit.Result) -> void:
	var def: CharacterDef = database.character(&"rune_ashmaw")
	var unit: UnitState = UnitState.new(def, 1)
	var base_attack: float = unit.attack_stat()

	var buff: StatusDef = StatusDef.new()
	buff.id = &"test_buff"
	buff.display_name = "Test Buff"
	buff.duration = 2.0
	buff.attack_percent = 0.5
	unit.add_status(buff, null)
	result.approx(unit.attack_stat(), base_attack * 1.5, "An attack buff raises the attack stat")

	var debuff: StatusDef = StatusDef.new()
	debuff.id = &"test_debuff"
	debuff.display_name = "Test Debuff"
	debuff.duration = 2.0
	debuff.defense_percent = -0.5
	var base_defense: float = unit.defense_stat()
	unit.add_status(debuff, null)
	result.approx(unit.defense_stat(), base_defense * 0.5, "A defence debuff lowers the defence stat")

	unit.tick_statuses(2.1)
	result.ok(not unit.has_status(&"test_buff"), "An expired buff is removed")
	result.ok(not unit.has_status(&"test_debuff"), "An expired debuff is removed")
	result.approx(unit.attack_stat(), base_attack, "Stats return to their correct values after expiry")
	result.approx(unit.defense_stat(), base_defense, "Defence returns to its correct value after expiry")


static func _test_shield_absorbs_before_hp(database: GameDatabase, result: TestKit.Result) -> void:
	var def: CharacterDef = database.character(&"torvald_grim")
	var unit: UnitState = UnitState.new(def, 1)
	var hp_before: float = unit.hp
	var instance: StatusInstance = unit.add_status(EffectApplier.shield_template(), null, 8.0)
	instance.shield_pool = 50.0
	var applied: Dictionary = unit.take_damage(30.0)
	result.approx(float(applied["absorbed"]), 30.0, "The shield absorbs the damage")
	result.approx(unit.hp, hp_before, "No HP is lost while the shield holds")
	var overflow: Dictionary = unit.take_damage(80.0)
	result.approx(float(overflow["absorbed"]), 20.0, "The shield absorbs up to its remaining pool")
	result.approx(unit.hp, hp_before - 60.0, "The remainder damages HP")
	result.approx(unit.status_instances(&"status_ward")[0].shield_pool, 0.0, "An exhausted shield is emptied")


static func _test_stun_blocks_actions(database: GameDatabase, balance: BalanceConfig, result: TestKit.Result) -> void:
	var def: CharacterDef = database.character(&"kael_vondar")
	var unit: UnitState = UnitState.new(def, 1)
	unit.arts = 200.0
	var stun: StatusDef = StatusDef.new()
	stun.id = &"test_stun"
	stun.display_name = "Stun"
	stun.duration = 2.0
	stun.blocks_actions = true
	unit.add_status(stun, null)
	result.ok(unit.status_blocks_actions(), "A stun blocks actions")
	result.ok(not AbilityExecutor.can_use(unit, def.skill, balance), "A stunned unit cannot use a skill")
	result.ok(not AbilityExecutor.can_use(unit, def.arts, balance), "A stunned unit cannot use arts")
	result.ok(not AbilityExecutor.can_use(unit, def.basic_attack, balance), "A stunned unit cannot attack")


static func _test_break_lifecycle(database: GameDatabase, result: TestKit.Result) -> void:
	var def: EnemyDef = database.enemy(&"cinder_wisp")
	var enemy: UnitState = UnitState.new(def, 1)
	result.approx(enemy.break_meter, def.break_max, "Enemies start with a full break meter")
	result.ok(not enemy.add_break(10.0), "A partial break does not break the enemy")
	result.approx(enemy.break_meter, def.break_max - 10.0, "Break damage reduces the meter")
	result.ok(enemy.add_break(def.break_max), "The enemy breaks when the meter empties")
	result.ok(enemy.is_broken, "The enemy is in the broken state")
	result.ok(not enemy.add_break(10.0), "A broken enemy cannot break again")
	result.ok(not enemy.tick_break(def.break_duration - 0.1), "The broken state lasts for its duration")
	result.ok(enemy.tick_break(0.2), "The broken state ends after its duration")
	result.ok(not enemy.is_broken, "The enemy is no longer broken")
	result.approx(enemy.break_meter, def.break_max, "The break meter resets when the broken state ends")


static func _test_retargeting(database: GameDatabase, result: TestKit.Result) -> void:
	var ally_def: CharacterDef = database.character(&"kael_vondar")
	var enemy_def: EnemyDef = database.enemy(&"cinder_wisp")
	var ally: UnitState = UnitState.new(ally_def, 1)
	var first: UnitState = UnitState.new(enemy_def, 1)
	var second: UnitState = UnitState.new(enemy_def, 1)
	var allies: Array = [ally]
	var enemies: Array = [first, second]

	var targets: Array = AbilityExecutor.resolve_targets(
		Targeting.Mode.SINGLE_TARGET, ally, allies, enemies, first, null)
	result.ok(targets.size() == 1 and targets[0] == first, "The preferred enemy is used as the target")

	first.is_dead = true
	var retargeted: Array = AbilityExecutor.resolve_targets(
		Targeting.Mode.SINGLE_TARGET, ally, allies, enemies, first, null)
	result.ok(retargeted.size() == 1 and retargeted[0] == second,
		"A dead preferred target is replaced by another living enemy")

	var all: Array = AbilityExecutor.resolve_targets(
		Targeting.Mode.ALL_ENEMIES, ally, allies, enemies, first, null)
	result.ok(all.size() == 1 and all[0] == second, "Area attacks skip dead enemies")


static func _test_healing_and_arts_generation(database: GameDatabase, result: TestKit.Result) -> void:
	var def: CharacterDef = database.character(&"seraphine_quill")
	var healer: UnitState = UnitState.new(def, 1)
	var hurt: UnitState = UnitState.new(def, 1)
	hurt.hp = 10.0
	var effect: EffectDef = EffectDef.new()
	effect.effect_type = EffectDef.EffectType.HEAL
	effect.heal_flat = 40.0
	EffectApplier.apply(effect, healer, hurt, BalanceConfig.make_default())
	result.approx(hurt.hp, 50.0, "Healing restores HP")

	# Broken units only receive a fraction of the healing.
	hurt.hp = 10.0
	hurt.is_broken = true
	EffectApplier.apply(effect, healer, hurt, BalanceConfig.make_default())
	result.approx(hurt.hp, 22.0, "Healing a broken unit is reduced")

	var arts_effect: EffectDef = EffectDef.new()
	arts_effect.effect_type = EffectDef.EffectType.ARTS_GAIN
	arts_effect.arts_amount = 45.0
	EffectApplier.apply(arts_effect, healer, hurt, BalanceConfig.make_default())
	result.approx(hurt.arts, 45.0, "Arts effects fill the arts gauge")

	# The gauge never exceeds its maximum.
	arts_effect.arts_amount = 500.0
	EffectApplier.apply(arts_effect, healer, hurt, BalanceConfig.make_default())
	result.approx(hurt.arts, BalanceConfig.make_default().arts_max, "The arts gauge is capped at its maximum")
