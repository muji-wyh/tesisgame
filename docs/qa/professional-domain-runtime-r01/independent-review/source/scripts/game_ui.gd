extends Control

const Model = preload("res://scripts/game_model.gd")
const Data = preload("res://scripts/game_data.gd")
const WordSampler = preload("res://scripts/word_sampler.gd")
const WordArt = preload("res://scripts/word_art.gd")
const VocabularyLoader = preload("res://scripts/vocabulary_loader.gd")
const SpeechWords = preload("res://scripts/speech_words.gd")
const Style = preload("res://scripts/ui_style.gd")
const Card = preload("res://scripts/word_card.gd")
const HintLink = preload("res://scripts/hint_link.gd")
const MatchConnections = preload("res://scripts/match_connections.gd")
const Audio = preload("res://scripts/game_audio.gd")
const Chest = preload("res://scripts/chest_view.gd")
const ChestFeel = preload("res://scripts/chest_feel.gd")
const RoundSettlement = preload("res://scripts/round_settlement.gd")
const MedalProgress = preload("res://scripts/medal_progress.gd")
const CoinWallet = preload("res://scripts/coin_wallet.gd")
const CoinCounter = preload("res://scripts/coin_counter.gd")
const CoinFlight = preload("res://scripts/coin_reward_flight.gd")
const Mascot = preload("res://scripts/duck_mascot.gd")
const Icons = preload("res://scripts/icon_button.gd")
const PricedIcons = preload("res://scripts/priced_icon_button.gd")
const Economy = preload("res://scripts/coin_economy.gd")
const MemoryGarden = preload("res://scripts/memory_garden.gd")
const MemoryPeekCountdown = preload("res://scripts/memory_peek_countdown.gd")
const PhraseGame = preload("res://scripts/phrase_game.gd")
const RoundCelebration = preload("res://scripts/round_celebration.gd")
const PairChestReward = preload("res://scripts/pair_chest_reward.gd")
const RewardConfetti = preload("res://scripts/reward_confetti.gd")
const VoicePop = preload("res://scripts/voice_pop.gd")
const JellyMatch = preload("res://scripts/jelly_match.gd")
const WordJelly = preload("res://scripts/word_jelly.gd")
const FinishConfirmation = preload("res://scripts/finish_confirmation.gd")
const SettlementDialog = preload("res://scripts/settlement_dialog.gd")
const JellyRewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const JellyBackdrop = preload("res://scripts/jelly_backdrop.gd")
const LearningThemeArt = preload("res://scripts/learning_theme_art.gd")
const PopRewardRoom = preload("res://scripts/pop_reward_room.gd")
const ReviewScroll = preload("res://scripts/review_scroll.gd")
const GrowthState = preload("res://scripts/growth_state.gd")
const GrowthBadge = preload("res://scripts/growth_badge.gd")
const AgeWordCatalog = preload("res://scripts/age_word_catalog.gd")
const LearningContext = preload("res://scripts/learning_context.gd")
const LearningContent = preload("res://scripts/learning_content_resolver.gd")
const LearningWord = preload("res://scripts/learning_word.gd")
const ProfessionalPlay = preload("res://scripts/professional_play.gd")
const ProfessionalMedia = preload("res://scripts/professional_media_access.gd")
const ProfessionalWordLibrary = preload("res://scripts/professional_word_library.gd")
const GameLibrary = preload("res://scripts/game_library.gd")
const PresentationPreferences = preload("res://scripts/presentation_preferences.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const MODES := {"match": "Match", "memory": "Memory", "pop": "Voice Pop", "phrase": "Phrase Builder", "jelly": "Jelly Match", "word_jelly": "Jelly Words"}
const HOLD_SECONDS: float = ChestFeel.HOLD_SECONDS
const MATCH_FEEDBACK_SECONDS: float = 0.7
const VOICE_MATCH_SECONDS: float = 1.0
const GAME_AREA_MAX_SIZE := Vector2(1064, 800)
const GAME_AREA_DESKTOP_WIDTH: float = 720.0

class InputActivityObserver extends Node:
	signal observed(event: InputEvent)

	func _input(event: InputEvent) -> void:
		observed.emit(event)


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
var vocabulary_loader = VocabularyLoader.new()
var _vocabulary_initialized: bool = false
var _vocabulary_booting: bool = true
var _vocabulary_catalog: Dictionary = {}
var _pending_vocabulary_round: Array = []
var _vocabulary_prompt: Panel
var _vocabulary_label: Label
var _vocabulary_progress: ProgressBar
var _vocabulary_retry: Button
var _vocabulary_back: Button
var _vocabulary_previous_pause: bool = false
var medal_progress := MedalProgress.new()
var coin_wallet := CoinWallet.new()
var _coin_counter: CoinCounter
var _coin_flight: CoinFlight
var _pending_coin_reward: Dictionary = {}
var _coin_published: String = ""
var _pair_reward: PairChestReward
var _pair_reward_row: Control
var _memory_peek_countdown: MemoryPeekCountdown
var _reward_confetti: RewardConfetti
var _confetti_reward_keys: Dictionary = {}
var _pair_words: Array[String] = []
var _pair_proposed_pair: int = 0
var _pair_save_failed: bool = false
var _pair_settlement_pending: bool = false
var duck: Mascot
var _header_duck_slot: Panel
var _header_duck_art_slot: Control
var _pip_age_description: String = ""
var _header: Control
var _header_spacer: Control
var _toolbar: HBoxContainer
var _main_column: VBoxContainer
var _collection_margins: MarginContainer
var _age_choices: VBoxContainer
var _age_row: HBoxContainer
var _age_scroll: ReviewScroll
var _age_buttons: Dictionary = {}
var _age_notice: Label
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
var hint_button: PricedIcons
var _hint_purchasing: bool = false
var _voice_button: Icons
var _voice_style_accent := Color.TRANSPARENT
var _voice_style_scale: float = -1.0
var _voice_space: Control
var _voice_mode: bool = false
var _mode_id: String = "match"
var _has_entered_game: bool = false
var _collection_from_home: bool = false
var _mode_buttons: Array[Button] = []
var _mode_menu: Control
var _mode_panel: GameLibrary
var _mode_heading_button: Button
var _mode_heading: Label
var _presentation := PresentationPreferences.new()
var _library_published := ""
var _mode_menu_focus_modes: Dictionary = {}
var _mode_menu_resume_voice: bool = false
var _mode_menu_resume_pop: bool = false
var _mode_menu_pointer: int = -2
var _memory: MemoryGarden
var _round_celebration: RoundCelebration
var _celebration_seen_id: String = ""
var _celebration_suspended: bool = false
var _celebration_published: String = ""
var _celebration_publish_left: float = 0.0
var _phrase: PhraseGame
var _phrase_published: String = ""
var _pop: VoicePop
var _pop_rewards: PopRewardRoom
var _pop_rewards_shown: bool = false
var pop_reward_save_path: String = "user://pop-rewards-v1.cfg"
var _controller_holding_pop_chest: bool = false
var _pop_speech_active: bool = false
var _pop_reward_saved: bool = false
var _pop_reward_theme: String = ""
var _pop_settling: bool = false
var _jelly: JellyMatch
var _word_jelly: WordJelly
var _finish_confirmation: FinishConfirmation
var _finish_confirmation_mode: String = ""
var _finish_confirmation_round: String = ""
var _finish_confirmation_generation: int = -1
var _finish_confirmation_focus_modes: Dictionary = {}
var _word_jelly_credits: Dictionary = {}
var _jelly_rewards: PopRewardRoom
var _jelly_rewards_shown: bool = false
var _settlement_dialog: SettlementDialog
var _jelly_rewards_parent: Control
var jelly_reward_save_path: String = "user://jelly-rewards-v1.cfg"
var _jelly_settling: bool = false
var _jelly_reward_saved: bool = false
var _jelly_reward_theme: String = ""
var _controller_holding_jelly_chest: bool = false
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
var _journey_save_failed: bool = false
var _voice_listening: bool = false
var _voice_attention_active: bool = false
var _speech_queue: Array[String] = []
var collection_button: Button
var collection_page: Panel
var collected_rewards: Dictionary = {}
var chest_button: Button
var reduced_motion: bool = false
var _page_hidden: bool = false
var _resume_music_after_background: bool = false
var _background: ColorRect
var _jelly_backdrop: JellyBackdrop
var _message: Label
var _storage_retry_button: Button
var _single_result: RoundSettlement
var _pending_fragment: Dictionary = {}
var _progress_ready: bool = false
var _save_error: bool = false
var _collection_back: Icons
var _collection_focus_modes: Dictionary = {}
var _focus_before_collection: Control
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
var _controller_mode: bool = false
var _pointer_focus_active: bool = false
var _navigation_focus_active: bool = false
var _proactive_touches: Dictionary = {}
var _collection_multi_touch: bool = false
var _controller_stick: Vector2 = Vector2.ZERO
var _controller_dpad: Vector2 = Vector2.ZERO
var _controller_last_direction: Vector2 = Vector2.ZERO
var _controller_repeat_elapsed: float = 0.0
var _controller_holding_chest: bool = false
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
var growth := GrowthState.new()
var _growth_button: GrowthBadge
var _growth_bar: ProgressBar
var _growth_summary: Label
var _growth_save_failed: bool = false
var _catalog_age: int = 3
var _memory_attempt: int = 0
var _growth_published: String = ""
var _growth_view_published: String = ""
var _round_id: String = ""
var _round_context: Dictionary = {}
var professional = ProfessionalPlay.new()
var professional_save_path: String = "user://professional-v1.json"
var _home_context: Dictionary = {}
var _round_content: Dictionary = {}
var _pending_professional_round: Array = []
var _professional_assisted: Dictionary = {}
var _professional_collections: Dictionary = {}
var _professional_preferences_restored := false
var _home_course_preview: String = ""
var _learning_theme_key: String = ""
var _resume_professional_source: String = ""
var _professional_library: ProfessionalWordLibrary
var _collection_professional := false
var _professional_button: Button
var _professional_heading: Label
var _professional_progress_label: Label
var _learning_backdrop: LearningThemeArt
var _round_result: Dictionary = {}


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
	_build_vocabulary_prompt()
	if OS.has_feature("web"):
		await get_tree().process_frame
	if not data.load_all():
		_show_error(data.error)
		return
	growth.configure(data.words)
	_growth_save_failed = not growth.load_state()
	coin_wallet.load_state()
	_coin_counter.available = coin_wallet.ready
	_coin_flight.sync(coin_wallet.balance)
	_load_collected_rewards()
	_build_collection()
	if OS.has_feature("web"):
		await get_tree().process_frame
	model.changed.connect(_refresh)
	model.word_attempted.connect(_match_growth_answer)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_presentation.load_preferences(DisplayServer.accessibility_should_reduce_animation() == 1)
	_preferred_theme = _presentation.preferred_theme
	reduced_motion = _presentation.reduced_motion
	_jelly_backdrop.set_reduced_motion(reduced_motion)
	WordArt.set_reduced_motion(reduced_motion)
	audio.set_muted(_presentation.muted)
	call_deferred("_sync_controller_accept_startup")
	_connect_browser()
	add_child(professional)
	professional.round_prepared.connect(_professional_round_ready)
	professional.changed.connect(_professional_changed)
	professional.event_completed.connect(_professional_event_completed)
	professional.configure(_host, _credit_coins, professional_save_path)
	_pop_rewards.save_path = pop_reward_save_path
	_pop_rewards.connect_storage(_host)
	_jelly_rewards.save_path = jelly_reward_save_path
	_jelly_rewards.connect_storage(_host)
	process_mode = initial_process_mode
	_vocabulary_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/vocabulary-packs.json"))
	add_child(vocabulary_loader)
	vocabulary_loader.configure(_host)
	vocabulary_loader.age_ready.connect(_on_vocabulary_ready)
	vocabulary_loader.age_failed.connect(_on_vocabulary_failed)
	vocabulary_loader.progress_changed.connect(_on_vocabulary_progress)
	_vocabulary_initialized = true
	# Native assets are already local. Web users reach the path chooser before
	# downloading a curriculum they may never select.
	if not vocabulary_loader._native:
		_finish_vocabulary_boot()
	elif new_round() or _pending_vocabulary_round.is_empty():
		_finish_vocabulary_boot()


func _finish_vocabulary_boot() -> void:
	if not _vocabulary_booting:
		return
	_vocabulary_booting = false
	_show_mode_menu()
	if _host != null:
		get_tree().paused = true
		_loading_finished_callback = JavaScriptBridge.create_callback(_on_loading_finished)
		_host.ready(_loading_finished_callback)
	_prefetch_vocabulary()


func _build_vocabulary_prompt() -> void:
	_vocabulary_prompt = Panel.new()
	_vocabulary_prompt.name = "VocabularyLoading"
	_vocabulary_prompt.z_index = 200
	_vocabulary_prompt.process_mode = Node.PROCESS_MODE_ALWAYS
	_vocabulary_prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vocabulary_prompt.add_theme_stylebox_override("panel", Style.box(Color("f4f6f1"), Color.TRANSPARENT, 0, 0))
	add_child(_vocabulary_prompt)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vocabulary_prompt.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 270
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	_vocabulary_label = Style.label("Loading words…", 20)
	_vocabulary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vocabulary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_vocabulary_label)
	_vocabulary_progress = ProgressBar.new()
	_vocabulary_progress.custom_minimum_size.y = 12
	_vocabulary_progress.show_percentage = false
	column.add_child(_vocabulary_progress)
	_vocabulary_retry = Button.new()
	_vocabulary_retry.name = "VocabularyRetry"
	_vocabulary_retry.text = "Try again"
	Style.action_button(_vocabulary_retry, Style.GOOD, true)
	UiClick.bind_button(_vocabulary_retry)
	_vocabulary_retry.pressed.connect(_retry_vocabulary)
	column.add_child(_vocabulary_retry)
	_vocabulary_back = Button.new()
	_vocabulary_back.name = "VocabularyBack"
	_vocabulary_back.text = "Back"
	Style.quiet_button(_vocabulary_back, Style.GOOD)
	UiClick.bind_button(_vocabulary_back)
	_vocabulary_back.pressed.connect(_cancel_vocabulary_round)
	column.add_child(_vocabulary_back)
	_vocabulary_prompt.hide()


func _wait_for_vocabulary(arguments: Array) -> void:
	if not _stop_pop_listening():
		return
	_pending_vocabulary_round = arguments
	if not _vocabulary_prompt.visible:
		_vocabulary_previous_pause = get_tree().paused
		_stop_controller_actions()
		audio.halt()
		_vocabulary_prompt.show()
		_vocabulary_prompt.move_to_front()
		_sync_reward_confetti()
		get_tree().paused = true
	_update_vocabulary_prompt()
	if str(vocabulary_loader.status(growth.learning_age()).state) == "idle":
		vocabulary_loader.request_age(growth.learning_age())


func _update_vocabulary_prompt() -> void:
	var state: Dictionary = vocabulary_loader.status(growth.learning_age())
	_vocabulary_label.text = "Words could not be loaded.\nPlease try again." if state.state == "failed" else "Loading Age %s words…" % ("12+" if growth.learning_age() == 12 else str(growth.learning_age()))
	_vocabulary_progress.value = float(state.progress) * 100.0
	_vocabulary_retry.visible = state.state == "failed"
	_vocabulary_back.visible = not _vocabulary_booting
	if _vocabulary_retry.visible:
		_vocabulary_retry.grab_focus()
	elif _vocabulary_back.visible:
		_vocabulary_back.grab_focus()
	_publish_growth_view()


func _retry_vocabulary() -> void:
	if not _pending_vocabulary_round.is_empty():
		vocabulary_loader.request_age(growth.learning_age())


func _close_vocabulary_prompt() -> void:
	if not _vocabulary_prompt.visible:
		return
	_vocabulary_prompt.hide()
	get_tree().paused = _vocabulary_previous_pause
	_sync_reward_confetti()
	_controller_accept_needs_release = _controller_accept_is_pressed()


func _cancel_vocabulary_round() -> void:
	if _vocabulary_booting:
		return
	_pending_vocabulary_round.clear()
	_close_vocabulary_prompt()
	_refresh()
	_default_focus().grab_focus()
	_restore_mode_music()
	_publish_growth_view()


func _on_vocabulary_ready(age: int) -> void:
	if collection_page.visible and age == _catalog_age:
		_show_age_catalog()
	if age == growth.learning_age() and not _pending_vocabulary_round.is_empty():
		_resume_vocabulary_round.call_deferred()
	_prefetch_vocabulary()
	_publish_growth_view()


func _resume_vocabulary_round() -> void:
	if _pending_vocabulary_round.is_empty() or _page_hidden or not vocabulary_loader.is_ready(growth.learning_age()):
		return
	var arguments: Array = _pending_vocabulary_round.duplicate()
	_pending_vocabulary_round.clear()
	_close_vocabulary_prompt()
	if not new_round.callv(arguments):
		return
	var was_booting: bool = _vocabulary_booting
	_finish_vocabulary_boot()
	if not was_booting:
		_default_focus().grab_focus()
		audio.interact(model.theme_id, _mode_id != "pop")
		if _mode_id == "phrase":
			_start_phrase_prompt()
		# Voice Pop retains its explicit microphone button after a download;
		# the completed network request is not a browser permission gesture.


func _on_vocabulary_failed(age: int, message: String) -> void:
	if _host != null and _vocabulary_booting:
		_host.vocabularyLoadingHint(age, "failed", vocabulary_loader.status(age).progress, message)
	_on_vocabulary_progress(age, 0.0)


func _on_vocabulary_progress(age: int, _progress: float) -> void:
	if _vocabulary_prompt.visible and age == growth.learning_age():
		_update_vocabulary_prompt()
	if collection_page.visible and age == _catalog_age:
		_show_age_catalog()
	_publish_growth_view()


func _prefetch_vocabulary() -> void:
	if not _vocabulary_initialized or _vocabulary_booting or not growth.ready:
		return
	if _home_context.get("track") == "professional" or (not _has_entered_game and _home_context.is_empty()):
		return
	var age: int = growth.learning_age()
	if str(vocabulary_loader.status(age).state) == "idle":
		vocabulary_loader.request_age(age)
	var state: Dictionary = growth.snapshot()
	if age < 12 and float(state.progress) >= 0.9 and str(vocabulary_loader.status(age + 1).state) == "idle":
		vocabulary_loader.request_age(age + 1)


func _vocabulary_snapshot() -> Dictionary:
	var age: int = growth.learning_age()
	var state: Dictionary = vocabulary_loader.status(age)
	var states: Dictionary = {}
	for value in range(3, 13):
		states[str(value)] = vocabulary_loader.status(value)
	return {"age": age, "status": state.state, "progress": state.progress,
		"ready": vocabulary_loader.is_ready(age), "pending_age": age if not _pending_vocabulary_round.is_empty() else 0,
		"pending_action": "round" if not _pending_vocabulary_round.is_empty() else "",
		"states": states}


func _on_loading_finished(_args: Array) -> void:
	if _loading_revealed:
		return
	_loading_revealed = true
	_stop_controller_actions()
	get_tree().paused = false
	_restore_mode_music()


