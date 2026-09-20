extends VBoxContainer

signal item_selected(id: String)
signal item_previewed(message: String)
signal word_requested(word_id: String)
signal toy_played(kind: String)
signal goal_requested(id: String)
signal pip_interaction(kind: String, message: String)
signal background_input(event: InputEvent, source: Control)

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Medal = preload("res://scripts/medal_view.gd")
const Icons = preload("res://scripts/icon_button.gd")
const Playground = preload("res://scripts/pip_playground.gd")
const ToyCard = preload("res://scripts/toy_card.gd")
const SUMMER_BALL_TINT := Color("#ffd16b")
const STAGE_HEIGHT := 304.0
const ACTIONS := {
	"water": ["Water the flower", "Grow the flower", "Bloom the flower"],
	"roll": ["Roll the ball", "Return the ball", "Catch the ball"],
	"offer": ["Offer the apple", "Nibble the apple", "Finish the apple"],
	"ring": ["Ring the bell", "Answer the bell", "Chime the bell"],
	"open": ["Lift the shell", "Listen to the shell", "Hear the waves"],
	"launch": ["Ready the rocket", "Ignite the rocket", "Launch the rocket"],
	"swing": ["Swing the monkey", "Wave to the monkey", "High-five the monkey"],
	"decorate": ["Set the cake", "Frost the cake", "Sprinkle the cake"]
}
const OUTCOMES := {
	"water": ["A drink for the flower!", "The flower grows taller!", "The flower blooms for Pip!"],
	"roll": ["The ball rolls to Pip!", "Pip rolls the ball back!", "Pip catches the ball. Hooray!"],
	"offer": ["An apple for Pip!", "Pip nibbles the apple. Crunch!", "Pip finishes the apple. Just the core!"],
	"ring": ["The bell rings. Ding!", "Pip answers the bell. Ding, ding!", "The bell and Pip make a happy chime!"],
	"open": ["Pip lifts the shell!", "Pip listens to the shell. Shh!", "The shell sounds like ocean waves. Whoosh!"],
	"launch": ["The rocket is ready on its launch pad!", "The rocket glows. Ready to go!", "The rocket takes off. Whoosh!"],
	"swing": ["The monkey swings through the jungle!", "The monkey waves to Pip!", "Pip and the monkey share a high five!"],
	"decorate": ["A cake for Pip's party!", "A swirl of frosting on the cake!", "Sprinkles on the cake. Ready to celebrate!"]
}

