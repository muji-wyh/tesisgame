extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")

var checks: int = 0
var failures: int = 0
var round_seed: int = 1900
var storage: BrowserStorage
var spend_sounds: int = 0


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
	# Settle the previous round against its own wallet before isolating this case.
	check(app.new_round(round_seed, false, "", "match"), "The real scene starts a fresh Match round")
	await _settle()
	storage = BrowserStorage.new()
	app.coin_wallet = Wallet.new("user://unused-match-hint-wallet.cfg", storage)
	check(app.coin_wallet.load_state(), "The paid Match fixture loads an isolated empty wallet")
	if coins > 0:
		check(app.coin_wallet.credit("fixture:hint-funding", coins / Wallet.COINS_PER_TIER).ok,
			"Fund only this paid Match scenario through the durable credit API")
	app.audio.set_muted(false)
	app.audio.interact(app.model.theme_id, false)
	app.audio.stop_pair_feedback()
	app.set_reduced_motion(true)
	app.hint_button.reset_feedback()
	app._coin_flight.sync(app.coin_wallet.balance)
	spend_sounds = 0


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
	await _prepare(app, 50)
	check(app._match_hint_price() == 100 and app.hint_button.cost == 100 and app.hint_button.count == 3,
		"Match shows its first 100-coin price separately from its three-use allowance")
	check(Rect2(Vector2.ZERO, app.hint_button.size).encloses(app.hint_button.price_rect())
		and str(app.hint_button.get("accessibility_name")).contains("100"),
		"The visible price fits its button and is included in the accessible action name")
	var id: String = str(app.model.cards[0].id)
	app.cards[id].pressed.emit()
	var before: Dictionary = _state(app)
	var saved: Variant = storage.text
	var writes: int = storage.writes
	app.hint_button.pressed.emit()
	check(_state(app) == before and app.coin_wallet.balance == 50 and storage.text == saved and storage.writes == writes
		and app._match_hint_price() == 100,
		"Insufficient coins preserve selection, cards, hints, allowance, and the complete saved wallet")
	check(app.hint_button._feedback_left > 0.0 and not app.hint_button._accepted
		and app.audio.pair_feedback.playing and app.audio.pair_feedback.stream == load(app.audio.PAIR_FEEDBACK_PATHS[false]),
		"An unaffordable hint produces negative button feedback and its negative sound")
	check(app.coin_wallet.ready and app.coin_wallet.error.is_empty() and app._coin_counter.available,
		"Insufficient coins leave otherwise healthy storage available")
	check(spend_sounds == 0 and not app._coin_flight.snapshot().debit_active
		and app._coin_counter.displayed == 50.0,
		"An unaffordable hint never starts a debit animation or a coin spending sound")


func _check_native_inputs_and_limit(app) -> void:
	await _prepare(app, 800)
	var initial_writes: int = storage.writes
	var spent: int = 0
	for ordinal in range(1, 4):
		var price: int = [100, 150, 200][ordinal - 1]
		check(app.hint_button.cost == price, "The next visible hint price matches its purchase ordinal")
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
		spent += price
		check(app.model.hint_ids.size() == 2 and app.model.hints_remaining == 3 - ordinal
			and app.hint_button.count == 3 - ordinal and app.hint_button.cost == [150, 200, 200][ordinal - 1],
			"Button, native keyboard, and Xbox X consume the same three-use hint allowance")
		check(app.coin_wallet.balance == 800 - spent and storage.writes == initial_writes + ordinal
			and app.coin_wallet._receipts.get(_receipt(app, ordinal), 0) == -price,
			"Each accepted native action persists exactly one escalating debit under its next ordinal")
		check(app.hint_button._feedback_left > 0.0 and app.hint_button._accepted
			and app.audio.pair_feedback.playing and app.audio.pair_feedback.stream == load(app.audio.PAIR_FEEDBACK_PATHS[true]),
			"A saved hint starts positive visual feedback and the purchase success sound")
		check(spend_sounds == ordinal and app.hint_button.disabled,
			"Every paid hint emits one coin spending cue while its success response survives disabled input")
		var before: Dictionary = _state(app)
		var writes: int = storage.writes
		app._request_hint()
		app.hint_button.pressed.emit()
		check(_state(app) == before and storage.writes == writes and app.coin_wallet.balance == 800 - spent,
			"Duplicate callbacks while a hint is active cannot spend or consume another allowance")
		check(spend_sounds == ordinal, "Repeated active-hint input cannot replay its coin spending sound")
		_clear_hint(app)
	var exhausted: Dictionary = _state(app)
	app._request_hint()
	_joy(true)
	_joy(false)
	await _settle()
	check(_state(app) == exhausted and app.coin_wallet.balance == 350 and app.hint_button.disabled,
		"The fourth hint remains blocked even with enough coins for another purchase")
	check(spend_sounds == 3, "Exhausted hints cannot create a fourth coin spending cue")
	var reloaded := Wallet.new("user://unused-match-hint-wallet.cfg", storage)
	check(reloaded.load_state() and reloaded.balance == 350 and reloaded._receipts == app.coin_wallet._receipts,
		"The three hint debits survive a real wallet reload")
	check(app.new_round(2900, false, "", "match") and app.hint_button.cost == 100,
		"A fresh board restores the first hint price without altering past debits")


