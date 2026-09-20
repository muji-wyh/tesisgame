extends RefCounted

const REACTIONS = ["jump", "shy", "bonk"]
const CAPTIONS = {
	"jump": "Boing! Pip jumps for you!",
	"shy": "Aww! Pip feels shy!",
	"bonk": "Boop! Pip bounces right back!",
}
const DANCE_SECONDS = 5.28

# Part order: body, head, left wing, right wing, left foot, right foot.
# All pivots and translations use the original 120 x 120 SVG coordinates.
const _PIVOTS = [Vector2(61, 98), Vector2(61, 72), Vector2(33, 78),
	Vector2(88, 78), Vector2(40, 103), Vector2(80, 103)]
const _LEFT_TOE = Vector2(24, 110)
const _RIGHT_TOE = Vector2(99, 111)
const _CROUCH_SCALE = Vector2(1.08, 0.91)

# Each Vector3 holds translation x/y in pixels and rotation in degrees.
const _POSES = {
	"neutral": [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO,
		Vector3.ZERO, Vector3.ZERO, Vector3.ZERO],
	"crouch": [Vector3(0, 4, 0), Vector3(0, 5, 0), Vector3(0, 0, -12),
		Vector3(0, 0, 12), Vector3.ZERO, Vector3.ZERO],
	"jump": [Vector3(0, -22, -3), Vector3(0, -22, 4), Vector3(0, -22, 88),
		Vector3(0, -22, -88), Vector3(0, -20, -15), Vector3(0, -20, 15)],
	"jump_still": [Vector3(0, -3, 0), Vector3(0, -3, 0), Vector3(0, 0, 70),
		Vector3(0, 0, -70), Vector3(0, 0, -10), Vector3(0, 0, 10)],
	"shy": [Vector3(3, 0, 3), Vector3(2, 3, 9), Vector3(3, 0, 24),
		Vector3(-6, -36, -135), Vector3(0, 0, -5), Vector3(0, 0, -6)],
	"scratch": [Vector3(3, 0, 3), Vector3(2, 4, 7), Vector3(3, 0, 24),
		Vector3(-2, -33, -128), Vector3(0, 0, -5), Vector3(0, 0, -6)],
	"bonk": [Vector3(7, 4, 10), Vector3(8, 7, 15), Vector3(5, 3, 62),
		Vector3(5, 3, -70), Vector3(0, 0, -9), Vector3(0, 0, 12)],
	"rebound": [Vector3(-5, -3, -8), Vector3(-6, -5, -12), Vector3(0, 0, 34),
		Vector3(0, 0, -40), Vector3(0, 0, 7), Vector3(0, 0, -8)],
	"bonk_again": [Vector3(7, 4, 10), Vector3(0, 0, 4), Vector3(5, 3, 62),
		Vector3(5, 3, -70), Vector3(0, 0, -9), Vector3(0, 0, 12)],
	"bonk_still": [Vector3(0, 0, 6), Vector3(0, 0, 8), Vector3(5, 3, 62),
		Vector3(5, 3, -70), Vector3(0, 0, -9), Vector3(0, 0, 12)],
}
const _BEATS = {
	"jump": [[0.0, "neutral"], [0.16, "crouch"], [0.38, "jump"],
		[0.60, "jump"], [0.82, "crouch"], [1.0, "neutral"]],
	"shy": [[0.0, "neutral"], [0.20, "shy"], [0.36, "scratch"],
		[0.52, "shy"], [0.68, "scratch"], [0.84, "shy"], [1.0, "neutral"]],
	"bonk": [[0.0, "neutral"], [0.16, "bonk"], [0.36, "rebound"],
		[0.60, "bonk_again"], [0.82, "neutral"], [1.0, "neutral"]],
}


static func duration(kind: String) -> float:
	return 1.15 if kind == "shy" else 0.85


