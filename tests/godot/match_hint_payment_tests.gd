extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")

var checks: int = 0
var failures: int = 0
var round_seed: int = 1900
var storage: BrowserStorage


class BrowserStorage extends RefCounted:
	var text: Variant = null
	var fail_write: bool = false
	var writes: int = 0
	var calls: int = 0
	var after_save: Callable

	func coinWalletState() -> Variant:
		return text

	func saveCoinWalletState(value: String, expected: Variant) -> bool:
		calls += 1
		if fail_write or text != expected:
			return false
		text = value
		writes += 1
		if after_save.is_valid():
			var callback: Callable = after_save
			after_save = Callable()
			callback.call()
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _settle() -> void:
	for frame in range(4):
		await process_frame


func _prepare(app, coins: int = 0) -> void:
	round_seed += 1
	storage = BrowserStorage.new()
	app.coin_wallet = Wallet.new("user://unused-match-hint-wallet.cfg", storage)
	check(app.coin_wallet.load_state(), "The paid Match fixture loads an isolated empty wallet")
	if coins > 0:
		check(app.coin_wallet.credit("fixture:hint-funding", coins / Wallet.COINS_PER_TIER).ok,
			"Fund only this paid Match scenario through the durable credit API")
	check(app.new_round(round_seed, false, "", "match"), "The real scene starts a fresh Match round")
	await _settle()
	app.audio.set_muted(false)
	app.audio.interact(app.model.theme_id, false)
	app.audio.stop_pair_feedback()
	app.set_reduced_motion(true)
	app.hint_button.reset_feedback()
	app._coin_flight.sync(app.coin_wallet.balance)


func _state(app) -> Dictionary:
	return {"cards": app.model.cards.duplicate(true), "selected": app.model.selected_id,
		"matched": app.model.matched_ids.duplicate(), "feedback": app.model.feedback_ids.duplicate(),
		"correct": app.model.last_correct, "mistakes": app.model.mistakes, "phase": app.model.phase,
		"hints": app.model.hint_ids.duplicate(), "remaining": app.model.hints_remaining}


func _receipt(app, ordinal: int) -> String:
	return app._round_id + ":match-hint:" + str(ordinal)


func _clear_hint(app) -> void:
	if app.model.hint_ids.is_empty():
		return
	var id: String = str(app.model.hint_ids[0])
	if app.model.selected_id != id:
		app.cards[id].pressed.emit()
	app.cards[id].pressed.emit()
	check(app.model.hint_ids.is_empty() and app.model.selected_id.is_empty(),
		"Cancelling the suggested selection clears its hint without refunding the purchase")


func _pair(app, correct: bool) -> void:
	var first: Dictionary = app.model.lesson_words[0]
	var second: Dictionary = first if correct else app.model.lesson_words[1]
	app.cards[str(first.id) + ":word"].pressed.emit()
	app.cards[str(second.id) + ":image"].pressed.emit()
	app.feedback_timer.paused = true
	check(app.model.phase == "feedback" and app.model.last_correct == correct,
		"Real card presses start the requested answer feedback")


func _key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = pressed
	Input.parse_input_event(event)


