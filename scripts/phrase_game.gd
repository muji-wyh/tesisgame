extends Control
## Listen, drag words into a phrase, and keep correcting until it is right.

signal finished
signal completion_requested
signal status_changed(message: String)
signal audio_requested(kind: String, value: String)
signal changed(snapshot: Dictionary)

const PhraseGameModel = preload("res://scripts/phrase_game_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Mascot = preload("res://scripts/duck_mascot.gd")
const AudioBar = preload("res://scripts/phrase_audio_bar.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const TILE_COLORS := [Color("#e1edf9"), Color("#f8e4cc"), Color("#ebe3f7"), Color("#dff0df"), Color("#f6dfdf"), Color("#f6edbf")]

var game := PhraseGameModel.new()
var interaction_allowed: Callable
var pip: Mascot
var option_buttons: Array[Button] = []
var answer_buttons: Array[Button] = []
var listen_button: AudioBar
var action_button: Button
var reduced_motion: bool = false
var _progress: ProgressBar
var _progress_caption: Label
var _bank_clip: Control
var _bank_content: Control
var _answer_clip: Control
var _answer_content: Control
var _answer_scroll: float = 0.0
var _answer_max_scroll: float = 0.0
var _bank_scroll: float = 0.0
var _bank_max_scroll: float = 0.0
var _scroll_start: float = 0.0
var _rail_swiping: bool = false
var _feedback: Label
var _preview: Button
var _palette: Dictionary = {}
var _theme_id: String = "spring"
var _paused: bool = false
var _finished_emitted: bool = false
var _celebrating: bool = false
var completion_pending: bool = false
var _configured: bool = false
var _muted: bool = false
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
var _drag_point: Vector2
var _dragging: bool = false
var _drop_kind: String = ""
var _drop_index: int = -1
var _settle_tween: Tween
var _reorder_tween: Tween


func _init() -> void:
	name = "PhraseBuilder"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip = Mascot.new()
	pip.name = "PhrasePip"
	pip.focus_mode = Control.FOCUS_NONE
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.set_proactive_allowed(false)
	pip.gameplay_reaction_finished.connect(_on_pip_reaction_finished)
	add_child(pip)
	_progress = ProgressBar.new()
	_progress.name = "PhraseProgress"
	_progress.max_value = PhraseGameModel.QUESTION_COUNT
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress)
	_progress_caption = _label("1 / 3", 12)
	_progress_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_caption.add_theme_color_override("font_color", Style.MUTED)
	_feedback = _label("Drag words into place.", 14)
	listen_button = AudioBar.new()
	listen_button.pressed.connect(play_prompt)
	add_child(listen_button)
	UiClick.bind_button(listen_button)
	_answer_clip = Control.new()
	_answer_clip.name = "PhraseAnswerRail"
	_answer_clip.clip_contents = true
	_answer_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_answer_clip.set("accessibility_name", "Answer words. Use Left and Right to scroll.")
	_answer_clip.focus_entered.connect(queue_redraw)
	_answer_clip.focus_exited.connect(queue_redraw)
	add_child(_answer_clip)
	_answer_content = Control.new()
	_answer_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_answer_clip.add_child(_answer_content)
	_bank_clip = Control.new()
	_bank_clip.name = "PhraseWordBank"
	_bank_clip.clip_contents = true
	_bank_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bank_clip)
	_bank_content = Control.new()
	_bank_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bank_clip.add_child(_bank_content)
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
	_celebrating = false
	completion_pending = false
	_question_id = ""
	_bank_scroll = 0.0
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
	listen_button.set_reduced_motion(value)
	if value:
		cancel_input()


func set_speaking(value: bool) -> void:
	pip.set_speaking(value and not _paused and is_visible_in_tree())
	listen_button.set_speaking(value and not _paused and is_visible_in_tree())


func set_muted(value: bool) -> void:
	if _muted == value:
		return
	_muted = value
	_refresh()


func pause(value: bool = true) -> void:
	if _paused == value:
		return
	_paused = value
	if value:
		cancel_input()
		pip.set_speaking(false)
		_celebrating = false
	pip.set_idle_paused(value)
	listen_button.set_paused(value)
	_refresh()


func resume() -> void:
	pause(false)


func stop() -> void:
	_paused = true
	_celebrating = false
	completion_pending = false
	cancel_input()
	pip.settle()
	pip.set_idle_paused(true)
	_refresh()


