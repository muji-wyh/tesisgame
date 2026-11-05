extends Node3D
## Additive Pirate player. Gameplay may disable auto_advance and supply its own clock.

signal animation_changed(clip: String)
signal action_finished(clip: String)

const MODEL_PATH: String = "res://assets/pirate/pirate-game.glb"
const Palette = preload("res://scripts/pirate_asset_color.gd")
const TAUNTS = ["Taunt_HatTip", "Taunt_BellyLaugh", "Taunt_SideEye", "Taunt_NopeWag",
	"Taunt_Peekaboo", "Taunt_MockBow", "Taunt_Swagger", "Taunt_TongueTease",
	"Taunt_VictoryLap", "Taunt_FakeSleep"]
const MORPHS = ["Bite_Open", "Eye_Squint", "Smile_Smirk", "Tongue_Out"]
const CLIPS = ["Idle", "Attack_L", "Attack_M", "Attack_P", "Hit_L", "Hit_M", "Hit_P",
	"Ultimate_TidalRush", "Ultimate_CrescentSpin", "Ultimate_CaptainsDrop",
	"Special_GiantRam", "Special_BigBite", "Taunt_HatTip", "Taunt_BellyLaugh",
	"Taunt_SideEye", "Taunt_NopeWag", "Taunt_Peekaboo", "Taunt_MockBow",
	"Taunt_Swagger", "Taunt_TongueTease", "Taunt_VictoryLap", "Taunt_FakeSleep"]

@export var model_path: String = MODEL_PATH
@export var display_height: float = 2.0
@export var auto_advance: bool = true
@export var reduced_motion: bool = false

var last_error: String = ""
var _normalizer := Node3D.new()
var _model: Node3D
var _player: AnimationPlayer
var _meshes: Array[MeshInstance3D] = []
var _clip_lookup: Dictionary = {}
var _clip: String = "Idle"
var _elapsed: float = 0.0
var _loaded: bool = false
var _active: bool = true
var _pose_paused: bool = false
var _scale_factor: float = 1.0
var _rest_bounds := AABB()


func _init() -> void:
	_normalizer.name = "DisplayNormalization"
	add_child(_normalizer)
	set_process(false)


func _ready() -> void:
	load_character()


func load_character() -> bool:
	if _loaded:
		return true
	if not ResourceLoader.exists(model_path, "PackedScene"):
		return _fail("Import the optimized Pirate model before opening its preview.")
	var source: PackedScene = load(model_path) as PackedScene
	if source == null:
		return _fail("The optimized Pirate model could not be loaded as a scene.")
	_model = source.instantiate() as Node3D
	if _model == null:
		return _fail("The Pirate asset requires a Node3D scene root.")
	_normalizer.add_child(_model)
	_scan(_model)
	if _meshes.is_empty() or _player == null:
		return _fail("The Pirate asset requires its authored meshes and animation player.")
	_configure_vertex_colors()
	for clip: String in CLIPS:
		for imported: String in _player.get_animation_list():
			if imported == clip or imported.ends_with("/" + clip):
				_clip_lookup[clip] = imported
				break
		if not _clip_lookup.has(clip):
			return _fail("The Pirate asset is missing the required %s clip." % clip)
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# Evaluate exported initial TRS before measuring the hat and elastic body.
	_apply_pose("Idle", 0.0)
	var source_bounds: AABB = _measure_neutral_bounds()
	if source_bounds.size.y <= 0.0 or display_height <= 0.0:
		return _fail("The Pirate asset has invalid neutral bounds or display height.")
	_scale_factor = display_height / source_bounds.size.y
	_normalizer.scale = Vector3.ONE * _scale_factor
	_normalizer.position = -Vector3(source_bounds.get_center().x, source_bounds.position.y,
		source_bounds.get_center().z) * _scale_factor
	_rest_bounds = AABB(Vector3(-source_bounds.size.x * 0.5, 0.0,
		-source_bounds.size.z * 0.5) * _scale_factor, source_bounds.size * _scale_factor)
	_loaded = true
	last_error = ""
	resume_idle()
	return true


func _scan(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node as MeshInstance3D)
	if node is AnimationPlayer:
		_player = node as AnimationPlayer
	for child: Node in node.get_children():
		_scan(child)


func _configure_vertex_colors() -> void:
	# Godot's importer can leave uniform-color material groups disabled even when
	# their source COLOR_0 arrays exist. Preserve the packed palette per instance.
	for mesh: MeshInstance3D in _meshes:
		if mesh.mesh is ArrayMesh:
			mesh.mesh = Palette.to_srgb_mesh(mesh.mesh as ArrayMesh)
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var source: BaseMaterial3D = mesh.get_active_material(surface) as BaseMaterial3D
			if colors.is_empty() or source == null:
				continue
			var material: BaseMaterial3D = source.duplicate() as BaseMaterial3D
			material.vertex_color_use_as_albedo = true
			material.vertex_color_is_srgb = true
			mesh.set_surface_override_material(surface, material)


