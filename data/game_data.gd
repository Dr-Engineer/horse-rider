class_name GameData
extends RefCounted
## Every number the game balances on: weapons, horses, tack, rivals, players.
## Weapon numbers come straight from docs/GAME_DESIGN.md. Do not rebalance here without changing the design doc.

# klass: "body" | "melee" | "ranged". reach in metres, swing in seconds.
# Ranged extras: draw (s to full draw), min_draw, speed (projectile m/s), ammo (-1 = unlimited).
const WEAPONS := {
	"fists": {"name": "Fists", "tibetan": "", "klass": "body", "damage": 8.4, "impact": 10.0, "reach": 1.9, "swing": 0.33, "cost": 0, "ammo": -1, "model": "", "desc": "Always available, and no shove."},
	"kick": {"name": "Kick", "tibetan": "", "klass": "body", "damage": 4.2, "impact": 20.0, "reach": 2.1, "swing": 0.62, "cost": 0, "ammo": -1, "model": "", "desc": "Lands late and slows your horse, but shoves the target away."},
	"barge": {"name": "Barge", "tibetan": "", "klass": "body", "damage": 5.6, "impact": 18.0, "reach": 0.0, "swing": 0.0, "cost": 0, "ammo": -1, "model": "", "desc": "Scales with sideways speed and horse bulk."},
	"knife": {"name": "Knife", "tibetan": "gri", "klass": "melee", "damage": 14.0, "impact": 8.0, "reach": 2.0, "swing": 0.3, "cost": 60, "ammo": -1, "model": "knife", "desc": "Fastest blade."},
	"pencase": {"name": "Pen case", "tibetan": "", "klass": "melee", "damage": 9.8, "impact": 20.0, "reach": 2.1, "swing": 0.42, "cost": 40, "ammo": -1, "model": "pencase", "desc": "Gravel-filled, cheap and comic."},
	"whip": {"name": "Whip", "tibetan": "", "klass": "melee", "damage": 8.4, "impact": 15.0, "reach": 3.0, "swing": 0.34, "cost": 120, "ammo": -1, "model": "whip", "desc": "Long and quick."},
	"sword": {"name": "Sword", "tibetan": "ral gri", "klass": "melee", "damage": 25.2, "impact": 24.0, "reach": 2.6, "swing": 0.55, "cost": 450, "ammo": -1, "model": "sword", "desc": "Best all-round."},
	"key": {"name": "Iron key", "tibetan": "lde brdzus", "klass": "melee", "damage": 21.0, "impact": 38.0, "reach": 3.5, "swing": 0.7, "cost": 650, "ammo": -1, "model": "key", "desc": "On a thong. Outreaches swords, weak up close."},
	"spear": {"name": "Spear", "tibetan": "mdung", "klass": "melee", "damage": 22.4, "impact": 34.0, "reach": 4.0, "swing": 0.75, "cost": 700, "ammo": -1, "model": "spear", "desc": "At a full gallop, +25% impact."},
	"sling": {"name": "Sling", "tibetan": "'ur rdo", "klass": "ranged", "damage": 5.6, "impact": 6.0, "reach": 28.0, "swing": 0.8, "cost": 80, "ammo": 297, "model": "sling", "draw": 0.5, "min_draw": 0.3, "speed": 42.0, "desc": "Side-swung, plentiful stones."},
	"bow": {"name": "Bow", "tibetan": "gzhu", "klass": "ranged", "damage": 11.9, "impact": 8.0, "reach": 45.0, "swing": 0.9, "cost": 520, "ammo": 36, "model": "bow", "draw": 0.9, "min_draw": 0.25, "speed": 70.0, "desc": "Draw to aim, +30% at full draw."},
	"roped_spear": {"name": "Roped spear", "tibetan": "thag mdung", "klass": "ranged", "damage": 14.7, "impact": 12.0, "reach": 27.0, "swing": 1.1, "cost": 900, "ammo": -1, "model": "roped_spear", "draw": 0.35, "min_draw": 0.2, "speed": 38.0, "desc": "Thrown then hauled back, no ammo."},
}

