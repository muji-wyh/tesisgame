extends RefCounted
## Combat owns its clock and receipts; rendering never decides hits or unlocks.

const Catalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const FREEZE_SECONDS: float = 3.0
const INK_SECONDS: float = 5.0
const BROKEN_SECONDS: float = 8.0
const FLIGHT_SECONDS: float = 0.85
const WINDUP_SECONDS: float = 0.65
const ENDING_SECONDS: float = 7.0
const MAX_EVENTS: int = 96
const MAX_RECEIPTS: int = 16384
const EPSILON: float = 0.000001

var error: String = ""
var definition: Dictionary = {}
var health: int = 0
var charge: int = 0
var clones: int = 0
var ward: int = 0
var broken_remaining: float = 0.0
var elapsed: float = 0.0
var phase: String = "inactive"
var ending_elapsed: float = 0.0
var outcome: String = ""
var _attack_in: float = 0.0
var _attack_index: int = 0
var _next_id: int = 1
var _statuses: Dictionary = {}
var _projectiles: Array[Dictionary] = []
var _specials: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _receipts: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func configure(value: Dictionary, seed_value: int = 0) -> void:
	definition = value.duplicate(true)
	health = int(definition.get("health", 0))
	phase = "watching" if bool(definition.get("intro", false)) else "arriving" if not definition.is_empty() else "inactive"
	charge = 0
	clones = 0
	ward = 0
	broken_remaining = 0.0
	elapsed = 0.0
	ending_elapsed = 0.0
	outcome = ""
	_attack_index = 0
	_next_id = 1
	_attack_in = 2.2
	_statuses.clear()
	_projectiles.clear()
	_specials.clear()
	_events.clear()
	_receipts.clear()
	_rng.seed = seed_value
	if not definition.is_empty():
		_event("entrance", {"text": definition.entrance})


func active() -> bool:
	return not definition.is_empty()


func fighting() -> bool:
	return phase in ["arriving", "fighting"]


func frozen(id: int) -> bool:
	return float(_statuses.get(id, {}).get("freeze", 0.0)) > EPSILON


func locks(id: int) -> int:
	return int(_statuses.get(id, {}).get("locks", 0))


func status(id: int) -> Dictionary:
	return _statuses.get(id, {}).duplicate(true)


func charge_merge(automatic: bool, complete: bool) -> void:
	if fighting() and not automatic:
		charge = mini(20, charge + (3 if complete else 1))


func collect_hit(receipt: String, level: int, combo: int, origin: Dictionary, wait_for_goals: bool = false) -> bool:
	error = ""
	if not fighting() or _receipts.has(receipt):
		return false
	if receipt.is_empty() or _receipts.size() >= MAX_RECEIPTS or level < 1 or level > 9:
		error = "This Boss attack needs a valid, unique collected-word receipt and merged level."
		return false
	_receipts[receipt] = true
	var damage: int = ceili(Catalog.DAMAGE[level] * (1.0 + minf(combo, 12) * 0.035) * (1.0 + charge * 0.025))
	charge = 0
	if clones > 0:
		clones -= 1
		_event("clone_hit", {"damage": 0, "origin": origin, "remaining": clones})
	elif ward > 0:
		ward -= 1
		_event("ward_hit", {"damage": 0, "origin": origin, "remaining": ward})
	else:
		health = maxi(0, health - damage)
		_event("player_hit", {"damage": damage, "level": level, "origin": origin, "health_after": health})
		if health == 0:
			if wait_for_goals:
				phase = "exhausted"
				_clear_attacks()
				_event("exhausted")
			else:
				begin_ending("defeated")
	return true


func unlock_pair(first: int, second: int) -> bool:
	var changed: bool = false
	for id: int in [first, second]:
		if locks(id) > 0:
			_statuses[id].locks = locks(id) - 1
			_event("unlock", {"target": id, "locks": locks(id)})
			changed = true
	return changed


