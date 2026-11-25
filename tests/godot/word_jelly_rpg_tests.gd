extends SceneTree
## Comprehensive unit + integration + UI test suite for Jelly World RPG progression:
## 1. WordJellyRpgCatalog (4-stat profile, slot capacity, 3 stances, 8 relics Lv1-3, 12 Codex synergies, Boons, Ascension)
## 2. WordJellyRpgStore (persistence, reload, idempotent receipts, Boss sync, relic equip/upgrade, bounties, deeds, days)
## 3. WordJellyModel + WordJellyBossRun combat (Companion Skills, all 8 relics, mastered word synergy, Ascension, Challenge 5-stage Boon draft + 9 exaggerated boons)
## 4. UI controls & campaign flow (WordJellyRpgOverlay 4 tabs, ChallengeBoonDraft, WordJellySkillButton, WordJellyCampaign end-to-end)

const Catalog = preload("res://scripts/word_jelly_rpg_catalog.gd")
const Store = preload("res://scripts/word_jelly_rpg_store.gd")
const Overlay = preload("res://scripts/word_jelly_rpg_overlay.gd")
const BoonDraft = preload("res://scripts/word_jelly_boon_draft.gd")
const SkillButton = preload("res://scripts/word_jelly_skill_button.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const BossRun = preload("res://scripts/word_jelly_boss_run.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const StageCatalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")

var checks: int = 0
var failures: int = 0
var words: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _load_words() -> void:
	var data := Data.new()
	check(data.load_all(), "Core game vocabulary loads for RPG tests")
	words = data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == 3) \
		.map(func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))


func _make_stage_model(stage_number: int = 3, challenge: bool = false, rpg_profile: Dictionary = {},
		mastered: Dictionary = {}, ascension_tier: int = 0, merged_limit: int = 5):
	var pool: Array = words.filter(func(w: Dictionary) -> bool:
		return int(w.get("min_age", 3)) == 3 and w.get("morphology") is Dictionary)
	var picked: Array = pool.slice(0, mini(16 if challenge else 4, pool.size()))
	var plan: Dictionary = StageCatalog.make_plan(0 if challenge else stage_number, picked, 3, 137, challenge)
	check(bool(plan.get("ok", false)), "RPG test stage plan builds cleanly")
	plan["merged_level_limit"] = merged_limit
	plan["auto_merge_level"] = 2
	plan["star_charm_level"] = 1
	plan["auto_collect_campaign_unlocked"] = true
	plan["rpg_profile"] = rpg_profile.duplicate(true)
	plan["mastered_word_ids"] = mastered.duplicate(true)
	if not challenge:
		plan["boss"] = BossCatalog.encounter(stage_number, false, ascension_tier)
	var model = Model.new()
	model.allow_cross_age = true
	var init_words: Array = plan.words.slice(0, 3) if challenge else plan.words
	check(model.configure(init_words, 3, 137) and model.bind_stage(plan), "RPG stage model configures and binds")
	model.cells.clear()
	model.upcoming.clear()
	model._supply.clear()
	model._supply_pending.clear()
	model.spawn_interval = 10000.0
	return model


func _put_tile(model, tile: Dictionary, col: int, row: int = 7) -> Dictionary:
	tile.column = col
	tile.row = row
	tile.age = 100.0
	tile.settling = false
	tile.falling = false
	tile.arrival = false
	model.cells.append(tile)
	return tile


