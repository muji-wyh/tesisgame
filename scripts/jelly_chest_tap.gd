extends Button
## A local chest response; it never opens a chest or issues a reward.

const Style = preload("res://scripts/ui_style.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const DURATION: float = 0.92
const REDUCED_DURATION: float = 0.40

var _texture: Texture2D
var _opacity: float = 1.0
var _elapsed: float = DURATION
var _active: bool = false
var _reduced: bool = false


func _init() -> void:
	name = "JellyChestTap"
	set("accessibility_name", "Make the chest sparkle")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	z_index = 10
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var focus := Style.box(Color.TRANSPARENT, Style.GOOD, ceili(size.x * 0.5), 2)
	add_theme_stylebox_override("focus", focus)
	queue_redraw()


func play(texture: Texture2D, opacity: float, reduced: bool) -> void:
	if _active or texture == null:
		return
	_texture = texture
	_opacity = clampf(opacity, 0.0, 1.0)
	_reduced = reduced
	_elapsed = 0.0
	_active = true
	queue_redraw()


func advance(delta: float) -> void:
	if not _active or not is_finite(delta) or delta <= 0.0:
		return
	_elapsed = minf(_duration(), _elapsed + delta)
	if _elapsed >= _duration():
		clear()
	else:
		queue_redraw()


func clear() -> void:
	_active = false
	_elapsed = _duration()
	_texture = null
	queue_redraw()


func is_active() -> bool:
	return _active


func _duration() -> float:
	return REDUCED_DURATION if _reduced else DURATION


func snapshot() -> Dictionary:
	var zoom: float = 1.0
	var turn: float = 0.0
	var light: float = 0.0
	if _active:
		var t: float = _elapsed
		if _reduced:
			light = 0.62 * (1.0 - smoothstep(0.10, REDUCED_DURATION, t))
		else:
			# One firm lift, a turning accent and a short, damped recovery.
			if t < 0.14:
				var p: float = 1.0 - pow(1.0 - t / 0.14, 3.0)
				zoom = lerpf(1.0, 1.36, p)
				turn = lerpf(0.0, -0.20, p)
			elif t < 0.34:
				var p: float = smoothstep(0.14, 0.34, t)
				zoom = lerpf(1.36, 1.72, p)
				turn = lerpf(-0.20, 0.24, p)
			elif t < 0.66:
				var p: float = smoothstep(0.34, 0.66, t)
				zoom = lerpf(1.72, 1.08, p)
				turn = lerpf(0.24, -0.07, p)
			else:
				var p: float = smoothstep(0.66, DURATION, t)
				zoom = lerpf(1.08, 1.0, p)
				turn = lerpf(-0.07, 0.0, p)
			light = (0.28 + 0.72 * smoothstep(0.0, 0.14, t)) * (1.0 - smoothstep(0.36, 0.88, t))
	return {"active": _active, "elapsed": _elapsed, "scale": zoom, "rotation": turn, "light": light}


func _draw() -> void:
	if not _active or _texture == null or size.x <= 0.0:
		return
	var state: Dictionary = snapshot()
	var center: Vector2 = size * 0.5
	var edge: float = minf(size.x, size.y)
	var light: float = float(state.light)
	# The existing acquired light textures radiate from the fixed chest center.
	draw_texture_rect(GLOW, Rect2(center - Vector2.ONE * edge * 0.75, Vector2.ONE * edge * 1.50),
		false, Color("#efb342", light * 0.90))
	if not _reduced:
		draw_set_transform(center, _elapsed * 0.22)
		draw_texture_rect(RAYS, Rect2(-Vector2.ONE * edge * 0.90, Vector2.ONE * edge * 1.80),
			false, Color("#eaa431", light * 0.95))
	var artwork_size: Vector2 = _texture.get_size()
	artwork_size *= edge * 0.67 / maxf(artwork_size.x, artwork_size.y)
	draw_set_transform(center, float(state.rotation), Vector2.ONE * float(state.scale))
	draw_texture_rect(_texture, Rect2(-artwork_size * 0.5, artwork_size), false,
		Color(1.0, 1.0, 1.0, lerpf(_opacity, 1.0, light)))
	draw_set_transform(Vector2.ZERO)
	var offsets: Array[Vector2] = [Vector2(-0.56, -0.24), Vector2(0.32, -0.57), Vector2(0.55, 0.20)]
	for index in range(offsets.size()):
		var glint: float = light if _reduced else light * sin(clampf((_elapsed - float(index) * 0.05) / 0.64, 0.0, 1.0) * PI)
		var diameter: float = edge * (0.26 if index == 1 else 0.20)
		var point: Vector2 = center + offsets[index] * edge
		draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter),
			false, Color("#efb331", glint))
		var core: float = diameter * 0.52
		draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * core * 0.5, Vector2.ONE * core),
			false, Color("#fff9e4", glint))
