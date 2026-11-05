extends Control
## Optional asset preview; combat, map and story keep their existing character.

const Actor = preload("res://scripts/pirate_asset_actor.gd")
const STEP: float = 1.0 / 24.0
const GROUPS: Array[Dictionary] = [
	{"label": "Attack", "clips": ["Attack_L", "Attack_M", "Attack_P"],
		"titles": ["Light", "Medium", "Heavy"], "keys": ["1", "2", "3"]},
	{"label": "Hit reaction", "clips": ["Hit_L", "Hit_M", "Hit_P"],
		"titles": ["Light", "Medium", "Heavy"], "keys": ["4", "5", "6"]},
	{"label": "Ultimate", "clips": ["Ultimate_TidalRush", "Ultimate_CrescentSpin", "Ultimate_CaptainsDrop"],
		"titles": ["Tidal Rush", "Crescent Spin", "Captain's Drop"], "keys": ["7", "8", "9"]},
	{"label": "Special", "clips": ["Special_GiantRam", "Special_BigBite"],
		"titles": ["Giant Ram", "Big Bite"], "keys": ["G", "B"]}
]
const SHORTCUTS: Dictionary = {
	KEY_1: "Attack_L", KEY_2: "Attack_M", KEY_3: "Attack_P",
	KEY_4: "Hit_L", KEY_5: "Hit_M", KEY_6: "Hit_P",
	KEY_7: "Ultimate_TidalRush", KEY_8: "Ultimate_CrescentSpin",
	KEY_9: "Ultimate_CaptainsDrop", KEY_G: "Special_GiantRam", KEY_B: "Special_BigBite"
}
const CATEGORIES: Array[String] = ["Actions", "Ultimates", "Specials", "Taunts"]
const TAUNT_CONTROLS: Array[Dictionary] = [
	{"clip": "Taunt_HatTip", "title": "Hat Tip"},
	{"clip": "Taunt_BellyLaugh", "title": "Belly Laugh"},
	{"clip": "Taunt_SideEye", "title": "Side Eye"},
	{"clip": "Taunt_NopeWag", "title": "Nope Wag"},
	{"clip": "Taunt_Peekaboo", "title": "Peekaboo"},
	{"clip": "Taunt_MockBow", "title": "Mock Bow"},
	{"clip": "Taunt_Swagger", "title": "Swagger"},
	{"clip": "Taunt_TongueTease", "title": "Tongue Tease"},
	{"clip": "Taunt_VictoryLap", "title": "Victory Lap"},
	{"clip": "Taunt_FakeSleep", "title": "Fake Sleep"}
]
const INK: Color = Color("#eaf0d7")
const MUTED: Color = Color("#afc2b1")
const GOLD: Color = Color("#e9c786")

var _actor
var _viewport := SubViewport.new()
var _body := BoxContainer.new()
var _stage := PanelContainer.new()
var _controls := PanelContainer.new()
var _status := Label.new()
var _motion := CheckBox.new()
var _buttons: Array[Button] = []
var _titles: Dictionary = {"Idle": "Idle"}
var _category_panels: Dictionary = {}
var _category_buttons: Dictionary = {}
var _clip_categories: Dictionary = {}
var _selected_category: String = "Actions"
var _taunt_scroll := ScrollContainer.new()
var _help := Label.new()
var _accumulator: float = 0.0
var _focused: bool = true


