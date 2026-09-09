extends Control

const Model = preload("res://scripts/game_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Card = preload("res://scripts/word_card.gd")
const Audio = preload("res://scripts/game_audio.gd")
const Chest = preload("res://scripts/chest_view.gd")
const Effects = preload("res://scripts/celebration.gd")
const HOLD_SECONDS: float = 1.2
const SCROLL_FRICTION: float = 8.0
const REWARD_SAVE: String = "user://rewards.cfg"
const LOSS_REACTIONS := ["High five! Let's try again!", "A big bear hug for you!", "You kept trying. Well done!"]
const PREVIEW_REACTIONS := ["Boing!", "Wheee!", "Big hug!"]

class ProgressBadges:
	extends Control

	const SUCCESS := 0
	const RETRY := 1

	var filled_count: int = 0
	var total_count: int = 3
	var badge_kind: int = SUCCESS

	func _init(kind: int = SUCCESS) -> void:
		badge_kind = kind
		custom_minimum_size = Vector2(88, 38)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_filled_count(value: int, total: int = 3) -> void:
		total_count = maxi(1, total)
		filled_count = clampi(value, 0, total_count)
		queue_redraw()

	func _draw() -> void:
		if total_count <= 0:
			return
		var gap: float = 5.0
		var radius: float = clampf(minf(size.y * 0.31, (size.x - gap * float(total_count - 1)) / float(total_count) * 0.5), 7.0, 13.0)
		var total_width: float = radius * 2.0 * total_count + gap * float(total_count - 1)
		var x: float = maxf(radius, (size.x - total_width) * 0.5 + radius)
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
var cards: Dictionary = {}
var grid: GridContainer
var feedback_timer: Timer
var audio: Audio
var chest: Chest
var effects: Effects
var theme_buttons: Array[Button] = []
var practice_button: Button
var hint_button: Button
var collection_button: Button
var collection_page: Panel
var collected_rewards: Dictionary = {}
var replay_button: Button
var chest_button: Button
var reward_image: TextureRect
var failure_image: TextureRect
var failure_button: Button
var reduced_motion: bool = false
var _background: ColorRect
var _success: ProgressBadges
var _mistakes: ProgressBadges
var _practice_caption: Label
var _match_caption: Label
var _message: Label
var _outcome: Control
var _stage: Panel
var _result_text: VBoxContainer
var _title: Label
var _caption: Label
var _medallion: Panel
var _reward_number: Label
var _reward_flight_image: TextureRect
var _collection_scroll: ScrollContainer
var _collection_grid: VBoxContainer
var _collection_back: Button
var _collection_rows: Array[GridContainer] = []
var _collection_headings: Dictionary = {}
var _reward_slots: Dictionary = {}
var _collection_focus_modes: Dictionary = {}
var _focus_before_collection: Control
var _preview_page: Panel
var _preview_image: TextureRect
var _preview_title: Label
var _preview_caption: Label
var _preview_close: Button
var _preview_play_button: Button
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
var _hidden_callback: JavaScriptObject
var _motion_callback: JavaScriptObject


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
	new_round()
	if _host != null:
		_host.ready()


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
	practice_button = Button.new()
	practice_button.name = "Practice"
	practice_button.toggle_mode = true
	practice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	practice_button.pressed.connect(_toggle_practice)
	header.add_child(practice_button)
	_mistakes = ProgressBadges.new(ProgressBadges.RETRY)
	_mistakes.name = "RetryProgress"
	_mistakes.tooltip_text = "0 mistakes"
	practice_button.add_child(_mistakes)
	_mistakes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_practice_caption = Style.label("Challenge", 14)
	_practice_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	practice_button.add_child(_practice_caption)
	_practice_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_practice_caption.offset_top = -20
	hint_button = Button.new()
	hint_button.name = "Hint"
	hint_button.text = "Hint"
	hint_button.tooltip_text = "Show a matching pair (Xbox X)"
	_set_accessibility_name(hint_button, "Hint: show a matching pair")
	hint_button.pressed.connect(_request_hint)
	header.add_child(hint_button)
	collection_button = Button.new()
	collection_button.name = "Rewards"
	_set_accessibility_name(collection_button, "My rewards")
	collection_button.icon = load(Data.theme("spring").symbol)
	collection_button.expand_icon = true
	collection_button.tooltip_text = "View collected rewards"
	collection_button.pressed.connect(_show_collection)
	header.add_child(collection_button)
	var seasons := HBoxContainer.new()
	seasons.add_theme_constant_override("separation", 8)
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
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
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
	chest_button.gui_input.connect(_chest_input)
	_medallion = Panel.new()
	_medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_medallion)
	reward_image = _picture(_medallion)
	reward_image.offset_left = 8
	reward_image.offset_top = 8
	reward_image.offset_right = -8
	reward_image.offset_bottom = -8
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
	_caption = Style.label("Hold the chest to open it!", 22)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_text.add_child(_caption)
	replay_button = Button.new()
	replay_button.text = "Play again"
	replay_button.pressed.connect(_replay)
	_result_text.add_child(replay_button)
	_message = Style.label("", 20)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.hide()
	column.add_child(_message)
	_build_collection_shell()
	audio = Audio.new()
	add_child(audio)
	audio.status_changed.connect(_audio_status)
	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.wait_time = 0.7
	feedback_timer.timeout.connect(_resolve_feedback)
	add_child(feedback_timer)
	_build_reward_preview_shell()
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
	var title := Style.label("My rewards", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
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
	_preview_image = _picture(stage)
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
	_preview_caption = Style.label("Tap the reward to play!", 20)
	_preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_preview_caption)


