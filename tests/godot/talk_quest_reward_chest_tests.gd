extends SceneTree

const Chest = preload("res://scripts/talk_quest_reward_chest.gd")
const Artist = preload("res://scripts/talk_quest_chest.gd")
const Data = preload("res://scripts/talk_quest_data.gd")
const Feel = preload("res://scripts/chest_feel.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _rect(value: Dictionary) -> Rect2:
	return Rect2(float(value.x), float(value.y), float(value.width), float(value.height))


func _new_chest(number: int = 1):
	var chest = Chest.new()
	root.add_child(chest)
	chest.size = Vector2(420, 370)
	chest.configure(Data.chest("chest-%02d" % number))
	return chest


func _confirm(chest) -> void:
	chest.begin_hold()
	chest.set_hold_progress(1.0)
	chest.start_open(false)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 760)
	_check_catalog_and_bounds()
	_check_lifecycle()
	_check_reduced_motion()
	_check_album_isolation()
	print("Talk Quest reward chest: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_catalog_and_bounds() -> void:
	var chest = _new_chest()
	var events: Array[String] = []
	chest.opened.connect(func() -> void: events.append("opened"))
	chest.release_reached.connect(func() -> void: events.append("release"))
	chest.cue_requested.connect(func(_theme: String, cue: String, _step: int) -> void: events.append(cue))
	var designs: Dictionary = {}
	for definition: Dictionary in Data.chests():
		chest.configure(definition)
		designs[chest.chest_id] = true
		check(chest.chest_id == definition.id and chest.chest_index == definition.index,
			"The shared performance preserves each quest design identity")
		check(chest._artist.chest_id == definition.id and chest._artist.externally_driven
			and not chest._artist.is_processing(), "The original artist has no independent runtime clock")
		check(Feel.PROFILES.has(chest.theme_id), "Every design selects a real shared Match profile")
		for dimensions: Vector2 in [Vector2(180, 280), Vector2(320, 140), Vector2(640, 400)]:
			chest.size = dimensions
			for time: float in [0.0, Feel.ANTICIPATION_TIME, Feel.RELEASE_TIME + 0.05, Feel.SETTLE_TIME, Feel.OPEN_SECONDS]:
				chest.set_preview_time(time)
				var state: Dictionary = chest.hold_effect_snapshot()
				var stage := Rect2(Vector2.ZERO, dimensions).grow(0.75)
				check(stage.encloses(_rect(state.physical_bounds)), "The full mechanism fits narrow, shallow and wide stages")
				check(stage.encloses(_rect(state.crown_effect_bounds)), "The shared crown stays inside the stage")
				check(stage.encloses(_rect(state.release_bloom_bounds)), "The common release light stays inside the stage")
				var anchor: Vector2 = chest._art.transform * Chest.CAVITIES[chest.chest_index - 1]
				check(anchor.distance_to(Vector2(state.cavity_origin.x, state.cavity_origin.y)) < 0.001,
					"Release light follows the design's cavity through the shared body transform")
				check(chest._seam_points().size() == 3, "Every mechanism supplies the shared light seam")
		check(chest._artist._open_amount == 1.0, "Every design retains its fully opened mechanism")
		chest._advance_animation(10.0)
	check(designs.size() == 20, "All twenty distinct quest rewards use the shared presentation")
	check(events.is_empty(), "Deterministic artwork previews never emit cues, releases or rewards")
	chest.free()


func _check_lifecycle() -> void:
	var chest = _new_chest(14)
	var events := {"release": 0, "opened": 0, "private": 0}
	chest.release_reached.connect(func() -> void: events.release += 1)
	chest.opened.connect(func() -> void: events.opened += 1)
	chest._artist.reward_revealed.connect(func() -> void: events.private += 1)
	chest._artist.opening_finished.connect(func() -> void: events.private += 1)
	chest.begin_hold()
	chest.set_hold_progress(0.8)
	check(chest.hold_effect_snapshot().active and chest._physical_pose.rotation != 0.0,
		"The procedural chest participates in the common confirmation performance")
	chest._artist._process(20.0)
	check(events.private == 0 and chest.mode == "closed", "The embedded artist cannot release a reward itself")
	chest.cancel_hold()
	chest._advance_animation(Feel.CANCEL_SECONDS + 0.01)
	check(not chest._hold_active and chest.mode == "closed" and events.opened == 0,
		"An early release returns to the same closed design")
	_confirm(chest)
	chest._advance_animation(Feel.RELEASE_TIME - 0.001)
	check(events.release == 0 and events.opened == 0 and not chest.opening_committed(),
		"Buildup and anticipation do not release or collect the reward")
	check(chest._artist._open_amount == 0.0, "The mechanism stays closed through the held breath")
	chest.cancel_open(true)
	chest._advance_animation(Feel.OPEN_SECONDS)
	check(chest.mode == "closed" and events.opened == 0 and events.release == 0,
		"Cancelling immediately before release cannot complete through a stale animation")
	_confirm(chest)
	chest._advance_animation(Feel.RELEASE_TIME + 0.001)
	check(events.release == 1 and events.opened == 0 and chest.opening_committed(),
		"Physical release ends the gesture while reward collection waits for settling")
	chest.cancel_open()
	check(chest.mode == "opening", "A released mechanism retains its settling tail")
	chest._advance_animation(Feel.OPEN_SECONDS)
	check(events.opened == 1 and events.release == 1 and chest.mode == "opened",
		"Settling completes exactly once through the inherited opened signal")
	chest.show_surprise()
	chest.show_surprise()
	check(chest._surprise.snapshot().play_count == 1, "The common surprise can play only once for a reward")
	chest.start_open(false)
	chest.finish_immediately()
	chest._advance_animation(20.0)
	check(events.opened == 1 and events.private == 0, "Duplicate commands cannot create another completion")
	chest.reset_closed()
	_confirm(chest)
	chest._advance_animation(20.0)
	check(events.release == 2 and events.opened == 2, "A frame skipping the whole release still delivers both lifecycle boundaries once")
	chest.reset_closed()
	_confirm(chest)
	chest.hide()
	var clock: float = chest._elapsed
	chest._advance_animation(20.0)
	check(chest._elapsed == clock and events.opened == 2, "A hidden chest cannot advance or replay its presentation")
	chest.show()
	chest.cancel_open(false)
	check(chest.chest_id == "chest-14" and chest._artist._open_amount == 0.0,
		"Lifecycle resets retain the earned original design")
	chest.free()


func _check_reduced_motion() -> void:
	var chest = _new_chest(20)
	var opened: Array[bool] = []
	chest.opened.connect(func() -> void: opened.append(true))
	chest.begin_hold()
	chest.set_hold_progress(0.6)
	chest.set_reduced_motion(true)
	var state: Dictionary = chest.hold_effect_snapshot()
	check(chest._hold_active and is_equal_approx(chest.hold_progress, 0.6),
		"Enabling reduced motion preserves earned confirmation progress")
	check(state.spark_count == 0 and state.physical_pose.rotation == 0.0,
		"Reduced confirmation has readable progress without body motion or particles")
	chest.set_hold_progress(1.0)
	chest.start_open(true)
	state = chest.hold_effect_snapshot()
	check(opened.size() == 1 and chest.mode == "opened" and chest._artist._open_amount == 1.0,
		"Reduced motion completes directly into the original opened design")
	check(state.release_flash == 0.0 and state.opened_glow > 0.0 and not state.opened_animated,
		"Reduced opening retains a steady result without a flash or sway")
	chest.reset_closed()
	chest.set_reduced_motion(false)
	_confirm(chest)
	chest._advance_animation(0.5)
	chest.set_reduced_motion(true)
	chest.set_reduced_motion(true)
	check(opened.size() == 2, "Changing motion preference during buildup settles the confirmed reward once")
	chest.free()


func _check_album_isolation() -> void:
	var preview = Artist.new()
	root.add_child(preview)
	preview.size = Vector2(100, 90)
	preview.configure(Data.chest("chest-11"))
	preview.set_preview_time(Artist.OPEN_SECONDS)
	check(not preview.externally_driven and preview.chest_id == "chest-11" and preview._open_amount == 1.0,
		"The album keeps independent deterministic original-design previews")
	preview.free()
