extends Control
## Noninteractive, collection-clock effects made from acquired particle textures.

const GLOW = preload("res://assets/chests/shared/effects/portal_glow.png")
const RAYS = preload("res://assets/chests/shared/effects/rays.png")
const SPARKLE = preload("res://assets/chests/shared/effects/sparkle.png")
const IMPACT_STAR = preload("res://assets/images/jelly-level-fx/impact-star.png")
const SOFT_POOF = preload("res://assets/images/jelly-level-fx/soft-poof.png")
const MAX_ACTIVE: int = 16
const PROFILES: Array[Dictionary] = [
	{"name": "Pearl pop", "pattern": "pearl", "seconds": 0.80, "radius": 40.0, "sparks": 9, "bursts": 1, "hue": 0.44},
	{"name": "Twin ripple", "pattern": "ripple", "seconds": 1.10, "radius": 58.0, "sparks": 16, "bursts": 2, "hue": 0.51},
	{"name": "Spiral lift", "pattern": "spiral", "seconds": 1.45, "radius": 78.0, "sparks": 28, "bursts": 1, "hue": 0.67},
	{"name": "Firework bloom", "pattern": "firework", "seconds": 2.80, "radius": 112.0, "sparks": 60, "bursts": 4, "hue": 0.10},
	{"name": "Rose cascade", "pattern": "cascade", "seconds": 3.10, "radius": 134.0, "sparks": 80, "bursts": 5, "hue": 0.92},
	{"name": "Prismatic bouquet", "pattern": "bouquet", "seconds": 3.40, "radius": 158.0, "sparks": 108, "bursts": 7, "hue": 0.53},
	{"name": "Aurora crown", "pattern": "aurora", "seconds": 3.60, "radius": 178.0, "sparks": 124, "bursts": 8, "hue": 0.72},
	{"name": "Constellation shower", "pattern": "constellation", "seconds": 3.80, "radius": 198.0, "sparks": 144, "bursts": 9, "hue": 0.12},
	{"name": "Grand bouquet", "pattern": "grand_bouquet", "seconds": 4.00, "radius": 220.0, "sparks": 168, "bursts": 10, "hue": 0.08},
]
const FIREWORK_PALETTE: Array[Color] = [Color("#efaf35"), Color("#23b8d2"), Color("#eb6ba8"), Color("#9274df")]
const CASCADE_PALETTE: Array[Color] = [Color("#ed5b9a"), Color("#f3bd52"), Color("#b474db"), Color("#ee8754")]
const BOUQUET_PALETTE: Array[Color] = [Color("#35bec1"), Color("#f0bc42"), Color("#ef6b9e"), Color("#8e82ee"), Color("#7bc77a"), Color("#57a5e3")]
const AURORA_PALETTE: Array[Color] = [Color("#b68aeb"), Color("#55d5b8"), Color("#739be9"), Color("#dfb5ef")]
const CONSTELLATION_PALETTE: Array[Color] = [Color("#f0bc42"), Color("#57bddd"), Color("#ef84bc"), Color("#b9a0ee")]

var _entries: Array[Dictionary] = []
var _merge_pops: Array[Dictionary] = []
var _splatters: Array[Dictionary] = []
var _reduced_motion: bool = false
var _ui_scale: float = 1.0
var _serial: int = 0
var _board_pitch: float = 0.0
var _board_recoil := Vector2.ZERO


func set_board_recoil(offset: Vector2) -> void:
	if _board_recoil.is_equal_approx(offset):
		return
	_board_recoil = offset
	if visible:
		queue_redraw()


func _init() -> void:
	name = "WordJellyCollectionFX"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 54
	hide()


static func profile(level: int) -> Dictionary:
	var result: Dictionary = PROFILES[clampi(level, 1, PROFILES.size()) - 1].duplicate(true)
	result["level"] = clampi(level, 1, PROFILES.size())
	result["cue"] = cue_for_level(level)
	return result


static func cue_for_level(level: int) -> String:
	return "pop" if level <= 1 else "jelly-collect-lv%d" % clampi(level, 2, PROFILES.size())


func configure_layout(available: Rect2, ui_scale: float = 1.0) -> void:
	position = available.position
	size = available.size.max(Vector2.ZERO)
	_ui_scale = maxf(0.25, ui_scale)
	queue_redraw()


func set_board_burst(cell_pitch: float) -> void:
	if not is_finite(cell_pitch) or cell_pitch <= 0.0:
		push_error("Board collection effects need a positive cell pitch.")
		return
	_board_pitch = cell_pitch
	queue_redraw()


