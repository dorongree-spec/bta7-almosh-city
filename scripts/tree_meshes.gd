## Tree crowns, built once and shared by every tree in town.
##
## A ficus crown is a clump of lumpy, smooth-shaded balls of leaves that is
## darker underneath; a date-palm crown is two rings of long fronds, the
## outer ones drooping. Both carry their shading in vertex colours, so one
## leaf material covers them.
class_name TreeMeshes
extends RefCounted

const FICUS_GREEN := Color(0.2, 0.33, 0.15)
const PALM_GREEN := Color(0.27, 0.4, 0.17)
const PALM_TIP := Color(0.45, 0.47, 0.2)
## Balls of leaves in a ficus crown: [centre, radius], metres.
const FICUS_BLOBS := [
	[Vector3(0.0, 0.0, 0.0), 1.7],
	[Vector3(1.25, -0.25, 0.4), 1.2],
	[Vector3(-1.15, -0.15, -0.5), 1.25],
	[Vector3(0.25, 0.05, 1.25), 1.1],
	[Vector3(-0.3, 0.15, -1.25), 1.15],
	[Vector3(0.1, 0.85, 0.1), 1.25],
]
## Balls of leaves in a bush, same form.
const BUSH_BLOBS := [
	[Vector3(0.0, 0.0, 0.0), 1.0],
	[Vector3(0.45, -0.15, 0.3), 0.75],
	[Vector3(-0.4, -0.2, -0.35), 0.7],
]
const RINGS := 6
const SEGMENTS := 9
const FROND_STEPS := 6

## Bushes sit low, where the crown shading made them nearly black; lift them.
const BUSH_BRIGHT := 0.3
static var _ficus: ArrayMesh
static var _palm: ArrayMesh
static var _bush: ArrayMesh
static var _leaves: StandardMaterial3D
static var _fronds: StandardMaterial3D
static var _bark: StandardMaterial3D
## Leaf-cluster cards (ficus) and frond texture (palm), see tools/gen_foliage.gd.
const LEAF_TEX := "res://assets/textures/leaf_cluster.png"
const FROND_TEX := "res://assets/textures/palm_frond.png"


## Two-sided, coloured by the mesh's own vertex colours; with the CC0 leaf
## atlas installed, an alpha-cut cluster of real leaves on every card.
static func leaf_material() -> StandardMaterial3D:
	if _leaves == null:
		_leaves = _foliage(LEAF_TEX)
	return _leaves


static func palm_material() -> StandardMaterial3D:
	if _fronds == null:
		_fronds = _foliage(FROND_TEX)
	return _fronds


## Photographic bark (CC0, assets/textures/bark_*), world-mapped.
static func bark_material(tint: Color) -> Material:
	if _bark == null:
		var photo := CityMaterials._photo("bark", 1.2, Color(0.55, 0.48, 0.42))  # darker: trunks read as pale posts in sun
		_bark = photo if photo else CityMaterials.color(tint, 1.0)
	return _bark