func _build_collection() -> void:
	for child in _collection_grid.get_children():
		child.queue_free()
	_reward_slots.clear()
	_collection_rows.clear()
	_collection_headings.clear()
	for theme_id in Model.THEMES:
		var heading := Style.label("", 26)
		_collection_headings[theme_id] = heading
		_collection_grid.add_child(heading)
		var row := GridContainer.new()
		row.columns = 5
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_collection_grid.add_child(row)
		_collection_rows.append(row)
		for reward in Data.rewards(theme_id):
			var slot := Button.new()
			slot.name = reward.id
			slot.custom_minimum_size = Vector2(80, 116)
			slot.clip_contents = true
			slot.pressed.connect(_open_reward_preview.bind(reward.id))
			slot.gui_input.connect(_collection_scroll_input.bind(slot))
			slot.focus_entered.connect(_ensure_collection_focus_visible.bind(slot))
			for style_name in ["normal", "hover", "pressed", "disabled"]:
				slot.add_theme_stylebox_override(style_name, Style.box(Color.WHITE, Color("#d8dde1"), 16, 2))
			var picture := TextureRect.new()
			picture.custom_minimum_size = Vector2(64, 64)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(picture)
			picture.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			picture.offset_left = 4
			picture.offset_top = 4
			picture.offset_right = -4
			picture.offset_bottom = 68
			var label := Style.label("", 14)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(label)
			label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			label.offset_left = 3
			label.offset_right = -3
			label.offset_top = -48
			label.offset_bottom = -4
			row.add_child(slot)
			_reward_slots[reward.id] = {"button": slot, "picture": picture, "label": label, "reward": reward}
	_refresh_collection()
	_layout_collection()


func _refresh_collection() -> void:
	for id in _reward_slots:
		var slot: Dictionary = _reward_slots[id]
		var unlocked: bool = collected_rewards.has(id)
		if unlocked and slot.picture.texture == null:
			slot.picture.texture = load(slot.reward.symbol)
		elif not unlocked:
			slot.picture.texture = null
		var button: Button = slot.button
		button.disabled = not unlocked
		button.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE
		button.tooltip_text = slot.reward.name if unlocked else "Locked reward"
		var palette: Dictionary = Data.theme(slot.reward.theme)
		var fill := Color.WHITE if unlocked else Color("#edf0f1")
		var border: Color = palette.accent.lightened(0.55) if unlocked else Color("#d8dde1")
		button.add_theme_stylebox_override("normal", Style.box(fill, border, 16, 2))
		button.add_theme_stylebox_override("hover", Style.box(palette.light, palette.accent, 16, 3))
		button.add_theme_stylebox_override("pressed", Style.box(palette.light.lightened(0.3), palette.accent, 16, 3))
		button.add_theme_stylebox_override("disabled", Style.box(Color("#edf0f1"), Color("#d8dde1"), 16, 2))
		button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, palette.accent, 16, 4))
		slot.label.text = ("%s #%d" % [slot.reward.name, slot.reward.number]) if unlocked else "?"
	for theme_id in _collection_headings:
		var rewards: Array = Data.rewards(theme_id)
		var count: int = rewards.filter(func(reward: Dictionary) -> bool: return collected_rewards.has(reward.id)).size()
		_collection_headings[theme_id].text = "%s%s %d/%d" % [
			Data.theme(theme_id).name, " complete!" if count == rewards.size() else "", count, rewards.size()]


