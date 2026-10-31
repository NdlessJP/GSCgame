class_name Targeting
extends RefCounted
## Targeting modes are always interpreted relative to the caster:
##   * SINGLE_TARGET  - one unit on the opposing side (uses the party's
##                      preferred enemy when the caster is an ally).
##   * ALL_ENEMIES    - every living unit on the opposing side.
##   * SINGLE_ALLY    - one living ally of the caster (lowest HP% by default).
##   * ALL_ALLIES     - every living ally of the caster.
##   * LOWEST_HP_ALLY - the caster's ally with the lowest HP percentage.
##   * SELF           - the caster.

enum Mode {
	SINGLE_TARGET,
	ALL_ENEMIES,
	SINGLE_ALLY,
	ALL_ALLIES,
	LOWEST_HP_ALLY,
	SELF,
}

const MODE_NAMES: Dictionary = {
	Mode.SINGLE_TARGET: "Single Target",
	Mode.ALL_ENEMIES: "All Enemies",
	Mode.SINGLE_ALLY: "Single Ally",
	Mode.ALL_ALLIES: "All Allies",
	Mode.LOWEST_HP_ALLY: "Lowest HP Ally",
	Mode.SELF: "Self",
}


static func mode_name(mode: int) -> String:
	return MODE_NAMES.get(mode, "Unknown")