class RoomScene extends Control:
	var theme_id: String = "home"
	var palette: Dictionary = {}
	var action: String = ""
	var action_progress: float = 0.0
	var stage: int = 0
	var toy_center: Vector2
	var stage_height: float = 304.0

	func _draw() -> void:
		var accent: Color = palette.get("accent", Color("#438363"))
		var background: Color = palette.get("background", Color("#edf8ec"))
		draw_style_box(preload("res://scripts/ui_style.gd").box(background, accent.lightened(0.6), 24, 2), Rect2(Vector2.ZERO, size))
		var floor_y := minf(stage_height * 0.57, STAGE_HEIGHT * 0.57)
		var wall := Style.box(palette.get("light", background).lightened(0.4), Color.TRANSPARENT, 22, 0)
		wall.corner_radius_bottom_left = 0
		wall.corner_radius_bottom_right = 0
		draw_style_box(wall, Rect2(Vector2(2, 2), Vector2(maxf(0, size.x - 4), maxf(0, floor_y - 2))))
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
		elif theme_id == "jungle":
			for index in range(5):
				var point := Vector2(25 + index * maxf(30, (size.x - 50) / 4), 39 + index % 2 * 12)
				var vine := PackedVector2Array([point, point + Vector2(-4, 28), point + Vector2(3, 56 + index % 3 * 12)])
				draw_polyline(vine, Color("#87b16b"), 3, true)
				for side in [-1, 1]:
					var leaf := PackedVector2Array([point + Vector2(0, 20), point + Vector2(side * 9, 6), point + Vector2(side * 23, 4), point + Vector2(side * 20, 21), point + Vector2(side * 9, 27)])
					draw_colored_polygon(leaf, Color("#9fc77b") if index % 2 == 0 else Color("#b9d893"))
					draw_line(point + Vector2(0, 20), point + Vector2(side * 19, 9), Color("#679951"), 1.5, true)
		elif theme_id == "candy":
			for index in range(3):
				var point := Vector2(size.x * (0.16 + index * 0.34), 62 + index % 2 * 22)
				draw_line(point, point + Vector2(0, 61), Color("#dab4c7"), 5, true)
				draw_circle(point, 20, Color("#f1accd") if index != 1 else Color("#a6dbc9"))
				draw_arc(point, 14, -PI * 0.5, PI, 22, Color("#fff5fa"), 4, true)
				draw_arc(point, 7, PI * 0.5, TAU, 16, Color("#fff5fa"), 4, true)
			for index in range(8):
				var point := Vector2(20 + fmod(index * 61.0, maxf(20, size.x - 40)), 43 + index % 3 * 35)
				draw_line(point, point + Vector2(5, -3), Color("#e6bf77"), 3, true)
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
		elif action == "swing":
			if stage == 1:
				draw_line(point - Vector2(0, 26), Vector2(point.x - 15, 37), Color("#77a65a"), 3, true)
			elif stage == 2:
				for index in range(2):
					draw_arc(point + Vector2(21, -20), 12 + index * 7, -1.0, 0.3, 12, Color("#dfa842"), 2, true)
			else:
				for index in range(5):
					var ray := Vector2.from_angle(-PI * 0.8 + index * PI * 0.4)
					draw_line(point + ray * 39, point + ray * 46, Color("#dfa842"), 3, true)
		elif action == "decorate":
			draw_arc(point + Vector2(0, 25), 32, 0, PI, 24, Color("#a1cfc6"), 4, true)
			if stage == 3:
				for index in range(6):
					var ray := Vector2.from_angle(-PI + index * PI / 5)
					draw_line(point + ray * 37, point + ray * 43, Color("#de88b2") if index % 2 == 0 else Color("#6db9a4"), 3, true)

class ToyMarks extends Control:
	var nibbled: bool = false
	var cake_stage: int = 0
	var background: Color

	func _draw() -> void:
		if nibbled:
			for offset in [Vector2(26, -10), Vector2(29, 3), Vector2(25, 13)]:
				draw_circle(size * 0.5 + offset, 10, background)
		if cake_stage >= 2:
			var frosting := PackedVector2Array()
			for index in range(17):
				frosting.append(size * 0.5 + Vector2(-18 + index * 2.25, -4 + sin(index * PI / 4) * 2))
			draw_polyline(frosting, Color("#fff5e9"), 5, true)
		if cake_stage == 3:
			for index in range(5):
				var point := size * 0.5 + Vector2(-14 + index * 7, -6 + index % 2 * 3)
				draw_line(point, point + Vector2(2, 2), Color("#de88b2") if index % 2 == 0 else Color("#6db9a4"), 2, true)

var duck_slot: Control
var feedback_text: String = "Choose a toy, then play with Pip!"
var favorite_medal: Medal
var toy_button: Button
var goal_button: Icons
var item_buttons: Dictionary = {}
var owned_toys: Control
var toy_homes: Dictionary = {}
var goal_label: Label
var interaction_allowed: Callable
var playground: Playground

var _state: RefCounted
var _counts: Dictionary = {}
var _palette: Dictionary = {}
var _reduced_motion: bool = false
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
var _positioned_toy_id: String = ""
var _positioned_width: float = 0.0


func _ready() -> void:
	_build()


