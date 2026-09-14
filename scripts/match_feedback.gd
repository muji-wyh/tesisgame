extends Control

signal hear_requested(word: Dictionary)
signal finished

const Style = preload("res://scripts/ui_style.gd")

var heading_label: Label
var action_button: Button
var word_buttons: Array[Button] = []
var _words: Array[Dictionary] = []
var _audio_available: bool = true
var _paused: bool = false
var _completed: bool = false


func _ready() -> void:
	heading_label = Style.label("", 16)
	heading_label.clip_text = true
	add_child(heading_label)
	for index in range(2):
		var button := Button.new()
		button.name = "Association%d" % (index + 1)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", 48)
		button.pressed.connect(_hear.bind(index))
		add_child(button)
		word_buttons.append(button)
	action_button = Button.new()
	action_button.name = "MatchResult"
	action_button.pressed.connect(_finish)
	add_child(action_button)
	resized.connect(_layout)
	set_palette({"accent": Style.GOOD})
	_refresh_controls()


func show_words(words: Array, heading: String, action_text: String = "") -> void:
	assert(words.size() in [1, 2], "Match feedback needs one or two word associations.")
	_words.assign(words)
	_completed = false
	_paused = false
	action_button.text = action_text
	for index in range(_words.size()):
		word_buttons[index].icon = load("res://" + _words[index].image)
	set_heading(heading)
	_refresh_controls()


func set_heading(text: String) -> void:
	heading_label.text = text
	_layout()


func set_palette(palette: Dictionary) -> void:
	heading_label.add_theme_color_override("font_color", palette.accent)
	for button in word_buttons + [action_button]:
		Style.button(button, palette.accent)
	_refresh_controls()


func set_audio_available(value: bool) -> void:
	_audio_available = value
	_refresh_controls()


func pause(value: bool) -> void:
	_paused = value
	_refresh_controls()


func controls() -> Array[Control]:
	var result: Array[Control] = []
	if not is_visible_in_tree() or _paused or _completed:
		return result
	for button in word_buttons + [action_button]:
		if button.visible and not button.disabled:
			result.append(button)
	return result


func _refresh_controls() -> void:
	var terminal: bool = not action_button.text.is_empty()
	for index in range(word_buttons.size()):
		var button := word_buttons[index]
		button.visible = index < _words.size() and not terminal
		button.disabled = _paused or _completed or not button.visible or not _audio_available
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		if index < _words.size():
			button.text = "%s\n%s" % [_words[index].text, "Tap to hear" if _audio_available else "No sound"]
			button.tooltip_text = ("Hear " if _audio_available else "No sound. ") + _words[index].text
	action_button.visible = terminal
	action_button.disabled = _paused or _completed or not terminal
	action_button.focus_mode = Control.FOCUS_NONE if action_button.disabled else Control.FOCUS_ALL
	_layout()


func _hear(index: int) -> void:
	if controls().has(word_buttons[index]):
		hear_requested.emit(_words[index])


func _finish() -> void:
	if not controls().has(action_button):
		return
	_completed = true
	_refresh_controls()
	finished.emit()


func _layout() -> void:
	if heading_label == null:
		return
	var wide: bool = size.x >= 392
	custom_minimum_size = Vector2(160, 104 if wide else 176)
	heading_label.position = Vector2.ZERO
	heading_label.size = Vector2(size.x, 24)
	var heading_font: Font = heading_label.get_theme_font("font")
	var heading_size: int = 16
	while heading_size > 12 and heading_font.get_string_size(heading_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, heading_size).x > size.x:
		heading_size -= 1
	heading_label.add_theme_font_size_override("font_size", heading_size)
	var width: float = (size.x - 8) * 0.5 if wide and _words.size() == 2 else size.x
	for index in range(word_buttons.size()):
		var button := word_buttons[index]
		button.position = Vector2(index * (width + 8), 32) if wide else Vector2(0, 24 + index * 80)
		button.size = Vector2(width, 72)
		var font: Font = button.get_theme_font("font")
		var font_size: int = 20
		for line in button.text.split("\n"):
			while font_size > 12 and font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width - 80:
				font_size -= 1
		button.add_theme_font_size_override("font_size", font_size)
	action_button.position = Vector2(0, 32 if wide else 24)
	action_button.size = Vector2(size.x, 72)
	action_button.add_theme_font_size_override("font_size", 20)
