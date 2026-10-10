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
const PAIR_FEEDBACK_PATHS := {
	true: "res://assets/imported-audio/pair-feedback/right.wav",
	false: "res://assets/imported-audio/pair-feedback/wrong.wav",
}
const PAIR_FEEDBACK_GAIN := 0.48
const UI_CLICK_PATH := "res://assets/imported-audio/ui-click/select.wav"
const UI_CLICK_GAIN := 0.48
const JELLY_PATHS := {
	"pick": UI_CLICK_PATH,
	"release": "res://assets/imported-audio/chest-reference/step.wav",
	"land": "res://assets/audio/jelly-match/land.wav",
	"merge": "res://assets/audio/jelly-match/merge.wav",
	"pop": "res://assets/audio/jelly-match/clear.wav",
	"danger": "res://assets/audio/jelly-match/danger.wav",
	"reward": "res://assets/imported-audio/chest-reference/reward.wav",
	"fragment": UI_CLICK_PATH,
	"assemble": "res://assets/imported-audio/chest-reference/step-detail.wav",
}
const JELLY_GAINS := {
	"pick": 0.64, "release": 0.38, "land": 0.35,
	"merge": 1.0, "pop": 0.90, "danger": 0.52, "reward": 0.36,
	"fragment": 0.30, "assemble": 0.28,
}
const JELLY_SECONDARY_CUES := ["pick", "release", "land"]
const JELLY_SPEECH_DB: float = -6.0
const ROUND_CELEBRATION_PATHS := {
	"step": "res://assets/imported-audio/chest-reference/step.wav",
	"step-detail": "res://assets/imported-audio/chest-reference/step-detail.wav",
	"reward": "res://assets/imported-audio/chest-reference/reward.wav",
}
const ROUND_CELEBRATION_GAINS := {"step": 0.32, "step-detail": 0.28, "reward": 0.44}
const ROUND_CELEBRATION_CHANNELS := 2
const ROUND_CELEBRATION_MUSIC_DB := -6.0
const ROUND_CELEBRATION_SPEECH_DB := -8.0
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
const PIP_REACTION_PATHS := {
	true: "res://assets/audio/pip/duck_double_01_bouncy.wav",
	false: "res://assets/audio/pip/duck_quack_innocent_deep_short_04.wav",
}
const ChestSoundBank = preload("res://scripts/chest_sound_bank.gd")
const ChestFeel = preload("res://scripts/chest_feel.gd")
const CHEST_EVENT_CHANNELS := 3

signal status_changed(message: String)

var music: AudioStreamPlayer
var effect: AudioStreamPlayer
var voice: AudioStreamPlayer
var pip_reaction: AudioStreamPlayer
var pop_launch: AudioStreamPlayer
var pair_feedback: AudioStreamPlayer
var ui_click: AudioStreamPlayer
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
var _round_celebration_id: String = ""
var _round_celebration_seen: Dictionary = {}
var _round_celebration_players: Array[AudioStreamPlayer] = []
var _round_celebration_gains: Dictionary = {}
var _round_celebration_next_player: int = 0
var _jelly_players: Array[AudioStreamPlayer] = []
var _jelly_gains: Dictionary = {}
var _jelly_cues: Dictionary = {}
var _jelly_next_player: int = 0


func _ready() -> void:
	set_process(false)
	_pop_slice_rng.randomize()
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
	pair_feedback = _player(PAIR_FEEDBACK_GAIN)
	for path: String in PAIR_FEEDBACK_PATHS.values():
		_stream(path)
	ui_click = _player(UI_CLICK_GAIN)
	_stream(UI_CLICK_PATH)
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
		stop_round_celebration()
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


func play_pair_feedback(correct: bool) -> void:
	if not muted and active and available and _speech_debug_mix > 0.0:
		_play(pair_feedback, PAIR_FEEDBACK_PATHS[correct])


func stop_pair_feedback() -> void:
	if pair_feedback != null:
		_stop(pair_feedback)
		pair_feedback.stream = null


func play_ui_click() -> void:
	# Navigation can run while gameplay audio is inactive or the microphone is on.
	if not muted and available and _speech_debug_mix > 0.0:
		_play(ui_click, UI_CLICK_PATH)


