extends SceneTree
## Exact original trajectory and stamp-output regression for the group clock.

# Original oracle frozen from production source SHA256:
# cc9209b7058df790ebda44d93c1f507fd1509ba8bfeb8dc896b3b603ede6f854.
# It must remain independent of the runtime prepared-clock implementation.

class Capture extends "res://scripts/word_jelly_reveal_fx.gd":
	var attempts: Array = []
	var accepted: Array = []

	func clear_capture() -> void:
		attempts.clear()
		accepted.clear()

	func _stamp(texture: Texture2D, point: Vector2, extent: Vector2, color: Color, angle: float = 0.0) -> void:
		attempts.append([texture, point, extent, color, angle])
		if (_stamp_limit >= 0 and _stamp_count >= _stamp_limit) or color.a <= 0.002 or extent.x <= 0.0 or extent.y <= 0.0:
			return
		var fit: float = _stamp_fit(point, extent, angle)
		if fit <= 0.0:
			return
		var fitted: Vector2 = extent * fit
		_stamp_count += 1
		accepted.append([texture, point, extent, fitted, color, angle, fit])

	func draw_capture() -> void:
		_stamp_count = 0
		if _stamp_limit == 0 or _card.size.x <= 0.0 or duration <= 0.0:
			return
		if elapsed < 0.0:
			if anticipation_seconds > 0.0 and elapsed >= -anticipation_seconds:
				if reduced_motion:
					_draw_steady(1.0)
				else:
					_draw_charge(clampf(1.0 + elapsed / anticipation_seconds, 0.0, 1.0))
			return
		var fade: float = (1.0 if anticipation_seconds > 0.0 else smoothstep(0.0, 0.055, elapsed)) \
			* (1.0 - smoothstep(duration - (0.22 if _batch and level < 4 else 0.31), duration, elapsed))
		if fade <= 0.0:
			return
		if reduced_motion:
			_draw_steady(fade)
		else:
			_draw_release(fade)
			_draw_celebration(fade)


