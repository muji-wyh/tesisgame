extends Control
## Sourced light and spark artwork framing a collected word's reading card.

const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const STAR = preload("res://assets/chests/milestone/sparkle.png")
const WordModel = preload("res://scripts/word_jelly_model.gd")
const PROFILES: Array[Dictionary] = [
	{"name": "Pearl greeting", "pattern": "pearl", "sparks": 3, "bursts": 1, "hue": 0.43, "margin": 6.0},
	{"name": "Crystal ripple", "pattern": "ripple", "sparks": 9, "bursts": 2, "hue": 0.51, "margin": 9.0},
	{"name": "Sapphire spiral", "pattern": "spiral", "sparks": 18, "bursts": 1, "hue": 0.65, "margin": 12.0},
	{"name": "Golden fireworks", "pattern": "fireworks", "sparks": 32, "bursts": 2, "hue": 0.11, "margin": 38.0,
		"trails": 2},
	{"name": "Double cascade", "pattern": "cascade", "sparks": 56, "bursts": 4, "hue": 0.93, "margin": 48.0,
		"trails": 3},
	{"name": "Prismatic bouquet", "pattern": "bouquet", "sparks": 120, "bursts": 6, "hue": 0.10, "margin": 68.0,
		"trails": 5},
]

var level: int = 1
var elapsed: float = 0.0
var duration: float = 1.95
var reduced_motion: bool = false
var _batch: bool = false
var _ui_scale: float = 1.0
var _margin: float = 6.0
var _card := Rect2()
var _accent := Color.WHITE


func _init() -> void:
	name = "CollectedWordLevelFX"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true


static func profile(value: int) -> Dictionary:
	return PROFILES[clampi(value, 1, WordModel.MAX_MERGE_LEVEL) - 1].duplicate(true)


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
	queue_redraw()


func sync(age: float, seconds: float, steady: bool) -> void:
	elapsed = age
	duration = seconds
	reduced_motion = steady
	queue_redraw()


func color_at(index: int = 0) -> Color:
	var hue: float = float(PROFILES[level - 1].hue)
	if level == WordModel.MAX_MERGE_LEVEL:
		hue += [0.0, 0.39, 0.62, 0.85][posmod(index, 4)]
	elif level >= 4:
		hue += [0.0, -0.08, 0.13][posmod(index, 3)]
	return Color.from_hsv(fposmod(hue, 1.0), 0.70, 1.0).lerp(_accent, 0.18 if level < 4 else 0.03)


func _stamp(texture: Texture2D, point: Vector2, extent: Vector2, color: Color, angle: float = 0.0) -> void:
	if color.a <= 0.002 or extent.x <= 0.0 or extent.y <= 0.0:
		return
	# Fit the rotated artwork itself, including its corners, to the reserved halo.
	var half: Vector2 = extent * 0.5
	var rotated := Vector2(absf(cos(angle)) * half.x + absf(sin(angle)) * half.y,
		absf(sin(angle)) * half.x + absf(cos(angle)) * half.y)
	var room: Vector2 = point.min(size - point).max(Vector2.ZERO)
	var fit: float = minf(1.0, minf(room.x / maxf(rotated.x, 0.001), room.y / maxf(rotated.y, 0.001)))
	if fit <= 0.0:
		return
	var fitted: Vector2 = extent * fit
	draw_set_transform(point, angle)
	draw_texture_rect(texture, Rect2(fitted * -0.5, fitted), false, color)


func _rim(angle: float, offset: float = 0.0) -> Vector2:
	var direction := Vector2.from_angle(angle)
	var half: Vector2 = _card.size * 0.5
	var reach: float = minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
	return _card.get_center() + direction * (reach + offset)


func _burst_angle(group: int) -> float:
	return -PI * 0.75 + float(group) * TAU / float(PROFILES[level - 1].bursts)


func _burst_origin(group: int) -> Vector2:
	# Move each bloom into the halo so the reading surface cannot hide its peak.
	return _rim(_burst_angle(group), _margin * 0.36)


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
	var fade: float = smoothstep(0.0, 0.055, elapsed) * (1.0 - smoothstep(duration - (0.22 if _batch else 0.31), duration, elapsed))
	if fade <= 0.0:
		return
	if reduced_motion:
		_draw_steady(fade)
	else:
		_draw_celebration(fade)
	draw_set_transform(Vector2.ZERO)


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
	var count: int = int(PROFILES[level - 1].get("trails", 0))
	return mini(count, 3) if _batch else count


