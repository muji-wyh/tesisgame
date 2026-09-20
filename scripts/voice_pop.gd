extends Control

signal request_listening
signal exit_requested
signal hit(word: Dictionary)
signal round_finished(summary: Dictionary)
signal hear_requested(word: Dictionary)
signal report_requested(text: String)
signal pip_report_requested(text: String)
signal status_changed(snapshot: Dictionary)

const Style = preload("res://scripts/ui_style.gd")
const PopModel = preload("res://scripts/voice_pop_model.gd")
const Duck = preload("res://scripts/duck_mascot.gd")
const NAVY := Color("#080e23")
const SURFACE := Color("#16203c")
const CYAN := Color("#57edff")
const PINK := Color("#ff6cce")
const VIOLET := Color("#a48aff")
const WHITE := Color("#f5f7ff")
const SOFT := Color("#a8b9dc")
const NEON := [CYAN, PINK, VIOLET]
const CARD_COLORS := [
	Color("#72dff3"), Color("#ffa1cb"), Color("#ffdc70"),
	Color("#bfa3ff"), Color("#80e3bb"), Color("#ffb77d")
]

var game = PopModel.new()
var reduced_motion: bool = false
var pip: Button
var replay_button: Button
var back_button: Button
var retry_button: Button
var time_label: Label
var score_label: Label
var hits_label: Label
var prompt_label: Label
var transcript_label: Label
var report_button: Button
var next_report_button: Button

var _words: Array = []
var _palette: Dictionary = {}
var _seed: int = -1
var _textures: Dictionary = {}
var _enabled: bool = false
var _listening: bool = false
var _listening_tick_usec: int = -1
var _message: String = "Allow microphone access to start."
var _finished_sent: bool = false
var _stopped: bool = true
var _pending: bool = false
var _pending_left: float = 0.0
var _reconnecting: bool = false
var _clock: float = 0.0
var _publish_key: String = ""
var _geometry_publish_pending: bool = false
var _last_target_ids: String = ""
var _last_hit: String = ""
var _last_hit_left: float = 0.0
var _transcript: String = ""
var _transcript_final: bool = false
var _report_step: int = 0
var _report_feedback: String = ""
var _report_pages: Array[Dictionary] = []
var _report_prompts: Dictionary = {}
var _report_audio_state: String = "idle"
var _bursts: Array[Dictionary] = []
var _draw_targets: Array[Dictionary] = []
var _arena: Rect2
var _hud: Control
var _time_caption: Label
var _score_caption: Label
var _mode_caption: Label
var _live_caption: Label
var _gate: ScrollContainer
var _gate_body: VBoxContainer
var _gate_title: Label
var _gate_copy: Label
var _gate_note: Label
var _gate_icon: Label
var _gate_privacy: Label
var _gate_actions: HBoxContainer
var _gate_back: Button
var _results: ScrollContainer
var _result_body: VBoxContainer
var _result_heading: Label
var _pip_caption: Label
var _report_kicker: Label
var _report_actions: HBoxContainer
var _stats: GridContainer
var _result_actions: HBoxContainer
var _review_grids: Array[GridContainer] = []
var _review_buttons: Array[Button] = []


func _ready() -> void:
	_build()
	_layout()


func _build() -> void:
	if _hud != null:
		return
	name = "VoicePop"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hud = Control.new()
	_hud.name = "ArenaHUD"
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	time_label = _label("30", 30)
	time_label.name = "Time"
	_time_caption = _label("SECONDS", 10, SOFT)
	score_label = _label("0", 27)
	score_label.name = "Score"
	_score_caption = _label("SCORE", 10, SOFT)
	_mode_caption = _label("VOICE POP", 10, CYAN)
	hits_label = _label("0 hits", 18)
	hits_label.name = "Hits"
	prompt_label = _label("Say what you see", 20)
	prompt_label.name = "Prompt"
	transcript_label = _label("", 17)
	transcript_label.name = "LiveTranscript"
	transcript_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	transcript_label.max_lines_visible = 2
	transcript_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	transcript_label.hide()
	_live_caption = _label("LISTENING", 10, CYAN)
	for item in [time_label, _time_caption, score_label, _score_caption, _mode_caption, hits_label, prompt_label, transcript_label, _live_caption]:
		_hud.add_child(item)
	_gate = ScrollContainer.new()
	_gate.name = "MicrophoneGate"
	_gate.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_gate.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_gate)
	_gate_body = VBoxContainer.new()
	_gate_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gate.add_child(_gate_body)
	_gate_icon = _label("VOICE POP", 15, CYAN)
	_gate_title = _label("Ready to pop?", 30)
	_gate_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gate_copy = _label(_message, 17, WHITE)
	_gate_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gate_note = _label("30 seconds. See it. Say it. Pop it!", 14, SOFT)
	_gate_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for item in [_gate_icon, _gate_title, _gate_copy, _gate_note]:
		_gate_body.add_child(item)
	_gate_actions = HBoxContainer.new()
	_gate_body.add_child(_gate_actions)
	retry_button = _action("Start listening", true)
	retry_button.name = "RetryListening"
	retry_button.pressed.connect(func() -> void: request_listening.emit())
	_gate_back = _action("Back")
	_gate_back.pressed.connect(_exit)
	_gate_actions.add_child(retry_button)
	_gate_actions.add_child(_gate_back)
	_gate_privacy = _label("Browser speech may process audio remotely. Game stores no voice or transcripts.", 11, SOFT)
	_gate_privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gate_body.add_child(_gate_privacy)
	_results = ScrollContainer.new()
	_results.name = "PopResults"
	_results.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_results.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_results.follow_focus = true
	add_child(_results)
	_result_body = VBoxContainer.new()
	_result_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results.add_child(_result_body)
	_results.hide()
	_results.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _queue_geometry_publish())
	_gate.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _queue_geometry_publish())
	for container in [_gate, _gate_body, _results, _result_body]:
		container.resized.connect(_queue_geometry_publish)
	_gate.visibility_changed.connect(_queue_geometry_publish)
	_results.visibility_changed.connect(_queue_geometry_publish)
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	_layout()


