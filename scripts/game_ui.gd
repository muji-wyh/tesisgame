extends Control

const Model = preload("res://scripts/game_model.gd")
const Data = preload("res://scripts/game_data.gd")
const SpeechWords = preload("res://scripts/speech_words.gd")
const Style = preload("res://scripts/ui_style.gd")
const Card = preload("res://scripts/word_card.gd")
const HintLink = preload("res://scripts/hint_link.gd")
const MatchConnections = preload("res://scripts/match_connections.gd")
const Audio = preload("res://scripts/game_audio.gd")
const Chest = preload("res://scripts/chest_view.gd")
const ChestFeel = preload("res://scripts/chest_feel.gd")
const TreasureBackdrop = preload("res://scripts/treasure_backdrop.gd")
const Medal = preload("res://scripts/medal_view.gd")
const MedalProgress = preload("res://scripts/medal_progress.gd")
const Mascot = preload("res://scripts/duck_mascot.gd")
const Icons = preload("res://scripts/icon_button.gd")
const MemoryGarden = preload("res://scripts/memory_garden.gd")
const PhraseGame = preload("res://scripts/phrase_game.gd")
const VoicePop = preload("res://scripts/voice_pop.gd")
const PopRewardRoom = preload("res://scripts/pop_reward_room.gd")
const ReviewScroll = preload("res://scripts/review_scroll.gd")
const ResultScroll = preload("res://scripts/result_scroll.gd")
const AgeWordCatalog = preload("res://scripts/age_word_catalog.gd")
const PlayroomState = preload("res://scripts/playroom_state.gd")
const PlayroomView = preload("res://scripts/playroom_view.gd")
const LeaderboardState = preload("res://scripts/leaderboard_state.gd")
const LeaderboardPanel = preload("res://scripts/leaderboard_panel.gd")
const GameLibrary = preload("res://scripts/game_library.gd")
const PresentationPreferences = preload("res://scripts/presentation_preferences.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const MODES := {"match": "Match", "memory": "Memory", "pop": "Voice Pop", "phrase": "Phrase Builder"}
const HOLD_SECONDS: float = ChestFeel.HOLD_SECONDS
const MATCH_FEEDBACK_SECONDS: float = 0.7
const VOICE_MATCH_SECONDS: float = 1.0

class InputActivityObserver extends Node:
	signal observed(event: InputEvent)

	func _input(event: InputEvent) -> void:
		observed.emit(event)


class ProgressBadges:
	extends Control

	const SUCCESS := 0
	const RETRY := 1

	var filled_count: int = 0
	var total_count: int = 5
	var badge_kind: int = SUCCESS

	func _init(kind: int = SUCCESS) -> void:
		badge_kind = kind
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_filled_count(value: int, total: int) -> void:
		total_count = maxi(0, total)
		filled_count = clampi(value, 0, total_count) if total_count > 0 else maxi(0, value)
		queue_redraw()

	func _draw() -> void:
		if size.y <= 0:
			return
		var scale: float = Style.ui_scale(self)
		var radius: float = 6 / scale
		var center := Vector2(7 / scale, size.y * 0.5)
		draw_circle(center, radius, Style.GOOD if badge_kind == SUCCESS else Style.WRONG)
		if badge_kind == SUCCESS:
			draw_polyline(PackedVector2Array([
				center + Vector2(-radius * 0.5, 0),
				center + Vector2(-radius * 0.1, radius * 0.4),
				center + Vector2(radius * 0.5, -radius * 0.4)
			]), Color.WHITE, 1.5 / scale, true)
		else:
			for side in [-1, 1]:
				draw_line(center + Vector2(-radius * 0.4, side * radius * 0.4), center + Vector2(radius * 0.4, -side * radius * 0.4), Color.WHITE, 1.5 / scale, true)
		var text: String = "%d/%d" % [filled_count, total_count] if total_count > 0 else str(filled_count)
		draw_string(get_theme_font("font"), Vector2(20 / scale, center.y + 5 / scale), text, HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(13 / scale), Style.INK)


class RewardSparkle:
	extends Control

	var progress: float = 0.0
	var accent: Color = Style.GOOD
	var particle_count: int = 4

	func set_progress(value: float) -> void:
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		if progress <= 0.0:
			return
		var center := size * 0.5
		var radius := minf(size.x, size.y) * lerpf(0.22, 0.45, progress)
		var alpha := 1.0 - progress
		draw_arc(center, radius, 0.0, TAU, 40, Color(accent.r, accent.g, accent.b, alpha * 0.75), 4.0, true)
		var count: int = clampi(particle_count, 1, 8)
		for index in range(count):
			var angle := TAU * float(index) / float(count) + progress * 0.18
			var point := center + Vector2(cos(angle), sin(angle)) * radius * 0.86
			var tint: Color = Color.WHITE if index % 3 == 2 else accent.lightened(0.35 if index % 3 == 1 else 0.0)
			tint.a = alpha
			var symbol_size: float = lerpf(8.0, 14.0, progress)
			_draw_symbol(point, symbol_size, progress * (0.5 if index % 2 == 0 else -0.5), tint)

	func _draw_symbol(point: Vector2, radius: float, rotation_angle: float, tint: Color) -> void:
		var stroke := Color(accent.r, accent.g, accent.b, tint.a)
		var vertices: Array[Vector2] = []
		for index in range(10):
			vertices.append(Vector2.UP.rotated(PI * float(index) / 5.0) * (1.0 if index % 2 == 0 else 0.45))
		var outline := PackedVector2Array()
		for vertex in vertices:
			outline.append(point + vertex.rotated(rotation_angle) * radius)
		draw_colored_polygon(outline, tint)
		outline.append(outline[0])
		draw_polyline(outline, stroke, 1.8, true)


var model := Model.new()
var data := Data.new()
var medal_progress := MedalProgress.new()
var duck: Mascot
var _header_duck_slot: Panel
var _header_duck_art_slot: Control
var _header: HBoxContainer
var _header_spacer: Control
var _toolbar: HBoxContainer
var _main_column: VBoxContainer
var _collection_duck_slot: Control
var _collection_margins: MarginContainer
var _world_choices: VBoxContainer
var _world_grid: HBoxContainer
var _world_scroll: ReviewScroll
var _world_save_notice: Label
var _age_choices: VBoxContainer
var _age_row: HBoxContainer
var _age_scroll: ReviewScroll
var _age_label: Label
var _age_buttons: Dictionary = {}
var _age_notice: Label
var _age_save_failed: bool = false
var _age_catalog: AgeWordCatalog
var _collection_title: Label
var _collection_header: HBoxContainer
var _collection_column: VBoxContainer
var cards: Dictionary = {}
var grid: GridContainer
var feedback_timer: Timer
var audio: Audio
var chest: Chest
var theme_buttons: Array[Button] = []
var hint_button: Icons
var _voice_button: Icons
var _voice_style_accent := Color.TRANSPARENT
var _voice_style_scale: float = -1.0
var _voice_space: Control
var _voice_mode: bool = false
var _mode_id: String = "match"
var _mode_row: GridContainer
var _mode_buttons: Array[Button] = []
var _mode_menu: Control
var _mode_panel: GameLibrary
var _mode_heading_button: Button
var _mode_heading: Label
var _mode_subheading: Label
var _presentation := PresentationPreferences.new()
var _library_published := ""
var _mode_menu_focus_modes: Dictionary = {}
var _mode_menu_resume_voice: bool = false
var _mode_menu_resume_pop: bool = false
var _mode_menu_pointer: int = -2
var _mode_menu_origin := Vector2.ZERO
var _mode_menu_dragged: bool = false
var _mode_menu_mouse_emulated: bool = false
var _memory: MemoryGarden
var _phrase: PhraseGame
var _phrase_published: String = ""
var _pop: VoicePop
var _pop_rewards: PopRewardRoom
var _pop_rewards_shown: bool = false
var pop_reward_save_path: String = "user://pop-rewards-v1.cfg"
var _controller_holding_pop_chest: bool = false
var _pop_speech_active: bool = false
var _match_playfield: Control
var _hint_link: HintLink
var _match_connections: MatchConnections
var _voice_match_link: HintLink
var _voice_match_ids: Array[String] = []
var _voice_match_left: float = 0.0
var _voice_match_serial: int = 0
var _voice_match_origin_frame: int = -1
var _voice_match_published: String = ""
var _content_margins: MarginContainer
var _new_adventure_button: Button
var _journey_save_failed: bool = false
var _pending_visit_id: String = ""
var _unlocked_gift: Dictionary = {}
var playroom_state := PlayroomState.new()
var _playroom_ready: bool = false
var _room: PlayroomView
var _voice_listening: bool = false
var _speech_queue: Array[String] = []
var collection_button: Icons
var collection_page: Panel
var collected_rewards: Dictionary = {}
var _result_retry_button: Button
var chest_button: Button
var reduced_motion: bool = false
var _page_hidden: bool = false
var _resume_music_after_background: bool = false
var _background: ColorRect
var _success: ProgressBadges
var _mistakes: ProgressBadges
var _message: Label
var _storage_retry_button: Button
var _outcome: Control
var _stage: Panel
var _treasure_backdrop: TreasureBackdrop
var _result_text: VBoxContainer
var _result_action_scale: float = -1.0
var _title: Label
var _caption: Label
var _pending_fragment: Dictionary = {}
var _progress_ready: bool = false
var _save_error: bool = false
var _collection_scroll: ScrollContainer
var _collection_grid: VBoxContainer
var _collection_back: Icons
var _collection_focus_modes: Dictionary = {}
var _focus_before_collection: Control
var _playroom_medal: Medal
var _favorite_reward_id: String = ""
var playroom_save_path: String = "user://playroom.cfg"
var _duck_trick_index: int = 0
var _last_phase: String = ""
var _rebuilding: bool = false
var _feedback_tweens: Array[Tween] = []
var _feedback_sparkles: Array[Control] = []
var _holding_chest: bool = false
var _settling_chest: bool = false
var _chest_reward_announced: bool = false
var _hold_elapsed: float = 0.0
var _hold_origin_frame: int = -1
var _chest_announced_percent: int = -1
var _chest_announced_phase: String = "idle"
var _drag_distance: float = 0.0
var _dragging_chest: bool = false
var _drag_has_anchor: bool = false
var _drag_anchor_position: Vector2 = Vector2.ZERO
var _drag_anchor_offset: Vector2 = Vector2.ZERO
var _collection_dragging: bool = false
var _collection_dragged: bool = false
var _collection_drag_pointer: int = -1
var _collection_drag_start_position: Vector2 = Vector2.ZERO
var _controller_mode: bool = false
var _pointer_focus_active: bool = false
var _proactive_touches: Dictionary = {}
var _collection_multi_touch: bool = false
var _controller_stick: Vector2 = Vector2.ZERO
var _controller_dpad: Vector2 = Vector2.ZERO
var _controller_last_direction: Vector2 = Vector2.ZERO
var _controller_repeat_elapsed: float = 0.0
var _controller_holding_chest: bool = false
var _controller_peeking: bool = false
var _controller_accept_needs_release: bool = true
var _status_announcement: String = ""
var _preferred_theme: String = ""
var _active_palette: Dictionary = {}
var _styled_mode_id: String = ""
var _host: JavaScriptObject
var _loading_finished_callback: JavaScriptObject
var _loading_revealed: bool = false
var _hidden_callback: JavaScriptObject
var _visible_callback: JavaScriptObject
var _motion_callback: JavaScriptObject
var _input_cancel_callback: JavaScriptObject
var _pointer_release_callback: JavaScriptObject
var _speech_result_callback: JavaScriptObject
var _speech_state_callback: JavaScriptObject
var _speech_debug_callback: JavaScriptObject
var _speech_debug_active: bool = false
var _speech_debug_tree_paused: bool = false
var _speech_debug_audio_process_mode: ProcessMode = Node.PROCESS_MODE_INHERIT
var _pop_result_callback: JavaScriptObject
var leaderboard_state := LeaderboardState.new()
var _leaderboard_round_id: String = ""
var _leaderboard_result: Dictionary = {}
var _leaderboard_saved_player_id: String = ""
var _leaderboard_gate: String = ""
var _return_to_pop_picker: bool = false
var _pop_player_id: String = ""
var _leaderboard_overlay: Panel
var _leaderboard_scroll: ResultScroll
var _leaderboard_margins: MarginContainer
var _leaderboard_panel: LeaderboardPanel
var _pop_leaderboard: LeaderboardPanel
var _leaderboard_close: Button
var _leaderboard_focus: Control
var _leaderboard_focus_modes: Dictionary = {}
var _leaderboard_menu: HBoxContainer
var _players_button: Button
var _leaderboards_button: Button
var _result_board_button: Button
var _leaderboard_publish_left: float = 0.0
var _leaderboard_published: String = ""


func _ready() -> void:
	get_window().title = Data.GAME_NAME
	var initial_process_mode := process_mode
	if OS.has_feature("web"):
		process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().process_frame
		await get_tree().process_frame
	theme = Theme.new()
	theme.default_font_size = 24
	theme.default_font = Style.BODY_FONT
	_build_controls()
	if OS.has_feature("web"):
		await get_tree().process_frame
	if not data.load_all():
		_show_error(data.error)
		return
	_load_collected_rewards()
	_build_collection()
	if OS.has_feature("web"):
		await get_tree().process_frame
	model.changed.connect(_refresh)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_presentation.load_preferences(DisplayServer.accessibility_should_reduce_animation() == 1)
	reduced_motion = _presentation.reduced_motion
	audio.set_muted(_presentation.muted)
	call_deferred("_sync_controller_accept_startup")
	_connect_browser()
	_pop_rewards.save_path = pop_reward_save_path
	_pop_rewards.connect_storage(_host)
	leaderboard_state.load_state()
	_load_favorite_reward()
	_refresh_favorite_reward()
	if _host != null:
		var loading_theme: Variant = _host.loadingTheme()
		if loading_theme is String and Model.THEMES.has(loading_theme):
			_preferred_theme = loading_theme
	new_round()
	if _host != null:
		get_tree().paused = true
	process_mode = initial_process_mode
	if _host != null:
		_loading_finished_callback = JavaScriptBridge.create_callback(_on_loading_finished)
		_host.ready(_loading_finished_callback)


func _on_loading_finished(args: Array) -> void:
	if _loading_revealed:
		return
	_loading_revealed = true
	if not args.is_empty() and args[0] is String and Model.THEMES.has(args[0]):
		_preferred_theme = args[0]
		model.set_theme(_preferred_theme)
		_save_journey()
	_stop_controller_actions()
	get_tree().paused = false
	_restore_mode_music()
	if not leaderboard_state.load_state() or leaderboard_state.profiles.is_empty():
		_leaderboard_gate = "onboarding"
		_show_leaderboard("onboarding", false)


func _build_controls() -> void:
	_background = ColorRect.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := MarginContainer.new()
	_content_margins = margins
	margins.minimum_size_changed.connect(_fit_content.call_deferred)
	add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 12)
	var column := VBoxContainer.new()
	_main_column = column
	column.add_theme_constant_override("separation", 8)
	margins.add_child(column)
	var header := HBoxContainer.new()
	_header = header
	header.item_rect_changed.connect(_layout_leaderboards.call_deferred)
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	_header_duck_slot = Panel.new()
	_header_duck_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_header_duck_slot)
	_header_duck_art_slot = Control.new()
	_header_duck_art_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_duck_slot.add_child(_header_duck_art_slot)
	_header_spacer = Control.new()
	_header_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_header_spacer)
	_mode_heading_button = Button.new()
	_mode_heading_button.name = "ChooseGame"
	_mode_heading_button.tooltip_text = "Choose a game, adjust sound or motion"
	_mode_heading_button.pressed.connect(_toggle_mode_menu)
	_header_spacer.add_child(_mode_heading_button)
	_header_spacer.resized.connect(_layout_game_heading)
	_mode_heading_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_heading = Style.label("Match", 22)
	_mode_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_heading_button.add_child(_mode_heading)
	_mode_subheading = Style.label("PIP AND WORDS  /  CHOOSE A GAME", 10)
	_mode_subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_subheading.add_theme_color_override("font_color", Style.MUTED)
	_mode_heading_button.add_child(_mode_subheading)
	_success = ProgressBadges.new(ProgressBadges.SUCCESS)
	_success.name = "MemoryProgress"
	_success.tooltip_text = "0 matches"
	_header_duck_slot.add_child(_success)
	_mistakes = ProgressBadges.new(ProgressBadges.RETRY)
	_mistakes.name = "MemoryMistakes"
	_mistakes.tooltip_text = "0 mistakes"
	_header_duck_slot.add_child(_mistakes)
	_toolbar = HBoxContainer.new()
	_toolbar.alignment = BoxContainer.ALIGNMENT_END
	_toolbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_toolbar)
	_voice_button = Icons.new()
	_voice_button.name = "Voice"
	_voice_button.symbol = Icons.Symbol.VOICE
	_voice_button.toggle_mode = true
	UiClick.bind_button(_voice_button)
	_voice_button.pressed.connect(_toggle_voice)
	_toolbar.add_child(_voice_button)
	hint_button = Icons.new()
	hint_button.name = "Hint"
	hint_button.symbol = Icons.Symbol.HINT
	hint_button.tooltip_text = "Three hints per round (Xbox X)"
	_set_accessibility_name(hint_button, "Hint: three per round")
	hint_button.pressed.connect(_request_hint)
	_toolbar.add_child(hint_button)
	collection_button = Icons.new()
	collection_button.name = "Rewards"
	collection_button.symbol = Icons.Symbol.MORE
	collection_button.tooltip_text = "More: Pip's room, players and leaderboards"
	_set_accessibility_name(collection_button, collection_button.tooltip_text)
	UiClick.bind_button(collection_button)
	collection_button.pressed.connect(_show_collection)
	_toolbar.add_child(collection_button)
	_build_mode_menu()
	_voice_space = Control.new()
	_voice_space.name = "SpeechPanelSpace"
	_voice_space.custom_minimum_size = Vector2(0, 112)
	_voice_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voice_space.item_rect_changed.connect(_sync_voice_bounds)
	_voice_space.hide()
	column.add_child(_voice_space)
	_match_playfield = Control.new()
	_match_playfield.name = "MatchPlayfield"
	_match_playfield.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_match_playfield.resized.connect(_fit_grid)
	column.add_child(_match_playfield)
	_match_connections = MatchConnections.new()
	_match_connections.name = "MatchConnections"
	_match_playfield.add_child(_match_connections)
	_match_connections.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_match_connections.hide()
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_match_playfield.add_child(grid)
	_hint_link = HintLink.new()
	_hint_link.name = "HintLink"
	_hint_link.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_match_playfield.add_child(_hint_link)
	_hint_link.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint_link.hide()
	grid.sort_children.connect(func() -> void: _refresh_hint_link.call_deferred())
	grid.visibility_changed.connect(_refresh_hint_link)
	grid.sort_children.connect(func() -> void: _refresh_match_connections.call_deferred())
	_voice_match_link = HintLink.new()
	_voice_match_link.name = "VoiceMatchLink"
	_match_playfield.add_child(_voice_match_link)
	_voice_match_link.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_voice_match_link.hide()
	grid.sort_children.connect(func() -> void: _refresh_voice_match_link.call_deferred())
	grid.visibility_changed.connect(_refresh_voice_match_link)
	_memory = MemoryGarden.new()
	_memory.name = "MemoryGarden"
	_memory.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_memory.card_revealed.connect(_memory_revealed)
	_memory.answer_chosen.connect(_memory_answer)
	_memory.progress_changed.connect(_memory_progress)
	_memory.round_finished.connect(_memory_finished)
	_memory.prompt_ready.connect(_memory_prompt)
	_memory.hide()
	column.add_child(_memory)
	_memory.study_button.reparent(_toolbar)
	_toolbar.move_child(_memory.study_button, 0)
	_phrase = PhraseGame.new()
	_phrase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_phrase.interaction_allowed = _phrase_interaction_allowed
	_phrase.completion_audio_playing = func() -> bool: return audio.voice.playing
	_phrase.finished.connect(_phrase_finished)
	_phrase.status_changed.connect(_phrase_status_changed)
	_phrase.audio_requested.connect(_phrase_audio_requested)
	_phrase.changed.connect(_publish_phrase)
	_phrase.hide()
	column.add_child(_phrase)
	_pop = VoicePop.new()
	_pop.name = "VoicePop"
	_pop.interaction_allowed = func() -> bool: return not collection_page.visible and not _leaderboard_overlay.visible and not _page_hidden and not _mode_menu_open()
	_pop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pop.request_listening.connect(_start_pop_listening)
	_pop.exit_requested.connect(func() -> void: choose_mode("match"))
	_pop.hit.connect(_pop_hit)
	_pop.launched.connect(_pop_launched)
	_pop.missed.connect(_pop_missed)
	_pop.round_finished.connect(_pop_finished)
	_pop.chests_requested.connect(_show_pop_rewards)
	_pop.chest_earned.connect(_pop_chest_earned)
	_pop.hear_requested.connect(_pop_hear)
	_pop.status_changed.connect(_pop_status_changed)
	_pop.hide()
	column.add_child(_pop)
	_pop_rewards = PopRewardRoom.new()
	_pop_rewards.name = "PopRewardRoom"
	_pop_rewards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pop_rewards.interaction_allowed = func() -> bool: return _pop_rewards_shown and _mode_id == "pop" and not collection_page.visible and not _leaderboard_overlay.visible and not _page_hidden and not _mode_menu_open()
	_pop_rewards.exit_requested.connect(_hide_pop_rewards)
	_pop_rewards.chest_audio_requested.connect(_pop_chest_audio)
	_pop_rewards.chest_cue_requested.connect(func(theme_id: String, cue: String, step: int) -> void:
		if not _pop_rewards_shown or _page_hidden or collection_page.visible or _leaderboard_overlay.visible or _mode_id != "pop":
			return
		audio.chest_cue(theme_id, cue, step)
		if _host != null:
			_host.chestCue(theme_id, cue, step))
	_pop_rewards.changed.connect(_publish_pop_rewards)
	_pop_rewards.hide()
	column.add_child(_pop_rewards)
	_outcome = Control.new()
	_outcome.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outcome.resized.connect(_layout_result)
	column.add_child(_outcome)
	_stage = Panel.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = true
	_stage.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_outcome.add_child(_stage)
	_treasure_backdrop = TreasureBackdrop.new()
	_stage.add_child(_treasure_backdrop)
	_treasure_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chest = Chest.new()
	_stage.add_child(chest)
	chest.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chest.opened.connect(_on_chest_opened)
	chest.release_reached.connect(_on_chest_released)
	chest.cue_requested.connect(_on_chest_cue)
	chest_button = Button.new()
	chest_button.text = ""
	chest_button.tooltip_text = "Open the treasure chest"
	_set_accessibility_name(chest_button, "Open the treasure chest")
	chest_button.focus_mode = Control.FOCUS_ALL
	chest_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		chest_button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	chest_button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Color.WHITE, 24, 4))
	_stage.add_child(chest_button)
	chest_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chest_button.button_down.connect(_start_chest_hold)
	chest_button.button_up.connect(_end_chest_hold)
	chest_button.gui_input.connect(_chest_input)
	_result_text = VBoxContainer.new()
	_result_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_text.add_theme_constant_override("separation", 10)
	_outcome.add_child(_result_text)
	_result_text.minimum_size_changed.connect(_layout_result)
	_title = Style.label("You did it!", 34)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_text.add_child(_title)
	_caption = Style.label("Hold to open your chest!", 22)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_text.add_child(_caption)
	_result_retry_button = Button.new()
	_result_retry_button.name = "RetryRewardSave"
	_result_retry_button.text = "Retry saving"
	_result_retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiClick.bind_button(_result_retry_button)
	_result_retry_button.pressed.connect(_retry_reward_save)
	_result_retry_button.hide()
	_outcome.add_child(_result_retry_button)
	_new_adventure_button = Button.new()
	_new_adventure_button.name = "NewAdventure"
	_new_adventure_button.text = "New adventure"
	_new_adventure_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiClick.bind_button(_new_adventure_button)
	_new_adventure_button.pressed.connect(_new_adventure)
	_new_adventure_button.hide()
	_outcome.add_child(_new_adventure_button)
	_result_board_button = Button.new()
	_result_board_button.name = "ResultLeaderboard"
	_result_board_button.text = "Leaderboard"
	_result_board_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_result_board_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiClick.bind_button(_result_board_button)
	_result_board_button.pressed.connect(_show_result_leaderboard)
	_toolbar.add_child(_result_board_button)
	_toolbar.move_child(_result_board_button, collection_button.get_index())
	_message = Style.label("", 16)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.hide()
	_match_playfield.add_child(_message)
	_storage_retry_button = Button.new()
	_storage_retry_button.name = "RetryRewards"
	_storage_retry_button.text = "Retry rewards"
	_storage_retry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiClick.bind_button(_storage_retry_button)
	_storage_retry_button.pressed.connect(_retry_storage)
	_storage_retry_button.hide()
	header.add_child(_storage_retry_button)
	header.move_child(_storage_retry_button, 0)
	_build_collection_shell()
	_build_leaderboard_overlay()
	audio = Audio.new()
	add_child(audio)
	audio.status_changed.connect(_audio_status)
	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.wait_time = MATCH_FEEDBACK_SECONDS
	feedback_timer.timeout.connect(_resolve_feedback)
	add_child(feedback_timer)
	duck = Mascot.new()
	duck.z_index = 80
	duck.pressed.connect(_play_duck)
	duck.gui_input.connect(_collection_scroll_input.bind(duck))
	duck.focus_entered.connect(func() -> void:
		if collection_page.visible:
			_ensure_collection_focus_visible(duck))
	duck.hide()
	add_child(duck)
	_set_accessibility_name(duck, "Pip the duck. Press to say hello.")
	_outcome.hide()
	# Input is dispatched child-first; observe it before interactive descendants consume it.
	var observer := InputActivityObserver.new()
	observer.name = "InputActivity"
	observer.observed.connect(_observe_activity)
	add_child(observer)


