extends Button
## A steady collection tray. Acquired word-jelly artwork builds the charge.

const Style = preload("res://scripts/ui_style.gd")
const GEL = preload("res://assets/images/jelly-match/gel-mint.png")
const SKY = preload("res://assets/images/jelly-match/gel-sky.png")
const LILAC = preload("res://assets/images/jelly-match/gel-lilac.png")
const WORD_PICTURE = preload("res://assets/images/ui/modes/cat.webp")
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
var _ui_scale: float = 1.0
var _panel := StyleBoxFlat.new()
var _lip := StyleBoxFlat.new()
var _badge := StyleBoxFlat.new()
var _focus := StyleBoxFlat.new()


func _init() -> void:
	name = "CollectWords"
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	_active = active
	var next_charge: float = minf(MAX_CHARGE, float(_batch_charge if _active else _count))
	if next_charge > _target_charge:
		_growth_elapsed = 0.0
		_growth_strength = minf(1.0, 0.45 + (next_charge - _target_charge) * 0.12)
	_target_charge = next_charge
	if _reduced_motion:
		_charge = _target_charge
		_growth_elapsed = GROW_SECONDS
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
	if _reduced_motion or not is_finite(delta) or delta <= 0.0:
		return
	_elapsed += delta
	_charge = lerpf(_charge, _target_charge, 1.0 - exp(-delta / CHARGE_SECONDS))
	if absf(_charge - _target_charge) < 0.001:
		_charge = _target_charge
	_growth_elapsed = minf(GROW_SECONDS, _growth_elapsed + delta)
	_beat_elapsed = minf(BEAT_SECONDS, _beat_elapsed + delta)
	queue_redraw()


func beat() -> void:
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
	if _active:
		description = "Collecting words. %d of %d remaining" % [_remaining, _total]
	elif _count == 0:
		description = "Collect completed words. Merge letter jellies to make a word first"
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
		"visual_scale": 0.88 + strength * 0.10 + growth * 0.055 + strike * 0.018 + pulse * strength * 0.008,
		"glow": minf(1.0, clampf((_charge - 1.0) / 8.0, 0.0, 1.0) * (0.48 + pulse * 0.20) + strike * 0.15 + surplus * 0.27),
		"rays": minf(1.0, clampf((_charge - 4.0) / 5.0, 0.0, 1.0) * (0.60 + pulse * 0.22) + surplus * 0.25),
		"rock": 0.0 if _reduced_motion else sin(_elapsed * (2.6 + surplus * 0.5)) * strength * strength * (0.038 + surplus * 0.007)
	}


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var pose: Dictionary = _sample()
	var tall: bool = size.y >= size.x * 0.68
	var unit: float = 1.0 / _ui_scale
	var ready: bool = _count > 0 or _active
	var available: bool = ready and (not disabled or _active)
	var press: float = 1.0 if is_pressed() and not disabled else 0.0
	var strength: float = float(pose.strength)
	# A consistent mint tray separates this free action from the priced items.
	# Only its surface flexes; the caption, count and input rectangle stay put.
	var panel_scale := Vector2(float(pose.visual_scale), float(pose.visual_scale))
	panel_scale += Vector2(float(pose.growth) * 0.024, -float(pose.growth) * 0.018)
	panel_scale *= 1.0 - press * 0.025
	var panel_size: Vector2 = (size - Vector2.ONE * 4.0 * unit) * panel_scale
	var bounds := Rect2((size - panel_size) * 0.5 + Vector2(0.0, press * unit), panel_size)
	var radius: int = roundi((20.0 if tall else 16.0) * unit)
	var fill := Color("#d5f3e7").lerp(Color("#a5e5ce"), strength) if available else Color("#e5eeeb")
	if is_hovered() and not disabled:
		fill = fill.lightened(0.12)
	_lip.bg_color = Color("#73b8a0") if available else Color("#b8cdc4")
	_lip.set_corner_radius_all(radius)
	_lip.shadow_color = Color("#527f73", 0.16 if available else 0.08)
	_lip.shadow_size = roundi(3.0 * unit)
	_lip.shadow_offset = Vector2(0.0, 2.0 * unit)
	draw_style_box(_lip, bounds)
	var face := Rect2(bounds.position, bounds.size - Vector2(0.0, (2.5 - press) * unit))
	_panel.bg_color = fill
	_panel.border_color = Color("#f3fff6") if available else Color("#f0f5f1")
	_panel.set_border_width_all(maxi(1, roundi(unit)))
	_panel.set_corner_radius_all(radius)
	draw_style_box(_panel, face)
	if has_focus() and not disabled:
		_focus.bg_color = Color.TRANSPARENT
		_focus.border_color = Color("#308775")
		_focus.set_border_width_all(maxi(2, roundi(2.0 * unit)))
		_focus.set_corner_radius_all(radius + roundi(2.0 * unit))
		draw_style_box(_focus, bounds.grow(2.0 * unit))
	var icon_center := Vector2(size.x * (0.45 if tall else 0.35), size.y * (0.40 if tall else 0.67))
	var icon_edge: float = minf(size.x * 0.42, size.y * 0.40) if tall else minf(size.x * 0.28, size.y * 0.46)
	icon_edge *= 0.92 + strength * 0.10
	var halo_edge: float = icon_edge * (1.55 if tall else 1.50)
	if available and float(pose.glow) > 0.001:
		_draw_art(GLOW, icon_center, Vector2.ONE * halo_edge, Color(0.78, 1.0, 0.85, float(pose.glow) * 0.70))
	if available and float(pose.rays) > 0.001:
		var turn: float = 0.0 if _reduced_motion else _elapsed * 0.14
		draw_set_transform(icon_center, turn)
		_draw_art(RAYS, Vector2.ZERO, Vector2.ONE * halo_edge, Color(1.0, 0.96, 0.66, float(pose.rays) * 0.75))
		draw_set_transform(Vector2.ZERO)
	_draw_jellies(icon_center, icon_edge, pose, tall, available)
	_draw_sparkles(icon_center, halo_edge, pose, tall, available)
	_draw_caption(tall, available, unit)
	_draw_count(tall, available, unit, float(pose.strike))


