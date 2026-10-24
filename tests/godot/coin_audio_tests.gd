extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")
const Flight = preload("res://scripts/coin_reward_flight.gd")
const Counter = preload("res://scripts/coin_counter.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")

class DelayedCoinAudio extends "res://scripts/game_audio.gd":
	signal coin_loaded
	var delay_coin: bool = false

	func _stream(path: String, loop: bool = false) -> AudioStream:
		if delay_coin and path in [COIN_PATH, COIN_RELEASE_PATH]:
			await coin_loaded
		return await super._stream(path, loop)


var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _flight_fixture() -> Dictionary:
	var counter := Counter.new()
	var flight := Flight.new()
	flight.counter = counter
	root.add_child(counter)
	root.add_child(flight)
	var state: Dictionary = {"flight": flight, "counter": counter, "time": 0.0,
		"times": [], "balances": [], "release_times": [], "sound_times": [], "settlements": 0}
	flight.release_sound.connect(func() -> void:
		state.release_times.append(state.time)
		state.sound_times.append(state.time))
	flight.arrival_sound.connect(func() -> void:
		state.times.append(state.time)
		state.sound_times.append(state.time)
		state.balances.append(counter.target))
	flight.settled.connect(func() -> void: state.settlements += 1)
	flight.sync(0)
	return state


func _advance(state: Dictionary, delta: float) -> void:
	if is_finite(delta) and delta > 0.0:
		state.time += delta
	state.flight.advance(delta)


func _reward(before: int, amount: int = 50) -> Dictionary:
	return {"amount": amount, "before": before, "after": before + amount}


func _dispose_flight(state: Dictionary) -> void:
	state.flight.free()
	state.counter.free()


func _check_flight_timing() -> void:
	var state := _flight_fixture()
	var flight = state.flight
	flight.present("word", _reward(0), Vector2(100, 100))
	check(state.times.is_empty() and state.counter.target == 0,
		"A flight that omits release audio waits for its visible arrival")
	for delta: float in [0.0, -1.0, INF, NAN]:
		_advance(state, delta)
	check(state.times.is_empty(), "Invalid clock updates cannot produce a coin sound")
	_advance(state, Flight.BURST_SECONDS + Flight.TRAVEL_SECONDS - 0.001)
	check(state.times.is_empty() and state.counter.target == 0,
		"Opting out of release audio keeps the burst silent until the first coin reaches the HUD")
	_advance(state, 0.002)
	check(state.times.size() == 1 and state.counter.target > 0 and state.counter.target < 50,
		"The first real coin arrival starts one deposit cue with its counter increment")
	for frame in range(45):
		_advance(state, 0.01)
	check(state.times.size() >= 3 and state.times.size() <= 4,
		"The normal eight-coin receipt has a short audible rhythm instead of eight stacked sounds")
	for index in range(1, state.times.size()):
		check(float(state.times[index]) - float(state.times[index - 1]) >= 0.10 - 0.00001,
			"Consecutive deposit sounds stay at least 100 milliseconds apart")
		check(int(state.balances[index]) > int(state.balances[index - 1]),
			"Every audible beat accompanies newly arrived value")
	check(state.counter.target == 50 and not flight.snapshot().active,
		"Sound cadence cannot delay or change the earned balance")
	check(state.release_times.is_empty(), "The explicit release-audio opt-out remains available")
	var sounds: int = state.times.size()
	flight.present("word", _reward(0), Vector2.ZERO)
	_advance(state, 10.0)
	check(state.times.size() == sounds and state.counter.target == 50,
		"A completed receipt and idle time cannot replay coin audio")
	flight.present("zero", _reward(50, 0), Vector2.ZERO)
	_advance(state, 10.0)
	check(state.times.size() == sounds, "An empty reward has no deposit sound")
	_dispose_flight(state)


