# Contributing to BTA 7 Almosh City

Thanks for wanting to make it better. You don't need to know Godot or write code to help:
most of the game is plain text in `data/`. This guide starts with the easy changes and ends
with code.

[עברית בקצרה](#בעברית-בקצרה) at the bottom.

- [Ground rules for content](#ground-rules-for-content)
- [Add a person (an encounter)](#add-a-person-an-encounter)
- [Add a radio station or a song](#add-a-radio-station-or-a-song)
- [Add jokes, billboards, phone calls](#add-jokes-billboards-phone-calls)
- [Add a place or a landmark](#add-a-place-or-a-landmark)
- [Change code](#change-code)
- [Add third-party assets](#add-third-party-assets)
- [Send your change](#send-your-change)

## Ground rules for content

The game is satire. It works because it hits everyone the same, and because it is clearly
invented. Keep it that way:

1. **Everybody gets it equally.** No crowd is the butt of every joke, and none is spared.
2. **Stereotypes, yes. Slurs, no.** Exaggerate habits, cars, clothes, food, slang and mothers.
   Don't use slurs, don't dehumanise, don't joke about real violence against a group.
3. **Invented people only.** No real private individuals, no real local businesses named
   in a way that harms them. Public landmarks and street names are fine.
4. **Nothing from commercial games or brands.** No names, logos, fonts, music, sounds, models or
   screenshots from other games, and no real car or clothing brands. Parody names are fine
   (the "Subara DL", the "Hondo Civic"). See [docs/SATIRE.md](docs/SATIRE.md).
5. **Plastic chairs are always "כיסא כתר פלסטיק"** in any text the player sees. House style.

Maintainers may edit or decline content that breaks these rules, however funny.

## Add a person (an encounter)

An encounter is someone who walks (or drives, or phones) up to the player with an offer, a
favour, a fine or just a line. They live in `data/encounters*.json`. Any file named
`data/encounters_<something>.json` is loaded automatically, so you can add to an existing file or
start your own pack.

A minimal encounter:

```json
{
  "id": "melon_seller",
  "who": "tenderim",
  "name": "אבו ג'מיל",
  "when": "foot",
  "near": "old_city",
  "hail": "אבטיח! אבטיח על סכין!",
  "offer": "אבטיח שלם, 20 שקל. מתוק כמו הבת דודה שלך.",
  "yes": { "line": "בתיאבון. תחזיר את הסכין.", "money": -20, "health": 15 },
  "no":  { "line": "מחר הוא 25. העונה נגמרת." }
}
```

Add it to the `"encounters": [ ... ]` list of a file, run the checker, and play.

| Field | What it means |
|---|---|
| `id` | Unique short English name. The checker tells you if it is taken. |
| `who` | The sort of person, which sets their clothes and how they react: `tenderim` (the traders), `meshuparot` (the tuned-car crowd), `ktarim` (the chair crowd), `student`, `babushka`, `soldier`, `landlord`, `inspector`, `elder`, `local`. |
| `name` | What the name tag over their head says. |
| `when` | `foot`, `car` or `any`: whether the player must be walking or driving. |
| `near` | Optional part of town: `old_city`, `dalet`, `tet`, `campus`, `center`, `emek_sara`. |
| `trigger` | Optional. When it happens. Conditions: `idle`, `runs_past`, `drives_slow`, `holds_chair`, `low_money`, `low_health`, `heat_high`, `night`, `dust_storm`, `fleeing`, `thursday`, `chased`. Events: `honks`, `parks`, `takes_chair`, `in_fight`, `hits_vehicle`, `touches_vehicle`. |
| `hail` | What they shout as they approach. |
| `lines` | Optional list of lines said before the question. |
| `offer` | The question. **E** is yes, **Q** is no. Leave it out for a person who only talks; then use `effects`. |
| `yes`, `no`, `effects` | What happens. Any of: `line`, `money`, `heat`, `health`, `reports` (negative clears fines), `chair` (true/false), `repair`, `take_car`, `car_damage`, `hold` (seconds the player is made to sit), `mood` (`nag`, `angry`, `flee`), `backup` (how many friends come), `calm` (ends every chase), `respect`, `chain` (any text: the same person goes on to another of their crowd's offers). |
| `phone` | `true` makes it a phone call; nobody walks up. |
| `cooldown` | Seconds before the same encounter can happen again (default 150). |

The full description, in Hebrew, is the `_readme` at the top of `data/encounters.json`. More
examples: `data/encounters_tv.json` also holds outfits, nicknames and banter between passers-by;
`data/encounters_slang.json` holds a slang glossary and per-crowd "flavor" words that get mixed
into every line.

**Test it:** run the game from Godot. Encounters come every 16 to 30 seconds. To meet yours
straight away, temporarily set `"cooldown": 1` and a `trigger` you can cause (for example
`honks`, then press **H**). Remember to remove it before you commit.

## Add a radio station or a song

Stations are the `"radio"` list in `data/world.json`:

```json
{
  "id": "falafel_fm",
  "name": "פלאפל FM 98.0",
  "genre": "מזרחית של פעם",
  "host": "שלומי",
  "bit": "הקדשה לכל מי שעומד בתור",
  "tracks": ["falafel_fm/song_one.ogg", "falafel_fm/song_two.ogg"]
}
```

Put the audio files under `assets/audio/radio/` (here `assets/audio/radio/falafel_fm/`).
`tracks` are paths relative to that folder. One track loops; several play in turn. A station whose
files are all missing is left off the dial, so a station can be written before its music exists.

**Music must be free to redistribute:** your own recording, CC0, CC BY, CC BY-SA, or public
domain in Israel *and* the United States (where GitHub is). "I found it on YouTube" is not a
licence. Commercial songs can't go in the repo; players can drop their own files into the
`music` folder instead. Add every file to `assets/CREDITS.md` with its source link and licence.
Ogg Vorbis, mono, about 96 kbps keeps the repo small.

## Add jokes, billboards, phone calls

`data/world.json` holds most of the rest of the writing. Add lines to the lists:

| Key | What it is |
|---|---|
| `pedestrian_barks` | what passers-by say as you go past |
| `gang_barks` | lines each crowd says |
| `mom_phone_lines` | Mom calling. She always calls. |
| `radio_ads` | ads between songs |
| `signs` | billboards and shop signs |
| `factions`, `vehicles`, `districts`, `missions` | the gangs, parody cars, parts of town, missions |

## Add a place or a landmark

- **Name a building the map doesn't name:** add a line to `KNOWN` in `tools/guess_heights.py`
  with a point inside the outline (game metres) and what to write on it, then run
  `python3 tools/guess_heights.py` and `python3 tools/dress_city.py`.
- **Model a landmark:** landmarks are built from simple shapes in GDScript, in
  `scripts/landmarks.gd`. Add the building's name as the map spells it to `SITES`, and a
  function that builds it (copy `_water_tower` for a small one). Write in
  [docs/LANDMARKS.md](docs/LANDMARKS.md) what you based it on. Photos you use as reference must
  not be committed unless their licence allows it; describe them and link instead.
- **Map data** comes from OpenStreetMap. Fixing a street? Fix it on
  [openstreetmap.org](https://www.openstreetmap.org) first; everyone benefits, and the next
  import picks it up.

## Change code

- Godot **4.3**, GDScript, Forward+ renderer. Open `project.godot` and press F5.
- One system per file in `scripts/`. Each file starts with a `##` comment saying what it does and
  how it fits in; keep that comment true when you change the file.
- Static types everywhere (`var speed: float`, `func f(x: int) -> void`). In particular, never
  `:=` a value that comes out of a Dictionary or an untyped Array; write the type.
- Follow the [GDScript style guide](https://docs.godotengine.org/en/4.3/tutorials/scripting/gdscript/gdscript_styleguide.html):
  tabs, `snake_case`, `PascalCase` classes, constants in `CAPS`.
- Prefer data over code: if a new feature has content, read it from `data/` so the next person
  can extend it without you.
- Check syntax without opening Godot: `pip install "gdtoolkit==4.*"` then `gdparse scripts/*.gd`.
- Performance matters: the target is 60 fps on a mid-range GPU. Say in the PR what fps you saw
  before and after if your change touches rendering, people or traffic.

## Add third-party assets

Only assets whose licence lets anyone redistribute and modify them: CC0, CC BY, CC BY-SA, OFL,
MIT or similar. **Not allowed:** anything from a commercial game, Mixamo, Sketchfab models
without a CC licence, Google Maps or Street View imagery, stock sites with "personal use"
licences, AI images of real people.

For every file, add a row to `assets/CREDITS.md` (file, title, author, source URL, licence) and,
if the licence isn't already covered, an entry in `REUSE.toml`. CI runs `reuse lint` and will
fail if a file has no licence.

## Send your change

1. Fork the repository and create a branch.
2. Make your change. Keep one idea per pull request; a new encounter pack and a physics change
   are two PRs.
3. Run the checks:
   ```
   python3 tools/validate_content.py
   gdparse scripts/*.gd        # only if you changed code
   ```
4. Play it. If you changed something you can see, attach a screenshot to the PR.
5. Open a pull request and fill in the template.

By sending a pull request you agree that your contribution is licensed under this repository's
licences: MIT for code, CC BY-SA 4.0 for content, as listed in the [README](README.md#licences).

Questions are welcome as issues. Be decent to each other; see the [Code of Conduct](CODE_OF_CONDUCT.md).

---

## בעברית בקצרה

- **להוסיף דמות שניגשת לשחקן:** מוסיפים רשומה לאחד הקבצים `data/encounters*.json`, או פותחים קובץ חדש בשם `data/encounters_<משהו>.json` והמשחק טוען אותו לבד. הדוגמה והשדות למעלה; ההסבר המלא בעברית נמצא ב-`_readme` בראש `data/encounters.json`.
- **תחנת רדיו:** רשומה ברשימת `radio` בקובץ `data/world.json`, עם `tracks` שמצביעים לקבצים תחת `assets/audio/radio/`. רק מוזיקה שמותר להפיץ (שלכם, CC0, CC BY, נחלת הכלל). שירים מסחריים לא נכנסים לריפו; כל שחקן יכול לשים קבצים משלו בתיקייה `music`.
- **בדיחות, שלטים, שיחות מאמא:** רשימות בקובץ `data/world.json`.
- **לפני ששולחים:** `python3 tools/validate_content.py` בודק את כל קבצי התוכן ואומר בדיוק מה לא תקין.
- **כללי התוכן:** כולם חוטפים באותה מידה, סטריאוטיפים כן וקללות גזעניות לא, רק דמויות בדיוניות, ושום דבר ממשחקים או מותגים מסחריים. הכיסא הוא תמיד "כיסא כתר פלסטיק".
