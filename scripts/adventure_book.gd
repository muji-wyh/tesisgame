extends VBoxContainer

signal adventure_selected(id: String)
signal surprise_requested
signal retry_requested

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const PICTURES := {
	"animal-friends": ["cat", "dog"],
	"picnic-time": ["apple", "banana"],
	"great-outdoors": ["sun", "tree"],
	"dress-up": ["hat", "shirt"],
	"on-the-move": ["car", "plane"],
	"play-time": ["ball", "kite"],
	"at-home": ["bed", "lamp"],
	"head-to-toe": ["hand", "foot"],
	"ocean-discovery": ["whale", "crab"],
	"space-trip": ["rocket", "earth"],
	"garden-trail": ["rose", "pond"],
	"music-makers": ["piano", "guitar"]
}

var buttons: Dictionary = {}
var surprise_button: Button
var retry_button: Button

var _grid: GridContainer
var _visit_count: Label
var _save_failure: Label
var _statuses: Dictionary = {}
var _suggestions: Dictionary = {}


func _ready() -> void:
	_build()


func _build() -> void:
	if _grid != null:
		return
	name = "AdventureBook"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var intro := Style.label("Pick a place. Learn five words, then play!", 21)
	intro.name = "Intro"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(intro)
	_visit_count = Style.label("Places visited 0 / 12", 16)
	_visit_count.name = "VisitCount"
	_visit_count.add_theme_color_override("font_color", Style.MUTED)
	add_child(_visit_count)
	surprise_button = Button.new()
	surprise_button.name = "SurpriseMe"
	surprise_button.text = "Surprise me"
	surprise_button.pressed.connect(func() -> void: surprise_requested.emit())
	add_child(surprise_button)
	_save_failure = Style.label("This visit could not be remembered.", 16)
	_save_failure.name = "SaveFailure"
	_save_failure.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_failure.add_theme_color_override("font_color", Style.WRONG)
	_save_failure.hide()
	add_child(_save_failure)
	retry_button = Button.new()
	retry_button.name = "RetryVisit"
	retry_button.text = "Retry"
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	retry_button.hide()
	add_child(retry_button)
	_grid = GridContainer.new()
	_grid.name = "Places"
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	add_child(_grid)
	for topic in Data.ADVENTURES:
		_build_card(topic)
	resized.connect(_layout_columns)
	_layout_columns()


func _build_card(topic: Dictionary) -> void:
	var button := Button.new()
	button.name = "Adventure_" + topic.id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: adventure_selected.emit(topic.id))
	_grid.add_child(button)
	buttons[topic.id] = button
	for index in range(2):
		var picture := TextureRect.new()
		picture.name = "Picture" + str(index + 1)
		picture.texture = load("res://assets/images/words/%s.svg" % PICTURES[topic.id][index])
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(picture)
		picture.anchor_left = index * 0.5
		picture.anchor_right = (index + 1) * 0.5
		picture.offset_left = 10 if index == 0 else 3
		picture.offset_right = -3 if index == 0 else -10
		picture.offset_top = 12
		picture.offset_bottom = 82
	var title := _card_label(button, "TopicName", topic.name, 16, 86, 130)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_statuses[topic.id] = _card_label(button, "VisitStatus", "New place", 13, 132, 154)
	var suggestion := _card_label(button, "Suggestion", "Try this next", 12, 155, 177)
	suggestion.add_theme_color_override("font_color", Color("#80621c"))
	suggestion.hide()
	_suggestions[topic.id] = suggestion


func _card_label(button: Button, node_name: String, text: String, font_size: int, top: float, bottom: float) -> Label:
	var label := Style.label(text, font_size)
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_left = 6
	label.offset_right = -6
	label.offset_top = top
	label.offset_bottom = bottom
	return label


func setup(current_id: String, recent_ids: Array, suggested_id: String, accent: Color, save_failed: bool = false) -> void:
	_build()
	var visited := 0
	for topic in Data.ADVENTURES:
		var current: bool = topic.id == current_id
		var remembered: bool = recent_ids.has(topic.id)
		var suggested: bool = topic.id == suggested_id
		if remembered:
			visited += 1
		var status: String = "Pip is here" if current else "Visited" if remembered else "New place"
		_statuses[topic.id].text = status
		_statuses[topic.id].add_theme_color_override("font_color", accent if current else Style.MUTED)
		_suggestions[topic.id].visible = suggested
		var button: Button = buttons[topic.id]
		Style.button(button, accent, 44)
		# A small width minimum lets the grid shrink before its column count changes.
		button.custom_minimum_size = Vector2(44, 184)
		var fill: Color = accent.lightened(0.92) if current else Color("#fff7dc") if suggested else Color.WHITE
		var border: Color = accent if current else Color("#bd983f") if suggested else accent.lightened(0.68)
		button.add_theme_stylebox_override("normal", Style.box(fill, border, 16, 3 if current else 2))
		button.tooltip_text = "%s. %s.%s" % [topic.name, status, " Try this next." if suggested else ""]
		for property in button.get_property_list():
			if property.name == "accessibility_name":
				button.set("accessibility_name", button.tooltip_text)
				break
	_visit_count.text = "Places visited %d / %d" % [visited, Data.ADVENTURES.size()]
	for button in [surprise_button, retry_button]:
		Style.button(button, accent)
		button.custom_minimum_size.y = 56
	_save_failure.visible = save_failed
	retry_button.visible = save_failed
	_layout_columns()


func _layout_columns() -> void:
	_grid.columns = 4 if size.x >= 840 else 3 if size.x >= 560 else 2


func controls() -> Array[Control]:
	_build()
	var result: Array[Control] = [surprise_button, retry_button]
	for button in buttons.values():
		result.append(button)
	return result
