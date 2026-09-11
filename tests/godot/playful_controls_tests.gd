extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var duck = load("res://scripts/duck_mascot.gd").new()
	var card = load("res://scripts/word_card.gd").new()
	check(duck.has_method("perform_trick") and duck.has_method("clear_trick"),
		"Pip offers repeatable tricks with an explicit reset")
	check(card.has_method("set_reduced_motion") and card.has_method("clear_feedback"),
		"Cards expose motion preference and feedback cleanup")
	if duck.has_method("perform_trick") and duck.has_method("clear_trick"):
		root.add_child(duck)
		duck.size = Vector2(160, 160)
		_test_duck(duck)
	if card.has_method("set_reduced_motion") and card.has_method("clear_feedback"):
		var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
		card.setup({"id": words[0].id + ":image", "kind": "image", "word": words[0]})
		root.add_child(card)
		card.size = Vector2(160, 110)
		_test_card(card)
	duck.free()
	card.free()
	print("Playful controls: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_duck(duck) -> void:
	var original_children: int = duck.get_child_count()
	var captions: Array[String] = []
	for kind in ["dance", "snack", "bubbles"]:
		var caption: String = duck.perform_trick(kind)
		check(not caption.is_empty() and not captions.has(caption), "Each Pip trick supplies a distinct caption")
		captions.append(caption)
		check(duck.get("_trick") == kind and duck.get("_trick_left") > 0.0,
			"The selected Pip trick begins immediately")
		var duration: float = duck.get("_trick_left")
		duck._process(0.2)
		check(duck.get("_trick_left") < duration, "A trick advances toward its finite end")
		for tap in range(25):
			duck.perform_trick(kind)
		check(duck.get("_trick_left") <= duration and duration <= 2.5,
			"Rapid trick taps replace a short animation without stacking")
		check(duck.get_child_count() == original_children and duck.scale == Vector2.ONE
			and is_zero_approx(duck.rotation), "Tricks keep one stable hit target and allocate no particles or players")
		duck._process(3.0)
		check(duck.get("_trick") == "" and is_zero_approx(duck.get("_trick_left")),
			"A completed trick removes its transient artwork")
	duck.perform_trick("dance")
	duck.set_speaking(true)
	check(duck.pose == 1, "Real speech retains control of Pip's beak during a trick")
	duck.settle()
	check(not duck.speaking and duck.get("_trick") == "" and is_zero_approx(duck.reaction_left),
		"Settling Pip clears speech, ordinary reactions, and tricks")
	check(duck.perform_trick("unknown") == "" and duck.get("_trick") == "",
		"Unknown trick names do not leave an active animation")
	duck.set_reduced_motion(true)
	for kind in ["dance", "snack", "bubbles"]:
		duck.perform_trick(kind)
		var pose: int = duck.pose
		duck._process(3.0)
		check(duck.get("_trick") == kind and is_zero_approx(duck.get("_trick_left"))
			and duck.pose == pose and not duck.is_processing(),
			"Reduced motion keeps each trick as a stable illustration")
	duck.clear_trick()
	check(duck.get("_trick") == "", "Reduced-motion trick artwork can be cleared explicitly")
	duck.set_reduced_motion(false)
	duck.perform_trick("bubbles")
	duck.hide()
	check(duck.get("_trick") == "" and not duck.is_processing(),
		"Hiding Pip clears tricks and stops processing")
	duck.show()
	check(duck.get("_trick") == "", "Showing Pip does not restart a hidden trick")


func _test_card(card) -> void:
	var palette: Dictionary = load("res://scripts/game_data.gd").theme("spring")
	card.refresh(palette, false, false, false, false)
	check(is_zero_approx(card.get("_feedback_left")) and not card.is_processing(),
		"An untouched card has no autonomous animation")
	card.refresh(palette, true, false, false, false)
	check(card.get("_feedback_kind") == "selected" and card.get("_feedback_left") > 0.0,
		"Selecting a card starts its ripple")
	card._process(0.1)
	var remaining: float = card.get("_feedback_left")
	for refresh in range(12):
		card.refresh(palette, true, false, false, false)
	check(is_equal_approx(card.get("_feedback_left"), remaining),
		"Repeated refreshes cannot restart selected-card feedback")
	card.refresh(palette, false, false, false, true)
	check(is_zero_approx(card.get("_feedback_left")), "A neutral feedback lock clears selection effects")
	for state in ["matched", "wrong"]:
		card.refresh(palette, false, false, false, false)
		var picture_rect: Rect2 = card.picture.get_rect()
		var word_rect: Rect2 = card.word_label.get_rect()
		var word_size: int = card.word_label.get_theme_font_size("font_size")
		var front: Array = [card.picture.visible, card.word_label.visible]
		card.refresh(palette, false, state == "matched", state == "wrong", true)
		check(card.picture.get_rect() == picture_rect and card.word_label.get_rect() == word_rect
			and card.word_label.get_theme_font_size("font_size") == word_size,
			"Answer feedback keeps the picture and word in their original positions and sizes")
		check([card.picture.visible, card.word_label.visible] == front,
			"A matched card retains its original face; the review supplies the complete association")
		check(card.get("_feedback_kind") == state and card.get("_feedback_left") > 0.0,
			"A new match or mistake gets its distinct bounded feedback")
		card._process(0.1)
		remaining = card.get("_feedback_left")
		card.refresh(palette, false, state == "matched", state == "wrong", true)
		check(is_equal_approx(card.get("_feedback_left"), remaining),
			"Refreshes during feedback do not restart its animation")
		card._process(1.0)
		check(is_zero_approx(card.get("_feedback_left")) and not card.is_processing(),
			"Card feedback finishes without a tween or permanent processing")
		check(card.scale == Vector2.ONE and card.picture.scale == Vector2.ONE
			and is_zero_approx(card.rotation), "Card feedback leaves scene-owned transforms untouched")
	card.refresh(palette, false, false, false, false)
	card.refresh(palette, true, false, false, false)
	card.set_reduced_motion(true)
	check(is_zero_approx(card.get("_feedback_left")) and not card.is_processing(),
		"Changing motion preference immediately stops a card animation")
	card.refresh(palette, false, true, false, true)
	check(card.match_mark.visible and card.disabled and is_zero_approx(card.get("_feedback_left")),
		"Reduced motion retains the static match badge and gameplay lock")
	card.set_reduced_motion(false)
	card.refresh(palette, false, true, false, true)
	check(is_zero_approx(card.get("_feedback_left")), "Restoring motion does not replay an old match")
	card.refresh(palette, false, false, false, false)
	card.refresh(palette, true, false, false, false)
	card.hide()
	check(is_zero_approx(card.get("_feedback_left")), "Hiding a card clears transient effects")
	card.show()
	card.clear_feedback()
	check(card.get("_feedback_kind") == "" and not card.is_processing(),
		"Explicit cleanup leaves no active card effect")
