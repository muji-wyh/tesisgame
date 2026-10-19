extends SceneTree

const Context = preload("res://scripts/learning_context.gd")
const Resolver = preload("res://scripts/learning_content_resolver.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
const Model = preload("res://scripts/game_model.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_context_cases()
	_growth_cases()
	_professional_cases()
	_catalog_cases()
	print("Learning content: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _context_cases() -> void:
	var selected: Dictionary = Context.professional("nursing", "module03", "professional-v1", "word_jelly")
	var frozen: Dictionary = Context.freeze(selected)
	selected.course_id = "retail"
	check(frozen.course_id == "nursing" and frozen.is_read_only(), "A round keeps its frozen course when Home changes")
	check(not Context.same_round(frozen, selected), "Changing career cannot resume the same-mode round")
	selected = frozen.duplicate()
	selected.curriculum_revision = "professional-v2"
	check(not Context.same_round(frozen, selected), "Changing content revision starts a new round")
	selected = frozen.duplicate()
	selected.mode = "match"
	check(Context.identity(frozen, false) == Context.identity(selected, false), "Course preferences can ignore exercise mode")
	check(Context.freeze(Context.growth(2, "match")).is_empty(), "Unknown Growth ages are rejected")
	check(Context.freeze(Context.professional("../../escape", "module03", "v1", "match")).is_empty(), "Context IDs cannot escape resource paths")
	check(Context.validate(Context.growth(12, "phrase")).is_empty(), "Growth's existing ages and modes remain valid")


func _growth_cases() -> void:
	var words: Array = [
		{"id": "cat", "text": "cat", "min_age": 3, "part_of_speech": "noun", "image": "cat.svg", "audio": "cat.wav"},
		{"id": "on", "text": "on", "min_age": 3, "image": "", "audio": "on.wav", "practice_modes": ["phrase"]},
		{"id": "school", "text": "school", "min_age": 4, "image": "school.svg", "audio": "school.wav"},
		{"id": "cat-pro", "text": "CAT", "track": "professional", "min_age": 3, "image": "scanner.svg", "audio": "scanner.wav"}
	]
	var original: Array = words.duplicate(true)
	var result: Dictionary = Resolver.resolve_growth(Context.growth(3, "word_jelly"), words)
	check(result.ok and result.words.size() == 1 and result.words[0].id == "cat", "Jelly needs one eligible Growth entry, independent of Match's five-pair requirement")
	check(result.ok and result.words[0].morphology_status == "reviewed" and result.words[0].morphology.kind == "atomic",
		"Growth resolves cat as one reviewed whole Jelly rather than spelling chunks")
	var altered: Dictionary = words[0].duplicate(true)
	altered.text = "cats"
	check(not Resolver.resolve_growth(Context.growth(3, "word_jelly"), [altered]).ok,
		"An unchanged ID with changed spelling cannot use a stale Growth analysis")
	var pending: Dictionary = words[0].duplicate(true)
	pending.id = "fixture.pending-growth"
	check(not Resolver.resolve_growth(Context.growth(3, "word_jelly"), [pending]).ok,
		"Growth words awaiting an authored analysis cannot enter Word Jelly")
	check(Resolver.resolve_growth(Context.growth(3, "jelly"), [pending]).ok,
		"Pending word analysis does not remove picture recognition content")
	check(not Resolver.resolve_growth(Context.growth(3, "match"), words).ok, "Match still requires enough pictured terms")
	result = Resolver.resolve_growth(Context.growth(4, "phrase"), words, ["cat", "on", "school"])
	check(result.ok and result.words.size() == 3, "Phrase dependencies preserve lower-age function words without inventing pictures")
	check(words == original, "Content resolution does not mutate the legacy vocabulary")
	var model := Model.new()
	check(model.prepare_activity("word_jelly", "3", 42), "Independent Jelly presentation can start without constructing a Match board")
	check(model.cards.is_empty() and model.lesson_words.is_empty() and not model.chest_earned, "Non-pair activity cannot inherit phantom Match cards or chest ownership")
	check(model.prepare_activity("phrase", "3", 42) and model.chest_earned, "Phrase retains its existing finale chest")


func _media() -> Dictionary:
	# This fixture tests eligibility, not file acquisition or hash verification.
	return {"status": "integrated", "path": "res://fixture/media.wav", "sha256": "a".repeat(64),
		"source": "fixture", "creator": "fixture", "license": "fixture", "review": {"status": "reviewed"}, "picture_suitable": true}


func _review() -> Dictionary:
	return {"status": "reviewed", "language": "reviewed", "domain": "not_required"}


func _atomic_fixture(entry: Dictionary) -> Dictionary:
	return {"schema": 1, "id": entry.id + ".analysis", "lexeme_id": entry.id, "text": entry.text,
		"kind": "atomic", "review": {"status": "reviewed"}, "nodes": [], "roots": ["whole"],
		"parts": [{"id": "whole", "canonical_id": entry.id, "type": "atomic", "canonical": entry.text,
			"surface": entry.text, "break_offsets": []}]}


func _professional_cases() -> void:
	var words: Dictionary = {}
	var expressions: Dictionary = {}
	var ids: Array = []
	var expression_ids: Array = []
	for index in range(50):
		var id: String = "fixture.sense.%d" % index
		ids.append(id)
		words[id] = {"id": id, "text": "term %d" % index, "pos": "noun", "definition": "A test sense.",
			"example": "A fixture only.", "difficulty": "A2", "review": _review(), "practice_modes": ["match", "pop", "word_jelly"],
			"media": {"image": _media(), "audio": _media()}}
	words[ids[0]].text = "charge"
	words[ids[1]].text = "charge"
	words[ids[2]].text = "MRI"
	words[ids[3]].text = "USB-C"
	words[ids[4]].text = "2-factor authentication"
	for entry in words.values():
		entry.morphology = _atomic_fixture(entry)
	words[ids[0]].practice_modes.append("phrase")
	for index in range(10):
		var id: String = "fixture.expression.%d" % index
		expression_ids.append(id)
		expressions[id] = {"id": id, "text": "Pass the key to the desk.", "review": _review(), "media": {"audio": _media()},
			"focus_lexeme_ids": [ids[0]],
			"tokens": [{"index": 0, "text": "Pass", "start": 0, "end": 4},
				{"index": 1, "text": "the", "start": 5, "end": 8}, {"index": 2, "text": "key", "start": 9, "end": 12},
				{"index": 3, "text": "to", "start": 13, "end": 15}, {"index": 4, "text": "the", "start": 16, "end": 19},
				{"index": 5, "text": "desk.", "start": 20, "end": 26}]}
	var course: Dictionary = {"id": "retail", "title": "Fixture Retail", "curriculum_revision": "v1", "theme_id": "retail_store",
		"modules": [{"id": "module03", "title": "Fixture workplace", "status": "ready", "requirements_revision": "v1", "lexeme_ids": ids, "expression_ids": expression_ids}]}
	# A bad authored token boundary must fail closed.
	var context: Dictionary = Context.professional("retail", "module03", "v1", "word_jelly")
	check(not Resolver.resolve_professional(context, course, words, expressions, 42).ok, "Invalid expression offsets cannot silently drop punctuation")
	for entry in expressions.values():
		entry.tokens[5].end = 25
	var result: Dictionary = Resolver.resolve_professional(context, course, words, expressions, 42)
	check(result.ok, "A complete reviewed fixture resolves for a non-picture game")
	if result.ok:
		check(result.words.size() == 49, "Only one sense of an identical displayed spelling enters a round")
		check(result.module_words.size() == 50 and result.module_words.filter(func(word: Dictionary) -> bool: return word.text == "charge").size() == 2,
			"The word library retains all module senses, including same-spelling distinct meanings")
		check(result.course_title == course.title and result.module_title == course.modules[0].title,
			"Library and game headers use the authored course and module titles")
		check(result.words.any(func(word: Dictionary) -> bool: return word.text == "MRI") \
			and result.words.any(func(word: Dictionary) -> bool: return word.text == "2-factor authentication"), "Genuine capitalization, spaces, hyphens and digits survive resolution")
		check(not result.words[0].has("min_age"), "Professional words are not assigned fabricated Growth ages")
		check(not result.requirements.terms[0].skills.has("spelling"), "Collecting an atomic Jelly cannot establish spelling mastery")
		check(result.expressions[0].tokens[1].text == result.expressions[0].tokens[4].text \
			and result.expressions[0].tokens[1].index != result.expressions[0].tokens[4].index, "Repeated phrase tokens keep distinct positions")
	words[ids[2]].morphology.roots = ["missing"]
	check(not Resolver.resolve_professional(context, course, words, expressions).ok, "A reviewed label cannot bypass composition graph validation")
	words[ids[2]].morphology = _atomic_fixture(words[ids[2]])
	words[ids[2]].morphology.lexeme_id = ids[3]
	check(not Resolver.resolve_professional(context, course, words, expressions).ok, "An analysis cannot be attached to another canonical sense")
	words[ids[2]].morphology = _atomic_fixture(words[ids[2]])
	words[ids[2]].text = "mri"
	check(not Resolver.resolve_professional(context, course, words, expressions).ok, "Morphology preserves exact capitalization and displayed term")
	words[ids[2]].text = "MRI"
	words[ids[5]].practice_modes = ["phrase"]
	check(not Resolver.resolve_professional(context, course, words, expressions).ok, "An unpictured phrase-only term without an assessed expression is unreachable")
	words[ids[5]].practice_modes = ["match"]
	var filtered: Dictionary = Resolver.resolve_professional(context, course, words, expressions, 42)
	check(filtered.ok and filtered.words.size() == 48 and filtered.module_words.size() == 50 \
		and filtered.module_words.any(func(word: Dictionary) -> bool: return word.id == ids[5]),
		"A term excluded from the selected game remains available in the module library")
	filtered.module_words[0].definition = "Modified test copy."
	check(words[ids[0]].definition == "A test sense.", "Browsing cannot mutate authored catalog content")
	expressions[expression_ids[0]].focus_lexeme_ids = ["unknown.sense"]
	check(not Resolver.resolve_professional(context, course, words, expressions).ok, "Expressions cannot award evidence to senses outside the module")
	expressions[expression_ids[0]].focus_lexeme_ids = [ids[0]]
	words[ids[0]].review.domain = "pending"
	check(not Resolver.resolve_professional(context, course, words, expressions).ok, "An unresolved specialist review blocks the module")
	words[ids[0]].review.domain = "not_required"
	words[ids[0]].media.image.status = "pending"
	check(not Resolver.resolve_professional(context, course, words, expressions).ok, "Missing artwork never becomes a ready entry")
	words[ids[0]].media.image.status = "integrated"
	course.modules[0].status = "draft"
	check(Resolver.resolve_professional(context, course, words, expressions).get("code") == "content_pending", "Draft audit success is not runtime release readiness")


func _catalog_cases() -> void:
	var catalog := Catalog.new()
	check(catalog.load_index(), "The authored professional catalog is readable")
	check(catalog.courses().size() == 20, "All twenty careers are discoverable in metadata")
	var copy: Array = catalog.courses()
	copy.clear()
	check(catalog.courses().size() == 20, "Consumers cannot mutate the catalog's owned metadata")
	check(catalog.course("../../escape").is_empty(), "Course lookup never treats an unknown ID as a path")
	var result: Dictionary = catalog.resolve(Context.professional("retail", "module03", "professional-v1", "match"))
	check(not result.ok and result.get("code") == "content_pending", "Unfinished pilot modules are not exposed as playable content")
