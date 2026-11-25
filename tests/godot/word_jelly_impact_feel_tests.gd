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

	# Advance right past the p=0.44 snap impact boundary!
	_advance_view(view, Model.FUSION_SECONDS * 0.48)
	var visual: Dictionary = view._fusion_visuals.values()[0]
	var flash_u: float = float(visual.art._gel.get_shader_parameter("impact_flash"))
	check(flash_u > 0.1, "Merge snap drives shader impact_flash on the liquid union (got=%.3f)" % flash_u)
	check(int(view._collection_effects.snapshot().get("merge_pop_count", 0)) >= 1,
		"Upgrade merge spawns a crisp Merge Pop shockwave/star/Lv4! badge effect")
	check(view._well_impulse_strength > 0.25 and not view._board_ripples.is_empty(),
		"Merge snap fires directional well impulse and neighborhood board ripple")

	# Advance slightly so ripple reaches distance-1 neighbor without shifting its Control hit rect
	_advance_view(view, 0.06)
	var nb_tile = view._tiles[int(neighbor.id)]
	check(nb_tile.get_rect().is_equal_approx(neighbor_rect),
		"Board ripple never alters the neighbor Control hit rect")
	check(not nb_tile._ripple_offset.is_zero_approx() or not nb_tile._ripple_stretch.is_equal_approx(Vector2.ONE),
		"Neighbor gel surface visibly ripples away from the merge impact")

	# Finish merge and let ripples decay cleanly to rest
	_advance_view(view, Model.FUSION_SECONDS + 0.5)
	check(nb_tile._ripple_offset.is_zero_approx() and nb_tile._ripple_stretch.is_equal_approx(Vector2.ONE),
		"Board ripple decays completely back to neutral rest pose")

	# Reduced motion suppresses all flash, ripple, and well impulse
	view.set_reduced_motion(true)
	view._trigger_well_impulse(0.9, Color.WHITE, Vector2.RIGHT)
	view._spawn_board_ripple(Vector2(3, 7), 1.0)
	check(is_zero_approx(view._well_impulse_strength) and view._board_ripples.is_empty(),
		"Reduced motion strictly suppresses well impulse and board ripples")

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
	audio.play_jelly_cue("merge-upgrade:4:3")
	audio.play_jelly_cue("merge-chain:5")
	audio.play_jelly_cue("contact_match")
	audio.play_jelly_cue("boss-hit")
	audio.play_jelly_cue("boss-hit-power")
	audio.play_jelly_cue("boss-ward-break")
	audio.play_jelly_cue("boss-clone-pop")
	check(audio._jelly_combo_players.size() == Audio.WORD_JELLY_COMBO_CHANNELS,
		"Layered impact audio reuses the bounded combo accent pool without allocating extra buses")
	audio.halt()
	audio.queue_free()
	await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 760)
	_prepare_words()
	await test_merge_impact_and_board_ripple()
	await test_boss_combat_impact_vfx()
	await test_layered_audio_cues()
	await create_timer(0.15).timeout
	print("Word Jelly impact feel: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
