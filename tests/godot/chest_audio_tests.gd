extends SceneTree

const Bank = preload("res://scripts/chest_sound_bank.gd")
const Feel = preload("res://scripts/chest_feel.gd")

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


func _rms(source: PackedByteArray, start: int, end: int) -> float:
	var energy: float = 0.0
	for offset in range(start, end, 2):
		var sample: float = float(source.decode_s16(offset)) / 32768.0
		energy += sample * sample
	return sqrt(energy / maxf(1.0, float(end - start) / 2.0))


func _check_grounded_impact(source: PackedByteArray, sample_rate: int, cue: String, label: String) -> void:
	var low: float = 0.0
	var low_energy: float = 0.0
	var body_energy: float = 0.0
	var total_energy: float = 0.0
	var peak: float = 0.0
	var body_end: int = roundi(0.12 * sample_rate) * 2 if cue == "release" else source.size()
	var alpha: float = 1.0 - exp(-TAU * 400.0 / sample_rate)
	var low180: float = 0.0
	var low1200: float = 0.0
	var phone_energy: float = 0.0
	for offset in range(0, source.size(), 2):
		var sample: float = float(source.decode_s16(offset)) / 32768.0
		low += alpha * (sample - low)
		if offset < body_end:
			low_energy += low * low
			body_energy += sample * sample
		total_energy += sample * sample
		peak = maxf(peak, absf(sample))
		low180 += (1.0 - exp(-TAU * 180.0 / sample_rate)) * (sample - low180)
		low1200 += (1.0 - exp(-TAU * 1200.0 / sample_rate)) * (sample - low1200)
		phone_energy += (low1200 - low180) * (low1200 - low180)
	check(low_energy / maxf(body_energy, 0.000001) > 0.60,
		label + " retains low cavity weight in its initial contact")
	if cue not in ["release", "settle"]:
		return
	check(phone_energy / maxf(total_energy, 0.000001) > 0.18,
		label + " keeps audible low-mid harmonics for small speakers")
	check(peak < 0.79, label + " retains unclipped mixing headroom")
	var strongest: float = 0.0
	var strongest_time: float = 0.0
	for window in range(50):
		var time: float = float(window) * 0.005
		var energy: float = _rms(source, roundi(time * sample_rate) * 2, roundi((time + 0.020) * sample_rate) * 2)
		if energy > strongest:
			strongest = energy
			strongest_time = time + 0.010
	var contact: float = _rms(source, 0, roundi(0.040 * sample_rate) * 2)
	check(contact > (0.30 if cue == "release" else 0.15), label + " has a solid immediate contact")
	check(strongest_time >= 0.010 and strongest_time <= 0.045,
		label + " carries its main weight inside the first 45 ms")
	if cue == "release":
		check(absi(source.size() - roundi(sample_rate * 0.68) * 2) <= 2,
			label + " keeps the physical release duration")
		check(_rms(source, roundi(0.150 * sample_rate) * 2, roundi(0.300 * sample_rate) * 2) > 0.075,
			label + " retains a resonating cavity beyond contact")
		var bloom: float = _rms(source, roundi(0.300 * sample_rate) * 2, roundi(0.500 * sample_rate) * 2)
		check(bloom > 0.035 and bloom < contact * 0.30,
			label + " expands into an audible bloom without a second louder impact")
		check(_rms(source, roundi(0.620 * sample_rate) * 2, source.size()) < bloom * 0.15,
			label + " damps its bloom before the physical sample ends")
	else:
		check(_rms(source, roundi(0.180 * sample_rate) * 2, roundi(0.400 * sample_rate) * 2) < contact * 0.02,
			label + " settles quickly after a small damped rebound")


func _check_held_breath(source: PackedByteArray, sample_rate: int, label: String) -> void:
	var early: float = _rms(source, roundi(0.006 * sample_rate) * 2, roundi(0.035 * sample_rate) * 2)
	var held: float = _rms(source, roundi(0.060 * sample_rate) * 2, roundi(0.210 * sample_rate) * 2)
	check(absi(source.size() - roundi(sample_rate * 0.24) * 2) <= 2,
		label + " preserves the shared anticipation cue duration")
	check(early > 0.08 and early < 0.25, label + " gathers an audible breath during the brake")
	check(held > 0.0002 and held < early * 0.12,
		label + " holds live tension at least 18 dB below the brake")
	for window in range(8):
		var start: float = 0.060 + float(window) * 0.020
		check(_rms(source, roundi(start * sample_rate) * 2, roundi((start + 0.020) * sample_rate) * 2) < early * 0.12,
			label + " cannot rise again or add another attack during its held pose")
	check(source.decode_s16(0) == 0 and source.decode_s16(source.size() - 2) == 0,
		label + " has clean sample boundaries")


func _check_reward_sound(source: PackedByteArray, sample_rate: int, label: String) -> float:
	var level: float = _rms(source, 0, source.size())
	check(level > 0.10 and level < 0.14, label + " plays a substantial saved reward accent")
	var resolving: float = _rms(source, roundi(0.300 * sample_rate) * 2, roundi(0.500 * sample_rate) * 2)
	check(resolving > 0.08, label + " sustains its resolving phrase beyond the initial contact")
	check(_rms(source, roundi(0.620 * sample_rate) * 2, source.size()) < resolving * 0.25,
		label + " fades cleanly after resolving")
	var peak: float = 0.0
	for offset in range(0, source.size(), 2):
		peak = maxf(peak, absf(float(source.decode_s16(offset)) / 32768.0))
	check(peak < 0.79, label + " retains unclipped mixing headroom")
	check(source.decode_s16(0) == 0 and source.decode_s16(source.size() - 2) == 0,
		label + " has clean sample boundaries")
	check(absi(source.size() - roundi(sample_rate * 0.74) * 2) <= 2,
		label + " keeps the saved receipt duration")
	return level


