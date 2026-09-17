extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(4):
		await process_frame


func contrast(first: Color, second: Color) -> float:
	var a := first.srgb_to_linear()
	var b := second.srgb_to_linear()
	var x := 0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b
	var y := 0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b
	return (maxf(x, y) + 0.05) / (minf(x, y) + 0.05)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1100, 1000)
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json")).slice(0, 5)
	var view = load("res://scripts/memory_garden.gd").new()
	root.add_child(view)
	view.size = Vector2(744, 900)
	view.set_reduced_motion(true)
	view.start_round(words, Data.theme("spring"), 23)
	await settle()
	var back: Control = view.card_buttons[0].find_child("CardBack", true, false)
	check(back.has_method("set_palette"), "Memory backs expose their themed graphical presentation")
	if not back.has_method("set_palette"):
		view.queue_free()
		await process_frame
		quit(1)
		return
	var original: Array = view.memory.cards.duplicate(true)
	var nodes: Array = view.card_buttons.map(func(card: Button) -> int: return card.get_instance_id())
	for theme_id in Data.THEMES:
		var palette: Dictionary = Data.theme(theme_id)
		view.set_palette(palette)
		await settle()
		back = view.card_buttons[0].find_child("CardBack", true, false)
		var changes := [0]
		var changed := func() -> void: changes[0] += 1
		back.kind_label.theme_changed.connect(changed)
		back.set_palette(palette)
		await settle()
		check(changes[0] == 0, "An unchanged Memory palette does not re-invalidate caption styling")
		back.kind_label.theme_changed.disconnect(changed)
		for dimensions in [Vector2(296, 200), Vector2(296, 480), Vector2(374, 680), Vector2(456, 300), Vector2(820, 300), Vector2(744, 948), Vector2(1040, 680)]:
			view.size = dimensions
			await settle()
			var colors: Dictionary = {}
			for index in range(10):
				var card = view.card_buttons[index]
				back = card.find_child("CardBack", true, false)
				var kind: String = view.memory.cards[index].kind
				check(back.is_visible_in_tree() and not card.picture.visible and card.word_label.text.is_empty(),
					"The redesigned back never exposes its concealed word or picture")
				check(back.kind_label.text == ("Word" if kind == "word" else "Picture")
					and back.number_label.text == str(index + 1), "Kind and position remain explicit")
				check(back.fill_color != Color.WHITE and contrast(back.kind_label.get_theme_color("font_color"), back.fill_color) >= 4.5,
					"Each themed back has a deliberate surface with readable text")
				colors[kind] = back.fill_color
				for label in [back.kind_label, back.number_label, back.symbol_label]:
					if label.is_visible_in_tree():
						var font: Font = label.get_theme_font("font")
						var font_size: int = label.get_theme_font_size("font_size")
						check(back.get_global_rect().grow(0.5).encloses(label.get_global_rect()),
							"Back text stays inside the card at " + str(dimensions))
						check(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x + 0.5,
							"The complete back caption fits without clipping")
				check(not back.kind_label.get_global_rect().intersects(back.number_label.get_global_rect()),
					"Small corner numbers do not collide with the kind caption")
				if back.symbol_label.is_visible_in_tree():
					check(back.symbol_label.text == "Aa" and not back.symbol_label.get_global_rect().intersects(back.kind_label.get_global_rect())
						and not back.symbol_label.get_global_rect().intersects(back.number_label.get_global_rect()),
						"Large Aa lettering has its own clear space at %s: symbol=%s kind=%s number=%s planned=%s font=%d minimum=%s height=%s" % [
							dimensions, back.symbol_label.get_rect(), back.kind_label.get_rect(), back.number_label.get_rect(),
							back._symbol_rect, back.symbol_label.get_theme_font_size("font_size"), back.symbol_label.get_minimum_size(),
							back.symbol_label.get_theme_font("font").get_height(back.symbol_label.get_theme_font_size("font_size"))])
				check(back.find_children("*", "TextureRect", true, false).is_empty(),
					"Generic back graphics never load the matching noun's artwork")
				check(view.get_global_rect().grow(0.5).encloses(card.get_global_rect()),
					"Card positions and hit targets stay inside the existing board")
			check(colors.size() == 2 and colors.image != colors.word,
				"Picture and word backs are visually distinct without revealing pair identity")
			check(view.memory.cards == original and view.card_buttons.map(func(card: Button) -> int: return card.get_instance_id()) == nodes,
				"Palette and viewport changes preserve every remembered card")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(480, 480)
	for dimensions in [Vector2i(320, 568), Vector2i(1366, 768), Vector2i(390, 844), Vector2i(1536, 1152)]:
		root.size = dimensions
		await settle()
		var scale: float = Style.ui_scale(view)
		view.size = root.get_visible_rect().size - Vector2(24, 140) / scale
		await settle()
		for card in view.card_buttons:
			back = card.find_child("CardBack", true, false)
			for label in [back.kind_label, back.number_label, back.symbol_label]:
				if label.is_visible_in_tree():
					check(back.get_global_rect().grow(0.5).encloses(label.get_global_rect()),
						"Back labels fit after CSS scaling changes: %s %s %s" % [dimensions, label.get_global_rect(), back.get_global_rect()])
			check(not back.kind_label.get_global_rect().intersects(back.number_label.get_global_rect()),
				"Scaled captions and corner numbers keep separate space")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1100, 1000)
	view.size = Vector2(744, 900)
	await settle()
	view.begin_peek()
	check(view.memory.studying and view.card_buttons.all(func(card: Button) -> bool:
		return not card.find_child("CardBack", true, false).is_visible_in_tree()), "Held Peek still reveals the true fronts")
	view.end_peek()
	check(not view.memory.studying and view.card_buttons.all(func(card: Button) -> bool:
		return card.find_child("CardBack", true, false).is_visible_in_tree()), "Releasing Peek restores the themed backs")
	var first: Dictionary = view.memory.cards[0]
	var partner := -1
	for index in range(1, 10):
		if view.memory.cards[index].word.id == first.word.id:
			partner = index
	view._choose(0)
	view._choose(partner)
	check(view.memory.last_correct and view.memory.matched_word_ids.size() == 1,
		"Redesigned cards still make an ordinary pair")
	view.continue_feedback()
	check(view.card_buttons[0].disabled and view.card_buttons[0].match_mark.visible,
		"Matched cards retain the existing planted state and completion mark")
	view.size = Vector2(296, 200)
	await settle()
	back = view.card_buttons[0].find_child("CardBack", true, false)
	check(not back.number_label.get_global_rect().intersects(view.card_buttons[0].match_mark.get_global_rect()),
		"A planted card's corner mark does not cover its stable position number")
	view.queue_free()
	await process_frame
	print("Memory back design: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