func _build_controls() -> void:
	_background = ColorRect.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_jelly_backdrop = JellyBackdrop.new()
	_jelly_backdrop.name = "JellyGarden"
	add_child(_jelly_backdrop)
	_jelly_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_jelly_backdrop.hide()
	_learning_backdrop = LearningThemeArt.new()
	_learning_backdrop.name = "WorkplaceEnvironment"
	add_child(_learning_backdrop)
	_learning_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := MarginContainer.new()
	margins.name = "GameArea"
	_content_margins = margins
	margins.minimum_size_changed.connect(_fit_content.call_deferred)
	margins.item_rect_changed.connect(_sync_voice_bounds.call_deferred)
	add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for edge in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 12)
	var column := VBoxContainer.new()
	_main_column = column
	column.add_theme_constant_override("separation", 8)
	margins.add_child(column)
	var header := Control.new()
	_header = header
	header.resized.connect(_layout_game_heading)
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
	_mode_heading_button.name = "Home"
	_set_accessibility_name(_mode_heading_button, "Home. Return home to choose a game")
	_mode_heading_button.icon = preload("res://assets/images/ui/home.webp")
	_mode_heading_button.expand_icon = true
	_mode_heading_button.pressed.connect(_toggle_mode_menu)
	_header_spacer.add_child(_mode_heading_button)
	_coin_counter = CoinCounter.new()
	_header_spacer.resized.connect(_layout_game_heading)
	_mode_heading_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_heading = Style.label("Match", 22)
	_mode_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_spacer.add_child(_mode_heading)
	_toolbar = HBoxContainer.new()
	_toolbar.alignment = BoxContainer.ALIGNMENT_END
	_toolbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_toolbar)
	_toolbar.resized.connect(_layout_game_heading)
	_voice_button = Icons.new()
	_voice_button.name = "Voice"
	_voice_button.symbol = Icons.Symbol.VOICE
	_voice_button.toggle_mode = true
	UiClick.bind_button(_voice_button)
	_voice_button.pressed.connect(_toggle_voice)
	_toolbar.add_child(_voice_button)
	hint_button = PricedIcons.new()
	hint_button.name = "Hint"
	hint_button.symbol = Icons.Symbol.HINT
	hint_button.cost = _match_hint_price()
	_set_accessibility_name(hint_button, "Hint: %d coins (Xbox X)" % _match_hint_price())
	hint_button.pressed.connect(_request_hint)
	_toolbar.add_child(hint_button)
	_growth_button = GrowthBadge.new()
	UiClick.bind_button(_growth_button)
	_growth_button.pressed.connect(_show_collection)
	_header_duck_slot.add_child(_growth_button)
	_professional_button = Button.new()
	_professional_button.name = "ProfessionalCourse"
	UiClick.bind_button(_professional_button)
	_professional_button.pressed.connect(_show_collection)
	_header_duck_slot.add_child(_professional_button)
	_professional_heading = Style.label("Professional English", 14)
	_professional_heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_professional_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_professional_button.add_child(_professional_heading)
	_professional_progress_label = Style.label("", 12)
	_professional_progress_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_professional_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_professional_button.add_child(_professional_progress_label)
	_professional_button.hide()
	header.add_child(_coin_counter)
	collection_button = _growth_button
	_growth_bar = _growth_button.bar
	_build_mode_menu()
	_pair_reward = PairChestReward.new()
	_pair_reward.name = "PairChestReward"
	_pair_reward.cue_requested.connect(_pair_reward_cue)
	_pair_reward.confetti_requested.connect(_pair_confetti_requested)
	_pair_reward_row = Control.new()
	_pair_reward_row.name = "PairRewardSpace"
	_pair_reward_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_pair_reward_row)
	_pair_reward_row.add_child(_pair_reward)
	_pair_reward.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_memory_peek_countdown = MemoryPeekCountdown.new()
	_memory_peek_countdown.name = "MemoryPeekCountdown"
	_pair_reward_row.add_child(_memory_peek_countdown)
	_pair_reward_row.resized.connect(_layout_pair_reward)
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
	_memory.round_finished.connect(_memory_finished)
	_memory.prompt_ready.connect(_memory_prompt)
	_memory.purchase_peek = _purchase_memory_peek
	_memory.peek_feedback.connect(_memory_peek_feedback)
	_memory.peek_clock_changed.connect(_memory_peek_clock_changed)
	_memory.hide()
	column.add_child(_memory)
	_memory.study_button.reparent(_toolbar)
	_toolbar.move_child(_memory.study_button, 0)
	_phrase = PhraseGame.new()
	_phrase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_phrase.interaction_allowed = _phrase_interaction_allowed
	_phrase.completion_requested.connect(_phrase_completion_requested)
	_phrase.word_attempted.connect(_phrase_answered)
	_phrase.finished.connect(_phrase_finished)
	_phrase.status_changed.connect(_phrase_status_changed)
	_phrase.audio_requested.connect(_phrase_audio_requested)
	_phrase.changed.connect(_publish_phrase)
	_phrase.hide()
	column.add_child(_phrase)
	_pop = VoicePop.new()
	_pop.name = "VoicePop"
	_pop.game.word_attempted.connect(_pop_growth_answer)
	_pop.interaction_allowed = func() -> bool: return not _round_celebration_active() and not collection_page.visible and not _page_hidden and not _mode_menu_open()
	_pop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pop.request_listening.connect(_start_pop_listening)
	_pop.exit_requested.connect(_show_mode_menu)
	_pop.hit.connect(_pop_hit)
	_pop.launched.connect(_pop_launched)
	_pop.missed.connect(_pop_missed)
	_pop.round_finished.connect(_pop_finished)
	_pop.chest_earned.connect(_pop_chest_earned)
	_pop.reward_cue_requested.connect(_pop_reward_cue)
	_pop.status_changed.connect(_pop_status_changed)
	_pop.hide()
	column.add_child(_pop)
	_pop._reward_presentation.confetti_requested.connect(_fragment_confetti_requested.bind("pop"))
	_pop_rewards = PopRewardRoom.new()
	_pop_rewards.credit_coins = _credit_coins
	_pop_rewards.coins_released.connect(_present_room_coins)
	_pop_rewards.name = "PopRewardRoom"
	_pop_rewards.max_chests = 0
	_pop_rewards.allow_repeated_themes = true
	_pop_rewards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pop_rewards.interaction_allowed = func() -> bool: return _pop_rewards_shown and _mode_id == "pop" and not collection_page.visible and not _page_hidden and not _mode_menu_open()
	_pop_rewards.exit_requested.connect(_hide_pop_rewards)
	_pop_rewards.replay_requested.connect(_replay_pop)
	_pop_rewards.home_requested.connect(_show_mode_menu)
	_pop_rewards.chest_audio_requested.connect(_pop_chest_audio)
	_pop_rewards.chest_cue_requested.connect(func(theme_id: String, cue: String, step: int) -> void:
		if not _pop_rewards_shown or _page_hidden or collection_page.visible or _mode_id != "pop":
			return
		audio.chest_cue(theme_id, cue, step)
		if _host != null:
			_host.chestCue(theme_id, cue, step))
	_pop_rewards.changed.connect(_publish_pop_rewards)
	_pop_rewards.hide()
	column.add_child(_pop_rewards)
	_jelly = JellyMatch.new()
	_jelly.name = "JellyMatch"
	_jelly.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_jelly.interaction_allowed = func() -> bool: return _mode_id == "jelly" and _jelly_interaction_allowed()
	_jelly.word_requested.connect(_jelly_hear.bind("jelly"))
	_jelly.audio_requested.connect(_jelly_audio.bind("jelly"))
	_jelly.word_attempted.connect(_jelly_growth_answer.bind("jelly"))
	_jelly.round_finished.connect(_jelly_finished.bind("jelly"))
	_jelly.finish_requested.connect(_request_jelly_finish.bind("jelly"))
	_jelly.changed.connect(_publish_jelly.bind("jelly"))
	_jelly.hide()
	column.add_child(_jelly)
	_jelly.host_header_chest(header)
	_jelly.finish_button.reparent(_toolbar, false)
	_jelly.finish_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_jelly._reward_presentation.confetti_requested.connect(_fragment_confetti_requested.bind("jelly"))
	_word_jelly = WordJelly.new()
	_word_jelly.name = "JellyWords"
	_word_jelly.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_word_jelly.interaction_allowed = func() -> bool: return _mode_id == "word_jelly" and _jelly_interaction_allowed()
	_word_jelly.credit_collection = _credit_word_jelly
	_word_jelly.purchase_powerup = _purchase_word_jelly_powerup
	_word_jelly.coin_balance = func() -> int: return coin_wallet.balance
	_word_jelly.collected.connect(_word_jelly_collected)
	_word_jelly.word_requested.connect(_jelly_hear.bind("word_jelly"))
	_word_jelly.word_merged.connect(_word_jelly_merged)
	_word_jelly.batch_collection_started.connect(func() -> void: audio.stop_voice())
	_word_jelly.audio_requested.connect(_jelly_audio.bind("word_jelly"))
	_word_jelly.word_attempted.connect(_jelly_growth_answer.bind("word_jelly"))
	_word_jelly.round_finished.connect(_jelly_finished.bind("word_jelly"))
	_word_jelly.finish_requested.connect(_request_jelly_finish.bind("word_jelly"))
	_word_jelly.changed.connect(_publish_jelly.bind("word_jelly"))
	_word_jelly.hide()
	column.add_child(_word_jelly)
	_word_jelly.host_header_chest(header)
	_word_jelly.finish_button.reparent(_toolbar, false)
	_word_jelly.finish_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_word_jelly._reward_presentation.confetti_requested.connect(_fragment_confetti_requested.bind("word_jelly"))
	_jelly_rewards = PopRewardRoom.new()
	_jelly_rewards.credit_coins = _credit_coins
	_jelly_rewards.coins_released.connect(_present_room_coins)
	_jelly_rewards.name = "JellyRewardRoom"
	_jelly_rewards.storage_kind = "jelly"
	_jelly_rewards.max_chests = 0
	_jelly_rewards.allow_repeated_themes = true
	_jelly_rewards.page_size = 3
	_jelly_rewards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_jelly_rewards.interaction_allowed = func() -> bool: return _jelly_rewards_shown and _is_jelly_mode() and not collection_page.visible and not _page_hidden and not _mode_menu_open()
	_jelly_rewards.exit_requested.connect(_hide_jelly_rewards)
	_jelly_rewards.replay_requested.connect(_replay_jelly)
	_jelly_rewards.chest_audio_requested.connect(_pop_chest_audio)
	_jelly_rewards.chest_cue_requested.connect(func(theme_id: String, cue: String, step: int) -> void:
		if _jelly_rewards_shown and _is_jelly_mode() and not _page_hidden and not collection_page.visible and not _mode_menu_open():
			audio.chest_cue(theme_id, cue, step))
	_jelly_rewards.changed.connect(_publish_jelly_rewards)
	_jelly_rewards.hide()
	column.add_child(_jelly_rewards)
	_jelly_rewards_parent = column
	_settlement_dialog = SettlementDialog.new()
	add_child(_settlement_dialog)
	_settlement_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_jelly_rewards.home_requested.connect(func() -> void: _settlement_dialog.home_requested.emit())
	_settlement_dialog.home_requested.connect(_show_mode_menu)
	_round_celebration = RoundCelebration.new()
	_round_celebration.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_round_celebration.performance_finished.connect(_on_round_celebration_finished)
	_round_celebration.open_requested.connect(_accept_round_chest)
	_round_celebration.home_requested.connect(_show_mode_menu)
	_round_celebration.cue_requested.connect(_round_celebration_cue)
	_round_celebration.confetti_requested.connect(_round_confetti_requested)
	_settlement_dialog.panel.add_child(_round_celebration)
	_round_celebration.hide()
	_single_result = RoundSettlement.new()
	_settlement_dialog.panel.add_child(_single_result)
	_single_result.hide()
	chest = _single_result.chest
	chest_button = _single_result.chest_button
	chest.opened.connect(_on_chest_opened)
	chest.release_reached.connect(_on_chest_released)
	chest.cue_requested.connect(_on_chest_cue)
	chest_button.button_down.connect(_start_chest_hold)
	chest_button.button_up.connect(_end_chest_hold)
	chest_button.gui_input.connect(_chest_input)
	_single_result.retry_requested.connect(_retry_reward_save)
	_single_result.replay_requested.connect(_new_adventure)
	_single_result.home_requested.connect(_show_mode_menu)
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
	duck.focus_entered.connect(func() -> void:
		if collection_page.visible:
			_ensure_collection_focus_visible(duck))
	duck.hide()
	add_child(duck)
	_set_accessibility_name(duck, "Pip the duck. Press for a new move.")
	_settlement_dialog.close()
	_coin_flight = CoinFlight.new()
	_coin_flight.counter = _coin_counter
	_coin_flight.release_sound.connect(audio.play_coin_release)
	_coin_flight.arrival_sound.connect(audio.play_coin_arrival)
	_coin_flight.spend_sound.connect(audio.play_coin_spend)
	_coin_flight.settled.connect(audio.stop_coin_sounds)
	add_child(_coin_flight)
	_coin_flight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reward_confetti = RewardConfetti.new()
	add_child(_reward_confetti)
	_finish_confirmation = FinishConfirmation.new()
	add_child(_finish_confirmation)
	_finish_confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_finish_confirmation.canceled.connect(_cancel_jelly_finish)
	_finish_confirmation.confirmed.connect(_confirm_jelly_finish)
	_finish_confirmation.resized.connect(_publish_finish_confirmation.call_deferred)
	_finish_confirmation.keep_playing_button.focus_entered.connect(_publish_finish_confirmation.call_deferred)
	_finish_confirmation.finish_button.focus_entered.connect(_publish_finish_confirmation.call_deferred)
	visibility_changed.connect(_sync_reward_confetti)
	# Input is dispatched child-first; observe it before interactive descendants consume it.
	var observer := InputActivityObserver.new()
	observer.name = "InputActivity"
	observer.observed.connect(_observe_activity)
	add_child(observer)


func _build_mode_menu() -> void:
	_mode_menu = Control.new()
	_mode_menu.name = "HomeScreen"
	_mode_menu.z_index = 100
	_mode_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_mode_menu)
	_mode_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_menu.hide()
	_sync_round_celebration()
	var shade := ColorRect.new()
	shade.color = Color(Style.INK, 0.32)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_panel = GameLibrary.new()
	_mode_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_mode_panel.scroll.interaction_allowed = func() -> bool:
		return _mode_menu_open() and not _page_hidden and not collection_page.visible \
			and not (is_instance_valid(_vocabulary_prompt) and _vocabulary_prompt.visible)
	_mode_menu.add_child(_mode_panel)
	_mode_buttons = _mode_panel.buttons
	theme_buttons = _mode_panel.theme_buttons
	_mode_panel.theme_requested.connect(_choose_world)
	_mode_panel.mode_requested.connect(_choose_mode_from_menu)
	_mode_panel.collection_requested.connect(_show_collection)
	_mode_panel.sound_toggled.connect(_toggle_library_sound)
	_mode_panel.learning_context_selected.connect(_select_learning_context)
	_mode_panel.learning_continue_requested.connect(_continue_learning_context)
	_mode_panel.learning_retry_requested.connect(_retry_professional)
	_mode_panel.learning_cancel_requested.connect(_cancel_professional)
	_mode_panel.learning_course_selected.connect(_preview_learning_course)


func _toggle_library_sound() -> void:
	if not _mode_menu_open():
		return
	audio.set_muted(not audio.muted)
	_phrase.set_muted(audio.muted or not audio.available)
	_play_ui_click()
	_presentation.muted = audio.muted
	_save_presentation()


func _save_presentation() -> void:
	_mode_panel.configure(_mode_id if _home_can_continue() else "", audio.muted, reduced_motion)
	if _host != null:
		_host.presentationSettings(reduced_motion, audio.muted)
	var saved: bool = _presentation.save_preferences()
	_announce_status(("Sound off." if audio.muted else "Sound on.") + ("" if saved else " Preferences could not be saved on this device. Your choices work for this visit."))


func _mode_menu_open() -> bool:
	return is_instance_valid(_mode_menu) and _mode_menu.visible


func _toggle_mode_menu() -> void:
	var was_open: bool = _mode_menu_open()
	_show_mode_menu()
	if was_open != _mode_menu_open():
		_play_ui_click()


func _play_ui_click(source: Control = null) -> void:
	if _page_hidden or _speech_debug_active or not is_instance_valid(audio):
		return
	if source != null and (not _valid_focus(source) or source.is_queued_for_deletion()):
		return
	if source != null and collection_page.is_ancestor_of(source) \
		and _collection_multi_touch:
		return
	audio.play_ui_click()


