extends RefCounted
## Chest appearance progresses independently of the player's learning level.

const THEMES: Array[String] = ["jungle", "autumn", "ocean", "space", "spring", "winter"]


static func theme_for_tier(tier: int) -> String:
	return THEMES[clampi(tier - 1, 0, THEMES.size() - 1)]


static func title_for_tier(tier: int) -> String:
	return "Chest Lv. %d" % maxi(1, tier)
