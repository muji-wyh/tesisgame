extends Control

signal request_listening
signal exit_requested
signal hit(word: Dictionary)
signal launched(uid: int)
signal missed(count: int)
signal round_finished(summary: Dictionary)
signal chests_requested
signal chest_earned(count: int)
signal hear_requested(word: Dictionary)
signal status_changed(snapshot: Dictionary)

const Style = preload("res://scripts/ui_style.gd")
const Data = preload("res://scripts/game_data.gd")
const SpeechWords = preload("res://scripts/speech_words.gd")
const PopModel = preload("res://scripts/voice_pop_model.gd")
const Slice = preload("res://scripts/voice_pop_slice.gd")
const ResultScroll = preload("res://scripts/result_scroll.gd")
const NAVY := Color("#080e23")
const SURFACE := Color("#16203c")
const CYAN := Color("#57edff")
const PINK := Color("#ff6cce")
const VIOLET := Color("#a48aff")
const WHITE := Color("#f5f7ff")
const SOFT := Color("#a8b9dc")
const LAUNCH_SOUND_WINDOW: float = 0.2
const HUD_HIT_DURATION: float = 0.9
const HUD_BONUS_DURATION: float = 1.8
const HUD_BONUS_MERGE_WINDOW: float = 0.12
const CHEST_FX_DURATION: float = 2.2
const CHEST_COLOR := Color("#ffd570")
const HIT_COLOR := Color("#9dffe0")
const BONUS_COLOR := Color("#ffdf73")
const RESULT_HIT_DURATION: float = 1.25
const NEON := [CYAN, PINK, VIOLET]
const CARD_COLORS := [
	Color("#72dff3"), Color("#ffa1cb"), Color("#ffdc70"),
	Color("#bfa3ff"), Color("#80e3bb"), Color("#ffb77d")
]

var game = PopModel.new()
var reduced_motion: bool = false
var replay_button: Button
var chests_button: Button
var retry_button: Button
var time_label: Label
var hits_label: Label
var transcript_label: Label
var interaction_allowed: Callable

var _words: Array = []
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
var _publish_key: String = ""
var _geometry_publish_pending: bool = false
var _last_hit_left: float = 0.0
var _hud_hit_age: float = HUD_HIT_DURATION
var _hud_hit_serial: int = 0
var _hud_hit_amount: int = 0
var _hud_hit_words := PackedStringArray()
var _hud_hit_pattern := RegEx.new()
var _hud_hit_forms: Array[String] = []
var _hud_transcript_hit: bool = false
var _hud_bonus_age: float = HUD_BONUS_DURATION
var _hud_bonus_serial: int = 0
var _hud_bonus_amount: int = 0
var _hud_bonus_awards: Array[int] = []
var _time_bonus_label: Label
var _time_bonus_caption: Label
var _time_bonus_badge: Control
var _bonus_overlay: Control
var _bonus_fx: Node2D
var _time_bonus_anchor := Vector2.ZERO
var _chest_overlay: Control
var _chest_fx: Node2D
var _reward_hud: Control
var _score_label: Label
var _chest_count_label: Label
var _chest_progress_label: Label
var _chest_badge: Control
var _chest_award_label: Label
var _chest_award_caption: Label
var _chest_badge_anchor := Vector2.ZERO
var _chest_fx_age: float = CHEST_FX_DURATION
var _chest_fx_serial: int = 0
var _chest_fx_amount: int = 0
var _last_launch_uid: int = 0
var _transcript: String = ""
var _transcript_final: bool = false
var _bursts: Array[Dictionary] = []
var _slice_clip: Control
var _slice_canvas: Node2D
var _draw_targets: Array[Dictionary] = []
var _target_canvas: Node2D
var _arena: Rect2
var _hud: Control
var _hud_fx: Node2D
var _hits_caption: Label
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
var _results: ResultScroll
var _result_body: VBoxContainer
var _result_hero: Control
var _round_player: Dictionary = {}
var _result_player: HBoxContainer
var _result_avatar: TextureRect
var _result_name: Label
var _result_hits: Label
var _result_hits_caption: Label
var _result_hit_fx: Node2D
var _result_hit_total: int = 0
var _result_hit_age: float = RESULT_HIT_DURATION
var _result_idle_time: float = 0.0
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
	_hud_fx = Node2D.new()
	_hud_fx.draw.connect(_draw_hud_feedback)
	_hud.add_child(_hud_fx)
	time_label = _label(str(int(PopModel.DURATION)), 30)
	time_label.name = "Time"
	hits_label = _label("0", 28)
	hits_label.name = "Hits"
	_hits_caption = _label("HITS", 10, SOFT)
	_hits_caption.name = "HitsCaption"
	transcript_label = _label("", 17)
	transcript_label.name = "LiveTranscript"
	transcript_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	transcript_label.max_lines_visible = 2
	transcript_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	transcript_label.hide()
	_live_caption = _label("", 10, CYAN)
	_live_caption.name = "LiveStatus"
	for item in [time_label, hits_label, _hits_caption, transcript_label, _live_caption]:
		_hud.add_child(item)
	# Live cards pass in front of the field HUD, inside this panel's clip.
	_target_canvas = Node2D.new()
	_target_canvas.name = "FlyingCards"
	_target_canvas.draw.connect(_draw_flying_targets)
	add_child(_target_canvas)
	_slice_clip = Control.new()
	_slice_clip.name = "SliceArena"
	_slice_clip.clip_contents = true
	_slice_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slice_clip)
	_slice_canvas = Node2D.new()
	_slice_canvas.draw.connect(_draw_slices)
	_slice_clip.add_child(_slice_canvas)
	# Earned time stays in the foreground even when a card crosses the timer.
	_bonus_overlay = Control.new()
	_bonus_overlay.name = "TimeBonusOverlay"
	_bonus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bonus_overlay)
	_bonus_fx = Node2D.new()
	_bonus_fx.draw.connect(_draw_time_bonus)
	_bonus_overlay.add_child(_bonus_fx)
	_time_bonus_badge = Control.new()
	_time_bonus_badge.name = "TimeBonusBadge"
	_time_bonus_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bonus_overlay.add_child(_time_bonus_badge)
	_time_bonus_label = _label("", 34, BONUS_COLOR)
	_time_bonus_label.name = "TimeBonus"
	_time_bonus_caption = _label("TIME BONUS", 10, WHITE)
	_time_bonus_caption.name = "TimeBonusCaption"
	for item in [_time_bonus_label, _time_bonus_caption]:
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_time_bonus_badge.add_child(item)
	_bonus_overlay.hide()
	_chest_overlay = Control.new()
	_chest_overlay.name = "ChestRewardOverlay"
	_chest_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chest_overlay)
	_chest_fx = Node2D.new()
	_chest_fx.draw.connect(_draw_chest_feedback)
	_chest_overlay.add_child(_chest_fx)
	_reward_hud = Control.new()
	_reward_hud.name = "ChestProgress"
	_reward_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest_overlay.add_child(_reward_hud)
	_score_label = _label("0 POINTS", 13, WHITE)
	_score_label.name = "Score"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_chest_count_label = _label("CHESTS 0 / 3", 13, CHEST_COLOR)
	_chest_count_label.name = "ChestCount"
	_chest_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chest_progress_label = _label("NEXT CHEST AT 100", 10, SOFT)
	_chest_progress_label.name = "NextChest"
	for item in [_score_label, _chest_count_label, _chest_progress_label]:
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reward_hud.add_child(item)
	_chest_badge = Control.new()
	_chest_badge.name = "ChestEarnedBadge"
	_chest_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest_overlay.add_child(_chest_badge)
	_chest_award_label = _label("+1 CHEST", 26, CHEST_COLOR)
	_chest_award_label.name = "ChestEarned"
	_chest_award_caption = _label("UNLOCKED", 10, WHITE)
	_chest_award_caption.name = "ChestEarnedCaption"
	for item in [_chest_award_label, _chest_award_caption]:
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chest_badge.add_child(item)
	_chest_overlay.hide()
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
	_gate_note = _label("%d seconds. See it. Say it. Pop it!" % int(PopModel.DURATION), 14, SOFT)
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
	_results = ResultScroll.new()
	_results.name = "PopResults"
	_results.interaction_allowed = func() -> bool: return not interaction_allowed.is_valid() or interaction_allowed.call()
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