func _build_mode_menu() -> void:
	_mode_menu = Control.new()
	_mode_menu.name = "GameModeMenu"
	# The library also covers Pip when compact layouts reach the header.
	_mode_menu.z_index = 100
	_mode_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_mode_menu.gui_input.connect(_mode_menu_input)
	add_child(_mode_menu)
	_mode_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_menu.hide()
	var shade := ColorRect.new()
	shade.color = Color(Style.INK, 0.32)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_panel = GameLibrary.new()
	_mode_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_mode_menu.add_child(_mode_panel)
	_mode_row = _mode_panel.grid
	_mode_buttons = _mode_panel.buttons
	_mode_panel.mode_requested.connect(_choose_mode_from_menu)
	_mode_panel.dismissed.connect(_hide_mode_menu)
	_mode_panel.sound_toggled.connect(_toggle_library_sound)
	_mode_panel.motion_toggled.connect(_toggle_library_motion)


func _toggle_library_sound() -> void:
	if not _mode_menu_open():
		return
	audio.set_muted(not audio.muted)
	_phrase.set_muted(audio.muted or not audio.available)
	_play_ui_click()
	_presentation.muted = audio.muted
	_save_presentation()


func _toggle_library_motion() -> void:
	if not _mode_menu_open():
		return
	set_reduced_motion(not reduced_motion)
	_presentation.reduced_motion = reduced_motion
	_presentation.has_motion_override = true
	_save_presentation()


func _save_presentation() -> void:
	_mode_panel.configure(_mode_id, audio.muted, reduced_motion)
	if _host != null:
		_host.presentationSettings(reduced_motion, audio.muted)
	var saved: bool = _presentation.save_preferences()
	_announce_status(("Sound off. " if audio.muted else "Sound on. ") + ("Reduced motion." if reduced_motion else "Full motion.") + ("" if saved else " Preferences could not be saved on this device. Your choices work for this visit."))


func _mode_menu_open() -> bool:
	return is_instance_valid(_mode_menu) and _mode_menu.visible


func _toggle_mode_menu() -> void:
	var was_open: bool = _mode_menu_open()
	if _mode_menu_open():
		_hide_mode_menu()
	else:
		_show_mode_menu()
	if was_open != _mode_menu_open():
		_play_ui_click()


func _play_ui_click(source: Control = null) -> void:
	if _page_hidden or _speech_debug_active or not is_instance_valid(audio):
		return
	if source != null and (not _valid_focus(source) or source.is_queued_for_deletion()):
		return
	if source != null and collection_page.is_ancestor_of(source) \
		and (_collection_dragged or _collection_multi_touch):
		return
	audio.play_ui_click()


func _show_mode_menu() -> void:
	if _mode_menu_open() or _page_hidden or collection_page.visible or (_leaderboard_overlay.visible and not _pop_picker_open()) \
		or not model.phase in ["waiting", "matching", "feedback"] or model.chest_state == "opening" \
		or (_save_error and not _pending_fragment.is_empty()):
		return
	_mode_menu_resume_voice = _voice_mode
	if _mode_menu_resume_voice and _host != null and not bool(_host.suspendSpeechForMenu()):
		_mode_menu_resume_voice = false
		return
	# Speech ownership can outlive a denied/failed microphone. Resume only a
	# recognizer that was listening or connecting when the menu interrupted it.
	_mode_menu_resume_pop = _mode_id == "pop" and (_pop._listening or _pop._pending or _pop._reconnecting)
	_mode_menu.show()
	_on_input_canceled()
	_stop_controller_actions()
	if _mode_menu_resume_voice:
		# Keep the reserved voice-panel bounds while the host hides its overlay.
		_voice_listening = false
		_voice_button.engaged = false
		_speech_queue.clear()
		_clear_voice_match_feedback()
	else:
		_stop_voice()
	if _mode_id == "pop":
		if _pop.game.phase in ["running", "finished"] or _mode_menu_resume_pop:
			_pop.pause()
		_pop_rewards.pause()
		_stop_pop_listening()
		audio.stop_pop_sounds()
	feedback_timer.paused = true
	_memory.pause(true)
	_pause_phrase()
	_hint_link.set_paused(true)
	audio.stop_voice()
	audio.stop_pip_reaction()
	duck.settle()
	_mode_menu_focus_modes.clear()
	for node in find_children("*", "Control", true, false):
		var control := node as Control
		if not _mode_menu.is_ancestor_of(control):
			_mode_menu_focus_modes[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
	_fit_mode_buttons()
	_update_duck()
	_default_focus().grab_focus()
	_announce_status("Game mode. %s is selected. Choose a game, or press Back to return." % MODES[_mode_id])


func _hide_mode_menu(restore_focus: bool = true, resume_game: bool = true) -> void:
	if not _mode_menu_open():
		return
	_mode_menu_pointer = -2
	_mode_menu.hide()
	for control in _mode_menu_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = _mode_menu_focus_modes[control]
	_mode_menu_focus_modes.clear()
	_publish_library.call_deferred()
	var resume_voice: bool = _mode_menu_resume_voice
	var resume_pop: bool = _mode_menu_resume_pop
	_mode_menu_resume_voice = false
	_mode_menu_resume_pop = false
	if resume_game and not _page_hidden and not collection_page.visible and not _leaderboard_overlay.visible:
		feedback_timer.paused = false
		_memory.pause(false)
		_resume_phrase()
		_refresh_hint_link()
		if resume_voice:
			if _host != null:
				_host.resumeSpeechFromMenu()
		if resume_pop:
			_start_pop_listening()
		if _pop_rewards_shown and _mode_id == "pop":
			_pop_rewards.resume()
	elif resume_voice:
		_stop_voice()
	_update_duck()
	if resume_game and not audio.muted and not audio.active:
		_restore_mode_music()
	if restore_focus and _valid_focus(duck):
		duck.grab_focus()
	if restore_focus:
		_announce_status("%s. Game mode menu closed." % MODES[_mode_id])


func _choose_mode_from_menu(id: String) -> void:
	if not _mode_menu_open() or not MODES.has(id):
		return
	if id == _mode_id:
		_hide_mode_menu()
		return
	_hide_mode_menu(false, false)
	choose_mode(id)


func _mode_menu_input(event: InputEvent) -> void:
	# A backdrop tap is an action; drags, canceled presses, and synthesized
	# duplicate mouse releases must not dismiss the menu or play another cue.
	if event is InputEventMouseMotion and _mode_menu_pointer == -1:
		_mode_menu_dragged = _mode_menu_dragged or event.position.distance_to(_mode_menu_origin) * Style.ui_scale(self) > 8
		return
	if event is InputEventScreenDrag and event.index == _mode_menu_pointer:
		_mode_menu_dragged = _mode_menu_dragged or event.position.distance_to(_mode_menu_origin) * Style.ui_scale(self) > 8
		return
	if not event is InputEventScreenTouch and not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pointer: int = event.index if event is InputEventScreenTouch else -1
	if event.pressed:
		if _mode_menu_pointer == -2:
			_mode_menu_pointer = pointer
			_mode_menu_origin = event.position
			_mode_menu_dragged = false
			_mode_menu_mouse_emulated = event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION
		elif _mode_menu_pointer == -1 and _mode_menu_mouse_emulated and pointer >= 0 \
			and event.position.distance_to(_mode_menu_origin) * Style.ui_scale(self) <= 8:
			# Some browsers deliver the emulated mouse press before its touch.
			# Transfer ownership to that touch, retaining its release blocker.
			_mode_menu_pointer = pointer
		elif pointer != -1:
			_mode_menu_dragged = true
		return
	if pointer != _mode_menu_pointer:
		return
	var tapped: bool = not event.canceled and not _mode_menu_dragged \
		and event.position.distance_to(_mode_menu_origin) * Style.ui_scale(self) <= 8
	_mode_menu_pointer = -2
	_mode_menu.accept_event()
	if tapped:
		_mode_panel.close_button.pressed.emit()


func _build_collection_shell() -> void:
	collection_page = Panel.new()
	collection_page.name = "Collection"
	collection_page.z_index = 50
	add_child(collection_page)
	collection_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := MarginContainer.new()
	_collection_margins = margins
	collection_page.add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 16)
	var column := VBoxContainer.new()
	_collection_column = column
	margins.add_child(column)
	var header := HBoxContainer.new()
	_collection_header = header
	column.add_child(header)
	_collection_duck_slot = Control.new()
	_collection_duck_slot.custom_minimum_size = Vector2(160, 160)
	_collection_duck_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collection_title = Style.label("Pip", 18)
	_collection_title.name = "PipsRoomTitle"
	_collection_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_collection_title)
	_build_age_choices()
	_collection_back = Icons.new()
	_collection_back.symbol = Icons.Symbol.BACK
	_collection_back.tooltip_text = "Back to game"
	_set_accessibility_name(_collection_back, "Back to game")
	UiClick.bind_button(_collection_back)
	_collection_back.pressed.connect(_back_from_collection)
	header.add_child(_collection_back)
	_leaderboard_menu = HBoxContainer.new()
	_leaderboard_menu.name = "PlayerMenu"
	column.add_child(_leaderboard_menu)
	_players_button = Button.new()
	_players_button.name = "MenuPlayers"
	_players_button.text = "Players"
	_players_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiClick.bind_button(_players_button)
	_players_button.pressed.connect(_show_leaderboard.bind("players", false))
	_leaderboard_menu.add_child(_players_button)
	_leaderboards_button = Button.new()
	_leaderboards_button.name = "MenuLeaderboards"
	_leaderboards_button.text = "Leaderboards"
	_leaderboards_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiClick.bind_button(_leaderboards_button)
	_leaderboards_button.pressed.connect(_show_leaderboard.bind("boards", false))
	_leaderboard_menu.add_child(_leaderboards_button)
	_collection_scroll = ScrollContainer.new()
	_collection_scroll.name = "PlaygroundViewport"
	_collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection_scroll.gui_input.connect(_collection_scroll_input.bind(_collection_scroll))
	column.add_child(_collection_scroll)
	_collection_grid = VBoxContainer.new()
	_collection_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_collection_scroll.add_child(_collection_grid)
	_age_catalog = AgeWordCatalog.new()
	_age_catalog.name = "AgeWordCatalog"
	_age_catalog.interaction_allowed = _can_browse_collection
	_age_catalog.hear_requested.connect(_hear_catalog_word)
	column.add_child(_age_catalog)
	_age_catalog.hide()
	collection_page.hide()


func _build_leaderboard_overlay() -> void:
	_leaderboard_overlay = Panel.new()
	_leaderboard_overlay.name = "LeaderboardOverlay"
	# Pip inherits the room's layer as well as its own elevated draw order.
	_leaderboard_overlay.z_index = 200
	_leaderboard_overlay.add_theme_stylebox_override("panel", Style.box(Style.PAPER, Color.TRANSPARENT, 0, 0))
	add_child(_leaderboard_overlay)
	# GUI hit testing follows sibling order, independently of the draw layer.
	move_child(_mode_menu, _leaderboard_overlay.get_index())
	_leaderboard_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_leaderboard_margins = MarginContainer.new()
	_leaderboard_overlay.add_child(_leaderboard_margins)
	_leaderboard_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	_leaderboard_margins.add_child(column)
	_leaderboard_close = Button.new()
	_leaderboard_close.name = "LeaderboardClose"
	_leaderboard_close.text = "Back"
	_leaderboard_close.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiClick.bind_button(_leaderboard_close)
	_leaderboard_close.pressed.connect(_back_from_leaderboard)
	column.add_child(_leaderboard_close)
	_leaderboard_scroll = ResultScroll.new()
	_leaderboard_scroll.name = "LeaderboardScroll"
	_leaderboard_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_leaderboard_scroll.follow_focus = true
	_leaderboard_scroll.interaction_allowed = func() -> bool: return not _page_hidden and not _mode_menu_open()
	column.add_child(_leaderboard_scroll)
	_leaderboard_panel = LeaderboardPanel.new()
	_leaderboard_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leaderboard_scroll.add_child(_leaderboard_panel)
	_leaderboard_panel.changed.connect(_publish_leaderboards)
	_leaderboard_panel.score_saved.connect(_leaderboard_score_saved)
	_leaderboard_panel.player_confirmed.connect(_leaderboard_player_confirmed)
	_leaderboard_panel.profile_updated.connect(_leaderboard_profile_updated)
	_leaderboard_panel.profile_removed.connect(_leaderboard_profile_removed)
	resized.connect(_layout_leaderboards)
	_layout_leaderboards()
	_leaderboard_overlay.hide()


func _pop_picker_open() -> bool:
	return _mode_id == "pop" and _leaderboard_gate == "pop" \
		and is_instance_valid(_leaderboard_overlay) and _leaderboard_overlay.visible


func _layout_leaderboards() -> void:
	if not is_instance_valid(_leaderboard_margins):
		return
	var scale: float = Style.ui_scale(self)
	var picker: bool = _pop_picker_open()
	_leaderboard_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_leaderboard_overlay.z_index = 60 if picker else 200
	if picker:
		var header_end: Vector2 = get_global_transform().affine_inverse() * _header.get_global_rect().end
		_leaderboard_overlay.offset_top = header_end.y + ceilf(8 / scale)
	_leaderboard_close.visible = _leaderboard_gate != "onboarding" and not picker
	for edge in ["left", "right"]:
		_leaderboard_margins.add_theme_constant_override("margin_" + edge, maxi(ceili(12 / scale), roundi((size.x - 720 / scale) * 0.5)))
	for edge in ["top", "bottom"]:
		_leaderboard_margins.add_theme_constant_override("margin_" + edge, ceili(12 / scale))
	Style.action_button(_leaderboard_close, Style.GOOD)


func _show_result_leaderboard() -> void:
	if not _leaderboard_result.is_empty() and model.chest_state != "opening":
		_show_leaderboard("boards", true)


