extends Control
## Model-owned rank and exact count, with one bounded flourish per increment.

const Style = preload("res://scripts/ui_style.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const COIN = preload("res://assets/coins/gold-coin.png")
const POP_SECONDS: float = 0.56
const BONUS_SECONDS: float = 1.80
const RANKS: Array[String] = ["D", "C", "B", "A", "S", "SS", "SSS"]
const COLORS: Array[Color] = [Color("#299d88"), Color("#258fc7"),
	Color("#5368d6"), Color("#a44acc"), Color("#d84991"),
	Color("#cf9425"), Color("#ed743b")]

var reduced_motion: bool = false
var _ui_scale: float = 1.0
var _count: int = 0
var _tier: int = 0
var _rank: String = "D"
var _bonus: int = 0
var _shown_bonus: int = 0
var _remaining: float = 0.0
var _seconds: float = 1.0
var _event_id: String = ""
var _pop_elapsed: float = POP_SECONDS
var _bonus_elapsed: float = BONUS_SECONDS
var _pulse_serial: int = 0
var _content := Control.new()
var _rank_label: Label
var _count_label: Label
var _caption: Label
var _bonus_label: Label
var _bonus_caption: Label
var _coin := TextureRect.new()
var _timer := ProgressBar.new()
var _timer_track := StyleBoxFlat.new()
var _timer_fill := StyleBoxFlat.new()
var _body := Rect2()
var _rank_region := Rect2()
var _count_region := Rect2()
var _detail_region := Rect2()
var _reward_region := Rect2()


func _init() -> void:
	name = "WordJellyCombo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_rank_label = _label("ComboRank")
	_count_label = _label("ComboCount")
	_caption = _label("ComboCaption")
	_caption.text = "COMBO"
	_bonus_label = _label("ComboBonus")
	_bonus_caption = _label("ComboBonusCaption")
	_bonus_caption.text = "COMBO BONUS"
	_coin.name = "ComboCoin"
	_coin.texture = COIN
	_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_content.add_child(_coin)
	_timer.name = "ComboCountdown"
	_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer.focus_mode = Control.FOCUS_NONE
	_timer.show_percentage = false
	_timer.step = 0.0
	for surface: StyleBoxFlat in [_timer_track, _timer_fill]:
		surface.set_corner_radius_all(3)
	_timer.add_theme_stylebox_override("background", _timer_track)
	_timer.add_theme_stylebox_override("fill", _timer_fill)
	_timer.set("accessibility_name", "Combo time remaining")
	_content.add_child(_timer)
	resized.connect(_layout)
	set("accessibility_name", "Combo 0")
	hide()


func _label(label_name: String) -> Label:
	var result: Label = Style.label("", 24)
	result.name = label_name
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.clip_text = false
	_content.add_child(result)
	return result


func configure(bounds: Rect2, ui_scale: float, steady: bool = false) -> void:
	_ui_scale = maxf(0.1, ui_scale)
	position = bounds.position
	size = bounds.size.max(Vector2.ZERO)
	reduced_motion = steady
	if steady:
		_pop_elapsed = POP_SECONDS
	_layout()
	_refresh()


func set_state(state: Dictionary, celebrate: bool = false) -> void:
	var next_count: int = maxi(0, int(state.get("count", 0)))
	set_timer(float(state.get("remaining", 0.0)) if next_count > 0 else 0.0,
		float(state.get("seconds", 1.0)))
	var next_event: String = str(state.get("event_id", ""))
	var next_tier: int = clampi(int(state.get("tier", 0)), 0, COLORS.size() - 1)
	var next_rank: String = str(state.get("rank", RANKS[next_tier])).strip_edges()
	if next_rank.is_empty():
		next_rank = RANKS[next_tier]
	var next_bonus: int = maxi(0, int(state.get("bonus", 0)))
	if next_count == _count and next_event == _event_id and next_tier == _tier \
		and next_rank == _rank and next_bonus == _bonus:
		return
	var increased: bool = next_count > _count
	var changed: bool = next_count != _count or next_event != _event_id
	_count = next_count
	_tier = next_tier
	_rank = next_rank
	_bonus = next_bonus
	_event_id = next_event
	if _count <= 0:
		_pop_elapsed = POP_SECONDS
		_bonus_elapsed = BONUS_SECONDS
		_shown_bonus = 0
	elif changed:
		if celebrate and increased and _bonus > 0:
			_shown_bonus = _bonus
			_bonus_elapsed = 0.0
		if celebrate and increased:
			_pulse_serial += 1
			_pop_elapsed = POP_SECONDS if reduced_motion else 0.0
	_rank_label.text = _rank
	_count_label.text = "×%d" % _count
	_bonus_label.text = "+%d" % _shown_bonus
	set("accessibility_name", "Combo %d. Rank %s.%s" % [_count, _rank,
		" Combo bonus: %d coins." % _shown_bonus if _reward_visible() else ""])
	_layout()
	_refresh()


func set_timer(remaining: float, seconds: float) -> void:
	var next_seconds: float = maxf(0.001, seconds)
	var next_remaining: float = clampf(remaining, 0.0, next_seconds)
	if next_seconds == _seconds and next_remaining == _remaining:
		return
	_seconds = next_seconds
	_remaining = next_remaining
	_timer.max_value = _seconds
	_timer.value = _remaining
	var color: Color = Color("#d85b3b") if _remaining / _seconds <= 0.25 else COLORS[_tier]
	if _timer_fill.bg_color != color:
		_timer_fill.bg_color = color


func _reward_visible() -> bool:
	return _count > 0 and _shown_bonus > 0 and _bonus_elapsed < BONUS_SECONDS


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or _count <= 0:
		return
	if _pop_elapsed >= POP_SECONDS and _bonus_elapsed >= BONUS_SECONDS:
		return
	var was_reward_visible: bool = _reward_visible()
	_pop_elapsed = minf(POP_SECONDS, _pop_elapsed + delta)
	_bonus_elapsed = minf(BONUS_SECONDS, _bonus_elapsed + delta)
	if was_reward_visible != _reward_visible():
		_layout()
	else:
		_refresh()


func reset() -> void:
	_count = 0
	_tier = 0
	_rank = "D"
	_bonus = 0
	_shown_bonus = 0
	_remaining = 0.0
	_timer.value = 0.0
	_event_id = ""
	_pop_elapsed = POP_SECONDS
	_bonus_elapsed = BONUS_SECONDS
	_pulse_serial = 0
	_rank_label.text = "D"
	_count_label.text = "×0"
	_bonus_label.text = ""
	set("accessibility_name", "Combo 0")
	_refresh()


func _fit_font(label: Label, region: Rect2, desired: float) -> void:
	var pixels: int = maxi(1, floori(desired))
	var room: Vector2 = (region.size - Vector2(4.0, 1.0) / _ui_scale).max(Vector2.ONE)
	while pixels > 1 and (Style.HEADING_FONT.get_string_size(label.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > room.x or Style.HEADING_FONT.get_height(pixels) > room.y):
		pixels -= 1
	label.add_theme_font_size_override("font_size", pixels)
	label.position = region.position
	label.size = region.size


func _layout() -> void:
	if _rank_label == null or size.x <= 0.0 or size.y <= 0.0:
		return
	# The supplied slot includes the complete 1.15-times text pop and artwork.
	_content.size = size / 1.16
	_content.pivot_offset = _content.size * 0.5
	_content.position = (size - _content.size) * 0.5
	_body = Rect2(_content.position, _content.size)
	var inner := Rect2(Vector2(3.0, 0.0) / _ui_scale,
		(_content.size - Vector2(6.0, 0.0) / _ui_scale).max(Vector2.ONE))
	var timer_height: float = 6.0 / _ui_scale
	_timer.position = inner.position + Vector2(4.0 / _ui_scale, inner.size.y - 9.0 / _ui_scale)
	_timer.size = Vector2(maxf(1.0, inner.size.x - 8.0 / _ui_scale), timer_height)
	inner.size.y = maxf(1.0, inner.size.y - 12.0 / _ui_scale)
	var reward_visible: bool = _reward_visible()
	var roomy: bool = _content.size.y * _ui_scale >= 50.0
	_reward_region = Rect2()
	if reward_visible and roomy:
		var reward_height: float = minf(25.0 / _ui_scale, inner.size.y * 0.49)
		_reward_region = Rect2(inner.position + Vector2(0.0, inner.size.y - reward_height),
			Vector2(inner.size.x, reward_height))
		inner.size.y -= reward_height + 2.0 / _ui_scale
	var rank_width: float = inner.size.x * (0.44 if _rank.length() >= 3 else 0.38)
	if reward_visible and not roomy:
		rank_width = inner.size.x * 0.24
	_rank_region = Rect2(inner.position, Vector2(rank_width, inner.size.y))
	var right := Rect2(inner.position + Vector2(rank_width, 0.0),
		Vector2(inner.size.x - rank_width, inner.size.y))
	if reward_visible and roomy:
		_count_region = Rect2(right.position, Vector2(right.size.x * 0.50, right.size.y))
		_detail_region = Rect2(right.position + Vector2(right.size.x * 0.50, 0.0),
			Vector2(right.size.x * 0.50, right.size.y))
	else:
		if reward_visible:
			_reward_region = Rect2(right.position + Vector2(right.size.x * 0.38, 0.0),
				Vector2(right.size.x * 0.62, right.size.y))
			right.size.x *= 0.38
		_count_region = Rect2(right.position, Vector2(right.size.x, right.size.y * 0.66))
		_detail_region = Rect2(right.position + Vector2(0.0, right.size.y * 0.64),
			Vector2(right.size.x, right.size.y * 0.36))
	_fit_font(_rank_label, _rank_region, 43.0 / _ui_scale)
	_fit_font(_count_label, _count_region, 36.0 / _ui_scale)
	_fit_font(_caption, _detail_region, 11.0 / _ui_scale)
	if reward_visible:
		var reward := Rect2(_reward_region.position + Vector2(3.0, 0.0) / _ui_scale,
			(_reward_region.size - Vector2(6.0, 0.0) / _ui_scale).max(Vector2.ONE))
		var caption_region: Rect2
		var amount_region: Rect2
		if roomy:
			caption_region = Rect2(reward.position, Vector2(reward.size.x * 0.57, reward.size.y))
			amount_region = Rect2(reward.position + Vector2(caption_region.size.x, 0.0),
				Vector2(reward.size.x - caption_region.size.x, reward.size.y))
		else:
			caption_region = Rect2(reward.position, Vector2(reward.size.x, reward.size.y * 0.34))
			amount_region = Rect2(reward.position + Vector2(0.0, caption_region.size.y),
				Vector2(reward.size.x, reward.size.y - caption_region.size.y))
		_fit_font(_bonus_caption, caption_region, (12.0 if roomy else 9.0) / _ui_scale)
		var coin_edge: float = minf(24.0 / _ui_scale, minf(amount_region.size.y, amount_region.size.x * 0.43))
		_coin.position = amount_region.position + Vector2(0.0, (amount_region.size.y - coin_edge) * 0.5)
		_coin.size = Vector2.ONE * coin_edge
		_fit_font(_bonus_label, Rect2(amount_region.position + Vector2(coin_edge + 2.0 / _ui_scale, 0.0),
			Vector2(maxf(1.0, amount_region.size.x - coin_edge - 2.0 / _ui_scale), amount_region.size.y)),
			26.0 / _ui_scale)
	var outline: int = maxi(1, roundi(2.0 / _ui_scale))
	for label: Label in [_rank_label, _count_label]:
		label.add_theme_color_override("font_outline_color", Color("#fffdf2"))
		label.add_theme_constant_override("outline_size", outline)
	_refresh()


func _pop_scale() -> float:
	if reduced_motion or _pop_elapsed >= 0.42:
		return 1.0
	var peak: float = 1.13 + _tier * 0.003
	if _pop_elapsed < 0.10:
		return lerpf(1.0, peak, 1.0 - pow(1.0 - _pop_elapsed / 0.10, 3.0))
	if _pop_elapsed < 0.24:
		return lerpf(peak, 0.975, smoothstep(0.10, 0.24, _pop_elapsed))
	return lerpf(0.975, 1.0, smoothstep(0.24, 0.42, _pop_elapsed))


func _refresh() -> void:
	visible = _count > 0 and size.x > 0.0 and size.y > 0.0
	_content.scale = Vector2.ONE * _pop_scale()
	var tint: Color = COLORS[_tier]
	_rank_label.add_theme_color_override("font_color", tint.darkened(0.21))
	_count_label.add_theme_color_override("font_color", Style.INK)
	_caption.add_theme_color_override("font_color", tint.darkened(0.35))
	_bonus_label.add_theme_color_override("font_color", Color("#7c4305"))
	_bonus_caption.add_theme_color_override("font_color", Color("#865413"))
	var reward_visible: bool = _reward_visible()
	_coin.visible = reward_visible
	_bonus_label.visible = reward_visible
	_bonus_caption.visible = reward_visible
	_caption.visible = true
	_timer.visible = _count > 0
	var timer_tint: Color = Color("#d85b3b") if _remaining / _seconds <= 0.25 else tint
	if _timer_track.bg_color != tint.lightened(0.82):
		_timer_track.bg_color = tint.lightened(0.82)
	if _timer_fill.bg_color != timer_tint:
		_timer_fill.bg_color = timer_tint
	var alpha: float = 1.0 if reduced_motion else 1.0 - smoothstep(1.42, BONUS_SECONDS, _bonus_elapsed)
	_coin.modulate.a = alpha
	_bonus_label.modulate.a = alpha
	_bonus_caption.modulate.a = alpha
	queue_redraw()


func _stamp(texture: Texture2D, point: Vector2, extent: Vector2, tint: Color, angle: float = 0.0) -> void:
	if tint.a <= 0.001 or extent.x <= 0.0 or extent.y <= 0.0:
		return
	var half: Vector2 = extent * 0.5
	var rotated := Vector2(absf(cos(angle)) * half.x + absf(sin(angle)) * half.y,
		absf(sin(angle)) * half.x + absf(cos(angle)) * half.y)
	var room: Vector2 = point.min(size - point).max(Vector2.ZERO)
	var fit: float = minf(1.0, minf(room.x / maxf(rotated.x, 0.001), room.y / maxf(rotated.y, 0.001)))
	if fit <= 0.0:
		return
	draw_set_transform(point, angle)
	draw_texture_rect(texture, Rect2(extent * fit * -0.5, extent * fit), false, tint)
	draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	if not visible or _body.size.x <= 0.0:
		return
	var tint: Color = COLORS[_tier]
	var flare: float = 0.0 if reduced_motion else 1.0 - smoothstep(0.035, POP_SECONDS, _pop_elapsed)
	var origin: Vector2 = _body.position + _rank_region.get_center()
	_stamp(GLOW, origin, Vector2(_body.size.y * 2.5, size.y * 1.25),
		Color(tint, 0.16 + flare * (0.35 + _tier * 0.055)))
	var panel := Style.box(Style.PAPER.lerp(tint.lightened(0.88), 0.20),
		tint.lightened(0.40), maxi(2, roundi(11.0 / _ui_scale)), maxi(1, roundi(1.2 / _ui_scale)))
	panel.shadow_color = Color(tint.darkened(0.5), 0.14)
	panel.shadow_size = maxi(1, roundi(2.0 / _ui_scale))
	draw_style_box(panel, _body)
	if _reward_visible() and _reward_region.has_area():
		var reward_box := Style.box(Color("#fff0bb"), Color("#efba50"),
			maxi(2, roundi(5.0 / _ui_scale)), maxi(1, roundi(1.0 / _ui_scale)))
		draw_style_box(reward_box, Rect2(_body.position + _reward_region.position, _reward_region.size))
	if flare <= 0.001:
		_stamp(SPARKLE, Vector2(_body.end.x - 4.0 / _ui_scale, _body.position.y + 4.0 / _ui_scale),
			Vector2.ONE * (5.0 + _tier * 0.8) / _ui_scale, Color(tint, 0.70))
		return
	var progress: float = clampf(_pop_elapsed / POP_SECONDS, 0.0, 1.0)
	_stamp(RAYS, origin, Vector2.ONE * _body.size.y * (1.15 + progress * 0.55),
		Color(tint, flare * 0.76), progress * 0.16)
	var count: int = 6 + _tier * 2
	for index in range(count):
		var angle: float = TAU * float(index) / float(count) - PI * 0.5
		var reach := Vector2(_body.size.x * (0.34 + progress * 0.12), _body.size.y * 0.43)
		var center: Vector2 = _body.get_center() + Vector2(cos(angle), sin(angle)) * reach
		var edge: float = (6.0 + _tier * 0.7 + float(index % 3)) / _ui_scale
		var color: Color = tint.lerp(Color("#ffd967"), 0.40 if index % 3 == 0 else 0.0)
		_stamp(SPARKLE, center, Vector2(edge * (1.2 + progress), edge * 0.52), Color(color, flare * 0.96), angle)


func _rect_array(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func coin_origin() -> Vector2:
	return _coin.get_global_rect().get_center()


func snapshot() -> Dictionary:
	return {"visible": is_visible_in_tree(), "count": _count, "rank": _rank, "tier": _tier,
		"bonus": _bonus, "event_id": _event_id, "count_text": _count_label.text,
		"bonus_visible": _coin.visible and visible, "bonus_text": _bonus_caption.text + " " + _bonus_label.text,
		"bonus_font_size": _bonus_label.get_theme_font_size("font_size"),
		"remaining": _remaining, "seconds": _seconds, "time_ratio": _remaining / _seconds,
		"timer_visible": _timer.visible and visible, "timer_rect": _rect_array(_timer.get_global_rect()),
		"pulse_serial": _pulse_serial,
		"pulse_elapsed": _pop_elapsed, "pulse_active": visible and not reduced_motion and _pop_elapsed < POP_SECONDS,
		"reduced_motion": reduced_motion, "input_transparent": mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"rect": _rect_array(get_global_rect()), "rank_rect": _rect_array(_rank_label.get_global_rect()),
		"count_rect": _rect_array(_count_label.get_global_rect()), "bonus_rect": _rect_array(_bonus_label.get_global_rect()),
		"coin_rect": _rect_array(_coin.get_global_rect()),
		"rank_font_size": _rank_label.get_theme_font_size("font_size"),
		"count_font_size": _count_label.get_theme_font_size("font_size"), "pop_scale": _pop_scale()}
