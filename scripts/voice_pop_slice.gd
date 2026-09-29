extends RefCounted

# Presentation uses only the throw ID; it never consumes the gameplay RNG.
const MAX_EFFECTS: int = 6
const DURATION: float = 0.78
const STILL_DURATION: float = 0.32
const IMPACT_HOLD: float = 0.044
const BLADE_DURATION: float = 0.14


static func create(target: Dictionary, points: int, color: Color, combo: int = 1) -> Dictionary:
	return {"uid": int(target.uid), "word": target.word.duplicate(true),
		"center": target.center, "size": target.size, "rotation": float(target.rotation),
		"age": 0.0, "color": color, "points": points,
		"strength": 1.0 + 0.04 * clampi(combo - 1, 0, 5)}


static func tangent(uid: int) -> Vector2:
	var slopes: Array[float] = [-0.32, 0.20, -0.22, 0.34]
	return Vector2(1.0, slopes[posmod(uid - 1, slopes.size())]).normalized()


static func normal(uid: int) -> Vector2:
	var direction: Vector2 = tangent(uid)
	# Positive screen Y points down; the word belongs to this lower half.
	return Vector2(-direction.y, direction.x)


static func cut_origin(size: Vector2) -> Vector2:
	return Vector2(0.0, -size.y * 0.12)


static func pose(effect: Dictionary, side: float, reduced: bool = false) -> Dictionary:
	var age: float = maxf(0.0, float(effect.age))
	if reduced:
		return {"offset": Vector2.ZERO, "rotation": 0.0,
			"alpha": 1.0 - smoothstep(0.12, STILL_DURATION, age)}
	var flight: float = maxf(0.0, age - IMPACT_HOLD)
	var span: float = float(effect.size.x)
	var cut_normal: Vector2 = normal(int(effect.uid))
	var separation: float = span * (0.48 * flight + 0.13 * flight * flight)
	var offset: Vector2 = (cut_normal * side * separation).rotated(float(effect.rotation))
	offset.y += span * 1.28 * flight * flight
	return {"offset": offset, "rotation": side * flight * (0.65 + 0.08 * (int(effect.uid) % 3)),
		"alpha": 1.0 - smoothstep(0.42, DURATION, age)}


static func rounded_rect(size: Vector2, radius: float) -> PackedVector2Array:
	var half: Vector2 = size * 0.5
	var rounded: float = minf(radius, minf(half.x, half.y))
	var centers: Array[Vector2] = [Vector2(half.x - rounded, -half.y + rounded),
		Vector2(half.x - rounded, half.y - rounded), Vector2(-half.x + rounded, half.y - rounded),
		Vector2(-half.x + rounded, -half.y + rounded)]
	var result := PackedVector2Array()
	for corner in range(4):
		for step in range(7):
			var angle: float = -PI * 0.5 + float(corner) * PI * 0.5 + float(step) * PI / 12.0
			result.append(centers[corner] + Vector2(cos(angle), sin(angle)) * rounded)
	return result


static func clip_half(polygon: PackedVector2Array, origin: Vector2, normal: Vector2, side: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if polygon.is_empty():
		return result
	var previous: Vector2 = polygon[polygon.size() - 1]
	var previous_distance: float = (previous - origin).dot(normal) * side
	for current in polygon:
		var distance: float = (current - origin).dot(normal) * side
		if (distance >= 0.0) != (previous_distance >= 0.0):
			result.append(previous.lerp(current, previous_distance / (previous_distance - distance)))
		if distance >= 0.0:
			result.append(current)
		previous = current
		previous_distance = distance
	return result


static func texture_uv(polygon: PackedVector2Array, art_rect: Rect2) -> PackedVector2Array:
	var uv := PackedVector2Array()
	for point in polygon:
		uv.append((point - art_rect.position) / art_rect.size)
	return uv


static func seam(size: Vector2, radius: float, uid: int) -> PackedVector2Array:
	var polygon: PackedVector2Array = rounded_rect(size, radius)
	var origin: Vector2 = cut_origin(size)
	var cut_normal: Vector2 = normal(uid)
	var direction: Vector2 = tangent(uid)
	var intersections := PackedVector2Array()
	for index in range(polygon.size()):
		var first: Vector2 = polygon[index]
		var second: Vector2 = polygon[(index + 1) % polygon.size()]
		var first_distance: float = (first - origin).dot(cut_normal)
		var second_distance: float = (second - origin).dot(cut_normal)
		if is_zero_approx(first_distance):
			intersections.append(first)
		elif (first_distance > 0.0) != (second_distance > 0.0):
			intersections.append(first.lerp(second, first_distance / (first_distance - second_distance)))
	if intersections.size() < 2:
		return PackedVector2Array()
	var first: Vector2 = intersections[0]
	var last: Vector2 = intersections[0]
	for point in intersections:
		if point.dot(direction) < first.dot(direction):
			first = point
		if point.dot(direction) > last.dot(direction):
			last = point
	return PackedVector2Array([first, last])


static func blade_ribbon(effect: Dictionary, width: float, scale: float) -> PackedVector2Array:
	var age: float = float(effect.age)
	if age < 0.0 or age >= BLADE_DURATION:
		return PackedVector2Array()
	var direction: Vector2 = tangent(int(effect.uid))
	if int(effect.uid) % 2 == 0:
		direction = -direction
	var normal: Vector2 = direction.orthogonal()
	var head: float = lerpf(0.05, 1.45, ease(clampf(age / 0.11, 0.0, 1.0), 0.55))
	var tail: float = head - 1.8
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for index in range(17):
		var fraction: float = float(index) / 16.0
		var travel: float = lerpf(tail, head, fraction)
		var center: Vector2 = cut_origin(effect.size) + direction * travel * float(effect.size.x) * 0.57
		center += normal * sin(travel * 1.8) * 8.0 / scale
		var thickness: float = pow(sin(fraction * PI), 0.8) * width / scale
		upper.append(center + normal * thickness)
		lower.append(center - normal * thickness)
	lower.reverse()
	upper.append_array(lower)
	return upper