func cancel_input() -> void:
	var restore_answer: bool = _dragging
	_pointer = -2
	_dragging = false
	_rail_swiping = false
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
	for button in option_buttons + answer_buttons + [listen_button, action_button]:
		if is_instance_valid(button):
			button.set_pressed_no_signal(false)
	if restore_answer:
		_layout_answer()
	queue_redraw()
	_publish.call_deferred()


func _on_resized() -> void:
	cancel_input()
	_layout()
	if is_inside_tree():
		scroll_answer_to(answer_buttons.find(get_viewport().gui_get_focus_owner()))


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_input()
		pip.set_speaking(false)
		_celebrating = false
	pip.set_idle_paused(_paused or not is_visible_in_tree())
	if _configured and is_visible_in_tree():
		_refresh()
	else:
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
	if _can_interact() and not completion_pending and not game.current_question().is_empty():
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
	scroll_answer_to(game.answer.find(index))


func _remove(index: int) -> void:
	var option_index: int = game.answer[index] if index >= 0 and index < game.answer.size() else -1
	if not _can_interact() or _pointer != -2 or game.phase != "building" or not game.remove(index):
		return
	audio_requested.emit("select", "")
	_refresh()
	_restore_focus()
	scroll_bank_to(option_index)


func _activate() -> void:
	if not _can_interact() or _pointer != -2:
		return
	if completion_pending:
		return
	if _celebrating:
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
	_celebrating = correct
	completion_pending = correct and game.completed == PhraseGameModel.QUESTION_COUNT
	if not completion_pending:
		pip.react_gameplay(correct)
	audio_requested.emit("feedback", result)
	if correct:
		audio_requested.emit("phrase", str(game.current_question().id))
	_refresh()
	if completion_pending:
		completion_requested.emit()
	elif correct:
		_restore_focus()
	elif not answer_buttons.is_empty() and not answer_buttons[0].disabled:
		answer_buttons[0].grab_focus()
	else:
		_restore_focus()


func _on_pip_reaction_finished(correct: bool) -> void:
	if not correct or not _celebrating or game.phase != "correct" or not _can_interact():
		return
	_celebrating = false
	_refresh()
	action_button.grab_focus()


func accept_completion() -> void:
	# Only the host's shared invitation may accept a completed round.
	if not completion_pending or _finished_emitted or game.phase != "correct" or game.completed != PhraseGameModel.QUESTION_COUNT:
		return
	if not game.advance() or game.phase != "finished":
		return
	completion_pending = false
	_celebrating = false
	_finished_emitted = true
	_refresh()
	finished.emit()


func _input(event: InputEvent) -> void:
	if _pointer != -2 and event.is_action_pressed("ui_cancel"):
		cancel_input()
		get_viewport().set_input_as_handled()
		return
	if not _can_interact() or completion_pending:
		return
	if event is InputEventKey and event.pressed:
		var direction := Vector2.LEFT if event.is_action_pressed("ui_left") else Vector2.RIGHT if event.is_action_pressed("ui_right") else Vector2.ZERO
		if scroll_focused_answer(direction):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and (_bank_clip.get_global_rect().has_point(event.position) or _answer_clip.get_global_rect().has_point(event.position)):
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			var direction: float = -1.0 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1.0
			if _answer_clip.get_global_rect().has_point(event.position):
				_scroll_answer(_answer_scroll + direction * 96)
			else:
				_scroll_bank(_bank_scroll + direction * 96)
			get_viewport().set_input_as_handled()
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
		if option_buttons.has(candidate) and not _bank_clip.get_global_rect().has_point(point):
			continue
		if answer_buttons.has(candidate) and not _answer_clip.get_global_rect().has_point(point):
			continue
		if candidate.is_visible_in_tree() and not candidate.disabled and candidate.get_global_rect().has_point(point):
			button = candidate
			index = answer_buttons.find(candidate)
			kind = "answer" if index >= 0 else "bank"
			if index < 0:
				index = option_buttons.find(candidate)
			break
	if button == null:
		var answer_pan: bool = _answer_max_scroll > 0 and _answer_clip.get_global_rect().has_point(point)
		if answer_pan or (_bank_max_scroll > 0 and _bank_clip.get_global_rect().has_point(point)):
			cancel_input()
			_pointer = pointer
			_gesture_serial += 1
			_source_kind = "answer-scroll" if answer_pan else "bank-scroll"
			_rail_swiping = true
			_scroll_start = _answer_scroll if answer_pan else _bank_scroll
			_press_point = point
			return true
		return false
	cancel_input()
	_gesture_serial += 1
	_pointer = pointer
	_source = button
	_source_kind = kind
	_source_index = index
	_drag_word = game.answer[index] if kind == "answer" else index
	_press_point = point
	_scroll_start = _answer_scroll if kind == "answer" else _bank_scroll
	_drag_offset = get_global_transform().affine_inverse() * point - _local_rect(button).position
	button.grab_focus()
	button.set_pressed_no_signal(true)
	return true