func _run() -> void:
	await _check_material_assets()
	await _check_performance()
	await _check_tension_rhythm()
	await _check_anticipation_delivery_order()
	await _check_delayed_rhythm_delivery()
	await _check_tension_interruption()
	await _check_motion_completion_before_save()
	await _check_cancellation_and_guards()
	await _check_bundled_preparation()
	await _check_saved_retry()
	# Give the native audio mixing thread time to retire stopped playback even
	# while other scene tests or movie captures are using the same machine.
	await create_timer(0.25).timeout
	print("Chest audio: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_material_assets() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	var initial_channels: int = audio.get_child_count()
	var fingerprints: Dictionary = {}
	var total_bytes: int = 0
	var reward_levels: Array[float] = []
	var fallback_reward_levels: Array[float] = []
	check(Bank.pulse_cue(0.0) == "step" and Bank.pulse_cue(0.559) == "step"
		and Bank.pulse_cue(0.56) == "step-detail" and Bank.pulse_cue(0.819) == "step-detail"
		and Bank.pulse_cue(0.82) == "step-roll" and Bank.pulse_cue(1.0) == "step-roll",
		"Strike textures gain material detail and air at the two authored tension boundaries")
	for theme: String in Bank.THEMES:
		audio.prepare_chest(theme)
		for cue_name: String in Bank.CUES:
			var path: String = Bank.path_for(theme, cue_name)
			var source: PackedByteArray = FileAccess.get_file_as_bytes(path)
			total_bytes += source.size()
			check(source.size() > 44 and source.slice(0, 4).get_string_from_ascii() == "RIFF", "Real WAV: " + theme + "/" + cue_name)
			var stream: AudioStreamWAV = audio.cache.get(path)
			check(stream != null and not stream.stereo and stream.mix_rate == 22050
				and stream.get_length() <= (0.81 if cue_name == "charge" else 0.75),
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
			if cue_name.begins_with("step") or cue_name in ["release", "settle"]:
				_check_grounded_impact(source.slice(44), 22050, cue_name, theme + "/" + cue_name)
			if cue_name == "reward":
				reward_levels.append(_check_reward_sound(source.slice(44), 22050, theme + "/reward"))
			if cue_name == "opening":
				_check_held_breath(source.slice(44), 22050, theme + "/opening")
			if cue_name == "charge":
				var window_frames: int = (source.size() - 44) / 8
				var texture_energy: Array[float] = []
				for window in range(4):
					texture_energy.append(_rms(source, 44 + window * window_frames * 2,
						44 + (window + 1) * window_frames * 2))
				check(texture_energy.min() > 0.07 and texture_energy.max() / texture_energy.min() < 1.6,
					"The %s tension texture stays audible without an independent decaying beat" % theme)
			var fingerprint: String = str(hash(source))
			check(not fingerprints.has(fingerprint), "Every material and action has distinct PCM")
			fingerprints[fingerprint] = true
		var fallback: AudioStreamWAV = Bank.fallback(theme, "charge")
		check(fallback.loop_mode == AudioStreamWAV.LOOP_FORWARD and fallback.data == Bank.fallback(theme, "charge").data,
			"The " + theme + " fallback is deterministic and loopable")
		for cue_name: String in ["step", "step-detail", "step-roll", "release", "settle"]:
			fallback = Bank.fallback(theme, cue_name)
			check(fallback.data == Bank.fallback(theme, cue_name).data
				and fallback.data.decode_s16(0) == 0 and fallback.data.decode_s16(fallback.data.size() - 2) == 0,
				"The " + theme + "/" + cue_name + " fallback is deterministic with clean boundaries")
			_check_grounded_impact(fallback.data, Bank.SAMPLE_RATE, cue_name, theme + "/" + cue_name + " fallback")
		fallback = Bank.fallback(theme, "reward")
		check(fallback.data == Bank.fallback(theme, "reward").data,
			"The " + theme + " saved reward fallback is deterministic")
		fallback_reward_levels.append(_check_reward_sound(fallback.data, Bank.SAMPLE_RATE, theme + "/reward fallback"))
		fallback = Bank.fallback(theme, "opening")
		check(fallback.get_length() >= Feel.RELEASE_TIME - Feel.ANTICIPATION_TIME
			and fallback.data == Bank.fallback(theme, "opening").data,
			"The " + theme + " fallback breath is deterministic and covers the final brake and hold")
		_check_held_breath(fallback.data, Bank.SAMPLE_RATE, theme + "/opening fallback")
	check(total_bytes < 1600000 and fingerprints.size() == 88, "All eight complete material banks with three strike textures fit within 1.6 MB")
	check(reward_levels.size() == Bank.THEMES.size() and reward_levels.max() / reward_levels.min() < 1.15,
		"Every theme acknowledges a saved reward at a comparable authored level")
	check(fallback_reward_levels.size() == Bank.THEMES.size() and fallback_reward_levels.max() / fallback_reward_levels.min() < 1.15,
		"Every theme acknowledges a saved reward at a comparable fallback level")
	check(audio.get_child_count() == initial_channels and _playing(audio) == 0, "Preparing themes never allocates playback channels or makes a sound")
	audio.queue_free()
	await process_frame


func _check_performance() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	var initial_channels: int = audio.get_child_count()
	audio.prepare_chest("autumn")
	audio.chest_cue("autumn", "press")
	audio.chest_cue("autumn", "hold_pulse", 1)
	audio.set_chest_charge(0.0)
	check(audio.chest_charge == null, "Chest cues cannot bypass trusted audio interaction")
	audio.interact("autumn", false)
	audio.set_chest_charge(0.4)
	check(audio.chest_charge == null, "Progress alone cannot start a charge")
	audio.chest_cue("autumn", "press")
	check(_last_player(audio).stream == audio.cache[Bank.path_for("autumn", "press")], "Press immediately uses its prepared material")
	var unarmed_player: int = audio._chest_next_player
	audio.chest_cue("autumn", "hold_pulse", 1)
	check(audio._chest_next_player == unarmed_player and audio._chest_last_hold_pulse == 0,
		"A press without an armed hold cannot sound or consume a hold beat")
	audio.set_chest_charge(0.0)
	var player: AudioStreamPlayer = audio.chest_charge
	var loop: AudioStreamWAV = audio._chest_charge_loop
	check(player.playing and player.stream == loop and audio._chest_charge_active, "The hold starts one dedicated material loop")
	var before_invalid: int = audio._chest_next_player
	for step in [-1, 0, Feel.HOLD_PULSE_TIMES.size() + 1]:
		audio.chest_cue("autumn", "hold_pulse", step)
	audio.chest_cue("winter", "hold_pulse", 1)
	check(audio._chest_next_player == before_invalid and audio._chest_last_hold_pulse == 0,
		"Invalid hold ordinals and another theme cannot sound or consume a beat")
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
		next_player = audio._chest_next_player
		audio.chest_cue("autumn", "charge_step", step)
		check(audio._chest_next_player == next_player, "Holding star %d stays silent between the scheduled beats" % step)
		audio.chest_cue("autumn", "charge_step" + str(step))
		check(audio._chest_next_player == next_player, "Duplicate step aliases do not replay")
	check(audio.get_child_count() == initial_channels + 4 and _playing(audio) <= 4, "The performance uses only four bounded chest channels")
	audio.set_chest_charge(1.0)
	var confirmation_gain: float = player.volume_db
	var confirmation_pitch: float = player.pitch_scale
	var confirmation_position: float = player.get_playback_position()
	next_player = audio._chest_next_player
	audio.chest_cue("autumn", "opening")
	check(player.playing and player.stream == loop and not audio._chest_charge_active
		and is_equal_approx(audio._chest_tension_progress, Feel.tension(0.0)),
		"Opening hands the existing loop channel to the same continuous tension")
	check(is_equal_approx(player.volume_db, confirmation_gain) and is_equal_approx(player.pitch_scale, confirmation_pitch)
		and player.get_playback_position() >= confirmation_position,
		"Confirming never restarts the material loop or drops its pitch and gain")
	check(audio._chest_next_player == next_player,
		"The automatic handoff adds no offbeat opening attack")
	audio.chest_cue("autumn", "hold_pulse", 1)
	check(audio._chest_next_player == next_player and audio._chest_last_hold_pulse == 0,
		"A late hold beat cannot play after the automatic opening takes over")
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
	audio.chest_cue("autumn", "hold_pulse", 1)
	audio.set_chest_charge(1.0)
	check(audio._chest_next_player == next_player and not player.playing, "Duplicate reward and old events cannot restart performance")
	var drain_deadline: int = Time.get_ticks_msec() + 2500
	while _playing(audio) > 0 and Time.get_ticks_msec() < drain_deadline:
		await create_timer(0.05).timeout
	check(_playing(audio) == 0, "Finite material cues drain without queued playback")
	audio.prepare_chest("autumn")
	audio.chest_cue("autumn", "press")
	audio.set_chest_charge(0.0)
	check(audio.chest_charge.stream == loop and audio.get_child_count() == initial_channels + 4, "The next chest reuses resources and players")
	audio.stop_chest_performance()
	audio.queue_free()
	await process_frame


func _check_tension_rhythm() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	var initial_channels: int = audio.get_child_count()
	for theme: String in Bank.THEMES:
		audio.prepare_chest(theme)
		audio.set_chest_tension(0.0)
		check(audio.chest_charge == null or not audio.chest_charge.playing, "Progress cannot arm an idle " + theme + " buildup")
		audio.interact(theme, false)
		audio.chest_cue(theme, "hold_pulse", 1)
		check(audio._chest_last_hold_pulse == 0 and _playing(audio) == 0,
			"An idle trusted interaction cannot sound or consume a hold beat")
		audio.chest_cue(theme, "press")
		audio.set_chest_charge(0.0)
		var player: AudioStreamPlayer = audio.chest_charge
		var loop: AudioStream = player.stream
		var starting_gain: float = player.volume_db
		var starting_pitch: float = player.pitch_scale
		var starting_music: float = audio.music.volume_db
		check(player.playing and loop == audio.cache[Bank.path_for(theme, "charge")]
			and is_equal_approx(starting_pitch, 0.92) and is_equal_approx(starting_gain, linear_to_db(0.035)),
			"The " + theme + " hold begins its quiet continuous material bed immediately")
		var previous_pulse_gain: float = -100.0
		var previous_bed_gain: float = player.volume_db
		var previous_bed_pitch: float = player.pitch_scale
		var delivered: int = 0
		var strike_textures: Dictionary = {}
		for holding: bool in [true, false]:
			if not holding:
				audio.set_chest_charge(1.0)
				var handoff: Vector2 = Vector2(player.volume_db, player.pitch_scale)
				var position: float = player.get_playback_position()
				var next_player: int = audio._chest_next_player
				audio.chest_cue(theme, "opening")
				check(player.stream == loop and player.get_playback_position() >= position
					and handoff.is_equal_approx(Vector2(player.volume_db, player.pitch_scale))
					and audio._chest_next_player == next_player,
					"The " + theme + " hold hands off without a new source, attack, or lower bed energy")
			var beats: Array = Feel.HOLD_PULSE_TIMES if holding else Feel.PULSE_TIMES
			var cue_name: String = "hold_pulse" if holding else "tension_pulse"
			for step in range(1, beats.size() + 1):
				var beat: float = float(beats[step - 1])
				var scheduled_energy: float = Feel.tension(beat - Feel.HOLD_SECONDS if holding else beat)
				if holding:
					audio.set_chest_charge(beat / Feel.HOLD_SECONDS)
				else:
					audio.set_chest_tension(scheduled_energy)
				var before_pulse: int = audio._chest_next_player
				audio.chest_cue(theme, cue_name, step)
				delivered += 1
				strike_textures[Bank.pulse_cue(scheduled_energy)] = true
				check(_last_player(audio).stream == audio.cache[Bank.path_for(theme, Bank.pulse_cue(scheduled_energy))]
					and player.stream == loop and audio._chest_next_player == (before_pulse + 1) % 3,
					"The %s %s %d starts exactly one material strike over the same bed" % [theme, cue_name, step])
				check(is_equal_approx(_last_player(audio).volume_db, linear_to_db(lerpf(0.30, 0.56, scheduled_energy)))
					and is_equal_approx(_last_player(audio).pitch_scale, 1.0),
					"Each strike uses its scheduled energy while preserving the chest's low resonance")
				check(_last_player(audio).volume_db > previous_pulse_gain
					and player.volume_db > previous_bed_gain and player.pitch_scale > previous_bed_pitch,
					"Every %s beat grows louder while its separate pressure layer rises through hold and opening" % theme)
				previous_pulse_gain = _last_player(audio).volume_db
				previous_bed_gain = player.volume_db
				previous_bed_pitch = player.pitch_scale
				var next_player: int = audio._chest_next_player
				audio.chest_cue(theme, cue_name, step)
				audio.chest_cue(theme, cue_name, step - 1)
				check(audio._chest_next_player == next_player, "Duplicate or older pulse ordinals never replay")
		check(delivered == Feel.HOLD_PULSE_TIMES.size() + Feel.PULSE_TIMES.size()
			and audio._chest_last_hold_pulse == Feel.HOLD_PULSE_TIMES.size() and audio._chest_last_tension_pulse == Feel.PULSE_TIMES.size(),
			"The normal " + theme + " performance sounds every scheduled hold and opening beat")
		check(strike_textures.size() == 3, "The " + theme + " crescendo progresses through three distinct material textures")
		check(player.volume_db - starting_gain > 14.0 and player.pitch_scale > starting_pitch * 1.45 and player.pitch_scale < starting_pitch * 1.6
			and audio.music.volume_db < starting_music, "The full " + theme + " crescendo rises while music leaves room")
		var pitch: float = player.pitch_scale
		var energy: float = audio._chest_tension_progress
		audio.set_chest_tension(0.1)
		audio.set_chest_tension(NAN)
		audio.set_chest_tension(INF)
		audio.set_chest_charge(0.0)
		check(player.pitch_scale == pitch and audio._chest_tension_progress == energy and audio._chest_phase == "opening",
			"Invalid or old progress cannot rewind tension or restore the hold")
		var before_stars: int = audio._chest_next_player
		for step in range(1, 4):
			audio.chest_cue(theme, "charge_step", step)
			check(audio._chest_next_player == before_stars,
				"Automatic progress star %d does not add a second unsynchronized beat" % step)
		check(_playing(audio) <= 4 and audio.get_child_count() == initial_channels + 4, "Rapid pulses and stars stay within the same four chest channels")
		var before_transition: int = audio._chest_next_player
		var before_breath_gain: float = player.volume_db
		var before_breath_position: float = player.get_playback_position()
		audio.chest_cue(theme, "anticipation")
		var bridge: AudioStreamPlayer = _last_player(audio)
		check(player.playing and player.stream == loop and is_equal_approx(player.pitch_scale, 1.42)
			and is_equal_approx(player.volume_db, linear_to_db(0.025))
			and player.get_playback_position() >= before_breath_position and before_breath_gain - player.volume_db > 18.0
			and bridge.playing and bridge.stream == audio.cache[Bank.path_for(theme, "opening")]
			and is_equal_approx(bridge.volume_db, linear_to_db(0.32)) and _playing(audio) == 2
			and audio._chest_next_player == (before_transition + 1) % 3
			and is_equal_approx(audio.music.volume_db, linear_to_db(0.12 * 0.06)),
			"Anticipation clears residual roll tails and gathers one breath over the quiet uninterrupted bed")
		var next_player: int = audio._chest_next_player
		audio.chest_cue(theme, "anticipation")
		audio.chest_cue(theme, "tension_pulse", Feel.PULSE_TIMES.size())
		audio.chest_cue(theme, "hold_pulse", Feel.HOLD_PULSE_TIMES.size())
		audio.set_chest_tension(0.0)
		audio.set_chest_tension(1.0)
		check(player.playing and player.stream == loop and bridge.playing
			and audio._chest_next_player == next_player and is_equal_approx(player.pitch_scale, 1.42)
			and is_equal_approx(player.volume_db, linear_to_db(0.025)) and _playing(audio) == 2,
			"Duplicate anticipation and late pulses or progress cannot restart or amplify the held breath")
		audio.chest_cue(theme, "unlock")
		check(player.playing and player.stream == loop and bridge.playing
			and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "unlock")]
			and is_equal_approx(_last_player(audio).volume_db, linear_to_db(0.055))
			and is_equal_approx(player.volume_db, linear_to_db(0.025)),
			"The tiny latch stays inside the held breath without rebuilding the crescendo")
		next_player = audio._chest_next_player
		audio.chest_cue(theme, "charge_step", 3)
		check(audio._chest_next_player == next_player,
			"The final progress star stays visual so the release retains its single impact")
		audio.chest_cue(theme, "release")
		var release_player: AudioStreamPlayer = _last_player(audio)
		check(release_player.stream == audio.cache[Bank.path_for(theme, "release")]
			and is_equal_approx(release_player.volume_db, linear_to_db(0.86))
			and not player.playing and player.stream == null and not bridge.playing and _playing(audio) == 1
			and is_equal_approx(audio.music.volume_db, linear_to_db(0.12 * 0.20)) and not audio._chest_rewarded,
			"The " + theme + " release replaces the bridge with one weighted payoff while music stays behind it")
		audio.chest_cue(theme, "settle")
		check(is_equal_approx(audio.music.volume_db, linear_to_db(0.12 * 0.45))
			and is_equal_approx(_last_player(audio).volume_db, linear_to_db(0.42)),
			"The " + theme + " landing remains in front of the returning music")
		check(release_player.playing and release_player.stream == audio.cache[Bank.path_for(theme, "release")]
			and release_player != _last_player(audio),
			"The " + theme + " mechanical stop preserves the release bloom on its own channel")
		audio.chest_reward(theme)
		check(audio._chest_rewarded and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "reward")]
			and is_equal_approx(_last_player(audio).volume_db, linear_to_db(0.54))
			and is_equal_approx(audio.music.volume_db, linear_to_db(0.12)),
			"Only a save acknowledgement plays the success accent and restores music after tension")
		audio.stop_chest_performance()
		audio.chest_cue(theme, "opening")
		audio.set_chest_tension(0.9)
		audio.chest_cue(theme, "release")
		check(not player.playing and player.stream == null, "Release stops the bed even if a long frame skipped anticipation")
		audio.stop_chest_performance()
	# The cue clock, rather than the previous UI frame, sets each strike's
	# intensity. Two different last-frame energy values must yield one beat.
	var scheduled_pulse: Array = []
	for stale_energy: float in [Feel.tension(0.0), 0.99]:
		audio.prepare_chest("autumn")
		audio.interact("autumn", false)
		audio.chest_cue("autumn", "opening")
		audio.set_chest_tension(stale_energy)
		audio.chest_cue("autumn", "tension_pulse", 5)
		scheduled_pulse.append(Vector2(_last_player(audio).volume_db, _last_player(audio).pitch_scale))
		audio.stop_chest_performance()
	check(scheduled_pulse[0].is_equal_approx(scheduled_pulse[1]),
		"A live beat has the same energy with stale or advanced UI progress")
	scheduled_pulse.clear()
	for stale_progress: float in [0.0, 1.0]:
		audio.prepare_chest("autumn")
		audio.interact("autumn", false)
		audio.chest_cue("autumn", "press")
		audio.set_chest_charge(0.0)
		audio.set_chest_charge(stale_progress)
		audio.chest_cue("autumn", "hold_pulse", 3)
		scheduled_pulse.append(Vector2(_last_player(audio).volume_db, _last_player(audio).pitch_scale))
		audio.stop_chest_performance()
	check(scheduled_pulse[0].is_equal_approx(scheduled_pulse[1]),
		"A held beat also uses its schedule rather than stale or advanced UI progress")
	audio.queue_free()
	await process_frame


