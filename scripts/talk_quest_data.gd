extends RefCounted

const GameData = preload("res://scripts/game_data.gd")

# Reviewed story content. Runtime callers receive copies of the catalog.
const LEVEL_COUNT: int = 14
const CHEST_COUNT: int = 20
const REPAIR_COUNT: int = 5
const CHEST_DURATION: float = 5.0
const CHEST_HOLD_TIME: float = 1.20
const CHEST_REVEAL_TIME: float = 3.36
const HEALTH: Array[int] = [5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20, 22, 25, 28]
const LEVEL_WORDS: Array = [
	["door", "key", "bell", "lamp", "window", "chair", "flower", "cat"],
	["soap", "towel", "brush", "mirror", "hand", "water", "comb", "tooth"],
	["bread", "milk", "egg", "cup", "plate", "spoon", "apple", "bowl"],
	["shirt", "sock", "shoe", "hat", "coat", "dress", "pants", "glove"],
	["ball", "swing", "slide", "kite", "seesaw", "frisbee", "scooter", "bike"],
	["book", "pen", "pencil", "crayons", "table", "chair", "clock", "abacus"],
	["apple", "banana", "orange", "pear", "grape", "melon", "peach", "cherry", "mango", "plum"],
	["book", "lamp", "chair", "window", "pencil", "owl", "bear", "rabbit", "fox", "tree"],
	["lion", "tiger", "monkey", "panda", "zebra", "elephant", "giraffe", "penguin", "turtle", "parrot"],
	["bus", "car", "train", "truck", "bike", "scooter", "taxi", "van", "wheel", "plane"],
	["beach", "sand", "shell", "crab", "whale", "dolphin", "starfish", "seahorse", "boat", "sunglasses"],
	["tent", "star", "moon", "tree", "forest", "rock", "river", "mountain", "owl", "pinecone"],
	["cake", "balloon", "candy", "cookie", "plate", "cup", "crown", "bell", "drum", "guitar", "piano", "box"],
	["robot", "doll", "car", "plane", "wheel", "key", "block", "puzzle", "yoyo", "drum", "box", "bear"]
]

static var _word_catalog: Dictionary = {}

const REPAIRS: Array = [
	{
		"id": "toy-car", "name": "Toy Car", "correct_part": "wheel",
		"choices": [
			{"id": "wheel", "label": "Wheel", "shape": "wheel"},
			{"id": "wing", "label": "Wing", "shape": "wing"},
			{"id": "ribbon", "label": "Ribbon", "shape": "ribbon"}
		]
	},
	{
		"id": "toy-plane", "name": "Toy Plane", "correct_part": "wing",
		"choices": [
			{"id": "screw", "label": "Screw", "shape": "screw"},
			{"id": "wing", "label": "Wing", "shape": "wing"},
			{"id": "key", "label": "Winding Key", "shape": "key"}
		]
	},
	{
		"id": "teddy-bear", "name": "Teddy Bear", "correct_part": "ribbon",
		"choices": [
			{"id": "key", "label": "Winding Key", "shape": "key"},
			{"id": "screw", "label": "Screw", "shape": "screw"},
			{"id": "ribbon", "label": "Ribbon", "shape": "ribbon"}
		]
	},
	{
		"id": "toy-robot", "name": "Toy Robot", "correct_part": "screw",
		"choices": [
			{"id": "wheel", "label": "Wheel", "shape": "wheel"},
			{"id": "screw", "label": "Screw", "shape": "screw"},
			{"id": "wing", "label": "Wing", "shape": "wing"}
		]
	},
	{
		"id": "music-box", "name": "Music Box", "correct_part": "key",
		"choices": [
			{"id": "key", "label": "Winding Key", "shape": "key"},
			{"id": "ribbon", "label": "Ribbon", "shape": "ribbon"},
			{"id": "wheel", "label": "Wheel", "shape": "wheel"}
		]
	}
]