func _check_chest_release_timing() -> void:
	var state := _flight_fixture()
	state.flight.present("chest", _reward(0), Vector2.ZERO, true)
	check(state.sound_times.is_empty() and state.counter.target == 0,
		"Queuing chest coins leaves audio activation to the first visible burst frame")
	for delta: float in [0.0, -1.0, INF, NAN]:
		_advance(state, delta)
	check(state.sound_times.is_empty(), "Invalid updates cannot consume or play a pending chest release")
	_advance(state, 0.016)
	check(state.release_times.size() == 1 and state.times.is_empty() and state.counter.target == 0,
		"The first valid chest burst frame plays one release cue before any coins arrive")
	state.flight.present("chest", _reward(0), Vector2.ZERO, true)
	for frame in range(200):
		_advance(state, 0.01)
	check(state.release_times.size() == 1 and state.times.size() >= 3 and state.counter.target == 50,
		"A chest release sounds once while its original deposit rhythm and full value remain intact")
	for index in range(1, state.sound_times.size()):
		check(float(state.sound_times[index]) - float(state.sound_times[index - 1]) >= Flight.SOUND_INTERVAL - 0.00001,
			"Chest release and deposit cues respect the same 100 millisecond interval")
	var sounds: int = state.sound_times.size()
	state.flight.present("chest", _reward(0), Vector2.ZERO, true)
	state.flight.present("empty", _reward(50, 0), Vector2.ZERO, true)
	state.flight.present("negative", _reward(50, -50), Vector2.ZERO, true)
	_advance(state, 0.016)
	check(state.sound_times.size() == sounds and not state.flight.snapshot().active,
		"Duplicate and nonpositive chest receipts cannot replay their release or deposit")
	state.flight.present("background", _reward(50), Vector2.ZERO, true)
	state.flight.sync(100)
	_advance(state, 0.016)
	state.flight.present("background", _reward(50), Vector2.ZERO, true)
	state.flight.present("restored", _reward(50), Vector2.ZERO, true)
	_advance(state, 10.0)
	check(state.sound_times.size() == sounds and state.counter.target == 100,
		"Settlement before the first burst frame cancels release audio, including retry and restored receipts")
	_dispose_flight(state)


func _check_chest_release_boundaries() -> void:
	var cases: Array[Dictionary] = [
		{"reduced": false, "amount": 50, "delta": Flight.BURST_SECONDS + 0.01, "release": true},
		{"reduced": false, "amount": 50, "delta": Flight.BURST_SECONDS + 7 * 0.045, "release": false},
		{"reduced": false, "amount": 350, "delta": Flight.BURST_SECONDS + 13 * 0.045 - 0.001, "release": true},
		{"reduced": false, "amount": 350, "delta": Flight.BURST_SECONDS + 13 * 0.045, "release": false},
		{"reduced": false, "amount": 50, "delta": Flight.BURST_SECONDS + Flight.TRAVEL_SECONDS + 0.001, "release": false},
		{"reduced": false, "amount": 50, "delta": 10.0, "release": false},
		{"reduced": true, "amount": 50, "delta": 0.016, "release": true},
		{"reduced": true, "amount": 50, "delta": 0.239, "release": true},
		{"reduced": true, "amount": 50, "delta": 0.24, "release": false},
		{"reduced": true, "amount": 50, "delta": 10.0, "release": false}
	]
	for scenario: Dictionary in cases:
		var state := _flight_fixture()
		state.flight.reduced_motion = scenario.reduced
		state.flight.present("boundary", _reward(0, scenario.amount), Vector2.ZERO, true)
		_advance(state, scenario.delta)
		check(state.release_times.size() == (1 if scenario.release else 0),
			"A %d-coin chest first shown at %.3f seconds only sounds while its burst remains visible (reduced: %s)"
			% [scenario.amount, scenario.delta, scenario.reduced])
		_advance(state, 10.0)
		check(state.release_times.size() == (1 if scenario.release else 0)
			and state.counter.target == scenario.amount and not state.flight.snapshot().active,
			"A delayed frame settles the full receipt without replaying a skipped or completed release")
		_dispose_flight(state)