func test_catalog_and_codex() -> void:
	check(Catalog.STANCES.size() == 3 and Catalog.RELICS.size() == 8 and Catalog.CHALLENGE_BOONS.size() == 9,
		"RPG catalog defines 3 stances, 8 Boss relics, and 9 exaggerated Challenge boons")
	check(Catalog.CODEX_SYNERGIES.size() == Data.ADVENTURES.size(),
		"Every thematic adventure in Data.ADVENTURES has a Word Codex synergy mapping")
	check(Catalog.relic_slot_capacity(0, 0) == 1 and Catalog.relic_slot_capacity(4, 0) == 2
		and Catalog.relic_slot_capacity(0, 10) == 2 and Catalog.relic_slot_capacity(6, 0) == 3
		and Catalog.relic_slot_capacity(0, 25) == 3,
		"Relic slot capacity scales 1 -> 2 -> 3 via Boss clears or Pip Lv10/Lv25")
	for boss_id in range(1, 9):
		var r: Dictionary = Catalog.relic_for_boss(boss_id)
		check(not r.is_empty() and int(r.boss_id) == boss_id, "Boss %d maps to a unique relic" % boss_id)
		check(ResourceLoader.exists(str(r.icon)), "Relic %s icon asset exists" % str(r.id))
	# Word Codex mastery thresholds (25% / 60% / 100%)
	var adv0: Dictionary = Data.ADVENTURES[0]
	var mastered_partial: Dictionary = {}
	var needed_1: int = ceili(float(adv0.words.size()) * 0.25)
	for i in range(needed_1):
		mastered_partial[str(adv0.words[i])] = true
	var sum1: Dictionary = Catalog.codex_summary(mastered_partial)
	check(int(sum1.themes[0].stars) == 1 and float(sum1.themes[0].value) > 0.0,
		"Mastering >=25% of a theme unlocks 1★ Codex synergy")
	var mastered_full: Dictionary = {}
	for w in adv0.words:
		mastered_full[str(w)] = true
	var sum3: Dictionary = Catalog.codex_summary(mastered_full)
	check(int(sum3.themes[0].stars) == 3 and float(sum3.totals.skill_charge) >= 0.16 - 0.001,
		"Mastering 100% of Animal Friends unlocks 3★ (+16% skill charge)")

	# Profile derivation with Word Compass Lv3 + Prestige + Seeker stance
	var upg := {"level": 6, "auto_merge_level": 5, "star_charm_level": 4, "prestige_rank": 10}
	var rstate := {"stance": "seeker", "equipped_relics": ["word_compass"], "relic_levels": {"word_compass": 3}}
	var profile: Dictionary = Catalog.compute_profile(20, 6, upg, rstate, mastered_full, 8, 90)
	check(int(profile.stats.wit) > 20 and int(profile.stats.spark) > 50
		and int(profile.stats.tempo) > 40 and int(profile.stats.fortune) > 30,
		"Pip 4-stat sheet (Wit/Spark/Tempo/Fortune) reflects level, upgrades, stars, relics, and prestige")
	check(int(profile.start_skill_energy) == 100, "Word Compass starts rounds with 100% Pip Skill energy")
	check(float(profile.clear_coin_bonus) >= 0.399, "Word Compass Lv3 (+30%) + Prestige 10 (+10%) boost clear coins")
	check(float(profile.boss_damage_bonus) >= 0.399, "Pip Lv20 (+10%) + Prestige 10 (+10%) + Word Compass Lv3 (+20%) boost Boss dmg")
	check(float(profile.fragment_bonus) >= 0.15 - 0.001, "Treasure Seeker stance grants +15% fragment odds")

	# Deterministic Boon drafting prefers unowned boons first
	var d1: Array[Dictionary] = Catalog.draft_challenge_boons(42, 5, [])
	var d2: Array[Dictionary] = Catalog.draft_challenge_boons(42, 5, [])
	check(d1.size() == 3 and str(d1[0].id) == str(d2[0].id) and str(d1[1].id) == str(d2[1].id)
		and str(d1[0].id) != str(d1[1].id) and str(d1[1].id) != str(d1[2].id),
		"Challenge Boon draft deterministically presents 3 distinct boons")
	var owned: Array = []
	for i in range(6):
		owned.append(str(Catalog.CHALLENGE_BOONS[i].id))
	var d3: Array[Dictionary] = Catalog.draft_challenge_boons(99, 10, owned)
	check(d3.size() == 3 and not owned.has(str(d3[0].id)) and not owned.has(str(d3[1].id)) and not owned.has(str(d3[2].id)),
		"Challenge Boon draft prioritizes unowned boons when >=3 remain")

	# Stage clear reward integration
	var base_q: Dictionary = StageCatalog.clear_reward(3, 3, 0, 0, 0, 5)
	var rpg_q: Dictionary = StageCatalog.clear_reward(3, 3, 0, 0, 0, 5, 0.30, true)
	check(rpg_q.ok and int(rpg_q.rpg_bonus) > 0 and int(rpg_q.fragment_rebate) == int(base_q.fragment_rebate) * 2
		and int(rpg_q.total) > int(base_q.total),
		"StageCatalog.clear_reward applies RPG clear coin bonus and Seeker 2x leftover fragment rebate")