func apply_status(kind: String, id: int) -> bool:
	if not fighting() or id < 0 or kind not in ["freeze", "ink", "lock"]:
		return false
	var state: Dictionary = _statuses.get(id, {"freeze": 0.0, "ink": 0.0, "locks": 0})
	if kind == "lock":
		if int(state.locks) >= 2:
			_event("lock_resisted", {"target": id})
			return false
		state.locks = int(state.locks) + 1
	else:
		state[kind] = FREEZE_SECONDS if kind == "freeze" else INK_SECONDS
	_statuses[id] = state
	_event("status_hit", {"target": id, "status": kind, "locks": int(state.locks)})
	return true


func forget(id: int) -> void:
	_statuses.erase(id)


func restore_jelly(id: int) -> void:
	_event("jelly_returned", {"target": id, "text": "That jelly is back in Next!"})


func begin_ending(result: String) -> void:
	if not active() or not outcome.is_empty():
		return
	outcome = "ambushed" if bool(definition.get("intro", false)) and result == "cleared" else result
	phase = "ending"
	ending_elapsed = 0.0
	_clear_attacks()
	_event("victory" if outcome == "defeated" else "taunt", {
		"text": definition.escape if outcome in ["ambushed", "defeated"] else "The compass stays!\nCan you beat my trick?",
		"reply": definition.reply if outcome in ["ambushed", "defeated"] else "We know your trick.\nOne more try!",
		"retreat": definition.retreat})


func _clear_attacks() -> void:
	_projectiles.clear()
	_specials.clear()
	for id: int in _statuses:
		if frozen(id):
			_event("thaw", {"target": id})
	_statuses.clear()
	broken_remaining = 0.0
	clones = 0
	ward = 0


func presentation_ready() -> bool:
	return not active() or phase == "done"


func next_boundary() -> float:
	if not fighting():
		return INF
	var boundary: float = maxf(0.0, _attack_in)
	for projectile: Dictionary in _projectiles:
		boundary = minf(boundary, maxf(0.0, WINDUP_SECONDS + FLIGHT_SECONDS - float(projectile.elapsed)))
	for special: Dictionary in _specials:
		boundary = minf(boundary, maxf(0.0, float(special.remaining)))
	for state: Dictionary in _statuses.values():
		for kind: String in ["freeze", "ink"]:
			if float(state[kind]) > EPSILON:
				boundary = minf(boundary, float(state[kind]))
	if broken_remaining > EPSILON:
		boundary = minf(boundary, broken_remaining)
	return boundary


func advance(delta: float, candidates: Array[Dictionary], allow_attacks: bool = true) -> Array[Dictionary]:
	var impacts: Array[Dictionary] = []
	if not active() or not is_finite(delta) or delta < 0.0:
		return impacts
	elapsed += delta
	if phase == "ending":
		ending_elapsed = minf(ENDING_SECONDS, ending_elapsed + delta)
		if ending_elapsed >= ENDING_SECONDS:
			phase = "done"
		return impacts
	if not fighting() or not allow_attacks:
		return impacts
	if phase == "arriving" and elapsed >= 1.6:
		phase = "fighting"
	var available: Dictionary = {}
	for tile: Dictionary in candidates:
		available[int(tile.id)] = tile
	for id: int in _statuses.keys():
		# Reserved bodies retain their status until their owning operation commits.
		for kind: String in ["freeze", "ink"]:
			var before: float = float(_statuses[id][kind])
			_statuses[id][kind] = maxf(0.0, before - delta)
			if before > EPSILON and float(_statuses[id][kind]) <= EPSILON:
				_event("thaw" if kind == "freeze" else "clear_ink", {"target": id})
	var was_broken: bool = broken_remaining > EPSILON
	broken_remaining = maxf(0.0, broken_remaining - delta)
	if was_broken and broken_remaining <= EPSILON:
		_event("sky_repaired")
	for special: Dictionary in _specials.duplicate():
		special.remaining = maxf(0.0, float(special.remaining) - delta)
		if float(special.remaining) <= EPSILON:
			_specials.erase(special)
			broken_remaining = BROKEN_SECONDS
			_event("kick", {"seconds": BROKEN_SECONDS, "text": "Two jellies at a time. My sky, my rules!"})
	for projectile: Dictionary in _projectiles.duplicate():
		projectile.elapsed = float(projectile.elapsed) + delta
		if float(projectile.elapsed) + EPSILON < WINDUP_SECONDS + FLIGHT_SECONDS:
			continue
		_projectiles.erase(projectile)
		var id: int = int(projectile.target)
		if not available.has(id) or int(available[id].column) != int(projectile.column) \
			or int(available[id].row) != int(projectile.row):
			_event("miss", {"target": id, "status": projectile.status})
			continue
		if projectile.status == "snatch":
			impacts.append({"kind": "snatch", "target": id})
			_event("snatch", {"target": id, "tile": available[id]})
		else:
			apply_status(str(projectile.status), id)
	_attack_in -= delta
	if _attack_in <= EPSILON:
		_attack_in = float(definition.interval)
		_launch(candidates)
	return impacts


