extends SceneTree

const CATALOG_PATH: String = "res://scripts/word_jelly_stage_catalog.gd"
const RUN_PATH: String = "res://scripts/word_jelly_stage_run.gd"
const STORE_PATH: String = "res://scripts/word_jelly_campaign_store.gd"
const MAX_SAVE_BYTES: int = 2 * 1024 * 1024
const CHAPTERS: Array[String] = ["Meadow", "Grove", "Pine Trail", "Cottage Creek",
	"Amber Orchard", "Snowfields", "Frost Pines", "Palm Lagoon", "Cactus Valley",
	"High Peaks", "Castle Gardens"]
const PROFILES: Array[String] = ["Discover", "Practice", "Build", "Breather",
	"Mix", "Flow", "Reward", "Prepare", "Finale"]
const NOUNS: Array[String] = ["apple", "book", "cat", "dog", "eagle", "flower",
	"garden", "house", "island", "jungle", "kite", "lion", "moon", "nest", "orange",
	"panda", "queen", "river", "sun", "tree", "umbrella", "violin", "whale", "zebra"]

var checks: int = 0
var failures: int = 0
var _catalog
var _run_script
var _store_script


class MemoryHost extends RefCounted:
	var text: Variant = null
	var fail_read: bool = false
	var fail_write: bool = false
	var write_reply: Variant = true
	var race_text: Variant = null
	var lose_ack_once: bool = false
	var calls: int = 0
	var writes: int = 0

	func jellyCampaignState() -> Variant:
		return false if fail_read else text

	func saveJellyCampaignState(value: String, expected_snapshot: Variant) -> Variant:
		calls += 1
		if race_text != null:
			text = race_text
			race_text = null
		if fail_write or not write_reply is bool or not write_reply or text != expected_snapshot:
			return false if fail_write or text != expected_snapshot else write_reply
		text = value
		writes += 1
		if lose_ack_once:
			lose_ack_once = false
			return false
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _load_domain(path: String):
	var exists: bool = ResourceLoader.exists(path)
	check(exists, "Campaign domain resource exists: " + path)
	if not exists:
		return null
	var script = load(path)
	check(script is GDScript and script.can_instantiate(), "Campaign domain script compiles: " + path)
	return script if script is GDScript and script.can_instantiate() else null


func _run() -> void:
	_catalog = _load_domain(CATALOG_PATH)
	_run_script = _load_domain(RUN_PATH)
	_store_script = _load_domain(STORE_PATH)
	if _catalog != null and _run_script != null and _store_script != null:
		_test_all_stage_recipes()
		_test_pool_scope_and_validation()
		_test_effort_budgets_and_relief()
		_test_exact_replay_recipes()
		_test_star_weighted_clear_quotes()
		_test_committed_goals_and_reset()
		_test_run_validation()
		_test_original_budget_star_boundaries()
		_test_deadline_ties_and_terminal_outcomes()
		_test_challenge_pressure()
		_test_snapshot_isolation()
		_test_fresh_store_and_recipe_reservation()
		_test_progress_replays_and_contexts()
		_test_all_99_unlocks()
		_test_pending_journal_and_recovery()
		_test_failed_host_writes()
		_test_stale_snapshots_and_races()
		_test_store_input_validation()
		_test_context_limit()
		_test_unavailable_and_malformed_saves()
		_test_native_atomic_storage()
	print("Word Jelly campaign domain: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _word(index: int, part_count: int = 1, picture: bool = true, age: int = 6,
		professional: bool = false) -> Dictionary:
	var pieces: Array[String] = []
	if part_count == 2:
		pieces.assign(["bright"])
	elif part_count == 3:
		pieces.assign(["little", "blue"])
	elif part_count == 4:
		pieces.assign(["very", "little", "blue"])
	pieces.append(NOUNS[index % NOUNS.size()])
	var text: String = " ".join(pieces)
	var id: String = "campaign:%d:%d:%d" % [age, part_count, index]
	var parts: Array[Dictionary] = []
	var nodes: Array[Dictionary] = []
	var root_id: String = "part-0"
	var surface: String = pieces[0]
	for offset in range(pieces.size()):
		var part_id: String = "part-%d" % offset
		parts.append({"id": part_id, "canonical_id": "word:" + pieces[offset],
			"type": "atomic" if part_count == 1 else "word",
			"canonical": pieces[offset], "surface": pieces[offset]})
		if offset > 0:
			surface += " " + pieces[offset]
			var node_id: String = "join-%d" % offset
			nodes.append({"id": node_id, "left": root_id, "right": part_id,
				"surface": surface, "rule": "lexical_word_boundary", "break_offsets": []})
			root_id = node_id
	var word: Dictionary = {"id": id, "text": text, "min_age": age,
		"image": "assets/images/words/cat.png" if picture else "",
		"audio": "assets/audio/words/cat.wav",
		"morphology": {"schema": 1, "id": "analysis:" + id, "lexeme_id": id,
			"text": text, "kind": "atomic" if part_count == 1 else "phrase",
			"review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
			"parts": parts, "nodes": nodes, "roots": [root_id]}}
	if professional:
		word.track = "professional"
		word.course_id = "retail"
		word.module_id = "workplace"
	return word


func _pool(count: int = 24, part_count: int = 1, picture: bool = true,
		age: int = 6, professional: bool = false) -> Array:
	var result: Array = []
	for index in range(count):
		result.append(_word(index, part_count, picture, age, professional))
	return result


func _plan(number: int = 1, challenge: bool = false) -> Dictionary:
	return _catalog.make_plan(number, _pool(), 6, 7341, challenge)


func _timed_plan(seconds: float = 90.0, quota: int = 1) -> Dictionary:
	var plan: Dictionary = _plan()
	plan.seconds = seconds
	for id: String in plan.word_ids:
		plan.goals[id] = quota
	return plan


func _pieces_required(plan: Dictionary) -> int:
	var result: int = 0
	for word: Dictionary in plan.words:
		var pieces: int = word.morphology.parts.size() + (0 if str(word.image).is_empty() else 1)
		result += pieces * int(plan.goals.get(word.id, 0))
	return result


func _finish_goals(run, prefix: String = "committed") -> void:
	var sequence: int = 0
	var goals: Dictionary = run.goals.duplicate()
	for id: String in goals:
		for occurrence in range(int(goals[id])):
			sequence += 1
			run.record_collection("%s:%d" % [prefix, sequence], id)


func _result(plan: Dictionary, outcome: String = "cleared", stars: int = 3) -> Dictionary:
	return {"kind": plan.kind, "number": plan.number, "outcome": outcome, "stars": stars,
		"time_elapsed": 12.0, "seconds_remaining": 20.0, "collection_count": 3,
		"chest_coins": 100, "completed_word_ids": plan.word_ids.duplicate()}


func _store(host: Object):
	return _store_script.new("res://.godot/unused-campaign-host.cfg", host)


