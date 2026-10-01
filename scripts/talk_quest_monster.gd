extends Node3D
## Rigged source character with small, explicitly authored gameplay reactions.
## The caller owns the SubViewport, camera, lights, and game state.

signal reaction_finished(kind: String)

const MODEL_ROOT: String = "res://assets/talk_quest/monsters/"
const CREATURE_IDS: Array[String] = [
	"lpm-alien", "lpm-alpaking", "lpm-armabee", "lpm-bird", "lpm-bunny",
	"lpm-cactoro", "lpm-dino", "lpm-frog", "lpm-glub", "lpm-goleing",
	"lpm-hywirl", "lpm-mushroom", "lpm-squidle", "lpm-yeti",
]

var creature_id: String = ""
var state: String = "idle"
var reduced_motion: bool = false
var cooperative_mode: bool = false
var repair_fraction: float = 0.0
var _motion := Node3D.new()
var _breathing := Node3D.new()
var _model: Node3D
var _player: AnimationPlayer
var _reaction: Tween
var _clock: float = 0.0
var _height: float = 2.0
var _materials: Array[StandardMaterial3D] = []
var _clips: Dictionary = {}


func _init() -> void:
	_ensure_root()


func _ensure_root() -> void:
	if _motion.get_parent() == null:
		_motion.name = "GameplayMotion"
		_breathing.name = "Breathing"
		add_child(_motion)
		_motion.add_child(_breathing)


func set_creature(id: String) -> bool:
	if id not in CREATURE_IDS:
		push_warning("Unknown Talk Quest creature: " + id)
		return false
	if id == creature_id and is_instance_valid(_model):
		# Reuse the rig and overrides on resume instead of replacing identical
		# cached meshes while their previous instances await deferred cleanup.
		reset_pose()
		return true
	var packed := load(MODEL_ROOT + id + ".glb") as PackedScene
	if packed == null:
		return false
	_ensure_root()
	_cancel_reaction()
	if is_instance_valid(_model):
		_breathing.remove_child(_model)
		_model.queue_free()
	_materials.clear()
	_clips.clear()
	_player = null
	_model = packed.instantiate() as Node3D
	if _model == null:
		return false
	_breathing.add_child(_model)
	creature_id = id
	_scan_model(_model)
	_height = 2.0
	var manifest_path: String = MODEL_ROOT + "manifest.json"
	if FileAccess.file_exists(manifest_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary:
			for entry: Dictionary in parsed.get("creatures", []):
				if str(entry.get("id", "")) == id:
					_height = float(entry.get("normalized_height", 2.0))
	if _player != null:
		for animation_name: StringName in _player.get_animation_list():
			var short_name: String = str(animation_name).get_slice("/", str(animation_name).get_slice_count("/") - 1)
			_clips[short_name] = animation_name
			if short_name == "Idle":
				_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
		_player.speed_scale = 0.0 if reduced_motion else 1.0
	reset_pose()
	return true


func _scan_model(node: Node) -> void:
	if node is AnimationPlayer and _player == null:
		_player = node as AnimationPlayer
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface: int in range(mesh_node.get_surface_override_material_count()):
			var original: Material = mesh_node.get_active_material(surface)
			if original is StandardMaterial3D:
				var material := original.duplicate() as StandardMaterial3D
				material.roughness = 0.72
				material.metallic = 0.0
				mesh_node.set_surface_override_material(surface, material)
				_materials.append(material)
	for child: Node in node.get_children():
		_scan_model(child)


func source_animation_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key: Variant in _clips:
		if str(key) != "RESET":
			names.append(str(key))
	return names


func get_normalized_height() -> float:
	return _height


func get_model_bounds() -> AABB:
	return AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, _height, 2.0))


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if _player != null:
		_player.speed_scale = 0.0 if enabled or state == "sleeping" else 1.0
	_breathing.position = Vector3.ZERO
	_breathing.rotation = Vector3.ZERO


func set_cooperative_mode(enabled: bool) -> void:
	cooperative_mode = enabled
	repair_fraction = 0.0
	reset_pose()


func reset_pose() -> void:
	_ensure_root()
	_cancel_reaction()
	_motion.position = Vector3.ZERO
	_motion.rotation = Vector3.ZERO
	_motion.scale = Vector3.ONE
	_breathing.position = Vector3.ZERO
	_breathing.rotation = Vector3.ZERO
	visible = true
	_apply_repair_glow()
	if cooperative_mode:
		set_sleeping(true)
	else:
		play_idle()


func play_idle() -> void:
	if cooperative_mode and state == "sleeping":
		return
	state = "idle"
	_play_source("Idle")


func set_sleeping(sleeping: bool) -> void:
	_cancel_reaction()
	if not sleeping:
		_motion.rotation = Vector3.ZERO
		_motion.scale = Vector3.ONE
		state = "idle"
		play_idle()
		return
	state = "sleeping"
	_play_source("Idle")
	if _player != null:
		_player.seek(0.0, true)
		_player.speed_scale = 0.0
	_motion.rotation.z = -0.14
	_motion.scale = Vector3(1.02, 0.88, 1.02)


