extends Control

const Model = preload("res://scripts/game_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Card = preload("res://scripts/word_card.gd")
const Audio = preload("res://scripts/game_audio.gd")
const Chest = preload("res://scripts/chest_view.gd")
const Effects = preload("res://scripts/celebration.gd")
const HOLD_SECONDS: float = 1.2
const REWARD_SAVE: String = "user://rewards.cfg"

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

var model := Model.new()
var data := Data.new()
var cards: Dictionary = {}
var grid: GridContainer
var feedback_timer: Timer
var audio: Audio
var chest: Chest
var effects: Effects
var theme_buttons: Array[Button] = []
var collection_button: Button
var collection_page: Panel
var collected_rewards: Dictionary = {}
var replay_button: Button
var chest_button: Button
var reward_image: TextureRect
var failure_image: TextureRect
var reduced_motion: bool = false
var _background: ColorRect
var _success: ProgressBadges
var _mistakes: ProgressBadges
var _message: Label
var _outcome: Control
var _stage: Panel
var _result_text: VBoxContainer
var _title: Label
var _caption: Label
var _medallion: Panel
var _reward_number: Label
var _reward_flight_image: TextureRect
var _collection_grid: VBoxContainer
var _collection_back: Button
var _collection_rows: Array[GridContainer] = []
var _reward_slots: Dictionary = {}
var _collection_focus_modes: Dictionary = {}
var _focus_before_collection: Control
var _last_phase: String = ""
var _rebuilding: bool = false
var _reward_tween: Tween
var _reward_transfer_active: bool = false
var _reward_delivered_to_collection: bool = false
var _feedback_tweens: Array[Tween] = []
var _feedback_origins: Dictionary = {}
var _holding_chest: bool = false
var _hold_elapsed: float = 0.0
var _drag_distance: float = 0.0
var _dragging_chest: bool = false
var _drag_has_anchor: bool = false
var _drag_anchor_position: Vector2 = Vector2.ZERO
var _drag_anchor_offset: Vector2 = Vector2.ZERO
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
	reduced_motion = DisplayServer.accessibility_should_reduce_animation() == 1
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
	_mistakes = ProgressBadges.new(ProgressBadges.RETRY)
	_mistakes.name = "RetryProgress"
	_mistakes.tooltip_text = "0 mistakes"
	_mistakes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_mistakes)
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
	_result_text = VBoxContainer.new()
	_result_text.add_theme_constant_override("separation", 10)
	_outcome.add_child(_result_text)
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
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	column.add_child(scroll)
	_collection_grid = VBoxContainer.new()
	_collection_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_collection_grid)
	collection_page.hide()


func _build_collection() -> void:
	for child in _collection_grid.get_children():
		child.queue_free()
	_reward_slots.clear()
	_collection_rows.clear()
	for theme_id in Model.THEMES:
		_collection_grid.add_child(Style.label(Data.theme(theme_id).name, 26))
		var row := GridContainer.new()
		row.columns = 5
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_collection_grid.add_child(row)
		_collection_rows.append(row)
		for reward in Data.rewards(theme_id):
			var slot := VBoxContainer.new()
			slot.custom_minimum_size = Vector2(80, 104)
			var picture := TextureRect.new()
			picture.custom_minimum_size = Vector2(72, 72)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			slot.add_child(picture)
			var label := Style.label("", 14)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			slot.add_child(label)
			row.add_child(slot)
			_reward_slots[reward.id] = {"picture": picture, "label": label, "reward": reward}
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
		slot.label.text = ("%s\n#%d" % [slot.reward.name, slot.reward.number]) if unlocked else "?"


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
	audio.halt()
	_cancel_reward_delivery(false)
	_reward_delivered_to_collection = false
	_stop_feedback_animations()
	_last_phase = ""
	if not model.reset(data.words, seed_value):
		_rebuilding = false
		_show_error(model.error)
		return
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
	collection_button.icon = load(palette.symbol)
	Style.button(replay_button, palette.accent)
	_success.set_filled_count(model.successes)
	_success.tooltip_text = "%d matches" % model.successes
	_mistakes.set_filled_count(model.mistakes)
	_mistakes.tooltip_text = "%d mistakes" % model.mistakes
	var playing: bool = model.phase in ["waiting", "matching", "feedback"]
	grid.visible = playing
	_message.hide()
	_outcome.visible = not playing
	for id in cards:
		cards[id].refresh(palette, model.selected_id == id, model.matched_ids.has(id),
			model.phase == "feedback" and not model.last_correct and model.feedback_ids.has(id),
			model.phase != "waiting" and model.phase != "matching")
	if model.phase == "matching":
		_message.text = "Now find its match!"
	elif model.phase == "feedback":
		_message.text = "Great match!" if model.last_correct else "Not quite. Try another one!"
	else:
		_message.text = "Find three pairs. Two cards have no match!"
	var won: bool = model.phase == "won"
	chest.visible = won
	chest_button.visible = won
	failure_image.visible = model.phase == "lost"
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
		_caption.text = "Let's play again!"
		_stage.add_theme_stylebox_override("panel", Style.box(Color.WHITE, palette.accent.lightened(0.7), 26))
	if _last_phase != model.phase:
		_last_phase = model.phase
		if won:
			audio.cue(model.theme_id + "-arrive", model.theme_id + "-arrive")
		elif model.phase == "lost":
			audio.stop_music()
			audio.cue("loss", "loss")
	if _host != null:
		_host.background("#" + palette.background.to_html(false))
		_host.announce(_message.text if playing else _title.text + " " + _caption.text)
		var selection := ""
		if not model.selected_id.is_empty():
			var selected: Dictionary = model.card_by_id(model.selected_id)
			selection = ("Word: " if selected.kind == "word" else "Picture: ") + selected.word.text
		_host.selectionStatus(selection)
	_layout_result()


