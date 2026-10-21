extends VBoxContainer
## Course browsing reads metadata only. Gameplay readiness remains the resolver's responsibility.

signal context_selected(context: Dictionary)
signal continue_requested(context: Dictionary)
signal retry_requested
signal cancel_requested
signal browsing_changed(screen: String)
signal course_selected(course_id: String)

const Style = preload("res://scripts/ui_style.gd")
const Context = preload("res://scripts/learning_context.gd")
const Progress = preload("res://scripts/professional_progress.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const ThemeArt = preload("res://scripts/learning_theme_art.gd")
const SearchLineEdit = preload("res://scripts/search_line_edit.gd")
const BABY_PIP = preload("res://assets/images/mascots/growth/pip-baby.png")
const RETAIL_PREVIEW = preload("res://assets/images/professional-previews/retail.png")
const SOFTWARE_PREVIEW = preload("res://assets/images/professional-previews/software-data.png")

var _catalog: RefCounted
var _selection: Dictionary = {}
var _course: Dictionary = {}
var _progress: Dictionary = {}
var _screen: String = "paths"
var _last_screen: String = ""
var _keyboard_focus_visible: bool = false
var _fit_cache: Array = []
var _style_revision: int = 0
var _factor: float = 1.0
var _wide: bool = true
var _busy: bool = false
var _retry: bool = false
var _status_text: String = ""
var _heading: Label
var _active: Label
var _compact_path: Label
var _navigation: HFlowContainer
var _change_path: Button
var _change_career: Button
var _change_module: Button
var _paths: GridContainer
var _growth_button: Button
var _professional_button: Button
var _search: LineEdit
var _list: GridContainer
var _empty: Label
var _detail: Label
var _status: Label
var _actions: HFlowContainer
var _continue: Button
var _retry_button: Button
var _cancel: Button
var _labels: Array[Label] = []
var _buttons: Array[Button] = []
var _rows: Array[Dictionary] = []
var _path_pictures: Array[TextureRect] = []
var _career_pictures: Array[Control] = []
var _search_word_pattern := RegEx.create_from_string("[a-z0-9]+")


func _init() -> void:
	name = "LearningPathSelector"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading = _label("Choose your learning path", 22)
	_heading.add_theme_font_override("font", Style.HEADING_FONT)
	add_child(_heading)
	_active = _label("", 15)
	_active.add_theme_color_override("font_color", Style.MUTED)
	add_child(_active)
	_navigation = HFlowContainer.new()
	add_child(_navigation)
	_compact_path = _label("Everyday English", 15)
	_compact_path.add_theme_font_override("font", Style.HEADING_FONT)
	# This short label shares a flow row with the path action. A wrapping label
	# has no intrinsic width and can make that row much taller than its viewport.
	_compact_path.autowrap_mode = TextServer.AUTOWRAP_OFF
	_compact_path.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_navigation.add_child(_compact_path)
	_change_path = _button("Change path", "ChangeLearningPath", _show_paths)
	_change_path.set("accessibility_name", "Change learning path")
	_navigation.add_child(_change_path)
	_change_career = _button("Careers", "ChangeCareer", _show_courses)
	_change_career.set("accessibility_name", "Choose another career")
	_navigation.add_child(_change_career)
	_change_module = _button("Modules", "ChangeModule", _show_modules)
	_change_module.set("accessibility_name", "Choose another module")
	_navigation.add_child(_change_module)
	_paths = GridContainer.new()
	add_child(_paths)
	_growth_button = _choice("Grow with Pip", "Build everyday English, one step at a time.", "GrowthPath", _choose_growth)
	_paths.add_child(_growth_button)
	var pip_portrait := AtlasTexture.new()
	pip_portrait.atlas = BABY_PIP
	pip_portrait.region = Rect2(0, 0, BABY_PIP.get_height(), BABY_PIP.get_height())
	_illustrate_path(_growth_button, [pip_portrait])
	_professional_button = _choice("Professional English", "Practice English for your working world.", "ProfessionalPath", _show_courses)
	_paths.add_child(_professional_button)
	_illustrate_path(_professional_button, [RETAIL_PREVIEW, SOFTWARE_PREVIEW])
	_search = SearchLineEdit.new()
	_search.name = "CareerSearch"
	_search.placeholder_text = "Search careers or workplace skills"
	_search.set("accessibility_name", "Search professional careers")
	_search.text_changed.connect(_filter_courses)
	add_child(_search)
	_list = GridContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)
	_empty = _label("", 14)
	add_child(_empty)
	_detail = _label("", 14)
	add_child(_detail)
	_status = _label("", 14)
	_status.name = "LearningPathStatus"
	add_child(_status)
	_actions = HFlowContainer.new()
	add_child(_actions)
	_continue = _button("Continue", "ContinueLearningPath", _continue_selection)
	_actions.add_child(_continue)
	_retry_button = _button("Retry", "RetryLearningPath", func() -> void: retry_requested.emit())
	_actions.add_child(_retry_button)
	_cancel = _button("Cancel", "CancelLearningPath", func() -> void: cancel_requested.emit())
	_actions.add_child(_cancel)
	_refresh()


