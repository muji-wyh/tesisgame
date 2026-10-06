extends PanelContainer
## A readable game library using the existing menu's pause and input lifecycle.

signal mode_requested(id: String)
signal dismissed
signal sound_toggled
signal motion_toggled

const Style = preload("res://scripts/ui_style.gd")
const CATALOG := [
	{"id": "match", "title": "Match", "copy": "Connect pictures\nand words.", "detail": "5 PAIRS", "art": "res://assets/avatars/cat.svg", "tint": Color("#e6efe3")},
	{"id": "memory", "title": "Memory", "copy": "Turn a card.\nFind its friend.", "detail": "NO TIMER", "art": "res://assets/avatars/rainbow.svg", "tint": Color("#f2e9d8")},
	{"id": "pop", "title": "Voice Pop", "copy": "Say the word.\nWatch it pop!", "detail": "50 SECONDS · MIC", "art": "res://assets/avatars/rocket.svg", "tint": Color("#e3eef1")}
]

var heading: Label
var grid: GridContainer
var buttons: Array[Button] = []
var sound_button: Button
var motion_button: Button
var close_button: Button
var _body: VBoxContainer
var _intro: Label
var _eyebrow: Label
var _footer: HBoxContainer
var _credit: Label
var _tiles: Array[Dictionary] = []
var _current := "match"
var _factor := 1.0

func _init() -> void:
	name = "GameModePopover"
	_body = VBoxContainer.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	var top := HBoxContainer.new()
	_body.add_child(top)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	top.add_child(titles)
	_eyebrow = Style.label("PIP AND WORDS", 11)
	_eyebrow.add_theme_color_override("font_color", Style.MUTED)
	titles.add_child(_eyebrow)
	heading = Style.label("A little play. A big discovery.", 28)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(heading)
	close_button = Button.new()
	close_button.name = "LibraryClose"
	close_button.text = "Back"
	close_button.tooltip_text = "Return to your game (Escape)"
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.pressed.connect(func() -> void: dismissed.emit())
	top.add_child(close_button)
	_intro = Style.label("Choose a game. Your treasures and best scores stay saved.", 14)
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro.add_theme_color_override("font_color", Style.MUTED)
	_body.add_child(_intro)
	grid = GridContainer.new()
	grid.name = "ModeOptions"
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(grid)
	for entry: Dictionary in CATALOG:
		var tile := Button.new()
		tile.name = "Mode_" + str(entry.id)
		tile.tooltip_text = str(entry.title) + ". " + str(entry.copy).replace("\n", " ") + " " + str(entry.detail)
		tile.toggle_mode = true
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.pressed.connect(func() -> void: mode_requested.emit(str(entry.id)))
		grid.add_child(tile)
		buttons.append(tile)
		var picture := TextureRect.new()
		picture.texture = load(entry.art)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(picture)
		var title := Style.label(entry.title, 22)
		tile.add_child(title)
		var copy := Style.label(entry.copy, 14)
		copy.add_theme_color_override("font_color", Style.MUTED)
		tile.add_child(copy)
		var detail := Style.label(entry.detail, 10)
		detail.add_theme_color_override("font_color", Style.MUTED)
		tile.add_child(detail)
		var current := Style.label("PLAYING", 10)
		current.add_theme_color_override("font_color", Style.GOOD)
		tile.add_child(current)
		var info := {"button": tile, "picture": picture, "title": title, "copy": copy, "detail": detail, "current": current, "entry": entry}
		_tiles.append(info)
		tile.resized.connect(_layout_tile.bind(info))
	_footer = HBoxContainer.new()
	_body.add_child(_footer)
	sound_button = Button.new()
	sound_button.name = "LibrarySound"
	sound_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_button.pressed.connect(func() -> void: sound_toggled.emit())
	_footer.add_child(sound_button)
	motion_button = Button.new()
	motion_button.name = "LibraryMotion"
	motion_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	motion_button.pressed.connect(func() -> void: motion_toggled.emit())
	_footer.add_child(motion_button)
	_credit = Style.label("Art: Twemoji · CC BY 4.0", 10)
	_credit.add_theme_color_override("font_color", Style.MUTED)
	_body.add_child(_credit)

func configure(current: String, muted: bool, reduced: bool) -> void:
	_current = current
	sound_button.text = "Sound: off" if muted else "Sound: on"
	motion_button.text = "Motion: reduced" if reduced else "Motion: full"
	for tile: Dictionary in _tiles:
		var selected: bool = tile.entry.id == current
		tile.button.button_pressed = selected
		tile.current.visible = selected and tile.button.size.y * _factor >= 170
		tile.button.set("accessibility_name", str(tile.entry.title) + (", current game. " if selected else ". ") + str(tile.entry.copy).replace("\n", " ") + " " + str(tile.entry.detail))

