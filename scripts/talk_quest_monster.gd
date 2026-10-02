extends Node3D
## Source skeletal animation plus bounded, authored character performance.
## The caller owns the SubViewport, camera, lights, and game state.

signal reaction_finished(kind: String)
signal reaction_started(kind: String)

const MODEL_ROOT: String = "res://assets/talk_quest/monsters/"
const CREATURE_IDS: Array[String] = [
	"lpm-alien", "lpm-alpaking", "lpm-armabee", "lpm-bird", "lpm-bunny",
	"lpm-cactoro", "lpm-dino", "lpm-frog", "lpm-glub", "lpm-goleing",
	"lpm-hywirl", "lpm-mushroom", "lpm-squidle", "lpm-yeti",
]
const GIANT_IDS: Array[String] = ["giant-rock-guardian", "giant-storm-dragon", "giant-ember-golem"]
const GIANT_MOTION: Dictionary = {
	"giant-rock-guardian": {"rate": 0.90, "bob": 0.008, "sway": 0.008, "turn": 0.018, "squash": 0.003},
	"giant-storm-dragon": {"rate": 1.15, "bob": 0.018, "sway": 0.012, "turn": 0.022, "squash": 0.002},
	"giant-ember-golem": {"rate": 0.75, "bob": 0.006, "sway": 0.006, "turn": 0.015, "squash": 0.002},
}
# The source rigs share limb names, but each character keeps its own cadence.
# Amplitudes are in normalized model units or radians, never accumulated offsets.
const MOTION_PROFILES: Dictionary = {
	"lpm-alien": {"rate": 1.9, "bob": 0.045, "sway": 0.055, "turn": 0.15, "squash": 0.025, "limb": 0.20},
	"lpm-alpaking": {"rate": 2.5, "bob": 0.13, "sway": 0.055, "turn": 0.13, "squash": 0.018, "limb": 0.20, "hover": true},
	"lpm-armabee": {"rate": 3.5, "bob": 0.095, "sway": 0.035, "turn": 0.11, "squash": 0.025, "limb": 0.26, "hover": true},
	"lpm-bird": {"rate": 2.6, "bob": 0.065, "sway": 0.04, "turn": 0.16, "squash": 0.025, "limb": 0.27},
	"lpm-bunny": {"rate": 2.8, "bob": 0.085, "sway": 0.025, "turn": 0.14, "squash": 0.045, "limb": 0.20},
	"lpm-cactoro": {"rate": 1.55, "bob": 0.035, "sway": 0.045, "turn": 0.12, "squash": 0.020, "limb": 0.15},
	"lpm-dino": {"rate": 2.05, "bob": 0.05, "sway": 0.035, "turn": 0.15, "squash": 0.025, "limb": 0.18},
	"lpm-frog": {"rate": 2.7, "bob": 0.08, "sway": 0.03, "turn": 0.14, "squash": 0.055, "limb": 0.23},
	"lpm-glub": {"rate": 1.8, "bob": 0.14, "sway": 0.075, "turn": 0.15, "squash": 0.035, "limb": 0.24, "hover": true},
	"lpm-goleing": {"rate": 1.45, "bob": 0.11, "sway": 0.06, "turn": 0.12, "squash": 0.015, "limb": 0.16, "hover": true},
	"lpm-hywirl": {"rate": 2.2, "bob": 0.13, "sway": 0.065, "turn": 0.16, "squash": 0.030, "limb": 0.24, "hover": true},
	"lpm-mushroom": {"rate": 1.8, "bob": 0.045, "sway": 0.07, "turn": 0.13, "squash": 0.035, "limb": 0.18},
	"lpm-squidle": {"rate": 2.35, "bob": 0.12, "sway": 0.055, "turn": 0.15, "squash": 0.045, "limb": 0.26, "hover": true},
	"lpm-yeti": {"rate": 1.35, "bob": 0.04, "sway": 0.045, "turn": 0.10, "squash": 0.020, "limb": 0.20},
}
# Body surfaces keep the acquired palette while responding differently to light.
# The source eye, tooth and wing surfaces are treated separately below.
const SURFACE_PROFILES: Dictionary = {
	"lpm-alien": {"surface": "skin", "roughness": 0.43, "specular": 0.50, "coat": 0.12},
	"lpm-alpaking": {"surface": "fur", "roughness": 0.87, "specular": 0.22, "coat": 0.0},
	"lpm-armabee": {"surface": "shell", "roughness": 0.32, "specular": 0.60, "coat": 0.32},
	"lpm-bird": {"surface": "fur", "roughness": 0.78, "specular": 0.30, "coat": 0.0},
	"lpm-bunny": {"surface": "fur", "roughness": 0.91, "specular": 0.20, "coat": 0.0},
	"lpm-cactoro": {"surface": "skin", "roughness": 0.66, "specular": 0.32, "coat": 0.07},
	"lpm-dino": {"surface": "skin", "roughness": 0.52, "specular": 0.42, "coat": 0.10},
	"lpm-frog": {"surface": "skin", "roughness": 0.26, "specular": 0.63, "coat": 0.38},
	"lpm-glub": {"surface": "skin", "roughness": 0.30, "specular": 0.58, "coat": 0.30},
	"lpm-goleing": {"surface": "stone", "roughness": 0.88, "specular": 0.24, "coat": 0.0},
	"lpm-hywirl": {"surface": "skin", "roughness": 0.38, "specular": 0.51, "coat": 0.16},
	"lpm-mushroom": {"surface": "skin", "roughness": 0.70, "specular": 0.30, "coat": 0.04},
	"lpm-squidle": {"surface": "skin", "roughness": 0.29, "specular": 0.62, "coat": 0.34},
	"lpm-yeti": {"surface": "fur", "roughness": 0.93, "specular": 0.18, "coat": 0.0},
}
# One small shared texture per surface family, never a texture per frame or limb.
static var _surface_textures: Dictionary = {}