func _check_feedback_payment(app) -> void:
	for correct: bool in [false, true]:
		await _prepare(app, 100)
		_pair(app, correct)
		var before: Dictionary = _state(app)
		var timer_left: float = app.feedback_timer.time_left
		var saved: Variant = storage.text
		storage.fail_write = true
		app._request_hint()
		check(_state(app) == before and app.coin_wallet.balance == 100 and storage.text == saved,
			"A failed durable save preserves answer feedback, selection, allowance, and coins")
		check(not app.feedback_timer.is_stopped() and is_equal_approx(app.feedback_timer.time_left, timer_left),
			"Payment failure neither dismisses nor restarts the correct or wrong feedback timer")
		check(not app._coin_counter.available and not app.coin_wallet.error.is_empty()
			and not app.hint_button._accepted, "Failed persistence reports unavailable storage and negative purchase feedback")
		check(spend_sounds == 0 and not app._coin_flight.snapshot().debit_active,
			"A failed durable save does not pretend to spend coins visually or audibly")
		storage.fail_write = false
		app._request_hint()
		check(app.coin_wallet.balance == 0 and app._coin_counter.available
			and app.coin_wallet._receipts.get(_receipt(app, 1), 0) == -100,
			"A retry saves exactly the same 100-coin ordinal after storage recovers")
		check(app.model.phase == "waiting" and app.model.hint_ids.size() == 2 and app.model.hints_remaining == 2
			and app.model.matched_ids == before.matched and app.model.mistakes == before.mistakes
			and app.feedback_timer.is_stopped(), "Successful payment continues feedback once and hints without scoring the answer twice")
		check(spend_sounds == 1, "A successful storage retry emits its coin spending cue exactly once")


func _check_debit_animation(app) -> void:
	for balance: int in [1000, 100]:
		await _prepare(app, balance)
		app.set_reduced_motion(false)
		var expected: int = balance - 100
		app.hint_button.pressed.emit()
		var state: Dictionary = app._coin_flight.snapshot()
		check(app.coin_wallet.balance == expected and state.target == expected
			and state.displayed == float(balance) and state.debit_active and state.active
			and state.debit_amount == 100 and spend_sounds == 1,
			"A committed hint debit starts at the previous visible balance while saving its final balance immediately")
		var previous: float = state.displayed
		for step in range(4):
			app._coin_flight.advance(0.12)
			state = app._coin_flight.snapshot()
			check(state.displayed < previous and state.displayed > float(expected) and state.target == expected,
				"The visible wallet counts downward without skipping its digit boundary or overshooting zero")
			previous = state.displayed
		app._coin_flight.advance(0.8)
		state = app._coin_flight.snapshot()
		check(state.displayed == float(expected) and not state.debit_active and not state.active
			and spend_sounds == 1,
			"The wallet settles exactly at the paid total without a delayed second spending cue")


