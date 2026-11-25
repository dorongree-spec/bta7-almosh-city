## Builds the playable city from res://data/city.json (produced by
## tools/osm_to_city.py from real OpenStreetMap data): extruded building
## footprints, road ribbons with pavements, parks and sand lots, plus one
## static collision body. Geometry is split into square tiles so the
## renderer can cull what the camera does not see.
class_name CityBuilder
extends Node3D

const TILE := 250.0
const STOREY := 3.1
const BAY := 4.0
const PAVEMENT_EXTRA := 5.0
const SHOP_HEIGHT := 3.4
const PARAPET := 0.9             # height of the low wall round a flat roof
const NO_UV := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
## The Ottoman grid around KKL street, in local metres (x east, y south).
const OLD_CITY := Rect2(-200, -440, 1060, 1000)
## Gav-Yam hi-tech park and the north railway station (PC, by lat/lon).
const HITECH := Rect2(2050, -2850, 500, 450)
## Neighbourhoods built from the eighties on (Ramot, Neve Ze'ev): stone-clad,
## not plastered sixties shikun (PC, by lat/lon).
const NEWER_AREAS := [Rect2(1200, -5000, 2700, 1800), Rect2(-2700, 600, 1500, 1150)]
const SHOP_KINDS := ["retail", "commercial", "kiosk", "supermarket"]
const SHED_KINDS := ["industrial", "warehouse", "service", "roof", "hangar"]

## Road classes in draw order (wider/major roads on top at junctions).
const ROAD_LAYER := {
	"footway": 0, "path": 0, "cycleway": 0, "steps": 0, "pedestrian": 1,
	"service": 2, "living_street": 2, "residential": 3, "unclassified": 3,
	"tertiary": 4, "tertiary_link": 4, "secondary": 5, "secondary_link": 5,
	"primary": 6, "primary_link": 6, "trunk": 7, "trunk_link": 7, "motorway": 8, "motorway_link": 8,
}

const AREA_COLORS := {
	"park": Color(0.5, 0.52, 0.3), "pitch": Color(0.4, 0.52, 0.26),  # dry Negev lawn, not English green (PC, from photos)
	# Flat ground takes the full sun; above ~0.6 it clips to white on screen
	# (tuned on the PC; was sand 0.84, residential 0.74, commercial 0.72).
	"cemetery": Color(0.55, 0.55, 0.45), "sand": Color(0.7, 0.58, 0.41),
	"field": Color(0.6, 0.57, 0.36), "residential": Color(0.58, 0.54, 0.47),
	"commercial": Color(0.56, 0.53, 0.48), "industrial": Color(0.52, 0.5, 0.46),
}

## Beer Sheva palette: sun-bleached plaster, Jerusalem-ish stone, grey concrete.
## Beer Sheva walls (PC tuning, the old all-sand set read as one brown): mostly
## white and pale-grey plaster, some cream and pale-yellow or peach render,
## blue-grey paint and raw concrete. Multiplied with the painted facade.
const WALL_COLORS := [
	Color(0.98, 0.97, 0.94), Color(0.97, 0.96, 0.93), Color(0.9, 0.9, 0.88),
	Color(0.84, 0.84, 0.82), Color(0.97, 0.92, 0.8), Color(0.99, 0.91, 0.7),
	Color(0.97, 0.84, 0.72), Color(0.84, 0.88, 0.92), Color(0.7, 0.7, 0.68),
	Color(0.95, 0.94, 0.9),
]

var data: Dictionary = {}
## Drivable road polylines (Array of PackedVector2Array), used by traffic AI.
var drive_paths: Array = []
## Names of drivable roads, aligned with drive_paths.
var drive_names: PackedStringArray = []
## Carriageway width in metres for each entry of drive_paths.
var drive_widths: PackedFloat32Array = []
var bounds := Rect2()

var _tiles := {}
var _rng := RandomNumberGenerator.new()
var _collision_faces := PackedVector3Array()


func build(path: String) -> void:
	_rng.seed = 0xBEE5
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("City data missing or invalid: %s" % path)
		return
	data = parsed
	var b: Array = data.get("bounds", [-1000, -1000, 1000, 1000])
	bounds = Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1])

	for area in data.get("areas", []):
		_add_area(area)
	var roads: Array = data.get("roads", [])
	roads.sort_custom(func(a, b2): return ROAD_LAYER.get(a.kind, 0) < ROAD_LAYER.get(b2.kind, 0))
	for road in roads:
		_add_road(road)
	for building in data.get("buildings", []):
		_add_building(building)

	_commit_tiles()
	_add_ground()
	_add_collision()


