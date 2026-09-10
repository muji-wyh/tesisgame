extends Control

const Model = preload("res://scripts/game_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Card = preload("res://scripts/word_card.gd")
const Audio = preload("res://scripts/game_audio.gd")
const Chest = preload("res://scripts/chest_view.gd")
const Effects = preload("res://scripts/celebration.gd")
const Medal = preload("res://scripts/medal_view.gd")
const MedalProgress = preload("res://scripts/medal_progress.gd")
const Mascot = preload("res://scripts/duck_mascot.gd")
const ChoiceGame = preload("res://scripts/choice_game.gd")
const MemoryGarden = preload("res://scripts/memory_garden.gd")
const WordLesson = preload("res://scripts/word_lesson.gd")
const PlayroomState = preload("res://scripts/playroom_state.gd")
const PlayroomView = preload("res://scripts/playroom_view.gd")
const AdventureBook = preload("res://scripts/adventure_book.gd")
const MODES := {"learn": "Learn", "match": "Match", "sky": "Sky", "listen": "Listen", "memory": "Memory"}
const HOLD_SECONDS: float = 1.2
const SCROLL_FRICTION: float = 8.0
const LOSS_REACTIONS := ["High five! Let's try again!", "A big bear hug for you!", "You kept trying. Well done!"]
const PREVIEW_REACTIONS := ["Boing!", "Wheee!", "Big hug!"]

class ProgressBadges:
	extends Control

	const SUCCESS := 0
	const RETRY := 1

	var filled_count: int = 0
	var total_count: int = 3
	var badge_kind: int = SUCCESS
	var mascot_inset: float = 0.0

	func _init(kind: int = SUCCESS) -> void:
		badge_kind = kind
		custom_minimum_size = Vector2(88, 38)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_filled_count(value: int, total: int = 3) -> void:
		total_count = maxi(1, total)
		filled_count = clampi(value, 0, total_count)
		queue_redraw()

	func set_mascot_inset(value: float) -> void:
		if not is_equal_approx(mascot_inset, value):
			mascot_inset = value
			queue_redraw()

	func _draw() -> void:
		if total_count <= 0:
			return
		var gap: float = 5.0
		var available: float = size.x - mascot_inset
		var radius: float = clampf(minf(size.y * 0.31, (available - gap * float(total_count - 1)) / float(total_count) * 0.5), 5.0, 13.0)
		var total_width: float = radius * 2.0 * total_count + gap * float(total_count - 1)
		var x: float = mascot_inset + maxf(radius, (available - total_width) * 0.5 + radius)
		for index in range(total_count):
			var center := Vector2(x + float(index) * (radius * 2.0 + gap), size.y * 0.5)
			var filled := index < filled_count
			if badge_kind == SUCCESS:
				_draw_success_badge(center, radius, filled)
			else:
				_draw_retry_badge(center, radius, filled)

	func _draw_success_badge(center: Vector2, radius: float, filled: bool) -> void:
		if filled:
			Style.draw_match_badge(self, center, radius)
			return
		draw_circle(center, radius, Color("#e8f5dc"))
		draw_arc(center, radius, 0.0, TAU, 28, Color("#9fcf8f"), 2.0, true)
		draw_circle(center, radius * 0.34, Color("#f8fff2"))

	func _draw_retry_badge(center: Vector2, radius: float, filled: bool) -> void:
		var fill := Style.WRONG if filled else Color("#ffe9df")
		var stroke := Style.WRONG.darkened(0.12) if filled else Color("#eba58f")
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0)
		])
		draw_colored_polygon(diamond, fill)
		var outline := PackedVector2Array([
			diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]
		])
		draw_polyline(outline, stroke, 2.0, true)
		if not filled:
			draw_circle(center, radius * 0.20, Color("#fff8f3"))
			return
		draw_circle(center + Vector2(-radius * 0.32, -radius * 0.22), radius * 0.10, Color.WHITE)
		draw_circle(center + Vector2(radius * 0.32, -radius * 0.22), radius * 0.10, Color.WHITE)
		draw_arc(center + Vector2(0.0, -radius * 0.05), radius * 0.42, PI * 0.18, PI * 0.82, 14, Color.WHITE, maxf(2.0, radius * 0.17), true)


class RewardSparkle:
	extends Control

	enum Shape { CIRCLE, HEART, STAR, LEAF, SNOWFLAKE }

	var progress: float = 0.0
	var accent: Color = Style.GOOD
	var shape_kind: Shape = Shape.CIRCLE
	var particle_count: int = 8

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
		var count: int = clampi(particle_count, 1, 12)
		if count == 12:
			draw_arc(center, radius * 0.72, 0.0, TAU, 40, Color(accent.r, accent.g, accent.b, alpha * 0.35), 2.0, true)
		for index in range(count):
			var angle := TAU * float(index) / float(count) + progress * 0.18
			var point := center + Vector2(cos(angle), sin(angle)) * radius * 0.86
			var tint: Color = Color.WHITE if index % 3 == 2 else accent.lightened(0.35 if index % 3 == 1 else 0.0)
			tint.a = alpha
			var symbol_size: float = lerpf(8.0, 14.0, progress) * (1.25 if count == 12 else 1.0)
			_draw_symbol(point, symbol_size, progress * (0.5 if index % 2 == 0 else -0.5), tint)

	func _draw_symbol(point: Vector2, radius: float, rotation_angle: float, tint: Color) -> void:
		var stroke := Color(accent.r, accent.g, accent.b, tint.a)
		if shape_kind == Shape.CIRCLE:
			draw_circle(point, radius * 0.3, tint)
			return
		if shape_kind == Shape.SNOWFLAKE:
			var branches := PackedVector2Array()
			for arm in range(6):
				var direction := Vector2.UP.rotated(TAU * float(arm) / 6.0 + rotation_angle)
				branches.append(point)
				branches.append(point + direction * radius)
				for side in [-1.0, 1.0]:
					var fork := point + direction * radius * 0.58
					branches.append(fork)
					branches.append(fork + direction.rotated(side * 0.65) * radius * 0.32)
			draw_multiline(branches, stroke, 4.0, true)
			draw_multiline(branches, Color(1, 1, 1, tint.a), 1.6, true)
			return
		var vertices: Array[Vector2] = []
		match shape_kind:
			Shape.HEART:
				vertices = [Vector2(0, 1), Vector2(-0.9, 0.1), Vector2(-0.8, -0.6),
					Vector2(-0.4, -0.8), Vector2(0, -0.4), Vector2(0.4, -0.8),
					Vector2(0.8, -0.6), Vector2(0.9, 0.1)]
			Shape.STAR:
				for index in range(10):
					vertices.append(Vector2.UP.rotated(PI * float(index) / 5.0) * (1.0 if index % 2 == 0 else 0.45))
			Shape.LEAF:
				vertices = [Vector2(0, -1), Vector2(0.22, -0.4), Vector2(0.6, -0.7),
					Vector2(0.53, -0.18), Vector2(1, -0.3), Vector2(0.65, 0.25),
					Vector2(0.8, 0.48), Vector2(0.2, 0.55), Vector2(0, 1),
					Vector2(-0.2, 0.55), Vector2(-0.8, 0.48), Vector2(-0.65, 0.25),
					Vector2(-1, -0.3), Vector2(-0.53, -0.18), Vector2(-0.6, -0.7), Vector2(-0.22, -0.4)]
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
var _collection_duck_slot: Control
var _preview_duck_slot: Control
var cards: Dictionary = {}
var grid: GridContainer
var feedback_timer: Timer
var audio: Audio
var chest: Chest
var effects: Effects
var theme_buttons: Array[Button] = []
var hint_button: Button
var _voice_button: Button
var _voice_space: Control
var _voice_mode: bool = false
var _mode_id: String = "learn"
var _listen_word_failed: bool = false
var _mode_row: HBoxContainer
var _mode_buttons: Array[Button] = []
var _choice: ChoiceGame
var _memory: MemoryGarden
var _lesson: WordLesson
var _match_feedback: WordLesson
var _feedback_key: String = ""
var _new_adventure_button: Button
var _explore_button: Button
var _adventure_book: AdventureBook
var _adventures_open: bool = false
var _journey_save_failed: bool = false
var _pending_visit_id: String = ""
var _gift_label: Label
var _try_gift_button: Button
var _unlocked_gift: Dictionary = {}
var playroom_state := PlayroomState.new()
var _playroom_ready: bool = false
var _room: PlayroomView
var _voice_listening: bool = false
var _speech_queue: Array[String] = []
var collection_button: Button
var collection_page: Panel
var collected_rewards: Dictionary = {}
var replay_button: Button
var chest_button: Button
var reward_image: Medal
var failure_image: TextureRect
var failure_button: Button
var reduced_motion: bool = false
var _background: ColorRect
var _success: ProgressBadges
var _mistakes: ProgressBadges
var _match_caption: Label
var _adventure_label: Label
var _goal_label: Label
var _goal_medal: Medal
var _found_words: HBoxContainer
var _found_words_scroll: ScrollContainer
var _found_words_heading: Label
var _message: Label
var _storage_retry_button: Button
var _outcome: Control
var _stage: Panel
var _result_text: VBoxContainer
var _title: Label
var _caption: Label
var _medallion: Panel
var _reward_number: Label
var _reward_flight_image: TextureRect
var _fragment_image: Medal
var _fragment_tween: Tween
var _fragment_active: bool = false
var _pending_fragment: Dictionary = {}
var _progress_ready: bool = false
var _save_error: bool = false
var _collection_scroll: ScrollContainer
var _collection_grid: VBoxContainer
var _collection_back: Button
var _collection_title: Label
var _collection_section: String = "room"
var _collection_tabs: Dictionary = {}
var _collection_rows: Array[GridContainer] = []
var _collection_headings: Dictionary = {}
var _reward_slots: Dictionary = {}
var _collection_focus_modes: Dictionary = {}
var _focus_before_collection: Control
var _preview_page: Panel
var _preview_image: Medal
var _preview_title: Label
var _preview_caption: Label
var _preview_close: Button
var _preview_play_button: Button
var _preview_wear_button: Button
var _playroom_caption: Label
var _playroom_medal: Medal
var _playroom_buttons: Array[Button] = []
var _favorite_reward_id: String = ""
var playroom_save_path: String = "user://playroom.cfg"
var _duck_trick_index: int = 0
var _preview_sparkle: RewardSparkle
var _preview_focus_modes: Dictionary = {}
var _focus_before_preview: Control
var _preview_reward_id: String = ""
var _preview_tap_count: int = 0
var _preview_tween: Tween
var _failure_sparkle: RewardSparkle
var _failure_tween: Tween
var _loss_reaction_index: int = 0
var _last_phase: String = ""
var _rebuilding: bool = false
var _reward_tween: Tween
var _reward_transfer_active: bool = false
var _reward_delivered_to_collection: bool = false
var _feedback_tweens: Array[Tween] = []
var _feedback_sparkles: Array[Control] = []
var _feedback_origins: Dictionary = {}
var _holding_chest: bool = false
var _hold_elapsed: float = 0.0
var _drag_distance: float = 0.0
var _dragging_chest: bool = false
var _drag_has_anchor: bool = false
var _drag_anchor_position: Vector2 = Vector2.ZERO
var _drag_anchor_offset: Vector2 = Vector2.ZERO
var _collection_dragging: bool = false
var _collection_dragged: bool = false
var _collection_drag_pointer: int = -1
var _collection_drag_start_position: Vector2 = Vector2.ZERO
var _collection_drag_start_scroll: Vector2 = Vector2.ZERO
var _collection_velocity: Vector2 = Vector2.ZERO
var _collection_inertia_position: Vector2 = Vector2.ZERO
var _collection_last_scroll: Vector2 = Vector2.ZERO
var _collection_last_sample_usec: int = 0
var _controller_mode: bool = false
var _controller_stick: Vector2 = Vector2.ZERO
var _controller_dpad: Vector2 = Vector2.ZERO
var _controller_last_direction: Vector2 = Vector2.ZERO
var _controller_repeat_elapsed: float = 0.0
var _controller_holding_chest: bool = false
var _controller_accept_needs_release: bool = true
var _status_announcement: String = ""
var _preferred_theme: String = ""
var _host: JavaScriptObject
var _loading_finished_callback: JavaScriptObject
var _hidden_callback: JavaScriptObject
var _motion_callback: JavaScriptObject
var _speech_result_callback: JavaScriptObject
var _speech_state_callback: JavaScriptObject


func _ready() -> void:
	theme = Theme.new()
	theme.default_font_size = 24
	_build_controls()
	if not data.load_all():
		_show_error(data.error)
		return
	effects.configure(data.chests)
	_load_collected_rewards()
	_build_collection()
	model.changed.connect(_refresh)
	resized.connect(_layout)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	reduced_motion = DisplayServer.accessibility_should_reduce_animation() == 1
	call_deferred("_sync_controller_accept_startup")
	_connect_browser()
	_load_favorite_reward()
	_refresh_favorite_reward()
	new_round()
	if _host != null:
		get_tree().paused = true
		_loading_finished_callback = JavaScriptBridge.create_callback(_on_loading_finished)
		_host.ready(_loading_finished_callback)


func _on_loading_finished(_args: Array) -> void:
	_stop_controller_actions()
	get_tree().paused = false


