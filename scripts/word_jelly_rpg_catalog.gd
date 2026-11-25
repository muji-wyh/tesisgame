extends RefCounted
## RPG definitions for Jelly World: stances, 8 Boss relics, Challenge boons,
## Boss ascension tiers, and pure Pip stat derivation. Zero scene dependencies.

const Data = preload("res://scripts/game_data.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")

const STANCES: Array[Dictionary] = [
	{
		"id": "scholar",
		"name": "Spark Scholar",
		"badge": "SPARK",
		"icon": "res://assets/images/ui/jelly-rpg/stance-scholar.webp",
		"accent": Color("#2a8c76"),
		"tint": Color("#e4f6ef"),
		"summary": "Combo & board chain specialist",
		"passive": "Manual upgrades +1 charge · Lv3+ collects can chain-upgrade 1 neighbor",
		"skill_name": "Starburst",
		"skill_desc": "Auto-matches up to 2 board pairs for free and sparks a bonus wave"
	},
	{
		"id": "hunter",
		"name": "Compass Hunter",
		"badge": "HUNTER",
		"icon": "res://assets/images/ui/jelly-rpg/stance-hunter.webp",
		"accent": Color("#6d4da6"),
		"tint": Color("#eee8fa"),
		"summary": "Boss counterplay & burst specialist",
		"passive": "Dodges give 2x Boss charge · POWER! strikes deal 1.35x and pierce 1 ward/clone",
		"skill_name": "Compass Strike",
		"skill_desc": "Clears freeze/ink/locks and fires a piercing Wit beam at Pirate"
	},
	{
		"id": "seeker",
		"name": "Treasure Seeker",
		"badge": "LOOT",
		"icon": "res://assets/images/ui/jelly-rpg/stance-seeker.webp",
		"accent": Color("#b57622"),
		"tint": Color("#fcf3dc"),
		"summary": "Fragment & coin snowball specialist",
		"passive": "+15% treasure fragments · 2x leftover fragment coins · Rank A+ coin bursts",
		"skill_name": "Lucky Shower",
		"skill_desc": "Attaches fragments to 3 tiles and adds +4.0s combo & stage grace"
	}
]

const STANCE_IDS: Array[String] = ["scholar", "hunter", "seeker"]

