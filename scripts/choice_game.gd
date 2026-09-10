extends Control

signal answer_chosen(word: Dictionary, correct: bool)
signal round_finished(won: bool, found_words: Array)
signal progress_changed(successes: int, mistakes: int)
signal hear_requested(word: Dictionary)
signal prompt_ready

const Style = preload("res://scripts/ui_style.gd")
const Data = preload("res://scripts/game_data.gd")
const Lesson = preload("res://scripts/word_lesson.gd")

class PlayScene:
	extends Control

	var accent: Color = Color("#438363")
	var sky: bool = true
	var arrival: float = 1.0:
		set(value):
			arrival = value
			queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		if sky:
			var drift: float = sin(arrival * PI) * 12.0
			for side in [-1, 1]:
				var cloud := Vector2(center.x + float(side) * minf(size.x * 0.37, 190.0) + drift, size.y * 0.38)
				for bubble in [Vector2(-12, 3), Vector2(0, -3), Vector2(12, 3)]:
					draw_circle(cloud + bubble, 13, accent.lightened(0.88))
				draw_line(cloud + Vector2(-15, 16), cloud + Vector2(15, 16), accent.lightened(0.62), 2.0, true)
			var ground: float = size.y - 5
			for dot in range(7):
				draw_circle(Vector2(center.x + float(dot - 3) * 13, ground), 2.5, accent.lightened(0.45))
			if arrival < 1.0:
				for dot in range(6):
					var trail := Vector2(center.x + sin(arrival * PI + dot * 0.9) * 15,
						center.y - (1.0 - arrival) * minf(size.y, 150) - float(dot) * 12)
					draw_circle(trail, 4.0 - dot * 0.4, Color(1.0, 0.78, 0.29, (1.0 - arrival) * 0.75))
		else:
			for side in [-1, 1]:
				var wave := Vector2(center.x + float(side) * minf(size.x * 0.4, 180.0), center.y)
				for bar in range(3):
					var height: float = 7.0 + float(bar % 2) * 7.0
					var x: float = wave.x + float(bar - 1) * 8
					draw_line(Vector2(x, wave.y - height), Vector2(x, wave.y + height), accent.lightened(0.4), 4, true)

var mode_id: String = "sky"
var current_target: Dictionary = {}
var choices: Array[Dictionary] = []
var found_words: Array[Dictionary] = []
var status: String = "stopped"
var successes: int = 0
var mistakes: int = 0
var reduced_motion: bool = false
var audio_available: bool = true
var suspended: bool = false
var answer_buttons: Array[Button] = []
var hear_button: Button
var feedback_view
var status_label: Label
var target_word_label: Label
var target_picture: TextureRect

var _words: Array[Dictionary] = []
var _palette: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _last_correct: bool = false
var _stage: Control
var _landing: Panel
var _art: PlayScene
var _motion: Tween
var _picture_position: Vector2
var _arrival_generation: int = 0


func _ready() -> void:
	_build()


func _build() -> void:
	if _stage != null:
		return
	custom_minimum_size = Vector2(216, 200)
	clip_contents = true
	status_label = Style.label("", 18)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.clip_text = true
	add_child(status_label)
	_stage = Control.new()
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_landing = Panel.new()
	_landing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_landing)
	_art = PlayScene.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_art)
	target_picture = TextureRect.new()
	target_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	target_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(target_picture)
	hear_button = Button.new()
	hear_button.name = "HearWord"
	hear_button.text = "Hear the word"
	hear_button.tooltip_text = "Hear the word, then choose its picture"
	_name_control(hear_button, hear_button.tooltip_text)
	hear_button.pressed.connect(_hear)
	_stage.add_child(hear_button)
	target_word_label = Style.label("", 36)
	target_word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_word_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage.add_child(target_word_label)
	for index in range(2):
		var button := Button.new()
		button.name = "Answer%d" % (index + 1)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(_choose.bind(index))
		add_child(button)
		answer_buttons.append(button)
	feedback_view = Lesson.new()
	add_child(feedback_view)
	feedback_view.finished.connect(continue_feedback)
	feedback_view.hear_requested.connect(_hear_feedback)
	feedback_view.hide()
	resized.connect(_layout)
	_layout()


