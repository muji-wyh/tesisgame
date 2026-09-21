extends Control

const Style = preload("res://scripts/ui_style.gd")
const EDGE := Color("#147ca8")
const CURRENT := Color("#2ddcff")
const CORE := Color("#efffff")
const PERIOD: float = 1.4

var active: bool = false
var reduced_motion: bool = false
var paused: bool = false
var phase: float = 0.0
var source: Control
var target: Control
var path := PackedVector2Array()
var _split_columns: bool = true
var _lengths := PackedFloat32Array()
var _distance: float = 0.0
var _gap: float = 10.0
var _pixel: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(refresh_geometry)
	visibility_changed.connect(_update_processing)
	_update_processing()


func configure(first: Control, second: Control, split_columns: bool, reduce: bool, pause: bool) -> void:
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
	_split_columns = split_columns
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
	_lengths.clear()
	_distance = 0.0
	_pixel = 1.0 / Style.ui_scale(self)
	if not active or not is_instance_valid(source) or not is_instance_valid(target):
		queue_redraw()
		return
	var transform: Transform2D = get_global_transform().affine_inverse()
	var a: Rect2 = transform * source.get_global_rect()
	var b: Rect2 = transform * target.get_global_rect()
	var route := PackedVector2Array()
	if _split_columns:
		_gap = maxf(1.0, b.position.x - a.end.x)
		var lane: float = (a.end.x + b.position.x) * 0.5
		route = PackedVector2Array([
			Vector2(a.end.x, a.get_center().y), Vector2(lane, a.get_center().y),
			Vector2(lane, b.get_center().y), Vector2(b.position.x, b.get_center().y)
		])
	else:
		_gap = maxf(1.0, b.position.y - a.end.y)
		var lane: float = (a.end.y + b.position.y) * 0.5
		route = PackedVector2Array([
			Vector2(a.get_center().x, a.end.y), Vector2(a.get_center().x, lane),
			Vector2(b.get_center().x, lane), Vector2(b.get_center().x, b.position.y)
		])
	# Coincident lane turns collapse when the suggested pair is directly opposite.
	for point in route:
		if path.is_empty() or path[-1].distance_squared_to(point) > 0.001:
			path.append(point)
	_lengths.append(0.0)
	for index in range(1, path.size()):
		_distance += path[index - 1].distance_to(path[index])
		_lengths.append(_distance)
	queue_redraw()


func _point_at(distance: float) -> Vector2:
	for index in range(1, _lengths.size()):
		if _lengths[index] >= distance:
			var segment: float = _lengths[index] - _lengths[index - 1]
			return path[index - 1].lerp(path[index], (distance - _lengths[index - 1]) / maxf(segment, 0.001))
	return path[-1]


func _draw() -> void:
	if not active or _distance <= 0 or not is_instance_valid(source) or not is_instance_valid(target):
		return
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var cores := PackedColorArray()
	var segments: int = clampi(ceili(_distance / (6.0 * _pixel)), 8, 160)
	var amplitude: float = minf(1.4 * _pixel, _gap * 0.12)
	for index in range(segments + 1):
		var along: float = float(index) / float(segments)
		var distance: float = along * _distance
		var tangent: Vector2 = (_point_at(minf(_distance, distance + _pixel)) - _point_at(maxf(0, distance - _pixel))).normalized()
		var wave: float = sin(float(index) * 2.3 + phase * TAU * 3.0) * 0.65 + sin(float(index) * 3.7 - phase * TAU * 2.0) * 0.35
		var pin: float = minf(1.0, minf(distance, _distance - distance) / (4.0 * _pixel))
		points.append(_point_at(distance) + tangent.orthogonal() * wave * amplitude * pin)
		var pulse: float = maxf(0.0, 1.0 - fposmod(phase - along, 1.0) / 0.24)
		colors.append(CURRENT.lerp(CORE, pulse))
		cores.append(Color(CORE, 0.25 + pulse * 0.75))
	# The arc runs through the gutter, not across other pictures or words.
	draw_polyline(points, Color(CURRENT, 0.22), minf(8.0 * _pixel, _gap * 0.58), true)
	draw_polyline(points, EDGE, minf(4.0 * _pixel, _gap * 0.4), true)
	draw_polyline_colors(points, colors, minf(2.7 * _pixel, _gap * 0.28), true)
	draw_polyline_colors(points, cores, minf(1.2 * _pixel, _gap * 0.15), true)
	for endpoint in [path[0], path[-1]]:
		draw_circle(endpoint, 5.0 * _pixel, Color(CURRENT, 0.2))
		draw_circle(endpoint, 3.2 * _pixel, EDGE)
		draw_circle(endpoint, 2.3 * _pixel, CURRENT)
		draw_circle(endpoint, 1.1 * _pixel, CORE)
