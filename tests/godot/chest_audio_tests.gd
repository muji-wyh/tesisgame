extends SceneTree

const Bank = preload("res://scripts/chest_sound_bank.gd")

class DelayedAudio:
	extends "res://scripts/game_audio.gd"
	signal release_download
	var download_count: int = 0
	var downloaded: AudioStreamWAV

	func _download(_url: String) -> Resource:
		download_count += 1
		await release_download
		return downloaded

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
	var count: int = int(audio.chest_charge != null and audio.chest_charge.playing)
	for player: AudioStreamPlayer in audio._chest_players:
		count += int(player.playing)
	return count


func _last_player(audio) -> AudioStreamPlayer:
	return audio._chest_players[(audio._chest_next_player + 2) % 3]


func _run() -> void:
	await _check_material_assets()
	await _check_performance()
	await _check_tension_rhythm()
	await _check_tension_interruption()
	await _check_motion_completion_before_save()
	await _check_cancellation_and_guards()
	await _check_delayed_preparation()
	await _check_saved_retry()
	# Give the native audio mixing thread time to retire stopped playback even
	# while other scene tests or movie captures are using the same machine.
	await create_timer(0.25).timeout
	print("Chest audio: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_material_assets() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	var fingerprints: Dictionary = {}
	var total_bytes: int = 0
	for theme: String in Bank.THEMES:
		audio.prepare_chest(theme)
		for cue_name: String in Bank.CUES:
			var path: String = Bank.path_for(theme, cue_name)
			var source: PackedByteArray = FileAccess.get_file_as_bytes(path)
			total_bytes += source.size()
			check(source.size() > 44 and source.slice(0, 4).get_string_from_ascii() == "RIFF", "Real WAV: " + theme + "/" + cue_name)
			var stream: AudioStreamWAV = audio.cache.get(path)
			check(stream != null and not stream.stereo and stream.mix_rate == 22050 and stream.get_length() <= 0.75,
				"A short mono clip preloads: " + theme + "/" + cue_name)
			if stream == null:
				continue
			check((stream.loop_mode == AudioStreamWAV.LOOP_FORWARD) == (cue_name == "charge"), "Only charge loops: " + theme + "/" + cue_name)
			var maximum: int = 0
			# Inspect the authored PCM, since Godot may compress imported streams.
			for offset in range(44, source.size(), 2):
				maximum = maxi(maximum, absi(source.decode_s16(offset)))
			check(maximum > 1000 and maximum < 27000, "Audible unclipped material energy: " + theme + "/" + cue_name)
			check(source.decode_s16(44) == 0 and source.decode_s16(source.size() - 2) == 0, "Clean sample boundaries: " + theme + "/" + cue_name)
			var fingerprint: String = str(hash(source))
			check(not fingerprints.has(fingerprint), "Every material and action has distinct PCM")
			fingerprints[fingerprint] = true
		var fallback: AudioStreamWAV = Bank.fallback(theme, "charge")
		check(fallback.loop_mode == AudioStreamWAV.LOOP_FORWARD and fallback.data == Bank.fallback(theme, "charge").data,
			"The " + theme + " fallback is deterministic and loopable")
	check(total_bytes < 1400000 and fingerprints.size() == 72, "All eight complete material banks fit within 1.4 MB")
	check(audio.get_child_count() == 4 and _playing(audio) == 0, "Preparing themes never allocates playback channels or makes a sound")
	audio.queue_free()
	await process_frame


func _check_performance() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	audio.prepare_chest("autumn")
	audio.chest_cue("autumn", "press")
	audio.set_chest_charge(0.0)
	check(audio.chest_charge == null, "Chest cues cannot bypass trusted audio interaction")
	audio.interact("autumn", false)
	audio.set_chest_charge(0.4)
	check(audio.chest_charge == null, "Progress alone cannot start a charge")
	audio.chest_cue("autumn", "press")
	check(_last_player(audio).stream == audio.cache[Bank.path_for("autumn", "press")], "Press immediately uses its prepared material")
	audio.set_chest_charge(0.0)
	var player: AudioStreamPlayer = audio.chest_charge
	var loop: AudioStreamWAV = audio._chest_charge_loop
	check(player.playing and player.stream == loop and audio._chest_charge_active, "The hold starts one dedicated material loop")
	var pitch: float = player.pitch_scale
	var gain: float = player.volume_db
	await create_timer(0.04).timeout
	var position: float = player.get_playback_position()
	var next_player: int = audio._chest_next_player
	audio.chest_cue("autumn", "press")
	audio.set_chest_charge(0.0)
	check(player.get_playback_position() >= position and audio._chest_next_player == next_player, "Duplicate starts do not reset or stack sounds")
	audio.set_chest_charge(0.5)
	check(player.pitch_scale > pitch and player.volume_db > gain, "Charge rate and energy follow hold progress")
	pitch = player.pitch_scale
	audio.set_chest_charge(0.2)
	audio.set_chest_charge(NAN)
	audio.set_chest_charge(INF)
	check(player.pitch_scale == pitch and audio._chest_charge_progress == 0.5, "Old or invalid progress cannot rewind or corrupt sound")
	for step in range(1, 4):
		audio.chest_cue("autumn", "charge_step", step)
		check(_last_player(audio).stream == audio.cache[Bank.path_for("autumn", "step")], "Charge step %d uses its material contact" % step)
		next_player = audio._chest_next_player
		audio.chest_cue("autumn", "charge_step" + str(step))
		check(audio._chest_next_player == next_player, "Duplicate step aliases do not replay")
	check(audio.get_child_count() == 8 and _playing(audio) <= 4, "The performance uses only four bounded chest channels")
	audio.chest_cue("autumn", "opening")
	check(player.playing and player.stream == loop and not audio._chest_charge_active
		and audio._chest_tension_progress == 0.0, "Opening hands the single loop channel to the automatic buildup")
	check(not audio._chest_rewarded and audio._chest_phase == "opening", "Opening alone never acknowledges a saved reward")
	for cue_name in ["unlock", "release", "settle"]:
		audio.chest_cue("autumn", cue_name)
		check(_last_player(audio).stream == audio.cache[Bank.path_for("autumn", cue_name)], "The view drives its actual " + cue_name + " cue")
		next_player = audio._chest_next_player
		audio.chest_cue("autumn", cue_name)
		check(audio._chest_next_player == next_player, "Duplicate " + cue_name + " cannot replay")
	audio.chest_reward("spring")
	check(not audio._chest_rewarded, "The wrong theme cannot acknowledge a reward")
	audio.chest_reward("autumn")
	check(audio._chest_rewarded and _last_player(audio).stream == audio.cache[Bank.path_for("autumn", "reward")], "Only the post-save call plays a reward accent")
	next_player = audio._chest_next_player
	audio.chest_reward("autumn")
	audio.chest_cue("autumn", "release")
	audio.set_chest_charge(1.0)
	check(audio._chest_next_player == next_player and not player.playing, "Duplicate reward and old events cannot restart performance")
	var drain_deadline: int = Time.get_ticks_msec() + 2500
	while _playing(audio) > 0 and Time.get_ticks_msec() < drain_deadline:
		await create_timer(0.05).timeout
	check(_playing(audio) == 0, "Finite material cues drain without queued playback")
	audio.prepare_chest("autumn")
	audio.chest_cue("autumn", "press")
	audio.set_chest_charge(0.0)
	check(audio.chest_charge.stream == loop and audio.get_child_count() == 8, "The next chest reuses resources and players")
	audio.stop_chest_performance()
	audio.queue_free()
	await process_frame


func _check_tension_rhythm() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	for theme: String in Bank.THEMES:
		audio.prepare_chest(theme)
		audio.set_chest_tension(0.0)
		check(audio.chest_charge == null or not audio.chest_charge.playing, "Progress cannot arm an idle " + theme + " buildup")
		audio.interact(theme, false)
		audio.chest_cue(theme, "opening")
		var player: AudioStreamPlayer = audio.chest_charge
		var loop: AudioStream = player.stream
		var starting_gain: float = player.volume_db
		var starting_pitch: float = player.pitch_scale
		var starting_music: float = audio.music.volume_db
		check(player.playing and loop == audio.cache[Bank.path_for(theme, "charge")], "Automatic " + theme + " buildup uses the prepared material loop")
		for step in range(1, 8):
			audio.set_chest_tension(float(step) / 7.0)
			audio.chest_cue(theme, "tension_pulse", step)
			check(_last_player(audio).stream == audio.cache[Bank.path_for(theme, "step")]
				and player.stream == loop and audio._chest_last_tension_pulse == step,
				"Tension pulse %d keeps the %s material and stable bed" % [step, theme])
			var next_player: int = audio._chest_next_player
			audio.chest_cue(theme, "tension_pulse", step)
			audio.chest_cue(theme, "tension_pulse", step - 1)
			check(audio._chest_next_player == next_player, "Duplicate or older pulse ordinals never replay")
		check(player.volume_db > starting_gain and player.pitch_scale > starting_pitch
			and audio.music.volume_db < starting_music, "The " + theme + " buildup rises in energy while music leaves room")
		var pitch: float = player.pitch_scale
		audio.set_chest_tension(0.1)
		audio.set_chest_tension(NAN)
		audio.set_chest_tension(INF)
		audio.set_chest_charge(0.0)
		check(player.pitch_scale == pitch and audio._chest_tension_progress == 1.0 and audio._chest_phase == "opening",
			"Invalid or old progress cannot rewind tension or restore the hold")
		for step in range(1, 3):
			audio.chest_cue(theme, "charge_step", step)
			check(_last_player(audio).stream == audio.cache[Bank.path_for(theme, "step")], "Progress star %d remains audible during buildup" % step)
		check(_playing(audio) <= 4 and audio.get_child_count() == 8, "Rapid pulses and stars stay within the same four chest channels")
		audio.chest_cue(theme, "anticipation")
		check(_playing(audio) == 0 and player.stream == null and audio.music.volume_db < -50.0,
			"Anticipation removes all chest tails and nearly silences music")
		var next_player: int = audio._chest_next_player
		audio.chest_cue(theme, "anticipation")
		audio.chest_cue(theme, "tension_pulse", 8)
		audio.set_chest_tension(0.0)
		audio.set_chest_tension(1.0)
		check(_playing(audio) == 0 and audio._chest_next_player == next_player,
			"Duplicate hush and late pulses or progress preserve the silence")
		audio.chest_cue(theme, "unlock")
		check(not player.playing and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "unlock")],
			"Unlock begins the final material release after silence")
		audio.chest_cue(theme, "charge_step", 3)
		check(_last_player(audio).stream == audio.cache[Bank.path_for(theme, "step")], "The final progress star remains available at release")
		audio.chest_cue(theme, "release")
		check(_last_player(audio).stream == audio.cache[Bank.path_for(theme, "release")]
			and is_equal_approx(audio.music.volume_db, linear_to_db(0.12)) and not audio._chest_rewarded,
			"The " + theme + " release restores music without claiming the saved reward")
		audio.chest_reward(theme)
		check(audio._chest_rewarded and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "reward")],
			"Only a save acknowledgement plays the success accent after tension")
		audio.stop_chest_performance()
		audio.chest_cue(theme, "opening")
		audio.set_chest_tension(0.9)
		audio.chest_cue(theme, "release")
		check(not player.playing and player.stream == null, "Release stops the bed even if a long frame skipped anticipation")
		audio.stop_chest_performance()
	audio.queue_free()
	await process_frame


