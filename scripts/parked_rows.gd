## Rows of parked cars on the asphalt car parks between the housing blocks
## (the "yard_parking" outlines in data/dressing.*). In the reference photos
## of Shchuna Dalet these lots are packed nose to kerb with white and silver
## cars, so that is what is drawn here: no physics bodies that can drive, just
## one MultiMesh per body style plus a box to bump into for each car.
class_name ParkedRows
extends Node3D

const INDEX := "res://data/dressing.json"
const NUMBERS := "res://data/dressing.bin"
const SLOT_W := 2.6        # metres between cars in a row
const ROW_D := 5.2         # depth of one row of bays
const AISLE := 6.0         # driving lane between two pairs of rows
const FILL := 0.72         # share of bays that have a car in them
const MAX_CARS := 16000
const PER_LOT := 34       # the rows nearest the edge of a big lot; the rest stays open asphalt

## style -> [length, width, height]
const STYLES := {
	"boxy": [4.2, 1.64, 1.38],
	"hatch": [3.98, 1.65, 1.39],
	"sedan": [4.6, 1.78, 1.45],
	"wagon": [4.41, 1.62, 1.42],
	"hatch_new": [4.4, 1.78, 1.44],
}
## Weighted car colours of an Israeli car park: mostly white and silver.
const COLOURS := [
	[Color(0.93, 0.93, 0.91), 34], [Color(0.72, 0.73, 0.74), 22], [Color(0.45, 0.46, 0.48), 10],
	[Color(0.08, 0.08, 0.09), 8], [Color(0.85, 0.82, 0.72), 6], [Color(0.55, 0.1, 0.09), 5],
	[Color(0.25, 0.35, 0.55), 6], [Color(0.62, 0.7, 0.78), 5], [Color(0.3, 0.4, 0.3), 4],
]

var _xforms := {}   # style -> Array[Transform3D]
var _colours := {}  # style -> Array[Color]
var _solid := StaticBody3D.new()
var count := 0


func build() -> void:
	if not FileAccess.file_exists(INDEX) or not FileAccess.file_exists(NUMBERS):
		return
	var index = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	if typeof(index) != TYPE_DICTIONARY:
		return
	var layer: Dictionary = (index as Dictionary).get("layers", {}).get("yard_parking", {})
	if layer.is_empty():
		return
	var numbers := FileAccess.get_file_as_bytes(NUMBERS).to_float32_array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	_solid.name = "ParkedCarsCollision"
	add_child(_solid)
	var at := int(layer.get("offset", 0))
	for r in int(layer.get("rings", 0)):
		var n := int(numbers[at])
		var outline := PackedVector2Array()
		outline.resize(n)
		for k in n:
			outline[k] = Vector2(numbers[at + 1 + k * 2], numbers[at + 2 + k * 2])
		at += 1 + n * 2
		if count < MAX_CARS:
			_fill_lot(outline, rng)
	_commit()


## Lays rows of bays along the longest side of the lot and parks cars in most.
## Cars nose to tail along both kerbs of the named streets (Avraham Avinu in
## the Street View walk), half up on the kerb the way Beer Sheva parks.
const KERB_STREETS := ["אברהם אבינו"]


func build_kerbs(roads: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1515
	# The car-park cars are already drawn; start the batches afresh.
	_xforms.clear()
	_colours.clear()
	if _solid.get_parent() == null:
		add_child(_solid)
	for r in roads:
		if not (String(r.get("name", "")) in KERB_STREETS):
			continue
		var pts: Array = r.pts
		var off: float = float(r.w) * 0.5 - 0.7
		for i in pts.size() - 1:
			var a := Vector2(pts[i][0], pts[i][1])
			var b := Vector2(pts[i + 1][0], pts[i + 1][1])
			var seg := a.distance_to(b)
			var dir := (b - a) / maxf(seg, 0.01)
			var right := Vector2(-dir.y, dir.x)
			var u := 9.0
			while u < seg - 9.0:
				for side: float in [1.0, -1.0]:
					if rng.randf() < 0.75:
						var c := a + dir * u + right * off * side
						_park(c, dir * side, rng)
				u += 5.4
	_commit()
	_xforms.clear()
	_colours.clear()

func _fill_lot(outline: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	if outline.size() < 3:
		return
	var along := Vector2.RIGHT
	var longest := 0.0
	for i in outline.size():
		var e := outline[(i + 1) % outline.size()] - outline[i]
		if e.length() > longest:
			longest = e.length()
			along = e.normalized()
	var across := Vector2(-along.y, along.x)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in outline:
		var q := Vector2(p.dot(along), p.dot(across))
		lo = lo.min(q)
		hi = hi.max(q)
	# Pattern across the lot: bay row, bay row (nose to nose), aisle, repeat.
	var v := lo.y + 1.0
	var row := 0
	var parked := 0
	while v + ROW_D <= hi.y - 0.5 and parked < PER_LOT:
		var facing := 1.0 if row % 2 == 0 else -1.0
		var u := lo.x + 1.2 + SLOT_W * 0.5
		while u + SLOT_W * 0.5 <= hi.x - 1.2:
			var centre := along * u + across * (v + ROW_D * 0.5)
			if parked < PER_LOT and _bay_inside(outline, centre, along, across) and rng.randf() < FILL:
				_park(centre, across * facing, rng)
				parked += 1
			u += SLOT_W
		v += ROW_D
		row += 1
		if row % 2 == 0:
			v += AISLE


func _bay_inside(outline: PackedVector2Array, centre: Vector2, along: Vector2, across: Vector2) -> bool:
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector2 = centre + along * c.x * SLOT_W * 0.45 + across * c.y * ROW_D * 0.48
		if not Geometry2D.is_point_in_polygon(p, outline):
			return false
	return true


func _park(centre: Vector2, nose: Vector2, rng: RandomNumberGenerator) -> void:
	var styles := STYLES.keys()
	var style: String = styles[rng.randi() % styles.size()]
	var dims: Array = STYLES[style]
	# A little untidy: nobody parks dead straight.
	var yaw := atan2(nose.x, nose.y) + rng.randf_range(-0.06, 0.06)
	var offset := Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.3, 0.2))
	var pos := Vector3(centre.x + offset.x, 0.0, centre.y + offset.y)
	var xform := Transform3D(Basis(Vector3.UP, yaw), pos)
	if not _xforms.has(style):
		_xforms[style] = []
		_colours[style] = []
	(_xforms[style] as Array).append(xform)
	(_colours[style] as Array).append(_pick_colour(rng))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(float(dims[1]), float(dims[2]) - 0.3, float(dims[0]))
	shape.shape = box
	shape.transform = Transform3D(xform.basis, pos + Vector3(0, 0.3 + box.size.y * 0.5, 0))
	_solid.add_child(shape)
	count += 1


