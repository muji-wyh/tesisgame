extends VBoxContainer

signal item_selected(id: String)
signal word_requested(word_id: String)
signal toy_played(kind: String)

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Medal = preload("res://scripts/medal_view.gd")
const SUMMER_BALL_TINT := Color("#ffd16b")
const ACTIONS := {"water": "Water the flower", "roll": "Roll the ball", "offer": "Offer the apple", "ring": "Ring the bell", "open": "Listen to the shell", "launch": "Launch the rocket"}
const OUTCOMES := {"water": "The flower blooms for Pip!", "roll": "The ball rolls to Pip!", "offer": "An apple for Pip. Yum!", "ring": "The bell rings. Ding, ding!", "open": "Pip listens to the shell. Whoosh!", "launch": "The rocket takes off. Whoosh!"}

class RoomScene extends Control:
	var theme_id: String = "home"
	var palette: Dictionary = {}
	var action: String = ""
	var action_progress: float = 0.0
	var toy_center: Vector2

	func _draw() -> void:
		var accent: Color = palette.get("accent", Color("#438363"))
		var background: Color = palette.get("background", Color("#edf8ec"))
		draw_style_box(preload("res://scripts/ui_style.gd").box(background, accent.lightened(0.6), 24, 2), Rect2(Vector2.ZERO, size))
		var floor_y := size.y * 0.78
		draw_line(Vector2(12, floor_y), Vector2(size.x - 12, floor_y), accent.lightened(0.6), 2, true)
		if theme_id == "space":
			for index in range(14):
				var point := Vector2(18 + fmod(index * 47.0, maxf(20, size.x - 36)), 32 + fmod(index * 31.0, 100))
				draw_circle(point, 1.5 + index % 2, accent.lightened(0.35))
			draw_arc(Vector2(size.x * 0.69, 65), 25, 0, TAU, 32, accent.lightened(0.55), 5, true)
		elif theme_id == "ocean":
			for row in range(3):
				for index in range(8):
					draw_arc(Vector2(index * 44 + 8, 75 + row * 29), 24, 0.12, PI - 0.12, 14, accent.lightened(0.67), 2, true)
		elif theme_id == "winter":
			for index in range(10):
				var point := Vector2(22 + fmod(index * 49.0, maxf(20, size.x - 40)), 46 + fmod(index * 37.0, 84))
				draw_line(point - Vector2(4, 0), point + Vector2(4, 0), accent.lightened(0.58), 2, true)
				draw_line(point - Vector2(0, 4), point + Vector2(0, 4), accent.lightened(0.58), 2, true)
		elif theme_id == "summer":
			draw_circle(Vector2(size.x - 49, 59), 24, Color("#ffd878"))
			for index in range(8):
				var direction := Vector2.from_angle(index * TAU / 8)
				draw_line(Vector2(size.x - 49, 59) + direction * 29, Vector2(size.x - 49, 59) + direction * 36, Color("#e9b34a"), 3, true)
		elif theme_id == "autumn":
			for index in range(7):
				var point := Vector2(22 + index * maxf(20, (size.x - 44) / 7), 48 + index % 3 * 26)
				draw_colored_polygon(PackedVector2Array([point, point + Vector2(11, -8), point + Vector2(16, 3), point + Vector2(6, 10)]), Color("#d9ab66"))
		elif theme_id == "spring":
			for index in range(5):
				var point := Vector2(24 + index * maxf(24, (size.x - 48) / 5), floor_y + 21)
				draw_line(point, point - Vector2(0, 15), accent.lightened(0.35), 2, true)
				draw_circle(point - Vector2(0, 17), 5, Color("#edb5bd") if index % 2 == 0 else Color("#f0d077"))
		else:
			var window := Rect2(Vector2(size.x * 0.67 - 32, 38), Vector2(64, 58))
			draw_style_box(preload("res://scripts/ui_style.gd").box(accent.lightened(0.88), accent.lightened(0.5), 10, 3), window)
			draw_line(Vector2(window.get_center().x, window.position.y + 2), Vector2(window.get_center().x, window.end.y - 2), accent.lightened(0.5), 3, true)
			draw_line(Vector2(window.position.x + 2, window.get_center().y), Vector2(window.end.x - 2, window.get_center().y), accent.lightened(0.5), 3, true)
		if action.is_empty():
			return
		var point := toy_center
		if action == "water":
			for index in range(3):
				draw_line(point + Vector2(-22 + index * 19, -66), point + Vector2(-25 + index * 19, -55), Color("#58a9c9"), 3, true)
		elif action == "ring":
			for side in [-1, 1]:
				for index in range(2):
					draw_arc(point + Vector2(side * 20, 0), 26 + index * 9, -0.8 if side == 1 else PI - 0.8, 0.8 if side == 1 else PI + 0.8, 12, accent, 2, true)
		elif action == "open":
			for row in range(3):
				var wave := PackedVector2Array()
				for index in range(12):
					wave.append(point + Vector2(-64 + index * 3, -18 + row * 14 + sin(index * 0.8) * 3))
				draw_polyline(wave, Color("#58a9c9"), 2, true)
		elif action == "launch":
			for index in range(3):
				var start := point + Vector2((index - 1) * 12, 40)
				draw_line(start, start + Vector2(0, 12 + index % 2 * 13), Color("#efb14f"), 4, true)
		elif action == "offer":
			for index in range(3):
				draw_circle(point + Vector2(-12 + index * 11, 28 + index % 2 * 7), 2.5, Color("#d49854"))
		elif action == "roll":
			for index in range(3):
				draw_line(point + Vector2(36 + index * 9, -7 + index * 7), point + Vector2(44 + index * 9, -7 + index * 7), accent.lightened(0.3), 2, true)

