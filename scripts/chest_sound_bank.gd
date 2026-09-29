extends RefCounted

const THEMES := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]
const CUES := ["press", "charge", "step", "cancel", "opening", "unlock", "release", "settle", "reward"]
const SAMPLE_RATE := 11025
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


static func fallback(theme: String, cue: String) -> AudioStreamWAV:
	# A small, deterministic material texture is available during download. It is
	# rendered only on first use and never awaits or schedules a later replacement.
	# The authored Foley assets contain the more detailed leaf/hinge/air layers.
	theme = theme_id(theme)
	var profile: Array = PROFILES[theme]
	var duration: float = 0.64 if cue == "charge" else (0.42 if cue == "reward" else 0.2)
	var frames: int = roundi(duration * SAMPLE_RATE)
	var samples := PackedByteArray()
	samples.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = (theme + "/" + cue).hash()
	var filtered: float = 0.0
	var base: float = profile[0] * (0.75 if cue in ["cancel", "settle"] else 1.0)
	for index in range(frames):
		var time: float = float(index) / SAMPLE_RATE
		filtered += float(profile[2]) * (rng.randf_range(-1.0, 1.0) - filtered)
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
			sample *= 0.64
		samples.encode_s16(index * 2, roundi(clampf(sample, -0.75, 0.75) * 32767.0))
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
