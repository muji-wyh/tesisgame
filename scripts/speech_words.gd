extends RefCounted

# Reviewed ASR spellings only. Separators may vary; arbitrary adjacent nouns
# must never become a different word simply because that word is on screen.
const COMPOUND_PARTS: Dictionary = {
	"seahorse": ["sea", "horse"], "seahorses": ["sea", "horses"],
	"sunflower": ["sun", "flower"], "sunflowers": ["sun", "flowers"],
	"sunglasses": ["sun", "glasses"],
	"pinecone": ["pine", "cone"], "pinecones": ["pine", "cones"],
	"yoyo": ["yo", "yo"], "yoyos": ["yo", "yos"]
}

# Exact sound equivalents, including common English pronunciation variants.
# Plural groups are explicit: do not invent forms such as "bes" or "knowses".
const HOMOPHONE_GROUPS: Array = [
	["sun", "son"], ["suns", "sons"],
	["ball", "bawl"], ["balls", "bawls"],
	["horse", "hoarse"],
	["bear", "bare"], ["bears", "bares"],
	["bee", "be", "b"],
	["ant", "aunt"], ["ants", "aunts"],
	["pear", "pair", "pare"], ["pears", "pairs", "pares"],
	["carrot", "carat", "caret", "karat"], ["carrots", "carats", "carets", "karats"],
	["bread", "bred"],
	["peas", "pees"],
	["eye", "i", "aye"], ["eyes", "ayes"],
	["nose", "knows", "noes"],
	["shoe", "shoo"], ["shoes", "shoos"],
	["rain", "reign", "rein"],
	["flower", "flour"], ["flowers", "flours"],
	["plane", "plain"], ["planes", "plains"],
	["key", "quay"], ["keys", "quays"],
	["bowl", "bole", "boll"], ["bowls", "boles", "bolls"],
	["whale", "wail", "wale"], ["whales", "wails", "wales"],
	["seed", "cede"], ["seeds", "cedes"],
	["root", "route"], ["roots", "routes"],
	["rose", "rows", "roes"],
	["berry", "bury"], ["berries", "buries"],
	["bell", "belle"], ["bells", "belles"],
	["ring", "wring"], ["rings", "wrings"],
	["tie", "thai"], ["ties", "thais"],
	["cymbal", "symbol"], ["cymbals", "symbols"],
	["deer", "dear"],
	["plum", "plumb"], ["plums", "plumbs"],
	["jam", "jamb"], ["jams", "jambs"],
	["beach", "beech"], ["beaches", "beeches"],
	["toe", "tow"], ["toes", "tows"],
	["beetle", "beatle"], ["beetles", "beatles"],
	["ferry", "fairy", "faery"], ["ferries", "fairies", "faeries"]
]

# Preserve Voice Pop's noun forms without stripping suffixes from transcripts.
const UNCHANGED_PLURALS: Array[String] = [
	"fish", "sheep", "peas", "corn", "bread", "cheese", "milk", "water", "juice", "rice",
	"rain", "snow", "grass", "pants", "sunglasses", "coral", "squid", "jellyfish", "starfish", "bamboo",
	"deer", "honey", "pasta", "sand", "mud", "ice", "wind", "shorts", "dice",
	"broccoli", "lettuce", "slippers", "earmuffs", "crayons", "asparagus", "cinnamon",
	"plankton", "swordfish", "binoculars"
]
const SPECIAL_PLURALS: Dictionary = {
	"mouse": ["mice"], "foot": ["feet"], "tooth": ["teeth"], "leaf": ["leaves"],
	"scarf": ["scarves", "scarfs"], "tomato": ["tomatoes"], "octopus": ["octopuses", "octopi"],
	"cactus": ["cacti", "cactuses"], "mango": ["mangoes", "mangos"],
	"potato": ["potatoes"], "volcano": ["volcanoes", "volcanos"],
	"domino": ["dominoes", "dominos"]
}


static func normalize_text(text: String, accepted_forms: Array = []) -> String:
	var normalized: String = text.to_lower()
	var compounds: Array = COMPOUND_PARTS.keys().filter(func(word: String) -> bool: return accepted_forms.has(word))
	compounds.sort_custom(func(first: String, second: String) -> bool:
		return COMPOUND_PARTS[first].size() > COMPOUND_PARTS[second].size() if COMPOUND_PARTS[first].size() != COMPOUND_PARTS[second].size() else first.length() > second.length())
	for canonical: String in compounds:
		var pattern := RegEx.new()
		pattern.compile("(?<![\\p{L}\\p{N}_'’-])" + "[ -]+".join(COMPOUND_PARTS[canonical]) + "(?![\\p{L}\\p{N}_'’-])")
		normalized = pattern.sub(normalized, canonical, true)
	return normalized


static func tokens(text: String, accepted_forms: Array = ["yoyo", "yoyos"]) -> Array[String]:
	var pattern := RegEx.new()
	# Keep Unicode letters, numbers and possessives intact. "bare2", "bared",
	# "bear's" and "bare\u00e9" must not turn into a hit for bear.
	pattern.compile("[\\p{L}\\p{N}_]+(?:['\u2019][\\p{L}\\p{N}_]+)*")
	var result: Array[String] = []
	for token in pattern.search_all(normalize_text(text, accepted_forms)):
		result.append(token.get_string())
	return result


static func compounds_conflict(first: String, second: String) -> bool:
	if not COMPOUND_PARTS.has(first) and not COMPOUND_PARTS.has(second):
		return false
	var first_forms: Array[String] = forms(first, true)
	var second_forms: Array[String] = forms(second, true)
	for compound: String in COMPOUND_PARTS:
		var parts: Array = COMPOUND_PARTS[compound]
		if first_forms.has(compound) and second_forms.any(func(form: String) -> bool: return parts.has(form)):
			return true
		if second_forms.has(compound) and first_forms.any(func(form: String) -> bool: return parts.has(form)):
			return true
	return false


static func browser_lexicon(words: Array) -> Dictionary:
	var entries: Array[Dictionary] = []
	var seen: Dictionary = {}
	for word in words:
		if not word is Dictionary or not word.get("text") is String:
			continue
		var noun: String = word.text.strip_edges().to_lower()
		if noun.is_empty() or seen.has(noun):
			continue
		seen[noun] = true
		entries.append({"text": noun, "forms": forms(noun, true)})
	return {"compounds": COMPOUND_PARTS.duplicate(true), "words": entries}


static func forms(noun: String, include_plurals: bool = false) -> Array[String]:
	var result: Array[String] = [noun]
	if include_plurals and noun not in UNCHANGED_PLURALS:
		if SPECIAL_PLURALS.has(noun):
			result.append_array(SPECIAL_PLURALS[noun])
		elif noun.ends_with("y") and noun.length() > 1 and not noun[-2] in "aeiou":
			result.append(noun.left(-1) + "ies")
		elif noun.ends_with("s") or noun.ends_with("x") or noun.ends_with("z") or noun.ends_with("ch") or noun.ends_with("sh"):
			result.append(noun + "es")
		else:
			result.append(noun + "s")
	# Expand every real noun form, including nouns whose plurals stay unchanged.
	for form in result.duplicate():
		for group in HOMOPHONE_GROUPS:
			if group.has(form):
				for equivalent in group:
					if not result.has(equivalent):
						result.append(equivalent)
	return result