func _build() -> void:
	if _room != null:
		return
	name = "PipsRoom"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	goal_label = Style.label("", 17)
	goal_label.clip_text = true
	goal_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.hide()
	goal_button = Icons.new()
	goal_button.symbol = Icons.Symbol.NEXT
	goal_button.name = "RoomGiftGoal"
	Style.square_icon_button(goal_button, Style.GOOD)
	goal_button.pressed.connect(_request_goal)
	goal_button.hide()
	_room = RoomScene.new()
	_room.custom_minimum_size = Vector2(0, 304)
	_room.clip_contents = true
	_room.resized.connect(_layout_room)
	_room.gui_input.connect(func(event: InputEvent) -> void: background_input.emit(event, _room))
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
	playground.activate_toy = _activate_playground_toy
	owned_toys = Control.new()
	owned_toys.name = "OwnedToys"
	owned_toys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.add_child(owned_toys)
	add_child(goal_label)
	add_child(goal_button)
	_item_grid = GridContainer.new()
	_item_grid.name = "LockedToys"
	_item_grid.columns = 2
	_item_grid.add_theme_constant_override("h_separation", 8)
	_item_grid.add_theme_constant_override("v_separation", 8)
	add_child(_item_grid)
	resized.connect(_fit_controls)
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
	if changed or (not _preview_id.is_empty() and _state.owned(_item(_preview_id), _counts)):
		_preview_id = ""
		_reset_sequence()
	if item_buttons.is_empty():
		_build_items()
	Style.square_icon_button(goal_button, palette.accent)
	_refresh_items()
	_refresh_room()
	_fit_controls()
	if reduced_motion and not _action.is_empty():
		settle()


func _fit_controls() -> void:
	if _room == null:
		return
	var scale: float = Style.ui_scale(self)
	var gap: int = ceili(8 / scale)
	add_theme_constant_override("separation", gap)
	_item_grid.columns = 3 if size.x * scale >= 720 else 2
	_item_grid.add_theme_constant_override("h_separation", gap)
	_item_grid.add_theme_constant_override("v_separation", gap)
	goal_button.custom_minimum_size = Vector2(44, 44) / scale
	goal_button.add_theme_font_size_override("font_size", ceili(14 / scale))
	goal_label.add_theme_font_size_override("font_size", ceili(12 / scale))
	# The default logical line gap grows with canvas scaling and overflows three-line cards.
	goal_label.add_theme_constant_override("line_spacing", 0)
	for button in item_buttons.values():
		button._layout()
	_layout_owned_toys()


func _layout_owned_toys() -> void:
	if owned_toys == null: return
	var width: float = maxf(240, size.x)
	var count: int = owned_toys.get_child_count()
	var first_columns: int = maxi(1, floori((width - 180) / 104))
	var columns: int = maxi(2, floori((width - 24) / 104))
	var height: float = STAGE_HEIGHT
	toy_homes.clear()
	var targets: Dictionary = {}
	for index in range(count):
		var card: Button = owned_toys.get_child(index)
		var id: String = card.get_meta("toy_id")
		var center := Vector2(width - 66, 230)
		if count > 1:
			if index < first_columns:
				center = Vector2(180 + (width - 180 - first_columns * 104) * 0.5 + 52 + index * 104, 230 + 12 * (index % 2))
			else:
				var floor_index: int = index - first_columns
				var column: int = floor_index % columns
				var row: int = floori(float(floor_index) / columns)
				center = Vector2((width - columns * 104) * 0.5 + 52 + column * 104, 342 + row * 112 + 12 * ((column + row + 1) % 2))
			height = maxf(height, center.y + 80)
		toy_homes[id] = center
		card.position = center - Vector2(32, 32)
		card.size = Vector2(64, 64)
		targets[id] = card
	owned_toys.size = Vector2(width, height)
	_room.custom_minimum_size.y = height
	_room.stage_height = height
	playground.toy_targets = targets
	playground.active_toy_id = "" if _preview_locked else str(_toy.get("id", "toy-ball"))
	playground.layout_room(Vector2(width, height))
	var home: Vector2 = Vector2(width - 66, 110) if _preview_locked else toy_homes.get(_toy.get("id", "toy-ball"), Vector2(width - 66, 230))
	# A single toy keeps its original move-away-from-Pip behavior.
	if count > 1 or _preview_locked or _positioned_toy_id != str(_toy.get("id", "")) or not is_equal_approx(_positioned_width, width):
		playground.set_toy_home(home, count > 1 or _preview_locked)
	else:
		playground.set_toy_home(playground._toy_home, false)
	_positioned_toy_id = str(_toy.get("id", ""))
	_positioned_width = width
	_room.queue_redraw()


