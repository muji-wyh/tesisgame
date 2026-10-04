extends Control
## Word flights become monster attacks. Speech remains transient.

signal exit_requested
signal sound_requested(kind: String)
signal chest_audio_requested(action: String, theme_id: String, progress: float)
signal chest_cue_requested(theme_id: String, cue: String, step: int)

const QuestData = preload("res://scripts/talk_quest_data.gd")
const QuestModel = preload("res://scripts/talk_quest_model.gd")
const Backdrop = preload("res://scripts/talk_quest_backdrop.gd")
const Treasure = preload("res://scripts/talk_quest_reward_chest.gd")
const TreasureArt = preload("res://scripts/talk_quest_chest.gd")
const ChestFeel = preload("res://scripts/chest_feel.gd")
const TreasureBackdrop = preload("res://scripts/talk_quest_treasure_stage.gd")
const Celebration = preload("res://scripts/talk_quest_celebration.gd")
const GameData = preload("res://scripts/game_data.gd")
const Creature = preload("res://scripts/talk_quest_monster.gd")
const Diorama = preload("res://scripts/talk_quest_environment.gd")
const Atlas = preload("res://scripts/talk_quest_map.gd")
const QuestButton = preload("res://scripts/talk_quest_button.gd")
const QuestMeter = preload("res://scripts/talk_quest_meter.gd")
const QuestEffects = preload("res://scripts/talk_quest_effects.gd")
const WordField = preload("res://scripts/talk_quest_words.gd")
const QuestResult = preload("res://scripts/talk_quest_result.gd")
const ResultScroll = preload("res://scripts/result_scroll.gd")
const Style = preload("res://scripts/ui_style.gd")
const INK := Style.INK
const ACCENT := Style.GOOD

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
var interaction_allowed: Callable
var _holding_chest: bool = false
var _chest_hold_elapsed: float = 0.0
var _chest_hold_frame: int = -1
var _dragging_chest: bool = false
var _chest_drag_anchor: Vector2
var _chest_drag_offset: Vector2
var _chest_has_anchor: bool = false
var _settling_chest: bool = false
var _reward_announced: bool = false
var _suspended: bool = false
var _loaded: bool = false
var _status_clock: float = 0.0
var _map: Control
var _map_heading: Label
var _map_note: Label
var _atlas: Atlas
var _continue: Button
var _album_button: Button
var _level_buttons: Array[Button] = []
var _album: Control
var _album_scroll: ResultScroll
var _album_grid: GridContainer
var _album_back: Button
var _stage: Control
var _stage_scroll: ScrollContainer
var _backdrop: Backdrop
var _loss_backdrop: Panel
var _viewport_box: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera3D
var _camera_tween: Tween
var _giant_camera_expansion: float = 1.0
var _threat_left: float = 5.5
var _world_environment: Environment
var _monster: Creature
var _environment: Diorama
var _stage_header: Panel
var _monster_name: Label
var _topline: Label
var _back: Button
var _meter: QuestMeter
var _meter_text: Label
var _transcript: Label
var _feedback: Label
var _banner: Label
var _chest: Treasure
var _chest_button: Button
var _treasure_backdrop: TreasureBackdrop
var _celebration: Celebration
var _reward_eyebrow: Label
var _reward_detail: Label
var _chest_caption: Label
var _next: Button
var _resume: Button
var _save_retry: Button
var _effects: QuestEffects
var _controls: Dictionary = {}
var _companion: TextureRect
var _label_tweens: Dictionary = {}
var _impact_pending: bool = false
var _impact_wait: float = 0.0
var _victory_pending: bool = false
var _victory_wait: float = 0.0
var _words: WordField
var _word_count: Label
var _retry: Button
var _loss: QuestResult
var _pause_card: QuestResult
var _mic_retry: Button
var _display_hp: int = 0
var _pending_hits: Array[Dictionary] = []
var _last_target_key: String = ""
var _transcript_final: bool = false


func _ready() -> void:
	_build_map()
	_build_stage()
	_build_album()
	_save_retry = _button(self, "Retry saving", func() -> void:
		if _save_progress() and game.phase == "complete":
			_announce_chest_reward(true)
		_refresh())
	_save_retry.z_index = 21
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
	var item := QuestButton.new()
	item.text = text
	parent.add_child(item)
	item.configure(ACCENT, false, reduced_motion)
	item.pressed.connect(action)
	return item


func _style_button(item: Button, primary: bool = false) -> void:
	if item is QuestButton:
		item.configure(ACCENT, primary, reduced_motion)
	else:
		Style.action_button(item, ACCENT, primary)


func _build_map() -> void:
	_map = Control.new()
	add_child(_map)
	_map_heading = _label(_map, "The Word Isles", 30)
	_map_note = _label(_map, "", 12)
	_continue = _button(_map, "Continue", _continue_run)
	_album_button = _button(_map, "Treasures", _show_album)
	_atlas = Atlas.new()
	_atlas.interaction_allowed = func() -> bool: return not interaction_allowed.is_valid() or interaction_allowed.call()
	_map.add_child(_atlas)
	_atlas.configure(QuestData.levels())
	_atlas.level_selected.connect(start_level)
	_level_buttons = _atlas.level_buttons
	_atlas.changed.connect(_publish)


func _build_stage() -> void:
	_stage_scroll = ScrollContainer.new()
	_stage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stage_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stage_scroll.follow_focus = true
	add_child(_stage_scroll)
	_stage = Control.new()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_scroll.add_child(_stage)
	_backdrop = Backdrop.new()
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_backdrop)
	_loss_backdrop = Panel.new()
	_loss_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loss_backdrop.add_theme_stylebox_override("panel", Style.box(Color("#102a2a"), Color.TRANSPARENT, 20, 0))
	_loss_backdrop.hide()
	_stage.add_child(_loss_backdrop)
	_viewport_box = SubViewportContainer.new()
	_viewport_box.stretch = true
	_viewport_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_viewport_box)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = false
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport_box.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 34.0
	_camera.size = 2.8
	_camera.current = true
	_viewport.add_child(_camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#a7bbc6")
	environment.environment.ambient_light_energy = 0.36
	_world_environment = environment.environment
	_viewport.add_child(environment)
	_environment = Diorama.new()
	_viewport.add_child(_environment)
	_monster = Creature.new()
	_viewport.add_child(_monster)
	_monster.reaction_started.connect(_frame_giant_reaction)
	_monster.reaction_finished.connect(func(kind: String) -> void:
		if _monster.creature_id.begins_with("giant-"):
			_frame_giant_reaction("idle")
		if kind == "wake" and game.phase == "victory":
			_monster.celebrate())
	_stage_header = Panel.new()
	_stage_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_header.add_theme_stylebox_override("panel", Style.box(Color("#fff9eae8"), Color("#ffffff90"), 18, 1))
	_stage.add_child(_stage_header)
	_topline = _label(_stage, "", 16)
	_topline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_monster_name = _label(_stage, "", 15)
	_monster_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back = _button(_stage, "Map", _show_map)
	_meter = QuestMeter.new()
	_meter.show_percentage = false
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_meter)
	_meter_text = _label(_stage, "", 12)
	_meter_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words = WordField.new()
	_words.name = "WordArena"
	_stage.add_child(_words)
	_word_count = _label(_stage, "", 13)
	_word_count.add_theme_color_override("font_color", Color("#d2ddd9"))
	_transcript = _label(_stage, "", 15)
	_transcript.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_transcript.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_transcript.max_lines_visible = 2
	_transcript.clip_text = true
	_transcript.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_transcript.accessibility_name = "Live transcript"
	_feedback = _label(_stage, "", 12)
	_feedback.clip_text = true
	_feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_mic_retry = _button(_stage, "Retry microphone", _start_listening)
	_mic_retry.visibility_changed.connect(_layout)
	_banner = _label(_stage, "", 36)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_treasure_backdrop = TreasureBackdrop.new()
	_stage.add_child(_treasure_backdrop)
	_stage.move_child(_treasure_backdrop, _loss_backdrop.get_index() + 1)
	_chest = Treasure.new()
	_stage.add_child(_chest)
	_chest.release_reached.connect(_on_chest_released)
	_chest.opened.connect(_reward_finished)
	_chest.cue_requested.connect(_on_chest_cue)
	_celebration = Celebration.new()
	_celebration.hide()
	_stage.add_child(_celebration)
	_reward_eyebrow = _label(_stage, "ADVENTURE COMPLETE", 12)
	_reward_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_detail = _label(_stage, "", 14)
	_reward_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_detail.clip_text = true
	_reward_detail.max_lines_visible = 1
	_reward_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_companion = TextureRect.new()
	_companion.texture = load("res://assets/talk_quest/monsters/lpm-alien.png")
	_companion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_companion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_companion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_companion)
	_chest_button = Button.new()
	_chest_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		_chest_button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	_chest_button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Color.WHITE, 24, 3))
	_stage.add_child(_chest_button)
	_chest_button.button_down.connect(start_chest_hold)
	_chest_button.button_up.connect(end_chest_hold)
	_chest_button.gui_input.connect(_chest_input)
	_chest_button.focus_exited.connect(func() -> void: cancel_chest_input(true))
	_chest_caption = _label(_stage, "Hold to open your chest!", 18)
	_chest_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chest_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next = _button(_stage, "Next adventure", _next_level)
	_effects = QuestEffects.new()
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_effects)
	_effects.word_landed.connect(_spell_impact)
	_loss = QuestResult.new()
	_loss.hide()
	_stage.add_child(_loss)
	_loss.loss_reaction_requested.connect(func() -> void: sound_requested.emit("pip_loss"))
	_retry = _loss.retry
	_retry.pressed.connect(func() -> void: start_level(game.level_number))
	_loss.map_button.pressed.connect(_show_map)
	_pause_card = QuestResult.new()
	_pause_card.hide()
	_stage.add_child(_pause_card)
	_resume = _pause_card.retry
	_resume.pressed.connect(_continue_run)
	_pause_card.map_button.pressed.connect(_show_map)
	_controls = {"map": _back, "open": _chest_button, "next": _next,
		"resume": _resume, "continue": _continue, "album": _album_button,
		"retry": _retry, "mic_retry": _mic_retry, "feedback": _feedback,
		"word_arena": _words, "stage_scroll": _stage_scroll,
		"loss_panel": _loss, "loss_card": _loss.surface,
		"pause_panel": _pause_card, "pause_card": _pause_card.surface}



