## Builds the foliage textures used by TreeMeshes from CC0 sources.
##
##   godot --headless --path . --script tools/gen_foliage.gd -- <LeafSet024 folder>
##
## leaf_cluster.png: a 1024x1024 card of a few hundred small leaves (cut from
## ambientCG LeafSet024, CC0), rotated and scaled at random, darker towards
## the back, with alpha. palm_frond.png: a date-palm frond (spine plus
## tapering leaflets) drawn from scratch, with alpha. Both go to
## assets/textures/ (see assets/CREDITS.md).
extends SceneTree

const OUT := "res://assets/textures/"


func _initialize() -> void:
	var src := OS.get_cmdline_user_args()[0]
	var color := Image.load_from_file(src + "/LeafSet024_1K-JPG_Color.jpg")
	var alpha := Image.load_from_file(src + "/LeafSet024_1K-JPG_Opacity.jpg")
	color.convert(Image.FORMAT_RGBA8)
	alpha.convert(Image.FORMAT_RGBA8)
	_leaf_cluster(color, alpha)
	_palm_frond()
	quit()


## One leaf of the 3x3 atlas as an RGBA image with its opacity as alpha.
func _cell(color: Image, alpha: Image, i: int) -> Image:
	var w := color.get_width() / 3
	var h := color.get_height() / 3
	var leaf := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var ox := (i % 3) * w
	var oy := (i / 3) * h
	for y in h:
		for x in w:
			var c := color.get_pixel(ox + x, oy + y)
			c.a = alpha.get_pixel(ox + x, oy + y).r
			leaf.set_pixel(x, y, c)
	return leaf


func _leaf_cluster(color: Image, alpha: Image) -> void:
	var size := 1024
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.2, 0.3, 0.12, 0.0))
	var leaves: Array[Image] = []
	for i in 9:
		var leaf := _cell(color, alpha, i)
		leaf.resize(56, 56, Image.INTERPOLATE_BILINEAR)
		leaves.append(leaf)
	var rng := RandomNumberGenerator.new()
	rng.seed = 24
	var centre := Vector2(size, size) * 0.5
	for n in 900:
		# Denser in the middle, ragged at the edge.
		var r := sqrt(rng.randf()) * size * 0.47
		var a := rng.randf() * TAU
		var at := centre + Vector2(cos(a), sin(a)) * r
		var leaf: Image = leaves[rng.randi() % leaves.size()]
		var rot := rng.randf() * TAU
		var scale := rng.randf_range(0.7, 1.25)
		# Leaves further back (drawn first) are in the crown's own shade.
		var shade := lerpf(0.45, 1.05, float(n) / 900.0) * rng.randf_range(0.85, 1.1)
		_stamp(out, leaf, at, rot, scale, shade)
	out.generate_mipmaps()
	out.save_png(ProjectSettings.globalize_path(OUT + "leaf_cluster.png"))
	print("leaf_cluster.png written")


## Draws `leaf` centred at `at`, rotated and scaled, alpha-blended.
func _stamp(out: Image, leaf: Image, at: Vector2, rot: float, scale: float, shade: float) -> void:
	var w := leaf.get_width()
	var h := leaf.get_height()
	var reach := int(ceil(maxf(w, h) * scale * 0.75))
	var c := cos(-rot)
	var s := sin(-rot)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var px := int(at.x) + dx
			var py := int(at.y) + dy
			if px < 0 or py < 0 or px >= out.get_width() or py >= out.get_height():
				continue
			# Inverse-map the output pixel into the leaf image.
			var lx := (dx * c - dy * s) / scale + w * 0.5
			var ly := (dx * s + dy * c) / scale + h * 0.5
			if lx < 0 or ly < 0 or lx >= w or ly >= h:
				continue
			var src := leaf.get_pixel(int(lx), int(ly))
			if src.a < 0.05:
				continue
			var dst := out.get_pixel(px, py)
			var col := Color(src.r * shade, src.g * shade, src.b * shade)
			var a := src.a
			out.set_pixel(px, py, Color(lerpf(dst.r, col.r, a), lerpf(dst.g, col.g, a), lerpf(dst.b, col.b, a), maxf(dst.a, a)))


## A date-palm frond seen from above: spine along V, leaflets angled out.
func _palm_frond() -> void:
	var w := 256
	var h := 1024
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.25, 0.35, 0.15, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var spine := Color(0.55, 0.5, 0.3, 1.0)
	for y in h:
		for x in range(w / 2 - 3, w / 2 + 3):
			out.set_pixel(x, y, spine)
	var y0 := 40
	while y0 < h - 10:
		var t := float(y0) / h
		var length := (w * 0.5 - 6) * (0.35 + 0.65 * sin(PI * minf(1.0, t * 1.1)))
		for side in [-1, 1]:
			var col := Color(0.24, 0.36, 0.14).lerp(Color(0.42, 0.46, 0.2), t * 0.6 + rng.randf() * 0.15)
			var steps := int(length)
			for k in steps:
				var u := float(k) / steps
				var x: int = w / 2 + side * (3 + k)
				var y := y0 + int(k * 0.75)  # leaflets sweep towards the tip
				var half := int(round(lerpf(3.0, 0.5, u)))
				for dy in range(-half, half + 1):
					if y + dy >= 0 and y + dy < h and x >= 0 and x < w:
						out.set_pixel(x, y + dy, col.darkened(0.15 * abs(dy) / max(1, half)))
		y0 += 14 + rng.randi() % 5
	out.generate_mipmaps()
	out.save_png(ProjectSettings.globalize_path(OUT + "palm_frond.png"))
	print("palm_frond.png written")
