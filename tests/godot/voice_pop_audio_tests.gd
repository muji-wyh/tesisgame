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
	await _check_launch()
	await _check_bank_and_overlap()
	await _check_lifecycle_and_fallback()
	await create_timer(0.15).timeout
	print("Voice Pop reference audio: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_launch() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	check(audio.pop_launch != null and audio.cache.has(audio._pop_launch_path),
		"The dedicated launch channel and its local recording are ready before listening")
	for blocked in ["inactive", "muted", "unavailable"]:
		audio.active = blocked != "inactive"
		audio.muted = blocked == "muted"
		audio.available = blocked != "unavailable"
		audio.cue("pop-launch")
		check(not audio.pop_launch.playing, "An " + blocked + " throw stays silent")
	audio.muted = false
	audio.available = true
	audio.interact("spring", false)
	audio.cue("pop-launch")
	var stream: AudioStreamWAV = audio.pop_launch.stream
	check(audio.pop_launch.playing and stream != null and not stream.stereo and stream.mix_rate == 44100
		and stream.get_length() >= 0.1 and stream.get_length() <= 0.3
		and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED,
		"A thrown word has a short standalone mono whoosh")
	check(is_equal_approx(audio.pop_launch.pitch_scale, 1.0)
		and is_equal_approx(db_to_linear(audio.pop_launch.volume_db), 0.16),
		"The launch uses its authored pitch at a quieter gain than a cut")
	var request: int = audio._playback_requests[audio.pop_launch]
	audio.cue("pop-slice")
	check(audio.pop_launch.playing and audio._playback_requests[audio.pop_launch] == request,
		"A successful cut never truncates the separate launch recording")
	audio.stop_pop_sounds()
	check(not audio.pop_launch.playing and audio.pop_launch.stream == null
		and audio.last_pop_player() == null, "Stopping Pop clears both launch and cut tails")
	audio._pop_launch_path = Audio.POP_LAUNCH_FALLBACK
	audio.cue("pop-launch")
	check(audio.pop_launch.playing and audio.pop_launch.stream == load(Audio.POP_LAUNCH_FALLBACK),
		"A clean checkout has a locally bundled launch sound without private source audio")
	audio.halt()
	audio.queue_free()
	await process_frame