# --- tiles -------------------------------------------------------------------

## One SurfaceTool per (tile, material) pair.
func _surface(at: Vector2, material_key: String) -> SurfaceTool:
	var key := "%d,%d,%s" % [floori(at.x / TILE), floori(at.y / TILE), material_key]
	if not _tiles.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tiles[key] = st
	return _tiles[key]


func _commit_tiles() -> void:
	var materials := {
		"wall_shikun": Facades.material("shikun"),
		"wall_shikun_b": Facades.material("shikun_b"),
		"wall_shikun_c": Facades.material("shikun_c"),
		"wall_modern_b": Facades.material("modern_b"),
		"wall_office": Facades.material("office"),
		"wall_shop_b": Facades.material("shop_b"),
		"wall_shop_c": Facades.material("shop_c"),
		"wall_mall": Facades.material("mall"),
		"wall_stone": Facades.material("stone"),
		"wall_modern": Facades.material("modern"),
		"wall_industrial": Facades.material("industrial"),
		"wall_shop": Facades.material("shop"),
		"roof": CityMaterials.roof(),
		"road": CityMaterials.asphalt(true),
		"lane": CityMaterials.asphalt(false),
		"walk": CityMaterials.pavement(),
		"walk_old": CityMaterials.pavement_old_city(),
		"area": CityMaterials.vertex_colored(),
	}
	for key in _tiles:
		var st: SurfaceTool = _tiles[key]
		var mat_key: String = key.get_slice(",", 2)
		st.set_material(materials[mat_key])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if mat_key.begins_with("wall") or mat_key == "roof" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_tiles.clear()


# --- buildings ----------------------------------------------------------------

## Which painted front a building gets, from what OSM knows about it.
func _facade_style(b: Dictionary, center: Vector2) -> String:
	var kind := String(b.get("kind", "yes"))
	var h: float = b.h
	if kind in SHED_KINDS:
		return "industrial"
	# The hi-tech park by the railway: glass and stone offices, not flats.
	if HITECH.has_point(center) and h > 8.0:
		return "office"
	# Offices, courts, the hospital and the university: stone with strip windows.
	if kind in ["office", "government", "university", "hospital", "public", "civic"]:
		return "office"
	# Malls are stone boxes with a band of glass, not blocks of flats (PC, photos).
	if kind in ["retail", "mall", "supermarket"] or String(b.get("name", "")).contains("קניון"):
		return "mall"
	if h >= 20.0:
		return "modern"
	if h >= 6.0:
		for area: Rect2 in NEWER_AREAS:
			if area.has_point(center):
				return "modern"
	if OLD_CITY.has_point(center) and h <= 10.0:
		return "stone"
	return "shikun"