const RELICS: Array[Dictionary] = [
	{
		"id": "thaw_bell",
		"boss_id": 1,
		"stage": 3,
		"name": "Thaw Bell",
		"icon": "res://assets/images/ui/jelly-rpg/relic-thaw-bell.webp",
		"accent": Color("#3b8db8"),
		"levels": [
			"Freeze -35% · Dodge/thaw +1.5s combo",
			"Freeze -50% · Dodge/thaw +2.2s combo",
			"Freeze -65% · Dodge/thaw +3.0s combo & +3 charge"
		],
		"values": [
			{"freeze_scale": 0.65, "combo_restore": 1.5, "charge": 0},
			{"freeze_scale": 0.50, "combo_restore": 2.2, "charge": 0},
			{"freeze_scale": 0.35, "combo_restore": 3.0, "charge": 3}
		]
	},
	{
		"id": "clarity_lens",
		"boss_id": 2,
		"stage": 5,
		"name": "Clarity Lens",
		"icon": "res://assets/images/ui/jelly-rpg/relic-clarity-lens.webp",
		"accent": Color("#7c53a8"),
		"levels": [
			"Ink -40% · Clearing ink grants +4 Boss charge",
			"Ink -55% · Clearing ink grants +6 Boss charge",
			"Ink -70% · Clearing ink grants +8 Boss charge & +12% skill"
		],
		"values": [
			{"ink_scale": 0.60, "charge": 4, "skill_gain": 0},
			{"ink_scale": 0.45, "charge": 6, "skill_gain": 0},
			{"ink_scale": 0.30, "charge": 8, "skill_gain": 12}
		]
	},
	{
		"id": "master_key",
		"boss_id": 3,
		"stage": 7,
		"name": "Master Key",
		"icon": "res://assets/images/ui/jelly-rpg/relic-master-key.webp",
		"accent": Color("#c48a28"),
		"levels": [
			"1 match breaks up to 2 locks at once",
			"Breaks all locks and +5 Boss charge on unlock",
			"Breaks all locks immediately & +10% skill energy"
		],
		"values": [
			{"locks_broken": 2, "charge": 0, "skill_gain": 0, "auto_merge_through": false},
			{"locks_broken": 2, "charge": 5, "skill_gain": 0, "auto_merge_through": false},
			{"locks_broken": 2, "charge": 6, "skill_gain": 10, "auto_merge_through": true}
		]
	},
	{
		"id": "truth_prism",
		"boss_id": 4,
		"stage": 9,
		"name": "Truth Prism",
		"icon": "res://assets/images/ui/jelly-rpg/relic-truth-prism.webp",
		"accent": Color("#6d52b8"),
		"levels": [
			"Lv3+ hit disperses all clones & deals 30% bleed damage",
			"Lv3+ hit disperses all clones & deals 45% bleed damage",
			"Lv2+ hit disperses all clones & deals 60% bleed damage"
		],
		"values": [
			{"min_level": 3, "bleed": 0.30},
			{"min_level": 3, "bleed": 0.45},
			{"min_level": 2, "bleed": 0.60}
		]
	},
	{
		"id": "gale_feather",
		"boss_id": 5,
		"stage": 18,
		"name": "Gale Feather",
		"icon": "res://assets/images/ui/jelly-rpg/relic-gale-feather.webp",
		"accent": Color("#2d8f6e"),
		"levels": [
			"Broken sky -50% · Manual Next adds +2.0s combo",
			"Broken sky -65% · Manual Next adds +2.5s combo",
			"Broken sky -80% · Manual Next adds +3.0s combo & +6% skill"
		],
		"values": [
			{"broken_scale": 0.50, "next_combo": 2.0, "skill_gain": 0},
			{"broken_scale": 0.35, "next_combo": 2.5, "skill_gain": 0},
			{"broken_scale": 0.20, "next_combo": 3.0, "skill_gain": 6}
		]
	},
	{
		"id": "echo_clasp",
		"boss_id": 6,
		"stage": 36,
		"name": "Echo Clasp",
		"icon": "res://assets/images/ui/jelly-rpg/relic-echo-clasp.webp",
		"accent": Color("#1d839b"),
		"levels": [
			"Returned snatched jelly carries +1 fragment",
			"Returned snatched jelly carries +2 fragments",
			"Returned snatched jelly carries +2 fragments & +15% skill"
		],
		"values": [
			{"fragments": 1, "skill_gain": 0},
			{"fragments": 2, "skill_gain": 0},
			{"fragments": 2, "skill_gain": 15}
		]
	},
	{
		"id": "aegis_crest",
		"boss_id": 7,
		"stage": 63,
		"name": "Aegis Crest",
		"icon": "res://assets/images/ui/jelly-rpg/relic-aegis-crest.webp",
		"accent": Color("#c25a34"),
		"levels": [
			"POWER! strike breaks all wards & stuns Pirate 2.5s",
			"POWER! strike breaks all wards & stuns Pirate 3.5s",
			"POWER! strike breaks all wards, stuns 4.5s & +20% damage"
		],
		"values": [
			{"stun": 2.5, "power_bonus": 0.0},
			{"stun": 3.5, "power_bonus": 0.0},
			{"stun": 4.5, "power_bonus": 0.20}
		]
	},
	{
		"id": "word_compass",
		"boss_id": 8,
		"stage": 99,
		"name": "Word Compass",
		"icon": "res://assets/jelly-boss/compass.webp",
		"accent": Color("#c88e24"),
		"levels": [
			"Start with full Pip skill · +15% clear coins",
			"Start with full Pip skill · +22% clear coins & +10% Boss dmg",
			"Start with full Pip skill · +30% clear coins & +20% Boss dmg"
		],
		"values": [
			{"start_skill": 100, "clear_coin_bonus": 0.15, "boss_bonus": 0.0},
			{"start_skill": 100, "clear_coin_bonus": 0.22, "boss_bonus": 0.10},
			{"start_skill": 100, "clear_coin_bonus": 0.30, "boss_bonus": 0.20}
		]
	}
]

const MAX_RELIC_LEVEL: int = 3
const RELIC_UPGRADE_COINS: Array[int] = [0, 150, 350]
const RELIC_UPGRADE_TOKENS: Array[int] = [0, 1, 2]

# Boss ascension tiers (unlocked after first clear of that main Boss stage).
const BOSS_ASCENSIONS: Array[Dictionary] = [
	{"tier": 0, "name": "Normal", "badge": "★1", "hp_scale": 1.0, "interval_scale": 1.0,
		"extra_ward": 0, "extra_clones": 0, "token_reward": 1, "coin_bounty": 0},
	{"tier": 1, "name": "Elite", "badge": "★2 Elite", "hp_scale": 1.45, "interval_scale": 0.86,
		"extra_ward": 1, "extra_clones": 0, "token_reward": 2, "coin_bounty": 200},
	{"tier": 2, "name": "Legend", "badge": "★3 Legend", "hp_scale": 2.0, "interval_scale": 0.74,
		"extra_ward": 2, "extra_clones": 1, "token_reward": 3, "coin_bounty": 450}
]