func _move_word(point: Vector2) -> void:
	var s: float = Style.ui_scale(self)
	var movement: Vector2 = (point - _press_point) * s
	var answer_source: bool = _source_kind.begins_with("answer")
	var overflow: float = _answer_max_scroll if answer_source else _bank_max_scroll
	if not _dragging and not _rail_swiping and overflow > 0 \
		and absf(movement.x) > 8 and absf(movement.x) > absf(movement.y) * 1.2:
		_rail_swiping = true
		_source.set_pressed_no_signal(false)
	if _rail_swiping:
		if answer_source:
			_scroll_answer(_scroll_start - movement.x)
		else:
			_scroll_bank(_scroll_start - movement.x)
		return
	if not _dragging and point.distance_to(_press_point) * s < 8:
		return
	if not _dragging:
		_dragging = true
		_source.set_pressed_no_signal(false)
		_source.modulate.a = 0.0 if _source_kind == "answer" else 0.25
		_preview.text = str(game.options[_drag_word].text)
		_preview.icon = _source.icon
		_style_tile(_preview, true, false, false, s, _drag_word, _source.size.x,
			_source.get_theme_constant("icon_max_width") if _source.icon != null else 0)
		_preview.size = _source.size
		var lifted := _preview.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		lifted.shadow_color = Color(Style.INK, 0.20)
		lifted.shadow_size = ceili(12 / s)
		lifted.shadow_offset = Vector2(0, 5 / s)
		_preview.add_theme_stylebox_override("normal", lifted)
		_preview.show()
	var local: Vector2 = get_global_transform().affine_inverse() * point
	_drag_point = local
	_preview.position = local - _drag_offset - Vector2(0, (30 if _pointer >= 0 else 4) / s)
	_update_drop(local)
	queue_redraw()
	_publish.call_deferred()


func _process(delta: float) -> void:
	if not _dragging or _answer_max_scroll <= 0 or not _answer_drop.has_point(_drag_point):
		return
	var edge: float = 28 / Style.ui_scale(self)
	var direction: float = -1 if _drag_point.x < _answer_drop.position.x + edge else 1 if _drag_point.x > _answer_drop.end.x - edge else 0
	if direction != 0:
		_scroll_answer(_answer_scroll + direction * 220 * delta)
		_update_drop(_drag_point)


func _update_drop(point: Vector2) -> void:
	var previous_kind: String = _drop_kind
	var previous_index: int = _drop_index
	_drop_kind = ""
	_drop_index = -1
	if _answer_drop.has_point(point) and (game.answer.has(_drag_word) or game.answer.size() < answer_buttons.size()):
		_drop_kind = "answer"
		var order: Array[int] = game.answer.duplicate()
		order.erase(_drag_word)
		var x: float = point.x + _answer_scroll / Style.ui_scale(self)
		_drop_index = previous_index if previous_kind == "answer" else game.answer.find(_drag_word)
		if _drop_index < 0:
			# A new bank card opens a gap at the first word's midpoint it reaches.
			_drop_index = order.size()
			var rects: Array[Rect2] = _answer_rects(order)
			for index in range(order.size()):
				if x <= rects[index].get_center().x + 0.5:
					_drop_index = index
					break
		else:
			# Compare against target positions, never the moving buttons. The gap
			# creates hysteresis so a stationary pointer cannot toggle the order.
			_drop_index = mini(_drop_index, order.size())
			while _drop_index < order.size():
				var rects: Array[Rect2] = _answer_rects(_answer_order())
				if x < rects[_drop_index + 1].get_center().x - 0.5:
					break
				_drop_index += 1
			while _drop_index > 0:
				var rects: Array[Rect2] = _answer_rects(_answer_order())
				if x > rects[_drop_index - 1].get_center().x + 0.5:
					break
				_drop_index -= 1
	elif _bank_drop.has_point(point) and game.answer.has(_drag_word):
		_drop_kind = "bank"
	if previous_kind != _drop_kind or previous_index != _drop_index:
		_layout_answer(true)
		queue_redraw()
		_publish.call_deferred()


