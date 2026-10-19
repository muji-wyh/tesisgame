extends SceneTree
## Original acquired Tiny Treats source inspection only. Root owns native execution.
const BASE := "res://build/professional-english/retail-term-art-review/cash-register-r04"
const OUTPUT := BASE + "/native-inspection-r01"
const MODEL := BASE + "/source/original/Assets/gltf/cash_register.gltf"
const EXPECTED_MODEL := "43aed74637cf10432d996a18f03ed580f6cbc346b5f91d9592473370ed8ea1cc"
var camera: Camera3D
var model: Node3D
var source_bounds: AABB
var centered_bounds: AABB
var captures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = node.global_transform.affine_inverse() * child.global_transform * child.get_aabb()
		result = part if first else result.merge(part)
		first = false
	assert(not first, "Original source must contain mesh instances")
	return result

func _capture(label: String, direction: Vector3) -> void:
	camera.position = direction.normalized() * source_bounds.size.length() * 5.0
	camera.look_at(Vector3.ZERO)
	var camera_bounds: AABB = camera.global_transform.affine_inverse() * centered_bounds
	camera.size = maxf(camera_bounds.size.x, camera_bounds.size.y) * 1.16
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var filename := OUTPUT + "/" + label + ".png"
	assert(not FileAccess.file_exists(filename), "Preserve existing capture")
	var capture: Image = root.get_texture().get_image()
	assert(capture.get_size() == Vector2i(768, 768))
	assert(capture.save_png(filename) == OK)
	captures.append({"file": label + ".png", "sha256": FileAccess.get_sha256(filename), "camera": [camera.position.x, camera.position.y, camera.position.z], "look_at": [0, 0, 0], "orthographic_size": camera.size, "pixels": [768, 768]})

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	assert(FileAccess.get_sha256(MODEL) == EXPECTED_MODEL)
	assert(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUTPUT)), "Preserve prior native attempt")
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT)) == OK)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(768, 768)
	root.msaa_3d = Viewport.MSAA_4X
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("f6f3e9")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.45
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.light_color = Color("fffaf0")
	light.light_energy = 0.65
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.shadow_enabled = true
	root.add_child(light)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(ProjectSettings.globalize_path(MODEL), state) == OK)
	model = document.generate_scene(state)
	assert(model != null)
	root.add_child(model)
	source_bounds = _bounds(model)
	model.position = -source_bounds.get_center()
	centered_bounds = AABB(source_bounds.position + model.position, source_bounds.size)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(camera)
	camera.make_current()
	await _capture("positive-z-right-high", Vector3(3, 2.4, 4))
	await _capture("positive-z-left-high", Vector3(-3, 2.4, 4))
	await _capture("negative-z-right-high", Vector3(3, 2.4, -4))
	await _capture("negative-z-left-high", Vector3(-3, 2.4, -4))
	await _capture("positive-z-right-low", Vector3(2.7, 1.6, 4))
	await _capture("positive-z-front", Vector3(0, 1.3, 5))
	var meshes: Array = []
	for instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append({"name": instance.name, "surfaces": instance.mesh.get_surface_count(), "aabb": str(instance.get_aabb())})
	var report := {"scope": "Original acquired source in six views; no term candidate, minimum-card validation, acceptance, or production integration.", "model_sha256": FileAccess.get_sha256(MODEL), "source_bounds": [source_bounds.position.x, source_bounds.position.y, source_bounds.position.z, source_bounds.size.x, source_bounds.size.y, source_bounds.size.z], "root_centering_translation": [model.position.x, model.position.y, model.position.z], "geometry_materials_textures_child_transforms": "Original and unchanged", "meshes": meshes, "animation_players": model.find_children("*", "AnimationPlayer", true, false).size(), "lighting": {"ambient_energy": 0.45, "directional_energy": 0.65, "directional_rotation": [-50, -35, 0]}, "captures": captures}
	var file := FileAccess.open(OUTPUT + "/report.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("Tiny Treats original cash-register inspection: " + str(captures.size()) + " views; no production acceptance")
	quit(0)
