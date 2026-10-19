extends SceneTree

const Analysis = preload("res://scripts/morphology_analysis.gd")
const Resolver = preload("res://scripts/morphology_resolver.gd")
const Growth = preload("res://scripts/growth_morphology.gd")
var checks := 0
var failures := 0
var resolver := Resolver.new()

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/retail-module03-morphology-first10-2026-10-16.json"))
	var next_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/retail-module03-morphology-next10-2026-10-16.json"))
	var case_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/retail-case-family-review-2026-10-16.json"))
	var third_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/retail-module03-morphology-third10-2026-10-16.json"))
	var fourth_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/retail-module03-morphology-fourth10-2026-10-16.json"))
	var fifth_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/retail-module03-morphology-fifth10-2026-10-16.json"))
	var graphs: Array = []
	var display_patches: Array = case_record.patches.filter(func(p: Dictionary) -> bool: return p.kind == "exact_display_case_graph_review")
	for patch: Dictionary in record.patches + next_record.patches + display_patches + third_record.patches + fourth_record.patches + fifth_record.patches:
		var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(patch.origin))
		var entries: Array = envelope.lexemes.filter(func(e: Dictionary) -> bool: return e.id == patch.id)
		check(entries.size() == 1, "One persisted exact sense: " + patch.id)
		if entries.is_empty():
			continue
		var graph: Dictionary = entries[0].morphology
		check(graph == patch.after.morphology, "Persisted graph equals independent acceptance: " + patch.id)
		check(Analysis.compile(graph).ok, "Reviewed exact graph compiles: " + patch.id)
		var pending := graph.duplicate(true)
		pending.review.status = "pending"
		check(not Analysis.compile(pending).ok, "Changing review status cannot retain admission: " + patch.id)
		graphs.append(graph)
	check(graphs.size() == 50 and resolver.configure(graphs), "All fifty production graphs configure together")
	for graph: Dictionary in graphs:
		var leaves: Array = resolver.source_tiles(graph.id)
		var by_id := {}
		check(leaves.size() == graph.parts.size(), "No extra spelling-only tile: " + graph.text)
		for index in range(leaves.size()):
			by_id[graph.parts[index].id] = leaves[index]
			check(not leaves[index].mastery_eligible, "Uncomposed input cannot award composition mastery: " + graph.text)
		var result := _resolve_node(graph, graph.roots[0], by_id)
		check(result.get("text", "") == graph.text and result.get("complete", false), "Exact whole spelling and sense: " + graph.text)
		check(result.get("lexeme_ids", []) == [graph.lexeme_id], "Exact completed sense: " + graph.text)
		check(result.get("mastery_eligible", false) == (graph.parts.size() > 1), "Only multipart unassisted composition earns mastery: " + graph.text)
		if graph.parts.size() > 1:
			by_id.clear()
			leaves = resolver.source_tiles(graph.id)
			for index in range(leaves.size()):
				leaves[index].assisted = true
				by_id[graph.parts[index].id] = leaves[index]
			result = _resolve_node(graph, graph.roots[0], by_id)
			check(not result.get("mastery_eligible", true), "Assistance cannot grant composition mastery: " + graph.text)
	var scanner: Dictionary = graphs.filter(func(g: Dictionary) -> bool: return g.text == "barcode scanner")[0]
	var reader: Dictionary = graphs.filter(func(g: Dictionary) -> bool: return g.text == "card reader")[0]
	var scanner_parts: Array = resolver.source_tiles(scanner.id)
	var reader_parts: Array = resolver.source_tiles(reader.id)
	var mixed: Dictionary = resolver.resolve(scanner_parts[2], reader_parts[2])
	check(mixed.status == "partial" and mixed.tile.text == "scanner", "Canonical er from reader produces authored scanner doubling")
	check(resolver.resolve(reader_parts[2], scanner_parts[2]).status == "invalid", "Reversed suffix/stem order remains invalid")
	_check_ing_families(graphs)
	_check_case_families(graphs, case_record)
	_check_third_families(graphs, third_record)
	_check_fourth_families(graphs, fourth_record)
	_check_fifth_families(graphs, fifth_record)
	_check_retail04_first10()
	print("Professional Retail morphology: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _resolve_node(graph: Dictionary, id: String, leaves: Dictionary) -> Dictionary:
	if leaves.has(id):
		return leaves[id]
	var nodes: Array = graph.nodes.filter(func(n: Dictionary) -> bool: return n.id == id)
	if nodes.is_empty():
		check(false, "Missing authored node " + id)
		return {}
	var node: Dictionary = nodes[0]
	var left := _resolve_node(graph, node.left, leaves)
	var right := _resolve_node(graph, node.right, leaves)
	var joined: Dictionary = resolver.resolve(left, right)
	check(joined.status in ["partial", "complete"], "Authored join resolves: " + graph.text + "/" + id)
	var tile: Dictionary = joined.get("tile", {})
	check(tile.get("text", "") == node.surface, "Authored intermediate spelling: " + node.surface)
	return tile

func _check_ing_families(graphs: Array) -> void:
	var growth_graphs: Array = []
	for target: Array in [[7, "bowling"], [9, "stuffing"]]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vocabulary/morphology/age-%02d.json" % target[0]))
		var entry: Dictionary = document.entries.filter(func(e: Dictionary) -> bool: return e.text == target[1])[0]
		var decorated: Dictionary = Growth.decorate(entry)
		check(decorated.morphology_status == "reviewed", "Actual Growth entry passes its normal source and identity gates: " + target[1])
		growth_graphs.append(decorated.morphology)
	check(resolver.configure(graphs + growth_graphs), "Reviewed Growth and Professional graphs configure together")
	var activity: Dictionary = resolver.source_tiles(growth_graphs[0].id)[1]
	var result_noun: Dictionary = resolver.source_tiles(growth_graphs[1].id)[1]
	check(activity.canonical_id == "english.affix.ing.activity", "Bowling supplies the existing activity identity")
	check(result_noun.canonical_id == "english.affix.ing.result-noun", "Stuffing supplies the existing result-noun identity")
	check(activity.signature != result_noun.signature, "Equal visible suffix spelling does not collapse different nominal roles")
	for text: String in ["shopping basket", "shopping cart", "fitting room", "loading bay", "clothing rack"]:
		var graph: Dictionary = graphs.filter(func(g: Dictionary) -> bool: return g.text == text)[0]
		var leaves: Array = resolver.source_tiles(graph.id)
		var expected: Dictionary = result_noun if text == "clothing rack" else activity
		var wrong: Dictionary = activity if text == "clothing rack" else result_noun
		check(resolver.resolve(leaves[0], wrong).status == "invalid", "Different nominal suffix cannot substitute: " + text)
		var partial: Dictionary = resolver.resolve(leaves[0], expected)
		check(partial.status == "partial", "Actual Growth suffix forms a legal Professional partial: " + text)
		check(partial.get("tile", {}).get("text", "") == graph.nodes[0].surface, "Cross-source join preserves authored spelling: " + text)
		check(not partial.get("tile", {}).get("mastery_eligible", true), "Cross-source partial grants no mastery: " + text)
		var complete: Dictionary = resolver.resolve(partial.get("tile", {}), leaves[2])
		check(complete.status == "complete" and complete.tile.text == text, "Cross-source compound completes exactly: " + text)
		check(complete.get("tile", {}).get("lexeme_ids", []) == [graph.lexeme_id], "Cross-source compound retains its exact sense: " + text)
	var foundation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/lexemes/foundation-module02.json"))
	var missing: Dictionary = foundation.lexemes.filter(func(e: Dictionary) -> bool: return e.id == "missing.not-present.adj")[0].morphology
	check(missing.review.status == "pending" and not Analysis.compile(missing).ok, "Legacy missing remains pending and inadmissible in production")
	# This resolver inspects a pending graph only as a negative structural fixture.
	var inspection := Resolver.new()
	check(inspection.configure(graphs + growth_graphs + [missing], false), "Inspection-only resolver can examine the legacy collision")
	var legacy: Array = inspection.source_tiles(missing.id)
	check(legacy[1].canonical_id == "affix.ing.suffix", "Unrelated legacy suffix identity remains unchanged")
	for text: String in ["shopping basket", "shopping cart", "fitting room", "loading bay", "clothing rack"]:
		var graph: Dictionary = graphs.filter(func(g: Dictionary) -> bool: return g.text == text)[0]
		var leaves: Array = inspection.source_tiles(graph.id)
		check(inspection.resolve(leaves[0], legacy[1]).status == "invalid", "Legacy participial suffix cannot enter a nominal compound: " + text)
		check(inspection.resolve(legacy[0], leaves[1]).status == "invalid", "Nominal suffix cannot enter legacy missing: " + text)

func _check_case_families(graphs: Array, record: Dictionary) -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vocabulary/morphology/age-07.json"))
	var entry: Dictionary = document.entries.filter(func(e: Dictionary) -> bool: return e.text == "bookcase")[0]
	var growth: Dictionary = Growth.decorate(entry)
	check(growth.morphology_status == "reviewed", "Actual Growth bookcase retains its reviewed source gate")
	var display: Dictionary = graphs.filter(func(g: Dictionary) -> bool: return g.text == "display case")[0]
	var admitted := Resolver.new()
	check(admitted.configure([display, growth.morphology]), "Reviewed display case and Growth bookcase configure without a bypass")
	var display_tiles: Array = admitted.source_tiles(display.id)
	var growth_tiles: Array = admitted.source_tiles(growth.morphology.id)
	var shared: Dictionary = admitted.resolve(display_tiles[0], growth_tiles[1])
	check(shared.status == "complete" and shared.tile.text == "display case", "Actual Growth container tile completes exact display case")
	check(shared.get("tile", {}).get("lexeme_ids", []) == [display.lexeme_id], "Shared container part does not merge complete lexical sense identities")
	var pending_graphs: Array = []
	for classification: Dictionary in record.proposal.classifications:
		var file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(classification.resource))
		var current: Dictionary = file.lexemes.filter(func(e: Dictionary) -> bool: return e.id == classification.id)[0]
		check(current.morphology.review.status == "pending" and not Analysis.compile(current.morphology).ok, "Case-family classification does not approve a pending graph: " + classification.id)
		pending_graphs.append(current.morphology)
	# Pending graphs are included here only to inspect forbidden homonym substitution.
	var inspection := Resolver.new()
	check(inspection.configure([display, growth.morphology] + pending_graphs, false), "Inspection-only case families configure for negative checks")
	var display_source: Dictionary = inspection.source_tiles(display.id)[0]
	for classification: Dictionary in record.proposal.classifications:
		var graph: Dictionary = pending_graphs.filter(func(g: Dictionary) -> bool: return g.lexeme_id == classification.id)[0]
		var candidate: Dictionary = inspection.source_tiles(graph.id)[classification.part_index]
		var combined: Dictionary = inspection.resolve(display_source, candidate)
		if classification.family == "container":
			check(combined.status == "complete" and combined.tile.text == "display case", "Corrected container identity shares only an installed authored join: " + classification.id)
		else:
			check(combined.status == "invalid", "Event or matter case cannot replace a container: " + classification.id)

