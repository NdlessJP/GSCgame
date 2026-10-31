class_name WaveDef
extends Resource
## One wave of a quest.  Enemy composition is fully data driven; nothing about
## wave contents is hard coded in the battle controller.

@export var label: String = "Wave"
## One entry per enemy that will be spawned.  Repeating an id spawns a copy.
@export var enemy_ids: Array[StringName] = []
## Seconds of preparation shown before this wave's enemies act.
@export var break_delay: float = 1.5
## Level the enemies of this wave are spawned at.  Higher levels give the
## enemies more HP, attack, defense and magic (see UnitDef growth values).
@export var enemy_level: int = 1
## Flat multiplier applied on top of the level scaling.  Used to give later
## waves of a quest a difficulty ramp without touching the enemy definitions.
@export var stat_scale: float = 1.0
