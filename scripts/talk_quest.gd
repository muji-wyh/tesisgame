extends Control
## Sentence adventure. Speech is transient; only compact progress is saved.

signal exit_requested
signal sound_requested(kind: String)

const QuestData = preload("res://scripts/talk_quest_data.gd")
const QuestModel = preload("res://scripts/talk_quest_model.gd")
const Backdrop = preload("res://scripts/talk_quest_backdrop.gd")
const Treasure = preload("res://scripts/talk_quest_chest.gd")
const Creature = preload("res://scripts/talk_quest_monster.gd")
const PartButton = preload("res://scripts/talk_quest_part.gd")
const Style = preload("res://scripts/ui_style.gd")
const INK := Color("#30405b")
const ACCENT := Color("#7263c7")

var game = QuestModel.new()
var save_path: String = "user://talk_quest.cfg"
var reduced_motion: bool = false
var view: String = "map"
var save_failed: bool = false
var _host: JavaScriptObject
var _speech_callback: JavaScriptObject
var _speech_enabled: bool = false
var _auto_listen: bool = false
var _listening: bool = false
var _hold: float = 0.0
var _opening: bool = false
var _opening_finished: bool = false
var _suspended: bool = false
var _loaded: bool = false
var _typing: bool = false
var _status_clock: float = 0.0
var _map: Control
var _map_heading: Label
var _map_note: Label
var _map_scroll: ScrollContainer
var _map_grid: GridContainer
var _continue: Button
var _album_button: Button
var _level_buttons: Array[Button] = []
var _album: Control
var _album_scroll: ScrollContainer
var _album_grid: GridContainer
var _album_back: Button
var _stage: Control
var _stage_scroll: ScrollContainer
var _backdrop: Backdrop
var _viewport_box: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera3D
var _monster: Creature
var _monster_name: Label
var _topline: Label
var _back: Button
var _meter: ProgressBar
var _meter_text: Label
var _prompt_panel: Panel
var _speaker: Label
var _prompt: Label
var _transcript: Label
var _feedback: Label
var _speak: Button
var _hear: Button
var _type: Button
var _input: LineEdit
var _submit: Button
var _privacy: Label
var _banner: Label
var _chest: Treasure
var _chest_button: Button
var _next: Button
var _resume: Button
var _save_retry: Button
var _effects: Control
var _controls: Dictionary = {}
var _part_title: Label
var _parts: Array[Button] = []
var _companion: TextureRect


func _ready() -> void:
	_build_map()
	_build_stage()
	_build_album()
	_save_retry = _button(self, "Retry saving", func() -> void:
		_save_progress()
		_refresh())
	resized.connect(_layout)
	visibility_changed.connect(_visibility)
	if not OS.has_feature("web"):
		_load_progress()
	_refresh()
	_layout.call_deferred()


func _label(parent: Node, text: String, font_size: int = 16) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_color_override("font_color", INK)
	item.add_theme_font_size_override("font_size", font_size)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item


