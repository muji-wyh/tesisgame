extends Control
## Listen, assemble a short phrase, and keep correcting until it sounds right.

signal finished
signal status_changed(message: String)
signal audio_requested(kind: String, value: String)
signal changed(snapshot: Dictionary)

const PhraseGameModel = preload("res://scripts/phrase_game_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Mascot = preload("res://scripts/duck_mascot.gd")
const UiClick = preload("res://scripts/ui_click.gd")

var game := PhraseGameModel.new()
var interaction_allowed: Callable
var pip: Mascot
var option_buttons: Array[Button] = []
var answer_buttons: Array[Button] = []
var listen_button: Button
var action_button: Button
var clear_button: Button
var transcript_button: Button
var reduced_motion: bool = false
var _hero: Panel
var _puzzle: Panel
var _heading: Label
var _instruction: Label
var _progress: Label
var _feedback: Label
var _answer_caption: Label
var _bank_caption: Label
var _clue: TextureRect
var _steps: Array[Label] = []
var _vocabulary: Dictionary = {}
var _palette: Dictionary = {}
var _theme_id: String = "spring"
var _paused: bool = false
var _finished_emitted: bool = false
var _configured: bool = false
var _muted: bool = false
var _show_phrase: bool = false
var _question_id: String = ""


func _init() -> void:
	name = "PhraseBuilder"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero = Panel.new()
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hero)
	_puzzle = Panel.new()
	_puzzle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_puzzle)
	pip = Mascot.new()
	pip.name = "PhrasePip"
	pip.focus_mode = Control.FOCUS_NONE
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.set_proactive_allowed(false)
	add_child(pip)
	_clue = TextureRect.new()
	_clue.name = "PhrasePictureClue"
	_clue.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clue.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_clue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clue)
	_heading = _label("Build what you hear", 28)
	_heading.add_theme_font_override("font", Style.HEADING_FONT)
	_instruction = _label("Listen to Pip. Pick the words in order.", 15)
	_instruction.add_theme_color_override("font_color", Style.MUTED)
	_progress = _label("PHRASE 1 OF 3", 11)
	_progress.add_theme_color_override("font_color", Style.MUTED)
	_feedback = _label("", 14)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_answer_caption = _label("YOUR PHRASE", 11)
	_bank_caption = _label("WORD BANK", 11)
	for caption in [_answer_caption, _bank_caption]:
		caption.add_theme_color_override("font_color", Style.MUTED)
	for index in range(3):
		var step := _label(str(index + 1), 11)
		step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_steps.append(step)
	listen_button = _button("Listen", "PhraseListen", _listen)
	listen_button.tooltip_text = "Hear Pip say the phrase again"
	UiClick.bind_button(listen_button)
	action_button = _button("Check answer", "PhraseAction", _activate)
	clear_button = _button("Clear", "PhraseClear", _clear)
	clear_button.tooltip_text = "Return all your words to the word bank"
	transcript_button = _button("Show phrase", "PhraseTranscript", _toggle_transcript)
	UiClick.bind_button(transcript_button)
	resized.connect(_layout)
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
	_vocabulary.clear()
	for word: Dictionary in vocabulary:
		_vocabulary[str(word.id)] = word
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
	for button in option_buttons + answer_buttons:
		button.scale = Vector2.ONE
	for button in option_buttons + answer_buttons + [listen_button, action_button, clear_button, transcript_button]:
		if is_instance_valid(button):
			button.set_pressed_no_signal(false)


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_input()
		pip.set_speaking(false)
	pip.set_idle_paused(_paused or not is_visible_in_tree())
	_publish.call_deferred()


func _can_interact() -> bool:
	return _configured and not _paused and is_visible_in_tree() \
		and (not interaction_allowed.is_valid() or bool(interaction_allowed.call()))


func play_prompt() -> void:
	if _can_interact() and not game.current_question().is_empty():
		audio_requested.emit("phrase", str(game.current_question().id))


func _listen() -> void:
	play_prompt()


func _choose(index: int) -> void:
	if not _can_interact() or game.phase != "building" or not game.select(index):
		return
	audio_requested.emit("select", "")
	audio_requested.emit("word", str(game.options[index].id))
	pip.react("curious")
	_refresh()
	_restore_focus()


