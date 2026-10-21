extends "res://tests/godot/unified_word_library_tests.gd"
## Real gameplay UI with reviewed synthetic vocabulary; career curriculum stays gated.

const OUTPUT: String = "res://build/professional-gameplay"
var captures: Array[Dictionary] = []


func _initialize() -> void:
	_capture_run.call_deferred()


func _capture_frames() -> void:
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw


func _capture_screen(label: String, celebration: bool = false) -> void:
	await _capture_frames()
	var image: Image = root.get_texture().get_image()
	var destination: String = OUTPUT + "/" + label + ".png"
	check(image.save_png(destination) == OK, "Save gameplay capture " + label)
	var header: Rect2 = app._header.get_global_rect().grow(8.0).intersection(Rect2(Vector2.ZERO, Vector2(image.get_size())))
	var header_path: String = OUTPUT + "/" + label + "-header.png"
	check(image.get_region(Rect2i(header)).save_png(header_path) == OK, "Save header detail " + label)
	check(app.duck.professional_profile.get("course_id") == app._round_context.course_id,
		"The gameplay companion retains the active career while rendering " + label)
	check(app._growth_button.is_visible_in_tree() and not app._professional_button.is_visible_in_tree(),
		"The shared Pip badge remains the sole career progress control in " + label)
	var evidence: Dictionary = {"image": destination, "header": header_path, "fixture_content": true,
		"viewport": [root.size.x, root.size.y], "context": app._round_context.duplicate(true),
		"pip": app.duck.professional_profile.duplicate(true), "level": app._growth_button.level_label.text,
		"career_label": app._growth_button.context_label.text,
		"accessible_context": str(app._growth_button.get("accessibility_name")),
		"header_rect": [header.position.x, header.position.y, header.size.x, header.size.y]}
	if celebration:
		evidence["celebration"] = app._round_celebration.snapshot()
		evidence["celebration_pip"] = app._round_celebration.pip.professional_profile.duplicate(true)
		check(app._round_celebration.is_active() and app._round_celebration.pip.professional_profile.get("course_id") == app._round_context.course_id,
			"The shared chest celebration keeps this career's Pip appearance")
	captures.append(evidence)


func _capture_chest_celebration(course: String) -> void:
	# This isolated reservation selects a deterministic reward, as in the existing
	# gameplay fixtures. It never marks production curriculum or a user's save ready.
	Fixture.earn_pair_chest(app)
	app.model.phase = "won"
	app._refresh()
	app._begin_round_celebration(1)
	check(app._round_celebration.is_active(), "The fixture enters the actual shared chest celebration")
	app._round_celebration.set_process(false)
	app._round_celebration.set_narration_playing(false)
	var elapsed: float = float(app._round_celebration.snapshot().elapsed)
	app._round_celebration.advance(maxf(0.0, 2.65 - elapsed))
	app._round_celebration.set_process(false)
	await _capture_screen("phone-" + course + "-celebration", true)


func _capture_run() -> void:
	check(DisplayServer.get_name() != "headless", "Gameplay visual review requires a renderer")
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	check(DirAccess.make_dir_recursive_absolute(OUTPUT) == OK, "Create the gameplay review output directory")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for course: String in ["retail", "nursing"]:
		root.size = Vector2i(390, 844)
		directory = "user://professional-gameplay-review-%s-%d-%d" % [course, OS.get_process_id(), Time.get_ticks_usec()]
		check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Isolate the " + course + " review saves")
		await _make_app()
		app.audio.set_muted(true)
		app.set_reduced_motion(true)
		await _use_course(course)
		await _start_professional_match()
		await _learn_terms(1 if course == "retail" else 3, "visual-" + course)
		check(app._round_context.course_id == course and app.professional.can_play(app._round_id),
			"The review uses a ready fixture round through the real vocabulary/game selection flow")
		for layout: Dictionary in [{"name": "compact", "size": Vector2i(320, 568)},
			{"name": "phone", "size": Vector2i(390, 844)},
			{"name": "desktop", "size": Vector2i(1280, 800)}]:
			root.size = layout.size
			await _settle()
			await _capture_screen(layout.name + "-" + course + "-match")
		if course == "retail":
			root.size = Vector2i(390, 844)
			await _settle()
			await _capture_chest_celebration(course)
		app.audio.halt()
		app.queue_free()
		await process_frame
		await process_frame
		for file: String in DirAccess.get_files_at(directory):
			check(DirAccess.remove_absolute(directory.path_join(file)) == OK, "Remove an isolated review save")
		check(DirAccess.remove_absolute(directory) == OK, "Remove the isolated review directory")
	var report := FileAccess.open(OUTPUT + "/review.json", FileAccess.WRITE)
	check(report != null, "Create the gameplay review report")
	if report != null:
		report.store_string(JSON.stringify({"fixture_content": true, "production_modules_unmodified": true,
			"captures": captures, "checks": checks, "failures": failures}, "\t"))
		report.close()
	print("Professional gameplay visual review: %d captures, %d checks, %d failures" % [captures.size(), checks, failures])
	quit(1 if failures else 0)
