extends RefCounted

const CANCEL_SECONDS: float = 0.12
const HOLD_SECONDS: float = 1.2
const BUILDUP_SECONDS: float = 2.0
const ANTICIPATION_TIME: float = 1.94
const UNLOCK_TIME: float = BUILDUP_SECONDS + 0.12
const RELEASE_TIME: float = BUILDUP_SECONDS + 0.32
const SETTLE_TIME: float = BUILDUP_SECONDS + 0.95
const OPEN_SECONDS: float = BUILDUP_SECONDS + 1.8
const PULSE_TIMES := [0.10, 0.50, 0.84, 1.12, 1.35, 1.53, 1.67, 1.78, 1.87]


static func progress(elapsed: float) -> float:
	return clampf((HOLD_SECONDS + elapsed) / (HOLD_SECONDS + RELEASE_TIME), 0.0, 1.0)


static func tension(elapsed: float) -> float:
	# Negative opening time represents the confirmation hold. Neither the
	# pressure nor the sound starts its crescendo again when that hold ends.
	return pow(clampf((HOLD_SECONDS + elapsed) / (HOLD_SECONDS + ANTICIPATION_TIME), 0.0, 1.0), 1.45)


static func pulse_duration(index: int) -> float:
	var next: float = float(PULSE_TIMES[index + 1]) if index + 1 < PULSE_TIMES.size() else ANTICIPATION_TIME
	return minf(0.24, (next - float(PULSE_TIMES[index])) * 0.90)


static func _pulse_state(elapsed: float) -> Vector3:
	if elapsed >= ANTICIPATION_TIME:
		return Vector3.ZERO
	for index in range(PULSE_TIMES.size() - 1, -1, -1):
		var beat: float = float(PULSE_TIMES[index])
		var age: float = elapsed - beat
		if age >= 0.0:
			var duration: float = pulse_duration(index)
			var phase: float = clampf(age / duration, 0.0, 1.0)
			return Vector3(phase, 0.28 + tension(beat) * 0.72 if phase < 1.0 else 0.0,
				1.0 if index % 2 == 0 else -1.0)
	return Vector3.ZERO


static func pulse_strength(elapsed: float) -> float:
	var pulse: Vector3 = _pulse_state(elapsed)
	return pulse.y * (1.0 - smoothstep(0.15, 1.0, pulse.x))


static func pulse_motion(elapsed: float) -> float:
	# Each audible strike starts one visible kick and a damped counter-swing.
	# Its return finishes before the next strike, even in the final fast roll.
	var pulse: Vector3 = _pulse_state(elapsed)
	# Give the attack enough width to read on a display instead of missing a
	# narrow sine peak between rendered frames as the beat intervals shorten.
	var kick: float = 1.0 - 0.30 * smoothstep(0.0, 0.35, pulse.x)
	kick -= 1.05 * smoothstep(0.35, 0.65, pulse.x)
	kick += 0.35 * smoothstep(0.65, 1.0, pulse.x)
	return pulse.y * kick * pulse.z


static func phase(elapsed: float) -> String:
	if elapsed >= RELEASE_TIME:
		return "release"
	if elapsed >= ANTICIPATION_TIME:
		return "anticipation"
	return "building" if elapsed >= ANTICIPATION_TIME * 0.45 else "gathering"


static func timeline() -> Array:
	var events: Array = []
	for index in range(PULSE_TIMES.size()):
		events.append({"cue": "tension_pulse", "step": index + 1, "time": PULSE_TIMES[index]})
	for step in range(1, 4):
		events.append({"cue": "charge_step", "step": step,
			"time": maxf(0.0, (HOLD_SECONDS + RELEASE_TIME) * float(step) / 3.0 - HOLD_SECONDS)})
	for event in [["anticipation", ANTICIPATION_TIME], ["unlock", UNLOCK_TIME], ["release", RELEASE_TIME], ["settle", SETTLE_TIME]]:
		events.append({"cue": event[0], "step": 0, "time": event[1]})
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.cue == "charge_step" and b.cue != "charge_step") if is_equal_approx(float(a.time), float(b.time)) else float(a.time) < float(b.time))
	return events

