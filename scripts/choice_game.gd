extends Control

signal answer_chosen(word: Dictionary, correct: bool)
signal round_finished(won: bool, found_words: Array)
signal progress_changed(successes: int, mistakes: int)
signal hear_requested(word: Dictionary)
signal prompt_ready

const Style = preload("res://scripts/ui_style.gd")

class PlayScene:
	extends Control

	var accent: Color = Color("#438363")
	var sky: bool = true
	var feedback: String = ""
	var arrival: float = 1.0:
		set(value):
			arrival = value
			queue_redraw()
	var burst: float = 0.0:
		set(value):
			burst = value
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
		if feedback == "correct":
			for index in range(8):
				var angle: float = TAU * float(index) / 8.0 - PI * 0.5
				var spread: float = 0.85 + sin(burst * PI * 0.5) * 0.15
				var point: Vector2 = center + Vector2(cos(angle) * minf(size.x * 0.42, 185), sin(angle) * size.y * 0.36) * spread
				var star := PackedVector2Array()
				for corner in range(10):
					star.append(point + Vector2.UP.rotated(float(corner) * PI / 5.0) * (8.0 if corner % 2 == 0 else 3.6))
				draw_colored_polygon(star, Color("#f6b93d"))
				star.append(star[0])
				draw_polyline(star, accent, 1.2, true)
		elif feedback == "wrong":
			for side in [-1, 1]:
				var point := Vector2(center.x + float(side) * minf(size.x * 0.39, 180), size.y * 0.77)
				draw_arc(point, 10, 0, PI, 12, accent.lightened(0.15), 2.5, true)

var mode_id: String = "sky"
var current_target: Dictionary = {}
var choices: Array[Dictionary] = []
var found_words: Array[Dictionary] = []
var status: String = "stopped"
var successes: int = 0
var mistakes: int = 0
var reduced_motion: bool = false
var suspended: bool = false
var answer_buttons: Array[Button] = []
var hear_button: Button
var feedback_timer: Timer
var status_label: Label
var target_picture: TextureRect

var _words: Array[Dictionary] = []
var _palette: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _last_correct: bool = false
var _selected_index: int = -1
var _stage: Control
var _landing: Panel
var _art: PlayScene
var _motion: Tween
var _picture_position: Vector2
var _arrival_generation: int = 0


func _ready() -> void:
	_build()


func _build() -> void:
	if feedback_timer != null:
		return
	custom_minimum_size = Vector2(216, 180)
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
	for index in range(2):
		var button := Button.new()
		button.name = "Answer%d" % (index + 1)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(_choose.bind(index))
		add_child(button)
		answer_buttons.append(button)
	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.wait_time = 0.65
	feedback_timer.timeout.connect(_finish_feedback)
	add_child(feedback_timer)
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
	_selected_index = -1
	_words.clear()
	var seen: Dictionary = {}
	for word in words:
		if word is Dictionary and word.has_all(["id", "text", "image", "audio"]) and not seen.has(word.id):
			seen[word.id] = true
			_words.append(word)
	set_palette(palette)
	progress_changed.emit(0, 0)
	if _words.size() < 5 or not mode_id in ["sky", "listen"]:
		status = "unavailable"
		status_label.text = "Five different words are needed to play."
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
	var color: Color = (Style.GOOD if _last_correct else Style.WRONG) if status == "feedback" else _palette.accent
	status_label.add_theme_color_override("font_color", color)
	if status == "feedback" and _selected_index >= 0:
		answer_buttons[_selected_index].add_theme_stylebox_override("disabled", Style.box(color.lightened(0.86), color, 16, 3))
	_apply_enabled()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		_arrival_generation += 1
		_stop_motion()
		_layout()


func pause(value: bool) -> void:
	suspended = value
	if feedback_timer != null:
		feedback_timer.paused = value
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
	if feedback_timer != null:
		feedback_timer.stop()
		feedback_timer.paused = false
	_stop_motion()
	_apply_enabled()


