extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
const Economy = preload("res://scripts/coin_economy.gd")
const ButtonView = preload("res://scripts/word_jelly_powerup_button.gd")
var checks := 0
var failures := 0
var word: Dictionary = {"id": "cat", "text": "cat", "min_age": 3,
	"image": "res://assets/images/ui/modes/cat.webp", "audio": "fixture:cat"}


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func fixture(level: int, count: int):
	var model := Model.new()
	check(model.configure([word], 3, 1901), "Use a real pictured word for legal automatic upgrades")
	model.auto_merge_level = level
	model.spawn_interval = 10000.0
	model.cells.clear()
	for index in range(count):
		var tile: Dictionary = model._new_word_root(word, index + 1)
		model._set_merged_word(tile, word, 1, true)
		model.cells.append(tile)
	settle_board(model)
	return model


func settle_board(model) -> void:
	for index in range(model.cells.size()):
		model.cells[index].merge({"column": index % Model.COLUMNS,
			"row": Model.ROWS - 1 - int(index / Model.COLUMNS), "age": 100.0,
			"settling": false, "falling": false, "arrival": false}, true)


func payments(model) -> Array:
	var paid: Array = []
	model.purchase_powerup = func(id: String, kind: String, price: int) -> Dictionary:
		paid.append([id, kind, price])
		return {"ok": true, "duplicate": false}
	return paid


func drain(model) -> void:
	for frame in range(800):
		if not model.powerup_active():
			break
		model.step(0.025)
	check(not model.powerup_active(), "Every accepted bounded path finishes without leaving a partial operation")


func _test_exact_capacities() -> void:
	var previous_price := 0
	for level in range(1, 10):
		var capacity: int = level + 2
		check(Economy.auto_merge_capacity(level) == capacity, "Every level adds exactly one participating Jelly")
		if level > 1:
			var price: int = Economy.permanent_upgrade_price("auto_merge", level)
			check(price > previous_price and price % 25 == 0, "Every permanent upgrade costs strictly more saved coins")
			previous_price = price
		var model = fixture(level, capacity + 3)
		var original: Dictionary = {}
		var fragments := 0
		for tile: Dictionary in model.cells:
			original[int(tile.id)] = true
			fragments += int(tile.fragments)
		var used: Dictionary = {}
		model.powerup_drag_started.connect(func(drag: Dictionary) -> void:
			for key: String in ["source_id", "target_id"]:
				if original.has(int(drag[key])):
					used[int(drag[key])] = true)
		var paid: Array = payments(model)
		check(model.activate_powerup("auto_merge"), "A funded legal Auto merge starts at every owned level")
		drain(model)
		var state: Dictionary = model.powerup_snapshot()
		check(used.size() == capacity and state.affected_jellies == capacity and state.capacity == capacity,
			"Lv%d consumes exactly %d original board Jellies, not %d pairs" % [level, capacity, capacity])
		check(model.cells.size() == 4 and model.merged_count == capacity - 1,
			"Generated results are reusable without counting as new input Jellies")
		var remaining_fragments := 0
		for tile: Dictionary in model.cells:
			remaining_fragments += int(tile.fragments)
		check(remaining_fragments == fragments and model.cleared_pairs == 0 and model.collected_coins == 0,
			"Capacity limiting preserves all carried fragments and never collects or grants pickup income")
		check(paid.size() == 1 and paid[0][1] == "auto_merge" and paid[0][2] == 600
			and model.powerup_price("auto_merge") == 900,
			"Permanent capacity does not change the existing per-round use-price policy")
		check(model.snapshot().auto_merge_level == level and model.snapshot().auto_merge_capacity == capacity,
			"The public game snapshot advertises the same level and capacity that actually executed")
		model.purchase_powerup = Callable()


func authored_word(triple: bool) -> Dictionary:
	var text: String = "unhelpful" if triple else "rainbow"
	var parts: Array = [{"id": "a", "canonical_id": "fixture:un" if triple else "fixture:rain",
		"type": "prefix" if triple else "root", "canonical": "un-" if triple else "rain",
		"surface": "un-" if triple else "rain"},
		{"id": "b", "canonical_id": "fixture:help" if triple else "fixture:bow",
			"type": "root", "canonical": "help" if triple else "bow", "surface": "help" if triple else "bow"}]
	var nodes: Array = [{"id": "whole", "left": "a", "right": "b", "surface": text, "rule": "test_authored_join"}]
	if triple:
		parts.append({"id": "c", "canonical_id": "fixture:ful", "type": "suffix",
			"canonical": "-ful", "surface": "-ful"})
		nodes = [{"id": "helpful", "left": "b", "right": "c", "surface": "helpful", "rule": "test_authored_join"},
			{"id": "whole", "left": "a", "right": "helpful", "surface": text, "rule": "test_authored_join"}]
	return {"id": text, "text": text, "min_age": 3, "image": word.image, "audio": "fixture:" + text,
		"morphology": {"schema": 1, "id": "fixture:auto:" + text, "lexeme_id": text, "text": text,
			"kind": "morphological", "review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
			"parts": parts, "nodes": nodes, "roots": ["whole"]}}


