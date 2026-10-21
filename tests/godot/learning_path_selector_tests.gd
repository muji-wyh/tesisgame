extends SceneTree

const Catalog = preload("res://scripts/professional_catalog.gd")
const Selector = preload("res://scripts/learning_path_selector.gd")
const Context = preload("res://scripts/learning_context.gd")
const Progress = preload("res://scripts/professional_progress.gd")
var checks: int = 0
var failures: int = 0
var selections: Array = []
var continuations: Array = []
var retries: int = 0
var cancellations: int = 0
var screens: Array[String] = []
var careers: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _settle() -> void:
	for frame in range(6):
		await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1080, 900)
	var catalog := Catalog.new()
	check(catalog.load_index(), "The selector uses the real course catalog")
	var scroll := ScrollContainer.new()
	root.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view := Selector.new()
	scroll.add_child(view)
	view.configure(catalog)
	view.context_selected.connect(func(context: Dictionary) -> void: selections.append(context))
	view.continue_requested.connect(func(context: Dictionary) -> void: continuations.append(context))
	view.retry_requested.connect(func() -> void: retries += 1)
	view.cancel_requested.connect(func() -> void: cancellations += 1)
	view.browsing_changed.connect(func(screen: String) -> void: screens.append(screen))
	view.course_selected.connect(func(id: String) -> void: careers.append(id))
	check(view.snapshot().screen == "paths", "A new selector offers both learning paths")
	check(view._path_pictures.size() == 3 and view._path_pictures.all(func(picture: TextureRect) -> bool:
		return picture.texture != null and picture.mouse_filter == Control.MOUSE_FILTER_IGNORE and picture.focus_mode == Control.FOCUS_NONE),
		"Both learning paths use actual local artwork without introducing extra input targets")
	for dimensions: Vector2i in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]:
		root.size = dimensions
		view.fit(1.0, dimensions.x >= 800)
		await _settle()
		for button: Button in [view._growth_button, view._professional_button]:
			for picture: TextureRect in button.find_children("*", "TextureRect", true, false):
				check(button.get_global_rect().grow(1).encloses(picture.get_global_rect()) and picture.size.y >= 71.0,
					"%s: path artwork stays readable and enclosed by its single choice target" % dimensions)
	view._growth_button.pressed.emit()
	check(selections.size() == 1 and selections[0] == Context.growth(3, "match"), "Growth emits the documented age substitution hint")
	view._continue.pressed.emit()
	check(continuations.size() == 1 and continuations[0].track == "growth", "Growth can continue")
	view._change_path.pressed.emit()
	view._professional_button.pressed.emit()
	check(view.snapshot().visible_rows == 20, "All twenty catalog careers remain browsable")
	for row in view._rows:
		var course: Dictionary = catalog.course(str(row.id))
		var profile: Dictionary = catalog.theme_profile(str(course.theme_id))
		var picture: Control = row.button.find_child(str(row.button.name) + "Art", true, false)
		if profile.get("preview", {}).get("status") == "integrated":
			check(picture != null and picture.has_art(), "An acquired career preview appears in its browsable card: " + str(row.id))
			check(picture != null and picture.mouse_filter == Control.MOUSE_FILTER_IGNORE and picture.focus_mode == Control.FOCUS_NONE,
				"Career artwork preserves its single parent input target: " + str(row.id))
		else:
			check(picture == null, "Missing career artwork is not replaced with a placeholder: " + str(row.id))
	view._search.text = "checkout"
	view._search.text_changed.emit(view._search.text)
	check(view.snapshot().visible_rows == 1 and view._rows.filter(func(row: Dictionary) -> bool: return row.button.visible)[0].id == "retail", "Career search uses real catalog titles")
	view._filter_courses(" IT  sup ")
	check(view.snapshot().visible_rows == 1 and view._rows.filter(func(row: Dictionary) -> bool: return row.button.visible)[0].id == "it_support",
		"IT is a whole abbreviation and cannot match letters inside recruitment")
	view._filter_courses("HR")
	check(view.snapshot().visible_rows == 1 and view._rows.filter(func(row: Dictionary) -> bool: return row.button.visible)[0].id == "hr_recruitment",
		"Short professional abbreviations remain searchable")
	for course in catalog.courses():
		view._filter_courses(course.title)
		check(view.snapshot().visible_rows == 1 and view._rows.filter(func(row: Dictionary) -> bool: return row.button.visible)[0].id == course.id,
			"The full title identifies its career: " + str(course.title))
	view._search.text = "not-a-career"
	view._search.text_changed.emit(view._search.text)
	check(view._empty.visible and view.snapshot().visible_rows == 0, "An empty search has a visible explanation")
	view._search.text = ""
	view._search.text_changed.emit(view._search.text)
	check(view.snapshot().visible_rows == 20 and not view._empty.visible, "Clearing a career query restores the complete list")
	# Godot Web forwards its HTML input through this engine method with signals enabled.
	# Do not emit text_changed manually: an empty replacement must reach filtering itself.
	var search_events: Array[String] = []
	var observe_search := func(value: String) -> void: search_events.append(value)
	view._search.text_changed.connect(observe_search)
	view._search.call("_set_text", "unmatched-career-fixture", true)
	check(view.snapshot().visible_rows == 0 and view._empty.visible, "Web text replacement can show a no-results state")
	check(search_events == ["unmatched-career-fixture"], "Nonempty Web input emits one native notification")
	view._search.call("_set_text", "", true)
	await _settle()
	check(view._search.text.is_empty() and view.snapshot().visible_rows == 20 and not view._empty.visible,
		"Clearing through the real Web text-input method restores every career without a manual signal")
	check(search_events == ["unmatched-career-fixture", ""], "Clearing Web input emits exactly one missing notification")
	view._search.call("_set_text", "", true)
	check(search_events.size() == 2, "Replacing empty text with empty text does not emit a spurious change")
	view._search.call("_set_text", "IT", false)
	check(view._search.text == "IT" and search_events.size() == 2 and view.snapshot().visible_rows == 20,
		"An explicitly silent nonempty replacement retains the engine's no-signal contract")
	view._search.call("_set_text", "", false)
	check(view._search.text.is_empty() and search_events.size() == 2, "An explicitly silent clear remains silent")
	view._search.call("_set_text", "IT", true)
	check(view.snapshot().visible_rows == 1 and search_events == ["unmatched-career-fixture", "", "IT"],
		"A later nonempty query still filters once after the empty-input correction")
	view._search.text_changed.disconnect(observe_search)
	view._choose_course("retail")
	check(view._career_pictures.is_empty(), "Leaving the career list releases all local preview holders")
	check(careers == ["retail"], "Career choice tells the host to apply its theme immediately")
	check(view.snapshot().visible_rows == 10 and view.snapshot().screen == "modules", "A draft career opens all ten modules")
	view._choose_module("module01")
	check(selections.back().course_id == "retail" and selections.back().module_id == "module01", "Draft module selection keeps a stable course identity")
	check(view.snapshot().active_text.contains("Retail") and view.snapshot().active_text.contains("People"), "The active course and module remain visible")
	check(not view.snapshot().continue_enabled and view._detail.text.contains("Preparing"), "Unreviewed content is visibly pending and cannot continue")
	check(not view._continue.visible and view._heading.text.contains("Retail") and view._active.text.contains("People"),
		"An unavailable module has a clear course and module hierarchy without a dead primary action")
	view._continue.pressed.emit()
	check(continuations.size() == 1, "A forced pending Continue does not emit a start")
	var module: Dictionary = view._selected_module()
	var requirements: Dictionary = {"course_id": "retail", "module_id": "module01", "requirements_revision": module.requirements_revision,
		"terms": [], "expressions": module.expression_ids}
	for id in module.lexeme_ids:
		requirements.terms.append({"sense_id": id, "skills": ["recognition"]})
	var key: String = Progress.requirement_key(requirements)
	var saved: Dictionary = Progress.empty_progress()
	saved.requirements[key] = Progress.requirement_fingerprint(requirements)
	saved.skills[module.lexeme_ids[0]] = {"recognition": {"earned": true, "streak": 3, "exposures": 3},
		"spelling": {"earned": true, "streak": 3, "exposures": 3}}
	saved.skills[module.lexeme_ids[1]] = {"spelling": {"earned": true, "streak": 3, "exposures": 3}}
	saved.expressions[key] = {module.expression_ids[0]: true, module.expression_ids[1]: true, "unrelated": true}
	_add_selector_completion(saved, "retail", module, str(module.requirements_revision))
	_add_selector_completion(saved, "retail", module, "selector-earlier-r01")
	check(Progress.validate_progress(saved).is_empty(), "The selector fixture uses valid persisted progress records")
	view.set_progress({"progress_loaded": true, "progress": saved})
	check(view._detail.text.contains("1 / 50 terms mastered") and view._detail.text.contains("2 / 10 expressions practised"), "Selected mastery uses canonical eligible skills and exact expression membership")
	check(view._detail.text.contains(" · Completed"), "An exact current requirements completion remains visible")
	check(view._course_progress("retail") == "1 / 10 modules completed\nEarlier versions: 1 module completed",
		"The current count and earlier achievement are presented separately")
	view.set_progress({"progress_loaded": true, "progress": saved, "blocked": true})
	check(view._detail.text.contains("Progress unavailable") and view._course_progress("retail") == "Progress unavailable", "Blocked storage never fabricates fresh progress")
	view.set_status("Loading your progress…", true)
	check(view._status.text == "Loading your progress…" and not view._detail.text.contains("Progress unavailable"),
		"An active load shows its real status without a premature storage failure caption")
	check(not view._detail.text.contains("Preparing") and view._change_career.disabled and view._change_module.disabled,
		"Busy selection does not recommend navigation that is temporarily disabled")
	check(not view.snapshot().continue_enabled and view._cancel.visible and not view._cancel.disabled,
		"Loading retains module readiness guards and a usable Cancel action")
	view.set_status("Saved progress could not be read. Please retry.", false, true)
	check(view._detail.text.contains("Progress unavailable") and view._detail.text.contains("Preparing")
		and not view._change_career.disabled and not view._change_module.disabled,
		"After loading fails, unavailable progress and usable alternative modules remain explicit")
	view.set_progress({"progress_loaded": true, "progress": saved})
	view.set_status("Loading recordings…", true)
	check(view._cancel.visible and not view._cancel.disabled and view._change_path.disabled, "Pending work offers cancellation and blocks selection races")
	view._cancel.pressed.emit()
	check(cancellations == 1, "Cancel reaches the host")
	view.set_status("Saved progress could not be read. Please retry.", false, true)
	view._retry_button.pressed.emit()
	check(retries == 1 and view._status.text.contains("could not be read"), "Storage failure remains explicit and retry reaches the host")
	view.set_status("")
	var screens_before: int = screens.size()
	view.set_progress({"progress_loaded": true})
	view.set_status("")
	check(screens.size() == screens_before, "Repeated progress updates do not emit duplicate browsing changes")
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_TAB
	key_event.pressed = true
	view._input(key_event)
	check(view._continue.get_theme_stylebox("focus") is StyleBoxFlat, "Keyboard navigation shows a focus outline")
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.pressed = true
	view._input(pointer)
	check(view._continue.get_theme_stylebox("focus") is StyleBoxEmpty, "Pointer input removes keyboard-only focus outlines")
	view._change_career.pressed.emit()
	for viewport in [Vector2i(1080, 900), Vector2i(390, 844), Vector2i(320, 568)]:
		root.size = viewport
		view.fit(1.0, viewport.x >= 800)
		await _settle()
		check(view._list.columns == (2 if viewport.x >= 800 else 1), "Career columns adapt at %s" % viewport)
		check(view.size.x <= viewport.x + 1, "The selector stays inside the viewport at %s" % viewport)
		for row in view._rows:
			var button: Button = row.button
			check(button.size.y >= 44 and button.size.x <= viewport.x + 1, "Career targets stay usable at %s" % viewport)
			for label in button.find_children("*", "Label", true, false):
				check(button.get_global_rect().grow(1).encloses(label.get_global_rect()), "Career copy stays inside its target at %s: %s within %s" % [viewport, label.get_global_rect(), button.get_global_rect()])
			var picture: Control = button.find_child(str(button.name) + "Art", true, false)
			if picture != null:
				check(button.get_global_rect().grow(1).encloses(picture.get_global_rect()) and picture.size.y >= 95.0,
					"Career artwork remains readable within its card at %s" % viewport)
	view._choose_course("retail")
	view._choose_module("module01")
	for selected_module in view._course.modules:
		if selected_module.id == "module01":
			selected_module.status = "ready"
	view._refresh()
	view._continue.pressed.emit()
	check(continuations.size() == 2 and continuations.back().course_id == "retail", "Ready metadata can request a resolver-guarded professional start")
	await _test_completion_revisions(view, catalog)
	view.set_selection({"track": "invalid"})
	check(view.snapshot().screen == "paths" and not view.snapshot().continue_enabled, "Invalid restored preferences return to path selection")
	scroll.queue_free()
	await process_frame
	print("Learning path selector: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _add_selector_completion(saved: Dictionary, course_id: String, module: Dictionary, revision: String) -> void:
	var requirements: Dictionary = {"course_id": course_id, "module_id": module.id, "requirements_revision": revision,
		"terms": [], "expressions": module.expression_ids.duplicate()}
	for id in module.lexeme_ids:
		requirements.terms.append({"sense_id": id, "skills": ["recognition"]})
	var key: String = Progress.requirement_key(requirements)
	saved.sequence += 1
	saved.requirements[key] = Progress.requirement_fingerprint(requirements)
	saved.completions[key] = {"course_id": course_id, "module_id": module.id, "requirements_revision": revision,
		"sequence": saved.sequence}


func _test_completion_revisions(view, catalog) -> void:
	view._choose_course("retail")
	var first: Dictionary = view._course.modules[0]
	var second: Dictionary = view._course.modules[1]
	var nursing: Dictionary = catalog.course("nursing")
	var saved: Dictionary = Progress.empty_progress()
	_add_selector_completion(saved, "retail", first, "selector-earlier-r01")
	_add_selector_completion(saved, "retail", first, "selector-earlier-r02")
	_add_selector_completion(saved, "retail", second, "selector-earlier-r01")
	_add_selector_completion(saved, "retail", second, str(second.requirements_revision))
	_add_selector_completion(saved, "nursing", nursing.modules[0], str(nursing.modules[0].requirements_revision))
	check(Progress.validate_progress(saved).is_empty(), "Revision comparisons use complete keyed receipt fixtures")
	var frozen: Dictionary = saved.duplicate(true)
	view.set_progress({"progress_loaded": true, "progress": saved})
	check(not view._module_complete(first) and view._module_complete(second),
		"Earlier requirements and another career cannot complete the current first module")
	check(view._course_progress("retail") == "1 / 10 modules completed\nEarlier versions: 2 modules completed",
		"Current modules and distinct earlier modules are counted separately across duplicate revisions")
	check(view._course_progress("nursing") == "1 / 10 modules completed",
		"Course cards use their own current requirements while another career is selected")
	var first_button: Button = view._rows[0].button
	var first_copy: String = str(first_button.get("accessibility_name"))
	var primary: String = "Ready" if first.status == "ready" else "Preparing"
	check(first_copy.contains(primary) and first_copy.contains("Previously completed") and not first_copy.contains(" · Completed"),
		"A historical module keeps its real readiness and a separate accessible achievement caption")
	check(str(view._rows[1].button.get("accessibility_name")).contains(" · Completed"),
		"An exact current receipt marks only its own module card complete")
	for viewport: Vector2i in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]:
		root.size = viewport
		view.fit(1.0, viewport.x >= 800)
		await _settle()
		var button: Button = view._rows[0].button
		for label in button.find_children("*", "Label", true, false):
			check(button.get_global_rect().grow(1).encloses(label.get_global_rect()),
				"Historical module copy fits its existing card at %s" % viewport)
	view._choose_module(str(first.id))
	check(view._detail.text.contains("Previously completed") and not view._detail.text.contains(" · Completed"),
		"The selected summary does not label an earlier receipt as current completion")
	var starts_before: int = continuations.size()
	view._continue.pressed.emit()
	check(view.snapshot().continue_enabled == (first.status == "ready")
		and continuations.size() == starts_before + (1 if first.status == "ready" else 0),
		"Historical completion does not bypass or replace the existing Continue readiness gate")
	view._show_courses()
	for viewport: Vector2i in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]:
		root.size = viewport
		view.fit(1.0, viewport.x >= 800)
		await _settle()
		var retail_row: Dictionary = view._rows.filter(func(row: Dictionary) -> bool: return row.id == "retail")[0]
		for label in retail_row.button.find_children("*", "Label", true, false):
			check(retail_row.button.get_global_rect().grow(1).encloses(label.get_global_rect()),
				"Earlier course history fits its existing card at %s" % viewport)
	check(saved == frozen, "Browsing and completion summaries never rewrite the supplied history")
	_add_selector_completion(saved, "retail", first, str(first.requirements_revision))
	view.set_progress({"progress_loaded": true, "progress": saved})
	view._choose_course("retail")
	view._choose_module(str(first.id))
	check(view._module_complete(view._selected_module()) and view._detail.text.contains(" · Completed")
		and not view._detail.text.contains("Previously completed"),
		"New current completion takes the primary state without a redundant historical module caption")
	check(view._course_progress("retail") == "2 / 10 modules completed\nEarlier versions: 2 modules completed",
		"New completion increments the current count once while preserving earlier course history")
	var current_context: Dictionary = view._selection.duplicate(true)
	view._course.curriculum_revision = "selector-content-only-r01"
	check(view._module_complete(view._selected_module()), "A content-only revision does not erase unchanged requirement completion")
	view._course.curriculum_revision = current_context.curriculum_revision
	for unavailable in [{"progress_loaded": true, "progress": saved, "blocked": true}, {"progress_loaded": false, "progress": saved}]:
		view.set_progress(unavailable)
		check(not view._module_complete(view._selected_module()) and not view._module_previously_complete(view._selected_module())
			and view._course_progress("retail") == "Progress unavailable" and view._detail.text.contains("Progress unavailable")
			and not view._detail.text.contains("Previously completed") and not view._detail.text.contains(" · Completed"),
			"Unavailable storage shows neither current nor historical completion claims")
	var historical_only: Dictionary = saved.duplicate(true)
	var current_key: String = Progress.requirement_key({"course_id": "retail", "module_id": first.id,
		"requirements_revision": first.requirements_revision})
	historical_only.completions.erase(current_key)
	view.set_progress({"progress_loaded": true, "progress": historical_only})
	for module in view._course.modules:
		if module.id == first.id:
			module.status = "ready"
	view._refresh()
	starts_before = continuations.size()
	view._continue.pressed.emit()
	check(not view._module_complete(view._selected_module()) and view.snapshot().continue_enabled
		and continuations.size() == starts_before + 1 and continuations.back() == current_context,
		"A ready module with earlier history continues the selected current context exactly once")
	view.set_progress({"progress_loaded": true, "progress": Progress.empty_progress()})
	check(view._course_progress("retail") == "0 / 10 modules completed" and not view._detail.text.contains("Previously completed"),
		"A new profile has no historical completion caption")
