## The buildings people know Beer Sheva by. The map gives every building as
## an outline and a height, which is fine for a block of flats and wrong for
## a mosque. For the outlines named here the city builder draws nothing and
## this draws a model made for that building instead, fitted to the real
## outline: its middle, its long side and its size.
##
## The shapes follow published descriptions and photographs of each place
## (see docs/LANDMARKS.md); they are likenesses, not surveys.
##
## Each model is built lying along +x (the outline's long side) around its
## own middle, then turned and moved into place.
class_name Landmarks
extends Node3D

## Outline name in data/city.json -> which model stands there. With
## "keep": true the plain building stays and the model is added to it.
const SITES := {
	"בית הפירמידה": {"model": "pyramid_house"},
	"מרכז הנגב": {"model": "negev_centre"},
	"המסגד הגדול": {"model": "mosque"},
	"תחנת הרכבת הטורקית בבאר שבע": {"model": "turkish_station"},
	"מגדל המים": {"model": "water_tower"},
	"הספרייה המרכזית": {"model": "library"},
	"עיריית באר שבע": {"model": "city_hall_tower", "keep": true},
}

## Places the map has no outline for: [latitude, longitude, model].
const EXTRA := [
	[31.2664, 34.8216, "brigade_monument"],
]

## Small things on Avraham Avinu street, placed from Doron's Street View
## walk along it (November 2018 pictures): [x, z, yaw, model], in the
## game's metres. The yaw turns the model's front (+z) towards the street.
const STREET_SET := [
	[596.0, -2414.0, -0.733, "kiosk"],          # no. 3: the nuts-and-seeds kiosk, a bus shelter in front, the car park behind
	[590.0, -2386.0, -0.733, "playground"],     # no. 1: playground under a shade sail, behind green railings
	[541.0, -2611.0, 0.0, "pylon"],             # the steel pylon at the corner of David HaMelech
]

## Ha-Pina Ha-Hama, the bakery on the corner of KKL street and Derekh
## Hebron (docs/REFERENCE_PINA_HAMA.md). The map has the corner as two plain
## two-storey outlines; both are left out and one model of the old stone row
## stands on their ground. Its front (+z) faces KKL street and its +x end
## faces Derekh Hebron.
const PINA_HAMA := [428.8, 328.0, -0.71]            # x, z, yaw
const PINA_HAMA_SIZE := Vector2(20.0, 17.7)         # along KKL street, and back from it
const PINA_HAMA_WINDOW := 7.6                       # where the service window is along the front
## A point inside each plain outline that the row replaces.
const CLEARED := [Vector2(433.0, 331.7), Vector2(425.0, 324.8)]

const STOREY := 3.0

var _stone: Material
var _concrete: Material
var _plaster: Material
var _tiles: Material
var _dark: Material
var _white: Material
var _wood: Material
var _font := SystemFont.new()
var _signs: Array = []          # [text, place in the model, letter height] for the model being built
var _solid := StaticBody3D.new()


## True if this outline is drawn here and the city builder should skip it.
static func replaces(building: Dictionary) -> bool:
	var site: Dictionary = SITES.get(String(building.get("name", "")), {})
	if not site.is_empty():
		return not bool(site.get("keep", false))
	var outline: Array = building.get("pts", [])
	if outline.is_empty() or absf(float(outline[0][0]) - PINA_HAMA[0]) > 40.0 or absf(float(outline[0][1]) - PINA_HAMA[1]) > 40.0:
		return false
	var polygon := PackedVector2Array()
	for pair: Array in outline:
		polygon.append(Vector2(pair[0], pair[1]))
	for inside: Vector2 in CLEARED:
		if Geometry2D.is_point_in_polygon(inside, polygon):
			return true
	return false


## True if `point` is on the ground of the bakery row or within 3 m of its
## walls, where dressing made for the outlines it replaced would float.
static func covers(point: Vector3) -> bool:
	var local := pina_hama_place().affine_inverse() * point
	return absf(local.x) < PINA_HAMA_SIZE.x * 0.5 + 3.0 and absf(local.z) < PINA_HAMA_SIZE.y * 0.5 + 3.0


## Where the bakery row stands, for anything that needs a spot beside it.
static func pina_hama_place() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PINA_HAMA[2]), Vector3(PINA_HAMA[0], 0.0, PINA_HAMA[1]))


## Where the queue stands: on the pavement in front of the service window.
static func pina_hama_queue() -> Vector3:
	return pina_hama_place() * Vector3(PINA_HAMA_WINDOW, 0.0, PINA_HAMA_SIZE.y * 0.5 + 1.4)


func build(city: CityBuilder) -> void:
	_stone = _photo("stone", 2.4, Color(1.0, 0.93, 0.8), Color(0.84, 0.76, 0.6))
	# Plain colours: with the plaster photo both came out dark brown on the PC.
	_concrete = CityMaterials.color(Color(0.72, 0.7, 0.65), 0.92)
	_plaster = CityMaterials.color(Color(0.84, 0.78, 0.65), 0.94)
	_tiles = CityMaterials.color(Color(0.6, 0.34, 0.25), 0.85)    # muted terracotta, as in the photos
	_dark = CityMaterials.color(Color(0.05, 0.06, 0.08), 0.3, 0.2)
	_white = CityMaterials.color(Color(0.92, 0.92, 0.9), 0.6)
	_wood = CityMaterials.color(Color(0.36, 0.25, 0.16), 0.85)
	_font.font_names = PackedStringArray(["Arial", "Segoe UI", "DejaVu Sans", "Noto Sans Hebrew"])
	_solid.name = "LandmarkCollision"
	add_child(_solid)

	for building: Dictionary in city.data.get("buildings", []):
		var site: Dictionary = SITES.get(String(building.get("name", "")), {})
		if site.is_empty():
			continue
		var frame := _frame(building.pts)
		_place(String(site.model), frame.place, frame.length, frame.width, float(building.h))
	for extra: Array in EXTRA:
		var spot := Gangs.latlon_to_local(float(extra[0]), float(extra[1]))
		_place(String(extra[2]), Transform3D(Basis.IDENTITY, spot), 0.0, 0.0, 0.0)
	for item: Array in STREET_SET:
		var turn := Basis(Vector3.UP, float(item[2]))
		_place(String(item[3]), Transform3D(turn, Vector3(float(item[0]), 0.0, float(item[1]))), 0.0, 0.0, 0.0)
	_place("pina_hama", pina_hama_place(), PINA_HAMA_SIZE.x, PINA_HAMA_SIZE.y, 0.0)


