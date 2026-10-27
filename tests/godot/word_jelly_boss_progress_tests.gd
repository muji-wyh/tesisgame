extends SceneTree

const Store = preload("res://scripts/word_jelly_campaign_store.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
var checks: int = 0
var failures: int = 0
var words: Array = []


class Host extends RefCounted:
	var text: Variant = null
	var writable: bool = true

	func jellyCampaignState() -> Variant:
		return text

	func saveJellyCampaignState(next: String, expected: Variant) -> bool:
		if not writable or expected != text:
			return false
		text = next
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var data := Data.new()
	check(data.load_all(), "Boss progress uses the original reviewed recipe identities")
	words = data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == 3) \
		.map(func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	var legacy: Dictionary = {"highest_cleared": 8, "recipes": {}, "ratings": {}, "pending": {}, "completed": []}
	for number in range(1, 9):
		legacy.recipes[str(number)] = Catalog.to_recipe(Catalog.make_plan(number, words, 3, 71))
		legacy.ratings[str(number)] = 3
	var config := ConfigFile.new()
	config.set_value("campaign", "version", 1)
	config.set_value("campaign", "contexts", {"growth": legacy})
	var host := Host.new()
	host.text = config.encode_to_text()
	var previous: String = host.text
	var store := Store.new("user://boss-progress.cfg", host)
	check(store.load_state() and store.highest_cleared("growth") == 8 and store.best_stars("growth", 8) == 3,
		"Version-one saves migrate without resetting cleared stages, frozen recipes or best stars")
	check(host.text == previous and store.merged_level("growth") == 1,
		"Reading a legacy save neither invents historical Boss victories nor rewrites it silently")
	var plan: Dictionary = Catalog.make_plan(9, words, 3, 71)
	check(store.reserve_plan("growth", plan), "Reserve the existing frontier's exact first Boss recipe")
	var win: Dictionary = {"kind": "main", "number": 9, "outcome": "cleared", "stars": 3,
		"boss_id": 1, "boss_victory": true, "boss_outcome": "defeated"}
	check(store.queue_result("growth", "boss:first", win), "Journal the real first Boss victory before granting its unlock")
	host.writable = false
	check(not store.complete_result("growth", "boss:first") and store.merged_level("growth") == 1
		and not store.pending("growth").is_empty(),
		"An unsaved completion retains its journal and cannot unlock Lv2 early")
	host.writable = true
	check(store.complete_result("growth", "boss:first") and store.merged_level("growth") == 2
		and store.boss_victories("growth") == [1] and store.highest_cleared("growth") == 9,
		"Successful durable completion advances the stage and unlocks exactly Lv2 together")
	check(store.complete_result("growth", "boss:first") and store.merged_level("growth") == 2,
		"A replayed completion callback cannot grant the same unlock twice")
	check(store.queue_result("growth", "boss:replay", win) and store.complete_result("growth", "boss:replay")
		and store.merged_level("growth") == 2,
		"Replaying and defeating an already-beaten Boss never farms additional levels")
	check(store.merged_level("professional:retail:module01") == 1,
		"A different vocabulary journey does not borrow a Boss victory it never earned")
	var restored := Store.new("user://boss-progress.cfg", host)
	check(restored.load_state() and restored.merged_level("growth") == 2
		and restored.boss_victories("growth") == [1],
		"Reload restores the durable first-victory unlock")
	var invalid: Dictionary = win.duplicate()
	invalid.boss_id = 2
	check(not restored.queue_result("growth", "boss:wrong-identity", invalid),
		"A stage-nine result cannot claim a different Boss unlock")
	check(restored.challenge_best_stage("growth") == 0,
		"Reading a legacy campaign does not invent a historical Challenge score")
	check(restored.record_challenge_stage("growth", 5) and restored.record_challenge_stage("growth", 2)
		and restored.challenge_best_stage("growth") == 5 and restored.highest_cleared("growth") == 9
		and restored.boss_victories("growth") == [1],
		"A best-stage record only increases and cannot change numbered clears or Boss-earned levels")
	host.writable = false
	check(not restored.record_challenge_stage("growth", 7) and restored.challenge_best_stage("growth") == 5,
		"An unsaved score cannot pretend the new best was persisted")
	host.writable = true
	check(restored.record_challenge_stage("growth", 7), "The original new best can retry after storage recovers")
	var score_reload := Store.new("user://boss-progress.cfg", host)
	check(score_reload.load_state() and score_reload.challenge_best_stage("growth") == 7
		and score_reload.challenge_best_stage("professional:retail:module01") == 0,
		"Best stages survive reload and remain isolated by learning route")
	for frontier in range(1, 100):
		var markers: Array[int] = BossCatalog.map_markers(frontier)
		var future: int = 0
		for number: int in markers:
			if number > frontier:
				future += 1
		check(future <= 1, "The map cannot reveal every future Boss at frontier %d" % frontier)
		for number: int in BossCatalog.STAGES:
			if number <= frontier:
				check(number in markers, "Every unlocked Boss remains marked for replay")
	print("Jelly Boss progress: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
