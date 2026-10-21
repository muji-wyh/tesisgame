extends Control
## Noninteractive, collection-clock effects made from acquired particle textures.

const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const MAX_ACTIVE: int = 12
const PROFILES: Array[Dictionary] = [
	{"name": "Pearl pop", "pattern": "pearl", "seconds": 0.46, "radius": 38.0, "sparks": 7, "bursts": 1, "hue": 0.44},
	{"name": "Twin ripple", "pattern": "ripple", "seconds": 0.64, "radius": 52.0, "sparks": 12, "bursts": 2, "hue": 0.49},
	{"name": "Spiral lift", "pattern": "spiral", "seconds": 0.82, "radius": 68.0, "sparks": 20, "bursts": 1, "hue": 0.67},
	{"name": "Firework bloom", "pattern": "firework", "seconds": 1.02, "radius": 91.0, "sparks": 32, "bursts": 1, "hue": 0.10},
	{"name": "Double bloom", "pattern": "double", "seconds": 1.18, "radius": 107.0, "sparks": 40, "bursts": 2, "hue": 0.92},
	{"name": "Comet crown", "pattern": "crown", "seconds": 1.30, "radius": 121.0, "sparks": 48, "bursts": 1, "hue": 0.53},
	{"name": "Aurora orbit", "pattern": "orbit", "seconds": 1.43, "radius": 136.0, "sparks": 58, "bursts": 2, "hue": 0.72},
	{"name": "Constellation shower", "pattern": "constellation", "seconds": 1.58, "radius": 151.0, "sparks": 70, "bursts": 3, "hue": 0.12},
	{"name": "Grand bouquet", "pattern": "bouquet", "seconds": 1.80, "radius": 173.0, "sparks": 90, "bursts": 5, "hue": 0.08},
]

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
	var result: Dictionary = PROFILES[clampi(level, 1, 9) - 1].duplicate(true)
	result["level"] = clampi(level, 1, 9)
	result["cue"] = cue_for_level(level)
	return result


static func cue_for_level(level: int) -> String:
	return "pop" if level <= 1 else "jelly-collect-lv%d" % clampi(level, 2, 9)


func configure_layout(available: Rect2, ui_scale: float = 1.0) -> void:
	position = available.position
	size = available.size.max(Vector2.ZERO)
	_ui_scale = maxf(0.25, ui_scale)
	queue_redraw()


