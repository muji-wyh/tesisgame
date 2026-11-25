extends Control
## Persistent stage progress and a brief, input-transparent stage arrival.

const Style = preload("res://scripts/ui_style.gd")
const GLOW = preload("res://assets/chests/shared/effects/portal_glow.png")
const SPARKLE = preload("res://assets/chests/shared/effects/sparkle.png")
const RAYS = preload("res://assets/chests/shared/effects/rays.png")
const STAR = preload("res://assets/images/ui/jelly-goals/star.webp")
const STAR_TEXTURES: Array[Texture2D] = [
	preload("res://assets/images/ui/jelly-goals/rating-bronze.png"),
	preload("res://assets/images/ui/jelly-goals/rating-silver.png"),
	STAR]
const STAR_COLORS: Array[Color] = [Color("#ce9062"), Color("#a9d8f6"), Color("#ffda6f")]
const CLOCK = preload("res://assets/images/ui/jelly-goals/clock.webp")
const DURATION: float = 1.8
const READY_SECONDS: float = 0.82
const STAR_LOSS_SECONDS: float = 0.60
const STAR_WARN_SECONDS: float = 5.0
const TIME_BONUS_SECONDS: float = 1.6
var reduced_motion: bool = false
var _state: Dictionary = {}
var _warn_elapsed: float = 0.0
var _label: Label
var _title: Label
var _detail: Label
var _card := Control.new()
var _badge := Rect2()
var _scale: float = 1.0
var _elapsed: float = DURATION
var _card_duration: float = DURATION
var _entry: bool = false
var _surface_style := Style.box(Color("#fff9e9"), Color("#d9cbb0"), 16, 1)
var _surface_shadow := Style.box(Color(0.20, 0.24, 0.30, 0.12), Color.TRANSPARENT, 16, 0)
var _track_style := Style.box(Color("#e6decb"), Color.TRANSPARENT, 3, 0)
var _fill_style := Style.box(Color("#78b9ae"), Color.TRANSPARENT, 3, 0)
var _time_bonus_remaining: float = 0.0
var _time_bonus: float = 0.0
var _time_feedback := Control.new()
var _time_amount: Label
var _time_clock := TextureRect.new()
var _time_anchor := Rect2()
var _time_compact: bool = false
var _star_loss_elapsed: Array[float] = [STAR_LOSS_SECONDS, STAR_LOSS_SECONDS, STAR_LOSS_SECONDS]


func _init() -> void:
	name = "JellyStageProgress"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 35
	_label = Style.label("", 15)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", Style.HEADING_FONT)
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
	_time_feedback.name = "ChallengeTimeGain"
	_time_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_feedback.z_index = 8
	add_child(_time_feedback)
	_time_feedback.draw.connect(_draw_time_feedback)
	_time_clock.texture = CLOCK
	_time_clock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_time_clock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_time_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_feedback.add_child(_time_clock)
	_time_amount = Style.label("", 18)
	_time_amount.add_theme_font_override("font", Style.HEADING_FONT)
	_time_amount.add_theme_color_override("font_color", Style.GOOD)
	_time_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_feedback.add_child(_time_amount)
	_time_feedback.hide()
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
			var c_stage: int = int(state.get("challenge_stage", 1))
			_title.text = "Bonus wave!" if c_stage % 5 == 0 else "Challenge"
			_detail.text = "Stage %d · 2× Treasure" % c_stage if c_stage % 5 == 0 else "Stage %d" % c_stage
		else:
			_title.text = "All words mastered!" if state.get("complete", false) else "Stage %d" % state.number
			var profile: String = str(state.get("profile", ""))
			if state.get("complete", false):
				_detail.text = "Beautiful work!"
			elif state.get("kind") == "main":
				var suffix: String = " · 2× Treasure" if profile == "Reward" \
					else " · Combo rush" if profile == "Flow" \
					else " · Relaxed pace" if profile == "Breather" else ""
				_detail.text = "%d word goals%s" % [state.total, suffix]
			else:
				_detail.text = "%d new words to master" % state.total
			if state.get("objective", "") == "boss":
				_detail.text = "Word goals + Pirate Raid" if int(state.get("number", 0)) in [27, 45, 54, 72, 81, 90] else "Word goals + Boss"
	_refresh_motion()
	queue_redraw()


