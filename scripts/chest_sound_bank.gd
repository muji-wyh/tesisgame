extends RefCounted

const THEMES := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]
const CUES := ["press", "charge", "step", "step-detail", "step-roll", "cancel", "opening", "unlock", "release", "settle", "reward"]
const SAMPLE_RATE := 11025
const BODY_FREQUENCIES := {
	"spring": 112.0, "summer": 98.0, "autumn": 82.0, "winter": 128.0,
	"ocean": 78.0, "space": 90.0, "jungle": 102.0, "candy": 118.0,
}
const PRESSURE_FREQUENCIES := {
	"spring": 360.0, "summer": 240.0, "autumn": 210.0, "winter": 680.0,
	"ocean": 140.0, "space": 310.0, "jungle": 260.0, "candy": 330.0,
}
const PROFILES := {
	"spring": [246.0, 0.22, 0.23],
	"summer": [340.0, 0.5, 0.18],
	"autumn": [154.0, 0.22, 0.32],
	"winter": [510.0, 0.08, 0.5],
	"ocean": [110.0, 0.55, 0.06],
	"space": [122.0, 0.32, 0.2],
	"jungle": [193.0, 0.43, 0.3],
	"candy": [185.0, 0.22, 0.16],
}
const PAYOFF_PROFILES := {
	"spring": [523.25, 0.46, 3600.0, 0.15, 0.006],
	"summer": [587.33, 0.76, 4600.0, 0.13, 0.008],
	"autumn": [392.00, 0.40, 2700.0, 0.12, 0.014],
	"winter": [783.99, 0.42, 5200.0, 0.21, 0.004],
	"ocean": [392.00, 0.62, 1800.0, 0.17, 0.010],
	"space": [440.00, 0.69, 4100.0, 0.16, 0.012],
	"jungle": [493.88, 0.57, 2900.0, 0.12, 0.016],
	"candy": [659.25, 0.39, 3800.0, 0.20, 0.008],
}
const SHIMMER_RATIOS := [1.0, 1.498, 2.008, 2.756, 3.73]
const SHIMMER_PHASES := [0.17, 1.09, 2.37, 0.64, 1.83]


static func theme_id(value: String) -> String:
	return value if value in THEMES else "spring"


static func path_for(theme: String, cue: String) -> String:
	if cue not in CUES:
		return ""
	return "res://assets/audio/chests/%s-%s.wav" % [theme_id(theme), cue]


static func pulse_cue(energy: float) -> String:
	return "step-roll" if energy >= 0.82 else ("step-detail" if energy >= 0.56 else "step")


static func _weighted_contact(time: float, base: float, duration: float, decay: float) -> float:
	if time < 0.0 or time >= duration:
		return 0.0
	var phase: float = TAU * base * (time + 0.13 * 0.025 * (1.0 - exp(-time / 0.025)))
	var body: float = sin(phase) + 0.72 * sin(phase * 2.03) + 0.38 * sin(phase * 3.97) + 0.15 * sin(phase * 6.13)
	return body * minf(1.0, time / 0.004) * exp(-time / decay) * minf(1.0, (duration - time) / 0.045)


static func _bloom_envelope(time: float, duration: float) -> float:
	if time < 0.0 or time >= duration:
		return 0.0
	return (1.0 - exp(-time / 0.028)) * exp(-time / 0.20) * minf(1.0, (duration - time) / 0.085)


static func _shimmer(time: float, duration: float, base: float, spread: float, attack: float = 0.022) -> float:
	if time < 0.0 or time >= duration:
		return 0.0
	var sound: float = 0.0
	for index in range(SHIMMER_RATIOS.size()):
		var phase: float = TAU * base * float(SHIMMER_RATIOS[index]) * time + float(SHIMMER_PHASES[index])
		var cluster: float = sin(phase) + 0.38 * sin(phase * (1.0 + spread))
		sound += cluster * exp(-time * index * 1.7) / (1.0 + index * 1.8)
	return sound * (1.0 - exp(-time / attack)) * exp(-time / 0.25) * minf(1.0, (duration - time) / 0.095)