func _button(parent: Node, text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	parent.add_child(item)
	Style.action_button(item, ACCENT)
	item.pressed.connect(action)
	return item


func _build_map() -> void:
	_map = Control.new()
	add_child(_map)
	_map_heading = _label(_map, "Talk Quest", 30)
	_map_note = _label(_map, "Two friends. Fourteen little adventures.")
	_map_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_continue = _button(_map, "Continue saved adventure", _continue_run)
	_album_button = _button(_map, "Treasure shelf", _show_album)
	_map_scroll = ScrollContainer.new()
	_map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_map_scroll.follow_focus = true
	_map.add_child(_map_scroll)
	_map_grid = GridContainer.new()
	_map_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_scroll.add_child(_map_grid)
	for level: Dictionary in QuestData.levels():
		var tile := _button(_map_grid, "", start_level.bind(int(level.number)))
		tile.accessibility_name = "Adventure %d: %s" % [int(level.number), str(level.title)]
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var portrait := TextureRect.new()
		portrait.texture = load("res://assets/talk_quest/monsters/" + str(level.monster_id) + ".png")
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(portrait)
		var caption := _label(tile, "", 14)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var badge := _label(tile, "", 12)
		tile.set_meta("portrait", portrait)
		tile.set_meta("caption", caption)
		tile.set_meta("badge", badge)
		_level_buttons.append(tile)


func _build_stage() -> void:
	_stage_scroll = ScrollContainer.new()
	_stage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stage_scroll.follow_focus = true
	add_child(_stage_scroll)
	_stage = Control.new()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_scroll.add_child(_stage)
	_backdrop = Backdrop.new()
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_backdrop)
	_viewport_box = SubViewportContainer.new()
	_viewport_box.stretch = true
	_viewport_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_viewport_box)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport_box.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 2.8
	_camera.current = true
	_viewport.add_child(_camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#fff2de")
	environment.environment.ambient_light_energy = 0.7
	_viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28, -32, 0)
	light.light_energy = 1.3
	_viewport.add_child(light)
	_monster = Creature.new()
	_viewport.add_child(_monster)
	_monster.reaction_finished.connect(func(kind: String) -> void:
		if kind == "wake" and game.phase == "victory":
			_monster.celebrate())
	_topline = _label(_stage, "", 16)
	_topline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_monster_name = _label(_stage, "", 15)
	_monster_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back = _button(_stage, "Map", _show_map)
	_meter = ProgressBar.new()
	_meter.show_percentage = false
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_theme_stylebox_override("background", Style.box(Color("#ffffffaa"), Color.TRANSPARENT, 8, 0))
	_meter.add_theme_stylebox_override("fill", Style.box(Color("#84b7a6"), Color.TRANSPARENT, 8, 0))
	_stage.add_child(_meter)
	_meter_text = _label(_stage, "", 12)
	_meter_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel = Panel.new()
	_prompt_panel.add_theme_stylebox_override("panel", Style.box(Color("#fffefb"), Color("#ddd9ed"), 20, 1))
	_stage.add_child(_prompt_panel)
	_speaker = _label(_prompt_panel, "", 13)
	_prompt = _label(_prompt_panel, "", 24)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_transcript = _label(_prompt_panel, "", 14)
	_transcript.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_transcript.max_lines_visible = 2
	_transcript.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_feedback = _label(_prompt_panel, "", 13)
	_feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_speak = _button(_prompt_panel, "Speak", _toggle_speech)
	_hear = _button(_prompt_panel, "Hear line", _hear_line)
	_type = _button(_prompt_panel, "Type", _toggle_type)
	_input = LineEdit.new()
	_input.placeholder_text = "Type the sentence above"
	_input.max_length = 2000
	_input.add_theme_stylebox_override("normal", Style.box(Color("#f6f4fc"), Color("#d9d3eb"), 12, 1))
	_input.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, ACCENT, 12, 2))
	_input.add_theme_color_override("font_color", INK)
	_input.add_theme_color_override("font_placeholder_color", Color("#697389"))
	_input.add_theme_color_override("caret_color", INK)
	_input.accessibility_name = "Type the prompted sentence"
	_input.text_submitted.connect(_submit_text)
	_prompt_panel.add_child(_input)
	_input.hide()
	_submit = _button(_prompt_panel, "Say it", func() -> void: _submit_text(_input.text))
	_submit.hide()
	_privacy = _label(_prompt_panel, "Speech may use an online service. Audio and transcripts are not saved.", 10)
	_privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_part_title = _label(_prompt_panel, "Choose a part to help fix this toy.", 20)
	_part_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index in range(3):
		var part := PartButton.new()
		_prompt_panel.add_child(part)
		Style.action_button(part, ACCENT)
		part.pressed.connect(func() -> void: _choose_part(str(part.get_meta("part_id", ""))))
		var caption := _label(part, "", 13)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		part.set_meta("caption", caption)
		_parts.append(part)
	_banner = _label(_stage, "", 36)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chest = Treasure.new()
	_stage.add_child(_chest)
	_chest.reward_revealed.connect(_reward_revealed)
	_chest.opening_finished.connect(_reward_finished)
	_companion = TextureRect.new()
	_companion.texture = load("res://assets/talk_quest/monsters/lpm-alien.png")
	_companion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_companion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_companion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_companion)
	_chest_button = _button(_stage, "Open your treasure", _open_chest)
	_next = _button(_stage, "Next adventure", _next_level)
	_resume = _button(_stage, "Continue adventure", _continue_run)
	_effects = Control.new()
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_effects)
	_controls = {"map": _back, "speak": _speak, "hear": _hear, "type": _type,
		"input": _input, "submit": _submit, "open": _chest_button, "next": _next,
		"resume": _resume, "continue": _continue, "album": _album_button,
		"prompt": _prompt, "speaker": _speaker, "feedback": _feedback, "stage_scroll": _stage_scroll}


func _build_album() -> void:
	_album = Control.new()
	add_child(_album)
	var title := _label(_album, "Your treasure shelf", 28)
	title.name = "Title"
	var note := _label(_album, "Replay adventures to discover all 20 treasures.", 14)
	note.name = "Note"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_album_back = _button(_album, "Map", _show_map)
	_album_scroll = ScrollContainer.new()
	_album_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_album.add_child(_album_scroll)
	_album_grid = GridContainer.new()
	_album_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_album_scroll.add_child(_album_grid)
	for chest_data: Dictionary in QuestData.chests():
		var item := Panel.new()
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_theme_stylebox_override("panel", Style.box(Color("#fffefb"), Color("#e0dced"), 14, 1))
		_album_grid.add_child(item)
		var art := Treasure.new()
		item.add_child(art)
		art.configure(chest_data)
		art.set_reduced_motion(true)
		var label := _label(item, str(chest_data.name), 12)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.set_meta("id", chest_data.id)
		item.set_meta("art", art)
		item.set_meta("label", label)


