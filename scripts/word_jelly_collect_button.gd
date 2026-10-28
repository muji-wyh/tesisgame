extends Button
## The collection action shares the quiet card layout of its neighboring tools.

const Style = preload("res://scripts/ui_style.gd")
const GEL = preload("res://assets/images/jelly-match/gel-mint.png")
const SKY = preload("res://assets/images/jelly-match/gel-sky.png")
const LILAC = preload("res://assets/images/jelly-match/gel-lilac.png")
const WORD_PICTURE = preload("res://assets/images/ui/modes/cat.webp")
const LOCK = preload("res://assets/images/ui/controls/lock.svg")
const UNLOCK_LEVEL: int = 3
const GEL_REGION := Rect2(11, 34, 298, 252)
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const MAX_CHARGE: float = 24.0
const CHARGE_SECONDS: float = 0.34
const GROW_SECONDS: float = 0.72
const BEAT_SECONDS: float = 0.38

var _count: int = 0
var _active: bool = false
var _remaining: int = 0
var _total: int = 0
var _batch_charge: int = 0
var _target_charge: float = 0.0
var _charge: float = 0.0
var _elapsed: float = 0.0
var _growth_elapsed: float = GROW_SECONDS
var _growth_strength: float = 0.0
var _beat_elapsed: float = BEAT_SECONDS
var _beat_count: int = 0
var _reduced_motion: bool = false
var _pip_level: int = 0
var _locked: bool = true
var _ui_scale: float = 1.0
var _panel := StyleBoxFlat.new()
var _focus := StyleBoxFlat.new()
var _count_badge := StyleBoxFlat.new()


func _init() -> void:
	name = "CollectWords"
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	set_ui_scale(1.0)
	_update_accessibility()


func set_state(count: int, active: bool, remaining: int, total: int) -> void:
	_count = maxi(0, count)
	_remaining = maxi(0, remaining)
	_total = maxi(0, total)
	if active and not _active:
		_batch_charge = maxi(_count, _total)
	elif active:
		_batch_charge = maxi(_batch_charge, _total)
	else:
		_batch_charge = 0
	_active = active and not _locked
	var next_charge: float = 0.0 if _locked else minf(MAX_CHARGE, float(_batch_charge if _active else _count))
	if next_charge > _target_charge:
		_growth_elapsed = 0.0
		_growth_strength = minf(1.0, 0.45 + (next_charge - _target_charge) * 0.12)
	_target_charge = next_charge
	if _reduced_motion:
		_charge = _target_charge
		_growth_elapsed = GROW_SECONDS
	_update_accessibility()
	queue_redraw()


func set_pip_level(level: int) -> void:
	_pip_level = maxi(0, level)
	var next_locked: bool = _pip_level < UNLOCK_LEVEL
	mouse_default_cursor_shape = Control.CURSOR_ARROW if next_locked else Control.CURSOR_POINTING_HAND
	if next_locked != _locked:
		_locked = next_locked
		_charge = 0.0
		_target_charge = 0.0
		_growth_elapsed = GROW_SECONDS
		_beat_elapsed = BEAT_SECONDS
		set_state(_count, _active, _remaining, _total)
	_update_accessibility()
	queue_redraw()


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if value:
		_charge = _target_charge
		_growth_elapsed = GROW_SECONDS
		_beat_elapsed = BEAT_SECONDS
	queue_redraw()


func set_ui_scale(value: float) -> void:
	_ui_scale = maxf(0.1, value)
	custom_minimum_size = Vector2.ONE * ceilf(44.0 / _ui_scale)
	queue_redraw()


func advance(delta: float) -> void:
	if _locked or _reduced_motion or not is_finite(delta) or delta <= 0.0:
		return
	_elapsed += delta
	_charge = lerpf(_charge, _target_charge, 1.0 - exp(-delta / CHARGE_SECONDS))
	if absf(_charge - _target_charge) < 0.001:
		_charge = _target_charge
	_growth_elapsed = minf(GROW_SECONDS, _growth_elapsed + delta)
	_beat_elapsed = minf(BEAT_SECONDS, _beat_elapsed + delta)
	queue_redraw()


func beat() -> void:
	if _locked:
		return
	_beat_count += 1
	if not _reduced_motion:
		_beat_elapsed = 0.0
	queue_redraw()


func reset() -> void:
	_count = 0
	_active = false
	_remaining = 0
	_total = 0
	_batch_charge = 0
	_target_charge = 0.0
	_charge = 0.0
	_elapsed = 0.0
	_growth_elapsed = GROW_SECONDS
	_growth_strength = 0.0
	_beat_elapsed = BEAT_SECONDS
	_beat_count = 0
	_update_accessibility()
	queue_redraw()


