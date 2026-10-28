extends RefCounted
## Deterministic attempt recipes; no mastery, wallet or scene dependencies.

const VERSION: int = 1
const MAX_STAGE: int = 99
const CHALLENGE_SECONDS: float = 90.0
const MAX_MAIN_WORDS: int = 8
const MAX_CHALLENGE_WORDS: int = 16
const MAX_GOAL: int = 99
const MAX_POOL_WORDS: int = 20000
const MAX_ID_LENGTH: int = 512
const MAX_COINS: int = 9007199254740991
const Analysis = preload("res://scripts/morphology_analysis.gd")
const CHAPTERS: Array[String] = ["Meadow", "Grove", "Pine Trail", "Cottage Creek",
	"Amber Orchard", "Snowfields", "Frost Pines", "Palm Lagoon", "Cactus Valley",
	"High Peaks", "Castle Gardens"]
const PROFILES: Array[String] = ["Discover", "Practice", "Build", "Breather",
	"Mix", "Flow", "Reward", "Prepare", "Finale"]
const MARGINS: Array[float] = [1.55, 1.35, 1.25, 1.65, 1.30, 1.15, 1.65, 1.25, 1.10]
const CADENCE_WAVE: Array[float] = [1.0, 1.0, 0.98, 1.10, 0.98, 0.94, 1.10, 0.96, 0.92]
const RECIPE_KEYS: Array[String] = ["version", "kind", "number", "chapter", "title",
	"profile", "age", "seed", "word_ids", "identities", "goals", "seconds",
	"spawn_interval", "fall_speed_scale"]