func _build_controls() -> void:
	_background = ColorRect.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := MarginContainer.new()
	add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 12)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margins.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	_success = ProgressBadges.new(ProgressBadges.SUCCESS)
	_success.name = "MatchProgress"
	_success.tooltip_text = "0 matches"
	_success.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_success)
	_match_caption = Style.label("Find 3 pairs", 14)
	_match_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success.add_child(_match_caption)
	_match_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_match_caption.offset_top = -20
	_mistakes = ProgressBadges.new(ProgressBadges.RETRY)
	_mistakes.name = "RetryProgress"
	_mistakes.tooltip_text = "0 mistakes"
	_mistakes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_mistakes)
	_voice_button = Button.new()
	_voice_button.name = "Voice"
	_voice_button.text = "Voice"
	_voice_button.toggle_mode = true
	_voice_button.pressed.connect(_toggle_voice)
	header.add_child(_voice_button)
	hint_button = Button.new()
	hint_button.name = "Hint"
	hint_button.text = "Hint"
	hint_button.tooltip_text = "One hint per round (Xbox X)"
	_set_accessibility_name(hint_button, "Hint: one per round")
	hint_button.pressed.connect(_request_hint)
	header.add_child(hint_button)
	_explore_button = Button.new()
	_explore_button.name = "Explore"
	_explore_button.text = "Explore"
	_set_accessibility_name(_explore_button, "Choose an adventure")
	_explore_button.pressed.connect(_show_adventures)
	header.add_child(_explore_button)
	collection_button = Button.new()
	collection_button.name = "Rewards"
	_set_accessibility_name(collection_button, "My rewards")
	collection_button.icon = load(Data.theme("spring").symbol)
	collection_button.expand_icon = true
	collection_button.tooltip_text = "View collected rewards"
	collection_button.pressed.connect(_show_collection)
	header.add_child(collection_button)
	_goal_medal = _medal_picture(collection_button)
	_goal_medal.show_missing = true
	_goal_medal.offset_left = 10
	_goal_medal.offset_top = 4
	_goal_medal.offset_right = -10
	_goal_medal.offset_bottom = -22
	_goal_label = Style.label("0/3", 16)
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collection_button.add_child(_goal_label)
	_goal_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_goal_label.offset_top = -24
	_goal_label.offset_bottom = -4
	var seasons := HBoxContainer.new()
	seasons.add_theme_constant_override("separation", 4)
	column.add_child(seasons)
	for id in Model.THEMES:
		var button := Button.new()
		var palette: Dictionary = Data.theme(id)
		button.name = palette.name
		_set_accessibility_name(button, palette.name)
		button.icon = load(palette.symbol)
		button.expand_icon = true
		button.tooltip_text = ""
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(choose_theme.bind(id))
		seasons.add_child(button)
		theme_buttons.append(button)
	_mode_row = HBoxContainer.new()
	_mode_row.add_theme_constant_override("separation", 8)
	column.add_child(_mode_row)
	for id in MODES:
		var button := Button.new()
		button.name = "Mode_" + id
		button.text = MODES[id]
		button.clip_text = true
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_set_accessibility_name(button, str(MODES[id]) + ": practise these same five words")
		button.pressed.connect(choose_mode.bind(id))
		_mode_row.add_child(button)
		_mode_buttons.append(button)
	_adventure_label = Style.label("Word explorers", 18)
	_adventure_label.name = "Adventure"
	_adventure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_adventure_label.clip_text = true
	_adventure_label.custom_minimum_size.y = 28
	column.add_child(_adventure_label)
	_gift_label = Style.label("", 14)
	_gift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gift_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_gift_label)
	_voice_space = Control.new()
	_voice_space.name = "SpeechPanelSpace"
	_voice_space.custom_minimum_size = Vector2(0, 112)
	_voice_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voice_space.item_rect_changed.connect(_sync_voice_bounds)
	_voice_space.hide()
	column.add_child(_voice_space)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.resized.connect(_fit_grid)
	column.add_child(grid)
	_lesson = WordLesson.new()
	_lesson.name = "LearnWords"
	_lesson.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lesson.hear_requested.connect(_lesson_hear)
	_lesson.word_changed.connect(_association_changed)
	_lesson.word_changed.connect(func(word: Dictionary) -> void:
		if _mode_id == "learn" and not _rebuilding:
			_announce_status("Learn: " + str(word.text) + ". Look, read, and press Hear."))
	_lesson.finished.connect(func() -> void: choose_mode("match"))
	column.add_child(_lesson)
	_match_feedback = WordLesson.new()
	_match_feedback.name = "MatchCorrection"
	_match_feedback.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_match_feedback.hear_requested.connect(_lesson_hear)
	_match_feedback.word_changed.connect(_association_changed)
	_match_feedback.finished.connect(_continue_match)
	_match_feedback.hide()
	column.add_child(_match_feedback)
	_choice = ChoiceGame.new()
	_choice.name = "ChoiceGame"
	_choice.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choice.answer_chosen.connect(_choice_answer)
	_choice.progress_changed.connect(_choice_progress)
	_choice.round_finished.connect(_choice_finished)
	_choice.hear_requested.connect(_choice_hear)
	_choice.prompt_ready.connect(func() -> void:
		audio.stop_voice()
		_listen_word_failed = false
		_choice.set_audio_available(audio.available and not audio.muted)
		if not _rebuilding:
			_refresh_controller_focus()
			if not collection_page.visible and not _preview_page.visible:
				var prompt: String = _choice.status_label.text
				if _mode_id == "listen" and not _choice.audio_available:
					prompt += " " + str(_choice.current_target.text) + "."
				_announce_status(prompt))
	_choice.hide()
	column.add_child(_choice)
	_choice.feedback_view.word_changed.connect(_association_changed)
	_memory = MemoryGarden.new()
	_memory.name = "MemoryGarden"
	_memory.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_memory.card_revealed.connect(_memory_revealed)
	_memory.answer_chosen.connect(_memory_answer)
	_memory.progress_changed.connect(_memory_progress)
	_memory.round_finished.connect(_memory_finished)
	_memory.hear_requested.connect(_lesson_hear)
	_memory.prompt_ready.connect(_memory_prompt)
	_memory.hide()
	column.add_child(_memory)
	_memory.feedback_view.word_changed.connect(_association_changed)
	_outcome = Control.new()
	_outcome.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outcome.resized.connect(_layout_result)
	column.add_child(_outcome)
	_stage = Panel.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = true
	_stage.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_outcome.add_child(_stage)
	chest = Chest.new()
	_stage.add_child(chest)
	chest.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chest.opened.connect(_on_chest_opened)
	effects = Effects.new()
	_stage.add_child(effects)
	effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	chest_button.pressed.connect(_finish_fragment_delivery)
	chest_button.gui_input.connect(_chest_input)
	_medallion = Panel.new()
	_medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_medallion)
	reward_image = _medal_picture(_medallion)
	reward_image.offset_left = 8
	reward_image.offset_top = 8
	reward_image.offset_right = -8
	reward_image.offset_bottom = -24
	_reward_number = Style.label("", 18)
	_reward_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_number.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_medallion.add_child(_reward_number)
	_reward_number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reward_number.offset_bottom = -4
	failure_image = _picture(_stage)
	failure_image.texture = load("res://assets/images/scenes/try-again.svg")
	failure_image.offset_left = 20
	failure_image.offset_top = 20
	failure_image.offset_right = -20
	failure_image.offset_bottom = -20
	_failure_sparkle = RewardSparkle.new()
	_failure_sparkle.shape_kind = RewardSparkle.Shape.HEART
	_failure_sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_failure_sparkle.hide()
	_stage.add_child(_failure_sparkle)
	_failure_sparkle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	failure_button = Button.new()
	failure_button.name = "PlayWithBear"
	failure_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_set_accessibility_name(failure_button, "Play with the bear")
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		failure_button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	failure_button.pressed.connect(_play_loss_bear)
	_stage.add_child(failure_button)
	failure_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	failure_button.hide()
	_result_text = VBoxContainer.new()
	_result_text.add_theme_constant_override("separation", 10)
	_outcome.add_child(_result_text)
	_result_text.minimum_size_changed.connect(_layout_result)
	_title = Style.label("You did it!", 34)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_text.add_child(_title)
	_caption = Style.label("Hold to find a piece!", 22)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_text.add_child(_caption)
	_found_words_heading = Style.label("Practise these words · tap to hear", 14)
	_found_words_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_found_words_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_text.add_child(_found_words_heading)
	_found_words = HBoxContainer.new()
	_found_words.name = "FoundWords"
	_found_words.add_theme_constant_override("separation", 8)
	_found_words_scroll = ScrollContainer.new()
	_found_words_scroll.custom_minimum_size = Vector2(0, 88)
	_found_words_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_found_words_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_result_text.add_child(_found_words_scroll)
	_found_words_scroll.add_child(_found_words)
	var result_actions := HBoxContainer.new()
	result_actions.add_theme_constant_override("separation", 8)
	_result_text.add_child(result_actions)
	replay_button = Button.new()
	replay_button.text = "Repeat lesson"
	replay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_button.pressed.connect(_replay)
	result_actions.add_child(replay_button)
	_new_adventure_button = Button.new()
	_new_adventure_button.name = "NewAdventure"
	_new_adventure_button.text = "New adventure"
	_new_adventure_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_adventure_button.pressed.connect(_show_adventures)
	result_actions.add_child(_new_adventure_button)
	_try_gift_button = Button.new()
	_try_gift_button.text = "Try it with Pip"
	_try_gift_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_try_gift_button.pressed.connect(_try_unlocked_gift)
	_try_gift_button.hide()
	result_actions.add_child(_try_gift_button)
	_message = Style.label("", 16)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.hide()
	column.add_child(_message)
	_storage_retry_button = Button.new()
	_storage_retry_button.name = "RetryRewards"
	_storage_retry_button.text = "Retry rewards"
	_storage_retry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_storage_retry_button.pressed.connect(func() -> void:
		if _save_error:
			_replay())
	_storage_retry_button.hide()
	header.add_child(_storage_retry_button)
	header.move_child(_storage_retry_button, 0)
	_build_collection_shell()
	audio = Audio.new()
	add_child(audio)
	audio.status_changed.connect(_audio_status)
	audio.word_failed.connect(_word_audio_failed)
	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.wait_time = 0.7
	feedback_timer.timeout.connect(_resolve_feedback)
	add_child(feedback_timer)
	_build_reward_preview_shell()
	duck = Mascot.new()
	duck.z_index = 80
	duck.pressed.connect(_play_duck)
	duck.gui_input.connect(_collection_scroll_input.bind(duck))
	duck.focus_entered.connect(func() -> void:
		if collection_page.visible and not _preview_page.visible:
			_ensure_collection_focus_visible(_collection_duck_slot))
	duck.hide()
	add_child(duck)
	_set_accessibility_name(duck, "Pip the duck. Press to say hello.")
	_outcome.hide()


func _build_collection_shell() -> void:
	collection_page = Panel.new()
	collection_page.name = "Collection"
	collection_page.z_index = 50
	add_child(collection_page)
	collection_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := MarginContainer.new()
	collection_page.add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 16)
	var column := VBoxContainer.new()
	margins.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_collection_duck_slot = Control.new()
	_collection_duck_slot.custom_minimum_size = Vector2(160, 160)
	_collection_duck_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collection_title = Style.label("My rewards", 32)
	_collection_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_collection_title)
	for entry in [["room", "Pip's room"], ["medals", "Medals"]]:
		var button := Button.new()
		button.name = "Rewards_" + entry[0]
		button.text = entry[1]
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_show_reward_section.bind(entry[0]))
		header.add_child(button)
		_collection_tabs[entry[0]] = button
	_collection_back = Button.new()
	_collection_back.text = "Back"
	_collection_back.pressed.connect(_hide_collection)
	header.add_child(_collection_back)
	_collection_scroll = ScrollContainer.new()
	_collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_collection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_collection_scroll.gui_input.connect(_collection_scroll_input.bind(_collection_scroll))
	column.add_child(_collection_scroll)
	_collection_grid = VBoxContainer.new()
	_collection_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_scroll.add_child(_collection_grid)
	collection_page.hide()


