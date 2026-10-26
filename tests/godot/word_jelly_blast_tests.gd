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
	return {"id": "blast:" + text, "text": text, "min_age": 3,
		"image": "assets/images/words/" + text + ".webp", "audio": "assets/audio/words/" + text + ".wav"}


func _composed() -> Dictionary:
	var word: Dictionary = _word("unbelievable")
	word.morphology = {"schema": 1, "id": "blast-unbelievable", "lexeme_id": word.id,
		"text": word.text, "kind": "morphological",
		"review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
		"parts": [
			{"id": "un", "canonical_id": "prefix:un", "type": "prefix", "canonical": "un-", "surface": "un-"},
			{"id": "believe", "canonical_id": "root:believe", "type": "root", "canonical": "believe", "surface": "believe"},
			{"id": "able", "canonical_id": "suffix:able", "type": "suffix", "canonical": "-able", "surface": "-able"}],
		"nodes": [
			{"id": "believable", "left": "believe", "right": "able", "surface": "believable", "rule": "drop_final_e", "break_offsets": [6]},
			{"id": "whole", "left": "un", "right": "believable", "surface": "unbelievable", "rule": "prefix", "break_offsets": [2, 8]}],
		"roots": ["whole"]}
	return word


func _model(extra: Array = []) -> RefCounted:
	var model := Model.new()
	check(model.configure([_word(), _word("dog")] + extra, 3, 9317), "A blast uses a real configured word board")
	model.cells.clear()
	model.spawn_interval = 10000.0
	model._coin_rng.seed = 0
	return model


func _put(model: RefCounted, tile: Dictionary, column: int, row: int) -> Dictionary:
	tile.column = column
	tile.row = row
	tile.age = 100.0
	tile.settling = false
	tile.falling = false
	tile.arrival = false
	model.cells.append(tile)
	return tile


func _ready(model: RefCounted, column: int, row: int, level: int, fragments: int = 0) -> Dictionary:
	var tile: Dictionary = model._new_word_root(_word("dog"), fragments)
	model._set_merged_word(tile, _word("dog"), level, true)
	return _put(model, tile, column, row)


func _targets(model: RefCounted, origin: Dictionary, level: int) -> Array:
	check(model.has_method("_blast_target_ids"), "Collection levels expose their actual bounded blast footprint")
	return model.call("_blast_target_ids", origin, level) if model.has_method("_blast_target_ids") else []


func _test_footprints() -> void:
	var model: RefCounted = _model()
	for row in range(Model.ROWS):
		for column in range(Model.COLUMNS):
			_put(model, model._new_word_root(_word()), column, row)
	var origin: Dictionary = model.cells[3 * Model.COLUMNS + 2]
	var expected: Array[int] = [0, 1, 2, 3, 7, 11, 8, 22, 39]
	for level in range(1, 10):
		var targets: Array = _targets(model, origin, level)
		check(targets.size() == expected[level - 1], "Lv%d selects exactly its requested full-board footprint" % level)
		var seen: Dictionary = {}
		var inner: int = 0
		var outer: int = 0
		for id: int in targets:
			var tile: Dictionary = model.cell(id)
			check(id != int(origin.id) and not seen.has(id) and not tile.is_empty(), "Blast targets are distinct existing neighbors, never the collected source")
			seen[id] = true
			var dx: int = absi(int(tile.column) - int(origin.column))
			var dy: int = absi(int(tile.row) - int(origin.row))
			var distance: int = maxi(dx, dy)
			if distance == 1:
				inner += 1
			elif distance == 2:
				outer += 1
			if level in [2, 3, 4, 7]:
				check(distance == 1, "Local bursts never wrap across a board edge or choose a distant body")
			elif level == 5:
				check(dx == 0, "Lv5 marks only the collected jelly's column")
			elif level == 6:
				check(dx == 0 or dy == 0, "Lv6 marks the exact row-and-column cross")
			elif level == 8:
				check(distance <= 2, "Lv8 never reaches outside its two surrounding rings")
		if level == 8:
			check(inner == 8 and outer == 14, "Lv8 respects the specified eight-plus-fourteen cap rather than silently selecting twenty-four")
	var corner: Dictionary = model.cells[0]
	check(_targets(model, corner, 7).size() == 3 and _targets(model, corner, 8).size() == 8,
		"Edge and corner footprints clip to the actual board without invented or duplicate neighbors")
	var arrangements: Dictionary = {}
	for attempt in range(24):
		arrangements[str(_targets(model, origin, 2))] = true
	check(arrangements.size() > 1, "Low-level affected neighbors are genuinely sampled rather than always picking the first body")


