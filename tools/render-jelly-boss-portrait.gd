extends SceneTree
## Render the acquired Bramble rig as a transparent, static map portrait.

const Actor = preload("res://scripts/word_jelly_boss_actor.gd")
const OUTPUT: String = "res://assets/jelly-boss/private/bramble-portrait.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("The Boss portrait requires a real rendering backend, not headless placeholder pixels.")
		quit(1)
		return
	root.size = Vector2i(512, 512)
	var actor := Actor.new()
	root.add_child(actor)
	actor.size = Vector2i(512, 512)
	if not actor.load_character():
		printerr(actor.last_error)
		quit(1)
		return
	actor._camera.position = Vector3(0, 1.57, 6)
	actor._camera.look_at(Vector3(0, 1.57, 0))
	actor._camera.size = 1.34
	actor.pose("Idle", 0.45)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = actor.get_texture().get_image()
	var occupied: Rect2i = image.get_used_rect()
	if occupied.size.x <= 0 or occupied.size.y <= 0:
		printerr("The acquired Boss portrait rendered empty.")
		quit(1)
		return
	var cropped: Image = image.get_region(occupied)
	var fit: float = 228.0 / maxf(cropped.get_width(), cropped.get_height())
	cropped.resize(maxi(1, roundi(cropped.get_width() * fit)),
		maxi(1, roundi(cropped.get_height() * fit)), Image.INTERPOLATE_LANCZOS)
	var portrait: Image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	portrait.fill(Color.TRANSPARENT)
	portrait.blit_rect(cropped, Rect2i(Vector2i.ZERO, cropped.get_size()),
		(Vector2i(256, 256) - cropped.get_size()) / 2)
	if portrait.save_png(OUTPUT) != OK:
		printerr("Could not save the acquired Boss portrait.")
		quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/jelly-boss/manifest.json"))
	manifest["portrait"] = {"path": OUTPUT.trim_prefix("res://"),
		"sha256": FileAccess.get_sha256(OUTPUT), "bytes": FileAccess.get_file_as_bytes(OUTPUT).size(),
		"width": 256, "height": 256, "source_model_sha256": manifest.model.sha256,
		"creator": manifest.source.creator, "license": manifest.source.license,
		"acquisition": "Rendered from the acquired and integrated Bramble model; not a source-listing preview.",
		"animations": "Static portrait sampled from the game-authored Idle clip at 0.45 seconds.",
		"framing": "Complete face and ears, upper-body portrait, transparent background and proportional fit."}
	var file := FileAccess.open("res://assets/jelly-boss/manifest.json", FileAccess.WRITE)
	if file == null:
		printerr("Could not record the Boss portrait's source and output hashes.")
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	file.close()
	print("Acquired Bramble portrait rendered: 256 x 256, " + str(manifest.portrait.sha256))
	actor.free()
	quit(0)
