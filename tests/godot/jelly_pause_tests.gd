extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func _key(app, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	app._input(event)


func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-pause")
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/qa/jelly-pause/" + name + ".png") == OK,
		"Capture the actual responsive pause menu")


func _check_mode(app, mode: String) -> void:
	Fixture.enter_mode(app, mode)
	await settle()
	var view = app._active_jelly()
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	view.game.step(2.0)
	var pause_button: Button = app.get("_jelly_pause_button")
	var menu = app.get("_jelly_pause_menu")
	check(pause_button != null and menu != null, mode + ": the real header exposes a Pause control and resume menu")
	if pause_button == null or menu == null:
		return
	for dimensions: Vector2i in [Vector2i(320, 480), Vector2i(393, 852), Vector2i(844, 390), Vector2i(1366, 768)]:
		root.size = dimensions
		await settle()
		var s: float = app.Style.ui_scale(app)
		var button_rect: Rect2 = pause_button.get_global_rect()
		check(pause_button == view.finish_button and pause_button.is_visible_in_tree() and not pause_button.disabled
			and app._header.get_global_rect().grow(0.1).encloses(button_rect)
			and button_rect.size.x * s >= 43.9 and button_rect.size.y * s >= 43.9
			and not button_rect.intersects(view._header_chest_host.get_global_rect())
			and not button_rect.intersects(app._mode_heading.get_global_rect()),
			mode + ": the original pull control pauses on a tap without adding a second header button at " + str(dimensions))
		var round_id: String = app._round_id
		pause_button.pressed.emit()
		check(app._jelly_pause_open() and view.game.paused and not app._jelly_interaction_allowed()
			and menu._heading.text == "Paused" and menu.keep_playing_button.text == "Resume"
			and menu.finish_button.text == "Finish round" and app._round_id == round_id,
			mode + ": Pause stops the same unfinished round without finishing or collecting anything")
		check(view.finish_button.is_visible_in_tree() and view.finish_button.snapshot().tap_hint
			and menu._caption.text.contains("Pull down"),
			mode + ": the same button retains its downward teaching animation and explains the finish gesture")
		check(root.gui_get_focus_owner() == menu.keep_playing_button and app._focus_candidates().size() == 2,
			mode + ": pause focus stays on the two explicit menu actions")
		var before: Dictionary = view.game.snapshot()
		var balance: int = app.coin_wallet.balance
		for frame in range(12):
			view._process(0.20)
			app._advance_ui(0.20)
		app._request_jelly_finish(mode)
		app._show_collection()
		app._show_mode_menu()
		check(view.game.snapshot() == before and app.coin_wallet.balance == balance and app._jelly_pause_open()
			and not app.collection_page.visible and not app._mode_menu_open() and app._round_result.is_empty(),
			mode + ": paused supply, danger, combo, operations and wallet remain unchanged and background actions are blocked")
		var focus_next := InputEventAction.new()
		focus_next.action = "ui_focus_next"
		focus_next.pressed = true
		app._input(focus_next)
		check(root.gui_get_focus_owner() == menu.finish_button, mode + ": Tab stays inside the pause menu")
		app._input(focus_next)
		check(root.gui_get_focus_owner() == menu.keep_playing_button, mode + ": pause focus wraps to Resume")
		for button: Button in [menu.keep_playing_button, menu.finish_button]:
			check(Rect2(Vector2.ZERO, app.size).grow(0.1).encloses(button.get_global_rect())
				and button.size.y * s >= 43.9, mode + ": pause actions remain readable and tappable")
		await _capture("%s-%dx%d" % [mode, dimensions.x, dimensions.y])
		app.on_page_hidden()
		menu.keep_playing_button.pressed.emit()
		check(app._jelly_pause_open() and view.game.paused, mode + ": a hidden page cannot consume Resume")
		app.on_page_visible()
		check(app._jelly_pause_open() and view.game.paused, mode + ": foregrounding does not silently unpause the game")
		menu.keep_playing_button.pressed.emit()
		check(not app._jelly_pause_open() and not view.game.paused and app._round_id == round_id,
			mode + ": Resume restores the same round at the exact paused clock")
		var elapsed: float = view.game.spawn_elapsed
		view._process(0.10)
		check(view.game.spawn_elapsed > elapsed, mode + ": supply resumes only after deliberate Resume")
	_key(app, KEY_P)
	check(app._jelly_pause_open(), mode + ": P pauses the live Jelly game")
	_key(app, KEY_ESCAPE)
	check(not app._jelly_pause_open() and not view.game.paused and not app._mode_menu_open(),
		mode + ": Escape resumes rather than navigating away from pause")
	pause_button.pressed.emit()
	menu.finish_button.pressed.emit()
	check(view.game.phase == "finished" and not app._jelly_pause_open() and app._round_end.is_active(),
		mode + ": the explicitly labelled Finish round action remains accessible without a pointer pull")
	Fixture.finish_celebration(app)
	check(app.new_round(4821, false, "", mode, "", false), mode + ": a new round follows the completed pause-menu finish")
	view.set_process(false)
	pause_button.pressed.emit()
	check(app.new_round(4821, false, "", mode, "", false) and not app._jelly_pause_open()
		and app._active_jelly().game.phase == "playing", mode + ": a replacement round clears its old pause owner")
	app._active_jelly().set_process(false)
	app._active_jelly().game.finish_round()
	check(not pause_button.is_visible_in_tree() or pause_button.disabled,
		mode + ": an ended game cannot reopen Pause over settlement")
	Fixture.finish_celebration(app)


