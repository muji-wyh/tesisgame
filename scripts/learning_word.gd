extends RefCounted
## Runtime contract for already resolved professional content. Editorial and
## media readiness remain the responsibility of LearningContentResolver.

static func professional(word: Dictionary, mode: String) -> bool:
	if word.get("track") != "professional" or not word.get("practice_modes") is Array \
		or not word.practice_modes.has(mode):
		return false
	for key in ["id", "text", "image", "audio"]:
		if not word.get(key) is String or str(word[key]).strip_edges().is_empty():
			return false
	return true


static func same_track(words: Array, track: String) -> bool:
	return words.all(func(word: Variant) -> bool:
		return word is Dictionary and word.get("track", "growth") == track)
