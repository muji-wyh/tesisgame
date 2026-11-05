extends SceneTree

const Progress = preload("res://scripts/jelly_reward_progress.gd")
const Economy = preload("res://scripts/coin_economy.gd")


func _initialize() -> void:
	var failures: int = 0
	var checks: int = 0
	for tier in range(1, 100):
		var fragments: int = 4 + (tier - 1) * 5
		var state: Dictionary = Progress.reward_progress(fragments)
		checks += 1
		if int(state.chest_tier) != tier or int(state.chest_count) != 1:
			printerr("FAIL: Each of the ninety-nine newly earned chest levels has its exact fragment threshold.")
			failures += 1
		var before: Dictionary = Progress.reward_progress(fragments - 1)
		checks += 1
		if int(before.chest_tier) != tier - 1 or int(state.max_chest_tier) != 99:
			printerr("FAIL: Every chest threshold crosses exactly one level while retaining the level-99 cap.")
			failures += 1
		checks += 1
		if int(Economy.chest_reward(tier, 0).tier) != tier or int(Economy.chest_reward(tier, 0).total) != 75 * tier:
			printerr("FAIL: New visual materials never change the earned tier's existing coin entitlement.")
			failures += 1
	for fragments: int in [494, 499, 10000]:
		var state: Dictionary = Progress.reward_progress(fragments)
		checks += 1
		if int(state.chest_tier) != 99 or int(state.fragments_toward_next) != int(state.fragments_required):
			printerr("FAIL: Fragment earnings cannot create chest level 100; the level-99 meter stays complete.")
			failures += 1
	checks += 1
	if int(Economy.chest_reward(42, 99, Economy.PREVIOUS_CHEST_REWARD_POLICY).tier) != 42:
		printerr("FAIL: Already reserved historical chest quote tiers remain verifiable, not silently rewritten.")
		failures += 1
	print("Chest tier progression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