func _check_third_families(graphs: Array, record: Dictionary) -> void:
	var growth_graphs: Array = []
	for target: Array in [[7, "bowling"], [9, "stuffing"], [10, "curiosity"], [11, "responsibility"], [12, "scales"], [12, "refrigerate"]]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vocabulary/morphology/age-%02d.json" % target[0]))
		var entry: Dictionary = document.entries.filter(func(e: Dictionary) -> bool: return e.id == target[1])[0]
		var decorated: Dictionary = Growth.decorate(entry)
		check(decorated.morphology_status == "reviewed", "Normal Growth admission for third-ten substitution: " + target[1])
		growth_graphs.append(decorated.morphology)
	var admitted := Resolver.new()
	check(admitted.configure(graphs + growth_graphs), "Forty reviewed graphs and actual Growth sources configure normally")
	var weighing: Dictionary = graphs.filter(func(g: Dictionary) -> bool: return g.text == "weighing scale")[0]
	var weighing_tiles: Array = admitted.source_tiles(weighing.id)
	var activity: Dictionary = admitted.source_tiles(growth_graphs[0].id)[1]
	var result_noun: Dictionary = admitted.source_tiles(growth_graphs[1].id)[1]
	var scale: Dictionary = admitted.source_tiles(growth_graphs[4].id)[0]
	var partial: Dictionary = admitted.resolve(weighing_tiles[0], activity)
	check(partial.status == "partial" and partial.tile.text == "weighing", "Reviewed Growth activity suffix forms weighing")
	check(not partial.get("tile", {}).get("mastery_eligible", true), "Weighing partial cannot grant mastery")
	check(admitted.resolve(weighing_tiles[0], result_noun).status == "invalid", "Result-noun ing cannot replace weighing activity")
	var whole: Dictionary = admitted.resolve(partial.get("tile", {}), scale)
	check(whole.status == "complete" and whole.tile.text == "weighing scale", "Reviewed Growth scale completes the selected device")
	check(whole.get("tile", {}).get("lexeme_ids", []) == [weighing.lexeme_id], "Shared scale preserves the Professional completed sense")
	var refrigerator: Dictionary = graphs.filter(func(g: Dictionary) -> bool: return g.text == "refrigerator")[0]
	var conveyor: Dictionary = graphs.filter(func(g: Dictionary) -> bool: return g.text == "conveyor belt")[0]
	whole = admitted.resolve(admitted.source_tiles(growth_graphs[5].id)[0], admitted.source_tiles(conveyor.id)[1])
	check(whole.status == "complete" and whole.tile.text == "refrigerator", "Actual atomic Growth base and reviewed Professional or form refrigerator")
	check(whole.get("tile", {}).get("lexeme_ids", []) == [refrigerator.lexeme_id], "Refrigerator completion keeps the appliance sense")
	var security_camera: Dictionary = graphs.filter(func(g: Dictionary) -> bool: return g.text == "security camera")[0]
	var security_tag: Dictionary = graphs.filter(func(g: Dictionary) -> bool: return g.text == "security tag")[0]
	var camera_tiles: Array = admitted.source_tiles(security_camera.id)
	var tag_tiles: Array = admitted.source_tiles(security_tag.id)
	for suffix_graph: Dictionary in [growth_graphs[2], growth_graphs[3]]:
		partial = admitted.resolve(camera_tiles[0], admitted.source_tiles(suffix_graph.id)[1])
		check(partial.status == "partial" and partial.tile.text == "security", "Actual Growth quality suffix preserves authored secure/security spelling")
		whole = admitted.resolve(partial.get("tile", {}), tag_tiles[2])
		check(whole.status == "complete" and whole.tile.text == "security tag", "Shared security partial completes the exact tag sense")
		check(whole.get("tile", {}).get("lexeme_ids", []) == [security_tag.lexeme_id], "Cross-security pieces preserve completed sense identity")
	var pending_graphs: Array = [record.original_held_candidate.before_morphology]
	for snapshot: Dictionary in record.scale_family_preimages:
		if snapshot.lexeme_id == weighing.lexeme_id:
			continue
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(snapshot.resource))
		var entry: Dictionary = document.lexemes.filter(func(e: Dictionary) -> bool: return e.id == snapshot.lexeme_id)[0]
		check(entry.morphology.review.status == "pending" and not Analysis.compile(entry.morphology).ok, "Other scale meaning remains pending: " + snapshot.lexeme_id)
		pending_graphs.append(entry.morphology)
	# The pending bypass is confined to negative substitution checks.
	var inspection := Resolver.new()
	check(inspection.configure(graphs + growth_graphs + pending_graphs, false), "Inspection can compare exact legacy scale parts without approving them")
	var target_tiles: Array = inspection.source_tiles(weighing.id)
	partial = inspection.resolve(target_tiles[0], target_tiles[1])
	for legacy: Dictionary in pending_graphs:
		var legacy_tiles: Array = inspection.source_tiles(legacy.id)
		for i in range(legacy.parts.size()):
			if legacy.parts[i].canonical_id == "morph.scale":
				var before: Dictionary = legacy_tiles[i].duplicate(true)
				check(inspection.resolve(partial.get("tile", {}), legacy_tiles[i]).status == "invalid", "Mixed legacy scale cannot enter corrected weighing target: " + legacy.lexeme_id)
				check(legacy_tiles[i] == before, "Rejected substitution preserves the original scale tile")