func present(origin: Vector2, level: int, accent: Color, batch: bool = false,
		initial_age: float = 0.0, delay: float = 0.0, anchor_id: String = "") -> void:
	if not origin.is_finite() or not is_finite(initial_age) or not is_finite(delay):
		return
	var selected: Dictionary = profile(level)
	var duration: float = float(selected.seconds)
	var burst_only: bool = _board_pitch > 0.0 and int(selected.level) >= 4
	if burst_only:
		duration = 0.62 + float(int(selected.level) - 4) * 0.04
	if batch:
		duration *= 0.75
	if _reduced_motion:
		duration = 0.42
	var wait: float = maxf(0.0, delay)
	if initial_age >= wait + duration:
		return
	_serial += 1
	var entry: Dictionary = {"id": _serial, "origin": origin - position, "profile": selected,
		"accent": accent, "batch": batch, "elapsed": maxf(0.0, initial_age),
		"delay": wait, "duration": duration, "anchor_id": anchor_id, "burst_only": burst_only}
	if int(selected.level) >= 4:
		entry["fireworks"] = _prepare_fireworks(entry)
	_entries.append(entry)
	while _entries.size() > MAX_ACTIVE:
		_entries.pop_front()
	show()
	queue_redraw()


func reanchor_pending(anchor_id: String, origin: Vector2) -> void:
	if anchor_id.is_empty() or not origin.is_finite():
		return
	var moved: bool = false
	for entry: Dictionary in _entries:
		if str(entry.anchor_id) == anchor_id and float(entry.elapsed) < float(entry.delay):
			entry.origin = origin - position
			moved = true
	if moved:
		queue_redraw()


func present_merge_pop(origin: Vector2, level: int, upgrade: bool, tint: Color, badge_text: String = "", gel_color: Color = Color(0, 0, 0, 0)) -> void:
	if not origin.is_finite():
		return
	var duration: float = 0.24 if _reduced_motion else (0.52 if upgrade else 0.38)
	_serial += 1
	var drop_tint: Color = gel_color if gel_color.a > 0.01 else tint
	_merge_pops.append({
		"id": _serial, "origin": origin - position, "level": clampi(level, 0, 9),
		"upgrade": upgrade, "tint": tint, "gel_color": drop_tint, "badge": badge_text,
		"elapsed": 0.0, "duration": duration
	})
	while _merge_pops.size() > MAX_ACTIVE:
		_merge_pops.pop_front()
	if not _reduced_motion:
		var droplet_count: int = (10 + mini(level, 6) * 2) if upgrade else (8 if level >= 1 else 6)
		present_jelly_splatter(origin, drop_tint, level if upgrade else maxi(1, level), upgrade, false, droplet_count)
	show()
	queue_redraw()


func present_jelly_splatter(origin: Vector2, gel_color: Color, level: int = 1, heavy: bool = false,
		is_collect: bool = true, count_override: int = -1, badge_text: String = "") -> void:
	if _reduced_motion or not origin.is_finite():
		return
	var clamped_lv: int = clampi(level, 1, 9)
	var count: int = count_override if count_override > 0 else (7 + clamped_lv * 2 if is_collect else 6 + clamped_lv)
	count = mini(count, 24)
	_serial += 1
	var sid: int = _serial
	var unit: float = _board_pitch if _board_pitch > 0.0 else 56.0 / _ui_scale
	var droplets: Array[Dictionary] = []
	for index in range(count):
		var frac: float = float(index) / float(maxi(1, count))
		var jitter: float = float(posmod(sid * 17 + index * 31, 19)) / 19.0 - 0.5
		var angle: float = frac * TAU + jitter * 0.42 - PI * 0.5
		var speed_var: float = 0.58 + float(posmod(sid * 13 + index * 23, 11)) / 11.0 * 0.85
		var speed_scale: float = (1.18 + float(mini(clamped_lv, 6)) * 0.14) if (heavy or is_collect) else 0.96
		var vel: Vector2 = Vector2.from_angle(angle) * unit * 2.55 * speed_scale * speed_var
		# Gentle upward bias so droplets pop into joyful Nintendo arcs before gravity pulls them down.
		vel.y -= unit * (0.65 if is_collect else 0.45) * (0.7 + float(index % 3) * 0.25)
		var size_factor: float = 0.095 + float(index % 4) * 0.032 + (0.025 if heavy or clamped_lv >= 4 else 0.0)
		var tint_shift: float = (float(index % 3) - 1.0) * 0.09
		var d_color: Color = gel_color.lightened(maxf(0.0, tint_shift)) if tint_shift >= 0.0 else gel_color.darkened(-tint_shift)
		droplets.append({
			"vel": vel,
			"radius": unit * size_factor,
			"color": d_color,
			"life": 0.34 + float(posmod(index * 7 + sid, 9)) / 9.0 * 0.24,
			"gloss": 0.78 + float(index % 2) * 0.18
		})
	var line_count: int = 8 + mini(clamped_lv, 6) if (heavy or clamped_lv >= 4) else 6
	_splatters.append({
		"id": sid,
		"origin": origin - position,
		"color": gel_color,
		"level": clamped_lv,
		"heavy": heavy or clamped_lv >= 4,
		"is_collect": is_collect,
		"badge": badge_text,
		"droplets": droplets,
		"line_count": line_count,
		"elapsed": 0.0,
		"duration": 0.60 if (heavy or clamped_lv >= 4) else 0.48
	})
	while _splatters.size() > MAX_ACTIVE:
		_splatters.pop_front()
	show()
	queue_redraw()


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for index in range(_entries.size() - 1, -1, -1):
		_entries[index].elapsed += delta
		if float(_entries[index].elapsed) >= float(_entries[index].delay) + float(_entries[index].duration):
			_entries.remove_at(index)
	for index in range(_merge_pops.size() - 1, -1, -1):
		_merge_pops[index].elapsed += delta
		if float(_merge_pops[index].elapsed) >= float(_merge_pops[index].duration):
			_merge_pops.remove_at(index)
	for index in range(_splatters.size() - 1, -1, -1):
		_splatters[index].elapsed += delta
		if float(_splatters[index].elapsed) >= float(_splatters[index].duration):
			_splatters.remove_at(index)
	visible = not _entries.is_empty() or not _merge_pops.is_empty() or not _splatters.is_empty()
	queue_redraw()


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if value:
		_splatters.clear()
		_board_recoil = Vector2.ZERO
	queue_redraw()


