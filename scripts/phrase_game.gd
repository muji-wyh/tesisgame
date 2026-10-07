extends Control
## Listen, drag words into a phrase, and keep correcting until it is right.

signal finished
signal status_changed(message: String)
signal audio_requested(kind: String, value: String)
signal changed(snapshot: Dictionary)

const PhraseGameModel = preload("res://scripts/phrase_game_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Mascot = preload("res://scripts/duck_mascot.gd")
const Icons = preload("res://scripts/icon_button.gd")
const UiClick = preload("res://scripts/ui_click.gd")

var game := PhraseGameModel.new()
var interaction_allowed: Callable
var pip: Mascot
var option_buttons: Array[Button] = []
var answer_buttons: Array[Button] = []
var listen_button: Button
var action_button: Button
var transcript_button: Icons
var reduced_motion: bool = false
var _heading: Label
var _progress: Label
var _feedback: Label
var _preview: Button
var _palette: Dictionary = {}
var _theme_id: String = "spring"
var _paused: bool = false
var _finished_emitted: bool = false
var _configured: bool = false
var _muted: bool = false
var _show_phrase: bool = false
var _question_id: String = ""
var _answer_drop: Rect2
var _bank_drop: Rect2
var _pointer: int = -2
var _gesture_serial: int = 0
var _source: Button
var _source_kind: String = ""
var _source_index: int = -1
var _drag_word: int = -1
var _press_point: Vector2
var _drag_offset: Vector2
var _dragging: bool = false
var _drop_kind: String = ""
var _drop_index: int = -1
var _settle_tween: Tween


func _init() -> void:
	name = "PhraseBuilder"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip = Mascot.new()
	pip.name = "PhrasePip"
	pip.focus_mode = Control.FOCUS_NONE
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.set_proactive_allowed(false)
	add_child(pip)
	_heading = _label("Build the phrase", 26)
	_heading.add_theme_font_override("font", Style.HEADING_FONT)
	_progress = _label("1 / 3", 13)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress.add_theme_color_override("font_color", Style.MUTED)
	_feedback = _label("Drag words into place.", 14)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	listen_button = _button("Listen", "PhraseListen", play_prompt)
	listen_button.tooltip_text = "Hear Pip say the phrase again"
	UiClick.bind_button(listen_button)
	transcript_button = Icons.new()
	transcript_button.name = "PhraseTranscript"
	transcript_button.symbol = Icons.Symbol.EYE
	transcript_button.pressed.connect(_toggle_transcript)
	add_child(transcript_button)
	UiClick.bind_button(transcript_button)
	action_button = _button("Check answer", "PhraseAction", _activate)
	_preview = Button.new()
	_preview.name = "DraggedPhraseWord"
	_preview.focus_mode = Control.FOCUS_NONE
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.z_index = 100
	_preview.hide()
	add_child(_preview)
	resized.connect(_on_resized)
	visibility_changed.connect(_visibility_changed)
	apply_theme(Data.theme(_theme_id), _theme_id)


func _label(text: String, font_size: int) -> Label:
	var label := Style.label(text, font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	add_child(label)
	return label


func _button(text: String, node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	add_child(button)
	return button


func configure(vocabulary: Array, age_band: String, theme_id: String, seed_value: int = -1) -> bool:
	cancel_input()
	_paused = false
	_finished_emitted = false
	_question_id = ""
	_show_phrase = _muted
	_configured = game.reset(vocabulary, age_band, seed_value)
	apply_theme(Data.theme(theme_id), theme_id)
	pip.settle()
	pip.set_idle_paused(false)
	_refresh()
	return _configured


func apply_theme(palette: Dictionary, theme_id: String) -> void:
	_palette = palette
	_theme_id = theme_id
	if pip != null:
		pip.set_outfit_theme(theme_id)
		pip.accent = palette.get("accent", Style.GOOD)
	_layout()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	pip.set_reduced_motion(value)
	if value:
		cancel_input()


func set_speaking(value: bool) -> void:
	pip.set_speaking(value and not _paused and is_visible_in_tree())


func set_muted(value: bool) -> void:
	if _muted == value:
		return
	_muted = value
	if value:
		_show_phrase = true
	_refresh()


func _toggle_transcript() -> void:
	if not _can_interact() or game.phase != "building":
		return
	_show_phrase = not _show_phrase
	_refresh()


func pause(value: bool = true) -> void:
	if _paused == value:
		return
	_paused = value
	if value:
		cancel_input()
		pip.set_speaking(false)
	pip.set_idle_paused(value)
	_refresh()


func resume() -> void:
	pause(false)


func stop() -> void:
	_paused = true
	cancel_input()
	pip.settle()
	pip.set_idle_paused(true)
	_refresh()


func cancel_input() -> void:
	_pointer = -2
	_dragging = false
	_source = null
	_source_kind = ""
	_source_index = -1
	_drag_word = -1
	_drop_kind = ""
	_drop_index = -1
	if is_instance_valid(_settle_tween):
		_settle_tween.kill()
	if is_instance_valid(_preview):
		_preview.hide()
	for button in option_buttons + answer_buttons:
		button.modulate = Color.WHITE
	for button in option_buttons + answer_buttons + [listen_button, action_button, transcript_button]:
		if is_instance_valid(button):
			button.set_pressed_no_signal(false)
	queue_redraw()
	_publish.call_deferred()


func _on_resized() -> void:
	cancel_input()
	_layout()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_input()
		pip.set_speaking(false)
	pip.set_idle_paused(_paused or not is_visible_in_tree())
	_publish.call_deferred()


func _can_interact() -> bool:
	return _configured and not _paused and is_visible_in_tree() \
		and (not interaction_allowed.is_valid() or bool(interaction_allowed.call()))


func release_pointer(pointer: int) -> void:
	# Window capture can observe release before Godot's canvas handler. Give the
	# regular drop first refusal, then cancel only a gesture that never received it.
	_cancel_unreleased_pointer.call_deferred(pointer, _gesture_serial)


func _cancel_unreleased_pointer(pointer: int, serial: int) -> void:
	if _pointer == pointer and _gesture_serial == serial:
		cancel_input()


func play_prompt() -> void:
	if _can_interact() and not game.current_question().is_empty():
		audio_requested.emit("phrase", str(game.current_question().id))


func _choose(index: int) -> void:
	if not _can_interact() or _pointer != -2 or game.phase != "building" or not game.select(index):
		return
	_word_placed(index)


func _word_placed(index: int) -> void:
	audio_requested.emit("select", "")
	audio_requested.emit("word", str(game.options[index].id))
	pip.react("curious")
	_refresh()
	_restore_focus()


func _remove(index: int) -> void:
	if not _can_interact() or _pointer != -2 or game.phase != "building" or not game.remove(index):
		return
	audio_requested.emit("select", "")
	_refresh()
	_restore_focus()


func _activate() -> void:
	if not _can_interact() or _pointer != -2:
		return
	cancel_input()
	if game.phase == "correct":
		audio_requested.emit("select", "")
		if game.advance():
			_refresh()
			if game.phase == "finished":
				if not _finished_emitted:
					_finished_emitted = true
					finished.emit()
			else:
				play_prompt()
				_restore_focus()
		return
	if game.phase != "building":
		return
	var result: String = game.check_answer()
	if not result in ["correct", "wrong"]:
		return
	var correct: bool = result == "correct"
	pip.react_gameplay(correct)
	audio_requested.emit("feedback", result)
	if correct:
		audio_requested.emit("phrase", str(game.current_question().id))
	_refresh()
	if correct:
		action_button.grab_focus()
	elif not answer_buttons.is_empty() and not answer_buttons[0].disabled:
		answer_buttons[0].grab_focus()
	else:
		_restore_focus()


func _input(event: InputEvent) -> void:
	if _pointer != -2 and event.is_action_pressed("ui_cancel"):
		cancel_input()
		get_viewport().set_input_as_handled()
		return
	if not _can_interact() or game.phase != "building":
		return
	# Touch owns its gesture; Godot's synthetic mouse must never commit it twice.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var consumed: bool = false
	if event is InputEventScreenTouch:
		if event.canceled and event.index == _pointer:
			cancel_input()
			consumed = true
		elif event.pressed:
			consumed = _press_word(event.index, event.position)
		elif event.index == _pointer:
			_release_word(event.position)
			consumed = true
	elif event is InputEventScreenDrag and event.index == _pointer:
		_move_word(event.position)
		consumed = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.canceled and _pointer == -1:
			cancel_input()
			consumed = true
		elif event.pressed:
			consumed = _press_word(-1, event.position)
		elif _pointer == -1:
			_release_word(event.position)
			consumed = true
	elif event is InputEventMouseMotion and _pointer == -1:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_move_word(event.position)
		else:
			cancel_input()
		consumed = true
	if consumed:
		get_viewport().set_input_as_handled()


func _press_word(pointer: int, point: Vector2) -> bool:
	if _pointer != -2:
		return true
	var button: Button
	var kind: String = ""
	var index: int = -1
	for candidate in answer_buttons + option_buttons:
		if candidate.is_visible_in_tree() and not candidate.disabled and candidate.get_global_rect().has_point(point):
			button = candidate
			index = answer_buttons.find(candidate)
			kind = "answer" if index >= 0 else "bank"
			if index < 0:
				index = option_buttons.find(candidate)
			break
	if button == null:
		return false
	cancel_input()
	_gesture_serial += 1
	_pointer = pointer
	_source = button
	_source_kind = kind
	_source_index = index
	_drag_word = game.answer[index] if kind == "answer" else index
	_press_point = point
	_drag_offset = get_global_transform().affine_inverse() * point - button.position
	button.grab_focus()
	button.set_pressed_no_signal(true)
	return true


func _move_word(point: Vector2) -> void:
	var s: float = Style.ui_scale(self)
	if not _dragging and point.distance_to(_press_point) * s < 8:
		return
	if not _dragging:
		_dragging = true
		_source.set_pressed_no_signal(false)
		_source.modulate.a = 0.25
		_preview.text = str(game.options[_drag_word].text)
		_preview.size = _source.size
		_style_tile(_preview, true, false, false, s)
		var lifted := _preview.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		lifted.shadow_color = Color(Style.INK, 0.20)
		lifted.shadow_size = ceili(12 / s)
		lifted.shadow_offset = Vector2(0, 5 / s)
		_preview.add_theme_stylebox_override("normal", lifted)
		_preview.show()
	var local: Vector2 = get_global_transform().affine_inverse() * point
	_preview.position = local - _drag_offset - Vector2(0, (30 if _pointer >= 0 else 4) / s)
	_update_drop(local)
	queue_redraw()
	_publish.call_deferred()


func _update_drop(point: Vector2) -> void:
	_drop_kind = ""
	_drop_index = -1
	if _answer_drop.has_point(point) and (game.answer.has(_drag_word) or game.answer.size() < answer_buttons.size()):
		_drop_kind = "answer"
		_drop_index = game.answer.size()
		for index in range(answer_buttons.size()):
			var button: Button = answer_buttons[index]
			if point.x < button.position.x + button.size.x:
				_drop_index = mini(index, game.answer.size())
				break
	elif _bank_drop.has_point(point) and game.answer.has(_drag_word):
		_drop_kind = "bank"


func _release_word(point: Vector2) -> void:
	var kind: String = _source_kind
	var source_index: int = _source_index
	var option_index: int = _drag_word
	var dragged: bool = _dragging
	var tap_inside: bool = is_instance_valid(_source) and _source.get_global_rect().has_point(point)
	var from: Rect2 = Rect2(_preview.position, _preview.size)
	if dragged:
		_update_drop(get_global_transform().affine_inverse() * point)
	var destination: String = _drop_kind
	var target_index: int = _drop_index
	cancel_input()
	if not _can_interact() or game.phase != "building":
		return
	if not dragged:
		if tap_inside:
			if kind == "bank":
				_choose(source_index)
			else:
				_remove(source_index)
		return
	var edited: bool = false
	if destination == "answer":
		edited = game.place(option_index, target_index)
		if edited:
			_word_placed(option_index)
	elif destination == "bank":
		edited = game.remove(game.answer.find(option_index))
		if edited:
			audio_requested.emit("select", "")
			_refresh()
			_restore_focus()
	if edited and not reduced_motion:
		var target: Button = answer_buttons[game.answer.find(option_index)] if destination == "answer" else option_buttons[option_index]
		_settle_word(from, target)


func _settle_word(from: Rect2, target: Button) -> void:
	_preview.text = target.text
	_preview.position = from.position
	_preview.size = from.size
	_preview.show()
	target.modulate.a = 0.0
	_settle_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_settle_tween.tween_property(_preview, "position", target.position, 0.12)
	_settle_tween.tween_property(_preview, "size", target.size, 0.12)
	_settle_tween.chain().tween_callback(func() -> void:
		_preview.hide()
		if is_instance_valid(target):
			target.modulate = Color.WHITE
	)


func _draw() -> void:
	if not _dragging or _drop_kind.is_empty():
		return
	var s: float = Style.ui_scale(self)
	var accent: Color = _palette.get("accent", Style.GOOD)
	var rect: Rect2 = _bank_drop if _drop_kind == "bank" else Rect2(answer_buttons[mini(_drop_index, answer_buttons.size() - 1)].position, answer_buttons[mini(_drop_index, answer_buttons.size() - 1)].size)
	var surface := Style.box(Color(accent, 0.08), accent, ceili(14 / s), ceili(2 / s))
	surface.draw(get_canvas_item(), rect.grow(3 / s))


func _refresh() -> void:
	var question: Dictionary = game.current_question()
	if str(question.get("id", "")) != _question_id:
		cancel_input()
		_question_id = str(question.get("id", ""))
		_show_phrase = _muted
		_rebuild_buttons()
	var correct: bool = game.phase == "correct"
	var wrong: bool = str(game.feedback) == "wrong"
	_progress.text = "%d / 3" % mini(game.question_index + 1, 3)
	_heading.text = str(question.get("text", "")) if _show_phrase or correct else "Try another order" if wrong else "Build the phrase"
	_feedback.text = "Well done!" if correct else "Try another order." if wrong else "Drag words into place. Tap to add or return."
	_feedback.add_theme_color_override("font_color", Style.GOOD if correct else Style.WRONG if wrong else Style.MUTED)
	for index in range(option_buttons.size()):
		var button: Button = option_buttons[index]
		button.visible = not game.answer.has(index)
		button.disabled = _paused or game.phase != "building" or game.answer.has(index)
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	for index in range(answer_buttons.size()):
		var button: Button = answer_buttons[index]
		var occupied: bool = index < game.answer.size()
		button.text = str(game.options[game.answer[index]].text) if occupied else str(index + 1)
		button.disabled = _paused or not occupied or game.phase != "building"
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		button.tooltip_text = "Drag to reorder or tap to return " + button.text if occupied else "Word %d" % (index + 1)
		button.set("accessibility_name", "Word %d: %s" % [index + 1, button.text] + (". Press to return this word." if occupied and not correct else ""))
	listen_button.disabled = _paused or question.is_empty() or game.phase == "finished"
	action_button.text = "Open chest" if correct and game.completed == 3 else "Continue" if correct else "Check answer"
	action_button.disabled = _paused or question.is_empty() or game.phase == "finished" \
		or (game.phase == "building" and game.answer.size() != question.get("words", []).size())
	transcript_button.disabled = _paused or question.is_empty() or game.phase != "building"
	transcript_button.engaged = _show_phrase or correct
	transcript_button.tooltip_text = "The completed phrase is shown." if correct else "Hide the written phrase" if _show_phrase else "Show the written phrase"
	transcript_button.set("accessibility_name", transcript_button.tooltip_text)
	for button in [listen_button, action_button, transcript_button]:
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	_layout()
	if _configured and game.phase != "finished":
		status_changed.emit("Phrase Builder. Phrase %d of 3. %s" % [mini(game.question_index + 1, 3), _feedback.text])
	_publish.call_deferred()


func _rebuild_buttons() -> void:
	for button in option_buttons + answer_buttons:
		remove_child(button)
		button.queue_free()
	option_buttons.clear()
	answer_buttons.clear()
	for index in range(game.options.size()):
		var button := _button(str(game.options[index].text), "PhraseOption_%d" % index, _choose.bind(index))
		button.tooltip_text = "Drag or tap to add " + button.text
		button.mouse_default_cursor_shape = Control.CURSOR_DRAG
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.set("accessibility_name", button.text + ". Drag or press to add this word.")
		option_buttons.append(button)
	for index in range(game.current_question().get("words", []).size()):
		var button := _button(str(index + 1), "PhraseAnswer_%d" % index, _remove.bind(index))
		button.mouse_default_cursor_shape = Control.CURSOR_DRAG
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		answer_buttons.append(button)


func _restore_focus() -> void:
	if not _can_interact():
		return
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner != null and owner.is_visible_in_tree() and owner.focus_mode != Control.FOCUS_NONE \
		and not (owner is Button and owner.disabled):
		return
	var target: Control = default_focus()
	if target != null:
		target.grab_focus()


func default_focus() -> Control:
	if not action_button.disabled and (game.phase == "correct" or game.answer.size() == answer_buttons.size()):
		return action_button
	for button in option_buttons:
		if button.is_visible_in_tree() and not button.disabled:
			return button
	return action_button if not action_button.disabled else listen_button


func navigation_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if not _can_interact():
		return controls
	for button in [listen_button, transcript_button] + answer_buttons + option_buttons + [action_button]:
		if button.is_visible_in_tree() and not button.disabled:
			controls.append(button)
	return controls


func _place(control: Control, rect: Rect2) -> void:
	var s: float = Style.ui_scale(self)
	control.position = rect.position / s
	control.size = rect.size.max(Vector2.ZERO) / s


func _style_tile(button: Button, filled: bool, correct: bool, wrong: bool, s: float) -> void:
	var accent: Color = _palette.get("accent", Style.GOOD)
	var edge: Color = Style.GOOD if correct else Style.WRONG if wrong and filled else Style.EDGE
	var fill: Color = Color("#e8f2e7") if correct else Color("#fbede5") if wrong and filled else Color.WHITE if filled else Color("#f1eee4")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var surface := Style.box(fill.darkened(0.04) if state == "pressed" else fill, accent if state == "hover" and filled else edge, ceili(12 / s), maxi(1, roundi(1 / s)))
		surface.set_content_margin_all(3 / s)
		if filled:
			surface.border_width_bottom = ceili((1 if state == "pressed" else 3) / s)
		button.add_theme_stylebox_override(state, surface)
	button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Style.INK, ceili(12 / s), ceili(2 / s)))
	button.add_theme_font_override("font", Style.HEADING_FONT)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(color, Style.INK if filled else Style.MUTED)
	button.custom_minimum_size = Vector2.ZERO
	button.clip_text = true
	var font_size: int = ceili(20 / s)
	var font: Font = button.get_theme_font("font")
	while font_size > ceili(12 / s) and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > button.size.x - 8 / s:
		font_size -= 1
	button.add_theme_font_size_override("font_size", font_size)


func _layout() -> void:
	if not is_instance_valid(action_button) or size.x <= 0 or size.y <= 0:
		return
	var s: float = Style.ui_scale(self)
	var w: float = size.x * s
	var h: float = size.y * s
	var compact: bool = h < 420
	var inner_w: float = minf(w, 800)
	var x: float = (w - inner_w) * 0.5
	var gap: float = 6 if compact else 10
	var columns: int = 3 if compact or w >= 480 else 2
	var rows: int = maxi(1, ceili(game.options.size() / float(columns)))
	var footer_h: float = 44 if compact else 50
	var helper_h: float = 26 if h >= 460 else 0
	var hero_h: float = clampf(h * 0.21, 104, 148)
	var tile_h: float
	var top: float = 0
	var answer_y: float
	var bank_y: float
	var footer_y: float
	if compact:
		tile_h = 44
		hero_h = maxf(24, h - (rows + 2) * tile_h - gap * (rows + 2))
		answer_y = hero_h + gap
		bank_y = answer_y + tile_h + gap
		footer_y = h - footer_h
	else:
		var fixed_height: float = hero_h + 16 + 16 + 20 + helper_h + footer_h + gap * (rows - 1)
		tile_h = clampf((h - fixed_height) / (rows + 1), 44, 70)
		var total_h: float = fixed_height + tile_h * (rows + 1)
		top = maxf(0, (h - total_h) * 0.3)
		answer_y = top + hero_h + 16
		bank_y = answer_y + tile_h + 16
		footer_y = bank_y + rows * tile_h + gap * (rows - 1) + 20 + helper_h
	var pip_side: float = minf(hero_h, 64) if compact or w < 360 else minf(hero_h, inner_w * 0.30)
	pip.custom_minimum_size = Vector2.ZERO
	_place(pip, Rect2(x, top + (hero_h - pip_side) * 0.5, pip_side, pip_side))
	var heading_x: float = x + pip_side + (8 if compact else 18)
	var heading_w: float = inner_w - (heading_x - x) - 44
	var heading_h: float = minf(34, hero_h)
	_place(_heading, Rect2(heading_x, top + (hero_h - heading_h) * 0.5 if compact else top + hero_h * 0.15, heading_w, heading_h))
	var font_size: int = ceili((16 if compact else 22 if w < 480 else 28) / s)
	while font_size > ceili(12 / s) and Style.HEADING_FONT.get_string_size(_heading.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > _heading.size.x:
		font_size -= 1
	_heading.add_theme_font_size_override("font_size", font_size)
	_progress.add_theme_font_size_override("font_size", ceili(12 / s))
	_place(_progress, Rect2(x + inner_w - 40, top + (hero_h - 24) * 0.5 if compact else top + hero_h * 0.15 + 5, 40, 24))
	var answer_w: float = (inner_w - gap * maxi(0, answer_buttons.size() - 1)) / maxi(1, answer_buttons.size())
	for index in range(answer_buttons.size()):
		var button: Button = answer_buttons[index]
		_place(button, Rect2(x + index * (answer_w + gap), answer_y, answer_w, tile_h))
		_style_tile(button, index < game.answer.size(), game.phase == "correct", str(game.feedback) == "wrong", s)
	_answer_drop = Rect2(Vector2(x, answer_y) / s, Vector2(inner_w, tile_h) / s).grow(3 / s)
	var option_w: float = (inner_w - gap * (columns - 1)) / columns
	var visible_index: int = 0
	for button in option_buttons:
		if not button.visible:
			continue
		_place(button, Rect2(x + (visible_index % columns) * (option_w + gap), bank_y + floori(visible_index / float(columns)) * (tile_h + gap), option_w, tile_h))
		_style_tile(button, true, false, false, s)
		visible_index += 1
	_bank_drop = Rect2(Vector2(x, bank_y) / s, Vector2(inner_w, rows * tile_h + gap * (rows - 1)) / s).grow(3 / s)
	_feedback.visible = helper_h > 0
	_feedback.add_theme_font_size_override("font_size", ceili(13 / s))
	_place(_feedback, Rect2(x, footer_y - helper_h - 6, inner_w, helper_h))
	var accent: Color = _palette.get("accent", Style.GOOD)
	for button in [listen_button, action_button]:
		Style.action_button(button, Style.GOOD if game.phase == "correct" else accent, button == action_button)
		button.custom_minimum_size = Vector2.ZERO
		button.clip_text = true
		button.add_theme_font_size_override("font_size", ceili((14 if compact else 16) / s))
		for state in ["normal", "hover", "pressed", "disabled"]:
			var surface: StyleBox = button.get_theme_stylebox(state)
			surface.content_margin_left = 4 / s
			surface.content_margin_right = 4 / s
	Style.square_icon_button(transcript_button, accent)
	transcript_button.custom_minimum_size = Vector2.ZERO
	if compact:
		if game.phase == "building":
			action_button.text = "Check"
		_place(listen_button, Rect2(x, footer_y, 64, footer_h))
		_place(transcript_button, Rect2(x + 64 + gap, footer_y, 44, footer_h))
		_place(action_button, Rect2(x + 108 + gap * 2, footer_y, inner_w - 108 - gap * 2, footer_h))
	else:
		var controls_y: float = top + hero_h - 48
		_place(listen_button, Rect2(heading_x, controls_y, 104, 44))
		_place(transcript_button, Rect2(heading_x + 112, controls_y, 44, 44))
		var action_w: float = minf(340, inner_w)
		_place(action_button, Rect2(x + (inner_w - action_w) * 0.5, footer_y, action_w, footer_h))
	queue_redraw()
	_publish.call_deferred()


func _rect_snapshot(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _control_snapshot(button: Button) -> Dictionary:
	return {"name": str(button.name), "text": button.text, "rect": _rect_snapshot(button.get_global_rect()), "disabled": button.disabled, "visible": button.is_visible_in_tree(), "accessibility_name": button.get("accessibility_name")}


func snapshot() -> Dictionary:
	var result: Dictionary = game.snapshot()
	result["visible"] = is_visible_in_tree()
	result["paused"] = _paused
	result["options"] = []
	result["answers"] = []
	for index in range(option_buttons.size()):
		var item: Dictionary = _control_snapshot(option_buttons[index])
		item["index"] = index
		item["word_id"] = str(game.options[index].id)
		result.options.append(item)
	for index in range(answer_buttons.size()):
		var item: Dictionary = _control_snapshot(answer_buttons[index])
		item["index"] = index
		result.answers.append(item)
	result["listen"] = _control_snapshot(listen_button)
	result["action"] = _control_snapshot(action_button)
	result["transcript"] = _control_snapshot(transcript_button)
	result["transcript_visible"] = _show_phrase or game.phase == "correct"
	result["answer_drop"] = _rect_snapshot(Rect2(_answer_drop.position + global_position, _answer_drop.size))
	result["bank_drop"] = _rect_snapshot(Rect2(_bank_drop.position + global_position, _bank_drop.size))
	result["dragging"] = _dragging
	result["drag_word"] = str(game.options[_drag_word].id) if _drag_word >= 0 and _drag_word < game.options.size() else ""
	result["drop_kind"] = _drop_kind
	result["drop_index"] = _drop_index
	return result


func _publish() -> void:
	if is_inside_tree():
		changed.emit(snapshot())
