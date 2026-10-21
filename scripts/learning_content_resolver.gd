extends RefCounted
## Eligibility is resolved before a game is constructed; drafts never enter play.

const Context = preload("res://scripts/learning_context.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/morphology_analysis.gd")
const GrowthMorphology = preload("res://scripts/growth_morphology.gd")
const MODE_SKILLS: Dictionary = {"match": "recognition", "memory": "recognition",
	"jelly": "recognition", "pop": "speaking", "word_jelly": "spelling", "phrase": "context"}


static func resolve_growth(context: Dictionary, words: Array, phrase_dependencies: Array = []) -> Dictionary:
	var problem: String = Context.validate(context)
	if not problem.is_empty() or context.get("track") != "growth":
		return _failure(problem if not problem.is_empty() else "Growth needs a Growth context.")
	var age: int = int(context.module_id)
	var mode: String = context.mode
	var eligible: Array[Dictionary] = []
	for candidate in words:
		if not candidate is Dictionary or candidate.get("track", "growth") != "growth":
			continue
		if mode == "phrase":
			if not phrase_dependencies.has(str(candidate.get("id", ""))):
				continue
		elif Data.word_age(candidate) != age:
			continue
		var word: Dictionary = GrowthMorphology.decorate(candidate) if mode == "word_jelly" else candidate
		if _growth_supports(word, mode):
			eligible.append(word.duplicate(true))
	return _result(context, eligible, [], "growth_garden")


static func resolve_professional(context: Dictionary, course: Dictionary, lexemes: Dictionary,
	expressions: Dictionary, seed_value: int = -1) -> Dictionary:
	var problem: String = Context.validate(context)
	if not problem.is_empty() or context.get("track") != "professional":
		return _failure(problem if not problem.is_empty() else "Choose a professional course.")
	if course.get("id") != context.course_id or course.get("curriculum_revision") != context.curriculum_revision:
		return _failure("This course has changed. Choose its current version before starting.")
	var module: Dictionary = {}
	for candidate in course.get("modules", []):
		if candidate is Dictionary and candidate.get("id") == context.module_id:
			module = candidate
			break
	if module.get("status") != "ready":
		return _failure("This module is still being prepared.", "content_pending")
	var ids: Variant = module.get("lexeme_ids", [])
	var expression_ids: Variant = module.get("expression_ids", [])
	if not ids is Array or not expression_ids is Array or ids.size() != 50 or expression_ids.size() != 10 \
		or not _unique_strings(ids) or not _unique_strings(expression_ids):
		return _failure("The module inventory is incomplete.")
	var lessons: Array[Dictionary] = []
	var contextual_senses: Dictionary = {}
	for id in expression_ids:
		var entry: Variant = expressions.get(id)
		if not entry is Dictionary or entry.get("id") != id or not _expression_ready(entry):
			return _failure("An expression is waiting for content or audio review.", "content_pending")
		var focuses: Variant = entry.get("focus_lexeme_ids")
		if not focuses is Array or focuses.is_empty() or not _unique_strings(focuses):
			return _failure("Every expression needs its assessed vocabulary senses.")
		for sense_id in focuses:
			var sense: Variant = lexemes.get(sense_id)
			if not ids.has(sense_id) or not sense is Dictionary or not sense.get("practice_modes") is Array \
				or not sense.practice_modes.has("phrase"):
				return _failure("An expression's assessed senses must support Phrase Builder in this module.")
			contextual_senses[sense_id] = true
		lessons.append(entry.duplicate(true))
	var eligible: Array[Dictionary] = []
	var requirements: Array[Dictionary] = []
	var module_words: Array[Dictionary] = []
	for id in ids:
		var entry: Variant = lexemes.get(id)
		if not entry is Dictionary or entry.get("id") != id or not _lexeme_ready(entry):
			return _failure("A term is waiting for content or media review.", "content_pending")
		module_words.append(_adapt(entry))
	# Requirements describe routes for each sense in this module, independent
	# of the selected round. A valid five-word pool may still exclude one sense.
	var pair_routes: Dictionary = {}
	for mode in ["match", "memory"]:
		var candidates: Array[Dictionary] = []
		for word in module_words:
			if word.practice_modes.has(mode) and _picture_eligible(word, mode):
				candidates.append(word)
		pair_routes[mode] = picture_reachable_ids(candidates, 5)
	for entry in module_words:
		var id: String = entry.id
		var skills: Array[String] = []
		for mode in entry.practice_modes:
			if not _picture_eligible(entry, str(mode)):
				continue
			if pair_routes.has(mode) and not pair_routes[mode].has(id):
				continue
			if mode == "phrase" and not contextual_senses.has(id):
				continue
			if MODE_SKILLS.has(mode) and not skills.has(MODE_SKILLS[mode]):
				if mode != "word_jelly" or entry.morphology.get("kind") != "atomic" or not str(entry.get("image", "")).is_empty():
					skills.append(MODE_SKILLS[mode])
		if skills.is_empty():
			return _failure("Every term needs a reachable scored exercise.")
		requirements.append({"sense_id": id, "skills": skills})
		if entry.practice_modes.has(context.mode) and _picture_eligible(entry, context.mode) \
			and (context.mode != "phrase" or contextual_senses.has(id)):
			eligible.append(entry)
	# Choosing a sense is visible in the next round; two identical labels never
	# coexist with a hidden sense-based incompatibility in one round.
	if context.mode in ["match", "memory", "jelly", "pop"]:
		# Keep alternative same-spelling senses until compatibility is resolved.
		# Early deduplication could discard the only feasible five-word witness.
		eligible = _shuffled_words(eligible, seed_value)
		eligible = picture_compatible_pool(eligible, 5 if context.mode in ["match", "memory"] else 1)
	else:
		eligible = unique_spellings(eligible, seed_value)
	var result: Dictionary = _result(context, eligible, lessons, str(course.get("theme_id", "")))
	if result.ok:
		result["module_words"] = module_words
		result["course_title"] = str(course.get("title", context.course_id))
		result["module_title"] = str(module.get("title", context.module_id))
		result["requirements"] = {"course_id": context.course_id, "module_id": context.module_id,
			"curriculum_revision": context.curriculum_revision,
			"requirements_revision": module.get("requirements_revision", context.curriculum_revision),
			"terms": requirements, "expressions": expression_ids.duplicate()}
	return result