func _test_all_stage_recipes() -> void:
	var pool: Array = _pool()
	var original: Array = pool.duplicate(true)
	for number in range(1, 100):
		var plan: Dictionary = _catalog.make_plan(number, pool, 6, 7200 + number)
		check(plan.get("ok", false) and str(plan.get("error", "")).is_empty(),
			"Stage %d produces an explicit successful plan" % number)
		if not plan.get("ok", false):
			continue
		var chapter: int = ceili(float(number) / 9.0)
		var profile: String = PROFILES[(number - 1) % 9]
		var base_quota: int = 1 + floori(float(chapter - 1) / 2.0)
		check(plan.kind == "main" and int(plan.number) == number and int(plan.chapter) == chapter,
			"All 99 numbered stages belong to their correct chapter")
		check(str(plan.title).contains(CHAPTERS[chapter - 1]) and str(plan.profile) == profile,
			"Each chapter keeps its authored title and nine-stage difficulty profile")
		check(plan.words.size() == mini(number + 2, 8) and plan.word_ids.size() == plan.words.size()
			and plan.goals.size() == plan.words.size(), "Targets ramp from three distinct words to the eight-word cap")
		var ids: Dictionary = {}
		var spellings: Dictionary = {}
		var raised: int = 0
		for word: Dictionary in plan.words:
			var id: String = str(word.id)
			var spelling: String = str(word.text).strip_edges().to_lower()
			check(not ids.has(id) and not spellings.has(spelling) and plan.word_ids.has(id),
				"One stage cannot ask for duplicate lexical identities or confusing duplicate spellings")
			ids[id] = true
			spellings[spelling] = true
			var quota: Variant = plan.goals.get(id)
			check(quota is int and quota >= base_quota and quota <= base_quota + 1,
				"Chapter quotas are positive whole per-word collection goals")
			if quota == base_quota + 1:
				raised += 1
		if profile in ["Build", "Mix", "Flow", "Prepare"]:
			check(raised > 0 and raised < plan.words.size(), "Pressure profiles selectively increase goals, not every word")
		elif profile == "Finale":
			check(raised == plan.words.size(), "A chapter finale gives every target its explicit extra collection")
		else:
			check(raised == 0, "Discovery, practice and relief profiles retain their chapter's base quotas")
		check(is_finite(float(plan.seconds)) and float(plan.seconds) >= 90.0 and float(plan.seconds) <= 900.0
			and is_finite(float(plan.spawn_interval)) and float(plan.spawn_interval) > 0.0
			and is_finite(float(plan.fall_speed_scale)) and float(plan.fall_speed_scale) > 0.0,
			"Every stage has bounded finite time and real supply and fall parameters")
		check(plan == _catalog.make_plan(number, pool, 6, 7200 + number),
			"A fixed scope, pool and seed reproduce the complete plan")
	check(pool == original, "Recipe selection never mutates the caller's pool or word definitions")
	check(_pieces_required(_plan(99)) > _pieces_required(_plan(9)),
		"The late campaign increases overall collection effort rather than merely shrinking timers")


func _test_pool_scope_and_validation() -> void:
	var growth: Array = _pool(5)
	growth.append_array(_pool(8, 1, true, 7))
	for word: Dictionary in growth:
		word.mastered = true
	var plan: Dictionary = _catalog.make_plan(99, growth, 6, 41)
	check(plan.ok and plan.words.size() == 5 and plan.words.all(
		func(word: Dictionary) -> bool: return int(word.min_age) == 6),
		"New growth recipes use the selected age and do not exclude lifetime-mastered words")
	var professional: Dictionary = _catalog.make_plan(99, _pool(7, 1, true, 12, true), 6, 41)
	check(professional.ok and professional.words.size() == 7,
		"Professional module terms do not acquire an unrelated growth-age filter")
	var duplicate: Dictionary = _word(0).duplicate(true)
	duplicate.id = "campaign:alternate-sense"
	duplicate.morphology.lexeme_id = duplicate.id
	duplicate.morphology.id = "analysis:alternate-sense"
	var small: Array = [_word(0), _word(0), duplicate, _word(1)]
	plan = _catalog.make_plan(99, small, 6, 41)
	check(plan.ok and plan.words.size() == 2 and plan.goals.size() == 2,
		"A smaller module uses its available distinct spellings without repeating alternate senses")
	var pending: Dictionary = _word(2)
	pending.morphology.review.status = "pending"
	plan = _catalog.make_plan(1, [pending, _word(0)], 6, 41)
	check(plan.ok and plan.word_ids == [_word(0).id],
		"Pending morphology never enters playable campaign targets")
	for number: int in [0, -1, 100]:
		var rejected: Dictionary = _catalog.make_plan(number, _pool(), 6, 41)
		check(not rejected.get("ok", true) and not str(rejected.get("error", "")).is_empty(),
			"Out-of-range main stage numbers fail with an explicit error")
	for pool: Array in [[], [{}], [pending]]:
		var rejected: Dictionary = _catalog.make_plan(1, pool, 6, 41)
		check(not rejected.get("ok", true) and not str(rejected.get("error", "")).is_empty(),
			"An empty or unusable target pool cannot fabricate a successful stage")


func _test_effort_budgets_and_relief() -> void:
	for part_count: int in [1, 3, 4]:
		for picture: bool in [false, true]:
			var pool: Array = _pool(24, part_count, picture)
			for number in range(1, 100):
				var plan: Dictionary = _catalog.make_plan(number, pool, 6, 51)
				check(plan.ok, "Reviewed image/no-image morphology has a viable plan")
				if not plan.ok:
					continue
				var pieces: int = _pieces_required(plan)
				var handling: float = float(pieces) * 1.6
				var supply: float = maxf(0.0, float(pieces - 15)) / 5.0 * float(plan.spawn_interval)
				check(float(plan.seconds) >= maxf(handling, supply) + 25.0
					and float(plan.seconds) >= 90.0 and float(plan.seconds) <= 900.0,
					"Stage %d funds deliberate actions and packet supply for %d parts, picture=%s" %
					[number, part_count, picture])
			for pair: Array in [[21, 22], [24, 25], [93, 94], [96, 97]]:
				var pressure: Dictionary = _catalog.make_plan(int(pair[0]), pool, 6, 51)
				var relief: Dictionary = _catalog.make_plan(int(pair[1]), pool, 6, 51)
				var pressure_allowance: float = float(pressure.seconds) / float(_pieces_required(pressure))
				var relief_allowance: float = float(relief.seconds) / float(_pieces_required(relief))
				check(relief_allowance > pressure_allowance
					and float(relief.spawn_interval) >= float(pressure.spawn_interval),
					"Breather and reward stages provide more time per action and gentler supply after pressure")
	var atomic: Dictionary = _catalog.make_plan(99, _pool(24, 1, false), 6, 51)
	var pictured: Dictionary = _catalog.make_plan(99, _pool(24, 1, true), 6, 51)
	var complex: Dictionary = _catalog.make_plan(99, _pool(24, 4, true), 6, 51)
	check(float(pictured.seconds) > float(atomic.seconds) and float(complex.seconds) > float(pictured.seconds),
		"Late-stage timing pays for picture partners and reviewed multi-part construction")
	check(float(_plan(1).spawn_interval) >= 18.0 and float(_plan(99).spawn_interval) >= 10.0
		and float(_plan(99).spawn_interval) < float(_plan(1).spawn_interval),
		"Main supply progresses from approximately twenty seconds toward ten, not an unplayable instant drop")


