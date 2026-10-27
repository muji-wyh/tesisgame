extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _word(text: String = "cat") -> Dictionary:
	return {"id": text, "text": text, "min_age": 3,
		"image": "assets/images/words/" + text + ".webp", "audio": "assets/audio/words/" + text + ".wav"}


func _model():
	var model = Model.new()
	check(model.configure([_word(), _word("dog")], 3, 71), "Configure a real word-pair model")
	model.cells.clear()
	model.spawn_interval = 10000.0
	model.set_pip_level(3)
	return model


func _put(model, tile: Dictionary, column: int) -> Dictionary:
	tile.column = column
	tile.row = 7
	tile.age = 100.0
	tile.settling = false
	tile.arrival = false
	tile.falling = false
	model.cells.append(tile)
	return tile


func _ready(model, level: int, column: int, text: String = "cat", fragments: int = 0) -> Dictionary:
	var word: Dictionary = _word(text)
	var tile: Dictionary = model._new_word_root(word, fragments)
	model._set_merged_word(tile, word, level, true)
	tile.mass = level * 2
	tile.parts_count = tile.mass
	return _put(model, tile, column)


func _test_capped_upgrades() -> void:
	for levels: Array in [[6, 5], [9, 1], [9, 9]]:
		var model = _model()
		var left: Dictionary = _ready(model, int(levels[0]), 0, "cat", 3)
		var right: Dictionary = _ready(model, int(levels[1]), 1, "cat", 4)
		var mass: int = int(left.mass) + int(right.mass)
		check(model.parts_compatible(left, right), "Over-cap words remain valid matching partners: " + str(levels))
		var status: String = model.try_merge(int(left.id), int(right.id))
		check(status == "merged", "Accept same-word levels even when their sum exceeds the cap: " + str(levels))
		if status != "merged":
			continue
		model.step(1.0)
		check(model.cells.size() == 1 and model.cells[0].merge_level == Model.MAX_MERGE_LEVEL
			and model.cells[0].fragments == 7 and model.cells[0].mass == mass,
			"Cap only the result level; preserve every input fragment and mass")


func _test_auto_merge_and_collection_credit() -> void:
	check(is_equal_approx(Model.POWERUP_MERGE_BEAT_SECONDS, 0.10)
		and is_equal_approx(Model.POWERUP_DRAG_SECONDS, 0.32),
		"Auto merge launches at 100 ms intervals while several 320 ms transfers remain visibly parallel")
	var model = _model()
	var learning: Array = []
	var payments: Array = []
	model.word_attempted.connect(func(event: String, ids: Array[String], correct: bool) -> void:
		learning.append({"event": event, "ids": ids, "correct": correct}))
	model.credit_combo = func(event: String, amount: int) -> Dictionary:
		payments.append([event, amount])
		return {"ok": true}
	model.purchase_powerup = func(_event: String, _kind: String, _price: int) -> Dictionary: return {"ok": true}
	_put(model, model._new_word_root(_word(), 0), 0)
	_put(model, model._new_picture_tile(_word(), 0), 1)
	_put(model, model._new_word_root(_word("dog"), 0), 3)
	_put(model, model._new_picture_tile(_word("dog"), 0), 4)
	check(model.activate_powerup("auto_merge"), "Start two actual automatic word matches")
	model.finish_powerup(false)
	model.step(1.0)
	check(model.cells.size() == 2 and model.cells.all(func(tile: Dictionary) -> bool: return tile.jelly_kind == "merged"),
		"The paid automatic flight finishes both complete words")
	check(model.combo_count == 2 and model.combo_best == 2 and model.combo_coins == 0 and payments.is_empty(),
		"Each committed Auto merge extends the combo once without inventing an automatic coin payout")
	check(learning.is_empty(), "Automatic construction alone never records a collection answer")
	check(model.start_collection_batch(), "Auto Collect accepts both automatically constructed words")
	model.step(1.0)
	check(model.cleared_pairs == 2 and learning.size() == 2,
		"Every successful Auto Collect pickup records its word even when an automatic match built it")
	if learning.size() == 2:
		check(learning[0].event != learning[1].event and learning[0].correct and learning[1].correct
			and [learning[0].ids[0], learning[1].ids[0]].has("cat")
			and [learning[0].ids[0], learning[1].ids[0]].has("dog"),
			"The two collected words have distinct exactly-once answer receipts")
	model.step(2.0)
	check(learning.size() == 2 and model.combo_count == 4 and payments.is_empty(),
		"Further frames never duplicate either learning or automatic combo increments")
	model.credit_combo = Callable()
	model.purchase_powerup = Callable()


func _test_blast_combo() -> void:
	var model = _model()
	var source: Dictionary = _ready(model, 2, 2)
	_put(model, model._new_word_root(_word(), 0), 1)
	_put(model, model._new_picture_tile(_word(), 0), 4)
	check(model.collect(int(source.id)), "Collect a real Lv2 blast source")
	model.step(3.0)
	check(model.cells.size() == 1 and model.cells[0].jelly_kind == "merged",
		"The source blast really marks a neighbor and merges it with its partner")
	check(model.combo_count == 2 and model.combo_best == 2 and model.combo_coins == 0,
		"The source collection and its completed blast match each extend the chain once")
	var count: int = model.combo_count
	model.step(0.1)
	check(model.combo_count == count, "An already-completed blast cannot count on subsequent frames")


func _test_batch_tempo() -> void:
	var model = _model()
	for index in range(3):
		_ready(model, 1, index, "cat" if index % 2 == 0 else "dog")
	check(is_equal_approx(Model.BATCH_BEAT_SECONDS, 0.12), "Auto Collect uses the requested slightly faster 120 ms beat")
	check(model.start_collection_batch(), "Begin a real three-word batch")
	model.step(0.119)
	check(model.cleared_pairs == 0, "The first pickup cannot finish before 120 ms")
	model.step(0.002)
	check(model.cleared_pairs == 1, "The first pickup completes as the clock crosses 120 ms")
	model.step(0.24)
	check(model.cleared_pairs == 3 and not model.collection_batch_active(),
		"Three pickups finish on the 360 ms beat with no missed or duplicate word")


func _run() -> void:
	_test_capped_upgrades()
	_test_auto_merge_and_collection_credit()
	_test_blast_combo()
	_test_batch_tempo()
	print("Jelly updated rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
