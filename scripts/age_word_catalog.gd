extends VBoxContainer
const WordArt = preload("res://scripts/word_art.gd")
## Browse the supplied age-eligible vocabulary without changing lesson progress.

signal hear_requested(word: Dictionary)
signal retry_requested

const Style = preload("res://scripts/ui_style.gd")
const ResultScroll = preload("res://scripts/result_scroll.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const GrowthState = preload("res://scripts/growth_state.gd")
const MASTERY_MEDAL = preload("res://assets/images/ui/mastery-medal.webp")
const MASTERY_PAPER := Color("#fff0be")
const MASTERY_GOLD := Color("#c9952b")
const MASTERY_INK := Color("#6b4819")

var scroll: ResultScroll
var grid: GridContainer
var word_buttons: Array[Button] = []
var title_label: Label
var count_label: Label
var meaning_label: Label
var retry_button: Button
var interaction_allowed: Callable

var _heading: HBoxContainer
var _content: MarginContainer
var _words: Array = []
var _band: Dictionary = {}
var _palette: Dictionary = {}
var _textures: Dictionary = {}
var _by_id: Dictionary = {}
var _word_indices: Dictionary = {}
var _growth: Dictionary = {}
var _styled_scale: float = -1.0
var _styled_accent: Color = Color.TRANSPARENT
var _loading_state: Dictionary = {}
var _loading_word_count: int = 0
var _loading_box: VBoxContainer
var _loading_label: Label
var _loading_progress: ProgressBar
var _art_sync_queued: bool = false


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
	title_label = Style.heading("All words", 22)
	title_label.name = "AgeWordTitle"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	_heading.add_child(title_label)
	count_label = Style.label("0 words", 13)
	count_label.name = "AgeWordCount"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_color_override("font_color", Style.MUTED)
	_heading.add_child(count_label)
	meaning_label = Style.label("Tap a word to hear it.", 14)
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
	scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _queue_visible_art())
	grid.sort_children.connect(_queue_visible_art)
	_loading_box = VBoxContainer.new()
	_loading_box.name = "AgeVocabularyLoading"
	_loading_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_loading_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_loading_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_box.hide()
	add_child(_loading_box)
	_loading_label = Style.label("", 16)
	_loading_label.name = "AgeVocabularyStatus"
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_box.add_child(_loading_label)
	_loading_progress = ProgressBar.new()
	_loading_progress.name = "AgeVocabularyProgress"
	_loading_progress.max_value = 1.0
	_loading_progress.step = 0.001
	_loading_progress.show_percentage = true
	_loading_progress.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_loading_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_box.add_child(_loading_progress)
	retry_button = Button.new()
	retry_button.name = "AgeVocabularyRetry"
	retry_button.text = "Try again"
	retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiClick.bind_button(retry_button)
	retry_button.pressed.connect(func() -> void:
		if _can_interact() and _loading_state.get("state", "") == "failed":
			retry_requested.emit())
	_loading_box.add_child(retry_button)


func configure(words: Array, band: Dictionary, palette: Dictionary, progress: Dictionary = {}) -> void:
	_build()
	_loading_state.clear()
	_loading_box.hide()
	scroll.show()
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
		meaning_label.text = "Tap a word to hear it."
		_rebuild_words()
		scroll.scroll_vertical = 0
	# Refreshing identical data must not jump back to a card the player focused
	# before scrolling elsewhere. Geometry changes handle their own focus reveal.
	_layout(false)


func show_loading(band: Dictionary, word_count: int, state: Dictionary, palette: Dictionary = {}) -> void:
	_build()
	cancel_input()
	_band = band.duplicate(true)
	_palette = palette.duplicate(true)
	_loading_state = state.duplicate(true)
	_loading_word_count = maxi(0, word_count)
	_words.clear()
	_word_indices.clear()
	_growth.clear()
	_clear_word_buttons()
	title_label.text = str(_band.get("name", "All words"))
	count_label.text = "%d %s" % [_loading_word_count, "word" if _loading_word_count == 1 else "words"]
	meaning_label.text = "Pictures and voices will be ready together."
	var failed: bool = _loading_state.get("state", "") == "failed"
	_loading_label.text = str(_loading_state.get("error", "These words could not be loaded. Please try again.")) if failed else "Getting these words ready..."
	if _loading_label.text.is_empty():
		_loading_label.text = "These words could not be loaded. Please try again." if failed else "Getting these words ready..."
	_loading_progress.value = clampf(float(_loading_state.get("progress", 0.0)), 0.0, 1.0)
	_loading_progress.visible = not failed
	retry_button.visible = failed
	retry_button.disabled = not failed
	scroll.hide()
	_loading_box.show()
	_layout(false)


