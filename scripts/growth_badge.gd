extends Button

const Style = preload("res://scripts/ui_style.gd")

var level_label: Label
var count_label: Label
var age_label: Label
var bar: ProgressBar
var compact: bool = false
var _scale: float = 1.0
var _tiny: bool = false
var _state: Dictionary = {}


func _init() -> void:
	name = "GrowthProgressButton"
	focus_mode = Control.FOCUS_ALL
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar = ProgressBar.new()
	bar.name = "GrowthProgressBar"
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	level_label = Style.label("Lv0", 18)
	level_label.add_theme_font_override("font", Style.HEADING_FONT)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(level_label)
	count_label = Style.label("0 / 1", 11)
	count_label.add_theme_font_override("font", Style.HEADING_FONT)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(count_label)
	age_label = Style.label("Baby", 10)
	age_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(age_label)
	resized.connect(_layout)
	fit(1.0, false)


func configure(state: Dictionary) -> void:
	_state = state
	var ready: bool = state.get("ready", false)
	var level: int = state.get("level", 0)
	level_label.text = str(state.get("label", "Lv0")) if ready else "Lv…"
	count_label.text = ("MAX" if state.get("level_completed", false) else "%d / %d" % [state.get("level_mastered", 0), state.get("level_required", 1)]) if ready else "Unavailable"
	age_label.text = str(state.get("age_label", "Baby")) if ready else ""
	bar.value = float(state.get("level_progress", 0.0)) * 100.0 if ready else 0.0
	var description: String = "%s. Pip: %s. %d of %d words mastered in your current age set." % [level_label.text, age_label.text, state.get("mastered", 0), state.get("total", 0)]
	if not ready:
		description = "Learning progress is unavailable. Retry saving to load it."
	elif state.get("level_completed", false):
		description += " Maximum level reached."
	else:
		description += " Master %d new %s to reach Lv%d." % [state.get("level_remaining", 1), "word" if state.get("level_remaining", 1) == 1 else "words", level + 1]
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
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Style.GOOD
	focus.border_width_bottom = maxi(1, roundi(2 / _scale))
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
	age_label.visible = not compact
	_style_type()
	reset_size()
	if not _state.is_empty():
		configure(_state)
	_layout()


func _style_type() -> void:
	var long_level: bool = level_label.text.length() > 3
	level_label.add_theme_font_size_override("font_size", ceili((13 if long_level else 16 if _tiny else 18) / _scale))
	level_label.add_theme_color_override("font_color", Style.INK)
	count_label.add_theme_font_size_override("font_size", ceili(11 / _scale))
	count_label.add_theme_color_override("font_color", Color("#2b5141"))
	age_label.add_theme_font_size_override("font_size", ceili(10 / _scale))
	age_label.add_theme_color_override("font_color", Color("#42644e"))


func _layout() -> void:
	if level_label == null:
		return
	level_label.position = Vector2(3, 1 if compact else 12) / _scale
	level_label.size = Vector2(size.x - 6 / _scale if compact else 42 / _scale, 28 / _scale)
	bar.position = Vector2(8 if _tiny else 10 if compact else 54, 31 if compact else 16) / _scale
	bar.size = Vector2(size.x - bar.position.x - (8 if _tiny else 10 if compact else 2) / _scale, (8 if compact else 20) / _scale)
	count_label.position = bar.position + Vector2(2, 0) / _scale
	count_label.size = Vector2(bar.size.x - 4 / _scale, bar.size.y)
	age_label.position = Vector2(bar.position.x, 36 / _scale)
	age_label.size = Vector2(bar.size.x, 14 / _scale)
