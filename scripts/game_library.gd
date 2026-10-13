extends PanelContainer
## Grow alongside Pip, then choose one of six places to practise.

signal mode_requested(id: String)
signal sound_toggled
signal collection_requested
signal theme_requested(id: String)

const Style = preload("res://scripts/ui_style.gd")
const Data = preload("res://scripts/game_data.gd")
const Model = preload("res://scripts/game_model.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const DuckMascot = preload("res://scripts/duck_mascot.gd")
const CoinCounter = preload("res://scripts/coin_counter.gd")
const ResultScroll = preload("res://scripts/result_scroll.gd")
const ModePreview = preload("res://scripts/game_mode_preview.gd")
const CATALOG := [
	{"id": "word_jelly", "title": "Jelly Words", "copy": "Join letter pieces.\nCollect your words.", "detail": "BUILD WORDS · COINS", "tint": Color("#eee5f4")},
	{"id": "match", "title": "Match", "copy": "Match a picture\nto its word.", "detail": "5 PAIRS", "tint": Color("#e6efe3")},
	{"id": "memory", "title": "Memory", "copy": "Remember, flip,\nfind the pair.", "detail": "NO TIMER", "tint": Color("#f2e9d8")},
	{"id": "pop", "title": "Voice Pop", "copy": "Say the word.\nPop flying cards.", "detail": "50 SECONDS · MIC", "tint": Color("#e3eef1")},
	{"id": "phrase", "title": "Phrase Builder", "copy": "Listen. Drag words\ninto a phrase.", "detail": "3 PHRASES", "tint": Color("#f5ebce")},
	{"id": "jelly", "title": "Jelly Match", "copy": "Drag matching pairs.\nMerge & collect.", "detail": "MERGE PAIRS · TREASURE", "tint": Color("#e1efea")}
]

var heading: Label
var grid: GridContainer
var buttons: Array[Button] = []
var theme_buttons: Array[Button] = []
var sound_button: Button
var collection_button: Button
var scroll: ResultScroll
var pip: DuckMascot
var coin_counter: CoinCounter
var _stage: Control
var _top: Control
var _brand: Label
var _body: VBoxContainer
var _hero: Control
var _intro: Label
var _pip_caption: Label
var _journey: Panel
var _journey_heading: Label
var _journey_count: Label
var _journey_bar: ProgressBar
var _next_pip: TextureRect
var _next_label: Label
var _growth: Dictionary = {}
var _next_age: int = -1
var _footer: HBoxContainer
var _credit: Label
var _theme_choices: VBoxContainer
var _theme_grid: GridContainer
var _theme_heading: Label
var _theme_save_notice: Label
var _theme_id := "spring"
var _tiles: Array[Dictionary] = []
var _current := ""
var _factor := 1.0
var _muted := false
var _available := Vector2(1280, 800)


func _init() -> void:
	name = "GameHome"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_top)
	_brand = Style.label("Grow with Pip", 22)
	_top.add_child(_brand)
	coin_counter = CoinCounter.new()
	coin_counter.name = "HomeCoins"
	_top.add_child(coin_counter)
	# Own pointer gestures before card focus can reveal a clipped button.
	scroll = ResultScroll.new()
	scroll.name = "HomeScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	scroll.scroll_deadzone = 8
	_stage.add_child(scroll)
	_body = VBoxContainer.new()
	_body.name = "HomeContent"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_hero = Control.new()
	_hero.name = "HomeWelcome"
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.resized.connect(_layout_hero)
	_body.add_child(_hero)
	pip = DuckMascot.new()
	pip.name = "HomePip"
	pip.pressed.connect(func() -> void: pip.perform_growth_action())
	_hero.add_child(pip)
	_pip_caption = Style.label("Your Pip", 12)
	_pip_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pip_caption.add_theme_color_override("font_color", Style.MUTED)
	_hero.add_child(_pip_caption)
	heading = Style.label("Let's grow\ntogether.", 42)
	_hero.add_child(heading)
	_intro = Style.label("Every new word helps Pip grow.", 15)
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro.add_theme_color_override("font_color", Style.MUTED)
	_hero.add_child(_intro)
	_build_growth_journey()
	grid = GridContainer.new()
	grid.name = "ModeOptions"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(grid)
	for entry: Dictionary in CATALOG:
		_add_game_card(entry)
	_build_theme_choices()
	_footer = HBoxContainer.new()
	_body.add_child(_footer)
	collection_button = Button.new()
	UiClick.bind_button(collection_button)
	collection_button.name = "HomeCollection"
	collection_button.set("accessibility_name", "Word library and treasure")
	collection_button.pressed.connect(func() -> void: collection_requested.emit())
	_footer.add_child(collection_button)
	sound_button = Button.new()
	sound_button.name = "LibrarySound"
	sound_button.pressed.connect(func() -> void: sound_toggled.emit())
	_footer.add_child(sound_button)
	for button: Button in [collection_button, sound_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_credit = Style.label("Pip: original art · Fluent Emoji: MIT · Twemoji: CC BY 4.0", 10)
	_credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credit.add_theme_color_override("font_color", Style.MUTED)
	_body.add_child(_credit)
	visibility_changed.connect(_sync_pip_visibility)


func _build_growth_journey() -> void:
	_journey = Panel.new()
	_journey.name = "HomeGrowthJourney"
	_journey.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.add_child(_journey)
	_journey_heading = Style.label("Pip's next chapter", 15)
	_journey.add_child(_journey_heading)
	_journey_count = Style.label("", 13)
	_journey_count.add_theme_color_override("font_color", Style.MUTED)
	_journey.add_child(_journey_count)
	_journey_bar = ProgressBar.new()
	_journey_bar.name = "HomeGrowthProgress"
	_journey_bar.show_percentage = false
	_journey_bar.step = 0.0
	_journey_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_journey.add_child(_journey_bar)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#ee887c"), Color("#efb354"), Color("#e7cd60"),
		Color("#7ebd8f"), Color("#69b9cf"), Color("#9b91cf")])
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 12
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	var fill := StyleBoxTexture.new()
	fill.texture = texture
	fill.set_content_margin_all(0)
	_journey_bar.add_theme_stylebox_override("fill", fill)
	_next_pip = TextureRect.new()
	_next_pip.name = "NextPip"
	_next_pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_next_pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_next_pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_journey.add_child(_next_pip)
	_next_label = Style.label("Next", 11)
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_label.add_theme_color_override("font_color", Style.MUTED)
	_journey.add_child(_next_label)
	configure_growth({})