func _build_album() -> void:
	_album = Control.new()
	add_child(_album)
	var title := _label(_album, "Your treasure shelf", 28)
	title.name = "Title"
	var note := _label(_album, "Replay adventures to discover all 20 treasures.", 14)
	note.name = "Note"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_album_back = _button(_album, "Map", _show_map)
	_album_scroll = ResultScroll.new()
	_album_scroll.interaction_allowed = func() -> bool: return not interaction_allowed.is_valid() or interaction_allowed.call()
	_album_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_album_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Keep the final card border clear of integer scroll rounding at fractional scales.
	var shelf_padding := StyleBoxEmpty.new()
	shelf_padding.content_margin_bottom = 4.0
	_album_scroll.add_theme_stylebox_override("panel", shelf_padding)
	_album.add_child(_album_scroll)
	_album_grid = GridContainer.new()
	_album_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_album_scroll.add_child(_album_grid)
	for chest_data: Dictionary in QuestData.chests():
		var item := Panel.new()
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.focus_mode = Control.FOCUS_ALL
		var normal := Style.box(Color("#fffefb"), Color("#dce2d7"), 14, 1)
		var focused := Style.box(Color("#fffefb"), Color("#346953"), 14, 3)
		item.add_theme_stylebox_override("panel", normal)
		item.focus_entered.connect(func() -> void:
			item.add_theme_stylebox_override("panel", focused)
			_ensure_album_item(item))
		item.focus_exited.connect(func() -> void: item.add_theme_stylebox_override("panel", normal))
		_album_grid.add_child(item)
		var art := TreasureArt.new()
		item.add_child(art)
		art.configure(chest_data)
		art.set_reduced_motion(true)
		var label := _label(item, str(chest_data.name), 12)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.set_meta("id", chest_data.id)
		item.set_meta("art", art)
		item.set_meta("label", label)


func cancel_scroll_input() -> void:
	if is_instance_valid(_atlas):
		_atlas.cancel_input()
	if is_instance_valid(_album_scroll):
		_album_scroll.cancel_drag()


func _ensure_album_item(item: Control) -> void:
	if _album_scroll.is_pointer_active():
		return
	_album_scroll.cancel_drag()
	# Hidden rails still reveal each treasure as keyboard focus moves through it.
	var content_rect: Rect2 = _album_grid.get_global_transform().affine_inverse() * item.get_global_rect()
	if content_rect.position.y < _album_scroll.scroll_vertical:
		_album_scroll.scroll_vertical = floori(content_rect.position.y)
	elif content_rect.end.y > _album_scroll.scroll_vertical + _album_scroll.size.y:
		_album_scroll.scroll_vertical = ceili(content_rect.end.y - _album_scroll.size.y)


func connect_browser(host: JavaScriptObject) -> void:
	_host = host
	_speech_callback = JavaScriptBridge.create_callback(func(arguments: Array) -> void:
		if arguments.is_empty() or not arguments[0] is String:
			return
		var accepted: bool = receive_speech(str(arguments[0]))
		if arguments.size() > 1 and arguments[1] != null:
			arguments[1].accepted = accepted)
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
	_loss.reset_loss()
	_celebration.reset()
	stop_speech()
	view = "stage"
	_suspended = false
	_hold = 0.0
	_opening = false
	_opening_finished = false
	_reward_announced = false
	cancel_chest_input()
	_setup_scene()
	for item in [_monster, _chest, _backdrop, _effects]:
		item.process_mode = Node.PROCESS_MODE_INHERIT
	_save_progress()
	_refresh()
	_back.grab_focus()
	_start_listening()


func _setup_scene() -> void:
	sound_requested.emit("stop")
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_giant_camera_expansion = 1.0
	_threat_left = 5.5
	_effects.clear()
	_pending_hits.clear()
	_display_hp = game.hp
	_impact_pending = false
	_victory_pending = false
	_victory_wait = 0.0
	_last_target_key = ""
	_backdrop.configure_level(game.level_number, game.level.scene)
	_backdrop.hide()
	_world_environment.background_color = Color(Diorama.PALETTES[game.level_number - 1][0])
	_environment.configure(game.level_number, game.level.scene)
	_environment.set_reduced_motion(reduced_motion)
	_monster.set_creature(str(game.level.monster_id))
	_monster.set_cooperative_mode(false)
	_monster.set_reduced_motion(reduced_motion)
	_camera.position = Vector3(0.15, 2.65, 7.8)
	_camera.look_at(Vector3(0, 1.35, 0))
	_frame_creature()
	_meter.reset_value(game.hp, maxi(1, game.max_hp), false)
	_chest.configure(game.current_chest())
	_chest.reset_closed()
	_treasure_backdrop.configure(GameData.theme(_chest.theme_id))
	_celebration.pip.set_outfit_theme(_chest.theme_id)
	_monster_name.text = str(game.level.monster_name)
	_topline.text = "%02d / 14" % game.level_number
	for label in [_topline, _meter_text, _banner]:
		label.add_theme_color_override("font_color", INK)
	_monster_name.add_theme_color_override("font_color", Color("#fff9eb"))
	_monster_name.add_theme_color_override("font_shadow_color", Color("#2c3447c0"))
	_monster_name.add_theme_constant_override("shadow_offset_x", 1)
	_monster_name.add_theme_constant_override("shadow_offset_y", 2)
	_feedback.text = ""
	_clear_transcript()
	_words.accent = Color(str(game.level.scene.accent))
	_words.reduced_motion = reduced_motion
	_words.present(game.targets)
	_banner.text = ""



