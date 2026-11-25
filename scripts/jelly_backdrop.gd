extends Control
## A sourced panoramic sky, calm daylight and low garden edges frame the board.

const Style = preload("res://scripts/ui_style.gd")
const SKY = preload("res://assets/images/jelly-match/sky/day.png")
const DAYLIGHT = preload("res://scripts/jelly_daylight.gdshader")
const HILLS = preload("res://assets/images/jelly-match/garden/hills.png")
const TREE = preload("res://assets/images/jelly-match/garden/tree.png")
const TREE_LONG = preload("res://assets/images/jelly-match/garden/tree-long.png")
const FOLIAGE = preload("res://assets/images/jelly-match/garden/foliage.png")
const CHAPTER_PROPS: Array[Texture2D] = [
	HILLS,
	TREE,
	preload("res://assets/images/jelly-campaign/tree-pine.png"),
	preload("res://assets/images/jelly-campaign/cottage.png"),
	preload("res://assets/images/jelly-campaign/tree-orange.png"),
	preload("res://assets/images/jelly-campaign/tree-snow.png"),
	preload("res://assets/images/jelly-campaign/tree-pine-snow.png"),
	preload("res://assets/images/jelly-campaign/tree-palm.png"),
	preload("res://assets/images/jelly-campaign/cactus.png"),
	preload("res://assets/images/jelly-campaign/mountains.png"),
	preload("res://assets/images/jelly-campaign/castle.png")]
# Gentle per-chapter atmospheric presets (1..11) keeping central playfield contrast high.
const CHAPTER_THEMES: Array[Dictionary] = [
	{"hill": Color(0.90, 0.94, 0.79, 0.36), "hill2": Color(0.84, 0.93, 0.75, 0.42), "prop": Color(0.82, 0.90, 0.76, 0.34), "warmth_bias": 0.0, "mote": Color("#fff9dc"), "key_light": Color("#fff2d4"), "ambient_light": Color("#e4f2e8"), "well_tint": Color("#e9f4ea")},
	{"hill": Color(0.84, 0.93, 0.78, 0.36), "hill2": Color(0.78, 0.90, 0.74, 0.42), "prop": Color(0.76, 0.88, 0.74, 0.36), "warmth_bias": -0.02, "mote": Color("#f3ffe0"), "key_light": Color("#f7f4d8"), "ambient_light": Color("#dcefe4"), "well_tint": Color("#e4f2e9")},
	{"hill": Color(0.80, 0.90, 0.82, 0.36), "hill2": Color(0.74, 0.86, 0.78, 0.42), "prop": Color(0.74, 0.86, 0.78, 0.36), "warmth_bias": -0.04, "mote": Color("#e8fbf2"), "key_light": Color("#edf6e6"), "ambient_light": Color("#d6ece8"), "well_tint": Color("#e2f0ee")},
	{"hill": Color(0.92, 0.91, 0.80, 0.36), "hill2": Color(0.88, 0.88, 0.76, 0.42), "prop": Color(0.92, 0.89, 0.80, 0.36), "warmth_bias": 0.05, "mote": Color("#fff3cf"), "key_light": Color("#ffedd0"), "ambient_light": Color("#ebe9dc"), "well_tint": Color("#f2efe4")},
	{"hill": Color(0.96, 0.88, 0.74, 0.36), "hill2": Color(0.94, 0.82, 0.68, 0.42), "prop": Color(0.96, 0.84, 0.68, 0.38), "warmth_bias": 0.10, "mote": Color("#ffe2b8"), "key_light": Color("#ffe2bd"), "ambient_light": Color("#f2e4d8"), "well_tint": Color("#f6ece0")},
	{"hill": Color(0.86, 0.93, 0.98, 0.38), "hill2": Color(0.82, 0.90, 0.98, 0.44), "prop": Color(0.88, 0.95, 1.0, 0.38), "warmth_bias": -0.06, "mote": Color("#f4fbff"), "key_light": Color("#eef6ff"), "ambient_light": Color("#d6e8fb"), "well_tint": Color("#e6f0f8")},
	{"hill": Color(0.82, 0.91, 0.97, 0.38), "hill2": Color(0.78, 0.88, 0.96, 0.44), "prop": Color(0.84, 0.92, 0.98, 0.38), "warmth_bias": -0.06, "mote": Color("#edf8ff"), "key_light": Color("#e8f2ff"), "ambient_light": Color("#d0e4fa"), "well_tint": Color("#e2edf8")},
	{"hill": Color(0.86, 0.95, 0.90, 0.36), "hill2": Color(0.80, 0.92, 0.88, 0.42), "prop": Color(0.82, 0.94, 0.84, 0.36), "warmth_bias": 0.06, "mote": Color("#fff8d6"), "key_light": Color("#fff0cc"), "ambient_light": Color("#daf1ec"), "well_tint": Color("#e5f4ef")},
	{"hill": Color(0.96, 0.89, 0.76, 0.36), "hill2": Color(0.94, 0.84, 0.70, 0.42), "prop": Color(0.92, 0.86, 0.74, 0.36), "warmth_bias": 0.12, "mote": Color("#ffe6ba"), "key_light": Color("#ffe5bf"), "ambient_light": Color("#f4e8d6"), "well_tint": Color("#f6eee1")},
	{"hill": Color(0.86, 0.89, 0.95, 0.36), "hill2": Color(0.80, 0.85, 0.93, 0.42), "prop": Color(0.84, 0.88, 0.95, 0.38), "warmth_bias": -0.04, "mote": Color("#eef1ff"), "key_light": Color("#edf0ff"), "ambient_light": Color("#dce2f4"), "well_tint": Color("#e8ebf6")},
	{"hill": Color(0.90, 0.87, 0.95, 0.36), "hill2": Color(0.85, 0.82, 0.92, 0.42), "prop": Color(0.90, 0.86, 0.94, 0.38), "warmth_bias": 0.04, "mote": Color("#fff1ff"), "key_light": Color("#f8ecff"), "ambient_light": Color("#e6dff5"), "well_tint": Color("#efeaf7")}]

