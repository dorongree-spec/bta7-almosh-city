# Run notes (PC side)

Machine: Windows 11, AMD Radeon RX 6750 XT, Vulkan 1.4, Godot 4.3-stable, Forward+, 1600x900.

## 2026-11-24 run

Tested at commit `9e28b98` (car damage, clouds, parked-car pool) plus the fixes listed below.

The log is clean: no errors or warnings on import, on the title screen, or
while playing (walking, stealing a car, driving into a wall).
FPS was a steady 60 (vsync) in every shot with SDFGI, SSIL, SSR and volumetric fog all on.

### Fixed here
- **Roofs and ground areas missing (culled)**: `Geometry2D.triangulate_polygon`
  keeps the OSM ring's winding, so about half of all roofs and land-use areas
  faced down. Added `CityBuilder._up_facing()` to orient every flat triangle up.
- **Pile of ~20 cars at the start point**: `Traffic._respawn` gave up after 40
  random tries (in a city about 7 km wide most tries land beyond SPAWN_MAX)
  and dropped the car to y = -100, below the WorldBoundary floor. Physics
  pushed every such car back up at the origin, which is the player spawn.
  It now falls back to a full scan of road points in range, keeps spawns
  10 m apart and at least 25 m from the player, and parks cars that still
  find no spot out of sight, retrying every 2 s.
- **NaN transforms after a parked car comes back**: in Godot 4.3, setting
  `freeze = false` on a `VehicleBody3D` turns its transform into NaN on the
  next physics step. This is reproducible every time. Use
  `process_mode = PROCESS_MODE_DISABLED` / `INHERIT` instead. **Do not use
  `freeze` on cars.**
- **Gang crews leaked at exit**: `Member.crew` and `Crew.members` formed a
  reference cycle. `Gangs._exit_tree()` now breaks it.
- **Parked cars** kept at least 8 m apart (several streets start at the same junction).
- **90 orphan Node3D leaked at exit**: `Humanoid._build()` returned before
  parenting `_body` whenever the rigged model is available. `_body` is now always parented.

### Tuned by eye
- **Flat ground clipped to white** in full sun. Two causes:
  - `vertex_color_is_srgb` was off on the roof and ground-area materials
    (`CityMaterials.roof()`, `vertex_colored()`). The sRGB colours were read
    as linear, so 0.58 showed like 0.79. Turned it on. `Facades.material()`
    uses vertex colours as a tint and looked right, so it was left as is.
  - Albedos lowered to the range of real materials: pavement 0.74 -> 0.55,
    sand ground 0.86 -> 0.74, AREA_COLORS sand/residential/commercial/industrial
    about 20% darker.
- Added `docs/.gdignore` so Godot does not import the screenshots as game assets.

### For the cloud side
- **People stand in a T-pose** (arms straight out) when the rigged body is
  used: the player, pedestrians and gang members in every shot. The walk or idle animation
  does not seem to play on `RiggedBody`. Not touched here.
- `night.png` is staged: the capture script lowers the main DirectionalLight and the ambient light.
  With the new sky and clouds it now reads as dusk rather than night.
  There is no day/night cycle yet, and the street lamps give no light (no
  OmniLight/SpotLight on them), so night is almost black. Cars' tail lights and
  the purple underglow do show.
- At street level the volumetric fog plus distance fog wash the far city into
  beige quite early (~300 m). It reads as a hot, dusty day, but if you want more
  visible skyline, lower `volumetric_fog_density` (0.004) first.
- Pavement and kerbs in the old city still read bright but are no longer clipped.

## 2026-11-24 evening run (PC side)

Tested at `896e482` plus the fixes below. The log is clean (no errors or warnings) across import,
title, the full `--tour` and a play-through. Tour FPS: 57-61 everywhere, 45 on the full map (M).

### Driving bench (car.gd, owned by the PC side this round)
A scripted bench (flat floor, fixed inputs, `--fixed-fps 120`, about 3 s per run) measured every car.

