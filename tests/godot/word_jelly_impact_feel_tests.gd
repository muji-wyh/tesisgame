extends SceneTree
## Verification suite for Jelly World tactile impact feel (Merge & Boss Combat):
## 1. Merge three-beat snap, shader impact_flash, beads/pop FX, and board ripple wave without moving tile hit rects
## 2. Directional well impulse on merge, upgrade, wrong bump, and Boss strikes
## 3. Boss 3D hit-flash, squash recoil, trailing health ghost, ward shatter, clone poof, stun stars, Compass Strike beam, finisher flash
## 4. Layered impact audio cues (upgrade pitch escalation, boss-hit sub-thud, boss-ward-break, contact_match)
## 5. Strict reduced_motion suppression across merge flash, ripples, Boss flash, and recoil

const Jelly = preload("res://scripts/word_jelly.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const BossView = preload("res://scripts/word_jelly_boss_view.gd")
const BossRun = preload("res://scripts/word_jelly_boss_run.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const Audio = preload("res://scripts/game_audio.gd")
const Backdrop = preload("res://scripts/jelly_backdrop.gd")
const Data = preload("res://scripts/game_data.gd")

var checks: int = 0
var failures: int = 0
var data := Data.new()
var words: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _prepare_words() -> void:
	check(data.load_all(), "Core data loads for impact feel tests")
	var cat: Dictionary = {}
	for word: Dictionary in data.words:
		if str(word.id) == "cat":
			cat = word.duplicate(true)
			break
	check(not cat.is_empty(), "cat word is present")
	words = [cat]


func _advance_view(view: Jelly, seconds: float) -> void:
	var rem: float = seconds
	while rem > 0.000001:
		var dt: float = minf(0.025, rem)
		view._process(dt)
		rem -= dt


func test_merge_impact_and_board_ripple() -> void:
	var view := Jelly.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(1000, 720)
	var cues: Array[String] = []
	view.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	check(view.configure(words, 3, Data.theme("spring"), data.chests, false, 42), "Word Jelly configures for impact test")
	view.game.spawn_interval = 10000.0
	view.game.cells.clear()
	var cat: Dictionary = words[0]
	var a: Dictionary = view.game._new_word_root(cat)
	view.game._set_merged_word(a, cat, 2, true)
	a.column = 2
	a.row = 7
	a.age = 100.0
	a.settling = false
	var b: Dictionary = view.game._new_word_root(cat)
	view.game._set_merged_word(b, cat, 2, true)
	b.column = 3
	b.row = 7
	b.age = 100.0
	b.settling = false
	var neighbor: Dictionary = view.game._new_word_root(cat)
	neighbor.column = 4
	neighbor.row = 7
	neighbor.age = 100.0
	neighbor.settling = false
	view.game.cells.append_array([a, b, neighbor])
	view._sync_tiles()
	view._layout()
	var neighbor_rect: Rect2 = view._tiles[int(neighbor.id)].get_rect()

	# Drag A onto B for an Lv2+Lv2 -> Lv4 upgrade merge
	var p_a: Vector2 = view._tiles[int(a.id)].get_global_rect().get_center()
	var p_b: Vector2 = view._tiles[int(b.id)].get_global_rect().get_center()
	check(view._press(-1, p_a), "Pointer picks up tile A")
	view._move(p_b)
	view._process(0.02)
	check(cues.has("contact_match"), "Dragging onto a valid match emits magnetic contact_match audio cue")
	view._release(p_b)
	check(view.game.fusions.size() == 1 and cues.any(func(c: String) -> bool: return c.begins_with("merge-upgrade:")),
		"Upgrade merge emits pitched merge-upgrade audio accent")

	# Advance right into the p=0.22 Nintendo impact + hit-stop window (165ms from release)!
	_advance_view(view, Model.FUSION_SECONDS * 0.24)
	var visual: Dictionary = view._fusion_visuals.values()[0]
	var flash_u: float = float(visual.art._gel.get_shader_parameter("impact_flash"))
	check(flash_u >= 0.9, "Merge hit-stop locks near-pure white shader impact_flash (got=%.3f)" % flash_u)
	check(cues.any(func(c: String) -> bool: return c.begins_with("merge-impact:upgrade:4:")),
		"Merge collision emits 0ms A/V-locked merge-impact cue right at MERGE_IMPACT_P")
	var fx_snap: Dictionary = view._collection_effects.snapshot()
	check(int(fx_snap.get("merge_pop_count", 0)) >= 1 and int(fx_snap.get("splatter_count", 0)) >= 1,
		"Upgrade merge spawns Merge Pop shockwave/Lv4! badge plus glossy jelly splatter droplets")
	check(view._well_impulse_strength > 0.55 and not view._board_ripples.is_empty(),
		"Merge snap fires single-dip board cushion thud and neighborhood ripple")
	check(not view._board_recoil_offset.is_zero_approx() and view._settled_body_layer.position.is_equal_approx(view._board_recoil_offset),
		"Board micro-dip drives SettledBodyLayer together with the well art")
	check(is_zero_approx(view._board_recoil_offset.x) and view._board_recoil_offset.y > 0.0 and view._board_recoil_offset.y <= 3.0,
		"Board micro-dip stays strictly vertical, non-oscillating, and <=3px for visual comfort (got=%s)" % str(view._board_recoil_offset))

	# Advance slightly so ripple reaches distance-1 neighbor without shifting its Control hit rect
	_advance_view(view, 0.06)
	var nb_tile = view._tiles[int(neighbor.id)]
	check(nb_tile.get_rect().is_equal_approx(neighbor_rect),
		"Board ripple and whole-board recoil never alter the neighbor Control hit rect")
	check(not nb_tile._ripple_offset.is_zero_approx() or not nb_tile._ripple_stretch.is_equal_approx(Vector2.ONE),
		"Neighbor gel surface visibly ripples away from the merge impact")

	# Finish merge and let ripples + aftershocks decay cleanly to rest
	_advance_view(view, Model.FUSION_SECONDS + 0.6)
	check(nb_tile._ripple_offset.is_zero_approx() and nb_tile._ripple_stretch.is_equal_approx(Vector2.ONE)
		and is_zero_approx(nb_tile._ripple_rotation) and view._board_recoil_offset.is_zero_approx(),
		"Board ripple, tilt, and whole-board recoil decay completely back to neutral rest pose")

	# Collect timing sync: recoil & splatter wait for pop_at, then fire right on the pop beat!
	var lv4_id: int = -1
	for cell: Dictionary in view.game.cells:
		if int(cell.get("merge_level", 0)) == 4:
			lv4_id = int(cell.id)
			break
	check(lv4_id >= 0, "Merged Lv4 tile is present on the board after fusion")
	cues.clear()
	check(view.game.collect(lv4_id), "Upgraded Lv4 merged word begins collection")
	view._refresh_fusion()
	check(is_zero_approx(view._well_impulse_strength),
		"Collection recoil waits during anticipation instead of firing prematurely at click time")
	var pop_at: float = Model.collection_pop_seconds(4)
	_advance_view(view, pop_at - 0.02)
	check(is_zero_approx(view._well_impulse_strength),
		"Before pop_at, collection stays in anticipation without premature board shake")
	_advance_view(view, 0.03)
	check(view._well_impulse_strength > 0.5 and not view._board_ripples.is_empty()
		and cues.any(func(c: String) -> bool: return c.begins_with("collect-punch:4:"))
		and int(view._collection_effects.snapshot().get("splatter_count", 0)) >= 1,
		"At pop_at, collection fires synchronized recoil, board ripple, splatter droplets, and collect-punch audio")
	_advance_view(view, 0.6)

	# Reduced motion suppresses all flash, ripple, splatter, and well impulse
	view.set_reduced_motion(true)
	view._trigger_well_impulse(0.9, Color.WHITE, Vector2.RIGHT)
	view._spawn_board_ripple(Vector2(3, 7), 1.0)
	check(is_zero_approx(view._well_impulse_strength) and view._board_ripples.is_empty()
		and view._board_recoil_offset.is_zero_approx(),
		"Reduced motion strictly suppresses well impulse, board recoil, and ripples")

	view.free()
	await process_frame


func test_boss_combat_impact_vfx() -> void:
	var view := BossView.new()
	root.add_child(view)
	view.size = Vector2(1000, 760)
	var board := Rect2(280, 100, 340, 580)
	var dock := Rect2(634, 130, 210, 330)
	view.layout_battle(dock, board, 1.0)

	var run := BossRun.new()
	run.configure(BossCatalog.encounter(63, false, 2), 71) # Legend Boss with starting ward=2 & clones=1
	var cues: Array[String] = []
	view.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	check(view.sync(run.snapshot(), {}, 1, true), "Boss view syncs Legend Boss encounter")

	# 1. Clone hit -> clone poof & audio
	check(run.clones == 1 and run.ward == 2, "Legend Boss starts with 1 clone and 2 wards")
	run.collect_hit("impact:clone", 1, 0, {"column": 3, "row": 5})
	run.advance(BossView.HIT_FLIGHT_SECONDS + 0.02, [], true)
	view.sync(run.snapshot(), {}, 1, true)
	check(int(view.snapshot().clone_poofs) >= 1 and cues.has("boss-clone-pop"),
		"Clone hit triggers purple poof dispersion and boss-clone-pop cue")

	# 2. Ward hit -> shield shatter shards & audio
	run.collect_hit("impact:ward", 2, 0, {"column": 3, "row": 5})
	run.advance(BossView.HIT_FLIGHT_SECONDS + 0.02, [], true)
	view.sync(run.snapshot(), {}, 1, true)
	check(int(view.snapshot().ward_shatters) >= 1 and cues.has("boss-ward-break"),
		"Ward hit triggers shield shatter shards and boss-ward-break cue")

	# Break remaining ward
	run.collect_hit("impact:ward2", 2, 0, {"column": 3, "row": 5})
	run.advance(BossView.HIT_FLIGHT_SECONDS + 0.02, [], true)
	view.sync(run.snapshot(), {}, 1, true)

	# 3. POWER! hit on real Boss -> 3D hit-flash, squash recoil, trailing health ghost, layered audio
	run.charge = 14
	run.collect_hit("impact:power", 5, 4, {"column": 3, "row": 4})
	run.advance(BossView.HIT_FLIGHT_SECONDS + 0.02, [], true)
	view.sync(run.snapshot(), {}, 1, true)
	var snap: Dictionary = view.snapshot()
	check(float(snap.hit_flash) > 0.5, "POWER! Boss hit illuminates 3D Pirate with hit-flash (got=%.2f)" % float(snap.hit_flash))
	check(cues.has("boss-hit") and cues.has("boss-hit-power"),
		"POWER! Boss hit preserves boss-hit cue and adds layered boss-hit-power cue")
	check(view._character.scale.x < 1.0 and view._character.position.x > view._character_rect.position.x,
		"Boss hit applies elastic horizontal squash and punchy knockback recoil")
	run.advance(0.18, [], true)
	view.sync(run.snapshot(), {}, 1, true)
	check(float(view.snapshot().energy_ghost_fraction) >= float(view.snapshot().energy_fraction),
		"Trailing damage ghost lags behind drained energy segments to highlight chunk damage")

	# 4. Compass Strike direct skill hit -> immediate beam strike + stun stars + hit-flash
	run.direct_skill_hit(180, {"column": 2, "row": 3}, false)
	run.advance(0.02, [], true)
	view.sync(run.snapshot(), {}, 1, true)
	check(int(view.snapshot().beam_strikes) >= 1 and float(run.stun_remaining) >= 2.4,
		"Compass Strike launches immediate piercing beam VFX and stuns Pirate")

	# 5. Reduced motion disables 3D hit-flash and recoil
	view.reduced_motion = true
	var still_run := BossRun.new()
	still_run.configure(BossCatalog.encounter(3), 71)
	view.sync(still_run.snapshot(), {}, 2, true)
	still_run.collect_hit("impact:reduced", 4, 0, {"column": 3, "row": 4})
	view.sync(still_run.snapshot(), {}, 2, true)
	check(is_zero_approx(float(view.snapshot().hit_flash)) and view._character.scale == Vector2.ONE,
		"Reduced motion disables 3D hit-flash and squash recoil")

	view.free()
	await process_frame


func test_layered_audio_cues() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.interact("spring", true)
	audio.play_jelly_cue("merge-impact:upgrade:4:3")
	audio.play_jelly_cue("collect-charge:4")
	audio.play_jelly_cue("collect-punch:4:2:0")
	audio.play_jelly_cue("collect-punch:1:0:3")
	audio.play_jelly_cue("wrong-bounce")
	audio.play_jelly_cue("merge-upgrade:4:3")
	audio.play_jelly_cue("merge-chain:5")
	audio.play_jelly_cue("contact_match")
	audio.play_jelly_cue("boss-hit")
	audio.play_jelly_cue("boss-hit-power")
	audio.play_jelly_cue("boss-ward-break")
	audio.play_jelly_cue("boss-clone-pop")
	check(audio._jelly_combo_players.size() == Audio.WORD_JELLY_COMBO_CHANNELS
		and audio._jelly_impact_players.size() == Audio.JELLY_IMPACT_CHANNELS,
		"Layered Nintendo impact audio reuses bounded combo and impact pools without allocating extra buses")
	audio.halt()
	audio.queue_free()
	await process_frame


func test_backdrop_glow_and_boss_shockwave() -> void:
	var backdrop := Backdrop.new()
	root.add_child(backdrop)
	backdrop.size = Vector2(1000, 760)
	backdrop.set_ambient_active(true)
	backdrop.set_process(false)
	# 1. Ordinary merge/collect glow pulses light only (0px shift, 0 zoom) -> zero motion sickness!
	backdrop.pulse_ambient_glow(0.8, Color("#fff0a8"), 0.34)
	backdrop._process(0.05)
	var glow_snap: Dictionary = backdrop.snapshot()
	check(float(glow_snap.impact_glow) > 0.3 and is_zero_approx(float(glow_snap.boss_kick_zoom))
		and is_zero_approx(float(glow_snap.boss_kick_offset[0])) and is_zero_approx(float(glow_snap.boss_kick_offset[1])),
		"Backdrop ambient glow pulses light without displacing scenery during normal merges/pops")
	# 2. Boss shockwave delivers dramatic parallax scenery slam + panoramic punch-zoom!
	backdrop.trigger_boss_shockwave(1.22, Color("#fff2a6"), Vector2(0.18, 1.0))
	backdrop._process(0.02)
	var boss_snap: Dictionary = backdrop.snapshot()
	var kick_vec := Vector2(float(boss_snap.boss_kick_offset[0]), float(boss_snap.boss_kick_offset[1]))
	check(kick_vec.length() > 8.0 and float(boss_snap.boss_kick_zoom) > 0.015 and float(boss_snap.impact_glow) > 0.3,
		"Boss finisher shockwave drives dramatic parallax scenery kick and punch-zoom (len=%.1f zoom=%.3f)" % [kick_vec.length(), float(boss_snap.boss_kick_zoom)])
	# 3. Decays cleanly back to neutral rest pose
	for step in range(30):
		backdrop._process(0.025)
	var rest_snap: Dictionary = backdrop.snapshot()
	check(is_zero_approx(float(rest_snap.impact_glow)) and is_zero_approx(float(rest_snap.boss_kick_zoom))
		and is_zero_approx(float(rest_snap.boss_kick_offset[0])) and is_zero_approx(float(rest_snap.boss_kick_offset[1])),
		"Backdrop glow and Boss shockwave decay cleanly back to neutral rest")
	# 4. Reduced motion strictly disables both glow and Boss shockwave
	backdrop.set_reduced_motion(true)
	backdrop.trigger_boss_shockwave(1.22, Color("#fff2a6"), Vector2(0.0, 1.0))
	var still_snap: Dictionary = backdrop.snapshot()
	check(is_zero_approx(float(still_snap.impact_glow)) and is_zero_approx(float(still_snap.boss_kick_zoom))
		and is_zero_approx(float(still_snap.boss_kick_offset[1])),
		"Reduced motion strictly suppresses backdrop glow and Boss shockwave")
	backdrop.free()
	await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 760)
	_prepare_words()
	await test_merge_impact_and_board_ripple()
	await test_boss_combat_impact_vfx()
	await test_layered_audio_cues()
	await test_backdrop_glow_and_boss_shockwave()
	await create_timer(0.15).timeout
	print("Word Jelly impact feel: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