func _build_items() -> void:
	for item in _state.toys():
		var button := ToyCard.new()
		button.setup(item, _art(item))
		button.set_meta("toy_id", item.id)
		button.picture.self_modulate = SUMMER_BALL_TINT if item.id == "toy-summer" else Color.WHITE
		button.pressed.connect(_choose_item.bind(item.id))
		_item_grid.add_child(button)
		item_buttons[item.id] = button
		_item_labels[item.id] = button.detail_label


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
	var owned_index := 0
	var locked_index := 0
	var equipped_id: String = _equipped_toy().id
	for item in _state.toys():
		var button: Button = item_buttons[item.id]
		var earned: bool = _state.owned(item, _counts)
		var destination: Control = owned_toys if earned else _item_grid
		if button.get_parent() != destination:
			button.reparent(destination, false)
		destination.move_child(button, owned_index if earned else locked_index)
		if earned: owned_index += 1
		else: locked_index += 1
		button.in_room = earned
		var selected: bool = item.id == equipped_id
		var previewing: bool = not _preview_id.is_empty() and not _state.owned(_item(_preview_id), _counts)
		button.visible = not (earned and selected and not previewing)
		button.focus_mode = Control.FOCUS_ALL if button.visible else Control.FOCUS_NONE
		var previewed: bool = item.id == _preview_id and not earned
		var detail: String = "Tap to play. Drag to toss." if earned else "%d/3 pieces" % _counts.get(item.medal_id, 0)
		button.tooltip_text = ("Preview only. " if previewed else "") + item.name + ". " + (detail if earned else _requirement(item))
		_name_control(button, button.tooltip_text)
		button.present(Data.theme(item.theme) if not item.theme.is_empty() else _palette, selected and earned, detail)
	_item_grid.visible = locked_index > 0


func _equipped_toy() -> Dictionary:
	var item: Dictionary = _item(_state.toy_id)
	return _item("toy-ball") if item.is_empty() or not _state.owned(item, _counts) else item


func _refresh_room() -> void:
	var previous_toy: String = _toy.get("id", "")
	_toy = _equipped_toy()
	var backdrop: Dictionary = _item(_state.backdrop_id)
	if backdrop.is_empty() or not _state.owned(backdrop, _counts):
		backdrop = _item("backdrop-home")
	var preview := _item(_preview_id)
	_preview_locked = not preview.is_empty() and preview.slot == "toy" and not _state.owned(preview, _counts)
	if not preview.is_empty() and preview.slot == "toy":
		_toy = preview
	if _toy.id != previous_toy:
		_reset_sequence()
	_room.theme_id = backdrop.theme if backdrop.id != "backdrop-home" else "home"
	_room.palette = Data.theme(backdrop.theme) if Data.THEMES.has(backdrop.theme) else _palette
	_room_title.text = str(backdrop.name)
	_toy_art = _art(_toy)
	toy_button.icon = _toy_art
	toy_button.add_theme_constant_override("icon_max_width", 84)
	toy_button.self_modulate = SUMMER_BALL_TINT if _toy.id == "toy-summer" else Color.WHITE
	_toy_label.text = _toy.word_id
	toy_button.disabled = _preview_locked
	toy_button.focus_mode = Control.FOCUS_NONE if _preview_locked else Control.FOCUS_ALL
	_toy_label.add_theme_font_size_override("font_size", 21)
	_toy_label.add_theme_color_override("font_color", Style.INK)
	playground.configure(_toy.word_id, _preview_locked, _reduced_motion, _room.palette.get("accent", Style.GOOD))
	_refresh_toy_control()
	if _preview_locked:
		feedback_text = "Preview: %s." % _toy.word_id
	elif _action.is_empty() and playground.interaction_kind.is_empty():
		feedback_text = "%s %s for Pip. %s!" % ["An" if _toy.word_id == "apple" else "A", _toy.word_id, ACTIONS[_toy.action][0]]
	_refresh_goal()
	_layout_room()


