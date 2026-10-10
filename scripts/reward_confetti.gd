extends Control
## Shared, viewport-wide paper burst sampled by the owning reward timeline.

const PAPER = preload("res://assets/images/jelly-match/confetti.png")
const Style = preload("res://scripts/ui_style.gd")
const DURATION: float = 1.43
const PAPER_COUNT: int = 108
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
	visible = is_finite(age) and is_finite(duration) and duration > 0.0 and age >= 0.0 and age < duration and opacity > 0.0
	_age = age * DURATION / maxf(0.001, duration)
	_opacity = clampf(opacity, 0.0, 1.0)
	queue_redraw()


func screen_rect() -> Rect2:
	if not is_inside_tree():
		return Rect2()
	return get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()


func _paper_state(index: int, screen: Rect2, unit: float) -> Dictionary:
	var progress: float = _age / DURATION
	var horizontal_seed: float = fposmod(float(index) * 0.754878 + 0.31, 1.0)
	var vertical_seed: float = fposmod(float(index) * 0.569841 + 0.27, 1.0)
	var seed_value: float = fposmod(float(index) * 0.618034, 1.0)
	var delay: float = float(index % 11) * 0.01
	var finish: float = 0.82 + vertical_seed * 0.18
	if progress <= delay or progress >= finish:
		return {}
	# Every staggered piece completes its own rise and fall inside the owner's
	# reveal window, including the shorter round finale. It exits below the frame
	# while still opaque instead of fading near the apex of an unfinished arc.
	var t: float = (progress - delay) / (finish - delay)
	var extent: Vector2 = screen.size
	var paper_edge: float = lerpf(18.0, 28.0, seed_value) * unit
	var sway: float = 12.0 * unit
	var margin: float = paper_edge * 0.65 + sway
	var launch_x: float = extent.x * (0.02 + horizontal_seed * 0.12)
	if index % 2 != 0:
		launch_x = extent.x - launch_x
	launch_x = clampf(launch_x, margin, extent.x - margin)
	var landing_x: float = lerpf(margin, extent.x - margin, 0.08 + horizontal_seed * 0.84)
	# Air resistance takes the speed out of the side launch before descent.
	var spread: float = (1.0 - exp(-4.0 * t)) / (1.0 - exp(-4.0))
	var x: float = lerpf(launch_x, landing_x, spread) + sin(t * 9.0 + index) * sway * sin(t * PI)
	var apex: float = maxf(paper_edge, extent.y * (0.04 + vertical_seed * 0.14))
	var apex_time: float = 0.24 + horizontal_seed * 0.09
	var y: float
	if t < apex_time:
		var rise: float = t / apex_time
		y = lerpf(extent.y * (0.64 + seed_value * 0.29), apex, 1.0 - pow(1.0 - rise, 2.0))
	else:
		var fall: float = (t - apex_time) / (1.0 - apex_time)
		y = lerpf(apex, extent.y + paper_edge, pow(fall, 1.65))
	var flutter: float = cos(t * (9.0 + seed_value * 7.0) + index)
	var dimensions := Vector2(paper_edge * maxf(0.16, absf(flutter)), paper_edge * 0.65)
	var color: Color = COLORS[index % COLORS.size()].darkened(0.20 if flutter < 0.0 else 0.0)
	color.a = _opacity
	return {"position": screen.position + Vector2(x, y), "size": dimensions,
		"rotation": index + t * (3.0 + seed_value * 4.0), "color": color}


func _draw() -> void:
	if not visible:
		return
	var screen: Rect2 = screen_rect()
	var unit: float = 1.0 / Style.ui_scale(self)
	for index in range(PAPER_COUNT):
		var paper: Dictionary = _paper_state(index, screen, unit)
		if paper.is_empty():
			continue
		draw_set_transform(paper.position, paper.rotation)
		draw_texture_rect_region(PAPER, Rect2(-paper.size * 0.5, paper.size), Rect2(Vector2.ZERO, PAPER.get_size() * 0.5), paper.color)
	draw_set_transform(Vector2.ZERO)
