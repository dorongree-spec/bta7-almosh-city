## What stands between and on top of the buildings: plots with their low
## walls, bushes and trees, scrub and stones on the land nobody built on,
## the clutter of the roofs (solar heaters above all), dumpsters and bus
## stops.
##
## Where everything goes was worked out offline by tools/dress_city.py and
## is read from data/dressing.json (which layers there are) and
## data/dressing.bin (the numbers). This file only draws: one small mesh
## per kind of thing, stamped with a MultiMesh per tile of town so that far
## tiles can be dropped.
##
## A yaw of 0 faces south (+z) and grows towards the east, as in the data.
class_name CityDressing
extends Node3D

const INDEX := "res://data/dressing.json"
const NUMBERS := "res://data/dressing.bin"
const TILE := 250.0            # metres; the usual size of one batch
const BIG_TILE := 1000.0       # for things there are few of
const FADE := 30.0             # metres over which a far tile fades out
const TILE_PITCH := 0.24        # height of a tiled roof for every metre of its width
const CANOPY_Y := 3.3           # under side of a shop canopy, just below the top of the shop fronts
const CANOPY_DEPTH := 2.0       # as CANOPY_DEPTH in tools/dress_city.py
const YARD_Y := 0.015          # above land-use colours (0.012), below pavements (0.02)

## Wall layers: height and thickness in metres, and what they are made of.
const WALLS := {
	# Light, like whitewashed block and Jerusalem-stone garden walls (PC: read dark brown).
	"wall_low": {"height": 0.9, "thick": 0.22, "photo": "plaster", "tint": Color(1.0, 0.98, 0.93)},
	"wall_stone": {"height": 1.05, "thick": 0.32, "photo": "stone", "tint": Color(1.0, 0.95, 0.85)},
	"wall_high": {"height": 2.1, "thick": 0.2, "photo": "plaster", "tint": Color(0.62, 0.61, 0.58)},
}

var _layers := {}                        # layer name -> its entry in the index
var _numbers := PackedFloat32Array()     # everything in dressing.bin
var _solid := PackedVector3Array()       # triangles of what can be bumped into


## Reads the data and puts everything in place. Slow (about a second); call
## it once, while the loading screen is up.
func build() -> void:
	if not _load():
		return
	_build_yards()
	_build_walls()
	_build_planting()
	_build_roofs()
	_build_facades()
	_build_street()
	_build_collision()
	_numbers = PackedFloat32Array()


func _load() -> bool:
	if not FileAccess.file_exists(INDEX) or not FileAccess.file_exists(NUMBERS):
		push_warning("City dressing data is missing; run tools/dress_city.py")
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("City dressing index is not valid JSON")
		return false
	var index: Dictionary = parsed
	_layers = index.get("layers", {})
	_numbers = FileAccess.get_file_as_bytes(NUMBERS).to_float32_array()
	return not _numbers.is_empty()


# --- materials -------------------------------------------------------------------------

## A photo material from assets/textures, world-mapped and tinted, or a flat
## colour if that set of textures is not installed.
func _photo(set_name: String, metres: float, tint: Color) -> Material:
	var photo := CityMaterials._photo(set_name, metres, tint)
	if photo != null:
		return photo
	return CityMaterials.color(tint, 0.95)


# --- the ground: plots -----------------------------------------------------------------

func _build_yards() -> void:
	# A "grass" texture set is used if somebody installs one; until then the
	# garden is the sand photo pulled towards dry green.
	var has_grass := CityMaterials._tex("grass_diff") != null
	var garden := _photo("grass", 3.0, Color(0.9, 0.9, 0.75)) if has_grass else _photo("sand", 3.0, Color(0.6, 0.66, 0.42))
	_yard("yard_garden", garden)
	_yard("yard_paved", _photo("pavers", 2.0, Color(0.86, 0.8, 0.72)))
	_yard("yard_works", _photo("asphalt", 4.0, Color(1.35, 1.32, 1.26)))
	# The car parks between the housing blocks: older, paler asphalt than the road.
	_yard("yard_parking", _photo("asphalt", 5.0, Color(1.5, 1.46, 1.38)))


