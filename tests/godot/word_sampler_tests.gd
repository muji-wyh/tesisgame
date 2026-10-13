extends SceneTree

const Sampler = preload("res://scripts/word_sampler.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _words(count: int = 20, mixed: bool = true) -> Array:
	var words: Array = []
	for index in range(count):
		words.append({"id": "word-%d" % index, "mastered": mixed and index < count / 2,
			"_practice_weight": 0.8 if mixed and index < count / 2 else 1.0})
	return words


func _run() -> void:
	_test_finite_order()
	_test_continuous_supply()
	_test_equal_weights_and_small_pools()
	_test_live_weights()
	_test_late_mastery_transitions()
	print("Word sampler: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_finite_order() -> void:
	check(is_equal_approx(Sampler.MASTERED_WEIGHT, 0.8) and is_equal_approx(Sampler.weight({}), 1.0),
		"Mastered words have a modest twenty-percent discount, with unannotated words at full weight")
	var words: Array = _words()
	var original: Array = words.duplicate(true)
	var rng := RandomNumberGenerator.new()
	var twin := RandomNumberGenerator.new()
	var first_mastered: int = 0
	var prefixes: Dictionary = {}
	for seed_value in range(2000):
		rng.seed = seed_value
		twin.seed = seed_value
		var ordered: Array = Sampler.weighted_order(words, rng)
		check(ordered == Sampler.weighted_order(words, twin), "A fixed seed reproduces the weighted order")
		var ids: Dictionary = {}
		for word: Dictionary in ordered:
			ids[str(word.id)] = true
		check(ids.size() == words.size() and ordered.size() == words.size(),
			"Weighted ordering retains every word exactly once")
		first_mastered += 1 if bool(ordered[0].mastered) else 0
		prefixes[str(ordered[0].id)] = true
	var ratio: float = float(first_mastered) / float(2000 - first_mastered)
	check(ratio > 0.70 and ratio < 0.92,
		"The first finite choice mildly favors unmastered words, without a strict mastered tail: %.3f" % ratio)
	check(prefixes.size() == words.size(), "Both mastered and unmastered words can lead a lesson")
	check(words == original, "Sampling leaves caller-owned vocabulary and metadata unchanged")
	check(Sampler.weighted_order([], rng).is_empty(), "An empty finite catalog has no fabricated entries")


func _test_continuous_supply() -> void:
	var words: Array = _words()
	var rng := RandomNumberGenerator.new()
	var twin := RandomNumberGenerator.new()
	rng.seed = 1729
	twin.seed = 1729
	var counts: Dictionary = {}
	var repeated_counts: Dictionary = {}
	var service: Dictionary = {}
	var repeated_service: Dictionary = {}
	var mastered: int = 0
	var unmastered: int = 0
	var recent: Array[String] = []
	var maximum_recent_repeats: int = 0
	for index in range(6000):
		var word: Dictionary = Sampler.next_word(words, rng, counts, service)
		check(word == Sampler.next_word(words, twin, repeated_counts, repeated_service),
			"Fixed-seed continuous supply stays reproducible beyond the first catalog cycle")
		if bool(word.mastered):
			mastered += 1
		else:
			unmastered += 1
		maximum_recent_repeats = maxi(maximum_recent_repeats, recent.count(str(word.id)))
		recent.append(str(word.id))
		if recent.size() > 10:
			recent.pop_front()
		if index in [599, 5999]:
			var ratio: float = float(mastered) / float(unmastered)
			check(ratio > 0.76 and ratio < 0.84,
				"Mastery still lowers exposure after many full catalog cycles: %.3f" % ratio)
	check(counts.size() == words.size() and counts.values().min() > 250,
		"Every mastered word continues receiving regular review without starvation")
	check(counts.values().reduce(func(total: int, value: int) -> int: return total + value, 0) == 6000,
		"Each successful draw increments exactly one exposure count")
	check(maximum_recent_repeats <= 1, "The modest bias does not create repeated-word bursts")
	var before: Dictionary = counts.duplicate(true)
	check(Sampler.next_word([], rng, counts, service).is_empty() and counts == before,
		"An empty continuous catalog consumes no word exposure")


func _test_equal_weights_and_small_pools() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	for pool_size in [1, 2, 3, 20]:
		for mastery_weight in [0.8, 1.0]:
			var words: Array = _words(pool_size, false)
			for word: Dictionary in words:
				word._practice_weight = mastery_weight
			var counts: Dictionary = {}
			var service: Dictionary = {}
			for cycle in range(8):
				var seen: Dictionary = {}
				for index in range(pool_size):
					var word: Dictionary = Sampler.next_word(words, rng, counts, service)
					seen[str(word.id)] = true
				check(seen.size() == pool_size,
					"Equal-weight catalogs visit every word before repeating, including all-mastered and tiny pools")
			check(counts.values().min() == 8 and counts.values().max() == 8,
				"Uniform catalogs keep balanced exposure over repeated cycles")
	for pool_size in [2, 3]:
		var words: Array = _words(pool_size)
		var counts: Dictionary = {}
		var service: Dictionary = {}
		for index in range(300):
			Sampler.next_word(words, rng, counts, service)
		check(counts.size() == pool_size and counts.values().min() >= 80,
			"A tiny mixed-mastery pool remains playable and never excludes review")


func _test_live_weights() -> void:
	var words: Array = _words(20, false)
	var live_mastered: Dictionary = {}
	var callback: Callable = func(word: Dictionary) -> float:
		return 0.8 if live_mastered.has(str(word.id)) else 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 119
	var counts: Dictionary = {}
	var service: Dictionary = {}
	for index in range(40):
		Sampler.next_word(words, rng, counts, service, callback)
	for index in range(10):
		live_mastered[str(words[index].id)] = true
	var mastered: int = 0
	var unmastered: int = 0
	for index in range(1800):
		var word: Dictionary = Sampler.next_word(words, rng, counts, service, callback)
		if live_mastered.has(str(word.id)):
			mastered += 1
		else:
			unmastered += 1
	var ratio: float = float(mastered) / float(unmastered)
	check(ratio > 0.76 and ratio < 0.84,
		"New mastery changes later supply in the same session without replacing the catalog: %.3f" % ratio)
	check(words.all(func(word: Dictionary) -> bool: return float(word._practice_weight) == 1.0),
		"Live mastery weighting does not rewrite catalog metadata")


func _test_late_mastery_transitions() -> void:
	var words: Array = _words(20, false)
	var live_mastered: Dictionary = {}
	var callback: Callable = func(word: Dictionary) -> float:
		return 0.8 if live_mastered.has(str(word.id)) else 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 173
	var counts: Dictionary = {}
	var service: Dictionary = {}
	for index in range(2000):
		Sampler.next_word(words, rng, counts, service, callback)
	check(counts.size() == 20 and counts.values().min() == 100 and counts.values().max() == 100,
		"The late-mastery fixture first practices every word one hundred times")
	for index in range(10):
		live_mastered[str(words[index].id)] = true
	var next_counts: Dictionary = {}
	var mastered: int = 0
	var unmastered: int = 0
	for index in range(1800):
		var word: Dictionary = Sampler.next_word(words, rng, counts, service, callback)
		if index < 40:
			next_counts[str(word.id)] = int(next_counts.get(str(word.id), 0)) + 1
		if live_mastered.has(str(word.id)):
			mastered += 1
		else:
			unmastered += 1
		if index == 39:
			check(next_counts.size() == 20 and next_counts.values().min() >= 1 and next_counts.values().max() <= 3,
				"Late mastery preserves near-term variety without a long review drought or compensating burst")
		if index == 179:
			var early_ratio: float = float(mastered) / float(unmastered)
			check(early_ratio > 0.70 and early_ratio < 0.92,
				"Late mastery gives a gentle bias in the next few catalog cycles: %.3f" % early_ratio)
	var ratio: float = float(mastered) / float(unmastered)
	check(ratio > 0.76 and ratio < 0.84,
		"Late mastery keeps the intended long-run ratio without rescaling old learning history: %.3f" % ratio)
	live_mastered.clear()
	next_counts.clear()
	for index in range(40):
		var word: Dictionary = Sampler.next_word(words, rng, counts, service, callback)
		next_counts[str(word.id)] = int(next_counts.get(str(word.id), 0)) + 1
	check(next_counts.size() == 20 and next_counts.values().min() >= 1 and next_counts.values().max() <= 3,
		"Returning a practiced word to unmastered status avoids a historical catch-up burst")
	check(counts.values().reduce(func(total: int, value: int) -> int: return total + value, 0) == 3840,
		"Mastery transitions preserve the exact number of actual word exposures")
