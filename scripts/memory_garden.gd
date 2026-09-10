extends Control

signal card_revealed(word: Dictionary, kind: String, index: int)
signal answer_chosen(words: Array, correct: bool)
signal progress_changed(successes: int, attempts: int)
signal round_finished(won: bool, found_words: Array)
signal hear_requested(word: Dictionary)
signal prompt_ready

const Style = preload("res://scripts/ui_style.gd")
const Memory = preload("res://scripts/memory_game_model.gd")
const WordCard = preload("res://scripts/word_card.gd")
const Lesson = preload("res://scripts/word_lesson.gd")


class CardBack:
	extends Control

	var accent: Color = Style.GOOD
	var kind_label: Label
	var number_label: Label

	func setup(kind: String, index: int) -> void:
		name = "CardBack"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		kind_label = Style.label("Word" if kind == "word" else "Picture", 16)
		kind_label.name = "CardKind"
		kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(kind_label)
		number_label = Style.label(str(index + 1), 13)
		number_label.name = "CardPosition"
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.add_theme_color_override("font_color", Style.MUTED)
		add_child(number_label)
		resized.connect(_layout)
		_layout()

	func _layout() -> void:
		kind_label.position = Vector2(4, size.y * 0.5 - 12)
		kind_label.size = Vector2(maxf(0, size.x - 8), 22)
		number_label.position = Vector2(4, size.y * 0.5 + 9)
		number_label.size = Vector2(maxf(0, size.x - 8), 18)
		queue_redraw()

	func _draw() -> void:
		var seed := Vector2(size.x * 0.5, size.y * 0.25)
		draw_line(seed + Vector2(0, 3), seed + Vector2(0, -6), accent, 2.0, true)
		draw_colored_polygon(PackedVector2Array([seed, seed + Vector2(-7, -2), seed + Vector2(-8, -7), seed + Vector2(-2, -6)]), accent.lightened(0.15))
		draw_colored_polygon(PackedVector2Array([seed + Vector2(0, -3), seed + Vector2(1, -9), seed + Vector2(7, -10), seed + Vector2(6, -5)]), accent)


class FlowerProgress:
	extends Control

	var count: int = 0
	var accent: Color = Style.GOOD

	func _draw() -> void:
		for index in range(5):
			var center := Vector2(9 + index * 22, 8)
			var planted: bool = index < count
			var color: Color = accent if planted else accent.lightened(0.65)
			draw_line(center + Vector2(0, 2), center + Vector2(0, 12), color, 2, true)
			if planted:
				draw_line(center + Vector2(0, 9), center + Vector2(5, 6), color, 2, true)
			for petal in range(5):
				var point: Vector2 = center + Vector2.UP.rotated(float(petal) * TAU / 5) * 4
				draw_circle(point, 2.8, color, planted, -1.0 if planted else 1.0, true)
			draw_circle(center, 2.4, Color("#ffd24d") if planted else Color.WHITE)


var memory = Memory.new()
var card_buttons: Array[Button] = []
var study_button: Button
var feedback_view
var status_label: Label
var audio_available: bool = true
var reduced_motion: bool = false

var _palette: Dictionary = {"accent": Style.GOOD}
var _paused: bool = false
var _board: Control
var _flowers: FlowerProgress
var _flower_count: Label


func _ready() -> void:
	_build()


func _build() -> void:
	if _board != null:
		return
	custom_minimum_size = Vector2(216, 200)
	_board = Control.new()
	_board.name = "GardenCards"
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	status_label = Style.label("", 16)
	status_label.name = "MemoryStatus"
	status_label.clip_text = true
	add_child(status_label)
	_flowers = FlowerProgress.new()
	_flowers.name = "FlowerProgress"
	_flowers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flowers)
	_flower_count = Style.label("0 / 5", 13)
	_flower_count.name = "FlowerCount"
	add_child(_flower_count)
	study_button = Button.new()
	study_button.name = "StudyGarden"
	study_button.text = "Study"
	study_button.pressed.connect(_toggle_study)
	add_child(study_button)
	feedback_view = Lesson.new()
	feedback_view.name = "MemoryFeedback"
	add_child(feedback_view)
	feedback_view.finished.connect(continue_feedback)
	feedback_view.hear_requested.connect(_hear_feedback)
	feedback_view.word_changed.connect(_feedback_word_changed)
	feedback_view.hide()
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	set_palette(_palette)
	_layout()