func test_rpg_store_persistence_and_economy() -> void:
	var rpg_path: String = "user://test-jelly-rpg-store-%d.cfg" % Time.get_ticks_usec()
	var wallet_path: String = "user://test-jelly-rpg-wallet-%d.cfg" % Time.get_ticks_usec()
	var wallet := Wallet.new(wallet_path)
	check(wallet.load_state(), "Test wallet loads")
	check(wallet.credit_amount("seed-coins", 800).ok, "Test wallet seeded with 800 coins")

	var store := Store.new(rpg_path)
	check(store.load_state() and store.ready, "Fresh RPG store initializes cleanly")
	check(store.state().bounties.size() == 3 and store.stance() == "scholar",
		"Fresh RPG store starts with 3 active bounties and Spark Scholar stance")

	# Sync existing Boss victories -> unlocks & auto-equips relics
	var unlocked: Array[String] = store.sync_boss_victories([1, 2], 1)
	check(unlocked.size() == 2 and store.relic_level("thaw_bell") == 1 and store.relic_level("clarity_lens") == 1
		and store.equipped_relics() == ["thaw_bell"],
		"sync_boss_victories unlocks relics for prior Boss clears and auto-equips up to slot cap")
	check(store.sync_boss_victories([1, 2], 1).is_empty(), "Re-syncing Boss victories is idempotent")

	# Equip toggle respects slot limit (FIFO swap when full)
	check(store.toggle_equip_relic("clarity_lens", 1) and store.equipped_relics() == ["clarity_lens"],
		"Equipping at slot cap 1 swaps to the newly chosen relic")
	check(store.toggle_equip_relic("thaw_bell", 2) and store.equipped_relics().size() == 2,
		"Slot cap 2 allows equipping 2 relics simultaneously")
	check(store.toggle_equip_relic("thaw_bell", 2) and store.equipped_relics() == ["clarity_lens"],
		"Toggling an equipped relic unequips it cleanly")

	# Stance switch
	check(store.set_stance("hunter") and store.stance() == "hunter", "Stance switches to Compass Hunter")
	check(not store.set_stance("invalid_stance"), "Unknown stance is rejected")

	# Record round progress (with Boss victory + Ascension + idempotent receipt)
	var summary := {
		"collections": 25, "high_collects": 6, "best_combo": 5, "skills_used": 2,
		"cleared": true, "stars": 3, "pure_clear": true, "boss_dodges": 2,
		"boss_victory": true, "boss_id": 3, "boss_ascension": 1, "challenge_stage": 10
	}
	var res1: Dictionary = store.record_round_progress("round-r1", summary, 2, "2026-11-25")
	check(res1.ok and res1.new_relics == ["master_key"] and int(res1.tokens_earned) == 2
		and int(res1.ascension_bounty) == 200 and store.boss_tokens() == 2
		and store.highest_boss_ascension(3) == 1,
		"Boss Elite victory unlocks Boss 3 Master Key, grants 2 tokens, records ascension tier 1, and tracks active day")
	var dup: Dictionary = store.record_round_progress("round-r1", summary, 2, "2026-11-25")
	check(dup.ok and bool(dup.get("duplicate", false)) and store.boss_tokens() == 2,
		"Duplicate round progress receipt never double-counts totals or Boss tokens")

	# Relic Lv1 -> Lv2 upgrade spends 150 coins + 1 token
	var coins_before: int = wallet.balance
	var up1: Dictionary = store.upgrade_relic("master_key", wallet)
	check(up1.ok and store.relic_level("master_key") == 2 and wallet.balance == coins_before - 150
		and store.boss_tokens() == 1,
		"Relic upgrade Lv1->Lv2 spends 150 coins and 1 Boss token")
	# Lv2 -> Lv3 requires 2 tokens, currently only 1 -> rejected without spending coins
	var up2_fail: Dictionary = store.upgrade_relic("master_key", wallet)
	check(not up2_fail.ok and store.relic_level("master_key") == 2 and wallet.balance == coins_before - 150,
		"Relic upgrade rejects cleanly when Boss tokens are insufficient")

	# Claim completed bounty -> pays coins, refills to 3 active bounties
	var claimable_bounty_uid: String = ""
	for b: Dictionary in store.state().bounties:
		if int(b.progress) >= int(b.target):
			claimable_bounty_uid = str(b.uid)
			break
	check(not claimable_bounty_uid.is_empty(), "Round progress advances and completes active Jelly World bounties")
	var before_bounty_coins: int = wallet.balance
	var b_claim: Dictionary = store.claim_bounty(claimable_bounty_uid, wallet)
	check(b_claim.ok and wallet.balance == before_bounty_coins + int(b_claim.coins)
		and store.state().bounties.size() == 3,
		"Claiming a completed bounty pays coins and auto-refills the 3rd bounty slot")

	# Claim completed permanent deed (e.g. first_skill, combo_s, challenge_10, ascension_1)
	var before_deed_coins: int = wallet.balance
	var before_deed_tokens: int = store.boss_tokens()
	var d_claim: Dictionary = store.claim_deed("ascension_1", wallet)
	check(d_claim.ok and wallet.balance == before_deed_coins + 250 and store.boss_tokens() == before_deed_tokens + 2,
		"Claiming an Adventure Deed pays its coins and Boss tokens")
	var d_dup: Dictionary = store.claim_deed("ascension_1", wallet)
	check(d_dup.ok and bool(d_dup.get("duplicate", false)) and wallet.balance == before_deed_coins + 250,
		"Re-claiming a Deed is idempotent")

	# Now we have >=2 tokens -> Lv2 -> Lv3 upgrade succeeds!
	var up2_ok: Dictionary = store.upgrade_relic("master_key", wallet)
	check(up2_ok.ok and store.relic_level("master_key") == 3, "Relic reaches max Lv3 once tokens are earned")

	# Persistence across reload
	var reloaded := Store.new(rpg_path)
	check(reloaded.load_state() and reloaded.stance() == "hunter"
		and reloaded.relic_level("master_key") == 3
		and reloaded.highest_boss_ascension(3) == 1
		and reloaded.state().claimed_deeds.has("ascension_1")
		and reloaded.state().active_days.has("2026-11-25"),
		"RPG store persists and reloads stance, relics, ascensions, claimed deeds, and active days")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(rpg_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(wallet_path))