const MELEE_IDS := ["fists", "knife", "pencase", "whip", "sword", "key", "spear"]
const RANGED_IDS := ["sling", "bow", "roped_spear"]
const SHIELD := {"name": "Shield", "tibetan": "phub", "cost": 250, "model": "shield"}

# speed in m/s, accel in m/s^2, handling scales lateral speed, stamina is whip seconds x ~22, bulk scales barge and shove.
const HORSES := {
	"old_tsampa": {"name": "Old Tsampa", "cost": 0, "speed": 20.0, "accel": 6.5, "handling": 3.0, "stamina": 80.0, "bulk": 1.0, "coat": Color("a88455"), "mane": Color("2b2420"), "rug": Color("c8a02a"), "desc": "Honest and steady. A dun pony."},
	"riwoche_dun": {"name": "Riwoche Dun", "cost": 320, "speed": 22.0, "accel": 7.5, "handling": 3.4, "stamina": 90.0, "bulk": 0.9, "coat": Color("b8956a"), "mane": Color("3a2f28"), "rug": Color("3a7a6a"), "desc": "Light and quick, easy to shove."},
	"nangchen_bay": {"name": "Nangchen Bay", "cost": 700, "speed": 24.0, "accel": 7.5, "handling": 3.2, "stamina": 100.0, "bulk": 1.0, "coat": Color("7a4326"), "mane": Color("1d1718"), "rug": Color("b3262b"), "desc": "A proper racehorse."},
	"golok_black": {"name": "Golok Black", "cost": 900, "speed": 23.0, "accel": 6.5, "handling": 2.8, "stamina": 120.0, "bulk": 1.5, "coat": Color("26232a"), "mane": Color("111013"), "rug": Color("8a1c2a"), "desc": "Heavy, hard to knock over."},
	"sertso_grey": {"name": "Sertso Grey", "cost": 2000, "speed": 27.0, "accel": 8.5, "handling": 3.4, "stamina": 120.0, "bulk": 1.1, "coat": Color("a9aeb4"), "mane": Color("e9e4d8"), "rug": Color("d6a62c"), "desc": "The horse people tell stories about."},
	# Rivals' horses
	"turquoise_bird": {"name": "Turquoise Bird", "cost": 0, "speed": 23.5, "accel": 7.5, "handling": 3.3, "stamina": 100.0, "bulk": 1.0, "coat": Color("c9b79a"), "mane": Color("3b8f8a"), "rug": Color("2aa7a0"), "desc": "Named by someone who hadn't read to the end."},
	"karma_roan": {"name": "Iron Roan", "cost": 0, "speed": 21.0, "accel": 6.5, "handling": 3.2, "stamina": 90.0, "bulk": 1.0, "coat": Color("7b7f86"), "mane": Color("2a2a2e"), "rug": Color("55585e"), "desc": "Knows every shortcut too."},
	"sonam_bay": {"name": "Salt Bay", "cost": 0, "speed": 20.5, "accel": 6.5, "handling": 2.9, "stamina": 110.0, "bulk": 1.1, "coat": Color("8a5a38"), "mane": Color("2a1e1a"), "rug": Color("d9d2c2"), "desc": "Strong on climbs."},
	"pasang_brown": {"name": "Lane Brown", "cost": 0, "speed": 20.5, "accel": 6.5, "handling": 3.0, "stamina": 100.0, "bulk": 1.3, "coat": Color("5d3b26"), "mane": Color("1e1613"), "rug": Color("b08a2e"), "desc": "Does not move over."},
	"samdup_pinto": {"name": "Bell Pinto", "cost": 0, "speed": 21.5, "accel": 7.5, "handling": 3.6, "stamina": 80.0, "bulk": 0.9, "coat": Color("d8cdb8"), "mane": Color("4a2f22"), "rug": Color("e0b020"), "desc": "A show-off's horse."},
	"temba_dun": {"name": "Ledger Dun", "cost": 0, "speed": 20.0, "accel": 6.0, "handling": 3.0, "stamina": 80.0, "bulk": 0.9, "coat": Color("b59c70"), "mane": Color("3c3027"), "rug": Color("2e4a8a"), "desc": "Fond of rules."},
	"pema_chestnut": {"name": "Friendly Chestnut", "cost": 0, "speed": 21.0, "accel": 7.0, "handling": 3.2, "stamina": 90.0, "bulk": 1.0, "coat": Color("94502c"), "mane": Color("d9c9a0"), "rug": Color("c23b2e"), "desc": "Underestimated, like its rider."},
	"dukpa_bay": {"name": "Courteous Bay", "cost": 0, "speed": 22.0, "accel": 7.0, "handling": 3.3, "stamina": 100.0, "bulk": 1.0, "coat": Color("6e3d24"), "mane": Color("181214"), "rug": Color("2c6a4a"), "desc": "After you."},
	"thupden_shaggy": {"name": "Shaggy Free", "cost": 0, "speed": 22.5, "accel": 7.0, "handling": 2.9, "stamina": 110.0, "bulk": 1.4, "coat": Color("453427"), "mane": Color("1c1613"), "rug": Color("7a5a3a"), "desc": "Owes nobody."},
	"drukmo_palomino": {"name": "Gold Finisher", "cost": 0, "speed": 23.0, "accel": 7.5, "handling": 3.3, "stamina": 110.0, "bulk": 1.0, "coat": Color("d1a45a"), "mane": Color("efe3c4"), "rug": Color("e6b13a"), "desc": "Saves something for the end."},
	"genden_grey": {"name": "Patient Grey", "cost": 0, "speed": 20.0, "accel": 6.0, "handling": 3.0, "stamina": 100.0, "bulk": 1.2, "coat": Color("969a9f"), "mane": Color("4c4c52"), "rug": Color("7e3a2a"), "desc": "Carries a doctor's chest."},
	"pamo_black": {"name": "Heir's Black", "cost": 0, "speed": 22.5, "accel": 7.0, "handling": 3.1, "stamina": 100.0, "bulk": 1.2, "coat": Color("2b2a30"), "mane": Color("141317"), "rug": Color("2aa7a0"), "desc": "Never rash."},
	"diki_arab": {"name": "Calcutta Bay", "cost": 0, "speed": 24.0, "accel": 8.0, "handling": 3.3, "stamina": 90.0, "bulk": 0.9, "coat": Color("7b3a28"), "mane": Color("1b1415"), "rug": Color("7a3c8c"), "desc": "Would rather be a motorbike."},
	"chakri_bay": {"name": "Escort Bay", "cost": 0, "speed": 22.5, "accel": 7.0, "handling": 3.0, "stamina": 110.0, "bulk": 1.3, "coat": Color("5b3a2a"), "mane": Color("1a1415"), "rug": Color("b3262b"), "desc": "Frank and sturdy."},
	"serkhar_grey": {"name": "Magnificent Debt", "cost": 0, "speed": 23.0, "accel": 6.5, "handling": 2.8, "stamina": 120.0, "bulk": 1.5, "coat": Color("8e9096"), "mane": Color("d8d2c4"), "rug": Color("c9a227"), "desc": "Heavy and hard to knock over."},
	"ama_felt": {"name": "Interest", "cost": 0, "speed": 21.0, "accel": 6.5, "handling": 3.0, "stamina": 90.0, "bulk": 1.1, "coat": Color("9a8a70"), "mane": Color("3a2e26"), "rug": Color("a8402a"), "desc": "Pays for itself."},
}

