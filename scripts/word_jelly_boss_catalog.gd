extends RefCounted
## One recurring trickster, eight earned rematches, and a nonpunitive opening ambush.

const STAGES: Array[int] = [9, 18, 27, 36, 45, 63, 81, 99]
const DAMAGE: Array[int] = [0, 14, 38, 72, 116, 176, 248, 344, 464, 620]
const TITLES: Array[String] = [
	"The Compass Thief", "Ink at the Crossing", "The Locksmith",
	"Three Brambles", "The Broken Sky", "Catch and Release",
	"The Borrowed Crown", "The Last Laugh"]
const ABILITIES: Array[String] = ["freeze", "ink", "lock", "clones", "kick", "snatch", "ward", "storm"]
const HEALTH: Array[int] = [98, 168, 245, 350, 490, 630, 840, 1120]
const RETREATS: Array[String] = ["scramble", "trick", "swagger", "panic", "trick", "scramble", "swagger", "panic"]
const ENTRANCES: Array[String] = [
	"My compass? You'll have to catch me first!",
	"Found me! Let's add a little ink.",
	"Your words look better under lock and key.",
	"One Bramble? Try finding three!",
	"I've outgrown this little sky!",
	"Nice jelly. May I borrow it?",
	"A crown, a shield, and one last trick!",
	"You followed me all this way. Let's finish this!"]
const ESCAPES: Array[String] = [
	"I'm not playing anymore! Follow the compass!",
	"Look over there! See you at the next crossing!",
	"That was only my warm-up. Just you wait!",
	"Three of me, and you still won? Time to go!",
	"I'll find something fun. Come find me!",
	"Fine, keep your jellies! I'll be back!",
	"Keep that piece. You haven't caught me yet!",
	"No more tricks. You earned the compass back."]
const REPLIES: Array[String] = [
	"We're coming for our compass!",
	"Your ink won't hide the trail.",
	"Every lock has a match.",
	"We know the real you now.",
	"We'll fix the sky and find you.",
	"Our words belong here.",
	"One more chase. No more running.",
	"Together, we found our way home."]


static func encounter(number: int, intro: bool = false) -> Dictionary:
	if intro and number == 1:
		return {"id": 0, "stage": 1, "intro": true, "name": "Bramble", "title": "A Sneaky Visitor",
			"health": 98, "interval": 8.0, "abilities": ["freeze"], "new_ability": "freeze",
			"retreat": "swagger", "entrance": "That Word Compass looks interesting!",
			"escape": "The compass is mine! Catch me at stage 9!",
			"reply": "We learned the words. Now let's get our compass back!"}
	var index: int = STAGES.find(number)
	if index < 0:
		return {}
	return {"id": index + 1, "stage": number, "intro": false, "name": "Bramble",
		"title": TITLES[index], "health": HEALTH[index], "interval": maxf(3.2, 7.0 - index * 0.5),
		"abilities": ABILITIES.slice(0, index + 1), "new_ability": ABILITIES[index],
		"retreat": RETREATS[index], "entrance": ENTRANCES[index], "escape": ESCAPES[index],
		"reply": REPLIES[index]}


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
