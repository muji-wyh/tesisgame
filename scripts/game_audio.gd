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

signal status_changed(message: String)
signal word_failed
signal narration_state_changed(state: String)
signal _stream_loaded(path: String)

var music: AudioStreamPlayer
var effect: AudioStreamPlayer
var voice: AudioStreamPlayer
var narration: AudioStreamPlayer
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


func _ready() -> void:
	_pop_slice_rng.randomize()
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
	stop_narration()
	if music != null:
		stop_music()
		_stop(effect)
		_stop(voice)
		music.volume_db = linear_to_db(0.12)


func _exit_tree() -> void:
	halt()
