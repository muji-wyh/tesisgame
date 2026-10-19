extends RefCounted
## Professional sense/skill evidence; never reads or changes Growth or the wallet.

const SCHEMA := 1
const SKILLS := ["recognition", "listening", "spelling", "speaking", "context"]
const MODES := ["match", "memory", "pop", "phrase", "jelly", "word_jelly"]
const MODE_SKILLS := {"match": ["recognition", "listening"], "memory": ["recognition", "listening"],
	"pop": ["speaking"], "phrase": ["context", "listening"], "jelly": ["recognition", "listening"], "word_jelly": ["spelling"]}
const MAX_SAFE_INTEGER := 9007199254740991

var error := ""
var requirements: Dictionary = {}


static func identity(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 256:
		return false
	var pattern := RegEx.new()
	pattern.compile("^[a-zA-Z0-9][a-zA-Z0-9._:/-]*$")
	return pattern.search(value) != null


static func whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floorf(float(value)) and value >= minimum and value <= maximum


static func canonical(value: Variant) -> String:
	if value is Dictionary:
		# Property assignment can create StringName keys whereas parsed JSON uses
		# String keys. Normalize before sorting so persistence fingerprints agree.
		var normalized: Dictionary = {}
		for key in value:
			normalized[str(key)] = value[key]
		var keys: Array = normalized.keys()
		keys.sort()
		var pieces: Array[String] = []
		for key in keys:
			pieces.append(JSON.stringify(str(key)) + ":" + canonical(normalized[key]))
		return "{" + ",".join(pieces) + "}"
	if value is Array:
		var pieces: Array[String] = []
		for item in value:
			pieces.append(canonical(item))
		return "[" + ",".join(pieces) + "]"
	if (value is int or value is float) and whole(value, -MAX_SAFE_INTEGER, MAX_SAFE_INTEGER):
		return str(int(value))
	return JSON.stringify(value)


static func module_key(context: Dictionary) -> String:
	return canonical([context.get("course_id"), context.get("module_id"), context.get("curriculum_revision")])


static func requirement_key(row: Dictionary) -> String:
	return canonical([row.get("course_id"), row.get("module_id"), row.get("requirements_revision")])


static func requirement_fingerprint(row: Dictionary) -> String:
	return canonical({"course_id": row.course_id, "module_id": row.module_id,
		"requirements_revision": row.requirements_revision, "terms": row.terms, "expressions": row.expressions})


static func empty_progress() -> Dictionary:
	return {"schema": SCHEMA, "sequence": 0, "skills": {}, "expressions": {}, "completions": {}, "requirements": {}}


func configure(source: Array) -> bool:
	var next: Dictionary = {}
	for original in source:
		if not original is Dictionary:
			return _fail("Professional requirements must contain module records.")
		var row: Dictionary = original.duplicate(true)
		for key in ["course_id", "module_id", "curriculum_revision", "requirements_revision"]:
			if not identity(row.get(key)):
				return _fail("Professional requirements need stable course, module, and revision IDs.")
		if not row.get("terms") is Array or row.terms.size() != 50 or not row.get("expressions") is Array or row.expressions.size() != 10:
			return _fail("A professional module requires 50 terms and 10 distinct expressions.")
		var seen: Dictionary = {}
		for term in row.terms:
			if not term is Dictionary or not identity(term.get("sense_id")) or seen.has(term.sense_id) \
				or not term.get("skills") is Array or term.skills.is_empty():
				return _fail("Each module term needs a distinct sense and eligible skills.")
			var skills: Dictionary = {}
			for skill in term.skills:
				if not skill in SKILLS or skills.has(skill):
					return _fail("Use distinct supported assessed skills.")
				skills[skill] = true
			term.skills.sort()
			seen[term.sense_id] = true
		seen.clear()
		for expression in row.expressions:
			if not identity(expression) or seen.has(expression):
				return _fail("Use ten distinct expression IDs.")
			seen[expression] = true
		row.terms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.sense_id) < str(b.sense_id))
		row.expressions.sort()
		var key: String = module_key(row)
		if next.has(key):
			return _fail("Duplicate professional module revision.")
		for previous: Dictionary in next.values():
			if requirement_key(previous) == requirement_key(row) and requirement_fingerprint(previous) != requirement_fingerprint(row):
				return _fail("One requirements revision cannot describe different objectives.")
		next[key] = row
	requirements = next
	error = ""
	return true