func _layout() -> void:
	if grid == null:
		return
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
	model.resolve_feedback()


func choose_theme(id: String) -> void:
	if not model.set_theme(id):
		return
	effects.clear()
	audio.interact(model.theme_id, model.phase != "lost")
	audio.cue("", model.theme_id + "-theme")


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	chest.reduced_motion = value
	if value:
		_stop_feedback_animations()
		effects.clear()
		_cancel_reward_delivery(true)
		chest.finish_immediately()
	if not data.words.is_empty():
		_refresh()


func _open_chest() -> void:
	var rewards: Array = Data.rewards(model.theme_id)
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
	_cancel_chest_hold()
	_finish_chest_drag()
	audio.halt()
	chest.finish_immediately()
	effects.clear()
	_cancel_reward_delivery(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and audio != null:
		on_page_hidden()


func _audio_status(message: String) -> void:
	if _host != null:
		_host.audioStatus(message)


func _show_error(message: String) -> void:
	grid.hide()
	for button in theme_buttons:
		button.disabled = true
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
	if reduced_motion:
		return
	for id in ids:
		var card: Button = cards[id]
		_feedback_origins[id] = card.position
		card.pivot_offset = card.size * 0.5
		var tween := create_tween()
		_feedback_tweens.append(tween)
		if correct:
			card.scale = Vector2.ONE * 0.82
			tween.tween_property(card, "scale", Vector2.ONE * 1.08, 0.14).set_trans(Tween.TRANS_BACK)
			tween.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)
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
	if not _holding_chest:
		return
	_hold_elapsed += delta
	var progress: float = clampf(_hold_elapsed / HOLD_SECONDS, 0.0, 1.0)
	chest.set_hold_progress(progress)
	if progress >= 1.0:
		_holding_chest = false
		chest.set_hold_progress(0.0)
		_open_chest()


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
	_cancel_chest_hold()
	_finish_chest_drag()
	_cancel_reward_delivery(true)
	_refresh_collection()
	_focus_before_collection = get_viewport().gui_get_focus_owner()
	_collection_focus_modes.clear()
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		if not collection_page.is_ancestor_of(button):
			_collection_focus_modes[button] = button.focus_mode
			button.focus_mode = Control.FOCUS_NONE
	collection_page.show()
	_collection_back.grab_focus()


func _hide_collection() -> void:
	collection_page.hide()
	for control in _collection_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = _collection_focus_modes[control]
	_collection_focus_modes.clear()
	if is_instance_valid(_focus_before_collection) and _focus_before_collection.visible:
		_focus_before_collection.grab_focus()
	else:
		collection_button.grab_focus()


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