func _check_tension_interruption() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	audio.prepare_chest("space")
	for reason in ["mute", "halt", "navigation", "unavailable"]:
		audio.available = true
		audio.set_muted(false)
		audio.interact("space", false)
		audio.chest_cue("space", "opening")
		audio.set_chest_tension(0.8)
		audio.chest_cue("space", "tension_pulse", 6)
		match reason:
			"mute": audio.set_muted(true)
			"halt": audio.halt()
			"navigation": audio.stop_chest_performance()
			"unavailable":
				audio.available = false
				audio.set_chest_tension(0.9)
		check(not audio.chest_charge.playing and audio.chest_charge.stream == null,
			"The " + reason + " path stops the automatic buildup")
		audio.available = true
		audio.set_muted(false)
		audio.interact("space", false)
		var next_player: int = audio._chest_next_player
		audio.set_chest_tension(0.0)
		audio.set_chest_tension(1.0)
		audio.chest_cue("space", "tension_pulse", 7)
		check(not audio.chest_charge.playing and audio._chest_next_player == next_player,
			"Old automatic progress and pulses stay silent after " + reason)
		audio.stop_chest_performance()
		check(is_equal_approx(audio.music.volume_db, linear_to_db(0.12)), "Ending a performance restores normal music gain")
	audio.queue_free()
	await process_frame


