"""Every spoken line that is not already in the game's menus: who says it, when, and in which language.

art/tools/make_voices.py turns this into audio, data/voice_bank.gd and docs/VOICE_SCRIPT.md.

Tibetan lines keep the real script for the speech model, a plain pronunciation for the subtitle and an English gloss.
The grammar is colloquial Lhasa-style Tibetan written by Claude and checked only against public phrasebooks and word
lists. Kham and Amdo riders read the same words in their own dialect's voice, which is not how they'd really phrase it.
No Tibetan speaker has reviewed this yet. See docs/VOICE_SCRIPT.md, which is laid out for that review.

Rules from docs/GAME_DESIGN.md hold here too: no mantras or chanting, nothing about monks, the PLA or 1959, and women
aren't prizes. Ki ki so so lha gyalo is the public shout at passes, not a prayer recital.

Categories for rivals:
  pass_by  rival overtakes the player        passed   the player overtakes the rival
  hit_you  rival lands a hit on the player   hurt     the player hits the rival
  down     rival is knocked down near you    gloat    the player falls near the rival
  near     alongside, an idle taunt          hat      the rival's hat is knocked off
  cry      crossing the high pass            win      the rival finishes ahead of the player
  start    on the start line                 scarf    the rival scoops a scarf nearby
Categories for the player's own rider: p_hurt, p_down, p_knock, p_remount, p_wind, p_cry, p_scarf, p_win, p_lose.
"""