## A photo material, or a flat colour where the textures are not installed.
func _photo(set_name: String, metres: float, tint: Color, fallback: Color) -> Material:
	var photo := CityMaterials._photo(set_name, metres, tint)
	return photo if photo != null else CityMaterials.color(fallback, 0.9)


## The tightest box round an outline: where its middle is, which way its
## long side runs, and both side lengths.
func _frame(outline: Array) -> Dictionary:
	var points := PackedVector2Array()
	for pair: Array in outline:
		points.append(Vector2(pair[0], pair[1]))
	var best_area := INF
	var best := {}
	for i in points.size():
		var along := (points[(i + 1) % points.size()] - points[i])
		if along.length() < 0.5:
			continue
		along = along.normalized()
		var across := Vector2(-along.y, along.x)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in points:
			var q := Vector2(p.dot(along), p.dot(across))
			lo = lo.min(q)
			hi = hi.max(q)
		var size := hi - lo
		if size.x * size.y >= best_area:
			continue
		best_area = size.x * size.y
		var middle := along * (lo.x + hi.x) * 0.5 + across * (lo.y + hi.y) * 0.5
		if size.x < size.y:
			along = across
			size = Vector2(size.y, size.x)
		# Local +x has to land on `along`: Basis(UP, yaw) sends +x to (cos, 0, -sin).
		var yaw := atan2(-along.y, along.x)
		best = {
			"place": Transform3D(Basis(Vector3.UP, yaw), Vector3(middle.x, 0.0, middle.y)),
			"length": size.x, "width": size.y,
		}
	return best


func _place(model: String, place: Transform3D, length: float, width: float, height: float) -> void:
	var kit := MeshKit.new()
	var blocks: Array[AABB] = []      # what you bump into, in the model's own space
	_signs.clear()
	match model:
		"pyramid_house":
			_terraced_rows(kit, blocks, length, width, 3, 2.4, 0.0, 5.0, _plaster, true)
		"negev_centre":
			_terraced_rows(kit, blocks, length, width, 3, 0.0, 1.3, 9.0, _concrete, false)
		"mosque":
			_mosque(kit, blocks, length, width)
		"turkish_station":
			_turkish_station(kit, blocks, length, width)
		"water_tower":
			_water_tower(kit, blocks)
		"library":
			_library(kit, blocks, length, width)
		"city_hall_tower":
			_city_hall_tower(kit, blocks, height)
		"brigade_monument":
			_brigade_monument(kit, blocks)
		"kiosk":
			_kiosk(kit, blocks)
		"playground":
			_playground(kit, blocks)
		"pylon":
			_pylon(kit, blocks)
		"pina_hama":
			_pina_hama(kit, blocks, length, width)
		_:
			push_warning("Landmarks: no model called %s" % model)
			return
	var body := MeshInstance3D.new()
	body.name = model
	body.mesh = kit.build()
	body.transform = place
	add_child(body)
	for lettering: Array in _signs:
		var label := Label3D.new()
		label.text = String(lettering[0])
		label.font = _font
		label.font_size = 160
		label.pixel_size = float(lettering[2]) / 160.0
		label.outline_size = 0
		label.modulate = Color.WHITE
		label.transform = lettering[1]
		label.visibility_range_end = 220.0
		body.add_child(label)
	for block in blocks:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = block.size
		shape.shape = box
		shape.transform = place * Transform3D(Basis.IDENTITY, block.get_center())
		_solid.add_child(shape)


## A box given by its low corner middle: stands on `y`, centred on (x, z).
func _block(kit: MeshKit, blocks: Array[AABB], material: Material, size: Vector3, x: float, y: float, z: float, solid := true) -> void:
	kit.box(material, size, Vector3(x, y + size.y * 0.5, z))
	if solid:
		blocks.append(AABB(Vector3(x - size.x * 0.5, y, z - size.z * 0.5), size))


# --- the stepped housing of the sixties ------------------------------------------------