func validate_context(context: Variant, professional_only: bool = false) -> String:
	if not context is Dictionary or not context.get("mode") in MODES:
		return "Choose an available exercise mode."
	if context.get("track") == "growth" and not professional_only:
		return ""
	if context.get("track") != "professional":
		return "Choose an available professional module revision."
	for key in ["course_id", "module_id", "curriculum_revision"]:
		if not identity(context.get(key)):
			return "Choose an available professional module revision."
	return "" if requirements.has(module_key(context)) else "Choose an available professional module revision."


func register_requirements(source: Array, saved: Dictionary) -> bool:
	var additions = get_script().new()
	if not additions.configure(source):
		return _fail(additions.error)
	var combined: Dictionary = requirements.duplicate(true)
	for key in additions.requirements:
		var row: Dictionary = additions.requirements[key]
		if combined.has(key) and canonical(combined[key]) != canonical(row):
			return _fail("This curriculum changed without a new revision. Please reload.")
		var pinned: String = requirement_key(row)
		if saved.requirements.has(pinned) and saved.requirements[pinned] != requirement_fingerprint(row):
			return _fail("This curriculum changed without a new revision. Please reload.")
		combined[key] = row
	return configure(combined.values())


func validate_event(event: Variant) -> String:
	if not event is Dictionary or not identity(event.get("id")) or not identity(event.get("sense_id")) or not event.get("skill") in SKILLS:
		return "The professional answer is invalid."
	for key in ["correct", "assisted", "atomic"]:
		if not event.get(key) is bool:
			return "The professional answer is invalid."
	var context_error: String = validate_context(event.get("context"), true)
	if not context_error.is_empty():
		return context_error
	if not event.skill in MODE_SKILLS[event.context.mode]:
		return "This skill does not match the selected exercise mode."
	var atomic_exposure: bool = event.atomic and event.correct and event.context.mode == "word_jelly" \
		and event.skill == "spelling" and not event.has("expression_id")
	if event.atomic and not atomic_exposure:
		return "Atomic collection must be a correct Word Jelly spelling exposure."
	var row: Dictionary = requirements[module_key(event.context)]
	var eligible := false
	for term: Dictionary in row.terms:
		if term.sense_id == event.sense_id and (event.skill in term.skills or atomic_exposure):
			eligible = true
	if not eligible:
		return "This sense or skill does not belong to the selected module."
	if event.has("expression_id") and (event.skill != "context" or not event.expression_id in row.expressions):
		return "The expression does not belong to this module or contextual skill."
	if event.has("reward"):
		var reward: Variant = event.reward
		if not reward is Dictionary or reward.size() != 2 or reward.get("operation") != "credit" \
			or not reward.get("payload") is Dictionary or reward.payload.size() != 1 \
			or not whole(reward.payload.get("tier"), 0, 180143985094819) or not event.correct:
			return "A reward needs a correct completed event and an existing wallet credit tier."
	return ""