func _fixture(level: int = 2) -> Dictionary:
	var model: RefCounted = _model()
	var source: Dictionary = _ready(model, 2, 7, level, 2)
	var marked: Dictionary = _put(model, model._new_word_root(_word(), 3), 1, 7)
	var partner: Dictionary = _put(model, model._new_picture_tile(_word(), 4), 4, 7)
	var launches: Array = []
	var cues: Array[String] = []
	var purchases: Array = []
	var learning: Array = []
	model.powerup_drag_started.connect(func(state: Dictionary) -> void: launches.append(state.duplicate(true)))
	model.cue_requested.connect(func(cue: String) -> void: cues.append(cue))
	model.powerup_feedback.connect(func(kind: String, ok: bool) -> void: purchases.append([kind, ok]))
	model.word_attempted.connect(func(id: String, ids: Array[String], ok: bool) -> void: learning.append([id, ids, ok]))
	return {"model": model, "source": source, "marked": marked, "partner": partner,
		"launches": launches, "cues": cues, "purchases": purchases, "learning": learning}


func _drain(model: RefCounted) -> void:
	for frame in range(250):
		model.step(0.04)
		if not model.powerup_active() and model.fusions.is_empty() and model.stage_transition_ready():
			break


func _test_flight_and_accounting() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	var supply_state: int = model._rng.state
	check(model.collect(int(fixture.source.id)), "A real Lv2 collection starts its usual transaction and release")
	model.step(Model.collection_seconds(2))
	model.step(0.001)
	var marking: Dictionary = model.powerup_snapshot()
	check(marking.active and marking.kind == "blast" and marking.stage == "mark",
		"A committed collection marks its affected bodies before automatic matching")
	check(model.cleared_pairs == 1 and model.fragment_count == 2 and model.cells.size() == 2,
		"Only the collected source is removed and banked before the chain reaction")
	model.step(0.12)
	check(fixture.launches.is_empty() and fixture.cues.has("blast_wave") and not fixture.cues.has("blast_mark"),
		"The source sounds first while outward marks are still travelling")
	model.step(float(model.powerup_snapshot().duration) - float(model.powerup_snapshot().elapsed) + 0.002)
	check(fixture.launches.is_empty() and fixture.cues.has("blast_mark"),
		"A marking impact sounds on arrival before the source flies")
	_drain(model)
	check(fixture.launches.size() == 1 and int(fixture.launches[0].source_id) == int(fixture.marked.id)
		and int(fixture.launches[0].target_id) == int(fixture.partner.id),
		"The marked jelly itself flies to a legal matching partner anywhere on the board")
	check(model.cells.size() == 1 and model.cells[0].jelly_kind == "merged" and model.cells[0].merge_level == 1
		and model.cells[0].word.id == _word().id and model.cells[0].fragments == 7,
		"The automatic union keeps the normal level, sense identity and both bodies' fragments")
	check(model.combo_count == 2 and model.combo_coins == 0 and model.cleared_pairs == 1
		and fixture.purchases.is_empty() and model.powerup_snapshot().kind == "blast"
		and model.snapshot().powerup_uses == {"auto_merge": 0, "fragments": 0},
		"Collection chains do not charge a paid item, mint combo coins, auto-collect, or advance purchase prices")
	check(model._rng.state == supply_state, "Random blast selection never consumes word-supply randomness")
	check(fixture.learning.size() == 1 and model.cells[0].assisted and not model.cells[0].mastery_eligible,
		"Only the deliberately collected source earns learning; automatic solutions are assisted")
	check(fixture.cues.has("contact") and fixture.cues.has("merge"), "The automatic flight keeps its acquired contact and fusion feedback")
	var id: int = int(model.cells[0].id)
	check(model.collect(id), "The resulting merged word remains available for a later deliberate collection")
	model.step(2.0)
	check(model.cleared_pairs == 2 and model.fragment_count == 9 and fixture.learning.size() == 2,
		"Later collection records one answer for the automatic word and banks its fragments")