func _update_accessibility() -> void:
	var description: String = "Collect %d completed words" % _count
	if _locked:
		description = "Auto Collect locked. Reach Pip Lv%d to unlock" % UNLOCK_LEVEL
	elif _active:
		description = "Collecting words. %d of %d remaining" % [_remaining, _total]
	elif _count == 0:
		description = "Collect completed words. Join word parts to complete more words"
	set("accessibility_name", description)


func _sample() -> Dictionary:
	var strength: float = clampf(_charge / 9.0, 0.0, 1.0)
	var surplus: float = clampf((_charge - 9.0) / 15.0, 0.0, 1.0)
	var pulse: float = 0.0
	var growth: float = 0.0
	var strike: float = 0.0
	if not _reduced_motion:
		var phase: float = _elapsed * (lerpf(2.1, 4.4, strength) + surplus * 2.4)
		pulse = (sin(phase) + 1.0) * 0.5
		if _growth_elapsed < GROW_SECONDS:
			var t: float = _growth_elapsed / GROW_SECONDS
			growth = sin(t * TAU) * pow(1.0 - t, 1.5) * _growth_strength
		if _beat_elapsed < BEAT_SECONDS:
			var t: float = _beat_elapsed / BEAT_SECONDS
			strike = sin(t * PI) * pow(1.0 - t, 0.55)
	var stage: int = 0 if _charge < 0.25 else 1 if _charge < 2.5 else 3 if _charge < 5.5 else 6 if _charge < 8.5 else 9 if _charge < 14.5 else 15 if _charge < 20.5 else 21
	var jellies: int = 0 if stage == 0 else 1 if stage == 1 else 3 if stage == 3 else 4 if stage == 6 else 5 if stage == 9 else 7 if stage == 15 else 8
	var sparks: int = 0 if stage < 3 else 2 if stage < 6 else 4 if stage < 9 else 7 + floori(surplus * 9.0)
	return {
		"strength": strength,
		"surplus": surplus,
		"pulse": pulse,
		"growth": growth,
		"strike": strike,
		"stage": stage,
		"jelly_count": jellies,
		"sparkle_count": sparks,
		"visual_scale": 0.94 + strength * 0.04 + growth * 0.055 + strike * 0.018 + pulse * strength * 0.008,
		"glow": minf(1.0, clampf((_charge - 1.0) / 8.0, 0.0, 1.0) * (0.48 + pulse * 0.20) + strike * 0.15 + surplus * 0.27),
		"rays": minf(1.0, clampf((_charge - 4.0) / 5.0, 0.0, 1.0) * (0.60 + pulse * 0.22) + surplus * 0.25),
		"rock": 0.0 if _reduced_motion else sin(_elapsed * (2.6 + surplus * 0.5)) * strength * strength * (0.038 + surplus * 0.007)
	}


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var pose: Dictionary = _sample()
	var unit: float = 1.0 / _ui_scale
	var ready: bool = not _locked and (_count > 0 or _active)
	var available: bool = ready and (not disabled or _active)
	var press: float = 1.0 if is_pressed() and not disabled and not _locked else 0.0
	var bounds := Rect2(Vector2.ONE * unit, size - Vector2.ONE * 2.0 * unit)
	var radius: int = maxi(1, roundi(13.0 * unit))
	var fill: Color = Style.GOOD if available else Style.SURFACE
	if is_hovered() and not disabled and not _locked:
		fill = fill.lightened(0.10)
	_panel.bg_color = fill
	_panel.border_color = Style.GOOD.darkened(0.10) if available else Style.EDGE
	_panel.set_border_width_all(maxi(1, roundi(unit)))
	_panel.set_corner_radius_all(radius)
	_panel.shadow_color = Color("#577777", 0.14)
	_panel.shadow_size = roundi(3.0 * unit)
	_panel.shadow_offset = Vector2(0.0, (1.0 if press > 0.0 else 2.0) * unit)
	draw_style_box(_panel, bounds)
	if has_focus() and not disabled:
		_focus.bg_color = Color.TRANSPARENT
		_focus.border_color = Color("#308775")
		_focus.set_border_width_all(maxi(2, roundi(2.0 * unit)))
		_focus.set_corner_radius_all(radius + roundi(2.0 * unit))
		draw_style_box(_focus, bounds.grow(2.0 * unit))
	if _locked:
		_draw_locked_detail(unit)
		_draw_caption(false, unit)
		return
	var content: Dictionary = _content_layout()
	var icon_area: Rect2 = content.icon
	var icon_edge: float = icon_area.size.x * float(pose.visual_scale)
	var icon_center: Vector2 = icon_area.get_center()
	var halo_edge: float = icon_edge * 1.28
	if available and float(pose.glow) > 0.001:
		_draw_art(GLOW, icon_center, Vector2.ONE * halo_edge, Color(0.85, 1.0, 0.82, float(pose.glow) * 0.75))
	if available and float(pose.rays) > 0.001:
		var turn: float = 0.0 if _reduced_motion else _elapsed * 0.14
		draw_set_transform(icon_center, turn)
		_draw_art(RAYS, Vector2.ZERO, Vector2.ONE * halo_edge, Color(1.0, 0.96, 0.66, float(pose.rays) * 0.65))
		draw_set_transform(Vector2.ZERO)
	_draw_jellies(icon_center, icon_edge, pose, available)
	_draw_sparkles(icon_center, pose, available)
	_draw_caption(available, unit)


