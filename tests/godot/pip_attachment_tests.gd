extends SceneTree

const Pip = preload("res://scripts/duck_mascot.gd")
const Motion = preload("res://scripts/pip_age_motion.gd")
const AGES := [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const LEGACY_ACTIONS := ["wave", "look", "high-five", "peekaboo", "stretch", "hop",
	"dance-sway", "flutter", "dance-wave", "dance-hop"]
const ROOT_TOLERANCE := 0.0001

var checks := 0
var failures := 0
var poses_checked := 0
var signatures_checked := 0


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
	duck.size = Vector2(120, 120)
	duck.set_proactive_allowed(false)
	var bounds: Rect2 = duck.get_rect()
	var child_count: int = duck.get_child_count()
	for age in AGES:
		duck.settle()
		duck.set_growth_age(age)
		check(duck.growth_age == age and duck._growth_stage.get("motionPivots", []).size() == 6,
			"Age %d loads its actual six production joints" % age)
		_check_signature_actions(duck, age)
		_check_legacy_actions(duck, age)
		_check_celebration(duck, age)
		_check_gameplay(duck, age)
		_check_combined_motion(duck, age)
		check(duck.get_rect() == bounds and duck.scale == Vector2.ONE
			and is_zero_approx(duck.rotation) and duck.get_child_count() == child_count,
			"Age %d attachment calculations preserve the input target and node count" % age)
	check(signatures_checked == 22, "All 22 age-specific performances exercise shoulder attachment")
	duck.free()
	print("Pip attachment: %d poses, %d checks, %d failures" % [poses_checked, checks, failures])
	quit(1 if failures else 0)


func _pose_transforms(pose: Dictionary) -> Array[Transform2D]:
	var result: Array[Transform2D] = []
	for index in range(pose.parts.size()):
		var part: Vector3 = pose.parts[index]
		result.append(Pip._gameplay_part_transform(index, Vector2(part.x, part.y), deg_to_rad(part.z)))
	return result


func _shoulder(duck, index: int) -> Vector2:
	var joint: Array = duck._growth_stage.motionPivots[index]
	return Vector2(float(joint[0]), float(joint[1]))


func _check_attachment(duck, authored: Array[Transform2D], context: String) -> void:
	var original: Array[Transform2D] = authored.duplicate()
	var result: Array[Transform2D] = duck._growth_transforms(authored)
	poses_checked += 1
	check(result.size() == 6 and authored.size() == 6, context + " keeps all six articulated parts")
	if result.size() != 6 or authored.size() != 6:
		return
	for index in range(6):
		check(authored[index] == original[index], context + " leaves source part %d unchanged" % index)
		check(result[index].x.is_equal_approx(original[index].x)
			and result[index].y.is_equal_approx(original[index].y),
			context + " preserves part %d's independent rotation and scale" % index)
		check(result[index].x.is_finite() and result[index].y.is_finite() and result[index].origin.is_finite(),
			context + " keeps part %d finite" % index)
		if index not in [2, 3]:
			var retargeted: Transform2D = duck._growth_part_transform(index, original[index])
			check(result[index].is_equal_approx(retargeted),
				context + " preserves non-wing part %d's authored retargeting" % index)
	for index in [2, 3]:
		var shoulder: Vector2 = _shoulder(duck, index)
		var torso_surface: Vector2 = result[0] * shoulder
		var wing_root: Vector2 = result[index] * shoulder
		check(wing_root.distance_to(torso_surface) <= ROOT_TOLERANCE,
			context + " keeps wing %d on its moving torso shoulder (drift %.6f)" % [index, wing_root.distance_to(torso_surface)])


func _check_signature_actions(duck, age: int) -> void:
	for id in Motion.actions(age):
		signatures_checked += 1
		var clip: Dictionary = Motion.clip(id)
		var times: Array[float] = []
		for index in range(21):
			times.append(index / 20.0)
		var beats: Array = clip.beats
		for index in range(beats.size()):
			# Keyframes include the authored rotation extrema; midpoints exercise interpolation.
			times.append(float(beats[index].time))
			if index > 0:
				times.append((float(beats[index - 1].time) + float(beats[index].time)) * 0.5)
		for progress in times:
			_check_attachment(duck, _pose_transforms(Motion.sample(id, progress)),
				"Age %d %s at %.4f" % [age, id, progress])
		_check_attachment(duck, _pose_transforms(Motion.sample(id, 0.0, true)),
			"Age %d %s reduced-motion still at %.4f" % [age, id, float(clip.still)])


func _check_legacy_actions(duck, age: int) -> void:
	for action in LEGACY_ACTIONS:
		for index in range(21):
			var progress: float = index / 20.0
			_check_attachment(duck, _pose_transforms(Pip._growth_action_pose(action, progress)),
				"Age %d legacy %s at %.2f" % [age, action, progress])
		_check_attachment(duck, _pose_transforms(Pip._growth_action_pose(action, 0.5, true)),
			"Age %d legacy %s reduced motion" % [age, action])


func _check_celebration(duck, age: int) -> void:
	for index in range(31):
		var progress: float = index / 30.0
		_check_attachment(duck, Pip._celebration_transforms(progress),
			"Age %d celebration at %.4f" % [age, progress])
	for beat in Pip.CELEBRATION_BEATS:
		var progress: float = float(beat[0]) / Pip.CELEBRATION_SECONDS
		_check_attachment(duck, Pip._celebration_transforms(progress),
			"Age %d celebration %s" % [age, str(beat[1])])
	_check_attachment(duck, Pip._celebration_transforms(0.0, true),
		"Age %d celebration reduced motion" % age)
	for seconds in [0.0, 0.9, 1.8, 2.7, 3.6]:
		_check_attachment(duck, Pip._celebration_transforms(1.0, false, seconds),
			"Age %d celebration resting breath at %.1f seconds" % [age, seconds])
	# This pose reproduced the visible bug: the old independent roots drift during torso squash.
	var crouch: Array[Transform2D] = Pip._celebration_transforms(0.18 / Pip.CELEBRATION_SECONDS)
	var torso: Transform2D = duck._growth_part_transform(0, crouch[0])
	var wing: Transform2D = duck._growth_part_transform(2, crouch[2])
	var shoulder: Vector2 = _shoulder(duck, 2)
	check((wing * shoulder).distance_to(torso * shoulder) > 1.0,
		"Age %d crouch fixture detects the former independent-root defect" % age)


func _check_gameplay(duck, age: int) -> void:
	for correct in [true, false]:
		var reaction: String = "happy" if correct else "sad"
		for index in range(41):
			var progress: float = index / 40.0
			_check_attachment(duck, Pip._gameplay_transforms(correct, progress),
				"Age %d %s reaction at %.3f" % [age, reaction, progress])
		_check_attachment(duck, Pip._gameplay_transforms(correct, 0.0, true),
			"Age %d %s reaction reduced motion" % [age, reaction])


func _check_combined_motion(duck, age: int) -> void:
	# Deliberately divergent limb translations catch double translation and parent-squash inheritance.
	# The roots must travel with the torso while the wings retain their own local shape and angle.
	for angle in [-0.32, 0.0, 0.27]:
		for stretch in [Vector2(1.12, 0.84), Vector2(0.93, 1.08)]:
			var authored: Array[Transform2D] = [
				Pip._gameplay_part_transform(0, Vector2(4, -11), angle, stretch),
				Pip._gameplay_part_transform(1, Vector2(-2, -13), -0.11),
				Pip._gameplay_part_transform(2, Vector2(-9, 5), 1.91, Vector2(0.96, 1.04)),
				Pip._gameplay_part_transform(3, Vector2(8, -6), -1.53, Vector2(1.03, 0.95)),
				Pip._gameplay_part_transform(4, Vector2(0, -2), -0.08),
				Pip._gameplay_part_transform(5, Vector2(1, -1), 0.09),
			]
			_check_attachment(duck, authored,
				"Age %d combined rotation %.2f and squash %s" % [age, angle, str(stretch)])