func _show_leaderboard(view: String, include_round: bool) -> void:
	if _leaderboard_overlay.visible:
		return
	_hide_mode_menu(false, false)
	_pop_rewards.pause()
	_pop.cancel_result_input()
	_cancel_chest_hold()
	_finish_chest_drag()
	audio.stop_voice()
	audio.stop_pair_feedback()
	audio.stop_pip_reaction()
	duck.settle()
	_leaderboard_focus = get_viewport().gui_get_focus_owner()
	_leaderboard_focus_modes.clear()
	for node in find_children("*", "Control", true, false):
		if view == "picker" and _leaderboard_gate == "pop" \
			and (node in [duck, collection_button, _mode_heading_button] or _mode_menu.is_ancestor_of(node)):
			continue
		if not _leaderboard_overlay.is_ancestor_of(node):
			_leaderboard_focus_modes[node] = node.focus_mode
			node.focus_mode = Control.FOCUS_NONE
	leaderboard_state.load_state()
	_reconcile_round_identity()
	include_round = include_round and not _leaderboard_result.is_empty()
	_leaderboard_overlay.show()
	_pause_phrase()
	_publish_pop_rewards(_pop_rewards.snapshot())
	_leaderboard_close.visible = _leaderboard_gate != "onboarding"
	_leaderboard_close.focus_mode = Control.FOCUS_ALL
	_cancel_collection_rails()
	if collection_page.visible:
		_room.settle()
	_update_duck()
	_leaderboard_panel.configure(leaderboard_state, view, _mode_id, _leaderboard_round_id if include_round else "", _leaderboard_result if include_round else {}, reduced_motion)
	_leaderboard_scroll.cancel_drag()
	_leaderboard_scroll.scroll_vertical = 0
	_layout_leaderboards()
	_default_focus().grab_focus()
	var announcement: String = "Players on this device." if view == "players" else "Local leaderboards. Personal bests; tied scores share a rank."
	if view == "onboarding":
		announcement = "Welcome! Create your first player to start playing. Choose an avatar and a name."
	elif view == "picker":
		announcement = "Who is playing Voice Pop? Tap your avatar to start."
	_announce_status(announcement)
	_publish_leaderboards()


func _back_from_leaderboard(play_click: bool = false) -> void:
	if _leaderboard_panel.cancel_management():
		if play_click:
			_play_ui_click()
	elif _leaderboard_gate != "onboarding" and _leaderboard_overlay.visible:
		if play_click:
			_play_ui_click()
		_hide_leaderboard()


func _hide_leaderboard() -> void:
	if _leaderboard_gate == "onboarding":
		return
	_hide_mode_menu(false, false)
	_leaderboard_gate = ""
	_leaderboard_panel.settle_animation()
	_leaderboard_overlay.hide()
	for control in _leaderboard_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = _leaderboard_focus_modes[control]
	_leaderboard_focus_modes.clear()
	_resume_phrase()
	if _pop_rewards_shown and _mode_id == "pop" and not collection_page.visible and not _page_hidden:
		_pop_rewards.resume()
	if _valid_focus(_leaderboard_focus):
		_leaderboard_focus.grab_focus()
	else:
		_default_focus().grab_focus()
	if collection_page.visible:
		_announce_collection_state()
	else:
		_announce_status(_message.text if model.phase in ["waiting", "matching", "feedback"] else _title.text + " " + _caption.text)
	_publish_leaderboards()
	_update_duck()


func _request_pop_player() -> void:
	if _mode_id != "pop" or collection_page.visible or _leaderboard_overlay.visible or _page_hidden:
		return
	if _pop_rewards.has_pending():
		_show_pop_rewards()
		_announce_status("Open your earned chests before starting another Voice Pop round.")
		return
	if not _stop_pop_listening():
		return
	_leaderboard_gate = "pop"
	_show_leaderboard("picker", false)


func _leaderboard_player_confirmed(player_id: String) -> void:
	if not _leaderboard_overlay.visible or _leaderboard_gate.is_empty() or _mode_menu_open() or _page_hidden:
		return
	if not leaderboard_state.ready or not leaderboard_state.profiles.any(func(profile: Dictionary) -> bool: return str(profile.id) == player_id):
		_leaderboard_panel.refresh_profiles()
		return
	var gate: String = _leaderboard_gate
	_leaderboard_gate = ""
	_hide_leaderboard()
	if gate == "pop" and _mode_id == "pop":
		# Keep the completed result intact until the next player confirms.
		if _pop.game.phase == "finished":
			_configure_pop()
		_pop_player_id = player_id
		for profile in leaderboard_state.profiles:
			if str(profile.id) == player_id:
				_pop.set_round_player(profile)
				break
		_start_pop_listening()
	else:
		_restore_mode_music()


func _leaderboard_score_saved(outcome: Dictionary) -> void:
	_leaderboard_saved_player_id = str(outcome.get("player_id", ""))
	if not _page_hidden and not bool(outcome.get("duplicate", false)):
		audio.interact(model.theme_id, false)
		audio.cue("correct")
	var message: String = "Score saved. Rank %d." % int(outcome.get("new_rank", 0))
	if bool(outcome.get("improved", false)):
		message = "Rank up! From %d to %d. Score saved." % [int(outcome.get("old_rank", 0)), int(outcome.get("new_rank", 0))]
	_announce_status(message)
	_publish_leaderboards()


func _leaderboard_profile_updated(profile: Dictionary) -> void:
	if str(profile.get("id", "")) == _pop_player_id:
		_pop.set_round_player(profile)
	if is_instance_valid(_pop_leaderboard):
		_pop_leaderboard.refresh_profiles()
	_announce_status("Player updated. Your personal bests are unchanged.")
	_publish_leaderboards()


func _reconcile_round_identity() -> void:
	if not leaderboard_state.ready:
		return
	if not _leaderboard_saved_player_id.is_empty() and not leaderboard_state.profiles.any(func(profile: Dictionary) -> bool: return str(profile.id) == _leaderboard_saved_player_id):
		_leaderboard_result.clear()
		_leaderboard_saved_player_id = ""
		_result_board_button.hide()
	if _pop_player_id.is_empty():
		return
	for profile in leaderboard_state.profiles:
		if str(profile.id) == _pop_player_id:
			_pop.set_round_player(profile)
			return
	_discard_removed_pop_round()


func _discard_removed_pop_round() -> void:
	if not _stop_pop_listening():
		_announce_status("Microphone could not be stopped. Close this tab to stop voice input.")
	audio.stop_pop_sounds()
	_configure_pop()


func _leaderboard_profile_removed(player_id: String) -> void:
	if player_id == _pop_player_id:
		_discard_removed_pop_round()
	elif player_id == _leaderboard_saved_player_id:
		# The receipt was deleted with its owner. Do not offer this old result
		# to another player when its leaderboard is opened again.
		_leaderboard_result.clear()
		_leaderboard_saved_player_id = ""
		_result_board_button.hide()
	if is_instance_valid(_pop_leaderboard):
		_pop_leaderboard.refresh_profiles()
	if leaderboard_state.profiles.is_empty():
		_leaderboard_gate = "onboarding"
		_leaderboard_close.hide()
		_leaderboard_panel.configure(leaderboard_state, "onboarding", _mode_id, "", {}, reduced_motion)
		_leaderboard_scroll.cancel_drag()
		_leaderboard_scroll.scroll_vertical = 0
		_layout_leaderboards()
		var focus: Control = _leaderboard_panel.default_focus()
		if is_instance_valid(focus):
			focus.grab_focus()
		_announce_status("Player removed. Create a new player to continue. Shared game progress and treasures are safe.")
	else:
		_announce_status("Player and their leaderboard scores removed. Shared game progress and treasures are safe.")
	_publish_leaderboards()


func leaderboard_snapshot() -> Dictionary:
	var panel = _leaderboard_panel if _leaderboard_overlay.visible else _pop_leaderboard
	var active: bool = is_instance_valid(panel) and panel.is_inside_tree() and panel.is_visible_in_tree() and not collection_page.visible
	if _leaderboard_overlay.visible:
		active = true
	var result: Dictionary = panel.snapshot() if active else {}
	result["visible"] = active
	result["modal"] = _leaderboard_overlay.visible
	result["gate"] = _leaderboard_gate
	result["round_player_id"] = _pop_player_id
	var controls: Array = result.get("controls", []).duplicate()
	var candidates: Array = [_leaderboard_close] if _leaderboard_overlay.visible else [_players_button, _leaderboards_button, _result_board_button]
	for control in candidates:
		if is_instance_valid(control) and control.is_visible_in_tree():
			var rect: Rect2 = control.get_global_rect()
			controls.append({"name": str(control.name), "text": control.text, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "disabled": control.disabled, "focused": control.has_focus()})
	result["controls"] = controls
	return result


func _publish_leaderboards() -> void:
	if _host == null or not is_instance_valid(_leaderboard_overlay):
		return
	var value: String = JSON.stringify(leaderboard_snapshot())
	if value != _leaderboard_published:
		_leaderboard_published = value
		_host.leaderboardStatus(value)


func _build_age_choices() -> void:
	_age_choices = VBoxContainer.new()
	_age_choices.name = "AgeChoices"
	_age_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_header.add_child(_age_choices)
	_age_scroll = ReviewScroll.new()
	_age_scroll.name = "AgeScroll"
	_age_scroll.interaction_allowed = _can_browse_collection
	_age_choices.add_child(_age_scroll)
	_age_row = HBoxContainer.new()
	_age_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_age_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_age_scroll.add_child(_age_row)
	_age_label = Style.label("Age", 14)
	_age_label.tooltip_text = "A vocabulary guide. Choose the level that feels right."
	_age_row.add_child(_age_label)
	for band in Data.age_bands():
		var button := Button.new()
		button.name = "Age_" + band.id.replace("-", "_")
		button.text = band.label
		button.toggle_mode = true
		button.tooltip_text = band.name + ": view words"
		_set_accessibility_name(button, band.name + ". View this word list and choose vocabulary for your next lesson.")
		UiClick.bind_button(button)
		button.pressed.connect(_choose_age_band.bind(band.id))
		button.focus_entered.connect(_ensure_collection_focus_visible.bind(button))
		_age_row.add_child(button)
		_age_buttons[band.id] = button
	_age_notice = Style.label("", 13)
	_age_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_age_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_age_notice.add_theme_color_override("font_color", Style.WRONG.darkened(0.15))
	_age_notice.hide()
	_age_choices.add_child(_age_notice)


func _choose_age_band(id: String) -> void:
	if not _can_browse_collection() or _collection_dragged or Data.age_band(id).is_empty():
		_refresh_age_choices()
		return
	_age_save_failed = not _ensure_playroom_loaded() or not playroom_state.set_age_band(id)
	_refresh_age_choices()
	if _age_save_failed:
		_announce_status(_age_notice.text)
		return
	_show_age_catalog()


func _can_browse_collection() -> bool:
	return collection_page.visible and not _leaderboard_overlay.visible and not _page_hidden \
		and not _speech_debug_active and not _collection_multi_touch


func _can_use_room() -> bool:
	return _can_browse_collection() and not _age_catalog.visible and not _collection_dragged


func _show_age_catalog() -> void:
	if not _can_browse_collection():
		return
	audio.stop_voice()
	audio.stop_pip_reaction()
	_cancel_collection_rails()
	_room.settle()
	duck.settle()
	var band: Dictionary = Data.age_band(playroom_state.age_band_id)
	# Catalogue ranges are distinct; lesson selection can still review earlier levels.
	var words: Array = data.words.filter(func(word: Dictionary) -> bool:
		return band.id == "all" or Data.word_level(word) == int(band.max_level))
	_age_buttons[band.id].grab_focus()
	_age_catalog.configure(words, band, Data.theme(model.theme_id))
	_age_catalog.show()
	_sync_collection_content()
	_update_duck()
	_announce_collection_state()


func _hide_age_catalog() -> void:
	audio.stop_voice()
	_age_catalog.cancel_input()
	_age_catalog.hide()
	_sync_collection_content()
	_update_duck()


func _sync_collection_content() -> void:
	var browsing: bool = _age_catalog.visible
	_collection_title.visible = not browsing
	_collection_scroll.visible = not browsing
	_leaderboard_menu.visible = not browsing
	if is_instance_valid(_world_choices):
		_world_choices.visible = not browsing
	if is_instance_valid(_room):
		_room.toy_shelf.visible = not browsing
		_room.playground.pause(browsing or _page_hidden)
	_collection_back.tooltip_text = "Back to Pip's room" if browsing else "Back to game"
	_set_accessibility_name(_collection_back, _collection_back.tooltip_text)


func _hear_catalog_word(word: Dictionary) -> void:
	if not _can_browse_collection() or not _age_catalog.visible or _age_catalog.scroll.is_scrolling():
		return
	audio.interact(model.theme_id)
	audio.say("res://" + str(word.audio))
	_announce_status(str(word.text) + (". " + str(word.meaning) if word.has("meaning") else ""))


func _back_from_collection() -> void:
	if not _can_browse_collection():
		return
	if _age_catalog.visible:
		_hide_age_catalog()
		_age_buttons[playroom_state.age_band_id].grab_focus()
		_announce_collection_state()
	else:
		_hide_collection()


func _refresh_age_choices() -> void:
	for id in _age_buttons:
		_age_buttons[id].set_pressed_no_signal(id == playroom_state.age_band_id)
	var notice_changed: bool = _age_notice.visible != _age_save_failed
	_age_notice.text = "Not saved. Tap an age to retry." if _age_save_failed else ""
	_age_notice.tooltip_text = playroom_state.error if _age_save_failed else ""
	_age_notice.visible = _age_save_failed
	if notice_changed:
		_layout_collection.call_deferred()


func _build_collection() -> void:
	if duck != null and duck.get_parent() != self:
		duck.reparent(self)
	if is_instance_valid(_room) and is_instance_valid(_room.toy_shelf):
		_room.toy_shelf.get_parent().remove_child(_room.toy_shelf)
		_room.toy_shelf.queue_free()
	if is_instance_valid(_world_choices):
		_world_choices.get_parent().remove_child(_world_choices)
		_world_choices.queue_free()
		_world_choices = null
		_world_grid = null
	if _collection_duck_slot.get_parent() != null:
		_collection_duck_slot.get_parent().remove_child(_collection_duck_slot)
	for child in _collection_grid.get_children():
		_collection_grid.remove_child(child)
		child.queue_free()
	_build_playroom()
	_build_world_choices()
	_collection_column.move_child(_room.toy_shelf, -1)
	_refresh_collection()
	_layout_collection()


func _build_world_choices() -> void:
	theme_buttons.clear()
	_active_palette.clear()
	_world_choices = VBoxContainer.new()
	_world_choices.name = "WorldChoices"
	_collection_column.add_child(_world_choices)
	_world_scroll = ReviewScroll.new()
	_world_scroll.name = "WorldScroll"
	_world_scroll.interaction_allowed = _can_use_room
	_world_choices.add_child(_world_scroll)
	var worlds := HBoxContainer.new()
	_world_grid = worlds
	worlds.alignment = BoxContainer.ALIGNMENT_CENTER
	worlds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_scroll.add_child(worlds)
	for id in Model.THEMES:
		var button := Button.new()
		var palette: Dictionary = Data.theme(id)
		button.name = palette.name
		button.icon = load(palette.symbol)
		button.tooltip_text = palette.name
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 48)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_set_accessibility_name(button, palette.name)
		UiClick.bind_button(button)
		button.pressed.connect(_choose_world.bind(id))
		button.focus_entered.connect(_ensure_collection_focus_visible.bind(button))
		worlds.add_child(button)
		theme_buttons.append(button)
	_world_save_notice = Style.label("Changes not saved. Tap a theme to retry.", 13)
	_world_save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_world_save_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world_save_notice.add_theme_color_override("font_color", Style.WRONG.darkened(0.15))
	_world_save_notice.hide()
	_world_choices.add_child(_world_save_notice)


func _choose_world(id: String) -> void:
	if not _can_use_room():
		return
	if model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty()):
		return
	choose_theme(id)


func _build_playroom() -> void:
	_collection_duck_slot.queue_free()
	_room = PlayroomView.new()
	_room.name = "PipsRoom"
	_room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_room.interaction_allowed = _can_use_room
	_collection_grid.add_child(_room)
	_room.configure(playroom_state, medal_progress.counts, Data.theme(model.theme_id), reduced_motion)
	_room.playground.pip_audio_busy = audio.is_pip_busy
	_room.toy_shelf.reparent(_collection_column)
	_room.toy_shelf.interaction_allowed = _can_use_room
	_collection_duck_slot = _room.duck_slot
	_playroom_medal = _room.favorite_medal
	_room.item_selected.connect(_select_room_item)
	_room.item_previewed.connect(_room_previewed)
	_room.word_requested.connect(_room_word)
	_room.toy_played.connect(_room_toy)
	_room.pip_interaction.connect(_room_pip_interaction)
	_room.background_input.connect(_collection_scroll_input)
	_room.playground.interaction_started.connect(func() -> void:
		_end_collection_drag()
		_collection_dragged = false)
	_room.goal_requested.connect(_start_gift_adventure)
	for control in _room.controls():
		control.gui_input.connect(_collection_scroll_input.bind(control))
		control.focus_entered.connect(_ensure_collection_focus_visible.bind(control))
	_refresh_favorite_reward()


func _room_previewed(message: String) -> void:
	if not _can_use_room():
		return
	_play_ui_click()
	audio.stop_voice()
	_end_collection_drag()
	_announce_status(message)


func _select_room_item(id: String) -> bool:
	if not _can_use_room():
		return false
	if playroom_state.item(id).get("slot", "") != "toy":
		return false
	if not _ensure_playroom_loaded() or not playroom_state.select_item(id, medal_progress.counts):
		var message := "Your room could not be saved. Tap the item to retry."
		_room.show_item_error(id, "Not saved\nTap again to retry", message)
		_announce_status(message)
		return false
	audio.stop_voice()
	_room.configure(playroom_state, medal_progress.counts, Data.theme(model.theme_id), reduced_motion)
	_refresh_favorite_reward()
	_announce_status(_room.feedback_text)
	return true


func _ensure_playroom_loaded() -> bool:
	if not _playroom_ready:
		_playroom_ready = playroom_state.load_state(_favorite_reward_id)
		if _playroom_ready:
			_favorite_reward_id = playroom_state.favorite_id
			if _preferred_theme.is_empty():
				_preferred_theme = playroom_state.preferred_theme_id
	return _playroom_ready


func _room_word(id: String) -> void:
	if not _can_use_room():
		return
	for word in data.words:
		if word.id == id:
			audio.interact(model.theme_id)
			audio.say("res://" + word.audio)
			return


func _room_toy(kind: String) -> void:
	if not _can_use_room():
		return
	if kind == "offer":
		duck.react("happy")
	else:
		duck.perform_trick("bubbles" if kind in ["water", "open"] else "dance")
	_announce_status(_room.feedback_text)


func _room_pip_interaction(kind: String, message: String) -> void:
	if not _can_use_room():
		return
	if kind in ["poke", "pet", "catch", "fetch"]:
		audio.interact(model.theme_id)
		if kind in ["poke", "pet"]:
			audio.play_pip()
		else:
			audio.cue("select")
	_announce_status(message)


func _load_favorite_reward() -> void:
	var value: Variant = _host.favoriteReward() if _host != null else ""
	var config := ConfigFile.new()
	if str(value).is_empty() and config.load(playroom_save_path) == OK:
		value = config.get_value("playroom", "favorite", "")
	if value is String and collected_rewards.has(value) and not Data.reward(value).is_empty():
		_favorite_reward_id = value
	playroom_state = PlayroomState.new(playroom_save_path.get_basename() + "-v2.cfg", _host)
	_playroom_ready = false
	_ensure_playroom_loaded()
	_room.configure(playroom_state, medal_progress.counts, Data.theme(model.theme_id), reduced_motion)
	if not _playroom_ready:
		_room.feedback_text = "Room choices could not load. Tap an owned item to retry."
		_room.show_item_error(playroom_state.toy_id, "Could not load\nTap to retry", _room.feedback_text)


func _refresh_favorite_reward() -> void:
	var reward: Dictionary = Data.reward(_favorite_reward_id)
	_playroom_medal.visible = not reward.is_empty() and collected_rewards.has(_favorite_reward_id)
	if _playroom_medal.visible:
		_playroom_medal.configure(load(reward.symbol), _piece_count(reward.id), Data.theme(reward.theme).accent)
		_playroom_medal.tooltip_text = reward.name + ": Pip's favorite medal"


func _sync_collected_rewards() -> void:
	collected_rewards = medal_progress.legacy_rewards.duplicate()
	for id in medal_progress.counts:
		if medal_progress.count_for(id) > 0:
			collected_rewards[id] = true


func _piece_count(id: String) -> int:
	return 3 if medal_progress.legacy_rewards.has(id) else medal_progress.count_for(id)


func _refresh_collection() -> void:
	_sync_collected_rewards()
	if _room != null:
		_room.configure(playroom_state, medal_progress.counts, Data.theme(model.theme_id), reduced_motion)
		_refresh_favorite_reward()
		if not _playroom_ready:
			_room.feedback_text = "Room choices could not load. Tap an owned item to retry."
			_room.show_item_error(playroom_state.toy_id, "Could not load\nTap to retry", _room.feedback_text)
	_sync_collection_content()
	_layout_collection()


