class_name StoryText
extends RefCounted
## Every word the menus say: the old rider's frame story, season beats, rival lines, credits and the end card.
## The tale never mentions 1959, and nobody comments on the quiet changes along the road. See docs/WORLD_AND_CAST.md.
## Text uses only the headline font's alphabet.

const SEASON_NAMES: Array[String] = ["SPRING MEETS", "SUMMER FESTIVAL", "HARVEST FINAL"]

const COURSES := [
	{"name": "TEA HORSE ROAD", "region": "KHAM", "blurb": "RED ROCK GORGE, SPRUCE AND JUNIPER, A RIVER BELOW ON THE RIGHT. MULE CARAVANS, A CANTILEVER BRIDGE, NARROW LEDGES."},
	{"name": "GRASS SEA", "region": "NAGCHU", "blurb": "OPEN GOLD-GREEN PLAIN AND A HUGE SKY. YAK HERDS CROSSING, WIDE FAST RACING, A LONG BOW RANGE."},
	{"name": "TURQUOISE PASS", "region": "KAMBA LA, YAMDROK", "blurb": "CLIMB TO A CAIRN AND FLAGS, THEN DROP BESIDE THE TURQUOISE LAKE. HAIRPINS AND A HIGH PASS."},
	{"name": "GALLOP BEHIND THE FORT", "region": "GYANTSE", "blurb": "BARLEY FIELDS, STONE VILLAGES, THE FORT ON ITS ROCK. TARGET POLES, FESTIVAL CROWDS, QUIET GROUND AT THE MONASTERY."},
	{"name": "THE WESTERN GATE", "region": "LHASA", "blurb": "WILLOW GROVES AND WHITEWASHED WALLS. QUIET GROUND THROUGH THE GATE, HUGE CROWDS, THE FINISH ON THE PLAIN."},
]

const COURSE_RIVAL: Array[String] = ["karma", "pasang", "sonam", "pema", "wangyal"]

## Fallback cast, used when data/game_data.gd has no entry. Order is their order of arrival.
const RIVALS := {
	"wangyal": {"name": "PON WANGYAL DORJE", "region": "KHAM", "from": 0, "intro": "A pack pony? Good. I need something to overtake.", "grudge": "You knocked my hat off in front of my mother. We're friends now. I'm going to kill you.", "win": "Never lost, never will. Come to my tent and I'll tell you how."},
	"karma": {"name": "KARMA TOBGYE", "region": "KHAM", "from": 0, "intro": "Watch the third bend. No, I won't tell you why.", "grudge": "I know where you hit me. I'll remember it at the third bend.", "win": "Eyes up, boy. And head down."},
	"sonam": {"name": "SONAM PHURBA", "region": "CHANGTANG", "from": 0, "intro": "Salt does not hurry. Neither do I. I still arrive.", "grudge": "My stones remember your face.", "win": "Slow and steady. Mostly steady."},
	"pasang": {"name": "PASANG TSOMO", "region": "CHANGTANG", "from": 0, "intro": "This is my lane. Come and get it.", "grudge": "You came into my lane. Come again.", "win": "My lane, my race."},
	"samdup": {"name": "LITHANG SAMDUP", "region": "KHAM", "from": 0, "intro": "If I fall off, it was on purpose.", "grudge": "That was MY scarf. I will have it back, with interest.", "win": "Did you see that? Of course you did."},
	"temba": {"name": "TEMBA TINLE", "region": "LHASA", "from": 0, "intro": "Under by-law nine, you may not overtake a sixth-rank official. By-law nine is new.", "grudge": "I have noted your offences. There are many. I have started a second notebook.", "win": "By-law twelve: the winner is whoever I say."},
	"pema": {"name": "PEMA YANGKEY", "region": "TSANG", "from": 0, "intro": "You rode well! Sorry about the arrow.", "grudge": "Sorry about the arrow. And the second one.", "win": "Good race! Come, there is tea."},
	"dukpa": {"name": "DUKPA TSEWANG", "region": "BHUTAN", "from": 0, "intro": "After you. No, truly. Mind the ditch.", "grudge": "I was most polite and you were most rude. I shall be polite again, near a ditch.", "win": "A pleasure, as always."},
	"thupden": {"name": "THUPDEN BUM", "region": "GOLOK", "from": 1, "intro": "My horse owes nobody. Neither do I. You owe me a hat.", "grudge": "You still owe me a hat.", "win": "Free horse, free man, first across."},
	"drukmo": {"name": "DRUKMO KYI", "region": "AMDO", "from": 1, "intro": "They named me for a prize. I've come to collect it.", "grudge": "You got in my way once. Do not do it twice.", "win": "I came to collect. I collected."},
	"genden": {"name": "GENDEN GYAL", "region": "EASTERN PLATEAU", "from": 1, "intro": "Your colour is bad. Have you been eating enough butter? Also, I would duck.", "grudge": "I will treat that bruise. After I win.", "win": "More butter tea. Doctor's orders."},
	"pamo": {"name": "PAMO KUNGA WANGMO", "region": "KHAM", "from": 1, "intro": "I do not hurry. I do not need to.", "grudge": "I have been watching you. Carefully.", "win": "Patience beats speed."},
	"diki": {"name": "LHACHAM DIKI YANGDOL", "region": "LHASA", "from": 1, "intro": "In Calcutta they have machines that do this without the smell.", "grudge": "You will pay for that silk.", "win": "Faster. Always faster."},
	"chakri": {"name": "LOBSANG WANGDU", "region": "LHASA", "from": 2, "intro": "That hurt! Good. Whoever you are, we're friends now.", "grudge": "Round two, friend!", "win": "Good fight! Take my winnings. Give them to someone who needs them."},
	"serkhar": {"name": "SERKHAR TASHI GYALTSEN", "region": "LHASA", "from": 2, "intro": "I will pay you back for that. I will pay everyone back. Eventually.", "grudge": "You will be paid in full. With interest.", "win": "Magnificent. Someone else is paying."},
	"ama": {"name": "AMA CHOEKYI", "region": "KALIMPONG", "from": 2, "intro": "You owe me eighty srang. Ride accordingly.", "grudge": "Nobody cheats me twice.", "win": "Interest is due."},
}

