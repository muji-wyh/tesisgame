extends RefCounted
## Gentle mastery weighting with bounded repetition for continuous word supply.

const MASTERED_WEIGHT: float = 0.8


static func weight(word: Dictionary, weight_for: Callable = Callable()) -> float:
	var value: float = float(weight_for.call(word)) if weight_for.is_valid() else float(word.get("_practice_weight", 1.0))
	return clampf(value, 0.01, 1.0) if is_finite(value) and value > 0.0 else 1.0


static func weighted_order(items: Array, rng: RandomNumberGenerator, weight_for: Callable = Callable()) -> Array:
	# Exponential keys produce a weighted shuffle without replacing or editing items.
	var ranked: Array[Dictionary] = []
	for index in range(items.size()):
		ranked.append({"item": items[index], "index": index,
			"key": -log(maxf(rng.randf(), 0.0000001)) / weight(items[index], weight_for)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.key < b.key if a.key != b.key else a.index < b.index)
	return ranked.map(func(entry: Dictionary) -> Dictionary: return entry.item)


static func next_word(words: Array, rng: RandomNumberGenerator, counts: Dictionary,
	service: Dictionary, weight_for: Callable = Callable()) -> Dictionary:
	if words.is_empty():
		return {}
	var entries: Array[Dictionary] = []
	var least_exposure: float = INF
	for word: Dictionary in words:
		var chance: float = weight(word, weight_for)
		var exposure: float = float(service.get(str(word.id), 0.0))
		least_exposure = minf(least_exposure, exposure)
		entries.append({"word": word, "weight": chance, "exposure": exposure})
	# Equal weights visit every eligible word before repeating. With mixed weights,
	# a one-visit window keeps variety while retaining the bias over long sessions.
	var candidates: Array = entries.filter(func(entry: Dictionary) -> bool:
		return float(entry.exposure) < least_exposure + 1.0 - 0.000001)
	var total: float = 0.0
	for entry: Dictionary in candidates:
		total += float(entry.weight)
	var roll: float = rng.randf() * total
	var chosen: Dictionary = candidates.back().word
	var chosen_weight: float = float(candidates.back().weight)
	for entry: Dictionary in candidates:
		roll -= float(entry.weight)
		if roll < 0.0:
			chosen = entry.word
			chosen_weight = float(entry.weight)
			break
	var id: String = str(chosen.id)
	counts[id] = int(counts.get(id, 0)) + 1
	# Apply mastery to this visit only, so a late change cannot create a long
	# absence or a catch-up burst by reweighting the word's entire history.
	service[id] = float(service.get(id, 0.0)) + 1.0 / chosen_weight
	return chosen