func _check_motion_completion_before_save() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	for theme: String in Bank.THEMES:
		for progress: float in [0.0, 0.65]:
			audio.prepare_chest(theme)
			audio.interact(theme, false)
			audio.chest_cue(theme, "opening")
			audio.set_chest_tension(progress)
			audio.chest_cue(theme, "tension_pulse", 1)
			var next_player: int = audio._chest_next_player
			audio.finish_chest_motion()
			check(_playing(audio) == 0 and audio.chest_charge.stream == null
				and is_equal_approx(audio.music.volume_db, linear_to_db(0.12)),
				"Finishing " + theme + " motion before save stops every physical sound and restores music")
			check(audio._chest_phase == "opening" and not audio._chest_rewarded
				and audio._chest_next_player == next_player,
				"Physical completion keeps the pending receipt without playing a success accent")
			audio.finish_chest_motion()
			audio.set_chest_tension(0.0)
			audio.set_chest_tension(1.0)
			audio.set_chest_charge(0.0)
			for cue_name: String in ["press", "opening", "tension_pulse", "charge_step", "anticipation", "unlock", "release", "settle"]:
				audio.chest_cue(theme, cue_name, 2 if cue_name in ["tension_pulse", "charge_step"] else 0)
			check(_playing(audio) == 0 and audio._chest_next_player == next_player,
				"Repeated completion and late motion updates cannot revive a finished performance")
			audio.chest_reward(theme, true)
			check(audio._chest_rewarded and _playing(audio) == 1
				and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "reward")],
				"A later successful save plays exactly its reward receipt after skipped motion")
			next_player = audio._chest_next_player
			audio.finish_chest_motion()
			audio.chest_reward(theme, true)
			check(audio._chest_next_player == next_player and _playing(audio) == 1,
				"Duplicate completion cannot cut off or replay the acknowledged reward")
			audio.stop_chest_performance()
			audio.chest_cue(theme, "press")
			check(audio._chest_phase == "holding" and _playing(audio) == 1,
				"A new performance explicitly clears the old motion guard")
			audio.stop_chest_performance()
	audio.queue_free()
	await process_frame


