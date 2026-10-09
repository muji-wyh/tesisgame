extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	await _exercise()
	await create_timer(0.15).timeout
	print("Jelly Match audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _exercise() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.interact("spring")
	for cue in ["merge", "pop", "danger", "tick", "reward"]:
		audio.play_jelly_cue(cue)
		var player: AudioStreamPlayer = audio._jelly_players[posmod(audio._jelly_next_player - 1, 3)]
		check(player.stream != null and player.stream.resource_path == Audio.JELLY_PATHS[cue], "The %s cue uses its production recording" % cue)
		check(player.playing, "The %s recording starts on its timeline event" % cue)
	check(audio._jelly_players.size() == 3, "Frequent effects reuse a bounded voice pool")
	audio.say("res://assets/audio/voice/word-cat.wav")
	audio.play_jelly_cue("merge")
	var speaking_player: AudioStreamPlayer = audio._jelly_players[posmod(audio._jelly_next_player - 1, 3)]
	check(is_equal_approx(speaking_player.volume_db, linear_to_db(Audio.JELLY_GAINS.merge) - 12.0), "Pronunciation ducks the merge effect by twelve decibels")
	audio.stop_voice()
	audio._process(0.01)
	check(is_equal_approx(speaking_player.volume_db, linear_to_db(Audio.JELLY_GAINS.merge)), "The normal effect mix returns after speech")
	audio.set_muted(true)
	for player: AudioStreamPlayer in audio._jelly_players:
		check(not player.playing and player.stream == null, "Mute immediately cancels every Jelly channel")
	audio.play_jelly_cue("danger")
	check(audio._jelly_next_player == 0, "Muted events cannot enqueue deferred playback")
	audio.set_muted(false)
	audio.interact("spring")
	audio.play_jelly_cue("reward")
	audio.halt()
	for player: AudioStreamPlayer in audio._jelly_players:
		check(not player.playing and player.stream == null, "Leaving a mode cancels reward tails")
	audio.queue_free()
	await create_timer(0.15).timeout