func configure(words: Array, palette: Dictionary, motion_reduced: bool = false, seed_value: int = -1) -> void:
	_build()
	_words = words.duplicate(true)
	_palette = palette.duplicate()
	_seed = seed_value
	game.configure(_words, seed_value)
	_enabled = false
	_listening = false
	_listening_tick_usec = -1
	_finished_sent = false
	_stopped = false
	_pending = false
	_reconnecting = false
	_publish_key = ""
	_last_target_ids = ""
	_last_hit = ""
	_last_hit_left = 0.0
	_clear_transcript()
	set_report_speaking(false)
	_report_step = 0
	_report_feedback = ""
	_report_pages.clear()
	_bursts.clear()
	_draw_targets.clear()
	_message = "Allow microphone access to start." if not _words.is_empty() else "Choose a world with words to play."
	_gate_title.text = "Ready to pop?"
	_gate_copy.text = _message
	_gate_note.text = "Your 30 seconds start when Pip can hear you."
	retry_button.text = "Start listening"
	retry_button.disabled = _words.is_empty()
	_gate.show()
	_results.hide()
	_hud.hide()
	_gate.scroll_vertical = 0
	set_reduced_motion(motion_reduced)
	set_process(is_visible_in_tree())
	_layout()
	_publish(true)


func set_listening(enabled: bool, listening: bool, message: String) -> void:
	_build()
	var was_running: bool = _listening and game.phase == "running"
	if was_running and not listening:
		_sync_game_clock()
	_enabled = enabled
	_listening = listening
	_message = message
	if _finished_sent:
		_listening = false
		_listening_tick_usec = -1
		if not _stopped:
			_message = report_text()
		_publish(true)
		return
	if listening:
		_pending = false
		_reconnecting = false
		if game.phase == "ready":
			game.start()
		elif game.phase == "paused":
			game.resume()
		if not was_running or _listening_tick_usec < 0:
			_listening_tick_usec = Time.get_ticks_usec()
		_gate.hide()
		_results.hide()
		_hud.show()
	else:
		_listening_tick_usec = -1
		_clear_transcript()
		var transient: bool = enabled and _pending_message(message)
		_pending = transient
		_pending_left = 10.0 if transient else 0.0
		_reconnecting = transient and game.phase in ["running", "paused"]
		if game.phase == "running":
			game.pause()
		_gate_title.text = "Opening microphone…" if transient else "Round paused" if game.phase == "paused" else "Ready to pop?"
		_gate_copy.text = message if not message.is_empty() else "Allow microphone access to start."
		_gate_note.text = "%d seconds left. Your progress is safe." % ceili(game.remaining) if game.phase == "paused" else "Your 30 seconds start when Pip can hear you."
		retry_button.text = "Waiting…" if transient else "Retry listening" if game.phase == "paused" or not message.is_empty() else "Start listening"
		retry_button.disabled = _words.is_empty() or transient
		_gate.visible = not _reconnecting
		_hud.visible = _reconnecting
	_layout()
	_refresh_targets()
	_publish(true)
	queue_redraw()


func show_transcript(text: String, is_final: bool) -> void:
	# Full browser hypotheses are presentation only. Scoring keeps its separate,
	# deduplicated word callback, so updating an interim sentence cannot score twice.
	if not _listening or game.phase != "running" or not is_visible_in_tree():
		return
	_sync_game_clock()
	if game.phase != "running":
		return
	_transcript = text.strip_edges().replace("\n", " ").replace("\r", " ").right(2000)
	_transcript_final = is_final
	transcript_label.text = _transcript
	_update_transcript_window()
	_update_hud()
	_publish(true)


func _clear_transcript() -> void:
	_transcript = ""
	_transcript_final = false
	if transcript_label != null:
		transcript_label.text = ""
		transcript_label.hide()
		prompt_label.show()


func _update_transcript_window() -> void:
	transcript_label.lines_skipped = 0
	# Keep the newest words in view during a long, continuously revised sentence.
	transcript_label.lines_skipped = maxi(0, transcript_label.get_line_count() - 2)


func receive_transcript(text: String) -> void:
	if not _listening or game.phase != "running" or not is_visible_in_tree():
		return
	_sync_game_clock()
	if game.phase != "running":
		return
	_refresh_targets()
	var struck: Array = game.hit_transcript(text)
	for target in struck:
		var visual: Dictionary = {}
		for item in _draw_targets:
			if int(item.uid) == int(target.uid):
				visual = item
		if not visual.is_empty():
			_bursts.append({"center": visual.center, "radius": float(visual.size.x) * 0.48,
				"age": 0.0, "color": _card_color(int(target.uid)), "points": int(target.get("points", 100))})
		_last_hit = "+%d" % int(target.get("points", 100))
		if int(target.get("combo", 0)) > 1:
			_last_hit += "  ·  %d× COMBO" % int(target.combo)
		_last_hit_left = 1.15
		hit.emit(target.word)
	_refresh_targets()
	_update_hud()
	_publish(true)
	queue_redraw()


func pause() -> void:
	if _finished_sent:
		_listening_tick_usec = -1
		return
	_sync_game_clock()
	if _finished_sent:
		return
	_listening = false
	_listening_tick_usec = -1
	_clear_transcript()
	_pending = false
	_reconnecting = false
	if game.phase == "running":
		game.pause()
	_message = "Listening paused. Tap Retry to keep popping."
	if _gate != null:
		_gate_title.text = "Round paused" if game.phase == "paused" else "Ready to pop?"
		_gate_copy.text = _message
		_gate_note.text = "%d seconds left. Your progress is safe." % ceili(game.remaining)
		retry_button.text = "Retry listening"
		_gate.show()
		_hud.hide()
		_layout()
	_publish(true)
	queue_redraw()


func stop() -> void:
	_clear_transcript()
	set_report_speaking(false)
	_listening = false
	_listening_tick_usec = -1
	_enabled = false
	_finished_sent = true
	_stopped = true
	_pending = false
	_reconnecting = false
	_message = ""
	game.stop()
	_bursts.clear()
	_draw_targets.clear()
	set_process(false)
	_publish(true)
	queue_redraw()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		_bursts.clear()
	if pip != null and is_instance_valid(pip):
		pip.set_reduced_motion(value)
	_refresh_targets()
	queue_redraw()


func controls() -> Array[Control]:
	var result: Array[Control] = []
	if not is_visible_in_tree():
		return result
	if _gate != null and _gate.visible:
		if not retry_button.disabled:
			result.append(retry_button)
		result.append(_gate_back)
	elif _results != null and _results.visible:
		if pip != null and is_instance_valid(pip):
			result.append(pip)
		result.append(report_button)
		result.append(next_report_button)
		result.append(replay_button)
		result.append(back_button)
		for button in _review_buttons:
			result.append(button)
	return result


