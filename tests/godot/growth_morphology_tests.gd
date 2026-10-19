extends SceneTree

const Growth = preload("res://scripts/growth_morphology.gd")
const Analysis = preload("res://scripts/morphology_analysis.gd")
const Resolver = preload("res://scripts/morphology_resolver.gd")
const Content = preload("res://scripts/learning_content_resolver.gd")
const Context = preload("res://scripts/learning_context.gd")
const GrowthState = preload("res://scripts/growth_state.gd")
var checks: int = 0
var failures: int = 0
var words: Array = []
var entries: Dictionary = {}
var sources: Dictionary = {}



class BreakFamilySaveStore extends RefCounted:
	var text: String = ""
	var writes: int = 0

	func growthState() -> String:
		return text

	func saveGrowthState(value: String, expected_text: Variant) -> bool:
		writes += 1
		if text != expected_text:
			return false
		text = value
		return true



func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _read(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _word(id: String) -> Dictionary:
	for word: Dictionary in words:
		if word.id == id:
			return word.duplicate(true)
	return {}


func _run() -> void:
	words = _read("res://words.json")
	var index: Dictionary = _read("res://data/vocabulary/morphology/index.json")
	sources = index.sources
	for age in range(3, 13):
		for entry: Dictionary in _read("res://data/vocabulary/morphology/age-%02d.json" % age).entries:
			entries[entry.id] = entry
	_test_inventory(index)
	_test_review_guard()
	_test_authored_composition()
	_test_multi_stage_composition()
	_test_shared_catalog_composition()
	_test_bound_family_review_resolution()
	_test_break_sense_boundaries()
	_test_break_family_save_identity()
	_test_isolation()
	print("Growth morphology: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_inventory(index: Dictionary) -> void:
	var reviewed: int = 0
	var pending: int = 0
	var context_only: int = 0
	check(words.size() == 1550 and entries.size() == 1550, "All 1,550 original Growth identities have separate review states")
	for word: Dictionary in words:
		var before: Dictionary = word.duplicate(true)
		var decorated: Dictionary = Growth.decorate(word)
		check(word == before, "Decorating does not mutate source: " + str(word.id))
		for key: String in word:
			check(decorated[key] == word[key], "Original media, eligibility and vocabulary fields survive: %s/%s" % [word.id, key])
		if str(word.get("image", "")).is_empty():
			context_only += 1
			check(str(decorated.get("image", "")).is_empty(), "Context-only media remains honestly absent: " + str(word.id))
		if entries[word.id].review.status == "reviewed":
			reviewed += 1
			check(decorated.morphology_status == "reviewed" and Analysis.compile(decorated.get("morphology")).ok,
				"Reviewed authored graph compiles: " + str(word.id))
		else:
			pending += 1
			check(decorated.morphology_status == "pending" and not decorated.has("morphology") and not decorated.morphology_notice.is_empty(),
				"Pending entries cannot fabricate graph data: " + str(word.id))
	var expected_reviewed: int = 0
	for age: Dictionary in index.ages.values():
		expected_reviewed += int(age.reviewed)
	check(reviewed == expected_reviewed and reviewed + pending == 1550, "Runtime review coverage matches the audited index")
	check(context_only == 265, "All 265 original context-only entries retain their image gaps")


func _test_review_guard() -> void:
	var word: Dictionary = _word("cat")
	var entry: Dictionary = entries.cat.duplicate(true)
	for field: String in ["text", "meaning", "part_of_speech", "min_age"]:
		var changed: Dictionary = word.duplicate(true)
		changed[field] = 4 if field == "min_age" else "changed"
		var result: Dictionary = Growth.from_entry(changed, entry, sources)
		check(result.morphology_status == "invalid" and not result.has("morphology"), "Changed vocabulary identity or sense rejects stale review: " + field)
	for field: String in ["reviewer", "date", "method", "rationale", "references"]:
		var changed: Dictionary = entry.duplicate(true)
		changed.review.erase(field)
		check(Growth.from_entry(word, changed, sources).morphology_status == "invalid", "Incomplete review rejected: " + field)
	for field: String in ["author", "consulted", "evidence"]:
		var changed_sources: Dictionary = sources.duplicate(true)
		changed_sources[entry.review.references[0]].erase(field)
		check(Growth.from_entry(word, entry, changed_sources).morphology_status == "invalid", "Incomplete consulted source rejected: " + field)
	var changed: Dictionary = entry.duplicate(true)
	changed.review.date = "unrecorded"
	check(Growth.from_entry(word, changed, sources).morphology_status == "invalid", "Review date must retain its recorded ISO date shape")
	changed = entry.duplicate(true)
	changed.review.references = ["unconsulted-source"]
	check(Growth.from_entry(word, changed, sources).morphology_status == "invalid", "Unregistered source reference rejected")
	changed = entry.duplicate(true)
	changed.erase("analysis")
	check(Growth.from_entry(word, changed, sources).morphology_status == "invalid", "Reviewed label alone never invents atomic content")
	word.morphology = entries.rainbow.analysis.duplicate(true)
	changed.review = {"status": "pending", "reason": "A fresh individual review is required."}
	var pending: Dictionary = Growth.from_entry(word, changed, sources)
	check(pending.morphology_status == "pending" and not pending.has("morphology"), "Pending review discards even candidate-supplied graphs")
	check(not Growth.from_entry(word, {}, sources).has("morphology"), "Missing overlay cannot inherit a candidate graph")
	check(Growth.decorate({"id": "cat", "min_age": 99}).morphology_status == "invalid", "Unknown cohorts cannot be treated as reviewed")
	word = _word("rainbow")
	changed = entries.rainbow.duplicate(true)
	changed.analysis.nodes[0].left = "whole"
	check(Growth.from_entry(word, changed, sources).morphology_status == "invalid", "A cyclic graph cannot enter a round")
	changed = entries.rainbow.duplicate(true)
	changed.analysis.parts.reverse()
	check(Growth.from_entry(word, changed, sources).morphology_status == "invalid", "Reordered authored components are rejected")


func _test_authored_composition() -> void:
	for id: String in ["rainbow", "classroom", "notebook", "playground", "afternoon", "inside", "outside", "breakfast", "angry", "thirsty", "dirty", "cloudy", "friendly", "closed", "peas", "stairs", "has", "triangle", "dinosaur"]:
		var decorated: Dictionary = Growth.decorate(_word(id))
		var resolver := Resolver.new()
		check(resolver.configure([decorated.morphology]), "Authored production analysis configures: " + id)
		var tiles: Array = resolver.source_tiles(decorated.morphology.id)
		check(tiles.size() == 2, "Individually reviewed two-part construction: " + id)
		if tiles.size() == 2:
			var result: Dictionary = resolver.resolve(tiles[0], tiles[1])
			check(result.status == "complete" and result.tile.text == _word(id).text, "The exact authored word completes: " + id)
	var cat: Dictionary = Growth.decorate(_word("cat"))
	var resolver := Resolver.new()
	check(resolver.configure([cat.morphology]), "A whole form remains available as exposure")
	var tile: Dictionary = resolver.source_tiles(cat.morphology.id)[0]
	check(tile.complete and not tile.mastery_eligible and tile.text == "cat", "Atomic exposure cannot grant composition mastery")
	check(Growth.decorate(_word("breakfast")).morphology.parts[1].canonical_id == "growth.part.fast.abstention", "Breakfast never borrows the unrelated speed-adjective sense")
	check(Growth.decorate(_word("friendly")).morphology.parts[1].canonical_id == "english.affix.ly.adjective", "Adjectival -ly has a distinct canonical identity")


func _test_multi_stage_composition() -> void:
	for fixture: Array in [["hairdryer", "dryer", 1], ["earrings", "earring", 0], ["sometimes", "sometime", 0], ["slippers", "slipper", 0], ["earmuffs", "earmuff", 0], ["screwdriver", "driver", 1], ["lawnmower", "mower", 1], ["dishwasher", "washer", 1], ["headphones", "headphone", 0], ["woodpecker", "pecker", 1], ["anteater", "eater", 1], ["caretaker", "taker", 1], ["binoculars", "binocular", 0], ["photocopier", "copier", 1]]:
		var id: String = fixture[0]
		var first: int = fixture[2]
		var decorated: Dictionary = Growth.decorate(_word(id))
		var resolver := Resolver.new()
		check(resolver.configure([decorated.morphology]), "Three-part production graph configures: " + id)
		var tiles: Array = resolver.source_tiles(decorated.morphology.id)
		check(tiles.size() == 3, "Three meaningful source parts: " + id)
		if tiles.size() != 3:
			continue
		check(resolver.resolve(tiles[0], tiles[2]).status == "invalid", "Nonadjacent parts cannot bypass the authored graph: " + id)
		var partial: Dictionary = resolver.resolve(tiles[first], tiles[first + 1])
		check(partial.status == "partial" and partial.tile.text == fixture[1], "The meaningful intermediate is built first: " + id)
		check(not partial.tile.mastery_eligible, "An intermediate cannot grant word mastery: " + id)
		var complete: Dictionary = resolver.resolve(tiles[0], partial.tile) if first == 1 else resolver.resolve(partial.tile, tiles[2])
		check(complete.status == "complete" and complete.tile.text == id and complete.tile.lexeme_id == id, "The manual path reaches the exact original identity: " + id)
		check(complete.tile.mastery_eligible, "Only the completed manual term may grant composition mastery: " + id)
		var plan: Dictionary = resolver.completion_plan(tiles)
		check(plan.status == "complete" and plan.steps.size() == 2 and plan.tile.text == id, "Automatic planning uses the same two authored joins: " + id)
		tiles[first].assisted = true
		partial = resolver.resolve(tiles[first], tiles[first + 1])
		complete = resolver.resolve(tiles[0], partial.tile) if first == 1 else resolver.resolve(partial.tile, tiles[2])
		check(complete.tile.assisted and not complete.tile.mastery_eligible, "Assistance survives both joins without mastery credit: " + id)


func _test_shared_catalog_composition() -> void:
	var authored: Array = []
	for word: Dictionary in words:
		var decorated: Dictionary = Growth.decorate(word)
		if decorated.has("morphology"):
			authored.append(decorated.morphology)
	var resolver := Resolver.new()
	check(resolver.configure(authored), "All reviewed cohorts coexist in one canonical resolver")
	for analysis: Dictionary in authored:
		if analysis.kind == "atomic":
			continue
		var states: Dictionary = {}
		var tiles: Array = resolver.source_tiles(analysis.id)
		for index in range(tiles.size()):
			states[analysis.parts[index].id] = tiles[index]
		var remaining: Array = analysis.nodes.duplicate(true)
		while not remaining.is_empty():
			var applied: bool = false
			for index in range(remaining.size()):
				var node: Dictionary = remaining[index]
				if not states.has(node.left) or not states.has(node.right):
					continue
				var result: Dictionary = resolver.resolve(states[node.left], states[node.right])
				check(result.status in ["partial", "complete"] and result.tile.get("text") == node.surface, "Catalog-wide canonical joins retain exact authored output: %s/%s" % [analysis.lexeme_id, node.id])
				if result.status in ["partial", "complete"]:
					states[node.id] = result.tile
				remaining.remove_at(index)
				applied = true
				break
			if not applied:
				check(false, "Every production join is reachable: " + str(analysis.lexeme_id))
				break
		for root: String in analysis.roots:
			var complete: Dictionary = states.get(root, {})
			check(complete.get("complete", false) and complete.get("lexeme_id") == analysis.lexeme_id, "Shared components cannot change a completed word's identity: " + str(analysis.lexeme_id))


func _test_bound_family_review_resolution() -> void:
	for id: String in ["compare", "investigate", "suggest", "explore", "separate", "multiply", "divide", "estimate", "retire"]:
		var word: Dictionary = _word(id)
		var age: int = int(word.min_age)
		var decorated: Dictionary = Growth.decorate(word)
		var resolver := Resolver.new()
		check(decorated.morphology_status == "reviewed" and resolver.configure([decorated.morphology]),
			"Each individually resolved historical family configures: " + id)
		var tiles: Array = resolver.source_tiles(decorated.morphology.id)
		if id == "explore":
			check(tiles.size() == 1 and tiles[0].complete and not tiles[0].mastery_eligible,
				"The reviewed whole explore stem remains exposure without composition mastery")
		else:
			var plan: Dictionary = resolver.completion_plan(tiles)
			check(plan.status == "complete" and plan.tile.text == word.text and plan.tile.lexeme_id == id,
				"Authored boundaries reach only the exact complete word: " + id)
			if tiles.size() == 3:
				check(resolver.resolve(tiles[0], tiles[2]).status == "invalid",
					"A suffix cannot skip the bound root: " + id)
		var withdrawn: Dictionary = entries[id].duplicate(true)
		withdrawn.review = {"status": "pending", "reason": "Regression fixture: reopen this individual review."}
		withdrawn.erase("analysis")
		check(not Growth.from_entry(decorated, withdrawn, sources).has("morphology"),
			"A later withdrawal still discards even candidate-supplied graphs: " + id)
		var phrase: Dictionary = Content.resolve_growth(Context.growth(age, "phrase"), [word], [id])
		check(phrase.ok and phrase.words[0] == word,
			"Review resolution preserves original contextual word and media: " + id)
		var composition: Dictionary = Content.resolve_growth(Context.growth(age, "word_jelly"), [word])
		check(composition.ok == (id in ["separate", "multiply", "divide", "retire"]),
			"Resolved reviews retain the original image eligibility: " + id)
	for id: String in ["attract", "connect", "include", "receive", "reflect", "adapt"]:
		var word: Dictionary = _word(id)
		var eligible: Dictionary = Content.resolve_growth(Context.growth(int(word.min_age), "word_jelly"), [word])
		check(eligible.ok == (id in ["attract", "receive"]),
			"Corrected graphs retain the original image eligibility: " + id)
	for age in range(3, 13):
		check(Content.resolve_growth(Context.growth(age, "word_jelly"), words).ok,
			"Every Growth age retains a playable composition pool: %d" % age)


func _test_isolation() -> void:
	var word: Dictionary = _word("cat")
	var result: Dictionary = Growth.decorate(word)
	result.morphology.parts[0].surface = "corrupted"
	result.morphology.review.references.clear()
	result.image = "invented.png"
	check(Growth.decorate(word).morphology.parts[0].surface == "cat", "Returned graphs cannot corrupt cached cohort metadata")
	check(Growth.decorate(word).image == word.image and not Growth.decorate(word).morphology.review.references.is_empty(), "Original media and review evidence are isolated")
	var entry: Dictionary = entries.cat.duplicate(true)
	result = Growth.from_entry(word, entry, sources)
	entry.analysis.parts[0].surface = "changed later"
	check(result.morphology.parts[0].surface == "cat", "Caller mutation cannot change an already decorated word")
	Growth.clear_cache()
	check(Growth.decorate(word).morphology_status == "reviewed", "The lazy loader survives explicit cache reset")


func _test_break_sense_boundaries() -> void:
	var meal: Dictionary = Growth.decorate(_word("breakfast"))
	var damage: Dictionary = Growth.decorate(_word("broken"))
	var resolver := Resolver.new()
	var configured: bool = resolver.configure([meal.morphology, damage.morphology])
	check(configured, "The current meal and damage graphs coexist in one resolver")
	if not configured:
		return
	var meal_tiles: Array = resolver.source_tiles(meal.morphology.id)
	var damage_tiles: Array = resolver.source_tiles(damage.morphology.id)
	check(meal_tiles.size() == 2 and damage_tiles.size() == 2, "Both complete break inputs retain their two-part graphs")
	if meal_tiles.size() != 2 or damage_tiles.size() != 2:
		return
	check(meal_tiles[0].text == "break" and damage_tiles[0].text == "break",
		"The distinct meanings keep identical readable input spellings")
	check(Analysis.part_signature(meal.morphology.parts[0]) != Analysis.part_signature(damage.morphology.parts[0]),
		"Ending a fast is not the same canonical part as damaging an object")
	for mixed: Array in [[meal_tiles[0], damage_tiles[1]], [damage_tiles[0], meal_tiles[1]]]:
		var result: Dictionary = resolver.resolve(mixed[0], mixed[1])
		check(result.status == "invalid" and result.tile.is_empty(),
			"A break from the other meaning cannot complete or receive mastery")
		check(resolver.compatible_pairs(mixed).is_empty(),
			"Compatibility hints do not suggest the wrong-sense break")
		var plan: Dictionary = resolver.completion_plan(mixed)
		check(plan.status == "unavailable" and plan.steps.is_empty(),
			"Automatic planning cannot use a wrong-sense break")
	for graph: Dictionary in [meal.morphology, damage.morphology]:
		var first: Array = resolver.source_tiles(graph.id)
		var second: Array = resolver.source_tiles(graph.id)
		first[0].origins[0].supply_group = 11
		second[1].origins[0].supply_group = 22
		first[0].fragments = 1
		second[1].fragments = 2
		var joined: Dictionary = resolver.resolve(first[0], second[1])
		check(joined.status == "complete", "Same-sense parts still compose across supply groups: " + graph.lexeme_id)
		if joined.status != "complete":
			continue
		check(joined.tile.text == graph.text and joined.tile.lexeme_id == graph.lexeme_id and joined.tile.mastery_eligible,
			"An unassisted valid join keeps the original word identity: " + graph.lexeme_id)
		check(joined.tile.fragments == 3 and joined.tile.origins.size() == 2
			and joined.tile.origins[0].supply_group == 11 and joined.tile.origins[1].supply_group == 22,
			"Valid sharing conserves fragments and both source groups: " + graph.lexeme_id)
		first[0].assisted = true
		check(not resolver.resolve(first[0], second[1]).tile.mastery_eligible,
			"Canonical correction does not grant mastery to assisted composition")
		var equivalent: Dictionary = graph.parts[0].duplicate(true)
		equivalent.id = "another-occurrence"
		equivalent.type = "stem" if equivalent.type == "compound" else "compound"
		equivalent.supply_group = 99
		check(Analysis.part_signature(equivalent) == Analysis.part_signature(graph.parts[0]),
			"Occurrence and contextual role remain irrelevant to same-sense identity")
	# A controlled alias mutation establishes that the negative cases depend on
	# selected canonical meaning, not merely the compound-versus-stem role.
	var aliased_meal: Dictionary = meal.morphology.duplicate(true)
	var aliased_damage: Dictionary = damage.morphology.duplicate(true)
	aliased_meal.parts[0].canonical_id = "growth.break"
	aliased_damage.parts[0].canonical_id = "growth.break"
	var alias_resolver := Resolver.new()
	var alias_configured: bool = alias_resolver.configure([aliased_meal, aliased_damage])
	check(alias_configured, "The controlled old-ID alias fixture is structurally valid")
	if alias_configured:
		var meal_alias: Array = alias_resolver.source_tiles(aliased_meal.id)
		var damage_alias: Array = alias_resolver.source_tiles(aliased_damage.id)
		check(alias_resolver.resolve(meal_alias[0], damage_alias[1]).status == "complete"
			and alias_resolver.resolve(damage_alias[0], meal_alias[1]).status == "complete",
			"The alias control demonstrates sensitivity to conflating the two meanings")


func _test_break_family_save_identity() -> void:
	var saved := ConfigFile.new()
	saved.set_value("growth", "version", GrowthState.VERSION)
	saved.set_value("growth", "level", 1)
	saved.set_value("growth", "age", 7)
	saved.set_value("growth", "streaks", {"breakfast": 3, "broken": 2})
	saved.set_value("growth", "mastered_words", ["breakfast"])
	saved.set_value("growth", "receipts", ["break-family-preserved-receipt"])
	var storage := BreakFamilySaveStore.new()
	storage.text = saved.encode_to_text()
	var original_text: String = storage.text
	var before := GrowthState.new("user://unused-break-family-test.cfg", storage)
	var before_ready: bool = before.configure(words) and before.load_state()
	check(before_ready, "Existing word-keyed Growth history loads against the original inventory")
	if not before_ready:
		return
	var decorated_words: Array = []
	var identities_preserved: bool = true
	for word: Dictionary in words:
		var decorated: Dictionary = Growth.decorate(word)
		identities_preserved = identities_preserved and decorated.id == word.id and decorated.min_age == word.min_age
		decorated_words.append(decorated)
	check(identities_preserved and decorated_words.size() == 1550, "All original Growth word IDs and ages survive the morphology overlay")
	var after := GrowthState.new("user://unused-break-family-test.cfg", storage)
	var after_ready: bool = after.configure(decorated_words) and after.load_state()
	check(after_ready, "The same saved history loads after decorating the full inventory")
	if not after_ready:
		return
	check(before.streak("breakfast") == 3 and after.streak("breakfast") == 3
		and before.streak("broken") == 2 and after.streak("broken") == 2,
		"Both original word-keyed streaks remain unchanged")
	check(after.is_mastered("breakfast") and not after.is_mastered("broken")
		and after.level == before.level and after.age == before.age
		and after.snapshot().lifetime_mastered == before.snapshot().lifetime_mastered,
		"Earned Growth history and current mastery do not transfer between component identities")
	check(storage.writes == 0 and storage.text == original_text,
		"Reading the narrowed component identities neither migrates nor rewrites saved Growth data")