func _release_word(point: Vector2) -> void:
	if _rail_swiping:
		cancel_input()
		return
	var kind: String = _source_kind
	var source_index: int = _source_index
	var option_index: int = _drag_word
	var dragged: bool = _dragging
	var tap_inside: bool = is_instance_valid(_source) and _source.get_global_rect().has_point(point) \
		and (_bank_clip.get_global_rect().has_point(point) if _source_kind == "bank" else _answer_clip.get_global_rect().has_point(point))
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
			scroll_bank_to(option_index)
	if edited and not reduced_motion:
		var target: Button = answer_buttons[game.answer.find(option_index)] if destination == "answer" else option_buttons[option_index]
		_settle_word(from, target)


func _settle_word(from: Rect2, target: Button) -> void:
	_preview.text = target.text
	_preview.icon = target.icon
	var word_index: int = game.answer[answer_buttons.find(target)] if answer_buttons.has(target) else option_buttons.find(target)
	_style_tile(_preview, true, false, false, Style.ui_scale(self), word_index,
		target.size.x, target.get_theme_constant("icon_max_width"))
	_preview.position = from.position
	_preview.size = from.size
	_preview.show()
	target.modulate.a = 0.0
	_settle_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_settle_tween.tween_property(_preview, "position", _local_rect(target).position, 0.12)
	_settle_tween.tween_property(_preview, "size", target.size, 0.12)
	_settle_tween.chain().tween_callback(func() -> void:
		_preview.hide()
		if is_instance_valid(target):
			target.modulate = Color.WHITE
	)


func _local_rect(control: Control) -> Rect2:
	return Rect2(get_global_transform().affine_inverse() * control.global_position, control.size)


func _scroll_bank(value: float) -> void:
	_bank_scroll = clampf(value, 0.0, _bank_max_scroll)
	_bank_content.position.x = -_bank_scroll / Style.ui_scale(self)
	queue_redraw()
	_publish.call_deferred()


func _scroll_answer(value: float) -> void:
	_answer_scroll = clampf(value, 0.0, _answer_max_scroll)
	_answer_content.position.x = -_answer_scroll / Style.ui_scale(self)
	queue_redraw()
	_publish.call_deferred()


func _answer_reveal_scroll(rect: Rect2, maximum: float) -> float:
	var s: float = Style.ui_scale(self)
	var left: float = (rect.position.x - _answer_drop.position.x) * s
	var right: float = left + rect.size.x * s
	var width: float = _answer_drop.size.x * s
	return clampf(minf(left, maxf(_answer_scroll, right - width)), 0, maximum)


func scroll_answer_to(index: int) -> void:
	if index < 0 or index >= game.answer.size() or _pointer != -2:
		return
	_scroll_answer(_answer_reveal_scroll(_answer_rects(game.answer)[index], _answer_max_scroll))


func scroll_focused_answer(direction: Vector2) -> bool:
	if not _can_interact() or not _answer_clip.has_focus() or is_zero_approx(direction.x):
		return false
	_scroll_answer(_answer_scroll + direction.x * 96)
	return true


func scroll_bank_to(index: int) -> void:
	if index < 0 or index >= option_buttons.size() or _pointer != -2:
		return
	var button: Button = option_buttons[index]
	if not button.is_visible_in_tree():
		return
	var s: float = Style.ui_scale(self)
	var left: float = button.position.x * s
	var right: float = left + button.size.x * s
	var width: float = _bank_clip.size.x * s
	if left < _bank_scroll:
		_scroll_bank(left)
	elif right > _bank_scroll + width:
		_scroll_bank(right - width)


