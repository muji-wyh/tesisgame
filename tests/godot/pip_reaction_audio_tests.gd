extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")
const HAPPY_PATH := "res://assets/audio/pip/duck_double_01_bouncy.wav"
const SAD_PATH := "res://assets/audio/pip/duck_quack_innocent_deep_short_04.wav"

class DelayedAudio extends "res://scripts/game_audio.gd":
	signal released
	var resolved: Dictionary = {}
	var downloads: Array[String] = []

	func _download(url: String) -> Resource:
		downloads.append(url)
		while not resolved.has(url):
			await released
		return resolved[url]

	func resolve(url: String, resource: Resource) -> void:
		resolved[url] = resource
		released.emit()

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
	await _check_reaction_channel()
	await _check_cancellation()
	await _check_delayed_reactions()
	# The audio mixer retires stopped playback objects on its next buffer.
	await create_timer(0.15).timeout
	print("Pip reaction audio: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_reaction_channel() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	check(audio.pip_reaction == null, "Gameplay reaction playback is allocated only when needed")
	audio.interact("spring", false)
	audio.cue("select")
	audio.say("res://assets/audio/voice/word-apple.wav")
	var word_stream: AudioStream = audio.voice.stream
	var effect_stream: AudioStream = audio.effect.stream
	var word_request: int = audio._playback_requests[audio.voice]
	var effect_request: int = audio._playback_requests[audio.effect]
	var pip_state: int = audio._pip_rng.state
	var pop_state: int = audio._pop_slice_rng.state
	seed(84063)
	var expected_random: int = randi()
	seed(84063)
	audio.play_pip_reaction(true)
	check(audio.pip_reaction.playing and audio.pip_reaction.stream == load(HAPPY_PATH)
		and audio.pip_reaction.pitch_scale > 1.0,
		"A correct result plays the bright bouncy double quack immediately")
	check(audio.voice.playing and audio.voice.stream == word_stream and audio.effect.playing
		and audio.effect.stream == effect_stream and audio._playback_requests[audio.voice] == word_request
		and audio._playback_requests[audio.effect] == effect_request,
		"The reaction preserves the selected word and feedback sound on their existing channels")
	check(not audio.music.playing and not audio.narration.playing,
		"A reaction in microphone-friendly playback never starts music or spoken narration")
	var happy_gain: float = audio.pip_reaction.volume_db
	var players: Array[Node] = audio.get_children()
	var reaction_player: AudioStreamPlayer = audio.pip_reaction
	for index in range(24):
		audio.play_pip_reaction(index % 2 == 0)
	check(audio.get_children() == players and audio.pip_reaction == reaction_player
		and audio.pip_reaction.playing and audio.pip_reaction.stream == load(SAD_PATH),
		"Rapid results replace one bounded reaction channel with the latest emotion")
	check(audio.pip_reaction.pitch_scale < 1.0 and audio.pip_reaction.volume_db < happy_gain,
		"A missed result has a lower, softer quack than the happy reaction")
	check(randi() == expected_random and audio._pip_rng.state == pip_state and audio._pop_slice_rng.state == pop_state,
		"Emotional quacks do not consume greeting, fruit sound or gameplay randomness")
	var reaction_request: int = audio._playback_requests[audio.pip_reaction]
	audio.say("res://assets/audio/voice/word-banana.wav")
	audio.cue("select")
	check(audio.pip_reaction.playing and audio._playback_requests[audio.pip_reaction] == reaction_request,
		"The next card pronunciation and selection cue cannot cut off the current quack")
	audio.stop_pip_reaction()
	check(not audio.pip_reaction.playing and audio.pip_reaction.stream == null
		and audio.voice.playing and audio.effect.playing,
		"Stopping the reaction leaves ordinary card audio intact")
	var narration_paths: Array[String] = ["res://assets/audio/voice/word-apple.wav"]
	audio.narrate(narration_paths)
	var narration_stream: AudioStream = audio.narration.stream
	var narration_generation: int = audio._narration_generation
	audio.play_pip_reaction(true)
	check(audio.narration.playing and audio.narration.stream == narration_stream
		and audio._narration_generation == narration_generation and audio.narration_state == "speaking",
		"A reaction never cancels or rewinds an active report sentence")
	check(audio.pip_reaction.stream.get_length() / audio.pip_reaction.pitch_scale < 0.5,
		"The happy quack stays brief enough for continuous Voice Pop listening")
	audio.play_pip_reaction(false)
	check(audio.pip_reaction.stream.get_length() / audio.pip_reaction.pitch_scale < 0.5,
		"The sad quack also stays brief enough for continuous Voice Pop listening")
	audio.queue_free()
	await process_frame


func _check_cancellation() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	for blocked in ["inactive", "muted", "unavailable"]:
		audio.active = blocked != "inactive"
		audio.muted = blocked == "muted"
		audio.available = blocked != "unavailable"
		audio.play_pip_reaction(true)
		check(audio.pip_reaction == null, "An " + blocked + " game does not allocate or play a reaction")
	audio.muted = false
	audio.available = true
	audio.interact("spring", false)
	audio.play_pip_reaction(false)
	audio.set_muted(true)
	check(not audio.active and not audio.pip_reaction.playing and audio.pip_reaction.stream == null,
		"Mute immediately stops a playing reaction")
	audio.set_muted(false)
	check(not audio.pip_reaction.playing, "Unmuting does not replay an old reaction")
	audio.interact("spring", false)
	audio.play_pip_reaction(true)
	audio.halt()
	check(not audio.active and not audio.pip_reaction.playing and audio.pip_reaction.stream == null,
		"The common page, round and mode halt stops the reaction")
	audio.interact("winter", false)
	check(not audio.pip_reaction.playing, "Starting the destination mode cannot revive the old reaction")
	audio.queue_free()
	await process_frame


func _check_delayed_reactions() -> void:
	var audio := DelayedAudio.new()
	root.add_child(audio)
	audio.remote_audio[HAPPY_PATH] = "test://happy"
	audio.remote_audio[SAD_PATH] = "test://sad"
	audio.interact("spring", false)
	audio.play_pip_reaction(true)
	audio.play_pip_reaction(true)
	check(not audio.pip_reaction.playing and audio.downloads == ["test://happy"],
		"Repeated reactions share an optional download without stacking playback")
	audio.halt()
	audio.interact("winter", false)
	audio.resolve("test://happy", load(HAPPY_PATH))
	await process_frame
	check(audio.cache.has(HAPPY_PATH) and not audio.pip_reaction.playing,
		"A download completed after mode change is cached without reviving a stale quack")
	audio.play_pip_reaction(false)
	audio.play_pip_reaction(true)
	var happy_stream: AudioStream = audio.pip_reaction.stream
	var happy_request: int = audio._playback_requests[audio.pip_reaction]
	audio.resolve("test://sad", load(SAD_PATH))
	await process_frame
	check(audio.pip_reaction.playing and audio.pip_reaction.stream == happy_stream
		and audio.pip_reaction.pitch_scale > 1.0 and audio._playback_requests[audio.pip_reaction] == happy_request,
		"An older sad download cannot overwrite the newer happy reaction")
	audio.queue_free()
	await process_frame

	var muted_audio := DelayedAudio.new()
	root.add_child(muted_audio)
	muted_audio.remote_audio[HAPPY_PATH] = "test://muted"
	muted_audio.interact("spring", false)
	muted_audio.play_pip_reaction(true)
	muted_audio.set_muted(true)
	muted_audio.set_muted(false)
	muted_audio.interact("spring", false)
	muted_audio.resolve("test://muted", load(HAPPY_PATH))
	await process_frame
	check(not muted_audio.pip_reaction.playing, "Mute invalidates a download even if playback is enabled before it finishes")
	muted_audio.queue_free()
	await process_frame

	var failed_audio := DelayedAudio.new()
	root.add_child(failed_audio)
	failed_audio.remote_audio[HAPPY_PATH] = "test://failed"
	failed_audio.interact("spring", false)
	failed_audio.say("res://assets/audio/voice/word-apple.wav")
	var word: AudioStream = failed_audio.voice.stream
	var word_failures: Array[bool] = []
	failed_audio.word_failed.connect(func() -> void: word_failures.append(true))
	failed_audio.play_pip_reaction(true)
	failed_audio.resolve("test://failed", null)
	await process_frame
	check(failed_audio.active and not failed_audio.pip_reaction.playing
		and failed_audio.voice.playing and failed_audio.voice.stream == word and word_failures.is_empty(),
		"A missing reaction does not stop card speech or report a failed vocabulary recording")
	failed_audio.remote_audio.erase(HAPPY_PATH)
	failed_audio.play_pip_reaction(true)
	check(failed_audio.pip_reaction.playing, "The next result can retry after an optional reaction download fails")
	failed_audio.queue_free()
	await process_frame
