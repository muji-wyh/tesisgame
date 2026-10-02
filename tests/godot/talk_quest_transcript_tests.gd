extends SceneTree
## Keep raw recognition feedback separate from bound combat events.

const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")
const Quest = preload("res://scripts/talk_quest.gd")
const OUTPUT := "res://build/talk-quest-transcript-review"

var checks: int = 0
var failures: int = 0
var _directory: String
var _capture: bool = false


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _isolate_quest(node: Node) -> void:
	if node.get_script() == Quest:
		node.save_path = _directory + "/quest.cfg"


func _begin(app) -> void:
	app._page_hidden = false
	app._speech_debug_active = false
	app.collection_page.hide()
	app._leaderboard_overlay.hide()
	if app._mode_id != "quest":
		app.choose_mode("quest")
	app._quest.show()
	app._quest.start_level(1)
	app._quest.set_process(false)
	app._quest._effects.set_process(false)
	app._on_voice_state([true, true, "Listening."])


func _combat_state(quest) -> Dictionary:
	return {
		"progress": quest.game.export_progress().duplicate(true),
		"hp": quest.game.hp, "hits": quest.game.hits, "misses": quest.game.misses,
		"targets": quest.game.targets.duplicate(true),
		"events": quest.game._consumed_speech_events.duplicate(true),
		"model_transcript": quest.game.last_transcript,
		"pending": quest._pending_hits.duplicate(true),
		"attacks": quest._effects._attacks.duplicate(true),
	}


func _check_raw_feedback(app) -> void:
	_begin(app)
	var quest = app._quest
	var before: Dictionary = _combat_state(quest)
	var saved: String = FileAccess.get_file_as_string(quest.save_path)
	app._on_voice_result(["I can hear something near the window", false])
	check(quest._transcript.text == "I can hear something near the window"
		and not bool(quest.snapshot().get("transcript_final", true)) and quest._transcript.is_visible_in_tree(),
		"An unrelated interim browser sentence appears immediately without requiring a word hit")
	app._on_voice_result(["I can hear a bird near the window.", true])
	check(quest.snapshot().transcript == "I can hear a bird near the window."
		and bool(quest.snapshot().get("transcript_final", false)),
		"A final browser sentence replaces its interim hypothesis and reports final status")
	var target: Dictionary = quest.game.current_prompt()
	app._on_voice_result([str(target.text), true])
	check(quest._transcript.text == str(target.text) and _combat_state(quest) == before,
		"Even an exact target on the generic callback cannot score, consume a bound occurrence or launch an attack")
	check(FileAccess.get_file_as_string(quest.save_path) == saved,
		"Displaying raw recognition never writes speech or gameplay changes to the checkpoint")
	app._on_voice_result(["A bird\r\nnear the window\nand a quiet garden", false])
	check(not quest._transcript.text.contains("\n") and not quest._transcript.text.contains("\r")
		and quest._transcript.text.contains("bird") and quest._transcript.text.ends_with("quiet garden"),
		"Browser line breaks become a readable continuous caption")
	var long_phrase: String = "earlier words ".repeat(200) + "the latest words remain visible"
	app._on_voice_result([long_phrase, true])
	check(quest._transcript.text.length() == 2000 and quest._transcript.text.ends_with("the latest words remain visible")
		and not quest._transcript.text.begins_with("earlier words earlier words"),
		"Long recognition is bounded while retaining its latest words instead of its oldest prefix")
	app._on_voice_result(["This sentence stays while I think", true])
	quest._process(3.0)
	check(quest.game.phase == "playing" and quest._transcript.text == "This sentence stays while I think",
		"The latest spoken sentence remains visible beyond the previous 2.5-second feedback timeout")
	for status: String in ["Starting microphone...", "Waiting for microphone audio...", "Listening paused. Reconnecting..."]:
		app._on_voice_state([true, false, status])
		check(quest._transcript.text == "This sentence stays while I think",
			"An automatic recognizer reconnect preserves the last sentence: " + status)
		app._on_voice_result(["stale result during reconnect", false])
		check(quest._transcript.text == "This sentence stays while I think",
			"A late raw callback cannot replace the caption while the microphone is reconnecting")
		app._on_voice_state([true, true, "Listening."])


func _check_bound_scoring(app) -> void:
	_begin(app)
	var quest = app._quest
	var prompt: Dictionary = quest.game.current_prompt()
	var phrase: String = "I think the word is " + str(prompt.text) + ", right there!"
	app._on_voice_result([phrase, false])
	var hp: int = quest.game.hp
	var event: Dictionary = quest.game.speech_target()
	event.merge({"event_id": "transcript-bound-hit", "text": str(prompt.text), "stage": "interim"})
	check(quest.receive_speech(JSON.stringify(event)) and quest.game.hp == hp - 1
		and quest.game.hits == 1 and quest._pending_hits.size() == 1,
		"One separately bound speech occurrence still scores and launches exactly one attack")
	check(quest._transcript.text == phrase and not bool(quest.snapshot().get("transcript_final", true)),
		"The accepted lexical hit leaves the full interim browser sentence intact")
	app._on_voice_result([phrase, true])
	check(quest._transcript.text == phrase and bool(quest.snapshot().get("transcript_final", false))
		and quest.game.hits == 1 and quest._pending_hits.size() == 1,
		"Finalizing the same caption cannot duplicate its already accepted attack")
	check(not quest.receive_speech(JSON.stringify(event)) and quest._transcript.text == phrase,
		"Replaying the bound event changes neither score nor the complete visible sentence")
	check(not JSON.stringify(quest.game.export_progress()).contains(phrase)
		and not FileAccess.get_file_as_string(quest.save_path).contains(phrase),
		"A real scored save still excludes the raw browser sentence")


