extends Node

const POP_SLICE_PATH := "res://assets/imported-audio/pop-slice.wav"
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
const CHEST_EVENT_CHANNELS := 3

signal status_changed(message: String)
signal word_failed
signal narration_state_changed(state: String)
signal _stream_loaded(path: String)

var music: AudioStreamPlayer
var effect: AudioStreamPlayer
var voice: AudioStreamPlayer
var narration: AudioStreamPlayer
var chest_charge: AudioStreamPlayer
var narration_state: String = "idle"
var muted: bool = false
var active: bool = false
var current_theme: String = ""
var cache: Dictionary = {}
var available: bool = true
var remote_audio: Dictionary = {}
var _loading: Dictionary = {}
var _playback_requests: Dictionary = {}
var _music_pending: bool = false
var _music_error: bool = false
var _narration_generation: int = 0
var _narration_streams: Array[AudioStream] = []
var _narration_index: int = 0
var _pop_slice_paths: Array[String] = []
var _pop_slice_rng := RandomNumberGenerator.new()
var _last_pop_slice_path: String = ""
var _pip_rng := RandomNumberGenerator.new()
var _last_pip_path: String = ""
var _chest_charge_active: bool = false
var _chest_charge_progress: float = -1.0
var _chest_charge_loop: AudioStreamWAV
var _chest_charge_accent: AudioStreamWAV
var _chest_theme: String = "spring"
var _chest_phase: String = "idle"
var _chest_seen: Dictionary = {}
var _chest_rewarded: bool = false
var _chest_players: Array[AudioStreamPlayer] = []
var _chest_next_player: int = 0
var _chest_fallbacks: Dictionary = {}
var _chest_prime_pending: Dictionary = {}


func _ready() -> void:
	_pop_slice_rng.randomize()
	_pip_rng.randomize()
	for path in POP_SLICE_PATHS:
		if ResourceLoader.exists(path):
			_pop_slice_paths.append(path)
	music = _player(0.12)
	effect = _player(0.24)
	voice = _player(0.64)
	voice.finished.connect(_voice_finished)
	narration = _player(0.64)
	narration.finished.connect(_narration_finished)
	if OS.has_feature("web"):
		available = bool(JavaScriptBridge.eval("Boolean(window.AudioContext || window.webkitAudioContext)"))
		var host: JavaScriptObject = JavaScriptBridge.get_interface("wordBuddiesHost")
		if host != null:
			var assets: Variant = JSON.parse_string(str(host.audioAssets()))
			if assets is Dictionary:
				remote_audio = assets
			else:
				push_warning("Optional audio configuration could not load.")


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
	if current_theme == theme_id and (music.playing or _music_pending) and not _music_error:
		return
	current_theme = theme_id
	_music_pending = true
	_play(music, "res://assets/audio/bgm/" + theme_id + ".wav", true)


func cue(effect_id: String = "", voice_id: String = "") -> void:
	if muted or not active:
		return
	if not effect_id.is_empty():
		var path: String = "res://assets/audio/sfx/" + effect_id + ".wav"
		if effect_id == "pop-slice":
			path = _next_pop_slice()
		_play(effect, path)
	if not voice_id.is_empty():
		say("res://assets/audio/voice/" + voice_id + ".wav")


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
	if muted or not active or not available:
		return
	# The shared voice channel replaces the previous greeting on rapid taps and
	# already stops on mute, page changes and microphone activation.
	say(next_pip_sound())


func prepare_chest(theme_id: String) -> void:
	var theme: String = ChestSoundBank.theme_id(theme_id)
	if theme != _chest_theme or _chest_phase == "finished":
		stop_chest_performance()
	_chest_theme = theme
	for cue_name: String in ChestSoundBank.CUES:
		var path: String = ChestSoundBank.path_for(theme, cue_name)
		if not cache.has(path) and not _loading.has(path):
			_preload_chest_stream(path, cue_name == "charge")
	_prime_chest_fallbacks(theme)


func _prime_chest_fallbacks(theme: String) -> void:
	if _chest_prime_pending.has(theme):
		return
	_chest_prime_pending[theme] = true
	for cue_name: String in ChestSoundBank.CUES:
		var path: String = ChestSoundBank.path_for(theme, cue_name)
		if cache.has(path) or _chest_fallbacks.has(path):
			continue
		# Cold optional downloads should not make the first press render a bank
		# of samples. Prime at most one small fallback per frame while waiting.
		await get_tree().process_frame
		if not is_inside_tree() or theme != _chest_theme:
			break
		if not cache.has(path) and not _chest_fallbacks.has(path):
			_chest_fallbacks[path] = ChestSoundBank.fallback(theme, cue_name)
	_chest_prime_pending.erase(theme)