func _check_word_effect_pause(app) -> void:
	check(app.new_round(4821, false, "", "word_jelly", "", false), "The animated-pause case starts a real Jelly Words round")
	var view = app._word_jelly
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	view.game.cells.clear()
	var word: Dictionary = view.game._words[0]
	var source: Dictionary = view.game._new_word_root(word)
	view.game._set_merged_word(source, word, 2, false)
	var target: Dictionary = view.game._new_word_root(word)
	var picture: Dictionary = view.game._new_picture_tile(word)
	for index in range(3):
		var tile: Dictionary = [source, target, picture][index]
		tile.column = [2, 1, 4][index]
		tile.row = 7
		tile.age = 100.0
		tile.falling = false
		tile.arrival = false
		tile.settling = false
		view.game.cells.append(tile)
	view._sync_tiles()
	view._layout()
	view._collect(int(source.id))
	view._process(0.42)
	view._process(0.01)
	view._process(0.20)
	check(view.game.powerup_active() and view._word_reveal.snapshot().active_count > 0,
		"The pause fixture reaches a real marking and visible collected-word effect")
	app._jelly_pause_button.pressed.emit()
	var game_before: Dictionary = view.game.snapshot()
	var effects: Dictionary = view._word_reveal.snapshot()
	var particles: Dictionary = view._collection_effects.snapshot()
	for frame in range(15):
		view._process(0.20)
		app._advance_ui(0.20)
	check(view.game.snapshot() == game_before and view._word_reveal.snapshot() == effects
		and view._collection_effects.snapshot() == particles and effects.active_count > 0,
		"Explicit Pause freezes and preserves the actual popover, firework and marking clocks instead of deleting effects")
	app.on_page_hidden()
	app.on_page_visible()
	check(view.game.snapshot() == game_before and view._word_reveal.snapshot() == effects,
		"Backgrounding during manual pause retains the same frozen collected-word effect")
	app._jelly_pause_menu.keep_playing_button.pressed.emit()
	for frame in range(100):
		view._process(0.04)
	check(not view.game.powerup_active() and not view.game.paused and view.game.merged_count == 1
		and view.game.cleared_pairs == 1, "Resuming a marking sequence completes one assisted merge without a second collection")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	var directory: String = "user://jelly-pause-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_process(false)
	for mode: String in ["jelly", "word_jelly"]:
		await _check_mode(app, mode)
	if app.get("_jelly_pause_button") != null:
		_check_word_effect_pause(app)
	app.audio.halt()
	app.free()
	await settle()
	for filename: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("Jelly Pause: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
