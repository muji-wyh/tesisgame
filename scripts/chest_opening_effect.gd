extends Node2D
## A finite flourish sampled by the chest's existing, pausable presentation clock.

const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const DURATION: float = 2.4
const COLORS: Array[Color] = [Color("#ff92b7"), Color("#ffd36c"), Color("#a6edb2"),
	Color("#8ae9f0"), Color("#b3b7ff"), Color("#e0a6fa")]

var _active: bool = false
var _age: float = 0.0
var _safe := Rect2()
var _origin := Vector2.ZERO
var _unit: float = 1.0
var _color := Color.WHITE


func clear() -> void:
	_active = false
	_age = 0.0
	hide()
	queue_redraw()


func sample(active: bool, age: float, safe: Rect2, origin: Vector2, unit: float, color: Color) -> void:
	_active = active and age >= 0.0 and age < DURATION and safe.has_area()
	_age = maxf(0.0, age)
	_safe = safe
	_origin = origin.clamp(safe.position, safe.end)
	_unit = minf(unit, minf(safe.size.x, safe.size.y) / 100.0)
	_color = color
	visible = _active
	queue_redraw()


func _particles() -> Array[Dictionary]:
	var particles: Array[Dictionary] = []
	if not _active:
		return particles
	for index in range(28):
		var seed_value: float = fposmod(float(index) * 0.618034, 1.0)
		var delay: float = float(index % 7) * 0.042
		var age: float = _age - delay
		var lifetime: float = 1.65 + seed_value * 0.48
		if age <= 0.0 or age >= lifetime:
			continue
		var progress: float = age / lifetime
		var spread: float = 1.0 - pow(1.0 - progress, 3.0)
		var edge: float = lerpf(12.0, 23.0, seed_value) * _unit
		var margin: float = edge * 0.72
		var safe: Rect2 = _safe.grow(-margin)
		var start: Vector2 = _origin.clamp(safe.position, safe.end)
		var lane: float = (float(index % 14) + 0.5) / 14.0
		var target := Vector2(lerpf(safe.position.x, safe.end.x, lane),
			lerpf(safe.position.y, start.y, 0.10 + seed_value * 0.48))
		var position: Vector2 = start.lerp(target, spread)
		position.y += pow(progress, 2.0) * _safe.size.y * 0.15
		position.x += sin(progress * PI) * sin(float(index) * 2.4) * _safe.size.x * 0.06
		position = position.clamp(safe.position, safe.end)
		var alpha: float = smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.55, 1.0, progress))
		particles.append({"position": position, "edge": edge, "alpha": alpha,
			"rotation": float(index) * 0.9 + progress * (0.5 if index % 2 == 0 else -0.5),
			"color": COLORS[index % COLORS.size()].lightened(seed_value * 0.2)})
	return particles


func draw_glow(canvas: Node2D) -> void:
	if not _active:
		return
	var bloom: float = smoothstep(0.0, 0.16, _age) * (1.0 - smoothstep(0.45, 1.45, _age))
	if bloom <= 0.0:
		return
	var rise: float = smoothstep(0.0, 0.65, _age)
	var center: Vector2 = _origin.lerp(Vector2(_safe.get_center().x, _safe.position.y + _safe.size.y * 0.44), rise)
	var edge: float = minf(_safe.size.x, _safe.size.y) * lerpf(0.68, 0.96, rise)
	var margin: float = edge * 0.5
	center = center.clamp(_safe.position + Vector2.ONE * margin, _safe.end - Vector2.ONE * margin)
	canvas.draw_texture_rect(GLOW, Rect2(center - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false,
		Color(_color.lightened(0.50), bloom * 0.58))
	# Texture strokes rotate within a fitted square, behind the physical chest.
	var ray_edge: float = edge * 0.70
	for layer in range(2):
		canvas.draw_set_transform(center, _age * (0.16 if layer == 0 else -0.12) + float(layer) * 0.48)
		canvas.draw_texture_rect(RAYS, Rect2(Vector2.ONE * -ray_edge * 0.5, Vector2.ONE * ray_edge), false,
			Color(COLORS[1 if layer == 0 else 4], bloom * 0.72))
	canvas.draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	for particle in _particles():
		var edge: float = particle.edge
		draw_set_transform(particle.position, particle.rotation)
		draw_texture_rect(SPARKLE, Rect2(Vector2.ONE * -edge * 0.5, Vector2.ONE * edge), false,
			Color(particle.color, particle.alpha))
	draw_set_transform(Vector2.ZERO)


func snapshot() -> Dictionary:
	var particles: Array[Dictionary] = _particles()
	return {"active": _active and is_visible_in_tree(), "age": _age,
		"particle_count": particles.size(), "particles": particles, "bounds": _safe}