func _open_reward_preview(id: String) -> void:
	if _collection_dragged:
		_collection_dragged = false
		return
	if not collected_rewards.has(id):
		return
	var reward: Dictionary = Data.reward(id)
	if reward.is_empty():
		return
	_end_collection_drag(false)
	_cancel_preview_flourish()
	_preview_reward_id = id
	_preview_tap_count = 0
	_focus_before_preview = get_viewport().gui_get_focus_owner()
	_preview_title.text = "%s #%d" % [reward.name, int(reward.number)]
	_preview_caption.text = "Tap to play. Five taps make a party!"
	_preview_image.texture = load(reward.symbol)
	_preview_image.scale = Vector2.ONE
	_preview_image.rotation = 0.0
	var palette: Dictionary = Data.theme(reward.theme)
	_preview_sparkle.accent = palette.accent
	_preview_sparkle.shape_kind = {
		"spring": RewardSparkle.Shape.HEART, "summer": RewardSparkle.Shape.STAR,
		"autumn": RewardSparkle.Shape.LEAF, "winter": RewardSparkle.Shape.SNOWFLAKE
	}[reward.theme]
	_preview_sparkle.particle_count = 8
	_preview_sparkle.set_progress(0.0)
	_preview_sparkle.hide()
	_preview_page.add_theme_stylebox_override("panel", Style.box(palette.background, palette.accent.lightened(0.55), 0, 0))
	var preview_stage: Panel = _preview_image.get_parent()
	preview_stage.clip_contents = true
	preview_stage.add_theme_stylebox_override("panel", Style.box(Color.WHITE, palette.light, 28, 4))
	Style.button(_preview_close, palette.accent)
	_preview_play_button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, palette.accent, 28, 4))
	_preview_focus_modes.clear()
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		if not _preview_page.is_ancestor_of(button):
			_preview_focus_modes[button] = button.focus_mode
			button.focus_mode = Control.FOCUS_NONE
	_preview_close.focus_mode = Control.FOCUS_ALL
	_preview_play_button.focus_mode = Control.FOCUS_ALL
	_preview_page.show()
	_preview_play_button.grab_focus()
	_announce_status("%s reward preview opened. Press the reward to play, or Back to close." % _preview_title.text)


func _hide_reward_preview() -> void:
	_cancel_preview_flourish()
	_preview_page.hide()
	_preview_reward_id = ""
	for control in _preview_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = _preview_focus_modes[control]
	_preview_focus_modes.clear()
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
			_cancel_collection_inertia()
			_collection_scroll.scroll_vertical = clampi(_collection_scroll.scroll_vertical + (48 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -48), 0, _collection_max_scroll().y)
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


func _set_accessibility_name(control: Control, label: String) -> void:
	for property in control.get_property_list():
		if property.name == "accessibility_name":
			control.set("accessibility_name", label)
			return


func new_round(seed_value: int = -1) -> void:
	_rebuilding = true
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
	if not model.reset(data.words, seed_value):
		_rebuilding = false
		_show_error(model.error)
		return
	if seed_value < 0 and not _preferred_theme.is_empty():
		model.set_theme(_preferred_theme)
	for button in cards.values():
		grid.remove_child(button)
		button.queue_free()
	cards.clear()
	for card_data in model.cards:
		var button := Card.new()
		button.setup(card_data)
		button.pressed.connect(_select_card.bind(card_data.id))
		grid.add_child(button)
		cards[card_data.id] = button
	_rebuilding = false
	_refresh()
	_layout()