func configure_growth(state: Dictionary) -> void:
	_growth = state
	set_growth_age(int(state.get("age", 0)))
	var ready: bool = state.get("ready", false)
	var completed: bool = state.get("completed", false)
	var next_age: int = int(state.get("learning_age", 3)) if ready and not completed else -1
	if next_age != _next_age:
		_next_age = next_age
		_next_pip.texture = _portrait(load("res://assets/images/mascots/growth/pip-lv%d.png" % next_age)) if next_age >= 3 else null
	_next_pip.visible = next_age >= 3
	_next_label.visible = _next_pip.visible
	_journey_bar.visible = ready
	_journey_bar.value = (1.0 if completed else float(state.get("progress", 0.0))) * 100.0 if ready else 0.0
	if not ready:
		_journey_heading.text = "Our learning journey"
		_journey_count.text = "Progress is unavailable."
	elif completed:
		_journey_heading.text = "Look how far we've grown!"
		_journey_count.text = "%d words learned together" % int(state.get("lifetime_mastered", 0))
	else:
		_journey_heading.text = "Pip's next chapter"
		_journey_count.text = "%d / %d words mastered" % [state.get("mastered", 0), state.get("total", 0)]
	_journey_bar.set("accessibility_name", _journey_count.text + (". Help Pip reach the next growth stage." if next_age >= 3 else "."))
	_next_pip.set("accessibility_name", "Pip's next growth stage, age %d" % next_age if next_age >= 3 else "")
	_layout_hero()