func _check_chest_release_cadence() -> void:
	var state := _flight_fixture()
	state.flight.present("word", _reward(0), Vector2.ZERO)
	_advance(state, Flight.BURST_SECONDS + Flight.TRAVEL_SECONDS - 0.01)
	state.flight.present("chest-one", _reward(50), Vector2.ZERO, true)
	state.flight.present("chest-two", _reward(100), Vector2.ZERO, true)
	_advance(state, 0.02)
	check(state.release_times.size() == 1 and state.times.is_empty() and state.counter.target > 0,
		"Simultaneous chest releases coalesce and take precedence over an older word's arriving coins")
	state.flight.present("chest-suppressed", _reward(150), Vector2.ZERO, true)
	_advance(state, 0.01)
	check(state.release_times.size() == 1 and state.times.is_empty(),
		"A second chest within the shared sound interval cannot stack another release cue")
	for frame in range(200):
		_advance(state, 0.01)
	check(state.release_times.size() == 1 and not state.times.is_empty() and state.counter.target == 200,
		"A coalesced release is never queued for later, while every overlapping reward still arrives")
	for index in range(1, state.sound_times.size()):
		check(float(state.sound_times[index]) - float(state.sound_times[index - 1]) >= Flight.SOUND_INTERVAL - 0.00001,
			"Mixed word deposits and chest releases cannot exceed the shared audio cadence")
	_dispose_flight(state)


func _check_overlapping_and_reduced() -> void:
	var state := _flight_fixture()
	for index in range(12):
		state.flight.present("collect-%d" % index, _reward(index * 100, 100), Vector2.ZERO, true)
		for frame in range(10):
			_advance(state, 0.01)
	check(state.release_times.size() == 12,
		"Twelve word receipts at 100 millisecond intervals each sound when their coins appear")
	for frame in range(200):
		_advance(state, 0.01)
	check(state.times.size() > 8 and state.times.size() < 30,
		"Collecting twelve words every 100 milliseconds creates a bounded continuous coin rhythm")
	for index in range(1, state.sound_times.size()):
		check(float(state.sound_times[index]) - float(state.sound_times[index - 1]) >= 0.10 - 0.00001,
			"Overlapping word releases and deposits share the same maximum sound cadence")
	check(state.counter.target == 1200 and not state.flight.snapshot().active,
		"Overlapping sounds preserve every word's full reward")
	var sounds: int = state.times.size()
	for index in range(10):
		state.flight.present("stall-%d" % index, _reward(1200 + index * 50), Vector2.ZERO)
	_advance(state, 10.0)
	check(state.times.size() == sounds + 1 and state.counter.target == 1700,
		"A stalled frame coalesces many simultaneous arrivals into one cue without losing coins")
	sounds = state.times.size()
	state.flight.present("cancelled", _reward(1700), Vector2.ZERO)
	state.flight.sync(1750)
	_advance(state, 10.0)
	state.flight.present("cancelled", _reward(1700), Vector2.ZERO)
	state.flight.present("restored", _reward(1700), Vector2.ZERO)
	_advance(state, 10.0)
	check(state.times.size() == sounds and state.counter.target == 1750 and state.settlements == 2,
		"Silent settlement cancels arrivals and neither a retry nor restored receipt can sound")
	state.flight.reduced_motion = true
	var releases: int = state.release_times.size()
	state.flight.present("reduced", _reward(1750, 100), Vector2.ZERO, true)
	_advance(state, 0.016)
	check(state.release_times.size() == releases + 1 and state.times.size() == sounds
		and state.counter.target == 1750,
		"Reduced motion sounds its visible coin acknowledgement before any balance arrives")
	_advance(state, 0.225)
	check(state.times.size() == sounds + 1 and state.counter.displayed == 1850.0
		and not state.flight.snapshot().active,
		"Reduced motion coalesces all arriving sprites into one sound and settles immediately")
	_advance(state, 2.0)
	check(state.times.size() == sounds + 1, "Reduced-motion completion never schedules a later sound train")
	_dispose_flight(state)


func _coin_players_silent(audio) -> bool:
	for player: AudioStreamPlayer in audio._coin_players:
		if player.playing or player.stream != null:
			return false
	return true


func _coin_playing(audio, path: String = "") -> bool:
	for player: AudioStreamPlayer in audio._coin_players:
		if player.playing and player.stream != null and (path.is_empty() or player.stream.resource_path == path):
			return true
	return false


