extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://playful-words-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.set_reduced_motion(false)
	app.audio.set_muted(true)
	var poses: Array = []
	for entry in [["ball", "play-time"], ["bell", "music-makers"], ["rocket", "space-trip"],
		["fish", "animal-friends"], ["boat", "on-the-move"], ["flower", "great-outdoors"]]:
		var id: String = entry[0]
		check(app.new_round(42, false, entry[1], "match", id), "A real Match board includes the animated noun " + id)
		await settle()
		var card = app.cards[id + ":image"]
		var word_card = app.cards[id + ":word"]
		var home: Transform2D = card.picture.get_transform()
		var hitbox: Rect2 = card.get_global_rect()
		var label: Rect2 = word_card.word_label.get_global_rect()
		word_card.pressed.emit()
		card.pressed.emit()
		var tween: Tween = card._word_play.get("_tween")
		check(tween != null and not app.audio.voice.playing, id + " has a real picture reaction during silent Match")
		if tween != null:
			tween.pause()
			tween.custom_step(0.16)
			var pose: Transform2D = card.picture.get_transform()
			check(not pose.is_equal_approx(home), id + " moves its picture after a correct pair")
			poses.append(pose)
			check(card.get_global_rect().is_equal_approx(hitbox)
				and word_card.word_label.get_global_rect().is_equal_approx(label),
				"The readable word and interaction rectangle remain stationary")
			tween.custom_step(0.44)
			check(card.picture.get_transform().is_equal_approx(home), id + " restores its exact transform within 600ms")
		app._continue_match()
		card.pressed.emit()
		var old: Tween = card._word_play.get("_tween")
		card.pressed.emit()
		check(old == null or not old.is_valid(), "Rapid matched-card taps replace, not queue, picture reactions")
		app._show_collection()
		check(card.picture.get_transform().is_equal_approx(home) and card._word_play.get("_tween") == null,
			"Covering Match cancels picture motion immediately")
		app._hide_collection()
	check(poses.size() == 6 and poses[0] != poses[1] and poses[2] != poses[3],
		"Nouns use different trajectories rather than one universal bounce")
	check(app.new_round(42, false, "play-time", "match", "book"), "An unanimated noun also has a real Match pair")
	await settle()
	app.cards["book:word"].pressed.emit()
	app.cards["book:image"].pressed.emit()
	check(app.cards["book:image"]._word_play.get("_tween") == null, "Unlisted nouns keep their original static picture")
	app.set_reduced_motion(true)
	app.new_round(42, false, "play-time", "match", "ball")
	app.audio.set_muted(false)
	await settle()
	var reduced_home: Transform2D = app.cards["ball:image"].picture.get_transform()
	app.cards["ball:word"].pressed.emit()
	app.cards["ball:image"].pressed.emit()
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://assets/audio/voice/word-ball.wav")
		and app.cards["ball:image"]._word_play.get("_tween") == null
		and app.cards["ball:image"].picture.get_transform().is_equal_approx(reduced_home),
		"Reduced motion keeps pronunciation and the original readable picture")
	app.set_reduced_motion(false)
	app.new_round(42, false, "play-time", "match", "ball")
	app.audio.set_muted(false)
	app._select_card("ball:word")
	app._select_card("ball:image")
	check(app.model.successes == 1 and app.model.phase == "feedback",
		"Picture play preserves normal matching")
	check(app.audio.voice.stream == load("res://assets/audio/voice/word-ball.wav"),
		"Correct Match repeats its actual noun instead of generic praise")
	var picture_card = app.cards["ball:image"]
	check(picture_card.get("_word_play") != null, "WordCard shares the bounded word reaction")
	if picture_card.get("_word_play") != null:
		check(picture_card._word_play.get("_tween") != null, "A successful pair plays its picture")
		app._continue_match()
		var snapshot: Array = [app.model.successes, app.model.mistakes, app.model.hints_remaining, app.model.selected_id]
		app._select_card("ball:word")
		check(picture_card._word_play.get("_tween") != null,
			"Replaying the completed word reacts on the matching picture")
		check(snapshot == [app.model.successes, app.model.mistakes, app.model.hints_remaining, app.model.selected_id],
			"Matched replay does not rescore, spend hints, or change selection")
		app._show_collection()
		check(picture_card._word_play.get("_tween") == null, "Covering a board stops its picture reactions")
		app._hide_collection()
		app._on_voice_state([true, true, "Listening"])
		app._select_card("ball:word")
		check(not app.audio.voice.playing and not app.audio.active, "Voice mode stays quiet during matched replay")
		app._stop_voice()
	app.audio.halt()
	app.queue_free()
	await settle()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Playful words: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
