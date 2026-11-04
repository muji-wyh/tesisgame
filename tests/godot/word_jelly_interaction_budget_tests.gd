extends SceneTree

const Budget = preload("res://scripts/word_jelly_ambient_budget.gd")
const Fusion = preload("res://scripts/jelly_fusion.gd")
const Reveal = preload("res://scripts/word_jelly_word_reveal.gd")
const LevelFX = preload("res://scripts/word_jelly_reveal_fx.gd")
const SKIN = preload("res://assets/images/jelly-match/gel-mint.png")

class Owner extends Control:
	var tile_id: int = -1
	var animated: bool = false
	func set_ambient_animation(enabled: bool) -> void:
		animated = enabled

class CountedFX extends LevelFX:
	var generated: int = 0

	func _stamp(_texture: Texture2D, _point: Vector2, _extent: Vector2, _color: Color, _angle: float = 0.0) -> void:
		generated += 1
		if _stamp_limit >= 0 and _stamp_count >= _stamp_limit:
			return
		_stamp_count += 1

	func sample(age: float) -> int:
		elapsed = age
		_stamp_count = 0
		generated = 0
		if _stamp_limit == 0:
			return 0
		if reduced_motion:
			_draw_steady(1.0)
		elif age < 0.0:
			_draw_charge(0.75)
		else:
			_draw_release(1.0)
			_draw_celebration(1.0)
		return _stamp_count

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
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	_check_priority_batch()
	_check_lazy_fusion()
	_check_reveal_budget()
	_check_stamp_generation()
	print("Word Jelly interaction budgets: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_priority_batch() -> void:
	var budget = Budget.new()
	var owners: Array[Owner] = []
	budget.begin_priority_update()
	for id in range(49):
		var owner := Owner.new()
		owner.tile_id = id
		root.add_child(owner)
		owners.append(owner)
		budget.register(owner)
	check(int(budget.snapshot().refreshes) == 0, "Registering a full board within one update performs no intermediate cohort scans")
	budget.end_priority_update()
	check(int(budget.snapshot().refreshes) == 1 and budget.animated_ids().size() == Budget.IDLE_SLOTS,
		"The registration batch selects its idle cohort in one scan")
	budget.begin_priority_update()
	budget.begin_priority_update()
	for id in range(24, 49):
		budget.set_priority(id, true)
	budget.end_priority_update()
	check(int(budget.snapshot().refreshes) == 1 and not owners[48].animated,
		"Nested hint updates retain one pending refresh until the outer boundary")
	budget.end_priority_update()
	check(int(budget.snapshot().refreshes) == 2 and owners[48].animated,
		"Many simultaneous priorities flush once and become visible before returning to input")
	budget.set_priority(23, true)
	check(owners[23].animated and int(budget.snapshot().refreshes) == 3,
		"A pointer transition outside a batch keeps immediate animation feedback")
	budget.begin_priority_update()
	for id in range(49):
		budget.set_priority(id, false)
	budget.end_priority_update()
	check(int(budget.snapshot().refreshes) == 4 and budget.animated_ids().size() == Budget.IDLE_SLOTS,
		"Releasing a crowded hint cohort restores the idle budget with one scan")
	budget.begin_priority_update()
	budget.set_priority(48, true)
	budget.clear()
	budget.end_priority_update()
	check(budget.animated_ids().is_empty() and int(budget.snapshot().priority_depth) == 0,
		"Disposal cancels a pending priority update without restoring old owners")
	for owner: Owner in owners:
		owner.free()


func _pose(art, release: float, opacity: float = 1.0) -> void:
	art.pose(Vector2(200, 200), Vector2(300, 200), Vector2(250, 200),
		Vector2(100, 100), Vector2(100, 100), 100.0, 0.5, 0.0, release, opacity)


func _check_lazy_fusion() -> void:
	var art = Fusion.new()
	root.add_child(art)
	art.configure(["coral", "mint", "sky", "lilac"], 0, 1, SKIN)
	_pose(art, 0.0)
	check(art._beads.is_empty() and not art._glow.visible,
		"A Word Jelly union allocates no unused release bead materials or invisible glow pass")
	_pose(art, 0.0, 0.0)
	check(not art.visible, "Full handover stops drawing the zero-opacity union")
	_pose(art, 0.4)
	check(art.visible and art._beads.size() == 5 and art._beads[0].texture == SKIN,
		"A game mode with bead release lazily acquires the original five sourced gel beads")
	var identity: int = art._beads[0].get_instance_id()
	_pose(art, 0.6)
	check(art._beads.size() == 5 and art._beads[0].get_instance_id() == identity,
		"Ongoing release reuses its bead nodes and materials")
	_pose(art, 1.0, 0.0)
	check(not art.visible, "The final release hides its completed union and particles")
	_pose(art, 0.0)
	check(art.visible and not art._beads[0].visible, "Reusing a completed union starts cleanly without stale release beads")
	art.free()


func _word(index: int) -> Dictionary:
	return {"id": "budget-word-%d" % index, "text": "word %d" % index, "image": ""}


func _check_reveal_budget() -> void:
	var reveal = Reveal.new()
	root.add_child(reveal)
	reveal.configure_layout(Rect2(0, 0, 1366, 768), 1.0)
	for index in range(20):
		reveal.present(_word(index), null, Color.WHITE, true, 0.0, 9, 0.04)
	var state: Dictionary = reveal.snapshot()
	check(int(state.active_count) == 20 and reveal.get_child_count() == 20,
		"A crowded collection preserves every reading card and word identity")
	var heroes: int = 0
	var limits: int = 0
	for index in range(state.entries.size()):
		var entry: Dictionary = state.entries[index]
		check(entry.word_id == _word(index).id and entry.spelling == _word(index).text,
			"Collection word %d remains present after its effects receive a budget" % index)
		var limit: int = int(entry.effects.stamp_limit)
		if limit < 0:
			heroes += 1
		else:
			limits += limit
			check(int(entry.effects.trail_count) <= 1 and int(entry.effects.spark_count) <= 12,
				"Secondary celebration %d generates compact particle tails" % index)
	check(heroes == 1 and limits <= Reveal.SECONDARY_STAMP_BUDGET
		and int(state.particle_budget.hero_entry_id) == int(state.entries.back().entry_id),
		"One current collection owns full fireworks while all secondary cards share a fixed global stamp budget")
	reveal.advance(0.95)
	state = reveal.snapshot()
	check(state.active_count == 20 and state.entries.all(func(entry: Dictionary) -> bool: return entry.phase == "afterglow"),
		"Secondary budgets retain each card's original afterglow lifetime")
	reveal.set_reduced_motion(true)
	check(reveal.snapshot().entries.all(func(entry: Dictionary) -> bool: return entry.effects.reduced_motion),
		"Reduced motion applies to all preserved collection identities")
	reveal.advance(1.2)
	check(reveal.get_child_count() == 0 and reveal.snapshot().active_count == 0,
		"Every collection card and budget owner expires at its original effect boundary")
	reveal.present(_word(21), null, Color.WHITE, false, 0.0, 9)
	check(int(reveal.snapshot().effects.stamp_limit) == -1,
		"An isolated collection retains its original full celebration")
	reveal.reset()
	check(int(reveal.particle_budget_snapshot().secondary_stamps) == 0,
		"Round cleanup clears every secondary particle reservation")
	reveal.free()


func _check_stamp_generation() -> void:
	var fx := CountedFX.new()
	fx.configure(Vector2(180, 100), 1.0, 9, Color.WHITE, true, 96.0)
	fx.duration = 1.95
	fx.anticipation_seconds = 0.4
	fx.set_particle_budget(-1)
	check(fx.sample(0.8) > 500, "The current hero retains its detailed high-level firework trajectory")
	for limit: int in [0, 1, 8, 12, 64]:
		fx.set_particle_budget(limit)
		for age: float in [-0.2, 0.03, 0.8, 1.3]:
			check(fx.sample(age) <= limit and fx.generated <= maxi(1, limit) + 4,
				"Secondary limit %d bounds accepted and generated stamps at age %.2f" % [limit, age])
	fx.free()