func _show_map() -> void:
	pause()
	view = "map"
	_atlas.show_level(game.level_number if game.has_saved_run() else game.unlocked_level)
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
		var locked: bool = index + 1 > game.unlocked_level
		_atlas.set_level_state(index + 1, not locked, index + 1 in game.completed_levels)
		button.disabled = locked or save_failed or pending_reward
	_album_button.text = "Treasures  %d / 20" % game.collected_chests.size()
	_map_note.text = "Drag or swipe to explore"


func pause() -> void:
	cancel_scroll_input()
	sound_requested.emit("stop")
	_celebration.pause()
	stop_speech()
	# A visible release is irrevocable. Settle it before pausing the model so
	# the reward callback still sees its chest phase and commits exactly once.
	_settling_chest = true
	cancel_chest_input()
	if _opening and _chest.opening_committed():
		chest_audio_requested.emit("stop", _chest.theme_id, 0.0)
		_chest.finish_immediately()
	_settling_chest = false
	_suspended = view == "stage"
	if game.phase in ["playing", "victory", "chest", "complete"]:
		game.pause()
		_save_progress()
	_monster.process_mode = Node.PROCESS_MODE_DISABLED
	_chest.process_mode = Node.PROCESS_MODE_DISABLED
	_backdrop.process_mode = Node.PROCESS_MODE_DISABLED
	_effects.process_mode = Node.PROCESS_MODE_DISABLED
	_environment.set_active(false)
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.pause()
	_effects.clear()
	_pending_hits.clear()
	_display_hp = game.hp
	_impact_pending = false
	_victory_pending = false
	_victory_wait = 0.0
	_refresh()


func _continue_run(resume_listening: bool = true) -> void:
	if save_failed or (not game.has_saved_run() and game.phase not in ["complete", "lost"]):
		return
	if view != "stage":
		_setup_scene()
		_opening = false
		_opening_finished = game.phase == "complete"
	view = "stage"
	_suspended = false
	game.resume()
	_display_hp = game.hp
	for item in [_monster, _chest, _backdrop, _effects]:
		item.process_mode = Node.PROCESS_MODE_INHERIT
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.play()
	if game.phase == "victory":
		_play_victory()
	if game.phase == "chest":
		_banner.text = str(game.current_chest().name)
	if game.phase == "complete":
		_opening_finished = true
		_opening = false
		if _chest.mode != "opened":
			_chest.set_preview_time(ChestFeel.OPEN_SECONDS)
		_banner.text = str(game.current_chest().name)
	_refresh()
	if game.phase == "playing" and resume_listening:
		_start_listening()


func back() -> void:
	if view == "map":
		exit_requested.emit()
	else:
		_show_map()


func stop_speech() -> bool:
	_auto_listen = false
	_speech_enabled = false
	_listening = false
	_clear_transcript()
	if _host != null:
		return bool(_host.stopSpeech())
	return true


func _sync_speech_targets() -> void:
	if _host == null:
		return
	var targets: Array = []
	for target in game.targets:
		targets.append({"uid": target.uid, "text": target.word.text,
			"forms": target.get("forms", []),
			"remaining_ms": maxi(0, int((target.lifetime - target.age) * 1000))})
	_host.questTargets(JSON.stringify({"round_id": game.round_id, "targets": targets}))


func _start_listening() -> void:
	if game.phase != "playing" or view != "stage" or not is_visible_in_tree() or save_failed or _suspended:
		return
	if _host == null:
		_feedback.text = ""
		return
	if not bool(_host.speechAvailable()):
		_feedback.text = "Voice input is unavailable in this browser."
		_refresh_controls()
		return
	if _speech_enabled and not stop_speech():
		_feedback.text = "The microphone could not restart. Try again."
		return
	_auto_listen = true
	_feedback.text = "Connecting microphone…"
	_sync_speech_targets()
	_host.speechMode(true, "quest")
	_refresh_controls()


func set_listening(enabled: bool, listening: bool, message: String) -> void:
	_speech_enabled = enabled
	_listening = listening
	var status: String = message.to_lower()
	var pending: bool = status.begins_with("starting") or status.begins_with("waiting for microphone audio") \
		or status.begins_with("allow microphone access") or status.begins_with("listening paused.")
	_auto_listen = enabled and (listening or pending)
	if not listening and not (enabled and pending):
		_clear_transcript()
	if game.phase == "playing":
		_feedback.text = "" if listening else message
	_refresh_controls()
	_publish()


func show_transcript(text: String, is_final: bool) -> void:
	# Display browser hypotheses independently of the bound attack events.
	if not _speech_enabled or not _listening or game.phase != "playing" or view != "stage" \
		or not is_visible_in_tree() or save_failed or _suspended:
		return
	if interaction_allowed.is_valid() and not bool(interaction_allowed.call()):
		return
	_present_transcript(text, is_final)
	_publish()


func _present_transcript(text: String, is_final: bool) -> void:
	_transcript.text = text.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ").right(2000)
	_transcript_final = is_final and not _transcript.text.is_empty()
	_update_transcript_window()


func _clear_transcript() -> void:
	_transcript_final = false
	if _transcript != null:
		_transcript.text = ""
		_transcript.lines_skipped = 0


func _update_transcript_window() -> void:
	_transcript.lines_skipped = 0
	# Long utterances keep their newest words in the bounded caption area.
	_transcript.lines_skipped = maxi(0, _transcript.get_line_count() - _transcript.max_lines_visible)


func receive_speech(json: String) -> bool:
	if not _speech_enabled or not _listening or game.phase != "playing" or view != "stage" or not is_visible_in_tree() or save_failed or _suspended:
		return false
	if interaction_allowed.is_valid() and not bool(interaction_allowed.call()):
		return false
	var event: Variant = JSON.parse_string(json)
	if not event is Dictionary:
		return false
	var result: Dictionary = game.submit_speech_event(event)
	if not result.accepted:
		return false
	_handle_result(result, str(result.get("word", {}).get("text", "")))
	return bool(result.matched)


func _submit_text(text: String) -> void:
	# Native simulation helper; the live UI only accepts bound microphone events.
	if game.phase != "playing" or text.strip_edges().is_empty() or save_failed or _suspended:
		return
	var result: Dictionary = game.submit_transcript(text)
	_present_transcript(text, true)
	_handle_result(result, str(result.get("word", {}).get("text", text)))


func _handle_result(result: Dictionary, word: String) -> void:
	if not result.matched:
		_publish()
		return
	var uid: int = int(result.get("target_uid", 0))
	var origin: Vector2 = _words.position + _words.center_for(uid)
	var creature_center: Vector3 = _monster.to_global(Vector3(0, _monster.get_normalized_height() * 0.55, 0))
	var destination: Vector2 = _viewport_box.position + _camera.unproject_position(creature_center)
	_pending_hits.append({"time": 0.0, "word": word, "uid": uid})
	_impact_pending = true
	_effects.launch_word(uid, word, origin, destination, Style.ui_scale(self))
	sound_requested.emit("launch")
	_words.present(game.targets)
	_feedback.text = ""
	_save_progress()
	if result.completed:
		stop_speech()
		_victory_pending = true
		_victory_wait = 0.25
		_hold = 2.1
	_refresh_controls()
	_sync_speech_targets()
	_publish()


func _refresh_word_field() -> void:
	_words.present(game.targets if game.phase == "playing" else [])
	_word_count.text = "%d words left" % maxi(0, game.total_words - game.hits - game.misses)
	var key: String = str(game.spawned) + ":" + str(game.misses)
	if key != _last_target_key:
		_last_target_key = key
		_sync_speech_targets()