func default_focus() -> Control:
	if _results != null and _results.visible:
		return replay_button
	if _gate != null and _gate.visible:
		return _gate_back if retry_button.disabled else retry_button
	return null


func snapshot() -> Dictionary:
	_refresh_targets()
	var targets: Array[Dictionary] = []
	for target in _draw_targets:
		var rect: Rect2 = _global_target_rect(target)
		targets.append({"uid": target.uid, "text": str(target.word.get("text", "")), "forms": target.get("forms", []),
			"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y})
	var actions: Array[Dictionary] = []
	var candidates: Array[Control] = controls()
	if _gate != null and _gate.visible and retry_button.disabled:
		candidates.push_front(retry_button)
	for control in candidates:
		var rect: Rect2 = control.get_global_rect()
		var visible_rect: Rect2 = _gate.get_global_rect() if _gate.visible else _results.get_global_rect()
		if not visible_rect.encloses(rect):
			continue
		actions.append({"name": str(control.name), "text": str(control.text) if control is Button else "",
			"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y,
			"disabled": bool(control.disabled) if control is BaseButton else false})
	return {"phase": "idle" if _stopped else str(game.phase), "remaining": float(game.remaining), "hits": int(game.hits),
		"score": int(game.score), "best_combo": int(game.best_combo), "targets": targets,
		"controls": actions, "message": _message, "listening": _listening, "enabled": _enabled,
		"transcript": _transcript, "transcript_final": _transcript_final,
		"report": report_text() if game.phase == "finished" and not _stopped else "", "report_step": _report_step,
		"report_speaking": _report_audio_state == "speaking", "report_loading": _report_audio_state == "loading",
		"report_audio": report_audio(),
		"results_scroll": _results.scroll_vertical,
		"results_scroll_max": maxf(0.0, _results.get_v_scroll_bar().max_value - _results.get_v_scroll_bar().page),
		"results_scrollbar_visible": _results.get_v_scroll_bar().is_visible_in_tree()}


func _publish(force: bool = false) -> void:
	var ids: PackedStringArray = []
	for target in game.targets:
		ids.append(str(target.uid))
	var key: String = "%s/%d/%d/%d/%s/%s/%s" % [game.phase, ceili(game.remaining), game.hits, game.score, ",".join(ids), _listening, _message]
	if force or key != _publish_key:
		_publish_key = key
		status_changed.emit(snapshot())


func _queue_geometry_publish() -> void:
	if _geometry_publish_pending or not is_inside_tree():
		return
	_geometry_publish_pending = true
	_publish_settled_geometry()


func _publish_settled_geometry() -> void:
	# Nested containers sort after their parent size changes. A plain deferred
	# callback can precede that second sort and publish empty action bounds forever.
	await get_tree().process_frame
	await get_tree().process_frame
	_geometry_publish_pending = false
	if is_inside_tree():
		_publish(true)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_listening_tick_usec = -1
		return
	if not reduced_motion:
		_clock += delta
	if _pending:
		_pending_left = maxf(0.0, _pending_left - delta)
		if _pending_left <= 0.0:
			set_listening(_enabled, false, "Still waiting for the microphone. Check the browser prompt, or retry.")
	_sync_game_clock()
	_last_hit_left = maxf(0.0, _last_hit_left - delta)
	for index in range(_bursts.size() - 1, -1, -1):
		_bursts[index].age = float(_bursts[index].age) + delta
		if float(_bursts[index].age) > (0.35 if reduced_motion else 0.75):
			_bursts.remove_at(index)
	_refresh_targets()
	_update_hud()
	_publish()
	queue_redraw()


func _sync_game_clock() -> void:
	if not _listening or game.phase != "running":
		_listening_tick_usec = -1
		return
	var now: int = Time.get_ticks_usec()
	if _listening_tick_usec < 0:
		_listening_tick_usec = now
		return
	var elapsed: float = maxf(0.0, float(now - _listening_tick_usec) / 1000000.0)
	_listening_tick_usec = now
	_advance_game(elapsed)


func _advance_game(elapsed_seconds: float) -> void:
	# Keep simulation directly tickable in scene tests. Production supplies real
	# monotonic time because Godot can clamp frame delta under slow Web rendering.
	if not _listening or game.phase != "running":
		return
	game.advance(elapsed_seconds)
	if game.phase == "finished" and not _finished_sent:
		_finish()
	_refresh_targets()
	_update_hud()
	_publish()
	queue_redraw()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		set_report_speaking(false)
		if game.phase == "running":
			pause()
		_listening_tick_usec = -1
		set_process(false)
	else:
		set_process(true)
		_layout()


func _update_hud() -> void:
	if time_label == null:
		return
	time_label.text = "%02d" % ceili(maxf(0.0, game.remaining))
	time_label.add_theme_color_override("font_color", PINK if game.remaining <= 5.0 else WHITE)
	score_label.text = str(game.score)
	hits_label.text = "%d %s" % [game.hits, "hit" if game.hits == 1 else "hits"]
	transcript_label.visible = not _transcript.is_empty()
	prompt_label.visible = _transcript.is_empty()
	_live_caption.text = "RECONNECTING · TIMER PAUSED" if _reconnecting else _last_hit if _last_hit_left > 0.0 else "LISTENING · SPEAK TO POP"
	if not _transcript.is_empty() and _last_hit_left <= 0.0 and not _reconnecting:
		_live_caption.text = "HEARD YOU · KEEP GOING" if _transcript_final else "HEARING YOU…"
	if game.phase == "running" and game.targets.is_empty() and game.remaining < 3.0:
		_live_caption.text = "NICE POPPING · ROUND ENDING"
	_live_caption.add_theme_color_override("font_color", PINK if _last_hit_left > 0.0 else CYAN)


func _layout() -> void:
	if _hud == null:
		return
	var scale: float = Style.ui_scale(self)
	_rescale_content(self, scale)
	custom_minimum_size = Vector2(180, 160) / scale
	var edge: float = 16.0 / scale
	var width: float = maxf(0.0, size.x - edge * 2.0)
	var short: bool = size.y * scale < 350.0
	_hud.position = Vector2.ZERO
	_hud.size = size
	var side: float = minf(86.0 / scale, width * 0.28)
	_place_label(time_label, Rect2(edge, 12 / scale, side, 33 / scale), 29)
	_place_label(_time_caption, Rect2(edge, 43 / scale, side, 16 / scale), 9)
	_place_label(score_label, Rect2(size.x - edge - side, 12 / scale, side, 33 / scale), 25)
	_place_label(_score_caption, Rect2(size.x - edge - side, 43 / scale, side, 16 / scale), 9)
	_place_label(_mode_caption, Rect2(edge + side, 15 / scale, width - side * 2, 16 / scale), 10)
	_place_label(hits_label, Rect2(edge + side, 31 / scale, width - side * 2, 26 / scale), 17)
	var speech_top: float = (59.0 if short else 65.0) / scale
	var speech_height: float = (36.0 if short else 44.0) / scale
	_place_label(prompt_label, Rect2(edge, speech_top, width, speech_height), 17 if short else 20)
	_place_label(transcript_label, Rect2(edge, speech_top, width, speech_height), 14 if short else 17)
	# Font ascent/descent and line spacing can exceed the nominal font size.
	# Reserve two actual lines instead of clipping the second at some UI scales.
	speech_height = maxf(speech_height, 2.0 * transcript_label.get_line_height() + transcript_label.get_theme_constant("line_spacing"))
	transcript_label.size.y = speech_height
	prompt_label.size.y = speech_height
	_update_transcript_window()
	_place_label(_live_caption, Rect2(edge, speech_top + speech_height, width, 17 / scale), 10)
	var top: float = speech_top + speech_height + 25.0 / scale
	_arena = Rect2(edge, top, width, maxf(64.0 / scale, size.y - top - 18.0 / scale))
	var gate_width: float = minf(width - 8.0 / scale, 420.0 / scale)
	var gate_top: float = maxf(18.0 / scale, (size.y - 290.0 / scale) * 0.5)
	_gate.position = Vector2((size.x - gate_width) * 0.5, gate_top)
	_gate.size = Vector2(gate_width, maxf(48.0 / scale, size.y - gate_top - 18.0 / scale))
	_gate_body.add_theme_constant_override("separation", ceili(10.0 / scale))
	_gate_icon.custom_minimum_size.y = 18.0 / scale
	_gate_title.add_theme_font_size_override("font_size", ceili(30.0 / scale))
	_gate_icon.add_theme_font_size_override("font_size", ceili(13.0 / scale))
	_gate_copy.add_theme_font_size_override("font_size", ceili(17.0 / scale))
	_gate_note.add_theme_font_size_override("font_size", ceili(13.0 / scale))
	_gate_title.custom_minimum_size.y = 38.0 / scale
	_gate_copy.custom_minimum_size.y = 44.0 / scale
	_gate_note.custom_minimum_size.y = 32.0 / scale
	_gate_privacy.add_theme_font_size_override("font_size", ceili(11.0 / scale))
	_gate_privacy.custom_minimum_size.y = 36.0 / scale
	_gate_actions.add_theme_constant_override("separation", ceili(10.0 / scale))
	_style_action(retry_button, true)
	_style_action(_gate_back)
	var result_width: float = minf(width - 8.0 / scale, 760.0 / scale)
	_results.position = Vector2((size.x - result_width) * 0.5, edge)
	_results.size = Vector2(result_width, maxf(0.0, size.y - edge * 2.0))
	_result_body.add_theme_constant_override("separation", ceili(8.0 / scale))
	if _report_actions != null and is_instance_valid(_report_actions):
		_report_actions.add_theme_constant_override("separation", ceili(8.0 / scale))
		_style_action(report_button)
		_style_action(next_report_button)
		for button in [report_button, next_report_button]:
			button.custom_minimum_size.y = 44.0 / scale
	if _stats != null and is_instance_valid(_stats):
		_stats.columns = 4 if result_width * scale >= 480.0 else 2
		_stats.add_theme_constant_override("h_separation", ceili(8.0 / scale))
		_stats.add_theme_constant_override("v_separation", ceili(8.0 / scale))
	if _result_actions != null and is_instance_valid(_result_actions):
		# Keep the main actions above the statistics on compact screens: longer
		# coaching sentences must not push Replay and Back across the scroll edge.
		var action_index: int = 2 if size.y * scale < 460.0 else 3
		if _result_actions.get_index() != action_index:
			_result_body.move_child(_result_actions, action_index)
		_result_actions.add_theme_constant_override("separation", ceili(10.0 / scale))
		_style_action(replay_button, true)
		_style_action(back_button)
	for grid in _review_grids:
		grid.columns = 3 if result_width * scale >= 650.0 else 2 if result_width * scale >= 360.0 else 1
		grid.add_theme_constant_override("h_separation", ceili(8.0 / scale))
		grid.add_theme_constant_override("v_separation", ceili(8.0 / scale))
	for button in _review_buttons:
		button.custom_minimum_size = Vector2(0.0, 66.0 / scale)
	_refresh_targets()
	queue_redraw()
	_queue_geometry_publish()


func _refresh_targets() -> void:
	_draw_targets.clear()
	if _arena.size.x <= 0.0 or _arena.size.y <= 0.0 or game.phase not in ["running", "paused"]:
		return
	var scale: float = Style.ui_scale(self)
	var capsule_width: float = clampf(minf(_arena.size.x * 0.43, _arena.size.y * 0.57), 112.0 / scale, 202.0 / scale)
	var capsule_height: float = minf(clampf(capsule_width * 0.83, 96.0 / scale, 162.0 / scale), _arena.size.y - 4.0 / scale)
	var capsule_size := Vector2(capsule_width, capsule_height)
	var room: float = maxf(0.0, _arena.size.x - capsule_width - 12.0 / scale)
	for target in game.targets:
		_cache_texture(target.word)
		var progress: float = clampf(float(target.age) / maxf(0.1, float(target.lifetime)), 0.0, 1.0)
		var lane: int = int(target.get("lane", int(target.uid) % 3))
		var unit_x: float = lerpf(float(target.x_start), float(target.x_end), progress)
		var x: float = _arena.position.x + capsule_width * 0.5 + 6.0 / scale + room * clampf((unit_x - 0.2) / 0.6, 0.0, 1.0)
		var bottom: float = _arena.end.y - capsule_height * 0.5 - 4.0 / scale
		var highest: float = _arena.position.y + capsule_height * 0.5 + 5.0 / scale
		var apex: float = highest + maxf(0.0, bottom - highest) * float(target.peak) * 0.38
		var y: float = bottom - (bottom - apex) * 4.0 * progress * (1.0 - progress)
		var tilt: float = float(target.spin) * sin(progress * PI)
		if reduced_motion:
			tilt = 0.0
			if _arena.size.x >= _arena.size.y * 1.25:
				x = _arena.position.x + capsule_width * 0.5 + room * float(lane) * 0.5
				y = (_arena.position.y + _arena.end.y) * 0.5
			else:
				x = _arena.position.x + capsule_width * 0.5 + room * (0.0 if lane == 0 else 1.0 if lane == 1 else 0.5)
				y = highest if lane != 2 else bottom
		var center := Vector2(x, y)
		if not reduced_motion:
			for burst in _bursts:
				var age: float = float(burst.age)
				if age < 0.14 and center.distance_to(burst.center) < 150.0 / scale:
					center += Vector2(sin(age * 100.0), cos(age * 85.0)) * (1.0 - age / 0.14) * 3.0 / scale
		_draw_targets.append({"uid": int(target.uid), "word": target.word, "forms": target.get("forms", []), "center": center,
			"size": capsule_size, "rotation": tilt, "progress": progress, "lane": lane})
	# In narrow portrait play, stagger neighboring capsules vertically rather than letting words cover one another.
	for pass_index in range(3):
		for a in range(_draw_targets.size()):
			for b in range(a + 1, _draw_targets.size()):
				var first: Dictionary = _draw_targets[a]
				var second: Dictionary = _draw_targets[b]
				var separation := Vector2(absf(first.center.x - second.center.x), absf(first.center.y - second.center.y))
				if separation.x < capsule_width + 4.0 / scale and separation.y < capsule_height + 8.0 / scale:
					var move: float = (capsule_height + 8.0 / scale - separation.y) * 0.5
					var direction: float = -1.0 if first.center.y <= second.center.y else 1.0
					first.center.y = clampf(first.center.y + direction * move, _arena.position.y + capsule_height * 0.5, _arena.end.y - capsule_height * 0.5)
					second.center.y = clampf(second.center.y - direction * move, _arena.position.y + capsule_height * 0.5, _arena.end.y - capsule_height * 0.5)


func _global_target_rect(target: Dictionary) -> Rect2:
	var transform := Transform2D(float(target.rotation), target.center)
	var half: Vector2 = target.size * 0.5
	var first: Vector2 = get_global_transform() * (transform * -half)
	var result := Rect2(first, Vector2.ZERO)
	for point in [Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]:
		result = result.expand(get_global_transform() * (transform * point))
	return result


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale: float = Style.ui_scale(self)
	draw_style_box(Style.box(NAVY, Color("#28385d"), ceili(20.0 / scale), maxi(1, roundi(1.0 / scale))), Rect2(Vector2.ZERO, size))
	_draw_atmosphere(scale)
	if _hud != null and _hud.visible:
		var side: float = minf(86.0 / scale, (size.x - 32.0 / scale) * 0.28)
		for x in [16.0 / scale, size.x - 16.0 / scale - side]:
			draw_style_box(Style.box(SURFACE, Color("#2d3a5c"), ceili(13.0 / scale), 1), Rect2(x, 10.0 / scale, side, 52.0 / scale))
		for target in _draw_targets:
			_draw_capsule(target, scale)
		for burst in _bursts:
			_draw_burst(burst, scale)


func _draw_atmosphere(scale: float) -> void:
	var horizon: float = size.y - 14.0 / scale
	var light := Color(CYAN, 0.025)
	for index in range(3):
		draw_circle(Vector2(size.x * (0.23 + index * 0.27), horizon + 180.0 / scale), (260.0 + index * 20.0) / scale, Color(NEON[index], 0.018))
	for index in range(22):
		var x: float = fposmod(float(index * 137 + 31), 997.0) / 997.0 * size.x
		var y: float = 122.0 / scale + fposmod(float(index * 89 + 11), 631.0) / 631.0 * maxf(0.0, size.y - 150.0 / scale)
		draw_circle(Vector2(x, y), (0.6 if index % 3 else 1.1) / scale, Color(SOFT, 0.20 if index % 3 else 0.35))
	for index in range(9):
		var x: float = size.x * float(index) / 8.0
		draw_line(Vector2(size.x * 0.5 + (x - size.x * 0.5) * 0.2, size.y * 0.68), Vector2(x, size.y), light, 1.0 / scale)
	draw_line(Vector2(24.0 / scale, horizon), Vector2(size.x - 24.0 / scale, horizon), Color(CYAN, 0.12), 1.0 / scale)


func _card_color(uid: int) -> Color:
	return CARD_COLORS[(uid - 1) % CARD_COLORS.size()]


func _draw_capsule(target: Dictionary, scale: float) -> void:
	var capsule_size: Vector2 = target.size
	var rect := Rect2(-capsule_size * 0.5, capsule_size)
	var accent: Color = _card_color(int(target.uid))
	draw_set_transform(target.center, target.rotation)
	var shadow: StyleBoxFlat = Style.box(Color(0.0, 0.0, 0.0, 0.3), Color.TRANSPARENT, ceili(21.0 / scale), 0)
	draw_style_box(shadow, Rect2(rect.position + Vector2(0, 6.0 / scale), capsule_size))
	draw_style_box(Style.box(Color(accent, 0.10), Color(accent, 0.20), ceili(24.0 / scale), maxi(1, roundi(2.0 / scale))), rect.grow(4.0 / scale))
	draw_style_box(Style.box(accent, accent.lightened(0.45), ceili(19.0 / scale), maxi(1, roundi(2.0 / scale))), rect)
	draw_line(rect.position + Vector2(19.0 / scale, 5.0 / scale), Vector2(rect.end.x - 19.0 / scale, rect.position.y + 5.0 / scale), Color(1, 1, 1, 0.65), 2.0 / scale, true)
	var art_edge: float = minf(capsule_size.x - 28.0 / scale, capsule_size.y * 0.61)
	var art_center := Vector2(0, rect.position.y + 10.0 / scale + art_edge * 0.5)
	draw_circle(art_center, art_edge * 0.52, Color("#fffaf2"))
	var texture: Texture2D = _textures.get(str(target.word.get("id", target.word.get("text", ""))), null)
	if texture != null:
		var original: Vector2 = texture.get_size()
		var art_size: Vector2 = original * minf(art_edge / maxf(1.0, original.x), art_edge / maxf(1.0, original.y))
		draw_texture_rect(texture, Rect2(art_center - art_size * 0.5, art_size), false)
	var word: String = str(target.word.get("text", ""))
	var font: Font = ThemeDB.fallback_font
	var font_size: int = ceili(clampf(capsule_size.x * scale * 0.17, 18.0, 26.0) / scale)
	while font_size > ceili(13.0 / scale) and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > capsule_size.x - 16.0 / scale:
		font_size -= 1
	var text_width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: float = rect.end.y - 11.0 / scale
	draw_string(font, Vector2(-text_width * 0.5, baseline), word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("#243454"))
	draw_set_transform(Vector2.ZERO)


func _draw_burst(burst: Dictionary, scale: float) -> void:
	var age: float = float(burst.age)
	var center: Vector2 = burst.center
	var accent: Color = burst.color
	var progress: float = clampf(age / (0.35 if reduced_motion else 0.75), 0.0, 1.0)
	if reduced_motion:
		draw_arc(center, float(burst.radius) * 0.7, 0.0, TAU, 28, Color(accent, 1.0 - progress), 3.0 / scale, true)
		return
	var radius: float = lerpf(12.0 / scale, float(burst.radius) * 1.7, ease(progress, 0.45))
	draw_arc(center, radius, 0.0, TAU, 48, Color(accent, (1.0 - progress) * 0.7), 3.0 / scale, true)
	draw_arc(center, radius * 0.74, 0.0, TAU, 40, Color.WHITE * Color(1, 1, 1, (1.0 - progress) * 0.4), 1.0 / scale, true)
	if age < 0.19:
		var flash: float = 1.0 - age / 0.19
		draw_circle(center, (20.0 + 28.0 * age / 0.19) / scale, Color(WHITE, flash * 0.75))
		var from: Vector2 = center + Vector2(-1.0, 0.48) * float(burst.radius)
		var to: Vector2 = center + Vector2(1.0, -0.48) * float(burst.radius)
		draw_line(from, to, Color(accent, flash * 0.8), 15.0 / scale, true)
		draw_line(from, to, Color(WHITE, flash), 5.0 / scale, true)
		var crack := PackedVector2Array([center + Vector2(-26, -34) / scale, center + Vector2(-6, -7) / scale, center + Vector2(12, 0) / scale, center + Vector2(26, 34) / scale])
		draw_polyline(crack, Color(WHITE, flash), 3.0 / scale, true)
	for index in range(11):
		var angle: float = TAU * float(index) / 11.0 + 0.22
		var direction := Vector2(cos(angle), sin(angle))
		var distance: float = (24.0 + 115.0 * progress) / scale
		var position: Vector2 = center + direction * distance + Vector2(0, progress * progress * 52.0 / scale)
		var side: float = (8.0 if index % 2 else 12.0) * (1.0 - progress * 0.7) / scale
		var tangent := direction.orthogonal()
		var points := PackedVector2Array([position + direction * side, position - direction * side * 0.6 + tangent * side * 0.5, position - direction * side * 0.3 - tangent * side * 0.65])
		draw_colored_polygon(points, Color(CARD_COLORS[index % CARD_COLORS.size()], 1.0 - progress))
	var font: Font = ThemeDB.fallback_font
	var label: String = "+%d" % int(burst.points)
	var font_size: int = ceili(23.0 / scale)
	var text_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, center + Vector2(-text_width * 0.5, -36.0 / scale - progress * 34.0 / scale), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(WHITE, 1.0 - progress))


func _finish() -> void:
	_finished_sent = true
	_listening = false
	_listening_tick_usec = -1
	_clear_transcript()
	_message = "Round complete. Tap a word to hear it, or play again."
	_draw_targets.clear()
	_bursts.clear()
	_hud.hide()
	_gate.hide()
	_build_results(game.summary())
	_results.show()
	_results.scroll_vertical = 0
	_layout()
	_publish(true)
	round_finished.emit(game.summary())


func _build_results(summary: Dictionary) -> void:
	for child in _result_body.get_children():
		_result_body.remove_child(child)
		child.queue_free()
	_review_grids.clear()
	_review_buttons.clear()
	var scale: float = Style.ui_scale(self)
	_report_pages = _make_report(summary)
	_report_step = 0
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", ceili(10.0 / scale))
	_result_body.add_child(hero)
	pip = Duck.new()
	pip.custom_minimum_size = Vector2.ONE * 72.0 / scale
	pip.set_meta("pop_edge", 72.0)
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pip.set_reduced_motion(reduced_motion)
	hero.add_child(pip)
	pip.tooltip_text = "High five Pip and hear your report!"
	pip.pressed.connect(_high_five)
	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_PASS
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bubble_style: StyleBoxFlat = Style.box(Color("#edf6ff"), Color("#a8c6f2"), ceili(16.0 / scale), 1)
	bubble_style.set_content_margin_all(10.0 / scale)
	bubble.add_theme_stylebox_override("panel", bubble_style)
	hero.add_child(bubble)
	var headline := VBoxContainer.new()
	headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headline.add_theme_constant_override("separation", ceili(5.0 / scale))
	bubble.add_child(headline)
	_report_kicker = _label("PIP'S REPORT · 1 / 3", 10, Color("#46658c"))
	_report_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_report_kicker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.add_child(_report_kicker)
	_result_heading = _label("", 20, Style.INK)
	_result_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_result_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.add_child(_result_heading)
	_pip_caption = _label("", 14, Style.INK)
	_pip_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pip_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.add_child(_pip_caption)
	_report_actions = HBoxContainer.new()
	_result_body.add_child(_report_actions)
	report_button = _action("Hear Pip")
	report_button.name = "HearPip"
	report_button.pressed.connect(_hear_report)
	next_report_button = _action("My highlights")
	next_report_button.name = "NextReport"
	next_report_button.pressed.connect(_next_report)
	_report_actions.add_child(report_button)
	_report_actions.add_child(next_report_button)
	_stats = GridContainer.new()
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_body.add_child(_stats)
	for item in [["HITS", int(summary.get("hits", 0)), CYAN], ["WORDS", int(summary.get("unique_words", 0)), VIOLET], ["BEST COMBO", int(summary.get("best_combo", 0)), PINK], ["SCORE", int(summary.get("score", 0)), CYAN]]:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(0, 54.0 / scale)
		panel.set_meta("pop_min_height", 54.0)
		panel.add_theme_stylebox_override("panel", Style.box(SURFACE, Color("#304164"), ceili(13.0 / scale), 1))
		_stats.add_child(panel)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 0)
		panel.add_child(stack)
		stack.add_child(_label(str(item[1]), 25, item[2]))
		stack.add_child(_label(str(item[0]), 10, SOFT))
	_result_actions = HBoxContainer.new()
	_result_body.add_child(_result_actions)
	replay_button = _action("Play again", true)
	replay_button.name = "Replay"
	replay_button.pressed.connect(_replay)
	back_button = _action("Back")
	back_button.name = "Back"
	back_button.pressed.connect(_exit)
	_result_actions.add_child(replay_button)
	_result_actions.add_child(back_button)
	_add_review("Words you popped", summary.get("hit_words", []), CYAN)
	_add_review("Try these next time", summary.get("missed_words", []), PINK)
	if _review_buttons.is_empty():
		var empty: Label = _label("Say a word while its picture is on screen.\nPip is ready for another round with you.", 14, SOFT)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_result_body.add_child(empty)
	var bottom_space := Control.new()
	bottom_space.custom_minimum_size.y = 8.0 / scale
	bottom_space.set_meta("pop_min_height", 8.0)
	bottom_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_body.add_child(bottom_space)
	for control in [pip, report_button, next_report_button, replay_button, back_button]:
		control.focus_entered.connect(func() -> void: _ensure_result_control(control))
	_show_report(0)
	pip.perform_trick("flutter")
	_layout()