# High-impact Roguelite Boons drafted every 5 stages in Survival Challenge (exaggerated power fantasy!).
const CHALLENGE_BOONS: Array[Dictionary] = [
	{
		"id": "supernova_blast",
		"name": "Supernova Blast",
		"tag": "BLAST",
		"icon": "res://assets/images/ui/jelly-rpg/boon-supernova.webp",
		"accent": Color("#d9534f"),
		"desc": "All collection blasts expand +2 power tiers (Lv1 fires like Lv3, Lv7+ clears whole board!)"
	},
	{
		"id": "overdrive_skill",
		"name": "Hyper Charge",
		"tag": "SKILL",
		"icon": "res://assets/images/ui/jelly-rpg/boon-hyper-charge.webp",
		"accent": Color("#6d4da6"),
		"desc": "Pip's Companion Skill charges 2.2x faster and instantly refills +50% right now!"
	},
	{
		"id": "chrono_flow",
		"name": "Chrono Flow",
		"tag": "TIME",
		"icon": "res://assets/images/ui/jelly-rpg/boon-chrono-flow.webp",
		"accent": Color("#2a8c76"),
		"desc": "+5.0s combo timer and +6 extra seconds refunded on every completed Challenge wave!"
	},
	{
		"id": "golden_cascade",
		"name": "Golden Cascade",
		"tag": "LOOT",
		"icon": "res://assets/images/ui/jelly-rpg/boon-golden-cascade.webp",
		"accent": Color("#c88e24"),
		"desc": "+60% treasure fragment chance and double combo coin payouts for the whole run!"
	},
	{
		"id": "giant_leap",
		"name": "Giant Leap",
		"tag": "MERGE",
		"icon": "res://assets/images/ui/jelly-rpg/boon-giant-leap.webp",
		"accent": Color("#2f7fb8"),
		"desc": "Every manual word merge immediately jumps +1 extra merge level (up to your cap)!"
	},
	{
		"id": "chain_echo",
		"name": "Chain Echo",
		"tag": "COMBO",
		"icon": "res://assets/images/ui/jelly-rpg/boon-chain-echo.webp",
		"accent": Color("#c45892"),
		"desc": "Every action gives +2 combo XP and +3 wrong-merge grace shields!"
	},
	{
		"id": "free_wand",
		"name": "Arcane Wand",
		"tag": "MAGIC",
		"icon": "res://assets/images/ui/jelly-rpg/boon-arcane-wand.webp",
		"accent": Color("#7c4ec4"),
		"desc": "Auto Merge capacity +4 and every Challenge wave clear auto-merges 2 free pairs!"
	},
	{
		"id": "treasure_frenzy",
		"name": "Treasure Frenzy",
		"tag": "COINS",
		"icon": "res://assets/images/ui/jelly-rpg/boon-treasure-frenzy.webp",
		"accent": Color("#d4871e"),
		"desc": "Every collected merged word adds +15 bonus coins and +30% chance of a free fragment!"
	},
	{
		"id": "lightning_hands",
		"name": "Lightning Hands",
		"tag": "SPEED",
		"icon": "res://assets/images/ui/jelly-rpg/boon-lightning-hands.webp",
		"accent": Color("#228b94"),
		"desc": "Every manual Next drop extends combo +4.0s and instantly grants +20% Pip Skill energy!"
	}
]

# Word Codex Synergy: 12 thematic adventures mapped to passive Jelly World RPG bonuses.
# Tiers unlock at 25% (1★), 60% (2★), and 100% (3★) mastered words in that theme.
const CODEX_SYNERGIES: Dictionary = {
	"animal-friends": {"stat": "skill_charge", "label": "Skill Charge", "tiers": [0.04, 0.09, 0.16], "fmt": "+%d%%"},
	"picnic-time": {"stat": "danger_bonus", "label": "Rescue Time", "tiers": [0.5, 1.0, 1.8], "fmt": "+%.1fs"},
	"great-outdoors": {"stat": "boss_damage", "label": "Boss Power", "tiers": [0.03, 0.07, 0.14], "fmt": "+%d%%"},
	"dress-up": {"stat": "coin_bonus", "label": "Clear Coins", "tiers": [0.03, 0.07, 0.14], "fmt": "+%d%%"},
	"on-the-move": {"stat": "combo_window", "label": "Combo Window", "tiers": [0.2, 0.5, 0.9], "fmt": "+%.1fs"},
	"play-time": {"stat": "skill_charge", "label": "Skill Charge", "tiers": [0.04, 0.09, 0.16], "fmt": "+%d%%"},
	"at-home": {"stat": "fragment_bonus", "label": "Treasure Odds", "tiers": [0.02, 0.05, 0.10], "fmt": "+%d%%"},
	"head-to-toe": {"stat": "boss_damage", "label": "Boss Power", "tiers": [0.03, 0.07, 0.14], "fmt": "+%d%%"},
	"ocean-discovery": {"stat": "fragment_bonus", "label": "Treasure Odds", "tiers": [0.03, 0.06, 0.12], "fmt": "+%d%%"},
	"space-trip": {"stat": "combo_window", "label": "Combo Window", "tiers": [0.25, 0.55, 1.0], "fmt": "+%.1fs"},
	"garden-trail": {"stat": "danger_bonus", "label": "Rescue Time", "tiers": [0.5, 1.0, 1.8], "fmt": "+%.1fs"},
	"music-makers": {"stat": "coin_bonus", "label": "Clear Coins", "tiers": [0.04, 0.08, 0.16], "fmt": "+%d%%"}
}


