extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
var checks: int = 0
var failures: int = 0
var words: Array = []
var cat: Dictionary
var dog: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func fixture() -> Dictionary:
	var model := Model.new()
	check(model.configure([cat, dog], 3, 71), "Use actual reviewed word and picture identities")
	model.cells.clear()
	model.spawn_interval = 10000.0
	var payments: Array = []
	var evidence: Array = []
	model.purchase_powerup = func(id: String, kind: String, price: int) -> Dictionary:
		payments.append({"id": id, "kind": kind, "price": price})
		return {"ok": true}
	model.word_attempted.connect(func(id: String, ids: Array[String], correct: bool) -> void:
		evidence.append([id, ids, correct]))
	return {"model": model, "payments": payments, "evidence": evidence}


func put(model, tile: Dictionary) -> Dictionary:
	var position: Vector2i = model._free_position(model._occupied(), 1, 1)
	check(position.x >= 0, "The fixture reserves a real board cell")
	tile.column = position.x
	tile.row = position.y
	tile.age = 100.0
	tile.arrival = false
	tile.falling = false
	tile.settling = false
	model.cells.append(tile)
	return tile


func merged(model, word: Dictionary, level: int, fragments: int = 0) -> Dictionary:
	var tile: Dictionary = model._new_word_root(word, fragments)
	model._set_merged_word(tile, word, level, true)
	return put(model, tile)


func drain(model) -> void:
	for frame in range(1000):
		model.step(0.02)
		if not model.powerup_active() and model.fusions.is_empty():
			break
	check(not model.powerup_active() and model.error.is_empty(), "A paid family operation completes its bounded ordinary timeline")


func test_selected_family() -> void:
	for selected_kind: String in ["root", "picture", "merged"]:
		var f: Dictionary = fixture()
		var model = f.model
		var root: Dictionary = put(model, model._new_word_root(cat, 1))
		var picture: Dictionary = put(model, model._new_picture_tile(cat, 2))
		var second: Dictionary = merged(model, cat, 2, 3)
		merged(model, cat, 3, 4)
		var other_root: Dictionary = put(model, model._new_word_root(dog, 2))
		var other_picture: Dictionary = put(model, model._new_picture_tile(dog, 1))
		var selected: int = int({"root": root.id, "picture": picture.id, "merged": second.id}[selected_kind])
		var before: Dictionary = model.snapshot()
		check(model.can_activate_powerup("family_merge") and model.family_word_id(selected) == str(cat.id)
			and f.payments.is_empty() and model.snapshot() == before,
			"Availability and target identity are read-only and never choose or charge at random")
		check(model.activate_powerup("family_merge", selected), "Each supported source kind can choose its own word family")
		check(f.payments.size() == 1 and f.payments[0].kind == "family_merge" and f.payments[0].price == 200
			and model.powerup_snapshot().family_word_id == str(cat.id),
			"One explicit target owns exactly one quoted purchase and its visible family")
		drain(model)
		var results: Array = model.cells.filter(func(tile: Dictionary) -> bool:
			return tile.get("word", {}).get("id") == cat.id and tile.jelly_kind == "merged")
		check(results.size() == 1 and results[0].merge_level == 6 and results[0].fragments == 10,
			"Words, pictures and different merged levels combine legally while retaining every carried fragment")
		check(not model.cell(int(other_root.id)).is_empty() and not model.cell(int(other_picture.id)).is_empty()
			and model.family_word_id(int(other_root.id)) == str(dog.id) and model.cells.size() == 3,
			"The tool never consumes an unrelated word family")
		check(model.cleared_pairs == 0 and model.combo_coins == 0 and f.evidence.is_empty(),
			"Automatic merging does not secretly collect, pay manual-combo coins or grant learning evidence")


func test_guards_and_cap() -> void:
	var f: Dictionary = fixture()
	var model = f.model
	var lonely: Dictionary = put(model, model._new_word_root(cat))
	put(model, model._new_word_root(dog))
	put(model, model._new_picture_tile(dog))
	check(not model.activate_powerup("family_merge", int(lonely.id)) and f.payments.is_empty(),
		"A selected word without a complete legal merge path cannot waste coins")
	check(not model.activate_powerup("family_merge", -1) and f.payments.is_empty(),
		"Missing, preview or stale targets never trigger a random replacement purchase")
	var picture: Dictionary = put(model, model._new_picture_tile(cat))
	model.boss.configure(BossCatalog.encounter(7), 71)
	model.boss.apply_status("freeze", int(picture.id))
	check(not model.activate_powerup("family_merge", int(picture.id)) and f.payments.is_empty(),
		"Frozen targets cannot bypass the actual Boss interaction rules")
	model.boss.forget(int(picture.id))
	model.merged_level_limit = 4
	merged(model, cat, 3, 2)
	merged(model, cat, 2, 3)
	check(model.activate_powerup("family_merge", int(lonely.id)), "A cap never makes same-word upgrades unavailable")
	drain(model)
	var result: Array = model.cells.filter(func(tile: Dictionary) -> bool:
		return tile.get("word", {}).get("id") == cat.id and tile.jelly_kind == "merged")
	check(result.size() == 1 and result[0].merge_level == 4 and result[0].fragments == 5,
		"The final result obeys the unlocked cap without discarding fragment ownership")
	check(not model.cell(int(model.cells.filter(func(tile: Dictionary) -> bool:
		return tile.get("word_candidate", {}).get("id") == dog.id)[0].id)).is_empty(),
		"Even after a capped union, the other family's input remains ordinary board content")


