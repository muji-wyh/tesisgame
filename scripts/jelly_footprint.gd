extends RefCounted
## Stable logical footprints measured at the minimum supported display scale.

const CELL_PITCH: int = 32
const FONT_SIZE: int = 16
const COLUMNS: int = 6
const MAX_ROWS: int = 2
const GAP: int = 3


static func plan(text: String, font: Font, break_offsets: Array = [],
	insets: Vector4 = Vector4(4, 3, 4, 3), reserved: Vector2 = Vector2.ZERO) -> Dictionary:
	if font == null or text.is_empty() or "\n" in text or "\r" in text or "\t" in text:
		return {"ok": false, "error": "A font and a single authored text string are required."}
	if minf(minf(insets.x, insets.y), minf(insets.z, insets.w)) < 0.0 or minf(reserved.x, reserved.y) < 0.0:
		return {"ok": false, "error": "Reserved artwork, badge space, and insets cannot be negative."}
	for metric: float in [insets.x, insets.y, insets.z, insets.w, reserved.x, reserved.y]:
		if not is_finite(metric):
			return {"ok": false, "error": "Layout reservations must be finite."}
	var previous: int = 0
	for offset: Variant in break_offsets:
		if (not offset is int and not offset is float) or not is_finite(float(offset)) \
			or float(offset) != floorf(float(offset)) or int(offset) <= previous or int(offset) >= text.length():
			return {"ok": false, "error": "Only increasing authored break offsets inside the text are accepted."}
		previous = int(offset)
	var line_height: float = ceilf(font.get_height(FONT_SIZE))
	if not is_finite(line_height) or line_height <= 0.0:
		return {"ok": false, "error": "The font does not provide usable metrics."}
	# Area first, then one row before two rows: stable across viewport changes.
	for area in range(1, COLUMNS * MAX_ROWS + 1):
		for rows in range(1, MAX_ROWS + 1):
			if area % rows != 0:
				continue
			var columns: int = area / rows
			if columns > COLUMNS:
				continue
			var width: float = columns * CELL_PITCH - GAP - insets.x - insets.z - reserved.x
			var height: float = rows * CELL_PITCH - GAP - insets.y - insets.w - reserved.y
			var maximum_lines: int = floori(height / line_height)
			if width <= 0.0 or maximum_lines < 1:
				continue
			var layout: Dictionary = _wrap(text, font, break_offsets, width, maximum_lines)
			if layout.ok:
				return {"ok": true, "error": "", "text": text, "width": columns, "height": rows,
					"font_size": FONT_SIZE, "cell_pitch": CELL_PITCH, "requires_read": false,
					"lines": layout.lines, "break_offsets": layout.break_offsets, "line_height": line_height}
	return {"ok": true, "error": "", "text": text, "width": COLUMNS, "height": MAX_ROWS,
		"font_size": FONT_SIZE, "cell_pitch": CELL_PITCH, "requires_read": true,
		"lines": [text], "break_offsets": [], "line_height": line_height}


static func _wrap(text: String, font: Font, offsets: Array, width: float, maximum_lines: int) -> Dictionary:
	var ends: Array = offsets.duplicate()
	ends.append(text.length())
	return _wrap_from(text, font, ends, width, maximum_lines, 0, {})


static func _wrap_from(text: String, font: Font, ends: Array, width: float, remaining: int,
	start: int, memo: Dictionary) -> Dictionary:
	if start == text.length():
		return {"ok": true, "lines": [], "break_offsets": []}
	if remaining <= 0:
		return {"ok": false}
	var key: String = "%d:%d" % [start, remaining]
	if memo.has(key):
		return memo[key]
	for index in range(ends.size() - 1, -1, -1):
		var end: int = int(ends[index])
		if end <= start:
			continue
		var segment: String = text.substr(start, end - start)
		if font.get_string_size(segment, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x > width:
			continue
		var tail: Dictionary = _wrap_from(text, font, ends, width, remaining - 1, end, memo)
		if tail.ok:
			var lines: Array = [segment]
			lines.append_array(tail.lines)
			var breaks: Array = [] if end == text.length() else [end]
			breaks.append_array(tail.break_offsets)
			var result: Dictionary = {"ok": true, "lines": lines, "break_offsets": breaks}
			memo[key] = result
			return result
	var failed: Dictionary = {"ok": false}
	memo[key] = failed
	return failed