func _check_cancellation_and_guards() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	audio.prepare_chest("jungle")
	for reason in ["cancel", "mute", "halt", "unavailable", "navigation"]:
		audio.available = true
		audio.set_muted(false)
		audio.interact("jungle", false)
		audio.chest_cue("jungle", "press")
		audio.set_chest_charge(0.0)
		audio.set_chest_charge(0.8)
		match reason:
			"cancel": audio.chest_cue("jungle", "cancel")
			"mute": audio.set_muted(true)
			"halt": audio.halt()
			"unavailable":
				audio.available = false
				audio.set_chest_charge(0.9)
			"navigation": audio.stop_chest_performance()
		check(not audio.chest_charge.playing and audio.chest_charge.stream == null and not audio._chest_charge_active,
			"The " + reason + " path immediately stops and detaches the loop")
		if reason in ["mute", "halt", "navigation"]:
			check(_playing(audio) == 0, "The " + reason + " path stops every one-shot too")
		audio.available = true
		audio.set_muted(false)
		audio.interact("jungle", false)
		audio.set_chest_charge(0.9)
		audio.complete_chest_charge()
		check(not audio.chest_charge.playing, "Late progress/completion after " + reason + " cannot restart the loop")
		audio.stop_chest_performance()
	audio.play_pip()
	var greeting: AudioStream = audio.voice.stream
	audio.cue("select")
	var effect: AudioStream = audio.effect.stream
	audio.chest_cue("jungle", "press")
	audio.set_chest_charge(0.0)
	audio.stop_chest_performance()
	check(audio.voice.playing and audio.voice.stream == greeting and audio.effect.playing and audio.effect.stream == effect,
		"Stopping chest audio preserves independent voice and effect channels")
	audio.set_chest_charge(0.0)
	audio.complete_chest_charge()
	check(audio.chest_charge.stream == audio._chest_charge_accent and not audio._chest_rewarded,
		"The generic completion API remains finite and does not claim a reward")
	audio.set_muted(true)
	check(_playing(audio) == 0 and not audio.voice.playing and not audio.effect.playing, "Mute stops old and new channels together")
	audio.queue_free()
	await process_frame