func _test_complete_authored_paths() -> void:
	for triple: bool in [false, true]:
		var authored: Dictionary = authored_word(triple)
		var model := Model.new()
		check(model.configure([authored], 3, 91), "Use an explicitly authored multipart test fixture")
		model.cells.clear()
		model.spawn_interval = 10000.0
		for part: Dictionary in model._morphology.source_tiles(str(authored.morphology.id)):
			model.cells.append(model._new_composition_tile(part))
		model.cells.append(model._new_picture_tile(authored))
		settle_board(model)
		var paid: Array = payments(model)
		var before: Array = model.cells.duplicate(true)
		if triple:
			check(not model.can_activate_powerup("auto_merge") and not model.activate_powerup("auto_merge")
				and paid.is_empty() and model.cells == before,
				"A four-input word cannot charge Lv1 and leave an incomplete spelling behind")
			model.auto_merge_level = 2
		check(model.activate_powerup("auto_merge"), "A complete authored word fits the real input budget")
		drain(model)
		check(model.collectable_ids().size() == 1 and model.cells.size() == 1
			and model.powerup_snapshot().affected_jellies == (4 if triple else 3),
			"Root joins and their final picture consume the exact original count, not the number of animation steps")
		model.purchase_powerup = Callable()


func _test_family_is_independent() -> void:
	var model = fixture(1, 7)
	var paid: Array = payments(model)
	check(model.activate_family_merge("cat"), "Paid goal-family merging is still available at Auto merge Lv1")
	drain(model)
	check(model.cells.size() == 1 and model.merged_count == 6 and paid.size() == 1 and paid[0][2] == 50,
		"The new Auto merge budget does not cap goal-family purchases or their distinct price")
	model.purchase_powerup = Callable()


func _test_badge_geometry() -> void:
	var button := ButtonView.new()
	root.add_child(button)
	for scale_value: float in [0.65, 1.0, 1.5, 2.45, 3.2]:
		for dimensions: Vector2 in [Vector2(88, 44), Vector2(144, 44), Vector2(184, 56), Vector2(369, 56)]:
			button.set_ui_scale(scale_value, dimensions.y == 44)
			button.size = dimensions / scale_value
			for level in [1, 2, 9]:
				button.set_auto_merge_level(level)
				var state: Dictionary = button.snapshot()
				var badge: Array = state.capacity_badge.rect
				var area := Rect2(badge[0], badge[1], badge[2], badge[3])
				check(state.capacity == level + 2 and state.auto_merge_level == level
					and state.capacity_badge.text == str(level + 2) and state.capacity_badge.visible,
					"The visible badge always shows actual capacity, including the two-digit maximum")
				check(Rect2(Vector2.ZERO, button.size).grow(0.01).encloses(area),
					"The capacity badge stays inside the stable control at every supported scale")
				for key: String in ["title_rect", "price_rect", "coin_rect"]:
					var values: Array = state[key]
					check(not area.grow(-0.02).intersects(Rect2(values[0], values[1], values[2], values[3])),
						"Capacity never covers the name or exact coin price")
				check(state.accessibility_name.contains("Up to %d board Jellies" % (level + 2)),
					"Screen readers receive capacity rather than only the decorative number")
				check(button._title.get_theme_font_size("font_size") >= 11
					and button._price_label.get_theme_font_size("font_size") >= 11,
					"The badge does not buy space by shrinking the name or exact price below readable display type")
	button.configure("family_merge", 50, true)
	check(not button.snapshot().capacity_badge.visible, "Goal-family buttons never inherit the Auto merge badge")
	button.free()


func _run() -> void:
	_test_exact_capacities()
	_test_complete_authored_paths()
	_test_family_is_independent()
	_test_badge_geometry()
	print("Auto merge permanent capacity: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
