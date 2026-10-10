extends Control
## A quiet segmented halo that charges when a fragment reaches the chest.

const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const FILL_SECONDS: float = 0.32
const PULSE_SECONDS: float = 0.55

var _filled: int = 0
var _required: int = 4
var _displayed: float = 0.0
var _from: float = 0.0
var _elapsed: float = PULSE_SECONDS
var _reduced: bool = false


func _init() -> void:
	name = "JellyChestProgress"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func reset() -> void:
	_filled = 0
	_required = 4
	settle()


func settle() -> void:
	_displayed = float(_filled)
	_from = _displayed
	_elapsed = PULSE_SECONDS
	queue_redraw()


func set_progress(filled: int, required: int, reduced: bool) -> void:
	var next_required: int = maxi(1, required)
	var next_filled: int = clampi(filled, 0, next_required)
	var increasing: bool = next_required == _required and next_filled > _filled
	var changed: bool = next_required != _required or next_filled != _filled
	if not changed and _reduced == reduced:
		return
	_reduced = reduced
	_required = next_required
	_filled = next_filled
	if _reduced or (changed and not increasing):
		settle()
	elif changed:
		_from = _displayed
		_elapsed = 0.0
	queue_redraw()


func advance(delta: float) -> void:
	if _reduced or not is_finite(delta) or delta <= 0.0 or _elapsed >= PULSE_SECONDS:
		return
	_elapsed = minf(PULSE_SECONDS, _elapsed + delta)
	_displayed = lerpf(_from, float(_filled), smoothstep(0.0, FILL_SECONDS, _elapsed))
	queue_redraw()


func _pulse() -> float:
	return sin(clampf(_elapsed / PULSE_SECONDS, 0.0, 1.0) * PI) if not _reduced and _elapsed < PULSE_SECONDS else 0.0


func _draw() -> void:
	var edge: float = minf(size.x, size.y)
	if edge <= 0.0:
		return
	var center: Vector2 = size * 0.5
	var radius: float = edge * 0.43
	var width: float = edge * 0.065
	var pulse: float = _pulse()
	# Reuse the chest's production light texture, with no idle shimmer or spin.
	if pulse > 0.0:
		draw_texture_rect(GLOW, Rect2(center - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false,
			Color("#ffdb7d", pulse * 0.60))
	var span: float = TAU / float(_required)
	var gap: float = 0.18
	for index in range(_required):
		var start: float = -PI * 0.5 + index * span + gap * 0.5
		var end: float = start + span - gap
		# A recessed track stays legible before the first fragment arrives.
		draw_arc(center, radius, start, end, 28, Color("#fffefa", 0.94), width * 1.8, true)
		draw_arc(center, radius, start, end, 28, Color("#a1b9a9", 0.62), width, true)
		var portion: float = clampf(_displayed - float(index), 0.0, 1.0)
		if portion <= 0.0:
			continue
		var tip: float = lerpf(start, end, portion)
		var color := Color("#d0a149") if _required > 4 else Color("#3f9b78")
		draw_arc(center, radius, start, tip, 28, color, width, true)
		draw_arc(center, radius - width * 0.16, start, tip, 28, Color("#fff0b2", 0.84), width * 0.28, true)
		if pulse > 0.0 and _displayed > float(index) and _displayed <= float(index + 1):
			var point: Vector2 = center + Vector2.from_angle(tip) * radius
			var light_size: float = edge * 0.14
			draw_texture_rect(GLOW, Rect2(point - Vector2.ONE * light_size * 0.5, Vector2.ONE * light_size), false,
				Color("#fff0a8", pulse * 0.90))


func snapshot() -> Dictionary:
	return {"filled": _filled, "required": _required, "displayed": _displayed,
		"pulse": _pulse(), "visible": is_visible_in_tree()}
