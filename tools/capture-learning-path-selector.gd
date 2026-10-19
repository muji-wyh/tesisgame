extends SceneTree
## Actual Home/catalog rendering; pending and retry messages are simulated UI states.

const Library = preload("res://scripts/game_library.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
const OUTPUT: String = "res://build/professional-english"
const SIZES: Array[Vector2i] = [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]
var home: Control
var catalog: RefCounted
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)


func _settle() -> void:
	for frame in range(8):
		await process_frame


func _focus(control: Control) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	home.learning._input(key)
	home._input(key)
	control.grab_focus()
	await _settle()
	_check(control.has_focus(), "Keyboard focus reaches " + str(control.name))
	_check(control.get_theme_stylebox("focus") is StyleBoxFlat, "Keyboard focus has a visible outline")
	_check(home.scroll.get_global_rect().grow(1.0).encloses(control.get_global_rect()), "Focused target is fully visible: " + str(control.name))


func _capture(stage: String, dimensions: Vector2i) -> void:
	await _settle()
	_check(root.size == dimensions, "Home viewport matches " + str(dimensions))
	_check(home.learning.size.x <= home.scroll.size.x + 1.0, "Learning selector fits the Home scroll width")
	var rows: Array[Dictionary] = []
	for row: Dictionary in home.learning._rows:
		if not row.button.visible:
			continue
		var button: Button = row.button
		_check(button.size.y >= 44.0 and button.size.x <= home.scroll.size.x + 1.0, "Career/module target stays within Home width")
		var labels: Array = []
		for label: Label in button.find_children("*", "Label", true, false):
			_check(button.get_global_rect().grow(1.0).encloses(label.get_global_rect()), "Career/module copy fits its card: " + label.text)
			_check(label.get_visible_line_count() == label.get_line_count(), "Career/module text has no missing wrapped lines")
			labels.append(label.text)
		rows.append({"id": row.id, "text": labels, "height": button.size.y, "width": button.size.x})
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var filename: String = "home-%dx%d-%s.png" % [dimensions.x, dimensions.y, stage]
	_check(picture.get_size() == dimensions and picture.save_png(OUTPUT + "/" + filename) == OK, "Home PNG saved: " + filename)
	var focused: Control = root.gui_get_focus_owner()
	captures.append({"file": filename, "stage": stage, "viewport": [dimensions.x, dimensions.y],
		"selector": home.learning.snapshot(), "scroll": home.scroll.scroll_vertical,
		"focus_rect": [focused.global_position.x, focused.global_position.y, focused.size.x, focused.size.y] if focused != null else [],
		"focus": str(focused.name) if focused != null else "", "rows": rows})


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
	var longest: Dictionary = {}
	for course: Dictionary in catalog.courses():
		if str(course.title).length() > str(longest.get("title", "")).length():
			longest = course
	home = Library.new()
	root.add_child(home)
	home.configure("", true, true)
	home.finish_previews()
	for dimensions: Vector2i in SIZES:
		root.size = dimensions
		await _settle()
		home.fit(Vector2(dimensions), 1.0)
		home.configure_learning(catalog, {}, {"phase": "idle"})
		home.scroll.scroll_vertical = 0
		await _capture("paths", dimensions)
		home.learning._professional_button.pressed.emit()
		await _settle()
		_check(home.learning.snapshot().visible_rows == 20, "All twenty real careers are present")
		home.scroll.scroll_vertical = 0
		await _capture("career-illustrations", dimensions)
		for course_id: String in ["nursing", "office_admin", "hr_recruitment", "warehouse_logistics", "hospitality_tourism", "education_childcare", "transport_delivery", "manufacturing_maintenance", "cleaning_facilities", "construction_trades", "it_support", "customer_support", "accounting_finance", "sales_marketing", "clinical_medicine", "legal_paralegal"]:
			var course: Dictionary = catalog.course(course_id)
			home.learning._search.text = str(course.title)
			home.learning._search.text_changed.emit(home.learning._search.text)
			home.scroll.scroll_vertical = 0
			await _settle()
			_check(home.learning.snapshot().visible_rows == 1, "The illustrated career has an exact searchable identity")
			await _capture("career-" + course_id, dimensions)
		home.learning._search.text = ""
		home.learning._search.text_changed.emit("")
		await _settle()
		var long_card: Control
		for row: Dictionary in home.learning._rows:
			if row.id == longest.id:
				long_card = row.button
		await _focus(long_card)
		await _capture("long-career-focus", dimensions)
		home.learning._search.text = "no-such-workplace-fixture"
		home.learning._search.text_changed.emit(home.learning._search.text)
		home.scroll.scroll_vertical = 0
		await _settle()
		_check(home.learning._empty.visible and home.learning.snapshot().visible_rows == 0, "Search exposes an honest empty state")
		await _capture("search-empty", dimensions)
		home.learning._choose_course(str(longest.id))
		await _settle()
		_check(home.learning.snapshot().visible_rows == 10, "The chosen real career exposes ten modules")
		var long_module: Dictionary = {}
		var module_card: Control
		for row: Dictionary in home.learning._rows:
			var length: int = str(row.button.get("accessibility_name")).length()
			if length > int(long_module.get("length", -1)):
				long_module = {"id": row.id, "length": length}
				module_card = row.button
		await _focus(module_card)
		await _capture("modules-focus", dimensions)
		home.learning._choose_module(str(long_module.id))
		var selection: Dictionary = home.learning.snapshot().selection
		home.configure_learning(catalog, selection, {"phase": "storage"})
		home.scroll.scroll_vertical = 0
		await _settle()
		_check(not home.learning.snapshot().continue_enabled and home.learning._cancel.visible,
			"Loading selection offers cancellation and does not claim readiness")
		await _capture("selection-pending", dimensions)
		home.configure_learning(catalog, selection, {"phase": "failed", "error": "Saved progress could not be read. Please retry."})
		await _settle()
		await _focus(home.learning._retry_button)
		_check(home.learning._retry_button.visible and not home.learning._retry_button.disabled, "Failed loading exposes an enabled Retry")
		await _capture("retry-focus", dimensions)
	var report: Dictionary = {"capture": "home-learning-path-selector", "renderer": RenderingServer.get_video_adapter_name(),
		"notice": "Actual GameLibrary and real Professional catalog, with reviewed local Home previews where available. Full workplace themes and curriculum review are still pending. Loading and failure messages are simulated UI states; no progress or wallet data is modified.",
		"longest_course": longest.title, "checks": checks, "failures": failures, "captures": captures}
	var file := FileAccess.open(OUTPUT + "/home-render-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("Home path renderer: %d checks, %d failures, %d PNG captures" % [checks, failures.size(), captures.size()])
	home.free()
	quit(1 if not failures.is_empty() else 0)