func _show_mode_menu() -> void:
	if _mode_menu_open() or _finish_confirmation_open() or _page_hidden or collection_page.visible \
		or (_save_error and not _pending_fragment.is_empty()):
		return
	if not _settle_completed_round_rewards():
		return
	_mode_menu_resume_voice = _voice_mode
	if _mode_menu_resume_voice and _host != null and not bool(_host.suspendSpeechForMenu()):
		_mode_menu_resume_voice = false
		return
	# Speech ownership can outlive a denied/failed microphone. Resume only a
	# recognizer that was listening or connecting when the menu interrupted it.
	_mode_menu_resume_pop = _mode_id == "pop" and (_pop._listening or _pop._pending or _pop._reconnecting)
	if not _stop_pop_listening():
		if _mode_menu_resume_voice and _host != null:
			_host.resumeSpeechFromMenu()
		_mode_menu_resume_voice = false
		_mode_menu_resume_pop = false
		return
	_mode_menu.show()
	_coin_flight.sync(coin_wallet.balance)
	_sync_round_celebration()
	_on_input_canceled()
	_stop_controller_actions()
	if _mode_menu_resume_voice:
		# Keep the reserved voice-panel bounds while the host hides its overlay.
		_voice_listening = false
		_voice_attention_active = false
		_voice_button.engaged = false
		_speech_queue.clear()
		_clear_voice_match_feedback()
	else:
		_stop_voice()
	if _mode_id == "pop":
		if _pop.game.phase in ["running", "finished"] or _mode_menu_resume_pop:
			_pop.pause()
		_pop_rewards.pause()
		audio.stop_pop_sounds()
	feedback_timer.paused = true
	_memory.pause(true)
	_pause_phrase()
	_jelly_rewards.pause()
	_sync_jelly()
	_hint_link.set_paused(true)
	hint_button.reset_feedback()
	audio.stop_voice()
	duck.settle()
	_mode_menu_focus_modes.clear()
	for node in find_children("*", "Control", true, false):
		var control := node as Control
		if not _mode_menu.is_ancestor_of(control) and not _vocabulary_prompt.is_ancestor_of(control):
			_mode_menu_focus_modes[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
	_fit_mode_buttons()
	_refresh_learning_home()
	_update_duck()
	_default_focus().grab_focus()
	_restore_mode_music()
	_announce_status("Home. Choose a game to play." + (" Select %s to continue your round." % MODES[_mode_id] if _can_continue_round() else ""))


func _current_round_ended() -> bool:
	if _is_jelly_mode():
		return is_instance_valid(_active_jelly()) and _active_jelly().game.phase == "finished"
	if _mode_id == "pop":
		return is_instance_valid(_pop) and _pop.game.phase == "finished"
	return _mode_id in ["match", "memory", "phrase"] and model.phase == "won"


func _can_continue_round() -> bool:
	return _has_entered_game and not _round_id.is_empty() and not _current_round_ended()


func _home_can_continue() -> bool:
	return _can_continue_round() and LearningContext.same_round(_round_context, _desired_learning_context(_mode_id))


func _home_mode_available() -> bool:
	if _home_context.get("track") != "professional":
		return true
	if professional.phase in ["media", "storage", "restoring"]:
		return false
	var course: Dictionary = professional.loader.catalog.course(str(_home_context.course_id))
	for module in course.get("modules", []):
		if module.id == _home_context.module_id:
			return module.get("status") == "ready"
	return false


func _settle_completed_round_rewards() -> bool:
	if not _current_round_ended():
		return true
	# Home and replay share the same durable receipts as opening by hand.
	# Settle an in-flight opening before leaving, including an incomplete hold.
	if _is_jelly_mode():
		_controller_holding_jelly_chest = false
		if not _save_jelly_round_reward() or not _jelly_rewards.collect_all_coins():
			_show_jelly_rewards()
			_announce_status("Your coins are waiting to be saved. Choose Retry save.")
			return false
	elif _mode_id == "pop":
		_controller_holding_pop_chest = false
		if not _save_pop_round_reward() or not _pop_rewards.collect_all_coins():
			_show_pop_rewards()
			_announce_status("Your coins are waiting to be saved. Choose Retry save.")
			return false
	else:
		_stop_round_celebration()
		_settling_chest = true
		audio.stop_chest_performance()
		if model.chest_earned and model.chest_state == "closed":
			_open_chest()
		if model.chest_state == "opening":
			chest.finish_immediately()
		_settling_chest = false
		if _save_error or (model.chest_earned and model.chest_state != "opened"):
			_refresh()
			_announce_status("Your progress is waiting to be saved. Choose Retry saving.")
			return false
	_coin_flight.sync(coin_wallet.balance)
	return true


func _hide_mode_menu(restore_focus: bool = true, resume_game: bool = true) -> void:
	if not _mode_menu_open():
		return
	_mode_menu_pointer = -2
	_mode_menu.hide()
	_sync_reward_confetti()
	for control in _mode_menu_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = _mode_menu_focus_modes[control]
	_mode_menu_focus_modes.clear()
	_publish_library.call_deferred()
	var resume_voice: bool = _mode_menu_resume_voice
	var resume_pop: bool = _mode_menu_resume_pop
	_mode_menu_resume_voice = false
	_mode_menu_resume_pop = false
	if resume_game and not _page_hidden and not collection_page.visible:
		feedback_timer.paused = false
		_memory.pause(_professional_input_blocked())
		_resume_phrase()
		_sync_jelly()
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
	if restore_focus:
		_default_focus().grab_focus()
	if restore_focus:
		_announce_status("%s. Let's play." % MODES[_mode_id])


func _choose_mode_from_menu(id: String) -> void:
	choose_mode(id)


func _desired_learning_context(mode: String) -> Dictionary:
	var selected: Dictionary = _home_context if _mode_menu_open() else _round_context
	if selected.get("track") == "professional":
		var context: Dictionary = selected.duplicate(true)
		context.mode = mode
		return context
	return LearningContext.growth(growth.learning_age(), mode)


func _select_learning_context(context: Dictionary) -> void:
	if not _mode_menu_open() or not LearningContext.validate(context).is_empty():
		return
	_professional_preferences_restored = true
	_resume_professional_source = ""
	professional.cancel()
	_pending_professional_round.clear()
	_home_context = context.duplicate(true)
	_home_course_preview = str(context.get("course_id", "")) if context.track == "professional" else ""
	if context.track == "growth":
		_home_context = LearningContext.growth(growth.learning_age(), context.mode)
		professional.store.request("context", _home_context)
	_refresh_learning_home()
	_refresh()


func _continue_learning_context(context: Dictionary) -> void:
	_select_learning_context(context)
	choose_mode(str(context.get("mode", "word_jelly")))


func _professional_round_ready(_selection: int, content: Dictionary, source: String) -> void:
	if _pending_professional_round.size() != 6:
		professional.cancel()
		return
	var arguments: Array = _pending_professional_round.duplicate()
	arguments.append(content)
	arguments.append(source)
	if new_round.callv(arguments):
		_pending_professional_round.clear()
		_has_entered_game = true
		_home_context = _round_context.duplicate(true)
		_default_focus().grab_focus()
		if _mode_id == "pop":
			_start_pop_listening()
		else:
			audio.interact(model.theme_id)
			if _mode_id == "phrase":
				_start_phrase_prompt()
	else:
		_announce_status("Your current round is safe. Finish saving its rewards, then retry.")


func _professional_input_blocked() -> bool:
	return _round_context.get("track") == "professional" and not professional.can_play(_round_id)


func _professional_changed(state: Dictionary) -> void:
	if not is_inside_tree() or _rebuilding:
		return
	var saved: Dictionary = state.session
	if collection_page.visible and _collection_professional:
		_professional_library.set_progress(saved)
	if not _professional_preferences_restored and saved.progress_loaded and saved.pending_count == 0 and not saved.blocked:
		_professional_preferences_restored = true
		var context: Variant = saved.saved_context
		if context is Dictionary and LearningContext.validate(context).is_empty():
			if context.track == "growth" or not professional.loader.catalog.course(context.course_id).is_empty():
				_home_context = context.duplicate(true)
	_refresh_learning_home()
	if not _vocabulary_initialized:
		return
	if _professional_input_blocked():
		feedback_timer.paused = true
		_memory.pause(true)
		_pause_phrase()
		_pop.pause()
		_stop_pop_listening()
		_sync_jelly()
		if not str(state.error).is_empty():
			_announce_status(str(state.error) + " Choose Retry saving.")
	elif not _mode_menu_open() and not _page_hidden and not collection_page.visible:
		feedback_timer.paused = false
		_memory.pause(false)
	if _resume_professional_source == _round_id and not _resume_professional_source.is_empty() \
		and professional.can_play(_round_id) and _mode_menu_open():
		_resume_professional_source = ""
		choose_mode.call_deferred(_mode_id)
	_refresh.call_deferred()


func _refresh_learning_home() -> void:
	if is_instance_valid(_mode_panel) and _mode_panel.has_method("configure_learning"):
		_mode_panel.configure_learning(professional.loader.catalog,
			_home_context if not _home_context.is_empty() else _round_context if _has_entered_game else {},
			professional.snapshot(), _round_context if _can_continue_round() else {}, _professional_library_available())


func _professional_library_available() -> bool:
	return _round_context.get("track") == "professional" and not professional.active.is_empty() \
		and LearningContext.identity(_home_context, false) == LearningContext.identity(_round_context, false)


func _preview_learning_course(id: String) -> void:
	_home_course_preview = id
	_refresh()


func _selected_theme_profile() -> Dictionary:
	if _mode_menu_open():
		var course_id: String = _home_course_preview if not _home_course_preview.is_empty() else str(_home_context.get("course_id", ""))
		if course_id not in ["", "growth"]:
			var course: Dictionary = professional.loader.catalog.course(course_id)
			return professional.loader.catalog.theme_profile(str(course.get("theme_id", "")))
	elif _round_context.get("track") == "professional":
		return _round_content.get("theme_profile", {})
	return professional.loader.catalog.theme_profile("growth_garden")


func _retry_professional() -> void:
	if professional.phase == "ready" and not professional.pending.is_empty():
		_professional_round_ready(professional.pending.selection, professional.pending.content, professional.pending.source)
	else:
		professional.retry()


func _cancel_professional() -> void:
	_pending_professional_round.clear()
	professional.cancel()
	_refresh_learning_home()


func _record_professional(attempt_id: String, words: Array, correct: bool) -> void:
	if _round_id.is_empty() or professional.active.get("source") != _round_id:
		return
	# Whole-word collection owns spelling evidence; intermediate merge feedback
	# must never create a second correct assessment for the same composition.
	if _mode_id == "word_jelly" and correct:
		return
	var distinct: Dictionary = {}
	for sense in words:
		if distinct.has(str(sense)):
			continue
		distinct[str(sense)] = true
		if _mode_id == "word_jelly":
			var assessed := false
			for requirement in _round_content.get("requirements", {}).get("terms", []):
				if requirement.sense_id == sense and requirement.skills.has("spelling"):
					assessed = true
					break
			# An atomic tile involved in an invalid merge has no spelling task.
			# Its only Word Jelly evidence comes from passive collection.
			if not assessed:
				continue
		var event: Dictionary = {"id": _round_id + ":" + attempt_id + ":" + str(sense),
			"sense_id": str(sense), "skill": LearningContent.MODE_SKILLS[_mode_id],
			"correct": correct, "assisted": _professional_assisted.has(str(sense)), "atomic": false}
		if _mode_id == "phrase":
			event.expression_id = _phrase.game.current_question().id
		var result: Dictionary = professional.session.submit(event, _round_id)
		if not result.get("ok", false) and not result.get("pending", false):
			professional.error = str(result.error)
			professional.phase = "failed"
			_professional_changed(professional.snapshot())


func _commit_professional_collection(payload: Dictionary) -> Dictionary:
	if _round_context.get("track") != "professional" or _mode_id != "word_jelly":
		return {"ok": false, "error": "This round has changed."}
	var local_id: String = str(payload.event_id)
	var id: String = _round_id + ":" + local_id
	var composition: Dictionary = payload.get("a", {}).get("composition", {})
	var event: Dictionary = {"id": id, "sense_id": str(payload.word.id), "skill": "spelling",
		"correct": true, "assisted": bool(composition.get("assisted", false)),
		"atomic": payload.word.get("morphology", {}).get("kind") == "atomic"}
	if int(payload.coins) > 0:
		event.reward = {"operation": "credit", "payload": {"tier": int(payload.coins) / CoinWallet.COINS_PER_TIER}}
	_professional_collections[id] = {"local_id": local_id, "generation": payload.generation, "source": _round_id}
	var result: Dictionary = professional.session.submit(event, _round_id)
	if result.get("ok", false):
		_word_jelly_credits[local_id] = result.get("wallet", {})
		_professional_collections.erase(id)
	elif not result.get("pending", false):
		_professional_collections.erase(id)
	return result


func _professional_event_completed(id: String, source: String, result: Dictionary) -> void:
	if source != _round_id or not _professional_collections.has(id):
		return
	var pending: Dictionary = _professional_collections[id]
	_professional_collections.erase(id)
	if result.get("ok", false):
		_word_jelly_credits[pending.local_id] = result.get("wallet", {})
	_word_jelly.game.resolve_collection_commit(pending.local_id, int(pending.generation), result)


func _build_collection_shell() -> void:
	collection_page = Panel.new()
	collection_page.name = "GrowthNotebook"
	collection_page.z_index = 50
	add_child(collection_page)
	collection_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_collection_margins = MarginContainer.new()
	collection_page.add_child(_collection_margins)
	_collection_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_collection_column = VBoxContainer.new()
	_collection_margins.add_child(_collection_column)
	_collection_header = HBoxContainer.new()
	_collection_column.add_child(_collection_header)
	_collection_title = Style.label("Grow with Pip", 22)
	_collection_title.clip_text = true
	_collection_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_header.add_child(_collection_title)
	_collection_back = Icons.new()
	_collection_back.name = "GrowthBack"
	_collection_back.symbol = Icons.Symbol.BACK
	_set_accessibility_name(_collection_back, "Back to game")
	UiClick.bind_button(_collection_back)
	_collection_back.pressed.connect(_back_from_collection)
	_collection_header.add_child(_collection_back)
	_growth_summary = Style.label("", 15)
	_growth_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_collection_column.add_child(_growth_summary)
	_build_age_choices()
	_age_catalog = AgeWordCatalog.new()
	_age_catalog.interaction_allowed = _can_browse_collection
	_age_catalog.hear_requested.connect(_hear_catalog_word)
	_age_catalog.retry_requested.connect(func() -> void:
		if _can_browse_collection():
			vocabulary_loader.request_age(_catalog_age))
	_collection_column.add_child(_age_catalog)
	_professional_library = ProfessionalWordLibrary.new()
	_professional_library.interaction_allowed = _can_browse_collection
	_professional_library.hear_requested.connect(_hear_professional_word)
	_collection_column.add_child(_professional_library)
	_professional_library.hide()
	collection_page.hide()


func _hear_professional_word(word: Dictionary) -> void:
	if not _collection_professional or not _can_browse_collection():
		return
	audio.interact(model.theme_id)
	audio.say(str(word.audio))
	_announce_status(str(word.get("display_text", word.text)) + ". " + str(word.definition))


func _build_age_choices() -> void:
	_age_choices = VBoxContainer.new()
	_collection_column.add_child(_age_choices)
	_age_scroll = ReviewScroll.new()
	_age_scroll.interaction_allowed = _can_browse_collection
	_age_choices.add_child(_age_scroll)
	_age_row = HBoxContainer.new()
	_age_scroll.add_child(_age_row)
	for band in Data.age_bands():
		var button := Button.new()
		button.name = "GrowthAge" + str(band.id)
		button.text = str(band.label)
		_set_accessibility_name(button, str(band.name))
		button.toggle_mode = true
		button.pressed.connect(_choose_age_band.bind(str(band.id)))
		button.focus_entered.connect(_ensure_collection_focus_visible.bind(button))
		UiClick.bind_button(button)
		_age_row.add_child(button)
		_age_buttons[band.id] = button
	_age_notice = Style.label("", 13)
	_age_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_age_choices.add_child(_age_notice)


func _choose_age_band(id: String) -> void:
	if not _can_browse_collection():
		return
	_catalog_age = int(id)
	_refresh_age_choices()
	_show_age_catalog()


func _can_browse_collection() -> bool:
	return collection_page.visible and not _page_hidden \
		and not _speech_debug_active and not _collection_multi_touch


func _show_age_catalog() -> void:
	if not collection_page.visible or _collection_professional or not _vocabulary_initialized:
		return
	audio.stop_voice()
	var band: Dictionary = Data.age_band(str(_catalog_age))
	if _catalog_age > growth.learning_age():
		band.name += " · Preview"
	var words: Array = data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == _catalog_age)
	if not vocabulary_loader.is_ready(_catalog_age):
		_age_catalog.show_loading(band, words.size(), vocabulary_loader.status(_catalog_age), Data.theme(model.theme_id))
		_age_catalog.show()
		if str(vocabulary_loader.status(_catalog_age).state) == "idle":
			vocabulary_loader.request_age(_catalog_age)
		return
	_age_catalog.configure(words, band, Data.theme(model.theme_id), growth.snapshot())
	_age_catalog.show()


func _hear_catalog_word(word: Dictionary) -> void:
	if not _can_browse_collection() or not _age_catalog.visible or _age_catalog.scroll.is_scrolling():
		return
	audio.interact(model.theme_id)
	audio.say("res://" + str(word.audio))
	_announce_status(str(word.text) + (". " + str(word.meaning) if word.has("meaning") else ""))


func _back_from_collection() -> void:
	if _can_browse_collection():
		_hide_collection()


func _refresh_age_choices() -> void:
	for id in _age_buttons:
		_age_buttons[id].set_pressed_no_signal(int(id) == _catalog_age)
		_age_buttons[id].set("accessibility_description", "Preview: complete the previous age's words to unlock" if int(id) > growth.learning_age() else "Review this age's words")
	_age_notice.text = "Preview only. Complete your current age's words to unlock this set." if _catalog_age > growth.learning_age() else "%d correct answers in a row master a word. A mistake resets that word; earned Lv and age stay." % GrowthState.MASTERY_STREAK
	if _growth_save_failed:
		_age_notice.text = "Learning progress could not be saved. Return to the game and choose Retry saving."
	_refresh_growth()


func _build_collection() -> void:
	_refresh_collection()
	_layout_collection()


func _can_choose_world() -> bool:
	# Learning-path selection owns the current theme. Historical preferences and
	# reward identities remain available for save compatibility.
	return false


func _choose_world(id: String) -> void:
	if not _can_choose_world():
		return
	if model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty()):
		return
	choose_theme(id)


func _sync_collected_rewards() -> void:
	collected_rewards = medal_progress.legacy_rewards.duplicate()
	for id in medal_progress.counts:
		if medal_progress.count_for(id) > 0:
			collected_rewards[id] = true


func _refresh_collection() -> void:
	_sync_collected_rewards()
	_refresh_age_choices()
	if collection_page.visible:
		_age_choices.visible = not _collection_professional
		_age_catalog.visible = not _collection_professional
		_professional_library.visible = _collection_professional
		if _collection_professional:
			_professional_library.set_progress(professional.session.snapshot())
		else:
			_show_age_catalog()
	_layout_collection()


func _collection_rails() -> Array[ReviewScroll]:
	var rails: Array[ReviewScroll] = []
	for rail in [_age_scroll]:
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


func new_round(seed_value: int = -1, repeat_lesson: bool = false, adventure_id: String = "", next_mode: String = "", required_word_id: String = "", resume_saved_treasure: bool = true, prepared_content: Dictionary = {}, source_id: String = "") -> bool:
	if _rebuilding:
		return false
	_close_finish_confirmation(true, false)
	var requested_mode: String = next_mode if not next_mode.is_empty() else _mode_id
	if not MODES.has(requested_mode):
		requested_mode = "match"
	var next_context: Dictionary = _desired_learning_context(requested_mode) if prepared_content.is_empty() else prepared_content.context
	var is_professional: bool = next_context.get("track") == "professional"
	if is_professional and prepared_content.is_empty():
		_pending_professional_round = [seed_value, repeat_lesson, adventure_id, requested_mode, required_word_id, resume_saved_treasure]
		professional.request(next_context, seed_value)
		return false
	if not is_professional and not growth.ready:
		_growth_save_failed = true
		_refresh()
		_layout()
		return false
	if not is_professional and not vocabulary_loader.is_ready(growth.learning_age()):
		_wait_for_vocabulary([seed_value, repeat_lesson, adventure_id, next_mode, required_word_id, resume_saved_treasure])
		return false
	var phrase_dependencies: Array = _vocabulary_catalog.get("ages", {}).get(str(growth.learning_age()), {}).get("word_ids", [])
	var content: Dictionary = prepared_content if is_professional else LearningContent.resolve_growth(next_context,
		_learning_words(requested_mode == "phrase"), phrase_dependencies)
	if not content.ok:
		_show_error(content.error)
		return false
	if is_professional:
		if not professional.can_claim(int(professional.pending.get("selection", -1)), source_id):
			return false
		var problem: String = _preflight_professional_round(content, seed_value)
		if not problem.is_empty():
			professional.error = problem
			professional.phase = "failed"
			_refresh_learning_home()
			return false
	_coin_flight.sync(coin_wallet.balance)
	if not _settle_pair_reward():
		_refresh()
		return false
	if not _settle_jelly_round():
		return false
	if not _settle_pop_reward():
		return false
	if is_professional:
		var state: Dictionary = professional.session.snapshot()
		if state.source_id != source_id or not state.ready or state.blocked:
			return false
	if resume_saved_treasure and _is_jelly_mode() and (next_mode.is_empty() or next_mode == _mode_id) and _jelly_rewards.has_pending():
		_hide_mode_menu(false, false)
		_stop_round_celebration()
		_show_jelly_rewards()
		return false
	_hide_mode_menu(false, false)
	if not _stop_pop_listening():
		return false
	_stop_round_celebration()
	_settling_chest = true
	audio.stop_chest_performance()
	if model.phase == "won" and model.chest_earned and model.chest_state == "closed":
		_open_chest()
	if model.chest_state == "opening":
		chest.finish_immediately()
	_settling_chest = false
	if (_save_error and (not _pending_fragment.is_empty() or model.chest_state == "opened")) or (model.phase == "won" and model.chest_earned and model.chest_state != "opened"):
		_announce_status("Your progress is waiting to be saved. Choose Retry saving.")
		return false
	_rebuilding = true
	if is_professional:
		# Claim before clearing any current views. This transfers a round lease
		# which later policy cancellation cannot revoke; the old lease remains
		# pinned until its views and audio have dropped their references below.
		content = professional.claim(int(professional.pending.get("selection", -1)), source_id)
		if not content.get("ok", false):
			_rebuilding = false
			_show_error(str(content.get("error", "This course selection changed.")))
			return false
	_stop_voice()
	_pop.stop()
	_pop_rewards.pause()
	_pop_rewards_shown = false
	_pop_rewards.set_result_context({})
	_controller_holding_pop_chest = false
	_jelly.stop()
	_word_jelly.stop()
	_word_jelly_credits.clear()
	_professional_library.clear()
	_learning_backdrop.clear()
	_mode_panel.apply_learning_art({}, true)
	_jelly_rewards.pause()
	_jelly_rewards_shown = false
	_jelly_rewards.set_result_context({})
	_restore_jelly_reward_host()
	_controller_holding_jelly_chest = false
	if not next_mode.is_empty():
		_mode_id = next_mode if MODES.has(next_mode) else "match"
	elif not MODES.has(_mode_id):
		_mode_id = "match"
	_memory.stop()
	_phrase.stop()
	duck.settle()
	_pending_fragment.clear()
	_pending_coin_reward.clear()
	_save_error = not _progress_ready
	feedback_timer.stop()
	feedback_timer.paused = false
	chest.clear()
	_cancel_chest_hold()
	_finish_chest_drag()
	audio.halt()
	_stop_feedback_animations()
	_last_phase = ""
	# Drop old controls/resources before releasing the claimed media lease.
	_match_connections.clear()
	for button in cards.values():
		grid.remove_child(button)
		button.free()
	cards.clear()
	if is_professional:
		ProfessionalMedia.release(str(content.get("previous_media_scope", "")))
	else:
		professional.leave()
	var prepared: bool = model.reset(content.words, seed_value, repeat_lesson, adventure_id,
		required_word_id, str(growth.learning_age()), true, next_context) if _mode_id in ["match", "memory"] \
		else model.prepare_activity(_mode_id, str(growth.learning_age()), seed_value, repeat_lesson, next_context)
	if not prepared:
		_rebuilding = false
		_show_error(model.error)
		return false
	_round_context = LearningContext.freeze(next_context)
	_round_content = content
	if _has_entered_game or is_professional:
		_home_context = next_context.duplicate(true)
		if not is_professional:
			professional.store.request("context", _home_context)
	_round_id = source_id if is_professional else GrowthState.make_round_id()
	_professional_assisted.clear()
	_professional_collections.clear()
	_word_jelly.game.commit_collection = _commit_professional_collection if is_professional else Callable()
	if _mode_id == "word_jelly" and not is_professional:
		_round_id = "word_jelly:" + _round_id
	_clear_reward_confetti()
	_pair_words.clear()
	_pair_proposed_pair = model.chest_reward_pair
	_pair_save_failed = false
	_pair_settlement_pending = false
	_pair_reward.clear()
	if _mode_id in ["match", "memory"]:
		_pair_reward.configure(_round_id, JellyRewardProgress.theme_for_tier(1), data.chests, reduced_motion)
		_sync_pair_reward()
	_memory_attempt = 0
	_celebration_seen_id = ""
	_round_result.clear()
	_jelly_reward_saved = false
	_jelly_reward_theme = ""
	# Reward/audio compatibility stays on an existing identity; learning artwork
	# and palette belong to the automatically selected course theme.
	model.set_theme(str(content.get("theme_profile", {}).get("rewards", {}).get("legacy_theme_id", "spring")))
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
		if not _phrase.configure(content.words, str(growth.learning_age()), model.theme_id, seed_value, content.expressions if is_professional else []):
			_rebuilding = false
			_show_error(_phrase.game.error)
			return false
	if _mode_id == "pop":
		_configure_pop(seed_value, content.words)
		if resume_saved_treasure and _pop_rewards.has_pending():
			_pop_rewards.configure_saved(data.chests, reduced_motion)
			_pop_rewards_shown = true
	if _is_jelly_mode():
		_active_jelly().game.practice_weight_for = _practice_weight
		if not _active_jelly().configure(content.words, growth.learning_age(), Data.theme(model.theme_id), data.chests, reduced_motion, seed_value):
			_rebuilding = false
			_show_error(_active_jelly().game.error)
			return false
		if resume_saved_treasure and _jelly_rewards.has_pending():
			_jelly_rewards.configure_saved(data.chests, reduced_motion)
			_jelly_rewards_shown = true
	_rebuilding = false
	_refresh()
	_layout()
	return true


func choose_mode(id: String) -> void:
	if not _mode_menu_open() or _page_hidden or not MODES.has(id) or collection_page.visible or model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty()):
		return
	_has_entered_game = true
	if id == _mode_id and not _current_round_ended() and LearningContext.same_round(_round_context, _desired_learning_context(id)):
		if _professional_input_blocked():
			_resume_professional_source = _round_id
			professional.cancel()
			return
		_hide_mode_menu(false, true)
		_refresh()
		_default_focus().grab_focus()
		if id != "pop" and not _voice_mode:
			audio.interact(model.theme_id)
		return
	# A failed reward settlement must expose the current game's save retry.
	if new_round(-1, id != _mode_id, "", id):
		_default_focus().grab_focus()
		if id == "pop":
			_start_pop_listening()
		elif not _page_hidden:
			# The mode gesture restores playback after new_round silences the
			# previous mode. Voice Pop stays quiet while its microphone is open.
			audio.interact(model.theme_id)
			if id == "phrase":
				_start_phrase_prompt()


func _configure_pop(seed_value: int = -1, resolved_words: Array = []) -> void:
	_stop_round_celebration()
	_celebration_seen_id = ""
	if _round_context.get("track") != "professional":
		_round_id = GrowthState.make_round_id()
	_clear_reward_confetti()
	_round_result.clear()
	_pop_reward_saved = false
	_pop_reward_theme = ""
	var pool: Array = (resolved_words if not resolved_words.is_empty() else _learning_words()).filter(func(word: Dictionary) -> bool:
		return LearningWord.professional(word, "pop") if word.get("track") == "professional" else Data.word_age(word) <= growth.learning_age() and Data.supports_mode(word, "pop"))
	_pop.game.practice_weight_for = _practice_weight
	_pop.configure(pool, reduced_motion, seed_value)
	_pop.apply_theme(Data.theme(model.theme_id), data.chests)
	_pop.retry_button.text = "Play again"