static func validate_progress(progress: Variant) -> String:
	if not progress is Dictionary or progress.get("schema") != SCHEMA or not whole(progress.get("sequence"), 0, MAX_SAFE_INTEGER):
		return "Professional progress could not be read. Please retry."
	for key in ["skills", "expressions", "completions", "requirements"]:
		if not progress.get(key) is Dictionary:
			return "Professional progress could not be read. Please retry."
	for sense in progress.skills:
		if not identity(sense) or not progress.skills[sense] is Dictionary:
			return "Invalid professional sense history."
		for skill in progress.skills[sense]:
			var evidence: Variant = progress.skills[sense][skill]
			if not skill in SKILLS or not evidence is Dictionary or not whole(evidence.get("streak"), 0, 3) \
				or not evidence.get("earned") is bool or (evidence.streak == 3 and not evidence.earned) \
				or not whole(evidence.get("exposures"), 1, MAX_SAFE_INTEGER):
				return "Invalid professional skill history."
	for key in progress.expressions:
		if not progress.expressions[key] is Dictionary or not progress.requirements.has(key):
			return "Invalid professional expression history."
		for id in progress.expressions[key]:
			if not identity(id) or progress.expressions[key][id] != true:
				return "Invalid professional expression history."
	for key in progress.completions:
		var receipt: Variant = progress.completions[key]
		if not receipt is Dictionary or key != requirement_key(receipt) or not whole(receipt.get("sequence"), 1, progress.sequence) \
			or not progress.requirements.has(key):
			return "Invalid professional completion receipt."
	for value in progress.requirements.values():
		if not value is String or value.is_empty():
			return "Invalid professional requirements history."
	return ""


func apply_event(saved: Dictionary, event: Dictionary) -> Dictionary:
	var message: String = validate_progress(saved)
	if message.is_empty():
		message = validate_event(event)
	if not message.is_empty():
		return {"ok": false, "error": message}
	var progress: Dictionary = saved.duplicate(true)
	var row: Dictionary = requirements[module_key(event.context)]
	var key: String = requirement_key(row)
	var fingerprint: String = requirement_fingerprint(row)
	if progress.requirements.has(key) and progress.requirements[key] != fingerprint:
		return {"ok": false, "error": "This curriculum changed without a new revision. Please reload."}
	progress.requirements[key] = fingerprint
	if progress.sequence >= MAX_SAFE_INTEGER:
		return {"ok": false, "error": "Professional progress storage has reached its supported limit."}
	progress.sequence = int(progress.sequence) + 1
	if not progress.skills.has(event.sense_id):
		progress.skills[event.sense_id] = {}
	var skills: Dictionary = progress.skills[event.sense_id]
	var evidence: Dictionary = skills.get(event.skill, {"streak": 0, "earned": false, "exposures": 0})
	if evidence.exposures >= MAX_SAFE_INTEGER:
		return {"ok": false, "error": "This professional history has reached its supported limit."}
	evidence.exposures = int(evidence.exposures) + 1
	if not event.atomic and not event.correct:
		evidence.streak = 0
	elif not event.atomic and not event.assisted:
		evidence.streak = mini(3, int(evidence.streak) + 1)
		evidence.earned = evidence.earned or evidence.streak == 3
	skills[event.skill] = evidence
	if event.has("expression_id") and event.correct and not event.assisted and not event.atomic:
		if not progress.expressions.has(key):
			progress.expressions[key] = {}
		progress.expressions[key][event.expression_id] = true
	for candidate: Dictionary in requirements.values():
		var candidate_key: String = requirement_key(candidate)
		if not progress.requirements.has(candidate_key) or progress.completions.has(candidate_key):
			continue
		if progress.requirements[candidate_key] != requirement_fingerprint(candidate):
			return {"ok": false, "error": "This curriculum changed without a new revision. Please reload."}
		var learned := true
		for term: Dictionary in candidate.terms:
			var term_learned := false
			for skill in term.skills:
				term_learned = term_learned or bool(progress.skills.get(term.sense_id, {}).get(skill, {}).get("earned", false))
			learned = learned and term_learned
		var expressions: Dictionary = progress.expressions.get(candidate_key, {})
		for expression in candidate.expressions:
			learned = learned and expressions.has(expression)
		if learned:
			progress.completions[candidate_key] = {"course_id": candidate.course_id, "module_id": candidate.module_id,
				"requirements_revision": candidate.requirements_revision, "sequence": progress.sequence}
	return {"ok": true, "progress": progress, "error": ""}


func _fail(message: String) -> bool:
	error = message
	return false
