extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
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


func fixture(continuous: bool = true, speed: float = 1.0) -> Dictionary:
	var model := Model.new()
	check(model.configure(words, 3, 71), "Use actual reviewed word families")
	check(model.bind_stage(Catalog.make_plan(1, words, 3, 71)), "Use the genuine timed stage and item set")
	model.fall_speed_scale = speed
	model.cells.clear()
	model._stage_spawn_interval = 10000.0
	model.spawn_interval = 10000.0
	var selected := -1
	for index in range(4):
		var word: Dictionary = words[index / 2]
		var tile: Dictionary = model._new_word_root(word) if index % 2 == 0 else model._new_picture_tile(word)
		var at: Vector2i = model._free_position(model._occupied(), 1, 1)
		tile.merge({"column": at.x, "row": at.y, "age": 100.0, "arrival": false, "settling": false}, true)
		model.cells.append(tile)
		if selected < 0:
			selected = int(tile.id)
	model.set_fill_mode(continuous)
	if not continuous:
		check(model.drop_now(), "Manual supply also has a genuine overlapping arrival")
	model.step(0.25 / speed)
	var payments: Array = []
	model.purchase_powerup = func(receipt: String, kind: String, price: int) -> Dictionary:
		payments.append({"receipt": receipt, "kind": kind, "price": price})
		return {"ok": true}
	check(model._settling_remaining() > Model.EPSILON and model.authored_completion_plan().status == "complete",
		"The reproduction has both falling supply and an actually legal settled pair")
	return {"model": model, "payments": payments, "selected": selected}


func check_reservations(model) -> void:
	var occupied := {}
	var area := 0
	for tile: Dictionary in model.cells:
		area += int(tile.width) * int(tile.height)
		model._occupy(occupied, tile.column, tile.row, tile.width, tile.height)
	check(area == occupied.size() and area <= Model.CAPACITY, "Items and in-flight supply preserve distinct real landing reservations")


func check_item(kind: String, continuous: bool, speed: float) -> void:
	var f: Dictionary = fixture(continuous, speed)
	var model = f.model
	var generated: int = model.generated_tiles
	var remaining: float = model.stage_run.remaining
	var price: int = model.powerup_price(kind)
	check(model.can_activate_powerup(kind), "%s remains available with airborne supply, Fill=%s speed=%s" % [kind, continuous, speed])
	var accepted: bool = model.activate_powerup(kind, int(f.selected) if kind == "family_merge" else -1)
	check(accepted, "A legal " + kind + " can really be purchased during the fall")
	if not accepted:
		return
	check(f.payments.size() == 1 and f.payments[0].kind == kind and f.payments[0].price == price,
		"One item activation owns exactly one current-price purchase")
	check(model.fill_mode == continuous, "Using an item never switches the selected Fill mode off")
	if kind == "extra_time":
		check(is_equal_approx(model.stage_run.remaining, remaining + 30.0), "Extra time retains its real thirty-second grant")
	else:
		var ages: Dictionary = {}
		for tile: Dictionary in model.cells:
			if bool(tile.arrival):
				ages[int(tile.id)] = float(tile.age)
		model.step(0.02)
		check(model.generated_tiles == generated and model.cells.any(func(tile: Dictionary) -> bool:
			return ages.has(int(tile.id)) and float(tile.age) > float(ages[int(tile.id)])),
			"Paid ownership stops new supply but does not freeze arrivals already in flight")
		for frame in range(800):
			if not model.powerup_active():
				break
			model.step(0.02)
			if model.powerup_active():
				check(model.generated_tiles == generated, "Fill cannot dispatch through an active item's reservation")
				check_reservations(model)
		check(not model.powerup_active() and model.error.is_empty(), "The paid " + kind + " genuinely completes without a settling deadlock")
		if kind != "fragments":
			check(model.merged_count > 0 and model.cleared_pairs == 0 and model.collected_coins == 0,
				"Automatic tools use legal merges without silently collecting or awarding coins")
		check(f.payments.size() == 1, "Landing, completion and Fill resumption cannot charge the item twice")
	if continuous:
		for frame in range(160):
			if model.generated_tiles > generated:
				break
			model.step(0.02)
		check(model.generated_tiles > generated and model.fill_mode, "Fill resumes itself after the item releases ownership")
	else:
		check(model.generated_tiles == generated and not model.fill_mode, "Ordinary manual play does not gain an automatic Fill preference")


func check_guards() -> void:
	var f: Dictionary = fixture()
	var model = f.model
	for kind: String in ["auto_merge", "family_merge", "fragments"]:
		model.set_paused(true)
		check(not model.activate_powerup(kind, int(f.selected)), "Pause still blocks " + kind)
		model.set_paused(false)
		model.set_held_tile(int(f.selected))
		check(not model.activate_powerup(kind, int(f.selected)), "A held body still owns " + kind + " input")
		model.set_held_tile()
	var ground: Dictionary = model.cells[0]
	ground.age = 0.0
	ground.arrival = false
	for kind: String in ["auto_merge", "family_merge", "fragments"]:
		check(not model.can_activate_powerup(kind), "Real board support settlement is not mistaken for unrelated supply")
	check(f.payments.is_empty(), "Blocked operations never reach payment")
	f = fixture()
	model = f.model
	var generated: int = model.generated_tiles
	model.purchase_powerup = func(_receipt: String, _kind: String, _price: int) -> Dictionary:
		model.step(1.0)
		check(model.generated_tiles == generated, "A reentrant save cannot dispatch another Fill wave")
		return {"ok": false}
	check(not model.activate_powerup("auto_merge") and not model.powerup_active() and model.fill_mode,
		"A rejected save leaves no paid operation and preserves the selected Fill mode")
	model.step(0.5)
	check(model.generated_tiles > generated, "A rejected payment cannot leave Fill permanently stopped")
	model.purchase_powerup = Callable()


func _run() -> void:
	var data := Data.new()
	check(data.load_all(), "Load the production vocabulary")
	words = data.words.filter(func(word: Dictionary) -> bool:
		return int(word.min_age) == 3 and not str(word.get("image", "")).is_empty()).slice(0, 3).map(
			func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	for continuous: bool in [true, false]:
		for speed: float in [1.0, 2.2]:
			for kind: String in ["auto_merge", "family_merge", "fragments", "extra_time"]:
				check_item(kind, continuous, speed)
	check_guards()
	print("Fill with items: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
