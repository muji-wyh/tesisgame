extends Node

const POP_SLICE_PATH := "res://assets/imported-audio/pop-slice.wav"
const POP_REFERENCE_PATHS := [
	"res://assets/imported-audio/pop-reference/quick.wav",
	"res://assets/imported-audio/pop-reference/juicy.wav",
	"res://assets/imported-audio/pop-reference/crisp.wav",
]
const POP_HIT_CHANNELS := 3
const POP_HIT_GAIN := 0.24
const POP_LAUNCH_PATH := "res://assets/imported-audio/pop-reference/launch.wav"
const POP_LAUNCH_FALLBACK := "res://assets/audio/sfx/pop-launch.wav"
const POP_LAUNCH_GAIN := 0.16
const MATCH_VOICE_HIT_PATH := "res://assets/audio/sfx/match-voice-hit.wav"
const MATCH_VOICE_HIT_GAIN := 0.48
const POP_SLICE_PATHS := [
	"res://assets/imported-audio/pop-slices/apple.wav",
	"res://assets/imported-audio/pop-slices/orange.wav",
	"res://assets/imported-audio/pop-slices/watermelon.wav",
	"res://assets/imported-audio/pop-slices/pineapple.wav",
	"res://assets/imported-audio/pop-slices/banana.wav",
	"res://assets/imported-audio/pop-slices/strawberry.wav",
	"res://assets/imported-audio/pop-slices/peach.wav",
	"res://assets/imported-audio/pop-slices/coconut.wav",
]
const PIP_SOUND_PATHS := [
	"res://assets/audio/pip/duck_double_01_bouncy.wav",
	"res://assets/audio/pip/duck_double_03_derpy.wav",
	"res://assets/audio/pip/duck_quack_innocent_deep_short_04.wav",
]
const ChestSoundBank = preload("res://scripts/chest_sound_bank.gd")
const ChestFeel = preload("res://scripts/chest_feel.gd")
const CHEST_EVENT_CHANNELS := 3

signal status_changed(message: String)
signal word_failed

var music: AudioStreamPlayer
var effect: AudioStreamPlayer
var voice: AudioStreamPlayer
var pip_reaction: AudioStreamPlayer
var pop_launch: AudioStreamPlayer
var match_voice_hit: AudioStreamPlayer
var chest_charge: AudioStreamPlayer
var muted: bool = false
var active: bool = false
var current_theme: String = ""
var cache: Dictionary = {}
var available: bool = true
var _playback_requests: Dictionary = {}
var _music_error: bool = false
var _pop_slice_paths: Array[String] = []
var _pop_slice_rng := RandomNumberGenerator.new()
var _last_pop_slice_path: String = ""
var _pop_players: Array[AudioStreamPlayer] = []
var _pop_next_player: int = 0
var _pop_last_player: AudioStreamPlayer
var _pop_launch_path: String = POP_LAUNCH_FALLBACK
var _pip_rng := RandomNumberGenerator.new()
var _last_pip_path: String = ""
var _pip_voice_request: int = -1
var _speech_debug_mix: float = 1.0
var _pip_reaction_gain: float = 0.68
var _chest_charge_active: bool = false
var _chest_charge_progress: float = -1.0
var _chest_tension_progress: float = -1.0
var _chest_last_hold_pulse: int = 0
var _chest_last_tension_pulse: int = 0
var _chest_anticipating: bool = false
var _chest_motion_finished: bool = false
var _chest_music_duck: float = 1.0
var _chest_charge_loop: AudioStreamWAV
var _chest_theme: String = "spring"
var _chest_phase: String = "idle"
var _chest_seen: Dictionary = {}
var _chest_rewarded: bool = false
var _chest_players: Array[AudioStreamPlayer] = []
var _chest_next_player: int = 0
var _chest_fallbacks: Dictionary = {}