func _check_audio_channels() -> void:
	var arrival: AudioStreamWAV = load(Audio.COIN_PATH)
	var release: AudioStreamWAV = load(Audio.COIN_RELEASE_PATH)
	check(Audio.COIN_RELEASE_PATH != Audio.COIN_PATH and release != arrival and release.data != arrival.data,
		"Coin appearance and HUD arrival are distinct production recordings rather than aliases of one stream")
	var audio := Audio.new()
	root.add_child(audio)
	check(audio._coin_players.is_empty(), "Starting the game does not allocate or play coin channels")
	audio.play_coin_arrival()
	audio.play_coin_release()
	check(audio._coin_players.is_empty(), "Inactive gameplay cannot enqueue release or deposit cues")
	audio.interact("spring", false)
	audio.say("res://assets/audio/voice/word-cat.wav")
	audio.play_pair_feedback(true)
	audio.play_jelly_cue("merge")
	var voice_request: int = audio._playback_requests[audio.voice]
	var pair_request: int = audio._playback_requests[audio.pair_feedback]
	var jelly: AudioStreamPlayer = audio._jelly_players[0]
	var jelly_request: int = audio._playback_requests[jelly]
	var rng_state: int = audio._pop_slice_rng.state
	for index in range(24):
		audio.play_coin_arrival()
	check(audio._coin_players.size() == Audio.COIN_CHANNELS and _coin_playing(audio, Audio.COIN_PATH)
		and not _coin_playing(audio, Audio.COIN_RELEASE_PATH),
		"Repeated deposits reuse a fixed pool and play the selected production recording")
	var channels: int = audio.get_child_count()
	for index in range(16):
		if index % 2 == 0:
			audio.play_coin_release()
		else:
			audio.play_coin_arrival()
	check(audio.get_child_count() == channels and _coin_playing(audio, Audio.COIN_PATH)
		and _coin_playing(audio, Audio.COIN_RELEASE_PATH),
		"Distinct appearance and deposit recordings overlap within the same fixed channel pool")
	check(audio.voice.playing and audio._playback_requests[audio.voice] == voice_request
		and audio._playback_requests[audio.pair_feedback] == pair_request
		and audio._playback_requests[jelly] == jelly_request and audio._pop_slice_rng.state == rng_state,
		"Coin feedback neither interrupts pronunciation and jelly cues nor changes gameplay randomness")
	for player: AudioStreamPlayer in audio._coin_players:
		check(player.stream is AudioStreamWAV and not player.stream.stereo
			and player.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED
			and player.stream in [arrival, release]
			and player.stream.get_length() > 0.05 and player.stream.get_length() < 1.0,
			"Each coin channel uses one of the complete short mono production recordings without a loop")
		check(player.volume_db <= linear_to_db(Audio.COIN_GAIN) + 0.001 and player.pitch_scale == 1.0,
			"The coin recording keeps its original pitch and bounded mix level")
	audio.stop_coin_sounds()
	check(_coin_players_silent(audio) and audio.voice.playing,
		"Settling coins stops only their own tails and preserves pronunciation")
	audio.play_coin_arrival()
	audio.play_coin_release()
	audio.set_muted(true)
	check(_coin_players_silent(audio), "Mute immediately stops both appearance and deposit tails")
	audio.play_coin_arrival()
	audio.play_coin_release()
	audio.set_muted(false)
	check(_coin_players_silent(audio), "Unmuting never replays a suppressed release or deposit cue")
	audio.interact("spring", false)
	audio.available = false
	audio.play_coin_arrival()
	audio.play_coin_release()
	check(_coin_players_silent(audio), "Unavailable audio leaves the earned reward silent")
	audio.available = true
	audio.play_coin_release()
	check(_coin_playing(audio, Audio.COIN_RELEASE_PATH) and not _coin_playing(audio, Audio.COIN_PATH),
		"A new live chest release selects only the appearance recording after audio availability returns")
	audio.halt()
	check(_coin_players_silent(audio), "Leaving gameplay stops the entire coin pool")
	audio.play_coin_arrival()
	audio.play_coin_release()
	check(_coin_players_silent(audio), "Late release or arrival callbacks cannot resume a halted gameplay channel")
	audio.queue_free()
	await process_frame


