extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
var checks := 0
var failures := 0


class DelayedUpgradeAudio extends "res://scripts/game_audio.gd":
	signal milestone_loaded
	signal charging_loaded
	var delay_milestone := false
	var delay_charging := false

	func _stream(path: String, loop: bool = false) -> AudioStream:
		if delay_milestone and path == JELLY_PATHS.goal_complete:
			await milestone_loaded
		if delay_charging and path == UPGRADE_CHARGE_PATH:
			await charging_loaded
		return await super._stream(path, loop)


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func playing(audio) -> bool:
	return audio.upgrade_milestone != null and audio.upgrade_milestone.playing


func touch(page, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 7
	event.position = page._buy.get_global_rect().get_center()
	event.pressed = pressed
	root.push_input(event)
	await process_frame


func accept(source: String, pressed: bool, echo: bool = false) -> void:
	var event: InputEvent
	if source == "key":
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		key.echo = echo
		event = key
	else:
		var joy := InputEventJoypadButton.new()
		joy.device = 0
		joy.button_index = JOY_BUTTON_A
		joy.pressed = pressed
		event = joy
	root.push_input(event)
	await process_frame


func _run() -> void:
	await _test_continuous_charge_audio()
	var audio := DelayedUpgradeAudio.new()
	root.add_child(audio)
	audio.active = true
	audio.play_upgrade_milestone()
	check(playing(audio) and audio.upgrade_milestone.stream.resource_path == Audio.JELLY_PATHS.goal_complete,
		"A saved upgrade uses the production reward recording on its dedicated channel")
	audio.stop_jelly_sounds()
	check(playing(audio), "Board cue cancellation lets the upgrade milestone finish")
	audio.set_muted(true)
	check(not playing(audio) and audio.upgrade_milestone.stream == null, "Muting cancels and clears the milestone")
	audio.set_muted(false)
	audio.play_upgrade_milestone()
	check(not playing(audio), "Unmuting cannot restart a milestone while audio is inactive")
	audio.active = true
	audio.available = false
	audio.play_upgrade_milestone()
	check(not playing(audio), "Unavailable audio rejects the milestone")
	audio.available = true
	audio.play_upgrade_milestone()
	audio.active = false
	audio._process(0.01)
	check(not playing(audio) and audio.upgrade_milestone.stream == null,
		"Losing audio activation cancels an active milestone")
	audio.active = true
	audio.delay_milestone = true
	audio.play_upgrade_milestone()
	audio.halt()
	audio.milestone_loaded.emit()
	await process_frame
	check(not playing(audio) and audio.upgrade_milestone.stream == null,
		"A delayed recording cannot start after halt cancels its request")
	audio.active = true
	audio.play_upgrade_milestone()
	audio.stop_jelly_sounds()
	audio.milestone_loaded.emit()
	await process_frame
	check(playing(audio), "Pausing board cues cannot cancel a pending upgrade recording")
	audio.set_muted(true)
	audio.queue_free()

	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	var directory := "user://upgrade-lifecycle-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Use isolated real application saves")
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	for frame in range(4):
		await process_frame
	app.set_process(false)
	app._word_jelly.set_process(false)
	app._jelly.set_process(false)
	app._show_mode_menu()
	app.choose_mode("word_jelly")
	check(app.coin_wallet.credit_amount("fixture:upgrade-lifecycle", 100).ok, "Fund the real hold with an isolated receipt")
	app._coin_flight.sync(app.coin_wallet.balance)
	app._campaign.open_upgrades()
	var page = app._campaign.upgrades
	check(page.visible and page._active, "Open the actual upgrade page through the campaign map")
	for reason: String in ["host_cancel", "window_release", "resize", "controller_cancel"]:
		await touch(page, true)
		check(page.snapshot().charging, "A real touch begins the %s cancellation case" % reason)
		check(app.audio.upgrade_charge != null and app.audio.upgrade_charge.playing,
			"The %s press starts its continuous charging recording immediately" % reason)
		app._advance_ui(0.05)
		match reason:
			"host_cancel": app._on_input_canceled()
			"window_release": app._on_pointer_released(7)
			"resize":
				root.size += Vector2i(1, 0)
				await process_frame
			"controller_cancel": app._stop_controller_actions()
		for frame in range(12):
			app._advance_ui(0.05)
			app.audio._process(0.05)
		check(not page.snapshot().charging and app.coin_wallet.balance == 100
			and app._campaign.store.upgrade_state().funded.jelly == 0,
			"%s stops spending without requiring a canvas release" % reason)
		check(not app.audio.upgrade_charge.playing,
			"%s also releases the continuous charging sound" % reason)
		await touch(page, false)
	app.audio.set_muted(false)
	app.audio.interact(app.model.theme_id, false)
	await touch(page, true)
	var first_debit_voice: AudioStreamPlayer
	var first_debit_request := 0
	for frame in range(80):
		app._advance_ui(0.05)
		if first_debit_voice == null and app.coin_wallet.balance == 75:
			for channel: AudioStreamPlayer in app.audio._coin_players:
				if channel.stream != null:
					first_debit_voice = channel
					first_debit_request = app.audio._playback_requests[channel]
					break
		if app._campaign.store.merged_level() == 2:
			page.stop_charging()
		if playing(app.audio):
			break
	check(app._campaign.store.merged_level() == 2 and app.coin_wallet.balance == 50 and playing(app.audio),
		"A real held upgrade spends fifty coins and leaves its actual milestone sound playing")
	check(first_debit_voice != null and app.audio._playback_requests[first_debit_voice] == first_debit_request,
		"The next real contribution reconciles the counter without cutting the preceding wallet sound")
	app._sync_jelly()
	app._refresh()
	check(playing(app.audio), "Normal paused-board synchronization and refresh preserve the upgrade sound")
	await touch(page, false)
	check(app.coin_wallet.credit_amount("fixture:upgrade-navigation", 200).ok,
		"Fund keyboard and gamepad controls through an isolated receipt")
	page.configure(app._campaign._upgrade_state())
	for source: String in ["key", "joy"]:
		page._buy.grab_focus()
		var before: int = app.coin_wallet.balance
		await accept(source, true)
		check(page.snapshot().charging and app._controller_holding_upgrade,
			"A real %s accept press starts the focused upgrade hold" % source)
		for frame in range(5):
			app._advance_ui(0.05)
		await accept(source, false)
		for frame in range(12):
			app._advance_ui(0.05)
		check(app.coin_wallet.balance == before - 25 and not page.snapshot().charging
			and not app._controller_holding_upgrade,
			"A real %s release stops after exactly its held contribution" % source)
		page._buy.grab_focus()
		before = app.coin_wallet.balance
		await accept(source, true)
		page._back.grab_focus()
		await process_frame
		for frame in range(12):
			app._advance_ui(0.05)
		check(not page.snapshot().charging and app.coin_wallet.balance == before,
			"Moving focus away cancels the held %s gesture before another debit" % source)
		await accept(source, false)
	page._buy.grab_focus()
	app._controller_accept()
	check(page.snapshot().charging, "The existing controller accept route starts a held upgrade")
	await accept("joy", false)
	check(not page.snapshot().charging, "The controller release route also stops a directly routed hold")
	page._buy.grab_focus()
	await accept("key", true)
	page._back.grab_focus()
	page._buy.grab_focus()
	await accept("key", true, true)
	check(not page.snapshot().charging, "Keyboard echo cannot restart a charge canceled by focus movement")
	await accept("key", false)
	for source: String in ["key", "joy"]:
		check(app._campaign.store.begin_upgrade_contribution("jelly", 25),
			"Reserve an unpaid contribution for the %s Retry route" % source)
		page.configure(app._campaign._upgrade_state())
		page._buy.grab_focus()
		var before: int = app.coin_wallet.balance
		await accept(source, true)
		for frame in range(20):
			app._advance_ui(0.05)
		await accept(source, false)
		check(app.coin_wallet.balance == before - 25 and not page.snapshot().charging
			and app._campaign.store.upgrade_state().pending.is_empty(),
			"The %s Retry gesture resumes once without becoming a continuous charge" % source)
	page._buy.grab_focus()
	await accept("key", true)
	var before_cancel: int = app.coin_wallet.balance
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.physical_keycode = KEY_ESCAPE
	cancel.pressed = true
	root.push_input(cancel)
	await process_frame
	for frame in range(12):
		app._advance_ui(0.05)
	check(app._campaign.map.visible and not page.visible and not app._controller_holding_upgrade
		and app.coin_wallet.balance == before_cancel,
		"Keyboard Back cancels the accept hold before returning to the map")
	await accept("key", false)
	cancel.pressed = false
	root.push_input(cancel)
	await process_frame
	app._campaign.open_upgrades()
	app.on_page_hidden()
	check(not playing(app.audio), "Backgrounding the application cancels the upgrade sound")
	check(not app.audio.upgrade_charge.playing and app.audio.upgrade_charge.stream == null,
		"Backgrounding clears the sustained charge immediately")
	app.on_page_visible()
	check(not playing(app.audio), "Returning to the page never replays the canceled milestone")
	app.audio.halt()
	app.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Jelly upgrade audio and input lifecycle: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_continuous_charge_audio() -> void:
	var audio := DelayedUpgradeAudio.new()
	root.add_child(audio)
	audio.set_upgrade_charging(true)
	check(audio.upgrade_charge == null, "Inactive input cannot allocate a charging voice")
	audio.active = true
	audio.set_upgrade_charging(true)
	var player: AudioStreamPlayer = audio.upgrade_charge
	check(player != null and player.playing and player.stream is AudioStreamWAV
		and player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"A hold starts the acquired periodic pressure recording as one continuous loop")
	check(is_equal_approx(player.stream.get_length(), 0.8), "The production charge texture retains its authored duration")
	var request: int = audio._playback_requests[player]
	var previous_db: float = player.volume_db
	audio._process(1.0 / 60.0)
	check(player.volume_db > previous_db and player.volume_db < linear_to_db(Audio.UPGRADE_CHARGE_GAIN),
		"The charging sound attacks over multiple frames")
	for frame in range(120):
		if frame % 10 == 0:
			audio.set_upgrade_charging(true)
			audio.play_upgrade_coin_spend()
		audio._process(1.0 / 60.0)
	check(player.playing and audio._playback_requests[player] == request,
		"Repeated receipts and hold updates preserve the same continuous playback request")
	check(audio._coin_players.size() == Audio.COIN_CHANNELS,
		"Frequent debits use the bounded existing coin voice pool")
	for channel: AudioStreamPlayer in audio._coin_players:
		check(channel.volume_db <= linear_to_db(Audio.UPGRADE_COIN_GAIN) + 0.001,
			"Frequent wallet sounds stay below the ordinary reward gain")
	audio.stop_jelly_sounds()
	check(player.playing, "Paused board synchronization cannot interrupt the held charging loop")
	audio.set_upgrade_charging(false)
	audio._process(0.03)
	check(player.playing and player.volume_db < linear_to_db(Audio.UPGRADE_CHARGE_GAIN),
		"Release fades the existing loop instead of cutting its waveform abruptly")
	for frame in range(3):
		audio._process(0.02)
	check(not player.playing and player.stream == null, "Release clears the loop within ninety milliseconds")
	audio.set_upgrade_charging(true)
	audio.set_muted(true)
	check(not player.playing and player.stream == null, "Mute bypasses the fade and silences charging immediately")
	audio.set_muted(false)
	check(not player.playing, "Unmute does not restart an abandoned hold")
	audio.active = true
	audio.delay_charging = true
	audio.set_upgrade_charging(true)
	audio.set_upgrade_charging(false)
	audio.charging_loaded.emit()
	await process_frame
	check(not player.playing and player.stream == null, "A delayed loop cannot start after release")
	audio.set_upgrade_charging(true)
	audio.halt()
	audio.charging_loaded.emit()
	await process_frame
	check(not player.playing and player.stream == null, "A delayed loop cannot start after navigation")
	audio.delay_charging = false
	audio.active = true
	audio.set_upgrade_charging(true)
	audio.available = false
	audio._process(0.01)
	check(not player.playing and player.stream == null, "Loss of audio availability stops the sustained voice")
	audio.queue_free()
	await process_frame