## Draws the outlines of one yard layer as flat ground, a mesh per tile.
func _yard(layer_name: String, material: Material) -> void:
	var layer: Dictionary = _layers.get(layer_name, {})
	var rings := int(layer.get("rings", 0))
	var at := int(layer.get("offset", 0))
	var tiles := {}   # Vector2i -> PackedVector3Array of triangle corners
	for r in rings:
		var count := int(_numbers[at])
		var outline := PackedVector2Array()
		outline.resize(count)
		for k in count:
			outline[k] = Vector2(_numbers[at + 1 + k * 2], _numbers[at + 2 + k * 2])
		at += 1 + count * 2
		var corners := Geometry2D.triangulate_polygon(outline)
		if corners.is_empty():
			continue
		var tile := Vector2i(floori(outline[0].x / TILE), floori(outline[0].y / TILE))
		var verts: PackedVector3Array = tiles.get(tile, PackedVector3Array())
		for t in range(0, corners.size(), 3):
			var a := outline[corners[t]]
			var b := outline[corners[t + 1]]
			var c := outline[corners[t + 2]]
			if (b - a).cross(c - a) < 0.0:
				# The other way round would face down and never be seen.
				var swap := b
				b = c
				c = swap
			verts.append(Vector3(a.x, YARD_Y, a.y))
			verts.append(Vector3(b.x, YARD_Y, b.y))
			verts.append(Vector3(c.x, YARD_Y, c.y))
		tiles[tile] = verts
	for tile: Vector2i in tiles:
		var verts: PackedVector3Array = tiles[tile]
		var normals := PackedVector3Array()
		normals.resize(verts.size())
		normals.fill(Vector3.UP)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var ground := MeshInstance3D.new()
		ground.mesh = mesh
		ground.material_override = material
		ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ground)


# --- walls -----------------------------------------------------------------------------

func _build_walls() -> void:
	var block := BoxMesh.new()   # one metre each way; every wall is this, stretched
	for layer_name: String in WALLS:
		var kind: Dictionary = WALLS[layer_name]
		var height: float = kind.height
		var thick: float = kind.thick
		var place := func(at: int) -> Transform3D:
			var a := Vector3(_numbers[at], 0.0, _numbers[at + 1])
			var b := Vector3(_numbers[at + 2], 0.0, _numbers[at + 3])
			var along := b - a
			var length := maxf(along.length(), 0.01)
			var dir := along / length
			_solid_wall(a, b, height)
			var stretch := Basis(dir * length, Vector3.UP * height, dir.cross(Vector3.UP) * thick)
			return Transform3D(stretch, (a + b) * 0.5 + Vector3(0.0, height * 0.5, 0.0))
		_stamp(layer_name, block, place, 420.0, true, _photo(kind.photo, 1.6, kind.tint))


# --- planting --------------------------------------------------------------------------

func _build_planting() -> void:
	# 0.7 of the authored size: by the road they read too big and heavy (PC tuning).
	_stamp("bush", TreeMeshes.bush(), _on_ground(0.55 * 0.7, Vector3.ONE * 0.7), 240.0, true)  # the mesh carries leaf and flower materials
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.26
	trunk.height = 3.0
	trunk.radial_segments = 8
	trunk.rings = 1
	_stamp("tree", trunk, _on_ground(1.5), 420.0, false, TreeMeshes.bark_material(Color(0.4, 0.34, 0.27)))
	_stamp("tree", TreeMeshes.ficus_crown(), _on_ground(4.2), 500.0, true, TreeMeshes.leaf_material())
	var stone := SphereMesh.new()
	stone.radius = 0.5
	stone.height = 0.7
	stone.radial_segments = 7
	stone.rings = 4
	_stamp("rock", stone, _on_ground(0.12, Vector3(1.0, 0.7, 0.8)), 220.0, false, _photo("stone", 1.5, Color(0.78, 0.7, 0.58)))


# --- roofs -----------------------------------------------------------------------------

func _build_roofs() -> void:
	_stamp("solar", _solar_heater(), _on_roof(), 480.0, true)
	_stamp("stairhead", _stair_head(), _on_roof(), 900.0, true, null, 500.0)
	_stamp("ac", _condenser(), _on_roof(), 380.0, false, null, 500.0)
	_stamp("chiller", _chiller(), _on_roof(), 800.0, true, null, BIG_TILE)
	_stamp("dish", _dish(), _on_roof(), 260.0, false, null, 500.0)
	_stamp("aerial", _aerial(), _on_roof(), 220.0, false, null, 500.0)
	_stamp("vent", _vent(), _on_roof(), 400.0, false, null, BIG_TILE)
	# Pitched roofs: one wedge, stretched to the length and width of each house.
	var tile_place := func(at: int) -> Transform3D:
		var across := _numbers[at + 5]
		var rise := clampf(across * TILE_PITCH, 1.1, 2.6)
		var turn := Basis(Vector3.UP, _numbers[at + 3]) * Basis.from_scale(Vector3(across, rise, _numbers[at + 4]))
		return Transform3D(turn, Vector3(_numbers[at], _numbers[at + 1], _numbers[at + 2]))
	_stamp("tile_roof", _tile_roof(), tile_place, 700.0, true)