func _build_theme_choices() -> void:
	_theme_choices = VBoxContainer.new()
	_theme_choices.name = "HomeThemes"
	_body.add_child(_theme_choices)
	_theme_heading = Style.label("Theme · Spring", 13)
	_theme_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_theme_heading.add_theme_color_override("font_color", Style.MUTED)
	_theme_choices.add_child(_theme_heading)
	_theme_grid = GridContainer.new()
	_theme_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_theme_choices.add_child(_theme_grid)
	for id: String in Model.THEMES:
		var palette: Dictionary = Data.theme(id)
		var button := Button.new()
		button.name = palette.name
		button.icon = load(palette.symbol)
		button.set("accessibility_name", str(palette.name) + ", choose theme")
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.toggle_mode = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		UiClick.bind_button(button)
		button.pressed.connect(func() -> void: theme_requested.emit(id))
		_theme_grid.add_child(button)
		theme_buttons.append(button)
	_theme_save_notice = Style.label("Changes not saved. Tap a theme to retry.", 12)
	_theme_save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_theme_save_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_theme_save_notice.add_theme_color_override("font_color", Style.WRONG.darkened(0.15))
	_theme_save_notice.hide()
	_theme_choices.add_child(_theme_save_notice)


func configure_theme(id: String, disabled: bool, save_failed: bool) -> void:
	var changed: bool = _theme_id != id
	_theme_id = id
	_theme_heading.text = "Theme · " + str(Data.theme(id).name)
	_theme_save_notice.visible = save_failed
	for index in range(theme_buttons.size()):
		var button: Button = theme_buttons[index]
		var selected: bool = Model.THEMES[index] == id
		button.button_pressed = selected
		button.disabled = disabled
		button.set("accessibility_name", str(button.name) + (", selected theme" if selected else ", choose theme"))
	if changed:
		_style_surface()


func _style_surface() -> void:
	var surface := Style.box(Style.PAPER.lerp(Data.theme(_theme_id).background, 0.16), Color.TRANSPARENT, 0, 0)
	surface.set_content_margin_all(0)
	add_theme_stylebox_override("panel", surface)


func _style_theme_choices() -> void:
	var narrow: bool = _available.x * _factor < 600
	_theme_grid.columns = 4 if narrow else 8
	_theme_choices.add_theme_constant_override("separation", ceili(6.0 / _factor))
	_theme_grid.add_theme_constant_override("h_separation", ceili(8.0 / _factor))
	_theme_grid.add_theme_constant_override("v_separation", ceili(6.0 / _factor))
	_theme_heading.add_theme_font_size_override("font_size", ceili(13.0 / _factor))
	_theme_save_notice.add_theme_font_size_override("font_size", ceili(12.0 / _factor))
	for index in range(theme_buttons.size()):
		var button: Button = theme_buttons[index]
		var palette: Dictionary = Data.theme(Model.THEMES[index])
		button.custom_minimum_size = Vector2(56, 44) / _factor
		button.add_theme_constant_override("icon_max_width", ceili(28.0 / _factor))
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var selected: bool = state in ["pressed", "hover_pressed"]
			var surface := Style.box(palette.background if selected else Style.PAPER.lightened(0.5),
				palette.accent if selected else Style.EDGE, ceili(12.0 / _factor), ceili((2.0 if selected else 1.0) / _factor))
			if state in ["hover", "hover_pressed"]:
				surface.bg_color = palette.background
			surface.set_content_margin_all(4.0 / _factor)
			button.add_theme_stylebox_override(state, surface)
		var focus := Style.box(Color.TRANSPARENT, Style.INK, ceili(12.0 / _factor), ceili(2.0 / _factor))
		focus.set_expand_margin_all(-3.0 / _factor)
		button.add_theme_stylebox_override("focus", focus)