func _emission_span() -> float:
	# Echo the release quickly in batch cards; the board owns the extended tail.
	return 0.075 + level * 0.007 if _batch else [0.0, 0.0, 0.0, 0.16, 0.38, 0.48][level - 1]


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
		var edge: float = (5.0 + level * 0.8 + phase * 3.8) / _ui_scale
		var angle: float = TAU * float(index) / float(count) - PI * 0.5
		var turn: float = clock * (1.15 if level == 3 else 0.60)
		var point: Vector2 = _rim(angle + turn, _margin * (0.25 + phase * 0.47) * launch)
		var opacity: float = fade * launch * (0.60 + 0.40 * sin(phase * TAU + clock * 4.0))
		_stamp(STAR, point, Vector2.ONE * edge, Color(color_at(index), opacity), angle + turn)


func _firework_point(origin: Vector2, direction: Vector2, reach: float, age: float, life: float) -> Vector2:
	# A firework opens from one point, slows in air, then lets its embers fall.
	var time: float = clampf(age / life, 0.0, 1.0)
	var travel: float = (1.0 - exp(-time * 4.5)) / (1.0 - exp(-4.5))
	return origin + direction * reach * travel + Vector2(0.0, reach * 0.30 * time * time)


func _draw_explosion(fade: float) -> void:
	var selected: Dictionary = PROFILES[level - 1]
	var groups: int = int(selected.bursts)
	var span: float = _emission_span()
	var life: float = minf(0.36, duration - span) if _batch else 1.32
	var count: int = _spark_count()
	var trails: int = _trail_count()
	for group in range(groups):
		var spokes: int = count / groups + (1 if group < count % groups else 0)
		var age: float = elapsed - span * float(group) / float(maxi(1, groups - 1))
		if age <= 0.0 or age >= life:
			continue
		var origin: Vector2 = _burst_origin(group)
		var radius: float = _margin * (0.57 + float(group % 2) * 0.03)
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
			var opacity: float = fade * smoothstep(0.0, 0.015, age) * (1.0 - smoothstep(life * 0.55, life, age))
			var edge: float = minf((9.0 + level * 0.75 + phase * 3.5) / _ui_scale, radius * 0.38)
			var ember: Color = tint.lerp(Color(1.0, 0.78, 0.32), smoothstep(life * 0.5, life, age) * 0.55)
			var stem: Vector2 = _firework_point(origin, direction, reach, age * 0.32, life)
			var streak: Vector2 = point - stem
			_stamp(STAR, stem.lerp(point, 0.5), Vector2(streak.length() * 1.6, edge * 0.70),
				Color(ember, opacity * 0.9), streak.angle())
			for tail in range(trails, 0, -1):
				var previous_age: float = age - float(tail) * life * 0.035
				if previous_age <= 0.0:
					continue
				var behind: Vector2 = _firework_point(origin, direction, reach, previous_age, life)
				var strength: float = 1.0 - float(tail) / float(trails + 1)
				var tangent: Vector2 = point - behind
				_stamp(STAR, behind, Vector2(edge * (0.55 + strength), edge * 0.42),
					Color(ember, opacity * strength * 0.72), tangent.angle())
			var shrink: float = lerpf(1.0, 0.40, smoothstep(life * 0.2, life, age))
			_stamp(STAR, point, Vector2.ONE * edge * shrink, Color(ember, opacity), angle)
			_stamp(STAR, point, Vector2.ONE * edge * shrink * 0.32, Color(1.0, 0.99, 0.86, opacity))


func snapshot() -> Dictionary:
	var selected: Dictionary = PROFILES[level - 1]
	var rect: Rect2 = get_global_rect()
	return {"level": level, "name": selected.name, "pattern": selected.pattern,
		"spark_count": _spark_count(), "wave_count": selected.bursts,
		"trail_count": _trail_count(), "emission_seconds": _emission_span() if level >= 4 else 0.0,
		"burst_count": selected.bursts, "reduced_motion": reduced_motion,
		"input_transparent": mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}