func _check_clear_and_guards(app) -> void:
	for reason: String in ["stop", "pause", "map", "new level", "microphone error", "disabled", "mode"]:
		_begin(app)
		var quest = app._quest
		app._on_voice_result(["private speech before " + reason, true])
		match reason:
			"stop": quest.stop_speech()
			"pause": quest.pause()
			"map": quest._show_map()
			"new level": quest.start_level(1)
			"microphone error": app._on_voice_state([true, false, "Microphone access was denied."])
			"disabled": app._on_voice_state([false, false, "Voice off."])
			"mode": app.choose_mode("match")
		check(quest._transcript.text.is_empty() and not bool(quest.snapshot().get("transcript_final", true)),
			"The raw sentence and final marker clear on " + reason)
		app._on_voice_result(["late speech after " + reason, true])
		check(quest._transcript.text.is_empty(), "A late callback stays discarded after " + reason)
	for reason: String in ["collection", "leaderboard", "page hidden", "quest hidden", "paused", "not listening", "debug"]:
		_begin(app)
		var quest = app._quest
		match reason:
			"collection": app.collection_page.show()
			"leaderboard": app._leaderboard_overlay.show()
			"page hidden": app._page_hidden = true
			"quest hidden": quest.hide()
			"paused": quest.pause()
			"not listening": app._on_voice_state([true, false, "Starting microphone..."])
			"debug": app._speech_debug_active = true
		var before: Dictionary = _combat_state(quest)
		app._on_voice_result(["late raw browser sentence", false])
		app._on_voice_result(["late raw browser sentence", true])
		check(quest._transcript.text.is_empty() and _combat_state(quest) == before,
			"Raw interim and final callbacks are inert while " + reason)
	_begin(app)


func _check_caption_layouts(app) -> void:
	var quest = app._quest
	for layout: Dictionary in [
		{"label": "phone portrait", "size": Vector2i(390, 844), "lines": 2},
		{"label": "small portrait", "size": Vector2i(320, 568), "lines": 2},
		{"label": "compact landscape", "size": Vector2i(568, 320), "lines": 1},
	]:
		root.size = layout.size
		app._layout()
		quest._layout()
		app._on_voice_result(["These are earlier words that should scroll out of the caption. ".repeat(12)
			+ "The latest spoken words are right here.", true])
		for frame in range(3):
			await process_frame
		var caption: Label = quest._transcript
		var bounds := Rect2(Vector2.ZERO, quest.size)
		check(caption.is_visible_in_tree() and caption.max_lines_visible == int(layout.lines)
			and bounds.grow(1).encloses(caption.get_rect()),
			str(layout.label) + " contains the requested number of caption lines inside the visible game body")
		check(caption.get_line_count() > int(layout.lines) and caption.lines_skipped > 0
			and caption.lines_skipped + caption.get_visible_line_count() >= caption.get_line_count(),
			str(layout.label) + " shows the final wrapped lines of a long recognition result")
		check(not caption.get_rect().intersects(quest._words.get_rect())
			and not caption.get_rect().intersects(quest._feedback.get_rect()),
			str(layout.label) + " keeps speech feedback separate from word targets and microphone status")
		check(caption.clip_text and caption.get_theme_font_size("font_size") * quest._transcript.get_global_transform_with_canvas().get_scale().y >= 11.5,
			str(layout.label) + " clips overflow at a readable text size")
		if _capture:
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			check(image != null and not image.is_empty()
				and image.save_png(OUTPUT + "/" + str(layout.label).replace(" ", "-") + ".png") == OK,
				str(layout.label) + " produces a real main-scene transcript capture")


func _run() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	if _capture and DisplayServer.get_name() == "headless":
		printerr("Transcript capture requires the real renderer; omit --headless and use --audio-driver Dummy.")
		quit(1)
		return
	if _capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_directory = "user://quest-transcript-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(_directory) == OK, "Transcript integration uses isolated player storage")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1050, 800)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(_directory + "/medals.cfg", _directory + "/legacy.cfg")
	app.playroom_save_path = _directory + "/room.cfg"
	app._mode_id = "quest"
	PlayerFixture.install(app, _directory)
	node_added.connect(_isolate_quest)
	root.add_child(app)
	await process_frame
	await process_frame
	node_added.disconnect(_isolate_quest)
	app.set_process(false)
	app.set_reduced_motion(true)
	app.audio.set_muted(true)
	app._quest.set_process(false)
	app._quest._effects.set_process(false)
	check(app._quest.save_path == _directory + "/quest.cfg" and app._quest._loaded
		and app._mode_id == "quest" and app._quest.is_visible_in_tree(),
		"The real main scene runs Quest against the isolated checkpoint")
	_check_raw_feedback(app)
	_check_bound_scoring(app)
	_check_clear_and_guards(app)
	await _check_caption_layouts(app)
	app.audio.halt()
	app.queue_free()
	await process_frame
	for filename: String in DirAccess.get_files_at(_directory):
		DirAccess.remove_absolute(_directory.path_join(filename))
	DirAccess.remove_absolute(_directory)
	print("Talk Quest raw transcript: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
