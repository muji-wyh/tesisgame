extends Control
## A sourced panoramic sky, calm daylight and low garden edges frame the board.

const Style = preload("res://scripts/ui_style.gd")
const SKY = preload("res://assets/images/jelly-match/sky/day.png")
const DAYLIGHT = preload("res://scripts/jelly_daylight.gdshader")
const HILLS = preload("res://assets/images/jelly-match/garden/hills.png")
const TREE = preload("res://assets/images/jelly-match/garden/tree.png")
const TREE_LONG = preload("res://assets/images/jelly-match/garden/tree-long.png")
const FOLIAGE = preload("res://assets/images/jelly-match/garden/foliage.png")

var _header_wash := GradientTexture2D.new()
var _elapsed: float = 0.0
var motion_scale: float = 1.0
var _ambient_active: bool = false
var _reduced_motion: bool = false
var _sky: TextureRect
var _sky_material := ShaderMaterial.new()
var _daylight: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#fffcf3"), Color("#fffcf3", 0.0)])
	_header_wash.gradient = gradient
	_header_wash.width = 4
	_header_wash.height = 256
	_header_wash.fill_from = Vector2(0.5, 0.0)
	_header_wash.fill_to = Vector2(0.5, 1.0)
	_sky_material.shader = DAYLIGHT
	_sky = TextureRect.new()
	_sky.name = "DaylightSky"
	_sky.texture = SKY
	_sky.material = _sky_material
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.focus_mode = Control.FOCUS_NONE
	_sky.show_behind_parent = true
	add_child(_sky)
	resized.connect(_layout)
	visibility_changed.connect(_sync_motion)
	set_process(false)
	_update_daylight()


func _ready() -> void:
	_layout()
	_sync_motion()


func set_ambient_active(value: bool) -> void:
	_ambient_active = value
	_sync_motion()


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	_update_daylight()
	_sync_motion()


func _sync_motion() -> void:
	set_process(_ambient_active and not _reduced_motion and is_visible_in_tree())


func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_elapsed = fmod(_elapsed + delta * clampf(motion_scale, 0.0, 1.0), 360.0)
	_update_daylight()


func _layout() -> void:
	_sky.size = size
	_update_daylight()
	queue_redraw()


func _update_daylight() -> void:
	var phase: float = 0.0 if _reduced_motion else _elapsed
	var sunlight: float = 0.5 + sin(phase * TAU / 120.0) * 0.5
	_daylight = {"yaw": sin(phase * TAU / 180.0) * 0.07,
		"warmth": lerpf(0.06, 0.26, sunlight), "light_strength": lerpf(0.10, 0.24, sunlight),
		"aspect": size.x / maxf(1.0, size.y)}
	for key: String in _daylight:
		_sky_material.set_shader_parameter(key, _daylight[key])


func snapshot() -> Dictionary:
	var result := _daylight.duplicate()
	result.merge({"elapsed": _elapsed, "active": is_processing(), "reduced_motion": _reduced_motion})
	return result


func _stamp(texture: Texture2D, anchor: Vector2, width: float, pivot: Vector2, tint: Color = Color.WHITE) -> void:
	var art_size: Vector2 = texture.get_size() * (width / texture.get_width())
	draw_texture_rect(texture, Rect2(anchor - art_size * pivot, art_size), false, tint)


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var scale: float = Style.ui_scale(self)
	var hill_width: float = maxf(size.x, size.y) * 1.25
	_stamp(HILLS, Vector2(size.x * 0.43, size.y * 0.82), hill_width, Vector2(0.5, 0.0), Color(0.90, 0.94, 0.79, 0.36))
	var portrait: bool = size.x < size.y
	var tree_height: float = minf(minf(size.y * 0.24, size.x * 0.46), 230.0 / scale)
	_stamp(TREE, Vector2(size.x * (0.005 if portrait else 0.045), size.y * 1.02), tree_height * TREE.get_width() / TREE.get_height(), Vector2(0.5, 1.0), Color(0.82, 0.90, 0.76, 0.34))
	_stamp(TREE_LONG, Vector2(size.x * 0.97, size.y * 1.02), tree_height * 0.88 * TREE_LONG.get_width() / TREE_LONG.get_height(), Vector2(0.5, 1.0), Color(0.82, 0.90, 0.76, 0.30))
	_stamp(HILLS, Vector2(size.x * 0.56, size.y * 0.94), hill_width, Vector2(0.5, 0.0), Color(0.84, 0.93, 0.75, 0.42))
	var foliage_width: float = minf(size.x * 0.26, 200.0 / scale)
	_stamp(FOLIAGE, Vector2(0.0, size.y * 1.05), foliage_width, Vector2(0.35, 1.0), Color(0.84, 0.93, 0.79, 0.34))
	_stamp(FOLIAGE, Vector2(size.x, size.y * 1.06), foliage_width * 0.86, Vector2(0.65, 1.0), Color(0.84, 0.93, 0.79, 0.30))
	draw_texture_rect(_header_wash, Rect2(Vector2.ZERO, Vector2(size.x, minf(size.y * 0.25, 220.0 / scale))), false, Color(1, 1, 1, 0.58))