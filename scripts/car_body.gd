## Builds a car body shell by lofting cross-sections along the length of the
## car, the way a clay model is cut into stations. Each body style is a short
## table of stations (rear to nose): where the boot ends, where the screens
## rise, where the pillars are. The result is one mesh with two surfaces:
## 0 = painted panels, 1 = glass.
class_name CarBody
extends RefCounted

## Points per half cross-section, from the floor centre up to the roof centre.
const RING := 10
## Ring segments that make up the greenhouse.
const SEG_SIDE_WINDOW := 6
const SEG_ROOF_TOP := 8

## style -> stations, each [z as a fraction of length, belt drop (m),
## cabin height fraction (0 = bonnet/boot, 1 = full roof), width scale,
## solid pillar between this station and the next].
const PROFILES := {
	"sedan": [
		[-0.50, 0.14, 0.0, 0.84, false], [-0.485, 0.03, 0.0, 0.95, false], [-0.33, 0.0, 0.0, 1.0, false],
		[-0.20, 0.0, 1.0, 1.0, true], [-0.13, 0.0, 1.0, 1.0, false], [-0.01, 0.0, 1.0, 1.0, true],
		[0.03, 0.0, 1.0, 1.0, false], [0.12, 0.0, 0.97, 1.0, false], [0.27, 0.02, 0.0, 1.0, false],
		[0.44, 0.10, 0.0, 0.97, false], [0.485, 0.16, 0.0, 0.92, false], [0.50, 0.26, 0.0, 0.82, false],
	],
	# Eighties three-box: upright screens, square nose.
	"boxy": [
		[-0.50, 0.10, 0.0, 0.90, false], [-0.49, 0.02, 0.0, 0.97, false], [-0.30, 0.0, 0.0, 1.0, false],
		[-0.23, 0.0, 1.0, 1.0, true], [-0.17, 0.0, 1.0, 1.0, false], [-0.02, 0.0, 1.0, 1.0, true],
		[0.02, 0.0, 1.0, 1.0, false], [0.11, 0.0, 1.0, 1.0, false], [0.20, 0.01, 0.0, 1.0, false],
		[0.46, 0.05, 0.0, 0.99, false], [0.49, 0.08, 0.0, 0.96, false], [0.50, 0.16, 0.0, 0.90, false],
	],
	"wagon": [
		[-0.50, 0.10, 0.0, 0.92, false], [-0.49, 0.0, 0.0, 0.98, false], [-0.47, 0.0, 0.0, 1.0, false],
		[-0.44, 0.0, 1.0, 1.0, true], [-0.38, 0.0, 1.0, 1.0, false], [-0.20, 0.0, 1.0, 1.0, true],
		[-0.16, 0.0, 1.0, 1.0, false], [-0.01, 0.0, 1.0, 1.0, true], [0.03, 0.0, 1.0, 1.0, false],
		[0.12, 0.0, 1.0, 1.0, false], [0.21, 0.01, 0.0, 1.0, false], [0.46, 0.05, 0.0, 0.99, false],
		[0.49, 0.08, 0.0, 0.96, false], [0.50, 0.16, 0.0, 0.90, false],
	],
	# Small hatchback: short bonnet, roof runs almost to the tail.
	"tuned_small": [
		[-0.50, 0.12, 0.0, 0.88, false], [-0.485, 0.02, 0.0, 0.97, false], [-0.46, 0.0, 0.0, 1.0, false],
		[-0.36, 0.0, 0.97, 1.0, true], [-0.28, 0.0, 1.0, 1.0, false], [-0.04, 0.0, 1.0, 1.0, true],
		[0.0, 0.0, 1.0, 1.0, false], [0.10, 0.0, 0.97, 1.0, false], [0.29, 0.02, 0.0, 1.0, false],
		[0.45, 0.10, 0.0, 0.96, false], [0.49, 0.16, 0.0, 0.90, false], [0.50, 0.26, 0.0, 0.80, false],
	],
	# Fastback coupe: long sloping rear screen.
	"tuned": [
		[-0.50, 0.12, 0.0, 0.86, false], [-0.485, 0.02, 0.0, 0.96, false], [-0.40, 0.0, 0.0, 1.0, false],
		[-0.16, 0.0, 1.0, 1.0, true], [-0.10, 0.0, 1.0, 1.0, false], [0.0, 0.0, 1.0, 1.0, true],
		[0.03, 0.0, 1.0, 1.0, false], [0.10, 0.0, 0.97, 1.0, false], [0.28, 0.03, 0.0, 1.0, false],
		[0.44, 0.12, 0.0, 0.97, false], [0.485, 0.18, 0.0, 0.90, false], [0.50, 0.28, 0.0, 0.80, false],
	],
	# Single-cab pickup: flat load bed, cab forward.
	"pickup": [
		[-0.50, 0.06, 0.0, 0.97, false], [-0.49, 0.0, 0.0, 1.0, false], [-0.10, 0.0, 0.0, 1.0, false],
		[-0.08, 0.0, 1.0, 1.0, true], [-0.03, 0.0, 1.0, 1.0, false], [0.14, 0.0, 0.97, 1.0, false],
		[0.27, 0.02, 0.0, 1.0, false], [0.46, 0.06, 0.0, 0.98, false], [0.49, 0.10, 0.0, 0.95, false],
		[0.50, 0.20, 0.0, 0.88, false],
	],
	# Car-based pickup of the eighties: the nose and cab of the boxy saloon,
	# an open bed where its back seat and boot were.
	"ute": [
		[-0.50, 0.06, 0.0, 0.95, false], [-0.49, 0.0, 0.0, 1.0, false], [-0.07, 0.0, 0.0, 1.0, false],
		[-0.05, 0.0, 1.0, 1.0, true], [0.0, 0.0, 1.0, 1.0, false], [0.11, 0.0, 1.0, 1.0, false],
		[0.20, 0.01, 0.0, 1.0, false], [0.46, 0.05, 0.0, 0.99, false], [0.49, 0.08, 0.0, 0.96, false],
		[0.50, 0.16, 0.0, 0.90, false],
	],
	# Boxy hatchback: the square nose of the saloon, roof carried to a
	# short sloping tailgate.
	"hatch": [
		[-0.50, 0.10, 0.0, 0.90, false], [-0.49, 0.02, 0.0, 0.97, false], [-0.46, 0.0, 0.0, 1.0, false],
		[-0.36, 0.0, 1.0, 1.0, true], [-0.29, 0.0, 1.0, 1.0, false], [-0.03, 0.0, 1.0, 1.0, true],
		[0.01, 0.0, 1.0, 1.0, false], [0.11, 0.0, 1.0, 1.0, false], [0.20, 0.01, 0.0, 1.0, false],
		[0.46, 0.05, 0.0, 0.99, false], [0.49, 0.08, 0.0, 0.96, false], [0.50, 0.16, 0.0, 0.90, false],
	],
	# Modern hatchback: rounded nose, raked screens, high tail.
	"hatch_new": [
		[-0.50, 0.12, 0.0, 0.88, false], [-0.485, 0.02, 0.0, 0.97, false], [-0.46, 0.0, 0.0, 1.0, false],
		[-0.36, 0.0, 0.97, 1.0, true], [-0.28, 0.0, 1.0, 1.0, false], [-0.04, 0.0, 1.0, 1.0, true],
		[0.0, 0.0, 1.0, 1.0, false], [0.10, 0.0, 0.97, 1.0, false], [0.29, 0.02, 0.0, 1.0, false],
		[0.45, 0.10, 0.0, 0.96, false], [0.49, 0.16, 0.0, 0.90, false], [0.50, 0.26, 0.0, 0.80, false],
	],
	# One-box van or minibus: upright tail, long glazed side, stubby nose.
	"van": [
		[-0.50, 0.10, 0.0, 0.94, false], [-0.49, 0.0, 0.0, 0.99, false], [-0.475, 0.0, 1.0, 1.0, true],
		[-0.43, 0.0, 1.0, 1.0, false], [-0.19, 0.0, 1.0, 1.0, true], [-0.16, 0.0, 1.0, 1.0, false],
		[0.07, 0.0, 1.0, 1.0, true], [0.10, 0.0, 1.0, 1.0, false], [0.27, 0.0, 1.0, 1.0, false],
		[0.40, 0.04, 0.0, 1.0, false], [0.47, 0.08, 0.0, 0.98, false], [0.495, 0.12, 0.0, 0.95, false],
		[0.50, 0.20, 0.0, 0.88, false],
	],
}