func _test_exact_replay_recipes() -> void:
	var pool: Array = _pool()
	var plan: Dictionary = _catalog.make_plan(24, pool, 6, 81)
	var recipe: Dictionary = _catalog.to_recipe(plan)
	check(recipe.get("version", 0) is int and int(recipe.get("version", 0)) > 0
		and recipe.word_ids == plan.word_ids and recipe.goals == plan.goals,
		"A replay recipe is versioned and retains exact target identities and quotas")
	var encoded: String = JSON.stringify(recipe)
	check(not recipe.has("words") and not encoded.contains("assets/images/")
		and not encoded.contains("assets/audio/") and not encoded.contains('"morphology"'),
		"Persistent recipes contain identities and parameters, not transient media or full word definitions")
	var rebound_pool: Array = pool.duplicate(true)
	rebound_pool.reverse()
	for word: Dictionary in rebound_pool:
		word.min_age = 12
	var replay: Dictionary = _catalog.rebuild_plan(recipe, rebound_pool)
	check(replay.get("ok", false) and replay.word_ids == plan.word_ids and replay.goals == plan.goals
		and replay.seconds == plan.seconds and replay.spawn_interval == plan.spawn_interval
		and replay.fall_speed_scale == plan.fall_speed_scale and replay.profile == plan.profile,
		"A saved recipe rebinds its exact order and immutable difficulty even after an age change")
	var id: String = str(plan.word_ids[0])
	var missing: Array = pool.filter(func(word: Dictionary) -> bool: return str(word.id) != id)
	var rejected: Dictionary = _catalog.rebuild_plan(recipe, missing)
	check(not rejected.get("ok", true) and not str(rejected.get("error", "")).is_empty(),
		"A missing saved identity fails explicitly instead of rerolling a different target")
	for change: String in ["text", "analysis", "part_identity"]:
		var revised: Array = pool.duplicate(true)
		for word: Dictionary in revised:
			if str(word.id) == id:
				if change == "text":
					word.text = "changed spelling"
				elif change == "analysis":
					word.morphology.id = "revised-analysis"
				else:
					word.morphology.parts[0].canonical_id = "word:revised-sense"
		rejected = _catalog.rebuild_plan(recipe, revised)
		check(not rejected.get("ok", true) and not str(rejected.get("error", "")).is_empty(),
			"A revised spelling, analysis or canonical part identity cannot silently change an old replay")
	var first_goal: String = str(recipe.word_ids[0])
	var mutated: Dictionary = recipe.duplicate(true)
	mutated.goals[first_goal] = 0
	check(not _catalog.rebuild_plan(mutated, pool).get("ok", true), "A replay cannot contain a zero collection quota")
	mutated = recipe.duplicate(true)
	mutated.seconds = -1.0
	check(not _catalog.rebuild_plan(mutated, pool).get("ok", true), "A replay cannot contain an invalid deadline")
	mutated = recipe.duplicate(true)
	mutated.version = 999
	check(not _catalog.rebuild_plan(mutated, pool).get("ok", true), "Unsupported recipe versions require explicit recovery")
	recipe.goals[first_goal] = 99
	replay.words[0].text = "caller mutation"
	check(plan.goals[first_goal] != 99 and plan.words[0].text != "caller mutation"
		and pool.all(func(word: Dictionary) -> bool: return word.text != "caller mutation"),
		"Recipes, rebound words, plans and caller pools do not share mutable nested data")
	var challenge: Dictionary = _plan(0, true)
	var challenge_recipe: Dictionary = _catalog.to_recipe(challenge)
	var challenge_replay: Dictionary = _catalog.rebuild_plan(challenge_recipe, pool)
	check(challenge_replay.get("ok", false) and challenge_replay.kind == "challenge"
		and challenge_replay.word_ids == challenge.word_ids and challenge_replay.goals.is_empty()
		and float(challenge_replay.seconds) == 90.0, "Survival candidate recipes retain their ninety-second starting clock")


func _test_star_weighted_clear_quotes() -> void:
	var chest: int = 100
	var expected: Array[int] = [0, 75, 163, 250]
	for stars in range(4):
		var reward: Dictionary = _catalog.clear_reward(1, stars, chest)
		check(reward.get("ok", false) and str(reward.get("error", "")).is_empty()
			and int(reward.get("bonus", -1)) == expected[stars],
			"Stage settlement adds the rounded star-weighted bonus without rewriting the paid chest")
		check(_catalog.clear_reward(1, stars, chest) == reward and chest == 100,
			"A clear reward is an immutable deterministic quote, not a coin or receipt mutation")
	var late: Dictionary = _catalog.clear_reward(99, 3, 101)
	check(late.get("ok", false) and int(late.get("bonus", -1)) == 551,
		"Chapter eleven uses a 225-coin base and doubles only chest-plus-clear settlement")
	check(_catalog.clear_reward(0, 0, chest).get("bonus", -1) == 0,
		"An untimed challenge receives no main-stage clear bonus")
	for arguments: Array in [[-1, 1, 0], [100, 1, 0], [1, -1, 0], [1, 4, 0], [1, 1, -1]]:
		var rejected: Dictionary = _catalog.clear_reward(int(arguments[0]), int(arguments[1]), int(arguments[2]))
		check(not rejected.get("ok", true) and not str(rejected.get("error", "")).is_empty(),
			"Invalid stage, star or coin inputs cannot produce a settlement quote")


func _test_committed_goals_and_reset() -> void:
	var plan: Dictionary = _timed_plan(90.0, 2)
	var run = _run_script.new()
	check(run.configure(plan) and run.error.is_empty(), "Configure a new per-attempt goal run")
	var id: String = str(plan.word_ids[0])
	check(run.current.get(id, -1) == 0 and run.outcome.is_empty() and run.collection_count == 0,
		"Globally mastered words and replays still start every attempt with zero collections")
	check(run.record_collection("commit:first", id) and run.current[id] == 1,
		"Only the caller's successfully committed pickup advances a target once")
	var snapshot: Dictionary = run.snapshot()
	check(not run.record_collection("commit:first", id) and run.snapshot() == snapshot,
		"The same committed collection receipt cannot advance a quota twice")
	check(not run.record_collection("commit:first", str(plan.word_ids[1]))
		and run.current[str(plan.word_ids[1])] == 0,
		"A collection receipt cannot be reassigned to a second word")
	run.record_collection("commit:old-board-word", "previous-stage:word")
	check(run.current[id] == 1 and run.outcome.is_empty(), "Carried old board words do not satisfy current stage goals")
	check(run.record_collection("commit:second", id) and run.current[id] == 2,
		"The second independent committed pickup reaches its explicit quota")
	run.record_collection("commit:above-quota", id)
	check(run.current[id] == 2, "Extra successful pickups are clamped at the target quota")
	_finish_goals(run, "commit:remaining")
	check(run.outcome == "cleared" and int(run.snapshot().stars) == 3,
		"All per-word goals, rather than any lifetime mastery state, clear an attempt")
	check(run.configure(plan) and run.elapsed == 0.0 and run.remaining == 90.0
		and run.collection_count == 0 and run.current[id] == 0 and run.outcome.is_empty(),
		"Reconfiguration clears old goals, timing, final outcome and collection receipts")
	check(run.record_collection("commit:first", id) and run.current[id] == 1,
		"A receipt from an old attempt does not leak into the next attempt's receipt set")
	plan.words[0].text = "outside mutation"
	plan.goals[id] = 100
	check(run.words[0].text != "outside mutation" and run.goals[id] == 2,
		"The run owns a deep copy of its configured target definitions and quotas")