func stop_ui_click() -> void:
	if ui_click != null:
		_stop(ui_click)
		ui_click.stream = null


func play_jelly_cue(cue_name: String) -> void:
	if muted or not active or not available or not JELLY_PATHS.has(cue_name):
		return
	if cue_name == "danger":
		stop_jelly_danger()
	if _jelly_players.is_empty():
		for index in range(3):
			var channel: AudioStreamPlayer = _player(1.0)
			channel.finished.connect(func() -> void: _jelly_cues.erase(channel))
			_jelly_players.append(channel)
	var player: AudioStreamPlayer = _jelly_players[_jelly_next_player]
	if cue_name != "danger" and _jelly_cues.get(player, "") == "danger":
		# A concurrent merge must not steal the still-active countdown warning.
		player = _jelly_players[(_jelly_next_player + 1) % _jelly_players.size()]
	if cue_name in JELLY_SECONDARY_CUES:
		# Short input and material cues must not steal answers, rewards or warnings.
		var idle: Array[AudioStreamPlayer] = []
		for candidate: AudioStreamPlayer in _jelly_players:
			if not candidate.playing and not _jelly_cues.has(candidate):
				idle.append(candidate)
		if idle.is_empty():
			return
		player = idle[0]
	_jelly_next_player = (_jelly_players.find(player) + 1) % _jelly_players.size()
	_jelly_gains[player] = float(JELLY_GAINS[cue_name])
	_jelly_cues[player] = cue_name
	_update_jelly_gain()
	_play(player, JELLY_PATHS[cue_name])
	set_process(true)


func _update_jelly_gain() -> void:
	var duck_db: float = JELLY_SPEECH_DB if voice != null and voice.playing else 0.0
	for player: AudioStreamPlayer in _jelly_players:
		player.volume_db = linear_to_db(float(_jelly_gains.get(player, 1.0))) + duck_db


func stop_jelly_danger() -> void:
	# Cancel pending requests as well as audible tails once a clear makes space.
	# Replacing a countdown beat also prevents stacked warning recordings.
	for player: AudioStreamPlayer in _jelly_players:
		if _jelly_cues.get(player, "") == "danger":
			_stop(player)
			player.stream = null
			_jelly_cues.erase(player)


func stop_jelly_sounds() -> void:
	for player: AudioStreamPlayer in _jelly_players:
		_stop(player)
		player.stream = null
	_jelly_cues.clear()
	_jelly_next_player = 0


func begin_round_celebration(round_id: String) -> void:
	if round_id.is_empty() or muted or not active or not available:
		stop_round_celebration()
		return
	if _round_celebration_id == round_id:
		return
	stop_round_celebration()
	_round_celebration_id = round_id
	for path: String in ROUND_CELEBRATION_PATHS.values():
		_stream(path)
	_update_music_gain()
	set_process(true)


func play_round_celebration_cue(round_id: String, cue_name: String) -> void:
	if muted or not active or not available:
		stop_round_celebration()
		return
	if round_id.is_empty() or round_id != _round_celebration_id \
		or not ROUND_CELEBRATION_PATHS.has(cue_name) or _round_celebration_seen.has(cue_name):
		return
	# These are presentation beats, independent of opening or saving a chest.
	# A missing recording consumes its cue without delaying the visual timeline.
	_round_celebration_seen[cue_name] = true
	if _round_celebration_players.is_empty():
		for index in range(ROUND_CELEBRATION_CHANNELS):
			var channel: AudioStreamPlayer = _player(1.0)
			channel.finished.connect(_round_celebration_event_finished.bind(channel))
			_round_celebration_players.append(channel)
	var player: AudioStreamPlayer = _round_celebration_players[_round_celebration_next_player]
	_round_celebration_next_player = (_round_celebration_next_player + 1) % ROUND_CELEBRATION_CHANNELS
	_round_celebration_gains[player] = float(ROUND_CELEBRATION_GAINS[cue_name])
	player.pitch_scale = 1.0
	_update_round_celebration_gain()
	player.stream = null
	_play(player, ROUND_CELEBRATION_PATHS[cue_name])


func _round_celebration_event_finished(player: AudioStreamPlayer) -> void:
	if not player.playing:
		player.stream = null


