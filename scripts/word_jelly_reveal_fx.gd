extends Control
## Sourced light and spark artwork framing a collected word's reading card.

const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const STAR = preload("res://assets/chests/milestone/sparkle.png")
const WordModel = preload("res://scripts/word_jelly_model.gd")
const FIREWORK_SECONDS: float = 1.95
const PROFILES: Array[Dictionary] = [
	{"name": "Pearl greeting", "pattern": "pearl", "sparks": 12, "bursts": 1, "hue": 0.43, "margin": 16.0},
	{"name": "Crystal ripple", "pattern": "ripple", "sparks": 20, "bursts": 2, "hue": 0.51, "margin": 23.0},
	{"name": "Sapphire spiral", "pattern": "spiral", "sparks": 32, "bursts": 1, "hue": 0.65, "margin": 32.0},
	{"name": "Golden fireworks", "pattern": "fireworks", "sparks": 48, "bursts": 3, "hue": 0.11, "margin": 44.0,
		"trails": 5, "radius": 72.0},
	{"name": "Double cascade", "pattern": "cascade", "sparks": 72, "bursts": 4, "hue": 0.93, "margin": 56.0,
		"trails": 6, "radius": 92.0},
	{"name": "Prismatic bouquet", "pattern": "bouquet", "sparks": 120, "bursts": 6, "hue": 0.10, "margin": 72.0,
		"trails": 7, "radius": 116.0},
]

var level: int = 1
var elapsed: float = 0.0
var anticipation_seconds: float = 0.0
var duration: float = 1.95
var reduced_motion: bool = false
var _batch: bool = false
var _ui_scale: float = 1.0
var _margin: float = 6.0
var _card := Rect2()
var _accent := Color.WHITE
var _exclusions: Array[Rect2] = []


func _init() -> void:
	name = "CollectedWordLevelFX"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	# All concurrent reading surfaces stay above every card's wider fireworks.
	z_index = -1


static func profile(value: int) -> Dictionary:
	return PROFILES[clampi(value, 1, WordModel.MAX_MERGE_LEVEL) - 1].duplicate(true)


static func duration_for(reading_seconds: float, value: int) -> float:
	return maxf(reading_seconds, FIREWORK_SECONDS) if value >= 4 else reading_seconds


static func margin_for(value: int, batch: bool, ui_scale: float) -> float:
	return float(PROFILES[clampi(value, 1, WordModel.MAX_MERGE_LEVEL) - 1].margin) * (0.68 if batch else 1.0) / ui_scale


func configure(card_size: Vector2, ui_scale: float, value: int, accent: Color, batch: bool, margin: float) -> void:
	level = clampi(value, 1, WordModel.MAX_MERGE_LEVEL)
	_ui_scale = maxf(0.5, ui_scale)
	_batch = batch
	_accent = accent
	_margin = maxf(0.0, margin)
	position = -Vector2.ONE * _margin
	size = card_size + Vector2.ONE * _margin * 2.0
	_card = Rect2(Vector2.ONE * _margin, card_size)
	_exclusions.clear()
	queue_redraw()


func fit_area(available: Rect2, exclusions: Array[Rect2]) -> void:
	if level < 4:
		return
	# Fireworks can use the reading region without shrinking the word to buy space.
	position = available.position
	size = available.size
	_card.position = -position
	_exclusions.clear()
	for exclusion: Rect2 in exclusions:
		_exclusions.append(Rect2(exclusion.position - position, exclusion.size))
	queue_redraw()


func sync(age: float, seconds: float, steady: bool, anticipation: float = 0.0) -> void:
	elapsed = age
	anticipation_seconds = anticipation
	duration = seconds
	reduced_motion = steady
	queue_redraw()


func color_at(index: int = 0) -> Color:
	var hue: float = float(PROFILES[level - 1].hue)
	if level == WordModel.MAX_MERGE_LEVEL:
		hue += [0.0, 0.39, 0.62, 0.85][posmod(index, 4)]
	elif level >= 4:
		hue += [0.0, 0.40, 0.78][posmod(index, 3)]
	elif level == 3:
		hue += [0.0, -0.16, 0.20][posmod(index, 3)]
	return Color.from_hsv(fposmod(hue, 1.0), 0.78, 1.0).lerp(_accent, 0.12 if level < 4 else 0.03)