func _test_run_validation() -> void:
	var run = _run_script.new()
	check(not run.record_collection("before-configure", "word") and not run.error.is_empty(),
		"An unconfigured run cannot accept collection receipts")
	for change: Dictionary in [{"seconds": -1.0}, {"seconds": NAN}, {"spawn_interval": 0.0},
		{"fall_speed_scale": INF}, {"kind": "unknown"}, {"number": 100}]:
		var plan: Dictionary = _timed_plan()
		plan.merge(change, true)
		check(not run.configure(plan) and not run.error.is_empty(), "Invalid plan parameters fail configuration explicitly")
	var bad_goals: Dictionary = _timed_plan()
	bad_goals.goals[str(bad_goals.word_ids[0])] = -1
	check(not run.configure(bad_goals) and not run.error.is_empty(), "Negative per-word quotas cannot start an attempt")
	check(run.configure(_timed_plan()), "A valid plan can configure after a rejected one")
	for id: String in ["", " ", "bad\nreceipt", "x".repeat(513)]:
		check(not run.record_collection(id, str(run.words[0].id)) and not run.error.is_empty(),
			"Invalid committed receipt identities cannot mutate goals")
		check(not run.add_time(id) and not run.error.is_empty(),
			"Invalid paid-time receipt identities cannot extend the deadline")
	for delta: float in [-0.1, INF, NAN]:
		var before: float = run.elapsed
		run.advance(delta)
		check(run.elapsed == before and not run.error.is_empty(), "Only finite nonnegative active-play delta is consumed")
	check(not run.decide("paused") and run.outcome.is_empty() and not run.error.is_empty(),
		"Unknown terminal reasons do not freeze or clear a live attempt")
	for seconds: int in [0, -30]:
		check(not run.add_time("time:invalid", seconds) and not run.error.is_empty(),
			"An extra-time receipt needs a positive whole extension")


func _test_original_budget_star_boundaries() -> void:
	for example: Array in [[0.0, 3], [29.0, 3], [30.0, 2], [59.0, 2], [60.0, 1], [90.0, 1]]:
		var run = _run_script.new()
		check(run.configure(_timed_plan()), "Configure an original ninety-second star budget")
		run.advance(float(example[0]))
		var state: Dictionary = run.snapshot()
		check(run.stars_now() == int(example[1]) and state.stars_now == int(example[1]) and state.stars == 0,
			"The first and second exact third boundaries lower the live rating; active runs have no final stars")
	for example: Array in [[0.0, 3], [30.0, 2], [60.0, 1]]:
		var run = _run_script.new()
		run.configure(_timed_plan())
		run.advance(float(example[0]))
		_finish_goals(run)
		check(run.outcome == "cleared" and run.snapshot().stars == int(example[1]),
			"A clear freezes the rating earned against the original active-play budget")
	var run = _run_script.new()
	run.configure(_timed_plan())
	run.advance(60.0)
	check(run.add_time("purchase:first") and run.remaining == 60.0 and run.elapsed == 60.0
		and run.initial_seconds == 90.0 and run.stars_now() == 1,
		"A paid thirty seconds extends only the deadline, never elapsed time or original star thresholds")
	var before: Dictionary = run.snapshot()
	check(not run.add_time("purchase:first") and run.error.is_empty() and run.snapshot() == before,
		"A duplicate saved time purchase is a benign no-change, not another extension")
	check(run.add_time("purchase:second", 30) and run.remaining == 90.0 and run.stars_now() == 1,
		"Independent paid extensions do not restore a lost second or third star")
	run.advance(90.0)
	check(run.remaining == 0.0 and run.elapsed == 150.0 and run.outcome.is_empty(),
		"Consuming original plus paid time still leaves the exact boundary undecided")
	check(run.check_deadline() and run.outcome == "timeout" and run.snapshot().stars == 0,
		"Only the explicit post-commit deadline check decides a failed timed attempt")
	check(run.configure(_timed_plan()) and run.add_time("purchase:first"),
		"Starting another attempt clears previous paid-time receipt identities")


func _test_deadline_ties_and_terminal_outcomes() -> void:
	var plan: Dictionary = _timed_plan()
	var run = _run_script.new()
	run.configure(plan)
	run.record_collection("tie:one", str(plan.word_ids[0]))
	run.record_collection("tie:two", str(plan.word_ids[1]))
	run.advance(90.0)
	check(run.outcome.is_empty() and run.remaining == 0.0,
		"advance does not time out before an operation committed at that exact timestamp")
	check(run.record_collection("tie:final", str(plan.word_ids[2])) and run.outcome == "cleared"
		and not run.check_deadline() and run.snapshot().stars == 1,
		"A last goal committed exactly on the deadline wins the deterministic boundary tie")
	var cleared: Dictionary = run.snapshot()
	run.record_collection("tie:late-end-sweep", str(plan.word_ids[0]))
	run.advance(5.0)
	check(not run.add_time("tie:late-time") and not run.decide("blocked") and run.snapshot() == cleared,
		"A successful clear is just as immutable as a failed ending")
	for reason: String in ["timeout", "blocked", "exit"]:
		run = _run_script.new()
		run.configure(plan)
		run.record_collection(reason + ":partial", str(plan.word_ids[0]))
		check(run.decide(reason) and run.outcome == reason and run.snapshot().stars == 0,
			"Timeout, overflow and leaving each freeze a failed zero-star outcome")
		var before: Dictionary = run.snapshot()
		for id: String in plan.word_ids:
			run.record_collection(reason + ":end-sweep:" + id, id)
		run.advance(1.0)
		check(not run.add_time(reason + ":late-purchase") and not run.decide("cleared")
			and not run.check_deadline() and run.snapshot() == before,
			"An automatic ending sweep, late time purchase or delayed goal cannot resurrect a failed run")
	check(not run.decide("unknown-reason") and run.outcome == "exit",
		"Even a rejected late reason cannot replace an existing outcome")