func configure(words: Array, motion_reduced: bool = false, seed_value: int = -1) -> void:
	_build()
	cancel_result_input()
	_round_player.clear()
	_words = words.duplicate(true)
	game.configure(_words, seed_value)
	_enabled = false
	_listening = false
	_listening_tick_usec = -1
	_finished_sent = false
	_stopped = false
	_pending = false
	_reconnecting = false
	_publish_key = ""
	_last_hit_left = 0.0
	_hud_hit_serial = 0
	_hud_bonus_serial = 0
	_chest_fx_serial = 0
	_last_launch_uid = 0
	_clear_transcript()
	_settle_result_feedback()
	_clear_slices()
	_draw_targets.clear()
	_message = "Allow microphone access to start." if not _words.is_empty() else "Choose a world with words to play."
	_gate_title.text = "Ready to pop?"
	_gate_copy.text = _message
	_gate_note.text = "Earn a chest at 100, 200, and 300 points. Your %d seconds start when Pip can hear you." % int(PopModel.DURATION)
	retry_button.text = "Start listening"
	retry_button.disabled = _words.is_empty()
	_gate.show()
	_results.hide()
	_hud.hide()
	_update_hud()
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
			_message = "Round complete. Tap a word to hear it, or play again."
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
		var transient: bool = enabled and _pending_message(message)
		_clear_transcript(not (transient and game.phase in ["running", "paused"]))
		_pending = transient
		_pending_left = 10.0 if transient else 0.0
		_reconnecting = transient and game.phase in ["running", "paused"]
		# Browser utterance rollover briefly pauses recognition after a hit.
		# Let that earned cut finish, but discard it on an actual error or exit.
		if not _reconnecting:
			_clear_slices()
		if game.phase == "running":
			game.pause()
		_gate_title.text = "Opening microphone…" if transient else "Round paused" if game.phase == "paused" else "Ready to pop?"
		_gate_copy.text = message if not message.is_empty() else "Allow microphone access to start."
		_gate_note.text = "%d seconds left. Your progress is safe." % ceili(game.remaining) if game.phase == "paused" else "Your %d seconds start when Pip can hear you." % int(PopModel.DURATION)
		retry_button.text = "Waiting…" if transient else "Retry listening" if game.phase == "paused" or not message.is_empty() else "Start listening"
		retry_button.disabled = _words.is_empty() or transient
		_gate.visible = not _reconnecting
		_hud.visible = _reconnecting
	_layout()
	_refresh_targets()
	_publish(true)
	_emit_launches()
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
	_refresh_transcript_hit()
	transcript_label.text = _transcript
	_update_transcript_window()
	_update_hud()
	_publish(true)


func _clear_transcript(clear_bonus: bool = true) -> void:
	_transcript = ""
	_transcript_final = false
	game.clear_recognition_feedback()
	_clear_hud_feedback(clear_bonus)
	if transcript_label != null:
		transcript_label.text = ""
		transcript_label.hide()


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
	# Browser recognition reports lexical tokens one at a time. A polite filler
	# after the matched noun must not replace that answer's short celebration.
	if struck.is_empty() and _last_hit_left > 0.0:
		game.clear_recognition_feedback()
	_present_hits(struck)


func receive_speech_event(json: String) -> bool:
	if not _listening or game.phase != "running" or not is_visible_in_tree():
		return false
	var event = JSON.parse_string(json)
	if not event is Dictionary:
		return false
	_sync_game_clock()
	if game.phase != "running":
		return false
	_refresh_targets()
	var struck: Array = game.hit_speech_event(event)
	if struck.is_empty():
		if _last_hit_left > 0.0:
			game.clear_recognition_feedback()
		_present_hits(struck)
		return false
	_present_hits(struck)
	return true


func _present_hits(struck: Array) -> void:
	if struck.is_empty() and not game.recognition_feedback.is_empty():
		_last_hit_left = 0.0
	var time_awards: Array[int] = []
	var chest_awards: int = 0
	for target in struck:
		chest_awards += int(target.get("chest_awards", 0))
		var time_bonus: int = int(target.get("time_bonus", 0))
		if time_bonus > 0:
			time_awards.append(time_bonus)
		var visual: Dictionary = {}
		for item in _draw_targets:
			if int(item.uid) == int(target.uid):
				visual = item
		if not visual.is_empty():
			if _bursts.size() >= Slice.MAX_EFFECTS:
				_bursts.pop_front()
			_bursts.append(Slice.create(visual, int(target.get("points", 100)), _card_color(int(target.uid)),
				int(target.get("combo", 1))))
		_last_hit_left = 1.15
		hit.emit(target.word)
	if not time_awards.is_empty():
		_present_time_bonus(time_awards)
	if chest_awards > 0:
		_chest_fx_age = 0.0
		_chest_fx_serial += 1
		_chest_fx_amount = chest_awards
		chest_earned.emit(game.chest_count)
	if not struck.is_empty():
		_hud_hit_age = 0.0
		_hud_hit_serial += 1
		_hud_hit_amount = struck.size()
		_hud_hit_words.clear()
		var forms := PackedStringArray()
		for target in struck:
			_hud_hit_words.append(str(target.word.text))
			for form in target.get("forms", [target.word.text]):
				if not str(form) in forms:
					forms.append(str(form))
		# Reuse accepted noun forms without highlighting a substring or possessive.
		_hud_hit_forms.assign(Array(forms))
		_hud_hit_pattern.compile("(?<![\\p{L}\\p{N}_'’])(?:%s)(?![\\p{L}\\p{N}_'’])" % "|".join(forms))
		_refresh_transcript_hit()
	_refresh_targets()
	_update_hud()
	_publish(true)
	_slice_canvas.queue_redraw()
	queue_redraw()


func _present_time_bonus(awards: Array[int]) -> void:
	# Browser lexical callbacks from one utterance can arrive separately in a frame.
	# Combine that burst, while a later target earns its own clear reward message.
	if _hud_bonus_age >= HUD_BONUS_MERGE_WINDOW:
		_hud_bonus_amount = 0
		_hud_bonus_awards.clear()
	for amount in awards:
		_hud_bonus_amount += amount
		_hud_bonus_awards.append(amount)
	_hud_bonus_age = 0.0
	_hud_bonus_serial += 1


func pause() -> void:
	cancel_result_input()
	_clear_slices()
	if _finished_sent:
		_settle_result_feedback()
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
	cancel_result_input()
	_clear_transcript()
	_settle_result_feedback()
	_listening = false
	_listening_tick_usec = -1
	_enabled = false
	_finished_sent = true
	_stopped = true
	_pending = false
	_reconnecting = false
	_message = ""
	game.stop()
	_clear_slices()
	_draw_targets.clear()
	_target_canvas.queue_redraw()
	set_process(false)
	_publish(true)
	queue_redraw()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		_clear_slices()
	if value:
		_settle_result_feedback()
	_apply_hud_feedback()
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
		if is_instance_valid(chests_button) and not chests_button.disabled:
			result.append(chests_button)
		result.append(replay_button)
		for button in _review_buttons:
			result.append(button)
	return result


func default_focus() -> Control:
	if _results != null and _results.visible:
		if is_instance_valid(chests_button) and not chests_button.disabled:
			return chests_button
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
			"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y,
			"age": target.age, "spawned_at": target.spawned_at})
	var actions: Array[Dictionary] = []
	var candidates: Array[Control] = controls()
	if _gate != null and _gate.visible and retry_button.disabled:
		candidates.push_front(retry_button)
	if is_visible_in_tree() and _results != null and _results.visible and is_instance_valid(chests_button) and chests_button.disabled:
		candidates.push_front(chests_button)
	for control in candidates:
		var rect: Rect2 = control.get_global_rect()
		var visible_rect: Rect2 = _gate.get_global_rect() if _gate.visible else _results.get_global_rect()
		# Fractional viewport scaling can put an aligned right edge a few floating
		# point units outside its parent; keep fully visible controls discoverable.
		if not visible_rect.grow(0.01).encloses(rect):
			continue
		var visible_text: String = str(control.text) if control is Button else ""
		if visible_text.is_empty() and str(control.name).begins_with("Hear_"):
			var words := PackedStringArray()
			for label in control.find_children("*", "Label", true, false):
				words.append(label.text)
			visible_text = " ".join(words)
		actions.append({"name": str(control.name), "text": visible_text,
			"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y,
			"disabled": bool(control.disabled) if control is BaseButton else false})
	return {"phase": "idle" if _stopped else str(game.phase), "round_id": game.round_id,
		"remaining": float(game.remaining), "hits": int(game.hits),
		"base_duration": PopModel.DURATION, "bonus_time": float(game.bonus_time), "combo": int(game.combo),
		"hud": _hud_snapshot(),
		"vocabulary": game.vocabulary(),
		"recognition_feedback": game.recognition_feedback, "recognition_message": game.recognition_message,
		"score": int(game.score), "best_combo": int(game.best_combo), "targets": targets,
		"chest_count": int(game.chest_count), "chest_next_score": game.next_chest_score(),
		"chest_progress": game.chest_progress(), "chest_thresholds": PopModel.CHEST_SCORE_THRESHOLDS.duplicate(),
		"chest_fx": _chest_fx_snapshot(),
		"controls": actions, "message": _message, "listening": _listening, "enabled": _enabled,
		"transcript": _transcript, "transcript_final": _transcript_final,
		"results_hits": _result_hits_snapshot(),
		"results_scroll": _results.scroll_vertical,
		"results_scroll_max": maxf(0.0, _results.get_v_scroll_bar().max_value - _results.get_v_scroll_bar().page),
		"results_scrollbar_visible": _results.get_v_scroll_bar().is_visible_in_tree()}