func _test_reverse_authored_join() -> void:
	var word: Dictionary = _composed()
	var model: RefCounted = _model([word])
	var source: Dictionary = _ready(model, 2, 7, 2)
	var roots: Array = model._morphology.source_tiles(str(word.morphology.id))
	var marked: Dictionary = _put(model, model._new_composition_tile(roots[2]), 1, 7)
	var partner: Dictionary = _put(model, model._new_composition_tile(roots[1]), 4, 7)
	var launches: Array = []
	model.powerup_drag_started.connect(func(state: Dictionary) -> void: launches.append(state.duplicate(true)))
	check(not model.can_merge(marked, partner) and model.can_merge(partner, marked),
		"The reviewed suffix fixture has exactly one valid semantic ordering")
	check(model.collect(int(source.id)), "A source collection can reach a marked right-hand root")
	model.step(Model.collection_seconds(2))
	_drain(model)
	check(launches.size() == 1 and launches[0].source_id == marked.id and launches[0].target_id == partner.id,
		"The affected suffix flies toward its partner without pretending the player dragged the opposite root")
	check(model.cells.size() == 1 and model.cells[0].text == "believable" and model.cells[0].column == 4
		and model.cells[0].assisted and not model.is_valid_word(model.cells[0]),
		"Automatic matching preserves the reviewed drop-e spelling and the actual flight destination")


func _test_unmatched_and_cap() -> void:
	for level in range(1, 10):
		var model: RefCounted = _model()
		var source: Dictionary = _ready(model, 2, 7, level)
		var unmatched: Dictionary = _put(model, model._new_picture_tile(_word()), 1, 7)
		check(model.collect(int(source.id)), "Every supported level retains its direct collection")
		model.step(Model.collection_seconds(level))
		_drain(model)
		check(model.cells.size() == 1 and model.cells[0].id == unmatched.id and model.combo_count == 1
			and not model.powerup_active(), "Unmatched marks settle harmlessly instead of inventing a match or hanging the board")
	var model: RefCounted = _model()
	var source: Dictionary = _ready(model, 2, 7, 9)
	var left: Dictionary = _ready(model, 1, 7, 5)
	var right: Dictionary = _ready(model, 4, 7, 5)
	check(model.collect(int(source.id)), "A Lv9 full-board source can mark high-level words")
	model.step(Model.collection_seconds(9))
	_drain(model)
	check(model.cell(int(left.id)).is_empty() and model.cell(int(right.id)).is_empty()
		and model.merged_count == 1 and model.cells.size() == 1 and model.cells[0].merge_level == 9,
		"Automatic blast matching also merges over-cap identical words and clamps only the output level")


func _test_persistence_and_pause() -> void:
	var fixture: Dictionary = _fixture(9)
	var model: RefCounted = fixture.model
	model._coin_rng.seed = 208
	var writes: Array = []
	model.credit_collection = func(id: String, coins: int) -> Dictionary:
		writes.append([id, coins])
		return {"ok": false}
	check(model.collect(int(fixture.source.id)), "A high-level collection reserves its real coin outcome")
	model.step(Model.collection_seconds(9))
	check(not model.cell(int(fixture.source.id)).is_empty() and not model.powerup_active()
		and fixture.launches.is_empty() and not fixture.cues.has("blast_wave"),
		"A failed collection save cannot trigger free automatic merges or consume neighbors")
	model.credit_collection = func(id: String, coins: int) -> Dictionary:
		writes.append([id, coins])
		return {"ok": true}
	check(model.collect(int(fixture.source.id)), "The same saved-outcome collection can retry")
	model.step(Model.collection_seconds(9))
	model.step(0.01)
	check(writes.size() == 2 and writes[0] == writes[1], "Blast recovery retains the exact collection receipt and coin roll")
	model.set_paused(true)
	var before: Dictionary = model.snapshot()
	model.step(100.0)
	check(model.snapshot() == before, "Pause freezes marking, flights and the combo countdown together")
	model.set_paused(false)
	_drain(model)
	check(fixture.launches.size() == 1 and model.cleared_pairs == 1, "Resume executes each captured match once after successful saving")
	model.credit_collection = Callable()
	model.finish_round("exit")
	model.step(100.0)
	check(not model.powerup_active() and model.phase == "finished", "Ending cancels every remaining blast action")