# ---------------------------------------------------------------- Tibetan phrases: script, subtitle, gloss
BO = {
    # Cries are spelled with a space after each syllable: the model reads "ཧ་ཧ་ཧ" as one 0.2 s blip but "ཧ་ ཧ་ ཧ" as three.
    "ara": ("ཨ་ ར་ ར", "A RA RA!", "OW!"),
    "akha": ("ཨ་ ཁ་ ཁ", "A KHA KHA!", "OH, NO!"),
    "atsi": ("ཨ་ཙི", "A TSI!", "WHAT!"),
    "amala": ("ཨ་མ་ལགས", "AMA LA!", "MOTHER!"),
    "ala": ("ཨ་ ལ་ ལ", "A LA LA!", "WOW!"),
    "haha": ("ཧ་ ཧ་ ཧ", "HA HA HA!", ""),
    "kale_shu": ("ག་ལེར་བཞུགས", "KALE SHU!", "TAKE YOUR TIME BACK THERE!"),   # literally "stay slowly", said to the one left behind
    "kale_phe": ("ག་ལེར་ཕེབས", "KALE PHE!", "GO GENTLY, THEN!"),              # literally "go slowly", said to the one leaving
    "sab": ("གཟབ་གཟབ་གྱིས", "SAB SAB GYI!", "BE CAREFUL!"),
    "sab_h": ("གཟབ་གཟབ་གནང", "SAB SAB NANG.", "DO TAKE CARE."),
    "tshur": ("ཚུར་ཤོག", "TSHUR SHOK!", "GET BACK HERE!"),
    "phar": ("ཕར་སོང", "PHAR SONG!", "GET AWAY!"),
    "kharok": ("ཁ་རོག་སྡོད", "KHAROK DO!", "SHUT UP!"),
    "lenpa": ("གླེན་པ", "LENPA!", "FOOL!"),
    "gyok": ("མགྱོགས་པོ་ མགྱོགས་པོ", "GYOKPO! GYOKPO!", "QUICK! QUICK!"),
    "shok": ("ཤོག་ ཤོག", "SHOK! SHOK!", "COME ON!"),
    "kare": ("ག་རེ་བྱེད་ཀྱི་ཡོད", "KARE CHE-GYI YO?", "WHAT ARE YOU DOING?"),
    "kare_song": ("ག་རེ་བྱས་སོང", "KARE CHE SONG?", "WHAT HAPPENED?"),
    "yarlong": ("ཡར་ལོངས", "YAR LONG!", "GET UP!"),
    "tashi": ("བཀྲ་ཤིས་བདེ་ལེགས", "TASHI DELEK!", "GOOD FORTUNE!"),
    "thukje": ("ཐུགས་རྗེ་ཆེ", "THUK JE CHE!", "THANK YOU!"),
    "gongda": ("དགོངས་དག", "GONGDA!", "SO SORRY!"),
    "yakpo": ("ཡག་པོ་འདུག", "YAKPO DU!", "NICE!"),
    "yakpo_jung": ("ཡག་པོ་བྱུང", "YAKPO JUNG!", "GOT IT!"),
    "kyipo": ("སྐྱིད་པོ་འདུག", "KYIPO DU!", "THIS IS FUN!"),
    "yamtsen": ("ཡ་མཚན་འདུག", "YAMTSEN DU!", "HOW STRANGE!"),
    "won": ("ང་རྒྱལ་བྱུང", "NGA GYAL JUNG!", "I WON!"),
    "no1": ("ང་ཨང་དང་པོ་ཡིན", "NGA ANG DANGPO YIN!", "I AM NUMBER ONE!"),
    "hat": ("ངའི་ཞྭ་མོ", "NGE SHAMO!", "MY HAT!"),
    "kiki": ("ཀི་ཀི་སོ་སོ་ ལྷ་རྒྱལ་ལོ", "KI KI SO SO! LHA GYALO!", "VICTORY TO THE GODS!"),
    "lhagyal": ("ལྷ་རྒྱལ་ལོ", "LHA GYALO!", "VICTORY TO THE GODS!"),
    "shuk": ("ཤུགས་རྒྱོབ", "SHUK GYOB!", "PUT YOUR BACK INTO IT!"),
    "ta_yakpo": ("རྟ་ཡག་པོ་འདུག", "TA YAKPO DU!", "GOOD HORSE!"),
    "to": ("བལྟོས་ བལྟོས", "TO! TO!", "LOOK! LOOK!"),
    # Character lines
    "never_lost": ("ང་ནམ་ཡང་ཕམ་མྱོང་མེད", "NGA NAMYANG PHAM NYONG ME!", "I HAVE NEVER LOST!"),
    "bad_horse": ("ཁྱོད་ཀྱི་རྟ་ཡག་པོ་མི་འདུག", "KHYO-KYI TA YAKPO MINDU!", "YOUR HORSE IS NO GOOD!"),
    "know_road": ("ལམ་འདི་ངས་ཤེས་ཀྱི་ཡོད", "LAM DI NGE SHE-KYI YO.", "I KNOW THIS ROAD."),
    "slowly": ("ག་ལེ་ ག་ལེ", "KALE, KALE.", "SLOWLY, SLOWLY."),
    "my_road": ("ལམ་འདི་ངའི་རེད", "LAM DI NGE RE!", "THIS ROAD IS MINE!"),
    "not_ok": ("མི་འགྲིག་ མི་འགྲིག", "MI DRIK! MI DRIK!", "NOT PERMITTED!"),
    "after_you": ("ཁྱེད་རང་སྔོན་ལ་ཕེབས", "KHYERANG NGON-LA PHE.", "AFTER YOU."),
    "my_hat_back": ("ངའི་ཞྭ་མོ་སྤྲོད", "NGE SHAMO TRO!", "GIVE ME MY HAT!"),
    "hurt_q": ("ན་གི་འདུག་གས", "NA-GI DU-GE?", "DOES IT HURT?"),
    "butter": ("མར་མང་པོ་ཟོས", "MAR MANGPO SO!", "EAT MORE BUTTER!"),
    "friends": ("ང་ཚོ་གྲོགས་པོ་རེད", "NGATSO DROKPO RE!", "WE'RE FRIENDS!"),
    "tomorrow": ("སང་ཉིན་སྤྲོད་ཀྱི་ཡིན", "SANGNYIN TRO-GYI YIN!", "I'LL PAY TOMORROW!"),
    "pay_me": ("སྲང་བརྒྱད་ཅུ་སྤྲོད", "SANG GYECHU TRO!", "PAY ME EIGHTY SRANG!"),
    "fine": ("ཉེས་ཆད་སྤྲོད", "NYECHE TRO!", "PAY THE FINE!"),
    "hands_down": ("ལག་པ་ཕོབ", "LAKPA PHOP!", "HANDS DOWN!"),
    "ready": ("རྟ་པ་ཚོ་ གྲ་སྒྲིག་གྱིས", "TAPA-TSO, DRADRIK GYI!", "RIDERS, GET READY!"),
    "three": ("གསུམ", "SUM!", "THREE!"),
    "two": ("གཉིས", "NYI!", "TWO!"),
    "one": ("གཅིག", "CHIK!", "ONE!"),
    "go": ("སོང་ སོང་ སོང", "SONG! SONG! SONG!", "GO! GO! GO!"),
}

