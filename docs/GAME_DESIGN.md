# WINDHORSE RUMBLE: game design

A horse racing brawler. Speed wins races, and knocking rivals off their horses is just as good a way
to win. Tibet, the Wood Horse Year (1954), as remembered by an old rider who may be exaggerating.

## Pillars

1. **Speed and violence are equal paths.** A slow bruiser and a clean sprinter can both finish first.
2. **Close is king.** Melee hits hard. Ranged only harasses.
3. **Readable at a gallop.** Every hit, threat and meter is understood in under a second.
4. **The horse is never the victim.** Riders fall. Horses are never hurt, they trot on and wait.
5. **Rivals are people.** They talk, hold grudges, and ride the way they talk.
6. **Respect is a rule, not a garnish.** See "Cultural rules" below.

## Core loop

Pick a course → read a rival's taunt → race 8 riders over 2-3 km (about 2-3 minutes) → finish top 3 to
qualify → earn silver and bounties → buy horses, weapons and tack at the Stable → repeat.
Qualify on all five courses to raise the Season.

Three Seasons: **Spring Meets, Summer Festival, Harvest Final**. Each brings longer courses, faster
rivals, more hazards, higher prizes and stiffer fines.

## Riding

Riders live in track space: `s` metres along the course, `d` metres right of centre.

- **Urge / Rein in:** hold to speed up or slow down. Gait shows speed: walk, trot, canter, gallop.
- **Whip (sprint):** burns stamina for extra top speed. Empty stamina means a lower top speed until it
  recovers.
- **Steer:** lateral speed scales with current speed, as in Road Rash. Curves push you outward in
  proportion to speed squared, so you lean into bends. Roads are narrow (11 to 15 m, down to 9 at bridges and through
  villages) and bend every few seconds, radius 40 to 75 m at the tightest. Nobody can just hold the throttle down, and a
  fast horse has to ease off for the sharpest ones. A bend keeps its radius in every Season: longer courses turn further.
- **Off-road:** verge and scrub slow you. Rocks, walls and trees throw you.
- **Wind trail (the catch-up):** a galloping horse leaves stiller air behind it, shown as a line of turquoise streaks.
  Riding in it, a horse has less to push through: up to +12% top speed and +80% acceleration, and the whip costs 35% less
  stamina. It reaches 55 m back, strongest close up and spreading as it fades, so anyone who has fallen behind has a way
  back in touch and the leader never has one. Rivals seek it out too. The HUD shows how far in you are.
- **Leap:** clears ramps, streams and logs. A boulder can't be leapt.
- **Second Wind:** spends a full Lungta meter on 4 seconds of extra speed with shake immunity.

## Combat

Attack left or right. The weapon decides reach, speed, damage and impact.

### Two meters on every rider

- **Health** (0-100): how much you can take. **At 0 you crash and must rest** for 7 seconds (mashing can
  shorten it by up to 2.5 seconds), then remount at 55 health.
- **Shake** (0-100): how rattled you are. Each hit adds its **impact**, and shake drains over time.
  - **45+** the rider visibly wobbles and steering drifts.
  - **70+ "Teetering":** each further hit has a chance to unseat, rising from 0% at 70 to 50% near 100.
  - **100:** always crash, even at full health.
  - Steering against the wobble drains shake twice as fast.
  - An impact crash means a shorter rest: tumble, get up, run to the horse, about 3.5 seconds.

### Weapons

Ranged weapons do far less damage and impact than melee. **Ranged impact is capped: it can't take a rider
above 85 shake, so a ranged hit never unseats anyone on impact alone.** Ranged can only finish a rider
whose health is already gone.