func _refresh_goal() -> void:
	Style.square_icon_button(goal_button, _palette.get("accent", Style.GOOD))
	for card in item_buttons.values():
		card.clear_goal()
	var gift: Dictionary = _item(_preview_id) if _preview_locked else _state.selected_goal(_counts)
	if gift.get("slot", "") != "toy" or _state.owned(gift, _counts):
		gift = {}
	_goal_id = str(gift.get("id", ""))
	goal_button.visible = not gift.is_empty()
	goal_label.visible = not gift.is_empty()
	goal_button.disabled = gift.is_empty()
	goal_button.focus_mode = Control.FOCUS_NONE if gift.is_empty() else Control.FOCUS_ALL
	if gift.is_empty():
		goal_label.text = ""
		_fit_controls()
		return
	var remaining: int = gift.remaining_pieces if gift.has("remaining_pieces") else _remaining(gift)
	var action: String = "Use toy" if remaining == 0 else "Continue adventure" if _state.goal_item_id == gift.id else "Start adventure"
	var progress: String = "Ready to play!" if remaining == 0 else "%d/3 · %d more %s" % [_counts.get(gift.medal_id, 0), remaining, "piece" if remaining == 1 else "pieces"]
	var using: bool = remaining == 0 and _state.toy_id == gift.id
	var context: String = "Preview" if _preview_locked else "Goal"
	var short_action: String = "Use toy" if remaining == 0 else "Continue" if _state.goal_item_id == gift.id else "Start"
	goal_label.text = "%s\n%s" % [gift.name, progress] if using else "%s\n%s\n%s · %s" % [gift.name, progress, context, short_action]
	goal_button.tooltip_text = "%s. %s. %s" % [action, gift.name, _requirement(gift)]
	_name_control(goal_button, goal_button.tooltip_text)
	var card: Button = item_buttons[gift.id]
	card.show_goal(goal_label, goal_button)
	_fit_controls()


func show_item_error(id: String, summary: String, details: String) -> void:
	if not item_buttons.has(id):
		return
	var card: Button = item_buttons[id]
	var label: Label = goal_label if goal_label.visible and goal_label.get_parent() == card else _item_labels[id]
	label.text = _item(id).name + "\n" + summary if label == goal_label else summary
	card.show_error(summary)
	if card.in_room and id == _toy.get("id", "") and not _preview_locked:
		_toy_label.text = "Not saved\nTap to retry"
		_toy_label.add_theme_font_size_override("font_size", 14)
		_toy_label.add_theme_constant_override("line_spacing", 0)
		_toy_label.add_theme_color_override("font_color", Style.WRONG.darkened(0.15))
		_toy_label.position = toy_button.position + Vector2(-16, 65)
		_toy_label.size = Vector2(96, 40)
		toy_button.add_theme_constant_override("icon_max_width", 40)
		toy_button.tooltip_text = details
		_name_control(toy_button, _item(id).name + ". " + details)
	card.tooltip_text = details
	if not card.in_room:
		card.add_theme_stylebox_override("normal", Style.box(Style.WRONG.lightened(0.94), Style.WRONG, 16, 2))
	_name_control(card, _item(id).name + ". " + details)
	if goal_button.visible and goal_button.get_parent() == card:
		goal_button.tooltip_text = details
		goal_button.add_theme_stylebox_override("normal", Style.box(Style.WRONG.lightened(0.9), Style.WRONG, ceili(4 / Style.ui_scale(self)), 1))
		_name_control(goal_button, _item(id).name + ". " + details)


func _request_goal() -> void:
	if _can_interact() and goal_button.visible and not _goal_id.is_empty():
		goal_requested.emit(_goal_id)


func _reset_sequence() -> void:
	if playground != null: playground.cancel()
	_action = ""
	_stage = 0
	_action_progress = 0.0
	set_process(false)


func _refresh_toy_control() -> void:
	toy_button.tooltip_text = "Play with the " + str(_toy.word_id) + " again" if _stage == 3 else str(ACTIONS[_toy.action][_stage])
	toy_button.tooltip_text = "Drag to toss the %s. Tap: %s" % [_toy.word_id, toy_button.tooltip_text]
	_name_control(toy_button, toy_button.tooltip_text)