## The Israeli roof: a white tank on a frame over a tilted black collector.
## The collector faces the front (+z, south).
func _solar_heater() -> ArrayMesh:
	var kit := MeshKit.new()
	var white := CityMaterials.color(Color(0.92, 0.92, 0.9), 0.4)
	var steel := CityMaterials.color(Color(0.5, 0.51, 0.53), 0.45, 0.7)
	var glass := CityMaterials.color(Color(0.03, 0.06, 0.13), 0.1, 0.6)
	var tilt := Basis(Vector3.RIGHT, 0.7)
	kit.box(glass, Vector3(1.0, 0.07, 1.9), Vector3(0.0, 0.75, 0.55), tilt)
	kit.box(steel, Vector3(1.06, 0.04, 1.96), Vector3(0.0, 0.715, 0.52), tilt)
	kit.cylinder(white, 0.27, 1.25, Vector3(0.0, 1.45, -0.45), Basis(Vector3.FORWARD, PI / 2.0))
	for side: float in [-0.45, 0.45]:
		kit.box(steel, Vector3(0.05, 1.2, 0.05), Vector3(side, 0.6, -0.45))
		kit.box(steel, Vector3(0.05, 0.05, 1.8), Vector3(side, 0.03, 0.4))
	return kit.build()


## The little room where the stairs come out on the roof; door at the front.
func _stair_head() -> ArrayMesh:
	var kit := MeshKit.new()
	var plaster := _photo("plaster", 2.0, Color(0.82, 0.78, 0.7))
	var slab := CityMaterials.color(Color(0.62, 0.6, 0.56), 0.9)
	var door := CityMaterials.color(Color(0.2, 0.24, 0.3), 0.5, 0.4)
	kit.box(plaster, Vector3(3.2, 2.5, 4.4), Vector3(0.0, 1.25, 0.0))
	kit.box(slab, Vector3(3.5, 0.14, 4.7), Vector3(0.0, 2.57, 0.0))
	kit.box(door, Vector3(0.9, 2.0, 0.06), Vector3(0.6, 1.0, 2.21))
	return kit.build()


## The outdoor half of an air conditioner; fan at the front.
func _condenser() -> ArrayMesh:
	var kit := MeshKit.new()
	var shell := CityMaterials.color(Color(0.8, 0.8, 0.77), 0.6)
	var dark := CityMaterials.color(Color(0.09, 0.09, 0.1), 0.7)
	var steel := CityMaterials.color(Color(0.5, 0.51, 0.53), 0.45, 0.7)
	kit.box(shell, Vector3(0.95, 0.7, 0.38), Vector3(0.0, 0.45, 0.0))
	kit.cylinder(dark, 0.27, 0.02, Vector3(-0.12, 0.45, 0.195), Basis(Vector3.RIGHT, PI / 2.0), -1.0, 12)
	for back: float in [-0.12, 0.12]:
		kit.box(steel, Vector3(0.9, 0.1, 0.06), Vector3(0.0, 0.05, back))
	return kit.build()


## The big machine on an office roof: a louvred box with two fans on top.
func _chiller() -> ArrayMesh:
	var kit := MeshKit.new()
	var shell := CityMaterials.color(Color(0.72, 0.72, 0.68), 0.65)
	var dark := CityMaterials.color(Color(0.09, 0.09, 0.1), 0.7)
	var steel := CityMaterials.color(Color(0.5, 0.51, 0.53), 0.45, 0.7)
	kit.box(steel, Vector3(3.1, 0.15, 2.0), Vector3(0.0, 0.075, 0.0))
	kit.box(shell, Vector3(3.0, 1.7, 1.9), Vector3(0.0, 1.0, 0.0))
	kit.box(dark, Vector3(2.6, 0.6, 0.02), Vector3(0.0, 0.9, 0.96))
	for side: float in [-0.75, 0.75]:
		kit.cylinder(dark, 0.6, 0.12, Vector3(side, 1.9, 0.0), Basis.IDENTITY, -1.0, 14)
	return kit.build()