func _add_building(b: Dictionary) -> void:
	var pts := _to_v2(b.pts)
	if pts.size() < 3 or Landmarks.replaces(b):
		return    # a landmark has its own model (scripts/landmarks.gd)
	var h: float = b.h
	var center := _centroid(pts)
	var style := _facade_style(b, center)
	var color: Color = WALL_COLORS[_rng.randi() % WALL_COLORS.size()]
	if style == "stone":
		color = Color(0.93, 0.84, 0.66).lerp(color, 0.3)
	# Shops at street level: on retail buildings, and on about a third of
	# the Old City and housing blocks, where the ground floor is a makolet.
	var has_shops: bool = h > SHOP_HEIGHT + 2.0 and style != "industrial" and (
		String(b.get("kind", "")) in SHOP_KINDS or b.has("shops") or _rng.randf() < (0.45 if style == "stone" else 0.12))
	# Three painted variants of the housing block and two of the tower, picked by
	# place, so one street is not forty copies of the same 8 m of wall (PC).
	var variant := ""
	var pick := absi(hash(Vector2i(roundi(center.x), roundi(center.y)))) % 3
	if style == "shikun":
		variant = ["", "_b", "_c"][pick]
	elif style == "modern" and pick > 0:
		variant = "_b"
	var walls := _surface(center, "wall_" + style + variant)
	var shops: SurfaceTool = _surface(center, "wall_shop" + ["", "_b", "_c"][pick]) if has_shops else null
	var base := SHOP_HEIGHT if has_shops else 0.0
	# A house with a tiled roof has no wall round it; CityDressing draws the tiles.
	var tiled := String(b.get("roof", "")) == "tile"
	var parapet := PARAPET if style != "industrial" and h > 5.0 and not tiled else 0.0
	var trim: SurfaceTool = _surface(center, "area") if parapet > 0.0 else null
	var trim_color := color.lightened(0.1)
	var roof_color := color.darkened(0.25)
	var perimeter := 0.0
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var c := pts[(i + 1) % n]
		var edge := c - a
		var length := edge.length()
		if length < 0.05:
			continue
		# Outward normal for a counter-clockwise ring in (x, z).
		var nrm := Vector3(edge.y, 0, -edge.x).normalized()
		# One texture tile is two bays wide and two storeys tall.
		var u0 := perimeter / (BAY * 2.0)
		var u1 := (perimeter + length) / (BAY * 2.0)
		var v1 := (h - base) / (STOREY * 2.0)
		var p0 := Vector3(a.x, 0, a.y)
		var p1 := Vector3(c.x, 0, c.y)
		var p2 := Vector3(c.x, h, c.y)
		var p3 := Vector3(a.x, h, a.y)
		var q0 := Vector3(a.x, base, a.y)
		var q1 := Vector3(c.x, base, c.y)
		# _quad wants its corners anticlockwise as seen from the front. Seen
		# from the street, `c` is on the left and `a` on the right, so the
		# order is c, a at the bottom and a, c at the top. (Listed the other
		# way round, every wall in town faced into its own building and was
		# see-through from outside.) U runs backwards along the ring so the
		# painted front is not mirrored.
		_quad(walls, [q1, q0, p3, p2], nrm, [Vector2(-u1, v1), Vector2(-u0, v1), Vector2(-u0, 0), Vector2(-u1, 0)], color)
		if shops != null:
			_quad(shops, [p1, p0, q0, q1], nrm, [Vector2(-u1, 1), Vector2(-u0, 1), Vector2(-u0, 0), Vector2(-u1, 0)], Color.WHITE)
		if parapet > 0.0:
			# A low wall round the roof: its outer face carries on up from the
			# street wall, its inner face is what you see from above.
			var r0 := Vector3(a.x, h + parapet, a.y)
			var r1 := Vector3(c.x, h + parapet, c.y)
			_quad(trim, [p2, p3, r0, r1], nrm, NO_UV, trim_color)
			_quad(trim, [p3, p2, r1, r0], -nrm, NO_UV, roof_color)
		_collision_faces.append_array([p0, p1, p2, p0, p2, p3])
		perimeter += length

	var roof := _surface(center, "roof")
	var idx := Geometry2D.triangulate_polygon(pts)
	for k in range(0, idx.size(), 3):
		for p in _up_facing(pts[idx[k]], pts[idx[k + 1]], pts[idx[k + 2]]):
			roof.set_color(roof_color)
			roof.set_normal(Vector3.UP)
			roof.set_uv(p / 4.0)
			roof.add_vertex(Vector3(p.x, h, p.y))
	# What stands on the roof (solar heaters, stair heads) is CityDressing's job.


# --- roads ----------------------------------------------------------------------

func _add_road(r: Dictionary) -> void:
	var pts := _to_v2(r.pts)
	if pts.size() < 2:
		return
	var w: float = r.w
	var layer: int = ROAD_LAYER.get(r.kind, 0)
	# Old City pavements are the red-pink pavers of Keren Kayemet street (PC, photos).
	var walk := "walk_old" if OLD_CITY.grow(-120.0).has_point(pts[0]) and OLD_CITY.grow(-120.0).has_point(pts[pts.size() - 1]) and w < 9.0 else "walk"
	if r.drivable:
		drive_paths.append(pts)
		drive_names.append(r.get("name", ""))
		drive_widths.append(w)
		# Pavement first (wider, lower), then the carriageway on top.
		_ribbon(pts, w + PAVEMENT_EXTRA, 0.02 + layer * 0.002, walk, 0.0)
		_ribbon(pts, w, 0.06 + layer * 0.004, "road" if w >= 9 else "lane", 8.0)
	else:
		_ribbon(pts, w, 0.03, walk, 0.0)


