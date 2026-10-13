extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")

var checks: int = 0
var failures: int = 0
var round_seed: int = 1800
var purchases: Array[Dictionary] = []
var feedback: Array[Dictionary] = []


class BrowserStorage extends RefCounted:
	var text: Variant = null
	var fail_write: bool = false
	var writes: int = 0
	var calls: int = 0

	func coinWalletState() -> Variant:
		return text

	func saveCoinWalletState(value: String, expected: Variant) -> bool:
		calls += 1
		if fail_write or text != expected:
			return false
		text = value
		writes += 1
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


func _watch_purchase(app) -> void:
	app._memory.purchase_peek = func(ordinal: int, price: int) -> Dictionary:
		purchases.append({"ordinal": ordinal, "price": price, "revealed_before_payment": app._memory.memory.studying})
		return app._purchase_memory_peek(ordinal, price)


func _prepare(app) -> void:
	round_seed += 1
	check(app.new_round(round_seed, false, "", "memory"), "The real scene starts a fresh Memory round")
	await _settle()
	app.audio.set_muted(false)
	app.audio.interact(app.model.theme_id, false)
	app.audio.stop_pair_feedback()
	purchases.clear()
	feedback.clear()
	_watch_purchase(app)


func _state(view) -> Dictionary:
	return {"cards": view.memory.cards.duplicate(true), "selected": view.memory.selected_indices.duplicate(),
		"matched": view.memory.matched_word_ids.duplicate(), "feedback": view.memory.feedback_words.duplicate(true),
		"attempts": view.memory.attempts, "mistakes": view.memory.mistakes, "phase": view.memory.phase,
		"studying": view.memory.studying, "peeks": view.memory.peeks, "price": view.memory.peek_price()}


func _check_free_and_insufficient(app, storage: BrowserStorage) -> void:
	await _prepare(app)
	var view = app._memory
	var writes: int = storage.writes
	view.begin_peek()
	view.begin_peek()
	view.study_button.button_down.emit()
	check(view.memory.studying and view.memory.peeks == 1 and view.memory.peek_price() == 100
		and purchases.is_empty() and storage.writes == writes and app.coin_wallet.balance == 0,
		"The first hold reveals for free once without a zero-cost wallet transaction")
	view.end_peek()
	view.card_buttons[0].pressed.emit()
	var before: Dictionary = _state(view)
	var saved: Variant = storage.text
	view.begin_peek()
	check(_state(view) == before and storage.text == saved and app.coin_wallet.balance == 0,
		"An insufficient paid reveal preserves the selected card, board, price, counter, and saved wallet")
	check(purchases.size() == 1 and purchases[0].ordinal == 2 and purchases[0].price == 100
		and not bool(purchases[0].revealed_before_payment), "Payment is requested with the next ordinal before exposing any hidden cards")
	check(not feedback.is_empty() and feedback.back() == {"success": false, "price": 100}
		and app.audio.pair_feedback.playing and app.audio.pair_feedback.stream == load(app.audio.PAIR_FEEDBACK_PATHS[false]),
		"An unfunded hold produces the negative response and the existing negative sound")
	var feedback_count: int = feedback.size()
	view.begin_peek()
	view.study_button.button_down.emit()
	check(purchases.size() == 1 and feedback.size() == feedback_count and _state(view) == before,
		"Duplicate native callbacks during one denied hold do not retry payment or spam feedback")
	view.end_peek()
	check(app.coin_wallet.ready and app.coin_wallet.error.is_empty() and app._coin_counter.available,
		"Ordinary insufficient funds never disable otherwise healthy coin storage")
	check(app.coin_wallet.credit("fixture:peek-funding", 1000).ok, "Fund the test wallet through its real durable credit API")
	app._coin_flight.sync(app.coin_wallet.balance)


