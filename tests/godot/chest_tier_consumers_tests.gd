extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Progress = preload("res://scripts/jelly_reward_progress.gd")
const Pair = preload("res://scripts/pair_chest_reward.gd")
const Badge = preload("res://scripts/memory_reward_badge.gd")
const Celebration = preload("res://scripts/round_celebration.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var data := Data.new()
	check(data.load_all(), "Reward consumers use the real acquired chest catalog")
	var pair := Pair.new()
	root.add_child(pair)
	check(pair.configure("tier-consumer", Progress.theme_for_tier(6), data.chests, false),
		"The ordinary earned-pair preview configures through its existing public API")
	check(pair._model_tier == 6 and pair._models._pool.has(6)
		and int(pair.chest.hold_effect_snapshot().get("chest_tier", 0)) == 6,
		"Pair tier six must use the same volumetric tier for its closed preview and full turn")
	pair.free()
	var badge := Badge.new()
	root.add_child(badge)
	check(badge.configure("tier-consumer", 6, data.chests, Data.theme("spring"), false)
		and int(badge.chest.hold_effect_snapshot().get("chest_tier", 0)) == 6,
		"Memory's actual potential level six is not silently replaced by a legacy theme's level28 skin")
	badge._animating = true
	badge._tier = 5
	badge._elapsed = 0.20
	badge._sample()
	check(is_zero_approx(badge.chest.rotation) and absf(badge.chest._model_view._rig.rotation.y) > 0.05,
		"The reverse upgrade really turns 3D geometry instead of rotating its flat viewport texture")
	badge.free()
	var celebration := Celebration.new()
	root.add_child(celebration)
	celebration.begin("tier-consumer", "spring", data.chests, 1, true, true, 0, 12)
	check(int(celebration.chest.hold_effect_snapshot().get("chest_tier", 0)) == 12,
		"The shared completion performance retains the earned chest's exact level")
	celebration.free()
	await process_frame
	print("Chest tier consumers: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