| Weapon | Tibetan | Class | Damage | Impact | Reach m | Swing s | Notes |
|---|---|---|---|---|---|---|---|
| Fists | | body | 8.4 | 10 | 1.9 | 0.33 | Always available, no shove, no penalty |
| Kick | | body | 4.2 | 20 | 2.1 | 0.62 | Lands after 0.3 s and costs 10% of your speed while it lasts, but shoves the target more than 6 m away |
| Barge | | body | 5.6 | 18 | contact | n/a | Scales with sideways speed and horse bulk |
| Knife | gri | melee | 14 | 8 | 2.0 | 0.3 | Fastest blade |
| Pen case | | melee | 9.8 | 20 | 2.1 | 0.42 | Gravel-filled, cheap and comic |
| Whip | | melee | 8.4 | 15 | 3.0 | 0.34 | Long and quick |
| Sword | ral gri | melee | 25.2 | 24 | 2.6 | 0.55 | Best all-round |
| Iron key | lde brdzus | melee | 21 | 38 | 3.5 | 0.7 | On a thong, outreaches swords, weak up close |
| Spear | mdung | melee | 22.4 | 34 | 4.0 | 0.75 | At a full gallop, +25% impact |
| Sling | 'ur rdo | ranged | 5.6 | 6 | 28 | 0.8 | Side-swung, 297 stones (rivals carry a third of any ammo) |
| Bow | gzhu | ranged | 11.9 | 8 | 45 | hold | Draw to aim, +30% at full draw, 36 arrows |
| Roped spear | thag mdung | ranged | 14.7 | 12 | 27 | 1.1 | Thrown then hauled back, no ammo |

**Aiming:** the mouse moves a sight, and nothing aims for you. Hold the right button to draw and let go to loose. A shot
flies through the world with real physics: it leaves the hand with the horse's own velocity added, gravity pulls it down at
9.8 m/s² and the air slows it. So you aim above a far target and ahead of one moving differently from you, and a shot at
a roadside pole drifts forward with your own speed. A weak draw throws slower (55% of full speed at the least) and drops
sooner. At full draw, a level bow shot drops 0.2 m at 15 m and 2 m at 45 m. A sling stone drops 1.9 m at 26 m. Marks under
the sight show the drop at 15, 30 and 45 m, the view tightens as you draw, and a line follows your own shots so you can
learn the arc. A shot only counts on the rider: below the saddle it would strike the horse, and horses are never hurt, so
it flies on. A shot to the head can take a hat off. Arrows that miss stay stuck in the ground for a while. Rivals work out
the same physics, then miss by however much their skill allows. Drawing a shot costs 7% of the horse's top speed.