func _check_price_sequence(app, storage: BrowserStorage) -> void:
	await _prepare(app)
	var view = app._memory
	var initial_balance: int = app.coin_wallet.balance
	var initial_writes: int = storage.writes
	var expected_spend: int = 0
	var ordinal: int = 0
	for price: int in [0, 100, 200, 300, 300, 300]:
		ordinal += 1
		var before_calls: int = purchases.size()
		var before_feedback: int = feedback.size()
		check(view.memory.peek_price() == price, "The next eye price matches its capped per-game schedule")
		view.begin_peek()
		expected_spend += price
		check(view.memory.studying and view.memory.peeks == ordinal and app.coin_wallet.balance == initial_balance - expected_spend,
			"A successful reveal charges exactly its current price before incrementing the count")
		check(purchases.size() == before_calls + (1 if price > 0 else 0), "Only paid uses call the wallet purchase boundary")
		if price > 0:
			check(app.coin_wallet._receipts.get(app._round_id + ":memory-peek:" + str(ordinal), 0) == -price,
				"Every paid use stores a durable debit under its round and ordinal")
			check(feedback.size() == before_feedback + 1 and feedback.back() == {"success": true, "price": price}
				and app.audio.pair_feedback.playing and app.audio.pair_feedback.stream == load(app.audio.PAIR_FEEDBACK_PATHS[true]),
				"A saved paid reveal starts one positive response and its sound")
		var accepted_calls: int = purchases.size()
		var accepted_feedback: int = feedback.size()
		view.begin_peek()
		view.study_button.button_down.emit()
		check(purchases.size() == accepted_calls and feedback.size() == accepted_feedback
			and app.coin_wallet.balance == initial_balance - expected_spend and view.memory.peeks == ordinal,
			"Repeated callbacks while the eye is held neither spend nor count twice")
		view.end_peek()
		view.end_peek()
		check(not view.memory.studying and view.memory.peeks == ordinal, "Repeated release only conceals the paid reveal")
	check(storage.writes == initial_writes + 5 and view.memory.peek_price() == 300,
		"Six reveals persist five payments and retain the 300-coin cap")
	var saved_balance: int = app.coin_wallet.balance
	var saved_receipts: Dictionary = app.coin_wallet._receipts.duplicate()
	var duplicate: Dictionary = app._purchase_memory_peek(ordinal, 300)
	check(app.coin_wallet.balance == saved_balance and app.coin_wallet._receipts == saved_receipts,
		"A stale already-used host callback cannot spend again")
	var reloaded := Wallet.new("user://unused-memory-peek-wallet.cfg", storage)
	check(reloaded.load_state() and reloaded.balance == saved_balance and reloaded._receipts == saved_receipts,
		"Paid reveals and their negative receipts survive a real wallet reload")
	check(not duplicate.is_empty(), "The host returns an explicit outcome for a stale purchase callback")


func _check_feedback_failure(app, storage: BrowserStorage) -> void:
	for correct: bool in [false, true]:
		await _prepare(app)
		var view = app._memory
		view.begin_peek()
		view.end_peek()
		var first: int = -1
		var second: int = -1
		for index in range(view.memory.cards.size()):
			if view.memory.cards[index].kind == "word":
				first = index
				break
		for index in range(view.memory.cards.size()):
			var card: Dictionary = view.memory.cards[index]
			if card.kind == "image" and (card.word.id == view.memory.cards[first].word.id) == correct:
				second = index
				break
		view.card_buttons[first].pressed.emit()
		view.card_buttons[second].pressed.emit()
		var before: Dictionary = _state(view)
		var timer_left: float = view._feedback_timer.time_left
		var balance: int = app.coin_wallet.balance
		var saved: Variant = storage.text
		storage.fail_write = true
		view.begin_peek()
		check(_state(view) == before and storage.text == saved and app.coin_wallet.balance == balance,
			"A failed save preserves correct or wrong feedback, every face, and the next paid ordinal")
		check(not view._feedback_timer.is_stopped() and is_equal_approx(view._feedback_timer.time_left, timer_left),
			"Denied payment does not dismiss or restart the active feedback timer")
		check(not app._coin_counter.available and not app.coin_wallet.error.is_empty(),
			"Storage failure is surfaced without pretending a reveal was bought")
		var calls: int = storage.calls
		view.begin_peek()
		check(storage.calls == calls and purchases.size() == 1, "A denied held press cannot retry a failing durable write")
		view.end_peek()
		storage.fail_write = false
		view.begin_peek()
		check(view.memory.studying and view.memory.phase == "waiting" and view.memory.peeks == 2
			and view.memory.attempts == before.attempts and view.memory.mistakes == before.mistakes
			and view.memory.matched_word_ids == before.matched and view._feedback_timer.is_stopped(),
			"A fresh successfully paid hold resolves feedback once without replaying the answer")
		check(app.coin_wallet.balance == balance - 100 and app._coin_counter.available
			and app.coin_wallet._receipts.get(app._round_id + ":memory-peek:2", 0) == -100,
			"Recovery saves one 100-coin receipt for the same previously denied reveal")
		view.end_peek()