func _refresh() -> void:
	if _rebuilding:
		return
	var palette: Dictionary = Data.theme(model.theme_id)
	_background.color = palette.background
	collection_page.add_theme_stylebox_override("panel", Style.box(palette.background, palette.accent.lightened(0.65), 0, 0))
	for index in range(theme_buttons.size()):
		var button: Button = theme_buttons[index]
		button.button_pressed = Model.THEMES[index] == model.theme_id
		button.disabled = model.chest_state == "opening"
		Style.button(button, palette.accent)
	Style.button(collection_button, palette.accent)
	Style.button(hint_button, palette.accent)
	Style.button(practice_button, palette.accent, 88)
	practice_button.add_theme_font_size_override("font_size", 18)
	practice_button.button_pressed = model.practice_mode
	practice_button.disabled = model.phase in ["feedback", "won"]
	practice_button.text = "No limit" if model.practice_mode else ""
	practice_button.tooltip_text = "Switch to Challenge: three tries." if model.practice_mode else "Switch to Practice: keep your matches and try freely."
	_set_accessibility_name(practice_button, ("Practice. " if model.practice_mode else "Challenge. ") + practice_button.tooltip_text)
	_practice_caption.text = "Practice" if model.practice_mode else "Challenge"
	_mistakes.visible = not model.practice_mode
	collection_button.icon = load(palette.symbol)
	Style.button(replay_button, palette.accent)
	_success.set_filled_count(model.successes)
	_success.tooltip_text = "%d matches" % model.successes
	_mistakes.set_filled_count(model.mistakes)
	_mistakes.tooltip_text = "%d mistakes" % model.mistakes
	var playing: bool = model.phase in ["waiting", "matching", "feedback"]
	hint_button.visible = playing
	hint_button.disabled = not model.phase in ["waiting", "matching"]
	_match_caption.text = "Nice match!" if model.streak == 1 else "Find 3 pairs"
	if model.streak > 1:
		_match_caption.text = "%d in a row!" % model.streak
	if not model.hint_ids.is_empty():
		_match_caption.text = "Follow stars"
	grid.visible = playing
	_message.hide()
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
		_message.text = "Find three pairs. Practice mode: keep trying, with no limit!" if model.practice_mode else "Find three pairs. Two cards have no match!"
	var won: bool = model.phase == "won"
	chest.visible = won
	chest_button.visible = won
	failure_image.visible = model.phase == "lost"
	failure_button.visible = model.phase == "lost"
	failure_button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, palette.accent, 26, 3))
	_failure_sparkle.accent = palette.accent
	_medallion.visible = won and model.chest_state == "opened" and not _reward_transfer_active and not _reward_delivered_to_collection
	reward_image.visible = _medallion.visible
	chest_button.disabled = model.chest_state != "closed"
	_stage.add_theme_stylebox_override("panel", Style.box(palette.accent.darkened(0.67), palette.accent.lightened(0.35), 26, 2))
	if won:
		var reward_id: String = model.reward_theme if not model.reward_theme.is_empty() else model.theme_id
		var reward_palette: Dictionary = Data.theme(reward_id)
		chest.reduced_motion = reduced_motion
		chest.configure_skin(reward_palette, data.chests)
		_title.text = "Wow!" if model.chest_state == "opened" else "You did it!"
		var reward: Dictionary = Data.reward(model.reward_id)
		_caption.text = reward.get("name", reward_palette.prize) if model.chest_state == "opened" else "Hold the chest to open it!"
		if model.chest_state == "opening":
			_caption.text = "Here comes your surprise!"
		reward_image.texture = load(reward.get("symbol", reward_palette.symbol))
		_reward_number.text = "#%d" % int(reward.get("number", 0)) if model.chest_state == "opened" else ""
		_medallion.add_theme_stylebox_override("panel", Style.box(Color.WHITE, reward_palette.light, 64, 5))
	elif model.phase == "lost":
		_title.text = "Good try!"
		_caption.text = "Try Practice, or tap the bear!"
		_stage.add_theme_stylebox_override("panel", Style.box(Color.WHITE, palette.accent.lightened(0.7), 26))
	if _last_phase != model.phase:
		_last_phase = model.phase
		if won:
			audio.cue(model.theme_id + "-arrive", model.theme_id + "-arrive")
			if _controller_mode and not collection_page.visible and not _preview_page.visible:
				chest_button.focus_mode = Control.FOCUS_ALL
				chest_button.grab_focus()
		elif model.phase == "lost":
			audio.stop_music()
			audio.cue("loss", "loss")
			if _controller_mode and not collection_page.visible and not _preview_page.visible:
				replay_button.focus_mode = Control.FOCUS_ALL
				replay_button.grab_focus()
	if _host != null:
		_host.background("#" + palette.background.to_html(false))
	if not _preview_page.visible:
		if collection_page.visible:
			_announce_collection_state()
		else:
			_announce_status(_message.text if playing else _title.text + " " + _caption.text)
	if _host != null:
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
	_refresh_controller_focus()


func _refresh_controller_focus() -> void:
	if not _controller_mode or collection_page.visible or _preview_page.visible:
		return
	if model.phase == "won" and model.chest_state == "closed":
		chest_button.focus_mode = Control.FOCUS_ALL
		chest_button.grab_focus()
	elif model.phase == "lost" and not _valid_focus(get_viewport().gui_get_focus_owner()):
		replay_button.focus_mode = Control.FOCUS_ALL
		replay_button.grab_focus()
	elif model.phase != "feedback" and not _valid_focus(get_viewport().gui_get_focus_owner()):
		_default_focus().grab_focus()


