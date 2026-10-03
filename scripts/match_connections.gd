extends Control

const Style = preload("res://scripts/ui_style.gd")
const GUTTER_PIXELS: float = 44.0
const PAIR_COLORS: Array[Color] = [
	Color("#31856a"), Color("#377eac"), Color("#8a66b0"), Color("#b48330"), Color("#b05d7b")
]

var connections: Array[Dictionary] = []
var focused_id: String = ""
var vertical_pairs: bool = false
var _bound_cards: Array[Control] = []
var _pixel: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(refresh_geometry)
	set_process(false)


func clear() -> void:
	for card in _bound_cards:
		if is_instance_valid(card) and card.item_rect_changed.is_connected(refresh_geometry):
			card.item_rect_changed.disconnect(refresh_geometry)
	_bound_cards.clear()
	connections.clear()
	focused_id = ""
	hide()
	queue_redraw()


func configure(pairs: Array[Dictionary], stacked: bool) -> void:
	var previous_focus: String = focused_id
	var previous_ids: Array = connections.map(func(pair: Dictionary) -> String: return str(pair.id))
	clear()
	vertical_pairs = stacked
	for pair in pairs:
		var source: Control = pair.source
		var target: Control = pair.target
		if not is_instance_valid(source) or not is_instance_valid(target):
			continue
		connections.append({"id": pair.id, "source": source, "target": target,
			"lane": pair.lane, "color": PAIR_COLORS[int(pair.lane) % PAIR_COLORS.size()],
			"path": PackedVector2Array()})
		for card in [source, target]:
			if not _bound_cards.has(card):
				_bound_cards.append(card)
				card.item_rect_changed.connect(refresh_geometry)
		if not previous_ids.has(pair.id):
			previous_focus = str(pair.id)
	if not focus_pair(previous_focus) and not connections.is_empty():
		focus_pair(str(connections.back().id))
	visible = not connections.is_empty()
	refresh_geometry()


func focus_pair(word_id: String) -> bool:
	if not connections.any(func(pair: Dictionary) -> bool: return pair.id == word_id):
		return false
	focused_id = word_id
	queue_redraw()
	return true


func visible_connections() -> Array[Dictionary]:
	var ordered: Array[Dictionary] = connections.filter(func(pair: Dictionary) -> bool: return pair.id != focused_id)
	ordered.append_array(connections.filter(func(pair: Dictionary) -> bool: return pair.id == focused_id))
	return ordered


func refresh_geometry() -> void:
	_pixel = 1.0 / Style.ui_scale(self)
	var inverse: Transform2D = get_global_transform().affine_inverse()
	for connection in connections:
		connection.path = PackedVector2Array()
		if not is_instance_valid(connection.source) or not is_instance_valid(connection.target):
			continue
		var picture: Rect2 = inverse * connection.source.get_global_rect()
		var word: Rect2 = inverse * connection.target.get_global_rect()
		var start: Vector2
		var end: Vector2
		var direction: Vector2
		var gap: float
		if vertical_pairs:
			start = Vector2(picture.get_center().x, picture.end.y - 2.0 * _pixel)
			end = Vector2(word.get_center().x, word.position.y + 2.0 * _pixel)
			direction = Vector2.DOWN
			gap = end.y - start.y
		else:
			start = Vector2(picture.end.x - 2.0 * _pixel, picture.get_center().y)
			end = Vector2(word.position.x + 2.0 * _pixel, word.get_center().y)
			direction = Vector2.RIGHT
			gap = end.x - start.x
		# Stable control lanes keep accumulated curves apart without rerouting earlier pairs.
		var lane_fraction: float = lerpf(0.15, 0.85, float(connection.lane) / float(PAIR_COLORS.size() - 1))
		var first_control: Vector2 = start + direction * gap * lane_fraction
		var second_control: Vector2 = end - direction * gap * (1.0 - lane_fraction)
		var path := PackedVector2Array()
		for step in range(49):
			path.append(start.bezier_interpolate(first_control, second_control, end, float(step) / 48.0))
		connection.path = path
	queue_redraw()


func _draw() -> void:
	for connection in visible_connections():
		var path: PackedVector2Array = connection.path
		if path.size() < 2:
			continue
		var tint: Color = connection.color
		var line_width: float = 3.0 if connection.id == focused_id else 2.25
		# A light casing separates crossings so different pairs cannot read as one junction.
		draw_polyline(path, Color.WHITE, (line_width + 2.5) * _pixel, true)
		draw_polyline(path, tint, line_width * _pixel, true)
		for contact in [path[0], path[path.size() - 1]]:
			draw_circle(contact, 4.5 * _pixel, tint)
			draw_circle(contact, 2.2 * _pixel, Color.WHITE)