func _add_review(title: String, words: Array, color: Color) -> void:
	if words.is_empty():
		return
	var scale: float = Style.ui_scale(self)
	var caption: Label = _label(title + " · tap to hear", 15, color)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_body.add_child(caption)
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_body.add_child(grid)
	_review_grids.append(grid)
	for word in words:
		if not word is Dictionary:
			continue
		_cache_texture(word)
		var button := Button.new()
		button.name = "Hear_" + str(word.get("id", word.get("text", "word")))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 66.0 / scale)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = "Hear " + str(word.get("text", ""))
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, Style.box(Color("#f3f7ff") if state == "normal" else Color("#dcecff"), color.lightened(0.3), ceili(12.0 / scale), 1))
		button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, color, ceili(12.0 / scale), maxi(2, ceili(2.0 / scale))))
		grid.add_child(button)
		_review_buttons.append(button)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10.0 / scale
		row.offset_right = -10.0 / scale
		row.add_theme_constant_override("separation", ceili(10.0 / scale))
		button.add_child(row)
		var art := TextureRect.new()
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.custom_minimum_size = Vector2.ONE * 46.0 / scale
		art.set_meta("pop_edge", 46.0)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture = _textures.get(str(word.get("id", word.get("text", ""))), null)
		row.add_child(art)
		var text: Label = _label(str(word.get("text", "")), 16, Style.INK)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(text)
		var times: Label = _label("×%d" % int(word.get("count", 1)), 12, Style.MUTED)
		row.add_child(times)
		button.pressed.connect(func() -> void:
			if pip != null and is_instance_valid(pip):
				pip.react("happy")
			hear_requested.emit(word))
		button.focus_entered.connect(func() -> void: _ensure_result_control(button))


