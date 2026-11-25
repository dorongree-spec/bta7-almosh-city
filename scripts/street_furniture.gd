## Street-level detail that makes the map read as a city rather than a model:
## street lamps along the roads, traffic lights at big junctions and shop
## signs (real names from OpenStreetMap) mounted on the nearest wall.
## Repeated objects are drawn with one MultiMesh per 500 m tile and part.
class_name StreetFurniture
extends Node3D

const TILE := 500.0
const LAMP_SPACING := 42.0
const TREE_SPACING := 28.0
const TREE_ROADS := ["primary", "secondary", "tertiary", "residential"]
const LAMP_ROADS := ["trunk", "primary", "secondary", "tertiary", "residential", "living_street"]
const JUNCTION_ROADS := ["trunk", "primary", "secondary", "tertiary"]
const SIGN_COLORS := [
	Color(0.8, 0.12, 0.1), Color(0.05, 0.3, 0.65), Color(0.95, 0.75, 0.05),
	Color(0.1, 0.5, 0.25), Color(0.9, 0.4, 0.05), Color(0.12, 0.12, 0.14),
]
const BUILDING_CELL := 80.0

## part name -> { tile key -> Array[Transform3D] }
var _batches := {}
var _font := SystemFont.new()
## The glowing head of every street lamp shares this material (DayNight dims it).
var lamp_material: StandardMaterial3D
## Tile -> PackedVector3Array of lamp head positions, for placing real lights at night.
var _lamp_heads := {}


func build(city: CityBuilder) -> void:
	_font.font_names = PackedStringArray(["Arial", "Segoe UI", "DejaVu Sans", "Noto Sans Hebrew"])
	var roads: Array = city.data.get("roads", [])
	_add_lamps(roads)
	_add_street_trees(roads)
	_add_traffic_lights(roads)
	_add_railings(roads)
	_add_market_stalls(roads)
	_add_wires(roads)
	_commit()
	_add_crossings(roads)
	_commit_crossings()
	_commit()  # the street-name signs placed with the crossings
	_add_shop_signs(city.data.get("buildings", []), city.data.get("pois", []))


# --- batching ----------------------------------------------------------------------

