extends Control

const Model = preload("res://scripts/game_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Card = preload("res://scripts/word_card.gd")
const Audio = preload("res://scripts/game_audio.gd")
const Chest = preload("res://scripts/chest_view.gd")
const Effects = preload("res://scripts/celebration.gd")

var model := Model.new()
var data := Data.new()
var cards: Dictionary = {}
var grid: GridContainer
var feedback_timer: Timer
var audio: Audio
var chest: Chest
var effects: Effects
var theme_menu: MenuButton
var mute_button: Button
var listen_button: Button
var replay_button: Button
var chest_button: Button
var reward_image: TextureRect
var failure_image: TextureRect
var reduced_motion: bool = false
var _background: ColorRect
var _success: Label
var _mistakes: Label
var _message: Label
var _audio_notice: Label
var _outcome: Control
var _stage: Panel
var _result_text: VBoxContainer
var _title: Label
var _caption: Label
var _medallion: Panel
var _last_phase: String = ""
var _rebuilding: bool = false
var _reward_tween: Tween
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
	var brand: Label = Style.label("Word Buddies", 24)
	brand.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	theme_menu = MenuButton.new()
	theme_menu.name = "Theme"
	theme_menu.flat = false
	theme_menu.tooltip_text = "Choose a season or reduce motion"
	header.add_child(theme_menu)
	var popup: PopupMenu = theme_menu.get_popup()
	for index in range(Model.THEMES.size()):
		popup.add_radio_check_item(Data.theme(Model.THEMES[index]).name, index)
	popup.add_separator()
	popup.add_check_item("Reduce motion", 100)
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_constant_override("v_separation", 50)
	popup.id_pressed.connect(_on_menu)
	mute_button = Button.new()
	mute_button.name = "Mute"
	mute_button.text = "Mute"
	mute_button.pressed.connect(_toggle_mute)
	header.add_child(mute_button)
	listen_button = Button.new()
	listen_button.name = "Listen"
	listen_button.text = "Listen"
	listen_button.pressed.connect(_listen)
	header.add_child(listen_button)
	var scores := HBoxContainer.new()
	scores.add_theme_constant_override("separation", 12)
	column.add_child(scores)
	_success = Style.label("Matches  0 / 3", 22)
	_success.custom_minimum_size.y = 36
	_success.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_success.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success.add_theme_color_override("font_color", Style.GOOD)
	scores.add_child(_success)
	_mistakes = Style.label("Oops  0 / 3", 22)
	_mistakes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mistakes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mistakes.add_theme_color_override("font_color", Style.WRONG)
	scores.add_child(_mistakes)
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
	chest_button.pressed.connect(_open_chest)
	_medallion = Panel.new()
	_medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_medallion)
	reward_image = _picture(_medallion)
	reward_image.offset_left = 8
	reward_image.offset_top = 8
	reward_image.offset_right = -8
	reward_image.offset_bottom = -8
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
	_caption = Style.label("Tap the chest!", 22)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_text.add_child(_caption)
	replay_button = Button.new()
	replay_button.text = "Play again"
	replay_button.pressed.connect(_replay)
	_result_text.add_child(replay_button)
	_message = Style.label("Find three pairs. Two cards have no match!", 20)
	_message.custom_minimum_size.y = 40
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	_audio_notice = Style.label("", 16)
	_audio_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_audio_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_audio_notice.hide()
	column.add_child(_audio_notice)
	audio = Audio.new()
	add_child(audio)
	audio.status_changed.connect(_audio_status)
	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.wait_time = 0.7
	feedback_timer.timeout.connect(_resolve_feedback)
	add_child(feedback_timer)
	_outcome.hide()


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
	audio.halt()
	if _reward_tween != null:
		_reward_tween.kill()
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
	theme_menu.text = palette.name
	theme_menu.disabled = model.chest_state == "opening"
	Style.button(theme_menu, palette.accent, 120)
	Style.button(mute_button, palette.accent, 90)
	Style.button(listen_button, palette.accent, 90)
	Style.button(replay_button, palette.accent)
	mute_button.text = "Unmute" if audio.muted else "Mute"
	var popup: PopupMenu = theme_menu.get_popup()
	for index in range(Model.THEMES.size()):
		popup.set_item_checked(index, Model.THEMES[index] == model.theme_id)
	popup.set_item_checked(popup.get_item_index(100), reduced_motion)
	_success.text = "Matches  %d / 3" % model.successes
	_mistakes.text = "Oops  %d / 3" % model.mistakes
	var playing: bool = model.phase in ["waiting", "matching", "feedback"]
	grid.visible = playing
	_message.visible = playing
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
		_caption.text = reward_palette.prize if model.chest_state == "opened" else "Tap the " + reward_palette.name.to_lower() + " chest!"
		if model.chest_state == "opening":
			_caption.text = "Here comes your surprise!"
		reward_image.texture = load(reward_palette.symbol)
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


func _on_menu(id: int) -> void:
	if id == 100:
		set_reduced_motion(not reduced_motion)
	elif id >= 0 and id < Model.THEMES.size():
		choose_theme(Model.THEMES[id])


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	chest.reduced_motion = value
	if value:
		effects.clear()
		if _reward_tween != null:
			_reward_tween.kill()
		_medallion.scale = Vector2.ONE
		chest.finish_immediately()
	if not data.words.is_empty():
		_refresh()


func _open_chest() -> void:
	if not model.begin_open():
		return
	audio.interact(model.reward_theme)
	audio.cue(model.reward_theme + "-open")
	effects.start(Data.theme(model.reward_theme), reduced_motion)
	chest.start_open(reduced_motion)


func _on_chest_opened() -> void:
	if not model.finish_open():
		return
	audio.cue("", model.reward_theme + "-open")
	if not reduced_motion:
		_medallion.scale = Vector2.ONE * 0.2
		_reward_tween = create_tween()
		_reward_tween.tween_property(_medallion, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _replay() -> void:
	new_round()
	audio.interact(model.theme_id)
	audio.cue("", "welcome")


func _toggle_mute() -> void:
	audio.set_muted(not audio.muted)
	if not audio.muted:
		audio.interact(model.theme_id, model.phase != "lost")
	_refresh()


func _listen() -> void:
	if audio.muted:
		audio.set_muted(false)
	audio.interact(model.theme_id, model.phase != "lost")
	var voice_id := "welcome"
	if not model.selected_id.is_empty():
		audio.say("res://" + model.card_by_id(model.selected_id).word.audio)
	elif model.phase == "lost":
		audio.cue("", "loss")
	elif model.phase == "won":
		voice_id = model.reward_theme + "-open" if model.chest_state == "opened" else model.theme_id + "-arrive"
		audio.cue("", voice_id)
	else:
		audio.cue("", voice_id)
	_refresh()


func on_page_hidden() -> void:
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
	_audio_notice.text = message
	_audio_notice.visible = not message.is_empty()
	if _host != null:
		_host.audioStatus(message)


func _show_error(message: String) -> void:
	grid.hide()
	theme_menu.disabled = true
	mute_button.disabled = true
	listen_button.disabled = true
	_message.text = message
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