func start_round(words: Array, selected_mode: String, palette: Dictionary, seed_value: int = -1) -> void:
	_build()
	stop()
	mode_id = selected_mode
	current_target = {}
	choices.clear()
	found_words.clear()
	successes = 0
	mistakes = 0
	_words.clear()
	var seen: Dictionary = {}
	for word in words:
		if word is Dictionary and word.has_all(["id", "text", "image", "audio"]) and not seen.has(word.id):
			seen[word.id] = true
			_words.append(word)
	set_palette(palette)
	progress_changed.emit(0, 0)
	if _words.size() < 5 or not mode_id in ["sky", "listen"]:
		_unavailable()
		return
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_shuffle(_words)
	_present_target()


func set_palette(palette: Dictionary) -> void:
	_build()
	_palette = palette
	for button in answer_buttons + [hear_button]:
		var focus: int = button.focus_mode
		Style.button(button, _palette.accent)
		button.focus_mode = focus
		button.add_theme_font_size_override("font_size", 28 if button != hear_button else 24)
	_landing.add_theme_stylebox_override("panel", Style.box(Color.WHITE, _palette.accent.lightened(0.45), 22, 3))
	_art.accent = _palette.accent
	_art.queue_redraw()
	status_label.add_theme_color_override("font_color", _palette.accent)
	target_word_label.add_theme_color_override("font_color", _palette.accent)
	feedback_view.set_palette(palette)
	_apply_enabled()


func set_audio_available(value: bool) -> void:
	_build()
	audio_available = value
	feedback_view.set_audio_available(value)
	if status == "asking":
		_show_question()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if feedback_view != null:
		feedback_view.set_reduced_motion(value)
	if value:
		_arrival_generation += 1
		_stop_motion()
		_layout()


func pause(value: bool) -> void:
	suspended = value
	if feedback_view != null:
		feedback_view.pause(value)
	if _motion != null and _motion.is_valid():
		if value:
			_motion.pause()
		else:
			_motion.play()
	_apply_enabled()


func stop() -> void:
	_arrival_generation += 1
	status = "stopped"
	suspended = false
	if feedback_view != null:
		feedback_view.hide()
	_stop_motion()
	_apply_enabled()


func controls() -> Array[Control]:
	var result: Array[Control] = []
	if suspended or not is_visible_in_tree():
		return result
	if status == "feedback":
		return feedback_view.controls()
	if status != "asking":
		return result
	if mode_id == "listen" and audio_available:
		result.append(hear_button)
	result.append_array(answer_buttons)
	return result