func _test_challenge_pressure() -> void:
	var plan: Dictionary = _plan(0, true)
	check(plan.get("ok", false) and plan.kind == "challenge" and plan.number == 0
		and plan.words.size() == 16 and plan.goals.is_empty() and float(plan.seconds) == 90.0,
		"Challenge recipes contain sixteen candidates and a ninety-second starting deadline")
	var run = _run_script.new()
	check(run.configure(plan), "Configure the timed Challenge domain")
	var start: Dictionary = run.challenge_pressure()
	check(start.level == 1 and start.word_limit == 3 and is_equal_approx(float(start.spawn_interval), 20.0)
		and is_equal_approx(float(start.fall_speed_scale), 1.0) and run.words_for_pressure().size() == 3,
		"Challenge starts with three word kinds and genuinely gentle falls")
	var receipt: int = 0
	for goal: Dictionary in run.snapshot().practice:
		run.record_collection("pressure:%d" % receipt, str(goal.word_id))
		receipt += 1
		if receipt < 3:
			check(run.challenge_stage == 1, "A partial target batch cannot advance the Challenge stage")
	var next: Dictionary = run.challenge_pressure()
	check(next.level == 2 and next.word_limit == 4 and run.words_for_pressure().size() == 4
		and float(next.spawn_interval) < float(start.spawn_interval)
		and float(next.fall_speed_scale) > float(start.fall_speed_scale),
		"The complete first target batch grows active variety, actual falling speed and supply pressure")
	var before: Dictionary = run.snapshot()
	check(not run.record_collection("pressure:0", str(plan.word_ids[0])) and run.snapshot() == before,
		"A duplicate committed challenge pickup cannot raise pressure twice")
	for stage in range(2, 15):
		var stage_goals: Array = run.snapshot().practice.filter(func(goal: Dictionary) -> bool: return int(goal.stage) == stage)
		check(stage_goals.size() == mini(3 + stage - 1, 16)
			and stage_goals.all(func(goal: Dictionary) -> bool: return int(goal.required) == 1 + floori(float(stage - 1) / 2.0)),
			"Every Challenge stage owns a harder explicit batch, not a raw collection counter")
		for goal: Dictionary in stage_goals:
			for index in range(int(goal.required)):
				run.record_collection("pressure:%d" % receipt, str(goal.word_id))
				receipt += 1
		check(run.challenge_stage == stage + 1, "Only the completed full batch advances exactly one stage")
	var late: Dictionary = run.challenge_pressure()
	check(late.level == 15 and late.word_limit == 16 and run.words_for_pressure().size() == 16
		and float(late.spawn_interval) >= 3.0 and float(late.spawn_interval) < float(next.spawn_interval)
		and float(late.fall_speed_scale) <= 2.2 and float(late.fall_speed_scale) > float(next.fall_speed_scale),
		"Later Challenge stages reach bounded variety, faster supply and a safe real fall-speed ceiling")
	var state: Dictionary = run.snapshot()
	check(int(state.get("collection_count", -1)) == receipt and state.get("pressure", {}) == late
		and run.words_for_pressure() == plan.words.slice(0, 16),
		"Challenge snapshots expose committed pickups and copied pressure alongside the exact active candidate prefix")
	run.advance(5000.0)
	check(run.outcome.is_empty() and run.check_deadline() and run.outcome == "timeout" and run.remaining == 0.0
		and run.stars_now() == 0 and run.snapshot().stars == 0,
		"The timed Challenge expires without fabricating a numbered clear or any star reward")
	check(not run.add_time("challenge:purchase") and not run.error.is_empty(),
		"A timed Challenge cannot consume a paid extension")
	var small: Dictionary = _catalog.make_plan(0, _pool(2), 6, 31, true)
	check(run.configure(small) and run.words_for_pressure().size() == 2,
		"Challenge active prefixes respect a genuinely smaller current module")
	check(run.configure(plan), "Start a late-stage difficulty boundary fixture")
	run.challenge_stage = 31
	run._append_challenge_stage()
	var previous: int = 0
	for stage in range(31, 34):
		var batch: Array = run.snapshot().practice.filter(func(goal: Dictionary) -> bool: return int(goal.stage) == stage)
		check(batch.size() == 16 and int(batch[0].required) > previous,
			"Every later stage raises its real goal quota even when variety, fall speed and supply have capped")
		previous = int(batch[0].required)
		for goal: Dictionary in batch:
			for index in range(int(goal.required)):
				run.record_collection("late:%d" % receipt, str(goal.word_id))
				receipt += 1
		check(run.challenge_stage == stage + 1 and run.error.is_empty(),
			"A complete late-stage batch still advances exactly one stage")


func _test_snapshot_isolation() -> void:
	var plan: Dictionary = _timed_plan(120.0, 2)
	var run = _run_script.new()
	run.configure(plan)
	run.record_collection("snapshot:one", str(plan.word_ids[0]))
	run.advance(7.0)
	var state: Dictionary = run.snapshot()
	check(state.kind == "main" and state.number == 1 and state.chapter == plan.chapter
		and state.title == plan.title and state.profile == plan.profile and state.outcome.is_empty()
		and state.time_elapsed == 7.0 and state.seconds_remaining == 113.0 and state.seconds_total == 120.0,
		"A main snapshot names seconds explicitly and retains stage identity and original budget")
	check(state.practice.size() == 3 and state.practice[0].has_all(
		["id", "text", "image", "current", "required", "mastered"]),
		"Main practice rows expose each target's identity, presentation and per-attempt goal evidence")
	for item: Dictionary in state.practice:
		check(int(item.current) == (1 if item.id == plan.word_ids[0] else 0)
			and item.required == 2 and not item.mastered,
			"Practice mastery reflects this attempt's quota, not global word mastery")
	if state.has("remaining"):
		check(int(state.remaining) == 3, "The legacy remaining field counts unfinished goal words, never seconds")
	var pristine: Dictionary = run.snapshot()
	state.practice[0].text = "mutated"
	state.practice[0].current = 99
	state["goals"] = {"injected": 100}
	check(run.snapshot() == pristine, "Changing returned snapshot dictionaries cannot mutate the live attempt")
	run.configure(_plan(0, true))
	var candidates: Array = run.words_for_pressure()
	candidates[0].text = "mutated challenge word"
	var pressure: Dictionary = run.challenge_pressure()
	pressure.level = 999
	check(run.words_for_pressure()[0].text != "mutated challenge word" and run.challenge_pressure().level == 1,
		"Challenge candidates and pressure dictionaries are also inert copied data")


func _test_fresh_store_and_recipe_reservation() -> void:
	var host := MemoryHost.new()
	var store = _store(host)
	var plan: Dictionary = _plan()
	check(not store.ready and not store.reserve_plan("growth", plan) and not store.error.is_empty()
		and host.calls == 0, "Campaign mutations require a successfully loaded store")
	check(store.load_state() and store.ready and store.error.is_empty() and host.text == null and host.writes == 0,
		"Missing storage starts at frontier one without overwriting anything")
	check(store.highest_cleared("growth") == 0 and store.frontier("growth") == 1
		and store.available("growth", 1) and not store.available("growth", 2)
		and store.best_stars("growth", 1) == 0 and store.recipe("growth", 1).is_empty(),
		"Fresh progress exposes only stage one, with no invented recipe or best-star rating")
	check(store.reserve_plan("growth", plan) and host.writes == 1,
		"An unlocked stage durably reserves its first immutable recipe")
	var expected: Dictionary = _catalog.to_recipe(plan)
	check(store.recipe("growth", 1) == expected, "The saved recipe retains exact IDs, quotas and timing")
	var saved: String = host.text
	var writes: int = host.writes
	check(store.reserve_plan("growth", plan) and host.writes == writes and host.text == saved,
		"Reserving the same recipe again is an idempotent acknowledgement")
	var changed: Dictionary = plan.duplicate(true)
	changed.seconds = float(plan.seconds) + 30.0
	store.reserve_plan("growth", changed)
	check(store.recipe("growth", 1) == expected and host.text == saved,
		"A replay cannot reprice or replace the first recipe's original immutable parameters")
	var detached: Dictionary = store.recipe("growth", 1)
	detached.goals[str(detached.word_ids[0])] = 99
	check(store.recipe("growth", 1) == expected, "Recipe readers never receive aliases into persistent progression")
	var reloaded = _store(host)
	check(reloaded.load_state() and reloaded.recipe("growth", 1) == expected
		and reloaded.frontier("growth") == 1 and host.writes == writes,
		"Reload retains a reserved recipe without treating an unplayed stage as cleared")


