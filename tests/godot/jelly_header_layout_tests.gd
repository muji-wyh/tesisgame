extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const SIZES: Array[Vector2i] = [Vector2i(320, 480), Vector2i(393, 852), Vector2i(624, 1119),
	Vector2i(768, 1024), Vector2i(834, 1194), Vector2i(1024, 1366), Vector2i(568, 320),
	Vector2i(844, 390), Vector2i(1024, 768), Vector2i(1366, 768), Vector2i(1473, 1175)]
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for frame in range(6):
		await process_frame

func tap(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func check_geometry(app, view, dimensions: Vector2i) -> void:
	var context: String = "%s at %s" % [app._mode_id, dimensions]
	var s: float = app.Style.ui_scale(app)
	var header: Rect2 = app._header.get_global_rect()
	var chest: Rect2 = view._chest_tap.get_global_rect()
	var board: Rect2 = view._global_rect(view._board)
	var tray: Rect2 = view.drop_button.get_global_rect()
	var finish: Rect2 = view.finish_button.get_global_rect()
	check(view.has_header_chest() and view._header_chest_host.is_visible_in_tree()
		and view._header_chest_host.get_parent() == app._header,
		context + " hosts the active chest in the real header")
	check(header.grow(0.1).encloses(chest) and chest.size.x * s >= 44.0 - 0.1
		and chest.size.y * s >= 44.0 - 0.1, context + " keeps a full chest touch target inside the header")
	check(header.grow(0.1).encloses(finish) and finish.size.y * s >= 44.0 - 0.1,
		context + " keeps Finish above gameplay")
	check(view._loot_meter.get_global_rect().is_equal_approx(chest)
		and chest.encloses(view._loot_icon.get_global_rect()), context + " aligns the chest ring, artwork, and hit target")
	check(view._reward_presentation._anchor.is_equal_approx(view.chest_anchor_rect())
		and view._global_rect(view.chest_anchor_rect()).is_equal_approx(view._loot_icon.get_global_rect()),
		context + " returns milestone and fragment flights to the hosted artwork")
	var controls: Array[Control] = [app._header_duck_slot, app._coin_counter, app._mode_heading_button,
		app._mode_heading, view.finish_button, app._storage_retry_button]
	for control: Control in controls:
		if control.is_visible_in_tree():
			check(not chest.intersects(control.get_global_rect()),
				context + " keeps treasure separate from " + control.name)
	check(view.get_global_rect().grow(0.1).encloses(board) and view.get_global_rect().grow(0.1).encloses(tray)
		and not board.intersects(tray), context + " keeps the full well and supply within gameplay")
	check(not board.intersects(chest) and not tray.intersects(chest) and not board.intersects(finish),
		context + " spends no playable cells on header actions")
	if app._mode_id == "jelly":
		check(is_equal_approx(board.size.x / board.size.y, 2.0 / 3.0), context + " preserves all four by six cells")
		check(absf(board.end.y - (view.get_global_rect().end.y - 8.0 / s)) < 0.1,
			context + " anchors gameplay above a small bottom margin")
	if dimensions.x >= 624 and dimensions.x < dimensions.y:
		check(board.size.x * s >= float(dimensions.x) * 0.74,
			context + " uses the portrait width for playable cells")
	if dimensions == Vector2i(834, 1194):
		check(app._content_margins.size.y * s > 1100.0,
			context + " uses portrait height instead of the old desktop cap")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	var directory: String = "user://jelly-header-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app._credit_coins("header-layout-wallet", 24691)
	for mode: String in ["jelly", "word_jelly"]:
		Fixture.enter_mode(app, mode)
		await settle()
		var view = app._active_jelly()
		view.set_process(false)
		for dimensions: Vector2i in SIZES:
			root.size = dimensions
			await settle()
			check_geometry(app, view, dimensions)
		root.size = Vector2i(393, 852)
		await settle()
		var before: Dictionary = view.game.snapshot()
		await tap(view._chest_tap)
		check(view._chest_tap.is_active(), mode + " receives a real pointer tap through the external header dock")
		check(view.game.snapshot() == before and view._pointer == view.NO_POINTER,
			mode + " chest sparkle neither grabs a jelly nor changes game state")
		view._chest_tap.clear()
		app._show_mode_menu()
		await settle()
		check(not view._header_chest_host.is_visible_in_tree() and not view.finish_button.is_visible_in_tree(),
			mode + " hides both externally hosted controls while Home owns input")
		app._hide_mode_menu()
		await settle()
		check(view._header_chest_host.is_visible_in_tree() and view.finish_button.is_visible_in_tree(),
			mode + " restores its hosted controls when gameplay resumes")
		await tap(view.finish_button)
		check(app._finish_confirmation_open() and view.game.phase == "playing",
			mode + " real header Finish still requires confirmation")
		app._finish_confirmation.keep_playing_button.pressed.emit()
		await settle()
		check(not app._finish_confirmation_open() and view._header_chest_host.is_visible_in_tree(),
			mode + " cancellation restores the same active chest")
		app._storage_retry_button.show()
		app._layout_game_heading()
		check_geometry(app, view, root.size)
		app._storage_retry_button.hide()
		app._layout_game_heading()
	check(not app._jelly._header_chest_host.is_visible_in_tree() and not app._jelly.finish_button.is_visible_in_tree(),
		"Switching to Words leaves no Match header controls behind")
	app.audio.halt()
	app.queue_free()
	await settle()
	print("Jelly header layout: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