func _build_reward_preview_shell() -> void:
	_preview_page = Panel.new()
	_preview_page.name = "RewardPreview"
	_preview_page.z_index = 70
	_preview_page.hide()
	add_child(_preview_page)
	_preview_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_page.add_theme_stylebox_override("panel", Style.box(Color(1, 1, 1, 0.94), Style.GOOD.lightened(0.4), 0, 0))
	var margins := MarginContainer.new()
	_preview_page.add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 22)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margins.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_preview_duck_slot = Control.new()
	_preview_duck_slot.custom_minimum_size = Vector2(72, 72)
	_preview_duck_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_preview_duck_slot)
	_preview_title = Style.label("", 30)
	_preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_preview_title)
	_preview_close = Button.new()
	_preview_close.text = "Back"
	Style.button(_preview_close, Style.GOOD)
	_preview_close.pressed.connect(_hide_reward_preview)
	header.add_child(_preview_close)
	var stage := Panel.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override("panel", Style.box(Color.WHITE, Color("#d7efc7"), 28, 4))
	column.add_child(stage)
	_preview_image = _medal_picture(stage)
	_preview_image.offset_left = 34
	_preview_image.offset_top = 22
	_preview_image.offset_right = -34
	_preview_image.offset_bottom = -22
	_preview_image.pivot_offset = Vector2.ZERO
	_preview_sparkle = RewardSparkle.new()
	_preview_sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_sparkle.hide()
	stage.add_child(_preview_sparkle)
	_preview_sparkle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_play_button = Button.new()
	_preview_play_button.text = ""
	_preview_play_button.tooltip_text = "Play with reward"
	_preview_play_button.focus_mode = Control.FOCUS_ALL
	_preview_play_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_set_accessibility_name(_preview_play_button, "Play with reward")
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		_preview_play_button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	_preview_play_button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Style.GOOD, 28, 4))
	_preview_play_button.pressed.connect(_play_reward_preview)
	stage.add_child(_preview_play_button)
	_preview_play_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_play_button.focus_neighbor_top = _preview_close.get_path()
	_preview_caption = Style.label("Tap the reward to play!", 20)
	_preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_preview_caption)
	_preview_wear_button = Button.new()
	_preview_wear_button.text = "Display with Pip"
	_preview_wear_button.pressed.connect(_wear_preview_reward)
	Style.button(_preview_wear_button, Style.GOOD)
	column.add_child(_preview_wear_button)


func _build_collection() -> void:
	if duck != null and duck.get_parent() != self:
		duck.reparent(self)
	if _collection_duck_slot.get_parent() != null:
		_collection_duck_slot.get_parent().remove_child(_collection_duck_slot)
	for child in _collection_grid.get_children():
		_collection_grid.remove_child(child)
		child.queue_free()
	_reward_slots.clear()
	_collection_rows.clear()
	_collection_headings.clear()
	_build_playroom()
	for theme_id in Model.THEMES:
		var heading := Style.label("", 26)
		_collection_headings[theme_id] = heading
		_collection_grid.add_child(heading)
		_add_reward_row(Data.medals(theme_id))
		var earlier: Array = Data.rewards(theme_id).filter(
			func(reward: Dictionary) -> bool: return medal_progress.legacy_rewards.has(reward.id))
		if not earlier.is_empty():
			_collection_grid.add_child(Style.label("Earlier rewards", 20))
			_add_reward_row(earlier)
	_refresh_collection()
	_layout_collection()
	_adventure_book = AdventureBook.new()
	_adventure_book.name = "AdventureBook"
	_collection_grid.add_child(_adventure_book)
	_adventure_book.adventure_selected.connect(_choose_adventure)
	_adventure_book.surprise_requested.connect(func() -> void: _choose_adventure(""))
	_adventure_book.retry_requested.connect(_retry_journey)
	_adventure_book.hide()
	for control in _adventure_book.controls():
		control.gui_input.connect(_collection_scroll_input.bind(control))
		control.focus_entered.connect(_ensure_collection_focus_visible.bind(control))
	_apply_collection_section()


func _build_playroom() -> void:
	_playroom_buttons.clear()
	_collection_duck_slot.queue_free()
	_room = PlayroomView.new()
	_room.name = "PipsRoom"
	_room.interaction_allowed = func() -> bool: return collection_page.visible and not _preview_page.visible and not _collection_dragged
	_collection_grid.add_child(_room)
	_room.configure(playroom_state, medal_progress.counts, Data.theme(model.theme_id), reduced_motion)
	_collection_duck_slot = _room.duck_slot
	_playroom_caption = _room.caption
	_playroom_medal = _room.favorite_medal
	_room.item_selected.connect(_select_room_item)
	_room.item_previewed.connect(_room_previewed)
	_room.word_requested.connect(_room_word)
	_room.toy_played.connect(_room_toy)
	for control in _room.controls():
		control.gui_input.connect(_collection_scroll_input.bind(control))
		control.focus_entered.connect(_ensure_collection_focus_visible.bind(control))
		if control is Button:
			_playroom_buttons.append(control)
	_refresh_favorite_reward()


func _room_previewed(message: String) -> void:
	if not collection_page.visible or _preview_page.visible or _collection_dragged:
		return
	audio.stop_voice()
	_end_collection_drag(false)
	_collection_scroll.scroll_vertical = 0
	_room.action_button.grab_focus()
	_ensure_collection_focus_visible.call_deferred(_room.action_button)
	_announce_status(message)


func _select_room_item(id: String) -> void:
	if not collection_page.visible or _preview_page.visible or _collection_dragged:
		return
	if not _ensure_playroom_loaded() or not playroom_state.select_item(id, medal_progress.counts):
		_playroom_caption.text = "Your room could not be saved. Tap the item to retry."
	else:
		audio.stop_voice()
		_room.configure(playroom_state, medal_progress.counts, Data.theme(model.theme_id), reduced_motion)
		_refresh_favorite_reward()
	_announce_status(_playroom_caption.text)


func _ensure_playroom_loaded() -> bool:
	if not _playroom_ready:
		_playroom_ready = playroom_state.load_state(_favorite_reward_id)
		if _playroom_ready:
			_favorite_reward_id = playroom_state.favorite_id
			if _preferred_theme.is_empty():
				_preferred_theme = playroom_state.preferred_theme_id
	return _playroom_ready


func _room_word(id: String) -> void:
	if not collection_page.visible or _preview_page.visible or _collection_dragged:
		return
	for word in data.words:
		if word.id == id:
			audio.interact(model.theme_id, model.phase != "lost")
			audio.say("res://" + word.audio)
			return


func _room_toy(kind: String) -> void:
	if not collection_page.visible or _preview_page.visible or _collection_dragged:
		return
	if kind == "offer":
		duck.react("happy")
	else:
		duck.perform_trick("bubbles" if kind in ["water", "open"] else "dance")
	_announce_status(_playroom_caption.text)


func _try_unlocked_gift() -> void:
	if _unlocked_gift.is_empty() or _save_error:
		return
	_collection_section = "room"
	_show_collection()
	_select_room_item(_unlocked_gift.id)
	_collection_scroll.scroll_vertical = 0
	_room.action_button.grab_focus()


func _play_duck_trick(kind: String) -> void:
	if not collection_page.visible or _preview_page.visible or _collection_dragged:
		return
	_playroom_caption.text = duck.perform_trick(kind)
	audio.interact(model.theme_id, model.phase != "lost")
	audio.cue("select")
	_announce_status(_playroom_caption.text)


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
		_playroom_caption.text = "Room choices could not load. Tap an owned item to retry."


func _refresh_favorite_reward() -> void:
	var reward: Dictionary = Data.reward(_favorite_reward_id)
	_playroom_medal.visible = not reward.is_empty() and collected_rewards.has(_favorite_reward_id)
	if _playroom_medal.visible:
		_playroom_medal.configure(load(reward.symbol), _piece_count(reward.id), Data.theme(reward.theme).accent)
		_playroom_medal.tooltip_text = reward.name + ": Pip's favorite medal"


func _wear_preview_reward() -> void:
	if not _preview_page.visible or not collected_rewards.has(_preview_reward_id):
		return
	if not _ensure_playroom_loaded() or not playroom_state.set_favorite(_preview_reward_id):
		_preview_caption.text = "Your display could not be saved. Try again."
		_announce_status(_preview_caption.text)
		return
	_favorite_reward_id = _preview_reward_id
	_refresh_favorite_reward()
	_preview_wear_button.text = "Displayed with Pip"
	_preview_caption.text = "Pip loves your " + str(Data.reward(_favorite_reward_id).name) + "!"
	duck.perform_trick("dance")
	_announce_status(_preview_caption.text)


func _add_reward_row(rewards: Array) -> void:
	var row := GridContainer.new()
	row.columns = 3
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_grid.add_child(row)
	_collection_rows.append(row)
	for reward in rewards:
		var slot := Button.new()
		slot.name = reward.id
		slot.custom_minimum_size = Vector2(80, 116)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.clip_contents = true
		slot.pressed.connect(_open_reward_preview.bind(reward.id))
		slot.gui_input.connect(_collection_scroll_input.bind(slot))
		slot.focus_entered.connect(_ensure_collection_focus_visible.bind(slot))
		for style_name in ["normal", "hover", "pressed", "disabled"]:
			slot.add_theme_stylebox_override(style_name, Style.box(Color.WHITE, Color("#d8dde1"), 16, 2))
		var picture := _medal_picture(slot)
		picture.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		picture.offset_left = 4
		picture.offset_top = 4
		picture.offset_right = -4
		picture.offset_bottom = 68
		var label := Style.label("", 14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		label.offset_left = 3
		label.offset_right = -3
		label.offset_top = -48
		label.offset_bottom = -4
		row.add_child(slot)
		_reward_slots[reward.id] = {"button": slot, "picture": picture, "label": label, "reward": reward}


func _sync_collected_rewards() -> void:
	collected_rewards = medal_progress.legacy_rewards.duplicate()
	for id in medal_progress.counts:
		if medal_progress.count_for(id) > 0:
			collected_rewards[id] = true


func _piece_count(id: String) -> int:
	return 3 if medal_progress.legacy_rewards.has(id) else medal_progress.count_for(id)


func _refresh_collection() -> void:
	_sync_collected_rewards()
	for id in _reward_slots:
		var slot: Dictionary = _reward_slots[id]
		var pieces: int = _piece_count(id)
		var unlocked: bool = _progress_ready and pieces > 0
		var palette: Dictionary = Data.theme(slot.reward.theme)
		slot.picture.configure(load(slot.reward.symbol) if unlocked else null, pieces, palette.accent)
		var button: Button = slot.button
		button.disabled = not unlocked
		button.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE
		button.tooltip_text = ("%s: %d of 3 pieces" % [slot.reward.name, pieces]) if unlocked else "Locked medal"
		_set_accessibility_name(button, button.tooltip_text)
		var fill := Color.WHITE if unlocked else Color("#edf0f1")
		var border: Color = palette.accent.lightened(0.55) if unlocked else Color("#d8dde1")
		button.add_theme_stylebox_override("normal", Style.box(fill, border, 16, 2))
		button.add_theme_stylebox_override("hover", Style.box(palette.light, palette.accent, 16, 3))
		button.add_theme_stylebox_override("pressed", Style.box(palette.light.lightened(0.3), palette.accent, 16, 3))
		button.add_theme_stylebox_override("disabled", Style.box(Color("#edf0f1"), Color("#d8dde1"), 16, 2))
		button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, palette.accent, 16, 4))
		slot.label.text = ("%s\n%s" % [slot.reward.name, "Complete" if pieces == 3 else "%d/3" % pieces]) if unlocked else "?"
	for theme_id in _collection_headings:
		var rewards: Array = Data.medals(theme_id)
		var count: int = medal_progress.completed_count(theme_id)
		_collection_headings[theme_id].text = "%s%s %d/%d" % [
			Data.theme(theme_id).name, " complete!" if count == rewards.size() else "", count, rewards.size()]
		if not _progress_ready:
			_collection_headings[theme_id].text = Data.theme(theme_id).name + " --/6"
	if _room != null:
		_room.configure(playroom_state, medal_progress.counts, Data.theme(model.theme_id), reduced_motion)
		_refresh_favorite_reward()
		if not _playroom_ready:
			_playroom_caption.text = "Room choices could not load. Tap an owned item to retry."


func _open_reward_preview(id: String) -> void:
	if _collection_dragged:
		_collection_dragged = false
		return
	if not collected_rewards.has(id):
		return
	var reward: Dictionary = Data.reward(id)
	if reward.is_empty():
		return
	if collection_page.visible and not _adventures_open and _collection_section != "medals":
		_show_reward_section("medals")
	_stop_voice()
	_end_collection_drag(false)
	_cancel_preview_flourish()
	_preview_reward_id = id
	_preview_tap_count = 0
	_focus_before_preview = get_viewport().gui_get_focus_owner()
	_preview_title.text = "%s #%d" % [reward.name, int(reward.number)]
	_preview_caption.text = "Tap to play. Five taps make a party!"
	_preview_image.configure(load(reward.symbol), _piece_count(id), Data.theme(reward.theme).accent)
	if _piece_count(id) < 3:
		_preview_caption.text = "%d of 3 pieces. Tap to play!" % _piece_count(id)
	_preview_image.scale = Vector2.ONE
	_preview_image.rotation = 0.0
	var palette: Dictionary = Data.theme(reward.theme)
	_preview_sparkle.accent = palette.accent
	_preview_sparkle.shape_kind = {
		"spring": RewardSparkle.Shape.HEART, "summer": RewardSparkle.Shape.STAR,
		"autumn": RewardSparkle.Shape.LEAF, "winter": RewardSparkle.Shape.SNOWFLAKE,
		"ocean": RewardSparkle.Shape.CIRCLE, "space": RewardSparkle.Shape.STAR
	}[reward.theme]
	_preview_sparkle.particle_count = 8
	_preview_sparkle.set_progress(0.0)
	_preview_sparkle.hide()
	_preview_page.add_theme_stylebox_override("panel", Style.box(palette.background, palette.accent.lightened(0.55), 0, 0))
	var preview_stage: Panel = _preview_image.get_parent()
	preview_stage.clip_contents = true
	preview_stage.add_theme_stylebox_override("panel", Style.box(Color.WHITE, palette.light, 28, 4))
	Style.button(_preview_close, palette.accent)
	Style.button(_preview_wear_button, palette.accent)
	_preview_wear_button.text = "Displayed with Pip" if _favorite_reward_id == id else "Display with Pip"
	_preview_play_button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, palette.accent, 28, 4))
	_preview_focus_modes.clear()
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		if button != duck and not _preview_page.is_ancestor_of(button):
			_preview_focus_modes[button] = button.focus_mode
			button.focus_mode = Control.FOCUS_NONE
	_preview_close.focus_mode = Control.FOCUS_ALL
	_preview_play_button.focus_mode = Control.FOCUS_ALL
	_preview_page.show()
	_preview_play_button.grab_focus()
	_update_duck()
	duck.react("happy")
	var progress_note: String = "Piece %d of 3. " % _piece_count(id) if _piece_count(id) < 3 else ""
	_announce_status("%s reward preview opened. %sPress the reward to play, or Back to close." % [_preview_title.text, progress_note])