func reset() -> void:
	_entries.clear()
	_merge_pops.clear()
	_splatters.clear()
	_board_recoil = Vector2.ZERO
	hide()
	queue_redraw()


func snapshot() -> Dictionary:
	var states: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		var age: float = float(entry.elapsed) - float(entry.delay)
		states.append({"id": entry.id, "level": entry.profile.level, "name": entry.profile.name,
			"anchor_id": entry.anchor_id,
			"pattern": entry.profile.pattern, "cue": entry.profile.cue, "batch": entry.batch,
			"elapsed": entry.elapsed, "delay": entry.delay, "popped": age >= 0.0,
			"phase": _phase(entry, age),
			"duration": entry.duration, "origin": [entry.origin.x + position.x, entry.origin.y + position.y],
			"burst_only": bool(entry.burst_only), "radius": _radius(entry),
			"reduced_motion": _reduced_motion})
	return {"visible": visible and (not states.is_empty() or not _merge_pops.is_empty() or not _splatters.is_empty()), "active_count": states.size(),
		"merge_pop_count": _merge_pops.size(), "splatter_count": _splatters.size(),
		"entries": states, "reduced_motion": _reduced_motion, "input_transparent": mouse_filter == Control.MOUSE_FILTER_IGNORE}


func _draw() -> void:
	for entry: Dictionary in _entries:
		var age: float = float(entry.elapsed) - float(entry.delay)
		if age < 0.0:
			continue
		var progress: float = clampf(age / float(entry.duration), 0.0, 1.0)
		if _reduced_motion:
			_draw_steady(entry, progress)
		elif int(entry.profile.level) >= 4:
			_draw_fireworks(entry, progress)
		else:
			_draw_burst(entry, progress)
	for pop: Dictionary in _merge_pops:
		var p: float = clampf(float(pop.elapsed) / maxf(0.01, float(pop.duration)), 0.0, 1.0)
		_draw_merge_pop(pop, p)
	if not _reduced_motion:
		for splat: Dictionary in _splatters:
			_draw_jelly_splatter(splat)
	draw_set_transform(Vector2.ZERO)


