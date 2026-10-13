extends SceneTree

const Backdrop = preload("res://scripts/jelly_backdrop.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Style = preload("res://scripts/ui_style.gd")
var checks := 0
var failures := 0

class ReducedSystemPreferences extends "res://scripts/presentation_preferences.gd":
	func load_preferences(_system_default: bool) -> void:
		# Supply the system's startup preference without a later motion toggle.
		super.load_preferences(true)


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle(count: int = 5) -> void:
	for frame in range(count):
		await process_frame


func cloud_positions(backdrop) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for cloud: TextureRect in backdrop._clouds:
		positions.append(cloud.position)
	return positions


func check_input_ignored(backdrop, context: String) -> void:
	check(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE and backdrop.focus_mode == Control.FOCUS_NONE,
		context + ": scenery cannot take pointer input or keyboard focus")
	for child: Control in backdrop.find_children("*", "Control", true, false):
		check(child.mouse_filter == Control.MOUSE_FILTER_IGNORE and child.focus_mode == Control.FOCUS_NONE,
			context + ": " + child.name + " cannot take pointer input or keyboard focus")


func check_frozen(backdrop, context: String) -> void:
	var elapsed: float = backdrop._elapsed
	var positions := cloud_positions(backdrop)
	check(not backdrop.is_processing(), context + ": cloud processing is disabled")
	await settle()
	check(backdrop._elapsed == elapsed and cloud_positions(backdrop) == positions,
		context + ": real frames leave the cloud clock and positions unchanged")


func check_advances(backdrop, context: String) -> void:
	var elapsed: float = backdrop._elapsed
	var positions := cloud_positions(backdrop)
	check(backdrop.is_processing() and backdrop.is_visible_in_tree(), context + ": visible clouds process during play")
	await settle()
	check(backdrop._elapsed > elapsed and cloud_positions(backdrop) != positions,
		context + ": real frames advance the clock and move the cloud artwork")


func check_resume(backdrop, elapsed: float, positions: Array[Vector2], context: String) -> void:
	check(backdrop.is_processing() and backdrop._elapsed == elapsed and cloud_positions(backdrop) == positions,
		context + ": resuming preserves the current cloud phase without replay or catch-up")
	await check_advances(backdrop, context)


func check_standalone() -> void:
	var holder := Control.new()
	root.add_child(holder)
	var backdrop := Backdrop.new()
	var redraws: Array[int] = [0]
	backdrop.draw.connect(func() -> void: redraws[0] += 1)
	holder.add_child(backdrop)
	backdrop.size = Vector2(393, 852)
	await settle()
	check(backdrop._clouds.size() == 2 and backdrop._clouds.all(func(cloud: TextureRect) -> bool: return cloud.texture != null and cloud.texture.get_width() > 0),
		"Two acquired cloud textures are available before animation starts")
	check_input_ignored(backdrop, "Standalone garden")
	await check_frozen(backdrop, "An inactive garden")
	backdrop.set_ambient_active(true)
	await check_advances(backdrop, "An active garden")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var initial_redraws: int = redraws[0]
		await settle(12)
		await RenderingServer.frame_post_draw
		check(initial_redraws > 0 and redraws[0] == initial_redraws,
			"Rendered cloud movement leaves the static garden drawing cached")

	# Exercise an entire combined cycle at each shape without waiting in real time.
	# Bounds and speed are user-visible constraints, independent of a sine formula.
	for dimensions: Vector2i in [Vector2i(393, 852), Vector2i(1473, 1175), Vector2i(320, 568), Vector2i(852, 393)]:
		root.size = dimensions
		backdrop.size = Vector2(dimensions)
		await settle()
		var maximum_offset := 0.0
		var maximum_step := 0.0
		var vertical_still := true
		var previous := cloud_positions(backdrop)
		var s := Style.ui_scale(backdrop)
		for step in range(960):
			backdrop._process(0.25)
			for index in range(backdrop._clouds.size()):
				var position: Vector2 = backdrop._clouds[index].position
				var origin: Vector2 = backdrop._cloud_origins[index]
				maximum_offset = maxf(maximum_offset, absf(position.x - origin.x) * s)
				maximum_step = maxf(maximum_step, absf(position.x - previous[index].x) * s)
				vertical_still = vertical_still and is_equal_approx(position.y, origin.y)
			previous = cloud_positions(backdrop)
		check(maximum_offset <= 8.01 and maximum_offset >= 7.0 and vertical_still,
			"Clouds move horizontally within eight CSS pixels at " + str(dimensions))
		check(maximum_step <= 0.26,
			"Cloud movement stays below one CSS pixel per second at " + str(dimensions))

	holder.hide()
	await check_frozen(backdrop, "A hidden ancestor")
	backdrop.size += Vector2(5, 5)
	backdrop.set_ambient_active(true)
	await check_frozen(backdrop, "Relayout and activation beneath a hidden ancestor")
	var elapsed: float = backdrop._elapsed
	var positions := cloud_positions(backdrop)
	holder.show()
	await check_resume(backdrop, elapsed, positions, "Showing the ancestor again")
	backdrop.set_reduced_motion(true)
	await check_frozen(backdrop, "Reduced motion in an otherwise active garden")
	backdrop.set_ambient_active(false)
	backdrop.set_reduced_motion(false)
	await check_frozen(backdrop, "Enabling motion in an inactive garden")
	holder.free()
	await process_frame


func check_application(mode: String) -> void:
	root.size = Vector2i(393, 852)
	var directory := "user://jelly-backdrop-test-%s-%d-%d" % [mode, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation = ReducedSystemPreferences.new()
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app._jelly.set_process(false)
	app._word_jelly.set_process(false)
	Fixture.enter_mode(app, mode)
	var backdrop = app._jelly_backdrop
	var view = app._active_jelly()
	view.set_process(false)
	check(app._mode_id == mode and app._jelly_interaction_allowed() and view.game.phase == "playing",
		mode + ": the real Home route starts an interactive round")
	check(app.reduced_motion and backdrop.is_visible_in_tree(),
		mode + ": the loaded system motion preference keeps the garden artwork visible")
	await check_frozen(backdrop, mode + " initial system reduced motion")
	check_input_ignored(backdrop, mode)
	check(backdrop.get_parent() == app._content_margins.get_parent() and backdrop.get_index() < app._content_margins.get_index(),
		mode + ": garden and cloud children remain behind the complete game area")
	app.set_reduced_motion(false)
	await check_advances(backdrop, mode + " motion enabled")

	var round_id: String = app._round_id
	app._mode_heading_button.pressed.emit()
	check(app._mode_menu_open(), mode + ": the Home button opens Home")
	await check_frozen(backdrop, mode + " Home")
	app.on_page_hidden()
	app.on_page_visible()
	await check_frozen(backdrop, mode + " foregrounded while Home remains open")
	app.set_reduced_motion(true)
	app.set_reduced_motion(false)
	await check_frozen(backdrop, mode + " motion enabled while Home remains open")
	var elapsed: float = backdrop._elapsed
	var positions := cloud_positions(backdrop)
	app.choose_mode(mode)
	check(app._round_id == round_id and not app._mode_menu_open(), mode + ": choosing the same game resumes its existing round")
	await check_resume(backdrop, elapsed, positions, mode + " returning from Home")

	app.collection_button.pressed.emit()
	check(app.collection_page.visible and not backdrop.is_visible_in_tree(), mode + ": the notebook owns its background")
	await check_frozen(backdrop, mode + " notebook")
	app.on_page_hidden()
	app.on_page_visible()
	await check_frozen(backdrop, mode + " foregrounded while the notebook remains open")
	app.set_reduced_motion(true)
	app.set_reduced_motion(false)
	await check_frozen(backdrop, mode + " motion enabled while the notebook remains open")
	elapsed = backdrop._elapsed
	positions = cloud_positions(backdrop)
	app._collection_back.pressed.emit()
	check(not app.collection_page.visible and app._round_id == round_id, mode + ": Back restores the same game from the notebook")
	await check_resume(backdrop, elapsed, positions, mode + " returning from notebook")

	app.on_page_hidden()
	check(not backdrop.is_visible_in_tree(), mode + ": a backgrounded page hides the garden")
	await check_frozen(backdrop, mode + " backgrounded page")
	app.set_reduced_motion(true)
	app.set_reduced_motion(false)
	await check_frozen(backdrop, mode + " motion enabled on a backgrounded page")
	elapsed = backdrop._elapsed
	positions = cloud_positions(backdrop)
	app.on_page_visible()
	await check_resume(backdrop, elapsed, positions, mode + " foregrounded game")

	app.set_reduced_motion(true)
	await check_frozen(backdrop, mode + " system reduced motion during play")
	app.set_reduced_motion(false)
	await check_advances(backdrop, mode + " restored system motion during play")

	app._mode_heading_button.pressed.emit()
	app._mode_panel.collection_button.pressed.emit()
	check(app.collection_page.visible and not backdrop.is_visible_in_tree(), mode + ": Home can open the notebook")
	app._collection_back.pressed.emit()
	check(app._mode_menu_open() and not app.collection_page.visible, mode + ": notebook Back returns to Home when opened there")
	await check_frozen(backdrop, mode + " Home after notebook Back")
	app.choose_mode(mode)
	await check_advances(backdrop, mode + " returning from nested navigation")

	view.finish_button.pressed.emit()
	check(app._finish_confirmation_open() and view.game.phase == "playing", mode + ": Finish asks before ending the round")
	await check_frozen(backdrop, mode + " finish confirmation")
	app._finish_confirmation.finish_button.pressed.emit()
	check(view.game.phase == "finished", mode + ": Finish ends the active round")
	await check_frozen(backdrop, mode + " finished round")
	view.replay_button.pressed.emit()
	view.set_process(false)
	check(view.game.phase == "playing", mode + ": Play again starts a new round")
	await check_advances(backdrop, mode + " replay")
	Fixture.enter_mode(app, "match")
	check(app._mode_id == "match" and not backdrop.is_visible_in_tree(), mode + ": regular Match has no Jelly scenery")
	await check_frozen(backdrop, mode + " after leaving the Jelly modes")
	app.audio.halt()
	app.free()
	await process_frame
	for filename: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	await check_standalone()
	if not OS.get_cmdline_user_args().has("--render-backdrop-only"):
		for mode: String in ["jelly", "word_jelly"]:
			await check_application(mode)
	print("Jelly garden lifecycle: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