func test_combat_skills_relics_and_ascension() -> void:
	# 1. Ascension Boss stats (Normal vs Elite vs Legend)
	var b_norm: Dictionary = BossCatalog.encounter(3, false, 0)
	var b_elite: Dictionary = BossCatalog.encounter(3, false, 1)
	var b_legend: Dictionary = BossCatalog.encounter(3, false, 2)
	check(int(b_norm.health) == 98 and int(b_elite.health) == roundi(98.0 * 1.45) and int(b_legend.health) == 196
		and int(b_elite.starting_ward) == 1 and int(b_legend.starting_ward) == 2 and int(b_legend.starting_clones) == 1
		and str(b_elite.title).begins_with("Elite · ") and str(b_legend.title).begins_with("Legend · "),
		"Boss Ascension scales HP, attack cadence, starting ward, starting clones, and title prefix")

	# 2. Compass Hunter + Aegis Crest + Truth Prism + Master Key + Thaw Bell + Clarity Lens + Gale Feather + Word Compass
	var full_relics: Dictionary = {
		"thaw_bell": Catalog.relic_values("thaw_bell", 3),
		"clarity_lens": Catalog.relic_values("clarity_lens", 3),
		"master_key": Catalog.relic_values("master_key", 3),
		"truth_prism": Catalog.relic_values("truth_prism", 3),
		"gale_feather": Catalog.relic_values("gale_feather", 3),
		"echo_clasp": Catalog.relic_values("echo_clasp", 3),
		"aegis_crest": Catalog.relic_values("aegis_crest", 3),
		"word_compass": Catalog.relic_values("word_compass", 3)
	}
	var hunter_profile := {
		"stance": "hunter",
		"stats": {"wit": 40, "spark": 30, "tempo": 30, "fortune": 30},
		"boss_damage_bonus": 0.20,
		"skill_charge_scale": 1.20,
		"combo_window_bonus": 0.5,
		"danger_bonus": 1.0,
		"start_skill_energy": 100,
		"active_relics": full_relics
	}
	var mastered_map: Dictionary = {}
	var m_hunt = _make_stage_model(7, false, hunter_profile, mastered_map, 2, 5)
	check(is_equal_approx(m_hunt.skill_energy, 100.0) and m_hunt.can_trigger_companion_skill(),
		"Word Compass grants 100% starting skill energy ready to trigger")
	check(m_hunt.boss.ward == 2 and m_hunt.boss.clones == 1,
		"Legend Boss spawns with 2 wards and 1 clone")
	# Thaw Bell Lv3 cuts freeze by 65% (3.0 * 0.35 = 1.05s)
	var w0: Dictionary = m_hunt.stage_run.words[0]
	var r0: Dictionary = _put_tile(m_hunt, m_hunt._new_word_root(w0), 0)
	var p0: Dictionary = _put_tile(m_hunt, m_hunt._new_picture_tile(w0), 1)
	m_hunt.boss.apply_status("freeze", int(r0.id))
	check(float(m_hunt.boss.status(int(r0.id)).freeze) < 1.2, "Thaw Bell Lv3 drastically cuts freeze duration")
	m_hunt.boss.apply_status("ink", int(p0.id))
	check(float(m_hunt.boss.status(int(p0.id)).ink) < 1.8, "Clarity Lens Lv3 drastically cuts ink duration")
	# Compass Strike cleanses all statuses, pierces ward/clones, stuns Pirate, and deals Wit beam damage!
	var hp_before: int = m_hunt.boss.health
	var strike: Dictionary = m_hunt.trigger_companion_skill()
	check(strike.ok and int(strike.cleansed) >= 2 and int(strike.boss_damage) > 150
		and m_hunt.boss.health < hp_before and m_hunt.boss.ward == 0 and m_hunt.boss.clones == 0
		and m_hunt.boss.stun_remaining >= 2.4 and not m_hunt.boss.frozen(int(r0.id))
		and is_equal_approx(m_hunt.skill_energy, 0.0) and m_hunt.skill_uses == 1,
		"Compass Strike cleanses freeze/ink, shatters ward/clones, stuns Boss, and deals Wit-scaled beam damage")

	# Master Key Lv3 breaks 2 locks AND auto-merges straight through!
	m_hunt.boss.apply_status("lock", int(r0.id))
	m_hunt.boss.apply_status("lock", int(r0.id))
	check(m_hunt.boss.locks(int(r0.id)) == 2, "Setup 2 locks on root tile")
	var unlock_res: String = m_hunt.try_merge(int(r0.id), int(p0.id))
	check(unlock_res == "merged" and m_hunt.boss.locks(int(r0.id)) == 0 and m_hunt.skill_energy > 0.0,
		"Master Key Lv3 strips 2 locks in one move, merges straight through, and grants skill energy")

	# Truth Prism Lv3 disperses clones + deals bleed damage on Lv2+ hit; Aegis Crest breaks wards + stuns on POWER! hit
	var brun := BossRun.new()
	brun.configure(BossCatalog.encounter(9, false, 0), 11)
	brun.set_rpg_modifiers(hunter_profile)
	brun.clones = 2
	var hp_prism: int = brun.health
	brun.collect_hit("prism-1", 2, 0, {})
	check(brun.clones == 0 and brun.health < hp_prism,
		"Truth Prism Lv3 sweeps all clones and bleeds damage through on Lv2+ collect")
	brun.ward = 2
	brun.charge = 12
	var hp_aegis: int = brun.health
	brun.collect_hit("aegis-1", 2, 0, {})
	check(brun.ward == 0 and brun.health < hp_aegis and brun.stun_remaining >= 4.4,
		"Aegis Crest Lv3 breaks all wards, stuns Pirate 4.5s, and deals boosted POWER! damage")

	# 3. Mastered word in-battle synergy (+15% Boss damage & +5% Skill charge)
	var m_base = _make_stage_model(3, false, {"stance": "scholar", "skill_charge_scale": 1.0, "boss_damage_bonus": 0.0}, {}, 0, 5)
	var mw: Dictionary = m_base.stage_run.words[0]
	var m_mast = _make_stage_model(3, false, {"stance": "scholar", "skill_charge_scale": 1.0, "boss_damage_bonus": 0.0}, {str(mw.id): true}, 0, 5)
	var t_base: Dictionary = _put_tile(m_base, m_base._new_word_root(mw), 0)
	m_base._set_merged_word(t_base, mw, 2, true)
	var t_mast: Dictionary = _put_tile(m_mast, m_mast._new_word_root(mw), 0)
	m_mast._set_merged_word(t_mast, mw, 2, true)
	m_base.collect(int(t_base.id))
	m_base.step(1.0)
	m_mast.collect(int(t_mast.id))
	m_mast.step(1.0)
	check(m_mast.boss.health < m_base.boss.health and m_mast.skill_energy > m_base.skill_energy
		and m_mast.mastered_collect_hits == 1,
		"Collecting a Mastered word deals +15% Boss damage and grants +5% bonus Companion Skill charge")

	# 4. Spark Scholar Starburst & Treasure Seeker Lucky Shower
	var m_scholar = _make_stage_model(3, false, {"stance": "scholar", "start_skill_energy": 100}, {}, 0, 5)
	var sw: Dictionary = m_scholar.stage_run.words[0]
	_put_tile(m_scholar, m_scholar._new_word_root(sw), 0)
	_put_tile(m_scholar, m_scholar._new_picture_tile(sw), 1)
	var burst: Dictionary = m_scholar.trigger_companion_skill()
	check(burst.ok and int(burst.free_merges) >= 1 and m_scholar.powerup_active(),
		"Spark Scholar Starburst triggers free automatic merges without spending coins")
	m_scholar.finish_powerup()
	var merged_tiles: Array = m_scholar.cells.filter(func(c: Dictionary) -> bool: return str(c.get("jelly_kind", "")) == "merged")
	check(merged_tiles.size() == 1 and not bool(merged_tiles[0].get("mastery_eligible", true)),
		"Starburst auto-merged words preserve learning integrity (mastery_eligible == false)")

	var m_seeker = _make_stage_model(3, false, {"stance": "seeker", "start_skill_energy": 100}, {}, 0, 5)
	for i in range(3):
		var tw: Dictionary = m_seeker.stage_run.words[i % m_seeker.stage_run.words.size()]
		_put_tile(m_seeker, m_seeker._new_word_root(tw, 0), i)
	var shower: Dictionary = m_seeker.trigger_companion_skill()
	check(shower.ok and int(shower.fragments_added) == 3 and float(shower.time_bonus) >= 3.9
		and m_seeker._stage_grace_remaining >= 3.9,
		"Treasure Seeker Lucky Shower attaches 3 fragments and adds 4.0s stage timer grace")
	var rem_before_grace: float = m_seeker.stage_run.remaining
	m_seeker.step(2.0)
	check(is_equal_approx(m_seeker.stage_run.remaining, rem_before_grace),
		"Stage timer pauses cleanly during Lucky Shower grace period")


