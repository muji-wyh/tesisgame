extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")

class DelayedLevelAudio extends "res://scripts/game_audio.gd":
	signal level_loaded
	var delay_level: bool = false

	func _stream(path: String, loop: bool = false) -> AudioStream:
		if delay_level and path == JELLY_PATHS["jelly-collect-lv9"]:
			await level_loaded
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
	for player: AudioStreamPlayer in audio._jelly_level_players:
		if player.playing or player.stream != null:
			return false
	return true


func _run() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.play_jelly_cue("jelly-collect-lv9")
	check(audio._jelly_level_players.is_empty(), "Inactive level cues cannot allocate or queue playback")
	audio.interact("spring", false)
	for cue: String in ["danger", "merge", "pop"]:
		audio.play_jelly_cue(cue)
	var ordinary: Dictionary = {}
	for player: AudioStreamPlayer in audio._jelly_players:
		ordinary[player] = audio._playback_requests.get(player, 0)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/assets/jelly-level-feedback.json"))
	var hashes: Dictionary = {}
	for asset: Dictionary in manifest.audio:
		if int(asset.level) == 1:
			check(Audio.JELLY_PATHS.pop == "res://" + str(asset.path)
				and FileAccess.get_sha256(Audio.JELLY_PATHS.pop) == str(asset.sha256),
				"The approved Lv1 fixed bubble pop remains unchanged")
			continue
		var cue: String = str(asset.cue)
		audio.play_jelly_cue(cue)
		var player: AudioStreamPlayer = audio._jelly_level_players[posmod(audio._jelly_level_next - 1, Audio.JELLY_LEVEL_CHANNELS)]
		var stream: AudioStreamWAV = player.stream
		check(player.playing and stream.resource_path == Audio.JELLY_PATHS[cue]
			and stream.resource_path == "res://" + str(asset.path), "Lv%d plays its own acquired layered recording" % int(asset.level))
		check(is_equal_approx(player.pitch_scale, 1.0) and is_equal_approx(player.volume_db, linear_to_db(0.90)),
			"Lv%d retains authored pitch and shared gain" % int(asset.level))
		check(stream.format == AudioStreamWAV.FORMAT_16_BITS and not stream.stereo and stream.mix_rate == 44100
			and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Level audio imports as nonlooping mono PCM16")
		check(absf(stream.get_length() - float(asset.seconds)) < 0.00001, "Level recording retains its full measured tail")
		var hash: String = FileAccess.get_sha256(stream.resource_path)
		check(hash == str(asset.sha256) and not hashes.has(hash), "Every higher level has a distinct verified asset")
		hashes[hash] = true
	check(audio._jelly_level_players.size() == 8 and audio._jelly_players.size() == 3,
		"Eight protected level tails coexist with the original three-channel interaction pool")
	for player: AudioStreamPlayer in audio._jelly_level_players:
		check(player.playing, "All eight distinct level tails coexist before the pool wraps")
	for player: AudioStreamPlayer in ordinary:
		check(audio._playback_requests.get(player, 0) == ordinary[player],
			"Level celebrations cannot cut warnings, merge feedback or the ordinary bubble pop")
	var levels: Dictionary = {}
	for player: AudioStreamPlayer in audio._jelly_level_players:
		levels[player] = audio._playback_requests.get(player, 0)
	for cue: String in ["pick", "contact", "release", "land", "merge", "danger"]:
		audio.play_jelly_cue(cue)
	for player: AudioStreamPlayer in levels:
		check(audio._playback_requests.get(player, 0) == levels[player],
			"Board interaction cannot steal a long collection tail")
	audio.say("res://assets/audio/voice/word-cat.wav")
	audio._process(0.01)
	for player: AudioStreamPlayer in audio._jelly_level_players:
		check(is_equal_approx(player.volume_db, linear_to_db(0.90) - 6.0), "Level tails duck six decibels beneath pronunciation")
	var spoken: AudioStream = audio.voice.stream
	audio.play_jelly_cue("jelly-collect-lv9")
	check(audio.voice.playing and audio.voice.stream == spoken, "A new high-level cue preserves spoken vocabulary")
	audio.stop_voice()
	audio._process(0.01)
	for player: AudioStreamPlayer in audio._jelly_level_players:
		check(is_equal_approx(player.volume_db, linear_to_db(0.90)), "Normal level gain returns after speech")
	audio.stop_jelly_danger()
	check(not _silent(audio), "Selective danger cancellation does not silence collection tails")
	for interruption: String in ["pause", "mute", "halt", "unavailable"]:
		audio.interact("spring", false)
		audio.available = true
		audio.play_jelly_cue("jelly-collect-lv9")
		match interruption:
			"pause": audio.stop_jelly_sounds()
			"mute": audio.set_muted(true)
			"halt": audio.halt()
			"unavailable":
				audio.available = false
				audio._process(0.01)
		check(_silent(audio) and audio._jelly_level_next == 0, "%s clears every level tail and resets its pool" % interruption)
		if interruption != "pause":
			audio.play_jelly_cue("jelly-collect-lv9")
			check(_silent(audio) and audio._jelly_level_next == 0, "Suppressed level events never enqueue playback")
		audio.set_muted(false)
		audio.available = true
		audio.interact("spring", false)
		check(_silent(audio), "Resuming after %s cannot replay old level cues" % interruption)
		audio.play_jelly_cue("jelly-collect-lv4")
		check(audio._jelly_level_players[0].playing and audio._jelly_level_players[0].stream.resource_path == Audio.JELLY_PATHS["jelly-collect-lv4"],
			"Only a new accepted event restarts its level cue after %s" % interruption)
	audio.halt()
	audio.queue_free()
	await process_frame
	await _pending()
	# Let the audio mixer release stopped playback references before shutdown.
	await create_timer(0.15).timeout
	print("Word Jelly level audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _pending() -> void:
	for interruption: String in ["pause", "mute", "halt"]:
		var audio := DelayedLevelAudio.new()
		root.add_child(audio)
		audio.interact("spring", false)
		audio.delay_level = true
		audio.play_jelly_cue("jelly-collect-lv9")
		check(_silent(audio), "Delayed level fixture is silent before resource preparation")
		match interruption:
			"pause": audio.stop_jelly_sounds()
			"mute":
				audio.set_muted(true)
				audio.set_muted(false)
			"halt": audio.halt()
		audio.interact("spring", false)
		audio.delay_level = false
		audio.level_loaded.emit()
		await process_frame
		check(_silent(audio) and audio._jelly_cues.is_empty(), "A pending level recording cannot replay after %s" % interruption)
		audio.play_jelly_cue("jelly-collect-lv9")
		var player: AudioStreamPlayer = audio._jelly_level_players[0]
		check(player.playing and player.stream.resource_path == Audio.JELLY_PATHS["jelly-collect-lv9"] and is_equal_approx(player.pitch_scale, 1.0),
			"A fresh high-level collection works after canceling the delayed request")
		audio.halt()
		audio.queue_free()
		await process_frame
