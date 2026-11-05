extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
const Economy = preload("res://scripts/coin_economy.gd")
const ButtonView = preload("res://scripts/word_jelly_powerup_button.gd")
var checks := 0
var failures := 0
var word: Dictionary = {"id": "cat", "text": "cat", "min_age": 3,
	"image": "res://assets/images/ui/modes/cat.webp", "audio": "fixture:cat"}


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func fixture(level: int, count: int):
	var model := Model.new()
	check(model.configure([word], 3, 1901), "Use a real pictured word for legal automatic upgrades")
	model.auto_merge_level = level
	model.spawn_interval = 10000.0
	model.cells.clear()
	for index in range(count):
		var tile: Dictionary = model._new_word_root(word, index + 1)
		model._set_merged_word(tile, word, 1, true)
		model.cells.append(tile)
	settle_board(model)
	return model


func settle_board(model) -> void:
	for index in range(model.cells.size()):
		model.cells[index].merge({"column": index % Model.COLUMNS,
			"row": Model.ROWS - 1 - int(index / Model.COLUMNS), "age": 100.0,
			"settling": false, "falling": false, "arrival": false}, true)


func payments(model) -> Array:
	var paid: Array = []
	model.purchase_powerup = func(id: String, kind: String, price: int) -> Dictionary:
		paid.append([id, kind, price])
		return {"ok": true, "duplicate": false}
	return paid


func drain(model) -> void:
	for frame in range(800):
		if not model.powerup_active():
			break
		model.step(0.025)
	check(not model.powerup_active(), "Every accepted bounded path finishes without leaving a partial operation")


func pictured_fixture(count: int):
	var model := Model.new()
	check(model.configure([word], 3, 1901), "Use actual root-picture pairs rather than invented completed outputs")
	model.spawn_interval = 10000.0
	model.cells.clear()
	for index in range(count):
		model.cells.append(model._new_word_root(word, index + 1))
		model.cells.append(model._new_picture_tile(word))
	settle_board(model)
	return model


func _test_three_completed_results() -> void:
	var model = pictured_fixture(3)
	var paid: Array = payments(model)
	check(model.auto_merge_capacity() == 3 and model.activate_powerup("auto_merge"),
		"The default badge's three-result ability accepts three real complete paths")
	drain(model)
	var state: Dictionary = model.powerup_snapshot()
	check(model.cells.size() == 3 and model.collectable_ids().size() == 3,
		"Three advertised Jellies leave three distinct collectable results, not one reused output")
	check(int(state.get("completed_results", 0)) == 3 and state.get("result_ids", []).size() == 3
		and state.affected_jellies == 6,
		"Original inputs and intermediate steps do not consume the completed-result capacity")
	var fragments := 0
	for tile: Dictionary in model.cells:
		fragments += int(tile.fragments)
		check(tile.jelly_kind == "merged" and tile.merge_level == 1 and tile.word.id == "cat",
			"Each surviving product is a complete Lv1 word, not three animations folded into one upgrade")
	check(fragments == 6 and model.cleared_pairs == 0 and model.collected_coins == 0
		and paid.size() == 1 and paid[0][2] == 25,
		"The three outputs preserve fragments, learning ownership and one exact debit")
	model.purchase_powerup = Callable()


