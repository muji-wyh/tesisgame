extends RefCounted
## A bounded, base-excited spring in Pip's 120-unit artwork coordinates.

const SUBSTEP := 1.0 / 120.0
const MAX_OFFSET := 3.2
const MAX_ANGLE := PI / 22.5

var offset := Vector2.ZERO
var velocity := Vector2.ZERO
var angle := 0.0
var angular_velocity := 0.0
var platform_velocity := 0.0
var _pending_distance := 0.0
var _direction := 1.0


func reset() -> void:
	offset = Vector2.ZERO
	velocity = Vector2.ZERO
	angle = 0.0
	angular_velocity = 0.0
	platform_velocity = 0.0
	_pending_distance = 0.0


func push(stage_distance: float, direction: float) -> void:
	if not is_finite(stage_distance):
		return
	_pending_distance = clampf(_pending_distance + stage_distance, -2000.0, 2000.0)
	_direction = -1.0 if direction < 0.0 else 1.0


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var elapsed: float = minf(delta, 0.1)
	var measured_speed: float = clampf(_pending_distance / elapsed, -1200.0, 1200.0)
	_pending_distance = 0.0
	# Filter integer scroll steps before applying the platform's change in speed.
	var next_speed: float = lerpf(platform_velocity, measured_speed, 1.0 - exp(-elapsed * 22.0))
	var change: float = next_speed - platform_velocity
	platform_velocity = next_speed
	velocity.y = clampf(velocity.y - change * 0.065, -60.0, 60.0)
	angular_velocity = clampf(angular_velocity - change * 0.0025 * _direction, -2.0, 2.0)
	var remaining: float = elapsed
	while remaining > 0.000001:
		var step: float = minf(SUBSTEP, remaining)
		velocity.y += (-144.0 * offset.y - 18.0 * velocity.y) * step
		offset.y = clampf(offset.y + velocity.y * step, -MAX_OFFSET, MAX_OFFSET)
		if absf(offset.y) >= MAX_OFFSET and signf(offset.y) == signf(velocity.y):
			velocity.y = 0.0
		angular_velocity += (-120.0 * angle - 15.0 * angular_velocity) * step
		angle = clampf(angle + angular_velocity * step, -MAX_ANGLE, MAX_ANGLE)
		if absf(angle) >= MAX_ANGLE and signf(angle) == signf(angular_velocity):
			angular_velocity = 0.0
		remaining -= step
	if not is_active():
		reset()


func is_active() -> bool:
	return _pending_distance != 0.0 or absf(platform_velocity) > 0.5 \
		or offset.length() > 0.012 or velocity.length() > 0.12 \
		or absf(angle) > 0.001 or absf(angular_velocity) > 0.01


func snapshot() -> Dictionary:
	return {"offset": [offset.x, offset.y], "velocity": [velocity.x, velocity.y],
		"angle": angle, "angular_velocity": angular_velocity,
		"platform_velocity": platform_velocity}
