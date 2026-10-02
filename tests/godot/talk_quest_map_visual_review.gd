extends SceneTree
## Render the actual map at phone, compact landscape, and desktop sizes.
## This harness instantiates only the atlas and never reads or writes player saves.

const Atlas = preload("res://scripts/talk_quest_map.gd")
const Data = preload("res://scripts/talk_quest_data.gd")
const OUTPUT := "res://build/talk-quest-map-review"
const LAYOUTS: Array = [
	{"label": "phone", "size": Vector2i(390, 650)},
	{"label": "small-phone", "size": Vector2i(320, 414)},
	{"label": "compact-landscape", "size": Vector2i(544, 140)},
	{"label": "desktop", "size": Vector2i(1050, 600)}
]

var captures: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _capture(atlas: Control, label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	if frame == null or frame.is_empty():
		failures += 1
		printerr("Unable to render map review: " + label)
		return
	var crop: Image = frame.get_region(Rect2i(Vector2i(atlas.position), Vector2i(atlas.size)))
	if crop.save_png(OUTPUT + "/" + label + ".png") != OK:
		failures += 1
		printerr("Unable to save map review: " + label)
		return
	captures += 1


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Map visual review requires a real renderer; omit --headless.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var atlas = Atlas.new()
	root.add_child(atlas)
	atlas.configure(Data.levels())
	atlas.set_reduced_motion(true)
	for number in range(1, 15):
		atlas.set_level_state(number, number <= 7, number < 7)
	for layout: Dictionary in LAYOUTS:
		root.size = layout.size
		atlas.position = Vector2.ZERO
		atlas.size = Vector2(layout.size)
		atlas.set_ui_scale(1.0)
		for chapter in range(3):
			atlas.set_chapter(chapter)
			await _capture(atlas, "%s-chapter-%d" % [layout.label, chapter + 1])
	atlas.queue_free()
	await process_frame
	print("Talk Quest map review: %d captures, %d failures" % [captures, failures])
	quit(1 if failures else 0)
