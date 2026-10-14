extends Control
## A visual receipt: every arriving sprite releases its share to the counter.

signal arrived(value: int)
signal release_sound
signal arrival_sound
signal spend_sound
signal settled
signal completed
const Style = preload("res://scripts/ui_style.gd")
const COINS = preload("res://assets/coins/gold-coins.png")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const COIN = preload("res://assets/coins/gold-coin.png")
const DEBIT_SECONDS: float = 0.76
const BURST_SECONDS: float = 0.46
const TRAVEL_SECONDS: float = 0.68
const SOUND_INTERVAL: float = 0.10
var counter: Control
var reduced_motion: bool = false
var _events: Array[Dictionary] = []
var _seen: Dictionary = {}
var _visual_total: int = 0
var _elapsed: float = 0.0
var _sound_cooldown: float = 0.0
var _debit: Dictionary = {}


func _init() -> void:
	name = "ChestCoins"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 85


func sync(balance: int) -> void:
	_events.clear()
	_debit.clear()
	_sound_cooldown = 0.0
	settled.emit()
	_visual_total = balance
	if is_instance_valid(counter):
		counter.sync(balance)
	queue_redraw()


func spend(receipt: Dictionary, destination: Vector2) -> void:
	if not receipt.get("ok", false) or receipt.get("duplicate", false) or int(receipt.get("amount", 0)) >= 0:
		return
	# Reconcile pending deposits before presenting this already-saved debit.
	sync(int(receipt.after))
	counter.reduced_motion = reduced_motion
	counter.debit(int(receipt.before), int(receipt.after))
	_debit = {"amount": -int(receipt.amount), "destination": destination, "elapsed": 0.0}
	spend_sound.emit()
	queue_redraw()


func present(id: String, reward: Dictionary, source: Vector2, with_release_sound: bool = false) -> void:
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
		"elapsed": 0.0, "count": count, "arrivals": 0, "release_pending": with_release_sound})
	queue_redraw()


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	counter.reduced_motion = reduced_motion
	_elapsed += delta
	_sound_cooldown = maxf(0.0, _sound_cooldown - delta)
	var had_debit: bool = not _debit.is_empty()
	if had_debit:
		_debit.elapsed += delta
		if float(_debit.elapsed) >= DEBIT_SECONDS:
			_debit.clear()
	var has_release: bool = false
	var has_arrivals: bool = false
	for event in _events:
		event.elapsed += delta
		var count: int = event.count
		if event.release_pending:
			event.release_pending = false
			var burst_end: float = 0.24 if reduced_motion else BURST_SECONDS + (count - 1) * 0.045
			has_release = has_release or event.elapsed < burst_end
		for index in range(int(event.arrivals), count):
			var arrival: float = 0.24 if reduced_motion else BURST_SECONDS + TRAVEL_SECONDS + index * 0.045
			if event.elapsed < arrival:
				break
			var share: int = floori(float((index + 1) * int(event.amount)) / count) - floori(float(index * int(event.amount)) / count)
			_visual_total += share
			event.arrivals += 1
			counter.arrive(_visual_total)
			arrived.emit(_visual_total)
			has_arrivals = true
	# A dense batch, reduced motion or a stalled frame gets one current beat.
	# Skipped accents are never queued, so audio cannot outlive the coin flight.
	if (has_release or has_arrivals) and _sound_cooldown <= 0.000001:
		_sound_cooldown = SOUND_INTERVAL
		if has_release:
			release_sound.emit()
		else:
			arrival_sound.emit()
	var had_events: bool = not _events.is_empty()
	_events = _events.filter(func(event: Dictionary) -> bool: return event.arrivals < event.count)
	if had_events and _events.is_empty():
		completed.emit()
	counter.advance(delta)
	if had_events or had_debit:
		queue_redraw()


func snapshot() -> Dictionary:
	return {"active": not _events.is_empty() or not _debit.is_empty(), "flights": _events.size(),
		"debit_active": not _debit.is_empty(), "debit_amount": int(_debit.get("amount", 0)),
		"arrived_balance": _visual_total, "displayed": counter.displayed if is_instance_valid(counter) else 0.0,
		"target": counter.target if is_instance_valid(counter) else 0}


func _draw() -> void:
	if not is_instance_valid(counter):
		return
	var s: float = Style.ui_scale(self)
	var destination: Vector2 = counter.icon_center() - global_position
	_draw_debit(destination, s)
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


func _draw_debit(source: Vector2, s: float) -> void:
	if _debit.is_empty():
		return
	var t: float = clampf(float(_debit.elapsed) / DEBIT_SECONDS, 0.0, 1.0)
	var alpha: float = minf(1.0, (1.0 - t) / 0.30)
	var label: String = "−%d" % int(_debit.amount)
	var width: float = 100.0 / s
	var at: Vector2 = counter.global_position - global_position + Vector2(counter.size.x * 0.5 - width * 0.5, counter.size.y + 15.0 / s)
	var stacked: bool = float(_debit.destination.y) > counter.global_position.y + counter.size.y
	if stacked:
		# Phone headers put Hint beneath the wallet; keep its bulb unobscured.
		at = counter.global_position - global_position + Vector2(-width + 18.0 / s, counter.size.y * 0.5 + 5.0 / s)
	if not reduced_motion:
		at.y += sin(t * PI * 0.5) * (-4.0 if stacked else 7.0) / s
	draw_string_outline(Style.HEADING_FONT, at, label, HORIZONTAL_ALIGNMENT_CENTER, width, ceili(16 / s), ceili(3 / s), Color("#fff7df", alpha))
	draw_string(Style.HEADING_FONT, at, label, HORIZONTAL_ALIGNMENT_CENTER, width, ceili(16 / s), Color("#a36628", alpha))
	if reduced_motion:
		return
	var p: float = clampf(float(_debit.elapsed) / 0.38, 0.0, 1.0)
	if p >= 1.0:
		return
	var end: Vector2 = _debit.destination - global_position
	var bend: Vector2 = (source + end) * 0.5 - Vector2(0, 22.0 / s)
	var point: Vector2 = source.lerp(bend, p).lerp(bend.lerp(end, p), p)
	var side: float = lerpf(17.0, 9.0, p) / s
	draw_texture_rect(GLOW, Rect2(point - Vector2.ONE * side, Vector2.ONE * side * 2.0), false, Color("#ffd781", 0.28))
	draw_texture_rect(COIN, Rect2(point - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, Color(1, 1, 1, minf(1.0, (1.0 - p) / 0.18)))