func _spell_impact(target_uid: int) -> void:
	if _pending_hits.is_empty() or view != "stage" or _suspended or game.phase == "paused":
		return
	var hit_index: int = -1
	for index in range(_pending_hits.size()):
		if int(_pending_hits[index].uid) == target_uid:
			hit_index = index
			break
	# A slow frame or resized effect can settle through the fallback first.
	# Its later visual callback must never consume another word's projectile.
	if hit_index < 0:
		return
	_pending_hits.remove_at(hit_index)
	_impact_pending = not _pending_hits.is_empty()
	_display_hp = maxi(game.hp, _display_hp - 1)
	_monster.react_hit()
	_update_meter()
	_pulse_label(_meter_text, Color("#70559e"))
	sound_requested.emit("hit")
	if game.phase == "lost" and not _impact_pending:
		_refresh()


func _pulse_label(label: Label, color: Color) -> void:
	var previous: Tween = _label_tweens.get(label)
	if previous != null and previous.is_valid():
		previous.kill()
	label.add_theme_color_override("font_color", color)
	label.modulate.a = 1.0
	label.scale = Vector2.ONE
	if reduced_motion:
		label.add_theme_color_override("font_color", INK)
		return
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 1.025
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: label.add_theme_color_override("font_color", INK))
	_label_tweens[label] = tween


func _play_victory() -> void:
	_monster.defeat()
	_celebration.set_companion_mode(false)
	_refresh()
	var first_celebration: bool = _celebration.begin(_chest.theme_id)
	if first_celebration:
		_hold = maxf(3.2, _monster.source_animation_duration("Defeat") + 0.35 if not reduced_motion else 0.0)
	else:
		# A resumed victory stays happy without replaying its calls or dance.
		_celebration.settle()
		_hold = maxf(0.6, _hold)
	_effects.clear()
	_backdrop.celebrate()
	_environment.celebrate()
	_effects.celebrate(_viewport_box.position + _viewport_box.size * Vector2(0.5, 0.5))
	if first_celebration:
		sound_requested.emit("victory")
		sound_requested.emit("pip_victory")
	_refresh()


func is_chest_control(control: Control) -> bool:
	return control == _chest_button and _chest_button.is_visible_in_tree() and not _chest_button.disabled


func start_chest_hold() -> void:
	if _holding_chest or _opening or save_failed or _suspended or view != "stage" \
		or game.phase != "chest" or not is_visible_in_tree():
		return
	if interaction_allowed.is_valid() and not interaction_allowed.call():
		return
	_holding_chest = true
	_chest_hold_elapsed = 0.0
	_chest_hold_frame = Engine.get_process_frames()
	_dragging_chest = true
	_chest_has_anchor = false
	chest_audio_requested.emit("prepare", _chest.theme_id, 0.0)
	_chest.begin_hold()
	chest_audio_requested.emit("charge", _chest.theme_id, 0.0)
	_refresh_chest_caption()
	_publish()


func end_chest_hold() -> void:
	cancel_chest_input(true)


func cancel_chest_input(animate_return: bool = false) -> void:
	var active: bool = _holding_chest or _opening
	_holding_chest = false
	_chest_hold_elapsed = 0.0
	_chest_hold_frame = -1
	_dragging_chest = false
	_chest_has_anchor = false
	if not is_instance_valid(_chest) or not active:
		return
	if _opening and _chest.opening_committed():
		return
	if _opening:
		_chest.cancel_open(animate_return)
	elif animate_return:
		_chest.cancel_hold()
	else:
		_chest.set_hold_progress(0.0)
	_opening = false
	chest_audio_requested.emit("cancel" if animate_return else "stop", _chest.theme_id, 0.0)
	_refresh_controls()
	_publish()


func _advance_chest_hold(delta: float) -> void:
	if view != "stage" or _suspended or game.phase != "chest":
		return
	if _holding_chest and not _opening and delta > 0.0 and is_finite(delta):
		_chest_hold_elapsed += delta
		var progress: float = clampf(_chest_hold_elapsed / ChestFeel.HOLD_SECONDS, 0.0, 1.0)
		_chest.set_hold_progress(progress)
		chest_audio_requested.emit("charge", _chest.theme_id, progress)
		if progress >= 1.0:
			_open_chest()
	if _opening:
		chest_audio_requested.emit("release" if _chest.opening_committed() else "tension", _chest.theme_id, _chest.tension_progress())
	_refresh_chest_caption()


func _open_chest() -> void:
	if game.phase != "chest" or _opening or not _holding_chest or save_failed or _suspended \
		or _chest_hold_elapsed < ChestFeel.HOLD_SECONDS:
		return
	_opening = true
	_opening_finished = false
	# Reduced motion can synchronously emit opened here.
	_chest.start_open(reduced_motion)
	_refresh_controls()


func _on_chest_released() -> void:
	if not _opening or not _chest.opening_committed():
		return
	# Disabling a pressed Button can emit button_up. Clear the gesture first.
	_holding_chest = false
	_dragging_chest = false
	_chest_has_anchor = false
	_chest_hold_frame = -1
	chest_audio_requested.emit("release", _chest.theme_id, 1.0)
	_refresh_controls()
	_publish()


func _on_chest_cue(theme_id: String, cue: String, step: int) -> void:
	if _settling_chest or _suspended or view != "stage" or game.phase != "chest" or not is_visible_in_tree():
		return
	if cue in ["press", "hold_pulse"] and (not _holding_chest or _opening):
		return
	if cue == "charge_step" and not (_holding_chest or _opening):
		return
	if cue in ["opening", "tension_pulse", "anticipation", "unlock", "release", "settle"] and not _opening:
		return
	chest_cue_requested.emit(theme_id, cue, step)


func _announce_chest_reward(explicit_retry: bool = false) -> void:
	if _reward_announced or save_failed or game.phase != "complete":
		return
	_reward_announced = true
	if not _settling_chest and not _suspended and view == "stage" and is_visible_in_tree():
		chest_audio_requested.emit("reward", _chest.theme_id, 1.0 if explicit_retry else 0.0)


func _reward_finished() -> void:
	if game.phase != "chest" or not _opening or _chest.mode != "opened":
		return
	_holding_chest = false
	_dragging_chest = false
	_chest_has_anchor = false
	_chest_hold_elapsed = 0.0
	_chest_hold_frame = -1
	_opening = false
	_opening_finished = true
	game.open_chest()
	chest_audio_requested.emit("finish", _chest.theme_id, 1.0)
	if not _settling_chest and not _suspended and is_visible_in_tree():
		_chest.show_surprise()
	_save_progress()
	_announce_chest_reward()
	_banner.text = str(game.current_chest().get("name", ""))
	_rebuild_map()
	_refresh()
	if not _settling_chest and _next.visible and not _next.disabled:
		_next.grab_focus()


func _refresh_chest_caption() -> void:
	if _chest_caption == null:
		return
	_chest_caption.text = "Hold your treasure to open"
	if _opening:
		_chest_caption.text = "It's yours!" if _chest.opening_committed() else "Keep holding..."
	elif _holding_chest:
		_chest_caption.text = "Keep holding..."
	_chest_button.tooltip_text = _chest_caption.text
	_chest_button.accessibility_name = "Hold to open your treasure. Release before it opens to cancel."


