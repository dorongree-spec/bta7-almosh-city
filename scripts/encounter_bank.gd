## The content behind Encounters: who can walk up to the player, what they
## say, and what a yes or a no costs. Read from every file in FILES (the same
## format in each; see the "_readme" at the top of data/encounters.json), so
## that new people are added by editing JSON and never by touching code.
##
## Every encounter is normalised to a "deal" dictionary with all keys present:
##   id, who, look, name, when ("foot" / "car" / "any"), near (zone or ""),
##   trigger, hail, lines (said before the question), offer ("" = no question),
##   yes, no (outcome of each answer), effects (outcome when there is no
##   question), cooldown (seconds), price (what a yes costs, 0 if nothing),
##   phone (true = a call, nobody shows up).
## An outcome is a dictionary of: line, money, heat, health, reports, chair,
## repair, take_car, car_damage, hold, mood, backup, calm, respect, chain.
##
## A file may also carry "flavor": for a sort of person, a "chance" and lists
## of "prefix" and "suffix" (their slang). Once everything is loaded, that
## share of their greetings and answers gets one of each stuck on, so the
## slang reaches every encounter without rewriting any. Encounters from the
## file that brings the flavor are left alone; they are written in it already.
class_name EncounterBank
extends RefCounted

## The built-in packs, loaded first and in this order. Any other file called
## data/encounters_*.json is picked up after them, in name order, so a new
## pack of people is added by dropping a file in; no code changes needed.
const FILES := ["res://data/encounters.json", "res://data/encounters_research.json", "res://data/encounters_slang.json",
	"res://data/encounters_tv.json"]
const DATA_DIR := "res://data/"
const DEFAULT_COOLDOWN := 150.0

## Triggers that only fire when the game reports the player's action; the
## scheduler never picks these on its own.
const EVENT_TRIGGERS := ["honks", "parks", "takes_chair", "in_fight", "hits_vehicle", "touches_vehicle", "bumps"]

## Named parts of town: [latitude, longitude, radius in metres].
const ZONES := {
	"old_city": [31.2400, 34.7895, 600.0],
	"dalet": [31.2645, 34.7938, 750.0],     # round Avraham Avinu street
	"tet": [31.2490, 34.8120, 700.0],
	"campus": [31.2622, 34.8013, 600.0],
	"center": [31.2432, 34.7975, 500.0],
	"emek_sara": [31.2335, 34.7990, 700.0],
}

## What each part of town is called on screen.
const ZONE_NAMES := {
	"old_city": "העיר העתיקה",
	"dalet": "שכונה ד'",
	"tet": "שכונה ט'",
	"campus": "האוניברסיטה וסורוקה",
	"center": "מרכז העיר",
	"emek_sara": "עמק שרה",
}

const GREY := Color(0.78, 0.78, 0.78)

## How each sort of person dresses. Missing keys fall back to a random look.
const LOOKS := {
	"tenderim": {"shirt": Color(0.95, 0.95, 0.95), "pants": Color(0.18, 0.31, 0.5), "prop": "keffiyeh", "long_hair": false},
	"meshuparot": {"shirt": Color(1.0, 0.18, 0.58), "pants": Color(0.1, 0.1, 0.1), "prop": "logo", "long_hair": false},
	"ktarim": {"shirt": Color(0.07, 0.07, 0.07), "pants": Color(0.07, 0.07, 0.07), "prop": "tracksuit4", "long_hair": false},
	"student": {"shirt": Color(0.42, 0.56, 0.14), "pants": Color(0.18, 0.31, 0.31), "prop": "backpack"},
	"babushka": {"shirt": Color(0.55, 0.2, 0.45), "pants": Color(0.25, 0.2, 0.3), "hair": GREY, "long_hair": true, "height": 0.86, "girth": 1.2},
	"soldier": {"shirt": Color(0.33, 0.38, 0.2), "pants": Color(0.33, 0.38, 0.2), "prop": "kitbag", "long_hair": false},
	"landlord": {"shirt": Color(0.85, 0.8, 0.65), "pants": Color(0.36, 0.25, 0.22), "hair": GREY, "girth": 1.18, "long_hair": false},
	"inspector": {"shirt": Color(0.96, 0.82, 0.2), "pants": Color(0.12, 0.14, 0.2), "prop": "vest", "long_hair": false},
	"elder": {"hair": GREY, "height": 0.92, "long_hair": false},
}

var deals: Array[Dictionary] = []

var _reactions := {}   # kind -> Array of lines
var _flavors := {}     # who -> {chance, prefix, suffix}
var _plain: Array[Dictionary] = []   # deals that may still get slang added
var _tempers := {}     # who -> {hit_line, hit}
var _zones := {}       # zone name -> [Vector2 centre (x, z), radius]


func load_all() -> void:
	for zone: String in ZONES:
		var spec: Array = ZONES[zone]
		var centre := Gangs.latlon_to_local(float(spec[0]), float(spec[1]))
		_zones[zone] = [Vector2(centre.x, centre.z), float(spec[2])]
	for path: String in pack_files():
		_load_file(path)
	_add_slang()


## FILES, then every other data/encounters_*.json in name order.
static func pack_files() -> Array[String]:
	var paths: Array[String] = []
	paths.assign(FILES)
	var extra: Array[String] = []
	for file in DirAccess.get_files_at(DATA_DIR):
		var path := DATA_DIR + file
		if file.begins_with("encounters_") and file.get_extension() == "json" and not paths.has(path):
			extra.append(path)
	extra.sort()
	paths.append_array(extra)
	return paths