func _preflight_professional_round(content: Dictionary, seed_value: int) -> String:
	var mode: String = content.context.mode
	if mode in ["match", "memory"]:
		var probe := Model.new()
		return "" if probe.reset(content.words, seed_value, false, "", "", "", true, content.context) else probe.error
	if mode == "phrase":
		var probe := PhraseGame.PhraseGameModel.new()
		return "" if probe.reset_professional(content.expressions, seed_value) else probe.error
	if mode == "pop":
		var probe := VoicePop.PopModel.new()
		return "" if probe.configure(content.words, seed_value) else probe.error
	var probe = WordJelly.WordModel.new() if mode == "word_jelly" else JellyMatch.JellyMatchModel.new()
	return "" if probe.configure(content.words, 3, seed_value) else probe.error


func _is_jelly_mode() -> bool:
	return _mode_id in ["jelly", "word_jelly"]


func _active_jelly():
	return _word_jelly if _mode_id == "word_jelly" else _jelly


func _jelly_interaction_allowed() -> bool:
	return _is_jelly_mode() and not _jelly_rewards_shown and not _round_celebration_active() \
		and not _professional_input_blocked() and not _rebuilding and not _page_hidden and not _speech_debug_active \
		and not collection_page.visible and not _mode_menu_open() and not _finish_confirmation_open()


func _finish_confirmation_open() -> bool:
	return is_instance_valid(_finish_confirmation) and _finish_confirmation.visible


func _publish_finish_confirmation() -> void:
	if _finish_confirmation_open():
		_publish_jelly(_active_jelly().snapshot())


