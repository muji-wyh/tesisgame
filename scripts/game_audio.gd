extends Node

signal status_changed(message: String)
signal _stream_loaded(path: String)

var music: AudioStreamPlayer
var effect: AudioStreamPlayer
var voice: AudioStreamPlayer
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


func _ready() -> void:
	music = _player(0.12)
	effect = _player(0.24)
	voice = _player(0.64)
	voice.finished.connect(_voice_finished)
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
		_play(effect, "res://assets/audio/sfx/" + effect_id + ".wav")
	if not voice_id.is_empty():
		say("res://assets/audio/voice/" + voice_id + ".wav")


func say(path: String) -> void:
	if muted or not active:
		return
	_play(voice, path)


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
		return
	player.stream = stream
	if player == music:
		_music_error = false
		status_changed.emit("")
		music.volume_db = linear_to_db(0.04 if voice.playing else 0.12)
	player.play()
	if player == voice:
		music.volume_db = linear_to_db(0.04)


func _stream(path: String, loop: bool = false) -> AudioStream:
	if cache.has(path):
		return cache[path]
	if _loading.has(path):
		while _loading.has(path):
			await _stream_loaded
		if cache.has(path):
			return cache[path]
		return await _stream(path, loop)
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
	if not voice.playing:
		music.volume_db = linear_to_db(0.12)


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		halt()
	status_changed.emit("")


func stop_music() -> void:
	current_theme = ""
	_music_pending = false
	_stop(music)


func halt() -> void:
	active = false
	if music != null:
		stop_music()
		_stop(effect)
		_stop(voice)
		music.volume_db = linear_to_db(0.12)