static func stance_by_id(id: String) -> Dictionary:
	for entry: Dictionary in STANCES:
		if str(entry.id) == id:
			return entry
	return STANCES[0]


static func relic_by_id(id: String) -> Dictionary:
	for entry: Dictionary in RELICS:
		if str(entry.id) == id:
			return entry
	return {}


static func relic_for_boss(boss_id: int) -> Dictionary:
	for entry: Dictionary in RELICS:
		if int(entry.boss_id) == boss_id:
			return entry
	return {}


static func relic_values(id: String, level: int) -> Dictionary:
	var relic: Dictionary = relic_by_id(id)
	if relic.is_empty() or level < 1:
		return {}
	var values: Array = relic.values
	return values[clampi(level - 1, 0, values.size() - 1)]


static func relic_upgrade_cost(current_level: int) -> Dictionary:
	if current_level < 1 or current_level >= MAX_RELIC_LEVEL:
		return {"coins": 0, "tokens": 0}
	return {"coins": RELIC_UPGRADE_COINS[current_level], "tokens": RELIC_UPGRADE_TOKENS[current_level]}


static func relic_slot_capacity(boss_victories_count: int, pip_level: int) -> int:
	var slots: int = 1
	if boss_victories_count >= 4 or pip_level >= 10:
		slots = 2
	if boss_victories_count >= 6 or pip_level >= 25:
		slots = 3
	return slots


static func ascension_by_tier(tier: int) -> Dictionary:
	return BOSS_ASCENSIONS[clampi(tier, 0, BOSS_ASCENSIONS.size() - 1)]


static func boon_by_id(id: String) -> Dictionary:
	for entry: Dictionary in CHALLENGE_BOONS:
		if str(entry.id) == id:
			return entry
	return {}