func _request_jelly_finish(source_mode: String) -> void:
	if source_mode != _mode_id or not _jelly_interaction_allowed() \
		or not _active_jelly()._can_play() or _active_jelly()._pointer != JellyMatch.NO_POINTER:
		return
	_finish_confirmation_mode = _mode_id
	_finish_confirmation_round = _round_id
	_finish_confirmation_generation = _active_jelly()._generation
	_finish_confirmation.configure(Data.theme(model.theme_id), reduced_motion)
	_finish_confirmation.open()
	_sync_reward_confetti()
	_on_input_canceled()
	_stop_controller_actions()
	_controller_accept_needs_release = true
	audio.stop_voice()
	_sync_jelly()
	_finish_confirmation_focus_modes.clear()
	for control in find_children("*", "Control", true, false):
		if not _finish_confirmation.is_ancestor_of(control):
			_finish_confirmation_focus_modes[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
	_finish_confirmation.keep_playing_button.grab_focus()
	_announce_status("Finish this round? Keep playing, or Finish to see your score. Your collected rewards will be kept.")
	_publish_jelly(_active_jelly().snapshot())


func _close_finish_confirmation(resume_game: bool = true, restore_focus: bool = true) -> void:
	if not _finish_confirmation_open():
		return
	_finish_confirmation.close()
	_sync_reward_confetti()
	_finish_confirmation_mode = ""
	_finish_confirmation_round = ""
	_finish_confirmation_generation = -1
	for control in _finish_confirmation_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = _finish_confirmation_focus_modes[control]
	_finish_confirmation_focus_modes.clear()
	_stop_controller_actions()
	if resume_game:
		_sync_jelly()
	if restore_focus and not _page_hidden:
		_default_focus().grab_focus()


func _cancel_jelly_finish() -> void:
	if not _finish_confirmation_open() or _page_hidden:
		return
	_close_finish_confirmation()
	_announce_status("Keep playing.")


func _confirm_jelly_finish() -> void:
	if not _finish_confirmation_open() or _page_hidden:
		return
	var same_round: bool = _is_jelly_mode() and _mode_id == _finish_confirmation_mode \
		and _round_id == _finish_confirmation_round \
		and _active_jelly()._generation == _finish_confirmation_generation
	_close_finish_confirmation(false, false)
	if same_round and _jelly_interaction_allowed():
		# Settle while paused so confirming cannot advance a queued motion or reward.
		_active_jelly().game.finish_round()
	else:
		_sync_jelly()


func _sync_jelly() -> void:
	if not is_instance_valid(_jelly):
		return
	_sync_settlement_dialog()
	var allowed: bool = _jelly_interaction_allowed()
	_jelly.pause(not allowed or _mode_id != "jelly")
	_word_jelly.pause(not allowed or _mode_id != "word_jelly")
	_jelly_backdrop.visible = _round_context.get("track") != "professional" and _is_jelly_mode() and (_active_jelly().visible or (_jelly_rewards_shown and not _jelly_rewards._result_context.is_empty())) and not _page_hidden and not collection_page.visible
	_learning_backdrop.visible = _learning_backdrop.has_art() and not _page_hidden and not collection_page.visible and not _mode_menu_open()
	var career_backdrop: bool = _round_context.get("track") == "professional" and _learning_backdrop.visible
	_jelly.set_learning_backdrop(career_backdrop)
	_word_jelly.set_learning_backdrop(career_backdrop)
	_pop.set_learning_backdrop(career_backdrop)
	_phrase.set_learning_backdrop(career_backdrop)
	_jelly_backdrop.set_ambient_active(allowed and _active_jelly().game.phase == "playing")
	if not allowed:
		audio.stop_jelly_sounds()
		if _mode_id == "word_jelly":
			audio.stop_pair_feedback()
	if _jelly_rewards_shown and _is_jelly_mode() and not _page_hidden and not collection_page.visible and not _mode_menu_open():
		_jelly_rewards.resume()
	if _settlement_dialog_open() and not _valid_focus(get_viewport().gui_get_focus_owner()):
		_default_focus().grab_focus()
	_publish_jelly(_active_jelly().snapshot())
	_publish_jelly_rewards(_jelly_rewards.snapshot())


func _jelly_hear(word: Dictionary, source_mode: String = "") -> void:
	if (source_mode.is_empty() or source_mode == _mode_id) and _jelly_interaction_allowed():
		audio.interact(model.theme_id)
		audio.say("res://" + str(word.audio))


func _word_jelly_merged(word: Dictionary) -> void:
	if _mode_id == "word_jelly" and _jelly_interaction_allowed():
		audio.interact(model.theme_id)
		audio.say_queued("res://" + str(word.audio))


func _jelly_audio(cue: String, source_mode: String = "") -> void:
	if (not source_mode.is_empty() and source_mode != _mode_id) or not _jelly_interaction_allowed():
		return
	if cue == "danger_end":
		audio.stop_jelly_danger()
	elif cue in ["wrong", "powerup_wrong"]:
		audio.play_pair_feedback(false)
	elif cue == "powerup_success":
		audio.stop_jelly_danger()
		audio.play_pair_feedback(true)
	elif cue in ["powerup_fragment_launch", "fragment_appear"]:
		audio.play_fragment_appearance()
	elif cue in ["powerup_fragment", "fragment_arrive"]:
		audio.play_fragment_arrival()
	else:
		if cue == "pick" and _mode_id == "word_jelly" and not _word_jelly.game.powerup_active():
			audio.stop_pair_feedback()
		audio.play_jelly_cue(cue)


func _purchase_word_jelly_powerup(event_id: String, kind: String, price: int) -> Dictionary:
	if _mode_id != "word_jelly" or not _jelly_interaction_allowed() or event_id.is_empty() \
		or not WordJelly.WordModel.POWERUP_PRICES.has(kind):
		return {"ok": false, "error": "This powerup cannot be used yet."}
	if not coin_wallet.ready or not coin_wallet.error.is_empty():
		coin_wallet.load_state()
	var receipt: String = _round_id + ":" + event_id
	# An old callback still refers to its paid price after the next price rises.
	# The wallet rechecks the saved snapshot before accepting that duplicate.
	if price != _word_jelly.game.powerup_price(kind) and not coin_wallet.has_purchase(receipt, price):
		return {"ok": false, "error": "This powerup price is no longer current."}
	var result: Dictionary = coin_wallet.spend(receipt, price)
	_coin_counter.available = coin_wallet.ready and coin_wallet.error.is_empty()
	if bool(result.get("ok", false)) and not bool(result.get("duplicate", false)):
		_coin_flight.sync(coin_wallet.balance)
		_announce_status("%s purchased for %d coins. Total: %d coins." % ["Auto merge" if kind == "auto_merge" else "Treasure", price, coin_wallet.balance])
	elif bool(result.get("duplicate", false)):
		_announce_status("This powerup purchase was already processed. No more coins were spent.")
	elif coin_wallet.balance < price:
		_announce_status("Not enough coins. This powerup costs %d coins." % price)
	else:
		_announce_status("Your purchase could not be saved. No coins were spent.")
	_coin_counter._update_description()
	_coin_counter.queue_redraw()
	_publish_coins()
	return result


func _jelly_growth_answer(id: String, words: Array[String], correct: bool, source_mode: String = "") -> void:
	if (source_mode.is_empty() or source_mode == _mode_id) and _jelly_interaction_allowed():
		_record_growth(id, words, correct)


func _credit_word_jelly(event_id: String, amount: int) -> Dictionary:
	if _mode_id != "word_jelly" or not _jelly_interaction_allowed() or event_id.is_empty() \
		or amount <= 0 or amount % CoinWallet.COINS_PER_TIER != 0:
		return {"ok": false, "duplicate": false, "amount": 0, "error": "This word cannot be collected yet."}
	var receipt: String = _round_id + ":" + event_id
	var credit: Dictionary = _credit_coins(receipt, int(amount / CoinWallet.COINS_PER_TIER))
	if bool(credit.get("ok", false)):
		# Keep the first committed result until the view finishes removing the tile.
		# An idempotent retry must not replace its pending visual amount with zero.
		if not _word_jelly_credits.has(event_id):
			_word_jelly_credits[event_id] = credit
	else:
		_refresh()
	return credit


func _word_jelly_collected(event_id: String, _word: Dictionary, _amount: int, _fragments: int, origin: Vector2) -> void:
	if _mode_id != "word_jelly" or not _word_jelly_credits.has(event_id):
		return
	var reward: Dictionary = _word_jelly_credits[event_id]
	_word_jelly_credits.erase(event_id)
	if not _page_hidden and not collection_page.visible and not _mode_menu_open():
		_coin_flight.reduced_motion = reduced_motion
		_coin_flight.present(_round_id + ":" + event_id, reward, origin, true)
	else:
		_coin_flight.sync(coin_wallet.balance)
	if int(reward.get("amount", 0)) > 0:
		_announce_status("Word collected. %d coins. Total: %d coins." % [reward.amount, coin_wallet.balance])


func _jelly_finished(result: Dictionary, source_mode: String = "") -> void:
	if (not source_mode.is_empty() and source_mode != _mode_id) or not _is_jelly_mode() or not _round_result.is_empty():
		return
	_close_finish_confirmation(false, false)
	_round_result = result.duplicate(true)
	var tier: int = int(result.get("chest_tier", 0))
	_jelly_reward_theme = JellyRewardProgress.theme_for_tier(tier) if tier > 0 else model.theme_id
	audio.stop_jelly_sounds()
	if _mode_id == "word_jelly":
		audio.stop_pair_feedback()
		audio.stop_voice()
	var count: int = int(result.get("chest_count", 0))
	if count > 0:
		_save_jelly_round_reward()
		_jelly_rewards.pause()
	if _jelly_settling:
		return
	_show_jelly_rewards()
	_announce_status(("Game over. " if str(result.get("reason", "")) == "danger" else "Round complete. ") + _jelly_result_summary())
	_refresh()


func _jelly_result_summary() -> String:
	var summary: String = "Round results. Score: %d. Chests: %d." % [int(_round_result.get("score", 0)), int(_round_result.get("chest_count", 0))]
	var tier: int = int(_round_result.get("chest_tier", 0))
	return summary + " Chest level: %d." % tier if tier > 0 else summary


func _save_jelly_round_reward() -> bool:
	var count: int = int(_round_result.get("chest_count", 0))
	if count <= 0 or _jelly_reward_saved:
		return true
	# Keep the earned tier durable before presenting or collecting the reward.
	_jelly_reward_saved = _jelly_rewards.configure(_round_id, 1, _jelly_reward_theme, data.chests, reduced_motion,
		int(_round_result.get("chest_tier", 0)))
	return _jelly_reward_saved


func _settle_jelly_round() -> bool:
	if not _is_jelly_mode() or not is_instance_valid(_active_jelly()):
		return true
	_jelly_settling = true
	_active_jelly().cancel_input()
	_active_jelly().game.finish_round()
	_jelly_settling = false
	var reward_saved: bool = _save_jelly_round_reward()
	if not reward_saved or _jelly_rewards._save_failed or _jelly_rewards._unsaved_index >= 0:
		_hide_mode_menu(false, false)
		_stop_round_celebration()
		_show_jelly_rewards()
		_announce_status("Your treasure is waiting to be saved. Choose Retry save.")
		return false
	return true


func _replay_jelly() -> void:
	if not _is_jelly_mode() or _active_jelly().game.phase != "finished" or _rebuilding \
			or _round_celebration_active() or _page_hidden or _speech_debug_active \
			or collection_page.visible or _mode_menu_open():
		return
	_controller_holding_jelly_chest = false
	if not _settle_completed_round_rewards():
		return
	_coin_flight.sync(coin_wallet.balance)
	if new_round(-1, false, "", _mode_id, "", false):
		audio.interact(model.theme_id)
		_default_focus().grab_focus()


func _show_jelly_rewards() -> void:
	if not _is_jelly_mode() or _round_celebration_active() or collection_page.visible or _page_hidden:
		return
	if int(_round_result.get("chest_count", 0)) > 0:
		_save_jelly_round_reward()
	elif _jelly_round_ended():
		_jelly_rewards.configure_empty_result(_round_id, data.chests, reduced_motion)
	elif not _jelly_rewards.configure_saved(data.chests, reduced_motion) and not _jelly_rewards.has_pending():
		return
	_jelly_rewards.set_result_context(_round_result if _active_jelly().game.phase == "finished" else {}, _round_id)
	if _jelly_round_ended():
		_settlement_dialog.configure(_jelly_rewards, Data.theme(model.theme_id), reduced_motion,
			int(_round_result.get("chest_count", 0)) > 0,
			"Game over" if str(_round_result.get("reason", "")) == "danger" else "Round complete")
		_stop_controller_actions()
		_controller_accept_needs_release = _controller_accept_is_pressed()
	_active_jelly().cancel_input()
	audio.halt()
	_jelly_rewards_shown = true
	if _jelly_round_ended() and not _mode_menu_open():
		_settlement_dialog.open(true)
	_refresh()
	_default_focus().grab_focus()


func _hide_jelly_rewards() -> void:
	if _jelly_round_ended():
		_show_mode_menu()
		return
	_coin_flight.sync(coin_wallet.balance)
	_jelly_rewards.pause()
	_controller_holding_jelly_chest = false
	_jelly_rewards_shown = false
	# A restored reward batch precedes a fresh board.
	if _jelly_rewards.has_pending():
		_show_mode_menu()
	else:
		_refresh()
	_publish_jelly_rewards(_jelly_rewards.snapshot())
	_default_focus().grab_focus()


func _jelly_round_ended() -> bool:
	return _is_jelly_mode() and not _round_result.is_empty() and _active_jelly().game.phase == "finished"


func _settlement_dialog_open() -> bool:
	return is_instance_valid(_settlement_dialog) and _settlement_dialog.is_visible_in_tree()


func _sync_settlement_dialog() -> void:
	if not is_instance_valid(_settlement_dialog):
		return
	var content: Control = null
	var has_chest: bool = false
	var title: String = "Round complete"
	if _round_celebration_active():
		content = _round_celebration
		has_chest = int(_round_celebration.snapshot().chest_count) > 0
	elif _jelly_round_ended() and _jelly_rewards_shown:
		content = _jelly_rewards
		has_chest = int(_round_result.get("chest_count", 0)) > 0
		title = "Game over" if str(_round_result.get("reason", "")) == "danger" else "Round complete"
	elif _mode_id == "pop" and _pop_rewards_shown:
		content = _pop_rewards
		has_chest = not _pop_rewards._cards.is_empty()
	elif _mode_id in ["match", "memory", "phrase"] and model.phase == "won" and not _pair_reward_revealing():
		content = _single_result
		has_chest = model.chest_earned
	if content != null and not _mode_menu_open() and not collection_page.visible and not _page_hidden and not _rebuilding and not _speech_debug_active:
		if _settlement_dialog._room != content or _settlement_dialog._has_chest != has_chest or _settlement_dialog._palette.get("id", "") != model.theme_id or _settlement_dialog._reduced_motion != reduced_motion:
			_settlement_dialog.configure(content, Data.theme(model.theme_id), reduced_motion, has_chest, title)
		content.show()
		_settlement_dialog.open(true)
		if content == _pop_rewards and _pop_rewards._paused:
			_pop_rewards.resume()
	else:
		_settlement_dialog.close()
	if is_instance_valid(_coin_flight):
		_coin_flight.z_index = 95 if _settlement_dialog_open() else 85


func _restore_jelly_reward_host() -> void:
	_settlement_dialog.close()
	if _jelly_rewards.get_parent() != _jelly_rewards_parent:
		_jelly_rewards.reparent(_jelly_rewards_parent, false)
	_coin_flight.z_index = 85


func _publish_jelly(state: Dictionary, source_mode: String = "") -> void:
	if _host == null or (not source_mode.is_empty() and source_mode != _mode_id):
		return
	var value: Dictionary = state.duplicate(true)
	value["visible"] = _is_jelly_mode() and _active_jelly().is_visible_in_tree() and not _jelly_rewards_shown and not _round_celebration_active() and not collection_page.visible and not _page_hidden and not _mode_menu_open()
	value["mode"] = _mode_id
	value["round_id"] = _round_id
	value["finish_confirmation"] = _finish_confirmation.snapshot() if is_instance_valid(_finish_confirmation) else {"visible": false}
	value["game_over"] = _settlement_dialog.snapshot() if is_instance_valid(_settlement_dialog) else {"visible": false}
	_host.jellyStatus(JSON.stringify(value))


func _publish_jelly_rewards(state: Dictionary) -> void:
	# Saving or opening a chest can disable the focused action or rebuild it.
	if _settlement_dialog_open() and not _jelly_rewards._paused and not _valid_focus(get_viewport().gui_get_focus_owner()):
		_default_focus().grab_focus()
	if _host != null:
		var value: Dictionary = state.duplicate(true)
		value["visible"] = _is_jelly_mode() and _jelly_rewards_shown and not collection_page.visible and not _page_hidden and not _mode_menu_open()
		value["mode"] = _mode_id
		value["game_over"] = _settlement_dialog.snapshot() if is_instance_valid(_settlement_dialog) else {"visible": false}
		_host.jellyRewardStatus(JSON.stringify(value))


func _start_pop_listening() -> void:
	if _professional_input_blocked() or _mode_id != "pop" or _round_celebration_active() or _pop_rewards_shown or collection_page.visible or _page_hidden or _mode_menu_open():
		return
	if _pop.game.phase == "finished":
		# Replay keeps unopened rewards saved without restoring the treasure room.
		if not new_round(-1, false, "", "pop", "", false):
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


func _pop_finished(result: Dictionary) -> void:
	if not _stop_pop_listening():
		_announce_status("Microphone could not be stopped. Close this tab to stop voice input.")
	audio.halt()
	if _mode_id != "pop" or not _round_result.is_empty():
		return
	_round_result = result.duplicate(true)
	var tier: int = int(result.get("chest_tier", 0))
	_pop_reward_theme = JellyRewardProgress.theme_for_tier(tier) if tier > 0 else model.theme_id
	if int(result.get("chest_count", 0)) > 0:
		_save_pop_round_reward()
		_pop_rewards.pause()
	if not _pop_settling:
		_show_pop_rewards()
	_refresh()


func _save_pop_round_reward() -> bool:
	if int(_round_result.get("chest_count", 0)) <= 0 or _pop_reward_saved:
		return true
	_pop_reward_saved = _pop_rewards.configure(_round_id, 1, _pop_reward_theme, data.chests, reduced_motion,
		int(_round_result.get("chest_tier", 0)))
	return _pop_reward_saved


func _settle_pop_reward() -> bool:
	if _mode_id != "pop":
		return true
	if _pop.game.phase in ["running", "paused"]:
		_pop_settling = true
		_pop.finish_round()
		_pop_settling = false
	if not _save_pop_round_reward() or _pop_rewards._save_failed or _pop_rewards._unsaved_index >= 0:
		_hide_mode_menu(false, false)
		_stop_round_celebration()
		_show_pop_rewards()
		_announce_status("Your treasure is waiting to be saved. Choose Retry save.")
		return false
	return true


func _pop_status_changed(snapshot: Dictionary) -> void:
	if _mode_id == "pop" and _host != null:
		_host.popStatus(JSON.stringify(snapshot))


func _pop_chest_earned(_count: int) -> void:
	if _mode_id != "pop" or collection_page.visible or _page_hidden:
		return
	_announce_status("Chest level %d!" % _pop.game.chest_tier)


func _pop_reward_cue(cue: String) -> void:
	if _mode_id != "pop" or collection_page.visible or _page_hidden or _mode_menu_open():
		return
	audio.interact(model.theme_id, false)
	if cue == "loot":
		audio.play_fragment_appearance()
	elif cue == "fragment_arrive":
		audio.play_fragment_arrival()
	else:
		audio.play_jelly_cue(cue)


func _show_pop_rewards() -> void:
	if _mode_id != "pop" or collection_page.visible or _page_hidden:
		return
	if not _stop_pop_listening():
		return
	if _pop.game.phase == "finished":
		if int(_round_result.get("chest_count", 0)) > 0:
			_save_pop_round_reward()
		else:
			_pop_rewards.configure_empty_result(_round_id, data.chests, reduced_motion)
	else:
		var restored: bool = _pop_rewards.configure_saved(data.chests, reduced_motion)
		if not restored and not _pop_rewards.has_pending():
			return
	_pop_rewards.set_result_context(_round_result if _pop.game.phase == "finished" else {}, _round_id)
	_pop.cancel_result_input()
	_stop_controller_actions()
	_controller_accept_needs_release = _controller_accept_is_pressed()
	audio.halt()
	_pop_rewards_shown = true
	_sync_settlement_dialog()
	_refresh()
	_pop_rewards.resume()
	_default_focus().grab_focus()
	_publish_pop_rewards(_pop_rewards.snapshot())


func _hide_pop_rewards() -> void:
	if _pop.game.phase == "finished" or _pop_rewards.has_pending():
		_show_mode_menu()
		return
	# Restored treasure precedes an unstarted round. Once claimed, Back returns
	# to its microphone gate instead of trapping the player in the opened batch.
	_coin_flight.sync(coin_wallet.balance)
	_pop_rewards.pause()
	_controller_holding_pop_chest = false
	_pop_rewards_shown = false
	_refresh()
	_publish_pop_rewards(_pop_rewards.snapshot())
	_default_focus().grab_focus()


func _replay_pop() -> void:
	if _mode_id != "pop" or _pop.game.phase != "finished" or _rebuilding or _page_hidden \
		or _speech_debug_active or collection_page.visible or _mode_menu_open():
		return
	_controller_holding_pop_chest = false
	if not _settle_completed_round_rewards():
		return
	_coin_flight.sync(coin_wallet.balance)
	if new_round(-1, false, "", "pop", "", false):
		_default_focus().grab_focus()


func _publish_pop_rewards(snapshot: Dictionary) -> void:
	if _host != null:
		var status: Dictionary = snapshot.duplicate(true)
		status["visible"] = _pop_rewards_shown and _mode_id == "pop" and not collection_page.visible and not _page_hidden and not _mode_menu_open()
		status["game_over"] = _settlement_dialog.snapshot()
		_host.popRewardStatus(JSON.stringify(status))


func _pop_chest_audio(action: String, theme_id: String, progress: float) -> void:
	if action == "stop":
		audio.stop_chest_performance()
	elif action in ["cancel", "release"]:
		audio.stop_chest_charge()
	elif action == "finish":
		audio.finish_chest_motion()
	elif ((_mode_id == "pop" and _pop_rewards_shown) or (_is_jelly_mode() and _jelly_rewards_shown)) and not _page_hidden and not collection_page.visible:
		match action:
			"prepare":
				audio.interact(theme_id)
				audio.stop_voice()
				audio.prepare_chest(theme_id)
			"charge": audio.set_chest_charge(progress)
			"tension": audio.set_chest_tension(progress)
			"reward": audio.chest_reward(theme_id, progress > 0.0)


func _reward_confetti_allowed() -> bool:
	return is_visible_in_tree() and not _page_hidden and not _rebuilding and not _speech_debug_active \
		and is_instance_valid(collection_page) and not collection_page.visible and not _mode_menu_open() \
		and not _finish_confirmation_open() and not (is_instance_valid(_vocabulary_prompt) and _vocabulary_prompt.visible)


func _sync_reward_confetti() -> void:
	if not is_instance_valid(_reward_confetti):
		return
	if reduced_motion and _reward_confetti.is_active():
		_reward_confetti.clear()
	_reward_confetti.set_paused(reduced_motion or not _reward_confetti_allowed())


func _clear_reward_confetti() -> void:
	_confetti_reward_keys.clear()
	if is_instance_valid(_reward_confetti):
		_reward_confetti.clear()


func _request_reward_confetti(round_id: String, mode: String, tier: int) -> void:
	if round_id.is_empty() or round_id != _round_id or mode != _mode_id or tier <= 0 \
		or reduced_motion or not _reward_confetti_allowed():
		return
	# The same earned chest may later appear in a round finale. Its paper burst
	# belongs to the reward, not to every presentation of that reward.
	var key: String = "%s:%s:%d" % [round_id, mode, tier]
	if _confetti_reward_keys.has(key):
		return
	_confetti_reward_keys[key] = true
	_sync_reward_confetti()
	_reward_confetti.burst(key)


func _fragment_confetti_requested(mode: String) -> void:
	if mode != _mode_id or mode not in ["jelly", "word_jelly", "pop"]:
		return
	var presentation: Dictionary = _active_jelly()._reward_presentation.snapshot() if mode in ["jelly", "word_jelly"] else _pop._reward_presentation.snapshot()
	_request_reward_confetti(_round_id, mode, int(presentation.get("tier", 0)))


func _pair_confetti_requested(round_id: String) -> void:
	if _mode_id in ["match", "memory"]:
		_request_reward_confetti(round_id, _mode_id, 1)


func _round_confetti_requested(round_id: String) -> void:
	if _mode_id == "phrase" or not _round_celebration.is_active() or round_id != _round_celebration.current_round_id():
		return
	var state: Dictionary = _round_celebration.snapshot()
	if int(state.chest_count) > 0:
		_request_reward_confetti(round_id, _mode_id, maxi(1, int(state.chest_tier)))


func _round_celebration_active() -> bool:
	return is_instance_valid(_round_celebration) and _round_celebration.is_active()


func _round_celebration_allowed() -> bool:
	return _round_celebration_active() and not _page_hidden and not _rebuilding \
		and not _speech_debug_active and not collection_page.visible \
		and not _mode_menu_open()


func _begin_round_celebration(chest_count: int) -> void:
	if _mode_id not in ["match", "memory", "phrase"] \
		or (chest_count <= 0 and _mode_id not in ["match", "memory"]) or _round_id.is_empty() or _celebration_seen_id == _round_id:
		return
	_celebration_seen_id = _round_id
	_celebration_suspended = false
	_stop_controller_actions()
	_controller_accept_needs_release = _controller_accept_is_pressed()
	duck.settle()
	var theme_id: String = model.theme_id
	if _mode_id in ["match", "memory"] and not model.reward_theme.is_empty():
		theme_id = model.reward_theme
	_settlement_dialog.configure(_round_celebration, Data.theme(model.theme_id), reduced_motion, chest_count > 0, "Round complete")
	if not _mode_menu_open() and not collection_page.visible and not _page_hidden:
		_settlement_dialog.open(true)
	_round_celebration.begin(_round_id, theme_id, data.chests, chest_count, reduced_motion, false, -1, 0, _mode_id in ["match", "memory"] and model.chest_earned)
	_round_celebration.set_narration_playing(audio.voice.playing and not audio.muted and audio.available)
	if _round_celebration_allowed():
		_start_round_celebration_audio()
		_announce_status("Every word matched!" if chest_count == 0 else "You did it! Pip is celebrating. You earned a treasure chest!")
	_sync_round_celebration()
	_publish_round_celebration()


func _start_round_celebration_audio() -> void:
	if _page_hidden:
		return
	audio.interact(model.theme_id)
	audio.begin_round_celebration(_round_id)


func _sync_round_celebration() -> void:
	_sync_reward_confetti()
	_sync_pair_presentation()
	if not _round_celebration_active():
		return
	# Reveal the modal parent before resuming its child animation.
	_sync_settlement_dialog()
	var allowed: bool = _round_celebration_allowed()
	if not allowed and not _celebration_suspended:
		_celebration_suspended = true
		_round_celebration.pause()
		audio.stop_round_celebration()
	elif allowed and (_celebration_suspended or _round_celebration.snapshot().paused):
		_celebration_suspended = false
		_round_celebration.set_narration_playing(audio.voice.playing and not audio.muted and audio.available)
		_round_celebration.resume()
		if not _round_celebration.is_ready():
			_start_round_celebration_audio()
	_round_celebration.visible = allowed
	if allowed:
		_round_celebration.set_narration_playing(audio.voice.playing and not audio.muted and audio.available)


func _stop_round_celebration() -> void:
	if is_instance_valid(_round_celebration):
		_round_celebration.stop()
		_round_celebration.hide()
	_celebration_suspended = false
	if is_instance_valid(audio):
		audio.stop_round_celebration()
	_publish_round_celebration()


func _round_celebration_cue(round_id: String, cue: String) -> void:
	if round_id != _round_id or not _round_celebration_allowed():
		return
	audio.play_round_celebration_cue(round_id, cue)


func _on_round_celebration_finished(round_id: String) -> void:
	if round_id != _round_id or not _round_celebration_allowed():
		return
	audio.stop_round_celebration()
	_controller_accept_needs_release = _controller_accept_is_pressed()
	# Finish the entrance in place; the chest itself is the next interaction.
	if int(_round_celebration.snapshot().chest_count) > 0:
		_accept_round_chest(round_id)
		return
	_announce_status("Every word matched! Choose Play again.")
	var target: Control = _default_focus()
	if _valid_focus(target):
		target.grab_focus()
	_publish_round_celebration()


func _accept_round_chest(round_id: String) -> void:
	if round_id != _round_id or not _round_celebration_allowed() or not _round_celebration.is_ready() or _mode_id in ["pop", "jelly", "word_jelly"]:
		return
	if _mode_id in ["match", "memory"] and not model.chest_earned:
		_play_ui_click()
		if new_round():
			_default_focus().grab_focus()
		else:
			_round_celebration.retry_open(round_id)
			_publish_round_celebration()
		return
	_stop_round_celebration()
	_controller_accept_needs_release = _controller_accept_is_pressed()
	if _mode_id == "phrase":
		_phrase.accept_completion()
	else:
		_refresh()
	_layout()
	_default_focus().grab_focus()


func _phrase_completion_requested() -> void:
	if not _phrase_interaction_allowed() or not _phrase.completion_pending:
		return
	_clear_reward_confetti()
	_begin_round_celebration(1)
	_refresh()


func _publish_round_celebration() -> void:
	if _host == null or not is_instance_valid(_round_celebration):
		return
	var state: Dictionary = _round_celebration.snapshot()
	state["mode"] = _mode_id
	var serialized: String = JSON.stringify(state)
	if serialized != _celebration_published:
		_celebration_published = serialized
		_host.celebrationStatus(serialized)


func _phrase_interaction_allowed() -> bool:
	return _mode_id == "phrase" and not _round_celebration_active() and model.phase in ["waiting", "matching", "feedback"] \
		and not _professional_input_blocked() and not _rebuilding and not _page_hidden and not _speech_debug_active and not collection_page.visible \
		and not _mode_menu_open()


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


func _memory_answer(words: Array, correct: bool) -> void:
	if _mode_id != "memory" or collection_page.visible:
		return
	_memory_attempt += 1
	_record_growth("memory-%d" % _memory_attempt, words.map(func(word: Dictionary) -> String: return str(word.id)), correct)
	audio.play_pair_feedback(correct)
	_react_to_gameplay(correct)
	if correct and not words.is_empty():
		_pair_matched(str(words[0].id))


func _memory_finished(won: bool, found: Array) -> void:
	if _mode_id != "memory" or model.phase == "won" or not won or _memory.memory.phase != "won" or found.size() != 5:
		return
	model.phase = "won"
	_refresh()
	_layout()


func _memory_status() -> String:
	return "Memory. %d of 5 pairs grown. %d attempts. %s" % [_memory.memory.matched_word_ids.size(), _memory.memory.attempts, _memory.status_label.text]


func _purchase_memory_peek(ordinal: int, price: int) -> Dictionary:
	if _mode_id != "memory" or _rebuilding or _page_hidden or _mode_menu_open() \
		or collection_page.visible or _round_id.is_empty() or model.phase == "won" \
		or not _memory._can_begin_peek() or _memory.memory.studying \
		or ordinal != _memory.memory.peeks + 1 or price <= 0 or price != _memory.memory.peek_price():
		return {"ok": false, "error": "This reveal cannot be used yet."}
	if not coin_wallet.ready or not coin_wallet.error.is_empty():
		coin_wallet.load_state()
	var receipt: String = _round_id + ":memory-peek:" + str(ordinal)
	var result: Dictionary = coin_wallet.spend(receipt, price)
	_coin_counter.available = coin_wallet.ready and coin_wallet.error.is_empty()
	if bool(result.get("ok", false)):
		# The ordinal also recovers an already-paid reveal after interrupted input.
		_coin_flight.sync(coin_wallet.balance)
	elif str(result.get("reason", "")) == "insufficient":
		_announce_status("Not enough coins. This reveal costs %d coins." % price)
	else:
		_announce_status("Your reveal could not be saved. No coins were spent.")
	_coin_counter._update_description()
	_coin_counter.queue_redraw()
	_publish_coins()
	return result


func _memory_peek_feedback(success: bool, price: int) -> void:
	if success and _round_context.get("track") == "professional":
		for word in model.lesson_words:
			_professional_assisted[str(word.id)] = true
	if _mode_id != "memory" or _page_hidden or _mode_menu_open() or collection_page.visible:
		return
	if not success or price > 0:
		audio.play_pair_feedback(success)
	_publish_growth_view()


func _memory_peek_clock_changed(remaining: float, duration: float) -> void:
	if not is_instance_valid(_memory_peek_countdown):
		return
	var active_changed: bool = (_memory_peek_countdown.remaining > 0.0) != (remaining > 0.0)
	_memory_peek_countdown.configure(remaining, duration, _active_palette, reduced_motion)
	# Memory emits its initial clock while the remaining host controls are building.
	if not is_instance_valid(collection_page) or not active_changed:
		return
	_sync_pair_presentation()
	_layout_pair_reward()


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
	if _mode_id in ["match", "memory"] and model.phase == "won" and not _settling_chest and not _pair_save_failed:
		_sync_pair_reward()
	var pair_revealing: bool = _pair_reward_revealing()
	if _mode_id in ["match", "memory"] and model.phase == "won" and model.chest_state == "closed" and not _settling_chest and not pair_revealing and not _pair_save_failed:
		_begin_round_celebration(1 if model.chest_earned else 0)
	var celebrating: bool = _round_celebration_active()
	var profile: Dictionary = _selected_theme_profile()
	_mode_panel.apply_learning_art(profile, reduced_motion)
	if not _mode_menu_open() and _round_context.get("track") == "professional":
		_learning_backdrop.show_profile(profile, "environment", reduced_motion)
	var theme_key: String = model.theme_id + ":" + str(profile.get("id", ""))
	var theme_changed: bool = _learning_theme_key != theme_key
	if theme_changed:
		_learning_theme_key = theme_key
		_active_palette = Data.theme(model.theme_id)
		for key in profile.get("palette", {}):
			_active_palette[key] = Color(str(profile.palette[key]))
		_mode_panel.apply_learning_palette(_active_palette)
		audio.prepare_chest(model.theme_id)
		# Multi-chest modes keep the theme of their already saved reward batch.
		if _round_celebration_active() and not _mode_id in ["pop", "jelly", "word_jelly"]:
			_round_celebration.apply_theme(model.reward_theme if not model.reward_theme.is_empty() else model.theme_id, data.chests)
	var palette: Dictionary = _active_palette
	_background.color = Style.PAPER.lerp(palette.background, 0.16)
	if theme_changed:
		collection_page.add_theme_stylebox_override("panel", Style.box(_background.color, Color.TRANSPARENT, 0, 0))
	_mode_panel.configure_theme(model.theme_id,
		model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty()), _journey_save_failed)
	var mode_changed: bool = theme_changed or _styled_mode_id != _mode_id
	var current_mode_button: Button = _mode_panel.button_for_mode(_mode_id) if _home_can_continue() else null
	for button: Button in _mode_buttons:
		button.set_pressed_no_signal(button == current_mode_button)
		button.disabled = not _home_mode_available() or model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty())
		if mode_changed:
			Style.quiet_button(button, palette.accent)
			button.add_theme_font_size_override("font_size", 16)
	if mode_changed:
		_fit_mode_buttons()
	if theme_changed:
		_memory.set_palette(palette)
		_phrase.apply_theme(palette, model.theme_id)
		_pop.apply_theme(palette, data.chests)
		var jelly_palette: Dictionary = palette
		if _is_jelly_mode() and _active_jelly().game.phase == "finished" and not _jelly_reward_theme.is_empty():
			jelly_palette = Data.theme(_jelly_reward_theme)
		_jelly.apply_theme(jelly_palette, data.chests)
		_word_jelly.apply_theme(jelly_palette, data.chests)
		Style.square_icon_button(hint_button, palette.accent)
		Style.square_icon_button(_collection_back, palette.accent)
		Style.button(_storage_retry_button, palette.accent)
	if mode_changed:
		_styled_mode_id = _mode_id
	_voice_button.disabled = (_round_context.get("track") != "professional" and not growth.ready) or _host == null or not bool(_host.speechAvailable())
	_voice_button.focus_mode = Control.FOCUS_NONE if _voice_button.disabled else Control.FOCUS_ALL
	var voice_description: String = "Voice on: click to stop" if _voice_mode else "Voice: click to listen. Browser speech may process audio remotely."
	if _voice_button.disabled:
		voice_description = "Voice input is unavailable in this browser. You can still tap cards."
	_set_accessibility_name(_voice_button, voice_description)
	_voice_button.button_pressed = _voice_mode
	_voice_button.engaged = _voice_listening
	_style_voice_button()
	var playing: bool = model.phase in ["waiting", "matching", "feedback"] or pair_revealing or (_pair_save_failed and _mode_id in ["match", "memory"])
	_storage_retry_button.add_theme_font_size_override("font_size", 16)
	_storage_retry_button.text = "Retry rewards" if _save_error else "Retry saving"
	_storage_retry_button.set("accessibility_description", coin_wallet.error if not coin_wallet.error.is_empty() else medal_progress.error if _save_error else growth.error)
	_storage_retry_button.visible = (_save_error or _journey_save_failed or _growth_save_failed or not coin_wallet.ready or not coin_wallet.error.is_empty())
	if professional.phase == "failed":
		_storage_retry_button.visible = true
		_storage_retry_button.set("accessibility_description", professional.error)
	_refresh_growth()
	if model.phase not in ["waiting", "matching", "feedback"] and _voice_mode:
		_stop_voice()
	_voice_button.visible = model.phase in ["waiting", "matching", "feedback"] and _mode_id == "match"
	_refresh_hint()
	_match_playfield.visible = _mode_id == "match"
	grid.visible = _mode_id == "match"
	_memory.visible = _mode_id == "memory"
	_phrase.visible = _mode_id == "phrase" and not collection_page.visible
	_resume_phrase()
	_pop.visible = _mode_id == "pop" and not collection_page.visible and (not _pop_rewards_shown or _pop.game.phase == "finished")
	_pop_rewards.visible = playing and _mode_id == "pop" and not collection_page.visible and _pop_rewards_shown
	var keep_ended_board: bool = _jelly_round_ended()
	_jelly.visible = playing and _mode_id == "jelly" and not collection_page.visible and (not _jelly_rewards_shown or keep_ended_board) and not celebrating
	_word_jelly.visible = playing and _mode_id == "word_jelly" and not collection_page.visible and (not _jelly_rewards_shown or keep_ended_board) and not celebrating
	_jelly_rewards.visible = playing and _is_jelly_mode() and not collection_page.visible and _jelly_rewards_shown
	_sync_jelly()
	_message.hide()
	_single_result.visible = _mode_id in ["match", "memory", "phrase"] and model.phase == "won" and not celebrating and not pair_revealing
	_sync_round_celebration()
	_sync_pair_presentation()
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
	elif playing and _mode_id == "jelly":
		_message.text = "Drag a picture onto its word. Make room for the falling jellies!"
	elif playing and _mode_id == "word_jelly":
		_message.text = "Join word pieces. Collect complete words and treasure fragments, with a 1% chance of bonus coins. Open chests to earn coins."
	var won: bool = model.phase == "won"
	var earned_chest: bool = won and model.chest_earned
	var saving_reward: bool = won and model.chest_state == "opened" and not _pending_fragment.is_empty() \
		and medal_progress.count_for(_pending_fragment.medal_id) < int(_pending_fragment.after)
	var result_message: String = ""
	if model.chest_state == "opening":
		result_message = "Your chest is open. You can let go!" if chest.opening_committed() else "Keep holding to open. Release to cancel."
	_single_result.configure(palette, earned_chest, saving_reward, _save_error, model.chest_state == "opened", result_message)
	_single_result.retry_button.set("accessibility_description", medal_progress.error if _save_error else "")
	var actions_blocked: bool = saving_reward or _save_error
	_single_result.replay_button.disabled = actions_blocked
	_single_result.home_button.disabled = actions_blocked
	chest_button.disabled = not earned_chest or model.chest_state == "opened" or chest.opening_committed() or _save_error
	_set_accessibility_name(chest_button, "Your chest is open. You can let go!" if chest.opening_committed() else "Hold to open the treasure chest")
	if won:
		var reward_id: String = JellyRewardProgress.theme_for_tier(1) if _mode_id in ["match", "memory"] else model.reward_theme if not model.reward_theme.is_empty() else model.theme_id
		chest.reduced_motion = reduced_motion
		chest.configure_skin(Data.theme(reward_id), data.chests)
		_single_result._sync_companion()
	_sync_settlement_dialog()
	if _last_phase != model.phase:
		_last_phase = model.phase
		if won:
			if not celebrating:
				duck.react("happy")
				audio.cue(model.theme_id + "-arrive")
			if _controller_mode and not collection_page.visible:
				chest_button.focus_mode = Control.FOCUS_ALL
				_default_focus().grab_focus()
	if _host != null:
		_host.background("#" + palette.background.to_html(false), "#" + palette.accent.to_html(false), "#" + palette.light.to_html(false), model.theme_id)
	if _save_error:
		_message.text = "Rewards are unavailable. You can keep practising." if playing else "Reward progress: " + medal_progress.error
	elif _journey_save_failed and playing:
		_message.text = "Your preferences could not be saved. Choose Retry saving."
	_sync_growth_load_notice()
	if _finish_confirmation_open():
		_announce_status("Finish this round? Keep playing, or Finish to see your score. Your collected rewards will be kept.")
	elif collection_page.visible:
		_announce_collection_state()
	elif not celebrating:
		_announce_status(_message.text if playing else _single_result.heading.text + " " + _single_result.caption.text)
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
	for control in _finish_confirmation_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = Control.FOCUS_NONE
	_single_result._update_focus()
	_settlement_dialog._layout()
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
	var locked: bool = _professional_input_blocked() or (not model.phase in ["waiting", "matching"] and not (_mode_id == "match" and model.phase == "feedback" and not _voice_mode))
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
	if _finish_confirmation_open():
		if not _valid_focus(get_viewport().gui_get_focus_owner()):
			_default_focus().grab_focus()
		return
	if _mode_menu_open():
		if not _valid_focus(get_viewport().gui_get_focus_owner()):
			_default_focus().grab_focus()
		return
	if _round_celebration_active():
		if not _valid_focus(get_viewport().gui_get_focus_owner()):
			var target: Control = _default_focus()
			if _valid_focus(target):
				target.grab_focus()
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
	_sync_growth_load_notice()
	_stop_feedback_animations()
	_fit_grid.call_deferred()
	_layout_collection()
	_settlement_dialog._layout()
	_sync_voice_bounds()
	_update_duck()
	_fit_content.call_deferred()