func _draw_art(texture: Texture2D, center: Vector2, extent: Vector2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(texture, Rect2(center - extent * 0.5, extent), false, tint)


func _draw_jellies(center: Vector2, edge: float, pose: Dictionary, available: bool) -> void:
	var lift: float = (float(pose.growth) * 0.08 + float(pose.strike) * 0.10) * edge
	var stretch := Vector2(1.0 + float(pose.strike) * 0.07, 1.0 - float(pose.strike) * 0.09)
	var positions: Array[Vector2] = [Vector2(-0.28, -0.08), Vector2(0.24, -0.16),
		Vector2(-0.12, -0.23), Vector2(0.15, -0.28), Vector2(-0.27, -0.26),
		Vector2(0.28, -0.30), Vector2(0.02, -0.34)]
	var thresholds: Array[float] = [1.5, 2.3, 5.0, 8.0, 10.0, 13.5, 20.0]
	draw_set_transform(center + Vector2(0.0, -lift), float(pose.rock) * 0.60, stretch)
	for index in range(positions.size() - 1, -1, -1):
		var amount: float = smoothstep(thresholds[index], thresholds[index] + 0.8, _charge)
		if amount <= 0.001:
			continue
		var offset: Vector2 = positions[index] * edge * amount
		var extent := Vector2(edge * 0.74, edge * 0.61) * (0.8 + amount * 0.2)
		var texture: Texture2D = SKY if index % 2 == 0 else LILAC
		draw_texture_rect_region(texture, Rect2(offset - extent * 0.5, extent), GEL_REGION,
			Color(1.0, 1.0, 1.0, amount * (1.0 if available else 0.50)))
	var extent := Vector2(edge, edge * 0.82)
	var tint := Color.WHITE if available else Color(0.82, 0.91, 0.85, 0.85)
	draw_texture_rect_region(GEL, Rect2(-extent * 0.5, extent), GEL_REGION, tint)
	_draw_art(WORD_PICTURE, Vector2(0.0, -edge * 0.025), Vector2.ONE * edge * 0.70, tint)
	draw_set_transform(Vector2.ZERO)


func _draw_sparkles(center: Vector2, pose: Dictionary, available: bool) -> void:
	if not available:
		return
	var amount: int = int(pose.sparkle_count)
	var unit: float = 1.0 / _ui_scale
	for index in range(amount):
		var angle: float = -PI * 0.86 + float(index) * TAU / maxf(float(amount), 4.0)
		var phase: float = float(index) * 1.91 + _elapsed * (1.7 + float(pose.strength) * 1.8 + float(pose.surplus))
		var twinkle: float = 0.72 if _reduced_motion else pow((sin(phase) + 1.0) * 0.5, 2.0)
		var radius: float = minf((11.0 + float(index % 2) * 3.0) * unit, minf(size.x * 0.14, size.y * 0.18))
		var point: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.78) * radius
		var star_edge: float = (4.0 + twinkle * 3.0 + float(pose.strike) * 2.0) * unit
		_draw_art(SPARKLE, point, Vector2.ONE * star_edge, Color(1.0, 0.97, 0.72, 0.30 + twinkle * 0.55))
		_draw_art(SPARKLE, point, Vector2.ONE * star_edge * 0.45, Color(1.0, 1.0, 0.98, 0.55 + twinkle * 0.45))


func _draw_caption(available: bool, unit: float) -> void:
	var content: Dictionary = _content_layout()
	var ink: Color = Color.WHITE if available else Style.MUTED
	_draw_text(content.title, ink, not bool(content.wide))
	_draw_text(content.detail, Color("#daebe0") if available else Style.MUTED, false)
	if not str(content.count.text).is_empty():
		if not _locked:
			_count_badge.bg_color = Style.GOOD.darkened(0.18) if available else Style.SOFT
			_count_badge.set_corner_radius_all(maxi(1, roundi(9.0 * unit)))
			draw_style_box(_count_badge, content.count.area)
		_draw_text(content.count, ink, true)