const LEVEL_DEFINITIONS: Array = [
	{
		"title": "At the Front Door", "monster_name": "Stonewarden", "source_creature": "Rock Guardian",
		"monster_id": "giant-rock-guardian",
		"accent": "#ee9b79", "kind": "ordinary",
		"description": "A peach porch with a broad front door, a doorbell, and welcoming plants.",
		"props": ["front door", "doorbell", "doorstep", "potted plants"],
		"dialogue": [
			["Adam", "Knock, knock."],
			["Yoki", "Who's that?"],
			["Adam", "It's me, Adam."],
			["Yoki", "Hello, Adam."],
			["Adam", "May I come in?"],
			["Yoki", "Come in, please."]
		]
	},
	{
		"title": "Clean Hands", "monster_name": "Bubbles", "source_creature": "Squidle",
		"accent": "#61c6cf", "kind": "ordinary",
		"description": "An aqua bathroom with a low sink, a round mirror, soap, and a soft towel.",
		"props": ["sink", "round mirror", "soap pump", "towel", "bubbles"],
		"dialogue": [
			["Adam", "My hands are dirty."],
			["Yoki", "Let's wash our hands."],
			["Adam", "May I have some soap?"],
			["Yoki", "Here is the soap."],
			["Adam", "Thank you, Yoki."],
			["Yoki", "Now our hands are clean."]
		]
	},
	{
		"title": "Breakfast Time", "monster_name": "Flapjack", "source_creature": "Mushroom",
		"accent": "#e9b95d", "kind": "ordinary",
		"description": "A warm cream kitchen with a breakfast table, toast, milk, and rounded cabinets.",
		"props": ["breakfast table", "toast", "milk cup", "kitchen cabinets"],
		"dialogue": [
			["Adam", "Good morning, Yoki."],
			["Yoki", "Good morning, Adam."],
			["Adam", "May I have some toast?"],
			["Yoki", "Yes, here is your toast."],
			["Adam", "May I have some milk too?"],
			["Yoki", "Here is a cup of milk."],
			["Adam", "Thank you for my breakfast."],
			["Yoki", "You are welcome. Enjoy it."]
		]
	},
	{
		"title": "Getting Dressed", "monster_name": "Socksy", "source_creature": "Bunny",
		"accent": "#aa8dda", "kind": "ordinary",
		"description": "A lavender bedroom with a low bed, a wardrobe, and colorful clothes to find.",
		"props": ["bed", "wardrobe", "blue shirt", "yellow socks", "shoes"],
		"dialogue": [
			["Yoki", "Where is my blue shirt?"],
			["Adam", "Your shirt is on the bed."],
			["Yoki", "Can you find my socks?"],
			["Adam", "Are these your yellow socks?"],
			["Yoki", "Yes, they are. Thank you."],
			["Adam", "Now we need our shoes."],
			["Yoki", "My shoes are by the door."],
			["Adam", "Let's put them on together."]
		]
	},
	{
		"title": "Taking Turns", "monster_name": "Boingo", "source_creature": "Frog",
		"accent": "#ed8586", "kind": "ordinary",
		"description": "A coral playground with a broad slide, swings, and a little flag.",
		"props": ["slide", "swings", "play platform", "flag"],
		"dialogue": [
			["Adam", "That slide looks like fun."],
			["Yoki", "May I go down first?"],
			["Adam", "Yes, I can wait here."],
			["Yoki", "Thank you for taking turns."],
			["Adam", "Is it my turn now?"],
			["Yoki", "Yes, the slide is clear."],
			["Adam", "Will you wait for me?"],
			["Yoki", "Of course. Take your time."],
			["Adam", "Let's play on the swings next."],
			["Yoki", "Good idea. We can take turns again."]
		]
	},
	{
		"title": "Our Classroom Picture", "monster_name": "Doodle", "source_creature": "Armabee",
		"accent": "#7ec9aa", "kind": "ordinary",
		"description": "A mint classroom with an art table, oversized crayons, and a picture display.",
		"props": ["art table", "crayons", "drawing paper", "display board"],
		"dialogue": [
			["Yoki", "Let's draw a picture together."],
			["Adam", "What would you like to draw?"],
			["Yoki", "I want to draw a sun."],
			["Adam", "May I use the yellow crayon?"],
			["Yoki", "Yes, please give it back later."],
			["Adam", "Thank you. I will draw a tree too."],
			["Yoki", "Can I have the green crayon?"],
			["Adam", "Here you are. Let's share the colors."],
			["Yoki", "Our picture looks bright and happy."],
			["Adam", "Let's put it on the classroom wall."]
		]
	},
	{
		"title": "Fruit Shopping", "monster_name": "Sprout", "source_creature": "Cactoro",
		"accent": "#97bc59", "kind": "ordinary",
		"description": "A cheerful fruit shop with produce crates, a striped canopy, and a shopping bag.",
		"props": ["fruit crates", "apples", "bananas", "canopy", "shopping bag"],
		"dialogue": [
			["Adam", "We need some fruit for our picnic."],
			["Yoki", "What fruit would you like to buy?"],
			["Adam", "I would like apples and bananas."],
			["Yoki", "How many apples do we need?"],
			["Adam", "We need three apples for our friends."],
			["Yoki", "Shall we choose these red apples?"],
			["Adam", "Yes, and let's get two bananas."],
			["Yoki", "These bananas look yellow and ripe."],
			["Adam", "Can you hold the bag for me?"],
			["Yoki", "Of course. Please put the fruit inside."],
			["Adam", "Thank you. Now we have everything."],
			["Yoki", "Let's pay and carry the bag together."]
		]
	},
	{
		"title": "A Quiet Library", "monster_name": "Bookmark", "source_creature": "Bird",
		"accent": "#8a9fc8", "kind": "ordinary",
		"description": "A quiet blue library with low bookshelves and two reading chairs by the window.",
		"props": ["bookshelves", "picture books", "reading chairs", "window"],
		"dialogue": [
			["Yoki", "Please use a quiet voice in the library."],
			["Adam", "I would like a book about animals."],
			["Yoki", "Shall we look on this low shelf?"],
			["Adam", "I found a book about a little bear."],
			["Yoki", "Would you like to read it together?"],
			["Adam", "Yes, but where can we sit?"],
			["Yoki", "There are two chairs by the window."],
			["Adam", "Can you help me turn this page?"],
			["Yoki", "Of course. We can read it slowly."],
			["Adam", "This story makes me want to smile."],
			["Yoki", "Let's put the book back when we finish."],
			["Adam", "Then another friend can enjoy it too."]
		]
	},
	{
		"title": "A Day at the Zoo", "monster_name": "Spotty", "source_creature": "Dino",
		"accent": "#d7ae59", "kind": "ordinary",
		"description": "A sunny zoo trail with a map, animal signs, a pond, and a safe viewing fence.",
		"props": ["zoo map", "animal signs", "pond", "viewing fence", "trees"],
		"dialogue": [
			["Adam", "Look at the tall giraffe by the tree."],
			["Yoki", "Its neck helps it reach the leaves."],
			["Adam", "Would you like to see the monkeys next?"],
			["Yoki", "Yes, but let's look at the map first."],
			["Adam", "The monkey house is beside the pond."],
			["Yoki", "Shall we walk along this little path?"],
			["Adam", "I can hear the monkeys calling to each other."],
			["Yoki", "Look! That baby monkey is holding its mother."],
			["Adam", "May we give the monkeys our snacks?"],
			["Yoki", "No, their keeper gives them the right food."],
			["Adam", "I will keep my snacks in my bag."],
			["Yoki", "Good idea. Let's watch from behind the fence."],
			["Adam", "Which animal would you like to see now?"],
			["Yoki", "Let's see the penguins before we go home."]
		]
	},
	{
		"title": "Riding the Bus", "monster_name": "Roly", "source_creature": "Hywirl",
		"accent": "#6aafda", "kind": "ordinary",
		"description": "A blue bus and a clearly marked bus stop, with big windows and a route sign.",
		"props": ["bus", "bus stop", "route sign", "seats", "handrail"],
		"dialogue": [
			["Yoki", "Our bus will arrive at this stop soon."],
			["Adam", "How will we know which bus to take?"],
			["Yoki", "We need the blue bus to the park."],
			["Adam", "I can see it coming down the road."],
			["Yoki", "Let's wait here until the doors open."],
			["Adam", "May I get on the bus after you?"],
			["Yoki", "Yes, please hold the rail as you step up."],
			["Adam", "There are two empty seats near the window."],
			["Yoki", "Let's sit down and keep our bags close."],
			["Adam", "How many stops are left before the park?"],
			["Yoki", "There are two stops before we get off."],
			["Adam", "Please tell me when we reach our stop."],
			["Yoki", "This is our stop. Let's stand up carefully."],
			["Adam", "Thank you for helping me ride the bus."]
		]
	},
	{
		"title": "A Sandcastle at the Beach", "monster_name": "Shelly", "source_creature": "Glub",
		"accent": "#5bc6bb", "kind": "ordinary",
		"description": "A turquoise beach with a sandcastle, red bucket, shells, and a bright little flag.",
		"props": ["sandcastle", "bucket", "shovel", "shells", "waves"],
		"dialogue": [
			["Adam", "The sand is soft enough to build a castle."],
			["Yoki", "Shall we build it away from the water?"],
			["Adam", "Yes, this dry spot looks like a good place."],
			["Yoki", "Could you fill the red bucket with wet sand?"],
			["Adam", "I will fill it while you make the walls."],
			["Yoki", "Please turn the bucket over very slowly."],
			["Adam", "Here is our first tower. What comes next?"],
			["Yoki", "Let's add another tower and a little bridge."],
			["Adam", "May I use these shells to make a path?"],
			["Yoki", "Yes, and I can put this flag on top."],
			["Adam", "A small wave is getting closer to our castle."],
			["Yoki", "We can make a little wall to protect it."],
			["Adam", "I will use the shovel to move some sand."],
			["Yoki", "Thank you. The new wall is strong enough now."],
			["Adam", "Let's take a picture before we leave the beach."],
			["Yoki", "Then we can collect our toys and leave it tidy."]
		]
	},
	{
		"title": "Camping Under the Stars", "monster_name": "Stormwing", "source_creature": "Storm Dragon",
		"monster_id": "giant-storm-dragon",
		"accent": "#9587cc", "kind": "ordinary",
		"description": "An indigo campsite with a tent, lantern, sleeping bags, and a sky full of stars.",
		"props": ["tent", "lantern", "sleeping bags", "trees", "stars"],
		"dialogue": [
			["Yoki", "The sun is setting, so let's finish our campsite."],
			["Adam", "Can you help me put the tent beside this tree?"],
			["Yoki", "Yes, and we should keep the path clear."],
			["Adam", "I have put our sleeping bags inside the tent."],
			["Yoki", "Could you bring the lantern before it gets dark?"],
			["Adam", "Here it is. Where would you like me to put it?"],
			["Yoki", "Please put it on this flat rock near us."],
			["Adam", "The sky is dark enough to see the stars now."],
			["Yoki", "Can you find three bright stars above the trees?"],
			["Adam", "I can see them, and one looks very shiny."],
			["Yoki", "Let's make up a story about a friendly star."],
			["Adam", "Our star can help a lost rabbit find its home."],
			["Yoki", "That is a kind story. How does it end?"],
			["Adam", "The rabbit thanks the star and falls asleep safely."],
			["Yoki", "Now let's turn off the lantern and get some rest."],
			["Adam", "Good night, Yoki. I am glad we came camping."]
		]
	},
	{
		"title": "The Grand Birthday Party", "monster_name": "King Cuddles", "source_creature": "Yeti",
		"accent": "#de91c2", "kind": "boss",
		"description": "A grand birthday room with one giant friendly Yeti, a tiered cake, balloons, and gifts.",
		"props": ["birthday cake", "balloons", "party table", "presents", "bunting"],
		"dialogue": [
			["Adam", "The birthday party starts soon. Is everything ready?"],
			["Yoki", "We still need to set the table for our friends."],
			["Adam", "I can put a plate beside each paper cup."],
			["Yoki", "Thank you. Could you bring the cake to the table?"],
			["Adam", "Yes, but please help me carry it very carefully."],
			["Yoki", "I am holding this side. Let's move it together."],
			["Adam", "Our friends are here. Shall we welcome them inside?"],
			["Yoki", "Welcome, everyone! We are happy you could come."],
			["Adam", "Would you like to play a game before we eat?"],
			["Yoki", "Yes, let's take turns so everyone can join in."],
			["Adam", "Now it is time to sing the birthday song."],
			["Yoki", "Please gather around the cake and sing with us."],
			["Adam", "I hope your birthday is full of happy surprises."],
			["Yoki", "Thank you. My wish is for us to stay good friends."],
			["Adam", "Would you like a small piece of cake or a big one?"],
			["Yoki", "A small piece, please, so there is enough for everyone."],
			["Adam", "We can open the presents after we tidy the table."],
			["Yoki", "What a wonderful party! Thank you for celebrating with me."]
		]
	},
	{
		"title": "Magic Toy Workshop", "monster_name": "Embermaw", "source_creature": "Ember Golem",
		"monster_id": "giant-ember-golem",
		"accent": "#9c92e2", "kind": "boss",
		"description": "A magical toy workshop with a workbench, bright toys, and the final friendly monster.",
		"props": ["workbench", "toy car", "toy plane", "teddy bear", "toy robot", "music box"],
		"dialogue": [
			["Adam", "Embermaw is sleeping. Can you help me fix this toy car?"],
			["Yoki", "Of course. What does the little car need?"],
			["Adam", "One wheel is loose. Please hold the car while I fix it."],
			["Yoki", "I am holding it steady. Now all four wheels can roll."],
			["Yoki", "This toy plane has a bent wing. Will you help me?"],
			["Adam", "Yes. Shall I hold the plane while you straighten the wing?"],
			["Yoki", "Please hold it gently, so we can line up both sides."],
			["Adam", "The wings look even now. Our plane is ready to play."],
			["Adam", "This teddy bear has a loose bow. Could you help me tie it?"],
			["Yoki", "Of course. I can hold the ribbon while you make a loop."],
			["Adam", "Thank you. Please keep holding it while I tie the knot."],
			["Yoki", "The bow is tidy now, and our teddy looks happy again."],
			["Yoki", "This little robot cannot wave. Can we find out why together?"],
			["Adam", "I can see a loose arm. Would you like me to hold it?"],
			["Yoki", "Yes, please. I will turn this small screw with the toy tool."],
			["Adam", "The arm is secure now. Look, our robot can wave again."],
			["Adam", "The music box is quiet. Shall we try to fix it together?"],
			["Yoki", "Yes. I will open the lid while you turn the winding key."],
			["Adam", "I can hear the tune now. Let's close the lid very gently."],
			["Yoki", "All five toys are ready. Wake up, Embermaw, and celebrate with us!"]
		]
	}
]

