# Handoff

Where the project stands, for whichever session continues it. First written on 2026-10-31 on the original Mac mini, then updated the same
day on the Windows PC that replaced it, after a round of polish, voices and new features.

## How the user works

- Claude does all the work and is the only interface. The user doesn't plan to open Blender or Godot themselves. They give
  direction and playtest feedback in chat.
- **Godot must never interrupt them.** Test windows kept pulling focus from their other work. Use `tools/run_hidden.ps1` for anything
  that needs pixels and `--headless` for the rest. Tell every agent the same.
- **When you ask them to play, give them the command to start it**, in its own shell block so the app shows a Run button: `explorer.exe` with the full path to `Play.bat`. Don't start it for them.
- **They muted the game on their PC** because it was too loud, in their own `settings.cfg`. After the loudness fix they chose to keep it muted, so leave that file alone unless they ask.
- They asked for parallel agents and tight deadlines. Four Sonnet agents with strict file ownership (`docs/INTERFACES.md`) built the game
  in about 75 minutes, and four did this polish round in about 90. Seven Opus research agents, by contrast, ran through the session
  and weekly usage limits. Only spawn agents when asked. Give each one everything it needs in the brief, and say exactly what's off limits:
  a loose "no new downloads" cost one round of English voices.
- They care about a consistent style and about the game being fun, and they value plain answers to direct questions.

## State of the game

Playable from start to end: 5 courses, 3 seasons, 18 riders, all weapons, HUD, menus, stable shop, saved progress, story, music and sound,
plus everything added in round 2:

- **Voices:** every rider talks in races in Tibetan and English with subtitles, the old rider tells the story aloud, and sayings between
  races. Options has voice volume and language. A phrasebook lets you hear each Tibetan phrase. See `docs/VOICE_SCRIPT.md`.
- **Mix:** a race now measures about -19 to -20 LUFS with peaks at -2 dBFS. It was -8.6 LUFS, because the old limiter added 5 dB of make-up gain.
- **Fun:** hats that fly off, near misses, overtakes called by name, knockdown streaks, slipstream cues, side bets with rivals, a finish camera.
- **Life:** mastiffs chasing along the verge, kiang on the Grass Sea, cranes taking off, marmots, a crowd that bobs and cheers.
- **Art:** real mud (it was a flat dark rectangle), ramp, log, scarf, mules, walking animals, stewards on foot, finer road, seasons with their own
  light and colour, fewer stray ink lines on terrain, interior ink lines on riders and horses (they never drew before).

Then the user's first real playtest, on 2026-10-31, asked for four things, all in now:

- **Wind trail as the catch-up:** reach 14 m to 55 m, top speed +6% to +12%, acceleration +30% to +80%, the whip costs less in it. Visible streaks behind every rival, a meter on the HUD, and rivals seek trails out.
- **More turning:** half widths from 9-14 m to 5.5-7.5 m (4.5 at the narrows), tightest bends from 85-570 m radius to 41-75 m, and bends no longer get gentler in later Seasons. With no steering a horse used to run 630-1,675 m before leaving the road, and now 67-242 m. Curve push is up 40%. Boulder counts were halved to suit the narrower road, and chortens and mani walls now stand at the road's edge: placed as before they nearly closed it.
- **Mouse aiming with real physics:** see Aiming in `docs/GAME_DESIGN.md`. The old auto-lock and its ring are gone for the player.
- **Speed readout:** km/h, gait and the wind trail meter, bottom right of the HUD.

The second round of notes, the same night, because ranged weapons still felt pointless, also all in:

- **Ranged:** three times the shots for the player (36 arrows, 297 stones; rivals keep the old counts, because with the new ones they landed twice as many arrows) and a little more damage for everyone (sling 4, bow 8.5, roped spear 10.5). A shot now flies exactly along the sight line. It used to converge on whatever was near that line, which threw shots off.
- **Beside the road (`scripts/race/roadside.gd`):** bullseyes that pay by the ring, and flocks with wolves. A wolf pays, a sheep costs a fine, and nothing dies. That last part was my call for the setting: the request was hit points and a penalty, not killing.
- **Fists and kicks:** fists 6 damage, no shove and no penalty. A kick does 3, lands after 0.3 s, slows the kicker and shoves the target about 2 m.
- **Slams:** `Rider.slide` is sideways momentum that the reins fight but can't cancel. A slam shares it between the two horses by bulk. A strike with 4.5 m/s of sideways speed toward the target, or within 1.5 s of slamming them, does 1.5x damage.

And a third round after that:

- **All damage up 40%**, every weapon, fists, kicks, barges and shots, including the numbers just above. Impact (shake) is unchanged, so riders go down more on health than before.
- **Kick:** costs 10% of the kicker's top speed instead of 20%, and pushes the target over 6 m instead of about 2. **Aiming** costs 7% of top speed.
- **Slams:** now need an edge of 3 units of sideways momentum (speed times bulk) over the other rider, as well as the 4.5 m/s. See `Race._has_edge`. **The 1.5x strike** has much higher thresholds of its own, 6.5 m/s and an edge of 5.5, and lands on about 2% of hits.
- **Spear:** does a third of its damage inside 2 m.
- **Shots leave from the weapon itself** (`RiderVisual.shot_point`, the bow in the left hand) and aim to cross the sight line where they'll come down, allowing for the horse's speed. See `Race.update_sight`.
- **Roped spear:** 27 m reach, up from 18.
- **Text:** comic readouts and in-world words are about half the size and sit up in the sky, not over the road. The place counter is smaller too.
- **Floating rocks:** `L.blob`'s `cut` flattens a rock's bottom but leaves it above the origin, so every rock and boulder hovered, the boulder by 0.56 m and more at bigger scales. `L.settle` sets them down. Scenery could also land on the road across the inside of a tight bend, since the old guard skipped anything within 7 m of the road: `TrackBuilder.road_gap` measures it properly. `tests/dressing_check` covers both.
- **Pola and Mola** go through `make_voices.age_voice`: slower, with a narrower tune, a shake in the pitch, more breath and less of the top of the voice. Nobody here can hear whether that worked. The settings are in `voice_script.SPEAKERS`, so if they're wrong, that's the place to turn them.

