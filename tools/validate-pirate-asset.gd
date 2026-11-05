extends SceneTree
## Focused import, playback and morph checks for the additive Pirate resource.

const Actor = preload("res://scripts/pirate_asset_actor.gd")
const Palette = preload("res://scripts/pirate_asset_color.gd")
var checks: int = 0
var failures: int = 0
var actor
var neutral: Dictionary = {}
var completed: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _settle(seconds: float) -> void:
	for step: int in range(ceili(seconds * 120.0)):
		actor.advance(1.0 / 120.0)


func _check_neutral(context: String) -> void:
	check(actor.snapshot().clip == "Idle", context + " returns to Idle")
	var actual: Dictionary = actor.model_transforms()
	for path: String in neutral:
		check(actual.has(path) and Transform3D(actual[path]).is_equal_approx(neutral[path]),
			context + " restores " + path)
	for weight: float in actor.morph_weights().values():
		check(absf(weight) < 0.00001, context + " resets every facial morph")


func _run() -> void:
	actor = Actor.new()
	actor.auto_advance = false
	root.add_child(actor)
	if not actor.load_character():
		check(false, actor.last_error)
		_finish()
		return
	_check_import_palette()
	_check_color_conversion()
	check(actor.animation_names().size() == 22, "The optimized scene imports all twenty-two exact clips")
	check(Actor.TAUNTS.size() == 10, "The actor exposes all ten distinct taunts")
	check(is_equal_approx(float(actor.snapshot().rest_bounds.size.y), 2.0),
		"An outer wrapper gives the evaluated neutral character a stable two-unit height")
	check(absf(float(actor.snapshot().rest_bounds.position.y)) < 0.00001,
		"The evaluated neutral character is grounded at zero")
	var morph_names: Dictionary = {}
	for path: String in actor.morph_weights():
		var target: String = path.get_slice(":", 1)
		morph_names[target] = true
		check(target in Actor.MORPHS, "The imported facial target retains its authored name: " + target)
	for target: String in Actor.MORPHS:
		check(morph_names.has(target), "The optimized scene retains the " + target + " morph")
	neutral = actor.model_transforms()
	actor.action_finished.connect(func(clip: String) -> void: completed.append(clip))
	for clip: String in actor.animation_names():
		if clip == "Idle":
			continue
		actor.pose(clip, 0.0)
		for path: String in neutral:
			check(Transform3D(actor.model_transforms()[path]).is_equal_approx(neutral[path]),
				clip + " starts with its " + path + " pivot reset")
		for weight: float in actor.morph_weights().values():
			check(absf(weight) < 0.00001, clip + " starts with every facial morph reset")
		actor.pose(clip, actor.clip_duration(clip))
		for path: String in neutral:
			check(Transform3D(actor.model_transforms()[path]).is_equal_approx(neutral[path]),
				clip + " ends with its " + path + " pivot reset")
		for weight: float in actor.morph_weights().values():
			check(absf(weight) < 0.00001, clip + " ends with every facial morph reset")
		check(actor.play_animation(clip), "Play " + clip)
		_settle(actor.clip_duration(clip) + 0.01)
		check(actor.snapshot().clip == "Idle", clip + " finishes into Idle automatically")
		# Sample the exact neutral origin, independent of a subsequent idle phase.
		actor.resume_idle()
		_check_neutral(clip)
	check(completed.size() == 21, "Every one-shot emits one completion")
	actor.pose("Special_BigBite", 0.60)
	for path: String in actor.morph_weights():
		var weight: float = float(actor.morph_weights()[path])
		check(weight > 0.98 if path.ends_with(":Bite_Open") else absf(weight) < 0.00001,
			"The actual bite pose opens only its imported Bite_Open target")
	actor.play_animation("Attack_M")
	actor.advance(0.1)
	for weight: float in actor.morph_weights().values():
		check(absf(weight) < 0.00001, "Interrupting a bite resets every facial target")
	_check_taunt_motion()
	for index: int in range(Actor.CLIPS.size() * 12):
		var clip: String = Actor.CLIPS[1 + index % (Actor.CLIPS.size() - 1)]
		actor.play_animation(clip)
		actor.advance(0.003)
	actor.resume_idle()
	_check_neutral("Rapid mixed replay")
	check(completed.size() == 21, "Interrupted replay cannot emit stale completions")
	actor.pose("Special_GiantRam", 1.05)
	var giant: Dictionary = actor.model_transforms()
	var found_body: bool = false
	var found_hat: bool = false
	for path: String in giant:
		var node_name: String = path.get_file().to_lower().replace(" ", "_")
		if "elastic_body_pivot" in node_name:
			found_body = true
			check(not Transform3D(giant[path]).basis.is_equal_approx(Transform3D(neutral[path]).basis),
				"Giant Ram really enlarges its elastic body pivot")
		if "rigid_hat_pivot" in node_name:
			found_hat = true
			check(Transform3D(giant[path]).basis.get_scale().is_equal_approx(Transform3D(neutral[path]).basis.get_scale()),
				"The hat stays rigid-sized during Giant Ram")
	check(found_body and found_hat, "The exported object-pivot rig remains inspectable")
	actor.resume_idle()
	_check_neutral("Giant return")
	actor.set_reduced_motion(true)
	actor.play_animation("Special_BigBite")
	check(not actor.advance(0.5), "Reduced motion keeps the actual neutral pose still")
	_check_neutral("Reduced motion")
	actor.set_reduced_motion(false)
	actor.play_animation("Attack_L")
	actor.set_active(false)
	var held: Dictionary = actor.snapshot()
	check(not actor.advance(1.0) and actor.snapshot().time == held.time,
		"An inactive actor cannot advance or finish its action")
	actor.set_active(true)
	actor.resume_idle()
	_finish()


