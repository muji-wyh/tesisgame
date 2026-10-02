extends SceneTree

const Monster = preload("res://scripts/talk_quest_monster.gd")

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
	var monster = Monster.new()
	root.add_child(monster)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Monster.MODEL_ROOT + "manifest.json"))
	var entries: Array = manifest.get("creatures", [])
	check(entries.size() == 14 and Monster.CREATURE_IDS.size() == 14, "The approved roster contains fourteen runtime characters")
	var ids: Dictionary = {}
	var hashes: Dictionary = {}
	for entry: Dictionary in entries:
		var id: String = str(entry.id)
		check(not ids.has(id) and not hashes.has(entry.sha256), id + " has its own identity and model payload")
		ids[id] = true
		hashes[entry.sha256] = true
		check(monster.set_creature(id), id + " loads as a Godot packed 3D scene")
		await process_frame
		var skeletons: Array[Node] = monster.find_children("*", "Skeleton3D", true, false)
		var meshes: Array[Node] = monster.find_children("*", "MeshInstance3D", true, false)
		check(skeletons.size() == 1 and not meshes.is_empty(), id + " contains complete meshes and a source skeleton")
		for node: Node in meshes:
			var mesh := node as MeshInstance3D
			check(mesh.mesh != null and mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) is Skeleton3D,
				id + " has an actual skinned mesh bound to its skeleton")
		var names: PackedStringArray = monster.source_animation_names()
		check("Idle" in names and names.size() <= 4, id + " exposes a compact source animation set")
		check(monster.get_normalized_height() > 0.0 and monster.get_normalized_height() <= 2.01,
			id + " provides its normalized framing height")
		if skeletons.size() == 1 and monster._player != null and monster._clips.has("Idle"):
			var skeleton := skeletons[0] as Skeleton3D
			var player := monster._player as AnimationPlayer
			var animation: Animation = player.get_animation(monster._clips["Idle"])
			check(animation.length > 0.0 and animation.get_track_count() > 0, id + " has real source animation tracks")
			var animation_root: Node = player.get_node(player.root_node)
			var bindings_valid: bool = true
			var skeletal_tracks: int = 0
			for track: int in range(animation.get_track_count()):
				var path: NodePath = animation.track_get_path(track)
				var target: Node = animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
				bindings_valid = bindings_valid and target != null
				if target is Skeleton3D and path.get_subname_count() > 0:
					bindings_valid = bindings_valid and target.find_bone(path.get_subname(0)) >= 0
					skeletal_tracks += 1
			check(bindings_valid and skeletal_tracks > 0, id + " source tracks resolve to the actual skinned skeleton bones")
			monster._restore_joint_motion()
			player.pause()
			player.seek(0.0, true)
			player.advance(0.0)
			var first: Array[Transform3D] = []
			for bone: int in range(skeleton.get_bone_count()):
				first.append(skeleton.get_bone_pose(bone))
			player.seek(animation.length * 0.43, true)
			player.advance(0.0)
			var moving: bool = false
			for bone: int in range(skeleton.get_bone_count()):
				moving = moving or not first[bone].is_equal_approx(skeleton.get_bone_pose(bone))
			check(moving, id + " source Idle changes bone poses after Godot import")
			_check_live_motion(monster, skeleton, id)
		var thumbnail := load(str(entry.thumbnail)) as Texture2D
		check(thumbnail != null and thumbnail.get_width() <= 320 and thumbnail.get_height() <= 320,
			id + " supplies a compact local card thumbnail")
	await _check_reactions(monster)
	monster.queue_free()
	await process_frame
	print("Talk Quest monsters: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _bone_poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for bone: int in range(skeleton.get_bone_count()):
		poses.append(skeleton.get_bone_pose(bone))
	return poses


func _step_idle(monster) -> void:
	for delta: float in [0.1, 0.1, 0.1, 0.071]:
		monster._process(delta)


func _check_live_motion(monster, skeleton: Skeleton3D, id: String) -> void:
	monster.reset_pose()
	var at_rest: bool = true
	for bone: int in range(skeleton.get_bone_count()):
		at_rest = at_rest and skeleton.get_bone_pose(bone).is_equal_approx(skeleton.get_bone_rest(bone))
	check(not at_rest, id + " evaluates an authored source pose immediately instead of displaying its rig rest pose")
	var before: Array[Transform3D] = _bone_poses(skeleton)
	var clip_time: float = monster._player.current_animation_position
	_step_idle(monster)
	check(monster._player.is_playing() and not is_equal_approx(clip_time, monster._player.current_animation_position),
		id + " advances its source Idle through the real per-frame performance path")
	var limb_moved: bool = false
	for bone: int in range(skeleton.get_bone_count()):
		var name: String = skeleton.get_bone_name(bone).to_lower()
		if "arm" in name or "wing" in name or "ear" in name:
			limb_moved = limb_moved or before[bone].basis.get_rotation_quaternion().angle_to(
				skeleton.get_bone_pose_rotation(bone)) > 0.025
	check(limb_moved, id + " visibly moves limb joints, not only its model container")
	check(not monster._breathing.transform.is_equal_approx(Transform3D.IDENTITY),
		id + " has an observable personality idle around the source clip")
	var posed: Array[Transform3D] = _bone_poses(skeleton)
	var body: Transform3D = monster._breathing.transform
	monster.reset_pose()
	_step_idle(monster)
	var repeatable: bool = body.is_equal_approx(monster._breathing.transform)
	for bone: int in range(skeleton.get_bone_count()):
		repeatable = repeatable and posed[bone].is_equal_approx(skeleton.get_bone_pose(bone))
	check(repeatable, id + " restores the source pose before additive motion without accumulating joint drift")
	monster.set_reduced_motion(true)
	var still: Array[Transform3D] = _bone_poses(skeleton)
	clip_time = monster._player.current_animation_position
	_step_idle(monster)
	var unchanged: bool = is_equal_approx(clip_time, monster._player.current_animation_position)
	for bone: int in range(skeleton.get_bone_count()):
		unchanged = unchanged and still[bone].is_equal_approx(skeleton.get_bone_pose(bone))
	check(unchanged and monster._breathing.transform.is_equal_approx(Transform3D.IDENTITY),
		id + " reduced motion freezes source bones and all continuous authored movement")
	monster.set_reduced_motion(false)


func _finish_tween(monster) -> void:
	await process_frame
	if monster._reaction != null and monster._reaction.is_valid():
		monster._reaction.custom_step(3.0)
	await process_frame


func _check_reactions(monster) -> void:
	var events: Array[String] = []
	monster.reaction_finished.connect(func(kind: String) -> void: events.append(kind))
	monster.set_cooperative_mode(false)
	monster.set_reduced_motion(false)
	check(monster.set_creature("lpm-bunny"), "A second level replaces the previous complete character")
	check(monster.play_attack() and monster.state == "attacking", "The normal character can offer a playful your-turn flourish")
	monster._reaction.custom_step(0.3)
	monster._process(0.0)
	check(monster._gesture > 0.5 and not monster._motion.transform.is_equal_approx(Transform3D.IDENTITY),
		"The flourish includes readable anticipation and a limb gesture")
	await _finish_tween(monster)
	check(events.count("attack") == 1 and monster.state == "idle" and monster._motion.transform.is_equal_approx(Transform3D.IDENTITY),
		"The flourish completes once and restores its exact base transform")
	check(monster.react_hit() and monster.state == "reacting", "Normal mode accepts a friendly hit reaction")
	monster._reaction.custom_step(0.08)
	monster._process(0.0)
	check(monster._motion.scale.y < 0.85 and monster._motion.position.z < -0.1,
		"An impact has a readable squash and backward recoil")
	check(monster._flash > 0.0 and monster._materials[0].emission_enabled,
		"An impact briefly lights its private material")
	await _finish_tween(monster)
	check("hit" in events and monster.state == "idle" and monster.visible, "Hit completes once and returns to visible idle")
	check(monster._materials[0].albedo_color == monster._material_base[0].albedo
		and monster._materials[0].emission_enabled == monster._material_base[0].enabled
		and is_equal_approx(monster._materials[0].emission_energy_multiplier, monster._material_base[0].energy),
		"A completed flash restores the original albedo and emission")
	check(monster.play_attack(), "A new flourish may start before an impact")
	check(monster.react_hit(), "An impact can replace the flourish without leaving an old completion callback")
	await _finish_tween(monster)
	check(events.count("attack") == 1 and events.count("hit") == 2, "Only the replacement reaction completes")
	check(monster.react_hit(), "A reaction may be paused with the adventure")
	await process_frame
	monster.process_mode = Node.PROCESS_MODE_DISABLED
	var paused_clock: float = monster._clock
	var paused_clip: float = monster._player.current_animation_position
	var paused_transform: Transform3D = monster._motion.transform
	await create_timer(0.07).timeout
	check(is_equal_approx(monster._clock, paused_clock) and is_equal_approx(monster._player.current_animation_position, paused_clip)
		and monster._motion.transform.is_equal_approx(paused_transform), "Pausing freezes the source clip, authored idle and bound reaction tween together")
	monster.process_mode = Node.PROCESS_MODE_INHERIT
	await process_frame
	await process_frame
	check(monster._clock > paused_clock, "Resuming advances the same performance without replacing the model")
	await _finish_tween(monster)
	monster.celebrate()
	await _finish_tween(monster)
	check("celebrate" in events and monster.state == "idle", "Celebration finishes without changing game state")
	check(monster.defeat(), "Normal mode can begin the friendly retreat")
	await _finish_tween(monster)
	check("defeat" in events and not monster.visible, "A completed friendly retreat hides the model")
	monster.reset_pose()
	check(monster.visible and monster.state == "idle", "Reset restores the character after retreat")
	monster.set_cooperative_mode(true)
	check(monster.state == "sleeping" and monster.visible, "Cooperative mode begins with a sleeping source character")
	var old_events: int = events.size()
	check(not monster.react_hit() and not monster.defeat() and not monster.play_attack(), "Cooperative mode rejects every combat gesture entry point")
	check(monster.state == "sleeping" and monster.visible and events.size() == old_events,
		"Rejected combat cannot disturb or hide the cooperative character")
	monster.repair_progress(3, 5)
	check(is_equal_approx(monster.repair_fraction, 0.6) and monster.state == "sleeping", "Partial repair preserves sleep and records gradual progress")
	monster.repair_progress(99, 5)
	check(is_equal_approx(monster.repair_fraction, 1.0), "Repair progress is bounded")
	monster.wake_up()
	await _finish_tween(monster)
	check("wake" in events and monster.state == "idle" and monster.visible, "Cooperative completion wakes the character instead of defeating it")
	monster.set_reduced_motion(true)
	monster.set_cooperative_mode(false)
	check(monster.react_hit(), "Reduced motion preserves successful interaction feedback")
	await _finish_tween(monster)
	check(monster.state == "idle" and monster.visible, "Reduced-motion feedback still completes normally")
	monster.set_reduced_motion(false)
	check(monster.react_hit(), "A motion preference may change during a hit")
	monster._reaction.custom_step(0.08)
	monster.set_reduced_motion(true)
	check(monster.state == "idle" and monster._reaction == null and monster._motion.transform.is_equal_approx(Transform3D.IDENTITY)
		and is_zero_approx(monster._flash), "Enabling reduced motion immediately settles the in-flight reaction and restores its material")
	var retained_model_id: int = monster._model.get_instance_id()
	check(monster.react_hit(), "A reaction can be active when a lesson resumes")
	check(monster.set_creature(monster.creature_id), "Resuming the same creature succeeds")
	await process_frame
	check(monster._model.get_instance_id() == retained_model_id and monster.state == "idle"
		and monster.visible and monster._reaction == null,
		"Resuming reuses the complete rig and cancels its old reaction without stale material resources")
	var original_id: String = monster.creature_id
	check(not monster.set_creature("not-a-monster") and monster.creature_id == original_id,
		"An unknown identity cannot replace a valid loaded character")