func controls() -> Array[Control]:
	var result: Array[Control] = []
	if status != "asking" or suspended or not is_visible_in_tree():
		return result
	if mode_id == "listen":
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
	var alternatives: Array = _words.filter(func(word: Dictionary) -> bool: return word.id != current_target.id)
	choices.assign([current_target, alternatives[_rng.randi_range(0, alternatives.size() - 1)]])
	_shuffle(choices)
	status = "asking"
	_art.sky = mode_id == "sky"
	_art.feedback = ""
	status_label.text = "Which word belongs to this picture?" if mode_id == "sky" else "Listen, then choose the picture."
	status_label.add_theme_color_override("font_color", _palette.accent)
	_landing.visible = mode_id == "sky"
	target_picture.visible = mode_id == "sky"
	hear_button.visible = mode_id == "listen"
	target_picture.texture = load("res://" + current_target.image)
	for index in range(2):
		var button: Button = answer_buttons[index]
		button.text = choices[index].text if mode_id == "sky" else ""
		button.icon = load("res://" + choices[index].image) if mode_id == "listen" else null
		button.tooltip_text = ("Choose " if mode_id == "sky" else "Picture: ") + choices[index].text
		_name_control(button, button.tooltip_text)
		button.remove_theme_stylebox_override("disabled")
	_apply_enabled()
	_layout()
	if mode_id == "sky" and not reduced_motion and not suspended:
		_arrive_after_layout.call_deferred(_arrival_generation)
	prompt_ready.emit()


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
	if status != "asking" or suspended or index < 0 or index >= choices.size():
		return
	_last_correct = choices[index].id == current_target.id
	_selected_index = index
	status = "feedback"
	if _last_correct:
		successes += 1
		found_words.append(current_target)
		status_label.text = "Yes! That's the %s!" % current_target.text
	else:
		mistakes += 1
		status_label.text = "Try again. Take another look!" if mode_id == "sky" else "Try again. Listen once more!"
	var color: Color = Style.GOOD if _last_correct else Style.WRONG
	status_label.add_theme_color_override("font_color", color)
	_apply_enabled()
	answer_buttons[index].add_theme_stylebox_override("disabled", Style.box(color.lightened(0.86), color, 16, 3))
	_stop_motion()
	_art.feedback = "correct" if _last_correct else "wrong"
	_art.queue_redraw()
	if _last_correct and not reduced_motion:
		_motion = create_tween().set_parallel(true)
		_motion.tween_property(answer_buttons[index], "scale", Vector2.ONE * 1.025, 0.12)
		_motion.tween_property(_art, "burst", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_motion.chain().tween_property(answer_buttons[index], "scale", Vector2.ONE, 0.15)
	elif not reduced_motion:
		var actor: Control = target_picture if mode_id == "sky" else hear_button
		var origin: Vector2 = actor.position
		_motion = create_tween()
		_motion.tween_property(actor, "position", origin + Vector2(-5, 0), 0.09)
		_motion.tween_property(actor, "position", origin + Vector2(5, 0), 0.09)
		_motion.tween_property(actor, "position", origin, 0.09)
	feedback_timer.start()
	progress_changed.emit(successes, mistakes)
	answer_chosen.emit(choices[index], _last_correct)


func _finish_feedback() -> void:
	if status != "feedback" or suspended:
		return
	feedback_timer.stop()
	_stop_motion()
	if successes >= 5 or mistakes >= 3:
		status = "won" if successes >= 5 else "lost"
		_apply_enabled()
		round_finished.emit(status == "won", found_words.duplicate(true))
	elif _last_correct:
		_present_target()
	else:
		status = "asking"
		_art.feedback = ""
		_art.queue_redraw()
		_apply_enabled()
		prompt_ready.emit()


func _hear() -> void:
	if status == "asking" and mode_id == "listen" and not suspended:
		hear_requested.emit(current_target)


func _apply_enabled() -> void:
	var enabled: bool = status == "asking" and not suspended
	for button in answer_buttons:
		button.disabled = not enabled
	if hear_button != null:
		hear_button.disabled = not enabled


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
		_art.burst = 0.0
	if hear_button != null and _stage != null:
		hear_button.position = (_stage.size - hear_button.size) * 0.5


func _layout() -> void:
	if _stage == null:
		return
	_stop_motion()
	status_label.position = Vector2.ZERO
	status_label.size = Vector2(size.x, 24)
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
