extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const Growth = preload("res://scripts/growth_state.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(4):
		await process_frame


func _run() -> void:
	root.size = Vector2i(1366, 768)
	var directory: String = "user://jelly-collected-learning-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Collection evidence uses isolated real saves")
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_process(false)
	Fixture.enter_mode(app, "word_jelly")
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	var words: Array = app.data.words.filter(func(word: Dictionary) -> bool: return str(word.id) in ["cat", "dog"])
	check(words.size() == 2 and view.configure(words, 3, Data.theme(app.model.theme_id), app.data.chests, false, 71),
		"Use two actual pictured vocabulary words with the real GameUI credit callbacks")
	app._word_jelly_stages.configure(words, app._jelly_word_mastered, 71)
	view.set_stage_progress(app._jelly_stage_snapshot())
	app._sync_jelly()
	Fixture.unlock_auto_collect(app)
	check(app.coin_wallet.credit_amount("learning-fixture", 6000).ok, "Fund the actual saved Auto merge purchases")
	app._coin_flight.sync(app.coin_wallet.balance)
	var receipts: Dictionary = {}
	view.collected.connect(func(event: String, word: Dictionary, _coins: int, _fragments: int, _origin: Vector2) -> void:
		receipts[str(word.id)] = event)
	for answer in range(1, 4):
		view.game.cells.clear()
		view.game.spawn_interval = 10000.0
		for index in range(4):
			var word: Dictionary = words[index / 2]
			var tile: Dictionary = view.game._new_word_root(word) if index % 2 == 0 else view.game._new_picture_tile(word)
			tile.column = [0, 1, 3, 4][index]
			tile.row = 7
			tile.age = 100.0
			tile.settling = false
			tile.falling = false
			tile.arrival = false
			view.game.cells.append(tile)
		check(view.game.activate_powerup("auto_merge"), "Purchase actual automatic matches before collection %d" % answer)
		view.game.finish_powerup(false)
		view.game.step(1.0)
		check(words.all(func(word: Dictionary) -> bool: return app.growth.streak(str(word.id)) == answer - 1),
			"Automatic construction by itself does not claim a collection answer")
		check(view.game.start_collection_batch(), "Start the real unlocked Auto Collect batch")
		view.game.step(1.0)
		for word: Dictionary in words:
			check(app.growth.streak(str(word.id)) == answer and app.growth.is_mastered(str(word.id)) == (answer == 3),
				"Saved proficiency advances exactly once for collected %s, answer %d" % [word.text, answer])
			var card: Array = view._practice_panel.snapshot().words.filter(func(item: Dictionary) -> bool: return item.id == word.id)
			check(card.size() == 1 and int(card[0].current) == answer,
				"The actual goal card reflects the same durable collection evidence")
		check(view.game.collection_batch_snapshot().completed == 2 and not view.game.collection_batch_active(),
			"Both words complete the batch without dropping an answer")
	var saved: Dictionary = app.growth.snapshot()
	view.word_attempted.emit(str(receipts.cat), ["cat"] as Array[String], true)
	check(app.growth.snapshot() == saved, "Replaying the completed collection receipt never grants another learning increment")
	var reloaded := Growth.new(directory + "/growth.cfg")
	check(reloaded.configure(app.data.words) and reloaded.load_state()
		and reloaded.streak("cat") == 3 and reloaded.streak("dog") == 3,
		"Both Auto Collect masteries survive reopening the actual learner save")
	check(app.coin_wallet.balance == 3300 and view.game.combo_coins == 0,
		"Three paid automatic batches preserve exact purchase costs without inventing automatic combo coins")
	app.audio.halt()
	app.free()
	await settle()
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Jelly collection learning: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
