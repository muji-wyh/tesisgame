extends SceneTree

const Library = preload("res://scripts/game_library.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var library := Library.new()
	root.add_child(library)
	library.configure("word_jelly", false, false)
	check(library.buttons.size() == 6, "Every game has a library entry")
	check(library.buttons.back().button_pressed, "Jelly Words is identified as the current game")
	for dimensions: Vector2 in [Vector2(320, 320), Vector2(390, 420), Vector2(390, 600), Vector2(390, 844), Vector2(844, 390), Vector2(1280, 800)]:
		root.size = dimensions
		var available := dimensions - Vector2(24, 24)
		library.fit(available, 1.0)
		await settle()
		library.fit(available, 1.0)
		await settle()
		library.position = (dimensions - library.size) * 0.5
		var bounds := Rect2(Vector2.ZERO, dimensions)
		check(bounds.grow(1).encloses(library.get_global_rect()), "%s: the complete library fits" % dimensions)
		for button: Button in library.buttons + [library.close_button, library.sound_button, library.motion_button]:
			check(bounds.grow(1).encloses(button.get_global_rect()), "%s: %s stays on screen" % [dimensions, button.name])
			check(button.size.y >= 43, "%s: %s keeps a touch target" % [dimensions, button.name])
		for tile: Dictionary in library._tiles:
			check(tile.button.get_global_rect().grow(1).encloses(tile.title.get_global_rect()), "%s: %s title fits its card" % [dimensions, tile.entry.title])
	library.queue_free()
	await process_frame
	print("Six-game library: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
