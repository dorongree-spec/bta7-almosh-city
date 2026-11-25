#!/usr/bin/env python3
"""Fills the space between the buildings of data/city.json.

The map knows roads and building outlines and nothing else, so on its own it
draws a city standing on bare sand. This works out, once and offline, what
belongs in between:

  on the ground   plots around the buildings (garden, paved court, car park or works yard),
                  paved squares with trees and benches on the empty blocks of the Old City,
                  low walls round them with gaps for gates, bushes along the
                  inside of the walls, trees, and desert scrub and stones on
                  the land nobody built on
  on the roofs    solar water heaters in rows, stair heads, air-conditioner
                  units, chillers, satellite dishes, aerials, shed vents,
                  and pitched roofs of red tiles on the houses marked for one
  on the walls    of the housing blocks: a stairwell behind a screen of
                  pierced blocks over every entrance, balconies that every
                  family closed in its own way, air-conditioner units and
                  racks of laundry
                  and a concrete canopy over the pavement along shop fronts
  in the yards    the mound of a public shelter beside some of the blocks
  on the street   dumpsters and bus stops, and a row of trees down each side
                  of the streets named in TREE_LINED

Nothing here is drawn; it only decides where things go. The game reads the
result and draws it (scripts/city_dressing.gd).

Output:
  data/dressing.json   what layers there are and where each sits in the numbers
  data/dressing.bin    the numbers, 32-bit floats, little-endian

Run from the repository root (needs shapely and numpy):

  python3 tools/dress_city.py
  python3 tools/dress_city.py --preview out.png -400 -700 300 -100   # x0 z0 x1 z1

Coordinates are the game's: metres, x east, z south, origin at the start point.
A yaw of 0 faces south (+z); positive yaw turns towards the east (+x).
"""
import argparse
import json
import math
import random
import struct
import sys
from pathlib import Path

import numpy as np
import shapely
from shapely import STRtree
from shapely.geometry import LineString, MultiLineString, Point, Polygon, box
from shapely.geometry.polygon import orient
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parent.parent
CITY = ROOT / "data" / "city.json"
OUT_INDEX = ROOT / "data" / "dressing.json"
OUT_NUMBERS = ROOT / "data" / "dressing.bin"

SEED = 1948

# The same rules city_builder.gd uses to pick a facade, so that a roof gets
# the clutter that suits the walls under it.
OLD_CITY = box(-200, -440, 860, 560)
# Outlines that the game replaces with a model of their own (the names in
# scripts/landmarks.gd that are not marked "keep"): no roof clutter there.
LANDMARKS = {"בית הפירמידה", "מרכז הנגב", "המסגד הגדול", "תחנת הרכבת הטורקית בבאר שבע", "מגדל המים", "הספרייה המרכזית"}
SHED_KINDS = {"industrial", "warehouse", "service", "roof", "hangar"}
TOWER_KINDS = {"office", "government", "university", "hospital"}
STOREY = 3.1
PAVEMENT_EXTRA = 5.0

GREEN_AREAS = {"park", "pitch", "cemetery"}
FOOT_KINDS = {"footway", "path", "steps", "pedestrian", "cycleway"}

# How far a plot reaches out from its building, by the kind of building.
PLOT_REACH = {"shikun": 6.5, "stone": 4.0, "modern": 8.0, "industrial": 9.0}
SQUARE_AREA = (350.0, 14000.0)     # square metres an empty Old City block needs to become a square
SQUARE_MIN_WIDTH = 11.0
SQUARE_TREE_EVERY = 14.0           # metres between the trees round the edge of a square
SQUARE_BENCH_CHANCE = 0.45         # of the gaps between two trees that get a bench
GATE_WIDTH = 2.8
GATE_EVERY = (13.0, 24.0)          # metres of wall between two gates

BLOCK_MIN_STOREYS = 3               # housing blocks from this height up get stairwells and balconies
BLOCK_MIN_AREA = 140.0
STAIR_EVERY = 24.0                  # metres of front for each entrance
BALCONY_EVERY = 7.0                 # metres between two columns of balconies
BALCONY_KINDS = ("balcony_open", "balcony_shutter", "balcony_glass", "balcony_built")
WALL_CLEARANCE = 1.6                # metres that must be free in front of a wall before anything hangs on it
SHELTER_CHANCE = 0.22               # of the long blocks that have a public shelter in the yard
SHELTER_OUT = 9.0                   # metres from the wall to the middle of the shelter
SHOP_KINDS = {"retail", "commercial", "kiosk", "supermarket"}
CANOPY_DEPTH = 2.0                  # metres a shop canopy reaches over the pavement
CANOPY_MAX_HEIGHT = 13.0            # taller buildings have their shops behind glass, not under a canopy
TREE_LINED = {"אברהם אבינו"}        # streets with a row of trees down each side
STREET_TREE_EVERY = 13.0
STONE_WALL_REACH = 22.0             # metres from such a street within which yard walls are rough stone
TILE_EAVES = 0.45                   # metres a tiled roof sticks out past the wall

SOLAR_FACING = 0.0                  # collectors face south
DISH_FACING = math.atan2(-0.5, 0.85)  # every dish in town looks at the same satellite


def style_of(building, centre):
    kind = str(building.get("kind", "yes"))
    h = building["h"]
    if kind in SHED_KINDS:
        return "industrial"
    if h >= 20.0 or kind in TOWER_KINDS:
        return "modern"
    if OLD_CITY.contains(centre) and h <= 10.0:
        return "stone"
    return "shikun"