func _test_activation_hit_stop() -> void:
	var model = pictured_fixture(3)
	var paid: Array = payments(model)
	var motion: Array[float] = [0.0]
	model.motion_advanced.connect(func(delta: float) -> void: motion[0] += delta)
	model.boss.configure(preload("res://scripts/word_jelly_boss_catalog.gd").encounter(3), 71)
	var boss_elapsed: float = model.boss.elapsed
	check(model.activate_powerup("auto_merge"), "Start one accepted click with its saved price")
	var impact: Dictionary = model.hit_stop_snapshot()
	check(bool(impact.active) and impact.get("source") == "auto_merge"
		and is_zero_approx(model.gameplay_time_scale()) and model.powerup_snapshot().drags.is_empty(),
		"The accepted click begins a real world hit-stop before the first automatic flight")
	check(is_zero_approx(model.presentation_delta(0.05)), "Rendered board motion shares the initial freeze")
	model.step(0.05)
	check(is_zero_approx(motion[0]) and model.powerup_snapshot().drags.is_empty()
		and model.hit_stop_snapshot().active and paid.size() == 1 and model.boss.elapsed == boss_elapsed,
		"The freeze does not secretly move pieces or the Boss, launch a drag or charge a second time")
	model.paused = true
	var clock: float = model.powerup_snapshot().clock
	model.step(1.0)
	check(model.powerup_snapshot().clock == clock and model.hit_stop_snapshot().active,
		"Pausing preserves the same accepted impact instead of consuming or replaying it")
	model.paused = false
	model.step(0.03)
	check(is_equal_approx(model.presentation_delta(0.05), 0.03),
		"A crossing frame freezes only the remaining twenty milliseconds")
	model.step(0.02)
	check(not model.hit_stop_snapshot().active and model.powerup_snapshot().drags.size() == 1,
		"The first real merge flight starts at the end of the hundred-millisecond stop")
	drain(model)
	check(model.collectable_ids().size() == 3 and not model.hit_stop_snapshot().active,
		"The finite impact recovers into all three products without a looping stop")
	model.purchase_powerup = Callable()
	var rejected = pictured_fixture(3)
	rejected.purchase_powerup = func(_id: String, _kind: String, _price: int) -> Dictionary:
		return {"ok": false, "reason": "insufficient", "after": 0}
	check(not rejected.activate_powerup("auto_merge") and not rejected.hit_stop_snapshot().active
		and rejected.gameplay_time_scale() == 1.0,
		"A rejected payment never plays a successful hit-stop or owns the board")
	rejected.purchase_powerup = Callable()


func _test_exact_capacities() -> void:
	var previous_price := 0
	for level in range(1, 10):
		var capacity: int = level + 2
		check(Economy.auto_merge_capacity(level) == capacity, "Every level adds exactly one completed output slot")
		if level > 1:
			var price: int = Economy.permanent_upgrade_price("auto_merge", level)
			check(price > previous_price and price % 25 == 0, "Every permanent upgrade costs strictly more saved coins")
			previous_price = price
		var model = fixture(level, capacity * 2 + 3)
		var original: Dictionary = {}
		var fragments := 0
		for tile: Dictionary in model.cells:
			original[int(tile.id)] = true
			fragments += int(tile.fragments)
		var used: Dictionary = {}
		model.powerup_drag_started.connect(func(drag: Dictionary) -> void:
			for key: String in ["source_id", "target_id"]:
				if original.has(int(drag[key])):
					used[int(drag[key])] = true)
		var paid: Array = payments(model)
		check(model.activate_powerup("auto_merge"), "A funded legal Auto merge starts at every owned level")
		drain(model)
		var state: Dictionary = model.powerup_snapshot()
		check(used.size() == capacity * 2 and state.affected_jellies == capacity * 2
			and state.capacity == capacity and state.completed_results == capacity,
			"Lv%d completes exactly %d products without treating their ingredients as output slots" % [level, capacity])
		check(model.cells.size() == capacity + 3 and model.merged_count == capacity
			and state.result_ids.size() == capacity,
			"Every finished product remains separate instead of collapsing into a reused result")
		for id: int in state.result_ids:
			check(not original.has(id) and not model.cell(id).is_empty()
				and model.cell(id).merge_level == 2,
				"Each advertised result survives as its own completed word after one ordinary upgrade")
		var remaining_fragments := 0
		for tile: Dictionary in model.cells:
			remaining_fragments += int(tile.fragments)
		check(remaining_fragments == fragments and model.cleared_pairs == 0 and model.collected_coins == 0,
			"Capacity limiting preserves all carried fragments and never collects or grants pickup income")
		check(paid.size() == 1 and paid[0][1] == "auto_merge" and paid[0][2] == 25,
			"Every owned capacity pays the same exact first-use price")
		# Releasing the completed timeline can start ordinary stack settlement.
		# Wait for settlement before checking the next actionable hover prediction.
		for frame in range(200):
			if model._powerup_inputs_ready():
				break
			model.step(0.025)
		check(model._powerup_inputs_ready(), "The completed operation returns a settled board to item input")
		var next_reduction: int = int(model.auto_merge_preview().reduction_count)
		check(next_reduction > 0 and model.powerup_price("auto_merge") == 50,
			"The next useful board has the fixed second-use price regardless of its reduction")
		check(model.snapshot().auto_merge_level == level and model.snapshot().auto_merge_capacity == capacity,
			"The public game snapshot advertises the same level and capacity that actually executed")
		model.purchase_powerup = Callable()


