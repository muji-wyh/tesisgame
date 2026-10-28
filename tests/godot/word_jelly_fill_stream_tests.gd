extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Motion = preload("res://scripts/jelly_motion.gd")
var checks := 0
var failures := 0
var data := Data.new()
var words: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func make_model(age: int = 3, speed: float = 1.0, seed_value: int = 71):
	var selected: Array = data.words.filter(func(word: Dictionary) -> bool:
		return int(word.min_age) == age).slice(0, 6).map(
			func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	var model := Model.new()
	check(model.configure(selected, age, seed_value), "Configure current reviewed vocabulary")
	var plan: Dictionary = Catalog.make_plan(1, selected, age, seed_value)
	check(model.bind_stage(plan), "Use a real current-age stage: " + str(plan.get("error", "")) + model.error)
	model.fall_speed_scale = speed
	model._stage_spawn_interval = 10000.0
	model.spawn_interval = 10000.0
	model.set_fill_mode(true)
	return model


func physical_rect(tile: Dictionary) -> Rect2:
	var row: float = float(tile.row)
	if bool(tile.get("arrival", false)):
		var elapsed: float = float(tile.age) - Model.arrival_delay(tile)
		if elapsed < -Model.EPSILON:
			return Rect2()
		var progress: float = clampf(elapsed / Motion.contact_at(tile), 0.0, 1.0)
		row -= Motion.travel_rows(tile) * (1.0 - progress * progress)
	return Rect2(Vector2(tile.column, row), Vector2(tile.width, tile.height))


func check_physics(model, context: String) -> void:
	var occupied := {}
	var ids := {}
	var area := 0
	var bodies: Array[Rect2] = []
	for tile: Dictionary in model.cells:
		ids[int(tile.id)] = true
		area += int(tile.width) * int(tile.height)
		model._occupy(occupied, tile.column, tile.row, tile.width, tile.height)
		var rect: Rect2 = physical_rect(tile)
		if rect.has_area():
			bodies.append(rect)
	check(ids.size() == model.cells.size() and area == occupied.size() and area <= Model.CAPACITY,
		context + ": real landing reservations and identities never overlap or exceed capacity")
	var overlap := false
	for index in range(bodies.size()):
		for next in range(index + 1, bodies.size()):
			var intersection: Rect2 = bodies[index].intersection(bodies[next])
			if intersection.size.x > 0.0001 and intersection.size.y > 0.0001:
				overlap = true
	check(not overlap, context + ": simultaneous falling bodies cannot pass through one another")
	if model.cells.any(func(tile: Dictionary) -> bool: return not model.is_settled(tile)):
		check(model.full_elapsed < 0.0, context + ": reserved future cells do not start danger before landing")


func test_streams() -> void:
	for age in [3, 8, 12]:
		for speed: float in [1.0, 1.4, 2.2]:
			var model = make_model(age, speed)
			var coin_rng: int = model._coin_rng.state
			model.step(0.01)
			check(model.cells.filter(func(tile: Dictionary) -> bool: return bool(tile.arrival)).all(
				func(tile: Dictionary) -> bool: return is_equal_approx(float(tile.motion_speed_scale), speed)),
				"Each supplied body actually uses the requested stage motion speed")
			check(model.cells.filter(func(tile: Dictionary) -> bool: return bool(tile.arrival)).all(
				func(tile: Dictionary) -> bool: return is_equal_approx(Model.arrival_slot_clearance(tile),
					sqrt(2.0 * int(tile.height) / Motion.ARRIVAL_GRAVITY) / speed)),
				"The preview handoff waits for actual speed-aware physical entrance clearance")
			var first_generated: int = model.generated_tiles
			var first_ids: Array[int] = []
			for tile: Dictionary in model.cells:
				if tile.get("fill_stream", false):
					first_ids.append(int(tile.id))
			var overlap_seen := false
			for frame in range(600):
				model.step(0.01)
				check_physics(model, "Age%s speed%s frame%s" % [age, speed, frame])
				overlap_seen = overlap_seen or (model.generated_tiles > first_generated and model.cells.any(
					func(tile: Dictionary) -> bool: return int(tile.id) in first_ids and not model.is_settled(tile)))
				if model.cells.size() == Model.CAPACITY and model._settling_remaining() <= Model.EPSILON:
					break
			check(overlap_seen, "Every vocabulary shape and fall speed overlaps successive Fill generations")
			check(model.cells.size() == Model.CAPACITY and model._settling_remaining() <= Model.EPSILON,
				"The continuous stream genuinely fills and settles all reachable cells")
			check(model._coin_rng.state == coin_rng and model.cleared_pairs == 0 and model.combo_actions == 0,
				"Supply never rolls pickup coins, collects or manufactures combo credit")


func test_step_equivalence() -> void:
	for speed: float in [1.0, 2.2]:
		var large = make_model(8, speed)
		var small = make_model(8, speed)
		large.step(3.0)
		for frame in range(300):
			small.step(0.01)
		check(large.generated_tiles == small.generated_tiles and large._rng.state == small._rng.state,
			"Large and small frames consume exactly the same advertised supply")
		check(large.cells.size() == small.cells.size(), "Frame size cannot change occupied capacity")
		for index in range(large.cells.size()):
			var a: Dictionary = large.cells[index]
			var b: Dictionary = small.cells[index]
			check(a.id == b.id and a.column == b.column and a.row == b.row
				and absf(float(a.age) - float(b.age)) < 0.0001
				and absf(Model.arrival_delay(a) - Model.arrival_delay(b)) < 0.0001,
				"Each streamed body's identity, destination and physical clock are frame-independent")


func test_lane_ownership() -> void:
	var model = make_model()
	model.set_fill_mode(false)
	check(model.drop_now(), "Begin with a real manually advertised packet")
	model.step(0.45)
	var advertised := {}
	for index in range(model.upcoming.size()):
		advertised[index] = int(model.upcoming[index].id)
	var generated: int = model.generated_tiles
	model.set_fill_mode(true)
	model.step(0.001)
	check(model.generated_tiles > generated and model.cells.any(func(tile: Dictionary) -> bool:
		return bool(tile.arrival) and not model.is_settled(tile)),
		"An already cleared lane feeds even while neighboring lanes still fall")
	for index in range(model.upcoming.size()):
		var predecessor: Dictionary = model.cells.filter(func(tile: Dictionary) -> bool:
			return bool(tile.arrival) and int(tile.arrival_index) == index)[0]
		if float(predecessor.age) - Model.arrival_delay(predecessor) < 0.4 - Model.EPSILON:
			check(int(model.upcoming[index].id) == int(advertised[index]),
				"A blocked preview keeps its own exact word/part instead of sliding or being replaced")


func test_interruption() -> void:
	var model = make_model()
	model.step(0.01)
	var generated: int = model.generated_tiles
	model.set_fill_mode(false)
	model.step(0.8)
	check(model.generated_tiles == generated, "Off stops future waves, not just the next landed packet")
	model.set_fill_mode(true)
	model.set_paused(true)
	var before: Array = model.cells.duplicate(true)
	model.step(10.0)
	check(model.generated_tiles == generated and model.cells == before, "Pause freezes release and in-flight clocks")
	model.set_paused(false)
	model.step(0.01)
	check(model.generated_tiles > generated, "Resume immediately uses a physically clear entrance")
	var held_id: int = int(model.cells[0].id)
	model.set_held_tile(held_id)
	generated = model.generated_tiles
	model.step(0.8)
	check(model.generated_tiles == generated, "A held body retains supply ownership while the stream is on")
	model.set_held_tile()
	model.step(0.05)
	check(model.generated_tiles > generated, "Releasing the held body returns clear entrances to Fill")
	for action in ["off", "pause", "configure"]:
		var interrupted = make_model()
		var initial: int = interrupted.generated_tiles
		interrupted.motion_advanced.connect(func(_delta: float) -> void:
			if action == "off":
				interrupted.set_fill_mode(false)
			elif action == "pause":
				interrupted.set_paused(true)
			else:
				check(interrupted.configure(words, 3, 72), "A callback can replace the active round")
		, CONNECT_ONE_SHOT)
		interrupted.step(3.0)
		check(interrupted.generated_tiles == (15 if action == "configure" else initial + 5),
			"Reentrant %s cannot release another stale wave at the closing boundary" % action)


func test_deadline_and_manual() -> void:
	var model = make_model()
	var generated: int = model.generated_tiles
	model.stage_run.advance(model.stage_run.remaining - 0.4)
	model.step(1.0)
	check(model.stage_ending() and model.generated_tiles == generated + 5,
		"A deadline tied with entrance clearance wins before any extra supply")
	var manual = make_model()
	manual.set_fill_mode(false)
	generated = manual.generated_tiles
	manual.step(2.0)
	check(manual.generated_tiles == generated, "Ordinary mode keeps its existing countdown")
	manual.upcoming[0].fill_stream = true
	check(manual.drop_now() and manual.drop_now(), "Rapid manual supply remains available without a new cooldown")
	for tile: Dictionary in manual.cells:
		if bool(tile.arrival):
			check(not tile.get("fill_stream", false) and is_equal_approx(Model.arrival_slot_clearance(tile), Model.ARRIVAL_SLOT_CLEARANCE),
				"Manual arrival queue and preview handoff retain their established contract")


func test_broken_supply() -> void:
	var model = make_model()
	model.boss.configure(preload("res://scripts/word_jelly_boss_catalog.gd").encounter(18), 71)
	model.boss.broken_remaining = 8.0
	var generated: int = model.generated_tiles
	var advertised: Array = model.upcoming.duplicate(true)
	model.step(0.01)
	check(model.generated_tiles == generated + 2,
		"Continuous Fill cannot immediately reopen a Boss-restricted two-body batch")
	for index in range(2, advertised.size()):
		check(int(model.upcoming[index].id) == int(advertised[index].id),
			"The broken sky retains every undispatched advertised partner")
	model.step(0.4)
	check(model.generated_tiles == generated + 2,
		"The damaged batch retains its existing ownership while its bodies are falling")
	model.boss.broken_remaining = 0.01
	model.step(0.02)
	check(model.generated_tiles > generated + 2 and model.cells.any(func(tile: Dictionary) -> bool:
		return bool(tile.arrival) and not model.is_settled(tile)),
		"Repair immediately restores continuous entry without waiting for the old batch to land")


func _run() -> void:
	check(data.load_all(), "Load the actual current-age reviewed vocabulary")
	words = data.words.filter(func(word: Dictionary) -> bool: return int(word.min_age) == 3).slice(0, 6).map(
		func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	test_streams()
	test_step_equivalence()
	test_lane_ownership()
	test_interruption()
	test_deadline_and_manual()
	test_broken_supply()
	print("Continuous Fill: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