@warning_ignore("shadowed_global_identifier")
static func make_plan(number: int, pool: Array, age: int, seed: int,
		challenge: bool = false) -> Dictionary:
	if number < (0 if challenge else 1) or number > MAX_STAGE:
		return _failure("Choose a main stage from 1 to 99, or stage zero for a challenge.")
	if age < 0 or age > 120 or pool.size() > MAX_POOL_WORDS:
		return _failure("This stage needs a supported learning age and a bounded word pool.")
	var candidates: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var seen_spellings: Dictionary = {}
	for value: Variant in pool:
		if not value is Dictionary or not _word_error(value).is_empty():
			continue
		var professional: bool = value.get("track", "") == "professional"
		if not professional and value.get("min_age", 3) != age:
			continue
		var identity: String = _identity(value)
		if seen_ids.has(value.id):
			if seen_ids[value.id] != identity:
				return _failure("The word pool contains conflicting definitions for " + str(value.id) + ".")
			continue
		seen_ids[value.id] = identity
		var spelling: String = str(value.text).strip_edges().to_lower()
		if seen_spellings.has(spelling):
			continue
		seen_spellings[spelling] = true
		candidates.append(value.duplicate(true))
	if candidates.is_empty():
		return _failure("This learning scope has no distinct reviewed words for a stage.")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for index in range(candidates.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var saved: Dictionary = candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = saved
	var target_count: int = mini(MAX_CHALLENGE_WORDS if challenge else mini(number + 2, MAX_MAIN_WORDS),
		candidates.size())
	var words: Array[Dictionary] = []
	var ids: Array[String] = []
	for index in range(target_count):
		words.append(candidates[index])
		ids.append(str(candidates[index].id))
	var chapter: int = 1 if challenge else ceili(float(number) / 9.0)
	var wave: int = 0 if challenge else (number - 1) % PROFILES.size()
	var goals: Dictionary = {}
	var cadence: float = 20.0
	var fall_speed: float = 1.0
	var seconds: float = CHALLENGE_SECONDS if challenge else 0.0
	if not challenge:
		var base: int = 1 + floori(float(chapter - 1) / 2.0)
		var offset: int = rng.randi_range(0, words.size() - 1)
		for index in range(words.size()):
			var raised: bool = wave == 8 or (wave in [2, 4, 5, 7] and (index - offset) % 3 == 0)
			goals[ids[index]] = base + (1 if raised else 0)
		var progression: float = float(number - 1) / 98.0
		cadence = clampf(lerpf(20.0, 10.0, pow(progression, 0.65)) * CADENCE_WAVE[wave], 10.0, 24.0)
		fall_speed = lerpf(1.0, 1.40, progression)
		var pieces: int = 0
		for word: Dictionary in words:
			pieces += (word.morphology.parts.size() + (0 if str(word.get("image", "")).is_empty() else 1)) \
				* int(goals[word.id])
		var handling: float = float(pieces) * 1.6
		var supply: float = maxf(0.0, float(pieces - 15)) / 5.0 * cadence
		var margin: float = 1.0 + (MARGINS[wave] - 1.0) * lerpf(1.0, 0.15, progression)
		var warmup_floor: float = lerpf(90.0, 60.0, smoothstep(1.0, 28.0, float(number)))
		seconds = clampf(ceilf(maxf(handling, supply) * margin + 25.0), warmup_floor, 900.0)
	return {"ok": true, "error": "", "kind": "challenge" if challenge else "main",
		"number": 0 if challenge else number, "chapter": chapter,
		"title": "Survival Challenge" if challenge else CHAPTERS[chapter - 1],
		"profile": "Challenge" if challenge else PROFILES[wave], "age": age, "seed": seed,
		"words": words, "word_ids": ids, "goals": goals, "seconds": seconds,
		"spawn_interval": cadence, "fall_speed_scale": fall_speed}


## Returns a versioned recipe, or an explicit {ok: false, error} result.
static func to_recipe(plan: Dictionary) -> Dictionary:
	if (plan.has("ok") and (not plan.ok is bool or not plan.ok)) or not plan.get("words") is Array:
		return _failure("A replay recipe needs a valid stage plan and its reviewed word definitions.")
	if plan.words.is_empty() or plan.words.size() > MAX_CHALLENGE_WORDS:
		return _failure("A stage plan needs a bounded nonempty target set.")
	var identities: Dictionary = {}
	for word: Variant in plan.words:
		var word_error: String = _word_error(word)
		if not word_error.is_empty():
			return _failure(word_error)
		if identities.has(word.id):
			return _failure("A stage plan cannot repeat a word identity.")
		identities[word.id] = _identity(word)
	var recipe: Dictionary = {"version": VERSION, "identities": identities}
	for key: String in RECIPE_KEYS:
		if key in ["version", "identities"]:
			continue
		var value: Variant = plan.get(key, 0 if key in ["age", "seed"] else null)
		recipe[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	var validation_error: String = recipe_error(recipe)
	if not validation_error.is_empty():
		return _failure(validation_error)
	if plan.words.size() != recipe.word_ids.size():
		return _failure("A stage plan's words do not match its saved target identities.")
	var spellings: Dictionary = {}
	for index in range(plan.words.size()):
		var word: Dictionary = plan.words[index]
		var spelling: String = str(word.text).strip_edges().to_lower()
		if word.id != recipe.word_ids[index] or spellings.has(spelling):
			return _failure("Stage target order and distinct spellings must match the recipe.")
		spellings[spelling] = true
	return recipe


static func rebuild_plan(recipe: Dictionary, pool: Array) -> Dictionary:
	var validation_error: String = recipe_error(recipe)
	if not validation_error.is_empty():
		return _failure(validation_error)
	if pool.size() > MAX_POOL_WORDS:
		return _failure("This replay needs a bounded word pool.")
	var bindings: Dictionary = {}
	for word: Variant in pool:
		if not word is Dictionary or not recipe.identities.has(word.get("id")):
			continue
		var word_error: String = _word_error(word)
		if not word_error.is_empty() or _identity(word) != recipe.identities[word.id]:
			return _failure("The saved definition for " + str(word.get("id", "")) + " is unavailable or revised.")
		if bindings.has(word.id) and _identity(bindings[word.id]) != _identity(word):
			return _failure("The replay contains an ambiguous saved word identity.")
		bindings[word.id] = word.duplicate(true)
	var words: Array[Dictionary] = []
	for id: String in recipe.word_ids:
		if not bindings.has(id):
			return _failure("The saved word " + id + " is unavailable. Restore its original content to replay.")
		words.append(bindings[id])
	var result: Dictionary = recipe.duplicate(true)
	result.erase("version")
	result.erase("identities")
	result["words"] = words
	result["ok"] = true
	result["error"] = ""
	return result


## Validates saved parameters without requiring transient word/media definitions.
static func recipe_error(value: Variant) -> String:
	if not value is Dictionary or value.size() != RECIPE_KEYS.size() or not value.has_all(RECIPE_KEYS):
		return "A replay recipe needs its complete immutable parameters."
	if not value.version is int or value.version != VERSION:
		return "This replay needs a supported recipe version."
	if not value.kind is String or value.kind not in ["main", "challenge"]:
		return "A recipe needs a main or challenge kind."
	var challenge: bool = value.kind == "challenge"
	if not value.number is int or (value.number != 0 if challenge else value.number < 1 or value.number > MAX_STAGE):
		return "A recipe has an invalid stage number."
	var chapter: int = 1 if challenge else ceili(float(value.number) / 9.0)
	var profile: String = "Challenge" if challenge else PROFILES[(int(value.number) - 1) % PROFILES.size()]
	if not value.chapter is int or value.chapter != chapter or not value.profile is String or value.profile != profile \
		or not _valid_id(value.title) or value.title.length() > 256:
		return "A recipe has an invalid chapter, title or difficulty profile."
	if not value.age is int or value.age < 0 or value.age > 120 or not value.seed is int:
		return "A recipe has an invalid learning age or deterministic seed."
	var limit: int = MAX_CHALLENGE_WORDS if challenge else mini(int(value.number) + 2, MAX_MAIN_WORDS)
	if not value.word_ids is Array or value.word_ids.is_empty() or value.word_ids.size() > limit \
		or not value.identities is Dictionary or value.identities.size() != value.word_ids.size() \
		or not value.goals is Dictionary or value.goals.size() != (0 if challenge else value.word_ids.size()):
		return "A recipe needs bounded distinct word identities and matching goals."
	var seen: Dictionary = {}
	for id: Variant in value.word_ids:
		if not _valid_id(id) or seen.has(id) or not _valid_hash(value.identities.get(id)):
			return "A recipe contains an invalid, repeated or unbound word identity."
		seen[id] = true
		if not challenge and (not value.goals.get(id) is int or value.goals[id] < 1 or value.goals[id] > MAX_GOAL):
			return "A recipe needs positive bounded whole collection goals."
	if not _number_between(value.seconds, CHALLENGE_SECONDS if challenge else 0.001, CHALLENGE_SECONDS if challenge else 900.0) \
		or not _number_between(value.spawn_interval, 3.0, 60.0) \
		or not _number_between(value.fall_speed_scale, 0.1, 2.2):
		return "A recipe has an invalid timer, supply cadence or fall-speed scale."
	return ""


static func clear_reward(number: int, stars: int, chest_coins: int) -> Dictionary:
	if number < 0 or number > MAX_STAGE or stars < 0 or stars > 3 or chest_coins < 0 or chest_coins > MAX_COINS:
		return _failure("A clear quote needs a supported stage, star rating and nonnegative chest amount.")
	var base: int = 0 if number == 0 else 75 + 15 * (ceili(float(number) / 9.0) - 1)
	var total: int = chest_coins
	var factor: float = 0.0
	if number != 0 and stars != 0:
		if chest_coins > MAX_COINS - base:
			return _failure("This stage settlement exceeds the supported coin amount.")
		var combined: int = chest_coins + base
		factor = [0.0, 1.0, 1.5, 2.0][stars]
		if stars == 2:
			@warning_ignore("integer_division")
			var weighted: int = (combined * 3 + 1) / 2
			total = weighted
		else:
			total = combined * (2 if stars == 3 else 1)
		if total > MAX_COINS:
			return _failure("This star-weighted settlement exceeds the supported coin amount.")
	return {"ok": true, "error": "", "policy": "jelly-stage-clear-v1", "number": number,
		"stars": stars, "base": base, "factor": factor, "chest_coins": chest_coins,
		"bonus": total - chest_coins, "total": total}


static func _word_error(value: Variant) -> String:
	if not value is Dictionary or not _valid_id(value.get("id")) or not _valid_id(value.get("text")):
		return "Stage words need valid lexical identities and readable spellings."
	if not value.get("image", "") is String or not value.get("audio", "") is String:
		return "Stage word media references must be strings."
	if str(value.get("image", "")).length() > 4096 or str(value.get("audio", "")).length() > 4096:
		return "Stage word media references exceed their supported length."
	var compiled: Dictionary = Analysis.compile(value.get("morphology"))
	if not compiled.ok:
		return "Stage words need reviewed morphology: " + str(compiled.error)
	if compiled.analysis.lexeme_id != value.id or compiled.analysis.text != value.text:
		return "A stage word's spelling and sense must match its reviewed morphology."
	return ""


static func _identity(word: Dictionary) -> String:
	# Age and runtime media URLs may change; the saved lexical construction may not.
	return JSON.stringify([word.id, word.text, word.morphology,
		not str(word.get("image", "")).is_empty()]).sha256_text()


static func _valid_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > MAX_ID_LENGTH or value.strip_edges() != value:
		return false
	for index in range(value.length()):
		if value.unicode_at(index) < 32 or value.unicode_at(index) == 127:
			return false
	return true


static func _valid_hash(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true


static func _number_between(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) >= minimum and float(value) <= maximum


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
