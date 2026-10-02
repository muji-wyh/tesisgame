extends SceneTree

const WordField = preload("res://scripts/talk_quest_words.gd")
const Model = preload("res://scripts/talk_quest_model.gd")
const Data = preload("res://scripts/talk_quest_data.gd")
const Monster = preload("res://scripts/talk_quest_monster.gd")
const Style = preload("res://scripts/ui_style.gd")

var checks := 0
var failures := 0
var draws := 0
var words: WordField


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(3):
		await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 740)
	words = WordField.new()
	words.draw.connect(func() -> void: draws += 1)
	root.add_child(words)
	words.size = Vector2(366, 300)
	await _check_live_words()
	await _check_resize_and_text()
	words.free()
	await _check_material_transitions()
	print("Quest presentation caches: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_live_words() -> void:
	var game := Model.new()
	check(game.start_level(1, 17), "The flight fixture starts a real seeded encounter")
	words.present(game.targets)
	await settle()
	check(draws > 0 and words._geometry.size() == 1,
		"The flight fixture observes a real draw with one live illustrated target")
	var first: Dictionary = words._geometry[0].duplicate(true)
	game.advance(0.5)
	words.present(game.targets)
	var prepared: Vector2 = words.center_for(int(first.uid))
	check(not prepared.is_equal_approx(first.center),
		"Presentation updates the projectile origin immediately as the model ages")
	await settle()
	# Inspect the data consumed by _draw; geometry() would rebuild it and mask a stale cache.
	var moved: Dictionary = words._geometry[0]
	check(moved.center.is_equal_approx(prepared) and moved.remaining_ms == 9500
		and float(moved.progress) > float(first.progress),
		"The drawn flight retains the current position and ten-second countdown")
	var hit: Dictionary = game.submit_transcript(str(game.current_prompt().text))
	check(hit.matched, "The live word can be consumed through the actual speech validator")
	words.present(game.targets)
	await settle()
	check(words._geometry.is_empty() and words.center_for(int(first.uid)) == words.size * 0.5,
		"A successful attack removes the old card and its cached projectile origin")
	game.advance(0.5)
	words.present(game.targets)
	await settle()
	check(words._geometry.size() == 1 and int(words._geometry[0].uid) != int(first.uid),
		"The next launch draws its new occurrence instead of a consumed word")


func _check_resize_and_text() -> void:
	var long_word: Dictionary = {}
	for word: Dictionary in Data.level(11).words:
		if word.id == "sunglasses":
			long_word = word
	check(not long_word.is_empty(), "The text-fit fixture uses an existing illustrated campaign word")
	if long_word.is_empty():
		return
	var target: Dictionary = {"uid": 1, "word": long_word, "age": 2.5, "lifetime": 10.0,
		"lane": 0, "spin": 0.75, "forms": ["sunglasses"]}
	words.present([target])
	await settle()
	var wide_fit: Vector2 = words._text_layouts["sunglasses"]
	_check_fitted_word("The original card")
	var card_style: StyleBoxFlat = words._card_styles[0]
	var shadow: StyleBoxFlat = words._shadow
	var normal_center: Vector2 = words._geometry[0].center
	for frame in range(3):
		target.age += 0.1
		words.present([target])
		await settle()
	check(words._card_styles[0] == card_style and words._shadow == shadow
		and words._text_layouts["sunglasses"] == wide_fit,
		"Moving a word keeps its fixed-scale card resources and fitted caption")
	words.size = Vector2(250, 230)
	await settle()
	check(not words._geometry[0].center.is_equal_approx(normal_center)
		and words._geometry[0].size.x < 90,
		"A resize redraws the existing target at the new bounds without another present call")
	_check_fitted_word("The narrower card")
	check(words._text_layouts["sunglasses"].x < wide_fit.x
		and words._card_styles[0] == card_style and words._shadow == shadow,
		"A narrower card refits long text while retaining the unchanged-scale artwork styles")
	words.reduced_motion = true
	words.queue_redraw()
	await settle()
	check(is_equal_approx(words._geometry[0].center.y, words.size.y * 0.5)
		and is_zero_approx(words._geometry[0].rotation),
		"Enabling reduced motion invalidates the drawn flight position and rotation")
	words.reduced_motion = false
	words.queue_redraw()
	await settle()
	check(not is_zero_approx(words._geometry[0].rotation)
		and not is_equal_approx(words._geometry[0].center.y, words.size.y * 0.5),
		"Restoring normal motion resumes the current trajectory instead of a frozen cached pose")
	var old_scale: float = Style.ui_scale(words)
	root.content_scale_size = Vector2i(480, 480)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(960, 720)
	words.queue_redraw()
	await settle()
	var new_scale: float = Style.ui_scale(words)
	check(new_scale > old_scale and words._card_styles[0] != card_style and words._shadow != shadow,
		"Canvas stretch replaces the styles even when the word field's logical size stays fixed")
	check(words._card_styles[0].bg_color == card_style.bg_color
		and words._card_styles[0].corner_radius_top_left < card_style.corner_radius_top_left,
		"The scaled card retains its palette and adapts its screen-space corner radius")
	_check_fitted_word("The scaled card")
	check(words._geometry_scale == new_scale and words._geometry_size == words.size,
		"The drawn card geometry uses the same current display scale as its caption and style")
	var scaled_fit: Vector2 = words._text_layouts["sunglasses"]
	target.word = Data.level(1).words[0]
	words.present([target])
	await settle()
	var replacement: String = str(target.word.text)
	check(words._text_layouts.has(replacement)
		and words._text_layouts[replacement].y < scaled_fit.y,
		"Replacing a long caption with a different word cannot reuse the old text width")


func _check_fitted_word(context: String) -> void:
	var item: Dictionary = words._geometry[0]
	var fit: Vector2 = words._text_layouts["sunglasses"]
	var measured: float = ThemeDB.fallback_font.get_string_size(
		"sunglasses", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit.x)).x
	check(is_equal_approx(fit.y, measured) and measured < float(item.size.x) - 6.0,
		context + " keeps the full long caption inside the illustrated card")