| | before | after |
|---|---|---|
| rollovers at full lock / handbrake turn | **every car except the truck, at 12-38 km/h** | none |
| 0-100 km/h | most cars never reached 100 | 3.2 s (Hondo) to 7.2 s (old Subaru) |
| top speed | 82-130 km/h | 112-118 old boxy cars, 131 family/taxi, 151 inspector, 173 Hondo, 97 truck |
| braking 100-0 | 12-27 m | 17-33 m |
| cornering | flipped instead | 1.1-1.6 g |

Changes: `GRIP_SCALE 0.55` (friction_slip 2.3-3.0 was above the ~2.2 g tip-over threshold for this
track width and centre of mass), centre of mass 0.35 -> 0.15, wheel roll influence 0.15 -> 0.08,
engine force `1 - r^4` instead of `1 - r` (pulls until near top speed).
Body roll is small (about 2 deg); visible lean would need softer suspension. Left as is.

### Fixed
- **Parked-car pile-up at the start (again)**: the new `Traffic._park()` had the old fallback (y = -100,
  under the floor, pops up at the origin). It now falls back to road segments in range, keeps cars 7 m apart,
  and hides cars with no kerb (process disabled, retried by `_recycle_parked`).
- Car rims: a mirror finish reflected the sky and read as white discs; now mid-grey and slightly rough.
- Committed the Godot `.import` files and the textures extracted from the CC0 models.

### Tuned by eye
- Ambient light now blends a warm sand colour (sky contribution 0.3) and SDFGI energy is 1.3,
  so shade is less blue and walls in shade keep some detail.

### Still open, for the cloud side
- **Asphalt in shade is still navy blue** even with 30% sky ambient. It looks like SDFGI lighting shade
  from the sky directly. Worth trying: `sdfgi_bounce_feedback`, a warmer `sky_horizon_color`, or a slightly
  warmer and lighter asphalt albedo. Needs a PC run to judge.
- The tour's `shikun` view now looks almost straight down at a pavement (a tree trunk in frame).
- Map view (M) runs at 45 fps.

### Windows export
`godot --headless --export-release "Windows Desktop" export/AlmoshCity.exe` works: it takes 3 s and makes a single
**87.7 MB** exe (not committed). The exe starts, renders on Vulkan Forward+ and exits cleanly (code 0).
Its log shows **249 harmless-looking errors at start-up** that the editor run does not show:
`Attempt to disconnect a nonexistent connection from 'Skeleton3D' ... Signal: 'skeleton_updated'`.
They are most likely the `BoneAttachment3D` holders from `RiggedBody._pin()` (one or more per person).
Worth checking whether items pinned to bones (sunglasses, chains, chairs) still follow the bones in the exe.

### Final tour (latest main, `86d67a4` + minibus)
The log is clean. FPS: 56-61 in every view, 58 on the map.

## 2026-11-24 night: two-hour push toward a GTA-like result (PC side)

Log is clean (import, title, `--tour`, the 3.5-minute scripted playtest). Tour 53-60 fps with vsync, 91-121 uncapped.

### Look
- **CC0 photo textures** (Poly Haven, 11 MB): roads, pavements, ground, roofs, and facade grain. See assets/CREDITS.md.
  Roads use a small shader that combines world-space asphalt with lane paint from the ribbon UVs.
- **SDFGI off**: it lit open shade straight from the blue sky (shaded asphalt measured RGB 13/31/60, vs 68/64/63
  without SDFGI). Warm ambient light plus SSIL now provide the shade.
- **Night**: 16 lamp lights (was 10) with a wider, gentler reach; stronger and longer headlights.

### Physics
- Softer suspension (springs 20/34, was 45/70): cars lean 3-4 deg in hard bends. The bench still shows no rollovers,
  and grip, braking and 0-100 are unchanged.

### HUD (big fix)
- **Everything anchored right or bottom was off-screen**: money, health and heat bars, clock, street, speed, minimap,
  subtitles and the E/Q prompt. Setting `position` on a just-anchored Control ignored the anchor (rects at x = -260).
  `Hud._place()` now writes the anchor offsets directly, under a full-screen root control. See the `encounter` shot.

