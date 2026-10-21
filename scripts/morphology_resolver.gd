extends RefCounted
## Shared pure composition rules for manual merging, hints, and completion plans.

const Analysis = preload("res://scripts/morphology_analysis.gd")
const MAX_PLAN_STATES: int = 1024
const MAX_PLAN_PAIR_CHECKS: int = 16384
var error: String = ""
var _analyses: Dictionary = {}
var _states: Dictionary = {}
var _joins: Dictionary = {}


func configure(analyses: Array, require_reviewed: bool = true) -> bool:
	var next_analyses: Dictionary = {}
	var next_states: Dictionary = {}
	var next_joins: Dictionary = {}
	for authored: Variant in analyses:
		var result: Dictionary = Analysis.compile(authored, require_reviewed)
		if not result.ok:
			error = result.error
			return false
		var analysis: Dictionary = result.analysis
		if next_analyses.has(analysis.id):
			error = "Analysis IDs must be unique within a resolver."
			return false
		next_analyses[analysis.id] = analysis
		for node_id: String in analysis.nodes:
			var node: Dictionary = analysis.nodes[node_id]
			var signature: String = node.signature
			if not next_states.has(signature):
				next_states[signature] = {"signature": signature, "text": node.surface,
					"part_signatures": node.part_signatures.duplicate(), "part_count": node.part_signatures.size(),
					"break_offsets": node.break_offsets.duplicate(), "candidates": [], "lexeme_ids": []}
			var state: Dictionary = next_states[signature]
			state.candidates.append({"analysis_id": analysis.id, "node_id": node_id})
			# Only boundaries approved by every equivalent node may be rendered.
			state.break_offsets = state.break_offsets.filter(func(offset: Variant) -> bool: return offset in node.break_offsets)
			if node_id in analysis.roots and not analysis.lexeme_id in state.lexeme_ids:
				state.lexeme_ids.append(analysis.lexeme_id)
			if not node.leaf:
				var key: String = _join_key(analysis.nodes[node.left].signature, analysis.nodes[node.right].signature)
				if not next_joins.has(key):
					next_joins[key] = []
				if not signature in next_joins[key]:
					next_joins[key].append(signature)
	_analyses = next_analyses
	_states = next_states
	_joins = next_joins
	error = ""
	return true