func _joy(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X
	event.pressed = pressed
	Input.parse_input_event(event)


func _check_insufficient(app) -> void:
	await _prepare(app, 150)
	check(app.MATCH_HINT_PRICE == 200 and app.hint_button.cost == 200 and app.hint_button.count == 3,
		"Match shows a 200-coin price separately from its three-use allowance")
	check(Rect2(Vector2.ZERO, app.hint_button.size).encloses(app.hint_button.price_rect())
		and str(app.hint_button.get("accessibility_name")).contains("200"),
		"The visible price fits its button and is included in the accessible action name")
	var id: String = str(app.model.cards[0].id)
	app.cards[id].pressed.emit()
	var before: Dictionary = _state(app)
	var saved: Variant = storage.text
	var writes: int = storage.writes
	app.hint_button.pressed.emit()
	check(_state(app) == before and app.coin_wallet.balance == 150 and storage.text == saved and storage.writes == writes,
		"Insufficient coins preserve selection, cards, hints, allowance, and the complete saved wallet")
	check(app.hint_button._feedback_left > 0.0 and not app.hint_button._accepted
		and app.audio.pair_feedback.playing and app.audio.pair_feedback.stream == load(app.audio.PAIR_FEEDBACK_PATHS[false]),
		"An unaffordable hint produces negative button feedback and its negative sound")
	check(app.coin_wallet.ready and app.coin_wallet.error.is_empty() and app._coin_counter.available,
		"Insufficient coins leave otherwise healthy storage available")


func _check_native_inputs_and_limit(app) -> void:
	await _prepare(app, 800)
	var initial_writes: int = storage.writes
	for ordinal in range(1, 4):
		match ordinal:
			1:
				app.hint_button.pressed.emit()
			2:
				app.hint_button.grab_focus()
				_key(true)
				await process_frame
				_key(false)
				await _settle()
			3:
				_joy(true)
				_joy(false)
				await _settle()
		check(app.model.hint_ids.size() == 2 and app.model.hints_remaining == 3 - ordinal
			and app.hint_button.count == 3 - ordinal and app.hint_button.cost == 200,
			"Button, native keyboard, and Xbox X consume the same three-use hint allowance")
		check(app.coin_wallet.balance == 800 - ordinal * 200 and storage.writes == initial_writes + ordinal
			and app.coin_wallet._receipts.get(_receipt(app, ordinal), 0) == -200,
			"Each accepted native action persists exactly one 200-coin debit under its next ordinal")
		check(app.hint_button._feedback_left > 0.0 and app.hint_button._accepted
			and app.audio.pair_feedback.playing and app.audio.pair_feedback.stream == load(app.audio.PAIR_FEEDBACK_PATHS[true]),
			"A saved hint starts positive visual feedback and the purchase success sound")
		var before: Dictionary = _state(app)
		var writes: int = storage.writes
		app._request_hint()
		app.hint_button.pressed.emit()
		check(_state(app) == before and storage.writes == writes and app.coin_wallet.balance == 800 - ordinal * 200,
			"Duplicate callbacks while a hint is active cannot spend or consume another allowance")
		_clear_hint(app)
	var exhausted: Dictionary = _state(app)
	app._request_hint()
	_joy(true)
	_joy(false)
	await _settle()
	check(_state(app) == exhausted and app.coin_wallet.balance == 200 and app.hint_button.disabled,
		"The fourth hint remains blocked even when another 200 coins are available")
	var reloaded := Wallet.new("user://unused-match-hint-wallet.cfg", storage)
	check(reloaded.load_state() and reloaded.balance == 200 and reloaded._receipts == app.coin_wallet._receipts,
		"The three hint debits survive a real wallet reload")


func _check_feedback_payment(app) -> void:
	for correct: bool in [false, true]:
		await _prepare(app, 200)
		_pair(app, correct)
		var before: Dictionary = _state(app)
		var timer_left: float = app.feedback_timer.time_left
		var saved: Variant = storage.text
		storage.fail_write = true
		app._request_hint()
		check(_state(app) == before and app.coin_wallet.balance == 200 and storage.text == saved,
			"A failed durable save preserves answer feedback, selection, allowance, and coins")
		check(not app.feedback_timer.is_stopped() and is_equal_approx(app.feedback_timer.time_left, timer_left),
			"Payment failure neither dismisses nor restarts the correct or wrong feedback timer")
		check(not app._coin_counter.available and not app.coin_wallet.error.is_empty()
			and not app.hint_button._accepted, "Failed persistence reports unavailable storage and negative purchase feedback")
		storage.fail_write = false
		app._request_hint()
		check(app.coin_wallet.balance == 0 and app._coin_counter.available
			and app.coin_wallet._receipts.get(_receipt(app, 1), 0) == -200,
			"A retry saves exactly the same 200-coin ordinal after storage recovers")
		check(app.model.phase == "waiting" and app.model.hint_ids.size() == 2 and app.model.hints_remaining == 2
			and app.model.matched_ids == before.matched and app.model.mistakes == before.mistakes
			and app.feedback_timer.is_stopped(), "Successful payment continues feedback once and hints without scoring the answer twice")


func _check_blocked_states(app) -> void:
	await _prepare(app, 200)
	app._on_voice_state([true, true, "Listening"])
	app._on_voice_result([str(app.model.lesson_words[0].text), true])
	app.feedback_timer.paused = true
	check(app.model.phase == "feedback", "Spoken success creates the queued feedback lock")
	var before: Dictionary = _state(app)
	var writes: int = storage.writes
	app._request_hint()
	check(_state(app) == before and app.coin_wallet.balance == 200 and storage.writes == writes,
		"A hint blocked by queued voice feedback does not charge or consume allowance")
	app._on_voice_state([false, false, "Voice off"])
	app._request_hint()
	check(app.model.hints_remaining == 2 and app.model.hint_ids.size() == 2 and app.coin_wallet.balance == 0,
		"Leaving voice feedback restores the same paid manual hint route")
	await _prepare(app, 200)
	for word: Dictionary in app.model.lesson_words.duplicate(true):
		app.cards[str(word.id) + ":word"].pressed.emit()
		app.cards[str(word.id) + ":image"].pressed.emit()
		if app.model.matched_ids.size() < app.model.cards.size():
			app._continue_match()
	app.feedback_timer.paused = true
	before = _state(app)
	writes = storage.writes
	app._request_hint()
	check(app.model.phase == "feedback" and _state(app) == before and app.coin_wallet.balance == 200
		and storage.writes == writes, "Final-pair feedback cannot purchase a useless hint or bypass the result transition")
	await _prepare(app, 200)
	for covered: String in ["home", "library", "page"]:
		match covered:
			"home": app._show_mode_menu()
			"library": app._show_collection()
			"page": app.on_page_hidden()
		before = _state(app)
		writes = storage.writes
		app._request_hint()
		check(_state(app) == before and app.coin_wallet.balance == 200 and storage.writes == writes,
			"A covered " + covered + " page cannot buy a stale Match hint")
		match covered:
			"home": app._hide_mode_menu()
			"library": app._hide_collection()
			"page": app.on_page_visible()


func _check_receipt_recovery(app) -> void:
	await _prepare(app, 200)
	storage.after_save = func() -> void:
		app._request_hint()
		app.hint_button.pressed.emit()
	app._request_hint()
	check(app.model.hints_remaining == 2 and app.model.hint_ids.size() == 2 and app.coin_wallet.balance == 0
		and storage.writes == 2, "Reentrant input during persistence saves and accepts only one paid hint")
	await _prepare(app, 200)
	var initial_writes: int = storage.writes
	storage.after_save = func() -> void: app._show_mode_menu()
	app._request_hint()
	check(app._mode_menu_open() and app.model.hint_ids.is_empty() and app.model.hints_remaining == 3
		and app.coin_wallet.balance == 0 and app.coin_wallet._receipts.get(_receipt(app, 1), 0) == -200,
		"A page interruption during payment leaves the saved ordinal unconsumed instead of showing a hint behind Home")
	app._hide_mode_menu()
	app._request_hint()
	check(app.model.hint_ids.size() == 2 and app.model.hints_remaining == 2 and app.coin_wallet.balance == 0
		and storage.writes == initial_writes + 1, "Returning consumes the already-paid ordinal once without requiring another 200 coins")
	var before: Dictionary = _state(app)
	var stale: Dictionary = app._purchase_match_hint(1, 200)
	check(not stale.is_empty() and _state(app) == before and app.coin_wallet.balance == 0
		and storage.writes == initial_writes + 1, "An already-used host callback cannot spend or apply the hint twice")
	_clear_hint(app)
	app._request_hint()
	check(app.model.hint_ids.is_empty() and app.model.hints_remaining == 2 and app.coin_wallet.balance == 0,
		"A recovered ordinal cannot be reused as the next unpaid hint")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 800)
	var directory := "user://match-hint-payments-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await _settle()
	Fixture.enter_mode(app, "match")
	await _check_insufficient(app)
	await _check_native_inputs_and_limit(app)
	await _check_feedback_payment(app)
	await _check_blocked_states(app)
	await _check_receipt_recovery(app)
	app.audio.halt()
	app.queue_free()
	await _settle()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("Match hint payments: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