func _check_bank_and_overlap() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	check(audio._pop_players.size() == 3 and audio.last_pop_player() == null,
		"Three fixed hit channels are prepared before the first recognized word")
	var reference: Array[String] = []
	for path: String in Audio.POP_REFERENCE_PATHS:
		if ResourceLoader.exists(path):
			var stream: AudioStreamWAV = load(path)
			check(stream != null and not stream.stereo and stream.mix_rate == 44100
				and stream.get_length() >= 0.27 and stream.get_length() <= 0.33
				and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED,
				"Each local reference hit is a short, unlooped mono PCM resource")
			reference.append(path)
	if reference.size() == 3:
		check(audio._pop_slice_paths == reference,
			"The complete reference bank takes priority over the previous slice bank")
		check(reference.all(func(path: String) -> bool: return audio.cache.has(path)),
			"All reference streams are ready in the local cache before playback")
	else:
		check(audio._pop_slice_paths.all(func(path: String) -> bool: return path in Audio.POP_SLICE_PATHS),
			"An absent or incomplete reference bank preserves the previous playable slices")
	audio.interact("spring", false)
	audio.cue("select")
	var effect_stream: AudioStream = audio.effect.stream
	var effect_request: int = audio._playback_requests[audio.effect]
	var requests: Array[int] = []
	var last_paths: Array[String] = []
	for index in range(3):
		audio.cue("pop-slice")
		var player: AudioStreamPlayer = audio.last_pop_player()
		check(player == audio._pop_players[index] and player.playing and player.stream != null,
			"A burst starts each hit on its own already allocated channel")
		check(is_equal_approx(player.pitch_scale, 1.0) and is_equal_approx(db_to_linear(player.volume_db), 0.24),
			"Premixed blade and impact play at the authored rate with bounded gain")
		requests.append(audio._playback_requests[player])
		last_paths.append(player.stream.resource_path)
		for previous in range(index):
			check(audio._pop_players[previous].playing
				and audio._playback_requests[audio._pop_players[previous]] == requests[previous],
				"The next hit does not truncate any earlier hit until all channels are occupied")
	var child_count: int = audio.get_child_count()
	audio.cue("pop-slice")
	check(audio.last_pop_player() == audio._pop_players[0]
		and audio._playback_requests[audio._pop_players[0]] == requests[0] + 1,
		"A fourth simultaneous hit replaces only the oldest channel")
	for index in [1, 2]:
		check(audio._pop_players[index].playing and audio._playback_requests[audio._pop_players[index]] == requests[index],
			"The remaining two hits retain their natural tails at channel capacity")
	check(audio.effect.stream == effect_stream and audio.effect.playing
		and audio._playback_requests[audio.effect] == effect_request,
		"A blade hit never replaces an ordinary interface effect")
	seed(30519)
	var expected_global: int = randi()
	seed(30519)
	var last_path: String = audio._last_pop_slice_path
	var all_distinct := true
	for index in range(128):
		audio.cue("pop-slice")
		if audio._pop_slice_paths.size() > 1:
			all_distinct = all_distinct and audio._last_pop_slice_path != last_path
		last_path = audio._last_pop_slice_path
	check(all_distinct and randi() == expected_global,
		"Repeated cuts vary without consuming gameplay randomness or immediately repeating")
	check(audio.get_child_count() == child_count and not audio.music.playing
		and not audio.voice.playing and not audio.narration.playing,
		"A long burst stays bounded without starting speech or microphone-competing music")
	audio.queue_free()
	await process_frame


func _check_lifecycle_and_fallback() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	for blocked in ["inactive", "muted", "unavailable"]:
		audio.active = blocked != "inactive"
		audio.muted = blocked == "muted"
		audio.available = blocked != "unavailable"
		var state: int = audio._pop_slice_rng.state
		audio.cue("pop-slice")
		check(audio.last_pop_player() == null and state == audio._pop_slice_rng.state,
			"An " + blocked + " game neither plays nor consumes the next cut")
	audio.muted = false
	audio.available = true
	audio.interact("spring", false)
	for index in range(3):
		audio.cue("pop-slice")
	var requests: Array[int] = []
	for player: AudioStreamPlayer in audio._pop_players:
		requests.append(audio._playback_requests[player])
	audio.set_muted(true)
	for index in range(3):
		var player: AudioStreamPlayer = audio._pop_players[index]
		check(not player.playing and player.stream == null and audio._playback_requests[player] > requests[index],
			"Mute stops every tail and invalidates every pending hit request")
	check(audio.last_pop_player() == null and audio._pop_next_player == 0,
		"Stopped rounds retain no pending slice or replay cursor")
	audio.set_muted(false)
	audio.interact("autumn", false)
	check(audio._pop_players.all(func(player: AudioStreamPlayer) -> bool: return not player.playing),
		"Resuming a mode never replays hits from the previous round")
	audio._pop_slice_paths.clear()
	var state: int = audio._pop_slice_rng.state
	audio.cue("pop-slice")
	var fallback: String = Audio.POP_SLICE_PATH if ResourceLoader.exists(Audio.POP_SLICE_PATH) else "res://assets/audio/sfx/select.wav"
	check(audio.last_pop_player().playing and audio.last_pop_player().stream == load(fallback)
		and state == audio._pop_slice_rng.state,
		"A source checkout without either slice bank remains audible without drawing a missing resource")
	audio.halt()
	check(not audio.active and audio._pop_players.all(func(player: AudioStreamPlayer) -> bool:
		return not player.playing and player.stream == null),
		"The shared page-hide and mode-exit halt stops every slice channel")
	audio.queue_free()
	await process_frame