func reset() -> void:
	_state.clear()
	_elapsed = DURATION
	_card_duration = DURATION
	_entry = false
	_time_bonus_remaining = 0.0
	_time_bonus = 0.0
	_pose_time_feedback()
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


func _star_warning_index() -> int:
	if _state.get("kind") != "main" or not str(_state.get("outcome", "")).is_empty():
		return -1
	var drop_in: float = float(_state.get("next_star_drop_in", -1.0))
	var active_stars: int = int(_state.get("stars_now", 0))
	if active_stars >= 2 and drop_in > 0.0 and drop_in <= STAR_WARN_SECONDS:
		return active_stars - 1
	return -1


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var warning: bool = not reduced_motion and _star_warning_index() >= 0
	var moving: bool = _elapsed < _card_duration or _time_bonus_remaining > 0.0 or rating_feedback_active() or warning
	if warning:
		_warn_elapsed = fmod(_warn_elapsed + delta, 100.0)
	_time_bonus_remaining = maxf(0.0, _time_bonus_remaining - delta)
	_pose_time_feedback()
	for index in range(3):
		_star_loss_elapsed[index] = minf(STAR_LOSS_SECONDS, _star_loss_elapsed[index] + delta)
	if _elapsed < _card_duration:
		_elapsed = minf(_card_duration, _elapsed + delta)
		_refresh_motion()
	if moving:
		queue_redraw()


func present_time_bonus(seconds: float) -> void:
	if not is_finite(seconds) or seconds < 0.0:
		push_error("A Challenge time notification needs a finite nonnegative committed award.")
		return
	if seconds == 0.0:
		return
	_time_bonus = (_time_bonus if _time_bonus_remaining > 0.0 else 0.0) + seconds
	_time_bonus_remaining = TIME_BONUS_SECONDS
	_layout_time_feedback()
	_pose_time_feedback()
	queue_redraw()


func configure_time_bonus(bounds: Rect2, compact: bool) -> void:
	_time_compact = compact
	var unit: float = 1.0 / _scale
	if not compact and _state.get("kind") == "challenge":
		bounds = _surface_bounds()
	_time_anchor = Rect2(bounds.position + Vector2(4, 0) * unit, Vector2(40, 18) * unit) if compact \
		else Rect2(bounds.position + Vector2(8.0 * unit, 2.0 * unit),
			Vector2(minf(96.0 * unit, maxf(1.0, bounds.size.x - 92.0 * unit)), 28.0 * unit))
	_layout_time_feedback()
	_pose_time_feedback()


func time_bonus_scale() -> float:
	if reduced_motion or _time_bonus_remaining <= 0.0:
		return 1.0
	var p: float = clampf((TIME_BONUS_SECONDS - _time_bonus_remaining) / 0.42, 0.0, 1.0)
	return 1.0 + 0.12 * sin(p * PI)


func _time_bonus_text() -> String:
	return "+<0.1s" if _time_bonus > 0.0 and _time_bonus < 0.1 \
		else "+" + String.num(_time_bonus, 1).trim_suffix(".0") + "s"