func _check_pending_audio() -> void:
	for cue: String in ["arrival", "release"]:
		for interruption: String in ["settlement", "mute", "halt"]:
			var audio := DelayedCoinAudio.new()
			root.add_child(audio)
			audio.interact("spring", false)
			audio.delay_coin = true
			audio.call("play_coin_" + cue)
			check(_coin_players_silent(audio), "The pending %s fixture delays the %s asset before playback" % [interruption, cue])
			match interruption:
				"settlement": audio.stop_coin_sounds()
				"mute":
					audio.set_muted(true)
					audio.set_muted(false)
				"halt": audio.halt()
			audio.interact("spring", false)
			audio.delay_coin = false
			audio.coin_loaded.emit()
			await process_frame
			check(_coin_players_silent(audio), "A delayed %s asset cannot revive playback after %s" % [cue, interruption])
			audio.call("play_coin_" + cue)
			var expected: String = Audio.COIN_RELEASE_PATH if cue == "release" else Audio.COIN_PATH
			var unexpected: String = Audio.COIN_PATH if cue == "release" else Audio.COIN_RELEASE_PATH
			check(_coin_playing(audio, expected) and not _coin_playing(audio, unexpected),
				"A new real %s selects its own recording after %s" % [cue, interruption])
			audio.halt()
			audio.queue_free()
			await process_frame


func _check_application_routes() -> void:
	var directory := "user://coin-audio-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Coin audio integration uses isolated saves")
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	for frame in range(4):
		await process_frame
	Fixture.enter_mode(app, "word_jelly")
	app.set_process(false)
	app._word_jelly.set_process(false)
	app._jelly.set_process(false)
	app._round_celebration.set_process(false)
	app.set_reduced_motion(false)
	app.audio.set_muted(false)
	app.audio.interact(app.model.theme_id, false)
	var chest: Dictionary = app._credit_coins("audio-chest", 1)
	app._present_room_coins("audio-chest", chest, Vector2.ZERO, true)
	check(chest.ok and app.coin_wallet.balance == 50 and not _coin_playing(app.audio),
		"The shared chest route commits its wallet receipt before the first visual burst frame")
	app._coin_flight.advance(0.016)
	check(_coin_playing(app.audio, Audio.COIN_RELEASE_PATH) and not _coin_playing(app.audio, Audio.COIN_PATH)
		and app._coin_counter.target == 0,
		"The first visible chest burst selects the appearance recording before any HUD deposit")
	app.audio.stop_coin_sounds()
	app._coin_flight.advance(Flight.BURST_SECONDS + Flight.TRAVEL_SECONDS - 0.015)
	check(_coin_playing(app.audio, Audio.COIN_PATH) and not _coin_playing(app.audio, Audio.COIN_RELEASE_PATH)
		and app._coin_counter.target > 0,
		"The chest's first actual HUD deposit selects the distinct arrival recording")
	app._show_mode_menu()
	check(_coin_players_silent(app.audio) and not app._coin_flight.snapshot().active
		and app._coin_counter.target == app.coin_wallet.balance,
		"Returning Home silently settles pending value and stops the current coin tail")
	app._hide_mode_menu()
	app.audio.interact(app.model.theme_id, false)
	var word: Dictionary = app._credit_word_jelly("audio-word", 100)
	app._word_jelly_collected("audio-word", {}, 100, 0, Vector2.ZERO)
	check(word.ok and app.coin_wallet.balance == 150 and not _coin_playing(app.audio),
		"Jelly Words saves its reward before the first visible coin frame")
	app._coin_flight.advance(0.016)
	check(_coin_playing(app.audio, Audio.COIN_RELEASE_PATH) and not _coin_playing(app.audio, Audio.COIN_PATH)
		and app._coin_counter.target == 50,
		"A collected Jelly Word selects the appearance recording at its first visible coin frame")
	app.audio.stop_coin_sounds()
	app._coin_flight.advance(Flight.BURST_SECONDS + Flight.TRAVEL_SECONDS - 0.015)
	check(_coin_playing(app.audio, Audio.COIN_PATH) and not _coin_playing(app.audio, Audio.COIN_RELEASE_PATH),
		"A collected Jelly Word switches to the distinct recording for its actual HUD deposit")
	app._show_collection()
	check(_coin_players_silent(app.audio) and not app._coin_flight.snapshot().active,
		"Opening the word library cancels coin tails even without halting all audio")
	app._hide_collection()
	app.audio.interact(app.model.theme_id, false)
	app._coin_flight.advance(10.0)
	check(_coin_players_silent(app.audio) and app.coin_wallet.balance == 150,
		"Returning from the library cannot replay settled coin audio or reward value")
	app.set_reduced_motion(true)
	word = app._credit_word_jelly("audio-reduced", 100)
	app._word_jelly_collected("audio-reduced", {}, 100, 0, Vector2.ZERO)
	app._coin_flight.advance(0.016)
	check(word.ok and _coin_playing(app.audio, Audio.COIN_RELEASE_PATH)
		and not _coin_playing(app.audio, Audio.COIN_PATH) and app._coin_counter.target == 150,
		"Reduced-motion Jelly Words retains the coin-appearance sound")
	app.audio.stop_coin_sounds()
	app._coin_flight.advance(0.225)
	check(word.ok and _coin_playing(app.audio, Audio.COIN_PATH)
		and not _coin_playing(app.audio, Audio.COIN_RELEASE_PATH) and app._coin_counter.displayed == 250.0,
		"Reduced-motion gameplay still acknowledges a real coin deposit audibly")
	app.on_page_hidden()
	check(_coin_players_silent(app.audio), "Backgrounding immediately stops coin feedback")
	app.on_page_visible()
	app._coin_flight.advance(10.0)
	check(_coin_players_silent(app.audio) and app.coin_wallet.balance == 250,
		"Resuming the page never replays the already settled deposit")
	_check_collect_application_route(app)
	_check_interrupted_word_release(app)
	app.audio.halt()
	app.queue_free()
	await process_frame


