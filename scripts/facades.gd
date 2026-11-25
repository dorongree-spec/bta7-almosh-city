## Painted building fronts, drawn pixel by pixel at load time so the game
## ships no third-party art. Each texture covers two 4 m bays by two storeys
## (the shop front: two bays by one storey) and tiles along a wall.
##
## The looks are the ones you see driving through Beer Sheva:
##   shikun     - sixties/seventies housing blocks: plaster, roll shutters,
##                closed-in balconies, air-conditioner boxes and laundry
##   stone      - Old City sandstone houses with arched windows
##   modern     - clad towers with ribbon windows and glass balconies
##   industrial - corrugated sheds
##   shop       - ground-floor shop fronts with awnings and roller doors
class_name Facades
extends RefCounted

const BAY_PX := 256
const STOREY_PX := 192
const STYLES := ["shikun", "stone", "modern", "industrial", "shop", "office", "mall"]

const GLASS := Color(0.14, 0.19, 0.24)
const SHUTTER := Color(0.84, 0.82, 0.76)
## Washed-out laundry: in the reference photos it reads as soft colour, not bunting.
const LAUNDRY := [Color(0.7, 0.35, 0.32), Color(0.4, 0.5, 0.68), Color(0.92, 0.92, 0.9), Color(0.82, 0.72, 0.45), Color(0.5, 0.6, 0.5), Color(0.78, 0.6, 0.66), Color(0.25, 0.25, 0.28)]
## Closed-in balconies in Shchuna Dalet: aluminium and glass, brown or beige
## roll shutters, the odd green or blue one somebody painted (PC, from photos).
const BALCONY_SHUTTERS := [Color(0.84, 0.82, 0.76), Color(0.55, 0.42, 0.3), Color(0.76, 0.7, 0.58), Color(0.42, 0.55, 0.5)]
const AWNINGS := [Color(0.8, 0.12, 0.1), Color(0.1, 0.4, 0.2), Color(0.1, 0.25, 0.6), Color(0.9, 0.6, 0.05)]

static var _cache := {}


static func material(style: String) -> StandardMaterial3D:
	if not _cache.has(style):
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(_paint(style))
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		# Glossy glass, rough wall: the panes now pick up sky and street in SSR.
		m.roughness_texture = ImageTexture.create_from_image(_glass_roughness(m.albedo_texture.get_image(), 0.6 if style == "modern" else 0.88))
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_add_grain(m, "stone" if style == "stone" else "plaster")
		# Lit windows for the night: same picture, only some of the glass glows.
		m.emission_enabled = true
		m.emission_texture = ImageTexture.create_from_image(_lit_windows(m.albedo_texture.get_image(), style))
		m.emission_energy_multiplier = 0.0
		_cache[style] = m
	return _cache[style]


## 0 = daylight (windows dark), 1 = night (windows lit).
static func set_window_glow(amount: float) -> void:
	for style in _cache:
		var m: StandardMaterial3D = _cache[style]
		m.emission_energy_multiplier = amount * 1.1


## Roughness map: wall everywhere, 0.08 on the glass (same test as _lit_windows).
static func _glass_roughness(albedo: Image, wall: float) -> Image:
	var r := Image.create(albedo.get_width(), albedo.get_height(), false, Image.FORMAT_L8)
	for y in albedo.get_height():
		for x in albedo.get_width():
			var c := albedo.get_pixel(x, y)
			var glass := c.b > c.r + 0.045 and c.r < 0.22 and c.g < 0.36 and c.b < 0.45
			r.set_pixel(x, y, Color(0.08, 0.08, 0.08) if glass else Color(wall, wall, wall))
	r.generate_mipmaps()
	return r


