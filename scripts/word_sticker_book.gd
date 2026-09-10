extends VBoxContainer

signal hear_requested(word: Dictionary)
signal selection_changed(word: Dictionary)
signal display_requested(id: String)
signal retry_requested
signal controls_changed

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")

var word_buttons: Dictionary = {}
var topic_index: int = 0
var selected_word: Dictionary = {}
var previous_topic_button: Button
var next_topic_button: Button
var hear_button: Button
var display_button: Button
var retry_button: Button
var interaction_allowed: Callable

var _words: Dictionary = {}
var _collected: Dictionary = {}
var _displayed_id: String = ""
var _palette: Dictionary = {}
var _audio_available: bool = true
var _save_failed: bool = false
var _grid: GridContainer
var _total_count: Label
var _topic_title: Label
var _topic_count: Label
var _selection: Label
var _save_failure: Label


func _ready() -> void:
	_build()
	visibility_changed.connect(_load_visible_artwork)
	_load_visible_artwork()


func _build() -> void:
	if _grid != null:
		return
	name = "WordStickerBook"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var intro := Style.label("Your word stickers", 26)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(intro)
	_total_count = _label("TotalCount", "Collected 0 / 140", 17)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	add_child(navigation)
	previous_topic_button = _button(navigation, "Previous topic", "Previous")
	next_topic_button = _button(navigation, "Next topic", "Next")
	previous_topic_button.pressed.connect(_turn_topic.bind(-1))
	next_topic_button.pressed.connect(_turn_topic.bind(1))
	_topic_title = _label("TopicTitle", "", 23)
	_topic_count = _label("TopicCount", "", 17)
	_selection = _label("Selection", "Choose a collected word.", 18)
	hear_button = _button(self, "Hear selected word", "Hear")
	hear_button.pressed.connect(_hear)
	display_button = _button(self, "Display selected word with Pip", "Display with Pip")
	display_button.pressed.connect(_display)
	_save_failure = _label("SaveFailure", "Your latest word changes could not be saved.", 16)
	_save_failure.add_theme_color_override("font_color", Style.WRONG)
	_save_failure.hide()
	retry_button = _button(self, "Retry saving word stickers", "Retry")
	retry_button.pressed.connect(_retry)
	retry_button.hide()
	_grid = GridContainer.new()
	_grid.name = "Words"
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	add_child(_grid)
	var hint := _label("CollectionHint", "Find matching words in games to collect their stickers.", 16)
	hint.add_theme_color_override("font_color", Style.MUTED)
	resized.connect(func() -> void: _grid.columns = 3 if size.x >= 520 else 2)


func _label(node_name: String, text: String, font_size: int) -> Label:
	var label := Style.label(text, font_size)
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


