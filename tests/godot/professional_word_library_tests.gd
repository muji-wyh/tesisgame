extends SceneTree

const Library = preload("res://scripts/professional_word_library.gd")
const Context = preload("res://scripts/learning_context.gd")
const Progress = preload("res://scripts/professional_progress.gd")
const CAPTURE_DIRECTORY: String = "res://build/visuals/professional-word-library"
var checks: int = 0
var failures: int = 0
var heard: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _settle() -> void:
	for frame in range(5):
		await process_frame


func _fixture() -> Dictionary:
	var content: Dictionary = {"ok": true, "context": Context.professional("retail", "module01", "test-v1", "match"),
		"course_title": "Retail & Checkout", "module_title": "Store essentials", "module_words": [], "requirements": {"terms": []}}
	for index in range(50):
		var id: String = "term.%02d.n" % index
		content.module_words.append({"id": id, "track": "professional", "text": "term%02d" % index,
			"pos": "noun", "definition": "The reviewed definition for term %d." % index,
			"example": "Use term %d in the workplace." % index, "image": "", "audio": "professional://test/recording%02d" % index})
		content.requirements.terms.append({"sense_id": id, "skills": ["recognition", "speaking"]})
	content.module_words[0].text = "bank"
	content.module_words[0].definition = "An organization that keeps money."
	content.module_words[1].text = "bank"
	content.module_words[1].definition = "The land beside a river."
	return content


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1080, 900)
	var view := Library.new()
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.hear_requested.connect(func(word: Dictionary) -> void: heard.append(word))
	var content: Dictionary = _fixture()
	var progress: Dictionary = Progress.empty_progress()
	progress.skills["term.00.n"] = {"recognition": {"earned": true, "streak": 0}, "speaking": {"earned": false, "streak": 2}}
	view.configure(content, {"progress_loaded": true, "progress": progress})
	await _settle()
	check(view.snapshot().term_count == 50 and view.snapshot().visible_rows == 8, "The complete module uses at most eight instantiated term rows")
	check(view.snapshot().selected_id == "term.00.n" and view.snapshot().definition.contains("money"), "Equal spellings keep distinct canonical senses")
	check(view.snapshot().skills_text.contains("Recognition: Mastered") and view.snapshot().skills_text.contains("Speaking: 2 / 3"), "Eligible skills show earned and current evidence independently")
	check(view.snapshot().skills_text.contains("Spelling: Not assessed here"), "Unassessed skills never appear unlearned")
	view._hear.pressed.emit()
	check(heard.size() == 1 and heard[0].id == "term.00.n" and heard[0].audio == content.module_words[0].audio, "Pronunciation emits the exact selected sense and prepared recording path")
	heard.clear()
	var stale: Button = view._row_buttons[1]
	view._next.pressed.emit()
	check(view.snapshot().page == 1 and view.snapshot().visible_rows == 8, "Next page reuses the bounded row window")
	stale.pressed.emit()
	check(view.snapshot().selected_id == "term.00.n", "Retired row input cannot select a term after rebuilding the page")
	view._search.call("_set_text", "river", true)
	check(view.snapshot().filtered_count == 1 and view.snapshot().selected_id == "term.01.n", "Definition search selects the correct sense of an ambiguous spelling")
	view._hear.pressed.emit()
	check(heard.back().id == "term.01.n", "Ambiguous spelling never falls back to another sense's recording")
	heard.clear()
	view.set_progress({"progress_loaded": true, "progress": progress, "blocked": true})
	check(view._search.text == "river" and view.snapshot().selected_id == "term.01.n" and view.snapshot().filtered_count == 1
		and view.snapshot().skills_text.contains("Progress unavailable"), "A storage callback refreshes evidence without resetting the search or selected sense")
	view.set_progress({"progress_loaded": true, "progress": progress})
	check(view.snapshot().selected_id == "term.01.n" and view.snapshot().progress_available, "Recovery preserves the selected sense")
	view._search.call("_set_text", "no-match", true)
	check(view.snapshot().visible_rows == 0 and view.snapshot().image_count == 0 and view._notice.visible, "An empty search clears the selected media and explains the result")
	view._search.call("_set_text", "", true)
	await _settle()
	check(view._search.text.is_empty() and view.snapshot().filtered_count == 50 and view.snapshot().visible_rows == 8
		and not view._notice.visible, "Clearing through the Web text-input method restores all module terms and the bounded first page")
	view.configure(content, {"progress_loaded": false})
	check(not view.snapshot().progress_available and view.snapshot().skills_text.contains("Progress unavailable"), "Unloaded persistence does not invent a fresh profile")
	view.configure(content, {"progress_loaded": true, "progress": progress, "blocked": true})
	check(not view.snapshot().progress_available and view.snapshot().skills_text.contains("Progress unavailable"), "Blocked persistence keeps progress unavailable")
	view.configure(content, {"progress_loaded": true, "progress": progress})
	for dimensions in [Vector2i(1280, 720), Vector2i(768, 1024), Vector2i(390, 844), Vector2i(320, 568)]:
		root.size = dimensions
		view.fit(1.0)
		await _settle()
		check(view._rows.columns == (2 if dimensions.x >= 800 else 1), "Term columns adapt at %s" % dimensions)
		check(view.size.x <= dimensions.x + 1, "The word library stays within the viewport at %s" % dimensions)
		for button in view._row_buttons:
			check(button.size.y >= 44, "Term controls retain a usable touch target")
			for label in button.find_children("*", "Label", true, false):
				check(button.get_global_rect().grow(1).encloses(label.get_global_rect()), "Term definition wraps inside its bounded row at %s" % dimensions)
	await _test_detail_reveal(view, content, progress)
	if "--capture" in OS.get_cmdline_user_args():
		await _capture_layouts(view, content, progress)
	var picture: ImageTexture = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var reference: WeakRef = weakref(picture)
	view._picture.texture = picture
	view._words[0].retained_image = picture
	view._selected.retained_image = picture
	picture = null
	view.hide()
	check(reference.get_ref() == null and not view.snapshot().configured and view.snapshot().term_count == 0, "Closing releases picture, selected record and module references immediately")
	view._hear.pressed.emit()
	check(heard.is_empty(), "A closed library cannot replay a retired recording")
	view.show()
	content.module_words.append(content.module_words[0].duplicate(true))
	view.configure(content, {"progress_loaded": true, "progress": progress})
	check(not view.snapshot().configured, "The library rejects inventory beyond one fifty-term module")
	content.module_words.pop_back()
	content.ok = false
	view.configure(content, {})
	check(not view.snapshot().configured, "Unresolved draft content cannot open in the library")
	view.queue_free()
	await process_frame
	print("Professional word library: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_detail_reveal(view, content: Dictionary, progress: Dictionary) -> void:
	var illustrated: Dictionary = content.duplicate(true)
	illustrated.module_words[0].image = "res://assets/images/word-library/bank.webp"
	illustrated.module_words[0].definition = "An organization that keeps money, processes payments, and provides financial services to its customers."
	for dimensions in [Vector2i(320, 568), Vector2i(844, 390)]:
		root.size = dimensions
		# The application reserves space above the library for its own header.
		view.offset_top = 110.0 if dimensions.x == 320 else 60.0
		view.configure(illustrated, {"progress_loaded": true, "progress": progress})
		view.fit(1.0)
		await _settle()
		view._row_buttons[0].pressed.emit()
		await _settle()
		var window: Rect2 = view.scroll.get_global_rect()
		var picture: Rect2 = view._picture.get_global_rect()
		check(view._detail.size.y > window.size.y, "The %s regression exercises a detail taller than its available viewport" % dimensions)
		check(view._picture.is_visible_in_tree() and picture.position.y >= window.position.y - 1.0
			and picture.end.y <= window.end.y + 1.0, "Selecting a term reveals its whole illustration first at %s" % dimensions)
		view.scroll.ensure_control_visible(view._hear)
		await _settle()
		check(window.grow(1).encloses(view._hear.get_global_rect()), "Pronunciation remains reachable by scrolling at %s" % dimensions)
		view.scroll.ensure_control_visible(view._skills)
		await _settle()
		check(window.grow(1).encloses(view._skills.get_global_rect()), "The complete skill summary remains reachable by scrolling at %s" % dimensions)
	view.offset_top = 0.0
	view.configure(content, {"progress_loaded": true, "progress": progress})
	await _settle()


func _capture_layouts(view, content: Dictionary, progress: Dictionary) -> void:
	# This is existing vocabulary artwork in a UI fixture, not reviewed course art.
	var illustrated: Dictionary = content.duplicate(true)
	illustrated.module_words[0].image = "res://assets/images/word-library/bank.webp"
	check(DirAccess.make_dir_recursive_absolute(CAPTURE_DIRECTORY) == OK, "The library creates its visual evidence directory")
	for dimensions in [Vector2i(1280, 720), Vector2i(768, 1024), Vector2i(390, 844), Vector2i(320, 568)]:
		root.size = dimensions
		view.configure(illustrated, {"progress_loaded": true, "progress": progress})
		view.fit(1.0)
		await _settle()
		await _capture("%dx%d-list" % [dimensions.x, dimensions.y])
		view._row_buttons[0].pressed.emit()
		await _settle()
		check(view.snapshot().image_count == 1, "The selected library sense retains one real picture")
		await _capture("%dx%d-detail" % [dimensions.x, dimensions.y])


func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	check(picture != null and not picture.is_empty() and picture.save_png(CAPTURE_DIRECTORY + "/" + filename + ".png") == OK,
		"The real word library renders " + filename)
