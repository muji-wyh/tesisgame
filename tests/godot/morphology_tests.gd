extends SceneTree

const Analysis = preload("res://scripts/morphology_analysis.gd")
const Resolver = preload("res://scripts/morphology_resolver.gd")
const Footprint = preload("res://scripts/jelly_footprint.gd")
const FONT = preload("res://assets/fonts/heading.tres")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	_test_validation()
	_test_composition()
	_test_equivalence_and_isolation()
	_test_paths_and_placement()
	_test_footprints()
	print("Morphology foundation: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _part(id: String, canonical: String, type: String = "root", surface: String = "") -> Dictionary:
	return {"id": id, "canonical_id": type + ":" + canonical, "type": type,
		"canonical": canonical, "surface": canonical if surface.is_empty() else surface}


func _node(id: String, left: String, right: String, surface: String, rule: String = "authored_join", breaks: Array = []) -> Dictionary:
	return {"id": id, "left": left, "right": right, "surface": surface, "rule": rule, "break_offsets": breaks}


func _analysis(id: String, text: String, parts: Array, nodes: Array = [], roots: Array = [], kind: String = "morphological") -> Dictionary:
	return {"schema": 1, "id": id, "lexeme_id": "sense:" + id, "text": text,
		"kind": "atomic" if parts.size() == 1 else kind,
		# These are executable test fixtures, not claims of production editorial review.
		"review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
		"parts": parts, "nodes": nodes, "roots": [parts[0].id] if roots.is_empty() and parts.size() == 1 else roots}


func _fixtures() -> Array:
	return [
		_analysis("cat", "cat", [_part("cat", "cat", "atomic")]),
		_analysis("mri", "MRI", [_part("mri", "MRI", "abbreviation")]),
		_analysis("unhelpful", "unhelpful", [_part("un", "un-", "prefix"), _part("help", "help"), _part("ful", "-ful", "suffix")],
			[_node("helpful", "help", "ful", "helpful", "suffix", [4]), _node("whole", "un", "helpful", "unhelpful", "prefix", [2, 6])], ["whole"]),
		_analysis("waterproof", "waterproof", [_part("water", "water", "compound"), _part("proof", "proof", "compound")],
			[_node("whole", "water", "proof", "waterproof", "compound", [5])], ["whole"], "compound"),
		_analysis("happiness", "happiness", [_part("happy", "happy", "stem"), _part("ness", "-ness", "suffix")],
			[_node("whole", "happy", "ness", "happiness", "final_y_to_i", [5])], ["whole"]),
		_analysis("running", "running", [_part("run", "run"), _part("ing", "-ing", "suffix")],
			[_node("whole", "run", "ing", "running", "double_final_consonant", [4])], ["whole"]),
		_analysis("unpredictability", "unpredictability", [_part("un", "un-", "prefix"), _part("predict", "predict"), _part("able", "-able", "suffix"), _part("ity", "-ity", "suffix")],
			[_node("predictable", "predict", "able", "predictable"), _node("unpredictable", "un", "predictable", "unpredictable"),
			_node("whole", "unpredictable", "ity", "unpredictability", "able_to_ability", [2, 9, 13])], ["whole"]),
		_analysis("blood-pressure", "blood pressure", [_part("blood", "blood", "word"), _part("pressure", "pressure", "word")],
			[_node("whole", "blood", "pressure", "blood pressure", "lexical_word_boundary", [6])], ["whole"], "phrase"),
		_analysis("repeated-phrase", "very very good", [_part("first", "very", "word"), _part("second", "very", "word"), _part("good", "good", "word")],
			[_node("left", "first", "second", "very very", "phrase_span", [5]), _node("right", "second", "good", "very good", "phrase_span", [5]),
			_node("whole-left", "left", "good", "very very good", "phrase_span", [5, 10]),
			_node("whole-right", "first", "right", "very very good", "phrase_span", [5, 10])], ["whole-left", "whole-right"], "phrase"),
		_analysis("follow-up", "follow-up", [_part("follow", "follow", "compound"), _part("up", "up", "compound")],
			[_node("whole", "follow", "up", "follow-up", "hyphenated_compound", [7])], ["whole"], "compound"),
		_analysis("type-2-diabetes", "type 2 diabetes", [_part("type", "type", "word"), _part("number", "2", "word"), _part("diabetes", "diabetes", "word")],
			[_node("type-2", "type", "number", "type 2", "phrase_span", [5]), _node("whole", "type-2", "diabetes", "type 2 diabetes", "phrase_span", [5, 7])], ["whole"], "phrase")
	]


func _test_validation() -> void:
	for authored: Dictionary in _fixtures():
		var result: Dictionary = Analysis.compile(authored)
		check(result.ok, "Reviewed fixture validates: %s (%s)" % [authored.id, result.error])
	var pending: Dictionary = _fixtures()[2].duplicate(true)
	pending.review.status = "pending"
	check(not Analysis.compile(pending).ok and Analysis.compile(pending, false).ok, "Pending content can be audited but cannot silently enter a round")
	var bad: Dictionary = _fixtures()[2].duplicate(true)
	bad.nodes[0].left = "missing"
	check(not Analysis.compile(bad).ok, "Missing child is rejected")
	bad = _fixtures()[2].duplicate(true)
	bad.nodes[0].left = "whole"
	check(not Analysis.compile(bad).ok, "Cycles are rejected before traversal can loop")
	bad = _fixtures()[2].duplicate(true)
	bad.nodes[0].right = "un"
	check(not Analysis.compile(bad).ok, "Wrong-order and nonadjacent joins are rejected")
	bad = _fixtures()[2].duplicate(true)
	bad.nodes[0].right = "help"
	check(not Analysis.compile(bad).ok, "Overlapping spans cannot reuse a part occurrence")
	bad = _fixtures()[2].duplicate(true)
	bad.nodes[1].surface = "unhelpfull"
	check(not Analysis.compile(bad).ok, "A complete root must exactly spell its target")
	bad = _fixtures()[2].duplicate(true)
	bad.nodes.append(_node("unused", "un", "help", "unhelp"))
	check(not Analysis.compile(bad).ok, "Unreachable rules cannot quietly authorize an unrelated partial")
	bad = _fixtures()[2].duplicate(true)
	bad.parts[0].id = "help"
	check(not Analysis.compile(bad).ok, "Duplicate occurrence IDs are rejected")
	bad = _fixtures()[2].duplicate(true)
	bad.nodes[1].break_offsets = [0, 99]
	check(not Analysis.compile(bad).ok, "Invalid display breaks are rejected")
	bad = _fixtures()[3].duplicate(true)
	bad.parts[0].type = "combining_form"
	check(not Analysis.compile(bad).ok, "Classical-form review requires explicit source references")
	bad = _fixtures()[0].duplicate(true)
	bad.parts.append(_part("extra", "s", "suffix"))
	check(not Analysis.compile(bad).ok, "Atomic classification cannot hide a split")
	check(not Analysis.compile({}).ok and not Analysis.compile(null).ok, "Missing analyses never fabricate midpoint parts")


func _test_composition() -> void:
	var resolver := Resolver.new()
	check(resolver.configure(_fixtures()), "The authored catalog configures")
	for id: String in ["cat", "mri"]:
		var tiles: Array = resolver.source_tiles(id)
		check(tiles.size() == 1 and tiles[0].complete and not tiles[0].mastery_eligible,
			"Atomic %s is collectable exposure without spelling evidence" % id)
	check(resolver.source_tiles("mri")[0].text == "MRI", "Abbreviation capitalization is preserved")
	check(resolver.source_tiles("unknown").is_empty(), "Unknown entries do not manufacture parts")
	var parts: Array = resolver.source_tiles("unhelpful")
	check(parts.size() == 3 and parts[0].part_type == "prefix" and parts[2].part_type == "suffix", "Typed parts remain three separate Jellies")
	check(resolver.resolve(parts[0], parts[1]).status == "invalid", "A plausible string without an authored join is rejected")
	var partial: Dictionary = resolver.resolve(parts[1], parts[2])
	check(partial.status == "partial" and partial.tile.text == "helpful" and not partial.tile.mastery_eligible, "An authored intermediate remains a non-rewarding partial")
	var whole: Dictionary = resolver.resolve(parts[0], partial.tile)
	check(whole.status == "complete" and whole.tile.text == "unhelpful" and whole.tile.part_count == 3 and whole.tile.mastery_eligible,
		"A second authored merge completes the target with all three components")
	check(resolver.resolve(partial.tile, parts[0]).status == "invalid", "Composition order is meaningful")
	for id: String in ["waterproof", "happiness", "running", "blood-pressure", "follow-up"]:
		parts = resolver.source_tiles(id)
		whole = resolver.resolve(parts[0], parts[1])
		var expected: String = "blood pressure" if id == "blood-pressure" else id
		check(whole.status == "complete" and whole.tile.text == expected, "Exact authored compound, boundary, or spelling transformation: " + id)
	parts = resolver.source_tiles("unpredictability")
	partial = resolver.resolve(parts[1], parts[2])
	partial = resolver.resolve(parts[0], partial.tile)
	whole = resolver.resolve(partial.tile, parts[3])
	check(parts.size() == 4 and whole.status == "complete" and whole.tile.text == "unpredictability" and whole.tile.part_count == 4,
		"Four-part composition retains the spelling transformation and full ordered ancestry")
	parts = resolver.source_tiles("running")
	parts[0].assisted = true
	check(not resolver.resolve(parts[0], parts[1]).tile.mastery_eligible, "Assisted ancestry cannot create mastery evidence")


func _test_equivalence_and_isolation() -> void:
	var authored: Array = _fixtures()
	var resolver := Resolver.new()
	check(resolver.configure(authored), "Equivalence fixture configures")
	authored[2].nodes[1].surface = "changed by caller"
	var first: Array = resolver.source_tiles("unhelpful")
	var second: Array = resolver.source_tiles("unhelpful")
	first[1].origins[0].supply_group = 11
	second[2].origins[0].supply_group = 22
	first[1].fragments = 1
	second[2].fragments = 2
	var joined: Dictionary = resolver.resolve(first[1], second[2])
	check(joined.status == "partial" and joined.tile.fragments == 3 and joined.tile.origins[0].supply_group == 11 and joined.tile.origins[1].supply_group == 22,
		"Equivalent parts from independent supply groups compose while conserving fragments and provenance")
	check(resolver.resolve(first[0], joined.tile).tile.text == "unhelpful", "Caller mutation cannot change compiled spelling rules")
	var renamed: Dictionary = _fixtures()[2].parts[1].duplicate(true)
	renamed.id = "another-occurrence"
	renamed.supply_group = 99
	check(Analysis.part_signature(renamed) == Analysis.part_signature(_fixtures()[2].parts[1]), "Canonical identity excludes occurrence and supply IDs")
	renamed.type = "stem"
	check(Analysis.part_signature(renamed) == Analysis.part_signature(_fixtures()[2].parts[1]), "A contextual stem or root role does not change canonical lexical identity")
	renamed.canonical_id = "root:help:different-sense"
	check(Analysis.part_signature(renamed) != Analysis.part_signature(_fixtures()[2].parts[1]), "Different canonical senses are not interchangeable")
	first[0].text = "corrupted"
	check(resolver.resolve(first[0], joined.tile).status == "invalid", "A changed display string cannot reuse a valid signature")
	check(resolver.source_tiles("unhelpful")[0].text == "un-", "Returned tiles do not expose mutable resolver metadata")
	var before: Array = resolver.source_tiles("running")
	var invalid: Dictionary = _fixtures()[0].duplicate(true)
	invalid.review.status = "pending"
	check(not resolver.configure([invalid]) and resolver.source_tiles("running") == before, "Failed reconfiguration preserves the existing valid catalog")
	var duplicate: Dictionary = _fixtures()[3].duplicate(true)
	duplicate.id = "second-sense"
	duplicate.lexeme_id = "another-waterproof-sense"
	check(resolver.configure([_fixtures()[3], duplicate]), "The resolver can represent ambiguity for the round filter to detect")
	var parts: Array = resolver.source_tiles("waterproof")
	check(resolver.resolve(parts[0], parts[1]).reason == "ambiguous_sense", "A hidden sense conflict never silently chooses one completion")


func _test_paths_and_placement() -> void:
	var resolver := Resolver.new()
	check(resolver.configure(_fixtures()), "Path-planning fixture configures")
	var parts: Array = resolver.source_tiles("repeated-phrase")
	var left: Dictionary = resolver.resolve(parts[0], parts[1])
	var right: Dictionary = resolver.resolve(parts[1], parts[2])
	var whole_left: Dictionary = resolver.resolve(left.tile, parts[2])
	var whole_right: Dictionary = resolver.resolve(parts[0], right.tile)
	check(whole_left.status == "complete" and whole_right.status == "complete" and whole_left.tile.signature == whole_right.tile.signature,
		"Both authored paths converge on one immutable composition signature")
	check(whole_left.tile.part_count == 3 and whole_left.tile.text == "very very good", "Repeated phrase tokens remain distinct occurrences")
	parts = resolver.source_tiles("unhelpful")
	for index in range(parts.size()):
		parts[index].id = index + 100
	var before: Array = parts.duplicate(true)
	var no_room: Callable = func(a: Dictionary, b: Dictionary, result: Dictionary, board: Array) -> bool:
		a.text = "mutated hook copy"
		b.fragments = 100
		result.text = "mutated result copy"
		board.clear()
		return false
	check(resolver.resolve(parts[1], parts[2], no_room, parts).status == "needs_room" and parts == before,
		"Placement refusal preserves both inputs, board, and immutable rule state")
	check(resolver.compatible_pairs(parts, no_room).is_empty(), "Hints exclude geometrically unavailable joins using the same preflight")
	check(resolver.completion_plan(parts, no_room).status == "unavailable", "Auto merge does not offer a path whose placement cannot succeed")
	var fit: Callable = func(_a: Dictionary, _b: Dictionary, _result: Dictionary, board: Array) -> Dictionary:
		return {"ok": true, "placement": {"column": board.size() - 2, "row": 0, "width": 2, "height": 1}}
	var pairs: Array = resolver.compatible_pairs(parts, fit)
	check(pairs.size() == 1 and pairs[0].left_index == 1 and pairs[0].right_index == 2, "Compatibility highlights exactly the authored first step")
	var plan: Dictionary = resolver.completion_plan(parts, fit)
	check(plan.status == "complete" and plan.steps.size() == 2 and plan.placement_checked and plan.tile.text == "unhelpful",
		"Auto merge establishes a full multi-step path with placement checked before charging")
	check(plan.steps[0].placement.column == 1 and plan.steps[1].placement.column == 0, "Later placement sees the simulated board after the prior merge")
	check(plan.steps[1].right_ref == "step:0" and plan.steps[0].left_ref == "input:1", "Plans reference original inputs and explicit intermediate results")
	check(parts == before, "Planning has no live-board side effects")
	check(resolver.completion_plan(parts, Callable(), 0).reason == "search_limit", "Bounded planning reports exhaustion without claiming a valid path")
	check(not resolver.completion_plan(parts).placement_checked, "An unplaced semantic plan cannot masquerade as a chargeable Auto merge plan")
	parts[2].id = parts[1].id
	check(resolver.resolve(parts[1], parts[2]).reason == "same_tile", "One physical tile cannot be consumed twice")


func _test_footprints() -> void:
	var small: Dictionary = Footprint.plan("cat", FONT)
	check(small.ok and not small.requires_read and small.font_size == 16 and small.cell_pitch == 32,
		"Footprints use actual font metrics at the documented minimum display size")
	var long_text: String = "supercalifragilisticexpialidocious"
	var overflow: Dictionary = Footprint.plan(long_text, FONT)
	check(overflow.ok and overflow.requires_read and overflow.width == 6 and overflow.height == 2 and overflow.text == long_text and overflow.lines == [long_text],
		"An indivisible overlong token retains all text and requests Read instead of invented breaks")
	var phrase: String = "communication communication"
	var wrapped: Dictionary = Footprint.plan(phrase, FONT, [14])
	check(wrapped.ok and not wrapped.requires_read and wrapped.lines.size() == 2 and "".join(wrapped.lines) == phrase and wrapped.break_offsets == [14],
		"A reviewed boundary permits multiline layout without dropping the preserved space")
	check(Footprint.plan(phrase, FONT).requires_read, "Whitespace does not silently create an unreviewed break")
	var reserved: Dictionary = Footprint.plan("cat", FONT, [], Vector4(4, 3, 4, 3), Vector2(32, 0))
	check(reserved.width * reserved.height > small.width * small.height, "Artwork and badge reservations participate in footprint measurement")
	check(Footprint.plan("cat", FONT) == small, "Footprint computation is deterministic and independent of viewport dimensions")
	check(not Footprint.plan("cat", FONT, [0]).ok and not Footprint.plan("cat", FONT, [2, 1]).ok,
		"Invalid or unordered break offsets fail explicitly")
	for text: String in ["unhelpful", "happiness", "MRI", "blood pressure", "type 2 diabetes"]:
		var layout: Dictionary = Footprint.plan(text, FONT)
		check(layout.ok and layout.width >= 1 and layout.width <= 6 and layout.height >= 1 and layout.height <= 2,
			"The fixed 6-by-2 envelope is respected for " + text)