func _check_anticipation_delivery_order() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	for theme: String in Bank.THEMES:
		for progress_first: bool in [true, false]:
			audio.prepare_chest(theme)
			audio.interact(theme, false)
			audio.chest_cue(theme, "opening")
			audio.set_chest_tension(0.95)
			audio.chest_cue(theme, "tension_pulse", Feel.PULSE_TIMES.size())
			var bed: AudioStream = audio.chest_charge.stream
			var next_player: int = audio._chest_next_player
			if progress_first:
				audio.set_chest_tension(1.0)
				check(_playing(audio) == 1 and audio.chest_charge.stream == bed
					and audio._chest_next_player == next_player and not audio._chest_seen.has("anticipation0")
					and is_equal_approx(audio.chest_charge.volume_db, linear_to_db(0.025))
					and is_equal_approx(audio.music.volume_db, linear_to_db(0.12 * 0.06)),
					"Saturated %s progress quietly enters the hold without inventing a breath cue" % theme)
				audio.chest_cue(theme, "anticipation")
				check(_playing(audio) == 2 and audio._chest_next_player == (next_player + 1) % 3
					and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "opening")],
					"A normally delivered %s breath still plays once after progress enters the same hold" % theme)
			else:
				audio.chest_cue(theme, "unlock")
				check(_playing(audio) == 2 and audio.chest_charge.stream == bed
					and audio._chest_next_player == (next_player + 1) % 3
					and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "unlock")]
					and is_equal_approx(audio.chest_charge.volume_db, linear_to_db(0.025))
					and is_equal_approx(audio.music.volume_db, linear_to_db(0.12 * 0.06)),
					"The %s unlock independently quiets a missed anticipation without a breath replay" % theme)
			next_player = audio._chest_next_player
			audio.set_chest_tension(1.0)
			audio.set_chest_tension(0.1)
			audio.chest_cue(theme, "anticipation")
			check(audio._chest_next_player == next_player and _playing(audio) == 2
				and is_equal_approx(audio.chest_charge.volume_db, linear_to_db(0.025)),
				"Repeated progress and late %s anticipation cannot clear or replay an existing held sound" % theme)
			audio.chest_cue(theme, "release")
			next_player = audio._chest_next_player
			audio.set_chest_tension(1.0)
			audio.chest_cue(theme, "anticipation")
			audio.chest_cue(theme, "unlock")
			audio.chest_cue(theme, "release")
			check(audio._chest_next_player == next_player and not audio.chest_charge.playing
				and audio.chest_charge.stream == null and _playing(audio) == 1
				and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "release")]
				and is_equal_approx(audio.music.volume_db, linear_to_db(0.12 * 0.20)),
				"Late %s held-state updates cannot restart the bed or interrupt the single release" % theme)
			audio.stop_chest_performance()
	audio.queue_free()
	await process_frame


