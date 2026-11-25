#!/usr/bin/env python3
"""Gives buildings whose height the map does not know a likelier one.

OpenStreetMap has no storey count for most of Beer Sheva, so
tools/osm_to_city.py falls back to three storeys for everything, and a
garden shed, a row of cottages and a housing block all come out 9.3 m
tall. The outline says more than that:

  a long narrow slab    the housing blocks of the fifties and sixties: four
                        storeys (the published figure for Shchuna Dalet)
  a small outline       a house: two storeys, or one if it is tiny

In the Old City, which is low, the small outlines become two storeys. The
map draws most of the Old City as one outline for a whole street block;
those are cut into house lots of different heights, the middle of the
deep ones left open as a courtyard, so that a block reads as a row of
houses and not as one slab ("piece": 1). Only buildings still at the fallback height and of no special
kind are touched, and each is marked ("guess": 1) so a
second run changes nothing.

Low houses with a simple outline also get a pitched roof of red tiles
("roof": "tile"): most of them in Ramot (small blocks of flats included), where the whole quarter is houses
with tiled roofs, and a share of them elsewhere. Which house gets one
depends only on where it stands, so a second run gives the same answer.

Buildings the map does not call shops, but which have a shop, a cafe or
the like marked inside them, get shop fronts at street level ("shops": 1).
A few places the map leaves nameless are filled in by hand (KNOWN).

Run before tools/dress_city.py:

  python3 tools/guess_heights.py
"""
import json
import math
import random
import sys
from pathlib import Path

from shapely import STRtree
from shapely.geometry import Point, Polygon, box
from shapely.geometry.polygon import orient

CITY = Path(__file__).resolve().parent.parent / "data" / "city.json"
STOREY = 3.1
FALLBACK = 9.3                      # what osm_to_city.py writes when it knows nothing
PLAIN_KINDS = {"yes", "residential", "apartments", "house", "detached", "terrace", "semidetached_house"}
OLD_CITY = box(-200, -440, 860, 560)

SLAB_LENGTH = 28.0                  # metres: at least this long...
SLAB_WIDTH = (7.5, 17.0)            # ...and this deep is a housing block
HOUSE_AREA = 190.0                  # square metres: smaller is a house
OLD_CITY_HOUSE_AREA = 450.0         # square metres: Old City outlines smaller than this are two storeys
HUT_AREA = 55.0                     # and smaller than this has one storey

LOT_WIDTH = (9.0, 18.0)             # metres of street front for one Old City house
LOT_HEIGHTS = ((4.0, 25), (6.2, 50), (7.4, 15), (9.3, 10))    # metres, and how common each is
LOT_MIN_AREA = 40.0                 # smaller leftovers are dropped
ROW_DEPTH = 20.0                    # deeper blocks are cut into rows about this deep

TILE_AREA = (55.0, 260.0)           # square metres of a house that can carry a tiled roof
TILE_MAX_HEIGHT = 6.5               # metres: two storeys at most
RAMOT_TILE_AREA = (55.0, 450.0)     # in Ramot the small blocks of flats have tiled roofs too,
RAMOT_TILE_MAX_HEIGHT = 9.4         # up to three storeys
TILE_SQUARENESS = 0.8               # share of its tightest box the outline must fill
RAMOT = box(900, -6500, 6000, -3300)
TILE_SHARE = {"ramot": 0.7, "old_city": 0.4, "elsewhere": 0.3}     # Ottoman houses had roofs of Marseille tiles

NOT_A_SHOP = {"kindergarten", "school", "place_of_worship", "parking", "community_centre", "clinic", "police", "yes"}
SHOP_REACH = 2.0                    # metres a marked shop may lie outside the outline it belongs to

# Words in a building's name that say it is full of shops.
SHOP_NAMES = ("קניון", "מרכז קניות", "שופרסל", "Mall", "השדרה", "תחנה מרכזית", "טיב טעם", "סופר")

# Heights the map lacks, from memory and not checked against a source.
HEIGHT_BY_NAME = {
    "קניון הנגב": 18.6,             # the mall beside the central bus station
    "מלון לאונרדו נגב": 31.0,       # the hotel tower, about ten storeys
}