func _preload_chest_stream(path: String, loop: bool) -> void:
	# Preparing may fill the shared cache, but never owns playback. A download
	# completing after cancellation cannot replay the original gesture.
	await _stream(path, loop)


func _chest_stream(theme: String, cue_name: String) -> AudioStreamWAV:
	var path: String = ChestSoundBank.path_for(theme, cue_name)
	if cache.get(path) is AudioStreamWAV:
		return cache[path]
	if not _chest_fallbacks.has(path):
		_chest_fallbacks[path] = ChestSoundBank.fallback(theme, cue_name)
	return _chest_fallbacks[path]


func _ensure_chest_players() -> void:
	if chest_charge != null:
		return
	chest_charge = _player(0.075)
	chest_charge.finished.connect(_chest_charge_finished)
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
	if muted or not active or not available:
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
		if theme != _chest_theme or _chest_phase in ["opening", "finished"]:
			return
		# Direct openings (including reduced motion) are an explicit start too.
		_chest_phase = "opening"
		_chest_rewarded = false
		stop_chest_charge()
	elif theme != _chest_theme:
		return
	var event_key: String = cue_name + str(step)
	if _chest_seen.has(event_key):
		return
	match cue_name:
		"press":
			_play_chest_event("press", 0.33)
		"step":
			if _chest_phase != "holding" or step < 1 or step > 3:
				return
			_play_chest_event("step", 0.23 + float(step) * 0.035, 0.9 + float(step) * 0.11)
		"cancel":
			if _chest_phase != "holding":
				return
			stop_chest_performance()
			_chest_phase = "cancelled"
			_play_chest_event("cancel", 0.22)
		"opening":
			_play_chest_event("opening", 0.22)
		"unlock", "release", "settle":
			if _chest_phase != "opening":
				return
			_play_chest_event(cue_name, 0.45 if cue_name == "release" else 0.34)
		_:
			return
	_chest_seen[event_key] = true


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
	_play_chest_event("reward", 0.37)


func set_chest_charge(progress: float) -> void:
	if not is_finite(progress):
		return
	if muted or not active or not available:
		stop_chest_charge()
		return
	if not _chest_charge_active:
		# Only the hold's explicit beginning arms playback. A late progress event
		# after cancel, mute or completion cannot start another sound.
		if progress != 0.0:
			return
		_ensure_chest_players()
		_chest_charge_loop = _chest_stream(_chest_theme, "charge")
		_chest_charge_accent = _chest_stream(_chest_theme, "opening")
		if _chest_phase != "holding":
			_chest_seen.clear()
			_chest_rewarded = false
			_chest_phase = "holding"
		_chest_charge_active = true
		_chest_charge_progress = 0.0
		chest_charge.stream = _chest_charge_loop
		chest_charge.pitch_scale = 0.86
		chest_charge.volume_db = linear_to_db(0.075)
		chest_charge.play()
	# A quiet material pulse supports the three explicit visual charge steps.
	# Progress changes its rate without restarting or replacing the current clip.
	_chest_charge_progress = maxf(_chest_charge_progress, clampf(progress, 0.0, 1.0))
	var energy: float = pow(_chest_charge_progress, 1.35)
	chest_charge.pitch_scale = lerpf(0.86, 1.42, energy)
	chest_charge.volume_db = linear_to_db(lerpf(0.075, 0.19, energy))


func stop_chest_charge() -> void:
	_chest_charge_active = false
	_chest_charge_progress = -1.0
	if chest_charge != null:
		chest_charge.stop()
		chest_charge.stream = null


func complete_chest_charge() -> void:
	if not _chest_charge_active:
		return
	stop_chest_charge()
	_chest_phase = "opening"
	if muted or not active or not available:
		return
	# Preserve the generic API for callers outside the staged chest performance.
	# This is only a small material release, never the saved-reward accent.
	chest_charge.stream = _chest_charge_accent
	chest_charge.pitch_scale = 1.0
	chest_charge.volume_db = linear_to_db(0.22)
	chest_charge.play()


func _chest_charge_finished() -> void:
	if not _chest_charge_active and chest_charge != null and not chest_charge.playing:
		chest_charge.stream = null


func stop_chest_performance() -> void:
	stop_chest_charge()
	for player: AudioStreamPlayer in _chest_players:
		player.stop()
		player.stream = null
	_chest_phase = "idle"
	_chest_seen.clear()
	_chest_rewarded = false
	_chest_next_player = 0


func say(path: String) -> void:
	stop_narration()
	if muted or not active:
		return
	_play(voice, path)