## Emission map: every pane of glass in roughly half of the bays glows warm.
static func _lit_windows(albedo: Image, style: String) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(style) + 1
	var glow := Image.create(albedo.get_width(), albedo.get_height(), false, Image.FORMAT_RGBA8)
	glow.fill(Color.BLACK)
	# Mostly warm rooms, the odd cold TV glow (PC: all read blue-white before).
	var warm := [Color(1.0, 0.68, 0.32), Color(1.0, 0.78, 0.48), Color(0.98, 0.86, 0.62), Color(1.0, 0.6, 0.3), Color(0.55, 0.7, 1.0)]
	for cy in range(0, albedo.get_height(), STOREY_PX):
		for cx in range(0, albedo.get_width(), BAY_PX):
			if rng.randf() > 0.55:
				continue
			var light: Color = warm[rng.randi() % warm.size()]
			for y in range(cy, cy + STOREY_PX):
				for x in range(cx, cx + BAY_PX):
					var c := albedo.get_pixel(x, y)
					# Glass is the only dark, bluish thing painted on a wall.
					if c.b > c.r + 0.045 and c.r < 0.22 and c.g < 0.36 and c.b < 0.45:
						glow.set_pixel(x, y, light)
	# Shop sign boards are lit at night: the board's own colours glow.
	if style.begins_with("shop"):
		for cx in range(0, albedo.get_width(), BAY_PX):
			for y in range(4, 38):
				for x in range(cx + 6, cx + 250):
					glow.set_pixel(x, y, albedo.get_pixel(x, y) * 0.9)
	glow.generate_mipmaps()
	return glow


## Real plaster or stone grain (CC0, assets/textures) as a world-space detail
## layer on top of the painted windows: the painted albedo stays, the wall gets
## relief and a little tonal variation. No-op if the textures are missing.
static var _half_mask: ImageTexture


static func _add_grain(m: StandardMaterial3D, set_name: String) -> void:
	var diff := CityMaterials._tex(set_name + "_diff")
	var nor := CityMaterials._tex(set_name + "_nor")
	if diff == null or nor == null:
		return
	m.detail_enabled = true
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	m.uv2_triplanar = true
	m.uv2_world_triplanar = true
	m.uv2_triplanar_sharpness = 8.0
	m.uv2_scale = Vector3.ONE / (3.0 if set_name == "stone" else 2.0)
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_albedo = diff
	m.detail_normal = nor
	# Half strength: the full photo multiply turned every wall tan (PC tuning).
	if _half_mask == null:
		var img := Image.create(4, 4, false, Image.FORMAT_L8)
		img.fill(Color(0.5, 0.5, 0.5))
		_half_mask = ImageTexture.create_from_image(img)
	m.detail_mask = _half_mask


static func _paint(style: String) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(style)
	var storeys := 1 if style.begins_with("shop") else 2
	var img := Image.create(BAY_PX * 2, STOREY_PX * storeys, false, Image.FORMAT_RGBA8)
	for row in storeys:
		for col in 2:
			var cell := Rect2i(col * BAY_PX, row * STOREY_PX, BAY_PX, STOREY_PX)
			match style.trim_suffix("_b").trim_suffix("_c"):
				"stone":
					_stone_bay(img, cell, rng)
				"modern":
					_modern_bay(img, cell, rng)
				"office":
					_office_bay(img, cell, rng)
				"mall":
					_mall_bay(img, cell, rng, row)
				"industrial":
					_industrial_bay(img, cell, rng, row == 0 and col == 0)
				"shop":
					# Variants: which bay is shut, and whether there is an awning at all.
					var shut_bay := {"shop": 1, "shop_b": 0, "shop_c": -1}.get(style, 1) as int
					_shop_bay(img, cell, rng, col == shut_bay, style != "shop_c")
				_:
					# Closed-in balconies now stand out from the wall in relief (city_dressing),
					# so the painted ones would double up: only one bay in four keeps one.
					# Variants (_b, _c) put it in a different bay and draw their own
					# shutters and stains, so neighbouring blocks stop matching (PC).
					var which: Vector2i = {"shikun": Vector2i(0, 1), "shikun_b": Vector2i(1, 0), "shikun_c": Vector2i(1, 1)}.get(style, Vector2i(0, 1))
					_shikun_bay(img, cell, rng, col == which.x and row == which.y)
	# The white blocks on Avraham Avinu carry a pink-red band along every floor slab.
	if style == "shikun_c":
		for row in storeys:
			img.fill_rect(Rect2i(0, row * STOREY_PX + STOREY_PX - 10, BAY_PX * 2, 10), Color(0.74, 0.36, 0.33))
	img.generate_mipmaps()
	return img


