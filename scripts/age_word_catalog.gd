extends VBoxContainer
## Browse the supplied age-eligible vocabulary without changing lesson progress.

signal hear_requested(word: Dictionary)

const Style = preload("res://scripts/ui_style.gd")
const ResultScroll = preload("res://scripts/result_scroll.gd")

var scroll: ResultScroll
var grid: GridContainer
var word_buttons: Array[Button] = []
var title_label: Label
var count_label: Label
var interaction_allowed: Callable

var _heading: HBoxContainer
var _content: MarginContainer
var _words: Array = []
var _band: Dictionary = {}
var _palette: Dictionary = {}
var _textures: Dictionary = {}
var _by_id: Dictionary = {}
var _styled_scale: float = -1.0
var _styled_accent: Color = Color.TRANSPARENT


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			cancel_input()
		else:
			_layout())


func _ready() -> void:
	_build()
	_layout()


func _build() -> void:
	if scroll != null:
		return
	_heading = HBoxContainer.new()
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heading)
	title_label = Style.label("All words", 19)
	title_label.name = "AgeWordTitle"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	_heading.add_child(title_label)
	count_label = Style.label("0 words", 13)
	count_label.name = "AgeWordCount"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_color_override("font_color", Style.MUTED)
	_heading.add_child(count_label)
	scroll = ResultScroll.new()
	scroll.name = "AgeWordScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.interaction_allowed = _can_interact
	add_child(scroll)
	_content = MarginContainer.new()
	_content.name = "WordCatalogContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_content)
	grid = GridContainer.new()
	grid.name = "AgeWordGrid"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(grid)
	grid.resized.connect(_reveal_focused_word)
	scroll.resized.connect(_layout)


func configure(words: Array, band: Dictionary, palette: Dictionary) -> void:
	_build()
	var ordered: Array = words.duplicate(true)
	ordered.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_text: String = str(first.get("text", "")).to_lower()
		var second_text: String = str(second.get("text", "")).to_lower()
		return str(first.get("id", "")) < str(second.get("id", "")) if first_text == second_text else first_text.naturalnocasecmp_to(second_text) < 0)
	var words_changed: bool = ordered != _words
	var band_changed: bool = str(band.get("id", "")) != str(_band.get("id", ""))
	_band = band.duplicate(true)
	_palette = palette.duplicate(true)
	title_label.text = str(_band.get("name", "All words"))
	count_label.text = "%d %s" % [ordered.size(), "word" if ordered.size() == 1 else "words"]
	if words_changed or band_changed:
		cancel_input()
	if words_changed:
		_words = ordered
		_rebuild_words()
	if words_changed or band_changed:
		scroll.scroll_vertical = 0
	# Refreshing identical data must not jump back to a card the player focused
	# before scrolling elsewhere. Geometry changes handle their own focus reveal.
	_layout(false)


func _rebuild_words() -> void:
	for button: Button in word_buttons:
		grid.remove_child(button)
		button.queue_free()
	word_buttons.clear()
	_by_id.clear()
	for word: Dictionary in _words:
		var button := Button.new()
		var id: String = str(word.get("id", word.get("text", "")))
		button.name = "AgeWord_" + id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.set_meta("word", word)
		button.set_meta("word_id", id)
		for property: Dictionary in button.get_property_list():
			if property.name == "accessibility_name":
				button.set("accessibility_name", "Hear " + str(word.get("text", "")))
				break
		grid.add_child(button)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(column)
		var picture := TextureRect.new()
		picture.name = "WordImage"
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture = _word_texture(str(word.get("image", "")))
		column.add_child(picture)
		var caption := Style.label(str(word.get("text", "")), 14)
		caption.name = "WordLabel"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_constant_override("line_spacing", 0)
		column.add_child(caption)
		button.set_meta("word_art", picture)
		button.set_meta("word_label", caption)
		button.set_meta("word_column", column)
		button.pressed.connect(_hear_word.bind(button))
		button.focus_entered.connect(ensure_control_visible.bind(button, true))
		word_buttons.append(button)
		_by_id[id] = button
	_styled_scale = -1.0


func _word_texture(source: String) -> Texture2D:
	if source.is_empty():
		return null
	var path: String = source if source.begins_with("res://") else "res://" + source
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	return _textures[path]


func _can_interact() -> bool:
	return is_visible_in_tree() and (not interaction_allowed.is_valid() or interaction_allowed.call())


