extends SceneTree
## Native source evidence only. Root must grant the shared native slot first.
const BASE := "res://build/professional-english/retail-term-art-review/checkout-r01"
const OUT := BASE + "/source-inspection"
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

func _pose(model: Node3D, clip: String, seconds: float) -> Dictionary:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert(players.size() == 1, "Expected the complete character's original animation player")
	var player: AnimationPlayer = players[0] as AnimationPlayer
	var actual := ""
	for name: StringName in player.get_animation_list():
		if str(name) == clip or str(name).ends_with("/" + clip):
			actual = str(name)
	assert(not actual.is_empty(), "Missing original clip: " + clip)
	player.play(actual)
	player.seek(seconds, true)
	player.pause()
	return {"clip": actual, "seconds": seconds, "method": "Original included animation sampled and paused; no manual skeleton or node edit", "available_clips": Array(player.get_animation_list())}

func _capture(name: String, at: Vector3, target: Vector3, size: float, pose: Dictionary = {}) -> void:
	camera.size = size
	camera.position = at
	camera.look_at(target)
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var file := OUT + "/" + name + ".png"
	assert(root.get_texture().get_image().save_png(file) == OK)
	captures.append({"file": name + ".png", "sha256": FileAccess.get_sha256(file), "camera": [at.x, at.y, at.z], "target": [target.x, target.y, target.z], "orthographic_size": size, "source_pose": pose})

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	assert(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUT)), "Preserve the previous source probe; use a new revision")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
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
	var source_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "/source-record.json"))
	for item: Dictionary in source_data.models:
		var source := BASE + "/" + str(item.retained_path)
		assert(FileAccess.get_sha256(source) == str(item.sha256))
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(ProjectSettings.globalize_path(source), state) == OK)
		var model := document.generate_scene(state)
		root.add_child(model)
		var bounds := _bounds(model)
		model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
		var name: String = str(item.id).replace("/", "--")
		var animated: bool = not item.animations.is_empty()
		structures.append({"source": source, "sha256": FileAccess.get_sha256(source), "source_root_centering_only": [model.position.x, model.position.y, model.position.z], "bind_bounds": [bounds.position.x, bounds.position.y, bounds.position.z, bounds.size.x, bounds.size.y, bounds.size.z], "source_child_nodes": model.find_children("*", "", true, false).size(), "available_animation_count": item.animations.size(), "hidden_or_deleted_source_nodes": []})
		if animated:
			for sample: Dictionary in [{"clip": "static", "seconds": 0.05, "tag": "static"}, {"clip": "idle", "seconds": 0.0, "tag": "idle-start"}, {"clip": "interact-right", "seconds": 0.0, "tag": "interact-start"}, {"clip": "interact-right", "seconds": 0.333, "tag": "interact-middle"}, {"clip": "interact-right", "seconds": 0.65, "tag": "interact-end"}]:
				var pose := _pose(model, str(sample.clip), float(sample.seconds))
				await _capture(name + "-" + str(sample.tag), Vector3(2.3, 1.9, 4), Vector3(0, 0.36, 0), 1.1, pose)
				if sample.tag == "interact-middle":
					await _capture(name + "-interact-middle-side", Vector3(-4, 1.8, 2.3), Vector3(0, 0.36, 0), 1.1, pose)
		elif str(item.id).ends_with("cash-register"):
			await _capture(name + "-front", Vector3(3, 2.4, 4), Vector3(0, 0.29, 0), 1.3)
			await _capture(name + "-rear", Vector3(3, 2.4, -4), Vector3(0, 0.29, 0), 1.3)
			await _capture(name + "-high", Vector3(0.7, 4, 0.8), Vector3(0, 0.25, 0), 1.3)
		else:
			var size := maxf(0.36, maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 1.5)
			await _capture(name + "-front", Vector3(3, 2.4, 4), Vector3(0, bounds.size.y * 0.48, 0), size)
		model.queue_free()
		await process_frame
	var output := FileAccess.open(OUT + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"scope": "Original licensed source models and selected included poses only. Not a composed checkout candidate, image acceptance, or production integration.", "lighting": {"ambient_energy": 0.18, "directional_energy": 0.38, "directional_rotation": [-50, -35, 0]}, "structures": structures, "captures": captures, "source_record_sha256": FileAccess.get_sha256(BASE + "/source-record.json"), "available_animation_scope": "Metadata lists all clips; only static, idle-start and three interact-right samples were rendered. Other clips are retained but not reviewed or used."}, "\t") + "\n")
	output.close()
	print("Checkout original source probe: " + str(structures.size()) + " models, " + str(captures.size()) + " captures")
	quit(0)