def clean_polygon(pts):
    """A valid polygon from a ring of points, or None if there is nothing to it."""
    if len(pts) < 3:
        return None
    poly = Polygon(pts)
    if not poly.is_valid:
        poly = poly.buffer(0)
    if poly.is_empty:
        return None
    if poly.geom_type == "MultiPolygon":
        poly = max(poly.geoms, key=lambda g: g.area)
    return poly if poly.area >= 12.0 else None


def polygons_of(geom):
    """Every polygon inside a geometry, whatever kind of collection it is."""
    if geom.is_empty:
        return []
    if geom.geom_type == "Polygon":
        return [geom]
    if hasattr(geom, "geoms"):
        return [p for g in geom.geoms for p in polygons_of(g)]
    return []


def lines_of(geom):
    if geom.is_empty:
        return []
    if geom.geom_type == "LineString":
        return [geom]
    if hasattr(geom, "geoms"):
        return [l for g in geom.geoms for l in lines_of(g)]
    return []


def without_holes(poly):
    """Splits a polygon with holes into pieces that have none (the game's
    triangulator only takes simple outlines)."""
    if not poly.interiors:
        return [poly]
    hole = Polygon(poly.interiors[0]).centroid
    x0, z0, x1, z1 = poly.bounds
    pieces = []
    for half in (box(x0 - 1, z0 - 1, hole.x, z1 + 1), box(hole.x, z0 - 1, x1 + 1, z1 + 1)):
        for part in polygons_of(poly.intersection(half)):
            if part.area > 4.0:
                pieces.extend(without_holes(part))
    return pieces


def long_axis(poly):
    """Unit vector along the longer side of the tightest box round a polygon, and both side lengths."""
    corners = list(poly.minimum_rotated_rectangle.exterior.coords)
    a = np.subtract(corners[1], corners[0])
    b = np.subtract(corners[2], corners[1])
    la, lb = float(np.hypot(*a)), float(np.hypot(*b))
    if la < 0.01 and lb < 0.01:
        return np.array([1.0, 0.0]), 0.0, 0.0
    if la >= lb:
        return a / la, la, lb
    return b / lb, lb, la


def yaw_of(direction):
    """The yaw that turns an object's front (+z) to point along a direction (x, z)."""
    return math.atan2(direction[0], direction[1])


# --- reading the city ----------------------------------------------------------------

class City:
    def __init__(self, path):
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        self.bounds = data["bounds"]
        self.buildings = []          # dicts: poly, h, kind, style
        for b in data["buildings"]:
            poly = clean_polygon(b["pts"])
            if poly is None:
                continue
            self.buildings.append({
                "poly": poly, "h": float(b["h"]), "kind": str(b.get("kind", "yes")), "name": str(b.get("name", "")),
                "roof": str(b.get("roof", "")),
                "shops": bool(b.get("shops")) or str(b.get("kind", "")) in SHOP_KINDS,
                "style": style_of(b, poly.centroid),
            })
        self.building_tree = STRtree([b["poly"] for b in self.buildings])

        drive, foot, kerb = [], [], []
        self.roads = []
        for r in data["roads"]:
            if len(r["pts"]) < 2:
                continue
            line = LineString(r["pts"])
            if line.length < 0.5:
                continue
            w = float(r["w"])
            if r["drivable"]:
                drive.append(line.buffer((w + PAVEMENT_EXTRA) / 2.0, cap_style="round"))
                kerb.append(line.buffer(w / 2.0, cap_style="round"))
                self.roads.append({"line": line, "w": w, "kind": r["kind"], "roundabout": bool(r.get("roundabout")), "name": str(r.get("name", ""))})
            elif r["kind"] in FOOT_KINDS:
                foot.append(line.buffer(w / 2.0 + 0.6, cap_style="flat"))
        self.road_zone = unary_union(drive)       # carriageways and their pavements
        self.carriageway = unary_union(kerb)
        self.foot_zone = unary_union(foot)        # footpaths, with a little elbow room
        self.foot_parts = foot
        self.foot_tree = STRtree(foot)
        self.green = unary_union([p for p in (clean_polygon(a["pts"]) for a in data["areas"] if a["kind"] in GREEN_AREAS) if p])
        self.footprints = unary_union([b["poly"] for b in self.buildings])
        for geom in (self.road_zone, self.carriageway, self.foot_zone, self.green, self.footprints):
            shapely.prepare(geom)


# --- ground: plots, walls, planting --------------------------------------------------

def make_plots(city):
    """Land that belongs to buildings: each footprint grown outwards, neighbours
    merged, roads and parks cut away. Returns (polygon, kind) pairs."""
    grown = [b["poly"].buffer(PLOT_REACH[b["style"]], join_style="mitre", mitre_limit=2.0) for b in city.buildings]
    land = unary_union(grown)
    land = land.buffer(3.0, join_style="mitre").buffer(-3.0, join_style="mitre")      # close the slits between neighbours
    land = land.difference(city.road_zone.buffer(0.25)).difference(city.green)
    land = land.buffer(-1.0, join_style="mitre").buffer(1.0, join_style="mitre")      # drop slivers
    plots = []
    rng = random.Random(SEED)
    for poly in polygons_of(land):
        if poly.area < 90.0:
            continue
        poly = poly.simplify(0.4)
        if poly.is_empty or not poly.is_valid:
            continue
        styles = [city.buildings[i]["style"] for i in city.building_tree.query(poly, predicate="intersects")]
        if not styles:
            continue
        main = max(sorted(set(styles)), key=styles.count)   # sorted: the same answer on every run
        if main == "industrial":
            kind = "works"
        elif main in ("stone", "modern"):
            kind = "paved"
        else:
            # Between the housing blocks: mostly dry garden, the rest a car park of
            # cracked asphalt or a paved court.
            kind = rng.choices(("garden", "parking", "paved"), weights=(60, 24, 16))[0]
        plots.append((poly, kind))
    return plots


