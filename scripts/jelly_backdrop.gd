extends Control
## Sourced garden layers frame the playfield; only the two cloud controls move.

const Style = preload("res://scripts/ui_style.gd")
const SKY = preload("res://assets/images/jelly-match/garden/sky.png")
const HILLS = preload("res://assets/images/jelly-match/garden/hills.png")
const CLOUD_BANK = preload("res://assets/images/jelly-match/garden/cloud-bank.png")
const CLOUD = preload("res://assets/images/jelly-match/garden/cloud.png")
const CLOUD_SMALL = preload("res://assets/images/jelly-match/garden/cloud-small.png")
const TREE = preload("res://assets/images/jelly-match/garden/tree.png")
const TREE_LONG = preload("res://assets/images/jelly-match/garden/tree-long.png")
const FOLIAGE = preload("res://assets/images/jelly-match/garden/foliage.png")

var _header_wash := GradientTexture2D.new()
var _elapsed: float = 0.0
var _ambient_active: bool = false
var _reduced_motion: bool = false
var _clouds: Array[TextureRect] = []
var _cloud_origins: Array[Vector2] = []


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
	resized.connect(_layout)
	visibility_changed.connect(_sync_motion)
	set_process(false)
	for texture: Texture2D in [CLOUD, CLOUD_SMALL]:
		var cloud := TextureRect.new()
		cloud.name = "DriftingCloud%d" % _clouds.size()
		cloud.texture = texture
		cloud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cloud.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cloud.focus_mode = Control.FOCUS_NONE
		cloud.modulate.a = 0.70 if _clouds.is_empty() else 0.58
		add_child(cloud)
		_clouds.append(cloud)
		_cloud_origins.append(Vector2.ZERO)


func _ready() -> void:
	_layout()
	_sync_motion()


func set_ambient_active(value: bool) -> void:
	_ambient_active = value
	_sync_motion()


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	_position_clouds()
	_sync_motion()


func _sync_motion() -> void:
	set_process(_ambient_active and not _reduced_motion and is_visible_in_tree())


func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_elapsed = fmod(_elapsed + delta, 240.0)
	_position_clouds()


func _layout() -> void:
	var portrait: bool = size.x < size.y
	var width: float = minf(size.x * (0.30 if portrait else 0.18), 280.0 / Style.ui_scale(self))
	for index: int in range(_clouds.size()):
		var cloud: TextureRect = _clouds[index]
		cloud.size = cloud.texture.get_size() * (width * (1.0 if index == 0 else 0.84) / cloud.texture.get_width())
		_cloud_origins[index] = Vector2(size.x * (0.27 if portrait else 0.14), size.y * (0.145 if portrait else 0.07)) if index == 0 else Vector2(size.x * 0.79, size.y * (0.22 if portrait else 0.12))
	_position_clouds()
	queue_redraw()


func _position_clouds() -> void:
	for index: int in range(_clouds.size()):
		var drift: float = 0.0 if _reduced_motion else sin(_elapsed * TAU / (60.0 if index == 0 else 80.0)) * 8.0 / Style.ui_scale(self)
		_clouds[index].position = _cloud_origins[index] + Vector2(drift * (1.0 if index == 0 else -0.75), 0.0)


func _stamp(texture: Texture2D, anchor: Vector2, width: float, pivot: Vector2, tint: Color = Color.WHITE) -> void:
	var art_size: Vector2 = texture.get_size() * (width / texture.get_width())
	draw_texture_rect(texture, Rect2(anchor - art_size * pivot, art_size), false, tint)


func _draw_cloud_bank() -> void:
	var width: float = maxf(size.x, size.y) * 1.16
	var art_size: Vector2 = CLOUD_BANK.get_size() * (width / CLOUD_BANK.get_width())
	var origin := Vector2(size.x * 0.5, size.y * 0.70) - art_size * Vector2(0.5, 1.0)
	var fade_start: float = 0.62
	var upper_size := Vector2(art_size.x, art_size.y * fade_start)
	var tint := Color(1, 1, 1, 0.56)
	draw_texture_rect_region(CLOUD_BANK, Rect2(origin, upper_size), Rect2(Vector2.ZERO, Vector2(CLOUD_BANK.get_width(), CLOUD_BANK.get_height() * fade_start)), tint)
	# Fade the original artwork's flat lower edge into the sky on wide screens.
	var top_left := origin + Vector2(0, upper_size.y)
	var top_right := origin + upper_size
	var bottom_right := origin + art_size
	var bottom_left := origin + Vector2(0, art_size.y)
	draw_polygon(PackedVector2Array([top_left, top_right, bottom_right, bottom_left]),
		PackedColorArray([tint, tint, Color(1, 1, 1, 0), Color(1, 1, 1, 0)]),
		PackedVector2Array([Vector2(0, fade_start), Vector2(1, fade_start), Vector2(1, 1), Vector2(0, 1)]), CLOUD_BANK)


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var scale: float = Style.ui_scale(self)
	var cover: float = maxf(size.x / SKY.get_width(), size.y / SKY.get_height())
	var art_size: Vector2 = SKY.get_size() * cover
	draw_texture_rect(SKY, Rect2((size - art_size) * Vector2(0.5, 0.35), art_size), false)
	_draw_cloud_bank()
	var hill_width: float = maxf(size.x, size.y) * 1.20
	_stamp(HILLS, Vector2(size.x * 0.43, size.y * 0.65), hill_width, Vector2(0.5, 0.0), Color(0.92, 0.98, 0.88, 0.70))
	# Edge silhouettes are quiet enough to sit behind the board and reward controls.
	var portrait: bool = size.x < size.y
	var tree_height: float = minf(minf(size.y * 0.43, size.x * 0.76), 440.0 / scale)
	_stamp(TREE, Vector2(size.x * (0.025 if portrait else 0.08), size.y * 0.96), tree_height * TREE.get_width() / TREE.get_height(), Vector2(0.5, 1.0), Color(1, 1, 1, 0.44))
	_stamp(TREE_LONG, Vector2(size.x * (0.98 if portrait else 0.94), size.y * 0.95), tree_height * 0.88 * TREE_LONG.get_width() / TREE_LONG.get_height(), Vector2(0.5, 1.0), Color(1, 1, 1, 0.38))
	_stamp(HILLS, Vector2(size.x * 0.56, size.y * 0.86), hill_width * 1.05, Vector2(0.5, 0.0), Color(0.89, 1, 0.77, 0.80))
	var foliage_width: float = minf(size.x * 0.31, 240.0 / scale)
	_stamp(FOLIAGE, Vector2(0.0, size.y * 1.035), foliage_width, Vector2(0.35, 1.0), Color(1, 1, 1, 0.46))
	_stamp(FOLIAGE, Vector2(size.x, size.y * 1.045), foliage_width * 0.86, Vector2(0.65, 1.0), Color(1, 1, 1, 0.38))
	# A warm atmospheric wash separates gameplay from the source illustrations.
	draw_rect(Rect2(Vector2.ZERO, size), Color("#fff9ed", 0.20))
	draw_texture_rect(_header_wash, Rect2(Vector2.ZERO, Vector2(size.x, minf(size.y * 0.33, 300.0 / scale))), false, Color(1, 1, 1, 0.82))