# Motion is expressed in chest-relative units; the view fits one measured
# envelope for the complete action instead of resizing as badges disappear.
const PROFILES: Dictionary = {
	"spring": {"material": "light_wood", "decoration": "petals", "press": 0.008, "tension": 0.0025, "frequency": 19.0, "hinge": 0.54, "stagger": 0.018, "spread": 0.12},
	"summer": {"material": "sun_mechanism", "decoration": "sun_rays", "press": 0.005, "tension": 0.0018, "frequency": 24.0, "hinge": 0.39, "stagger": 0.022, "spread": 0.13},
	"autumn": {"material": "heavy_wood", "decoration": "falling_leaves", "press": 0.013, "tension": 0.0012, "frequency": 14.0, "hinge": 0.68, "stagger": 0.025, "spread": 0.10},
	"winter": {"material": "ice_crystal", "decoration": "ice_facets", "press": 0.004, "tension": 0.0020, "frequency": 29.0, "hinge": 0.36, "stagger": 0.035, "spread": 0.11},
	"ocean": {"material": "pearl_shell", "decoration": "bubbles", "press": 0.007, "tension": 0.0015, "frequency": 12.0, "hinge": 0.61, "stagger": 0.042, "spread": 0.15},
	"space": {"material": "servo_core", "decoration": "orbit", "press": 0.003, "tension": 0.0010, "frequency": 32.0, "hinge": 0.48, "stagger": 0.028, "spread": 0.17},
	"jungle": {"material": "vine_wood", "decoration": "vine_leaves", "press": 0.010, "tension": 0.0028, "frequency": 16.0, "hinge": 0.57, "stagger": 0.032, "spread": 0.14},
	"candy": {"material": "soft_candy", "decoration": "sprinkles", "press": 0.020, "tension": 0.0030, "frequency": 21.0, "hinge": 0.44, "stagger": 0.030, "spread": 0.16}
}


static func profile(theme_id: String) -> Dictionary:
	return PROFILES.get(theme_id, PROFILES.spring).duplicate()


static func opening(theme_id: String, elapsed: float, index: int = 0) -> float:
	var feel: Dictionary = PROFILES.get(theme_id, PROFILES.spring)
	var delay: float = RELEASE_TIME + float(index) * float(feel.stagger)
	var value: float = clampf((elapsed - delay) / float(feel.hinge), 0.0, 1.0)
	match theme_id:
		"summer":
			# The solar mechanism releases quickly and brakes before its stop.
			return 1.0 - pow(1.0 - value, 3.0)
		"autumn":
			return smoothstep(0.0, 1.0, value * value)
		"winter":
			return smoothstep(0.0, 0.72, value)
		"space":
			return value * value * (3.0 - 2.0 * value)
		"candy":
			return 1.0 - exp(-value * 6.0) * cos(value * 9.5) if value < 1.0 else 1.0
		"jungle":
			return smoothstep(0.0, 1.0, value) + sin(value * PI) * 0.08
		_:
			return smoothstep(0.0, 1.0, value)


static func body_pose(theme_id: String, pressure: float, progress: float, time: float, opening_now: bool, pulse_time: float = -INF) -> Dictionary:
	var feel: Dictionary = PROFILES.get(theme_id, PROFILES.spring)
	if is_inf(pulse_time):
		pulse_time = time
	if opening_now and time < UNLOCK_TIME:
		var energy: float = tension(time)
		var strained: Dictionary = body_pose(theme_id, 0.30 + energy * 0.70, energy, 0.0, false)
		var strike: float = pulse_motion(pulse_time)
		strained.offset.x += strike * (0.011 + float(feel.tension) * 2.5)
		strained.offset.y += pulse_strength(pulse_time) * 0.006
		strained.rotation = strike * (0.015 if theme_id == "candy" else 0.009)
		if theme_id == "candy":
			strained.scale += Vector2(0.012, -0.018) * pulse_strength(pulse_time)
		return strained
	var offset := Vector2(0.0, float(feel.press) * pressure)
	var scale := Vector2.ONE
	var rotation: float = 0.0
	if pressure > 0.0:
		if theme_id == "candy":
			scale = Vector2(1.0 + pressure * 0.045, 1.0 - pressure * 0.065)
	if opening_now:
		var preparation: float = 1.0 - smoothstep(UNLOCK_TIME, RELEASE_TIME, time)
		offset = Vector2(0.0, float(feel.press) * preparation)
		var strike_age: float = maxf(0.0, time - RELEASE_TIME)
		var recoil: float = sin(minf(strike_age / 0.28, 1.0) * PI)
		var settle: float = exp(-maxf(0.0, time - SETTLE_TIME) * 16.0) * sin(maxf(0.0, time - SETTLE_TIME) * 24.0)
		match theme_id:
			"spring": offset.y -= recoil * 0.007
			"summer": offset.y += recoil * 0.004
			"autumn": offset.y += recoil * 0.012 + settle * 0.004
			"winter": offset.x = sin(strike_age * 32.0) * exp(-strike_age * 13.0) * 0.003
			"ocean":
				offset.y -= sin(clampf(strike_age / 1.45, 0.0, 1.0) * PI) * 0.020
				rotation = sin(strike_age * 5.0) * exp(-strike_age * 2.8) * 0.018
			"space": offset.y -= smoothstep(RELEASE_TIME, SETTLE_TIME, time) * 0.025
			"jungle": rotation = sin(strike_age * 10.0) * exp(-strike_age * 5.0) * 0.027
			"candy":
				var bounce: float = sin(strike_age * 15.0) * exp(-strike_age * 4.8)
				scale = Vector2(1.0 + preparation * 0.045 - bounce * 0.070,
					1.0 - preparation * 0.065 + bounce * 0.100)
				offset.y -= absf(bounce) * 0.025
	return {"offset": offset, "scale": scale, "rotation": rotation}
