extends SceneTree

const Reveal = preload("res://scripts/word_jelly_word_reveal.gd")
const WordArt = preload("res://scripts/word_art.gd")

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
	var reveal := Reveal.new()
	root.add_child(reveal)
	var apple: Texture2D = WordArt.texture("assets/images/word-library/apple.webp")
	var cat: Texture2D = WordArt.texture("assets/images/word-library/cat.webp")
	check(not reveal.snapshot().visible, "the reveal is hidden before a collection")
	for area: Rect2 in [Rect2(22, 14, 900, 180), Rect2(14, 8, 362, 160), Rect2(12, 6, 620, 90)]:
		reveal.configure_layout(area, 1.0)
		reveal.present({"id": "apple", "text": "apple"}, apple, Color("#598c6c"))
		reveal.advance(0.18)
		var state: Dictionary = reveal.snapshot()
		check(state.visible and state.spelling == "apple", "a collected word is readable at the release peak")
		check(state.picture.ends_with("apple.webp"), "the reveal preserves the real vocabulary artwork")
		check(area.encloses(_rect(state.rect)), "the reveal peak fits its available upper region")
		check(_rect(state.rect).encloses(_rect(state.picture_rect)), "the word picture stays within its surface")
		check(_rect(state.rect).encloses(_rect(state.spelling_rect)), "the spelling stays within its surface")
		var json: Dictionary = JSON.parse_string(JSON.stringify(state))
		check(json.rect is Array and json.picture_rect is Array and json.spelling_rect is Array
			and json.resting_rect is Array, "the browser receives numeric rectangle coordinates")
		check(float(state.content_alpha) > 0.99, "the released word is fully visible")
		check(reveal.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the overlay permits gameplay input")
		_check_input(reveal)
	var before: Dictionary = reveal.snapshot()
	check(reveal._surface.get_index() < reveal._aura.get_index()
		and reveal._aura.get_index() < reveal._picture.get_index(), "the glow lights the picture above its opaque surface")
	reveal.advance(-1.0)
	reveal.advance(NAN)
	check(reveal.snapshot().elapsed == before.elapsed, "invalid time steps cannot rewind or corrupt the effect")
	reveal.present({"id": "cat", "text": "cat"}, cat, Color("#ac77a6"))
	check(reveal.snapshot().word_id == "cat" and reveal.snapshot().elapsed == 0.0,
		"a rapid second collect replaces the previous word without a stale timeline")
	check(reveal.snapshot().picture.ends_with("cat.webp"), "replacement updates the picture as well as the spelling")
	reveal.advance(0.40)
	reveal.configure_layout(Rect2(5, 8, 310, 115), 1.0)
	check(reveal.snapshot().elapsed == 0.40 and reveal.snapshot().visible, "resizing preserves the reading beat")
	reveal.advance(1.50)
	check(reveal.snapshot().visible and float(reveal.snapshot().content_alpha) < 0.2,
		"the reading beat ends with a short fade")
	reveal.advance(0.10)
	check(not reveal.snapshot().visible and reveal.snapshot().picture.is_empty(),
		"completion releases the picture and removes the overlay")
	reveal.set_reduced_motion(true)
	reveal.present({"id": "apple", "text": "apple"}, apple, Color("#598c6c"))
	reveal.advance(0.10)
	before = reveal.snapshot()
	reveal.advance(0.40)
	check(reveal.snapshot().rect == before.rect, "reduced motion keeps the reveal completely still")
	check(reveal.snapshot().content_alpha == 1.0, "reduced motion preserves a clear reading beat")
	check(not reveal._aura.visible, "reduced motion suppresses the light burst")
	for glint: TextureRect in reveal._glints:
		check(not glint.visible, "reduced motion suppresses moving glints")
	reveal.reset()
	check(not reveal.snapshot().visible and reveal.snapshot().spelling.is_empty(),
		"exit or pause cleanup clears the complete presentation")
	reveal.present({"id": "missing", "text": "missing"}, null, Color.WHITE)
	check(not reveal.snapshot().visible, "missing artwork cannot show a placeholder reveal")
	reveal.queue_free()
	await process_frame
	print("Word Jelly word reveal: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check_input(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			check(child.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"every reveal child passes pointer input to the game")
		_check_input(child)


func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
