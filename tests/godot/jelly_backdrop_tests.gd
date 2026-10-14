extends SceneTree

const Backdrop = preload("res://scripts/jelly_backdrop.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
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


func ambient_state(backdrop) -> Dictionary:
	var state: Dictionary = backdrop.snapshot()
	return {"yaw": state.yaw, "warmth": state.warmth, "light_strength": state.light_strength}


func game_geometry(view) -> Dictionary:
	var state: Dictionary = view.snapshot()
	var geometry := {"board": state.board_rect, "preview": state.preview.rect,
		"finish": state.finish.rect, "loot": state.loot.rect}
	if state.has("collect_button"):
		geometry.collect = state.collect_button.rect
		for kind: String in state.powerup_buttons:
			geometry[kind] = state.powerup_buttons[kind].rect
	return geometry


func check_input_ignored(backdrop, context: String) -> void:
	check(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE and backdrop.focus_mode == Control.FOCUS_NONE,
		context + ": scenery cannot take pointer input or keyboard focus")
	for child: Control in backdrop.find_children("*", "Control", true, false):
		check(child.mouse_filter == Control.MOUSE_FILTER_IGNORE and child.focus_mode == Control.FOCUS_NONE,
			context + ": " + child.name + " cannot take pointer input or keyboard focus")


func check_frozen(backdrop, context: String) -> void:
	var elapsed: float = backdrop._elapsed
	var state := ambient_state(backdrop)
	check(not backdrop.is_processing(), context + ": sky and daylight processing is disabled")
	await settle()
	check(backdrop._elapsed == elapsed and ambient_state(backdrop) == state,
		context + ": real frames leave the sky clock and daylight unchanged")


func check_advances(backdrop, context: String) -> void:
	var elapsed: float = backdrop._elapsed
	var state := ambient_state(backdrop)
	check(backdrop.is_processing() and backdrop.is_visible_in_tree(), context + ": visible sky and daylight process during play")
	await settle()
	check(backdrop._elapsed > elapsed and ambient_state(backdrop) != state,
		context + ": real frames advance the clock and atmospheric lighting")


func check_resume(backdrop, elapsed: float, state: Dictionary, context: String) -> void:
	check(backdrop.is_processing() and backdrop._elapsed == elapsed and ambient_state(backdrop) == state,
		context + ": resuming preserves the current sky and daylight phase without replay or catch-up")
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
	check(backdrop._sky.texture != null and backdrop._sky.texture.get_width() >= 1024,
		"The acquired panoramic sky is available at presentation resolution")
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
			"Rendered atmospheric motion leaves the static garden drawing cached")

	# Sample twenty minutes without waiting in real time. Bounds and continuity
	# protect quiet gameplay without depending on a specific lighting curve.
	for dimensions: Vector2i in [Vector2i(393, 852), Vector2i(1473, 1175), Vector2i(320, 568), Vector2i(852, 393)]:
		root.size = dimensions
		backdrop.size = Vector2(dimensions)
		await settle()
		check(is_equal_approx(float(backdrop.snapshot().aspect), float(dimensions.x) / dimensions.y),
			"Sky projection uses the resized viewport aspect at " + str(dimensions))
		check(backdrop._sky.get_global_rect().is_equal_approx(backdrop.get_global_rect()),
			"The panoramic layer covers the complete resized viewport at " + str(dimensions))
		var previous := ambient_state(backdrop)
		var minimum := previous.duplicate()
		var maximum := previous.duplicate()
		var finite_and_bounded := true
		var gentle_steps := true
		for step in range(4800):
			backdrop._process(0.25)
			var state := ambient_state(backdrop)
			for key: String in state:
				var value: float = state[key]
				minimum[key] = minf(minimum[key], value)
				maximum[key] = maxf(maximum[key], value)
				finite_and_bounded = finite_and_bounded and is_finite(value)
				if key != "yaw":
					finite_and_bounded = finite_and_bounded and value >= 0.0 and value <= 1.0
				gentle_steps = gentle_steps and absf(value - float(previous[key])) <= (0.005 if key == "yaw" else 0.02)
			previous = state
		check(finite_and_bounded, "Lighting remains finite and bounded at " + str(dimensions))
		check(gentle_steps, "Sky and lighting cross all cycle boundaries without visible jumps at " + str(dimensions))
		check(maximum.yaw > minimum.yaw and maximum.yaw - minimum.yaw <= 0.20,
			"The panorama gently drifts without sweeping around the board at " + str(dimensions))
		check(maximum.warmth > minimum.warmth and maximum.light_strength > minimum.light_strength,
			"Both daylight color and sunlight evolve during play at " + str(dimensions))
		check_input_ignored(backdrop, "Resized garden " + str(dimensions))
		var elapsed_before_invalid: float = backdrop._elapsed
		var state_before_invalid := ambient_state(backdrop)
		for delta: float in [0.0, -1.0, NAN, INF]:
			backdrop._process(delta)
		check(backdrop._elapsed == elapsed_before_invalid and ambient_state(backdrop) == state_before_invalid,
			"Invalid frame deltas cannot corrupt atmospheric state at " + str(dimensions))

	holder.hide()
	await check_frozen(backdrop, "A hidden ancestor")
	backdrop.size += Vector2(5, 5)
	backdrop.set_ambient_active(true)
	await check_frozen(backdrop, "Relayout and activation beneath a hidden ancestor")
	var elapsed: float = backdrop._elapsed
	var state := ambient_state(backdrop)
	holder.show()
	await check_resume(backdrop, elapsed, state, "Showing the ancestor again")
	backdrop.set_reduced_motion(true)
	await check_frozen(backdrop, "Reduced motion in an otherwise active garden")
	var neutral_state := ambient_state(backdrop)
	backdrop._elapsed += 83.0
	backdrop.size += Vector2(5, 5)
	await settle()
	check(ambient_state(backdrop) == neutral_state,
		"Reduced motion uses a stable neutral sky and daylight through resize and clock changes")
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
		mode + ": garden and daylight children remain behind the complete game area")
	app.set_reduced_motion(false)
	await check_advances(backdrop, mode + " motion enabled")
	for dimensions: Vector2i in [Vector2i(393, 852), Vector2i(1473, 1175), Vector2i(320, 568), Vector2i(852, 393)]:
		root.size = dimensions
		await settle()
		var geometry := game_geometry(view)
		for step in range(40):
			backdrop._process(0.25)
		check(game_geometry(view) == geometry,
			mode + ": ambient motion preserves all board and control geometry at " + str(dimensions))
	root.size = Vector2i(393, 852)
	await settle()

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
	var state := ambient_state(backdrop)
	app.choose_mode(mode)
	check(app._round_id == round_id and not app._mode_menu_open(), mode + ": choosing the same game resumes its existing round")
	await check_resume(backdrop, elapsed, state, mode + " returning from Home")

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
	state = ambient_state(backdrop)
	app._collection_back.pressed.emit()
	check(not app.collection_page.visible and app._round_id == round_id, mode + ": Back restores the same game from the notebook")
	await check_resume(backdrop, elapsed, state, mode + " returning from notebook")

	app.on_page_hidden()
	check(not backdrop.is_visible_in_tree(), mode + ": a backgrounded page hides the garden")
	await check_frozen(backdrop, mode + " backgrounded page")
	app.set_reduced_motion(true)
	app.set_reduced_motion(false)
	await check_frozen(backdrop, mode + " motion enabled on a backgrounded page")
	elapsed = backdrop._elapsed
	state = ambient_state(backdrop)
	app.on_page_visible()
	await check_resume(backdrop, elapsed, state, mode + " foregrounded game")

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

	view.finish_button.accessibility_requested.emit()
	check(app._finish_confirmation_open() and view.game.phase == "playing", mode + ": Finish asks before ending the round")
	await check_frozen(backdrop, mode + " finish confirmation")
	app._finish_confirmation.finish_button.pressed.emit()
	check(view.game.phase == "finished", mode + ": Finish ends the active round")
	await check_frozen(backdrop, mode + " finished round")
	app._jelly_rewards._back.pressed.emit()
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
