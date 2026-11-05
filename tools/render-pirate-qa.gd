extends SceneTree
## Native Compatibility renders of actual optimized Pirate meshes and morphs.

const Actor = preload("res://scripts/pirate_asset_actor.gd")
const OUTPUT: String = "res://build/qa/pirate-asset"
const PORTRAIT: String = "res://assets/pirate/pirate-portrait.png"
const POSES: Dictionary = {"Idle": 0.45, "Attack_L": 0.22, "Attack_M": 0.40,
	"Attack_P": 0.69, "Hit_L": 0.07, "Hit_M": 0.10, "Hit_P": 0.12,
	"Ultimate_TidalRush": 1.32, "Ultimate_CrescentSpin": 0.90,
	"Ultimate_CaptainsDrop": 1.18, "Special_GiantRam": 1.05, "Special_BigBite": 0.60,
	"Taunt_HatTip": 0.65, "Taunt_BellyLaugh": 0.95, "Taunt_SideEye": 0.80,
	"Taunt_NopeWag": 0.64, "Taunt_Peekaboo": 0.65, "Taunt_MockBow": 0.70,
	"Taunt_Swagger": 1.15, "Taunt_TongueTease": 0.90, "Taunt_VictoryLap": 1.20,
	"Taunt_FakeSleep": 1.20}