func _remove(index: int) -> void:
	if not _can_interact() or game.phase != "building" or not game.remove(index):
		return
	audio_requested.emit("select", "")
	_refresh()
	_restore_focus()


func _clear() -> void:
	if not _can_interact() or game.phase != "building" or game.answer.is_empty():
		return
	game.clear()
	audio_requested.emit("select", "")
	_refresh()
	_restore_focus()


func _activate() -> void:
	if not _can_interact():
		return
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
	else:
		audio_requested.emit("prompt", "phrase-try-again")
	_refresh()
	if correct:
		action_button.grab_focus()
	elif not answer_buttons.is_empty() and not answer_buttons[0].disabled:
		answer_buttons[0].grab_focus()
	else:
		_restore_focus()


func _refresh() -> void:
	var question: Dictionary = game.current_question()
	var new_question: bool = str(question.get("id", "")) != _question_id
	if new_question:
		_question_id = str(question.get("id", ""))
		_show_phrase = _muted
		_rebuild_buttons()
		var picture: Dictionary = _vocabulary.get(str(question.get("picture_id", "")), {})
		var path: String = str(picture.get("image", ""))
		_clue.texture = load("res://" + path) if not path.is_empty() and ResourceLoader.exists("res://" + path) else null
	var correct: bool = game.phase == "correct"
	var wrong: bool = str(game.feedback) == "wrong"
	_progress.text = "PHRASE %d OF 3" % mini(game.question_index + 1, 3)
	_heading.text = str(question.get("text", "")) if _show_phrase or correct else "Build what you hear"
	_instruction.text = "Three phrases, one lovely treasure." if correct else "Listen to Pip. Pick the words in order."
	_feedback.text = "That's it! " + str(question.get("text", "")) if correct else "Try again. Tap a selected word to change it." if wrong else "Pick your first word." if game.answer.is_empty() else "Tap a selected word to change it."
	_feedback.add_theme_color_override("font_color", Style.GOOD if correct else Style.WRONG if wrong else Style.MUTED)
	for index in range(_steps.size()):
		var step: Label = _steps[index]
		step.text = "✓" if index < game.completed else str(index + 1)
		step.add_theme_color_override("font_color", Color.WHITE if index < game.completed else Style.INK)
	for index in range(option_buttons.size()):
		var button: Button = option_buttons[index]
		button.disabled = _paused or not game.phase == "building" or game.answer.has(index)
		button.modulate.a = 0.35 if game.answer.has(index) else 1.0
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	for index in range(answer_buttons.size()):
		var button: Button = answer_buttons[index]
		var occupied: bool = index < game.answer.size()
		button.text = str(game.options[game.answer[index]].text) if occupied else str(index + 1)
		button.disabled = _paused or not occupied or not game.phase == "building"
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		button.tooltip_text = "Remove " + button.text if occupied else "Word %d" % (index + 1)
		button.set("accessibility_name", "Word %d: %s" % [index + 1, button.text] + (". Press to return this word." if occupied and not correct else ""))
	listen_button.disabled = _paused or question.is_empty() or game.phase == "finished"
	action_button.text = "Open chest" if correct and game.completed == 3 else "Continue" if correct else "Try again" if wrong else "Check answer"
	action_button.disabled = _paused or question.is_empty() or game.phase == "finished" \
		or (game.phase == "building" and game.answer.size() != question.get("words", []).size())
	clear_button.disabled = _paused or game.phase != "building" or game.answer.is_empty()
	transcript_button.disabled = _paused or question.is_empty() or game.phase != "building"
	transcript_button.tooltip_text = "The completed phrase is shown." if correct else "Hide the written phrase" if _show_phrase else "Show the written phrase. You can use this help anytime."
	transcript_button.set("accessibility_name", transcript_button.tooltip_text)
	for button in [listen_button, action_button, clear_button, transcript_button]:
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	_layout()
	if _configured and game.phase != "finished":
		var message: String = "Phrase Builder. Phrase %d of 3. %s" % [mini(game.question_index + 1, 3), _feedback.text if correct or wrong else "Listen to Pip, then choose the words in order."]
		status_changed.emit(message)
	_publish.call_deferred()


