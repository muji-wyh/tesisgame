extends SceneTree

const Pip = preload("res://scripts/duck_mascot.gd")
const Motion = preload("res://scripts/pip_age_motion.gd")
const OUTPUT := "res://web/preview/pip-growth/action-catalog.json"
const SOURCES := ["res://scripts/duck_mascot.gd", "res://scripts/pip_age_motion.gd",
	"res://data/pip-age-motions.json", "res://data/pip-growth-stages.json",
	"res://tools/pip-growth/export-review.gd"]
const FPS := 24
var definitions: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _add(id: String, label: String, category: String, kind: String, seconds: float,
		source: String, extra: Dictionary = {}) -> void:
	var definition := {"id": id, "label": label, "category": category, "kind": kind,
		"seconds": seconds, "source": source, "performances": {}}
	definition.merge(extra)
	definitions.append(definition)


func _run() -> void:
	var stages: Array = JSON.parse_string(FileAccess.get_file_as_string(Pip.GROWTH_CATALOG_PATH)).stages
	for stage: Dictionary in stages:
		for id: String in Motion.actions(int(stage.age)):
			var clip: Dictionary = Motion.clip(id)
			_add(id, clip.label, "signature", "growth", float(clip.seconds),
				"data/pip-age-motions.json", {"native_id": id, "age": stage.age,
				"description": clip.description})
	for id: String in Pip.GROWTH_ACTION_SECONDS:
		_add("inherited:" + id, Pip.GROWTH_ACTION_CAPTIONS[id], "inherited", "growth",
			float(Pip.GROWTH_ACTION_SECONDS[id]), "duck_mascot.gd: perform_growth_action",
			{"native_id": id})
	_add("idle", "Rest and blink", "attention", "idle", 4.6, "duck_mascot.gd: _update_pose")
	_add("speaking", "Speaking", "attention", "speaking", 1.0, "duck_mascot.gd: set_speaking")
	for face: String in ["listening", "thinking"]:
		_add("attention:" + face, face.capitalize(), "attention", "attention", 1.0,
			"duck_mascot.gd: set_attention", {"face": face, "held": true})
	for index in range(Pip.HAPPY_EXPRESSIONS.size()):
		var face: String = Pip.HAPPY_EXPRESSIONS[index]
		_add("hello:" + face, "Hello: " + face, "feedback", "hello", 0.65,
			"duck_mascot.gd: react(happy)", {"variant": index})
	_add("curious", "Curious acknowledgement", "feedback", "curious", 0.65,
		"duck_mascot.gd: react(curious)")
	for face: String in Pip.EXPRESSION_NAMES:
		_add("expression:" + face, face.capitalize(), "expressions", "expression", 1.0,
			"duck_mascot.gd: EXPRESSION_NAMES", {"face": face, "held": true})
	for index in range(Pip.HAPPY_EXPRESSIONS.size()):
		_add("answer:" + Pip.HAPPY_EXPRESSIONS[index],
			"Correct: " + Pip.HAPPY_EXPRESSIONS[index], "feedback", "correct",
			Pip.GAMEPLAY_HAPPY_SECONDS, "duck_mascot.gd: react_gameplay(true)", {"variant": index})
	_add("answer:encourage", "Try again, together", "feedback", "incorrect",
		Pip.GAMEPLAY_SAD_SECONDS, "duck_mascot.gd: react_gameplay(false)")
	_add("celebration", "Leap, two-step and present", "celebration", "celebration",
		Pip.CELEBRATION_SECONDS, "duck_mascot.gd: set_celebration_progress")
	var duck := Pip.new()
	root.add_child(duck)
	duck.size = Vector2(120, 120)
	duck.set_process(false)
	var performances := 0
	for stage: Dictionary in stages:
		duck.settle()
		duck.set_growth_age(int(stage.age))
		for definition: Dictionary in definitions:
			if definition.has("age") and int(definition.age) != int(stage.age):
				continue
			if definition.category == "inherited" and not definition.native_id in stage.actions:
				continue
			var frames: Array[Dictionary] = []
			var count: int = 1 if definition.get("held", false) else ceili(float(definition.seconds) * FPS) + 1
			for index in range(count):
				var progress: float = index / float(count - 1) if count > 1 else 0.0
				frames.append(_sample(duck, definition, progress, false))
			definition.performances[str(int(stage.age))] = {
				"frames": frames, "reduced": _sample(duck, definition, 0.5, true)}
			performances += 1
	duck.free()
	var hashes := {}
	for source: String in SOURCES:
		hashes[source.trim_prefix("res://")] = FileAccess.get_sha256(source)
	var catalog := {"version": 1, "fps": FPS, "sources": hashes, "actions": definitions,
		"scope": "Native character poses, expressions and shadows. Game audio, particles and rewards are not replayed.",
		"performances": performances}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write the Pip action review catalog.")
		quit(1)
		return
	file.store_string(JSON.stringify(catalog, "", true, false) + "\n")
	file.close()
	print("Pip action review: %d actions/states, %d age performances, %d fps native samples." %
		[definitions.size(), performances, FPS])
	quit(0)


