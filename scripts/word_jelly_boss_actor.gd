extends SubViewport
## The acquired character is posed from authored skeletal clips; the view owns its clock.

const MODEL = "res://assets/jelly-boss/private/bramble.glb"
const CAMERA_HEIGHT: float = 3.1
const FOOT_Y: float = (1.05 + CAMERA_HEIGHT * 0.5) / CAMERA_HEIGHT
var last_error: String = ""
var _world := Node3D.new()
var _rig := Node3D.new()
var _camera := Camera3D.new()
var _model: Node3D
var _player: AnimationPlayer
var _clip: String = ""
var _box := AABB()
var _loaded: bool = false


func _init() -> void:
	name = "BrambleModelViewport"
	size = Vector2i(384, 576)
	transparent_bg = true
	own_world_3d = true
	gui_disable_input = true
	handle_input_locally = false
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_world)
	_world.add_child(_rig)
	_world.add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.01
	_camera.far = 100.0
	_camera.current = true
	var studio := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e0edff")
	environment.ambient_light_energy = 0.65
	studio.environment = environment
	_world.add_child(studio)
	for spec: Array in [[Vector3(-35, -30, 0), Color("#fff0d1"), 1.0],
		[Vector3(-15, 125, 0), Color("#d9e8ff"), 0.6]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		_world.add_child(light)
	set_process(false)


func load_character() -> bool:
	if _loaded:
		return true
	if not ResourceLoader.exists(MODEL, "PackedScene"):
		return _fail("Restore and import the approved Bramble character before starting a Boss stage.")
	var source: PackedScene = load(MODEL)
	if source == null:
		return _fail("The approved Boss character could not be loaded.")
	_model = source.instantiate()
	_rig.add_child(_model)
	var meshes: Array[MeshInstance3D] = []
	_scan(_model, meshes)
	if meshes.is_empty() or _player == null:
		return _fail("The Boss model needs its original skinned mesh and authored animation player.")
	var first: bool = true
	for mesh: MeshInstance3D in meshes:
		var transformed: AABB = _rig.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		_box = transformed if first else _box.merge(transformed)
		first = false
	if _box.size.y <= 0.0:
		return _fail("The Boss character has invalid source bounds.")
	var scale_factor: float = 2.0 / _box.size.y
	_model.scale *= scale_factor
	_model.position = -Vector3(_box.get_center().x, _box.position.y, _box.get_center().z) * scale_factor
	_rig.rotation.y = -0.15
	_camera.position = Vector3(0.0, 1.05, 6.0)
	_camera.look_at(Vector3(0.0, 1.05, 0.0))
	_camera.size = CAMERA_HEIGHT
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_loaded = true
	last_error = ""
	pose("Idle", 0.0)
	return true


func _scan(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	if node is AnimationPlayer:
		_player = node
	for child: Node in node.get_children():
		_scan(child, meshes)


func pose(clip: String, elapsed: float, reduced_motion: bool = false) -> void:
	if not _loaded:
		return
	var selected: String = ""
	for name: String in _player.get_animation_list():
		if name == clip or name.ends_with("/" + clip):
			selected = name
			break
	if selected.is_empty():
		_fail("The Boss character is missing its required %s animation." % clip)
		return
	if selected != _clip:
		_player.play(selected)
		_clip = selected
	_rig.rotation.y = 0.70 if clip == "Kick" else -0.15
	var animation: Animation = _player.get_animation(selected)
	var at: float = 0.0 if reduced_motion else fposmod(maxf(0.0, elapsed), maxf(0.01, animation.length))
	_player.seek(at, true)
	_player.advance(0.0)
	render_target_update_mode = SubViewport.UPDATE_ONCE


func animation_names() -> PackedStringArray:
	return _player.get_animation_list() if _player != null else PackedStringArray()


func _fail(message: String) -> bool:
	last_error = message
	push_error(message)
	return false