func _fourth_source(selected: RefCounted, graph: Dictionary, canonical: String) -> Dictionary:
	var matches: Array = selected.source_tiles(graph.id).filter(func(tile: Dictionary) -> bool: return tile.canonical == canonical)
	check(matches.size() == 1, "Actual graph supplies one exact constituent: " + graph.text + "/" + canonical)
	return matches[0] if matches.size() == 1 else {}

func _fourth_node(selected: RefCounted, graph: Dictionary, id: String, leaves: Dictionary) -> Dictionary:
	if leaves.has(id):
		return leaves[id]
	var nodes: Array = graph.nodes.filter(func(node: Dictionary) -> bool: return node.id == id)
	if nodes.is_empty():
		check(false, "Missing fourth-family authored node: " + graph.text + "/" + id)
		return {}
	var node: Dictionary = nodes[0]
	var joined: Dictionary = selected.resolve(_fourth_node(selected, graph, node.left, leaves), _fourth_node(selected, graph, node.right, leaves))
	check(joined.status in ["partial", "complete"] and joined.get("tile", {}).get("text") == node.surface, "Fourth-family authored node preserves its spelling: " + graph.text + "/" + id)
	return joined.get("tile", {})

func _fourth_whole(selected: RefCounted, graph: Dictionary) -> Dictionary:
	var tiles: Array = selected.source_tiles(graph.id)
	var leaves: Dictionary = {}
	for index in range(tiles.size()):
		leaves[graph.parts[index].id] = tiles[index]
	return _fourth_node(selected, graph, graph.roots[0], leaves)

