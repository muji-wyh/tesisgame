extends SceneTree

const Mascot = preload("res://scripts/duck_mascot.gd")
const ACTIONS := ["wave", "look", "high-five", "peekaboo", "stretch", "hop",
	"dance-sway", "flutter", "dance-wave", "dance-hop"]
const THEMES := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _step(duck, seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.00001:
		var delta: float = minf(0.05, remaining)
		duck._process(delta)
		remaining -= delta


func _run() -> void:
	root.size = Vector2i(960, 640)
	var duck = Mascot.new()
	root.add_child(duck)
	duck.size = Vector2(120, 120)
	duck.set_proactive_allowed(false)
	check(duck.growth_level == 3 and duck.growth_actions() == ["wave"], "A new Pip starts at Lv 3 with one intentional gesture")
	var input_bounds: Rect2 = duck.get_rect()
	var child_count: int = duck.get_child_count()
	var appearance_paths: Array[String] = []
	for level in range(3, 13):
		duck.settle()
		duck.set_growth_level(level)
		check(duck.growth_level == level, "Pip selects the requested growth level %d" % level)
		check(duck.growth_actions() == ACTIONS.slice(0, level - 2), "Lv %d retains every previously learned gesture" % level)
		var art: Texture2D = duck._outfit_sheet
		check(art != null and art.resource_path == "res://assets/images/mascots/growth/pip-lv%d.svg" % level,
			"Lv %d loads its own ordinary production atlas" % level)
		if art == null:
			continue
		appearance_paths.append(art.resource_path)
		var sheets: Array = [art, duck._outfit_idle_sheet, duck._outfit_dance_sheet, duck._expression_sheet, duck._expression_heads]
		var cells: Array[int] = [4, 4, 6, 10, 10]
		for index in range(sheets.size()):
			var sheet: Texture2D = sheets[index]
			check(sheet != null and sheet.get_height() == 360 and sheet.get_width() == 360 * cells[index],
				"Lv %d sheet %d retains 3x source cells and transparent margins" % [level, index])
		check(ResourceLoader.exists(duck.growth_voice_path(), "AudioStream"), "Lv %d has an acquired local voice recording" % level)
		for theme_id in THEMES:
			duck.set_outfit_theme(theme_id)
			check(duck._outfit_sheet == art and duck.growth_level == level and duck.theme_id == theme_id,
				"World %s does not overwrite Lv %d Pip" % [theme_id, level])
		var action: String = ACTIONS[level - 3]
		check(not duck.perform_trick(action).is_empty(), "Lv %d can explicitly perform its newly unlocked gesture" % level)
		var remaining: float = duck._idle_left
		check(duck.perform_trick(action).is_empty() and duck._idle_left == remaining,
			"Repeated taps cannot restart or stack a running growth gesture")
		_step(duck, float(Mascot.GROWTH_ACTION_SECONDS[action]) + 0.2)
		check(duck._idle_action.is_empty() and not duck.is_manual_action_busy(),
			"A manually requested growth gesture finishes even with proactive motion disabled")
		check(duck.get_rect() == input_bounds and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation) and duck.get_child_count() == child_count,
			"Growth motion preserves input ownership and never creates transient nodes")
		if level < 12:
			check(duck.perform_trick(ACTIONS[level - 2]).is_empty() and duck._idle_action.is_empty(),
				"Lv %d cannot play next level's locked gesture" % level)
	check(appearance_paths.size() == 10 and appearance_paths.all(func(value: String) -> bool: return appearance_paths.count(value) == 1),
		"All ten stages have a loaded production appearance")
	_check_motion_contract()
	_check_lifecycle(duck)
	_check_feedback(duck)
	duck.free()
	print("Pip growth: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_motion_contract() -> void:
	for action in ACTIONS:
		var at_start: Dictionary = Mascot._growth_action_pose(action, 0.0)
		var at_end: Dictionary = Mascot._growth_action_pose(action, 1.0)
		var varying_parts: Dictionary = {}
		for index in range(6):
			var start: Vector3 = at_start.parts[index]
			var end: Vector3 = at_end.parts[index]
			check(start.is_equal_approx(Vector3.ZERO) and end.is_equal_approx(Vector3.ZERO),
				"%s returns part %d to its authored joint after one performance" % [action, index])
		for fraction in [0.2, 0.4, 0.6, 0.8]:
			var moving: Dictionary = Mascot._growth_action_pose(action, fraction)
			check(Mascot.EXPRESSION_NAMES.has(str(moving.face)), "%s uses an authored expression at %.1f" % [action, fraction])
			for index in range(6):
				var part: Vector3 = moving.parts[index]
				if not part.is_equal_approx(Vector3.ZERO):
					varying_parts[index] = true
				check(part.is_finite() and absf(part.x) < 8.0 and absf(part.y) < 24.0 and absf(part.z) < 140.0,
					"%s stays inside its reviewed articulated range" % action)
			var still: Dictionary = Mascot._growth_action_pose(action, fraction, true)
			check(still.face == "delighted" and still.parts == Mascot._growth_action_pose(action, 0.0, true).parts,
				"Reduced motion keeps %s in one time-independent happy pose" % action)
		check(varying_parts.size() >= 2, "%s articulates real body layers rather than moving the entire hit target" % action)
	var landing: Dictionary = Mascot._growth_action_pose("hop", 0.70)
	check(is_zero_approx(landing.parts[4].y) and is_zero_approx(landing.parts[5].y) and landing.parts[0].y > 0.0 and landing.parts[1].y > landing.parts[0].y,
		"A hop plants the feet before the body and head absorb the landing")


func _check_lifecycle(duck) -> void:
	duck.settle()
	duck.set_growth_level(12)
	duck.set_reduced_motion(true)
	check(duck.perform_growth_action("dance-hop") and duck.expression_name() == "delighted" and not duck.is_processing(),
		"Reduced motion acknowledges a requested gesture without starting an animation loop")
	duck.set_reduced_motion(false)
	duck.settle()
	check(duck.perform_growth_action("flutter"), "A full-motion gesture can start after leaving reduced motion")
	duck.set_idle_paused(true)
	check(duck._idle_action.is_empty() and not duck.is_processing() and not duck.perform_growth_action("wave"),
		"Page suspension stops the gesture and rejects late input")
	duck.set_idle_paused(false)
	check(duck._idle_action.is_empty(), "Resuming a page does not replay an interrupted gesture")
	duck.perform_growth_action("hop")
	duck.hide()
	check(duck._idle_action.is_empty() and not duck.perform_growth_action("wave"), "Hidden Pip cannot keep moving or accept late gestures")
	duck.show()
	duck.set_speaking(true)
	check(not duck.perform_growth_action("wave"), "Actual word pronunciation takes priority over growth gestures")
	duck.set_speaking(false)
	duck.set_proactive_allowed(true)
	duck.set_growth_level(3)
	for invitation in range(4):
		duck._idle_wait = 0.01
		duck._process(0.05)
		check(duck._idle_action == "wave", "Lv 3 autonomous motion cannot borrow an unearned higher-level dance")
		_step(duck, 2.0)
	duck.set_proactive_allowed(false)
	duck.settle()


func _check_feedback(duck) -> void:
	duck.set_growth_level(3)
	duck.react_gameplay(true)
	check(duck._gameplay_reaction == "happy" and duck._gameplay_left > 0.0,
		"The first level retains complete correct-answer emotional feedback")
	_step(duck, 1.5)
	duck.react_gameplay(false)
	check(duck._gameplay_reaction == "sad" and duck.expression_name() == "thinking",
		"The first level retains thoughtful, supportive wrong-answer feedback")
	duck.set_celebration_progress(0.4)
	check(duck._celebration_progress == 0.4 and duck.expression_name() == "delighted" and not duck.perform_growth_action("wave"),
		"Shared round celebration stays available at Lv 3 and blocks unrelated gestures")
	duck.set_growth_level(4)
	check(duck._celebration_progress == 0.4 and duck.expression_name() == "delighted",
		"A new growth appearance cannot restart or interrupt the shared celebration timeline")
	duck.clear_celebration()
	duck.settle()
