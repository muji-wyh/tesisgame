extends VBoxContainer
## Browse one already-resolved module. Only the selected term owns a picture.

signal hear_requested(word: Dictionary)

const Style = preload("res://scripts/ui_style.gd")
const WordArt = preload("res://scripts/word_art.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const SearchLineEdit = preload("res://scripts/search_line_edit.gd")
const PAGE_SIZE: int = 8
const MAX_TERMS: int = 50
const SKILLS: Array[String] = ["recognition", "listening", "spelling", "speaking", "context"]
const SKILL_TITLES: Dictionary = {"recognition": "Recognition", "listening": "Listening", "spelling": "Spelling", "speaking": "Speaking", "context": "Context"}

var scroll: ScrollContainer
var interaction_allowed: Callable
var _heading: Label
var _summary: Label
var _search: LineEdit
var _body: VBoxContainer
var _rows: GridContainer
var _pager: HBoxContainer
var _previous: Button
var _next: Button
var _page_label: Label
var _notice: Label
var _detail: VBoxContainer
var _picture: TextureRect
var _title: Label
var _part_of_speech: Label
var _definition: Label
var _example: Label
var _skills: Label
var _hear: Button
var _words: Array[Dictionary] = []
var _filtered: Array[int] = []
var _requirements: Dictionary = {}
var _session: Dictionary = {}
var _context: Dictionary = {}
var _selected: Dictionary = {}
var _page: int = 0
var _factor: float = 1.0
var _configured: bool = false
var _summary_base: String = "Open a prepared module to browse its terms."
var _keyboard_focus: bool = false
var _labels: Array[Label] = []
var _row_buttons: Array[Button] = []
var _fit_cache: Array = []
var _row_revision: int = 0
var _outer_scroll: ScrollContainer


func _init() -> void:
	name = "ProfessionalWordLibrary"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_heading = _label("Professional word library", 22, true)
	add_child(_heading)
	_summary = _label("Open a prepared module to browse its terms.", 14, false, true)
	add_child(_summary)
	_search = SearchLineEdit.new()
	_search.name = "ProfessionalWordSearch"
	_search.placeholder_text = "Search terms or definitions"
	_search.set("accessibility_name", "Search this professional module")
	_search.text_changed.connect(_filter)
	add_child(_search)
	scroll = ScrollContainer.new()
	scroll.name = "ProfessionalWordScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_notice = _label("", 14)
	_body.add_child(_notice)
	_rows = GridContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_rows)
	_pager = HBoxContainer.new()
	_body.add_child(_pager)
	_previous = _button("Previous", "PreviousWordPage", _change_page.bind(-1))
	_pager.add_child(_previous)
	_page_label = _label("", 13, false, true)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pager.add_child(_page_label)
	_next = _button("Next", "NextWordPage", _change_page.bind(1))
	_pager.add_child(_next)
	_detail = VBoxContainer.new()
	_detail.name = "ProfessionalWordDetail"
	_body.add_child(_detail)
	_picture = TextureRect.new()
	_picture.name = "ProfessionalWordPicture"
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(_picture)
	_title = _label("", 24, true)
	_detail.add_child(_title)
	_part_of_speech = _label("", 13, false, true)
	_detail.add_child(_part_of_speech)
	_definition = _label("", 16)
	_detail.add_child(_definition)
	_example = _label("", 15, false, true)
	_detail.add_child(_example)
	_hear = _button("Hear pronunciation", "HearProfessionalWord", _hear_selected)
	_detail.add_child(_hear)
	_detail.add_child(_label("Practice progress", 16, true))
	_skills = _label("", 14)
	_detail.add_child(_skills)
	resized.connect(func() -> void: fit(_factor))
	visibility_changed.connect(_visibility_changed)
	clear()
	fit(1.0)


func configure(content: Dictionary, session: Dictionary) -> void:
	clear()
	_session = session.duplicate(true)
	if not content.get("ok", false) or content.get("context", {}).get("track") != "professional":
		_summary.text = "Open a prepared professional module to browse its terms."
		return
	var supplied: Variant = content.get("module_words", content.get("words", []))
	if not supplied is Array or supplied.is_empty() or supplied.size() > MAX_TERMS:
		_summary.text = "This module's word library is unavailable."
		return
	var seen: Dictionary = {}
	for word in supplied:
		if not word is Dictionary or not word.get("id") is String or seen.has(word.id) \
			or not word.get("text") is String or not word.get("definition") is String or not word.get("example") is String:
			clear()
			_summary.text = "This module's word library is unavailable."
			return
		seen[word.id] = true
		_words.append(word.duplicate(true))
	_words.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_text: String = str(left.get("display_text", left.text)).to_lower()
		var right_text: String = str(right.get("display_text", right.text)).to_lower()
		return str(left.id) < str(right.id) if left_text == right_text else left_text < right_text)
	_context = content.context.duplicate(true)
	for term in content.get("requirements", {}).get("terms", []):
		_requirements[str(term.sense_id)] = term.skills.duplicate()
	_configured = true
	_heading.text = str(content.get("course_title", "Professional English"))
	_summary_base = "%s · %d terms" % [content.get("module_title", _context.module_id), _words.size()]
	_refresh_progress()
	_search.editable = true
	_filter("")


