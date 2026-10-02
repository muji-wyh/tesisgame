extends SceneTree

const Monster = preload("res://scripts/talk_quest_monster.gd")
const Data = preload("res://scripts/talk_quest_data.gd")
const Model = preload("res://scripts/talk_quest_model.gd")
const Quest = preload("res://scripts/talk_quest.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var expected: Dictionary = {1: "giant-rock-guardian", 12: "giant-storm-dragon", 14: "giant-ember-golem"}
	var active: Dictionary = {}
	for number: int in range(1, Data.LEVEL_COUNT + 1):
		var level: Dictionary = Data.level(number)
		check(not active.has(level.monster_id), "Each destination still has a distinct creature identity")
		active[level.monster_id] = true
		if expected.has(number):
			check(level.monster_id == expected[number], "The selected destination uses its acquired giant")
	check(active.size() == 14 and Monster.CREATURE_IDS.size() == 14 and Monster.GIANT_IDS.size() == 3,
		"The campaign keeps fourteen identities while retaining the original model catalog")
	var model := Model.new()
	model.start_level(1, 17)
	var progress: Dictionary = model.export_progress()
	var restored := Model.new()
	check(restored.import_progress(progress) and restored.level.monster_id == expected[1],
		"Existing level-number saves restore against the new roster without a schema change")
	check(not progress.run.has("monster_id") and progress.version == 2, "Creature art does not enter the save format")
	var path: String = Monster.MODEL_ROOT + "giants-manifest.json"
	check(FileAccess.file_exists(path), "The supplemental catalog is bundled with the acquired models")
	if not FileAccess.file_exists(path):
		_finish()
		return
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(document is Dictionary and document.get("creatures") is Array, "The supplemental catalog has creature entries")
	if not document is Dictionary or not document.get("creatures") is Array:
		_finish()
		return
	var entries: Array = document.creatures
	var ids: Dictionary = {}
	var monster := Monster.new()
	root.add_child(monster)
	monster.set_process(false)
	for entry: Dictionary in entries:
		var id: String = str(entry.id)
		check(id in Monster.GIANT_IDS and not ids.has(id), "A supplemental entry identifies one distinct giant")
		ids[id] = true
		if id not in Monster.GIANT_IDS:
			continue
		var resource_path: String = Monster.MODEL_ROOT + id + ".glb"
		check(ResourceLoader.exists(resource_path), id + " has an actual local GLB")
		if not ResourceLoader.exists(resource_path):
			continue
		var packed := load(resource_path) as PackedScene
		var source: Node3D = packed.instantiate() as Node3D
		root.add_child(source)
		check(monster.set_creature(id), id + " loads through the shared lifecycle")
		await process_frame
		_check_materials(monster, source, id)
		_check_source_rig(monster, id)
		var bounds: AABB = monster.get_model_bounds()
		check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.x > 0.0 and bounds.size.y > 0.0 and bounds.size.z > 0.0,
			id + " exposes valid framing bounds")
		check(is_equal_approx(monster.get_normalized_height(), float(entry.normalized_height)), id + " retains its measured height")
		var names: PackedStringArray = monster.source_animation_names()
		check("Idle" in names, id + " has an authored source idle")
		for role: Variant in entry.get("animations", {}):
			check(str(role) in names and monster.source_animation_duration(str(role)) > 0.0,
				id + " imports the declared source clip " + str(role))
		monster._process(0.1)
		check(monster._joint_base.is_empty(), id + " never receives unrelated low-poly rig bone overlays")
		check(not monster._breathing.transform.is_equal_approx(Transform3D.IDENTITY), id + " keeps a restrained body idle")
		await _check_lifecycle(monster, id)
		source.queue_free()
		await process_frame
	check(ids.size() == 3, "The supplemental catalog contains the three selected giants")
	check(monster.set_creature("lpm-alien"), "The original creatures still load after a different rig family")
	monster.queue_free()
	await process_frame
	await _check_threat_camera_lifecycle()
	_finish()


func _materials(node: Node) -> Array[StandardMaterial3D]:
	var found: Array[StandardMaterial3D] = []
	if node is MeshInstance3D:
		for surface: int in range(node.get_surface_override_material_count()):
			var material: Material = node.get_active_material(surface)
			if material is StandardMaterial3D:
				found.append(material)
	for child: Node in node.get_children():
		found.append_array(_materials(child))
	return found