func narrate(paths: Array[String]) -> void:
	stop_voice()
	if muted or not active or not available or paths.is_empty():
		_set_narration_state("unavailable")
		return
	var generation: int = _narration_generation
	_set_narration_state("loading")
	var loaded: Array[AudioStream] = []
	# Prepare the whole page before speaking. A missing word or closing sentence
	# must not leave Pip delivering only the first half of a report.
	for path in paths:
		var stream: AudioStream = await _stream(path)
		if generation != _narration_generation or not is_inside_tree() or not active or muted or not available:
			return
		if stream == null:
			_set_narration_state("unavailable")
			status_changed.emit("Pip's voice could not load. Read along or tap Try Pip again.")
			return
		loaded.append(stream)
	_narration_streams = loaded
	_narration_index = 0
	_play_narration_clip()


func stop_narration() -> void:
	_narration_generation += 1
	_narration_streams.clear()
	_narration_index = 0
	if narration != null:
		narration.stop()
		narration.stream = null
	_set_narration_state("idle")
	_update_music_gain()


func _play_narration_clip() -> void:
	if muted or not active or not available or _narration_index >= _narration_streams.size():
		stop_narration()
		return
	narration.stream = _narration_streams[_narration_index]
	narration.play()
	_set_narration_state("speaking")
	_update_music_gain()


func _narration_finished() -> void:
	if narration_state != "speaking" or _narration_streams.is_empty():
		return
	_narration_index += 1
	_play_narration_clip()


func _set_narration_state(state: String) -> void:
	if narration_state != state:
		narration_state = state
		narration_state_changed.emit(state)


func _play(player: AudioStreamPlayer, path: String, loop: bool = false) -> void:
	_stop(player)
	var request_id: int = _playback_requests[player]
	var stream: AudioStream = await _stream(path, loop)
	# A completed download may be cached, but must never revive an obsolete cue.
	if request_id != _playback_requests[player] or not active or muted or not available:
		return
	if player == music:
		_music_pending = false
	if stream == null:
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
	if cache.has(path):
		return cache[path]
	if _loading.has(path):
		while _loading.has(path):
			await _stream_loaded
		if cache.has(path):
			return cache[path]
		# Every waiter shares this attempt's result. A cancelled request must not
		# turn a failed shared download into another serialized retry.
		return null
	_loading[path] = true
	var resource: Resource
	if remote_audio.has(path):
		resource = await _download(str(remote_audio[path]))
	elif ResourceLoader.exists(path):
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
	_loading.erase(path)
	_stream_loaded.emit(path)
	return cache.get(path)


func _download(url: String) -> Resource:
	var request := HTTPRequest.new()
	request.timeout = 15.0
	request.body_size_limit = 4 * 1024 * 1024
	add_child(request)
	if request.request(url) != OK:
		request.queue_free()
		return null
	var response: Array = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		return null
	var body: PackedByteArray = response[3]
	if body.size() < 4 or not body.slice(0, 4).get_string_from_ascii() in ["RSRC", "RSCC"]:
		return null
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(body)
	var filename := "audio-" + digest.finish().hex_encode().substr(0, 16) + ".sample"
	if url.get_file() != filename:
		return null
	# Imported .sample files are Godot resources, not raw WAV buffers.
	# Keep only the decoded resource; the browser caches the immutable HTTP asset.
	var local_path := "user://" + filename
	var file := FileAccess.open(local_path, FileAccess.WRITE)
	if file == null:
		return null
	file.store_buffer(body)
	var stored: bool = file.get_error() == OK
	file.close()
	var resource: Resource
	if stored:
		resource = ResourceLoader.load(local_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(local_path)
	return resource


func _stop(player: AudioStreamPlayer) -> void:
	_playback_requests[player] = _playback_requests.get(player, 0) + 1
	player.stop()
	if player == voice:
		_voice_finished()


func _voice_finished() -> void:
	_update_music_gain()


func _update_music_gain() -> void:
	if music != null:
		var speaking: bool = (voice != null and voice.playing) or (narration != null and narration.playing)
		music.volume_db = linear_to_db(0.04 if speaking else 0.12)


func set_muted(value: bool) -> void:
	var was_narrating: bool = narration_state in ["loading", "speaking"]
	muted = value
	if muted:
		halt()
		if was_narrating:
			_set_narration_state("unavailable")
	status_changed.emit("")


func stop_music() -> void:
	current_theme = ""
	_music_pending = false
	_stop(music)


func stop_voice() -> void:
	stop_narration()
	if voice != null:
		_stop(voice)


func halt() -> void:
	active = false
	stop_chest_performance()
	stop_narration()
	if music != null:
		stop_music()
		_stop(effect)
		_stop(voice)
		music.volume_db = linear_to_db(0.12)


func _exit_tree() -> void:
	halt()
