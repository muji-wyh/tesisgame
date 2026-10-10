extends VBoxContainer
const WordArt = preload("res://scripts/word_art.gd")
## Browse the supplied age-eligible vocabulary without changing lesson progress.

signal hear_requested(word: Dictionary)

const Style = preload("res://scripts/ui_style.gd")
const ResultScroll = preload("res://scripts/result_scroll.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const PAGE_SIZE: int = 60

var scroll: ResultScroll
var grid: GridContainer
var word_buttons: Array[Button] = []
var title_label: Label
var count_label: Label
var meaning_label: Label
var previous_button: Button
var next_button: Button
var page_label: Label
var interaction_allowed: Callable

var _heading: HBoxContainer
var _content: MarginContainer
var _navigation: HBoxContainer
var _words: Array = []
var _band: Dictionary = {}
var _palette: Dictionary = {}
var _textures: Dictionary = {}
var _by_id: Dictionary = {}
var _word_indices: Dictionary = {}
var _page_index: int = 0
var _growth: Dictionary = {}
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
	title_label = Style.label("All words", 22)
	title_label.name = "AgeWordTitle"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	_heading.add_child(title_label)
	count_label = Style.label("0 words", 13)
	count_label.name = "AgeWordCount"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_color_override("font_color", Style.MUTED)
	_heading.add_child(count_label)
	meaning_label = Style.label("Tap a word to hear it.", 13)
	meaning_label.name = "AgeWordMeaning"
	meaning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meaning_label.add_theme_color_override("font_color", Style.MUTED)
	meaning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(meaning_label)
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
	_navigation = HBoxContainer.new()
	_navigation.name = "AgeWordPages"
	_navigation.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_navigation)
	previous_button = Button.new()
	previous_button.name = "AgeWordPrevious"
	previous_button.text = "Previous"
	UiClick.bind_button(previous_button)
	previous_button.pressed.connect(_change_page.bind(-1))
	_navigation.add_child(previous_button)
	page_label = Style.label("Page 1 of 1", 13)
	page_label.name = "AgeWordPage"
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_navigation.add_child(page_label)
	next_button = Button.new()
	next_button.name = "AgeWordNext"
	next_button.text = "Next"
	UiClick.bind_button(next_button)
	next_button.pressed.connect(_change_page.bind(1))
	_navigation.add_child(next_button)
	_update_navigation()


func configure(words: Array, band: Dictionary, palette: Dictionary, progress: Dictionary = {}) -> void:
	_build()
	var ordered: Array = words.duplicate(true)
	ordered.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_text: String = str(first.get("text", "")).to_lower()
		var second_text: String = str(second.get("text", "")).to_lower()
		return str(first.get("id", "")) < str(second.get("id", "")) if first_text == second_text else first_text.naturalnocasecmp_to(second_text) < 0)
	var words_changed: bool = ordered != _words or progress != _growth
	_growth = progress.duplicate(true)
	var band_changed: bool = str(band.get("id", "")) != str(_band.get("id", ""))
	_band = band.duplicate(true)
	_palette = palette.duplicate(true)
	title_label.text = str(_band.get("name", "All words"))
	count_label.text = "%d %s" % [ordered.size(), "word" if ordered.size() == 1 else "words"]
	if words_changed or band_changed:
		cancel_input()
	if words_changed:
		_words = ordered
		_word_indices.clear()
		for index in range(_words.size()):
			_word_indices[str(_words[index].id)] = index
	if words_changed or band_changed:
		_page_index = 0
		meaning_label.text = "Tap a word to hear it."
		_rebuild_words()
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
	# Keep only the current page's image resources alive.
	_textures.clear()
	for word: Dictionary in _words.slice(_page_index * PAGE_SIZE, (_page_index + 1) * PAGE_SIZE):
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
				button.set("accessibility_name", "Hear " + str(word.get("text", ""))
					+ (". " + str(word.meaning) if word.has("meaning") else "") + _practice_hint(word))
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
		WordArt.bind(picture.texture, picture)
		column.add_child(picture)
		picture.visible = picture.texture != null
		var caption := Style.label(str(word.get("display_text", word.get("text", ""))), 14)
		caption.name = "WordLabel"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_constant_override("line_spacing", 0)
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if picture.texture == null:
			column.alignment = BoxContainer.ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		column.add_child(caption)
		var streak: int = int(_growth.get("streaks", {}).get(id, 0))
		var mastered: bool = streak >= 6
		var progress_label := Style.label("Mastered" if mastered else "%d / 6" % streak, 12)
		progress_label.name = "WordMastery"
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress_label.add_theme_color_override("font_color", Style.GOOD if mastered else Style.MUTED)
		column.add_child(progress_label)
		button.set_meta("mastery_label", progress_label)
		button.set_meta("word_art", picture)
		button.set_meta("word_label", caption)
		button.set_meta("word_column", column)
		button.pressed.connect(_hear_word.bind(button))
		button.focus_entered.connect(ensure_control_visible.bind(button, true))
		word_buttons.append(button)
		_by_id[id] = button
	_styled_scale = -1.0
	_update_navigation()


func word_count() -> int:
	return _words.size()


func _page_count() -> int:
	return maxi(1, ceili(float(_words.size()) / PAGE_SIZE))


func _update_navigation() -> void:
	if previous_button == null:
		return
	previous_button.disabled = _page_index == 0
	next_button.disabled = _page_index >= _page_count() - 1
	page_label.text = "Page %d of %d" % [_page_index + 1, _page_count()]


