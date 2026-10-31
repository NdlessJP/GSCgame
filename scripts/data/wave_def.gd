class_name WaveDef
extends Resource
## One wave of a quest.  Enemy composition is fully data driven; nothing about
## wave contents is hard coded in the battle controller.

@export var label: String = "Wave"
## One entry per enemy that will be spawned.  Repeating an id spawns a copy.
@export var enemy_ids: Array[StringName] = []
## Seconds of preparation shown before this wave's enemies act.
@export var break_delay: float = 1.5