# --- drawing helpers ------------------------------------------------------------------

static func _rect(img: Image, cell: Rect2i, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(cell.position.x + x, cell.position.y + y, w, h).intersection(cell), color)


## Fills the cell with slightly uneven plaster.
static func _plaster(img: Image, cell: Rect2i, rng: RandomNumberGenerator, base: Color, grain: float) -> void:
	for y in range(cell.position.y, cell.end.y):
		for x in range(cell.position.x, cell.end.x):
			img.set_pixel(x, y, base.darkened(rng.randf() * grain))


## A dirty rain streak running down from (x, y); width in pixels.
static func _streak(img: Image, cell: Rect2i, x: int, y: int, length: int, width := 5, strength := 0.16) -> void:
	for i in length:
		var px := cell.position.x + x
		var py := cell.position.y + y + i
		if py >= cell.end.y:
			return
		var fade := 1.0 - float(i) / length
		for dx in width:
			# Softer at the edges of the streak.
			var edge := 1.0 - absf(float(dx) - width * 0.5) / (width * 0.5 + 1.0)
			var c := img.get_pixel(px + dx, py)
			img.set_pixel(px + dx, py, c.darkened(strength * fade * edge))


## Large soft blotches of damp and dust: sixty-year-old plaster is never one colour.
static func _blotches(img: Image, cell: Rect2i, rng: RandomNumberGenerator, count: int) -> void:
	for b in count:
		var cx := rng.randi_range(0, cell.size.x)
		var cy := rng.randi_range(0, cell.size.y)
		var r := rng.randi_range(18, 60)
		var amount := rng.randf_range(0.03, 0.08)
		for y in range(maxi(cy - r, 0), mini(cy + r, cell.size.y)):
			for x in range(maxi(cx - r, 0), mini(cx + r, cell.size.x)):
				var d := Vector2(x - cx, (y - cy) * 1.4).length() / r
				if d < 1.0:
					var p := Vector2i(cell.position.x + x, cell.position.y + y)
					img.set_pixelv(p, img.get_pixelv(p).darkened(amount * (1.0 - d * d)))


## A window with a roll shutter pulled down by `closed` (0..1).
static func _window(img: Image, cell: Rect2i, x: int, y: int, w: int, h: int, closed: float) -> void:
	_rect(img, cell, x - 4, y - 14, w + 8, 14, Color(0.74, 0.73, 0.7))  # shutter box
	_rect(img, cell, x - 3, y, w + 6, h + 3, Color(0.7, 0.72, 0.74))    # frame
	_rect(img, cell, x, y, w, h, GLASS)
	_rect(img, cell, x + w / 2 - 1, y, 3, h, Color(0.7, 0.72, 0.74))    # mullion
	var drop := int(h * closed)
	_rect(img, cell, x, y, w, drop, SHUTTER)
	for sy in range(4, drop, 6):
		_rect(img, cell, x, y + sy, w, 1, SHUTTER.darkened(0.25))
	_rect(img, cell, x - 8, y + h + 3, w + 16, 5, Color(0.8, 0.79, 0.76))  # sill


static func _ac_unit(img: Image, cell: Rect2i, x: int, y: int) -> void:
	_rect(img, cell, x, y, 50, 34, Color(0.93, 0.93, 0.92))
	for i in 5:
		_rect(img, cell, x + 4, y + 6 + i * 5, 28, 1, Color(0.6, 0.6, 0.6))
	_rect(img, cell, x + 36, y + 8, 10, 18, Color(0.72, 0.72, 0.72))
	_streak(img, cell, x + 20, y + 34, 70)


# --- styles ---------------------------------------------------------------------------

