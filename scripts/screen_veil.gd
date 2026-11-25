extends Control
## Non-blocking warm-paper transition veil for gentle screen handoffs.
## Logical visibility and focus always switch immediately; this layer only smooths perception.

const Style = preload("res://scripts/ui_style.gd")
const DURATION: float = 0.22

var reduced_motion: bool = false
var _elapsed: float = DURATION
var _tint: Color = Style.PAPER
var _active: bool = false


func _init() -> void:
	name = "ScreenVeil"
	z_index = 220
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process(false)
	hide()


func pulse(tint: Color = Style.PAPER) -> void:
	if reduced_motion or not is_inside_tree():
		finish()
		return
	_tint = Color(tint.r, tint.g, tint.b, 1.0)
	_elapsed = 0.0
	_active = true
	show()
	set_process(true)
	queue_redraw()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled:
		finish()


func finish() -> void:
	_active = false
	_elapsed = DURATION
	set_process(false)
	hide()


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	if not _active or not is_finite(delta) or delta <= 0.0:
		return
	_elapsed = minf(DURATION, _elapsed + minf(delta, 0.05))
	if _elapsed >= DURATION:
		finish()
		return
	queue_redraw()


func _draw() -> void:
	if not _active or size.x <= 0.0 or size.y <= 0.0:
		return
	var p: float = clampf(_elapsed / DURATION, 0.0, 1.0)
	# Ease out smoothly from a soft 0.56 warm veil to fully transparent.
	var alpha: float = (1.0 - p) * (1.0 - p) * 0.56
	if alpha > 0.004:
		draw_rect(Rect2(Vector2.ZERO, size), Color(_tint.r, _tint.g, _tint.b, alpha))


func snapshot() -> Dictionary:
	return {"active": _active, "elapsed": _elapsed, "duration": DURATION, "reduced_motion": reduced_motion}