## A satellite dish on a short mast, looking up and to the front.
func _dish() -> ArrayMesh:
	var kit := MeshKit.new()
	var grey := CityMaterials.color(Color(0.82, 0.82, 0.8), 0.5)
	var steel := CityMaterials.color(Color(0.5, 0.51, 0.53), 0.45, 0.7)
	var look := Basis(Vector3.RIGHT, 1.0)
	kit.cylinder(steel, 0.025, 1.1, Vector3(0.0, 0.55, 0.0), Basis.IDENTITY, -1.0, 6)
	kit.cylinder(grey, 0.06, 0.12, Vector3(0.0, 1.1, 0.08), look, 0.42, 14)
	kit.box(steel, Vector3(0.02, 0.45, 0.02), Vector3(0.0, 1.3, 0.38), look)
	return kit.build()


## A television aerial: a mast with a comb on top.
func _aerial() -> ArrayMesh:
	var kit := MeshKit.new()
	var metal := CityMaterials.color(Color(0.36, 0.37, 0.39), 0.5, 0.6)
	kit.cylinder(metal, 0.02, 3.0, Vector3(0.0, 1.5, 0.0), Basis.IDENTITY, -1.0, 5)
	kit.box(metal, Vector3(0.03, 0.03, 1.3), Vector3(0.0, 2.9, 0.0))
	for k in 5:
		kit.box(metal, Vector3(0.7 - k * 0.08, 0.015, 0.015), Vector3(0.0, 2.9, -0.55 + k * 0.27))
	return kit.build()


## The spinning vent on a shed roof.
func _vent() -> ArrayMesh:
	var kit := MeshKit.new()
	var metal := CityMaterials.color(Color(0.6, 0.61, 0.62), 0.4, 0.8)
	kit.cylinder(metal, 0.28, 0.45, Vector3(0.0, 0.225, 0.0))
	kit.ball(metal, 0.36, Vector3(0.0, 0.62, 0.0), 0.8)
	return kit.build()


# --- the street ------------------------------------------------------------------------

## A wedge one metre each way, standing on the roof slab; ridge along z.
func _tile_roof() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.prism(CityMaterials.color(Color(0.66, 0.29, 0.2), 0.85), Vector3.ONE, Vector3(0.0, 0.5, 0.0))
	return kit.build()


# --- on the walls of the housing blocks ------------------------------------------------
#
# Every piece is made with the wall at z = 0 and sticks out towards +z, and
# stands on the floor level of its storey (y = 0).

func _build_facades() -> void:
	_stamp("stair_screen", _stair_screen(), _on_roof(), 520.0, true)
	_stamp("stair_entry", _stair_entry(), _on_roof(), 320.0, true)
	_stamp("balcony_open", _balcony("open"), _on_roof(), 380.0, true)
	_stamp("balcony_shutter", _balcony("shutter"), _on_roof(), 380.0, true)
	_stamp("balcony_glass", _balcony("glass"), _on_roof(), 380.0, true)
	_stamp("balcony_built", _balcony("built"), _on_roof(), 380.0, true)
	_stamp("wall_ac", _wall_condenser(), _on_roof(), 170.0, false, null, 125.0)
	_stamp("laundry", _laundry(), _on_roof(), 150.0, false, null, 125.0)
	var shelter_place := func(at: int) -> Transform3D:
		var spot := Vector3(_numbers[at], 0.0, _numbers[at + 1])
		_solid_box(spot, _numbers[at + 2], Vector3(4.5, 1.3, 7.0))
		return Transform3D(Basis(Vector3.UP, _numbers[at + 2]), spot)
	_stamp("shelter", _shelter(), shelter_place, 320.0, true)
	# Shop canopies: one slab, stretched along each shop front.
	var canopy_place := func(at: int) -> Transform3D:
		var a := Vector3(_numbers[at], CANOPY_Y, _numbers[at + 1])
		var b := Vector3(_numbers[at + 2], CANOPY_Y, _numbers[at + 3])
		var along := b - a
		var length := maxf(along.length(), 0.01)
		var dir := along / length
		var stretch := Basis(dir * length, Vector3.UP * 0.2, dir.cross(Vector3.UP) * CANOPY_DEPTH)
		return Transform3D(stretch, (a + b) * 0.5)
	_stamp("canopy", BoxMesh.new(), canopy_place, 420.0, true, CityMaterials.color(Color(0.74, 0.71, 0.65), 0.9))