func _layout_time_feedback() -> void:
	_time_feedback.position = _time_anchor.position
	_time_feedback.size = _time_anchor.size
	_time_feedback.pivot_offset = _time_feedback.size * 0.5
	_time_clock.visible = not _time_compact
	_time_clock.position = Vector2(4, 4) / _scale
	_time_clock.size = Vector2.ONE * 20.0 / _scale
	_time_amount.position = Vector2(2.0 if _time_compact else 26.0, 0.0) / _scale
	var area := Vector2(maxf(1.0, _time_feedback.size.x - _time_amount.position.x - 2.0 / _scale),
		maxf(1.0, _time_feedback.size.y))
	_time_amount.text = _time_bonus_text()
	var pixels: int = ceili((13.0 if _time_compact else 18.0) / _scale)
	var width: float = Style.HEADING_FONT.get_string_size(_time_amount.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	var height: float = Style.HEADING_FONT.get_height(pixels)
	var fit: float = minf(1.0, minf(area.x / maxf(1.0, width), area.y / maxf(1.0, height)))
	pixels = maxi(1, floori(float(pixels) * fit))
	_time_amount.add_theme_font_size_override("font_size", pixels)
	_time_amount.update_minimum_size()
	_time_amount.size = area
	_time_feedback.accessibility_name = "Challenge time: " + _time_amount.text


func _pose_time_feedback() -> void:
	var active: bool = _time_bonus_remaining > 0.0 and _state.get("kind") == "challenge"
	if not active and not _time_feedback.visible and _label.scale == Vector2.ONE:
		return
	_time_feedback.visible = active
	_time_feedback.scale = Vector2.ONE * time_bonus_scale()
	_time_feedback.modulate.a = 1.0 if reduced_motion else clampf(_time_bonus_remaining / 0.25, 0.0, 1.0)
	_label.pivot_offset = _label.size * Vector2(1.0, 0.5)
	_label.scale = Vector2.ONE * time_bonus_scale()
	_label.add_theme_color_override("font_color", Style.GOOD if active else Style.INK)
	_time_feedback.queue_redraw()


func _draw_time_feedback() -> void:
	if not _time_feedback.visible:
		return
	var unit: float = 1.0 / _scale
	var bounds := Rect2(Vector2.ZERO, _time_feedback.size)
	var age: float = TIME_BONUS_SECONDS - _time_bonus_remaining
	var strength: float = 0.18 if reduced_motion else 0.25 + 0.20 * sin(clampf(age / 0.6, 0.0, 1.0) * PI)
	_time_feedback.draw_texture_rect(GLOW, bounds.grow(8.0 * unit), false, Color(0.78, 1.0, 0.72, strength))
	_time_feedback.draw_style_box(Style.box(Color("#eaffde"), Color("#75ae79"),
		ceili(9.0 * unit), maxi(1, roundi(unit))), bounds)
	if reduced_motion or age >= 0.65:
		return
	var p: float = age / 0.65
	for index in range(3):
		var angle: float = -PI * (0.15 + float(index) * 0.35)
		var at: Vector2 = bounds.get_center() + Vector2(cos(angle), sin(angle)) \
			* Vector2(bounds.size.x * 0.46 + p * 5.0 * unit, bounds.size.y * 0.5 + p * 5.0 * unit)
		var edge: float = (5.0 if _time_compact else 8.0) * unit * (1.0 - p)
		_time_feedback.draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * edge * 0.5,
			Vector2.ONE * edge), false, Color(1.0, 0.91, 0.49, 1.0 - p))


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
	for surface: StyleBoxFlat in [_surface_style, _surface_shadow]:
		surface.set_corner_radius_all(ceili(16.0 / _scale))
	_surface_style.set_border_width_all(maxi(1, roundi(1.0 / _scale)))
	for ribbon: StyleBoxFlat in [_track_style, _fill_style]:
		ribbon.set_corner_radius_all(maxi(1, ceili(3.0 / _scale)))
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
	configure_time_bonus(badge, false)
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
	var time_rect: Rect2 = _time_feedback.get_global_rect()
	state["time_bonus"] = {"active": _time_bonus_remaining > 0.0, "seconds": _time_bonus,
		"visible": _time_feedback.is_visible_in_tree(), "text": _time_amount.text if _time_feedback.visible else "",
		"remaining": _time_bonus_remaining, "duration": TIME_BONUS_SECONDS,
		"feedback_scale": _time_feedback.scale.x, "clock_scale": time_bonus_scale(),
		"rect": [time_rect.position.x, time_rect.position.y, time_rect.size.x, time_rect.size.y]}
	state["timer_ratio"] = _timer_ratio()
	state["surface_rect"] = _rect_values(_surface_bounds())
	state["timer_track"] = _rect_values(_timer_track())
	state["timer_fill"] = _rect_values(_timer_fill())
	state["clock_rect"] = _rect_values(_clock_bounds())
	state["rating_segments"] = rating_geometry(_rating_bounds(), _scale)
	state["star_loss_active"] = rating_feedback_active()
	state["star_loss_elapsed"] = _star_loss_elapsed.duplicate()
	state["rect"] = [_badge.position.x, _badge.position.y, _badge.size.x, _badge.size.y]
	return state


