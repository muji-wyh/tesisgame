extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
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
		if app._mode_id == "word_jelly":
			# Five square columns retain the former minimum cell size while the
			# eight-row board becomes narrower on height-limited tablets.
			check(board.size.x * s / 5.0 >= float(dimensions.x) * 0.74 / 6.0
				and is_equal_approx(board.size.x / board.size.y, 5.0 / 8.0),
				context + " keeps five columns of playable square cells")
		else:
			check(board.size.x * s >= float(dimensions.x) * 0.74,
				context + " uses the portrait width for playable cells")
	if dimensions == Vector2i(834, 1194):
		check(app._content_margins.size.y * s > 1100.0,
			context + " uses portrait height instead of the old desktop cap")

func check_chest_levels(app, view, dimensions: Vector2i) -> void:
	var before: Dictionary = view.game.snapshot()
	var displayed_before: int = view._displayed_chest_tier
	var s: float = app.Style.ui_scale(app)
	var dock_before: Rect2 = view._header_chest_host.get_global_rect()
	var icon_before: Rect2 = view._loot_icon.get_global_rect()
	var label: Label = view._header_chest_level
	for tier: int in [0, 1, 10, 29, 30, 99, 999]:
		# Seed completed reward progress without creating pending celebration events.
		var fragments: int = 0 if tier == 0 else 4 + (tier - 1) * 5
		var progress: Dictionary = RewardProgress.reward_progress(fragments)
		var expected_tier: int = mini(tier, RewardProgress.MAX_TIER)
		view.game.fragment_count = fragments
		view.game.chest_tier = int(progress.chest_tier)
		view.game.chest_count = int(progress.chest_count)
		view._displayed_chest_tier = int(progress.chest_tier)
		view._refresh_hud()
		view._loot_meter.settle()
		var context: String = "%s Lv%d at %s" % [app._mode_id, tier, dimensions]
		var badge: Rect2 = label.get_global_rect()
		var font: Font = label.get_theme_font("font")
		var pixels: int = label.get_theme_font_size("font_size")
		var surface: StyleBox = label.get_theme_stylebox("normal")
		var ink: Vector2 = Vector2(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x,
			font.get_height(pixels))
		var available: Vector2 = label.size - surface.get_minimum_size()
		check(label.is_visible_in_tree() and label.get_parent() == view._header_chest_host
			and label.text == "Lv%d" % expected_tier, context + " visibly identifies the capped earned chest level")
		check(dock_before.grow(0.1).encloses(badge) and badge.has_area()
			and badge.end.distance_to(dock_before.end) < 0.1,
			context + " contains the complete badge at the dock's lower-right corner")
		check(ink.x <= available.x + 0.1 and ink.y <= available.y + 0.1,
			context + " fits every level character and the full font height without clipping: ink=%s available=%s" % [ink, available])
		check(font == app.Style.HEADING_FONT and pixels == ceili(12.0 / s),
			context + " retains the bold twelve-pixel reading size")
		check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE and label.focus_mode == Control.FOCUS_NONE,
			context + " passes pointer and keyboard input to the existing chest action")
		check(label.z_index > view._chest_tap.z_index,
			context + " keeps the level readable over the chest tap response")
		check(view._header_chest_host.get_global_rect().is_equal_approx(dock_before)
			and view._loot_icon.get_global_rect().is_equal_approx(icon_before)
			and view._chest_tap.get_global_rect().is_equal_approx(dock_before)
			and (dock_before.size * s).is_equal_approx(Vector2(44, 44)),
			context + " preserves the existing chest artwork and forty-four-pixel header target")
		var state: Dictionary = view.snapshot().loot
		check(state.displayed_tier == expected_tier and state.level_label.text == label.text and state.level_label.visible,
			context + " publishes the same visible level for browser verification")
	view.game.fragment_count = int(before.fragment_count)
	view.game.chest_tier = int(before.chest_tier)
	view.game.chest_count = int(before.chest_count)
	view._displayed_chest_tier = displayed_before
	view._refresh_hud()
	view._loot_meter.settle()
	check(view.game.snapshot() == before and label.text == "Lv%d" % displayed_before,
		"The chest-level layout fixture restores the original round and displayed level at %s" % dimensions)

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
			check_chest_levels(app, view, dimensions)
		root.size = Vector2i(393, 852)
		await settle()
		var before: Dictionary = view.game.snapshot()
		await tap(view._chest_tap)
		check(view._chest_tap.is_active(), mode + " receives a real pointer tap through the external header dock")
		check(view.game.snapshot() == before and view._pointer == view.NO_POINTER,
			mode + " chest sparkle neither grabs a jelly nor changes game state")
		view._chest_tap.clear()
		view._sync_chest_tap()
		await tap(view._header_chest_level)
		check(view._chest_tap.is_active() and view._header_chest_level.is_visible_in_tree(),
			mode + " a real pointer tap over the level badge reaches the chest action")
		check(view.game.snapshot() == before and view._pointer == view.NO_POINTER,
			mode + " tapping the level badge preserves rewards and does not grab a jelly")
		view._chest_tap.clear()
		app._show_mode_menu()
		await settle()
		check(not view._header_chest_host.is_visible_in_tree() and not view.finish_button.is_visible_in_tree(),
			mode + " hides both externally hosted controls while Home owns input")
		check(not view._header_chest_level.is_visible_in_tree(), mode + " hides its chest level behind Home")
		app._hide_mode_menu()
		await settle()
		check(view._header_chest_host.is_visible_in_tree() and view.finish_button.is_visible_in_tree(),
			mode + " restores its hosted controls when gameplay resumes")
		check(view._header_chest_level.is_visible_in_tree(), mode + " restores the chest level with its dock")
		await tap(view.finish_button)
		check(app._jelly_pause_open() and view.game.paused and view.game.phase == "playing",
			mode + " tapping the original pull control pauses without ending the round")
		app._jelly_pause_button.pressed.emit()
		view.finish_button.accessibility_requested.emit()
		check(app._finish_confirmation_open() and view.game.phase == "playing",
			mode + " an explicit finish request retains its accessible confirmation")
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
