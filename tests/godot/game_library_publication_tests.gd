extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")

class ObservedApp extends "res://scripts/game_ui.gd":
	var library_publications: Array[bool] = []
	func _publish_library() -> void:
		if is_instance_valid(_mode_panel):
			library_publications.append(_mode_panel.is_visible_in_tree())
		super._publish_library()

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

func _run() -> void:
	root.size = Vector2i(1366, 768)
	var directory: String = "user://library-publication-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Use isolated library-publication saves")
	var app := ObservedApp.new()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app.size = Vector2(root.size)
	root.add_child(app)
	await settle()
	app.set_process(false)
	app.audio.set_muted(true)
	app._hide_mode_menu(false, false)
	await settle()
	check(not app._mode_menu_open(), "The real home menu closes before the gameplay publication check")
	app.library_publications.clear()
	app._celebration_publish_left = 0.05
	for tick in range(40):
		app._advance_ui(0.025)
	check(app.library_publications.is_empty(),
		"One second of gameplay does not rebuild the hidden home-library snapshot")
	app._publish_library()
	check(app.library_publications == [false],
		"An explicit hidden-library publication still reports its current visibility")
	app._show_mode_menu()
	await settle()
	check(app._mode_menu_open() and not app.library_publications.is_empty() and app.library_publications.back(),
		"Opening Home explicitly publishes the visible library")
	app.library_publications.clear()
	app._celebration_publish_left = 0.05
	app._advance_ui(0.025)
	check(app.library_publications.is_empty(), "Visible Home retains its existing 50 ms publication interval")
	app._advance_ui(0.025)
	check(app.library_publications == [true], "Visible Home publishes on the next original timer boundary")
	app._advance_ui(0.025)
	app._advance_ui(0.025)
	check(app.library_publications == [true, true], "Visible Home continues publishing at the original cadence")
	app._hide_mode_menu(false, false)
	await settle()
	check(not app._mode_menu_open() and not app.library_publications.is_empty() and not app.library_publications.back(),
		"Closing Home explicitly publishes hidden state without waiting for a periodic tick")
	app.library_publications.clear()
	for tick in range(40):
		app._advance_ui(0.025)
	check(app.library_publications.is_empty(), "The closed library stays out of later gameplay frames")
	app.audio.halt()
	app.queue_free()
	await settle()
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Game library publication checks: %d; failures: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)
