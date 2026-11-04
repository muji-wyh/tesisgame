extends SceneTree

const MapPipAudio = preload("res://scripts/word_jelly_map_pip_audio.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _resources_released(references: Array[WeakRef]) -> bool:
	for reference: WeakRef in references:
		if reference.get_ref() != null:
			return false
	return true


func _run() -> void:
	var audio = MapPipAudio.new()
	root.add_child(audio)
	await process_frame
	var teardown_refs: Array[WeakRef] = [weakref(audio._snore.stream), weakref(audio._wake.stream)]
	check(audio._snore.stream != null and audio._wake.stream != null,
		"Both map-only character cues load from acquired production audio assets")
	check(is_equal_approx(audio._snore.stream.get_length(), 0.6),
		"The acquired short cartoon snore keeps its complete authored envelope")
	audio.set_sleeping(true)
	audio.pulse_snore()
	check(audio.snapshot().snore_requests == 0, "A muted or inactive map cannot start a snore")
	audio.set_enabled(true)
	check(audio.snapshot().snore_requests == 0, "Enabling sound does not replay a missed sleeping pulse")
	audio.pulse_snore()
	audio.pulse_snore()
	teardown_refs.append(weakref(audio._snore.get_stream_playback()))
	check(audio.snapshot().snore_requests == 1 and audio._snore.playing,
		"The real sleep timeline can start a snore without overlapping duplicate pulses")
	audio.wake()
	teardown_refs.append(weakref(audio._wake.get_stream_playback()))
	check(not audio.snapshot().sleeping and not audio._snore.playing
		and audio.snapshot().wake_requests == 1 and audio._wake.playing,
		"Hover cuts off the snore and starts exactly one short startled peep")
	audio.wake()
	audio.pulse_snore()
	check(audio.snapshot().wake_requests == 1 and audio.snapshot().snore_requests == 1,
		"Repeated awake input cannot queue more peeps or snores")
	audio.set_enabled(false)
	check(not audio._snore.playing and not audio._wake.playing,
		"Muting or backgrounding stops both one-shot players immediately")
	audio.set_sleeping(true)
	audio.wake()
	check(audio.snapshot().wake_requests == 1 and not audio.snapshot().sleeping,
		"Waking while muted still updates state without saving an audible event")
	audio.set_enabled(true)
	check(not audio._wake.playing and not audio._snore.playing,
		"Unmuting does not resurrect an interrupted cue")
	audio.set_sleeping(true)
	audio.pulse_snore()
	teardown_refs.append(weakref(audio._snore.get_stream_playback()))
	audio.stop()
	check(not audio.snapshot().sleeping and not audio._snore.playing and not audio._wake.playing,
		"Closing the map discards its complete audio state")
	check(not audio.is_processing() and audio.get_child_count() == 2,
		"Character audio uses two reusable one-shot players without a frame loop")
	audio._snore.stream = null
	audio._wake.stream = null
	audio.free()
	# AudioServer releases interrupted playback on a later mix, not on stop().
	# Observe all playback and stream references instead of assuming a fixed delay.
	var cleanup_deadline: int = Time.get_ticks_msec() + 2000
	while not _resources_released(teardown_refs) and Time.get_ticks_msec() < cleanup_deadline:
		await create_timer(0.01).timeout
	check(_resources_released(teardown_refs), "Mixer teardown releases every interrupted playback and its audio stream")
	await process_frame
	print("Map Pip audio: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