func _ready() -> void:
	pip.name = "HomePip"
	pip.set("accessibility_name", "Pip. Play a friendly gesture")
	_sync_pip_visibility()
	fit(_available, _factor)


func _add_game_card(entry: Dictionary) -> void:
	var tile := Button.new()
	UiClick.bind_button(tile)
	tile.name = "Mode_" + str(entry.id)
	tile.toggle_mode = true
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.pressed.connect(func() -> void: mode_requested.emit(str(entry.id)))
	grid.add_child(tile)
	buttons.append(tile)
	var preview := ModePreview.new()
	preview.configure(str(entry.id))
	tile.add_child(preview)
	var title := Style.label(entry.title, 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	tile.add_child(title)
	var copy := Style.label(entry.copy, 14)
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_theme_color_override("font_color", Style.MUTED)
	tile.add_child(copy)
	var current := Style.label("CONTINUE", 10)
	current.add_theme_color_override("font_color", Style.GOOD)
	tile.add_child(current)
	var info := {"button": tile, "preview": preview, "title": title, "copy": copy, "current": current, "entry": entry}
	_tiles.append(info)
	tile.resized.connect(_layout_tile.bind(info))
	for interaction: Signal in [tile.mouse_entered, tile.mouse_exited, tile.focus_entered, tile.focus_exited]:
		interaction.connect(_preview_focus_changed.bind(info))


func _preview_focus_changed(tile: Dictionary) -> void:
	tile.preview.set_highlighted(tile.button.is_hovered() or tile.button.has_focus())


func _portrait(texture: Texture2D) -> AtlasTexture:
	var portrait := AtlasTexture.new()
	portrait.atlas = texture
	var side: float = texture.get_height()
	portrait.region = Rect2(0, 0, side, side)
	return portrait


func configure(current: String, muted: bool, reduced: bool) -> void:
	_current = current
	_muted = muted
	pip.set_reduced_motion(reduced)
	coin_counter.reduced_motion = reduced
	_style_footer()
	for tile: Dictionary in _tiles:
		tile.preview.set_reduced_motion(reduced)
		var selected: bool = tile.entry.id == current and not current.is_empty()
		tile.button.button_pressed = selected
		tile.current.visible = selected
		tile.button.set("accessibility_name", str(tile.entry.title) + (", continue game. " if selected else ". ") + str(tile.entry.copy).replace("\n", " ") + " " + str(tile.entry.detail))


func set_growth_age(age: int) -> void:
	pip.set_growth_age(age)


func set_home_coins(amount: int) -> void:
	coin_counter.sync(amount)


func finish_previews() -> void:
	for tile: Dictionary in _tiles:
		tile.preview.finish_demo()


func resume_previews() -> void:
	for tile: Dictionary in _tiles:
		tile.preview.resume_demo()


func ensure_mode_visible(id: String) -> void:
	for tile: Dictionary in _tiles:
		if tile.entry.id == id:
			scroll.ensure_control_visible(tile.button)
			return


func _sync_pip_visibility() -> void:
	if pip == null:
		return
	pip.set_idle_paused(not is_visible_in_tree())
	pip.set_proactive_allowed(is_visible_in_tree())


func fit(available: Vector2, factor: float) -> void:
	_available = available
	_factor = maxf(0.1, factor)
	var css: Vector2 = available * _factor
	var wide: bool = css.x >= 800
	var short: bool = css.y < 540
	var edge: float = (12.0 if css.x < 600 else 24.0) / _factor
	var content_width: float = maxf(1.0, minf(1040.0 / _factor, available.x - edge * 2.0))
	var content_x: float = (available.x - content_width) * 0.5
	var top_height: float = (44.0 if short else 48.0) / _factor
	var top_y: float = (8.0 if short else 12.0) / _factor
	_style_surface()
	custom_minimum_size = Vector2.ZERO
	size = available
	_top.position = Vector2(content_x, top_y)
	_top.size = Vector2(content_width, top_height)
	var coin_width: float = (100.0 if css.x < 420 else 112.0) / _factor
	coin_counter.position = Vector2(content_width - coin_width, (top_height - 36.0 / _factor) * 0.5)
	coin_counter.size = Vector2(coin_width, 36.0 / _factor)
	_brand.position = Vector2.ZERO
	_brand.size = Vector2(maxf(1.0, content_width - coin_width - 12.0 / _factor), top_height)
	_brand.add_theme_font_size_override("font_size", ceili((18.0 if css.x < 420 else 22.0) / _factor))
	var scroll_top: float = top_y + top_height + (8.0 if short else 12.0) / _factor
	scroll.position = Vector2(content_x, scroll_top)
	scroll.size = Vector2(content_width, maxf(1.0, available.y - scroll_top - edge))
	_body.add_theme_constant_override("separation", ceili((12.0 if not wide else 16.0) / _factor))
	_style_theme_choices()
	grid.columns = 3 if wide else 2
	grid.add_theme_constant_override("h_separation", ceili((14.0 if wide else 10.0) / _factor))
	grid.add_theme_constant_override("v_separation", ceili((14.0 if wide else 10.0) / _factor))
	var tile_height: float = (210.0 if css.y >= 780 else 196.0) if wide else (200.0 if css.y >= 740 else 184.0)
	for tile: Dictionary in _tiles:
		tile.button.custom_minimum_size = Vector2(0, tile_height / _factor)
		_style_tile(tile)
		_layout_tile(tile)
	_footer.add_theme_constant_override("separation", ceili(8.0 / _factor))
	_style_footer()
	_credit.add_theme_font_size_override("font_size", ceili(10.0 / _factor))
	_layout_hero()


func _style_footer() -> void:
	if collection_button == null:
		return
	var narrow: bool = _available.x * _factor < 440
	collection_button.text = "Word library"
	sound_button.text = "Sound: off" if _muted else "Sound: on"
	sound_button.set("accessibility_name", "Turn sound on" if _muted else "Turn sound off")
	for button: Button in [collection_button, sound_button]:
		Style.action_button(button, Style.GOOD)
		button.custom_minimum_size = Vector2(0, 44.0 / _factor)
		button.add_theme_font_size_override("font_size", ceili(13.0 / _factor))
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var surface: StyleBox = button.get_theme_stylebox(state)
			surface.content_margin_left = (6.0 if narrow else 12.0) / _factor
			surface.content_margin_right = (6.0 if narrow else 12.0) / _factor


func _style_tile(tile: Dictionary) -> void:
	var radius: int = ceili(20.0 / _factor)
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var pressed: bool = state in ["pressed", "hover_pressed"]
		var tint: Color = tile.entry.tint
		var surface := Style.box(tint.lightened(0.32 if state == "normal" else 0.08),
			Style.GOOD if pressed else tint.darkened(0.13), radius, maxi(1, roundi(1.0 / _factor)))
		surface.border_width_bottom = ceili((2.0 if pressed else 4.0) / _factor)
		surface.shadow_color = Color(tint.darkened(0.55), 0.06 if pressed else 0.11)
		surface.shadow_size = ceili((1.0 if pressed else 3.0) / _factor)
		surface.shadow_offset = Vector2(0, (1.0 if pressed else 2.0) / _factor)
		tile.button.add_theme_stylebox_override(state, surface)
	var focus := Style.box(Color.TRANSPARENT, Style.INK, radius, ceili(3.0 / _factor))
	focus.set_expand_margin_all(-2.0 / _factor)
	tile.button.add_theme_stylebox_override("focus", focus)


func _layout_hero() -> void:
	if pip == null or _hero.size.x <= 0:
		return
	var wide: bool = _available.x * _factor >= 800
	var short: bool = _available.y * _factor < 540
	var art_side: float = ((112.0 if short else 184.0) if wide else (100.0 if short else 120.0)) / _factor
	var gap: float = (28.0 if wide else 12.0) / _factor
	var group_width: float = minf(_hero.size.x, (840.0 if wide else 460.0) / _factor)
	var left: float = (_hero.size.x - group_width) * 0.5
	var text_x: float = left + art_side + gap
	var text_width: float = maxf(1.0, group_width - art_side - gap)
	heading.add_theme_font_size_override("font_size", ceili((28.0 if short or not wide else 42.0) / _factor))
	var title_height: float = heading.get_minimum_size().y
	heading.position = Vector2(text_x, 0)
	heading.size = Vector2(text_width, title_height)
	_intro.add_theme_font_size_override("font_size", ceili((13.0 if short or not wide else 15.0) / _factor))
	_intro.position = Vector2(text_x, title_height + 4.0 / _factor)
	_intro.size = Vector2(text_width, (24.0 if wide else 42.0) / _factor)
	var journey_height: float = (84.0 if short else 88.0) / _factor
	var intro_end: float = _intro.position.y + _intro.size.y
	var journey_y: float = (intro_end if wide else maxf(intro_end, art_side + 20.0 / _factor)) + 12.0 / _factor
	var hero_height: float = maxf(journey_y + journey_height, art_side + 20.0 / _factor)
	_hero.custom_minimum_size = Vector2(0, hero_height)
	pip.position = Vector2(left, maxf(0, (hero_height - art_side - 20.0 / _factor) * 0.5) if wide else 0)
	pip.custom_minimum_size = Vector2.ZERO
	pip.size = Vector2.ONE * art_side
	_pip_caption.position = pip.position + Vector2(0, art_side - 2.0 / _factor)
	_pip_caption.size = Vector2(art_side, 20.0 / _factor)
	_pip_caption.add_theme_font_size_override("font_size", ceili(12.0 / _factor))
	_journey.position = Vector2(text_x if wide else left, journey_y)
	_journey.size = Vector2(text_width if wide else group_width, journey_height)
	var surface := Style.box(Color("#fffdf6"), Color("#e3e5d5"), ceili(16.0 / _factor), maxi(1, roundi(1.0 / _factor)))
	surface.set_content_margin_all(0)
	_journey.add_theme_stylebox_override("panel", surface)
	var pad: float = 14.0 / _factor
	var portrait_side: float = 64.0 / _factor
	var copy_width: float = _journey.size.x - pad * 2.0 - (portrait_side + 12.0 / _factor if _next_pip.visible else 0.0)
	_journey_heading.position = Vector2(pad, 9.0 / _factor)
	_journey_heading.size = Vector2(copy_width, 22.0 / _factor)
	_journey_heading.add_theme_font_size_override("font_size", ceili(15.0 / _factor))
	_journey_count.position = Vector2(pad, 31.0 / _factor)
	_journey_count.size = Vector2(copy_width, 20.0 / _factor)
	_journey_count.add_theme_font_size_override("font_size", ceili(13.0 / _factor))
	_journey_bar.position = Vector2(pad, 61.0 / _factor)
	_journey_bar.size = Vector2(copy_width, 10.0 / _factor)
	var track := Style.box(Color("#e7e9db"), Color.TRANSPARENT, ceili(5.0 / _factor), 0)
	track.set_content_margin_all(0)
	_journey_bar.add_theme_stylebox_override("background", track)
	_next_pip.position = Vector2(_journey.size.x - pad - portrait_side, 3.0 / _factor)
	_next_pip.size = Vector2.ONE * portrait_side
	_next_label.position = _next_pip.position + Vector2(0, portrait_side - 1.0 / _factor)
	_next_label.size = Vector2(portrait_side, 18.0 / _factor)
	_next_label.add_theme_font_size_override("font_size", ceili(11.0 / _factor))


func _layout_tile(tile: Dictionary) -> void:
	var area: Vector2 = tile.button.size
	var pad: float = 10.0 / _factor
	var compact: bool = area.x * _factor < 170
	tile.copy.add_theme_font_size_override("font_size", ceili((12.0 if compact else 13.0) / _factor))
	var copy_height: float = maxf(34.0 / _factor, tile.copy.get_minimum_size().y)
	var title_y: float = area.y - copy_height - 43.0 / _factor
	var art_height: float = maxf(36.0 / _factor, title_y - 20.0 / _factor)
	tile.preview.position = Vector2(pad, 16.0 / _factor)
	tile.preview.size = Vector2(maxf(1.0, area.x - pad * 2.0), art_height)
	tile.title.position = Vector2(pad, title_y)
	tile.title.size = Vector2(maxf(1.0, area.x - pad * 2.0), 28.0 / _factor)
	tile.copy.position = Vector2(pad, title_y + 29.0 / _factor)
	tile.copy.size = Vector2(maxf(1.0, area.x - pad * 2.0), copy_height)
	tile.current.position = Vector2(pad, 5.0 / _factor)
	tile.current.add_theme_font_size_override("font_size", ceili(9.0 / _factor))
	tile.current.visible = not _current.is_empty() and tile.entry.id == _current
	var title_size: int = ceili((20.0 if grid.columns == 3 else 18.0) / _factor)
	var title_font: Font = tile.title.get_theme_font("font")
	while title_size > ceili(14.0 / _factor) and title_font.get_string_size(tile.title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > tile.title.size.x:
		title_size -= 1
	tile.title.add_theme_font_size_override("font_size", title_size)


func snapshot() -> Dictionary:
	var controls: Array = []
	var previews: Array = []
	for tile: Dictionary in _tiles:
		previews.append({"mode": tile.entry.id, "rect": _rect_values(tile.preview.get_global_rect()),
			"animating": tile.preview.is_processing(), "reduced_motion": tile.preview.reduced_motion,
			"elapsed": tile.preview._elapsed, "duration": tile.preview.DURATION})
	var viewport: Rect2 = scroll.get_global_rect()
	for button: Button in theme_buttons + buttons + [collection_button, sound_button]:
		var rect: Rect2 = button.get_global_rect()
		controls.append({"name": str(button.name), "rect": _rect_values(rect), "disabled": button.disabled,
			"visible": button.is_visible_in_tree() and viewport.intersects(rect), "fully_visible": viewport.encloses(rect),
			"focused": button.has_focus(), "selected": button.button_pressed, "visible_rect": _rect_values(viewport.intersection(rect))})
	return {"visible": is_visible_in_tree(), "current": _current, "controls": controls, "previews": previews,
		"hero": {"title": heading.text, "intro": _intro.text, "ready": _growth.get("ready", false),
			"completed": _growth.get("completed", false), "mastered": _growth.get("mastered", 0), "total": _growth.get("total", 0),
			"progress": _journey_bar.value / 100.0, "next_age": _next_age, "rect": _rect_values(_hero.get_global_rect()),
			"pip_rect": _rect_values(pip.get_global_rect()), "title_rect": _rect_values(heading.get_global_rect()),
			"intro_rect": _rect_values(_intro.get_global_rect()), "journey_rect": _rect_values(_journey.get_global_rect()),
			"next_pip_rect": _rect_values(_next_pip.get_global_rect())},
		"theme_id": _theme_id, "theme_save_failed": _theme_save_notice.visible,
		"rect": _rect_values(get_global_rect()), "scroll_rect": _rect_values(viewport), "viewport_rect": _rect_values(viewport),
		"scroll_offset": scroll.scroll_vertical, "scrollable": scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page,
		"content_height": _body.size.y, "coins": coin_counter.target, "pip_age": pip.growth_age}


func _rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