## style -> [sill height, belt (shoulder) height] in metres.
const STANCE := {
	"sedan": [0.26, 0.88], "boxy": [0.27, 0.87], "wagon": [0.27, 0.87],
	"tuned": [0.20, 0.84], "tuned_small": [0.22, 0.88], "pickup": [0.42, 1.05],
	"van": [0.32, 1.08], "ute": [0.27, 0.87], "hatch": [0.27, 0.87], "hatch_new": [0.23, 0.9],
}


static func stance(style: String) -> Array:
	return STANCE.get(style, STANCE["sedan"])


## length / width / height in metres. The nose points to +Z.
static func build(style: String, length: float, width: float, height: float) -> ArrayMesh:
	var stations: Array = PROFILES.get(style, PROFILES["sedan"])
	var st: Array = stance(style)
	var sill: float = st[0]
	var belt: float = st[1]
	var mid_y := (sill + height) * 0.5

	var rings: Array[PackedVector3Array] = []
	for s in stations:
		var zf: float = s[0]
		var drop: float = s[1]
		var cabin: float = s[2]
		var scale: float = s[3]
		var y_belt := belt - drop
		rings.append(_ring(zf * length, sill, y_belt, y_belt + cabin * (height - belt), width * 0.5 * scale))

	var paint := SurfaceTool.new()
	var glass := SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in stations.size() - 1:
		var cab_a: bool = float(stations[i][2]) > 0.5
		var cab_b: bool = float(stations[i + 1][2]) > 0.5
		var pillar: bool = stations[i][4]
		for k in RING - 1:
			var is_glass := false
			if cab_a and cab_b:
				is_glass = k == SEG_SIDE_WINDOW and not pillar
			elif cab_a != cab_b:
				is_glass = k == SEG_ROOF_TOP  # windscreen or rear screen
			var target := glass if is_glass else paint
			for side in [1.0, -1.0]:
				var flip := Vector3(side, 1, 1)
				var a0: Vector3 = rings[i][k] * flip
				var a1: Vector3 = rings[i][k + 1] * flip
				var b0: Vector3 = rings[i + 1][k] * flip
				var b1: Vector3 = rings[i + 1][k + 1] * flip
				_tri(target, a0, a1, b1, mid_y)
				_tri(target, a0, b1, b0, mid_y)

	# Close the tail and the nose with a fan.
	for ring in [rings[0], rings[rings.size() - 1]]:
		var pts: PackedVector3Array = ring
		var centre := Vector3(0, (pts[0].y + pts[RING - 1].y) * 0.5, pts[0].z)
		for k in RING - 1:
			for side in [1.0, -1.0]:
				var flip := Vector3(side, 1, 1)
				_tri(paint, centre, pts[k] * flip, pts[k + 1] * flip, mid_y)

	# Shared vertices and smooth normals on the body: continuous reflections
	# over the panels instead of flat facets (PC tuning). Glass stays flat.
	paint.index()
	paint.generate_normals()
	glass.generate_normals()
	var mesh := paint.commit()
	glass.commit(mesh)
	return mesh