const TACK := {
	"saddle": [
		{"id": "felt_pad", "name": "Felt pad", "cost": 0, "impact_cut": 0.0},
		{"id": "derge", "name": "Derge saddle", "cost": 300, "impact_cut": 0.15},
		{"id": "gilt", "name": "Gilt saddle", "cost": 900, "impact_cut": 0.30},
	],
	"armor": [
		{"id": "chuba", "name": "Plain chuba", "cost": 0, "health": 0.0},
		{"id": "padded", "name": "Padded chuba", "cost": 200, "health": 15.0},
		{"id": "mail", "name": "Mail shirt", "cost": 700, "health": 30.0},
	],
}

# Rivals. seasons: which seasons (0 Spring, 1 Summer, 2 Harvest) they ride in.
# AI: skill 0..1 (how cleanly they ride and aim), aggression 0..1 (how much they pick fights), lane -1..1 (habit, left to right),
# pace (fraction of horse top speed they ride at), style picks behaviour in RiderAI.
const RIVALS := {
	"wangyal": {
		"name": "Pon Wangyal Dorje", "region": "Kham", "seasons": [0, 1, 2], "weapon": "sword", "ranged": "", "shield": false,
		"horse": "turquoise_bird", "skill": 0.85, "aggression": 0.8, "lane": 0.0, "pace": 0.985, "style": "front", "bon": false,
		"slot_a": Color("c4262e"), "slot_b": Color("f2c14e"), "skin": Color("e0b08a"),
		"wardrobe": ["body_oneoff", "head_young", "hair_wound", "hat_peak"],
		"lines": {
			"intro": ["A pack pony? Good. I need something to overtake.", "I have never lost. Do come and watch."],
			"grudge": ["You knocked my hat off in front of my mother. We're friends now. I'm going to kill you."],
			"win": ["Wasn't close. Was it close? It felt close."],
		},
	},
	"karma": {
		"name": "Karma Tobgye", "region": "Kham", "seasons": [0, 1, 2], "weapon": "whip", "ranged": "", "shield": false,
		"horse": "karma_roan", "skill": 0.8, "aggression": 0.45, "lane": -0.5, "pace": 0.97, "style": "shortcut", "bon": false,
		"slot_a": Color("6d7178"), "slot_b": Color("e8dcc0"), "skin": Color("b98458"),
		"wardrobe": ["body_hide", "head_old", "hat_felt", "x_satchels"],
		"lines": {
			"intro": ["Watch the third bend. No, I won't tell you why.", "Forty years on this road. Ask me nothing."],
			"grudge": ["I told you to watch the bend. You didn't listen. That's on you."],
			"win": ["I trust nobody. That's how you win."],
		},
	},
	"sonam": {
		"name": "Sonam Phurba", "region": "Changtang", "seasons": [0, 1, 2], "weapon": "fists", "ranged": "sling", "shield": false,
		"horse": "sonam_bay", "skill": 0.7, "aggression": 0.5, "lane": 0.6, "pace": 0.96, "style": "harasser", "bon": true,
		"slot_a": Color("3d6fa8"), "slot_b": Color("e8e0cf"), "skin": Color("a87a52"),
		"wardrobe": ["body_fleece", "head_young", "hat_fox", "x_satchels"],
		"lines": {
			"intro": ["Salt is heavy. Stones are lighter. Guess which I throw.", "I'm not slow. I'm patient."],
			"grudge": ["You hit me once. I have a great many stones."],
			"win": ["Slow and stubborn. It works for salt."],
		},
	},
	"pasang": {
		"name": "Pasang Tsomo", "region": "Changtang", "seasons": [0, 1, 2], "weapon": "whip", "ranged": "", "shield": false,
		"horse": "pasang_brown", "skill": 0.7, "aggression": 0.4, "lane": 0.35, "pace": 0.955, "style": "blocker", "bon": false,
		"slot_a": Color("5a3b6e"), "slot_b": Color("c9a227"), "skin": Color("b07f58"),
		"wardrobe": ["body_fleece", "head_woman", "hair_plaits"],
		"lines": {
			"intro": ["This is my lane. You may ask me to move. I may say no.", "Come to me. I'll wait."],
			"grudge": ["You pushed me out of my lane. Nobody does that."],
			"win": ["I didn't move. They moved."],
		},
	},
	"samdup": {
		"name": "Lithang Samdup", "region": "Kham", "seasons": [0, 1, 2], "weapon": "knife", "ranged": "", "shield": false,
		"horse": "samdup_pinto", "skill": 0.65, "aggression": 0.6, "lane": -0.3, "pace": 0.95, "style": "trickster", "bon": false,
		"slot_a": Color("e8b82a"), "slot_b": Color("b3262b"), "skin": Color("c28b5e"),
		"wardrobe": ["body_oneoff", "head_young", "hat_big", "x_casebell"],
		"lines": {
			"intro": ["If I fall off, it was on purpose.", "Watch this! Actually, watch that, it's shinier."],
			"grudge": ["You made me look foolish. Only I'm allowed to do that."],
			"win": ["Did you see the scarf? I got the scarf!"],
		},
	},
	"temba": {
		"name": "Temba Tinle", "region": "Lhasa", "seasons": [0, 1, 2], "weapon": "pencase", "ranged": "", "shield": false,
		"horse": "temba_dun", "skill": 0.55, "aggression": 0.55, "lane": 0.2, "pace": 0.94, "style": "clerk", "bon": false,
		"slot_a": Color("2c3f8a"), "slot_b": Color("f0c33a"), "skin": Color("d0a078"),
		"wardrobe": ["body_chuba", "head_young", "hat_basin"],
		"lines": {
			"intro": ["Under by-law nine, you may not overtake a sixth-rank official. By-law nine is new.", "I have a form for this."],
			"grudge": ["I have filed a complaint about your elbow."],
			"win": ["By-law twelve says the winner is correct."],
		},
	},
	"pema": {
		"name": "Pema Yangkey", "region": "Tsang", "seasons": [0, 1, 2], "weapon": "fists", "ranged": "bow", "shield": false,
		"horse": "pema_chestnut", "skill": 0.75, "aggression": 0.4, "lane": 0.5, "pace": 0.96, "style": "harasser", "bon": false,
		"slot_a": Color("d6612a"), "slot_b": Color("2f6f8f"), "skin": Color("c58e62"),
		"wardrobe": ["body_chuba", "head_woman", "hair_plaits"],
		"lines": {
			"intro": ["You rode well! Sorry about the arrow.", "I only hit what I aim at. Mostly."],
			"grudge": ["I'm still sorry about the arrow. There will be more."],
			"win": ["Oh! Did I win? How lovely."],
		},
	},
	"dukpa": {
		"name": "Dukpa Tsewang", "region": "Bhutan", "seasons": [0, 1, 2], "weapon": "sword", "ranged": "", "shield": false,
		"horse": "dukpa_bay", "skill": 0.8, "aggression": 0.55, "lane": -0.4, "pace": 0.975, "style": "polite", "bon": false,
		"slot_a": Color("2a7a58"), "slot_b": Color("e9dcc0"), "skin": Color("c08c60"),
		"wardrobe": ["body_chuba", "head_young", "hair_short", "x_scarf"],
		"lines": {
			"intro": ["After you. No, truly. Mind the ditch.", "A pleasure. I shall try not to enjoy this."],
			"grudge": ["I apologise in advance for what comes next."],
			"win": ["How very kind of everyone."],
		},
	},
	"thupden": {
		"name": "Thupden Bum", "region": "Golok", "seasons": [1, 2], "weapon": "spear", "ranged": "", "shield": false,
		"horse": "thupden_shaggy", "skill": 0.7, "aggression": 0.9, "lane": 0.0, "pace": 0.965, "style": "brawler", "bon": false,
		"slot_a": Color("7a5a32"), "slot_b": Color("c8452a"), "skin": Color("a87450"),
		"wardrobe": ["body_hide", "head_young", "hair_mop"],
		"lines": {
			"intro": ["My horse owes nobody. Neither do I. You owe me a hat.", "I ram. Then I run. Then I ram."],
			"grudge": ["You owe me a hat. I'm collecting."],
			"win": ["Nobody owns the wind!"],
		},
	},
	"drukmo": {
		"name": "Drukmo Kyi", "region": "Amdo", "seasons": [1, 2], "weapon": "fists", "ranged": "bow", "shield": false,
		"horse": "drukmo_palomino", "skill": 0.88, "aggression": 0.5, "lane": 0.3, "pace": 0.975, "style": "finisher", "bon": false,
		"slot_a": Color("d99a2a"), "slot_b": Color("f4f0e0"), "skin": Color("b98258"),
		"wardrobe": ["body_fleece", "head_woman", "hat_peak", "x_backpanel"],
		"lines": {
			"intro": ["They named me for a prize. I've come to collect it.", "Watch my back. Not literally. I'm faster."],
			"grudge": ["You thought I was somebody's prize. Now you know."],
			"win": ["I told you I'd collect."],
		},
	},
	"genden": {
		"name": "Genden Gyal", "region": "Eastern plateau", "seasons": [1, 2], "weapon": "fists", "ranged": "", "shield": true,
		"horse": "genden_grey", "skill": 0.55, "aggression": 0.15, "lane": -0.2, "pace": 0.94, "style": "avoider", "bon": false,
		"slot_a": Color("8a5a2a"), "slot_b": Color("d4a23a"), "skin": Color("c19064"),
		"wardrobe": ["body_chuba", "head_old", "hat_felt", "x_casebell"],
		"lines": {
			"intro": ["Your colour is bad. Have you been eating enough butter? Also, I would duck.", "Fight? No, no. Do you have a cough?"],
			"grudge": ["You hit a doctor. Do you know how rare we are? Hold still."],
			"win": ["It is a matter of circulation."],
		},
	},
	"pamo": {
		"name": "Pamo Kunga Wangmo", "region": "Kham", "seasons": [1, 2], "weapon": "fists", "ranged": "roped_spear", "shield": true,
		"horse": "pamo_black", "skill": 0.85, "aggression": 0.35, "lane": 0.15, "pace": 0.97, "style": "blocker", "bon": false,
		"slot_a": Color("1f8a8a"), "slot_b": Color("d5d0c4"), "skin": Color("b98a64"),
		"wardrobe": ["body_chuba", "head_woman", "hair_plaits"],
		"lines": {
			"intro": ["I do not hurry. I arrive.", "My father has a plan. I have the better one."],
			"grudge": ["You were rash. I noted it."],
			"win": ["As expected."],
		},
	},
	"diki": {
		"name": "Lhacham Diki Yangdol", "region": "Lhasa", "seasons": [1, 2], "weapon": "knife", "ranged": "", "shield": false,
		"horse": "diki_arab", "skill": 0.75, "aggression": 0.75, "lane": -0.1, "pace": 0.985, "style": "reckless", "bon": false,
		"slot_a": Color("7a3c8c"), "slot_b": Color("e8e2d0"), "skin": Color("dcb48e"),
		"wardrobe": ["body_chuba", "head_woman", "hair_plaits"],
		"lines": {
			"intro": ["In Calcutta they have machines that do this without the smell.", "Faster! Why is everything so slow?"],
			"grudge": ["You scuffed my silk. Nobody scuffs my silk."],
			"win": ["Finally. Something that goes quickly."],
		},
	},
	"chakri": {
		"name": "Lobsang Wangdu", "region": "Lhasa", "seasons": [2], "weapon": "key", "ranged": "", "shield": false,
		"horse": "chakri_bay", "skill": 0.8, "aggression": 0.9, "lane": 0.0, "pace": 0.975, "style": "brawler", "bon": false,
		"slot_a": Color("5b3a2a"), "slot_b": Color("c4262e"), "skin": Color("8f6444"),
		"wardrobe": ["body_chuba", "head_soot", "hair_earlocks", "x_armcloth"],
		"lines": {
			"intro": ["That hurt! Good. Whoever you are, we're friends now.", "Come closer. I only hit people I like."],
			"grudge": ["You hit me last time. I liked it. Come here."],
			"win": ["Winnings go to the beggars. Their hats are better than mine."],
		},
	},
	"serkhar": {
		"name": "Serkhar Tashi Gyaltsen", "region": "Lhasa", "seasons": [2], "weapon": "spear", "ranged": "", "shield": false,
		"horse": "serkhar_grey", "skill": 0.72, "aggression": 0.7, "lane": 0.1, "pace": 0.96, "style": "brawler", "bon": false,
		"slot_a": Color("9a7a1a"), "slot_b": Color("2a2a6a"), "skin": Color("d3a67e"),
		"wardrobe": ["body_brocade", "head_old", "hat_disc"],
		"lines": {
			"intro": ["I will pay you back for that. I will pay everyone back. Eventually.", "Magnificence is expensive."],
			"grudge": ["You will be repaid. In full. Eventually."],
			"win": ["Now I can pay one person."],
		},
	},
	"ama": {
		"name": "Ama Choekyi", "region": "Kalimpong", "seasons": [2], "weapon": "pencase", "ranged": "", "shield": false,
		"horse": "ama_felt", "skill": 0.75, "aggression": 0.6, "lane": 0.25, "pace": 0.96, "style": "clerk", "bon": false,
		"slot_a": Color("a8402a"), "slot_b": Color("3a6a9a"), "skin": Color("bd8a62"),
		"wardrobe": ["body_chuba", "head_woman_old", "hat_foreign", "x_bale"],
		"lines": {
			"intro": ["You owe me eighty srang. Ride accordingly.", "Nobody cheats me twice."],
			"grudge": ["Interest, dear. Compound interest."],
			"win": ["Family business."],
		},
	},
}

