extends Control
## Persistent stage progress and a brief, input-transparent stage arrival.

const Style = preload("res://scripts/ui_style.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const STAR = preload("res://assets/images/ui/jelly-goals/star.webp")
const CLOCK = preload("res://assets/images/ui/jelly-goals/clock.webp")
const DURATION: float = 1.8
const READY_SECONDS: float = 0.82
const STAR_LOSS_SECONDS: float = 0.60
var reduced_motion: bool = false
var _state: Dictionary = {}
var _label: Label
var _title: Label
var _detail: Label
var _card := Control.new()
var _badge := Rect2()
var _scale: float = 1.0
var _elapsed: float = DURATION
var _card_duration: float = DURATION
var _entry: bool = false
var _time_bonus_remaining: float = 0.0
var _time_bonus: float = 0.0
var _star_loss_elapsed: Array[float] = [STAR_LOSS_SECONDS, STAR_LOSS_SECONDS, STAR_LOSS_SECONDS]


func _init() -> void:
	name = "JellyStageProgress"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 35
	_label = Style.label("", 15)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.z_index = 30
	_card.draw.connect(_draw_card)
	add_child(_card)
	_title = Style.label("", 28)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_title)
	_detail = Style.label("", 14)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_detail)
	hide()


func set_stage(state: Dictionary, celebrate: bool = false) -> void:
	if _state == state and not celebrate:
		return
	var same_stage: bool = not celebrate and state.get("kind") == "main" and _state.get("kind") == "main" \
		and state.get("number") == _state.get("number")
	if not same_stage or reduced_motion:
		_star_loss_elapsed.fill(STAR_LOSS_SECONDS)
	elif state.get("outcome", "") in ["", "timeout"]:
		for index in range(clampi(int(state.get("stars_now", 0)), 0, 3), clampi(int(_state.get("stars_now", 0)), 0, 3)):
			_star_loss_elapsed[index] = 0.0
	_state = state.duplicate(true)
	visible = int(state.get("number", 0)) > 0 or state.get("kind") == "challenge"
	_update_label()
	set("accessibility_name", _label.text)
	if celebrate:
		_elapsed = 0.0
		_card_duration = DURATION
		_entry = not state.get("complete", false) and state.get("kind", "") in ["main", "challenge"]
		if state.get("kind") == "challenge":
			_title.text = "Challenge"
			_detail.text = "Stage %d" % int(state.get("challenge_stage", 1))
		else:
			_title.text = "All words mastered!" if state.get("complete", false) else "Stage %d" % state.number
			_detail.text = "Beautiful work!" if state.get("complete", false) else "%d word goals" % state.total \
				if state.get("kind") == "main" else "%d new words to master" % state.total
			if state.get("objective", "") == "boss":
				_detail.text = "Word goals + Boss"
	_refresh_motion()
	queue_redraw()


func reset() -> void:
	_state.clear()
	_elapsed = DURATION
	_card_duration = DURATION
	_entry = false
	_time_bonus_remaining = 0.0
	_star_loss_elapsed.fill(STAR_LOSS_SECONDS)
	hide()
	_card.hide()


func dismiss() -> void:
	_elapsed = DURATION
	_entry = false
	_refresh_motion()


func entry_active() -> bool:
	return _entry and visible and _elapsed < DURATION


func ready_pending() -> bool:
	return _entry and visible and _elapsed < READY_SECONDS


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_time_bonus_remaining = maxf(0.0, _time_bonus_remaining - delta)
	for index in range(3):
		_star_loss_elapsed[index] = minf(STAR_LOSS_SECONDS, _star_loss_elapsed[index] + delta)
	if _elapsed < _card_duration:
		_elapsed = minf(_card_duration, _elapsed + delta)
		_refresh_motion()
	queue_redraw()


func present_time_bonus(seconds: float) -> void:
	_time_bonus = seconds
	_time_bonus_remaining = 1.0
	queue_redraw()


func present_stage_clear(seconds: float) -> void:
	_entry = false
	_elapsed = 0.0
	_card_duration = seconds
	_title.text = "Stage clear!"
	_detail.text = "Wonderful work!"
	_title.add_theme_color_override("font_color", Style.GOOD)
	_refresh_motion()
	queue_redraw()