func _check_taunt_motion() -> void:
	var used_morphs: Dictionary = {}
	for clip: String in Actor.TAUNTS:
		var moved: bool = false
		for step: int in range(1, 12):
			actor.pose(clip, actor.clip_duration(clip) * float(step) / 12.0)
			var actual: Dictionary = actor.model_transforms()
			for path: String in neutral:
				moved = moved or not Transform3D(actual[path]).is_equal_approx(neutral[path])
			for path: String in actor.morph_weights():
				if absf(float(actor.morph_weights()[path])) > 0.05:
					moved = true
					used_morphs[path.get_slice(":", 1)] = true
		check(moved, clip + " produces an authored pose or facial gesture")
		actor.play_animation("Attack_L")
		actor.advance(0.003)
		for weight: float in actor.morph_weights().values():
			check(absf(weight) < 0.00001, "Interrupting " + clip + " resets its facial targets")
	for target: String in ["Eye_Squint", "Smile_Smirk", "Tongue_Out"]:
		check(used_morphs.has(target), "The taunt set animates its " + target + " expression")
	actor.resume_idle()
	_check_neutral("Taunt interruptions")


func _check_import_palette() -> void:
	# Test the raw imported scene too, so the reusable actor cannot mask an import bug.
	var source: PackedScene = load(Actor.MODEL_PATH) as PackedScene
	var raw: Node3D = source.instantiate() as Node3D
	root.add_child(raw)
	for node: Node in raw.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			if colors.is_empty():
				continue
			var material: StandardMaterial3D = mesh.get_active_material(surface) as StandardMaterial3D
			check(material != null and material.vertex_color_use_as_albedo,
				"Raw imported surface preserves its glTF vertex palette")
			check(material != null and material.vertex_color_is_srgb,
				"Raw imported display-encoded colors declare their sRGB encoding")
			check(mesh.mesh.get_meta("pirate_vertex_color_encoding", "") == "srgb",
				"Raw imported mesh prevents duplicate color conversion")
	raw.free()


func _check_color_conversion() -> void:
	var source := ArrayMesh.new()
	for target: String in Actor.MORPHS:
		source.add_blend_shape(target)
	source.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color(0.5373, 0.8667, 0.251, 0.5), Color.WHITE, Color.BLACK])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var morph: Array = []
	morph.resize(Mesh.ARRAY_MAX)
	morph[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3(0, 0.5, 0.3)])
	morph[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	var shapes: Array = []
	for index: int in range(Actor.MORPHS.size()):
		var target_arrays: Array = morph.duplicate(true)
		target_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.ZERO,
			Vector3(0, 0.5, 0.3) * float(index + 1)])
		shapes.append(target_arrays)
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes)
	var material := StandardMaterial3D.new()
	source.surface_set_material(0, material)
	source.surface_set_name(0, "Mouth surface")
	var converted: ArrayMesh = Palette.to_srgb_mesh(source)
	var before: Array = source.surface_get_arrays(0)
	var after: Array = converted.surface_get_arrays(0)
	for attribute: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_INDEX]:
		check(before[attribute] == after[attribute], "Color conversion preserves geometry attribute %d" % attribute)
	var original_shapes: Array = source.surface_get_blend_shape_arrays(0)
	var converted_shapes: Array = converted.surface_get_blend_shape_arrays(0)
	var retained: bool = original_shapes.size() == converted_shapes.size()
	for shape: int in range(original_shapes.size()):
		for attribute: int in range(Mesh.ARRAY_MAX):
			if attribute == Mesh.ARRAY_TANGENT and original_shapes[shape][attribute] != null:
				var original_tangents: PackedFloat32Array = original_shapes[shape][attribute]
				var converted_tangents: PackedFloat32Array = converted_shapes[shape][attribute]
				retained = retained and original_tangents.size() == converted_tangents.size()
				for index: int in range(original_tangents.size()):
					# ArrayMesh repacks tangent channels into signed 16-bit storage.
					retained = retained and absf(original_tangents[index] - converted_tangents[index]) <= 2.0 / 32767.0
			else:
				retained = retained and original_shapes[shape][attribute] == converted_shapes[shape][attribute]
	check(retained, "Color conversion retains morph arrays within tangent packing precision")
	check(source.blend_shape_mode == converted.blend_shape_mode
		and converted.get_blend_shape_count() == Actor.MORPHS.size(), "Color conversion retains relative shape semantics")
	for index: int in range(Actor.MORPHS.size()):
		check(converted.get_blend_shape_name(index) == Actor.MORPHS[index],
			"Color conversion retains the " + Actor.MORPHS[index] + " shape name")
	check(converted.surface_get_material(0) == material and converted.surface_get_name(0) == "Mouth surface",
		"Color conversion retains surface material and name")
	var color: Color = after[Mesh.ARRAY_COLOR][0]
	var original: Color = before[Mesh.ARRAY_COLOR][0]
	var expected: Color = original.linear_to_srgb()
	var precision: float = 1.0 / 255.0 + 0.00001
	check(absf(color.r - expected.r) <= precision and absf(color.g - expected.g) <= precision
		and absf(color.b - expected.b) <= precision and is_equal_approx(color.a, original.a),
		"Color conversion encodes linear RGB and preserves alpha")
	check(Palette.to_srgb_mesh(converted) == converted, "The mesh marker prevents a second conversion")


func _finish() -> void:
	print("Pirate asset validation: %d checks, %d failures" % [checks, failures])
	if actor != null:
		actor.free()
	quit(1 if failures else 0)