func _test_batch_and_exit() -> void:
	var model: RefCounted = _model()
	model.set_pip_level(3)
	_ready(model, 0, 7, 2, 1)
	_ready(model, 4, 7, 2, 1)
	var left: Dictionary = _put(model, model._new_word_root(_word(), 2), 1, 7)
	var right: Dictionary = _put(model, model._new_picture_tile(_word(), 3), 3, 7)
	var launches: Array = []
	model.powerup_drag_started.connect(func(state: Dictionary) -> void: launches.append(state.duplicate(true)))
	check(model.start_collection_batch(), "Two high-level words can use the normal automatic Collect batch")
	model.step(Model.BATCH_BEAT_SECONDS * 2.0)
	check(model.cleared_pairs == 2 and model.collection_batch_snapshot().completed == 2
		and not model.collection_batch_active(), "Blast reactions never steal a body already promised to the collection batch")
	_drain(model)
	check(launches.size() == 1 and model.cells.size() == 1 and model.cells[0].fragments == 5
		and model.fragment_count == 2 and model.combo_count == 3,
		"Overlapping batch blasts coalesce their marks and merge the same two endpoints only once")
	check(model.cell(int(left.id)).is_empty() and model.cell(int(right.id)).is_empty()
		and model.cleared_pairs == 2, "Batch-triggered automatic unions remain uncollected")
	var fixture: Dictionary = _fixture()
	model = fixture.model
	model.collect(int(fixture.source.id))
	model.step(Model.collection_seconds(2))
	model.step(0.01)
	model.step(float(model.powerup_snapshot().duration) - float(model.powerup_snapshot().elapsed)
		+ Model.BLAST_MARK_RECOVERY_SECONDS + 0.10)
	check(model.powerup_active() and not model.powerup_snapshot().drags.is_empty(),
		"The exit fixture has a real automatic source in flight")
	var result: Dictionary = model.finish_round("exit")
	model.step(100.0)
	check(model.phase == "finished" and not model.powerup_active() and model.fusions.is_empty()
		and model.cleared_pairs == 1 and model.combo_coins == 0 and model.cells.size() == 1
		and model.finish_round("exit") == result, "Exit settles an accepted flight without collecting its result or repeating any reward")


func _test_frame_subdivision() -> void:
	var coarse: Dictionary = _fixture(9)
	var fine: Dictionary = _fixture(9)
	for fixture: Dictionary in [coarse, fine]:
		fixture.model.collect(int(fixture.source.id))
		fixture.model.step(Model.collection_seconds(9))
	coarse.model.step(2.0)
	for frame in range(50):
		fine.model.step(0.04)
	check(coarse.launches.size() == 1 and fine.launches.size() == 1
		and coarse.model.combo_count == fine.model.combo_count
		and coarse.model.collected_coins == fine.model.collected_coins
		and coarse.model.fragment_count == fine.model.fragment_count,
		"Slow and fast frames agree on automatic matches, combo increments, coins and fragments")
	check(coarse.model.cells.size() == 1 and fine.model.cells.size() == 1
		and coarse.model.cells[0].id == fine.model.cells[0].id
		and coarse.model.cells[0].text == fine.model.cells[0].text
		and coarse.model.cells[0].fragments == fine.model.cells[0].fragments,
		"Frame subdivision cannot change the selected endpoints or the resulting word")