func _check_fourth_families(graphs: Array, record: Dictionary) -> void:
	var by_text: Dictionary = {}
	for graph: Dictionary in graphs:
		by_text[graph.text] = graph
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	var growth: Dictionary = {}
	var growth_graphs: Array = []
	for id: String in ["enter", "stairs", "scales", "has", "sometimes", "later", "tractor", "escalator"]:
		var matches: Array = words.filter(func(word: Dictionary) -> bool: return word.id == id)
		check(matches.size() == 1, "One actual Growth vocabulary sense for fourth-ten donor: " + id)
		if matches.is_empty():
			return
		var word: Dictionary = matches[0]
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vocabulary/morphology/age-%02d.json" % word.min_age))
		var source_entry: Dictionary = document.entries.filter(func(entry: Dictionary) -> bool: return entry.id == id)[0]
		var decorated: Dictionary = Growth.decorate(word)
		var expected: Dictionary = source_entry.analysis.duplicate(true)
		expected.review = source_entry.review.duplicate(true)
		check(decorated.morphology_status == "reviewed" and decorated.get("morphology") == expected, "Actual Growth donor passes unchanged identity and source gates: " + id)
		if not decorated.get("morphology") is Dictionary:
			return
		growth[id] = decorated.morphology
		if id != "escalator":
			growth_graphs.append(decorated.morphology)
	var admitted := Resolver.new()
	check(admitted.configure(graphs + growth_graphs), "All persisted reviews and selected actual Growth donors configure without a bypass")
	var elevator: Dictionary = by_text.elevator
	var elevate: Dictionary = admitted.source_tiles(elevator.id)[0]
	for text: String in ["conveyor belt", "refrigerator"]:
		var suffix: Dictionary = _fourth_source(admitted, by_text[text], "-or")
		check(suffix.canonical_id == "affix.or.suffix", "Reviewed donor retains the instrument-or identity: " + text)
		var complete: Dictionary = admitted.resolve(elevate, suffix)
		check(complete.status == "complete" and complete.tile.text == "elevator" and complete.tile.lexeme_ids == [elevator.lexeme_id], "Reviewed instrument-or completes the selected elevator with authored final-e omission")
		check(complete.get("tile", {}).get("mastery_eligible", false), "Unassisted elevator composition retains its mastery route")
	for suffix: Dictionary in [_fourth_source(admitted, by_text["receipt printer"], "-er"), _fourth_source(admitted, growth.later, "-er"), _fourth_source(admitted, growth.tractor, "-or")]:
		check(admitted.resolve(elevate, suffix).status == "invalid", "Agent-er, comparative-er and the retained distinct Growth-or namespace cannot replace authored instrument-or")
	var entrance: Dictionary = by_text.entrance
	var enter: Dictionary = _fourth_source(admitted, growth.enter, "enter")
	var ance: Dictionary = _fourth_source(admitted, entrance, "-ance")
	var complete: Dictionary = admitted.resolve(enter, ance)
	check(complete.status == "complete" and complete.tile.text == "entrance" and complete.tile.lexeme_ids == [entrance.lexeme_id], "Actual Growth enter and authored nominal-ance complete entrance, preserving enter-to-entr spelling")
	check(complete.get("tile", {}).get("break_offsets", []) == [] and admitted.resolve(ance, enter).status == "invalid", "Entrance has no invented word break or reversed suffix join")
	var returns_counter: Dictionary = by_text["returns counter"]
	var return_part: Dictionary = _fourth_source(admitted, returns_counter, "return")
	var counter: Dictionary = _fourth_source(admitted, by_text.counter, "counter")
	for id: String in ["stairs", "scales"]:
		var plural: Dictionary = _fourth_source(admitted, growth[id], "-s")
		check(plural.canonical_id == "english.affix.s.plural", "Actual Growth donor supplies reviewed noun-plural-s: " + id)
		var partial: Dictionary = admitted.resolve(return_part, plural)
		check(partial.status == "partial" and partial.tile.text == "returns" and not partial.tile.mastery_eligible, "Noun-plural-s creates only the authored returns partial")
		complete = admitted.resolve(partial.get("tile", {}), counter)
		check(complete.status == "complete" and complete.tile.text == "returns counter" and complete.tile.lexeme_ids == [returns_counter.lexeme_id], "Growth noun-plural-s and reviewed counter complete only the merchandise-return sense")
	for id: String in ["has", "sometimes"]:
		var wrong_s: Dictionary = _fourth_source(admitted, growth[id], "-s")
		check(wrong_s.canonical_id != "english.affix.s.plural" and admitted.resolve(return_part, wrong_s).status == "invalid", "Third-person or adverbial-s cannot substitute for noun-plural-s: " + id)
	var pickup: Dictionary = by_text["pickup counter"]
	var pickup_tiles: Array = admitted.source_tiles(pickup.id)
	var picked: Dictionary = admitted.resolve(pickup_tiles[0], pickup_tiles[1])
	check(picked.status == "partial" and picked.tile.text == "pickup" and picked.tile.break_offsets == [] and not picked.tile.mastery_eligible, "Collection pickup uses the authored closed noun and grants no partial mastery")
	complete = admitted.resolve(picked.get("tile", {}), counter)
	check(complete.status == "complete" and complete.tile.text == "pickup counter" and complete.tile.break_offsets == [7.0] and complete.tile.lexeme_ids == [pickup.lexeme_id], "Reviewed counter completes pickup with the exact JSON numeric boundary and sense")

	var legacy: Dictionary = {}
	var legacy_graphs: Array = []
	for id: String in ["customer.buyer.n", "customer-order.customer-request-for-specified-goods.n", "service-desk.contact-function-coordinating-user-support.n", "attendance.presence-record.n", "clearance.unobstructed-space.n", "acceptance-criteria.agreed-success-conditions.n", "returns-area.designated-place-for-returned-goods.n", "counterclaim.claim-brought-against-party-who-brought-original-claim.n", "counterpart.separate-copy-of-document-used-for-parties-execution.n"]:
		var snapshots: Array = record.protected_related_entries.filter(func(snapshot: Dictionary) -> bool: return snapshot.entry.id == id)
		check(snapshots.size() == 1, "Fourth-ten provenance retains the exact legacy donor: " + id)
		if snapshots.is_empty():
			return
		var snapshot: Dictionary = snapshots[0]
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(snapshot.resource))
		var entry: Dictionary = document.lexemes.filter(func(item: Dictionary) -> bool: return item.id == id)[0]
		if id == "customer.buyer.n":
			var language_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/foundation-module01-language-first10-2026-10-16.json"))
			var language_patches: Array = language_record.patches.filter(func(patch: Dictionary) -> bool: return patch.id == id)
			check(language_patches.size() == 1, "Exactly one scoped Foundation customer language patch is retained")
			if language_patches.size() != 1:
				return
			var language_patch: Dictionary = language_patches[0]
			check(entry == language_patch.after, "Live customer equals the exact later Foundation language entry")
			if entry != language_patch.after:
				return
			entry = language_patch.before.duplicate(true)
		check(entry == snapshot.entry, "Persisted legacy entry equals its protected preimage: " + id)
		check(entry.morphology.review.status == "pending" and not Analysis.compile(entry.morphology).ok, "Related legacy graph remains pending and fails normal compiler admission: " + id)
		legacy[id] = entry.morphology
		legacy_graphs.append(entry.morphology)
	var retained_sources: Array = admitted.source_tiles(entrance.id)
	check(not admitted.configure(legacy_graphs), "Default resolver still refuses all pending fourth-family legacy donors")
	check(admitted.source_tiles(entrance.id) == retained_sources, "Failed pending configuration retains the admitted reviewed catalog")
	var inspection := Resolver.new()
	check(inspection.configure(graphs + growth_graphs + legacy_graphs, false), "Explicit inspection compares retained legacy families without approving their graphs")
	for id: String in ["attendance.presence-record.n", "clearance.unobstructed-space.n"]:
		complete = inspection.resolve(_fourth_source(inspection, growth.enter, "enter"), _fourth_source(inspection, legacy[id], "-ance"))
		check(complete.status == "complete" and complete.tile.text == "entrance" and complete.tile.lexeme_ids == [entrance.lexeme_id], "Existing nominal-ance component supports the selected entrance without promoting its legacy graph")
	check(inspection.resolve(_fourth_source(inspection, growth.enter, "enter"), _fourth_source(inspection, legacy["acceptance-criteria.agreed-success-conditions.n"], "ance")).status == "invalid", "Retained unhyphenated legacy ance remains distinct")
	var legacy_returns: Dictionary = inspection.resolve(_fourth_source(inspection, returns_counter, "return"), _fourth_source(inspection, legacy["returns-area.designated-place-for-returned-goods.n"], "s"))
	var reviewed_returns: Dictionary = inspection.resolve(_fourth_source(inspection, returns_counter, "return"), _fourth_source(inspection, returns_counter, "-s"))
	check(legacy_returns.status == "partial" and legacy_returns.tile.text == "returns" and not legacy_returns.tile.mastery_eligible, "Explicit inspection preserves the authored legacy returns-area intermediate without mastery")
	check(legacy_returns.tile.candidates == [{"analysis_id": legacy["returns-area.designated-place-for-returned-goods.n"].id, "node_id": "n1"}], "Generic-s intermediate belongs only to its pending legacy analysis")
	check(legacy_returns.tile.signature != reviewed_returns.tile.signature, "Equal returns spellings preserve distinct generic-s and noun-plural-s states")
	check(inspection.resolve(legacy_returns.tile, counter).status == "invalid", "Legacy generic-s intermediate cannot complete the reviewed returns counter")
	var help_desk: Dictionary = by_text["customer service desk"]
	var help_tiles: Array = inspection.source_tiles(help_desk.id)
	var current_customer: Dictionary = _fourth_source(inspection, legacy["customer-order.customer-request-for-specified-goods.n"], "customer")
	var historical_customer: Dictionary = _fourth_whole(inspection, legacy["customer.buyer.n"])
	check(current_customer.signature == help_tiles[0].signature and current_customer.text == "customer", "Current whole buyer customer shares the authored component identity")
	check(historical_customer.text == current_customer.text and historical_customer.signature != current_customer.signature, "Historical custom-plus-er completion remains a distinct state despite equal spelling")
	check(inspection.resolve(historical_customer, help_tiles[1]).status == "invalid", "Historical derived customer cannot replace the current whole customer constituent")
	var customer_service: Dictionary = inspection.resolve(current_customer, help_tiles[1])
	check(customer_service.status == "partial" and customer_service.tile.text == "customer service" and not customer_service.tile.mastery_eligible, "Current customer supports only the authored customer-service intermediate")
	complete = inspection.resolve(customer_service.get("tile", {}), help_tiles[2])
	check(complete.status == "complete" and complete.tile.text == "customer service desk" and complete.tile.lexeme_ids == [help_desk.lexeme_id], "Whole customer substitution preserves the selected help-counter sense")
	var service_desk: Dictionary = _fourth_whole(inspection, legacy["service-desk.contact-function-coordinating-user-support.n"])
	check(inspection.resolve(help_tiles[0], service_desk).status == "invalid", "Customer plus complete service desk cannot invent an alternate authored bracket")
	for id: String in ["counterclaim.claim-brought-against-party-who-brought-original-claim.n", "counterpart.separate-copy-of-document-used-for-parties-execution.n"]:
		var opposing_counter: Dictionary = _fourth_source(inspection, legacy[id], "counter")
		var returns_partial: Dictionary = inspection.resolve(_fourth_source(inspection, returns_counter, "return"), _fourth_source(inspection, returns_counter, "-s"))
		check(inspection.resolve(returns_partial.get("tile", {}), opposing_counter).status == "invalid", "Opposing or corresponding counter-prefix cannot replace the service surface")
	for graph: Dictionary in legacy_graphs:
		check(graph.review.status == "pending" and not Analysis.compile(graph).ok, "Inspection leaves legacy admission unchanged: " + graph.lexeme_id)

	var professional_escalator: Dictionary = by_text.escalator
	var selected_professional := Resolver.new()
	check(selected_professional.configure([professional_escalator]), "Independently reviewed Professional escalator configures through normal gate")
	var professional_tile: Dictionary = selected_professional.source_tiles(professional_escalator.id)[0]
	check(professional_tile.complete and professional_tile.lexeme_ids == [professional_escalator.lexeme_id] and not professional_tile.mastery_eligible, "Selected Professional atomic escalator exposes its exact sense without composition mastery")
	var selected_growth := Resolver.new()
	check(selected_growth.configure([growth.escalator]), "Actual reviewed Growth escalator configures through normal gate")
	var growth_tile: Dictionary = selected_growth.source_tiles(growth.escalator.id)[0]
	check(growth_tile.complete and growth_tile.lexeme_ids == [growth.escalator.lexeme_id] and not growth_tile.mastery_eligible, "Selected Growth atomic escalator exposes its exact sense without composition mastery")
	check(professional_tile.signature == growth_tile.signature and professional_escalator.lexeme_id != growth.escalator.lexeme_id, "Shared atomic escalator identity preserves distinct completed lexical senses")
	var collision := Resolver.new()
	check(collision.configure([professional_escalator, growth.escalator]), "Both independently reviewed escalator senses configure in an explicit collision catalog")
	var ambiguous: Dictionary = collision.source_tiles(professional_escalator.id)[0]
	check(ambiguous.lexeme_ids.size() == 2 and professional_escalator.lexeme_id in ambiguous.lexeme_ids and growth.escalator.lexeme_id in ambiguous.lexeme_ids and not ambiguous.complete and not ambiguous.mastery_eligible, "Combined atomic escalator retains both senses as ambiguous with no complete tile or mastery")
	var plan: Dictionary = collision.completion_plan([ambiguous])
	check(plan.status == "unavailable" and plan.reason == "no_completion_path" and plan.steps.is_empty(), "Ambiguous atomic escalator supplies no completion plan or automatic cross-corpus route")