func _draw() -> void:
	if completion_pending or not _configured:
		return
	var s: float = Style.ui_scale(self)
	var accent: Color = _palette.get("accent", Style.GOOD)
	if _answer_clip.has_focus():
		var focus := Style.box(Color.TRANSPARENT, Style.INK, ceili(14 / s), ceili(2 / s))
		focus.draw(get_canvas_item(), _local_rect(_answer_clip).grow(2 / s))
	var line_y: float = _answer_drop.end.y - 2 / s
	draw_line(Vector2(_answer_drop.position.x, line_y), Vector2(_answer_drop.end.x, line_y),
		accent if _drop_kind == "answer" else Style.GOOD if game.phase == "correct" else Color("#b9cbbf"), 2 / s, true)
	if _answer_max_scroll > 0:
		var thumb: float = _answer_drop.size.x * _answer_drop.size.x / (_answer_drop.size.x + _answer_max_scroll / s)
		var left: float = _answer_drop.position.x + (_answer_drop.size.x - thumb) * _answer_scroll / _answer_max_scroll
		draw_line(Vector2(left, line_y), Vector2(left + thumb, line_y), accent, 3 / s, true)
	if _bank_max_scroll > 0:
		var rail_y: float = _bank_drop.end.y + 5 / s
		draw_line(Vector2(_bank_drop.position.x, rail_y), Vector2(_bank_drop.end.x, rail_y), Color("#e2e8de"), 3 / s, true)
		var thumb: float = _bank_drop.size.x * _bank_drop.size.x / (_bank_drop.size.x + _bank_max_scroll / s)
		var left: float = _bank_drop.position.x + (_bank_drop.size.x - thumb) * _bank_scroll / _bank_max_scroll
		draw_line(Vector2(left, rail_y), Vector2(left + thumb, rail_y), accent.lightened(0.35), 3 / s, true)
	if not _dragging or _drop_kind.is_empty():
		return
	var rect: Rect2 = _drop_rect()
	if _drop_kind == "answer":
		rect = rect.intersection(_answer_drop)
	if not rect.has_area():
		return
	var surface := Style.box(Color(accent, 0.08), accent, ceili(14 / s), ceili(2 / s))
	surface.draw(get_canvas_item(), rect.grow(3 / s))


func _answer_rects(order: Array[int]) -> Array[Rect2]:
	var s: float = Style.ui_scale(self)
	var gap: float = (6 if size.y * s < 360 or _answer_drop.size.x * s < 400 else 10) / s
	var picture: float = (28 if size.y * s < 360 else 40) / s
	var result: Array[Rect2] = []
	var cursor: float = _answer_drop.position.x
	for index in range(answer_buttons.size()):
		var text: String = str(game.options[order[index]].text) if index < order.size() else ""
		var width: float = maxf(64 / s, Style.HEADING_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(18 / s)).x + 30 / s) + picture + 8 / s if index < order.size() else 44 / s
		result.append(Rect2(cursor, _answer_drop.position.y, width, _answer_clip.size.y))
		cursor += width + gap
	return result


func _answer_order() -> Array[int]:
	# Keep edits transactional while the visible row previews their final order.
	var order: Array[int] = game.answer.duplicate()
	if _dragging and _drop_kind == "answer":
		order.erase(_drag_word)
		order.insert(mini(_drop_index, order.size()), _drag_word)
	return order


func _drop_rect() -> Rect2:
	if _drop_kind == "bank":
		return _bank_drop
	if _drop_kind != "answer":
		return Rect2()
	var rect: Rect2 = _answer_rects(_answer_order())[_drop_index]
	rect.position.x -= _answer_scroll / Style.ui_scale(self)
	return rect