## Two rows facing each other across a narrow shaded street, with bridges
## and beams over it and open stairs standing in it. Two buildings in town
## are made this way:
##   the "Pyramid" in Shchuna Dalet (Lufenfeld and Gamerman, about 1970):
##     each floor set back by `step` on the outside, so every flat has a
##     terrace and the whole reads as a stepped pyramid;
##   the Negev Centre (Ram Karmi, about 1960), in raw concrete: shops on
##     the street, offices, then flats, each floor reaching `lean` further
##     out over the inner street, so the section widens towards the top.
func _terraced_rows(kit: MeshKit, blocks: Array[AABB], length: float, width: float, floors: int,
		step: float, lean: float, street: float, wall: Material, canopies: bool) -> void:
	var half := width * 0.5
	var bay := 7.2
	var bays := maxi(2, int(length / bay))
	bay = length / bays
	for side: float in [-1.0, 1.0]:
		for floor_no in floors:
			var outer := half - floor_no * step
			var inner := maxf(street * 0.5 - floor_no * lean, 1.6)
			var depth := outer - inner
			if depth < 2.5:
				break
			var y := floor_no * STOREY
			var z := side * (inner + depth * 0.5)
			_block(kit, blocks, wall, Vector3(length, STOREY - 0.25, depth), 0.0, y, z)
			# The concrete skeleton shows: a slab edge over every floor...
			kit.box(_concrete, Vector3(length + 0.4, 0.25, depth + 0.5), Vector3(0.0, y + STOREY - 0.125, z))
			# ...the wall of the terrace above...
			kit.box(_concrete, Vector3(length, 0.9, 0.16), Vector3(0.0, y + STOREY + 0.45, side * (outer - 0.08)))
			for b in bays + 1:
				# ...and a fin between every two flats.
				var x := -length * 0.5 + b * bay
				kit.box(_concrete, Vector3(0.28, STOREY, depth + 0.7), Vector3(x, y + STOREY * 0.5, z))
			for b in bays:
				var x := -length * 0.5 + (b + 0.5) * bay
				# Outwards: a terrace door and a small window. Inwards: a slit.
				kit.box(_dark, Vector3(1.5, 2.0, 0.1), Vector3(x - 1.2, y + 1.1, side * (outer + 0.01)))
				kit.box(_dark, Vector3(1.1, 1.0, 0.1), Vector3(x + 1.6, y + 1.6, side * (outer + 0.01)))
				kit.box(_dark, Vector3(2.6 if floor_no == 0 and lean > 0.0 else 0.7, 2.2 if floor_no == 0 and lean > 0.0 else 1.2, 0.1),
						Vector3(x, y + 1.5, side * (inner - 0.01)))
				# The Pyramid: a wooden pergola over most terraces (they are what
				# gives the real building its bands of shade).
				if canopies and step > 0.0 and floor_no >= 1 and (b + floor_no) % 3 != 0:
					_pergola(kit, Vector3(x, y, side * (outer + step * 0.5)), bay - 1.6, step - 0.3)
	var top := floors * STOREY
	for b in bays:
		var x := -length * 0.5 + (b + 0.5) * bay
		# Beams over the inner street, and a bridge on every other bay.
		kit.box(_concrete, Vector3(0.35, 0.55, street + 0.6), Vector3(x + bay * 0.5, top - 0.3, 0.0))
		if b % 2 == 1:
			for floor_no in range(1, floors):
				kit.box(_concrete, Vector3(1.6, 0.22, street), Vector3(x, floor_no * STOREY, 0.0))
				for edge: float in [-0.75, 0.75]:
					kit.box(_concrete, Vector3(0.1, 0.9, street), Vector3(x + edge, floor_no * STOREY + 0.55, 0.0))
	# Three open stairs in the street, each under its own swept-up canopy.
	for third: float in [-1.0, 0.0, 1.0]:
		var x := third * length / 3.0
		for floor_no in floors - 1:
			var y := floor_no * STOREY
			var tilt := Basis(Vector3.FORWARD, 0.52 * (1.0 if floor_no % 2 == 0 else -1.0))
			kit.box(_concrete, Vector3(STOREY * 2.0, 0.2, 1.1), Vector3(x, y + STOREY * 0.5, 0.0), tilt)
		_block(kit, blocks, _concrete, Vector3(0.25, top, 1.4), x - 3.0, 0.0, 0.0)
		_block(kit, blocks, _concrete, Vector3(0.25, top, 1.4), x + 3.0, 0.0, 0.0)
		if canopies:
			for wing: float in [-1.0, 1.0]:
				kit.box(_concrete, Vector3(3.4, 0.16, street + 1.5), Vector3(x + wing * 1.6, top + 1.0, 0.0), Basis(Vector3.FORWARD, wing * 0.28))


## A wooden pergola standing on a terrace: `centre` is the middle of its
## floor, `along` its length (x) and `across` its depth (z).
func _pergola(kit: MeshKit, centre: Vector3, along: float, across: float) -> void:
	var wood := _wood    # one material for all of them, so they stay one surface
	var height := 2.25
	for end: float in [-0.5, 0.5]:
		for edge: float in [-0.5, 0.5]:
			kit.box(wood, Vector3(0.1, height, 0.1), centre + Vector3(end * along, height * 0.5, edge * across))
	var slats := maxi(3, int(along / 0.6))
	for slat in slats + 1:
		var x := -along * 0.5 + along * slat / slats
		kit.box(wood, Vector3(0.07, 0.12, across + 0.5), centre + Vector3(x, height + 0.06, 0.0))


# --- Avraham Avinu street ---------------------------------------------------------------