static func _foliage(path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.45
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		# Light coming through the leaves from behind.
		m.backlight_enabled = true
		m.backlight = Color(0.25, 0.3, 0.12)
	return m


## Bougainvillea and oleander: the same alpha-cut clusters, recoloured magenta
## and pink. Beer Sheva's yards and kerbs are full of them (PC, from photos).
static var _flowers: StandardMaterial3D


static func flower_material() -> StandardMaterial3D:
	if _flowers == null:
		_flowers = _foliage(LEAF_TEX)
		_flowers.vertex_color_use_as_albedo = false
		var tex := load(LEAF_TEX) as Texture2D if ResourceLoader.exists(LEAF_TEX) else null
		if tex:
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.05:
						var lum := clampf((c.r + c.g + c.b) * 1.6, 0.35, 1.0)
						var pink := Color(0.86, 0.12, 0.52).lerp(Color(0.97, 0.55, 0.72), fposmod(float(x * 7 + y * 13) * 0.01, 1.0) * 0.5)
						img.set_pixel(x, y, Color(pink.r * lum, pink.g * lum, pink.b * lum, c.a))
			img.generate_mipmaps()
			_flowers.albedo_texture = ImageTexture.create_from_image(img)
		_flowers.backlight = Color(0.3, 0.05, 0.15)
	return _flowers


static func has_leaf_cards() -> bool:
	return ResourceLoader.exists(LEAF_TEX)


## About 5 m across and 3.5 m tall, centred on the origin.
static func ficus_crown() -> ArrayMesh:
	if _ficus == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for blob: Array in FICUS_BLOBS:
			var centre: Vector3 = blob[0]
			var radius: float = blob[1]
			if has_leaf_cards():
				_add_cards(st, centre, radius, rng)
			else:
				_add_blob(st, centre, radius, rng)
		_ficus = st.commit()
	return _ficus


## A bush about 2 m across and waist high, centred on the origin: a few
## small balls of the same leaves a ficus carries. Whoever plants it lifts
## and scales it (CityDressing does, by the thousand).
static func bush() -> ArrayMesh:
	if _bush == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 23
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var bloom := SurfaceTool.new()
		bloom.begin(Mesh.PRIMITIVE_TRIANGLES)
		for blob: Array in BUSH_BLOBS:
			var centre: Vector3 = blob[0]
			var radius: float = blob[1]
			if has_leaf_cards():
				_add_cards(st, centre, radius, rng, BUSH_BRIGHT)
				# A sprinkle of flower clusters on the outside of each ball.
				_add_cards(bloom, centre, radius * 0.55, rng, BUSH_BRIGHT)
			else:
				_add_blob(st, centre, radius, rng)
		_bush = st.commit()
		_bush.surface_set_material(0, leaf_material())
		if has_leaf_cards():
			bloom.commit(_bush)
			_bush.surface_set_material(1, flower_material())
	return _bush


## Fronds reaching about 3.3 m out from the origin, which sits on top of the trunk.
static func palm_crown() -> ArrayMesh:
	if _palm == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Outer ring: long and drooping.
		for i in 13:
			_add_frond(st, TAU * i / 13.0 + rng.randf_range(-0.15, 0.15), rng.randf_range(2.9, 3.5), 0.75, rng.randf_range(1.5, 2.1))
		# Inner ring: shorter and more upright.
		for i in 8:
			_add_frond(st, TAU * i / 8.0 + rng.randf_range(0.1, 0.5), rng.randf_range(2.0, 2.6), 1.5, rng.randf_range(0.3, 0.8))
		_palm = st.commit()
	return _palm


## Leaf cards for one ball of the crown: alpha-cut clusters scattered over the
## ball at random angles. Normals point away from the crown's centre so the
## whole crown shades like one soft volume instead of flat cards.
static func _add_cards(st: SurfaceTool, centre: Vector3, radius: float, rng: RandomNumberGenerator, bright := 0.0) -> void:
	var tint := rng.randf_range(0.85, 1.1)
	var count := int(radius * 8.0)  # PC: 11 cost ~10 fps across the city; TAA keeps 8 dense enough
	for n in count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1.0), rng.randf_range(-1, 1)).normalized()
		var at := centre + Vector3(dir.x, dir.y * 0.8, dir.z) * radius * rng.randf_range(0.45, 0.95)
		var size := radius * rng.randf_range(0.85, 1.25)
		# A random plane, tilted towards facing outwards.
		var facing := (dir + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))).normalized()
		var u := facing.cross(Vector3.UP if absf(facing.y) < 0.95 else Vector3.RIGHT).normalized()
		var v := facing.cross(u).normalized()
		var spin := rng.randf() * TAU
		var a := (u * cos(spin) + v * sin(spin)) * size * 0.5
		var b := (-u * sin(spin) + v * cos(spin)) * size * 0.5
		var corners := [at - a - b, at + a - b, at + a + b, at - a + b]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i: int in [0, 1, 2, 0, 2, 3]:
			var p: Vector3 = corners[i]
			var light := (lerpf(0.55, 1.15, clampf((p.y + 1.6) / 3.2, 0.0, 1.0)) + bright) * tint
			st.set_normal((p - Vector3(0, -0.4, 0)).normalized())
			st.set_color(Color(light, light, light))
			st.set_uv(uvs[i])
			st.add_vertex(p)


