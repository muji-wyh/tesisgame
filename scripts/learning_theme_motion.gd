extends RefCounted
## Reviewed sprite-sheet clips; no procedural substitutes for ambient artwork.

const Resolver = preload("res://scripts/learning_content_resolver.gd")
const MAX_CLIPS := 4


static func compile(profile: Dictionary, require_ready: bool = false) -> Dictionary:
	var motion: Variant = profile.get("ambient_motion", {})
	if not motion is Dictionary or motion.get("status") != "ready":
		return _failure("The workplace motion is waiting for review.") if require_ready else {"ok": true, "clips": []}
	var review: Variant = motion.get("review", {})
	var clips: Variant = motion.get("clips")
	if not review is Dictionary or review.get("status") != "reviewed" \
		or not clips is Array or clips.is_empty() or clips.size() > MAX_CLIPS:
		return _failure("The workplace motion needs reviewed, bounded clips.")
	var ids: Dictionary = {}
	for clip in clips:
		if not clip is Dictionary or not clip.get("id") is String or str(clip.id).is_empty() or ids.has(clip.id):
			return _failure("A workplace motion clip has an invalid or repeated identity.")
		ids[clip.id] = true
		if not Resolver._media_ready(clip.get("image", {})):
			return _failure("A workplace motion image is waiting for review.")
		for field in ["columns", "rows", "frame_count", "rest_frame"]:
			if not _integer(clip.get(field)):
				return _failure("A workplace motion frame index is invalid.")
		if clip.columns < 1 or clip.columns > 8 or clip.rows < 1 or clip.rows > 8 \
			or clip.frame_count < 2 or clip.frame_count > clip.columns * clip.rows \
			or clip.rest_frame < 0 or clip.rest_frame >= clip.frame_count:
			return _failure("A workplace motion frame is outside its sheet.")
		if not _number(clip.get("frames_per_second")) or clip.frames_per_second < 0.5 or clip.frames_per_second > 24:
			return _failure("A workplace motion frame rate is invalid.")
		var rect: Variant = clip.get("rect")
		if not rect is Array or rect.size() != 4:
			return _failure("A workplace motion placement is invalid.")
		for value in rect:
			if not _number(value) or value < 0 or value > 1:
				return _failure("A workplace motion placement is outside the composition.")
		if rect[2] <= 0 or rect[3] <= 0 or rect[0] + rect[2] > 1.000001 or rect[1] + rect[3] > 1.000001:
			return _failure("A workplace motion placement is outside the composition.")
	return {"ok": true, "clips": clips.duplicate(true)}


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _integer(value: Variant) -> bool:
	return _number(value) and float(value) == floor(float(value))


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "clips": []}
