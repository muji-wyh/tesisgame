extends Control
## Noninteractive, collection-clock effects made from acquired particle textures.

const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const MAX_ACTIVE: int = 12
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
var _reduced_motion: bool = false
var _ui_scale: float = 1.0
var _serial: int = 0


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


func present(origin: Vector2, level: int, accent: Color, batch: bool = false,
		initial_age: float = 0.0, delay: float = 0.0, anchor_id: String = "") -> void:
	if not origin.is_finite() or not is_finite(initial_age) or not is_finite(delay):
		return
	var selected: Dictionary = profile(level)
	var duration: float = float(selected.seconds)
	if batch:
		duration *= 0.75
	if _reduced_motion:
		duration = 0.42
	var wait: float = maxf(0.0, delay)
	if initial_age >= wait + duration:
		return
	_serial += 1
	_entries.append({"id": _serial, "origin": origin - position, "profile": selected,
		"accent": accent, "batch": batch, "elapsed": maxf(0.0, initial_age),
		"delay": wait, "duration": duration, "anchor_id": anchor_id})
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


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for index in range(_entries.size() - 1, -1, -1):
		_entries[index].elapsed += delta
		if float(_entries[index].elapsed) >= float(_entries[index].delay) + float(_entries[index].duration):
			_entries.remove_at(index)
	visible = not _entries.is_empty()
	queue_redraw()


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	queue_redraw()


func reset() -> void:
	_entries.clear()
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
			"reduced_motion": _reduced_motion})
	return {"visible": visible and not states.is_empty(), "active_count": states.size(),
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
	draw_set_transform(Vector2.ZERO)


func _radius(entry: Dictionary) -> float:
	var requested: float = float(entry.profile.radius) / _ui_scale
	if bool(entry.batch):
		requested *= 0.66
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
	_stamp(GLOW, origin, Vector2.ONE * radius * lerpf(0.55, 2.1, progress), Color(_palette(entry, 0), peak * 0.34))
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


func _draw_fireworks(entry: Dictionary, progress: float) -> void:
	var radius: float = _radius(entry)
	var level: int = int(entry.profile.level)
	var group_count: int = int(entry.profile.bursts)
	var count: int = int(entry.profile.sparks)
	if bool(entry.batch):
		count = roundi(float(count) * 0.45)
	var main_count: int = roundi(float(count) * (0.50 if level == 4 else 0.34))
	var secondary_count: int = maxi(5, (count - main_count) / (group_count - 1))
	# Every colored layer launches from the collected body, including delayed blooms.
	for group in range(group_count):
		var delay: float = _firework_delay(level, group)
		var age: float = (progress - delay) * float(entry.profile.seconds)
		if age < 0.0:
			continue
		var life: float = (1.0 - delay) * float(entry.profile.seconds)
		var base: Vector2 = entry.origin
		var reach: float = radius * _firework_reach(level, group)
		var spokes: int = main_count if group == 0 else secondary_count
		var tint: Color = _palette(entry, group)
		var peak: float = (1.0 - smoothstep(0.05, 0.38, age)) * (0.85 + smoothstep(0.0, 0.035, age) * 0.15)
		_stamp(GLOW, base, Vector2.ONE * reach * (0.55 + minf(age, 0.4) * 2.0), Color(tint, peak * 0.32))
		_stamp(RAYS, base, Vector2.ONE * reach * (0.60 + minf(age, 0.35) * 2.2), Color(tint, peak * 0.48), group * 0.37)
		for index in range(spokes):
			var phase: float = float(posmod(index * 7 + group * 3, 13)) / 13.0
			var angle: float = TAU * float(index) / float(spokes) - PI * 0.5 + group * 0.38 + float(entry.id % 7) * 0.09
			var point: Vector2 = base + _firework_trajectory(angle, age, phase, reach, level)
			var fade: float = 1.0 - smoothstep(life * (0.60 + phase * 0.10), life, age)
			# Ember flicker changes luminance, not trajectory or visibility ownership.
			var flicker: float = lerpf(1.0, 0.90 + 0.10 * sin(age * 12.0 + phase * TAU), smoothstep(0.55, 1.4, age))
			var edge: float = (12.0 + phase * 4.0 + float(level - 4) * 0.8) / _ui_scale
			edge *= lerpf(1.08, 0.62, clampf(age / life, 0.0, 1.0))
			var spark_tint: Color = tint.lerp(_palette(entry, group + 1), 0.18 if index % 3 == 0 else 0.0)
			var trail_count: int = 3 if bool(entry.batch) else mini(10, 7 + level - 4)
			for tail in range(trail_count, 0, -1):
				var prior_age: float = age - float(tail) * 0.05
				if prior_age < 0.0:
					continue
				var behind: Vector2 = base + _firework_trajectory(angle, prior_age, phase, reach, level)
				var taper: float = 1.0 - float(tail) / float(trail_count + 1)
				_stamp(SPARKLE, behind, Vector2.ONE * edge * (0.40 + taper * 0.50),
					Color(spark_tint, fade * taper * 0.70), angle)
			_stamp(SPARKLE, point, Vector2.ONE * edge, Color(spark_tint, fade * flicker), angle + age * 0.35)
			_stamp(SPARKLE, point, Vector2.ONE * edge * 0.35, Color(1.0, 0.98, 0.84, fade * flicker * 0.90), -angle)


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


func _firework_trajectory(angle: float, age: float, phase: float, reach: float, level: int) -> Vector2:
	# Fast release loses radial speed to drag. Gravity then wins, making the last
	# beat visibly descend instead of merely fading an expanded star pattern.
	var release: float = 1.0 - exp(-age * 5.0)
	var direction: Vector2 = Vector2.from_angle(angle)
	var spread: Vector2 = direction * reach * (0.72 + phase * 0.28) * release
	var falling_age: float = maxf(0.0, age - 0.16)
	var drop: float = reach * falling_age * falling_age * (0.115 if level == 5 else 0.095)
	var drift: float = sin(phase * TAU) * reach * 0.035 * falling_age
	return spread + Vector2(drift, drop)