# Places the map has an outline for but says nothing about: a point inside
# the outline, and what to write on it. Heights here are guesses too.
KNOWN = [
    ((470.0, -2660.0), {"name": "מרכז גילת", "h": 6.2, "shops": 1, "guess": 1}),   # the shopping centre of Shchuna Dalet
]


def storeys_for(outline):
    """How many storeys an outline of unknown height most likely has, or None to leave it."""
    try:
        poly = Polygon(outline)
    except ValueError:
        return None
    if not poly.is_valid or poly.is_empty:
        return None
    if OLD_CITY.contains(poly.centroid):
        # The Ottoman town is low: stone houses of one and two storeys.
        return 2 if poly.area < OLD_CITY_HOUSE_AREA else None
    corners = list(poly.minimum_rotated_rectangle.exterior.coords)
    sides = sorted((math.dist(corners[0], corners[1]), math.dist(corners[1], corners[2])))
    width, length = sides
    if poly.area < HUT_AREA:
        return 1
    if poly.area < HOUSE_AREA:
        return 2
    if length >= SLAB_LENGTH and SLAB_WIDTH[0] <= width <= SLAB_WIDTH[1]:
        return 4
    return None


def house_lots(outline, dice):
    """Cuts the outline of a whole Old City block into house lots: rows
    along its length, each row cut across into fronts of uneven width. In a
    block three rows deep or more the inner rows stay open as a courtyard."""
    corners = list(outline.minimum_rotated_rectangle.exterior.coords)
    a = (corners[1][0] - corners[0][0], corners[1][1] - corners[0][1])
    b = (corners[2][0] - corners[1][0], corners[2][1] - corners[1][1])
    origin = corners[0]
    if math.hypot(*a) < math.hypot(*b):
        # Measure from the next corner instead, so that `a` is the long side.
        origin = corners[1]
        a = (corners[2][0] - corners[1][0], corners[2][1] - corners[1][1])
        b = (corners[0][0] - corners[1][0], corners[0][1] - corners[1][1])
    length, depth = math.hypot(*a), math.hypot(*b)
    along = (a[0] / length, a[1] / length)
    across = (b[0] / depth, b[1] / depth)
    rows = max(1, round(depth / ROW_DEPTH))
    lots = []
    for row in range(rows):
        if rows >= 3 and 0 < row < rows - 1:
            continue                    # the courtyard
        near, far = depth * row / rows, depth * (row + 1) / rows
        at = 0.0
        while at < length - 0.5:
            front = dice.uniform(*LOT_WIDTH)
            if length - at - front < LOT_WIDTH[0] * 0.6:
                front = length - at     # no sliver at the end of the row
            cell = Polygon([
                (origin[0] + along[0] * at + across[0] * near, origin[1] + along[1] * at + across[1] * near),
                (origin[0] + along[0] * (at + front) + across[0] * near, origin[1] + along[1] * (at + front) + across[1] * near),
                (origin[0] + along[0] * (at + front) + across[0] * far, origin[1] + along[1] * (at + front) + across[1] * far),
                (origin[0] + along[0] * at + across[0] * far, origin[1] + along[1] * at + across[1] * far),
            ])
            at += front
            cut = outline.intersection(cell)
            pieces = [cut] if cut.geom_type == "Polygon" else [g for g in getattr(cut, "geoms", []) if g.geom_type == "Polygon"]
            for piece in pieces:
                if piece.area >= LOT_MIN_AREA:
                    lots.append(orient(Polygon(piece.exterior), 1.0))
    return lots


def split_old_city(data):
    """Replaces the whole-block outlines of the Old City by house lots. Returns how many blocks were cut."""
    kept, blocks = [], 0
    heights = [h for h, _ in LOT_HEIGHTS]
    weights = [w for _, w in LOT_HEIGHTS]
    for b in data["buildings"]:
        plain = str(b.get("kind", "yes")) in PLAIN_KINDS and not b.get("name") and not b.get("piece")
        outline = None
        if plain and len(b["pts"]) >= 3 and abs(float(b["h"]) - FALLBACK) < 0.01:
            outline = Polygon(b["pts"])
            if not outline.is_valid or outline.area < OLD_CITY_HOUSE_AREA or not OLD_CITY.contains(outline.centroid):
                outline = None
        if outline is None:
            kept.append(b)
            continue
        dice = random.Random(round(outline.centroid.x * 10.0) * 100003 + round(outline.centroid.y * 10.0))
        lots = house_lots(outline, dice)
        if len(lots) < 2:
            kept.append(b)
            continue
        blocks += 1
        for lot in lots:
            pts = [[round(x, 2), round(z, 2)] for x, z in list(lot.exterior.coords)[:-1]]
            kept.append({"h": dice.choices(heights, weights=weights)[0], "kind": b.get("kind", "yes"), "name": "",
                         "pts": pts, "guess": 1, "piece": 1})
    data["buildings"] = kept
    return blocks


