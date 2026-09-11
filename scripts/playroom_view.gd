extends VBoxContainer

signal item_selected(id: String)
signal item_previewed(message: String)
signal word_requested(word_id: String)
signal toy_played(kind: String)
signal goal_requested(id: String)
signal pip_interaction(kind: String, message: String)

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Medal = preload("res://scripts/medal_view.gd")
const Playground = preload("res://scripts/pip_playground.gd")
const SUMMER_BALL_TINT := Color("#ffd16b")
const ACTIONS := {
	"water": ["Water the flower", "Grow the flower", "Bloom the flower"],
	"roll": ["Roll the ball", "Return the ball", "Catch the ball"],
	"offer": ["Offer the apple", "Nibble the apple", "Finish the apple"],
	"ring": ["Ring the bell", "Answer the bell", "Chime the bell"],
	"open": ["Lift the shell", "Listen to the shell", "Hear the waves"],
	"launch": ["Ready the rocket", "Ignite the rocket", "Launch the rocket"]
}
const OUTCOMES := {
	"water": ["A drink for the flower!", "The flower grows taller!", "The flower blooms for Pip!"],
	"roll": ["The ball rolls to Pip!", "Pip rolls the ball back!", "Pip catches the ball. Hooray!"],
	"offer": ["An apple for Pip!", "Pip nibbles the apple. Crunch!", "Pip finishes the apple. Just the core!"],
	"ring": ["The bell rings. Ding!", "Pip answers the bell. Ding, ding!", "The bell and Pip make a happy chime!"],
	"open": ["Pip lifts the shell!", "Pip listens to the shell. Shh!", "The shell sounds like ocean waves. Whoosh!"],
	"launch": ["The rocket is ready on its launch pad!", "The rocket glows. Ready to go!", "The rocket takes off. Whoosh!"]
}

class RoomScene extends Control:
	var theme_id: String = "home"
	var palette: Dictionary = {}
	var action: String = ""
	var action_progress: float = 0.0
	var stage: int = 0
	var toy_center: Vector2

	func _draw() -> void:
		var accent: Color = palette.get("accent", Color("#438363"))
		var background: Color = palette.get("background", Color("#edf8ec"))
		draw_style_box(preload("res://scripts/ui_style.gd").box(background, accent.lightened(0.6), 24, 2), Rect2(Vector2.ZERO, size))
		var floor_y := size.y * 0.57
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
			if stage == 1:
				for index in range(3):
					draw_line(point + Vector2(-22 + index * 19, -61), point + Vector2(-25 + index * 19, -50), Color("#58a9c9"), 4, true)
			elif stage == 2:
				for side in [-1, 1]:
					draw_line(point + Vector2(side * 43, 28), point + Vector2(side * 43, -21), accent, 3, true)
					draw_line(point + Vector2(side * 43, -21), point + Vector2(side * 43 - 7, -10), accent, 3, true)
					draw_line(point + Vector2(side * 43, -21), point + Vector2(side * 43 + 7, -10), accent, 3, true)
			else:
				for index in range(8):
					var ray := Vector2.from_angle(index * TAU / 8)
					draw_line(point + ray * 49, point + ray * 57, Color("#e8af39"), 4, true)
		elif action == "ring":
			for side in [-1, 1]:
				for index in range(stage):
					draw_arc(point + Vector2(side * 14, 0), 25 + index * 7, -0.8 if side == 1 else PI - 0.8, 0.8 if side == 1 else PI + 0.8, 12, accent, 2, true)
			if stage >= 2:
				for index in range(stage - 1):
					var note := Vector2(70 + index * 42, 48 + index * 14)
					draw_circle(note, 5, accent)
					draw_line(note + Vector2(4, 0), note + Vector2(4, -16), accent, 3, true)
		elif action == "open":
			for row in range(stage):
				var wave := PackedVector2Array()
				for index in range(22 if stage == 3 else 12):
					wave.append(point + Vector2(-69 + index * (6 if stage == 3 else 3), 32 + row * 8 + sin(index * 0.8) * 3))
				draw_polyline(wave, Color("#58a9c9"), 2, true)
		elif action == "launch":
			draw_line(Vector2(size.x - 120, floor_y), Vector2(size.x - 12, floor_y), accent, 6, true)
			if stage >= 2:
				for index in range(3):
					var start := point + Vector2((index - 1) * 12, 37)
					draw_line(start, start + Vector2(0, (9 + index % 2 * 10) * (stage - 1)), Color("#efb14f"), 5, true)
		elif action == "offer":
			if stage >= 2:
				for index in range(stage + 1):
					draw_circle(point + Vector2(-16 + index * 11, 35 + index % 2 * 7), 3, Color("#d49854"))
			if stage == 3 and action_progress >= 0.8:
				var core := PackedVector2Array([point + Vector2(-19, -26), point + Vector2(19, -26), point + Vector2(7, 0), point + Vector2(19, 25), point + Vector2(-19, 25), point + Vector2(-7, 0)])
				draw_colored_polygon(core, Color("#fff1c5"))
				draw_polyline(PackedVector2Array([core[1], core[2], core[3]]), Color("#ba8854"), 2, true)
				draw_polyline(PackedVector2Array([core[4], core[5], core[0]]), Color("#ba8854"), 2, true)
				draw_line(point + Vector2(-19, -26), point + Vector2(19, -26), Color("#d45f4e"), 5, true)
				draw_line(point + Vector2(-19, 25), point + Vector2(19, 25), Color("#d45f4e"), 5, true)
				draw_line(point + Vector2(0, -27), point + Vector2(3, -36), Color("#83572f"), 4, true)
				draw_circle(point, 3, Color("#83572f"))
		elif action == "roll":
			if stage == 3:
				draw_arc(point, 48, 0.1, PI - 0.1, 24, accent, 4, true)
			else:
				for index in range(3):
					var side := 1 if stage == 1 else -1
					draw_line(point + Vector2(side * (36 + index * 5), -7 + index * 7), point + Vector2(side * (44 + index * 5), -7 + index * 7), accent.lightened(0.3), 3, true)