static func _shikun_bay(img: Image, cell: Rect2i, rng: RandomNumberGenerator, balcony: bool) -> void:
	_plaster(img, cell, rng, Color(0.93, 0.91, 0.87), 0.07)
	_blotches(img, cell, rng, 5)
	_rect(img, cell, 0, STOREY_PX - 8, BAY_PX, 8, Color(0.8, 0.79, 0.77))  # floor slab edge
	# Grime washed off the slab edge over sixty winters.
	for k in 6:
		_streak(img, cell, rng.randi_range(0, BAY_PX - 12), 0, rng.randi_range(20, 60), rng.randi_range(6, 14), 0.1)
	if not balcony:
		_window(img, cell, 44, 56, 112, 84, rng.randf_range(0.15, 1.0))
		if rng.randf() < 0.8:
			_ac_unit(img, cell, 188, 108)
		_streak(img, cell, 50, 148, 40, 10, 0.22)
		_streak(img, cell, 130, 148, 30, 8, 0.18)
		return
	# A balcony that was closed in during the eighties, as they all were.
	_rect(img, cell, 20, 40, 216, 112, Color(0.62, 0.63, 0.64))  # aluminium frame
	_rect(img, cell, 24, 44, 208, 62, GLASS)
	for p in 4:
		var px := 24 + p * 52
		if rng.randf() < 0.6:
			var shut: Color = BALCONY_SHUTTERS[rng.randi() % BALCONY_SHUTTERS.size()]
			var drop := rng.randi_range(30, 62)
			_rect(img, cell, px, 44, 50, drop, shut)
			for sy in range(4, drop, 6):
				_rect(img, cell, px, 44 + sy, 50, 1, shut.darkened(0.22))
		_rect(img, cell, px + 50, 44, 2, 62, Color(0.62, 0.63, 0.64))
	_rect(img, cell, 24, 106, 208, 46, Color(0.86, 0.85, 0.82))  # parapet
	_rect(img, cell, 20, 104, 216, 4, Color(0.55, 0.56, 0.57))    # rail
	_streak(img, cell, 30, 152, 36, 180, 0.12)  # dirt below the parapet
	# Laundry on the line under the parapet.
	_rect(img, cell, 20, 156, 216, 1, Color(0.3, 0.3, 0.3))
	var lx := 30
	while lx < 210:
		var lw := rng.randi_range(14, 30)
		if rng.randf() < 0.7:
			_rect(img, cell, lx, 157, lw, rng.randi_range(14, 24), LAUNDRY[rng.randi() % LAUNDRY.size()])
		lx += lw + 6


static func _stone_bay(img: Image, cell: Rect2i, rng: RandomNumberGenerator) -> void:
	_plaster(img, cell, rng, Color(0.95, 0.9, 0.8), 0.1)
	# Ashlar courses with staggered joints.
	var course := 0
	for y in range(0, STOREY_PX, 24):
		_rect(img, cell, 0, y, BAY_PX, 2, Color(0.72, 0.66, 0.55))
		for x in range(24 if course % 2 == 0 else 0, BAY_PX, 48):
			_rect(img, cell, x, y, 2, 24, Color(0.74, 0.68, 0.57))
		course += 1
	# Tall arched window with wooden shutters folded open on both sides.
	var wx := 98
	var wy := 62
	var ww := 60
	var wh := 96
	var wood := Color(0.18, 0.45, 0.46) if rng.randf() < 0.6 else Color(0.2, 0.32, 0.55)
	_rect(img, cell, wx - 6, wy - 4, ww + 12, wh + 8, Color(0.8, 0.74, 0.62))
	_rect(img, cell, wx, wy, ww, wh, GLASS)
	var r := ww / 2 + 6
	for dy in range(0, r):
		var half := int(sqrt(float(r * r - dy * dy)))
		_rect(img, cell, wx + ww / 2 - half, wy - 4 - dy, half * 2, 1, Color(0.8, 0.74, 0.62))
		if dy < r - 6:
			var inner := int(sqrt(float((r - 6) * (r - 6) - dy * dy)))
			_rect(img, cell, wx + ww / 2 - inner, wy - dy, inner * 2, 1, GLASS)
	for side in [wx - 34, wx + ww + 6]:
		_rect(img, cell, side, wy, 28, wh, wood)
		for sy in range(6, wh, 8):
			_rect(img, cell, side + 3, wy + sy, 22, 2, wood.darkened(0.3))
	_rect(img, cell, wx + ww / 2 - 1, wy, 2, wh, Color(0.85, 0.85, 0.8))