func authored_word(triple: bool) -> Dictionary:
	var text: String = "unhelpful" if triple else "rainbow"
	var parts: Array = [{"id": "a", "canonical_id": "fixture:un" if triple else "fixture:rain",
		"type": "prefix" if triple else "root", "canonical": "un-" if triple else "rain",
		"surface": "un-" if triple else "rain"},
		{"id": "b", "canonical_id": "fixture:help" if triple else "fixture:bow",
			"type": "root", "canonical": "help" if triple else "bow", "surface": "help" if triple else "bow"}]
	var nodes: Array = [{"id": "whole", "left": "a", "right": "b", "surface": text, "rule": "test_authored_join"}]
	if triple:
		parts.append({"id": "c", "canonical_id": "fixture:ful", "type": "suffix",
			"canonical": "-ful", "surface": "-ful"})
		nodes = [{"id": "helpful", "left": "b", "right": "c", "surface": "helpful", "rule": "test_authored_join"},
			{"id": "whole", "left": "a", "right": "helpful", "surface": text, "rule": "test_authored_join"}]
	return {"id": text, "text": text, "min_age": 3, "image": word.image, "audio": "fixture:" + text,
		"morphology": {"schema": 1, "id": "fixture:auto:" + text, "lexeme_id": text, "text": text,
			"kind": "morphological", "review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
			"parts": parts, "nodes": nodes, "roots": ["whole"]}}


func _test_complete_authored_paths() -> void:
	for triple: bool in [false, true]:
		var authored: Dictionary = authored_word(triple)
		var model := Model.new()
		check(model.configure([authored], 3, 91), "Use an explicitly authored multipart test fixture")
		model.cells.clear()
		model.spawn_interval = 10000.0
		for copy in range(3):
			for part: Dictionary in model._morphology.source_tiles(str(authored.morphology.id)):
				model.cells.append(model._new_composition_tile(part))
			model.cells.append(model._new_picture_tile(authored))
		settle_board(model)
		var paid: Array = payments(model)
		check(model.activate_powerup("auto_merge"), "Lv1 accepts complete authored paths regardless of ingredient count")
		drain(model)
		check(model.collectable_ids().size() == 3 and model.cells.size() == 3
			and model.powerup_snapshot().completed_results == 3
			and model.powerup_snapshot().affected_jellies == (12 if triple else 9)
			and paid.size() == 1,
			"Several root joins and their required pictures still produce all three promised collectable Jellies")
		model.purchase_powerup = Callable()


func _test_shortage() -> void:
	var model = pictured_fixture(3)
	model.cells.pop_back()
	var paid: Array = payments(model)
	check(model.activate_powerup("auto_merge"), "A useful partial-capacity purchase still needs a complete legal path")
	drain(model)
	check(model.powerup_snapshot().completed_results == 2 and model.collectable_ids().size() == 2
		and model.cells.size() == 3 and model.cells.any(func(tile: Dictionary) -> bool: return tile.jelly_kind == "root")
		and paid.size() == 1 and paid[0][2] == 25,
		"A missing picture preserves the unmatched root while a useful partial use pays the fixed first-use price")
	model.purchase_powerup = Callable()
	var missing = pictured_fixture(1)
	missing.cells.pop_back()
	var rejected: Array = payments(missing)
	check(not missing.activate_powerup("auto_merge") and rejected.is_empty()
		and not missing.hit_stop_snapshot().active and missing.cells.size() == 1,
		"No complete path means no debit, partial construction or successful impact")
	missing.purchase_powerup = Callable()


func _test_family_is_independent() -> void:
	var model = fixture(1, 7)
	var paid: Array = payments(model)
	check(model.activate_family_merge("cat"), "Paid goal-family merging is still available at Auto merge Lv1")
	drain(model)
	check(model.cells.size() == 1 and model.merged_count == 6 and paid.size() == 1 and paid[0][2] == 25,
		"Goal-family merging remains uncapped and pays its independent first-use price")
	model.purchase_powerup = Callable()