def make_walls(city, plots):
    """Walls along the edge of each plot, broken by gates and wherever a
    footpath crosses. Returns {wall kind: [(x0, z0, x1, z1), ...]}."""
    rng = random.Random(SEED + 1)
    walls = {"wall_low": [], "wall_stone": [], "wall_high": []}
    lined = [road["line"] for road in city.roads if any(name in road["name"] for name in TREE_LINED)]
    stone_street = unary_union(lined).buffer(STONE_WALL_REACH) if lined else None
    for poly, kind in plots:
        # Along Avraham Avinu every yard stands behind a wall of rough stone (Street View, 2018).
        on_stone_street = stone_street is not None and poly.intersects(stone_street)
        if kind in ("paved", "parking") and rng.random() < 0.6 and not on_stone_street:
            continue  # paved forecourts mostly run straight into the pavement
        if kind == "works":
            layer = "wall_high"
        else:
            layer = "wall_stone" if on_stone_street or rng.random() < 0.3 else "wall_low"
        pieces = []
        for ring in [poly.exterior, *poly.interiors]:
            coords = list(ring.coords)
            to_gate = rng.uniform(3.0, GATE_EVERY[1])
            for a, b in zip(coords[:-1], coords[1:]):
                length = math.dist(a, b)
                if length < 1.5:
                    continue
                ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
                at = 0.0
                while at < length - 0.5:
                    run = min(to_gate, length - at)
                    if run >= 1.2:
                        pieces.append(LineString([(a[0] + ux * at, a[1] + uz * at), (a[0] + ux * (at + run), a[1] + uz * (at + run))]))
                    at += run
                    to_gate -= run
                    if to_gate <= 0.01:
                        at += GATE_WIDTH * (2.0 if kind == "works" else 1.0)
                        to_gate = rng.uniform(*GATE_EVERY)
        if not pieces:
            continue
        kept = MultiLineString(pieces)
        crossing = city.foot_tree.query(kept, predicate="intersects")
        if len(crossing):
            kept = kept.difference(unary_union([city.foot_parts[i] for i in crossing]))
        for line in lines_of(kept):
            if line.length >= 1.2:
                (x0, z0), (x1, z1) = line.coords[0], line.coords[-1]
                walls[layer].append((x0, z0, x1, z1))
    return walls


def make_squares(city, plots):
    """Empty blocks in the Old City become paved squares with a row of trees
    and benches round the edge, instead of bare sand between the stone
    houses. Returns the squares as (polygon, "square") pairs, their trees
    and their benches (x, z, yaw)."""
    rng = random.Random(SEED + 6)
    taken = unary_union([p for p, _ in plots] + [city.road_zone.buffer(0.25), city.green, city.footprints.buffer(1.0)])
    empty = OLD_CITY.difference(taken)
    empty = empty.buffer(-3.0, join_style="mitre").buffer(3.0, join_style="mitre")    # drop the strips between plots
    squares, trees, benches = [], [], []
    for poly in polygons_of(empty):
        if not SQUARE_AREA[0] <= poly.area <= SQUARE_AREA[1]:
            continue
        poly = poly.simplify(0.4)
        if poly.is_empty or not poly.is_valid:
            continue
        axis, _, width = long_axis(poly)
        if width < SQUARE_MIN_WIDTH:
            continue
        squares.append((poly, "square"))
        # One row of trees round the edge, benches in between looking at the
        # open middle.
        for ring in lines_of(poly.buffer(-4.0).boundary):
            if ring.length < SQUARE_TREE_EVERY * 2.0:
                continue
            count = int(ring.length / SQUARE_TREE_EVERY)
            step = ring.length / count
            for i in range(count):
                p = ring.interpolate(i * step)
                if not city.foot_zone.contains(p):
                    trees.append((p.x, p.y, rng.uniform(0.85, 1.25), rng.uniform(0, math.tau)))
                if rng.random() > SQUARE_BENCH_CHANCE:
                    continue
                at = (i + 0.5) * step
                seat, ahead = ring.interpolate(at), ring.interpolate(at + 0.5)
                along = (ahead.x - seat.x, ahead.y - seat.y)
                for inward in ((-along[1], along[0]), (along[1], -along[0])):
                    if poly.buffer(-4.0).contains(Point(seat.x + inward[0] * 2.0, seat.y + inward[1] * 2.0)):
                        if not city.foot_zone.contains(seat):
                            benches.append((seat.x, seat.y, yaw_of(inward)))
                        break
    return squares, trees, benches