# Which shared Tibetan phrases a rival can use in each category. make_voices.py gives each rival a steady subset.
BO_POOL = {
    "pass_by": ["kale_shu", "haha", "shok"],
    "passed": ["tshur", "kale_phe", "atsi", "yamtsen"],
    "hit_you": ["haha", "kharok", "lenpa"],
    "hurt": ["ara", "atsi", "akha"],
    "down": ["amala", "akha"],
    "gloat": ["yarlong", "kare_song", "haha", "sab"],
    "near": ["phar", "kare", "gyok", "ta_yakpo"],
    "hat": ["hat"],
    "cry": ["kiki"],
    "win": ["won", "no1"],
    "start": ["tashi"],
    "scarf": ["ala"],
}
POOL_KEEP = {"pass_by": 2, "passed": 2, "hit_you": 2, "hurt": 2, "down": 2, "gloat": 2, "near": 2, "hat": 1, "cry": 1, "win": 1, "start": 1, "scarf": 1}

# ---------------------------------------------------------------- voices
# en: Kokoro pipeline ("a" American or "b" British spelling rules), voice, speed, pitch ratio (1.0 = untouched).
#     A voice can be a blend of two ("bm_daniel:0.6,bm_fable:0.4"), which also steadies Kokoro's thinner voices. Pitch moves by
#     resampling, which raises or lowers the formants with it, like a smaller or bigger person. No vocoder touches English.
#     Kokoro fetches a voice the first time it's used, and make_voices.py runs offline, so fetch any new one first.
# bo: Tibetan model (bod Central, khg Khams, adx Amdo), target pitch in Hz, formant ratio, tempo (1.0 = a quarter second
#     a syllable, 1.1 = ten percent faster). Women's and old voices come from the one male reader through the WORLD vocoder.
#     The pitch is the calm speaking pitch: a shout is made 14 percent higher. The readers' own pitch is bod 154 Hz, khg 113,
#     adx 133 and the English voices sit near 120 to 145 Hz for men and 180 to 225 for women, so each speaker's Tibetan pitch
#     is set near the pitch of their English voice, which keeps the vocoder's shifts small and makes both sound like one person.
# tremor: a little shake in the pitch, for age. rows are kept near the cast list in docs/WORLD_AND_CAST.md.
SPEAKERS = {
    "wangyal": {"name": "Pon Wangyal Dorje", "en": ("b", "bm_fable", 1.04, 1.0), "bo": ("khg", 120, 1.01, 1.0)},
    "karma": {"name": "Karma Tobgye", "en": ("a", "am_onyx:0.6,am_fenrir:0.4", 0.95, 0.98), "bo": ("khg", 95, 0.97, 0.9), "tremor": 0.008},
    "sonam": {"name": "Sonam Phurba", "en": ("a", "am_michael", 0.92, 0.96), "bo": ("bod", 110, 0.96, 0.88)},
    "pasang": {"name": "Pasang Tsomo", "en": ("a", "af_kore", 0.96, 0.98), "bo": ("bod", 162, 1.14, 0.95)},
    "samdup": {"name": "Lithang Samdup", "en": ("a", "am_puck", 1.12, 1.08), "bo": ("khg", 130, 1.05, 1.12)},
    "temba": {"name": "Temba Tinle", "en": ("b", "bm_daniel:0.6,bm_fable:0.4", 1.08, 1.2), "bo": ("bod", 115, 1.04, 1.08)},
    "pema": {"name": "Pema Yangkey", "en": ("a", "af_bella", 1.04, 1.0), "bo": ("bod", 205, 1.18, 1.05)},
    "dukpa": {"name": "Dukpa Tsewang", "en": ("a", "hm_psi", 1.0, 1.03), "bo": ("bod", 128, 1.0, 0.96)},
    "thupden": {"name": "Thupden Bum", "en": ("a", "am_fenrir", 1.05, 1.0), "bo": ("adx", 141, 0.98, 1.05)},
    "drukmo": {"name": "Drukmo Kyi", "en": ("a", "af_nova:0.6,af_sarah:0.4", 1.0, 1.0), "bo": ("adx", 195, 1.15, 1.0)},
    "genden": {"name": "Genden Gyal", "en": ("a", "hm_omega", 1.06, 1.02), "bo": ("adx", 112, 1.02, 1.1), "tremor": 0.004},
    "pamo": {"name": "Pamo Kunga Wangmo", "en": ("a", "af_aoede", 0.93, 0.97), "bo": ("khg", 180, 1.13, 0.92)},
    "diki": {"name": "Lhacham Diki Yangdol", "en": ("b", "bf_isabella:0.6,bf_emma:0.4", 1.14, 1.05), "bo": ("bod", 220, 1.2, 1.16)},
    "chakri": {"name": "Lobsang Wangdu", "en": ("a", "am_michael:0.5,am_onyx:0.5", 1.0, 1.0), "bo": ("bod", 100, 0.94, 1.0)},
    "serkhar": {"name": "Serkhar Tashi Gyaltsen", "en": ("b", "bm_lewis:0.6,bm_george:0.4", 0.92, 0.97), "bo": ("bod", 108, 0.96, 0.9), "tremor": 0.006},
    "ama": {"name": "Ama Choekyi", "en": ("a", "hf_beta", 0.98, 0.92), "bo": ("bod", 160, 1.1, 0.95), "tremor": 0.008},
    "joru": {"name": "Joru", "en": ("a", "am_michael", 1.04, 1.1), "bo": ("khg", 125, 1.03, 1.05)},
    "yangkyi": {"name": "Yangkyi", "en": ("a", "af_heart", 1.05, 1.0), "bo": ("adx", 215, 1.18, 1.1)},
    # age: made older still by make_voices.age_voice. f0 moves the pitch on its own, the vocal tract staying put: men's voices
    # tend to rise and thin with great age, women's to fall. spread narrows the tune, quaver and jitter shake the pitch,
    # shimmer shakes the strength, breath lets air through the voice (0 to 1), tilt takes the top off (dB an octave above 1 kHz).
    "pola": {"name": "Pola", "en": ("b", "bm_george", 0.76, 0.93), "bo": ("khg", 108, 0.98, 0.8), "pause": 0.26,
             "age": {"f0": 1.14, "spread": 0.8, "quaver": 0.05, "jitter": 0.018, "shimmer": 0.2, "breath": 0.62, "tilt": -1.4}},
    "mola": {"name": "Mola", "en": ("b", "bf_emma", 0.78, 0.92), "bo": ("adx", 155, 1.12, 0.8), "pause": 0.26,
             "age": {"f0": 0.97, "spread": 0.8, "quaver": 0.052, "jitter": 0.018, "shimmer": 0.2, "breath": 0.66, "tilt": -1.6}},
    "child": {"name": "The grandchild", "en": ("a", "af_sky", 1.0, 1.4)},
    "steward": {"name": "Race steward", "en": ("b", "bm_daniel:0.5,bm_lewis:0.5", 1.05, 1.08), "bo": ("bod", 140, 1.05, 1.05)},
    "starter": {"name": "The starter", "en": ("b", "bm_george", 1.0, 1.0), "bo": ("bod", 123, 0.98, 0.95)},
}

