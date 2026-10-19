extends SceneTree
const BASE := "res://build/professional-english/retail-term-art-review/shelf-r01"
var camera: Camera3D
var captures: Array = []
var structures: Array = []
func _initialize() -> void: _run.call_deferred()
func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = node.global_transform.affine_inverse() * child.global_transform * child.get_aabb()
		result = part if first else result.merge(part)
		first = false
	return result
func _capture(name: String, at: Vector3, target: Vector3, size: float) -> void:
	camera.size = size
	camera.position = at
	camera.look_at(target)
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(BASE + "/source-inspection/" + name + ".png") == OK)
	captures.append({"file": name + ".png", "camera": [at.x, at.y, at.z], "target": [target.x, target.y, target.z], "orthographic_size": size})
func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
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
	environment.environment.ambient_light_energy = 0.35
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.light_color = Color("fffaf0")
	light.light_energy = 0.65
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.shadow_enabled = true
	root.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(camera)
	for name: String in ["shelf-boxes", "shelf-bags", "shelf-end"]:
		var model_path := BASE + "/source/original/" + name + ".glb"
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(ProjectSettings.globalize_path(model_path), state) == OK)
		var model := document.generate_scene(state)
		root.add_child(model)
		var bounds := _bounds(model)
		model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
		var nodes: Array = []
		for node: Node3D in model.find_children("*", "Node3D", true, false):
			nodes.append({"name": node.name, "type": node.get_class(), "path": str(model.get_path_to(node)), "position": [node.position.x, node.position.y, node.position.z]})
		structures.append({"model": name, "sha256": FileAccess.get_sha256(model_path), "bounds": [bounds.position.x, bounds.position.y, bounds.position.z, bounds.size.x, bounds.size.y, bounds.size.z], "nodes": nodes})
		await _capture(name + "-front", Vector3(2.1, 1.9, 4), Vector3(0, 0.43, 0), 1.27)
		await _capture(name + "-rear", Vector3(-2.1, 1.9, -4), Vector3(0, 0.43, 0), 1.27)
		if name == "shelf-boxes":
			await _capture(name + "-front-level", Vector3(0.6, 1.0, 4), Vector3(0, 0.43, 0), 1.15)
			await _capture(name + "-front-high", Vector3(-1.5, 2.8, 4), Vector3(0, 0.43, 0), 1.27)
		model.queue_free()
		await process_frame
	var file := FileAccess.open(BASE + "/source-inspection/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Original static source models inspected before candidate composition. No nodes hidden, geometry altered, or materials changed.", "models": structures, "captures": captures}, "\t") + "\n")
	file.close()
	print("Inspected three original Kenney Mini Market shelf sources in eight views")
	quit(0)
