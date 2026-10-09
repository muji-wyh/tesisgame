extends Control
## One continuous, textured gel surface follows the committed model clock.

const Surface = preload("res://scripts/jelly_union.gdshader")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
var stage: String = "contact"
var _paint: ColorRect
var _gel: ShaderMaterial
var _glow: TextureRect
var _beads: Array[TextureRect] = []
var _materials: Array[Texture2D] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow = _image()
	_glow.texture = GLOW
	_glow.modulate = Color(0.65, 1.0, 0.80, 0.0)
	_paint = ColorRect.new()
	_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gel = ShaderMaterial.new()
	_gel.shader = Surface
	_paint.material = _gel
	add_child(_paint)
	for index in range(5):
		_beads.append(_image())
	hide()

func _image() -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	return image

func configure(colors: Array, a: int, b: int, surface: Texture2D) -> void:
	if _materials.is_empty():
		for color: String in colors:
			_materials.append(load("res://assets/images/jelly-match/gel-%s-material.png" % color) as Texture2D)
	_gel.set_shader_parameter("material_a", _materials[posmod(a, _materials.size())])
	_gel.set_shader_parameter("material_b", _materials[posmod(b, _materials.size())])
	for bead: TextureRect in _beads:
		bead.texture = surface

func pose(a: Vector2, b: Vector2, destination: Vector2, extent: Vector2, unit: float,
		progress: float, union: float, compression: float, release: float, opacity: float) -> void:
	stage = "release" if progress >= 2.0 / 3.0 else "compress" if progress >= 0.54 else "hold" if progress >= 0.38 else "union" if progress >= 0.20 else "contact"
	var bounds := Rect2(a, Vector2.ZERO).expand(b).grow(unit * 1.35)
	position = bounds.position
	size = bounds.size
	_paint.size = size
	_gel.set_shader_parameter("canvas_size", size)
	_gel.set_shader_parameter("body_a", Vector4(a.x - position.x, a.y - position.y, extent.x, extent.y))
	_gel.set_shader_parameter("body_b", Vector4(b.x - position.x, b.y - position.y, extent.x, extent.y))
	_gel.set_shader_parameter("neck", unit * lerpf(0.04, 0.17, sin(union * PI)))
	_gel.set_shader_parameter("flow", progress)
	_gel.set_shader_parameter("charge", compression)
	_gel.set_shader_parameter("opacity", opacity)
	var center: Vector2 = destination - position
	var bloom: float = sin(clampf(release / 0.72, 0.0, 1.0) * PI)
	_glow.size = Vector2.ONE * unit * lerpf(1.0, 2.1, release)
	_glow.position = center - _glow.size * 0.5
	_glow.modulate.a = bloom * 0.52
	for index in range(_beads.size()):
		var bead: TextureRect = _beads[index]
		bead.visible = release > 0.0 and release < 1.0
		var angle: float = -PI * 0.95 + float(index) * PI * 0.235
		var direction := Vector2(cos(angle), sin(angle))
		var travel: float = (1.0 - pow(1.0 - release, 2.0)) * unit * (0.66 + 0.09 * (index % 2))
		var bead_size: float = unit * (0.16 + 0.025 * (index % 3)) * (1.0 - smoothstep(0.48, 1.0, release))
		bead.size = Vector2(bead_size * (1.0 - release * 0.18), bead_size * (1.32 - release * 0.32))
		bead.pivot_offset = bead.size * 0.5
		bead.rotation = angle + PI * 0.5
		bead.position = center + direction * travel + Vector2(0.0, unit * release * release * 0.24) - bead.size * 0.5
		bead.modulate.a = 1.0 - smoothstep(0.7, 1.0, release)
	show()