static func draft_challenge_boons(seed_value: int, wave_number: int, owned_boons: Array) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_value) ^ (wave_number * 0x9E3779B1)
	var pool: Array[Dictionary] = []
	for boon: Dictionary in CHALLENGE_BOONS:
		# Allow stacking after the pool runs low, but strongly prefer fresh boons first.
		if not owned_boons.has(str(boon.id)):
			pool.append(boon)
	if pool.size() < 3:
		pool.clear()
		for boon: Dictionary in CHALLENGE_BOONS:
			pool.append(boon)
	for index in range(pool.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var saved: Dictionary = pool[index]
		pool[index] = pool[other]
		pool[other] = saved
	var result: Array[Dictionary] = []
	for index in range(mini(3, pool.size())):
		result.append(pool[index].duplicate(true))
	return result


static func codex_summary(mastered_words: Dictionary) -> Dictionary:
	var themes: Array[Dictionary] = []
	var totals: Dictionary = {
		"skill_charge": 0.0,
		"danger_bonus": 0.0,
		"boss_damage": 0.0,
		"coin_bonus": 0.0,
		"combo_window": 0.0,
		"fragment_bonus": 0.0
	}
	var total_stars: int = 0
	for adventure: Dictionary in Data.ADVENTURES:
		var id: String = str(adventure.id)
		var words: Array = adventure.words
		var count: int = words.size()
		var mastered: int = 0
		for word_id: String in words:
			if mastered_words.has(word_id):
				mastered += 1
		var ratio: float = float(mastered) / float(maxi(1, count))
		var stars: int = 3 if ratio >= 1.0 - 0.0001 else 2 if ratio >= 0.60 else 1 if ratio >= 0.25 else 0
		total_stars += stars
		var spec: Dictionary = CODEX_SYNERGIES.get(id, {})
		var stat_key: String = str(spec.get("stat", ""))
		var value: float = float(spec.tiers[stars - 1]) if stars > 0 and spec.has("tiers") else 0.0
		if not stat_key.is_empty() and totals.has(stat_key):
			totals[stat_key] = float(totals[stat_key]) + value
		themes.append({
			"id": id,
			"name": str(adventure.name),
			"mastered": mastered,
			"total": count,
			"ratio": ratio,
			"stars": stars,
			"stat": stat_key,
			"label": str(spec.get("label", "")),
			"value": value
		})
	return {
		"themes": themes,
		"totals": totals,
		"stars": total_stars,
		"max_stars": Data.ADVENTURES.size() * 3
	}


static func compute_profile(pip_level: int, pip_age: int, upgrade_state: Dictionary,
		rpg_state: Dictionary, mastered_words: Dictionary = {}, boss_victories_count: int = 0,
		total_chapter_stars: int = 0) -> Dictionary:
	var clamped_level: int = clampi(pip_level, 0, 99)
	var clamped_age: int = clampi(pip_age, 0, 12)
	var jelly_lv: int = clampi(int(upgrade_state.get("level", 1)), 1, 9)
	var auto_lv: int = clampi(int(upgrade_state.get("auto_merge_level", 1)), 1, 9)
	var charm_lv: int = clampi(int(upgrade_state.get("star_charm_level", 1)), 1, 9)
	var prestige: int = clampi(int(upgrade_state.get("prestige_rank", 0)), 0, 50)
	var stance_id: String = str(rpg_state.get("stance", "scholar"))
	if stance_id not in STANCE_IDS:
		stance_id = "scholar"
	var equipped: Array = rpg_state.get("equipped_relics", [])
	var relic_levels: Dictionary = rpg_state.get("relic_levels", {})
	var codex: Dictionary = codex_summary(mastered_words)
	var codex_totals: Dictionary = codex.totals

	# 4 readable RPG stats (0..99+ scale for Pip's Character Sheet)
	var wit: int = 10 + clamped_level + mini(30, int(codex.stars))
	var spark: int = 10 + (jelly_lv - 1) * 9 + (auto_lv - 1) * 3 + prestige
	var tempo: int = 10 + (charm_lv - 1) * 9 + clamped_age * 2 + equipped.size() * 4
	var fortune: int = 10 + mini(40, floori(float(total_chapter_stars) / 5.0)) + equipped.size() * 6 + prestige

	var boss_damage_bonus: float = float(floori(float(clamped_level) / 10.0)) * 0.05 \
		+ float(codex_totals.boss_damage) + float(prestige) * 0.01
	var skill_charge_scale: float = 1.0 + float(clamped_age) * 0.04 + float(codex_totals.skill_charge)
	var clear_coin_bonus: float = float(codex_totals.coin_bonus) + float(prestige) * 0.01
	var fragment_bonus: float = float(codex_totals.fragment_bonus) + (0.15 if stance_id == "seeker" else 0.0)
	var combo_window_bonus: float = float(codex_totals.combo_window)
	var danger_bonus: float = float(codex_totals.danger_bonus)
	var start_skill_energy: int = 0

	var active_relics: Dictionary = {}
	for raw_id: Variant in equipped:
		var rid: String = str(raw_id)
		var rlv: int = clampi(int(relic_levels.get(rid, 0)), 0, MAX_RELIC_LEVEL)
		if rlv <= 0:
			continue
		var vals: Dictionary = relic_values(rid, rlv)
		active_relics[rid] = vals.duplicate(true)
		active_relics[rid]["level"] = rlv
		if rid == "word_compass":
			start_skill_energy = maxi(start_skill_energy, int(vals.get("start_skill", 100)))
			clear_coin_bonus += float(vals.get("clear_coin_bonus", 0.0))
			boss_damage_bonus += float(vals.get("boss_bonus", 0.0))

	return {
		"stance": stance_id,
		"stance_info": stance_by_id(stance_id),
		"stats": {"wit": wit, "spark": spark, "tempo": tempo, "fortune": fortune},
		"slot_capacity": relic_slot_capacity(boss_victories_count, clamped_level),
		"equipped_relics": equipped.duplicate(),
		"active_relics": active_relics,
		"boss_damage_bonus": boss_damage_bonus,
		"skill_charge_scale": skill_charge_scale,
		"clear_coin_bonus": clear_coin_bonus,
		"fragment_bonus": fragment_bonus,
		"combo_window_bonus": combo_window_bonus,
		"danger_bonus": danger_bonus,
		"start_skill_energy": start_skill_energy,
		"codex": codex,
		"prestige_rank": prestige
	}