# Which speaker says every distinct Tibetan phrase for the phrasebook (files <speaker>_<md5 of the script>.ogg): the
# starter, in the calm "call" style, so the phrases are clear rather than shouted. The races reuse the starter's own files.
PHRASEBOOK_SPEAKER = "starter"

# A Tibetan take whose fit score (length and syllable peaks, see make_voices.py) is worse than this is called poor.
FIT_LIMIT = 0.40

# Cries the model turns to mush. When the plain take fits badly they are built from single syllables with gaps and a falling
# pitch instead. Syllables as the model reads them (tsheg after each).
STITCH = {
    "ara": ["ཨ་", "ར་", "ར་"],
    "akha": ["ཨ་", "ཁ་", "ཁ་"],
    "ala": ["ཨ་", "ལ་", "ལ་"],
    "haha": ["ཧ་", "ཧ་", "ཧ་"],
}

# Phrases Claude is least sure of, for the Tibetan reviewer (shown in docs/VOICE_SCRIPT.md). Keys are BO keys.
DOUBT = {
    "atsi": "an exclamation; the spelling may be wrong (perhaps ཨ་ཅི)",
    "amala": "meant as the exclamation 'mother!'; check the spelling and the honorific",
    "sab": "the imperative ending གྱིས may not be what is said; compare བྱོས",
    "sab_h": "the honorific imperative གནང is a guess",
    "kharok": "not sure this is a natural way to say 'shut up'",
    "kare_song": "ག་རེ་བྱས་སོང reads 'what did you do?'; 'what happened' may be ག་རེ་བྱུང་སོང",
    "won": "the past tense of 'win' is a guess",
    "shuk": "unsure of the meaning and register",
    "hurt_q": "the question ending འདུག་གས is a guess",
    "butter": "ཟོས is a past form; an imperative may be better",
    "ready": "the imperative ending is a guess",
    "to": "ལྟོས ('look') may need a pronoun or a different imperative",
    "my_hat_back": "སྤྲོད is formal; ཕྱིར་སྤྲོད may be what is wanted",
}