func _clear_word_buttons() -> void:
	for button: Button in word_buttons:
		grid.remove_child(button)
		button.queue_free()
	word_buttons.clear()
	_by_id.clear()
	_textures.clear()


func _rebuild_words() -> void:
	# Stable controls keep every word reachable by scrolling or keyboard focus.
	_clear_word_buttons()
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
		var streak: int = int(_growth.get("streaks", {}).get(id, 0))
		var mastered: bool = streak >= GrowthState.MASTERY_STREAK
		var accessible_name: String = ("Hear " + str(word.get("text", ""))
			+ (". " + str(word.meaning) if word.has("meaning") else "") + _practice_hint(word)).trim_suffix(".")
		accessible_name += ". Mastered." if mastered else ". %d of %d correct in a row." % [streak, GrowthState.MASTERY_STREAK]
		for property: Dictionary in button.get_property_list():
			if property.name == "accessibility_name":
				button.set("accessibility_name", accessible_name)
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
		picture.set_meta("source", str(word.get("image", "")))
		column.add_child(picture)
		picture.visible = not str(word.get("image", "")).is_empty()
		var caption := Style.heading(str(word.get("display_text", word.get("text", ""))), 14)
		caption.name = "WordLabel"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_constant_override("line_spacing", 0)
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not picture.visible:
			column.alignment = BoxContainer.ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		column.add_child(caption)
		button.set_meta("mastered", mastered)
		var progress_label := Style.label("Mastered" if mastered else "%d / %d" % [streak, GrowthState.MASTERY_STREAK], 12)
		progress_label.name = "WordMastery"
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		progress_label.add_theme_color_override("font_color", MASTERY_INK if mastered else Style.MUTED)
		if mastered:
			progress_label.add_theme_font_override("font", Style.HEADING_FONT)
		column.add_child(progress_label)
		var medal := TextureRect.new()
		medal.name = "WordMasteryMedal"
		medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		medal.texture = MASTERY_MEDAL
		medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		medal.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		medal.visible = mastered
		button.add_child(medal)
		button.set_meta("mastery_badge", medal)
		button.set_meta("mastery_label", progress_label)
		button.set_meta("word_art", picture)
		button.set_meta("word_label", caption)
		button.set_meta("word_column", column)
		button.pressed.connect(_hear_word.bind(button))
		button.focus_entered.connect(ensure_control_visible.bind(button, true))
		word_buttons.append(button)
		_by_id[id] = button
	_styled_scale = -1.0


func word_count() -> int:
	return _words.size() if _loading_state.is_empty() else _loading_word_count


func _queue_visible_art() -> void:
	if _art_sync_queued:
		return
	_art_sync_queued = true
	_flush_visible_art.call_deferred()


func _flush_visible_art() -> void:
	_art_sync_queued = false
	_sync_visible_art()


