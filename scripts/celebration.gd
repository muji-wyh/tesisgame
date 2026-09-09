extends Control

const LIFETIME: float = 4.8

var _particles: Array[Dictionary] = []
var _texture_paths: Dictionary = {}
var _textures: Dictionary = {}
var _palette: Dictionary = {}
var _token: Texture2D
var _elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	set_process(false)


func configure(manifest: Dictionary) -> void:
	_texture_paths = manifest.particles.duplicate()
	_textures.clear()


func start(palette: Dictionary, reduced_motion: bool, small: bool = false) -> void:
	clear()
	if reduced_motion:
		return
	if _textures.is_empty():
		for key in _texture_paths:
			_textures[key] = load("res://" + _texture_paths[key])
	_palette = palette
	_token = load(palette.symbol)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for category in range(3):
		var count: int = [4, 12, 8][category] if small else [12, 36, 24][category]
		for index in range(count):
			var angle: float = TAU * float(index) / float(count) + rng.randf_range(-0.05, 0.05)
			_particles.append({
				"kind": category, "angle": angle, "distance": rng.randf_range(0.48, 1.0),
				"spin": rng.randf_range(-4.0, 4.0), "size": rng.randf_range(0.7, 1.3),
				"delay": rng.randf_range(0.0, 0.2)
			})
	set_process(true)
	queue_redraw()


func clear() -> void:
	_particles.clear()
	_elapsed = 0.0
	set_process(false)
	queue_redraw()


func particle_count() -> int:
	return _particles.size()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		clear()
	else:
		queue_redraw()


func _texture(key: String, center: Vector2, dimensions: Vector2, color: Color, rotation: float = 0.0) -> void:
	draw_set_transform(center, rotation)
	draw_texture_rect(_textures[key], Rect2(-dimensions * 0.5, dimensions), false, color)
	draw_set_transform(Vector2.ZERO)


func _particle_position(particle: Dictionary, age: float, center: Vector2, unit: float) -> Vector2:
	var travel: float = 1.0 - exp(-age * 1.8)
	var direction := Vector2(cos(particle.angle), sin(particle.angle))
	var distance: float = travel * unit * 0.62 * float(particle.distance)
	var position: Vector2 = center + direction * distance
	match _palette.id:
		"spring":
			position.x += sin(age * 4.0 + float(particle.angle) * 3.0) * unit * 0.045 * travel
			position.y += age * age * unit * 0.018
		"summer":
			position = center + direction.rotated(age * 0.16) * distance * 1.12
			position.y += age * age * unit * 0.028
		"autumn":
			position.x += sin(age * 2.0 + float(particle.angle)) * unit * 0.07 * travel
			position.y += age * age * unit * 0.075
		"winter":
			position = center + direction.rotated(-age * 0.22) * distance
			position.y += age * unit * 0.012
	return position


func _draw() -> void:
	if _particles.is_empty() or _textures.is_empty():
		return
	var unit: float = minf(size.x, size.y)
	var center := Vector2(size.x * 0.5, size.y * 0.55)
	var fade: float = clampf((LIFETIME - _elapsed) / 1.4, 0.0, 1.0)
	var charge: float = smoothstep(0.0, 0.5, _elapsed)
	var burst: float = smoothstep(0.42, 0.85, _elapsed)
	var light: Color = _palette.light
	var spark: Color = _palette.spark
	_texture("glow", center, Vector2.ONE * unit * (0.8 + burst), Color(light, fade * 0.7 * charge))
	_texture("ray", center - Vector2(0, size.y * 0.18), Vector2(unit * 0.8, size.y * 1.2),
		Color(light, fade * burst * 0.45))
	var ray_count: int = {"spring": 10, "summer": 12, "autumn": 8, "winter": 6}[_palette.id]
	var ray_speed: float = 0.3 if _palette.id == "summer" else -0.12
	for ray in range(ray_count):
		var angle: float = TAU * float(ray) / float(ray_count) + _elapsed * ray_speed
		_texture("ray", center, Vector2(unit * 0.13, unit * 1.3), Color(light, fade * burst * 0.22), angle)
	for ring in range(2):
		var age: float = _elapsed - 0.45 - float(ring) * 0.24
		if age > 0.0 and age < 1.6:
			var radius: float = lerpf(0.12, 1.45, age / 1.6) * unit
			_texture("ring", center, Vector2.ONE * radius, Color(spark, (1.0 - age / 1.6) * 0.9))
	var flash: float = maxf(0.0, 1.0 - absf(_elapsed - 0.68) / 0.28)
	_texture("burst", center, Vector2.ONE * unit * 1.4, Color(light, flash * 0.65))
	for particle in _particles:
		var age: float = _elapsed - 0.45 - float(particle.delay)
		if age <= 0.0:
			continue
		var position: Vector2 = _particle_position(particle, age, center, unit)
		var opacity: float = fade * minf(age * 6.0, 1.0)
		var color: Color = Color(light if particle.kind != 2 else spark, opacity)
		var rotation: float = float(particle.spin) * age
		if particle.kind == 0:
			var token_size: float = unit * 0.105 * float(particle.size)
			draw_set_transform(position, rotation * 0.35)
			draw_texture_rect(_token, Rect2(Vector2.ONE * -token_size * 0.5, Vector2.ONE * token_size), false, Color(1, 1, 1, opacity))
			draw_set_transform(Vector2.ZERO)
		elif particle.kind == 1:
			var spark_size: float = unit * 0.045 * float(particle.size)
			_texture("spark", position, Vector2.ONE * spark_size, color, rotation)
		else:
			draw_set_transform(position, rotation)
			var length: float = unit * 0.028 * float(particle.size)
			draw_rect(Rect2(-length * 0.5, -length * 0.2, length, length * 0.4), color)
			draw_set_transform(Vector2.ZERO)
	_texture("orb", center, Vector2.ONE * unit * 0.26, Color(light, flash * 0.75))