The user's core rules, all implemented and checked by `tests/sim_balance`:
- Ranged weapons do less damage and impact, and can never unseat a rider on impact alone.
- Too much impact can crash a rider even with health left.
- Zero health crashes the rider and forces a rest.

**Tested only by bots, scripts and screenshots:**
- Full AI races on every course in every season, at about 59 fps on an RX 7600.
- A menu walkthrough with screenshots of every screen.
- Voices appear in recordings at the right moment, and are measured for level, pitch and length. See the limits below.

**Never checked by a person, and the most likely source of changes:**
- **What any of the audio sounds like.** Claude can't hear. Spectrograms and loudness numbers are all anyone has looked at.
- **Whether the Tibetan is right.** No Tibetan speaker has read or heard it. `docs/VOICE_SCRIPT.md` is laid out for that review and marks the
  phrases Claude trusts least. Women's Tibetan voices are the same male readers shifted by a vocoder, the likeliest to sound artificial.
  `tools/make_voice_review.py` builds a listening page with flags and notes, published privately for the user. Rebuild and republish it after regenerating voices.
- How the controls feel and whether the difficulty is right. Top 3 is needed on all 5 courses, and a bot with starting gear averages about 4.8th in Season 1 (8 races a course; 5.0 on the old roads). Rivals were slowed by 1% in Season 1 and 0.5% in Season 2 to allow for a person learning the bends.
- Whether the new bends, the wind trail and the sight feel good. Bots show that a keyboard can hold the road, that shots follow the physics and that the sight works through the camera, but no hand has held the mouse yet. A real pointer has never moved the sight, because tests must not touch it: the mouse-reading lines in `PlayerControl.move_sight` are the one part of the aiming path that has not run.
- Gamepad input, including right-stick aiming.

## Licence catch

The Tibetan lines come from Meta's MMS models, CC BY-NC 4.0: free game only. **They must be replaced before any paid release.** The user accepted
this. They're the only non-original assets in the game, credited on the credits screen. English is Kokoro-82M, Apache 2.0. Models, their
cache and the Python environment live outside the repo, in `GameDev\voice` in the home folder on this PC. Only the generated audio is in the repo.

## Next work, in the user's likely order

1. Their playtest feedback, now including how the voices sound.
2. Tibetan review of phrases, names, dress, story and the dob-dob rival. No Tibetan reader has seen any of this.
3. The Visitors: Mongol riders, cowboys, British and a fantasy horse lord people, designed in `docs/GAME_DESIGN.md`.
   The user asked for the Rohirrim. Tolkien's names and the film designs are actively licensed, so plan an original people with their own name (general guidance, not legal advice).
4. A standalone app. Godot's export templates are installed on this PC, but there's no export preset yet.

**About `tests/sim_balance`:** run enough races. Its per-hit and knockdown averages can fail on small samples, so a failure at 2 races means little until 10 agree. A knockdown count far above the others does mean something: the check that says "knockdowns per race should be sane" is how the chortens closing the road at Lhasa were caught, at 43 a race.

**Known small flaws:** far mud is a thin stripe at grazing angles. Crane, wool bale and kiang legs are weak up close, yak legs hide under their
hair, and the steward's hat reads as a yellow ball from behind. Hoof grip is better, but the horse animations stride only a third of what the
ground speed asks for: a fuller fix means re-animating them.

## Decisions worth keeping

- The game is framed as an old rider's tall tale, because no source describes racers fighting on horseback. The frame also licenses the Visitors.
- The cultural rules in `docs/GAME_DESIGN.md` are binding: no sacred objects as weapons or power-ups, no ordained monks as combatants, no real people, the PLA and 1959 stay offstage. Survey stakes and one parked truck appear with no comment.
- Sacred sites earn no near-miss bonus: skimming a mani wall isn't a stunt.
- All models and pictures are original and generated by scripts, and so are the sound effects and music. Voices are generated by third-party models, as above.
- The sayings are the storyteller's own, invented for the game. Only "like a yeti catching marmots" is a real Tibetan proverb. Don't present anything else as one without a source.
- Muted players still get subtitles, and a settings file with no voice key inherits the mute.
- Test runs use scratch save and settings files. Godot started from a session writes to the real user data folder. Before that guard, a bot race overwrote the user's `save.cfg` on 2026-10-31, with no older copy to restore.
- Git LFS holds models, textures and audio.

## What isn't in this repo

The repo is public, so these stay elsewhere:
- `research_notes/` holds about 280 KB of long-form notes with citations on arms, dress and names, and history, on the Mac mini. `docs/RESEARCH.md` is the summary.
- `demo/windhorse_rumble_demo.mp4` is 120 MB, over GitHub's file limit. `tools/record_demo.sh` can record a new one, though on Windows it needs a replacement for its two Swift video tools.
- `.mcp.json` has local paths. See `.mcp.example.json`.
- The speech models and voice cache, as above.
- The original conversation and Claude's local memory notes, whose useful content is in this file.

## Limits of the research

Usage limits stopped four of the seven research passes before they wrote notes (festivals, regions, Road Rash, art). Findings for those came
from recovered web results, mostly excerpts and summaries. See `docs/RESEARCH.md`. For Tibetan phrases, online dictionaries were partly blocked, so
spellings were checked only against public phrasebooks and word lists.