### Encounters (78f9f01) - scripted playtest
- Visitors come at 21 s and 45 s, then about every 25 s. Each one calls out, walks up and asks. E and Q apply the
  outcome (money, health, heat, reply line). A "no" to the Ktarim chair offer turns them angry, and they hit.
- Haggling works, but the 3rd drop rounded back to 10 ("10" twice). Now each drop is at least 5 (20 -> 15 -> 10 -> 5).
- Punching a Meshuparot visitor calls 2 friends. **3 attackers took a standing player from 49 to -36 in 7 s.**
  Hits are now every 1.3-1.9 s (was 1.1) for 4 (Ktarim 6, was 5/7): about 14 s for three attackers, 25 s for one Ktarim.
  Galina turned up after the fight. Carjacking an AI car brought Dima ("you touched my spoiler") with take_car.
- `Sitting_Idle_Loop` resolves (the model has `Sitting_Idle`; RiggedBody strips `_Loop`).
- **Enter during loading** used to start the game before the player existed (null errors every frame). `_start()` is now guarded.
- Frequency feels right on foot. In a car only event triggers fire, which also feels right.
- Tour: new `encounter` view (the watermelon seller with the E/Q prompt on screen).

### 1ea6212 checks (scripted, `npc_test.gd` on the PC)
- **E next to a walker**: the walker is replaced by a visitor (an air-con technician, "local") who asks at once.
  The E that answered did **not** open a second conversation. Works.
- **Students away**: weekday 3 with the clock at 23:95, then midnight. The clock reads "יום חמישי 00:07" and `students_away = true`.
  No student crews were near the start to see them disappear.
- **Grudge**: at standing -3, 4 of 6 Meshuparot visitors arrived angry with a friend ("אתה חושב ששכחנו?").
  Each angry arrival resets standing to -1, as designed.
- Log clean.

### Also this round
- GTA-style colour grade (per-channel S-curve LUT: cool shadows, warm highlights; contrast 1.08, saturation 1.14).
- Glossy window glass: a roughness map from the painted facade (glass 0.08). Subtle in daylight with SSR.
- Tour: driving and handbrake now start in the right-hand lane of the nearest 90 m+ straight. They read 89 and 54 km/h
  (was 0, nose against a lamp post).

### 23d176b checks
- Conversation camera: the player and the speaker stand side by side (see `encounter.jpg`). TALK_CAM_ANGLE 0.55 and pitch
  -0.12 look right; no change. `_cam_idle` on foot is only read by the talk framing, so nothing else reacts to it.
  The tour no longer forces the yaw and waits 2.5 s for the camera to settle.
- **Night ground was bright orange**: my warm ambient colour (sky contribution 0.3) times the 4x night ambient lift
  lit the sand as if by day. `day_night` now blends the sky contribution from 0.3 (day) to 1.0 (night).
- Street-life density, measured but not committed (traffic.gd and pedestrians.gd are cloud files): 50 cars,
  30 parked and 60 people run at 71-87 fps uncapped (now 91-121). There is room for it if wanted.

### Windows exe (rebuilt at eaae601 + denser streets)
`export/AlmoshCity.exe` (now `export/BTA7AlmoshCity.exe`), **108.5 MB**, not committed. It runs and exits cleanly. Its log still has only the
harmless `Skeleton3D ... skeleton_updated` disconnect errors (328 at start-up, export-only; see above). No other errors.
Tour after the density change: 56-60 fps in every view with vsync.


## Night of 24-25 Nov 2026: toward a GTA 5 look (PC side)

Everything was checked on the RX 6750 XT at 1600x900. The tour runs at 55-60 fps with vsync in game views
(the map overlay at 44-59). Load to the title screen takes 4.8 s. The log is clean.