func _check_debit_cancellation(app) -> void:
	await _prepare(app, 1000)
	app.set_reduced_motion(false)
	app.hint_button.pressed.emit()
	app._coin_flight.advance(0.12)
	check(app._coin_flight.snapshot().debit_active and app._coin_counter.displayed > 900.0,
		"Page cancellation begins during a live paid debit")
	app.on_page_hidden()
	var state: Dictionary = app._coin_flight.snapshot()
	check(not state.debit_active and not state.active and state.displayed == 900.0 and state.target == 900
		and app.hint_button._feedback_left == 0.0,
		"Hiding the page clears Hint feedback and reconciles the paid wallet without refunding it")
	app.on_page_visible()
	app._coin_flight.advance(1.0)
	check(not app._coin_flight.snapshot().debit_active and app._coin_counter.displayed == 900.0
		and spend_sounds == 1,
		"Returning to the page does not resume or replay the old debit")


func _check_reduced_debit(app) -> void:
	await _prepare(app, 1000)
	app.hint_button.pressed.emit()
	check(app._coin_counter.displayed == 900.0 and app._coin_counter.target == 900
		and app.hint_button._feedback_left > 0.0 and app.hint_button._accepted and spend_sounds == 1,
		"Reduced motion acknowledges the purchase while the wallet immediately shows its exact paid total")
	for delta: float in [0.1, 0.2, 1.0]:
		app._coin_flight.advance(delta)
		check(app._coin_counter.displayed == 900.0 and app._coin_counter.target == 900,
			"Reduced-motion debit feedback never drifts the wallet number")
	check(not app._coin_flight.snapshot().debit_active and spend_sounds == 1,
		"Reduced-motion feedback finishes without queuing a late spending sound")


func _coin_sound_playing(app) -> bool:
	for player: AudioStreamPlayer in app.audio._coin_players:
		if player.playing and player.stream == load(app.audio.COIN_PATH):
			return true
	return false


func _check_voice_payment_audio(app) -> void:
	for balance: int in [50, 100]:
		await _prepare(app, balance)
		app._on_voice_state([true, true, "Listening"])
		check(app._voice_mode and not app.audio.active and not app.audio.pair_feedback.playing
			and not _coin_sound_playing(app),
			"Enabling the microphone leaves Hint payment audio cold before this real purchase attempt")
		app.hint_button.pressed.emit()
		var accepted: bool = balance >= 100
		check(app.hint_button._accepted == accepted and app.hint_button._feedback_left > 0.0
			and app.audio.active and app.audio.pair_feedback.playing
			and app.audio.pair_feedback.stream == load(app.audio.PAIR_FEEDBACK_PATHS[accepted]),
			"A voice-mode Hint attempt activates its matching success or failure sound from cold audio")
		check(not app.audio.music.playing and not app.audio.voice.playing,
			"Microphone-mode purchase feedback does not start music or a competing word pronunciation")
		check(_coin_sound_playing(app) == accepted and spend_sounds == (1 if accepted else 0)
			and app.coin_wallet.balance == (0 if accepted else 50),
			"Only a paid microphone-mode Hint plays the physical coin spending sound and changes the balance")


func _check_muted_payment(app) -> void:
	for balance: int in [50, 100]:
		await _prepare(app, balance)
		app.audio.set_muted(true)
		app.hint_button.pressed.emit()
		var accepted: bool = balance >= 100
		check(app.hint_button._accepted == accepted and app.hint_button._feedback_left > 0.0
			and app.coin_wallet.balance == (0 if accepted else 50)
			and spend_sounds == (1 if accepted else 0),
			"Muting preserves positive or negative purchase visuals and the exact durable payment result")
		check(not app.audio.active and not app.audio.pair_feedback.playing
			and not _coin_sound_playing(app) and not app.audio.music.playing and not app.audio.voice.playing,
			"Neither a successful nor rejected muted Hint can restart any payment, music or speech audio")
		app.audio.set_muted(false)
		app._coin_flight.advance(1.0)
		check(not _coin_sound_playing(app) and not app.audio.pair_feedback.playing,
			"Unmuting after a purchase does not replay the muted payment feedback")


