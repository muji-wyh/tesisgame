extends CanvasLayer
## Viewport paper lives beyond the chest beat, without owning input or rewards.

const PAPER = preload("res://assets/images/jelly-match/confetti.png")
const Style = preload("res://scripts/ui_style.gd")
const DURATION: float = 6.4
const PAPER_COUNT: int = 85
const MAX_PAPER_COUNT: int = 267
const PAPER_SPACING: float = 42.0
const SMALL_DURATION: float = 2.4
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
	return _start_burst(key, false)


func burst_small(key: String) -> bool:
	return _start_burst(key, true)


func _start_burst(key: String, small: bool) -> bool:
	if key.is_empty() or _seen_keys.has(key):
		return false
	_seen_keys[key] = true
	if small:
		_bursts = _bursts.filter(func(item: Dictionary) -> bool: return not bool(item.small))
	_bursts.append({"key": key, "age": 0.0, "small": small,
		"duration": SMALL_DURATION if small else DURATION,
		"variation": fposmod(float(key.hash()), 1009.0) / 1009.0})
	_sync()
	return true


func advance(delta: float) -> void:
	if _paused or not is_finite(delta) or delta <= 0.0 or _bursts.is_empty():
		return
	for item: Dictionary in _bursts:
		item.age += delta
	_bursts = _bursts.filter(func(item: Dictionary) -> bool: return float(item.age) < float(item.duration))
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


func _paper_count(screen: Rect2, unit: float) -> int:
	if not screen.has_area():
		return 0
	var spacing: float = PAPER_SPACING * maxf(0.25, unit)
	var previous: int = clampi(roundi(ceili(screen.get_area() / (spacing * spacing)) / 3.0), 128, 400)
	return clampi(roundi(previous * 2.0 / 3.0), PAPER_COUNT, MAX_PAPER_COUNT)


func _paper_state(index: int, screen: Rect2, unit: float, age: float, variation: float = 0.0) -> Dictionary:
	var count: int = _paper_count(screen, unit)
	if index < 0 or index >= count:
		return {}
	var columns: int = clampi(ceili(screen.size.x / (PAPER_SPACING * maxf(0.25, unit))), 8, 64)
	var rows: int = maxi(1, ceili(float(count) / columns))
	var column: int = index % columns
	var row: int = posmod(floori(float(index) / columns) + column * 7, rows)
	var horizontal_seed: float = fposmod(float(index) * 0.754878 + 0.31 + variation, 1.0)
	var seed_value: float = fposmod(float(index) * 0.618034 + variation * 0.41, 1.0)
	var vertical_seed: float = (row + 0.2 + seed_value * 0.6) / rows
	var delay: float = float(index % 11) * 0.025
	var finish: float = DURATION - 1.1 + vertical_seed * 1.1
	if not is_finite(age) or age <= delay or age >= finish:
		return {}
	var t: float = age - delay
	var extent: Vector2 = screen.size
	var paper_edge: float = lerpf(22.0, 34.0, seed_value) * unit
	var paper_size := Vector2(paper_edge * 1.5, paper_edge * 0.65)
	var sway: float = lerpf(20.0, 46.0, vertical_seed) * unit
	var margin: float = paper_size.length() * 0.5 + 2.0 * unit
	var launch_x: float = extent.x * (0.015 + horizontal_seed * 0.08)
	if index % 2 != 0:
		launch_x = extent.x - launch_x
	launch_x = clampf(launch_x, margin, extent.x - margin)
	# Stratify the canopy across the entire viewport, independently of launch side.
	var landing_x: float = lerpf(margin, extent.x - margin, (column + 0.2 + horizontal_seed * 0.6) / columns)
	var rise_seconds: float = 0.55 + horizontal_seed * 0.25
	var rise: float = clampf(t / rise_seconds, 0.0, 1.0)
	var spread: float = 1.0 - pow(1.0 - rise, 3.0)
	var phase: float = seed_value * TAU
	var wind_rate: float = lerpf(1.6, 3.1, horizontal_seed)
	var wind: float = sin(t * wind_rate + phase) * 0.72 + sin(t * wind_rate * 0.47 + vertical_seed * TAU) * 0.28
	var center_x: float = lerpf(launch_x, landing_x, spread)
	# Room near the edges limits the breeze smoothly, without clipped paper or wall bounces.
	var wind_room: float = minf(sway, minf(center_x - margin, extent.x - margin - center_x))
	var x: float = center_x + wind * wind_room * spread
	# Vary height independently of lifetime so paper does not fall as one strip.
	var apex: float = extent.y * (-0.06 + vertical_seed * 1.02)
	var flutter_rate: float = lerpf(4.2, 7.0, vertical_seed)
	var flutter_phase: float = t * flutter_rate + phase + sin(t * 1.7 + phase) * 0.38
	var y: float
	if t < rise_seconds:
		var launch_y: float = maxf(extent.y * (0.78 + seed_value * 0.20), apex + extent.y * 0.12)
		y = lerpf(launch_y, apex, 1.0 - pow(1.0 - rise, 2.0))
	else:
		# A brief acceleration becomes a slow terminal drift. The fall uses real
		# seconds, never a compressed chest/Pip performance window.
		var fall: float = clampf((t - rise_seconds) / (finish - delay - rise_seconds), 0.0, 1.0)
		var drift: float = (fall - 0.12 * (1.0 - exp(-fall / 0.12))) / (1.0 - 0.12 * (1.0 - exp(-1.0 / 0.12)))
		# Broadside paper catches air; the small lift vanishes at the apex and exit.
		drift += pow(sin(fall * PI), 2.0) * sin(flutter_phase) * 0.009
		y = lerpf(apex, extent.y + paper_edge, drift)
	var flutter: float = cos(flutter_phase)
	var pitch: float = cos(t * (2.3 + horizontal_seed * 1.4) + vertical_seed * TAU)
	var dimensions := Vector2(paper_size.x * maxf(0.12, absf(flutter)), paper_size.y * lerpf(0.52, 1.0, absf(pitch)))
	var direction: float = -1.0 if index % 2 == 0 else 1.0
	var bank: float = cos(t * wind_rate + phase) * 0.32 * spread
	var rotation: float = phase + direction * t * lerpf(0.75, 1.65, seed_value) + sin(flutter_phase * 0.62) * 0.48 + bank
	var bend: float = sin(flutter_phase + 0.65) * dimensions.y * 0.16
	# Turning faces change brightness continuously instead of snapping at each flip.
	var color: Color = COLORS[index % COLORS.size()].darkened(lerpf(0.24, 0.0, (flutter + 1.0) * 0.5))
	color = color.lerp(Color.WHITE, pow(maxf(flutter, 0.0), 4.0) * 0.08)
	return {"position": screen.position + Vector2(x, y), "size": dimensions,
		"rotation": rotation, "bend": bend, "color": color}