func fit(available: Vector2, factor: float) -> void:
	_factor = factor
	var css := available * factor
	var wide: bool = css.x >= 660 or (css.x >= 440 and css.x > css.y)
	var short: bool = css.y < (560 if wide else 660)
	var tiny: bool = css.y < (380 if wide else 440)
	grid.columns = 3 if wide else 1
	var padding: float = (16.0 if short or not wide else 28.0) / factor
	var surface := Style.box(Style.PAPER, Style.EDGE, ceili(24 / factor), 1)
	surface.set_content_margin_all(padding)
	surface.shadow_color = Color(Style.INK, 0.2)
	surface.shadow_size = ceili(30 / factor)
	surface.shadow_offset = Vector2(0, 12 / factor)
	add_theme_stylebox_override("panel", surface)
	_body.add_theme_constant_override("separation", ceili((10 if short else 16) / factor))
	grid.add_theme_constant_override("h_separation", ceili(12 / factor))
	grid.add_theme_constant_override("v_separation", ceili(12 / factor))
	_footer.add_theme_constant_override("separation", ceili(8 / factor))
	heading.text = "Let's play" if tiny else "Choose your adventure" if not wide else "A little play. A big discovery."
	_eyebrow.visible = not tiny
	heading.add_theme_font_size_override("font_size", ceili((22 if short or not wide else 30) / factor))
	_eyebrow.add_theme_font_size_override("font_size", ceili(10 / factor))
	_intro.add_theme_font_size_override("font_size", ceili(13 / factor))
	_intro.visible = not short
	_credit.visible = not short
	_credit.add_theme_font_size_override("font_size", ceili(10 / factor))
	for button in [close_button, sound_button, motion_button]:
		Style.action_button(button, Style.GOOD)
		button.custom_minimum_size = Vector2(0, 44 / factor)
		button.add_theme_font_size_override("font_size", ceili(13 / factor))
	var tile_height: float = (124.0 if tiny else 148.0 if short else 218.0) if wide else (44.0 if tiny else 82.0 if short else 124.0)
	for tile: Dictionary in _tiles:
		tile.button.custom_minimum_size = Vector2(0, tile_height / factor)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var tint: Color = tile.entry.tint
			var active: bool = state in ["pressed", "hover_pressed"]
			var card := Style.box(tint.lightened(0.45 if state == "normal" else 0.2), Style.GOOD if active else Style.EDGE, ceili(16 / factor), 2 if active else 1)
			tile.button.add_theme_stylebox_override(state, card)
		var focus := Style.box(Color.TRANSPARENT, Style.INK, ceili(16 / factor), ceili(3 / factor))
		tile.button.add_theme_stylebox_override("focus", focus)
		_layout_tile(tile)
	custom_minimum_size = Vector2.ZERO
	size = Vector2(minf(900 / factor, available.x), get_combined_minimum_size().y)

func _layout_tile(tile: Dictionary) -> void:
	var area: Vector2 = tile.button.size
	var factor := _factor
	var short: bool = area.y * factor < 170
	var tiny: bool = area.y * factor < 105
	var minimal: bool = area.y * factor < 60
	var pad := 14 / factor
	var horizontal: bool = grid.columns == 1 and short and not minimal
	var art_height: float = maxf(0, area.y - 114 / factor)
	tile.picture.visible = not short or horizontal
	tile.picture.position = Vector2(pad, 8 / factor)
	tile.picture.size = Vector2(area.x - pad * 2, art_height)
	var y: float = (area.y - 27 / factor) * 0.5 if minimal else pad if short else art_height + 14 / factor
	tile.title.position = Vector2(pad, y)
	tile.title.size = Vector2(area.x - pad * 2, 27 / factor)
	tile.title.add_theme_font_size_override("font_size", ceili((17 if short else 21) / factor))
	tile.copy.visible = not tiny
	tile.copy.position = Vector2(pad, y + 30 / factor)
	tile.copy.size = Vector2(area.x - pad * 2, 42 / factor)
	tile.copy.add_theme_font_size_override("font_size", ceili(13 / factor))
	tile.detail.position = Vector2(pad, area.y - 23 / factor)
	tile.detail.visible = not minimal
	tile.detail.size = Vector2(area.x - pad * 2, 14 / factor)
	tile.detail.add_theme_font_size_override("font_size", ceili(9 / factor))
	tile.current.position = Vector2(pad, 10 / factor)
	tile.current.add_theme_font_size_override("font_size", ceili(9 / factor))
	tile.current.visible = tile.entry.id == _current and not short
	if horizontal:
		var art_size: float = minf(area.y - pad * 2, 76 / factor)
		var text_x: float = pad + art_size + 14 / factor
		var text_width: float = maxf(0, area.x - text_x - pad)
		var text_height: float = (45 if tiny else 90) / factor
		var text_top: float = (area.y - text_height) * 0.5
		tile.picture.position = Vector2(pad, (area.y - art_size) * 0.5)
		tile.picture.size = Vector2.ONE * art_size
		tile.title.position = Vector2(text_x, text_top)
		tile.title.size.x = text_width
		tile.copy.position = Vector2(text_x, text_top + 30 / factor)
		tile.copy.size.x = text_width
		tile.detail.position = Vector2(text_x, text_top + (31 if tiny else 76) / factor)
		tile.detail.size.x = text_width

func snapshot() -> Dictionary:
	var controls: Array = []
	for button: Button in buttons + [close_button, sound_button, motion_button]:
		var rect := button.get_global_rect()
		controls.append({"name": str(button.name), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "disabled": button.disabled})
	return {"visible": is_visible_in_tree(), "current": _current, "controls": controls}