func connect_browser(host: JavaScriptObject) -> void:
	_host = host
	_speech_callback = JavaScriptBridge.create_callback(func(arguments: Array) -> void:
		if arguments.size() == 1 and arguments[0] is String:
			receive_speech(str(arguments[0])))
	_host.observeQuestSpeech(_speech_callback)
	_load_progress()
	_refresh()


func _load_progress() -> void:
	if _loaded:
		return
	var payload: Variant = null
	if _host != null:
		payload = _host.questProgress()
		if payload is bool and not payload:
			save_failed = true
			return
	elif not OS.has_feature("web"):
		var config := ConfigFile.new()
		var error: int = config.load(save_path)
		if error == OK:
			payload = config.get_value("quest", "progress", "")
		elif error != ERR_FILE_NOT_FOUND:
			save_failed = true
			return
	else:
		return
	if payload is String and not payload.is_empty():
		var parsed: Variant = JSON.parse_string(payload)
		if not parsed is Dictionary or not game.import_progress(parsed):
			save_failed = true
			return
	_loaded = true
	_rebuild_map()


func _save_progress() -> bool:
	if not _loaded:
		_load_progress()
		if not _loaded:
			return false
	var payload: String = JSON.stringify(game.export_progress())
	if _host != null:
		save_failed = not bool(_host.saveQuestProgress(payload))
	elif not OS.has_feature("web"):
		var config := ConfigFile.new()
		config.set_value("quest", "progress", payload)
		save_failed = config.save(save_path) != OK
	else:
		save_failed = true
	_save_retry.visible = save_failed
	if save_failed:
		stop_speech()
	return not save_failed


func enter() -> void:
	_show_map()


func start_level(number: int) -> void:
	if save_failed or not _loaded or not game.start_level(number):
		return
	stop_speech()
	view = "stage"
	_suspended = false
	_hold = 0.0
	_opening = false
	_opening_finished = false
	_input.text = ""
	_typing = false
	_input.hide()
	_submit.hide()
	_setup_scene()
	_monster.process_mode = Node.PROCESS_MODE_INHERIT
	_chest.process_mode = Node.PROCESS_MODE_INHERIT
	_backdrop.process_mode = Node.PROCESS_MODE_INHERIT
	_effects.process_mode = Node.PROCESS_MODE_INHERIT
	_save_progress()
	_refresh()
	_speak.grab_focus()


func _setup_scene() -> void:
	for effect in _effects.get_children():
		_effects.remove_child(effect)
		effect.queue_free()
	_backdrop.configure_level(game.level_number, game.level.scene)
	_monster.set_creature(str(game.level.monster_id))
	_monster.set_cooperative_mode(bool(game.level.cooperative))
	_monster.set_reduced_motion(reduced_motion)
	_monster.repair_progress(game.repaired_toys.size(), 5)
	var height: float = _monster.get_normalized_height()
	_camera.size = 2.35 if game.level_number == 13 else 2.8
	_camera.position = Vector3(0, height * 0.55 + 0.20, 5)
	_camera.look_at(Vector3(0, height * 0.5, 0))
	_chest.configure(game.current_chest())
	_chest.reset_closed()
	_monster_name.text = str(game.level.monster_name)
	_topline.text = "%02d / 14  ·  %s" % [game.level_number, game.level.title]
	var scene_ink: Color = Color("#fff5dc") if game.level_number in [8, 12] else INK
	for label in [_topline, _monster_name, _meter_text, _banner]:
		label.add_theme_color_override("font_color", scene_ink)
	_feedback.text = "Read both parts. Say the highlighted sentence."
	if _host == null or not bool(_host.speechAvailable()):
		_feedback.text = "Use Type to play without a microphone."
	_transcript.text = "Heard: —"
	_banner.text = ""


func _show_map() -> void:
	pause()
	view = "map"
	_rebuild_map()
	_refresh()


func _show_album() -> void:
	pause()
	view = "album"
	for item in _album_grid.get_children():
		var owned: bool = str(item.get_meta("id")) in game.collected_chests
		item.get_meta("art").modulate = Color.WHITE if owned else Color(0.6, 0.64, 0.7, 0.38)
		var caption: Label = item.get_meta("label")
		caption.text = str(QuestData.chest(str(item.get_meta("id"))).name) + ("\nCollected" if owned else "\nUndiscovered")
	_refresh()


func _rebuild_map() -> void:
	var pending_reward: bool = game.has_saved_run() and str(game.export_progress().get("run", {}).get("phase", "")) in ["victory", "chest"]
	for index in range(_level_buttons.size()):
		var button: Button = _level_buttons[index]
		var level: Dictionary = QuestData.level(index + 1)
		var locked: bool = index + 1 > game.unlocked_level
		button.disabled = locked or save_failed or pending_reward
		button.tooltip_text = "Continue your saved adventure to collect its treasure." if pending_reward else ("Complete the previous adventure to unlock " if locked else "Play ") + str(level.title)
		var caption: Label = button.get_meta("caption")
		caption.text = str(level.title)
		var badge: Label = button.get_meta("badge")
		badge.text = "%02d%s" % [index + 1, "  Cleared" if index + 1 in game.completed_levels else "  Locked" if locked else "  Special" if index >= 12 else ""]
		button.get_meta("portrait").modulate.a = 0.4 if locked else 1.0
	_album_button.text = "Treasures  %d / 20" % game.collected_chests.size()
	_map_note.text = "Read, speak, and make a little magic. %d / 14 adventures complete." % game.completed_levels.size()