func _chest_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not event.canceled:
			start_chest_hold()
		else:
			end_chest_hold()
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			start_chest_hold()
		else:
			end_chest_hold()
		return
	if not _dragging_chest:
		return
	var relative := Vector2.ZERO
	var pointer := Vector2.ZERO
	if event is InputEventMouseMotion:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		relative = event.relative
		pointer = event.position
	elif event is InputEventScreenDrag:
		relative = event.relative
		pointer = event.position
	else:
		return
	if not _chest_has_anchor:
		_chest_drag_anchor = pointer - relative
		_chest_drag_offset = _chest.drag_offset
		_chest_has_anchor = true
	var displacement: Vector2 = pointer - _chest_drag_anchor
	if displacement.length() > 10.0 and _holding_chest:
		var anchor: Vector2 = _chest_drag_anchor
		var offset: Vector2 = _chest_drag_offset
		cancel_chest_input(true)
		_dragging_chest = true
		_chest_has_anchor = true
		_chest_drag_anchor = anchor
		_chest_drag_offset = offset
	_chest.set_drag_offset(_chest_drag_offset + displacement)


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
	_advance_chest_hold(0.0 if Engine.get_process_frames() == _chest_hold_frame else delta)
	_treasure_backdrop.set_reveal(1.0 if game.phase == "complete" else _chest.performance_progress() if _opening else 0.0)
	var started_victory: bool = false
	if view == "stage" and not _suspended and game.phase != "paused":
		if game.phase == "playing" and not reduced_motion and _monster.creature_id.begins_with("giant-"):
			_threat_left -= delta
			if _threat_left <= 0.0 and _monster.state == "idle" and not _impact_pending:
				_monster.play_attack()
				_threat_left = 7.5
		for hit in _pending_hits:
			hit.time += delta
		while not _pending_hits.is_empty() and float(_pending_hits[0].time) >= (0.12 if reduced_motion else 0.56):
			_spell_impact(int(_pending_hits[0].uid))
		if _victory_pending and not _impact_pending:
			_victory_wait -= delta
			if _victory_wait <= 0:
				_victory_pending = false
				_play_victory()
				started_victory = true
		if game.phase == "playing" and not save_failed and (_listening or not OS.has_feature("web")):
			game.advance(delta)
			_refresh_word_field()
			if game.phase == "lost":
				stop_speech()
				_save_progress()
				_refresh()
		if _hold > 0 and not started_victory and not _victory_pending:
			_hold = maxf(0.0, _hold - delta)
			if _hold <= 0:
				if game.phase == "victory":
					sound_requested.emit("pip_stop")
					_celebration.settle()
					_effects.clear()
					game.finish_victory()
					_save_progress()
					_banner.text = str(game.current_chest().name)
					_chest.configure(game.current_chest())
				_refresh()
	_status_clock += delta
	if _status_clock >= 0.2:
		_status_clock = 0
		if _listening:
			_sync_speech_targets()
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
	_map_note.text = "Progress could not be saved." if save_failed else "Drag or swipe to explore"
	_words.visible = game.phase == "playing" and not _suspended
	_word_count.visible = _words.visible
	_transcript.visible = _words.visible
	_feedback.visible = _words.visible
	var show_pause: bool = view == "stage" and (game.phase == "paused" or _suspended)
	var first_pause: bool = show_pause and not _pause_card.visible
	var context_phase: String = game._paused_phase if game.phase == "paused" else game.phase
	var reward_context: bool = context_phase in ["chest", "complete"]
	var show_victory: bool = view == "stage" and game.phase == "victory" and not show_pause and not _victory_pending
	var show_loss: bool = view == "stage" and game.phase == "lost" and not _suspended and not _impact_pending
	_monster_name.visible = game.phase in ["playing", "victory", "paused", "lost"]
	_viewport_box.visible = not game.level.is_empty() and not reward_context and not show_loss
	if reward_context:
		_monster.hide()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() and view == "stage" and _viewport_box.visible else SubViewport.UPDATE_DISABLED
	_environment.set_active(is_visible_in_tree() and view == "stage" and _viewport_box.visible and not _suspended and game.phase != "paused")
	_treasure_backdrop.visible = reward_context or show_victory
	_treasure_backdrop.set_active(is_visible_in_tree() and view == "stage" and not show_pause)
	_celebration.set_companion_mode(reward_context)
	if reward_context:
		_celebration.settle()
	_celebration.visible = (show_victory or reward_context) and not show_pause
	_reward_eyebrow.visible = reward_context and not show_pause
	_reward_detail.visible = reward_context and not show_pause
	_reward_eyebrow.text = "ADDED TO YOUR COLLECTION" if game.phase == "complete" else "ADVENTURE %02d COMPLETE" % game.level_number
	_reward_detail.text = ("Tinker is your new friend!" if game.level_number == 14 else "%d / 20 treasures discovered" % game.collected_chests.size()) if game.phase == "complete" else "%d word hits  ·  A treasure for you" % game.hits
	_chest.visible = reward_context
	_companion.visible = game.phase == "complete" and game.level_number == 14 and not _suspended
	_chest_button.visible = game.phase == "chest"
	_chest_caption.visible = game.phase == "chest" and not _suspended
	_next.visible = game.phase == "complete"
	_next.text = "Back to the map" if game.level_number == 14 else "Next adventure"
	_resume.visible = show_pause
	if show_pause:
		var subject: String = str(game.current_chest().name) if reward_context else str(game.level.monster_name)
		_pause_card.present_pause(game.level_number, subject, game.hits, game.max_hp, game.hp, context_phase, save_failed)
	else:
		_pause_card.hide()
	var first_loss: bool = show_loss and not _loss.visible
	_retry.visible = show_loss
	if show_loss:
		_loss.present(game.level_number, str(game.level.monster_name), game.hits, game.max_hp, game.hp, save_failed)
	else:
		_loss.hide()
	_stage_header.visible = not show_loss and not show_pause and not reward_context and not show_victory
	_topline.visible = _stage_header.visible
	_back.visible = not show_loss and not show_pause
	_loss_backdrop.visible = show_loss or show_pause
	_banner.visible = reward_context and not show_pause
	if show_pause:
		_chest_button.hide()
		_next.hide()
	if not _impact_pending:
		_display_hp = game.hp
	_refresh_word_field()
	_update_meter()
	_refresh_controls()
	_layout()
	if first_loss and is_visible_in_tree() and not _retry.disabled:
		_retry.grab_focus()
	if first_pause and is_visible_in_tree() and not _resume.disabled:
		_resume.grab_focus()
	_publish()


func _refresh_controls() -> void:
	_mic_retry.visible = game.phase == "playing" and not _suspended and not _listening and not _auto_listen and _host != null
	_mic_retry.disabled = save_failed
	_chest_button.disabled = save_failed or _chest.opening_committed() or _suspended
	_refresh_chest_caption()
	_next.disabled = not _opening_finished or save_failed
	_back.disabled = save_failed
	_retry.disabled = save_failed
	_loss.map_button.disabled = save_failed
	_resume.disabled = save_failed
	_pause_card.map_button.disabled = save_failed


func _update_meter() -> void:
	if game.level.is_empty():
		_meter.hide()
		_meter_text.hide()
		return
	_meter.visible = game.phase in ["playing", "lost"] and not _loss.visible and not _pause_card.visible
	_meter_text.visible = _meter.visible
	_meter.present(_display_hp, maxi(1, game.max_hp), false)
	_meter_text.text = "%d / %d" % [_display_hp, game.max_hp]
	_backdrop.set_progress(game.progress_ratio())
	_environment.set_progress(game.progress_ratio())


