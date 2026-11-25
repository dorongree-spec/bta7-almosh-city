#!/usr/bin/env python3
"""
Convert an Overpass API JSON export ("out geom") into the compact city file
the game loads at runtime (res://data/city.json).

Output coordinates are metres in a local tangent plane: +x east, +z south
(Godot's forward is -z, so north stays "up the screen" on the minimap).

Accepts Overpass JSON ("out geom") or one or more OpenStreetMap XML exports
(.osm, e.g. several tiles saved from openstreetmap.org); tiles are merged.

Usage:
    python3 osm_to_city.py export.json city.json [--origin LAT,LON]
    python3 osm_to_city.py tile1.osm tile2.osm ... city.json [--bbox S,W,N,E]
"""
from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass, field

EARTH_R = 6_378_137.0
STOREY = 3.1

# Carriageway width (m) by OSM highway class; missing classes are skipped.
ROAD_WIDTH = {
    "motorway": 16, "trunk": 14, "primary": 13, "secondary": 11, "tertiary": 9,
    "unclassified": 7, "residential": 7, "living_street": 6, "service": 5,
    "motorway_link": 8, "trunk_link": 8, "primary_link": 8, "secondary_link": 7,
    "tertiary_link": 7, "pedestrian": 6, "footway": 2.5, "path": 2, "cycleway": 2.5,
    "steps": 2,
}
DRIVABLE = {k for k in ROAD_WIDTH if k not in {"pedestrian", "footway", "path", "cycleway", "steps"}}

# Typical heights when OSM has no levels (Beer Sheva is mostly 4-storey blocks).
DEFAULT_LEVELS = {
    "house": 2, "detached": 2, "semidetached_house": 2, "terrace": 2,
    "apartments": 4, "residential": 4, "commercial": 3, "retail": 2,
    "industrial": 2, "warehouse": 2, "school": 3, "university": 4,
    "hospital": 6, "office": 5, "garage": 1, "shed": 1, "roof": 1,
    "mosque": 2, "synagogue": 2, "yes": 3,
}

AREA_KINDS = {
    ("leisure", "park"): "park", ("leisure", "garden"): "park", ("leisure", "pitch"): "pitch",
    ("leisure", "stadium"): "pitch", ("landuse", "grass"): "park", ("landuse", "recreation_ground"): "park",
    ("landuse", "residential"): "residential", ("landuse", "commercial"): "commercial",
    ("landuse", "retail"): "commercial", ("landuse", "industrial"): "industrial",
    ("landuse", "cemetery"): "cemetery", ("landuse", "construction"): "sand", ("landuse", "brownfield"): "sand",
    ("landuse", "farmland"): "field", ("landuse", "orchard"): "field",
}


@dataclass
class Projector:
    lat0: float
    lon0: float
    kx: float = field(init=False)
    kz: float = field(init=False)

    def __post_init__(self) -> None:
        self.kx = math.radians(1) * EARTH_R * math.cos(math.radians(self.lat0))
        self.kz = math.radians(1) * EARTH_R

    def __call__(self, lat: float, lon: float) -> list[float]:
        return [round((lon - self.lon0) * self.kx, 2), round(-(lat - self.lat0) * self.kz, 2)]


def levels_of(tags: dict) -> float:
    if "height" in tags:
        try:
            return float(str(tags["height"]).split()[0]) / STOREY
        except ValueError:
            pass
    if "building:levels" in tags:
        try:
            return float(tags["building:levels"])
        except ValueError:
            pass
    return DEFAULT_LEVELS.get(tags.get("building", "yes"), 3)


def polygon_area(pts: list[list[float]]) -> float:
    a = 0.0
    for (x1, z1), (x2, z2) in zip(pts, pts[1:] + pts[:1]):
        a += x1 * z2 - x2 * z1
    return a / 2