func _stamp(texture: Texture2D, point: Vector2, extent: Vector2, color: Color, angle: float = 0.0) -> void:
	if color.a <= 0.002 or extent.x <= 0.0 or extent.y <= 0.0:
		return
	var fit: float = _stamp_fit(point, extent, angle)
	if fit <= 0.0:
		return
	var fitted: Vector2 = extent * fit
	draw_set_transform(point, angle)
	draw_texture_rect(texture, Rect2(fitted * -0.5, fitted), false, color)


func _stamp_fit(point: Vector2, extent: Vector2, angle: float) -> float:
	# Fit the rotated artwork itself, including its corners, to the reserved halo.
	var half: Vector2 = extent * 0.5
	var rotated := Vector2(absf(cos(angle)) * half.x + absf(sin(angle)) * half.y,
		absf(sin(angle)) * half.x + absf(cos(angle)) * half.y)
	var room: Vector2 = point.min(size - point).max(Vector2.ZERO)
	var fit: float = minf(1.0, minf(room.x / maxf(rotated.x, 0.001), room.y / maxf(rotated.y, 0.001)))
	for exclusion: Rect2 in _exclusions:
		if exclusion.has_point(point):
			return 0.0
		# Keep the entire rotated stamp clear of Finish and other live controls.
		var gap := Vector2(maxf(exclusion.position.x - point.x, point.x - exclusion.end.x),
			maxf(exclusion.position.y - point.y, point.y - exclusion.end.y))
		var clearance: float = maxf(gap.x / maxf(rotated.x, 0.001), gap.y / maxf(rotated.y, 0.001))
		fit = minf(fit, clearance)
	return clampf(fit, 0.0, 1.0)


func _rim(angle: float, offset: float = 0.0) -> Vector2:
	var direction := Vector2.from_angle(angle)
	var half: Vector2 = _card.size * 0.5
	var reach: float = minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
	return _card.get_center() + direction * (reach + offset)


func _burst_angle(group: int) -> float:
	return -PI * 0.75 + float(group) * TAU / float(PROFILES[level - 1].bursts)


func _burst_origin(group: int) -> Vector2:
	var radius: float = _firework_radius()
	var vertical: float = _firework_vertical_scale()
	var point: Vector2 = _rim(_burst_angle(group), radius * 0.32)
	# Keep the large flowers inside the cosmetic canvas, clear of its hard edges.
	var start := Vector2(radius * 1.32, radius * vertical * 0.80)
	var end := size - Vector2(radius * 1.32, radius * vertical * 1.65)
	return point.clamp(start.min(size * 0.5), end.max(size * 0.5))


func _firework_radius() -> float:
	# Reading padding cannot cap the celebration or shrink automatic pickups.
	var pixels: float = float(PROFILES[level - 1].get("radius", 0.0))
	return minf(pixels / _ui_scale, size.x * 0.28)


func _firework_vertical_scale() -> float:
	# Short landscapes retain broad blooms while leaving room for their descent.
	return minf(1.0, size.y / maxf(1.0, _firework_radius() * 3.3))


func _edge_light(fade: float, clock: float) -> void:
	# Broad artwork on each edge remains visible behind the opaque reading card.
	for side in range(4):
		var angle: float = PI * 0.5 * float(side)
		var point: Vector2 = _rim(angle, _margin * 0.07)
		var extent: Vector2 = Vector2(_margin * 1.9, _card.size.y * 1.15) if side % 2 == 0 \
			else Vector2(_card.size.x * 1.1, _margin * 1.9)
		var breathing: float = 0.84 + 0.16 * sin(clock * 5.0 + side)
		_stamp(GLOW, point, extent, Color(color_at(side), fade * breathing))