func _ensure_result_control(control: Control) -> void:
	# Godot's built-in focus scrolling checks scrollbar visibility. Our scrollbars
	# are intentionally hidden, so reveal focused actions using container bounds.
	var local_rect: Rect2 = _results.get_global_transform().affine_inverse() * control.get_global_rect()
	if local_rect.position.y < 0.0:
		_results.scroll_vertical += floori(local_rect.position.y)
	elif local_rect.end.y > _results.size.y:
		_results.scroll_vertical += ceili(local_rect.end.y - _results.size.y)


func _make_report(summary: Dictionary) -> Array[Dictionary]:
	if _report_prompts.is_empty():
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://pop-voice-prompts.json"))
		if manifest is Dictionary:
			_report_prompts = manifest
	var count: int = int(summary.get("hits", 0))
	var combo: int = int(summary.get("best_combo", 0))
	var hits: Array = summary.get("hit_words", [])
	var missed: Array = summary.get("missed_words", [])
	var opening_id: String = "round-%d" % count if count >= 0 and count <= 20 else "round-fallback"
	var opening: String = _prompt_text(opening_id)
	if count > 20:
		# The exact number stays visible; the generic recorded encouragement is
		# explicitly identified instead of substituting a wrong recorded number.
		opening = "%d words in 30 seconds.\nPip says: %s" % [count, opening]
	var opening_audio: Array[String] = [_prompt_path(opening_id)]
	var highlights_id: String = "no-highlights" if hits.is_empty() else ("highlights-one" if hits.size() == 1 else "highlights-two")
	var highlights: String = _prompt_text(highlights_id)
	var highlights_audio: Array[String] = [_prompt_path(highlights_id)]
	for word in hits.slice(0, 2):
		highlights += " " + str(word.get("text", "")) + "."
		highlights_audio.append(_word_audio(word))
	if not hits.is_empty() and combo >= 1 and combo <= 20:
		var combo_id: String = "combo-%d" % combo
		highlights += " " + _prompt_text(combo_id)
		highlights_audio.append(_prompt_path(combo_id))
	var practice: String = _prompt_text("ready")
	var practice_audio: Array[String] = [_prompt_path("ready")]
	if not missed.is_empty():
		practice = "%s %s. %s" % [_prompt_text("practice"), str(missed[0].get("text", "")), _prompt_text("practice-next")]
		practice_audio = [_prompt_path("practice"), _word_audio(missed[0]), _prompt_path("practice-next")]
	elif not hits.is_empty():
		practice = "%s %s. %s" % [_prompt_text("repeat"), str(hits[0].get("text", "")), _prompt_text("repeat-next")]
		practice_audio = [_prompt_path("repeat"), _word_audio(hits[0]), _prompt_path("repeat-next")]
	return [{"title": "Your round", "text": opening, "audio": opening_audio},
		{"title": "Your highlights", "text": highlights, "audio": highlights_audio},
		{"title": "Let's practise", "text": practice, "audio": practice_audio}]