func _refresh() -> void:
	var question: Dictionary = game.current_question()
	if str(question.get("id", "")) != _question_id:
		cancel_input()
		_question_id = str(question.get("id", ""))
		_bank_scroll = 0.0
		_answer_scroll = 0.0
		_rebuild_buttons()
	var correct: bool = game.phase == "correct"
	var wrong: bool = str(game.feedback) == "wrong"
	pip.set_attention("thinking" if _can_interact() and game.phase == "building" and not game.answer.is_empty() else "")
	var accent: Color = _palette.get("accent", Style.GOOD)
	for control in [listen_button, _progress, _progress_caption, _bank_clip, _answer_clip]:
		control.visible = not completion_pending
	_progress.value = game.completed
	_progress.tooltip_text = "%d of 3 phrases complete" % game.completed
	_progress.set("accessibility_name", _progress.tooltip_text)
	_progress_caption.text = "%d / 3" % mini(game.question_index + 1, 3)
	_feedback.text = "Well done!" if correct else "Try again." if wrong else "Drag words onto the line."
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_feedback.add_theme_color_override("font_color", Style.GOOD if correct else Style.WRONG if wrong else Style.MUTED)
	for index in range(option_buttons.size()):
		var button: Button = option_buttons[index]
		button.visible = not completion_pending and not game.answer.has(index)
		button.disabled = _paused or game.phase != "building" or game.answer.has(index)
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	for index in range(answer_buttons.size()):
		var button: Button = answer_buttons[index]
		var occupied: bool = index < game.answer.size()
		button.visible = not completion_pending and occupied
		button.text = str(game.options[game.answer[index]].text) if occupied else ""
		button.icon = option_buttons[game.answer[index]].icon if occupied else null
		button.disabled = _paused or not occupied or game.phase != "building"
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		button.tooltip_text = "Drag to reorder or tap to return " + button.text if occupied else "Place a word on the answer line"
		button.set("accessibility_name", "Word %d: %s" % [index + 1, button.text] if occupied else "Empty answer position %d" % (index + 1))
	listen_button.disabled = _paused or completion_pending or question.is_empty() or game.phase == "finished"
	listen_button.configure(question, _muted or correct, accent)
	listen_button.set_paused(_paused)
	action_button.visible = not completion_pending
	action_button.text = "Continue" if correct else "Check answer"
	action_button.disabled = _paused or question.is_empty() or game.phase == "finished" \
		or (completion_pending or _celebrating or (game.phase == "building" and game.answer.size() != question.get("words", []).size()))
	for button in [listen_button, action_button]:
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	_layout()
	if _configured and game.phase != "finished":
		status_changed.emit("Phrase Builder. Phrase %d of 3. %s" % [mini(game.question_index + 1, 3), _feedback.text])
	_publish.call_deferred()


func _rebuild_buttons() -> void:
	for button in option_buttons + answer_buttons:
		button.get_parent().remove_child(button)
		button.queue_free()
	option_buttons.clear()
	answer_buttons.clear()
	for index in range(game.options.size()):
		var button := _button(str(game.options[index].text), "PhraseOption_%d" % index, _choose.bind(index))
		button.icon = load("res://" + str(game.options[index].image))
		button.expand_icon = true
		button.reparent(_bank_content)
		button.focus_entered.connect(scroll_bank_to.bind(index))
		button.tooltip_text = "Drag or tap to add " + button.text
		button.mouse_default_cursor_shape = Control.CURSOR_DRAG
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.set("accessibility_name", button.text + ". Drag or press to add this word.")
		option_buttons.append(button)
	for index in range(game.current_question().get("words", []).size()):
		var button := _button("", "PhraseAnswer_%d" % index, _remove.bind(index))
		button.reparent(_answer_content)
		button.focus_entered.connect(scroll_answer_to.bind(index))
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
	if completion_pending:
		return null
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
	for button in [listen_button] + answer_buttons + option_buttons + [action_button]:
		if button.is_visible_in_tree() and not button.disabled:
			controls.append(button)
	if _answer_clip.is_visible_in_tree() and _answer_clip.focus_mode == Control.FOCUS_ALL:
		controls.append(_answer_clip)
	return controls


func _place(control: Control, rect: Rect2) -> void:
	var s: float = Style.ui_scale(self)
	control.position = rect.position / s
	control.size = rect.size.max(Vector2.ZERO) / s


func _style_tile(button: Button, filled: bool, correct: bool, wrong: bool, s: float, color_index: int, tile_width: float, icon_width: float = 0) -> void:
	if not filled:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.custom_minimum_size = Vector2.ZERO
		return
	var fill: Color = Color("#e1f0de") if correct else Color("#f9e0d7") if wrong else TILE_COLORS[posmod(color_index, TILE_COLORS.size())]
	var edge: Color = Style.GOOD if correct else Style.WRONG if wrong else fill.darkened(0.18)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var surface := Style.box(fill.darkened(0.04) if state == "pressed" else fill, edge, ceili(14 / s), maxi(1, roundi(1 / s)))
		surface.set_content_margin_all(6 / s)
		surface.border_width_bottom = ceili((1 if state == "pressed" else 3) / s)
		if state == "hover":
			surface.border_color = edge.darkened(0.15)
		button.add_theme_stylebox_override(state, surface)
	button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Style.INK, ceili(14 / s), ceili(2 / s)))
	button.add_theme_font_override("font", Style.HEADING_FONT)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(color, Style.INK)
	button.custom_minimum_size = Vector2.ZERO
	button.clip_text = true
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", ceili(icon_width))
	button.add_theme_constant_override("h_separation", ceili(8 / s))
	var text_width: float = tile_width - 14 / s
	if button.icon != null:
		text_width -= icon_width + 8 / s
	var font_size: int = ceili(18 / s)
	while font_size > ceili(12 / s) and Style.HEADING_FONT.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > text_width:
		font_size -= 1
	button.add_theme_font_size_override("font_size", font_size)