func configure(catalog: RefCounted) -> void:
	_catalog = catalog
	if _screen == "courses":
		_build_courses()
	_refresh()


func set_selection(context: Dictionary) -> void:
	_selection = Context.freeze(context).duplicate(true)
	_course = {}
	if _selection.get("track") == "professional" and _catalog != null:
		_course = _catalog.course(str(_selection.course_id))
	_screen = "summary" if not _selection.is_empty() else "paths"
	_clear_rows()
	_refresh()


func set_progress(session_snapshot: Dictionary) -> void:
	if _progress == session_snapshot:
		return
	_progress = session_snapshot.duplicate(true)
	if _screen == "modules":
		_build_modules()
	elif _screen == "courses":
		_build_courses()
	_refresh()


func set_status(message: String, busy: bool = false, retry: bool = false) -> void:
	if _status_text == message and _busy == busy and _retry == retry:
		return
	_status_text = message
	_busy = busy
	_retry = retry
	_refresh()


func fit(factor: float, wide: bool) -> void:
	_factor = maxf(0.1, factor)
	_wide = wide
	var next_fit: Array = [_factor, _wide, _keyboard_focus_visible, _style_revision]
	if next_fit == _fit_cache:
		return
	_fit_cache = next_fit
	_paths.columns = 2 if wide else 1
	_list.columns = 2 if wide else 1
	for picture in _path_pictures:
		picture.custom_minimum_size.y = (156.0 if wide else 128.0) / _factor
	for picture in _career_pictures:
		picture.custom_minimum_size.y = 96.0 / _factor
	for container in [self, _paths, _list, _navigation, _actions]:
		container.add_theme_constant_override("separation", ceili(10.0 / _factor))
		container.add_theme_constant_override("h_separation", ceili(10.0 / _factor))
		container.add_theme_constant_override("v_separation", ceili(10.0 / _factor))
	_navigation.add_theme_constant_override("h_separation", ceili(6.0 / _factor))
	_compact_path.custom_minimum_size.y = 44.0 / _factor
	for label in _labels:
		if is_instance_valid(label):
			label.add_theme_font_size_override("font_size", ceili(float(label.get_meta("font_size", 14)) / _factor))
	for button in _buttons:
		if not is_instance_valid(button):
			continue
		if button in [_change_path, _change_career, _change_module, _cancel]:
			Style.quiet_button(button, Style.GOOD, 0)
		else:
			Style.action_button(button, Style.GOOD, button == _continue)
		if not _keyboard_focus_visible:
			button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.custom_minimum_size = Vector2(0, (90.0 if button.has_meta("choice") else 44.0) / _factor)
		button.add_theme_font_size_override("font_size", ceili(14.0 / _factor))
		if button.has_meta("choice"):
			var content: MarginContainer = button.get_meta("choice")
			var is_path: bool = button.has_meta("path_choice")
			for edge in ["left", "right", "top", "bottom"]:
				content.add_theme_constant_override("margin_" + edge, ceili((20.0 if wide and is_path else 16.0 if is_path else 14.0) / _factor))
			content.get_child(0).add_theme_constant_override("separation", ceili((10.0 if is_path else 6.0) / _factor))
			button.custom_minimum_size.y = maxf(90.0 / _factor, content.get_combined_minimum_size().y)
			if is_path:
				_style_path_card(button)
		else:
			for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
				var surface: StyleBox = button.get_theme_stylebox(state)
				surface.content_margin_left = 10.0 / _factor
				surface.content_margin_right = 10.0 / _factor
	Style.text_field(_search, _factor, _keyboard_focus_visible)
	queue_sort()