**Look**
- Trees: alpha leaf-cluster cards built from ambientCG LeafSet024 (tools/gen_foliage.gd), palm fronds, Bark007 trunks; fade at 500 m.
- Photo textures for roads (with patches, oil drips and kerb grime in the shader), pavements, ground (with macro patches), roofs and wall grain.
- Colour: the wall palette moved from six sand tones to white, grey, cream, pale-yellow and peach plaster plus concrete;
  wall grain at half strength.
- Light, following the published GTA V frame study (Courreges):
  - Hable filmic tone mapping and auto exposure (ISO 80-1200);
  - SDFGI off (it turned shade navy); warm ambient light plus SSIL;
  - TAA; street-level shadow cascades;
  - a colour-grade LUT, a vignette, lens aberration and barrel distortion, and a sprite sun flare;
  - golden-hour volumetric shafts.
- Night: warm lit windows, a sodium glow on the horizon, 16 street-lamp lights, longer headlights, and shop signs that glow like neon.
- Clouds fuller by day; richer dusk colours.
- Cars: dusty paint shader (dust thick on the sills, clearcoat elsewhere).
- People: denim and cotton weave, skin with subsurface scattering, leather shoes.

**Physics**
- Bench-tuned driving: no rollovers, real 0-100 times and top speeds, softer springs (3-4 deg lean).

**Key art**
- assets/art/keyart_01..06.jpg, rendered in-engine by tools/keyart.gd (4K, MSAA 8x, TAA, depth of field, downsampled to 2560x1440).

**Fixed along the way**
- HUD elements were off-screen (anchors).
- Encounter bank crashed on statement-only deals.
- The game could start before the city was built.
- Parked cars piled up at the start (again).
- Cars caught NaN after being frozen.
- The tour's car landed on traffic.
- Shop signs could face inwards.
- Desert lots and walls were too dark.

**Checked for the cloud side**
- Front end, opening shot, HUD rewrite, city dressing, far lights, walls facing out.

**Not done**
- Craft Anything is installed (v0.6.1, doctor healthy) but not connected: it needs an API key or a change to the Claude Code config.
  It is also aimed at software reverse engineering, so it was not used.
- No free realistic car or people models without an account were found; the existing ones got better materials instead.
- Kerbs with real height would need pavement collision.

## Night of 24-25 Nov (PC), second half

- Exe rebuilt 02:43 local from 4b3b95d (170 MB, export 3.4 s), with an empty
  `music` folder beside it for the "הדיסק של אבא" station.
- Tour: 50-61 fps at 1080p everywhere; Dalet street level 58-60 with the
  relief balconies, solar heater rows, railings and wires.
- Added tonight: zebra crossings (one per junction arm), red-white/blue-white
  kerbs, traffic that pulls out round blockers instead of gridlocking, a closer
  chase camera, benches that actually draw, 13-inch wheels on the old cars,
  crisp clothing edges, darker bark, grimier Dalet facades, green kerb
  railings on Avraham Avinu and Ringelblum, phone lines across Dalet side
  streets, and a "78 סיבובים" radio station with four public-domain 1914-1929
  shellac recordings.
- Known: the exported exe prints ~950 "disconnect a nonexistent connection
  ... skeleton_updated" errors once (same count at 200 and 1200 frames, so at
  load or exit, not per frame). The editor binary prints none. Harmless, but
  noisy in a console.

## Night of 24-25 Nov (PC), after Doron's "until 10:00" message

Exe rebuilt 03:48 local from a1433ab (180 MB, export 3.4 s, music folder
beside it), smoke test clean. Tour 48-61 fps.

- Town-wide: paler roofs, dry olive park lawns, ~15,900 static parked cars in
  rows on the yard_parking lots (scripts/parked_rows.gd), three painted variants
  of the housing block and two of the tower chosen by position, towers drawn as
  stone-clad flats, "office" and "mall" fronts (Negev Mall, courts, hospital,
  Gav-Yam), Ramot and Neve Ze'ev stone-clad, shop sign boards with lettering in
  three variants (lit at night), flowering bushes, blue street-name signs at
  junctions, low Negev hills on the horizon (scripts/horizon.gd).