func _hide_reward_preview() -> void:
	_cancel_preview_flourish()
	_preview_page.hide()
	_preview_reward_id = ""
	for control in _preview_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = _preview_focus_modes[control]
	_preview_focus_modes.clear()
	_refresh_collection()
	if is_instance_valid(_focus_before_preview) and _focus_before_preview.visible and not _focus_before_preview.disabled:
		_focus_before_preview.grab_focus()
	elif collection_page.visible:
		_focus_first_collection_reward()
	else:
		collection_button.grab_focus()
	if collection_page.visible:
		_announce_collection_state()


func _play_reward_preview() -> void:
	if not _preview_page.visible or _preview_reward_id.is_empty() or not collected_rewards.has(_preview_reward_id):
		return
	_cancel_preview_flourish()
	_preview_tap_count += 1
	duck.react("happy")
	var reaction: int = (_preview_tap_count - 1) % PREVIEW_REACTIONS.size()
	var party: bool = _preview_tap_count % 5 == 0
	var reward: Dictionary = Data.reward(_preview_reward_id)
	_preview_caption.text = ("High five! %s party!" % Data.theme(reward.theme).name) if party else ("%s Tap %d" % [PREVIEW_REACTIONS[reaction], _preview_tap_count])
	_preview_sparkle.particle_count = 12 if party else 8
	audio.interact(model.theme_id, model.phase != "lost")
	audio.cue("correct" if party else "select")
	_announce_status("%s. %s" % [_preview_title.text, _preview_caption.text])
	_preview_image.pivot_offset = _preview_image.size * 0.5
	if reduced_motion:
		return
	var squash := Vector2(1.14, 0.92)
	var stretch := Vector2(0.96, 1.10)
	var turn: float = 0.04
	if reaction == 1:
		squash = Vector2(1.07, 1.07)
		stretch = Vector2(1.02, 1.02)
		turn = 0.18
	elif reaction == 2:
		squash = Vector2(1.08, 1.03)
		stretch = Vector2(0.98, 1.04)
		turn = -0.06
	if party:
		squash = Vector2(1.18, 1.14)
		stretch = Vector2(1.05, 1.05)
		turn = 0.12
	_preview_sparkle.show()
	_preview_tween = create_tween()
	_preview_tween.tween_property(_preview_image, "scale", squash, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_preview_tween.parallel().tween_property(_preview_image, "rotation", turn, 0.14)
	_preview_tween.tween_property(_preview_image, "scale", stretch, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_preview_tween.parallel().tween_property(_preview_image, "rotation", -turn * 0.6, 0.18)
	_preview_tween.parallel().tween_method(_preview_sparkle.set_progress, 0.0, 1.0, 0.70 if party else 0.45)
	_preview_tween.tween_property(_preview_image, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_preview_tween.parallel().tween_property(_preview_image, "rotation", 0.0, 0.18)
	_preview_tween.tween_callback(_cancel_preview_flourish)


func _cancel_preview_flourish() -> void:
	if _preview_tween != null:
		_preview_tween.kill()
	_preview_tween = null
	if _preview_image != null:
		_preview_image.scale = Vector2.ONE
		_preview_image.rotation = 0.0
	if _preview_sparkle != null:
		_preview_sparkle.set_progress(0.0)
		_preview_sparkle.hide()


func _play_loss_bear() -> void:
	if model.phase != "lost" or collection_page.visible or _preview_page.visible:
		return
	_cancel_loss_play()
	audio.interact(model.theme_id, false)
	audio.cue("select")
	var direction: float = -1.0 if _loss_reaction_index % 2 == 0 else 1.0
	_caption.text = LOSS_REACTIONS[_loss_reaction_index]
	_loss_reaction_index = (_loss_reaction_index + 1) % LOSS_REACTIONS.size()
	_announce_status("Good try! " + _caption.text)
	if reduced_motion:
		return
	failure_image.pivot_offset = failure_image.size * 0.5
	_failure_sparkle.show()
	_failure_tween = create_tween()
	_failure_tween.tween_property(failure_image, "scale", Vector2(1.05, 1.03), 0.12).set_trans(Tween.TRANS_SINE)
	_failure_tween.parallel().tween_property(failure_image, "rotation", direction * 0.05, 0.12)
	_failure_tween.tween_property(failure_image, "rotation", -direction * 0.04, 0.12)
	_failure_tween.parallel().tween_method(_failure_sparkle.set_progress, 0.0, 1.0, 0.35)
	_failure_tween.tween_property(failure_image, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	_failure_tween.parallel().tween_property(failure_image, "rotation", 0.0, 0.18)
	_failure_tween.tween_callback(_cancel_loss_play)


func _cancel_loss_play() -> void:
	if _failure_tween != null:
		_failure_tween.kill()
	_failure_tween = null
	if failure_image != null:
		failure_image.scale = Vector2.ONE
		failure_image.rotation = 0.0
	if _failure_sparkle != null:
		_failure_sparkle.set_progress(0.0)
		_failure_sparkle.hide()


func _collection_scroll_input(event: InputEvent, source: Control) -> void:
	if not collection_page.visible or _preview_page.visible or _collection_scroll == null:
		return
	if event is InputEventKey and event.pressed:
		_cancel_collection_inertia()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_cancel_collection_inertia()
				var distance: int = roundi(48.0 * event.factor) * (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
				_collection_scroll.scroll_vertical = clampi(_collection_scroll.scroll_vertical + distance, 0, _collection_max_scroll().y)
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
		if event.pressed:
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
	var stopping_glide: bool = _collection_velocity.length_squared() >= 100.0
	_cancel_collection_inertia()
	_collection_dragging = true
	_collection_dragged = stopping_glide
	_collection_drag_pointer = pointer
	_collection_drag_start_position = position
	_collection_drag_start_scroll = Vector2(_collection_scroll.scroll_horizontal, _collection_scroll.scroll_vertical)
	_collection_last_scroll = _collection_drag_start_scroll
	_collection_last_sample_usec = Time.get_ticks_usec()


func _update_collection_drag(position: Vector2) -> void:
	if not _collection_dragging:
		return
	var displacement: Vector2 = position - _collection_drag_start_position
	if displacement.length() > 8.0:
		_collection_dragged = true
	var maximum: Vector2i = _collection_max_scroll()
	_collection_scroll.scroll_horizontal = clampi(int(round(_collection_drag_start_scroll.x - displacement.x)), 0, maximum.x)
	_collection_scroll.scroll_vertical = clampi(int(round(_collection_drag_start_scroll.y - displacement.y)), 0, maximum.y)
	var current_scroll := Vector2(_collection_scroll.scroll_horizontal, _collection_scroll.scroll_vertical)
	if current_scroll != _collection_last_scroll:
		var now_usec: int = Time.get_ticks_usec()
		var elapsed: float = maxf(float(now_usec - _collection_last_sample_usec) / 1000000.0, 1.0 / 240.0)
		var sample: Vector2 = ((current_scroll - _collection_last_scroll) / elapsed).limit_length(2600.0)
		_collection_velocity = _collection_velocity.lerp(sample, 0.75)
		_collection_last_scroll = current_scroll
		_collection_last_sample_usec = now_usec


func _end_collection_drag(allow_inertia: bool = true) -> void:
	if not allow_inertia:
		_cancel_collection_inertia()
	if not _collection_dragging:
		return
	_collection_dragging = false
	_collection_drag_pointer = -1
	if not allow_inertia or reduced_motion or not _collection_dragged or Time.get_ticks_usec() - _collection_last_sample_usec > 120000:
		_cancel_collection_inertia()
	_collection_inertia_position = Vector2(_collection_scroll.scroll_horizontal, _collection_scroll.scroll_vertical)
	_clear_finished_collection_swipe.call_deferred()


func _cancel_collection_inertia() -> void:
	_collection_velocity = Vector2.ZERO


func _advance_collection_inertia(delta: float) -> void:
	if _collection_dragging:
		return
	if not collection_page.visible or _preview_page.visible or reduced_motion or _collection_velocity.length_squared() < 100.0:
		_cancel_collection_inertia()
		return
	# Integrate exponential damping without making glide distance depend on frame rate.
	var decay: float = exp(-SCROLL_FRICTION * delta)
	var target: Vector2 = _collection_inertia_position + _collection_velocity * (1.0 - decay) / SCROLL_FRICTION
	var maximum: Vector2i = _collection_max_scroll()
	_collection_inertia_position = Vector2(clampf(target.x, 0, maximum.x), clampf(target.y, 0, maximum.y))
	_collection_velocity *= decay
	if not is_equal_approx(target.x, _collection_inertia_position.x):
		_collection_velocity.x = 0.0
	if not is_equal_approx(target.y, _collection_inertia_position.y):
		_collection_velocity.y = 0.0
	_collection_scroll.scroll_horizontal = int(round(_collection_inertia_position.x))
	_collection_scroll.scroll_vertical = int(round(_collection_inertia_position.y))


func _clear_finished_collection_swipe() -> void:
	if not _collection_dragging:
		_collection_dragged = false


func _collection_max_scroll() -> Vector2i:
	return Vector2i(
		maxi(0, int(ceili(_collection_grid.size.x - _collection_scroll.size.x))),
		maxi(0, int(ceili(_collection_grid.size.y - _collection_scroll.size.y)))
	)


func _picture(parent: Node) -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return picture


func _medal_picture(parent: Node) -> Medal:
	var picture := Medal.new()
	parent.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return picture


func _set_accessibility_name(control: Control, label: String) -> void:
	for property in control.get_property_list():
		if property.name == "accessibility_name":
			control.set("accessibility_name", label)
			return


func new_round(seed_value: int = -1, repeat_lesson: bool = false, adventure_id: String = "", next_mode: String = "") -> bool:
	if model.phase == "won" and model.chest_state == "closed":
		_open_chest()
	if model.chest_state == "opening":
		chest.finish_immediately()
	if (_save_error and not _pending_fragment.is_empty()) or (model.phase == "won" and model.chest_state != "opened"):
		_announce_status("Your piece is waiting to be saved. Choose Retry saving.")
		return false
	_stop_voice()
	_rebuilding = true
	if not next_mode.is_empty():
		_mode_id = next_mode
	_choice.stop()
	_memory.stop()
	duck.settle()
	_cancel_fragment_delivery()
	_pending_fragment.clear()
	_unlocked_gift.clear()
	_feedback_key = ""
	_save_error = not _progress_ready
	feedback_timer.stop()
	effects.clear()
	chest.clear()
	_cancel_chest_hold()
	_finish_chest_drag()
	_end_collection_drag(false)
	audio.halt()
	_cancel_loss_play()
	_loss_reaction_index = 0
	_cancel_reward_delivery(false)
	_hide_reward_preview_if_open()
	_reward_delivered_to_collection = false
	_stop_feedback_animations()
	_last_phase = ""
	for button in _found_words.get_children():
		_found_words.remove_child(button)
		button.queue_free()
	if not model.reset(data.words, seed_value, repeat_lesson, adventure_id):
		_rebuilding = false
		_show_error(model.error)
		return false
	if not repeat_lesson and seed_value < 0 and not _preferred_theme.is_empty():
		model.set_theme(_preferred_theme)
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
	_lesson.show_words(model.lesson_words, model.adventure_name)
	_lesson.set_audio_available(audio.available and not audio.muted)
	if _mode_id in ["sky", "listen"]:
		_choice.set_reduced_motion(reduced_motion)
		_choice.set_audio_available(audio.available and not audio.muted)
		_choice.start_round(model.lesson_words, _mode_id, Data.theme(model.theme_id), seed_value)
	elif _mode_id == "memory":
		_memory.set_reduced_motion(reduced_motion)
		_memory.set_audio_available(audio.available and not audio.muted)
		_memory.start_round(model.lesson_words, Data.theme(model.theme_id), seed_value)
	_rebuilding = false
	_refresh()
	_layout()
	if _mode_id == "learn":
		_pending_visit_id = model.adventure_id
		_save_journey()
	return true


func choose_mode(id: String) -> void:
	if not MODES.has(id) or collection_page.visible or _preview_page.visible or model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty()):
		return
	if id == _mode_id and model.phase in ["waiting", "matching", "feedback"]:
		_refresh()
		return
	if new_round(-1, true, "", id):
		_default_focus().grab_focus()


func _choice_answer(word: Dictionary, correct: bool) -> void:
	if not _mode_id in ["sky", "listen"] or collection_page.visible:
		return
	audio.interact(model.theme_id)
	audio.cue("correct" if correct else "wrong")
	var target: Dictionary = _choice.current_target
	audio.say("res://" + target.audio)
	if not correct and not model.missed_word_ids.has(target.id):
		model.missed_word_ids.append(target.id)
	duck.react("happy" if correct else "curious")
	_announce_status(_choice_feedback_status())
	_refresh_controller_focus()


func _choice_feedback_status() -> String:
	var word: String = str(_choice.current_target.get("text", ""))
	return "Yes! %s. Press Continue." % word if _choice._last_correct else "This picture is %s. Look, listen, then Continue." % word


func _choice_progress(successes: int, mistakes: int) -> void:
	if not _mode_id in ["sky", "listen"]:
		return
	model.successes = successes
	model.mistakes = mistakes
	if not _rebuilding:
		_success.set_filled_count(successes, 5)
		_mistakes.set_filled_count(mistakes)
		_match_caption.text = "%d of 5 found" % successes


func _choice_hear(word: Dictionary) -> void:
	if not _mode_id in ["sky", "listen"] or collection_page.visible or _preview_page.visible:
		return
	if _choice.status == "feedback":
		_lesson_hear(word)
		return
	_listen_word_failed = false
	audio.interact(model.theme_id)
	_choice.set_audio_available(audio.available and not audio.muted)
	duck.react("curious")
	if _choice.audio_available:
		_announce_status("Listen, then choose a picture. Press Hear to listen again.")
	else:
		_announce_status("No sound. Choose the picture. " + str(word.text) + ".")
	audio.say("res://" + word.audio)


func _choice_finished(won: bool, _found: Array) -> void:
	if not _mode_id in ["sky", "listen"]:
		return
	audio.stop_voice()
	model.phase = "won" if won else "lost"
	_refresh()
	_layout()


func _memory_revealed(word: Dictionary, _kind: String, _index: int) -> void:
	if _mode_id != "memory" or collection_page.visible or _preview_page.visible:
		return
	audio.interact(model.theme_id)
	audio.cue("select")
	var spoken: Dictionary = _memory.feedback_view.current_word if _memory.memory.phase == "feedback" else word
	audio.say("res://" + spoken.audio)
	duck.react("curious")
	_sync_memory_selection()


func _memory_answer(_words: Array, correct: bool) -> void:
	if _mode_id != "memory" or collection_page.visible or _preview_page.visible:
		return
	audio.cue("correct" if correct else "wrong")
	duck.react("happy" if correct else "curious")


func _memory_progress(successes: int, _attempts: int) -> void:
	if _mode_id != "memory":
		return
	model.successes = successes
	if not _rebuilding:
		_success.set_filled_count(successes, 5)
		_match_caption.text = "%d of 5 grown" % successes


func _memory_finished(won: bool, found: Array) -> void:
	if _mode_id != "memory" or model.phase == "won" or not won or _memory.memory.phase != "won" or found.size() != 5:
		return
	model.phase = "won"
	_refresh()
	_layout()


func _memory_status() -> String:
	return "Memory. %d of 5 pairs grown. %d attempts. %s" % [model.successes, _memory.memory.attempts, _memory.status_label.text]


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
	if _rebuilding or _mode_id != "memory" or collection_page.visible or _preview_page.visible or model.phase == "won":
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
	var palette: Dictionary = Data.theme(model.theme_id)
	_background.color = palette.background
	collection_page.add_theme_stylebox_override("panel", Style.box(palette.background, palette.accent.lightened(0.65), 0, 0))
	for index in range(theme_buttons.size()):
		var button: Button = theme_buttons[index]
		button.button_pressed = Model.THEMES[index] == model.theme_id
		button.disabled = model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty())
		Style.button(button, palette.accent)
	for index in range(_mode_buttons.size()):
		var button: Button = _mode_buttons[index]
		button.button_pressed = MODES.keys()[index] == _mode_id
		button.disabled = model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty())
		Style.button(button, palette.accent)
		button.add_theme_font_size_override("font_size", 16)
		if button.button_pressed:
			button.add_theme_stylebox_override("normal", Style.box(palette.light, palette.accent, 16, 3))
	_fit_mode_buttons()
	_choice.set_palette(palette)
	_memory.set_palette(palette)
	_lesson.set_palette(palette)
	_match_feedback.set_palette(palette)
	Style.button(collection_button, palette.accent)
	Style.button(_collection_back, palette.accent)
	for id in _collection_tabs:
		var button: Button = _collection_tabs[id]
		Style.button(button, palette.accent)
		button.add_theme_font_size_override("font_size", 18)
		button.button_pressed = id == _collection_section
	Style.button(hint_button, palette.accent)
	Style.button(_explore_button, palette.accent, 100)
	_explore_button.visible = _mode_id == "learn" and model.phase in ["waiting", "matching", "feedback"]
	_explore_button.disabled = model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty())
	Style.button(_voice_button, palette.accent)
	_voice_button.disabled = _host == null or not bool(_host.speechAvailable())
	_voice_button.focus_mode = Control.FOCUS_NONE if _voice_button.disabled else Control.FOCUS_ALL
	_voice_button.tooltip_text = "Voice on: click to stop" if _voice_mode else "Voice: click to listen. Browser speech may process audio remotely."
	if _voice_button.disabled:
		_voice_button.tooltip_text = "Voice input is unavailable in this browser. You can still tap cards."
	_set_accessibility_name(_voice_button, _voice_button.tooltip_text)
	_voice_button.button_pressed = _voice_mode
	_refresh_goal(palette)
	Style.button(replay_button, palette.accent)
	Style.button(_new_adventure_button, palette.accent)
	Style.button(_try_gift_button, palette.accent)
	for button in [replay_button, _new_adventure_button, _try_gift_button]:
		button.add_theme_font_size_override("font_size", 16)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	replay_button.text = "Retry saving" if _save_error else "Repeat lesson"
	replay_button.tooltip_text = medal_progress.error if _save_error else ""
	_new_adventure_button.visible = not _save_error
	_try_gift_button.visible = not _unlocked_gift.is_empty() and not _save_error
	_success.set_filled_count(model.successes, 3 if _mode_id == "match" else 5)
	_success.tooltip_text = "%d matches" % model.successes
	_mistakes.set_filled_count(model.mistakes)
	_mistakes.tooltip_text = "%d mistakes" % model.mistakes
	var playing: bool = model.phase in ["waiting", "matching", "feedback"]
	Style.button(_storage_retry_button, palette.accent)
	_storage_retry_button.add_theme_font_size_override("font_size", 16)
	_storage_retry_button.tooltip_text = medal_progress.error
	_storage_retry_button.visible = _save_error and playing
	_success.visible = not _storage_retry_button.visible
	_adventure_label.text = model.adventure_name
	_adventure_label.add_theme_color_override("font_color", palette.accent)
	_adventure_label.visible = playing and not _voice_mode and _mode_id == "match"
	_gift_label.visible = playing and not _voice_mode and size.y >= 520
	_mode_row.visible = playing and not _voice_mode
	_refresh_found_words(playing, palette.accent)
	if not playing and _voice_mode:
		_stop_voice()
	_voice_button.visible = playing and _mode_id == "match"
	hint_button.visible = playing and _mode_id == "match"
	hint_button.disabled = model.hint_used or not model.phase in ["waiting", "matching"]
	hint_button.focus_mode = Control.FOCUS_NONE if hint_button.disabled else Control.FOCUS_ALL
	hint_button.text = "Used" if model.hint_used else "Hint"
	hint_button.tooltip_text = "Hint used. Start a new round for another hint." if model.hint_used else "One hint per round (Xbox X)"
	_set_accessibility_name(hint_button, hint_button.tooltip_text)
	_match_caption.text = "Nice match!" if model.streak == 1 else "Find 3 pairs"
	if model.streak > 1:
		_match_caption.text = "%d in a row!" % model.streak
	if not model.hint_ids.is_empty():
		_match_caption.text = "Follow stars"
	var correcting: bool = playing and _mode_id == "match" and model.phase == "feedback"
	grid.visible = playing and _mode_id == "match" and not correcting
	_lesson.visible = playing and _mode_id == "learn"
	_match_feedback.visible = correcting
	if correcting:
		_show_match_feedback()
	else:
		_feedback_key = ""
	_choice.visible = playing and _mode_id in ["sky", "listen"]
	_memory.visible = playing and _mode_id == "memory"
	if _mode_id in ["sky", "listen"]:
		_match_caption.text = "%d of 5 found" % model.successes
	elif _mode_id == "memory":
		_match_caption.text = "%d of 5 grown" % model.successes
	elif _mode_id == "learn":
		_match_caption.text = "Look · listen · play"
	_mistakes.visible = not _mode_id in ["learn", "memory"]
	_message.visible = playing and _mode_id == "match" and not correcting and not _voice_mode
	_outcome.visible = not playing
	for id in cards:
		cards[id].refresh(palette, model.selected_id == id, model.matched_ids.has(id),
			model.phase == "feedback" and not model.last_correct and model.feedback_ids.has(id),
			model.phase != "waiting" and model.phase != "matching", model.hint_ids.has(id))
	if not model.hint_ids.is_empty():
		_message.text = "Hint: match the %s cards." % model.card_by_id(model.hint_ids[0]).word.text
	elif model.phase == "matching":
		_message.text = "Now find its match!"
	elif model.phase == "feedback":
		_message.text = "Great match!" if model.last_correct else "Not quite. Try another one!"
		if model.streak > 1:
			_message.text += " %d in a row!" % model.streak
	else:
		_message.text = "Find 3 word–picture pairs. Two cards have no match."
	if playing and _mode_id in ["sky", "listen"]:
		_message.text = "Sky words. Choose the word that matches the picture. Find five!" if _mode_id == "sky" else "Listen. Press Hear, then choose the matching picture. Find five!"
		if _mode_id == "listen" and not _choice.audio_available:
			_message.text = "Listen. No sound. Choose the picture for " + str(_choice.current_target.text) + "."
		if _choice.status == "feedback":
			_message.text = _choice_feedback_status()
	elif playing and _mode_id == "learn":
		_message.text = "Learn five words. Look at the picture, read the word, and press Hear."
	elif playing and _mode_id == "memory":
		_message.text = _memory_status()
	var won: bool = model.phase == "won"
	chest.visible = won
	chest_button.visible = won
	failure_image.visible = model.phase == "lost"
	failure_button.visible = model.phase == "lost"
	failure_button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, palette.accent, 26, 3))
	_failure_sparkle.accent = palette.accent
	_medallion.visible = won and not _reward_transfer_active and not _reward_delivered_to_collection
	reward_image.visible = _medallion.visible
	chest_button.disabled = (model.chest_state != "closed" and not _fragment_active) or _save_error
	chest_button.tooltip_text = "Place the piece" if _fragment_active else "Hold to open the treasure chest"
	_set_accessibility_name(chest_button, chest_button.tooltip_text)
	_stage.add_theme_stylebox_override("panel", Style.box(palette.accent.darkened(0.67), palette.accent.lightened(0.35), 26, 2))
	if won:
		var reward_id: String = model.reward_theme if not model.reward_theme.is_empty() else model.theme_id
		var reward_palette: Dictionary = Data.theme(reward_id)
		chest.reduced_motion = reduced_motion
		chest.configure_skin(reward_palette, data.chests)
		var reward: Dictionary = Data.reward(model.reward_id)
		if reward.is_empty():
			var next: Dictionary = medal_progress.next_fragment(reward_id) if _progress_ready else {}
			reward = Data.reward(next.medal_id) if not next.is_empty() else Data.medals(reward_id).back()
		var pieces: int = medal_progress.count_for(reward.id)
		var displayed_pieces: int = int(_pending_fragment.before) if _fragment_active else pieces
		_title.text = "You did it!"
		_caption.text = "Hold to find a piece!" if medal_progress.completed_count(reward_id) < 6 else "Hold for a celebration!"
		if model.chest_state == "opening":
			_caption.text = "Here comes your surprise!"
		elif model.chest_state == "opened":
			if _pending_fragment.is_empty():
				_title.text = "All six collected!"
				_caption.text = reward_palette.name + " collection"
			elif pieces < int(_pending_fragment.after):
				_title.text = "Saving your piece"
				_caption.text = "Please wait."
			elif pieces == 3 and not _fragment_active:
				_title.text = "Medal complete!"
				_caption.text = "%s\n%s %d of 6 medals" % [reward.name, reward_palette.name, medal_progress.completed_count(reward_id)]
			else:
				_title.text = "A new piece!"
				_caption.text = "%s\nPiece %d of 3" % [reward.name, pieces]
				if _fragment_active:
					_caption.text += "\nTap to place!"
		reward_image.configure(load(reward.symbol) if displayed_pieces > 0 else null, displayed_pieces, reward_palette.accent)
		_reward_number.text = "%d/3" % displayed_pieces
		_medallion.add_theme_stylebox_override("panel", Style.box(Color.WHITE, reward_palette.light, 64, 5))
		if _save_error:
			_title.text = "Keep your piece"
			_caption.text = "Saving failed.\nChoose Retry saving."
		elif not _unlocked_gift.is_empty() and not _fragment_active:
			_title.text = "A gift for Pip!"
			_caption.text = str(_unlocked_gift.name) + " unlocked!"
	elif model.phase == "lost":
		_title.text = "Good try!"
		_caption.text = "Tap the bear to play!"
		_stage.add_theme_stylebox_override("panel", Style.box(Color.WHITE, palette.accent.lightened(0.7), 26))
	if _last_phase != model.phase:
		_last_phase = model.phase
		if won:
			duck.react("happy")
			audio.cue(model.theme_id + "-arrive")
			if _controller_mode and not collection_page.visible and not _preview_page.visible:
				chest_button.focus_mode = Control.FOCUS_ALL
				_default_focus().grab_focus()
		elif model.phase == "lost":
			duck.react("curious")
			audio.stop_music()
			audio.cue("loss", "loss")
			if _controller_mode and not collection_page.visible and not _preview_page.visible:
				replay_button.focus_mode = Control.FOCUS_ALL
				replay_button.grab_focus()
	if _host != null:
		_host.background("#" + palette.background.to_html(false), "#" + palette.accent.to_html(false), "#" + palette.light.to_html(false))
	if _save_error:
		_message.text = "Rewards are unavailable. You can keep practising." if playing else "Reward progress: " + medal_progress.error
		_message.visible = playing and _mode_id == "match" and model.phase in ["waiting", "matching"] and not _voice_mode
	if not _preview_page.visible:
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
	var blocked_controls: Dictionary = _preview_focus_modes if _preview_page.visible else _collection_focus_modes
	for control in blocked_controls:
		if is_instance_valid(control):
			control.focus_mode = Control.FOCUS_NONE
	_layout_result()
	_update_duck()
	_refresh_controller_focus()