func _collection_scroll_input(event: InputEvent, source: Control) -> void:
	if not collection_page.visible or _collection_scroll == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_collection_scroll.accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_collection_drag(_event_position_in_collection(event, source), -2)
			else:
				_end_collection_drag()
			if not (source is Button):
				_collection_scroll.accept_event()
	elif event is InputEventMouseMotion and _collection_dragging and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_update_collection_drag(_event_position_in_collection(event, source))
		_collection_scroll.accept_event()
	elif event is InputEventScreenTouch:
		if event.canceled:
			if event.index == _collection_drag_pointer:
				_end_collection_drag()
		elif event.pressed:
			_start_collection_drag(_event_position_in_collection(event, source), event.index)
		elif event.index == _collection_drag_pointer:
			_end_collection_drag()
		_collection_scroll.accept_event()
	elif event is InputEventScreenDrag and _collection_dragging and event.index == _collection_drag_pointer:
		_update_collection_drag(_event_position_in_collection(event, source))
		_collection_scroll.accept_event()


func _event_position_in_collection(event: InputEvent, source: Control) -> Vector2:
	return _collection_scroll.get_global_transform().affine_inverse() * (source.get_global_transform() * event.position)


func _start_collection_drag(position: Vector2, pointer: int) -> void:
	if _collection_dragging:
		return
	_collection_dragging = true
	_collection_dragged = false
	_collection_drag_pointer = pointer
	_collection_drag_start_position = position


func _update_collection_drag(position: Vector2) -> void:
	if not _collection_dragging:
		return
	var displacement: Vector2 = position - _collection_drag_start_position
	if displacement.length() > 8.0:
		_collection_dragged = true


func _end_collection_drag() -> void:
	if not _collection_dragging:
		return
	_collection_dragging = false
	_collection_drag_pointer = -1
	_clear_finished_collection_swipe.call_deferred()


func _clear_finished_collection_swipe() -> void:
	if not _collection_dragging:
		_collection_dragged = false


func _collection_rails() -> Array[ReviewScroll]:
	var rails: Array[ReviewScroll] = []
	for rail in [_age_scroll, _world_scroll, _room.toy_shelf if is_instance_valid(_room) else null]:
		if is_instance_valid(rail):
			rails.append(rail)
	return rails


func _cancel_collection_rails() -> void:
	for rail in _collection_rails():
		rail.cancel_drag()
	if is_instance_valid(_age_catalog):
		_age_catalog.cancel_input()


func _set_accessibility_name(control: Control, label: String) -> void:
	for property in control.get_property_list():
		if property.name == "accessibility_name":
			control.set("accessibility_name", label)
			return


func new_round(seed_value: int = -1, repeat_lesson: bool = false, adventure_id: String = "", next_mode: String = "", required_word_id: String = "") -> bool:
	_hide_mode_menu(false, false)
	if _leaderboard_gate == "onboarding":
		return false
	_return_to_pop_picker = false
	if _leaderboard_overlay.visible:
		_hide_leaderboard()
	_settling_chest = true
	audio.stop_chest_performance()
	if model.phase == "won" and model.chest_state == "closed":
		_open_chest()
	if model.chest_state == "opening":
		chest.finish_immediately()
	_settling_chest = false
	if (_save_error and not _pending_fragment.is_empty()) or (model.phase == "won" and model.chest_state != "opened"):
		_announce_status("Your progress is waiting to be saved. Choose Retry saving.")
		return false
	_stop_voice()
	if not _stop_pop_listening():
		return false
	_pop.stop()
	_pop_rewards.pause()
	_pop_rewards_shown = false
	_controller_holding_pop_chest = false
	_rebuilding = true
	if not next_mode.is_empty():
		_mode_id = next_mode if MODES.has(next_mode) else "match"
	elif not MODES.has(_mode_id):
		_mode_id = "match"
	_memory.stop()
	_phrase.stop()
	duck.settle()
	_pending_fragment.clear()
	_unlocked_gift.clear()
	_save_error = not _progress_ready
	feedback_timer.stop()
	feedback_timer.paused = false
	chest.clear()
	_cancel_chest_hold()
	_finish_chest_drag()
	_end_collection_drag()
	audio.halt()
	_stop_feedback_animations()
	_last_phase = ""
	if not model.reset(data.words, seed_value, repeat_lesson, adventure_id, required_word_id, playroom_state.age_band_id):
		_rebuilding = false
		_show_error(model.error)
		return false
	_leaderboard_round_id = LeaderboardState.make_round_id()
	_leaderboard_result.clear()
	_leaderboard_saved_player_id = ""
	_pop_player_id = ""
	if not repeat_lesson and seed_value < 0 and not _preferred_theme.is_empty():
		model.set_theme(_preferred_theme)
	_match_connections.clear()
	for button in cards.values():
		grid.remove_child(button)
		button.queue_free()
	cards.clear()
	for card_data in model.cards:
		var button := Card.new()
		button.setup(card_data)
		button.set_reduced_motion(reduced_motion)
		button.pressed.connect(_select_card.bind(card_data.id))
		grid.add_child(button)
		cards[card_data.id] = button
	if _mode_id == "memory":
		_memory.set_reduced_motion(reduced_motion)
		_memory.start_round(model.lesson_words, Data.theme(model.theme_id), seed_value)
	if _mode_id == "phrase":
		_phrase.set_reduced_motion(reduced_motion)
		_phrase.set_muted(audio.muted or not audio.available)
		if not _phrase.configure(data.words, playroom_state.age_band_id, model.theme_id, seed_value):
			_rebuilding = false
			_show_error(_phrase.game.error)
			return false
	if _mode_id == "pop":
		_configure_pop(seed_value)
	_rebuilding = false
	_refresh()
	_layout()
	if not repeat_lesson:
		_pending_visit_id = model.adventure_id
		_save_journey()
	if _mode_id == "pop":
		_request_pop_player()
	return true


func choose_mode(id: String) -> void:
	if not MODES.has(id) or collection_page.visible or (_leaderboard_overlay.visible and not _pop_picker_open()) or model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty()):
		return
	_hide_mode_menu(false, id == _mode_id)
	if id == _mode_id and model.phase in ["waiting", "matching", "feedback"]:
		_refresh()
		return
	if new_round(-1, true, "", id):
		_default_focus().grab_focus()
		if id == "pop":
			_start_pop_listening()
		elif not _page_hidden:
			# The mode gesture restores playback after new_round silences the
			# previous mode. Voice Pop stays quiet while its microphone is open.
			audio.interact(model.theme_id)
			if id == "phrase":
				_start_phrase_prompt()


func _configure_pop(seed_value: int = -1) -> void:
	if is_instance_valid(_pop_leaderboard):
		_pop_leaderboard.settle_animation()
	_pop_leaderboard = null
	_leaderboard_round_id = LeaderboardState.make_round_id()
	_leaderboard_result.clear()
	_leaderboard_saved_player_id = ""
	_pop_player_id = ""
	var age: Dictionary = Data.age_band(playroom_state.age_band_id)
	var pool: Array = data.words.filter(func(word: Dictionary) -> bool: return Data.word_level(word) <= age.max_level)
	_pop.configure(pool, reduced_motion, seed_value)
	_pop.retry_button.text = "Choose player"


func _start_pop_listening() -> void:
	if _mode_id != "pop" or _pop_rewards_shown or collection_page.visible or _leaderboard_overlay.visible or _page_hidden or _mode_menu_open():
		return
	if _pop_player_id.is_empty() or _pop.game.phase == "finished":
		_request_pop_player()
		return
	audio.halt()
	duck.settle()
	if not _stop_pop_listening():
		return
	if _host == null:
		_pop.set_listening(true, false, "Voice Pop needs a browser with speech recognition. Open the Web game in Chrome or Safari.")
		return
	_pop_speech_active = true
	_host.speechMode(true, "pop")


func _stop_pop_listening() -> bool:
	var was_active: bool = _pop_speech_active
	_pop_speech_active = false
	if _host != null:
		if was_active and not bool(_host.stopSpeech()):
			_pop_speech_active = true
			return false
	return true


func _pop_launched(_uid: int) -> void:
	if _mode_id != "pop" or collection_page.visible or _page_hidden:
		return
	audio.interact(model.theme_id, false)
	audio.cue("pop-launch")


func _pop_hit(_word: Dictionary) -> void:
	if _mode_id != "pop" or collection_page.visible or _page_hidden:
		return
	audio.interact(model.theme_id, false)
	audio.cue("pop-slice")
	duck.react_gameplay(true)


func _pop_missed(_count: int) -> void:
	if _count <= 0 or _mode_id != "pop" or collection_page.visible or _page_hidden:
		return
	audio.interact(model.theme_id, false)
	_react_to_gameplay(false)


func _react_to_gameplay(correct: bool) -> void:
	if collection_page.visible or _page_hidden:
		return
	duck.react_gameplay(correct)
	if _mode_id == "pop" and not _voice_mode:
		audio.play_pip_reaction(correct)


func _pop_hear(word: Dictionary) -> void:
	if _mode_id != "pop" or _pop.game.phase != "finished" or collection_page.visible:
		return
	if not _stop_pop_listening():
		_announce_status("Microphone could not be stopped. Close this tab to stop voice input.")
		return
	audio.interact(model.theme_id, false)
	audio.say("res://" + word.audio)


func _pop_finished(result: Dictionary) -> void:
	if not _stop_pop_listening():
		_announce_status("Microphone could not be stopped. Close this tab to stop voice input.")
	audio.halt()
	if _mode_id != "pop" or not _leaderboard_result.is_empty():
		return
	_leaderboard_result = result.duplicate(true)
	if int(result.get("chest_count", 0)) > 0:
		_pop_rewards.configure(_leaderboard_round_id, int(result.chest_count), model.theme_id, data.chests, reduced_motion)
	_pop_leaderboard = LeaderboardPanel.new()
	_pop_leaderboard.name = "PopLeaderboard"
	_pop.attach_leaderboard(_pop_leaderboard)
	_pop_leaderboard.score_saved.connect(_leaderboard_score_saved)
	_pop_leaderboard.changed.connect(_publish_leaderboards)
	_pop_leaderboard.configure(leaderboard_state, "result", "pop", _leaderboard_round_id, _leaderboard_result, reduced_motion, _pop_player_id)
	_pop_leaderboard.save_assigned_score()
	_publish_leaderboards()


func _pop_status_changed(snapshot: Dictionary) -> void:
	if _mode_id == "pop" and _host != null:
		_host.popStatus(JSON.stringify(snapshot))


func _pop_chest_earned(count: int) -> void:
	if _mode_id != "pop" or collection_page.visible or _page_hidden:
		return
	audio.chest_cue(model.theme_id, "unlock")
	_announce_status("Chest earned! %d of 3 chests." % count)


func _show_pop_rewards() -> void:
	if _mode_id != "pop" or collection_page.visible or _leaderboard_overlay.visible or _page_hidden:
		return
	if not _stop_pop_listening():
		return
	if _pop.game.phase == "finished" and int(_leaderboard_result.get("chest_count", 0)) > 0:
		_pop_rewards.configure(_leaderboard_round_id, int(_leaderboard_result.chest_count), model.theme_id, data.chests, reduced_motion)
	else:
		var restored: bool = _pop_rewards.configure_saved(data.chests, reduced_motion)
		if not restored and not _pop_rewards.has_pending():
			return
	_pop.cancel_result_input()
	audio.halt()
	_pop_rewards_shown = true
	_refresh()
	_pop_rewards.resume()
	_default_focus().grab_focus()
	_publish_pop_rewards(_pop_rewards.snapshot())


func _hide_pop_rewards() -> void:
	_pop_rewards.pause()
	_controller_holding_pop_chest = false
	_pop_rewards_shown = false
	if _pop.game.phase != "finished" or _leaderboard_result.is_empty():
		choose_mode("match")
	else:
		_refresh()
		_default_focus().grab_focus()
	_publish_pop_rewards(_pop_rewards.snapshot())


func _publish_pop_rewards(snapshot: Dictionary) -> void:
	if _host != null:
		var status: Dictionary = snapshot.duplicate(true)
		status["visible"] = _pop_rewards_shown and _mode_id == "pop" and not collection_page.visible and not _leaderboard_overlay.visible and not _page_hidden
		_host.popRewardStatus(JSON.stringify(status))


func _pop_chest_audio(action: String, theme_id: String, progress: float) -> void:
	if action == "stop":
		audio.stop_chest_performance()
	elif action in ["cancel", "release"]:
		audio.stop_chest_charge()
	elif action == "finish":
		audio.finish_chest_motion()
	elif _mode_id == "pop" and _pop_rewards_shown and not _page_hidden and not collection_page.visible and not _leaderboard_overlay.visible:
		match action:
			"prepare":
				audio.interact(theme_id)
				audio.stop_voice()
				audio.prepare_chest(theme_id)
			"charge": audio.set_chest_charge(progress)
			"tension": audio.set_chest_tension(progress)
			"reward": audio.chest_reward(theme_id, progress > 0.0)


func _phrase_interaction_allowed() -> bool:
	return _mode_id == "phrase" and model.phase in ["waiting", "matching", "feedback"] \
		and not _rebuilding and not _page_hidden and not _speech_debug_active and not collection_page.visible \
		and not _leaderboard_overlay.visible and not _mode_menu_open()


func _pause_phrase() -> void:
	_phrase.pause()
	if _mode_id == "phrase":
		audio.stop_voice()
		audio.stop_pair_feedback()


func _resume_phrase() -> void:
	_phrase.set_muted(audio.muted or not audio.available)
	if _phrase_interaction_allowed():
		_phrase.resume()
	else:
		_phrase.pause()
	_publish_phrase(_phrase.snapshot())


func _start_phrase_prompt() -> void:
	if not _phrase_interaction_allowed():
		return
	if audio.muted or not audio.available:
		return
	audio.interact(model.theme_id)
	_phrase.play_prompt()


func _phrase_audio_requested(kind: String, value: String) -> void:
	if not _phrase_interaction_allowed():
		return
	audio.interact(model.theme_id)
	match kind:
		"select":
			audio.stop_pair_feedback()
			audio.play_ui_click()
		"word":
			for word: Dictionary in data.words:
				if word.id == value:
					audio.say("res://" + str(word.audio))
					break
		"phrase":
			var question: Dictionary = _phrase.game.current_question()
			if str(question.get("id", "")) == value:
				audio.say("res://" + str(question.audio))
		"feedback":
			audio.stop_voice()
			audio.play_pair_feedback(value == "correct")


func _phrase_status_changed(message: String) -> void:
	if _phrase_interaction_allowed():
		_message.text = message
		_announce_status(message)


func _phrase_finished() -> void:
	if not _phrase_interaction_allowed() or _phrase.game.phase != "finished" or _phrase.game.completed != 3:
		return
	audio.stop_voice()
	model.phase = "won"
	_refresh()
	_layout()
	_default_focus().grab_focus()


func _publish_phrase(state: Dictionary) -> void:
	if _host == null or (_mode_id != "phrase" and _phrase_published.is_empty()):
		return
	var value: Dictionary = state.duplicate(true)
	value["visible"] = _phrase_interaction_allowed() and _phrase.is_visible_in_tree()
	var serialized := JSON.stringify(value)
	if serialized != _phrase_published:
		_phrase_published = serialized
		_host.phraseStatus(serialized)


func _memory_revealed(word: Dictionary, _kind: String, _index: int) -> void:
	if _mode_id != "memory" or collection_page.visible:
		return
	audio.interact(model.theme_id)
	audio.stop_pair_feedback()
	audio.cue("select")
	audio.say("res://" + word.audio)
	duck.react("curious")
	_sync_memory_selection()


func _memory_answer(_words: Array, correct: bool) -> void:
	if _mode_id != "memory" or collection_page.visible:
		return
	audio.play_pair_feedback(correct)
	_react_to_gameplay(correct)


func _memory_progress(successes: int, _attempts: int) -> void:
	if _mode_id != "memory":
		return
	if not _rebuilding:
		_success.set_filled_count(successes, 5)
		_success.tooltip_text = "%d matches" % successes
		_mistakes.set_filled_count(_memory.memory.mistakes, 0)
		_mistakes.tooltip_text = "%d mistakes" % _memory.memory.mistakes


func _memory_finished(won: bool, found: Array) -> void:
	if _mode_id != "memory" or model.phase == "won" or not won or _memory.memory.phase != "won" or found.size() != 5:
		return
	model.phase = "won"
	_refresh()
	_layout()


func _memory_status() -> String:
	return "Memory. %d of 5 pairs grown. %d attempts. %s" % [_memory.memory.matched_word_ids.size(), _memory.memory.attempts, _memory.status_label.text]


func _sync_memory_selection() -> void:
	if _host == null:
		return
	var selection := ""
	if not _memory.memory.selected_indices.is_empty():
		var index: int = _memory.memory.selected_indices.back()
		var card: Dictionary = _memory.memory.cards[index]
		selection = "Memory card %d. %s: %s." % [index + 1, "Word" if card.kind == "word" else "Picture", card.word.text]
	_host.selectionStatus(selection)


func _memory_prompt() -> void:
	if _rebuilding or _mode_id != "memory" or collection_page.visible or model.phase == "won":
		return
	if _memory.memory.phase in ["waiting", "won"]:
		audio.stop_voice()
	_message.text = _memory_status()
	_announce_status(_message.text)
	_sync_memory_selection()
	if _memory.memory.phase == "feedback" or not _valid_focus(get_viewport().gui_get_focus_owner()):
		var target: Control = _default_focus()
		if _valid_focus(target):
			target.grab_focus()