func _draw_locked_detail(unit: float) -> void:
	var area: Rect2 = _content_layout().icon
	_draw_art(LOCK, area.get_center(), Vector2.ONE * minf(area.size.x, 22.0 * unit), Style.MUTED)


func _text_entry(value: String, area: Rect2, target: float) -> Dictionary:
	if value.is_empty():
		return {"text": value, "area": area, "font_size": 1}
	var font: Font = Style.HEADING_FONT
	var font_size: int = maxi(1, roundi(target / _ui_scale))
	while font_size > 1 and (font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > area.size.x
		or font.get_height(font_size) > area.size.y):
		font_size -= 1
	return {"text": value, "area": area, "font_size": font_size}


func _content_layout() -> Dictionary:
	var unit: float = 1.0 / _ui_scale
	var wide: bool = size.x * _ui_scale >= 136.0
	var compact: bool = size.y * _ui_scale < 50.0
	var icon_edge: float = (26.0 if wide else 18.0 if compact else 24.0) * unit
	var icon := Rect2(Vector2((8.0 if wide else 10.0) * unit,
		(size.y - icon_edge) * 0.5 if wide else size.y - (13.0 if compact else 16.0) * unit - icon_edge * 0.5),
		Vector2.ONE * icon_edge)
	var count_area := Rect2(Vector2(size.x - 40.0 * unit,
		(size.y - 32.0 * unit) * 0.5 if wide else size.y - (24.0 if compact else 28.0) * unit),
		Vector2(32.0, 32.0 if wide else 22.0 if compact else 24.0) * unit)
	var title_area := Rect2(Vector2(6.0, 2.0) * unit,
		Vector2(maxf(1.0, size.x - 12.0 * unit), 18.0 * unit))
	var detail_area := Rect2()
	if wide:
		var title_width: float = maxf(1.0, (size.x - 48.0 * unit if _locked else count_area.position.x - 46.0 * unit))
		title_area = Rect2(Vector2(40.0 * unit, size.y * 0.5 - 13.0 * unit), Vector2(title_width, 26.0 * unit))
		if _locked:
			title_area.position.y = size.y * 0.5 - 18.0 * unit
			title_area.size.y = 20.0 * unit
			detail_area = Rect2(Vector2(title_area.position.x, size.y * 0.5 + 2.0 * unit), Vector2(title_width, 18.0 * unit))
	var value: String = "Lv%d" % UNLOCK_LEVEL if _locked else str(_remaining if _active else _count)
	var detail: String = "Unlock at Lv%d" % UNLOCK_LEVEL if _locked and wide else ""
	return {"wide": wide, "icon": icon,
		"title": _text_entry("Collect", title_area, 16.0 if wide and not _locked else 14.0 if wide else 12.0),
		"detail": _text_entry(detail, detail_area, 10.0),
		"count": _text_entry("" if _locked and wide else value, count_area, 12.0 if _locked else 16.0)}


func _draw_text(entry: Dictionary, color: Color, centered: bool) -> void:
	var value: String = entry.text
	if value.is_empty():
		return
	var area: Rect2 = entry.area
	var font: Font = Style.HEADING_FONT
	var font_size: int = int(entry.font_size)
	var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x: float = area.get_center().x - width * 0.5 if centered else area.position.x
	var y: float = area.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func snapshot() -> Dictionary:
	var pose: Dictionary = _sample()
	var content: Dictionary = _content_layout()
	var text_content := {}
	for key: String in ["title", "detail", "count"]:
		var entry: Dictionary = content[key]
		var rect: Rect2 = entry.area
		text_content[key] = {"text": entry.text, "font_size": entry.font_size,
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}
	return {
		"pip_level": _pip_level, "unlock_level": UNLOCK_LEVEL, "locked": _locked,
		"count": _count, "active": _active, "remaining": _remaining, "total": _total,
		"target_charge": _target_charge, "charge": _charge, "stage": int(pose.stage), "surplus": pose.surplus,
		"visual_scale": pose.visual_scale, "growth": pose.growth,
		"glow": pose.glow, "rays": pose.rays,
		"sparkle_count": pose.sparkle_count, "jelly_count": pose.jelly_count,
		"elapsed": _elapsed, "beat_count": _beat_count, "reduced_motion": _reduced_motion,
		"content": text_content
	}