const CHEST_DEFINITIONS: Array = [
	["Welcome Mailbox", "Domed postbox with a side-opening door.", "The side door swings open and paper stars float out."],
	["Bubble Capsule", "Oval capsule with twin curved covers.", "The covers separate and a cluster of bubbles rises."],
	["Breakfast Basket", "Rounded wicker basket with a roll-top cover.", "The roll-top retracts and golden sparkles rise."],
	["Button Wardrobe", "Cloth-covered wardrobe with rounded double doors.", "The doors open and ribbons unfurl."],
	["Sandcastle Chest", "Castle bucket with a drawbridge and flag.", "The drawbridge lowers and the flag rises."],
	["Palette Case", "Artist palette with a brush-shaped latch.", "The brush releases and the case opens like a fan."],
	["Orchard Cart", "Wheeled produce crate beneath a rounded canopy.", "The crate slats retract in sequence."],
	["Storybook Coffer", "Thick book with a page-like lid.", "The lid opens and paper birds flutter out."],
	["Turtle Treasure", "Friendly turtle with separate shell plates.", "The shell plates lift one after another."],
	["Little Bus Trunk", "Rounded bus case with a sliding roof and step.", "The roof slides back and the side step extends."],
	["Pearl Shell Chest", "Broad scallop shell with a rear hinge.", "The lid opens and a gentle pearl glow blooms."],
	["Tent Trunk", "Soft tent with a star zipper and rolled flaps.", "The star zipper rises and the tent flaps roll aside."],
	["Birthday Cake Box", "Three cake tiers on a broad stable base.", "The upper tiers rotate and rise amid confetti."],
	["Robot Toolbox", "Robot-faced toolbox with cantilever trays.", "The trays unfold around a small companion reward."],
	["Mushroom Cottage", "Rounded cottage beneath a broad mushroom cap.", "The mushroom cap rotates and lifts."],
	["Cloud Pillow Box", "Padded cloud with a crescent-shaped flap.", "The flap curls back and rainbow puffs emerge."],
	["Clockwork Egg", "Wind-up egg with a key and two shell halves.", "The key turns and the shell halves separate."],
	["Concertina Chest", "Accordion body with rounded bellows and a top hatch.", "The bellows expand and musical notes rise."],
	["Honeycomb Hideaway", "Hexagonal box with drawer-like honeycomb cells.", "The drawers extend in a staggered sequence."],
	["Patchwork Present", "Padded fabric gift with a bow and four panels.", "The bow unties and the panels fold down."]
]


