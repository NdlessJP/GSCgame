class_name Elements
extends RefCounted
## Central definition of the five combat elements and the explicit interaction table.
##
## The table is intentionally explicit and complete: every ordered pair of
## (attacker element, defender element) has a defined multiplier.  Only the
## five "beats" relationships are non-neutral; everything else is neutral.
##
##   Fire  beats Earth
##   Earth beats Water
##   Water beats Fire
##   Light beats Dark
##   Dark  beats Light

enum Element { FIRE, EARTH, WATER, LIGHT, DARK }

const ALL_ELEMENTS: Array[int] = [
	Element.FIRE, Element.EARTH, Element.WATER, Element.LIGHT, Element.DARK,
]

const ELEMENT_NAMES: Dictionary = {
	Element.FIRE: "Fire",
	Element.EARTH: "Earth",
	Element.WATER: "Water",
	Element.LIGHT: "Light",
	Element.DARK: "Dark",
}

const ELEMENT_COLORS: Dictionary = {
	Element.FIRE: Color(1.0, 0.42, 0.24),
	Element.EARTH: Color(0.72, 0.52, 0.28),
	Element.WATER: Color(0.31, 0.62, 1.0),
	Element.LIGHT: Color(1.0, 0.93, 0.66),
	Element.DARK: Color(0.66, 0.36, 0.88),
}

## Advantage relationships: attacker element -> defender element it beats.
const BEATS: Dictionary = {
	Element.FIRE: Element.EARTH,
	Element.EARTH: Element.WATER,
	Element.WATER: Element.FIRE,
	Element.LIGHT: Element.DARK,
	Element.DARK: Element.LIGHT,
}


static func element_name(element: int) -> String:
	return ELEMENT_NAMES.get(element, "Unknown")


static func element_color(element: int) -> Color:
	return ELEMENT_COLORS.get(element, Color.WHITE)


## Returns the raw interaction key for a pair, used by the explicit table below.
static func interaction(attacker: int, defender: int) -> Vector2i:
	return Vector2i(attacker, defender)


## The complete, explicit 5x5 interaction table.
## Rows are attacker elements, columns are defender elements.
## 1.0 = neutral, 1.5 = attacker has the advantage.
static func multiplier(attacker: int, defender: int, advantage: float = 1.5, neutral: float = 1.0) -> float:
	if not ELEMENT_NAMES.has(attacker):
		return neutral
	if not ELEMENT_NAMES.has(defender):
		return neutral
	if BEATS.get(attacker, -1) == defender:
		return advantage
	return neutral


## Human readable description, e.g. "Fire > Earth".
static func describe(attacker: int, defender: int) -> String:
	if BEATS.get(attacker, -1) == defender:
		return "%s > %s" % [element_name(attacker), element_name(defender)]
	return "%s - %s" % [element_name(attacker), element_name(defender)]