func _test_progress_replays_and_contexts() -> void:
	var host := MemoryHost.new()
	var store = _store(host)
	store.load_state()
	var plan: Dictionary = _plan()
	store.reserve_plan("growth", plan)
	check(store.queue_result("growth", "round:clear-one", _result(plan, "cleared", 2))
		and store.highest_cleared("growth") == 0 and not store.available("growth", 2),
		"Journaling a swept result does not unlock anything before payout completes")
	check(store.complete_result("growth", "round:clear-one") and store.highest_cleared("growth") == 1
		and store.frontier("growth") == 2 and store.best_stars("growth", 1) == 2
		and store.available("growth", 1) and store.available("growth", 2) and not store.available("growth", 3),
		"One completed clear unlocks exactly the next contiguous stage and records its best stars")
	check(store.queue_result("growth", "round:replay-low", _result(plan, "cleared", 1))
		and store.complete_result("growth", "round:replay-low") and store.best_stars("growth", 1) == 2
		and store.highest_cleared("growth") == 1,
		"A lower-star replay neither downgrades the map rating nor unlocks another stage")
	check(store.queue_result("growth", "round:replay-high", _result(plan, "cleared", 3))
		and store.complete_result("growth", "round:replay-high") and store.best_stars("growth", 1) == 3,
		"A better replay upgrades best stars without changing the original recipe")
	var second: Dictionary = _plan(2)
	check(store.reserve_plan("growth", second)
		and store.queue_result("growth", "round:failed-two", _result(second, "blocked", 0))
		and store.complete_result("growth", "round:failed-two") and store.frontier("growth") == 2
		and store.best_stars("growth", 2) == 0, "An overflow result preserves frontier and gives no best-star clear")
	var context: String = "professional:retail:workplace"
	check(store.frontier(context) == 1 and store.highest_cleared(context) == 0
		and not store.available(context, 2) and store.best_stars(context, 1) == 0,
		"Growth and professional career/module progress are independent and never age-keyed")
	var professional: Dictionary = _catalog.make_plan(1, _pool(6, 1, false, 12, true), 6, 12)
	check(store.reserve_plan(context, professional)
		and store.queue_result(context, "round:professional", _result(professional))
		and store.complete_result(context, "round:professional") and store.frontier(context) == 2
		and store.frontier("growth") == 2 and store.recipe("growth", 1) == _catalog.to_recipe(plan),
		"A professional clear advances only its own module and cannot overwrite growth recipes")
	var reloaded = _store(host)
	check(reloaded.load_state() and reloaded.best_stars("growth", 1) == 3
		and reloaded.highest_cleared(context) == 1
		and reloaded.frontier("professional:retail:another-module") == 1,
		"Best replay ratings and isolated module frontiers survive reload together")


func _test_all_99_unlocks() -> void:
	var host := MemoryHost.new()
	var store = _store(host)
	store.load_state()
	for number in range(1, 100):
		var plan: Dictionary = _plan(number)
		var round_id: String = "round:contiguous:%d" % number
		check(store.available("growth", number) and store.reserve_plan("growth", plan)
			and store.queue_result("growth", round_id, _result(plan))
			and store.complete_result("growth", round_id)
			and store.highest_cleared("growth") == number,
			"Contiguous stage %d reserves, journals and completes before its next unlock" % number)
	check(store.frontier("growth") == 99 and store.available("growth", 99)
		and not store.available("growth", 100) and not store.available("growth", 0),
		"Clearing the final stage caps the map at ninety-nine while leaving all clears replayable")
	var reloaded = _store(host)
	check(reloaded.load_state() and reloaded.highest_cleared("growth") == 99
		and reloaded.frontier("growth") == 99 and reloaded.best_stars("growth", 99) == 3,
		"A complete campaign persists all ninety-nine recipes and ratings within supported bounds")
	var writes: int = host.writes
	check(reloaded.complete_result("growth", "round:contiguous:99") and host.writes == writes,
		"A recent completed-round receipt makes payout completion retry idempotent")


func _test_pending_journal_and_recovery() -> void:
	var host := MemoryHost.new()
	var store = _store(host)
	store.load_state()
	var plan: Dictionary = _plan()
	store.reserve_plan("growth", plan)
	var result: Dictionary = _result(plan, "cleared", 2)
	check(store.queue_result("growth", "round:pending", result)
		and store.pending("growth") == {"round_id": "round:pending", "result": result},
		"A swept result is journaled in full before the caller pays its independent wallet receipts")
	var saved: String = host.text
	var writes: int = host.writes
	check(store.queue_result("growth", "round:pending", result) and host.writes == writes and host.text == saved,
		"An identical pending result is acknowledged without a second journal write")
	var changed: Dictionary = result.duplicate(true)
	changed.stars = 3
	check(not store.queue_result("growth", "round:pending", changed) and not store.error.is_empty()
		and not store.queue_result("growth", "round:different", result) and host.text == saved,
		"A round's immutable journal cannot be repriced or replaced by another pending settlement")
	result.completed_word_ids.clear()
	var detached: Dictionary = store.pending("growth")
	detached.result.stars = 1
	check(store.pending("growth").result.stars == 2
		and not store.pending("growth").result.completed_word_ids.is_empty(),
		"Queued results and pending readers are deep copied, not mutable payout aliases")
	var recovered = _store(host)
	check(recovered.load_state() and recovered.pending("growth").round_id == "round:pending"
		and recovered.frontier("growth") == 1,
		"Reload recovers an unpaid settlement without claiming a clear or losing its round identity")
	check(not recovered.complete_result("growth", "round:unknown") and not recovered.error.is_empty()
		and recovered.pending("growth").round_id == "round:pending" and host.text == saved,
		"A stale or unknown callback cannot clear another round's pending result")
	check(recovered.complete_result("growth", "round:pending") and recovered.pending("growth").is_empty()
		and recovered.best_stars("growth", 1) == 2 and recovered.frontier("growth") == 2,
		"After payout succeeds, rating, contiguous unlock and journal removal commit atomically")
	writes = host.writes
	check(recovered.complete_result("growth", "round:pending") and host.writes == writes,
		"A completed same-round retry acknowledges its bounded recent receipt without a write")
	var challenge: Dictionary = _plan(0, true)
	var context: String = "professional:retail:workplace"
	check(recovered.queue_result(context, "round:challenge", _result(challenge, "exit", 0))
		and recovered.complete_result(context, "round:challenge") and recovered.frontier(context) == 1
		and recovered.highest_cleared(context) == 0 and recovered.best_stars(context, 1) == 0,
		"Challenge settlement clears its journal without granting a numbered unlock or star reward")
	var fractional: Dictionary = _result(challenge, "timeout", 0)
	fractional["challenge_stage"] = 6
	fractional["challenge_previous_best"] = 5
	fractional["time_elapsed"] = 91.828454666666666
	fractional["seconds_added"] = 1.828454666666666
	fractional["seconds_remaining"] = 0.0
	check(recovered.queue_result(context, "round:fractional", fractional),
		"A capped fractional goal-time extension can be journaled before settlement")
	var retry = _store(host)
	check(retry.load_state(), "Reload the actual ConfigFile representation of fractional Challenge time")
	writes = host.writes
	check(retry.queue_result(context, "round:fractional", fractional) and host.writes == writes,
		"The original retry remains identical after ConfigFile precision rounding, without a second write")
	var altered: Dictionary = fractional.duplicate(true)
	altered.collection_count = int(altered.collection_count) + 1
	check(not retry.queue_result(context, "round:fractional", altered) and not retry.error.is_empty(),
		"Storage-precision comparison never hides changed integer collection or reward data")
	check(retry.complete_result(context, "round:fractional") and retry.challenge_best_stage(context) == 6,
		"Fractional-time recovery saves the actual reached record and completes its original journal")