## What a rival says when you beat them and they have no grudge to speak of.
const LOSE_LINES: Array[String] = [
	"Good race. I want another.",
	"That was luck. Do it again, if you can.",
	"I was warming up.",
	"Enjoy it. It will not last.",
	"My horse was thinking about lunch.",
]

const LOAN_LINES: Array[String] = [
	"I hear your aunt had to lend you silver. Ride carefully.",
	"Your aunt lent you money? She will mention it. She mentions everything.",
	"They say you borrowed again. Do not worry, so did I.",
]

const END_CARD := "This story is a tall tale. Tibetans raced horses and shot at targets at a gallop. They did not, as far as anyone knows, hit each other with iron keys.\n\nIn 1954 motor roads reached Lhasa. In the years that followed, this way of life was changed by war and exile. Many Tibetans still ride and race, in Tibet and beyond.\n\nTo hear Tibetans tell their own history, start with the Tibet Oral History Project and Tsering Shakya's \"The Dragon in the Land of Snows\"."

const TALL_TALE_LINE := "HORSEBACK BRAWLING IS A TALL TALE, NOT HISTORY."


static func narrator(player_id: String) -> String:
	return "MOLA" if player_id == "yangkyi" else "POLA"


static func narrator_title(player_id: String) -> String:
	return "GRANDMOTHER" if player_id == "yangkyi" else "GRANDFATHER"


static func course_fallback(index: int) -> Dictionary:
	return COURSES[clampi(index, 0, COURSES.size() - 1)]


static func intro_pages(player_id: String) -> Array[String]:
	var nick := "They called me Joru, after the snot-nosed hero of the old epic. They did not mean it kindly."
	if player_id == "yangkyi":
		nick = "The villagers called me Joru too, after the snot-nosed hero of the old epic. They did not mean it kindly. I did not mind. He won in the end."
	var out: Array[String] = [
		"Sit, little one. Pour me more tea. You want to hear about the Wood Horse Year? Everyone does. Nobody ever asks about the Ox Year.",
		"I was seventeen and owned nothing but debt. My horse was a borrowed pack pony named Old Tsampa. My aunt, Ama Choekyi, the wool dealer in Kalimpong, wanted every srang back.",
		nick,
		"That year the rich wool dealers and the noble houses made a great wager: a circuit of race meets from the Kham gorges to the Western Gate of Lhasa. The rules? There were no rules worth mentioning.",
		"I won every race, of course. Well. Most of them. Fine, some of them. Listen.",
	]
	return out


## Pages shown after clearing Season `cleared` (0 = Spring Meets, 1 = Summer Festival).
static func season_end_pages(player_id: String, cleared: int) -> Array[String]:
	if cleared == 0:
		return [
			"By the end of the Spring Meets, people had noticed me. A little. Karma Tobgye, the old caravan guard, gave me advice and then hit me. I accepted both.",
			"Pon Wangyal Dorje sent over a brick of tea, out of pity. I drank it out of spite. It was very good tea.",
			"Then came the Summer Festival. People started to bet on me! Ama Choekyi raised the interest. Lithang Samdup wanted to know my secret. I had none. Serkhar Tashi Gyaltsen offered to buy my horse with money he did not have.",
		]
	return [
		"By harvest time, Wangyal had stopped laughing. He still talked. But he had stopped laughing, and that is how you know.",
		"The last meet was at the Western Gate of Lhasa. Willows, whitewashed walls, and the whole plain full of people. Just me against Pon Wangyal Dorje, who has never lost and tells everyone so.",
	]


static func victory_pages(player_id: String) -> Array[String]:
	return [
		"I won. Of course I won. The dust had not settled before the crowd reached me, and somebody put a white scarf around my neck.",
		"Next morning Wangyal arrived at my tent with a barrel of chang. \"You cheated,\" he said. \"Let's race again.\"",
		"I smiled. We raced for the rest of that year.",
	]


static func credits_lines() -> Array[String]:
	var l: Array[String] = [
		"WINDHORSE RUMBLE",
		"A TALL TALE OF THE WOOD HORSE YEAR",
		"",
		"HORSEBACK BRAWLING IS A TALL TALE, NOT HISTORY.",
		"",
		"- THE WOOD HORSE GAMES -",
		"",
		"DESIGN, CODE, ART, MUSIC AND SOUND",
		"MADE WITH CLAUDE",
		"",
		"EVERY MODEL, PICTURE AND SOUND IS GENERATED BY SCRIPTS",
		"MUSIC IS ORIGINAL, PLAYED BY A SYNTHESISED LUTE,",
		"FRAME DRUM, CYMBAL AND LOW HORN",
		"",
		"- THE CAST -",
		"",
		"ALL RIDERS ARE INVENTED, INSPIRED BY TYPES AND NOT",
		"BY INDIVIDUALS. THEIR NAMES AND CUSTOMS STILL NEED",
		"CHECKING BY TIBETAN SPEAKERS.",
		"",
		"- RESPECT -",
		"",
		"MANI WALLS AND CHORTENS CAN NEVER BE HARMED.",
		"NO ONE IN THE SADDLE IS A MONK OR A NUN.",
		"HORSES ARE NEVER HURT. THEY TROT ON AND WAIT.",
		"",
		"THANK YOU FOR RIDING.",
	]
	return l