def spread(points, minimum):
    """Drops points that crowd an earlier one (simple grid test)."""
    taken, kept = set(), []
    for p in points:
        cell = (int(p[0] // minimum), int(p[1] // minimum))
        if any((cell[0] + i, cell[1] + j) in taken for i in (-1, 0, 1) for j in (-1, 0, 1)):
            continue
        taken.add(cell)
        kept.append(p)
    return kept


def plant_plots(city, plots):
    """Bushes along the inside of garden walls, and trees where there is room."""
    rng = random.Random(SEED + 2)
    bushes, trees = [], []
    blocked_for_bushes = unary_union([city.footprints.buffer(0.8), city.foot_zone])
    blocked_for_trees = unary_union([city.footprints.buffer(3.2), city.foot_zone, city.road_zone.buffer(1.0)])
    shapely.prepare(blocked_for_bushes)
    shapely.prepare(blocked_for_trees)
    for poly, kind in plots:
        if kind == "works":
            continue
        # Bushes: beads on a string one metre inside the edge.
        if kind == "garden":
            hedge = rng.random() < 0.12       # some plots grow a proper hedge
            for line in lines_of(poly.buffer(-1.1).boundary):
                step = 2.1 if hedge else rng.uniform(3.5, 7.0)
                at = rng.uniform(0, step)
                while at < line.length:
                    p = line.interpolate(at)
                    if (hedge or rng.random() < 0.5) and not blocked_for_bushes.contains(p):
                        bushes.append((p.x, p.y, rng.uniform(0.7, 1.15) * (0.85 if hedge else 1.0), rng.uniform(0, math.tau)))
                    at += step * rng.uniform(0.8, 1.25)
        # Trees: thrown at random, kept where they have room to grow.
        room = poly.buffer(-2.0)
        if room.is_empty:
            continue
        wanted = int(room.area / (150.0 if kind == "garden" else 420.0) + rng.random())
        x0, z0, x1, z1 = room.bounds
        tries, found = 0, []
        while len(found) < wanted and tries < wanted * 12:
            tries += 1
            p = Point(rng.uniform(x0, x1), rng.uniform(z0, z1))
            if room.contains(p) and not blocked_for_trees.contains(p):
                found.append((p.x, p.y, rng.uniform(0.75, 1.2), rng.uniform(0, math.tau)))
        trees.extend(found)
    return bushes, spread(trees, 5.5)


def scatter_wasteland(city, plots):
    """Scrub and stones on the open land inside and around town."""
    rng = np.random.default_rng(SEED + 3)
    taken = unary_union([p for p, _ in plots] + [city.road_zone.buffer(1.5), city.foot_zone, city.green, city.footprints.buffer(1.0)])
    near_town = unary_union([city.footprints.buffer(110.0, resolution=2), city.road_zone.buffer(30.0, resolution=2)])
    open_land = near_town.difference(taken)
    shapely.prepare(open_land)
    x0, z0, x1, z1 = open_land.bounds
    cell = 9.0
    xs, zs = np.meshgrid(np.arange(x0, x1, cell), np.arange(z0, z1, cell))
    xs = xs.ravel() + rng.uniform(0, cell, xs.size)
    zs = zs.ravel() + rng.uniform(0, cell, zs.size)
    # Scrub grows in patches: keep more of it where a slow noise is high.
    patch = 0.5 + 0.5 * np.sin(xs / 37.0 + 1.3) * np.cos(zs / 29.0 - 0.7) + 0.25 * np.sin((xs + zs) / 11.0)
    roll = rng.uniform(0, 1, xs.size)
    is_bush = roll < 0.85 * np.clip(patch, 0.08, 1.0)
    is_rock = (roll > 0.955) & ~is_bush
    inside = shapely.contains_xy(open_land, xs, zs)
    bushes = [(float(x), float(z), float(s), float(y)) for x, z, s, y in zip(
        xs[is_bush & inside], zs[is_bush & inside],
        rng.uniform(0.45, 0.95, int((is_bush & inside).sum())), rng.uniform(0, math.tau, int((is_bush & inside).sum())))]
    rocks = [(float(x), float(z), float(s), float(y)) for x, z, s, y in zip(
        xs[is_rock & inside], zs[is_rock & inside],
        rng.uniform(0.4, 1.3, int((is_rock & inside).sum())), rng.uniform(0, math.tau, int((is_rock & inside).sum())))]
    return bushes, rocks, open_land


# --- roofs ---------------------------------------------------------------------------

def grid_on(poly, axis, along, across, centre):
    """Grid points inside a polygon, lined up with its long axis. Returns
    (x, z, row, column) tuples sorted row by row."""
    if poly.is_empty:
        return []
    side = np.array([-axis[1], axis[0]])
    x0, z0, x1, z1 = poly.bounds
    reach = math.hypot(x1 - x0, z1 - z0) / 2.0 + along
    n_i, n_j = int(reach / along) + 1, int(reach / across) + 1
    ii, jj = np.meshgrid(np.arange(-n_i, n_i + 1), np.arange(-n_j, n_j + 1))
    ii, jj = ii.ravel(), jj.ravel()
    xs = centre[0] + axis[0] * ii * along + side[0] * jj * across
    zs = centre[1] + axis[1] * ii * along + side[1] * jj * across
    keep = shapely.contains_xy(poly, xs, zs)
    found = sorted(zip(jj[keep].tolist(), ii[keep].tolist(), xs[keep].tolist(), zs[keep].tolist()))
    return [(x, z, j, i) for j, i, x, z in found]


def run_of(points, count, rng):
    """`count` neighbours in a row, starting somewhere at random."""
    if count >= len(points):
        return points
    start = rng.randrange(0, len(points) - count + 1)
    return points[start:start + count]


def dress_roofs(city):
    rng = random.Random(SEED + 4)
    out = {name: [] for name in ("solar", "stairhead", "ac", "chiller", "dish", "aerial", "vent", "tile_roof")}
    for b in city.buildings:
        poly, h, style = b["poly"], b["h"], b["style"]
        area = poly.area
        if area < 30.0 or h < 2.8 or b["name"] in LANDMARKS:
            continue
        axis, length, width = long_axis(poly)
        side = np.array([-axis[1], axis[0]])
        centre = (poly.centroid.x, poly.centroid.y)
        storeys = max(1, round(h / STOREY))
        heads = []

        if b["roof"] == "tile":
            # A pitched roof over the whole house, ridge along its length.
            frame = poly.minimum_rotated_rectangle.centroid
            out["tile_roof"].append((frame.x, h, frame.y, yaw_of(axis), length + 2 * TILE_EAVES, width + 2 * TILE_EAVES))
            continue

        if style == "industrial":
            spine = poly.buffer(-2.5)
            if not spine.is_empty and length > 14.0:
                for k in range(int(length / 7.0)):
                    d = (k + 0.5) * 7.0 - length / 2.0
                    p = Point(centre[0] + axis[0] * d, centre[1] + axis[1] * d)
                    if spine.contains(p):
                        out["vent"].append((p.x, h, p.y, 0.0))
            continue

        # Stair heads: one for every entrance of a block of flats.
        if storeys >= 3 and area >= 140.0 and style != "stone":
            core = poly.buffer(-2.8)
            count = max(1, min(4, round(length / 24.0)))
            door = side if rng.random() < 0.5 else -side
            for k in range(count):
                d = ((k + 0.5) / count - 0.5) * length * 0.82
                p = Point(centre[0] + axis[0] * d, centre[1] + axis[1] * d)
                if not core.is_empty and core.contains(p):
                    heads.append((p.x, p.y))
                    out["stairhead"].append((p.x, h, p.y, yaw_of(door)))

        inner = poly.buffer(-1.5)
        if inner.is_empty:
            continue
        if heads:
            inner = inner.difference(unary_union([Point(x, z).buffer(3.6) for x, z in heads]))
            if inner.is_empty:
                continue

        if style == "modern" or b["kind"] in ("retail", "commercial", "supermarket", "school", "hospital", "office"):
            # Offices and towers: banks of condensers, and a chiller or two on the big ones.
            spots = grid_on(inner, axis, 2.3, 2.6, centre)
            wanted = max(2, min(14, int(area / 110.0)))
            for x, z, _, _ in run_of(spots, wanted, rng):
                out["ac"].append((x, h, z, yaw_of(side)))
            if area > 900.0:
                core = poly.buffer(-5.0)
                big = [s for s in grid_on(core, axis, 6.0, 6.0, centre) if all(math.dist((s[0], s[1]), (a[0], a[2])) > 4.0 for a in out["ac"][-wanted:])]
                for x, z, _, _ in run_of(big, min(3, 1 + int(area / 2500.0)), rng):
                    out["chiller"].append((x, h, z, yaw_of(axis)))
            continue

        # Homes: a solar heater for every flat, in rows, all facing south.
        flats = storeys * max(1, round(area / 95.0)) if storeys >= 2 else 1
        if style == "stone":
            flats = min(flats, 2)
        wanted = min(flats, 20)     # the long blocks carry a whole row of white tanks
        if rng.random() < 0.9:
            spots = grid_on(inner, axis, 2.5, 3.8, centre)
            for x, z, _, _ in run_of(spots, wanted, rng):
                out["solar"].append((x, h, z, SOLAR_FACING + rng.uniform(-0.12, 0.12)))
        # A dish or three near the edge, and now and then an aerial.
        rim = inner.boundary
        if not rim.is_empty and rim.length > 4.0:
            for _ in range(min(2, int(flats / 5 + rng.random() * 1.2))):
                p = rim.interpolate(rng.uniform(0, rim.length))
                out["dish"].append((p.x, h, p.y, DISH_FACING + rng.uniform(-0.1, 0.1)))
        if rng.random() < 0.3:
            if heads:
                x, z = heads[rng.randrange(len(heads))]
                out["aerial"].append((x, h + 2.6, z, rng.uniform(0, math.tau)))
            else:
                p = inner.representative_point()
                out["aerial"].append((p.x, h, p.y, rng.uniform(0, math.tau)))
    return out


# --- walls of the housing blocks: stairwells, balconies, air conditioners, laundry ----

def dress_facades(city):
    """What hangs on the walls of the housing blocks. Everything is an
    (x, y, z, yaw) item standing against the wall and facing away from it."""
    rng = random.Random(SEED + 6)
    names = ("stair_screen", "stair_entry", "wall_ac", "laundry") + BALCONY_KINDS
    out = {name: [] for name in names}
    shelters, canopies = [], []
    for index, b in enumerate(city.buildings):
        poly, h, style = b["poly"], b["h"], b["style"]
        if b["shops"] and STOREY * 1.7 < h <= CANOPY_MAX_HEIGHT and style != "industrial" and b["name"] not in LANDMARKS:
            canopies.extend(canopy_runs(city, index))
        if style != "shikun" or b["name"] in LANDMARKS or b["roof"] == "tile" or poly.area < 45.0:
            continue
        storeys = max(1, round(h / STOREY))
        is_block = storeys >= BLOCK_MIN_STOREYS and poly.area >= BLOCK_MIN_AREA
        axis, length, width = long_axis(poly)
        side = np.array([-axis[1], axis[0]])
        front = side if rng.random() < 0.5 else -side      # the side the entrances are on
        ring = list(orient(poly, 1.0).exterior.coords)

        def free(x, z, out_x, out_z):
            """Nothing else stands just in front of this piece of wall."""
            spot = Point(x + out_x * WALL_CLEARANCE, z + out_z * WALL_CLEARANCE)
            near = city.building_tree.query(spot.buffer(0.6), predicate="intersects")
            return all(i == index for i in near) and not poly.contains(spot) and not city.carriageway.contains(spot)

        for (x0, z0), (x1, z1) in zip(ring, ring[1:]):
            run = math.hypot(x1 - x0, z1 - z0)
            if run < 5.0:
                continue
            along = ((x1 - x0) / run, (z1 - z0) / run)
            outward = (along[1], -along[0])            # the ring runs anticlockwise
            yaw = yaw_of(outward)
            facing = outward[0] * front[0] + outward[1] * front[1]
            taken = []                                  # distances along this wall already in use

            def at(d):
                return x0 + along[0] * d, z0 + along[1] * d

            if is_block and facing > 0.7 and run >= 9.0:
                # The entrance side: a stairwell every so often, behind pierced blocks.
                count = max(1, round(run / STAIR_EVERY))
                for k in range(count):
                    d = (k + 0.5) / count * run
                    x, z = at(d)
                    if not free(x, z, *outward):
                        continue
                    taken.append(d)
                    out["stair_entry"].append((x, 0.0, z, yaw))
                    for floor in range(1, storeys):
                        out["stair_screen"].append((x, floor * STOREY, z, yaw))
            elif is_block and facing < -0.7 and run >= 9.0:
                # The other side: columns of balconies, each closed in differently.
                count = max(1, int(run / BALCONY_EVERY))
                for k in range(count):
                    d = (k + 0.5) / count * run
                    x, z = at(d)
                    if not free(x, z, *outward):
                        continue
                    taken.append(d)
                    for floor in range(1, storeys):
                        kind = rng.choices(BALCONY_KINDS, weights=(2, 4, 3, 2))[0]
                        out[kind].append((x, floor * STOREY, z, yaw))

            # Air conditioners and laundry in the gaps, on any wall.
            for floor in range(1 if is_block else 0, storeys):
                for _ in range(int(run / 11.0 + rng.random())):
                    d = rng.uniform(1.2, run - 1.2)
                    if any(abs(d - t) < 3.0 for t in taken):
                        continue
                    x, z = at(d)
                    if not free(x, z, *outward):
                        continue
                    if is_block and floor >= 1 and rng.random() < 0.3:
                        out["laundry"].append((x, floor * STOREY + 0.95, z, yaw))
                    else:
                        out["wall_ac"].append((x, floor * STOREY + 0.5, z, yaw))

        # A public shelter in the yard on the entrance side of some long blocks.
        if is_block and length >= 30.0 and rng.random() < SHELTER_CHANCE:
            slide = rng.uniform(-0.25, 0.25) * length
            cx = poly.centroid.x + front[0] * (width / 2.0 + SHELTER_OUT) + axis[0] * slide
            cz = poly.centroid.y + front[1] * (width / 2.0 + SHELTER_OUT) + axis[1] * slide
            room = Point(cx, cz).buffer(5.5)
            if not (city.footprints.intersects(room) or city.road_zone.intersects(room) or city.foot_zone.intersects(room)):
                shelters.append((cx, cz, yaw_of(axis)))
    return out, spread(shelters, 60.0), canopies


def canopy_runs(city, index):
    """The walls of a building of shops that have room in front for a canopy,
    as (x0, z0, x1, z1) runs along the middle of the canopy."""
    poly = city.buildings[index]["poly"]
    ring = list(orient(poly, 1.0).exterior.coords)
    runs = []
    for (x0, z0), (x1, z1) in zip(ring, ring[1:]):
        run = math.hypot(x1 - x0, z1 - z0)
        if run < 6.0:
            continue
        along = ((x1 - x0) / run, (z1 - z0) / run)
        outward = (along[1], -along[0])
        middle = Point((x0 + x1) / 2.0 + outward[0] * CANOPY_DEPTH, (z0 + z1) / 2.0 + outward[1] * CANOPY_DEPTH)
        near = city.building_tree.query(middle.buffer(1.0), predicate="intersects")
        if len(near) > 0 or city.carriageway.contains(middle):
            continue            # a courtyard wall, a neighbour or the road is in the way
        shift = (outward[0] * CANOPY_DEPTH / 2.0, outward[1] * CANOPY_DEPTH / 2.0)
        runs.append((x0 + shift[0], z0 + shift[1], x1 + shift[0], z1 + shift[1]))
    return runs


def street_trees(city):
    """A row of trees down each side of the streets in TREE_LINED, as (x, z, scale, yaw)."""
    rng = random.Random(SEED + 7)
    trees = []
    for road in city.roads:
        if not any(name in road["name"] for name in TREE_LINED) or road["roundabout"]:
            continue
        line, w = road["line"], road["w"]
        at = rng.uniform(3.0, STREET_TREE_EVERY)
        while at < line.length - 3.0:
            p, q = line.interpolate(at), line.interpolate(min(at + 1.0, line.length))
            along = np.array([q.x - p.x, q.y - p.y])
            along = along / max(float(np.hypot(*along)), 0.01)
            for way in (1.0, -1.0):
                right = np.array([-along[1], along[0]]) * way
                spot = Point(p.x + right[0] * (w / 2.0 + 1.6), p.y + right[1] * (w / 2.0 + 1.6))
                if not city.carriageway.contains(spot) and len(city.building_tree.query(spot.buffer(1.5), predicate="intersects")) == 0:
                    trees.append((spot.x, spot.y, rng.uniform(0.85, 1.25), rng.uniform(0.0, math.tau)))
            at += STREET_TREE_EVERY * rng.uniform(0.85, 1.2)
    return spread(trees, 6.0)


# --- street: dumpsters, bus stops ----------------------------------------------------

def dress_streets(city):
    rng = random.Random(SEED + 5)
    bins, stops = [], []
    against_a_wall = city.footprints.buffer(0.5)
    shapely.prepare(against_a_wall)
    for road in city.roads:
        line, w, kind = road["line"], road["w"], road["kind"]
        if road["roundabout"] or line.length < 40.0:
            continue
        # Dumpsters: at the kerb on quiet streets, well away from the corners.
        if kind in ("residential", "living_street", "tertiary"):
            at = rng.uniform(20.0, 70.0)
            while at < line.length - 18.0:
                p, q = line.interpolate(at), line.interpolate(at + 1.0)
                along = np.array([q.x - p.x, q.y - p.y])
                right = np.array([-along[1], along[0]]) * (1.0 if rng.random() < 0.5 else -1.0)
                spot = (p.x + right[0] * (w / 2.0 + 1.25), p.y + right[1] * (w / 2.0 + 1.25))
                if not city.carriageway.contains(Point(spot)) and not city.footprints.contains(Point(spot)):
                    bins.append((spot[0], spot[1], yaw_of(-right)))
                at += rng.uniform(55.0, 110.0)
        # Bus stops: on the through roads.
        if kind in ("primary", "secondary", "tertiary") and line.length > 70.0 and rng.random() < line.length / 420.0:
            at = line.length * rng.uniform(0.35, 0.65)
            p, q = line.interpolate(at), line.interpolate(at + 1.0)
            along = np.array([q.x - p.x, q.y - p.y])
            right = np.array([-along[1], along[0]])
            spot = (p.x + right[0] * (w / 2.0 + 1.75), p.y + right[1] * (w / 2.0 + 1.75))
            if not city.carriageway.contains(Point(spot)) and not against_a_wall.contains(Point(spot)):
                stops.append((spot[0], spot[1], yaw_of(-right)))
    return spread(bins, 8.0), spread(stops, 230.0)


# --- writing -------------------------------------------------------------------------

README = (
    "Where things go between the buildings; made by tools/dress_city.py, drawn by scripts/city_dressing.gd. "
    "The numbers are in dressing.bin as 32-bit floats. For each layer, 'offset' is the index of its first float. "
    "Layers with a 'stride' hold 'count' items of that many floats each; 'fields' names them. "
    "Layers with 'rings' hold that many outlines one after the other, each as its number of points followed by x, z pairs. "
    "Metres, x east, z south; yaw 0 faces south and grows towards the east."
)


def write(layers, rings):
    numbers = []
    index = {"_readme": README, "layers": {}}
    for name, (fields, items) in layers.items():
        index["layers"][name] = {"offset": len(numbers), "count": len(items), "stride": len(fields), "fields": fields}
        for item in items:
            numbers.extend(item)
    for name, outlines in rings.items():
        index["layers"][name] = {"offset": len(numbers), "rings": len(outlines)}
        for outline in outlines:
            numbers.append(float(len(outline)))
            for x, z in outline:
                numbers.extend((x, z))
        index["layers"][name]["length"] = len(numbers) - index["layers"][name]["offset"]
    OUT_NUMBERS.write_bytes(struct.pack("<%df" % len(numbers), *numbers))
    OUT_INDEX.write_text(json.dumps(index, ensure_ascii=False, indent=1), encoding="utf-8")
    return index


def preview(path, view, city, plots, walls, bushes, trees, rocks, roofs, bins, stops):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.collections import LineCollection, PolyCollection

    x0, z0, x1, z1 = view
    window = box(x0, z0, x1, z1)
    fig, ax = plt.subplots(figsize=(18, 18 * (z1 - z0) / (x1 - x0)), dpi=100)
    ax.set_facecolor("#cdb58a")
    from matplotlib.patches import PathPatch
    from matplotlib.path import Path as Outline

    def fill(poly, colour):
        """A polygon with its holes left open."""
        points, codes = [], []
        for ring in [poly.exterior, *poly.interiors]:
            coords = list(ring.coords)
            points.extend(coords)
            codes.extend([Outline.MOVETO] + [Outline.LINETO] * (len(coords) - 2) + [Outline.CLOSEPOLY])
        ax.add_patch(PathPatch(Outline(points, codes), facecolor=colour, edgecolor="none"))

    for geom, colour in ((city.road_zone, "#c9c5bd"), (city.carriageway, "#4c4c50")):
        for poly in polygons_of(shapely.clip_by_rect(geom, x0, z0, x1, z1)):
            fill(poly, colour)
    colours = {"garden": "#93a56b", "paved": "#b9b3a6", "works": "#8f8d88", "parking": "#77757a", "square": "#d48f7a"}
    for poly, kind in plots:
        if poly.intersects(window):
            fill(poly, colours[kind])
    ax.add_collection(PolyCollection([np.array(b["poly"].exterior.coords) for b in city.buildings if b["poly"].intersects(window)], facecolors="#6b4a3a", edgecolors="none"))
    for layer, colour in (("wall_low", "#f4efe2"), ("wall_stone", "#e0c9a0"), ("wall_high", "#333")):
        near = [[(a, b), (c, d)] for a, b, c, d in walls[layer] if x0 < a < x1 and z0 < b < z1]
        ax.add_collection(LineCollection(near, colors=colour, linewidths=1.6))
    scale = 18 * 100 / (x1 - x0)   # pixels per metre

    def dots(items, colour, metres, xi=0, zi=1):
        if items:
            arr = np.array(items)
            arr = arr[(arr[:, xi] > x0) & (arr[:, xi] < x1) & (arr[:, zi] > z0) & (arr[:, zi] < z1)]
            ax.scatter(arr[:, xi], arr[:, zi], s=(metres * scale * 72 / 100) ** 2, c=colour, linewidths=0)

    dots(bushes, "#3f6b2a", 1.4)
    dots(trees, "#1f4d1a", 4.5)
    dots(rocks, "#77706a", 1.0)
    dots(roofs["solar"], "#e9f0ff", 1.6, 0, 2)
    dots(roofs["stairhead"], "#d8cdb4", 3.6, 0, 2)
    dots(roofs["ac"], "#9fb7c9", 1.2, 0, 2)
    dots(roofs["chiller"], "#5c7f99", 3.0, 0, 2)
    dots(roofs["dish"], "#ffffff", 0.8, 0, 2)
    dots(roofs["vent"], "#bbbbbb", 0.9, 0, 2)
    dots(bins, "#0d7a2e", 1.6)
    dots(stops, "#ffcc00", 3.5)
    ax.set_xlim(x0, x1)
    ax.set_ylim(z1, z0)
    ax.set_aspect("equal")
    fig.savefig(path, bbox_inches="tight")


def say(*words):
    print(*words, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--preview", nargs=5, metavar=("PNG", "X0", "Z0", "X1", "Z1"))
    parser.add_argument("--dry", action="store_true", help="work everything out but write nothing")
    args = parser.parse_args()

    city = City(CITY)
    say("buildings", len(city.buildings), "roads", len(city.roads))
    plots = make_plots(city)
    say("plots", len(plots), {k: sum(1 for _, kk in plots if kk == k) for k in ("garden", "paved", "parking", "works")})
    walls = make_walls(city, plots)
    say("walls", {k: len(v) for k, v in walls.items()})
    yard_bushes, trees = plant_plots(city, plots)
    squares, square_trees, benches = make_squares(city, plots)
    say("squares", len(squares), "with trees", len(square_trees), "benches", len(benches))
    trees = trees + square_trees
    plots = plots + squares       # from here on squares count as taken land
    wild_bushes, rocks, _ = scatter_wasteland(city, plots)
    say("bushes", len(yard_bushes), "+", len(wild_bushes), "trees", len(trees), "rocks", len(rocks))
    roofs = dress_roofs(city)
    say("roofs", {k: len(v) for k, v in roofs.items()})
    facades, shelters, canopies = dress_facades(city)
    say("walls of the blocks", {k: len(v) for k, v in facades.items()}, "shelters", len(shelters), "canopies", len(canopies))
    lined = street_trees(city)
    say("street trees", len(lined))
    trees = trees + lined
    bins, stops = dress_streets(city)
    say("bins", len(bins), "bus stops", len(stops))

    if not args.dry:
        spot = ["x", "z", "scale", "yaw"]
        roof = ["x", "y", "z", "yaw"]
        layers = {
            "wall_low": (["x0", "z0", "x1", "z1"], walls["wall_low"]),
            "wall_stone": (["x0", "z0", "x1", "z1"], walls["wall_stone"]),
            "wall_high": (["x0", "z0", "x1", "z1"], walls["wall_high"]),
            "bush": (spot, yard_bushes + wild_bushes),
            "tree": (spot, trees),
            "rock": (spot, rocks),
            "bin": (["x", "z", "yaw"], bins),
            "bus_stop": (["x", "z", "yaw"], stops),
            "bench": (["x", "z", "yaw"], benches),
            "shelter": (["x", "z", "yaw"], shelters),
            "canopy": (["x0", "z0", "x1", "z1"], canopies),
        }
        layers["tile_roof"] = (["x", "y", "z", "yaw", "length", "width"], roofs["tile_roof"])
        layers.update({name: (roof, items) for name, items in roofs.items() if name != "tile_roof"})
        layers.update({name: (roof, items) for name, items in facades.items()})
        rings = {}
        for kind in ("garden", "paved", "parking", "works"):
            outlines = []
            for poly, k in plots:
                if k != kind and not (kind == "paved" and k == "square"):
                    continue
                for piece in without_holes(poly):
                    outlines.append(list(piece.exterior.coords)[:-1])
            rings["yard_" + kind] = outlines
        index = write(layers, rings)
        size = OUT_NUMBERS.stat().st_size
        say("wrote", OUT_INDEX.name, "and", OUT_NUMBERS.name, "(%.1f MB)" % (size / 1e6))

    if args.preview:
        view = tuple(float(v) for v in args.preview[1:])
        preview(args.preview[0], view, city, plots, walls, yard_bushes + wild_bushes, trees, rocks, roofs, bins, stops)
        say("preview", args.preview[0])


if __name__ == "__main__":
    sys.exit(main())