func source_tiles(analysis_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _analyses.has(analysis_id):
		return result
	var analysis: Dictionary = _analyses[analysis_id]
	for part: Dictionary in analysis.parts:
		var tile: Dictionary = _tile(part.signature)
		tile.origins = [{"analysis_id": analysis_id, "part_id": part.id}]
		tile.part_type = part.type
		tile.canonical_id = part.canonical_id
		tile.canonical = part.canonical
		result.append(tile)
	return result


func resolve(left: Dictionary, right: Dictionary, placement: Callable = Callable(), board: Array = []) -> Dictionary:
	if not _valid_tile(left) or not _valid_tile(right):
		return _invalid("unknown_state")
	if is_same(left, right) or (left.has("id") and right.has("id") and left.id == right.id):
		return _invalid("same_tile")
	var key: String = _join_key(left.signature, right.signature)
	if not _joins.has(key):
		return _invalid("no_authored_join")
	if _joins[key].size() != 1:
		return _invalid("ambiguous_surface")
	var tile: Dictionary = _tile(_joins[key][0])
	if tile.lexeme_ids.size() > 1:
		return _invalid("ambiguous_sense")
	for origin: Variant in left.get("origins", []):
		tile.origins.append(origin.duplicate(true))
	for origin: Variant in right.get("origins", []):
		tile.origins.append(origin.duplicate(true))
	tile.composed = true
	tile.assisted = bool(left.get("assisted", false)) or bool(right.get("assisted", false))
	tile.mastery_eligible = tile.complete and not tile.assisted
	tile.fragments = int(left.get("fragments", 0)) + int(right.get("fragments", 0))
	var result: Dictionary = {"status": "complete" if tile.complete else "partial", "reason": "", "tile": tile}
	if placement.is_valid():
		# The hook receives isolated snapshots, including the simulated board for Auto merge.
		var fit: Variant = placement.call(left.duplicate(true), right.duplicate(true), tile.duplicate(true), board.duplicate(true))
		if not (fit is bool and fit) and not (fit is Dictionary and bool(fit.get("ok", false))):
			return {"status": "needs_room", "reason": "placement", "tile": {}}
		if fit is Dictionary:
			if not fit.get("placement", {}) is Dictionary:
				return {"status": "needs_room", "reason": "invalid_placement", "tile": {}}
			result.placement = fit.get("placement", {}).duplicate(true)
			for field: String in ["column", "row", "width", "height"]:
				if result.placement.has(field):
					tile[field] = result.placement[field]
	return result


func compatible_pairs(tiles: Array, placement: Callable = Callable()) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for left_index in range(tiles.size()):
		for right_index in range(tiles.size()):
			if left_index == right_index or not tiles[left_index] is Dictionary or not tiles[right_index] is Dictionary:
				continue
			var result: Dictionary = resolve(tiles[left_index], tiles[right_index], placement, tiles)
			if result.status in ["partial", "complete"]:
				pairs.append({"left_index": left_index, "right_index": right_index, "result": result})
	return pairs


func completion_plan(tiles: Array, placement: Callable = Callable(), maximum_states: int = MAX_PLAN_STATES,
	accept_completion: Callable = Callable()) -> Dictionary:
	# Breadth-first search returns the fewest authored joins that reach a new complete term.
	# The caller must provide placement before charging and revalidate when executing.
	var initial: Array = tiles.duplicate(true)
	for index in range(initial.size()):
		if not initial[index] is Dictionary or not _valid_tile(initial[index]):
			return {"status": "invalid", "reason": "unknown_state", "steps": []}
		initial[index]["plan_ref"] = "input:%d" % index
	var queue: Array[Dictionary] = [{"tiles": initial, "steps": []}]
	var visited: Dictionary = {}
	var cursor: int = 0
	var pair_checks: int = 0
	var limited: bool = false
	var state_limit: int = clampi(maximum_states, 0, MAX_PLAN_STATES)
	while cursor < queue.size() and cursor < state_limit and pair_checks < MAX_PLAN_PAIR_CHECKS:
		var state: Dictionary = queue[cursor]
		cursor += 1
		var candidates: Dictionary = _planning_pairs(state.tiles, placement, MAX_PLAN_PAIR_CHECKS - pair_checks)
		pair_checks += int(candidates.checks)
		limited = limited or bool(candidates.limited)
		for pair: Dictionary in candidates.pairs:
			var result: Dictionary = pair.result
			var merged: Dictionary = result.tile.duplicate(true)
			var steps: Array = state.steps.duplicate(true)
			merged.plan_ref = "step:%d" % steps.size()
			steps.append({"left_ref": state.tiles[pair.left_index].plan_ref,
				"right_ref": state.tiles[pair.right_index].plan_ref, "result_ref": merged.plan_ref,
				"result": merged.duplicate(true), "placement": result.get("placement", {}).duplicate(true)})
			if result.status == "complete" and _completion_uses_all_steps(steps) \
				and (not accept_completion.is_valid() or bool(accept_completion.call(merged.duplicate(true)))):
				return {"status": "complete", "reason": "", "steps": steps,
					"tile": merged, "placement_checked": placement.is_valid(), "explored_states": cursor,
					"evaluated_pairs": pair_checks}
			var next_tiles: Array = []
			for index in range(state.tiles.size()):
				if index != pair.left_index and index != pair.right_index:
					next_tiles.append(state.tiles[index].duplicate(true))
			next_tiles.append(merged)
			var key: String = _board_key(next_tiles)
			if not visited.has(key):
				if queue.size() >= state_limit:
					limited = true
					continue
				visited[key] = true
				queue.append({"tiles": next_tiles, "steps": steps})
	return {"status": "unavailable", "reason": "search_limit" if limited or cursor < queue.size() else "no_completion_path",
		"steps": [], "placement_checked": placement.is_valid(), "explored_states": cursor,
		"evaluated_pairs": pair_checks}


static func _completion_uses_all_steps(steps: Array) -> bool:
	# Space freed by an unrelated partial is not a valid reason to buy a path.
	# Every accepted intermediate must be consumed into the completed target.
	var pending: Array[int] = [steps.size() - 1]
	var used: Dictionary = {}
	while not pending.is_empty():
		var index: int = pending.pop_back()
		if used.has(index):
			continue
		used[index] = true
		for key: String in ["left_ref", "right_ref"]:
			var reference: String = str(steps[index][key])
			if reference.begins_with("step:"):
				pending.append(int(reference.trim_prefix("step:")))
	return used.size() == steps.size()


func _planning_pairs(tiles: Array, placement: Callable, budget: int) -> Dictionary:
	var result: Dictionary = {"pairs": [], "checks": 0, "limited": false}
	for left_index in range(tiles.size()):
		for right_index in range(tiles.size()):
			if left_index == right_index:
				continue
			if int(result.checks) >= budget:
				result.limited = true
				return result
			result.checks += 1
			var composed: Dictionary = resolve(tiles[left_index], tiles[right_index], placement, tiles)
			if composed.status in ["partial", "complete"]:
				result.pairs.append({"left_index": left_index, "right_index": right_index, "result": composed})
	return result


func _tile(signature: String) -> Dictionary:
	var result: Dictionary = _states[signature].duplicate(true)
	result.complete = result.lexeme_ids.size() == 1
	result.lexeme_id = result.lexeme_ids[0] if result.complete else ""
	result.composed = false
	result.assisted = false
	result.mastery_eligible = false
	result.fragments = 0
	result.origins = []
	return result


func _valid_tile(tile: Dictionary) -> bool:
	var signature: String = str(tile.get("signature", ""))
	return _states.has(signature) and tile.get("text") == _states[signature].text \
		and tile.get("part_signatures") == _states[signature].part_signatures


static func _join_key(left: String, right: String) -> String:
	return left + ":" + right


static func _board_key(tiles: Array) -> String:
	var entries: Array[String] = []
	for tile: Dictionary in tiles:
		entries.append(JSON.stringify([tile.signature, tile.get("column", -1), tile.get("row", -1),
			tile.get("width", -1), tile.get("height", -1), tile.get("assisted", false)]))
	entries.sort()
	return JSON.stringify(entries)


static func _invalid(reason: String) -> Dictionary:
	return {"status": "invalid", "reason": reason, "tile": {}}