var creature_id: String = ""
var state: String = "idle"
var reduced_motion: bool = false
var cooperative_mode: bool = false
var repair_fraction: float = 0.0
var _motion := Node3D.new()
var _breathing := Node3D.new()
var _model: Node3D
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _reaction: Tween
var _clock: float = 0.0
var _height: float = 2.0
var _gesture: float = 0.0
var _flash: float = 0.0
var _profile: Dictionary = {}
var _bones: Dictionary = {}
var _joint_base: Dictionary = {}
var _materials: Array[StandardMaterial3D] = []
var _material_base: Array[Dictionary] = []
var _clips: Dictionary = {}
var _hit_side: float = 1.0
var _is_giant: bool = false
var _bounds: AABB = AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 2.0, 2.0))


func _init() -> void:
	_ensure_root()


func _ensure_root() -> void:
	if _motion.get_parent() == null:
		_motion.name = "GameplayMotion"
		_breathing.name = "Breathing"
		add_child(_motion)
		_motion.add_child(_breathing)


func set_creature(id: String) -> bool:
	if id not in CREATURE_IDS and id not in GIANT_IDS:
		push_warning("Unknown Talk Quest creature: " + id)
		return false
	if id == creature_id and is_instance_valid(_model):
		# Reuse the complete rig on resume, including its private materials.
		reset_pose()
		return true
	var packed := load(MODEL_ROOT + id + ".glb") as PackedScene
	if packed == null:
		return false
	var candidate := packed.instantiate() as Node3D
	if candidate == null:
		return false
	_ensure_root()
	_cancel_reaction()
	_restore_joint_motion()
	if is_instance_valid(_model):
		_breathing.remove_child(_model)
		_model.queue_free()
	_materials.clear()
	_material_base.clear()
	_clips.clear()
	_bones.clear()
	_player = null
	_skeleton = null
	_model = candidate
	_breathing.add_child(_model)
	creature_id = id
	_is_giant = id in GIANT_IDS
	_profile = GIANT_MOTION[id] if _is_giant else MOTION_PROFILES[id]
	_scan_model(_model)
	_height = 2.0
	_bounds = AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 2.0, 2.0))
	var manifest_path: String = MODEL_ROOT + ("giants-manifest.json" if _is_giant else "manifest.json")
	if FileAccess.file_exists(manifest_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary:
			for entry: Dictionary in parsed.get("creatures", []):
				if str(entry.get("id", "")) == id:
					_height = float(entry.get("normalized_height", 2.0))
					_bounds = _read_bounds(entry.get("bounds", {}), _height)
	if _skeleton != null:
		for bone: int in range(_skeleton.get_bone_count()):
			_bones[_skeleton.get_bone_name(bone).replace(".", "_").to_lower()] = bone
	if _player != null:
		# One owner advances source tracks before applying the additive pose.
		# This also makes PROCESS_MODE_DISABLED pause both layers together.
		_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for animation_name: StringName in _player.get_animation_list():
			var short_name: String = str(animation_name).get_slice("/", str(animation_name).get_slice_count("/") - 1)
			_clips[short_name] = animation_name
			if short_name == "Idle":
				_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
			elif _is_giant and short_name != "RESET":
				_player.get_animation(animation_name).loop_mode = Animation.LOOP_NONE
	reset_pose()
	return true


func _scan_model(node: Node) -> void:
	if node is AnimationPlayer and _player == null:
		_player = node as AnimationPlayer
	if node is Skeleton3D and _skeleton == null:
		_skeleton = node as Skeleton3D
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surface: int in range(mesh_node.get_surface_override_material_count()):
			var original: Material = mesh_node.get_active_material(surface)
			if original is StandardMaterial3D:
				var material := original.duplicate() as StandardMaterial3D
				_style_surface(material, original.resource_name)
				mesh_node.set_surface_override_material(surface, material)
				_materials.append(material)
				_material_base.append({
					"albedo": material.albedo_color,
					"enabled": material.emission_enabled,
					"emission": material.emission,
					"energy": material.emission_energy_multiplier,
				})
	for child: Node in node.get_children():
		_scan_model(child)


func _style_surface(material: StandardMaterial3D, source_name: String) -> void:
	# These independently authored creatures bring their own UVs, painted color,
	# normals and emissive masks. Only temporary feedback touches the private copy.
	if _is_giant:
		return
	var profile: Dictionary = SURFACE_PROFILES[creature_id]
	var surface: String = str(profile.surface)
	var name_key: String = source_name.to_lower()
	material.metallic = 0.0
	material.roughness = float(profile.roughness)
	material.metallic_specular = float(profile.specular)
	material.clearcoat_enabled = float(profile.coat) > 0.0
	material.clearcoat = float(profile.coat)
	material.clearcoat_roughness = 0.34
	if "eye_" in name_key:
		# Broad, quiet highlights preserve the pupils instead of glassy white spots.
		var pupil: bool = "black" in name_key
		material.roughness = 0.42 if pupil else 0.70
		material.metallic_specular = 0.30 if pupil else 0.18
		material.clearcoat_enabled = false
		material.clearcoat = 0.0
		return
	if "teeth" in name_key or "horn" in name_key or "beak" in name_key:
		material.roughness = 0.36
		material.metallic_specular = 0.47
		material.clearcoat_enabled = true
		material.clearcoat = 0.10
		return
	if "tongue" in name_key:
		material.roughness = 0.29
		material.metallic_specular = 0.48
		return
	if "wings" in name_key or (creature_id == "lpm-goleing" and "secondary" in name_key):
		# The thin membranes catch a broad sheen; the bodies remain matte.
		material.roughness = 0.48
		material.metallic_specular = 0.46
		material.clearcoat_enabled = false
		surface = "shell"
	var detail: Dictionary = _surface_detail(surface)
	material.albedo_texture = detail.albedo
	material.normal_enabled = true
	material.normal_texture = detail.normal
	material.normal_scale = 0.35 if surface == "stone" else 0.16 if surface == "fur" else 0.08
	material.uv1_triplanar = true
	material.uv1_triplanar_sharpness = 4.0
	material.uv1_scale = Vector3(4.0, 1.3, 4.0) if surface == "fur" else Vector3.ONE * 3.0


static func _surface_detail(family: String) -> Dictionary:
	if _surface_textures.has(family):
		return _surface_textures[family]
	# Baked periodic grain is subtle in color and carries fine grazing-light detail.
	# It adds no extra rendering pass and cannot drift relative to the character.
	const EDGE: int = 64
	var heights := PackedFloat32Array()
	heights.resize(EDGE * EDGE)
	var albedo: Image = Image.create(EDGE, EDGE, false, Image.FORMAT_RGBA8)
	var normal: Image = Image.create(EDGE, EDGE, false, Image.FORMAT_RGBA8)
	for y: int in range(EDGE):
		for x: int in range(EDGE):
			var u: float = float(x) / float(EDGE) * TAU
			var v: float = float(y) / float(EDGE) * TAU
			var grain: float = sin(u * 7.0 + cos(v * 3.0)) * cos(v * 9.0 + sin(u * 2.0))
			grain = grain * 0.55 + sin(u * 17.0 - v * 13.0) * 0.20 + cos(u * 3.0 + v * 5.0) * 0.25
			if family == "fur":
				grain = sin(u * 13.0 + sin(v * 2.0)) * 0.55 + grain * 0.45
			elif family == "stone":
				grain = grain * 0.5 + sin(u * 2.0 + sin(v * 3.0)) * 0.5
			heights[y * EDGE + x] = grain
			var strength: float = 0.07 if family == "stone" else 0.035 if family == "fur" else 0.018
			var value: float = 1.0 - strength * (0.5 + grain * 0.5)
			albedo.set_pixel(x, y, Color(value, value, value))
	for y: int in range(EDGE):
		for x: int in range(EDGE):
			var dx: float = heights[y * EDGE + (x + 1) % EDGE] - heights[y * EDGE + (x + EDGE - 1) % EDGE]
			var dy: float = heights[((y + 1) % EDGE) * EDGE + x] - heights[((y + EDGE - 1) % EDGE) * EDGE + x]
			var direction: Vector3 = Vector3(-dx, -dy, 2.0).normalized()
			normal.set_pixel(x, y, Color(direction.x * 0.5 + 0.5, direction.y * 0.5 + 0.5, direction.z * 0.5 + 0.5))
	albedo.generate_mipmaps()
	normal.generate_mipmaps(true)
	var result: Dictionary = {"albedo": ImageTexture.create_from_image(albedo), "normal": ImageTexture.create_from_image(normal)}
	_surface_textures[family] = result
	return result


func source_animation_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key: Variant in _clips:
		if str(key) != "RESET":
			names.append(str(key))
	return names


func get_normalized_height() -> float:
	return _height


func get_model_bounds() -> AABB:
	return _bounds


func _read_bounds(value: Variant, height: float) -> AABB:
	var fallback := AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, height, 2.0))
	if not value is Dictionary:
		return fallback
	var lower: Variant = value.get("min", value.get("position", []))
	var upper: Variant = value.get("max", [])
	var extent: Variant = value.get("size", [])
	if not lower is Array or lower.size() != 3:
		return fallback
	var origin := Vector3(float(lower[0]), float(lower[1]), float(lower[2]))
	var dimensions: Vector3
	if upper is Array and upper.size() == 3:
		dimensions = Vector3(float(upper[0]), float(upper[1]), float(upper[2])) - origin
	elif extent is Array and extent.size() == 3:
		dimensions = Vector3(float(extent[0]), float(extent[1]), float(extent[2]))
	else:
		return fallback
	if not origin.is_finite() or not dimensions.is_finite() or dimensions.x <= 0.0 or dimensions.y <= 0.0 or dimensions.z <= 0.0:
		return fallback
	return AABB(origin, dimensions)


