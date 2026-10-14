extends Button
## The hit target stays still while acquired gel and coin artwork build charge.

const Style = preload("res://scripts/ui_style.gd")
const Surface = preload("res://scripts/jelly_surface.gdshader")
const GEL = preload("res://assets/images/jelly-match/gel-mint.png")
const COIN = preload("res://assets/coins/gold-coin.png")
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
var _surface := TextureRect.new()
var _material := ShaderMaterial.new()


func _init() -> void:
	name = "CollectWords"
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_surface.texture = GEL
	_surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_surface.stretch_mode = TextureRect.STRETCH_SCALE
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.show_behind_parent = true
	_material.shader = Surface
	_surface.material = _material
	add_child(_surface)
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
	var coins: int = 0 if stage == 0 else 1 if stage == 1 else 3 if stage == 3 else 4 if stage == 6 else 5 if stage == 9 else 7 if stage == 15 else 8
	var sparks: int = 0 if stage < 3 else 2 if stage < 6 else 4 if stage < 9 else 7 + floori(surplus * 9.0)
	return {
		"strength": strength,
		"surplus": surplus,
		"pulse": pulse,
		"growth": growth,
		"strike": strike,
		"stage": stage,
		"coin_count": coins,
		"sparkle_count": sparks,
		"visual_scale": 0.82 + strength * 0.15 + growth * 0.075 + strike * 0.035 + pulse * strength * 0.014,
		"glow": minf(1.0, clampf((_charge - 1.0) / 8.0, 0.0, 1.0) * (0.48 + pulse * 0.20) + strike * 0.15 + surplus * 0.27),
		"rays": minf(1.0, clampf((_charge - 4.0) / 5.0, 0.0, 1.0) * (0.60 + pulse * 0.22) + surplus * 0.25),
		"rock": 0.0 if _reduced_motion else sin(_elapsed * (2.6 + surplus * 0.5)) * strength * strength * (0.038 + surplus * 0.007)
	}


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var pose: Dictionary = _sample()
	var tall: bool = size.y >= size.x * 0.68
	var center: Vector2 = size * 0.5
	var unit: float = 1.0 / _ui_scale
	var ready: bool = _count > 0 or _active
	var body_size: Vector2 = size * Vector2(1.03, 1.04) if tall else size * Vector2(1.00, 1.14)
	var art_scale: float = float(pose.visual_scale)
	if is_pressed() and not disabled:
		art_scale *= 0.97
	var base_color := Color.WHITE if ready else Color(0.91, 0.96, 0.91, 0.90)
	if is_hovered() and not disabled:
		base_color = Color(1.05, 1.05, 1.00, 1.0)
	var icon_center: Vector2 = Vector2(size.x * 0.5, size.y * 0.43) if tall else Vector2(size.x * 0.22, size.y * 0.50)
	var coin_edge: float = minf(size.x * 0.40, size.y * 0.39) if tall else minf(size.y * 0.57, size.x * 0.245)
	coin_edge *= 0.85 + float(pose.strength) * 0.13
	var halo_edge: float = minf(size.x * (0.97 if tall else 0.56), size.y * (0.86 if tall else 0.98))
	halo_edge = minf(halo_edge, minf(icon_center.x, size.x - icon_center.x) * 2.0 - 2.0 * unit)
	# Only the authored body flexes. Text and the stable touch target stay level.
	_surface.size = body_size
	_surface.position = center - body_size * 0.5
	_surface.pivot_offset = body_size * 0.5
	_surface.scale = Vector2.ONE * art_scale
	_surface.modulate = base_color
	var warmth: float = clampf((_charge - 1.0) / 8.0, 0.0, 1.0)
	var focused: bool = has_focus() and not disabled
	# Focus follows the acquired gel silhouette while the hit target stays fixed.
	_material.set_shader_parameter("palette_hue", lerpf(0.35, 0.115, warmth))
	_material.set_shader_parameter("rim_strength", 0.95 if focused else warmth * 0.72)
	_material.set_shader_parameter("rim_color", Color("#4c987a") if focused else Color("#eab243"))
	_material.set_shader_parameter("rim_width", 1.4 if focused else 1.15)
	if float(pose.glow) > 0.001:
		_draw_art(GLOW, icon_center, Vector2.ONE * halo_edge, Color(1.0, 0.76, 0.22, float(pose.glow)))
	if float(pose.rays) > 0.001:
		var turn: float = 0.0 if _reduced_motion else _elapsed * 0.17
		draw_set_transform(icon_center, turn)
		_draw_art(RAYS, Vector2.ZERO, Vector2.ONE * halo_edge, Color(1.0, 0.66, 0.08, float(pose.rays)))
		if float(pose.surplus) > 0.001:
			draw_set_transform(icon_center, -turn + PI / 6.0)
			_draw_art(RAYS, Vector2.ZERO, Vector2.ONE * halo_edge * 0.98, Color(1.0, 0.78, 0.17, float(pose.surplus) * 0.65))
		draw_set_transform(Vector2.ZERO)
	_draw_coins(icon_center, coin_edge, pose, ready)
	_draw_sparkles(icon_center, halo_edge, pose, tall)
	_draw_caption(tall, ready, unit)
	_draw_count(tall, ready, unit, float(pose.strike))


