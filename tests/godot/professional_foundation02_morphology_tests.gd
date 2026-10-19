extends SceneTree

const Analysis = preload("res://scripts/morphology_analysis.gd")
const Resolver = preload("res://scripts/morphology_resolver.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _read(resource: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(resource))

func _run() -> void:
	const MODULE: String = "res://data/professional/lexemes/foundation-module02.json"
	const RECORD: String = "res://data/professional/provenance/foundation-module02-morphology-2026-10-17.json"
	check(FileAccess.get_sha256(MODULE) == "7d6c2e941d9b5b6c3490c0155f01ecf8fa42ff4ccf998b552aadb56c4cabfa64", "Exact current Foundation02 accepted assembly")
	check(FileAccess.get_sha256(RECORD) == "8f2944a6129662d856003b08b8638fda6399db782e7401e2eac277cc4de2c803", "Exact Foundation02 source acceptance provenance")
	var document: Dictionary = _read(MODULE)
	var record: Dictionary = _read(RECORD)
	var graphs: Array = []
	var by_text: Dictionary = {}
	var counts: Dictionary = {}
	for entry: Dictionary in document.lexemes:
		var graph: Dictionary = entry.morphology
		var patches: Array = record.patches.filter(func(p: Dictionary) -> bool: return p.lexeme_id == entry.id)
		if not patches.is_empty():
			check(patches.size() == 1 and graph == patches[0].proposed_morphology, "Current graph equals the exact accepted proposal: " + entry.text)
		else:
			check(entry.id in ["collect.bring-together.v", "inform.give-information.v", "ensure.make-certain.v"], "Only the three existing reviewed graphs are preserved")
		check(Analysis.compile(graph).ok, "Normal reviewed compilation: " + entry.text)
		var pending: Dictionary = graph.duplicate(true)
		pending.review.status = "pending"
		check(not Analysis.compile(pending).ok, "Pending clones cannot retain admission: " + entry.text)
		graphs.append(graph)
		by_text[entry.text] = graph
		counts[graph.kind] = int(counts.get(graph.kind, 0)) + 1
	check(graphs.size() == 50 and counts == {"atomic":34, "morphological":16}, "All fifty actual Foundation02 treatments are included")
	var selected := Resolver.new()
	check(selected.configure(graphs), "Every accepted current graph configures through the normal review gate")
	for graph: Dictionary in graphs:
		var pieces: Array = selected.source_tiles(graph.id)
		check(pieces.size() == graph.parts.size(), "Only complete authored source units are supplied: " + graph.text)
		for index in range(pieces.size()):
			check(pieces[index].text == graph.parts[index].surface and not pieces[index].mastery_eligible, "Readable source surface with no uncomposed mastery: " + graph.text)
		if graph.kind == "atomic":
			check(pieces.size() == 1 and pieces[0].complete and pieces[0].lexeme_ids == [graph.lexeme_id], "Atomic treatment is a complete exact-sense exposure: " + graph.text)
			check(pieces[0].break_offsets == graph.parts[0].get("break_offsets", []), "Atomic display keeps only authored boundaries: " + graph.text)
			continue
		check(pieces.size() == 2 and graph.nodes.size() == 1, "Foundation02 multipart lessons use the accepted two-source graph: " + graph.text)
		var complete: Dictionary = selected.resolve(pieces[0], pieces[1])
		check(complete.status == "complete", "The ordered real parts compose: " + graph.text)
		if complete.status != "complete":
			continue
		check(complete.tile.text == graph.text and complete.tile.lexeme_ids == [graph.lexeme_id] and complete.tile.mastery_eligible, "Manual composition retains the exact spelling and one selected sense: " + graph.text)
		check(complete.tile.break_offsets == graph.nodes[0].break_offsets, "Authored irregular boundary survives composition: " + graph.text)
		check(selected.resolve(pieces[1], pieces[0]).status == "invalid", "Reversed order cannot complete the word: " + graph.text)
		pieces[0].assisted = true
		var assisted: Dictionary = selected.resolve(pieces[0], pieces[1])
		check(assisted.status == "complete" and assisted.tile.assisted and not assisted.tile.mastery_eligible, "Assisted completion never claims independent mastery: " + graph.text)
	_check_scoped_families(graphs, by_text)
	print("Professional Foundation02 morphology: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_scoped_families(graphs: Array, by_text: Dictionary) -> void:
	var selected := Resolver.new()
	check(selected.configure(graphs), "Current Foundation02 families configure together")
	var replacement: Array = selected.source_tiles(by_text.replace.id)
	var reschedule: Array = selected.source_tiles(by_text.reschedule.id)
	var reject: Array = selected.source_tiles(by_text.reject.id)
	check(replacement[0].signature == reschedule[0].signature and replacement[0].signature != reject[0].signature, "Again/anew and refusal-back retain distinct re identities")
	var changed: Dictionary = selected.resolve(replacement[0], reschedule[1])
	check(changed.status == "complete" and changed.tile.lexeme_ids == [by_text.reschedule.lexeme_id], "A compatible re donor completes only the selected scheduling sense")
	changed = selected.resolve(reschedule[0], replacement[1])
	check(changed.status == "complete" and changed.tile.lexeme_ids == [by_text.replace.lexeme_id], "Compatible re reuse works in the reverse donor direction")
	check(selected.resolve(reject[0], replacement[1]).status == "invalid" and selected.resolve(replacement[0], reject[1]).status == "invalid", "Same-spelled back and again prefixes cannot substitute")
	var foundation01: Dictionary = _read("res://data/professional/lexemes/foundation-module01.json")
	var supervisor: Dictionary = foundation01.lexemes.filter(func(e: Dictionary) -> bool: return e.text == "supervisor")[0].morphology
	var signature: Dictionary = foundation01.lexemes.filter(func(e: Dictionary) -> bool: return e.text == "signature")[0].morphology
	var retail: Dictionary = _read("res://data/professional/lexemes/retail-pilot.json")
	var shopping_bag: Dictionary = retail.lexemes.filter(func(e: Dictionary) -> bool: return e.id == "shopping-bag.goods-carrier.n")[0].morphology
	check(selected.configure(graphs + [supervisor, signature, shopping_bag]), "Reviewed neighboring or, ure and ing families coexist normally")
	var error_parts: Array = selected.source_tiles(by_text.error.id)
	var supervisor_parts: Array = selected.source_tiles(supervisor.id)
	check(error_parts[1].text == supervisor_parts[1].text and error_parts[1].signature != supervisor_parts[1].signature, "State/activity or and agent or keep separate meanings")
	check(selected.resolve(error_parts[0], supervisor_parts[1]).status == "invalid" and selected.resolve(supervisor_parts[0], error_parts[1]).status == "invalid", "Agent suffix substitution fails in both directions")
	var procedure: Array = selected.source_tiles(by_text.procedure.id)
	var signature_parts: Array = selected.source_tiles(signature.id)
	var signate: Dictionary = selected.resolve(signature_parts[0], signature_parts[1])
	check(signate.status == "partial", "Actual signature exposes its authored bound intermediate")
	check(procedure[1].text == signature_parts[2].text and procedure[1].signature != signature_parts[2].signature, "Process ure and signature result ure are separate")
	check(selected.resolve(procedure[0], signature_parts[2]).status == "invalid", "Written-result ure cannot compose the agreed-method procedure")
	if signate.status == "partial":
		check(selected.resolve(signate.tile, procedure[1]).status == "invalid", "Process ure cannot compose signature")
	var missing: Array = selected.source_tiles(by_text.missing.id)
	var shopping: Array = selected.source_tiles(shopping_bag.id)
	check(missing[1].text == shopping[1].text and missing[1].signature != shopping[1].signature, "Adjectival absence ing and shopping activity ing stay distinct")
	check(selected.resolve(missing[0], shopping[1]).status == "invalid" and selected.resolve(shopping[0], missing[1]).status == "invalid", "Same-spelled ing suffixes cannot substitute across the selected meanings")
