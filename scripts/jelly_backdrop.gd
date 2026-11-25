extends Control
## A sourced panoramic sky, calm daylight and low garden edges frame the board.

const Style = preload("res://scripts/ui_style.gd")
const SKY = preload("res://assets/images/jelly-match/sky/day.png")
const SKY_MORNING = preload("res://assets/images/jelly-match/sky/morning.png")
const SKY_NIGHT = preload("res://assets/images/jelly-match/sky/night.png")
const DAYLIGHT = preload("res://scripts/jelly_daylight.gdshader")
const HILLS = preload("res://assets/images/jelly-match/garden/hills.png")
const TREE = preload("res://assets/images/jelly-match/garden/tree.png")
const TREE_LONG = preload("res://assets/images/jelly-match/garden/tree-long.png")
const FOLIAGE = preload("res://assets/images/jelly-match/garden/foliage.png")
const CHAPTER_SKIES: Array[Texture2D] = [
	SKY, SKY, SKY, SKY,
	SKY_MORNING,
	SKY_NIGHT, SKY_NIGHT,
	SKY_MORNING, SKY_MORNING,
	SKY_NIGHT, SKY_NIGHT
]
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
var _impact_glow: float = 0.0
var _impact_glow_value: float = 0.0
var _impact_glow_elapsed: float = 1.0
var _impact_glow_duration: float = 0.36
var _impact_glow_color := Color("#ffea98")
var _boss_kick_strength: float = 0.0
var _boss_kick_elapsed: float = 1.0
var _boss_kick_duration: float = 0.42
var _boss_kick_dir := Vector2(0.0, 1.0)
var _boss_kick_offset := Vector2.ZERO
var _boss_kick_zoom: float = 0.0


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
	_apply_impact_shader()


func _ready() -> void:
	_layout()
	_sync_motion()


func set_ambient_active(value: bool) -> void:
	_ambient_active = value
	_sync_motion()


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if value:
		_clear_impact_effects()
	_update_daylight()
	_sync_motion()


func pulse_ambient_glow(strength: float, color: Color = Color("#ffea98"), duration: float = 0.34) -> void:
	if _reduced_motion or not is_finite(strength) or strength <= 0.0:
		return
	var next: float = clampf(strength, 0.0, 1.0)
	if next >= _impact_glow * 0.65 or _impact_glow_elapsed >= _impact_glow_duration:
		_impact_glow = maxf(_impact_glow * 0.6, next)
		_impact_glow_color = color
		_impact_glow_duration = clampf(duration, 0.16, 0.65)
		_impact_glow_elapsed = 0.0
		_apply_impact_shader()


func trigger_boss_shockwave(strength: float, color: Color = Color("#ffe58f"), direction: Vector2 = Vector2(0.0, 1.0)) -> void:
	if _reduced_motion or not is_finite(strength) or strength <= 0.0:
		return
	var next: float = clampf(strength, 0.25, 1.25)
	_boss_kick_strength = maxf(_boss_kick_strength * 0.7, next)
	_boss_kick_dir = direction.normalized() if direction.length_squared() > 0.01 else Vector2(0.0, 1.0)
	_boss_kick_duration = 0.48 if next >= 1.0 else 0.38
	_boss_kick_elapsed = 0.0
	pulse_ambient_glow(minf(1.0, next * 0.95), color, _boss_kick_duration + 0.10)
	_apply_impact_shader()
	queue_redraw()


func _clear_impact_effects() -> void:
	var had_kick: bool = not _boss_kick_offset.is_zero_approx() or _boss_kick_zoom > 0.0001
	_impact_glow = 0.0
	_impact_glow_elapsed = _impact_glow_duration
	_boss_kick_strength = 0.0
	_boss_kick_elapsed = _boss_kick_duration
	_boss_kick_offset = Vector2.ZERO
	_boss_kick_zoom = 0.0
	_apply_impact_shader()
	if had_kick:
		queue_redraw()


func _apply_impact_shader() -> void:
	var glow_val: float = 0.0
	if not _reduced_motion and _impact_glow > 0.0 and _impact_glow_elapsed < _impact_glow_duration:
		var gp: float = clampf(_impact_glow_elapsed / _impact_glow_duration, 0.0, 1.0)
		# Instant-attack glow peak at t=0 (1.0 -> silky exponential decay) so frame-0 hits read immediately.
		var rise: float = lerpf(0.72, 1.0, smoothstep(0.0, 0.08, gp))
		glow_val = rise * pow(1.0 - gp, 1.75) * _impact_glow
	_impact_glow_value = glow_val
	_sky_material.set_shader_parameter("impact_glow", glow_val)
	_sky_material.set_shader_parameter("impact_color", _impact_glow_color)
	var u: float = 1.0 / maxf(0.1, Style.ui_scale(self))
	var kick_offset := Vector2.ZERO
	var kick_zoom: float = 0.0
	if not _reduced_motion and _boss_kick_strength > 0.0 and _boss_kick_elapsed < _boss_kick_duration:
		var kp: float = clampf(_boss_kick_elapsed / _boss_kick_duration, 0.0, 1.0)
		# Dramatic Boss finisher / POWER! smash: big heavy downward slam (up to 16px on
		# foreground scenery + 3.2% panoramic punch-zoom) with one deep cushion rebound!
		var env: float = pow(1.0 - kp, 1.55) * exp(-kp * 3.1) * _boss_kick_strength
		var wave: float = cos(kp * TAU * 0.95)
		kick_offset = (_boss_kick_dir * (14.5 * wave) + Vector2(0.0, 4.5 * sin(kp * PI))) * env * u
		kick_zoom = clampf(pow(1.0 - kp, 1.8) * exp(-kp * 2.2) * 0.032 * _boss_kick_strength, 0.0, 0.045)
	_boss_kick_offset = kick_offset
	_boss_kick_zoom = kick_zoom
	var uv_shift := Vector2(kick_offset.x / maxf(1.0, size.x), kick_offset.y / maxf(1.0, size.y)) * 0.55
	_sky_material.set_shader_parameter("impact_zoom", kick_zoom)
	_sky_material.set_shader_parameter("impact_shift", uv_shift)