func _test_read_only_preview() -> void:
	var probe := Model.new()
	if not probe.has_method("auto_merge_preview"):
		check(false, "Auto merge exposes a read-only preview of its actual complete-path inputs")
		return
	for level: int in [1, 2, 9]:
		var capacity: int = level + 2
		var model = fixture(level, capacity * 2 + 4)
		var before: Dictionary = model.snapshot()
		var allocation: int = model._next_tile_id
		var receipt: int = model._next_event_id
		var rng_state: int = model._rng.state
		var events: Array = []
		model.changed.connect(func() -> void: events.append("changed"))
		model.cue_requested.connect(func(_cue: String) -> void: events.append("cue"))
		var preview: Dictionary = model.auto_merge_preview()
		check(preview.capacity == capacity and preview.result_count == capacity and preview.reduction_count == capacity
			and preview.input_ids.size() == capacity * 2,
			"The owned output capacity previews only the inputs of its complete legal paths")
		check(model.snapshot() == before and model._next_tile_id == allocation and model._next_event_id == receipt
			and model._rng.state == rng_state and events.is_empty(),
			"Hover prediction cannot allocate bodies, emit cues, pause clocks or mutate gameplay")
		var expected: Array = preview.input_ids.duplicate()
		preview.input_ids.clear()
		check(model.auto_merge_preview().input_ids == expected,
			"Preview consumers cannot mutate cached target IDs")
		var paid: Array = payments(model)
		check(model.activate_powerup("auto_merge"), "Use the same real planner after its uncharged preview")
		drain(model)
		var consumed: Array = model._powerup.used_input_ids.keys()
		consumed.sort()
		expected.sort()
		check(consumed == expected and model.powerup_snapshot().completed_results == capacity and paid.size() == 1
			and paid[0][2] == 25,
			"The saved first-use price preserves exact parity between highlighted originals and consumed inputs")
		model.purchase_powerup = Callable()
	for triple: bool in [false, true]:
		var authored: Dictionary = authored_word(triple)
		var model := Model.new()
		check(model.configure([authored], 3, 91), "Preview real authored multi-step construction")
		model.cells.clear()
		model.spawn_interval = 10000.0
		for copy in range(5):
			for part: Dictionary in model._morphology.source_tiles(str(authored.morphology.id)):
				model.cells.append(model._new_composition_tile(part))
			model.cells.append(model._new_picture_tile(authored))
		settle_board(model)
		var preview: Dictionary = model.auto_merge_preview()
		check(preview.result_count == 3 and preview.input_ids.size() == (12 if triple else 9)
			and preview.reduction_count == (9 if triple else 6),
			"Hover names every intermediate ingredient and required picture, not just the first join")
		var expected: Array = preview.input_ids.duplicate()
		var paid: Array = payments(model)
		model.activate_powerup("auto_merge")
		drain(model)
		var consumed: Array = model._powerup.used_input_ids.keys()
		consumed.sort()
		expected.sort()
		check(consumed == expected and model.powerup_snapshot().completed_results == 3
			and paid.size() == 1 and paid[0][2] == 25,
			"Full authored hover paths retain every net join while both ingredient counts pay the same first-use price")
		model.purchase_powerup = Callable()
	var unavailable = pictured_fixture(1)
	unavailable.cells.pop_back()
	check(unavailable.auto_merge_preview().result_count == 0 and unavailable.auto_merge_preview().input_ids.is_empty(),
		"An incomplete word with a missing picture cannot advertise an invented preview")
	var paused = pictured_fixture(4)
	paused.auto_merge_preview()
	paused.set_paused(true)
	check(paused.auto_merge_preview().input_ids.is_empty(), "A paused board cannot retain actionable hover targets")
	paused.set_paused(false)
	paused.boss.configure(preload("res://scripts/word_jelly_boss_catalog.gd").encounter(3), 71)
	var blocked: int = int(paused.cells[0].id)
	paused.boss.apply_status("freeze", blocked)
	check(blocked not in paused.auto_merge_preview().input_ids and paused.auto_merge_preview().result_count == 3,
		"A live Boss status updates the preview without borrowing a frozen ingredient")
	for remaining: float in [0.02, 0.30, 0.80]:
		var incoming = pictured_fixture(5)
		for index in range(2, incoming.cells.size()):
			var tile: Dictionary = incoming.cells[index]
			tile.arrival = true
			tile.arrival_delay = 0.0
			tile.settling = true
			tile.age = maxf(0.0, Model.settle_duration(tile) - remaining)
		var preview: Dictionary = incoming.auto_merge_preview()
		var expected: Array = preview.input_ids.duplicate()
		payments(incoming)
		check(incoming.activate_powerup("auto_merge"), "Supply in flight does not disable a useful legal Auto merge")
		drain(incoming)
		var consumed: Array = incoming._powerup.used_input_ids.keys()
		consumed.sort()
		expected.sort()
		check(consumed == expected and preview.result_count == incoming.powerup_snapshot().completed_results,
			"Preview preserves existing Auto behavior when captured airborne bodies become ready during the use: %.2fs" % remaining)
		incoming.purchase_powerup = Callable()


