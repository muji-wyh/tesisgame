extends Button

const Style = preload("res://scripts/ui_style.gd")

var level_label: Label
var count_label: Label
var target_label: Label
var bar: ProgressBar
var compact: bool = false
var _scale: float = 1.0
var _tiny: bool = false
var _state: Dictionary = {}


func _init() -> void:
	name = "GrowthProgressButton"
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_label = Style.label("Lv3", 18)
	level_label.add_theme_font_override("font", Style.HEADING_FONT)
	add_child(level_label)
	target_label = Style.label("Lv4  ›", 11)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(target_label)
	count_label = Style.label("0 / 80 mastered", 11)
	add_child(count_label)
	bar = ProgressBar.new()
	bar.name = "GrowthProgressBar"
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	resized.connect(_layout)
	fit(1.0, false)


func configure(state: Dictionary) -> void:
	_state = state
	var ready: bool = state.get("ready", false)
	var level: int = state.get("level", 3)
	level_label.text = str(state.get("label", "Lv3")) if ready else "Lv…"
	count_label.text = "%d / %d mastered" % [state.get("mastered", 0), state.get("total", 0)] if ready else "Progress unavailable"
	var next_label: String = "Lv12+" if level == 11 else "Lv%d" % (level + 1)
	target_label.text = "›" if compact else (next_label + "  ›" if level < 12 else "Words  ›")
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
	_layout()


func fit(css_scale: float, use_compact: bool, tiny: bool = false) -> void:
	_scale = css_scale
	compact = use_compact
	_tiny = tiny
	custom_minimum_size = Vector2(52 if tiny else 68 if compact else 168, 44 if compact else 52) / _scale
	var radius: int = ceili(13 / _scale)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var pressed: bool = state == "pressed"
		var surface := Style.box(Color("#e7f1e2") if pressed else Color("#f5faef") if state == "hover" else Color("#fffdf4"),
			Color("#b3c9af"), radius, maxi(1, roundi(1 / _scale)))
		surface.border_width_bottom = ceili((1 if pressed else 3) / _scale)
		surface.shadow_color = Color("#294d3c", 0.06 if pressed else 0.1)
		surface.shadow_size = ceili((1 if pressed else 3) / _scale)
		surface.shadow_offset = Vector2(0, (1 if pressed else 2) / _scale)
		for edge: String in ["left", "right", "top", "bottom"]:
			surface.set("content_margin_" + edge, 0.0)
		add_theme_stylebox_override(state, surface)
	var focus := Style.box(Color.TRANSPARENT, Style.GOOD, radius, maxi(2, roundi(2 / _scale)))
	focus.set_expand_margin_all(2 / _scale)
	add_theme_stylebox_override("focus", focus)
	for label: Label in [level_label, count_label, target_label]:
		label.add_theme_font_size_override("font_size", ceili((13 if tiny else 16 if compact else 18) / _scale) if label == level_label else ceili(11 / _scale))
		label.add_theme_color_override("font_color", Color("#2e5946") if label == level_label else Color("#587361"))
	for key: String in ["background", "fill"]:
		var track := Style.box(Color("#e2e9d9") if key == "background" else Color("#77a767"), Color.TRANSPARENT, ceili(3 / _scale), 0)
		for edge: String in ["left", "right", "top", "bottom"]:
			track.set("content_margin_" + edge, 0.0)
		bar.add_theme_stylebox_override(key, track)
	count_label.visible = not compact
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if compact else HORIZONTAL_ALIGNMENT_LEFT
	reset_size()
	if not _state.is_empty():
		configure(_state)
	_layout()


func _layout() -> void:
	var inset: float = (7.0 if _tiny else 10.0 if compact else 12.0) / _scale
	var width: float = maxf(0.0, size.x - inset * 2)
	level_label.position = Vector2(inset, 4 / _scale)
	level_label.size = Vector2(width, 24 / _scale)
	target_label.visible = not compact
	target_label.position = Vector2(size.x - inset - (12 if compact else 60) / _scale, 6 / _scale)
	target_label.size = Vector2((12 if compact else 60) / _scale, 20 / _scale)
	bar.position = Vector2(inset, (30 if compact else 29) / _scale)
	bar.size = Vector2(width, 5 / _scale)
	count_label.position = Vector2(inset, 35 / _scale)
	count_label.size = Vector2(width, 15 / _scale)