func _check_delayed_rhythm_delivery() -> void:
	var data = load("res://scripts/game_data.gd").new()
	check(data.load_all(), "Delayed rhythm tests load the original chest artwork")
	var audio = load("res://scripts/game_audio.gd").new()
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(audio)
	root.add_child(chest)
	chest.set_process(false)
	chest.size = Vector2(440, 360)
	chest.cue_requested.connect(audio.chest_cue)
	for theme: String in Bank.THEMES:
		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		audio.prepare_chest(theme)
		audio.interact(theme, false)
		chest.begin_hold()
		audio.set_chest_charge(0.0)
		var bed: AudioStream = audio.chest_charge.stream
		var delivered_hold: Array[int] = []
		var pulse_gain: float = -100.0
		for frame in range(1, 21):
			var previous: int = audio._chest_last_hold_pulse
			chest.set_hold_progress(float(frame) * 0.06 / Feel.HOLD_SECONDS)
			audio.set_chest_charge(chest.hold_progress)
			if audio._chest_last_hold_pulse > previous:
				delivered_hold.append(audio._chest_last_hold_pulse)
				var state: Dictionary = chest.hold_effect_snapshot()
				check(absf(state.physical_pose.x) > 0.0001 and state.pulse_strength > 0.30
					and _last_player(audio).playing and _last_player(audio).volume_db > pulse_gain
					and is_equal_approx(_last_player(audio).pitch_scale, 1.0),
					"Each held %s beat starts an audible strike and fresh visible kick at 60-millisecond cadence" % theme)
				pulse_gain = _last_player(audio).volume_db
		check(delivered_hold == range(1, Feel.HOLD_PULSE_TIMES.size() + 1), "The " + theme + " hold delivers every scheduled strike")
		chest.start_open(false)
		check(audio.chest_charge.playing and audio.chest_charge.stream == bed,
			"The view's opening preserves the material bed already playing during the hold")
		var delivered: Array[int] = []
		for frame in range(32):
			var previous: int = audio._chest_last_tension_pulse
			chest._advance_animation(0.06)
			var state: Dictionary = chest.hold_effect_snapshot()
			if audio._chest_last_tension_pulse > previous:
				delivered.append(audio._chest_last_tension_pulse)
				check(absf(state.physical_pose.x) > 0.0001 and state.pulse_strength > 0.4
					and _last_player(audio).playing
					and _last_player(audio).volume_db > pulse_gain and is_equal_approx(_last_player(audio).pitch_scale, 1.0)
					and _last_player(audio).stream == audio.cache[Bank.path_for(theme,
						Bank.pulse_cue(Feel.tension(float(Feel.PULSE_TIMES[audio._chest_last_tension_pulse - 1]))))],
					"A 60-millisecond %s frame starts each audible strike with its body kick and glow" % theme)
				pulse_gain = _last_player(audio).volume_db
		check(delivered == range(1, Feel.PULSE_TIMES.size() + 1)
			and delivered.size() + delivered_hold.size() == Feel.PULSE_TIMES.size() + Feel.HOLD_PULSE_TIMES.size(),
			"The %s rhythm delivers every opening beat after its hold beats at 60-millisecond cadence" % theme)
		chest._advance_animation(Feel.ANTICIPATION_TIME - chest._elapsed)
		var bridge_index: int = audio._chest_next_player
		check(audio.chest_charge.playing and _last_player(audio).playing
			and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "opening")]
			and is_equal_approx(audio.chest_charge.volume_db, linear_to_db(0.025))
			and _playing(audio) == 2
			and is_zero_approx(chest.hold_effect_snapshot().pulse_motion),
			"The %s final brake clears the roll and takes a held breath over quiet pressure" % theme)
		chest._advance_animation(0.01)
		check(audio.chest_charge.playing and audio._chest_next_player == bridge_index
			and is_zero_approx(chest.hold_effect_snapshot().pulse_motion),
			"The %s held breath continues without another beat or source restart" % theme)
		audio.stop_chest_performance()
		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		audio.prepare_chest(theme)
		chest.begin_hold()
		audio.set_chest_charge(0.0)
		chest.set_hold_progress((float(Feel.HOLD_PULSE_TIMES[0]) - 0.001) / Feel.HOLD_SECONDS)
		check(audio._chest_last_hold_pulse == 0 and is_zero_approx(chest.hold_effect_snapshot().pulse_motion),
			"The first " + theme + " hold kick waits for its 80-millisecond beat")
		chest.set_hold_progress((float(Feel.HOLD_PULSE_TIMES[0]) + 0.000001) / Feel.HOLD_SECONDS)
		var held: Dictionary = chest.hold_effect_snapshot()
		check(audio._chest_last_hold_pulse == 1 and _last_player(audio).playing
			and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "step")]
			and is_equal_approx(held.pulse_motion, Feel.pulse_motion(float(Feel.HOLD_PULSE_TIMES[0]), true))
			and absf(held.physical_pose.x) > 0.0001,
			"The first " + theme + " hold beat sounds as a fresh visible kick begins after 80 milliseconds")
		chest.set_hold_progress((float(Feel.HOLD_PULSE_TIMES[0]) + Feel.pulse_duration(0, true) + 0.001) / Feel.HOLD_SECONDS)
		check(audio._chest_last_hold_pulse == 1 and is_zero_approx(chest.hold_effect_snapshot().pulse_motion),
			"The first " + theme + " held kick returns before the second scheduled beat")
		audio.stop_chest_performance()
		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		audio.prepare_chest(theme)
		chest.start_open(false)
		# This delivery is still live, but the old absolute clock had already
		# decayed its visual attack by the time the matching sound began.
		chest._advance_animation(float(Feel.PULSE_TIMES[0]) + 0.08)
		var delayed: Dictionary = chest.hold_effect_snapshot()
		check(audio._chest_last_tension_pulse == 1 and _last_player(audio).playing
			and is_equal_approx(delayed.pulse_motion, Feel.pulse_motion(float(Feel.PULSE_TIMES[0])))
			and absf(delayed.physical_pose.x) > 0.0001,
			"An 80-millisecond late %s strike starts a fresh kick with the actual audio" % theme)
		audio.stop_chest_performance()
		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		audio.prepare_chest(theme)
		chest.start_open(false)
		var before_jump: int = audio._chest_next_player
		chest._advance_animation(float(Feel.PULSE_TIMES.back()) + 0.001)
		check(audio._chest_last_tension_pulse == Feel.PULSE_TIMES.size() and audio._chest_next_player == (before_jump + 1) % 3
			and is_equal_approx(chest.hold_effect_snapshot().pulse_motion, Feel.pulse_motion(float(Feel.PULSE_TIMES.back()))),
			"A stalled " + theme + " opening coalesces its backlog into only the newest live sound and kick")
		chest._advance_animation(Feel.pulse_duration(Feel.PULSE_TIMES.size() - 1) + 0.001)
		check(audio._chest_last_tension_pulse == Feel.PULSE_TIMES.size()
			and is_zero_approx(chest.hold_effect_snapshot().pulse_motion),
			"The delayed %s kick returns once without inventing another beat" % theme)
		audio.stop_chest_performance()
		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		audio.prepare_chest(theme)
		chest.begin_hold()
		audio.set_chest_charge(0.0)
		before_jump = audio._chest_next_player
		chest.set_hold_progress(0.32 / Feel.HOLD_SECONDS)
		check(audio._chest_last_hold_pulse == 0 and audio._chest_next_player == before_jump
			and is_zero_approx(chest.hold_effect_snapshot().pulse_motion),
			"A held " + theme + " strike more than 200 milliseconds stale cannot replay its sound or kick")
		chest.set_hold_progress(0.92 / Feel.HOLD_SECONDS)
		check(audio._chest_last_hold_pulse == 4 and audio._chest_next_player == (before_jump + 1) % 3,
			"A stalled " + theme + " hold plays only its newest live beat instead of a backlog")
		audio.stop_chest_performance()
		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		audio.prepare_chest(theme)
		chest.start_open(false)
		chest._advance_animation(Feel.ANTICIPATION_TIME)
		check(audio._chest_last_tension_pulse == 0 and audio.chest_charge.playing
			and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "opening")]
			and is_equal_approx(audio.chest_charge.volume_db, linear_to_db(0.025))
			and is_zero_approx(chest.hold_effect_snapshot().pulse_motion),
			"A " + theme + " frame reaching the brake consumes old beats and sounds only its current breath")
		audio.stop_chest_performance()
		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		audio.prepare_chest(theme)
		chest.start_open(false)
		chest._advance_animation(1.90)
		audio.set_chest_tension(chest.tension_progress())
		check(audio._chest_last_tension_pulse == Feel.PULSE_TIMES.size() and _playing(audio) == 2,
			"The %s stalled-frame fixture reaches the final roll with its bed and newest strike" % theme)
		before_jump = audio._chest_next_player
		chest._advance_animation(0.14)
		audio.set_chest_tension(chest.tension_progress())
		check(not audio._chest_seen.has("anticipation0") and audio._chest_next_player == before_jump
			and _playing(audio) == 1 and audio.chest_charge.playing
			and is_equal_approx(audio.chest_charge.volume_db, linear_to_db(0.025))
			and is_equal_approx(audio.music.volume_db, linear_to_db(0.12 * 0.06)),
			"A %s frame from 1.90 to 2.04 seconds skips the late breath but still quiets the held state" % theme)
		audio.set_chest_tension(1.0)
		chest._advance_animation(Feel.UNLOCK_TIME - chest._elapsed + 0.000001)
		audio.set_chest_tension(chest.tension_progress())
		check(not audio._chest_seen.has("anticipation0") and audio._chest_next_player == (before_jump + 1) % 3
			and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "unlock")]
			and is_equal_approx(audio.chest_charge.volume_db, linear_to_db(0.025))
			and is_equal_approx(audio.music.volume_db, linear_to_db(0.12 * 0.06)),
			"The %s latch preserves that quiet hold without backfilling a skipped breath" % theme)
		chest._advance_animation(Feel.RELEASE_TIME - chest._elapsed + 0.000001)
		audio.set_chest_tension(chest.tension_progress())
		check(not audio.chest_charge.playing and _playing(audio) == 1
			and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "release")],
			"The %s release stops the quiet bed after the skipped anticipation" % theme)
		audio.stop_chest_performance()
		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		audio.prepare_chest(theme)
		chest.start_open(false)
		chest._advance_animation(Feel.RELEASE_TIME + 0.01)
		audio.set_chest_tension(chest.tension_progress())
		check(not audio._chest_seen.has("anticipation0") and not audio.chest_charge.playing
			and _last_player(audio).stream == audio.cache[Bank.path_for(theme, "release")],
			"A " + theme + " frame arriving after release cannot replay the missed breath over the payoff")
		audio.stop_chest_performance()
	chest.queue_free()
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
		audio.chest_cue("space", "anticipation")
		match reason:
			"mute": audio.set_muted(true)
			"halt": audio.halt()
			"navigation": audio.stop_chest_performance()
			"unavailable":
				audio.available = false
				audio.set_chest_tension(0.9)
		check(_playing(audio) == 0 and audio.chest_charge.stream == null,
			"The " + reason + " path stops both the pressure and transition")
		audio.available = true
		audio.set_muted(false)
		audio.interact("space", false)
		var next_player: int = audio._chest_next_player
		audio.set_chest_tension(0.0)
		audio.set_chest_tension(1.0)
		audio.chest_cue("space", "tension_pulse", 7)
		audio.chest_cue("space", "hold_pulse", 4)
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
			if progress > 0.0:
				audio.chest_cue(theme, "anticipation")
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
			for cue_name: String in ["press", "opening", "hold_pulse", "tension_pulse", "charge_step", "anticipation", "unlock", "release", "settle"]:
				audio.chest_cue(theme, cue_name, 2 if cue_name in ["hold_pulse", "tension_pulse", "charge_step"] else 0)
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
		audio.chest_cue("jungle", "hold_pulse", 3)
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
		var next_player: int = audio._chest_next_player
		audio.set_chest_charge(0.9)
		audio.chest_cue("jungle", "hold_pulse", 4)
		check(not audio.chest_charge.playing and audio._chest_next_player == next_player,
			"Late hold progress or beats after " + reason + " cannot restart performance")
		audio.stop_chest_performance()
		check(audio._chest_last_hold_pulse == 0, "Stopping the " + reason + " performance resets its held-beat ordinal")
	audio.play_pip()
	var greeting: AudioStream = audio.voice.stream
	audio.cue("select")
	var effect: AudioStream = audio.effect.stream
	audio.chest_cue("jungle", "press")
	audio.set_chest_charge(0.0)
	audio.stop_chest_performance()
	check(audio.voice.playing and audio.voice.stream == greeting and audio.effect.playing and audio.effect.stream == effect,
		"Stopping chest audio preserves independent voice and effect channels")
	audio.chest_cue("jungle", "press")
	audio.set_chest_charge(0.0)
	audio.chest_cue("jungle", "opening")
	audio.set_muted(true)
	check(_playing(audio) == 0 and not audio.voice.playing and not audio.effect.playing, "Mute stops old and new channels together")
	audio.queue_free()
	await process_frame