func stop_round_celebration() -> void:
	_round_celebration_id = ""
	_round_celebration_seen.clear()
	_round_celebration_next_player = 0
	for player: AudioStreamPlayer in _round_celebration_players:
		_stop(player)
		player.stream = null
		player.volume_db = linear_to_db(float(_round_celebration_gains.get(player, 1.0)))
	set_process(not _jelly_players.is_empty())
	_update_music_gain()


func _update_round_celebration_gain() -> void:
	var speaking: bool = voice != null and voice.playing
	var duck: float = ROUND_CELEBRATION_SPEECH_DB if speaking and not _round_celebration_id.is_empty() else 0.0
	for player: AudioStreamPlayer in _round_celebration_players:
		player.volume_db = linear_to_db(float(_round_celebration_gains.get(player, 1.0))) + duck


func _process(_delta: float) -> void:
	if muted or not active or not available:
		stop_round_celebration()
		stop_jelly_sounds()
		set_process(false)
		return
	var jelly_playing: bool = false
	for player: AudioStreamPlayer in _jelly_players:
		jelly_playing = jelly_playing or player.playing
	_update_jelly_gain()
	if _round_celebration_id.is_empty() and not jelly_playing:
		set_process(false)
		return
	# Actual playback, including a natural word ending, controls the cue mix.
	_update_round_celebration_gain()


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


func play_pip_reaction(correct: bool) -> void:
	_play_pip_call(PIP_REACTION_PATHS[correct],
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
	if pair_feedback != null:
		pair_feedback.volume_db = linear_to_db(maxf(0.0001, PAIR_FEEDBACK_GAIN * value))
	if ui_click != null:
		ui_click.volume_db = linear_to_db(maxf(0.0001, UI_CLICK_GAIN * value))
	if pip_reaction != null:
		pip_reaction.volume_db = linear_to_db(maxf(0.0001, _pip_reaction_gain * value))
	if value == 0.0:
		stop_ui_click()
		stop_pop_sounds()
		stop_pair_feedback()
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
	# Recorded cues are shared; their emergency material textures are themed.
	var fallback_key: String = "%s/%s" % [ChestSoundBank.theme_id(theme), cue_name]
	if not _chest_fallbacks.has(fallback_key):
		_chest_fallbacks[fallback_key] = ChestSoundBank.fallback(theme, cue_name)
	return _chest_fallbacks[fallback_key]


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
	# Three short recorded attacks follow the shared physical beat sequence.
	# Preserve their pitch and leave headroom for the longer opening flourish.
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
	var stream: AudioStream = await _stream(path, loop)
	# State callbacks may cancel or replace this request during preparation.
	if request_id != _playback_requests[player] or (not active and player != ui_click) or muted or not available:
		return
	if stream == null:
		if player == music:
			current_theme = ""
			_music_error = true
		status_changed.emit("Sound could not load. You can keep playing. Tap a card to try again.")
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
	_update_music_gain()


func _update_music_gain() -> void:
	if music != null:
		var speaking: bool = voice != null and voice.playing
		var celebration_db: float = ROUND_CELEBRATION_MUSIC_DB if not _round_celebration_id.is_empty() else 0.0
		music.volume_db = linear_to_db((0.04 if speaking else 0.12) * _chest_music_duck) + celebration_db
	_update_round_celebration_gain()


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		stop_ui_click()
		halt()
	status_changed.emit("")


func stop_music() -> void:
	current_theme = ""
	_stop(music)


func stop_voice() -> void:
	if voice != null:
		_stop(voice)


func halt(keep_pair_feedback: bool = false) -> void:
	# Screen changes silence gameplay, while their short UI acknowledgement finishes.
	# Muting, backgrounding and shutdown explicitly stop the UI channel too.
	active = false
	if not keep_pair_feedback:
		stop_pair_feedback()
	stop_pop_sounds()
	stop_jelly_sounds()
	stop_pip_reaction()
	stop_round_celebration()
	stop_chest_performance()
	if music != null:
		stop_music()
		_stop(effect)
		_stop(voice)
		music.volume_db = linear_to_db(0.12)


func _exit_tree() -> void:
	stop_ui_click()
	halt()