func _test_failed_host_writes() -> void:
	var host := MemoryHost.new()
	var store = _store(host)
	store.load_state()
	var plan: Dictionary = _plan()
	host.fail_write = true
	check(not store.reserve_plan("growth", plan) and not store.error.is_empty()
		and store.recipe("growth", 1).is_empty() and host.text == null,
		"A failed host reservation cannot announce an immutable recipe that was never saved")
	host.fail_write = false
	check(store.reserve_plan("growth", plan), "A reservation retries after host storage recovers")
	var saved: String = host.text
	host.fail_write = true
	check(not store.queue_result("growth", "round:write-retry", _result(plan))
		and store.pending("growth").is_empty() and host.text == saved,
		"A failed journal write leaves no in-memory pending result or rewritten durable state")
	host.fail_write = false
	check(store.queue_result("growth", "round:write-retry", _result(plan)), "A swept result retries its journal write")
	saved = host.text
	host.fail_write = true
	check(not store.complete_result("growth", "round:write-retry") and not store.error.is_empty()
		and store.highest_cleared("growth") == 0 and store.best_stars("growth", 1) == 0
		and not store.pending("growth").is_empty() and host.text == saved,
		"A failed completion retains the payable journal and cannot expose an unsaved unlock or rating")
	host.fail_write = false
	check(store.complete_result("growth", "round:write-retry") and store.frontier("growth") == 2,
		"Retry completes the exact saved result after the host write succeeds")
	for reply: Variant in [1, "true", null]:
		var invalid_host := MemoryHost.new()
		invalid_host.write_reply = reply
		var invalid_store = _store(invalid_host)
		invalid_store.load_state()
		check(not invalid_store.reserve_plan("growth", plan) and not invalid_store.error.is_empty()
			and invalid_host.text == null and invalid_store.recipe("growth", 1).is_empty(),
			"Only an actual true host acknowledgement commits campaign state")
	host = MemoryHost.new()
	store = _store(host)
	store.load_state()
	store.reserve_plan("growth", plan)
	host.lose_ack_once = true
	check(not store.queue_result("growth", "round:lost-ack", _result(plan))
		and store.pending("growth").is_empty(), "A lost acknowledgement cannot falsely confirm an in-memory journal")
	var recovered = _store(host)
	check(recovered.load_state() and recovered.pending("growth").round_id == "round:lost-ack"
		and recovered.complete_result("growth", "round:lost-ack"),
		"Reload discovers an actually durable journal after acknowledgement loss and safely resumes payout")


func _test_stale_snapshots_and_races() -> void:
	var host := MemoryHost.new()
	var first = _store(host)
	var stale = _store(host)
	first.load_state()
	stale.load_state()
	var plan: Dictionary = _plan()
	first.reserve_plan("growth", plan)
	var saved: String = host.text
	check(not stale.reserve_plan("professional:retail:workplace", plan) and not stale.error.is_empty()
		and stale.recipe("professional:retail:workplace", 1).is_empty() and host.text == saved,
		"A stale tab cannot replace a newer campaign with a different context's older snapshot")
	check(stale.load_state() and stale.reserve_plan("professional:retail:workplace", plan),
		"Explicit reload permits an independent context mutation without losing the newer recipe")
	saved = host.text
	check(not first.queue_result("growth", "round:stale", _result(plan)) and host.text == saved
		and first.pending("growth").is_empty(), "Even a previously valid tab must reload after another tab writes")
	first.load_state()
	var concurrent := MemoryHost.new()
	concurrent.text = host.text
	var other = _store(concurrent)
	other.load_state()
	other.reserve_plan("professional:retail:another-module", plan)
	var concurrent_text: String = concurrent.text
	host.race_text = concurrent_text
	check(not first.queue_result("growth", "round:race", _result(plan))
		and not first.error.is_empty() and first.pending("growth").is_empty() and host.text == concurrent_text,
		"The host expected-snapshot comparison catches a change occurring between read and write")
	check(first.load_state() and first.queue_result("growth", "round:race", _result(plan)),
		"An exact swept result can retry only after loading the concurrent durable state")
	saved = host.text
	host.fail_read = true
	var calls: int = host.calls
	check(not first.complete_result("growth", "round:race") and not first.error.is_empty()
		and host.calls == calls and host.text == saved and first.highest_cleared("growth") == 0,
		"Unavailable reads never look like fresh storage and cannot start a conditional completion write")
	check(not first.load_state() and not first.ready and host.text == saved,
		"A failed reload disables mutations while preserving the previous durable snapshot")
	host.fail_read = false
	check(first.load_state() and first.pending("growth").round_id == "round:race",
		"Readable storage recovers the original journal after a failed reload")
	host.text = null
	check(not first.complete_result("growth", "round:race") and host.text == null,
		"Deleted shared storage cannot be reconstructed from a stale in-memory settlement")


func _test_store_input_validation() -> void:
	var host := MemoryHost.new()
	var store = _store(host)
	store.load_state()
	var plan: Dictionary = _plan()
	for context: String in ["", "growth:6", "professional", "professional:retail",
		"professional::workplace", "professional:retail:", "growth\n", " growth", "x".repeat(513)]:
		check(not store.reserve_plan(context, plan) and not store.error.is_empty() and host.text == null,
			"Context identity must be growth or a stable professional career/module pair, never an age key")
	check(not store.reserve_plan("growth", _plan(2)) and not store.error.is_empty() and host.text == null,
		"A locked future recipe cannot be reserved or used to jump the frontier")
	check(store.reserve_plan("growth", plan), "Reserve the valid result-validation fixture")
	var saved: String = host.text
	for round_id: String in ["", " ", "bad\nround", "x".repeat(513)]:
		check(not store.queue_result("growth", round_id, _result(plan)) and not store.error.is_empty()
			and host.text == saved, "Journal round IDs are validated before a durable mutation")
	var invalid: Array = []
	for field: String in ["kind", "number", "outcome", "stars"]:
		var missing: Dictionary = _result(plan)
		missing.erase(field)
		invalid.append(missing)
	for change: Dictionary in [{"kind": "other"}, {"number": 99}, {"number": 1.5},
		{"outcome": "playing"}, {"stars": -1}, {"stars": 4}, {"stars": 2.5},
		{"outcome": "timeout", "stars": 3}, {"collection_count": -1},
		{"time_elapsed": NAN}, {"chest_coins": -1},
		{"completed_word_ids": ["bad\nid"]}, {"completed_word_ids": [{"id": "not-a-scalar"}]},
		{"words": [_word(0)]}, {"practice": [{"image": "transient://media"}]}]:
		var malformed: Dictionary = _result(plan)
		malformed.merge(change, true)
		invalid.append(malformed)
	for result: Dictionary in invalid:
		check(not store.queue_result("growth", "round:invalid", result) and not store.error.is_empty()
			and store.pending("growth").is_empty() and host.text == saved,
			"Malformed results, unearned stars, future clears and transient media cannot enter a settlement journal")
	check(not store.complete_result("growth", "round:never-queued") and not store.error.is_empty()
		and store.frontier("growth") == 1 and host.text == saved,
		"Completion cannot manufacture a result or unlock a stage without a saved journal")


func _test_context_limit() -> void:
	var host := MemoryHost.new()
	var store = _store(host)
	store.load_state()
	var plan: Dictionary = _plan()
	for index in range(256):
		check(store.reserve_plan("professional:career:module-%d" % index, plan),
			"Each valid context below the 256-context cap can reserve independently")
	var saved: String = host.text
	check(not store.reserve_plan("professional:career:module-over-limit", plan)
		and not store.error.is_empty() and host.text == saved,
		"The context count limit rejects overflow without dropping an existing module")
	var reloaded = _store(host)
	check(reloaded.load_state() and not reloaded.recipe("professional:career:module-255", 1).is_empty(),
		"The exact supported context cap remains loadable without losing the final module")