## One storey of a stairwell: concrete posts and a screen of pierced blocks
## with the dark of the stairs behind it.
func _stair_screen() -> ArrayMesh:
	var kit := MeshKit.new()
	var concrete := CityMaterials.color(Color(0.7, 0.67, 0.61), 0.9)
	var block := CityMaterials.color(Color(0.8, 0.75, 0.65), 0.9)
	var dark := CityMaterials.color(Color(0.07, 0.07, 0.08), 0.9)
	for side: float in [-1.25, 1.25]:
		kit.box(concrete, Vector3(0.3, 3.1, 0.5), Vector3(side, 1.55, 0.25))
	kit.box(concrete, Vector3(2.8, 0.25, 0.5), Vector3(0.0, 0.125, 0.25))
	kit.box(dark, Vector3(2.2, 2.85, 0.05), Vector3(0.0, 1.675, 0.12))
	for column in 6:
		kit.box(block, Vector3(0.08, 2.85, 0.12), Vector3(-0.9 + column * 0.36, 1.675, 0.36))
	for row in 9:
		kit.box(block, Vector3(2.2, 0.08, 0.12), Vector3(0.0, 0.45 + row * 0.31, 0.36))
	return kit.build()


## The ground floor of a stairwell: an open doorway under a concrete canopy.
func _stair_entry() -> ArrayMesh:
	var kit := MeshKit.new()
	var concrete := CityMaterials.color(Color(0.7, 0.67, 0.61), 0.9)
	var dark := CityMaterials.color(Color(0.07, 0.07, 0.08), 0.9)
	var boxes := CityMaterials.color(Color(0.55, 0.56, 0.58), 0.5, 0.6)
	for side: float in [-1.25, 1.25]:
		kit.box(concrete, Vector3(0.3, 3.1, 0.5), Vector3(side, 1.55, 0.25))
	kit.box(concrete, Vector3(2.8, 0.5, 0.5), Vector3(0.0, 2.85, 0.25))
	kit.box(dark, Vector3(2.2, 2.6, 0.05), Vector3(0.0, 1.3, 0.12))
	kit.box(concrete, Vector3(3.4, 0.14, 1.7), Vector3(0.0, 2.55, 0.85))
	kit.box(concrete, Vector3(2.2, 0.15, 1.1), Vector3(0.0, 0.075, 0.55))
	kit.box(boxes, Vector3(0.7, 0.45, 0.1), Vector3(0.7, 1.35, 0.18))    # letter boxes
	return kit.build()


## A balcony and what its family did with it: left "open", closed with a
## plastic "shutter", with "glass" in brown aluminium, or "built" shut for
## another room.
func _balcony(kind: String) -> ArrayMesh:
	var kit := MeshKit.new()
	# Seen on the PC: anything brighter than the wall reads as a new white box.
	var plaster := CityMaterials.color(Color(0.74, 0.67, 0.53), 0.95)
	var slab := CityMaterials.color(Color(0.58, 0.55, 0.5), 0.9)
	var dark := CityMaterials.color(Color(0.08, 0.08, 0.1), 0.8)
	kit.box(slab, Vector3(3.3, 0.14, 1.25), Vector3(0.0, 0.07, 0.625))
	if kind == "built":
		var patch := CityMaterials.color(Color(0.8, 0.77, 0.68), 0.95)   # never quite the colour of the block
		kit.box(patch, Vector3(3.3, 2.85, 1.2), Vector3(0.0, 1.565, 0.62))
		# A wide window with its roll shutter half down, so it does not read as a blank cube.
		var shutter := CityMaterials.color(Color(0.7, 0.66, 0.57), 0.7)
		kit.box(dark, Vector3(2.3, 0.75, 0.04), Vector3(0.0, 1.45, 1.23))
		kit.box(shutter, Vector3(2.3, 0.6, 0.05), Vector3(0.0, 2.12, 1.23))
		kit.box(slab, Vector3(2.5, 0.08, 0.1), Vector3(0.0, 1.04, 1.25))
		return kit.build()
	kit.box(plaster, Vector3(3.3, 1.0, 0.1), Vector3(0.0, 0.64, 1.2))
	for side: float in [-1.6, 1.6]:
		kit.box(plaster, Vector3(0.1, 1.0, 1.2), Vector3(side, 0.64, 0.6))
	if kind == "open":
		kit.box(dark, Vector3(2.6, 2.1, 0.04), Vector3(0.0, 1.25, 0.03))     # the door into the flat
		return kit.build()
	# Closed in above the parapet: a lid, two sides and a front.
	kit.box(slab, Vector3(3.3, 0.1, 1.25), Vector3(0.0, 2.95, 0.625))
	for side: float in [-1.6, 1.6]:
		kit.box(plaster, Vector3(0.1, 1.8, 1.2), Vector3(side, 2.02, 0.6))
	if kind == "shutter":
		var plastic := CityMaterials.color(Color(0.76, 0.7, 0.58), 0.7)
		var gap := CityMaterials.color(Color(0.42, 0.38, 0.31), 0.8)
		kit.box(plastic, Vector3(3.1, 1.76, 0.05), Vector3(0.0, 2.02, 1.2))
		for slat in 7:
			kit.box(gap, Vector3(3.1, 0.02, 0.06), Vector3(0.0, 1.3 + slat * 0.24, 1.2))
	else:
		var frame := CityMaterials.color(Color(0.3, 0.2, 0.13), 0.5, 0.5)
		kit.box(CityMaterials.glass(), Vector3(3.1, 1.76, 0.03), Vector3(0.0, 2.02, 1.2))
		for bar: float in [-1.55, -0.52, 0.52, 1.55]:
			kit.box(frame, Vector3(0.07, 1.76, 0.07), Vector3(bar, 2.02, 1.2))
		for bar: float in [1.16, 2.88]:
			kit.box(frame, Vector3(3.1, 0.07, 0.07), Vector3(0.0, bar, 1.2))
	return kit.build()


