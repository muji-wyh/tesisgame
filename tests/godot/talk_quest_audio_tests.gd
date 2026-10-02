extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")
const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")
const Quest = preload("res://scripts/talk_quest.gd")
const Result = preload("res://scripts/talk_quest_result.gd")
const SAD_PATH := "res://assets/audio/pip/duck_quack_innocent_deep_short_04.wav"
const HAPPY_PATH := "res://assets/audio/pip/duck_double_01_bouncy.wav"
const PLAYFUL_PATH := "res://assets/audio/pip/duck_double_03_derpy.wav"

var checks: int = 0
var failures: int = 0
var _directory: String


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _isolate_quest(node: Node) -> void:
	if node.get_script() == Quest:
		node.save_path = _directory + "/quest.cfg"


func _playing(audio) -> int:
	var count: int = 0
	for players: Array in audio._quest_players.values():
		for player: AudioStreamPlayer in players:
			count += int(player.playing)
	return count


func _cleared(audio) -> bool:
	for kind: String in audio.QUEST_SOUNDS:
		if audio.last_quest_player(kind) != null:
			return false
		for player: AudioStreamPlayer in audio._quest_players[kind]:
			if player.playing or player.stream != null:
				return false
	return true


func _requests(audio) -> Dictionary:
	var result: Dictionary = {}
	for kind: String in audio.QUEST_SOUNDS:
		var values: Array[int] = []
		for player: AudioStreamPlayer in audio._quest_players[kind]:
			values.append(int(audio._playback_requests.get(player, 0)))
		result[kind] = values
	return result


func _correct_stream(audio, kind: String) -> bool:
	var player: AudioStreamPlayer = audio.last_quest_player(kind)
	return player != null and player.playing and player.stream == load(str(Audio.QUEST_SOUNDS[kind].path))