func _load_quietly(store) -> bool:
	var printing: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var loaded: bool = store.load_state()
	Engine.print_error_messages = printing
	return loaded


func _replace_nested_field(value: Variant, key: String, replacement: Variant) -> Variant:
	if value is Dictionary:
		var changed: Dictionary = value.duplicate(true)
		for field: Variant in changed:
			changed[field] = replacement if str(field) == key else _replace_nested_field(changed[field], key, replacement)
		return changed
	if value is Array:
		var changed: Array = []
		for entry: Variant in value:
			changed.append(_replace_nested_field(entry, key, replacement))
		return changed
	return value


func _rewrite_saved_field(text: String, key: String, replacement: Variant) -> String:
	if text.strip_edges().begins_with("{"):
		var value: Variant = JSON.parse_string(text)
		return JSON.stringify(_replace_nested_field(value, key, replacement))
	var config := ConfigFile.new()
	check(config.parse(text) == OK, "The generated campaign fixture can be decoded for corruption testing")
	for section: String in config.get_sections():
		for field: String in config.get_section_keys(section):
			var value: Variant = config.get_value(section, field)
			config.set_value(section, field, replacement if field == key else _replace_nested_field(value, key, replacement))
	return config.encode_to_text()


func _test_unavailable_and_malformed_saves() -> void:
	var valid_host := MemoryHost.new()
	var valid_store = _store(valid_host)
	valid_store.load_state()
	var plan: Dictionary = _plan()
	valid_store.reserve_plan("growth", plan)
	valid_store.queue_result("growth", "round:corrupt-fixture", _result(plan))
	var valid_text: String = valid_host.text
	var bad_context: String = valid_text.replace('"growth"', '"growth:6"')
	check(bad_context != valid_text, "The corruption fixture contains the saved context identity")
	var invalid: Array = [false, 42, {}, "", "not a campaign save", valid_text + " ".repeat(MAX_SAVE_BYTES + 1),
		bad_context,
		_rewrite_saved_field(valid_text, "version", 999),
		_rewrite_saved_field(valid_text, "goals", {"campaign:bad": -1}),
		_rewrite_saved_field(valid_text, "seconds", -1.0),
		_rewrite_saved_field(valid_text, "seconds", 901.0),
		_rewrite_saved_field(valid_text, "number", 100),
		_rewrite_saved_field(valid_text, "stars", 7),
		_rewrite_saved_field(valid_text, "outcome", "not-terminal"),
		_rewrite_saved_field(valid_text, "completed_word_ids", [{"image": "transient://media"}])]
	for text: Variant in invalid:
		var host := MemoryHost.new()
		host.text = text
		var store = _store(host)
		check(not _load_quietly(store) and not store.ready and not store.error.is_empty(),
			"Unsupported, corrupt, unavailable or oversized campaign storage fails visibly")
		check(not store.reserve_plan("growth", plan) and host.text == text and host.calls == 0,
			"A rejected save remains untouched instead of being silently reset to frontier one")
	var missing_methods = _store(RefCounted.new())
	check(not _load_quietly(missing_methods) and not missing_methods.ready and not missing_methods.error.is_empty(),
		"A host without campaign storage methods is unavailable, not a missing save")
	var empty_path = _store_script.new("", MemoryHost.new())
	check(not empty_path.load_state() and not empty_path.error.is_empty(), "An empty campaign path is invalid configuration")


func _test_native_atomic_storage() -> void:
	if OS.has_feature("web"):
		return
	var directory: String = "res://.godot/campaign-domain-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated native fixtures inside the project")
	var path: String = directory.path_join("campaign.cfg")
	var store = _store_script.new(path)
	var stale = _store_script.new(path)
	var plan: Dictionary = _plan()
	check(store.load_state() and stale.load_state() and not FileAccess.file_exists(path),
		"A missing native campaign is valid and does not create or overwrite a file")
	check(store.reserve_plan("growth", plan) and FileAccess.file_exists(path),
		"A native recipe reservation durably saves through atomic staging")
	var saved: String = FileAccess.get_file_as_string(path)
	check(not stale.reserve_plan("professional:retail:workplace", plan) and not stale.error.is_empty()
		and FileAccess.get_file_as_string(path) == saved,
		"Native conditional snapshots reject stale writes just like browser tabs")
	check(DirAccess.make_dir_absolute(path + ".pending") == OK, "Block native journal staging with an isolated directory")
	check(not store.queue_result("growth", "round:native", _result(plan)) and not store.error.is_empty()
		and store.pending("growth").is_empty() and FileAccess.get_file_as_string(path) == saved,
		"A failed native journal write preserves the previous durable recipe and empty pending state")
	check(DirAccess.remove_absolute(path + ".pending") == OK
		and store.queue_result("growth", "round:native", _result(plan)), "Native journaling retries after staging recovers")
	saved = FileAccess.get_file_as_string(path)
	check(DirAccess.make_dir_absolute(path + ".pending") == OK, "Block native completion staging")
	check(not store.complete_result("growth", "round:native") and store.highest_cleared("growth") == 0
		and not store.pending("growth").is_empty() and FileAccess.get_file_as_string(path) == saved,
		"Failed native completion cannot remove the payable journal or publish an unsaved unlock")
	check(DirAccess.remove_absolute(path + ".pending") == OK, "Restore native completion staging")
	check(DirAccess.rename_absolute(path, path + ".previous") == OK,
		"Simulate interruption between preserving the previous campaign and installing a replacement")
	var recovered = _store_script.new(path)
	check(recovered.load_state() and recovered.pending("growth").round_id == "round:native"
		and recovered.highest_cleared("growth") == 0 and FileAccess.file_exists(path),
		"Native recovery restores the previously committed pending settlement instead of resetting progress")
	check(recovered.complete_result("growth", "round:native") and recovered.frontier("growth") == 2
		and recovered.pending("growth").is_empty(), "Recovered native settlement completes once after payout")
	var reloaded = _store_script.new(path)
	check(reloaded.load_state() and reloaded.best_stars("growth", 1) == 3
		and reloaded.complete_result("growth", "round:native"), "Native unlock, best stars and completion receipt reload together")
	check(not FileAccess.file_exists(path + ".pending") and not FileAccess.file_exists(path + ".previous"),
		"Successful native atomic commits leave no transient staging or backup files")
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	check(corrupt != null, "Open the isolated native corruption fixture")
	if corrupt != null:
		corrupt.store_string("corrupt campaign")
		corrupt.close()
	check(not recovered.reserve_plan("growth", _plan(2)) and FileAccess.get_file_as_string(path) == "corrupt campaign",
		"A stale native snapshot cannot overwrite newly corrupted data")
	check(not _load_quietly(reloaded) and not reloaded.ready and not reloaded.error.is_empty(),
		"Native corruption disables progress rather than silently resetting it")
	check(DirAccess.remove_absolute(path) == OK and DirAccess.make_dir_absolute(path) == OK,
		"Create an unavailable native save-path fixture")
	var unreadable = _store_script.new(path)
	check(not _load_quietly(unreadable) and not unreadable.error.is_empty(),
		"A directory at the save path is unavailable storage, not an absent campaign")
	check(DirAccess.remove_absolute(path) == OK, "Remove the isolated unreadable save-path directory")
	for suffix: String in [".pending", ".previous"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	check(DirAccess.remove_absolute(directory) == OK, "Remove the isolated native campaign fixture directory")
