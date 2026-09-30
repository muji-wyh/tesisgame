extends SceneTree

const Surprise = preload("res://scripts/chest_surprise.gd")
const Chest = preload("res://scripts/chest_view.gd")
const Feel = preload("res://scripts/chest_feel.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _rect(state: Dictionary) -> Rect2:
	var bounds: Dictionary = state.bounds
	return Rect2(float(bounds.x), float(bounds.y), float(bounds.width), float(bounds.height))


func _select_kind(effect, kind: String, color: Color, reduced: bool) -> bool:
	# Use the real seeded selector, including its consecutive-repeat protection.
	for attempt in range(96):
		effect.clear()
		effect.play(color, reduced)
		if str(effect.snapshot().kind) == kind:
			return true
	return false


func _check_assets() -> void:
	check(Surprise.KINDS == ["star", "ball", "rocket", "kite", "robot", "doll"]
		and Surprise.TEXTURES.size() == Surprise.KINDS.size(), "The surprise pool contains six distinct toys")
	for index in range(Surprise.KINDS.size()):
		var texture: Texture2D = Surprise.TEXTURES[index]
		check(texture != null and texture.get_width() > 0 and texture.get_height() > 0,
			str(Surprise.KINDS[index]) + " has usable local artwork")
		if texture == null:
			continue
		var artwork: Image = texture.get_image()
		check(artwork != null and not artwork.is_empty(), str(Surprise.KINDS[index]) + " decodes without a download")
		if artwork == null or artwork.is_empty():
			continue
		var corners_are_clear: bool = true
		for point in [Vector2i.ZERO, Vector2i(artwork.get_width() - 1, 0),
			Vector2i(0, artwork.get_height() - 1), artwork.get_size() - Vector2i.ONE]:
			corners_are_clear = corners_are_clear and artwork.get_pixelv(point).a <= 0.01
		check(corners_are_clear, str(Surprise.KINDS[index]) + " retains transparent artwork corners")


func _check_effect_lifecycle() -> void:
	var effect = Surprise.new()
	root.add_child(effect)
	effect.fit(Vector2(440, 360), Vector2(220, 240), 1.0)
	effect._random.seed = 1307
	check(not effect.is_processing() and not effect.snapshot().active,
		"The surprise has no independent clock and starts hidden")
	effect.play(Color("#a6e4f7"))
	var initial: Dictionary = effect.snapshot()
	check(initial.active and initial.play_count == 1 and initial.age == 0.0
		and initial.kind in Surprise.KINDS, "A new surprise starts once at its cavity origin")
	effect.advance(0.18)
	var moving: Dictionary = effect.snapshot()
	check(moving.active and moving.age > initial.age and _rect(moving).position != _rect(initial).position,
		"Normal feedback visibly travels away from its initial position")
	for delta in [0.0, -1.0, NAN, INF]:
		effect.advance(delta)
	check(effect.snapshot() == moving, "Invalid or unearned frame intervals cannot change the surprise")
	effect.reduce_motion()
	var reduced: Dictionary = effect.snapshot()
	check(reduced.active and reduced.reduced_motion and reduced.kind == initial.kind
		and reduced.play_count == initial.play_count, "Enabling reduced motion keeps the same toy without another draw")
	effect.advance(0.4)
	check(effect.snapshot().bounds == reduced.bounds, "Reduced motion holds the toy in one static position")
	effect.reduce_motion()
	check(is_equal_approx(float(effect.snapshot().age), 0.4),
		"Repeated reduced-motion updates cannot restart its display timer")
	effect.advance(0.69)
	check(effect.snapshot().active and effect.snapshot().bounds == reduced.bounds,
		"The static surprise remains visible until its brief display duration completes")
	effect.advance(0.02)
	check(not effect.snapshot().active and not effect.visible and effect.snapshot().kind.is_empty(),
		"The reduced-motion surprise clears after 1.1 seconds")
	effect.play(Color("#d6b8ff"), false)
	effect.advance(2.39)
	check(effect.snapshot().active, "Normal feedback preserves its complete 2.4-second appearance")
	effect.advance(0.02)
	var expired: Dictionary = effect.snapshot()
	check(not expired.active and not effect.visible and expired.play_count == 2,
		"Normal feedback expires without replaying or creating another toy")
	effect.advance(100.0)
	check(effect.snapshot() == expired, "An expired effect remains inert during later frames")
	effect.play(Color.WHITE)
	effect.advance(0.2)
	effect.clear()
	var cleared: Dictionary = effect.snapshot()
	effect.clear()
	effect.advance(0.5)
	check(not cleared.active and effect.snapshot() == cleared,
		"Cancellation is immediate, idempotent, and cannot leave a delayed effect")
	effect.free()


func _check_randomness() -> void:
	var expected: Array[int] = []
	seed(420192)
	for index in range(8):
		expected.append(randi())
	seed(420192)
	var effect = Surprise.new()
	root.add_child(effect)
	effect.fit(Vector2(440, 360), Vector2(220, 240), 1.0)
	effect._random.seed = 724901
	var seen: Dictionary = {}
	var previous: String = ""
	var consecutive_repeat: bool = false
	for opening in range(96):
		effect.play(Color.WHITE, opening % 2 == 0)
		var kind: String = effect.snapshot().kind
		consecutive_repeat = consecutive_repeat or kind == previous
		seen[kind] = true
		previous = kind
		effect.advance(0.2)
		effect.clear()
	var actual: Array[int] = []
	for index in range(8):
		actual.append(randi())
	check(actual == expected, "Choosing, animating, and cancelling surprises never advances the global game RNG")
	check(seen.size() == Surprise.KINDS.size() and not consecutive_repeat,
		"The seeded cosmetic pool reaches every toy without consecutive duplicates")
	check(effect.snapshot().play_count == 96, "Every deliberate cosmetic draw is counted exactly once")
	effect.free()


func _check_layouts(data) -> void:
	var chest = Chest.new()
	root.add_child(chest)
	chest.set_process(false)
	var effect = Surprise.new()
	root.add_child(effect)
	effect._random.seed = 57209
	var layouts: Array[Dictionary] = [
		{"size": Vector2(180, 110), "scale": 0.75},
		{"size": Vector2(320, 190), "scale": 1.0},
		{"size": Vector2(180, 400), "scale": 1.25},
		{"size": Vector2(440, 360), "scale": 1.0},
		{"size": Vector2(640, 420), "scale": 1.5},
		{"size": Vector2(900, 480), "scale": 2.0}
	]
	for theme_id in data.THEMES:
		chest.clear()
		chest.configure_skin(data.theme(theme_id), data.chests)
		chest.start_open(false)
		chest.finish_immediately()
		for layout in layouts:
			chest.size = layout.size
			chest.set_drag_offset(Vector2.ZERO)
			effect.fit(layout.size, chest._cavity_origin(), layout.scale)
			var stage := Rect2(Vector2.ZERO, layout.size).grow(0.5)
			for kind in Surprise.KINDS:
				for reduced in [false, true]:
					var context: String = "%s %s at %s, reduced=%s" % [theme_id, kind, layout.size, reduced]
					var chosen: bool = _select_kind(effect, kind, Feel.FLASH_COLORS[theme_id], reduced)
					check(chosen, "The layout fixture exercises " + context)
					if not chosen:
						continue
					var first: Dictionary = effect.snapshot()
					var previous_time: float = 0.0
					var outside: Array[String] = []
					var changed_position: bool = false
					var stayed_static: bool = true
					var samples: Array = [0.0, 0.08, 0.24, 0.5, 0.86, 1.1, 1.45, 1.9, 2.39]
					if reduced:
						samples = [0.0, 0.18, 0.56, 1.09]
					for time in samples:
						effect.advance(float(time) - previous_time)
						previous_time = float(time)
						var state: Dictionary = effect.snapshot()
						var bounds: Rect2 = _rect(state)
						if not state.active or not bounds.position.is_finite() or not bounds.size.is_finite() \
							or bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or not stage.encloses(bounds):
							outside.append("%.2fs: %s" % [time, state])
						changed_position = changed_position or bounds.position != _rect(first).position
						stayed_static = stayed_static and state.bounds == first.bounds
					check(outside.is_empty(), "%s keeps its toy and light envelope inside the stage: %s" % [context, outside])
					check(stayed_static if reduced else changed_position,
						context + (" stays static" if reduced else " follows a visible flight"))
					check(effect._color == Feel.FLASH_COLORS[theme_id], context + " uses the chest's theme light")
					effect.clear()
	effect.free()
	chest.free()


func _check_chest_lifecycle(data) -> void:
	var chest = Chest.new()
	root.add_child(chest)
	chest.set_process(false)
	chest.size = Vector2(440, 360)
	chest.configure_skin(data.theme("spring"), data.chests)
	var openings: Array[String] = []
	var cues: Array = []
	chest.opened.connect(func() -> void: openings.append(chest.theme_id))
	chest.cue_requested.connect(func(theme: String, cue: String, step: int) -> void: cues.append([theme, cue, step]))
	chest.show_surprise()
	chest.begin_hold()
	chest.set_hold_progress(0.7)
	chest.show_surprise()
	check(chest.hold_effect_snapshot().surprise.play_count == 0, "Closed and partially held chests cannot show a surprise")
	chest.start_open(false)
	chest.show_surprise()
	chest._advance_animation(Feel.RELEASE_TIME + 0.05)
	chest.show_surprise()
	check(chest.mode == "opening" and not chest.hold_effect_snapshot().surprise.active
		and chest.hold_effect_snapshot().surprise.play_count == 0,
		"The visible release cannot show the surprise before the opening fully completes")
	chest.finish_immediately()
	check(chest.mode == "opened" and openings.size() == 1 and not chest.hold_effect_snapshot().surprise.active,
		"The opening signal leaves presentation authorization with its owner")
	chest.show_surprise()
	var earned: Dictionary = chest.hold_effect_snapshot().surprise
	var cue_count: int = cues.size()
	check(earned.active and earned.play_count == 1 and not earned.reduced_motion,
		"An opened chest can present one normal surprise")
	for duplicate in range(12):
		chest.show_surprise()
		chest.finish_immediately()
	check(chest.hold_effect_snapshot().surprise == earned and openings.size() == 1 and cues.size() == cue_count,
		"Duplicate callbacks neither reroll the toy nor repeat opening rewards or sounds")
	chest._advance_animation(0.2)
	chest.hide()
	check(not chest.hold_effect_snapshot().surprise.active, "Hiding the chest immediately cancels its surprise")
	chest.show()
	chest.show_surprise()
	chest._advance_animation(0.2)
	check(not chest.hold_effect_snapshot().surprise.active and chest.hold_effect_snapshot().surprise.play_count == 1
		and openings.size() == 1, "Showing an earned chest cannot replay a cancelled surprise")
	chest.clear()
	chest.configure_skin(data.theme("summer"), data.chests)
	chest.start_open(true)
	chest.show_surprise()
	var still: Dictionary = chest.hold_effect_snapshot().surprise
	check(still.active and still.reduced_motion and still.play_count == 2,
		"The next opening gets a fresh static surprise when reduced motion is enabled")
	chest._advance_animation(0.3)
	check(chest.hold_effect_snapshot().surprise.bounds == still.bounds, "Reduced-motion chest updates keep the surprise still")
	chest.set_idle_paused(true)
	chest._advance_animation(0.3)
	check(not chest.hold_effect_snapshot().surprise.active, "Background pause cancels an active surprise")
	chest.set_idle_paused(false)
	chest.show_surprise()
	check(not chest.hold_effect_snapshot().surprise.active and chest.hold_effect_snapshot().surprise.play_count == 2,
		"Returning from the background cannot replay a consumed surprise")
	chest.clear()
	chest.configure_skin(data.theme("winter"), data.chests)
	chest.start_open(false)
	chest.finish_immediately()
	chest.set_idle_paused(true)
	chest.show_surprise()
	check(chest.hold_effect_snapshot().surprise.play_count == 2, "A paused chest rejects a late presentation request")
	chest.set_idle_paused(false)
	chest.show_surprise()
	var before_reduction: Dictionary = chest.hold_effect_snapshot().surprise
	chest.reduced_motion = true
	chest._advance_animation(0.02)
	var after_reduction: Dictionary = chest.hold_effect_snapshot().surprise
	check(after_reduction.active and after_reduction.reduced_motion and after_reduction.kind == before_reduction.kind
		and after_reduction.play_count == before_reduction.play_count,
		"A live preference change makes the existing surprise static without rerolling it")
	chest._advance_animation(1.1)
	chest.show_surprise()
	check(not chest.hold_effect_snapshot().surprise.active and chest.hold_effect_snapshot().surprise.play_count == 3,
		"Natural expiry also preserves the once-per-opening guard")
	chest.clear()
	chest.configure_skin(data.theme("autumn"), data.chests)
	chest.start_open(true)
	chest.show_surprise()
	chest.configure_skin(data.theme("ocean"), data.chests)
	chest.show_surprise()
	check(chest.mode == "closed" and not chest.hold_effect_snapshot().surprise.active
		and chest.hold_effect_snapshot().surprise.play_count == 4,
		"Changing theme discards the old surprise until the new chest is opened")
	chest.clear()
	check(not chest.hold_effect_snapshot().surprise.active and openings.size() == 4,
		"Clearing presentation leaves the number of completed openings unchanged")
	chest.free()


func _run() -> void:
	_check_assets()
	_check_effect_lifecycle()
	_check_randomness()
	var data = load("res://scripts/game_data.gd").new()
	check(data.load_all(), "Surprise integration uses valid chest themes and artwork")
	_check_layouts(data)
	_check_chest_lifecycle(data)
	print("Chest surprise: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
