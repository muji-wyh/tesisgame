extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")

class DelayedDangerAudio extends "res://scripts/game_audio.gd":
	signal danger_loaded

	func _stream(path: String, loop: bool = false) -> AudioStream:
		if path == JELLY_PATHS.danger:
			await danger_loaded
		return await super._stream(path, loop)


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
	await _check_pending_warnings()
	await create_timer(0.15).timeout
	print("Jelly Match audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _exercise() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.interact("spring")
	for cue in ["merge", "pop", "danger", "reward"]:
		audio.play_jelly_cue(cue)
		var player: AudioStreamPlayer = audio._jelly_players[posmod(audio._jelly_next_player - 1, 3)]
		check(player.stream != null and player.stream.resource_path == Audio.JELLY_PATHS[cue], "The %s cue uses its production recording" % cue)
		check(player.playing, "The %s recording starts on its timeline event" % cue)
	check(audio._jelly_players.size() == 3, "Frequent effects reuse a bounded voice pool")
	_check_warning_cancellation(audio)
	audio.say("res://assets/audio/voice/word-cat.wav")
	audio.play_jelly_cue("merge")
	var speaking_player: AudioStreamPlayer = audio._jelly_players[posmod(audio._jelly_next_player - 1, 3)]
	check(is_equal_approx(speaking_player.volume_db, linear_to_db(Audio.JELLY_GAINS.merge) - 12.0), "Pronunciation ducks the merge effect by twelve decibels")
	audio.play_jelly_cue("danger")
	var warning_player: AudioStreamPlayer = audio._jelly_players[posmod(audio._jelly_next_player - 1, 3)]
	check(is_equal_approx(warning_player.volume_db, linear_to_db(Audio.JELLY_GAINS.danger) - 12.0),
		"Repeated warning audio preserves the twelve-decibel pronunciation duck")
	audio.stop_voice()
	audio._process(0.01)
	check(is_equal_approx(speaking_player.volume_db, linear_to_db(Audio.JELLY_GAINS.merge)), "The normal effect mix returns after speech")
	check(is_equal_approx(warning_player.volume_db, linear_to_db(Audio.JELLY_GAINS.danger)),
		"The warning mix returns to its normal gain after speech")
	audio.set_muted(true)
	for player: AudioStreamPlayer in audio._jelly_players:
		check(not player.playing and player.stream == null, "Mute immediately cancels every Jelly channel")
	audio.play_jelly_cue("danger")
	check(audio._jelly_next_player == 0, "Muted events cannot enqueue deferred playback")
	audio.set_muted(false)
	check(audio._jelly_next_player == 0 and not warning_player.playing and warning_player.stream == null,
		"Unmuting cannot replay warnings that were suppressed while muted")
	audio.interact("spring")
	audio.play_jelly_cue("danger")
	check(audio._jelly_players[0].playing and audio._jelly_players[0].stream.resource_path == Audio.JELLY_PATHS.danger,
		"Only a new live countdown beat restarts warning audio after unmuting")
	audio.play_jelly_cue("reward")
	audio.halt()
	for player: AudioStreamPlayer in audio._jelly_players:
		check(not player.playing and player.stream == null, "Leaving a mode cancels reward tails")
	audio.queue_free()
	await create_timer(0.15).timeout


func _check_warning_cancellation(audio) -> void:
	audio.stop_jelly_sounds()
	audio.play_jelly_cue("danger")
	var warning: AudioStreamPlayer = audio._jelly_players[0]
	audio.play_jelly_cue("pop")
	var clear: AudioStreamPlayer = audio._jelly_players[1]
	audio.play_jelly_cue("merge")
	var merge: AudioStreamPlayer = audio._jelly_players[2]
	check(not warning.playing and warning.stream == null,
		"Starting a rescue merge immediately stops the previous warning tail")
	check(clear.playing and clear.stream.resource_path == Audio.JELLY_PATHS.pop
		and merge.playing and merge.stream.resource_path == Audio.JELLY_PATHS.merge,
		"Selective warning cancellation preserves unrelated clear audio and the new merge")
	audio.stop_jelly_sounds()
	audio.play_jelly_cue("danger")
	audio.play_jelly_cue("danger")
	audio.play_jelly_cue("merge")
	check(not audio._jelly_players[0].playing and audio._jelly_players[0].stream == null
		and not audio._jelly_players[1].playing and audio._jelly_players[1].stream == null
		and audio._jelly_players[2].playing,
		"A rescue cancels every warning channel even when closely delivered beats overlap")
	audio.stop_jelly_sounds()
	for beat in range(8):
		audio.play_jelly_cue("danger")
	check(audio._jelly_players.size() == 3, "All eight countdown beats reuse the existing bounded channel pool")
	audio.stop_jelly_sounds()
	for player: AudioStreamPlayer in audio._jelly_players:
		check(not player.playing and player.stream == null,
			"The shared pause and finish stop path removes all warning tails")


func _check_pending_warnings() -> void:
	for interruption: String in ["merge", "mute", "halt"]:
		var audio := DelayedDangerAudio.new()
		root.add_child(audio)
		audio.interact("spring", false)
		audio.play_jelly_cue("danger")
		var warning: AudioStreamPlayer = audio._jelly_players[0]
		check(not warning.playing and warning.stream == null,
			"The %s fixture holds warning preparation before playback" % interruption)
		match interruption:
			"merge":
				audio.play_jelly_cue("merge")
			"mute":
				audio.set_muted(true)
				audio.set_muted(false)
				audio.interact("spring", false)
			"halt":
				audio.halt()
				audio.interact("spring", false)
		audio.danger_loaded.emit()
		await process_frame
		check(not warning.playing and warning.stream == null,
			"A pending warning cannot restart after %s even when its asset finishes preparing" % interruption)
		if interruption == "merge":
			check(audio._jelly_players[1].stream != null
				and audio._jelly_players[1].stream.resource_path == Audio.JELLY_PATHS.merge,
				"Canceling delayed danger leaves the already requested rescue sound intact")
		audio.halt()
		audio.queue_free()
		await process_frame