static func unique_spellings(words: Array[Dictionary], seed_value: int = -1) -> Array[Dictionary]:
	var shuffled: Array[Dictionary] = _shuffled_words(words, seed_value)
	var seen: Dictionary = {}
	var result: Array[Dictionary] = []
	for word in shuffled:
		var spelling: String = _display_spelling(word)
		if not spelling.is_empty() and not seen.has(spelling):
			seen[spelling] = true
			result.append(word)
	return result


static func _display_spelling(word: Dictionary) -> String:
	return " ".join(str(word.get("display_text", word.get("text", ""))).to_lower().split(" ", false))


static func _shuffled_words(words: Array[Dictionary], seed_value: int) -> Array[Dictionary]:
	var shuffled: Array[Dictionary] = words.duplicate(true)
	var rng := RandomNumberGenerator.new()
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	for index in range(shuffled.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var saved: Dictionary = shuffled[index]
		shuffled[index] = shuffled[other]
		shuffled[other] = saved
	return shuffled


static func _result(context: Dictionary, words: Array[Dictionary], expressions: Array,
	theme_id: String) -> Dictionary:
	var mode: String = context.mode
	var minimum: int = 5 if mode in ["match", "memory"] else 1
	if context.track == "professional" and mode == "phrase":
		if expressions.size() < 3:
			return _failure("Phrase Builder needs three reviewed expressions.")
	elif words.size() < minimum:
		return _failure("This module does not have enough eligible content for this game.", "mode_unavailable")
	return {"ok": true, "error": "", "context": Context.freeze(context), "words": words,
		"expressions": expressions, "theme_id": theme_id, "skill": MODE_SKILLS[mode]}


static func picture_compatible_pool(words: Array[Dictionary], minimum: int) -> Array[Dictionary]:
	# The caller has already randomized senses. Exclusions are symmetric even
	# when only one illustration records an overlapping meaning.
	var adjacent: Array[int] = _picture_graph(words)
	var candidates: Array[int] = _picture_indices(words.size())
	var selected: Array[int] = []
	var selected_mask: int = 0
	for index in candidates:
		if (adjacent[index] & selected_mask) == selected_mask:
			selected.append(index)
			selected_mask |= 1 << index
	if selected.size() >= minimum:
		return _picture_words(words, selected)
	# A broad first meaning can block several more specific ones. Search for
	# the small game minimum before declaring the mode unavailable. The module
	# has at most fifty candidates and Match/Memory need only five.
	selected = _picture_minimum(candidates, adjacent, minimum)
	if selected.is_empty():
		return []
	selected_mask = 0
	for index in selected:
		selected_mask |= 1 << index
	for index in candidates:
		if (adjacent[index] & selected_mask) == selected_mask:
			selected.append(index)
			selected_mask |= 1 << index
	return _picture_words(words, selected)


static func picture_reachable_ids(words: Array[Dictionary], minimum: int) -> Dictionary:
	var reachable: Dictionary = {}
	if minimum <= 1:
		for word in words:
			reachable[word.id] = true
		return reachable
	if words.size() < minimum:
		return reachable
	var adjacent: Array[int] = _picture_graph(words)
	var candidates: Array[int] = _picture_indices(words.size())
	if not _picture_can_complete(candidates, adjacent, minimum):
		return reachable
	for anchor in candidates:
		if reachable.has(words[anchor].id):
			continue
		var remaining: Array[int] = []
		for index in candidates:
			if words[index].id != words[anchor].id and (adjacent[anchor] & (1 << index)) != 0:
				remaining.append(index)
		var witness: Array[int] = _picture_minimum(remaining, adjacent, minimum - 1)
		if witness.size() == minimum - 1:
			reachable[words[anchor].id] = true
			for index in witness:
				reachable[words[index].id] = true
	return reachable


static func _picture_minimum(candidates: Array[int], adjacent: Array[int], needed: int) -> Array[int]:
	if not _picture_can_complete(candidates, adjacent, needed):
		return []
	for offset in range(candidates.size() - needed + 1):
		var index: int = candidates[offset]
		var chosen: Array[int] = [index]
		if needed == 1:
			return chosen
		var remaining: Array[int] = []
		for other_offset in range(offset + 1, candidates.size()):
			var other: int = candidates[other_offset]
			if (adjacent[index] & (1 << other)) != 0:
				remaining.append(other)
		var tail: Array[int] = _picture_minimum(remaining, adjacent, needed - 1)
		if tail.size() == needed - 1:
			chosen.append_array(tail)
			return chosen
	return []


static func _picture_can_complete(candidates: Array[int], adjacent: Array[int], needed: int) -> bool:
	if candidates.size() < needed:
		return false
	if needed <= 1:
		return true
	# Each color contains mutually incompatible senses. A compatible witness
	# needs one color per member. Fewer colors proves failure; enough colors
	# merely permits the exact search and never substitutes for a witness.
	var colors: Array[int] = []
	for index in candidates:
		var placed: bool = false
		for color in range(colors.size()):
			if (adjacent[index] & colors[color]) == 0:
				colors[color] |= 1 << index
				placed = true
				break
		if not placed:
			colors.append(1 << index)
			if colors.size() >= needed:
				return true
	return false


static func _picture_graph(words: Array[Dictionary]) -> Array[int]:
	# Professional modules contain at most fifty senses, so one 64-bit mask
	# records all neighbors. Normalize labels and inspect exclusions only once.
	var labels: Array[String] = []
	var exclusions: Array = []
	var adjacent: Array[int] = []
	for word in words:
		labels.append(_display_spelling(word))
		exclusions.append(word.media.image.get("confusable_with", []))
		adjacent.append(0)
	for first in range(words.size()):
		for second in range(first + 1, words.size()):
			if not labels[first].is_empty() and labels[first] == labels[second] \
				or exclusions[first].has(words[second].id) or exclusions[second].has(words[first].id):
				continue
			adjacent[first] |= 1 << second
			adjacent[second] |= 1 << first
	return adjacent


static func _picture_indices(count: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(count):
		result.append(index)
	return result


static func _picture_words(words: Array[Dictionary], indices: Array[int]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in indices:
		result.append(words[index])
	return result


static func _growth_supports(word: Dictionary, mode: String) -> bool:
	if not word.get("id") is String or not word.get("text") is String:
		return false
	if mode == "phrase":
		return not str(word.get("audio", "")).is_empty()
	if mode == "word_jelly":
		return word.get("morphology_status") == "reviewed" and word.get("morphology") is Dictionary \
			and not str(word.get("audio", "")).is_empty()
	if mode == "jelly":
		return not str(word.get("image", "")).is_empty() and not str(word.get("audio", "")).is_empty()
	return Data.supports_mode(word, mode)


static func _lexeme_ready(entry: Dictionary) -> bool:
	for key in ["text", "pos", "definition", "example", "difficulty"]:
		if not entry.get(key) is String or str(entry[key]).strip_edges().is_empty():
			return false
	if not _reviewed(entry.get("review", {})) or not entry.get("practice_modes") is Array \
		or not entry.get("morphology") is Dictionary:
		return false
	if entry.morphology.get("lexeme_id") != entry.get("id") or entry.morphology.get("text") != entry.text \
		or not Morphology.compile(entry.morphology).ok:
		return false
	var media: Variant = entry.get("media", {})
	if not media is Dictionary or not _media_ready(media.get("image", {})) or not _media_ready(media.get("audio", {})):
		return false
	var exclusions: Variant = media.image.get("confusable_with", [])
	return exclusions is Array and _unique_strings(exclusions) and not exclusions.has(entry.id)


static func _expression_ready(entry: Dictionary) -> bool:
	if not _reviewed(entry.get("review", {})) or not entry.get("text") is String \
		or not entry.get("tokens") is Array or entry.tokens.is_empty():
		return false
	var media: Variant = entry.get("media", {})
	if not media is Dictionary or not _media_ready(media.get("audio", {})):
		return false
	var previous_end: int = 0
	for index in range(entry.tokens.size()):
		var token: Variant = entry.tokens[index]
		if not token is Dictionary or token.get("index") != index or not token.get("text") is String:
			return false
		var start: int = int(token.get("start", -1))
		var end: int = int(token.get("end", -1))
		if start < previous_end or end <= start or end > entry.text.length() \
			or entry.text.substr(start, end - start) != token.text \
			or not entry.text.substr(previous_end, start - previous_end).strip_edges().is_empty():
			return false
		previous_end = end
	return entry.text.substr(previous_end).strip_edges().is_empty()


static func _reviewed(review: Variant) -> bool:
	return review is Dictionary and review.get("status") == "reviewed" \
		and review.get("language") == "reviewed" and review.get("domain") in ["not_required", "reviewed"]


static func _media_ready(media: Variant) -> bool:
	if not media is Dictionary or media.get("status") != "integrated":
		return false
	var review: Variant = media.get("review", {})
	if not review is Dictionary or review.get("status") != "reviewed":
		return false
	for key in ["path", "sha256", "source", "creator", "license"]:
		if not media.get(key) is String or str(media[key]).strip_edges().is_empty():
			return false
	var digest: String = media.sha256
	if digest.length() != 64:
		return false
	for character in digest:
		if character not in "0123456789abcdef":
			return false
	return true


static func _picture_eligible(entry: Dictionary, mode: String) -> bool:
	return mode not in ["match", "memory", "jelly", "pop"] or entry.media.image.get("picture_suitable", false) == true


static func _adapt(entry: Dictionary) -> Dictionary:
	var result: Dictionary = entry.duplicate(true)
	result["track"] = "professional"
	result["sense_id"] = entry.id
	result["display_text"] = entry.get("display_text", entry.text)
	result["image"] = entry.media.image.path
	result["audio"] = entry.media.audio.path
	return result


static func _unique_strings(values: Array) -> bool:
	var seen: Dictionary = {}
	for value in values:
		if not value is String or value.is_empty() or seen.has(value):
			return false
		seen[value] = true
	return true


static func _failure(message: String, code: String = "invalid_content") -> Dictionary:
	return {"ok": false, "error": message, "code": code, "words": [], "expressions": []}
