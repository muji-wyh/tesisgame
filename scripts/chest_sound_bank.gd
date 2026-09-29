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


static func fallback(theme: String, cue: String) -> AudioStreamWAV:
	# A small, deterministic material texture is available during download. It is
	# rendered only on first use and never awaits or schedules a later replacement.
	# The authored Foley assets contain the more detailed leaf/hinge/air layers.
	theme = theme_id(theme)
	var profile: Array = PROFILES[theme]
	var duration: float = 0.64 if cue == "charge" else (0.42 if cue == "reward" else 0.2)
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
		var envelope: float = minf(time / 0.004, 1.0) * exp(-time * 18.0) * minf(float(frames - 1 - index) / (SAMPLE_RATE * 0.024), 1.0)
		if cue == "charge":
			# Keep cold-cache pressure sustained too. All rhythmic attacks come
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
				# The cold-cache release has the same quick load, phone-audible
				# cavity harmonics and short dry tail as the authored material.
				var contact_base: float = maxf(86.0, float(BODY_FREQUENCIES[theme]))
				sample = _weighted_contact(time, contact_base, 0.38, 0.088) * 1.20
				sample += (filtered * 0.35 + (noise - filtered) * 0.11) * exp(-time / 0.006)
				sample += body * 0.045 * envelope * exp(-maxf(0.0, time - 0.04) * 16.0)
				sample += filtered * 0.10 * minf(time / 0.008, 1.0) * exp(-time / 0.035)
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
	if impact or cue in ["charge", "opening"]:
		var target: float = 0.12 if cue == "charge" else (0.15 if cue == "release" else (0.085 if cue == "settle" else (0.11 if cue == "opening" else [0.07, 0.075, 0.082][strike_stage])))
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