func _draw() -> void:
	if _card.size.x <= 0.0 or duration <= 0.0:
		return
	if elapsed < 0.0:
		if anticipation_seconds > 0.0 and elapsed >= -anticipation_seconds:
			if reduced_motion:
				_draw_steady(1.0)
			else:
				_draw_charge(clampf(1.0 + elapsed / anticipation_seconds, 0.0, 1.0))
		draw_set_transform(Vector2.ZERO)
		return
	var fade: float = (1.0 if anticipation_seconds > 0.0 else smoothstep(0.0, 0.055, elapsed)) \
		* (1.0 - smoothstep(duration - (0.22 if _batch and level < 4 else 0.31), duration, elapsed))
	if fade <= 0.0:
		return
	if reduced_motion:
		_draw_steady(fade)
	else:
		_draw_release(fade)
		_draw_celebration(fade)
	draw_set_transform(Vector2.ZERO)


func _draw_charge(progress: float) -> void:
	var contraction: float = smoothstep(0.06, 1.0, progress)
	var center: Vector2 = _card.get_center()
	var body: Vector2 = _card.size * Vector2.ONE.lerp(Vector2(0.40, 0.50), contraction)
	var strength: float = smoothstep(0.0, 0.22, progress)
	_stamp(GLOW, center, body + Vector2.ONE * _margin * (1.7 - contraction * 0.45),
		Color(color_at(), strength * (0.46 + contraction * 0.38)), progress * 0.22)
	# Staggered inward streams accelerate into a single bright core.
	var count: int = 8 + level * 3 if not _batch else 8 + level
	for index in range(count):
		var phase: float = float(index % 4) * 0.055
		var pull: float = smoothstep(phase, 1.0, progress)
		var angle: float = TAU * float(index) / float(count) + pull * 0.55
		var outside: Vector2 = _rim(angle, _margin * 0.65)
		var point: Vector2 = center.lerp(outside, lerpf(1.0, 0.18, pull))
		var edge: float = (8.0 + level * 0.8 + (index % 3) * 1.3) / _ui_scale
		var tint: Color = color_at(index)
		for tail in range(3, 0, -1):
			var behind: Vector2 = center.lerp(outside, lerpf(1.0, 0.18, maxf(0.0, pull - tail * 0.045)))
			_stamp(STAR, behind, Vector2(edge * (1.4 - tail * 0.23), edge * 0.38),
				Color(tint, strength * (0.50 - tail * 0.10)), angle)
		_stamp(STAR, point, Vector2.ONE * edge, Color(tint, strength * 0.95), angle + progress)
	_stamp(RAYS, center, body + Vector2.ONE * _margin * 1.25,
		Color(color_at(1), contraction * strength * 0.80), -progress * 0.32)


func _draw_release(fade: float) -> void:
	# The compact core opens into the reserved halo before the card settles.
	var life: float = minf(0.30, duration * 0.64) if _batch and level < 4 else 0.64
	if elapsed >= life:
		return
	var progress: float = clampf(elapsed / life, 0.0, 1.0)
	var launch: float = 1.0 - pow(1.0 - clampf(elapsed / 0.17, 0.0, 1.0), 3.0)
	var opacity: float = fade * (1.0 - smoothstep(0.20, 1.0, progress))
	var center: Vector2 = _card.get_center()
	_stamp(RAYS, center, (_card.size + Vector2.ONE * _margin * 1.9) * lerpf(0.40, 1.0, launch),
		Color(color_at(1), opacity * 0.90), 0.12 + progress * 0.10)
	_edge_light(opacity * (0.50 + level * 0.04), 0.0)
	var count: int = 10 + level * 3 if not _batch else 8 + level
	for index in range(count):
		var angle: float = TAU * float(index) / float(count) - PI * 0.5
		var target: Vector2 = _rim(angle, _margin * (0.55 + float(index % 3) * 0.08))
		var point: Vector2 = center.lerp(target, lerpf(0.22, 1.0, launch))
		var stem: Vector2 = center.lerp(target, lerpf(0.18, 0.88, launch))
		var trail: Vector2 = point - stem
		var edge: float = (8.5 + level * 0.8 + float(index % 3)) / _ui_scale
		var tint: Color = color_at(index)
		_stamp(STAR, stem.lerp(point, 0.5), Vector2(trail.length() * 1.7, edge * 0.56),
			Color(tint, opacity * 0.86), angle)
		_stamp(STAR, point, Vector2.ONE * edge * (1.0 - progress * 0.30), Color(tint, opacity), angle)
		_stamp(STAR, point, Vector2.ONE * edge * 0.30, Color(1.0, 0.99, 0.91, opacity))


