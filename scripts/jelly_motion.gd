extends RefCounted
## One clock for descent, planted compression, recovery, and input readiness.

const FOOT_Y: float = 285.0 / 320.0
const ARRIVAL_GRAVITY: float = 12.5
const COLLAPSE_GRAVITY: float = 78.125
const MAX_SETTLE_SECONDS: float = 1.26
const COMPRESSION_SECONDS: float = 0.055
const REBOUND_SECONDS: float = 0.105
const RECOVERY_SECONDS: float = 0.11


static func travel_rows(cell: Dictionary) -> float:
	# Arrivals enter from one cell above the clipped well. Local gravity only
	# traverses the cleared gap, keeping a collapse brisk after a successful match.
	if bool(cell.get("arrival", false)):
		return maxf(1.0, float(cell.get("falling_rows", 1)))
	return maxf(0.0, minf(float(cell.get("falling_rows", 0)), float(cell.get("row", 0))))


static func contact_at(cell: Dictionary) -> float:
	# Distance is measured in board rows, so gravity feels the same at every size.
	var gravity: float = ARRIVAL_GRAVITY if bool(cell.get("arrival", false)) else COLLAPSE_GRAVITY
	return sqrt(2.0 * maxf(1.0, travel_rows(cell)) / gravity)


static func ready_at(cell: Dictionary) -> float:
	return contact_at(cell) + COMPRESSION_SECONDS + REBOUND_SECONDS + RECOVERY_SECONDS


static func preview(elapsed: float, interval: float, index: int, reduced: bool = false) -> Dictionary:
	if reduced:
		return {"offset": Vector2.ZERO, "stretch": Vector2.ONE, "bend": 0.0, "beat": 0.0, "intensity": 0.0}
	var duration: float = maxf(0.1, interval)
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)
	var buildup: float = pow(progress, 2.4)
	# Integrating the rising frequency keeps phase continuous as the real supply
	# clock approaches release. No independent tween can outlive a paused round.
	var beat: float = TAU * duration * (progress + 0.875 * pow(progress, 4.0)) + float(index) * 1.31
	var amplitude: float = lerpf(0.006, 0.052, buildup)
	var height: float = 1.0 + sin(beat + 0.8) * lerpf(0.012, 0.078, buildup)
	return {
		"offset": Vector2(sin(beat) * amplitude, -absf(sin(beat * 0.82)) * amplitude * 0.4),
		"stretch": Vector2(1.0 / sqrt(height), height),
		"bend": lerpf(0.002, 0.014, buildup), "beat": beat,
		"intensity": lerpf(0.12, 1.0, buildup)
	}


static func sample(cell: Dictionary) -> Dictionary:
	var age: float = maxf(0.0, float(cell.get("age", 0.0)))
	var contact: float = contact_at(cell)
	var fall: float = clampf(age / contact, 0.0, 1.0)
	var after: float = maxf(0.0, age - contact)
	var impact: float = sqrt(clampf(travel_rows(cell) / 6.0, 0.0, 1.0))
	var squash: float = lerpf(0.14, 0.24, impact)
	var extension: float = lerpf(0.04, 0.08, impact)
	var height: float = 1.0
	if age < contact:
		height = 1.0 + extension * fall * fall
	elif after < COMPRESSION_SECONDS:
		height = lerpf(1.0 + extension, 1.0 - squash, sin(after / COMPRESSION_SECONDS * PI * 0.5))
	elif after < COMPRESSION_SECONDS + REBOUND_SECONDS:
		height = lerpf(1.0 - squash, 1.035, smoothstep(0.0, REBOUND_SECONDS, after - COMPRESSION_SECONDS))
	elif age < ready_at(cell):
		height = lerpf(1.035, 1.0, smoothstep(0.0, RECOVERY_SECONDS, after - COMPRESSION_SECONDS - REBOUND_SECONDS))
	return {
		"lift_rows": travel_rows(cell) * (1.0 - fall * fall),
		"stretch": Vector2(1.0 / sqrt(height), height),
		"compression": clampf((1.0 - height) / squash, 0.0, 1.0),
		"bend": absf(1.0 - height) * 0.045 if age >= contact else 0.0,
		"beat": after * 24.0,
		"opacity": smoothstep(0.0, 0.055, age)
	}
