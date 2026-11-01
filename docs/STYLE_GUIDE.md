# Style guide: "Woodblock Arcade"

**One line:** a mid-1990s arcade 3D game printed from woodblocks. Chunky low-poly shapes, flat mineral
pigment colours, stepped light, black ink line, and pixel-painted detail. Warm and nostalgic, always
readable at a gallop.

## The five rules

1. **One atlas.** Every model samples `assets/atlas/atlas.png`. Colours come from named palette cells.
2. **One material.** Everything uses the shaders in `shaders/`: `toon` for models, `ground` for terrain,
   `road` for the course.
3. **Three steps of light, no gradients on objects.** Shadow, mid, light.
4. **Ink is drawn by the screen, not the model.** `ink.gdshader` draws all lines.
5. **Foreground saturated, background quiet.** Anything that can hit you is bold. Anything that can't fades
   toward the sky.

## Palette

Defined in `art/tools/atlas_palette.py`. Use names, never new hex values. Approximations of thangka
pigments and architectural colours.

| Group | Names | Use |
|---|---|---|
| Inks | ink, soot, charcoal, slate, ash | Lines, hooves, hair |
| Lights | bone, chalk, conch | Whitewash, cloth, highlights |
| Pigments | vermilion, cinnabar, madder, pema, orpiment, gold, amber, ochre | Robes, trim, gold, friezes |
| Stone colours | malachite, turquoise, lapis, azure, indigo, saffron, plum, rose | Accents, sky, robes, flags |
| Earths | umber, sienna, tan, sand, khaki, rock_* | Ground, road, rock |
| Plants | grass_*, pine, juniper, barley | Vegetation |
| Skin | skin_light, skin, skin_deep, blush | Faces and hands, with variety across the cast |
| Materials | wood_*, iron, steel, silver, brass, coral, amber_bead, leather, sheepskin, fox_fur, yak_* | Gear |

**Team slots** (row 0 of the atlas) are grey cells multiplied by per-instance colours. A = robe, B = trim
and rug, C = horse coat, D = mane, tail and accent. Each rival has a unique main colour so they can be told
apart from behind.

## Readability, in order of priority

1. **The player's rider** in the centre, with a dark ink silhouette against a light road.
2. **Rivals:** saturated robe colour plus a distinct head shape. Never put two similar silhouettes in a race.
3. **Hazards:** dark or strongly coloured, on a lighter road. Yaks are near-black. Walls have strong outlines.
4. **The road:** always the lightest large shape on screen, with clear dark verges.
5. **Scenery:** mid values, reduced contrast with distance, and no ink beyond 260 m.
6. **The sky:** clean gradient, simple clouds, never busy.

Value test: convert a screenshot to greyscale. The rider must still read instantly.

## Light and shade

- Sun is a single directional light, with one colour per course. Sharp shadows.
- Ambient is cool lavender, from high-altitude sky. Shadow band is about 60% of albedo, tinted cool.
- Mid band about 90%, lit band about 105%. Never blown out.
- A soft rim on riders only.
- Faces are flat-shaded per triangle (derivatives in the shader).

## Ink

Full-screen line pass based on depth, normals and material class. Class is stored in ROUGHNESS: riders 0.2,
props 0.5, terrain 0.85. Godot 4.7 hands the shader those values so that they decode differently (see the comment in `ink.gdshader`).

- Width about 1.25 px at 1080p, scales with resolution.
- Interior lines on riders and horses only, plus real cliffs and steps on terrain near the camera.
- Fades out from 70 m to 260 m, and terrain from 24 m to 90 m, so far ground never picks up stray streaks.

## Shape language

- **Chunky and tapered.** Wide at the base, narrow at the top, echoing battered Tibetan walls.
- **Exaggerate what identifies a thing:** big hats, big hooves, big tassels, thick sword hilts.
- **Riders:** head about 1/5 of height. Big hands and boots. Weapons about 15% thicker than real.
- **Horses:** stocky highland ponies with thick necks, short cannons, big manes and tails. Never sleek.
- **Polygon budgets:** horse 1800, rider body 900 + head pieces 200, weapon 60-200, small prop 40-300, house
  300-800, monument 1500-4000.

## Patterns and motifs

Pixel-painted tiles in the atlas, low resolution and nearest-filtered on purpose.

**Safe for decoration:** stair-step and T-key borders, brocade strips, cloud bands, chuba trim, carpet
medallions, wave pattern, dotted borders, flower and lotus-scroll borders on cloth.

**Reserved, used only in the right place and never on anything struck or stepped on:** eight auspicious
symbols, the endless knot (on banners and walls only, high up), wind-horse flags (on flags only).

**Banned from models and UI:** Buddha images, deities, mantras, invented "script", the snow lion flag,
tiger rugs (tiger motifs are tied to monastic seats), and the swastika form. If the game shows Tibetan text
it must be real, correct, and reviewed.

**Prayer flags** are always in order blue, white, red, green, yellow, with an abstract horse block print
and no text. Mani stones show abstract carved marks only, as we can't check real inscriptions.

## Architecture colours

- Whitewashed battered walls (chalk), black window frames with a wider sill (ink), a dark red **pema**
  frieze below the roofline.
- Kham: red-ochre log upper floors over stone.
- Tsang and Gyantse: grey stone with white and red vertical stripes.
- Potala: white palace, deep red palace at the centre, gold canopies.
- Kumbum: stepped white tiers, gold top.

## UI: the thangka frame

- **Font:** `assets/fonts/headline.fnt`, an original pixel Latin face. Every capital hangs from a heavy
  top bar, as a tribute to the head line of uchen script. It's not fake Tibetan, and it's used only for Latin
  text. All capitals. Sizes are integer multiples only.
- **Frames:** a dark ink panel with a two-pixel gold line and a brocade strip top and bottom, like a
  thangka's silk mount.
- **Colours:** ink background, conch text, orpiment highlights, vermilion danger.
- **HUD is sparse:** player meters top left, rival plate top right only when one is close, position at
  top centre, progress thread beneath it, equipment bottom centre, nothing else.
- **Comic hit words** are large, tilted, and last under 0.6 seconds, no more than 2 on screen.
- **Motion:** menus snap and bounce, like a 16-bit arcade cabinet.

## Sound direction

Sound effects and music are original and synthesised. Hooves and wind carry the race. Hits are short and dry. Festival brass
and drums (dungchen-like low horns, cymbals, frame drum), and plucked pentatonic lute for music. No
chanting and no sacred music.

Voices are generated by speech models and stay natural: no comedy accents, and nobody's speech is made fun of. Riders shout in races, the
narrator speaks close and warm. Voices sit 3 to 4 dB above a race mix of about -20 LUFS. Menus sit about -24 LUFS. Keep it comfortable:
a player once muted this game because it was too loud.

## Consistency checklist for any new asset

- [ ] Uses atlas cells and tiles only
- [ ] Within the polygon budget
- [ ] Faces +Y, metres, Z up, origin on the ground
- [ ] Passes the greyscale test beside the lineup scene
- [ ] Breaks none of the cultural rules in `GAME_DESIGN.md`