func _layout() -> void:
	if grid == null:
		return
	_stop_feedback_animations()
	_cancel_loss_play()
	_cancel_preview_flourish()
	_end_collection_drag(false)
	grid.columns = 4 if size.x >= size.y else 2
	_layout_collection()
	_layout_result()


func _layout_collection() -> void:
	if _collection_rows.is_empty():
		return
	var usable_width: float = maxf(0.0, size.x - 32.0)
	var columns: int = clampi(floori((usable_width + 4.0) / 84.0), 2, 5)
	for row in _collection_rows:
		row.columns = columns


func _layout_result() -> void:
	if _outcome == null or _stage == null or _result_text == null:
		return
	var dimensions: Vector2 = _outcome.size
	if size.x >= size.y:
		var stage_width: float = maxf(72.0, (dimensions.x - 16.0) * 0.61)
		_stage.position = Vector2.ZERO
		_stage.size = Vector2(stage_width, dimensions.y)
		_result_text.position = Vector2(stage_width + 16.0, 0)
		_result_text.size = Vector2(maxf(0.0, dimensions.x - stage_width - 16.0), dimensions.y)
	else:
		_stage.position = Vector2.ZERO
		_stage.size = Vector2(dimensions.x, maxf(72.0, dimensions.y - 180.0))
		_result_text.position = Vector2(0, _stage.size.y + 10.0)
		_result_text.size = Vector2(dimensions.x, 170.0)
	var diameter: float = clampf(minf(_stage.size.x, _stage.size.y) * 0.3, 64.0, 128.0)
	_medallion.size = Vector2.ONE * diameter
	_medallion.pivot_offset = _medallion.size * 0.5
	_medallion.position = Vector2((_stage.size.x - diameter) * 0.5, _stage.size.y * 0.2 - diameter * 0.5)


func _toggle_practice() -> void:
	if collection_page.visible or _preview_page.visible or not model.set_practice(not model.practice_mode):
		return
	_cancel_loss_play()
	audio.interact(model.theme_id)
	audio.cue("select")
	_announce_status(("Practice mode: no limit. " if model.practice_mode else "Challenge mode: three tries. ") + _message.text)


func _request_hint() -> void:
	if collection_page.visible or _preview_page.visible or not model.request_hint():
		return
	audio.interact(model.theme_id)
	audio.cue("select")
	audio.say("res://" + model.card_by_id(model.hint_ids[0]).word.audio)
	var next_id: String = model.hint_ids[1] if model.selected_id == model.hint_ids[0] else model.hint_ids[0]
	cards[next_id].grab_focus()


func _select_card(id: String) -> void:
	audio.interact(model.theme_id, model.phase != "lost")
	var result: String = model.select(id)
	if result in ["selected", "reselected"]:
		audio.cue("select")
		audio.say("res://" + model.card_by_id(id).word.audio)
	elif result in ["correct", "wrong"]:
		_animate_feedback(model.feedback_ids, result == "correct")
		audio.cue(result, result)
		feedback_timer.start()


func _resolve_feedback() -> void:
	feedback_timer.stop()
	_stop_feedback_animations()
	model.resolve_feedback()


func choose_theme(id: String) -> void:
	if not model.set_theme(id):
		return
	_preferred_theme = id
	effects.clear()
	audio.interact(model.theme_id, model.phase != "lost")
	audio.cue("", model.theme_id + "-theme")


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	chest.reduced_motion = value
	if value:
		_cancel_collection_inertia()
		_stop_feedback_animations()
		effects.clear()
		_cancel_reward_delivery(true)
		_cancel_preview_flourish()
		_cancel_loss_play()
		chest.finish_immediately()
	if not data.words.is_empty():
		_refresh()


func _open_chest() -> void:
	var rewards: Array = Data.rewards(model.theme_id)
	var unearned: Array = rewards.filter(func(reward: Dictionary) -> bool: return not collected_rewards.has(reward.id))
	if not unearned.is_empty():
		rewards = unearned
	if rewards.is_empty() or not model.begin_open(rewards.pick_random().id):
		return
	_reward_delivered_to_collection = false
	audio.interact(model.reward_theme)
	audio.cue(model.reward_theme + "-open")
	effects.start(Data.theme(model.reward_theme), reduced_motion)
	chest.start_open(reduced_motion)