func _check_blocked_states(app) -> void:
	await _prepare(app, 100)
	app._on_voice_state([true, true, "Listening"])
	app._on_voice_result([str(app.model.lesson_words[0].text), true])
	app.feedback_timer.paused = true
	check(app.model.phase == "feedback", "Spoken success creates the queued feedback lock")
	var before: Dictionary = _state(app)
	var writes: int = storage.writes
	app._request_hint()
	check(_state(app) == before and app.coin_wallet.balance == 100 and storage.writes == writes,
		"A hint blocked by queued voice feedback does not charge or consume allowance")
	check(spend_sounds == 0, "Queued voice feedback cannot start a Hint coin spending cue")
	app._on_voice_state([false, false, "Voice off"])
	app._request_hint()
	check(app.model.hints_remaining == 2 and app.model.hint_ids.size() == 2 and app.coin_wallet.balance == 0,
		"Leaving voice feedback restores the same paid manual hint route")
	await _prepare(app, 100)
	for word: Dictionary in app.model.lesson_words.duplicate(true):
		app.cards[str(word.id) + ":word"].pressed.emit()
		app.cards[str(word.id) + ":image"].pressed.emit()
		if app.model.matched_ids.size() < app.model.cards.size():
			app._continue_match()
	app.feedback_timer.paused = true
	before = _state(app)
	writes = storage.writes
	app._request_hint()
	check(app.model.phase == "feedback" and _state(app) == before and app.coin_wallet.balance == 100
		and storage.writes == writes, "Final-pair feedback cannot purchase a useless hint or bypass the result transition")
	await _prepare(app, 100)
	for covered: String in ["home", "library", "page"]:
		match covered:
			"home": app._show_mode_menu()
			"library": app._show_collection()
			"page": app.on_page_hidden()
		before = _state(app)
		writes = storage.writes
		app._request_hint()
		check(_state(app) == before and app.coin_wallet.balance == 100 and storage.writes == writes,
			"A covered " + covered + " page cannot buy a stale Match hint")
		check(spend_sounds == 0 and not app._coin_flight.snapshot().debit_active,
			"A covered " + covered + " page cannot emit stale spending feedback")
		match covered:
			"home": app._hide_mode_menu()
			"library": app._hide_collection()
			"page": app.on_page_visible()


func _check_receipt_recovery(app) -> void:
	await _prepare(app, 100)
	storage.after_save = func() -> void:
		app._request_hint()
		app.hint_button.pressed.emit()
	app._request_hint()
	check(app.model.hints_remaining == 2 and app.model.hint_ids.size() == 2 and app.coin_wallet.balance == 0
		and storage.writes == 2, "Reentrant input during persistence saves and accepts only one paid hint")
	check(spend_sounds == 1, "Reentrant payment input emits only one coin spending cue")
	await _prepare(app, 100)
	var initial_writes: int = storage.writes
	storage.after_save = func() -> void: app._show_mode_menu()
	app._request_hint()
	check(app._mode_menu_open() and app.model.hint_ids.is_empty() and app.model.hints_remaining == 3
		and app.coin_wallet.balance == 0 and app.coin_wallet._receipts.get(_receipt(app, 1), 0) == -100,
		"A page interruption during payment leaves the saved ordinal unconsumed instead of showing a hint behind Home")
	check(spend_sounds == 0 and not app._coin_flight.snapshot().debit_active,
		"A navigation interruption suppresses payment effects on the covered Match page")
	app._hide_mode_menu()
	app._request_hint()
	check(app.model.hint_ids.size() == 2 and app.model.hints_remaining == 2 and app.coin_wallet.balance == 0
		and storage.writes == initial_writes + 1, "Returning consumes the already-paid ordinal once without requiring another 100 coins")
	check(spend_sounds == 0 and not app._coin_flight.snapshot().debit_active,
		"Recovering an already-paid ordinal cannot animate or sound a second debit")
	var before: Dictionary = _state(app)
	var stale: Dictionary = app._purchase_match_hint(1, 100)
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
	app._coin_flight.spend_sound.connect(func() -> void: spend_sounds += 1)
	await _check_insufficient(app)
	await _check_native_inputs_and_limit(app)
	await _check_feedback_payment(app)
	await _check_debit_animation(app)
	await _check_debit_cancellation(app)
	await _check_reduced_debit(app)
	await _check_voice_payment_audio(app)
	await _check_muted_payment(app)
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