func pause() -> void:
	stop_speech()
	_suspended = view == "stage"
	if game.phase in ["playing", "victory", "chest", "complete"]:
		game.pause()
		_save_progress()
	_monster.process_mode = Node.PROCESS_MODE_DISABLED
	_chest.process_mode = Node.PROCESS_MODE_DISABLED
	_backdrop.process_mode = Node.PROCESS_MODE_DISABLED
	_effects.process_mode = Node.PROCESS_MODE_DISABLED
	_refresh()


func _continue_run() -> void:
	if save_failed or (not game.has_saved_run() and game.phase != "complete"):
		return
	if view != "stage":
		_setup_scene()
		_opening = false
		_opening_finished = game.phase == "complete"
	view = "stage"
	_suspended = false
	game.resume()
	_monster.process_mode = Node.PROCESS_MODE_INHERIT
	_chest.process_mode = Node.PROCESS_MODE_INHERIT
	_backdrop.process_mode = Node.PROCESS_MODE_INHERIT
	_effects.process_mode = Node.PROCESS_MODE_INHERIT
	if game.phase == "victory":
		_hold = 3.0 if game.is_cooperative() else 1.6
		_play_victory()
	if game.phase == "chest":
		_banner.text = str(game.current_chest().name)
	if game.phase == "complete":
		_opening_finished = true
		_opening = false
		_chest.set_preview_time(5.0)
		_banner.text = str(game.current_chest().name) + " collected!"
	_refresh()


func back() -> void:
	if view == "map":
		exit_requested.emit()
	else:
		_show_map()


func stop_speech() -> bool:
	_auto_listen = false
	_speech_enabled = false
	_listening = false
	if _host != null:
		_host.questCancelSpeak()
		return bool(_host.stopSpeech())
	return true


func _toggle_speech() -> void:
	if _speech_enabled or _auto_listen:
		stop_speech()
		_refresh()
	else:
		_auto_listen = true
		_start_listening()


func _start_listening() -> void:
	if _host == null or game.phase != "playing" or view != "stage" or not is_visible_in_tree() or _hold > 0 or save_failed or _suspended or _part_required():
		_auto_listen = false
		return
	_host.questCancelSpeak()
	var target: Dictionary = game.speech_target()
	if not bool(_host.questTarget(JSON.stringify(target))):
		_auto_listen = false
		_feedback.text = "The microphone could not stop. Please try again."
		return
	_host.speechMode(true, "quest")


func set_listening(enabled: bool, listening: bool, message: String) -> void:
	_speech_enabled = enabled
	_listening = listening
	if not enabled:
		_auto_listen = false
	if game.phase == "playing" and _hold <= 0.0:
		_feedback.text = "Listening… say the sentence above." if listening else message
	_refresh_controls()


func receive_speech(json: String) -> void:
	if not _speech_enabled or not _listening or game.phase != "playing" or view != "stage" or not is_visible_in_tree() or _hold > 0 or save_failed or _suspended:
		return
	var event: Variant = JSON.parse_string(json)
	if not event is Dictionary:
		return
	var line: String = str(game.current_prompt().get("text", ""))
	var result: Dictionary = game.submit_speech_event(event)
	if not result.accepted:
		return
	_transcript.text = "Heard%s: %s" % [" (listening)" if str(event.get("stage", "")) == "interim" else "", str(event.get("text", "")).left(350)]
	_handle_result(result, line)


func _submit_text(text: String) -> void:
	if game.phase != "playing" or _hold > 0 or text.strip_edges().is_empty() or save_failed or _suspended:
		return
	stop_speech()
	var line: String = str(game.current_prompt().get("text", ""))
	var result: Dictionary = game.submit_transcript(text)
	_transcript.text = "Typed: " + text.left(350)
	_handle_result(result, line)


func _handle_result(result: Dictionary, line: String) -> void:
	if not result.matched:
		if str(result.get("reason", "")) != "interim":
			_feedback.text = "Almost! Try the whole sentence again."
		_publish()
		return
	var keep_listening: bool = _auto_listen
	stop_speech()
	_auto_listen = keep_listening
	_feedback.text = "Lovely! Every word matched."
	_input.text = ""
	_hold = 0.85
	_word_effect(line, bool(game.level.cooperative))
	if bool(game.level.cooperative):
		_monster.repair_progress(game.repaired_toys.size(), 5)
		if result.repair_completed:
			_feedback.text = "Another toy repaired! %d / 5 ready." % game.repaired_toys.size()
	else:
		_monster.react_hit()
	sound_requested.emit("hit")
	_save_progress()
	_update_meter()
	if result.completed:
		_auto_listen = false
		_hold = 3.0 if game.is_cooperative() else 2.1
		_play_victory()
	_refresh_controls()
	_publish()


