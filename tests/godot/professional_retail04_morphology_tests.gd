extends SceneTree

const Analysis = preload("res://scripts/morphology_analysis.gd")
const Resolver = preload("res://scripts/morphology_resolver.gd")
const Growth = preload("res://scripts/growth_morphology.gd")
var checks: int = 0
var failures: int = 0
var selected := Resolver.new()

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _read(resource: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(resource))

func _growth(age: int, text: String) -> Dictionary:
	var document := _read("res://data/vocabulary/morphology/age-%02d.json" % age)
	var entry: Dictionary = document.entries.filter(func(row: Dictionary) -> bool: return row.text == text)[0]
	var decorated: Dictionary = Growth.decorate(entry)
	check(decorated.morphology_status == "reviewed", "Actual reviewed Growth donor: " + text)
	return decorated.morphology

func _run() -> void:
	var document := _read("res://data/professional/lexemes/retail-module04.json")
	var record := _read("res://data/professional/provenance/retail-module04-morphology-remaining20-2026-10-20.json")
	var graphs: Array = []
	var by_text: Dictionary = {}
	for entry: Dictionary in document.lexemes:
		check(Analysis.compile(entry.morphology).ok, "Reviewed compilation: " + entry.text)
		graphs.append(entry.morphology)
		by_text[entry.text] = entry.morphology
	check(graphs.size() == 50 and selected.configure(graphs), "All fifty Retail04 graphs configure together")
	check(record.candidates.size() == 20, "Twenty new treatments are covered")
	for row: Dictionary in record.candidates:
		var graph: Dictionary = by_text[row.text]
		check(graph == row.accepted_morphology, "Installed graph matches accepted editorial treatment: " + row.text)
		check(not Analysis.compile(row.candidate_morphology).ok, "Original pending candidate stays excluded: " + row.text)
		var leaves: Array = selected.source_tiles(graph.id)
		var by_id: Dictionary = {}
		for index in range(leaves.size()):
			check(leaves[index].text == graph.parts[index].surface and not leaves[index].mastery_eligible, "Full authored source without unearned mastery: " + row.text)
			by_id[graph.parts[index].id] = leaves[index]
		var result := _compose(graph, graph.roots[0], by_id)
		check(result.get("text", "") == row.text and result.get("lexeme_ids", []) == [row.id], "Exact completed spelling and sense: " + row.text)
		check(result.get("mastery_eligible", false) == (graph.parts.size() > 1), "Only composed terms award composition mastery: " + row.text)
		if graph.parts.size() > 1:
			var plan: Dictionary = selected.completion_plan(leaves)
			check(plan.status == "complete" and plan.tile.text == row.text and plan.steps.size() == graph.nodes.size(), "Planner follows the complete authored path: " + row.text)
			leaves[0].assisted = true
			var assisted := _compose(graph, graph.roots[0], by_id)
			check(assisted.get("assisted", false) and not assisted.get("mastery_eligible", true), "Assisted composition remains ineligible for mastery: " + row.text)
	_check_families(graphs, by_text)
	print("Professional Retail04 morphology: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _compose(graph: Dictionary, id: String, leaves: Dictionary) -> Dictionary:
	if leaves.has(id):
		return leaves[id]
	var node: Dictionary = graph.nodes.filter(func(item: Dictionary) -> bool: return item.id == id)[0]
	var left := _compose(graph, node.left, leaves)
	var right := _compose(graph, node.right, leaves)
	var result: Dictionary = selected.resolve(left, right)
	check(result.status in ["partial", "complete"], "Authored merge resolves: " + graph.text + "/" + id)
	var tile: Dictionary = result.get("tile", {})
	check(tile.get("text", "") == node.surface and tile.get("break_offsets", []) == node.break_offsets, "Exact intermediate spelling and boundaries: " + graph.text + "/" + id)
	if not id in graph.roots:
		check(not tile.get("complete", true) and not tile.get("mastery_eligible", true), "Partial composition does not claim whole-term mastery: " + graph.text + "/" + id)
	check(selected.resolve(right, left).status == "invalid", "Reversed constituents are rejected: " + graph.text + "/" + id)
	return tile

func _check_families(graphs: Array, by_text: Dictionary) -> void:
	var headband := _growth(7, "headband")
	var stuffing := _growth(9, "stuffing")
	var bowling := _growth(7, "bowling")
	var network := _growth(9, "network")
	var fill := _growth(6, "fill")
	var pack := _growth(7, "pack")
	var backpack := _growth(6, "backpack")
	var caretaker := _growth(11, "caretaker")
	var foundation := _read("res://data/professional/lexemes/foundation-module02.json")
	var replace: Dictionary = foundation.lexemes.filter(func(entry: Dictionary) -> bool: return entry.text == "replace")[0].morphology
	var reject: Dictionary = foundation.lexemes.filter(func(entry: Dictionary) -> bool: return entry.text == "reject")[0].morphology
	check(selected.configure(graphs + [headband, stuffing, bowling, network, fill, pack, backpack, caretaker, replace, reject]), "Reviewed neighboring families configure together")
	var waistband: Array = selected.source_tiles(by_text.waistband.id)
	var band: Dictionary = selected.source_tiles(headband.id)[1]
	check(selected.resolve(waistband[0], band).status == "complete", "The reviewed physical-strip band composes waistband")
	var lining: Array = selected.source_tiles(by_text.lining.id)
	var result_ing: Dictionary = selected.source_tiles(stuffing.id)[1]
	var activity_ing: Dictionary = selected.source_tiles(bowling.id)[1]
	check(selected.resolve(lining[0], result_ing).status == "complete", "Reviewed result/material ing composes lining")
	check(selected.resolve(lining[0], activity_ing).status == "invalid", "Activity ing cannot substitute for the lining material")
	var net_weight: Array = selected.source_tiles(by_text["net weight"].id)
	var network_net: Dictionary = selected.source_tiles(network.id)[0]
	check(net_weight[0].text == network_net.text and net_weight[0].signature != network_net.signature, "Net after deductions is separate from a network net")
	check(selected.resolve(network_net, net_weight[1]).status == "invalid", "Network net cannot form net weight")
	var refill: Array = selected.source_tiles(by_text.refill.id)
	var again: Dictionary = selected.source_tiles(replace.id)[0]
	var back: Dictionary = selected.source_tiles(reject.id)[0]
	var filling: Dictionary = selected.source_tiles(fill.id)[0]
	check(selected.resolve(again, filling).status == "complete", "Reviewed again and fill compose the selected refill noun")
	check(selected.resolve(back, refill[1]).status == "invalid", "Back-valued re cannot form refill")
	var pack_size: Array = selected.source_tiles(by_text["pack size"].id)
	var multipack: Array = selected.source_tiles(by_text.multipack.id)
	check(selected.resolve(multipack[0], pack_size[0]).status == "complete", "Item-pack source is reusable in multipack")
	check(selected.resolve(selected.source_tiles(pack.id)[0], pack_size[1]).status == "invalid", "Packing-action source cannot replace the item-pack noun")
	check(selected.resolve(selected.source_tiles(backpack.id)[1], pack_size[1]).status == "invalid", "Carried-bag source cannot replace the item-pack noun")
	var dimension_size: Dictionary = selected.source_tiles(by_text["size"].id)[0]
	check(selected.resolve(pack_size[0], dimension_size).status == "invalid", "Dimension size cannot substitute for pack quantity")
	var care_label: Array = selected.source_tiles(by_text["care label"].id)
	check(selected.resolve(selected.source_tiles(caretaker.id)[0], care_label[1]).status == "complete", "Reviewed upkeep care composes care label")
