extends "res://tools/capture-learning-path-selector.gd"
## Actual reviewed Home previews with real catalog selection and scrolling.


func _course_art(id: String) -> void:
	var course: Dictionary = catalog.course(id)
	home.apply_learning_art(catalog.theme_profile(str(course.theme_id)), false)


func _capture_preview(stage: String, dimensions: Vector2i, course_id: String) -> void:
	await _capture(course_id + "-" + stage, dimensions)
	var art: Control = home._learning_art
	var texture_rect: TextureRect = art._current.get_node("environment")
	var state: Dictionary = home.learning.snapshot()
	var collapsed: bool = dimensions.y <= 600 and (state.busy or (state.retry and not str(state.status).is_empty()))
	_check(art.has_art() and art.visible != collapsed, "Reviewed career preview respects compact loading/recovery layout: " + course_id)
	_check(art.snapshot().theme_id == "professional_" + course_id, "Preview follows selected career")
	_check(not art.snapshot().transitioning and art.snapshot().previous_images == 0, "Completed fade releases prior preview")
	_check(texture_rect.texture != null and texture_rect.texture.get_size() == Vector2(512, 320), "The actual reviewed 512 by 320 PNG is loaded")
	_check(texture_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Home preview preserves its full source image")
	if art.visible:
		_check(art.get_global_rect().end.y <= home.learning.get_global_rect().position.y + 0.5, "Preview and selector do not overlap")
	_check(art.size.x <= home.scroll.size.x + 0.5, "Preview width fits Home")
	var profile: Dictionary = catalog.theme_profile("professional_" + course_id)
	_check(profile.status == "pending", "A ready preview does not claim full theme readiness")
	captures[-1]["art"] = art.snapshot()
	captures[-1]["preview_rect"] = [art.global_position.x, art.global_position.y, art.size.x, art.size.y]
	captures[-1]["preview_source"] = profile.preview.path
	captures[-1]["preview_visible"] = art.visible


func _check_initial_actions(retry: bool = false) -> void:
	var viewport: Rect2 = home.scroll.get_global_rect().grow(0.5)
	_check(home.scroll.scroll_vertical == 0, "Loading and recovery actions are checked before scrolling")
	_check(viewport.encloses(home.learning._active.get_global_rect()), "The current career and module remain visible")
	_check(viewport.encloses(home.learning._status.get_global_rect()), "Loading and recovery status is fully visible without scrolling")
	_check(viewport.encloses(home.learning._cancel.get_global_rect()), "Cancel is fully visible without scrolling")
	if retry:
		_check(viewport.encloses(home.learning._retry_button.get_global_rect()), "Retry is fully visible without scrolling")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This harness requires the actual renderer; omit --headless.")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	catalog = Catalog.new()
	_check(catalog.load_index(), "The real Professional catalog loads")
	for dimensions: Vector2i in SIZES:
		root.size = dimensions
		await _settle()
		for course_id: String in ["retail", "software_data"]:
			home = Library.new()
			root.add_child(home)
			home.configure("", true, true)
			home.finish_previews()
			home.fit(Vector2(dimensions), 1.0)
			home.configure_learning(catalog, {}, {"phase": "idle"})
			home.learning_course_selected.connect(_course_art)
			home.learning._professional_button.pressed.emit()
			home.learning._choose_course(course_id)
			home.scroll.scroll_vertical = 0
			await _capture_preview("modules-top", dimensions, course_id)
			_check(home.scroll.get_global_rect().encloses(home._learning_art.get_global_rect()), "Top of page contains the entire reviewed preview")
			_check(home.scroll.get_global_rect().grow(0.5).encloses(home.learning._rows[0].button.get_global_rect()), "The first module is fully visible without scrolling")
			var last_card: Control = home.learning._rows[-1].button
			await _focus(last_card)
			await _capture_preview("last-module-focus", dimensions, course_id)
			home.learning._choose_module("module01")
			var selection: Dictionary = home.learning.snapshot().selection
			home.configure_learning(catalog, selection, {"phase": "storage"})
			_course_art("software_data" if course_id == "retail" else "retail")
			_course_art(course_id)
			_course_art(course_id)
			home.scroll.scroll_vertical = 0
			await _capture_preview("selection-pending", dimensions, course_id)
			_check_initial_actions()
			_check(not home.learning.snapshot().continue_enabled and home.learning._cancel.visible, "Pending content remains unavailable and offers Cancel")
			await _focus(home.learning._cancel)
			await _capture_preview("pending-cancel-focus", dimensions, course_id)
			home.configure_learning(catalog, selection, {"phase": "failed", "error": "Saved progress could not be read. Please retry."})
			await _settle()
			home.scroll.scroll_vertical = 0
			await _settle()
			_check_initial_actions(true)
			await _focus(home.learning._retry_button)
			await _capture_preview("retry-focus", dimensions, course_id)
			_check(home.learning._retry_button.visible and not home.learning._retry_button.disabled, "Retry remains reachable below the preview")
			home.configure_learning(catalog, selection, {"phase": "idle"})
			await _settle()
			_check(home._learning_art.visible, "Completing recovery restores the current career preview")
			home.apply_learning_art(catalog.theme_profile("professional_nursing"), true)
			await _settle()
			_check(not home._learning_art.has_art() and not home._learning_art.visible, "Selecting Nursing clears the prior career image without substituting artwork")
			home.free()
	var report: Dictionary = {"capture": "professional-home-previews", "renderer": RenderingServer.get_video_adapter_name(),
		"notice": "Actual GameLibrary, real catalog and reviewed Retail/Software Home PNGs. Full workplace themes and curriculum remain pending. Loading and retry are simulated view states; saved progress and wallet are untouched.",
		"checks": checks, "failures": failures, "captures": captures}
	var file := FileAccess.open(OUTPUT + "/home-preview-render-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("Home preview renderer: %d checks, %d failures, %d PNG captures" % [checks, failures.size(), captures.size()])
	quit(1 if not failures.is_empty() else 0)
