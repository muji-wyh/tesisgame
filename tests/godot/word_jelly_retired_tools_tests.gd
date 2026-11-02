extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
const View = preload("res://scripts/word_jelly.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
var checks := 0
var failures := 0
var words: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func make_model(kind: String):
	var model := Model.new()
	check(model.configure(words, 3, 71), "Use actual reviewed Jelly supply")
	if kind != "legacy":
		check(model.bind_stage(Catalog.make_plan(0 if kind == "challenge" else 2, words, 3, 71, kind == "challenge")),
			"Use a real numbered or Challenge clock")
	model.set_fill_mode(false)
	return model


func _test_removed_requests() -> void:
	check(Model.POWERUP_PRICES == {"auto_merge": 600, "family_merge": 50},
		"The live purchase catalog contains only Auto merge and goal-family purchases")
	for mode: String in ["main", "challenge", "legacy"]:
		var model = make_model(mode)
		var payments: Array = []
		model.purchase_powerup = func(id: String, kind: String, price: int) -> Dictionary:
			payments.append([id, kind, price])
			return {"ok": true}
		var before: Dictionary = model.snapshot()
		var rng: int = model._rng.state
		for kind: String in ["fragments", "treasure", "extra_time"]:
			check(not model.can_activate_powerup(kind) and not model.activate_powerup(kind)
				and not model._purchase_powerup(kind) and model.powerup_price(kind) == 0,
				"%s has no live purchase or quoted price in %s" % [kind, mode])
			check(payments.is_empty() and model.snapshot() == before and model._rng.state == rng,
				"A retired item cannot spend, add fragments, extend time, alter stars or change supply")
		check(not before.powerup_prices.has("fragments") and not before.powerup_prices.has("extra_time"),
			"Public snapshots do not advertise the retired tools")
		model.purchase_powerup = Callable()


func _test_natural_rewards_and_clock() -> void:
	var model = make_model("main")
	model.cells.clear()
	var tile: Dictionary = model._new_word_root(words[0], 4)
	model._set_merged_word(tile, words[0], 1, true)
	tile.merge({"column": 3, "row": 7, "age": 100.0, "arrival": false, "settling": false}, true)
	model.cells.append(tile)
	check(model.collect(int(tile.id)), "A natural fragment-bearing word remains collectable")
	model.step(Model.COLLECT_SECONDS + 0.02)
	check(model.fragment_count == 4 and model.chest_tier == 1 and model.chest_count == 1,
		"Retiring the paid Treasure card never removes earned chest fragments or natural chest unlocks")
	var challenge = make_model("challenge")
	challenge.stage_run.advance(20.0)
	check(is_equal_approx(challenge.stage_run.grant_challenge_time("retire-tools:earned-goal", 10), 10.0)
		and is_equal_approx(challenge.stage_run.remaining, 80.0),
		"Challenge goal-earned time remains intact and is not the retired paid extension")


func _test_application(app) -> void:
	Fixture.enter_mode(app, "word_jelly")
	app.set_process(false)
	app._word_jelly.set_process(false)
	check(app.coin_wallet.credit_amount("fixture:retired-tools", 1000).ok, "Fund only isolated test coins")
	app._coin_flight.sync(app.coin_wallet.balance)
	var view = app._word_jelly
	check(view.powerup_buttons.keys() == ["auto_merge"],
		"Only Auto merge is constructed in the paid action rail")
	var balance: int = app.coin_wallet.balance
	var receipts: Dictionary = app.coin_wallet._receipts.duplicate()
	for kind: String in ["fragments", "extra_time", "treasure"]:
		var result: Dictionary = app._purchase_word_jelly_powerup("retired:" + kind, kind, 200)
		check(not result.ok and app.coin_wallet.balance == balance and app.coin_wallet._receipts == receipts,
			"The application purchase adapter rejects hidden retired requests before touching the real wallet")
		view._activate_powerup(kind)
		check(app.coin_wallet.balance == balance and not view.game.powerup_active(),
			"The view cannot activate a removed tool through a stale input command")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	var data := Data.new()
	check(data.load_all(), "Load the existing production word and chest assets")
	words = data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == 3).slice(0, 8).map(
		func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	_test_removed_requests()
	_test_natural_rewards_and_clock()
	var directory := "user://retired-jelly-tools-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	for frame in range(6):
		await process_frame
	app.audio.set_muted(true)
	_test_application(app)
	app.audio.halt()
	app.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Retired Jelly tools: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