func _matches_source(monster: Monster) -> bool:
	if monster._materials.is_empty():
		return false
	for index in range(monster._materials.size()):
		var material: StandardMaterial3D = monster._materials[index]
		var source: Dictionary = monster._material_base[index]
		if material.albedo_color != source.albedo or material.emission_enabled != source.enabled \
			or material.emission != source.emission \
			or not is_equal_approx(material.emission_energy_multiplier, float(source.energy)):
			return false
	return true


func _check_material_transitions() -> void:
	var monster := Monster.new()
	root.add_child(monster)
	monster.set_process(false)
	check(monster.set_creature("lpm-bunny") and _matches_source(monster),
		"A newly loaded source creature starts with every original material value")
	check(monster.react_hit(), "The material fixture enters a normal hit reaction")
	var peak: float = monster._materials[0].emission_energy_multiplier
	check(monster._materials[0].emission_enabled and not _matches_source(monster),
		"A hit immediately lights the private materials after cached idle frames")
	monster._reaction.custom_step(0.12)
	monster._process(0.0)
	check(monster._materials[0].emission_energy_multiplier > 0.0
		and monster._materials[0].emission_energy_multiplier < peak,
		"Intermediate flash values continue to reach the rendered materials")
	monster._reaction.custom_step(3.0)
	monster._process(0.0)
	check(monster.state == "idle" and _matches_source(monster),
		"The final flash frame restores every source albedo, emission color, flag, and energy")
	monster.set_cooperative_mode(true)
	monster.repair_progress(3, 5)
	var glow: float = monster._materials[0].emission_energy_multiplier
	check(glow > 0.0 and monster._materials[0].emission_enabled,
		"Cooperative progress updates the formerly idle materials")
	var previous: StandardMaterial3D = monster._materials[0]
	check(monster.set_creature("lpm-frog") and monster._materials[0] != previous,
		"Changing levels replaces the source creature and its private material instances")
	check(monster._materials.all(func(material: StandardMaterial3D) -> bool:
		return material.emission_enabled and is_equal_approx(material.emission_energy_multiplier, glow)),
		"The new creature receives retained cooperative glow even when the feedback value is unchanged")
	monster.set_cooperative_mode(false)
	check(_matches_source(monster), "Leaving cooperative mode restores the new creature's source materials")
	check(monster.react_hit(), "The new creature can receive another hit after returning to cached idle")
	monster.set_reduced_motion(true)
	check(monster.state == "idle" and _matches_source(monster),
		"A motion-preference change cancels the hit and clears its cached material feedback")
	monster.free()
	await process_frame
