extends CanvasLayer
## Viewport paper lives beyond the chest beat, without owning input or rewards.

const PAPER = preload("res://assets/images/jelly-match/confetti.png")
const Style = preload("res://scripts/ui_style.gd")
const DURATION: float = 6.4
const PAPER_COUNT: int = 108
const COLORS: Array[Color] = [Color("#ffcf63"), Color("#ff8396"), Color("#67dbbe"), Color("#83bdff"), Color("#cf9af1")]

class PaperSurface extends Control:
	var effect: CanvasLayer

	func _draw() -> void:
		effect.draw_paper(self)

var _surface := PaperSurface.new()
var _bursts: Array[Dictionary] = []
var _seen_keys: Dictionary = {}
var _paused: bool = false


func _init() -> void:
	name = "RewardConfetti"
	layer = 80
	_surface.name = "ViewportPaper"
	_surface.effect = self
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.focus_mode = Control.FOCUS_NONE
	add_child(_surface)
	visible = false


func burst(key: String) -> bool:
	if key.is_empty() or _seen_keys.has(key):
		return false
	_seen_keys[key] = true
	_bursts.append({"key": key, "age": 0.0})
	_sync()
	return true


func advance(delta: float) -> void:
	if _paused or not is_finite(delta) or delta <= 0.0 or _bursts.is_empty():
		return
	for item: Dictionary in _bursts:
		item.age += delta
	_bursts = _bursts.filter(func(item: Dictionary) -> bool: return float(item.age) < DURATION)
	_sync()


func set_paused(value: bool) -> void:
	if _paused == value:
		return
	_paused = value
	_sync()


func clear() -> void:
	_bursts.clear()
	_seen_keys.clear()
	_sync()


func is_active() -> bool:
	return not _bursts.is_empty()


func _sync() -> void:
	visible = is_active() and not _paused
	_surface.queue_redraw()


func screen_rect() -> Rect2:
	return get_viewport().get_visible_rect() if is_inside_tree() else Rect2()


func _paper_state(index: int, screen: Rect2, unit: float, age: float) -> Dictionary:
	var horizontal_seed: float = fposmod(float(index) * 0.754878 + 0.31, 1.0)
	var vertical_seed: float = fposmod(float(index) * 0.569841 + 0.27, 1.0)
	var seed_value: float = fposmod(float(index) * 0.618034, 1.0)
	var delay: float = float(index % 11) * 0.025
	var finish: float = DURATION - 1.1 + vertical_seed * 1.1
	if not is_finite(age) or age <= delay or age >= finish:
		return {}
	var t: float = age - delay
	var extent: Vector2 = screen.size
	var paper_edge: float = lerpf(18.0, 28.0, seed_value) * unit
	var sway: float = lerpf(10.0, 22.0, vertical_seed) * unit
	var margin: float = paper_edge * 0.65 + sway
	var launch_x: float = extent.x * (0.015 + horizontal_seed * 0.08)
	if index % 2 != 0:
		launch_x = extent.x - launch_x
	launch_x = clampf(launch_x, margin, extent.x - margin)
	# Stratify the canopy across the entire viewport, independently of launch side.
	var landing_x: float = lerpf(margin, extent.x - margin, (float(index % 18) + 0.5) / 18.0)
	var rise_seconds: float = 0.55 + horizontal_seed * 0.25
	var rise: float = clampf(t / rise_seconds, 0.0, 1.0)
	var spread: float = 1.0 - pow(1.0 - rise, 3.0)
	var x: float = lerpf(launch_x, landing_x, spread) + sin(t * 2.4 + index) * sway * spread
	# Vary height independently of lifetime so paper does not fall as one strip.
	var apex: float = extent.y * (-0.06 + horizontal_seed * 0.30)
	var y: float
	if t < rise_seconds:
		y = lerpf(extent.y * (0.64 + seed_value * 0.29), apex, 1.0 - pow(1.0 - rise, 2.0))
	else:
		# A brief acceleration becomes a slow terminal drift. The fall uses real
		# seconds, never a compressed chest/Pip performance window.
		var fall: float = clampf((t - rise_seconds) / (finish - delay - rise_seconds), 0.0, 1.0)
		var drift: float = (fall - 0.12 * (1.0 - exp(-fall / 0.12))) / (1.0 - 0.12 * (1.0 - exp(-1.0 / 0.12)))
		y = lerpf(apex, extent.y + paper_edge, drift)
	var flutter: float = cos(t * (2.1 + seed_value * 1.2) + index)
	var dimensions := Vector2(paper_edge * maxf(0.16, absf(flutter)), paper_edge * 0.65)
	var color: Color = COLORS[index % COLORS.size()].darkened(0.20 if flutter < 0.0 else 0.0)
	return {"position": screen.position + Vector2(x, y), "size": dimensions,
		"rotation": index + t * (0.55 + seed_value * 0.85), "color": color}


func draw_paper(surface: Control) -> void:
	var screen: Rect2 = screen_rect()
	var unit: float = 1.0 / Style.ui_scale(surface)
	for item: Dictionary in _bursts:
		for index in range(PAPER_COUNT):
			var paper: Dictionary = _paper_state(index, screen, unit, float(item.age))
			if paper.is_empty():
				continue
			surface.draw_set_transform(paper.position, paper.rotation)
			surface.draw_texture_rect_region(PAPER, Rect2(-paper.size * 0.5, paper.size), Rect2(Vector2.ZERO, PAPER.get_size() * 0.5), paper.color)
	surface.draw_set_transform(Vector2.ZERO)


func snapshot() -> Dictionary:
	var rect: Rect2 = screen_rect()
	return {"active": is_active(), "visible": visible, "paused": _paused,
		"ages": _bursts.map(func(item: Dictionary) -> float: return float(item.age)),
		"keys": _seen_keys.keys(), "screen_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}
