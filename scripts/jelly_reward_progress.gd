extends RefCounted
## Chest appearance progresses independently of the player's learning level.

const THEMES: Array[String] = ["jungle", "autumn", "ocean", "space", "spring", "winter"]
const CHEST_UNLOCK_FRAGMENTS: int = 4
const CHEST_UPGRADE_FRAGMENTS: int = 5
const MAX_TIER: int = 30


static func reward_progress(total: int) -> Dictionary:
	var fragments: int = maxi(0, total)
	var tier: int = 0
	var progress: int = fragments
	var required: int = CHEST_UNLOCK_FRAGMENTS
	if fragments >= CHEST_UNLOCK_FRAGMENTS:
		tier = mini(MAX_TIER, 1 + int((fragments - CHEST_UNLOCK_FRAGMENTS) / float(CHEST_UPGRADE_FRAGMENTS)))
		progress = (fragments - CHEST_UNLOCK_FRAGMENTS) % CHEST_UPGRADE_FRAGMENTS
		required = CHEST_UPGRADE_FRAGMENTS
		if tier == MAX_TIER:
			progress = required
	return {
		"fragment_count": fragments, "chest_tier": tier, "max_chest_tier": MAX_TIER,
		"chest_count": 1 if tier > 0 else 0,
		"fragments_toward_next": progress, "fragments_required": required
	}


static func theme_for_tier(tier: int) -> String:
	return THEMES[clampi(tier - 1, 0, THEMES.size() - 1)]


static func title_for_tier(tier: int) -> String:
	return "Chest Lv. %d" % clampi(tier, 1, MAX_TIER)