func _test_pending_blast_purchase_guard() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	var purchases: Array = []
	model.purchase_powerup = func(id: String, kind: String, price: int) -> Dictionary:
		purchases.append([id, kind, price])
		return {"ok": true}
	model.collect(int(fixture.source.id))
	model.step(Model.collection_seconds(2))
	check(not model.can_activate_powerup("auto_merge") and not model.can_activate_powerup("fragments"),
		"A promised free blast cannot be overtaken by a paid item between simulation frames")
	check(not model.activate_powerup("auto_merge") and purchases.is_empty(),
		"Pending blast protection rejects a purchase before any wallet callback or repeat-price change")
	model.purchase_powerup = Callable()


func _test_hit_stop_timeline() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	var falling: Dictionary = _put(model, model._new_word_root(_word("dog")), 0, 6)
	check(model.collect(int(fixture.source.id)), "Hit stop follows a real durable collection")
	model.step(Model.collection_seconds(2) - 0.001)
	check(not model.snapshot().get("hit_stop", {}).get("active", false),
		"Collecting and saving finish before the marking slowdown begins")
	model.step(0.002)
	var state: Dictionary = model.powerup_snapshot()
	var slow: Dictionary = model.snapshot().get("hit_stop", {})
	check(state.stage == "mark" and slow.get("active", false)
		and is_zero_approx(float(slow.get("time_scale", 1.0))) and int(state.blast.marked) == 0,
		"A collected Jelly first holds a real local impact freeze before releasing any mark")
	var before_age: float = float(model.cell(int(fixture.marked.id)).age)
	var falling_age: float = float(model.cell(int(falling.id)).age)
	var before_clock: float = float(state.clock)
	var combo: Dictionary = model.combo_snapshot()
	var spawn: float = model.spawn_elapsed
	var motion_delta: float = model.presentation_delta(0.20)
	model.step(0.20)
	state = model.powerup_snapshot()
	check(is_equal_approx(float(state.clock) - before_clock, 0.20)
		and is_equal_approx(float(model.cell(int(fixture.marked.id)).age) - before_age, motion_delta)
		and bool(model.cell(int(falling.id)).falling)
		and is_equal_approx(float(model.cell(int(falling.id)).age) - falling_age, motion_delta),
		"Outward marking uses real time while the board first freezes and then advances at twelve percent")
	check(int(state.blast.marked) == 0 and not fixture.cues.has("blast_mark")
		and fixture.launches.is_empty() and model.combo_snapshot() == combo and model.spawn_elapsed == spawn,
		"Travel cannot mark early, start matching, drain the combo or advance supply")
	var until_impact: float = float(state.duration) - float(state.elapsed)
	model.step(until_impact - 0.001)
	check(model.snapshot().get("hit_stop", {}).get("active", false)
		and int(model.powerup_snapshot().blast.marked) == 0,
		"Slow motion lasts until the final outward mark actually reaches its target")
	model.step(0.002)
	state = model.powerup_snapshot()
	slow = model.snapshot().get("hit_stop", {})
	check(not slow.get("active", true) and is_equal_approx(float(slow.get("time_scale", 0.0)), 1.0)
		and int(state.blast.marked) == 1 and fixture.cues.count("blast_mark") == 1,
		"The final marking impact restores full speed exactly once")
	check(fixture.launches.is_empty(), "A planted impact is visible before automatic matching lifts its body")
	before_age = float(model.cell(int(fixture.marked.id)).age)
	model.step(0.04)
	check(is_equal_approx(float(model.cell(int(fixture.marked.id)).age) - before_age, 0.04),
		"Ordinary board time resumes during the short grounded impact recovery")
	model.set_paused(true)
	var frozen: Dictionary = model.snapshot()
	model.step(10.0)
	check(model.snapshot() == frozen, "Pausing during impact recovery cannot launch or replay the marking action")
	model.set_paused(false)
	_drain(model)
	check(fixture.launches.size() == 1 and model.cleared_pairs == 1 and model.combo_count == 2
		and not model.snapshot().get("hit_stop", {}).get("active", true),
		"The weighted sequence keeps one assisted merge, one pickup and no lingering slowdown")
	for level: int in [1, 2]:
		model = _model()
		var source: Dictionary = _ready(model, 2, 7, level)
		model.collect(int(source.id))
		model.step(Model.collection_seconds(level) + 0.20)
		check(not model.snapshot().get("hit_stop", {}).get("active", false) and not model.powerup_active(),
			"Lv1 and a blast with no affected body never create an empty slowdown")
	var coarse: Dictionary = _fixture()
	var fine: Dictionary = _fixture()
	for item: Dictionary in [coarse, fine]:
		item.model.collect(int(item.source.id))
		item.model.step(Model.collection_seconds(2))
		item.model.step(0.001)
	var crossing: float = float(coarse.model.powerup_snapshot().duration) - float(coarse.model.powerup_snapshot().elapsed) + 0.06
	coarse.model.step(crossing)
	var remaining: float = crossing
	while remaining > 0.000001:
		var delta: float = minf(0.01, remaining)
		fine.model.step(delta)
		remaining -= delta
	check(not coarse.model.snapshot().hit_stop.active and not fine.model.snapshot().hit_stop.active
		and coarse.launches.is_empty() and fine.launches.is_empty()
		and is_equal_approx(float(coarse.model.cell(int(coarse.marked.id)).age),
			float(fine.model.cell(int(fine.marked.id)).age)),
		"A frame crossing the final marking impact slows only its marking portion, never the normal-speed remainder")