# ---------------------------------------------------------------- English in-race chatter
EN = {
    "wangyal": {
        "pass_by": ["Did you see that? Everyone saw that.", "Wave to my mother as I pass."],
        "passed": ["That was my slow horse!", "Hey! I was letting you!"],
        "hit_you": ["You're welcome.", "That's the nicest thing I'll do today."],
        "hurt": ["Not the face!", "My mother is watching!"],
        "down": ["In front of my mother!"],
        "gloat": ["Come to my tent later. I'll explain riding."],
        "near": ["Do you know who my father is?", "Nice pony. Does it do anything?"],
        "hat": ["You knocked my hat off!"],
        "win": ["Never lost. Tell everyone."],
    },
    "karma": {
        "pass_by": ["Forty years. Stay behind me.", "You're wasting that horse."],
        "passed": ["Go on, then. Bend's coming.", "Young. You'll learn."],
        "hit_you": ["Eyes up, boy.", "That's lesson one."],
        "hurt": ["I've had worse from mules.", "Hm. Lucky."],
        "down": ["Should've gone by the river!"],
        "gloat": ["Told you to watch the bend."],
        "near": ["Don't trust me.", "Who taught you to sit like that?"],
        "hat": ["Forty years I've had that hat."],
        "win": ["Knew the road. Knew the riders."],
    },
    "sonam": {
        "pass_by": ["Slow is a kind of fast.", "Stubborn beats quick."],
        "passed": ["Go on. You'll tire. I won't.", "I'll see you at the salt."],
        "hit_you": ["I have more stones.", "A stone for your trouble."],
        "hurt": ["Stones are easier.", "Ow. Still stubborn."],
        "down": ["Mind the salt!"],
        "gloat": ["Stay there. Stones are heavy."],
        "near": ["Salt or stones? Choose."],
        "hat": ["That was my good hat."],
        "win": ["Patience. And stones."],
    },
    "pasang": {
        "pass_by": ["My lane. You left it.", "Stay out."],
        "passed": ["Go round, then. Fine."],
        "hit_you": ["My lane.", "I said no."],
        "hurt": ["Try that again.", "No."],
        "down": ["That was my lane!"],
        "gloat": ["You were in my lane."],
        "near": ["Move.", "Ask me to move. I'll say no."],
        "win": ["I didn't move. They moved."],
    },
    "samdup": {
        "pass_by": ["Did you see that? Tell me you saw that!", "No hands! Almost!"],
        "passed": ["I meant to do that!", "I'm letting you feel good!"],
        "hit_you": ["Ooh, sorry! Not sorry!", "Ta-da!"],
        "hurt": ["Careful! I'm decorative!", "Hey! Watch the bells!"],
        "down": ["On purpose! That was on purpose!"],
        "gloat": ["Nice dismount! Six out of ten!"],
        "near": ["Watch this! No, watch the road!", "That scarf's mine!"],
        "hat": ["Give that back! It's the whole act!"],
        "scarf": ["I got the scarf!"],
        "win": ["Did you see the scarf?"],
    },
    "temba": {
        "pass_by": ["Noted.", "Overtaken in accordance with by-law four."],
        "passed": ["That requires a permit!", "I am writing this down!"],
        "hit_you": ["Stamped.", "Consider yourself filed."],
        "hurt": ["I am a sixth-rank official!", "My notebook!"],
        "down": ["This will need a form!"],
        "gloat": ["Falling carries a fee."],
        "near": ["Your papers, please.", "By-law nine!"],
        "hat": ["That hat is government property!"],
        "win": ["By-law twelve applies."],
    },
    "pema": {
        "pass_by": ["Lovely day for it!", "You're doing so well!"],
        "passed": ["Oh, well ridden!", "Good for you!"],
        "hit_you": ["Sorry! So sorry!", "Oops! Sorry about that!"],
        "hurt": ["Oh! Good arm!", "Ow! You're quite strong!"],
        "down": ["Oh dear, oh dear, oh dear!"],
        "gloat": ["Are you all right? Good!"],
        "near": ["Mind if I shoot you?", "Sorry in advance!"],
        "win": ["Oh! Did I win? How lovely."],
    },
    "dukpa": {
        "pass_by": ["Pardon me. Excuse me. Thank you.", "A thousand apologies."],
        "passed": ["After you. No, truly.", "Very well ridden. Mind the ditch."],
        "hit_you": ["I do beg your pardon.", "So sorry. Was that your ear?"],
        "hurt": ["How very forward.", "Most kind."],
        "down": ["Terribly sorry, I seem to be falling."],
        "gloat": ["Do take your time down there."],
        "near": ["Lovely ditch, over there.", "Would you care to move? No?"],
        "win": ["How very kind of everyone."],
    },
    "thupden": {
        "pass_by": ["Nobody owns the road!", "Ha! Free as the wind!"],
        "passed": ["You still owe me a hat!", "Run! I like it when they run!"],
        "hit_you": ["Ram, then run!", "Ha! Again!"],
        "hurt": ["Good! Harder!", "Ha! That tickled!"],
        "down": ["Nobody keeps me down!"],
        "gloat": ["I'll have your hat."],
        "near": ["Nice hat. Mine now.", "Hat. Now."],
        "win": ["Nobody owns the wind!"],
    },
    "drukmo": {
        "pass_by": ["I told you. I collect.", "Watch my back. You'll get used to it."],
        "passed": ["Enjoy it. I finish strong.", "Save your breath."],
        "hit_you": ["Prize that.", "That's for asking."],
        "hurt": ["You'll pay for that.", "Wrong woman."],
        "down": ["Count it. It won't happen twice!"],
        "gloat": ["Stay down. It suits you."],
        "near": ["Nobody wins me. Try it."],
        "hat": ["Touch that hat again. Go on."],
        "win": ["I told you I'd collect."],
    },
    "genden": {
        "pass_by": ["Lovely gait on that horse. You, less so.", "Breathe through the nose!"],
        "passed": ["Slow down, your colour is terrible!", "You'll get a stitch!"],
        "hit_you": ["Hold still. That's for the swelling.", "There. Reflexes fine."],
        "hurt": ["I'm a doctor!", "That's a bruise. I would know."],
        "down": ["Nobody panic! I'm a doctor!"],
        "gloat": ["Don't move! Actually, do. You're blocking the road."],
        "near": ["Let me see your tongue.", "More butter. I mean it."],
        "hat": ["My hat! Is it serious?"],
        "win": ["It's a matter of circulation."],
    },
    "pamo": {
        "pass_by": ["As planned.", "You were predictable."],
        "passed": ["You'll tire on the climb.", "I'll be there when you slow."],
        "hit_you": ["You left your side open.", "Rash."],
        "hurt": ["Interesting.", "Rash. But interesting."],
        "down": ["Temporarily."],
        "gloat": ["As expected."],
        "near": ["You're thinking too loudly.", "Move left. Your other left."],
        "win": ["As expected."],
    },
    "diki": {
        "pass_by": ["Too slow! Everything's too slow!", "In Calcutta you'd be run over!"],
        "passed": ["How dare you be faster!", "Excuse me, this is silk!"],
        "hit_you": ["Oh, did that hurt? How dull.", "Out of the way, darling."],
        "hurt": ["My silk!", "Do you know what this cost?"],
        "down": ["This is why I want a motorbike!"],
        "gloat": ["Someone clear that away."],
        "near": ["Is this as fast as it goes?", "Does it have a second gear?"],
        "win": ["Finally. Something that goes quickly."],
    },
    "chakri": {
        "pass_by": ["Come on, friend! Catch me!", "Too slow! I still like you!"],
        "passed": ["Ha! Come back and hit me!", "Where are you going, friend?"],
        "hit_you": ["We're friends now!", "That's how I say hello!"],
        "hurt": ["Good one! Again!", "Ha! I like you!"],
        "down": ["Best day! Best day!"],
        "gloat": ["Get up, friend! We've only started!"],
        "near": ["Come closer.", "You've got a good face for hitting."],
        "win": ["Good fight! Who's hungry?"],
    },
    "serkhar": {
        "pass_by": ["Stand aside for magnificence.", "Send the bill to my steward."],
        "passed": ["I'll buy that horse from you!", "Put that on my account!"],
        "hit_you": ["Consider it a payment.", "Repaid. In part."],
        "hurt": ["This robe is borrowed!", "You will be repaid! Eventually!"],
        "down": ["Mind the brocade!"],
        "gloat": ["I'd help you up, but I can't afford it."],
        "near": ["Lend me ten srang?", "Magnificent, isn't it? It isn't paid for."],
        "hat": ["That hat isn't paid for!"],
        "win": ["Now I can pay one person."],
    },
    "ama": {
        "pass_by": ["Eighty srang, dear.", "That's interest, overtaking you."],
        "passed": ["Ride faster. You owe me.", "Win, then. I'll take my share."],
        "hit_you": ["Interest, dear.", "That's on account."],
        "hurt": ["That goes on your bill!", "Add ten srang for that!"],
        "down": ["I'm charging you for this!"],
        "gloat": ["Get up. Riders on the ground don't pay."],
        "near": ["Have you eaten? You still owe me.", "Sit up straight. You're family."],
        "hat": ["That's my good hat! Twelve srang!"],
        "win": ["Family business."],
    },
    # The player's own rider
    "joru": {
        "p_hurt": ["Ow!", "Hey!"],
        "p_down": ["Not again!", "Old Tsampa, wait!"],
        "p_knock": ["Stay down!", "Tell my aunt about that one!", "Old Tsampa says hello!"],
        "p_remount": ["Up. Up, up, up.", "Sorry, old friend."],
        "p_wind": ["Now, Old Tsampa! Now!"],
        "p_scarf": ["Got it!"],
        "p_win": ["Tell the aunt the interest is paid."],
        "p_lose": ["Next time."],
    },
    "yangkyi": {
        "p_hurt": ["Ow!", "Hey!"],
        "p_down": ["Not again!", "Wait for me!"],
        "p_knock": ["Stay down!", "Quick, and also right!", "He won in the end, you know."],
        "p_remount": ["Up. Up, up, up.", "Good horse. Good horse."],
        "p_wind": ["Light and quick! Now!"],
        "p_scarf": ["Got it!"],
        "p_win": ["Quick, and also right."],
        "p_lose": ["Next time."],
    },
    "steward": {
        "fine": ["You there! That's a fine!", "No lying about on the road!", "Name and village, please!"],
        "quiet": ["Hands down, riders! Hands down!"],
    },
    "starter": {
        "ready": ["Riders ready!"],
        "three": ["Three!"],
        "two": ["Two!"],
        "one": ["One!"],
        "go": ["Go! Go! Go!"],
    },
    "child": {
        "and_then": ["And then?"],
    },
    # The storyteller greets the child before the tale (the sayings are in SAYINGS below).
    "pola": {
        "greet": ["Come in, little one. Sit down."],
    },
    "mola": {
        "greet": ["Come in, little one. Sit down."],
    },
}