func _short_game_header() -> bool:
	var height: float = size.y * Style.ui_scale(self)
	return (_is_jelly_mode() and height <= 440) or (_mode_id in ["match", "memory"] and height <= 360)


func _stacked_game_header() -> bool:
	var width: float = size.x * Style.ui_scale(self)
	return width < 520 or (width < 600 and not _short_game_header())


func _fit_content() -> void:
	if _content_margins != null:
		var scale: float = Style.ui_scale(self)
		var short_header: bool = _short_game_header()
		for edge in ["top", "bottom"]:
			_content_margins.add_theme_constant_override("margin_" + edge, ceili((4 if short_header else 12) / scale))
		for edge in ["left", "right"]:
			_content_margins.add_theme_constant_override("margin_" + edge, ceili(12 / scale))
		var area: Vector2 = size * scale
		area.x = minf(area.x, GAME_AREA_MAX_SIZE.x)
		if area.x >= GAME_AREA_DESKTOP_WIDTH:
			if _is_jelly_mode():
				if size.x >= size.y:
					area.y = minf(area.y, 1040.0)
			else:
				area.y = minf(area.y, GAME_AREA_MAX_SIZE.y)
			if _mode_id in ["match", "memory"]:
				# Reserve the header and reward strip, then keep the two card rows proportional.
				area.y = minf(area.y, 142.0 + (area.x - 24.0) * 0.5)
		# Explicit sizing also lets containers shrink after transient child minima change.
		_content_margins.size = area / scale
		_content_margins.position = ((size - _content_margins.size) * 0.5).max(Vector2.ZERO)


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
	_pair_reward_row.custom_minimum_size.y = (34.0 if size.y * css_scale <= 440 else 46.0) / css_scale
	_layout_pair_reward()
	var short_header: bool = _short_game_header()
	_header_spacer.show()
	var gap: int = ceili((4 if short_header or size.x * css_scale < 360 else 8) / css_scale)
	_main_column.add_theme_constant_override("separation", gap)
	_header.custom_minimum_size.y = ceilf((88 if _stacked_game_header() else 44 if short_header else 56) / css_scale)
	_toolbar.add_theme_constant_override("separation", gap)
	_toolbar.custom_minimum_size.x = 0.0
	_header_duck_slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var accent: Color = _active_palette.get("accent", Style.GOOD)
	var heading_focus: int = _mode_heading_button.focus_mode
	Style.quiet_button(_mode_heading_button, accent, 0)
	_mode_heading_button.focus_mode = heading_focus
	_mode_heading_button.custom_minimum_size = Vector2.ZERO
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var surface := _mode_heading_button.get_theme_stylebox(state) as StyleBoxFlat
		surface.set_content_margin_all(6.0 / css_scale)
		surface.set_corner_radius_all(ceili(12.0 / css_scale))
	_mode_heading_button.set("accessibility_name", "Home. Return home to choose a game")
	_mode_heading_button.add_theme_constant_override("icon_max_width", ceili(28 / css_scale))
	_mode_heading.text = str(MODES[_mode_id])
	_mode_heading.add_theme_font_size_override("font_size", ceili((20 if size.x * css_scale >= 680 else 16) / css_scale))
	_layout_game_heading()
	_mode_panel.configure(_mode_id if _home_can_continue() else "", audio.muted if audio != null else false, reduced_motion)
	_mode_panel.configure_growth(growth.snapshot())
	_mode_panel.coin_counter.available = coin_wallet.ready and coin_wallet.error.is_empty()
	_mode_panel.set_home_coins(coin_wallet.balance)
	_layout_mode_menu()
	_layout_mode_menu.call_deferred()
	for button in [hint_button, _memory.study_button]:
		_style_header_action(button, accent)
	_style_voice_button()
	var compact_retry: bool = size.x * css_scale < 680
	_storage_retry_button.text = "Retry" if compact_retry else "Retry rewards" if _save_error else "Retry saving"
	_set_accessibility_name(_storage_retry_button, "Retry rewards" if _save_error else "Retry saving")
	_storage_retry_button.custom_minimum_size = Vector2(52 if compact_retry else 96, 44) / css_scale
	_storage_retry_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_storage_retry_button.add_theme_font_size_override("font_size", ceili(14 / css_scale))
	_voice_space.custom_minimum_size.y = ceilf(112 / css_scale)
	_style_growth_progress()
	_layout_game_heading()
	# Retry text and the Pip cluster can shrink after the header first expands.
	_content_margins.queue_sort.call_deferred()


func _layout_game_heading() -> void:
	if _growth_button == null or _storage_retry_button == null:
		return
	var scale: float = Style.ui_scale(self)
	var stacked: bool = _stacked_game_header()
	var short_header: bool = _short_game_header()
	var row: float = (44.0 if stacked or short_header else 56.0) / scale
	var gap: float = (8.0 if size.x * scale < 680 else 16.0) / scale
	var pip_side: float = (44.0 if stacked or short_header else 56.0) / scale
	var profile_width: float = (120.0 if short_header else 132.0 if stacked else 140.0) / scale
	_header_duck_slot.position = Vector2.ZERO
	_header_duck_slot.size = Vector2(profile_width, row)
	_header_duck_art_slot.position = Vector2(0, (row - pip_side) * 0.5)
	_header_duck_art_slot.size = Vector2.ONE * pip_side
	_growth_button.position = Vector2(pip_side + 6.0 / scale, (row - 44.0 / scale) * 0.5)
	_growth_button.size = Vector2(profile_width - _growth_button.position.x, 44.0 / scale)
	_professional_button.position = Vector2(0, (row - 44.0 / scale) * 0.5)
	_professional_button.size = Vector2(profile_width, 44.0 / scale)
	_professional_heading.position = Vector2(6, 3) / scale
	_professional_heading.size = Vector2(profile_width - 12.0 / scale, 20.0 / scale)
	_professional_progress_label.position = Vector2(6, 24) / scale
	_professional_progress_label.size = Vector2(profile_width - 12.0 / scale, 17.0 / scale)
	_professional_heading.add_theme_font_size_override("font_size", ceili(14.0 / scale))
	_professional_progress_label.add_theme_font_size_override("font_size", ceili(12.0 / scale))
	_layout_coin_counter()
	_toolbar.reset_size()
	_toolbar.position = Vector2(_header.size.x - _toolbar.size.x, 44.0 / scale) if stacked else Vector2(_coin_counter.position.x - gap - _toolbar.size.x, (row - _toolbar.size.y) * 0.5)
	var right: float = _toolbar.position.x - gap if _toolbar.get_minimum_size().x > 0.0 else _header.size.x if stacked else _coin_counter.position.x - gap
	if _is_jelly_mode() and is_instance_valid(_active_jelly()) and _active_jelly().has_header_chest():
		var dock_size: Vector2 = Vector2.ONE * 44.0 / scale
		var dock_x: float = (profile_width + _coin_counter.position.x - dock_size.x) * 0.5 if stacked else right - dock_size.x
		for view in [_jelly, _word_jelly]:
			if is_instance_valid(view) and view.has_header_chest():
				view._header_chest_host.position = Vector2(dock_x, (row - dock_size.y) * 0.5)
				view._header_chest_host.size = dock_size
				view.layout_header_chest()
		if not stacked:
			right = dock_x - gap
	if _storage_retry_button.visible:
		_storage_retry_button.reset_size()
		_storage_retry_button.position = Vector2(right - _storage_retry_button.size.x, (44.0 if stacked else 0.0) / scale + (row - _storage_retry_button.size.y) * 0.5)
		right = _storage_retry_button.position.x - gap
	var left: float = 0.0 if stacked else profile_width + gap
	_header_spacer.position = Vector2(left, 44.0 / scale if stacked else 0.0)
	_header_spacer.size = Vector2(maxf(0.0, right - left), row)
	_mode_heading_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_mode_heading_button.size = Vector2.ONE * 44.0 / scale
	_mode_heading_button.position = Vector2(0, (row - 44.0 / scale) * 0.5)
	_mode_heading_button.show()
	_mode_heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_mode_heading.position = Vector2(50.0 / scale, 0)
	_mode_heading.size = Vector2(maxf(0, _header_spacer.size.x - 50.0 / scale), row)
	_mode_heading.clip_text = true
	_mode_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if stacked else HORIZONTAL_ALIGNMENT_CENTER


func _layout_coin_counter() -> void:
	var scale: float = Style.ui_scale(self)
	var row: float = (44.0 if _stacked_game_header() or _short_game_header() else 56.0) / scale
	_coin_counter.position = Vector2(maxf(0.0, _header.size.x - _coin_counter.size.x), (row - _coin_counter.size.y) * 0.5)
	_coin_counter.queue_redraw()


func _layout_mode_menu() -> void:
	var css_scale: float = Style.ui_scale(self)
	_mode_panel.fit(size, css_scale)
	_mode_panel.position = Vector2.ZERO
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
	_style_header_action(_voice_button, accent)
	var radius: int = ceili(10 / scale)
	_voice_button.add_theme_stylebox_override("pressed", Style.box(accent.darkened(0.18), accent, radius, 0))
	_voice_button.add_theme_stylebox_override("hover_pressed", Style.box(accent.darkened(0.12), accent, radius, 0))
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		_voice_button.add_theme_color_override(state, Color.WHITE)
	_voice_button.queue_redraw()


func _style_header_action(button: Button, accent: Color) -> void:
	Style.square_icon_button(button, accent)
	var scale: float = Style.ui_scale(self)
	var radius: int = ceili(12 / scale)
	button.add_theme_stylebox_override("normal", Style.box(accent.lightened(0.94), Color.TRANSPARENT, radius, 0))
	button.add_theme_stylebox_override("disabled", Style.box(Color("#edf0eb"), Color.TRANSPARENT, radius, 0))


func _layout_collection() -> void:
	if not is_instance_valid(_age_catalog):
		return
	var scale: float = Style.ui_scale(self)
	var compact: bool = size.y * scale < 500
	_growth_summary.visible = not compact and not _collection_professional
	_age_notice.visible = not compact and not _collection_professional
	_professional_library.fit(scale)
	_age_catalog.meaning_label.visible = not compact or _age_catalog.meaning_label.text != "Tap a word to hear it."
	var padding: int = ceili((8 if compact else 14) / scale)
	for edge in ["left", "right"]:
		_collection_margins.add_theme_constant_override("margin_" + edge, maxi(padding, roundi((size.x - 1000 / scale) * 0.5)))
	for edge in ["top", "bottom"]:
		_collection_margins.add_theme_constant_override("margin_" + edge, padding)
	_collection_column.add_theme_constant_override("separation", ceili(8 / scale))
	_collection_header.add_theme_constant_override("separation", ceili(8 / scale))
	_collection_title.add_theme_font_size_override("font_size", ceili(21 / scale))
	_growth_summary.add_theme_font_size_override("font_size", ceili(13 / scale))
	_age_notice.add_theme_font_size_override("font_size", ceili(12 / scale))
	_age_scroll.custom_minimum_size.y = ceilf(44 / scale)
	_age_row.add_theme_constant_override("separation", ceili(6 / scale))
	for button in _age_buttons.values():
		Style.action_button(button, Style.GOOD)
		button.custom_minimum_size = Vector2(48, 42) / scale
		button.add_theme_font_size_override("font_size", ceili(14 / scale))
	Style.square_icon_button(_collection_back, Style.GOOD)


func _can_request_hint() -> bool:
	if _professional_input_blocked() or _rebuilding or _page_hidden or _mode_menu_open() or collection_page.visible or _round_id.is_empty():
		return false
	if _mode_id != "match" or not model.hint_ids.is_empty() or not model.error.is_empty():
		return false
	if model.available_hint_pair().is_empty():
		return false
	if model.phase == "feedback":
		return not _voice_mode and model.matched_ids.size() < model.cards.size()
	return model.phase in ["waiting", "matching"]


func _refresh_hint() -> void:
	hint_button.visible = _mode_id == "match" and model.phase in ["waiting", "matching", "feedback"]
	hint_button.disabled = not _can_request_hint()
	hint_button.focus_mode = Control.FOCUS_NONE if hint_button.disabled else Control.FOCUS_ALL
	hint_button.count = -1
	hint_button.cost = _match_hint_price()
	hint_button.reduced_motion = reduced_motion
	if not hint_button.is_visible_in_tree() or _page_hidden or _mode_menu_open() or collection_page.visible:
		hint_button.reset_feedback()
	var description: String
	if model.phase == "won" or model.matched_ids.size() == model.cards.size():
		description = "Round finished. View your result."
	elif _voice_mode and model.phase == "feedback":
		description = "Finishing voice matches. Hints will be available afterward."
	elif not model.hint_ids.is_empty():
		description = "Hint active. Follow the electric link between the two matching cards."
	else:
		description = "Hint: %d coins (Xbox X)" % _match_hint_price()
	_set_accessibility_name(hint_button, description)


func _match_hint_price() -> int:
	return Economy.match_hint_price(model.hints_used)


func _purchase_match_hint(ordinal: int, price: int) -> Dictionary:
	if not _can_request_hint() or ordinal != model.hints_used + 1 or price != _match_hint_price():
		return {"ok": false, "error": "This hint cannot be used yet."}
	if not coin_wallet.ready or not coin_wallet.error.is_empty():
		coin_wallet.load_state()
	var receipt: String = _round_id + ":match-hint:" + str(ordinal)
	var result: Dictionary = coin_wallet.spend(receipt, price)
	_coin_counter.available = coin_wallet.ready and coin_wallet.error.is_empty()
	if bool(result.get("ok", false)):
		_coin_flight.sync(coin_wallet.balance)
	elif str(result.get("reason", "")) == "insufficient":
		_announce_status("Not enough coins. A hint costs %d coins." % price)
	else:
		_announce_status("Your hint could not be saved. No coins were spent.")
	_coin_counter._update_description()
	_coin_counter.queue_redraw()
	_publish_coins()
	return result


func _request_hint() -> void:
	if _hint_purchasing or not _can_request_hint():
		return
	_hint_purchasing = true
	var round_id: String = _round_id
	var round_model = model
	var uses: int = model.hints_used
	var purchase: Dictionary = _purchase_match_hint(uses + 1, _match_hint_price())
	# A saved receipt can recover this same ordinal if an overlay interrupted payment.
	if round_id != _round_id or model != round_model or uses != model.hints_used or not _can_request_hint():
		_hint_purchasing = false
		return
	if not bool(purchase.get("ok", false)):
		hint_button.feedback(false)
		audio.interact(model.theme_id, not _voice_mode)
		audio.play_pair_feedback(false)
		_hint_purchasing = false
		_publish_growth_view()
		return
	if model.phase == "feedback":
		_continue_match()
	if round_id != _round_id or model != round_model or uses != model.hints_used or not _can_request_hint():
		_hint_purchasing = false
		return
	if not model.request_hint() or round_id != _round_id or model != round_model \
		or _page_hidden or _mode_menu_open() or collection_page.visible or model.hint_ids.size() != 2:
		_hint_purchasing = false
		return
	for card_id in model.hint_ids:
		_professional_assisted[str(model.card_by_id(card_id).word.id)] = true
	duck.react("happy")
	audio.stop_pair_feedback()
	audio.interact(model.theme_id, not _voice_mode)
	hint_button.feedback(true)
	audio.play_pair_feedback(true)
	_coin_flight.reduced_motion = reduced_motion
	_coin_flight.spend(purchase, hint_button.global_position + hint_button.size * Vector2(0.5, 0.32))
	if not _voice_mode:
		audio.cue("select")
		audio.say("res://" + model.card_by_id(model.hint_ids[0]).word.audio)
	var next_id: String = model.hint_ids[1] if model.selected_id == model.hint_ids[0] else model.hint_ids[0]
	if cards.has(next_id):
		cards[next_id].grab_focus()
	_hint_purchasing = false
	_publish_growth_view()


func _select_card(id: String) -> void:
	if _professional_input_blocked() or _hint_purchasing or _mode_id != "match" or collection_page.visible or _mode_menu_open():
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
	if _mode_menu_open():
		_announce_status(str(Data.theme(id).name) + " theme selected." + (" Changes not saved. Tap a theme to retry." if _journey_save_failed else ""))
	if collection_page.visible:
		_refresh_collection()
		_announce_collection_state()
	duck.react("happy")
	if not _voice_mode and not _pop_speech_active:
		audio.interact(model.theme_id)


func set_reduced_motion(value: bool) -> void:
	_pair_reward.set_reduced_motion(value)
	reduced_motion = value
	_sync_reward_confetti()
	WordArt.set_reduced_motion(value)
	if _host != null:
		_host.presentationSettings(value, audio.muted)
	_hint_link.set_reduced_motion(value)
	hint_button.reduced_motion = value
	_voice_match_link.set_reduced_motion(value)
	_pop.set_reduced_motion(value)
	_pop_rewards.set_reduced_motion(value)
	_jelly.set_reduced_motion(value)
	_word_jelly.set_reduced_motion(value)
	_jelly_backdrop.set_reduced_motion(value)
	_jelly_rewards.set_reduced_motion(value)
	_memory.set_reduced_motion(value)
	_phrase.set_reduced_motion(value)
	_round_celebration.set_reduced_motion(value)
	for card in cards.values():
		card.set_reduced_motion(value)
	if duck != null:
		duck.set_reduced_motion(value)
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
	if (_round_celebration_active() or _pair_reward_revealing()) and not _settling_chest:
		return
	if model.phase != "won" or not model.chest_earned or model.chest_state != "closed":
		return
	if not _progress_ready:
		_progress_ready = medal_progress.load_progress()
		if not _progress_ready:
			_save_error = true
			_cancel_chest_hold()
			_refresh()
			return
	var pair: Dictionary = medal_progress.pair_round(_mode_id)
	var saved_pair: bool = _mode_id in ["match", "memory"] and pair.get("id", "") == _round_id and pair.get("awarded", false)
	_pending_fragment = pair.fragment.duplicate(true) if saved_pair else medal_progress.next_fragment(model.theme_id)
	if not medal_progress.error.is_empty():
		_save_error = true
		_cancel_chest_hold()
		_refresh()
		return
	var id: String = _pending_fragment.medal_id if not _pending_fragment.is_empty() else Data.medals(pair.theme if saved_pair else model.theme_id).back().id
	if not model.begin_open(id):
		_cancel_chest_hold()
		return
	if saved_pair:
		model.reward_theme = JellyRewardProgress.theme_for_tier(1)
		chest.configure_skin(Data.theme(model.reward_theme), data.chests)
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
	# Physical completion stops the bed even if the following save fails.
	# The success accent remains gated by the separate persistence result.
	audio.finish_chest_motion()
	_publish_chest_charge()
	_commit_fragment()
	if _controller_mode and not _settling_chest and not _page_hidden \
		and not collection_page.visible and not _mode_menu_open():
		_default_focus().grab_focus()


func _settle_released_chest() -> void:
	if model.chest_state != "opening" or not chest.opening_committed():
		return
	var was_settling: bool = _settling_chest
	_settling_chest = true
	audio.stop_chest_performance()
	chest.finish_immediately()
	_settling_chest = was_settling


func _single_chest_receipt() -> String:
	return ("pair:" + _mode_id + ":" if _mode_id in ["match", "memory"] else "phrase:") + _round_id


func _credit_coins(id: String, tier: int) -> Dictionary:
	if not coin_wallet.ready or not coin_wallet.error.is_empty():
		coin_wallet.load_state()
	var result: Dictionary = coin_wallet.credit(id, tier)
	_coin_counter.available = coin_wallet.ready and bool(result.ok)
	_coin_counter._update_description()
	_coin_counter.queue_redraw()
	if result.ok and result.duplicate and not _coin_flight.snapshot().active \
		and _pending_coin_reward.is_empty() and not _pop_rewards_shown and not _jelly_rewards_shown:
		_coin_flight.sync(coin_wallet.balance)
	return result


func _present_room_coins(id: String, reward: Dictionary, origin: Vector2, animate: bool) -> void:
	_present_coins(id, reward, origin, animate)


func _present_coins(id: String, reward: Dictionary, origin: Vector2, animate: bool = true) -> void:
	if animate and not _page_hidden and not collection_page.visible and not _mode_menu_open():
		_coin_flight.reduced_motion = reduced_motion
		_coin_flight.present(id, reward, origin, true)
	else:
		_coin_flight.sync(coin_wallet.balance)
	if int(reward.get("amount", 0)) > 0:
		_announce_status("%d coins from your chest. Total: %d coins." % [reward.amount, coin_wallet.balance])


