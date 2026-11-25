extends RefCounted
## Shared future reward and purchase values; saved wallet receipts keep their amounts.

const COINS_PER_TIER: int = 50
const CHEST_BASE_COINS: int = 75
const CHEST_REWARD_POLICY: String = "pip-chest-v2"
const PREVIOUS_CHEST_REWARD_POLICY: String = "pip-chest-v1"
const LEGACY_CHEST_REWARD_POLICY: String = "legacy-chest-v1"
const MATCH_HINT_PRICES: Array[int] = [100, 150, 200]
const MEMORY_PEEK_PRICES: Array[int] = [0, 100, 200, 300]
# Retired quotes remain available to historical reports, not the live tool catalog.
const POWERUP_BASE_PRICES: Dictionary = {"auto_merge": 50, "family_merge": 25, "fragments": 200, "extra_time": 100}
const AUTO_MERGE_UNIT_PRICES: Array[int] = [50, 100, 150]
const MERGE_UNIT_PRICES: Array[int] = [25, 50, 75]
const JELLY_BONUS_CHANCES: Array[float] = [0.0, 0.12, 0.22, 0.32, 0.42, 0.52, 0.62, 0.72, 0.85]
const JELLY_BONUS_AMOUNTS: Array[int] = [0, 50, 100, 150, 200, 250, 300, 350, 450]
const TREASURE_FRAGMENT_MIN: int = 2
const TREASURE_FRAGMENT_MAX: int = 8
const JELLY_UPGRADE_PRICES: Array[int] = [50, 100, 200, 350, 550, 800, 1100, 1500]
const AUTO_MERGE_UPGRADE_PRICES: Array[int] = [50, 100, 175, 275, 425, 625, 875, 1175]
const STAR_CHARM_UPGRADE_PRICES: Array[int] = [50, 125, 225, 375, 600, 900, 1250, 1700]
const BOSS_FIRST_VICTORY_BOUNTIES: Array[int] = [0, 100, 125, 150, 200, 250, 300, 350, 500]
const MINI_RAID_VICTORY_BONUS: int = 75
const LEFTOVER_FRAGMENT_COINS: int = 15
const PURE_CLEAR_BONUS_RATIO: float = 0.20
const REPLAY_BASE_RATIO: float = 0.50
const STAR_UPGRADE_COIN_STEP: int = 35
const CHALLENGE_STAGE_MILESTONE_STEP: int = 5
const CHALLENGE_NEW_RECORD_BONUS: int = 75
const JELLY_FIRST_CLEAR_MIN_COINS: int = 50
const MAX_UPGRADE_LEVEL: int = 9
const MAX_PRESTIGE_RANK: int = 50
const PRESTIGE_BASE_PRICE: int = 1000
const PRESTIGE_PRICE_STEP: int = 250
const AUTO_MERGE_BASE_CAPACITY: int = 3
const CHAPTER_STAR_MILESTONES: Array[int] = [12, 21, 27]
const CHAPTER_MILESTONE_COINS: Dictionary = {12: 100, 21: 200, 27: 350}


static func chapter_milestone_reward(threshold: int) -> int:
	return int(CHAPTER_MILESTONE_COINS.get(threshold, 0))


static func boss_first_victory_bounty(boss_id: int) -> int:
	return BOSS_FIRST_VICTORY_BOUNTIES[boss_id] if boss_id >= 1 and boss_id < BOSS_FIRST_VICTORY_BOUNTIES.size() else 0


static func challenge_milestone_bonus(stage_reached: int) -> int:
	var milestones: int = floori(float(maxi(0, stage_reached)) / float(CHALLENGE_STAGE_MILESTONE_STEP))
	var total: int = 0
	for index in range(1, milestones + 1):
		total += 50 * index
	return total


static func leftover_fragment_coins(fragments: int) -> int:
	var count: int = maxi(0, fragments)
	if count <= 0:
		return 0
	var remainder: int = count if count < 4 else (count - 4) % 5
	return remainder * LEFTOVER_FRAGMENT_COINS


