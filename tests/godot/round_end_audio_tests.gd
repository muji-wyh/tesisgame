extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	check(audio.has_method("play_round_end") and audio.has_method("stop_round_end"),
		"Game over has a dedicated acquired audio cue with explicit interruption cleanup")
	if audio.has_method("play_round_end"):
		audio.interact("spring", false)
		for failed: bool in [false, true]:
			audio.call("play_round_end", failed)
			await process_frame
			var player = audio.get("round_end")
			var expected: String = Audio.MEMORY_CHEST_LOSS_PATHS[true] if failed else Audio.WORD_JELLY_COMBO_PATHS[2]
			check(player != null and player.playing and player.stream.resource_path == expected,
				"Timeout and ordinary completion use different existing production recordings")
			if player != null:
				check(player.stream.get_length() > 0.20 and player.pitch_scale == 1.0,
					"The complete authored end recording plays at its original pitch")
				audio.stop_jelly_sounds()
				check(player.playing, "Pausing the finished Jelly board does not immediately cut off its end cue")
				audio.halt()
				check(not player.playing and player.stream == null, "Navigation cancels the end cue and its resource")
				audio.interact("spring", false)
				check(not player.playing, "Returning to the page cannot replay an old end cue")
		audio.call("play_round_end", true)
		await process_frame
		audio.set_muted(true)
		var player = audio.get("round_end")
		check(player != null and not player.playing and player.stream == null,
			"Muting stops the end cue through the shared audio lifecycle")
	audio.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Round end audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