func _word_effect(line: String, cooperative: bool) -> void:
	for index in range(line.split(" ").size()):
		var word := _label(_effects, line.split(" ")[index], 20)
		word.add_theme_color_override("font_color", Color("#7658b1") if cooperative else Color("#e48a3d"))
		var origin := Vector2(size.x * 0.5, _prompt_panel.position.y + 26)
		word.position = origin + Vector2((index % 5 - 2) * 30, (index / 5) * 13)
		var tween := word.create_tween()
		if reduced_motion:
			tween.tween_property(word, "modulate:a", 0.0, 0.25)
		else:
			tween.set_parallel(true)
			tween.tween_property(word, "position", Vector2(size.x * 0.5 + (index % 3 - 1) * 22, _backdrop.size.y * 0.4), 0.55).set_delay(index * 0.015).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(word, "modulate:a", 0.0, 0.2).set_delay(0.42 + index * 0.015)
		tween.chain().tween_callback(word.queue_free)


func _play_victory() -> void:
	if bool(game.level.cooperative):
		_monster.wake_up()
		_banner.text = "We did it!\nFive happy toys."
	else:
		_monster.defeat()
		_banner.text = "You win!"
	_backdrop.celebrate()
	sound_requested.emit("victory")
	_refresh()


func _hear_line() -> void:
	if game.phase != "playing" or _host == null:
		return
	if not stop_speech():
		return
	if not bool(_host.questSpeak(str(game.current_prompt().get("text", "")))):
		_feedback.text = "Read the line together, then speak or type it."
	else:
		_feedback.text = "Listen first. Press Speak when you are ready."
	_refresh_controls()


func _toggle_type() -> void:
	stop_speech()
	_typing = not _typing
	_input.visible = _typing
	_submit.visible = _typing
	_layout()
	if _input.visible:
		_feedback.text = "Type the sentence, then choose Say it."
		_input.grab_focus()


func _part_required() -> bool:
	return game.phase == "playing" and game.is_cooperative() and not game.has_correct_part()


func _choose_part(id: String) -> void:
	if not _part_required() or save_failed or _suspended:
		return
	stop_speech()
	var result: Dictionary = game.choose_part(id)
	if bool(result.get("correct", false)):
		_save_progress()
		_feedback.text = "The part is ready. Now read both parts together."
	else:
		_feedback.text = "Try another shape. Which part would help this toy?"
	_refresh()


func _open_chest() -> void:
	if game.phase != "chest" or _opening or save_failed:
		return
	_opening = true
	_opening_finished = false
	_chest.play_open()
	sound_requested.emit("open")
	_refresh_controls()


func _reward_revealed() -> void:
	if game.phase != "chest" or not _opening:
		return
	game.open_chest()
	_save_progress()
	_banner.text = ("Tinker is your new friend!\n" if game.level_number == 14 else "Treasure discovered!\n") + str(game.current_chest().get("name", ""))
	sound_requested.emit("reward")
	_rebuild_map()
	_refresh()


func _reward_finished() -> void:
	_opening = false
	_opening_finished = true
	_refresh()
	if _next.visible and not _next.disabled:
		_next.grab_focus()


func _next_level() -> void:
	if save_failed or not _opening_finished or game.phase != "complete":
		return
	if game.level_number < 14:
		start_level(game.level_number + 1)
	else:
		_show_map()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if view == "stage" and game.phase != "paused" and not _suspended and _hold > 0:
		_hold = maxf(0.0, _hold - delta)
		if _hold <= 0:
			if game.phase == "victory":
				game.finish_victory()
				_save_progress()
				_banner.text = str(game.current_chest().name)
				_chest.configure(game.current_chest())
			_refresh()
			if _auto_listen and game.phase == "playing":
				_start_listening()
	_status_clock += delta
	if _status_clock >= 0.2:
		_status_clock = 0
		_publish()