func _check_collect_application_route(app) -> void:
	Fixture.unlock_auto_collect(app)
	app.set_reduced_motion(false)
	app.audio.interact(app.model.theme_id, false)
	app.audio.stop_voice()
	var view = app._word_jelly
	var game = view.game
	game.spawn_interval = 10000.0
	# The first eligible Lv2 pickup wins; the other eleven Lv1 pickups never roll.
	game._coin_rng.seed = 208
	game.cells.clear()
	for index in range(12):
		var tile: Dictionary = game._new_tile(str(game._words[0].text), 2, 0)
		game._set_merged_word(tile, game._words[0], 1, true)
		tile.column = (index % 3) * 2
		tile.row = game.ROWS - 1 - floori(float(index) / 3.0)
		game.cells.append(tile)
	var rewarded_tile: Dictionary = game.cells[game._index_for_id(game.collectable_ids()[0])]
	rewarded_tile.mass = 4
	rewarded_tile.parts_count = 4
	game._set_merged_word(rewarded_tile, game._words[0], 2, true)
	check(game.coins_for_tile(game.cell(int(rewarded_tile.id))) == 50,
		"The first reserved collection is an eligible Lv2 word")
	view._sync_tiles()
	view._layout()
	var before: int = app.coin_wallet.balance
	var observed := {"time": 0.0, "releases": [], "receipts": [], "streams": []}
	var on_release := func() -> void:
		observed.releases.append(observed.time)
		var index: int = posmod(app.audio._coin_next_player - 1, Audio.COIN_CHANNELS)
		observed.streams.append(app.audio._coin_players[index].stream.resource_path)
	var on_collected := func(id: String, _word: Dictionary, coins: int, _fragments: int, _origin: Vector2) -> void:
		observed.receipts.append({"id": id, "coins": coins})
	app._coin_flight.release_sound.connect(on_release)
	view.collected.connect(on_collected)
	view.collect_button.pressed.emit()
	var voice_request: int = app.audio._playback_requests.get(app.audio.voice, 0)
	check(not app.audio.voice.playing, "Starting Collect cancels pending pronunciation before the first pickup")
	check(game.collection_batch_active() and game.collection_batch_snapshot().total == 12,
		"The real Collect button queues twelve valid merged jellies")
	for frame in range(ceili((12.0 * game.BATCH_BEAT_SECONDS + 0.2) / 0.01)):
		observed.time += 0.01
		view._process(0.01)
		app._coin_flight.advance(0.01)
	check(observed.receipts.size() == 12 and observed.releases.size() == 1
		and not game.collection_batch_active(),
		"Twelve rapid word pickups produce only the one successful rare coin appearance")
	check(observed.streams.size() == 1 and observed.streams[0] == Audio.COIN_RELEASE_PATH
		and is_equal_approx(float(observed.releases[0]), game.BATCH_BEAT_SECONDS),
		"The rare drop uses the appearance recording on its collection beat")
	check(observed.receipts[0].coins == 50
		and observed.receipts.slice(1).all(func(receipt: Dictionary) -> bool: return receipt.coins == 0),
		"The eleven ordinary pickups emit no coin reward and never trigger a release sound")
	check(app.coin_wallet.balance == before + 50,
		"Collect credits only its rare bonus")
	check(not app.audio.voice.playing and app.audio._playback_requests.get(app.audio.voice, 0) == voice_request,
		"Collect never adds pronunciation after its initial voice cancellation")
	var release_count: int = observed.releases.size()
	for receipt: Dictionary in observed.receipts:
		if int(receipt.coins) > 0:
			var duplicate: Dictionary = app._credit_word_jelly(str(receipt.id), int(receipt.coins))
			check(duplicate.ok and duplicate.duplicate,
				"A retried rare-drop receipt retains the wallet's idempotent result")
		app._word_jelly_collected(str(receipt.id), {}, int(receipt.coins), 0, Vector2.ZERO)
	app._coin_flight.advance(10.0)
	check(app.coin_wallet.balance == before + 50 and app._coin_counter.target == before + 50
		and observed.releases.size() == release_count and not app._coin_flight.snapshot().active,
		"Retries cannot duplicate rare-drop sounds or coins, and ordinary pickups cannot create a flight")
	app._coin_flight.release_sound.disconnect(on_release)
	view.collected.disconnect(on_collected)