func _sync_visible_art() -> void:
	if scroll == null or word_buttons.is_empty() or not is_visible_in_tree():
		return
	# New cards briefly share the origin before GridContainer lays out its rows.
	if word_buttons.size() > grid.columns and word_buttons.back().position.y <= word_buttons.front().position.y:
		return
	# Prefetch one row above and below the viewport while releasing distant art.
	# Cards retain their geometry and focus even when their textures are unloaded.
	var scale: float = Style.ui_scale(self)
	var nearby: Rect2 = scroll.get_global_rect().grow_individual(0, 154.0 / scale, 0, 154.0 / scale)
	var retained: Dictionary = {}
	for button: Button in word_buttons:
		var picture: TextureRect = button.get_meta("word_art")
		var source: String = str(picture.get_meta("source", ""))
		if source.is_empty():
			continue
		if not nearby.intersects(button.get_global_rect()):
			picture.texture = null
			continue
		var path: String = source if source.begins_with("res://") else "res://" + source
		var texture: Texture2D = _word_texture(path)
		picture.texture = texture
		WordArt.bind(texture, picture)
		retained[path] = texture
	_textures = retained


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
	meaning_label.add_theme_font_size_override("font_size", ceili(14.0 / scale))
	meaning_label.custom_minimum_size.y = ceilf(34.0 / scale)
	for edge in ["left", "right", "top", "bottom"]:
		_content.add_theme_constant_override("margin_" + edge, inset)
	var available: float = maxf(1.0, size.x - inset * 2.0)
	grid.columns = clampi(floori((available + gap) / (124.0 / scale + gap)), 1, 8)
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", gap)
	var accent: Color = _palette.get("accent", Style.GOOD)
	var restyle: bool = not is_equal_approx(_styled_scale, scale) or _styled_accent != accent
	_loading_box.add_theme_constant_override("separation", ceili(16.0 / scale))
	_loading_label.add_theme_font_size_override("font_size", ceili(16.0 / scale))
	_loading_progress.custom_minimum_size = Vector2(minf(280.0 / scale, available), 26.0 / scale)
	_loading_progress.add_theme_stylebox_override("background", Style.box(Style.EDGE, Color.TRANSPARENT, ceili(8.0 / scale), 0))
	_loading_progress.add_theme_stylebox_override("fill", Style.box(accent, Color.TRANSPARENT, ceili(8.0 / scale), 0))
	_loading_progress.add_theme_font_size_override("font_size", ceili(12.0 / scale))
	if restyle:
		Style.action_button(retry_button, accent)
	retry_button.custom_minimum_size = Vector2(128.0, 48.0) / scale
	retry_button.add_theme_font_size_override("font_size", ceili(14.0 / scale))
	for button: Button in word_buttons:
		var mastered: bool = bool(button.get_meta("mastered", false))
		if restyle:
			var previous_focus: int = button.focus_mode
			Style.action_button(button, accent)
			button.focus_mode = previous_focus
			if mastered:
				_style_mastered_card(button, scale)
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
		if restyle and mastered:
			var mastery_pill := Style.box(Color("#ffdc78"), Color.TRANSPARENT, ceili(7.0 / scale), 0)
			mastery_pill.content_margin_left = 9.0 / scale
			mastery_pill.content_margin_right = 9.0 / scale
			mastery_pill.content_margin_top = 0.0
			mastery_pill.content_margin_bottom = 0.0
			progress_label.add_theme_stylebox_override("normal", mastery_pill)
		var medal: TextureRect = button.get_meta("mastery_badge")
		medal.offset_left = -40.0 / scale
		medal.offset_right = -6.0 / scale
		medal.offset_top = 6.0 / scale
		medal.offset_bottom = 40.0 / scale
		var picture: TextureRect = button.get_meta("word_art")
		picture.custom_minimum_size.y = ceilf(70.0 / scale)
		var caption: Label = button.get_meta("word_label")
		caption.custom_minimum_size.y = ceilf(34.0 / scale)
		caption.add_theme_font_size_override("font_size", ceili(14.0 / scale))
		if restyle and mastered:
			caption.add_theme_font_override("font", Style.HEADING_FONT)
			caption.add_theme_color_override("font_color", MASTERY_INK)
	_styled_scale = scale
	_styled_accent = accent
	_queue_visible_art()
	if reveal_focus:
		_reveal_focused_word.call_deferred()


func _style_mastered_card(button: Button, scale: float) -> void:
	# Warm gold distinguishes mastered cards without competing idle animations.
	for state: String in ["normal", "hover", "pressed"]:
		var fill: Color = MASTERY_PAPER
		if state == "hover":
			fill = Color("#ffe7a0")
		elif state == "pressed":
			fill = Color("#ffdc83")
		var surface := Style.box(fill, MASTERY_GOLD, ceili(12.0 / scale), maxi(2, ceili(2.0 / scale)))
		surface.border_width_bottom = maxi(3, ceili(4.0 / scale))
		surface.content_margin_left = 12.0 / scale
		surface.content_margin_right = 12.0 / scale
		surface.content_margin_top = 6.0 / scale
		surface.content_margin_bottom = 6.0 / scale
		button.add_theme_stylebox_override(state, surface)


func snapshot() -> Dictionary:
	var ids: Array[String] = []
	for word: Dictionary in _words:
		ids.append(str(word.id))
	var visible_ids: Array[String] = []
	var mastered_ids: Array[String] = []
	for button: Button in word_buttons:
		visible_ids.append(str(button.get_meta("word_id")))
		if bool(button.get_meta("mastered", false)):
			mastered_ids.append(str(button.get_meta("word_id")))
	return {"growth": _growth, "loading": _loading_state.duplicate(true),
		"loading_state": str(_loading_state.get("state", "ready")), "loading_progress": float(_loading_state.get("progress", 1.0)),
		"visible": is_visible_in_tree(), "age_band": str(_band.get("id", "")),
		"word_count": word_count(), "word_ids": ids, "visible_word_ids": visible_ids, "mastered_word_ids": mastered_ids,
		"loaded_image_count": _textures.size(), "meaning": meaning_label.text if meaning_label != null else "",
		"columns": grid.columns if grid != null else 0,
		"scroll_offset": scroll.scroll_vertical if scroll != null else 0,
		"scroll_max": maxf(0.0, scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page) if scroll != null else 0.0}
