extends SceneTree
## Sourced static Nursing composition exploration; no production descriptor changes.
const BASE := "res://build/professional-english/nursing-theme-review"
const OUTPUT := BASE + "/motion-r01"
const FURNITURE := BASE + "/acquired/kenney/Furniture Kit/Models/GLTF format/"
const PATHS := {
	"floor": FURNITURE + "floorFull.glb", "wall": FURNITURE + "wall.glb", "window": FURNITURE + "wallWindow.glb",
	"bedside": FURNITURE + "cabinetBedDrawerTable.glb", "chair": FURNITURE + "chairCushion.glb",
	"storage": FURNITURE + "bookcaseClosedDoors.glb",
	"wheelchair": BASE + "/acquired/kenney/Mini Characters/Models/GLB format/wheelchair.glb",
	"curtain": BASE + "/acquired/privacy-curtain/privacy-curtain-and-ceiling-track.glb",
	"station": BASE + "/acquired/nurse-station/nurse-station-with-low-accessible-counter.glb",
	"bed": "res://docs/assets/sources/innerscene-hospital-bed/hospital-bed-raised-backrest.glb",
	"cart": "res://docs/assets/sources/innerscene-medical-supply-cart/medical-supply-cart.glb"
}
var scene: Node3D
var camera: Camera3D
var models: Dictionary = {}
var sources: Dictionary = {}
var placements: Array = []
var props: Array[Node3D] = []
var curtain_adaptation: Dictionary = {}
var textile_motion: RefCounted
var curtain_holder: Node3D

func _initialize() -> void: _run.call_deferred()

func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = node.global_transform.affine_inverse() * child.global_transform * child.get_aabb()
		result = part if first else result.merge(part)
		first = false
	return result

func _model(id: String, at: Vector3, yaw: float = 0, size: Vector3 = Vector3.ONE, is_prop: bool = false) -> Node3D:
	if not models.has(id):
		var path: String = PATHS[id]
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(ProjectSettings.globalize_path(path), state) == OK)
		var original: Node3D = document.generate_scene(state)
		root.add_child(original)
		var b := _bounds(original)
		sources[id] = {"path": path, "sha256": FileAccess.get_sha256(path), "bounds": [b.position.x,b.position.y,b.position.z,b.size.x,b.size.y,b.size.z], "source_animation_count": state.get_animations().size()}
		root.remove_child(original)
		models[id] = original
	var holder := Node3D.new()
	scene.add_child(holder)
	var model: Node3D = models[id].duplicate()
	holder.add_child(model)
	var bounds := _bounds(model)
	model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
	if id == "curtain":
		textile_motion = load(OUTPUT + "/textile-motion.gd").new()
		curtain_adaptation = textile_motion.setup(model)
		curtain_holder = holder
	holder.position = at
	holder.rotation.y = deg_to_rad(yaw)
	holder.scale = size
	if is_prop: props.append(holder)
	placements.append({"source": id,"position": [at.x,at.y,at.z],"yaw": yaw,"scale": [size.x,size.y,size.z],"layer": "props" if is_prop else "environment"})
	return holder

