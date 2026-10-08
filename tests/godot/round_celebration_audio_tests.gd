extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")
const CUE_PATHS := {
	"step": "res://assets/imported-audio/chest-reference/step.wav",
	"step-detail": "res://assets/imported-audio/chest-reference/step-detail.wav",
	"reward": "res://assets/imported-audio/chest-reference/reward.wav",
}
const CUE_GAINS := {"step": 0.32, "step-detail": 0.28, "reward": 0.44}

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _playing(audio) -> int:
	var count := 0
	for player: AudioStreamPlayer in audio._round_celebration_players:
		count += int(player.playing)
	return count


func _last_player(audio) -> AudioStreamPlayer:
	return audio._round_celebration_players[(audio._round_celebration_next_player + 1) % 2]


func _chest_state(audio) -> Array:
	return [audio._chest_phase, audio._chest_rewarded, audio._chest_motion_finished,
		audio._chest_seen.duplicate(), audio._chest_theme, audio._chest_music_duck]


func _run() -> void:
	await _check_independent_presentation()
	await _check_cue_guards()
	await _check_speech_mix()
	await _check_interruption()
	await _check_missing_recording()
	# Give the audio thread a buffer to retire stopped playback resources.
	await create_timer(0.15).timeout
	print("Round celebration audio: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_independent_presentation() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.interact("spring")
	audio.cue("select")
	audio.play_pair_feedback(true)
	var effect_request: int = audio._playback_requests[audio.effect]
	var answer_request: int = audio._playback_requests[audio.pair_feedback]
	var original_music_gain: float = audio.music.volume_db
	var original_chest_state: Array = _chest_state(audio)
	var pip_random: int = audio._pip_rng.state
	var pop_random: int = audio._pop_slice_rng.state
	var initial_channels: int = audio.get_child_count()
	audio.begin_round_celebration("round-a")
	check(is_equal_approx(audio.music.volume_db, original_music_gain - 6.0),
		"The round presentation ducks existing music by exactly six decibels")
	check(audio._round_celebration_players.is_empty() and audio.get_child_count() == initial_channels,
		"Preparing a round makes no sound and does not allocate playback channels")
	for cue: String in CUE_PATHS:
		audio.play_round_celebration_cue("round-a", cue)
		var player: AudioStreamPlayer = _last_player(audio)
		check(player.playing and player.stream == load(CUE_PATHS[cue]) and player.pitch_scale == 1.0,
			"The " + cue + " beat immediately uses the complete existing recording at its original pitch")
		check(is_equal_approx(player.volume_db, linear_to_db(float(CUE_GAINS[cue]))),
			"The " + cue + " beat uses its authored unducked gain without speech")
	check(audio._round_celebration_players.size() == 2 and audio.get_child_count() == initial_channels + 2,
		"Three cue events share two fixed players")
	check(audio._playback_requests[audio.effect] == effect_request
		and audio._playback_requests[audio.pair_feedback] == answer_request,
		"Celebration does not replace a card effect or the final correct-answer acknowledgement")
	check(audio.pip_reaction == null and not audio.voice.playing
		and audio._pip_rng.state == pip_random and audio._pop_slice_rng.state == pop_random,
		"Celebration introduces no quack or narration and consumes no gameplay sound randomness")
	check(_chest_state(audio) == original_chest_state and audio._chest_players.is_empty(),
		"The earned-chest cue cannot open a chest, acknowledge a save or allocate chest sound channels")
	audio.stop_round_celebration()
	check(_playing(audio) == 0 and audio._round_celebration_players.all(
		func(player: AudioStreamPlayer) -> bool: return player.stream == null),
		"Finishing the presentation stops both players and releases their streams")
	check(is_equal_approx(audio.music.volume_db, original_music_gain) and audio.music.playing,
		"Finishing restores the music mix without restarting its playback")
	audio.queue_free()
	await process_frame


func _check_cue_guards() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.interact("spring", false)
	audio.play_round_celebration_cue("round-a", "reward")
	check(audio._round_celebration_players.is_empty(), "A cue cannot arm its own presentation")
	audio.begin_round_celebration("round-a")
	audio.play_round_celebration_cue("round-a", "step")
	var player: AudioStreamPlayer = _last_player(audio)
	var request: int = audio._playback_requests[player]
	var next_player: int = audio._round_celebration_next_player
	for index in range(12):
		audio.begin_round_celebration("round-a")
		audio.play_round_celebration_cue("round-a", "step")
		audio.play_round_celebration_cue("stale-round", "reward")
		audio.play_round_celebration_cue("round-a", "release")
	check(audio._playback_requests[player] == request and audio._round_celebration_next_player == next_player,
		"Repeated begin/cue events, stale round IDs and chest-opening names cannot replay a beat")
	check(audio._round_celebration_seen == {"step": true}, "Only accepted timeline beats are consumed")
	audio.begin_round_celebration("round-b")
	check(_playing(audio) == 0 and audio._round_celebration_seen.is_empty(),
		"A different round invalidates the old presentation before arming new cues")
	audio.play_round_celebration_cue("round-a", "reward")
	check(_playing(audio) == 0, "An old round cannot inject a sound into the new round")
	audio.play_round_celebration_cue("round-b", "reward")
	check(_playing(audio) == 1, "A new round can reveal its chest once")
	audio.stop_round_celebration()
	audio.play_round_celebration_cue("round-b", "step-detail")
	check(_playing(audio) == 0, "A late cue cannot revive a finished presentation")
	audio.begin_round_celebration("round-b")
	audio.play_round_celebration_cue("round-b", "step-detail")
	check(_playing(audio) == 1 and audio._round_celebration_seen == {"step-detail": true},
		"An explicit resumed begin accepts remaining cues without automatically replaying earlier beats")
	for index in range(20):
		var round_id: String = "bounded-%d" % index
		audio.begin_round_celebration(round_id)
		for cue: String in CUE_PATHS:
			audio.play_round_celebration_cue(round_id, cue)
	check(audio._round_celebration_players.size() == 2 and _playing(audio) <= 2,
		"Repeated rounds retain a bounded two-channel overlap")
	check(not audio.music.playing, "Celebration never starts music in a microphone-friendly session")
	audio.queue_free()
	await process_frame


func _check_speech_mix() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.interact("spring")
	audio.begin_round_celebration("speech-round")
	audio.play_round_celebration_cue("speech-round", "reward")
	var player: AudioStreamPlayer = _last_player(audio)
	var base_gain: float = player.volume_db
	var cue_request: int = audio._playback_requests[player]
	audio.say("res://assets/audio/voice/word-apple.wav")
	var voice_request: int = audio._playback_requests[audio.voice]
	check(audio.voice.playing and is_equal_approx(player.volume_db, base_gain - 8.0),
		"Actual word playback immediately lowers an already-playing celebration cue by eight decibels")
	check(is_equal_approx(audio.music.volume_db, linear_to_db(0.04) - 6.0),
		"The existing speech music balance composes with the celebration music reduction")
	audio.play_round_celebration_cue("speech-round", "step")
	var step_player: AudioStreamPlayer = _last_player(audio)
	check(is_equal_approx(step_player.volume_db, linear_to_db(0.32) - 8.0)
		and audio._playback_requests[audio.voice] == voice_request and audio.voice.playing,
		"A cue beginning during pronunciation is ducked and leaves pronunciation uninterrupted")
	audio.stop_voice()
	check(is_equal_approx(player.volume_db, base_gain)
		and audio._playback_requests[player] == cue_request,
		"Stopping pronunciation restores the cue gain without replaying the cue")
	# Use a short real recording on the voice channel to check its natural end.
	audio.say("res://assets/imported-audio/ui-click/select.wav")
	check(is_equal_approx(player.volume_db, base_gain - 8.0), "A new voice playback reinstates the speech mix")
	await create_timer(0.25).timeout
	check(not audio.voice.playing and is_equal_approx(player.volume_db, base_gain),
		"A natural voice ending restores the celebration cue mix")
	audio.say("res://assets/audio/voice/word-apple.wav")
	voice_request = audio._playback_requests[audio.voice]
	audio.stop_round_celebration()
	check(audio.voice.playing and audio._playback_requests[audio.voice] == voice_request
		and is_equal_approx(audio.music.volume_db, linear_to_db(0.04)),
		"Finishing while a word speaks preserves that word and restores only the celebration music reduction")
	audio.queue_free()
	await process_frame


func _check_interruption() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	for reason: String in ["inactive", "muted", "unavailable"]:
		audio.active = reason != "inactive"
		audio.muted = reason == "muted"
		audio.available = reason != "unavailable"
		audio.begin_round_celebration("blocked")
		audio.play_round_celebration_cue("blocked", "reward")
		check(audio._round_celebration_id.is_empty() and audio._round_celebration_players.is_empty(),
			"An " + reason + " session cannot arm or allocate celebration audio")
	for reason: String in ["mute", "halt", "inactive", "unavailable", "stop"]:
		audio.muted = false
		audio.available = true
		audio.interact("spring")
		audio.begin_round_celebration(reason)
		audio.play_round_celebration_cue(reason, "reward")
		match reason:
			"mute": audio.set_muted(true)
			"halt": audio.halt()
			"inactive": audio.active = false
			"unavailable": audio.available = false
			"stop": audio.stop_round_celebration()
		audio._process(0.016)
		check(_playing(audio) == 0 and audio._round_celebration_id.is_empty()
			and not audio.is_processing(), "The " + reason + " pathway stops audio and its idle processing")
		check(is_equal_approx(audio.music.volume_db, linear_to_db(0.12)),
			"The " + reason + " pathway removes the celebration music reduction")
		audio.set_muted(false)
		audio.available = true
		audio.interact("winter", false)
		audio.play_round_celebration_cue(reason, "step")
		check(_playing(audio) == 0, "Resuming after " + reason + " does not replay the interrupted round")
	audio.queue_free()
	await process_frame


func _check_missing_recording() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.interact("spring", false)
	for path: String in CUE_PATHS.values():
		audio.cache[path] = null
	audio.begin_round_celebration("missing")
	for cue: String in CUE_PATHS:
		audio.play_round_celebration_cue("missing", cue)
	check(_playing(audio) == 0 and audio._round_celebration_seen.size() == 3,
		"Unavailable recordings leave cue progress intact without adding a generated sound or retry queue")
	check(audio._chest_players.is_empty() and audio.pip_reaction == null,
		"Missing celebration audio does not fall back to a chest save cue or a quack")
	audio.stop_round_celebration()
	check(audio._round_celebration_id.is_empty() and is_equal_approx(audio.music.volume_db, linear_to_db(0.12)),
		"A silent performance still stops and restores its mix normally")
	audio.queue_free()
	await process_frame