func source_animation_duration(role: String) -> float:
	if _player == null or not _clips.has(role):
		return 0.0
	return _player.get_animation(_clips[role]).length


func set_reduced_motion(enabled: bool) -> void:
	var changed: bool = reduced_motion != enabled
	reduced_motion = enabled
	if changed and enabled:
		# A preference change must stop an in-flight spatial tween immediately.
		var interrupted: String = state
		var was_reacting: bool = _reaction != null and _reaction.is_valid()
		_cancel_reaction()
		_reset_motion()
		if interrupted == "defeated":
			visible = false
			if was_reacting:
				reaction_finished.emit("defeat")
		elif interrupted == "sleeping":
			_sleep_pose()
		elif interrupted in ["reacting", "attacking", "celebrating", "waking"]:
			state = "idle"
			_play_source("Idle")
			var kind: String = {"reacting": "hit", "attacking": "attack", "celebrating": "celebrate", "waking": "wake"}[interrupted]
			reaction_finished.emit(kind)
	if _player != null:
		_player.speed_scale = 0.0 if enabled or state == "sleeping" else 1.0
	_restore_joint_motion()
	_breathing.transform = Transform3D.IDENTITY
	_apply_material_feedback()


func set_cooperative_mode(enabled: bool) -> void:
	cooperative_mode = enabled
	repair_fraction = 0.0
	reset_pose()


