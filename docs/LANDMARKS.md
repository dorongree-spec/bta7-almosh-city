# Landmarks: what stands where, and how sure we are

`scripts/landmarks.gd` replaces the plain extruded box of a few named
outlines with a model made for that building. This page says what each
model is based on. "Sourced" means a page that was actually read;
"from memory" means general knowledge that nobody has yet checked against
a photograph. Anything from memory should be compared with a reference
picture before more work goes into it.

The research behind this page is in the project's shared notes
(`landmarks.md`); reference photographs gathered on the PC go in
`docs/reference/`.

| Model | Outline name in the map | Based on | Confidence |
| --- | --- | --- | --- |
| `pyramid_house` | בית הפירמידה (Avraham Avinu 33, Shchuna Dalet) | Two stepped three-storey rows facing each other across an inner covered street, bridges and concrete beams over it, three open stairs under swept-up canopies, exposed concrete frame with rough plaster infill. Architects Lufenfeld and Gamerman, about 1970. | Sourced (heritage site page, two architecture walk-throughs, ynet). Colours and exact sizes are not in the sources. |
| `negev_centre` | מרכז הנגב | Ram Karmi, about 1960: an inner covered street like a bazaar at ground level, offices above, flats on the third floor; only part was built. The section widening towards the top is from memory. | Layout sourced (SOS Brutalism); section from memory. |
| `mosque` | המסגד הגדול | Stone hall, one dome, one slender minaret, arcade, in a garden; early 1900s. | Date sourced; shape from memory. |
| `turkish_station` | תחנת הרכבת הטורקית בבאר שבע | Two-storey stone building with a pitched roof, opened 1915, water tower beside it. | Sourced; the wings and the number of openings are guesses. |
| `water_tower` | מגדל המים | The station's stone water tower. | From memory. |
| `library` | הספרייה המרכזית | The university's central library (Nadler, 1968 to 1971): a large box with rows of white skylight hoods on the roof, all facing north. | Architect and date sourced; shape from memory. |
| `city_hall_tower` | עיריית באר שבע (the plain building is kept) | Concrete office building of the seventies with a tall narrow tower seen from all over the centre. | From memory. |
| `brigade_monument` | none (placed by latitude and longitude) | Dani Karavan, 1963 to 1968, on a hill north-east of town: a pierced tower about 20 m high, a split dome, a concrete tunnel. | Date sourced; shapes from memory; position approximate. |

## Heights

OpenStreetMap has no storey count for most of the town.
`tools/guess_heights.py` replaces the three-storey fallback with four
storeys for long narrow slabs (the published figure for the old blocks of
Shchuna Dalet), two for house-sized outlines and one for huts. Guessed
buildings carry `"guess": 1` in `data/city.json`.

## The ordinary housing block

Most of the town is not landmarks but blocks of flats, so the look of the
ordinary block matters more than any one model. `tools/dress_city.py`
(`dress_facades`) hangs on every block of three storeys or more a stairwell
behind pierced blocks over each entrance, columns of balconies closed in
four different ways, wall air conditioners and drying racks, and puts a
public shelter in some yards. All of this follows written descriptions of
Shchuna Dalet, not measurements.

## Roofs and shops

- `tools/guess_heights.py` marks low houses for a red tiled roof,
  seven in ten of the houses and small blocks in Ramot, three in ten houses elsewhere. Which
  houses really have one is not in the map; the share is a guess.
- Buildings with a shop, cafe or the like marked inside them get shop
  fronts and a concrete canopy over the pavement. The shopping centre of
  Shchuna Dalet (מרכז גילת) is named by hand; its two storeys are a guess.
- Avraham Avinu street has a row of trees down each side. That the real
  street is tree-lined is from memory.

## Still to do

- The quarter-kilometre block and the carpet housing opposite it (model
  housing estate, Shchuna He): find the right outline first.
- The drawers tower (בניין המגירות): not in the map under a name. One source
  puts it at Shimoni 9 in Shchuna Bet, a photo geotag puts it near the Negev
  Centre (about x 959, z -1865); no outline lies there. Needs someone who
  knows the town to point at it.
- The high-tech footbridge over the railway, the Turner stadium, the
  covered market.