func _prompt_text(id: String) -> String:
	return str(_report_prompts.get(id, ""))


func _prompt_path(id: String) -> String:
	return "res://assets/audio/pop/" + id + ".wav"


func _word_audio(word: Dictionary) -> String:
	var path: String = str(word.get("audio", ""))
	return path if path.begins_with("res://") else "res://" + path


func report_audio() -> Array[String]:
	var paths: Array[String] = []
	if game.phase != "finished" or _stopped or _report_pages.is_empty():
		return paths
	if not _report_feedback.is_empty():
		paths.append(_prompt_path("high-five"))
	for path in _report_pages[_report_step].get("audio", []):
		paths.append(str(path))
	return paths


func report_text() -> String:
	if _pip_caption != null and is_instance_valid(_pip_caption):
		return _report_feedback + _pip_caption.text
	return ""


func _show_report(step: int) -> void:
	if _report_pages.is_empty():
		return
	_report_step = posmod(step, _report_pages.size())
	_report_feedback = ""
	_report_audio_state = "idle"
	set_report_audio_state("idle")
	_result_heading.text = str(_report_pages[_report_step].title)
	_pip_caption.text = str(_report_pages[_report_step].text)
	_report_kicker.text = "PIP'S REPORT · %d / 3" % (_report_step + 1)
	next_report_button.text = ["My highlights", "Coach me", "My round"][_report_step]
	_message = _pip_caption.text
	_results.scroll_vertical = 0
	_layout()
	_publish(true)