func embed_in(outer: ScrollContainer) -> void:
	_outer_scroll = outer
	# The whole vocabulary page has one scroll surface on small screens.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_heading.hide()
	_summary.hide()


func set_progress(session: Dictionary) -> void:
	if _session == session:
		return
	_session = session.duplicate(true)
	if _configured:
		_refresh_progress()


func _refresh_progress() -> void:
	_summary.text = _summary_base
	if not _progress_available():
		_summary.text += "\nProgress unavailable."
	if not _selected.is_empty():
		_skills.text = _skill_summary(str(_selected.id))


func clear() -> void:
	# The host must stop pronunciation too, before releasing this module's lease.
	_picture.texture = null
	_selected.clear()
	_words.clear()
	_filtered.clear()
	_requirements.clear()
	_session.clear()
	_context.clear()
	_clear_rows()
	_configured = false
	_page = 0
	_search.text = ""
	_search.editable = false
	_heading.text = "Professional word library"
	_summary.text = "Open a prepared module to browse its terms."
	_summary_base = _summary.text
	_notice.text = ""
	_notice.hide()
	_detail.hide()
	_pager.hide()
	_hear.disabled = true
	_title.text = ""
	_part_of_speech.text = ""
	_definition.text = ""
	_example.text = ""
	_skills.text = ""
	_page_label.text = ""
	scroll.scroll_vertical = 0


func fit(scale: float) -> void:
	_factor = maxf(0.1, scale)
	var wide: bool = size.x * _factor >= 800.0
	var next_fit: Array = [_factor, wide, _row_revision, _keyboard_focus]
	if _fit_cache == next_fit:
		return
	_fit_cache = next_fit
	_rows.columns = 2 if wide else 1
	for container in [self, _body, _rows, _pager, _detail]:
		container.add_theme_constant_override("separation", ceili(10.0 / _factor))
		container.add_theme_constant_override("h_separation", ceili(10.0 / _factor))
		container.add_theme_constant_override("v_separation", ceili(10.0 / _factor))
	for label in _labels:
		if is_instance_valid(label):
			label.add_theme_font_size_override("font_size", ceili(float(label.get_meta("font_size", 14)) / _factor))
	for button in _row_buttons + [_previous, _next, _hear]:
		Style.action_button(button, Style.GOOD, button == _hear)
		button.add_theme_font_size_override("font_size", ceili(14.0 / _factor))
		button.custom_minimum_size = Vector2(0, 48.0 / _factor)
		if not _keyboard_focus:
			button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if button.has_meta("content"):
			var content: MarginContainer = button.get_meta("content")
			for edge in ["left", "right", "top", "bottom"]:
				content.add_theme_constant_override("margin_" + edge, ceili(10.0 / _factor))
			button.custom_minimum_size.y = maxf(64.0 / _factor, content.get_combined_minimum_size().y)
	Style.text_field(_search, _factor, _keyboard_focus)
	scroll.custom_minimum_size.y = 120.0 / _factor
	_picture.custom_minimum_size.y = 150.0 / _factor


func controls() -> Array[Control]:
	var result: Array[Control] = []
	if _search.is_visible_in_tree() and _search.editable:
		result.append(_search)
	for button in _row_buttons + [_previous, _next, _hear]:
		if button.is_visible_in_tree() and not button.disabled:
			result.append(button)
	return result


func snapshot() -> Dictionary:
	return {"configured": _configured, "context": _context.duplicate(true), "term_count": _words.size(),
		"filtered_count": _filtered.size(), "visible_rows": _row_buttons.size(), "page": _page,
		"selected_id": _selected.get("id", ""), "image_count": int(_picture.texture != null),
		"progress_available": _progress_available(), "skills_text": _skills.text,
		"definition": _definition.text, "example": _example.text, "columns": _rows.columns}


func _filter(value: String) -> void:
	_filtered.clear()
	var terms: PackedStringArray = value.strip_edges().to_lower().split(" ", false)
	for index in range(_words.size()):
		var word: Dictionary = _words[index]
		var text: String = " ".join([word.get("display_text", word.text), word.text, word.definition, word.example, word.get("pos", "")]).to_lower()
		if terms.is_empty() or Array(terms).all(func(term: String) -> bool: return text.contains(term)):
			_filtered.append(index)
	_page = 0
	_show_page()
	if _filtered.is_empty():
		_picture.texture = null
		_selected.clear()
		_detail.hide()
		_hear.disabled = true
	else:
		_select(_filtered[0], false)
	scroll.scroll_vertical = 0


func _change_page(direction: int) -> void:
	if not _can_interact():
		return
	_page = clampi(_page + direction, 0, maxi(0, ceili(float(_filtered.size()) / PAGE_SIZE) - 1))
	_show_page()
	scroll.scroll_vertical = 0


