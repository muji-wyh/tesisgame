extends SceneTree

var checks := 0
var failures := 0
var coverage := {2: {"aligned": false, "offset": false}, 4: {"aligned": false, "offset": false}}


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func global_path(link) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in link.path:
		result.append(link.get_global_transform() * point)
	return result


func same_path(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	if first.size() != second.size():
		return false
	for index in range(first.size()):
		if not first[index].is_equal_approx(second[index]):
			return false
	return true


func facing_boundary(bounds: Rect2, other_center: Vector2) -> Vector2:
	var corners := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y),
		bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	for edge in range(4):
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			bounds.get_center(), other_center, corners[edge], corners[(edge + 1) % 4])
		if intersection != null:
			return intersection
	return Vector2(INF, INF)


func check_link(app, image_id: String, word_id: String, columns: int, stage: String) -> void:
	var link = app._hint_link
	check(app.grid.columns == columns, stage + ": the real board uses the expected column count")
	check(link.active and link.is_visible_in_tree() and link.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		stage + ": the active link stays visible without blocking card input")
	check(link.source == app.cards[image_id] and link.target == app.cards[word_id],
		stage + ": direction always runs from picture to word, regardless of hint order")
	var points: PackedVector2Array = global_path(link)
	check(points.size() == 2, stage + ": one direct segment joins the cards without gutter detours")
	if points.size() != 2:
		return
	var picture: Rect2 = app.cards[image_id].get_global_rect()
	var word: Rect2 = app.cards[word_id].get_global_rect()
	var first: Vector2 = points[0]
	var last: Vector2 = points[1]
	var axis: Vector2 = (word.get_center() - picture.get_center()).normalized()
	var pixel_scale: float = app.Style.ui_scale(link)
	check(picture.has_point(first) and word.has_point(last),
		stage + ": the electricity reaches inside both intended cards")
	check(absf((first - picture.get_center()).cross(axis)) * pixel_scale <= 0.5
		and absf((last - word.get_center()).cross(axis)) * pixel_scale <= 0.5,
		stage + ": both endpoints lie on the picture-to-word center axis")
	check((first - picture.get_center()).dot(axis) > 0.0
		and (word.get_center() - last).dot(axis) > 0.0 and (last - first).dot(axis) > 0.0,
		stage + ": the segment connects the facing halves of the cards in picture-to-word order")
	var picture_edge: Vector2 = facing_boundary(picture, word.get_center())
	var word_edge: Vector2 = facing_boundary(word, picture.get_center())
	check(picture_edge.is_finite() and word_edge.is_finite(),
		stage + ": the center ray crosses both card boundaries")
	check(absf(first.distance_to(picture_edge) * pixel_scale - 18.0) <= 1.0
		and absf(last.distance_to(word_edge) * pixel_scale - 18.0) <= 1.0,
		stage + ": endpoints extend about 18 screen pixels inside each facing boundary")
	var board: Rect2 = app._match_playfield.get_global_rect().grow(1.0)
	check(board.has_point(first) and board.has_point(last), stage + ": the direct link remains inside the board")
	var offset: float = picture.get_center().y - word.get_center().y if columns == 2 else picture.get_center().x - word.get_center().x
	coverage[columns]["aligned" if absf(offset) <= 1.0 else "offset"] = true


func round_state(app) -> Array:
	return [app.model.cards.duplicate(true), app.model.lesson_words.duplicate(true),
		app.model.hint_ids.duplicate(), app.model.hints_remaining, app.model.phase, app.model.selected_id,
		app.model.matched_ids.duplicate(), app.model.successes, app.model.mistakes, app.model.streak]


func card_appearance(card) -> Array:
	var normal: StyleBoxFlat = card.get_theme_stylebox("normal")
	var disabled_style: StyleBoxFlat = card.get_theme_stylebox("disabled")
	return [normal.bg_color, normal.border_color, disabled_style.bg_color, disabled_style.border_color,
		card.match_mark.visible, card.disabled]


func hue_distance(first: Color, second: Color) -> float:
	var difference: float = absf(first.h - second.h)
	return minf(difference, 1.0 - difference)