static func fallback(theme: String, cue: String) -> AudioStreamWAV:
	# A small, deterministic material texture covers missing bundled recordings.
	# It is rendered only on first use and never schedules a later replacement.
	# The authored Foley assets contain the more detailed leaf/hinge/air layers.
	theme = theme_id(theme)
	var profile: Array = PROFILES[theme]
	var duration: float = 0.64 if cue == "charge" else (0.74 if cue == "reward" else 0.2)
	var impact: bool = cue.begins_with("step") or cue in ["release", "settle"]
	var strike_stage: int = ["step", "step-detail", "step-roll"].find(cue)
	if impact:
		duration = 0.68 if cue == "release" else (0.48 if cue == "settle" else 0.24)
	elif cue == "opening":
		duration = 0.24
	var frames: int = roundi(duration * SAMPLE_RATE)
	var samples := PackedByteArray()
	samples.resize(frames * 2)
	var rendered := PackedFloat32Array()
	rendered.resize(frames)
	var rng := RandomNumberGenerator.new()
	rng.seed = (theme + "/" + cue).hash()
	var filtered: float = 0.0
	var payoff: Array = PAYOFF_PROFILES[theme]
	var payoff_cue: bool = cue in ["release", "reward"]
	var payoff_air: float = 0.0
	var payoff_dark: float = 0.0
	var payoff_filter: float = 1.0 - exp(-TAU * minf(float(payoff[2]), SAMPLE_RATE * 0.45) / SAMPLE_RATE)
	var dark_filter: float = 1.0 - exp(-TAU * 360.0 / SAMPLE_RATE)
	var base: float = profile[0] * (0.75 if cue in ["cancel", "settle"] else 1.0)
	if cue == "charge":
		base = PRESSURE_FREQUENCIES[theme]
	var energy: float = 0.0
	var peak: float = 0.0
	for index in range(frames):
		var time: float = float(index) / SAMPLE_RATE
		var noise: float = rng.randf_range(-1.0, 1.0)
		var filter_rate: float = float(profile[2])
		if cue == "opening":
			filter_rate = 1.0 - exp(-TAU * (550.0 + 4100.0 * pow(minf(time / 0.215, 1.0), 2.0)) / SAMPLE_RATE)
		filtered += filter_rate * (noise - filtered)
		if payoff_cue:
			payoff_air += payoff_filter * (noise - payoff_air)
			payoff_dark += dark_filter * (payoff_air - payoff_dark)
		var envelope: float = minf(time / 0.004, 1.0) * exp(-time * 18.0) * minf(float(frames - 1 - index) / (SAMPLE_RATE * 0.024), 1.0)
		if cue == "charge":
			# Keep fallback pressure sustained too. All rhythmic attacks come
			# from the shared pulse events, never from this texture's loop seam.
			envelope = minf(time / 0.004, 1.0) * minf(float(frames - 1 - index) / (SAMPLE_RATE * 0.008), 1.0)
		var phase: float = TAU * base * time
		if theme == "candy" and cue != "charge":
			phase += TAU * 440.0 * time * time
		elif theme == "space":
			phase += 0.65 * sin(TAU * 43.0 * time)
		elif theme == "jungle":
			phase += 1.1 * sin(TAU * 27.0 * time)
		var body: float = sin(phase) + 0.28 * sin(phase * (2.83 if theme == "winter" else 2.71)) * (1.0 if cue == "charge" else exp(-time * 20.0))
		var sample: float = (body * 0.25 + filtered * float(profile[1])) * envelope
		if cue == "charge":
			# Friction rises separately from the fixed, low chest resonance.
			sample = (body * 0.075 + filtered * float(profile[1]) * 1.5) * envelope
		elif cue == "opening":
			var rise: float = minf(time / 0.215, 1.0)
			var rise_phase: float = TAU * (float(BODY_FREQUENCIES[theme]) * 2.3 * time + 1450.0 * time * time)
			sample = (filtered * 0.72 + sin(rise_phase) * 0.16 + sin(rise_phase * 1.51) * 0.07) * (0.16 + 0.84 * rise * rise)
			sample *= minf(time / 0.008, 1.0) * minf(float(frames - 1 - index) / (SAMPLE_RATE * 0.014), 1.0)
		elif cue == "reward":
			# The saved reward resolves upward through diffuse material overtones.
			# It stays separate from the release, including when persistence retries.
			var note: float = float(payoff[0])
			var spread: float = float(payoff[4])
			sample *= 0.48
			sample += _weighted_contact(time - 0.002, note * 0.5, 0.13, 0.025) * 0.08
			sample += (payoff_air - payoff_dark * 0.72) * _bloom_envelope(time - 0.012, 0.37) * float(payoff[1]) * 0.18
			sample += _shimmer(time - 0.008, 0.57, note, spread, 0.009) * 0.28
			sample += _shimmer(time - 0.105, 0.56, note * 1.25, spread, 0.012) * 0.18
			sample += _shimmer(time - 0.205, 0.50, note * 1.5, spread, 0.015) * 0.30
			sample = 0.8 * tanh(sample / 0.8)
			sample *= minf(time / 0.003, 1.0) * minf(float(frames - 1 - index) / (SAMPLE_RATE * 0.018), 1.0)
		elif impact:
			var releasing: bool = cue == "release"
			var settling: bool = cue == "settle"
			var impact_phase: float = TAU * float(BODY_FREQUENCIES[theme]) * time
			var weight: float = sin(impact_phase) + 0.55 * sin(impact_phase * 2.03) + 0.22 * sin(impact_phase * 3.81)
			var pressure: float = minf(time / 0.018, 1.0) * exp(-time / 0.041)
			sample = weight * pressure * 0.75
			sample += (body * 0.035 + filtered * 0.07) * exp(-time / 0.01)
			if strike_stage >= 1:
				sample += (sin(impact_phase * 3.1) * 0.12 + filtered * 0.22) * minf(time / 0.012, 1.0) * exp(-time / 0.04)
			if strike_stage >= 2:
				sample += ((noise - filtered) * 0.40 + sin(impact_phase * 8.3) * 0.12) * minf(time / 0.010, 1.0) * exp(-time / 0.045)
			if releasing:
				# A quick crack and phone-audible cavity open into the same broad
				# air and harmonic bloom as the authored material payoff.
				var contact_base: float = maxf(86.0, float(BODY_FREQUENCIES[theme]))
				sample = _weighted_contact(time, contact_base, 0.36, 0.085) * 1.25
				sample += (filtered * 0.40 + (noise - filtered) * 0.22) * exp(-time / 0.005)
				sample += body * 0.10 * envelope
				sample += (sin(impact_phase * 3.1) + 0.35 * sin(impact_phase * 5.97)) * minf(time / 0.006, 1.0) * exp(-time / 0.045) * 0.20
				sample += (payoff_air - payoff_dark * 0.72) * _bloom_envelope(time - 0.014, 0.57) * float(payoff[1]) * 1.9
				sample += _shimmer(time - 0.018, 0.58, float(payoff[0]), float(payoff[4])) * float(payoff[3]) * 1.85
			elif settling:
				var contact_base: float = maxf(90.0, float(BODY_FREQUENCIES[theme]) * 1.10)
				sample = _weighted_contact(time, contact_base, 0.19, 0.042) * 0.80
				sample += _weighted_contact(time - 0.065, contact_base * 0.94, 0.13, 0.028) * 0.19
				sample += (body * 0.04 + filtered * 0.16) * envelope * exp(-time / 0.020)
			if releasing or settling:
				sample = 0.8 * tanh(sample / 0.8)
			sample *= minf(time / 0.002, 1.0) * minf(float(frames - 1 - index) / (SAMPLE_RATE * 0.045), 1.0)
			if not releasing and not settling:
				sample *= 1.0 - smoothstep(0.15, 0.19, time)
		rendered[index] = sample
		energy += sample * sample
		peak = maxf(peak, absf(sample))
	var gain: float = 1.0
	if impact or cue in ["charge", "opening", "reward"]:
		var target: float = 0.12 if cue in ["charge", "reward"] else (0.17 if cue == "release" else (0.085 if cue == "settle" else (0.11 if cue == "opening" else [0.07, 0.075, 0.082][strike_stage])))
		gain = minf(target / maxf(sqrt(energy / frames), 0.000001), 0.75 / maxf(peak, 0.000001))
	for index in range(frames):
		samples.encode_s16(index * 2, roundi(clampf(rendered[index] * gain, -0.75, 0.75) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = samples
	if cue == "charge":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frames
	return stream
