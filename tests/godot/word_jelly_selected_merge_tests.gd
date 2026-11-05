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


class QuoteModel extends Model:
	var forecast_calls: int = 0
	var preview_calls: int = 0

	func auto_merge_preview() -> Dictionary:
		preview_calls += 1
		return super.auto_merge_preview()

	func _powerup_forecast() -> WordJellyModel:
		forecast_calls += 1
		return super._powerup_forecast()


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func fixture(pricing_probe: bool = false) -> Dictionary:
	var model = QuoteModel.new() if pricing_probe else Model.new()
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
		check(model.activate_family_merge(str(cat.id)) if selected_kind == "root" else model.activate_powerup("family_merge", selected),
			"The goal identity and legacy direct targets both choose only their own word family")
		check(f.payments.size() == 1 and f.payments[0].kind == "family_merge" and f.payments[0].price == 25
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
	check(not model.activate_family_merge(str(cat.id)) and not model.activate_family_merge("")
		and not model.activate_family_merge("not-a-goal") and f.payments.is_empty(),
		"A missing goal path or identity never substitutes the other family's complete pair")
	check(model.snapshot().powerup_uses.family_merge == 0 and model.powerup_price("family_merge") == 25,
		"Rejected and empty family operations never advance the successful-use price tier")
	var picture: Dictionary = put(model, model._new_picture_tile(cat))
	model.boss.configure(BossCatalog.encounter(7), 71)
	model.boss.apply_status("freeze", int(picture.id))
	check(not model.activate_powerup("family_merge", int(picture.id)) and f.payments.is_empty(),
		"Frozen targets cannot bypass the actual Boss interaction rules")
	model.boss.forget(int(picture.id))
	model.merged_level_limit = 4
	merged(model, cat, 3, 2)
	merged(model, cat, 2, 3)
	check(model.activate_powerup("family_merge", int(lonely.id)), "Below-cap Jellies still provide a legal same-word upgrade")
	drain(model)
	var result: Array = model.cells.filter(func(tile: Dictionary) -> bool:
		return tile.get("word", {}).get("id") == cat.id and tile.jelly_kind == "merged")
	var carried: int = 0
	for tile: Dictionary in result:
		carried += int(tile.fragments)
	check(result.size() == 2 and carried == 5
		and result.any(func(tile: Dictionary) -> bool: return int(tile.merge_level) == 4),
		"A family operation stops using a capped result and preserves the remaining Jelly and every fragment")
	check(not model.cell(int(model.cells.filter(func(tile: Dictionary) -> bool:
		return tile.get("word_candidate", {}).get("id") == dog.id)[0].id)).is_empty(),
		"Even after a capped union, the other family's input remains ordinary board content")


func capped_fixture(limit: int) -> Dictionary:
	var f: Dictionary = fixture()
	var model = f.model
	var plan: Dictionary = Catalog.make_plan(1, [cat, dog], 3, 71)
	plan["merged_level_limit"] = limit
	check(model.bind_stage(plan) and model.merged_level_limit == limit,
		"The capped fixture binds the actual campaign level limit")
	var root: Dictionary = put(model, model._new_word_root(cat))
	var picture: Dictionary = put(model, model._new_picture_tile(cat))
	check(model.try_merge(int(root.id), int(picture.id)) == "merged",
		"A genuine root-picture match starts the combo before a capped interaction")
	model.step(Model.FUSION_SECONDS + 0.001)
	check(model.combo_snapshot().count > 0 and model.fusions.is_empty(),
		"The capped fixture retains a real successful combo")
	model.cells.clear()
	return f


func test_capped_merge_guards() -> void:
	for limit: int in [1, 4, Model.MAX_MERGE_LEVEL]:
		for partner_kind: String in ["same_lower", "same_max", "other_word", "root", "picture"]:
			for reverse: bool in [false, true]:
				var f: Dictionary = capped_fixture(limit)
				var model = f.model
				var capped: Dictionary = merged(model, cat, limit, 2)
				var partner: Dictionary
				match partner_kind:
					"same_lower": partner = merged(model, cat, maxi(1, limit - 1), 3)
					"same_max": partner = merged(model, cat, limit, 3)
					"other_word": partner = merged(model, dog, 1, 3)
					"root": partner = put(model, model._new_word_root(cat, 3))
					"picture": partner = put(model, model._new_picture_tile(cat, 3))
				var source: Dictionary = partner if reverse else capped
				var target: Dictionary = capped if reverse else partner
				var label: String = "Lv%d %s %s" % [limit, partner_kind, "target" if reverse else "source"]
				check(not model.parts_compatible(source, target) and not model.can_merge(source, target)
					and not model.merge_candidate(source, target).status in ["partial", "complete"],
					"A capped Jelly is excluded from semantic matching and merge previews: " + label)
				var before: Array = model.cells.duplicate(true)
				var combo: Dictionary = model.combo_snapshot()
				var evidence: Array = f.evidence.duplicate(true)
				var next_id: int = model._next_tile_id
				var cues: Array[String] = []
				var combo_changes: Array[Dictionary] = []
				model.cue_requested.connect(func(cue: String) -> void: cues.append(cue))
				model.combo_changed.connect(func(state: Dictionary) -> void: combo_changes.append(state))
				check(model.try_merge(int(source.id), int(target.id)) == "ignored"
					and model.cells == before and model.fusions.is_empty() and model._next_tile_id == next_id,
					"Dropping either side of a capped pair preserves both bodies and their fragments: " + label)
				check(cues.is_empty() and combo_changes.is_empty() and model.combo_snapshot() == combo
					and f.evidence == evidence and model.error.is_empty(),
					"A capped attempt has no wrong cue, combo penalty or learning-error evidence: " + label)
				check(model.compatible_pairs().is_empty() and model.auto_merge_preview().result_count == 0
					and not model.can_activate_powerup("auto_merge")
					and not model.activate_powerup("auto_merge") and f.payments.is_empty(),
					"Auto merge cannot select or charge for a capped pair: " + label)
				check(int(capped.id) in model.collectable_ids(),
					"Reaching the limit preserves the intended collection action: " + label)


func test_below_cap_upgrade() -> void:
	for limit: int in [4, Model.MAX_MERGE_LEVEL]:
		var f: Dictionary = capped_fixture(limit)
		var model = f.model
		var left: Dictionary = merged(model, cat, limit - 1, 2)
		var right: Dictionary = merged(model, cat, 2, 3)
		check(model.can_merge(left, right) and model.try_merge(int(left.id), int(right.id)) == "merged",
			"Two below-cap Jellies may still combine even when their sum reaches the limit")
		model.step(Model.FUSION_SECONDS + 0.001)
		check(model.cells.size() == 1 and int(model.cells[0].merge_level) == limit
			and int(model.cells[0].fragments) == 5,
			"A legitimate upgrade clamps to the campaign limit and retains every carried fragment")


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
	check(model.activate_family_merge(str(compound.id)), "A goal resolves its complete authored multi-root path without a board selector")
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
	check(model.cells.size() > Model.INITIAL_SETTLED_TILES and model.cells.size() < Model.CAPACITY
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
		check(not model.activate_family_merge(str(cat.id)) and model.cells == before.cells
			and model.powerup_price("family_merge") == 25 and not model.powerup_active()
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
		check(model.activate_family_merge(str(cat.id)), "A committed goal-family purchase retains its paid obligation")
		model.finish_powerup()
		check(f.payments.size() == 1 and model.cells.size() == 1 and model.cells[0].word.id == cat.id
			and model.cells[0].fragments == 5 and not model.powerup_active()
			and model.powerup_price("family_merge") == 50,
			"A reentrant pause, exit or rejected reconfigure settles the chosen family exactly once")
		model.purchase_powerup = Callable()
	var f: Dictionary = fixture()
	var model = f.model
	var prices: Array[int] = [25, 50, 75, 75]
	for index in range(prices.size()):
		model.cells.clear()
		var word: Dictionary = cat if index % 2 == 0 else dog
		var root: Dictionary = put(model, model._new_word_root(word))
		put(model, model._new_picture_tile(word))
		check(model.powerup_price("family_merge") == prices[index],
			"Different word families share one capped successful-use tier within the round")
		check(model.activate_powerup("family_merge", int(root.id)),
			"Each selected-family repeat pays its own exact capped use tier")
		drain(model)
		check(f.payments.back().price == prices[index] and model.powerup_price("auto_merge") == 25
			and model.auto_merge_level == 1 and model.powerup_price("fragments") == 0,
			"A family purchase changes neither Auto merge prices nor capacity and cannot restore retired tools")
	check(model.configure([cat, dog], 3, 92) and model.powerup_price("family_merge") == 25
		and model.powerup_price("auto_merge") == 25 and model.snapshot().powerup_uses.family_merge == 0,
		"A new round resets the selected-family use counter and its capped quote")
	model.purchase_powerup = Callable()


func test_family_flat_prices() -> void:
	for count: int in [2, 4]:
		var f: Dictionary = fixture(true)
		var model = f.model
		for index in range(count):
			merged(model, cat, 1)
		# These same-family bodies cannot participate in the paid operation.
		var capped: Dictionary = merged(model, cat, Model.MAX_MERGE_LEVEL)
		var frozen: Dictionary = merged(model, cat, 1)
		model.boss.configure(BossCatalog.encounter(7), 71)
		model.boss.apply_status("freeze", int(frozen.id))
		var unmatched: Dictionary = put(model, model._new_word_root(cat))
		var other_root: Dictionary = put(model, model._new_word_root(dog))
		put(model, model._new_picture_tile(dog))
		var before: Dictionary = model.snapshot()
		var next_tile: int = model._next_tile_id
		var next_receipt: int = model._next_event_id
		var rng_state: int = model._rng.state
		var expected_price: int = 25
		check(model.powerup_price("family_merge", str(cat.id)) == expected_price
			and model.powerup_price("family_merge", str(dog.id)) == 25,
			"Every family's first use has the same price regardless of its eligible body count")
		var forecast_calls: int = model.forecast_calls
		var preview_calls: int = model.preview_calls
		check(model.powerup_price("family_merge", str(cat.id)) == expected_price
			and model.snapshot() == before and model._next_tile_id == next_tile
			and model._next_event_id == next_receipt and model._rng.state == rng_state and f.payments.is_empty(),
			"Repeated fixed quotes preserve the live board, allocations, random stream and wallet")
		for tile: Dictionary in model.cells:
			tile.age = float(tile.age) + 0.1
		check(model.powerup_price("family_merge", str(cat.id)) == expected_price
			and model.forecast_calls == forecast_calls and model.preview_calls == preview_calls
			and forecast_calls == 0 and preview_calls == 0,
			"Ordinary family quotes and snapshots never start a semantic preview or simulated timeline")
		var added: Dictionary = merged(model, cat, 1)
		check(model.powerup_price("family_merge", str(cat.id)) == expected_price,
			"Adding an eligible Jelly leaves the fixed per-use family price unchanged")
		model.cells.remove_at(model._index_for_id(int(added.id)))
		check(model.powerup_price("family_merge", str(cat.id)) == expected_price,
			"Removing an eligible Jelly also leaves the fixed per-use family price unchanged")
		var accepted_purchase: Callable = model.purchase_powerup
		var unchanged: Array = model.cells.duplicate(true)
		for response: Dictionary in [{"ok": false, "reason": "insufficient", "after": 0},
			{"ok": false, "reason": "storage"}, {"ok": true, "duplicate": true}]:
			model.purchase_powerup = func(_id: String, _kind: String, price: int) -> Dictionary:
				check(price == expected_price, "Even a rejected purchase receives the exact fixed selected-family quote")
				return response.duplicate()
			check(not model.activate_family_merge(str(cat.id)) and model.cells == unchanged
				and model.powerup_price("family_merge", str(cat.id)) == expected_price
				and model.snapshot().powerup_uses.family_merge == 0 and f.payments.is_empty(),
				"Insufficient, unsaved and duplicate purchases preserve bodies and the first-use price")
		model.purchase_powerup = accepted_purchase
		check(model.activate_family_merge(str(cat.id)) and f.payments.size() == 1
			and f.payments[0].price == expected_price,
			"The selected family pays exactly its displayed fixed per-use quote")
		drain(model)
		check(before.cells.size() - model.cells.size() == count - 1
			and not model.cell(int(capped.id)).is_empty() and not model.cell(int(frozen.id)).is_empty()
			and not model.cell(int(unmatched.id)).is_empty() and not model.cell(int(other_root.id)).is_empty(),
			"The fixed-price operation still preserves capped, frozen, unmatched and unrelated bodies")
		model.purchase_powerup = Callable()


func test_family_price_independent_of_outcome() -> void:
	for counts: Vector3i in [Vector3i(0, 0, 2), Vector3i(1, 1, 0), Vector3i(2, 1, 1),
		Vector3i(1, 2, 2), Vector3i(3, 3, 6), Vector3i(0, 3, 3)]:
		var f: Dictionary = fixture(true)
		var model = f.model
		for index in range(counts.x):
			put(model, model._new_word_root(cat))
		for index in range(counts.y):
			put(model, model._new_picture_tile(cat))
		for index in range(counts.z):
			merged(model, cat, 1)
		var before_count: int = model.cells.size()
		var price: int = model.powerup_price("family_merge", str(cat.id))
		check(model.forecast_calls == 0 and model.activate_family_merge(str(cat.id)),
			"Settled one-cell families receive a useful fixed quote without a timeline forecast")
		drain(model)
		check(price == 25 and before_count > model.cells.size() and f.payments.size() == 1
			and f.payments[0].price == price,
			"Different legal reductions, caps and unmatched leftovers all retain the same first-use debit")
		model.purchase_powerup = Callable()


	var capped: Dictionary = fixture(true)
	capped.model.merged_level_limit = 1
	for index in range(3):
		put(capped.model, capped.model._new_word_root(cat))
		put(capped.model, capped.model._new_picture_tile(cat))
	merged(capped.model, cat, 1)
	check(capped.model.powerup_price("family_merge", str(cat.id)) == 25
		and capped.model.forecast_calls == 0 and capped.model.activate_family_merge(str(cat.id)),
		"At the first unlocked cap, one fixed price covers every legal pair while capped bodies are excluded")
	drain(capped.model)
	check(capped.model.cells.size() == 4 and capped.payments.size() == 1 and capped.payments[0].price == 25,
		"The capped first-level operation frees exactly three spaces and preserves every completed body")
	capped.model.purchase_powerup = Callable()


func test_family_airborne_prices(compound: Dictionary) -> void:
	var f: Dictionary = fixture(true)
	var model = f.model
	check(model.configure([compound], Data.word_age(compound), 71), "Use a real multipart family with incoming supply bodies")
	model.cells.clear()
	model.spawn_interval = 10000.0
	for copy in range(2):
		for part: Dictionary in model._morphology.source_tiles(str(compound.morphology.id)):
			put(model, model._new_composition_tile(part))
		put(model, model._new_picture_tile(compound))
		if copy == 1:
			for tile: Dictionary in model.cells.slice(model.cells.size() / 2):
				tile.arrival = true
				tile.settling = true
				tile.age = maxf(0.0, Model.settle_duration(tile) - 0.3)
	var first: int = model.powerup_price("family_merge", str(compound.id))
	check(first == 25 and model.powerup_price("family_merge", str(compound.id)) == first
		and model.snapshot().powerup_prices.family_merge == first
		and model.forecast_calls == 0 and model.preview_calls == 0,
		"Complex incoming families expose fixed prices and complete snapshots without previewing a timeline")
	for tile: Dictionary in model.cells:
		if not model.is_settled(tile):
			tile.age = float(tile.age) + 0.05
	var second: int = model.powerup_price("family_merge", str(compound.id))
	check(second == first and model.snapshot().powerup_prices.family_merge == second
		and model.forecast_calls == 0 and model.preview_calls == 0,
		"Changing airborne deadlines does not start a pricing forecast or change the per-use tier")
	var before_count: int = model.cells.size()
	check(model.activate_family_merge(str(compound.id)), "The flat airborne quote still owns a real useful family purchase")
	drain(model)
	check(second == 25 and before_count - model.cells.size() > 1 and model.cells.size() == 1
		and model.cells[0].word.id == compound.id and model.cells[0].merge_level == 2 and f.payments.size() == 1
		and f.payments[0].price == second,
		"One first-use debit completes both authored words and their actual legal family upgrade")
	model.purchase_powerup = Callable()


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
	var pricing_only: bool = OS.get_cmdline_user_args().has("--pricing-only")
	if pricing_only:
		var source: Variant = data._read_json("res://words.json")
		check(data.error.is_empty() and Data.validate_words(source).is_empty(),
			"Load and validate actual reviewed word identities for the focused pricing checks")
		if not source is Array or failures > 0:
			quit(1)
			return
		data.words = source
	else:
		check(data.load_all(), "Load acquired vocabulary and its actual reviewed morphology")
	words = data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == 3).map(
		func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	cat = words.filter(func(word: Dictionary) -> bool: return str(word.id) == "cat")[0]
	dog = words.filter(func(word: Dictionary) -> bool: return str(word.id) == "dog")[0]
	test_selected_family()
	test_guards_and_cap()
	test_capped_merge_guards()
	test_below_cap_upgrade()
	var compounds: Array = data.words.filter(func(word: Dictionary) -> bool: return str(word.text) == "rainbow").map(
		func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	check(not compounds.is_empty(), "The real reviewed vocabulary supplies a compound family fixture")
	if not compounds.is_empty():
		test_authored_family(compounds[0])
		test_family_airborne_prices(compounds[0])
	test_family_payment_lifecycle()
	test_family_flat_prices()
	test_family_price_independent_of_outcome()
	if pricing_only:
		print("Selected-family fixed pricing: %d checks, %d failures" % [checks, failures])
		quit(1 if failures else 0)
		return
	test_fill()
	test_combo_levels()
	test_main_pressure()
	print("Selected-family merge, Fill and combo levels: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