func _layout() -> void:
	if _stage == null or size.x <= 0 or size.y <= 0:
		return
	var s: float = Style.ui_scale(self)
	var w: float = size.x
	var h: float = size.y
	var gap: float = 10 / s
	var landscape: bool = w * s >= 440 and h * s < 320
	for panel in [_map, _stage_scroll, _album]:
		panel.size = size
	_album_button.add_theme_font_size_override("font_size", ceili(12 / s))
	_continue.add_theme_font_size_override("font_size", ceili(14 / s))
	var album_width: float = maxf(132 / s, _album_button.get_combined_minimum_size().x)
	_map_heading.position = Vector2(6, 0) / s
	_map_heading.size = Vector2(maxf(1, w - album_width - 18 / s), 34 / s)
	_map_heading.add_theme_font_size_override("font_size", ceili((20 if w * s < 360 else 24) / s))
	_map_note.position = Vector2(6, 34) / s
	_map_note.size = Vector2(w - 12 / s, 20 / s)
	_map_note.add_theme_font_size_override("font_size", ceili(11 / s))
	_album_button.position = Vector2(w - album_width - 4 / s, 0)
	_album_button.size = Vector2(album_width, 48 / s)
	_continue.position = Vector2(0, 58 / s)
	_continue.size = Vector2(w, 40 / s)
	var map_top: float = (106 if _continue.visible else 58) / s
	_map_note.visible = not landscape
	if landscape:
		# Keep the resumed map's chapter area as tall as a fresh map.
		_map_heading.position.y = 2 / s
		_map_heading.size.x = maxf(1, w - album_width - (122 if _continue.visible else 18) / s)
		_album_button.custom_minimum_size.y = ceilf(44 / s)
		_album_button.size.y = 44 / s
		_continue.custom_minimum_size.y = ceilf(44 / s)
		_continue.position = Vector2(w - album_width - 112 / s, 0)
		_continue.size = Vector2(100, 44) / s
		map_top = 44 / s
	else:
		_album_button.custom_minimum_size.y = ceilf(48 / s)
		_continue.custom_minimum_size.y = ceilf(48 / s)
	_atlas.position = Vector2(0, map_top)
	_atlas.size = Vector2(w, maxf(0, h - map_top))
	_atlas.set_ui_scale(s)
	var album_columns: int = 4 if w * s >= 740 else 3 if w * s >= 460 else 2
	var tile_w: float = (w - gap * (album_columns - 1) - 14 / s) / album_columns
	_stage.custom_minimum_size = Vector2.ZERO
	_stage.size = Vector2(w, h)
	_stage_scroll.scroll_vertical = 0
	var header_h: float = (52 if landscape else 78) / s
	var footer_h: float = (24 if landscape else 120 if _mic_retry.visible else 68) / s
	var scene_h: float = maxf(76 / s, (h - header_h - footer_h) * 0.48)
	var arena_top: float = header_h + scene_h
	_backdrop.size = Vector2(w, h)
	_loss_backdrop.size = Vector2(w, h)
	_treasure_backdrop.position = Vector2.ZERO
	_treasure_backdrop.size = Vector2(w, h)
	_viewport_box.position = Vector2(0, header_h)
	_viewport_box.size = Vector2(w, scene_h)
	_camera.size = maxf(4.3, 3.6 / maxf(0.4, w / maxf(1, scene_h)))
	_stage_header.position = Vector2(4, 2) / s
	_stage_header.size = Vector2(w - 8 / s, header_h - 4 / s)
	_back.position = Vector2(w - 68 / s, 7 / s)
	_back.add_theme_font_size_override("font_size", ceili(13 / s))
	_back.custom_minimum_size.y = ceilf(44 / s)
	_back.size = Vector2(60, 44) / s
	_topline.position = Vector2(14, 7) / s
	_topline.size = Vector2(w - 92 / s, 23 / s)
	_topline.add_theme_font_size_override("font_size", ceili(14 / s))
	_meter.position = Vector2(14 / s, header_h - 33 / s)
	_meter.size = Vector2(maxf(20 / s, w - 169 / s), 19 / s)
	_meter_text.position = Vector2(w - 148 / s, header_h - 35 / s)
	_meter_text.size = Vector2(64, 24) / s
	_meter_text.add_theme_font_size_override("font_size", ceili(12 / s))
	_monster_name.position = Vector2(8 / s, arena_top - 23 / s)
	_monster_name.size = Vector2(w - 16 / s, 21 / s)
	_monster_name.add_theme_font_size_override("font_size", ceili(12 / s))
	_words.position = Vector2(0, arena_top)
	_words.size = Vector2(w, maxf(40 / s, h - arena_top - footer_h))
	_word_count.position = _words.position + Vector2(12, 7) / s
	_word_count.size = Vector2(w - 24 / s, 18 / s)
	_word_count.add_theme_font_size_override("font_size", ceili(11 / s))
	_transcript.position = Vector2(8 / s, h - 65 / s)
	_transcript.size = Vector2(w - 16 / s, 44 / s)
	_transcript.max_lines_visible = 2
	_transcript.add_theme_font_size_override("font_size", ceili(14 / s))
	_feedback.position = Vector2(8 / s, h - 21 / s)
	_feedback.size = Vector2(w - 16 / s, 20 / s)
	_feedback.add_theme_font_size_override("font_size", ceili(11 / s))
	_mic_retry.position = Vector2(w * 0.2, h - 118 / s)
	_mic_retry.size = Vector2(w * 0.6, 42 / s)
	_monster_name.visible = game.phase in ["playing", "victory", "paused", "lost"]
	if landscape:
		# Short phone viewports keep full-size controls and split the two play areas.
		var scene_width: float = w * 0.37
		var content_height: float = maxf(60 / s, h - header_h - footer_h)
		_viewport_box.position = Vector2(0, header_h)
		_viewport_box.size = Vector2(scene_width, content_height)
		_camera.size = maxf(4.3, 3.6 / maxf(0.4, scene_width / content_height))
		_back.position.y = 4 / s
		_topline.position = Vector2(12, 15) / s
		_topline.size = Vector2(w * 0.36, 23 / s)
		_topline.add_theme_font_size_override("font_size", ceili(12 / s))
		_meter.position = Vector2(w * 0.40, 19 / s)
		_meter.size = Vector2(maxf(30 / s, w * 0.60 - 144 / s), 16 / s)
		_meter_text.position = Vector2(w - 136 / s, 15 / s)
		_meter_text.size = Vector2(56, 23) / s
		_monster_name.position = Vector2(4 / s, h - footer_h - 20 / s)
		_monster_name.size = Vector2(scene_width - 8 / s, 18 / s)
		_monster_name.visible = _monster_name.visible and not _mic_retry.visible
		_words.position = Vector2(scene_width + 6 / s, header_h)
		_words.size = Vector2(w - _words.position.x, content_height)
		_word_count.position = _words.position + Vector2(10, 3) / s
		_word_count.size = Vector2(_words.size.x - 20 / s, 17 / s)
		_transcript.position = Vector2(scene_width + 8 / s, h - 23 / s)
		_transcript.size = Vector2(w - scene_width - 16 / s, 21 / s)
		_transcript.max_lines_visible = 1
		_transcript.add_theme_font_size_override("font_size", ceili(12 / s))
		_feedback.position = Vector2(8 / s, h - 22 / s)
		_feedback.size = Vector2(scene_width - 16 / s, 21 / s)
		_mic_retry.add_theme_font_size_override("font_size", ceili(12 / s))
		_mic_retry.custom_minimum_size.y = ceilf(44 / s)
		_mic_retry.position = Vector2(6 / s, h - footer_h - 46 / s)
		_mic_retry.size = Vector2(scene_width - 12 / s, 44 / s)
	else:
		_mic_retry.add_theme_font_size_override("font_size", ceili(14 / s))
		_mic_retry.custom_minimum_size.y = ceilf(48 / s)
	_update_transcript_window()
	_loss.size = _stage.size
	_loss.layout()
	_pause_card.size = _stage.size
	_pause_card.layout()
	var intermission: QuestResult = _pause_card if _pause_card.visible else _loss
	if intermission.visible:
		_viewport_box.position = intermission.hero_rect.position
		_viewport_box.size = intermission.hero_rect.size
		_monster_name.hide()
		if _pause_card.visible and _viewport_box.visible:
			_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_frame_creature()
	_banner.position = Vector2(w * 0.08, header_h + 6 / s)
	_banner.size = Vector2(w * 0.84, minf(90 / s, h * 0.21))
	_banner.add_theme_font_size_override("font_size", ceili(28 / s))
	var chest_top: float = minf(160 / s, h * 0.35)
	_chest.position = Vector2(w * 0.08, chest_top)
	_chest.size = Vector2(w * 0.84, maxf(45 / s, h - chest_top - 60 / s))
	_chest_button.position = _chest.position
	_chest_button.size = _chest.size
	_chest_caption.position = Vector2(w * 0.06, h - 56 / s)
	_chest_caption.size = Vector2(w * 0.88, 50 / s)
	_chest_caption.add_theme_font_size_override("font_size", ceili(16 / s))
	_companion.position = Vector2(w * 0.5 - 36 / s, chest_top - 40 / s)
	_companion.size = Vector2(72, 72) / s
	if _pause_card.visible and _pause_card.context_phase in ["chest", "complete"]:
		_treasure_backdrop.position = _pause_card.hero_rect.position
		_treasure_backdrop.size = _pause_card.hero_rect.size
		_chest.position = _pause_card.hero_rect.position + Vector2(6, 4) / s
		_chest.size = _pause_card.hero_rect.size - Vector2(12, 35) / s
		_treasure_backdrop.set_presentation_rects(Rect2(), Rect2(_chest.position - _treasure_backdrop.position, _chest.size))
	for button in [_next]:
		_style_button(button, true)
		button.position = Vector2(w * 0.15, h - 50 / s)
		button.size = Vector2(w * 0.7, 44 / s)
	_layout_reward_presentation(s)
	_effects.size = _stage.size
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
	_album_grid.columns = album_columns
	_album_grid.add_theme_constant_override("h_separation", ceili(gap))
	_album_grid.add_theme_constant_override("v_separation", ceili(gap))
	for item in _album_grid.get_children():
		item.custom_minimum_size = Vector2(tile_w, 160 / s)
		item.get_meta("art").position = Vector2(8, 5) / s
		item.get_meta("art").size = Vector2(tile_w - 16 / s, 110 / s)
		item.get_meta("label").position = Vector2(8, 116) / s
		item.get_meta("label").size = Vector2(tile_w - 16 / s, 40 / s)
		item.get_meta("label").add_theme_font_size_override("font_size", ceili(12 / s))