func rating_feedback_active() -> bool:
	return not reduced_motion and _star_loss_elapsed.any(func(elapsed: float) -> bool: return elapsed < STAR_LOSS_SECONDS)


func _rating_bounds() -> Rect2:
	var bounds: Rect2 = _surface_bounds()
	return Rect2(bounds.position + Vector2(12, 1) / _scale,
		Vector2(maxf(1.0, bounds.size.x - _timer_width() - 24.0 / _scale), 33.0 / _scale))


func _rect_values(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _surface_bounds() -> Rect2:
	if _state.get("kind") not in ["main", "challenge"]:
		return _badge
	var width: float = minf(_badge.size.x, (280.0 if _state.get("kind") == "main" else 200.0) / _scale)
	return Rect2(_badge.position + Vector2((_badge.size.x - width) * 0.5, 0.0), Vector2(width, _badge.size.y))


func _timer_width() -> float:
	var width: float = _surface_bounds().size.x
	return minf(104.0 / _scale, maxf(58.0 / _scale, width * 0.40))


func _clock_bounds() -> Rect2:
	var bounds: Rect2 = _surface_bounds()
	if _state.get("kind") == "challenge":
		return Rect2(bounds.position + Vector2(16, 3) / _scale, Vector2.ONE * 28.0 / _scale)
	if bounds.size.x * _scale < 208.0:
		return Rect2()
	return Rect2(Vector2(bounds.end.x - _timer_width(), bounds.position.y + 4.0 / _scale), Vector2.ONE * 26.0 / _scale)


func _timer_track() -> Rect2:
	var bounds: Rect2 = _surface_bounds()
	return Rect2(Vector2(bounds.position.x + 14.0 / _scale, bounds.end.y - 9.0 / _scale),
		Vector2(maxf(0.0, bounds.size.x - 28.0 / _scale), 5.0 / _scale))


func _timer_fill() -> Rect2:
	var fill: Rect2 = _timer_track()
	fill.size.x *= _timer_ratio()
	return fill


func rating_geometry(bounds: Rect2, ui_scale: float, compact: bool = false) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var span: float = bounds.size.x / 3.0
	var maximum: float = minf((20.0 if compact else 33.0) / ui_scale,
		minf(span * 0.94, bounds.size.y))
	for index in range(3):
		var edge: float = maximum * [0.86, 0.93, 1.0][index]
		var star := Rect2(Vector2(bounds.position.x + (float(index) + 0.5) * span - edge * 0.5,
			bounds.position.y + (bounds.size.y - edge) * 0.5),
			Vector2.ONE * edge)
		var bar := Rect2(Vector2(bounds.position.x + float(index) * span, bounds.end.y - 3.0 / ui_scale),
			Vector2(maxf(0.0, span - 2.0 / ui_scale), 3.0 / ui_scale))
		slots.append({"tier": index + 1, "material": ["Bronze", "Silver", "Gold"][index],
			"active": index < int(_state.get("stars_now", 0)),
			"star": [star.position.x, star.position.y, star.size.x, star.size.y],
			"bar": [bar.position.x, bar.position.y, bar.size.x, bar.size.y]})
	return slots


func draw_rating(canvas: CanvasItem, bounds: Rect2, ui_scale: float, compact: bool = false) -> void:
	var slots: Array[Dictionary] = rating_geometry(bounds, ui_scale, compact)
	var warn_index: int = _star_warning_index()
	for index in range(3):
		var slot: Dictionary = slots[index]
		var star := Rect2(slot.star[0], slot.star[1], slot.star[2], slot.star[3])
		var active: bool = bool(slot.active)
		var texture: Texture2D = STAR_TEXTURES[index]
		if active and index == warn_index:
			var pulse_w: float = 0.55 if reduced_motion else 0.5 + 0.5 * sin(_warn_elapsed * TAU * 2.2)
			var warn_star: Rect2 = star if reduced_motion else star.grow(star.size.x * 0.08 * pulse_w)
			canvas.draw_texture_rect(GLOW, warn_star.grow(star.size.x * 0.28), false,
				Color(1.0, 0.72, 0.28, 0.26 + 0.30 * pulse_w))
			canvas.draw_texture_rect(texture, warn_star, false, Color.WHITE.lerp(Color("#ffe2a0"), 0.25 * pulse_w))
		else:
			canvas.draw_texture_rect(texture, star, false, Color.WHITE if active else Color(0.65, 0.70, 0.70, 0.32))
		if reduced_motion or _star_loss_elapsed[index] >= STAR_LOSS_SECONDS:
			continue
		var p: float = _star_loss_elapsed[index] / STAR_LOSS_SECONDS
		var pulse: float = sin(p * PI)
		var flying: Rect2 = star.grow(star.size.x * 0.14 * pulse)
		flying.position.y -= 8.0 / ui_scale * pulse
		canvas.draw_texture_rect(texture, flying, false, Color(1, 1, 1, 1.0 - p))
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
		var bounds: Rect2 = _surface_bounds()
		var seconds: int = maxi(0, ceili(float(_state.get("seconds_remaining", 0.0))))
		_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
		_label.position = Vector2(bounds.end.x - _timer_width(), bounds.position.y + 1.0 / _scale)
		_label.size = Vector2(_timer_width() - 12.0 / _scale, 32.0 / _scale)
		if _state.get("kind") == "main" and _clock_bounds().has_area():
			_label.position.x += 26.0 / _scale
			_label.size.x -= 26.0 / _scale
		var pixels: int = ceili(21.0 / _scale)
		var measured: float = Style.HEADING_FONT.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
		if measured > _label.size.x:
			pixels = maxi(1, floori(float(pixels) * _label.size.x / measured))
		_label.add_theme_font_size_override("font_size", pixels)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_fill_style.bg_color = Color("#7bbcaf") if _timer_ratio() > 0.60 else Color("#8cb9cf") \
			if _timer_ratio() > 0.30 else Color("#dba15c")
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
	var bounds: Rect2 = _surface_bounds()
	draw_style_box(_surface_shadow, Rect2(bounds.position + Vector2(0, 2) / _scale, bounds.size))
	draw_style_box(_surface_style, bounds)
	if _state.get("kind") in ["main", "challenge"]:
		if _label.visible:
			var track: Rect2 = _timer_track()
			draw_style_box(_track_style, track)
			var fill: Rect2 = _timer_fill()
			if fill.has_area():
				draw_style_box(_fill_style, fill)
			if _state.get("kind") == "main":
				for boundary in [0.30, 0.60]:
					var point: Vector2 = track.position + Vector2(track.size.x * boundary, 0.0)
					draw_line(point, point + Vector2(0.0, track.size.y), Color("#fff9e9"), 2.0 / _scale)
				draw_rating(self, _rating_bounds(), _scale)
			var clock: Rect2 = _clock_bounds()
			if clock.has_area() and not (_state.get("kind") == "challenge" and _time_bonus_remaining > 0.0):
				draw_texture_rect(CLOCK, clock, false)
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