## Beer Sheva's newer towers (Ramot, Nahal Ashan, the centre) are flats, not
## offices: beige stone cladding, a pair of windows with grey roll shutters,
## and a recessed balcony with a glass rail in every other bay (PC, photos).
static func _modern_bay(img: Image, cell: Rect2i, rng: RandomNumberGenerator) -> void:
	_plaster(img, cell, rng, Color(0.93, 0.88, 0.79), 0.05)
	# Stone courses: 32 px rows, joints offset every other row.
	for y in range(0, STOREY_PX, 32):
		_rect(img, cell, 0, y, BAY_PX, 1, Color(0.8, 0.74, 0.64))
		var shift := 0 if (y / 32) % 2 == 0 else 40
		for x in range(shift, BAY_PX, 80):
			_rect(img, cell, x, y, 1, 32, Color(0.8, 0.74, 0.64))
	var balcony := rng.randf() < 0.5
	if balcony:
		# Recess in shadow, sliding door, glass rail with a steel top.
		_rect(img, cell, 20, 24, 216, 150, Color(0.42, 0.38, 0.33))
		_rect(img, cell, 60, 34, 136, 120, GLASS)
		_rect(img, cell, 126, 34, 4, 120, Color(0.7, 0.71, 0.72))
		if rng.randf() < 0.6:
			_rect(img, cell, 60, 34, 66, 120, Color(0.78, 0.76, 0.72))  # a curtain drawn
		_rect(img, cell, 20, 120, 216, 54, Color(0.5, 0.62, 0.66))
		_rect(img, cell, 20, 118, 216, 3, Color(0.72, 0.73, 0.75))
	else:
		for wx in [34, 140]:
			_window(img, cell, wx, 58, 82, 80, rng.randf_range(0.1, 0.9))
		if rng.randf() < 0.6:
			_ac_unit(img, cell, 100, 128)
	_rect(img, cell, 0, STOREY_PX - 8, BAY_PX, 8, Color(0.84, 0.79, 0.7))

## Offices, courts and the hospital: pale stone with a strip of tinted glass.
static func _office_bay(img: Image, cell: Rect2i, rng: RandomNumberGenerator) -> void:
	_plaster(img, cell, rng, Color(0.92, 0.88, 0.8), 0.03)
	for y in range(0, STOREY_PX, 48):
		_rect(img, cell, 0, y, BAY_PX, 1, Color(0.8, 0.76, 0.68))
	_rect(img, cell, 0, 60, BAY_PX, 76, Color(0.2, 0.22, 0.24))
	_rect(img, cell, 0, 64, BAY_PX, 68, Color(0.2, 0.3, 0.38))
	for x in range(0, BAY_PX, 64):
		_rect(img, cell, x, 64, 4, 68, Color(0.62, 0.64, 0.66))
	if rng.randf() < 0.5:
		_rect(img, cell, 68, 64, 60, 68, Color(0.8, 0.79, 0.74))  # a blind down
	_rect(img, cell, 0, STOREY_PX - 8, BAY_PX, 8, Color(0.82, 0.78, 0.7))


## A mall: big panels of beige stone, a high band of dark glass on the upper
## floor and a red accent stripe, the way the Negev Mall dresses (PC, photos).
static func _mall_bay(img: Image, cell: Rect2i, rng: RandomNumberGenerator, row: int) -> void:
	_plaster(img, cell, rng, Color(0.93, 0.89, 0.81), 0.03)
	for y in range(0, STOREY_PX, 64):
		_rect(img, cell, 0, y, BAY_PX, 2, Color(0.8, 0.75, 0.66))
	for x in range(0, BAY_PX, 128):
		_rect(img, cell, x, 0, 2, STOREY_PX, Color(0.8, 0.75, 0.66))
	if row == 0:
		_rect(img, cell, 0, 40, BAY_PX, 50, Color(0.16, 0.2, 0.25))
		for x in range(0, BAY_PX, 32):
			_rect(img, cell, x, 40, 2, 50, Color(0.55, 0.57, 0.6))
	else:
		_rect(img, cell, 0, 120, BAY_PX, 10, Color(0.7, 0.14, 0.12))


