#!/usr/bin/env python3
"""Checks the game's content files before they reach Godot.

Most contributions to BTA 7 Almosh City are JSON, not code: a new person who
walks up to the player, a radio station, a joke. A typo there does not crash
the game; the entry is quietly skipped or behaves oddly. This script finds
those mistakes first and says, in plain words, which file and which entry.

    python3 tools/validate_content.py          # check everything
    python3 tools/validate_content.py -q       # print errors only

Exit status is 1 if anything is wrong, so CI can run it on every pull request.
Only the Python standard library is used.

The rules mirror scripts/encounter_bank.gd, scripts/encounters.gd and
scripts/game_audio.gd. When the game learns a new trigger, outcome or kind of
person, add it to the matching set below in the same pull request.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
RADIO = ROOT / "assets" / "audio" / "radio"

# Sorts of person (the "who" field). Each has a look in EncounterBank.LOOKS,
# except "local", who gets a random one.
WHO = {
    "tenderim", "meshuparot", "ktarim", "student", "babushka",
    "soldier", "landlord", "inspector", "elder", "local",
}
WHEN = {"foot", "car", "any"}
# EncounterBank.ZONES
ZONES = {"old_city", "dalet", "tet", "campus", "center", "emek_sara"}
# Conditions checked by Encounters._holds, and events main.gd reports.
CONDITION_TRIGGERS = {
    "near", "idle", "runs_past", "drives_slow", "holds_chair", "low_money",
    "low_health", "heat_high", "night", "dust_storm", "fleeing", "thursday",
    "chased",
}
EVENT_TRIGGERS = {
    "honks", "parks", "takes_chair", "in_fight", "hits_vehicle",
    "touches_vehicle", "bumps",
}
TRIGGERS = CONDITION_TRIGGERS | EVENT_TRIGGERS
OUTCOME_KEYS = {
    "line", "money", "heat", "health", "reports", "chair", "repair",
    "take_car", "car_damage", "hold", "mood", "backup", "calm", "respect",
    "chain", "phone",
}
MOODS = {"nag", "angry", "flee"}
ENCOUNTER_KEYS = {
    "id", "who", "who_look", "name", "when", "near", "trigger", "hail",
    "lines", "offer", "yes", "no", "effects", "cooldown", "phone", "price",
}


class Report:
    """Collects problems so that one run shows all of them, not just the first."""

    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, where: str, message: str) -> None:
        self.errors.append(f"ERROR   {where}: {message}")

    def warn(self, where: str, message: str) -> None:
        self.warnings.append(f"warning {where}: {message}")


def load_json(path: Path, report: Report) -> dict | None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        report.error(path.name, f"not valid JSON (line {exc.lineno}, column {exc.colno}: {exc.msg})")
        return None
    if not isinstance(data, dict):
        report.error(path.name, "the top level must be an object { ... }")
        return None
    return data


def check_outcome(where: str, outcome: object, report: Report) -> None:
    if not isinstance(outcome, dict):
        report.error(where, "must be an object such as {\"line\": \"...\", \"money\": -20}")
        return
    for key, value in outcome.items():
        if key not in OUTCOME_KEYS:
            report.error(where, f"unknown outcome key \"{key}\" (known: {', '.join(sorted(OUTCOME_KEYS))})")
        elif key == "mood" and value not in MOODS:
            report.error(where, f"mood must be one of {sorted(MOODS)}, not {value!r}")
        elif key in {"money", "heat", "health", "reports", "hold", "backup", "respect", "car_damage"} \
                and not isinstance(value, (int, float)):
            report.error(where, f"\"{key}\" must be a number, not {value!r}")


def check_encounter(where: str, entry: object, seen_ids: dict[str, str], report: Report) -> None:
    if not isinstance(entry, dict):
        report.error(where, "each encounter must be an object")
        return
    enc_id = entry.get("id")
    if not isinstance(enc_id, str) or not enc_id:
        report.error(where, "missing \"id\" (a short unique name in English, e.g. \"melon_seller\")")
    else:
        where = f"{where} [{enc_id}]"
        if enc_id in seen_ids:
            report.error(where, f"id is already used in {seen_ids[enc_id]}")
        seen_ids[enc_id] = where
    for key in entry:
        if key not in ENCOUNTER_KEYS:
            report.warn(where, f"key \"{key}\" is not read by the game")
    who = entry.get("who")
    if who not in WHO:
        report.error(where, f"\"who\" must be one of {sorted(WHO)}, not {who!r}")
    if entry.get("when", "any") not in WHEN:
        report.error(where, f"\"when\" must be one of {sorted(WHEN)}")
    near = entry.get("near")
    if near not in (None, "") and near not in ZONES:
        report.error(where, f"\"near\" must be one of {sorted(ZONES)}, not {near!r}")
    trigger = entry.get("trigger")
    if trigger is not None and trigger not in TRIGGERS:
        report.error(where, f"\"trigger\" must be one of {sorted(TRIGGERS)}, not {trigger!r}")
    has_offer = bool(entry.get("offer"))
    if has_offer:
        for answer in ("yes", "no"):
            if entry.get(answer) is None:
                report.error(where, f"has an \"offer\" but no \"{answer}\" answer")
    elif not entry.get("lines") and not entry.get("hail"):
        report.error(where, "says nothing: give it an \"offer\", \"lines\" or a \"hail\"")
    for answer in ("yes", "no", "effects"):
        if entry.get(answer) is not None:   # null means "no such answer"
            check_outcome(f"{where}.{answer}", entry[answer], report)


def check_encounter_packs(report: Report) -> int:
    seen_ids: dict[str, str] = {}
    count = 0
    for path in sorted(DATA.glob("encounters*.json")):
        data = load_json(path, report)
        if data is None:
            continue
        encounters = data.get("encounters", [])
        if not isinstance(encounters, list):
            report.error(path.name, "\"encounters\" must be a list [ ... ]")
            continue
        for index, entry in enumerate(encounters):
            check_encounter(f"{path.name} #{index}", entry, seen_ids, report)
        count += len(encounters)
    return count


def check_world(report: Report) -> int:
    path = DATA / "world.json"
    data = load_json(path, report)
    if data is None:
        return 0
    stations = data.get("radio", [])
    seen: set[str] = set()
    for index, station in enumerate(stations):
        where = f"world.json radio #{index}"
        station_id = station.get("id")
        if not station_id:
            report.error(where, "missing \"id\"")
        elif station_id in seen:
            report.error(where, f"station id \"{station_id}\" is used twice")
        seen.add(station_id)
        if not station.get("name"):
            report.error(where, "missing \"name\" (what the screen shows when you tune in)")
        tracks = station.get("tracks", [])
        if not tracks:
            report.warn(where, "has no \"tracks\", so it stays off the dial")
        for track in tracks:
            if not (RADIO / track).is_file():
                report.error(where, f"track assets/audio/radio/{track} does not exist")
    return len(stations)


def check_other_json(report: Report) -> None:
    """Every other JSON file in data/ must at least parse."""
    for path in sorted(DATA.glob("*.json")):
        if path.name != "world.json" and not path.name.startswith("encounters"):
            load_json(path, report)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("-q", "--quiet", action="store_true", help="print errors only")
    args = parser.parse_args()

    report = Report()
    encounters = check_encounter_packs(report)
    stations = check_world(report)
    check_other_json(report)

    if not args.quiet:
        for line in report.warnings:
            print(line)
    for line in report.errors:
        print(line)
    if not args.quiet:
        print(f"\nChecked {encounters} encounters and {stations} radio stations: "
              f"{len(report.errors)} errors, {len(report.warnings)} warnings.")
    return 1 if report.errors else 0


if __name__ == "__main__":
    sys.exit(main())