func _hear_word(button: Button) -> void:
	if not _can_interact() or not is_instance_valid(button) or not word_buttons.has(button):
		return
	var word: Dictionary = button.get_meta("word")
	hear_requested.emit(word.duplicate(true))


func cancel_input() -> void:
	if is_instance_valid(scroll):
		scroll.cancel_drag()


func focus_word(id: String) -> bool:
	var button: Button = _by_id.get(id)
	if button == null or not _can_interact():
		return false
	button.grab_focus()
	ensure_control_visible(button, true)
	return true


func ensure_control_visible(control: Control, explicit_focus: bool = false) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(control) or not grid.is_ancestor_of(control):
		return
	if scroll.is_pointer_active() or (scroll.is_scrolling() and not explicit_focus):
		return
	if explicit_focus:
		scroll.cancel_drag()
	# A very short viewport can show a card's caption even when its whole image
	# and label cannot fit together. All remaining content stays scrollable.
	var target: Control = control
	if control.size.y > scroll.size.y and control.has_meta("word_label"):
		target = control.get_meta("word_label")
	var rect: Rect2 = _content.get_global_transform().affine_inverse() * target.get_global_rect()
	if rect.position.y < scroll.scroll_vertical:
		scroll.scroll_vertical = floori(rect.position.y)
	elif rect.end.y > scroll.scroll_vertical + scroll.size.y:
		scroll.scroll_vertical = ceili(rect.end.y - scroll.size.y)


func _reveal_focused_word() -> void:
	if not is_inside_tree() or not is_visible_in_tree() or scroll == null:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and grid.is_ancestor_of(focused):
		ensure_control_visible(focused)


func _layout(reveal_focus: bool = true) -> void:
	if scroll == null or size.x <= 0:
		return
	var scale: float = Style.ui_scale(self)
	var gap: int = ceili(8.0 / scale)
	var inset: int = ceili(3.0 / scale)
	add_theme_constant_override("separation", ceili(6.0 / scale))
	_heading.add_theme_constant_override("separation", ceili(12.0 / scale))
	_heading.custom_minimum_size.y = ceilf(30.0 / scale)
	title_label.add_theme_font_size_override("font_size", ceili(19.0 / scale))
	count_label.add_theme_font_size_override("font_size", ceili(13.0 / scale))
	for edge in ["left", "right", "top", "bottom"]:
		_content.add_theme_constant_override("margin_" + edge, inset)
	var available: float = maxf(1.0, size.x - inset * 2.0)
	grid.columns = clampi(floori((available + gap) / (124.0 / scale + gap)), 1, 8)
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", gap)
	var accent: Color = _palette.get("accent", Style.GOOD)
	var restyle: bool = not is_equal_approx(_styled_scale, scale) or _styled_accent != accent
	for button: Button in word_buttons:
		if restyle:
			var previous_focus: int = button.focus_mode
			Style.action_button(button, accent)
			button.focus_mode = previous_focus
			button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Style.INK, ceili(12.0 / scale), maxi(2, ceili(2.0 / scale))))
		button.custom_minimum_size = Vector2(0, ceilf(126.0 / scale))
		var column: VBoxContainer = button.get_meta("word_column")
		column.offset_left = 8.0 / scale
		column.offset_right = -8.0 / scale
		column.offset_top = 8.0 / scale
		column.offset_bottom = -8.0 / scale
		column.add_theme_constant_override("separation", ceili(4.0 / scale))
		var picture: TextureRect = button.get_meta("word_art")
		picture.custom_minimum_size.y = ceilf(70.0 / scale)
		var caption: Label = button.get_meta("word_label")
		caption.custom_minimum_size.y = ceilf(34.0 / scale)
		caption.add_theme_font_size_override("font_size", ceili(14.0 / scale))
	_styled_scale = scale
	_styled_accent = accent
	if reveal_focus:
		_reveal_focused_word.call_deferred()


func snapshot() -> Dictionary:
	var ids: Array[String] = []
	for button: Button in word_buttons:
		ids.append(str(button.get_meta("word_id")))
	return {"visible": is_visible_in_tree(), "age_band": str(_band.get("id", "")),
		"word_count": word_buttons.size(), "word_ids": ids,
		"columns": grid.columns if grid != null else 0,
		"scroll_offset": scroll.scroll_vertical if scroll != null else 0,
		"scroll_max": maxf(0.0, scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page) if scroll != null else 0.0}