## The kiosk by the car park: a low white box with a red-and-white striped
## band, a counter open to the street under an awning, a big black sign on
## the roof, racks outside, and the bus shelter in front of it.
func _kiosk(kit: MeshKit, blocks: Array[AABB]) -> void:
	var red := CityMaterials.color(Color(0.75, 0.12, 0.12), 0.6)
	var sign_black := CityMaterials.color(Color(0.06, 0.06, 0.07), 0.5)
	var sign_pink := CityMaterials.color(Color(0.9, 0.35, 0.6), 0.5)
	var steel := CityMaterials.color(Color(0.5, 0.51, 0.53), 0.45, 0.7)
	_block(kit, blocks, _white, Vector3(9.0, 2.7, 3.6), 0.0, 0.0, 0.0)
	kit.box(_white, Vector3(9.6, 0.16, 5.4), Vector3(0.0, 2.78, 0.6))               # roof slab, reaching out over the counter
	kit.box(_dark, Vector3(5.2, 1.3, 0.1), Vector3(-1.2, 1.75, 1.81))               # the counter opening
	kit.box(steel, Vector3(5.4, 0.08, 0.5), Vector3(-1.2, 1.08, 2.0))               # the counter
	for stripe in 9:
		kit.box(red if stripe % 2 == 0 else _white, Vector3(1.0, 0.45, 0.06), Vector3(-4.0 + stripe * 1.0, 2.45, 1.84))
	kit.box(sign_black, Vector3(6.4, 1.3, 0.14), Vector3(0.6, 3.6, 1.2))            # the roof sign
	kit.box(sign_pink, Vector3(3.6, 0.5, 0.16), Vector3(1.4, 3.6, 1.2))
	kit.box(_white, Vector3(1.0, 1.0, 0.16), Vector3(-1.9, 3.6, 1.2))
	for post: float in [-2.6, 3.8]:
		kit.box(steel, Vector3(0.08, 0.7, 0.08), Vector3(post, 3.0, 1.2))
	for rack in 3:                                                                   # crates and racks by the door
		_block(kit, blocks, sign_black if rack == 1 else red, Vector3(0.9, 1.5, 0.5), 2.6 + rack * 1.0, 0.0, 2.3)
	# The bus shelter, two steps towards the kerb.
	var glass := CityMaterials.glass()
	for post: float in [-1.6, 1.6]:
		kit.box(steel, Vector3(0.08, 2.4, 0.08), Vector3(post - 1.0, 1.2, 6.6))
	kit.box(red, Vector3(3.8, 0.1, 1.6), Vector3(-1.0, 2.45, 7.2))
	kit.box(glass, Vector3(3.2, 1.6, 0.04), Vector3(-1.0, 1.3, 6.6))
	kit.box(steel, Vector3(2.6, 0.06, 0.4), Vector3(-1.0, 0.5, 6.9))
	blocks.append(AABB(Vector3(-2.7, 0.0, 6.5), Vector3(3.4, 2.4, 0.2)))


## The little playground at the bottom of the street: red rubber ground, a
## sand-coloured shade sail on four posts, a slide and swings, and the
## green railing all round with a gap for the gate.
func _playground(kit: MeshKit, blocks: Array[AABB]) -> void:
	var rubber := CityMaterials.color(Color(0.62, 0.25, 0.2), 0.95)
	var sail := CityMaterials.color(Color(0.78, 0.7, 0.58), 0.9)
	var green := CityMaterials.color(Color(0.1, 0.42, 0.3), 0.6, 0.3)
	var steel := CityMaterials.color(Color(0.5, 0.51, 0.53), 0.45, 0.7)
	var yellow := CityMaterials.color(Color(0.95, 0.75, 0.1), 0.6)
	var blue := CityMaterials.color(Color(0.15, 0.35, 0.7), 0.6)
	var half := Vector2(8.0, 6.0)
	kit.box(rubber, Vector3(half.x * 2.0, 0.04, half.y * 2.0), Vector3(0.0, 0.03, 0.0))
	# Shade sail: four posts of uneven height and a tilted sheet between them.
	for corner: Vector2 in [Vector2(-5.0, -4.0), Vector2(5.0, -4.0), Vector2(5.0, 4.0), Vector2(-5.0, 4.0)]:
		var tall := 4.6 if corner.y < 0.0 else 3.6
		_block(kit, blocks, steel, Vector3(0.16, tall, 0.16), corner.x, 0.0, corner.y)
	kit.box(sail, Vector3(10.0, 0.05, 8.1), Vector3(0.0, 4.05, 0.0), Basis(Vector3.RIGHT, -0.124))
	# Slide: a tower, a platform and the chute.
	_block(kit, blocks, blue, Vector3(1.2, 1.6, 1.2), -2.5, 0.0, 0.0)
	kit.box(yellow, Vector3(0.7, 0.08, 3.0), Vector3(-2.5, 0.85, 1.9), Basis(Vector3.RIGHT, 0.5))
	# Swings: a frame and two seats.
	for end: float in [1.2, 4.2]:
		kit.box(steel, Vector3(0.1, 2.3, 0.1), Vector3(end, 1.15, 0.5))
	kit.box(steel, Vector3(3.1, 0.1, 0.1), Vector3(2.7, 2.3, 0.5))
	for seat: float in [2.1, 3.3]:
		kit.box(yellow, Vector3(0.45, 0.05, 0.25), Vector3(seat, 0.55, 0.5))
		for chain: float in [-0.2, 0.2]:
			kit.box(steel, Vector3(0.02, 1.75, 0.02), Vector3(seat + chain, 1.42, 0.5))
	# The railing: a top and a bottom rail and uprights, gate gap at the front.
	for side: float in [-1.0, 1.0]:
		_rail(kit, green, Vector3(-half.x, 0.0, side * half.y), Vector3(-1.2 if side > 0.0 else half.x, 0.0, side * half.y))
		if side > 0.0:
			_rail(kit, green, Vector3(1.2, 0.0, half.y), Vector3(half.x, 0.0, half.y))
		_rail(kit, green, Vector3(side * half.x, 0.0, -half.y), Vector3(side * half.x, 0.0, half.y))
	blocks.append(AABB(Vector3(-half.x, 0.0, -half.y - 0.1), Vector3(half.x * 2.0, 1.1, 0.2)))
	for side: float in [-1.0, 1.0]:
		blocks.append(AABB(Vector3(side * half.x - 0.1, 0.0, -half.y), Vector3(0.2, 1.1, half.y * 2.0)))


## A run of the green street railing from a to b (along x or along z).
func _rail(kit: MeshKit, paint: Material, a: Vector3, b: Vector3) -> void:
	var run := b - a
	var length := run.length()
	if length < 0.2:
		return
	var along_x := absf(run.x) > absf(run.z)
	var middle := (a + b) * 0.5
	for height: float in [0.35, 1.05]:
		kit.box(paint, Vector3(length, 0.05, 0.05) if along_x else Vector3(0.05, 0.05, length), middle + Vector3(0.0, height, 0.0))
	var posts := maxi(1, int(length / 0.5))
	for post in posts + 1:
		kit.box(paint, Vector3(0.03, 1.05, 0.03), a + run * (float(post) / posts) + Vector3(0.0, 0.525, 0.0))


