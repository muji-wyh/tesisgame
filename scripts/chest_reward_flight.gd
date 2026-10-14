extends RefCounted
## One readable route for every earned chest, sampled by its owner's clock.

const TOP_SECONDS: float = 0.84
const TURN_START: float = 0.90
const REVEAL_SECONDS: float = 1.36
const TURN_END: float = 1.82
const RETURN_START: float = 1.98
const PERFORMANCE_SECONDS: float = 2.65


static func sample(age: float, rest: Vector2, safe: Rect2, edge: float, peak_edge: float) -> Dictionary:
	var middle: Vector2 = safe.get_center()
	var peak: float = maxf(edge, minf(peak_edge, minf(safe.size.x * 0.46, safe.size.y * 0.40)))
	var upper := Vector2(middle.x, safe.position.y + maxf(safe.size.y * 0.22, peak * 0.72))
	var center: Vector2 = rest
	var phase: String = "depart"
	if age < TOP_SECONDS:
		center = rest.lerp(upper, smoothstep(0.0, TOP_SECONDS, age))
	elif age < RETURN_START:
		phase = "celebrate"
		center = upper
	else:
		phase = "return"
		center = upper.lerp(rest, smoothstep(RETURN_START, PERFORMANCE_SECONDS, age))
	var growth: float = smoothstep(TOP_SECONDS, 1.25, age)
	var recovery: float = 1.0 - smoothstep(RETURN_START, PERFORMANCE_SECONDS, age)
	var turn: float = smoothstep(TURN_START, TURN_END, age)
	return {"center": center, "scale": lerpf(1.0, peak / maxf(edge, 1.0), growth * recovery),
		"yaw": turn * TAU, "roll": sin(turn * TAU) * 0.065, "phase": phase,
		"emphasis": smoothstep(0.0, 0.16, age) * recovery,
		"model_weight": smoothstep(TOP_SECONDS, TURN_START, age) * (1.0 - smoothstep(TURN_END, RETURN_START, age))}


static func fit(pose: Dictionary, local: Rect2, safe: Rect2) -> Dictionary:
	var result: Dictionary = pose.duplicate()
	var bounds: Rect2 = Transform2D(float(pose.roll), Vector2.ONE * float(pose.scale), 0.0, Vector2.ZERO) * local
	var fit_scale: float = minf(1.0, minf(safe.size.x / maxf(bounds.size.x, 1.0), safe.size.y / maxf(bounds.size.y, 1.0)))
	result.scale = float(pose.scale) * fit_scale
	bounds = Rect2(bounds.position * fit_scale, bounds.size * fit_scale)
	result.center = Vector2(pose.center).clamp(safe.position - bounds.position, safe.end - bounds.end)
	return result