func _style_path_card(button: Button) -> void:
	var tint: Color = Color("#edf2e7") if button == _growth_button else Color("#eeedf5")
	var radius: int = ceili(20.0 / _factor)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = tint.lightened(0.15) if state == "normal" else tint if state == "hover" else tint.darkened(0.02)
		var surface := Style.box(fill, Style.EDGE if state in ["normal", "disabled"] else Style.GOOD, radius, maxi(1, ceili(1.0 / _factor)))
		surface.set_content_margin_all(0)
		button.add_theme_stylebox_override(state, surface)


func _input(event: InputEvent) -> void:
	var keyboard_focus: bool = _keyboard_focus_visible
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		keyboard_focus = false
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		keyboard_focus = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		keyboard_focus = true
	if keyboard_focus != _keyboard_focus_visible:
		_keyboard_focus_visible = keyboard_focus
		fit(_factor, _wide)


func controls() -> Array[Control]:
	var result: Array[Control] = []
	for button in _buttons:
		if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
			result.append(button)
	if _search.is_visible_in_tree() and _search.editable:
		result.append(_search)
	return result


func snapshot() -> Dictionary:
	return {"screen": _screen, "selection": _selection.duplicate(true), "course_id": _course.get("id", ""),
		"visible_rows": _rows.filter(func(row: Dictionary) -> bool: return row.button.visible).size(),
		"columns": _list.columns, "busy": _busy, "retry": _retry, "status": _status.text,
		"continue_enabled": _continue.visible and not _continue.disabled,
		"active_text": _heading.text + "\n" + _active.text if _screen == "summary" else _active.text}


func _show_paths() -> void:
	if _busy:
		return
	_screen = "paths"
	_clear_rows()
	_refresh()


func _show_courses() -> void:
	if _busy:
		return
	_screen = "courses"
	_search.text = ""
	_build_courses()
	_refresh()


func _show_modules() -> void:
	if _busy or _course.is_empty():
		return
	_screen = "modules"
	_build_modules()
	_refresh()


func _choose_growth() -> void:
	if _busy:
		return
	set_selection(Context.growth(3, "match"))
	context_selected.emit(_selection.duplicate(true))


func _choose_course(id: String) -> void:
	if _busy or _catalog == null:
		return
	_course = _catalog.course(id)
	if _course.is_empty():
		set_status(str(_catalog.error), false, true)
		return
	course_selected.emit(id)
	_screen = "modules"
	_build_modules()
	_refresh()


func _choose_module(id: String) -> void:
	if _busy or _course.is_empty():
		return
	var context: Dictionary = Context.professional(str(_course.id), id,
		str(_course.curriculum_revision), str(_selection.get("mode", "match")))
	set_selection(context)
	context_selected.emit(_selection.duplicate(true))


func _continue_selection() -> void:
	if not _busy and not _selection.is_empty() and _selected_ready():
		continue_requested.emit(_selection.duplicate(true))