## The steel lattice pylon at the corner of David HaMelech: four legs
## leaning in, rings of bracing, two cross arms and a transformer.
func _pylon(kit: MeshKit, blocks: Array[AABB]) -> void:
	var steel := CityMaterials.color(Color(0.55, 0.56, 0.57), 0.5, 0.6)
	var tall := 13.0
	var foot := 1.1                    # half the width at the ground
	var head := 0.35                   # half the width at the top
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var lean := Basis(Vector3.RIGHT, z * atan((foot - head) / tall) * -1.0) * Basis(Vector3.FORWARD, x * atan((foot - head) / tall) * -1.0)
			kit.box(steel, Vector3(0.09, tall, 0.09), Vector3(x * (foot + head) * 0.5, tall * 0.5, z * (foot + head) * 0.5), lean)
	for ring in 7:
		var y := 1.0 + ring * 1.9
		var half := lerpf(foot, head, y / tall)
		for side: float in [-1.0, 1.0]:
			kit.box(steel, Vector3(half * 2.0, 0.05, 0.05), Vector3(0.0, y, side * half))
			kit.box(steel, Vector3(0.05, 0.05, half * 2.0), Vector3(side * half, y, 0.0))
			kit.box(steel, Vector3(half * 2.6, 0.04, 0.04), Vector3(0.0, y + 0.95, side * half), Basis(Vector3.FORWARD, 0.75 * side))
	for arm: float in [11.0, 12.4]:
		kit.box(steel, Vector3(3.4, 0.1, 0.1), Vector3(0.0, arm, 0.0))
		for cup: float in [-1.5, -0.8, 0.8, 1.5]:
			kit.cylinder(_dark, 0.06, 0.3, Vector3(cup, arm + 0.2, 0.0), Basis.IDENTITY, -1.0, 6)
	kit.box(steel, Vector3(0.9, 1.1, 0.7), Vector3(0.0, 8.6, 0.0))                   # the transformer
	blocks.append(AABB(Vector3(-foot, 0.0, -foot), Vector3(foot * 2.0, tall, foot * 2.0)))


# --- the corner of KKL street and Derekh Hebron -----------------------------------------