static func level(number: int) -> Dictionary:
	if number < 1 or number > LEVEL_COUNT:
		return {}
	var source: Dictionary = LEVEL_DEFINITIONS[number - 1]
	var health: int = HEALTH[number - 1]
	var extra: int = maxi(3, ceili(float(health) / 4.0))
	var result: Dictionary = {
		"number": number, "id": "level-%02d" % number, "title": source.title,
		"scene_id": "scene-%02d" % number,
		"scene": {
			"id": "scene-%02d" % number, "name": source.title, "accent": source.accent,
			"description": source.description, "props": source.props.duplicate()
		},
		"monster_id": str(source.get("monster_id", "lpm-" + source.source_creature.to_lower())),
		"monster_name": source.monster_name, "source_creature": source.source_creature,
		"cooperative": false, "kind": source.kind,
		"chest_id": "chest-%02d" % number, "lines": [],
		"hp": health, "extra_words": extra, "word_budget": health + extra,
		"words": _words_for_level(number)
	}
	for index in range(source.dialogue.size()):
		var dialogue: Array = source.dialogue[index]
		var line: Dictionary = {
			"id": "line-%02d-%02d" % [number, index + 1], "uid": index + 1,
			"speaker": dialogue[0], "text": dialogue[1]
		}
		if result.cooperative:
			var repair_index: int = floori(float(index) / 4.0)
			line.merge({
				"repair_id": REPAIRS[repair_index].id, "repair_name": REPAIRS[repair_index].name,
				"repair_index": repair_index, "repair_step": index % 4 + 1,
				"role": "requester" if index % 2 == 0 else "helper"
			})
		result.lines.append(line)
	return result


