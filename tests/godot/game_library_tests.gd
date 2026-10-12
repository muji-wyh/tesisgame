extends SceneTree

const Library = preload("res://scripts/game_library.gd")
var checks := 0
var failures := 0
var chosen := ""
var collection_visits := 0

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
	library.mode_requested.connect(func(id: String) -> void: chosen = id)
	library.collection_requested.connect(func() -> void: collection_visits += 1)
	library.configure("", false, true)
	check(library.buttons.size() == 6, "Home offers all six supported games")
	check(not library.buttons.any(func(button: Button) -> bool: return button.button_pressed),
		"A first visit to Home does not claim a current game")
	check(library.find_child("LibraryClose", true, false) == null, "Home has no menu dismissal button")
	library.configure("word_jelly", false, true)
	check(library.buttons.back().button_pressed, "Home identifies the resumable Jelly Words game")
	library.pip.set_idle_paused(true)
	library.configure("word_jelly", false, true)
	check(library.pip._idle_paused, "Refreshing Home settings cannot resume Pip while the page is in the background")
	library.pip.set_idle_paused(false)
	library.set_growth_age(6)
	library.set_home_coins(123)
	check(library.pip.growth_age == 6, "Home uses the player's current Pip age")
	library.collection_button.pressed.emit()
	check(collection_visits == 1, "Home requests the collection once")
	for dimensions: Vector2 in [Vector2(320, 320), Vector2(390, 420), Vector2(390, 600), Vector2(390, 844), Vector2(844, 390), Vector2(1280, 800)]:
		root.size = dimensions
		library.position = Vector2.ZERO
		library.fit(dimensions, 1.0)
		await settle()
		library.fit(dimensions, 1.0)
		await settle()
		var bounds := Rect2(Vector2.ZERO, dimensions)
		check(bounds.grow(1).encloses(library.get_global_rect()) and library.size.is_equal_approx(dimensions),
			"%s: Home fills the viewport without overflowing" % dimensions)
		for tile: Dictionary in library._tiles:
			library.ensure_mode_visible(str(tile.entry.id))
			await settle()
			var button: Button = tile.button
			var scroll_bounds: Rect2 = library.scroll.get_global_rect()
			check(button.size.x >= 43 and button.size.y >= 43,
				"%s: %s keeps a comfortable touch target" % [dimensions, button.name])
			check(scroll_bounds.grow(1).encloses(button.get_global_rect()) and bounds.grow(1).encloses(button.get_global_rect()),
				"%s: scrolling fully reveals %s" % [dimensions, button.name])
			check(button.get_global_rect().grow(1).encloses(tile.title.get_global_rect()),
				"%s: the %s title fits its card" % [dimensions, tile.entry.title])
			button.grab_focus()
			await settle()
			check(button.has_focus() and library.scroll.get_global_rect().has_point(button.get_global_rect().get_center()),
				"%s: keyboard focus reveals %s" % [dimensions, button.name])
			button.pressed.emit()
			check(chosen == tile.entry.id, "Each Home card requests its own game: " + str(tile.entry.id))
		for button: Button in [library.sound_button, library.motion_button, library.collection_button]:
			button.grab_focus()
			await settle()
			check(bounds.grow(1).encloses(button.get_global_rect()) and button.size.y >= 43,
				"%s: focused %s stays reachable" % [dimensions, button.name])
		if dimensions == Vector2(320, 320):
			check(library.scroll.get_v_scroll_bar().max_value > library.scroll.get_v_scroll_bar().page,
				"A small Home viewport scrolls instead of cramping every game into a tiny row")
	root.size = Vector2i(640, 400)
	library.fit(Vector2(640, 400), 2.0)
	await settle()
	check(library.pip.size.is_equal_approx(Vector2(56, 56))
		and library.pip.get_global_rect().end.x < library.heading.get_global_rect().position.x,
		"A scaled Home portrait keeps its authored CSS size and clear separation from the welcome text")
	library.queue_free()
	await process_frame
	print("Game homepage: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
