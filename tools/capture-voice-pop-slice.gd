extends SceneTree

# Uses the real game scene and hit/audio connections. Only the speech source
# and clock are deterministic; player saves live in an isolated capture folder.
const Progress = preload("res://scripts/medal_progress.gd")
const STAGES: Array[Dictionary] = [
	{"id": "impact", "age": 0.0}, {"id": "rupture", "age": 0.044},
	{"id": "blade", "age": 0.12}, {"id": "separated", "age": 0.25},
	{"id": "falling", "age": 0.50}, {"id": "faded", "age": 0.75}
]

var app
var view
var layout_id: String = "desktop"
var dimensions := Vector2i(960, 720)
var output_directory: String = "res://build/voice-pop-slice"
var clock_seconds: float = 0.0
var ready_to_capture: bool = false
var first_hit_time: float = -1.0
var second_hit_time: float = -1.0
var next_stage: int = 0
var stages: Array[Dictionary] = []
var hits: Array[Dictionary] = []
var before_saved: bool = false
var done: bool = false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--layout="):
			layout_id = argument.trim_prefix("--layout=")
	if layout_id not in ["desktop", "portrait"]:
		printerr("Unknown Voice Pop capture layout: " + layout_id)
		quit(1)
		return
	if layout_id == "portrait":
		dimensions = Vector2i(390, 844)
	_start.call_deferred()


func _start() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = dimensions
	DirAccess.make_dir_recursive_absolute(output_directory)
	var isolated: String = "user://voice-pop-capture-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(isolated)
	app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = Progress.new(isolated + "/medals.cfg", isolated + "/legacy.cfg")
	app.playroom_save_path = isolated + "/room.cfg"
	root.add_child(app)
	for frame in range(8):
		await process_frame
	app.choose_mode("pop")
	view = app._pop
	var vocabulary: Array = app.data.words.filter(func(word: Dictionary) -> bool:
		return str(word.id) in ["apple", "orange", "banana", "strawberry", "watermelon"])
	view.configure(vocabulary, false, 41)
	app._on_voice_state([true, true, "Listening. Say an English word."])
	view.set_process(false)
	view._listening_tick_usec = -1
	view.game.advance(3.0)
	view._refresh_targets()
	view.hit.connect(func(word: Dictionary) -> void:
		hits.append({"word": str(word.text), "time": clock_seconds}))
	app.audio.stop_music()
	ready_to_capture = true


func _capture_stage(id: String, requested_age: float = -1.0) -> void:
	var file: String = "%s-%s.png" % [layout_id, id]
	var effects: Array[Dictionary] = []
	for effect in view.slice_snapshot():
		effects.append({"uid": effect.uid, "word": effect.word, "age": effect.age,
			"center": [effect.center.x, effect.center.y], "size": [effect.size.x, effect.size.y],
			"first_offset": [effect.first_offset.x, effect.first_offset.y],
			"second_offset": [effect.second_offset.x, effect.second_offset.y],
			"first_rotation": effect.first_rotation, "second_rotation": effect.second_rotation,
			"alpha": effect.alpha})
	var stage := {"id": id, "file": file, "time": clock_seconds, "requested_age": requested_age,
		"effects": effects, "hits": view.game.hits, "remaining": view.game.remaining}
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image.save_png(output_directory + "/" + file) != OK:
		printerr("Could not save Voice Pop stage: " + file)
		quit(1)
		return
	stages.append(stage)


func _process(delta: float) -> bool:
	clock_seconds += delta
	if not ready_to_capture or done:
		return false
	# Advance the exact production model and presentation separately so capture
	# frame rate cannot feed wall-clock time back into the round's game clock.
	view._advance_slices(delta)
	view._advance_game(delta)
	view._last_hit_left = maxf(0.0, view._last_hit_left - delta)
	view._listening_tick_usec = -1
	if not before_saved and clock_seconds >= 0.8:
		before_saved = true
		_capture_stage.call_deferred("before")
	if first_hit_time < 0.0 and clock_seconds >= 1.0:
		first_hit_time = clock_seconds
		view.receive_transcript(str(view.game.targets[0].word.text))
	if first_hit_time >= 0.0 and next_stage < STAGES.size():
		var stage: Dictionary = STAGES[next_stage]
		if clock_seconds - first_hit_time + 0.000001 >= float(stage.age):
			_capture_stage.call_deferred(str(stage.id), float(stage.age))
			next_stage += 1
	if second_hit_time < 0.0 and clock_seconds >= 2.5:
		second_hit_time = clock_seconds
		var sentence: PackedStringArray = []
		for target in view.game.targets:
			sentence.append(str(target.word.text))
		view.receive_transcript(" ".join(sentence))
	if second_hit_time > 0.0 and second_hit_time < 10.0 and clock_seconds - second_hit_time >= 0.20:
		_capture_stage.call_deferred("multi-hit", 0.20)
		second_hit_time = 10.0 + second_hit_time
	view._update_hud()
	view.queue_redraw()
	view._slice_canvas.queue_redraw()
	if clock_seconds >= 4.5:
		done = true
		print("VOICE_POP_CAPTURE " + JSON.stringify({"capture": "voice-pop-slice", "layout": layout_id,
			"dimensions": [dimensions.x, dimensions.y], "duration": clock_seconds,
			"hits": hits, "first_hit_time": first_hit_time, "stages": stages,
			"final_hits": view.game.hits, "remaining": view.game.remaining,
			"arena": [view._arena.position.x, view._arena.position.y, view._arena.size.x, view._arena.size.y]}))
		quit()
	return false
