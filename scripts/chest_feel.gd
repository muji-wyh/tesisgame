extends RefCounted

const CANCEL_SECONDS: float = 0.12
const HOLD_SECONDS: float = 1.2
const BUILDUP_SECONDS: float = 2.0
const ANTICIPATION_TIME: float = 1.94
const UNLOCK_TIME: float = BUILDUP_SECONDS + 0.08
const RELEASE_TIME: float = BUILDUP_SECONDS + 0.16
const SETTLE_TIME: float = BUILDUP_SECONDS + 0.95
const OPEN_SECONDS: float = BUILDUP_SECONDS + 1.8
const HOLD_PULSE_TIMES := [0.08, 0.40, 0.68, 0.91, 1.12]
const PULSE_TIMES := [0.11, 0.30, 0.48, 0.65, 0.81, 0.96, 1.10, 1.23,
	1.35, 1.46, 1.56, 1.65, 1.73, 1.80, 1.86]
const FLASH_COLORS := {"spring": Color("#89ef9c"), "summer": Color("#ffcd51"),
	"autumn": Color("#ff9b45"), "winter": Color("#8ccfff"), "ocean": Color("#4be6e0"),
	"space": Color("#b994ff"), "jungle": Color("#a9e74b"), "candy": Color("#ff92d4")}


static func progress(elapsed: float) -> float:
	return clampf((HOLD_SECONDS + elapsed) / (HOLD_SECONDS + RELEASE_TIME), 0.0, 1.0)


static func tension(elapsed: float) -> float:
	# Negative opening time represents the confirmation hold. Neither the
	# pressure nor the sound starts its crescendo again when that hold ends.
	return pow(clampf((HOLD_SECONDS + elapsed) / (HOLD_SECONDS + ANTICIPATION_TIME), 0.0, 1.0), 0.72)


static func buildup_intensity(elapsed: float) -> float:
	if not is_finite(elapsed):
		return 0.0
	# Motion and light reserve more range for the last third of the hold.
	# Sound keeps its existing energy curve and exact authored beat times.
	return pow(progress(elapsed), 1.35)


static func _buildup_sway(elapsed: float) -> float:
	var beat_count: int = HOLD_PULSE_TIMES.size() + PULSE_TIMES.size()
	for ordinal in range(beat_count - 1, -1, -1):
		var holding: bool = ordinal < HOLD_PULSE_TIMES.size()
		var index: int = ordinal if holding else ordinal - HOLD_PULSE_TIMES.size()
		var beat: float = float(HOLD_PULSE_TIMES[index]) - HOLD_SECONDS if holding else float(PULSE_TIMES[index])
		if elapsed < beat:
			continue
		var next: float = ANTICIPATION_TIME
		if holding:
			next = float(HOLD_PULSE_TIMES[index + 1]) - HOLD_SECONDS if index + 1 < HOLD_PULSE_TIMES.size() else float(PULSE_TIMES[0])
		elif index + 1 < PULSE_TIMES.size():
			next = float(PULSE_TIMES[index + 1])
		# Alternating half-swings follow the same intervals as the audible
		# strikes. Keep this continuous clock when a delivered strike is late;
		# only its separate contact impulse follows the latched audio clock.
		var phase: float = (elapsed - beat) / maxf(0.001, next - beat)
		return sin(phase * PI) * (1.0 if ordinal % 2 == 0 else -1.0)
	return 0.0