func present(origin: Vector2, level: int, accent: Color, batch: bool = false,
		initial_age: float = 0.0, delay: float = 0.0) -> void:
	if not origin.is_finite() or not is_finite(initial_age) or not is_finite(delay):
		return
	var selected: Dictionary = profile(level)
	var duration: float = float(selected.seconds)
	if batch:
		duration = minf(duration * 0.72, 0.84)
	if _reduced_motion:
		duration = 0.42
	var wait: float = maxf(0.0, delay)
	if initial_age >= wait + duration:
		return
	_serial += 1
	_entries.append({"id": _serial, "origin": origin - position, "profile": selected,
		"accent": accent, "batch": batch, "elapsed": maxf(0.0, initial_age),
		"delay": wait, "duration": duration})
	while _entries.size() > MAX_ACTIVE:
		_entries.pop_front()
	show()
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
		states.append({"id": entry.id, "level": entry.profile.level, "name": entry.profile.name,
			"pattern": entry.profile.pattern, "cue": entry.profile.cue, "batch": entry.batch,
			"elapsed": entry.elapsed, "delay": entry.delay, "popped": float(entry.elapsed) >= float(entry.delay),
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
	if level >= 8:
		hue += [0.0, 0.40, 0.61, 0.84][posmod(index, 4)]
	elif level >= 4:
		hue += 0.12 * float(posmod(index, 3) - 1)
	var color := Color.from_hsv(fposmod(hue, 1.0), 0.69, 0.95)
	return color.lerp(entry.accent, 0.16 if level < 4 else 0.06)


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
			Color(_palette(entry, 1), peak * (0.52 if level < 8 else 0.78)), progress * 0.28)
	for index in range(count):
		var slot: float = float(index) / float(count)
		var phase: float = float(posmod(index * 7, 11)) / 11.0
		var group: int = index % int(entry.profile.bursts)
		var delay: float = _burst_delay(pattern, group)
		var p: float = clampf((progress - delay) / (1.0 - delay), 0.0, 1.0)
		if p <= 0.0:
			continue
		var angle: float = slot * TAU - PI * 0.5 + float(entry.id % 7) * 0.17
		var base: Vector2 = origin + _burst_offset(pattern, group, radius)
		var point: Vector2 = base + _trajectory(pattern, angle, p, phase, group, radius)
		var fade: float = smoothstep(0.0, 0.025, p) * (1.0 - smoothstep(0.42 + phase * 0.19, 1.0, p))
		var edge: float = (6.2 + float(level) * 0.62 + phase * 4.0) / _ui_scale
		edge *= lerpf(1.10, 0.45, p)
		var tint: Color = _palette(entry, index)
		if level >= 4:
			# Repeated texture stamps form luminous spark trails, never line stand-ins.
			var trail_count: int = 3 if level < 8 else 5
			for tail in range(trail_count, 0, -1):
				var previous: float = maxf(0.0, p - float(tail) * 0.022)
				var behind: Vector2 = base + _trajectory(pattern, angle, previous, phase, group, radius)
				var tail_alpha: float = fade * (1.0 - float(tail) / float(trail_count + 1)) * 0.36
				_stamp(SPARKLE, behind, Vector2.ONE * edge * 0.66, Color(tint, tail_alpha), angle)
		_stamp(SPARKLE, point, Vector2.ONE * edge, Color(tint, fade), angle + p * 0.45)
		if level >= 6 and index % 5 == 0:
			_stamp(SPARKLE, point, Vector2.ONE * edge * 0.45, Color(1.0, 0.98, 0.81, fade * 0.88), -angle)
	if level >= 5:
		_draw_satellite_peaks(entry, progress, radius)


func _burst_delay(pattern: String, group: int) -> float:
	match pattern:
		"ripple": return float(group) * 0.22
		"double": return float(group) * 0.24
		"orbit": return float(group) * 0.10
		"constellation": return float(group) * 0.13
		"bouquet": return float(group) * 0.095
	return 0.0


func _burst_offset(pattern: String, group: int, radius: float) -> Vector2:
	match pattern:
		"double": return Vector2(-0.18 if group == 0 else 0.21, -float(group) * 0.22) * radius
		"constellation": return Vector2.from_angle(-PI * 0.5 + float(group) * TAU / 3.0) * radius * 0.34
		"bouquet":
			if group > 0:
				return Vector2.from_angle(-PI * 0.5 + float(group - 1) * TAU / 4.0) * radius * 0.43
	return Vector2.ZERO


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
		"crown":
			var crown_angle: float = lerpf(-PI * 0.94, -PI * 0.06, fposmod(angle / TAU + 0.25, 1.0))
			return Vector2.from_angle(crown_angle) * reach * release + Vector2.DOWN * radius * p * p * 0.62
		"orbit":
			return Vector2.from_angle(angle + p * (2.1 if group == 0 else -2.1)) * reach * release * Vector2(1.0, 0.62)
		"constellation":
			return direction * reach * 0.63 * release + Vector2.DOWN * radius * p * p * 0.34
		"bouquet":
			return direction * reach * (0.80 if group == 0 else 0.48) * release + Vector2.DOWN * radius * p * p * 0.40
	# Fireworks and the double bloom expand rapidly, then their embers curve down.
	return direction * reach * release + Vector2.DOWN * radius * p * p * 0.34


func _draw_satellite_peaks(entry: Dictionary, progress: float, radius: float) -> void:
	var pattern: String = str(entry.profile.pattern)
	for group in range(1, int(entry.profile.bursts)):
		var age: float = progress - _burst_delay(pattern, group)
		if age < 0.0:
			continue
		var peak: float = smoothstep(0.0, 0.025, age) * (1.0 - smoothstep(0.045, 0.20, age))
		var point: Vector2 = entry.origin + _burst_offset(pattern, group, radius)
		_stamp(GLOW, point, Vector2.ONE * radius * 0.60, Color(_palette(entry, group), peak * 0.52))
		_stamp(RAYS, point, Vector2.ONE * radius * (0.6 + age * 1.4), Color(_palette(entry, group), peak * 0.65), age * 0.8)