func _ready() -> void:
	_pop_slice_rng.randomize()
	_pip_rng.randomize()
	for path in POP_SLICE_PATHS:
		if ResourceLoader.exists(path):
			_pop_slice_paths.append(path)
	var reference_paths: Array[String] = []
	for path: String in POP_REFERENCE_PATHS:
		var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if stream is AudioStreamWAV and not stream.stereo and stream.mix_rate == 44100 \
			and stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED \
			and stream.get_length() >= 0.20 and stream.get_length() <= 0.50:
			reference_paths.append(path)
			cache[path] = stream
	if reference_paths.size() == POP_REFERENCE_PATHS.size():
		_pop_slice_paths = reference_paths
	for index in range(POP_HIT_CHANNELS):
		_pop_players.append(_player(POP_HIT_GAIN))
	pop_launch = _player(POP_LAUNCH_GAIN)
	var launch_stream: AudioStream = load(POP_LAUNCH_PATH) if ResourceLoader.exists(POP_LAUNCH_PATH) else null
	if launch_stream is AudioStreamWAV and not launch_stream.stereo and launch_stream.mix_rate == 44100 \
		and launch_stream.format == AudioStreamWAV.FORMAT_16_BITS and launch_stream.loop_mode == AudioStreamWAV.LOOP_DISABLED \
		and launch_stream.get_length() >= 0.1 and launch_stream.get_length() <= 0.3:
		_pop_launch_path = POP_LAUNCH_PATH
		cache[POP_LAUNCH_PATH] = launch_stream
	_stream(_pop_launch_path)
	match_voice_hit = _player(MATCH_VOICE_HIT_GAIN)
	_stream(MATCH_VOICE_HIT_PATH)
	music = _player(0.12)
	effect = _player(0.24)
	voice = _player(0.64)
	voice.finished.connect(_voice_finished)
	if OS.has_feature("web"):
		available = bool(JavaScriptBridge.eval("Boolean(window.AudioContext || window.webkitAudioContext)"))