func _commit_fragment(explicit_retry: bool = false) -> void:
	var receipt: String = _single_chest_receipt()
	var credit: Dictionary = _credit_coins(receipt, 1)
	if not credit.ok:
		_save_error = true
		_refresh()
		return
	if int(credit.amount) > 0:
		_pending_coin_reward = credit
	var pair: Dictionary = medal_progress.pair_round(_mode_id)
	var saved_pair: bool = _mode_id in ["match", "memory"] and pair.get("id", "") == _round_id and pair.get("awarded", false)
	var saved: bool = medal_progress.settle_pair_reward(_mode_id, _round_id) if saved_pair else (_pending_fragment.is_empty() or medal_progress.claim(_pending_fragment))
	if not saved:
		_save_error = true
		_refresh()
		return
	_save_error = false
	if not _chest_reward_announced:
		_chest_reward_announced = true
		_present_coins(receipt, _pending_coin_reward, chest.get_global_transform() * chest._cavity_origin(), not _settling_chest)
		_pending_coin_reward.clear()
		if not _settling_chest and not _page_hidden and not collection_page.visible:
			if explicit_retry:
				audio.interact(model.reward_theme)
			audio.chest_reward(model.reward_theme, explicit_retry)
	_refresh_collection()
	_refresh()
	duck.react("happy")


func _retry_reward_save() -> void:
	if not _save_error or collection_page.visible:
		return
	if _pair_save_failed:
		if not _progress_ready:
			_load_collected_rewards()
		if _progress_ready:
			if _pair_settlement_pending:
				_settle_pair_reward()
			else:
				_sync_pair_reward()
		_refresh()
		return
	if not _progress_ready:
		_load_collected_rewards()
		if _progress_ready:
			_build_collection()
		_refresh()
	else:
		_commit_fragment(true)
	if not _valid_focus(get_viewport().gui_get_focus_owner()):
		_default_focus().grab_focus()


func on_page_hidden() -> void:
	if is_instance_valid(_finish_confirmation):
		_finish_confirmation.cancel_input()
	_reward_confetti.set_paused(true)
	_coin_flight.sync(coin_wallet.balance)
	audio.stop_ui_click()
	_mode_menu_resume_voice = false
	_mode_menu_resume_pop = false
	_mode_panel.pip.set_idle_paused(true)
	_mode_panel.scroll.cancel_drag()
	_mode_panel.finish_previews()
	if is_instance_valid(_pop_rewards):
		_pop_rewards.pause()
	if is_instance_valid(_jelly_rewards):
		_jelly_rewards.pause()
		_jelly.pause(true)
		_word_jelly.pause(true)
	if _speech_debug_active:
		_page_hidden = true
		audio.halt()
		audio.set_speech_debug_mix(1.0)
		return
	if not _page_hidden:
		_resume_music_after_background = audio.active and audio.music.playing and not audio.muted
	_page_hidden = true
	chest.set_idle_paused(true)
	_sync_jelly()
	_publish_jelly_rewards(_jelly_rewards.snapshot())
	_sync_round_celebration()
	_hint_link.set_paused(true)
	hint_button.reset_feedback()
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
	audio.halt()
	duck.settle()
	duck.set_idle_paused(true)
	_memory.set_reduced_motion(true)
	_memory.set_reduced_motion(reduced_motion)
	chest.stop_reaction()


func on_page_visible() -> void:
	if not _pending_vocabulary_round.is_empty():
		_resume_vocabulary_round.call_deferred()
	if _speech_debug_active:
		_page_hidden = false
		_sync_reward_confetti()
		return
	var resume_music: bool = _page_hidden and _resume_music_after_background
	_page_hidden = false
	_resume_music_after_background = false
	_sync_round_celebration()
	if _pop_rewards_shown and not collection_page.visible and not _mode_menu_open():
		_pop_rewards.resume()
	chest.set_idle_paused(false)
	_refresh_hint_link()
	duck.set_idle_paused(false)
	_mode_panel.pip.set_idle_paused(false)
	_mode_panel.resume_previews()
	feedback_timer.paused = collection_page.visible or _mode_menu_open()
	_memory.pause(collection_page.visible or _mode_menu_open() or _professional_input_blocked())
	_resume_phrase()
	_sync_jelly()
	if resume_music:
		_restore_mode_music()


func _restore_mode_music() -> void:
	# Building Home happens behind the Web loader; its first music belongs to
	# the accepted Enter gesture, after the host reveals the game.
	if OS.has_feature("web") and not _loading_revealed:
		return
	if _page_hidden or _voice_mode or _pop_speech_active or (is_instance_valid(_vocabulary_prompt) and _vocabulary_prompt.visible):
		return
	if _mode_id == "pop" and not collection_page.visible and not _mode_menu_open():
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
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed):
		_navigation_focus_active = false
		if _is_jelly_mode() and is_instance_valid(_active_jelly()):
			var view = _active_jelly()
			if view._tiles.values().has(get_viewport().gui_get_focus_owner()):
				view.grab_focus()
	elif event is InputEventKey and event.pressed and not event.echo:
		var entering_navigation: bool = not _navigation_focus_active
		_navigation_focus_active = true
		# A pointer-started board keeps a neutral focus anchor until navigation
		# begins. Promote it once; later Tab cycles must reach older jellies too.
		if entering_navigation and _is_jelly_mode() and is_instance_valid(_active_jelly()) and _active_jelly().has_focus():
			for action: String in ["ui_focus_next", "ui_focus_prev", "ui_left", "ui_right", "ui_up", "ui_down"]:
				if event.is_action_pressed(action):
					_default_focus().grab_focus()
					get_viewport().set_input_as_handled()
					break


func _input(event: InputEvent) -> void:
	if _settlement_dialog_open():
		if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed):
			_stop_controller_actions()
			_on_input_canceled()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey:
			for action: String in ["ui_left", "ui_right", "ui_up", "ui_down"]:
				if event.is_action_pressed(action):
					_move_focus({"ui_left": Vector2.LEFT, "ui_right": Vector2.RIGHT,
						"ui_up": Vector2.UP, "ui_down": Vector2.DOWN}[action])
					get_viewport().set_input_as_handled()
					return
		if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
			var controls: Array[Control] = _focus_candidates()
			if not controls.is_empty():
				var index: int = controls.find(get_viewport().gui_get_focus_owner())
				var direction: int = -1 if event.is_action_pressed("ui_focus_prev") else 1
				controls[posmod(index + direction, controls.size())].grab_focus()
			get_viewport().set_input_as_handled()
			return
		if (event is InputEventKey and event.is_action_pressed("ui_accept") and event.echo) \
			or (event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B]):
			get_viewport().set_input_as_handled()
			return
	if _finish_confirmation_open():
		if event.is_action_pressed("ui_cancel"):
			_cancel_jelly_finish()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.is_action_pressed("ui_accept") and event.echo:
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
			var target: Button = _finish_confirmation.finish_button if get_viewport().gui_get_focus_owner() == _finish_confirmation.keep_playing_button else _finish_confirmation.keep_playing_button
			target.grab_focus()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B]:
			get_viewport().set_input_as_handled()
			return
	if _mode_menu_open():
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START]:
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
			elif _controller_holding_jelly_chest:
				_controller_accept_needs_release = false
				_controller_holding_jelly_chest = false
				_jelly_rewards.end_hold()
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
		if absf(event.axis_value) >= 0.55:
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
	var entering_navigation: bool = not _navigation_focus_active
	_controller_mode = true
	_navigation_focus_active = true
	if not _valid_focus(get_viewport().gui_get_focus_owner()) \
		or (entering_navigation and _is_jelly_mode() and _active_jelly().has_focus()):
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
	if _controller_holding_jelly_chest:
		_controller_holding_jelly_chest = false
		_jelly_rewards.cancel_input()
	if is_instance_valid(_memory) and _memory.memory.studying:
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
	if _jelly_rewards_shown and _is_jelly_mode() and _valid_focus(focused) and _jelly_rewards.is_chest_control(focused):
		_controller_holding_jelly_chest = true
		_jelly_rewards.begin_hold(focused)
		return
	if _pop_rewards_shown and _mode_id == "pop" and _valid_focus(focused) and _pop_rewards.is_chest_control(focused):
		_controller_holding_pop_chest = true
		_pop_rewards.begin_hold(focused)
		return
	if _mode_id == "memory" and focused == _memory.study_button and _valid_focus(focused):
		# One controller press starts a timed reveal; releasing A leaves it running.
		_controller_accept_needs_release = true
		_memory.begin_peek()
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
	if _finish_confirmation_open():
		_cancel_jelly_finish()
		return
	if _mode_menu_open():
		return
	if _controller_holding_jelly_chest:
		_controller_holding_jelly_chest = false
		_jelly_rewards.cancel_input()
		_controller_accept_needs_release = _controller_accept_is_pressed()
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
	elif _is_jelly_mode():
		if _jelly_rewards_shown and _jelly_rewards._result_context.is_empty():
			_jelly_rewards._back.pressed.emit()
		else:
			_active_jelly().cancel_input()
			_show_mode_menu()
	elif _mode_id == "pop":
		if _pop_rewards_shown:
			_pop_rewards._back.pressed.emit()
		else:
			_play_ui_click()
			_show_mode_menu()
	elif _mode_id == "match" and model.phase == "feedback":
		_continue_match()
	elif _mode_id == "memory":
		if _memory.memory.studying:
			_memory.end_peek()
		elif _memory.memory.phase == "matching" and not _memory.memory.selected_indices.is_empty():
			_memory.card_buttons[_memory.memory.selected_indices[0]].pressed.emit()
	elif model.phase == "matching" and not model.selected_id.is_empty():
		model.select(model.selected_id)


func _toggle_collection() -> void:
	if collection_page.visible:
		_collection_back.pressed.emit()
	else:
		collection_button.pressed.emit()


func _cycle_theme(step: int) -> void:
	if not _can_choose_world():
		return
	if model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty()):
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
	if not _settlement_dialog_open() and _mode_id == "phrase" and _phrase.scroll_focused_answer(direction):
		return
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
	if _settlement_dialog_open() and result.size() > 1:
		result.erase(_settlement_dialog.panel)
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
	if _finish_confirmation_open():
		return _finish_confirmation.is_ancestor_of(control)
	if is_instance_valid(_vocabulary_prompt) and _vocabulary_prompt.visible:
		return _vocabulary_prompt.is_ancestor_of(control)
	if _mode_menu_open():
		return _mode_panel.is_ancestor_of(control)
	if collection_page.visible and is_instance_valid(control) and control != duck and not collection_page.is_ancestor_of(control):
		return false
	if _settlement_dialog_open():
		return _settlement_dialog.is_ancestor_of(control)
	if _round_celebration_active() and not collection_page.visible:
		return _round_celebration.is_ancestor_of(control) or _header.is_ancestor_of(control)
	return true


func _default_focus() -> Control:
	if _finish_confirmation_open():
		return _finish_confirmation.keep_playing_button
	if is_instance_valid(_vocabulary_prompt) and _vocabulary_prompt.visible:
		return _vocabulary_retry if _vocabulary_retry.visible else _vocabulary_back
	if _mode_menu_open():
		var current_mode_button: Button = _mode_panel.button_for_mode(_mode_id) if _can_continue_round() else null
		return current_mode_button if current_mode_button != null and current_mode_button.is_visible_in_tree() else _mode_panel.learning_focus()
	if collection_page.visible:
		return _collection_back
	if _round_celebration_active():
		var target: Control = _round_celebration.default_focus()
		return target if _valid_focus(target) else _settlement_dialog.panel
	if _mode_id == "pop" and _pop_rewards_shown:
		for control in _pop_rewards.navigation_controls():
			if _valid_focus(control):
				return control
		return _settlement_dialog.panel
	if _is_jelly_mode():
		if _jelly_rewards_shown:
			for control in _jelly_rewards.navigation_controls():
				if _valid_focus(control):
					return control
			return _settlement_dialog.panel
		# Automatic handoffs after a pointer gesture must not look like a
		# selected jelly. Keep every tile available to keyboard navigation.
		if not _navigation_focus_active and _active_jelly()._can_play():
			return _active_jelly()
		var jelly_focus: Control = _active_jelly().default_focus()
		return jelly_focus if _valid_focus(jelly_focus) else collection_button
	if model.phase == "won":
		if _valid_focus(chest_button):
			return chest_button
		if _valid_focus(_single_result.retry_button):
			return _single_result.retry_button
		return _single_result.replay_button if _valid_focus(_single_result.replay_button) else _single_result.home_button if _valid_focus(_single_result.home_button) else _settlement_dialog.panel
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
	if collection_page.visible and not _pointer_focus_active:
		_reveal_catalog_control(control, true)


func _reveal_catalog_control(target: Control, explicit_focus: bool = false) -> void:
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
	# Keep pair feedback in the same live-region update as the board status.
	# Otherwise an immediate refresh can replace it before a reader speaks it.
	if _mode_id in ["match", "memory"] and _pair_reward_revealing() \
		and _pair_reward_row.is_visible_in_tree() and not _page_hidden \
		and not collection_page.visible and not _mode_menu_open():
		var notice: String = PairChestReward.DISCOVERY_MESSAGE if model.chest_earned else "No chest this pair."
		if not message.begins_with(notice):
			message = notice + " " + message
	_status_announcement = message
	if _host != null:
		_host.announce(message)


func _show_error(message: String) -> void:
	_memory.hide()
	_phrase.hide()
	_pop.hide()
	_jelly.hide()
	_word_jelly.hide()
	_settlement_dialog.close()
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
		set_reduced_motion(bool(arguments[0])))
	_input_cancel_callback = JavaScriptBridge.create_callback(_on_input_canceled)
	_pointer_release_callback = JavaScriptBridge.create_callback(func(arguments: Array) -> void:
		_phrase.release_pointer(int(arguments[0]))
		_jelly.release_pointer(int(arguments[0]))
		_word_jelly.release_pointer(int(arguments[0])))
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
		or collection_page.visible or _page_hidden or _mode_menu_open():
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
		return true
	audio.interact(model.theme_id, false)
	match arguments[1]:
		"launch": audio.cue("pop-launch")
		"slice": audio.cue("pop-slice")
		"miss":
			if _mode_id != "pop":
				audio.play_pair_feedback(false)
		"match": audio.play_pair_feedback(true)
	return true


func _open_speech_debug() -> bool:
	if _speech_debug_active:
		return not _page_hidden
	if _page_hidden or not _pending_vocabulary_round.is_empty() or (OS.has_feature("web") and not _loading_revealed) \
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
	_sync_round_celebration()
	_pause_phrase()
	_jelly.pause(true)
	_word_jelly.pause(true)
	_jelly_rewards.pause()
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
		_sync_jelly()
		_restore_mode_music()
		_sync_round_celebration()
	return true


func _exit_tree() -> void:
	_clear_reward_confetti()
	_stop_round_celebration()
	_close_speech_debug(false)


func _on_input_canceled(_arguments: Array = []) -> void:
	if is_instance_valid(_finish_confirmation):
		_finish_confirmation.cancel_input()
	_mode_menu_pointer = -2
	if is_instance_valid(_mode_panel):
		_mode_panel.scroll.cancel_drag()
	_proactive_touches.clear()
	_pointer_focus_active = false
	_cancel_chest_hold()
	_finish_chest_drag()
	_pop_rewards.cancel_input()
	_jelly_rewards.cancel_input()
	_jelly.cancel_input()
	_word_jelly.cancel_input()
	duck.note_activity()
	_pop.cancel_result_input()
	_memory.end_peek()
	_phrase.cancel_input()
	_cancel_collection_rails()


func _toggle_voice() -> void:
	if _mode_id != "match" or collection_page.visible or _mode_menu_open():
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
		_pop.set_listening(bool(arguments[0]), bool(arguments[1]), str(arguments[2]))
		# Recognition rolls over after an utterance. Let that word's short
		# emotion finish while the recognizer reconnects automatically.
		if not bool(arguments[1]) and not _pop._reconnecting:
			audio.stop_jelly_sounds()
			audio.stop_pop_sounds()
			duck.settle()
		return
	var enabled: bool = bool(arguments[0])
	if enabled and model.phase == "won":
		_stop_voice()
		return
	var layout_changed: bool = _voice_mode != enabled
	_voice_mode = enabled
	_voice_listening = enabled and bool(arguments[1])
	_voice_attention_active = enabled and (_voice_listening or _pop._pending_message(str(arguments[2])))
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
	if _professional_input_blocked() or _speech_debug_active or _mode_menu_open() or arguments.size() < 2:
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
	if _professional_input_blocked() or not _voice_mode or not model.phase in ["waiting", "matching"]:
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
	_voice_attention_active = false
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
	if _round_celebration_active() or _pair_reward_revealing():
		return
	if _holding_chest or _page_hidden or collection_page.visible or _save_error \
		or model.phase != "won" or not model.chest_earned or model.chest_state != "closed":
		return
	_holding_chest = true
	_hold_elapsed = 0.0
	_hold_origin_frame = Engine.get_process_frames()
	_drag_distance = 0.0
	_dragging_chest = true
	_drag_has_anchor = false
	audio.interact(chest.theme_id)
	audio.stop_voice()
	audio.prepare_chest(chest.theme_id)
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
	WordArt.advance(delta, not _page_hidden and not _mode_menu_open())
	# Input may start a hold in this frame; delta includes time from before
	# that press. Start counting on the next frame without delaying its pose.
	var hold_delta: float = 0.0 if Engine.get_process_frames() == _hold_origin_frame else delta
	_advance_ui(delta, hold_delta)


func _advance_ui(delta: float, hold_delta: float = -1.0) -> void:
	_sync_reward_confetti()
	_reward_confetti.advance(delta)
	_coin_flight.reduced_motion = reduced_motion
	if _page_hidden or collection_page.visible or _mode_menu_open():
		if _coin_flight.snapshot().active:
			_coin_flight.sync(coin_wallet.balance)
	else:
		_coin_flight.advance(delta)
	var pair_was_revealing: bool = _pair_reward_revealing()
	_sync_pair_presentation()
	_pair_reward.advance(delta)
	# Audio completion can happen between UI frames. Resume the waiting finale
	# from its round identity as well as the visual timeline's transition edge.
	var pair_finale_pending: bool = _mode_id in ["match", "memory"] and not _round_id.is_empty() \
		and _celebration_seen_id != _round_id and model.chest_state == "closed" and not _pair_save_failed and not _settling_chest
	if (pair_was_revealing or pair_finale_pending) and not _pair_reward_revealing() and model.phase == "won":
		_refresh()
	_sync_round_celebration()
	_sync_settlement_dialog()
	_celebration_publish_left -= delta
	if _celebration_publish_left <= 0.0:
		_celebration_publish_left = 0.05
		_publish_round_celebration()
		_publish_growth_view()
		_publish_coins()
		_publish_library()
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
	if collection_page.visible or _mode_menu_open() or _page_hidden or _rebuilding \
		or _mode_id not in ["match", "memory", "phrase"] or model.phase != "won" or _save_error:
		return
	if not _settle_completed_round_rewards():
		return
	if not _pending_fragment.is_empty() and medal_progress.count_for(_pending_fragment.medal_id) < int(_pending_fragment.after):
		return
	if new_round(-1, false, "", _mode_id):
		_default_focus().grab_focus()
		if _mode_id == "phrase":
			_start_phrase_prompt()


func _save_journey() -> void:
	_presentation.preferred_theme = _preferred_theme
	_journey_save_failed = not _presentation.save_preferences()
	_refresh()


func _retry_storage() -> void:
	if collection_page.visible:
		return
	if professional.phase == "failed" or _professional_input_blocked():
		_retry_professional()
	if not coin_wallet.ready or not coin_wallet.error.is_empty():
		coin_wallet.load_state()
		_coin_counter.available = coin_wallet.ready
		_coin_flight.sync(coin_wallet.balance)
	if _save_error:
		_retry_reward_save()
	if _journey_save_failed:
		_save_journey()
	if not growth.ready:
		_growth_save_failed = not growth.load_state()
	else:
		_growth_save_failed = not bool(growth.retry_pending().save_ok)
	if growth.ready and model.cards.is_empty() and _round_context.get("track") != "professional":
		new_round()
	_refresh_growth()
	_refresh()
	if not _valid_focus(get_viewport().gui_get_focus_owner()):
		_default_focus().grab_focus()