static func _words_for_level(number: int) -> Array[Dictionary]:
	if _word_catalog.is_empty():
		var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
		if not GameData.validate_words(loaded).is_empty():
			return []
		for word: Dictionary in loaded:
			var entry: Dictionary = word.duplicate(true)
			var imported: String = "assets/imported-unity/" + entry.id + ".png"
			if ResourceLoader.exists("res://" + imported):
				entry.image = imported
			_word_catalog[entry.id] = entry
	var result: Array[Dictionary] = []
	for id: String in LEVEL_WORDS[number - 1]:
		if _word_catalog.has(id):
			result.append(_word_catalog[id].duplicate(true))
	return result


static func levels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for number in range(1, LEVEL_COUNT + 1):
		result.append(level(number))
	return result


static func chest(id: String) -> Dictionary:
	for index in range(CHEST_COUNT):
		if id != "chest-%02d" % (index + 1):
			continue
		var source: Array = CHEST_DEFINITIONS[index]
		return {
			"id": id, "index": index + 1, "name": source[0], "shape": source[1],
			"animation": source[2], "level": index + 1 if index < LEVEL_COUNT else 0,
			"accent": LEVEL_DEFINITIONS[index % LEVEL_COUNT].accent,
			"duration": CHEST_DURATION, "hold_time": CHEST_HOLD_TIME, "reveal_time": CHEST_REVEAL_TIME,
			"companion_reward": index == 13
		}
	return {}


static func chests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for number in range(1, CHEST_COUNT + 1):
		result.append(chest("chest-%02d" % number))
	return result


static func repairs() -> Array:
	return REPAIRS.duplicate(true)