func _put(part: String, xform: Transform3D) -> void:
	var tile := Vector2i(floori(xform.origin.x / TILE), floori(xform.origin.z / TILE))
	if not _batches.has(part):
		_batches[part] = {}
	var tiles: Dictionary = _batches[part]
	if not tiles.has(tile):
		tiles[tile] = []
	(tiles[tile] as Array).append(xform)


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _blob(radius: float, height: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 10
	m.rings = 5
	return m


func _pole(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius * 0.7
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 6
	m.rings = 1
	return m


func _commit() -> void:
	var steel := CityMaterials.color(Color(0.42, 0.44, 0.46), 0.5, 0.7)
	if lamp_material == null:  # committed twice (signs come with the crossings): keep one
		lamp_material = CityMaterials.emissive(Color(1.0, 0.86, 0.6), 0.6).duplicate() as StandardMaterial3D
	var dark := CityMaterials.color(Color(0.08, 0.08, 0.09), 0.6, 0.2)
	var parts := {
		"lamp_pole": [_pole(0.11, 8.0), steel],
		"lamp_arm": [_box(Vector3(0.09, 0.09, 2.0)), steel],
		"lamp_head": [_box(Vector3(0.32, 0.12, 0.7)), lamp_material],
		"ficus_trunk": [_pole(0.22, 3.0), TreeMeshes.bark_material(Color(0.4, 0.34, 0.27))],
		"ficus_crown": [TreeMeshes.ficus_crown(), TreeMeshes.leaf_material()],
		"palm_trunk": [_pole(0.26, 8.0), TreeMeshes.bark_material(Color(0.46, 0.37, 0.26))],
		"palm_crown": [TreeMeshes.palm_crown(), TreeMeshes.palm_material()],
		"light_pole": [_pole(0.09, 3.6), dark],
		"globe_pole": [_pole(0.08, 4.2), CityMaterials.color(Color(0.08, 0.24, 0.15), 0.5, 0.5)],
		"globe_bar": [_box(Vector3(0.95, 0.06, 0.06)), CityMaterials.color(Color(0.08, 0.24, 0.15), 0.5, 0.5)],
		"globe_head": [_blob(0.2, 0.4), lamp_material],
		"name_pole": [_pole(0.035, 2.8), CityMaterials.color(Color(0.6, 0.62, 0.64), 0.4, 0.7)],
		"name_plate": [_box(Vector3(0.95, 0.26, 0.03)), _street_sign_material()],
		"stall": [_stall_mesh(), null],
		"railing": [_railing_panel(), CityMaterials.color(Color(0.1, 0.3, 0.17), 0.55, 0.4)],
		"wood_pole": [_pole(0.13, 8.0), CityMaterials.color(Color(0.3, 0.24, 0.17), 0.95)],
		"wire": [_box(Vector3(0.025, 0.025, 1.0)), dark],
		"light_box": [_box(Vector3(0.34, 1.0, 0.3)), dark],
		"light_red": [_box(Vector3(0.2, 0.2, 0.05)), CityMaterials.emissive(Color(1.0, 0.1, 0.08), 3.0)],
		"light_amber": [_box(Vector3(0.2, 0.2, 0.05)), CityMaterials.color(Color(0.3, 0.22, 0.02), 0.5)],
		"light_green": [_box(Vector3(0.2, 0.2, 0.05)), CityMaterials.color(Color(0.03, 0.25, 0.08), 0.5)],
	}
	for part in _batches:
		var def: Array = parts[part]
		var tiles: Dictionary = _batches[part]
		for tile in tiles:
			var xforms: Array = tiles[tile]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = def[0]
			mm.instance_count = xforms.size()
			for i in xforms.size():
				mm.set_instance_transform(i, xforms[i])
			var node := MultiMeshInstance3D.new()
			node.multimesh = mm
			if def[1] != null:
				node.material_override = def[1]
			# Trees fade out at 500 m, where the haze hides them anyway; their alpha
			# leaf cards were the most expensive thing on screen (PC tuning).
			var tree := String(part).begins_with("ficus") or String(part).begins_with("palm")
			node.visibility_range_end = 500.0 if tree else 1100.0
			node.visibility_range_end_margin = 60.0 if tree else 0.0
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if tree else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			# Only the trees are big enough for their shadows to matter.
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if String(part).ends_with("crown") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
	_batches.clear()


## The blue municipal street-name plate: white border, a line of white
## right-aligned lettering (Hebrew over a smaller English line).
func _street_sign_material() -> StandardMaterial3D:
	var img := Image.create(256, 72, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.22, 0.55))
	var white := Color(0.96, 0.96, 0.94)
	for t in 4:
		img.fill_rect(Rect2i(t, t, 256 - t * 2, 1), white)
		img.fill_rect(Rect2i(t, 71 - t, 256 - t * 2, 1), white)
		img.fill_rect(Rect2i(t, t, 1, 72 - t * 2), white)
		img.fill_rect(Rect2i(255 - t, t, 1, 72 - t * 2), white)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var x := 236
	while x > 70:
		var w := rng.randi_range(6, 16)
		img.fill_rect(Rect2i(x - w, 14, w, 26), white)
		x -= w + (12 if rng.randf() < 0.2 else 4)
	x = 40
	while x < 200:
		var w := rng.randi_range(4, 9)
		img.fill_rect(Rect2i(x, 48, w, 10), white)
		x += w + (8 if rng.randf() < 0.2 else 2)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.4
	m.uv1_scale = Vector3(1, 1, 1)
	return m


## Green post, a crossbar and two white globes either side.
func _add_globe_lamp(at: Vector3) -> void:
	_put("globe_pole", Transform3D(Basis.IDENTITY, at + Vector3(0, 2.1, 0)))
	_put("globe_bar", Transform3D(Basis.IDENTITY, at + Vector3(0, 4.05, 0)))
	for side: float in [-0.42, 0.42]:
		var head := at + Vector3(side, 4.35, 0)
		_put("globe_head", Transform3D(Basis.IDENTITY, head))
		var tile := Vector2i(floori(head.x / TILE), floori(head.z / TILE))
		if not _lamp_heads.has(tile):
			_lamp_heads[tile] = PackedVector3Array()
		var heads: PackedVector3Array = _lamp_heads[tile]
		heads.append(head)
		_lamp_heads[tile] = heads


# --- market stalls (Old City pedestrian streets, from the Kakal street photos) -------

func _stall_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	var tarp := CityMaterials.color(Color(0.12, 0.35, 0.62), 0.7)
	var steel := CityMaterials.color(Color(0.55, 0.56, 0.58), 0.4, 0.6)
	var board := CityMaterials.color(Color(0.82, 0.8, 0.74), 0.8)
	for x: float in [-0.95, 0.95]:
		for z: float in [-0.7, 0.7]:
			kit.box(steel, Vector3(0.04, 2.3 if z < 0.0 else 2.1, 0.04), Vector3(x, 1.15 if z < 0.0 else 1.05, z))
	kit.box(tarp, Vector3(2.2, 0.04, 1.8), Vector3(0, 2.2, 0), Basis(Vector3.RIGHT, 0.11))
	kit.box(tarp, Vector3(2.2, 0.35, 0.03), Vector3(0, 2.0, 0.9))
	kit.box(board, Vector3(1.9, 0.06, 1.0), Vector3(0, 0.85, 0.2))
	kit.box(steel, Vector3(1.8, 0.8, 0.04), Vector3(0, 0.42, -0.25))
	var goods := [Color(0.85, 0.3, 0.12), Color(0.95, 0.8, 0.2), Color(0.3, 0.55, 0.2), Color(0.9, 0.9, 0.88), Color(0.55, 0.2, 0.5), Color(0.2, 0.4, 0.75)]
	for k in 6:
		kit.box(CityMaterials.color(goods[k], 0.8), Vector3(0.28, 0.18, 0.4), Vector3(-0.75 + k * 0.3, 0.97, 0.25))
	return kit.build()


## Stalls with blue tarps down the Old City's pedestrian streets.
func _add_market_stalls(roads: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1900
	var solid := StaticBody3D.new()
	solid.name = "StallCollision"
	add_child(solid)
	for r in roads:
		# Only the Keren Kayemet mall itself: on the wide plazas the stalls stood
		# in a grid and swallowed the square (seen at Herzl).
		if r.kind != "pedestrian" or String(r.get("name", "")) != "קרן קיימת לישראל" or not OLD_CITY.has_point(Vector2(r.pts[0][0], r.pts[0][1])):
			continue
		var pts: Array = r.pts
		var half: float = maxf(float(r.w) * 0.5 - 1.4, 1.2)
		var travelled := 9.0  # clear of the road at the end of the street
		var side := 1.0
		for i in pts.size() - 1:
			var a := Vector2(pts[i][0], pts[i][1])
			var b := Vector2(pts[i + 1][0], pts[i + 1][1])
			var seg := a.distance_to(b)
			if seg < 0.01:
				continue
			var dir := (b - a) / seg
			var right := Vector2(-dir.y, dir.x)
			while travelled < seg:
				if rng.randf() < 0.65:
					var p := a + dir * travelled + right * half * side
					# Facing the middle of the street.
					var facing := Basis(Vector3.UP, atan2(-right.x * side, -right.y * side))
					_put("stall", Transform3D(facing, Vector3(p.x, 0.05, p.y)))
					var shape := CollisionShape3D.new()
					var box := BoxShape3D.new()
					box.size = Vector3(2.0, 1.0, 1.5)
					shape.shape = box
					shape.transform = Transform3D(facing, Vector3(p.x, 0.55, p.y))
					solid.add_child(shape)
				side = -side
				travelled += 3.6
			travelled -= seg


# --- railings and wires (Shchuna Dalet, from the reference photos) ---------------------

## Main streets of Dalet with the green iron pedestrian railing along the kerb.
const RAILING_STREETS := ["אברהם אבינו", "רינגלבלום"]
const RAILING_PANEL := 2.4
## Where overhead phone and power lines cross the side streets (game x/z box
## around Shchuna Dalet).
const WIRES_AREA := Rect2(-100, -3350, 1500, 1050)
const WIRE_SPACING := 38.0


## One 2.4 m panel: posts, top and bottom rails, upright bars. Origin at the
## middle of its foot, running along local x.
func _railing_panel() -> ArrayMesh:
	var kit := MeshKit.new()
	var iron := CityMaterials.color(Color(0.1, 0.3, 0.17), 0.55, 0.4)
	kit.box(iron, Vector3(0.06, 1.0, 0.06), Vector3(-RAILING_PANEL * 0.5 + 0.03, 0.5, 0))
	kit.box(iron, Vector3(RAILING_PANEL, 0.05, 0.05), Vector3(0, 0.98, 0))
	kit.box(iron, Vector3(RAILING_PANEL, 0.04, 0.04), Vector3(0, 0.22, 0))
	for k in 11:
		kit.box(iron, Vector3(0.02, 0.76, 0.02), Vector3(-RAILING_PANEL * 0.5 + 0.2 * (k + 1), 0.6, 0))
	return kit.build()


## Vertices shared by two or more streets: gaps in the railing there.
func _junction_keys(roads: Array) -> Dictionary:
	var count := {}
	for r in roads:
		if not (r.kind in LAMP_ROADS):
			continue
		var seen := {}
		for p in r.pts:
			var key := Vector2i(roundi(p[0]), roundi(p[1]))
			if not seen.has(key):
				seen[key] = true
				count[key] = int(count.get(key, 0)) + 1
	var out := {}
	for key in count:
		if int(count[key]) >= 2:
			out[key] = true
	return out


func _add_railings(roads: Array) -> void:
	var junctions := _junction_keys(roads)
	for r in roads:
		if not (String(r.get("name", "")) in RAILING_STREETS):
			continue
		var pts: Array = r.pts
		var half: float = float(r.w) * 0.5 + 0.35
		for i in pts.size() - 1:
			var a := Vector2(pts[i][0], pts[i][1])
			var b := Vector2(pts[i + 1][0], pts[i + 1][1])
			var seg := a.distance_to(b)
			if seg < RAILING_PANEL:
				continue
			var dir := (b - a) / seg
			var right := Vector2(-dir.y, dir.x)
			# Leave the corners open where another street joins.
			var start := 12.0 if junctions.has(Vector2i(roundi(a.x), roundi(a.y))) else 0.0
			var stop := seg - (12.0 if junctions.has(Vector2i(roundi(b.x), roundi(b.y))) else 0.0)
			var along := start + RAILING_PANEL * 0.5
			var turn := Basis(Vector3.UP, atan2(-dir.y, dir.x))
			while along + RAILING_PANEL * 0.5 <= stop:
				for side: float in [1.0, -1.0]:
					var p := a + dir * along + right * half * side
					_put("railing", Transform3D(turn, Vector3(p.x, 0.12, p.y)))
				along += RAILING_PANEL


## Wooden poles on both pavements with three sagging lines across the street,
## every ~40 m along the side streets of Dalet.
func _add_wires(roads: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1964
	for r in roads:
		if r.kind != "residential" and r.kind != "living_street":
			continue
		var pts: Array = r.pts
		var half: float = float(r.w) * 0.5 + 1.2
		var travelled := WIRE_SPACING * rng.randf()
		for i in pts.size() - 1:
			var a := Vector2(pts[i][0], pts[i][1])
			var b := Vector2(pts[i + 1][0], pts[i + 1][1])
			var seg := a.distance_to(b)
			if seg < 0.01:
				continue
			var dir := (b - a) / seg
			var right := Vector2(-dir.y, dir.x)
			while travelled < seg:
				var mid := a + dir * travelled
				if WIRES_AREA.has_point(mid):
					var l := mid - right * half
					var rr := mid + right * half
					_put("wood_pole", Transform3D(Basis.IDENTITY, Vector3(l.x, 4.0, l.y)))
					_put("wood_pole", Transform3D(Basis.IDENTITY, Vector3(rr.x, 4.0, rr.y)))
					for k in 3:
						_add_sagging_wire(Vector3(l.x, 7.6 - k * 0.35, l.y), Vector3(rr.x, 7.6 - k * 0.35, rr.y), 0.5 + k * 0.1)
				travelled += WIRE_SPACING
			travelled -= seg


## A wire from a to b hanging sag metres in the middle, as four straight runs.
func _add_sagging_wire(a: Vector3, b: Vector3, sag: float) -> void:
	const RUNS := 4
	var prev := a
	for k in range(1, RUNS + 1):
		var t := float(k) / RUNS
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var span := p - prev
		var basis := Basis.looking_at(span.normalized(), Vector3.UP).scaled(Vector3(1, 1, span.length()))
		_put("wire", Transform3D(basis, (prev + p) * 0.5))
		prev = p


# --- street trees ----------------------------------------------------------------------

## Shade trees along the pavements: dusty ficus on ordinary streets, date
## palms down the big boulevards. Sizes vary so no two are quite alike.
func _add_street_trees(roads: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1948
	for r in roads:
		if not (r.kind in TREE_ROADS) or r.get("roundabout", false):
			continue
		var pts: Array = r.pts
		var palms: bool = float(r.w) >= 11.0
		var half: float = float(r.w) * 0.5 + 2.2
		var travelled := TREE_SPACING * rng.randf()
		for i in pts.size() - 1:
			var a := Vector2(pts[i][0], pts[i][1])
			var b := Vector2(pts[i + 1][0], pts[i + 1][1])
			var seg := a.distance_to(b)
			if seg < 0.01:
				continue
			var dir := (b - a) / seg
			var right := Vector2(-dir.y, dir.x)
			while travelled < seg:
				for side: float in [1.0, -1.0]:
					if rng.randf() < 0.3:
						continue  # gaps: driveways, dead trees, the municipality
					var p := a + dir * travelled + right * half * side
					_add_tree(Vector3(p.x, 0, p.y), palms, rng)
				travelled += TREE_SPACING
			travelled -= seg


func _add_tree(at: Vector3, palm: bool, rng: RandomNumberGenerator) -> void:
	var size := rng.randf_range(0.8, 1.25)
	var grow := Basis.from_scale(Vector3(size, size, size)).rotated(Vector3.UP, rng.randf() * TAU)
	if palm:
		_put("palm_trunk", Transform3D(grow, at + Vector3(0, 4.0 * size, 0)))
		_put("palm_crown", Transform3D(grow, at + Vector3(0, 8.1 * size, 0)))
	else:
		_put("ficus_trunk", Transform3D(grow, at + Vector3(0, 1.5 * size, 0)))
		_put("ficus_crown", Transform3D(grow, at + Vector3(0, 4.2 * size, 0)))


# --- lamps ---------------------------------------------------------------------------

## One lamp every LAMP_SPACING metres, alternating sides, arm over the road.
func _add_lamps(roads: Array) -> void:
	for r in roads:
		if not (r.kind in LAMP_ROADS) or r.get("roundabout", false):
			continue
		var pts: Array = r.pts
		var half: float = float(r.w) * 0.5 + 1.4
		var travelled := LAMP_SPACING * 0.5
		var side := 1.0
		for i in pts.size() - 1:
			var a := Vector2(pts[i][0], pts[i][1])
			var b := Vector2(pts[i + 1][0], pts[i + 1][1])
			var seg := a.distance_to(b)
			if seg < 0.01:
				continue
			var dir := (b - a) / seg
			var right := Vector2(-dir.y, dir.x)
			while travelled < seg:
				var p := a + dir * travelled + right * half * side
				_add_lamp(Vector3(p.x, 0, p.y), -right * side)
				side = -side
				travelled += LAMP_SPACING
			travelled -= seg


## The Old City (game x/z): green cast-iron posts with white globes, as on the
## Keren Kayemet / Smilansky pedestrian streets, instead of highway lamps.
const OLD_CITY := Rect2(-160, -360, 640, 680)


## `inward` points from the pole towards the carriageway.
func _add_lamp(at: Vector3, inward: Vector2) -> void:
	if OLD_CITY.has_point(Vector2(at.x, at.z)):
		_add_globe_lamp(at)
		return
	var yaw := atan2(inward.x, inward.y)
	var facing := Basis(Vector3.UP, yaw)
	var over := Vector3(inward.x, 0, inward.y)
	_put("lamp_pole", Transform3D(Basis.IDENTITY, at + Vector3(0, 4.0, 0)))
	_put("lamp_arm", Transform3D(facing, at + Vector3(0, 7.9, 0) + over * 1.0))
	var head := at + Vector3(0, 7.82, 0) + over * 1.9
	_put("lamp_head", Transform3D(facing, head))
	var tile := Vector2i(floori(head.x / TILE), floori(head.z / TILE))
	if not _lamp_heads.has(tile):
		_lamp_heads[tile] = PackedVector3Array()
	var heads: PackedVector3Array = _lamp_heads[tile]
	heads.append(head)
	_lamp_heads[tile] = heads


## Every lamp head in town (world positions), for whoever wants them all.
func all_lamp_heads() -> PackedVector3Array:
	var all := PackedVector3Array()
	for tile in _lamp_heads:
		var heads: PackedVector3Array = _lamp_heads[tile]
		all.append_array(heads)
	return all


## The `count` lamp heads closest to `centre` within `reach` metres.
func lamps_near(centre: Vector3, reach: float, count: int) -> Array[Vector3]:
	var found: Array[Vector3] = []
	var tile := Vector2i(floori(centre.x / TILE), floori(centre.z / TILE))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var heads: PackedVector3Array = _lamp_heads.get(tile + Vector2i(dx, dz), PackedVector3Array())
			for head in heads:
				if head.distance_to(centre) < reach:
					found.append(head)
	found.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(centre) < b.distance_squared_to(centre))
	if found.size() > count:
		found.resize(count)
	return found


# --- traffic lights ---------------------------------------------------------------------

## A junction is a point where three or more major road ends meet.
func _add_traffic_lights(roads: Array) -> void:
	var ends := {}
	for r in roads:
		if not (r.kind in JUNCTION_ROADS) or r.get("roundabout", false):
			continue
		var pts: Array = r.pts
		if pts.size() < 2:
			continue
		var half: float = float(r.w) * 0.5 + 1.0
		for pair in [[pts[0], pts[1]], [pts[-1], pts[-2]]]:
			var end := Vector2(pair[0][0], pair[0][1])
			var away := (Vector2(pair[1][0], pair[1][1]) - end).normalized()
			var key := Vector2i(roundi(end.x), roundi(end.y))
			if not ends.has(key):
				ends[key] = []
			(ends[key] as Array).append([end, away, half])
	for key in ends:
		var arms: Array = ends[key]
		if arms.size() < 3:
			continue
		for arm in arms:
			var end: Vector2 = arm[0]
			var away: Vector2 = arm[1]
			var half: float = arm[2]
			# Stand on the right-hand kerb of traffic arriving along this arm,
			# a few metres back from the junction, facing that traffic.
			var arriving := -away
			var right := Vector2(-arriving.y, arriving.x)
			var p := end + away * 7.0 + right * half
			_add_traffic_light(Vector3(p.x, 0, p.y), away)


# --- zebra crossings -------------------------------------------------------------

## A zebra crossing on every arm of a junction, just in front of the lights
## (PC tuning: the streets had no crossings at all). One MultiMesh for the city.
const CROSSING_SHADER := """
shader_type spatial;
render_mode cull_disabled;
varying float across;
varying float along;
void vertex() {
	across = (VERTEX.x + 0.5) * length(MODEL_MATRIX[0].xyz);
	along = (VERTEX.z + 0.5) * length(MODEL_MATRIX[2].xyz);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float stripe = step(0.5, fract(across / 1.0));
	// Worn patches in the crossing's own frame, so the stripe edges stay straight.
	float wear = hash(floor(vec2(across * 3.0, along * 1.5)));
	if (stripe < 0.5 || wear < 0.07) {
		discard;
	}
	ALBEDO = vec3(0.86, 0.85, 0.8);
	ROUGHNESS = 0.6;
}
"""
var _crossings: Array[Transform3D] = []


## Every junction of three or more streets (any street with lamps, not only
## the main roads that get traffic lights).
func _add_crossings(roads: Array) -> void:
	var ends := {}
	for r in roads:
		if not (r.kind in LAMP_ROADS) or r.get("roundabout", false):
			continue
		var pts: Array = r.pts
		if pts.size() < 2:
			continue
		# Every vertex can be a junction: OSM streets often run straight through
		# a crossroads, so their middle points count too (two arms each).
		for j in pts.size():
			var here := Vector2(pts[j][0], pts[j][1])
			var key := Vector2i(roundi(here.x), roundi(here.y))
			for k in [j - 1, j + 1]:
				if k < 0 or k >= pts.size():
					continue
				var seg := Vector2(pts[k][0], pts[k][1]) - here
				var away := seg.normalized()
				if not ends.has(key):
					ends[key] = []
				(ends[key] as Array).append([here, away, float(r.w), seg.length()])
	for key in ends:
		var arms: Array = ends[key]
		if arms.size() < 3:
			continue
		# Clear of the junction itself: half the widest street there, plus a bit.
		var widest := 0.0
		for arm in arms:
			widest = maxf(widest, float(arm[2]))
		var back := widest * 0.5 + 2.2
		var used: Array[Vector2] = []
		for arm in arms:
			# Two streets leaving the same way would paint two crossings over each
			# other at slightly different angles; a crossing past the end of a short
			# (curving) segment sits off the road. Skip both.
			var dir: Vector2 = arm[1]
			if float(arm[3]) < back + 3.5 or used.any(func(u: Vector2) -> bool: return u.dot(dir) > 0.94):
				continue
			# On a skewed junction a crossing on one arm runs into the next arm's lane
			# arrows (seen at the Gilat centre): leave those arms without one.
			var skewed := false
			for other in arms:
				var cosine := absf((other[1] as Vector2).dot(dir))
				if cosine > 0.42 and cosine < 0.9:
					skewed = true
			if skewed:
				continue
			used.append(dir)
			_crossings.append(_crossing_xform(arm[0], dir, arm[2], back))
			# One blue street-name sign per junction, on the corner of its first arm.
			if used.size() == 1:
				var side := Vector2(-dir.y, dir.x)
				var corner: Vector2 = (arm[0] as Vector2) + dir * (back + 2.5) + side * (float(arm[2]) * 0.5 + 1.1)
				var facing := Basis(Vector3.UP, atan2(dir.x, dir.y))
				_put("name_pole", Transform3D(Basis.IDENTITY, Vector3(corner.x, 1.4, corner.y)))
				_put("name_plate", Transform3D(facing, Vector3(corner.x, 2.55, corner.y)))



func _crossing_xform(end: Vector2, away: Vector2, width: float, back := 4.0) -> Transform3D:
	var across := Vector2(-away.y, away.x)
	var centre := end + away * back
	var basis := Basis(Vector3(across.x, 0, across.y) * width, Vector3.UP, Vector3(away.x, 0, away.y) * 3.0)
	return Transform3D(basis, Vector3(centre.x, 0.1, centre.y))


func _commit_crossings() -> void:
	if _crossings.is_empty():
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = plane
	mm.instance_count = _crossings.size()
	for i in _crossings.size():
		mm.set_instance_transform(i, _crossings[i])
	var shader := Shader.new()
	shader.code = CROSSING_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _add_traffic_light(at: Vector3, facing_dir: Vector2) -> void:
	var facing := Basis(Vector3.UP, atan2(facing_dir.x, facing_dir.y))
	var front := Vector3(facing_dir.x, 0, facing_dir.y) * 0.17
	_put("light_pole", Transform3D(Basis.IDENTITY, at + Vector3(0, 1.8, 0)))
	_put("light_box", Transform3D(facing, at + Vector3(0, 3.9, 0)))
	_put("light_red", Transform3D(facing, at + Vector3(0, 4.2, 0) + front))
	_put("light_amber", Transform3D(facing, at + Vector3(0, 3.9, 0) + front))
	_put("light_green", Transform3D(facing, at + Vector3(0, 3.6, 0) + front))


# --- shop signs ------------------------------------------------------------------------

## Every named shop or cafe gets a signboard on the closest building wall.
func _add_shop_signs(buildings: Array, pois: Array) -> void:
	# Coarse grid of buildings so each sign only tests its neighbours.
	var grid := {}
	for b in buildings:
		var first: Array = b.pts[0]
		var cell := Vector2i(floori(first[0] / BUILDING_CELL), floori(first[1] / BUILDING_CELL))
		if not grid.has(cell):
			grid[cell] = []
		(grid[cell] as Array).append(b)

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for poi in pois:
		var title := String(poi.get("name", ""))
		if title == "":
			continue
		var at := Vector2(poi.p[0], poi.p[1])
		var wall := _nearest_wall(grid, at)
		if wall.is_empty():
			continue
		_add_sign(title, wall.point, wall.normal, SIGN_COLORS[rng.randi() % SIGN_COLORS.size()])


## Closest point on any nearby building edge, with that wall's outward normal.
func _nearest_wall(grid: Dictionary, at: Vector2) -> Dictionary:
	var cell := Vector2i(floori(at.x / BUILDING_CELL), floori(at.y / BUILDING_CELL))
	var best := {}
	var best_d := 30.0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for b in grid.get(cell + Vector2i(dx, dy), []):
				var pts: Array = b.pts
				for i in pts.size():
					var a := Vector2(pts[i][0], pts[i][1])
					var c := Vector2(pts[(i + 1) % pts.size()][0], pts[(i + 1) % pts.size()][1])
					var edge := c - a
					if edge.length() < 3.5:
						continue
					var q := Geometry2D.get_closest_point_to_segment(at, a, c)
					var d := q.distance_to(at)
					if d < best_d:
						best_d = d
						var n := Vector2(edge.y, -edge.x).normalized()
						# Whatever the ring's winding, the sign goes on the outside:
						# the normal must point away from the building's middle.
						var mid := Vector2.ZERO
						for p in pts:
							mid += Vector2(p[0], p[1])
						mid /= pts.size()
						if n.dot(q - mid) < 0.0:
							n = -n
						best = {"point": q, "normal": n}
	return best


## Shop boards light up at night like the neon and lightboxes on any Israeli
## high street; DayNight drives the glow (0 by day, 1 at night).
static var _sign_mats := {}


static func _sign_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _sign_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.45
		m.emission_enabled = true
		m.emission = color.lightened(0.2)
		m.emission_energy_multiplier = 0.0
		_sign_mats[key] = m
	return _sign_mats[key]


static func set_sign_glow(dark: float) -> void:
	for key in _sign_mats:
		(_sign_mats[key] as StandardMaterial3D).emission_energy_multiplier = dark * 2.2


func _add_sign(text: String, at: Vector2, normal: Vector2, color: Color) -> void:
	var width := clampf(text.length() * 0.34 + 0.8, 2.0, 6.0)
	var out := Vector3(normal.x, 0, normal.y)
	var root := Node3D.new()
	root.position = Vector3(at.x, 3.3, at.y) + out * 0.12
	root.rotation.y = atan2(normal.x, normal.y)
	add_child(root)

	var board := MeshInstance3D.new()
	board.mesh = _box(Vector3(width, 0.8, 0.1))
	board.material_override = _sign_material(color)
	board.visibility_range_end = 260.0
	root.add_child(board)

	var label := Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = 96
	label.pixel_size = 0.0045
	label.outline_size = 0
	label.modulate = Color(0.1, 0.1, 0.1) if color.get_luminance() > 0.5 else Color.WHITE
	label.position = Vector3(0, 0, 0.06)
	label.visibility_range_end = 90.0
	root.add_child(label)