func _show_collection() -> void:
	if collection_page.visible or _finish_confirmation_open():
		return
	var from_home: bool = _mode_menu_open()
	var selected_professional: bool = (_home_context if from_home else _round_context).get("track") == "professional"
	if selected_professional and from_home and not _professional_library_available():
		return
	_collection_professional = selected_professional
	_coin_flight.sync(coin_wallet.balance)
	# Preserve prepared and hard-error gates; only an interrupted live or pending
	# recognizer needs paused wording. Capture this before host stop callbacks.
	var pause_pop: bool = _mode_id == "pop" and (_pop.game.phase in ["running", "finished"] \
		or _pop._listening or _pop._pending or _pop._reconnecting or _pop.reward_presentation_active())
	if not _stop_pop_listening():
		return
	_collection_from_home = _mode_menu_open()
	_hide_mode_menu(false, false)
	_set_accessibility_name(_collection_back, "Back to home" if _collection_from_home else "Back to game")
	_focus_before_collection = get_viewport().gui_get_focus_owner()
	if pause_pop:
		_pop.pause()
	_pop_rewards.pause()
	_jelly.pause(true)
	_word_jelly.pause(true)
	_jelly_rewards.pause()
	audio.stop_jelly_sounds()
	audio.stop_voice()
	audio.stop_pop_sounds()
	duck.settle()
	_stop_voice()
	feedback_timer.paused = true
	_stop_feedback_animations()
	_cancel_chest_hold()
	_settle_released_chest()
	_finish_chest_drag()
	_cancel_collection_rails()
	_collection_focus_modes.clear()
	for control in find_children("*", "Control", true, false):
		if not collection_page.is_ancestor_of(control):
			_collection_focus_modes[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
	_catalog_age = growth.learning_age()
	collection_page.show()
	if _collection_professional:
		_professional_library.show()
		_professional_library.configure(_round_content, professional.session.snapshot())
		_collection_title.text = "Word library"
	_sync_jelly()
	_publish_jelly_rewards(_jelly_rewards.snapshot())
	_refresh_collection()
	_sync_round_celebration()
	_hint_link.set_paused(true)
	hint_button.reset_feedback()
	_memory.pause(true)
	_pause_phrase()
	_collection_back.grab_focus()
	_update_duck()
	_announce_collection_state()


func _hide_collection() -> void:
	audio.stop_voice()
	_cancel_collection_rails()
	_professional_library.clear()
	collection_page.hide()
	for control in _collection_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = _collection_focus_modes[control]
	_collection_focus_modes.clear()
	if _collection_from_home:
		_collection_from_home = false
		_show_mode_menu()
	feedback_timer.paused = _page_hidden or _mode_menu_open()
	_memory.pause(_page_hidden or _mode_menu_open() or _professional_input_blocked())
	_refresh()
	if _mode_id == "pop" and _pop_rewards_shown and not _page_hidden and not _mode_menu_open():
		_pop_rewards.resume()
	if _valid_focus(_focus_before_collection):
		_focus_before_collection.grab_focus()
	else:
		_default_focus().grab_focus()


func _announce_collection_state() -> void:
	if _collection_professional:
		_announce_status("Professional word library. " + str(_round_content.get("course_title", "")) + ". " + str(_round_content.get("module_title", "")))
		return
	var announcement := _collection_title.text + ". " + _growth_summary.text + " " + _age_notice.text
	if _journey_save_failed:
		announcement += " Theme preference not saved. Return Home to retry."
	_announce_status(announcement)


func _publish_coins() -> void:
	if _host == null:
		return
	var state: Dictionary = _coin_flight.snapshot()
	state["balance"] = coin_wallet.balance
	state["available"] = coin_wallet.ready and coin_wallet.error.is_empty()
	var value: String = JSON.stringify(state)
	if value != _coin_published:
		_coin_published = value
		_host.coinStatus(value)


func _load_collected_rewards() -> void:
	_progress_ready = medal_progress.load_progress()
	if _progress_ready:
		for mode in ["match", "memory"]:
			var pair: Dictionary = medal_progress.pair_round(mode)
			if pair.get("awarded", false) and not pair.get("settled", false):
				var credit: Dictionary = _credit_coins("pair:" + mode + ":" + str(pair.id), 1)
				_progress_ready = credit.ok and medal_progress.settle_pair_reward(mode, pair.id)
				if not _progress_ready:
					break
	_save_error = not _progress_ready
	_coin_flight.sync(coin_wallet.balance)
	_sync_collected_rewards()


func _update_duck() -> void:
	if duck == null or audio == null:
		return
	_header_duck_slot.show()
	var in_collection: bool = collection_page.visible
	var visible_here: bool = not in_collection and not _mode_menu_open() and _round_context.get("track") != "professional"
	var phrase_speaking: bool = _phrase_interaction_allowed() and audio.available and not audio.muted and audio.voice.playing
	_phrase.set_speaking(phrase_speaking)
	duck.set_outfit_theme(model.theme_id)
	duck.set_reduced_motion(reduced_motion)
	duck.set_speaking(visible_here and not _round_celebration_active() and not phrase_speaking and audio.available and audio.active and not audio.muted and audio.voice.playing)
	var active_phase: String = _memory.memory.phase if _mode_id == "memory" else model.phase
	if _mode_id == "pop":
		active_phase = _pop.game.phase
	elif _is_jelly_mode():
		active_phase = _active_jelly().game.phase
	var quiet_phase: bool = in_collection or active_phase in ["waiting", "matching"] \
		or (_mode_id == "pop" and active_phase in ["ready", "paused"])
	var microphone_busy: bool = _pop_speech_active or (_mode_id == "pop"
		and (_pop._listening or _pop._pending or _pop._reconnecting))
	var voice_busy: bool = audio.voice.playing
	duck.set_proactive_allowed(visible_here and quiet_phase and not _voice_mode and not _mode_menu_open()
		and (_mode_id != "phrase" or in_collection)
		and not microphone_busy and not voice_busy and not duck.speaking
		and not _pointer_focus_active and _proactive_touches.is_empty()
		and _controller_last_direction == Vector2.ZERO
		and not _memory.memory.studying and not Input.is_anything_pressed())
	if not visible_here:
		duck.hide()
		return
	var slot: Control = _header_duck_art_slot
	if not slot.is_visible_in_tree():
		duck.set_proactive_allowed(false)
		duck.hide()
		return
	var parent: Control = slot
	if duck.get_parent() != parent:
		duck.reparent(parent)
	var rect: Rect2 = slot.get_global_rect()
	if rect.position == Vector2.ZERO or rect.size.x <= 0 or rect.size.y <= 0:
		duck.hide()
		return
	duck.compact = false
	var pip_identity: String = "Pip" if _pip_age_description.is_empty() else "Pip · " + _pip_age_description
	_set_accessibility_name(duck, pip_identity + ". Press for a new move.")
	duck.position = parent.get_global_transform().affine_inverse() * rect.position
	duck.custom_minimum_size = Vector2(72, 72).min(rect.size) if in_collection else Vector2.ZERO
	duck.size = rect.size
	duck.show()
	var attention := ""
	if not in_collection and not _page_hidden \
		and not _mode_menu_open() and not _speech_debug_active and not _rebuilding:
		if _mode_id == "pop" and not _pop._stopped and active_phase in ["ready", "running", "paused"] \
			and (_pop._listening or _pop._pending or _pop._reconnecting):
			attention = "listening"
		elif _mode_id == "match" and active_phase in ["waiting", "matching", "feedback"] \
			and _voice_mode and _voice_attention_active:
			attention = "listening"
		elif _mode_id == "memory" and active_phase in ["waiting", "matching"] \
			and (_memory.memory.studying or _memory.memory.selected_indices.size() == 1):
			attention = "thinking"
		elif _mode_id == "match" and active_phase == "matching" and not model.selected_id.is_empty():
			attention = "thinking"
	duck.set_attention(attention)
	var accent: Color = Data.THEMES[model.theme_id].accent
	if duck.accent != accent:
		duck.accent = accent
		duck.queue_redraw()


func _play_duck() -> void:
	if _page_hidden or not duck.is_visible_in_tree() or collection_page.visible or _mode_menu_open():
		return
	if duck.is_manual_action_busy():
		return
	var tricks: Array = duck.age_actions()
	var caption: String = duck.perform_trick(tricks[_duck_trick_index % tricks.size()])
	if caption.is_empty():
		return
	_duck_trick_index += 1
	if _voice_mode or _pop_speech_active:
		return
	audio.interact(model.theme_id)
	_announce_status("Pip says hello! " + caption)


func _learning_words(for_phrase: bool = false) -> Array:
	var age: int = growth.learning_age()
	var dependencies: Array = _vocabulary_catalog.get("ages", {}).get(str(age), {}).get("word_ids", [])
	var words: Array = data.words.filter(func(word: Dictionary) -> bool:
		return dependencies.has(str(word.id)) if for_phrase else Data.word_age(word) == age).duplicate(true)
	for word: Dictionary in words:
		word["_practice_weight"] = _practice_weight(word)
	return words


func _practice_weight(word: Dictionary) -> float:
	if word.get("track") == "professional":
		var skills: Dictionary = professional.session.snapshot().progress.get("skills", {}).get(str(word.id), {})
		for evidence in skills.values():
			if evidence.get("earned", false):
				return WordSampler.MASTERED_WEIGHT
		return 1.0
	return WordSampler.MASTERED_WEIGHT if growth.is_mastered(str(word.id)) else 1.0


func _match_growth_answer(id: String, words: Array[String], correct: bool) -> void:
	if _mode_id == "match" and not _rebuilding:
		_record_growth(id, words, correct)
		if correct and not words.is_empty():
			_pair_matched(words[0])


func _pair_matched(word_id: String) -> void:
	if _pair_words.has(word_id) or _round_id.is_empty():
		return
	_pair_words.append(word_id)
	if _sync_pair_reward() and not model.chest_earned:
		_pair_reward.show_pair_result(_round_id, false)
	_refresh()


func _sync_pair_reward() -> bool:
	if _mode_id not in ["match", "memory"] or _round_id.is_empty():
		return true
	var pair: Dictionary = medal_progress.pair_round(_mode_id)
	if pair.get("id", "") != _round_id:
		pair = medal_progress.begin_pair_round(_mode_id, _round_id, _pair_proposed_pair)
	if pair.is_empty():
		_pair_save_failed = true
		_save_error = true
		return false
	model.chest_reward_pair = int(pair.pair)
	if not pair.awarded and int(pair.pair) > 0 and _pair_words.size() >= int(pair.pair):
		if not medal_progress.record_pair_reward(_mode_id, _round_id, model.theme_id):
			_pair_save_failed = true
			_save_error = true
			return false
		pair = medal_progress.pair_round(_mode_id)
		model.chest_earned = true
		model.reward_theme = JellyRewardProgress.theme_for_tier(1)
		_pair_reward.configure(_round_id, model.reward_theme, data.chests, reduced_motion)
		_pair_reward.show_pair_result(_round_id, true)
	if pair.awarded:
		model.chest_earned = true
		model.reward_theme = JellyRewardProgress.theme_for_tier(1)
	if model.phase == "won" and not pair.completed:
		if not medal_progress.finish_pair_round(_mode_id, _round_id):
			_pair_save_failed = true
			_save_error = true
			return false
	if _pair_save_failed:
		_save_error = false
	_pair_save_failed = false
	return true


func _settle_pair_reward() -> bool:
	if _mode_id not in ["match", "memory"] or _round_id.is_empty():
		return true
	# Unavailable reward storage must not trap an untouched practice board.
	# Once answers exist, preserve their pending outcome until it can be saved.
	if _pair_words.is_empty() and not model.chest_earned and _pair_save_failed:
		return true
	if not _sync_pair_reward():
		return false
	var pair: Dictionary = medal_progress.pair_round(_mode_id)
	if pair.get("id", "") == _round_id and pair.get("awarded", false):
		_pair_settlement_pending = true
		var credit: Dictionary = _credit_coins(_single_chest_receipt(), 1)
		if not credit.ok or not medal_progress.settle_pair_reward(_mode_id, _round_id):
			_pair_save_failed = true
			_save_error = true
			return false
		model.chest_state = "opened"
		_coin_flight.sync(coin_wallet.balance)
		_pair_settlement_pending = false
		_pair_save_failed = false
		_save_error = false
		_refresh_collection()
	return true


func _pair_reward_revealing() -> bool:
	if not is_instance_valid(_pair_reward):
		return false
	# A slow reveal frame must still leave room for the complete cheer before
	# final-pair settlement. Mute or navigation cancels its player immediately.
	var cheer_playing: bool = is_instance_valid(audio.pair_chest_discovery) and audio.pair_chest_discovery.playing
	return bool(_pair_reward.snapshot().get("performance_active", false)) or cheer_playing


func _sync_pair_presentation() -> void:
	if not is_instance_valid(_pair_reward):
		return
	var on_board: bool = _mode_id in ["match", "memory"] and not _page_hidden and not _rebuilding \
		and not collection_page.visible and not _speech_debug_active
	var allowed: bool = on_board and not _mode_menu_open() and not _settlement_dialog_open()
	if not allowed and _pair_reward.visible:
		audio.stop_pair_chest_discovery()
	_pair_reward.set_paused(not allowed)
	_pair_reward.visible = allowed
	var timed_peek: bool = allowed and _mode_id == "memory" and is_instance_valid(_memory) and _memory.memory.studying
	_pair_reward.set_status_suppressed(timed_peek)
	if is_instance_valid(_memory_peek_countdown):
		_memory_peek_countdown.visible = timed_peek
	# Opening the header menu must not move the board behind its overlay.
	_pair_reward_row.visible = on_board


func _layout_pair_reward() -> void:
	if is_instance_valid(_pair_reward):
		_pair_reward.set_toast_bounds(Rect2(Vector2.ZERO, _pair_reward.size))
	if is_instance_valid(_memory_peek_countdown) and is_instance_valid(_pair_reward_row):
		var unit: float = 1.0 / Style.ui_scale(self)
		var row: Vector2 = _pair_reward_row.size
		var has_chest: bool = model.chest_earned and _mode_id == "memory"
		var group_width: float = minf(324.0 * unit, row.x)
		var inset: float = minf(64.0 * unit, row.x * 0.2) if has_chest else 0.0
		_memory_peek_countdown.position = Vector2((row.x - group_width) * 0.5 + inset, 0.0)
		_memory_peek_countdown.size = Vector2(maxf(0.0, group_width - inset), row.y)


func _pair_reward_cue(round_id: String, cue: String) -> void:
	if round_id != _round_id or _page_hidden or _mode_menu_open() or collection_page.visible or _voice_listening \
		or _mode_id not in ["match", "memory"] or _settlement_dialog_open():
		return
	if cue == "reward":
		audio.play_pair_chest_discovery()


func _phrase_answered(id: String, words: Array[String], correct: bool) -> void:
	if not _phrase_interaction_allowed():
		return
	_record_growth(id, words, correct)
	if correct and not _round_id.is_empty() and not reduced_motion and _reward_confetti_allowed():
		_sync_reward_confetti()
		# Answer celebrations are independent of the chest earned at the finale.
		_reward_confetti.burst("%s:phrase:answer:%s" % [_round_id, id])


func _pop_growth_answer(id: String, words: Array[String], correct: bool) -> void:
	if _mode_id == "pop" and not _rebuilding and not _page_hidden and not collection_page.visible:
		_record_growth(id, words, correct)


func _record_growth(attempt_id: String, words: Array, correct: bool) -> void:
	if _round_context.get("track") == "professional":
		_record_professional(attempt_id, words, correct)
		return
	if _round_id.is_empty() or _round_context.get("track", "growth") != "growth":
		return
	var was_failed: bool = _growth_save_failed
	var result: Dictionary = growth.record_attempt(_round_id + ":" + attempt_id, words, correct)
	_growth_save_failed = not bool(result.save_ok)
	_refresh_growth()
	if _growth_save_failed != was_failed:
		# Memory, Phrase and Pop do not otherwise refresh the shared header per answer.
		_refresh.call_deferred()
	if bool(result.get("aged_up", false)):
		_announce_status("Pip grew to %s! %s. Meet Pip's new look." % [growth.snapshot().age_label, growth.snapshot().label])
	elif bool(result.leveled_up):
		_announce_status("%s! Keep mastering new words to grow." % growth.snapshot().label)


func _sync_growth_load_notice() -> void:
	if growth.ready or _round_context.get("track") == "professional" or _mode_menu_open():
		return
	_message.text = "Your learning progress could not be loaded.\nChoose Retry saving before you play."
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.show()


func _refresh_growth() -> void:
	_prefetch_vocabulary()
	if not is_instance_valid(_growth_button):
		return
	var state: Dictionary = growth.snapshot()
	_mode_panel.configure_growth(state)
	for mascot in [duck, _phrase.pip, _round_celebration.pip, _single_result.pip]:
		if is_instance_valid(mascot):
			mascot.set_growth_age(growth.age)
	_growth_button.configure(state)
	_growth_button.visible = _round_context.get("track") != "professional"
	_professional_button.visible = not _growth_button.visible
	if _professional_button.visible:
		_professional_heading.text = str(_round_content.get("course_title", "Professional English"))
		var saved: Dictionary = professional.session.snapshot()
		var learned := 0
		for term in _round_content.get("requirements", {}).get("terms", []):
			for skill in term.skills:
				if saved.progress.get("skills", {}).get(term.sense_id, {}).get(skill, {}).get("earned", false):
					learned += 1
					break
		var progress_text: String = "%d / 50 learned" % learned if saved.progress_loaded and not saved.blocked else "Progress unavailable"
		_professional_progress_label.text = progress_text
		_professional_button.tooltip_text = "%s · %s\n%s" % [_professional_heading.text, _round_content.get("module_title", _round_context.module_id), progress_text]
		_set_accessibility_name(_professional_button, _professional_button.tooltip_text + ". Open word library.")
		var previous_focus: int = _professional_button.focus_mode
		Style.quiet_button(_professional_button, _active_palette.get("accent", Style.GOOD))
		_professional_button.focus_mode = previous_focus
	_pip_age_description = str(state.age_label) if state.ready else ""
	_collection_title.text = "%s · %s" % [state.label, "Baby Pip" if state.age == 0 else "Pip · " + state.age_label] if state.ready else "Grow with Pip"
	if collection_page.visible and _collection_professional:
		_collection_title.text = "Word library"
	var level_summary: String = "Lv99 reached!" if state.level_completed else "%d new %s to Lv%d" % [state.level_remaining, "word" if state.level_remaining == 1 else "words", state.level + 1]
	var age_target: String = "Age 12+" if state.learning_age == 12 else "Age %d" % state.learning_age
	_growth_summary.text = "%s · %d words learned\n%s: %d / %d mastered%s" % [level_summary, state.lifetime_mastered, age_target, state.mastered, state.total, " · All ages unlocked!" if state.completed else " · Master this set to help Pip grow."] if state.ready else "Learning progress is unavailable. Retry saving to load it."
	var serialized: String = JSON.stringify(state)
	if _host != null and serialized != _growth_published:
		_growth_published = serialized
		_host.growthStatus(serialized)


func _style_growth_progress() -> void:
	var scale: float = Style.ui_scale(self)
	var width: float = size.x * scale
	var coin_width: float = 84.0 if width < 680 else 100.0 if coin_wallet.balance < 1000000 else 124.0
	var coin_height: float = 28.0
	_coin_counter.size = Vector2(coin_width, coin_height) / scale
	_growth_button.fit_companion(scale)
	_layout_coin_counter()


func _publish_growth_view() -> void:
	if _host == null or not is_instance_valid(_growth_button):
		return
	var controls: Array = [_growth_control(_growth_button), _growth_control(_growth_bar)]
	for control: Control in [_mode_heading_button, _voice_button, hint_button, _memory.study_button, _coin_counter, _storage_retry_button]:
		controls.append(_growth_control(control))
	var state := {"visible": collection_page.visible, "controls": controls}
	state["game_area"] = _growth_control(_content_margins)
	state["result"] = _growth_control(_single_result)
	state.result["controls"] = []
	for control: Control in [chest_button, _single_result.retry_button, _single_result.replay_button, _single_result.home_button]:
		state.result.controls.append(_growth_control(control))
	state["settlement"] = _settlement_dialog.snapshot()
	state["background_game"] = _growth_control(_memory if _mode_id == "memory" else _phrase if _mode_id == "phrase" else _pop if _mode_id == "pop" else _active_jelly() if _is_jelly_mode() else _match_playfield)
	state["pip"] = _growth_control(duck)
	state.pip["age"] = duck.growth_age
	state.pip["action"] = duck._idle_action
	state.pip["signature_actions"] = duck.age_actions()
	state["vocabulary"] = _vocabulary_snapshot()
	if _mode_id == "memory":
		var price_area: Rect2 = _memory.study_button.price_rect()
		price_area.position += _memory.study_button.global_position
		state["memory"] = {"peek": {"count": _memory.memory.peeks,
			"next_price": _memory.memory.peek_price(), "price_text": str(_memory.study_button.cost),
			"price_rect": [price_area.position.x, price_area.position.y, price_area.size.x, price_area.size.y],
			"remaining": _memory.memory.peek_remaining, "duration": _memory.memory.peek_duration,
			"seconds": ceili(_memory.memory.peek_remaining), "progress": _memory_peek_countdown.progress(),
			"countdown": _memory_peek_countdown.snapshot(),
			"studying": _memory.memory.studying, "round_id": _round_id}}
	elif _mode_id == "match":
		var price_area: Rect2 = hint_button.price_rect()
		price_area.position += hint_button.global_position
		state["match"] = {"hint": {"uses": model.hints_used, "price": _match_hint_price(),
			"price_text": str(hint_button.cost),
			"price_rect": [price_area.position.x, price_area.position.y, price_area.size.x, price_area.size.y],
			"active": not model.hint_ids.is_empty(), "round_id": _round_id}}
	if is_instance_valid(_vocabulary_prompt) and _vocabulary_prompt.visible:
		controls.append(_growth_control(_vocabulary_retry))
		controls.append(_growth_control(_vocabulary_back))
	if collection_page.visible:
		state["catalog"] = _professional_library.snapshot() if _collection_professional else _age_catalog.snapshot()
		state.catalog["viewport_rect"] = _growth_control(_professional_library.scroll if _collection_professional else _age_catalog.scroll).rect
		state.catalog.erase("growth")
		state.catalog.erase("word_ids")
		state["notice"] = _age_notice.text
		for control in _focus_candidates():
			controls.append(_growth_control(control))
	else:
		state["board"] = _growth_control(_memory._board if _mode_id == "memory" else _match_playfield)
	var serialized := JSON.stringify(state)
	if serialized != _growth_view_published:
		_growth_view_published = serialized
		_host.growthView(serialized)


func _growth_control(control: Control) -> Dictionary:
	var rect := control.get_global_rect()
	var result := {"name": str(control.name), "visible": control.is_visible_in_tree(),
		"focused": control.has_focus(),
		"disabled": control.disabled if control is BaseButton else false,
		"text": control.text if control is Button or control is Label else "",
		"description": str(control.get("accessibility_name")),
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}
	if control is Range:
		result["value"] = control.value
		result["max_value"] = control.max_value
	return result