func test_authored_family(compound: Dictionary) -> void:
	var f: Dictionary = fixture()
	var model = f.model
	check(model.configure([compound], Data.word_age(compound), 71), "Use a real reviewed multi-root word family")
	model.cells.clear()
	model.spawn_interval = 10000.0
	var ids: Array[int] = []
	for state: Dictionary in model._morphology.source_tiles(str(compound.morphology.id)):
		state.fragments = 1
		ids.append(int(put(model, model._new_composition_tile(state)).id))
	var picture: Dictionary = put(model, model._new_picture_tile(compound, 2))
	merged(model, compound, 2, 3)
	var carried: int = ids.size() + 5
	check(ids.size() >= 2 and model.family_word_id(ids[0]) == str(compound.id)
		and model.family_word_id(int(picture.id)) == str(compound.id),
		"A selected incomplete root identifies its authored word, not its printed substring or gel color")
	check(model.activate_powerup("family_merge", ids[0]), "A complete authored root path can own the selected-family purchase")
	drain(model)
	check(model.cells.size() == 1 and model.cells[0].word.id == compound.id
		and model.cells[0].merge_level == 3 and model.cells[0].fragments == carried
		and f.evidence.is_empty() and f.payments.size() == 1,
		"Partial roots finish their actual word and picture before legally joining the family's higher-level body")


func test_fill() -> void:
	var model := Model.new()
	check(model.configure(words, 3, 71) and not model.fill_mode, "Main/unbound play begins with optional Fill off")
	model.spawn_interval = 10000.0
	check(model.set_fill_mode(true), "The ordinary Fill switch can be turned on")
	model.step(0.01)
	check(model.cells.size() > 15 and model.cells.size() < Model.CAPACITY
		and model.cells.any(func(tile: Dictionary) -> bool: return tile.arrival),
		"Fill starts a real top-down supply flight instead of popping a full board into existence")
	var first_arrivals: Array[int] = []
	for tile: Dictionary in model.cells:
		if bool(tile.arrival):
			first_arrivals.append(int(tile.id))
	var first_generated: int = model.generated_tiles
	model.step(0.5)
	check(model.generated_tiles > first_generated and model.cells.any(func(tile: Dictionary) -> bool:
		return int(tile.id) in first_arrivals and not model.is_settled(tile)),
		"Fill releases the next advertised Jellies while the previous ones are still falling")
	for frame in range(300):
		model.step(0.025)
		if model.cells.size() == Model.CAPACITY:
			break
	check(model.cells.size() == Model.CAPACITY, "The continuous physical supply fills every available ordinary cell")
	check(model.set_fill_mode(false), "Main play can switch automatic filling off")
	var top: Dictionary = model.cells.filter(func(tile: Dictionary) -> bool: return tile.row == 0)[0]
	model.cells.remove_at(model._index_for_id(int(top.id)))
	model.step(0.1)
	check(model.cells.size() == Model.CAPACITY - 1, "An off switch really stops replenishing a new vacancy")
	var challenge := Model.new()
	var plan: Dictionary = Catalog.make_plan(0, words, 3, 71, true)
	check(challenge.configure(plan.words, 3, 71) and challenge.bind_stage(plan)
		and challenge.fill_mode and challenge.fill_mode_locked(),
		"Challenge binds with Fill already on and visibly required")
	check(not challenge.set_fill_mode(false) and challenge.fill_mode,
		"Programmatic, keyboard and pointer callers cannot turn Challenge Fill off")
	challenge.set_paused(true)
	var generated: int = challenge.generated_tiles
	challenge.step(10.0)
	check(challenge.generated_tiles == generated, "Pause freezes Fill along with the actual board")
	challenge.set_paused(false)
	challenge.stage_run.advance(float(challenge.stage_run.remaining))
	challenge.step(0.01)
	check(challenge.generated_tiles == generated and challenge.stage_ending(),
		"An already expired Challenge cannot dispatch a final unpaid extra packet before locking its ending")