func _draw_steady(fade: float) -> void:
	# Tier color and a still star setting retain the achievement without travel.
	var tint: Color = color_at()
	_stamp(GLOW, _card.get_center(), _card.size + Vector2.ONE * _margin * 1.6, Color(tint, fade * 0.42))
	if level >= 4:
		_edge_light(fade * (0.26 + level * 0.025), 0.0)
	var count: int = 2 + level
	for index in range(count):
		var angle: float = TAU * float(index) / float(count) - PI * 0.5
		_stamp(STAR, _rim(angle, _margin * 0.35), Vector2.ONE * (5.0 + level * 0.65) / _ui_scale,
			Color(color_at(index), fade * 0.88), angle)


func _spark_count() -> int:
	var count: int = int(PROFILES[level - 1].sparks)
	return maxi(3, roundi(count * 0.62)) if _batch else count


func _trail_count() -> int:
	return int(PROFILES[level - 1].get("trails", 0))


func _emission_span() -> float:
	# Automatic collection keeps the full bloom and descent at a lighter density.
	return [0.0, 0.0, 0.0, 0.16, 0.38, 0.48][level - 1]


func _draw_celebration(fade: float) -> void:
	if level >= 4:
		_draw_explosion(fade)
		return
	var clock: float = elapsed / (minf(0.48, duration * 0.8) if _batch else 1.28)
	var launch: float = smoothstep(0.0, 0.08, clock)
	var glow: float = (0.38 + float(level) * 0.055) * fade * (1.0 - smoothstep(0.35, 1.10, clock) * 0.65)
	_stamp(GLOW, _card.get_center(), _card.size + Vector2.ONE * _margin * 1.9, Color(color_at(), glow))
	if level == 2:
		for wave in range(2):
			var ripple: float = clampf((clock - float(wave) * 0.16) / 0.60, 0.0, 1.0)
			_stamp(GLOW, _card.get_center(), _card.size + Vector2.ONE * _margin * ripple * 2.0,
				Color(color_at(wave), sin(ripple * PI) * fade * 0.40))
	if level == 3:
		var rays_alpha: float = fade * launch * (1.0 - smoothstep(0.30, 0.95, clock))
		_stamp(RAYS, _card.get_center(), _card.size + Vector2.ONE * _margin * 2.0,
			Color(color_at(1), rays_alpha * 0.84), clock * 0.12)
	var count: int = _spark_count()
	for index in range(count):
		var phase: float = float(posmod(index * 7, 13)) / 13.0
		var edge: float = (7.0 + level * 0.9 + phase * 3.8) / _ui_scale
		var angle: float = TAU * float(index) / float(count) - PI * 0.5
		var turn: float = clock * (1.15 if level == 3 else 0.60)
		var point: Vector2 = _rim(angle + turn, _margin * (0.25 + phase * 0.47) * launch)
		var opacity: float = fade * launch * (0.74 + 0.26 * sin(phase * TAU + clock * 4.0))
		_stamp(STAR, point, Vector2.ONE * edge, Color(color_at(index), opacity), angle + turn)


func _firework_point(origin: Vector2, direction: Vector2, reach: float, age: float, life: float) -> Vector2:
	# Radial drag opens a broad flower; gravity overtakes even its upward spokes.
	var time: float = clampf(age / life, 0.0, 1.0)
	var travel: float = (1.0 - exp(-time * 4.5)) / (1.0 - exp(-4.5))
	var falling: float = maxf(0.0, (time - 0.08) / 0.92)
	var spread: Vector2 = direction * Vector2(1.16, 0.88) * reach * travel
	var drop: float = reach * 1.40 * falling * falling
	var offset: Vector2 = spread + Vector2(direction.x * reach * 0.045 * time * time, drop)
	offset.y *= _firework_vertical_scale()
	return origin + offset