func set_chapter(chapter: int) -> void:
	var next: int = clampi(chapter, 0, CHAPTER_PROPS.size())
	if next == _chapter:
		return
	_chapter = next
	_sky.texture = CHAPTER_SKIES[_chapter - 1] if _chapter >= 1 and _chapter <= CHAPTER_SKIES.size() else SKY
	_update_daylight()
	queue_redraw()


func _sync_motion() -> void:
	set_process(_ambient_active and not _reduced_motion and is_visible_in_tree())


func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_elapsed = fmod(_elapsed + delta * clampf(motion_scale, 0.0, 1.0), 360.0)
	_update_daylight()
	var dt: float = minf(delta, 0.05)
	var impact_dirty: bool = false
	var needs_redraw: bool = false
	if _impact_glow > 0.0 and _impact_glow_elapsed < _impact_glow_duration:
		_impact_glow_elapsed = minf(_impact_glow_duration, _impact_glow_elapsed + dt)
		impact_dirty = true
		if _impact_glow_elapsed >= _impact_glow_duration:
			_impact_glow = 0.0
	if _boss_kick_strength > 0.0 and _boss_kick_elapsed < _boss_kick_duration:
		_boss_kick_elapsed = minf(_boss_kick_duration, _boss_kick_elapsed + dt)
		impact_dirty = true
		needs_redraw = true
		if _boss_kick_elapsed >= _boss_kick_duration:
			_boss_kick_strength = 0.0
	if impact_dirty:
		_apply_impact_shader()
	if needs_redraw:
		queue_redraw()


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
		"chapter": _chapter,
		"impact_glow": _impact_glow_value,
		"boss_kick_offset": [_boss_kick_offset.x, _boss_kick_offset.y],
		"boss_kick_zoom": _boss_kick_zoom})
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
	# Upgraded 3D diorama props deserve crisp, rich visibility along board edges while keeping central playfield calm.
	var hill_tint: Color = Color(theme.hill.r, theme.hill.g, theme.hill.b, 0.72)
	var hill2_tint: Color = Color(theme.hill2.r, theme.hill2.g, theme.hill2.b, 0.84)
	var prop_tint: Color = Color(theme.prop.r, theme.prop.g, theme.prop.b, 0.86)
	var right_tint: Color = Color(theme.prop.r, theme.prop.g, theme.prop.b, 0.78)
	# Layered parallax displacement ONLY during dramatic Boss shockwaves (0px during ordinary play!).
	var far_kick: Vector2 = _boss_kick_offset * 0.45
	var mid_kick: Vector2 = _boss_kick_offset * 0.82
	var near_kick: Vector2 = _boss_kick_offset * 1.18
	_stamp(HILLS, Vector2(size.x * 0.43, size.y * 0.80) + far_kick, hill_width, Vector2(0.5, 0.0), hill_tint)
	var portrait: bool = size.x < size.y
	var tree_height: float = minf(minf(size.y * 0.27, size.x * 0.48), 255.0 / scale)
	var left_prop: Texture2D = CHAPTER_PROPS[_chapter - 1] if _chapter >= 2 else TREE
	var right_prop: Texture2D = CHAPTER_PROPS[_chapter - 1] if _chapter >= 3 else TREE_LONG
	_stamp(left_prop, Vector2(size.x * (0.01 if portrait else 0.048), size.y * 1.01) + mid_kick, tree_height * left_prop.get_width() / left_prop.get_height(), Vector2(0.5, 1.0), prop_tint)
	_stamp(right_prop, Vector2(size.x * 0.965, size.y * 1.01) + mid_kick, tree_height * 0.90 * right_prop.get_width() / right_prop.get_height(), Vector2(0.5, 1.0), right_tint)
	_stamp(HILLS, Vector2(size.x * 0.56, size.y * 0.92) + mid_kick, hill_width, Vector2(0.5, 0.0), hill2_tint)
	var foliage_width: float = minf(size.x * 0.28, 220.0 / scale)
	_stamp(FOLIAGE, Vector2(0.0, size.y * 1.04) + near_kick, foliage_width, Vector2(0.32, 1.0), prop_tint)
	_stamp(FOLIAGE, Vector2(size.x, size.y * 1.05) + near_kick, foliage_width * 0.88, Vector2(0.68, 1.0), right_tint)
	draw_texture_rect(_header_wash, Rect2(Vector2.ZERO, Vector2(size.x, minf(size.y * 0.25, 220.0 / scale))), false, Color(1, 1, 1, 0.58))