## Ha-Pina Ha-Hama: a single-storey row of old sandstone with arched
## doorways and painted metal doors, a tiled lean-to over the pavement, and
## at the Derekh Hebron end the bakery itself: a wide service window under
## a striped awning and a big red sign on the roof. Along KKL street, past
## the row, a poinciana and a black-framed seating enclosure with clear
## plastic sides.
func _pina_hama(kit: MeshKit, blocks: Array[AABB], length: float, depth: float) -> void:
	var blue := CityMaterials.color(Color(0.2, 0.45, 0.7), 0.55, 0.3)
	var pink := CityMaterials.color(Color(0.85, 0.45, 0.6), 0.55, 0.3)
	var red := CityMaterials.color(Color(0.78, 0.1, 0.1), 0.55)
	var steel := CityMaterials.color(Color(0.5, 0.51, 0.53), 0.45, 0.7)
	var black := CityMaterials.color(Color(0.07, 0.07, 0.08), 0.5, 0.4)
	var half := length * 0.5
	var front := depth * 0.5
	var tall := 4.2                                  # one high Ottoman storey

	_block(kit, blocks, _stone, Vector3(length, tall, depth), 0.0, 0.0, 0.0)
	kit.box(_stone, Vector3(length + 0.3, 0.3, depth + 0.3), Vector3(0.0, tall + 0.15, 0.0))        # the cornice

	# Four arched doorways along KKL street, each with its own painted door
	# and an air conditioner over it.
	var doors: Array[Material] = [blue, pink, blue, pink]
	for bay in doors.size():
		var x := -half + 2.2 + bay * 3.6
		_arch(kit, x, 0.0, front, 2.2, 2.3, 1.0)
		kit.box(doors[bay], Vector3(1.9, 2.2, 0.06), Vector3(x, 1.1, front + 0.1))
		kit.box(_white, Vector3(0.8, 0.3, 0.3), Vector3(x + 1.5, 3.7, front + 0.15))
	# The tiled lean-to over them, on thin steel posts.
	var lean_to := 3.6 * doors.size()
	var lean_x := -half + lean_to * 0.5 + 0.3
	kit.box(_tiles, Vector3(lean_to, 0.1, 2.5), Vector3(lean_x, 3.05, front + 1.15), Basis(Vector3.RIGHT, 0.3))
	for post in doors.size() + 1:
		kit.box(steel, Vector3(0.07, 2.7, 0.07), Vector3(lean_x - lean_to * 0.5 + post * 3.6, 1.35, front + 2.25))

	# The bakery on the corner: the service window and its counter...
	var window := PINA_HAMA_WINDOW
	kit.box(_dark, Vector3(3.8, 1.4, 0.1), Vector3(window, 1.8, front + 0.02))
	kit.box(steel, Vector3(4.0, 0.08, 0.6), Vector3(window, 1.08, front + 0.3))
	kit.box(_white, Vector3(4.2, 0.5, 0.08), Vector3(window, 2.85, front + 0.05))               # the price board
	# ...a second window round the corner, towards Derekh Hebron...
	kit.box(_dark, Vector3(0.1, 1.4, 3.0), Vector3(half + 0.02, 1.8, front - 2.4))
	kit.box(steel, Vector3(0.5, 0.08, 3.2), Vector3(half + 0.25, 1.08, front - 2.4))
	for arched in 3:
		kit.box(_dark, Vector3(0.1, 2.0, 1.2), Vector3(half + 0.02, 1.9, front - 6.5 - arched * 3.4))
	# ...and a red-and-white striped awning over both.
	for stripe in 8:
		var paint: Material = red if stripe % 2 == 0 else _white
		kit.box(paint, Vector3(0.55, 0.06, 1.5), Vector3(window - 1.93 + stripe * 0.55, 3.2, front + 0.7), Basis(Vector3.RIGHT, 0.35))
		if stripe < 6:
			kit.box(paint, Vector3(1.5, 0.06, 0.55), Vector3(half + 0.7, 3.2, front - 1.0 - stripe * 0.55), Basis(Vector3.FORWARD, 0.35))

	# The roof sign, turned to face the junction. Our own lettering: the
	# real one shares its frame with a soft-drink advert, which stays out.
	var board := Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(half - 4.2, tall + 2.0, front - 4.2))
	kit.box(red, Vector3(7.0, 2.2, 0.2), board.origin, board.basis)
	kit.box(_white, Vector3(7.3, 0.12, 0.24), board.origin + Vector3(0.0, 1.16, 0.0), board.basis)
	kit.box(_white, Vector3(7.3, 0.12, 0.24), board.origin + Vector3(0.0, -1.16, 0.0), board.basis)
	for leg: float in [-2.8, 2.8]:
		kit.box(steel, Vector3(0.1, 1.0, 0.1), board * Vector3(leg, -1.6, 0.0))
	_signs.append(["הפינה החמה", board * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.15, 0.12)), 1.1])
	_signs.append(["סמבוסק · בורקס · פתוח 24 שעות", board * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.72, 0.12)), 0.36])

	# What collects on such a roof: dishes, a water tank, a solar panel.
	for dish: float in [-6.5, -1.0]:
		kit.box(steel, Vector3(0.06, 0.9, 0.06), Vector3(dish, tall + 0.6, front - 1.2))
		kit.cylinder(_white, 0.45, 0.05, Vector3(dish, tall + 1.1, front - 1.05), Basis(Vector3.RIGHT, 1.1), -1.0, 12)
	kit.cylinder(_white, 0.45, 1.3, Vector3(-3.5, tall + 1.25, 0.0), Basis(Vector3.FORWARD, PI / 2.0))
	kit.box(steel, Vector3(1.6, 0.6, 0.9), Vector3(-3.5, tall + 0.3, 0.0))
	kit.box(_dark, Vector3(1.8, 0.06, 1.1), Vector3(-3.5, tall + 0.5, 1.2), Basis(Vector3.RIGHT, 0.6))

	# Up KKL street from the row: the poinciana, wide and flat, in flower...
	var bark := CityMaterials.color(Color(0.33, 0.27, 0.21), 0.95)
	var leaves := CityMaterials.color(Color(0.2, 0.42, 0.16), 0.9)
	var flowers := CityMaterials.color(Color(0.85, 0.22, 0.1), 0.85)
	var tree := Vector3(-half - 3.5, 0.0, front + 1.6)
	kit.cylinder(bark, 0.3, 3.4, tree + Vector3(0.0, 1.7, 0.0), Basis.IDENTITY, 0.22)
	blocks.append(AABB(tree + Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 3.4, 0.6)))
	kit.ball(leaves, 4.6, tree + Vector3(0.0, 4.8, 0.0), 0.4, 12)
	kit.ball(leaves, 3.0, tree + Vector3(2.2, 5.3, -1.0), 0.45, 10)
	# Flowers in clumps over the crown, not one patch.
	for clump in 7:
		var turn := clump * 2.4
		var r := 1.2 + (clump % 3) * 1.1
		kit.ball(flowers, 1.0 + (clump % 2) * 0.4, tree + Vector3(cos(turn) * r, 6.1 + (clump % 2) * 0.3, sin(turn) * r * 0.8), 0.45, 8)

	# ...and a seating enclosure: a black frame with clear plastic sheets.
	var glass := CityMaterials.glass()
	var seat_len := 8.0
	var seat_deep := 2.6
	var seat := Vector3(-half - 12.5, 0.0, front + 0.3 + seat_deep * 0.5)
	for end: float in [-0.5, 0.0, 0.5]:
		for edge: float in [-0.5, 0.5]:
			kit.box(black, Vector3(0.1, 2.6, 0.1), seat + Vector3(end * seat_len, 1.3, edge * seat_deep))
	kit.box(black, Vector3(seat_len + 0.2, 0.12, seat_deep + 0.2), seat + Vector3(0.0, 2.66, 0.0))
	kit.box(glass, Vector3(seat_len, 2.0, 0.03), seat + Vector3(0.0, 1.3, seat_deep * 0.5))
	blocks.append(AABB(seat + Vector3(-seat_len * 0.5, 0.0, seat_deep * 0.5 - 0.1), Vector3(seat_len, 2.6, 0.2)))
	kit.box(glass, Vector3(0.03, 2.0, seat_deep), seat + Vector3(-seat_len * 0.5, 1.3, 0.0))
	blocks.append(AABB(seat + Vector3(-seat_len * 0.5 - 0.1, 0.0, -seat_deep * 0.5), Vector3(0.2, 2.6, seat_deep)))
	for table: float in [-2.6, 0.0, 2.6]:
		kit.cylinder(_white, 0.4, 0.04, seat + Vector3(table, 0.75, 0.0), Basis.IDENTITY, -1.0, 12)
		kit.box(black, Vector3(0.06, 0.75, 0.06), seat + Vector3(table, 0.375, 0.0))


# --- the Ottoman town ------------------------------------------------------------------