func _next_report() -> void:
	if game.phase != "finished" or not is_visible_in_tree():
		return
	set_report_speaking(false)
	_show_report(_report_step + 1)
	pip.react("curious" if _report_step == 2 else "happy")
	_hear_report()


func _hear_report() -> void:
	if game.phase == "finished" and is_visible_in_tree():
		pip.react("happy")
		report_requested.emit(report_text())


func report_voice_unavailable() -> void:
	set_report_audio_state("unavailable")


func set_report_speaking(value: bool) -> void:
	set_report_audio_state("speaking" if value else "idle")


func set_report_audio_state(state: String) -> void:
	var visible_report: bool = game.phase == "finished" and is_visible_in_tree() and not _stopped
	if not visible_report:
		state = "idle"
	# A routine cancellation after a failed request must not immediately erase
	# Read along. A new page or a fresh loading request clears the failure.
	if state == "idle" and _report_audio_state == "unavailable" and visible_report:
		return
	_report_audio_state = state
	if pip != null and is_instance_valid(pip):
		pip.set_speaking(state == "speaking")
	if _report_kicker != null and is_instance_valid(_report_kicker):
		var caption: String = "PIP'S REPORT"
		if state == "speaking":
			caption = "PIP IS SPEAKING"
		elif state == "loading":
			caption = "PIP IS LOADING"
		_report_kicker.text = "PIP SAYS · READ ALONG" if state == "unavailable" else caption + " · %d / 3" % (_report_step + 1)
	if report_button != null and is_instance_valid(report_button):
		report_button.text = {"speaking": "Hear again", "loading": "Loading...", "unavailable": "Try Pip again"}.get(state, "Hear Pip")
	_queue_geometry_publish()