var actor
var viewport: SubViewport
var camera: Camera3D
var failures: int = 0
var outputs: Array[Dictionary] = []
var extra_outputs: Array[Dictionary] = []
var portrait_check_path: String = PORTRAIT


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Pirate portraits require an actual rendering backend.")
		quit(1)
		return
	root.size = Vector2i(384, 576)
	viewport = SubViewport.new()
	viewport.size = Vector2i(384, 576)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var studio := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e4f4e8")
	environment.ambient_light_energy = 0.65
	studio.environment = environment
	viewport.add_child(studio)
	for spec: Array in [[Vector3(-35, -30, 0), Color("#fff0d1"), 1.0],
		[Vector3(-15, 125, 0), Color("#d9e8ff"), 0.6]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		viewport.add_child(light)
	actor = Actor.new()
	actor.auto_advance = false
	viewport.add_child(actor)
	if not actor.load_character():
		printerr(actor.last_error)
		quit(1)
		return
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.6
	camera.near = 0.01
	camera.far = 100.0
	viewport.add_child(camera)
	camera.position = Vector3(0.0, 1.5, 8.0)
	camera.look_at(Vector3(0.0, 1.5, 0.0))
	camera.make_current()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for clip: String in Actor.CLIPS:
		var pose_time: float = float(POSES[clip])
		actor.pose(clip, pose_time)
		var image: Image = await _draw()
		var occupied: Rect2i = image.get_used_rect()
		if occupied.size.x <= 0 or occupied.size.y <= 0 or occupied.position.x <= 0 \
			or occupied.position.y <= 0 or occupied.end.x >= image.get_width() \
			or occupied.end.y >= image.get_height():
			failures += 1
			printerr("FAIL: %s does not retain a complete, padded transparent silhouette: %s" % [clip, occupied])
		var path: String = OUTPUT + "/" + clip.to_lower() + ".png"
		if image.save_png(path) != OK:
			failures += 1
			printerr("FAIL: Could not save " + path)
		outputs.append({"clip": clip, "time": pose_time, "path": path,
			"sha256": FileAccess.get_sha256(path), "width": 384, "height": 576,
			"alpha_bounds": [occupied.position.x, occupied.position.y, occupied.size.x, occupied.size.y]})
	actor.pose("Taunt_FakeSleep", 2.05)
	var wake_image: Image = await _draw()
	var wake_bounds: Rect2i = wake_image.get_used_rect()
	if wake_bounds.size.x <= 0 or wake_bounds.size.y <= 0 or wake_bounds.position.x <= 0 \
		or wake_bounds.position.y <= 0 or wake_bounds.end.x >= wake_image.get_width() \
		or wake_bounds.end.y >= wake_image.get_height():
		failures += 1
		printerr("FAIL: The Fake Sleep wake-up pose loses its padded silhouette.")
	var wake_path: String = OUTPUT + "/taunt_fakesleep_wakeup.png"
	if wake_image.save_png(wake_path) != OK:
		failures += 1
		printerr("FAIL: Could not save the Fake Sleep wake-up pose.")
	extra_outputs.append({"clip": "Taunt_FakeSleep", "time": 2.05, "path": wake_path,
		"sha256": FileAccess.get_sha256(wake_path), "width": 384, "height": 576,
		"alpha_bounds": [wake_bounds.position.x, wake_bounds.position.y, wake_bounds.size.x, wake_bounds.size.y]})
	# Inspect the actual recessed oral lining and morphed lip at native pixel scale.
	viewport.size = Vector2i(512, 512)
	camera.size = 1.45
	camera.position = Vector3(0.22, 0.55, 8.0)
	camera.look_at(Vector3(0.22, 0.55, 0.0))
	actor.pose("Special_BigBite", float(POSES.Special_BigBite))
	var mouth_image: Image = await _draw()
	var mouth_path: String = OUTPUT + "/big-bite-closeup.png"
	if mouth_image.save_png(mouth_path) != OK:
		failures += 1
		printerr("FAIL: Could not save the native mouth close-up.")
	actor.pose("Taunt_TongueTease", float(POSES.Taunt_TongueTease))
	var tongue_image: Image = await _draw()
	var tongue_path: String = OUTPUT + "/tongue-tease-closeup.png"
	if tongue_image.save_png(tongue_path) != OK:
		failures += 1
		printerr("FAIL: Could not save the native Tongue Tease close-up.")
	extra_outputs.append({"clip": "Taunt_TongueTease", "time": POSES.Taunt_TongueTease,
		"path": tongue_path, "sha256": FileAccess.get_sha256(tongue_path), "width": 512, "height": 512})
	for clip: String in ["Taunt_SideEye", "Taunt_BellyLaugh"]:
		actor.pose(clip, float(POSES[clip]))
		var face_image: Image = await _draw()
		var face_path: String = OUTPUT + "/" + clip.to_lower() + "_closeup.png"
		if face_image.save_png(face_path) != OK:
			failures += 1
			printerr("FAIL: Could not save the native " + clip + " facial close-up.")
		extra_outputs.append({"clip": clip, "time": POSES[clip], "path": face_path,
			"sha256": FileAccess.get_sha256(face_path), "width": 512, "height": 512})
	# A separate tight Idle view supplies the static map/UI image, not combat frames.
	viewport.size = Vector2i(512, 512)
	camera.size = 2.55
	camera.position = Vector3(0.0, 1.0, 8.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	actor.pose("Idle", 0.45)
	var portrait_source: Image = await _draw()
	var source_rect: Rect2i = portrait_source.get_used_rect()
	if source_rect.size.x <= 0 or source_rect.size.y <= 0:
		failures += 1
		printerr("FAIL: The Pirate Idle portrait is empty.")
	else:
		var cropped: Image = portrait_source.get_region(source_rect)
		var fit: float = 228.0 / maxf(cropped.get_width(), cropped.get_height())
		cropped.resize(maxi(1, roundi(cropped.get_width() * fit)),
			maxi(1, roundi(cropped.get_height() * fit)), Image.INTERPOLATE_LANCZOS)
		var portrait: Image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
		portrait.fill(Color.TRANSPARENT)
		portrait.blit_rect(cropped, Rect2i(Vector2i.ZERO, cropped.get_size()),
			(Vector2i(256, 256) - cropped.get_size()) / 2)
		# Keep the approved Idle portrait byte-for-byte while extending the clip pack.
		portrait_check_path = PORTRAIT if not FileAccess.file_exists(PORTRAIT) else OUTPUT + "/idle-portrait-check.png"
		if portrait.save_png(portrait_check_path) != OK:
			failures += 1
			printerr("FAIL: Could not save the Pirate portrait.")
	var report: Dictionary = {"model": Actor.MODEL_PATH,
		"expected_clip_count": Actor.CLIPS.size(), "taunt_count": Actor.TAUNTS.size(),
		"model_sha256": FileAccess.get_sha256(Actor.MODEL_PATH),
		"renderer": "GL Compatibility", "viewport": [384, 576],
		"camera": {"projection": "orthographic", "size": 6.6, "center_y": 1.5},
		"mouth_closeup": {"path": mouth_path, "sha256": FileAccess.get_sha256(mouth_path),
			"width": 512, "height": 512, "clip": "Special_BigBite", "time": POSES.Special_BigBite},
		"poses": outputs, "extra_poses": extra_outputs, "portrait": {"path": PORTRAIT,
			"sha256": FileAccess.get_sha256(PORTRAIT), "width": 256, "height": 256,
			"clip": "Idle", "time": 0.45, "transparent": true,
			"verification_path": portrait_check_path,
			"verification_sha256": FileAccess.get_sha256(portrait_check_path)}, "failures": failures}
	var file := FileAccess.open(OUTPUT + "/render-report.json", FileAccess.WRITE)
	if file == null:
		failures += 1
	else:
		file.store_string(JSON.stringify(report, "  ", false) + "\n")
		file.close()
	print("Pirate native renders: %d poses, %d failures; portrait %s" % [outputs.size(), failures, PORTRAIT])
	actor.free()
	viewport.free()
	quit(1 if failures else 0)


func _draw() -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return image
