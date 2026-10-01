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
		var thumbnail := load(str(entry.thumbnail)) as Texture2D
		check(thumbnail != null and thumbnail.get_width() <= 320 and thumbnail.get_height() <= 320,
			id + " supplies a compact local card thumbnail")
	await _check_reactions(monster)
	monster.queue_free()
	await process_frame
	print("Talk Quest monsters: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


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
	check(monster.react_hit() and monster.state == "reacting", "Normal mode accepts a friendly hit reaction")
	await _finish_tween(monster)
	check("hit" in events and monster.state == "idle" and monster.visible, "Hit completes once and returns to visible idle")
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
	check(not monster.react_hit() and not monster.defeat(), "Cooperative mode rejects both combat entry points")
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