func _sample(duck: Pip, definition: Dictionary, progress: float, reduced: bool) -> Dictionary:
	duck.settle()
	duck.set_reduced_motion(reduced)
	match str(definition.kind):
		"growth":
			if not duck.perform_growth_action(str(definition.native_id)):
				push_error("Cannot review unavailable Pip action: " + str(definition.id))
				quit(1)
		"speaking":
			duck.set_speaking(true)
		"attention":
			duck.set_attention(str(definition.face))
		"hello":
			duck._greeting_cycle = int(definition.variant)
			duck.react("happy")
		"curious":
			duck.react("curious")
		"expression":
			duck.react(str(definition.face))
		"correct", "incorrect":
			duck._success_cycle = int(definition.get("variant", 0))
			duck.react_gameplay(definition.kind == "correct")
		"celebration":
			duck.set_celebration_progress(progress)
	if definition.kind != "celebration" and not definition.get("held", false):
		duck._process(float(definition.seconds) * progress)
	duck.set_process(false)
	return _frame(duck)


func _matrix(value: Transform2D) -> Array:
	return [snappedf(value.x.x, 0.00001), snappedf(value.x.y, 0.00001),
		snappedf(value.y.x, 0.00001), snappedf(value.y.y, 0.00001),
		snappedf(value.origin.x, 0.00001), snappedf(value.origin.y, 0.00001)]


func _frame(duck: Pip) -> Dictionary:
	var transforms: Array[Transform2D] = []
	var inset := 1.0
	var shadow: Array = []
	var base := Transform2D.IDENTITY
	var radius: float = float(duck._growth_stage.shadowRadius)
	if duck._celebration_progress >= 0.0:
		transforms = Pip._celebration_transforms(duck._celebration_progress, duck.reduced_motion)
		inset = 0.82
		var lift: float = maxf(0.0, 98.0 - (transforms[0] * Pip.GAMEPLAY_PIVOTS[0]).y) / 23.0
		base = Transform2D(Vector2(inset, 0), Vector2(0, inset), Vector2(10.8, 20.16))
		var point: Vector2 = base * Vector2(61, 112)
		shadow = [point.x, point.y, (radius * 37.0 / 39.0 - lift * 10.0) * inset,
			(4.2 - lift) * inset, 0.15 - lift * 0.06]
	elif not duck._gameplay_reaction.is_empty():
		var correct: bool = duck._gameplay_reaction == "happy"
		var progress: float = 0.45 if duck.reduced_motion else 1.0 - duck._gameplay_left / duck._gameplay_duration()
		var envelope: float = 1.0 if duck.reduced_motion else smoothstep(0.0, 0.055, progress) * (1.0 - smoothstep(0.84, 1.0, progress))
		transforms = Pip._gameplay_transforms(correct, progress, duck.reduced_motion)
		inset = 1.0 - (0.20 if correct else 0.045) * envelope
		base = Transform2D(Vector2(inset, 0), Vector2(0, inset), Vector2((1.0 - inset) * 60, (1.0 - inset) * 112))
		var airborne: float = clampf((98.0 - (transforms[0] * Pip.GAMEPLAY_PIVOTS[0]).y) / 24.0, 0.0, 1.0)
		shadow = [61.2, 112.8, 120 * (0.31 * radius / 39.0 - airborne * 0.095), 4.32, 0.19 - airborne * 0.09]
	elif not duck.speaking and not duck._idle_action.is_empty():
		var progress: float = 1.0 if duck.reduced_motion else 1.0 - duck._idle_left / duck._idle_duration()
		var action: Dictionary = duck._current_growth_pose(progress)
		var envelope: float = 0.0 if duck.reduced_motion else smoothstep(0.0, 0.14, progress) * (1.0 - smoothstep(0.82, 1.0, progress))
		inset = 1.0 - float(action.get("inset", 0.18 * envelope))
		base = Transform2D(Vector2(inset, 0), Vector2(0, inset), Vector2((1.0 - inset) * 60, (1.0 - inset) * 112))
		for index in range(6):
			var part: Vector3 = action.parts[index]
			transforms.append(Pip._gameplay_part_transform(index, Vector2(part.x, part.y), deg_to_rad(part.z)))
		var lift: float = maxf(0.0, -float(action.parts[0].y)) / 23.0
		var point: Vector2 = base * Vector2(61, 112)
		shadow = [point.x, point.y, (radius - lift * 9.0) * inset, 5.0 * inset, 0.14 - lift * 0.05]
	else:
		var wave: float = sin((1.0 - duck.reaction_left / 0.65) * PI) if duck.reaction_left > 0.0 and not duck.reduced_motion else 0.0
		var angle: float = (-0.07 if duck._reaction == "curious" else 0.07) * wave
		var stretch := Vector2(1 + wave * 0.04, 1 - wave * 0.03)
		var transform := Transform2D(angle, stretch, 0.0, Vector2(60, 90 - wave * 8.4))
		transform.origin -= transform.basis_xform(Vector2(60, 90))
		var sheet := "regular" if duck._face_name.is_empty() else "expressions"
		var cell: int = duck.pose if duck._face_name.is_empty() else Pip.EXPRESSION_NAMES.find(duck._face_name)
		return {"mode": "sheet", "sheet": sheet, "cell": cell, "transform": _matrix(transform)}
	var matrices: Array = []
	for transform: Transform2D in duck._growth_transforms(transforms):
		matrices.append(_matrix(base * transform))
	return {"mode": "parts", "parts": matrices, "face": duck._face_name, "shadow": shadow}
