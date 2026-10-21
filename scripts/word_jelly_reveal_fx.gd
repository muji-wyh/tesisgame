extends Control
## Sourced light and spark artwork framing a collected word's reading card.

const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const STAR = preload("res://assets/chests/milestone/sparkle.png")
const PROFILES: Array[Dictionary] = [
	{"name": "Pearl greeting", "pattern": "pearl", "sparks": 3, "bursts": 1, "hue": 0.43, "margin": 6.0},
	{"name": "Crystal ribbon", "pattern": "ribbon", "sparks": 9, "bursts": 1, "hue": 0.51, "margin": 9.0},
	{"name": "Sapphire spiral", "pattern": "spiral", "sparks": 18, "bursts": 1, "hue": 0.65, "margin": 12.0},
	{"name": "Golden fireworks", "pattern": "fireworks", "sparks": 28, "bursts": 2, "hue": 0.11, "margin": 38.0},
	{"name": "Rose cascade", "pattern": "cascade", "sparks": 38, "bursts": 3, "hue": 0.93, "margin": 43.0},
	{"name": "Comet coronation", "pattern": "crown", "sparks": 48, "bursts": 3, "hue": 0.51, "margin": 48.0},
	{"name": "Aurora embrace", "pattern": "aurora", "sparks": 60, "bursts": 4, "hue": 0.75, "margin": 52.0},
	{"name": "Starlight festival", "pattern": "constellation", "sparks": 72, "bursts": 5, "hue": 0.12, "margin": 59.0},
	{"name": "Prismatic finale", "pattern": "bouquet", "sparks": 84, "bursts": 6, "hue": 0.10, "margin": 68.0},
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
	return PROFILES[clampi(value, 1, 9) - 1].duplicate(true)


static func margin_for(value: int, batch: bool, ui_scale: float) -> float:
	return float(PROFILES[clampi(value, 1, 9) - 1].margin) * (0.68 if batch else 1.0) / ui_scale


func configure(card_size: Vector2, ui_scale: float, value: int, accent: Color, batch: bool, margin: float) -> void:
	level = clampi(value, 1, 9)
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
	if level >= 7:
		hue += [0.0, 0.39, 0.62, 0.85][posmod(index, 4)]
	elif level >= 4:
		hue += [0.0, -0.08, 0.13][posmod(index, 3)]
	return Color.from_hsv(fposmod(hue, 1.0), 0.70, 1.0).lerp(_accent, 0.18 if level < 4 else 0.03)


func _stamp(texture: Texture2D, point: Vector2, extent: Vector2, color: Color, angle: float = 0.0) -> void:
	if color.a <= 0.002:
		return
	draw_set_transform(point, angle)
	draw_texture_rect(texture, Rect2(extent * -0.5, extent), false, color)


func _rim(angle: float, offset: float = 0.0) -> Vector2:
	var direction := Vector2.from_angle(angle)
	var half: Vector2 = _card.size * 0.5
	var reach: float = minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
	return _card.get_center() + direction * (reach + offset)


func _burst_angle(group: int) -> float:
	if level == 6:
		return -PI * 0.83 + float(group) * PI * 0.33
	return -PI * 0.75 + float(group) * TAU / float(PROFILES[level - 1].bursts)


func _burst_origin(group: int) -> Vector2:
	# Move each bloom into the halo so the reading surface cannot hide its peak.
	return _rim(_burst_angle(group), _margin * 0.45)


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


func _draw_celebration(fade: float) -> void:
	var selected: Dictionary = PROFILES[level - 1]
	# The reading card keeps its existing lifetime; batch effects compress their
	# own release so even a 250 ms pickup rhythm reaches the level's main peak.
	var clock: float = elapsed / (minf(0.48, duration * 0.8) if _batch else 1.28)
	var launch: float = smoothstep(0.0, 0.08, clock)
	var glow: float = (0.38 + float(level) * 0.055) * fade * (1.0 - smoothstep(0.35, 1.10, clock) * 0.65)
	_stamp(GLOW, _card.get_center(), _card.size + Vector2.ONE * _margin * 1.9,
		Color(color_at(), glow), 0.0)
	if level >= 4:
		_edge_light(glow * 1.15, clock)
	if level >= 3:
		var rays_alpha: float = fade * launch * (1.0 - smoothstep(0.30, 0.95, clock))
		_stamp(RAYS, _card.get_center(), _card.size + Vector2.ONE * _margin * 2.0,
			Color(color_at(1), rays_alpha * 0.84), clock * 0.12)
		if level >= 7:
			_stamp(RAYS, _card.get_center(), _card.size + Vector2.ONE * _margin * 1.6,
				Color(color_at(2), rays_alpha * 0.72), -clock * 0.18)
	var count: int = int(selected.sparks)
	if _batch:
		count = maxi(3, roundi(count * 0.62))
	for index in range(count):
		var phase: float = float(posmod(index * 7, 13)) / 13.0
		var tint: Color = color_at(index)
		var edge: float = (5.0 + level * 0.8 + phase * 3.8) / _ui_scale
		if level >= 4:
			edge = minf(edge, _margin * 0.30)
		var point: Vector2
		var opacity: float
		var rotation_angle: float
		if level < 4 or level == 7:
			var angle: float = TAU * float(index) / float(count) - PI * 0.5
			var turn: float = clock * (1.15 if level == 3 else 0.60) * (-1.0 if level == 7 and index % 2 == 0 else 1.0)
			point = _rim(angle + turn, _margin * (0.25 + phase * 0.47) * launch)
			opacity = fade * launch * (0.60 + 0.40 * sin(phase * TAU + clock * 4.0))
			rotation_angle = angle + turn
		else:
			var group: int = index % int(selected.bursts)
			var delay: float = float(group) * (0.055 if level >= 8 else 0.085)
			var age: float = maxf(0.0, clock - delay)
			var base: Vector2 = _burst_origin(group)
			var spoke: float = float(index / int(selected.bursts))
			var spokes: float = ceilf(float(count) / float(selected.bursts))
			var spread: float = TAU * spoke / spokes + float(group) * 0.37
			var direction := Vector2.from_angle(spread)
			var travel: float = 1.0 - pow(1.0 - clampf(age / 0.62, 0.0, 1.0), 2.5)
			point = base + direction * _margin * (0.30 + phase * 0.10) * travel
			if level == 5 or level == 8:
				point.y += _margin * minf(age * age, 1.0) * 0.20
			elif level == 6:
				point.y -= _margin * sin(clampf(age, 0.0, 1.0) * PI) * 0.16
			opacity = fade * smoothstep(0.0, 0.025, age) * (1.0 - smoothstep(0.34 + phase * 0.12, 1.12, age))
			rotation_angle = spread + age * 0.60
			for tail in range(2 if level < 8 else 4, 0, -1):
				var behind: Vector2 = point.lerp(base, float(tail) * 0.15)
				_stamp(STAR, behind, Vector2.ONE * edge * (0.50 - float(tail) * 0.07),
					Color(tint, opacity * 0.55), rotation_angle)
		_stamp(STAR, point, Vector2.ONE * edge, Color(tint, opacity), rotation_angle)
		if level >= 4 and index % 3 == 0:
			_stamp(STAR, point, Vector2.ONE * edge * 0.35, Color(1.0, 0.99, 0.86, opacity), -rotation_angle)
	if level >= 4:
		for group in range(int(selected.bursts)):
			var age: float = clock - float(group) * (0.055 if level >= 8 else 0.085)
			var peak: float = smoothstep(0.0, 0.035, age) * (1.0 - smoothstep(0.16, 0.52, age))
			var point: Vector2 = _burst_origin(group)
			_stamp(GLOW, point, Vector2.ONE * _margin * 1.05,
				Color(color_at(group), peak * fade * 0.7))
			_stamp(RAYS, point, Vector2.ONE * _margin * (0.70 + clampf(age, 0.0, 0.6)),
				Color(color_at(group), peak * fade * 0.9), age * 0.5)
	if level >= 8:
		# A separate perimeter wave makes the finale read between satellite blooms.
		for index in range(8 if level == 8 else 14):
			var count_stars: float = 8.0 if level == 8 else 14.0
			var angle: float = TAU * float(index) / count_stars + clock * 0.24
			var point: Vector2 = _rim(angle, _margin * (0.16 + 0.13 * sin(clock * PI)))
			var pulse: float = 0.72 + 0.28 * sin(index * 2.3 + clock * 7.0)
			_stamp(STAR, point, Vector2.ONE * minf(13.0 / _ui_scale, _margin * 0.30) * pulse,
				Color(color_at(index + 1), fade * launch * 0.88), -angle)


func snapshot() -> Dictionary:
	var selected: Dictionary = PROFILES[level - 1]
	var rect: Rect2 = get_global_rect()
	return {"level": level, "name": selected.name, "pattern": selected.pattern,
		"spark_count": maxi(3, roundi(int(selected.sparks) * 0.62)) if _batch else int(selected.sparks),
		"burst_count": selected.bursts, "reduced_motion": reduced_motion,
		"input_transparent": mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}