func _button(parent: Node, accessible_name: String, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Style.button(button, _palette.get("accent", Style.GOOD), 44)
	button.custom_minimum_size.y = 56
	button.add_theme_font_size_override("font_size", 18)
	_name_control(button, accessible_name)
	parent.add_child(button)
	return button


func setup(words: Array, collected_ids: Array[String], displayed_id: String, palette: Dictionary, save_failed: bool = false) -> void:
	_build()
	_words.clear()
	var canonical: Dictionary = {}
	for topic in Data.ADVENTURES:
		for id in topic.words:
			canonical[id] = true
	for word in words:
		if word is Dictionary and word.has_all(["id", "text", "image", "audio"]) and canonical.has(word.id):
			_words[word.id] = word
	_collected.clear()
	for id in collected_ids:
		if _words.has(id):
			_collected[id] = true
	_displayed_id = displayed_id if _collected.has(displayed_id) else ""
	_palette = palette
	_save_failed = save_failed
	_total_count.text = "Collected %d / %d" % [_collected.size(), _words.size()]
	_save_failure.visible = save_failed
	retry_button.visible = save_failed
	for button in [previous_topic_button, next_topic_button, hear_button, display_button, retry_button]:
		Style.button(button, palette.get("accent", Style.GOOD), 44)
		button.custom_minimum_size.y = 56
		button.add_theme_font_size_override("font_size", 18)
	_rebuild_topic()


func _rebuild_topic() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	word_buttons.clear()
	topic_index = wrapi(topic_index, 0, Data.ADVENTURES.size())
	var topic: Dictionary = Data.ADVENTURES[topic_index]
	_topic_title.text = "%s · %d / %d" % [topic.name, topic_index + 1, Data.ADVENTURES.size()]
	var collected_count := 0
	var available_count := 0
	for id in topic.words:
		if not _words.has(id):
			continue
		available_count += 1
		if _collected.has(id):
			collected_count += 1
		var button := _button(_grid, str(_words[id].text), "")
		button.name = "Word_" + id
		button.custom_minimum_size = Vector2(44, 148)
		button.disabled = not _collected.has(id)
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		button.pressed.connect(_select_word.bind(id))
		word_buttons[id] = button
		var picture := TextureRect.new()
		picture.name = "Picture"
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(picture)
		picture.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		picture.offset_left = 10
		picture.offset_right = -10
		picture.offset_top = 8
		picture.offset_bottom = 88
		var label := Style.label(str(_words[id].text), 20)
		label.name = "Word"
		label.clip_text = true
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		label.offset_top = 91
		label.offset_bottom = 119
		var status := Style.label("Collected" if _collected.has(id) else "Not collected", 13)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(status)
		status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		status.offset_top = 120
		status.offset_bottom = 144
	_topic_count.text = "Collected %d / %d" % [collected_count, available_count]
	var selection_id: String = str(selected_word.get("id", ""))
	if not word_buttons.has(selection_id) or not _collected.has(selection_id):
		selection_id = _displayed_id if word_buttons.has(_displayed_id) else ""
		if selection_id.is_empty():
			for id in word_buttons:
				if _collected.has(id):
					selection_id = id
					break
	selected_word = _words.get(selection_id, {})
	_refresh_selection()
	_load_visible_artwork()
	controls_changed.emit()


func _load_visible_artwork() -> void:
	if not is_visible_in_tree():
		return
	for id in word_buttons:
		var picture: TextureRect = word_buttons[id].get_node("Picture")
		if _collected.has(id) and picture.texture == null:
			picture.texture = load("res://" + str(_words[id].image))


func _refresh_selection() -> void:
	var selected_id: String = str(selected_word.get("id", ""))
	_selection.text = "Selected: " + str(selected_word.text) if not selected_word.is_empty() else "No stickers here yet. Find these words in games!"
	hear_button.text = "Hear" if _audio_available else "No sound"
	hear_button.disabled = selected_word.is_empty() or not _audio_available
	display_button.text = "With Pip" if not selected_id.is_empty() and selected_id == _displayed_id else "Display with Pip"
	display_button.disabled = selected_word.is_empty() or selected_id == _displayed_id
	for button in [hear_button, display_button]:
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	_name_control(hear_button, "Hear " + str(selected_word.get("text", "selected word")))
	for id in word_buttons:
		var accent: Color = _palette.get("accent", Style.GOOD)
		word_buttons[id].add_theme_stylebox_override("normal", Style.box(accent.lightened(0.9) if id == selected_id else Color.WHITE, accent if id == selected_id else accent.lightened(0.6), 16, 3 if id == selected_id else 2))


func set_audio_available(value: bool) -> void:
	_build()
	_audio_available = value
	_refresh_selection()


func _can_interact() -> bool:
	return is_visible_in_tree() and (not interaction_allowed.is_valid() or bool(interaction_allowed.call()))


func _select_word(id: String) -> void:
	if not _can_interact() or not _collected.has(id) or not word_buttons.has(id):
		return
	selected_word = _words[id]
	_refresh_selection()
	selection_changed.emit(selected_word)
	_hear()


func _hear() -> void:
	if _can_interact() and _audio_available and not selected_word.is_empty():
		hear_requested.emit(selected_word)


func _display() -> void:
	if _can_interact() and not selected_word.is_empty() and selected_word.id != _displayed_id:
		display_requested.emit(selected_word.id)


func _retry() -> void:
	if _can_interact() and _save_failed:
		retry_requested.emit()


func _turn_topic(direction: int) -> void:
	if _can_interact():
		topic_index = wrapi(topic_index + direction, 0, Data.ADVENTURES.size())
		_rebuild_topic()


func controls() -> Array[Control]:
	_build()
	var result: Array[Control] = [previous_topic_button, next_topic_button, hear_button, display_button, retry_button]
	for button in word_buttons.values():
		result.append(button)
	return result


func _name_control(control: Control, text: String) -> void:
	control.set("accessibility_name", text)