func _layout_answer(animate: bool = false) -> void:
	if not _answer_drop.has_area():
		return
	if is_instance_valid(_reorder_tween):
		_reorder_tween.kill()
	var s: float = Style.ui_scale(self)
	var order: Array[int] = _answer_order()
	var rects: Array[Rect2] = _answer_rects(order)
	var picture_w: float = (28 if size.y * s < 360 else 40) / s
	for index in range(answer_buttons.size()):
		var button: Button = answer_buttons[index]
		var occupied: bool = index < game.answer.size()
		var slot: int = order.find(game.answer[index]) if occupied else index
		var rect: Rect2 = rects[slot]
		_style_tile(button, occupied, game.phase == "correct", str(game.feedback) == "wrong", s,
			game.answer[index] if occupied else 0, rect.size.x, picture_w)
		var target: Vector2 = rect.position - _answer_drop.position
		if animate and not reduced_motion and occupied and button != _source and not button.position.is_equal_approx(target):
			if not is_instance_valid(_reorder_tween) or not _reorder_tween.is_valid():
				_reorder_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_reorder_tween.tween_property(button, "position", target, 0.12)
		else:
			button.position = target
		button.size = rect.size
	if is_instance_valid(_reorder_tween) and _reorder_tween.is_valid():
		_reorder_tween.chain().tween_callback(_publish)
	var content_w: float = maxf(_answer_drop.size.x, rects[order.size() - 1].end.x - _answer_drop.position.x) if not order.is_empty() else _answer_drop.size.x
	_answer_max_scroll = maxf(0, content_w - _answer_drop.size.x) * s
	_answer_clip.focus_mode = Control.FOCUS_ALL if game.phase == "correct" and not _paused and _answer_max_scroll > 0 else Control.FOCUS_NONE
	_answer_content.size = Vector2(content_w, _answer_clip.size.y)
	_scroll_answer(_answer_scroll)