## Extrudes a polyline sideways into a flat strip. UV.x runs across (0..1),
## UV.y along the road in units of `dash` metres (0 = tile by world size).
func _ribbon(pts: PackedVector2Array, width: float, y: float, mat: String, dash: float) -> void:
	var half := width * 0.5
	var along := 0.0
	var st := _surface(pts[0], mat)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := b - a
		var len := seg.length()
		if len < 0.01:
			continue
		var na := _miter(pts, i, half)
		var nb := _miter(pts, i + 1, half)
		var v0 := along / dash if dash > 0 else 0.0
		var v1 := (along + len) / dash if dash > 0 else len / 3.0
		var u_l := 0.0 if dash > 0 else 0.0
		var u_r := 1.0 if dash > 0 else width / 3.0
		var corners := [
			Vector3(a.x - na.x, y, a.y - na.y), Vector3(a.x + na.x, y, a.y + na.y),
			Vector3(b.x + nb.x, y, b.y + nb.y), Vector3(b.x - nb.x, y, b.y - nb.y),
		]
		_quad(st, corners, Vector3.UP, [Vector2(u_l, v0), Vector2(u_r, v0), Vector2(u_r, v1), Vector2(u_l, v1)], Color.WHITE)
		along += len


## Offset vector at vertex i, averaged between adjoining segments.
func _miter(pts: PackedVector2Array, i: int, half: float) -> Vector2:
	var dir := Vector2.ZERO
	if i > 0:
		dir += (pts[i] - pts[i - 1]).normalized()
	if i < pts.size() - 1:
		dir += (pts[i + 1] - pts[i]).normalized()
	if dir.length() < 0.001:
		dir = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
	var perp := Vector2(-dir.y, dir.x).normalized()
	return perp * half


# --- areas & ground -------------------------------------------------------------

func _add_area(a: Dictionary) -> void:
	var pts := _to_v2(a.pts)
	if pts.size() < 3:
		return
	var color: Color = AREA_COLORS.get(a.kind, Color(0.8, 0.72, 0.56))
	var idx := Geometry2D.triangulate_polygon(pts)
	var st := _surface(_centroid(pts), "area")
	var y := 0.012 if a.kind in ["park", "pitch", "cemetery"] else 0.008
	for k in range(0, idx.size(), 3):
		for p in _up_facing(pts[idx[k]], pts[idx[k + 1]], pts[idx[k + 2]]):
			st.set_color(color)
			st.set_normal(Vector3.UP)
			# Solar heaters share this surface and carry UVs, so the format must match.
			st.set_uv(p * 0.1)
			st.add_vertex(Vector3(p.x, y, p.y))
	if a.kind == "park":
		_scatter_trees(pts)


func _scatter_trees(pts: PackedVector2Array) -> void:
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	var count := clampi(int(box.get_area() / 250.0), 1, 40)
	for i in count:
		var p := Vector2(_rng.randf_range(box.position.x, box.end.x), _rng.randf_range(box.position.y, box.end.y))
		if Geometry2D.is_point_in_polygon(p, pts):
			Props.tree(self, Vector3(p.x, 0, p.y), _rng)


func _add_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(bounds.size.x + 4000, bounds.size.y + 4000)
	plane.subdivide_width = 40
	plane.subdivide_depth = 40
	ground.mesh = plane
	ground.position = Vector3(bounds.get_center().x, -0.02, bounds.get_center().y)
	ground.material_override = CityMaterials.sand()
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _add_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "CityCollision"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_collision_faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	body.add_child(floor_shape)
	add_child(body)
	_collision_faces = PackedVector3Array()


# --- helpers ----------------------------------------------------------------------

func _quad(st: SurfaceTool, c: Array, nrm: Vector3, uv: Array, color: Color) -> void:
	# Godot treats clockwise triangles as front-facing.
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_color(color)
		st.set_normal(nrm)
		st.set_uv(uv[i])
		st.add_vertex(c[i])


## Orders a flat (x, z) triangle so its front face points up. The winding that
## triangulate_polygon returns follows the source ring, which OSM does not fix,
## so roofs and areas were culled whenever a ring ran the other way. Same
## convention as _ribbon: (b - a) x (c - a) > 0 in (x, z) is front-facing.
static func _up_facing(a: Vector2, b: Vector2, c: Vector2) -> Array[Vector2]:
	if (b - a).cross(c - a) > 0:
		return [a, b, c]
	return [a, c, b]


static func _to_v2(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(Vector2(p[0], p[1]))
	return out


static func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / pts.size()
