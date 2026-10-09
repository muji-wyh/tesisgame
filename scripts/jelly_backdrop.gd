extends Control
## Acquired woodland art frames the playfield without competing with vocabulary.

const WOODLAND = preload("res://assets/images/jelly-match/environment/woodland.png")
const TREE = preload("res://assets/images/jelly-match/environment/tree.png")
const BUSH = preload("res://assets/images/jelly-match/environment/bush.png")
const MUSHROOM = preload("res://assets/images/jelly-match/environment/mushroom.png")

var _header_wash := GradientTexture2D.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#fffdf5"), Color("#fffdf5", 0.0)])
	_header_wash.gradient = gradient
	_header_wash.width = 4
	_header_wash.height = 256
	_header_wash.fill_from = Vector2(0.5, 0.0)
	_header_wash.fill_to = Vector2(0.5, 1.0)
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var cover: float = maxf(size.x / WOODLAND.get_width(), size.y / WOODLAND.get_height())
	var art_size: Vector2 = WOODLAND.get_size() * cover
	draw_texture_rect(WOODLAND, Rect2(Vector2((size.x - art_size.x) * 0.5, size.y - art_size.y), art_size), false)
	# Keep detailed trunks and foreground foliage at the edges, away from the well.
	var portrait: bool = size.x < size.y
	var tree_height: float = minf(size.y * 0.5, size.x * (0.72 if portrait else 0.28))
	var tree_size: Vector2 = TREE.get_size() * (tree_height / TREE.get_height())
	var outside: float = 0.63 if portrait else 0.23
	var left: float = -tree_size.x * outside
	var right: float = size.x - tree_size.x * (1.0 - outside)
	draw_texture_rect(TREE, Rect2(Vector2(left, size.y - tree_height), tree_size), false)
	draw_texture_rect(TREE, Rect2(Vector2(right, size.y - tree_height * 0.92), tree_size), false)
	var bush_width: float = minf(size.x * 0.36, size.y * 0.32)
	var bush_size: Vector2 = BUSH.get_size() * (bush_width / BUSH.get_width())
	draw_texture_rect(BUSH, Rect2(Vector2(-bush_width * 0.15, size.y - bush_size.y * 0.78), bush_size), false)
	draw_texture_rect(BUSH, Rect2(Vector2(size.x - bush_width * 0.8, size.y - bush_size.y * 0.9), bush_size), false)
	var mushroom_width: float = minf(size.x * 0.10, size.y * 0.085)
	var mushroom_size: Vector2 = MUSHROOM.get_size() * (mushroom_width / MUSHROOM.get_width())
	draw_texture_rect(MUSHROOM, Rect2(Vector2(size.x * 0.065, size.y - mushroom_size.y * 0.95), mushroom_size), false)
	# A light atmospheric veil and header wash keep existing controls legible.
	draw_rect(Rect2(Vector2.ZERO, size), Color("#fffaf0", 0.30))
	draw_texture_rect(_header_wash, Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.30)), false, Color(1, 1, 1, 0.82))