var duck_slot: Control
var caption: Label
var favorite_medal: Medal
var toy_button: Button
var action_button: Button
var item_buttons: Dictionary = {}
var category_buttons: Dictionary = {}
var goal_label: Label
var interaction_allowed: Callable

var _state: RefCounted
var _counts: Dictionary = {}
var _palette: Dictionary = {}
var _reduced_motion: bool = false
var _category: String = "toy"
var _preview_id: String = ""
var _last_toy: String = ""
var _last_backdrop: String = ""
var _toy: Dictionary = {}
var _room: RoomScene
var _room_title: Label
var _toy_label: Label
var _item_grid: GridContainer
var _item_labels: Dictionary = {}
var _base_toy_position: Vector2
var _action: String = ""
var _action_progress: float = 0.0
var _preview_locked: bool = false


func _ready() -> void:
	_build()


func _build() -> void:
	if _room != null:
		return
	name = "PipsRoom"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	add_child(Style.label("Pip's room", 26))
	goal_label = Style.label("", 17)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(goal_label)
	_room = RoomScene.new()
	_room.custom_minimum_size = Vector2(0, 224)
	_room.clip_contents = true
	_room.resized.connect(_layout_room)
	add_child(_room)
	_room_title = Style.label("Pip's home", 18)
	_room.add_child(_room_title)
	duck_slot = Control.new()
	duck_slot.name = "RoomPipSlot"
	duck_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.add_child(duck_slot)
	favorite_medal = Medal.new()
	favorite_medal.name = "RoomFavoriteMedal"
	favorite_medal.show_missing = true
	favorite_medal.hide()
	_room.add_child(favorite_medal)
	toy_button = Button.new()
	toy_button.name = "PlayRoomToy"
	Style.button(toy_button, Style.GOOD)
	for style_name in ["normal", "disabled"]:
		toy_button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	toy_button.expand_icon = true
	toy_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toy_button.add_theme_constant_override("icon_max_width", 84)
	toy_button.pressed.connect(_play_toy)
	_room.add_child(toy_button)
	_toy_label = Style.label("ball", 21)
	_toy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room.add_child(_toy_label)
	caption = Style.label("Choose a toy, then play with Pip!", 18)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.y = 50
	add_child(caption)
	action_button = Button.new()
	action_button.name = "RoomToyAction"
	Style.button(action_button, Style.GOOD)
	action_button.pressed.connect(_play_toy)
	add_child(action_button)
	var categories := HBoxContainer.new()
	categories.add_theme_constant_override("separation", 8)
	add_child(categories)
	for entry in [["toy", "Toys"], ["backdrop", "Rooms"]]:
		var button := Button.new()
		button.name = "RoomCategory_" + entry[0]
		button.text = entry[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Style.button(button, Style.GOOD)
		button.pressed.connect(_show_category.bind(entry[0]))
		categories.add_child(button)
		category_buttons[entry[0]] = button
	_item_grid = GridContainer.new()
	_item_grid.columns = 2
	_item_grid.add_theme_constant_override("h_separation", 8)
	_item_grid.add_theme_constant_override("v_separation", 8)
	add_child(_item_grid)
	resized.connect(func() -> void: _item_grid.columns = 3 if size.x >= 520 else 2)
	visibility_changed.connect(_visibility_changed)
	set_process(false)


func configure(state, counts: Dictionary, palette: Dictionary, reduced_motion: bool) -> void:
	_build()
	var changed: bool = state.toy_id != _last_toy or state.backdrop_id != _last_backdrop
	_state = state
	_counts = counts.duplicate()
	_palette = palette
	_reduced_motion = reduced_motion
	_last_toy = state.toy_id
	_last_backdrop = state.backdrop_id
	if changed:
		_preview_id = ""
		_action = ""
		set_process(false)
	if item_buttons.is_empty():
		_build_items()
	_refresh_items()
	_refresh_room()
	if reduced_motion and not _action.is_empty():
		_action_progress = 1.0
		set_process(false)
		_apply_action()
	var gift: Dictionary = _state.next_gift(_counts, palette.get("id", ""))
	goal_label.text = "Every gift in this world is yours. Mix and play!" if gift.is_empty() else "Next gift: %s · %d more %s" % [gift.name, gift.remaining_pieces, "piece" if gift.remaining_pieces == 1 else "pieces"]


func _build_items() -> void:
	for item in _state.catalog():
		var button := Button.new()
		button.name = "RoomItem_" + item.id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Style.button(button, Style.GOOD)
		button.custom_minimum_size = Vector2(116, 148)
		button.pressed.connect(_choose_item.bind(item.id))
		var picture := TextureRect.new()
		picture.texture = _art(item)
		picture.self_modulate = SUMMER_BALL_TINT if item.id == "toy-summer" else Color.WHITE
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(picture)
		picture.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		picture.offset_top = 6
		picture.offset_left = 12
		picture.offset_right = -12
		picture.offset_bottom = 68
		var label := Style.label("", 15)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_left = 6
		label.offset_right = -6
		label.offset_top = 70
		label.offset_bottom = -6
		_item_grid.add_child(button)
		item_buttons[item.id] = button
		_item_labels[item.id] = label


func _item(id: String) -> Dictionary:
	for item in _state.catalog():
		if item.id == id:
			return item
	return {}


func _art(item: Dictionary) -> Texture2D:
	var imported: String = "res://assets/imported-unity/%s.png" % item.word_id
	return load(imported) if item.slot == "toy" and ResourceLoader.exists(imported) else load(item.art)


func _can_interact() -> bool:
	return is_visible_in_tree() and (not interaction_allowed.is_valid() or bool(interaction_allowed.call()))


func _name_control(control: Control, text: String) -> void:
	for property in control.get_property_list():
		if property.name == "accessibility_name":
			control.set("accessibility_name", text)
			return


func _remaining(item: Dictionary) -> int:
	if _state.owned(item, _counts):
		return 0
	var total := 0
	for medal in Data.medals(item.theme):
		total += maxi(0, 3 - int(_counts.get(medal.id, 0)))
		if medal.id == item.medal_id:
			break
	return total


func _requirement(item: Dictionary) -> String:
	var medal: Dictionary = Data.reward(item.medal_id)
	return "Complete %s: %d/3. %d more %s in %s." % [medal.name, _counts.get(item.medal_id, 0), _remaining(item), "piece" if _remaining(item) == 1 else "pieces", Data.theme(item.theme).name]


func _refresh_items() -> void:
	for item in _state.catalog():
		var button: Button = item_buttons[item.id]
		button.visible = item.slot == _category
		var earned: bool = _state.owned(item, _counts)
		var selected: bool = item.id == (_state.toy_id if item.slot == "toy" else _state.backdrop_id)
		var detail: String = "Using" if selected and earned else "Choose" if earned else "Complete %s · %d/3" % [Data.reward(item.medal_id).name, _counts.get(item.medal_id, 0)]
		_item_labels[item.id].text = item.name + "\n" + detail
		button.tooltip_text = item.name + ". " + (detail if earned else _requirement(item))
		_name_control(button, button.tooltip_text)
		button.add_theme_stylebox_override("normal", Style.box(_palette.get("light", Color.WHITE) if selected and earned else Color.WHITE, _palette.get("accent", Style.GOOD) if selected and earned else Color("#cbd5d8"), 16, 3 if selected and earned else 2))
	for id in category_buttons:
		category_buttons[id].add_theme_stylebox_override("normal", Style.box(_palette.get("light", Color.WHITE) if id == _category else Color.WHITE, _palette.get("accent", Style.GOOD)))


func _refresh_room() -> void:
	var previous_toy: String = _toy.get("id", "")
	_toy = _item(_state.toy_id)
	if _toy.is_empty() or not _state.owned(_toy, _counts):
		_toy = _item("toy-ball")
	var backdrop: Dictionary = _item(_state.backdrop_id)
	if backdrop.is_empty() or not _state.owned(backdrop, _counts):
		backdrop = _item("backdrop-home")
	var preview := _item(_preview_id)
	_preview_locked = not preview.is_empty() and not _state.owned(preview, _counts)
	if not preview.is_empty():
		if preview.slot == "toy":
			_toy = preview
		else:
			backdrop = preview
	if _toy.id != previous_toy:
		_action = ""
		set_process(false)
	_room.theme_id = backdrop.theme if backdrop.id != "backdrop-home" else "home"
	_room.palette = Data.theme(backdrop.theme) if Data.THEMES.has(backdrop.theme) else _palette
	_room_title.text = ("Preview: " if _preview_locked and preview.slot == "backdrop" else "") + str(backdrop.name)
	toy_button.icon = _art(_toy)
	toy_button.self_modulate = SUMMER_BALL_TINT if _toy.id == "toy-summer" else Color.WHITE
	toy_button.tooltip_text = ACTIONS[_toy.action]
	_name_control(toy_button, toy_button.tooltip_text)
	_toy_label.text = _toy.word_id
	action_button.disabled = _preview_locked
	toy_button.disabled = _preview_locked
	action_button.text = "Earn this " + preview.slot if _preview_locked else ACTIONS[_toy.action]
	if _preview_locked:
		caption.text = preview.name + ". " + _requirement(preview)
	elif _action.is_empty():
		caption.text = "%s %s for Pip. %s!" % ["An" if _toy.word_id == "apple" else "A", _toy.word_id, ACTIONS[_toy.action]]
	_layout_room()


func _show_category(id: String) -> void:
	if not _can_interact():
		return
	_category = id
	_preview_id = ""
	_action = ""
	set_process(false)
	_refresh_items()
	_refresh_room()


func _choose_item(id: String) -> void:
	if not _can_interact():
		return
	var item := _item(id)
	if item.is_empty():
		return
	if _state.owned(item, _counts):
		_preview_id = ""
		item_selected.emit(id)
	else:
		_preview_id = id
		_action = ""
		set_process(false)
		_refresh_room()


func _play_toy() -> void:
	if _preview_locked or _toy.is_empty() or not _can_interact():
		return
	_action = _toy.action
	_action_progress = 1.0 if _reduced_motion else 0.0
	caption.text = OUTCOMES[_action]
	_apply_action()
	set_process(not _reduced_motion)
	word_requested.emit(_toy.word_id)
	toy_played.emit(_action)


func _layout_room() -> void:
	if _room == null or toy_button == null:
		return
	var width := maxf(240, _room.size.x)
	var edge := clampf(width * 0.28, 72, 96)
	duck_slot.position = Vector2(10, 48)
	duck_slot.size = Vector2(minf(150, width * 0.49), 156)
	favorite_medal.position = Vector2(duck_slot.size.x - 24, 160)
	favorite_medal.size = Vector2(48, 48)
	_room_title.position = Vector2(14, 9)
	_room_title.size = Vector2(width - 28, 28)
	toy_button.size = Vector2.ONE * edge
	toy_button.pivot_offset = toy_button.size * 0.5
	_base_toy_position = Vector2(width - edge - 17, 102)
	_toy_label.position = Vector2(_base_toy_position.x - 8, 198)
	_toy_label.size = Vector2(edge + 16, 24)
	_apply_action()


func _apply_action() -> void:
	toy_button.position = _base_toy_position
	toy_button.scale = Vector2.ONE
	toy_button.rotation = 0
	var progress := smoothstep(0.0, 1.0, _action_progress)
	if _action == "water":
		toy_button.scale = Vector2.ONE * (1.0 + progress * 0.12)
	elif _action == "roll":
		toy_button.position.x -= progress * minf(80, _room.size.x * 0.25)
		toy_button.rotation = -TAU * progress
	elif _action == "offer":
		toy_button.position += Vector2(-minf(100, _room.size.x * 0.32), -8) * progress
		toy_button.scale = Vector2.ONE * (1.0 - progress * 0.3)
	elif _action == "ring":
		toy_button.rotation = -0.16 if _reduced_motion or progress == 1 else sin(progress * TAU * 3) * 0.2
	elif _action == "open":
		toy_button.rotation = -progress * 0.18
		toy_button.position.x -= progress * 18
	elif _action == "launch":
		toy_button.position.y -= progress * 54
	_toy_label.position.x = toy_button.position.x + toy_button.size.x * 0.5 - _toy_label.size.x * 0.5
	_room.action = _action
	_room.action_progress = progress
	_room.toy_center = toy_button.position + toy_button.size * 0.5
	_room.queue_redraw()


func _process(delta: float) -> void:
	_action_progress = minf(1.0, _action_progress + delta / 0.85)
	_apply_action()
	if _action_progress >= 1.0:
		set_process(false)


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		set_process(false)
		if not _action.is_empty():
			_action_progress = 1.0
			_apply_action()


func controls() -> Array[Control]:
	var result: Array[Control] = []
	# The host wires focus and scrolling once, including currently hidden choices.
	for button in [toy_button, action_button] + category_buttons.values() + item_buttons.values():
		if button != null:
			result.append(button)
	return result