func _run() -> void:
	_directory = "user://quest-audio-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(_directory) == OK, "Audio regression uses isolated player storage")
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(_directory + "/medals.cfg", _directory + "/legacy.cfg")
	app.playroom_save_path = _directory + "/room.cfg"
	app._mode_id = "quest"
	PlayerFixture.install(app, _directory)
	node_added.connect(_isolate_quest)
	root.add_child(app)
	await process_frame
	await process_frame
	node_added.disconnect(_isolate_quest)
	app.set_process(false)
	app.set_reduced_motion(false)
	app.audio.set_muted(false)
	app._quest.set_process(false)
	app._quest._effects.set_process(false)
	check(app._quest.save_path == _directory + "/quest.cfg" and app._quest._loaded,
		"The embedded quest reads only its isolated checkpoint")
	check(app._mode_id == "quest" and app._quest.is_visible_in_tree() and not app._leaderboard_overlay.visible,
		"The real main scene exposes Talk Quest with a selected player")
	_check_last_projectile(app)
	_check_combat_flow(app)
	_check_banks(app.audio)
	_check_mix_and_lifecycle(app.audio)
	_check_host_guards(app)
	_check_loss_sequence(app)
	_check_loss_cancellation(app)
	_check_victory_sequence(app.audio)
	_check_victory_cancellation(app.audio)
	_check_victory_flow(app)
	app.audio.halt()
	app.queue_free()
	await process_frame
	for filename: String in DirAccess.get_files_at(_directory):
		DirAccess.remove_absolute(_directory.path_join(filename))
	DirAccess.remove_absolute(_directory)
	print("Talk Quest combat audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_last_projectile(app) -> void:
	var quest = app._quest
	quest.start_level(1)
	var reached: bool = false
	for step in range(240):
		if quest.game.phase != "playing":
			break
		var prompt: Dictionary = quest.game.current_prompt()
		if quest.game.misses < 4 or prompt.is_empty():
			quest._process(0.25)
			continue
		app.audio.stop_quest_sounds()
		quest._submit_text(str(prompt.text))
		if quest.game.targets.is_empty() and quest.game.spawned == quest.game.total_words:
			quest._process(0.01)
			check(quest.game.phase == "lost" and quest._impact_pending,
				"The exhausted word budget can finish while its last accepted projectile is still in flight")
			quest._spell_impact(int(prompt.uid))
			check(_correct_stream(app.audio, "hit"),
				"An already earned projectile retains its contact sound after the round ends")
			reached = true
			break
		quest._process(0.60)
	check(reached, "The real finite-word encounter exercises a final nonlethal projectile")
	quest._show_map()


func _check_combat_flow(app) -> void:
	var quest = app._quest
	var audio = app.audio
	quest.start_level(1)
	audio.halt()
	check(quest.game.phase == "playing" and not audio.active, "A new quest battle begins after the previous mode has halted audio")
	quest._submit_text("unmatchedword")
	check(quest.game.hits == 0 and _playing(audio) == 0 and not audio.active,
		"Unmatched speech neither launches a projectile nor activates combat sound")
	var prompt: Dictionary = quest.game.current_prompt()
	check(not prompt.is_empty(), "The real first level supplies an attack target")
	if prompt.is_empty():
		return
	var uid: int = int(prompt.uid)
	quest._submit_text(str(prompt.text))
	check(audio.active and _correct_stream(audio, "launch"),
		"The first accepted word reactivates the halted mixer and plays its dedicated launch recording")
	check(audio.last_quest_player("hit") == null and quest._impact_pending,
		"Impact sound waits for the traveling word to reach the monster")
	check(not audio.music.playing and not audio.voice.playing and not audio.effect.playing and not audio.match_voice_hit.playing,
		"Quest combat starts neither background music nor unrelated pronunciation, UI, or Match sounds")
	quest._spell_impact(uid)
	check(_correct_stream(audio, "hit") and _correct_stream(audio, "launch") and quest._display_hp == quest.game.hp,
		"Monster contact plays a separate impact without cutting off the launch tail")
	var settled: Dictionary = _requests(audio)
	quest._effects.word_landed.emit(uid)
	quest._spell_impact(uid)
	check(_requests(audio) == settled, "Duplicate visual and fallback contacts cannot replay the same impact")
	quest.pause()
	check(_cleared(audio), "Pausing clears every combat channel and its pending playback request")
	settled = _requests(audio)
	quest._spell_impact(uid)
	check(_requests(audio) == settled, "A late projectile callback stays silent after pause")
	quest._continue_run()
	check(_playing(audio) == 0, "Resuming a battle does not replay an old launch or impact")
	audio.set_muted(true)
	quest._process(0.5)
	prompt = quest.game.current_prompt()
	var previous_hits: int = quest.game.hits
	if not prompt.is_empty():
		quest._submit_text(str(prompt.text))
		quest._spell_impact(int(prompt.uid))
	check(quest.game.hits == previous_hits + 1 and _playing(audio) == 0,
		"A muted accepted word still damages the monster while both combat cues stay silent")
	audio.set_muted(false)
	for turn in range(80):
		if quest.game.phase != "playing":
			break
		prompt = quest.game.current_prompt()
		if prompt.is_empty():
			quest._process(0.5)
			continue
		quest._submit_text(str(prompt.text))
		quest._process(0.65)
	check(quest.game.phase == "victory" and quest.game.hp == 0 and _correct_stream(audio, "hit"),
		"The final word still sounds its impact after the game model enters victory")
	check(_correct_stream(audio, "victory") and not audio.music.playing and not audio._chest_charge_active,
		"The defeat animation plays its own recording without requiring a chest opening or music")
	quest._show_map()
	check(_cleared(audio), "Returning to the map stops the defeat tail as well as attack channels")


func _check_banks(audio) -> void:
	audio.interact("spring", false)
	for kind: String in Audio.QUEST_SOUNDS:
		var config: Dictionary = Audio.QUEST_SOUNDS[kind]
		check(audio._quest_players[kind].size() == int(config.channels),
			"The " + kind + " bank uses its fixed channel budget")
		audio.play_quest_sound(kind)
		var player: AudioStreamPlayer = audio.last_quest_player(kind)
		var stream: AudioStreamWAV = player.stream as AudioStreamWAV if player != null else null
		check(_correct_stream(audio, kind) and stream != null
			and not stream.stereo and stream.mix_rate == 44100
			and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED,
			"The " + kind + " recording is locally bundled mono PCM with no loop")
		check(player != null and is_equal_approx(player.pitch_scale, 1.0)
			and is_equal_approx(db_to_linear(player.volume_db), float(config.gain)),
			"The " + kind + " recording retains its authored pitch and bounded gain")
		if kind in ["launch", "hit"] and stream != null:
			var peak: float = 0.0
			for offset in range(0, stream.data.size(), 2):
				peak = maxf(peak, absf(float(stream.data.decode_s16(offset))) / 32768.0)
			check(peak * db_to_linear(player.volume_db) * int(config.channels) < 0.95,
				"Even three aligned " + kind + " recordings retain output headroom")
	for kind: String in ["launch", "hit"]:
		audio.stop_quest_sounds()
		var players: Array[AudioStreamPlayer] = []
		var requests: Array[int] = []
		for index in range(3):
			audio.play_quest_sound(kind)
			var player: AudioStreamPlayer = audio.last_quest_player(kind)
			players.append(player)
			requests.append(int(audio._playback_requests[player]))
		check(players[0] != players[1] and players[1] != players[2] and players[0] != players[2]
			and players.all(func(player: AudioStreamPlayer) -> bool: return player.playing),
			"Three rapid " + kind + " events preserve overlapping tails on distinct channels")
		audio.play_quest_sound(kind)
		check(audio.last_quest_player(kind) == players[0]
			and audio._playback_requests[players[0]] == requests[0] + 1
			and audio._playback_requests[players[1]] == requests[1]
			and audio._playback_requests[players[2]] == requests[2],
			"A fourth " + kind + " replaces only the oldest of the three channels")
	var before: Dictionary = _requests(audio)
	audio.play_quest_sound("unknown")
	check(_requests(audio) == before, "Unknown combat cue names cannot start or replace any sound")


func _check_mix_and_lifecycle(audio) -> void:
	check(audio.set_speech_debug_mix(0.35), "The reduced speech diagnostic mix is accepted")
	for kind: String in Audio.QUEST_SOUNDS:
		audio.play_quest_sound(kind)
		var player: AudioStreamPlayer = audio.last_quest_player(kind)
		check(_correct_stream(audio, kind) and is_equal_approx(db_to_linear(player.volume_db), float(Audio.QUEST_SOUNDS[kind].gain) * 0.35),
			"The diagnostic mix scales the actual " + kind + " channel")
	audio.set_speech_debug_mix(0.0)
	for kind: String in Audio.QUEST_SOUNDS:
		audio.play_quest_sound(kind)
	check(_cleared(audio), "Zero diagnostic mix stops current tails and suppresses new combat playback")
	audio.set_speech_debug_mix(1.0)
	audio.play_quest_sound("launch")
	check(_correct_stream(audio, "launch") and is_equal_approx(db_to_linear(audio.last_quest_player("launch").volume_db), 0.5),
		"Leaving diagnostics restores the authored launch mix")
	audio.halt()
	check(_cleared(audio) and not audio.active, "Global halt clears all dedicated combat channels")
	for blocked: String in ["inactive", "muted", "unavailable"]:
		audio.active = blocked != "inactive"
		audio.muted = blocked == "muted"
		audio.available = blocked != "unavailable"
		for kind: String in Audio.QUEST_SOUNDS:
			audio.play_quest_sound(kind)
		check(_cleared(audio), "Combat playback remains silent when the mixer is " + blocked)
	audio.available = true
	audio.set_muted(false)
	audio.interact("spring", false)
	audio.play_quest_sound("hit")
	audio.set_muted(true)
	check(_cleared(audio) and not audio.active, "The user's mute action immediately stops a playing combat tail")
	audio.set_muted(false)


func _check_host_guards(app) -> void:
	app._quest.start_level(1)
	for blocker: String in ["map", "collection", "leaderboard", "hidden", "paused"]:
		app.audio.halt()
		match blocker:
			"map": app._quest.view = "map"
			"collection": app.collection_page.show()
			"leaderboard": app._leaderboard_overlay.show()
			"hidden": app._page_hidden = true
			"paused": app._quest._suspended = true
		app._quest_sound("launch")
		app._quest_sound("pip_loss")
		app._quest_sound("pip_victory")
		check(not app.audio.active and _cleared(app.audio),
			"A " + blocker + " quest cannot reactivate playback through a delayed sound event")
		app._quest.view = "stage"
		app.collection_page.hide()
		app._leaderboard_overlay.hide()
		app._page_hidden = false
		app._quest._suspended = false
	app._quest_sound("pip_loss")
	app._quest_sound("pip_victory")
	check(not app.audio.active and app.audio._pip_loss_tween == null,
		"A delayed loss event cannot start Pip during an active battle without a visible loss card")


func _lose(quest) -> void:
	quest.start_level(1)
	quest._process(1000.0)
	check(quest.game.phase == "lost" and quest._loss.is_visible_in_tree(),
		"The finite ten-second word budget reaches the real visible loss result")


func _check_loss_sequence(app) -> void:
	var audio = app.audio
	var quest = app._quest
	audio.set_muted(false)
	_lose(quest)
	check(audio.active and audio.pip_reaction != null and audio.pip_reaction.playing
		and audio.pip_reaction.stream == load(SAD_PATH) and audio.pip_reaction.pitch_scale < 1.0,
		"The first visible failure immediately plays Pip's sourced disappointed call")
	check(not audio.music.playing and not audio.voice.playing and not audio.effect.playing,
		"Pip's loss reaction uses its dedicated voice without restarting unrelated audio")
	var sequence: Tween = audio._pip_loss_tween
	check(sequence != null and sequence.is_valid(), "A failure owns one cancellable emotional sound sequence")
	if sequence == null:
		return
	sequence.pause()
	var before: int = int(audio._playback_requests.get(audio.pip_reaction, 0))
	for repeat in range(4):
		quest._refresh()
	check(audio._pip_loss_tween == sequence and int(audio._playback_requests[audio.pip_reaction]) == before,
		"Repeated loss refreshes preserve the original recording instead of replaying it")
	sequence.custom_step(0.79)
	check(int(audio._playback_requests[audio.pip_reaction]) == before,
		"The second sigh waits for its authored beat")
	sequence.custom_step(0.02)
	check(int(audio._playback_requests[audio.pip_reaction]) == before + 1
		and audio.pip_reaction.stream == load(SAD_PATH) and is_equal_approx(audio.pip_reaction.pitch_scale, 0.70)
		and is_equal_approx(db_to_linear(audio.pip_reaction.volume_db), 0.40),
		"At 0.8 seconds a quieter, lower second sourced sigh makes the disappointment clear")
	sequence.custom_step(1.58)
	check(audio.pip_reaction.stream == load(SAD_PATH), "The sad call does not become encouragement too early")
	sequence.custom_step(0.02)
	check(audio.pip_reaction.stream == load(HAPPY_PATH) and audio.pip_reaction.pitch_scale > 1.0
		and int(audio._playback_requests[audio.pip_reaction]) == before + 2
		and Audio.PIP_LOSS_ENCOURAGE_DELAY == Result.LOSS_SAD_SECONDS,
		"At 2.4 seconds the hopeful double quack coincides with Pip's encouraging expression")
	check(audio._pip_loss_tween == null, "The completed sequence releases its only scheduler")
	before = int(audio._playback_requests[audio.pip_reaction])
	quest._refresh()
	check(int(audio._playback_requests[audio.pip_reaction]) == before,
		"Refreshing the completed result cannot replay either emotion")
	quest._show_map()


func _check_victory_sequence(audio) -> void:
	audio.halt()
	audio.set_muted(false)
	audio.interact("spring", false)
	audio.play_pip_victory()
	check(audio.pip_reaction.playing and audio.pip_reaction.stream == load(HAPPY_PATH)
		and is_equal_approx(audio.pip_reaction.pitch_scale, 1.12),
		"Victory immediately plays Pip's supplied bouncy double quack")
	var sequence: Tween = audio._pip_victory_tween
	check(sequence != null and sequence.is_valid(), "Pip's victory owns one cancellable sound sequence")
	if sequence == null:
		return
	sequence.pause()
	var first: int = int(audio._playback_requests[audio.pip_reaction])
	var players: Array[Node] = audio.get_children()
	for repeat in range(3):
		audio.play_pip_victory()
	check(audio._pip_victory_tween == sequence and int(audio._playback_requests[audio.pip_reaction]) == first,
		"Repeated celebration requests do not replace or stack the active recording")
	sequence.custom_step(0.99)
	check(int(audio._playback_requests[audio.pip_reaction]) == first, "The next quack waits for the one-second dance beat")
	sequence.custom_step(0.02)
	check(audio.pip_reaction.stream == load(PLAYFUL_PATH) and is_equal_approx(audio.pip_reaction.pitch_scale, 1.08)
		and is_equal_approx(db_to_linear(audio.pip_reaction.volume_db), 0.58),
		"The middle dance beat uses the distinct supplied playful double quack at a softer gain")
	sequence.custom_step(0.98)
	check(int(audio._playback_requests[audio.pip_reaction]) == first + 1, "The final cheer does not play before its dance beat")
	sequence.custom_step(0.02)
	check(audio.pip_reaction.stream == load(HAPPY_PATH) and is_equal_approx(audio.pip_reaction.pitch_scale, 1.20)
		and int(audio._playback_requests[audio.pip_reaction]) == first + 2,
		"At two seconds Pip finishes with the brighter recorded double quack")
	check(2.0 + audio.pip_reaction.stream.get_length() / audio.pip_reaction.pitch_scale < Audio.PIP_VICTORY_SECONDS,
		"The final recorded call finishes before the 3.2-second celebration leaves for the chest")
	sequence.custom_step(1.20)
	check(audio._pip_victory_tween == null and audio.get_children() == players,
		"The 3.2-second sequence releases its scheduler without adding audio channels")
	check(not audio.music.playing and not audio.voice.playing and not audio.effect.playing,
		"Pip's celebration leaves background music, pronunciation and ordinary effects untouched")
	audio.stop_pip_reaction()


func _check_victory_cancellation(audio) -> void:
	for blocked: String in ["inactive", "muted", "unavailable", "zero_mix"]:
		audio.halt()
		audio.active = blocked != "inactive"
		audio.muted = blocked == "muted"
		audio.available = blocked != "unavailable"
		audio.set_speech_debug_mix(0.0 if blocked == "zero_mix" else 1.0)
		audio.play_pip_victory()
		check(audio._pip_victory_tween == null and not audio.pip_reaction.playing,
			"A " + blocked + " mixer does not queue victory calls")
	audio.available = true
	audio.set_muted(false)
	audio.set_speech_debug_mix(1.0)
	for interruption: String in ["mute", "zero_mix", "halt", "stop"]:
		audio.interact("spring", false)
		audio.play_pip_victory()
		var sequence: Tween = audio._pip_victory_tween
		sequence.pause()
		match interruption:
			"mute": audio.set_muted(true)
			"zero_mix": audio.set_speech_debug_mix(0.0)
			"halt": audio.halt()
			"stop": audio.stop_pip_reaction()
		check(not sequence.is_valid() and audio._pip_victory_tween == null
			and not audio.pip_reaction.playing and audio.pip_reaction.stream == null,
			"A " + interruption + " cancels current and future victory calls")
		audio.set_muted(false)
		audio.set_speech_debug_mix(1.0)
		audio.interact("spring", false)
		check(audio._pip_victory_tween == null and not audio.pip_reaction.playing,
			"Restoring sound after " + interruption + " cannot revive a cancelled celebration")
	audio.play_pip_loss()
	var previous_loss: Tween = audio._pip_loss_tween
	audio.play_pip_victory()
	check(not previous_loss.is_valid() and audio._pip_loss_tween == null,
		"A victory celebration cannot overlap a previous loss sequence")
	var previous_win: Tween = audio._pip_victory_tween
	audio.play_pip_loss()
	check(not previous_win.is_valid() and audio._pip_victory_tween == null,
		"A newer loss response also cancels the previous celebration scheduler")
	audio.halt()


func _win(quest) -> void:
	quest.start_level(1)
	for turn in range(80):
		if quest.game.phase != "playing":
			break
		var prompt: Dictionary = quest.game.current_prompt()
		if not prompt.is_empty():
			quest._submit_text(str(prompt.text))
		quest._process(0.10)
	check(quest.game.phase == "victory", "The real word battle reaches victory for its Pip audio test")


func _check_victory_flow(app) -> void:
	var audio = app.audio
	var quest = app._quest
	for interruption: String in ["chest", "pause", "map", "page", "mode"]:
		_win(quest)
		for step in range(60):
			if audio._pip_victory_tween != null or quest.game.phase != "victory":
				break
			quest._process(0.1)
		var sequence: Tween = audio._pip_victory_tween
		check(sequence != null and sequence.is_valid(), "A visible victory starts Pip's cheerful voice through the real Quest route")
		if sequence == null:
			continue
		sequence.pause()
		var first: int = int(audio._playback_requests[audio.pip_reaction])
		for repeat in range(3):
			quest._refresh()
		check(int(audio._playback_requests[audio.pip_reaction]) == first and audio._pip_victory_tween == sequence,
			"Ordinary victory refreshes do not replay the cheerful sequence")
		match interruption:
			"chest":
				for step in range(100):
					if quest.game.phase != "victory":
						break
					quest._process(0.1)
				check(quest.game.phase == "chest", "The celebration reaches the normal treasure phase")
			"pause": quest.pause()
			"map": quest._show_map()
			"page": app.on_page_hidden()
			"mode": app.choose_mode("match")
		check(not sequence.is_valid() and audio._pip_victory_tween == null
			and not audio.pip_reaction.playing and audio.pip_reaction.stream == null,
			"Entering " + interruption + " stops Pip's victory audio and all scheduled quacks")
		if interruption == "chest":
			app._quest_sound("pip_victory")
			check(audio._pip_victory_tween == null and not audio.pip_reaction.playing,
				"A late victory event cannot start a new cheer over the treasure interaction")
			quest.start_chest_hold()
			app._quest_sound("pip_stop")
			check(audio._chest_charge_active and audio.chest_charge.playing,
				"Pip-only cleanup preserves an already starting treasure charge recording")
			quest.cancel_chest_input(false)
		if interruption == "page":
			app.on_page_visible()
		if interruption == "mode":
			app.choose_mode("quest")
			quest.set_process(false)
		quest._show_map()


func _check_loss_cancellation(app) -> void:
	var audio = app.audio
	var quest = app._quest
	for blocked: String in ["inactive", "muted", "unavailable", "zero_mix"]:
		audio.halt()
		audio.active = blocked != "inactive"
		audio.muted = blocked == "muted"
		audio.available = blocked != "unavailable"
		audio.set_speech_debug_mix(0.0 if blocked == "zero_mix" else 1.0)
		audio.play_pip_loss()
		check(audio._pip_loss_tween == null and not audio.pip_reaction.playing,
			"A " + blocked + " mixer neither plays nor schedules loss reactions")
	audio.available = true
	audio.set_muted(false)
	audio.set_speech_debug_mix(1.0)
	audio.set_muted(true)
	_lose(quest)
	check(audio._pip_loss_tween == null and not audio.pip_reaction.playing,
		"A failure first shown while muted does not queue Pip's emotional calls")
	audio.set_muted(false)
	quest._refresh()
	check(audio._pip_loss_tween == null and not audio.pip_reaction.playing,
		"Unmuting the same visible failure cannot start an old loss sequence")
	for interruption: String in ["mute", "zero_mix", "pause", "map", "page", "mode", "retry"]:
		_lose(quest)
		var sequence: Tween = audio._pip_loss_tween
		check(sequence != null and sequence.is_valid(), "A new attempt can start its own Pip loss reaction")
		if sequence == null:
			continue
		sequence.pause()
		match interruption:
			"mute": audio.set_muted(true)
			"zero_mix": audio.set_speech_debug_mix(0.0)
			"pause": quest.pause()
			"map": quest._show_map()
			"page": app.on_page_hidden()
			"mode": app.choose_mode("match")
			"retry": quest.start_level(1)
		check(not sequence.is_valid() and audio._pip_loss_tween == null
			and not audio.pip_reaction.playing and audio.pip_reaction.stream == null,
			"The " + interruption + " action cancels both the current call and every future loss beat")
		match interruption:
			"mute": audio.set_muted(false)
			"zero_mix": audio.set_speech_debug_mix(1.0)
			"pause": quest._continue_run()
			"page":
				app.on_page_visible()
				quest._continue_run()
			"mode":
				app.choose_mode("quest")
				quest.set_process(false)
		quest._refresh()
		check(audio._pip_loss_tween == null and not audio.pip_reaction.playing and audio.pip_reaction.stream == null,
			"Returning after " + interruption + " does not replay a cancelled emotional sequence")
	quest._show_map()