## An air conditioner's outdoor half on two brackets, with its pipe down the wall.
func _wall_condenser() -> ArrayMesh:
	var kit := MeshKit.new()
	var shell := CityMaterials.color(Color(0.8, 0.8, 0.77), 0.6)
	var dark := CityMaterials.color(Color(0.09, 0.09, 0.1), 0.7)
	var steel := CityMaterials.color(Color(0.5, 0.51, 0.53), 0.45, 0.7)
	kit.box(shell, Vector3(0.85, 0.6, 0.32), Vector3(0.0, 0.34, 0.22))
	kit.cylinder(dark, 0.23, 0.02, Vector3(-0.1, 0.34, 0.385), Basis(Vector3.RIGHT, PI / 2.0), -1.0, 10)
	for side: float in [-0.3, 0.3]:
		kit.box(steel, Vector3(0.04, 0.04, 0.42), Vector3(side, 0.02, 0.21))
	kit.box(dark, Vector3(0.03, 1.1, 0.03), Vector3(0.5, -0.3, 0.03))
	return kit.build()


## A drying rack outside a window, with the week's washing on it.
func _laundry() -> ArrayMesh:
	var kit := MeshKit.new()
	var steel := CityMaterials.color(Color(0.5, 0.51, 0.53), 0.45, 0.7)
	for side: float in [-0.95, 0.95]:
		kit.box(steel, Vector3(0.03, 0.03, 0.9), Vector3(side, 0.0, 0.45))
	for line: float in [0.3, 0.55, 0.8]:
		kit.box(steel, Vector3(1.9, 0.012, 0.012), Vector3(0.0, 0.0, line))
	# Each row: colour, x, width, length of what hangs, which line.
	var washing := [
		[Color(0.85, 0.85, 0.88), -0.55, 0.7, 0.75, 0.8],
		[Color(0.75, 0.15, 0.15), 0.35, 0.4, 0.5, 0.8],
		[Color(0.15, 0.3, 0.6), -0.3, 0.45, 0.6, 0.55],
		[Color(0.9, 0.75, 0.2), 0.5, 0.35, 0.4, 0.55],
		[Color(0.1, 0.1, 0.12), 0.1, 0.5, 0.55, 0.3],
	]
	for item: Array in washing:
		var cloth := CityMaterials.color(item[0], 0.95)
		var width: float = item[2]
		var drop: float = item[3]
		kit.box(cloth, Vector3(width, drop, 0.015), Vector3(float(item[1]), -drop / 2.0, float(item[4])))
	return kit.build()


## The public shelter in the yard: a concrete mound, a stair head with a
## steel door at one end and two air pipes at the other.
func _shelter() -> ArrayMesh:
	var kit := MeshKit.new()
	var concrete := CityMaterials.color(Color(0.72, 0.69, 0.63), 0.9)
	var band := CityMaterials.color(Color(0.16, 0.5, 0.52), 0.8)
	var door := CityMaterials.color(Color(0.2, 0.3, 0.42), 0.5, 0.5)
	var steel := CityMaterials.color(Color(0.5, 0.51, 0.53), 0.45, 0.7)
	kit.box(concrete, Vector3(4.5, 1.2, 7.0), Vector3(0.0, 0.6, 0.0))
	kit.box(band, Vector3(4.53, 0.3, 7.03), Vector3(0.0, 0.85, 0.0))
	kit.box(concrete, Vector3(2.2, 2.3, 2.0), Vector3(0.0, 1.15, -2.5))
	kit.box(door, Vector3(1.0, 1.8, 0.05), Vector3(0.0, 0.95, -3.52))
	for side: float in [-1.2, 1.2]:
		kit.cylinder(steel, 0.13, 1.1, Vector3(side, 1.75, 2.2), Basis.IDENTITY, -1.0, 8)
		kit.box(steel, Vector3(0.3, 0.26, 0.5), Vector3(side, 2.3, 2.38))
	return kit.build()