static func buildup_motion(elapsed: float, pulse_time: float = -INF) -> float:
	if not is_finite(elapsed) or elapsed < -HOLD_SECONDS or elapsed >= RELEASE_TIME + 0.075:
		return 0.0
	if elapsed >= RELEASE_TIME:
		# Retain the exact last loaded pose as the release takes its weight.
		# The small-stage pixel floor consumes this same short return envelope.
		return buildup_motion(RELEASE_TIME - 0.000001) * (1.0 - smoothstep(RELEASE_TIME, RELEASE_TIME + 0.075, elapsed))
	var holding: bool = elapsed < 0.0
	if is_inf(pulse_time):
		pulse_time = elapsed + HOLD_SECONDS if holding else elapsed
	var sustain: float = smoothstep(0.38, 0.78, progress(elapsed))
	var handover: float = smoothstep(1.80, ANTICIPATION_TIME, elapsed)
	var strike: float = pulse_motion(pulse_time, holding)
	var sway: float = _buildup_sway(elapsed)
	var motion: float = strike * (1.0 - sustain * 0.45) * (1.0 - handover)
	motion += sway * (sustain * 0.50 + handover * 0.35)
	return motion * lerpf(0.80, 2.55, buildup_intensity(elapsed))


static func pulse_duration(index: int, holding: bool = false) -> float:
	var beats: Array = HOLD_PULSE_TIMES if holding else PULSE_TIMES
	var end: float = HOLD_SECONDS + float(PULSE_TIMES[0]) if holding else ANTICIPATION_TIME
	var next: float = float(beats[index + 1]) if index + 1 < beats.size() else end
	return minf(0.24, (next - float(beats[index])) * 0.90)


static func _pulse_state(elapsed: float, holding: bool = false) -> Vector3:
	if elapsed >= (HOLD_SECONDS if holding else ANTICIPATION_TIME):
		return Vector3.ZERO
	var beats: Array = HOLD_PULSE_TIMES if holding else PULSE_TIMES
	for index in range(beats.size() - 1, -1, -1):
		var beat: float = float(beats[index])
		var age: float = elapsed - beat
		if age >= 0.0:
			var duration: float = pulse_duration(index, holding)
			var phase: float = clampf(age / duration, 0.0, 1.0)
			var energy: float = tension(beat - HOLD_SECONDS if holding else beat)
			var direction: int = index + (0 if holding else HOLD_PULSE_TIMES.size())
			return Vector3(phase, 0.28 + energy * 0.72 if phase < 1.0 else 0.0,
				1.0 if direction % 2 == 0 else -1.0)
	return Vector3.ZERO


static func pulse_strength(elapsed: float, holding: bool = false) -> float:
	var pulse: Vector3 = _pulse_state(elapsed, holding)
	return pulse.y * (1.0 - smoothstep(0.15, 1.0, pulse.x))


static func pulse_motion(elapsed: float, holding: bool = false) -> float:
	var pulse: Vector3 = _pulse_state(elapsed, holding)
	# A mass accelerates into its impact instead of teleporting to full tilt.
	# A small immediate response bridges the audio device's output latency.
	var kick: float = lerpf(0.18, 1.0, smoothstep(0.0, 0.25, pulse.x))
	kick *= 1.0 - smoothstep(0.30, 0.78, pulse.x)
	kick -= sin(smoothstep(0.66, 1.0, pulse.x) * PI) * 0.12
	return pulse.y * kick * pulse.z


static func release_flash(elapsed: float) -> float:
	var age: float = elapsed - RELEASE_TIME
	if age < 0.0 or age >= 1.02:
		return 0.0
	return lerpf(0.70, 1.0, smoothstep(0.0, 0.045, age)) * (1.0 - smoothstep(0.12, 1.02, age))


static func final_drive(elapsed: float) -> float:
	# The last roll becomes continuous pressure instead of stopping in mid-air.
	return smoothstep(1.80, RELEASE_TIME, elapsed)


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
	# The initial gap, pressure release and impact belong to one beat. The
	# remainder brakes into a physical stop rather than delaying the first gap.
	var driven: float = 1.0 - pow(1.0 - value, 3.0)
	match theme_id:
		"summer":
			# The solar mechanism releases quickly and brakes before its stop.
			return driven
		"autumn":
			return lerpf(driven, smoothstep(0.0, 1.0, value), 0.25)
		"winter":
			return driven
		"space":
			return driven
		"candy":
			return 1.0 - exp(-value * 6.0) * cos(value * 9.5) if value < 1.0 else 1.0
		"jungle":
			return driven + sin(value * PI) * 0.045
		_:
			return driven