func _layout() -> void:
	if not is_instance_valid(action_button) or size.x <= 0 or size.y <= 0:
		return
	var s: float = Style.ui_scale(self)
	var w: float = size.x * s
	var h: float = size.y * s
	var accent: Color = _palette.get("accent", Style.GOOD)
	Style.action_button(action_button, Style.GOOD if game.phase == "correct" else accent, true)
	action_button.custom_minimum_size = Vector2.ZERO
	action_button.add_theme_font_size_override("font_size", ceili(16 / s))
	var compact: bool = h < 360
	var inner_w: float = minf(w, 820)
	var x: float = (w - inner_w) * 0.5
	var gap: float = 6 if compact else 24
	var progress_h: float = 14 if compact else 24
	var hero_h: float = 48 if compact else minf(64 if w < 400 else 112, h * 0.18)
	var tile_h: float = 44 if compact else 58
	var answer_h: float = tile_h + (8 if compact else 12)
	var footer_h: float = 44 if compact else 50
	var total_h: float = progress_h + hero_h + answer_h + tile_h + 8 + footer_h + gap * 4
	var top: float = maxf(0, (h - total_h) * 0.38)
	_progress.add_theme_stylebox_override("background", Style.box(Color("#e1e9dd"), Color.TRANSPARENT, ceili(5 / s), 0))
	_progress.add_theme_stylebox_override("fill", Style.box(accent, Color.TRANSPARENT, ceili(5 / s), 0))
	for state in ["background", "fill"]:
		_progress.get_theme_stylebox(state).set_content_margin_all(0)
	_place(_progress, Rect2(x, top + (progress_h - 7) * 0.5, inner_w - 52, 7))
	_progress_caption.add_theme_font_size_override("font_size", ceili(11 / s))
	_place(_progress_caption, Rect2(x + inner_w - 44, top, 44, maxf(18, progress_h)))
	var hero_y: float = top + progress_h + gap
	var pip_side: float = minf(hero_h, 64 if w < 400 else 112)
	pip.custom_minimum_size = Vector2.ZERO
	_place(pip, Rect2(x, hero_y + (hero_h - pip_side) * 0.5, pip_side, pip_side))
	var audio_x: float = x + pip_side + 12
	var audio_h: float = minf(56, hero_h)
	var audio_w: float = minf(360, inner_w - pip_side - 12)
	_place(listen_button, Rect2(audio_x, hero_y + (hero_h - audio_h) * 0.5, audio_w, audio_h))
	var answer_y: float = hero_y + hero_h + gap
	_answer_drop = Rect2(Vector2(x, answer_y) / s, Vector2(inner_w, answer_h) / s)
	_place(_answer_clip, Rect2(x, answer_y, inner_w, tile_h))
	var picture_w: float = 28 if compact else 40
	_layout_answer()
	var bank_y: float = answer_y + answer_h + gap
	_place(_bank_clip, Rect2(x, bank_y, inner_w, tile_h))
	var cursor: float = 0
	for index in range(option_buttons.size()):
		var button: Button = option_buttons[index]
		if not button.visible:
			continue
		var word_w: float = maxf(64, Style.HEADING_FONT.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(18 / s)).x * s + 30) + picture_w + 8
		# Finalize font and style minimums before assigning the rail's exact card size.
		_style_tile(button, true, false, false, s, index, word_w / s, picture_w / s)
		_place(button, Rect2(cursor, 0, word_w, tile_h))
		cursor += word_w + 10
	var content_w: float = maxf(inner_w, cursor - 10)
	_bank_max_scroll = maxf(0, content_w - inner_w)
	_bank_content.size = Vector2(content_w, tile_h) / s
	_bank_scroll = clampf(_bank_scroll, 0, _bank_max_scroll)
	_bank_content.position = Vector2(-_bank_scroll / s, 0)
	_bank_drop = Rect2(Vector2(x, bank_y) / s, Vector2(inner_w, tile_h) / s)
	var footer_y: float = bank_y + tile_h + 8 + gap
	var action_w: float = minf(184, inner_w)
	_place(action_button, Rect2(x + inner_w - action_w, footer_y, action_w, footer_h))
	_feedback.visible = inner_w - action_w > 175 or game.feedback in ["wrong", "correct"]
	_feedback.add_theme_font_size_override("font_size", ceili(13 / s))
	_place(_feedback, Rect2(x, footer_y, maxf(0, inner_w - action_w - 12), footer_h))
	queue_redraw()
	_publish.call_deferred()


func _rect_snapshot(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _control_snapshot(button: Button) -> Dictionary:
	return {"name": str(button.name), "text": button.text, "icon": button.icon.resource_path if button.icon != null else "", "rect": _rect_snapshot(button.get_global_rect()), "disabled": button.disabled, "visible": button.is_visible_in_tree(), "accessibility_name": button.get("accessibility_name")}


func snapshot() -> Dictionary:
	var result: Dictionary = game.snapshot()
	result["visible"] = is_visible_in_tree()
	result["paused"] = _paused
	result["celebrating"] = _celebrating
	result["completion_pending"] = completion_pending
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
	result["prompt_text_visible"] = not completion_pending and (_muted or game.phase == "correct")
	result["prompt_layout"] = listen_button.transcript_layout()
	result["progress"] = {"value": game.completed, "total": PhraseGameModel.QUESTION_COUNT, "rect": _rect_snapshot(_progress.get_global_rect()), "visible": _progress.is_visible_in_tree()}
	result["bank"] = {"rect": _rect_snapshot(_bank_clip.get_global_rect()), "scroll": _bank_scroll, "max_scroll": _bank_max_scroll}
	result["answer_rail"] = {"rect": _rect_snapshot(_answer_clip.get_global_rect()), "scroll": _answer_scroll, "max_scroll": _answer_max_scroll}
	result["answer_drop"] = _rect_snapshot(Rect2(_answer_drop.position + global_position, _answer_drop.size))
	result["bank_drop"] = _rect_snapshot(Rect2(_bank_drop.position + global_position, _bank_drop.size))
	result["dragging"] = _dragging
	result["drag_word"] = str(game.options[_drag_word].id) if _drag_word >= 0 and _drag_word < game.options.size() else ""
	result["drop_kind"] = _drop_kind
	result["drop_index"] = _drop_index
	var landing: Rect2 = _drop_rect()
	result["drop_rect"] = _rect_snapshot(Rect2(landing.position + global_position, landing.size)) if landing.has_area() else []
	return result


func _publish() -> void:
	if is_inside_tree():
		changed.emit(snapshot())
