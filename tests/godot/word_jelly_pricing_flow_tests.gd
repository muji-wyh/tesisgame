extends SceneTree

const UI = preload("res://scripts/game_ui.gd")
const Jelly = preload("res://scripts/word_jelly.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
const Counter = preload("res://scripts/coin_counter.gd")
const Flight = preload("res://scripts/coin_reward_flight.gd")
var checks: int = 0
var failures: int = 0


class PricingHost extends UI:
	# Keep the production purchase handler without unrelated library bootstrap.
	func _ready() -> void:
		set_process(false)

	func _exit_tree() -> void:
		var visited: Dictionary = {}
		var unused: Array[Node] = []
		_collect_unused_nodes(self, visited, unused)
		for node: Node in unused:
			if is_instance_valid(node) and node != self and node.get_parent() == null:
				node.free()

	func _collect_unused_nodes(owner: Object, visited: Dictionary, unused: Array[Node]) -> void:
		if visited.has(owner.get_instance_id()):
			return
		visited[owner.get_instance_id()] = true
		for property: Dictionary in owner.get_property_list():
			if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var member: Variant = owner.get(str(property.name))
			if not member is Object or not is_instance_valid(member):
				continue
			if member is Node and member != self and member.get_parent() == null:
				unused.append(member)
			if member.get_script() != null:
				_collect_unused_nodes(member, visited, unused)

	func _jelly_interaction_allowed() -> bool:
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func put(model, tile: Dictionary) -> void:
	var at: Vector2i = model._free_position(model._occupied(), 1, 1)
	check(at.x >= 0, "Pricing fixtures occupy genuine distinct board cells")
	tile.merge({"column": at.x, "row": at.y, "age": 100.0,
		"arrival": false, "falling": false, "settling": false}, true)
	model.cells.append(tile)


func _run() -> void:
	root.size = Vector2i(1366, 768)
	var data := Data.new()
	var source: Variant = data._read_json("res://words.json")
	check(data.error.is_empty() and Data.validate_words(source).is_empty(),
		"Use validated production vocabulary without bootstrapping unrelated chest downloads")
	if not source is Array or failures > 0:
		quit(1)
		return
	var words: Array = source.filter(func(word: Dictionary) -> bool: return str(word.id) in ["cat", "dog"]).map(
		func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	check(words.size() == 2, "The quoted families use actual reviewed cat and dog identities")
	if words.size() != 2:
		quit(1)
		return
	var cat: Dictionary = words.filter(func(word: Dictionary) -> bool: return str(word.id) == "cat")[0]
	var dog: Dictionary = words.filter(func(word: Dictionary) -> bool: return str(word.id) == "dog")[0]
	var directory: String = "user://jelly-pricing-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app := PricingHost.new()
	app._mode_id = "word_jelly"
	app._round_id = "fixture:pricing"
	app.coin_wallet = Wallet.new(directory + "/coins.cfg")
	check(app.coin_wallet.load_state() and app.coin_wallet.credit_amount("fixture:funding", 1000).ok,
		"The pricing route uses an isolated durable wallet")
	app._coin_counter = Counter.new()
	app._coin_flight = Flight.new()
	app._coin_flight.counter = app._coin_counter
	app.add_child(app._coin_counter)
	app.add_child(app._coin_flight)
	app._word_jelly = Jelly.new()
	app.add_child(app._word_jelly)
	root.add_child(app)
	var view = app._word_jelly
	view.size = Vector2(1366, 768)
	view.coin_balance = func() -> int: return app.coin_wallet.balance
	# This fixture exercises prices and debit feedback; it never awards a chest.
	check(view.configure(words, 3, Data.theme("spring"), {}, true, 7281),
		"Configure the real Jelly controls, illustrations and layout for the pricing route")
	view.set_process(false)
	var model = view.game
	check(model.bind_stage(Catalog.make_plan(1, words, 3, 7281)), "Bind actual pending goal identities")
	model.merged_level_limit = 9
	model.cells.clear()
	model.spawn_interval = 10000.0
	model._stage_spawn_interval = 10000.0
	put(model, model._new_word_root(cat))
	put(model, model._new_picture_tile(cat))
	for level: int in [2, 3]:
		var tile: Dictionary = model._new_word_root(cat)
		model._set_merged_word(tile, cat, level, true)
		put(model, tile)
	put(model, model._new_word_root(dog))
	put(model, model._new_picture_tile(dog))
	view.set_stage_progress(model.stage_run.snapshot())
	view._sync_tiles()
	view._layout()
	view._refresh_controls()
	app._coin_flight.sync(app.coin_wallet.balance)
	var cat_button: Button = view._practice_panel.button_for_goal(str(cat.id))
	var dog_button: Button = view._practice_panel.button_for_goal(str(dog.id))
	check(cat_button != null and dog_button != null, "Each reviewed family has its real left-side goal control")
	if cat_button == null or dog_button == null:
		app.free()
		quit(1)
		return
	check(cat_button.snapshot().price == 150 and dog_button.snapshot().price == 50
		and not cat_button.disabled and not dog_button.disabled,
		"The larger legal family advertises 150 coins while a single root-picture reduction advertises 50")
	view.coin_balance = func() -> int: return 100
	view._refresh_controls()
	check(not cat_button.snapshot().affordable and dog_button.snapshot().affordable
		and not cat_button.disabled and not dog_button.disabled,
		"One wallet balance computes affordability separately while preserving insufficient-funds feedback")
	view.coin_balance = func() -> int: return app.coin_wallet.balance
	for item: Dictionary in [{"level": 1, "price": 200}, {"level": 2, "price": 250}, {"level": 9, "price": 600}]:
		model.auto_merge_level = int(item.level)
		view._refresh_controls()
		check(view.powerup_buttons.auto_merge.snapshot().price == int(item.price)
			and model.powerup_price("auto_merge") == int(item.price),
			"The visible Auto merge quote follows its actual owned level")
	model.auto_merge_level = 1
	view._refresh_controls()
	var payments: Array[Dictionary] = []
	view.purchase_powerup = func(event_id: String, kind: String, price: int) -> Dictionary:
		var before: int = app.coin_wallet.balance
		check(model._powerup_purchasing and price == 150 and kind == "family_merge",
			"The chosen card captures its quantity price before the durable host callback locks the board")
		var wrong_price: Dictionary = app._purchase_word_jelly_powerup(event_id, kind, 50)
		var wrong_receipt: Dictionary = app._purchase_word_jelly_powerup(event_id + ":stale", kind, price)
		check(not bool(wrong_price.get("ok", false)) and not bool(wrong_receipt.get("ok", false))
			and app.coin_wallet.balance == before,
			"The locked host refuses a smaller family's unit price and a different receipt without spending")
		var paid: Dictionary = app._purchase_word_jelly_powerup(event_id, kind, price)
		payments.append(paid)
		return paid
	var receipts: int = app.coin_wallet._receipts.size()
	cat_button.pressed.emit()
	check(payments.size() == 1 and bool(payments[0].get("ok", false)) and model.powerup_active()
		and app.coin_wallet.balance == 850 and app.coin_wallet._receipts.size() == receipts + 1,
		"The actual goal activation debits its displayed 150 coins through the production host exactly once")
	check(cat_button.snapshot().spent_coins == 150 and cat_button.snapshot().price == 225
		and app._coin_flight.snapshot().debit_amount == 150 and app._coin_counter.target == 850,
		"Paid feedback retains the exact debit while the cached busy quantity uses the next successful-use tier")
	var receipt: String = str(model.powerup_snapshot().receipt_id)
	var mismatch: Dictionary = app._purchase_word_jelly_powerup(receipt, "family_merge", 225)
	var duplicate: Dictionary = app._purchase_word_jelly_powerup(receipt, "family_merge", 150)
	check(not bool(mismatch.get("ok", false)) and bool(duplicate.get("ok", false))
		and bool(duplicate.get("duplicate", false)) and app.coin_wallet.balance == 850
		and app.coin_wallet._receipts.size() == receipts + 1,
		"An immutable quantity-priced receipt rejects the new quote and accepts only its original exact duplicate")
	model.finish_powerup()
	view._refresh_controls()
	check(model.cells.size() == 3 and cat_button.disabled and cat_button.snapshot().price == 75
		and not dog_button.disabled and dog_button.snapshot().price == 75,
		"After settlement each goal recomputes its legal remaining reduction without retaining an expensive stale quote")
	view.purchase_powerup = Callable()
	app.free()
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Jelly level and quantity pricing flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