func _draw_strip(surface: Control, paper: Dictionary) -> void:
	var half: Vector2 = paper.size * 0.5
	var bend: float = float(paper.bend)
	var edge: float = half.y - absf(bend)
	# Bow the acquired rounded-square texture along the long paper axis. Both
	# halves share their fold edge and stay inside the reported rotated footprint.
	for side in range(2):
		var left: float = -half.x if side == 0 else 0.0
		var right: float = 0.0 if side == 0 else half.x
		var left_bend: float = 0.0 if side == 0 else bend
		var right_bend: float = bend if side == 0 else 0.0
		var points := PackedVector2Array([Vector2(left, -edge + left_bend), Vector2(right, -edge + right_bend),
			Vector2(right, edge + right_bend), Vector2(left, edge + left_bend)])
		var uv_left: float = float(side) * 0.25
		var uv_right: float = uv_left + 0.25
		var uvs := PackedVector2Array([Vector2(uv_left, 0.0), Vector2(uv_right, 0.0), Vector2(uv_right, 0.5), Vector2(uv_left, 0.5)])
		surface.draw_polygon(points, PackedColorArray([paper.color]), uvs, PAPER)


func _burst_region(item: Dictionary, screen: Rect2) -> Rect2:
	return Rect2(screen.position, Vector2(screen.size.x, screen.size.y / 3.0)) if item.small else screen


func _burst_count(item: Dictionary, screen: Rect2, unit: float) -> int:
	if not item.small:
		return _paper_count(screen, unit)
	var spacing: float = 80.0 * maxf(0.25, unit)
	var previous: int = clampi(roundi(ceili(_burst_region(item, screen).get_area() / (spacing * spacing)) / 3.0), 8, 24)
	return roundi(previous * 2.0 / 3.0)


func _burst_paper_state(item: Dictionary, index: int, screen: Rect2, unit: float) -> Dictionary:
	var region: Rect2 = _burst_region(item, screen)
	var paper: Dictionary = _paper_state(index, region, unit, float(item.age), float(item.variation))
	if paper.is_empty() or not item.small:
		return paper
	var half: Vector2 = Vector2(paper.size) * 0.5
	var angle: float = float(paper.rotation)
	var extent := Vector2(absf(cos(angle)) * half.x + absf(sin(angle)) * half.y,
		absf(sin(angle)) * half.x + absf(cos(angle)) * half.y)
	if not region.encloses(Rect2(Vector2(paper.position) - extent, extent * 2.0)):
		return {}
	paper.color.a *= clampf((SMALL_DURATION - float(item.age)) / 0.4, 0.0, 1.0)
	return paper


func draw_paper(surface: Control) -> void:
	var screen: Rect2 = screen_rect()
	var unit: float = 1.0 / Style.ui_scale(surface)
	for item: Dictionary in _bursts:
		for index in range(_burst_count(item, screen, unit)):
			var paper: Dictionary = _burst_paper_state(item, index, screen, unit)
			if paper.is_empty():
				continue
			surface.draw_set_transform(paper.position, paper.rotation)
			_draw_strip(surface, paper)
	surface.draw_set_transform(Vector2.ZERO)


func snapshot() -> Dictionary:
	var rect: Rect2 = screen_rect()
	var regions: Array = []
	var count: int = 0
	for item: Dictionary in _bursts:
		var region: Rect2 = _burst_region(item, rect)
		regions.append([region.position.x, region.position.y, region.size.x, region.size.y])
		count = maxi(count, _burst_count(item, rect, 1.0 / Style.ui_scale(_surface)))
	return {"active": is_active(), "visible": visible, "paused": _paused,
		"paper_count": count if is_active() else _paper_count(rect, 1.0 / Style.ui_scale(_surface)),
		"regions": regions,
		"ages": _bursts.map(func(item: Dictionary) -> float: return float(item.age)),
		"keys": _seen_keys.keys(), "screen_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}