func _pick_colour(rng: RandomNumberGenerator) -> Color:
	var total := 0
	for c in COLOURS:
		total += int(c[1])
	var roll := rng.randi_range(0, total - 1)
	for c in COLOURS:
		roll -= int(c[1])
		if roll < 0:
			return (c[0] as Color).darkened(rng.randf_range(0.0, 0.12))
	return Color.WHITE


func _commit() -> void:
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.roughness = 0.35
	paint.metallic = 0.25
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.4
	var glass := CityMaterials.color(Color(0.06, 0.08, 0.1), 0.08, 0.2)
	var dark := CityMaterials.color(Color(0.05, 0.05, 0.05), 0.9)
	var rim := CityMaterials.color(Color(0.42, 0.42, 0.42), 0.4, 0.6)
	var lamp := CityMaterials.color(Color(0.95, 0.93, 0.85), 0.2)
	var tail := CityMaterials.color(Color(0.6, 0.05, 0.04), 0.3)
	var plate := CityMaterials.color(Color(0.95, 0.78, 0.05), 0.5)
	for style: String in _xforms:
		var dims: Array = STYLES[style]
		var L: float = dims[0]
		var W: float = dims[1]
		var H: float = dims[2]
		var mesh := CarBody.build(style, L, W, H)
		mesh.surface_set_material(0, paint)
		mesh.surface_set_material(1, glass)
		var kit := MeshKit.new()
		var r := 0.31
		for fz: float in [L * 0.33, -L * 0.33]:
			for fx: float in [-1.0, 1.0]:
				var hub := Vector3(fx * (W * 0.5 - 0.12), r, fz)
				kit.cylinder(dark, r, 0.2, hub, Basis(Vector3.FORWARD, PI / 2.0), -1.0, 12)
				kit.cylinder(rim, r * 0.6, 0.21, hub, Basis(Vector3.FORWARD, PI / 2.0), -1.0, 10)
		for side: float in [-1.0, 1.0]:
			kit.box(lamp, Vector3(0.34, 0.12, 0.04), Vector3(side * W * 0.3, 0.72, L * 0.5))
			kit.box(tail, Vector3(0.3, 0.12, 0.04), Vector3(side * W * 0.32, 0.74, -L * 0.5))
		kit.box(plate, Vector3(0.52, 0.12, 0.03), Vector3(0, 0.45, L * 0.5 + 0.01))
		kit.box(plate, Vector3(0.52, 0.12, 0.03), Vector3(0, 0.5, -L * 0.5 - 0.01))
		var extras := kit.build()
		for s in extras.get_surface_count():
			mesh.add_surface_from_arrays(extras.surface_get_primitive_type(s), extras.surface_get_arrays(s))
			mesh.surface_set_material(mesh.get_surface_count() - 1, extras.surface_get_material(s))
		# One batch per 250 m tile so far lots are culled.
		var tiles := {}
		var xforms: Array = _xforms[style]
		var colours: Array = _colours[style]
		for i in xforms.size():
			var t := Vector2i(floori((xforms[i] as Transform3D).origin.x / 250.0), floori((xforms[i] as Transform3D).origin.z / 250.0))
			if not tiles.has(t):
				tiles[t] = []
			(tiles[t] as Array).append(i)
		for t: Vector2i in tiles:
			var ids: Array = tiles[t]
			var middle := Vector3((t.x + 0.5) * 250.0, 0, (t.y + 0.5) * 250.0)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = ids.size()
			for k in ids.size():
				var xf: Transform3D = xforms[ids[k]]
				xf.origin -= middle
				mm.set_instance_transform(k, xf)
				mm.set_instance_color(k, colours[ids[k]])
			var node := MultiMeshInstance3D.new()
			node.multimesh = mm
			node.position = middle
			node.visibility_range_end = 450.0
			node.visibility_range_end_margin = 40.0
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(node)