# Tibetan lines each speaker has on top of the shared pool. (category, phrase key)
BO_EXTRA = {
    "wangyal": [("near", "bad_horse"), ("pass_by", "never_lost"), ("win", "never_lost")],
    "karma": [("near", "know_road"), ("gloat", "sab")],
    "sonam": [("pass_by", "slowly"), ("passed", "slowly")],
    "pasang": [("near", "my_road"), ("hit_you", "my_road")],
    "samdup": [("near", "to"), ("pass_by", "kyipo"), ("scarf", "kyipo")],
    "temba": [("near", "not_ok"), ("passed", "not_ok")],
    "pema": [("hit_you", "gongda"), ("passed", "yakpo"), ("start", "tashi")],
    "dukpa": [("near", "after_you"), ("hit_you", "gongda"), ("passed", "sab_h"), ("gloat", "sab_h")],
    "thupden": [("near", "my_hat_back"), ("passed", "my_hat_back")],
    "drukmo": [("hit_you", "kharok"), ("win", "lhagyal")],
    "genden": [("hit_you", "hurt_q"), ("near", "butter"), ("gloat", "hurt_q")],
    "pamo": [("passed", "slowly"), ("near", "yakpo")],
    "diki": [("near", "gyok"), ("pass_by", "gyok")],
    "chakri": [("hit_you", "friends"), ("hurt", "friends"), ("near", "tshur")],
    "serkhar": [("near", "tomorrow"), ("hurt", "tomorrow")],
    "ama": [("near", "pay_me"), ("hit_you", "pay_me"), ("pass_by", "pay_me")],
    "joru": [("p_hurt", "ara"), ("p_hurt", "atsi"), ("p_down", "amala"), ("p_down", "akha"), ("p_knock", "lhagyal"), ("p_knock", "yakpo_jung"), ("p_remount", "yarlong"), ("p_remount", "gyok"), ("p_wind", "kiki"), ("p_wind", "shuk"), ("p_cry", "kiki"), ("p_scarf", "ala"), ("p_scarf", "yakpo_jung"), ("p_win", "won"), ("p_win", "lhagyal"), ("p_lose", "akha")],
    "yangkyi": [("p_hurt", "ara"), ("p_hurt", "atsi"), ("p_down", "amala"), ("p_down", "akha"), ("p_knock", "lhagyal"), ("p_knock", "yakpo_jung"), ("p_remount", "yarlong"), ("p_remount", "gyok"), ("p_wind", "kiki"), ("p_wind", "shuk"), ("p_cry", "kiki"), ("p_scarf", "ala"), ("p_scarf", "yakpo_jung"), ("p_win", "won"), ("p_win", "lhagyal"), ("p_lose", "akha")],
    "steward": [("fine", "fine"), ("quiet", "hands_down")],
    "starter": [("ready", "ready"), ("three", "three"), ("two", "two"), ("one", "one"), ("go", "go")],
    "pola": [("greet", "tashi")],
    "mola": [("greet", "tashi")],
}