func _high_five() -> void:
	if pip == null or not is_instance_valid(pip) or game.phase != "finished" or not is_visible_in_tree():
		return
	pip.perform_trick("high-five")
	_report_feedback = _prompt_text("high-five") + " "
	_result_heading.text = _prompt_text("high-five")
	_message = report_text()
	_layout()
	_publish(true)
	pip.react("happy")
	pip_report_requested.emit(report_text())


func _replay() -> void:
	request_listening.emit()


func _exit() -> void:
	exit_requested.emit()


func _cache_texture(word: Dictionary) -> void:
	var key: String = str(word.get("id", word.get("text", "")))
	if _textures.has(key):
		return
	var image_path: String = str(word.get("image", ""))
	_textures[key] = null
	if image_path.is_empty():
		return
	if not image_path.begins_with("res://"):
		image_path = "res://" + image_path
	if ResourceLoader.exists(image_path):
		_textures[key] = load(image_path)


func _pending_message(message: String) -> bool:
	var value: String = message.to_lower()
	return value.begins_with("starting") or value == "listening..." \
		or value.begins_with("allow microphone access if your browser asks") \
		or value.begins_with("listening paused. continuing") \
		or value.begins_with("listening paused. say a word when listening resumes")


func _label(text: String, font_size: int, color: Color = WHITE) -> Label:
	var label: Label = Style.label(text, ceili(float(font_size) / Style.ui_scale(self)))
	label.set_meta("pop_font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _rescale_content(node: Node, scale: float) -> void:
	for child in node.get_children():
		if child is Label and child.has_meta("pop_font_size"):
			child.add_theme_font_size_override("font_size", ceili(float(child.get_meta("pop_font_size")) / scale))
		if child is Control and child.has_meta("pop_edge"):
			child.custom_minimum_size = Vector2.ONE * float(child.get_meta("pop_edge")) / scale
		elif child is Control and child.has_meta("pop_min_height"):
			child.custom_minimum_size.y = float(child.get_meta("pop_min_height")) / scale
		_rescale_content(child, scale)


func _place_label(label: Label, rect: Rect2, font_size: int) -> void:
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", ceili(float(font_size) / Style.ui_scale(self)))
	label.clip_text = true


func _action(text: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action(button, primary)
	return button


func _style_action(button: Button, primary: bool = false) -> void:
	if button == null or not is_instance_valid(button):
		return
	var scale: float = Style.ui_scale(self)
	Style.action_button(button, CYAN, primary)
	button.custom_minimum_size = Vector2(0, 48.0 / scale)
	button.add_theme_font_size_override("font_size", ceili(14.0 / scale))
	for state in ["normal", "hover", "pressed"]:
		var fill: Color = CYAN if primary else SURFACE
		if state != "normal":
			fill = fill.lightened(0.12)
		button.add_theme_stylebox_override(state, Style.box(fill, CYAN if primary else Color("#41557a"), ceili(13.0 / scale), 1))
	button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, PINK, ceili(13.0 / scale), maxi(2, ceili(2.0 / scale))))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, NAVY if primary else WHITE)