func _hud_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for entry in [["time", time_label], ["time_bonus", _time_bonus_label], ["time_bonus_caption", _time_bonus_caption], ["hits", hits_label], ["transcript", transcript_label], ["status", _live_caption], ["score", _score_label], ["chests", _chest_count_label], ["next_chest", _chest_progress_label]]:
		var label: Label = entry[1]
		# Describe stable layout bounds, independent of the counter's brief pulse.
		var rect: Rect2 = label.get_parent().get_global_transform() * Rect2(label.position, label.size)
		if label.get_parent() == _time_bonus_badge:
			rect = _bonus_overlay.get_global_transform() * Rect2(_time_bonus_anchor + label.position, label.size)
		result[entry[0]] = {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y,
			"text": label.text}
	result.hit_effect = {"serial": _hud_hit_serial, "active": _hud_hit_age < HUD_HIT_DURATION and _hud.visible,
		"amount": _hud_hit_amount, "words": Array(_hud_hit_words)}
	result.bonus_effect = {"serial": _hud_bonus_serial, "active": _hud_bonus_age < HUD_BONUS_DURATION and _hud.visible,
		"amount": _hud_bonus_amount, "awards": _hud_bonus_awards.duplicate(), "reduced_motion": reduced_motion,
		"duration": HUD_BONUS_DURATION, "above_targets": _bonus_overlay.get_index() > _target_canvas.get_index()
			and _bonus_overlay.get_index() > _slice_clip.get_index()}
	result.targets_above_hud = _target_canvas.get_index() > _hud.get_index()
	return result


func _chest_fx_snapshot() -> Dictionary:
	return {"serial": _chest_fx_serial,
		"active": _chest_fx_age < CHEST_FX_DURATION and _hud.visible and is_visible_in_tree(),
		"amount": _chest_fx_amount, "count": game.chest_count, "duration": CHEST_FX_DURATION,
		"reduced_motion": reduced_motion, "text": _chest_award_label.text,
		"above_targets": _chest_overlay.get_index() > _target_canvas.get_index()
			and _chest_overlay.get_index() > _slice_clip.get_index()}


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
	if _pending:
		_pending_left = maxf(0.0, _pending_left - delta)
		if _pending_left <= 0.0:
			set_listening(_enabled, false, "Still waiting for the microphone. Check the browser prompt, or retry.")
	_sync_game_clock()
	_last_hit_left = maxf(0.0, _last_hit_left - delta)
	_advance_hud_feedback(delta)
	_advance_result_feedback(delta)
	_advance_slices(delta)
	_refresh_targets()
	_update_hud()
	_publish()
	queue_redraw()
	_slice_canvas.queue_redraw()


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
	var previous_misses: int = game.misses
	game.advance(elapsed_seconds)
	if game.misses > previous_misses:
		# One response per batch of expired targets; clearing or pausing a round
		# does not count as a miss, and slow frames cannot queue a chorus.
		missed.emit(game.misses - previous_misses)
	if game.phase == "finished" and not _finished_sent:
		_finish()
	_refresh_targets()
	_update_hud()
	_publish()
	_emit_launches()
	queue_redraw()


func _emit_launches() -> void:
	if not _listening or game.phase != "running" or not is_visible_in_tree():
		return
	var newest_uid: int = _last_launch_uid
	var sound_uid: int = 0
	for target in game.targets:
		var uid: int = int(target.uid)
		if uid <= _last_launch_uid:
			continue
		newest_uid = maxi(newest_uid, uid)
		# A delayed simulation step can create older targets. Never catch up
		# their launch sounds after they are already well into their flight.
		if float(target.age) <= LAUNCH_SOUND_WINDOW:
			sound_uid = maxi(sound_uid, uid)
	_last_launch_uid = newest_uid
	# A volley is one throw gesture. Do not stack two or three identical whooshes.
	if sound_uid > 0:
		launched.emit(sound_uid)


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		_clear_slices()
		_settle_result_feedback()
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
	hits_label.text = str(game.hits)
	_score_label.text = "%d POINTS" % game.score
	_chest_count_label.text = "CHESTS %d / %d" % [game.chest_count, PopModel.MAX_CHESTS]
	_chest_progress_label.text = "ALL 3 CHESTS EARNED" if game.chest_count >= PopModel.MAX_CHESTS else "NEXT CHEST AT %d" % game.next_chest_score()
	var celebrating: bool = _hud_hit_age < HUD_HIT_DURATION
	var visible_text: String = _transcript if not _transcript.is_empty() else " · ".join(_hud_hit_words) if celebrating else ""
	if transcript_label.text != visible_text:
		transcript_label.text = visible_text
		_update_transcript_window()
	transcript_label.visible = not visible_text.is_empty()
	_live_caption.text = "Reconnecting…" if _reconnecting else ""
	if not _reconnecting and not game.recognition_message.is_empty():
		_live_caption.text = game.recognition_message
	if game.phase == "running" and game.targets.is_empty() and game.remaining < 3.0:
		_live_caption.text = "Finishing up…"
	_live_caption.visible = not _live_caption.text.is_empty()
	_apply_hud_feedback()


func _clear_hud_feedback(clear_bonus: bool = true) -> void:
	_hud_hit_age = HUD_HIT_DURATION
	_hud_hit_amount = 0
	_hud_hit_words.clear()
	_hud_hit_forms.clear()
	_hud_transcript_hit = false
	if clear_bonus:
		_hud_bonus_age = HUD_BONUS_DURATION
		_hud_bonus_amount = 0
		_hud_bonus_awards.clear()
		_chest_fx_age = CHEST_FX_DURATION
		_chest_fx_amount = 0
	_apply_hud_feedback()


func _refresh_transcript_hit() -> void:
	_hud_transcript_hit = _hud_hit_age < HUD_HIT_DURATION and (_transcript.is_empty() \
		or (_hud_hit_pattern.is_valid() and _hud_hit_pattern.search(SpeechWords.normalize_text(_transcript, _hud_hit_forms)) != null))


