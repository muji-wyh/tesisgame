extends Node2D

# A one-shot visual toy. Its private random stream never changes game rewards.
const SECONDS: float = 2.4
const STILL_SECONDS: float = 1.1
const KINDS := ["star", "ball", "rocket", "kite", "robot", "doll"]
const TEXTURES := [
	preload("res://assets/chests/surprises/star.svg"),
	preload("res://assets/chests/surprises/ball.svg"),
	preload("res://assets/chests/surprises/rocket.svg"),
	preload("res://assets/chests/surprises/kite.svg"),
	preload("res://assets/chests/surprises/robot.svg"),
	preload("res://assets/chests/surprises/doll.svg")
]

var _random := RandomNumberGenerator.new()
var _index: int = -1
var _age: float = 0.0
var _active: bool = false
var _reduced: bool = false
var _play_count: int = 0
var _color := Color.WHITE
var _direction: float = 1.0
var _stage := Vector2.ZERO
var _origin := Vector2.ZERO
var _unit: float = 1.0
var _edge: float = 0.0


func _ready() -> void:
	_random.randomize()
	# ChestView advances the same clock as its opening and visibility lifecycle.
	set_process(false)
	hide()


func play(color: Color, reduce: bool = false) -> void:
	# Draw uniformly from the other toys to keep consecutive openings varied.
	var choice: int = _random.randi_range(0, KINDS.size() - (2 if _index >= 0 else 1))
	if _index >= 0 and choice >= _index:
		choice += 1
	_index = choice
	_direction = -1.0 if _random.randf() < 0.5 else 1.0
	_color = color
	_reduced = reduce
	_age = 0.0
	_active = true
	_play_count += 1
	show()
	queue_redraw()


func fit(stage_size: Vector2, origin: Vector2, pixel_scale: float) -> void:
	_stage = stage_size.max(Vector2.ZERO)
	_origin = origin
	_unit = 1.0 / maxf(0.25, pixel_scale)
	_edge = maxf(0.0, minf(96.0 * _unit, minf(_stage.x * 0.24, _stage.y * 0.28)))
	if _active:
		queue_redraw()


func advance(delta: float) -> void:
	if not _active or delta <= 0.0 or not is_finite(delta):
		return
	_age += delta
	if _age >= (STILL_SECONDS if _reduced else SECONDS):
		clear()
	else:
		queue_redraw()


func clear() -> void:
	_active = false
	_age = 0.0
	hide()
	queue_redraw()


func reduce_motion() -> void:
	if not _active or _reduced:
		return
	_reduced = true
	_age = 0.0
	queue_redraw()


func _center(age: float) -> Vector2:
	var margin: float = _edge * 1.1
	var lower := Vector2.ONE * margin
	var upper: Vector2 = (_stage - lower).max(lower)
	var start: Vector2 = _origin.clamp(lower, upper)
	var target: Vector2 = (start + Vector2(_direction * _edge * 0.85,
		-minf(_stage.y * 0.42, _edge * 1.9))).clamp(lower, upper)
	if _reduced:
		return target
	var flight: float = clampf(age / 0.86, 0.0, 1.0)
	var point: Vector2 = start.lerp(target, 1.0 - pow(1.0 - flight, 3.0))
	point.y -= sin(flight * PI) * _edge * 0.30
	# A small landing bounce resolves before the toy dissolves into its light.
	var landing: float = clampf((age - 0.86) / 0.42, 0.0, 1.0)
	point.y -= sin(landing * PI) * (1.0 - landing) * _edge * 0.10
	return point.clamp(lower, upper)


func snapshot() -> Dictionary:
	var extent: float = _edge * 1.06
	var center: Vector2 = _center(_age)
	var bounds := Rect2(center - Vector2.ONE * extent, Vector2.ONE * extent * 2.0)
	return {"active": _active and is_visible_in_tree(), "kind": KINDS[_index] if _active else "",
		"age": _age, "play_count": _play_count, "reduced_motion": _reduced,
		"bounds": {"x": bounds.position.x, "y": bounds.position.y,
			"width": bounds.size.x, "height": bounds.size.y}}


func _star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(8):
		points.append(center + Vector2.from_angle(PI * 0.25 * index)
			* radius * (1.0 if index % 2 == 0 else 0.28))
	draw_colored_polygon(points, color)


func _draw() -> void:
	if not _active or _edge <= 0.0:
		return
	var center: Vector2 = _center(_age)
	var alpha: float = 1.0 if _reduced else smoothstep(0.0, 0.12, _age) * (1.0 - smoothstep(1.65, SECONDS, _age))
	var flight: float = clampf(_age / 0.86, 0.0, 1.0)
	var scale: float = 1.0 if _reduced else lerpf(0.35, 1.0, smoothstep(0.0, 0.46, _age)) + sin(flight * PI) * 0.12
	for layer in range(4, 0, -1):
		draw_circle(center, _edge * (0.34 + layer * 0.11), Color(_color, 0.035 * alpha))
	if not _reduced:
		for index in range(5):
			var trail_age: float = maxf(0.0, _age - 0.045 * (index + 1))
			var trail_alpha: float = (1.0 - flight) * (1.0 - float(index) / 5.0) * alpha * 0.45
			draw_circle(_center(trail_age), _edge * 0.12, Color(_color.lightened(0.35), trail_alpha))
		for index in range(8):
			var angle: float = TAU * float(index) / 8.0 + _direction * 0.15 * _age
			var reach: float = _edge * (0.55 + 0.30 * smoothstep(0.3, 1.8, _age))
			var radius: float = _edge * 0.038 * (0.65 + sin(_age * 7.0 + index) * 0.35)
			_star(center + Vector2.from_angle(angle) * reach, radius,
				Color(_color.lightened(0.5) if index % 2 == 0 else Color.WHITE, alpha * 0.9))
	var rotation: float = 0.0 if _reduced else _direction * (-0.35 + TAU * (1.0 - pow(1.0 - flight, 3.0)))
	# A full turn resolves into a small tilt, without rotating back through 360 degrees.
	if not _reduced and flight >= 1.0:
		rotation = -_direction * 0.35 * (1.0 - smoothstep(0.86, 1.28, _age))
	draw_set_transform(center, rotation, Vector2.ONE * scale)
	var rect := Rect2(Vector2.ONE * -_edge * 0.5, Vector2.ONE * _edge)
	draw_texture_rect(TEXTURES[_index], Rect2(rect.position + Vector2(1.5, 3.0) * _unit, rect.size), false,
		Color(Color("#3c344e"), alpha * 0.23))
	draw_texture_rect(TEXTURES[_index], rect, false, Color(Color.WHITE, alpha))
	draw_set_transform(Vector2.ZERO)