func _refresh() -> void:
	if _stage == null:
		return
	_map.visible = view == "map"
	if view == "map":
		_rebuild_map()
	_album.visible = view == "album"
	_stage.visible = view == "stage"
	_stage_scroll.visible = view == "stage"
	_continue.visible = game.has_saved_run()
	_continue.disabled = save_failed
	_save_retry.visible = save_failed
	_map_note.text = "Progress could not be saved. Retry saving before continuing." if save_failed else "Read, speak, and make a little magic. %d / 14 adventures complete." % game.completed_levels.size()
	var active: bool = game.phase == "playing"
	_prompt_panel.visible = active
	_monster_name.visible = game.phase in ["playing", "victory", "paused"]
	_viewport_box.visible = game.phase in ["playing", "victory", "paused"]
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() and view == "stage" and _viewport_box.visible else SubViewport.UPDATE_DISABLED
	_chest.visible = game.phase in ["chest", "complete"]
	_companion.visible = game.phase == "complete" and game.level_number == 14 and not _suspended
	_chest_button.visible = game.phase == "chest"
	_next.visible = game.phase == "complete"
	_next.text = "Back to the map" if game.level_number == 14 else "Next adventure"
	_resume.visible = game.phase == "paused" or _suspended
	_banner.visible = game.phase in ["victory", "chest", "complete", "paused"] or _suspended
	if game.phase == "paused" or _suspended:
		_banner.text = "Adventure paused"
		_prompt_panel.hide()
		_chest.hide()
		_chest_button.hide()
		_next.hide()
	if active:
		var line: Dictionary = game.current_prompt()
		_speaker.text = "%s says   ·   %d / %d" % [str(line.get("speaker", "")), game.line_index + 1, game.level.lines.size()]
		_prompt.text = str(line.get("text", ""))
	var choose_part: bool = _part_required()
	_part_title.visible = choose_part
	for control in [_prompt, _transcript, _speak, _hear, _type, _privacy]:
		control.visible = not choose_part
	_input.visible = _typing and not choose_part
	_submit.visible = _input.visible
	if choose_part:
		_speaker.text = "Workshop  ·  " + str(game.current_prompt().get("repair_name", "Toy repair"))
		_part_title.text = "What will help fix the %s?" % str(game.current_prompt().get("repair_name", "toy")).to_lower()
	var choices: Array = game.current_part_choices()
	for index in range(_parts.size()):
		var part: Button = _parts[index]
		part.visible = choose_part
		if choose_part and index < choices.size():
			part.set_meta("part_id", choices[index].id)
			part.set("shape_id", str(choices[index].shape))
			part.get_meta("caption").text = str(choices[index].label)
			part.accessibility_name = "Choose " + str(choices[index].label)
			part.queue_redraw()
	_update_meter()
	_refresh_controls()
	_layout()
	_publish()


func _refresh_controls() -> void:
	_speak.text = "Stop" if _speech_enabled else "Speak"
	_speak.disabled = _host == null or not bool(_host.speechAvailable()) or _hold > 0 or save_failed
	_speak.tooltip_text = "Say the entire displayed sentence." if not _speak.disabled else "Use Type when browser speech is unavailable."
	_hear.disabled = _host == null or _hold > 0
	_type.disabled = _hold > 0 or save_failed
	_submit.disabled = _hold > 0 or save_failed
	_input.editable = _hold <= 0 and not save_failed
	_chest_button.disabled = _opening or save_failed
	_next.disabled = not _opening_finished or save_failed
	_back.disabled = save_failed


func _update_meter() -> void:
	if game.level.is_empty():
		_meter.hide()
		_meter_text.hide()
		return
	_meter.visible = game.phase in ["playing", "victory"]
	_meter_text.visible = _meter.visible
	_meter.max_value = 5 if bool(game.level.cooperative) else maxi(1, game.max_hp)
	_meter.value = game.repaired_toys.size() if bool(game.level.cooperative) else game.hp
	_meter_text.text = "%d / 5 toys repaired" % game.repaired_toys.size() if bool(game.level.cooperative) else "%s  ·  %d / %d hearts" % [str(game.level.monster_name), ceili(game.hp / 10.0), ceili(game.max_hp / 10.0)]
	_backdrop.set_progress(float(game.line_index) / maxf(1, game.level.lines.size()))
	if bool(game.level.cooperative):
		_backdrop.set_repair_count(game.repaired_toys.size())


