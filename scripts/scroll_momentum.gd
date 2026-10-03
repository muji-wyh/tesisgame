extends RefCounted
## Axis-independent momentum in the scroll container's local coordinates.

const FRICTION := 6.5
const SAMPLE_WINDOW := 0.10
const RELEASE_TIMEOUT := 0.12
const MAX_SPEED := 2600.0
const MIN_LAUNCH_SPEED := 50.0
const STOP_SPEED := 8.0

var position := 0.0
var velocity := 0.0
var _samples: Array[Vector2] = []
var _direction := 0.0
var _unit_scale := 1.0


func is_active() -> bool:
	return velocity != 0.0


func stop() -> void:
	velocity = 0.0
	_samples.clear()
	_direction = 0.0


func begin(offset: float, time: float, unit_scale: float) -> void:
	stop()
	position = offset
	_unit_scale = maxf(0.01, unit_scale)
	_samples.append(Vector2(time, offset))


func track(offset: float, time: float) -> void:
	if is_equal_approx(offset, position):
		return
	var direction := signf(offset - position)
	if direction != _direction and _samples.size() > 1:
		# A last-moment reversal must fling in the new direction.
		_samples = [_samples.back()]
	_direction = direction
	position = offset
	_samples.append(Vector2(time, offset))
	while _samples.size() > 2 and time - _samples[0].x > SAMPLE_WINDOW:
		_samples.pop_front()


func release(time: float) -> void:
	if _samples.size() < 2 or time - _samples.back().x > RELEASE_TIMEOUT:
		stop()
		return
	var first := _samples[0]
	var elapsed := maxf(1.0 / 240.0, time - first.x)
	velocity = clampf((_samples.back().y - first.y) / elapsed, -MAX_SPEED / _unit_scale, MAX_SPEED / _unit_scale)
	if absf(velocity) < MIN_LAUNCH_SPEED / _unit_scale:
		velocity = 0.0
	_samples.clear()


func wheel(offset: float, distance: float, maximum: float, unit_scale: float) -> void:
	_unit_scale = maxf(0.01, unit_scale)
	if signf(distance) != signf(velocity):
		velocity = 0.0
	# A small immediate step acknowledges the notch; the remaining distance
	# settles smoothly, including a burst of consecutive wheel events.
	position = clampf(offset + distance * 0.25, 0.0, maximum)
	velocity = clampf(velocity + distance * 0.75 * FRICTION,
		-MAX_SPEED / _unit_scale, MAX_SPEED / _unit_scale)
	_stop_at_edge(maximum)


func advance(delta: float, maximum: float) -> float:
	if not is_active():
		return position
	# Integrate exponential damping exactly, so 30/60/120 Hz travel alike.
	var decay := exp(-FRICTION * maxf(0.0, delta))
	position = clampf(position + velocity * (1.0 - decay) / FRICTION, 0.0, maximum)
	velocity *= decay
	if absf(velocity) < STOP_SPEED / _unit_scale:
		velocity = 0.0
	_stop_at_edge(maximum)
	return position


func _stop_at_edge(maximum: float) -> void:
	if (position <= 0.0 and velocity < 0.0) or (position >= maximum and velocity > 0.0):
		velocity = 0.0
