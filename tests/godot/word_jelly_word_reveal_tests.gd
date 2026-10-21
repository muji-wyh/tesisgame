extends SceneTree

const Reveal = preload("res://scripts/word_jelly_word_reveal.gd")
const WordArt = preload("res://scripts/word_art.gd")

var checks: int = 0
var failures: int = 0
var apple: Texture2D
var cat: Texture2D


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var reveal := Reveal.new()
	root.add_child(reveal)
	reveal._rng.seed = 4821
	apple = WordArt.texture("assets/images/word-library/apple.webp")
	cat = WordArt.texture("assets/images/word-library/cat.webp")
	check(not reveal.snapshot().visible and reveal.snapshot().entries.is_empty()
		and int(reveal.snapshot().active_count) == 0, "the reading layer starts empty")
	await _check_independent_lifetimes(reveal)
	_check_layouts(reveal)
	_check_varied_content_cards(reveal)
	_check_elastic_entry(reveal)
	_check_reduced_motion(reveal)
	reveal.reset()
	reveal.present({"id": "image-free", "text": "on"}, null, Color.WHITE)
	check(reveal.snapshot().visible and reveal.snapshot().spelling == "on" and reveal.snapshot().picture.is_empty(),
		"Image-free words present their full spelling without a phantom picture")
	reveal.queue_free()
	await process_frame
	print("Word Jelly word reveal: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _present(reveal, text: String, picture: Texture2D = null, batch: bool = false) -> void:
	reveal.present({"id": text, "text": text}, apple if picture == null else picture, Color("#598c6c"), batch)


func _check_independent_lifetimes(reveal) -> void:
	reveal.reset()
	reveal.configure_layout(Rect2(22, 14, 900, 180), 1.0)
	await process_frame
	var baseline_children: int = reveal.get_child_count()
	_present(reveal, "apple")
	reveal.advance(0.10)
	var first: Dictionary = reveal.snapshot().entries[0].duplicate(true)
	_present(reveal, "cat", cat)
	check(reveal.snapshot().entries[0] == first, "adding another word leaves the prior card and timeline unchanged")
	reveal.advance(0.10)
	_present(reveal, "apple")
	var state: Dictionary = reveal.snapshot()
	check(int(state.active_count) == 3 and state.entries.size() == 3,
		"three rapid pickups coexist, including a repeated spelling")
	var entry_ids: Array = []
	for index in range(3):
		var entry: Dictionary = state.entries[index]
		entry_ids.append(entry.entry_id)
		check(str(entry.word_id) == ["apple", "cat", "apple"][index]
			and is_equal_approx(float(entry.elapsed), (2 - index) * 0.10),
			"each visible word retains its own content and 100 ms collection age")
		check(str(entry.picture).ends_with("cat.webp" if index == 1 else "apple.webp"),
			"concurrent entries keep their original production artwork")
	check(entry_ids[0] != entry_ids[1] and entry_ids[1] != entry_ids[2] and entry_ids[0] != entry_ids[2],
		"repeated spellings have distinct presentation identities")
	check(state.word_id == "apple" and state.elapsed == 0.0 and state.spelling == "apple",
		"legacy reveal fields describe the newest entry")
	var before: Dictionary = state.duplicate(true)
	for delta: float in [-1.0, NAN, INF, 0.0]:
		reveal.advance(delta)
	check(reveal.snapshot().entries == before.entries, "invalid time steps leave every entry unchanged")
	reveal.present({"id": "missing", "text": ""}, null, Color.WHITE)
	reveal.present({"id": "blank", "text": "  "}, apple, Color.WHITE)
	check(reveal.snapshot().entries == before.entries,
		"Empty spelling cannot erase unrelated collected words")
	var duration: float = float(state.duration)
	reveal.advance(duration - 0.21)
	state = reveal.snapshot()
	check(int(state.active_count) == 3 and float(state.entries[0].content_alpha) < 0.2,
		"the oldest card reaches its own fade while younger cards remain alive")
	reveal.advance(0.02)
	state = reveal.snapshot()
	check(int(state.active_count) == 2 and state.entries.size() == 2
		and state.entries[0].word_id == "cat" and state.entries[1].word_id == "apple",
		"only the oldest entry disappears at its lifetime boundary")
	check(is_equal_approx(float(state.entries[0].elapsed), duration - 0.09)
		and is_equal_approx(float(state.entries[1].elapsed), duration - 0.19),
		"expiry never resets or accelerates either younger timeline")
	reveal.advance(0.10)
	check(int(reveal.snapshot().active_count) == 1 and reveal.snapshot().word_id == "apple",
		"the middle entry expires separately while the latest word stays visible")
	reveal.advance(0.10)
	state = reveal.snapshot()
	check(not state.visible and int(state.active_count) == 0 and state.entries.is_empty()
		and str(state.picture).is_empty() and str(state.spelling).is_empty(),
		"the final expiry releases all pictures and empties the reading layer")
	await process_frame
	check(reveal.get_child_count() == baseline_children, "expired entry nodes leave no hidden child accumulation")
	for text: String in ["apple", "cat", "apple"]:
		_present(reveal, text, cat if text == "cat" else apple)
	reveal.reset()
	reveal.advance(0.5)
	check(not reveal.snapshot().visible and reveal.snapshot().entries.is_empty()
		and int(reveal.snapshot().active_count) == 0, "reset removes all active words without restoring them later")
	await process_frame
	check(reveal.get_child_count() == baseline_children, "reset frees every concurrent entry node")
	_present(reveal, "apple")
	_present(reveal, "cat", cat, true)
	var mixed: Dictionary = reveal.snapshot()
	check(float(mixed.entries[1].duration) < float(mixed.entries[0].duration),
		"batch cards use a shorter reading beat without replacing a manual pickup")
	reveal.advance(float(mixed.entries[1].duration) + 0.01)
	check(int(reveal.snapshot().active_count) == 1 and reveal.snapshot().word_id == "apple",
		"a younger batch card can expire before a still-living manual card")
	var existing: Array = reveal.snapshot().entries.duplicate(true)
	reveal.present({"id": "cat", "text": "cat"}, cat, Color.WHITE, true, float(mixed.entries[1].duration) + 0.01)
	check(reveal.snapshot().entries == existing,
		"a catch-up age beyond the new card's lifetime cannot append an expired reveal")


func _check_layouts(reveal) -> void:
	for scale_factor: float in [0.75, 1.0, 1.5]:
		for area: Rect2 in [Rect2(22, 14, 900, 180), Rect2(14, 8, 362, 160), Rect2(12, 6, 620, 90), Rect2(8, 6, 250, 115)]:
			for batch: bool in [false, true]:
				_check_layout_case(reveal, area, scale_factor, batch)


func _check_layout_case(reveal, area: Rect2, scale_factor: float, batch: bool) -> void:
	reveal.reset()
	reveal.set_reduced_motion(false)
	reveal.configure_layout(area, scale_factor)
	for text: String in ["cat", "hippopotamus", "ice cream"]:
		_present(reveal, text, cat if text == "cat" else apple, batch)
		reveal.advance(0.10)
	for tick in range(16 if batch else 28):
		_check_bounds(reveal, area)
		reveal.advance(0.025)
	_check_input(reveal)
	_check_labels(reveal)
	var before: Array = reveal.snapshot().entries.duplicate(true)
	reveal.configure_layout(area, scale_factor)
	check(reveal.snapshot().entries == before, "repeating a layout pass cannot reroll placement, scale or time")
	var resized := Rect2(5, 8, 310, 115)
	reveal.configure_layout(resized, scale_factor)
	var after: Array = reveal.snapshot().entries
	check(after.size() == before.size(), "resizing retains every concurrent entry")
	for index in range(after.size()):
		check(after[index].entry_id == before[index].entry_id
			and is_equal_approx(float(after[index].elapsed), float(before[index].elapsed)),
			"resizing preserves each word and its independent reading age")
	_check_bounds(reveal, resized)
	_check_labels(reveal)


func _check_varied_content_cards(reveal) -> void:
	reveal.reset()
	reveal._rng.seed = 4821
	reveal.set_reduced_motion(true)
	var area := Rect2(20, 12, 980, 260)
	reveal.configure_layout(area, 1.0)
	var centers: Array[Vector2] = []
	var scales: Array[float] = []
	for index in range(12):
		_present(reveal, "cat", cat)
		centers.append(_rect(reveal.snapshot().resting_rect).get_center())
		scales.append(float(reveal.snapshot().variant_scale))
		reveal.advance(0.025)
	check(reveal.snapshot().entries.size() == 12, "a rapid run keeps every still-living collection card")
	var distinct_centers: Array[Vector2] = []
	for center: Vector2 in centers:
		if not distinct_centers.has(center):
			distinct_centers.append(center)
	check(distinct_centers.size() >= 3, "repeated words use varied upper-screen positions")
	check(float(scales.max()) > float(scales.min()) * 1.05, "repeated words receive visibly varied resting scales")
	_check_bounds(reveal, area)
	reveal.reset()
	_present(reveal, "cat", cat)
	var short: Dictionary = reveal.snapshot()
	_present(reveal, "hippopotamus")
	var long: Dictionary = reveal.snapshot()
	var short_width: float = _rect(short.resting_rect).size.x / float(short.variant_scale)
	var long_width: float = _rect(long.resting_rect).size.x / float(long.variant_scale)
	check(long_width > short_width * 1.1, "the long spelling gets a wider content-sized card independent of random scale")
	check(_rect(short.resting_rect).size.x < area.size.x * 0.5 and _rect(long.resting_rect).size.x < area.size.x * 0.75,
		"content-sized cards leave upper-screen room for concurrent words")
	_check_labels(reveal)


func _check_elastic_entry(reveal) -> void:
	reveal.reset()
	reveal.set_reduced_motion(false)
	var area := Rect2(20, 12, 900, 220)
	reveal.configure_layout(area, 1.0)
	_present(reveal, "apple")
	var initial: Dictionary = reveal.snapshot()
	check(_rect(initial.rect).size.x < _rect(initial.resting_rect).size.x * 0.80,
		"the elastic entrance begins clearly smaller than its resting card")
	var largest: float = 0.0
	var contracted_after_peak: bool = false
	for tick in range(40):
		reveal.advance(0.025)
		var entry: Dictionary = reveal.snapshot()
		var ratio: float = _rect(entry.rect).size.x / _rect(entry.resting_rect).size.x
		largest = maxf(largest, ratio)
		contracted_after_peak = contracted_after_peak or (largest > 1.08 and ratio < 0.99)
		_check_bounds(reveal, area)
	check(largest > 1.08 and contracted_after_peak, "the entry visibly overshoots and recoils before settling")
	check(absf(_rect(reveal.snapshot().rect).size.x / _rect(reveal.snapshot().resting_rect).size.x - 1.0) < 0.02,
		"elastic motion settles onto the sampled resting scale")


func _check_reduced_motion(reveal) -> void:
	for enabled_before: bool in [false, true]:
		reveal.reset()
		reveal.configure_layout(Rect2(18, 10, 760, 190), 1.0)
		reveal.set_reduced_motion(enabled_before)
		_present(reveal, "apple")
		reveal.advance(0.10)
		_present(reveal, "cat", cat)
		reveal.advance(0.10)
		reveal.set_reduced_motion(true)
		var before: Array = reveal.snapshot().entries.duplicate(true)
		reveal.advance(0.40)
		var after: Array = reveal.snapshot().entries
		check(after.size() == 2, "changing the motion preference preserves every active reveal")
		for index in range(after.size()):
			check(after[index].rect == before[index].rect and after[index].resting_rect == before[index].resting_rect,
				"reduced motion keeps every sampled card position and scale completely still")
			check(is_equal_approx(float(after[index].elapsed), float(before[index].elapsed) + 0.40)
				and float(after[index].content_alpha) == 1.0,
				"static reveals keep independent lifetimes and a clear reading beat")
		_check_static_decorations(reveal)
		reveal.advance(float(reveal.snapshot().duration))
		check(not reveal.snapshot().visible and reveal.snapshot().entries.is_empty(),
			"reduced-motion reveals still expire normally")


func _check_bounds(reveal, area: Rect2) -> void:
	var state: Dictionary = reveal.snapshot()
	check(int(state.active_count) == state.entries.size(), "the active count matches all rendered reveal entries")
	for entry: Dictionary in state.entries:
		var panel: Rect2 = _rect(entry.rect)
		check(area.grow(0.1).encloses(panel), "every elastic card remains bounded by the upper region")
		check(panel.grow(0.1).encloses(_rect(entry.picture_rect)) and panel.grow(0.1).encloses(_rect(entry.spelling_rect)),
			"picture and complete spelling stay inside their own card: %s age %.3f panel %s picture %s spelling %s" % [
				entry.spelling, entry.elapsed, panel, _rect(entry.picture_rect), _rect(entry.spelling_rect)])
		check(_rect(entry.picture_rect).end.x <= _rect(entry.spelling_rect).position.x,
			"artwork and spelling retain separate reading space")
		var json: Dictionary = JSON.parse_string(JSON.stringify(entry))
		check(json.rect is Array and json.picture_rect is Array and json.spelling_rect is Array and json.resting_rect is Array,
			"each entry exposes numeric rectangle coordinates to the browser")


func _check_labels(node: Node) -> void:
	for child: Node in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Label:
			var font: Font = child.get_theme_font("font")
			var pixels: int = child.get_theme_font_size("font_size")
			check(child.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "each full spelling remains available without ellipsis")
			check(font.get_string_size(child.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= child.size.x + 0.1
				and font.get_height(pixels) <= child.size.y + 0.1,
				"short, long and multiword spellings fit their content-sized label")
		_check_labels(child)


func _check_static_decorations(node: Node) -> void:
	for child: Node in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is TextureRect and child.texture != null and (child.texture.resource_path.ends_with("portal_glow.png")
			or child.texture.resource_path.ends_with("sparkle.png")):
			check(not child.visible, "reduced motion suppresses every aura and moving glint")
		_check_static_decorations(child)


func _check_input(node: Node) -> void:
	for child: Node in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Control:
			check(child.mouse_filter == Control.MOUSE_FILTER_IGNORE, "every concurrent reveal child passes pointer input to the game")
		_check_input(child)


func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