func _draw_explosion(fade: float) -> void:
	var selected: Dictionary = PROFILES[level - 1]
	var groups: int = int(selected.bursts)
	var span: float = _emission_span()
	var count: int = _spark_count()
	var trails: int = _trail_count()
	for group in range(groups):
		var spokes: int = count / groups + (1 if group < count % groups else 0)
		var delay: float = span * float(group) / float(maxi(1, groups - 1))
		var age: float = elapsed - delay
		var life: float = minf(1.72, duration - delay - 0.08)
		if age <= 0.0 or age >= life:
			continue
		var origin: Vector2 = _burst_origin(group)
		var radius: float = _firework_radius() * (0.96 + float(group % 2) * 0.06)
		var tint: Color = color_at(group)
		var opening: float = smoothstep(0.0, 0.012, age) * (1.0 - smoothstep(0.025, life * 0.27, age))
		_stamp(GLOW, origin, Vector2.ONE * radius * 1.5, Color(tint, opening * fade * 0.55))
		_stamp(RAYS, origin, Vector2.ONE * radius * (0.7 + smoothstep(0.0, life * 0.2, age)),
			Color(tint, opening * fade * 0.8), group * 0.7)
		for spoke in range(spokes):
			var phase: float = float(posmod(spoke * 7 + group * 3, 13)) / 13.0
			var angle: float = TAU * float(spoke) / float(spokes) + group * 0.43
			var direction := Vector2.from_angle(angle)
			# The alternating inner and outer petals share one unmistakable origin.
			var reach: float = radius * (0.72 + phase * 0.28)
			var point: Vector2 = _firework_point(origin, direction, reach, age, life)
			var opacity: float = fade * smoothstep(0.0, 0.015, age) * (1.0 - smoothstep(life * 0.68, life, age))
			var edge: float = minf((9.0 + level * 0.75 + phase * 3.5) * 1.30 / _ui_scale, radius * 0.38)
			var ember: Color = tint.lerp(Color(1.0, 0.78, 0.32), smoothstep(life * 0.5, life, age) * 0.55)
			# Consecutive trajectory samples bend the tail with the falling tip;
			# a line back toward the burst would pin late embers into radial spokes.
			for tail in range(trails, 0, -1):
				var previous_age: float = age - float(tail) * life * 0.045
				if previous_age <= 0.0:
					continue
				var behind: Vector2 = _firework_point(origin, direction, reach, previous_age, life)
				var ahead: Vector2 = _firework_point(origin, direction, reach, previous_age + life * 0.045, life)
				var strength: float = 1.0 - float(tail) / float(trails + 1)
				var tangent: Vector2 = ahead - behind
				_stamp(STAR, behind.lerp(ahead, 0.5),
					Vector2(tangent.length() * 1.65 + edge * 0.30, edge * (0.25 + strength * 0.26)),
					Color(ember, opacity * strength * 0.86), tangent.angle())
			var shrink: float = lerpf(1.0, 0.56, smoothstep(life * 0.2, life, age))
			_stamp(STAR, point, Vector2.ONE * edge * shrink, Color(ember, opacity), angle)
			_stamp(STAR, point, Vector2.ONE * edge * shrink * 0.32, Color(1.0, 0.99, 0.86, opacity))


func snapshot() -> Dictionary:
	var selected: Dictionary = PROFILES[level - 1]
	var rect: Rect2 = get_global_rect()
	return {"level": level, "name": selected.name, "pattern": selected.pattern,
		"elapsed": elapsed, "duration": duration,
		"visible": is_visible_in_tree() and elapsed >= -anticipation_seconds and elapsed < duration,
		"phase": "charging" if elapsed < 0.0 else ("release" if elapsed < 0.10 else "settling"),
		"spark_count": _spark_count(), "wave_count": selected.bursts,
		"trail_count": _trail_count(), "emission_seconds": _emission_span() if level >= 4 else 0.0,
		"bloom_radius": _firework_radius() if level >= 4 else 0.0,
		"vertical_scale": _firework_vertical_scale() if level >= 4 else 1.0,
		"burst_count": selected.bursts, "reduced_motion": reduced_motion,
		"input_transparent": mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}
