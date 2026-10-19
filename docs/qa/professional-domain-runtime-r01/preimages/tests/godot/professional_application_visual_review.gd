extends SceneTree
## Actual application layouts with clearly synthetic, non-curriculum content.

const Flow = preload("res://tests/godot/professional_application_flow_tests.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const MediaFixture = preload("res://tests/godot/professional_round_loader_tests.gd")
const Context = preload("res://scripts/learning_context.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
const OUTPUT := "res://build/professional-english/application-review"

class RenderCatalog extends Flow.Catalog:
	func resolve(context: Dictionary, seed_value: int = -1) -> Dictionary:
		var result: Dictionary = super.resolve(context, seed_value)
		result.course_title = "Retail & Store Service"
		result.module_title = "Workplace spaces and equipment"
		for words in [result.words, result.module_words]:
			for word in words:
				word.definition = "A synthetic application-layout fixture; not reviewed course content."
				word.example = "This example is for layout review only."
		return result

var app
var directory: String
var checks := 0
var failures := 0
var captures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for unused in range(12):
		await process_frame
	await RenderingServer.frame_post_draw


func capture(name: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png")) == OK, name + " screenshot saved")
	captures.append(name + ".png")


func in_view(control: Control) -> bool:
	return Rect2(Vector2.ZERO, Vector2(root.size)).grow(1).encloses(control.get_global_rect())


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Visual review requires a renderer")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	directory = "user://professional-app-review-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for layout in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]:
		root.size = layout
		var prefix: String = "%dx%d" % [layout.x, layout.y]
		var saved: String = directory.path_join(prefix)
		DirAccess.make_dir_recursive_absolute(saved)
		app = load("res://scenes/main.tscn").instantiate()
		Fixture.install(app, saved)
		app.medal_progress = preload("res://scripts/medal_progress.gd").new(saved + "/medals.cfg", saved + "/legacy.cfg")
		app._presentation.path = saved + "/presentation.cfg"
		app._presentation.muted = true
		app._presentation.reduced_motion = true
		app._presentation.save_preferences()
		app.professional.loader.media.free()
		app.professional.loader.media = MediaFixture.FixtureMedia.new()
		app.professional.loader.catalog = RenderCatalog.new()
		app.professional.loader.media.cache.values["sha256:" + MediaFixture.IMAGE_HASH] = load("res://assets/images/words/absent.png")
		app.professional.loader.media.cache.values["sha256:" + MediaFixture.AUDIO_HASH] = load("res://assets/audio/jelly-match/collect-do.wav")
		root.add_child(app)
		await settle()
		app._show_mode_menu()
		app._select_learning_context(Context.professional("retail", "module03", "v1", "match"))
		app.choose_mode("match")
		app.professional.loader.media.finish(app.professional.loader.media.generation)
		await settle()
		check(app._round_context.get("track") == "professional" and not app._mode_menu_open(), prefix + " actual Professional game prepared")
		check(app._professional_button.is_visible_in_tree() and in_view(app._professional_button), prefix + " career header is visible and in bounds")
		check(not app._growth_button.is_visible_in_tree() and not app.duck.visible, prefix + " Professional presentation suppresses Growth progress and Pip")
		check(app._professional_heading.get_global_rect().end.x <= app._professional_button.get_global_rect().end.x + 1,
			prefix + " long career title remains within its button")
		await capture(prefix + "-game")
		app._show_collection()
		await settle()
		check(in_view(app._collection_back) and in_view(app._professional_library._search), prefix + " library exit and search remain in bounds")
		check(in_view(app._professional_library.scroll), prefix + " library scrolling fits the actual application")
		check(app._professional_library.snapshot().visible_rows == 8 and app._professional_library.snapshot().image_count == 1,
			prefix + " library bounds rows and image residency")
		await capture(prefix + "-library")
		app._professional_library._select(0)
		await capture(prefix + "-detail")
		check(app._professional_library._hear.is_visible_in_tree(), prefix + " pronunciation remains reachable")
		app._hide_collection()
		check(app._professional_library.snapshot().image_count == 0, prefix + " library closes and releases its picture")
		app.audio.halt()
		app.queue_free()
		await settle()
		for file in DirAccess.get_files_at(saved):
			DirAccess.remove_absolute(saved.path_join(file))
		DirAccess.remove_absolute(saved)
	DirAccess.remove_absolute(directory)
	var report := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "captures": captures,
		"content": "Synthetic application fixture, not production curriculum or workplace art."}, "  ") + "\n")
	print("Professional application rendering: %d checks, %d failures; %d captures" % [checks, failures, captures.size()])
	quit(1 if failures else 0)