func _check_delayed_preparation() -> void:
	var audio := DelayedAudio.new()
	root.add_child(audio)
	audio.downloaded = Bank.fallback("winter", "press")
	for cue_name: String in Bank.CUES:
		audio.remote_audio[Bank.path_for("space", cue_name)] = "test://" + cue_name
	audio.prepare_chest("space")
	audio.prepare_chest("space")
	check(audio.download_count == 9 and audio._loading.size() == 9 and audio.chest_charge == null, "Repeated prepares share each pending download without playback")
	await process_frame
	check(audio._chest_fallbacks.size() == 1 and audio.chest_charge == null, "Cold preparation primes only one quiet fallback in its first frame")
	await process_frame
	check(audio._chest_fallbacks.size() == 2, "The second fallback waits for a separate frame instead of blocking a gesture")
	audio.interact("space", false)
	audio.chest_cue("space", "press")
	audio.set_chest_charge(0.0)
	var fallback: AudioStream = audio.chest_charge.stream
	check(audio.chest_charge.playing and fallback != audio.downloaded, "A cold gesture uses its immediate material fallback")
	audio.release_download.emit()
	await process_frame
	check(audio._loading.is_empty() and audio.chest_charge.stream == fallback, "Finishing a download never replaces the active gesture")
	audio.stop_chest_performance()
	audio.chest_cue("space", "press")
	audio.set_chest_charge(0.0)
	check(audio.chest_charge.stream == audio.cache[Bank.path_for("space", "charge")], "A fresh gesture uses the completed cache")
	audio.stop_chest_performance()
	audio.cache.clear()
	audio.prepare_chest("space")
	audio.chest_cue("space", "press")
	audio.set_chest_charge(0.0)
	audio.halt()
	audio.release_download.emit()
	await process_frame
	check(_playing(audio) == 0 and audio.chest_charge.stream == null and audio._loading.is_empty(), "Download after pagehide caches quietly without late playback")
	audio.cache.clear()
	audio.downloaded = null
	audio.prepare_chest("space")
	audio.release_download.emit()
	await process_frame
	audio.interact("space", false)
	audio.chest_cue("space", "press")
	audio.set_chest_charge(0.0)
	check(audio.chest_charge.playing and audio.cache.is_empty() and audio._loading.is_empty(), "A failed optional download keeps the immediate material fallback usable")
	audio.halt()
	audio.queue_free()
	await process_frame


func _check_saved_retry() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	audio.prepare_chest("winter")
	audio.interact("winter", false)
	audio.chest_reward("winter")
	check(_playing(audio) == 0, "An ordinary stale receipt cannot start an idle performance")
	audio.chest_reward("winter", true)
	check(audio._chest_rewarded and _playing(audio) == 1 and audio._chest_seen.is_empty()
		and _last_player(audio).stream == audio.cache[Bank.path_for("winter", "reward")],
		"An explicit successful retry plays only its reward receipt, without physical opening beats")
	var next_player: int = audio._chest_next_player
	audio.chest_reward("winter", true)
	check(audio._chest_next_player == next_player and _playing(audio) == 1,
		"A duplicate explicit receipt cannot replay or stack its success sound")
	audio.set_muted(true)
	audio.chest_reward("winter", true)
	check(_playing(audio) == 0, "Explicit retry cannot bypass mute")
	audio.set_muted(false)
	audio.chest_reward("winter", true)
	check(_playing(audio) == 0, "Explicit retry still requires the caller's trusted interaction after unmute")
	audio.interact("winter", false)
	audio.chest_reward("winter", true)
	check(audio._chest_rewarded and _playing(audio) == 1, "A fresh visible retry can acknowledge a save after unmute")
	audio.halt()
	audio.available = false
	audio.chest_reward("winter", true)
	check(_playing(audio) == 0, "Unavailable audio cannot be restarted by explicit retry")
	audio.queue_free()
	await process_frame
