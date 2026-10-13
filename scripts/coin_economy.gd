extends RefCounted
## Shared future reward and purchase values; saved wallet receipts keep their amounts.

const COINS_PER_TIER: int = 50
const MATCH_HINT_PRICES: Array[int] = [100, 150, 200]
const MEMORY_PEEK_PRICES: Array[int] = [0, 100, 200, 300]
const POWERUP_BASE_PRICES: Dictionary = {"auto_merge": 600, "fragments": 200}
const JELLY_BONUS_CHANCE: float = 0.01
const TREASURE_FRAGMENT_MIN: int = 2
const TREASURE_FRAGMENT_MAX: int = 8


static func match_hint_price(successful_uses: int) -> int:
	return MATCH_HINT_PRICES[clampi(successful_uses, 0, MATCH_HINT_PRICES.size() - 1)]


static func memory_peek_price(successful_uses: int) -> int:
	return MEMORY_PEEK_PRICES[clampi(successful_uses, 0, MEMORY_PEEK_PRICES.size() - 1)]


static func powerup_price(kind: String, successful_uses: int) -> int:
	if not POWERUP_BASE_PRICES.has(kind):
		return 0
	var extra: int = 300 if kind == "auto_merge" else 100
	return int(POWERUP_BASE_PRICES[kind]) + extra * clampi(successful_uses, 0, 2)


static func jelly_bonus(mass: int) -> int:
	return COINS_PER_TIER * (2 if mass >= 3 else 1)


static func chest_coins(tier: int) -> int:
	return maxi(1, tier) * COINS_PER_TIER