func _draw_art(texture: Texture2D, center: Vector2, extent: Vector2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(texture, Rect2(center - extent * 0.5, extent), false, tint)


func _draw_jellies(center: Vector2, edge: float, pose: Dictionary, tall: bool, available: bool) -> void:
	var lift: float = (float(pose.growth) * 0.10 + float(pose.strike) * 0.10) * edge
	var stretch := Vector2(1.0 + float(pose.strike) * 0.07, 1.0 - float(pose.strike) * 0.09)
	var positions: Array[Vector2] = [Vector2(-0.35, -0.10), Vector2(0.32, -0.18),
		Vector2(-0.12, -0.33), Vector2(0.15, -0.45), Vector2(-0.32, -0.46),
		Vector2(0.35, -0.51), Vector2(0.02, -0.63)]
	var thresholds: Array[float] = [1.5, 2.3, 5.0, 8.0, 10.0, 13.5, 20.0]
	# Rear jellies unfurl from the center as the real available count increases.
	draw_set_transform(center + Vector2(0.0, -lift), float(pose.rock) * 0.60, stretch)
	for index in range(positions.size() - 1, -1, -1):
		var amount: float = smoothstep(thresholds[index], thresholds[index] + 0.8, _charge)
		if amount <= 0.001:
			continue
		var offset: Vector2 = positions[index] * edge * amount
		var extent := Vector2(edge * 0.74, edge * 0.61) * (0.8 + amount * 0.2)
		if not tall:
			# The compact fan opens sideways, leaving the title its own line even
			# during growth and a collection lift at the highest stored charge.
			offset.y *= 0.24
			offset.y = maxf(offset.y, size.y * 0.46 - center.y + lift + extent.y * 0.5 + 1.0 / _ui_scale)
		var texture: Texture2D = SKY if index % 2 == 0 else LILAC
		draw_texture_rect_region(texture, Rect2(offset - extent * 0.5, extent), GEL_REGION,
			Color(1.0, 1.0, 1.0, amount * (1.0 if available else 0.50)))
	var extent := Vector2(edge, edge * 0.82)
	var tint := Color.WHITE if available else Color(0.90, 0.95, 0.91, 0.65)
	draw_texture_rect_region(GEL, Rect2(-extent * 0.5, extent), GEL_REGION, tint)
	_draw_art(WORD_PICTURE, Vector2(0.0, -edge * 0.025), Vector2.ONE * edge * 0.67, tint)
	draw_set_transform(Vector2.ZERO)


func _draw_sparkles(center: Vector2, edge: float, pose: Dictionary, tall: bool, available: bool) -> void:
	if not available:
		return
	var amount: int = int(pose.sparkle_count)
	var unit: float = 1.0 / _ui_scale
	for index in range(amount):
		var angle: float = -PI * 0.86 + float(index) * TAU / maxf(float(amount), 4.0)
		var phase: float = float(index) * 1.91 + _elapsed * (1.7 + float(pose.strength) * 1.8 + float(pose.surplus))
		var twinkle: float = 0.72 if _reduced_motion else pow((sin(phase) + 1.0) * 0.5, 2.0)
		var radius: float = edge * (0.35 + float(index % 2) * 0.10)
		var point: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.68) * radius
		var star_edge: float = edge * (0.07 + twinkle * 0.055 + float(pose.strike) * 0.025)
		# Keep local light below the compact caption and above the tray lip.
		point.x = clampf(point.x, star_edge, size.x * 0.67)
		point.y = clampf(point.y, 8.0 * unit if tall else size.y * 0.46, size.y * (0.67 if tall else 0.88))
		_draw_art(SPARKLE, point, Vector2.ONE * star_edge, Color(1.0, 0.95, 0.69, 0.30 + twinkle * 0.55))
		_draw_art(SPARKLE, point, Vector2.ONE * star_edge * 0.45, Color(1.0, 1.0, 0.98, 0.55 + twinkle * 0.45))