func _reset_motion() -> void:
	_restore_joint_motion()
	_motion.transform = Transform3D.IDENTITY
	_breathing.transform = Transform3D.IDENTITY
	_gesture = 0.0
	_flash = 0.0
	_apply_material_feedback()


func reset_pose() -> void:
	_ensure_root()
	_cancel_reaction()
	_reset_motion()
	_clock = 0.0
	visible = true
	if _player != null:
		_player.stop()
	if cooperative_mode:
		set_sleeping(true)
	else:
		play_idle()


func play_idle() -> void:
	if cooperative_mode and state == "sleeping":
		return
	_cancel_reaction()
	_reset_motion()
	state = "idle"
	_play_source("Idle")


func _sleep_pose() -> void:
	_motion.rotation.z = -0.14
	_motion.scale = Vector3(1.02, 0.88, 1.02)


func set_sleeping(sleeping: bool) -> void:
	_cancel_reaction()
	_reset_motion()
	if not sleeping:
		state = "idle"
		play_idle()
		return
	state = "sleeping"
	_play_source("Idle")
	if _player != null:
		_player.seek(0.0, true)
		_player.advance(0.0)
		_player.speed_scale = 0.0
	_sleep_pose()


func play_attack() -> bool:
	# Anticipation, a clear forward gesture, then weight returning to the body.
	if cooperative_mode or not is_instance_valid(_model) or state in ["sleeping", "defeated"]:
		return false
	if _is_giant:
		return _play_giant_reaction("attack")
	_cancel_reaction()
	_reset_motion()
	state = "attacking"
	if not _play_source("Attack") and not _play_source("Celebrate"):
		_play_source("Idle")
	_reaction = create_tween()
	if reduced_motion:
		_reaction.tween_interval(0.18)
	else:
		var weight: float = _body_weight()
		var windup: float = 0.15 * weight
		var spring: float = 0.19 * weight
		_reaction.tween_property(_motion, "scale", Vector3(1.04, 0.9, 1.04), windup).set_trans(Tween.TRANS_SINE)
		_reaction.parallel().tween_property(_motion, "position:z", -0.10, windup)
		_reaction.parallel().tween_property(_motion, "rotation", Vector3(-0.10, -0.15, 0.035), windup)
		_reaction.parallel().tween_property(self, "_gesture", 0.5, windup)
		_reaction.tween_property(_motion, "scale", Vector3(0.98, 1.06, 0.98), spring).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_reaction.parallel().tween_property(_motion, "position", Vector3(0.0, 0.10 / weight, 0.24 / weight), spring)
		_reaction.parallel().tween_property(_motion, "rotation", Vector3(0.08, 0.10, -0.025), spring)
		_reaction.parallel().tween_property(self, "_gesture", 1.0, 0.22)
		_reaction.tween_property(_motion, "transform", Transform3D.IDENTITY, 0.30 * weight).set_trans(Tween.TRANS_SINE)
		_reaction.parallel().tween_property(self, "_gesture", 0.0, 0.30 * weight)
	_reaction.tween_callback(_finish_reaction.bind("attack", true))
	return true


func react_hit() -> bool:
	if cooperative_mode or not is_instance_valid(_model) or state in ["sleeping", "defeated"]:
		return false
	if _is_giant:
		return _play_giant_reaction("hit")
	_cancel_reaction()
	_reset_motion()
	state = "reacting"
	_hit_side *= -1.0
	if not _play_source("Hit"):
		_play_source("Idle")
	_flash = 0.25 if reduced_motion else 1.0
	_apply_material_feedback()
	_reaction = create_tween()
	if reduced_motion:
		_reaction.tween_property(self, "_flash", 0.0, 0.18)
	else:
		var weight: float = _body_weight()
		var compression: float = 0.21 / weight
		_reaction.tween_property(_motion, "scale", Vector3(1.0 + compression * 0.57, 1.0 - compression, 1.0 + compression * 0.38), 0.085)
		_reaction.parallel().tween_property(_motion, "position", Vector3(0.10 * _hit_side / weight, 0.06, -0.20 / weight), 0.085)
		_reaction.parallel().tween_property(_motion, "rotation", Vector3(0.14 / weight, 0.07 * _hit_side, -0.15 * _hit_side / weight), 0.085)
		_reaction.parallel().tween_property(self, "_gesture", 1.0, 0.085)
		_reaction.tween_property(_motion, "scale", Vector3(0.97, 1.05, 0.97), 0.18).set_trans(Tween.TRANS_SINE)
		_reaction.parallel().tween_property(_motion, "position", Vector3(-0.03 * _hit_side, 0.025, 0.0), 0.18)
		_reaction.parallel().tween_property(_motion, "rotation", Vector3(0.0, 0.0, 0.04 * _hit_side), 0.18)
		_reaction.parallel().tween_property(self, "_flash", 0.0, 0.18)
		_reaction.tween_property(_motion, "transform", Transform3D.IDENTITY, 0.22 * weight).set_trans(Tween.TRANS_SINE)
		_reaction.parallel().tween_property(self, "_gesture", 0.0, 0.22 * weight)
	_reaction.tween_callback(_finish_reaction.bind("hit", true))
	return true


func _body_weight() -> float:
	match creature_id:
		"lpm-yeti": return 1.38
		"lpm-dino", "lpm-goleing": return 1.20
		"lpm-cactoro", "lpm-mushroom": return 1.10
		"lpm-armabee", "lpm-alpaking": return 0.85
		_: return 1.0