func _refresh() -> void:
	if _rebuilding:
		return
	var theme_changed: bool = str(_active_palette.get("id", "")) != model.theme_id
	if theme_changed:
		_active_palette = Data.theme(model.theme_id)
		audio.prepare_chest(model.theme_id)
	var palette: Dictionary = _active_palette
	_background.color = Style.PAPER.lerp(palette.background, 0.16)
	if theme_changed:
		collection_page.add_theme_stylebox_override("panel", Style.box(_background.color, Color.TRANSPARENT, 0, 0))
	for index in range(theme_buttons.size()):
		var button: Button = theme_buttons[index]
		button.button_pressed = Model.THEMES[index] == model.theme_id
		button.disabled = model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty())
		if theme_changed:
			Style.button(button, Data.theme(Model.THEMES[index]).accent)
	var mode_changed: bool = theme_changed or _styled_mode_id != _mode_id
	for index in range(_mode_buttons.size()):
		var button: Button = _mode_buttons[index]
		button.button_pressed = MODES.keys()[index] == _mode_id
		button.disabled = model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty())
		if mode_changed:
			Style.quiet_button(button, palette.accent)
			button.add_theme_font_size_override("font_size", 16)
	if mode_changed:
		_fit_mode_buttons()
	if theme_changed:
		_memory.set_palette(palette)
		_phrase.apply_theme(palette, model.theme_id)
		for button in [collection_button, hint_button]:
			Style.square_icon_button(button, palette.accent)
		Style.square_icon_button(_collection_back, palette.accent)
		Style.button(_storage_retry_button, palette.accent)
		_style_result_actions(palette.accent)
	if mode_changed:
		_styled_mode_id = _mode_id
	_voice_button.disabled = _host == null or not bool(_host.speechAvailable())
	_voice_button.focus_mode = Control.FOCUS_NONE if _voice_button.disabled else Control.FOCUS_ALL
	_voice_button.tooltip_text = "Voice on: click to stop" if _voice_mode else "Voice: click to listen. Browser speech may process audio remotely."
	if _voice_button.disabled:
		_voice_button.tooltip_text = "Voice input is unavailable in this browser. You can still tap cards."
	_set_accessibility_name(_voice_button, _voice_button.tooltip_text)
	_voice_button.button_pressed = _voice_mode
	_voice_button.engaged = _voice_listening
	_style_voice_button()
	_result_retry_button.visible = _save_error
	_result_retry_button.tooltip_text = medal_progress.error if _save_error else ""
	_result_board_button.disabled = model.chest_state == "opening"
	if _mode_id == "memory":
		_memory_progress(_memory.memory.matched_word_ids.size(), _memory.memory.attempts)
	var playing: bool = model.phase in ["waiting", "matching", "feedback"]
	_storage_retry_button.add_theme_font_size_override("font_size", 16)
	_storage_retry_button.text = "Retry rewards" if _save_error else "Retry saving"
	_storage_retry_button.tooltip_text = medal_progress.error if _save_error else playroom_state.error
	_storage_retry_button.visible = (_save_error or _journey_save_failed) and playing
	_world_save_notice.visible = _journey_save_failed
	_world_save_notice.tooltip_text = playroom_state.error if _journey_save_failed else ""
	_refresh_age_choices()
	_success.visible = playing and _mode_id == "memory" and not _storage_retry_button.visible
	if not playing and _voice_mode:
		_stop_voice()
	_voice_button.visible = playing and _mode_id == "match"
	_refresh_hint()
	_match_playfield.visible = playing and _mode_id == "match"
	grid.visible = playing and _mode_id == "match"
	_memory.visible = playing and _mode_id == "memory"
	_phrase.visible = playing and _mode_id == "phrase" and not collection_page.visible
	_resume_phrase()
	_pop.visible = playing and _mode_id == "pop" and not collection_page.visible and not _pop_rewards_shown
	_pop_rewards.visible = playing and _mode_id == "pop" and not collection_page.visible and _pop_rewards_shown
	_mistakes.visible = _success.visible
	_message.hide()
	_outcome.visible = not playing
	_refresh_match_cards()
	if not model.hint_ids.is_empty():
		_message.text = "Hint: match the %s cards." % model.card_by_id(model.hint_ids[0]).word.text
	elif model.phase == "matching":
		_message.text = "Now find its match!"
	elif model.phase == "feedback":
		_message.text = "Great match!" if model.last_correct else "Not quite. Try another one!"
	else:
		_message.text = "Find %d word–picture pairs." % Model.MATCH_PAIR_COUNT
	if playing and _mode_id == "memory":
		_message.text = _memory_status()
	elif playing and _mode_id == "phrase":
		_message.text = "Phrase Builder. %d of 3 phrases complete. Listen to Pip and put the words in order." % _phrase.game.completed
	elif playing and _mode_id == "pop":
		_message.text = "Voice Pop. Say the flying words. Start with %d seconds." % ceili(VoicePop.PopModel.DURATION)
	var won: bool = model.phase == "won"
	var saving_reward: bool = won and model.chest_state == "opened" and not _pending_fragment.is_empty() \
		and medal_progress.count_for(_pending_fragment.medal_id) < int(_pending_fragment.after)
	_new_adventure_button.visible = won and model.chest_state == "opened" and not _save_error and not saving_reward
	var show_result_message: bool = not won or _save_error or saving_reward
	_result_text.visible = show_result_message
	_title.visible = show_result_message
	_caption.visible = show_result_message
	_treasure_backdrop.visible = won
	_treasure_backdrop.show_theme_name = not show_result_message
	_treasure_backdrop.queue_redraw()
	if won:
		_treasure_backdrop.configure(palette)
	chest.visible = won
	chest_button.visible = won
	chest_button.disabled = model.chest_state == "opened" or chest.opening_committed() or _save_error
	chest_button.tooltip_text = "Your chest is open. You can let go!" if chest.opening_committed() else "Hold to open the treasure chest"
	_set_accessibility_name(chest_button, chest_button.tooltip_text)
	_stage.add_theme_stylebox_override("panel", Style.box(palette.background, palette.accent.lightened(0.5), 26, 2))
	if won:
		var reward_id: String = model.reward_theme if not model.reward_theme.is_empty() else model.theme_id
		var reward_palette: Dictionary = Data.theme(reward_id)
		chest.reduced_motion = reduced_motion
		chest.configure_skin(reward_palette, data.chests)
		_title.text = "You did it!"
		_caption.text = "Hold to open your chest!"
		if model.chest_state == "opening":
			_caption.text = "Your chest is open. You can let go!" if chest.opening_committed() else "Keep holding to open. Release to cancel."
		elif model.chest_state == "opened":
			_title.text = "Chest opened!"
			_caption.text = "Ready for another adventure?"
			if saving_reward:
				_title.text = "Saving your progress"
				_caption.text = "Please wait."
		if _save_error:
			_title.text = "Save your progress"
			_caption.text = "Saving failed.\nChoose Retry saving."
		elif not _unlocked_gift.is_empty():
			_title.text = "A gift for Pip!"
			_caption.text = str(_unlocked_gift.name) + " unlocked!"
	if _last_phase != model.phase:
		_last_phase = model.phase
		if won:
			if _mode_id == "match":
				_leaderboard_result = {"won": true, "mistakes": model.mistakes, "hints_used": Model.MAX_HINTS - model.hints_remaining}
			elif _mode_id == "memory":
				_leaderboard_result = {"won": true, "attempts": _memory.memory.attempts, "peeks": _memory.memory.peeks}
			duck.react("happy")
			audio.cue(model.theme_id + "-arrive")
			if _controller_mode and not collection_page.visible:
				chest_button.focus_mode = Control.FOCUS_ALL
				_default_focus().grab_focus()
	_result_board_button.visible = model.phase == "won" and _mode_id in ["match", "memory"] and not _leaderboard_result.is_empty()
	if _host != null:
		_host.background("#" + palette.background.to_html(false), "#" + palette.accent.to_html(false), "#" + palette.light.to_html(false), model.theme_id)
	if _save_error:
		_message.text = "Rewards are unavailable. You can keep practising." if playing else "Reward progress: " + medal_progress.error
	elif _journey_save_failed and playing:
		_message.text = "Room choices could not be remembered. You can keep practising. Choose Retry saving."
	if collection_page.visible:
		_announce_collection_state()
	else:
		_announce_status(_message.text if playing else _title.text + " " + _caption.text)
	if _host != null and _mode_id == "memory":
		_sync_memory_selection()
	elif _host != null:
		var selection := ""
		if not model.selected_id.is_empty():
			var selected: Dictionary = model.card_by_id(model.selected_id)
			selection = ("Word: " if selected.kind == "word" else "Picture: ") + selected.word.text
		_host.selectionStatus(selection)
	var blocked_controls: Dictionary = _collection_focus_modes
	for control in blocked_controls:
		if is_instance_valid(control):
			control.focus_mode = Control.FOCUS_NONE
	for control in _mode_menu_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = Control.FOCUS_NONE
	_layout_result()
	_fit_mode_buttons.call_deferred()
	if theme_changed:
		_layout_collection.call_deferred()
	_update_duck()
	_refresh_controller_focus()


func _hear_word(word: Dictionary) -> void:
	if collection_page.visible or _voice_mode:
		return
	audio.interact(model.theme_id)
	audio.stop_pair_feedback()
	audio.say("res://" + word.audio)
	duck.react("curious")
	_announce_status(str(word.text) + ". Look at the picture and say the word.")


func _refresh_match_cards() -> void:
	var palette: Dictionary = _active_palette if not _active_palette.is_empty() else Data.theme(model.theme_id)
	var locked: bool = not model.phase in ["waiting", "matching"] and not (_mode_id == "match" and model.phase == "feedback" and not _voice_mode)
	_refresh_match_connections()
	var pair_styles: Dictionary = {}
	for pair in _match_connections.connections:
		pair_styles[pair.id] = pair
	for id in cards:
		var word_id: String = str(cards[id].card_data.word.id)
		var pair: Dictionary = pair_styles.get(word_id, {})
		cards[id].refresh(palette, model.selected_id == id, model.matched_ids.has(id),
			model.phase == "feedback" and not model.last_correct and model.feedback_ids.has(id),
			locked, model.hint_ids.has(id), int(pair.get("lane", -1)), pair.get("color", Style.GOOD),
			word_id == _match_connections.focused_id)
		cards[id].disabled = locked
		cards[id].picture.modulate.a = 1.0
		cards[id].word_label.modulate.a = 1.0
	_refresh_hint_link()
	_refresh_voice_match_link()


func _refresh_match_connections() -> void:
	if _match_connections == null or _rebuilding:
		return
	var pairs: Array[Dictionary] = []
	if _mode_id == "match":
		var pictures: Array = model.cards.filter(func(card: Dictionary) -> bool: return card.kind == "image")
		for index in range(pictures.size()):
			var picture: Dictionary = pictures[index]
			if not model.matched_ids.has(picture.id):
				continue
			for word in model.cards:
				if word.kind == "word" and word.word.id == picture.word.id and model.matched_ids.has(word.id):
					pairs.append({"id": picture.word.id, "source": cards.get(picture.id),
						"target": cards.get(word.id), "lane": index})
					break
	_match_connections.configure(pairs, grid.columns == Model.MATCH_PAIR_COUNT)


func _refresh_hint_link() -> void:
	if _hint_link == null or collection_page == null:
		return
	var first: Control = null
	var second: Control = null
	if _mode_id == "match" and grid.is_visible_in_tree() and model.hint_ids.size() == 2:
		first = cards.get(model.hint_ids[0])
		second = cards.get(model.hint_ids[1])
	_hint_link.set_palette(Data.theme(model.theme_id))
	_hint_link.configure(first, second, reduced_motion,
		_page_hidden or collection_page.visible or _mode_menu_open())


func _start_voice_match_feedback(ids: Array[String]) -> void:
	_clear_voice_match_feedback()
	if ids.size() != 2 or _mode_id != "match" or _page_hidden or collection_page.visible:
		return
	_voice_match_ids.assign(ids)
	_voice_match_left = VOICE_MATCH_SECONDS
	_voice_match_serial += 1
	_voice_match_origin_frame = Engine.get_process_frames()
	_refresh_voice_match_link()
	# The dedicated answer channel continues through recognizer rollover while music and words stay quiet.
	audio.interact(model.theme_id, false)
	audio.play_pair_feedback(true)


func _clear_voice_match_feedback(stop_sound: bool = true) -> void:
	_voice_match_left = 0.0
	_voice_match_ids.clear()
	if _voice_match_link != null:
		_voice_match_link.configure(null, null, reduced_motion, false)
	if audio != null and stop_sound:
		audio.stop_pair_feedback()
	_publish_voice_match_feedback()


func _refresh_voice_match_link() -> void:
	if _voice_match_link == null:
		return
	if _voice_match_left <= 0.0:
		return
	if _mode_id != "match" or _page_hidden or collection_page.visible or not grid.is_visible_in_tree() \
		or not _voice_mode or _voice_match_ids.size() != 2:
		_clear_voice_match_feedback()
		return
	_voice_match_link.set_palette(Data.theme(model.theme_id))
	_voice_match_link.configure(cards.get(_voice_match_ids[0]), cards.get(_voice_match_ids[1]), reduced_motion, false)
	_publish_voice_match_feedback()


func _advance_voice_match_feedback(delta: float) -> void:
	if _voice_match_left <= 0.0 or delta <= 0.0 or not is_finite(delta):
		return
	_voice_match_left = maxf(0.0, _voice_match_left - delta)
	if _voice_match_left <= 0.0:
		_clear_voice_match_feedback()


func _voice_match_feedback_snapshot() -> Dictionary:
	var result: Dictionary = {"active": _voice_match_left > 0.0 and _voice_match_link != null and _voice_match_link.is_visible_in_tree(),
		"duration": VOICE_MATCH_SECONDS, "serial": _voice_match_serial, "reduced_motion": reduced_motion}
	if not result.active:
		return result
	for entry in [["source", _voice_match_link.source], ["target", _voice_match_link.target]]:
		var card: Control = entry[1]
		var bounds: Rect2 = card.get_global_rect()
		result[entry[0]] = {"id": str(card.card_data.id), "x": bounds.position.x, "y": bounds.position.y,
			"width": bounds.size.x, "height": bounds.size.y}
	var path: Array = []
	for point in _voice_match_link.path:
		var global_point: Vector2 = _voice_match_link.get_global_transform() * point
		path.append({"x": global_point.x, "y": global_point.y})
	result.path = path
	return result


func _publish_voice_match_feedback() -> void:
	if _host == null:
		return
	var serialized: String = JSON.stringify(_voice_match_feedback_snapshot())
	if serialized != _voice_match_published:
		_voice_match_published = serialized
		_host.voiceMatchFeedback(serialized)


func _continue_match() -> void:
	if collection_page.visible or _mode_id != "match" or model.phase != "feedback":
		return
	audio.stop_voice()
	audio.stop_pair_feedback()
	_resolve_feedback()
	_default_focus().grab_focus()


func _refresh_controller_focus() -> void:
	if not _controller_mode or collection_page.visible:
		return
	if model.phase == "won" and model.chest_state == "opening":
		# Keep the handoff pending until the next result action is available.
		return
	if model.phase == "won" and model.chest_state == "closed" and not _save_error:
		chest_button.focus_mode = Control.FOCUS_ALL
		chest_button.grab_focus()
	elif not _valid_focus(get_viewport().gui_get_focus_owner()):
		_default_focus().grab_focus()


func _layout() -> void:
	if grid == null:
		return
	_cancel_collection_rails()
	_refresh_hint()
	_fit_mode_buttons.call_deferred()
	_message.hide()
	_stop_feedback_animations()
	_end_collection_drag()
	_fit_grid.call_deferred()
	_layout_collection()
	_layout_result()
	_sync_voice_bounds()
	_update_duck()
	_fit_content.call_deferred()


func _fit_content() -> void:
	# Containers grow to transient child minima, but do not shrink back with anchors alone.
	if _content_margins != null:
		var scale: float = Style.ui_scale(self)
		for edge in ["top", "bottom"]:
			_content_margins.add_theme_constant_override("margin_" + edge, ceili(12 / scale))
		for edge in ["left", "right"]:
			_content_margins.add_theme_constant_override("margin_" + edge, maxi(ceili(12 / scale), roundi((size.x - 1040 / scale) * 0.5)))
		_content_margins.size = size


func _fit_grid() -> void:
	if grid == null or _rebuilding or cards.is_empty() or not grid.is_visible_in_tree():
		return
	var area: Vector2 = _match_playfield.size
	var css_scale: float = Style.ui_scale(self)
	grid.columns = Style.word_board_columns(area, css_scale, Vector2(10, 10))
	var gutter: int = ceili(MatchConnections.GUTTER_PIXELS / css_scale)
	var horizontal_gap: int = gutter if grid.columns == 2 else 10
	var vertical_gap: int = 10 if grid.columns == 2 else gutter
	if grid.columns == Model.MATCH_PAIR_COUNT:
		# In short landscape speech layouts, protect the two 44-pixel card rows.
		vertical_gap = mini(vertical_gap, maxi(10, floori(area.y - 88 / Style.ui_scale(self))))
	grid.add_theme_constant_override("h_separation", horizontal_gap)
	grid.add_theme_constant_override("v_separation", vertical_gap)
	var rows := ceili(float(cards.size()) / grid.columns)
	var cell_size := Vector2(
		maxf(1, (area.x - (grid.columns - 1) * horizontal_gap) / grid.columns),
		maxf(1, (area.y - (rows - 1) * vertical_gap) / rows))
	for card in cards.values():
		# The speech panel shares the playfield; let all five pairs fit its remaining space.
		card.custom_minimum_size = Vector2(72, 72).min(cell_size)
	grid.position = Vector2.ZERO
	grid.size = area
	var pictures: Array = model.cards.filter(func(card: Dictionary) -> bool: return card.kind == "image")
	var words: Array = model.cards.filter(func(card: Dictionary) -> bool: return card.kind == "word")
	var display_order: Array = pictures + words
	if grid.columns == 2:
		display_order = []
		for index in range(pictures.size()):
			display_order.append(pictures[index])
			display_order.append(words[index])
	for index in range(display_order.size()):
		var button: Button = cards[display_order[index].id]
		if grid.get_child(index) != button:
			grid.move_child(button, index)
	_refresh_hint_link.call_deferred()
	_refresh_match_connections.call_deferred()


func _fit_mode_buttons() -> void:
	var css_scale: float = Style.ui_scale(self)
	_header_spacer.show()
	var gap: int = ceili(8 / css_scale)
	_main_column.add_theme_constant_override("separation", gap)
	_header.add_theme_constant_override("separation", gap)
	_header.custom_minimum_size.y = ceilf(56 / css_scale)
	_toolbar.add_theme_constant_override("separation", gap)
	_toolbar.custom_minimum_size.x = 0.0
	var with_counts: bool = _mode_id == "memory" and model.phase in ["waiting", "matching", "feedback"] and not _storage_retry_button.visible
	_header_duck_slot.custom_minimum_size = Vector2(ceilf((132 if with_counts else 52) / css_scale), ceilf(56 / css_scale))
	_header_duck_art_slot.position = Vector2(0, 2 / css_scale)
	_header_duck_art_slot.size = Vector2.ONE * (52 / css_scale)
	_success.position = Vector2(60, 5) / css_scale
	_mistakes.position = Vector2(60, 30) / css_scale
	_mistakes.visible = with_counts
	for counter in [_success, _mistakes]:
		counter.size = Vector2(70, 21) / css_scale
		counter.queue_redraw()
	_header_duck_slot.add_theme_stylebox_override("panel", Style.box(
		Color(1, 1, 1, 0.75) if with_counts else Color.TRANSPARENT, Color.TRANSPARENT, ceili(12 / css_scale), 0))
	var accent: Color = _active_palette.get("accent", Style.GOOD)
	var heading_focus: int = _mode_heading_button.focus_mode
	Style.quiet_button(_mode_heading_button, accent, 0)
	_mode_heading_button.focus_mode = heading_focus
	_mode_heading_button.custom_minimum_size = Vector2.ZERO
	_mode_heading_button.set("accessibility_name", str(MODES[_mode_id]) + ". Choose a game")
	_mode_heading.text = str(MODES[_mode_id]) + "  ›"
	_mode_heading.add_theme_font_size_override("font_size", ceili((22 if size.x * css_scale >= 680 else 15) / css_scale))
	_mode_heading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_heading.offset_bottom = -14 / css_scale if size.x * css_scale >= 680 else 0
	_mode_subheading.visible = size.x * css_scale >= 680
	_mode_subheading.text = {"match": "FIND 5 PAIRS  /  PICTURE + WORD", "memory": "TURN TWO CARDS  /  FIND A PAIR", "pop": "SAY THE WORD  /  WATCH IT POP", "phrase": "LISTEN AND BUILD  /  3 PHRASES"}.get(_mode_id, "PIP AND WORDS")
	_mode_subheading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_subheading.offset_top = 32 / css_scale
	_mode_subheading.add_theme_font_size_override("font_size", ceili(10 / css_scale))
	_layout_game_heading()
	_mode_panel.configure(_mode_id, audio.muted if audio != null else false, reduced_motion)
	_layout_mode_menu()
	_layout_mode_menu.call_deferred()
	for button in [collection_button, hint_button, _memory.study_button]:
		Style.square_icon_button(button, accent)
	_style_voice_button()
	var compact_retry: bool = size.x * css_scale < 360
	_storage_retry_button.text = "Retry" if compact_retry else "Retry rewards" if _save_error else "Retry saving"
	_set_accessibility_name(_storage_retry_button, "Retry rewards" if _save_error else "Retry saving")
	_storage_retry_button.custom_minimum_size = Vector2(72 if compact_retry else 96, 44) / css_scale
	_storage_retry_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_storage_retry_button.add_theme_font_size_override("font_size", ceili(14 / css_scale))
	_voice_space.custom_minimum_size.y = ceilf(112 / css_scale)
	# Retry text and the Pip cluster can shrink after the header first expands.
	_content_margins.queue_sort.call_deferred()


func _layout_game_heading() -> void:
	if _mode_heading_button == null:
		return
	# Restyling can expand the button before its temporary minimum size is cleared.
	_mode_heading_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_heading_button.visible = _header_spacer.size.x * Style.ui_scale(self) >= 64 and model.phase in ["waiting", "matching", "feedback"]


func _layout_mode_menu() -> void:
	var css_scale: float = Style.ui_scale(self)
	var edge: float = ceilf(12 / css_scale)
	_mode_panel.fit(size - Vector2.ONE * edge * 2, css_scale)
	_mode_panel.position = (size - _mode_panel.size) * 0.5
	_publish_library.call_deferred()


func _publish_library() -> void:
	if _host == null:
		return
	var value := JSON.stringify(_mode_panel.snapshot())
	if value != _library_published:
		_library_published = value
		_host.libraryStatus(value)