# ---------------------------------------------------------------- the old rider's sayings
# Spoken and shown between races. These are the storyteller's own, invented for the game: he's a boaster, not a source.
# The one exception is the yeti and the marmots, a real Tibetan proverb (see Pema Tsewang, "Like a Yeti Catching Marmots").
SAYINGS = [
    "A fast horse is a fine thing. A horse that knows the way home is better.",
    "Never overtake a man who owes you money.",
    "Butter tea first. Then the fight.",
    "The road is long, the whip is short, and your aunt keeps a ledger.",
    "You can borrow a horse. You cannot borrow its opinion of you.",
    "Uphill, the horse carries you. Downhill, you carry your pride.",
    "Never shout at a yak. It has already decided.",
    "Do not count your silver while your hat is in the air.",
    "He who laughs on the start line walks home.",
    "Mud is only a road that has changed its mind.",
    "When the crowd shouts your name, look who is behind you.",
    "If you must fall off, fall forward. It is closer to the finish.",
    "Trust your horse, your aunt and nobody else. In that order. No, the other way round.",
    "Every rider's horse is the fastest, until the first bend.",
    "Like a yeti catching marmots: you grab the next one, and the one you were sitting on runs away.",
    "A rider with no scars has been riding very slowly.",
    "Do not argue with a mule. It is only waiting for you to finish.",
    "The man who sells you the horse is never the man who rides it home.",
]