func _refresh_goal(palette: Dictionary) -> void:
	var medals: Array = Data.medals(model.theme_id)
	var goal: Dictionary = medals.back()
	for medal in medals:
		if medal_progress.count_for(medal.id) < 3:
			goal = medal
			break
	var pieces: int = medal_progress.count_for(goal.id)
	var complete: bool = medal_progress.completed_count(model.theme_id) == medals.size()
	collection_button.icon = null
	_goal_medal.configure(load(goal.symbol), pieces, palette.accent)
	_goal_label.text = "6/6" if complete else "%d/3" % pieces
	collection_button.tooltip_text = "%s complete! View my rewards." % palette.name if complete else "Next: %s. %d of 3 pieces. View my rewards." % [goal.name, pieces]
	_set_accessibility_name(collection_button, collection_button.tooltip_text)
	_goal_label.add_theme_color_override("font_color", palette.accent)
	var gift: Dictionary = playroom_state.next_gift(medal_progress.counts, model.theme_id) if playroom_state != null else {}
	_gift_label.text = "Next gift: %s · %d pieces to go" % [gift.name, gift.remaining_pieces] if not gift.is_empty() else palette.name + " room gifts collected!"
	_gift_label.add_theme_color_override("font_color", palette.accent)


func _refresh_found_words(playing: bool, accent: Color) -> void:
	var show_words: bool = not playing and not model.lesson_words.is_empty()
	_found_words.visible = show_words
	_found_words_heading.visible = show_words
	_found_words_scroll.visible = show_words
	if not show_words or collection_page.visible or _preview_page.visible:
		return
	_found_words_heading.text = "Review · missed words first" if not model.missed_word_ids.is_empty() else "Words practised · tap to hear"
	if _found_words.get_child_count() == 0:
		for word in model.review_words():
			var button := Button.new()
			button.name = "Found_" + word.id
			button.set_meta("word_id", word.id)
			button.size_flags_horizontal = Control.SIZE_FILL
			button.tooltip_text = "Hear %s again" % word.text
			_set_accessibility_name(button, button.tooltip_text)
			button.pressed.connect(_replay_found_word.bind(word.id))
			button.focus_entered.connect(func() -> void: _found_words_scroll.ensure_control_visible(button))
			_found_words.add_child(button)
			var picture := _picture(button)
			picture.texture = load("res://" + word.image)
			picture.offset_left = 8
			picture.offset_top = 6
			picture.offset_right = -8
			picture.offset_bottom = -26
			var label := Style.label(word.text, 16)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.clip_text = true
			button.add_child(label)
			label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			label.offset_top = -26
			label.offset_bottom = -4
	for button in _found_words.get_children():
		Style.button(button, accent)