func _measure_neutral_bounds() -> AABB:
	var bounds := AABB()
	var first: bool = true
	for mesh: MeshInstance3D in _meshes:
		var local: Transform3D = _normalizer.global_transform.affine_inverse() * mesh.global_transform
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var point: Vector3 = local * vertex
				bounds = AABB(point, Vector3.ZERO) if first else bounds.expand(point)
				first = false
	return bounds


func _apply_pose(clip: String, time: float) -> void:
	var selected: String = str(_clip_lookup[clip])
	_player.play(selected, 0.0)
	_player.seek(time, true)
	_player.advance(0.0)


func play_animation(clip: String) -> bool:
	if not _loaded and not load_character():
		return false
	if not _clip_lookup.has(clip):
		return _fail("Unknown Pirate animation: %s." % clip)
	last_error = ""
	# Every clip owns all pivot and facial tracks. Reset first so interruption cannot
	# leave a former expression, bite weight, or giant scale behind.
	_apply_pose("Idle", 0.0)
	_clip = "Idle" if reduced_motion else clip
	_elapsed = 0.0
	_pose_paused = false
	_apply_pose(_clip, 0.0)
	_refresh_processing()
	animation_changed.emit(_clip)
	if reduced_motion and clip != "Idle":
		action_finished.emit(clip)
	return true


func resume_idle() -> bool:
	return play_animation("Idle")


func pose(clip: String, time: float) -> bool:
	if not _loaded and not load_character():
		return false
	if not _clip_lookup.has(clip) or not is_finite(time):
		return _fail("The Pirate pose requires a known clip and finite time.")
	last_error = ""
	_apply_pose("Idle", 0.0)
	_clip = clip
	_elapsed = clampf(time, 0.0, clip_duration(clip))
	_pose_paused = true
	_apply_pose(clip, _elapsed)
	_refresh_processing()
	animation_changed.emit(clip)
	return true


func clip_duration(clip: String) -> float:
	if _player == null or not _clip_lookup.has(clip):
		return 0.0
	return _player.get_animation(str(_clip_lookup[clip])).length


func animation_names() -> PackedStringArray:
	return PackedStringArray(CLIPS) if _loaded else PackedStringArray()


func advance(delta: float) -> bool:
	if not _loaded or not _active or reduced_motion or _pose_paused \
		or not is_finite(delta) or delta <= 0.0:
		return false
	_elapsed += delta
	var duration: float = maxf(0.001, clip_duration(_clip))
	if _clip == "Idle":
		_elapsed = fposmod(_elapsed, duration)
		_apply_pose(_clip, _elapsed)
	elif _elapsed >= duration:
		var completed: String = _clip
		# Restore before emitting: a listener may start a new action immediately.
		resume_idle()
		action_finished.emit(completed)
	else:
		_apply_pose(_clip, _elapsed)
	return true


func _process(delta: float) -> void:
	advance(delta)


func set_active(value: bool) -> void:
	_active = value
	_refresh_processing()


func set_reduced_motion(value: bool) -> void:
	if value == reduced_motion:
		return
	reduced_motion = value
	if _loaded:
		resume_idle()
	_refresh_processing()


func _refresh_processing() -> void:
	set_process(_loaded and _active and auto_advance and not reduced_motion and not _pose_paused)


func morph_weights() -> Dictionary:
	var weights: Dictionary = {}
	for mesh: MeshInstance3D in _meshes:
		for index: int in range(mesh.mesh.get_blend_shape_count()):
			weights[str(_model.get_path_to(mesh)) + ":" + mesh.mesh.get_blend_shape_name(index)] \
				= mesh.get_blend_shape_value(index)
	return weights


func model_transforms() -> Dictionary:
	var transforms: Dictionary = {}
	if _model != null:
		_collect_transforms(_model, transforms)
	return transforms


func _collect_transforms(node: Node, result: Dictionary) -> void:
	if node is Node3D:
		result[str(_model.get_path_to(node))] = (node as Node3D).transform
	for child: Node in node.get_children():
		_collect_transforms(child, result)


func snapshot() -> Dictionary:
	return {"loaded": _loaded, "clip": _clip, "time": _elapsed,
		"duration": clip_duration(_clip), "animations": animation_names(),
		"reduced_motion": reduced_motion, "active": _active, "pose_paused": _pose_paused,
		"scale_factor": _scale_factor, "rest_bounds": _rest_bounds,
		"front_axis": "+Z", "last_error": last_error}


func _fail(message: String) -> bool:
	last_error = message
	push_error(message)
	return false