func _test_preview_board_sweep() -> void:
	var probe := Model.new()
	if not probe.has_method("auto_merge_preview"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 71103
	var cold_usec: int = 0
	var cached_usec: int = 0
	for seed_value in range(32):
		var model = fixture(1 + seed_value % 9, 12 + seed_value % 38)
		for tile: Dictionary in model.cells:
			model._set_merged_word(tile, word, rng.randi_range(1, 9), true)
		for index in range(model.cells.size() - 1, 0, -1):
			var other: int = rng.randi_range(0, index)
			var saved: Dictionary = model.cells[index]
			model.cells[index] = model.cells[other]
			model.cells[other] = saved
		settle_board(model)
		var started: int = Time.get_ticks_usec()
		var preview: Dictionary = model.auto_merge_preview()
		cold_usec = maxi(cold_usec, Time.get_ticks_usec() - started)
		started = Time.get_ticks_usec()
		check(model.auto_merge_preview() == preview, "A stable hover reuses its exact legal prediction")
		cached_usec = maxi(cached_usec, Time.get_ticks_usec() - started)
		var expected: Array = preview.input_ids.duplicate()
		var paid: Array = payments(model)
		if int(preview.result_count) > 0:
			check(model.activate_powerup("auto_merge"), "A forecasted mixed-level board has a real paid completion")
			drain(model)
			var consumed: Array = model._powerup.used_input_ids.keys()
			consumed.sort()
			expected.sort()
			check(consumed == expected and preview.result_count == model.powerup_snapshot().completed_results
				and paid.size() == 1, "Mixed levels, physical ordering and every owned capacity keep forecast/execution parity")
		else:
			check(not model.can_activate_powerup("auto_merge") and paid.is_empty(),
				"No legal forecast cannot invent a payable completion")
		model.purchase_powerup = Callable()
	print("Auto preview timing: maximum cold %dus, maximum cached %dus on this native host" % [cold_usec, cached_usec])


func _test_badge_geometry() -> void:
	var button := ButtonView.new()
	root.add_child(button)
	for scale_value: float in [0.65, 1.0, 1.5, 2.45, 3.2]:
		for dimensions: Vector2 in [Vector2(88, 44), Vector2(144, 44), Vector2(184, 56), Vector2(369, 56)]:
			button.set_ui_scale(scale_value, dimensions.y == 44)
			button.size = dimensions / scale_value
			for level in [1, 2, 9]:
				button.set_auto_merge_level(level)
				var state: Dictionary = button.snapshot()
				var badge: Array = state.capacity_badge.rect
				var area := Rect2(badge[0], badge[1], badge[2], badge[3])
				check(state.capacity == level + 2 and state.auto_merge_level == level
					and state.capacity_badge.text == str(level + 2) and state.capacity_badge.visible,
					"The visible badge always shows actual capacity, including the two-digit maximum")
				check(Rect2(Vector2.ZERO, button.size).grow(0.01).encloses(area),
					"The capacity badge stays inside the stable control at every supported scale")
				for key: String in ["title_rect", "price_rect", "coin_rect"]:
					var values: Array = state[key]
					check(not area.grow(-0.02).intersects(Rect2(values[0], values[1], values[2], values[3])),
						"Capacity never covers the name or exact coin price")
				check(state.accessibility_name.contains("Up to %d completed Jellies" % (level + 2)),
					"Screen readers receive capacity rather than only the decorative number")
				check(button._title.get_theme_font_size("font_size") >= 11
					and button._price_label.get_theme_font_size("font_size") >= 11,
					"The badge does not buy space by shrinking the name or exact price below readable display type")
	button.configure("family_merge", 50, true)
	check(not button.snapshot().capacity_badge.visible, "Goal-family buttons never inherit the Auto merge badge")
	button.free()


func _run() -> void:
	_test_read_only_preview()
	_test_preview_board_sweep()
	if OS.get_cmdline_user_args().has("--hover-preview-only"):
		print("Auto merge input preview: %d checks, %d failures" % [checks, failures])
		quit(1 if failures else 0)
		return
	_test_three_completed_results()
	_test_activation_hit_stop()
	if OS.get_cmdline_user_args().has("--output-fix-only"):
		print("Auto merge completed outputs: %d checks, %d failures" % [checks, failures])
		quit(1 if failures else 0)
		return
	_test_exact_capacities()
	_test_complete_authored_paths()
	_test_shortage()
	_test_family_is_independent()
	_test_badge_geometry()
	print("Auto merge permanent capacity: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
