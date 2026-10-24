extends SceneTree

const Jelly = preload("res://scripts/word_jelly.gd")
const Data = preload("res://scripts/game_data.gd")
const GrowthMorphology = preload("res://scripts/growth_morphology.gd")
var checks: int = 0
var failures: int = 0
var cues: Array[String] = []
var attempts: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _advance(view, seconds: float) -> void:
	while seconds > 0.00001:
		var step: float = minf(seconds, 0.025)
		view._process(step)
		seconds -= step

func _install(view, tiles: Array) -> void:
	view.game.cells.clear()
	for index in range(tiles.size()):
		tiles[index].column = index
		tiles[index].row = 7
		tiles[index].age = view.game.SETTLE_SECONDS
		tiles[index].settling = false
		tiles[index].falling = false
		tiles[index].arrival = false
		view.game.cells.append(tiles[index])
	view._sync_tiles()
	view._layout()
	# Reusing an existing body at a new fixture column starts its normal reflow.
	# Let that real presentation settle before reading pointer coordinates.
	_advance(view, view.game.SETTLE_SECONDS + 0.05)

func _drag(view, first: int, second: int) -> void:
	var from: Vector2 = view._tiles[first].get_global_rect().get_center()
	var to: Vector2 = view._tiles[second].get_global_rect().get_center()
	check(from.distance_to(to) > 7.0, "The drag fixture has distinct displayed source and target positions")
	check(view._press(-1, from), "The root or merged Jelly can be picked up")
	view._move(to)
	check(view._dragging and view._target == second, "A dragged body contacts the intended partner")
	view._release(to)
	_advance(view, 1.1)

