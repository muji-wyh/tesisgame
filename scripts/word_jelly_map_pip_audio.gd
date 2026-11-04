extends Node
## Map-only character cues. The visual sleep timeline owns every snore pulse.

const SNORE_PATH := "res://assets/audio/pip/map-snore.wav"
const WAKE_PATH := "res://assets/audio/pip/duck_quack_innocent_deep_short_04.wav"
const SNORE_GAIN := 0.36
const WAKE_GAIN := 0.24

var _enabled := false
var _sleeping := false
var _snore: AudioStreamPlayer
var _wake: AudioStreamPlayer
var _snore_requests := 0
var _wake_requests := 0


func _ready() -> void:
	_snore = _player("Snore", SNORE_PATH, SNORE_GAIN)
	_wake = _player("StartledPeep", WAKE_PATH, WAKE_GAIN)
	set_process(false)


func _player(label: String, path: String, gain: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.volume_db = linear_to_db(gain)
	player.stream = load(path) if ResourceLoader.exists(path) else null
	add_child(player)
	return player


func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		_stop_players()


func set_sleeping(value: bool) -> void:
	_sleeping = value
	if not value and is_instance_valid(_snore):
		_snore.stop()


func pulse_snore() -> void:
	if not _enabled or not _sleeping or not is_instance_valid(_snore) \
		or _snore.stream == null or _snore.playing:
		return
	_snore_requests += 1
	_snore.play()


func wake() -> void:
	var was_sleeping: bool = _sleeping
	set_sleeping(false)
	if not was_sleeping or not _enabled or not is_instance_valid(_wake) \
		or _wake.stream == null or _wake.playing:
		return
	_wake_requests += 1
	_wake.play()


func stop() -> void:
	_sleeping = false
	_stop_players()


func _stop_players() -> void:
	for player: AudioStreamPlayer in [_snore, _wake]:
		if is_instance_valid(player):
			player.stop()


func snapshot() -> Dictionary:
	return {"enabled": _enabled, "sleeping": _sleeping,
		"snore_playing": is_instance_valid(_snore) and _snore.playing,
		"wake_playing": is_instance_valid(_wake) and _wake.playing,
		"snore_requests": _snore_requests, "wake_requests": _wake_requests}