## One ball of leaves: a sphere with every point pushed in or out a little.
static func _add_blob(st: SurfaceTool, centre: Vector3, radius: float, rng: RandomNumberGenerator) -> void:
	var tint := rng.randf_range(0.85, 1.1)
	var dirs := PackedVector3Array()
	var points := PackedVector3Array()
	for ring in RINGS + 1:
		var lat := PI * ring / float(RINGS)  # 0 at the top, PI at the bottom
		for seg in SEGMENTS:
			var lon := TAU * seg / float(SEGMENTS)
			var dir := Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon))
			var lump := 1.0 if (ring == 0 or ring == RINGS) else rng.randf_range(0.82, 1.12)
			dirs.append(dir)
			points.append(centre + Vector3(dir.x, dir.y * 0.8, dir.z) * radius * lump)
	for ring in RINGS:
		for seg in SEGMENTS:
			var a := ring * SEGMENTS + seg
			var b := ring * SEGMENTS + (seg + 1) % SEGMENTS
			var c := a + SEGMENTS
			var d := b + SEGMENTS
			for i: int in [a, c, b, b, c, d]:
				var p := points[i]
				# Leaves low in the crown sit in its shade.
				var light := lerpf(0.6, 1.15, clampf((p.y + 1.6) / 3.2, 0.0, 1.0)) * tint
				st.set_normal(dirs[i])
				st.set_color(Color(FICUS_GREEN.r * light, FICUS_GREEN.g * light, FICUS_GREEN.b * light))
				st.add_vertex(p)


## One palm frond: a tapering strip that leaves the trunk at `angle`, climbs
## by `lift` and then sags by `droop` over its `length` (all metres).
static func _add_frond(st: SurfaceTool, angle: float, length: float, lift: float, droop: float) -> void:
	var out := Vector3(sin(angle), 0.0, cos(angle))
	var side := Vector3(out.z, 0.0, -out.x)
	var last_left := Vector3.ZERO
	var last_right := Vector3.ZERO
	var last_color := PALM_GREEN
	for step in FROND_STEPS + 1:
		var t := step / float(FROND_STEPS)
		var spine := out * (length * t) + Vector3.UP * (lift * t - droop * t * t)
		# Wider when the frond texture carries the leaflets (alpha-cut).
		var half := (0.62 if ResourceLoader.exists(FROND_TEX) else 0.34) * sin(PI * (0.08 + t * 0.92)) + 0.02
		var left := spine - side * half
		var right := spine + side * half
		var color := PALM_GREEN.lerp(PALM_TIP, t * 0.5)
		if step > 0:
			var normal := (right - last_left).cross(left - last_left).normalized()
			if normal.y < 0.0:
				normal = -normal
			var corners := [last_left, last_right, right, last_left, right, left]
			var colors := [last_color, last_color, color, last_color, color, color]
			var t0 := (step - 1) / float(FROND_STEPS)
			var uvs := [Vector2(0, t0), Vector2(1, t0), Vector2(1, t), Vector2(0, t0), Vector2(1, t), Vector2(0, t)]
			for i in 6:
				st.set_normal(normal)
				st.set_color(colors[i].lightened(0.6) if ResourceLoader.exists(FROND_TEX) else colors[i])
				st.set_uv(uvs[i])
				st.add_vertex(corners[i])
		last_left = left
		last_right = right
		last_color = color
