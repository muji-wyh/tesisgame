extends SceneTree
## Capture the actual loss card and Pip artwork without accessing player saves.

const Result = preload("res://scripts/talk_quest_result.gd")
const OUTPUT := "res://build/talk-quest-pip-loss-review"
const LAYOUTS := [
	{"label": "desktop", "size": Vector2i(1050, 600)},
	{"label": "phone", "size": Vector2i(390, 650)},
	{"label": "small-phone", "size": Vector2i(320, 414)},
	{"label": "compact-landscape", "size": Vector2i(544, 140)},
]

var captures: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _capture(result, label: String) -> void:
	result.set_process(false)
	result.pip.set_process(false)
	result.queue_redraw()
	result.pip.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	if frame == null or frame.is_empty():
		failures += 1
		printerr("Unable to render loss review: " + label)
		return
	var crop: Image = frame.get_region(Rect2i(Vector2i.ZERO, Vector2i(result.size)))
	if crop.save_png(OUTPUT + "/" + label + ".png") != OK:
		failures += 1
		printerr("Unable to save loss review: " + label)
		return
	captures += 1


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Loss visual review requires the real renderer; omit --headless and use --audio-driver Dummy.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var result = Result.new()
	root.add_child(result)
	for layout: Dictionary in LAYOUTS:
		root.size = layout.size
		result.size = Vector2(layout.size)
		result.reset_loss()
		result.set_reduced_motion(false)
		result.present(4, "Friendly forest guardian", 4, 7, 3, false)
		result.reveal = 1.0
		result.layout()
		result.pip._process(1.0)
		result._process(1.0)
		await _capture(result, str(layout.label) + "-sad")
		result.pip._process(1.41)
		result._process(1.41)
		result.pip._process(0.45)
		await _capture(result, str(layout.label) + "-encouraging")
	result.reset_loss()
	result.set_reduced_motion(true)
	root.size = Vector2i(390, 650)
	result.size = Vector2(root.size)
	result.present(4, "Friendly forest guardian", 4, 7, 3, false)
	await _capture(result, "phone-reduced-motion-sad")
	result.pip._process(Result.LOSS_SAD_SECONDS + 0.01)
	result._process(Result.LOSS_SAD_SECONDS + 0.01)
	await _capture(result, "phone-reduced-motion-encouraging")
	result.free()
	print("Talk Quest Pip loss review: %d captures, %d failures" % [captures, failures])
	quit(1 if failures else 0)