func _test_unmatched_mark_impact() -> void:
	var model: RefCounted = _model()
	var source: Dictionary = _ready(model, 2, 7, 2)
	var target: Dictionary = _put(model, model._new_picture_tile(_word()), 1, 7)
	model.collect(int(source.id))
	model.step(Model.collection_seconds(2))
	model.step(0.01)
	model.step(float(model.powerup_snapshot().duration) - float(model.powerup_snapshot().elapsed) + 0.035)
	check(model.powerup_active() and model.powerup_snapshot().stage == "ready"
		and not model.snapshot().hit_stop.active and model.powerup_snapshot().blast.marked == 1,
		"Even an unmatched target retains its visible planted impact after slow motion ends")
	model.step(Model.BLAST_MARK_RECOVERY_SECONDS)
	check(not model.powerup_active() and not model.cell(int(target.id)).is_empty()
		and model.merged_count == 0 and model.cleared_pairs == 1,
		"Unmatched impact recovery ends cleanly without inventing a match or an extra pickup")


func _test_perceptible_hit_stop() -> void:
	var fixture: Dictionary = _fixture()
	var model: RefCounted = fixture.model
	model.collect(int(fixture.source.id))
	model.step(Model.collection_seconds(2))
	model.step(0.001)
	var hit: Dictionary = model.hit_stop_snapshot()
	check(hit.get("phase", "") == "freeze" and is_zero_approx(model.gameplay_time_scale())
		and float(model.powerup_snapshot().duration) >= 0.59,
		"A real, readable impact freeze precedes at least six tenths of a second of source-to-target marking")
	var age: float = float(model.cell(int(fixture.marked.id)).age)
	model.step(0.08)
	check(is_equal_approx(float(model.cell(int(fixture.marked.id)).age), age)
		and fixture.cues.count("blast_mark") == 0,
		"The impact hold truly freezes the world before the source begins releasing marks")
	model.step(0.05)
	check(model.hit_stop_snapshot().get("phase", "") == "slow"
		and is_equal_approx(model.gameplay_time_scale(), 0.12),
		"After the short freeze, visible outward marking runs over the slowed board")
	_drain(model)
	check(fixture.launches.size() == 1 and not model.hit_stop_snapshot().active and model.cleared_pairs == 1,
		"Making the impact readable preserves exactly one automatic match and one collected word")


func _run() -> void:
	_test_footprints()
	_test_flight_and_accounting()
	_test_reverse_authored_join()
	_test_unmatched_and_cap()
	_test_persistence_and_pause()
	_test_batch_and_exit()
	_test_frame_subdivision()
	_test_pending_blast_purchase_guard()
	_test_hit_stop_timeline()
	_test_unmatched_mark_impact()
	_test_perceptible_hit_stop()
	print("Word Jelly blast: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