class Original extends Capture:

	func _stamp_fit(point: Vector2, extent: Vector2, angle: float) -> float:
		# Fit the rotated artwork itself, including its corners, to the reserved halo.
		var half: Vector2 = extent * 0.5
		var rotated := Vector2(absf(cos(angle)) * half.x + absf(sin(angle)) * half.y,
			absf(sin(angle)) * half.x + absf(cos(angle)) * half.y)
		var room: Vector2 = point.min(size - point).max(Vector2.ZERO)
		var fit: float = minf(1.0, minf(room.x / maxf(rotated.x, 0.001), room.y / maxf(rotated.y, 0.001)))
		for exclusion: Rect2 in _exclusions:
			if exclusion.has_point(point):
				return 0.0
			# Keep the entire rotated stamp clear of Finish and other live controls.
			var gap := Vector2(maxf(exclusion.position.x - point.x, point.x - exclusion.end.x),
				maxf(exclusion.position.y - point.y, point.y - exclusion.end.y))
			var clearance: float = maxf(gap.x / maxf(rotated.x, 0.001), gap.y / maxf(rotated.y, 0.001))
			fit = minf(fit, clearance)
		return clampf(fit, 0.0, 1.0)


	func _firework_radius() -> float:
		# Reading padding cannot cap the celebration or shrink automatic pickups.
		var pixels: float = float(PROFILES[level - 1].get("radius", 0.0))
		return minf(pixels / _ui_scale, size.x * (0.30 + (level - 4) * 0.025))


	func _firework_vertical_scale() -> float:
		# Short landscapes retain broad blooms while leaving room for their descent.
		return minf(1.0, size.y / maxf(1.0, _firework_radius() * 2.4))


	func _firework_point(origin: Vector2, direction: Vector2, reach: float, age: float, life: float) -> Vector2:
		# Radial drag opens a broad flower; gravity overtakes even its upward spokes.
		var time: float = clampf(age / life, 0.0, 1.0)
		var travel: float = (1.0 - exp(-time * 4.5)) / (1.0 - exp(-4.5))
		var falling: float = maxf(0.0, (time - 0.08) / 0.92)
		var spread: Vector2 = direction * Vector2(1.16, 0.88) * reach * travel
		var drop: float = reach * 1.40 * falling * falling
		var offset: Vector2 = spread + Vector2(direction.x * reach * 0.045 * time * time, drop)
		offset.y *= _firework_vertical_scale()
		return origin + offset


	func _draw_explosion(fade: float) -> void:
		var selected: Dictionary = PROFILES[level - 1]
		var groups: int = int(selected.bursts)
		if _stamp_limit >= 0:
			groups = mini(groups, 2)
		var span: float = _emission_span()
		var count: int = _spark_count()
		var trails: int = _trail_count()
		if _stamp_limit >= 0:
			if count == 0:
				_stamp(GLOW, _card.get_center(), _card.size * 1.12, Color(color_at(), fade * 0.24))
				return
			groups = mini(groups, count)
		for group in range(groups):
			var spokes: int = count / groups + (1 if group < count % groups else 0)
			var delay: float = span * float(group) / float(maxi(1, groups - 1))
			var age: float = elapsed - delay
			var life: float = minf(1.72, duration - delay - 0.08)
			if age <= 0.0 or age >= life:
				continue
			var origin: Vector2 = _burst_origin(group)
			var radius: float = _firework_radius() * (0.96 + float(group % 2) * 0.06)
			var tint: Color = color_at(group)
			var opening: float = smoothstep(0.0, 0.012, age) * (1.0 - smoothstep(0.025, life * 0.27, age))
			_stamp(GLOW, origin, Vector2.ONE * radius * 1.5, Color(tint, opening * fade * 0.55))
			_stamp(RAYS, origin, Vector2.ONE * radius * (0.7 + smoothstep(0.0, life * 0.2, age)),
				Color(tint, opening * fade * 0.8), group * 0.7)
			for spoke in range(spokes):
				var phase: float = float(posmod(spoke * 7 + group * 3, 13)) / 13.0
				var angle: float = TAU * float(spoke) / float(spokes) + group * 0.43
				var direction := Vector2.from_angle(angle)
				# The alternating inner and outer petals share one unmistakable origin.
				var reach: float = radius * (0.72 + phase * 0.28)
				var point: Vector2 = _firework_point(origin, direction, reach, age, life)
				var opacity: float = fade * smoothstep(0.0, 0.015, age) * (1.0 - smoothstep(life * 0.68, life, age))
				var edge: float = minf((9.0 + level * 0.75 + phase * 3.5) * 1.50 / _ui_scale, radius * 0.38)
				var ember: Color = tint.lerp(Color(1.0, 0.78, 0.32), smoothstep(life * 0.5, life, age) * 0.55)
				# Consecutive trajectory samples bend the tail with the falling tip;
				# a line back toward the burst would pin late embers into radial spokes.
				for tail in range(trails, 0, -1):
					var previous_age: float = age - float(tail) * life * 0.045
					if previous_age <= 0.0:
						continue
					var behind: Vector2 = _firework_point(origin, direction, reach, previous_age, life)
					var ahead: Vector2 = _firework_point(origin, direction, reach, previous_age + life * 0.045, life)
					var strength: float = 1.0 - float(tail) / float(trails + 1)
					var tangent: Vector2 = ahead - behind
					_stamp(STAR, behind.lerp(ahead, 0.5),
						Vector2(tangent.length() * 1.65 + edge * 0.30, edge * (0.25 + strength * 0.26)),
						Color(ember, opacity * strength * 0.86), tangent.angle())
				var shrink: float = lerpf(1.0, 0.56, smoothstep(life * 0.2, life, age))
				_stamp(STAR, point, Vector2.ONE * edge * shrink, Color(ember, opacity), angle)
				_stamp(STAR, point, Vector2.ONE * edge * shrink * 0.32, Color(1.0, 0.99, 0.86, opacity))