func _style_voice_button() -> void:
	if _voice_button == null:
		return
	var accent: Color = _active_palette.get("accent", Style.GOOD)
	var scale: float = Style.ui_scale(self)
	if accent == _voice_style_accent and is_equal_approx(scale, _voice_style_scale):
		return
	_voice_style_accent = accent
	_voice_style_scale = scale
	Style.square_icon_button(_voice_button, accent)
	var radius: int = ceili(10 / scale)
	var normal := Style.box(accent, accent, radius, 0)
	normal.shadow_color = Color(accent, 0.18)
	normal.shadow_size = ceili(2 / scale)
	normal.shadow_offset = Vector2(0, 1 / scale)
	_voice_button.add_theme_stylebox_override("normal", normal)
	_voice_button.add_theme_stylebox_override("hover", Style.box(accent.darkened(0.06), accent, radius, 0))
	_voice_button.add_theme_stylebox_override("pressed", Style.box(accent.darkened(0.18), accent, radius, 0))
	_voice_button.add_theme_stylebox_override("hover_pressed", Style.box(accent.darkened(0.12), accent, radius, 0))
	_voice_button.add_theme_stylebox_override("disabled", Style.box(Color("#e9eef2"), Color("#c7d1dc"), radius, 1))
	_voice_button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Style.INK, radius, maxi(2, roundi(2 / scale))))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_voice_button.add_theme_color_override(state, Color.WHITE)
	_voice_button.add_theme_color_override("font_disabled_color", Style.MUTED)
	_voice_button.queue_redraw()


func _layout_collection() -> void:
	if not is_instance_valid(_room):
		return
	var scale: float = Style.ui_scale(self)
	var compact: bool = size.y * scale < 500
	var padding: int = ceili((8 if compact else 12) / scale)
	var gap: int = ceili((6 if compact else 8) / scale)
	var max_width: float = 960 / scale
	for edge in ["left", "right"]:
		_collection_margins.add_theme_constant_override("margin_" + edge, maxi(padding, roundi((size.x - max_width) * 0.5)))
	for edge in ["top", "bottom"]:
		_collection_margins.add_theme_constant_override("margin_" + edge, padding)
	_collection_margins.set_deferred("size", size)
	_collection_column.add_theme_constant_override("separation", gap)
	_leaderboard_menu.add_theme_constant_override("separation", gap)
	for button in [_players_button, _leaderboards_button]:
		var previous_focus: int = button.focus_mode
		Style.action_button(button, _active_palette.get("accent", Style.GOOD))
		button.focus_mode = previous_focus
		button.custom_minimum_size.y = ceilf(40 / scale)
	_collection_header.add_theme_constant_override("separation", gap)
	_collection_header.custom_minimum_size.y = ceilf(48 / scale)
	_collection_grid.add_theme_constant_override("separation", 0)
	_age_choices.add_theme_constant_override("separation", roundi(4 / scale))
	_age_scroll.custom_minimum_size.y = ceilf(48 / scale)
	_age_row.add_theme_constant_override("separation", roundi(6 / scale))
	_age_label.add_theme_font_size_override("font_size", ceili(14 / scale))
	_age_label.custom_minimum_size.x = ceilf(30 / scale)
	_age_notice.add_theme_font_size_override("font_size", ceili(13 / scale))
	_age_notice.custom_minimum_size.y = ceilf(20 / scale)
	for button in _age_buttons.values():
		var focus: int = button.focus_mode
		Style.action_button(button, _active_palette.get("accent", Style.GOOD))
		button.focus_mode = focus
		button.custom_minimum_size.x = ceilf(52 / scale)
	var title_width: float = ceilf(40 / scale)
	_collection_title.custom_minimum_size = Vector2(title_width, ceilf(44 / scale))
	_collection_title.add_theme_font_size_override("font_size", ceili(18 / scale))
	Style.square_icon_button(_collection_back, _active_palette.get("accent", Style.GOOD))
	if is_instance_valid(_world_grid):
		var side: int = ceili((44 if compact else 52) / scale)
		var spacing: int = roundi(6 / scale)
		_world_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_world_scroll.custom_minimum_size.y = side
		_world_grid.add_theme_constant_override("separation", spacing)
		_world_save_notice.add_theme_font_size_override("font_size", ceili(13 / scale))
		for index in range(theme_buttons.size()):
			var button: Button = theme_buttons[index]
			var palette: Dictionary = Data.theme(Model.THEMES[index])
			Style.square_icon_button(button, palette.accent)
			button.custom_minimum_size = Vector2.ONE * side
			button.add_theme_constant_override("icon_max_width", ceili((30 if compact else 36) / scale))
			button.add_theme_stylebox_override("normal", Style.box(Color.WHITE, palette.accent.lightened(0.65), ceili(8 / scale), 1))
			button.add_theme_stylebox_override("pressed", Style.box(palette.light.lightened(0.5), palette.accent, ceili(8 / scale), 2))
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				var surface: StyleBox = button.get_theme_stylebox(state)
				for edge in ["left", "right", "top", "bottom"]:
					surface.set("content_margin_" + edge, 6 / scale)


func _style_result_actions(accent: Color) -> void:
	_result_action_scale = Style.ui_scale(self)
	Style.action_button(_result_retry_button, accent, true)
	Style.prominent_action_button(_new_adventure_button, accent)
	Style.action_button(_result_board_button, accent)
	_result_board_button.add_theme_font_size_override("font_size", ceili(12 / _result_action_scale))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var surface: StyleBox = _result_board_button.get_theme_stylebox(state)
		surface.content_margin_left = 8 / _result_action_scale
		surface.content_margin_right = 8 / _result_action_scale


func _layout_result() -> void:
	if _outcome == null or _stage == null or _new_adventure_button == null:
		return
	var dimensions: Vector2 = _outcome.size
	var scale: float = Style.ui_scale(self)
	if not is_equal_approx(scale, _result_action_scale):
		_style_result_actions(_active_palette.get("accent", Style.GOOD))
	# Overlay actions never change the chest's framing, including during recovery.
	_stage.position = Vector2.ZERO
	_stage.size = dimensions
	var inset: float = 16 / scale
	var available_width: float = maxf(0.0, dimensions.x - inset * 2)
	_new_adventure_button.add_theme_font_size_override("font_size", ceili(20 / scale))
	for button in [_new_adventure_button, _result_retry_button]:
		var primary: bool = button == _new_adventure_button
		button.custom_minimum_size = Vector2(minf((240 if primary else 176) / scale, available_width), ceilf((56 if primary else 48) / scale))
		button.size = button.get_combined_minimum_size()
		button.position = dimensions - button.size - Vector2(inset, inset)
	_result_text.add_theme_constant_override("separation", ceili(4 / scale))
	_title.add_theme_font_size_override("font_size", ceili(22 / scale))
	_caption.add_theme_font_size_override("font_size", ceili(16 / scale))
	_result_text.position = Vector2(inset, inset)
	_result_text.size = Vector2(available_width, _result_text.get_combined_minimum_size().y)


func _can_request_hint() -> bool:
	if collection_page.visible or _leaderboard_overlay.visible:
		return false
	if _mode_id != "match" or model.hints_remaining <= 0 or not model.hint_ids.is_empty() or not model.error.is_empty():
		return false
	if model.phase == "feedback":
		return not _voice_mode and model.matched_ids.size() < model.cards.size()
	return model.phase in ["waiting", "matching"]


func _refresh_hint() -> void:
	hint_button.visible = _mode_id == "match" and model.phase in ["waiting", "matching", "feedback"]
	hint_button.disabled = not _can_request_hint()
	hint_button.focus_mode = Control.FOCUS_NONE if hint_button.disabled else Control.FOCUS_ALL
	hint_button.count = model.hints_remaining
	if model.hints_remaining <= 0:
		hint_button.tooltip_text = "No hints left. Start a new round for three more."
	elif model.phase == "won" or model.matched_ids.size() == model.cards.size():
		hint_button.tooltip_text = "Round finished. View your result."
	elif _voice_mode and model.phase == "feedback":
		hint_button.tooltip_text = "Finishing voice matches. Hints will be available afterward."
	elif not model.hint_ids.is_empty():
		hint_button.tooltip_text = "Hint active. Follow the electric link between the two matching cards."
	else:
		hint_button.tooltip_text = "%d %s left (Xbox X)" % [model.hints_remaining, "hint" if model.hints_remaining == 1 else "hints"]
	_set_accessibility_name(hint_button, hint_button.tooltip_text)


func _request_hint() -> void:
	if _mode_menu_open() or not _can_request_hint():
		return
	if model.phase == "feedback":
		_continue_match()
	if not model.request_hint():
		return
	duck.react("happy")
	audio.stop_pair_feedback()
	if not _voice_mode:
		audio.interact(model.theme_id)
		audio.cue("select")
		audio.say("res://" + model.card_by_id(model.hint_ids[0]).word.audio)
	var next_id: String = model.hint_ids[1] if model.selected_id == model.hint_ids[0] else model.hint_ids[0]
	cards[next_id].grab_focus()


func _select_card(id: String) -> void:
	if _mode_id != "match" or collection_page.visible or _leaderboard_overlay.visible or _mode_menu_open():
		return
	if not cards.has(id) or model.card_by_id(id).is_empty():
		return
	if model.matched_ids.has(id):
		if model.phase in ["waiting", "matching", "feedback"]:
			var word: Dictionary = model.card_by_id(id).word
			_hear_word(word)
			_match_connections.focus_pair(str(word.id))
			_refresh_match_cards()
			cards[id].play_press()
			cards[word.id + ":image"].play_word()
		return
	if model.phase == "feedback":
		if _voice_mode:
			return
		# The same tap acknowledges feedback and starts the next pair in place.
		_continue_match()
		if model.phase in ["waiting", "matching"]:
			cards[id].grab_focus()
	if not model.phase in ["waiting", "matching"]:
		return
	if not _voice_mode:
		audio.interact(model.theme_id)
	# Start the accepted tap's sound before the full board refresh and its
	# browser status updates. The model still validates every selection first.
	var result: String = model.select(id, false)
	if result == "ignored":
		return
	if result in ["selected", "reselected"]:
		audio.stop_pair_feedback()
		if not _voice_mode:
			audio.cue("select")
			audio.say("res://" + model.card_by_id(id).word.audio)
	if result in ["correct", "wrong"]:
		audio.stop_voice()
		if _voice_mode:
			audio.interact(model.theme_id, false)
		audio.play_pair_feedback(result == "correct")
		if result == "correct" and not _voice_mode:
			audio.say("res://" + model.card_by_id(id).word.audio)
	model.changed.emit()
	if result in ["selected", "reselected"] and not _voice_mode:
		duck.react("curious")
	elif result in ["correct", "wrong"]:
		_animate_feedback(model.feedback_ids, result == "correct")
		feedback_timer.start(VOICE_MATCH_SECONDS if _voice_mode else MATCH_FEEDBACK_SECONDS)
	cards[id].play_press()


func _resolve_feedback() -> void:
	feedback_timer.stop()
	feedback_timer.wait_time = MATCH_FEEDBACK_SECONDS
	# The board is ready before the reference clips finish; let their tails decay naturally.
	_clear_voice_match_feedback(false)
	_stop_feedback_animations()
	model.resolve_feedback()
	_consume_spoken_word()


func choose_theme(id: String) -> void:
	if (_save_error and not _pending_fragment.is_empty()) or not model.set_theme(id):
		return
	if _holding_chest:
		_cancel_chest_hold()
		_finish_chest_drag()
	_preferred_theme = id
	_save_journey()
	if collection_page.visible:
		_refresh_collection()
		_announce_collection_state()
	duck.react("happy")
	if not _voice_mode and not _pop_speech_active:
		audio.interact(model.theme_id)
		audio.cue("", model.theme_id + "-theme")


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if _host != null:
		_host.presentationSettings(value, audio.muted)
	for panel in [_leaderboard_panel, _pop_leaderboard]:
		if is_instance_valid(panel):
			panel.reduced_motion = value
			if value:
				panel.settle_animation()
	_hint_link.set_reduced_motion(value)
	_voice_match_link.set_reduced_motion(value)
	_pop.set_reduced_motion(value)
	_pop_rewards.set_reduced_motion(value)
	_memory.set_reduced_motion(value)
	_phrase.set_reduced_motion(value)
	for card in cards.values():
		card.set_reduced_motion(value)
	if duck != null:
		duck.set_reduced_motion(value)
	if _room != null:
		_room.set_reduced_motion(value)
	chest.reduced_motion = value
	if value:
		chest.stop_reaction()
		if _holding_chest:
			chest.begin_hold()
			chest.set_hold_progress(_hold_elapsed / HOLD_SECONDS)
		_stop_feedback_animations()
		chest.finish_immediately()
	if not data.words.is_empty():
		_refresh()


func _open_chest() -> void:
	if model.phase != "won" or model.chest_state != "closed":
		return
	if not _progress_ready:
		_progress_ready = medal_progress.load_progress()
		if not _progress_ready:
			_save_error = true
			_cancel_chest_hold()
			_refresh()
			return
	_pending_fragment = medal_progress.next_fragment(model.theme_id)
	if not medal_progress.error.is_empty():
		_save_error = true
		_cancel_chest_hold()
		_refresh()
		return
	var id: String = _pending_fragment.medal_id if not _pending_fragment.is_empty() else Data.medals(model.theme_id).back().id
	if not model.begin_open(id):
		_cancel_chest_hold()
		return
	_hold_elapsed = 0.0
	_chest_reward_announced = false
	if not _settling_chest:
		audio.interact(model.reward_theme)
	chest.start_open(reduced_motion or _settling_chest)
	if chest.mode == "opening":
		_publish_chest_charge(chest.performance_progress(), chest.performance_phase())


func _on_chest_cue(theme_id: String, cue: String, step: int) -> void:
	if audio == null or _settling_chest or _page_hidden or collection_page.visible or model.phase != "won":
		return
	var expected_theme: String = model.reward_theme if not model.reward_theme.is_empty() else model.theme_id
	if theme_id != expected_theme:
		return
	if cue in ["press", "hold_pulse"] and (not _holding_chest or model.chest_state != "closed"):
		return
	if cue == "charge_step" and not ((_holding_chest and model.chest_state == "closed") or model.chest_state == "opening"):
		return
	if cue in ["opening", "tension_pulse", "anticipation", "unlock", "release", "settle"] and model.chest_state != "opening":
		return
	audio.chest_cue(theme_id, cue, step)
	if _host != null:
		_host.chestCue(theme_id, cue, step)
	# ChestView owns the cavity-anchored flash on this exact release frame.
	# A second screen-centred celebration would produce a later visual climax.


func _on_chest_released() -> void:
	if model.chest_state != "opening" or not chest.opening_committed():
		return
	# Clear the gesture before disabling its button can emit button_up.
	_holding_chest = false
	_hold_elapsed = 0.0
	_hold_origin_frame = -1
	_finish_chest_drag()
	_refresh()


func _on_chest_opened() -> void:
	if chest.mode != "opened":
		return
	_holding_chest = false
	_hold_elapsed = 0.0
	_hold_origin_frame = -1
	_finish_chest_drag()
	if not model.finish_open():
		return
	if not _settling_chest and not _page_hidden and not collection_page.visible and chest.is_visible_in_tree():
		chest.show_surprise()
	# Physical completion stops the bed even if the following save fails.
	# The success accent remains gated by the separate persistence result.
	audio.finish_chest_motion()
	_publish_chest_charge()
	_commit_fragment()
	if _controller_mode and not _settling_chest and not _page_hidden \
		and not collection_page.visible and not _leaderboard_overlay.visible and not _mode_menu_open():
		_default_focus().grab_focus()


func _settle_released_chest() -> void:
	if model.chest_state != "opening" or not chest.opening_committed():
		return
	var was_settling: bool = _settling_chest
	_settling_chest = true
	audio.stop_chest_performance()
	chest.finish_immediately()
	_settling_chest = was_settling


func _commit_fragment(explicit_retry: bool = false) -> void:
	var before: Dictionary = medal_progress.counts.duplicate()
	if not _pending_fragment.is_empty() and not medal_progress.claim(_pending_fragment):
		_save_error = true
		_refresh()
		return
	_save_error = false
	if not _chest_reward_announced:
		_chest_reward_announced = true
		if not _settling_chest and not _page_hidden and not collection_page.visible:
			if explicit_retry:
				audio.interact(model.reward_theme)
			audio.chest_reward(model.reward_theme, explicit_retry)
	for item in playroom_state.toys():
		if not playroom_state.owned(item, before) and playroom_state.owned(item, medal_progress.counts):
			_unlocked_gift = item
			break
	_refresh_collection()
	_refresh()
	duck.react("happy")


func _retry_reward_save() -> void:
	if not _save_error or collection_page.visible:
		return
	if not _progress_ready:
		_progress_ready = medal_progress.load_progress()
		_save_error = not _progress_ready
		if _progress_ready:
			_build_collection()
		_refresh()
	else:
		_commit_fragment(true)
	if not _valid_focus(get_viewport().gui_get_focus_owner()):
		_default_focus().grab_focus()


func on_page_hidden() -> void:
	audio.stop_ui_click()
	_hide_mode_menu(false, false)
	if is_instance_valid(_leaderboard_scroll):
		_leaderboard_scroll.cancel_drag()
	if is_instance_valid(_pop_rewards):
		_pop_rewards.pause()
	if _speech_debug_active:
		_page_hidden = true
		audio.halt()
		audio.set_speech_debug_mix(1.0)
		return
	for panel in [_leaderboard_panel, _pop_leaderboard]:
		if is_instance_valid(panel):
			panel.settle_animation()
	if not _page_hidden:
		_resume_music_after_background = audio.active and audio.music.playing and not audio.muted
	_page_hidden = true
	chest.set_idle_paused(true)
	_hint_link.set_paused(true)
	if _mode_id == "pop":
		_pop.pause()
	_stop_pop_listening()
	_pointer_focus_active = false
	_proactive_touches.clear()
	_collection_multi_touch = false
	_cancel_collection_rails()
	_stop_voice()
	feedback_timer.paused = true
	_memory.pause(true)
	_pause_phrase()
	_stop_controller_actions()
	_stop_feedback_animations()
	_cancel_chest_hold()
	_settle_released_chest()
	_finish_chest_drag()
	_end_collection_drag()
	audio.halt()
	duck.settle()
	duck.set_idle_paused(true)
	_room.settle()
	_room.playground.pause(true)
	_memory.set_reduced_motion(true)
	_memory.set_reduced_motion(reduced_motion)
	chest.stop_reaction()


func on_page_visible() -> void:
	if _speech_debug_active:
		_page_hidden = false
		return
	var resume_music: bool = _page_hidden and _resume_music_after_background
	_page_hidden = false
	_resume_music_after_background = false
	if _pop_rewards_shown and not collection_page.visible:
		_pop_rewards.resume()
	chest.set_idle_paused(false)
	_refresh_hint_link()
	duck.set_idle_paused(false)
	_room.playground.pause(_age_catalog.visible)
	feedback_timer.paused = collection_page.visible
	_memory.pause(collection_page.visible)
	_resume_phrase()
	if resume_music:
		_restore_mode_music()


func _restore_mode_music() -> void:
	if _page_hidden or _voice_mode or _pop_speech_active:
		return
	if _mode_id == "pop" and not collection_page.visible:
		return
	# Resume the current room's music only. Interrupted words, quacks and reward
	# cues were cancelled on exit and must never replay when the page returns.
	audio.interact(model.theme_id)


func _notification(what: int) -> void:
	# Web focus/visibility is coordinated by the host; native desktop focus
	# loss must also cancel any unfinished chest gesture.
	var native_focus_out: bool = not OS.has_feature("web") and what == NOTIFICATION_APPLICATION_FOCUS_OUT
	var native_focus_in: bool = not OS.has_feature("web") and what == NOTIFICATION_APPLICATION_FOCUS_IN
	if (what == NOTIFICATION_APPLICATION_PAUSED or native_focus_out) and audio != null:
		on_page_hidden()
	elif (what == NOTIFICATION_APPLICATION_RESUMED or native_focus_in) and duck != null:
		on_page_visible()