func _check_source_rig(monster, id: String) -> void:
	var skeletons: Array[Node] = monster.find_children("*", "Skeleton3D", true, false)
	var meshes: Array[Node] = monster.find_children("*", "MeshInstance3D", true, false)
	var skinned: bool = false
	for node: Node in meshes:
		var mesh := node as MeshInstance3D
		skinned = skinned or (mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) is Skeleton3D)
	check(not skeletons.is_empty() and skinned, id + " retains a real bound source skeleton")
	if monster._player == null or not monster._clips.has("Idle") or skeletons.is_empty():
		check(false, id + " has an evaluable source idle")
		return
	var before: Array[Transform3D] = []
	var skeleton := skeletons[0] as Skeleton3D
	for bone: int in range(skeleton.get_bone_count()):
		before.append(skeleton.get_bone_pose(bone))
	var clip: Animation = monster._player.get_animation(monster._clips.Idle)
	monster._player.seek(clip.length * 0.43, true)
	monster._player.advance(0.0)
	var moved: bool = false
	for bone: int in range(skeleton.get_bone_count()):
		moved = moved or not before[bone].is_equal_approx(skeleton.get_bone_pose(bone))
	check(moved, id + " imported Idle deforms its source rig rather than only moving a container")
	monster.reset_pose()


func _check_materials(monster, source: Node3D, id: String) -> void:
	var originals: Array[StandardMaterial3D] = _materials(source)
	check(not originals.is_empty() and originals.size() == monster._materials.size(), id + " keeps every authored surface")
	var textured: bool = false
	for index: int in range(mini(originals.size(), monster._materials.size())):
		var original: StandardMaterial3D = originals[index]
		var active: StandardMaterial3D = monster._materials[index]
		textured = textured or original.albedo_texture != null
		check(active != original and active.albedo_texture == original.albedo_texture and active.normal_texture == original.normal_texture
			and active.emission_texture == original.emission_texture and active.albedo_color == original.albedo_color,
			id + " duplicates its material without replacing source textures or painted color")
		check(is_equal_approx(active.roughness, original.roughness) and is_equal_approx(active.metallic, original.metallic)
			and active.uv1_scale == original.uv1_scale and active.uv1_triplanar == original.uv1_triplanar,
			id + " preserves its authored surface response and texture coordinates")
	check(textured, id + " renders the acquired painted textures")


func _finish_reaction(monster) -> void:
	if monster._reaction != null and monster._reaction.is_valid():
		monster._reaction.custom_step(60.0)
	await process_frame


func _check_lifecycle(monster, id: String) -> void:
	monster.set_reduced_motion(false)
	for kind: String in ["Attack", "Hit"]:
		var began: bool = monster.play_attack() if kind == "Attack" else monster.react_hit()
		check(began, id + " accepts " + kind + " feedback")
		var duration: float = monster.source_animation_duration(kind)
		if duration > 0.0:
			monster._reaction.custom_step(duration * 0.5)
			check(monster.state == ("attacking" if kind == "Attack" else "reacting"), id + " does not cut the source take short")
			check(monster._player.current_animation == monster._clips[kind], id + " plays its actual " + kind + " clip")
		await _finish_reaction(monster)
		check(monster.state == "idle" and monster._motion.transform.is_equal_approx(Transform3D.IDENTITY), id + " settles after " + kind)
		check(is_zero_approx(monster._flash), id + " restores its temporary material feedback")
	check(monster.play_attack() and monster.react_hit(), id + " lets impact replace an in-flight attack")
	monster.set_reduced_motion(true)
	check(monster.state == "idle" and monster._reaction == null and monster._motion.transform.is_equal_approx(Transform3D.IDENTITY),
		id + " reduced motion cancels active spatial feedback immediately")
	var position: float = monster._player.current_animation_position
	monster._process(0.1)
	check(is_equal_approx(position, monster._player.current_animation_position) and monster._breathing.transform.is_equal_approx(Transform3D.IDENTITY),
		id + " reduced motion freezes the imported source take and body motion")
	check(monster.react_hit(), id + " keeps interaction feedback with reduced motion")
	await _finish_reaction(monster)
	monster.set_reduced_motion(false)
	check(monster.defeat(), id + " can complete a normal battle")
	await _finish_reaction(monster)
	check(not monster.visible and monster.state == "defeated", id + " hides only after defeat completes")
	var retained: int = monster._model.get_instance_id()
	check(monster.set_creature(id) and monster._model.get_instance_id() == retained and monster.visible and monster.state == "idle",
		id + " resumes without reloading its textures or retaining a defeated pose")


