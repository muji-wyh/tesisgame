extends Control

const Style = preload("res://scripts/ui_style.gd")
const EDGE := Color("#147ca8")
const CURRENT := Color("#2ddcff")
const CORE := Color("#efffff")
const PERIOD: float = 1.65

var active: bool = false
var reduced_motion: bool = false
var paused: bool = false
var corner_radius: float = 20.0
var phase: float = 0.0
var _outline := PackedVector2Array()
var _lengths := PackedFloat32Array()
var _perimeter: float = 0.0
var _pixel: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild_path)
	visibility_changed.connect(_update_processing)
	_rebuild_path()
	_update_processing()


func configure(enabled: bool, reduce: bool, radius: float) -> void:
	active = enabled
	reduced_motion = reduce
	corner_radius = radius
	visible = active
	_rebuild_path()
	_update_processing()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_update_processing()


func set_paused(value: bool) -> void:
	paused = value
	_update_processing()


func _update_processing() -> void:
	set_process(active and not reduced_motion and not paused and is_visible_in_tree())
	if reduced_motion:
		phase = 0.12
	elif is_processing():
		_sync_phase()
	queue_redraw()


func _sync_phase() -> void:
	# One shared clock keeps both members of a hinted pair conducting together.
	phase = fposmod(float(Time.get_ticks_msec()) / 1000.0 / PERIOD, 1.0)


func _process(_delta: float) -> void:
	_sync_phase()
	queue_redraw()


func _rebuild_path() -> void:
	_pixel = 1.0 / Style.ui_scale(self)
	_outline.clear()
	_lengths.clear()
	_perimeter = 0.0
	var inset: float = 4.0 * _pixel
	var bounds := Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
	var radius: float = clampf(corner_radius - inset, 1.0, minf(bounds.size.x, bounds.size.y) * 0.5)
	var centers: Array[Vector2] = [
		Vector2(bounds.end.x - radius, bounds.position.y + radius),
		bounds.end - Vector2.ONE * radius,
		Vector2(bounds.position.x + radius, bounds.end.y - radius),
		bounds.position + Vector2.ONE * radius
	]
	for corner in range(4):
		for step in range(13):
			var angle: float = -PI * 0.5 + float(corner) * PI * 0.5 + float(step) * PI / 24.0
			_outline.append(centers[corner] + Vector2.from_angle(angle) * radius)
	_outline.append(_outline[0])
	_lengths.append(0.0)
	for index in range(1, _outline.size()):
		_perimeter += _outline[index - 1].distance_to(_outline[index])
		_lengths.append(_perimeter)
	queue_redraw()


func _point_at(fraction: float) -> Vector2:
	var distance: float = fposmod(fraction, 1.0) * _perimeter
	for index in range(1, _lengths.size()):
		if _lengths[index] >= distance:
			var segment: float = _lengths[index] - _lengths[index - 1]
			return _outline[index - 1].lerp(_outline[index], (distance - _lengths[index - 1]) / maxf(segment, 0.001))
	return _outline[0]


func _draw() -> void:
	if not active or _perimeter <= 0.0:
		return
	# A narrow luminous circuit stays at the edge, leaving all learning content clear.
	draw_polyline(_outline, Color(CURRENT, 0.13), 8.0 * _pixel, true)
	draw_polyline(_outline, Color(EDGE, 0.72), 2.4 * _pixel, true)
	draw_polyline(_outline, Color(CURRENT, 0.75), 1.0 * _pixel, true)
	for offset in [0.0, 0.5]:
		_draw_current(phase + offset)


func _draw_current(head: float) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var glow_colors := PackedColorArray()
	var segments: int = 30
	for index in range(segments + 1):
		var strength: float = float(index) / float(segments)
		var along: float = head - (1.0 - strength) * 0.23
		var point: Vector2 = _point_at(along)
		var tangent: Vector2 = (_point_at(along + 0.001) - _point_at(along - 0.001)).normalized()
		# Fine angular crackle gives the travelling pulse an electrical edge.
		var crackle: float = sin(float(index) * 2.4 + phase * TAU * 5.0) * sin(strength * PI) * 1.5 * _pixel
		points.append(point + tangent.orthogonal() * crackle)
		colors.append(Color(CURRENT.lerp(CORE, strength), strength))
		glow_colors.append(Color(CURRENT, strength * 0.38))
	draw_polyline_colors(points, glow_colors, 7.0 * _pixel, true)
	draw_polyline_colors(points, colors, 2.2 * _pixel, true)
	var tip: Vector2 = _point_at(head)
	draw_circle(tip, 4.5 * _pixel, Color(CURRENT, 0.20))
	draw_circle(tip, 2.0 * _pixel, CORE)
	var tangent: Vector2 = (_point_at(head + 0.002) - _point_at(head - 0.002)).normalized()
	var inward: Vector2 = tangent.orthogonal()
	var spark := PackedVector2Array([
		tip - tangent * 7.0 * _pixel,
		tip - tangent * 3.0 * _pixel + inward * 3.0 * _pixel,
		tip + tangent * 1.0 * _pixel - inward * 2.0 * _pixel,
		tip + tangent * 5.0 * _pixel
	])
	draw_polyline(spark, CURRENT, 3.5 * _pixel, true)
	draw_polyline(spark, CORE, 1.2 * _pixel, true)