func _fifth_has_analysis(tile: Dictionary, analysis_id: String, node_id: String = "") -> bool:
	for candidate: Dictionary in tile.get("candidates", []):
		if candidate.analysis_id == analysis_id and (node_id.is_empty() or candidate.node_id == node_id):
			return true
	return false

func _check_fifth_families(graphs: Array, record: Dictionary) -> void:
	var by_text: Dictionary = {}
	for graph: Dictionary in graphs:
		by_text[graph.text] = graph
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	var growth: Dictionary = {}
	var growth_graphs: Array = []
	for id: String in ["window", "bag", "touch", "keyboard", "mop", "bowling", "key", "safe", "sunscreen", "stuffing", "wrap"]:
		var matches: Array = words.filter(func(word: Dictionary) -> bool: return word.id == id)
		check(matches.size() == 1, "One actual current Growth word for fifth-family donor: " + id)
		if matches.size() != 1:
			return
		var word: Dictionary = matches[0]
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vocabulary/morphology/age-%02d.json" % word.min_age))
		var entries: Array = document.entries.filter(func(entry: Dictionary) -> bool: return entry.id == id)
		check(entries.size() == 1, "One actual current Growth source analysis: " + id)
		if entries.size() != 1:
			return
		var expected: Dictionary = entries[0].analysis.duplicate(true)
		expected.review = entries[0].review.duplicate(true)
		var decorated: Dictionary = Growth.decorate(word)
		check(decorated.get("morphology_status") == "reviewed" and decorated.get("morphology") == expected, "Actual reviewed Growth donor and source review are unchanged: " + id)
		if not decorated.get("morphology") is Dictionary:
			return
		growth[id] = decorated.morphology
		if id != "mop":
			growth_graphs.append(decorated.morphology)
	var admitted := Resolver.new()
	check(admitted.configure(graphs + growth_graphs), "All fifty persisted reviews and selected actual Growth donors pass the normal gate")
	for row: Array in [["window display", "window", "window"], ["shopping bag", "bag", "bag"], ["touchscreen", "touch", "touch"], ["keypad", "keyboard", "key"], ["shopping bag", "bowling", "-ing"]]:
		var selected: Dictionary = _fourth_source(admitted, by_text[row[0]], row[2])
		var actual: Dictionary = _fourth_source(admitted, growth[row[1]], row[2])
		check(selected.signature == actual.signature, "Fifth-family component reuses the exact actual Growth signature: " + row[1])
	for row: Array in [["window display", "window", "window", "display"], ["touchscreen", "touch", "touch", "screen"], ["keypad", "keyboard", "key", "pad"]]:
		var graph: Dictionary = by_text[row[0]]
		var joined: Dictionary = admitted.resolve(_fourth_source(admitted, growth[row[1]], row[2]), _fourth_source(admitted, graph, row[3]))
		var tile: Dictionary = joined.get("tile", {})
		check(joined.status == "complete" and tile.lexeme_ids == [graph.lexeme_id] and _fifth_has_analysis(tile, graph.id, graph.roots[0]), "Actual Growth donor completes the exact selected fifth-family analysis: " + graph.text)
	var shopping: Dictionary = by_text["shopping bag"]
	var partial: Dictionary = admitted.resolve(_fourth_source(admitted, shopping, "shop"), _fourth_source(admitted, growth.bowling, "-ing"))
	check(partial.status == "partial" and partial.tile.text == "shopping" and partial.tile.break_offsets == [] and not partial.tile.mastery_eligible, "Actual activity-ing creates authored doubled-p shopping without partial mastery")
	var completed: Dictionary = admitted.resolve(partial.get("tile", {}), _fourth_source(admitted, growth.bag, "bag"))
	check(completed.status == "complete" and completed.tile.text == "shopping bag" and completed.tile.break_offsets == [9.0] and completed.tile.lexeme_ids == [shopping.lexeme_id] and _fifth_has_analysis(completed.tile, shopping.id, shopping.roots[0]), "Actual Growth activity-ing and bag complete the exact selected shopping-bag analysis")
	for row: Array in [["keypad", "key", "key", "pad", true], ["cash safe", "safe", "safe", "cash", false], ["touchscreen", "sunscreen", "screen", "touch", false], ["gift wrap", "wrap", "wrap", "gift", false], ["shopping bag", "stuffing", "-ing", "shop", false]]:
		var graph: Dictionary = by_text[row[0]]
		var wrong: Dictionary = _fourth_source(admitted, growth[row[1]], row[2])
		var selected: Dictionary = _fourth_source(admitted, graph, row[2])
		var other: Dictionary = _fourth_source(admitted, graph, row[3])
		var refused: Dictionary = admitted.resolve(wrong, other) if row[4] else admitted.resolve(other, wrong)
		check(wrong.signature != selected.signature and refused.status == "invalid" and not _fifth_has_analysis(refused.get("tile", {}), graph.id), "Retained Growth lock-key, adjective-safe, shield-screen, action-wrap or result-ing cannot reach the selected analysis: " + row[1])

	var legacy: Dictionary = {}
	var legacy_graphs: Array = []
	for text: String in ["shopping bag", "keypad", "touchscreen"]:
		var patches: Array = record.patches.filter(func(patch: Dictionary) -> bool: return patch.after.text == text)
		check(patches.size() == 1, "Fifth provenance retains the replaced exact target: " + text)
		if patches.size() != 1:
			return
		var previous: Dictionary = patches[0].before.morphology
		check(previous.review.status == "pending" and not Analysis.compile(previous).ok, "Retired target graph remains pending in its exact provenance preimage: " + text)
		legacy[text] = previous
		legacy_graphs.append(previous)
	var broad: Dictionary = {}
	for id: String in ["safe.free-from-unacceptable-danger.adj", "sunscreen.product-intended-to-reduce-ultraviolet-exposure.n", "wrap.cover-item.v"]:
		var snapshots: Array = record.protected_related_entries.filter(func(snapshot: Dictionary) -> bool: return snapshot.entry.id == id)
		check(snapshots.size() == 1, "Fifth provenance protects the related broad Professional donor: " + id)
		if snapshots.size() != 1:
			return
		var snapshot: Dictionary = snapshots[0]
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(snapshot.resource))
		var entry: Dictionary = document.lexemes.filter(func(item: Dictionary) -> bool: return item.id == id)[0]
		check(entry == snapshot.entry and entry.morphology.review.status == "pending" and not Analysis.compile(entry.morphology).ok, "Related broad Professional graph remains its exact pending preimage: " + id)
		broad[id] = entry.morphology
		legacy_graphs.append(entry.morphology)
	var retained: Array = admitted.source_tiles(shopping.id)
	check(not admitted.configure(legacy_graphs) and admitted.source_tiles(shopping.id) == retained, "Default pending rejection preserves the admitted fifth-family catalog")
	var inspection := Resolver.new()
	check(inspection.configure(graphs + growth_graphs + legacy_graphs, false), "Explicit diagnostic bypass compares retired and broad graphs without approving them")
	for text: String in ["shopping bag", "keypad", "touchscreen"]:
		var old_graph: Dictionary = legacy[text]
		var old_tile: Dictionary = _fourth_whole(inspection, old_graph)
		check(old_tile.get("complete", false) and old_tile.get("lexeme_ids") == [by_text[text].lexeme_id] and _fifth_has_analysis(old_tile, old_graph.id, old_graph.roots[0]) and not _fifth_has_analysis(old_tile, by_text[text].id), "Legacy same-lexeme completion retains only its old analysis attribution: " + text)
	var old_shopping: Dictionary = legacy["shopping bag"]
	var old_partial: Dictionary = inspection.resolve(_fourth_source(inspection, old_shopping, "shop"), _fourth_source(inspection, old_shopping, "-ing"))
	check(old_partial.status == "partial" and old_partial.tile.text == "shopping" and not old_partial.tile.mastery_eligible and not _fifth_has_analysis(old_partial.tile, shopping.id), "Legacy generic-ing shopping is partial and never acquires the selected activity analysis")
	for row: Array in [["cash safe", "safe.free-from-unacceptable-danger.adj", "cash", "safe"], ["touchscreen", "sunscreen.product-intended-to-reduce-ultraviolet-exposure.n", "touch", "screen"], ["gift wrap", "wrap.cover-item.v", "gift", "wrap"]]:
		var graph: Dictionary = by_text[row[0]]
		var result: Dictionary = inspection.resolve(_fourth_source(inspection, graph, row[2]), _fourth_source(inspection, broad[row[1]], row[3]))
		check(result.status == "complete" and result.tile.lexeme_ids == [graph.lexeme_id] and _fifth_has_analysis(result.tile, graph.id, graph.roots[0]), "Intentional broad Professional related-base compatibility preserves the selected completed sense: " + row[3])

	var professional_mop: Dictionary = by_text.mop
	var selected_professional := Resolver.new()
	check(selected_professional.configure([professional_mop]), "Selected reviewed Professional mop passes the normal gate")
	var professional_tile: Dictionary = selected_professional.source_tiles(professional_mop.id)[0]
	check(professional_tile.complete and professional_tile.lexeme_ids == [professional_mop.lexeme_id] and not professional_tile.mastery_eligible, "Selected Professional atomic mop has its exact identity without composition mastery")
	var selected_growth := Resolver.new()
	check(selected_growth.configure([growth.mop]), "Actual reviewed Growth mop passes the normal gate")
	var growth_tile: Dictionary = selected_growth.source_tiles(growth.mop.id)[0]
	check(growth_tile.complete and growth_tile.lexeme_ids == [growth.mop.lexeme_id] and not growth_tile.mastery_eligible and growth_tile.signature == professional_tile.signature, "Actual Growth atomic mop retains its own lexical identity and shares the selected tool signature")
	check(selected_professional.configure([professional_mop, growth.mop]), "Both actual reviewed mop senses configure without renaming either identity")
	var ambiguous: Dictionary = selected_professional.source_tiles(professional_mop.id)[0]
	check(ambiguous.lexeme_ids.size() == 2 and professional_mop.lexeme_id in ambiguous.lexeme_ids and growth.mop.lexeme_id in ambiguous.lexeme_ids and ambiguous.lexeme_id == "" and not ambiguous.complete and not ambiguous.mastery_eligible, "Combined mop is a source ambiguity retaining both lexical IDs with no complete identity or mastery")
	check(_fifth_has_analysis(ambiguous, professional_mop.id, professional_mop.roots[0]) and _fifth_has_analysis(ambiguous, growth.mop.id, growth.mop.roots[0]) and professional_tile.complete and professional_tile.lexeme_ids == [professional_mop.lexeme_id], "Fresh mop sources retain both analyses while pre-switch source snapshots keep their original identity")
	var plan: Dictionary = selected_professional.completion_plan([ambiguous])
	check(plan.status == "unavailable" and plan.reason == "no_completion_path" and plan.steps.is_empty(), "Atomic mop ambiguity supplies no completion plan or automatic cross-corpus route")
	var boundaries: Dictionary = {"store directory": [6.0], "window display": [7.0], "gift wrap": [5.0], "shopping bag": [9.0], "receipt roll": [8.0], "touchscreen": [], "keypad": [], "cash safe": [5.0], "mop": [], "waste bin": [6.0]}
	for text: String in boundaries:
		var graph: Dictionary = by_text[text]
		var tile: Dictionary = _fourth_whole(admitted, graph)
		check(tile.get("text") == text and tile.get("break_offsets") == boundaries[text] and _fifth_has_analysis(tile, graph.id, graph.roots[0]), "Fifth-family exact spelling, word boundaries, and selected root attribution: " + text)
	for spelling: String in ["wrapping paper", "touch screen", "trash can"]:
		check(not by_text.has(spelling), "Accepted alternate form has no newly authored exact graph: " + spelling)

