extends PanelContainer
## The game's home: a quiet companion and six clear places to play.

signal mode_requested(id: String)
signal sound_toggled
signal motion_toggled
signal collection_requested
signal theme_requested(id: String)

const Style = preload("res://scripts/ui_style.gd")
const Data = preload("res://scripts/game_data.gd")
const Model = preload("res://scripts/game_model.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const DuckMascot = preload("res://scripts/duck_mascot.gd")
const CoinCounter = preload("res://scripts/coin_counter.gd")
const ResultScroll = preload("res://scripts/result_scroll.gd")
const CATALOG := [
	{"id": "match", "title": "Match", "copy": "Pair pictures\nwith words.", "detail": "5 PAIRS", "art": "res://assets/images/ui/modes/cat.svg", "tint": Color("#e6efe3")},
	{"id": "memory", "title": "Memory", "copy": "Flip cards.\nFind each pair.", "detail": "NO TIMER", "art": "res://assets/images/ui/modes/rainbow.svg", "tint": Color("#f2e9d8")},
	{"id": "pop", "title": "Voice Pop", "copy": "Say a word.\nMake it pop!", "detail": "50 SECONDS · MIC", "art": "res://assets/images/ui/modes/rocket.svg", "tint": Color("#e3eef1")},
	{"id": "phrase", "title": "Phrase Builder", "copy": "Listen, then\nbuild a phrase.", "detail": "3 PHRASES", "art": "res://assets/images/mascots/growth/pip-baby.png", "tint": Color("#f5ebce")},
	{"id": "jelly", "title": "Jelly Match", "copy": "Slide a pair.\nWatch it merge.", "detail": "MERGE PAIRS · TREASURE", "art": "res://assets/images/jelly-match/gel-mint.png", "tint": Color("#e1efea")},
	{"id": "word_jelly", "title": "Jelly Words", "copy": "Join pieces.\nMake a word.", "detail": "BUILD WORDS · COINS", "art": "res://assets/images/jelly-match/gel-lilac.png", "tint": Color("#eee5f4")}
]

var heading: Label
var grid: GridContainer
var buttons: Array[Button] = []
var theme_buttons: Array[Button] = []
var sound_button: Button
var motion_button: Button
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
var _reduced := false
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
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
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
	heading = Style.label("Let's play!", 38)
	_hero.add_child(heading)
	_intro = Style.label("Pick a game and grow with Pip.", 15)
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro.add_theme_color_override("font_color", Style.MUTED)
	_hero.add_child(_intro)
	_build_theme_choices()
	grid = GridContainer.new()
	grid.name = "ModeOptions"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(grid)
	for entry: Dictionary in CATALOG:
		_add_game_card(entry)
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
	motion_button = Button.new()
	UiClick.bind_button(motion_button)
	motion_button.name = "LibraryMotion"
	motion_button.pressed.connect(func() -> void: motion_toggled.emit())
	_footer.add_child(motion_button)
	for button: Button in [collection_button, sound_button, motion_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_credit = Style.label("Pip: original game art · Twemoji: CC BY 4.0", 10)
	_credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credit.add_theme_color_override("font_color", Style.MUTED)
	_body.add_child(_credit)
	visibility_changed.connect(_sync_pip_visibility)


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
	var picture := TextureRect.new()
	picture.texture = load(entry.art)
	if entry.id == "phrase":
		picture.texture = _portrait(picture.texture)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(picture)
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
	var info := {"button": tile, "picture": picture, "title": title, "copy": copy, "current": current, "entry": entry}
	_tiles.append(info)
	tile.resized.connect(_layout_tile.bind(info))


func _portrait(texture: Texture2D) -> AtlasTexture:
	var portrait := AtlasTexture.new()
	portrait.atlas = texture
	var side: float = texture.get_height()
	portrait.region = Rect2(0, 0, side, side)
	return portrait


func configure(current: String, muted: bool, reduced: bool) -> void:
	_current = current
	_muted = muted
	_reduced = reduced
	pip.set_reduced_motion(reduced)
	coin_counter.reduced_motion = reduced
	_style_footer()
	for tile: Dictionary in _tiles:
		var selected: bool = tile.entry.id == current and not current.is_empty()
		tile.button.button_pressed = selected
		tile.current.visible = selected
		tile.button.set("accessibility_name", str(tile.entry.title) + (", continue game. " if selected else ". ") + str(tile.entry.copy).replace("\n", " ") + " " + str(tile.entry.detail))


func set_growth_age(age: int) -> void:
	pip.set_growth_age(age)
	var path: String = "res://assets/images/mascots/growth/pip-%s.png" % ("baby" if age < 3 else "lv%d" % clampi(age, 3, 12))
	for tile: Dictionary in _tiles:
		if tile.entry.id == "phrase":
			tile.picture.texture = _portrait(load(path) as Texture2D)


func set_home_coins(amount: int) -> void:
	coin_counter.sync(amount)


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
	_hero.custom_minimum_size = Vector2(0, (76.0 if short else 112.0 if wide else 104.0) / _factor)
	_style_theme_choices()
	grid.columns = 3 if wide else 2
	grid.add_theme_constant_override("h_separation", ceili((14.0 if wide else 10.0) / _factor))
	grid.add_theme_constant_override("v_separation", ceili((14.0 if wide else 10.0) / _factor))
	var tile_height: float = (180.0 if css.y >= 780 else 162.0) if wide else (168.0 if css.y >= 740 else 152.0 if css.y >= 560 else 144.0)
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
	collection_button.text = "Words" if narrow else "Word library"
	sound_button.text = "Sound: off" if _muted else "Sound: on"
	motion_button.text = ("Motion: less" if narrow else "Motion: reduced") if _reduced else "Motion: full"
	sound_button.set("accessibility_name", "Turn sound on" if _muted else "Turn sound off")
	motion_button.set("accessibility_name", "Use full motion" if _reduced else "Use reduced motion")
	for button: Button in [collection_button, sound_button, motion_button]:
		Style.action_button(button, Style.GOOD)
		button.custom_minimum_size = Vector2(0, 44.0 / _factor)
		button.add_theme_font_size_override("font_size", ceili((11.0 if narrow else 13.0) / _factor))
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
	var art_side: float = (76.0 if short else 112.0 if wide else 104.0) / _factor
	var gap: float = (22.0 if wide else 10.0) / _factor
	var group_width: float = minf(_hero.size.x, (640.0 if wide else 430.0) / _factor)
	var left: float = (_hero.size.x - group_width) * 0.5
	pip.position = Vector2(left, 0)
	pip.custom_minimum_size = Vector2.ZERO
	pip.size = Vector2.ONE * art_side
	var text_x: float = left + art_side + gap
	var text_width: float = maxf(1.0, _hero.size.x - text_x)
	var title_height: float = (36.0 if short else 48.0) / _factor
	var text_top: float = (art_side - title_height - 36.0 / _factor) * 0.5
	heading.position = Vector2(text_x, maxf(0.0, text_top))
	heading.size = Vector2(text_width, title_height)
	heading.add_theme_font_size_override("font_size", ceili((28.0 if short or not wide else 38.0) / _factor))
	_intro.position = Vector2(text_x, heading.position.y + title_height)
	_intro.size = Vector2(text_width, 36.0 / _factor)
	_intro.add_theme_font_size_override("font_size", ceili((12.0 if short else 14.0) / _factor))


func _layout_tile(tile: Dictionary) -> void:
	var area: Vector2 = tile.button.size
	var pad: float = 10.0 / _factor
	var compact: bool = area.y * _factor < 160
	tile.copy.add_theme_font_size_override("font_size", ceili((12.0 if compact else 13.0) / _factor))
	var copy_height: float = maxf(34.0 / _factor, tile.copy.get_minimum_size().y)
	var title_y: float = area.y - copy_height - 43.0 / _factor
	var art_height: float = maxf(36.0 / _factor, title_y - 10.0 / _factor)
	tile.picture.position = Vector2(pad, 8.0 / _factor)
	tile.picture.size = Vector2(maxf(1.0, area.x - pad * 2.0), art_height)
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
	var viewport: Rect2 = scroll.get_global_rect()
	for button: Button in theme_buttons + buttons + [collection_button, sound_button, motion_button]:
		var rect: Rect2 = button.get_global_rect()
		controls.append({"name": str(button.name), "rect": _rect_values(rect), "disabled": button.disabled,
			"visible": button.is_visible_in_tree() and viewport.intersects(rect), "fully_visible": viewport.encloses(rect),
			"focused": button.has_focus(), "selected": button.button_pressed, "visible_rect": _rect_values(viewport.intersection(rect))})
	return {"visible": is_visible_in_tree(), "current": _current, "controls": controls,
		"theme_id": _theme_id, "theme_save_failed": _theme_save_notice.visible,
		"rect": _rect_values(get_global_rect()), "scroll_rect": _rect_values(viewport), "viewport_rect": _rect_values(viewport),
		"scroll_offset": scroll.scroll_vertical, "scrollable": scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page,
		"content_height": _body.size.y, "coins": coin_counter.target, "pip_age": pip.growth_age}


func _rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
