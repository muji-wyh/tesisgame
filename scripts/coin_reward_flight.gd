extends Control
## A visual receipt: every arriving sprite releases its share to the counter.

signal arrived(value: int)
signal completed
const Style = preload("res://scripts/ui_style.gd")
const COINS = preload("res://assets/coins/gold-coins.png")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const BURST_SECONDS: float = 0.46
const TRAVEL_SECONDS: float = 0.68
var counter: Control
var reduced_motion: bool = false
var _events: Array[Dictionary] = []
var _seen: Dictionary = {}
var _visual_total: int = 0
var _elapsed: float = 0.0


func _init() -> void:
	name = "ChestCoins"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 85


func sync(balance: int) -> void:
	_events.clear()
	_visual_total = balance
	if is_instance_valid(counter):
		counter.sync(balance)
	queue_redraw()


func present(id: String, reward: Dictionary, source: Vector2) -> void:
	if _seen.has(id) or int(reward.get("amount", 0)) <= 0:
		return
	_seen[id] = true
	# Background settlement may already have reconciled this durable receipt.
	# A later retry must not wind the counter backward and replay its deposit.
	if _visual_total >= int(reward.after):
		return
	if _events.is_empty():
		_visual_total = int(reward.before)
		counter.sync(_visual_total)
	var count: int = clampi(7 + int(reward.amount) / 50, 8, 14)
	_events.append({"id": id, "amount": int(reward.amount), "source": source,
		"elapsed": 0.0, "count": count, "arrivals": 0})
	queue_redraw()


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	counter.reduced_motion = reduced_motion
	_elapsed += delta
	for event in _events:
		event.elapsed += delta
		var count: int = event.count
		for index in range(int(event.arrivals), count):
			var arrival: float = 0.24 if reduced_motion else BURST_SECONDS + TRAVEL_SECONDS + index * 0.045
			if event.elapsed < arrival:
				break
			var share: int = floori(float((index + 1) * int(event.amount)) / count) - floori(float(index * int(event.amount)) / count)
			_visual_total += share
			event.arrivals += 1
			counter.arrive(_visual_total)
			arrived.emit(_visual_total)
	var had_events: bool = not _events.is_empty()
	_events = _events.filter(func(event: Dictionary) -> bool: return event.arrivals < event.count)
	if had_events and _events.is_empty():
		completed.emit()
	counter.advance(delta)
	if had_events:
		queue_redraw()


func snapshot() -> Dictionary:
	return {"active": not _events.is_empty(), "flights": _events.size(),
		"arrived_balance": _visual_total, "displayed": counter.displayed if is_instance_valid(counter) else 0.0,
		"target": counter.target if is_instance_valid(counter) else 0}


func _draw() -> void:
	if not is_instance_valid(counter):
		return
	var s: float = Style.ui_scale(self)
	var destination: Vector2 = counter.icon_center() - global_position
	for event in _events:
		var source: Vector2 = event.source - global_position
		var age: float = event.elapsed
		var amount_alpha: float = clampf(age / 0.14, 0.0, 1.0) * clampf((1.25 - age) / 0.28, 0.0, 1.0)
		var label_at: Vector2 = source + Vector2(0, -114 / s)
		if not reduced_motion:
			label_at.y -= 14 / s * minf(1.0, age)
		draw_string_outline(Style.HEADING_FONT, label_at - Vector2(90 / s, 0), "+%d" % event.amount,
			HORIZONTAL_ALIGNMENT_CENTER, 180 / s, ceili(28 / s), ceili(4 / s), Color("#fff6da", amount_alpha))
		draw_string(Style.HEADING_FONT, label_at - Vector2(90 / s, 0), "+%d" % event.amount,
			HORIZONTAL_ALIGNMENT_CENTER, 180 / s, ceili(28 / s), Color("#b17516", amount_alpha))
		for index in range(int(event.arrivals), int(event.count)):
			var local_age: float = maxf(0.0, age - index * 0.045)
			var spread := Vector2((float(index) / maxf(1, event.count - 1) - 0.5) * 142 / s,
				-(65.0 + sin(index * 2.4) * 18.0) / s)
			var launch: Vector2 = source + spread
			var point: Vector2
			var scale_factor: float = 1.0
			if reduced_motion:
				point = source + Vector2((index - event.count * 0.5) * 5 / s, -12 / s)
			elif local_age < BURST_SECONDS:
				var p: float = local_age / BURST_SECONDS
				point = source.lerp(launch, 1.0 - pow(1.0 - p, 2))
				point.y -= sin(p * PI) * 26 / s
				scale_factor = lerpf(0.55, 1.0, minf(1.0, p * 4))
			else:
				var p: float = clampf((local_age - BURST_SECONDS) / TRAVEL_SECONDS, 0, 1)
				var eased: float = p * p * (3.0 - 2.0 * p)
				var bend := Vector2(launch.x + (destination.x - launch.x) * 0.12, minf(launch.y, destination.y) - 70 / s)
				point = launch.lerp(bend, eased).lerp(bend.lerp(destination, eased), eased)
				scale_factor = lerpf(1.0, 0.56, p)
			var side: float = 33 / s * scale_factor
			# Authored views are distinct perspectives, not sequential spin frames.
			var frame: int = index % 4 if not reduced_motion else 0
			var region := Rect2(Vector2(frame % 2, frame / 2) * 128, Vector2.ONE * 128)
			draw_texture_rect(GLOW, Rect2(point - Vector2.ONE * side, Vector2.ONE * side * 2), false, Color("#ffc864", 0.18))
			draw_set_transform(point, 0.0 if reduced_motion else sin(local_age * 4 + index) * 0.24)
			draw_texture_rect_region(COINS, Rect2(-Vector2.ONE * side * 0.5, Vector2.ONE * side), region)
			draw_set_transform(Vector2.ZERO)
