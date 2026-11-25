extends SceneTree
## Capture multi-viewport real runtime screenshots of the upgraded Storybook 2.5D assets:
## 1) Jelly Journey Map (desktop 1366x768 & phone 393x852, Chapters 1, 5, 11)
## 2) Jelly Words Board with 3D Gel Skins, Well Frame & Biome Backdrops
## 3) RPG Adventurer Pack Overlay (Pip Build Stances + Relics Tabs)
## 4) Challenge Boon Draft Modal (Fluent 3D Boon Icons + Parchment Panel)
## 5) Memory Garden (Storybook Quilted Card Backs)

const MapView = preload("res://scripts/word_jelly_map.gd")
const Backdrop = preload("res://scripts/jelly_backdrop.gd")
const RpgOverlay = preload("res://scripts/word_jelly_rpg_overlay.gd")
const RpgCatalog = preload("res://scripts/word_jelly_rpg_catalog.gd")
const BoonDraft = preload("res://scripts/word_jelly_boon_draft.gd")
const MemoryGarden = preload("res://scripts/memory_garden.gd")
const Data = preload("res://scripts/game_data.gd")
const WordJellyView = preload("res://scripts/word_jelly.gd")
const OUT_DIR = "res://build/qa/storybook-upgrade-qa"


func _initialize() -> void:
	_run.call_deferred()


func _settle(frames: int = 4) -> void:
	for _i in range(frames):
		await process_frame


func _capture(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await _settle(3)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(OUT_DIR + "/" + name + ".png")
		print("Captured: " + name + " (%dx%d)" % [img.get_width(), img.get_height()])


func _run() -> void:
	var data := Data.new()
	data.load_all()
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)

	# 1. Jelly Journey Map (Desktop 1366x768)
	root.size = Vector2i(1366, 768)
	var map := MapView.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(map)
	var map_state := {
		"highest_cleared": 42,
		"best_stars": {"1": 3, "2": 3, "3": 2, "37": 3, "38": 2, "39": 3, "40": 3, "41": 2, "42": 3},
		"frontier": 43,
		"coins": 1280,
		"merged_level": 5,
		"auto_merge_level": 4,
		"star_charm_level": 3,
		"prestige_rank": 1,
		"upgrade_affordable": true,
		"boss_markers": [3, 5, 7, 9, 18, 36, 63, 99],
		"boss_victories": [1, 2, 3, 4],
		"pip_age": 5,
		"loading": false,
		"error": ""
	}
	map.open(map_state, true)
	map.show_chapter(5)
	await _capture("01-map-ch5-desktop")
	map.show_chapter(11)
	await _capture("02-map-ch11-castle-desktop")
	root.size = Vector2i(393, 852)
	map.show_chapter(4)
	await _capture("03-map-ch4-cottage-phone")
	map.queue_free()
	await _settle(2)

	# 2. Jelly Words Gameplay Board with 3D Gels, Well Frame & Biome Backdrop
	root.size = Vector2i(1366, 768)
	var backdrop := Backdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.set_chapter(5)
	holder.add_child(backdrop)
	var jelly := WordJellyView.new()
	jelly.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(jelly)
	var words: Array = data.words.filter(func(w: Dictionary) -> bool: return int(w.get("min_age", 99)) <= 5 and not str(w.get("image", "")).is_empty())
	jelly.configure(words.slice(0, 12), 1, data.theme("autumn"), data.chests, true, 42)
	jelly.apply_atmosphere(backdrop.atmosphere())
	await _capture("04-jelly-board-ch5-desktop")

	# 3. RPG Adventurer Pack Overlay (Build + Relics)
	var rpg := RpgOverlay.new()
	rpg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(rpg)
	var payload := {
		"coins": 1280, "boss_tokens": 5, "pip_level": 18, "claimable_count": 2,
		"boss_victories": [1, 2, 3, 4],
		"relic_levels": {"thaw_bell": 2, "clarity_lens": 1, "master_key": 3, "truth_prism": 1, "gale_feather": 2, "echo_clasp": 1, "aegis_crest": 2, "word_compass": 1},
		"profile": RpgCatalog.compute_profile(18, 5, {"level": 5, "auto_merge_level": 4, "star_charm_level": 3, "prestige_rank": 1},
			{"stance": "hunter", "equipped_relics": ["thaw_bell", "master_key"], "relic_levels": {"thaw_bell": 2, "master_key": 3}}, {}, 4, 90),
		"rpg_state": {"active_days": ["2026-11-24", "2026-11-25"], "bounties": []}
	}
	rpg.open(payload, "build", true)
	await _capture("05-rpg-build-stances")
	rpg.open(payload, "relics", true)
	await _capture("06-rpg-relics-3d")
	rpg.queue_free()

	# 4. Challenge Boon Draft Modal
	var boon := BoonDraft.new()
	boon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(boon)
	boon.present(RpgCatalog.CHALLENGE_BOONS.slice(0, 3))
	await _capture("07-boon-draft-3d")
	boon.queue_free()
	jelly.queue_free()
	backdrop.queue_free()
	await _settle(2)

	# 5. Memory Garden with Storybook Card Backs
	var mem := MemoryGarden.new()
	mem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(mem)
	mem.start_round(words.slice(0, 6), data.theme("spring"), 7)
	await _capture("08-memory-card-backs")

	print("All QA captures completed.")
	quit(0)