func _check_missing_callback_and_reentry(app) -> void:
	await _prepare(app)
	var view = app._memory
	view.begin_peek()
	view.end_peek()
	view.purchase_peek = Callable()
	view.begin_peek()
	check(not view.memory.studying and view.memory.peeks == 1 and view.memory.peek_price() == 100,
		"An unwired paid reveal rejects instead of silently granting an unpaid effect")
	view.end_peek()
	var balance: int = app.coin_wallet.balance
	var reentrant_calls: Array = []
	view.purchase_peek = func(ordinal: int, price: int) -> Dictionary:
		reentrant_calls.append(ordinal)
		view.begin_peek()
		view.study_button.button_down.emit()
		return app._purchase_memory_peek(ordinal, price)
	view.begin_peek()
	check(view.memory.studying and view.memory.peeks == 2 and reentrant_calls == [2] and app.coin_wallet.balance == balance - 100,
		"Reentrant callbacks inside the payment boundary cannot recursively buy another reveal")
	view.end_peek()
	_watch_purchase(app)


func _check_paid_interruption(app) -> void:
	await _prepare(app)
	var view = app._memory
	view.begin_peek()
	view.end_peek()
	var balance: int = app.coin_wallet.balance
	var receipts: int = app.coin_wallet._receipts.size()
	view.purchase_peek = func(ordinal: int, price: int) -> Dictionary:
		var result: Dictionary = app._purchase_memory_peek(ordinal, price)
		view.pause(true)
		return result
	view.begin_peek()
	check(not view.memory.studying and view.memory.peeks == 1 and app.coin_wallet.balance == balance - 100,
		"A pause during an accepted payment prevents a stale reveal from opening behind the overlay")
	view.end_peek()
	view.pause(false)
	_watch_purchase(app)
	view.begin_peek()
	check(view.memory.studying and view.memory.peeks == 2 and app.coin_wallet.balance == balance - 100
		and app.coin_wallet._receipts.size() == receipts + 1,
		"A fresh hold consumes its already-paid ordinal without creating a second debit")
	view.end_peek()


func _check_lifecycle_and_reset(app) -> void:
	await _prepare(app)
	var view = app._memory
	view.begin_peek()
	view.end_peek()
	for cancellation: String in ["pause", "page", "home", "focus"]:
		var price: int = view.memory.peek_price()
		var balance: int = app.coin_wallet.balance
		var peeks: int = view.memory.peeks
		view.begin_peek()
		match cancellation:
			"pause": view.pause(true)
			"page": app.on_page_hidden()
			"home": app._show_mode_menu()
			"focus": view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(not view.memory.studying and view.memory.peeks == peeks + 1 and app.coin_wallet.balance == balance - price,
			"Cancelling an accepted " + cancellation + " hold hides cards without refunding or buying another use")
		match cancellation:
			"pause": view.pause(false)
			"page": app.on_page_visible()
			"home": app._hide_mode_menu()
		view.end_peek()
		check(not view.memory.studying and app.coin_wallet.balance == balance - price,
			"Returning after " + cancellation + " and a late release cannot reopen or recharge the eye")
	var old_round: String = app._round_id
	var balance: int = app.coin_wallet.balance
	await _prepare(app)
	check(app._round_id != old_round and view.memory.peeks == 0 and view.memory.peek_price() == 0,
		"A new game starts at free with a distinct receipt namespace")
	view.begin_peek()
	view.end_peek()
	check(app.coin_wallet.balance == balance and purchases.is_empty() and view.memory.peeks == 1,
		"The new round's first reveal is free even after the previous round reached the cap")
	view.begin_peek()
	check(app.coin_wallet.balance == balance - 100
		and app.coin_wallet._receipts.get(app._round_id + ":memory-peek:2", 0) == -100,
		"The new round's first paid use cannot reuse an old game's receipt")
	view.end_peek()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 800)
	var directory := "user://memory-peek-payments-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	var storage := BrowserStorage.new()
	app.coin_wallet = Wallet.new(directory + "/coins.cfg", storage)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await _settle()
	Fixture.enter_mode(app, "memory")
	app.set_reduced_motion(true)
	app._memory.peek_feedback.connect(func(success: bool, price: int) -> void: feedback.append({"success": success, "price": price}))
	await _check_free_and_insufficient(app, storage)
	await _check_price_sequence(app, storage)
	await _check_feedback_failure(app, storage)
	await _check_missing_callback_and_reentry(app)
	await _check_paid_interruption(app)
	await _check_lifecycle_and_reset(app)
	app.audio.halt()
	app.queue_free()
	await _settle()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("Memory peek payments: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