func _rebuild_buttons() -> void:
	for button in option_buttons + answer_buttons:
		remove_child(button)
		button.queue_free()
	option_buttons.clear()
	answer_buttons.clear()
	for index in range(game.options.size()):
		var button := _button(str(game.options[index].text), "PhraseOption_%d" % index, _choose.bind(index))
		button.tooltip_text = "Add " + button.text
		button.set("accessibility_name", button.text + ". Add this word to your phrase.")
		option_buttons.append(button)
	for index in range(game.current_question().get("words", []).size()):
		answer_buttons.append(_button(str(index + 1), "PhraseAnswer_%d" % index, _remove.bind(index)))


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
		if not button.disabled:
			return button
	return action_button if not action_button.disabled else listen_button


func navigation_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if not _can_interact():
		return controls
	for button in [listen_button, transcript_button] + answer_buttons + option_buttons + [clear_button, action_button]:
		if button.is_visible_in_tree() and not button.disabled:
			controls.append(button)
	return controls


func _place(control: Control, rect: Rect2) -> void:
	var s: float = Style.ui_scale(self)
	control.position = rect.position / s
	control.size = rect.size.max(Vector2.ZERO) / s


func _style_tile(button: Button, filled: bool, correct: bool, wrong: bool, scale_factor: float) -> void:
	var accent: Color = _palette.get("accent", Style.GOOD)
	var edge: Color = Style.GOOD if correct else Style.WRONG if wrong and filled else accent if filled else Style.EDGE
	var fill: Color = Color("#e8f2e7") if correct else Color("#fbede5") if wrong and filled else Color.WHITE if filled else Color("#f4f2e9")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var surface := Style.box(fill.darkened(0.04) if state == "pressed" else fill, edge, ceili(12 / scale_factor), maxi(1, roundi(1 / scale_factor)))
		surface.set_content_margin_all(3 / scale_factor)
		button.add_theme_stylebox_override(state, surface)
	button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Style.INK, ceili(12 / scale_factor), ceili(2 / scale_factor)))
	button.add_theme_font_override("font", Style.HEADING_FONT)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(color, Style.INK if filled else Style.MUTED)
	button.custom_minimum_size = Vector2.ZERO
	button.clip_text = true
	var font_size: int = ceili(19 / scale_factor)
	var font: Font = button.get_theme_font("font")
	while font_size > ceili(12 / scale_factor) and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > button.size.x - 8 / scale_factor:
		font_size -= 1
	button.add_theme_font_size_override("font_size", font_size)