func _r04_exact(tile: Dictionary, graph: Dictionary) -> bool:
	return tile.get("complete", false) and tile.get("text", "") == graph.text and tile.get("lexeme_ids", []) == [graph.lexeme_id] and _fifth_has_analysis(tile, graph.id, graph.roots[0])

func _r04_complete(graph: Dictionary, replacements: Dictionary = {}, assisted: bool = false) -> Dictionary:
	var leaves: Array = resolver.source_tiles(graph.id)
	var states: Dictionary = {}
	if leaves.size() != graph.parts.size():
		return {}
	for index: int in range(leaves.size()):
		var part: Dictionary = graph.parts[index]
		var tile: Dictionary = replacements.get(part.id, leaves[index]).duplicate(true)
		if assisted:
			tile.assisted = true
		states[part.id] = tile
	for node: Dictionary in graph.nodes:
		var result: Dictionary = resolver.resolve(states[node.left], states[node.right])
		if result.status not in ["partial", "complete"]:
			return {}
		states[node.id] = result.tile
	return states.get(graph.roots[0], {})

func _r04_part(graph: Dictionary, canonical: String) -> Dictionary:
	for tile: Dictionary in resolver.source_tiles(graph.id):
		if tile.canonical == canonical:
			return tile
	return {}

func _r04_protected_graph(record: Dictionary, id: String) -> Dictionary:
	var rows: Array = record.protected_related_entries.filter(func(row: Dictionary) -> bool: return row.entry.id == id)
	check(rows.size() == 1, "Retail04 has one protected complete record: " + id)
	if rows.size() != 1:
		return {}
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(rows[0].resource))
	var current: Array = envelope.lexemes.filter(func(entry: Dictionary) -> bool: return entry.id == id)
	check(current.size() == 1 and current[0] == rows[0].entry, "Retail04 protected actual record remains exact: " + id)
	return current[0].morphology if current.size() == 1 else {}

