extends SceneTree
## Exact budgeting scenarios, not measured player behavior.

const Economy = preload("res://scripts/coin_economy.gd")
const Jelly = preload("res://scripts/word_jelly_model.gd")


func _initialize() -> void:
	print(JSON.stringify(build_report(), "  "))
	quit()


static func fixture_words() -> Array:
	var words: Array = []
	for name: String in ["cat", "dog", "hat", "sun", "cup", "pig"]:
		words.append({"id": name, "text": name, "min_age": 3,
			"image": "assets/images/words/%s.png" % name,
			"audio": "assets/audio/words/%s.wav" % name})
	return words


static func supply_groups(count: int) -> Array[Dictionary]:
	# Drain actual supplied packets into a ledger. Clearing cells here models
	# consumption only; this report does not assert a player's matching speed.
	var game := Jelly.new()
	if not game.configure(fixture_words(), 3, 20261014):
		return []
	var groups: Dictionary = {}
	while groups.size() < count:
		for tile: Dictionary in game.cells:
			var id: int = int(tile.supply_group)
			if not groups.has(id):
				groups[id] = {"id": id, "chunks": 0, "fragments": 0}
			groups[id].chunks += 1
			groups[id].fragments += int(tile.fragments)
		game.cells.clear()
		if groups.size() < count and not game.drop_now():
			return []
	var ids: Array = groups.keys()
	ids.sort()
	var result: Array[Dictionary] = []
	for id: int in ids.slice(0, count):
		result.append(groups[id])
	return result


static func chest_payout(fragments: int) -> int:
	var tier: int = int(Jelly.reward_progress(fragments).chest_tier)
	return int(Economy.chest_reward(tier, 0).total) if tier > 0 else 0


static func expected_chest(marked_groups: int, success: float, treasure_uses: int = 0) -> float:
	# Each source word is independently collected with the stated probability.
	# Keep the full distribution: rounding mean fragments gives a wrong answer
	# near unlock/upgrade boundaries. All paid fragments are optimistically kept.
	var distribution: Array[float] = [1.0]
	for _index in range(marked_groups):
		var next: Array[float] = []
		next.resize(distribution.size() + 1)
		next.fill(0.0)
		for fragments in range(distribution.size()):
			next[fragments] += distribution[fragments] * (1.0 - success)
			next[fragments + 1] += distribution[fragments] * success
		distribution = next
	var outcomes: int = Economy.TREASURE_FRAGMENT_MAX - Economy.TREASURE_FRAGMENT_MIN + 1
	for _use in range(treasure_uses):
		var next: Array[float] = []
		next.resize(distribution.size() + Economy.TREASURE_FRAGMENT_MAX)
		next.fill(0.0)
		for fragments in range(distribution.size()):
			for bonus in range(Economy.TREASURE_FRAGMENT_MIN, Economy.TREASURE_FRAGMENT_MAX + 1):
				next[fragments + bonus] += distribution[fragments] / float(outcomes)
		distribution = next
	var result: float = 0.0
	for fragments in range(distribution.size()):
		result += distribution[fragments] * chest_payout(fragments)
	return result


static func purchase_total(kind: String, uses: int) -> int:
	var total: int = 0
	for use in range(uses):
		total += Economy.powerup_price(kind, use)
	return total


static func scenario(supplied_words: int, success: float) -> Dictionary:
	var groups: Array[Dictionary] = supply_groups(supplied_words)
	var marked: int = 0
	for group: Dictionary in groups:
		marked += int(group.fragments)
	var chest: float = expected_chest(marked, success)
	# This source workload collects each ordinary word at Lv1 without upgrades.
	var bonus: float = supplied_words * success * Economy.jelly_bonus_chance(1) * Economy.jelly_bonus(1)
	var total: float = chest + bonus
	var with_treasure: float = expected_chest(marked, success, 1) + bonus - purchase_total("fragments", 1)
	return {
		"supplied_words": supplied_words, "success_probability": success,
		"expected_collected_words": supplied_words * success, "natural_marked_groups": marked,
		"free_play_chest": chest, "free_play_bonus": bonus, "free_play_total": total,
		"one_treasure_net": with_treasure,
		"one_treasure_every_three_sessions_net_average": (total * 2.0 + with_treasure) / 3.0,
		"one_auto_merge_net": total - purchase_total("auto_merge", 1),
		"three_treasure_net": expected_chest(marked, success, 3) + bonus - purchase_total("fragments", 3),
		"three_auto_merge_net": total - purchase_total("auto_merge", 3)
	}


static func build_report() -> Dictionary:
	var scenarios: Array[Dictionary] = []
	var upgraded_collections: Array[Dictionary] = []
	for level in range(1, Jelly.MAX_MERGE_LEVEL + 1):
		var expected_bonus: float = Economy.jelly_bonus_chance(level) * Economy.jelly_bonus(level)
		upgraded_collections.append({"merge_level": level,
			"chance": Economy.jelly_bonus_chance(level), "winning_amount": Economy.jelly_bonus(level),
			"expected_bonus": expected_bonus, "source_words": level,
			"expected_bonus_per_source_word": expected_bonus / float(level)})
	for count: int in [20, 40, 60]:
		for success: float in [0.6, 1.0]:
			scenarios.append(scenario(count, success))
	return {
		"assumptions": [
			"Scenario inputs are modeled workloads, not measured players or session lengths.",
			"Each supplied two-chunk word has an independent stated chance of being collected.",
			"Source workloads collect ordinary Lv1 words, which have no coin bonus; upgraded collection rewards are reported separately.",
			"Additive merges preserve source word count: a LvN body combines N completed Lv1 words, up to Lv9.",
			"All injected Treasure fragments are collected: this overestimates paid returns.",
			"Net budgets assume enough previously saved coins to buy the specified items.",
			"Auto Merge uses the same completed workload; no automatic collection or bonus income is assumed.",
			"One modeled session is one round; fresh rounds reset repeat prices."
		],
		"scenarios": scenarios, "upgraded_collections": upgraded_collections
	}