func _layout_reward_presentation(s: float) -> void:
	var w: float = size.x
	var h: float = size.y
	var unit: float = 1.0 / s
	var compact: bool = h * s < 320 and w * s >= 440
	var wide: bool = w > h * 1.2
	_celebration.set_ui_scale(s)
	if game.phase == "victory" and not _suspended:
		_monster_name.hide()
		if wide:
			_viewport_box.position = Vector2(0, 48 * unit)
			_viewport_box.size = Vector2(w * 0.44, maxf(40 * unit, h - 48 * unit))
			_celebration.position = Vector2(w * 0.44, 8 * unit)
			_celebration.size = Vector2(w * 0.56, h - 16 * unit)
		else:
			_viewport_box.position = Vector2(0, 48 * unit)
			_viewport_box.size = Vector2(w, maxf(40 * unit, h * 0.35 - 48 * unit))
			_celebration.position = Vector2(0, h * 0.35)
			_celebration.size = Vector2(w, h * 0.65)
		_treasure_backdrop.set_presentation_rects(Rect2(), _celebration.get_rect())
		_frame_creature()
	if game.phase not in ["chest", "complete"] or _suspended:
		return
	# Set typography before sizing: shrinking a font does not shrink a Label's
	# size after a previous minimum-size clamp in a differently scaled viewport.
	_chest_caption.add_theme_font_size_override("font_size", ceili((12 if compact else 15) * unit))
	_next.add_theme_font_size_override("font_size", ceili((13 if compact else 15) * unit))
	var title_rect: Rect2
	var chest_rect: Rect2
	if compact:
		var column: float = w * 0.39
		title_rect = Rect2(10 * unit, 4 * unit, column - 14 * unit, 64 * unit)
		chest_rect = Rect2(column, 10 * unit, w - column - 6 * unit, h - 20 * unit)
		_celebration.position = Vector2(8 * unit, 62 * unit)
		_celebration.size = Vector2(64 * unit, maxf(40 * unit, h - 108 * unit))
		_chest_caption.position = Vector2(76 * unit, 69 * unit)
		_chest_caption.size = Vector2(maxf(30 * unit, column - 84 * unit), maxf(36 * unit, h - 119 * unit))
		_next.position = Vector2(8 * unit, h - 48 * unit)
		_next.size = Vector2(column - 16 * unit, 44 * unit)
		_back.position = Vector2(w - 66 * unit, 4 * unit)
	else:
		title_rect = Rect2(w * 0.08, 52 * unit, w * 0.84, 94 * unit)
		var chest_top: float = minf(152 * unit, h * 0.32)
		chest_rect = Rect2(w * (0.28 if wide else 0.05), chest_top,
			w * (0.64 if wide else 0.90), maxf(56 * unit, h - chest_top - 64 * unit))
		var pip_size: float = minf(210 * unit, minf(w * (0.24 if wide else 0.27), h * 0.26))
		_celebration.position = Vector2(w * (0.045 if wide else 0.01), h - 68 * unit - pip_size)
		_celebration.size = Vector2(pip_size, pip_size)
		_chest_caption.position = Vector2(w * 0.12, h - 53 * unit)
		_chest_caption.size = Vector2(w * 0.76, 42 * unit)
		_next.position = Vector2(w * 0.19, h - 52 * unit)
		_next.size = Vector2(w * 0.62, 44 * unit)
	_reward_eyebrow.position = title_rect.position
	_reward_eyebrow.size = Vector2(title_rect.size.x, (16 if compact else 20) * unit)
	_reward_eyebrow.add_theme_font_size_override("font_size", ceili((10 if compact else 11) * unit))
	_banner.position = title_rect.position + Vector2(0, (18 if compact else 23) * unit)
	_banner.size = Vector2(title_rect.size.x, (28 if compact else 39) * unit)
	_banner.add_theme_font_size_override("font_size", ceili((17 if compact else 24) * unit))
	_banner.max_lines_visible = 1
	_banner.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_reward_detail.position = title_rect.position + Vector2(0, (48 if compact else 65) * unit)
	_reward_detail.size = Vector2(title_rect.size.x, 24 * unit)
	_reward_detail.add_theme_font_size_override("font_size", ceili((10 if compact else 12) * unit))
	_reward_detail.visible = not compact
	_chest.position = chest_rect.position
	_chest.size = chest_rect.size
	_chest_button.position = chest_rect.position
	_chest_button.size = chest_rect.size
	for label in [_banner, _reward_eyebrow, _reward_detail, _chest_caption]:
		label.add_theme_color_override("font_color", Color("#fff4d9"))
		label.add_theme_color_override("font_shadow_color", Color("#16242fe0"))
		label.add_theme_constant_override("shadow_offset_y", 2)
	_companion.position = Vector2(w - 72 * unit, h - 136 * unit)
	_companion.size = Vector2(64, 64) * unit
	_treasure_backdrop.set_presentation_rects(title_rect, chest_rect)


func _frame_giant_reaction(kind: String) -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	var expansion: float = 1.0
	if kind == "attack" and not reduced_motion:
		expansion = 1.40 if _monster.creature_id == "giant-storm-dragon" else 1.25 if _monster.creature_id == "giant-ember-golem" else 1.04
	elif kind == "hit" and not reduced_motion and _monster.creature_id == "giant-ember-golem":
		expansion = 1.35
	if reduced_motion:
		_apply_giant_camera_expansion(1.0)
		return
	# Give raised heads, horns and impact gestures room before returning close.
	_camera_tween = create_tween().bind_node(_monster)
	_camera_tween.tween_method(_apply_giant_camera_expansion, _giant_camera_expansion, expansion, 0.10 if kind == "hit" else 0.12 if kind == "attack" else 0.32).set_trans(Tween.TRANS_SINE)


func _apply_giant_camera_expansion(value: float) -> void:
	_giant_camera_expansion = value
	_frame_creature()