func configure_layout(badge: Rect2, board: Rect2, ui_scale: float) -> void:
	_scale = maxf(0.1, ui_scale)
	_badge = badge
	_label.add_theme_font_size_override("font_size", ceili(14.0 / _scale))
	_update_label()
	_card.size = Vector2(minf(board.size.x - 16.0 / _scale, 320.0 / _scale), 128.0 / _scale)
	_card.position = board.get_center() - _card.size * 0.5
	_card.pivot_offset = _card.size * 0.5
	var title_width: float = maxf(1.0, _card.size.x - 16.0 / _scale)
	var title_pixels: int = ceili((minf(24.0, _card.size.x * _scale / 10.0) \
		if _state.get("complete", false) else 48.0) / _scale)
	var measured: float = Style.HEADING_FONT.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_pixels).x
	if measured > title_width:
		title_pixels = maxi(1, floori(float(title_pixels) * title_width / measured))
	_title.add_theme_font_size_override("font_size", title_pixels)
	_title.position = Vector2(8, 16) / _scale
	_title.size = Vector2(title_width, 62.0 / _scale)
	_title.add_theme_constant_override("outline_size", ceili(4.0 / _scale))
	_title.add_theme_color_override("font_outline_color", Color("#fffdf6"))
	_detail.position = Vector2(8, 84) / _scale
	_detail.size = Vector2(_card.size.x - 16.0 / _scale, 28.0 / _scale)
	_detail.add_theme_font_size_override("font_size", ceili(14.0 / _scale))
	queue_redraw()
	_card.queue_redraw()


func snapshot() -> Dictionary:
	var state: Dictionary = _state.duplicate(true)
	state["visible"] = is_visible_in_tree()
	state["label"] = _label.text
	state["celebrating"] = visible and _elapsed < _card_duration
	state["elapsed"] = _elapsed
	state["ready_pending"] = ready_pending()
	state["entry_phase"] = "ready" if ready_pending() else "go" if entry_active() else "done"
	state["time_bonus"] = {"active": _time_bonus_remaining > 0.0, "seconds": _time_bonus}
	state["timer_ratio"] = _timer_ratio()
	state["rating_segments"] = rating_geometry(_rating_bounds(), _scale)
	state["star_loss_active"] = rating_feedback_active()
	state["star_loss_elapsed"] = _star_loss_elapsed.duplicate()
	state["rect"] = [_badge.position.x, _badge.position.y, _badge.size.x, _badge.size.y]
	return state


func rating_feedback_active() -> bool:
	return not reduced_motion and _star_loss_elapsed.any(func(elapsed: float) -> bool: return elapsed < STAR_LOSS_SECONDS)


func _rating_bounds() -> Rect2:
	return Rect2(_badge.position + Vector2(8, 7) / _scale,
		Vector2(maxf(1.0, _badge.size.x - 104.0 / _scale), maxf(1.0, _badge.size.y - 14.0 / _scale)))


func rating_geometry(bounds: Rect2, ui_scale: float, compact: bool = false) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var span: float = bounds.size.x / 3.0
	var edge: float = minf((20.0 if compact else 28.0) / ui_scale, span * 0.84)
	for index in range(3):
		var star := Rect2(Vector2(bounds.position.x + (float(index) + 0.5) * span - edge * 0.5, bounds.position.y),
			Vector2.ONE * edge)
		var bar := Rect2(Vector2(bounds.position.x + float(index) * span, bounds.end.y - 3.0 / ui_scale),
			Vector2(maxf(0.0, span - 2.0 / ui_scale), 3.0 / ui_scale))
		slots.append({"star": [star.position.x, star.position.y, star.size.x, star.size.y],
			"bar": [bar.position.x, bar.position.y, bar.size.x, bar.size.y]})
	return slots


func draw_rating(canvas: CanvasItem, bounds: Rect2, ui_scale: float, compact: bool = false) -> void:
	var slots: Array[Dictionary] = rating_geometry(bounds, ui_scale, compact)
	for index in range(3):
		var slot: Dictionary = slots[index]
		var star := Rect2(slot.star[0], slot.star[1], slot.star[2], slot.star[3])
		canvas.draw_texture_rect(STAR, star, false,
			Color.WHITE if index < int(_state.get("stars_now", 0)) else Color(0.35, 0.40, 0.38, 0.45))
		if reduced_motion or _star_loss_elapsed[index] >= STAR_LOSS_SECONDS:
			continue
		var p: float = _star_loss_elapsed[index] / STAR_LOSS_SECONDS
		var pulse: float = sin(p * PI)
		var flying: Rect2 = star.grow(star.size.x * 0.14 * pulse)
		flying.position.y -= 8.0 / ui_scale * pulse
		canvas.draw_texture_rect(STAR, flying, false, Color(1, 1, 1, 1.0 - p))
		for mote in range(4):
			var angle: float = TAU * float(mote) / 4.0
			var at: Vector2 = star.get_center() + Vector2(cos(angle), sin(angle)) * (6.0 + 15.0 * p) / ui_scale
			var edge: float = (7.0 * (1.0 - p)) / ui_scale
			canvas.draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge),
				false, Color(1.0, 0.86, 0.45, 1.0 - p))


