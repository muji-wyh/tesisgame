extends SceneTree

var checks := 0
var failures := 0
var heard := 0


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
	app.choose_mode("learn")
	app.set_reduced_motion(false)
	app.audio.set_muted(true)
	var lesson = app._lesson
	lesson.hear_requested.connect(func(_word: Dictionary) -> void: heard += 1)
	check(lesson.get("_word_play") != null, "Learn has a bounded picture-play controller")
	if lesson.get("_word_play") != null:
		var poses: Array = []
		for id in ["ball", "bell", "rocket", "fish", "boat", "flower"]:
			var word: Dictionary = app.data.words.filter(func(value: Dictionary) -> bool: return value.id == id)[0]
			lesson.show_words([word])
			lesson.set_audio_available(true)
			await settle()
			var home: Transform2D = lesson.picture.get_transform()
			var hitbox: Rect2 = lesson.picture_button.get_global_rect()
			var label: Rect2 = lesson.word_label.get_global_rect()
			lesson.picture_button.pressed.emit()
			var tween: Tween = lesson._word_play.get("_tween")
			check(tween != null, id + " has a real reaction")
			if tween != null:
				tween.pause()
				tween.custom_step(0.16)
				var pose: Transform2D = lesson.picture.get_transform()
				check(not pose.is_equal_approx(home), id + " moves its picture after activation")
				poses.append(pose)
				check(lesson.picture_button.get_global_rect().is_equal_approx(hitbox)
					and lesson.word_label.get_global_rect().is_equal_approx(label),
					"The readable word and interaction rectangle remain stationary")
				tween.custom_step(0.44)
				check(lesson.picture.get_transform().is_equal_approx(home),
					id + " restores its exact transform within 600ms")
			lesson.picture_button.pressed.emit()
			var old: Tween = lesson._word_play.get("_tween")
			lesson.picture_button.pressed.emit()
			check(old == null or not old.is_valid(), "Rapid taps replace, not queue, picture reactions")
			lesson.pause(true)
			check(lesson.picture.get_transform().is_equal_approx(home) and lesson._word_play.get("_tween") == null,
				"Pausing cancels picture motion immediately")
			lesson.pause(false)
		check(poses.size() == 6 and poses[0] != poses[1] and poses[2] != poses[3],
			"Nouns use different trajectories rather than one universal bounce")
		var ball: Dictionary = app.data.words.filter(func(value: Dictionary) -> bool: return value.id == "ball")[0]
		var book: Dictionary = app.data.words.filter(func(value: Dictionary) -> bool: return value.id == "book")[0]
		lesson.show_words([ball, book])
		lesson.set_audio_available(false)
		var before: int = heard
		lesson.picture_button.pressed.emit()
		check(lesson._word_play.get("_tween") != null and heard == before,
			"Silent Learn still plays visually without requesting unavailable audio")
		lesson._move(1)
		check(lesson._word_play.get("_tween") == null, "Changing words cancels the old picture action")
		lesson.picture_button.pressed.emit()
		check(lesson._word_play.get("_tween") == null, "Unlisted nouns keep their original static picture")
		lesson._move(-1)
		app.set_reduced_motion(true)
		lesson.set_audio_available(true)
		before = heard
		var home: Transform2D = lesson.picture.get_transform()
		lesson.picture_button.pressed.emit()
		check(heard == before + 1 and lesson._word_play.get("_tween") == null
			and lesson.picture.get_transform().is_equal_approx(home),
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