func _on_chest_opened() -> void:
	if not model.finish_open():
		return
	var reward_id := model.reward_id
	_record_reward(model.reward_id)
	audio.cue("", model.reward_theme + "-open")
	if not collected_rewards.has(reward_id) or reduced_motion or collection_page.visible:
		_cancel_reward_delivery(true)
		return
	_start_reward_delivery(reward_id)


func _start_reward_delivery(reward_id: String) -> void:
	_cancel_reward_delivery(true)
	_medallion.scale = Vector2.ONE * 0.2
	collection_button.pivot_offset = collection_button.size * 0.5
	_reward_tween = create_tween()
	_reward_tween.tween_property(_medallion, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reward_tween.tween_interval(0.15)
	_reward_tween.tween_callback(_show_reward_flight.bind(reward_id))
	_reward_tween.tween_method(_place_reward_flight, 0.0, 1.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
	new_round()
	audio.interact(model.theme_id)
	audio.cue("", "welcome")


func on_page_hidden() -> void:
	_stop_controller_actions()
	_stop_feedback_animations()
	_cancel_loss_play()
	_cancel_chest_hold()
	_finish_chest_drag()
	_end_collection_drag(false)
	audio.halt()
	chest.finish_immediately()
	effects.clear()
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
		_end_chest_hold()
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
	if model.chest_state == "opening":
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
		var reward := _first_collection_reward()
		return reward if reward != null else _collection_back
	if model.phase == "won":
		return chest_button if model.chest_state == "closed" else replay_button
	if model.phase == "lost":
		return replay_button
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
	if _host != null:
		_host.audioStatus(message)


func _announce_status(message: String) -> void:
	_status_announcement = message
	if _host != null:
		_host.announce(message)


func _show_error(message: String) -> void:
	grid.hide()
	for button in theme_buttons:
		button.disabled = true
	hint_button.disabled = true
	practice_button.disabled = true
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


func _animate_feedback(ids: Array[String], correct: bool) -> void:
	_stop_feedback_animations()
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
		_cancel_chest_hold()
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


func _show_collection() -> void:
	_stop_feedback_animations()
	_cancel_loss_play()
	_cancel_chest_hold()
	_finish_chest_drag()
	_cancel_reward_delivery(true)
	_end_collection_drag(false)
	_collection_dragged = false
	_refresh_collection()
	_focus_before_collection = get_viewport().gui_get_focus_owner()
	_collection_focus_modes.clear()
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		if not collection_page.is_ancestor_of(button) and not _preview_page.is_ancestor_of(button):
			_collection_focus_modes[button] = button.focus_mode
			button.focus_mode = Control.FOCUS_NONE
	collection_page.show()
	_collection_back.grab_focus()
	_announce_collection_state()


func _hide_collection() -> void:
	_hide_reward_preview_if_open()
	_end_collection_drag(false)
	_collection_dragged = false
	collection_page.hide()
	for control in _collection_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = _collection_focus_modes[control]
	_collection_focus_modes.clear()
	if is_instance_valid(_focus_before_collection) and _focus_before_collection.visible:
		_focus_before_collection.grab_focus()
	else:
		collection_button.grab_focus()
	_announce_status(_message.text if model.phase in ["waiting", "matching", "feedback"] else _title.text + " " + _caption.text)


func _hide_reward_preview_if_open() -> void:
	if _preview_page != null and _preview_page.visible:
		_hide_reward_preview()


func _announce_collection_state() -> void:
	_announce_status("My rewards opened. %d earned rewards. %s. Use Back to return." % [
		collected_rewards.size(), _collection_headings[model.theme_id].text])


func _load_collected_rewards() -> void:
	var config := ConfigFile.new()
	if config.load(REWARD_SAVE) != OK:
		return
	for id in config.get_value("rewards", "ids", PackedStringArray()):
		if not Data.reward(str(id)).is_empty():
			collected_rewards[str(id)] = true


func _record_reward(id: String) -> void:
	if id.is_empty() or collected_rewards.has(id):
		return
	var ids: Array = collected_rewards.keys()
	ids.append(id)
	var config := ConfigFile.new()
	config.set_value("rewards", "ids", PackedStringArray(ids))
	if config.save(REWARD_SAVE) != OK:
		_message.text = "Rewards could not be saved."
		_message.show()
		return
	collected_rewards[id] = true
	_refresh_collection()
