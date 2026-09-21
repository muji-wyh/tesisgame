extends Control

const Style = preload("res://scripts/ui_style.gd")
const PERIOD: float = 1.2

var active: bool = false
var reduced_motion: bool = false
var paused: bool = false
var phase: float = 0.0
var source: Control
var target: Control
var path := PackedVector2Array()
var colors: Dictionary = Style.hint_palette({})
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


func set_palette(palette: Dictionary) -> void:
	var next_colors: Dictionary = Style.hint_palette(palette)
	if colors != next_colors:
		colors = next_colors
		queue_redraw()


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
	var currents := PackedColorArray()
	var cores := PackedColorArray()
	var direction: Vector2 = (path[1] - path[0]).normalized()
	var normal: Vector2 = direction.orthogonal()
	var segments: int = clampi(ceili(_distance / (12.0 * _pixel)), 5, 100)
	var amplitude: float = minf(14.0 * _pixel, _distance * 0.17)
	var strike: float = floorf(phase * 18.0)
	var surge: float = 0.5 + 0.5 * sin(phase * TAU * 2.0)
	for index in range(segments + 1):
		var along: float = float(index) / float(segments)
		var pin: float = minf(1.0, minf(along, 1.0 - along) * 8.0)
		var jag: float = _noise(float(index), strike) * amplitude * pin
		points.append(path[0].lerp(path[1], along) + normal * jag)
		var pulse: float = maxf(0.0, 1.0 - fposmod(phase * 2.0 - along, 1.0) / 0.2)
		currents.append(colors.current.lerp(colors.core, pulse * 0.75))
		cores.append(Color(colors.core, 0.8 + pulse * 0.2))
	_draw_forks(points, direction, normal, strike)
	# Two thinner filaments split off and rejoin the main strike, adding depth and energy.
	for side in [-1.0, 1.0]:
		var filament := PackedVector2Array()
		for index in range(points.size()):
			var along: float = float(index) / float(segments)
			var pin: float = minf(1.0, minf(along, 1.0 - along) * 6.0)
			var offset: float = (7.0 + _noise(float(index + 180), strike + side) * 5.0) * _pixel * pin
			filament.append(points[index] + normal * side * offset)
		draw_polyline(filament, Color(colors.current, 0.15), 6.0 * _pixel, true)
		draw_polyline(filament, Color(colors.current, 0.75), 2.0 * _pixel, true)
		draw_polyline(filament, Color(colors.core, 0.7), 0.8 * _pixel, true)
	# Keep the glow local to the strike while giving its white-hot core a stronger pulse.
	draw_polyline(points, Color(colors.current, 0.09), (23.0 + surge * 4.0) * _pixel, true)
	draw_polyline(points, Color(colors.current, 0.22), (13.0 + surge * 3.0) * _pixel, true)
	draw_polyline(points, colors.edge, (6.4 + surge * 0.8) * _pixel, true)
	draw_polyline_colors(points, currents, (4.8 + surge * 0.8) * _pixel, true)
	draw_polyline_colors(points, cores, (2.0 + surge * 0.65) * _pixel, true)
	# Bright packets race along the actual jagged bolt from picture to word.
	for packet in range(2):
		var along: float = fposmod(phase * 2.0 + float(packet) * 0.5, 1.0)
		var position: float = along * float(segments)
		var index: int = mini(floori(position), segments - 1)
		var center: Vector2 = points[index].lerp(points[index + 1], position - float(index))
		var flare: float = minf(1.0, minf(along, 1.0 - along) * 8.0)
		var radius: float = (4.0 + surge * 3.0) * _pixel * flare
		draw_circle(center, radius * 1.6, Color(colors.spark, 0.22))
		draw_line(center - direction * radius * 1.4, center + direction * radius * 1.4, colors.core, 2.6 * _pixel, true)
		draw_line(center - normal * radius, center + normal * radius, colors.spark, 2.0 * _pixel, true)
		draw_circle(center, 2.1 * _pixel, colors.core)
	for endpoint in path:
		_draw_contact(endpoint, surge, strike)


func _draw_forks(points: PackedVector2Array, direction: Vector2, normal: Vector2, strike: float) -> void:
	var segments: int = points.size() - 1
	var fork_count: int = clampi(ceili(_distance / (85.0 * _pixel)), 2, 6)
	for fork in range(fork_count):
		var index: int = clampi(roundi(float(segments) * float(fork + 1) / float(fork_count + 1)), 1, segments - 1)
		var side: float = -1.0 if _noise(float(fork + 50), strike) < 0.0 else 1.0
		var reach: float = minf(_distance * 0.28, (25.0 + 17.0 * absf(_noise(float(fork + 80), strike))) * _pixel)
		var start: Vector2 = points[index]
		var fork_points := PackedVector2Array([start,
			start + direction * reach * 0.25 + normal * reach * side * 0.5,
			start + direction * reach * 0.55 + normal * reach * side * 0.38,
			start + direction * reach * 0.8 + normal * reach * side])
		var tint: Color = colors.current if fork % 2 == 0 else colors.spark
		draw_polyline(fork_points, Color(tint, 0.16), 8.0 * _pixel, true)
		draw_polyline(fork_points, colors.edge, 3.6 * _pixel, true)
		draw_polyline(fork_points, tint, 2.4 * _pixel, true)
		draw_polyline(fork_points, Color(colors.core, 0.9), 1.0 * _pixel, true)
		var twig := PackedVector2Array([fork_points[1],
			fork_points[1] - direction * reach * 0.3 + normal * reach * side * 0.18,
			fork_points[1] - direction * reach * 0.45 + normal * reach * side * 0.42])
		draw_polyline(twig, Color(tint, 0.85), 1.5 * _pixel, true)


func _draw_contact(endpoint: Vector2, surge: float, strike: float) -> void:
	draw_circle(endpoint, (12.0 + surge * 4.0) * _pixel, Color(colors.current, 0.2))
	var ring: float = fposmod(phase * 2.0, 1.0)
	draw_arc(endpoint, (9.0 + ring * 12.0) * _pixel, 0, TAU, 24,
		Color(colors.current, (1.0 - ring) * 0.65), 1.5 * _pixel, true)
	for ray in range(9):
		var angle: float = float(ray) * TAU / 9.0 + _noise(float(ray + 100), strike) * 0.45
		var ray_direction := Vector2.from_angle(angle)
		var ray_length: float = (10.0 + absf(_noise(float(ray + 120), strike)) * 13.0) * _pixel
		var spark := PackedVector2Array([endpoint + ray_direction * 5.0 * _pixel,
			endpoint + ray_direction * ray_length * 0.65 + ray_direction.orthogonal() * 2.0 * _pixel,
			endpoint + ray_direction * ray_length])
		var tint: Color = colors.current if ray % 2 == 0 else colors.spark
		draw_polyline(spark, Color(tint, 0.2), 5.0 * _pixel, true)
		draw_polyline(spark, tint, 1.8 * _pixel, true)
	draw_circle(endpoint, 5.0 * _pixel, colors.edge)
	draw_circle(endpoint, 3.8 * _pixel, colors.current)
	draw_circle(endpoint, 2.4 * _pixel, colors.core)
