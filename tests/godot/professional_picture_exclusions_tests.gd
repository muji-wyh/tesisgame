extends SceneTree

const Context = preload("res://scripts/learning_context.gd")
const Resolver = preload("res://scripts/learning_content_resolver.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_round_cases()
	_minimum_cases()
	_per_sense_cases()
	_large_pool_cases()
	_color_bound_cases()
	print("Professional picture exclusions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _fixture() -> Dictionary:
	# Synthetic eligibility metadata; these are not acquired media or lessons.
	var media: Dictionary = {"status": "integrated", "path": "res://fixture.png", "sha256": "a".repeat(64),
		"source": "fixture", "creator": "fixture", "license": "fixture", "review": {"status": "reviewed"}, "picture_suitable": true}
	var review: Dictionary = {"status": "reviewed", "language": "reviewed", "domain": "not_required"}
	var ids: Array = []
	var words: Dictionary = {}
	for index in range(50):
		var id: String = "fixture%d" % index
		ids.append(id)
		words[id] = {"id": id, "text": id, "pos": "noun", "definition": "A synthetic test sense.",
			"example": "Fixture only.", "difficulty": "A2", "review": review.duplicate(true),
			"practice_modes": ["match", "memory", "jelly", "pop", "word_jelly", "phrase"],
			"media": {"image": media.duplicate(true), "audio": media.duplicate(true)},
			"morphology": {"schema": 1, "id": id + ".analysis", "lexeme_id": id, "text": id,
				"kind": "atomic", "review": {"status": "reviewed"}, "nodes": [], "roots": ["whole"],
				"parts": [{"id": "whole", "canonical_id": id, "type": "atomic", "canonical": id, "surface": id}]}}
	var expressions: Dictionary = {}
	var expression_ids: Array = []
	for index in range(10):
		var id: String = "expression%d" % index
		expression_ids.append(id)
		var focus: Array = ids.slice(index * 5, index * 5 + 5)
		var sentence: String = " ".join(focus)
		var tokens: Array = []
		var start: int = 0
		for token in focus:
			tokens.append({"index": tokens.size(), "text": token, "start": start, "end": start + token.length()})
			start += token.length() + 1
		expressions[id] = {"id": id, "text": sentence, "tokens": tokens, "focus_lexeme_ids": focus,
			"review": review.duplicate(true), "media": {"audio": media.duplicate(true)}}
	var course: Dictionary = {"id": "retail", "curriculum_revision": "fixture-v1", "theme_id": "retail_store",
		"modules": [{"id": "module03", "status": "ready", "lexeme_ids": ids, "expression_ids": expression_ids}]}
	return {"words": words, "expressions": expressions, "course": course}


func _resolve(fixture: Dictionary, mode: String, seed_value: int = 7) -> Dictionary:
	return Resolver.resolve_professional(Context.professional("retail", "module03", "fixture-v1", mode),
		fixture.course, fixture.words, fixture.expressions, seed_value)


func _round_cases() -> void:
	var fixture: Dictionary = _fixture()
	check(_resolve(fixture, "match").words.size() == 50, "Older content without exclusions retains its full pool")
	fixture.words.fixture0.media.image.confusable_with = ["fixture1"]
	var original: Dictionary = fixture.duplicate(true)
	var seen: Dictionary = {}
	for seed_value in range(24):
		for mode in ["match", "memory", "jelly", "pop"]:
			var result: Dictionary = _resolve(fixture, mode, seed_value)
			check(result.ok, "A valid image pool resolves")
			if not result.ok:
				continue
			var ids: Array = result.words.map(func(word: Dictionary) -> String: return word.id)
			check(ids.size() == 49 and ids.has("fixture0") != ids.has("fixture1"), "One-sided exclusions work in either shuffled order")
			check(result.module_words.size() == 50 and result.requirements.terms.size() == 50, "Round filtering preserves library and completion requirements")
			seen["fixture0" if ids.has("fixture0") else "fixture1"] = true
	check(seen.size() == 2, "Either meaning can appear in a later seeded round")
	check(_resolve(fixture, "match", 42).words == _resolve(fixture, "match", 42).words, "Replay selection stays deterministic")
	for mode in ["word_jelly", "phrase"]:
		check(_resolve(fixture, mode).words.size() == 50, "Context and morphology games retain both meanings")
	check(fixture == original, "Selection does not mutate shared source metadata")
	fixture.words.fixture2.media.image.picture_suitable = false
	check(_resolve(fixture, "pop").words.size() == 48, "Speaking prompts also honor picture suitability")
	for invalid in ["fixture1", ["fixture0"], ["fixture1", "fixture1"], [42]]:
		fixture.words.fixture0.media.image.confusable_with = invalid
		check(not _resolve(fixture, "match").ok, "Malformed exclusion metadata fails closed")
	fixture = _fixture()
	for index in range(4, 50):
		fixture.words["fixture%d" % index].media.image.picture_suitable = false
	check(_resolve(fixture, "match").get("code") == "mode_unavailable", "An unavailable five-pair mode does not admit ambiguous or unpictured fillers")
	check(_resolve(fixture, "jelly").ok, "A one-target picture game can use the smaller safe pool")


func _minimum_cases() -> void:
	var words: Array[Dictionary] = []
	for index in range(6):
		words.append({"id": "fixture%d" % index, "media": {"image": {"confusable_with": []}}})
	words[0].media.image.confusable_with = ["fixture1", "fixture2", "fixture3", "fixture4", "fixture5"]
	var safe: Array[Dictionary] = Resolver.picture_compatible_pool(words, 5)
	check(safe.size() == 5 and not safe.has(words[0]), "A broad first meaning cannot hide a valid five-pair pool")
	words[1].media.image.confusable_with = ["fixture2"]
	check(Resolver.picture_compatible_pool(words, 5).is_empty(), "A genuinely impossible pool stays unavailable")


func _skills(result: Dictionary, id: String) -> Array:
	if result.get("ok", false):
		for term in result.requirements.terms:
			if term.sense_id == id:
				return term.skills
	return []


func _per_sense_cases() -> void:
	var fixture: Dictionary = _fixture()
	for index in range(6, 50):
		fixture.words["fixture%d" % index].media.image.picture_suitable = false
	fixture.words.fixture0.media.image.confusable_with = ["fixture1", "fixture2", "fixture3", "fixture4", "fixture5"]
	fixture.words.fixture0.practice_modes = ["match", "memory", "word_jelly", "phrase"]
	var result: Dictionary = _resolve(fixture, "match")
	check(result.ok and result.words.size() == 5, "The five specific senses still form a valid round")
	check(_skills(result, "fixture0") == ["context"], "A stranded broad sense cannot advertise recognition from unreachable Match or Memory")
	check(result.get("module_words", []).size() == 50 and result.get("requirements", {}).get("terms", []).size() == 50,
		"Per-sense feasibility never removes the stranded term from module objectives or the library")
	fixture.words.fixture0.practice_modes.append("pop")
	check(_skills(_resolve(fixture, "match"), "fixture0").has("speaking") and
		not _skills(_resolve(fixture, "pop"), "fixture0").has("recognition"), "Voice Pop rescues speaking, not recognition")
	fixture.words.fixture0.practice_modes.append("jelly")
	check(_skills(_resolve(fixture, "jelly"), "fixture0").has("recognition"), "Singleton Jelly provides a genuine recognition route")
	fixture.words.fixture0.practice_modes = ["match", "word_jelly"]
	fixture.expressions.expression0.focus_lexeme_ids.erase("fixture0")
	result = _resolve(fixture, "match")
	check(not result.ok and result.error.contains("reachable scored"), "Atomic exposure cannot rescue a term without a feasible scored route")
	fixture = _fixture()
	for index in range(6, 50):
		fixture.words["fixture%d" % index].media.image.picture_suitable = false
	fixture.words.fixture0.display_text = " Charge "
	fixture.words.fixture1.display_text = "charge"
	fixture.words.fixture0.media.image.confusable_with = ["fixture2", "fixture3", "fixture4", "fixture5"]
	for seed_value in range(24):
		result = _resolve(fixture, "match", seed_value)
		check(result.ok and result.words.size() == 5 and result.words.any(func(word: Dictionary) -> bool: return word.id == "fixture1"),
			"A compatible same-spelling alternative remains available under every seeded order")
		check(result.ok and not result.words.any(func(word: Dictionary) -> bool: return word.id == "fixture0"),
			"A blocked same-spelling sense cannot hide the only valid pool")
	fixture.words.fixture0.media.image.confusable_with = []
	fixture.words.fixture5.media.image.picture_suitable = false
	check(_resolve(fixture, "match").get("code") == "mode_unavailable", "Five senses with four distinct labels cannot form a five-pair game")


func _grouped_pictures(groups: int, duplicate_labels: bool) -> Array[Dictionary]:
	var words: Array[Dictionary] = []
	for index in range(50):
		words.append({"id": "sense%d" % index,
			"text": "label%d" % (index % groups) if duplicate_labels else "label%d" % index,
			"media": {"image": {"confusable_with": []}}})
	if not duplicate_labels:
		for first in range(50):
			for second in range(first + 1, 50):
				if first % groups == second % groups:
					words[first].media.image.confusable_with.append(words[second].id)
	return words


func _large_pool_cases() -> void:
	for duplicate_labels in [false, true]:
		var words: Array[Dictionary] = _grouped_pictures(4, duplicate_labels)
		var before: Array[Dictionary] = words.duplicate(true)
		check(Resolver.picture_reachable_ids(words, 5).is_empty(), "Four groups cannot supply a five-choice witness in a full module")
		check(Resolver.picture_compatible_pool(words, 5).is_empty(), "An impossible full module has no five-choice round")
		check(Resolver.picture_reachable_ids(words, 1).size() == 50, "Singleton practice keeps every grouped sense")
		check(words == before, "Indexed feasibility does not modify shared metadata")
		words.reverse()
		check(Resolver.picture_reachable_ids(words, 5).is_empty(), "Group pruning is independent of candidate order")
		words = _grouped_pictures(5, duplicate_labels)
		check(Resolver.picture_reachable_ids(words, 5).size() == 50, "Every alternative in five groups has a separate witness")
		var chosen: Array[Dictionary] = Resolver.picture_compatible_pool(words, 5)
		check(chosen.size() == 5, "A five-group round contains exactly one member of each group")
		for index in range(chosen.size()):
			check(chosen[index].id == "sense%d" % index, "The compatible pool preserves the original candidate order")


func _color_bound_cases() -> void:
	# Two joined five-cycles need six colors but have no five-choice witness.
	var words: Array[Dictionary] = _grouped_pictures(50, false)
	for first in range(50):
		for second in range(first + 1, 50):
			var a: int = first % 10
			var b: int = second % 10
			var joined: bool = (a < 5) != (b < 5)
			var cycle_edge: bool = absi(a % 5 - b % 5) in [1, 4]
			if not joined and not cycle_edge:
				words[first].media.image.confusable_with.append(words[second].id)
	check(Resolver.picture_reachable_ids(words, 5).is_empty(), "Enough greedy colors does not prove per-sense feasibility")
	check(Resolver.picture_compatible_pool(words, 5).is_empty(), "Enough greedy colors does not replace the exact round search")
	check(Resolver.picture_reachable_ids(words, 4).size() == 50, "The joined cycles have real four-choice witnesses for every sense")