def tiled(building):
    """Whether a house gets a pitched roof of red tiles."""
    if str(building.get("kind", "yes")) not in PLAIN_KINDS or building.get("shops"):
        return False
    try:
        poly = Polygon(building["pts"])
    except ValueError:
        return False
    if not poly.is_valid:
        return False
    in_ramot = RAMOT.contains(poly.centroid)
    in_old_city = OLD_CITY.contains(poly.centroid)
    area = RAMOT_TILE_AREA if in_ramot or in_old_city else TILE_AREA
    if float(building["h"]) > (RAMOT_TILE_MAX_HEIGHT if in_ramot else TILE_MAX_HEIGHT) or not area[0] <= poly.area <= area[1]:
        return False
    if poly.area < TILE_SQUARENESS * poly.minimum_rotated_rectangle.area:
        return False
    share = TILE_SHARE["ramot" if in_ramot else "old_city" if in_old_city else "elsewhere"]
    # The same house always draws the same lot: the dice are seeded by its position.
    dice = random.Random(round(poly.centroid.x * 10.0) * 100003 + round(poly.centroid.y * 10.0))
    return dice.random() < share


def main():
    data = json.loads(CITY.read_text(encoding="utf-8"))
    changed = {1: 0, 2: 0, 4: 0}
    tiles = 0
    print("Old City blocks cut into houses", split_old_city(data))
    for b in data["buildings"]:
        if b.get("guess") or abs(float(b["h"]) - FALLBACK) > 0.01:
            continue
        if str(b.get("kind", "yes")) not in PLAIN_KINDS or len(b["pts"]) < 3:
            continue
        storeys = storeys_for(b["pts"])
        if storeys is None:
            continue
        b["h"] = round(storeys * STOREY, 1)
        b["guess"] = 1
        changed[storeys] += 1
    outlines = [Polygon(b["pts"]) if len(b["pts"]) >= 3 else Point(0.0, 0.0) for b in data["buildings"]]
    for (x, z), facts in KNOWN:
        for b, outline in zip(data["buildings"], outlines):
            if outline.is_valid and outline.contains(Point(x, z)):
                b.update(facts)
    for b in data["buildings"]:
        name = str(b.get("name", ""))
        if name in HEIGHT_BY_NAME and abs(float(b["h"]) - FALLBACK) < 0.01:
            b["h"] = HEIGHT_BY_NAME[name]
            b["guess"] = 1
        if any(word in name for word in SHOP_NAMES) and str(b.get("kind", "yes")) in PLAIN_KINDS:
            b["shops"] = 1
    tree = STRtree(outlines)
    with_shops = set()
    for poi in data["pois"]:
        if str(poi.get("kind", "")) in NOT_A_SHOP:
            continue
        with_shops.update(int(i) for i in tree.query(Point(poi["p"]).buffer(SHOP_REACH), predicate="intersects"))
    for i in with_shops:
        b = data["buildings"][i]
        if str(b.get("kind", "yes")) in PLAIN_KINDS:
            b["shops"] = 1
    for b in data["buildings"]:
        b.pop("roof", None)
        if len(b["pts"]) >= 3 and tiled(b):
            b["roof"] = "tile"
            tiles += 1
    CITY.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print("one storey", changed[1], "two storeys", changed[2], "four storeys", changed[4], "of", len(data["buildings"]))
    print("tiled roofs", tiles, "with shop fronts", sum(1 for b in data["buildings"] if b.get("shops")))


if __name__ == "__main__":
    sys.exit(main())