func _replay_found_word(word_id: String) -> void:
	if collection_page.visible or _preview_page.visible or not model.phase in ["won", "lost"]:
		return
	for word in model.lesson_words:
		if word.id == word_id:
			_lesson_hear(word)
			return


func _association_changed(_word: Dictionary) -> void:
	audio.stop_voice()


func _lesson_hear(word: Dictionary) -> void:
	if collection_page.visible or _preview_page.visible or _voice_mode:
		return
	audio.interact(model.theme_id, model.phase != "lost")
	audio.say("res://" + word.audio)
	duck.react("curious")
	_announce_status(str(word.text) + ". Look at the picture and say the word.")


func _show_match_feedback() -> void:
	var key := ",".join(model.feedback_ids)
	if key == _feedback_key:
		return
	_feedback_key = key
	var associations: Array = []
	var word_card: Dictionary = {}
	var image_card: Dictionary = {}
	for id in model.feedback_ids:
		var card: Dictionary = model.card_by_id(id)
		if card.kind == "word":
			word_card = card
		else:
			image_card = card
	if word_card.is_empty() or image_card.is_empty():
		return
	associations.append(word_card.word)
	var heading: String = "Yes! The word and picture match."
	if not model.last_correct:
		associations.append(image_card.word)
		heading = "%s and %s are different." % [word_card.word.text, image_card.word.text]
		if model.card_by_id(word_card.word.id + ":image").is_empty():
			heading = "No picture partner: %s." % word_card.word.text
		elif model.card_by_id(image_card.word.id + ":word").is_empty():
			heading = "No word partner: %s." % image_card.word.text
	_match_feedback.show_words(associations, heading, "Continue")
	_match_feedback.set_audio_available(audio.available and not audio.muted and not _voice_mode)
	if not collection_page.visible:
		_match_feedback.action_button.grab_focus()


func _continue_match() -> void:
	if collection_page.visible or _preview_page.visible or _mode_id != "match":
		return
	audio.stop_voice()
	_resolve_feedback()
	_default_focus().grab_focus()


func _refresh_controller_focus() -> void:
	if not _controller_mode or collection_page.visible or _preview_page.visible:
		return
	if model.phase == "won" and model.chest_state == "closed" and not _save_error:
		chest_button.focus_mode = Control.FOCUS_ALL
		chest_button.grab_focus()
	elif model.phase == "lost" and not _valid_focus(get_viewport().gui_get_focus_owner()):
		replay_button.focus_mode = Control.FOCUS_ALL
		replay_button.grab_focus()
	elif not _valid_focus(get_viewport().gui_get_focus_owner()):
		_default_focus().grab_focus()


func _layout() -> void:
	if grid == null:
		return
	_fit_mode_buttons()
	_adventure_label.visible = model.phase in ["waiting", "matching", "feedback"] and not _voice_mode and _mode_id == "match"
	_mode_row.visible = model.phase in ["waiting", "matching", "feedback"] and not _voice_mode
	_gift_label.visible = model.phase in ["waiting", "matching", "feedback"] and not _voice_mode and size.y >= 520
	_message.visible = _mode_id == "match" and model.phase in ["waiting", "matching"] and not _voice_mode
	_stop_feedback_animations()
	_cancel_loss_play()
	_cancel_preview_flourish()
	_end_collection_drag(false)
	_fit_grid.call_deferred()
	_layout_collection()
	_layout_result()
	_sync_voice_bounds()
	_update_duck()


func _fit_grid() -> void:
	if grid == null or not grid.is_visible_in_tree():
		return
	# Use the allocated playfield after container layout, not a previous mode's cached minimum.
	grid.columns = 4 if size.x >= size.y or grid.size.y < 318.0 else 2


func _fit_mode_buttons() -> void:
	var width: float = (size.x - 24 - 8 * (_mode_buttons.size() - 1)) / maxf(1, _mode_buttons.size())
	for button in _mode_buttons:
		button.custom_minimum_size.x = 0
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var box: StyleBox = button.get_theme_stylebox(state)
			box.content_margin_left = 4
			box.content_margin_right = 4
		var font: Font = button.get_theme_font("font")
		var font_size: int = 16
		while font_size > 10 and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width - 8:
			font_size -= 1
		button.add_theme_font_size_override("font_size", font_size)


func _layout_collection() -> void:
	if _collection_rows.is_empty():
		return
	var usable_width: float = maxf(0.0, size.x - 32.0)
	var columns: int = 6 if usable_width >= 500.0 else 3
	for row in _collection_rows:
		row.columns = columns


func _layout_result() -> void:
	if _outcome == null or _stage == null or _result_text == null:
		return
	var dimensions: Vector2 = _outcome.size
	var compact: bool = dimensions.y < 340.0 and _found_words.visible
	_result_text.add_theme_constant_override("separation", 4 if compact else 10)
	_title.add_theme_font_size_override("font_size", 28 if compact else 34)
	_caption.add_theme_font_size_override("font_size", 18 if compact else 22)
	var minimum_text: Vector2 = _result_text.get_combined_minimum_size()
	if size.x >= size.y or dimensions.y < minimum_text.y + 82.0:
		var text_width: float = maxf(maxf(minimum_text.x, 232.0 if _found_words.visible else 0.0), (dimensions.x - 16.0) * 0.39)
		var stage_width: float = maxf(72.0, dimensions.x - 16.0 - text_width)
		_stage.position = Vector2.ZERO
		_stage.size = Vector2(stage_width, dimensions.y)
		_result_text.position = Vector2(stage_width + 16.0, 0)
		_result_text.size = Vector2(maxf(0.0, dimensions.x - stage_width - 16.0), dimensions.y)
	else:
		var text_height: float = maxf(170.0, minimum_text.y)
		_stage.position = Vector2.ZERO
		_stage.size = Vector2(dimensions.x, maxf(72.0, dimensions.y - text_height - 10.0))
		_result_text.position = Vector2(0, _stage.size.y + 10.0)
		_result_text.size = Vector2(dimensions.x, text_height)
	var diameter: float = clampf(minf(_stage.size.x, _stage.size.y) * 0.3, 64.0, 128.0)
	_medallion.size = Vector2.ONE * diameter
	_medallion.pivot_offset = _medallion.size * 0.5
	_medallion.position = Vector2(maxf(4, _stage.size.x - diameter - 12), maxf(4, _stage.size.y - diameter - 12))


func _request_hint() -> void:
	if _mode_id != "match" or collection_page.visible or _preview_page.visible or not model.request_hint():
		return
	duck.react("happy")
	if not _voice_mode:
		audio.interact(model.theme_id)
		audio.cue("select")
		audio.say("res://" + model.card_by_id(model.hint_ids[0]).word.audio)
	var next_id: String = model.hint_ids[1] if model.selected_id == model.hint_ids[0] else model.hint_ids[0]
	cards[next_id].grab_focus()


func _select_card(id: String) -> void:
	if _mode_id != "match" or collection_page.visible or _preview_page.visible:
		return
	if not _voice_mode:
		audio.interact(model.theme_id, model.phase != "lost")
	var result: String = model.select(id)
	if result in ["selected", "reselected"] and not _voice_mode:
		duck.react("curious")
		audio.cue("select")
		audio.say("res://" + model.card_by_id(id).word.audio)
	elif result in ["correct", "wrong"]:
		_animate_feedback(model.feedback_ids, result == "correct")
		if not _voice_mode:
			audio.cue(result, result)
		if _voice_mode:
			feedback_timer.start()


func _resolve_feedback() -> void:
	feedback_timer.stop()
	_stop_feedback_animations()
	model.resolve_feedback()
	_consume_spoken_word()


func choose_theme(id: String) -> void:
	if collection_page.visible or _preview_page.visible or (_save_error and not _pending_fragment.is_empty()) or not model.set_theme(id):
		return
	_preferred_theme = id
	_save_journey()
	duck.react("happy")
	effects.clear()
	if not _voice_mode:
		audio.interact(model.theme_id, model.phase != "lost")
		audio.cue("", model.theme_id + "-theme")


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_choice.set_reduced_motion(value)
	_memory.set_reduced_motion(value)
	_lesson.set_reduced_motion(value)
	_match_feedback.set_reduced_motion(value)
	for card in cards.values():
		card.set_reduced_motion(value)
	if duck != null:
		duck.set_reduced_motion(value)
	chest.reduced_motion = value
	if value:
		chest.stop_reaction()
		_cancel_collection_inertia()
		_stop_feedback_animations()
		effects.clear()
		_cancel_reward_delivery(true)
		_cancel_fragment_delivery()
		_cancel_preview_flourish()
		_cancel_loss_play()
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
			_refresh()
			return
	_pending_fragment = medal_progress.next_fragment(model.theme_id)
	if not medal_progress.error.is_empty():
		_save_error = true
		_refresh()
		return
	var id: String = _pending_fragment.medal_id if not _pending_fragment.is_empty() else Data.medals(model.theme_id).back().id
	if not model.begin_open(id):
		return
	_reward_delivered_to_collection = false
	audio.interact(model.reward_theme)
	audio.cue(model.reward_theme + "-open")
	effects.start(Data.theme(model.reward_theme), reduced_motion, not _pending_fragment.is_empty())
	chest.start_open(reduced_motion)