static func dance(seconds: float) -> Array[Transform2D]:
	var beat: float = fposmod(seconds, DANCE_SECONDS) / 0.44
	var left: float = sin(PI * clampf(beat / 2.0, 0.0, 1.0))
	var right: float = sin(PI * clampf((beat - 2.0) / 2.0, 0.0, 1.0))
	var amount: float = smoothstep(0.0, 1.0, (beat - 4.0) / 0.65) * smoothstep(0.0, 1.0, (12.0 - beat) / 0.65)
	var phase: float = (beat - 4.0) * PI
	var hips: float = sin(phase) * amount
	var follow: float = sin(phase - 0.32) * amount
	var bend: float = pow(cos(phase), 2.0) * amount
	var bounce: float = maxf(left, right)
	return [
		_transform(_PIVOTS[0], Vector2(hips * 6.0, bend * 1.5 - bounce), -hips * 2.0,
			Vector2(1.0 + bend * 0.045, 1.0 - bend * 0.06), hips * 18.0),
		_transform(_PIVOTS[1], Vector2(-follow * 1.8, bend * 3.0 - bounce * 1.5), -follow * 4.0),
		_transform(_PIVOTS[2], Vector2(follow * 3.0, bend * 1.8), left * 108.0 - amount * 22.0 - follow * 3.0),
		_transform(_PIVOTS[3], Vector2(follow * 3.0, bend * 1.8), -right * 108.0 + amount * 22.0 - follow * 3.0),
		# CSS shifts each foot's origin to its outside toe before rotating.
		_transform(_LEFT_TOE, Vector2.ZERO, -maxf(hips, 0.0) * 5.0 - right * 2.0),
		_transform(_RIGHT_TOE, Vector2.ZERO, maxf(-hips, 0.0) * 5.0 + left * 2.0),
	]


static func reaction(kind: String, progress: float, reduced: bool = false) -> Array[Transform2D]:
	# The loading-page function also falls back to bonk for an unknown name.
	var name: String = kind if kind in REACTIONS else "bonk"
	if reduced:
		var still: String = "shy" if name == "shy" else name + "_still"
		return _blend(still, still, 0.0)
	var beats: Array = _BEATS[name]
	var time: float = clampf(progress, 0.0, 1.0)
	for index in range(1, beats.size()):
		var end: float = beats[index][0]
		if time <= end:
			var start: float = beats[index - 1][0]
			# Smoothstep closely follows CSS ease-in-out, applied per keyframe interval.
			var weight: float = smoothstep(0.0, 1.0, (time - start) / (end - start))
			return _blend(beats[index - 1][1], beats[index][1], weight)
	return _blend("neutral", "neutral", 0.0)


static func _blend(from: String, to: String, weight: float) -> Array[Transform2D]:
	var first: Array = _POSES[from]
	var last: Array = _POSES[to]
	var result: Array[Transform2D] = []
	for index in range(_PIVOTS.size()):
		var source: Vector3 = first[index]
		var pose: Vector3 = source.lerp(last[index], weight)
		var stretch := Vector2.ONE
		if index == 0:
			var source_scale: Vector2 = _CROUCH_SCALE if from == "crouch" else Vector2.ONE
			var target_scale: Vector2 = _CROUCH_SCALE if to == "crouch" else Vector2.ONE
			stretch = source_scale.lerp(target_scale, weight)
		result.append(_transform(_PIVOTS[index], Vector2(pose.x, pose.y), pose.z, stretch))
	return result


static func _transform(pivot: Vector2, translation: Vector2, degrees: float,
		stretch: Vector2 = Vector2.ONE, skew_degrees: float = 0.0) -> Transform2D:
	var angle: float = deg_to_rad(degrees)
	var shear: float = tan(deg_to_rad(skew_degrees))
	var cosine: float = cos(angle)
	var sine: float = sin(angle)
	# CSS composes translate * rotate * skewX * scale around transform-origin.
	# Supply the complete affine transform, so callers do not add another pivot.
	var axis_x := Vector2(cosine, sine) * stretch.x
	var axis_y := Vector2(cosine * shear - sine, sine * shear + cosine) * stretch.y
	var origin: Vector2 = pivot + translation - axis_x * pivot.x - axis_y * pivot.y
	return Transform2D(axis_x, axis_y, origin)