## A tall arched opening on a wall that faces along z (`facing` = +1 or -1).
func _arch(kit: MeshKit, x: float, y: float, z: float, wide: float, tall: float, facing: float) -> void:
	kit.box(_dark, Vector3(wide, tall, 0.12), Vector3(x, y + tall * 0.5, z + facing * 0.02))
	kit.cylinder(_dark, wide * 0.5, 0.12, Vector3(x, y + tall, z + facing * 0.02), Basis(Vector3.RIGHT, PI / 2.0), -1.0, 16)


## The Great Mosque (1906): a plain stone hall, one dome on a low drum, an
## arcade across the front and a slender minaret with one balcony.
func _mosque(kit: MeshKit, blocks: Array[AABB], length: float, width: float) -> void:
	var hall_h := 8.0
	_block(kit, blocks, _stone, Vector3(length, hall_h, width), 0.0, 0.0, 0.0)
	kit.box(_stone, Vector3(length + 0.5, 0.45, width + 0.5), Vector3(0.0, hall_h + 0.2, 0.0))
	var arches := maxi(3, int(length / 4.0))
	for i in arches:
		var x := -length * 0.5 + (i + 0.5) * length / arches
		for facing: float in [-1.0, 1.0]:
			_arch(kit, x, 1.2, facing * width * 0.5, 1.5, 3.4, facing)
	var dome_r := minf(length, width) * 0.27
	kit.cylinder(_stone, dome_r, 1.8, Vector3(0.0, hall_h + 1.3, 0.0), Basis.IDENTITY, -1.0, 16)
	kit.ball(_white, dome_r, Vector3(0.0, hall_h + 2.2, 0.0), 0.95, 20)
	kit.cylinder(_dark, 0.06, 1.6, Vector3(0.0, hall_h + 2.2 + dome_r + 0.6, 0.0), Basis.IDENTITY, -1.0, 6)
	# The minaret at one corner.
	var mx := length * 0.5 - 1.6
	var mz := width * 0.5 - 1.6
	_block(kit, blocks, _stone, Vector3(3.0, hall_h + 2.0, 3.0), mx, 0.0, mz)
	kit.cylinder(_stone, 0.95, 10.0, Vector3(mx, hall_h + 7.0, mz), Basis.IDENTITY, -1.0, 8)
	kit.cylinder(_stone, 1.75, 0.35, Vector3(mx, hall_h + 12.0, mz), Basis.IDENTITY, 1.4, 8)
	kit.cylinder(_stone, 1.7, 0.9, Vector3(mx, hall_h + 12.6, mz), Basis.IDENTITY, -1.0, 8)
	kit.cylinder(_stone, 0.75, 3.2, Vector3(mx, hall_h + 14.6, mz), Basis.IDENTITY, -1.0, 8)
	kit.cylinder(_white, 0.95, 2.8, Vector3(mx, hall_h + 17.6, mz), Basis.IDENTITY, 0.0, 8)


## The Turkish railway station (1915): a two-storey stone house with a red
## tiled roof between two low wings, long side to the tracks.
func _turkish_station(kit: MeshKit, blocks: Array[AABB], length: float, width: float) -> void:
	var middle := length * 0.4
	var wing := (length - middle) * 0.5
	_block(kit, blocks, _stone, Vector3(middle, 8.0, width), 0.0, 0.0, 0.0)
	kit.prism(_tiles, Vector3(width + 1.2, 2.6, middle + 1.2), Vector3(0.0, 9.3, 0.0), Basis(Vector3.UP, PI / 2.0))
	for side: float in [-1.0, 1.0]:
		var x := side * (middle + wing) * 0.5
		_block(kit, blocks, _stone, Vector3(wing, 4.6, width * 0.86), x, 0.0, 0.0)
		kit.prism(_tiles, Vector3(width * 0.86 + 1.0, 2.0, wing + 0.6), Vector3(x, 5.6, 0.0), Basis(Vector3.UP, PI / 2.0))
	for facing: float in [-1.0, 1.0]:
		for i in 3:
			var x := (i - 1) * middle / 3.0
			_arch(kit, x, 0.0 if i == 1 else 1.0, facing * width * 0.5, 1.3, 2.6 if i == 1 else 1.9, facing)
			_arch(kit, x, 4.7, facing * width * 0.5, 1.1, 1.7, facing)
		for side: float in [-1.0, 1.0]:
			for i in 2:
				_arch(kit, side * (middle * 0.5 + (i + 0.5) * wing * 0.5), 1.0, facing * width * 0.43, 1.2, 1.8, facing)


## The station's stone water tower: a square shaft with the tank room
## standing proud of it under a little tiled roof.
func _water_tower(kit: MeshKit, blocks: Array[AABB]) -> void:
	_block(kit, blocks, _stone, Vector3(4.2, 9.0, 4.2), 0.0, 0.0, 0.0)
	kit.box(_stone, Vector3(5.4, 3.4, 5.4), Vector3(0.0, 10.7, 0.0))
	kit.cylinder(_tiles, 4.0, 1.8, Vector3(0.0, 13.3, 0.0), Basis(Vector3.UP, PI / 4.0), 0.0, 4)
	for facing: float in [-1.0, 1.0]:
		_arch(kit, 0.0, 0.0 if facing > 0.0 else 4.0, facing * 2.1, 1.1, 2.2 if facing > 0.0 else 1.4, facing)
		kit.box(_dark, Vector3(1.6, 0.8, 0.1), Vector3(0.0, 10.9, facing * 2.72))


# --- concrete Beer Sheva ---------------------------------------------------------------