func _build_courses() -> void:
	_clear_rows()
	if _catalog == null:
		return
	for course in _catalog.courses():
		var description: String = str(course.get("description", ""))
		var copy: String = description + "\n500 terms · 100 expressions · 10 modules"
		copy += "\n" + _course_progress(str(course.id))
		var profile: Dictionary = _catalog.theme_profile(str(course.get("theme_id", "")))
		if profile.get("status") != "ready":
			copy += "\nCourse in preparation"
		var button: Button = _choice(str(course.title), copy, "Career_" + str(course.id), _choose_course.bind(str(course.id)))
		_list.add_child(button)
		_illustrate_career(button, profile)
		var searchable: String = " ".join([str(course.title), description, " ".join(course.get("workflows", []))]).to_lower()
		_rows.append({"id": course.id, "button": button, "search": _search_words(searchable)})
	_filter_courses(_search.text)


func _build_modules() -> void:
	_clear_rows()
	for index in range(_course.get("modules", []).size()):
		var module: Dictionary = _course.modules[index]
		var status: String = "Completed" if _module_complete(module) else "Ready" if module.get("status") == "ready" else "Preparing"
		var copy: String = "50 terms · 10 expressions · " + status
		if not _module_complete(module) and _module_previously_complete(module):
			copy += "\nPreviously completed"
		if module.get("foundation", false):
			copy += "\nShared workplace foundation"
		var button: Button = _choice("%02d  %s" % [index + 1, module.title], copy, "Module_" + str(module.id), _choose_module.bind(str(module.id)))
		_list.add_child(button)
		_rows.append({"id": module.id, "button": button, "search": ""})


func _filter_courses(value: String) -> void:
	var terms: Array[String] = _search_words(value)
	for row in _rows:
		row.button.visible = terms.is_empty() or terms.all(func(term: String) -> bool:
			# Short abbreviations such as IT and HR must be whole words. Longer
			# queries can be prefixes while someone is still typing a skill.
			return row.search.any(func(word: String) -> bool:
				return word == term if term.length() <= 2 else word.begins_with(term)))
	_refresh()


func _search_words(value: String) -> Array[String]:
	var words: Array[String] = []
	for match_value: RegExMatch in _search_word_pattern.search_all(value.to_lower()):
		words.append(match_value.get_string())
	return words


func _selected_module() -> Dictionary:
	for module in _course.get("modules", []):
		if module.id == _selection.get("module_id") and _course.get("id") == _selection.get("course_id"):
			return module
	return {}


func _selected_ready() -> bool:
	return _selection.get("track") == "growth" or _selected_module().get("status") == "ready"


func _progress_available() -> bool:
	return _progress.get("progress_loaded", false) and not _progress.get("blocked", false) and _progress.get("progress") is Dictionary


func _course_progress(id: String) -> String:
	if not _progress_available():
		return "Progress unavailable"
	var course: Dictionary = _catalog.course(id) if _catalog != null else {}
	if course.is_empty():
		return "Progress unavailable"
	var completed: Dictionary = {}
	var current_keys: Dictionary = {}
	for module in course.get("modules", []):
		var key: String = Progress.requirement_key({"course_id": id, "module_id": module.get("id"),
			"requirements_revision": module.get("requirements_revision")})
		current_keys[key] = true
		if _module_complete(module, id):
			completed[module.id] = true
	var earlier: Dictionary = {}
	for receipt in _progress.progress.get("completions", {}).values():
		if receipt.get("course_id") == id and not current_keys.has(Progress.requirement_key(receipt)):
			earlier[receipt.module_id] = true
	var copy: String = "%d / 10 modules completed" % completed.size()
	if not earlier.is_empty():
		copy += "\nEarlier versions: %d %s completed" % [earlier.size(), "module" if earlier.size() == 1 else "modules"]
	return copy