var checks: int = 0
var failures: int = 0
var _draw_cases: int = 0
var _attempted_stamps: int = 0
var _accepted_stamps: int = 0
var _clipped_stamps: int = 0
var _saturated_draws: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
	return condition


func _fixture(level: int, batch: bool, budget: int, scale_value: float = 1.0, clipped: bool = false, reduced: bool = false) -> Dictionary:
	return {"level": level, "batch": batch, "budget": budget, "scale": scale_value,
		"clipped": clipped, "reduced": reduced}


func _fixtures() -> Array[Dictionary]:
	return [
		_fixture(4, false, -1),
		_fixture(5, true, -1, 0.75, true),
		_fixture(6, false, -1, 1.5),
		_fixture(7, true, 64, 1.0, true),
		_fixture(8, false, 12, 0.75, true),
		_fixture(9, false, -1),
		_fixture(9, true, -1),
		_fixture(9, true, 0),
		_fixture(9, true, 1, 1.5, true),
		_fixture(9, true, 4),
		_fixture(9, true, 5),
		_fixture(9, true, 12, 0.75, true),
		_fixture(9, true, 64, 1.5, true),
		_fixture(4, false, -1, 1.0, false, true),
		_fixture(9, true, 12, 0.75, true, true),
	]


func _configure(view, fixture: Dictionary) -> void:
	var scale_value: float = float(fixture.scale)
	var clipped: bool = bool(fixture.clipped)
	var card := Vector2(168, 60) if clipped else Vector2(210, 88)
	view.configure(card, scale_value, int(fixture.level), Color("#35bec1"), bool(fixture.batch),
		view.margin_for(int(fixture.level), bool(fixture.batch), scale_value))
	var exclusions: Array[Rect2] = []
	if clipped:
		exclusions.append(Rect2(Vector2(50, 20), Vector2(70, 45)))
		exclusions.append(Rect2(Vector2(190, 75), Vector2(65, 50)))
	view.fit_area(Rect2(Vector2(-120, -40), Vector2(480, 180)) if clipped
		else Rect2(Vector2(-310, -140), Vector2(930, 430)), exclusions)
	view.set_particle_budget(int(fixture.budget))
	view.duration = view.duration_for(0.86 if fixture.batch else 1.95, int(fixture.level))
	view.anticipation_seconds = 0.30 if clipped else 0.04
	view.reduced_motion = bool(fixture.reduced)


func _ages(original) -> Array:
	var ages: Dictionary = {}
	for age: float in [-original.anticipation_seconds - 0.00000001, -original.anticipation_seconds,
		-0.00000001, 0.0, 0.00000001, 0.04, 0.12, 0.31, 0.62, 1.10, 1.72,
		original.duration - 0.00000001, original.duration, original.duration + 0.00000001]:
		ages[age] = true
	var groups: int = int(original.PROFILES[original.level - 1].bursts)
	if original._stamp_limit >= 0:
		groups = mini(groups, 2)
		groups = mini(groups, original._spark_count())
	var span: float = original._emission_span()
	for group in range(groups):
		var delay: float = span * float(group) / float(maxi(1, groups - 1))
		var life: float = minf(1.72, original.duration - delay - 0.08)
		for boundary: float in [delay, delay + life, delay + life * 0.045,
			delay + float(original._trail_count()) * life * 0.045]:
			for offset: float in [-0.00000001, 0.0, 0.00000001]:
				ages[boundary + offset] = true
	var result: Array = ages.keys()
	result.sort()
	return result


func _same_commands(a: Array, b: Array, label: String) -> bool:
	if not check(a.size() == b.size(), "%s count %d != %d" % [label, a.size(), b.size()]):
		return false
	for index in range(a.size()):
		checks += 1
		if a[index] != b[index]:
			return check(false, "%s command %d: %s != %s" % [label, index, str(a[index]), str(b[index])])
	return true