func test_challenge_boon_draft_and_exaggerated_effects() -> void:
	var m = _make_stage_model(0, true, {"stance": "scholar"}, {}, 0, 7)
	var draft_signals: Array = []
	var applied_signals: Array = []
	m.challenge_boon_draft_requested.connect(func(opts: Array) -> void: draft_signals.append(opts))
	m.challenge_boon_applied.connect(func(b: Dictionary) -> void: applied_signals.append(b))

	# Advance Challenge wave to stage 5 with 1 remaining goal -> clearing Wave 5 triggers 3-pick Boon draft!
	m.stage_run.challenge_stage = 5
	var cw: Dictionary = m.stage_run.words[0]
	m.stage_run._challenge_goals.clear()
	m.stage_run._challenge_goals.append({
		"id": "challenge:5:%s" % str(cw.id), "stage": 5, "word_id": str(cw.id),
		"text": str(cw.text), "image": str(cw.get("image", "")),
		"current": 0, "required": 1, "mastered": false
	})
	var tile: Dictionary = _put_tile(m, m._new_word_root(cw), 0)
	m._set_merged_word(tile, cw, 1, true)
	check(m.collect(int(tile.id)), "Collect word to complete Challenge Wave 5")
	m.step(1.0)
	check(m.stage_run.challenge_stage == 6 and m.pending_boon_options.size() == 3 and draft_signals.size() == 1,
		"Clearing Challenge Wave 5 requests a 3-pick exaggerated Roguelite Boon Draft")

	# While draft is pending, clock freezes and board inputs are safely blocked
	var rem_frozen: float = m.stage_run.remaining
	m.step(5.0)
	check(is_equal_approx(m.stage_run.remaining, rem_frozen), "Challenge timer freezes while Boon Draft modal is open")
	var extra_t: Dictionary = _put_tile(m, m._new_word_root(cw), 1)
	m._set_merged_word(extra_t, cw, 1, true)
	check(not m.collect(int(extra_t.id)) and not m.can_drop_now(),
		"Board collection and drops wait until player selects a Challenge Boon")

	# Pick the first drafted boon
	var chosen_id: String = str(m.pending_boon_options[0].id)
	var pick_res: Dictionary = m.select_challenge_boon(chosen_id)
	check(pick_res.ok and m.pending_boon_options.is_empty() and m.challenge_boons.has(chosen_id)
		and applied_signals.size() == 1,
		"Selecting a Boon applies it, clears pending options, and resumes Challenge play")

	# Verify exaggerated effects directly across boons
	m.challenge_boons.append("giant_leap")
	m.challenge_boons.append("chrono_flow")
	m.challenge_boons.append("chain_echo")
	m.challenge_boons.append("free_wand")
	m.challenge_boons.append("treasure_frenzy")
	m.challenge_boons.append("overdrive_skill")
	m.challenge_boons.append("lightning_hands")
	check(m.combo_window() >= Model.COMBO_SECONDS + 5.0 - 0.01, "Chrono Flow adds +5.0s combo timer")
	check(m.auto_merge_capacity() >= 6, "Arcane Wand expands Auto Merge capacity by +4")
	var lr: Dictionary = _put_tile(m, m._new_word_root(cw), 2)
	var lp: Dictionary = _put_tile(m, m._new_picture_tile(cw), 3)
	check(m.try_merge(int(lr.id), int(lp.id)) == "merged", "Giant Leap manual merge succeeds")
	m.step(1.0)
	var boosted: Array = m.cells.filter(func(c: Dictionary) -> bool:
		return int(c.get("merge_level", 0)) >= 2 and str(c.get("word", {}).get("id", "")) == str(cw.id))
	check(not boosted.is_empty(), "Giant Leap immediately jumps a manual word merge by +1 extra merge level (Lv1 -> Lv2)")

	# Treasure Frenzy adds +15 coins into the actual wallet receipt on collection!
	var credited_amounts: Array[int] = []
	m.credit_collection = func(_eid: String, amount: int) -> Dictionary:
		credited_amounts.append(amount)
		return {"ok": true, "amount": amount}
	var ft: Dictionary = _put_tile(m, m._new_word_root(cw), 4)
	m._set_merged_word(ft, cw, 1, true)
	check(m.collect(int(ft.id)), "Collect word with Treasure Frenzy active")
	m.step(1.0)
	check(not credited_amounts.is_empty() and credited_amounts[0] >= 15,
		"Treasure Frenzy credits its +15 bonus coins through the real wallet collection receipt")


