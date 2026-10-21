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


class DelayedCollectionAudio extends "res://scripts/game_audio.gd":
	signal collection_loaded
	var delay_collection: bool = false

	func _stream(path: String, loop: bool = false) -> AudioStream:
		if delay_collection and path == JELLY_PATHS.pop:
			await collection_loaded
		return await super._stream(path, loop)


class DelayedFragmentAudio extends "res://scripts/game_audio.gd":
	signal fragment_loaded
	var delay_fragment: bool = false

	func _stream(path: String, loop: bool = false) -> AudioStream:
		if delay_fragment and path in [FRAGMENT_APPEAR_PATH, FRAGMENT_ARRIVE_PATH]:
			await fragment_loaded
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


func _matches_jelly_cue(player: AudioStreamPlayer, cue: String) -> bool:
	if player.stream == null:
		return false
	return player.stream.resource_path == Audio.JELLY_PATHS[cue]


func _run() -> void:
	await _exercise()
	await _check_pending_warnings()
	await _check_pending_release()
	await _check_pending_collection()
	await _check_fragment_channels()
	await _check_pending_fragments()
	await create_timer(0.15).timeout
	print("Jelly Match audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _exercise() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.interact("spring")
	for cue in ["pick", "release", "land", "contact", "merge", "pop", "danger", "reward", "finish_ready"]:
		audio.play_jelly_cue(cue)
		var player: AudioStreamPlayer = audio._jelly_players[posmod(audio._jelly_next_player - 1, 3)]
		check(_matches_jelly_cue(player, cue), "The %s cue uses its production recording" % cue)
		check(player.playing, "The %s recording starts on its timeline event" % cue)
		audio.stop_jelly_sounds()
	check(audio._jelly_players.size() == 3, "Frequent effects reuse a bounded voice pool")
	var selected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/assets/jelly-interaction-audio.json"))
	for recording: Dictionary in selected.files:
		check(FileAccess.get_sha256("res://" + recording.path) == recording.source_sha256,
			"The selected %s WAV remains byte-for-byte identical to the approved source" % recording.cue)
		var stream: AudioStream = load(Audio.JELLY_PATHS[recording.cue])
		check(is_equal_approx(stream.get_length(), float(recording.seconds)),
			"The %s cue retains its selected duration without a scheduling delay" % recording.cue)
		check(stream is AudioStreamWAV and stream.format == AudioStreamWAV.FORMAT_16_BITS,
			"The approved %s recording imports as PCM without lossy compression" % recording.cue)
	check(FileAccess.get_sha256("res://" + str(selected.preserved_disappearance.path)) == selected.preserved_disappearance.sha256
		and is_equal_approx(Audio.JELLY_GAINS.pop, 0.90), "The archived disappearance source and shared runtime gain remain preserved")
	_check_collection_pop(audio)
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


func _check_collection_pop(audio) -> void:
	check(Audio.JELLY_PATHS.pop == "res://assets/audio/jelly-match/collect-pop.wav",
		"Collection uses the fixed bubble-pop recording")
	var stream: AudioStream = audio.cache.get(Audio.JELLY_PATHS.pop)
	check(stream is AudioStreamWAV and stream.format == AudioStreamWAV.FORMAT_16_BITS
		and not stream.stereo and stream.mix_rate == 44100 and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED
		and stream.get_length() >= 0.03 and stream.get_length() <= 0.4,
		"The short nonlooping bubble pop is cached as mono PCM before collection")
	audio.stop_jelly_sounds()
	var other_sound_rng: int = audio._pop_slice_rng.state
	for index in range(21):
		audio.play_jelly_cue("pop")
		var player: AudioStreamPlayer = audio._jelly_players[posmod(audio._jelly_next_player - 1, 3)]
		check(player.playing and _matches_jelly_cue(player, "pop") and player.stream == stream,
			"Collection %d immediately reuses the same cached bubble pop" % (index + 1))
		check(is_equal_approx(player.pitch_scale, 1.0),
			"Collection %d preserves the recording's original pitch" % (index + 1))
	check(audio._jelly_players.size() == 3 and audio._pop_slice_rng.state == other_sound_rng,
		"Rapid collections keep the three-channel pool and leave other random sound sequences untouched")
	audio.stop_jelly_sounds()
	audio.say("res://assets/audio/voice/word-cat.wav")
	var word_stream: AudioStream = audio.voice.stream
	audio.play_jelly_cue("pop")
	var collection: AudioStreamPlayer = audio._jelly_players[0]
	check(collection.playing and is_equal_approx(collection.volume_db, linear_to_db(Audio.JELLY_GAINS.pop) - 6.0)
		and audio.voice.playing and audio.voice.stream == word_stream,
		"The collection pop ducks beneath pronunciation without replacing the spoken word")
	audio.stop_voice()
	audio._process(0.01)
	check(is_equal_approx(collection.volume_db, linear_to_db(Audio.JELLY_GAINS.pop)),
		"The collection pop returns to the normal mix after pronunciation")
	audio.stop_jelly_sounds()
	audio.play_jelly_cue("merge")
	check(not audio._jelly_cues.values().has("pop"), "Merging alone never starts a collection pop")
	for suppression: String in ["muted", "inactive", "unavailable"]:
		audio.stop_jelly_sounds()
		match suppression:
			"muted": audio.set_muted(true)
			"inactive": audio.halt()
			"unavailable": audio.available = false
		audio.play_jelly_cue("pop")
		check(audio._jelly_cues.is_empty() and audio._jelly_next_player == 0,
			"A %s collection never queues playback" % suppression)
		for player: AudioStreamPlayer in audio._jelly_players:
			check(not player.playing and player.stream == null, "Suppressed collection tails stay silent")
		audio.set_muted(false)
		audio.available = true
		audio.interact("spring", false)
	audio.play_jelly_cue("pop")
	var resumed: AudioStreamPlayer = audio._jelly_players[0]
	check(resumed.playing and resumed.stream == stream and is_equal_approx(resumed.pitch_scale, 1.0),
		"A fresh collection reuses the same fixed pop after mute and leaving the mode")


func _check_interaction_audio(audio) -> void:
	audio.stop_jelly_sounds()
	audio.say("res://assets/audio/voice/word-cat.wav")
	var word_stream: AudioStream = audio.voice.stream
	for cue: String in ["pick", "release", "contact"]:
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
	for cue: String in ["pick", "release", "contact"]:
		audio.play_jelly_cue(cue)
		check(audio._jelly_cues == occupied,
			"Rapid %s input cannot replace warning, clear or reward audio" % cue)
	for player: AudioStreamPlayer in audio._jelly_players:
		check(player.playing and _matches_jelly_cue(player, occupied[player]),
			"Foreground audio survives input when all three channels are occupied")
	audio.halt()
	for cue: String in ["pick", "release", "land", "contact"]:
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
		check(player.playing and _matches_jelly_cue(player, occupied[player]),
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
	check(clear.playing and _matches_jelly_cue(clear, "pop")
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


func _check_pending_collection() -> void:
	for interruption: String in ["pause", "mute", "halt"]:
		var audio := DelayedCollectionAudio.new()
		root.add_child(audio)
		audio.interact("spring", false)
		audio.delay_collection = true
		audio.play_jelly_cue("pop")
		var collection: AudioStreamPlayer = audio._jelly_players[0]
		check(not collection.playing and collection.stream == null,
			"The %s fixture delays the collection pop before playback" % interruption)
		match interruption:
			"pause": audio.stop_jelly_sounds()
			"mute":
				audio.set_muted(true)
				audio.set_muted(false)
			"halt": audio.halt()
		audio.interact("spring", false)
		audio.delay_collection = false
		audio.collection_loaded.emit()
		await process_frame
		check(not collection.playing and collection.stream == null and audio._jelly_cues.is_empty(),
			"A delayed collection cannot replay after %s" % interruption)
		audio.play_jelly_cue("pop")
		check(collection.playing and _matches_jelly_cue(collection, "pop")
			and collection.stream == audio.cache.get(Audio.JELLY_PATHS.pop) and is_equal_approx(collection.pitch_scale, 1.0),
			"Only a fresh collection starts the fixed pop after %s" % interruption)
		audio.halt()
		audio.queue_free()
		await process_frame


func _fragment_silent(audio) -> bool:
	for player: AudioStreamPlayer in audio._fragment_players:
		if player.playing or player.stream != null:
			return false
	return true


func _fragment_playing(audio, path: String) -> bool:
	for player: AudioStreamPlayer in audio._fragment_players:
		if player.playing and player.stream != null and player.stream.resource_path == path:
			return true
	return false


func _check_fragment_channels() -> void:
	var appearance: AudioStreamWAV = load(Audio.FRAGMENT_APPEAR_PATH)
	var arrival: AudioStreamWAV = load(Audio.FRAGMENT_ARRIVE_PATH)
	check(appearance != null and arrival != null and appearance != arrival and appearance.data != arrival.data,
		"Fragment appearance and destination contact use distinct acquired recordings")
	var audio := Audio.new()
	root.add_child(audio)
	audio.play_fragment_appearance()
	audio.play_fragment_arrival()
	check(audio._fragment_players.is_empty(), "Inactive fragment events cannot allocate or queue sound")
	audio.interact("spring", false)
	audio.say("res://assets/audio/voice/word-cat.wav")
	audio.play_coin_arrival()
	for cue: String in ["danger", "merge", "reward"]:
		audio.play_jelly_cue(cue)
	var occupied: Dictionary = audio._jelly_cues.duplicate()
	var requests: Dictionary = {}
	for player: AudioStreamPlayer in audio._jelly_players + audio._coin_players + [audio.voice]:
		if player.playing:
			requests[player] = audio._playback_requests.get(player, 0)
	check(requests.size() == 5,
		"The independent-lane fixture starts one word, one coin, and three foreground jelly sounds")
	var rng_state: int = audio._pop_slice_rng.state
	for index in range(24):
		audio.play_fragment_appearance()
		audio.play_fragment_arrival()
	check(audio._fragment_players.size() == 4 and _fragment_playing(audio, Audio.FRAGMENT_APPEAR_PATH)
		and _fragment_playing(audio, Audio.FRAGMENT_ARRIVE_PATH),
		"Rapid fragment flights retain both feedback stages inside a fixed four-channel pool")
	check(audio._jelly_cues == occupied and audio._pop_slice_rng.state == rng_state,
		"Fragment effects neither replace foreground jelly sounds nor change gameplay randomness")
	for player: AudioStreamPlayer in requests:
		check(player.playing and audio._playback_requests.get(player, 0) == requests[player],
			"Fragment feedback preserves active pronunciation, coins, warnings, merging, and rewards")
	audio.stop_jelly_sounds()
	check(_fragment_silent(audio) and audio.voice.playing,
		"Pausing gameplay cancels fragment tails without interrupting pronunciation")
	audio.play_fragment_appearance()
	audio.play_fragment_arrival()
	audio.set_muted(true)
	check(_fragment_silent(audio), "Mute immediately cancels both fragment stages")
	audio.play_fragment_appearance()
	audio.play_fragment_arrival()
	audio.set_muted(false)
	check(_fragment_silent(audio), "Unmuting never replays a suppressed fragment cue")
	audio.interact("spring", false)
	audio.available = false
	audio.play_fragment_appearance()
	audio.play_fragment_arrival()
	check(_fragment_silent(audio), "Unavailable audio cannot start either fragment recording")
	audio.available = true
	audio.play_fragment_arrival()
	check(_fragment_playing(audio, Audio.FRAGMENT_ARRIVE_PATH)
		and not _fragment_playing(audio, Audio.FRAGMENT_APPEAR_PATH),
		"A fresh destination event plays only its own recording after audio becomes available")
	audio.halt()
	audio.play_fragment_appearance()
	audio.play_fragment_arrival()
	check(_fragment_silent(audio), "Leaving gameplay cancels fragment sounds and rejects late events")
	audio.queue_free()
	await process_frame


func _check_pending_fragments() -> void:
	for cue: String in ["appearance", "arrival"]:
		for interruption: String in ["pause", "mute", "halt"]:
			var audio := DelayedFragmentAudio.new()
			root.add_child(audio)
			audio.interact("spring", false)
			audio.delay_fragment = true
			audio.call("play_fragment_" + cue)
			check(_fragment_silent(audio), "The %s fixture delays fragment %s before playback" % [interruption, cue])
			match interruption:
				"pause": audio.stop_jelly_sounds()
				"mute":
					audio.set_muted(true)
					audio.set_muted(false)
				"halt": audio.halt()
			audio.interact("spring", false)
			audio.delay_fragment = false
			audio.fragment_loaded.emit()
			await process_frame
			check(_fragment_silent(audio), "A delayed fragment %s cannot restart after %s" % [cue, interruption])
			audio.call("play_fragment_" + cue)
			var expected: String = Audio.FRAGMENT_APPEAR_PATH if cue == "appearance" else Audio.FRAGMENT_ARRIVE_PATH
			check(_fragment_playing(audio, expected), "Fresh fragment %s still responds after %s" % [cue, interruption])
			audio.halt()
			audio.queue_free()
			await process_frame
