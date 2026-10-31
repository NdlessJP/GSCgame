class_name Unit
extends Node2D
## Placeholder presentation for a combat unit.
##
## Everything is drawn with simple shapes: coloured silhouettes, element
## accents, hit flashes and a lunge animation.  No imported art is required.
## Replace `_draw()` with a Sprite2D / AnimatedSprite2D to use finished assets.

const NAME_FONT_SIZE: int = 13
const BAR_WIDTH: float = 52.0
const BAR_HEIGHT: float = 5.0

var state: UnitState = null
## Offset used for the attack lunge.
var body_offset: Vector2 = Vector2.ZERO
## 1.0 right after a hit, fades to 0.
var flash: float = 0.0
## 1.0 while the unit is the party's preferred target.
var selected: bool = false
## Rises briefly when the unit takes damage.
var hurt_shake: float = 0.0

var _attack_tween: Tween = null
var _font: Font = null


func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_process(true)


func setup(unit_state: UnitState) -> void:
	state = unit_state
	if unit_state != null:
		unit_state.view = self
	queue_redraw()


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
		queue_redraw()
	if hurt_shake > 0.0:
		hurt_shake = maxf(0.0, hurt_shake - delta * 3.0)
		queue_redraw()


## Called when the unit is hit.
func play_hit() -> void:
	flash = 1.0
	hurt_shake = 1.0
	queue_redraw()


## Called when the unit performs an attack.
func play_attack(target_global_position: Vector2) -> void:
	var direction: Vector2 = (target_global_position - global_position).normalized()
	if _attack_tween != null and _attack_tween.is_valid():
		_attack_tween.kill()
	_attack_tween = create_tween()
	_attack_tween.tween_property(self, "body_offset", direction * 26.0, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(self, "body_offset", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_QUAD)


func _draw() -> void:
	if state == null or state.def == null:
		return
	var def: UnitDef = state.def
	var size: Vector2 = def.body_size
	var body_color: Color = def.body_color
	var accent: Color = def.accent_color
	if state.is_dead:
		# Defeated units stay visible as a grey silhouette so the player can
		# still read the battlefield.
		body_color = body_color.lerp(Color(0.35, 0.35, 0.4), 0.75)
		accent = accent.lerp(Color(0.3, 0.3, 0.35), 0.7)
	body_color = body_color.lerp(Color(1, 1, 1), flash * 0.85)
	var origin: Vector2 = body_offset + Vector2(0, randf_range(-1.0, 1.0) * hurt_shake * 3.0)
	var half_w: float = size.x * 0.5
	var height: float = size.y

	# Shadow.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0, 2), half_w * 0.9, Color(0, 0, 0, 0.28))

	# Broken aura.
	if state.is_broken:
		draw_circle(origin + Vector2(0, -height * 0.5), half_w * 1.35, Color(1.0, 0.85, 0.25, 0.18))
		draw_arc(origin + Vector2(0, -height * 0.5), half_w * 1.2, 0.0, TAU, 28, Color(1.0, 0.85, 0.3, 0.7), 2.0)

	match def.body_shape:
		0: _draw_capsule(origin, size, body_color, accent)
		1: _draw_round(origin, size, body_color, accent)
		2: _draw_angular(origin, size, body_color, accent)
		3: _draw_robed(origin, size, body_color, accent)
		4: _draw_winged(origin, size, body_color, accent)
		_: _draw_capsule(origin, size, body_color, accent)

	# Defeated marker.
	if state.is_dead:
		var mark: Vector2 = origin + Vector2(0, -size.y * 0.55)
		draw_line(mark + Vector2(-8, -8), mark + Vector2(8, 8), Color(0.8, 0.25, 0.28), 2.5)
		draw_line(mark + Vector2(8, -8), mark + Vector2(-8, 8), Color(0.8, 0.25, 0.28), 2.5)

	# Preferred target marker.
	if selected and not state.is_dead:
		var marker: Vector2 = origin + Vector2(0, -height - 18.0)
		var pulse: float = 4.0 * sin(Time.get_ticks_msec() / 160.0)
		draw_colored_polygon(PackedVector2Array([
			marker + Vector2(-9, -10 + pulse),
			marker + Vector2(9, -10 + pulse),
			marker + Vector2(0, 2 + pulse),
		]), Color(1.0, 0.35, 0.3))

	# Name and bars for enemies (allies are shown in the HUD).
	if not state.is_ally:
		var top: Vector2 = origin + Vector2(0, -height - 14.0)
		if _font != null:
			var label: String = def.display_name
			var text_width: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE).x
			draw_string(_font, top + Vector2(-text_width * 0.5, 0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, Color(0.92, 0.92, 0.95))
		var bar_top: Vector2 = top + Vector2(-BAR_WIDTH * 0.5, 4.0)
		draw_rect(Rect2(bar_top, Vector2(BAR_WIDTH, BAR_HEIGHT)), Color(0.08, 0.08, 0.12, 0.85))
		var ratio: float = clampf(state.hp / maxf(1.0, state.max_hp()), 0.0, 1.0)
		draw_rect(Rect2(bar_top, Vector2(BAR_WIDTH * ratio, BAR_HEIGHT)), Color(0.85, 0.25, 0.28))
		if state.break_max > 0.0:
			var break_top: Vector2 = bar_top + Vector2(0, BAR_HEIGHT + 2.0)
			draw_rect(Rect2(break_top, Vector2(BAR_WIDTH, 3.0)), Color(0.08, 0.08, 0.12, 0.85))
			var break_ratio: float = 1.0 - state.break_ratio()
			draw_rect(Rect2(break_top, Vector2(BAR_WIDTH * break_ratio, 3.0)), Color(0.35, 0.8, 0.95))


func _draw_capsule(origin: Vector2, size: Vector2, body: Color, accent: Color) -> void:
	var half_w: float = size.x * 0.5
	var height: float = size.y
	draw_rect(Rect2(origin + Vector2(-half_w * 0.75, -height), Vector2(half_w * 1.5, height * 0.72)), body)
	draw_circle(origin + Vector2(0, -height * 0.82), half_w * 0.78, body)
	draw_circle(origin + Vector2(0, -height * 0.86), half_w * 0.3, accent)


func _draw_round(origin: Vector2, size: Vector2, body: Color, accent: Color) -> void:
	var half_w: float = size.x * 0.5
	var height: float = size.y
	draw_circle(origin + Vector2(0, -height * 0.45), half_w * 0.95, body)
	draw_circle(origin + Vector2(0, -height * 0.78), half_w * 0.42, accent)


func _draw_angular(origin: Vector2, size: Vector2, body: Color, accent: Color) -> void:
	var half_w: float = size.x * 0.5
	var height: float = size.y
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(-half_w, 0),
		origin + Vector2(-half_w * 0.6, -height),
		origin + Vector2(half_w * 0.6, -height),
		origin + Vector2(half_w, 0),
	]), body)
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(-half_w * 0.35, -height),
		origin + Vector2(0, -height - half_w * 0.9),
		origin + Vector2(half_w * 0.35, -height),
	]), accent)