func check_theme_switches(app) -> void:
	app.new_round(21, false, "", "match")
	await settle()
	app._request_hint()
	await settle()
	var hinted: Array = app.model.hint_ids.duplicate()
	check(hinted.size() == 2 and app.model.hints_remaining == 2, "Theme switching starts with one real, paid hint")
	if hinted.size() != 2:
		return
	var link = app._hint_link
	var original_state: Array = round_state(app)
	var original_path: PackedVector2Array = global_path(link)
	var original_source: Control = link.source
	var original_target: Control = link.target
	var palettes: Dictionary = {}
	var currents: Array[Color] = []
	var probe = app.Card.new()
	probe.setup(app.model.cards[0])
	probe.set_reduced_motion(true)
	for theme_id in ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy", "spring"]:
		app.choose_theme(theme_id)
		await settle()
		var palette: Dictionary = app.Data.theme(theme_id)
		var valid_colors: bool = ["edge", "current", "core", "spark", "fill", "border"].all(
			func(key: String) -> bool: return link.colors.get(key) is Color)
		check(valid_colors and link.colors == app.Style.hint_palette(palette),
			theme_id + ": the active arc receives the current theme's complete shared palette")
		if not valid_colors:
			continue
		var current: Color = link.colors.current
		var spark: Color = link.colors.spark
		check(hue_distance(current, palette.accent) < 0.035 and current.v > palette.accent.v,
			theme_id + ": the electric current keeps the theme's primary hue with a brighter charge")
		check(hue_distance(spark, palette.spark) < 0.035 and not spark.is_equal_approx(current),
			theme_id + ": fork sparks use the theme's distinct secondary color")
		for id in hinted:
			var style: StyleBoxFlat = app.cards[id].get_theme_stylebox("normal")
			check(style.bg_color == link.colors.fill and style.border_color == link.colors.border
				and not app.cards[id].match_mark.visible,
				theme_id + ": both hinted cards share the arc's themed treatment without showing success")
		probe.refresh(palette, false, false, false, false, false)
		var ordinary: StyleBoxFlat = probe.get_theme_stylebox("normal")
		check(ordinary.bg_color != link.colors.fill and ordinary.border_color != link.colors.border,
			theme_id + ": the theme's hinted cards remain distinguishable from ordinary cards")
		for state in ["selected", "matched", "wrong"]:
			probe.refresh(palette, state == "selected", state == "matched", state == "wrong", false, false)
			var before: Array = card_appearance(probe)
			probe.refresh(palette, state == "selected", state == "matched", state == "wrong", false, true)
			check(card_appearance(probe) == before,
				theme_id + ": hint styling cannot replace a card's " + state + " feedback")
		check(app.model.theme_id == theme_id and round_state(app) == original_state
			and app._hint_link == link and link.source == original_source and link.target == original_target,
			theme_id + ": switching theme preserves the paid hint, card instances and round progress")
		check(link.active and link.is_visible_in_tree() and not link.is_processing()
			and same_path(global_path(link), original_path),
			theme_id + ": switching theme keeps the same direct geometry and reduced-motion behavior")
		if palettes.has(theme_id):
			check(link.colors == palettes[theme_id], "Returning to Spring restores its original electric colors")
		else:
			palettes[theme_id] = link.colors.duplicate()
			currents.append(current)
	check(palettes.size() == 8 and currents.all(func(color: Color) -> bool: return currents.count(color) == 1),
		"All eight worlds have a distinct electric primary color instead of sharing the old blue")
	probe.free()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 900)
	var directory := "user://hint-link-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	for seed_value in range(8):
		app.new_round(seed_value, false, "", "match")
		await settle()
		check(app.grid.get_child_count() == 8 and app._hint_link is Control,
			"The real board keeps eight cards and one independent link control")
		for data in app.model.cards:
			var word_id: String = data.word.id + ":word"
			if data.kind != "image" or not app.cards.has(word_id):
				continue
			var image_id: String = data.id
			root.size = Vector2i(480, 900)
			app.model.hint_ids.assign([word_id, image_id])
			app.model.changed.emit()
			await settle()
			var stage: String = "Seed %d %s" % [seed_value, data.word.id]
			check_link(app, image_id, word_id, 2, stage + " portrait, reversed hint")
			var portrait_path: PackedVector2Array = global_path(app._hint_link)
			app.model.hint_ids.assign([image_id, word_id])
			app.model.changed.emit()
			await settle()
			check(same_path(global_path(app._hint_link), portrait_path),
				stage + ": swapping hint order leaves the picture-to-word geometry unchanged")
			var image_instance: int = app.cards[image_id].get_instance_id()
			var word_instance: int = app.cards[word_id].get_instance_id()
			root.size = Vector2i(900, 480)
			await settle()
			check_link(app, image_id, word_id, 4, stage + " landscape after resize")
			check(app.model.hint_ids == [image_id, word_id]
				and app.cards[image_id].get_instance_id() == image_instance
				and app.cards[word_id].get_instance_id() == word_instance,
				stage + ": resize preserves the active hint and both existing cards")
			check(not same_path(global_path(app._hint_link), portrait_path),
				stage + ": resize updates endpoints automatically without manually refreshing geometry")
		if coverage[2].aligned and coverage[2].offset and coverage[4].aligned and coverage[4].offset:
			break
	for columns in [2, 4]:
		check(coverage[columns].aligned and coverage[columns].offset,
			"%d-column fixtures cover both aligned pairs and pairs in different rows or columns" % columns)
	await check_theme_switches(app)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Hint link geometry: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