func _timer_ratio() -> float:
	if _state.get("kind") not in ["main", "challenge"]:
		return 0.0
	var total: float = maxf(0.001, float(_state.get("seconds_total", 0.0)))
	return clampf(float(_state.get("seconds_remaining", 0.0)) / total, 0.0, 1.0)


func _update_label() -> void:
	if _state.is_empty():
		return
	_label.position = _badge.position
	_label.size = _badge.size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var separator: String = "\n" if _badge.size.y * _scale >= 40.0 else "  ·  "
	if _state.get("kind") in ["main", "challenge"]:
		var seconds: int = maxi(0, ceili(float(_state.get("seconds_remaining", 0.0))))
		_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
		_label.position = Vector2(_badge.end.x - 84.0 / _scale, _badge.position.y)
		_label.size = Vector2(76.0 / _scale, _badge.size.y)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		return
	_label.text = "Stage %d%s%d / %d mastered" % [_state.number, separator, _state.mastered, _state.total]


func _refresh_motion() -> void:
	if entry_active():
		_title.text = "Ready?" if ready_pending() else "Go!"
		_title.add_theme_color_override("font_color", Style.INK if ready_pending() else Style.GOOD)
	_card.visible = _elapsed < _card_duration and visible
	var enter: float = clampf(_elapsed / 0.25, 0.0, 1.0)
	var leave: float = clampf((_card_duration - _elapsed) / 0.32, 0.0, 1.0)
	_card.modulate.a = minf(enter, leave)
	var beat: float = clampf((_elapsed - READY_SECONDS) / 0.24, 0.0, 1.0)
	_card.scale = Vector2.ONE if reduced_motion else Vector2.ONE * \
		(1.0 + sin(enter * PI) * 0.08 - (1.0 - enter) * 0.14 + sin(beat * PI) * 0.13)
	_card.queue_redraw()


func _draw() -> void:
	if _state.is_empty():
		return
	draw_style_box(Style.box(Color("eef9ed"), Color("b8d6bf"), 12, 1), _badge)
	if _label.visible and _state.get("kind") in ["main", "challenge"]:
		var fill: Rect2 = _badge.grow(-1.0 / _scale)
		fill.size.x *= _timer_ratio()
		if fill.has_area():
			draw_style_box(Style.box(Color("#c5e7cc"), Color.TRANSPARENT, 11, 0), fill)
	if _state.get("kind") == "challenge":
		if _time_bonus_remaining > 0.0:
			var at := Vector2(_badge.end.x - 64.0 / _scale,
				_badge.position.y + (20.0 + 10.0 * _time_bonus_remaining) / _scale)
			draw_texture_rect(CLOCK, Rect2(at, Vector2.ONE * 18.0 / _scale), false)
			draw_string(Style.HEADING_FONT, at + Vector2(20, 15) / _scale,
				"+" + String.num(_time_bonus, 1).trim_suffix(".0") + "s",
				HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(15.0 / _scale), Style.GOOD)
		return
	if _state.get("kind") == "main":
		if _label.visible:
			draw_rating(self, _rating_bounds(), _scale)
		return
	var progress: float = float(_state.get("mastered", 0)) / maxf(1.0, float(_state.get("total", 10)))
	var track := Rect2(_badge.position + Vector2(12.0 / _scale, _badge.size.y - 3.0 / _scale), Vector2((_badge.size.x - 24.0 / _scale) * progress, 2.0 / _scale))
	if track.size.x > 0.0:
		draw_rect(track, Style.GOOD)


func _draw_card() -> void:
	if not _card.visible:
		return
	var bounds := Rect2(Vector2.ZERO, _card.size)
	draw_card_light(bounds)
	var spin: float = 0.0 if reduced_motion else _elapsed * 0.12
	_card.draw_set_transform(bounds.get_center(), spin)
	_card.draw_texture_rect(RAYS, Rect2(-bounds.size * 0.62, bounds.size * 1.24), false,
		Color(1.0, 0.87, 0.48, 0.35))
	_card.draw_set_transform(Vector2.ZERO)
	for index in range(6):
		var angle: float = TAU * float(index) / 6.0
		var travel: float = 1.0 if reduced_motion else smoothstep(0.0, 0.7, _elapsed)
		var offset := Vector2(cos(angle) * (_card.size.x * 0.48 + 12.0 / _scale * travel), sin(angle) * (52.0 + 22.0 * travel) / _scale)
		var edge: float = (16.0 + 6.0 * sin(float(index))) / _scale
		_card.draw_texture_rect(SPARKLE, Rect2(bounds.get_center() + offset - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, Color("f4c768"))


func draw_card_light(bounds: Rect2) -> void:
	_card.draw_texture_rect(GLOW, bounds.grow(26.0 / _scale), false, Color(0.9, 0.86, 0.4, 0.45))