func _check_draw(original, current, age: float, label: String) -> bool:
	original.elapsed = age
	current.elapsed = age
	original.clear_capture()
	current.clear_capture()
	original.draw_capture()
	current.draw_capture()
	if not _same_commands(original.attempts, current.attempts, label + " attempted") \
		or not _same_commands(original.accepted, current.accepted, label + " fitted") \
		or not check(original._stamp_count == current._stamp_count, label + " accepted stamp count") \
		or not check(JSON.stringify(original.snapshot()) == JSON.stringify(current.snapshot()), label + " complete public snapshot bytes"):
		return false
	_draw_cases += 1
	_attempted_stamps += original.attempts.size()
	_accepted_stamps += original.accepted.size()
	for command: Array in original.accepted:
		if float(command[6]) < 1.0:
			_clipped_stamps += 1
	if current._stamp_limit > 0 and current._stamp_count == current._stamp_limit:
		_saturated_draws += 1
	if current._stamp_limit == 0:
		return check(current.attempts.is_empty() and current.accepted.is_empty(), label + " zero budget submits no attempts")
	return true


func _check_trajectories(original, current) -> bool:
	if not check(current.has_method("_firework_clock_point"), "Runtime group-clock helper is integrated"):
		return false
	for level in range(4, 10):
		for clipped: bool in [false, true]:
			var fixture: Dictionary = _fixture(level, true, -1, 0.75 if clipped else 1.5, clipped)
			_configure(original, fixture)
			_configure(current, fixture)
			for life: float in [0.41, 1.10, 1.72]:
				for age: float in [-0.01, 0.0, 0.00000001, life * 0.08, life * 0.5, life, life + 0.01]:
					var time: float = clampf(age / life, 0.0, 1.0)
					var travel: float = (1.0 - exp(-time * 4.5)) / (1.0 - exp(-4.5))
					var falling: float = maxf(0.0, (time - 0.08) / 0.92)
					for angle: float in [0.0, PI * 0.5, PI, 5.79]:
						var origin := Vector2(120.25, 45.75)
						var direction := Vector2.from_angle(angle)
						var reach: float = original._firework_radius() * 0.781
						var expected: Vector2 = original._firework_point(origin, direction, reach, age, life)
						var public_point: Vector2 = current._firework_point(origin, direction, reach, age, life)
						var prepared_point: Vector2 = current._firework_clock_point(origin, direction, reach,
							time, travel, falling, current._firework_vertical_scale())
						if not check(public_point == expected and prepared_point == expected,
							"Exact original/public/prepared trajectory Lv%d clipped=%s age=%.12f angle=%.12f" % [level, str(clipped), age, angle]):
							return false
	return true


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	var original := Original.new()
	var current := Capture.new()
	original.process_mode = Node.PROCESS_MODE_DISABLED
	current.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(original)
	root.add_child(current)
	var passing: bool = _check_trajectories(original, current)
	if passing:
		for fixture: Dictionary in _fixtures():
			_configure(original, fixture)
			_configure(current, fixture)
			for age: float in _ages(original):
				var label: String = "Lv%d batch=%s budget=%d scale=%.2f clip=%s reduced=%s age=%.12f" % [
					int(fixture.level), str(fixture.batch), int(fixture.budget), float(fixture.scale),
					str(fixture.clipped), str(fixture.reduced), age]
				if not _check_draw(original, current, age, label):
					passing = false
					break
			if not passing:
				break
	if passing:
		check(_draw_cases > 100 and _attempted_stamps > 10000 and _accepted_stamps > 1000,
			"Representative fixtures compare substantial original and runtime stamp work")
		check(_clipped_stamps > 0, "Short/excluded fixtures exercise fitted stamps")
		check(_saturated_draws > 0, "Secondary fixtures exercise the actual stamp cap")
	original.free()
	current.free()
	print("Word Jelly reveal group clock: %d checks, %d failures; %d draw cases, %d/%d attempted/accepted stamps" % [
		checks, failures, _draw_cases, _attempted_stamps, _accepted_stamps])
	quit(1 if failures > 0 else 0)