func _build_street() -> void:
	var bin_place := func(at: int) -> Transform3D:
		var spot := Vector3(_numbers[at], 0.0, _numbers[at + 1])
		_solid_box(spot, _numbers[at + 2], Vector3(1.35, 1.15, 0.85))
		return Transform3D(Basis(Vector3.UP, _numbers[at + 2]), spot)
	_stamp("bin", _dumpster(), bin_place, 260.0, true, null, 500.0)
	var stop_place := func(at: int) -> Transform3D:
		var turn := Basis(Vector3.UP, _numbers[at + 2])
		var spot := Vector3(_numbers[at], 0.0, _numbers[at + 1])
		# Only the back of the shelter is solid, so people can stand in it.
		_solid_box(spot + turn * Vector3(0.0, 0.0, -0.55), _numbers[at + 2], Vector3(3.0, 2.4, 0.2))
		return Transform3D(turn, spot)
	_stamp("bus_stop", _bus_stop(), stop_place, 420.0, true, null, BIG_TILE)
	var bench_place := func(at: int) -> Transform3D:
		var spot := Vector3(_numbers[at], 0.0, _numbers[at + 1])
		_solid_box(spot, _numbers[at + 2], Vector3(1.7, 0.5, 0.5))
		return Transform3D(Basis(Vector3.UP, _numbers[at + 2]), spot)
	# Visibility is measured from the middle of a tile, so the tile must be well
	# under the view distance (500 m tiles hid benches but kept their shadows).
	_stamp("bench", _bench(), bench_place, 180.0, true, null, 60.0)


## The green dumpster at the kerb; lid opens towards the front.
func _dumpster() -> ArrayMesh:
	var kit := MeshKit.new()
	var green := CityMaterials.color(Color(0.07, 0.32, 0.14), 0.55)
	var lid := CityMaterials.color(Color(0.05, 0.22, 0.1), 0.5)
	var rubber := CityMaterials.color(Color(0.05, 0.05, 0.05), 0.9)
	kit.box(green, Vector3(1.35, 0.95, 0.85), Vector3(0.0, 0.6, 0.0))
	kit.box(lid, Vector3(1.4, 0.07, 0.9), Vector3(0.0, 1.11, 0.0))
	for side: float in [-0.55, 0.55]:
		for back: float in [-0.32, 0.32]:
			kit.cylinder(rubber, 0.09, 0.06, Vector3(side, 0.09, back), Basis(Vector3.FORWARD, PI / 2.0), -1.0, 8)
	return kit.build()


## A park bench: wooden slats on two cast legs; you sit facing the front.
func _bench() -> ArrayMesh:
	var kit := MeshKit.new()
	var wood := CityMaterials.color(Color(0.42, 0.27, 0.15), 0.75)
	var iron := CityMaterials.color(Color(0.12, 0.13, 0.14), 0.5, 0.6)
	for slat: float in [-0.14, 0.0, 0.14]:
		kit.box(wood, Vector3(1.7, 0.04, 0.11), Vector3(0.0, 0.45, slat))
	for slat: float in [0.6, 0.76]:
		kit.box(wood, Vector3(1.7, 0.11, 0.04), Vector3(0.0, slat, -0.24))
	for side: float in [-0.7, 0.7]:
		kit.box(iron, Vector3(0.06, 0.45, 0.42), Vector3(side, 0.225, 0.0))
		kit.box(iron, Vector3(0.06, 0.42, 0.05), Vector3(side, 0.64, -0.26))
	return kit.build()