- Old City: red-pink pavers on its own streets, green globe lamps, market
  stalls with blue tarps down the pedestrian streets (Kakal).
- People: Quaternius Universal Base Characters (CC0) bodies with faces, eyes,
  eyebrows and hair on the mannequin skeleton; women on the female body's own
  skeleton with the mannequin's AnimationPlayer moved across. Clothes are still
  the painted-on shader.
- Known: bodies are muscular ("superhero" base); clothes are skin-tight paint.

## Character work (PC, 25 Nov afternoon) - state for whoever continues

Bodies: Quaternius Universal Base Characters (CC0) bound to the UAL mannequin
skeleton (rigged_body.gd _swap_in_real_body); women use the female body's own
skeleton with the mannequin's AnimationPlayer moved across (_build).

- rigged_body.gd _build_shell(src, lift, robe, head): copies the body's clothed
  triangles (tag colours from _region: r shirt, g trousers, b skin; alpha 0.5
  head, 0.25 hands), welds UV seams, relaxes them (Laplacian, 18 rounds, 30 for
  robes), lifts along the normal (fitted 0.01 m, loose/tracksuit 0.034, robe
  0.04, robe with head cover 0.03), recomputes normals from the relaxed shape,
  keeps the bone weights. Cached per "sex|cut" in _shells. _add_garments adds
  the shell (own material copy, no shadow) and sets hide_clothes on the body
  material so the body discards clothed fragments. Robes add _add_skirt (flared
  tube pinned to pelvis; red bands on the Bedouin dress).
- Shader (SHADER_CODE): outfit uniform 0 everyday, 1 tracksuit (zip, hem), 2
  leopard suit, 3 leopard top, 4 robe; stripes (four bands on |normal.x|>0.8);
  cover_head; hem (shorts); use_body (skin from the body texture).
- body_shape.gd (SkeletonModifier3D, one per person): slim (0.65 men, 0.45
  women) thins upper arms, forearms, neck, chest; belly on spine_01 cancelled
  on spine_02; stoop 0.2 rad for grey hair; relaxed fingers; standing pose
  (legs to rest, pelvis to rest height with a small sway, upper arms hanging,
  computed once from the rest skeleton) whenever not walking or swinging.
- Idle_Loop is played as Idle_Talking_Loop at a random start point.
- Humanoid.set_far(far): pedestrians.gd calls it beyond 55 m for walking
  people; it pauses the AnimationPlayer, switches BodyShape off and hides the
  garment shell.
- humanoid.gd random_look: outfit mix, belly, old, hat (kippa/cap/bald),
  teenagers, no skin-like clothing colours.

FPS uncapped at the start: 48 -> 62 after set_far, 60.7 with BodyShape off
when far, 52.5 after hide_clothes/looser shells (814c48b).

Open list (in order): FPS back to 60 (per-person material copies, discard in
the depth prepass, shells hidden sooner); galabiya torso still shows pecs
(check the robe shell covers the male torso); real shoes as small meshes on
foot_l/foot_r; Bedouin woman's face (normal face, draped scarf); straight hems
and cuffs and the band where top meets trousers; standing pose variants
(pockets, arms crossed, hand on hip, phone).

- 25 Nov 14:1x: walkers 15-40 m advance their animation every third frame (RiggedBody.set_mid, AnimationMixer manual callback). Profiled 54.5-55.8 fps uncapped either way, so animation is not the main cost any more; next suspects: pedestrians' per-frame GDScript and the 60 skinned meshes plus shells (GPU skinning). Open list unchanged: galabiya pecs, shoe meshes, Bedouin face/scarf, hems and the waist band, pose variants.

## 25 Nov afternoon (PC): FPS, garment layers, shoes, poses

