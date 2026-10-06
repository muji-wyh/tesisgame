extends SceneTree

const UiClick = preload("res://scripts/ui_click.gd")
const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")

class CountingAudio extends "res://scripts/game_audio.gd":
	var click_count: int = 0

	func play_ui_click() -> void:
		if not muted and available:
			click_count += 1
		super()


var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _click(app, button: BaseButton, message: String) -> void:
	var count: int = app.audio.click_count
	button.pressed.emit()
	check(app.audio.click_count == count + 1, message + " plays exactly one UI click")


func _run() -> void:
	var directory := "user://ui-click-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	app._presentation.path = directory + "/presentation.cfg"
	PlayerFixture.install(app, directory)
	root.size = Vector2i(960, 900)
	root.add_child(app)
	await process_frame
	await process_frame
	var previous = app.audio
	app.remove_child(previous)
	previous.queue_free()
	app.audio = CountingAudio.new()
	app.add_child(app.audio)
	app.audio.set_muted(false)
	app.set_reduced_motion(true)
	await _check_library(app)
	await _check_collection_and_profiles(app)
	await _check_gameplay_exclusions_and_results(app)
	await _check_lifecycle(app)
	app.audio.halt()
	app.audio.stop_ui_click()
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("UI click: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_library(app) -> void:
	_click(app, app._mode_heading_button, "The header game menu")
	check(app._mode_menu_open(), "The library opens through its real header action")
	_click(app, app._mode_panel.motion_button, "The motion setting")
	_click(app, app._mode_panel.close_button, "The library Back button")
	_click(app, app.duck, "Pip acting as the game-menu button")
	var count: int = app.audio.click_count
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	app._input(cancel)
	check(not app._mode_menu_open() and app.audio.click_count == count + 1,
		"Escape dismisses the library with exactly one click")
	app._show_mode_menu()
	check(app.audio.click_count == count + 1, "Programmatic menu changes do not add UI sounds")
	_check_backdrop(app)
	app._show_mode_menu()
	UiClick.bind_button(app._mode_buttons[1])
	UiClick.bind_button(app._mode_buttons[1])
	await create_timer(0.12).timeout
	var request: int = app.audio._playback_requests.get(app.audio.ui_click, 0)
	var completions: Array[bool] = []
	app.audio.ui_click.finished.connect(func() -> void: completions.append(true), CONNECT_ONE_SHOT)
	_click(app, app._mode_buttons[1], "A Memory mode choice, even when bound repeatedly")
	check(app._mode_id == "memory" and app.audio._playback_requests.get(app.audio.ui_click, 0) == request + 1,
		"A mode change does not cancel its click request during gameplay shutdown")
	await create_timer(0.2).timeout
	check(completions.size() == 1, "A mode change lets its click reach a natural finish")
	app._show_mode_menu()
	count = app.audio.click_count
	app._mode_panel.sound_button.pressed.emit()
	check(app.audio.muted and not app.audio.ui_click.playing and app.audio.click_count == count,
		"Switching sound off immediately silences UI audio")
	app._mode_panel.motion_button.pressed.emit()
	check(app.audio.click_count == count, "Other settings remain silent while muted")
	_click(app, app._mode_panel.sound_button, "Switching sound back on")
	app._hide_mode_menu()
	app.choose_mode("match")
	await process_frame


func _check_backdrop(app) -> void:
	var count: int = app.audio.click_count
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(4, 4)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	app._mode_menu_input(press)
	release.canceled = true
	app._mode_menu_input(release)
	check(app._mode_menu_open() and app.audio.click_count == count, "Canceled backdrop presses stay silent")
	release.canceled = false
	app._mode_menu_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(4, 70)
	app._mode_menu_input(motion)
	app._mode_menu_input(release)
	check(app._mode_menu_open() and app.audio.click_count == count, "Backdrop drags do not dismiss or click")
	app._mode_menu_input(press)
	app._mode_menu_input(release)
	check(not app._mode_menu_open() and app.audio.click_count == count + 1, "A completed backdrop tap clicks once")
	app._mode_menu_input(release)
	check(app.audio.click_count == count + 1, "Duplicate release events cannot add clicks")
	for touch_first: bool in [false, true]:
		app._show_mode_menu()
		count = app.audio.click_count
		for down: bool in [true, false]:
			for touch: bool in [touch_first, not touch_first]:
				var event: InputEvent
				if touch:
					event = InputEventScreenTouch.new()
					event.index = 0
				else:
					event = InputEventMouseButton.new()
					event.button_index = MOUSE_BUTTON_LEFT
					event.device = InputEvent.DEVICE_ID_EMULATION
				event.pressed = down
				event.position = Vector2(4, 4)
				app._mode_menu_input(event)
		check(not app._mode_menu_open() and app.audio.click_count == count + 1,
			"Paired touch and emulated mouse events dismiss with one click: touch-first=%s" % touch_first)


func _check_collection_and_profiles(app) -> void:
	_click(app, app.collection_button, "The room navigation button")
	_click(app, app._age_buttons["all"], "The vocabulary age selector")
	_click(app, app._collection_back, "The vocabulary catalog Back action")
	_click(app, app.theme_buttons[1], "The world selector")
	var count: int = app.audio.click_count
	app._collection_dragged = true
	app._age_buttons["all"].pressed.emit()
	check(app.audio.click_count == count, "A canceled collection swipe cannot trigger an age click")
	app._collection_dragged = false
	_click(app, app._players_button, "The Players menu")
	await process_frame
	await process_frame
	var panel = app._leaderboard_panel
	var create: Button = panel.find_child("LeaderboardCreatePlayer", true, false)
	count = app.audio.click_count
	create.pressed.emit()
	check(create.disabled and app.audio.click_count == count, "Disabled player actions remain silent")
	_click(app, panel.find_child("LeaderboardAvatar_cat", true, false), "A dynamically created avatar button")
	var field: LineEdit = panel.find_child("LeaderboardName", true, false)
	field.text = "Click tester"
	field.text_changed.emit(field.text)
	count = app.audio.click_count
	field.text_submitted.emit(field.text)
	check(app.leaderboard_state.profiles.size() == 2 and app.audio.click_count == count + 1,
		"Submitting a name with Enter shares the enabled Create player's single click")
	await process_frame
	var profile_id: String = app.leaderboard_state.profiles[1].id
	_click(app, panel.find_child("LeaderboardEdit_" + profile_id, true, false), "A rebuilt Edit player action")
	_click(app, panel.find_child("LeaderboardCancelEdit", true, false), "The player editor Cancel action")
	_click(app, panel.find_child("LeaderboardRemove_" + profile_id, true, false), "The player removal prompt")
	_click(app, panel.find_child("LeaderboardCancelRemove", true, false), "The Keep player action")
	await process_frame
	await process_frame
	count = app.audio.click_count
	var scroll = app._leaderboard_scroll
	var avatar: Button = panel.find_child("LeaderboardAvatar_cat", true, false)
	var point := avatar.get_global_rect().get_center()
	scroll._begin(point, scroll.MOUSE_POINTER)
	scroll._move(point + Vector2(0, -80))
	scroll._finish(point + Vector2(0, -80))
	check(app.audio.click_count == count, "Dragging a player list does not play a button click")
	scroll.cancel_drag()
	app._controller_back()
	check(not app._leaderboard_overlay.visible and app.audio.click_count == count + 1,
		"Controller Back closes the player dialog with one click")
	_click(app, app._leaderboards_button, "The Leaderboards menu")
	_click(app, panel.find_child("LeaderboardMode_memory", true, false), "A dynamic leaderboard mode tab")
	app._controller_back()
	count = app.audio.click_count
	app._toggle_collection()
	check(not app.collection_page.visible and app.audio.click_count == count + 1,
		"The controller's room shortcut plays one navigation click")
	app._mode_heading_button.grab_focus()
	count = app.audio.click_count
	app._controller_accept()
	check(app._mode_menu_open() and app.audio.click_count == count + 1, "Controller Accept follows the same menu click")
	app._controller_back()


func _check_gameplay_exclusions_and_results(app) -> void:
	app.new_round(42, true, "", "match")
	var count: int = app.audio.click_count
	var first: Dictionary = app.model.cards[0]
	app.cards[first.id].pressed.emit()
	app._controller_back()
	app.hint_button.pressed.emit()
	check(app.audio.click_count == count, "Match cards, deselection and hints keep their gameplay sounds only")
	app.choose_mode("memory")
	app._memory.card_buttons[0].pressed.emit()
	app._memory.study_button.button_down.emit()
	app._memory.study_button.button_up.emit()
	check(app.audio.click_count == count, "Memory cards and peeking have no menu click")
	app.new_round(42, true, "", "match")
	for card in app.model.cards:
		if card.kind == "word":
			app.cards[card.id].pressed.emit()
			app.cards[card.word.id + ":image"].pressed.emit()
			app._continue_match()
	await process_frame
	await process_frame
	check(app.model.phase == "won" and app.audio.click_count == count, "Completing a real Match board adds no UI clicks")
	if app._found_words.get_child_count() > 0:
		app._found_words.get_child(0).pressed.emit()
	check(app.audio.click_count == count, "Result vocabulary replay remains a content-audio action")
	_click(app, app._result_board_button, "The result Leaderboard button")
	app._controller_back()
	await create_timer(0.12).timeout
	var request: int = app.audio._playback_requests.get(app.audio.ui_click, 0)
	var completions: Array[bool] = []
	app.audio.ui_click.finished.connect(func() -> void: completions.append(true), CONNECT_ONE_SHOT)
	_click(app, app._new_adventure_button, "The result New adventure button")
	check(app.audio._playback_requests.get(app.audio.ui_click, 0) == request + 1,
		"New adventure does not cancel its click request while rebuilding the board")
	await create_timer(0.2).timeout
	check(completions.size() == 1, "New adventure lets its click reach a natural finish")
	app.choose_mode("pop")
	_click(app, app._leaderboard_panel.find_child("LeaderboardPlayer_" + str(app.leaderboard_state.profiles[0].id), true, false),
		"The Voice Pop player choice")
	app._pop.set_process(false)
	app._on_voice_state([false, false, "Microphone is unavailable."])
	_click(app, app._pop._gate_back, "The Voice Pop Back action")


func _check_lifecycle(app) -> void:
	app.audio.halt()
	await create_timer(0.12).timeout
	var count: int = app.audio.click_count
	var completions: Array[bool] = []
	app.audio.ui_click.finished.connect(func() -> void: completions.append(true), CONNECT_ONE_SHOT)
	app.audio.play_ui_click()
	check(not app.audio.active and not app.audio.music.playing,
		"The menu cue works with gameplay audio inactive without starting music")
	check(app.audio.ui_click.stream == load(app.audio.UI_CLICK_PATH)
		and is_equal_approx(app.audio.ui_click.pitch_scale, 1.0)
		and is_equal_approx(db_to_linear(app.audio.ui_click.volume_db), app.audio.UI_CLICK_GAIN),
		"UI actions play the reference clip at its fixed gain and original pitch")
	var request: int = app.audio._playback_requests.get(app.audio.ui_click, 0)
	app.audio.halt()
	check(app.audio._playback_requests.get(app.audio.ui_click, 0) == request,
		"Navigation shutdown does not invalidate the UI click request")
	await create_timer(0.2).timeout
	check(completions.size() == 1, "A click started with gameplay inactive finishes naturally after shutdown")
	app.audio.play_ui_click()
	app.on_page_hidden()
	check(not app.audio.ui_click.playing and app.audio.ui_click.stream == null,
		"Backgrounding explicitly stops and clears the UI channel")
	app._play_ui_click()
	check(app.audio.click_count == count + 2, "Backgrounded UI actions cannot start new clicks")
	app.on_page_visible()
	app.audio.set_muted(true)
	app._play_ui_click()
	check(not app.audio.ui_click.playing and app.audio.click_count == count + 2, "Mute suppresses new UI clicks")