func _check_bundled_preparation() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	var initial_cached: int = audio.cache.size()
	for theme: String in Bank.THEMES:
		audio.prepare_chest(theme)
		audio.prepare_chest(theme)
		for cue_name: String in Bank.CUES:
			var path: String = Bank.path_for(theme, cue_name)
			check(audio.cache.get(path) is AudioStreamWAV,
				theme + " " + cue_name + " is immediately ready from the game pack")
		check(audio._chest_fallbacks.is_empty() and _playing(audio) == 0,
			"Preparation reads authored local recordings without starting playback or a fallback")
		audio.interact(theme, false)
		audio.chest_cue(theme, "press")
		audio.set_chest_charge(0.0)
		var charge: AudioStreamWAV = audio.chest_charge.stream
		check(charge == audio.cache[Bank.path_for(theme, "charge")]
			and charge.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"The first press immediately uses the complete authored looping charge")
		audio.prepare_chest(theme)
		check(audio.chest_charge.playing and audio.chest_charge.stream == charge,
			"Repeated preparation cannot interrupt an active charge")
		audio.halt()
		await process_frame
		check(_playing(audio) == 0 and audio.chest_charge.stream == null,
			"Background cancellation stops every chest channel with no delayed playback")
	check(audio.cache.size() - initial_cached == Bank.THEMES.size() * Bank.CUES.size(),
		"Every theme is cached locally without allocating network requests")
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