func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	_build_interface()
	_build_studio()
	resized.connect(_layout)
	visibility_changed.connect(_refresh_activity)
	_layout()
	_sync_controls()
	_refresh_activity()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#1c382f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 15)
	scroll.add_child(column)
	column.add_child(_label("CAPTAIN CLOVER", 25, INK))
	column.add_child(_label("Pirate asset preview · 22 authored animations", 12, MUTED))
	_body.add_theme_constant_override("separation", 16)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.add_theme_stylebox_override("panel", _panel(Color("#2a493c")))
	_body.add_child(_stage)
	_controls.add_theme_stylebox_override("panel", _panel(Color("#243e34")))
	_body.add_child(_controls)
	var controls_column := VBoxContainer.new()
	controls_column.add_theme_constant_override("separation", 9)
	_controls.add_child(controls_column)
	_status.add_theme_color_override("font_color", GOLD)
	_status.add_theme_font_size_override("font_size", 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_column.add_child(_status)
	var category_row := HBoxContainer.new()
	category_row.add_theme_constant_override("separation", 6)
	controls_column.add_child(category_row)
	for category: String in CATEGORIES:
		var selector := Button.new()
		selector.text = category
		selector.custom_minimum_size.y = 44
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector.add_theme_font_size_override("font_size", 11)
		selector.add_theme_color_override("font_color", INK)
		selector.add_theme_color_override("font_pressed_color", GOLD)
		selector.toggle_mode = true
		selector.pressed.connect(_select_category.bind(category))
		category_row.add_child(selector)
		_category_buttons[category] = selector
		var panel: Control
		if category == "Taunts":
			_taunt_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			_taunt_scroll.follow_focus = true
			_taunt_scroll.custom_minimum_size.y = 190
			panel = _taunt_scroll
		else:
			var rows := VBoxContainer.new()
			rows.add_theme_constant_override("separation", 9)
			panel = rows
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.visible = category == "Actions"
		controls_column.add_child(panel)
		_category_panels[category] = panel
	for group: Dictionary in GROUPS:
		var category: String = "Ultimates" if group.label == "Ultimate" else "Specials" if group.label == "Special" else "Actions"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_category_panels[category].add_child(row)
		var label := _label(group.label, 11, MUTED)
		label.custom_minimum_size.x = 69
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		for index: int in range(group.clips.size()):
			var button := Button.new()
			button.text = str(group.titles[index]).replace(" ", "\n") if group.label == "Ultimate" else group.titles[index]
			button.tooltip_text = "%s (%s)" % [group.titles[index], group.keys[index]]
			button.custom_minimum_size = Vector2(0, 44)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", 10 if group.label == "Ultimate" else 11)
			button.add_theme_color_override("font_color", INK)
			button.add_theme_color_override("font_pressed_color", GOLD)
			button.toggle_mode = true
			button.set_meta("clip", group.clips[index])
			_clip_categories[group.clips[index]] = category
			var title: String = group.titles[index]
			if group.label == "Attack":
				title += " attack"
			elif group.label == "Hit reaction":
				title += " hit reaction"
			_titles[group.clips[index]] = title
			button.pressed.connect(_play.bind(group.clips[index]))
			row.add_child(button)
			_buttons.append(button)
	var taunt_grid := GridContainer.new()
	taunt_grid.columns = 2
	taunt_grid.add_theme_constant_override("h_separation", 8)
	taunt_grid.add_theme_constant_override("v_separation", 8)
	taunt_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_taunt_scroll.add_child(taunt_grid)
	for taunt: Dictionary in TAUNT_CONTROLS:
		var button := Button.new()
		button.text = taunt.title
		button.tooltip_text = "Play " + str(taunt.title)
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_pressed_color", GOLD)
		button.toggle_mode = true
		button.set_meta("clip", taunt.clip)
		_titles[taunt.clip] = taunt.title
		_clip_categories[taunt.clip] = "Taunts"
		button.pressed.connect(_play.bind(taunt.clip))
		taunt_grid.add_child(button)
		_buttons.append(button)
	var bottom := HBoxContainer.new()
	controls_column.add_child(bottom)
	var idle := Button.new()
	idle.text = "Idle"
	idle.tooltip_text = "Return to the neutral breathing loop (I)"
	idle.custom_minimum_size = Vector2(62, 44)
	idle.pressed.connect(_idle)
	bottom.add_child(idle)
	_motion.text = "Reduced motion"
	_motion.add_theme_font_size_override("font_size", 11)
	_motion.add_theme_color_override("font_color", MUTED)
	_motion.toggled.connect(_set_reduced_motion)
	bottom.add_child(_motion)
	_help.add_theme_font_size_override("font_size", 10)
	_help.add_theme_color_override("font_color", MUTED)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_column.add_child(_help)
	_select_category("Actions")


func _build_studio() -> void:
	_viewport.size = Vector2i(384, 576)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_stage.add_child(_viewport)
	var image := TextureRect.new()
	image.texture = _viewport.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(image)
	var world := Node3D.new()
	_viewport.add_child(world)
	var studio := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e0edff")
	environment.ambient_light_energy = 0.65
	studio.environment = environment
	world.add_child(studio)
	for spec: Array in [[Vector3(-35, -30, 0), Color("#fff0d1"), 1.0],
		[Vector3(-15, 125, 0), Color("#d9e8ff"), 0.6]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.5
	camera.near = 0.01
	camera.far = 100.0
	world.add_child(camera)
	camera.position = Vector3(0, 1.5, 8)
	camera.look_at(Vector3(0, 1.5, 0))
	camera.make_current()
	_actor = Actor.new()
	_actor.auto_advance = false
	world.add_child(_actor)
	_actor.animation_changed.connect(_animation_changed)
	_actor.action_finished.connect(_animation_changed)
	_actor.load_character()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _layout() -> void:
	var narrow: bool = size.x < 760
	_body.vertical = narrow
	_stage.custom_minimum_size = Vector2(220, 260)
	_controls.custom_minimum_size = Vector2(0 if narrow else 355, 0)
	_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_FILL
	_controls.size_flags_vertical = Control.SIZE_FILL if narrow else Control.SIZE_SHRINK_CENTER


func _process(delta: float) -> void:
	_accumulator += delta
	if _accumulator < STEP:
		return
	var elapsed: float = _accumulator
	_accumulator = 0.0
	if _actor.advance(elapsed):
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.alt_pressed or event.ctrl_pressed or event.meta_pressed:
		return
	if event.keycode == KEY_I:
		_idle()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_T:
		_select_category("Taunts")
		get_viewport().set_input_as_handled()
	elif SHORTCUTS.has(event.keycode):
		_play(SHORTCUTS[event.keycode])
		get_viewport().set_input_as_handled()


func _play(clip: String) -> void:
	_select_category(_clip_categories.get(clip, "Actions"))
	if _actor.play_animation(clip):
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_sync_controls()


func _select_category(category: String) -> void:
	if not _category_panels.has(category):
		return
	_selected_category = category
	for name: String in CATEGORIES:
		_category_panels[name].visible = name == category
		_category_buttons[name].set_pressed_no_signal(name == category)
	var hints: Dictionary = {
		"Actions": "1–6: attack / hit · T: taunts · I: idle",
		"Ultimates": "7–9: ultimates · T: taunts · I: idle",
		"Specials": "G/B: specials · T: taunts · I: idle",
		"Taunts": "Scroll for all ten taunts · I: idle"
	}
	_help.text = hints[category]


func _idle() -> void:
	_actor.resume_idle()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_sync_controls()


func _set_reduced_motion(value: bool) -> void:
	_actor.set_reduced_motion(value)
	_accumulator = 0.0
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_sync_controls()
	_refresh_activity()


func _animation_changed(_clip: String) -> void:
	_sync_controls()


func _sync_controls() -> void:
	if _actor == null:
		return
	var state: Dictionary = _actor.snapshot()
	var loaded: bool = state.get("loaded", false)
	_status.text = str(_titles.get(state.get("clip", "Idle"), "Idle")) if loaded else str(state.get("last_error", "Preparing the character"))
	if loaded and _motion.button_pressed:
		_status.text += " · Still pose"
	for button: Button in _buttons:
		button.disabled = not loaded
		button.set_pressed_no_signal(loaded and button.get_meta("clip") == state.get("clip", "Idle"))


func _refresh_activity() -> void:
	if _actor == null:
		return
	var active: bool = _focused and is_visible_in_tree()
	_actor.set_active(active)
	set_process(active and not _motion.button_pressed)
	if not active:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		_refresh_activity()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		_accumulator = 0.0
		_refresh_activity()


func _label(text: String, pixels: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	return label


func _panel(color: Color) -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = color
	panel.set_corner_radius_all(12)
	panel.set_content_margin_all(12)
	return panel