static func prestige_price(next_rank: int) -> int:
	if next_rank < 1 or next_rank > MAX_PRESTIGE_RANK:
		push_error("A Golden Crown rank needs a target from 1 to %d." % MAX_PRESTIGE_RANK)
		return 0
	return PRESTIGE_BASE_PRICE + PRESTIGE_PRICE_STEP * (next_rank - 1)


static func jelly_upgrade_price(level: int) -> int:
	if level < 2 or level > 9:
		push_error("A Jelly upgrade needs a level from 2 to 9.")
		return 0
	return JELLY_UPGRADE_PRICES[level - 2]


static func permanent_upgrade_price(kind: String, level: int) -> int:
	if kind == "jelly":
		return jelly_upgrade_price(level)
	if kind == "auto_merge":
		if level < 2 or level > 9:
			push_error("An Auto merge upgrade needs a level from 2 to 9.")
			return 0
		return AUTO_MERGE_UPGRADE_PRICES[level - 2]
	if kind == "star_charm":
		if level < 2 or level > 9:
			push_error("A Star charm upgrade needs a level from 2 to 9.")
			return 0
		return STAR_CHARM_UPGRADE_PRICES[level - 2]
	push_error("Choose Jelly powers, Auto merge or Star charm before pricing an upgrade.")
	return 0


static func auto_merge_capacity(level: int) -> int:
	return AUTO_MERGE_BASE_CAPACITY + clampi(level, 1, MAX_UPGRADE_LEVEL) - 1


static func star_charm_combo_bonus(level: int) -> float:
	return float(clampi(level, 1, MAX_UPGRADE_LEVEL) - 1) * 0.3


static func star_charm_fragment_bonus(level: int) -> float:
	return float(clampi(level, 1, MAX_UPGRADE_LEVEL) - 1) * 0.03


static func star_charm_grace_charges(level: int) -> int:
	var clamped: int = clampi(level, 1, MAX_UPGRADE_LEVEL)
	return 2 if clamped >= 6 else 1 if clamped >= 2 else 0


static func star_charm_boss_damage_bonus(level: int) -> float:
	var clamped: int = clampi(level, 1, MAX_UPGRADE_LEVEL)
	return 0.15 if clamped >= 9 else 0.08 if clamped >= 5 else 0.0


static func match_hint_price(successful_uses: int) -> int:
	return MATCH_HINT_PRICES[clampi(successful_uses, 0, MATCH_HINT_PRICES.size() - 1)]


static func memory_peek_price(successful_uses: int) -> int:
	return MEMORY_PEEK_PRICES[clampi(successful_uses, 0, MEMORY_PEEK_PRICES.size() - 1)]


# Optional level and reduction arguments remain compatible with older callers.
static func powerup_price(kind: String, successful_uses: int, auto_merge_level: int = 1, _reduction_count: int = 1) -> int:
	if not POWERUP_BASE_PRICES.has(kind):
		return 0
	if kind == "extra_time":
		return 100 + 50 * clampi(successful_uses, 0, 4095)
	if kind == "auto_merge":
		var base_price: int = AUTO_MERGE_UNIT_PRICES[clampi(successful_uses, 0, AUTO_MERGE_UNIT_PRICES.size() - 1)]
		var discount: int = 25 if clampi(auto_merge_level, 1, MAX_UPGRADE_LEVEL) >= 6 else 0
		return maxi(25, base_price - discount)
	if kind == "family_merge":
		return MERGE_UNIT_PRICES[clampi(successful_uses, 0, MERGE_UNIT_PRICES.size() - 1)]
	var extra: int = 100
	return int(POWERUP_BASE_PRICES[kind]) + extra * clampi(successful_uses, 0, 2)


static func jelly_bonus_chance(merge_level: int) -> float:
	return JELLY_BONUS_CHANCES[clampi(merge_level, 1, JELLY_BONUS_CHANCES.size()) - 1]


static func jelly_bonus(merge_level: int) -> int:
	return JELLY_BONUS_AMOUNTS[clampi(merge_level, 1, JELLY_BONUS_AMOUNTS.size()) - 1]


static func jelly_combo_bonus(count: int) -> int:
	if count < 3:
		return 0
	if count < 6:
		return 1
	if count < 10:
		return 2
	if count < 15:
		return 4
	return 6


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
