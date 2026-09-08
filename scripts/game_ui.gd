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
var _success: Label
var _mistakes: Label
var _message: Label
var _outcome: Control
var _stage: Panel
var _result_text: VBoxContainer
var _title: Label
var _caption: Label
var _medallion: Panel
var _reward_number: Label
var _motion_button: Button
var _collection_grid: VBoxContainer
var _collection_back: Button
var _reward_slots: Dictionary = {}
var _collection_focus_modes: Dictionary = {}
var _focus_before_collection: Control
var _last_phase: String = ""
var _rebuilding: bool = false
var _reward_tween: Tween
var _feedback_tweens: Array[Tween] = []
var _feedback_origins: Dictionary = {}
var _holding_chest: bool = false
var _hold_elapsed: float = 0.0
var _drag_distance: float = 0.0
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
	_success = Style.label("", 28)
	_success.tooltip_text = "0 matches"
	_success.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_success.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_success.add_theme_color_override("font_color", Style.GOOD)
	header.add_child(_success)
	_mistakes = Style.label("", 30)
	_mistakes.tooltip_text = "0 mistakes"
	_mistakes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mistakes.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_mistakes.add_theme_color_override("font_color", Style.WRONG)
	header.add_child(_mistakes)
	_motion_button = Button.new()
	_motion_button.name = "Motion"
	_motion_button.text = "FX"
	_motion_button.tooltip_text = "Reduce motion"
	_motion_button.toggle_mode = true
	_motion_button.pressed.connect(func() -> void: set_reduced_motion(_motion_button.button_pressed))
	header.add_child(_motion_button)
	collection_button = Button.new()
	collection_button.name = "Rewards"
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
		button.icon = load(palette.symbol)
		button.expand_icon = true
		button.tooltip_text = "Switch to " + palette.name
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
	column.add_child(scroll)
	_collection_grid = VBoxContainer.new()
	_collection_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_collection_grid)
	collection_page.hide()


func _build_collection() -> void:
	for child in _collection_grid.get_children():
		child.queue_free()
	_reward_slots.clear()
	for theme_id in Model.THEMES:
		_collection_grid.add_child(Style.label(Data.theme(theme_id).name, 26))
		var row := GridContainer.new()
		row.columns = 5
		_collection_grid.add_child(row)
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


func new_round(seed_value: int = -1) -> void:
	_rebuilding = true
	feedback_timer.stop()
	effects.clear()
	chest.clear()
	_cancel_chest_hold()
	audio.halt()
	if _reward_tween != null:
		_reward_tween.kill()
	_stop_feedback_animations()
	_medallion.scale = Vector2.ONE
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
	Style.button(_motion_button, palette.accent)
	_motion_button.button_pressed = reduced_motion
	Style.button(collection_button, palette.accent)
	collection_button.icon = load(palette.symbol)
	Style.button(replay_button, palette.accent)
	_success.text = "\u25cf".repeat(model.successes)
	_success.tooltip_text = "%d matches" % model.successes
	_mistakes.text = "\u00d7".repeat(model.mistakes)
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
	_medallion.visible = won and model.chest_state == "opened"
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
	_layout_result()


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
		if _reward_tween != null:
			_reward_tween.kill()
		_medallion.scale = Vector2.ONE
		chest.finish_immediately()
	if not data.words.is_empty():
		_refresh()


func _open_chest() -> void:
	var rewards: Array = Data.rewards(model.theme_id)
	if rewards.is_empty() or not model.begin_open(rewards.pick_random().id):
		return
	audio.interact(model.reward_theme)
	audio.cue(model.reward_theme + "-open")
	effects.start(Data.theme(model.reward_theme), reduced_motion)
	chest.start_open(reduced_motion)


func _on_chest_opened() -> void:
	if not model.finish_open():
		return
	_record_reward(model.reward_id)
	audio.cue("", model.reward_theme + "-open")
	if not reduced_motion:
		_medallion.scale = Vector2.ONE * 0.2
		_reward_tween = create_tween()
		_reward_tween.tween_property(_medallion, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _replay() -> void:
	new_round()
	audio.interact(model.theme_id)
	audio.cue("", "welcome")


func on_page_hidden() -> void:
	_cancel_chest_hold()
	audio.halt()
	chest.finish_immediately()
	effects.clear()
	if _reward_tween != null:
		_reward_tween.kill()
	_medallion.scale = Vector2.ONE


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
	set_process(true)


func _end_chest_hold() -> void:
	if _holding_chest:
		_cancel_chest_hold()


func _cancel_chest_hold() -> void:
	_holding_chest = false
	_hold_elapsed = 0.0
	if chest != null:
		chest.set_hold_progress(0.0)


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
	var relative := Vector2.ZERO
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		relative = event.relative
	elif event is InputEventScreenDrag:
		relative = event.relative
	if relative == Vector2.ZERO:
		return
	_drag_distance += relative.length()
	if _drag_distance > 10.0:
		_cancel_chest_hold()
	_drag_chest(relative)


func _drag_chest(delta: Vector2) -> void:
	chest.set_drag_offset(chest.drag_offset + delta)


func _show_collection() -> void:
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
