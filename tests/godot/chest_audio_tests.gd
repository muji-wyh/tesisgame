extends SceneTree

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
	await _check_progression_and_completion()
	await _check_cancellation_and_guards()
	# Let the audio mixing thread release stopped native playback instances.
	await create_timer(0.1).timeout
	print("Chest audio: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_progression_and_completion() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	check(audio.chest_charge == null and audio.get_child_count() == 4,
		"The charge channel and its samples are deferred until the first audible hold")
	audio.set_chest_charge(0.0)
	check(audio.chest_charge == null, "A hold cannot bypass the existing trusted-interaction audio gate")
	audio.interact("spring", false)
	audio.set_chest_charge(0.35)
	check(audio.chest_charge == null, "Only an explicit zero-progress start can arm charge audio")
	audio.set_chest_charge(0.0)
	var player: AudioStreamPlayer = audio.chest_charge
	var loop: AudioStreamWAV = audio._chest_charge_loop
	var accent: AudioStreamWAV = audio._chest_charge_accent
	check(player != null and player.playing and audio._chest_charge_active and player.stream == loop,
		"Starting a hold immediately plays its dedicated native loop")
	check(loop.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop.loop_end == loop.data.size() / 2,
		"The complete synthesized pulse and its silent tail repeat as one bounded loop")
	check(accent.loop_mode == AudioStreamWAV.LOOP_DISABLED and accent.get_length() < 0.5,
		"Completion uses a short non-looping accent")
	check(loop.data.size() + accent.data.size() < 32768 and audio._loading.is_empty(),
		"Both cached sounds total less than 32 KB and need no asynchronous loading")
	for entry: AudioStreamWAV in [loop, accent]:
		var maximum: int = 0
		for offset in range(0, entry.data.size(), 2):
			maximum = maxi(maximum, absi(entry.data.decode_s16(offset)))
		check(maximum > 2000 and maximum < 32767, "Synthesized audio contains audible, unclipped samples")
		check(entry.data.decode_s16(0) == 0 and absi(entry.data.decode_s16(entry.data.size() - 2)) <= 1,
			"Each sample has silent boundaries to avoid a start, finish or loop click")
	var start_pitch: float = player.pitch_scale
	var start_gain: float = player.volume_db
	var start_rate: float = start_pitch / loop.get_length()
	await create_timer(0.04).timeout
	var position: float = player.get_playback_position()
	audio.set_chest_charge(0.0)
	check(player.get_playback_position() >= position and player.stream == loop,
		"Repeated hold-start progress does not reset native playback")
	audio.set_chest_charge(0.5)
	var middle_pitch: float = player.pitch_scale
	var middle_gain: float = player.volume_db
	check(middle_pitch > start_pitch and middle_gain > start_gain,
		"Halfway through the actual hold, tone and intensity have increased")
	position = player.get_playback_position()
	for unused in range(20):
		audio.set_chest_charge(0.5)
	check(player.get_playback_position() >= position and is_equal_approx(player.pitch_scale, middle_pitch),
		"Duplicate progress updates preserve playback instead of stacking or replaying pulses")
	audio.set_chest_charge(0.2)
	check(is_equal_approx(player.pitch_scale, middle_pitch), "A delayed lower progress update cannot rewind the charge")
	audio.set_chest_charge(1.0)
	check(player.pitch_scale > middle_pitch and player.volume_db > middle_gain and player.pitch_scale / loop.get_length() > start_rate * 2.5,
		"The final hold builds to a higher, louder pulse at over twice the opening pace")
	audio.cue("spring-open")
	var open_stream: AudioStream = audio.effect.stream
	check(audio.effect.playing and open_stream != null, "The existing theme-open effect remains independently playable")
	audio.complete_chest_charge()
	check(not audio._chest_charge_active and audio._chest_charge_progress == -1.0 and player.playing and player.stream == accent,
		"Completing the active hold replaces its loop with one completion accent")
	check(audio.effect.playing and audio.effect.stream == open_stream,
		"The completion accent blends with the existing theme-open channel")
	await create_timer(0.04).timeout
	position = player.get_playback_position()
	audio.complete_chest_charge()
	audio.set_chest_charge(1.0)
	check(player.stream == accent and player.get_playback_position() >= position,
		"Repeated completion and late progress cannot replay or replace the completion accent")
	await create_timer(0.6).timeout
	check(not player.playing and player.stream == null, "The finite accent finishes without leaving a loop or queued playback")
	audio.set_chest_charge(0.0)
	check(audio._chest_charge_loop == loop and audio._chest_charge_accent == accent and audio.get_child_count() == 5,
		"The next hold reuses the same sample resources and single dedicated player")
	audio.stop_chest_charge()
	audio.queue_free()
	await process_frame


func _check_cancellation_and_guards() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	audio.interact("spring", false)
	audio.set_chest_charge(0.0)
	var player: AudioStreamPlayer = audio.chest_charge
	for reason in ["cancel", "mute", "halt", "unavailable"]:
		audio.available = true
		audio.set_muted(false)
		audio.interact("spring", false)
		audio.set_chest_charge(0.0)
		audio.set_chest_charge(0.8)
		match reason:
			"cancel": audio.stop_chest_charge()
			"mute": audio.set_muted(true)
			"halt": audio.halt()
			"unavailable":
				audio.available = false
				audio.set_chest_charge(0.9)
		check(not player.playing and player.stream == null and not audio._chest_charge_active,
			"The " + reason + " path immediately stops and detaches the charge audio")
		audio.available = true
		audio.set_muted(false)
		audio.interact("spring", false)
		audio.set_chest_charge(0.9)
		audio.complete_chest_charge()
		await process_frame
		check(not player.playing and player.stream == null,
			"Late progress or completion after " + reason + " cannot resurrect audio, even after another interaction")
	audio.set_chest_charge(0.0)
	audio.set_chest_charge(NAN)
	audio.set_chest_charge(INF)
	check(is_finite(player.pitch_scale) and is_finite(player.volume_db) and audio._chest_charge_progress == 0.0,
		"Non-finite progress cannot corrupt the native player's pitch or gain")
	audio.play_pip()
	var greeting: AudioStream = audio.voice.stream
	audio.cue("select")
	var effect: AudioStream = audio.effect.stream
	audio.stop_chest_charge()
	check(audio.voice.playing and audio.voice.stream == greeting and audio.effect.playing and audio.effect.stream == effect,
		"Canceling the dedicated charge leaves unrelated voice and effect playback intact")
	audio.set_chest_charge(0.0)
	audio.complete_chest_charge()
	audio.stop_chest_charge()
	check(not player.playing and player.stream == null, "Cancellation can also stop a completion accent immediately")
	audio.set_chest_charge(0.0)
	audio.complete_chest_charge()
	audio.set_muted(true)
	check(not player.playing and not audio.voice.playing and not audio.effect.playing,
		"Mute shuts down the accent and all pre-existing channels together")
	audio.set_muted(false)
	audio.interact("spring", false)
	audio.set_chest_charge(0.0)
	audio._chest_charge_finished()
	check(player.playing and player.stream == audio._chest_charge_loop,
		"A stale finished callback cannot detach a replacement hold loop")
	audio.queue_free()
	await process_frame
