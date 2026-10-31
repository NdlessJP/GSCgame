class_name Projectile
extends Node2D
## Simple travelling shot used to visualise ranged abilities.

var target: Node2D = null
var speed: float = 460.0
var color: Color = Color(1.0, 0.8, 0.4)
var on_arrive: Callable = Callable()

var _direction: Vector2 = Vector2.RIGHT
var _life: float = 2.0


func setup(from: Vector2, to: Node2D, shot_color: Color, shot_speed: float = 460.0) -> void:
	position = from
	target = to
	color = shot_color
	speed = shot_speed


func _ready() -> void:
	z_index = 20
	if target != null and is_instance_valid(target):
		_direction = (target.global_position - global_position).normalized()
	else:
		_direction = Vector2.RIGHT


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if target != null and is_instance_valid(target):
		var to_target: Vector2 = target.global_position - global_position
		if to_target.length() < 12.0:
			if on_arrive.is_valid():
				on_arrive.call()
			queue_free()
			return
		_direction = to_target.normalized()
	global_position += _direction * speed * delta
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(color.r, color.g, color.b, 0.35))
	draw_circle(Vector2.ZERO, 3.5, color)