**FPS** (profiled with render-time and per-system toggles, RX 6750 XT, 1600x900, uncapped):
55 -> 82-85 fps at the start. The cost was not the people: 80 VehicleBody3Ds in the
physics engine took ~5 ms a frame, the walkers' per-frame script ~2.8 ms.
- traffic.gd: AI cars beyond 110 m leave physics (process_mode DISABLED, as for parked
  cars, never `freeze`) and slide along their lane by script; back into physics under
  95 m, already rolling. Fresh spawns get 1.5 s of real physics first. Settled parked
  cars beyond 60 m are out of physics too. Typically 37-39 of 50 cars are such "ghosts".
- pedestrians.gd: walkers beyond 40 m on a plain stroll are moved every third frame
  (with the saved-up time), and one transform write per move instead of two.
- The garment layer no longer hides when far: the body under it has no clothed
  triangles, so far walkers showed as floating heads, hands and feet.

**Garment layers** (rigged_body.gd `_layer` / `_build_layer`, cached in user://layers/*_v9.res):
- The lift is a membrane: smooth, push back out wherever it went under the lift, and
  at most 1.5 cm of sliding along the skin. Grooves (abs, pecs) are bridged instead of
  followed. Open edges are anchored at 6 mm and snapped to straight loops (neck curve,
  sleeve at |x| 0.5, wrist 0.68 on robes, ankle 0.14), so hems and cuffs are lines.
- CUSTOM0 carries the rest position; the shader splits top/trousers by the rest rule
  (straight waist line) and paints the body under a layer as skin only. The tracksuit
  hem darkening (the faint waist band) is gone.
- Crew neck: `_neckline(side)` (rounded, lowest at the front).
- Galabiya/thob: robe layer at 2.8 cm plus a skirt cone from under the chest (y 1.19)
  to the ankles, oval, pinned to the pelvis; the thob's cone has red cross-stitch panels
  and hem in its own shader; a small embroidered chest panel.
- Bedouin woman: the head is part of the layer except the face oval (`_face`), fuller
  over the crown and back, snug round the face. Normal face, hair, ears and neck covered.
- Sunglasses: two lenses and a bridge, at the right height (men stand on the
  mannequin frame, whose head is 3 cm lower than the body file's).

**Shoes**: a small rigid mesh per foot, pinned to foot_l / foot_r through the skin's
bind pose, lofted from that body's own foot (14 slices, rounded section, sole colour
below sole_h). Sneaker (white/black/grey/navy/red), leather (glossy), sandal (sole and
two straps), flip-flop (sole and thong). Closed shoes drop the foot triangles below
8.5 cm from the body so toes cannot poke through. Look key `shoes`.

**Standing poses** (BodyShape.pose, look key `pose`): 0 arms down, 1 hands in front
pockets, 2 arms crossed, 3 left hand on hip, 4 phone in the right hand with the head
bowed (phone pinned to hand_r). Aimed once from the rest skeleton.

Shots: clothes_lineup, clothes_street, clothes_bedouin, stance, person_close.

Still looks wrong: fitted tops on the men still hint at the chest under the cloth;
the hands-in-pockets pose reads more like hands clasped in front; shorts are painted
on the trouser layer (legs a little thick); the old mannequin fallback is untouched;
sandals' straps are simple bands.
## PR #1 check (PC, 25 Nov 15:00) - radio from world.json, encounter packs by DirAccess

Run on this branch (a1d2e3d) in the editor binary and in an exported release exe, with a
throwaway check script (not committed):
- **Radio**: R cycles all six stations and then off: 78 סיבובים, רדיו דרומה 101.5, הבייס FM,
  רדיו באבושקה, קול הקמפוס, גלי המדבר (the "own music" station is absent because there is no
  music folder in that run). On 78 סיבובים the record does not loop, and the end of a record
  moves on to the next (1929 -> 1928 -> 1914 -> 1926). The one-track stations loop.
  Same result in the exe.
- **Encounters**: EncounterBank.pack_files() finds the four packs, 118 deals. Inside the
  exported .pck, DirAccess.get_files_at("res://data/") also lists the files: a temporary extra
  data/encounters_zz_check.json was picked up as the 5th pack in the exe. Visitors came and
  asked three times in 70 s in both the editor run and the exe.
- No script errors. Nothing needed fixing.
