extends SceneTree

const Reveal = preload("res://scripts/word_jelly_word_reveal.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
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
	_check_level_effects(reveal)
	_check_level_lifetimes(reveal)
	_check_batch_afterglow(reveal)
	_check_separate_firework_area(reveal)
	_check_firework_geometry(reveal)
	_check_source_centered_fireworks(reveal)
	_check_firework_trajectories()
	_check_firework_stamp_exclusions()
	await _check_delayed_reveal(reveal)
	reveal.reset()
	reveal.present({"id": "image-free", "text": "on"}, null, Color.WHITE)
	check(reveal.snapshot().visible and reveal.snapshot().spelling == "on" and reveal.snapshot().picture.is_empty(),
		"Image-free words present their full spelling without a phantom picture")
	reveal.queue_free()
	await process_frame
	print("Word Jelly word reveal: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _present(reveal, text: String, picture: Texture2D = null, batch: bool = false, level: int = 1) -> void:
	reveal.present({"id": text, "text": text}, apple if picture == null else picture, Color("#598c6c"), batch, 0.0, level)


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
	var spellings: Array[String] = ["cat", "hippopotamus", "ice cream"]
	for index in range(spellings.size()):
		var text: String = spellings[index]
		_present(reveal, text, cat if text == "cat" else apple, batch, [1, 4, 6][index])
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
		_present(reveal, "apple", apple, false, 4)
		reveal.advance(0.10)
		_present(reveal, "cat", cat, false, 6)
		reveal.advance(0.10)
		reveal.set_reduced_motion(true)
		var before: Array = reveal.snapshot().entries.duplicate(true)
		reveal.advance(0.40)
		var after: Array = reveal.snapshot().entries
		check(after.size() == 2, "changing the motion preference preserves every active reveal")
		for index in range(after.size()):
			check(after[index].rect == before[index].rect and after[index].resting_rect == before[index].resting_rect,
				"reduced motion keeps every sampled card position and scale completely still")
			check(bool(after[index].effects.reduced_motion) and after[index].effects.rect == before[index].effects.rect,
				"changing the motion preference keeps high-level effect footprints still")
			check(is_equal_approx(float(after[index].elapsed), float(before[index].elapsed) + 0.40)
				and float(after[index].content_alpha) == 1.0,
				"static reveals keep independent lifetimes and a clear reading beat")
		_check_static_decorations(reveal)
		reveal.advance(float(reveal.snapshot().duration))
		check(not reveal.snapshot().visible and reveal.snapshot().entries.is_empty(),
			"reduced-motion reveals still expire normally")


func _check_level_effects(reveal) -> void:
	reveal.configure_layout(Rect2(20, 12, 980, 260), 1.0)
	var profiles: Array[Dictionary] = []
	var patterns: Array[String] = []
	for level in range(1, Model.MAX_MERGE_LEVEL + 1):
		reveal.reset()
		reveal.set_reduced_motion(false)
		_present(reveal, "cat", cat, false, level)
		reveal.advance(0.12)
		var state: Dictionary = reveal.snapshot()
		var fx: Dictionary = state.effects
		check(int(state.merge_level) == level and int(fx.level) == level,
			"each reading pop retains the collected Jelly's level")
		check(not str(fx.name).is_empty() and not str(fx.pattern).is_empty(),
			"every level has a named effect treatment")
		check(bool(fx.input_transparent) and not bool(fx.reduced_motion),
			"level effects remain decorative during ordinary motion")
		check(int(fx.spark_count) > 0 and int(fx.burst_count) >= 0,
			"each level carries a nonempty sourced-particle effect")
		check(state.spelling == "cat" and str(state.picture).ends_with("cat.webp")
			and is_equal_approx(float(state.duration), Reveal.SECONDS),
			"higher-level decoration keeps the complete picture, spelling and reading lifetime")
		profiles.append(fx.duplicate(true))
		patterns.append(str(fx.pattern))
		_check_bounds(reveal, Rect2(20, 12, 980, 260))
		_check_input(reveal)
	check(patterns.size() == 9, "All nine merged-word levels receive a reading-pop treatment")
	for index in range(patterns.size()):
		check(patterns.count(patterns[index]) == 1, "Every available level has a distinct collection-pop choreography")
	check(str(profiles[3].pattern) == "fireworks", "Lv4 carries its fireworks identity into the reading pop")
	check(str(profiles[4].pattern) == "cascade" and str(profiles[5].pattern) == "bouquet",
		"Lv5 carries the double cascade and Lv6 carries the prismatic bouquet")
	check(str(profiles[6].pattern) == "aurora" and str(profiles[7].pattern) == "constellation"
		and str(profiles[8].pattern) == "grand_bouquet", "Lv7 through Lv9 have distinct crown, shower, and final bouquet treatments")
	check(int(profiles[5].spark_count) > int(profiles[3].spark_count)
		and int(profiles[3].spark_count) > int(profiles[0].spark_count),
		"collection-pop sparkle density grows from Lv1 through Lv4 to Lv6")
	for requested: int in [-10, 0, 1, 4, 6, 9, 20]:
		reveal.reset()
		_present(reveal, "apple", apple, false, requested)
		var clamped: int = clampi(requested, 1, Model.MAX_MERGE_LEVEL)
		check(int(reveal.snapshot().merge_level) == clamped and int(reveal.snapshot().effects.level) == clamped,
			"out-of-range level input clamps safely to the available effect tiers")


func _check_level_lifetimes(reveal) -> void:
	var area := Rect2(20, 12, 980, 260)
	reveal.configure_layout(area, 1.0)
	for batch: bool in [false, true]:
		for reduced: bool in [false, true]:
			reveal.reset()
			reveal.set_reduced_motion(reduced)
			var duration: float = Reveal.BATCH_SECONDS if batch else Reveal.SECONDS
			var cadence: float = Model.BATCH_BEAT_SECONDS if batch else 0.10
			var levels: Array[int] = [1, 4, 6]
			for index in range(levels.size()):
				if index > 0:
					reveal.advance(cadence)
				var prior: Array = reveal.snapshot().entries.duplicate(true)
				_present(reveal, "cat", cat, batch, levels[index])
				var entries: Array = reveal.snapshot().entries
				check(entries.size() == index + 1, "rapid mixed-level pickups retain every still-living pop")
				for earlier in range(prior.size()):
					check(entries[earlier] == prior[earlier],
						"a richer new pop cannot reroll a previous pop's content, identity or clock")
				check(int(entries[index].merge_level) == levels[index]
					and int(entries[index].effects.level) == levels[index]
					and bool(entries[index].effects.reduced_motion) == reduced,
					"manual and automatic collection retain the correct effect tier and motion preference")
			var before: Array = reveal.snapshot().entries.duplicate(true)
			reveal.configure_layout(Rect2(8, 6, 250, 115), 1.0)
			var after: Array = reveal.snapshot().entries
			for index in range(after.size()):
				check(after[index].entry_id == before[index].entry_id
					and after[index].effects.level == before[index].effects.level
					and is_equal_approx(float(after[index].elapsed), float(before[index].elapsed)),
					"resizing active level effects preserves identity and lifetime")
			_check_bounds(reveal, Rect2(8, 6, 250, 115))
			_check_input(reveal)
			reveal.advance(duration - cadence * 2.0 + 0.01)
			var survivors: Array = reveal.snapshot().entries
			check(survivors.size() == 2 and int(survivors[0].merge_level) == 4 and int(survivors[1].merge_level) == 6,
				"Lv1 expires on its original beat without clearing younger Lv4 and Lv6 effects")
			reveal.reset()
			check(reveal.get_child_count() == 0 and reveal.snapshot().effects.is_empty(),
				"reset releases every effect node and removes the last tier from the empty state")
			reveal.configure_layout(area, 1.0)
			for level: int in levels:
				var lifetime: float = Reveal.SECONDS if level >= 4 else duration
				reveal.present({"id": "cat", "text": "cat"}, cat, Color.WHITE, batch, lifetime - 0.04, level)
			var late: Array = reveal.snapshot().entries
			check(late.size() == 3, "a late frame creates the remaining tail for each live effect tier")
			for index in range(late.size()):
				check(int(late[index].merge_level) == levels[index] and float(late[index].content_alpha) < 0.15,
					"late-frame effects inherit the existing fade instead of restarting their flash")
			reveal.advance(0.05)
			check(not reveal.snapshot().visible and reveal.get_child_count() == 0,
				"late effect tails expire without retaining a particle subtree")
			reveal.present({"id": "cat", "text": "cat"}, cat, Color.WHITE, batch, Reveal.SECONDS + 0.01, 6)
			check(not reveal.snapshot().visible and reveal.get_child_count() == 0,
				"an already-expired Lv6 catch-up cannot replay its showcase")


func _check_batch_afterglow(reveal) -> void:
	var no_exclusions: Array[Rect2] = []
	var layouts: Array[Dictionary] = [
		{"area": Rect2(20, 12, 980, 260), "reading_seconds": 0.86},
		{"area": Rect2(14, 8, 362, 190), "reading_seconds": 0.62},
		{"area": Rect2(12, 6, 820, 110), "reading_seconds": 0.48},
	]
	for layout: Dictionary in layouts:
		for reduced: bool in [false, true]:
			for level: int in [4, 5, 6]:
				reveal.reset()
				reveal.set_reduced_motion(reduced)
				reveal.configure_layout(layout.area, 1.0)
				_present(reveal, "cat", cat, false, level)
				var manual: Dictionary = reveal.snapshot()
				var manual_fall: Vector2 = reveal._entries[0]._level_effects._firework_point(
					Vector2.ZERO, Vector2(0.6, -0.8), 60.0, 1.30, 1.72)
				reveal.reset()
				_present(reveal, "cat", cat, true, level)
				var start: Dictionary = reveal.snapshot()
				var reading_seconds: float = float(layout.reading_seconds)
				check(is_equal_approx(float(start.duration), reading_seconds)
					and is_equal_approx(float(start.effect_duration), float(manual.effect_duration)),
					"Automatic fireworks keep the manual lifetime without extending the layout's reading beat")
				check(start.effects.emission_seconds == manual.effects.emission_seconds
					and start.effects.trail_count == manual.effects.trail_count
					and int(start.effects.spark_count) < int(manual.effects.spark_count),
					"Automatic collection keeps complete staggered blooms and trails at reduced spark density")
				var batch_fall: Vector2 = reveal._entries[0]._level_effects._firework_point(
					Vector2.ZERO, Vector2(0.6, -0.8), 60.0, 1.30, 1.72)
				check(batch_fall.is_equal_approx(manual_fall),
					"Automatic falling embers follow the full manual descent rather than a shortened path")
				reveal.advance(reading_seconds - 0.02)
				check(reveal.snapshot().content_visible and float(reveal.snapshot().content_alpha) < 0.15,
					"The compact reading surface fades on its original layout-specific boundary")
				reveal.advance(0.04)
				var tail: Dictionary = reveal.snapshot()
				check(tail.visible and tail.active_count == 1 and not tail.content_visible
					and tail.phase == "afterglow" and tail.effects.visible and float(tail.content_alpha) == 0.0,
					"After the reading card disappears, its high-level fireworks remain independently visible")
				check(is_equal_approx(float(tail.effects.elapsed), float(tail.elapsed))
					and is_equal_approx(float(tail.effects.duration), float(tail.effect_duration)),
					"Lingering fireworks retain their original release age and full lifetime")
				reveal.set_reduced_motion(true)
				var still: Dictionary = reveal.snapshot()
				reveal.advance(0.10)
				var advanced: Dictionary = reveal.snapshot()
				check(not advanced.content_visible and advanced.effects.reduced_motion
					and advanced.rect == still.rect and advanced.effects.rect == still.effects.rect
					and is_equal_approx(float(advanced.elapsed), float(still.elapsed) + 0.10),
					"Reduced-motion afterglow remains stationary without restoring the expired reading card")
				reveal.set_reduced_motion(false)
				check(not reveal.snapshot().content_visible and reveal.snapshot().elapsed == advanced.elapsed,
					"Restoring motion resumes the existing tail without a new card or clock")
				var resized := Rect2(8, 6, 300, 125)
				var effect_area := Rect2(8, 6, 300, 220)
				reveal.configure_layout(resized, 1.0, no_exclusions, effect_area)
				check(reveal.snapshot().entry_id == tail.entry_id and reveal.snapshot().elapsed == advanced.elapsed
					and not reveal.snapshot().content_visible,
					"Resizing an afterglow preserves identity and age without resurrecting its text")
				_check_bounds(reveal, resized, effect_area)
				_check_input(reveal)
				reveal.advance(float(tail.effect_duration) - float(advanced.elapsed) - 0.01)
				check(reveal.snapshot().effects.visible and not reveal.snapshot().content_visible,
					"The presentation retains the final fade until the effect's own boundary")
				reveal.advance(0.02)
				check(not reveal.snapshot().visible and reveal.get_child_count() == 0,
					"The final afterglow releases its entire subtree at the effect boundary")
				reveal.configure_layout(layout.area, 1.0)
				var delay: float = Model.collection_pop_seconds(level, true)
				var age: float = reading_seconds + 0.12
				reveal.present({"id": "cat", "text": "cat"}, cat, Color.WHITE, true, delay + age, level, delay)
				var caught_up: Dictionary = reveal.snapshot()
				check(caught_up.visible and caught_up.effects.visible and not caught_up.content_visible
					and caught_up.phase == "afterglow" and is_equal_approx(float(caught_up.effects.elapsed), age),
					"A delayed frame after reading expiry catches up only the existing firework tail")
				reveal.reset()
				reveal.advance(3.0)
				check(not reveal.snapshot().visible and reveal.get_child_count() == 0,
					"Reset cancels caught-up afterglows without a later callback")


func _check_separate_firework_area(reveal) -> void:
	var reading_area := Rect2(24, 18, 760, 190)
	var effect_area := Rect2(24, 18, 760, 360)
	var exclusions: Array[Rect2] = [Rect2(26, 20, 60, 42), Rect2(700, 26, 76, 44)]
	for level: int in [3, 4, 5, 6]:
		for batch: bool in [false, true]:
			for reduced: bool in [false, true]:
				reveal.reset()
				reveal.set_reduced_motion(reduced)
				reveal.configure_layout(reading_area, 1.0, exclusions)
				reveal._rng.seed = 5831
				_present(reveal, "cat", cat, batch, level)
				reveal.advance(0.20)
				var original: Dictionary = reveal.snapshot()
				reveal.reset()
				reveal.configure_layout(reading_area, 1.0, exclusions, effect_area)
				reveal._rng.seed = 5831
				_present(reveal, "cat", cat, batch, level)
				reveal.advance(0.20)
				var expanded: Dictionary = reveal.snapshot()
				for key: String in ["rect", "resting_rect", "picture_rect", "spelling_rect", "font_size",
					"animated_scale", "variant_scale", "elapsed", "duration", "content_alpha"]:
					check(expanded[key] == original[key],
						"Extra room for falling fireworks preserves the original reading card's " + key)
				if level >= 4:
					check(_rect(expanded.effects.rect).is_equal_approx(effect_area),
						"High-level fireworks use the separately bounded falling area")
				else:
					check(expanded.effects.rect == original.effects.rect,
						"The wider firework canvas does not change ordinary collection effects")
				var card = reveal._entries[0]
				check(card._level_effects.z_index < card._visual.z_index,
					"Concurrent fireworks remain behind every card's reading surface")
				_check_bounds(reveal, reading_area, effect_area)
				_check_input(reveal)
				var before: Array = expanded.entries.duplicate(true)
				reveal.configure_layout(reading_area, 1.0, exclusions, effect_area)
				check(reveal.snapshot().entries == before,
					"Repeating both layout regions leaves placement and every effect clock untouched")
				if reduced:
					reveal.advance(0.10)
					var still: Dictionary = reveal.snapshot()
					check(still.rect == expanded.rect and still.effects.rect == expanded.effects.rect,
						"Reduced-motion cards and their wider effect footprint remain stationary")


func _check_firework_geometry(reveal) -> void:
	var no_exclusions: Array[Rect2] = []
	var layouts: Array[Dictionary] = [
		{"reading": Rect2(8, 8, 984, 272), "effects": Rect2(8, 8, 984, 410)},
		{"reading": Rect2(8, 8, 374, 272), "effects": Rect2(8, 8, 374, 432)},
		{"reading": Rect2(8, 8, 552, 184), "effects": Rect2(8, 8, 552, 184)},
	]
	var compact := Reveal.Card.LevelEffects.new()
	for layout: Dictionary in layouts:
		var display_radii: Dictionary = {}
		for scale_factor: float in [0.75, 1.0, 1.5]:
			var reading := Rect2(layout.reading.position / scale_factor, layout.reading.size / scale_factor)
			var canvas := Rect2(layout.effects.position / scale_factor, layout.effects.size / scale_factor)
			var manual_radii: Dictionary = {}
			for batch: bool in [false, true]:
				var previous_radius: float = 0.0
				for level: int in [4, 5, 6, 7, 8, 9]:
					reveal.reset()
					reveal.set_reduced_motion(false)
					reveal.configure_layout(reading, scale_factor, no_exclusions, canvas)
					_present(reveal, "cat", cat, batch, level)
					var card = reveal._entries[0]
					var effects = card._level_effects
					var state: Dictionary = reveal.snapshot()
					var radius: float = float(state.effects.bloom_radius)
					check(radius > card.effect_margin() * 1.50 and radius * scale_factor >= 68.0,
						"High-tier blooms stay materially larger than card padding even in short landscape")
					check(radius > previous_radius or is_equal_approx(radius, canvas.size.x * 0.28),
						"High-level blooms grow until the shared safe canvas limit")
					previous_radius = radius
					if batch:
						check(is_equal_approx(radius, float(manual_radii[level])),
							"Automatic pickups retain the manual bloom size despite their smaller reading cards")
					else:
						manual_radii[level] = radius
						if display_radii.has(level):
							check(is_equal_approx(radius * scale_factor, float(display_radii[level])),
								"UI scaling preserves the fireworks' display size")
						else:
							display_radii[level] = radius * scale_factor
					compact.configure(Vector2(36, 18), scale_factor, level, Color.WHITE, batch, 0.25)
					compact.fit_area(Rect2(Vector2.ZERO, canvas.size), no_exclusions)
					check(is_equal_approx(float(compact.snapshot().bloom_radius), radius),
						"A tiny card and near-zero reading margin cannot shrink the same firework canvas")
					var origin: Vector2 = effects._burst_origin(0)
					var left: Vector2 = effects._firework_point(origin, Vector2.LEFT, radius, 0.85, 1.72)
					var right: Vector2 = effects._firework_point(origin, Vector2.RIGHT, radius, 0.85, 1.72)
					check(right.x - left.x > radius * 1.9,
						"Short-screen fitting preserves a broad horizontal bloom instead of uniformly shrinking it")
					if layout.effects.size.y < 200.0:
						check(float(state.effects.vertical_scale) > 0.0 and float(state.effects.vertical_scale) < 1.0,
							"Short landscape fits vertical travel independently of its full-width bloom")
					for group in range(int(state.effects.burst_count)):
						check(Rect2(Vector2.ZERO, canvas.size).has_point(effects._burst_origin(group)),
							"Every enlarged bloom starts inside its bounded cosmetic canvas")
					check(is_equal_approx(float(state.effect_duration), 1.95),
						"A larger bloom keeps the complete existing manual and automatic firework lifetime")
					_check_bounds(reveal, reading, canvas)
	compact.free()


func _check_firework_trajectories() -> void:
	var effects := Reveal.Card.LevelEffects.new()
	for batch: bool in [false, true]:
		effects.configure(Vector2(180, 90), 1.0, 6, Color.WHITE, batch, 60.0)
		var origin := Vector2(210, 130)
		var reach: float = 60.0
		for direction: Vector2 in [Vector2.UP, Vector2(-0.6, -0.8), Vector2(0.6, -0.8)]:
			var rising: Vector2 = effects._firework_point(origin, direction, reach, 0.20, 1.0)
			var opening: Vector2 = effects._firework_point(origin, direction, reach, 0.45, 1.0)
			var falling: Vector2 = effects._firework_point(origin, direction, reach, 0.90, 1.0)
			check(rising.y < origin.y and opening.y < origin.y,
				"Upward firework spokes first open above their own origin")
			check(falling.y - opening.y > reach * 0.25,
				"Even upward spokes turn into a clearly descending tail before fading")
		var early: Vector2 = effects._firework_point(origin, Vector2.RIGHT, reach, 0.30, 1.0)
		var middle: Vector2 = effects._firework_point(origin, Vector2.RIGHT, reach, 0.60, 1.0)
		var late: Vector2 = effects._firework_point(origin, Vector2.RIGHT, reach, 0.90, 1.0)
		check(early.x - origin.x > reach * 0.75,
			"The initial firework release opens decisively across its available reach")
		check(late.x - middle.x < middle.x - early.x and late.y > middle.y,
			"Radial movement slows while the late trail continues falling")
	effects.free()


func _check_source_centered_fireworks(reveal) -> void:
	var no_exclusions: Array[Rect2] = []
	for canvas: Rect2 in [Rect2(8, 8, 984, 600), Rect2(8, 8, 374, 570), Rect2(8, 8, 552, 220)]:
		var reading := Rect2(canvas.position, Vector2(canvas.size.x, minf(190.0, canvas.size.y)))
		for batch: bool in [false, true]:
			var previous_radius: float = 0.0
			for level in range(4, 10):
				reveal.reset()
				reveal.set_reduced_motion(false)
				reveal.configure_layout(reading, 1.0, no_exclusions, canvas)
				_present(reveal, "cat", cat, batch, level)
				var effects = reveal._entries[0]._level_effects
				var radius: float = float(effects.snapshot().bloom_radius)
				var target: float = [116.0, 148.0, 184.0, 212.0, 244.0, 280.0][level - 4]
				var minimum: float = minf(target, canvas.size.x * (0.30 + (level - 4) * 0.025))
				check(radius >= minimum - 0.01,
					"Lv%d popup flowers have a visibly larger, level-specific sky radius" % level)
				check(radius > previous_radius,
					"Even narrow screens retain a distinct bloom size for each firework level")
				previous_radius = radius
				var card = reveal._entries[0]
				var center: Vector2 = effects._card.get_center()
				for group in range(int(effects.snapshot().burst_count)):
					var origin: Vector2 = effects._burst_origin(group)
					check(origin.is_equal_approx(center),
						"Every firework layer launches from its own collected-word card center, not a screen position")
					check((effects.get_global_transform() * origin).is_equal_approx(
						card.get_global_transform() * (card.size * 0.5)),
						"The real transformed popover remains the origin after responsive fitting and placement")
					for direction: Vector2 in [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
						check(effects._firework_point(origin, direction, radius, 0.0, 1.72).is_equal_approx(center),
							"Every radial trail begins on the collected Jelly rather than teleporting into the sky")


func _check_firework_stamp_exclusions() -> void:
	var effects := Reveal.Card.LevelEffects.new()
	effects.configure(Vector2(180, 90), 1.0, 6, Color.WHITE, false, 60.0)
	var available := Rect2(-30, -10, 420, 260)
	var blocked := Rect2(110, 80, 90, 65)
	effects.fit_area(available, [blocked])
	var canvas := Rect2(Vector2.ZERO, available.size)
	var local_blocked := Rect2(blocked.position - available.position, blocked.size)
	check(effects.position + effects._card.position == Vector2.ZERO
		and effects._card.size == Vector2(180, 90),
		"Expanding the effect canvas preserves the card's original position and size")
	check(is_zero_approx(effects._stamp_fit(local_blocked.get_center(), Vector2(80, 18), PI / 4.0)),
		"A sparkle centered inside a live control is suppressed completely")
	check(is_equal_approx(effects._stamp_fit(Vector2(70, 40), Vector2(24, 14), PI / 4.0), 1.0),
		"A clear sparkle retains its full production-artwork size")
	var partial: float = effects._stamp_fit(Vector2(local_blocked.position.x - 8, local_blocked.get_center().y),
		Vector2(80, 18), PI / 4.0)
	check(partial > 0.0 and partial < 1.0,
		"A sparkle near a control shrinks to the remaining space instead of covering it")
	var blocked_polygon := PackedVector2Array([local_blocked.position, Vector2(local_blocked.end.x, local_blocked.position.y),
		local_blocked.end, Vector2(local_blocked.position.x, local_blocked.end.y)])
	for point: Vector2 in [Vector2(2, 2), Vector2(418, 258), Vector2(70, 40),
		Vector2(130, 120), Vector2(185, 80), Vector2(240, 120), Vector2(185, 165),
		Vector2(132, 82), Vector2(238, 163)]:
		for angle: float in [0.0, PI / 6.0, PI / 4.0, PI / 2.0]:
			var extent := Vector2(80, 18)
			var fit: float = effects._stamp_fit(point, extent, angle)
			check(fit > 0.0 and fit <= 1.0, "A nonblocked spark receives a valid visible fit")
			var polygon := PackedVector2Array()
			for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
				var painted_corner: Vector2 = point + (corner * extent * fit).rotated(angle)
				polygon.append(painted_corner)
				check(canvas.grow(0.01).has_point(painted_corner),
					"Every rotated texture corner stays inside the effect canvas")
			var overlaps: Array[PackedVector2Array] = Geometry2D.intersect_polygons(polygon, blocked_polygon)
			var overlap_area: float = 0.0
			for overlap: PackedVector2Array in overlaps:
				var twice_area: float = 0.0
				for index in range(overlap.size()):
					twice_area += overlap[index].cross(overlap[(index + 1) % overlap.size()])
				overlap_area += absf(twice_area) * 0.5
			check(overlap_area < 0.01, "The actual rotated artwork polygon remains clear of the live control")
	effects.free()


func _check_delayed_reveal(reveal) -> void:
	for level: int in [1, 3, 4, 6, 7, 8, 9]:
		for batch: bool in [false, true]:
			for reduced: bool in [false, true]:
				await _check_charge_case(reveal, level, batch, reduced)
	reveal.reset()
	reveal.configure_layout(Rect2(20, 12, 980, 260), 1.0)
	reveal.set_reduced_motion(false)
	reveal.present({"id": "cat", "text": "cat"}, cat, Color.WHITE, false, 0.40, 4, 0.66)
	check(reveal.snapshot().phase == "charging" and float(reveal.snapshot().animated_scale[0]) < 0.75,
		"a late frame inside anticipation resumes an already-compressed card")
	reveal.set_reduced_motion(true)
	var steady: Dictionary = reveal.snapshot()
	reveal.advance(0.30)
	check(steady.animated_scale == [1.0, 1.0] and reveal.snapshot().animated_scale == [1.0, 1.0]
		and steady.rect == reveal.snapshot().rect and reveal.snapshot().phase != "charging",
		"enabling reduced motion during charge restores a still card through the release")
	reveal.reset()
	for invalid: float in [NAN, INF]:
		reveal.present({"id": "cat", "text": "cat"}, cat, Color.WHITE, false, 0.0, 4, invalid)
	check(reveal.get_child_count() == 0, "invalid anticipation durations cannot retain a permanent card")


func _check_charge_case(reveal, level: int, batch: bool, reduced: bool) -> void:
	reveal.reset()
	reveal.configure_layout(Rect2(20, 12, 980, 260), 1.0)
	reveal.set_reduced_motion(reduced)
	var delay: float = Model.collection_pop_seconds(level, batch)
	var seconds: float = Reveal.BATCH_SECONDS if batch else Reveal.SECONDS
	reveal.present({"id": "cat", "text": "cat"}, cat, Color.WHITE, batch, 0.0, level, delay)
	var start: Dictionary = reveal.snapshot()
	var effect_seconds: float = float(start.effect_duration)
	check(start.visible and start.entries.size() == 1 and start.entries[0].visible
		and start.phase == "charging" and start.effects.phase == "charging",
		"each manual and batch reading card appears in its charge phase before release")
	check(is_equal_approx(float(start.elapsed), -delay) and is_equal_approx(float(start.anticipation_seconds), delay)
		and is_equal_approx(float(start.duration), seconds),
		"anticipation shares the model release boundary without consuming reading time")
	await process_frame
	await process_frame
	check(reveal.snapshot() == start, "a paused collection clock cannot advance charge or release on its own")
	reveal.advance(delay * 0.35)
	var gathering: Dictionary = reveal.snapshot()
	check(gathering.visible and gathering.phase == "charging" and gathering.effects.phase == "charging"
		and float(gathering.charge_progress) > float(start.charge_progress),
		"light gathers while the reading card remains in anticipation rather than starting its explosion")
	if reduced:
		check(gathering.animated_scale == [1.0, 1.0] and gathering.rect == start.rect,
			"reduced-motion anticipation preserves the original readable card geometry")
	else:
		check(float(gathering.animated_scale[0]) < float(start.animated_scale[0])
			and float(gathering.animated_scale[1]) < float(start.animated_scale[1]),
			"the top reading card contracts in both dimensions while gathering energy")
	var resized := Rect2(8, 6, 250, 115)
	reveal.configure_layout(resized, 1.0)
	check(reveal.snapshot().visible and reveal.snapshot().phase == "charging"
		and is_equal_approx(float(reveal.snapshot().elapsed), float(gathering.elapsed)),
		"resizing preserves a visible charging card and its existing clock")
	_check_bounds(reveal, resized)
	_check_input(reveal)
	_check_labels(reveal)
	reveal.advance(delay * 0.60)
	var compressed: Dictionary = reveal.snapshot()
	check(compressed.phase == "charging" and compressed.effects.phase == "charging"
		and float(compressed.charge_progress) > float(gathering.charge_progress),
		"the last pre-release sample is still gathering energy without explosive particles")
	if reduced:
		check(compressed.animated_scale == [1.0, 1.0], "reduced motion keeps full size at maximum charge")
	else:
		check(float(compressed.animated_scale[0]) < float(gathering.animated_scale[0])
			and float(compressed.animated_scale[0]) < 0.60 and float(compressed.animated_scale[1]) < 0.65,
			"the charge becomes visibly more compressed before the release")
	_check_bounds(reveal, resized)
	reveal.advance(delay * 0.05 + 0.09)
	var released: Dictionary = reveal.snapshot()
	check(released.visible and is_equal_approx(float(released.elapsed), 0.09)
		and released.phase == "release" and released.effects.phase != "charging"
		and float(released.content_alpha) > 0.9,
		"crossing the shared release launches the burst at the correct residual frame age")
	if not reduced:
		check(float(released.animated_scale[0]) > 1.05
			and float(released.animated_scale[0]) > float(compressed.animated_scale[0]) * 2.0,
			"the compact energy core releases into a decisive elastic expansion")
	_check_bounds(reveal, resized)
	reveal.advance(seconds - 0.10)
	check(reveal.snapshot().visible and float(reveal.snapshot().content_alpha) < 0.1,
		"charge leaves the complete original reading lifetime available after release")
	reveal.advance(0.02)
	if effect_seconds > seconds:
		check(reveal.snapshot().visible and not reveal.snapshot().content_visible
			and reveal.snapshot().phase == "afterglow" and reveal.snapshot().effects.visible,
			"A charged batch card expires on time while its complete firework tail continues")
		reveal.advance(effect_seconds - seconds)
	check(not reveal.snapshot().visible and reveal.get_child_count() == 0,
		"A charged presentation frees itself after its last reading or effect lifetime")
	reveal.configure_layout(Rect2(20, 12, 980, 260), 1.0)
	reveal.present({"id": "cat", "text": "cat"}, cat, Color.WHITE, batch, delay + 0.24, level, delay)
	check(reveal.snapshot().visible and is_equal_approx(float(reveal.snapshot().elapsed), 0.24)
		and reveal.snapshot().phase != "charging" and reveal.snapshot().effects.phase != "charging",
		"a late release catches up from the pop boundary without replaying anticipation")
	reveal.reset()
	reveal.present({"id": "cat", "text": "cat"}, cat, Color.WHITE, batch, delay + effect_seconds - 0.04, level, delay)
	check(reveal.snapshot().visible and float(reveal.snapshot().content_alpha) < 0.15,
		"late charged presentations retain only their existing fading tail")
	reveal.advance(0.05)
	reveal.present({"id": "cat", "text": "cat"}, cat, Color.WHITE, batch, delay + effect_seconds + 0.01, level, delay)
	check(not reveal.snapshot().visible and reveal.get_child_count() == 0,
		"an expired charged presentation cannot replay its reading card")
	reveal.present({"id": "cat", "text": "cat"}, cat, Color.WHITE, batch, 0.0, level, delay)
	reveal.reset()
	reveal.advance(3.0)
	check(not reveal.snapshot().visible and reveal.get_child_count() == 0,
		"pause or exit cleanup cancels charged cards without a later callback")


func _check_bounds(reveal, area: Rect2, effect_area: Rect2 = Rect2()) -> void:
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
		var effect_bounds: Rect2 = effect_area if effect_area.has_area() and int(entry.merge_level) >= 4 else area
		check(effect_bounds.grow(0.1).encloses(_rect(entry.effects.rect)),
			"the full effect footprint remains inside the available reading region: area %s effect %s card %s level %d age %.3f" % [
				effect_bounds, _rect(entry.effects.rect), _rect(entry.resting_rect), int(entry.merge_level), float(entry.elapsed)])
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