func _draw_jelly_splatter(splat: Dictionary) -> void:
	var t: float = float(splat.elapsed)
	var dur: float = maxf(0.01, float(splat.duration))
	var p: float = clampf(t / dur, 0.0, 1.0)
	var origin: Vector2 = Vector2(splat.origin) + _board_recoil
	var unit: float = _board_pitch if _board_pitch > 0.0 else 56.0 / _ui_scale
	var heavy: bool = bool(splat.heavy)
	var is_collect: bool = bool(splat.is_collect)
	var base_color: Color = splat.color
	var level: int = int(splat.level)
	# 1. Crisp 2-stage Nintendo shock-rings (bright white inner snap + tinted outer echo).
	var inner_p: float = clampf(t / 0.16, 0.0, 1.0)
	if inner_p < 1.0:
		var er: float = 1.0 - pow(1.0 - inner_p, 3.2)
		var max_r: float = unit * ((1.28 + float(mini(level, 6)) * 0.09) if (is_collect or heavy) else 0.92)
		var ring_r: float = lerpf(unit * 0.22, max_r, er)
		var ring_w: float = maxf(1.4, lerpf(5.8 if (heavy or is_collect) else 3.8, 0.6, er) / _ui_scale)
		draw_set_transform(Vector2.ZERO)
		draw_arc(origin, ring_r, 0.0, TAU, 32, Color(1.0, 0.99, 0.92, (1.0 - inner_p) * 0.92), ring_w, true)
	var outer_t: float = t - 0.025
	if outer_t > 0.0 and outer_t < 0.22:
		var outer_p: float = outer_t / 0.22
		var eo: float = 1.0 - pow(1.0 - outer_p, 2.6)
		var out_r: float = unit * lerpf(0.32, (1.58 + float(mini(level, 6)) * 0.11) if (is_collect or heavy) else 1.12, eo)
		var out_w: float = maxf(1.0, lerpf(3.2 if heavy else 2.2, 0.5, eo) / _ui_scale)
		draw_set_transform(Vector2.ZERO)
		draw_arc(origin, out_r, 0.0, TAU, 32, Color(base_color.lightened(0.30), (1.0 - outer_p) * 0.78), out_w, true)
	# 2. Snappy comic speed-lines radiating on the first 120ms of impact.
	var line_p: float = clampf(t / 0.125, 0.0, 1.0)
	if line_p < 1.0:
		var lines: int = int(splat.line_count)
		var alpha: float = (1.0 - line_p) * (0.92 if heavy else 0.78)
		var el: float = 1.0 - pow(1.0 - line_p, 2.4)
		var line_w: float = maxf(1.3, lerpf(3.2 if heavy else 2.2, 0.6, line_p) / _ui_scale)
		draw_set_transform(Vector2.ZERO)
		for index in range(lines):
			var a: float = TAU * float(index) / float(lines) + float(int(splat.id) % 7) * 0.23
			var dir: Vector2 = Vector2.from_angle(a)
			var inner_d: float = unit * lerpf(0.30, 0.85 if heavy else 0.68, el)
			var seg_len: float = unit * lerpf(0.42 if heavy else 0.30, 0.10, line_p) * (0.78 + float(index % 3) * 0.16)
			var col: Color = Color(1.0, 0.97, 0.80, alpha) if index % 2 == 0 else Color(base_color.lightened(0.45), alpha)
			draw_line(origin + dir * inner_d, origin + dir * (inner_d + seg_len), col, line_w, true)
	# 3. Glossy color-matched jelly droplets with velocity stretch, rim outline & specular highlight.
	var gravity: float = unit * 7.8
	var drag: float = 4.6
	var inv_drag: float = 1.0 / drag
	var exp_term: float = 1.0 - exp(-drag * t)
	var vel_decay: float = exp(-drag * t)
	for drop: Dictionary in splat.droplets:
		var life: float = float(drop.life)
		if t >= life:
			continue
		var dp: float = clampf(t / life, 0.0, 1.0)
		var v0: Vector2 = drop.vel
		var pos: Vector2 = origin + v0 * (exp_term * inv_drag) + Vector2(0.0, 0.5 * gravity * t * t)
		var v_now: Vector2 = v0 * vel_decay + Vector2(0.0, gravity * t)
		var speed: float = v_now.length()
		var scale_env: float = lerpf(0.55, 1.18, clampf(dp / 0.14, 0.0, 1.0)) if dp < 0.14 else (1.0 - smoothstep(0.45, 1.0, dp)) * 1.18
		var r: float = float(drop.radius) * scale_env
		if r < 0.8:
			continue
		var stretch_x: float = clampf(1.0 + speed / maxf(1.0, unit * 5.2), 1.0, 1.85)
		var stretch_y: float = 1.0 / sqrt(stretch_x)
		var fade: float = 1.0 - smoothstep(0.62, 1.0, dp)
		var dc: Color = drop.color
		dc.a = fade * 0.94
		var outline_c: Color = dc.darkened(0.38)
		outline_c.a = fade * 0.72
		var angle: float = v_now.angle() if speed > 1.0 else 0.0
		draw_set_transform(pos, angle, Vector2(stretch_x, stretch_y))
		draw_circle(Vector2.ZERO, r + 1.0 / _ui_scale, outline_c)
		draw_circle(Vector2.ZERO, r, dc)
		# Crisp candy-gel white specular dot offset toward upper-left crown.
		draw_circle(Vector2(-r * 0.22, -r * 0.28), maxf(1.0, r * 0.34), Color(1.0, 1.0, 1.0, fade * float(drop.gloss)))
	# 4. Optional comic pop stamp for juicy collect beats (Lv2+ or combo).
	var badge: String = str(splat.badge)
	if not badge.is_empty():
		var Style = preload("res://scripts/ui_style.gd")
		var pop_scale: float = lerpf(0.45, 1.44, clampf(p / 0.13, 0.0, 1.0)) if p < 0.13 else lerpf(1.44, 0.96, smoothstep(0.13, 0.34, p))
		var b_alpha: float = 1.0 - smoothstep(0.58, 1.0, p)
		var rise: float = unit * (0.36 + 0.62 * (1.0 - pow(1.0 - p, 2.5)))
		var px: int = maxi(10, ceili(15.5 * pop_scale / _ui_scale))
		var w: float = Style.HEADING_FONT.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var pos := origin + Vector2(-w * 0.5, -rise)
		var tilt: float = sin(p * PI * 2.0) * (1.0 - p) * 0.09 * (-1.0 if int(splat.id) % 2 == 0 else 1.0)
		draw_set_transform(pos + Vector2(w * 0.5, 0.0), tilt)
		draw_string_outline(Style.HEADING_FONT, Vector2(-w * 0.5, 0.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(2, ceili(3.4 / _ui_scale)), Color("#2b233d", b_alpha * 0.90))
		draw_string(Style.HEADING_FONT, Vector2(-w * 0.5, 0.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("#fff4b8", b_alpha))


func _draw_merge_pop(pop: Dictionary, p: float) -> void:
	var origin: Vector2 = Vector2(pop.origin) + _board_recoil
	var level: int = int(pop.level)
	var upgrade: bool = bool(pop.upgrade)
	var tint: Color = pop.tint
	var unit: float = _board_pitch if _board_pitch > 0.0 else 56.0 / _ui_scale
	if _reduced_motion:
		var steady_alpha: float = 1.0 - smoothstep(0.45, 1.0, p)
		_stamp(GLOW, origin, Vector2.ONE * unit * (1.35 if upgrade else 1.05), Color(tint, steady_alpha * 0.42))
		return
	var ring_p: float = clampf(p / 0.48, 0.0, 1.0)
	if ring_p < 1.0:
		var ease_r: float = 1.0 - pow(1.0 - ring_p, 3.2)
		var ring_r: float = unit * lerpf(0.24, 1.18 + float(mini(level, 6)) * 0.09 if upgrade else 0.92, ease_r)
		var ring_w: float = maxf(1.4, lerpf(5.4 if upgrade else 3.4, 0.6, ease_r) / _ui_scale)
		draw_set_transform(Vector2.ZERO)
		draw_arc(origin, ring_r, 0.0, TAU, 32, Color(tint.lightened(0.52), (1.0 - ring_p) * (0.95 if upgrade else 0.78)), ring_w, true)
	var flash: float = 1.0 - smoothstep(0.0, 0.24, p)
	if flash > 0.005:
		_stamp(GLOW, origin, Vector2.ONE * unit * lerpf(0.88, 1.85 if upgrade else 1.42, p),
			Color(tint.lightened(0.58), flash * (0.76 if upgrade else 0.52)))
		var star_s: float = unit * lerpf(0.45, (1.42 + float(mini(level, 6)) * 0.08) if upgrade else 0.96, 1.0 - pow(1.0 - minf(1.0, p / 0.24), 2.8))
		_stamp(IMPACT_STAR, origin, Vector2.ONE * star_s, Color(1.0, 0.98, 0.78, flash * (0.98 if upgrade else 0.80)), p * 0.75)
		if upgrade or level >= 1:
			_stamp(RAYS, origin, Vector2.ONE * star_s * (1.55 if upgrade else 1.25), Color(tint.lightened(0.35), flash * (0.78 if upgrade else 0.48)), -p * 0.55)
	var spark_count: int = (8 + mini(level, 6)) if upgrade else 6
	var spread: float = unit * (1.12 + float(mini(level, 6)) * 0.10 if upgrade else 0.82)
	var travel: float = 1.0 - pow(1.0 - p, 3.0)
	var spark_fade: float = 1.0 - smoothstep(0.38, 1.0, p)
	for index in range(spark_count):
		var angle: float = TAU * float(index) / float(spark_count) + float(int(pop.id) % 5) * 0.27 - PI * 0.5
		var dist: float = spread * (0.72 + float(index % 3) * 0.16) * travel
		var pt: Vector2 = origin + Vector2.from_angle(angle) * dist
		var sp_edge: float = (11.5 if upgrade else 8.4) / _ui_scale * lerpf(1.22, 0.35, p)
		_stamp(SPARKLE, pt, Vector2(sp_edge * 1.45, sp_edge * 0.82),
			Color(Color("#fff8c8") if index % 2 == 0 else tint.lightened(0.30), spark_fade), angle)
	var badge: String = str(pop.badge)
	if not badge.is_empty():
		var Style = preload("res://scripts/ui_style.gd")
		# Nintendo bubble-pop overshoot: punchy 1.48x pop with elastic rebound and slight comic tilt.
		var pop_scale: float = lerpf(0.48, 1.48, clampf(p / 0.12, 0.0, 1.0)) if p < 0.12 else lerpf(1.48, 0.96, smoothstep(0.12, 0.30, p)) + sin(maxf(0.0, p - 0.30) * PI * 3.0) * (1.0 - p) * 0.08
		var b_alpha: float = 1.0 - smoothstep(0.60, 1.0, p)
		var rise: float = unit * (0.44 + 0.64 * (1.0 - pow(1.0 - p, 2.5)))
		var px: int = maxi(11, ceili(16.5 * pop_scale / _ui_scale))
		var w: float = Style.HEADING_FONT.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var pos := origin + Vector2(-w * 0.5, -rise)
		var tilt: float = sin(p * PI * 2.2) * (1.0 - p) * 0.10 * (-1.0 if int(pop.id) % 2 == 0 else 1.0)
		draw_set_transform(pos + Vector2(w * 0.5, 0.0), tilt)
		draw_string_outline(Style.HEADING_FONT, Vector2(-w * 0.5, 0.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(2, ceili(3.6 / _ui_scale)), Color("#2b233d", b_alpha * 0.92))
		draw_string(Style.HEADING_FONT, Vector2(-w * 0.5, 0.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("#fff4b8", b_alpha))


func _radius(entry: Dictionary) -> float:
	var requested: float = float(entry.profile.radius) / _ui_scale
	if bool(entry.batch):
		requested *= 0.66
	if bool(entry.get("burst_only", false)):
		requested = minf(requested, _board_pitch * (0.45 + float(int(entry.profile.level) - 4) * 0.015))
	return minf(requested, minf(size.x, size.y) * 0.44)


func _palette(entry: Dictionary, index: int) -> Color:
	var hue: float = float(entry.profile.hue)
	var level: int = int(entry.profile.level)
	if level == 6 or level >= 9:
		return BOUQUET_PALETTE[posmod(index, BOUQUET_PALETTE.size())]
	if level == 8:
		return CONSTELLATION_PALETTE[posmod(index, CONSTELLATION_PALETTE.size())]
	if level == 7:
		return AURORA_PALETTE[posmod(index, AURORA_PALETTE.size())]
	if level == 5:
		return CASCADE_PALETTE[posmod(index, CASCADE_PALETTE.size())]
	if level == 4:
		return FIREWORK_PALETTE[posmod(index, FIREWORK_PALETTE.size())]
	var color := Color.from_hsv(fposmod(hue, 1.0), 0.69, 0.95)
	return color.lerp(entry.accent, 0.16)


func _phase(entry: Dictionary, age: float) -> String:
	if age < 0.0:
		return "waiting"
	if _reduced_motion:
		return "steady"
	if int(entry.profile.level) < 4:
		return "release" if age < float(entry.duration) * 0.42 else "settling"
	var progress: float = age / float(entry.duration)
	if bool(entry.get("burst_only", false)):
		return "explosion" if progress < 0.18 else "blossom"
	if progress < 0.11:
		return "explosion"
	return "blossom" if progress < 0.46 else "falling_embers"


func _stamp(texture: Texture2D, point: Vector2, dimensions: Vector2, color: Color, angle: float = 0.0) -> void:
	if color.a <= 0.002 or dimensions.x <= 0.0 or dimensions.y <= 0.0:
		return
	draw_set_transform(point, angle)
	draw_texture_rect(texture, Rect2(dimensions * -0.5, dimensions), false, color)


func _draw_steady(entry: Dictionary, progress: float) -> void:
	var opacity: float = 1.0 - smoothstep(0.55, 1.0, progress)
	var origin: Vector2 = entry.origin
	var radius: float = minf(_radius(entry), 36.0 / _ui_scale)
	var tint: Color = _palette(entry, 0)
	_stamp(GLOW, origin, Vector2.ONE * radius * 2.1, Color(tint, 0.43 * opacity))
	var count: int = 3 + int(entry.profile.level) / 2
	for index in range(count):
		var angle: float = TAU * float(index) / float(count) - PI * 0.5
		var point: Vector2 = origin + Vector2.from_angle(angle) * radius * 0.70
		_stamp(SPARKLE, point, Vector2.ONE * (12.0 / _ui_scale), Color(_palette(entry, index), opacity))


func _draw_burst(entry: Dictionary, progress: float) -> void:
	var radius: float = _radius(entry)
	var origin: Vector2 = entry.origin
	var level: int = int(entry.profile.level)
	var pattern: String = str(entry.profile.pattern)
	var count: int = int(entry.profile.sparks)
	if bool(entry.batch):
		count = maxi(6, roundi(count * 0.66))
	var peak: float = smoothstep(0.0, 0.06, progress) * (1.0 - smoothstep(0.14, 0.56, progress))
	var shock_p: float = clampf(progress / 0.24, 0.0, 1.0)
	if shock_p < 1.0:
		var ring_r: float = radius * lerpf(0.24, 1.08, 1.0 - pow(1.0 - shock_p, 2.8))
		draw_set_transform(Vector2.ZERO)
		draw_arc(origin, ring_r, 0.0, TAU, 28,
			Color(_palette(entry, 0).lightened(0.45), (1.0 - shock_p) * 0.78),
			maxf(1.2, lerpf(3.4, 0.6, shock_p) / _ui_scale), true)
	_stamp(GLOW, origin, Vector2.ONE * radius * lerpf(0.55, 2.1, progress), Color(_palette(entry, 0), peak * 0.34))
	if level >= 2 and progress < 0.26:
		var star_p: float = clampf(progress / 0.26, 0.0, 1.0)
		_stamp(IMPACT_STAR, origin, Vector2.ONE * radius * lerpf(0.42, 1.12, 1.0 - pow(1.0 - star_p, 2.4)),
			Color(1.0, 0.96, 0.76, (1.0 - star_p) * 0.85), star_p * 0.4)
	if level >= 3:
		_stamp(RAYS, origin, Vector2.ONE * radius * (1.0 + progress * 1.55),
			Color(_palette(entry, 1), peak * 0.52), progress * 0.28)
	for index in range(count):
		var slot: float = float(index) / float(count)
		var phase: float = float(posmod(index * 7, 11)) / 11.0
		var group: int = index % int(entry.profile.bursts)
		var delay: float = float(group) * 0.24 if pattern == "ripple" else 0.0
		var p: float = clampf((progress - delay) / (1.0 - delay), 0.0, 1.0)
		if p <= 0.0:
			continue
		var angle: float = slot * TAU - PI * 0.5 + float(entry.id % 7) * 0.17
		var point: Vector2 = origin + _trajectory(pattern, angle, p, phase, group, radius)
		var fade: float = smoothstep(0.0, 0.025, p) * (1.0 - smoothstep(0.42 + phase * 0.19, 1.0, p))
		var edge: float = (6.2 + float(level) * 0.62 + phase * 4.0) / _ui_scale
		edge *= lerpf(1.10, 0.45, p)
		var tint: Color = _palette(entry, index)
		_stamp(SPARKLE, point, Vector2.ONE * edge, Color(tint, fade), angle + p * 0.45)


func _trajectory(pattern: String, angle: float, p: float, phase: float, group: int, radius: float) -> Vector2:
	var release: float = 1.0 - pow(1.0 - p, 2.6)
	var reach: float = radius * (0.59 + phase * 0.41)
	var direction: Vector2 = Vector2.from_angle(angle)
	match pattern:
		"pearl":
			return direction * reach * release
		"ripple":
			return direction * reach * release * (0.72 if group == 0 else 1.0)
		"spiral":
			return Vector2.from_angle(angle + p * 1.5) * reach * release + Vector2.UP * radius * p * 0.18
	return direction * reach * release


func _prepare_fireworks(entry: Dictionary) -> Array[Dictionary]:
	var level: int = int(entry.profile.level)
	var group_count: int = int(entry.profile.bursts)
	var count: int = int(entry.profile.sparks)
	var burst_only: bool = bool(entry.get("burst_only", false))
	if burst_only:
		group_count = mini(group_count, 4)
		count = roundi(float(count) * 0.45)
	if bool(entry.batch):
		count = roundi(float(count) * 0.45)
	var main_count: int = roundi(float(count) * (0.50 if level == 4 else 0.34))
	var secondary_count: int = maxi(5, (count - main_count) / (group_count - 1))
	var trail_count: int = 3 if bool(entry.batch) else mini(10, 7 + level - 4)
	if burst_only:
		trail_count = 2
	var groups: Array[Dictionary] = []
	for group in range(group_count):
		var spokes: int = main_count if group == 0 else secondary_count
		var tint: Color = _palette(entry, group)
		var directions := PackedVector2Array()
		var phases := PackedFloat64Array()
		var phase_sines := PackedFloat64Array()
		var angles := PackedFloat64Array()
		var edges := PackedFloat64Array()
		var colors := PackedColorArray()
		for index in range(spokes):
			var phase: float = float(posmod(index * 7 + group * 3, 13)) / 13.0
			var angle: float = TAU * float(index) / float(spokes) - PI * 0.5 + group * 0.38 + float(entry.id % 7) * 0.09
			directions.append(Vector2.from_angle(angle))
			phases.append(phase)
			phase_sines.append(sin(phase * TAU))
			angles.append(angle)
			edges.append(12.0 + phase * 4.0 + float(level - 4) * 0.8)
			colors.append(tint.lerp(_palette(entry, group + 1), 0.18 if index % 3 == 0 else 0.0))
		var tail_releases: Array[float] = []
		var tail_falling_ages: Array[float] = []
		var tail_drops: Array[float] = []
		tail_releases.resize(trail_count)
		tail_falling_ages.resize(trail_count)
		tail_drops.resize(trail_count)
		groups.append({"group": group, "delay": _firework_delay(level, group),
			"reach": _firework_reach(level, group), "tint": tint, "directions": directions,
			"phases": phases, "phase_sines": phase_sines, "angles": angles, "edges": edges,
			"colors": colors, "trail_count": trail_count, "tail_releases": tail_releases,
			"tail_falling_ages": tail_falling_ages, "tail_drops": tail_drops})
	return groups


func _draw_fireworks(entry: Dictionary, progress: float) -> void:
	var radius: float = _radius(entry)
	var level: int = int(entry.profile.level)
	var burst_only: bool = bool(entry.get("burst_only", false))
	var shock_p: float = clampf(progress / 0.16, 0.0, 1.0)
	if shock_p < 1.0:
		var sr: float = radius * lerpf(0.28, 1.28, 1.0 - pow(1.0 - shock_p, 3.0))
		draw_set_transform(Vector2.ZERO)
		draw_arc(entry.origin, sr, 0.0, TAU, 32,
			Color(1.0, 0.96, 0.74, (1.0 - shock_p) * 0.85),
			maxf(1.5, lerpf(4.4, 0.8, shock_p) / _ui_scale), true)
		_stamp(IMPACT_STAR, entry.origin, Vector2.ONE * radius * lerpf(0.48, 1.26, 1.0 - pow(1.0 - shock_p, 2.5)),
			Color(1.0, 0.95, 0.72, (1.0 - shock_p) * 0.90), shock_p * 0.35)
	# Every colored layer launches from the collected body, including delayed blooms.
	for geometry: Dictionary in entry.fireworks:
		var group: int = int(geometry.group)
		var delay: float = float(geometry.delay)
		var age: float = (progress - delay) * float(entry.profile.seconds)
		if burst_only:
			age = progress * float(entry.duration) - float(group) * 0.045
		if age < 0.0:
			continue
		var life: float = (1.0 - delay) * float(entry.profile.seconds)
		if burst_only:
			life = float(entry.duration) - float(group) * 0.045
		var base: Vector2 = entry.origin
		var reach: float = radius * float(geometry.reach)
		var directions: PackedVector2Array = geometry.directions
		var phases: PackedFloat64Array = geometry.phases
		var phase_sines: PackedFloat64Array = geometry.phase_sines
		var angles: PackedFloat64Array = geometry.angles
		var edges: PackedFloat64Array = geometry.edges
		var colors: PackedColorArray = geometry.colors
		var tint: Color = geometry.tint
		var peak: float = (1.0 - smoothstep(0.05, 0.38, age)) * (0.85 + smoothstep(0.0, 0.035, age) * 0.15)
		_stamp(GLOW, base, Vector2.ONE * reach * (0.55 + minf(age, 0.4) * 2.0), Color(tint, peak * 0.32))
		_stamp(RAYS, base, Vector2.ONE * reach * (0.60 + minf(age, 0.35) * 2.2), Color(tint, peak * 0.48), group * 0.37)
		# All spokes in a blossom and each of their tails share the same clock.
		# Keep the acquired sprite count and trajectories while sampling drag once.
		var release: float = 1.0 - exp(-age * 5.0)
		var falling_age: float = maxf(0.0, age - 0.16)
		var drop: float = reach * falling_age * falling_age * (0.115 if level == 5 else 0.095)
		var trail_count: int = int(geometry.trail_count)
		var tail_releases: Array[float] = geometry.tail_releases
		var tail_falling_ages: Array[float] = geometry.tail_falling_ages
		var tail_drops: Array[float] = geometry.tail_drops
		var first_tail: int = trail_count
		for tail_slot in range(trail_count):
			var prior_age: float = age - float(trail_count - tail_slot) * 0.05
			if prior_age < 0.0:
				continue
			first_tail = mini(first_tail, tail_slot)
			tail_releases[tail_slot] = 1.0 - exp(-prior_age * 5.0)
			tail_falling_ages[tail_slot] = maxf(0.0, prior_age - 0.16)
			tail_drops[tail_slot] = reach * tail_falling_ages[tail_slot] * tail_falling_ages[tail_slot] * (0.115 if level == 5 else 0.095)
		for index in range(directions.size()):
			var phase: float = phases[index]
			var angle: float = angles[index]
			var point: Vector2 = base + _firework_precomputed_trajectory(directions[index], phase, phase_sines[index],
				reach, release, falling_age, drop, burst_only)
			var fade: float = 1.0 - smoothstep(life * (0.60 + phase * 0.10), life, age)
			# Ember flicker changes luminance, not trajectory or visibility ownership.
			var flicker: float = lerpf(1.0, 0.90 + 0.10 * sin(age * 12.0 + phase * TAU), smoothstep(0.55, 1.4, age))
			var edge: float = edges[index] / _ui_scale
			if burst_only:
				edge = minf(edge, _board_pitch * 0.18)
			edge *= lerpf(1.08, 0.62, clampf(age / life, 0.0, 1.0))
			var spark_tint: Color = colors[index]
			for tail_slot in range(first_tail, trail_count):
				var tail: int = trail_count - tail_slot
				var behind: Vector2 = base + _firework_precomputed_trajectory(directions[index], phase, phase_sines[index],
					reach, tail_releases[tail_slot], tail_falling_ages[tail_slot], tail_drops[tail_slot], burst_only)
				var taper: float = 1.0 - float(tail) / float(trail_count + 1)
				_stamp(SPARKLE, behind, Vector2.ONE * edge * (0.40 + taper * 0.50),
					Color(spark_tint, fade * taper * 0.70), angle)
			_stamp(SPARKLE, point, Vector2.ONE * edge, Color(spark_tint, fade * flicker), angle + age * 0.35)
			_stamp(SPARKLE, point, Vector2.ONE * edge * 0.35, Color(1.0, 0.98, 0.84, fade * flicker * 0.90), -angle)


func _firework_precomputed_trajectory(direction: Vector2, phase: float, phase_sine: float,
		reach: float, release: float, falling_age: float, drop: float, burst_only: bool) -> Vector2:
	var spread: Vector2 = direction * reach * (0.72 + phase * 0.28) * release
	if burst_only:
		return spread
	var drift: float = phase_sine * reach * 0.035 * falling_age
	return spread + Vector2(drift, drop)


func _firework_delay(level: int, group: int) -> float:
	if group == 0:
		return 0.0
	match level:
		4: return 0.10 + float(group - 1) * 0.045
		5: return 0.10 + float(group - 1) * 0.075
		6: return 0.08 + float(group - 1) * 0.043
		7: return 0.07 + float(group - 1) * 0.037
		8: return 0.055 + float(group - 1) * 0.038
		9: return 0.05 + float(group - 1) * 0.038
	return 0.0


func _firework_reach(level: int, group: int) -> float:
	if group == 0:
		return 0.96 if level == 4 else 0.84
	return 0.43 if level == 4 else 0.49


func _firework_trajectory(angle: float, age: float, phase: float, reach: float, level: int, burst_only: bool = false) -> Vector2:
	# Fast release loses radial speed to drag. Gravity then wins, making the last
	# beat visibly descend instead of merely fading an expanded star pattern.
	var release: float = 1.0 - exp(-age * 5.0)
	var direction: Vector2 = Vector2.from_angle(angle)
	var spread: Vector2 = direction * reach * (0.72 + phase * 0.28) * release
	if burst_only:
		return spread
	var falling_age: float = maxf(0.0, age - 0.16)
	var drop: float = reach * falling_age * falling_age * (0.115 if level == 5 else 0.095)
	var drift: float = sin(phase * TAU) * reach * 0.035 * falling_age
	return spread + Vector2(drift, drop)