func _check_retail04_first10() -> void:
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/retail-module04-morphology-first10-2026-10-16.json"))
	var by_text: Dictionary = {}
	var graphs: Array = []
	for patch: Dictionary in record.patches:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(patch.origin))
		var entries: Array = document.lexemes.filter(func(entry: Dictionary) -> bool: return entry.id == patch.id)
		check(entries.size() == 1 and entries[0] == patch.after, "Retail04 persisted full record equals exact acceptance: " + patch.id)
		if entries.size() != 1:
			continue
		var graph: Dictionary = entries[0].morphology
		check(Analysis.compile(graph).ok and resolver.configure([graph]), "Retail04 ordinary reviewed admission: " + graph.text)
		var pending: Dictionary = graph.duplicate(true)
		pending.review.status = "pending"
		check(not Analysis.compile(pending).ok, "Retail04 pending status never inherits admission: " + graph.text)
		var result: Dictionary = _r04_complete(graph)
		check(_r04_exact(result, graph), "Retail04 exact analysis, root, spelling and sense: " + graph.text)
		check(result.get("mastery_eligible", false) == (graph.parts.size() > 1), "Retail04 atomic exposure has no composition mastery: " + graph.text)
		var helped: Dictionary = _r04_complete(graph, {}, true)
		check(_r04_exact(helped, graph) and not helped.get("mastery_eligible", true), "Retail04 assisted exposure or composition has no mastery: " + graph.text)
		by_text[graph.text] = graph
		graphs.append(graph)
		if patch.before.morphology != null:
			var old: Dictionary = patch.before.morphology
			check(not resolver.configure([old]) and resolver.configure([old], false), "Retail04 old candidate still requires inspection: " + graph.text)
			var old_result: Dictionary = _r04_complete(old)
			check(_r04_exact(old_result, old) and not _fifth_has_analysis(old_result, graph.id), "Retail04 old lexical ID cannot claim new exact graph: " + graph.text)
			check(not old_result.get("mastery_eligible", true), "Retail04 old atomic graph has no mastery: " + graph.text)
			check(resolver.configure([old, graph], false), "Retail04 old and accepted exact analyses coexist for inspection: " + graph.text)
			var selected: Dictionary = resolver.source_tiles(graph.id)[0]
			var legacy: Dictionary = resolver.source_tiles(old.id)[0]
			check(_fifth_has_analysis(selected, graph.id, graph.roots[0]) and _fifth_has_analysis(legacy, old.id, old.roots[0]), "Retail04 paired source attribution remains explicit: " + graph.text)
			if graph.text == "fabric":
				check(selected.signature != legacy.signature and not _fifth_has_analysis(legacy, graph.id), "Retail04 old fabric family stays separate without migration")
	check(graphs.size() == 10 and resolver.configure(graphs), "Retail04 ten reviewed production graphs configure normally")
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	var growth: Dictionary = {}
	for id: String in ["attachment", "environment", "material", "fabric", "sort", "ant"]:
		var actual: Array = words.filter(func(word: Dictionary) -> bool: return word.id == id)
		check(actual.size() == 1, "Retail04 actual Growth source exists: " + id)
		if actual.size() != 1:
			return
		var decorated: Dictionary = Growth.decorate(actual[0])
		check(decorated.morphology_status == "reviewed", "Retail04 actual Growth decoration admits source: " + id)
		growth[id] = decorated.morphology
	var assortment: Dictionary = by_text.assortment
	check(resolver.configure([assortment]), "Retail04 assortment isolated reviewed catalog")
	var base: Dictionary = resolver.source_tiles(assortment.id)[0]
	var ending: Dictionary = resolver.source_tiles(assortment.id)[1]
	check(resolver.resolve(ending, base).status == "invalid", "Retail04 reversed assortment order rejected")
	for part: Dictionary in [base, ending]:
		check(not part.complete and not part.mastery_eligible and resolver.completion_plan([part]).status == "unavailable", "Retail04 lone assortment component has no mastery or completion")
	for index: int in [0, 1]:
		var helped: Dictionary = (base if index == 0 else ending).duplicate(true)
		helped.assisted = true
		var result: Dictionary = _r04_complete(assortment, {assortment.parts[index].id: helped})
		check(_r04_exact(result, assortment) and not result.mastery_eligible, "Retail04 either assisted component removes mastery")
	for donor_ids: Array in [["attachment"], ["environment"], ["attachment", "environment"]]:
		var catalog: Array = [assortment]
		for id: String in donor_ids:
			catalog.append(growth[id])
		check(resolver.configure(catalog), "Retail04 real reviewed result-ment donors configure normally")
		for id: String in donor_ids:
			var donor: Dictionary = growth[id]
			var suffix: Dictionary = _r04_part(donor, "-ment")
			check(suffix.canonical_id == "english.affix.ment.result" and suffix.text == "ment", "Retail04 actual result-ment identity and surface")
			var result: Dictionary = _r04_complete(assortment, {"p2": suffix})
			check(_r04_exact(result, assortment) and result.break_offsets == [], "Retail04 donor reaches only exact assortment root")
			check(_r04_exact(_r04_complete(donor), donor), "Retail04 complete donor sense stays distinct")
	for item: Array in [["appointment.arranged-meeting.n", "-ment", "p2"], ["statement.program-instruction-unit.n", "ment", "p2"], ["sort.group-by-kind.v", "sort", "p1"]]:
		var wrong_graph: Dictionary = _r04_protected_graph(record, item[0])
		check(wrong_graph.review.status == "pending" and resolver.configure([assortment, wrong_graph], false), "Retail04 unchanged generic family is inspection only")
		var wrong: Dictionary = _r04_part(wrong_graph, item[1])
		check(not _r04_exact(_r04_complete(assortment, {item[2]: wrong}), assortment), "Retail04 spelling alone cannot donate assort or result-ment")
	check(resolver.configure([assortment, growth.sort]), "Retail04 actual Growth sort configures normally")
	check(not _r04_exact(_r04_complete(assortment, {"p1": resolver.source_tiles(growth.sort.id)[0]}), assortment), "Retail04 sort cannot substitute for assort")
	var numerical_range: Dictionary = _r04_protected_graph(record, "range.maximum-minus-minimum.n")
	for pair: Array in [[by_text.material, growth.material], [by_text.fabric, growth.fabric], [by_text.range, numerical_range]]:
		var chosen: Dictionary = pair[0]
		var other: Dictionary = pair[1]
		check(resolver.configure(pair, false), "Retail04 atomic collision catalog configures for inspection")
		var tile: Dictionary = resolver.source_tiles(chosen.id)[0]
		check(tile.lexeme_ids.size() == 2 and chosen.lexeme_id in tile.lexeme_ids and other.lexeme_id in tile.lexeme_ids, "Retail04 ambiguous source retains both complete lexical identities")
		check(not tile.complete and tile.lexeme_id == "" and not tile.mastery_eligible, "Retail04 ambiguous atomic source grants no arbitrary completion or mastery")
		check(_fifth_has_analysis(tile, chosen.id, chosen.roots[0]) and _fifth_has_analysis(tile, other.id, other.roots[0]), "Retail04 ambiguous source retains exact analysis/root attribution")
		check(resolver.completion_plan([tile]).status == "unavailable", "Retail04 atomic source ambiguity offers no automatic completion")
	var color: Dictionary = by_text.color
	check(resolver.configure([color]), "Retail04 exact color graph configures")
	var color_tile: Dictionary = resolver.source_tiles(color.id)[0]
	check(color_tile.text == "color" and _r04_exact(color_tile, color), "Retail04 color root does not silently author colour")
	var spelling_only: Dictionary = color.duplicate(true)
	spelling_only.text = "colour"
	check(not Analysis.compile(spelling_only).ok, "Retail04 language variant needs its own exact graph")