**Slams and momentum:** steer hard into a rider from the side with a real edge on them and you slam them: a barge, and both of you carry on sideways.
An edge means at least 4.5 m/s of sideways speed toward them, and 3 more units of sideways momentum (speed times the horse's bulk) than they have, whichever
way they're going. Meeting a rider coming just as hard, or catching one going nearly as fast, is no slam: the horses just lean on each other. The heavier horse
loses less of its speed, and the rider who slammed keeps going even with the reins let go, for about a second as the momentum fades. Shoving someone off the road
is fair: past the scrub they're thrown.

**The 1.5x strike** is rare and has to be earned: 6.5 m/s of sideways speed toward the target, nearly all a horse has at a full gallop, and 5.5 more units of sideways
momentum than they have, so they must be holding their line. A slam that hard also sets it up for 0.8 seconds after, and the HUD says when. Ranged hits never get it. In
simulated races about 2% of hits land this way.

**Shield (phub):** hold to raise. Cuts damage by 75% and impact by 65% from the side it faces, but slows
you and you can't strike. A hit in the first 0.2 seconds of raising is a **parry**: the attacker gets +25
shake and you gain Lungta. A shield blocks arrows from any side.

**Reach rules from history:** inside 2 m a spear has no room to work and does a third of its damage. At under 1.5 m a key does half. Swords
and knives don't suffer. So fighters want the range that suits them.

**Taking weapons:** hitting a rider out of the saddle or as they swing lets you snatch their melee
weapon for the rest of the race, if it's better than yours. Otherwise it drops on the course to pick up.

## Lungta (fortune)

Five flags in the HUD, filling in blue, white, red, green, yellow. Not magic: it's fortune, which rises
and falls with how you ride.

- **Gain:** passing a mani wall or chorten with it on your right (Bon rivals pass the other way, and
  that counts for them), crossing a high pass, parries, stunts, knocking down rivals.
- **Lose:** passing a sacred site on the wrong side, a crash (half), striking on Quiet Ground.
- **Quiet Ground:** short stretches near monasteries and the Western Gate. Striking there costs Lungta and
  a fine. Rivals keep their hands down too.

## Stunts and bonuses (real festival events)

- **Scarf scoop:** ride over a coloured silk scarf to lean down and scoop it at speed. Pays silver and
  a little Lungta. These are festival prizes, not white khata, which never go on the ground in-game.
- **Target poles:** hit a red-cloth pole with a ranged shot as you pass for a silver bonus, after the
  Gallop Behind the Fort.
- **Bullseyes:** festival archery targets stand off the road on every course and face the riders coming. Each pays once, by the ring: 5, 10,
  or 20 for the middle.
- **Wolves at the sheep:** flocks graze off the road with a wolf or two circling and running at them. Driving off a wolf pays 12. Hitting a sheep costs a
  fine of 8, on the road as well. Nothing dies: a wolf that's hit yelps and runs for the hills, and a sheep bolts and comes back.
- All of these pay half as much again in Season 2 and double in Season 3. A blow from the saddle counts too (a struck bullseye pays 10), but it means riding
  the rough to get in reach, and the rough costs about 40% of your speed. Rivals ride past them, and their stray shots cost and earn nothing.
- **Mud-and-rock ramps:** leap for shortcuts and a small bonus.
- **High pass:** crossing the cairn gives the cry "KI KI SO SO!" and a burst of Lungta with coloured paper
  squares in the air.

### Showing off (player only, silver and shouting, no effect on anyone's riding)

- **Near miss:** passing a boulder, yak or mule within about a metre at speed: CLOSE! +2 silver and a sliver of Lungta. Sacred sites
  never count: skimming a mani wall or chorten earns nothing.
- **Hats:** a hard hit or a fall can knock a rider's hat off. It spins away and stays on the road, and the rider complains. Knocking one off
  yourself earns a little silver. Hatless riders stay hatless until the next race.
- **Knockdown streak:** another knockdown within 25 seconds calls DOUBLE!, TRIPLE! or RAMPAGE! and pays part of a bounty again.
- **Overtakes** are called out by name. The results screen counts hats, near misses, overtakes and your best streak.

## Side bets

The pre-race card can include an offer from the featured rival: finish ahead of them and win the stake, finish behind and lose it.
The stake is 15% of your silver in steps of 5, from 20 to 200, and it can never leave you under 20. So there's no offer under 40 silver,
and a lost bet can't trigger your aunt's loan. A bet lasts one race and isn't saved. It's the story's great wager at the scale of one rider.

## Voices

Rivals talk during races (`scripts/race/chatter.gd`): when they pass you, when you pass them, when they hit or are hit, when anyone falls,
when they ride alongside. One voice at a time, a few seconds apart, and rivals with a grudge talk more. Quiet Ground stays quiet, apart from
the steward telling everyone to put their hands down. Options sets the language: both, Tibetan or English. Muted players still get subtitles.

## Hazards

Yak herds crossing, mule caravans plodding along, sheep, mud fords (slow), boulders, ruts, walls, narrow
bridges. Riders fall on impact. Mani walls and chortens are never damaged in any way.

**Race stewards** are the police. Fussy officials in indigo and yellow hats patrol from Season 2 and
fine you if they reach you while you're down. Fine rises by Season. You can hit stewards, but it doubles
the fine if you're caught later. **The PLA and any real authority stay offstage.**

## Rival AI

Each rival has data for skill, aggression, weapon, horse, lane habit and a personality trait. Behaviours:
line choice with hazard avoidance; tucks into wind trails, then pulls out to pass; matches speed to fight; backs off
below 30 health and returns after recovering; uses the shield when threatened; ranged riders hang back and harass; mild
catch-up only, so that a leader can still be caught but no one teleports.

**Grudges:** rivals remember. Knock one down and that rival targets you first next race and says so in
pre-race talk. Finish behind someone repeatedly and they get cocky. Stored in the save.

## Economy

Currency is the **srang** (silver). Start with 150.

| | Season 1 | Season 2 | Season 3 |
|---|---|---|---|
| Prize 1st / 2nd / 3rd | 200 / 120 / 70 | 420 / 260 / 150 | 800 / 500 / 300 |
| Knockdown bounty | 15 | 30 | 60 |
| Steward fine | 40 | 90 | 180 |

Finishing 4th or lower earns no prize and doesn't qualify, but you keep bounties and scoops.
**Going broke isn't game over:** at under 20 srang, your aunt lends you 60, and rivals mention it.

### Stable

| Horse | Cost | Speed | Accel | Handling | Stamina | Bulk | Notes |
|---|---|---|---|---|---|---|---|
| Old Tsampa (dun pony) | start | 20 | 6.5 | 3.0 | 80 | 1.0 | Honest and steady |
| Riwoche Dun | 320 | 22 | 7.5 | 3.4 | 90 | 0.9 | Light and quick, easy to shove |
| Nangchen Bay | 700 | 24 | 7.5 | 3.2 | 100 | 1.0 | Proper racehorse |
| Golok Black | 900 | 23 | 6.5 | 2.8 | 120 | 1.5 | Heavy, hard to knock over |
| Sertso Grey | 2000 | 27 | 8.5 | 3.4 | 120 | 1.1 | The horse people tell stories about |

Weapons cost 40-900. Tack upgrades: **Felt pad** (start) → **Derge saddle** 300 (-15% impact taken) →
**Gilt saddle** 900 (-30%). **Padded chuba** 200 (+15 max health) → **Mail shirt** 700 (+30).

Leopard, tiger and otter never appear as items or rewards.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Steer, urge, rein in | WASD or arrows | Left stick, RT urge, LT rein |
| Whip | Left Shift | RB |
| Leap | Space | A |
| Strike left / right | J / L, or Q / E. Left and right mouse if you carry no ranged weapon | X / B |
| Strike at the nearest rival | Left mouse, when you carry a ranged weapon | |
| Kick (auto side) | K or F | Y |
| Aim | Mouse | Right stick |
| Draw, then loose on release | Right mouse, or U or R | Right stick click or D-pad up |
| Shield (hold) | I or C | LB |
| Second Wind | Enter or Ctrl | D-pad down |
| Pause | Esc | Start |

## Cultural rules (binding)

- No Buddha images, deities or mantras on anything struck, trampled or worn on boots or saddles. Road and
  ground stay free of script and sacred symbols.
- Prayer wheels, rosaries, ritual daggers, thangkas and khata are never weapons, pickups or power-ups.
- Mani walls and chortens can't be damaged.
- Ordained monks and nuns are never combatants, targets or jokes. The one dob-dob rival is a hired escort
  in travelling clothes. Flag this for Tibetan review.
- No real people. No real noble houses. No real victims, no flood jokes, no PLA, no 1959, no famine.
- No "bandit" class or "savage" language. Every region gets several kinds of people, and Khampas aren't
  the only tough ones.
- No magic. No mystic Tibet. No outsider saves anyone.
- Women aren't prizes or ornaments.
- Horses are never hurt. Animals are never killed: wolves run off and sheep bolt.
- The game says plainly, on the title and credits, that horseback brawling is a tall tale and not history.
- Voices: no chanting, mantras or sacred recitation. "Ki ki so so lha gyalo" is the public shout at passes, and it stays. Tibetan speech
  must be real, and no line is called reviewed until a Tibetan speaker has checked it (`docs/VOICE_SCRIPT.md`).

## Later: the Visitors

Data-driven, added later with no engine change. All framed as the old rider's most outrageous stories.
Details are in `research_notes/.../history_1950s_visitors.md`.

- **Mongol pilgrim riders:** uurga pole that hooks hats and rivals, treat your course as a warm-up.
- **Cowboys:** rope against pole duels. A Kalimpong muleteer in a Stetson quoting Westerns he never
  understood. A yak-tail buyer for Santa beards. No guns.
- **British:** a sports day at altitude with rulebooks and protest committees; an officer who was never
  told, because the mail is late. Jokes never touch 1904.
- **Fantasy horse lords:** the request was for the Rohirrim. Tolkien's names and the film designs are
  actively licensed, so build an original people from public-domain roots (*Beowulf*, Anglo-Saxon mail,
  the Uffington horse) with their own name and emblem, such as the Hengestings. They treat a mule race
  as the last ride of their people. This is general guidance, not legal advice. If the game stays private
  this doesn't matter, but check before any release.

Rules: no visitor explains Tibet, rescues anyone or wins the final race.
