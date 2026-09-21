extends Control

const Style = preload("res://scripts/ui_style.gd")
const EDGE := Color("#2362d6")
const CURRENT := Color("#27cdff")
const CORE := Color("#f4ffff")
const PERIOD: float = 1.2

var active: bool = false
var reduced_motion: bool = false
var paused: bool = false
var phase: float = 0.0
var source: Control
var target: Control
var path := PackedVector2Array()
var _distance: float = 0.0
var _pixel: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(refresh_geometry)
	visibility_changed.connect(_update_processing)
	_update_processing()


func configure(first: Control, second: Control, reduce: bool, pause: bool) -> void:
	# Hint IDs can start with an already selected word. Always send energy from picture to word.
	if is_instance_valid(first) and first.get("card_data") != null and first.card_data.get("kind", "") == "word":
		var swap: Control = first
		first = second
		second = swap
	if source != first or target != second:
		for card in [source, target]:
			if is_instance_valid(card) and card.item_rect_changed.is_connected(refresh_geometry):
				card.item_rect_changed.disconnect(refresh_geometry)
		source = first
		target = second
		for card in [source, target]:
			if is_instance_valid(card):
				card.item_rect_changed.connect(refresh_geometry)
	active = is_instance_valid(source) and is_instance_valid(target) and source != target
	reduced_motion = reduce
	paused = pause
	visible = active and not paused
	refresh_geometry()
	_update_processing()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_update_processing()


func set_paused(value: bool) -> void:
	paused = value
	visible = active and not paused
	_update_processing()


func _update_processing() -> void:
	set_process(active and not reduced_motion and not paused and is_visible_in_tree())
	if reduced_motion:
		phase = 0.18
	elif is_processing():
		_sync_phase()
	queue_redraw()


func _sync_phase() -> void:
	phase = fposmod(float(Time.get_ticks_msec()) / 1000.0 / PERIOD, 1.0)


func _process(_delta: float) -> void:
	_sync_phase()
	queue_redraw()


func refresh_geometry() -> void:
	path.clear()
	_distance = 0.0
	_pixel = 1.0 / Style.ui_scale(self)
	if not active or not is_instance_valid(source) or not is_instance_valid(target):
		queue_redraw()
		return
	var transform: Transform2D = get_global_transform().affine_inverse()
	var a: Rect2 = transform * source.get_global_rect()
	var b: Rect2 = transform * target.get_global_rect()
	var direction: Vector2 = (b.get_center() - a.get_center()).normalized()
	if direction.is_zero_approx():
		queue_redraw()
		return
	# One direct strike on the center-to-center axis, including diagonal pairs.
	# Contacts sit just inside each card so even neighboring cards have a visible bolt.
	path = PackedVector2Array([_contact(a, direction), _contact(b, -direction)])
	_distance = path[0].distance_to(path[1])
	queue_redraw()


func _contact(bounds: Rect2, direction: Vector2) -> Vector2:
	var half_size: Vector2 = bounds.size * 0.5
	var edge_distance: float = minf(half_size.x / maxf(absf(direction.x), 0.0001),
		half_size.y / maxf(absf(direction.y), 0.0001))
	var inset: float = minf(18.0 * _pixel, minf(half_size.x, half_size.y) * 0.36)
	return bounds.get_center() + direction * maxf(0.0, edge_distance - inset)


func _noise(index: float, strike: float) -> float:
	# Local deterministic noise keeps the bolt sharp without touching gameplay's RNG.
	return fposmod(sin(index * 127.1 + strike * 311.7) * 43758.5453, 1.0) * 2.0 - 1.0


func _draw() -> void:
	if not active or _distance <= 0 or not is_instance_valid(source) or not is_instance_valid(target):
		return
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var cores := PackedColorArray()
	var direction: Vector2 = (path[1] - path[0]).normalized()
	var normal: Vector2 = direction.orthogonal()
	var segments: int = clampi(ceili(_distance / (10.0 * _pixel)), 5, 100)
	var amplitude: float = minf(9.0 * _pixel, _distance * 0.13)
	var strike: float = floorf(phase * 14.0)
	var surge: float = 0.5 + 0.5 * sin(phase * TAU * 2.0)
	for index in range(segments + 1):
		var along: float = float(index) / float(segments)
		var pin: float = minf(1.0, minf(along, 1.0 - along) * 8.0)
		var jag: float = _noise(float(index), strike) * amplitude * pin
		points.append(path[0].lerp(path[1], along) + normal * jag)
		var pulse: float = maxf(0.0, 1.0 - fposmod(phase * 2.0 - along, 1.0) / 0.2)
		colors.append(CURRENT.lerp(CORE, pulse))
		cores.append(Color(CORE, 0.72 + pulse * 0.28))
	# Short, changing forks and a white-hot core read as electricity, not a wavy wire.
	var fork_count: int = clampi(ceili(_distance / (120.0 * _pixel)), 1, 4)
	for fork in range(fork_count):
		var index: int = clampi(roundi(float(segments) * float(fork + 1) / float(fork_count + 1)), 1, segments - 1)
		var side: float = -1.0 if _noise(float(fork + 50), strike) < 0.0 else 1.0
		var reach: float = minf(_distance * 0.22, (16.0 + 9.0 * absf(_noise(float(fork + 80), strike))) * _pixel)
		var start: Vector2 = points[index]
		var fork_points := PackedVector2Array([start,
			start + direction * reach * 0.25 + normal * reach * side * 0.5,
			start + direction * reach * 0.55 + normal * reach * side * 0.38,
			start + direction * reach * 0.8 + normal * reach * side])
		draw_polyline(fork_points, Color(CURRENT, 0.16), 6.0 * _pixel, true)
		draw_polyline(fork_points, Color(EDGE, 0.75), 2.6 * _pixel, true)
		draw_polyline(fork_points, Color(CURRENT.lerp(CORE, 0.6), 0.9), 1.2 * _pixel, true)
	draw_polyline(points, Color(EDGE, 0.08), (15.0 + surge * 3.0) * _pixel, true)
	draw_polyline(points, Color(CURRENT, 0.2), (9.0 + surge * 2.0) * _pixel, true)
	draw_polyline(points, EDGE, 4.6 * _pixel, true)
	draw_polyline_colors(points, colors, 3.2 * _pixel, true)
	draw_polyline_colors(points, cores, (1.25 + surge * 0.35) * _pixel, true)
	for endpoint in path:
		draw_circle(endpoint, (8.0 + surge * 2.0) * _pixel, Color(CURRENT, 0.16))
		for ray in range(5):
			var angle: float = float(ray) * TAU / 5.0 + _noise(float(ray + 100), strike) * 0.4
			var ray_direction := Vector2.from_angle(angle)
			var ray_length: float = (6.0 + absf(_noise(float(ray + 120), strike)) * 6.0) * _pixel
			draw_line(endpoint + ray_direction * 4.0 * _pixel, endpoint + ray_direction * ray_length,
				CURRENT, 1.5 * _pixel, true)
		draw_circle(endpoint, 3.8 * _pixel, EDGE)
		draw_circle(endpoint, 2.8 * _pixel, CURRENT)
		draw_circle(endpoint, 1.6 * _pixel, CORE)
