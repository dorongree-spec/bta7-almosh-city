# Third-party assets

Every third-party file in `assets/`, where it came from and under which
licence. Models, textures, sounds and music are CC0 or public domain (no
attribution required; it is given anyway, with thanks); the fonts are under
the SIL Open Font Licence. Adding a file? Add a row here in the same pull
request (see CONTRIBUTING.md).

| Files | Pack | Author | Licence |
|---|---|---|---|
| `characters/mannequin.glb` | Universal Animation Library (Standard) | Quaternius, quaternius.com | CC0 1.0 |
| `vehicles/pickup.gltf`, `vehicles/sports.gltf`, `vehicles/truck.gltf` | Zombie Apocalypse Kit | Quaternius, quaternius.com | CC0 1.0 |
| `props/*.gltf` | Zombie Apocalypse Kit | Quaternius, quaternius.com | CC0 1.0 |
| `audio/sfx/*.ogg` | Impact Sounds | Kenney, kenney.nl | CC0 1.0 |
| `audio/radio/*.ogg` | Music Loops | Kenney, kenney.nl | CC0 1.0 |

Licence texts are in `assets/licenses/`. Files were fetched from the
`series-ai/jam-ready-assets` mirror on GitHub.

Map data: © OpenStreetMap contributors, ODbL 1.0.

## Textures (assets/textures)

Photo textures from [Poly Haven](https://polyhaven.com), all **CC0** (public domain).
They were downloaded at 1K resolution as JPG: diffuse (`_diff`), OpenGL normal (`_nor`) and roughness (`_rough`).

| file prefix | Poly Haven asset | used for |
|---|---|---|
| `asphalt` | asphalt_02 | roads (CityMaterials.asphalt, road shader) |
| `pavers` | square_concrete_pavers | pavements |
| `plaster` | white_plaster_rough_01 | facade grain (shikun, modern, shops, industrial) |
| `stone` | white_sandstone_blocks_02 | facade grain (old city stone) |
| `sand` | sand_01 | desert ground plane |
| `roof` | dirty_concrete | flat roofs |

## Fonts (assets/fonts)

All three families are under the **SIL Open Font Licence 1.1** and were taken
from the `google/fonts` repository on GitHub. Each carries Hebrew and Latin.
Licence texts: `assets/licenses/font-*-OFL.txt`.

| Files | Family | Designer | Used for |
|---|---|---|---|
| `Karantina-Bold.ttf` | Karantina | Rony Koch | logo lines, neighbourhood names, big cards |
| `SecularOne-Regular.ttf` | Secular One | Michal Sahar | menus, name tags, billboards |
| `Heebo-Regular.ttf`, `Heebo-Bold.ttf`, `Heebo-Black.ttf` | Heebo | Oded Ezer, Meir Sadan | everything else on screen |

Heebo ships as one variable font; the three weights here are fixed instances
cut from it with fontTools.

## Artwork (assets/art)

The logo (`logo.png`, drawn by `tools/art/make_logo.py`), the icon (`icon.png`) and the drawn posters (`poster_*.jpg`) are original work
made for this game. They are drawn as HTML and SVG and photographed with a
headless browser; the sources and the one-line build command are in
`tools/art/`. Files called `keyart_*.jpg`, when present, are stills rendered
from the game's own models. Nothing in this folder is traced, copied or
derived from any other game or brand.
## Vegetation (assets/textures)

| file | source | licence |
|---|---|---|
| `bark_diff/nor/rough.jpg` | [ambientCG Bark007](https://ambientcg.com/view?id=Bark007), 1K | CC0 |
| `leaf_cluster.png` | made by `tools/gen_foliage.gd` from [ambientCG LeafSet024](https://ambientcg.com/view?id=LeafSet024) leaves | CC0 |
| `palm_frond.png` | drawn by `tools/gen_foliage.gd` (no third-party pixels) | CC0 (ours) |

## People fabric (assets/textures)

| file | source | licence |
|---|---|---|
| `denim_diff/nor.jpg` | [Poly Haven denim_fabric](https://polyhaven.com/a/denim_fabric), 1K | CC0 |
| `jersey_diff/nor.jpg` | [Poly Haven cotton_jersey](https://polyhaven.com/a/cotton_jersey), 1K | CC0 |

## Garden ground (assets/textures)

| file | source | licence |
|---|---|---|
| `grass_diff/nor/rough.jpg` | [Poly Haven withered_grass](https://polyhaven.com/a/withered_grass), 1K | CC0 |

## Radio "78 סיבובים" (assets/audio/radio/shellac)

A 78 rpm shellac recording of about 1914, marked public domain on its
Wikimedia Commons page with {{PD-traditional}} (traditional music, no known
composer or lyricist). It came to Commons from the Free Music Archive's
"Excavated Shellac" collection. Converted to mono Vorbis and
loudness-normalised; nothing else is changed.

Only recordings published before 1926 are used: under the US Music
Modernization Act, sound recordings from 1923 to 1946 stay protected in the
US for 100 years after publication, so a 1926 recording is free there from
1 January 2027, a 1928 one from 2029 and so on. Three later recordings were
taken out before the public release for that reason and can return when
their year comes. Adding to this station? Check the year first.

| File | Title | Performer | Year | Source | Statement on the source page |
|---|---|---|---|---|---|
| `aldahre_kata_awsali_1914.ogg` | Aldahre Kata Awsali (traditional Egyptian song) | Munira al-Mahdiyya | c. 1914, Baidaphon 23045 | https://commons.wikimedia.org/wiki/File:Aldahre_Kata_Awsali_(c._1914).ogg | Public domain, PD-traditional |

## People: real bodies (assets/characters/ubc)

| Files | Pack | Author | Licence |
|---|---|---|---|
| `characters/ubc/*` (Superhero male and female bodies with eyes and eyebrows, five hairstyles, textures scaled to 1024 px) | Universal Base Characters (Standard) | Quaternius, quaternius.com (quaternius.itch.io/universal-base-characters) | CC0 1.0 |

They use the same skeleton as the Universal Animation Library mannequin, so
its animations drive them. The clothes are still painted by the game's own shader.