func _load_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("EncounterBank: %s is missing" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("EncounterBank: %s is not valid JSON" % path)
		return
	var data: Dictionary = parsed
	var flavors: Dictionary = _dict(data.get("flavor"))
	for who: String in flavors:
		_flavors[who] = flavors[who]
	for entry: Variant in data.get("encounters", []):
		if entry is Dictionary:
			var deal := _normalise(entry)
			deals.append(deal)
			if flavors.is_empty():
				_plain.append(deal)
	var tempers: Dictionary = data.get("tempers", {})
	for who: String in tempers:
		_tempers[who] = tempers[who]
	var reactions: Dictionary = data.get("reactions", {})
	for kind: String in reactions:
		var lines: Array = _reactions.get(kind, [])
		lines.append_array(reactions[kind] as Array)
		_reactions[kind] = lines


## Sprinkles each sort of person's slang over their greetings and answers.
func _add_slang() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for deal: Dictionary in _plain:
		var flavor: Dictionary = _dict(_flavors.get(deal.who))
		if flavor.is_empty():
			continue
		deal.hail = _with_slang(String(deal.hail), flavor, rng)
		for answer: String in ["yes", "no", "effects"]:
			var outcome: Dictionary = deal[answer]
			if outcome.has("line"):
				outcome["line"] = _with_slang(String(outcome["line"]), flavor, rng)
	_plain.clear()


## One line with, by the flavor's chance, an opening word, a closing word or
## both. An opening the line already starts with is not said twice.
static func _with_slang(line: String, flavor: Dictionary, rng: RandomNumberGenerator) -> String:
	if line == "" or rng.randf() >= float(flavor.get("chance", 0.0)):
		return line
	var prefixes: Array = flavor.get("prefix", [])
	var suffixes: Array = flavor.get("suffix", [])
	var roll := rng.randf()      # 40% opening only, 40% closing only, 20% both
	if roll < 0.6 and not prefixes.is_empty():
		var opening := String(prefixes[rng.randi() % prefixes.size()])
		if not line.begins_with(opening.strip_edges().trim_suffix(",")):
			line = opening + line
	if roll >= 0.4 and not suffixes.is_empty():
		var closing := String(suffixes[rng.randi() % suffixes.size()])
		# "…מחר." + " חמסה חמסה." reads as one sentence with a comma.
		if line.ends_with("."):
			line = line.trim_suffix(".") + ","
		line += closing
	return line


## Statement-only encounters (galina, mom_*) carry "yes": null in the JSON.
static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


## Fills in every key, so the rest of the game never has to ask "is it there?".
func _normalise(entry: Dictionary) -> Dictionary:
	var yes := _dict(entry.get("yes"))
	var cost := -int(yes.get("money", 0))
	return {
		"id": String(entry.get("id", "deal_%d" % deals.size())),
		"who": String(entry.get("who", "local")),
		"look": String(entry.get("who_look", "")),
		"name": String(entry.get("name", "")),
		"when": String(entry.get("when", "any")),
		"near": String(entry.get("near", "")),
		"trigger": String(entry.get("trigger", "near")),
		"hail": String(entry.get("hail", "")),
		"lines": entry.get("lines", []),
		"offer": String(entry.get("offer", "")),
		"yes": yes,
		"no": _dict(entry.get("no")),
		"effects": _dict(entry.get("effects")),
		"cooldown": float(entry.get("cooldown", DEFAULT_COOLDOWN)),
		"price": maxi(cost, 0),
		"phone": bool(entry.get("phone", false)),
	}


## True if `pos` is inside the named part of town ("" = anywhere).
func in_zone(near: String, pos: Vector3) -> bool:
	if near == "" or not _zones.has(near):
		return true
	var zone: Array = _zones[near]
	var centre: Vector2 = zone[0]
	return centre.distance_to(Vector2(pos.x, pos.z)) <= float(zone[1])


## The name of the part of town `pos` is in ("" between neighbourhoods).
## Where two overlap, the one whose centre is nearer wins.
func zone_name_at(pos: Vector3) -> String:
	var here := Vector2(pos.x, pos.z)
	var best := ""
	var best_d := INF
	for zone: String in _zones:
		var spec: Array = _zones[zone]
		var centre: Vector2 = spec[0]
		var d := centre.distance_to(here)
		if d <= float(spec[1]) and d < best_d:
			best_d = d
			best = zone
	return String(ZONE_NAMES.get(best, ""))


## A full Humanoid look for a sort of person ("tenderim", "babushka"...),
## with an optional variation on top of it ("elder").
func look(who: String, variation: String, rng: RandomNumberGenerator) -> Dictionary:
	var result := Humanoid.random_look(rng)
	for key: String in [who, variation]:
		var fixed: Dictionary = LOOKS.get(key, {})
		for part: String in fixed:
			result[part] = fixed[part]
	return result


## Everything a passer-by might say about `kind` ("horn", "punch", "park"...).
func reactions(kind: String) -> Array:
	return _reactions.get(kind, [])


func one_reaction(kind: String, rng: RandomNumberGenerator) -> String:
	var lines := reactions(kind)
	if lines.is_empty():
		return ""
	return String(lines[rng.randi() % lines.size()])


## How this sort of person takes a punch: an outcome with its own line.
func hit_response(who: String, _rng: RandomNumberGenerator) -> Dictionary:
	var temper: Dictionary = _tempers.get(who, _tempers.get("local", {}))
	var answer: Dictionary = (temper.get("hit", {}) as Dictionary).duplicate()
	answer["line"] = String(temper.get("hit_line", ""))
	return answer


## Seconds a subtitle needs to stay up to be read comfortably.
static func reading_time(line: String) -> float:
	return clampf(1.4 + line.length() * 0.055, 2.2, 6.5)
