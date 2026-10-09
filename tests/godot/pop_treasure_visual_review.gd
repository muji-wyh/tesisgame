extends SceneTree
## Capture the actual Voice Pop reward flow at desktop and phone sizes.

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const OUTPUT: String = "res://build/pop-treasure-large-review"

var app
var room
var captures: int = 0
var _directory: String
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func capture(filename: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(OUTPUT + "/" + filename + ".png") != OK:
		printerr("Unable to capture " + filename)
		_failed = true
		return
	var file := FileAccess.open(OUTPUT + "/" + filename + ".json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"window": {"width": root.size.x, "height": root.size.y},
			"pop": app._pop.snapshot(), "treasure": app._pop_rewards.snapshot()}, "  "))
		file.close()
	captures += 1


func resize_to(dimensions: Vector2i) -> void:
	root.size = dimensions
	for frame in range(4):
		await process_frame
	app._layout()
	if room != null:
		room._layout()
	await process_frame


func _earn_chests(count: int) -> bool:
	for attempt in range(120):
		if app._pop.game.chest_count >= count:
			return true
		if app._pop.game.phase != "running":
			break
		if app._pop.game.targets.is_empty():
			app._pop._advance_game(0.66)
		if not app._pop.game.targets.is_empty():
			app._pop._listening_tick_usec = Time.get_ticks_usec()
			app._pop.receive_transcript(str(app._pop.game.targets[0].word.text))
	printerr("Unable to earn %d chests for visual review" % count)
	_failed = true
	return false


func _freeze_chests() -> void:
	room.set_process(false)
	for card in room._cards:
		card.art.set_process(false)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_directory = "user://pop-treasure-visual-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(_directory)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(_directory + "/medals.cfg", _directory + "/legacy.cfg")
	Fixture.install(app, _directory)
	root.add_child(app)
	app.audio.muted = true
	for frame in range(4):
		await process_frame
	app.choose_mode("pop")
	Fixture.choose_pop_player(app)
	app.model.set_theme("autumn")
	app._pop.set_listening(true, true, "Listening.")
	app._pop.set_process(false)
	if not _earn_chests(1):
		await _cleanup()
		return
	app._pop._advance_hud_feedback(0.38)
	app._pop._advance_slices(0.12)
	await capture("desktop-earned-chest")
	await resize_to(Vector2i(390, 844))
	await capture("phone-earned-chest")
	await resize_to(Vector2i(320, 568))
	await capture("small-earned-chest")
	await resize_to(Vector2i(844, 390))
	await capture("landscape-earned-chest")
	if not _earn_chests(3):
		await _cleanup()
		return
	app._pop._advance_game(app._pop.game.remaining + 1.0)
	await process_frame
	app._pop.chests_button.pressed.emit()
	room = app._pop_rewards
	_freeze_chests()
	if not app._pop_rewards_shown or room._cards.size() != 3:
		printerr("The actual result did not open all three treasure cards")
		_failed = true
		await _cleanup()
		return
	await resize_to(Vector2i(1366, 768))
	await capture("desktop-three-chests")
	await resize_to(Vector2i(390, 844))
	await capture("phone-three-chests")
	room._ensure_chest_visible(room._cards[2].button)
	await capture("phone-last-chest")
	room._ensure_chest_visible(room._cards[0].button)
	await resize_to(Vector2i(320, 568))
	await capture("small-three-chests")
	await resize_to(Vector2i(844, 390))
	await capture("landscape-three-chests")
	await resize_to(Vector2i(667, 375))
	await capture("narrow-landscape-three-chests")
	await resize_to(Vector2i(1366, 768))
	room.begin_hold(room._cards[0].button)
	room.advance_hold(0.6)
	await capture("desktop-holding")
	room.advance_hold(0.6)
	room._cards[0].art._advance_animation(1.0)
	await capture("desktop-buildup")
	room._cards[0].art._advance_animation(Feel.RELEASE_TIME - 1.0 + 0.045)
	await capture("desktop-release")
	room._cards[0].art._advance_animation(Feel.OPEN_SECONDS)
	await capture("desktop-opened")
	room._cards[0].art._advance_animation(10.0)
	await capture("desktop-retained-gift")
	await resize_to(Vector2i(844, 390))
	await capture("landscape-one-opened")
	await resize_to(Vector2i(390, 844))
	await capture("phone-one-opened")
	room.begin_hold(room._cards[1].button)
	room.advance_hold(Feel.HOLD_SECONDS)
	room._cards[1].art._advance_animation(Feel.RELEASE_TIME + 0.045)
	await capture("phone-release")
	room._cards[1].art._advance_animation(Feel.OPEN_SECONDS)
	await capture("phone-two-opened")
	await resize_to(Vector2i(320, 568))
	await capture("small-two-opened")
	room.set_reduced_motion(true)
	room.begin_hold(room._cards[2].button)
	room.advance_hold(Feel.HOLD_SECONDS)
	for card in room._cards:
		card.art._advance_animation(30.0)
	await capture("small-all-opened-reduced-motion")
	await resize_to(Vector2i(390, 844))
	await capture("phone-three-retained-gifts")
	room._ensure_chest_visible(room._cards[0].button)
	await capture("phone-first-retained-gift")
	room._ensure_chest_visible(room._cards[2].button)
	await capture("phone-last-retained-gift")
	await resize_to(Vector2i(1366, 768))
	await capture("desktop-three-retained-gifts")
	await _cleanup()


func _cleanup() -> void:
	app.audio.halt()
	app._pop_rewards.pause()
	app.queue_free()
	await process_frame
	await process_frame
	for filename in DirAccess.get_files_at(_directory):
		DirAccess.remove_absolute(_directory + "/" + filename)
	DirAccess.remove_absolute(_directory)
	print("Voice Pop treasure: %d rendered captures" % captures)
	quit(1 if _failed else 0)
