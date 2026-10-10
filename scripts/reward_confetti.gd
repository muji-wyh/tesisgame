extends Control
## Shared, viewport-wide paper burst sampled by the owning reward timeline.

const PAPER = preload("res://assets/images/jelly-match/confetti.png")
const Style = preload("res://scripts/ui_style.gd")
const DURATION: float = 1.43
const COLORS: Array[Color] = [Color("#ffcf63"), Color("#ff8396"), Color("#67dbbe"), Color("#83bdff"), Color("#cf9af1")]

var _age: float = 0.0
var _opacity: float = 1.0


func _init() -> void:
	name = "RewardConfetti"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	z_as_relative = false
	hide()


func sample(age: float, duration: float = DURATION, opacity: float = 1.0) -> void:
	visible = is_finite(age) and duration > 0.0 and age >= 0.0 and age < duration and opacity > 0.0
	_age = age * DURATION / maxf(0.001, duration)
	_opacity = clampf(opacity, 0.0, 1.0)
	queue_redraw()


func screen_rect() -> Rect2:
	if not is_inside_tree():
		return Rect2()
	return get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()


func _draw() -> void:
	if not visible:
		return
	# Preserve the production side fountains across the entire viewport and header.
	var screen: Rect2 = screen_rect()
	var origin: Vector2 = screen.position
	var unit: float = 1.0 / Style.ui_scale(self)
	var extent: Vector2 = screen.size
	for index in range(108):
		var horizontal_seed: float = fposmod(float(index) * 0.754878 + 0.31, 1.0)
		var vertical_seed: float = fposmod(float(index) * 0.569841 + 0.27, 1.0)
		var delay: float = float(index % 11) * 0.026
		var t: float = _age - delay
		if t <= 0.0:
			continue
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var seed_value: float = fposmod(float(index) * 0.618034, 1.0)
		var launch_x: float = 0.02 + horizontal_seed * 0.12
		var start := origin + Vector2(extent.x * (launch_x if side < 0.0 else 1.0 - launch_x), extent.y * (0.64 + seed_value * 0.29))
		var velocity := Vector2(-side * extent.x * (0.16 + horizontal_seed * 0.48), -extent.y * (1.05 + vertical_seed * 0.65))
		var point: Vector2 = start + velocity * t + Vector2(0.0, extent.y * 0.65 * t * t)
		point.x += sin(t * 6.0 + index) * 12.0 * unit
		var paper_edge: float = lerpf(18.0, 28.0, seed_value) * unit
		var flutter: float = cos(t * (7.0 + seed_value * 6.0) + index)
		var dimensions := Vector2(paper_edge * maxf(0.16, absf(flutter)), paper_edge * 0.65)
		var color: Color = COLORS[index % COLORS.size()]
		color = color.darkened(0.20 if flutter < 0.0 else 0.0)
		color.a = _opacity * (1.0 - smoothstep(1.17, DURATION, _age))
		draw_set_transform(point, index + t * (2.0 + seed_value * 3.0))
		draw_texture_rect_region(PAPER, Rect2(-dimensions * 0.5, dimensions), Rect2(Vector2.ZERO, PAPER.get_size() * 0.5), color)
	draw_set_transform(Vector2.ZERO)