func start_round(words: Array, palette: Dictionary, seed_value: int = -1) -> void:
	_build()
	memory.stop()
	for index in range(card_buttons.size()):
		var button = card_buttons[index]
		button.pressed.disconnect(_choose.bind(index))
		button.clear_feedback()
		_board.remove_child(button)
		button.queue_free()
	card_buttons.clear()
	memory = Memory.new()
	_paused = false
	if memory.reset(words, seed_value):
		for index in range(memory.cards.size()):
			var button = WordCard.new()
			button.setup(memory.cards[index])
			button.name = "MemoryCard%d" % (index + 1)
			button.focus_mode = Control.FOCUS_ALL
			button.set_reduced_motion(reduced_motion)
			button.pressed.connect(_choose.bind(index))
			_board.add_child(button)
			var back := CardBack.new()
			back.setup(memory.cards[index].kind, index)
			button.add_child(back)
			back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			card_buttons.append(button)
	else:
		memory.stop()
	feedback_view.hide()
	set_palette(palette)
	_refresh()
	_layout()
	progress_changed.emit(0, 0)
	prompt_ready.emit()


func pause(value: bool) -> void:
	if _paused == value:
		return
	_paused = value
	_refresh()
	prompt_ready.emit()


func stop() -> void:
	memory.stop()
	_paused = false
	for button in card_buttons:
		button.clear_feedback()
	_refresh()
	prompt_ready.emit()


func controls() -> Array[Control]:
	var result: Array[Control] = []
	if _paused or not is_visible_in_tree():
		return result
	if memory.phase == "feedback":
		return feedback_view.controls()
	if not memory.phase in ["waiting", "matching"] or card_buttons.is_empty():
		return result
	for button in card_buttons:
		if not button.disabled:
			result.append(button)
	result.append(study_button)
	return result


func set_palette(palette: Dictionary) -> void:
	_build()
	_palette = palette
	Style.button(study_button, palette.accent)
	study_button.add_theme_font_size_override("font_size", 16)
	study_button.custom_minimum_size = Vector2(132, 44)
	_flowers.accent = palette.accent
	feedback_view.set_palette(palette)
	_refresh()
	_layout()


func set_audio_available(value: bool) -> void:
	_build()
	if audio_available == value:
		return
	audio_available = value
	feedback_view.set_audio_available(value)
	if memory.phase == "feedback":
		prompt_ready.emit()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	for button in card_buttons:
		button.set_reduced_motion(value)
	if feedback_view != null:
		feedback_view.set_reduced_motion(value)


func continue_feedback() -> void:
	if _paused or not is_visible_in_tree() or memory.phase != "feedback":
		return
	var result: String = memory.continue_feedback()
	_refresh()
	prompt_ready.emit()
	if result == "won":
		var found: Array = []
		for word_id in memory.matched_word_ids:
			for card in memory.cards:
				if card.word.id == word_id and card.kind == "word":
					found.append(card.word.duplicate(true))
					break
		round_finished.emit(true, found)


func _choose(index: int) -> void:
	if not _can_play() or memory.studying:
		return
	var result: String = memory.select(index)
	if result == "ignored":
		return
	if result in ["correct", "wrong"]:
		feedback_view.show_words(memory.feedback_words, "A new flower!" if memory.last_correct else "Let's learn these words.", "Continue")
		feedback_view.set_audio_available(audio_available)
	_refresh()
	if result != "cancelled":
		var card: Dictionary = memory.cards[index]
		card_revealed.emit(card.word, card.kind, index)
	if result in ["correct", "wrong"]:
		progress_changed.emit(memory.matched_word_ids.size(), memory.attempts)
		answer_chosen.emit(memory.feedback_words.duplicate(true), memory.last_correct)
	prompt_ready.emit()


func _toggle_study() -> void:
	if _can_play() and memory.set_study(not memory.studying):
		_refresh()
		prompt_ready.emit()


func _can_play() -> bool:
	return not _paused and is_visible_in_tree() and memory.phase in ["waiting", "matching"]


func _hear_feedback(word: Dictionary) -> void:
	if memory.phase == "feedback" and audio_available and not _paused and is_visible_in_tree():
		hear_requested.emit(word)


func _feedback_word_changed(_word: Dictionary) -> void:
	if memory.phase == "feedback":
		prompt_ready.emit()


func _visibility_changed() -> void:
	_refresh()
	prompt_ready.emit()