func _finish() -> void:
	print("Talk Quest giants: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_threat_camera_lifecycle() -> void:
	var file: String = "user://quest-giant-camera-%d.cfg" % Time.get_ticks_usec()
	var quest := Quest.new()
	quest.save_path = file
	root.add_child(quest)
	quest.size = Vector2(960, 640)
	quest.set_process(false)
	await process_frame
	quest.start_level(1)
	await process_frame
	var starts: Array[String] = []
	var finishes: Array[String] = []
	quest._monster.reaction_started.connect(func(kind: String) -> void: starts.append(kind))
	quest._monster.reaction_finished.connect(func(kind: String) -> void: finishes.append(kind))
	quest._threat_left = 0.01
	quest._process(0.02)
	check(starts.count("attack") == 1 and quest._monster.state == "attacking", "An elapsed threat timer starts one source attack")
	check(quest._camera_tween != null and quest._camera_tween.is_valid(), "Attack start coordinates the reaction camera")
	if quest._camera_tween != null and quest._camera_tween.is_valid():
		quest._camera_tween.custom_step(0.045)
	quest.pause()
	var expansion: float = quest._giant_camera_expansion
	var field_of_view: float = quest._camera.fov
	var source_time: float = quest._monster._player.current_animation_position
	var threat_left: float = quest._threat_left
	await create_timer(0.06).timeout
	quest._process(0.2)
	check(is_equal_approx(quest._giant_camera_expansion, expansion) and is_equal_approx(quest._camera.fov, field_of_view),
		"Pausing holds the reaction camera at its current framing")
	check(is_equal_approx(quest._monster._player.current_animation_position, source_time) and is_equal_approx(quest._threat_left, threat_left),
		"Pausing freezes both the source take and the next threat timer")
	quest._continue_run()
	await create_timer(0.04).timeout
	check(quest._monster._player.current_animation_position > source_time, "Resuming continues the same source attack")
	if quest._camera_tween != null and quest._camera_tween.is_valid():
		quest._camera_tween.custom_step(0.3)
	check(quest._giant_camera_expansion > 1.0, "The attack camera provides the expanded framing")
	if quest._monster._reaction != null and quest._monster._reaction.is_valid():
		quest._monster._reaction.custom_step(60.0)
	check(quest._monster.state == "idle" and finishes.count("attack") == 1,
		"The attack completes once before the return camera has settled")
	check(quest._camera_tween != null and quest._camera_tween.is_valid() and quest._giant_camera_expansion > 1.0,
		"Idle can overlap the finite camera return transition")
	quest.set_reduced_motion(true)
	check(is_equal_approx(quest._giant_camera_expansion, 1.0)
		and (quest._camera_tween == null or not quest._camera_tween.is_valid()),
		"Enabling reduced motion immediately cancels a camera return even when the creature is already idle")
	quest._threat_left = 0.0
	quest._process(0.3)
	check(starts.count("attack") == 1 and quest._monster.state == "idle", "Reduced motion suppresses automatic attack flourishes")
	quest.set_reduced_motion(false)
	quest._impact_pending = true
	quest._process(0.01)
	check(starts.count("attack") == 1, "A pending word impact takes priority over a scheduled threat")
	quest._impact_pending = false
	quest._process(0.01)
	check(starts.count("attack") == 2, "A waiting threat can start after the word impact clears")
	quest._monster.react_hit()
	if quest._monster._reaction != null and quest._monster._reaction.is_valid():
		quest._monster._reaction.custom_step(60.0)
	check(starts.count("hit") == 1 and finishes.count("hit") == 1 and finishes.count("attack") == 1,
		"An impact replaces a threat without an abandoned attack completion event")
	quest.game.phase = "lost"
	quest._threat_left = 0.0
	quest._process(0.1)
	check(starts.count("attack") == 2, "Finished play does not schedule another threat")
	quest.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