const PLAYERS := {
	"joru": {
		"name": "Joru", "region": "Kham", "seasons": [0, 1, 2], "weapon": "fists", "ranged": "", "shield": false,
		"horse": "old_tsampa", "skill": 0.66, "aggression": 0.65, "lane": 0.0, "pace": 1.0, "style": "brawler", "bon": false,
		"slot_a": Color("7a1c22"), "slot_b": Color("f2b632"), "skin": Color("c58e62"),
		"wardrobe": ["body_chuba", "head_young", "hair_wound"],
		"lines": {"intro": ["Nobody expects anything from me. Good."], "grudge": [], "win": ["Tell the aunt the interest is paid."]},
	},
	"yangkyi": {
		"name": "Yangkyi", "region": "Amdo", "seasons": [0, 1, 2], "weapon": "fists", "ranged": "", "shield": false,
		"horse": "old_tsampa", "skill": 0.68, "aggression": 0.65, "lane": 0.0, "pace": 1.0, "style": "sprinter", "bon": false,
		"slot_a": Color("5f7f9e"), "slot_b": Color("c4262e"), "skin": Color("c28b62"),
		"wardrobe": ["body_chuba", "head_woman", "hair_plaits"],
		"lines": {"intro": ["Light and quick. That's the whole plan."], "grudge": [], "win": ["Quick, and also right."]},
	},
}

