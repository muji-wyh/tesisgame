extends RefCounted
## Shared future reward and purchase values; saved wallet receipts keep their amounts.

const COINS_PER_TIER: int = 50
const CHEST_BASE_COINS: int = 75
const CHEST_REWARD_POLICY: String = "pip-chest-v2"
const PREVIOUS_CHEST_REWARD_POLICY: String = "pip-chest-v1"
const LEGACY_CHEST_REWARD_POLICY: String = "legacy-chest-v1"
const MATCH_HINT_PRICES: Array[int] = [100, 150, 200]
const MEMORY_PEEK_PRICES: Array[int] = [0, 100, 200, 300]
const POWERUP_BASE_PRICES: Dictionary = {"auto_merge": 600, "family_merge": 200, "fragments": 200, "extra_time": 100}
const JELLY_BONUS_CHANCES: Array[float] = [0.0, 0.02, 0.04, 0.12, 0.20, 0.30, 0.40, 0.50, 0.80]
const JELLY_BONUS_AMOUNTS: Array[int] = [0, 50, 100, 150, 200, 250, 300, 350, 450]
const TREASURE_FRAGMENT_MIN: int = 2
const TREASURE_FRAGMENT_MAX: int = 8


static func match_hint_price(successful_uses: int) -> int:
	return MATCH_HINT_PRICES[clampi(successful_uses, 0, MATCH_HINT_PRICES.size() - 1)]


static func memory_peek_price(successful_uses: int) -> int:
	return MEMORY_PEEK_PRICES[clampi(successful_uses, 0, MEMORY_PEEK_PRICES.size() - 1)]


static func powerup_price(kind: String, successful_uses: int) -> int:
	if not POWERUP_BASE_PRICES.has(kind):
		return 0
	if kind == "extra_time":
		return 100 + 50 * clampi(successful_uses, 0, 4095)
	var extra: int = 300 if kind == "auto_merge" else 100
	return int(POWERUP_BASE_PRICES[kind]) + extra * clampi(successful_uses, 0, 2)


static func jelly_bonus_chance(merge_level: int) -> float:
	return JELLY_BONUS_CHANCES[clampi(merge_level, 1, JELLY_BONUS_CHANCES.size()) - 1]


static func jelly_bonus(merge_level: int) -> int:
	return JELLY_BONUS_AMOUNTS[clampi(merge_level, 1, JELLY_BONUS_AMOUNTS.size()) - 1]


static func jelly_combo_bonus(count: int) -> int:
	if count < 3:
		return 0
	return 1 if count < 6 else (2 if count < 10 else 3)


static func chest_coins(tier: int) -> int:
	return maxi(1, tier) * COINS_PER_TIER


static func chest_reward(tier: int, pip_level: int, policy: String = CHEST_REWARD_POLICY) -> Dictionary:
	if policy not in [CHEST_REWARD_POLICY, PREVIOUS_CHEST_REWARD_POLICY]:
		push_error("Unknown chest reward policy: " + policy)
		return {}
	var reward_tier: int = maxi(1, tier)
	var level: int = clampi(pip_level, 0, 99)
	var previous: bool = policy == PREVIOUS_CHEST_REWARD_POLICY
	var base: int = reward_tier * (COINS_PER_TIER if previous else CHEST_BASE_COINS)
	var bonus: int = reward_tier * (ceili(level / 4.0) if previous else ceili(level * 24.0 / 99.0))
	return {"policy": policy, "pip_level": level, "tier": reward_tier,
		"base": base, "bonus": bonus, "total": base + bonus}
