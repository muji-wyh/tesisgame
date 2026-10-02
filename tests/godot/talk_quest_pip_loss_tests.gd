extends SceneTree
## Exercise the real rematch card without loading or changing player saves.

const Result = preload("res://scripts/talk_quest_result.gd")
const LAYOUTS := [
	{"label": "desktop", "size": Vector2i(1050, 600)},
	{"label": "phone", "size": Vector2i(390, 650)},
	{"label": "small phone", "size": Vector2i(320, 414)},
	{"label": "compact landscape", "size": Vector2i(544, 140)},
]

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _present(result, blocked: bool = false) -> void:
	result.present(4, "Friendly forest guardian", 4, 7, 3, blocked)


func _advance(result, seconds: float) -> void:
	result.pip._process(seconds)
	result._process(seconds)


func _check_lifecycle(result) -> void:
	var calls: Array[int] = [0]
	result.loss_reaction_requested.connect(func() -> void: calls[0] += 1)
	result.reset_loss()
	_present(result)
	check(calls[0] == 1 and result.loss_emotion == "sad" and result.pip.is_visible_in_tree()
		and result.pip._gameplay_reaction == "sad", "A new loss reveals sad Pip and requests one reaction call")
	check(not result.retry.disabled and not result.map_button.disabled,
		"The player can retry or leave throughout the emotional sequence")
	check(is_equal_approx(result.pip._gameplay_duration(), Result.LOSS_SAD_SECONDS),
		"Pip's articulated reaction uses the entire loss expression interval")
	_advance(result, 0.8)
	var age: float = result._loss_age
	var reaction_left: float = result.pip._gameplay_left
	for index in range(8):
		_present(result, index % 2 == 0)
	check(calls[0] == 1 and is_equal_approx(result._loss_age, age)
		and is_equal_approx(result.pip._gameplay_left, reaction_left),
		"Statistics and save-status refreshes do not restart the expression or request another call")
	_present(result)
	_advance(result, 1.59)
	check(result.loss_emotion == "sad", "Pip stays disappointed until the intended expression finishes")
	_advance(result, 0.02)
	check(result.loss_emotion == "encouraging" and result.pip._gameplay_reaction.is_empty()
		and result.pip._trick == "high-five" and result._note.text == "Let's try again together!",
		"The sad sequence finishes with a high five and supportive retry copy")
	_present(result)
	check(calls[0] == 1 and result.loss_emotion == "encouraging",
		"Refreshing a completed sequence keeps Pip supportive without another cry")
	result.reset_loss()
	_present(result)
	check(calls[0] == 2 and result.loss_emotion == "sad", "Starting another round re-arms exactly one new loss reaction")
	_advance(result, 0.4)
	result.hide()
	check(result.loss_emotion == "encouraging" and result.pip._gameplay_reaction.is_empty(),
		"Hiding the result cancels disappointment instead of storing an old cry")
	_present(result)
	check(calls[0] == 2 and result.loss_emotion == "encouraging"
		and result._note.text == "Let's try again together!",
		"Returning after a pause immediately offers encouragement without replaying the call")
	result.reset_loss()
	result.set_reduced_motion(true)
	_present(result)
	check(calls[0] == 3 and result.reveal == 1.0 and result.pip.reduced_motion and result.is_processing()
		and result.pip.pose == 2, "Reduced motion shows the complete static sad expression immediately")
	_advance(result, 1.6)
	check(result.loss_emotion == "sad" and result.pip.pose == 2,
		"The reduced-motion expression remains sad for the full interval")
	_advance(result, 0.81)
	check(result.loss_emotion == "encouraging" and result.pip._trick == "high-five"
		and result._note.text == "Let's try again together!" and not result.is_processing(),
		"Reduced motion still advances encouragement copy and leaves no sequence processing loop")
	result.reset_loss()
	result.present_pause(4, "Friendly forest guardian", 4, 7, 3, "lost", false)
	check(not result.pip.visible and calls[0] == 3 and result.pause_mode,
		"The pause card does not introduce a loss expression or sound")
	result.hide()
	result.set_reduced_motion(false)


func _check_layout(result, label: String) -> void:
	var bounds := Rect2(Vector2.ZERO, result.size)
	check(bounds.grow(1).encloses(result.surface.get_rect())
		and bounds.grow(1).encloses(result.pip.get_rect()), label + " contains the full rematch card and Pip")
	var card_bounds := Rect2(Vector2.ZERO, result.surface.size)
	for button: Button in [result.retry, result.map_button]:
		check(button.size.x * result._scale >= 44 and button.size.y * result._scale >= 44,
			label + " preserves a complete touch target for " + button.text)
		check(card_bounds.grow(1).encloses(button.get_rect()), label + " contains the entire " + button.text + " action")
	check(not result.retry.get_rect().intersects(result.map_button.get_rect()), label + " separates the two actions")
	check(not result.pip.get_rect().intersects(result.surface.get_rect()), label + " keeps Pip clear of the rematch controls")
	check(not result.pip.get_rect().intersects(result._hero_name.get_rect()), label + " separates Pip from his caption")
	for value: Label in [result._eyebrow, result._title, result._note, result._hits_value,
		result._hits_label, result._hp_value, result._hp_label]:
		if not value.visible:
			continue
		check(card_bounds.grow(1).encloses(value.get_rect()), label + " keeps " + value.text + " inside its card")
		check(not value.get_rect().intersects(result.retry.get_rect())
			and not value.get_rect().intersects(result.map_button.get_rect()),
			label + " keeps text clear of both actions")
	for value: Label in [result._hits_value, result._hits_label, result._hp_value, result._hp_label]:
		if value.visible:
			check(not value.get_rect().intersects(result._title.get_rect()),
				label + " separates the title from " + value.text)
	check(result.pip.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and result.pip.focus_mode == Control.FOCUS_NONE, label + " makes decorative Pip transparent to input and focus")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1050, 600)
	var result = Result.new()
	root.add_child(result)
	result.size = Vector2(root.size)
	_check_lifecycle(result)
	for layout: Dictionary in LAYOUTS:
		root.size = layout.size
		result.size = Vector2(layout.size)
		result.reset_loss()
		_present(result)
		result.reveal = 1.0
		result.layout()
		_check_layout(result, str(layout.label) + " sad")
		_advance(result, Result.LOSS_SAD_SECONDS + 0.01)
		_check_layout(result, str(layout.label) + " encouraging")
	result.free()
	print("Talk Quest Pip loss: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