class ToyMarks extends Control:
	var nibbled: bool = false
	var background: Color

	func _draw() -> void:
		if nibbled:
			for offset in [Vector2(26, -10), Vector2(29, 3), Vector2(25, 13)]:
				draw_circle(size * 0.5 + offset, 10, background)

var duck_slot: Control
var caption: Label
var favorite_medal: Medal
var toy_button: Button
var action_button: Button
var goal_button: Button
var item_buttons: Dictionary = {}
var category_buttons: Dictionary = {}
var goal_label: Label
var interaction_allowed: Callable
var word_sticker_button: Button
var playground: Playground
var pip_buttons: Array[Button] = []

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
var _action: String = ""
var _action_progress: float = 0.0
var _stage: int = 0
var _toy_art: Texture2D
var _toy_marks: ToyMarks
var _goal_id: String = ""
var _preview_locked: bool = false
var _word_sticker: Dictionary = {}
var _sticker_audio_available: bool = true


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
	goal_button = Button.new()
	goal_button.name = "RoomGiftGoal"
	Style.button(goal_button, Style.GOOD)
	goal_button.pressed.connect(_request_goal)
	add_child(goal_button)
	_room = RoomScene.new()
	_room.custom_minimum_size = Vector2(0, 304)
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
	toy_button.custom_minimum_size = Vector2(64, 64)
	for style_name in ["normal", "disabled"]:
		toy_button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	toy_button.expand_icon = true
	toy_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toy_button.add_theme_constant_override("icon_max_width", 84)
	toy_button.pressed.connect(_play_toy)
	_room.add_child(toy_button)
	_toy_marks = ToyMarks.new()
	_toy_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toy_button.add_child(_toy_marks)
	_toy_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toy_label = Style.label("ball", 21)
	_toy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room.add_child(_toy_label)
	playground = Playground.new()
	playground.name = "PipPlayground"
	_room.add_child(playground)
	playground.setup(duck_slot, toy_button, _toy_label)
	playground.interaction_allowed = _can_interact
	playground.interaction_started.connect(_direct_play_started)
	playground.interaction.connect(_direct_play_feedback)
	playground.toy_tapped.connect(_play_toy)
	var gesture_hint := Style.label("Stroke Pip · Drag a toy · Tap the floor", 15)
	gesture_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(gesture_hint)
	var pip_actions := HBoxContainer.new()
	pip_actions.add_theme_constant_override("separation", 6)
	add_child(pip_actions)
	for entry in [["Pet", playground.pet], ["Poke", playground.poke], ["Toss", playground.toss_to_pip], ["Call", playground.call_pip]]:
		var button := Button.new()
		button.name = "Pip" + entry[0]
		button.text = entry[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Style.button(button, Style.GOOD)
		button.custom_minimum_size = Vector2(52, 48)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(entry[1])
		_name_control(button, entry[0] + (" the toy to Pip" if entry[0] == "Toss" else " Pip"))
		pip_actions.add_child(button)
		pip_buttons.append(button)
	word_sticker_button = Button.new()
	word_sticker_button.name = "RoomWordSticker"
	Style.button(word_sticker_button, Style.GOOD)
	word_sticker_button.custom_minimum_size = Vector2(44, 88)
	word_sticker_button.expand_icon = true
	word_sticker_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	word_sticker_button.add_theme_constant_override("icon_max_width", 68)
	word_sticker_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	word_sticker_button.pressed.connect(_hear_word_sticker)
	word_sticker_button.hide()
	add_child(word_sticker_button)
	caption = Style.label("Choose a toy, then play with Pip!", 18)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.y = 50
	add_child(caption)
	action_button = Button.new()
	action_button.name = "RoomToyAction"
	Style.button(action_button, Style.GOOD)
	action_button.pressed.connect(_activate_action)
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
		_reset_sequence()
	if item_buttons.is_empty():
		_build_items()
	_refresh_items()
	_refresh_room()
	if reduced_motion and not _action.is_empty():
		settle()


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


func set_word_sticker(word: Dictionary, audio_available: bool = true) -> void:
	_build()
	_word_sticker = word if word.has_all(["id", "text", "image", "audio"]) else {}
	_sticker_audio_available = audio_available
	word_sticker_button.visible = not _word_sticker.is_empty()
	word_sticker_button.disabled = _word_sticker.is_empty() or not audio_available
	word_sticker_button.focus_mode = Control.FOCUS_NONE if word_sticker_button.disabled else Control.FOCUS_ALL
	word_sticker_button.text = str(_word_sticker.get("text", ""))
	word_sticker_button.icon = null if _word_sticker.is_empty() else load("res://" + str(_word_sticker.image))
	word_sticker_button.tooltip_text = ("Hear " if audio_available else "No sound. ") + word_sticker_button.text
	_name_control(word_sticker_button, word_sticker_button.tooltip_text)


func _hear_word_sticker() -> void:
	if _can_interact() and _sticker_audio_available and not _word_sticker.is_empty():
		word_requested.emit(_word_sticker.id)


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
		_reset_sequence()
	_room.theme_id = backdrop.theme if backdrop.id != "backdrop-home" else "home"
	_room.palette = Data.theme(backdrop.theme) if Data.THEMES.has(backdrop.theme) else _palette
	_room_title.text = ("Preview: " if _preview_locked and preview.slot == "backdrop" else "") + str(backdrop.name)
	_toy_art = _art(_toy)
	toy_button.icon = _toy_art
	toy_button.self_modulate = SUMMER_BALL_TINT if _toy.id == "toy-summer" else Color.WHITE
	_toy_label.text = _toy.word_id
	action_button.disabled = false
	toy_button.disabled = _preview_locked
	toy_button.focus_mode = Control.FOCUS_NONE if _preview_locked else Control.FOCUS_ALL
	playground.configure(_toy.word_id, _preview_locked, _reduced_motion, _room.palette.get("accent", Style.GOOD))
	pip_buttons[2].disabled = _preview_locked
	pip_buttons[2].focus_mode = Control.FOCUS_NONE if _preview_locked else Control.FOCUS_ALL
	_refresh_action_control()
	if _preview_locked:
		caption.text = preview.name + ". " + _requirement(preview)
	elif _action.is_empty() and playground.interaction_kind.is_empty():
		caption.text = "%s %s for Pip. %s!" % ["An" if _toy.word_id == "apple" else "A", _toy.word_id, ACTIONS[_toy.action][0]]
	_refresh_goal()
	_layout_room()


func _refresh_goal() -> void:
	var gift: Dictionary = _item(_preview_id) if _preview_locked else _state.selected_goal(_counts)
	_goal_id = str(gift.get("id", ""))
	goal_button.visible = not gift.is_empty()
	goal_button.disabled = gift.is_empty()
	goal_button.focus_mode = Control.FOCUS_NONE if gift.is_empty() else Control.FOCUS_ALL
	if gift.is_empty():
		gift = _state.next_gift(_counts, _palette.get("id", ""))
		goal_label.text = "Every gift in this world is yours. Mix and play!" if gift.is_empty() else "Next gift: %s · %d more %s" % [gift.name, gift.remaining_pieces, "piece" if gift.remaining_pieces == 1 else "pieces"]
		return
	var remaining: int = gift.remaining_pieces if gift.has("remaining_pieces") else _remaining(gift)
	goal_label.text = "%s · %s · %s" % [gift.name, Data.theme(gift.theme).name, "Ready to play!" if remaining == 0 else "%d more %s" % [remaining, "piece" if remaining == 1 else "pieces"]]
	goal_button.text = "Help Pip get this" if _preview_locked else "Play with this gift" if remaining == 0 else "Continue adventure"
	goal_button.tooltip_text = goal_button.text + ". " + goal_label.text
	_name_control(goal_button, goal_button.tooltip_text)


func _request_goal() -> void:
	if _can_interact() and goal_button.visible and not _goal_id.is_empty():
		goal_requested.emit(_goal_id)


func _reset_sequence() -> void:
	if playground != null: playground.cancel()
	_action = ""
	_stage = 0
	_action_progress = 0.0
	set_process(false)


func _refresh_action_control() -> void:
	action_button.text = "Back to my room" if _preview_locked else "Play again" if _stage == 3 else ACTIONS[_toy.action][_stage]
	toy_button.tooltip_text = "Play with the " + str(_toy.word_id) + " again" if _stage == 3 else str(ACTIONS[_toy.action][_stage])
	toy_button.tooltip_text = "Drag to toss the %s. Tap: %s" % [_toy.word_id, toy_button.tooltip_text]
	_name_control(toy_button, toy_button.tooltip_text)
	_name_control(action_button, action_button.text)


func _show_category(id: String) -> void:
	if not _can_interact():
		return
	_category = id
	_preview_id = ""
	_reset_sequence()
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
		_reset_sequence()
		_refresh_room()
		item_previewed.emit(caption.text)


func _activate_action() -> void:
	if not _can_interact():
		return
	if _preview_locked:
		_preview_id = ""
		_reset_sequence()
		_refresh_room()
		item_previewed.emit(caption.text)
	else:
		_play_toy()


func _play_toy() -> void:
	if _preview_locked or _toy.is_empty() or not _can_interact():
		return
	playground.cancel()
	if _stage == 3:
		_reset_sequence()
		_refresh_room()
		return
	_action = _toy.action
	_stage += 1
	_action_progress = 1.0 if _reduced_motion else 0.0
	caption.text = "%d/3 · %s" % [_stage, OUTCOMES[_action][_stage - 1]]
	_refresh_action_control()
	_apply_action()
	set_process(not _reduced_motion)
	word_requested.emit(_toy.word_id)
	toy_played.emit(_action)


func _layout_room() -> void:
	if _room == null or toy_button == null:
		return
	var width := maxf(240, _room.size.x)
	if playground == null: return
	playground.layout_room(Vector2(width, _room.size.y))
	favorite_medal.position = Vector2(16, 46)
	favorite_medal.size = Vector2(48, 48)
	_room_title.position = Vector2(14, 9)
	_room_title.size = Vector2(width - 28, 28)
	_apply_action()


func _apply_action() -> void:
	if playground != null and playground.toy_phase != "idle": return
	toy_button.position = playground._toy_home - toy_button.size * 0.5
	toy_button.scale = Vector2.ONE
	toy_button.rotation = 0
	toy_button.icon = _toy_art
	_toy_marks.nibbled = _action == "offer" and _stage == 2
	_toy_marks.background = _room.palette.get("background", Color("#edf8ec"))
	_toy_marks.queue_redraw()
	var progress := smoothstep(0.0, 1.0, _action_progress)
	var previous := maxi(0, _stage - 1)
	var offsets: Array[Vector2] = [Vector2.ZERO]
	var rotations: Array[float] = [0.0, 0.0, 0.0, 0.0]
	if _action == "water":
		offsets.append_array([Vector2(0, 8), Vector2(0, -4), Vector2(0, -10)])
		var scales := [1.0, 0.9, 1.05, 1.15]
		toy_button.scale = Vector2.ONE * lerpf(scales[previous], scales[_stage], progress)
	elif _action == "roll":
		var travel := minf(58, _room.size.x * 0.2)
		offsets.append_array([Vector2(-travel, 0), Vector2(0, -14), Vector2(-travel * 0.7, -28)])
		rotations = [0.0, -TAU, 0.0, -PI * 0.25]
	elif _action == "offer":
		offsets.append_array([Vector2(-42, -8), Vector2(-50, -18), Vector2(-44, 0)])
		rotations = [0.0, -0.1, 0.15, 0.0]
		if _stage == 3 and progress >= 0.8:
			toy_button.icon = null
	elif _action == "ring":
		offsets.append_array([Vector2.ZERO, Vector2(-8, -4), Vector2(0, -13)])
		rotations = [0.0, -0.2, 0.2, 0.0]
	elif _action == "open":
		offsets.append_array([Vector2(-6, -20), Vector2(-44, -26), Vector2(-38, -10)])
		rotations = [0.0, -0.12, -0.28, 0.1]
	elif _action == "launch":
		offsets.append_array([Vector2(0, 4), Vector2(0, -6), Vector2(-16, -54)])
	if offsets.size() == 4:
		var offset := offsets[previous].lerp(offsets[_stage], progress)
		if playground._toy_home.x < _room.size.x * 0.5: offset.x *= -1
		toy_button.position += offset
		toy_button.rotation = lerpf(rotations[previous], rotations[_stage], progress)
		if _action == "ring" and not _reduced_motion:
			toy_button.rotation += sin(progress * TAU * 3) * 0.16 * sin(progress * PI)
	playground._place_toy(toy_button.position + toy_button.size * 0.5)
	_room.action = _action
	_room.action_progress = progress
	_room.stage = _stage
	_room.toy_center = toy_button.position + toy_button.size * 0.5
	_room.queue_redraw()


func _process(delta: float) -> void:
	_action_progress = minf(1.0, _action_progress + delta / 0.85)
	_apply_action()
	if _action_progress >= 1.0:
		set_process(false)


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		settle()


func settle() -> void:
	set_process(false)
	if playground != null: playground.cancel()
	if not _action.is_empty():
		_action_progress = 1.0
		_apply_action()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		settle()


func controls() -> Array[Control]:
	var result: Array[Control] = []
	# The host wires focus and scrolling once, including currently hidden choices.
	for button in [toy_button, action_button, goal_button, word_sticker_button] + pip_buttons + category_buttons.values() + item_buttons.values():
		if button != null:
			result.append(button)
	return result


func _direct_play_started() -> void:
	_action = ""
	_stage = 0
	_action_progress = 0
	set_process(false)
	_apply_action()
	_refresh_action_control()


func _direct_play_feedback(kind: String, message: String) -> void:
	caption.text = message
	if kind == "throw": word_requested.emit(_toy.word_id)
	pip_interaction.emit(kind, message)


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if playground != null:
		playground.configure(playground.toy_word, playground.toy_locked, value, playground.accent)
	if value: settle()