func _launch(candidates: Array[Dictionary]) -> void:
	if candidates.is_empty():
		_attack_in = 0.5
		return
	var abilities: Array = definition.abilities
	# Showcase each new trick first, then combine it with the earlier abilities.
	var kind: String = str(definition.new_ability) if _attack_index == 0 else str(abilities[_attack_index % abilities.size()])
	_attack_index += 1
	match kind:
		"clones":
			clones = 2
			_event("clones", {"count": clones, "text": "Which Bramble is real?"})
		"kick":
			_specials.append({"kind": "kick", "remaining": WINDUP_SECONDS})
			_event("kick_windup", {"text": "Watch the sky!"})
		"ward":
			ward = 2
			_event("ward", {"text": "Two words to break my borrowed shield!"})
		"storm":
			for index in range(mini(3, candidates.size())):
				_projectile(["freeze", "ink", "lock"][index], candidates[index], index * 0.18)
			_event("storm", {"text": "One last rainbow of trouble!"})
		_:
			var eligible: Array[Dictionary] = candidates.filter(func(tile: Dictionary) -> bool:
				return not frozen(int(tile.id)) and (kind != "lock" or locks(int(tile.id)) < 2) \
					and (kind != "snatch" or tile.get("jelly_kind", "root") != "merged"))
			if not eligible.is_empty():
				_projectile(kind, eligible[_rng.randi_range(0, eligible.size() - 1)])


func _projectile(kind: String, tile: Dictionary, delay: float = 0.0) -> void:
	var shot: Dictionary = {"id": _next_id, "status": kind, "target": int(tile.id),
		"column": int(tile.column), "row": int(tile.row), "elapsed": -delay,
		"windup": WINDUP_SECONDS, "duration": FLIGHT_SECONDS}
	_projectiles.append(shot)
	var event: Dictionary = shot.duplicate()
	if _attack_index == 1 or _attack_index % 3 == 0:
		event["text"] = {"freeze": "That word is on ice!",
			"ink": "No peeking through ink!", "lock": "Match your way out!",
			"snatch": "Mine! Try building now!"}.get(kind, "")
	_event("throw", event)


func _event(kind: String, data: Dictionary = {}) -> void:
	var item: Dictionary = data.duplicate(true)
	item.merge({"kind": kind, "id": _next_id, "at": elapsed}, true)
	_next_id += 1
	_events.append(item)
	while _events.size() > MAX_EVENTS:
		_events.pop_front()


func snapshot() -> Dictionary:
	return {"active": active(), "definition": definition.duplicate(true), "phase": phase,
		"health": health, "max_health": int(definition.get("health", 0)), "charge": charge,
		"clones": clones, "ward": ward, "elapsed": elapsed, "outcome": outcome,
		"ending_elapsed": ending_elapsed, "broken_remaining": broken_remaining,
		"drop_limit": 2 if broken_remaining > EPSILON else 5,
		"statuses": _statuses.duplicate(true), "projectiles": _projectiles.duplicate(true),
		"events": _events.duplicate(true), "next_attack": _attack_in}