func _observe_activity(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_proactive_touches[event.index] = true
		else:
			_proactive_touches.erase(event.index)
		if _proactive_touches.size() > 1:
			_collection_multi_touch = true
			_cancel_collection_rails()
		elif _proactive_touches.is_empty():
			_collection_multi_touch = false
	var meaningful: bool = false
	if event is InputEventMouseButton or event is InputEventKey or event is InputEventJoypadButton:
		meaningful = event.is_pressed() and not event.is_echo()
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		meaningful = true
	elif event is InputEventMouseMotion:
		meaningful = event.button_mask != 0 and event.relative != Vector2.ZERO
	elif event is InputEventJoypadMotion:
		meaningful = absf(event.axis_value) > 0.3
	if meaningful and duck != null:
		duck.note_activity()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer_focus_active = event.pressed and not event.canceled
	elif event is InputEventScreenTouch:
		_pointer_focus_active = event.pressed and not event.canceled
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_pointer_focus_active = false


func _input(event: InputEvent) -> void:
	if _mode_menu_open():
		if event.is_action_pressed("ui_cancel"):
			_mode_panel.close_button.pressed.emit()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			get_viewport().set_input_as_handled()
			return
	# Handle mapped controller events before GUI defaults can activate or move focus.
	if event is InputEventJoypadButton:
		if event.pressed:
			_enter_controller_mode()
		if event.button_index == JOY_BUTTON_A:
			if event.pressed:
				if not _controller_accept_needs_release:
					_controller_accept()
			elif _controller_holding_chest:
				_controller_accept_needs_release = false
				_controller_holding_chest = false
				_end_chest_hold()
			elif _controller_holding_pop_chest:
				_controller_accept_needs_release = false
				_controller_holding_pop_chest = false
				_pop_rewards.end_hold()
			elif _controller_peeking:
				_controller_accept_needs_release = false
				_controller_peeking = false
				_memory.end_peek()
			else:
				_controller_accept_needs_release = false
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == JOY_BUTTON_B:
			_controller_back()
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == JOY_BUTTON_X:
			_request_hint()
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [JOY_BUTTON_Y, JOY_BUTTON_START]:
			_toggle_collection()
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			_cycle_theme(-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
			get_viewport().set_input_as_handled()
		elif event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			_controller_dpad = Vector2(
				int(Input.is_joy_button_pressed(event.device, JOY_BUTTON_DPAD_RIGHT)) - int(Input.is_joy_button_pressed(event.device, JOY_BUTTON_DPAD_LEFT)),
				int(Input.is_joy_button_pressed(event.device, JOY_BUTTON_DPAD_DOWN)) - int(Input.is_joy_button_pressed(event.device, JOY_BUTTON_DPAD_UP)))
			_update_controller_navigation()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		_enter_controller_mode()
		if event.axis == JOY_AXIS_LEFT_X:
			_controller_stick.x = event.axis_value
		else:
			_controller_stick.y = event.axis_value
		_update_controller_navigation()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_controller_back()


func _enter_controller_mode() -> void:
	_controller_mode = true
	if not _valid_focus(get_viewport().gui_get_focus_owner()):
		_default_focus().grab_focus()


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if not connected:
		_stop_controller_actions()
		if Input.get_connected_joypads().is_empty():
			_controller_mode = false


func _stop_controller_actions() -> void:
	_controller_stick = Vector2.ZERO
	_controller_dpad = Vector2.ZERO
	_controller_last_direction = Vector2.ZERO
	_controller_repeat_elapsed = 0.0
	if _controller_holding_chest:
		_controller_holding_chest = false
		_cancel_chest_hold()
		_finish_chest_drag()
	if _controller_holding_pop_chest:
		_controller_holding_pop_chest = false
		_pop_rewards.cancel_input()
	if _controller_peeking:
		_controller_peeking = false
		_memory.end_peek()
	_controller_accept_needs_release = _controller_accept_is_pressed()


func _controller_accept_is_pressed() -> bool:
	if _host != null:
		# The Web controller's first native sample can arrive after the scene starts.
		return bool(_host.controllerAcceptHeld())
	var devices: Array = Input.get_connected_joypads()
	if not devices.has(0):
		devices.append(0)
	for device in devices:
		if Input.is_joy_button_pressed(int(device), JOY_BUTTON_A):
			return true
	return false


func _sync_controller_accept_startup() -> void:
	await get_tree().process_frame
	_controller_accept_needs_release = _controller_accept_is_pressed()


func _controller_accept() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if _pop_rewards_shown and _mode_id == "pop" and _valid_focus(focused) and _pop_rewards.is_chest_control(focused):
		_controller_holding_pop_chest = true
		_pop_rewards.begin_hold(focused)
		return
	if _mode_id == "memory" and focused == _memory.study_button and _valid_focus(focused):
		_memory.begin_peek()
		_controller_peeking = _memory.memory.studying
		return
	if focused == chest_button and model.phase == "won" and model.chest_state == "closed":
		_controller_holding_chest = true
		_start_chest_hold()
		return
	if _valid_focus(focused) and focused is Button:
		(focused as Button).pressed.emit()
	else:
		_default_focus().grab_focus()


func _controller_back() -> void:
	if _mode_menu_open():
		_mode_panel.close_button.pressed.emit()
		return
	if _leaderboard_overlay.visible:
		_back_from_leaderboard(true)
		return
	if _controller_holding_pop_chest:
		_controller_holding_pop_chest = false
		_pop_rewards.cancel_input()
		_controller_accept_needs_release = _controller_accept_is_pressed()
		return
	if _holding_chest:
		_cancel_chest_hold()
		_finish_chest_drag()
		_controller_holding_chest = false
		_controller_accept_needs_release = _controller_accept_is_pressed()
		return
	if collection_page.visible:
		_collection_back.pressed.emit()
	elif _voice_mode:
		_play_ui_click()
		_stop_voice()
	elif _mode_id == "pop":
		if _pop_rewards_shown:
			_pop_rewards._back.pressed.emit()
		else:
			_play_ui_click()
			choose_mode("match")
	elif _mode_id == "match" and model.phase == "feedback":
		_continue_match()
	elif _mode_id == "memory":
		if _memory.memory.studying:
			_controller_peeking = false
			_memory.end_peek()
		elif _memory.memory.phase == "matching" and not _memory.memory.selected_indices.is_empty():
			_memory.card_buttons[_memory.memory.selected_indices[0]].pressed.emit()
	elif model.phase == "matching" and not model.selected_id.is_empty():
		model.select(model.selected_id)


func _toggle_collection() -> void:
	if _pop_picker_open():
		collection_button.pressed.emit()
		return
	if _leaderboard_overlay.visible:
		_back_from_leaderboard(true)
		return
	if collection_page.visible:
		_collection_back.pressed.emit()
	else:
		collection_button.pressed.emit()


func _cycle_theme(step: int) -> void:
	if _leaderboard_overlay.visible or model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty()):
		return
	var index: int = Model.THEMES.find(model.theme_id)
	if index < 0:
		index = 0
	_play_ui_click()
	choose_theme(Model.THEMES[posmod(index + step, Model.THEMES.size())])


func _update_controller_navigation() -> void:
	var direction := Vector2.ZERO
	var movement: Vector2 = _controller_dpad if _controller_dpad != Vector2.ZERO else _controller_stick
	if absf(movement.x) >= 0.55 or absf(movement.y) >= 0.55:
		if absf(movement.x) > absf(movement.y):
			direction = Vector2.RIGHT if movement.x > 0.0 else Vector2.LEFT
		else:
			direction = Vector2.DOWN if movement.y > 0.0 else Vector2.UP
	if direction == Vector2.ZERO:
		_controller_last_direction = Vector2.ZERO
		_controller_repeat_elapsed = 0.0
	elif direction != _controller_last_direction:
		_controller_last_direction = direction
		_controller_repeat_elapsed = 0.0
		_move_focus(direction)


func _move_focus(direction: Vector2) -> void:
	var candidates: Array[Control] = _focus_candidates()
	if candidates.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner()
	if not candidates.has(current):
		candidates[0].grab_focus()
		return
	var side: int = SIDE_LEFT if direction == Vector2.LEFT else SIDE_RIGHT if direction == Vector2.RIGHT else SIDE_TOP if direction == Vector2.UP else SIDE_BOTTOM
	var neighbor_path: NodePath = current.get_focus_neighbor(side)
	if not neighbor_path.is_empty():
		var neighbor := current.get_node_or_null(neighbor_path) as Control
		if candidates.has(neighbor):
			neighbor.grab_focus()
			return
	var current_center: Vector2 = _focus_center(current)
	var best: Control = null
	var best_score := INF
	for candidate in candidates:
		if candidate == current:
			continue
		var delta: Vector2 = _focus_center(candidate) - current_center
		if delta.dot(direction) <= 1.0:
			continue
		var score: float = absf(delta.cross(direction)) * 4.0 + delta.length()
		if score < best_score:
			best_score = score
			best = candidate
	if best != null:
		best.grab_focus()


func _focus_center(control: Control) -> Vector2:
	var center: Vector2 = control.get_global_rect().get_center()
	if collection_page.visible:
		for rail in _collection_rails():
			if rail.is_ancestor_of(control):
				center.x += rail.scroll_horizontal
				break
	return center


func _focus_candidates() -> Array[Control]:
	var result: Array[Control] = []
	for node in find_children("*", "Control", true, false):
		var control := node as Control
		if _valid_focus(control):
			result.append(control)
	result.sort_custom(func(a: Control, b: Control) -> bool:
		var ac := _focus_center(a)
		var bc := _focus_center(b)
		return ac.y < bc.y if not is_equal_approx(ac.y, bc.y) else ac.x < bc.x
	)
	return result


func _valid_focus(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE \
		or (control is Button and (control as Button).disabled):
		return false
	if _mode_menu_open():
		return _mode_panel.is_ancestor_of(control)
	if is_instance_valid(_leaderboard_overlay) and _leaderboard_overlay.visible and not _leaderboard_overlay.is_ancestor_of(control):
		return _pop_picker_open() and control in [duck, collection_button, _mode_heading_button]
	if collection_page.visible and not _leaderboard_overlay.visible and is_instance_valid(control) and control != duck and not collection_page.is_ancestor_of(control):
		return false
	return true


func _default_focus() -> Control:
	if _mode_menu_open():
		return _mode_buttons[MODES.keys().find(_mode_id)]
	if _leaderboard_overlay.visible:
		if not _leaderboard_close.visible:
			for candidate in _leaderboard_panel.controls():
				if _valid_focus(candidate):
					return candidate
		return _leaderboard_close
	if collection_page.visible:
		return _collection_back
	if _mode_id == "pop" and _pop_rewards_shown:
		for control in _pop_rewards.navigation_controls():
			if _valid_focus(control):
				return control
		return collection_button
	if model.phase == "won":
		if _valid_focus(chest_button):
			return chest_button
		if _valid_focus(_result_retry_button):
			return _result_retry_button
		return _new_adventure_button if _valid_focus(_new_adventure_button) else collection_button
	if _mode_id == "pop":
		var pop_focus: Control = _pop.default_focus()
		return pop_focus if _valid_focus(pop_focus) else collection_button
	if _mode_id == "memory":
		if _memory.memory.studying:
			return _memory.study_button
		var memory_controls: Array[Control] = _memory.controls()
		return memory_controls[0] if not memory_controls.is_empty() else collection_button
	if _mode_id == "phrase":
		var phrase_focus: Control = _phrase.default_focus()
		return phrase_focus if _valid_focus(phrase_focus) else collection_button
	for kind in ["image", "word"]:
		for card in model.cards:
			if card.kind == kind and not model.matched_ids.has(card.id) and _valid_focus(cards[card.id]):
				return cards[card.id]
	return collection_button


func _ensure_collection_focus_visible(control: Control) -> void:
	if collection_page.visible and not _collection_dragging and not _pointer_focus_active:
		var target: Control = control.get_parent() if control == _room.goal_button and control.get_parent() is Button else control
		if control == duck:
			# Keep tracking the focused duck while revealing its fixed input slot.
			target = _collection_duck_slot
		_reveal_room_control(target, true)
		# Goal text and room controls can settle over multiple container passes.
		for frame in range(3):
			await get_tree().process_frame
			if not is_instance_valid(control) or get_viewport().gui_get_focus_owner() != control or not collection_page.visible or _collection_dragging or _pointer_focus_active:
				return
			if target != control and control.get_parent() != target:
				return
			_reveal_room_control(target)


func _reveal_room_control(target: Control, explicit_focus: bool = false) -> void:
	for rail in _collection_rails():
		if not rail.is_ancestor_of(target):
			continue
		if rail.is_pointer_active() or (rail.is_scrolling() and not explicit_focus):
			return
		if explicit_focus:
			rail.cancel_drag()
		rail.ensure_control_visible(target)
		return


func _audio_status(message: String) -> void:
	if _host != null:
		_host.audioStatus(message)


func _announce_status(message: String) -> void:
	_status_announcement = message
	if _host != null:
		_host.announce(message)


func _show_error(message: String) -> void:
	_memory.hide()
	_phrase.hide()
	_pop.hide()
	_outcome.hide()
	_match_playfield.show()
	grid.hide()
	_refresh_hint_link()
	for button in theme_buttons + _mode_buttons + [hint_button, _voice_button, collection_button]:
		button.disabled = true
		button.focus_mode = Control.FOCUS_NONE
	_message.text = message
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.show()
	_message.add_theme_color_override("font_color", Style.WRONG)
	if OS.has_feature("web"):
		var host: JavaScriptObject = JavaScriptBridge.get_interface("wordBuddiesHost")
		if host != null:
			host.fail(message)


func _connect_browser() -> void:
	if not OS.has_feature("web"):
		return
	_host = JavaScriptBridge.get_interface("wordBuddiesHost")
	if _host == null:
		return
	_hidden_callback = JavaScriptBridge.create_callback(func(_arguments: Array) -> void: on_page_hidden())
	_visible_callback = JavaScriptBridge.create_callback(func(_arguments: Array) -> void: on_page_visible())
	_motion_callback = JavaScriptBridge.create_callback(func(arguments: Array) -> void:
		if not _presentation.has_motion_override:
			set_reduced_motion(bool(arguments[0])))
	_input_cancel_callback = JavaScriptBridge.create_callback(_on_input_canceled)
	_pointer_release_callback = JavaScriptBridge.create_callback(func(arguments: Array) -> void:
		_memory.release_peek_pointer(int(arguments[0]))
		_phrase.release_pointer(int(arguments[0])))
	_host.observe(_hidden_callback, _motion_callback, _visible_callback, _input_cancel_callback, _pointer_release_callback)
	_host.presentationSettings(reduced_motion, audio.muted)
	_speech_result_callback = JavaScriptBridge.create_callback(_on_voice_result)
	_speech_state_callback = JavaScriptBridge.create_callback(_on_voice_state)
	_host.observeSpeech(_speech_result_callback, _speech_state_callback)
	_host.configureSpeechLexicon(JSON.stringify(SpeechWords.browser_lexicon(data.words)))
	_speech_debug_callback = JavaScriptBridge.create_callback(_dispatch_speech_debug)
	_host.observeSpeechDebug(_speech_debug_callback)
	_pop_result_callback = JavaScriptBridge.create_callback(_dispatch_pop_speech)
	_host.observePopSpeech(_pop_result_callback)


func _dispatch_pop_speech(arguments: Array) -> void:
	if arguments.size() != 2 or not arguments[0] is String or not arguments[1] is JavaScriptObject:
		return
	var receipt: JavaScriptObject = arguments[1]
	receipt.accepted = _accept_pop_speech(arguments[0])


func _accept_pop_speech(json: String) -> bool:
	if _speech_debug_active or _mode_id != "pop" or not _pop_speech_active \
		or collection_page.visible or _leaderboard_overlay.visible or _page_hidden:
		return false
	return _pop.receive_speech_event(json)


func _dispatch_speech_debug(arguments: Array) -> void:
	if arguments.size() != 3 or not arguments[2] is JavaScriptObject:
		return
	# JavaScriptBridge callbacks discard the Callable return value. An
	# explicit response object acknowledges the action in this same call.
	var reply: JavaScriptObject = arguments[2]
	reply.accepted = _on_speech_debug(arguments.slice(0, 2))


func _on_speech_debug(arguments: Array) -> bool:
	if arguments.is_empty() or not arguments[0] is String:
		return false
	var action: String = arguments[0]
	if action == "open":
		return _open_speech_debug()
	if action == "close":
		# The diagnostic DOM listener can run before the host's hidden callback.
		# Mark background exit first so closing never requests hidden playback.
		if _speech_debug_active and arguments.size() == 2 and arguments[1] is bool and arguments[1]:
			_page_hidden = true
		return _close_speech_debug()
	if not _speech_debug_active or _page_hidden or arguments.size() != 2:
		return false
	if action == "mix" and (arguments[1] is float or arguments[1] is int):
		return audio.set_speech_debug_mix(float(arguments[1]))
	if action != "cue" or not arguments[1] is String or arguments[1] not in ["launch", "slice", "miss", "match", "stop"]:
		return false
	if arguments[1] == "stop":
		audio.stop_pop_sounds()
		audio.stop_pair_feedback()
		audio.stop_pip_reaction()
		return true
	audio.interact(model.theme_id, false)
	match arguments[1]:
		"launch": audio.cue("pop-launch")
		"slice": audio.cue("pop-slice")
		"miss":
			if _mode_id == "pop":
				audio.play_pip_reaction(false)
			else:
				audio.play_pair_feedback(false)
		"match": audio.play_pair_feedback(true)
	return true


func _open_speech_debug() -> bool:
	if _speech_debug_active:
		return not _page_hidden
	if _page_hidden or (OS.has_feature("web") and not _loading_revealed) \
		or _holding_chest or model.chest_state == "opening" or _save_error or not _pending_fragment.is_empty():
		return false
	# Stop the old recognizer before freezing the scene. A failed microphone
	# stop must never overlap the isolated diagnostic recognizer.
	if _mode_id == "pop":
		# Do not catch up a nearly expired round into scoring or a report as
		# a side effect of opening an unscored diagnostic session.
		_pop._listening_tick_usec = -1
	if _host != null and not bool(_host.stopSpeech()):
		return false
	if not _stop_pop_listening():
		return false
	_stop_voice()
	if _mode_id == "pop":
		_pop.pause()
	_on_input_canceled()
	_stop_controller_actions()
	audio.halt()
	duck.settle()
	_speech_debug_tree_paused = get_tree().paused
	_speech_debug_audio_process_mode = audio.process_mode
	_speech_debug_active = true
	_pause_phrase()
	audio.set_speech_debug_mix(1.0)
	# Freeze gameplay, controller input and timers while real sound assets
	# remain available to the isolated browser diagnostic controls.
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	return true


func _close_speech_debug(restore_audio: bool = true) -> bool:
	if not _speech_debug_active:
		return true
	audio.halt()
	audio.set_speech_debug_mix(1.0)
	audio.process_mode = _speech_debug_audio_process_mode
	_speech_debug_active = false
	get_tree().paused = _speech_debug_tree_paused
	if restore_audio and _page_hidden:
		on_page_hidden()
		_resume_music_after_background = _mode_id != "pop" or collection_page.visible
	elif restore_audio:
		_resume_phrase()
		_restore_mode_music()
	return true


func _exit_tree() -> void:
	_close_speech_debug(false)


func _on_input_canceled(_arguments: Array = []) -> void:
	_mode_menu_pointer = -2
	_proactive_touches.clear()
	_pointer_focus_active = false
	_leaderboard_scroll.cancel_drag()
	_cancel_chest_hold()
	_finish_chest_drag()
	_pop_rewards.cancel_input()
	duck.note_activity()
	_pop.cancel_result_input()
	_memory.end_peek()
	_phrase.cancel_input()
	_room.playground.cancel()
	_cancel_collection_rails()
	_end_collection_drag()


func _toggle_voice() -> void:
	if _mode_id != "match" or collection_page.visible or _leaderboard_overlay.visible:
		return
	if _voice_mode:
		_stop_voice()
		_restore_mode_music()
	elif _host != null and bool(_host.speechAvailable()) and model.phase in ["waiting", "matching", "feedback"]:
		_voice_mode = true
		_voice_space.show()
		_refresh_match_cards()
		_layout()
		audio.halt()
		_sync_voice_bounds()
		_host.speechMode(true)
	_voice_button.grab_focus()


func _sync_voice_bounds() -> void:
	if _host == null or not _voice_mode or _voice_space == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var bounds: Rect2 = _voice_space.get_global_rect()
	_host.speechBounds(bounds.position.x / viewport_size.x, bounds.position.y / viewport_size.y,
		bounds.size.x / viewport_size.x, bounds.size.y / viewport_size.y)


func _on_voice_state(arguments: Array) -> void:
	if _speech_debug_active or _mode_menu_open():
		return
	if _mode_id == "pop":
		if _pop_player_id.is_empty() or _leaderboard_overlay.visible:
			return
		_pop.set_listening(bool(arguments[0]), bool(arguments[1]), str(arguments[2]))
		# Recognition rolls over after an utterance. Let that word's short
		# emotion finish while the recognizer reconnects automatically.
		if not bool(arguments[1]) and not _pop._reconnecting:
			audio.stop_pop_sounds()
			audio.stop_pip_reaction()
			duck.settle()
		return
	var enabled: bool = bool(arguments[0])
	if enabled and model.phase == "won":
		_stop_voice()
		return
	var layout_changed: bool = _voice_mode != enabled
	_voice_mode = enabled
	_voice_listening = enabled and bool(arguments[1])
	_voice_button.button_pressed = enabled
	_voice_button.engaged = _voice_listening
	_voice_space.visible = enabled
	if layout_changed:
		_refresh_match_cards()
		_layout()
	if enabled:
		# Automatic recognizer rollover must not cut off the current answer sound.
		audio.halt(audio.pair_feedback.playing)
	else:
		_clear_voice_match_feedback()
		_speech_queue.clear()
		if layout_changed:
			_restore_mode_music()
		if model.phase == "feedback":
			feedback_timer.start(MATCH_FEEDBACK_SECONDS)
	if model.phase in ["waiting", "matching", "feedback"] and not str(arguments[2]).is_empty():
		_announce_status(str(arguments[2]))
	elif layout_changed and not enabled and model.phase in ["waiting", "matching", "feedback"]:
		_announce_status("Voice off. " + _message.text)
	_sync_voice_bounds()


func _on_voice_result(arguments: Array) -> void:
	if _speech_debug_active or _mode_menu_open() or arguments.size() < 2:
		return
	if _mode_id == "pop":
		if not collection_page.visible:
			_pop.show_transcript(str(arguments[0]), bool(arguments[1]))
		return
	if _mode_id != "match":
		return
	if not _voice_mode or not _voice_listening or not bool(arguments[1]):
		return
	for id in model.spoken_matches(str(arguments[0])):
		if not _speech_queue.has(id):
			_speech_queue.append(id)
	_consume_spoken_word()


func _consume_spoken_word() -> void:
	if not _voice_mode or not model.phase in ["waiting", "matching"]:
		return
	while not _speech_queue.is_empty():
		var id: String = _speech_queue.pop_front()
		if model.match_spoken_word(id) == "correct":
			_animate_feedback(model.feedback_ids, true)
			_start_voice_match_feedback(model.feedback_ids)
			feedback_timer.start(VOICE_MATCH_SECONDS)
			return


func _stop_voice() -> void:
	_clear_voice_match_feedback()
	var was_enabled: bool = _voice_mode
	_voice_mode = false
	_voice_listening = false
	_speech_queue.clear()
	if was_enabled and feedback_timer != null and model.phase == "feedback":
		feedback_timer.start(MATCH_FEEDBACK_SECONDS)
	if _voice_space != null:
		_voice_space.hide()
	if _voice_button != null:
		_voice_button.button_pressed = false
		_voice_button.engaged = false
	if was_enabled:
		_refresh_match_cards()
		_layout()
	if was_enabled and _host != null:
		_host.stopSpeech()
	if was_enabled and not _voice_mode and model.phase in ["waiting", "matching", "feedback"]:
		_announce_status("Voice off. " + _message.text)


func _animate_feedback(ids: Array[String], correct: bool) -> void:
	_stop_feedback_animations()
	_react_to_gameplay(correct)
	if correct:
		for id in ids:
			cards[id].play_word()
	if reduced_motion:
		return
	for id in ids:
		var card: Button = cards[id]
		if correct:
			var tween := create_tween()
			_feedback_tweens.append(tween)
			var sparkle := RewardSparkle.new()
			sparkle.name = "MatchSparkle"
			sparkle.accent = Data.theme(model.theme_id).accent
			sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(sparkle)
			sparkle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_feedback_sparkles.append(sparkle)
			tween.tween_method(sparkle.set_progress, 0.0, 1.0, 0.45)
			tween.finished.connect(sparkle.queue_free)


func _stop_feedback_animations() -> void:
	for card in cards.values():
		card.stop_word_play()
		card.stop_press()
	for tween in _feedback_tweens:
		tween.kill()
	_feedback_tweens.clear()
	for sparkle in _feedback_sparkles:
		if is_instance_valid(sparkle):
			sparkle.hide()
			sparkle.queue_free()
	_feedback_sparkles.clear()


func _start_chest_hold() -> void:
	if _leaderboard_overlay.visible:
		return
	if _holding_chest or _page_hidden or collection_page.visible or _save_error \
		or model.phase != "won" or model.chest_state != "closed":
		return
	_holding_chest = true
	_hold_elapsed = 0.0
	_hold_origin_frame = Engine.get_process_frames()
	_drag_distance = 0.0
	_dragging_chest = true
	_drag_has_anchor = false
	audio.interact(model.theme_id)
	audio.stop_voice()
	audio.prepare_chest(model.theme_id)
	chest.begin_hold()
	audio.set_chest_charge(0.0)
	_publish_chest_charge(0.0)
	set_process(true)


func _end_chest_hold() -> void:
	if _holding_chest:
		_cancel_chest_hold(true)
	_finish_chest_drag()


func _cancel_chest_hold(animate_return: bool = false) -> void:
	var was_holding: bool = _holding_chest
	_holding_chest = false
	_hold_elapsed = 0.0
	_hold_origin_frame = -1
	var was_opening: bool = model.chest_state == "opening"
	if was_opening and chest != null and chest.opening_committed():
		# The visible release completes input. Its motion, light and sounds
		# continue even if a pointer/key is released or a controller disconnects.
		_finish_chest_drag()
		return
	if chest != null:
		if was_opening:
			chest.cancel_open(animate_return)
		elif animate_return:
			chest.cancel_hold()
		else:
			chest.set_hold_progress(0.0)
	# Inactive Match cleanup must leave a committed Voice Pop opening audible.
	if audio != null and (_mode_id == "match" or was_holding or was_opening):
		if animate_return:
			audio.stop_chest_charge()
		else:
			audio.stop_chest_performance()
	if was_opening:
		_pending_fragment.clear()
		_chest_reward_announced = false
		model.cancel_open()
	_publish_chest_charge()


func _publish_chest_charge(progress: float = -1.0, phase: String = "holding") -> void:
	# Expose real progress without flooding screen readers with live announcements.
	var percent: int = int(floorf(clampf(progress, 0.0, 1.0) * 20.0)) * 5 if progress >= 0.0 else -1
	if progress < 0.0:
		phase = "idle"
	if percent == _chest_announced_percent and phase == _chest_announced_phase:
		return
	_chest_announced_percent = percent
	_chest_announced_phase = phase
	if _host != null:
		_host.chestProgress(percent, phase)


func _finish_chest_drag() -> void:
	_dragging_chest = false
	_drag_has_anchor = false
	_drag_anchor_position = Vector2.ZERO
	_drag_anchor_offset = Vector2.ZERO


func _process(delta: float) -> void:
	# Input may start a hold in this frame; delta includes time from before
	# that press. Start counting on the next frame without delaying its pose.
	var hold_delta: float = 0.0 if Engine.get_process_frames() == _hold_origin_frame else delta
	_advance_ui(delta, hold_delta)


func _advance_ui(delta: float, hold_delta: float = -1.0) -> void:
	_leaderboard_publish_left -= delta
	if _leaderboard_publish_left <= 0.0:
		_leaderboard_publish_left = 0.1
		_publish_leaderboards()
	_update_duck()
	if Engine.get_process_frames() != _voice_match_origin_frame:
		_advance_voice_match_feedback(delta)
	var elapsed: float = delta if hold_delta < 0.0 else hold_delta
	if _holding_chest and model.chest_state == "closed" and elapsed > 0.0 and is_finite(elapsed):
		_hold_elapsed += elapsed
		var progress: float = clampf(_hold_elapsed / HOLD_SECONDS, 0.0, 1.0)
		chest.set_hold_progress(progress)
		audio.set_chest_charge(progress)
		_publish_chest_charge(chest.performance_progress())
		if progress >= 1.0:
			_open_chest()
	if model.chest_state == "opening" and chest.mode == "opening" and not _page_hidden and not collection_page.visible:
		var phase: String = chest.performance_phase()
		if phase == "release":
			# A stalled frame may consume the release cue without playing its
			# stale accent. Physical release must still end the pressure bed.
			audio.stop_chest_charge()
		else:
			audio.set_chest_tension(chest.tension_progress())
		_publish_chest_charge(chest.performance_progress(), phase)
	if _controller_last_direction != Vector2.ZERO:
		_controller_repeat_elapsed += delta
		if _controller_repeat_elapsed >= 0.34:
			_controller_repeat_elapsed = 0.18
			_move_focus(_controller_last_direction)


func _chest_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_chest_hold()
		else:
			_end_chest_hold()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_chest_hold()
		else:
			_end_chest_hold()
		return
	if not _dragging_chest:
		return
	var relative := Vector2.ZERO
	var position := Vector2.ZERO
	if event is InputEventMouseMotion:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		relative = event.relative
		position = event.position
	elif event is InputEventScreenDrag:
		relative = event.relative
		position = event.position
	else:
		return
	if relative == Vector2.ZERO and (not _drag_has_anchor or position == _drag_anchor_position):
		return
	if not _drag_has_anchor:
		_drag_anchor_position = position - relative
		_drag_anchor_offset = chest.drag_offset
		_drag_has_anchor = true
	var displacement: Vector2 = position - _drag_anchor_position
	_drag_distance = maxf(_drag_distance, displacement.length())
	if _drag_distance > 10.0:
		if _holding_chest:
			_cancel_chest_hold(true)
	chest.set_drag_offset(_drag_anchor_offset + displacement)


func _new_adventure() -> void:
	if collection_page.visible or model.phase != "won" or model.chest_state != "opened" or _save_error:
		return
	if not _pending_fragment.is_empty() and medal_progress.count_for(_pending_fragment.medal_id) < int(_pending_fragment.after):
		return
	if new_round(-1, false, "", "phrase" if _mode_id == "phrase" else "match"):
		_default_focus().grab_focus()
		if _mode_id == "phrase":
			_start_phrase_prompt()


func _start_gift_adventure(id: String) -> void:
	if not collection_page.visible or _collection_dragged:
		return
	var gift: Dictionary = playroom_state.item(id)
	if gift.is_empty() or gift.slot != "toy" or str(gift.theme).is_empty():
		return
	if playroom_state.owned(gift, medal_progress.counts):
		_select_room_item(id)
		return
	if not _progress_ready or (_save_error and not _pending_fragment.is_empty()):
		var message := "Your progress is waiting. Use Back, then Retry saving before a new adventure."
		_room.show_item_error(id, "Save your reward first", message)
		_announce_status(message)
		return
	if model.chest_state == "opening" or (model.phase == "won" and model.chest_state != "opened"):
		var message := "Your chest is waiting! Use Back and open it before a new adventure."
		_room.show_item_error(id, "Open your chest first", message)
		_announce_status(message)
		return
	if not _ensure_playroom_loaded() or not playroom_state.set_goal(id, medal_progress.counts):
		var message := "Your gift goal could not be saved. Press the gift button to retry."
		_room.show_item_error(id, "Not saved\nTap arrow to retry", message)
		_announce_status(message)
		return
	var topics := {"spring": "great-outdoors", "summer": "play-time", "autumn": "picnic-time", "winter": "music-makers", "ocean": "ocean-discovery", "space": "space-trip", "jungle": "animal-friends", "candy": "picnic-time"}
	_preferred_theme = gift.theme
	_hide_collection()
	if not new_round(-1, false, topics[gift.theme], "match", gift.word_id):
		return
	_default_focus().grab_focus()
	_announce_status("%s. Find %d word–picture pairs. Help Pip get %s. Win games in %s and open their chests." % [model.adventure_name, Model.MATCH_PAIR_COUNT, gift.name, Data.theme(gift.theme).name])


func _save_journey() -> void:
	_journey_save_failed = not _ensure_playroom_loaded()
	if not _journey_save_failed and not _preferred_theme.is_empty():
		_journey_save_failed = not playroom_state.prefer_theme(_preferred_theme)
	if not _journey_save_failed and not _pending_visit_id.is_empty():
		_journey_save_failed = not playroom_state.remember_visit(_pending_visit_id)
		if not _journey_save_failed:
			_pending_visit_id = ""
	_refresh()


func _retry_storage() -> void:
	if collection_page.visible:
		return
	if _save_error:
		_retry_reward_save()
	if _journey_save_failed:
		_save_journey()
	if not _valid_focus(get_viewport().gui_get_focus_owner()):
		_default_focus().grab_focus()


func _show_collection() -> void:
	var from_picker: bool = _pop_picker_open()
	if _leaderboard_overlay.visible and not from_picker:
		return
	if from_picker:
		_hide_leaderboard()
	_hide_mode_menu(false, false)
	if _mode_id == "pop":
		_pop.pause()
		_pop_rewards.pause()
		_pop_rewards.hide()
		audio.stop_pop_sounds()
	if not _stop_pop_listening():
		return
	if _mode_id == "pop":
		_pop.hide()
	_focus_before_collection = get_viewport().gui_get_focus_owner()
	audio.stop_voice()
	audio.stop_pip_reaction()
	duck.settle()
	_collection_scroll.scroll_vertical = 0
	_cancel_collection_rails()
	_stop_voice()
	feedback_timer.paused = true
	_stop_feedback_animations()
	_cancel_chest_hold()
	_settle_released_chest()
	_finish_chest_drag()
	_end_collection_drag()
	_collection_dragged = false
	_refresh_favorite_reward()
	_refresh_collection()
	_collection_focus_modes.clear()
	for node in find_children("*", "Control", true, false):
		var control := node as Control
		if control != duck and not collection_page.is_ancestor_of(control):
			_collection_focus_modes[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
	_return_to_pop_picker = from_picker
	collection_page.show()
	_hint_link.set_paused(true)
	_memory.pause(true)
	_pause_phrase()
	_collection_back.grab_focus()
	_update_duck()
	duck.react("happy")
	_announce_collection_state()


func _hide_collection() -> void:
	var restore_picker: bool = _return_to_pop_picker
	_return_to_pop_picker = false
	_hide_age_catalog()
	audio.stop_voice()
	audio.stop_pip_reaction()
	duck.settle()
	_cancel_collection_rails()
	_end_collection_drag()
	_collection_dragged = false
	collection_page.hide()
	duck.clear_trick()
	for control in _collection_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = _collection_focus_modes[control]
	_collection_focus_modes.clear()
	# Closing one overlay must not release a separate background pause.
	feedback_timer.paused = _page_hidden
	_memory.pause(_page_hidden)
	if _mode_id == "pop" and not _pop_player_id.is_empty():
		leaderboard_state.load_state()
		_reconcile_round_identity()
	if _mode_id == "pop" and _pop.game.phase == "finished" and is_instance_valid(_pop_leaderboard):
		_pop_leaderboard.refresh_profiles()
	_refresh()
	if _mode_id == "pop" and _pop_rewards_shown and not _page_hidden:
		_pop_rewards.resume()
	if _valid_focus(_focus_before_collection):
		_focus_before_collection.grab_focus()
	else:
		_default_focus().grab_focus()
	if restore_picker and _mode_id == "pop" and not _pop_rewards.has_pending() \
			and (_pop_player_id.is_empty() or _pop.game.phase == "finished"):
		_request_pop_player()
		if _pop_picker_open():
			return
	_announce_status(_message.text if model.phase in ["waiting", "matching", "feedback"] else _title.text + " " + _caption.text)


func _announce_collection_state() -> void:
	if _age_catalog.visible:
		var message: String = "%s. %d words. Tap a picture to hear its word. Back returns to Pip's room." % [
			_age_catalog.title_label.text, _age_catalog.word_count()]
		if _age_save_failed:
			message += " " + _age_notice.text
		_announce_status(message)
		return
	var message: String = "Pip's room opened. %d toys in Pip's home. %d toys to unlock below. Tap an age to see all its words. Tap any toy on the floor to play, or drag it to toss to Pip. Swipe the age choices at the top or the worlds and toys at the bottom. Use Back to return." % [_room.owned_toys.get_child_count(), _room._item_grid.get_child_count()]
	message += " Choose Players to add an emoji and name, or Leaderboards to view personal bests on this device."
	if _journey_save_failed:
		message += " Changes not saved. Choose a theme again to retry."
	if _age_save_failed:
		message += " " + _age_notice.text
	_announce_status(message)


func _load_collected_rewards() -> void:
	_progress_ready = medal_progress.load_progress()
	_save_error = not _progress_ready
	_sync_collected_rewards()


func _update_duck() -> void:
	if duck == null or audio == null:
		return
	_header_duck_slot.show()
	var in_collection: bool = collection_page.visible
	var visible_here: bool = not _leaderboard_overlay.visible or _pop_picker_open()
	var phrase_speaking: bool = _phrase_interaction_allowed() and audio.available and not audio.muted and audio.voice.playing
	_phrase.set_speaking(phrase_speaking)
	duck.set_outfit_theme(model.theme_id)
	duck.set_reduced_motion(reduced_motion)
	duck.set_speaking(visible_here and not phrase_speaking and audio.available and audio.active and not audio.muted and audio.voice.playing)
	duck.set_home_playground(in_collection)
	var active_phase: String = _memory.memory.phase if _mode_id == "memory" else model.phase
	if _mode_id == "pop":
		active_phase = _pop.game.phase
	var quiet_phase: bool = in_collection or active_phase in ["waiting", "matching"] \
		or (_mode_id == "pop" and active_phase in ["ready", "paused"])
	var microphone_busy: bool = _pop_speech_active or (_mode_id == "pop"
		and (_pop._listening or _pop._pending or _pop._reconnecting))
	var voice_busy: bool = audio.voice.playing
	duck.set_proactive_allowed(visible_here and quiet_phase and not _voice_mode and not _mode_menu_open()
		and (_mode_id != "phrase" or in_collection)
		and not microphone_busy and not voice_busy and not duck.speaking
		and not _pointer_focus_active and _proactive_touches.is_empty()
		and not _collection_dragging and _controller_last_direction == Vector2.ZERO
		and not _memory.memory.studying and not Input.is_anything_pressed())
	if not visible_here:
		duck.hide()
		return
	var slot: Control = _collection_duck_slot if in_collection else _header_duck_art_slot
	if not slot.is_visible_in_tree():
		duck.set_proactive_allowed(false)
		duck.hide()
		return
	var parent: Control = slot
	if duck.get_parent() != parent:
		duck.clear_room_interaction()
		duck.reparent(parent)
	if in_collection:
		_room.playground.set_duck(duck)
	var rect: Rect2 = slot.get_global_rect()
	if rect.position == Vector2.ZERO or rect.size.x <= 0 or rect.size.y <= 0:
		duck.hide()
		return
	duck.compact = false
	var opens_menu: bool = not in_collection and model.phase in ["waiting", "matching", "feedback"]
	duck.tooltip_text = "" if in_collection else "Pip: change game mode" if opens_menu else "Pip the duck. Press for a hello!"
	_set_accessibility_name(duck, "Pip: change game mode. Current mode: " + str(MODES[_mode_id]) if opens_menu else "Pip the duck. Press to say hello.")
	duck.position = parent.get_global_transform().affine_inverse() * rect.position
	duck.custom_minimum_size = Vector2(72, 72).min(rect.size) if in_collection else Vector2.ZERO
	duck.size = rect.size
	duck.show()
	var accent: Color = Data.THEMES[model.theme_id].accent
	if duck.accent != accent:
		duck.accent = accent
		duck.queue_redraw()


func _play_duck() -> void:
	if _page_hidden or (_leaderboard_overlay.visible and not _pop_picker_open()) or not duck.is_visible_in_tree() or (collection_page.visible and _collection_dragged):
		return
	if collection_page.visible:
		_room.playground.poke()
		return
	if model.phase in ["waiting", "matching", "feedback"]:
		_toggle_mode_menu()
		return
	if duck.is_manual_action_busy() or audio.is_pip_busy():
		return
	var tricks := ["dance", "snack", "bubbles", "high-five", "peekaboo", "flutter"]
	var caption: String = duck.perform_trick(tricks[_duck_trick_index % tricks.size()])
	if caption.is_empty():
		return
	_duck_trick_index += 1
	if _voice_mode or _pop_speech_active:
		return
	audio.interact(model.theme_id)
	if _mode_id == "pop":
		audio.play_pip()
	_announce_status("Pip says hello! " + caption)