func _run() -> void:
	var data := Data.new()
	check(data.load_all(), "Production vocabulary and art load")
	var cat: Dictionary
	for word: Dictionary in data.words:
		if word.id == "cat":
			cat = GrowthMorphology.decorate(word)
	var view := Jelly.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(1000, 720)
	view.credit_collection = func(_id: String, _coins: int) -> Dictionary: return {"ok": true}
	view.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	view.word_attempted.connect(func(id: String, _ids: Array[String], correct: bool) -> void:
		if correct: attempts.append(id))
	check(view.configure([cat], 3, Data.theme("spring"), data.chests, false, 42), "Hybrid view configures")
	view.game.spawn_interval = 10000.0
	var root_tile: Dictionary = view.game._new_composition_tile(view.game._morphology.source_tiles(cat.morphology.id)[0])
	var picture: Dictionary = view.game._new_picture_tile(cat)
	_install(view, [root_tile, picture])
	var before: Dictionary = view.snapshot()
	check(before.tiles[0].label_visible and not before.tiles[0].picture_visible, "A root shows only text")
	check(not before.tiles[1].label_visible and before.tiles[1].picture_visible, "A picture shows only artwork")
	view._show_read(int(picture.id))
	check(not view._read_panel.visible, "Picture Read cannot expose the matching word")
	_drag(view, int(root_tile.id), int(picture.id))
	check(view.game.cells.size() == 1 and view.game.cells[0].jelly_kind == "merged", "Dragging word onto picture creates a merged Jelly")
	var merged: Dictionary = view.game.cells[0]
	check(view._tiles[int(merged.id)]._picture.visible and view._tiles[int(merged.id)]._label.visible, "Merged Jelly displays picture and word")
	check(attempts.is_empty(), "Picture fusion does not prematurely grant mastery")
	var second: Dictionary = merged.duplicate(true)
	second.id = view.game._next_tile_id
	view.game._next_tile_id += 1
	_install(view, [merged, second])
	_drag(view, int(merged.id), int(second.id))
	check(view.game.cells.size() == 1 and view.game.cells[0].merge_level == 2, "Dragging identical Lv1 Jellies upgrades to Lv2")
	merged = view.game.cells[0]
	check(view._tiles[int(merged.id)].presentation_snapshot().level_badge == "2", "Lv2 badge is visible")
	check(attempts.is_empty(), "Upgrade does not prematurely grant mastery")
	second = merged.duplicate(true)
	second.id = view.game._next_tile_id
	view.game._next_tile_id += 1
	second.merge_level = 3
	_install(view, [merged, second])
	_drag(view, int(merged.id), int(second.id))
	check(view.game.cells.size() == 1 and view.game.cells[0].merge_level == 5,
		"Dragging a Lv2 onto the same Lv3 word adds into Lv5")
	merged = view.game.cells[0]
	check(view._tiles[int(merged.id)].presentation_snapshot().level_badge == "5", "The summed result displays its Lv5 badge")
	# The same actual tile is promoted for focused presentation checks; model
	# tests separately prove every legal upgrade and the Lv6 cap.
	for level in range(1, view.game.MAX_MERGE_LEVEL + 1):
		var tile: Dictionary = merged.duplicate(true)
		tile.id = view.game._next_tile_id
		view.game._next_tile_id += 1
		tile.merge_level = level
		_install(view, [tile])
		cues.clear()
		var previous_attempts: int = attempts.size()
		view._collect(int(tile.id))
		check(view._collection_effects.snapshot().active_count == 1, "Lv%d schedules one collection effect" % level)
		_advance(view, view.game.collection_pop_seconds(level) - 0.01)
		check(not cues.has("pop" if level == 1 else "jelly-collect-lv%d" % level),
			"Lv%d sound waits through its visible anticipation" % level)
		_advance(view, 0.02)
		check(cues.has("pop" if level == 1 else "jelly-collect-lv%d" % level), "Lv%d sound follows collection pop" % level)
		_advance(view, 0.35)
		check(view.game.cells.is_empty() and attempts.size() == previous_attempts + 1, "Lv%d collection credits once" % level)
		view.pause(true)
		check(view._collection_effects.snapshot().active_count == 0, "Pause clears Lv%d visual tail" % level)
		view.pause(false)
	var no_picture: Dictionary = cat.duplicate(true)
	no_picture.image = ""
	check(view.configure([no_picture], 3, Data.theme("spring"), data.chests, true, 43), "Image-free word configures")
	view.game.spawn_interval = 10000.0
	var ready: Dictionary = view.game.cells[0]
	check(ready.jelly_kind == "merged", "Image-free whole word arrives ready")
	view._collect(int(ready.id))
	check(view._word_reveal.snapshot().visible and view._word_reveal.snapshot().spelling == "cat", "Image-free collection still presents readable spelling")
	_advance(view, 0.5)
	view.stop()
	check(view._collection_effects.snapshot().active_count == 0, "Stop clears all effects")
	for dimensions: Vector2 in [Vector2(1000, 720), Vector2(390, 844)]:
		view.size = dimensions
		for reduced: bool in [false, true]:
			_check_charge(view, cat, data, reduced)
	_check_charge_resize(view, cat, data)
	view.free()
	print("Word Jelly hybrid view: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _begin_charge(view, cat: Dictionary) -> Dictionary:
	var tile: Dictionary = view.game._new_word_root(cat, 2)
	view.game._set_merged_word(tile, cat, 4, true)
	_install(view, [tile])
	cues.clear()
	view._collect(int(tile.id))
	return view._fusion_visuals[str(view.game.fusions[0].attempt_id)]


func _charge_nodes(visual: Dictionary) -> Array[Node]:
	var nodes: Array[Node] = [visual.collect_glow]
	for spark: TextureRect in visual.get("charge_sparks", []):
		nodes.append(spark)
	return nodes


func _check_charge(view, cat: Dictionary, data, reduced: bool) -> void:
	check(view.configure([cat], 3, Data.theme("spring"), data.chests, reduced, 44), "Charge fixture configures")
	view.game.spawn_interval = 10000.0
	var visual: Dictionary = _begin_charge(view, cat)
	var card = view._word_reveal._entries[0]
	check(card.visible and view._word_reveal.snapshot().visible
		and card.snapshot().phase == "charging" and card.snapshot().effects.phase == "charging",
		"The top reading card gathers energy alongside the original Lv4 Jelly")
	_advance(view, 0.22)
	check(card._visual.scale.is_equal_approx(Vector2.ONE) if reduced else card._visual.scale.x < 0.95,
		"The top reading card also contracts during charge and honors reduced motion")
	check(visual.merged.scale.is_equal_approx(Vector2.ONE) if reduced else visual.merged.scale.x < 0.63,
		"Lv4 visibly contracts before its firework, while reduced motion keeps the original size")
	check(visual.merged.modulate.a == 1.0 and visual.collect_glow.visible,
		"The contracted Jelly and its acquired energy glow remain readable during charge")
	check(visual.get("charge_sparks", []).size() == (0 if reduced else 8),
		"Normal motion gathers acquired sparkle artwork; reduced motion has no moving sparks")
	var position_before: Vector2 = visual.merged.position
	var glow_before: Rect2 = visual.collect_glow.get_rect()
	var radius_before: float = 0.0
	if not reduced:
		radius_before = visual.charge_sparks[0].get_rect().get_center().distance_to(visual.merged.get_rect().get_center())
	_advance(view, 0.25)
	if reduced:
		check(visual.merged.scale.is_equal_approx(Vector2.ONE) and visual.merged.position == position_before
			and visual.collect_glow.get_rect().is_equal_approx(glow_before),
			"Reduced-motion charge keeps the body and glow geometry still")
	else:
		check(visual.charge_sparks[0].get_rect().get_center().distance_to(visual.merged.get_rect().get_center()) < radius_before,
			"The acquired sparkles travel inward toward the charging Jelly")
	_advance(view, view.game.collection_pop_seconds(4) - 0.47 - 0.001)
	check(card.visible and card.snapshot().phase == "charging" and card.snapshot().effects.phase == "charging"
		and not cues.has("jelly-collect-lv4") and view.game.cleared_pairs == 0,
		"The last anticipation frame keeps its charged card without an early burst sound or collection credit")
	_advance(view, 0.002)
	check(card.visible and card.snapshot().phase == "release" and card.snapshot().effects.phase != "charging"
		and cues.count("jelly-collect-lv4") == 1 and view.game.cleared_pairs == 0,
		"The reading card's explosion and firework sound release together at the Lv4 pop boundary")
	_advance(view, 0.14)
	check(visual.merged.modulate.a < 0.001 and not view.game.cells.is_empty(),
		"The Jelly disappears into its burst before its reserved collection completes")
	var owned: Array[Node] = _charge_nodes(visual)
	_advance(view, 0.11)
	check(view.game.cells.is_empty() and view._fusion_visuals.is_empty() and cues.count("jelly-collect-lv4") == 1,
		"The completed firework leaves one collection and retires its fusion presentation")
	for node: Node in owned:
		check(node.is_queued_for_deletion(), "Charge glow and sparkles retire with their owning collection")
	for action: String in ["configure", "stop"]:
		check(view.configure([cat], 3, Data.theme("spring"), data.chests, reduced, 45), "Interrupted charge fixture configures")
		view.game.spawn_interval = 10000.0
		visual = _begin_charge(view, cat)
		_advance(view, 0.30)
		owned = _charge_nodes(visual)
		if action == "configure":
			view.configure([cat], 3, Data.theme("spring"), data.chests, reduced, 46)
		else:
			view.stop()
		check(view._fusion_visuals.is_empty() and view._word_reveal.snapshot().entries.is_empty()
			and view._collection_effects.snapshot().active_count == 0,
			action + " clears charging Jellies, charging reading cards, and future firework tails")
		for node: Node in owned:
			check(node.is_queued_for_deletion(), action + " releases every extra charge node")


func _check_charge_resize(view, cat: Dictionary, data) -> void:
	view.size = Vector2(1000, 720)
	check(view.configure([cat], 3, Data.theme("spring"), data.chests, false, 47), "Resize charge fixture configures")
	view.game.spawn_interval = 10000.0
	var visual: Dictionary = _begin_charge(view, cat)
	_advance(view, 0.30)
	var fusion: Dictionary = view.game.fusions[0].duplicate(true)
	var before: Dictionary = view._collection_effects.snapshot().entries[0]
	view.size = Vector2(390, 844)
	view._layout()
	var expected: Vector2 = view._tile_rect(fusion.a).get_center()
	var after: Dictionary = view._collection_effects.snapshot().entries[0]
	var moved_origin := Vector2(after.origin[0], after.origin[1])
	check(moved_origin.is_equal_approx(expected)
		and moved_origin.distance_to(Vector2(before.origin[0], before.origin[1])) > 10.0,
		"Desktop-to-phone resize moves the pending firework to the charged Jelly's actual new center")
	check(visual.collect_glow.get_rect().get_center().is_equal_approx(expected),
		"The gathering glow and pending explosion remain anchored to the same resized Jelly")
	check(after.id == before.id and after.anchor_id == fusion.attempt_id and after.elapsed == before.elapsed
		and after.delay == before.delay and not after.popped,
		"Reanchoring preserves the exact pending effect identity, charge age, and pop boundary")
	_advance(view, float(fusion.pop_at) - float(before.elapsed) + 0.01)
	var released: Dictionary = view._collection_effects.snapshot().entries[0]
	check(released.popped and Vector2(released.origin[0], released.origin[1]).is_equal_approx(expected)
		and cues.count("jelly-collect-lv4") == 1,
		"The resized Jelly releases its firework at the new position on its original audio boundary")
	view.size = Vector2(1000, 720)
	view._layout()
	var settled: Dictionary = view._collection_effects.snapshot().entries[0]
	check(settled.origin == released.origin and settled.elapsed == released.elapsed
		and view._collection_effects.snapshot().active_count == 1,
		"A later resize cannot teleport, restart, or duplicate an already released firework")
	view.stop()