func _module_progress(module: Dictionary) -> String:
	if not _progress_available():
		return "Progress unavailable"
	var key: String = Progress.requirement_key({"course_id": _course.get("id"), "module_id": module.get("id"),
		"requirements_revision": module.get("requirements_revision")})
	var fingerprint: String = str(_progress.progress.get("requirements", {}).get(key, ""))
	if fingerprint.is_empty():
		return "Progress appears after your first practice."
	var requirements: Variant = JSON.parse_string(fingerprint)
	if not requirements is Dictionary or not requirements.get("terms") is Array or not requirements.get("expressions") is Array:
		return "Progress unavailable"
	var learned: int = 0
	for term in requirements.terms:
		for skill in term.skills:
			if _progress.progress.get("skills", {}).get(term.sense_id, {}).get(skill, {}).get("earned", false):
				learned += 1
				break
	var expressions: int = 0
	var practised: Dictionary = _progress.progress.get("expressions", {}).get(key, {})
	for expression in requirements.expressions:
		if practised.get(expression, false):
			expressions += 1
	return "%d / %d terms mastered · %d / %d expressions practised" % [learned, requirements.terms.size(), expressions, requirements.expressions.size()]


func _module_complete(module: Dictionary, course_id: String = "") -> bool:
	if not _progress_available():
		return false
	var id: String = str(_course.get("id", "")) if course_id.is_empty() else course_id
	var key: String = Progress.requirement_key({"course_id": id, "module_id": module.get("id"),
		"requirements_revision": module.get("requirements_revision")})
	return _progress.progress.get("completions", {}).has(key)


func _module_previously_complete(module: Dictionary) -> bool:
	if not _progress_available():
		return false
	var key: String = Progress.requirement_key({"course_id": _course.get("id"), "module_id": module.get("id"),
		"requirements_revision": module.get("requirements_revision")})
	for receipt in _progress.progress.get("completions", {}).values():
		if receipt.get("course_id") == _course.get("id") and receipt.get("module_id") == module.get("id") \
			and Progress.requirement_key(receipt) != key:
			return true
	return false


func _refresh() -> void:
	var growth_summary: bool = _screen == "summary" and _selection.get("track") == "growth"
	_heading.text = "Choose your learning path" if _screen == "paths" else "Choose a career" if _screen == "courses" \
		else str(_course.get("title", "Choose a module")) if _screen == "modules" else "Your learning path"
	_heading.visible = not growth_summary
	_compact_path.visible = growth_summary
	_active.visible = _screen == "summary" and not growth_summary
	_active.text = ""
	if _screen == "summary" and _selection.get("track") == "professional":
		var selected_course: Dictionary = _course if _course.get("id") == _selection.course_id else _catalog.course(_selection.course_id) if _catalog != null else {}
		var title: String = str(_selection.module_id)
		for module in selected_course.get("modules", []):
			if module.id == _selection.module_id:
				title = str(module.title)
		_heading.text = str(selected_course.get("title", _selection.course_id))
		_active.text = title
	_paths.visible = _screen == "paths"
	_search.visible = _screen == "courses"
	_list.visible = _screen in ["courses", "modules"]
	_change_path.visible = _screen != "paths"
	_change_path.text = "Change path" if growth_summary else "All paths"
	_change_career.visible = _screen in ["modules", "summary"] and (_selection.get("track") == "professional" or not _course.is_empty())
	_change_module.visible = _screen == "summary" and _selection.get("track") == "professional" and not _course.is_empty()
	_navigation.visible = _change_path.visible or _change_career.visible or _change_module.visible
	_empty.visible = _screen == "courses" and _rows.filter(func(row: Dictionary) -> bool: return row.button.visible).is_empty()
	_empty.text = "No careers match your search." if _catalog != null and not _catalog.courses().is_empty() else "The course catalog is unavailable. Retry to load it."
	_detail.visible = _screen == "summary" and not growth_summary
	_detail.text = ""
	if _selection.get("track") == "professional":
		var module: Dictionary = _selected_module()
		_detail.text = "50 terms · 10 expressions"
		var progress: String = _module_progress(module)
		if progress != "Progress appears after your first practice." and (not _busy or progress != "Progress unavailable"):
			_detail.text += "\n" + progress
		if _module_complete(module):
			_detail.text += " · Completed"
		elif _module_previously_complete(module):
			_detail.text += "\nPreviously completed"
		if not _busy and module.get("status") != "ready":
			_detail.text += "\nPreparing this module. Explore another module while you wait."
	_status.text = _status_text
	_status.visible = not _status_text.is_empty()
	_continue.visible = _screen == "summary" and not growth_summary and _selected_ready()
	_continue.text = "Continue"
	_retry_button.visible = _retry
	_cancel.visible = _busy or _retry
	_actions.visible = _continue.visible or _retry_button.visible or _cancel.visible
	for button in _buttons:
		if is_instance_valid(button):
			button.disabled = _busy and button != _cancel
	_continue.disabled = _busy or not _selected_ready() or _selection.is_empty()
	_search.editable = not _busy
	fit(_factor, _wide)
	if _last_screen != _screen:
		_last_screen = _screen
		browsing_changed.emit(_screen)