func test_family_payment_lifecycle() -> void:
	for response: Dictionary in [{"ok": false}, {"ok": true, "duplicate": true}]:
		var f: Dictionary = fixture()
		var model = f.model
		var root: Dictionary = put(model, model._new_word_root(cat))
		put(model, model._new_picture_tile(cat))
		var before: Dictionary = model.snapshot()
		model.purchase_powerup = func(_id: String, _kind: String, _price: int) -> Dictionary:
			return response.duplicate()
		check(not model.activate_powerup("family_merge", int(root.id)) and model.cells == before.cells
			and model.powerup_price("family_merge") == 200 and not model.powerup_active()
			and model.snapshot().powerup_uses.family_merge == 0,
			"Failed and duplicate chosen-family payments preserve inputs, use count and quoted price")
	for interruption: String in ["pause", "finish", "configure"]:
		var f: Dictionary = fixture()
		var model = f.model
		var root: Dictionary = put(model, model._new_word_root(cat, 2))
		put(model, model._new_picture_tile(cat, 3))
		model.purchase_powerup = func(id: String, kind: String, price: int) -> Dictionary:
			f.payments.append([id, kind, price])
			if interruption == "pause":
				model.set_paused(true)
			elif interruption == "finish":
				model.finish_round("callback-exit")
			else:
				check(not model.configure([cat], 3, 92), "An in-flight family payment cannot replace its selected round")
			return {"ok": true}
		check(model.activate_powerup("family_merge", int(root.id)), "A committed selected-family purchase retains its paid obligation")
		model.finish_powerup()
		check(f.payments.size() == 1 and model.cells.size() == 1 and model.cells[0].word.id == cat.id
			and model.cells[0].fragments == 5 and not model.powerup_active()
			and model.powerup_price("family_merge") == 300,
			"A reentrant pause, exit or rejected reconfigure settles the chosen family exactly once")
		model.purchase_powerup = Callable()
	var f: Dictionary = fixture()
	var model = f.model
	var prices: Array[int] = [200, 300, 400, 400]
	for index in range(prices.size()):
		model.cells.clear()
		var root: Dictionary = put(model, model._new_word_root(cat))
		put(model, model._new_picture_tile(cat))
		check(model.powerup_price("family_merge") == prices[index]
			and model.activate_powerup("family_merge", int(root.id)),
			"Each selected-family repeat pays its own exact capped use tier")
		drain(model)
		check(f.payments.back().price == prices[index] and model.powerup_price("auto_merge") == 600
			and model.powerup_price("fragments") == 200,
			"A family purchase never advances the unrelated tools' prices")


func test_combo_levels() -> void:
	var f: Dictionary = fixture()
	var model = f.model
	var ready_id: int = -1
	for action in range(1, 19):
		if action % 2 == 1:
			var left: Dictionary = put(model, model._new_word_root(cat))
			var right: Dictionary = put(model, model._new_picture_tile(cat))
			check(model.try_merge(int(left.id), int(right.id)) == "merged", "A real manual merge starts")
			ready_id = int(model.fusions.back().result.id)
		else:
			check(model.collect(ready_id), "A real collection continues the same chain")
		model.step(2.0)
		var expected: int = 1 if action < 3 else 2 if action < 7 else 3 if action < 12 else 4 if action < 18 else 5
		var combo: Dictionary = model.combo_snapshot()
		check(combo.count == expected and combo.actions == action and combo.required == expected + 2
			and combo.progress >= 0 and combo.progress < combo.required,
			"Three, four, five and later cumulative points upgrade once, rather than one level per action")
	var best: int = model.combo_best
	var coins: int = model.combo_coins
	model.step(float(model.combo_snapshot().remaining))
	check(model.combo_count == 0 and model.combo_progress == 0 and model.combo_actions == 0
		and model.combo_best == best and model.combo_coins == coins,
		"The eight-second boundary resets active progress but never erases earned coins or its best level")


func test_main_pressure() -> void:
	var early := Model.new()
	var late := Model.new()
	for item: Dictionary in [{"model": early, "number": 1}, {"model": late, "number": 99}]:
		var plan: Dictionary = Catalog.make_plan(int(item.number), words, 3, 71)
		check(item.model.configure(plan.words, 3, 71) and item.model.bind_stage(plan) and item.model.drop_now(),
			"Actual main-stage binding dispatches its real next advertised packet")
	var early_body: Dictionary = early.cells.filter(func(tile: Dictionary) -> bool: return tile.arrival)[0]
	var late_body: Dictionary = late.cells.filter(func(tile: Dictionary) -> bool: return tile.arrival)[0]
	check(early.spawn_interval > late.spawn_interval and float(late_body.motion_speed_scale) == 1.4
		and Model.arrival_contact_at(late_body) < Model.arrival_contact_at(early_body),
		"Later main stages actually dispatch more often and land faster, not merely report harder catalog metadata")


func _run() -> void:
	var data := Data.new()
	check(data.load_all(), "Load acquired vocabulary and its actual reviewed morphology")
	words = data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == 3).map(
		func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	cat = words.filter(func(word: Dictionary) -> bool: return str(word.id) == "cat")[0]
	dog = words.filter(func(word: Dictionary) -> bool: return str(word.id) == "dog")[0]
	test_selected_family()
	test_guards_and_cap()
	var compounds: Array = data.words.filter(func(word: Dictionary) -> bool: return str(word.text) == "rainbow").map(
		func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	check(not compounds.is_empty(), "The real reviewed vocabulary supplies a compound family fixture")
	if not compounds.is_empty():
		test_authored_family(compounds[0])
	test_fill()
	test_family_payment_lifecycle()
	test_combo_levels()
	test_main_pressure()
	print("Selected-family merge, Fill and combo levels: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