func _on_chest_opened() -> void:
	if not model.finish_open():
		return
	_commit_fragment()


func _commit_fragment() -> void:
	var before: Dictionary = medal_progress.counts.duplicate()
	if not _pending_fragment.is_empty() and not medal_progress.claim(_pending_fragment):
		_save_error = true
		_refresh()
		return
	_save_error = false
	for item in playroom_state.catalog():
		if not playroom_state.owned(item, before) and playroom_state.owned(item, medal_progress.counts):
			_unlocked_gift = item
			break
	_refresh_collection()
	_refresh()
	duck.react("happy")
	if _pending_fragment.is_empty() or reduced_motion or collection_page.visible:
		return
	_start_fragment_delivery()


func _start_fragment_delivery() -> void:
	_cancel_fragment_delivery()
	_fragment_active = true
	_fragment_image = Medal.new()
	_fragment_image.name = "MedalFragment"
	_fragment_image.z_index = collection_page.z_index - 5
	var reward: Dictionary = Data.reward(_pending_fragment.medal_id)
	_fragment_image.configure(load(reward.symbol), int(_pending_fragment.after), Data.theme(reward.theme).accent, int(_pending_fragment.after) - 1)
	add_child(_fragment_image)
	_refresh()
	_place_fragment(0.0)
	_fragment_tween = create_tween()
	_fragment_tween.tween_interval(0.35)
	_fragment_tween.tween_method(_place_fragment, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fragment_tween.tween_callback(_finish_fragment_delivery)
	if _controller_mode:
		chest_button.grab_focus()


func _place_fragment(progress: float) -> void:
	if not is_instance_valid(_fragment_image):
		return
	var stage_rect: Rect2 = _stage.get_global_rect()
	var start: Vector2 = stage_rect.get_center()
	var target: Vector2 = reward_image.get_global_rect().get_center()
	var edge: float = clampf(minf(stage_rect.size.x, stage_rect.size.y) * 0.45, 32.0, 144.0)
	var target_edge: float = minf(reward_image.size.x, reward_image.size.y)
	_fragment_image.size = Vector2.ONE * lerpf(edge, target_edge, progress)
	var center: Vector2 = start.lerp(target, progress) + Vector2(0, -sin(progress * PI) * minf(32.0, stage_rect.size.y * 0.1))
	_fragment_image.position = get_global_transform().affine_inverse() * center - _fragment_image.size * 0.5


func _finish_fragment_delivery(celebrate: bool = true) -> void:
	if not _fragment_active:
		return
	_fragment_active = false
	if _fragment_tween != null:
		_fragment_tween.kill()
	_fragment_tween = null
	if is_instance_valid(_fragment_image):
		_fragment_image.hide()
		_fragment_image.queue_free()
	_fragment_image = null
	_refresh()
	if celebrate and bool(_pending_fragment.completed) and not reduced_motion and not collection_page.visible:
		effects.start(Data.theme(model.reward_theme), false)
		_start_reward_delivery(model.reward_id)


func _cancel_fragment_delivery() -> void:
	_finish_fragment_delivery(false)


func _start_reward_delivery(reward_id: String) -> void:
	_cancel_reward_delivery(true)
	_medallion.scale = Vector2.ONE * 0.2
	collection_button.pivot_offset = collection_button.size * 0.5
	_reward_tween = create_tween()
	_reward_tween.tween_property(_medallion, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reward_tween.tween_interval(0.2)
	_reward_tween.tween_callback(_show_reward_flight.bind(reward_id))
	_reward_tween.tween_method(_place_reward_flight, 0.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reward_tween.tween_callback(func() -> void:
		_place_reward_flight(1.0)
		collection_button.scale = Vector2.ONE * 1.12
	)
	_reward_tween.tween_interval(0.08)
	_reward_tween.tween_property(collection_button, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reward_tween.tween_callback(_finish_reward_delivery)


func _show_reward_flight(reward_id: String) -> void:
	var reward: Dictionary = Data.reward(reward_id)
	if reward.is_empty():
		return
	if _reward_flight_image == null or not is_instance_valid(_reward_flight_image):
		_reward_flight_image = TextureRect.new()
		_reward_flight_image.name = "RewardFlight"
		_reward_flight_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reward_flight_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_reward_flight_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_reward_flight_image.z_index = collection_page.z_index - 5
		add_child(_reward_flight_image)
	_reward_transfer_active = true
	_reward_flight_image.texture = load(reward.symbol)
	_reward_flight_image.visible = true
	_medallion.visible = false
	reward_image.visible = false
	_place_reward_flight(0.0)


func _place_reward_flight(progress: float) -> void:
	if _reward_flight_image == null or not is_instance_valid(_reward_flight_image) or not _reward_flight_image.visible:
		return
	var start_rect: Rect2 = reward_image.get_global_rect()
	var start_center: Vector2 = start_rect.get_center()
	var target_center: Vector2 = collection_button.get_global_rect().get_center()
	var eased: float = smoothstep(0.0, 1.0, clampf(progress, 0.0, 1.0))
	var arc: float = clampf(start_center.distance_to(target_center) * 0.18, 26.0, 82.0)
	var center: Vector2 = start_center.lerp(target_center, eased) + Vector2(0.0, -sin(eased * PI) * arc)
	var end_edge: float = clampf(minf(collection_button.get_global_rect().size.x, collection_button.get_global_rect().size.y) * 0.48, 30.0, 46.0)
	var flight_size: Vector2 = start_rect.size.lerp(Vector2.ONE * end_edge, eased)
	_reward_flight_image.size = flight_size
	_reward_flight_image.position = get_global_transform().affine_inverse() * center - flight_size * 0.5


func _finish_reward_delivery() -> void:
	if _reward_flight_image != null and is_instance_valid(_reward_flight_image):
		_reward_flight_image.queue_free()
	_reward_flight_image = null
	_reward_transfer_active = false
	_reward_delivered_to_collection = true
	collection_button.scale = Vector2.ONE
	_reward_tween = null


func _cancel_reward_delivery(show_static_reveal: bool = true) -> void:
	var had_motion := _reward_tween != null or _reward_transfer_active or (_reward_flight_image != null and is_instance_valid(_reward_flight_image))
	if _reward_tween != null:
		_reward_tween.kill()
	_reward_tween = null
	if _reward_flight_image != null and is_instance_valid(_reward_flight_image):
		_reward_flight_image.queue_free()
	_reward_flight_image = null
	_reward_transfer_active = false
	collection_button.scale = Vector2.ONE
	collection_button.pivot_offset = collection_button.size * 0.5
	_medallion.scale = Vector2.ONE
	if show_static_reveal and model.phase == "won" and model.chest_state == "opened" and (had_motion or not _reward_delivered_to_collection):
		_reward_delivered_to_collection = false
		_medallion.visible = true
		reward_image.visible = true


func _replay() -> void:
	if _save_error:
		if not _progress_ready:
			_progress_ready = medal_progress.load_progress()
			_save_error = not _progress_ready
			if _progress_ready:
				_build_collection()
			_refresh()
		else:
			_commit_fragment()
		return
	if not new_round(-1, true):
		return
	duck.react("happy")
	audio.interact(model.theme_id)
	audio.cue("", "welcome")


func on_page_hidden() -> void:
	_stop_voice()
	_stop_controller_actions()
	_stop_feedback_animations()
	_cancel_loss_play()
	_cancel_chest_hold()
	_finish_chest_drag()
	_end_collection_drag(false)
	audio.halt()
	duck.settle()
	_choice.set_reduced_motion(true)
	_choice.set_reduced_motion(reduced_motion)
	_memory.set_reduced_motion(true)
	_memory.set_reduced_motion(reduced_motion)
	chest.finish_immediately()
	chest.stop_reaction()
	effects.clear()
	_cancel_fragment_delivery()
	_cancel_reward_delivery(true)
	_hide_reward_preview_if_open()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and audio != null:
		on_page_hidden()


func _input(event: InputEvent) -> void:
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
	if focused == chest_button and model.phase == "won" and model.chest_state == "closed":
		_controller_holding_chest = true
		_start_chest_hold()
		return
	if _valid_focus(focused) and focused is Button:
		(focused as Button).pressed.emit()
	else:
		_default_focus().grab_focus()


func _controller_back() -> void:
	if _preview_page.visible:
		_hide_reward_preview()
	elif collection_page.visible:
		_hide_collection()
	elif _voice_mode:
		_stop_voice()
	elif _mode_id == "memory":
		if _memory.memory.studying:
			_memory.study_button.pressed.emit()
		elif _memory.memory.phase == "matching" and not _memory.memory.selected_indices.is_empty():
			_memory.card_buttons[_memory.memory.selected_indices[0]].pressed.emit()
	elif model.phase == "matching" and not model.selected_id.is_empty():
		model.select(model.selected_id)


func _toggle_collection() -> void:
	if _preview_page.visible:
		_hide_reward_preview()
	if collection_page.visible:
		_hide_collection()
	else:
		_show_collection()


func _cycle_theme(step: int) -> void:
	if model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty()):
		return
	var index: int = Model.THEMES.find(model.theme_id)
	if index < 0:
		index = 0
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
	if collection_page.visible and not _collection_dragging:
		_cancel_collection_inertia()
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
	if collection_page.visible and not _preview_page.visible:
		# Navigate the collection's content, not its temporarily scrolled screen positions.
		center = _collection_grid.get_global_transform().affine_inverse() * center
		if control == _collection_back:
			center.y = -1.0
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
	return is_instance_valid(control) and control.visible and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE and not (control is Button and (control as Button).disabled)


func _default_focus() -> Control:
	if _preview_page.visible:
		return _preview_play_button
	if collection_page.visible:
		if _adventures_open:
			return _adventure_book.surprise_button
		var reward := _first_collection_reward()
		return reward if reward != null else _collection_back
	if model.phase == "won":
		return chest_button if (model.chest_state == "closed" or _fragment_active) and not _save_error else replay_button
	if model.phase == "lost":
		return replay_button
	if _mode_id == "learn":
		var lesson_controls: Array[Control] = _lesson.controls()
		return lesson_controls[0] if not lesson_controls.is_empty() else collection_button
	if _mode_id == "match" and model.phase == "feedback":
		return _match_feedback.action_button
	if _mode_id in ["sky", "listen"]:
		var choices: Array[Control] = _choice.controls()
		# Keep the feedback lock on the answer area; A must never select another mode.
		return choices[0] if not choices.is_empty() else _choice.answer_buttons[0]
	if _mode_id == "memory":
		if _memory.memory.phase == "feedback":
			return _memory.feedback_view.action_button
		if _memory.memory.studying:
			return _memory.study_button
		var memory_controls: Array[Control] = _memory.controls()
		return memory_controls[0] if not memory_controls.is_empty() else collection_button
	for id in cards:
		if _valid_focus(cards[id]):
			return cards[id]
	return collection_button


func _first_collection_reward() -> Button:
	for id in _reward_slots:
		var button: Button = _reward_slots[id].button
		if _valid_focus(button):
			return button
	return null


func _focus_first_collection_reward() -> void:
	var button := _first_collection_reward()
	if button != null:
		button.grab_focus()
	else:
		_collection_back.grab_focus()


func _ensure_collection_focus_visible(control: Control) -> void:
	if _collection_scroll != null and collection_page.visible and not _collection_dragging:
		_cancel_collection_inertia()
		_collection_scroll.ensure_control_visible(control)


func _audio_status(message: String) -> void:
	var can_hear: bool = audio.available and not audio.muted
	_choice.set_audio_available(can_hear and not _listen_word_failed)
	_memory.set_audio_available(can_hear)
	_lesson.set_audio_available(can_hear)
	_match_feedback.set_audio_available(can_hear and not _voice_mode)
	if _host != null:
		_host.audioStatus(message)


func _word_audio_failed() -> void:
	if _mode_id == "listen" and _choice.status == "asking":
		_listen_word_failed = true
		_choice.set_audio_available(false)
		_announce_status("No sound. Choose the picture. " + str(_choice.current_target.text) + ".")


func _announce_status(message: String) -> void:
	_status_announcement = message
	if _host != null:
		_host.announce(message)


func _show_error(message: String) -> void:
	grid.hide()
	for button in theme_buttons:
		button.disabled = true
	hint_button.disabled = true
	_voice_button.disabled = true
	_message.text = message
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
	_motion_callback = JavaScriptBridge.create_callback(func(arguments: Array) -> void: set_reduced_motion(bool(arguments[0])))
	_host.observe(_hidden_callback, _motion_callback)
	_speech_result_callback = JavaScriptBridge.create_callback(_on_voice_result)
	_speech_state_callback = JavaScriptBridge.create_callback(_on_voice_state)
	_host.observeSpeech(_speech_result_callback, _speech_state_callback)


func _toggle_voice() -> void:
	if _mode_id != "match" or collection_page.visible or _preview_page.visible:
		return
	if _voice_mode:
		_stop_voice()
	elif _host != null and bool(_host.speechAvailable()) and model.phase in ["waiting", "matching", "feedback"]:
		_voice_mode = true
		_voice_space.show()
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
	var enabled: bool = bool(arguments[0])
	if enabled and model.phase in ["won", "lost"]:
		_stop_voice()
		return
	var layout_changed: bool = _voice_mode != enabled
	_voice_mode = enabled
	_voice_listening = enabled and bool(arguments[1])
	_voice_button.button_pressed = enabled
	_voice_space.visible = enabled
	if layout_changed:
		_layout()
	if enabled:
		audio.halt()
	else:
		_speech_queue.clear()
		feedback_timer.stop()
		_match_feedback.set_audio_available(audio.available and not audio.muted)
	if model.phase in ["waiting", "matching", "feedback"] and not str(arguments[2]).is_empty():
		_announce_status(str(arguments[2]))
	elif layout_changed and not enabled and model.phase in ["waiting", "matching", "feedback"]:
		_announce_status("Voice off. " + _message.text)
	_sync_voice_bounds()


func _on_voice_result(arguments: Array) -> void:
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
		if model.match_spoken_word(_speech_queue.pop_front()) == "correct":
			_animate_feedback(model.feedback_ids, true)
			feedback_timer.start()
			return


func _stop_voice() -> void:
	var was_enabled: bool = _voice_mode
	_voice_mode = false
	_voice_listening = false
	_speech_queue.clear()
	if feedback_timer != null:
		feedback_timer.stop()
	if _match_feedback != null and audio != null:
		_match_feedback.set_audio_available(audio.available and not audio.muted)
	if _voice_space != null:
		_voice_space.hide()
	if _voice_button != null:
		_voice_button.button_pressed = false
	if was_enabled:
		_layout()
	if was_enabled and _host != null:
		_host.stopSpeech()
	if was_enabled and not _voice_mode and model.phase in ["waiting", "matching", "feedback"]:
		_announce_status("Voice off. " + _message.text)


func _animate_feedback(ids: Array[String], correct: bool) -> void:
	_stop_feedback_animations()
	duck.react("happy" if correct else "curious")
	if reduced_motion:
		return
	for id in ids:
		var card: Button = cards[id]
		_feedback_origins[id] = card.position
		card.pivot_offset = card.size * 0.5
		var tween := create_tween()
		_feedback_tweens.append(tween)
		if correct:
			var sparkle := RewardSparkle.new()
			sparkle.name = "MatchSparkle"
			sparkle.accent = Data.theme(model.theme_id).accent
			sparkle.shape_kind = RewardSparkle.Shape.STAR
			sparkle.particle_count = 2 + model.streak
			sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(sparkle)
			sparkle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_feedback_sparkles.append(sparkle)
			card.scale = Vector2.ONE * 0.82
			tween.tween_property(card, "scale", Vector2.ONE * 1.08, 0.14).set_trans(Tween.TRANS_BACK)
			tween.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)
			tween.parallel().tween_method(sparkle.set_progress, 0.0, 1.0, 0.45)
			tween.finished.connect(sparkle.queue_free)
		else:
			var start: Vector2 = card.position
			card.position = start + Vector2(-6, 0)
			card.rotation = -0.045
			tween.tween_property(card, "position", start + Vector2(7, 0), 0.08)
			tween.parallel().tween_property(card, "rotation", 0.045, 0.08)
			tween.tween_property(card, "position", start, 0.12)
			tween.parallel().tween_property(card, "rotation", 0.0, 0.12)


func _stop_feedback_animations() -> void:
	for tween in _feedback_tweens:
		tween.kill()
	_feedback_tweens.clear()
	for sparkle in _feedback_sparkles:
		if is_instance_valid(sparkle):
			sparkle.hide()
			sparkle.queue_free()
	_feedback_sparkles.clear()
	for id in _feedback_origins:
		if cards.has(id) and is_instance_valid(cards[id]):
			cards[id].position = _feedback_origins[id]
			cards[id].scale = Vector2.ONE
			cards[id].rotation = 0.0
	_feedback_origins.clear()


func _start_chest_hold() -> void:
	if model.phase != "won" or model.chest_state != "closed":
		return
	_holding_chest = true
	_hold_elapsed = 0.0
	_drag_distance = 0.0
	_dragging_chest = true
	_drag_has_anchor = false
	set_process(true)


func _end_chest_hold() -> void:
	if _holding_chest:
		var playful_tap: bool = _hold_elapsed < HOLD_SECONDS and _drag_distance <= 10.0
		_cancel_chest_hold()
		if playful_tap:
			chest.play_tap()
			audio.cue("select")
	_finish_chest_drag()


func _cancel_chest_hold() -> void:
	_holding_chest = false
	_hold_elapsed = 0.0
	if chest != null:
		chest.set_hold_progress(0.0)


func _finish_chest_drag() -> void:
	_dragging_chest = false
	_drag_has_anchor = false
	_drag_anchor_position = Vector2.ZERO
	_drag_anchor_offset = Vector2.ZERO


func _process(delta: float) -> void:
	_update_duck()
	_advance_collection_inertia(delta)
	if _holding_chest:
		_hold_elapsed += delta
		var progress: float = clampf(_hold_elapsed / HOLD_SECONDS, 0.0, 1.0)
		chest.set_hold_progress(progress)
		if progress >= 1.0:
			_holding_chest = false
			chest.set_hold_progress(0.0)
			_open_chest()
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
		_cancel_chest_hold()
	chest.set_drag_offset(_drag_anchor_offset + displacement)


func _drag_chest(delta: Vector2) -> void:
	chest.set_drag_offset(chest.drag_offset + delta)


func _show_adventures() -> void:
	if collection_page.visible or _preview_page.visible or model.chest_state == "opening" or (_save_error and not _pending_fragment.is_empty()):
		return
	_show_collection(true)


func _choose_adventure(id: String) -> void:
	if not collection_page.visible or not _adventures_open or _collection_dragged or (_save_error and not _pending_fragment.is_empty()) or model.chest_state == "opening":
		return
	if not id.is_empty() and not Data.ADVENTURES.any(func(entry: Dictionary) -> bool: return entry.id == id):
		return
	_hide_collection()
	if not new_round(-1, false, id, "learn"):
		return
	_default_focus().grab_focus()
	_announce_status(model.adventure_name + ". Learn five words. Look at the picture, read the word, and press Hear.")


func _save_journey() -> void:
	_journey_save_failed = not _ensure_playroom_loaded()
	if not _journey_save_failed and not _preferred_theme.is_empty():
		_journey_save_failed = not playroom_state.prefer_theme(_preferred_theme)
	if not _journey_save_failed and not _pending_visit_id.is_empty():
		_journey_save_failed = not playroom_state.remember_visit(_pending_visit_id)
		if not _journey_save_failed:
			_pending_visit_id = ""
	if _adventures_open:
		_refresh_adventure_book()


func _retry_journey() -> void:
	if not collection_page.visible or not _adventures_open or _collection_dragged:
		return
	_save_journey()
	_adventure_book.surprise_button.grab_focus()
	_announce_collection_state()


func _refresh_adventure_book() -> void:
	_adventure_book.setup(model.adventure_id, playroom_state.recent_topic_ids,
		playroom_state.suggested_adventure(), Data.theme(model.theme_id).accent, _journey_save_failed)


func _show_collection(as_adventures: bool = false) -> void:
	audio.stop_voice()
	_adventures_open = as_adventures
	_collection_title.text = "Pip's adventures" if as_adventures else "My rewards"
	_apply_collection_section()
	if as_adventures:
		_refresh_adventure_book()
	_collection_scroll.scroll_vertical = 0
	_stop_voice()
	_choice.pause(true)
	_lesson.pause(true)
	_match_feedback.pause(true)
	_cancel_fragment_delivery()
	_stop_feedback_animations()
	_cancel_loss_play()
	_cancel_chest_hold()
	_finish_chest_drag()
	_cancel_reward_delivery(true)
	_end_collection_drag(false)
	_collection_dragged = false
	_refresh_favorite_reward()
	_refresh_collection()
	_focus_before_collection = get_viewport().gui_get_focus_owner()
	_collection_focus_modes.clear()
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		if button != duck and not collection_page.is_ancestor_of(button) and not _preview_page.is_ancestor_of(button):
			_collection_focus_modes[button] = button.focus_mode
			button.focus_mode = Control.FOCUS_NONE
	collection_page.show()
	_memory.pause(true)
	_collection_back.grab_focus()
	_update_duck()
	duck.react("happy")
	_announce_collection_state()


func _apply_collection_section() -> void:
	_collection_title.visible = _adventures_open
	for id in _collection_tabs:
		_collection_tabs[id].visible = not _adventures_open
		_collection_tabs[id].set_pressed_no_signal(id == _collection_section)
	for child in _collection_grid.get_children():
		child.visible = child == _adventure_book if _adventures_open else (child != _adventure_book and (child == _room) == (_collection_section == "room"))


func _show_reward_section(section: String) -> void:
	if not collection_page.visible or _adventures_open or _preview_page.visible or not _collection_tabs.has(section):
		return
	_collection_section = section
	audio.stop_voice()
	_end_collection_drag(false)
	_collection_dragged = false
	_apply_collection_section()
	_collection_scroll.scroll_vertical = 0
	_update_duck()
	_announce_collection_state()


func _hide_collection() -> void:
	audio.stop_voice()
	_hide_reward_preview_if_open()
	_end_collection_drag(false)
	_collection_dragged = false
	collection_page.hide()
	_adventures_open = false
	duck.clear_trick()
	_choice.pause(false)
	_lesson.pause(false)
	_match_feedback.pause(false)
	for control in _collection_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = _collection_focus_modes[control]
	_collection_focus_modes.clear()
	_memory.pause(false)
	_refresh()
	if _valid_focus(_focus_before_collection):
		_focus_before_collection.grab_focus()
	else:
		_default_focus().grab_focus()
	_announce_status(_message.text if model.phase in ["waiting", "matching", "feedback"] else _title.text + " " + _caption.text)


func _hide_reward_preview_if_open() -> void:
	if _preview_page != null and _preview_page.visible:
		_hide_reward_preview()


func _announce_collection_state() -> void:
	if _adventures_open:
		_announce_status("Pip's adventures. %d of 12 places visited. Choose a picture to learn five words, or Surprise me. Back returns to your lesson.%s" % [
			playroom_state.recent_topic_ids.size(), " This visit could not be remembered. Choose Retry." if _journey_save_failed else ""])
		return
	var guidance := "Pip's room. Choose toys and places for Pip. Choose Medals to see your pieces."
	if _collection_section == "medals":
		guidance = "Medals. Win a game and open its chest to collect a piece. Three pieces complete a medal. Choose Pip's room to use your gifts."
	_announce_status("My rewards opened. %d of %d medals complete. %s. %s %d earlier rewards. Use Back to return." % [
		medal_progress.completed_count(), Model.THEMES.size() * 6, _collection_headings[model.theme_id].text, guidance, medal_progress.legacy_rewards.size()])


func _load_collected_rewards() -> void:
	_progress_ready = medal_progress.load_progress()
	_save_error = not _progress_ready
	_sync_collected_rewards()


func _update_duck() -> void:
	if duck == null or audio == null:
		return
	var in_preview: bool = _preview_page.visible
	var in_collection: bool = collection_page.visible
	if in_collection and _adventures_open:
		duck.hide()
		return
	if in_collection and not in_preview and _collection_section == "medals":
		duck.hide()
		return
	var visible_here: bool = in_preview or in_collection or not _voice_mode
	duck.set_reduced_motion(reduced_motion)
	duck.set_speaking(visible_here and audio.available and audio.active and not audio.muted and audio.voice.playing)
	var in_header: bool = not in_preview and not in_collection
	_success.set_mascot_inset(54.0 if visible_here and in_header else 0.0)
	if not visible_here:
		duck.hide()
		return
	var slot: Control = _preview_duck_slot if in_preview else _collection_duck_slot if in_collection else _success
	if not slot.is_visible_in_tree():
		duck.hide()
		return
	var parent: Control = _collection_duck_slot if in_collection and not in_preview else self
	if duck.get_parent() != parent:
		duck.reparent(parent)
	var rect: Rect2 = slot.get_global_rect()
	if rect.position == Vector2.ZERO or rect.size.y < 72:
		duck.hide()
		return
	duck.compact = in_header
	duck.position = parent.get_global_transform().affine_inverse() * rect.position
	duck.size = Vector2(maxf(72, rect.size.x), maxf(72, rect.size.y))
	duck.show()
	var accent: Color = _preview_sparkle.accent if in_preview else Data.THEMES[model.theme_id].accent
	if duck.accent != accent:
		duck.accent = accent
		duck.queue_redraw()


func _play_duck() -> void:
	if collection_page.visible and not _preview_page.visible and _collection_dragged:
		return
	var tricks := ["dance", "snack", "bubbles"]
	var caption: String = duck.perform_trick(tricks[_duck_trick_index % tricks.size()])
	_duck_trick_index += 1
	if collection_page.visible and not _preview_page.visible:
		_playroom_caption.text = caption
	if _voice_mode:
		return
	audio.interact(model.theme_id, model.phase != "lost")
	audio.cue("select")
	for word in data.words:
		if word.id == "duck":
			audio.say("res://" + word.audio)
			_announce_status("Pip says: duck! " + caption)
			return
	_announce_status("Pip waves hello!")