static func body_pose(theme_id: String, pressure: float, progress: float, time: float, opening_now: bool, pulse_time: float = -INF) -> Dictionary:
	var feel: Dictionary = PROFILES.get(theme_id, PROFILES.spring)
	var rocking: float = 0.040 if theme_id == "candy" else 0.024 + float(feel.tension) * 2.0
	if is_inf(pulse_time):
		pulse_time = time
	if opening_now and time < RELEASE_TIME:
		var energy: float = tension(time)
		pressure = 0.30 + energy * 0.70
	var offset := Vector2(0.0, float(feel.press) * pressure)
	var scale := Vector2.ONE
	var rotation: float = 0.0
	if pressure > 0.0:
		if theme_id == "candy":
			scale = Vector2(1.0 + pressure * 0.045, 1.0 - pressure * 0.065)
	if (not opening_now and pressure > 0.0) or (opening_now and time < RELEASE_TIME):
		var elapsed: float = time if opening_now else time - HOLD_SECONDS
		var motion: float = buildup_motion(elapsed, pulse_time)
		var strength: float = pulse_strength(pulse_time, not opening_now)
		var drive: float = final_drive(time) if opening_now else 0.0
		offset.x = motion * shake_distance(theme_id) - drive * 0.004
		offset.y += strength * 0.008 + drive * 0.010
		rotation = motion * rocking - drive * 0.010
		if theme_id == "candy":
			scale += Vector2(0.018, -0.025) * (strength + drive * 0.6)
		return {"offset": offset, "scale": scale, "rotation": rotation}
	if opening_now:
		var preparation: float = 1.0 - smoothstep(RELEASE_TIME, RELEASE_TIME + 0.075, time)
		offset = Vector2(-0.004, float(feel.press) + 0.010) * preparation
		var loaded_motion: float = buildup_motion(time)
		offset.x += loaded_motion * shake_distance(theme_id)
		rotation = loaded_motion * rocking - 0.010 * preparation
		var strike_age: float = maxf(0.0, time - RELEASE_TIME)
		var recoil: float = sin(minf(strike_age / 0.18, 1.0) * PI)
		# The floor takes the release impulse while the lid moves upward.
		offset.y += recoil * (0.028 if theme_id == "autumn" else 0.018)
		var settle: float = exp(-maxf(0.0, time - SETTLE_TIME) * 16.0) * sin(maxf(0.0, time - SETTLE_TIME) * 24.0)
		match theme_id:
			"spring": offset.y -= recoil * 0.007
			"summer": offset.y += recoil * 0.004
			"autumn": offset.y += recoil * 0.012 + settle * 0.004
			"winter": offset.x += sin(strike_age * 32.0) * exp(-strike_age * 13.0) * 0.003
			"ocean":
				offset.y -= sin(clampf(strike_age / 1.45, 0.0, 1.0) * PI) * 0.020
				rotation += sin(strike_age * 5.0) * exp(-strike_age * 2.8) * 0.018
			"space": offset.y -= smoothstep(RELEASE_TIME, SETTLE_TIME, time) * 0.025
			"jungle": rotation += sin(strike_age * 10.0) * exp(-strike_age * 5.0) * 0.027
			"candy":
				var bounce: float = sin(strike_age * 15.0) * exp(-strike_age * 4.8)
				scale = Vector2(1.0 + preparation * 0.0558 - bounce * 0.070,
					1.0 - preparation * 0.080 + bounce * 0.100)
				offset.y -= absf(bounce) * 0.025
	return {"offset": offset, "scale": scale, "rotation": rotation}


static func shake_distance(theme_id: String) -> float:
	return 0.012 + float(PROFILES.get(theme_id, PROFILES.spring).tension) * 1.8