func _shuffle(items: Array) -> void:
	for index in range(items.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var item: Variant = items[index]
		items[index] = items[other]
		items[other] = item


func _present_target() -> void:
	_arrival_generation += 1
	current_target = _words[successes]
	var alternatives: Array = _words.filter(func(word: Dictionary) -> bool:
		return not Data.confusable_words(word.id, current_target.id) and word.text != current_target.text)
	if alternatives.is_empty():
		_unavailable()
		return
	choices.assign([current_target, alternatives[_rng.randi_range(0, alternatives.size() - 1)]])
	_shuffle(choices)
	status = "asking"
	_art.sky = mode_id == "sky"
	target_picture.texture = load("res://" + current_target.image)
	for index in range(2):
		var button: Button = answer_buttons[index]
		button.text = choices[index].text if mode_id == "sky" else ""
		button.icon = load("res://" + choices[index].image) if mode_id == "listen" else null
		button.tooltip_text = ("Choose " if mode_id == "sky" else "Picture: ") + choices[index].text
		_name_control(button, button.tooltip_text)
		button.remove_theme_stylebox_override("disabled")
	_show_question()
	if mode_id == "sky" and not reduced_motion and not suspended:
		_arrive_after_layout.call_deferred(_arrival_generation)
	prompt_ready.emit()


func _unavailable() -> void:
	status = "unavailable"
	choices.clear()
	status_label.text = "Choose five different words to play."
	_apply_enabled()
	_layout()


func _show_question() -> void:
	status_label.text = "Choose the matching word." if mode_id == "sky" else "Listen and choose a picture."
	if mode_id == "listen" and not audio_available:
		status_label.text = "No sound. Choose the picture."
	status_label.add_theme_color_override("font_color", _palette.accent)
	_landing.visible = mode_id == "sky"
	target_picture.visible = mode_id == "sky"
	hear_button.visible = mode_id == "listen" and audio_available
	target_word_label.visible = mode_id == "listen" and not audio_available
	target_word_label.text = current_target.text
	_apply_enabled()
	_layout()


func _arrive_after_layout(generation: int) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if generation != _arrival_generation or status != "asking" or mode_id != "sky" or reduced_motion or suspended or not is_visible_in_tree():
		return
	_stop_motion()
	target_picture.position.y -= minf(150, _stage.size.y)
	target_picture.rotation = -0.16
	_art.arrival = 0.0
	_motion = create_tween().set_parallel(true)
	_motion.tween_property(target_picture, "position", _picture_position, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(target_picture, "rotation", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_art, "arrival", 1.0, 0.9)


func _choose(index: int) -> void:
	if status != "asking" or suspended or not is_visible_in_tree() or index < 0 or index >= choices.size():
		return
	_last_correct = choices[index].id == current_target.id
	status = "feedback"
	if _last_correct:
		successes += 1
		found_words.append(current_target)
	else:
		mistakes += 1
	_stop_motion()
	feedback_view.show_words([current_target], "Yes! You found it." if _last_correct else "Let's learn this word.", "Continue")
	feedback_view.set_audio_available(audio_available)
	_apply_enabled()
	_layout()
	progress_changed.emit(successes, mistakes)
	answer_chosen.emit(choices[index], _last_correct)


func continue_feedback() -> void:
	if status != "feedback" or suspended or not is_visible_in_tree():
		return
	_stop_motion()
	if successes >= 5 or mistakes >= 3:
		status = "won" if successes >= 5 else "lost"
		_apply_enabled()
		round_finished.emit(status == "won", found_words.duplicate(true))
	elif _last_correct:
		_present_target()
	else:
		status = "asking"
		_show_question()
		prompt_ready.emit()


func _hear() -> void:
	if status == "asking" and mode_id == "listen" and audio_available and not suspended and is_visible_in_tree():
		hear_requested.emit(current_target)


func _hear_feedback(word: Dictionary) -> void:
	if status == "feedback" and audio_available and not suspended and is_visible_in_tree():
		hear_requested.emit(word)


func _apply_enabled() -> void:
	var enabled: bool = status == "asking" and not suspended
	for button in answer_buttons:
		button.visible = status == "asking"
		button.disabled = not enabled
	if hear_button != null:
		hear_button.disabled = not enabled or not audio_available
	if _stage != null:
		_stage.visible = status == "asking"
		status_label.visible = status in ["asking", "unavailable"]
	if feedback_view != null:
		feedback_view.visible = status == "feedback"


func _stop_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	for button in answer_buttons:
		button.scale = Vector2.ONE
	if target_picture != null:
		target_picture.rotation = 0.0
		target_picture.position = _picture_position
	if _art != null:
		_art.arrival = 1.0
	if hear_button != null and _stage != null:
		hear_button.position = (_stage.size - hear_button.size) * 0.5


func _layout() -> void:
	if _stage == null:
		return
	_stop_motion()
	status_label.position = Vector2.ZERO
	status_label.size = Vector2(size.x, size.y if status == "unavailable" else 24.0)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if status == "unavailable" else TextServer.AUTOWRAP_OFF
	var font: Font = status_label.get_theme_font("font")
	var font_size: int = 18
	while font_size > 14 and font.get_string_size(status_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x:
		font_size -= 1
	status_label.add_theme_font_size_override("font_size", font_size)
	feedback_view.position = Vector2.ZERO
	feedback_view.size = size
	var answer_height: float = clampf((size.y - 36.0) * 0.38, 72.0, 140.0)
	_stage.position = Vector2(0, 28)
	_stage.size = Vector2(size.x, maxf(72, size.y - 36.0 - answer_height))
	_art.size = _stage.size
	_art.queue_redraw()
	var card_size := Vector2(minf(size.x * 0.65, 240), minf(_stage.size.y, 240))
	_landing.position = (_stage.size - card_size) * 0.5
	_landing.size = card_size
	_picture_position = _landing.position + Vector2(8, 8)
	target_picture.position = _picture_position
	target_picture.size = card_size - Vector2(16, 16)
	target_picture.pivot_offset = target_picture.size * 0.5
	hear_button.size = Vector2(minf(size.x, 300), maxf(72, minf(_stage.size.y, 120)))
	hear_button.position = (_stage.size - hear_button.size) * 0.5
	target_word_label.position = Vector2.ZERO
	target_word_label.size = _stage.size
	var width: float = (size.x - 10.0) * 0.5
	for index in range(2):
		answer_buttons[index].position = Vector2(float(index) * (width + 10), size.y - answer_height)
		answer_buttons[index].size = Vector2(width, answer_height)
		answer_buttons[index].pivot_offset = answer_buttons[index].size * 0.5


func _name_control(control: Control, label: String) -> void:
	for property in control.get_property_list():
		if property.name == "accessibility_name":
			control.set("accessibility_name", label)
			return