func _change_page(direction: int) -> void:
	if not _can_interact():
		return
	var focus_previous: bool = previous_button.has_focus()
	var focus_next: bool = next_button.has_focus()
	_set_page(_page_index + direction)
	if focus_previous and previous_button.disabled and not next_button.disabled:
		next_button.grab_focus()
	elif focus_next and next_button.disabled and not previous_button.disabled:
		previous_button.grab_focus()


func _set_page(index: int) -> void:
	var next_page: int = clampi(index, 0, _page_count() - 1)
	if next_page == _page_index:
		return
	cancel_input()
	_page_index = next_page
	meaning_label.text = "Tap a word to hear it."
	_rebuild_words()
	scroll.scroll_vertical = 0
	_layout(false)


func _word_texture(source: String) -> Texture2D:
	if source.is_empty():
		return null
	var path: String = source if source.begins_with("res://") else "res://" + source
	if not _textures.has(path):
		_textures[path] = WordArt.texture(path)
	return _textures[path]


func _can_interact() -> bool:
	return is_visible_in_tree() and (not interaction_allowed.is_valid() or interaction_allowed.call())


func _hear_word(button: Button) -> void:
	if not _can_interact() or not is_instance_valid(button) or not word_buttons.has(button):
		return
	var word: Dictionary = button.get_meta("word")
	meaning_label.show()
	meaning_label.text = (str(word.get("display_text", word.text)).capitalize() + (": " + str(word.meaning) if word.has("meaning") else "")).trim_suffix(".") + _practice_hint(word)
	hear_requested.emit(word.duplicate(true))


func _practice_hint(word: Dictionary) -> String:
	return ". Practice in Phrase Builder." if str(word.get("image", "")).is_empty() and word.get("practice_modes", []) == ["phrase"] else ""


func cancel_input() -> void:
	if is_instance_valid(scroll):
		scroll.cancel_drag()


func focus_word(id: String) -> bool:
	if not _word_indices.has(id) or not _can_interact():
		return false
	_set_page(int(_word_indices[id]) / PAGE_SIZE)
	var button: Button = _by_id.get(id)
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
	if scroll == null or _navigation == null or size.x <= 0:
		return
	var scale: float = Style.ui_scale(self)
	var gap: int = ceili(8.0 / scale)
	var inset: int = ceili(3.0 / scale)
	add_theme_constant_override("separation", ceili(6.0 / scale))
	_heading.add_theme_constant_override("separation", ceili(12.0 / scale))
	_heading.custom_minimum_size.y = ceilf(30.0 / scale)
	title_label.add_theme_font_size_override("font_size", ceili(19.0 / scale))
	count_label.add_theme_font_size_override("font_size", ceili(13.0 / scale))
	meaning_label.add_theme_font_size_override("font_size", ceili(13.0 / scale))
	meaning_label.custom_minimum_size.y = ceilf(34.0 / scale)
	_navigation.add_theme_constant_override("separation", gap)
	page_label.add_theme_font_size_override("font_size", ceili(12.0 / scale))
	for edge in ["left", "right", "top", "bottom"]:
		_content.add_theme_constant_override("margin_" + edge, inset)
	var available: float = maxf(1.0, size.x - inset * 2.0)
	grid.columns = clampi(floori((available + gap) / (124.0 / scale + gap)), 1, 8)
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", gap)
	var accent: Color = _palette.get("accent", Style.GOOD)
	var restyle: bool = not is_equal_approx(_styled_scale, scale) or _styled_accent != accent
	for button: Button in [previous_button, next_button]:
		if restyle:
			var previous_focus: int = button.focus_mode
			Style.action_button(button, accent)
			button.focus_mode = previous_focus
		button.custom_minimum_size = Vector2(80.0, 48.0) / scale
		button.add_theme_font_size_override("font_size", ceili(13.0 / scale))
	for button: Button in word_buttons:
		if restyle:
			var previous_focus: int = button.focus_mode
			Style.action_button(button, accent)
			button.focus_mode = previous_focus
			button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Style.INK, ceili(12.0 / scale), maxi(2, ceili(2.0 / scale))))
		button.custom_minimum_size = Vector2(0, ceilf(146.0 / scale))
		var column: VBoxContainer = button.get_meta("word_column")
		column.offset_left = 8.0 / scale
		column.offset_right = -8.0 / scale
		column.offset_top = 8.0 / scale
		column.offset_bottom = -8.0 / scale
		column.add_theme_constant_override("separation", ceili(4.0 / scale))
		var progress_label: Label = button.get_meta("mastery_label")
		progress_label.add_theme_font_size_override("font_size", ceili(12 / scale))
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
	for word: Dictionary in _words:
		ids.append(str(word.id))
	var visible_ids: Array[String] = []
	for button: Button in word_buttons:
		visible_ids.append(str(button.get_meta("word_id")))
	return {"growth": _growth, "visible": is_visible_in_tree(), "age_band": str(_band.get("id", "")),
		"word_count": word_count(), "word_ids": ids, "visible_word_ids": visible_ids,
		"page": _page_index + 1, "page_count": _page_count(), "meaning": meaning_label.text,
		"columns": grid.columns if grid != null else 0,
		"scroll_offset": scroll.scroll_vertical if scroll != null else 0,
		"scroll_max": maxf(0.0, scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page) if scroll != null else 0.0}
