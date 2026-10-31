class_name FloatingText
extends Node2D
## Small rising label used for damage, healing and ability names.

var text: String = ""
var color: Color = Color.WHITE
var lifetime: float = 0.9
var _age: float = 0.0
var _font: Font = null


func setup(label: String, label_color: Color, size: int = 16) -> void:
	text = label
	color = label_color
	lifetime = 0.9
	_font = ThemeDB.fallback_font


func _ready() -> void:
	if _font == null:
		_font = ThemeDB.fallback_font
	z_index = 50


func _process(delta: float) -> void:
	_age += delta
	position.y -= 42.0 * delta
	queue_redraw()
	if _age >= lifetime:
		queue_free()


func _draw() -> void:
	if _font == null:
		return
	var alpha: float = clampf(1.0 - _age / lifetime, 0.0, 1.0)
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var offset: Vector2 = Vector2(-width * 0.5, 0)
	draw_string(_font, offset + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(0, 0, 0, alpha * 0.7))
	draw_string(_font, offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(color.r, color.g, color.b, alpha))
