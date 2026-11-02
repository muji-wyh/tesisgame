extends Button
## An icon-only mode switch; the board owner advances its local running cue.

const CHEVRON = preload("res://assets/images/ui/controls/chevron-left.svg")
const LOCK = preload("res://assets/images/ui/controls/lock.svg")
const GEL = preload("res://assets/images/jelly-match/gel-mint.png")
const SKY = preload("res://assets/images/jelly-match/gel-sky.png")
const GEL_REGION := Rect2(11, 34, 298, 252)
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
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
	custom_minimum_size = Vector2(56.0, 44.0) / _ui_scale
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
	var icon := Rect2((size - Vector2(44.0, 36.0) * unit) * 0.5, Vector2(44.0, 36.0) * unit)
	return {
		"icon": icon,
		"flow": Rect2(icon.position, Vector2(14.0, 36.0) * unit),
		"surface": Rect2(Vector2.ZERO, size)
	}


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var unit: float = 1.0 / _ui_scale
	var layout: Dictionary = _layout()
	var icon: Rect2 = layout.icon
	var flow: Rect2 = layout.flow
	var surface: Rect2 = layout.surface
	var fill: Color = Color("#fffaf0").lerp(Color("#c2ead2"), _blend)
	if is_hovered() and not disabled:
		fill = fill.lightened(0.04)
	if _down and not disabled:
		fill = fill.darkened(0.04)
	_panel.bg_color = fill
	_panel.border_color = Color("#438068") if has_focus() and not disabled \
		else Color("#86b99b") if _on else Color("#d4dfd4")
	_panel.set_border_width_all(maxi(1, roundi((2.0 if has_focus() and not disabled else 1.0) * unit)))
	_panel.set_corner_radius_all(maxi(1, roundi(12.0 * unit)))
	_panel.shadow_color = Color("#386345", 0.10)
	_panel.shadow_size = roundi(unit)
	_panel.shadow_offset = Vector2(0.0, unit)
	draw_style_box(_panel, surface)
	var pulse: float = 0.5 if _reduced_motion else 0.5 + 0.5 * sin(_elapsed * TAU / 2.8)
	if _on:
		draw_texture_rect(GLOW, icon.grow(2.0 * unit), false, Color("#77d69e", 0.12 + pulse * 0.06))
	var press: Vector2 = Vector2(0.0, unit) if _down and not disabled else Vector2.ZERO
	var phase: float = fposmod(_elapsed / FLOW_SECONDS, 1.0) if _on and not _reduced_motion else 0.5
	var tint: Color = Color("#286f4c") if _on else Color("#71978a")
	if _locked:
		draw_texture_rect(LOCK, Rect2(flow.position + Vector2(0.0, 10.0) * unit,
			Vector2.ONE * 14.0 * unit), false, tint)
	else:
		var center := flow.position + Vector2(7.0, 11.0 + phase * 12.0 if _on else 18.0) * unit + press
		draw_set_transform(center, -PI * 0.5)
		draw_texture_rect(CHEVRON, Rect2(Vector2.ONE * -11.0 * unit, Vector2.ONE * 22.0 * unit),
			false, Color(tint, 0.55 + 0.45 * sin(phase * PI) if _on else 1.0))
		draw_set_transform(Vector2.ZERO)
	var cell_size := Vector2(14.0, 14.0 * GEL_REGION.size.y / GEL_REGION.size.x) * unit
	for index in range(2):
		var at: Vector2 = icon.position + Vector2(12.0 + index * 16.0, 24.0) * unit + press
		draw_texture_rect_region(GEL if _on else SKY, Rect2(at, cell_size), GEL_REGION)
	var incoming_size := Vector2(24.0, 24.0 * GEL_REGION.size.y / GEL_REGION.size.x) * unit
	var incoming_at := icon.position + Vector2(18.0, phase * 14.0 if _on else 0.0) * unit + press
	draw_texture_rect_region(GEL if _on else SKY, Rect2(incoming_at, incoming_size), GEL_REGION,
		Color(1.0, 1.0, 1.0, 0.45 + 0.55 * sin(phase * PI) if _on else 1.0))


func snapshot() -> Dictionary:
	var layout: Dictionary = _layout()
	var surface: Rect2 = layout.surface
	var icon: Rect2 = layout.icon
	return {"on": _on, "locked": _locked, "paused": _paused, "reduced_motion": _reduced_motion,
		"elapsed": _elapsed, "flowing": _on and not _paused and not _reduced_motion and is_visible_in_tree(),
		"icon_only": text.is_empty(), "glow": _on, "unified_switch": true,
		"stationary_icon": true, "switch_blend": _blend,
		"icon_rect": [icon.position.x, icon.position.y, icon.size.x, icon.size.y],
		"surface_rect": [surface.position.x, surface.position.y, surface.size.x, surface.size.y]}
