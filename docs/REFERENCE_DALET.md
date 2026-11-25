# Shchuna Dalet / Avraham Avinu: reference notes

These notes were written on the PC for building from. They are for looking at
only. No photo is used as a game texture.

## Sources

- **Street View could not be used.** Google Maps opened at 27 Avraham Avinu
  (panorama found), but the panorama renders black in the hidden in-app
  browser, and fetching the still thumbnails directly was refused. Nothing was
  signed in to or accepted.
- **Wikimedia Commons photos** (CC BY-SA 4.0, viewed as thumbnails, not
  stored in the repo). Game coordinates come from each photo's geotag
  (x = (lon - 34.78802) * 95250, z = -(lat - 31.24056) * 111320):
  - "The Pyramid Housing cooperative, Shchuna D IMG 5545" by Bella Kapish, 2018. Taken at about (380, -2707), looking east-south-east at the Pyramid.
  - "137678 / 137680 the pyramid building", PikiWiki Israel.
  - "Beersheba Shchuna D IMG 7059", 2019. Taken at about (112, -2622).
  - "Ringelblum Street, Beersheba IMG 4150" by Eddau. Taken at about (1189, -2962).
  - "Shchuna D Solar hot water panels IMG 4696", 2020. Taken at about (1147, -2789).
- Paired game shots from the same geotags: `docs/screenshots/dalet_ref_1..3.jpg`.
  The headings are guessed, so they show the same place but not the same frame.

## What the photos show

### Housing blocks
- The common block is a **long four-storey slab** ("רכבת"), 60–120 m long. A
  few are three storeys. Flat roof with a low parapet.
- **Plaster colours:** sand, ochre and dirty yellow (about #CDB88E to
  #D9C79A), or off-white/grey (#D8D6CF). The paint is never even: dark grey
  rain streaks under every sill and slab edge, damp blotches near the ground,
  and lighter patches where someone repainted one flat.
- **Windows:** horizontal, with roll shutters in white or grey aluminium. Many
  are half down. Window frames are white aluminium.
- **Balconies:** nearly all were closed in long ago, each flat differently.
  You see aluminium and glass, brown or beige shutters, the occasional green
  or blue panel, and sometimes a section of bare block. This is the single
  strongest "Beer Sheva" cue: one long block with forty different balconies.
- **AC units** in or under about every second window, with a rust or grime
  streak under each one.
- **Roofs** are packed: a row of **white solar water heater cylinders**
  (one per flat, about 1.5 m long) on steel stands, each with a dark flat
  collector panel tilted south. There are also TV aerials and dish antennas.
  Seen from the street, the roofline is a jagged row of white tanks.
- **Stair towers:** a vertical strip at each entrance, set back slightly, with
  narrow windows or a lattice of breeze blocks. The entrance door is often
  under a small concrete canopy, with a row of mailboxes inside.
- **Ground floor:** on Ringelblum (and the commercial stretch of Avraham
  Avinu), shops sit in an arcade under the block with coloured awnings and
  roller doors. Elsewhere the ground floor is flats, behind low walls.

### Between and around the blocks
- Low **rough-stone retaining walls** (grey-beige fieldstone, about 0.6–1.2 m)
  along the pavements and terraces.
- **Parking lots** of cracked asphalt, packed with white and silver cars
  (Mazda 3s, Skodas, Toyotas, Hyundais), with no markings in places.
- Dirt yards with dry grass, single **ficus** trees and a few **palms**, a
  **cypress** at a corner, and oleander or bougainvillea bushes.
- One-storey **public shelters** (מקלט), painted, some pink or pastel, with a
  pitched or flat roof.
- **Green iron pedestrian railings** along the kerb on the main streets
  (Ringelblum), plus bollards at crossings.
- **Kerbs** painted red-white and blue-white (already in the game).
- Overhead **telephone and power wires** on wooden or concrete poles across
  side streets.

### The Pyramid (Avraham Avinu 33)
- A **stepped terraced housing cooperative**: three or four storeys that step
  back like a ziggurat, built in grey concrete with beige render.
- Every terrace has a **wooden pergola or reed shade** and planters, so the
  whole building reads as layered horizontal bands of shade, with dark
  recesses under each terrace.
- Underneath are open **concrete galleries and bridges** (access decks), a
  **red brick paved** court, and green steel fences.
- In front are a **stone retaining wall** and a big asphalt parking lot.
- From the street it reads low and wide, not tall. Its silhouette is a
  stepped wedge.

## What the game already matches
- Sand and off-white slabs with roll shutters and closed-in balconies. Since
  36e746e this includes grime streaks, blotches and mixed shutter colours.
- Red-white and blue-white kerbs, zebra crossings, dumpsters, lamp posts.
- Mazda and Subaru traffic.

## What is still missing or wrong (suggested owner in brackets)
1. **Roofs need the white solar-tank row** on every shikun block: denser
   and closer to the front edge, so it shows from the street (city_dressing,
   cloud).
2. **Stair-tower strips** and entrance canopies (facades.gd can paint a
   breeze-block strip, but it would repeat every 8 m. The building UVs would
   need a separate stair bay to place them properly (city_builder, cloud)).
3. **The ground floor is the same as the upper floors** everywhere. Shikun
   blocks on main streets want a shop arcade or a stone plinth with a low
   wall (city_builder, cloud).
4. **Green kerb railings** along Avraham Avinu and Ringelblum, and wires on
   poles across side streets (street_furniture, PC).
5. **Parking lots between blocks** are dirt in the game. They should be
   cracked asphalt with parked cars (city_dressing, cloud; traffic.gd parked
   cars, PC).
6. The facade texture **repeats every 8 m**, which shows on long slabs. A
   4-bay texture would need a UV change in city_builder.
