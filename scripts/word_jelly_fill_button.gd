extends Button
## An icon-only mode switch; the board owner advances its local running cue.

const Style = preload("res://scripts/ui_style.gd")
const CHEVRON = preload("res://assets/images/ui/controls/chevron-left.svg")
const LOCK = preload("res://assets/images/ui/controls/lock.svg")
const GEL = preload("res://assets/images/jelly-match/gel-mint.png")
const SKY = preload("res://assets/images/jelly-match/gel-sky.png")
const GEL_REGION := Rect2(11, 34, 298, 252)
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const FLOW_SECONDS: float = 1.4
const SWITCH_SECONDS: float = 0.16

var _on := false
var _locked := false
var _paused := false
var _reduced_motion := false
var _ui_scale := 1.0
var _elapsed := 0.0
var _blend := 0.0
var _down := false
var _panel := StyleBoxFlat.new()
var _track := StyleBoxFlat.new()
var _focus := StyleBoxFlat.new()


func _init() -> void:
	text = ""
	tooltip_text = ""
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for event: Signal in [resized, focus_entered, focus_exited, mouse_entered, mouse_exited]:
		event.connect(queue_redraw)
	button_down.connect(func() -> void: _down = true; queue_redraw())
	button_up.connect(func() -> void: _down = false; queue_redraw())
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_down = false)
	set_ui_scale(1.0)
	set_state(false, false)


func set_state(enabled: bool, locked: bool, reduced: bool = false) -> void:
	_on = enabled
	_locked = locked
	_reduced_motion = reduced
	set_pressed_no_signal(enabled)
	if reduced or locked or _paused:
		_blend = 1.0 if enabled else 0.0
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	set("accessibility_name", "Auto fill. %s.%s" % ["On" if enabled else "Off",
		" Required in Challenge." if locked else " Automatically drop supply into every vacancy."])
	queue_redraw()


func set_reduced_motion(value: bool) -> void:
	set_state(_on, _locked, value)


func set_ui_scale(value: float) -> void:
	_ui_scale = maxf(0.1, value)
	custom_minimum_size = Vector2(88.0, 44.0) / _ui_scale
	queue_redraw()


func pause_feedback(value: bool) -> void:
	_paused = value
	if value:
		_blend = 1.0 if _on else 0.0
		_down = false
	queue_redraw()


func reset() -> void:
	_elapsed = 0.0
	_blend = 1.0 if _on else 0.0
	_down = false
	queue_redraw()


func advance(delta: float) -> void:
	if _paused or _reduced_motion or not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	var target: float = 1.0 if _on else 0.0
	if not _on and is_equal_approx(_blend, target):
		return
	_blend = move_toward(_blend, target, delta / SWITCH_SECONDS)
	if _on:
		_elapsed += delta
	queue_redraw()