func _layout() -> void:
	if _stage == null or size.x <= 0 or size.y <= 0:
		return
	var s: float = Style.ui_scale(self)
	var w: float = size.x
	var h: float = size.y
	var gap: float = 10 / s
	for panel in [_map, _stage_scroll, _album]:
		panel.size = size
	_map_heading.position = Vector2(6, 0) / s
	_map_heading.size = Vector2(w * 0.56, 40 / s)
	_map_heading.add_theme_font_size_override("font_size", ceili(30 / s))
	_map_note.position = Vector2(6, 44) / s
	_map_note.size = Vector2(w - 12 / s, 44 / s)
	_map_note.add_theme_font_size_override("font_size", ceili(14 / s))
	_album_button.position = Vector2(w - 145 / s, 0)
	_album_button.size = Vector2(145, 42) / s
	_continue.position = Vector2(0, 88 / s)
	_continue.size = Vector2(w, 44 / s)
	var map_top: float = (142 if _continue.visible else 94) / s
	_map_scroll.position = Vector2(0, map_top)
	_map_scroll.size = Vector2(w, maxf(0, h - map_top))
	_map_grid.columns = 4 if w * s >= 740 else 3 if w * s >= 460 else 2
	_map_grid.add_theme_constant_override("h_separation", ceili(gap))
	_map_grid.add_theme_constant_override("v_separation", ceili(gap))
	var tile_w: float = (w - gap * (_map_grid.columns - 1) - 14 / s) / _map_grid.columns
	for button in _level_buttons:
		button.custom_minimum_size = Vector2(tile_w, 170 / s)
		button.get_meta("portrait").position = Vector2(8, 22) / s
		button.get_meta("portrait").size = Vector2(tile_w - 16 / s, 96 / s)
		button.get_meta("caption").position = Vector2(8, 121) / s
		button.get_meta("caption").size = Vector2(tile_w - 16 / s, 46 / s)
		button.get_meta("caption").add_theme_font_size_override("font_size", ceili(14 / s))
		button.get_meta("badge").position = Vector2(10, 7) / s
		button.get_meta("badge").add_theme_font_size_override("font_size", ceili(11 / s))
	var compact: bool = w * s < 520
	var prompt_h: float = (290 if compact else 254) / s + (48 / s if _input.visible else 0)
	h = maxf(h, prompt_h + 130 / s) if game.phase == "playing" else maxf(h, 390 / s)
	w -= 14 / s if h > size.y else 0.0
	_stage.custom_minimum_size = Vector2(0, h)
	_stage.size = Vector2(w, h)
	var art_h: float = maxf(120 / s, h - prompt_h - gap)
	_backdrop.size = Vector2(w, art_h)
	var model_side: float = minf(w * 0.7, maxf(90 / s, art_h - 65 / s))
	_viewport_box.position = Vector2((w - model_side) * 0.5, 55 / s)
	_viewport_box.size = Vector2(model_side, model_side)
	_back.position = Vector2(w - 66 / s, 0)
	_back.size = Vector2(66, 42) / s
	_topline.position = Vector2(12, 10) / s
	_topline.size = Vector2(w - 92 / s, 24 / s)
	_topline.add_theme_font_size_override("font_size", ceili(15 / s))
	_meter.position = Vector2(w * 0.25, 40 / s)
	_meter.size = Vector2(w * 0.5, 8 / s)
	_meter_text.position = Vector2(w * 0.15, 51 / s)
	_meter_text.size = Vector2(w * 0.7, 20 / s)
	_meter_text.add_theme_font_size_override("font_size", ceili(11 / s))
	_monster_name.position = Vector2(w * 0.2, art_h - 26 / s)
	_monster_name.size = Vector2(w * 0.6, 22 / s)
	_monster_name.add_theme_font_size_override("font_size", ceili(14 / s))
	_monster_name.visible = game.phase in ["playing", "victory", "paused"] and art_h * s >= 180
	_prompt_panel.position = Vector2(0, art_h + gap)
	_prompt_panel.size = Vector2(w, prompt_h)
	_speaker.position = Vector2(16, 10) / s
	_speaker.size = Vector2(w - 32 / s, 24 / s)
	_speaker.add_theme_font_size_override("font_size", ceili(13 / s))
	_prompt.position = Vector2(16, 34) / s
	_prompt.size = Vector2(w - 32 / s, (86 if compact else 66) / s)
	_prompt.add_theme_font_size_override("font_size", ceili((21 if compact else 25) / s))
	_transcript.position = Vector2(16, 124 if compact else 104) / s
	_transcript.size = Vector2(w - 32 / s, 38 / s)
	_transcript.add_theme_font_size_override("font_size", ceili(13 / s))
	_feedback.position = Vector2(16, 165 if compact else 145) / s
	_feedback.size = Vector2(w - 32 / s, 22 / s)
	_feedback.add_theme_font_size_override("font_size", ceili(12 / s))
	_part_title.position = Vector2(16, 34) / s
	_part_title.size = Vector2(w - 32 / s, 48 / s)
	_part_title.add_theme_font_size_override("font_size", ceili(20 / s))
	for index in range(_parts.size()):
		var part: Button = _parts[index]
		var part_w: float = (w - 48 / s) / 3
		part.position = Vector2(16 / s + index * (part_w + 8 / s), 88 / s)
		part.size = Vector2(part_w, 112 / s)
		part.get_meta("caption").position = Vector2(0, 84 / s)
		part.get_meta("caption").size = Vector2(part_w, 22 / s)
		part.get_meta("caption").add_theme_font_size_override("font_size", ceili(13 / s))
	if _part_required():
		_feedback.position.y = 211 / s
	var button_y: float = (192 if compact else 172) / s
	var button_w: float = (w - 48 / s) / 3
	for index in range(3):
		var button: Button = [_speak, _hear, _type][index]
		Style.action_button(button, ACCENT, index == 0)
		button.position = Vector2(16 / s + index * (button_w + 8 / s), button_y)
		button.size = Vector2(button_w, 44 / s)
	_input.position = Vector2(16 / s, button_y + 51 / s)
	_input.size = Vector2(w - 116 / s, 42 / s)
	_input.add_theme_font_size_override("font_size", ceili(14 / s))
	_submit.position = Vector2(w - 92 / s, button_y + 51 / s)
	_submit.size = Vector2(76, 42) / s
	_privacy.position = Vector2(16 / s, prompt_h - 38 / s)
	_privacy.size = Vector2(w - 32 / s, 32 / s)
	_privacy.add_theme_font_size_override("font_size", ceili(10 / s))
	_banner.position = Vector2(w * 0.08, 78 / s)
	_banner.size = Vector2(w * 0.84, 102 / s)
	_banner.add_theme_font_size_override("font_size", ceili(30 / s))
	_chest.position = Vector2(w * 0.08, 172 / s)
	_chest.size = Vector2(w * 0.84, maxf(100 / s, h - 236 / s))
	_companion.position = Vector2(w * 0.5 - 48 / s, 160 / s)
	_companion.size = Vector2(96, 96) / s
	for button in [_chest_button, _next, _resume]:
		Style.action_button(button, ACCENT, true)
		button.position = Vector2(w * 0.15, h - 54 / s)
		button.size = Vector2(w * 0.7, 48 / s)
	_effects.size = size
	w = size.x
	h = size.y
	_save_retry.position = Vector2(w - 145 / s, h - 48 / s)
	_save_retry.size = Vector2(145, 44) / s
	_album.get_node("Title").position = Vector2(4, 3) / s
	_album.get_node("Title").add_theme_font_size_override("font_size", ceili(24 / s))
	_album.get_node("Note").position = Vector2(4, 44) / s
	_album.get_node("Note").size = Vector2(w - 8 / s, 40 / s)
	_album.get_node("Note").add_theme_font_size_override("font_size", ceili(13 / s))
	_album_back.position = Vector2(w - 66 / s, 0)
	_album_back.size = Vector2(66, 42) / s
	_album_scroll.position = Vector2(0, 90 / s)
	_album_scroll.size = Vector2(w, maxf(0, h - 90 / s))
	_album_grid.columns = _map_grid.columns
	_album_grid.add_theme_constant_override("h_separation", ceili(gap))
	_album_grid.add_theme_constant_override("v_separation", ceili(gap))
	for item in _album_grid.get_children():
		item.custom_minimum_size = Vector2(tile_w, 160 / s)
		item.get_meta("art").position = Vector2(8, 5) / s
		item.get_meta("art").size = Vector2(tile_w - 16 / s, 110 / s)
		item.get_meta("label").position = Vector2(8, 116) / s
		item.get_meta("label").size = Vector2(tile_w - 16 / s, 40 / s)
		item.get_meta("label").add_theme_font_size_override("font_size", ceili(12 / s))


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if _stage != null:
		_monster.set_reduced_motion(enabled)
		_backdrop.set_reduced_motion(enabled)
		_chest.set_reduced_motion(enabled)


