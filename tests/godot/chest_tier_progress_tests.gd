extends SceneTree

const Progress = preload("res://scripts/jelly_reward_progress.gd")
const Economy = preload("res://scripts/coin_economy.gd")


func _initialize() -> void:
	var failures: int = 0
	var checks: int = 0
	for tier in range(1, 31):
		var fragments: int = 4 + (tier - 1) * 5
		var state: Dictionary = Progress.reward_progress(fragments)
		checks += 1
		if int(state.chest_tier) != tier or int(state.chest_count) != 1:
			printerr("FAIL: Each of the thirty newly earned chest levels has its exact fragment threshold.")
			failures += 1
	for fragments: int in [154, 499, 10000]:
		var state: Dictionary = Progress.reward_progress(fragments)
		checks += 1
		if int(state.chest_tier) != 30 or int(state.fragments_toward_next) != int(state.fragments_required):
			printerr("FAIL: Fragment earnings cannot create chest level 31; the level-30 meter stays complete.")
			failures += 1
	checks += 1
	if int(Economy.chest_reward(42, 99, Economy.PREVIOUS_CHEST_REWARD_POLICY).tier) != 42:
		printerr("FAIL: Already reserved historical chest quote tiers remain verifiable, not silently rewritten.")
		failures += 1
	print("Chest tier progression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