func react_hit() -> bool:
	if cooperative_mode or not is_instance_valid(_model) or state == "defeated":
		return false
	_cancel_reaction()
	state = "reacting"
	if not _play_source("Hit"):
		_play_source("Idle")
	_reaction = create_tween()
	if reduced_motion:
		_reaction.tween_interval(0.15)
	else:
		_reaction.set_parallel(true)
		_reaction.tween_property(_motion, "scale", Vector3(1.07, 0.89, 1.07), 0.09)
		_reaction.tween_property(_motion, "rotation:z", -0.07, 0.09)
		_reaction.chain().tween_property(_motion, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_reaction.parallel().tween_property(_motion, "rotation:z", 0.0, 0.24)
	_reaction.chain().tween_callback(_finish_reaction.bind("hit", true))
	return true


func defeat() -> bool:
	if cooperative_mode or not is_instance_valid(_model) or state == "defeated":
		return false
	_cancel_reaction()
	state = "defeated"
	# The friendly retreat is authored gameplay motion, not a claimed source death.
	if not _play_source("Celebrate"):
		_play_source("Idle")
	_reaction = create_tween()
	_reaction.tween_interval(0.12 if reduced_motion else 0.35)
	if not reduced_motion:
		_reaction.tween_property(_motion, "position", Vector3(0.36, 0.16, 0.0), 0.2).set_trans(Tween.TRANS_SINE)
		_reaction.parallel().tween_property(_motion, "rotation:z", -0.16, 0.2)
		_reaction.tween_property(_motion, "scale", Vector3.ONE * 0.015, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_reaction.tween_callback(func() -> void:
		visible = false
		reaction_finished.emit("defeat")
	)
	return true


func celebrate() -> void:
	if not is_instance_valid(_model):
		return
	_cancel_reaction()
	state = "celebrating"
	visible = true
	_motion.position = Vector3.ZERO
	_motion.rotation = Vector3.ZERO
	_motion.scale = Vector3.ONE
	if not _play_source("Celebrate"):
		_play_source("Idle")
	_reaction = create_tween()
	if reduced_motion:
		_reaction.tween_interval(0.35)
	else:
		for bounce: int in range(2):
			_reaction.tween_property(_motion, "position:y", 0.15, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_reaction.tween_property(_motion, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_reaction.tween_callback(_finish_reaction.bind("celebrate", true))


func repair_progress(completed: int, total: int = 5) -> void:
	if not cooperative_mode:
		return
	repair_fraction = clampf(float(completed) / float(maxi(total, 1)), 0.0, 1.0)
	_apply_repair_glow()
	if state != "sleeping" or reduced_motion:
		return
	_cancel_reaction()
	_reaction = create_tween()
	_reaction.tween_property(_motion, "rotation:z", -0.09, 0.16).set_trans(Tween.TRANS_SINE)
	_reaction.tween_property(_motion, "rotation:z", -0.14, 0.28).set_trans(Tween.TRANS_SINE)
	_reaction.tween_callback(func() -> void: reaction_finished.emit("repair"))


func wake_up() -> void:
	if not cooperative_mode or not is_instance_valid(_model):
		return
	_cancel_reaction()
	repair_fraction = 1.0
	_apply_repair_glow()
	state = "waking"
	_play_source("Celebrate")
	_reaction = create_tween()
	var duration: float = 0.2 if reduced_motion else 0.75
	_reaction.tween_property(_motion, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reaction.parallel().tween_property(_motion, "rotation", Vector3.ZERO, duration)
	if not reduced_motion:
		_reaction.tween_property(_motion, "position:y", 0.12, 0.25).set_trans(Tween.TRANS_SINE)
		_reaction.tween_property(_motion, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	_reaction.tween_callback(_finish_reaction.bind("wake", true))


func _apply_repair_glow() -> void:
	for material: StandardMaterial3D in _materials:
		material.emission_enabled = cooperative_mode and repair_fraction > 0.0
		material.emission = Color(0.18, 0.58, 0.38)
		material.emission_energy_multiplier = repair_fraction * 0.32


func _play_source(role: String) -> bool:
	if _player == null or not _clips.has(role):
		return false
	_player.speed_scale = 0.0 if reduced_motion else 1.0
	_player.play(_clips[role], 0.12)
	return true


func _finish_reaction(kind: String, resume_idle: bool) -> void:
	if resume_idle:
		state = "idle"
		play_idle()
	reaction_finished.emit(kind)


func _cancel_reaction() -> void:
	if _reaction != null and _reaction.is_valid():
		_reaction.kill()
	_reaction = null


func _process(delta: float) -> void:
	if reduced_motion or not is_instance_valid(_model) or not visible:
		return
	_clock += minf(delta, 0.1)
	if state == "sleeping":
		_breathing.position.y = sin(_clock * 1.5) * 0.015
		_breathing.rotation.z = sin(_clock * 1.5) * 0.008
	else:
		_breathing.position = Vector3.ZERO
		_breathing.rotation = Vector3.ZERO
