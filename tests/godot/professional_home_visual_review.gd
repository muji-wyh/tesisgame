extends SceneTree
## Render the shared Home with real career artwork and isolated progress fixtures.

const Home = preload("res://scripts/game_library.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
const Context = preload("res://scripts/learning_context.gd")
const Progress = preload("res://scripts/professional_progress.gd")
const PipProgress = preload("res://scripts/professional_pip_progress.gd")
const OUTPUT: String = "res://build/professional-home"

var captures: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _settle() -> void:
	for frame in range(8):
		await process_frame


func _capture(home: Home, name: String) -> void:
	home.scroll.scroll_vertical = 0
	await _settle()
	await RenderingServer.frame_post_draw
	var path: String = OUTPUT + "/" + name + ".png"
	assert(root.get_texture().get_image().save_png(path) == OK)
	var snapshot: Dictionary = home.snapshot()
	captures.append({"image": path, "viewport": [root.size.x, root.size.y],
		"brand": snapshot.brand, "vocabulary": snapshot.vocabulary, "hero": snapshot.hero,
		"career": snapshot.pip_profile, "recovery": snapshot.recovery})


func _profile(course: Dictionary, count: int, context: Dictionary) -> Dictionary:
	var saved: Dictionary = Progress.empty_progress()
	var added: int = 0
	for module: Dictionary in course.modules:
		for id: String in module.lexeme_ids:
			if saved.skills.has(id):
				continue
			if added >= count:
				break
			saved.skills[id] = {"recognition": {"earned": true, "streak": 3, "exposures": 3}}
			added += 1
	return PipProgress.summary(course, {"progress_loaded": true, "blocked": false,
		"pending_count": 0, "progress": saved}, context)


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Home visual review requires a renderer.")
	assert(DirAccess.make_dir_recursive_absolute(OUTPUT) == OK)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var catalog := Catalog.new()
	assert(catalog.load_index())
	var home := Home.new()
	root.add_child(home)
	home.configure("", true, true)
	home.set_home_coins(240)
	home.configure_growth({"ready": true, "age": 6, "learning_age": 7,
		"mastered": 12, "total": 70, "progress": 12.0 / 70.0, "lifetime_mastered": 165})
	for layout: Dictionary in [{"name": "desktop", "size": Vector2i(1280, 800)},
		{"name": "phone", "size": Vector2i(390, 844)}, {"name": "compact", "size": Vector2i(320, 568)}]:
		root.size = layout.size
		home.configure_learning(catalog, Context.growth(7, "word_jelly"), {"phase": "idle"})
		home.configure_professional({})
		for button: Button in home.buttons:
			button.disabled = false
		home.fit(Vector2(layout.size), 1.0)
		await _settle()
		home.fit(Vector2(layout.size), 1.0)
		await _capture(home, layout.name + "-everyday")
		for career: Dictionary in [{"id": "retail", "mastered": 18}, {"id": "nursing", "mastered": 53},
			{"id": "manufacturing_maintenance", "mastered": 112}]:
			var course: Dictionary = catalog.course(career.id)
			var context: Dictionary = Context.professional(course.id, course.modules[0].id, course.curriculum_revision, "word_jelly")
			home.configure_learning(catalog, context, {"phase": "idle"})
			home.configure_professional(_profile(course, career.mastered, context))
			for button: Button in home.buttons:
				button.disabled = not home.learning._selected_ready()
			home.fit(Vector2(layout.size), 1.0)
			await _settle()
			home.fit(Vector2(layout.size), 1.0)
			await _capture(home, layout.name + "-" + career.id)
		var selected: Dictionary = home.snapshot().vocabulary.selection
		home.configure_learning(catalog, selected, {"phase": "media"})
		home.fit(Vector2(layout.size), 1.0)
		await _capture(home, layout.name + "-loading")
	var report := FileAccess.open(OUTPUT + "/review.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({"captures": captures}, "\t"))
	report.close()
	home.queue_free()
	await process_frame
	print("Professional Home visual review: %d captures" % captures.size())
	quit()
