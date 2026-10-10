extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")

class DelayedDangerAudio extends "res://scripts/game_audio.gd":
	signal danger_loaded

	func _stream(path: String, loop: bool = false) -> AudioStream:
		if path == JELLY_PATHS.danger:
			await danger_loaded
		return await super._stream(path, loop)


class DelayedReleaseAudio extends "res://scripts/game_audio.gd":
	signal release_loaded

	func _stream(path: String, loop: bool = false) -> AudioStream:
		if path == JELLY_PATHS.release:
			await release_loaded
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
	await _check_pending_release()
	await create_timer(0.15).timeout
	print("Jelly Match audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _exercise() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.interact("spring")
	for cue in ["pick", "release", "land", "merge", "pop", "danger", "reward"]:
		audio.play_jelly_cue(cue)
		var player: AudioStreamPlayer = audio._jelly_players[posmod(audio._jelly_next_player - 1, 3)]
		check(player.stream != null and player.stream.resource_path == Audio.JELLY_PATHS[cue], "The %s cue uses its production recording" % cue)
		check(player.playing, "The %s recording starts on its timeline event" % cue)
		audio.stop_jelly_sounds()
	check(audio._jelly_players.size() == 3, "Frequent effects reuse a bounded voice pool")
	_check_interaction_audio(audio)
	_check_warning_cancellation(audio)
	_check_landing_audio(audio)
	audio.interact("spring", false)
	audio.say("res://assets/audio/voice/word-cat.wav")
	audio.play_jelly_cue("merge")
	var speaking_player: AudioStreamPlayer = audio._jelly_players[posmod(audio._jelly_next_player - 1, 3)]
	check(is_equal_approx(speaking_player.volume_db, linear_to_db(Audio.JELLY_GAINS.merge) - 6.0), "Pronunciation keeps the merge effect six decibels below its normal mix")
	audio.play_jelly_cue("danger")
	var warning_player: AudioStreamPlayer = audio._jelly_players[posmod(audio._jelly_next_player - 1, 3)]
	check(is_equal_approx(warning_player.volume_db, linear_to_db(Audio.JELLY_GAINS.danger) - 6.0),
		"Repeated warning audio preserves the six-decibel pronunciation duck")
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


func _check_interaction_audio(audio) -> void:
	audio.stop_jelly_sounds()
	audio.say("res://assets/audio/voice/word-cat.wav")
	var word_stream: AudioStream = audio.voice.stream
	for cue: String in ["pick", "release"]:
		audio.play_jelly_cue(cue)
		var player: AudioStreamPlayer = audio._jelly_players[posmod(audio._jelly_next_player - 1, 3)]
		check(player.playing and player.stream.resource_path == Audio.JELLY_PATHS[cue]
			and is_equal_approx(player.volume_db, linear_to_db(Audio.JELLY_GAINS[cue]) - 6.0),
			"The %s feedback starts immediately beneath pronunciation" % cue)
		check(audio.voice.playing and audio.voice.stream == word_stream,
			"The %s feedback preserves the selected word recording" % cue)
	audio.stop_voice()
	audio._process(0.01)
	for player: AudioStreamPlayer in audio._jelly_players:
		if audio._jelly_cues.has(player):
			check(is_equal_approx(player.volume_db, linear_to_db(Audio.JELLY_GAINS[audio._jelly_cues[player]])),
				"Interaction feedback returns to its baseline when pronunciation ends")
	audio.stop_jelly_sounds()
	for cue: String in ["danger", "pop", "reward"]:
		audio.play_jelly_cue(cue)
	var occupied: Dictionary = audio._jelly_cues.duplicate()
	for cue: String in ["pick", "release"]:
		audio.play_jelly_cue(cue)
		check(audio._jelly_cues == occupied,
			"Rapid %s input cannot replace warning, clear or reward audio" % cue)
	for player: AudioStreamPlayer in audio._jelly_players:
		check(player.playing and player.stream.resource_path == Audio.JELLY_PATHS[occupied[player]],
			"Foreground audio survives input when all three channels are occupied")
	audio.halt()
	for cue: String in ["pick", "release", "land"]:
		audio.play_jelly_cue(cue)
		check(audio._jelly_cues.is_empty(), "Inactive gameplay cannot start a %s cue" % cue)
	audio.interact("spring", false)


func _check_landing_audio(audio) -> void:
	audio.stop_jelly_sounds()
	for cue: String in ["danger", "pop", "reward"]:
		audio.play_jelly_cue(cue)
	var occupied: Dictionary = audio._jelly_cues.duplicate()
	audio.play_jelly_cue("land")
	check(audio._jelly_cues == occupied and audio._jelly_players.size() == 3,
		"Landing feedback cannot steal a warning, answer or reward channel when the pool is busy")
	for player: AudioStreamPlayer in audio._jelly_players:
		check(player.playing and player.stream.resource_path == Audio.JELLY_PATHS[occupied[player]],
			"The original foreground cue remains audible when an impact is skipped")
	audio.stop_jelly_sounds()
	audio.play_jelly_cue("danger")
	var warning: AudioStreamPlayer = audio._jelly_players[0]
	audio.say("res://assets/audio/voice/word-cat.wav")
	audio.play_jelly_cue("land")
	var landing: AudioStreamPlayer = audio._jelly_players[1]
	check(warning.playing and landing.playing and landing.stream.resource_path == Audio.JELLY_PATHS.land
		and is_equal_approx(landing.volume_db, linear_to_db(Audio.JELLY_GAINS.land) - 6.0),
		"A quiet impact uses an idle channel and ducks beneath pronunciation without cutting the warning")
	audio.stop_voice()
	audio._process(0.01)
	check(is_equal_approx(landing.volume_db, linear_to_db(Audio.JELLY_GAINS.land)),
		"Landing returns to its quiet baseline after pronunciation")
	audio.set_muted(true)
	audio.play_jelly_cue("land")
	audio.set_muted(false)
	check(not landing.playing and landing.stream == null and audio._jelly_cues.is_empty(),
		"Mute cancels impact tails and unmute cannot replay a suppressed landing")
	audio.stop_jelly_sounds()


func _check_warning_cancellation(audio) -> void:
	audio.stop_jelly_sounds()
	audio.play_jelly_cue("danger")
	var warning: AudioStreamPlayer = audio._jelly_players[0]
	audio.play_jelly_cue("pop")
	var clear: AudioStreamPlayer = audio._jelly_players[1]
	audio.play_jelly_cue("merge")
	var merge: AudioStreamPlayer = audio._jelly_players[2]
	check(warning.playing and warning.stream.resource_path == Audio.JELLY_PATHS.danger,
		"Starting a merge preserves the active full-board warning")
	audio.stop_jelly_danger()
	check(not warning.playing and warning.stream == null,
		"Completing a rescue stops the previous warning tail")
	check(clear.playing and clear.stream.resource_path == Audio.JELLY_PATHS.pop
		and merge.playing and merge.stream.resource_path == Audio.JELLY_PATHS.merge,
		"Selective warning cancellation preserves unrelated clear audio and the new merge")
	audio.stop_jelly_sounds()
	audio.play_jelly_cue("danger")
	audio.play_jelly_cue("danger")
	audio.play_jelly_cue("merge")
	audio.stop_jelly_danger()
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
	for interruption: String in ["clear", "mute", "halt"]:
		var audio := DelayedDangerAudio.new()
		root.add_child(audio)
		audio.interact("spring", false)
		audio.play_jelly_cue("danger")
		var warning: AudioStreamPlayer = audio._jelly_players[0]
		check(not warning.playing and warning.stream == null,
			"The %s fixture holds warning preparation before playback" % interruption)
		match interruption:
			"clear":
				audio.play_jelly_cue("merge")
				audio.stop_jelly_danger()
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
		if interruption == "clear":
			check(audio._jelly_players[1].stream != null
				and audio._jelly_players[1].stream.resource_path == Audio.JELLY_PATHS.merge,
				"Canceling delayed danger leaves the already requested rescue sound intact")
		audio.halt()
		audio.queue_free()
		await process_frame


func _check_pending_release() -> void:
	for interruption: String in ["pause", "mute", "halt"]:
		var audio := DelayedReleaseAudio.new()
		root.add_child(audio)
		audio.interact("spring", false)
		audio.play_jelly_cue("release")
		var release: AudioStreamPlayer = audio._jelly_players[0]
		check(not release.playing and release.stream == null,
			"The %s fixture holds release preparation before playback" % interruption)
		match interruption:
			"pause":
				audio.stop_jelly_sounds()
			"mute":
				audio.set_muted(true)
				audio.set_muted(false)
				for cue: String in ["pick", "release"]:
					audio.play_jelly_cue(cue)
					check(audio._jelly_cues.is_empty(),
						"Unmute cannot reactivate suppressed %s input before gameplay resumes" % cue)
				audio.interact("spring", false)
			"halt":
				audio.halt()
				audio.interact("spring", false)
		audio.release_loaded.emit()
		await process_frame
		check(not release.playing and release.stream == null and audio._jelly_cues.is_empty(),
			"An interrupted release cannot play late after %s or return to the mode" % interruption)
		audio.play_jelly_cue("pick")
		check(audio._jelly_players[0].playing
			and audio._jelly_players[0].stream.resource_path == Audio.JELLY_PATHS.pick,
			"A new selection responds immediately after %s without replaying old input" % interruption)
		audio.halt()
		audio.queue_free()
		await process_frame