func _capture(name: String) -> void:
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT + "/renders/" + name + ".png") == OK)

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	DirAccess.make_dir_recursive_absolute(OUTPUT + "/renders")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(1024,1024)
	root.msaa_3d = Viewport.MSAA_4X
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("f4f5ef")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.30
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	root.add_child(world)
	var key := DirectionalLight3D.new()
	key.light_color = Color("fffaf0")
	key.light_energy = 0.34
	key.rotation_degrees = Vector3(-50,-35,0)
	key.shadow_enabled = true
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("eef5f4")
	fill.light_energy = 0.08
	fill.rotation_degrees = Vector3(-25,135,0)
	root.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.6
	root.add_child(camera)
	camera.position = Vector3(7,7.3,10)
	camera.look_at(Vector3(0,0.9,0))
	scene = Node3D.new()
	root.add_child(scene)
	# All source instances, including structural modules, use uniform scale.
	for x in range(3):
		for z in range(2): _model("floor",Vector3((x-1)*1.91,0,(z-0.5)*1.91),0,Vector3.ONE*1.91)
	for x in range(3): _model("window" if x == 2 else "wall",Vector3((x-1)*1.91,0.0955,-1.95775),0,Vector3.ONE*1.91)
	for z in range(2): _model("wall",Vector3(-2.91275,0.0955,(z-0.5)*1.91),90,Vector3.ONE*1.91)
	# Five original square source panels form a ceiling cutaway connected to the back wall.
	# Both source brackets have half their upper footprint in contact with the underside.
	for x in range(5): _model("floor",Vector3((x-2)*0.51,2.5585,-1.655),0,Vector3.ONE*0.51)
	_model("curtain",Vector3(0,0.2155,-1.40))
	_model("station",Vector3(-2.18,0.0955,0),-90,Vector3.ONE)
	_model("storage",Vector3(2.48,0.0955,-1.48),0,Vector3.ONE*1.5)
	_model("bed",Vector3(0.15,0.0955,0.40),90,Vector3.ONE,true)
	_model("bedside",Vector3(1.48,0.0955,-1.20),0,Vector3.ONE*2.0,true)
	_model("chair",Vector3(1.90,0.0955,-0.40),-45,Vector3.ONE*1.75,true)
	_model("cart",Vector3(1.75,0.0955,0.80),-15,Vector3.ONE*0.85,true)
	_model("wheelchair",Vector3(-1.05,0.0955,1.30),-20,Vector3.ONE*1.5,true)
	for sample in range(16):
		textile_motion.set_phase(sample/16.0)
		await _capture("composite-%02d"%sample)
	textile_motion.set_phase(1.0)
	await _capture("loop-end")
	for prop: Node3D in props: prop.hide()
	await _capture("environment")
	for prop: Node3D in props: prop.show()
	var file := FileAccess.open(OUTPUT + "/renders/composition-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"scratch_authored_motion_pending_independent_review","renderer":RenderingServer.get_video_adapter_name(),
		"sources":sources,"placements":placements,"curtain_motion_adaptation":curtain_adaptation,"motion_samples":textile_motion.records,"frame_count":16,"frames_per_second":2,"duration_seconds":8,"rest_frame":0,
		"camera":{"position":[7,7.3,10],"target":[0,0.9,0],"orthographic_size":7.6,"source_render_size":[1024,1024]},
		"lighting":{"ambient":0.30,"key":0.34,"key_rotation":[-50,-35,0],"fill":0.08,"fill_rotation":[-25,135,0],"tonemap":"linear","exposure":1.0},
		"ceiling_support":{"source":"Kenney floorFull.glb","treatment":"Five uniformly scaled original source floor panels form a cutaway ceiling strip meeting the back wall; no new primitive geometry","underside_y":2.5585,"curtain_bracket_max_y":2.55849993515015,"bracket_contact_depth_meters":0.0425,"bracket_total_depth_meters":0.085,"contact_gap_meters":0.00000006484985},
		"scope":"Authored lower-hem motion exploration only; no clinical approval, production art integration, readiness change or Home preview replacement."},"\t")+"\n")
	file.close()
	for child in scene.get_children(): child.visible = child == curtain_holder
	curtain_holder.position = Vector3.ZERO
	camera.size = 2.82
	camera.position = Vector3(5.60,4.53,7.47)
	camera.look_at(Vector3(0,1.1715,0))
	for sample: Dictionary in [{"name":"rest","phase":0.0},{"name":"positive-extreme","phase":0.25},{"name":"negative-extreme","phase":0.75},{"name":"loop-end","phase":1.0}]:
		textile_motion.set_phase(sample.phase)
		await _capture("textile-"+sample.name)
	for original: Node3D in models.values(): original.free()
	scene.queue_free()
	for frame in range(3): await process_frame
	print("Nursing authored hem-sway: 16 full source frames, exact loop, 4 isolated poses and matching environment rendered")
	quit(0)
