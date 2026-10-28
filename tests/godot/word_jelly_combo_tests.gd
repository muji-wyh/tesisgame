extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
const Economy = preload("res://scripts/coin_economy.gd")
const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
var checks: int = 0
var failures: int = 0


class Storage extends RefCounted:
	var text: Variant = null
	var fail_write: bool = false
	var writes: int = 0

	func coinWalletState() -> Variant:
		return text

	func saveCoinWalletState(value: String, expected: Variant) -> bool:
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


func _run() -> void:
	_test_manual_rewards()
	_test_neutral_actions_and_invalid_merge()
	_test_countdown()
	_test_countdown_completion_order()
	_test_collection_batch_and_assistance()
	_test_batch_cancel_and_upgrade()
	_test_high_level_upgrade_combo()
	_test_save_retry()
	_test_lost_payment_acknowledgement()
	_test_concurrent_merges()
	_test_collection_commit_order()
	_test_finish_and_reconfigure()
	_test_payment_reentrancy()
	_test_committed_learning_reentrancy()
	await _test_game_ui_wallet()
	print("Word Jelly combo: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _word(text: String = "cat") -> Dictionary:
	return {"id": "combo:" + text, "text": text, "min_age": 3,
		"image": "assets/images/words/" + text + ".webp", "audio": "assets/audio/words/" + text + ".wav"}


func _fixture() -> Dictionary:
	var storage := Storage.new()
	var wallet := Wallet.new("user://unused-combo-wallet.cfg", storage)
	check(wallet.load_state(), "Load an isolated real wallet for combo persistence")
	var model := Model.new()
	check(model.configure([_word(), _word("dog")], 3, 71), "Configure real root and picture merging")
	model.set_pip_level(3)
	model.cells.clear()
	model.spawn_interval = 10000.0
	var payments: Array = []
	var changes: Array = []
	model.credit_combo = func(event_id: String, amount: int) -> Dictionary:
		payments.append({"event_id": event_id, "amount": amount})
		return wallet.credit_amount("test-round:combo:" + event_id, amount)
	model.combo_changed.connect(func(state: Dictionary) -> void: changes.append(state.duplicate(true)))
	return {"model": model, "wallet": wallet, "storage": storage, "payments": payments, "changes": changes}


func _put(model: RefCounted, tile: Dictionary) -> Dictionary:
	var at: Vector2i = model._free_position(model._occupied(), 1, 1)
	check(at.x >= 0, "The combo fixture has a free board cell")
	tile.column = at.x
	tile.row = at.y
	tile.age = 100.0
	tile.settling = false
	tile.arrival = false
	tile.falling = false
	model.cells.append(tile)
	return tile


func _pair(model: RefCounted) -> Array[Dictionary]:
	return [_put(model, model._new_word_root(_word(), 0)), _put(model, model._new_picture_tile(_word(), 0))]


func _ready(model: RefCounted, text: String = "cat") -> Dictionary:
	var tile: Dictionary = model._new_word_root(_word(text), 0)
	model._set_merged_word(tile, _word(text), 1, true)
	return _put(model, tile)


func _seed_with_collections(model: RefCounted, amount: int = 2) -> void:
	for index in range(amount):
		var tile: Dictionary = _ready(model)
		check(model.collect(int(tile.id)), "A real completed word begins collection")
		model.step(2.0)
	check(model.combo_snapshot().actions == amount and model.combo_snapshot().coins == 0,
		"Successful collections establish a chain without issuing combo coins")


func _begin_pair(model: RefCounted) -> Dictionary:
	var pair: Array[Dictionary] = _pair(model)
	check(model.try_merge(int(pair[0].id), int(pair[1].id)) == "merged", "Accept a manual root and matching picture")
	return model.fusions.back().duplicate(true) if not model.fusions.is_empty() else {}


func _test_manual_rewards() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	var expected: Array[int] = [0, 0, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3]
	var total: int = 0
	var ids: Array[String] = []
	for index in range(expected.size()):
		var operation: Dictionary = _begin_pair(model)
		check(model.combo_snapshot().actions == index and fixture.wallet.balance == total,
			"Accepting a merge does not count or pay before its successful completion")
		model.step(2.0)
		total += expected[index]
		var combo: Dictionary = model.combo_snapshot()
		var level: int = 1 if index + 1 < 3 else 2 if index + 1 < 7 else 3 if index + 1 < 12 else 4
		check(combo.actions == index + 1 and combo.count == level and combo.best == level and combo.bonus == expected[index]
			and combo.coins == total and fixture.wallet.balance == total,
			"Committed manual merges follow the 0, 1, 2, 3 coin schedule exactly")
		check(not model.cell(int(operation.result.id)).is_empty() and model.cell(int(operation.a_id)).is_empty()
			and model.cell(int(operation.b_id)).is_empty(), "A counted merge consumes both source bodies once")
		ids.append(str(combo.event_id))
		model._complete_operation(str(operation.attempt_id))
		model.retry_combo_credit()
		check(model.combo_snapshot() == combo and fixture.wallet.balance == total,
			"Duplicate completion and retry calls cannot count or credit an already finished merge")
	check(fixture.payments.size() == 10 and fixture.changes.size() == 12 and total == 20,
		"The first two successes need no payment; every later completion has one payment and one combo event")
	for index in range(ids.size()):
		check(ids.count(ids[index]) == 1, "Each counted success has a distinct stable event identity")
	for count: int in [10, 25, 40, 100, 1000000]:
		check(Economy.jelly_combo_bonus(count) == 3, "Long chains retain the three-coin reward cap")
	var wrong_root: Dictionary = _put(model, model._new_word_root(_word(), 0))
	var wrong_picture: Dictionary = _put(model, model._new_picture_tile(_word("dog"), 0))
	check(model.try_merge(int(wrong_root.id), int(wrong_picture.id)) == "wrong"
		and model.combo_snapshot().count == 0 and model.combo_snapshot().best == 4
		and model.combo_snapshot().coins == total and fixture.wallet.balance == total,
		"Breaking a long chain cannot remove saved coins or its best result")
	for next_count in range(1, 4):
		_begin_pair(model)
		model.step(2.0)
		check(model.combo_snapshot().actions == next_count and fixture.wallet.balance == total + (1 if next_count == 3 else 0),
			"After a mistake the reward threshold starts again from the new chain")
	total += 1
	var result: Dictionary = model.finish_round()
	check(result.combo_coins == total and result.coins == total and result.best_combo == 4,
		"Round results include earned combo coins and the best chain exactly once")
	model.credit_combo = Callable()


func _test_neutral_actions_and_invalid_merge() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	_seed_with_collections(model)
	var before: Dictionary = model.combo_snapshot()
	check(model.try_merge(-1, -2) == "ignored" and model.combo_snapshot() == before,
		"Missing or stale merge targets leave the chain intact")
	var root: Dictionary = _put(model, model._new_word_root(_word(), 0))
	model.set_held_tile(int(root.id))
	model.set_held_tile()
	check(model.reposition(int(root.id), 4, Model.ROWS - 1), "A neutral drag can reposition an ordinary body")
	model.step(1.0)
	var paused_combo: Dictionary = model.combo_snapshot()
	model.set_paused(true)
	model.step(100.0)
	check(model.combo_snapshot() == paused_combo, "A long pause freezes both the chain and its countdown")
	model.set_paused(false)
	model.step(1.0)
	check(model.combo_count == int(before.count), "Neutral movement does not directly break the active chain")
	before = model.combo_snapshot()
	var generated: int = model.generated_tiles
	check(model.drop_now() and model.generated_tiles > generated and model.combo_snapshot() == before,
		"Fast-dropping the preview supplies new bodies without breaking or advancing the chain")
	check(not model.drop_now(-99) and model.combo_snapshot() == before,
		"A stale preview gesture is neutral")
	model.step(2.0)
	before = model.combo_snapshot()
	check(model.replace_stage_words([_word(), _word("dog")], 3) and model.combo_snapshot() == before,
		"A vocabulary stage transition preserves the current count, best, and reward state")
	var wrong: Dictionary = _put(model, model._new_picture_tile(_word("dog"), 0))
	check(model.try_merge(int(root.id), int(wrong.id)) == "wrong", "An actual wrong root-picture pair is rejected")
	check(model.combo_snapshot().count == 0 and model.combo_snapshot().best == 1
		and model.combo_snapshot().coins == 0 and model.combo_snapshot().event_id == "",
		"An invalid merge resets only the active chain, retaining the round's best and earned coins")
	model.credit_combo = Callable()


func _test_countdown() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	_begin_pair(model)
	model.step(Model.FUSION_SECONDS)
	var fresh: Dictionary = model.combo_snapshot()
	check(is_equal_approx(float(fresh.get("seconds", 0.0)), 8.0)
		and is_equal_approx(float(fresh.get("remaining", 0.0)), 8.0),
		"A committed success starts a full eight-second combo window")
	model.step(3.0)
	check(model.combo_count == 1 and is_equal_approx(float(model.combo_snapshot().get("remaining", 0.0)), 5.0),
		"Active gameplay drains the model-owned countdown in real seconds")
	var frozen: Dictionary = model.combo_snapshot()
	for invalid: float in [0.0, -1.0, NAN, INF]:
		model.step(invalid)
	model.set_paused(true)
	model.step(100.0)
	check(model.combo_snapshot() == frozen, "Invalid deltas and pause cannot consume combo time")
	model.set_paused(false)
	var operation: Dictionary = _begin_pair(model)
	model.step(Model.FUSION_SECONDS)
	fresh = model.combo_snapshot()
	check(model.combo_actions == 2 and model.combo_count == 1 and is_equal_approx(float(fresh.get("remaining", 0.0)), 8.0),
		"A subsequent committed success refills rather than extends the countdown")
	model.step(1.0)
	var before_duplicate: Dictionary = model.combo_snapshot()
	model._complete_operation(str(operation.attempt_id))
	check(model.combo_snapshot() == before_duplicate, "Duplicate completion cannot refill an existing combo")
	model.step(7.0)
	var expired: Dictionary = model.combo_snapshot()
	check(model.combo_count == 0 and expired.best == 1 and expired.coins == 0
		and expired.bonus == 0 and expired.event_id == "" and float(expired.get("remaining", -1.0)) == 0.0,
		"Reaching zero ends only the current chain, preserving its best result and earned coins")
	check(fixture.changes.size() == 3 and fixture.changes.back().count == 0,
		"Expiry emits one reset event instead of another successful increment")
	model.step(20.0)
	check(fixture.changes.size() == 3, "An expired chain cannot emit repeated timeout events")
	_begin_pair(model)
	model.step(Model.FUSION_SECONDS)
	check(model.combo_count == 1 and fixture.wallet.balance == 0,
		"The first success after expiry starts a new unrewarded chain")
	model.credit_combo = Callable()


func _test_countdown_completion_order() -> void:
	for until_expiry: float in [0.40, Model.FUSION_SECONDS]:
		var fixture: Dictionary = _fixture()
		var model: RefCounted = fixture.model
		_seed_with_collections(model)
		var remaining: float = float(model.combo_snapshot().get("remaining", 8.0))
		model.step(remaining - until_expiry)
		_begin_pair(model)
		model.step(Model.FUSION_SECONDS)
		check(model.combo_count == 1 and model.combo_coins == 0 and fixture.wallet.balance == 0,
			"A merge completed at or after the deadline starts a new chain without the old tier's payment")
		check(is_equal_approx(float(model.combo_snapshot().get("remaining", 0.0)), 8.0),
			"The new chain receives its full window even when one frame spans the old expiry and completion")
		model.credit_combo = Callable()
	var coarse: Dictionary = _fixture()
	var fine: Dictionary = _fixture()
	for fixture: Dictionary in [coarse, fine]:
		_seed_with_collections(fixture.model, 3)
	coarse.model.step(8.0)
	for tick in range(80):
		fine.model.step(0.10)
	check(coarse.model.combo_snapshot() == fine.model.combo_snapshot(),
		"Coarse and fine frames agree on expiry, best combo and credited coins")
	coarse.model.credit_combo = Callable()
	fine.model.credit_combo = Callable()


func _test_collection_batch_and_assistance() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	for index in range(5):
		_ready(model, "cat" if index % 2 == 0 else "dog")
	check(model.start_collection_batch(), "Automatic Collect captures a ready group")
	model.step(Model.BATCH_BEAT_SECONDS * 5.0 + 0.01)
	check(model.combo_snapshot().actions == 5 and model.cleared_pairs == 5 and not model.collection_batch_active()
		and fixture.payments.is_empty() and fixture.wallet.balance == 0,
		"Every automatic collection extends the chain once without minting combo rewards")
	check(fixture.changes.size() == 5, "Each automatic collection emits one increment for HUD and audio feedback")
	for state: Dictionary in fixture.changes:
		check(state.bonus == 0, "Collection feedback reports no manual-merge reward")
	_pair(model)
	model.purchase_powerup = func(_id: String, _kind: String, _price: int) -> Dictionary: return {"ok": true}
	check(model.activate_powerup("auto_merge"), "A paid Auto Merge can complete the next pictured word")
	model.finish_powerup(false)
	check(model.combo_snapshot().actions == 6 and fixture.payments.is_empty() and fixture.wallet.balance == 0,
		"Paid Auto Merge increments the combo on commit without inventing an automatic coin payout")
	check(model.start_collection_batch(), "The assisted result remains collectable")
	model.step(2.0)
	check(model.combo_snapshot().actions == 7 and fixture.wallet.balance == 0,
		"Collecting an assisted result still extends the chain without refunding its purchase")
	_begin_pair(model)
	model.step(2.0)
	check(model.combo_snapshot().actions == 8 and fixture.wallet.balance == 2,
		"The next manual merge receives the tier reached through automatic collection")
	model.credit_combo = Callable()
	model.purchase_powerup = Callable()


func _test_batch_cancel_and_upgrade() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	for index in range(4):
		_ready(model)
	check(model.start_collection_batch(), "Start a batch with four independently collectable words")
	model.cancel_collection_batch()
	model.step(2.0)
	check(model.combo_snapshot().count == 1 and model.cleared_pairs == 1 and model.cells.size() == 3,
		"Canceling a batch settles only its accepted item and preserves that earned increment")
	check(model.start_collection_batch(), "A later Collect command can resume the remaining words")
	model.step(2.0)
	check(model.combo_snapshot().actions == 4 and fixture.payments.is_empty(),
		"Resuming a canceled batch extends its existing chain without combo coin farming")
	var left: Dictionary = _ready(model)
	var right: Dictionary = _ready(model)
	check(model.try_merge(int(left.id), int(right.id)) == "merged", "Identical completed words accept a manual level upgrade")
	var upgraded_id: int = int(model.fusions.back().result.id)
	model.step(2.0)
	check(model.cell(upgraded_id).merge_level == 2 and model.combo_snapshot().actions == 5 and fixture.wallet.balance == 1,
		"A successful manual level upgrade counts and pays under the same rule as a root-picture merge")
	model.credit_combo = Callable()


func _test_high_level_upgrade_combo() -> void:
	for level: int in [7, 8, 9]:
		var fixture: Dictionary = _fixture()
		var model: RefCounted = fixture.model
		_seed_with_collections(model)
		var left: Dictionary = _ready(model)
		var right: Dictionary = _ready(model)
		model._set_merged_word(left, _word(), level - 1, true)
		check(model.try_merge(int(left.id), int(right.id)) == "merged", "A high-level additive upgrade remains an ordinary manual merge")
		var result_id: int = int(model.fusion.result.id)
		model.step(2.0)
		check(model.cell(result_id).merge_level == level and model.combo_actions == 3
			and fixture.wallet.balance == 1 and fixture.payments.size() == 1,
			"A Lv%d upgrade advances combo once and retains the existing one-coin tier" % level)
		check(model.collect(result_id), "The high-level result remains manually collectable")
		model.step(2.0)
		check(model.combo_actions == 4 and fixture.wallet.balance == 1 and fixture.payments.size() == 1,
			"Collecting a Lv%d word advances combo once without paying another merge bonus" % level)
		model.credit_combo = Callable()


func _test_save_retry() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	_seed_with_collections(model)
	var spare: Dictionary = _ready(model, "dog")
	var operation: Dictionary = _begin_pair(model)
	fixture.storage.fail_write = true
	model.step(2.0)
	check(model.combo_snapshot().pending and model.combo_snapshot().actions == 2 and fixture.wallet.balance == 0
		and not model.cell(int(operation.a_id)).is_empty() and not model.cell(int(operation.b_id)).is_empty()
		and model.cell(int(operation.result.id)).is_empty(), "Failed payment retains both merge sources without counting or granting coins")
	var frozen: Dictionary = model.snapshot()
	model.step(100.0)
	check(model.snapshot() == frozen, "An unpaid combo freezes the simulation until retry or exit")
	check(not model.drop_now(), "Pending save blocks a new preview drop")
	check(not model.collect(int(spare.id)), "Pending save blocks a new manual collection")
	check(not model.start_collection_batch(), "Pending save blocks a new automatic collection batch")
	check(not model.begin_drag(int(spare.id)), "Pending save blocks a new drag")
	check(not model.reposition(int(spare.id), 4, Model.ROWS - 1), "Pending save blocks a body reposition")
	check(model.try_merge(int(spare.id), int(operation.a_id)) == "ignored", "Pending save blocks another merge attempt")
	model.retry_combo_credit()
	check(fixture.payments.size() == 2 and fixture.payments[0] == fixture.payments[1]
		and model.combo_snapshot().actions == 2, "A repeated failure preserves the exact event, reward, and chain position")
	fixture.storage.fail_write = false
	model.retry_combo_credit()
	check(not model.combo_snapshot().pending and model.combo_snapshot().actions == 3 and model.combo_snapshot().coins == 1
		and fixture.wallet.balance == 1 and fixture.storage.writes == 1 and model.error.is_empty(),
		"Successful retry durably pays and commits the retained merge exactly once")
	check(fixture.payments.size() == 3 and fixture.payments[0] == fixture.payments[2]
		and model.cell(int(operation.a_id)).is_empty() and not model.cell(int(operation.result.id)).is_empty(),
		"Recovery reuses the original receipt and replaces its original sources")
	model.retry_combo_credit()
	check(fixture.payments.size() == 3 and model.combo_snapshot().actions == 3 and fixture.wallet.balance == 1,
		"Repeated Retry saving cannot farm the completed reward")
	model.credit_combo = Callable()


func _test_lost_payment_acknowledgement() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	var wallet: RefCounted = fixture.wallet
	_seed_with_collections(model)
	var attempts: Array = []
	model.credit_combo = func(event_id: String, amount: int) -> Dictionary:
		var response: Dictionary = wallet.credit_amount("lost-ack:" + event_id, amount)
		attempts.append({"id": event_id, "amount": amount, "duplicate": response.get("duplicate", false)})
		return {"ok": false} if attempts.size() == 1 else response
	_begin_pair(model)
	model.step(2.0)
	check(model.combo_snapshot().pending and model.combo_snapshot().actions == 2 and wallet.balance == 1,
		"A lost acknowledgement retains the merge while its durable receipt remains paid")
	model.retry_combo_credit()
	check(model.combo_snapshot().actions == 3 and model.combo_snapshot().coins == 1 and wallet.balance == 1
		and attempts.size() == 2 and attempts[1].duplicate and attempts[0].id == attempts[1].id,
		"Retry acknowledges an already saved coin and completes once without a second reward")
	model.credit_combo = Callable()


func _test_concurrent_merges() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	_seed_with_collections(model, 4)
	var first: Dictionary = _begin_pair(model)
	var second: Dictionary = _begin_pair(model)
	fixture.storage.fail_write = true
	model.step(2.0)
	check(model.combo_snapshot().actions == 4 and model.fusions.size() == 2 and fixture.payments.size() == 1,
		"A failed first payment freezes both concurrent merges before either source pair is consumed")
	fixture.storage.fail_write = false
	model.retry_combo_credit()
	model.step(1.0)
	check(model.combo_snapshot().actions == 6 and model.combo_snapshot().coins == 3 and fixture.wallet.balance == 3,
		"Concurrent successes cross the reward threshold in committed order with one- then two-coin awards")
	check(fixture.payments.size() == 3 and fixture.payments[0] == fixture.payments[1]
		and fixture.payments[1].amount == 1 and fixture.payments[2].amount == 2
		and fixture.payments[2].event_id == second.attempt_id
		and not model.cell(int(first.result.id)).is_empty() and not model.cell(int(second.result.id)).is_empty(),
		"Each concurrent merge owns an immutable receipt and its own committed result")
	model.credit_combo = Callable()


func _test_collection_commit_order() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	_seed_with_collections(model)
	var tile: Dictionary = _ready(model)
	var requests: Array = []
	model.commit_collection = func(payload: Dictionary) -> Dictionary:
		requests.append(payload.duplicate(true))
		return {"pending": true}
	check(model.collect(int(tile.id)), "Start a collection whose durable acknowledgement is delayed")
	model.step(1.0)
	check(requests.size() == 1 and model.combo_snapshot().actions == 2,
		"A pending collection does not increment the combo early")
	_begin_pair(model)
	model.step(2.0)
	check(model.combo_snapshot().actions == 3 and fixture.wallet.balance == 1,
		"A later merge that commits first earns the third-success reward")
	var request: Dictionary = requests[0]
	check(model.resolve_collection_commit(str(request.event_id), int(request.generation), {"ok": false})
		and model.combo_snapshot().actions == 3, "A failed delayed collection leaves the committed merge's chain intact")
	check(model.collect(int(tile.id)), "The same failed collection can retry")
	model.step(1.0)
	check(requests.size() == 2 and requests[0].event_id == requests[1].event_id,
		"Collection retry preserves its existing permanent identity")
	check(model.resolve_collection_commit(str(request.event_id), int(request.generation), {"ok": true})
		and model.combo_snapshot().actions == 4 and fixture.wallet.balance == 1,
		"Collection acknowledgement advances the chain once with no extra combo payment")
	check(not model.resolve_collection_commit(str(request.event_id), int(request.generation), {"ok": true})
		and model.combo_snapshot().actions == 4, "A duplicate asynchronous acknowledgement cannot add a combo")
	model.commit_collection = Callable()
	model.credit_combo = Callable()


func _test_finish_and_reconfigure() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	_seed_with_collections(model)
	var operation: Dictionary = _begin_pair(model)
	fixture.storage.fail_write = true
	model.step(2.0)
	var result: Dictionary = model.finish_round("exit")
	check(model.phase == "finished" and not model.combo_snapshot().pending and result.combo_coins == 0
		and result.best_combo == 1 and fixture.wallet.balance == 0,
		"Finishing cancels an unpaid pending reward without claiming a successful merge")
	check(not model.cell(int(operation.a_id)).is_empty() and not model.cell(int(operation.b_id)).is_empty(),
		"Canceling unpaid settlement retains its unconsumed source bodies")
	fixture.storage.fail_write = false
	model.retry_combo_credit()
	check(fixture.payments.size() == 1 and fixture.wallet.balance == 0,
		"A retry after leaving the round cannot resurrect the canceled reward")
	check(model.configure([_word()], 3, 72) and model.combo_snapshot().count == 0
		and model.combo_snapshot().best == 0 and model.combo_snapshot().coins == 0,
		"A genuinely new round starts with a fresh combo")
	model.credit_combo = Callable()


func _test_payment_reentrancy() -> void:
	for action: String in ["pause", "finish", "retry", "configure", "finish-failed"]:
		var fixture: Dictionary = _fixture()
		var model: RefCounted = fixture.model
		var wallet: RefCounted = fixture.wallet
		_seed_with_collections(model)
		var attempts: Array = []
		var operation: Dictionary = _begin_pair(model)
		model.credit_combo = func(event_id: String, amount: int) -> Dictionary:
			attempts.append(event_id)
			var response: Dictionary = {"ok": false} if action == "finish-failed" else wallet.credit_amount("reentrant:" + event_id, amount)
			match action:
				"pause": model.set_paused(true)
				"finish", "finish-failed": model.finish_round("callback-exit")
				"retry": model.retry_combo_credit()
				"configure": check(not model.configure([_word()], 3, 73), "Round replacement is blocked while a combo payment is in flight")
			return response
		model.step(2.0)
		if action == "finish-failed":
			check(model.phase == "finished" and not model.combo_snapshot().pending and model.combo_snapshot().actions == 2
				and wallet.balance == 0, "A finish requested inside a failed payment callback cancels unpaid settlement cleanly")
		else:
			check(model.combo_snapshot().actions == 3 and model.combo_snapshot().coins == 1 and wallet.balance == 1
				and model.cell(int(operation.a_id)).is_empty() and not model.cell(int(operation.result.id)).is_empty(),
				"Payment callback reentrancy cannot separate the saved coin from its committed merge")
			if action == "finish":
				check(model.phase == "finished" and model.snapshot().result.coins == 1,
					"Finish waits for the paid merge and includes its coin in the final result")
			elif action == "pause":
				check(model.paused, "A callback pause remains active after the accepted reward settles")
		check(attempts.size() == 1, "A reentrant callback cannot start the same payment twice")
		model.credit_combo = Callable()


func _test_committed_learning_reentrancy() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	var learned: Array = []
	model.word_attempted.connect(func(id: String, words: Array[String], correct: bool) -> void: learned.append([id, words, correct]))
	model.combo_changed.connect(func(state: Dictionary) -> void:
		if int(state.count) == 1:
			model.configure([_word()], 3, 74))
	var tile: Dictionary = _ready(model)
	check(model.collect(int(tile.id)), "A mastery-eligible collection begins before presentation callbacks")
	model.step(2.0)
	check(learned.size() == 1 and bool(learned[0][2]),
		"An already committed collection records its learning evidence before combo presentation can replace the round")
	model.credit_combo = Callable()


func _settle_ui() -> void:
	for frame in range(5):
		await process_frame


func _game_ui_merge(view, word: Dictionary) -> String:
	var model: RefCounted = view.game
	var root_tile: Dictionary = _put(model, model._new_word_root(word, 0))
	var picture: Dictionary = _put(model, model._new_picture_tile(word, 0))
	view._sync_tiles()
	check(model.try_merge(int(root_tile.id), int(picture.id)) == "merged",
		"The real application accepts an eligible manual root-picture merge")
	var event_id: String = str(model.fusions.back().attempt_id)
	model.step(2.0)
	view._process(0.0)
	return event_id


func _test_game_ui_wallet() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory: String = "user://jelly-combo-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated application combo storage")
	var app = load("res://scenes/main.tscn").instantiate()
	PlayerFixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await _settle_ui()
	PlayerFixture.enter_mode(app, "word_jelly")
	await _settle_ui()
	app.set_process(false)
	app.audio.set_muted(true)
	var view = app._word_jelly
	view.set_process(false)
	var word: Dictionary = view.game._words.filter(func(item: Dictionary) -> bool: return not str(item.get("image", "")).is_empty())[0]
	check(view.configure([word], app.growth.learning_age(), Data.theme(app.model.theme_id), app.data.chests, true, 81),
		"The application combo fixture uses a real current-age word and its production picture")
	app._sync_jelly()
	var model: RefCounted = view.game
	model.cells.clear()
	model.spawn_interval = 10000.0
	_game_ui_merge(view, word)
	_game_ui_merge(view, word)
	check(app.coin_wallet.balance == 0 and model.combo_snapshot().actions == 2,
		"The real application saves no coins before the third consecutive success")
	var first_event: String = _game_ui_merge(view, word)
	var first_receipt: String = app._round_id + ":combo:" + first_event
	check(model.combo_snapshot().actions == 3 and app.coin_wallet.balance == 1
		and app.coin_wallet._receipts.get(first_receipt, 0) == 1 and app._coin_counter.target == 0
		and app._coin_flight.snapshot().active,
		"GameUI saves the round-scoped combo coin but holds its visible balance until arrival")
	app._coin_flight.advance(2.0)
	check(app._coin_counter.target == 1 and app._coin_counter.displayed == 1.0,
		"The saved combo coin reaches the real header through its arrival-driven counter")
	var wallet_path: String = app.coin_wallet._path
	check(DirAccess.make_dir_absolute(wallet_path + ".pending") == OK, "Block the real wallet's next native staging write")
	var retry_event: String = _game_ui_merge(view, word)
	await _settle_ui()
	check(model.combo_snapshot().pending and model.combo_snapshot().actions == 3 and app.coin_wallet.balance == 1
		and not app._jelly_interaction_allowed() and not view._can_play(),
		"A real save failure preserves the chain and coin balance while blocking gameplay input")
	check(app._storage_retry_button.is_visible_in_tree(), "The application exposes Retry saving for a pending combo payment")
	check(DirAccess.remove_absolute(wallet_path + ".pending") == OK, "Restore the real wallet staging path")
	app._retry_storage()
	await _settle_ui()
	var retry_receipt: String = app._round_id + ":combo:" + retry_event
	check(not model.combo_snapshot().pending and model.combo_snapshot().actions == 4
		and app.coin_wallet.balance == 2 and app.coin_wallet._receipts.get(retry_receipt, 0) == 1
		and app._coin_counter.target == 1 and app._coin_flight.snapshot().active and app._jelly_interaction_allowed(),
		"The real Retry saving action pays once, completes the merge, restores input and launches the recovered coin")
	app._coin_flight.advance(2.0)
	check(app._coin_counter.target == 2 and app._coin_counter.displayed == 2.0,
		"The recovered saved reward increments the header only through the coin's arrival")
	app._retry_storage()
	check(model.combo_snapshot().actions == 4 and app.coin_wallet.balance == 2,
		"Repeated application retry cannot replay a committed combo")
	var duplicate: Dictionary = app._credit_word_jelly_combo(retry_event, 1)
	check(duplicate.ok and duplicate.duplicate and app.coin_wallet.balance == 2,
		"The GameUI adapter acknowledges the same receipt without another coin")
	var reloaded := Wallet.new(wallet_path)
	check(reloaded.load_state() and reloaded.balance == 2
		and reloaded.credit_amount(first_receipt, 1).duplicate and reloaded.credit_amount(retry_receipt, 1).duplicate,
		"An independent native reload preserves both GameUI exact credits and their permanent identities")
	var before: Dictionary = model.combo_snapshot()
	app._show_mode_menu()
	app._hide_mode_menu()
	check(model.combo_snapshot() == before and app.coin_wallet.balance == 2,
		"Opening and closing Home preserves the application combo and saved reward")
	model.cells.clear()
	for index in range(3):
		var ready: Dictionary = model._new_word_root(word, 0)
		model._set_merged_word(ready, word, 1, true)
		_put(model, ready)
	view._sync_tiles()
	var cues: Array[String] = []
	var observed_pulses: Array = []
	view.audio_requested.connect(func(cue: String) -> void:
		if cue.begins_with("jelly-combo-"):
			cues.append(cue))
	model.combo_changed.connect(func(state: Dictionary) -> void:
		if int(state.actions) > 4:
			observed_pulses.append(view._combo_hud.snapshot().pulse_serial))
	var pulse_before: int = int(view._combo_hud.snapshot().pulse_serial)
	PlayerFixture.unlock_auto_collect(app)
	check(model.start_collection_batch(), "The real GameUI starts an automatic batch of three mastery-eligible words")
	model.step(Model.BATCH_BEAT_SECONDS * 3.0 + 0.01)
	check(model.combo_snapshot().actions == 7 and app.coin_wallet.balance == 2,
		"Three committed automatic pickups advance the real application's combo without paying extra coins")
	check(cues == ["jelly-combo-3"],
		"Automatic collection sounds celebrate an actual level-up, not each added progress point")
	check(observed_pulses == [pulse_before, pulse_before, pulse_before + 1]
		and int(view._combo_hud.snapshot().count) == 3,
		"Every automatic increment reaches the HUD, but only the actual level-up pulses after learning saves")
	app.audio.halt()
	app.queue_free()
	await _settle_ui()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
