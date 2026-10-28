extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")

class DelayedComboAudio extends "res://scripts/game_audio.gd":
	signal combo_loaded
	var delay_combo: bool = false

	func _stream(path: String, loop: bool = false) -> AudioStream:
		if delay_combo and path in WORD_JELLY_COMBO_PATHS:
			await combo_loaded
		return await super._stream(path, loop)

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _silent(audio) -> bool:
	for player: AudioStreamPlayer in audio._jelly_combo_players:
		if player.playing or player.stream != null:
			return false
	return true


func _run() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.play_jelly_cue("jelly-combo-3")
	check(audio._jelly_combo_players.is_empty(), "Inactive combo events never allocate or queue audio")
	audio.interact("spring", false)
	for cue: String in ["jelly-combo-0", "jelly-combo--1", "jelly-combo-invalid"]:
		audio.play_jelly_cue(cue)
	check(audio._jelly_combo_players.is_empty(), "Invalid combo cues have no audio side effects")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/assets/jelly-combo-audio.json"))
	for asset: Dictionary in manifest.audio:
		var path: String = "res://" + str(asset.path)
		var stream: AudioStreamWAV = load(path)
		check(FileAccess.get_sha256(path) == str(asset.sha256), "Combo audio matches its source-derived manifest")
		check(stream != null and stream.format == AudioStreamWAV.FORMAT_16_BITS and not stream.stereo
			and stream.mix_rate == 44100 and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED,
			"Combo accents use nonlooping mono PCM16")
		check(absf(stream.get_length() - float(asset.seconds)) < 0.00001,
			"Combo accent retains the complete measured short tail")
	audio.play_jelly_cue("danger")
	audio.play_jelly_cue("jelly-collect-lv6")
	audio.say("res://assets/audio/voice/word-cat.wav")
	var protected: Dictionary = {}
	for player: AudioStreamPlayer in audio._jelly_players + audio._jelly_level_players + [audio.voice]:
		protected[player] = audio._playback_requests.get(player, 0)
	var previous_pitch: float = 0.0
	for count in range(1, 25):
		audio.play_jelly_cue("jelly-combo-%d" % count)
		var player: AudioStreamPlayer = audio._jelly_combo_players[posmod(audio._jelly_combo_next - 1, Audio.WORD_JELLY_COMBO_CHANNELS)]
		var expected_tier: int = 2 if count >= 5 else 1 if count >= 3 else 0
		check(player.playing and player.stream.resource_path == Audio.WORD_JELLY_COMBO_PATHS[expected_tier],
			"Each actual combo level plays its acquired timbre tier")
		check(player.pitch_scale > previous_pitch and player.pitch_scale <= 2.0,
			"Successive combo increments rise within one octave")
		check(is_equal_approx(player.volume_db, linear_to_db(Audio.WORD_JELLY_COMBO_GAINS[expected_tier]) - 6.0),
			"Combo gain remains capped and ducks beneath active pronunciation")
		previous_pitch = player.pitch_scale
	check(audio._jelly_combo_players.size() == 3, "Rapid combo events reuse exactly three independent channels")
	for player: AudioStreamPlayer in protected:
		check(audio._playback_requests.get(player, 0) == protected[player],
			"Combo accents never replace pronunciation, warnings or collection tails")
	audio.stop_voice()
	audio._process(0.01)
	for player: AudioStreamPlayer in audio._jelly_combo_players:
		check(is_equal_approx(player.volume_db, linear_to_db(0.48)), "The capped combo gain returns after speech")
	check(float(Audio.word_jelly_combo_profile(100000).pitch) <= 2.0,
		"Very long streaks remain within the pitch ceiling")
	for interruption: String in ["pause", "mute", "halt", "unavailable"]:
		audio.interact("spring", false)
		audio.available = true
		audio.play_word_jelly_combo(8)
		match interruption:
			"pause": audio.stop_jelly_sounds()
			"mute": audio.set_muted(true)
			"halt": audio.halt()
			"unavailable":
				audio.available = false
				audio._process(0.01)
		check(_silent(audio) and audio._jelly_combo_next == 0, "%s clears all combo accents" % interruption)
		audio.set_muted(false)
		audio.available = true
		audio.interact("spring", false)
		check(_silent(audio), "Resuming cannot replay an old combo increment")
	audio.halt()
	audio.queue_free()
	await process_frame
	for interruption: String in ["pause", "mute", "halt"]:
		var delayed := DelayedComboAudio.new()
		root.add_child(delayed)
		delayed.interact("spring", false)
		delayed.delay_combo = true
		delayed.play_word_jelly_combo(8)
		check(_silent(delayed), "The delayed combo fixture is silent during resource preparation")
		match interruption:
			"pause": delayed.stop_jelly_sounds()
			"mute":
				delayed.set_muted(true)
				delayed.set_muted(false)
			"halt": delayed.halt()
		delayed.interact("spring", false)
		delayed.delay_combo = false
		delayed.combo_loaded.emit()
		await process_frame
		check(_silent(delayed) and delayed._jelly_cues.is_empty(), "A late combo resource cannot replay after %s" % interruption)
		delayed.play_jelly_cue("jelly-combo-1")
		check(delayed._jelly_combo_players[0].playing and is_equal_approx(delayed._jelly_combo_players[0].pitch_scale, 1.0),
			"A new streak restarts at the first pitch after cancellation")
		delayed.halt()
		delayed.queue_free()
		await process_frame
	await create_timer(0.15).timeout
	print("Word Jelly combo audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