## Half cross-section at one station: rounded sill, flat door, shoulder,
## then the greenhouse leaning in (tumblehome) up to the roof.
static func _ring(z: float, sill: float, y_belt: float, y_top: float, half_w: float) -> PackedVector3Array:
	var rise := maxf(y_top - y_belt, 0.03)
	var tumble := 0.13 * clampf(rise / 0.45, 0.0, 1.0)
	var low := half_w - 0.04
	return PackedVector3Array([
		Vector3(0, sill, z),
		Vector3(low - 0.07, sill, z),
		Vector3(low, sill + 0.07, z),
		Vector3(half_w, sill + 0.26, z),
		Vector3(half_w, y_belt - 0.06, z),
		Vector3(half_w - 0.05, y_belt, z),
		Vector3(half_w - 0.09, y_belt + rise * 0.06, z),
		Vector3(half_w - 0.09 - tumble, y_belt + rise * 0.92, z),
		Vector3(half_w - 0.20 - tumble, y_belt + rise, z),
		Vector3(0, y_belt + rise + 0.02, z),
	])


## Adds one triangle wound so that its front (clockwise in Godot) faces away
## from the car's centre line, whatever order the corners arrive in.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, mid_y: float) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-10:
		return
	var centroid := (a + b + c) / 3.0
	var outward := centroid - Vector3(0, mid_y, centroid.z * 0.8)
	if normal.dot(outward) > 0.0:
		var swap := b
		b = c
		c = swap
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