# Prize / bounty / fine by season (0..2).
const PRIZES := [[200, 120, 70], [420, 260, 150], [800, 500, 300]]
const BOUNTIES := [15, 30, 60]
const FINES := [40, 90, 180]


static func prize(season: int, place: int) -> int:
	if place < 1 or place > 3:
		return 0
	return PRIZES[clampi(season, 0, 2)][place - 1]


static func bounty(season: int) -> int:
	return BOUNTIES[clampi(season, 0, 2)]


static func fine(season: int) -> int:
	return FINES[clampi(season, 0, 2)]


static func weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS["fists"])


## A rough worth for "is this better than mine" comparisons.
static func weapon_value(id: String) -> float:
	var w: Dictionary = WEAPONS.get(id, WEAPONS["fists"])
	var damage: float = w["damage"]
	var impact: float = w["impact"]
	return damage + impact * 0.6


static func rival_ids_for_season(season: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in RIVALS:
		var seasons: Array = RIVALS[id]["seasons"]
		if seasons.has(season):
			out.append(id)
	return out


static func saddle_cut(level: int) -> float:
	var arr: Array = TACK["saddle"]
	var e: Dictionary = arr[clampi(level, 0, arr.size() - 1)]
	return e["impact_cut"]


static func armor_health(level: int) -> float:
	var arr: Array = TACK["armor"]
	var e: Dictionary = arr[clampi(level, 0, arr.size() - 1)]
	return e["health"]