## The university's central library: a concrete base, a wider windowless
## box of reading rooms on top, and on its roof row after row of skylight
## hoods all looking north, which is how everyone draws it.
func _library(kit: MeshKit, blocks: Array[AABB], length: float, width: float) -> void:
	_block(kit, blocks, _concrete, Vector3(length - 4.0, 6.0, width - 4.0), 0.0, 0.0, 0.0)
	kit.box(_dark, Vector3(length - 3.9, 2.4, width - 3.9), Vector3(0.0, 4.4, 0.0))
	kit.box(_white, Vector3(length, 10.0, width), Vector3(0.0, 11.0, 0.0))
	for slit in 2:
		kit.box(_dark, Vector3(length + 0.1, 0.5, width + 0.1), Vector3(0.0, 8.6 + slit * 4.4, 0.0))
	var roof := 16.0
	var pitch := 3.4
	var rows := int((width - 3.0) / pitch)
	var columns := int((length - 3.0) / pitch)
	for row in rows:
		for column in columns:
			var x := (column - (columns - 1) * 0.5) * pitch
			var z := (row - (rows - 1) * 0.5) * pitch
			kit.box(_white, Vector3(2.2, 1.0, 2.2), Vector3(x, roof + 0.5, z))
			kit.prism(_white, Vector3(2.2, 1.3, 2.2), Vector3(x, roof + 1.65, z), Basis(Vector3.UP, PI / 2.0))
			kit.box(_dark, Vector3(1.6, 0.8, 0.06), Vector3(x, roof + 1.5, z - 0.6), Basis(Vector3.RIGHT, -0.86))


## The tower that stands over the city hall: a bare concrete shaft with
## deep vertical fins, opening into a frame at the top.
func _city_hall_tower(kit: MeshKit, blocks: Array[AABB], base: float) -> void:
	var tall := 52.0
	_block(kit, blocks, _concrete, Vector3(7.0, tall, 7.0), 0.0, base, 0.0, false)
	blocks.append(AABB(Vector3(-3.5, 0.0, -3.5), Vector3(7.0, base + tall, 7.0)))
	for corner_x: float in [-1.0, 1.0]:
		for corner_z: float in [-1.0, 1.0]:
			kit.box(_concrete, Vector3(1.2, tall + 8.0, 1.2), Vector3(corner_x * 3.6, base + (tall + 8.0) * 0.5, corner_z * 3.6))
	for face in 4:
		var turn := Basis(Vector3.UP, face * PI / 2.0)
		for fin: float in [-1.4, 0.0, 1.4]:
			kit.box(_concrete, Vector3(0.3, tall - 2.0, 0.5), turn * Vector3(fin, 0.0, 3.7) + Vector3(0.0, base + tall * 0.5, 0.0), turn)
			kit.box(_dark, Vector3(0.9, tall - 6.0, 0.08), turn * Vector3(fin + 0.7, 0.0, 3.52) + Vector3(0.0, base + tall * 0.5, 0.0), turn)
	kit.box(_concrete, Vector3(9.0, 0.8, 9.0), Vector3(0.0, base + tall + 8.0, 0.0))


## The Negev Brigade monument on its hill north-east of town (Dani Karavan,
## 1960s): bare concrete shapes you walk through. Here: the pierced tower,
## the split dome, the long pipe and the slanted walls, on a low mound.
func _brigade_monument(kit: MeshKit, blocks: Array[AABB]) -> void:
	var sand := _photo("sand", 4.0, Color(0.95, 0.88, 0.72), Color(0.8, 0.7, 0.5))
	var ground := 2.4
	kit.cylinder(sand, 60.0, ground, Vector3(0.0, ground * 0.5, 0.0), Basis.IDENTITY, 34.0, 28)
	blocks.append(AABB(Vector3(-34.0, 0.0, -34.0), Vector3(68.0, ground, 68.0)))
	# The tower, with its rows of round holes.
	_block(kit, blocks, _concrete, Vector3(4.0, 20.0, 4.0), -16.0, ground, -6.0)
	for level in 6:
		for facing: float in [-1.0, 1.0]:
			kit.cylinder(_dark, 0.55, 0.1, Vector3(-16.0, ground + 3.0 + level * 2.8, -6.0 + facing * 2.02), Basis(Vector3.RIGHT, PI / 2.0), -1.0, 12)
			kit.cylinder(_dark, 0.55, 0.1, Vector3(-16.0 + facing * 2.02, ground + 3.0 + level * 2.8, -6.0), Basis(Vector3.FORWARD, PI / 2.0), -1.0, 12)
	# The dome, cut in two by a walkway.
	for half: float in [-1.0, 1.0]:
		kit.ball(_concrete, 8.0, Vector3(4.0 + half * 0.9, ground, 6.0), 0.85, 20)
	kit.box(_dark, Vector3(0.5, 7.2, 16.4), Vector3(4.0, ground + 3.4, 6.0))
	blocks.append(AABB(Vector3(-4.0, ground, -2.0), Vector3(16.0, 6.5, 16.0)))
	# The pipe you can walk through.
	kit.cylinder(_concrete, 1.9, 24.0, Vector3(10.0, ground + 1.9, -14.0), Basis(Vector3.FORWARD, PI / 2.0), -1.0, 18)
	kit.cylinder(_dark, 1.6, 24.1, Vector3(10.0, ground + 1.9, -14.0), Basis(Vector3.FORWARD, PI / 2.0), -1.0, 18)
	blocks.append(AABB(Vector3(-2.0, ground, -15.9), Vector3(24.0, 3.8, 3.8)))
	# Slanted walls, like tents and like trenches.
	for wall in 4:
		var x := -22.0 + wall * 4.5
		kit.box(_concrete, Vector3(0.5, 6.0, 12.0), Vector3(x, ground + 2.4, 14.0), Basis(Vector3.BACK, 0.45 * (1.0 if wall % 2 == 0 else -1.0)))
	_block(kit, blocks, _concrete, Vector3(14.0, 1.2, 3.0), 18.0, ground, 14.0)
