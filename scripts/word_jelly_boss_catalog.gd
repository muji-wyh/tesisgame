extends RefCounted
## One recurring trickster, eight earned rematches, and a nonpunitive opening ambush.

const STAGES: Array[int] = [3, 5, 7, 9, 18, 36, 63, 99]
const LEGACY_STAGES: Array[int] = [9, 18, 27, 36, 45, 63, 81, 99]
const DAMAGE: Array[int] = [0, 14, 38, 72, 116, 176, 248, 344, 464, 620]
const TITLES: Array[String] = [
	"The Compass Thief", "Ink at the Crossing", "The Locksmith",
	"Three Brambles", "The Broken Sky", "Catch and Release",
	"The Borrowed Crown", "The Last Laugh"]
const ABILITIES: Array[String] = ["freeze", "ink", "lock", "clones", "kick", "snatch", "ward", "storm"]
const HEALTH: Array[int] = [98, 168, 245, 350, 490, 630, 840, 1120]
const RETREATS: Array[String] = ["scramble", "trick", "swagger", "panic", "trick", "scramble", "swagger", "panic"]
const ENTRANCES: Array[String] = [
	"Still chasing me?\nBeat my ice first!",
	"No reading, no compass.\nHere comes the ink!",
	"The compass is locked.\nMatch your way in!",
	"Find the real me.\nThen try to catch me!",
	"My sky. My rules.\nWatch your next move!",
	"Building that word?\nNot if I grab it!",
	"You broke every trick?\nTry my shield!",
	"No more running.\nCome take the compass!"]
const ESCAPES: Array[String] = [
	"You broke my ice?!\nThis isn't over!",
	"My ink... all gone?!\nNext time, locks!",
	"You broke every lock!\nI need a new trick!",
	"Even my doubles?!\nI'm out of here!",
	"My big kick failed?!\nTime for plan B!",
	"Fine! Keep your words!\nYou can't catch me!",
	"You broke my shield?!\nOne last showdown!",
	"All right. You win.\nThe compass is yours."]
const REPLIES: Array[String] = [
	"Ice trick beaten!\nNext stop: Stage 5!",
	"Ink trick beaten!\nNext stop: Stage 7!",
	"Locks broken!\nNext stop: Stage 9!",
	"Found the real thief!\nNext stop: Stage 18!",
	"Our sky is back!\nNext stop: Stage 36!",
	"Our words stay here!\nNext stop: Stage 63!",
	"No more hiding!\nFinal stop: Stage 99!",
	"We won it back!\nHome at last."]


static func encounter(number: int, intro: bool = false) -> Dictionary:
	if intro and number == 1:
		return {"id": 0, "stage": 1, "intro": true, "name": "Bramble", "title": "A Sneaky Visitor",
			"health": 98, "interval": 8.0, "abilities": ["freeze"], "new_ability": "freeze",
			"retreat": "swagger", "entrance": "What a fine compass!\nI'll take it!",
			"next_stage": STAGES[0],
			"escape": "Mine now!\nCatch me at Stage 3!",
			"reply": "That compass is ours.\nWe're coming, Bramble!"}
	var index: int = STAGES.find(number)
	if index < 0:
		return {}
	return {"id": index + 1, "stage": number, "intro": false, "name": "Bramble",
		"title": TITLES[index], "health": HEALTH[index], "interval": maxf(3.2, 7.0 - index * 0.5),
		"abilities": ABILITIES.slice(0, index + 1), "new_ability": ABILITIES[index],
		"retreat": RETREATS[index], "entrance": ENTRANCES[index], "escape": ESCAPES[index],
		"reply": REPLIES[index], "next_stage": STAGES[index + 1] if index + 1 < STAGES.size() else 0}


static func chase_target(highest_cleared: int) -> int:
	for number: int in STAGES:
		if number > highest_cleared:
			return number
	return 0


static func merged_level(victories: Array) -> int:
	var distinct: Dictionary = {}
	for id: Variant in victories:
		if id is int and id >= 1 and id <= STAGES.size():
			distinct[id] = true
	return 1 + distinct.size()


static func map_markers(frontier: int) -> Array[int]:
	var result: Array[int] = []
	var future_added: bool = false
	for number: int in STAGES:
		if number <= frontier or not future_added:
			result.append(number)
		if number >= frontier:
			future_added = true
	return result