def convert(data: dict, origin: tuple[float, float] | None) -> dict:
    elements = data.get("elements", [])
    if origin is None:
        lats = [p["lat"] for e in elements for p in e.get("geometry", [])] or [31.25]
        lons = [p["lon"] for e in elements for p in e.get("geometry", [])] or [34.79]
        origin = ((min(lats) + max(lats)) / 2, (min(lons) + max(lons)) / 2)
    proj = Projector(*origin)

    roads, buildings, areas, pois = [], [], [], []
    for e in elements:
        tags = e.get("tags", {})
        if e["type"] == "node":
            name = tags.get("name:he") or tags.get("name")
            kind = tags.get("amenity") or tags.get("shop")
            if name and kind:
                pois.append({"name": name, "kind": kind, "p": proj(e["lat"], e["lon"])})
            continue
        geom = e.get("geometry")
        if not geom or len(geom) < 2:
            continue
        pts = [proj(p["lat"], p["lon"]) for p in geom]

        if "highway" in tags and tags["highway"] in ROAD_WIDTH:
            hw = tags["highway"]
            lanes = tags.get("lanes")
            width = ROAD_WIDTH[hw]
            if lanes and lanes.isdigit() and hw in DRIVABLE:
                width = max(width, int(lanes) * 3.3)
            roads.append({
                "kind": hw,
                "drivable": hw in DRIVABLE,
                "w": width,
                "oneway": tags.get("oneway") == "yes",
                "name": tags.get("name:he") or tags.get("name", ""),
                "roundabout": tags.get("junction") == "roundabout",
                "pts": pts,
            })
            continue

        closed = pts[0] == pts[-1] and len(pts) >= 4
        if not closed:
            continue
        ring = pts[:-1]
        if polygon_area(ring) < 0:  # normalise winding to counter-clockwise
            ring.reverse()

        if "building" in tags:
            if abs(polygon_area(ring)) < 12:
                continue
            buildings.append({
                "h": round(max(1, levels_of(tags)) * STOREY, 1),
                "kind": tags.get("building", "yes"),
                "name": tags.get("name:he") or tags.get("name", ""),
                "pts": ring,
            })
            continue

        for (k, v), kind in AREA_KINDS.items():
            if tags.get(k) == v:
                areas.append({"kind": kind, "name": tags.get("name:he") or tags.get("name", ""), "pts": ring})
                break

    xs = [p[0] for r in roads for p in r["pts"]] or [0]
    zs = [p[1] for r in roads for p in r["pts"]] or [0]
    return {
        "origin": {"lat": origin[0], "lon": origin[1]},
        "bounds": [min(xs), min(zs), max(xs), max(zs)],
        "roads": roads,
        "buildings": buildings,
        "areas": areas,
        "pois": pois,
    }


def load_osm_xml(paths: list[str]) -> dict:
    """Merge OSM XML files into Overpass-style elements with inline geometry."""
    import xml.etree.ElementTree as ET

    nodes: dict[str, tuple[float, float]] = {}
    node_tags: dict[str, dict] = {}
    ways: dict[str, tuple[list[str], dict]] = {}
    relations: dict[str, tuple[list[tuple[str, str, str]], dict]] = {}
    for path in paths:
        for el in ET.parse(path).getroot():
            tags = {t.get("k"): t.get("v") for t in el.findall("tag")}
            if el.tag == "node":
                nodes[el.get("id")] = (float(el.get("lat")), float(el.get("lon")))
                if tags:
                    node_tags[el.get("id")] = tags
            elif el.tag == "way":
                ways[el.get("id")] = ([nd.get("ref") for nd in el.findall("nd")], tags)
            elif el.tag == "relation":
                members = [(m.get("type"), m.get("ref"), m.get("role")) for m in el.findall("member")]
                relations[el.get("id")] = (members, tags)

    def geometry(refs: list[str]) -> list[dict]:
        return [{"lat": nodes[r][0], "lon": nodes[r][1]} for r in refs if r in nodes]

    elements: list[dict] = []
    for nid, tags in node_tags.items():
        lat, lon = nodes[nid]
        elements.append({"type": "node", "lat": lat, "lon": lon, "tags": tags})
    for refs, tags in ways.values():
        elements.append({"type": "way", "tags": tags, "geometry": geometry(refs)})
    # Multipolygon buildings/areas: emit each closed outer ring as its own way.
    for members, tags in relations.values():
        if tags.get("type") != "multipolygon":
            continue
        for mtype, ref, role in members:
            if mtype == "way" and role == "outer" and ref in ways:
                elements.append({"type": "way", "tags": {k: v for k, v in tags.items() if k != "type"},
                                 "geometry": geometry(ways[ref][0])})
    return {"elements": elements}


def clip(data: dict, bbox: tuple[float, float, float, float]) -> dict:
    """Keep elements with at least one vertex inside S,W,N,E."""
    s, w, n, e = bbox

    def inside(p: dict) -> bool:
        return s <= p["lat"] <= n and w <= p["lon"] <= e

    kept = [el for el in data["elements"]
            if (el["type"] == "node" and inside(el)) or any(inside(p) for p in el.get("geometry", []))]
    return {"elements": kept}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+", help="input file(s) followed by the output file")
    ap.add_argument("--origin", help="LAT,LON of the world origin (default: centre of the data)")
    ap.add_argument("--bbox", help="S,W,N,E: keep only features touching this box")
    args = ap.parse_args()
    *sources, dst = args.paths
    args.dst = dst
    origin = tuple(float(v) for v in args.origin.split(",")) if args.origin else None
    if all(src.endswith(".osm") for src in sources):
        data = load_osm_xml(sources)
    else:
        with open(sources[0], encoding="utf-8") as f:
            data = json.load(f)
    if args.bbox:
        data = clip(data, tuple(float(v) for v in args.bbox.split(",")))  # type: ignore[arg-type]
    city = convert(data, origin)  # type: ignore[arg-type]
    with open(args.dst, "w", encoding="utf-8") as f:
        json.dump(city, f, ensure_ascii=False, separators=(",", ":"))
    print(f"roads={len(city['roads'])} buildings={len(city['buildings'])} "
          f"areas={len(city['areas'])} pois={len(city['pois'])} bounds={city['bounds']}")


if __name__ == "__main__":
    main()
