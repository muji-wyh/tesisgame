extends RefCounted
## Validates authored morphology; it never guesses a split or spelling rule.

const SCHEMA: int = 1
const MAX_PARTS: int = 64
const MAX_NODES: int = 256
const KINDS: Array[String] = ["atomic", "morphological", "compound", "phrase"]
const PART_TYPES: Array[String] = ["atomic", "root", "stem", "prefix", "suffix", "compound", "combining_form", "word", "abbreviation"]


static func compile(value: Variant, require_reviewed: bool = true) -> Dictionary:
	if not value is Dictionary:
		return _failure("An analysis must be an object.")
	if value.get("schema") != SCHEMA or not _text(value.get("id")) or not _text(value.get("lexeme_id")) or not _text(value.get("text")):
		return _failure("An analysis needs schema 1, id, lexeme_id, and exact text.")
	if not value.get("kind") in KINDS:
		return _failure("Unknown analysis kind.")
	if not value.get("review") is Dictionary or not value.review.get("status") in ["pending", "reviewed"]:
		return _failure("An explicit pending or reviewed status is required.")
	if require_reviewed and value.review.status != "reviewed":
		return _failure("Pending morphology cannot be used in a playable round.")
	if not value.get("parts") is Array or value.parts.is_empty() or value.parts.size() > MAX_PARTS:
		return _failure("An analysis needs between 1 and %d ordered parts." % MAX_PARTS)
	if not value.get("nodes") is Array or value.nodes.size() > MAX_NODES:
		return _failure("An analysis needs an authored nodes array within the size limit.")
	if not value.get("roots") is Array or value.roots.is_empty():
		return _failure("An analysis needs at least one completion root.")
	if value.kind == "atomic" and (value.parts.size() != 1 or not value.nodes.is_empty()):
		return _failure("An atomic entry has exactly one whole part and no joins.")
	if value.kind != "atomic" and value.parts.size() < 2:
		return _failure("A composed analysis needs at least two meaningful parts.")
	var authored: Dictionary = {}
	var compiled: Dictionary = {}
	var ordered_parts: Array[Dictionary] = []
	for index in range(value.parts.size()):
		var part: Variant = value.parts[index]
		if not part is Dictionary or not _text(part.get("id")) or authored.has(part.id):
			return _failure("Part and node IDs must be unique nonempty strings.")
		if not part.get("type") in PART_TYPES or not _text(part.get("canonical_id")) or not _text(part.get("canonical")) or not _text(part.get("surface")):
			return _failure("Each part needs a type, canonical sense identity, canonical form, and surface.")
		if part.type == "combining_form" and value.review.status == "reviewed" and (not value.review.get("references") is Array or value.review.references.is_empty()):
			return _failure("Reviewed classical combining forms need review references.")
		var breaks: Variant = part.get("break_offsets", [])
		if not _valid_breaks(part.surface, breaks):
			return _failure("Part break offsets must be increasing character offsets inside its surface.")
		var item: Dictionary = part.duplicate(true)
		item.break_offsets = breaks.duplicate()
		item.start = index
		item.end = index + 1
		item.part_signatures = [part_signature(part)]
		item.signature = composition_signature(item.part_signatures, item.surface)
		item.leaf = true
		authored[item.id] = item
		compiled[item.id] = item
		ordered_parts.append(item)
	for node: Variant in value.nodes:
		if not node is Dictionary or not _text(node.get("id")) or authored.has(node.id):
			return _failure("Part and node IDs must be unique nonempty strings.")
		if not _text(node.get("left")) or not _text(node.get("right")) or not _text(node.get("surface")) or not _text(node.get("rule")):
			return _failure("A binary node needs left, right, exact surface, and an authored rule label.")
		if not _valid_breaks(node.surface, node.get("break_offsets", [])):
			return _failure("Node break offsets must be increasing character offsets inside its surface.")
		authored[node.id] = node.duplicate(true)
	var visiting: Dictionary = {}
	for node_id: String in authored:
		var error: String = _compile_node(node_id, authored, compiled, visiting)
		if not error.is_empty():
			return _failure(error)
	var root_ids: Dictionary = {}
	var reachable: Dictionary = {}
	for root_id: Variant in value.roots:
		if not root_id is String or not compiled.has(root_id) or root_ids.has(root_id):
			return _failure("Completion roots must reference distinct existing nodes or parts.")
		var node: Dictionary = compiled[root_id]
		if int(node.start) != 0 or int(node.end) != ordered_parts.size() or node.surface != value.text:
			return _failure("Every root must cover all ordered parts and preserve the exact target text.")
		root_ids[root_id] = true
		_mark_reachable(root_id, authored, reachable)
	if reachable.size() != authored.size():
		return _failure("Every authored part and node must lie on a completion path.")
	return {"ok": true, "error": "", "analysis": {"schema": SCHEMA, "id": value.id,
		"lexeme_id": value.lexeme_id, "text": value.text, "kind": value.kind,
		"review": value.review.duplicate(true), "parts": ordered_parts,
		"nodes": compiled, "roots": value.roots.duplicate()}}


static func part_signature(part: Dictionary) -> String:
	# Contextual roles, occurrence IDs, and supply groups are deliberately absent.
	# A lexical base can be atomic in one target and a stem in another.
	return JSON.stringify([SCHEMA, str(part.get("canonical_id", "")), str(part.get("canonical", ""))]).sha256_text()


static func composition_signature(part_signatures: Array, surface: String) -> String:
	return JSON.stringify([SCHEMA, part_signatures, surface]).sha256_text()


static func _compile_node(node_id: String, authored: Dictionary, compiled: Dictionary, visiting: Dictionary) -> String:
	if compiled.has(node_id):
		return ""
	if not authored.has(node_id):
		return "A composition refers to a missing child: " + node_id
	if visiting.has(node_id):
		return "The composition graph must be acyclic."
	visiting[node_id] = true
	var node: Dictionary = authored[node_id]
	for child: String in [str(node.left), str(node.right)]:
		var error: String = _compile_node(child, authored, compiled, visiting)
		if not error.is_empty():
			return error
	var left: Dictionary = compiled[node.left]
	var right: Dictionary = compiled[node.right]
	if int(left.end) != int(right.start):
		return "A join must combine adjacent ordered, non-overlapping part spans."
	var result: Dictionary = node.duplicate(true)
	result.start = left.start
	result.end = right.end
	result.part_signatures = left.part_signatures.duplicate()
	result.part_signatures.append_array(right.part_signatures)
	result.signature = composition_signature(result.part_signatures, result.surface)
	result.break_offsets = node.get("break_offsets", []).duplicate()
	result.leaf = false
	compiled[node_id] = result
	visiting.erase(node_id)
	return ""


static func _mark_reachable(node_id: String, authored: Dictionary, reachable: Dictionary) -> void:
	if reachable.has(node_id):
		return
	reachable[node_id] = true
	var node: Dictionary = authored[node_id]
	if node.has("left"):
		_mark_reachable(node.left, authored, reachable)
		_mark_reachable(node.right, authored, reachable)


static func _valid_breaks(surface: String, offsets: Variant) -> bool:
	if not offsets is Array:
		return false
	var previous: int = 0
	for offset: Variant in offsets:
		if not offset is int and not offset is float:
			return false
		if not is_finite(float(offset)) or float(offset) != floorf(float(offset)) or int(offset) <= previous or int(offset) >= surface.length():
			return false
		previous = int(offset)
	return true


static func _text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and not "\n" in value and not "\r" in value and not "\t" in value


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "analysis": {}}