func _draw_art(texture: Texture2D, center: Vector2, extent: Vector2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(texture, Rect2(center - extent * 0.5, extent), false, tint)


func _draw_coins(center: Vector2, edge: float, pose: Dictionary, ready: bool) -> void:
	var strength: float = float(pose.strength)
	var lift: float = -float(pose.strike) * edge * 0.12
	var positions: Array[Vector2] = [
		Vector2(-0.42, 0.13), Vector2(0.40, 0.13),
		Vector2(-0.19, -0.28), Vector2(0.18, -0.36),
		Vector2(-0.23, -0.53), Vector2(0.22, -0.58), Vector2(0.0, -0.69)
	]
	var thresholds: Array[float] = [1.5, 2.3, 5.0, 8.0, 10.0, 13.5, 20.0]
	draw_set_transform(center + Vector2(0.0, lift), float(pose.rock))
	for index in range(positions.size()):
		var amount: float = smoothstep(thresholds[index], thresholds[index] + 0.8, _charge)
		if amount <= 0.001:
			continue
		var offset: Vector2 = positions[index] * edge * (0.65 + amount * 0.35)
		var extra_edge: float = edge * (0.77 + amount * 0.15)
		if index >= 4:
			# More saved words add a small crown, within the same touch footprint.
			extra_edge *= 0.73
			offset.y = maxf(offset.y, -center.y - lift + extra_edge * 0.5 + 3.0 / _ui_scale)
		_draw_art(COIN, offset, Vector2.ONE * extra_edge, Color(1, 1, 1, amount))
	var main_tint := Color.WHITE if ready else Color(0.88, 0.91, 0.83, 0.88)
	_draw_art(COIN, Vector2.ZERO, Vector2.ONE * edge * (1.0 + strength * 0.10), main_tint)
	draw_set_transform(Vector2.ZERO)


func _draw_sparkles(center: Vector2, edge: float, pose: Dictionary, tall: bool) -> void:
	var amount: int = int(pose.sparkle_count)
	for index in range(amount):
		var angle: float = -PI * 0.86 + float(index) * TAU / maxf(float(amount), 4.0)
		var phase: float = float(index) * 1.91 + _elapsed * (1.7 + float(pose.strength) * 2.0 + float(pose.surplus) * 1.5)
		var twinkle: float = 0.72 if _reduced_motion else pow((sin(phase) + 1.0) * 0.5, 2.0)
		var radius: float = edge * (0.30 + float(index % 2) * 0.12)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius
		offset.y *= 0.72 if tall else 0.63
		var point: Vector2 = center + offset
		var star_edge: float = edge * (0.09 + twinkle * 0.065 + float(pose.strike) * 0.035)
		point.x = clampf(point.x, star_edge, size.x - star_edge)
		point.y = clampf(point.y, star_edge, size.y - star_edge)
		_draw_art(SPARKLE, point, Vector2.ONE * star_edge, Color(1.0, 0.68, 0.08, 0.40 + twinkle * 0.60))
		_draw_art(SPARKLE, point, Vector2.ONE * star_edge * 0.5, Color(1.0, 1.0, 0.88, 0.55 + twinkle * 0.45))


func _draw_caption(tall: bool, ready: bool, unit: float) -> void:
	var font: Font = Style.HEADING_FONT
	var caption: String = "Collect"
	var font_size: int = maxi(10, roundi((15.0 if tall else 13.0) * unit))
	var area: Rect2 = Rect2(Vector2(size.x * 0.09, size.y * 0.63), Vector2(size.x * 0.82, size.y * 0.27)) if tall else Rect2(Vector2(size.x * 0.375, size.y * 0.22), Vector2(size.x * 0.40, size.y * 0.57))
	var tint: Color = Style.INK if ready else Style.MUTED
	var extent: Vector2 = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	if extent.x > area.size.x:
		font_size = maxi(8, floori(font_size * area.size.x / extent.x))
		extent = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var origin := Vector2(area.get_center().x - extent.x * 0.5, area.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string_outline(font, origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(1, roundi(unit)), Color(1.0, 1.0, 0.92, 0.66))
	draw_string(font, origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)


func _draw_count(tall: bool, ready: bool, unit: float, strike: float) -> void:
	var value: int = _remaining if _active else _count
	var caption: String = str(value)
	var font: Font = Style.HEADING_FONT
	var font_size: int = maxi(10, roundi(13.0 * unit))
	var extent: Vector2 = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var width: float = maxf(22.0 * unit, extent.x + 10.0 * unit)
	var height: float = 23.0 * unit
	var center: Vector2 = Vector2(size.x * 0.76, size.y * 0.26) if tall else Vector2(size.x * 0.845, size.y * 0.50)
	var bounds := Rect2(center - Vector2(width, height) * 0.5, Vector2(width, height))
	bounds.position.x = clampf(bounds.position.x, 2.0 * unit, size.x - bounds.size.x - 2.0 * unit)
	var fill := Color("#fff6ca") if ready else Color("#f1f6eb")
	var edge := Color("#ca9141") if ready else Color("#c7d4bd")
	if _active:
		fill = fill.lerp(Color.WHITE, strike * 0.65)
	var badge := Style.box(fill, edge, ceili(11.0 * unit), maxi(1, roundi(unit)))
	badge.shadow_color = Color(0.12, 0.25, 0.12, 0.17)
	badge.shadow_size = ceili(2.0 * unit)
	badge.shadow_offset = Vector2(0.0, unit)
	draw_style_box(badge, bounds)
	var baseline: float = bounds.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(bounds.get_center().x - extent.x * 0.5, baseline), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Style.INK if ready else Style.MUTED)


func snapshot() -> Dictionary:
	var pose: Dictionary = _sample()
	return {
		"count": _count, "active": _active, "remaining": _remaining, "total": _total,
		"target_charge": _target_charge, "charge": _charge, "stage": int(pose.stage), "surplus": pose.surplus,
		"visual_scale": pose.visual_scale, "growth": pose.growth,
		"glow": pose.glow, "rays": pose.rays,
		"sparkle_count": pose.sparkle_count, "coin_count": pose.coin_count,
		"elapsed": _elapsed, "beat_count": _beat_count, "reduced_motion": _reduced_motion
	}