func _show_page() -> void:
	_clear_rows()
	var start: int = _page * PAGE_SIZE
	var end: int = mini(_filtered.size(), start + PAGE_SIZE)
	for offset in range(start, end):
		var index: int = _filtered[offset]
		var word: Dictionary = _words[index]
		var button: Button = _button("", "ProfessionalTerm_" + str(index), _select.bind(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set("accessibility_name", "%s. %s. %s" % [word.get("display_text", word.text), word.get("pos", ""), word.definition])
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.set_meta("content", margin)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(content)
		var heading := HBoxContainer.new()
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(heading)
		heading.add_child(_label(str(word.get("display_text", word.text)), 16, true))
		var part_of_speech := _label(str(word.get("pos", "")), 13, false, true)
		part_of_speech.autowrap_mode = TextServer.AUTOWRAP_OFF
		part_of_speech.size_flags_horizontal = Control.SIZE_SHRINK_END
		heading.add_child(part_of_speech)
		content.add_child(_label(word.definition, 14, false, true))
		margin.minimum_size_changed.connect(func() -> void:
			if is_instance_valid(button):
				button.custom_minimum_size.y = maxf(64.0 / _factor, margin.get_combined_minimum_size().y))
		_rows.add_child(button)
		_row_buttons.append(button)
	_notice.visible = _filtered.is_empty()
	_notice.text = "No terms match your search."
	_pager.visible = not _filtered.is_empty()
	_page_label.text = "%d–%d of %d" % [start + 1, end, _filtered.size()]
	_previous.disabled = _page == 0
	_next.disabled = end >= _filtered.size()
	fit(_factor)


func _select(index: int, reveal: bool = true) -> void:
	if index < 0 or index >= _words.size() or not _configured or (reveal and not _can_interact()):
		return
	_picture.texture = null
	_selected = _words[index].duplicate(true)
	var path: String = str(_selected.get("image", ""))
	if not path.is_empty():
		_picture.texture = WordArt.texture(path, _picture)
	_picture.visible = _picture.texture != null
	_title.text = str(_selected.get("display_text", _selected.text))
	_part_of_speech.text = str(_selected.get("pos", ""))
	_part_of_speech.visible = not _part_of_speech.text.is_empty()
	_definition.text = str(_selected.definition)
	_example.text = "Example: " + str(_selected.example)
	_skills.text = _skill_summary(str(_selected.id))
	_hear.disabled = str(_selected.get("audio", "")).is_empty()
	_detail.show()
	if reveal:
		_reveal_detail.call_deferred()


func _reveal_detail() -> void:
	if not _configured or not _detail.is_visible_in_tree():
		return
	if is_instance_valid(_outer_scroll):
		_outer_scroll.scroll_vertical += floori(_detail.global_position.y - _outer_scroll.global_position.y)
		return
	# A detail can exceed a phone's scroll window. Reveal its picture first;
	# aligning the entire panel would move the illustration above the viewport.
	scroll.scroll_vertical = maxi(0, floori(_detail.position.y))


func _skill_summary(id: String) -> String:
	if not _requirements.has(id):
		return "Assessment details unavailable."
	var lines: PackedStringArray = []
	for skill in SKILLS:
		var status: String = "Not assessed here"
		if _requirements[id].has(skill):
			if not _progress_available():
				status = "Progress unavailable"
			else:
				var evidence: Dictionary = _session.progress.get("skills", {}).get(id, {}).get(skill, {})
				status = "Mastered" if evidence.get("earned", false) else "%d / 3 correct in a row" % int(evidence.get("streak", 0))
		lines.append(str(SKILL_TITLES[skill]) + ": " + status)
	return "\n".join(lines)


func _progress_available() -> bool:
	return _session.get("progress_loaded", false) and not _session.get("blocked", false) and _session.get("progress") is Dictionary


func _hear_selected() -> void:
	if _can_interact() and not _selected.is_empty() and not _hear.disabled:
		hear_requested.emit(_selected.duplicate(true))


func _can_interact() -> bool:
	return _configured and is_visible_in_tree() and (not interaction_allowed.is_valid() or interaction_allowed.call())


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		clear()


func _input(event: InputEvent) -> void:
	var keyboard: bool = _keyboard_focus
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		keyboard = false
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		keyboard = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		keyboard = true
	if keyboard != _keyboard_focus:
		_keyboard_focus = keyboard
		fit(_factor)


func _clear_rows() -> void:
	for button in _row_buttons:
		var callback: Callable = button.get_meta("action")
		if button.pressed.is_connected(callback):
			button.pressed.disconnect(callback)
		for label in button.find_children("*", "Label", true, false):
			_labels.erase(label)
		_rows.remove_child(button)
		button.queue_free()
	_row_buttons.clear()
	_row_revision += 1


func _label(text: String, font_size: int, heading: bool = false, muted: bool = false) -> Label:
	var label := Style.heading(text, font_size) if heading else Style.label(text, font_size)
	if muted:
		label.add_theme_color_override("font_color", Style.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("font_size", font_size)
	_labels.append(label)
	return label


func _button(text: String, node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	button.set_meta("action", callback)
	UiClick.bind_button(button)
	return button