func _layout() -> void:
	if not is_instance_valid(action_button) or size.x <= 0 or size.y <= 0:
		return
	var s: float = Style.ui_scale(self)
	var w: float = size.x * s
	var h: float = size.y * s
	var compact: bool = h < 330
	var split: bool = w >= 650 and not compact
	var accent: Color = _palette.get("accent", Style.GOOD)
	var gap: float = 4 if h < 470 else 10
	var padding: float = 0 if compact else 18 if split else 8
	var puzzle_x: float = w * 0.34 + gap if split else 0.0
	var hero_h: float = 30 if compact else h if split else clampf(h * 0.25, 64, 170)
	var puzzle_y: float = 0 if split or compact else hero_h + gap
	var puzzle_w: float = w - puzzle_x
	var puzzle_h: float = h - puzzle_y
	_place(_hero, Rect2(0, 0, puzzle_x - gap if split else w, hero_h))
	_place(_puzzle, Rect2(puzzle_x, puzzle_y, puzzle_w, puzzle_h))
	_hero.visible = not compact
	_puzzle.visible = not compact
	_hero.add_theme_stylebox_override("panel", Style.box(_palette.get("light", Color("#edf2e4")).lightened(0.35), Color.TRANSPARENT, ceili(24 / s), 0))
	_puzzle.add_theme_stylebox_override("panel", Style.box(Color(1, 1, 1, 0.72), Style.EDGE, ceili(24 / s), 1))
	var inner_x: float = puzzle_x + padding
	var inner_w: float = puzzle_w - padding * 2
	var top: float = puzzle_y + padding
	var show_heading: bool = puzzle_h >= 290
	var show_instruction: bool = puzzle_h >= 410
	var show_transcript: bool = _show_phrase or game.phase == "correct"
	var title_h: float = 24 + (34 if show_heading else 0) + (24 if show_instruction else 0)
	var footer_h: float = 44 if compact else 50
	var label_h: float = 16 if not compact and puzzle_h >= 360 else 0
	var feedback_h: float = 24 if not compact and puzzle_h >= 410 else 0
	var rows: int = ceili(game.options.size() / 3.0)
	rows = maxi(1, rows)
	var usable: float = puzzle_h - padding * 2 - title_h - footer_h - label_h * 2 - feedback_h - gap * (rows + 3)
	var tile_h: float = clampf(usable / (rows + 1), 44, 70)
	var answer_y: float = top + title_h + gap + label_h
	var bank_y: float = answer_y + tile_h + gap + label_h
	var footer_y: float = h - padding - footer_h
	if compact:
		# Keep every answer, word-bank tile and footer action at least 44 CSS px.
		title_h = maxf(16, h - (rows + 2) * 44 - gap * (rows + 2))
		tile_h = 44
		answer_y = title_h + gap
		bank_y = answer_y + tile_h + gap
		footer_y = h - footer_h
	var compact_pip_side: float = minf(title_h, 74)
	var compact_text_x: float = compact_pip_side + 8
	var title_center_y: float = top + (title_h - 24) * 0.5 if compact else top
	_heading.visible = (not compact and show_heading) or show_transcript
	_instruction.visible = not compact and show_instruction
	_feedback.visible = feedback_h > 0
	_answer_caption.visible = label_h > 0
	_bank_caption.visible = label_h > 0
	_clue.visible = _clue.texture != null and not compact and (not split or h >= 540)
	clear_button.visible = not compact
	_progress.visible = not show_transcript or (not compact and show_heading)
	_progress.add_theme_font_size_override("font_size", ceili((10 if compact else 11) / s))
	_place(_progress, Rect2(inner_x + (compact_text_x if compact else 0), title_center_y, inner_w - 110 - (compact_text_x if compact else 0), 24))
	for index in range(_steps.size()):
		var step: Label = _steps[index]
		step.visible = _progress.visible
		var step_side: float = 20 if compact else 24
		_place(step, Rect2(inner_x + inner_w - (3 - index) * (step_side + 5), top + (title_h - step_side) * 0.5 if compact else top + 1, step_side, step_side))
		step.add_theme_font_size_override("font_size", ceili(11 / s))
		step.add_theme_stylebox_override("normal", Style.box(Style.GOOD if index < game.completed else Color.WHITE, accent if index == game.question_index else Style.EDGE, ceili(12 / s), 1))
	var heading_x: float = inner_x + (compact_text_x if compact else 0)
	var heading_height: float = minf(32, title_h)
	var heading_y: float = top + (title_h - heading_height) * 0.5 if compact else top + (26 if show_heading else 0)
	var heading_width: float = inner_w - (compact_text_x if compact else 0)
	var heading_font: int = ceili((26 if split else 20 if not compact else 15) / s)
	while heading_font > ceili(12 / s) and Style.HEADING_FONT.get_string_size(_heading.text, HORIZONTAL_ALIGNMENT_LEFT, -1, heading_font).x > heading_width / s:
		heading_font -= 1
	_heading.add_theme_font_size_override("font_size", heading_font)
	_place(_heading, Rect2(heading_x, heading_y, heading_width, heading_height))
	_instruction.add_theme_font_size_override("font_size", ceili(13 / s))
	_place(_instruction, Rect2(inner_x, top + 58, inner_w, 22))
	for caption in [_answer_caption, _bank_caption]:
		caption.add_theme_font_size_override("font_size", ceili(10 / s))
	_place(_answer_caption, Rect2(inner_x, answer_y - label_h, inner_w, label_h))
	_place(_bank_caption, Rect2(inner_x, bank_y - label_h, inner_w, label_h))
	var answer_w: float = (inner_w - gap * maxi(0, answer_buttons.size() - 1)) / maxi(1, answer_buttons.size())
	for index in range(answer_buttons.size()):
		var button: Button = answer_buttons[index]
		_place(button, Rect2(inner_x + index * (answer_w + gap), answer_y, answer_w, tile_h))
		_style_tile(button, index < game.answer.size(), game.phase == "correct", str(game.feedback) == "wrong", s)
	var columns: int = mini(3, maxi(1, option_buttons.size()))
	var option_w: float = (inner_w - gap * (columns - 1)) / columns
	for index in range(option_buttons.size()):
		var button: Button = option_buttons[index]
		_place(button, Rect2(inner_x + (index % columns) * (option_w + gap), bank_y + floori(index / float(columns)) * (tile_h + gap), option_w, tile_h))
		_style_tile(button, true, false, false, s)
	_feedback.add_theme_font_size_override("font_size", ceili(12 / s))
	_place(_feedback, Rect2(inner_x, footer_y - feedback_h - 4, inner_w, feedback_h))
	for button in [listen_button, clear_button, action_button, transcript_button]:
		Style.action_button(button, Style.GOOD if game.phase == "correct" else accent, button == action_button)
		button.custom_minimum_size = Vector2.ZERO
		button.clip_text = true
		button.add_theme_font_size_override("font_size", ceili((14 if compact else 15) / s))
	for button in [listen_button, clear_button, transcript_button]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var surface: StyleBox = button.get_theme_stylebox(state)
			surface.content_margin_left = 4 / s
			surface.content_margin_right = 4 / s
	if not split:
		transcript_button.add_theme_font_size_override("font_size", floori(13 / s))
	if compact:
		transcript_button.text = "Shown" if game.phase == "correct" else "Hide" if _show_phrase else "Text"
		pip.custom_minimum_size = Vector2.ZERO
		_place(pip, Rect2(0, maxf(0, (title_h - compact_pip_side) * 0.5), compact_pip_side, compact_pip_side))
		_place(listen_button, Rect2(inner_x, footer_y, 64, footer_h))
		_place(transcript_button, Rect2(inner_x + 64 + gap, footer_y, 54, footer_h))
		_place(action_button, Rect2(inner_x + 118 + gap * 2, footer_y, inner_w - 118 - gap * 2, footer_h))
	elif split:
		transcript_button.text = "Phrase shown" if game.phase == "correct" else "Hide phrase" if _show_phrase else "Show phrase"
		var hero_w: float = puzzle_x - gap
		var pip_side: float = minf(hero_w - 28, h * 0.43)
		pip.custom_minimum_size = Vector2.ZERO
		_place(pip, Rect2((hero_w - pip_side) * 0.5, maxf(16, h * 0.12), pip_side, pip_side))
		var clue_side: float = minf(100, h * 0.17)
		_place(_clue, Rect2((hero_w - clue_side) * 0.5, h * 0.59, clue_side, clue_side))
		_place(listen_button, Rect2(18, h - 128, hero_w - 36, 50))
		_place(transcript_button, Rect2(18, h - 70, hero_w - 36, 50))
		_place(clear_button, Rect2(inner_x, footer_y, 78, footer_h))
		_place(action_button, Rect2(inner_x + 78 + gap, footer_y, inner_w - 78 - gap, footer_h))
	else:
		transcript_button.text = "Shown" if game.phase == "correct" else "Hide" if _show_phrase else "Text"
		var pip_side: float = minf(hero_h - 12, w * 0.44)
		pip.custom_minimum_size = Vector2.ZERO
		_place(pip, Rect2(12, (hero_h - pip_side) * 0.5, pip_side, pip_side))
		var right_x: float = pip_side + 28
		var right_w: float = w - right_x - 14
		var clue_side: float = minf(hero_h - 62, 82)
		_place(_clue, Rect2(right_x + (right_w - clue_side) * 0.5, 6, clue_side, clue_side))
		_place(listen_button, Rect2(right_x, hero_h - 52, right_w - 56 - gap, 44))
		_place(transcript_button, Rect2(right_x + right_w - 56, hero_h - 52, 56, 44))
		_place(clear_button, Rect2(inner_x, footer_y, 64, footer_h))
		_place(action_button, Rect2(inner_x + 64 + gap, footer_y, inner_w - 64 - gap, footer_h))
	_publish.call_deferred()


func _control_snapshot(button: Button) -> Dictionary:
	var rect: Rect2 = button.get_global_rect()
	return {"name": str(button.name), "text": button.text, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "disabled": button.disabled, "visible": button.is_visible_in_tree()}


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
	result["clear"] = _control_snapshot(clear_button)
	result["transcript"] = _control_snapshot(transcript_button)
	result["transcript_visible"] = _show_phrase or game.phase == "correct"
	return result


func _publish() -> void:
	if is_inside_tree():
		changed.emit(snapshot())