# Crowd cheers: phrase keys layered into group shouts by make_voices.py.
CHEERS = {
    "cheer_kiki": "kiki",
    "cheer_lha": "lhagyal",
    "cheer_shuk": "shuk",
    "cheer_ala": "ala",
}

# How English says the Tibetan names. {O} is the "oh" sound, written differently for American and British spelling rules.
PRONOUNCE = {
    "srang": "sˈɑŋ",
    "Tsampa": "ʦˈɑmpə",
    "Wangyal": "wˈɑŋjɑl",
    "Dorje": "dˈɔɹʤə",
    "Pon": "p{O}n",
    "Joru": "ʤˈ{O}ɹu",
    "Yangkyi": "jˈɑŋki",
    "Pola": "pˈ{O}lɑ",
    "Mola": "mˈ{O}lɑ",
    "Ama": "ˈɑmɑ",
    "Choekyi": "ʧˈ{O}ki",
    "Kalimpong": "kˌælɪmpˈɔŋ",
    "Kham": "kˈɑm",
    "Lhasa": "lˈɑsə",
    "Karma": "kˈɑɹmə",
    "Tobgye": "tˈɑpɡjɛ",
    "Lithang": "lˈiθɑŋ",
    "Samdup": "sˈɑmdʌp",
    "Serkhar": "sˈɛɹkɑɹ",
    "Tashi": "tˈɑʃi",
    "Gyaltsen": "ɡjˈɑlʦɛn",
    "chang": "ʧˈɑŋ",
    "Calcutta": "kælkˈʌtə",
}
