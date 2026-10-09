extends Button

const Style = preload("res://scripts/ui_style.gd")

var level_label: Label
var count_label: Label
var target_label: Label
var bar: ProgressBar
var _level_plate: Panel
var compact: bool = false
var _scale: float = 1.0
var _tiny: bool = false
var _state: Dictionary = {}


func _init() -> void:
	name = "GrowthProgressButton"
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level_plate = Panel.new()
	_level_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level_plate)
	bar = ProgressBar.new()
	bar.name = "GrowthProgressBar"
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	level_label = Style.label("Lv3", 18)
	level_label.add_theme_font_override("font", Style.HEADING_FONT)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(level_label)
	target_label = Style.label("›", 16)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(target_label)
	count_label = Style.label("0 / 80", 11)
	count_label.add_theme_font_override("font", Style.HEADING_FONT)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(count_label)
	resized.connect(_layout)
	mouse_entered.connect(_refresh_surface)
	mouse_exited.connect(_refresh_surface)
	button_down.connect(_refresh_surface)
	button_up.connect(_refresh_surface)
	fit(1.0, false)


func configure(state: Dictionary) -> void:
	_state = state
	var ready: bool = state.get("ready", false)
	var level: int = state.get("level", 3)
	level_label.text = str(state.get("label", "Lv3")) if ready else "Lv…"
	count_label.text = "%d / %d" % [state.get("mastered", 0), state.get("total", 0)] if ready else "Unavailable"
	var next_label: String = "Lv12+" if level == 11 else "Lv%d" % (level + 1)
	bar.value = float(state.get("progress", 0.0)) * 100.0 if ready else 0.0
	var description: String = "%s. %d of %d words mastered." % [level_label.text, state.get("mastered", 0), state.get("total", 0)]
	if not ready:
		description = "Learning progress is unavailable. Retry saving to load it."
	elif state.get("completed", false):
		description += " All stages unlocked."
	elif level < 12:
		description += " Master every word to reach %s." % next_label
	tooltip_text = description + " View your words."
	set("accessibility_name", tooltip_text)
	bar.set("accessibility_name", description)
	_style_type()
	_layout()


func fit(css_scale: float, use_compact: bool, tiny: bool = false) -> void:
	_scale = css_scale
	compact = use_compact
	_tiny = tiny
	custom_minimum_size = Vector2(52 if tiny else 68 if compact else 168, 44 if compact else 52) / _scale
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := Style.box(Color.TRANSPARENT, Style.GOOD, ceili(16 / _scale), maxi(2, roundi(2 / _scale)))
	focus.set_expand_margin_all(2 / _scale)
	add_theme_stylebox_override("focus", focus)
	for key: String in ["background", "fill"]:
		var fill: bool = key == "fill"
		var track := Style.box(Color("#91d9ad") if fill else Color("#dde8db"),
			Color("#b8efd0") if fill else Color("#a6beaa"), ceili((4 if compact else 10) / _scale), maxi(1, roundi(1 / _scale)))
		track.border_width_top = ceili((1 if fill else 2) / _scale)
		track.border_width_bottom = ceili((2 if fill else 1) / _scale)
		track.shadow_color = Color("#345444", 0.08)
		track.shadow_size = 0 if fill else ceili(1 / _scale)
		track.shadow_offset = Vector2(0, 1 / _scale)
		for edge: String in ["left", "right", "top", "bottom"]:
			track.set("content_margin_" + edge, 0.0)
		bar.add_theme_stylebox_override(key, track)
	count_label.visible = not compact
	_style_type()
	_refresh_surface()
	reset_size()
	if not _state.is_empty():
		configure(_state)
	_layout()


func _style_type() -> void:
	var long_level: bool = level_label.text.length() > 3
	level_label.add_theme_font_size_override("font_size", ceili((13 if long_level else 16 if _tiny else 18) / _scale))
	level_label.add_theme_color_override("font_color", Color("#67471f"))
	count_label.add_theme_font_size_override("font_size", ceili(11 / _scale))
	count_label.add_theme_color_override("font_color", Color("#2b5141"))
	target_label.add_theme_font_size_override("font_size", ceili(16 / _scale))
	target_label.add_theme_color_override("font_color", Color("#42644e"))


func _refresh_surface() -> void:
	var pressed: bool = is_pressed()
	var surface := Style.box(Color("#efcd86") if pressed else Color("#ffe8ad") if is_hovered() else Color("#f9dfa1"),
		Color("#c5a25f"), ceili(15 / _scale), maxi(1, roundi(1 / _scale)))
	surface.border_width_bottom = ceili((1 if pressed else 3) / _scale)
	surface.shadow_color = Color("#735a2e", 0.08 if pressed else 0.13)
	surface.shadow_size = ceili((1 if pressed else 2) / _scale)
	surface.shadow_offset = Vector2(0, (1 if pressed else 2) / _scale)
	_level_plate.add_theme_stylebox_override("panel", surface)


func _layout() -> void:
	if _level_plate == null:
		return
	_level_plate.position = Vector2.ZERO if compact else Vector2(0, 4 / _scale)
	_level_plate.size = Vector2(size.x if compact else 48 / _scale, 44 / _scale)
	level_label.position = _level_plate.position + Vector2(3, 1 if compact else 8) / _scale
	level_label.size = Vector2(_level_plate.size.x - 6 / _scale, 28 / _scale)
	bar.position = Vector2(8 if _tiny else 10 if compact else 54, 31 if compact else 16) / _scale
	bar.size = Vector2(size.x - bar.position.x - (8 if _tiny else 10 if compact else 14) / _scale, (8 if compact else 20) / _scale)
	count_label.position = bar.position + Vector2(2, 0) / _scale
	count_label.size = Vector2(bar.size.x - 4 / _scale, bar.size.y)
	target_label.position = Vector2(size.x - 13 / _scale, bar.position.y - 1 / _scale)
	target_label.size = Vector2(12, 20) / _scale
	target_label.visible = not compact
