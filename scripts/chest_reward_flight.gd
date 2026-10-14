extends RefCounted
## One readable route for every earned chest, sampled by its owner's clock.

const TOP_SECONDS: float = 0.84
const TURN_START: float = 0.90
const REVEAL_SECONDS: float = 1.36
const TURN_END: float = 1.82
const RETURN_START: float = 1.98
const PERFORMANCE_SECONDS: float = 2.65


static func sample(age: float, rest: Vector2, safe: Rect2, edge: float, peak_edge: float, curved: bool = false) -> Dictionary:
	var middle: Vector2 = safe.get_center()
	var peak: float = maxf(edge, minf(peak_edge, minf(safe.size.x * 0.46, safe.size.y * 0.40)))
	var upper := Vector2(middle.x, safe.position.y + maxf(safe.size.y * 0.22, peak * 0.72))
	var phase: String = "depart"
	var travel: float = smoothstep(0.0, TOP_SECONDS, age)
	if age >= RETURN_START:
		phase = "return"
		travel = 1.0 - smoothstep(RETURN_START, PERFORMANCE_SECONDS, age)
	elif age >= TOP_SECONDS:
		phase = "celebrate"
	# One route coordinate ties approach size to position and retraces both on return.
	var center: Vector2 = _arc_center(rest, upper, safe, edge, travel) if curved else rest.lerp(upper, travel)
	var recovery: float = 1.0 - smoothstep(RETURN_START, PERFORMANCE_SECONDS, age)
	var turn: float = smoothstep(TURN_START, TURN_END, age)
	var pose: Dictionary = {"center": center, "scale": lerpf(1.0, peak / maxf(edge, 1.0), travel),
		"yaw": turn * TAU, "roll": sin(turn * TAU) * 0.065, "phase": phase,
		"pitch": 0.0, "depth": 0.0,
		"emphasis": smoothstep(0.0, 0.16, age) * recovery,
		"model_weight": smoothstep(TOP_SECONDS, TURN_START, age) * (1.0 - smoothstep(TURN_END, RETURN_START, age))}
	if curved:
		pose.depth = travel
		var bank: float = sin(travel * PI) if phase != "celebrate" else 0.0
		var hand: float = 1.0 if rest.x <= safe.get_center().x else -1.0
		pose.yaw += bank * hand * 0.48
		pose.pitch = bank * -0.22
		pose.roll += bank * hand * -0.12
		pose.model_weight = smoothstep(0.0, 0.05, travel)
	return pose


static func _arc_center(rest: Vector2, upper: Vector2, safe: Rect2, edge: float, progress: float) -> Vector2:
	var route: Vector2 = upper - rest
	var normal := Vector2(-route.y, route.x).normalized()
	if normal.x * (safe.get_center().x - rest.x) < 0.0:
		normal = -normal
	var bow: float = minf(route.length() * 0.46, minf(safe.size.x, safe.size.y) * 0.24)
	var control: Vector2 = rest.lerp(upper, 0.5) + normal * bow
	var inset: Rect2 = safe.grow(-minf(edge * 0.85, minf(safe.size.x, safe.size.y) * 0.2))
	control = control.clamp(inset.position, inset.end)
	return rest.lerp(control, progress).lerp(control.lerp(upper, progress), progress)


static func fit(pose: Dictionary, local: Rect2, safe: Rect2) -> Dictionary:
	var result: Dictionary = pose.duplicate()
	var bounds: Rect2 = Transform2D(float(pose.roll), Vector2.ONE * float(pose.scale), 0.0, Vector2.ZERO) * local
	var fit_scale: float = minf(1.0, minf(safe.size.x / maxf(bounds.size.x, 1.0), safe.size.y / maxf(bounds.size.y, 1.0)))
	result.scale = float(pose.scale) * fit_scale
	bounds = Rect2(bounds.position * fit_scale, bounds.size * fit_scale)
	result.center = Vector2(pose.center).clamp(safe.position - bounds.position, safe.end - bounds.end)
	return result