func _clear_rows() -> void:
	for picture in _career_pictures:
		picture.clear()
	_career_pictures.clear()
	for row in _rows:
		var button: Button = row.button
		_buttons.erase(button)
		for child in button.find_children("*", "Label", true, false):
			_labels.erase(child)
		_list.remove_child(button)
		button.queue_free()
	_rows.clear()


func _label(text: String, font_size: int) -> Label:
	var label := Style.label(text, font_size)
	label.set_meta("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.append(label)
	return label


func _button(text: String, node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.pressed.connect(callback)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiClick.bind_button(button)
	_buttons.append(button)
	_style_revision += 1
	return button


func _choice(title: String, copy: String, node_name: String, callback: Callable) -> Button:
	var button: Button = _button("", node_name, callback)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set("accessibility_name", title + ". " + copy.replace("\n", ". "))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(margin)
	button.set_meta("choice", margin)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)
	var title_label: Label = _label(title, 17)
	title_label.add_theme_font_override("font", Style.HEADING_FONT)
	content.add_child(title_label)
	var copy_label: Label = _label(copy, 13)
	copy_label.add_theme_color_override("font_color", Style.MUTED)
	content.add_child(copy_label)
	margin.minimum_size_changed.connect(func() -> void:
		if is_instance_valid(button):
			button.custom_minimum_size.y = maxf(90.0 / _factor, margin.get_combined_minimum_size().y))
	return button


func _illustrate_path(button: Button, textures: Array) -> void:
	button.set_meta("path_choice", true)
	var content: VBoxContainer = button.get_meta("choice").get_child(0)
	content.get_child(0).set_meta("font_size", 21)
	content.get_child(1).set_meta("font_size", 14)
	var pictures := HBoxContainer.new()
	pictures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(pictures)
	content.move_child(pictures, 0)
	for texture: Texture2D in textures:
		var picture := TextureRect.new()
		picture.name = str(button.name) + "Art" + str(pictures.get_child_count() + 1)
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.custom_minimum_size.y = (156.0 if _wide else 128.0) / _factor
		pictures.add_child(picture)
		_path_pictures.append(picture)


func _illustrate_career(button: Button, profile: Dictionary) -> void:
	var picture := ThemeArt.new()
	if not picture.show_profile(profile, "preview", true):
		picture.free()
		return
	picture.name = str(button.name) + "Art"
	picture.custom_minimum_size.y = 96.0 / _factor
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content: VBoxContainer = button.get_meta("choice").get_child(0)
	content.add_child(picture)
	content.move_child(picture, 0)
	_career_pictures.append(picture)