func _advance_hud_feedback(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	var was_active: bool = _hud_hit_age < HUD_HIT_DURATION
	var bonus_was_active: bool = _hud_bonus_age < HUD_BONUS_DURATION
	var chest_was_active: bool = _chest_fx_age < CHEST_FX_DURATION
	_hud_hit_age = minf(HUD_HIT_DURATION, _hud_hit_age + delta)
	_hud_bonus_age = minf(HUD_BONUS_DURATION, _hud_bonus_age + delta)
	_chest_fx_age = minf(CHEST_FX_DURATION, _chest_fx_age + delta)
	_apply_hud_feedback()
	if (was_active and _hud_hit_age >= HUD_HIT_DURATION) or (bonus_was_active and _hud_bonus_age >= HUD_BONUS_DURATION) \
		or (chest_was_active and _chest_fx_age >= CHEST_FX_DURATION):
		_update_hud()
		_publish(true)


func _apply_hud_feedback() -> void:
	if hits_label == null:
		return
	var active: bool = _hud_hit_age < HUD_HIT_DURATION
	var pulse: float = 0.0
	if active and not reduced_motion:
		pulse = sin(clampf(_hud_hit_age / 0.38, 0.0, 1.0) * PI) * 0.28
	hits_label.pivot_offset = hits_label.size * 0.5
	hits_label.scale = Vector2.ONE * (1.0 + pulse)
	hits_label.add_theme_color_override("font_color", HIT_COLOR if active else WHITE)
	_hits_caption.add_theme_color_override("font_color", HIT_COLOR if active else SOFT)
	var highlight_words: bool = active and _hud_transcript_hit
	transcript_label.add_theme_color_override("font_color", HIT_COLOR if highlight_words else WHITE)
	transcript_label.add_theme_color_override("font_shadow_color", Color(HIT_COLOR, 0.55) if highlight_words else Color.TRANSPARENT)
	transcript_label.add_theme_constant_override("shadow_outline_size", 4 if highlight_words else 0)
	var bonus_active: bool = _hud_bonus_age < HUD_BONUS_DURATION and _hud.visible
	var bonus_pulse: float = 0.0
	if bonus_active and not reduced_motion:
		bonus_pulse = sin(clampf(_hud_bonus_age / 0.38, 0.0, 1.0) * PI) * 0.3
		bonus_pulse += sin(clampf((_hud_bonus_age - 1.3) / 0.5, 0.0, 1.0) * PI) * 0.2
	time_label.pivot_offset = time_label.size * 0.5
	time_label.scale = Vector2.ONE * (1.0 + bonus_pulse)
	time_label.add_theme_color_override("font_color", BONUS_COLOR if bonus_active else PINK if game.remaining <= 5.0 else WHITE)
	time_label.add_theme_color_override("font_shadow_color", Color(BONUS_COLOR, 0.8) if bonus_active else Color.TRANSPARENT)
	time_label.add_theme_constant_override("shadow_outline_size", 5 if bonus_active else 0)
	_bonus_overlay.visible = bonus_active
	_time_bonus_badge.visible = bonus_active
	_time_bonus_label.visible = bonus_active
	_time_bonus_caption.visible = bonus_active
	_time_bonus_label.text = "+%ds" % _hud_bonus_amount if bonus_active else ""
	_time_bonus_caption.text = "TIME BONUS" if bonus_active else ""
	_time_bonus_badge.pivot_offset = _time_bonus_badge.size * 0.5
	_time_bonus_badge.position = _time_bonus_anchor
	_time_bonus_badge.scale = Vector2.ONE
	_time_bonus_badge.modulate.a = 1.0
	if bonus_active and not reduced_motion:
		var arrival: float = clampf(_hud_bonus_age / 0.32, 0.0, 1.0)
		var pop_scale: float = 1.0 + 0.22 * sin(arrival * PI) - 0.2 * pow(1.0 - arrival, 2.0)
		var collect: float = smoothstep(1.35, HUD_BONUS_DURATION, _hud_bonus_age)
		var lift := Vector2(0, -7.0 * smoothstep(0.0, 0.65, _hud_bonus_age) / Style.ui_scale(self))
		var destination: Vector2 = time_label.position + time_label.size * 0.5 - _time_bonus_badge.size * 0.5
		_time_bonus_badge.position = (_time_bonus_anchor + lift).lerp(destination, collect)
		_time_bonus_badge.scale = Vector2.ONE * lerpf(pop_scale, 0.45, collect)
		_time_bonus_badge.modulate.a = 1.0 - collect
	if _bonus_fx != null:
		_bonus_fx.queue_redraw()
	if _hud_fx != null:
		_hud_fx.queue_redraw()
	_apply_chest_feedback()


func _apply_chest_feedback() -> void:
	if not is_instance_valid(_chest_overlay):
		return
	_chest_overlay.visible = _hud.visible and not _stopped
	var active: bool = _chest_fx_age < CHEST_FX_DURATION and _chest_overlay.visible
	_chest_badge.visible = active
	_chest_award_label.text = "+%d CHEST%s" % [_chest_fx_amount, "S" if _chest_fx_amount != 1 else ""] if active else ""
	_chest_award_caption.text = "%d OF %d EARNED" % [game.chest_count, PopModel.MAX_CHESTS]
	_chest_badge.pivot_offset = _chest_badge.size * 0.5
	_chest_badge.position = _chest_badge_anchor
	_chest_badge.scale = Vector2.ONE
	_chest_badge.modulate.a = 1.0
	_chest_count_label.scale = Vector2.ONE
	_chest_count_label.pivot_offset = _chest_count_label.size * 0.5
	if active and not reduced_motion:
		var arrival: float = clampf(_chest_fx_age / 0.4, 0.0, 1.0)
		var collect: float = smoothstep(1.55, CHEST_FX_DURATION, _chest_fx_age)
		var destination: Vector2 = _reward_hud.position + _chest_count_label.position + _chest_count_label.size * 0.5 - _chest_badge.size * 0.5
		var pop_scale: float = 1.0 + 0.2 * sin(arrival * PI) - 0.15 * pow(1.0 - arrival, 2.0)
		_chest_badge.position = (_chest_badge_anchor + Vector2(0, -8.0 * sin(arrival * PI) / Style.ui_scale(self))).lerp(destination, collect)
		_chest_badge.scale = Vector2.ONE * lerpf(pop_scale, 0.3, collect)
		_chest_badge.modulate.a = 1.0 - collect
		_chest_count_label.scale = Vector2.ONE * (1.0 + 0.13 * sin(clampf((_chest_fx_age - 1.4) / 0.55, 0.0, 1.0) * PI))
	_chest_fx.queue_redraw()


func _draw_chest_feedback() -> void:
	if not _chest_overlay.visible:
		return
	var scale: float = Style.ui_scale(self)
	var status := Rect2(_reward_hud.position, _reward_hud.size)
	_chest_fx.draw_style_box(Style.box(Color("#152039", 0.96), Color("#536485"), ceili(14.0 / scale), 1), status)
	var meter := Rect2(status.position + Vector2(12.0, 43.0) / scale, Vector2(status.size.x - 24.0 / scale, 4.0 / scale))
	_chest_fx.draw_style_box(Style.box(Color("#3d4a65"), Color.TRANSPARENT, ceili(2.0 / scale)), meter)
	if game.chest_progress() > 0.0:
		var filled: Rect2 = meter
		filled.size.x *= game.chest_progress()
		_chest_fx.draw_style_box(Style.box(CHEST_COLOR, Color.TRANSPARENT, ceili(2.0 / scale)), filled)
	if not _chest_badge.visible:
		return
	var alpha: float = _chest_badge.modulate.a
	var badge: Rect2 = _chest_badge.get_transform() * Rect2(Vector2.ZERO, _chest_badge.size)
	var radius: int = ceili(18.0 / scale)
	for spread in [14.0, 8.0, 3.0]:
		_chest_fx.draw_style_box(Style.box(Color(CHEST_COLOR, 0.05 * alpha), Color.TRANSPARENT, radius), badge.grow(spread / scale))
	_chest_fx.draw_style_box(Style.box(Color("#4a3217", 0.97 * alpha), Color(CHEST_COLOR, alpha), radius, maxi(1, ceili(2.0 / scale))), badge)
	_chest_fx.draw_style_box(Style.box(Color(CHEST_COLOR, 0.06 * alpha), Color(WHITE, 0.25 * alpha), maxi(1, radius - 4), 1), badge.grow(-4.0 / scale))
	_chest_fx.draw_style_box(Style.box(Color(CHEST_COLOR, 0.08), Color(CHEST_COLOR, 0.8), ceili(14.0 / scale), 1), status)
	if reduced_motion:
		return
	var center: Vector2 = _chest_badge_anchor + _chest_badge.size * 0.5
	var burst: float = clampf(_chest_fx_age / 0.75, 0.0, 1.0)
	var burst_alpha: float = 1.0 - smoothstep(0.3, 1.0, burst)
	for index in range(14):
		var angle: float = float(index) * TAU / 14.0
		var direction := Vector2(cos(angle), sin(angle) * 0.72)
		var point: Vector2 = center + direction * (56.0 + 34.0 * burst) / scale
		_chest_fx.draw_line(point, point + direction * (12.0 - burst * 9.0) / scale,
			Color(CHEST_COLOR if index % 2 == 0 else WHITE, burst_alpha), 2.5 / scale, true)
	var destination: Vector2 = _reward_hud.position + _chest_count_label.position + _chest_count_label.size * 0.5
	for index in range(9):
		var travel: float = clampf((_chest_fx_age - 0.5 - float(index) * 0.055) / 1.0, 0.0, 1.0)
		if travel <= 0.0 or travel >= 1.0:
			continue
		var start: Vector2 = center + Vector2(cos(float(index) * 2.4) * 66.0, sin(float(index) * 2.4) * 26.0) / scale
		var point: Vector2 = start.lerp(destination, travel) + Vector2(24.0 * sin(travel * PI), 0.0) / scale
		var mote_alpha: float = sin(travel * PI)
		_chest_fx.draw_circle(point, 6.0 / scale, Color(CHEST_COLOR, 0.15 * mote_alpha))
		_chest_fx.draw_circle(point, 2.2 / scale, Color(WHITE, mote_alpha))


func _draw_hud_feedback() -> void:
	if not _hud.visible:
		return
	if _hud_hit_age >= HUD_HIT_DURATION:
		return
	var scale: float = Style.ui_scale(self)
	var progress: float = _hud_hit_age / HUD_HIT_DURATION
	var alpha: float = 1.0 if reduced_motion else 1.0 - smoothstep(0.48, 1.0, progress)
	var speech: Rect2 = Rect2(transcript_label.position, transcript_label.size)
	var count: Rect2 = Rect2(hits_label.position, hits_label.size)
	var center: Vector2 = count.get_center()
	var highlight: Rect2 = Rect2(count.position - Vector2(2, 0) / scale, count.size + Vector2(4, 16) / scale)
	_hud_fx.draw_style_box(Style.box(Color(HIT_COLOR, 0.12 * alpha), Color(HIT_COLOR, 0.45 * alpha), ceili(12.0 / scale), 1), highlight)
	if reduced_motion:
		if _hud_transcript_hit:
			_hud_fx.draw_line(Vector2(speech.position.x + 8.0 / scale, speech.end.y),
				Vector2(speech.end.x - 8.0 / scale, speech.end.y), HIT_COLOR, 2.0 / scale, true)
		return
	var sweep: float = smoothstep(0.0, 0.36, progress)
	var half_span: float = maxf(0.0, speech.size.x * 0.5 - 8.0 / scale) * sweep
	var underline := Vector2(speech.get_center().x, speech.end.y - 2.0 / scale)
	if _hud_transcript_hit:
		_hud_fx.draw_line(underline - Vector2(half_span, 0), underline + Vector2(half_span, 0), Color(HIT_COLOR, 0.22 * alpha), 7.0 / scale, true)
		_hud_fx.draw_line(underline - Vector2(half_span, 0), underline + Vector2(half_span, 0), Color(HIT_COLOR, alpha), 2.0 / scale, true)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = ceili(16.0 / scale)
	var addition: String = "+%d" % _hud_hit_amount
	var text_width: float = font.get_string_size(addition, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var lift: float = 15.0 * sin(progress * PI * 0.5) / scale
	_hud_fx.draw_string(font, Vector2(center.x - text_width * 0.5, count.end.y + 39.0 / scale - lift),
		addition, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(HIT_COLOR, alpha))
	for index in range(7):
		var angle: float = float(index) * TAU / 7.0 - PI * 0.5
		var radius: float = (15.0 + 28.0 * sin(progress * PI * 0.5)) / scale
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * Vector2(radius, radius * 0.7)
		var reach: float = (3.0 + sin(progress * PI) * 2.0) / scale
		_hud_fx.draw_line(point - Vector2(reach, 0), point + Vector2(reach, 0), Color(HIT_COLOR, alpha), 1.5 / scale, true)
		_hud_fx.draw_line(point - Vector2(0, reach), point + Vector2(0, reach), Color(WHITE, alpha), 1.5 / scale, true)


func _draw_time_bonus() -> void:
	if not _bonus_overlay.visible:
		return
	var scale: float = Style.ui_scale(self)
	var alpha: float = _time_bonus_badge.modulate.a
	var rect: Rect2 = _time_bonus_badge.get_transform() * Rect2(Vector2.ZERO, _time_bonus_badge.size)
	var radius: int = ceili(17.0 / scale)
	for glow in [12.0, 7.0, 3.0]:
		_bonus_fx.draw_style_box(Style.box(Color(BONUS_COLOR, 0.05 * alpha), Color.TRANSPARENT, radius), rect.grow(glow / scale))
	_bonus_fx.draw_style_box(Style.box(Color("#453519", 0.97 * alpha), Color(BONUS_COLOR, alpha), radius, maxi(1, ceili(2.0 / scale))), rect)
	_bonus_fx.draw_style_box(Style.box(Color(BONUS_COLOR, 0.08 * alpha), Color(WHITE, 0.32 * alpha), maxi(1, radius - 3), 1), rect.grow(-4.0 / scale))
	var timer := Rect2(time_label.position, time_label.size)
	_bonus_fx.draw_style_box(Style.box(Color(BONUS_COLOR, 0.08 * alpha), Color(BONUS_COLOR, 0.65 * alpha), ceili(12.0 / scale), 1), timer.grow(3.0 / scale))
	if reduced_motion:
		return
	var burst: float = clampf(_hud_bonus_age / 0.65, 0.0, 1.0)
	var burst_alpha: float = 1.0 - smoothstep(0.3, 1.0, burst)
	var center: Vector2 = _time_bonus_anchor + _time_bonus_badge.size * 0.5
	for index in range(12):
		var angle: float = TAU * float(index) / 12.0
		var direction := Vector2(cos(angle), sin(angle) * 0.66)
		var reach: float = (43.0 + 30.0 * burst) / scale
		var point: Vector2 = center + direction * reach
		_bonus_fx.draw_line(point, point + direction * (10.0 * (1.0 - burst) + 3.0) / scale,
			Color(BONUS_COLOR if index % 2 == 0 else CYAN, burst_alpha), 2.5 / scale, true)
	# Bright motes curve into the countdown as the large reward badge settles.
	for index in range(8):
		var travel: float = clampf((_hud_bonus_age - 0.35 - float(index) * 0.07) / 0.85, 0.0, 1.0)
		if travel <= 0.0 or travel >= 1.0:
			continue
		var direction := Vector2(cos(float(index) * 2.4), sin(float(index) * 2.4))
		var start: Vector2 = center + direction * Vector2(64.0, 35.0) / scale
		var destination: Vector2 = timer.get_center()
		var point: Vector2 = start.lerp(destination, travel) + Vector2(26.0 * sin(travel * PI), 0.0) / scale
		var mote_alpha: float = sin(travel * PI)
		_bonus_fx.draw_circle(point, 6.0 / scale, Color(BONUS_COLOR, 0.18 * mote_alpha))
		_bonus_fx.draw_circle(point, 2.4 / scale, Color(WHITE, mote_alpha))
	for delay in [0.0, 1.18]:
		var ring: float = clampf((_hud_bonus_age - delay) / 0.6, 0.0, 1.0)
		if ring > 0.0 and ring < 1.0:
			_bonus_fx.draw_arc(timer.get_center(), (22.0 + 18.0 * ring) / scale, 0.0, TAU, 48,
				Color(BONUS_COLOR, (1.0 - ring) * 0.8), 2.5 / scale, true)


func _layout() -> void:
	if _hud == null:
		return
	var scale: float = Style.ui_scale(self)
	_rescale_content(self, scale)
	custom_minimum_size = Vector2(180, 160) / scale
	var edge: float = 16.0 / scale
	var width: float = maxf(0.0, size.x - edge * 2.0)
	_hud.position = Vector2.ZERO
	_hud.size = size
	_bonus_overlay.position = Vector2.ZERO
	_bonus_overlay.size = size
	_chest_overlay.position = Vector2.ZERO
	_chest_overlay.size = size
	var reward_width: float = minf(width, 340.0 / scale)
	_reward_hud.position = Vector2((size.x - reward_width) * 0.5, maxf(0.0, size.y - 64.0 / scale))
	_reward_hud.size = Vector2(reward_width, 52.0 / scale)
	var reward_font: int = 12 if reward_width * scale < 280.0 else 13
	_place_label(_score_label, Rect2(12.0 / scale, 5.0 / scale, reward_width * 0.48 - 12.0 / scale, 19.0 / scale), reward_font)
	_place_label(_chest_count_label, Rect2(reward_width * 0.48, 5.0 / scale, reward_width * 0.52 - 12.0 / scale, 19.0 / scale), reward_font)
	_place_label(_chest_progress_label, Rect2(12.0 / scale, 25.0 / scale, reward_width - 24.0 / scale, 14.0 / scale), 10)
	_chest_badge.size = Vector2(minf(width, 190.0 / scale), 74.0 / scale)
	_place_label(_chest_award_label, Rect2(6.0 / scale, 9.0 / scale, _chest_badge.size.x - 12.0 / scale, 35.0 / scale), 26)
	_place_label(_chest_award_caption, Rect2(6.0 / scale, 46.0 / scale, _chest_badge.size.x - 12.0 / scale, 19.0 / scale), 10)
	var side: float = minf(72.0 / scale, width * 0.22)
	_place_label(time_label, Rect2(edge, 13 / scale, side, 46 / scale), 30)
	_time_bonus_badge.size = Vector2(minf(140.0 / scale, width - 8.0 / scale), 72.0 / scale)
	_time_bonus_anchor = Vector2(edge + 4.0 / scale, 80.0 / scale)
	_place_label(_time_bonus_label, Rect2(4.0 / scale, 2.0 / scale, _time_bonus_badge.size.x - 8.0 / scale, 46.0 / scale), 34)
	_place_label(_time_bonus_caption, Rect2(4.0 / scale, 50.0 / scale, _time_bonus_badge.size.x - 8.0 / scale, 18.0 / scale), 10)
	# Leave room for both arrival pulses when a hit earns time and a chest together.
	_chest_badge_anchor = Vector2((size.x - _chest_badge.size.x) * 0.5,
		_time_bonus_anchor.y + _time_bonus_badge.size.y + 34.0 / scale)
	if size.x * scale >= 440.0:
		_chest_badge_anchor.x = maxf(_chest_badge_anchor.x,
			_time_bonus_anchor.x + _time_bonus_badge.size.x + 44.0 / scale)
		_chest_badge_anchor.y = _time_bonus_anchor.y
	_place_label(hits_label, Rect2(size.x - edge - side, 12 / scale, side, 35 / scale), 28)
	_place_label(_hits_caption, Rect2(size.x - edge - side, 45 / scale, side, 14 / scale), 9)
	var speech_x: float = edge + side + 8.0 / scale
	var speech_width: float = maxf(1.0, width - side * 2.0 - 16.0 / scale)
	var speech_height: float = 44.0 / scale
	_place_label(transcript_label, Rect2(speech_x, 12.0 / scale, speech_width, speech_height), 16 if size.x * scale < 360.0 else 19)
	# Font ascent/descent and line spacing can exceed the nominal font size.
	# Reserve two actual lines instead of clipping the second at some UI scales.
	speech_height = maxf(speech_height, 2.0 * transcript_label.get_line_height() + transcript_label.get_theme_constant("line_spacing"))
	transcript_label.size.y = speech_height
	_update_transcript_window()
	_place_label(_live_caption, Rect2(edge, 16.0 / scale + speech_height, width, 19.0 / scale), 10)
	var top: float = 10.0 / scale
	_arena = Rect2(edge, top, width, maxf(64.0 / scale, size.y - top - 18.0 / scale))
	_slice_clip.position = _arena.position
	_slice_clip.size = _arena.size
	_slice_canvas.queue_redraw()
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
	if is_instance_valid(_result_hero):
		var compact: bool = size.y * scale < 350.0
		_result_hero.custom_minimum_size.y = (104.0 if compact else 156.0) / scale
		_layout_result_hits()
	if is_instance_valid(_result_actions):
		_result_actions.add_theme_constant_override("separation", ceili(8.0 / scale))
		_style_action(chests_button, not chests_button.disabled)
		_style_action(replay_button, chests_button.disabled)
		for button in [chests_button, replay_button]:
			button.custom_minimum_size.y = 52.0 / scale
			button.add_theme_font_size_override("font_size", ceili((14.0 if result_width * scale < 360.0 else 18.0) / scale))
	for grid in _review_grids:
		grid.columns = 3 if result_width * scale >= 650.0 else 2 if result_width * scale >= 360.0 else 1
		grid.add_theme_constant_override("h_separation", ceili(8.0 / scale))
		grid.add_theme_constant_override("v_separation", ceili(8.0 / scale))
	for button in _review_buttons:
		button.custom_minimum_size = Vector2(0.0, 66.0 / scale)
	_apply_hud_feedback()
	_refresh_targets()
	queue_redraw()
	_queue_geometry_publish()


func _refresh_targets() -> void:
	_draw_targets.clear()
	if _target_canvas != null:
		_target_canvas.queue_redraw()
	if _arena.size.x <= 0.0 or _arena.size.y <= 0.0 or game.phase not in ["running", "paused"]:
		return
	var scale: float = Style.ui_scale(self)
	# Give the cards more flight height without increasing their illustrated size.
	var card_space_height: float = maxf(64.0 / scale, _arena.size.y - (110.0 if size.y * scale < 350.0 else 124.0) / scale)
	var capsule_width: float = clampf(minf(_arena.size.x * 0.43, card_space_height * 0.57), 112.0 / scale, 202.0 / scale)
	var capsule_height: float = minf(clampf(capsule_width * 0.83, 96.0 / scale, 162.0 / scale), card_space_height - 4.0 / scale)
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
		var apex: float = highest + maxf(0.0, bottom - highest) * float(target.peak) * 0.08
		if bool(target.get("volley", false)) and lane == 1:
			# A lower center throw fans simultaneous cards apart on portrait fields.
			# Keep the offset on the target so hitting its neighbors cannot change its flight.
			var portrait_fan: float = clampf((1.25 - _arena.size.x / _arena.size.y) / 0.35, 0.0, 1.0)
			apex = minf(bottom, apex + capsule_height * 1.6 * portrait_fan)
		var y: float = bottom - (bottom - apex) * 4.0 * progress * (1.0 - progress)
		var tilt: float = float(target.spin) * sin(progress * PI)
		if reduced_motion:
			tilt = 0.0
			var still_top: float = minf(bottom, maxf(highest, _live_caption.get_rect().end.y + capsule_height * 0.5 + 10.0 / scale))
			if _arena.size.x >= _arena.size.y * 1.25:
				x = _arena.position.x + capsule_width * 0.5 + room * float(lane) * 0.5
				y = clampf((_arena.position.y + _arena.end.y) * 0.5, still_top, bottom)
			else:
				x = _arena.position.x + capsule_width * 0.5 + room * (0.0 if lane == 0 else 1.0 if lane == 1 else 0.5)
				y = still_top if lane != 2 else bottom
		var center := Vector2(x, y)
		if not reduced_motion:
			for burst in _bursts:
				var age: float = float(burst.age)
				if age < 0.14 and center.distance_to(burst.center) < 150.0 / scale:
					center += Vector2(sin(age * 100.0), cos(age * 85.0)) * (1.0 - age / 0.14) * 3.0 / scale
		_draw_targets.append({"uid": int(target.uid), "word": target.word, "forms": target.get("forms", []), "center": center,
			"size": capsule_size, "rotation": tilt, "progress": progress, "lane": lane,
			"age": float(target.age), "spawned_at": float(target.get("spawned_at", game.elapsed - float(target.age)))})


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
		var side: float = time_label.size.x
		for x in [16.0 / scale, size.x - 16.0 / scale - side]:
			draw_style_box(Style.box(SURFACE, Color("#2d3a5c"), ceili(13.0 / scale), 1), Rect2(x, 10.0 / scale, side, 52.0 / scale))


func _draw_flying_targets() -> void:
	if _hud == null or not _hud.visible:
		return
	var scale: float = Style.ui_scale(self)
	for target in _draw_targets:
		_draw_capsule(target, scale)


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
	_target_canvas.draw_set_transform(target.center, target.rotation)
	var shadow: StyleBoxFlat = Style.box(Color(0.0, 0.0, 0.0, 0.3), Color.TRANSPARENT, ceili(21.0 / scale), 0)
	_target_canvas.draw_style_box(shadow, Rect2(rect.position + Vector2(0, 6.0 / scale), capsule_size))
	_target_canvas.draw_style_box(Style.box(Color(accent, 0.10), Color(accent, 0.20), ceili(24.0 / scale), maxi(1, roundi(2.0 / scale))), rect.grow(4.0 / scale))
	_target_canvas.draw_style_box(Style.box(accent, accent.lightened(0.45), ceili(19.0 / scale), maxi(1, roundi(2.0 / scale))), rect)
	_target_canvas.draw_line(rect.position + Vector2(19.0 / scale, 5.0 / scale), Vector2(rect.end.x - 19.0 / scale, rect.position.y + 5.0 / scale), Color(1, 1, 1, 0.65), 2.0 / scale, true)
	var art_edge: float = minf(capsule_size.x - 28.0 / scale, capsule_size.y * 0.61)
	var art_center := Vector2(0, rect.position.y + 10.0 / scale + art_edge * 0.5)
	_target_canvas.draw_circle(art_center, art_edge * 0.52, Color("#fffaf2"))
	var texture: Texture2D = _textures.get(str(target.word.get("id", target.word.get("text", ""))), null)
	if texture != null:
		var original: Vector2 = texture.get_size()
		var art_size: Vector2 = original * minf(art_edge / maxf(1.0, original.x), art_edge / maxf(1.0, original.y))
		_target_canvas.draw_texture_rect(texture, Rect2(art_center - art_size * 0.5, art_size), false)
	var word: String = str(target.word.get("text", ""))
	var font: Font = ThemeDB.fallback_font
	var font_size: int = ceili(clampf(capsule_size.x * scale * 0.17, 18.0, 26.0) / scale)
	while font_size > ceili(13.0 / scale) and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > capsule_size.x - 16.0 / scale:
		font_size -= 1
	var text_width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: float = rect.end.y - 11.0 / scale
	_target_canvas.draw_string(font, Vector2(-text_width * 0.5, baseline), word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("#243454"))
	_target_canvas.draw_set_transform(Vector2.ZERO)


func _clear_slices() -> void:
	_bursts.clear()
	if is_instance_valid(_slice_canvas):
		_slice_canvas.queue_redraw()


func _advance_slices(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	for index in range(_bursts.size() - 1, -1, -1):
		_bursts[index].age = float(_bursts[index].age) + delta
		if float(_bursts[index].age) >= (Slice.STILL_DURATION if reduced_motion else Slice.DURATION):
			_bursts.remove_at(index)


func slice_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for burst in _bursts:
		var first: Dictionary = Slice.pose(burst, -1.0, reduced_motion)
		var second: Dictionary = Slice.pose(burst, 1.0, reduced_motion)
		result.append({"uid": burst.uid, "word": str(burst.word.text), "age": burst.age,
			"center": burst.center, "size": burst.size, "rotation": burst.rotation,
			"first_offset": first.offset, "second_offset": second.offset,
			"first_rotation": first.rotation, "second_rotation": second.rotation,
			"alpha": first.alpha, "strength": burst.strength, "reduced_motion": reduced_motion})
	return result


func _draw_slices() -> void:
	if _hud == null or not _hud.visible:
		return
	var scale: float = Style.ui_scale(self)
	for burst in _bursts:
		var age: float = float(burst.age)
		var center: Vector2 = burst.center - _arena.position
		var accent: Color = burst.color
		if reduced_motion:
			var alpha: float = float(Slice.pose(burst, 1.0, true).alpha)
			_slice_canvas.draw_set_transform(center, float(burst.rotation))
			var seam: PackedVector2Array = _slice_seam(burst, scale)
			_slice_canvas.draw_line(seam[0], seam[1], Color(accent, alpha * 0.35), 9.0 / scale, true)
			_slice_canvas.draw_line(seam[0], seam[1], Color(WHITE, alpha), 2.5 / scale, true)
			_slice_canvas.draw_set_transform(Vector2.ZERO)
			_draw_slice_score(burst, center, scale, 0.0, alpha)
			continue
		_draw_slice_splash(burst, center, scale)
		for side in [-1.0, 1.0]:
			_draw_slice_half(burst, center, side, scale)
		_draw_slice_droplets(burst, center, scale)
		if age < Slice.BLADE_DURATION:
			_slice_canvas.draw_set_transform(center, float(burst.rotation))
			var flash: float = 1.0 - smoothstep(0.045, Slice.BLADE_DURATION, age)
			_slice_canvas.draw_colored_polygon(Slice.blade_ribbon(burst, 12.0 * float(burst.strength), scale), Color(accent, flash * 0.42))
			_slice_canvas.draw_colored_polygon(Slice.blade_ribbon(burst, 6.0 * float(burst.strength), scale), Color(accent.lightened(0.5), flash * 0.85))
			_slice_canvas.draw_colored_polygon(Slice.blade_ribbon(burst, 2.7, scale), Color(WHITE, flash))
			_slice_canvas.draw_set_transform(Vector2.ZERO)
		_draw_slice_score(burst, center, scale, clampf(age / Slice.DURATION, 0.0, 1.0),
			1.0 - smoothstep(0.45, Slice.DURATION, age))


func _slice_seam(burst: Dictionary, scale: float) -> PackedVector2Array:
	return Slice.seam(burst.size, 19.0 / scale, int(burst.uid))


func _draw_slice_half(burst: Dictionary, center: Vector2, side: float, scale: float) -> void:
	var pose: Dictionary = Slice.pose(burst, side)
	var alpha: float = float(pose.alpha)
	var accent: Color = burst.color
	var capsule_size: Vector2 = burst.size
	var normal: Vector2 = Slice.normal(int(burst.uid))
	var origin: Vector2 = Slice.cut_origin(capsule_size)
	var polygon: PackedVector2Array = Slice.clip_half(Slice.rounded_rect(capsule_size, 19.0 / scale), origin, normal, side)
	_slice_canvas.draw_set_transform(center + pose.offset + Vector2(0, 5.0 / scale), float(burst.rotation) + float(pose.rotation))
	_slice_canvas.draw_colored_polygon(polygon, Color(0, 0, 0, alpha * 0.25))
	_slice_canvas.draw_set_transform(center + pose.offset, float(burst.rotation) + float(pose.rotation))
	_slice_canvas.draw_colored_polygon(polygon, Color(accent, alpha))
	var outline: PackedVector2Array = polygon.duplicate()
	outline.append(outline[0])
	_slice_canvas.draw_polyline(outline, Color(accent.lightened(0.45), alpha), 2.0 / scale, true)
	var art_edge: float = minf(capsule_size.x - 28.0 / scale, capsule_size.y * 0.61)
	var art_center := Vector2(0, -capsule_size.y * 0.5 + 10.0 / scale + art_edge * 0.5)
	var disc := PackedVector2Array()
	for index in range(32):
		var angle: float = float(index) * TAU / 32.0
		disc.append(art_center + Vector2(cos(angle), sin(angle)) * art_edge * 0.52)
	var half_disc: PackedVector2Array = Slice.clip_half(disc, origin, normal, side)
	if half_disc.size() >= 3:
		_slice_canvas.draw_colored_polygon(half_disc, Color(Color("#fffaf2"), alpha))
	var texture: Texture2D = _textures.get(str(burst.word.get("id", burst.word.get("text", ""))), null)
	if texture != null:
		var original: Vector2 = texture.get_size()
		var art_size: Vector2 = original * minf(art_edge / maxf(1.0, original.x), art_edge / maxf(1.0, original.y))
		var art_rect := Rect2(art_center - art_size * 0.5, art_size)
		var art_polygon := PackedVector2Array([art_rect.position, Vector2(art_rect.end.x, art_rect.position.y),
			art_rect.end, Vector2(art_rect.position.x, art_rect.end.y)])
		art_polygon = Slice.clip_half(art_polygon, origin, normal, side)
		if art_polygon.size() >= 3:
			_slice_canvas.draw_polygon(art_polygon, PackedColorArray([Color(1, 1, 1, alpha)]), Slice.texture_uv(art_polygon, art_rect), texture)
	# The cut crosses the illustration; the readable word remains on the lower half.
	if side > 0.0:
		_draw_slice_word(burst, capsule_size, scale, alpha)
	var seam: PackedVector2Array = _slice_seam(burst, scale)
	_slice_canvas.draw_line(seam[0] + normal * side * 1.5 / scale, seam[1] + normal * side * 1.5 / scale,
		Color(accent.darkened(0.28), alpha), 4.0 / scale, true)
	_slice_canvas.draw_line(seam[0], seam[1], Color(accent.lightened(0.7), alpha), 2.0 / scale, true)
	_slice_canvas.draw_set_transform(Vector2.ZERO)


func _draw_slice_word(burst: Dictionary, capsule_size: Vector2, scale: float, alpha: float) -> void:
	var word: String = str(burst.word.text)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = ceili(clampf(capsule_size.x * scale * 0.17, 18.0, 26.0) / scale)
	while font_size > ceili(13.0 / scale) and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > capsule_size.x - 16.0 / scale:
		font_size -= 1
	var width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_slice_canvas.draw_string(font, Vector2(-width * 0.5, capsule_size.y * 0.5 - 11.0 / scale), word,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(Color("#243454"), alpha))


func _draw_slice_splash(burst: Dictionary, center: Vector2, scale: float) -> void:
	var age: float = float(burst.age)
	if age >= 0.34:
		return
	var accent: Color = burst.color
	var fade: float = (1.0 - age / 0.34) * 0.22
	var radius: float = (18.0 + 16.0 * smoothstep(0.0, 0.1, age)) * float(burst.strength) / scale
	var polygon := PackedVector2Array()
	for index in range(20):
		var angle: float = float(index) * TAU / 20.0
		var reach: float = radius * (1.0 if index % 2 else 1.6)
		polygon.append(center + Vector2(cos(angle), sin(angle) * 0.76) * reach)
	_slice_canvas.draw_colored_polygon(polygon, Color(accent, fade))


func _draw_slice_droplets(burst: Dictionary, center: Vector2, scale: float) -> void:
	var age: float = maxf(0.0, float(burst.age) - Slice.IMPACT_HOLD)
	var fade: float = 1.0 - smoothstep(0.25, 0.65, age)
	if fade <= 0.0:
		return
	var accent: Color = burst.color
	var normal: Vector2 = Slice.normal(int(burst.uid)).rotated(float(burst.rotation))
	var origin: Vector2 = center + Slice.cut_origin(burst.size).rotated(float(burst.rotation))
	for index in range(12):
		var angle: float = float((index * 7 + int(burst.uid) * 3) % 13) / 12.0 - 0.5
		var direction: Vector2 = normal.rotated(angle * 1.5) * (-1.0 if index % 2 else 1.0)
		var speed: float = (112.0 + float((index * 23 + int(burst.uid) * 11) % 100)) * float(burst.strength) / scale
		var point: Vector2 = origin + direction * speed * age + Vector2(0, 230.0 * age * age / scale)
		var side: float = (2.5 + float(index % 3) * 1.1) * (1.0 - age * 0.6) / scale
		var across: Vector2 = direction.orthogonal()
		var droplet := PackedVector2Array([point + direction * side * 2.0, point + across * side,
			point - direction * side * 0.8, point - across * side])
		_slice_canvas.draw_colored_polygon(droplet, Color(accent, fade * 0.9))
		_slice_canvas.draw_circle(point - across * side * 0.25, side * 0.3, Color(accent.lightened(0.65), fade))


func _draw_slice_score(burst: Dictionary, center: Vector2, scale: float, progress: float, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	var label: String = "+%d" % int(burst.points)
	var font_size: int = ceili(25.0 / scale)
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var point: Vector2 = center + Vector2(-width * 0.5, -float(burst.size.y) * 0.48 - progress * 24.0 / scale)
	point.x = clampf(point.x, 3.0 / scale, maxf(3.0 / scale, _arena.size.x - width - 3.0 / scale))
	point.y = clampf(point.y, float(font_size), maxf(float(font_size), _arena.size.y - 4.0 / scale))
	_slice_canvas.draw_string(font, point + Vector2(0, 2.0 / scale), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(NAVY, alpha))
	_slice_canvas.draw_string(font, point, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(WHITE, alpha))


func _finish() -> void:
	_finished_sent = true
	_listening = false
	_listening_tick_usec = -1
	_clear_transcript()
	_message = "Round complete. Tap a word to hear it, or play again."
	_draw_targets.clear()
	_clear_slices()
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
	_result_hit_total = maxi(0, int(summary.get("hits", 0)))
	_result_hit_age = RESULT_HIT_DURATION if reduced_motion else 0.0
	_result_idle_time = 0.0
	_result_hero = Control.new()
	_result_hero.name = "ResultHits"
	_result_hero.mouse_filter = Control.MOUSE_FILTER_PASS
	_result_hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_body.add_child(_result_hero)
	_result_hit_fx = Node2D.new()
	_result_hit_fx.draw.connect(_draw_result_feedback)
	_result_hero.add_child(_result_hit_fx)
	_result_player = HBoxContainer.new()
	_result_player.name = "ResultPlayer"
	_result_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_hero.add_child(_result_player)
	_result_avatar = TextureRect.new()
	_result_avatar.name = "PlayerAvatar"
	_result_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_result_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_result_player.add_child(_result_avatar)
	_result_name = _label("", 22)
	_result_name.name = "PlayerName"
	_result_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_result_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_name.clip_text = true
	_result_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_result_player.add_child(_result_name)
	_refresh_result_player()
	_result_hits = _label("0", 68, CYAN)
	_result_hits.name = "HitTotal"
	_result_hits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_hits.add_theme_color_override("font_shadow_color", Color(CYAN, 0.5))
	_result_hits.add_theme_constant_override("shadow_outline_size", 6)
	_result_hero.add_child(_result_hits)
	_result_hits_caption = _label("HITS", 14, HIT_COLOR)
	_result_hits_caption.name = "HitsCaption"
	_result_hits_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_hero.add_child(_result_hits_caption)
	_result_hero.resized.connect(_layout_result_hits)
	_result_actions = HBoxContainer.new()
	_result_body.add_child(_result_actions)
	var earned_chests: int = clampi(int(summary.get("chest_count", 0)), 0, PopModel.MAX_CHESTS)
	chests_button = _action("Open chests (%d)" % earned_chests, earned_chests > 0)
	chests_button.name = "OpenChests"
	chests_button.disabled = earned_chests == 0
	chests_button.tooltip_text = "Earn a chest every 100 points, up to 3 per round." if earned_chests == 0 else "Open every chest you earned this round."
	chests_button.pressed.connect(_open_chests)
	chests_button.mouse_filter = Control.MOUSE_FILTER_PASS
	chests_button.focus_entered.connect(func() -> void: _ensure_result_control(chests_button))
	_result_actions.add_child(chests_button)
	replay_button = _action("Play again", earned_chests == 0)
	replay_button.name = "Replay"
	replay_button.pressed.connect(_replay)
	replay_button.mouse_filter = Control.MOUSE_FILTER_PASS
	replay_button.focus_entered.connect(func() -> void: _ensure_result_control(replay_button))
	_result_actions.add_child(replay_button)
	_add_review("Words you popped", summary.get("hit_words", []), CYAN)
	_add_review("Try these next time", summary.get("missed_words", []), PINK)
	# Leave room for the final row and its focus outline at fractional UI scales.
	var bottom_space := Control.new()
	bottom_space.custom_minimum_size.y = 8.0 / Style.ui_scale(self)
	bottom_space.set_meta("pop_min_height", 8.0)
	bottom_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_body.add_child(bottom_space)
	_layout()
	_apply_result_feedback()


func attach_leaderboard(panel: Control) -> void:
	if game.phase != "finished":
		panel.queue_free()
		return
	_result_body.add_child(panel)
	_result_body.move_child(panel, 2)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.minimum_size_changed.connect(_layout)
	_layout()


func set_round_player(profile: Dictionary) -> void:
	_round_player = profile.duplicate(true)
	_refresh_result_player()
	_layout_result_hits()
	_queue_geometry_publish()


func _refresh_result_player() -> void:
	if not is_instance_valid(_result_player):
		return
	_result_player.visible = not _round_player.is_empty()
	_result_name.text = str(_round_player.get("name", ""))
	_result_name.tooltip_text = _result_name.text
	var path: String = "res://assets/avatars/" + str(_round_player.get("avatar", "duck")) + ".svg"
	_result_avatar.texture = load(path) if ResourceLoader.exists(path) else null


func _result_rect(control: Control) -> Array:
	var rect: Rect2 = control.get_global_rect()
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _result_hits_snapshot() -> Dictionary:
	var visible_result: bool = not _stopped and game.phase == "finished" and _results.visible
	var player: Dictionary = {}
	if visible_result and not _round_player.is_empty() and is_instance_valid(_result_player):
		player = _round_player.duplicate(true)
		player["rect"] = _result_rect(_result_player)
		player["avatar_rect"] = _result_rect(_result_avatar)
		player["name_rect"] = _result_rect(_result_name)
	return {"text": _result_hits.text if visible_result and is_instance_valid(_result_hits) else "",
		"total": _result_hit_total if visible_result else 0,
		"player": player, "rect": _result_rect(_result_hits) if visible_result and is_instance_valid(_result_hits) else [],
		"active": visible_result and not reduced_motion and _result_hit_age < RESULT_HIT_DURATION}


func _layout_result_hits() -> void:
	if not is_instance_valid(_result_hero) or not is_instance_valid(_result_hits):
		return
	var scale: float = Style.ui_scale(self)
	var compact: bool = size.y * scale < 350.0
	var number_height: float = (68.0 if compact else 96.0) / scale
	var top: float = (6.0 if compact else 18.0) / scale
	var score_left: float = 0.0
	var score_width: float = _result_hero.size.x
	if not _round_player.is_empty():
		var group_width: float = minf(_result_hero.size.x, 480.0 / scale)
		var group_left: float = (_result_hero.size.x - group_width) * 0.5
		score_width = minf(160.0 / scale, group_width * 0.38)
		score_left = group_left + group_width - score_width
		var avatar_edge: float = (44.0 if compact else 56.0) / scale
		_result_player.position = Vector2(group_left, top + (number_height - avatar_edge) * 0.5)
		_result_player.size = Vector2(group_width - score_width - 16.0 / scale, avatar_edge)
		_result_player.add_theme_constant_override("separation", ceili(10.0 / scale))
		_result_avatar.custom_minimum_size = Vector2.ONE * avatar_edge
		_result_name.add_theme_font_size_override("font_size", ceili((18.0 if group_width * scale < 360.0 else 24.0) / scale))
	var number_font: int = 52 if compact else 76
	var text_width: float = _result_hits.get_theme_font("font").get_string_size(str(_result_hit_total), HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(number_font / scale)).x
	if text_width > score_width:
		number_font = maxi(18, floori(number_font * score_width / text_width))
	_place_label(_result_hits, Rect2(score_left, top, score_width, number_height), number_font)
	_place_label(_result_hits_caption, Rect2(score_left, top + number_height, score_width, 24.0 / scale), 14)
	_apply_result_feedback()


func _settle_result_feedback() -> void:
	_result_hit_age = RESULT_HIT_DURATION
	_result_idle_time = 0.0
	_apply_result_feedback()
	if is_instance_valid(_results) and _results.visible and game.phase == "finished" and not _stopped:
		_publish(true)


func _advance_result_feedback(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta) or _stopped or game.phase != "finished" or not _results.visible:
		return
	var before: Dictionary = _result_hits_snapshot()
	_result_hit_age = minf(RESULT_HIT_DURATION, _result_hit_age + delta)
	_result_idle_time += minf(delta, 0.1)
	_apply_result_feedback()
	if before != _result_hits_snapshot():
		_publish(true)


func _apply_result_feedback() -> void:
	if not is_instance_valid(_result_hits):
		return
	var progress: float = clampf(_result_hit_age / 0.82, 0.0, 1.0)
	var displayed: int = _result_hit_total if reduced_motion or progress >= 1.0 else floori(_result_hit_total * (1.0 - pow(1.0 - progress, 3.0)))
	_result_hits.text = str(displayed)
	var bounce: float = 0.0 if reduced_motion else sin(clampf((_result_hit_age - 0.74) / 0.42, 0.0, 1.0) * PI) * 0.18
	_result_hits.pivot_offset = _result_hits.size * 0.5
	_result_hits.scale = Vector2.ONE * (1.0 + bounce)
	_result_hits.add_theme_color_override("font_color", CYAN.lerp(WHITE, bounce * 3.0))
	if is_instance_valid(_result_hit_fx):
		_result_hit_fx.queue_redraw()


func _draw_result_feedback() -> void:
	if not is_instance_valid(_result_hits) or not _results.visible:
		return
	var scale: float = Style.ui_scale(self)
	var center: Vector2 = _result_hits.position + _result_hits.size * 0.5
	var compact: bool = size.y * scale < 350.0
	var radius: float = (25.0 if compact else 42.0) / scale
	var breath: float = 1.0 if reduced_motion else 0.92 + sin(_result_idle_time * 1.7) * 0.08
	for layer in range(5, 0, -1):
		_result_hit_fx.draw_circle(center, radius * (0.75 + float(layer) * 0.16), Color(CYAN, 0.025 * breath))
	var span: float = minf(_result_hero.size.x * 0.30, 150.0 / scale)
	for direction in ([-1.0, 1.0] if _round_player.is_empty() else []):
		var first: Vector2 = center + Vector2(direction * radius * 1.4, 0)
		var last: Vector2 = center + Vector2(direction * span, 0)
		_result_hit_fx.draw_line(first, last, Color(CYAN, 0.26 * breath), 2.0 / scale, true)
	if reduced_motion:
		return
	var burst: float = clampf((_result_hit_age - 0.72) / 0.53, 0.0, 1.0)
	if burst > 0.0 and burst < 1.0:
		_result_hit_fx.draw_arc(center, radius * (0.9 + burst * 0.65), 0, TAU, 48,
			Color(HIT_COLOR, (1.0 - burst) * 0.65), 2.0 / scale, true)
		for index in range(12):
			var angle: float = float(index) * TAU / 12.0
			var spread := Vector2(cos(angle) * 1.8, sin(angle) * 0.7)
			var point: Vector2 = center + spread * radius * (0.85 + burst * 0.65)
			var reach: float = (2.0 + 3.0 * sin(burst * PI)) / scale
			var color := Color(HIT_COLOR if index % 2 == 0 else WHITE, 1.0 - burst)
			_result_hit_fx.draw_line(point - Vector2(reach, 0), point + Vector2(reach, 0), color, 1.5 / scale, true)
			_result_hit_fx.draw_line(point - Vector2(0, reach), point + Vector2(0, reach), color, 1.5 / scale, true)


func _add_review(title: String, words: Array, color: Color) -> void:
	if words.is_empty():
		return
	var scale: float = Style.ui_scale(self)
	var caption: Label = _label(title, 15, color)
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
		button.mouse_filter = Control.MOUSE_FILTER_PASS
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
		button.pressed.connect(func() -> void:
			hear_requested.emit(word))
		button.focus_entered.connect(func() -> void: _ensure_result_control(button))


func cancel_result_input() -> void:
	if is_instance_valid(_results):
		_results.cancel_drag()


func _ensure_result_control(control: Control) -> void:
	if _results.is_pointer_active():
		return
	# Godot's built-in focus scrolling checks scrollbar visibility. Our scrollbars
	# are intentionally hidden, so reveal focused actions using container bounds.
	# Work in content coordinates so repeated focus notifications before the
	# next layout pass request the same offset instead of scrolling twice.
	var content_rect: Rect2 = _result_body.get_global_transform().affine_inverse() * control.get_global_rect()
	if content_rect.position.y < _results.scroll_vertical:
		_results.scroll_vertical = floori(content_rect.position.y)
	elif content_rect.end.y > _results.scroll_vertical + _results.size.y:
		_results.scroll_vertical = ceili(content_rect.end.y - _results.size.y)


func _replay() -> void:
	request_listening.emit()


func _open_chests() -> void:
	if _stopped or game.phase != "finished" or game.chest_count <= 0 or not is_visible_in_tree():
		return
	if not is_instance_valid(chests_button) or chests_button.disabled:
		return
	if interaction_allowed.is_valid() and not interaction_allowed.call():
		return
	cancel_result_input()
	chests_requested.emit()


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
		or value.begins_with("waiting for microphone audio") \
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