func _play_giant_reaction(kind: String) -> bool:
	_cancel_reaction()
	_reset_motion()
	state = {"attack": "attacking", "hit": "reacting", "defeat": "defeated", "celebrate": "celebrating"}[kind]
	var role: String = {"attack": "Attack", "hit": "Hit", "defeat": "Defeat", "celebrate": "Challenge"}[kind]
	if not _clips.has(role):
		role = "Celebrate" if kind == "celebrate" and _clips.has("Celebrate") else "Idle"
	_play_source("Idle" if reduced_motion else role)
	reaction_started.emit(kind)
	var authored_duration: float = source_animation_duration(role) if role != "Idle" else 0.0
	_reaction = create_tween()
	if kind == "hit":
		_hit_side *= -1.0
		_flash = 0.25 if reduced_motion else 0.70
		_apply_material_feedback()
	if reduced_motion:
		_reaction.tween_property(self, "_flash", 0.0, 0.18)
	else:
		var motion_duration: float = 0.0
		if kind == "hit":
			# The source skeleton supplies the impact. The massive body gives way
			# only a little, so its stone/armour never reads as a rubber toy.
			_reaction.tween_property(_motion, "position", Vector3(0.025 * _hit_side, 0.0, -0.065), 0.08)
			_reaction.parallel().tween_property(_motion, "rotation:z", -0.018 * _hit_side, 0.08)
			_reaction.tween_property(_motion, "transform", Transform3D.IDENTITY, 0.32).set_trans(Tween.TRANS_SINE)
			_reaction.parallel().tween_property(self, "_flash", 0.0, 0.24)
			motion_duration = 0.40
		elif kind == "attack":
			_reaction.tween_property(_motion, "position:z", -0.025, 0.16).set_trans(Tween.TRANS_SINE)
			_reaction.tween_property(_motion, "position:z", 0.065, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_reaction.tween_property(_motion, "transform", Transform3D.IDENTITY, 0.32).set_trans(Tween.TRANS_SINE)
			motion_duration = 0.70
		elif kind == "defeat":
			# Let a real source defeat finish before the model is removed.
			# Without that optional clip, use a brief heavy settling retreat.
			if role == "Idle":
				_reaction.tween_property(_motion, "position:y", -0.10, 0.38).set_trans(Tween.TRANS_SINE)
				_reaction.parallel().tween_property(_motion, "rotation:x", -0.08, 0.38)
				motion_duration = 0.38
		else:
			_reaction.tween_interval(0.35)
			motion_duration = 0.35
		# Do not interrupt the imported source take with the shorter container tween.
		_reaction.tween_interval(maxf(0.0, authored_duration - motion_duration))
	if kind == "defeat":
		_reaction.tween_callback(func() -> void:
			_restore_joint_motion()
			visible = false
			_reaction = null
			reaction_finished.emit("defeat")
		)
	else:
		_reaction.tween_callback(_finish_reaction.bind(kind, true))
	return true


func defeat() -> bool:
	if cooperative_mode or not is_instance_valid(_model) or state == "defeated":
		return false
	if _is_giant:
		return _play_giant_reaction("defeat")
	_cancel_reaction()
	_reset_motion()
	state = "defeated"
	# A little wave and buoyant retreat, with no source death animation.
	if not _play_source("Celebrate"):
		_play_source("Idle")
	_reaction = create_tween()
	if reduced_motion:
		_reaction.tween_interval(0.2)
	else:
		_reaction.tween_property(self, "_gesture", 1.0, 0.2)
		_reaction.parallel().tween_property(_motion, "position:y", 0.18, 0.2).set_trans(Tween.TRANS_SINE)
		_reaction.tween_property(_motion, "position", Vector3(0.42, 0.24, -0.12), 0.32).set_trans(Tween.TRANS_SINE)
		_reaction.parallel().tween_property(_motion, "rotation", Vector3(0.0, -0.22, -0.13), 0.32)
		_reaction.tween_property(_motion, "scale", Vector3.ONE * 0.015, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_reaction.tween_callback(func() -> void:
		_restore_joint_motion()
		visible = false
		_reaction = null
		reaction_finished.emit("defeat")
	)
	return true


func celebrate() -> void:
	if not is_instance_valid(_model):
		return
	if _is_giant:
		visible = true
		_play_giant_reaction("celebrate")
		return
	_cancel_reaction()
	_reset_motion()
	state = "celebrating"
	visible = true
	if not _play_source("Celebrate"):
		_play_source("Idle")
	_reaction = create_tween()
	if reduced_motion:
		_reaction.tween_interval(0.35)
	else:
		_reaction.tween_property(self, "_gesture", 1.0, 0.12)
		for bounce: int in range(2):
			_reaction.tween_property(_motion, "position:y", 0.20, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_reaction.parallel().tween_property(_motion, "rotation:z", 0.06 if bounce == 0 else -0.06, 0.20)
			_reaction.tween_property(_motion, "position:y", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_reaction.tween_callback(_finish_reaction.bind("celebrate", true))


func repair_progress(completed: int, total: int = 5) -> void:
	if not cooperative_mode:
		return
	repair_fraction = clampf(float(completed) / float(maxi(total, 1)), 0.0, 1.0)
	_apply_material_feedback()
	if state != "sleeping" or reduced_motion:
		return
	_cancel_reaction()
	_reaction = create_tween()
	_reaction.tween_property(_motion, "rotation:z", -0.09, 0.16).set_trans(Tween.TRANS_SINE)
	_reaction.tween_property(_motion, "rotation:z", -0.14, 0.28).set_trans(Tween.TRANS_SINE)
	_reaction.tween_callback(func() -> void:
		_reaction = null
		reaction_finished.emit("repair")
	)


func wake_up() -> void:
	if not cooperative_mode or not is_instance_valid(_model):
		return
	_cancel_reaction()
	_restore_joint_motion()
	repair_fraction = 1.0
	_apply_material_feedback()
	state = "waking"
	if not _play_source("Celebrate"):
		_play_source("Idle")
	_reaction = create_tween()
	var duration: float = 0.2 if reduced_motion else 0.75
	_reaction.tween_property(_motion, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reaction.parallel().tween_property(_motion, "rotation", Vector3.ZERO, duration)
	if not reduced_motion:
		_reaction.parallel().tween_property(self, "_gesture", 1.0, duration)
		_reaction.tween_property(_motion, "position:y", 0.12, 0.25).set_trans(Tween.TRANS_SINE)
		_reaction.tween_property(_motion, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	_reaction.tween_callback(_finish_reaction.bind("wake", true))


func _apply_repair_glow() -> void:
	_apply_material_feedback()


func _apply_material_feedback() -> void:
	for index: int in range(_materials.size()):
		var material: StandardMaterial3D = _materials[index]
		var original: Dictionary = _material_base[index]
		var glow: float = repair_fraction * 0.32 if cooperative_mode else 0.0
		material.albedo_color = original.albedo.lerp(Color(1.0, 0.9, 0.62, original.albedo.a), _flash * 0.32)
		material.emission_enabled = bool(original.enabled) or glow > 0.0 or _flash > 0.0
		material.emission = Color(1.0, 0.72, 0.22) if _flash > 0.0 else Color(0.18, 0.58, 0.38) if glow > 0.0 else original.emission
		material.emission_energy_multiplier = _flash * 0.45 if _flash > 0.0 else glow if glow > 0.0 else float(original.energy)


func _play_source(role: String) -> bool:
	if _player == null or not _clips.has(role):
		return false
	_restore_joint_motion()
	_player.speed_scale = 0.0 if reduced_motion or state == "sleeping" else 1.0
	_player.play(_clips[role], 0.0)
	# play() schedules evaluation. Sampling now avoids a rest/T pose on entry,
	# including reduced-motion mode, where no later time advance is expected.
	_player.advance(0.0)
	return true


func _finish_reaction(kind: String, resume_idle: bool) -> void:
	_reaction = null
	if resume_idle:
		state = "idle"
		play_idle()
	reaction_finished.emit(kind)


func _cancel_reaction() -> void:
	if _reaction != null and _reaction.is_valid():
		_reaction.kill()
	_reaction = null


func _restore_joint_motion() -> void:
	if is_instance_valid(_skeleton):
		for bone: Variant in _joint_base:
			_skeleton.set_bone_pose_rotation(int(bone), _joint_base[bone])
	_joint_base.clear()


func _pose_joint(name: String, actor_axis: Vector3, angle: float) -> void:
	var bone: int = int(_bones.get(name.replace(".", "_").to_lower(), -1))
	if bone < 0 or absf(angle) < 0.00001:
		return
	if not _joint_base.has(bone):
		_joint_base[bone] = _skeleton.get_bone_pose_rotation(bone)
	# Convert a character-space gesture into the imported bone's local axes.
	# This keeps wings and arms bending visibly, despite differing rig rests.
	var axis: Vector3 = _skeleton.global_transform.basis.inverse() * (global_transform.basis * actor_axis)
	axis = _skeleton.get_bone_global_pose(bone).basis.inverse() * axis
	var rotation: Quaternion = _skeleton.get_bone_pose_rotation(bone)
	_skeleton.set_bone_pose_rotation(bone, (rotation * Quaternion(axis.normalized(), angle)).normalized())


func _animate_personality() -> void:
	var phase: float = _clock * float(_profile.get("rate", 2.0))
	var beat: float = sin(phase)
	var sway: float = sin(phase * 0.61)
	var hovering: bool = bool(_profile.get("hover", false))
	var idle_weight: float = 1.0 if state == "idle" else 0.28
	var bob: float = float(_profile.get("bob", 0.04))
	_breathing.position = Vector3(sway * float(_profile.get("sway", 0.04)), bob * (0.65 + beat * 0.65) if hovering else bob * (0.5 + beat * 0.5), 0.0) * idle_weight
	_breathing.rotation = Vector3(0.0, sway * float(_profile.get("turn", 0.12)), beat * 0.035) * idle_weight
	var squash: float = beat * float(_profile.get("squash", 0.02)) * idle_weight
	_breathing.scale = Vector3(1.0 - squash * 0.45, 1.0 + squash, 1.0 - squash * 0.45)
	if _is_giant:
		# Their authored takes own every joint, including unfamiliar rig names.
		return
	var limb: float = float(_profile.get("limb", 0.2))
	_pose_joint("Head", Vector3.UP, sin(phase * 0.47) * 0.12 * idle_weight)
	_pose_joint("Head", Vector3.RIGHT, sin(phase + 0.7) * 0.055 * idle_weight)
	_pose_joint("Torso", Vector3.FORWARD, beat * 0.035 * idle_weight)
	_pose_joint("Body2", Vector3.RIGHT, beat * 0.06 * idle_weight)
	if state == "reacting":
		_pose_joint("Head", Vector3.RIGHT, -0.14 * _gesture)
	for side: String in ["L", "R"]:
		var sign_side: float = 1.0 if side == "L" else -1.0
		var swing: float = sin(phase + (0.0 if side == "L" else 1.2))
		_pose_joint("UpperArm." + side, Vector3.FORWARD, sign_side * (0.08 + swing * limb) * idle_weight)
		_pose_joint("LowerArm." + side, Vector3.RIGHT, (0.1 + swing * 0.08) * idle_weight)
		_pose_joint("Wing1." + side, Vector3.FORWARD, sign_side * sin(phase * 1.8) * limb * idle_weight)
		_pose_joint("Wing2." + side, Vector3.UP, sign_side * cos(phase * 1.8 + 0.6) * limb * 0.45 * idle_weight)
		_pose_joint("Ear1." + side, Vector3.FORWARD, sign_side * sin(phase * 1.2 + sign_side * 0.4) * 0.13 * idle_weight)
		if _gesture <= 0.0:
			continue
		if state == "reacting":
			_pose_joint("UpperArm." + side, Vector3.FORWARD, sign_side * 0.32 * _gesture)
		else:
			_pose_joint("UpperArm." + side, Vector3.FORWARD, sign_side * 0.5 * _gesture)
			_pose_joint("LowerArm." + side, Vector3.RIGHT, -0.2 * _gesture)
			_pose_joint("Wing1." + side, Vector3.FORWARD, sign_side * 0.35 * _gesture)
			if side == "L":
				_pose_joint("LowerArm." + side, Vector3.FORWARD, sin(_clock * 11.0) * 0.2 * _gesture)
	_animate_signature(phase, idle_weight)
	if _gesture > 0.0:
		_animate_reaction_pose()


func _animate_signature(phase: float, weight: float) -> void:
	# Short, readable actions separated by quiet breathing. They are sampled from
	# absolute time, so pause/reset never accumulates transforms on the source rig.
	var cadence: float = 5.8 + float(CREATURE_IDS.find(creature_id) % 4) * 0.55
	var intent: float = pow(maxf(0.0, sin(_clock * TAU / cadence)), 3.0) * weight
	var follow: float = sin(phase * 0.68) * weight
	match creature_id:
		"lpm-alien":
			# Curious, asymmetrical listening pose followed by an open hand.
			_pose_joint("Head", Vector3.FORWARD, -0.20 * intent)
			_pose_joint("Head", Vector3.UP, 0.22 * intent)
			_pose_joint("UpperArm.R", Vector3.RIGHT, -0.28 * intent)
			_pose_joint("LowerArm.R", Vector3.RIGHT, -0.48 * intent)
			_pose_joint("Shoulder.L", Vector3.FORWARD, 0.08 * intent)
		"lpm-alpaking":
			# A slow bank and a proud raised head between wing strokes.
			_breathing.rotation.z += 0.10 * follow
			_pose_joint("Neck", Vector3.RIGHT, -0.12 * intent)
			_pose_joint("Wing3.L", Vector3.UP, 0.20 * intent)
			_pose_joint("Wing3.R", Vector3.UP, -0.12 * intent)
		"lpm-armabee":
			# Small precise darts; the abdomen follows the change of direction.
			_breathing.position.x += sin(phase * 1.4) * 0.045 * intent
			_breathing.rotation.z += sin(phase * 1.4) * 0.09 * intent
			_pose_joint("Body1", Vector3.RIGHT, -0.13 * intent)
			_pose_joint("Head", Vector3.UP, -0.18 * follow)
			_pose_joint("Wing3.L", Vector3.FORWARD, sin(phase * 3.5) * 0.13 * weight)
			_pose_joint("Wing3.R", Vector3.FORWARD, -sin(phase * 3.5) * 0.13 * weight)
		"lpm-bird":
			# A bird-like double head dip, balanced by the shoulders.
			_pose_joint("Head", Vector3.RIGHT, sin(phase * 2.0) * 0.17 * intent)
			_pose_joint("Neck", Vector3.UP, 0.22 * intent)
			_pose_joint("UpperArm.L", Vector3.FORWARD, 0.23 * intent)
			_pose_joint("UpperArm.R", Vector3.FORWARD, -0.16 * intent)
		"lpm-bunny":
			# Ears listen independently, then the body rises out of a small crouch.
			_pose_joint("Ear1.L", Vector3.RIGHT, -0.26 * intent)
			_pose_joint("Ear2.L", Vector3.FORWARD, 0.18 * intent)
			_pose_joint("Ear1.R", Vector3.FORWARD, -0.31 * intent)
			_pose_joint("Ear2.R", Vector3.RIGHT, -0.18 * intent)
			_pose_joint("Head", Vector3.FORWARD, 0.11 * intent)
			_breathing.position.y += 0.065 * intent
		"lpm-cactoro":
			# A grounded, confident shoulder roll with a deliberate glance.
			_pose_joint("Torso", Vector3.UP, -0.15 * intent)
			_pose_joint("Head", Vector3.UP, 0.24 * intent)
			_pose_joint("Shoulder.L", Vector3.FORWARD, 0.19 * intent)
			_pose_joint("Shoulder.R", Vector3.FORWARD, -0.10 * intent)
		"lpm-dino":
			# Sniff forward and shift the heavy upper body over one foot.
			_pose_joint("Neck", Vector3.RIGHT, 0.15 * intent)
			_pose_joint("Head", Vector3.UP, -0.18 * intent)
			_pose_joint("Torso", Vector3.RIGHT, 0.11 * intent)
			_pose_joint("LowerArm.L", Vector3.RIGHT, -0.22 * intent)
			_pose_joint("LowerArm.R", Vector3.RIGHT, -0.22 * intent)
			_breathing.position.z += 0.065 * intent
		"lpm-frog":
			# Low spring-loaded posture, hands spread as the chest expands.
			_pose_joint("UpperLeg.L", Vector3.RIGHT, -0.10 * intent)
			_pose_joint("UpperLeg.R", Vector3.RIGHT, -0.10 * intent)
			_pose_joint("Torso", Vector3.RIGHT, -0.12 * intent)
			_pose_joint("UpperArm.L", Vector3.FORWARD, 0.19 * intent)
			_pose_joint("UpperArm.R", Vector3.FORWARD, -0.19 * intent)
			_breathing.scale *= Vector3(1.0 + 0.04 * intent, 1.0 - 0.045 * intent, 1.0 + 0.035 * intent)
		"lpm-glub":
			# Broad, lazy fin sweeps carry a gradual turn through the water.
			_breathing.rotation.y += 0.22 * intent
			_breathing.rotation.z += 0.06 * follow
			_pose_joint("Body1", Vector3.UP, -0.16 * intent)
			_pose_joint("Wing3.L", Vector3.RIGHT, 0.18 * follow)
			_pose_joint("Wing3.R", Vector3.RIGHT, -0.18 * follow)
		"lpm-goleing":
			# Stone weight, wide wing tips, an alert gaze instead of a flat hover.
			_breathing.rotation.x += -0.07 * intent
			_pose_joint("Head", Vector3.UP, 0.27 * intent)
			_pose_joint("Neck", Vector3.RIGHT, -0.10 * intent)
			_pose_joint("Wing2.L", Vector3.FORWARD, 0.19 * intent)
			_pose_joint("Wing2.R", Vector3.FORWARD, -0.19 * intent)
			_pose_joint("Wing4.L", Vector3.UP, -0.18 * follow)
			_pose_joint("Wing4.R", Vector3.UP, 0.18 * follow)
		"lpm-hywirl":
			# The trailing body bends as a chain, never as one rigid capsule.
			_pose_joint("Body2", Vector3.FORWARD, sin(phase) * 0.12 * weight)
			_pose_joint("Body3", Vector3.FORWARD, sin(phase - 0.65) * 0.17 * weight)
			_pose_joint("Body4", Vector3.FORWARD, sin(phase - 1.30) * 0.21 * weight)
			_pose_joint("Head", Vector3.UP, -0.20 * intent)
			_pose_joint("UpperArm.L", Vector3.RIGHT, -0.20 * intent)
		"lpm-mushroom":
			# A deep cap nod and a small contrasting hand flourish.
			_pose_joint("Head", Vector3.RIGHT, 0.20 * intent)
			_pose_joint("Torso", Vector3.FORWARD, -0.09 * intent)
			_pose_joint("UpperArm.R", Vector3.FORWARD, -0.30 * intent)
			_pose_joint("LowerArm.R", Vector3.RIGHT, -0.25 * intent)
		"lpm-squidle":
			# Rolling mantle and alternating tentacle/hand curls.
			_breathing.rotation.z += 0.095 * follow
			_pose_joint("Torso", Vector3.UP, 0.17 * intent)
			_pose_joint("LowerArm.L", Vector3.RIGHT, -0.30 * intent)
			_pose_joint("LowerArm.R", Vector3.RIGHT, -0.22 * (1.0 - intent) * weight)
			_pose_joint("Wing3.L", Vector3.RIGHT, sin(phase + 0.7) * 0.22 * weight)
			_pose_joint("Wing3.R", Vector3.RIGHT, sin(phase - 0.7) * 0.22 * weight)
		"lpm-yeti":
			# Slow chest-led stretch; the shoulders settle after the head.
			_pose_joint("Torso", Vector3.RIGHT, -0.10 * intent)
			_pose_joint("Head", Vector3.RIGHT, 0.11 * intent)
			_pose_joint("Shoulder.L", Vector3.FORWARD, 0.16 * intent)
			_pose_joint("Shoulder.R", Vector3.FORWARD, -0.16 * intent)
			_pose_joint("LowerArm.L", Vector3.RIGHT, -0.25 * intent)
			_pose_joint("LowerArm.R", Vector3.RIGHT, -0.25 * intent)
			_breathing.position.x += 0.025 * follow


func _animate_reaction_pose() -> void:
	var recoil: bool = state == "reacting"
	var sign_side: float = _hit_side if recoil else 1.0
	_pose_joint("Torso", Vector3.UP, (0.16 if recoil else -0.20) * sign_side * _gesture)
	_pose_joint("Neck", Vector3.RIGHT, (-0.10 if recoil else 0.10) * _gesture)
	for side: String in ["L", "R"]:
		var mirror: float = 1.0 if side == "L" else -1.0
		_pose_joint("Wing3." + side, Vector3.FORWARD, mirror * 0.28 * _gesture)
		_pose_joint("Ear2." + side, Vector3.RIGHT, 0.30 * _gesture)
		for finger: String in ["Index1", "Middle1", "Pinky1"]:
			_pose_joint(finger + "." + side, Vector3.RIGHT, -0.16 * _gesture)


func _process(delta: float) -> void:
	if not is_instance_valid(_model) or not visible or not can_process():
		return
	_restore_joint_motion()
	var step: float = minf(maxf(delta, 0.0), 0.1)
	if not reduced_motion:
		_clock += step
		if _player != null and state != "sleeping":
			# Imported giant takes and their completion tween share elapsed time,
			# even on a slow frame. Bounded decorative motion still uses the cap.
			_player.advance(maxf(delta, 0.0) if _is_giant else step)
	if reduced_motion:
		_breathing.transform = Transform3D.IDENTITY
	elif state == "sleeping":
		_breathing.position.y = sin(_clock * 1.5) * 0.022
		_breathing.rotation.z = sin(_clock * 1.5) * 0.012
	else:
		_animate_personality()
	_apply_material_feedback()