func _refresh() -> void:
	if _board == null:
		return
	var playing: bool = memory.phase in ["waiting", "matching"] and not card_buttons.is_empty()
	_board.visible = playing or memory.phase == "won"
	study_button.visible = playing
	study_button.disabled = not playing or _paused
	study_button.text = "Return to play" if memory.studying else "Study"
	study_button.tooltip_text = "Hide unmatched cards and play" if memory.studying else "Study all five word and picture pairs"
	_name_control(study_button, study_button.text + ". " + study_button.tooltip_text)
	feedback_view.visible = memory.phase == "feedback"
	feedback_view.pause(_paused or not is_visible_in_tree() or memory.phase != "feedback")
	status_label.visible = playing or memory.phase == "won" or not memory.error.is_empty()
	_flowers.visible = playing or memory.phase == "won"
	_flower_count.visible = _flowers.visible
	_flowers.count = memory.matched_word_ids.size()
	_flowers.queue_redraw()
	_flower_count.text = "%d / 5" % _flowers.count
	_name_control(_flower_count, "%d of 5 flowers planted" % _flowers.count)
	if not memory.error.is_empty():
		status_label.text = memory.error
	elif memory.phase == "feedback":
		status_label.text = "A new flower!" if memory.last_correct else "Let's learn these words."
	elif memory.phase == "won":
		status_label.text = "Garden complete!"
	elif memory.studying:
		status_label.text = "Study the garden."
	elif not memory.selected_indices.is_empty():
		var first: Dictionary = memory.cards[memory.selected_indices[0]]
		status_label.text = ("Word: " if first.kind == "word" else "Picture: ") + first.word.text
	else:
		status_label.text = "Find a pair."
	status_label.tooltip_text = status_label.text
	for index in range(card_buttons.size()):
		var button = card_buttons[index]
		var card: Dictionary = memory.cards[index]
		var matched: bool = memory.matched_word_ids.has(card.word.id)
		var revealed: bool = memory.is_revealed(index)
		var selected: bool = memory.selected_indices.has(index)
		button.word_label.text = card.word.text if revealed else ""
		button.refresh(_palette, selected and not matched, matched, selected and memory.phase == "feedback" and not memory.last_correct, not playing or _paused or memory.studying)
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		button.picture.visible = revealed and (matched or card.kind == "image")
		button.word_label.visible = revealed and (matched or card.kind == "word")
		button.picture.modulate.a = 1.0
		button.word_label.modulate.a = 1.0
		var back: CardBack = button.get_node("CardBack")
		back.visible = not revealed
		back.accent = _palette.accent
		back.queue_redraw()
		var label: String = ("Word" if card.kind == "word" else "Picture") + " %d" % (index + 1)
		if revealed:
			label += ": " + card.word.text + (". Planted." if matched else "")
		button.tooltip_text = label
		_name_control(button, label)
	_layout()


func _layout() -> void:
	if _board == null:
		return
	var wide: bool = (size.x >= 420 and size.x >= size.y * 1.3) or (size.x >= 392 and size.y < 460)
	var columns: int = 5 if wide else 2
	var rows: int = 2 if wide else 5
	var header: float = 44 if wide else 64
	var study_width: float = 132 if wide else clampf(size.x * 0.4, 132, 176)
	study_button.position = Vector2(size.x - study_width, 0)
	study_button.size = Vector2(study_width, header)
	var label_width: float = maxf(0, study_button.position.x - 8) if study_button.visible else size.x
	status_label.position = Vector2.ZERO
	status_label.size = Vector2(label_width, 24 if wide else 32)
	var font: Font = status_label.get_theme_font("font")
	var font_size: int = 16
	while font_size > 14 and font.get_string_size(status_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label_width:
		font_size -= 1
	status_label.add_theme_font_size_override("font_size", font_size)
	_flowers.position = Vector2(0, header - 22)
	_flowers.size = Vector2(110, 22)
	_flower_count.position = Vector2(112, header - 22)
	_flower_count.size = Vector2(maxf(0, label_width - 112), 22)
	_board.position = Vector2.ZERO
	_board.size = size
	var card_size := Vector2((size.x - 8 * (columns - 1)) / columns, (size.y - header - 4 - 8 * (rows - 1)) / rows)
	for index in range(card_buttons.size()):
		card_buttons[index].position = Vector2((index % columns) * (card_size.x + 8), header + 4 + (index / columns) * (card_size.y + 8))
		card_buttons[index].size = card_size
	feedback_view.position = Vector2.ZERO
	# Remove the previous portrait minimum before WordLesson measures its new shape.
	feedback_view.custom_minimum_size.y = 200
	feedback_view.size = size


func _name_control(control: Control, label: String) -> void:
	for property in control.get_property_list():
		if property.name == "accessibility_name":
			control.set("accessibility_name", label)
			return