func _player(gain: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = linear_to_db(gain)
	add_child(player)
	return player


func interact(theme_id: String, play_music: bool = true) -> void:
	if muted:
		return
	if not available:
		active = false
		status_changed.emit("Sound is not available in this browser.")
		return
	active = true
	status_changed.emit("")
	if not play_music:
		stop_music()
		return
	if current_theme == theme_id and music.playing and not _music_error:
		return
	current_theme = theme_id
	_play(music, "res://assets/audio/bgm/" + theme_id + ".wav", true)


func cue(effect_id: String = "", voice_id: String = "") -> void:
	if muted or not active or not available:
		return
	if not effect_id.is_empty():
		var path: String = "res://assets/audio/sfx/" + effect_id + ".wav"
		if effect_id == "pop-slice":
			if _speech_debug_mix > 0.0:
				_play_pop_slice()
		elif effect_id == "pop-launch":
			if _speech_debug_mix > 0.0:
				_play(pop_launch, _pop_launch_path)
		else:
			_play(effect, path)
	if not voice_id.is_empty():
		say("res://assets/audio/voice/" + voice_id + ".wav")


func _play_pop_slice() -> void:
	# Short overlapping slices keep simultaneous words from cutting off each
	# other. A fourth hit replaces the oldest of three fixed channels.
	var player: AudioStreamPlayer = _pop_players[_pop_next_player]
	_pop_next_player = (_pop_next_player + 1) % _pop_players.size()
	_pop_last_player = player
	_play(player, _next_pop_slice())


func play_match_voice_hit() -> void:
	if not muted and active and available and _speech_debug_mix > 0.0:
		_play(match_voice_hit, MATCH_VOICE_HIT_PATH)


func stop_match_voice_hit() -> void:
	if match_voice_hit != null:
		_stop(match_voice_hit)


func last_pop_player() -> AudioStreamPlayer:
	return _pop_last_player


func stop_pop_slices() -> void:
	for player: AudioStreamPlayer in _pop_players:
		_stop(player)
		player.stream = null
	_pop_next_player = 0
	_pop_last_player = null


func stop_pop_sounds() -> void:
	stop_pop_slices()
	if pop_launch != null:
		_stop(pop_launch)
		pop_launch.stream = null


func _next_pop_slice() -> String:
	# Use a separate generator so sound choices never change the vocabulary or rewards.
	var choices: Array[String] = _pop_slice_paths.duplicate()
	if choices.size() > 1:
		choices.erase(_last_pop_slice_path)
	if choices.is_empty():
		# External source audio stays private; clean checkouts can still play.
		return POP_SLICE_PATH if ResourceLoader.exists(POP_SLICE_PATH) else "res://assets/audio/sfx/select.wav"
	_last_pop_slice_path = choices[_pop_slice_rng.randi_range(0, choices.size() - 1)]
	return _last_pop_slice_path


func next_pip_sound() -> String:
	# Keep mascot sounds independent from cards, rewards and other random effects.
	var choices: Array = PIP_SOUND_PATHS.duplicate()
	choices.erase(_last_pip_path)
	_last_pip_path = choices[_pip_rng.randi_range(0, choices.size() - 1)]
	return _last_pip_path


func play_pip() -> void:
	if muted or not active or not available or is_pip_busy():
		return
	# Ignore repeated greetings while their voice is still active.
	# The shared channel keeps existing mute, page and microphone cleanup.
	say(next_pip_sound())


func is_pip_busy() -> bool:
	if not active or muted or not available:
		return false
	return _pip_voice_request >= 0 and _pip_voice_request == _playback_requests.get(voice, -1)


func play_pip_reaction(correct: bool) -> void:
	_play_pip_call(PIP_SOUND_PATHS[0] if correct else PIP_SOUND_PATHS[2],
		1.12 if correct else 0.80, 0.68 if correct else 0.54)


func _play_pip_call(path: String, pitch: float, gain: float) -> void:
	if muted or not active or not available or _speech_debug_mix <= 0.0:
		return
	if pip_reaction == null:
		pip_reaction = _player(0.68)
	# Gameplay feelings have their own short, nonverbal voice. They cannot
	# replace a card's pronunciation or its answer cue.
	pip_reaction.pitch_scale = pitch
	_pip_reaction_gain = gain
	pip_reaction.volume_db = linear_to_db(_pip_reaction_gain * _speech_debug_mix)
	_play(pip_reaction, path)


func set_speech_debug_mix(value: float) -> bool:
	if value not in [0.0, 0.35, 1.0]:
		return false
	_speech_debug_mix = value
	# Only the microphone-competing gameplay channels participate in this
	# temporary comparison. Music, spoken words and rewards keep their mix.
	for player: AudioStreamPlayer in _pop_players:
		player.volume_db = linear_to_db(maxf(0.0001, POP_HIT_GAIN * value))
	if pop_launch != null:
		pop_launch.volume_db = linear_to_db(maxf(0.0001, POP_LAUNCH_GAIN * value))
	if match_voice_hit != null:
		match_voice_hit.volume_db = linear_to_db(maxf(0.0001, MATCH_VOICE_HIT_GAIN * value))
	if pip_reaction != null:
		pip_reaction.volume_db = linear_to_db(maxf(0.0001, _pip_reaction_gain * value))
	if value == 0.0:
		stop_pop_sounds()
		stop_match_voice_hit()
		stop_pip_reaction()
	return true


func stop_pip_reaction() -> void:
	if pip_reaction != null:
		_stop(pip_reaction)
		pip_reaction.stream = null


func prepare_chest(theme_id: String) -> void:
	var theme: String = ChestSoundBank.theme_id(theme_id)
	if theme != _chest_theme or _chest_phase == "finished":
		stop_chest_performance()
	_chest_theme = theme
	for cue_name: String in ChestSoundBank.CUES:
		var path: String = ChestSoundBank.path_for(theme, cue_name)
		_stream(path, cue_name == "charge")


func _chest_stream(theme: String, cue_name: String) -> AudioStreamWAV:
	var path: String = ChestSoundBank.path_for(theme, cue_name)
	var stream: AudioStream = _stream(path, cue_name == "charge")
	if stream is AudioStreamWAV:
		return stream
	if not _chest_fallbacks.has(path):
		_chest_fallbacks[path] = ChestSoundBank.fallback(theme, cue_name)
	return _chest_fallbacks[path]


func _ensure_chest_players() -> void:
	if chest_charge != null:
		return
	chest_charge = _player(0.075)
	for index in range(CHEST_EVENT_CHANNELS):
		var player: AudioStreamPlayer = _player(0.36)
		player.finished.connect(_chest_event_finished.bind(player))
		_chest_players.append(player)


func _chest_event_finished(player: AudioStreamPlayer) -> void:
	if not player.playing:
		player.stream = null


func _play_chest_event(cue_name: String, gain: float = 0.36, pitch: float = 1.0) -> void:
	_ensure_chest_players()
	# A fixed three-channel ring bounds overlap even under rapid input. Reusing
	# a channel replaces its old sound; it never creates a queued callback.
	var player: AudioStreamPlayer = _chest_players[_chest_next_player]
	_chest_next_player = (_chest_next_player + 1) % CHEST_EVENT_CHANNELS
	player.stop()
	player.stream = _chest_stream(_chest_theme, cue_name)
	player.pitch_scale = pitch
	player.volume_db = linear_to_db(gain)
	player.play()


func chest_cue(theme_id: String, cue_name: String, step: int = 0) -> void:
	if muted or not active or not available or _chest_motion_finished:
		return
	var theme: String = ChestSoundBank.theme_id(theme_id)
	if cue_name.begins_with("charge_step"):
		if cue_name != "charge_step":
			step = cue_name.trim_prefix("charge_step").to_int()
		cue_name = "step"
	if cue_name == "press":
		if _chest_phase == "holding" and theme == _chest_theme:
			return
		stop_chest_performance()
		_chest_theme = theme
		_chest_phase = "holding"
	elif cue_name == "opening":
		if theme != _chest_theme or _chest_phase in ["opening", "finished", "cancelled"]:
			return
		# Direct openings (including reduced motion) are an explicit start too.
		_chest_phase = "opening"
		_chest_rewarded = false
		_start_chest_tension()
	elif theme != _chest_theme:
		return
	var event_key: String = cue_name + str(step)
	if _chest_seen.has(event_key):
		return
	match cue_name:
		"press":
			_play_chest_event("press", 0.33)
		"step":
			if _chest_phase not in ["holding", "opening"] or step < 1 or step > 3:
				return
			# Progress stars stay silent; the shared hold and opening beats own
			# the full rhythm, without extra clicks between their strikes.
			pass
		"hold_pulse":
			if _chest_phase != "holding" or not _chest_charge_active or step <= _chest_last_hold_pulse or step > ChestFeel.HOLD_PULSE_TIMES.size():
				return
			_chest_last_hold_pulse = step
			var energy: float = ChestFeel.tension(float(ChestFeel.HOLD_PULSE_TIMES[step - 1]) - ChestFeel.HOLD_SECONDS)
			_play_chest_pulse(energy)
		"cancel":
			if _chest_phase not in ["holding", "opening"]:
				return
			stop_chest_performance()
			_chest_phase = "cancelled"
			_play_chest_event("cancel", 0.22)
		"opening":
			# Keep the sustained material bed alive through the hold transition.
			# An additional attack here would sound like another buildup starting.
			pass
		"tension_pulse":
			if _chest_phase != "opening" or _chest_anticipating or _chest_tension_progress < 0.0 or step <= _chest_last_tension_pulse or step > ChestFeel.PULSE_TIMES.size():
				return
			_chest_last_tension_pulse = step
			# Read the strike's own timestamp, not the previous UI frame's energy.
			var energy: float = ChestFeel.tension(float(ChestFeel.PULSE_TIMES[step - 1]))
			_play_chest_pulse(energy)
		"anticipation":
			if _chest_phase != "opening" or _chest_tension_progress < 0.0 or _chest_seen.has("unlock0"):
				return
			# Progress may already have quieted the bed on this frame. The
			# one-shot remains independently deduplicated by its delivered cue.
			_hold_chest_anticipation()
			_play_chest_event("opening", 0.32)
		"unlock", "release", "settle":
			if _chest_phase != "opening":
				return
			if cue_name == "unlock":
				if _chest_tension_progress < 0.0:
					return
				_hold_chest_anticipation()
			else:
				_chest_anticipating = true
			if cue_name == "release" or cue_name == "settle":
				# Unlock stays inside the breath. Release takes over the sound field,
				# even when a long frame skipped the transition or unlock cue.
				stop_chest_charge()
				if cue_name == "release":
					# Give the release impact and expanding bloom a clear onset.
					# The held breath and latch should not mask that contact.
					for player: AudioStreamPlayer in _chest_players:
						player.stop()
						player.stream = null
				# Keep the physical release and landing in front of the music.
				# Completion restores the normal mix after the material tail.
				_chest_music_duck = 0.45 if cue_name == "settle" else 0.20
				_update_music_gain()
			_play_chest_event(cue_name, 0.86 if cue_name == "release" else (0.055 if cue_name == "unlock" else 0.42))
		_:
			return
	_chest_seen[event_key] = true


func _play_chest_pulse(energy: float) -> void:
	# Clear material attacks carry the rhythm from the first held beat onward.
	# Keep headroom for the final release instead of making the pressure hum loud.
	# Retain the cavity's low body instead of pitching the whole chest upward.
	# Successive textures add material detail and a broad air edge, alongside
	# cadence and the separate pressure texture, without transposing the body.
	_play_chest_event(ChestSoundBank.pulse_cue(energy), lerpf(0.30, 0.56, energy), 1.0)


func chest_reward(theme_id: String, explicit_retry: bool = false) -> void:
	# The caller invokes this only after the reward save succeeds. The material
	# opening cues never contain this success accent, so a failed save stays quiet.
	if muted or not active or not available or _chest_rewarded:
		return
	var resumed_receipt: bool = explicit_retry and _chest_phase in ["idle", "cancelled"]
	if ChestSoundBank.theme_id(theme_id) != _chest_theme or (_chest_phase != "opening" and not resumed_receipt):
		return
	# A user-requested successful save retry may follow a background or mute
	# that cleared the performance. Acknowledge that save without replaying its
	# old press, charge, opening or release beats.
	_chest_rewarded = true
	_chest_phase = "finished"
	stop_chest_charge()
	_chest_music_duck = 1.0
	_update_music_gain()
	_play_chest_event("reward", 0.54)


func set_chest_charge(progress: float) -> void:
	if not is_finite(progress):
		return
	if muted or not active or not available:
		stop_chest_performance()
		return
	if _chest_phase in ["opening", "finished"]:
		return
	if not _chest_charge_active:
		# Only the hold's explicit beginning arms playback. A late progress event
		# after cancel, mute or completion cannot start another sound.
		if progress != 0.0:
			return
		_ensure_chest_players()
		_chest_charge_loop = _chest_stream(_chest_theme, "charge")
		if _chest_phase != "holding":
			_chest_seen.clear()
			_chest_rewarded = false
			_chest_phase = "holding"
		_chest_charge_active = true
		_chest_charge_progress = 0.0
		chest_charge.stream = _chest_charge_loop
		_apply_chest_tension_energy(0.0)
		chest_charge.play()
	# Both phases share one energy curve. Reaching the hold threshold changes
	# who owns progress, never the texture, playback position or intensity.
	_chest_charge_progress = maxf(_chest_charge_progress, clampf(progress, 0.0, 1.0))
	_apply_chest_tension_energy(ChestFeel.tension((_chest_charge_progress - 1.0) * ChestFeel.HOLD_SECONDS))


func _start_chest_tension() -> void:
	_ensure_chest_players()
	var continuing: bool = _chest_charge_active and chest_charge.playing and chest_charge.stream == _chest_charge_loop
	_chest_charge_active = false
	_chest_charge_progress = -1.0
	_chest_tension_progress = 0.0
	_chest_last_tension_pulse = 0
	_chest_anticipating = false
	if not continuing:
		_chest_charge_loop = _chest_stream(_chest_theme, "charge")
		chest_charge.stream = _chest_charge_loop
	set_chest_tension(ChestFeel.tension(0.0))
	if not continuing:
		chest_charge.play()


func set_chest_tension(progress: float) -> void:
	if not is_finite(progress):
		return
	if muted or not active or not available:
		stop_chest_performance()
		return
	# Only an explicit opening arms this bed. Frame updates cannot revive it
	# after anticipation, interruption or completion.
	if _chest_phase != "opening" or _chest_anticipating or _chest_tension_progress < 0.0:
		return
	_chest_tension_progress = maxf(_chest_tension_progress, clampf(progress, 0.0, 1.0))
	if _chest_tension_progress >= 1.0:
		# The steady held state must survive a frame that skips the short
		# breath cue. This changes the mix without replaying that one-shot.
		_hold_chest_anticipation()
	else:
		_apply_chest_tension_energy(_chest_tension_progress)


func _hold_chest_anticipation() -> void:
	if _chest_anticipating:
		return
	_chest_anticipating = true
	for player: AudioStreamPlayer in _chest_players:
		player.stop()
		player.stream = null
	if chest_charge != null and chest_charge.playing:
		chest_charge.pitch_scale = 1.42
		chest_charge.volume_db = linear_to_db(0.025)
	_chest_music_duck = 0.06
	_update_music_gain()


func _apply_chest_tension_energy(energy: float) -> void:
	# Pressure supports the accelerating attacks without masking their rhythm.
	# The shared early-rising curve makes the confirmation hold feel active too.
	chest_charge.pitch_scale = lerpf(0.92, 1.42, energy)
	chest_charge.volume_db = linear_to_db(lerpf(0.035, 0.22, energy))
	_chest_music_duck = lerpf(0.68, 0.20, energy)
	_update_music_gain()


func stop_chest_charge() -> void:
	_chest_charge_active = false
	_chest_charge_progress = -1.0
	_chest_tension_progress = -1.0
	if chest_charge != null:
		chest_charge.stop()
		chest_charge.stream = null


func finish_chest_motion() -> void:
	if _chest_phase != "opening" or _chest_motion_finished:
		return
	# The physical timeline can finish before persistence succeeds, especially
	# when reduced motion skips its release cues. Silence that performance while
	# retaining the pending receipt for a later successful save acknowledgement.
	_chest_motion_finished = true
	_chest_anticipating = true
	stop_chest_charge()
	for player: AudioStreamPlayer in _chest_players:
		player.stop()
		player.stream = null
	_chest_music_duck = 1.0
	_update_music_gain()


func stop_chest_performance() -> void:
	stop_chest_charge()
	for player: AudioStreamPlayer in _chest_players:
		player.stop()
		player.stream = null
	_chest_phase = "idle"
	_chest_seen.clear()
	_chest_rewarded = false
	_chest_next_player = 0
	_chest_last_hold_pulse = 0
	_chest_last_tension_pulse = 0
	_chest_anticipating = false
	_chest_motion_finished = false
	_chest_music_duck = 1.0
	_update_music_gain()


func say(path: String) -> void:
	if muted or not active:
		return
	_play(voice, path)


func _play(player: AudioStreamPlayer, path: String, loop: bool = false) -> void:
	_stop(player)
	var request_id: int = _playback_requests[player]
	if player == voice and path in PIP_SOUND_PATHS:
		_pip_voice_request = request_id
	var stream: AudioStream = await _stream(path, loop)
	# State callbacks may cancel or replace this request during preparation.
	if request_id != _playback_requests[player] or not active or muted or not available:
		if player == voice and _pip_voice_request == request_id:
			_pip_voice_request = -1
		return
	if stream == null:
		if player == voice and _pip_voice_request == request_id:
			_pip_voice_request = -1
		if player == music:
			current_theme = ""
			_music_error = true
		status_changed.emit("Sound could not load. You can keep playing. Tap a card to try again.")
		if player == voice and path.get_file().begins_with("word-"):
			word_failed.emit()
		return
	player.stream = stream
	if player == music:
		_music_error = false
		status_changed.emit("")
		_update_music_gain()
	player.play()
	if player == voice:
		_update_music_gain()


func _stream(path: String, loop: bool = false) -> AudioStream:
	# Every recording is already in the startup pack. Loading a stream only
	# reads local resources; gameplay never waits for an audio HTTP request.
	if cache.has(path):
		return cache[path]
	var resource: Resource
	if ResourceLoader.exists(path):
		resource = load(path)
	if resource is AudioStream:
		if not loop:
			cache[path] = resource
		elif resource is AudioStreamWAV:
			var looping: AudioStreamWAV = resource.duplicate()
			looping.loop_mode = AudioStreamWAV.LOOP_FORWARD
			looping.loop_begin = 0
			looping.loop_end = int(round(looping.get_length() * looping.mix_rate))
			cache[path] = looping
	return cache.get(path)


func _stop(player: AudioStreamPlayer) -> void:
	_playback_requests[player] = _playback_requests.get(player, 0) + 1
	player.stop()
	if player == voice:
		_voice_finished()


func _voice_finished() -> void:
	_pip_voice_request = -1
	_update_music_gain()


func _update_music_gain() -> void:
	if music != null:
		var speaking: bool = voice != null and voice.playing
		music.volume_db = linear_to_db((0.04 if speaking else 0.12) * _chest_music_duck)


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		halt()
	status_changed.emit("")


func stop_music() -> void:
	current_theme = ""
	_stop(music)


func stop_voice() -> void:
	if voice != null:
		_stop(voice)


func halt(keep_match_voice_hit: bool = false) -> void:
	active = false
	if not keep_match_voice_hit:
		stop_match_voice_hit()
	stop_pop_sounds()
	stop_pip_reaction()
	stop_chest_performance()
	if music != null:
		stop_music()
		_stop(effect)
		_stop(voice)
		music.volume_db = linear_to_db(0.12)


func _exit_tree() -> void:
	halt()