static func _industrial_bay(img: Image, cell: Rect2i, rng: RandomNumberGenerator, door: bool) -> void:
	_plaster(img, cell, rng, Color(0.86, 0.87, 0.88), 0.05)
	for x in range(0, BAY_PX, 8):
		_rect(img, cell, x, 0, 3, STOREY_PX, Color(0.74, 0.75, 0.77))
	_rect(img, cell, 30, 26, 196, 30, GLASS)
	for x in range(30, 226, 49):
		_rect(img, cell, x, 26, 3, 30, Color(0.5, 0.5, 0.5))
	if door:
		_rect(img, cell, 40, 76, 176, 116, Color(0.35, 0.42, 0.5))
		for y in range(80, 192, 10):
			_rect(img, cell, 40, y, 176, 2, Color(0.25, 0.3, 0.38))
	_streak(img, cell, rng.randi_range(20, 220), 0, 120)


## Sign boards and the strokes of their Hebrew lettering (PC, from the Kakal
## and Gilat photos: every makolet has its own board, not one striped awning).
const SIGN_BOARDS := [Color(0.95, 0.94, 0.9), Color(0.96, 0.8, 0.15), Color(0.12, 0.3, 0.6), Color(0.1, 0.45, 0.25), Color(0.72, 0.12, 0.1), Color(0.15, 0.15, 0.17)]


static func _shop_bay(img: Image, cell: Rect2i, rng: RandomNumberGenerator, shut: bool, awning_on := true) -> void:
	_plaster(img, cell, rng, Color(0.9, 0.89, 0.86), 0.06)
	# The sign board, with a line of right-aligned "lettering".
	var board: Color = SIGN_BOARDS[rng.randi() % SIGN_BOARDS.size()]
	var ink := Color(0.1, 0.1, 0.12) if board.get_luminance() > 0.5 else Color(0.97, 0.96, 0.92)
	if rng.randf() < 0.3:
		ink = Color(0.8, 0.1, 0.08) if board.get_luminance() > 0.5 else Color(0.98, 0.85, 0.2)
	_rect(img, cell, 6, 4, 244, 34, board)
	var x := 236
	while x > 40:
		var w := rng.randi_range(5, 14)
		_rect(img, cell, x - w, 12 + rng.randi_range(0, 3), w, rng.randi_range(9, 14), ink)
		x -= w + (rng.randi_range(8, 16) if rng.randf() < 0.18 else 3)
	if awning_on:
		var awning: Color = AWNINGS[rng.randi() % AWNINGS.size()]
		for sx in range(0, BAY_PX, 32):
			_rect(img, cell, sx, 40, 16, 22, awning)
			_rect(img, cell, sx + 16, 40, 16, 22, Color(0.95, 0.94, 0.9))
	_rect(img, cell, 0, 64, BAY_PX, 3, Color(0.3, 0.3, 0.3))
	if shut:
		# Roller door down, with a quick tag sprayed on it.
		_rect(img, cell, 16, 72, 224, 116, Color(0.62, 0.64, 0.66))
		for y in range(76, 188, 7):
			_rect(img, cell, 16, y, 224, 2, Color(0.45, 0.47, 0.5))
		var spray: Color = LAUNDRY[rng.randi() % LAUNDRY.size()]
		for i in 9:
			_rect(img, cell, 50 + i * 14, 120 + int(sin(i * 1.3) * 16.0), 16, 5, spray)
	else:
		_rect(img, cell, 12, 72, 232, 116, Color(0.25, 0.26, 0.28))
		_rect(img, cell, 16, 76, 144, 108, Color(0.2, 0.28, 0.33))
		# Goods stacked in the window: crates, bottles, a poster.
		for g in 6:
			var gx := 22 + g * 22
			_rect(img, cell, gx, 150 - rng.randi_range(0, 30), 18, 34, Color(rng.randf_range(0.3, 0.9), rng.randf_range(0.25, 0.8), rng.randf_range(0.2, 0.6)))
		_rect(img, cell, 168, 76, 72, 112, Color(0.16, 0.22, 0.27))  # door
		_rect(img, cell, 228, 128, 5, 16, Color(0.8, 0.8, 0.8))