func _visibility() -> void:
	if not is_visible_in_tree():
		pause()
	else:
		_refresh()


func default_focus() -> Control:
	if view == "map":
		return _continue if _continue.visible else _level_buttons[mini(game.unlocked_level, 14) - 1]
	if view == "album":
		return _album_back
	if game.phase == "paused" or _suspended:
		return _resume
	if game.phase == "chest":
		return _chest_button
	if game.phase == "complete":
		return _next
	if _part_required():
		return _parts[0]
	return _type if _speak.disabled else _speak


func _rect(control: Control) -> Dictionary:
	var rect: Rect2 = control.get_global_rect()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return {"x": rect.position.x / viewport_size.x, "y": rect.position.y / viewport_size.y,
		"width": rect.size.x / viewport_size.x, "height": rect.size.y / viewport_size.y,
		"visible": control.is_visible_in_tree(), "disabled": control.disabled if control is Button else false}


func snapshot() -> Dictionary:
	var controls: Dictionary = {}
	for key in _controls:
		controls[key] = _rect(_controls[key])
	var levels: Array = []
	for button in _level_buttons:
		levels.append(_rect(button))
	var part_choices: Array = []
	for button in _parts:
		part_choices.append({"id": button.get_meta("part_id", ""), "label": button.get_meta("caption").text, "rect": _rect(button)})
	return {"active": is_visible_in_tree(), "view": view, "phase": game.phase,
		"level": game.level_number, "line_index": game.line_index, "prompt": game.current_prompt(),
		"hp": game.hp, "max_hp": game.max_hp, "repairs": game.repaired_toys.size(),
		"completed": game.completed_levels, "unlocked": game.unlocked_level,
		"chests": game.collected_chests, "total_clears": game.total_clears,
		"transcript": _transcript.text, "feedback": _feedback.text,
		"listening": _listening, "busy": _hold > 0 or _opening, "save_failed": save_failed,
		"controls": controls, "levels": levels,
		"part_required": _part_required(), "part_choices": part_choices,
		"reduced_motion": reduced_motion, "scroll_offset": _stage_scroll.scroll_vertical,
		"paused": _suspended or game.phase == "paused",
		"scroll_max": maxf(0, _stage_scroll.get_v_scroll_bar().max_value - _stage_scroll.get_v_scroll_bar().page)}


func _publish() -> void:
	if _host != null:
		_host.questStatus(JSON.stringify(snapshot()))


func _exit_tree() -> void:
	stop_speech()