func _check_interrupted_word_release(app) -> void:
	for interruption: String in ["mute", "background"]:
		app._coin_flight.sync(app.coin_wallet.balance)
		app.audio.interact(app.model.theme_id, false)
		var before: int = app.coin_wallet.balance
		var id: String = "audio-interrupted-" + interruption
		var reward: Dictionary = app._credit_word_jelly(id, 100)
		app._word_jelly_collected(id, {}, 100, 0, Vector2.ZERO)
		if interruption == "mute":
			app.audio.set_muted(true)
			app._coin_flight.advance(0.016)
			check(_coin_players_silent(app.audio), "Muted jelly elimination suppresses the coin-appearance cue")
			app.audio.set_muted(false)
			app._coin_flight.advance(0.016)
			check(_coin_players_silent(app.audio), "Unmuting cannot replay a missed jelly coin-appearance cue")
			app._coin_flight.sync(app.coin_wallet.balance)
		else:
			app.on_page_hidden()
			app.on_page_visible()
			app._coin_flight.advance(10.0)
			check(_coin_players_silent(app.audio), "Backgrounding before the first coin frame cancels its pending appearance cue")
		check(reward.ok and app.coin_wallet.balance == before + 100 and app._coin_counter.target == before + 100,
			"%s preserves the committed Jelly Word reward without replaying feedback" % interruption)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 800)
	_check_flight_timing()
	_check_chest_release_timing()
	_check_chest_release_boundaries()
	_check_chest_release_cadence()
	_check_overlapping_and_reduced()
	await _check_audio_channels()
	await _check_pending_audio()
	await _check_application_routes()
	await create_timer(0.15).timeout
	print("Coin audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
