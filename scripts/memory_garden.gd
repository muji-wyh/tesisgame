extends Control

signal card_revealed(word: Dictionary, kind: String, index: int)
signal answer_chosen(words: Array, correct: bool)
signal progress_changed(successes: int, attempts: int)
signal round_finished(won: bool, found_words: Array)
signal prompt_ready

const Style = preload("res://scripts/ui_style.gd")
const Memory = preload("res://scripts/memory_game_model.gd")
const WordCard = preload("res://scripts/word_card.gd")
const IconButton = preload("res://scripts/icon_button.gd")
const FEEDBACK_SECONDS: float = 0.7


class CardBack:
	extends Control

	var accent: Color = Style.GOOD
	var fill_color: Color = Color.WHITE
	var ink_color: Color = Style.INK
	var kind_label: Label
	var number_label: Label
	var symbol_label: Label
	var _kind: String = ""
	var _light: Color = Color.WHITE
	var _spark: Color = Style.GOOD
	var _symbol_rect := Rect2()

	func setup(kind: String, index: int) -> void:
		name = "CardBack"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_kind = kind
		kind_label = Style.label("Word" if kind == "word" else "Picture", 13)
		kind_label.name = "CardKind"
		kind_label.clip_text = true
		add_child(kind_label)
		number_label = Style.label(str(index + 1), 11)
		number_label.name = "CardPosition"
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(number_label)
		symbol_label = Style.label("Aa" if kind == "word" else "", 40)
		symbol_label.name = "CardSymbol"
		symbol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		symbol_label.clip_text = true
		add_child(symbol_label)
		resized.connect(_layout)
		set_palette({"accent": Style.GOOD})

	func set_palette(palette: Dictionary) -> void:
		accent = palette.get("accent", Style.GOOD)
		_light = palette.get("light", accent.lightened(0.72))
		_spark = palette.get("spark", accent.lightened(0.35))
		fill_color = accent if _kind == "image" else _light.lerp(Color.WHITE, 0.3)
		ink_color = Color.WHITE if _kind == "image" else accent.darkened(0.12)
		for label in [kind_label, number_label, symbol_label]:
			if label.get_theme_color("font_color") != ink_color:
				label.add_theme_color_override("font_color", ink_color)
		_layout()

	func _layout() -> void:
		if size.x <= 0 or size.y <= 0:
			return
		var scale: float = Style.ui_scale(self)
		var compact: bool = size.y * scale < 64
		var narrow: bool = size.x * scale < 100
		kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if narrow or compact else HORIZONTAL_ALIGNMENT_LEFT
		var caption_width: float = maxf(0, size.x - (8 if narrow or compact else 42) / scale)
		var caption_font: Font = kind_label.get_theme_font("font")
		var caption_size: int = ceili(13 / scale)
		while caption_size > ceili(10 / scale) and caption_font.get_string_size(kind_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x > caption_width:
			caption_size -= 1
		if kind_label.get_theme_font_size("font_size") != caption_size:
			kind_label.add_theme_font_size_override("font_size", caption_size)
		kind_label.position = Vector2((4 if narrow or compact else 10) / scale, 2 / scale if compact else size.y - 30 / scale)
		kind_label.set_deferred("size", Vector2(caption_width, 22 / scale))
		if number_label.get_theme_font_size("font_size") != ceili(11 / scale):
			number_label.add_theme_font_size_override("font_size", ceili(11 / scale))
		number_label.position = Vector2(8 / scale if narrow else size.x - 28 / scale, size.y - 20 / scale if compact else 8 / scale if narrow else size.y - 29 / scale)
		number_label.set_deferred("size", Vector2(20, 18 if compact else 22) / scale)
		var top: float = (30 if narrow else 8) / scale
		var height: float = maxf(0, kind_label.position.y - 6 / scale - top)
		var side: float = 0 if compact else maxf(0, minf(96 / scale, minf(size.x * 0.64, height)))
		_symbol_rect = Rect2(Vector2((size.x - side) * 0.5, top + (height - side) * 0.5), Vector2.ONE * side)
		symbol_label.visible = _kind == "word" and side >= 16 / scale
		var symbol_size: int = maxi(1, floori(side * 0.7))
		var font: Font = symbol_label.get_theme_font("font")
		while symbol_size > 1 and (font.get_height(symbol_size) > side or font.get_string_size("Aa", HORIZONTAL_ALIGNMENT_LEFT, -1, symbol_size).x > side):
			symbol_size -= 1
		if symbol_label.get_theme_font_size("font_size") != symbol_size:
			symbol_label.add_theme_font_size_override("font_size", symbol_size)
		symbol_label.position = _symbol_rect.position
		symbol_label.set_deferred("size", _symbol_rect.size)
		queue_redraw()

	func _draw() -> void:
		var scale: float = Style.ui_scale(self)
		var surface := Rect2(Vector2.ONE * (2 / scale), size - Vector2.ONE * (4 / scale))
		if surface.size.x <= 0 or surface.size.y <= 0:
			return
		draw_style_box(Style.box(fill_color, Color.TRANSPARENT, ceili(12 / scale), 0), surface)
		draw_style_box(Style.box(Color.TRANSPARENT, Color(ink_color, 0.14), ceili(8 / scale), 1), surface.grow(-5 / scale))
		for fraction in [Vector2(0.16, 0.26), Vector2(0.8, 0.4), Vector2(0.26, 0.76)]:
			draw_circle(size * fraction, 2.4 / scale, Color(ink_color, 0.12))
		draw_circle(number_label.get_rect().get_center(), 10 / scale,
			fill_color.darkened(0.12) if _kind == "image" else Color.WHITE)
		var side: float = _symbol_rect.size.x
		if side < 16 / scale:
			return
		var center := _symbol_rect.get_center()
		if _kind == "word":
			draw_circle(center, side * 0.54, Color(1, 1, 1, 0.55))
			draw_arc(center, side * 0.54, 0, TAU, 48, Color(accent, 0.13), 1 / scale, true)
			return
		var frame := Rect2(center - Vector2(side * 0.43, side * 0.34), Vector2(side * 0.86, side * 0.68))
		draw_style_box(Style.box(Color.WHITE, Color.TRANSPARENT, maxi(1, roundi(side * 0.07)), 0), frame)
		var image := frame.grow(-side * 0.06)
		draw_style_box(Style.box(_light, Color.TRANSPARENT, maxi(1, roundi(side * 0.035)), 0), image)
		draw_circle(image.position + image.size * Vector2(0.74, 0.28), side * 0.07, Color("#ffe7a0"))
		draw_colored_polygon(PackedVector2Array([image.position + Vector2(0, image.size.y),
			image.position + image.size * Vector2(0.3, 0.35), image.position + image.size * Vector2(0.73, 1)]), _spark)
		draw_colored_polygon(PackedVector2Array([image.position + image.size * Vector2(0.38, 1),
			image.position + image.size * Vector2(0.7, 0.49), image.end]), accent.lightened(0.18))


var memory = Memory.new()
var card_buttons: Array[Button] = []
var study_button: IconButton
var status_label: Label
var reduced_motion: bool = false

var _palette: Dictionary = {"accent": Style.GOOD}
var _paused: bool = false
var _board: Control
var _feedback_timer: Timer
var _peek_touch: int = -1
var _mouse_peek: bool = false


func _ready() -> void:
	_build()


func _build() -> void:
	if _board != null:
		return
	custom_minimum_size = Vector2(216, 144)
	_board = Control.new()
	_board.name = "GardenCards"
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	status_label = Style.label("", 16)
	status_label.name = "MemoryStatus"
	status_label.clip_text = true
	status_label.hide()
	add_child(status_label)
	study_button = IconButton.new()
	study_button.name = "StudyGarden"
	study_button.symbol = IconButton.Symbol.EYE
	study_button.tooltip_text = "Hold to reveal all cards. Release to hide unmatched cards."
	_name_control(study_button, study_button.tooltip_text)
	study_button.button_down.connect(begin_peek)
	study_button.button_up.connect(end_peek)
	study_button.gui_input.connect(_study_input)
	study_button.focus_exited.connect(end_peek)
	study_button.mouse_exited.connect(_study_mouse_exited)
	study_button.tree_entered.connect(_layout)
	add_child(study_button)
	_feedback_timer = Timer.new()
	_feedback_timer.name = "MemoryFeedbackTimer"
	_feedback_timer.one_shot = true
	_feedback_timer.wait_time = FEEDBACK_SECONDS
	_feedback_timer.timeout.connect(continue_feedback)
	add_child(_feedback_timer)
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	set_palette(_palette)
	_layout()


func start_round(words: Array, palette: Dictionary, seed_value: int = -1) -> void:
	_build()
	memory.stop()
	_feedback_timer.stop()
	_peek_touch = -1
	_mouse_peek = false
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
			button.custom_minimum_size = Vector2(44, 44)
			button.name = "MemoryCard%d" % (index + 1)
			button.focus_mode = Control.FOCUS_ALL
			button.set_reduced_motion(reduced_motion)
			button.pressed.connect(_choose.bind(index))
			_board.add_child(button)
			var back := CardBack.new()
			back.setup(memory.cards[index].kind, index)
			button.set_back(back)
			button.set_face_up(false, false)
			card_buttons.append(button)
	else:
		memory.stop()
	set_palette(palette)
	_refresh()
	_layout()
	progress_changed.emit(0, 0)
	prompt_ready.emit()


func pause(value: bool) -> void:
	if _paused == value:
		return
	_paused = value
	if value:
		end_peek()
	_refresh()
	prompt_ready.emit()


func stop() -> void:
	memory.stop()
	if _feedback_timer != null:
		_feedback_timer.stop()
	_peek_touch = -1
	_mouse_peek = false
	_paused = false
	for button in card_buttons:
		button.clear_feedback()
	_refresh()
	prompt_ready.emit()


func controls() -> Array[Control]:
	var result: Array[Control] = []
	if _paused or not is_visible_in_tree():
		return result
	if not memory.phase in ["waiting", "matching", "feedback"] or card_buttons.is_empty():
		return result
	for button in card_buttons:
		if not button.disabled:
			result.append(button)
	if is_instance_valid(study_button) and study_button.is_visible_in_tree() and not study_button.disabled:
		result.append(study_button)
	return result


func set_palette(palette: Dictionary) -> void:
	_build()
	_palette = palette
	_refresh()
	_layout()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	for button in card_buttons:
		button.set_reduced_motion(value or _paused or not is_visible_in_tree())


func continue_feedback() -> void:
	if _paused or not is_visible_in_tree() or memory.phase != "feedback":
		return
	_feedback_timer.stop()
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
	if _paused or not is_visible_in_tree() or memory.studying or index < 0 or index >= memory.cards.size():
		return
	if memory.matched_word_ids.has(memory.cards[index].word.id):
		return
	if memory.phase == "feedback":
		continue_feedback()
		if _can_play():
			card_buttons[index].grab_focus()
	if not _can_play():
		return
	var result: String = memory.select(index)
	if result == "ignored":
		return
	card_buttons[index].play_press()
	if result in ["correct", "wrong"]:
		_feedback_timer.start()
	_refresh()
	if result != "cancelled":
		var card: Dictionary = memory.cards[index]
		card_revealed.emit(card.word, card.kind, index)
	if result in ["correct", "wrong"]:
		progress_changed.emit(memory.matched_word_ids.size(), memory.attempts)
		answer_chosen.emit(memory.feedback_words.duplicate(true), memory.last_correct)
	prompt_ready.emit()


func begin_peek() -> void:
	if _paused or not is_visible_in_tree() or not is_instance_valid(study_button):
		return
	if memory.phase == "feedback" and memory.matched_word_ids.size() < 5:
		continue_feedback()
	if _can_play() and memory.set_study(true):
		study_button.grab_focus()
		_refresh()
		prompt_ready.emit()


func end_peek() -> void:
	_peek_touch = -1
	_mouse_peek = false
	if memory.set_study(false):
		if is_instance_valid(study_button):
			study_button.set_pressed_no_signal(false)
		_refresh()
		prompt_ready.emit()


func _can_play() -> bool:
	return not _paused and is_visible_in_tree() and memory.phase in ["waiting", "matching"]


func _study_input(event: InputEvent) -> void:
	if not is_instance_valid(study_button):
		return
	if event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		study_button.accept_event()
		if not event.pressed:
			end_peek()
		elif not event.echo:
			begin_peek()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_peek = event.pressed and not event.canceled


func _study_mouse_exited() -> void:
	if _mouse_peek:
		end_peek()


func _input(event: InputEvent) -> void:
	if _board == null or _paused or not is_visible_in_tree():
		return
	if not is_instance_valid(study_button):
		end_peek()
		return
	if event is InputEventKey and not event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and memory.studying:
		end_peek()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var inside: bool = study_button.get_global_rect().has_point(event.position)
		if _peek_touch >= 0:
			get_viewport().set_input_as_handled()
			if event.index == _peek_touch and (not inside or (event is InputEventScreenTouch and (event.canceled or not event.pressed))):
				end_peek()
		elif inside and not study_button.disabled and event is InputEventScreenTouch and event.pressed and not event.canceled:
			get_viewport().set_input_as_handled()
			begin_peek()
			if memory.studying:
				_peek_touch = event.index
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION and (_peek_touch >= 0 or study_button.get_global_rect().has_point(event.position)):
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and (not event.pressed or event.canceled):
			end_peek()
		elif event is InputEventMouseMotion and _mouse_peek and (not study_button.get_global_rect().has_point(event.position) or (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0):
			end_peek()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		end_peek()
		for button in card_buttons:
			button.set_reduced_motion(true)
			button.set_reduced_motion(reduced_motion)


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		end_peek()
	_refresh()
	prompt_ready.emit()


func _refresh() -> void:
	if not is_instance_valid(_board):
		return
	var playing: bool = memory.phase in ["waiting", "matching"] and not card_buttons.is_empty()
	var reviewing: bool = memory.phase == "feedback"
	var suspended: bool = _paused or not is_visible_in_tree()
	_feedback_timer.paused = suspended
	_board.visible = playing or reviewing or memory.phase == "won"
	if is_instance_valid(study_button):
		study_button.visible = (playing or reviewing) and is_visible_in_tree()
		study_button.disabled = suspended or not (playing or (reviewing and memory.matched_word_ids.size() < 5))
		study_button.focus_mode = Control.FOCUS_NONE if study_button.disabled else Control.FOCUS_ALL
		study_button.engaged = memory.studying
	status_label.hide()
	if not memory.error.is_empty():
		status_label.text = memory.error
	elif memory.phase == "feedback":
		status_label.text = "A new flower!" if memory.last_correct else "Try another pair."
	elif memory.phase == "won":
		status_label.text = "Garden complete!"
	elif memory.studying:
		status_label.text = "Release to hide."
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
		button.set_reduced_motion(reduced_motion or suspended)
		button.refresh(_palette, selected and not matched and not reviewing, matched, selected and reviewing and not memory.last_correct, not (playing or reviewing) or suspended or memory.studying)
		button.set_face_up(revealed, not suspended and (playing or reviewing))
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		button.picture.modulate.a = 1.0
		button.word_label.modulate.a = 1.0
		var back: CardBack = button.find_child("CardBack", true, false)
		back.set_palette(_palette)
		var label: String = ("Word" if card.kind == "word" else "Picture") + " %d" % (index + 1)
		if revealed:
			label += ": " + card.word.text
		if matched:
			label += ". Planted."
		button.tooltip_text = label
		_name_control(button, label)
	_layout()


func _layout() -> void:
	if not is_instance_valid(_board):
		return
	var ui_scale: float = Style.ui_scale(self)
	var gap: float = ceilf(8 / ui_scale)
	var target: float = ceilf(44 / ui_scale)
	var header: float = 0.0
	if is_instance_valid(study_button) and study_button.get_parent() == self:
		Style.square_icon_button(study_button, _palette.accent)
		study_button.position = Vector2(size.x - target, 0)
		study_button.size = Vector2.ONE * target
		header = target
	_board.position = Vector2(0, header)
	_board.size = Vector2(size.x, maxf(0, size.y - _board.position.y))
	var columns: int = 2 if size.x < size.y else 5
	var rows: int = 10 / columns
	var card_size := Vector2((_board.size.x - gap * (columns - 1)) / columns, (_board.size.y - gap * (rows - 1)) / rows)
	for index in range(card_buttons.size()):
		var row: int = index / columns
		card_buttons[index].custom_minimum_size = Vector2.ONE * maxf(0, minf(target, minf(card_size.x, card_size.y)))
		card_buttons[index].position = Vector2((index % columns) * (card_size.x + gap), row * (card_size.y + gap))
		card_buttons[index].size = card_size


func _name_control(control: Control, label: String) -> void:
	for property in control.get_property_list():
		if property.name == "accessibility_name":
			control.set("accessibility_name", label)
			return
