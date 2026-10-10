extends SceneTree

const PairReward = preload("res://scripts/pair_chest_reward.gd")
const Data = preload("res://scripts/game_data.gd")
const THEMES := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]

var checks: int = 0
var failures: int = 0
var cues: Array[String] = []
var reveals: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 640)
	var data := Data.new()
	if not data.load_all():
		check(false, "Pair rewards use the acquired game chest manifests")
		quit(1)
		return
	var view := PairReward.new()
	root.add_child(view)
	view.size = Vector2(960, 640)
	view.set_toast_bounds(Rect2(100, 72, 760, 46))
	view.cue_requested.connect(func(id: String, cue: String) -> void: cues.append(id + ":" + cue))
	view.confetti_requested.connect(func(id: String) -> void: reveals.append(id))
	check(view.configure("round-a", "spring", data.chests, false), "A valid round configures its existing theme chest")
	check(not view.snapshot().active and not view.visible and view.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"The empty reward row adds no visible content or input target")
	check(not view.show_pair_result("old-round", true), "A stale pair callback cannot show treasure in the current round")
	check(not view.show_pair_result("round-a", false, false), "The owner can omit routine no-chest messages")
	check(view.show_pair_result("round-a", false), "A requested no-chest result appears")
	check(view.snapshot().message == "No chest this pair" and not view.snapshot().earned and not view.chest.visible,
		"A failed drop is a small text acknowledgement without fake treasure")
	view.advance(PairReward.MISS_SECONDS + 0.01)
	check(not view.snapshot().active and not view.visible and cues.is_empty(), "No-chest feedback quietly clears without sound or paper")
	check(view.show_pair_result("round-a", true), "A committed successful pair starts the chest result")
	view.advance(PairReward.REVEAL_SECONDS - 0.01)
	check(cues.is_empty() and reveals.is_empty(), "Paper and sound wait for the actual reveal beat")
	view.advance(0.02)
	check(cues == ["round-a:reward"] and reveals == ["round-a"] and view.snapshot().performance_active,
		"The reveal emits one round-bound sound and one request for the shared screen overlay")
	check(not view.show_pair_result("round-a", true) and not view.show_pair_result("round-a", false),
		"Duplicate or later pairs cannot restart the earned chest or replace its status")
	var before_pause: float = view.snapshot().elapsed
	view.set_paused(true)
	view.advance(5.0)
	check(view.snapshot().elapsed == before_pause and reveals == ["round-a"],
		"Menu or background pause preserves the current timeline without another reveal")
	view.set_paused(false)
	view.advance(0.1)
	check(view.snapshot().elapsed > before_pause and cues.size() == 1 and reveals.size() == 1,
		"Resume continues without replaying the reward cue or screen overlay request")
	view.advance(1.0)
	check(view.snapshot().performance_active and reveals.size() == 1,
		"The compact chest performance continues independently after its single reveal request")
	view.advance(2.0)
	check(not view.snapshot().performance_active and view.snapshot().active and view.snapshot().earned,
		"The performance ends while its earned chest remains visible")
	check(view.snapshot().message == "Chest ready" and view.snapshot().chest_mode == "closed" and reveals.size() == 1,
		"The compact settled status retains a closed chest without opening or repeated paper")
	check(view.chest.scale == Vector2.ONE and is_zero_approx(view.chest.rotation), "The closed chest settles exactly to its authored dimensions")
	for theme_id: String in THEMES:
		check(view.configure("theme-" + theme_id, theme_id, data.chests, true)
			and view.show_pair_result("theme-" + theme_id, true), "The earned preview supports source chest theme " + theme_id)
		view.advance(0.5)
		check(view.chest.theme_id == theme_id and view.chest.mode == "closed" and view.chest.piece_count() > 0,
			"Theme " + theme_id + " reuses real closed chest artwork")
		check(view.chest.scale == Vector2.ONE and is_zero_approx(view.chest.rotation) and reveals == ["round-a"],
			"Reduced motion preserves a static earned status in " + theme_id)
		view.advance(2.0)
		check(not view.snapshot().performance_active and view.snapshot().earned,
			"Reduced motion completes the same presentation deadline for " + theme_id)
	for area: Rect2 in [Rect2(12, 64, 336, 46), Rect2(12, 40, 780, 46), Rect2(12, 64, 184, 42)]:
		view.set_toast_bounds(area)
		check(area.encloses(view.snapshot().toast_rect), "The status remains inside the host's reserved toolbar row")
		check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view._title.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and view.chest.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"All pair reward visuals leave gameplay input with the live board")
	view.clear()
	view.advance(10.0)
	check(not view.snapshot().active and view.snapshot().round_id.is_empty() and not view.visible,
		"Leaving a round removes every transient and persistent reward visual")
	view.configure("reentrant", "spring", data.chests, false)
	view.cue_requested.connect(func(id: String, _cue: String) -> void:
		if id == "reentrant":
			view.clear())
	view.show_pair_result("reentrant", true)
	view.advance(0.3)
	check(not view.snapshot().active and view.snapshot().round_id.is_empty() and not view.visible
		and reveals.count("reentrant") <= 1,
		"A host navigation during the sound cue cannot revive an obsolete reward")
	view.free()
	print("Pair chest reward: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