func _choose_item(id: String, play_after: bool = true) -> void:
	if not _can_interact() or not item_buttons.has(id):
		return
	var item := _item(id)
	if item.is_empty():
		return
	if _state.owned(item, _counts):
		var had_focus: bool = item_buttons[id].has_focus()
		_preview_id = ""
		item_selected.emit(id)
		if _state.toy_id == id and not _preview_locked and not item_buttons[id]._showing_error:
			if had_focus: toy_button.grab_focus()
			if play_after: _play_toy()
	else:
		_preview_id = id
		_reset_sequence()
		_refresh_items()
		_refresh_room()
		item_previewed.emit("Preview only. " + item.name + ". " + _requirement(item))
	if not item_buttons[id].in_room: item_buttons[id].play_press(_reduced_motion)


func _activate_playground_toy(id: String) -> bool:
	if not _can_interact() or not item_buttons.has(id) or not _state.owned(_item(id), _counts):
		return false
	if id == _toy.get("id", "") and not _preview_locked and not item_buttons[id]._showing_error:
		return true
	_choose_item(id, false)
	return id == _state.toy_id and id == _toy.get("id", "") and not _preview_locked and not item_buttons[id]._showing_error


func _play_toy() -> void:
	if _preview_locked or _toy.is_empty() or not _can_interact():
		return
	if item_buttons[_toy.id]._showing_error and not _activate_playground_toy(_toy.id):
		return
	playground.cancel()
	if _stage == 3:
		_reset_sequence()
		_refresh_room()
		return
	_action = _toy.action
	_stage += 1
	_action_progress = 1.0 if _reduced_motion else 0.0
	feedback_text = "%d/3 · %s" % [_stage, OUTCOMES[_action][_stage - 1]]
	_refresh_toy_control()
	_apply_action()
	set_process(not _reduced_motion)
	word_requested.emit(_toy.word_id)
	toy_played.emit(_action)


func _layout_room() -> void:
	if _room == null or toy_button == null:
		return
	var width := maxf(240, _room.size.x)
	if playground == null: return
	_layout_owned_toys()
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
	_toy_marks.cake_stage = _stage if _action == "decorate" else 0
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
	elif _action == "swing":
		offsets.append_array([Vector2(-30, -28), Vector2(10, -16), Vector2(-26, -22)])
		rotations = [0.0, -0.3, 0.24, -0.08]
	elif _action == "decorate":
		offsets.append_array([Vector2(-10, 0), Vector2(-10, -4), Vector2(-10, -8)])
		var scales := [1.0, 1.0, 1.04, 1.08]
		toy_button.scale = Vector2.ONE * lerpf(scales[previous], scales[_stage], progress)
	if offsets.size() == 4:
		var offset := offsets[previous].lerp(offsets[_stage], progress)
		if playground._toy_home.x < _room.size.x * 0.5: offset.x *= -1
		toy_button.position += offset
		toy_button.rotation = lerpf(rotations[previous], rotations[_stage], progress)
		if _action == "ring" and not _reduced_motion:
			toy_button.rotation += sin(progress * TAU * 3) * 0.16 * sin(progress * PI)
	playground._place_toy(toy_button.position + toy_button.size * 0.5)
	toy_button.z_index = 10 if not _action.is_empty() else 0
	_toy_label.z_index = toy_button.z_index
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
	for button in item_buttons.values():
		button.stop_press()
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
	for button in [toy_button, goal_button] + item_buttons.values():
		if button != null:
			result.append(button)
	return result


func _direct_play_started() -> void:
	_action = ""
	_stage = 0
	_action_progress = 0
	set_process(false)
	_apply_action()
	_refresh_toy_control()


func _direct_play_feedback(kind: String, message: String) -> void:
	feedback_text = message
	if kind == "throw": word_requested.emit(_toy.word_id)
	pip_interaction.emit(kind, message)


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if playground != null:
		playground.configure(playground.toy_word, playground.toy_locked, value, playground.accent)
	if value: settle()
