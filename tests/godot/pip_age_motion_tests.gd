extends SceneTree

const Pip = preload("res://scripts/duck_mascot.gd")
const Motion = preload("res://scripts/pip_age_motion.gd")
const AGES := [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var duck := Pip.new()
	root.add_child(duck)
	duck.size = Vector2(56, 56)
	duck.set_process(false)
	var bounds: Rect2 = duck.get_rect()
	var all_actions: Array[String] = []
	var fingerprints: Array[String] = []
	for age in AGES:
		duck.settle()
		duck.set_growth_age(age)
		var actions: Array[String] = duck.age_actions()
		check(actions.size() == 2, "Age %d has two signature actions" % age)
		for id in actions:
			check(not id in all_actions, "%s belongs to exactly one age" % id)
			all_actions.append(id)
			var definition: Dictionary = Motion.clip(id)
			check(float(definition.seconds) >= 2.0 and float(definition.seconds) <= 3.2, id + " is a short finite performance")
			var start: Dictionary = Motion.sample(id, 0.0)
			var finish: Dictionary = Motion.sample(id, 1.0)
			check(start.parts == finish.parts and start.parts.all(func(part): return part == Vector3.ZERO), id + " starts and ends on its authored rest pose")
			check(start.face == "neutral" and finish.face == "neutral", id + " has no facial jump on return to idle")
			var fingerprint := ""
			var moving := {}
			for sample_index in range(41):
				var p: float = sample_index / 40.0
				var sampled: Dictionary = Motion.sample(id, p)
				check(sampled.parts.size() == 6 and sampled.face in Pip.EXPRESSION_NAMES, id + " supplies all six parts and a production face")
				fingerprint += str(sampled.parts)
				for index in range(6):
					var part: Vector3 = sampled.parts[index]
					check(part.is_finite() and absf(part.x) <= 5 and absf(part.y) <= 16 and absf(part.z) <= 120, id + " remains in the reviewed motion range")
					if part != Vector3.ZERO:
						moving[index] = true
				check(Motion.sample(id, p, true) == Motion.sample(id, 0.0, true), id + " has one stable reduced-motion pose")
			check(moving.size() >= 3 and not fingerprint in fingerprints, id + " has distinct articulated choreography")
			fingerprints.append(fingerprint)
			duck.settle()
			check(not duck.perform_trick(id).is_empty(), id + " runs through the real manual interaction")
			var remaining: float = duck._idle_left
			check(not duck.perform_growth_action(id) and duck._idle_left == remaining, id + " cannot stack or restart on repeated input")
			duck._process(remaining + 0.1)
			check(duck._idle_action.is_empty() and not duck.is_manual_action_busy(), id + " finishes without a proactive loop")
			duck.set_reduced_motion(true)
			check(duck.perform_growth_action(id) and not duck.is_processing(), id + " acknowledges reduced motion without a timer")
			check(duck._current_growth_pose(0.0) == duck._current_growth_pose(1.0), id + " freezes its actual rendered pose")
			duck.set_reduced_motion(false)
			duck.settle()
			duck.perform_growth_action(id)
			duck.set_speaking(true)
			check(duck._idle_action.is_empty() and not duck.perform_growth_action(id), id + " yields to pronunciation")
			duck.set_speaking(false)
			duck.perform_growth_action(id)
			duck.set_idle_paused(true)
			check(duck._idle_action.is_empty() and not duck.perform_growth_action(id), id + " cancels for pause")
			duck.set_idle_paused(false)
			duck.perform_growth_action(id)
			duck.hide()
			check(duck._idle_action.is_empty() and not duck.perform_growth_action(id), id + " cancels when hidden")
			duck.show()
			check(duck.get_rect() == bounds and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation), id + " preserves the full input target")
		duck.settle()
		duck._idle_index = 0
		duck.set_proactive_allowed(true)
		for turn in range(4):
			duck._idle_wait = .01
			duck._process(.02)
			check(duck._idle_action == actions[turn % 2], "Age %d alternates its two own motions" % age)
			duck.note_activity()
		duck.set_proactive_allowed(false)
		var other: String = Motion.actions(12 if age != 12 else 0)[0]
		check(not duck.perform_growth_action(other), "Age %d cannot borrow another age's signature" % age)
	duck.set_growth_age(0)
	duck.perform_growth_action()
	duck.set_growth_age(12)
	check(duck._idle_action.is_empty() and duck._idle_index == 0, "Changing age cancels old choreography and starts the new repertoire")
	duck.set_celebration_progress(.4)
	check(not duck.perform_growth_action() and duck._celebration_progress == .4, "Age actions never steal the shared celebration clock")
	duck.free()
	print("Pip age motion: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