var _header_wash := GradientTexture2D.new()
var _elapsed: float = 0.0
var motion_scale: float = 1.0
var _chapter: int = 0
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


func set_chapter(chapter: int) -> void:
	var next: int = clampi(chapter, 0, CHAPTER_PROPS.size())
	if next == _chapter:
		return
	_chapter = next
	_update_daylight()
	queue_redraw()


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
	var theme: Dictionary = CHAPTER_THEMES[_chapter - 1] if _chapter >= 1 else CHAPTER_THEMES[0]
	var bias: float = float(theme.get("warmth_bias", 0.0))
	_daylight = {"yaw": sin(phase * TAU / 180.0) * 0.07,
		"warmth": clampf(lerpf(0.06, 0.26, sunlight) + bias, 0.0, 0.45),
		"light_strength": lerpf(0.10, 0.24, sunlight),
		"aspect": size.x / maxf(1.0, size.y)}
	for key: String in _daylight:
		_sky_material.set_shader_parameter(key, _daylight[key])
	_sky_material.set_shader_parameter("mote_time", phase)
	_sky_material.set_shader_parameter("mote_strength", 0.0 if _reduced_motion else 1.0)
	_sky_material.set_shader_parameter("mote_color", theme.get("mote", Color("#fff9dc")))


static func chapter_atmosphere(chapter: int) -> Dictionary:
	var index: int = clampi(chapter - 1, 0, CHAPTER_THEMES.size() - 1) if chapter >= 1 else 0
	var theme: Dictionary = CHAPTER_THEMES[index]
	return {
		"chapter": chapter,
		"warmth": clampf(0.16 + float(theme.get("warmth_bias", 0.0)), 0.0, 0.45),
		"well_tint": theme.get("well_tint", Color("#e9f4ea")),
		"key_light": theme.get("key_light", Color("#fff2d4")),
		"ambient_light": theme.get("ambient_light", Color("#e4f2e8")),
		"mote": theme.get("mote", Color("#fff9dc"))
	}


func atmosphere() -> Dictionary:
	var info: Dictionary = chapter_atmosphere(_chapter)
	info["warmth"] = float(_daylight.get("warmth", info.warmth))
	return info


func snapshot() -> Dictionary:
	var result := _daylight.duplicate()
	result.merge({"elapsed": _elapsed, "active": is_processing(), "reduced_motion": _reduced_motion,
		"chapter": _chapter})
	return result


func _stamp(texture: Texture2D, anchor: Vector2, width: float, pivot: Vector2, tint: Color = Color.WHITE) -> void:
	var art_size: Vector2 = texture.get_size() * (width / texture.get_width())
	draw_texture_rect(texture, Rect2(anchor - art_size * pivot, art_size), false, tint)


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var scale: float = Style.ui_scale(self)
	var theme: Dictionary = CHAPTER_THEMES[_chapter - 1] if _chapter >= 1 else CHAPTER_THEMES[0]
	var hill_width: float = maxf(size.x, size.y) * 1.25
	_stamp(HILLS, Vector2(size.x * 0.43, size.y * 0.82), hill_width, Vector2(0.5, 0.0), theme.hill)
	var portrait: bool = size.x < size.y
	var tree_height: float = minf(minf(size.y * 0.24, size.x * 0.46), 230.0 / scale)
	var left_prop: Texture2D = CHAPTER_PROPS[_chapter - 1] if _chapter >= 2 else TREE
	var right_prop: Texture2D = CHAPTER_PROPS[_chapter - 1] if _chapter >= 3 else TREE_LONG
	_stamp(left_prop, Vector2(size.x * (0.005 if portrait else 0.045), size.y * 1.02), tree_height * left_prop.get_width() / left_prop.get_height(), Vector2(0.5, 1.0), theme.prop)
	var right_tint: Color = Color(theme.prop.r, theme.prop.g, theme.prop.b, maxf(0.24, theme.prop.a - 0.04))
	_stamp(right_prop, Vector2(size.x * 0.97, size.y * 1.02), tree_height * 0.88 * right_prop.get_width() / right_prop.get_height(), Vector2(0.5, 1.0), right_tint)
	_stamp(HILLS, Vector2(size.x * 0.56, size.y * 0.94), hill_width, Vector2(0.5, 0.0), theme.hill2)
	var foliage_width: float = minf(size.x * 0.26, 200.0 / scale)
	_stamp(FOLIAGE, Vector2(0.0, size.y * 1.05), foliage_width, Vector2(0.35, 1.0), theme.prop)
	_stamp(FOLIAGE, Vector2(size.x, size.y * 1.06), foliage_width * 0.86, Vector2(0.65, 1.0), right_tint)
	draw_texture_rect(_header_wash, Rect2(Vector2.ZERO, Vector2(size.x, minf(size.y * 0.25, 220.0 / scale))), false, Color(1, 1, 1, 0.58))