func _frame_creature() -> void:
	if _monster == null or _camera == null or _viewport_box.size.y <= 0.0:
		return
	var aspect: float = maxf(0.4, _viewport_box.size.x / _viewport_box.size.y)
	if _monster.creature_id.begins_with("giant-"):
		# Keep a massive standing body while allowing room for lateral attacks.
		var model_height: float = maxf(0.5, _monster.get_normalized_height())
		var scale_value: float = 3.35 / model_height
		_monster.scale = Vector3.ONE * scale_value
		_monster.position = Vector3(0, 0, 0.35)
		var bounds: AABB = _monster.get_model_bounds()
		var dragon: bool = _monster.creature_id == "giant-storm-dragon"
		var focus_height: float = (2.8 if dragon else 1.65) + (_giant_camera_expansion - 1.0) * 0.85
		_camera.position = Vector3(0.18, 1.30, 9.6)
		_camera.look_at(Vector3(0, focus_height, 0.15))
		var body_frame: float = 5.0 if dragon else 4.65 if _monster.creature_id == "giant-ember-golem" else 4.15
		var width_frame: float = (bounds.size.x * scale_value + 0.16) * 1.12 / aspect
		var visible_height: float = maxf(body_frame, width_frame) * _giant_camera_expansion
		_camera.fov = rad_to_deg(2.0 * atan(visible_height / (2.0 * 9.6)))
		return
	_camera.position = Vector3(0.15, 2.65, 7.8)
	_camera.look_at(Vector3(0, 1.35, 0))
	var frame_height: float = maxf(4.15, 3.65 / aspect)
	_camera.fov = rad_to_deg(2.0 * atan(frame_height / (2.0 * 7.8)))
	var creature_height: float = _monster.get_normalized_height()
	# Wide creatures can be larger on desktop; mobile keeps their wings in frame.
	var creature_scale: float = minf(3.0, minf(2.5 / maxf(0.5, creature_height), frame_height * aspect / 2.65))
	_monster.scale = Vector3.ONE * creature_scale
	_monster.position = Vector3(0, 0.25 if creature_height < 1.1 else 0.0, 0.20)


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if _stage != null:
		_monster.set_reduced_motion(enabled)
		if enabled:
			if _camera_tween != null and _camera_tween.is_valid():
				_camera_tween.kill()
			_apply_giant_camera_expansion(1.0)
		_backdrop.set_reduced_motion(enabled)
		_chest.set_reduced_motion(enabled)
		_celebration.set_reduced_motion(enabled)
		_treasure_backdrop.set_reduced_motion(enabled)
		if enabled and _opening:
			_chest.finish_immediately()
		_environment.set_reduced_motion(enabled)
		_atlas.set_reduced_motion(enabled)
		_words.reduced_motion = enabled
		_effects.reduced_motion = enabled
		_meter.reduced_motion = enabled
		_loss.set_reduced_motion(enabled)
		_pause_card.set_reduced_motion(enabled)
		if enabled:
			for label: Label in _label_tweens:
				var tween: Tween = _label_tweens[label]
				if tween != null and tween.is_valid():
					tween.kill()
				label.scale = Vector2.ONE
				label.add_theme_color_override("font_color", INK)
			_label_tweens.clear()
			_meter.present(_meter._target, _meter.max_value, _meter.cooperative, false)
		for button in [_back, _continue, _album_button, _album_back, _next, _resume, _retry, _mic_retry, _save_retry]:
			button.set_reduced_motion(enabled)


func _visibility() -> void:
	if not is_visible_in_tree():
		pause()
	else:
		_refresh()


func default_focus() -> Control:
	if view == "map":
		if _continue.visible:
			return _continue
		if _atlas._current_stop > 0 and not _level_buttons[_atlas._current_stop - 1].disabled:
			return _level_buttons[_atlas._current_stop - 1]
		for button in _atlas.visible_level_buttons():
			if not button.disabled:
				return button
		return _album_button
	if view == "album":
		return _album_back
	if game.phase == "paused" or _suspended:
		return _resume
	if game.phase == "chest":
		return _chest_button
	if game.phase == "complete":
		return _next
	if game.phase == "lost":
		return _retry
	return _mic_retry if _mic_retry.visible else _back


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
	if _loss.visible:
		controls["map"] = _rect(_loss.map_button)
	if _pause_card.visible:
		controls["map"] = _rect(_pause_card.map_button)
	controls["map_previous"] = _rect(_atlas._previous)
	controls["map_next"] = _rect(_atlas._next)
	controls["map_current"] = _rect(_atlas._home)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var levels: Array = []
	for button in _level_buttons:
		var entry: Dictionary = _rect(button)
		entry.in_view = _atlas.level_in_view(button)
		entry.visible = entry.visible and entry.in_view
		entry.compact = button.compact
		entry.caption = _rect(button._caption)
		if button.compact:
			var badge: Rect2 = button.compact_badge_rect()
			badge.position += button.global_position
			entry.badge = {"x": badge.position.x / viewport_size.x, "y": badge.position.y / viewport_size.y,
				"width": badge.size.x / viewport_size.x, "height": badge.size.y / viewport_size.y}
		levels.append(entry)
	var targets: Array = []
	for item in _words.geometry():
		var center: Vector2 = _words.global_position + item.center
		targets.append({"uid": item.uid, "word": item.word, "text": item.word.text,
			"forms": item.forms, "remaining_ms": item.remaining_ms,
			"rect": {"x": (center.x - item.size.x * 0.5) / viewport_size.x,
				"y": (center.y - item.size.y * 0.5) / viewport_size.y,
				"width": item.size.x / viewport_size.x, "height": item.size.y / viewport_size.y}})
	return {"active": is_visible_in_tree(), "view": view, "phase": game.phase,
		"level": game.level_number, "line_index": game.line_index, "prompt": game.current_prompt(),
		"hp": game.hp, "max_hp": game.max_hp, "displayed_hp": _display_hp,
		"hits": game.hits, "misses": game.misses, "spawned": game.spawned, "total_words": game.total_words,
		"targets": targets, "projectiles": _pending_hits.duplicate(true),
		"completed": game.completed_levels, "unlocked": game.unlocked_level,
		"chests": game.collected_chests, "total_clears": game.total_clears,
		"transcript": _transcript.text, "transcript_final": _transcript_final, "feedback": _feedback.text,
		"listening": _listening, "busy": _hold > 0 or _opening or _holding_chest, "save_failed": save_failed,
		"holding_chest": _holding_chest, "chest_progress": _chest.performance_progress(),
		"chest_phase": _chest.performance_phase(), "chest_committed": _chest.opening_committed(),
		"victory_celebration": _celebration.snapshot(),
		"treasure_presentation": _treasure_backdrop.snapshot(),
		"loss_result": {"visible": _loss.is_visible_in_tree(), "hits": _loss.hits, "max_hp": _loss.max_hp,
			"remaining_hp": _loss.remaining_hp, "reveal": _loss.reveal,
			"pip_visible": _loss.pip.is_visible_in_tree(), "pip_emotion": _loss.loss_emotion},
		"pause_result": {"visible": _pause_card.is_visible_in_tree(), "context_phase": _pause_card.context_phase,
			"hits": _pause_card.hits, "max_hp": _pause_card.max_hp, "remaining_hp": _pause_card.remaining_hp,
			"reveal": _pause_card.reveal},
		"controls": controls, "levels": levels, "map_chapter": _atlas.current_chapter,
		"map_scroll_max": _atlas._scroll._maximum(), "map_scroll_offset": _atlas._scroll.scroll_horizontal,
		"map_scroll_rect": _rect(_atlas._scroll),
		"reduced_motion": reduced_motion, "scroll_offset": 0,
		"paused": _suspended or game.phase == "paused", "scroll_max": 0}


func _publish() -> void:
	if _host != null:
		_host.questStatus(JSON.stringify(snapshot()))


func _exit_tree() -> void:
	cancel_chest_input()
	stop_speech()
