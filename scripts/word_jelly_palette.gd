extends RefCounted
## Stable exact-word pairs, with ordered completion hints for the held chunk.

const HUES: Array[float] = [0.40, 0.98, 0.57, 0.09, 0.75, 0.03, 0.49, 0.29, 0.65, 0.89, 0.15, 0.81]
const Model = preload("res://scripts/word_jelly_model.gd")
static var _hues: Array[float] = HUES.duplicate()
var colors: Dictionary = {}
var _signature: String = ""
var compatibility: Callable

static func hue(index: int) -> float:
	# A crowded board still needs distinct colors, rather than modulo-four skins.
	while index >= _hues.size():
		var hues: Array[float] = _hues.duplicate()
		hues.sort()
		var widest: float = -1.0
		var next: float = 0.0
		for slot in range(hues.size()):
			var end: float = hues[slot + 1] if slot + 1 < hues.size() else hues[0] + 1.0
			if end - hues[slot] > widest:
				widest = end - hues[slot]
				next = fposmod(hues[slot] + widest * 0.5, 1.0)
		_hues.append(next)
	return _hues[maxi(0, index)]

static func completes(a: Dictionary, b: Dictionary, words: Dictionary) -> bool:
	return int(a.get("id", -1)) != int(b.get("id", -1)) and words.has(Model.normalize_word(str(a.get("text", "")) + str(b.get("text", ""))))

func _compatible(a: Dictionary, b: Dictionary, words: Dictionary) -> bool:
	return bool(compatibility.call(a, b)) if compatibility.is_valid() else completes(a, b, words)

func clear() -> void:
	colors.clear()
	_signature = ""

func update(items: Array[Dictionary], words: Dictionary, reserved: Array[int] = []) -> void:
	var signature: String = ""
	for item: Dictionary in items:
		signature += "%d:%s;" % [int(item.id), str(item.text)]
	signature += str(reserved)
	if signature == _signature:
		return
	_signature = signature
	var groups: Array[Array] = []
	var paired: Dictionary = {}
	# Keep existing valid pairs before matching new arrivals. Each body belongs
	# to one idle pair: compatibility is not transitive (ca+t and ca+n).
	for preserve: bool in [true, false]:
		for a: Dictionary in items:
			if paired.has(int(a.id)):
				continue
			for b: Dictionary in items:
				if paired.has(int(b.id)) or int(a.id) == int(b.id):
					continue
				if preserve and (not colors.has(int(a.id)) or colors.get(int(a.id)) != colors.get(int(b.id), -1)):
					continue
				if _compatible(a, b, words) or _compatible(b, a, words):
					groups.append([int(a.id), int(b.id)])
					paired[int(a.id)] = true
					paired[int(b.id)] = true
					break
	for item: Dictionary in items:
		if not paired.has(int(item.id)):
			groups.append([int(item.id)])
	var used: Dictionary = {}
	for color: int in reserved:
		used[color] = true
	var next: Dictionary = {}
	var group_colors: Array[int] = []
	for group: Array in groups:
		var color: int = -1
		for id: int in group:
			if colors.has(id) and not used.has(int(colors[id])):
				color = int(colors[id])
				break
		group_colors.append(color)
		if color >= 0:
			used[color] = true
	for index in range(groups.size()):
		var color: int = group_colors[index]
		if color < 0:
			color = 0
			while used.has(color):
				color += 1
		used[color] = true
		for id: int in groups[index]:
			next[id] = color
	colors = next

func selected(items: Array[Dictionary], words: Dictionary, source_id: int) -> Dictionary:
	var result: Dictionary = colors.duplicate()
	var source: Dictionary = {}
	for item: Dictionary in items:
		if int(item.id) == source_id:
			source = item
			break
	if source.is_empty() or not colors.has(source_id):
		return result
	var source_color: int = int(colors[source_id])
	for item: Dictionary in items:
		var id: int = int(item.id)
		if id == source_id:
			continue
		if _compatible(source, item, words):
			result[id] = source_color
		# Incompatible targets retain their idle paint, even if the reverse word
		# shares a resting pair color. Only a forward completion earns a cue.
	return result