func _layout() -> Dictionary:
	var unit: float = 1.0 / _ui_scale
	var center: Vector2 = size * 0.5
	return {
		"icon": Rect2(center + Vector2(-34.0, -16.0) * unit, Vector2(30.0, 32.0) * unit),
		"track": Rect2(center + Vector2(8.0, -9.0) * unit, Vector2(28.0, 18.0) * unit)
	}


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var unit: float = 1.0 / _ui_scale
	var layout: Dictionary = _layout()
	var icon: Rect2 = layout.icon
	var track: Rect2 = layout.track
	var fill: Color = Color("#dff5e8") if _on else Style.SURFACE
	if is_hovered() and not disabled:
		fill = fill.lightened(0.06) if _on else Style.PAPER
	_panel.bg_color = fill
	_panel.border_color = Color("#61b78f") if _on else Style.EDGE
	_panel.set_border_width_all(maxi(1, roundi((2.0 if _on else 1.0) * unit)))
	_panel.set_corner_radius_all(maxi(1, roundi(13.0 * unit)))
	_panel.shadow_color = Color("#48775c", 0.14)
	_panel.shadow_size = roundi(2.0 * unit)
	_panel.shadow_offset = Vector2(0.0, unit)
	draw_style_box(_panel, Rect2(Vector2.ONE * unit, size - Vector2.ONE * 2.0 * unit))
	var pulse: float = 0.5 if _reduced_motion else 0.5 + 0.5 * sin(_elapsed * TAU / 2.8)
	if _on:
		draw_texture_rect(GLOW, icon.grow(2.0 * unit), false, Color("#77e8b3", 0.28 + pulse * 0.22))
	var tint: Color = Style.GOOD if _on else Style.MUTED
	tint.a = 1.0 if _on else 0.65
	var press: Vector2 = Vector2(0.0, unit) if _down and not disabled else Vector2.ZERO
	for index in range(2):
		var phase: float = fposmod(_elapsed / FLOW_SECONDS + index * 0.5, 1.0) if _on and not _reduced_motion else 0.18 + index * 0.48
		var alpha: float = sin(phase * PI) if _on and not _reduced_motion else 0.75
		var center := Vector2(icon.get_center().x, icon.position.y + (7.0 + phase * 12.0) * unit) + press
		draw_set_transform(center, -PI * 0.5)
		draw_texture_rect(CHEVRON, Rect2(Vector2.ONE * -13.0 * unit, Vector2.ONE * 26.0 * unit),
			false, Color(tint, alpha * tint.a))
		draw_set_transform(Vector2.ZERO)
	var gel_tint := Color.WHITE if _on else Color("#cbd8cf", 0.72)
	var back_size := Vector2(16.0, 16.0 * GEL_REGION.size.y / GEL_REGION.size.x) * unit
	var front_size := Vector2(21.0, 21.0 * GEL_REGION.size.y / GEL_REGION.size.x) * unit
	draw_texture_rect_region(SKY, Rect2(Vector2(icon.get_center().x - 3.0 * unit,
		icon.end.y - back_size.y - 3.0 * unit) + press, back_size), GEL_REGION, gel_tint)
	draw_texture_rect_region(GEL, Rect2(Vector2(icon.get_center().x - 12.0 * unit,
		icon.end.y - front_size.y) + press, front_size), GEL_REGION, gel_tint)
	_track.bg_color = Style.GOOD if _on else Color("#dbe2d8")
	_track.set_corner_radius_all(maxi(1, roundi(9.0 * unit)))
	draw_style_box(_track, track)
	var thumb := Vector2(lerpf(track.position.x + 9.0 * unit, track.end.x - 9.0 * unit, _blend), track.get_center().y)
	draw_circle(thumb + Vector2(0.0, unit), 6.0 * unit, Color("#244738", 0.14))
	draw_circle(thumb, 6.0 * unit, Color.WHITE if _on else Style.SURFACE)
	if _locked:
		draw_texture_rect(LOCK, Rect2(thumb - Vector2.ONE * 5.0 * unit, Vector2.ONE * 10.0 * unit), false, Style.GOOD)
	if _on and not _reduced_motion:
		for index in range(2):
			var phase: float = fposmod(_elapsed / FLOW_SECONDS + 0.5 * index, 1.0)
			var point := Vector2(icon.position.x + (2.0 if index == 0 else 28.0) * unit,
				icon.position.y + (3.0 + phase * 24.0) * unit)
			draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * 3.0 * unit, Vector2.ONE * 6.0 * unit),
				false, Color("#faffed", sin(phase * PI) * 0.85))
	if has_focus() and not disabled:
		_focus.bg_color = Color.TRANSPARENT
		_focus.border_color = Style.GOOD
		_focus.set_border_width_all(maxi(1, roundi(2.0 * unit)))
		_focus.set_corner_radius_all(maxi(1, roundi(14.0 * unit)))
		draw_style_box(_focus, Rect2(Vector2.ZERO, size))


func snapshot() -> Dictionary:
	var layout: Dictionary = _layout()
	var track: Rect2 = layout.track
	var icon: Rect2 = layout.icon
	return {"on": _on, "locked": _locked, "paused": _paused, "reduced_motion": _reduced_motion,
		"elapsed": _elapsed, "flowing": _on and not _paused and not _reduced_motion and is_visible_in_tree(),
		"icon_only": text.is_empty(), "glow": _on,
		"thumb_x": lerpf(track.position.x + 9.0 / _ui_scale, track.end.x - 9.0 / _ui_scale, _blend),
		"icon_rect": [icon.position.x, icon.position.y, icon.size.x, icon.size.y],
		"track_rect": [track.position.x, track.position.y, track.size.x, track.size.y]}