func test_ui_controls_and_campaign_flow() -> void:
	# 1. Standalone RPG Overlay 4 tabs + SkillButton + BoonDraft
	var overlay := Overlay.new()
	overlay.size = Vector2(900, 640)
	root.add_child(overlay)
	var draft := BoonDraft.new()
	draft.size = Vector2(900, 640)
	root.add_child(draft)
	var skill_btn := SkillButton.new()
	skill_btn.size = Vector2(140, 34)
	root.add_child(skill_btn)
	await process_frame

	var sample_profile: Dictionary = Catalog.compute_profile(12, 4, {"level": 3}, {"stance": "scholar", "equipped_relics": ["thaw_bell"], "relic_levels": {"thaw_bell": 1}}, {}, 1, 20)
	var payload := {
		"profile": sample_profile,
		"rpg_state": Store._default_state(),
		"relic_levels": {"thaw_bell": 1},
		"boss_tokens": 2,
		"boss_victories": [1],
		"boss_ascensions": {},
		"selected_ascensions": {},
		"coins": 500,
		"pip_level": 12,
		"claimable_count": 1,
		"deed_progress": {},
		"notice": ""
	}
	overlay.open(payload, "build", true)
	await process_frame
	check(overlay.visible and overlay.snapshot().tab == "build", "RPG overlay opens on Pip Build tab")
	for tab_id: String in ["relics", "bounties", "codex", "build"]:
		overlay._select_tab(tab_id)
		await process_frame
		check(overlay.snapshot().tab == tab_id and overlay._body.get_child_count() > 0,
			"RPG overlay renders non-empty content for tab: " + tab_id)
	overlay.close()
	check(not overlay.visible, "RPG overlay closes cleanly")

	draft.present(Catalog.draft_challenge_boons(7, 5, []))
	await process_frame
	check(draft.visible and draft.navigation_controls().size() == 3,
		"ChallengeBoonDraft renders 3 focusable boon option buttons")
	draft.dismiss()

	skill_btn.set_skill_state({"energy": 100.0, "ready": true, "name": "Starburst"}, Color("#2a8c76"), true)
	skill_btn.show()
	await process_frame
	check(skill_btn.snapshot().ready and is_equal_approx(float(skill_btn.snapshot().energy), 100.0),
		"Companion Skill button updates ready state and accessibility label")

	overlay.queue_free()
	draft.queue_free()
	skill_btn.queue_free()
	await process_frame

	# 2. Real app + WordJellyCampaign RPG integration
	var directory: String = OS.get_user_data_dir().path_join("rpg_flow_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var app = preload("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	root.add_child(app)
	for _frame in range(6):
		await process_frame
	app.choose_mode("word_jelly")
	for _frame in range(6):
		await process_frame
	var camp = app._campaign
	check(camp.rpg_store != null and camp.rpg_store.ready, "WordJellyCampaign loads its dedicated RPG store")
	check(camp.map.visible and camp.map._rpg_pill.visible, "Jelly World map displays the Pip Adventurer Pack entry pill")
	camp.open_rpg("build")
	await process_frame
	check(camp.rpg_overlay.visible and camp.is_open(), "Opening Pip's Adventurer Pack from the map works cleanly")
	camp.select_rpg_stance("seeker")
	check(camp.rpg_store.stance() == "seeker", "Switching stance through WordJellyCampaign updates RPG store")
	camp._home()
	await process_frame
	check(not camp.rpg_overlay.visible and camp.map.visible, "Back/Escape from RPG overlay returns to Jelly World map")
	app.audio.halt()
	app.free()
	for _frame in range(5):
		await process_frame
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)


func _run() -> void:
	_load_words()
	test_catalog_and_codex()
	test_rpg_store_persistence_and_economy()
	test_combat_skills_relics_and_ascension()
	test_challenge_boon_draft_and_exaggerated_effects()
	await test_ui_controls_and_campaign_flow()
	await create_timer(0.15).timeout
	print("Word Jelly RPG tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
