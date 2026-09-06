extends Node

signal status_changed(message: String)

var music: AudioStreamPlayer
var effect: AudioStreamPlayer
var voice: AudioStreamPlayer
var muted: bool = false
var active: bool = false
var current_theme: String = ""
var cache: Dictionary = {}
var available: bool = true


func _ready() -> void:
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
		music.stop()
		return
	if current_theme == theme_id and music.playing:
		return
	music.stop()
	current_theme = ""
	var stream: AudioStream = _stream("res://assets/audio/bgm/" + theme_id + ".wav", true)
	if stream == null:
		return
	current_theme = theme_id
	music.stream = stream
	music.volume_db = linear_to_db(0.04 if voice.playing else 0.12)
	music.play()


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
	if _play(voice, path):
		music.volume_db = linear_to_db(0.04)


func _play(player: AudioStreamPlayer, path: String) -> bool:
	player.stop()
	if player == voice:
		_voice_finished()
	var stream: AudioStream = _stream(path)
	if stream == null:
		return false
	player.stream = stream
	player.play()
	return true


func _stream(path: String, loop: bool = false) -> AudioStream:
	if cache.has(path):
		return cache[path]
	if not ResourceLoader.exists(path):
		status_changed.emit("Sound could not load. Tap Listen to try again.")
		return null
	var resource: Resource = load(path)
	if not resource is AudioStream:
		status_changed.emit("This sound could not play. Tap Listen to try again.")
		return null
	var stream: AudioStream = resource
	if loop:
		if not stream is AudioStreamWAV:
			status_changed.emit("This music format cannot loop.")
			return null
		var looping: AudioStreamWAV = stream.duplicate()
		looping.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looping.loop_begin = 0
		looping.loop_end = int(round(looping.get_length() * looping.mix_rate))
		stream = looping
	cache[path] = stream
	return stream


func _voice_finished() -> void:
	if not voice.playing:
		music.volume_db = linear_to_db(0.12)


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		halt()
	status_changed.emit("")


func stop_music() -> void:
	music.stop()


func halt() -> void:
	active = false
	current_theme = ""
	if music != null:
		music.stop()
		music.volume_db = linear_to_db(0.12)
		effect.stop()
		voice.stop()