func _draw_robed(origin: Vector2, size: Vector2, body: Color, accent: Color) -> void:
	var half_w: float = size.x * 0.5
	var height: float = size.y
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(-half_w, 0),
		origin + Vector2(-half_w * 0.55, -height * 0.75),
		origin + Vector2(0, -height),
		origin + Vector2(half_w * 0.55, -height * 0.75),
		origin + Vector2(half_w, 0),
	]), body)
	draw_circle(origin + Vector2(0, -height * 0.86), half_w * 0.34, accent)


func _draw_winged(origin: Vector2, size: Vector2, body: Color, accent: Color) -> void:
	var half_w: float = size.x * 0.5
	var height: float = size.y
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(-half_w * 0.45, -height),
		origin + Vector2(half_w * 0.45, -height),
		origin + Vector2(half_w * 0.4, 0),
		origin + Vector2(-half_w * 0.4, 0),
	]), body)
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(-half_w * 0.45, -height * 0.8),
		origin + Vector2(-half_w * 1.5, -height * 0.5),
		origin + Vector2(-half_w * 0.5, -height * 0.35),
	]), accent)
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(half_w * 0.45, -height * 0.8),
		origin + Vector2(half_w * 1.5, -height * 0.5),
		origin + Vector2(half_w * 0.5, -height * 0.35),
	]), accent)
	draw_circle(origin + Vector2(0, -height * 0.92), half_w * 0.32, accent)