func _draw_caption(tall: bool, available: bool, unit: float) -> void:
	var font: Font = Style.HEADING_FONT
	var caption: String = "Collect"
	var font_size: int = maxi(10, roundi((16.0 if tall else 14.0) * unit))
	var area := Rect2(Vector2(size.x * 0.08, size.y * (0.68 if tall else 0.065)),
		Vector2(size.x * 0.84, size.y * (0.25 if tall else 0.34)))
	var extent: Vector2 = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	if extent.x > area.size.x:
		font_size = maxi(8, floori(font_size * area.size.x / extent.x))
		extent = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var origin := Vector2(area.get_center().x - extent.x * 0.5,
		area.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string(font, origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color("#245d4f") if available else Color("#728a80"))


func _draw_count(tall: bool, available: bool, unit: float, strike: float) -> void:
	var caption: String = str(_remaining if _active else _count)
	var font: Font = Style.HEADING_FONT
	var font_size: int = maxi(10, roundi(16.0 * unit))
	var extent: Vector2 = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var width: float = maxf(26.0 * unit, extent.x + 10.0 * unit)
	var height: float = 26.0 * unit
	var center := Vector2(size.x * (0.75 if tall else 0.72), size.y * (0.31 if tall else 0.665))
	var bounds := Rect2(center - Vector2(width, height) * 0.5, Vector2(width, height))
	bounds.position.x = clampf(bounds.position.x, 3.0 * unit, size.x - bounds.size.x - 3.0 * unit)
	_badge.bg_color = Color("#fffce5") if available else Color("#f4f7f3")
	if _active:
		_badge.bg_color = _badge.bg_color.lerp(Color.WHITE, strike * 0.65)
	_badge.border_color = Color("#ffffff", 0.94)
	_badge.set_border_width_all(maxi(1, roundi(unit)))
	_badge.set_corner_radius_all(roundi(10.0 * unit))
	_badge.shadow_color = Color("#468773", 0.12)
	_badge.shadow_size = roundi(2.0 * unit)
	_badge.shadow_offset = Vector2(0.0, unit)
	draw_style_box(_badge, bounds)
	var baseline: float = bounds.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(bounds.get_center().x - extent.x * 0.5, baseline), caption,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#306a56") if available else Color("#82938b"))


func snapshot() -> Dictionary:
	var pose: Dictionary = _sample()
	return {
		"count": _count, "active": _active, "remaining": _remaining, "total": _total,
		"target_charge": _target_charge, "charge": _charge, "stage": int(pose.stage), "surplus": pose.surplus,
		"visual_scale": pose.visual_scale, "growth": pose.growth,
		"glow": pose.glow, "rays": pose.rays,
		"sparkle_count": pose.sparkle_count, "jelly_count": pose.jelly_count,
		"elapsed": _elapsed, "beat_count": _beat_count, "reduced_motion": _reduced_motion
	}
