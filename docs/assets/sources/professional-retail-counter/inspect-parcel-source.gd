extends SceneTree

const BASE := "res://build/professional-english/retail-term-art-review/counter-r01"
var camera: Camera3D
var captures: Array = []
var structures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = node.global_transform.affine_inverse() * child.global_transform * child.get_aabb()
		result = part if first else result.merge(part)
		first = false
	return result

func _capture(name: String, model: Node3D, direction: Vector3) -> void:
	var bounds := _bounds(model)
	var center: Vector3 = model.global_transform * bounds.get_center()
	var span := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	camera.size = span * 1.45
	camera.position = center + direction * span
	camera.look_at(center)
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var file := BASE + "/source-inspection-parcel/" + name + ".png"
	assert(not FileAccess.file_exists(file))
	assert(root.get_texture().get_image().save_png(file) == OK)
	captures.append({"file": name + ".png", "camera": [camera.position.x, camera.position.y, camera.position.z], "target": [center.x, center.y, center.z], "orthographic_size": camera.size})

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	assert(not FileAccess.file_exists(BASE + "/source-inspection-parcel/report.json"))
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE + "/source-inspection-parcel")) == OK)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(512, 512)
	root.msaa_3d = Viewport.MSAA_4X
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("f6f3e9")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.18
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.light_color = Color("fffaf0")
	light.light_energy = 0.38
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.shadow_enabled = true
	root.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(camera)
	for name: String in ["kitchenBar", "box"]:
		var model_path := BASE + ("/source/parcel/original/" if name == "box" else "/source/original/") + name + ".glb"
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(ProjectSettings.globalize_path(model_path), state) == OK)
		var model := document.generate_scene(state)
		root.add_child(model)
		var bounds := _bounds(model)
		var nodes: Array = []
		for node: Node3D in model.find_children("*", "Node3D", true, false):
			nodes.append({"name": node.name, "type": node.get_class(), "path": str(model.get_path_to(node)), "position": [node.position.x, node.position.y, node.position.z]})
		structures.append({"model": name, "sha256": FileAccess.get_sha256(model_path), "bounds": [bounds.position.x, bounds.position.y, bounds.position.z, bounds.size.x, bounds.size.y, bounds.size.z], "nodes": nodes})
		await _capture(name + "-front", model, Vector3(2.2, 1.7, 4.0))
		await _capture(name + "-rear", model, Vector3(-2.2, 1.7, -4.0))
		model.queue_free()
		await process_frame
	var report := FileAccess.open(BASE + "/source-inspection-parcel/report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"scope": "Four original source views with reduced lighting before candidate composition. Every source geometry, material, node and transform preserved. No production edits.", "models": structures, "captures": captures}, "\t") + "\n")
	report.close()
	print("Counter and sealed parcel source inspection: two originals in four views; ambient 0.18, directional 0.38")
	quit(0)