## A bus shelter with its yellow sign; open towards the front (the road).
func _bus_stop() -> ArrayMesh:
	var kit := MeshKit.new()
	var steel := CityMaterials.color(Color(0.42, 0.44, 0.46), 0.5, 0.7)
	var yellow := CityMaterials.color(Color(0.98, 0.78, 0.05), 0.5)
	var seat := CityMaterials.color(Color(0.35, 0.36, 0.38), 0.6, 0.3)
	for side: float in [-1.5, 1.5]:
		kit.box(steel, Vector3(0.08, 2.4, 0.08), Vector3(side, 1.2, -0.55))
	kit.box(steel, Vector3(3.4, 0.08, 1.5), Vector3(0.0, 2.44, 0.05))
	kit.box(CityMaterials.glass(), Vector3(2.9, 1.5, 0.03), Vector3(0.0, 1.35, -0.55))
	kit.box(yellow, Vector3(3.4, 0.16, 0.04), Vector3(0.0, 2.3, 0.8))
	kit.box(seat, Vector3(2.2, 0.06, 0.4), Vector3(0.0, 0.5, -0.3))
	for side: float in [-0.9, 0.9]:
		kit.box(seat, Vector3(0.06, 0.5, 0.3), Vector3(side, 0.25, -0.3))
	kit.cylinder(steel, 0.035, 2.7, Vector3(2.1, 1.35, 0.3), Basis.IDENTITY, -1.0, 6)
	kit.box(yellow, Vector3(0.5, 0.6, 0.04), Vector3(2.1, 2.45, 0.3))
	return kit.build()


# --- where things stand ----------------------------------------------------------------

## For layers of (x, y, z, yaw): standing on a roof at height y.
func _on_roof() -> Callable:
	return func(at: int) -> Transform3D:
		return Transform3D(Basis(Vector3.UP, _numbers[at + 3]), Vector3(_numbers[at], _numbers[at + 1], _numbers[at + 2]))


## For layers of (x, z, scale, yaw): on the ground, grown by `scale`, with
## the mesh's centre `lift` metres up (before growing). `shape` squashes it.
func _on_ground(lift: float, shape := Vector3.ONE) -> Callable:
	return func(at: int) -> Transform3D:
		var grown := _numbers[at + 2]
		var turn := Basis(Vector3.UP, _numbers[at + 3]) * Basis.from_scale(shape * grown)
		return Transform3D(turn, Vector3(_numbers[at], lift * grown, _numbers[at + 1]))


# --- stamping and collision ------------------------------------------------------------

## Draws `mesh` once for every item of a layer, a MultiMesh per tile.
## `place` is given the index of an item's first number and returns where
## that item stands. Tiles further than `seen_from` metres are not drawn.
func _stamp(layer_name: String, mesh: Mesh, place: Callable, seen_from: float, shadows: bool,
		material: Material = null, tile_size := TILE) -> void:
	var layer: Dictionary = _layers.get(layer_name, {})
	var count := int(layer.get("count", 0))
	if count == 0:
		return
	var stride := int(layer.stride)
	var offset := int(layer.offset)
	var tiles := {}   # Vector2i -> Array of Transform3D
	for i in count:
		var xform: Transform3D = place.call(offset + i * stride)
		var tile := Vector2i(floori(xform.origin.x / tile_size), floori(xform.origin.z / tile_size))
		if not tiles.has(tile):
			tiles[tile] = []
		(tiles[tile] as Array).append(xform)
	for tile: Vector2i in tiles:
		var xforms: Array = tiles[tile]
		# Each batch sits at the middle of its tile, so that "how far away is
		# it" means the tile and not the middle of the map.
		var middle := Vector3((tile.x + 0.5) * tile_size, 0.0, (tile.y + 0.5) * tile_size)
		var many := MultiMesh.new()
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.mesh = mesh
		many.instance_count = xforms.size()
		for i in xforms.size():
			var xform: Transform3D = xforms[i]
			xform.origin -= middle
			many.set_instance_transform(i, xform)
		var node := MultiMeshInstance3D.new()
		node.multimesh = many
		node.position = middle
		if material != null:
			node.material_override = material
		node.visibility_range_end = seen_from
		node.visibility_range_end_margin = FADE
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


## An upright rectangle from a to b that things bump into (from either side).
func _solid_wall(a: Vector3, b: Vector3, height: float) -> void:
	var up := Vector3(0.0, height, 0.0)
	_solid.append_array(PackedVector3Array([a, b, b + up, a, b + up, a + up]))


## The four sides of a box standing on the ground at `centre`.
func _solid_box(centre: Vector3, yaw: float, size: Vector3) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var half_x := turn * Vector3(size.x * 0.5, 0.0, 0.0)
	var half_z := turn * Vector3(0.0, 0.0, size.z * 0.5)
	var corners: Array[Vector3] = [centre - half_x - half_z, centre + half_x - half_z, centre + half_x + half_z, centre - half_x + half_z]
	for i in 4:
		_solid_wall(corners[i], corners[(i + 1) % 4], size.y)


func _build_collision() -> void:
	if _solid.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_solid)
	var hull := CollisionShape3D.new()
	hull.shape = shape
	var body := StaticBody3D.new()
	body.name = "DressingCollision"
	body.add_child(hull)
	add_child(body)
	_solid = PackedVector3Array()
