## PBR materials for the city. Ground, roads, pavements and roofs use CC0 photo
## textures from Poly Haven (assets/textures, see assets/CREDITS.md) mapped in
## world space; anything missing falls back to a texture generated at load time.
class_name CityMaterials
extends RefCounted

static var _cache := {}
const TEX_DIR := "res://assets/textures/"


## A CC0 texture from assets/textures, or null if it is not installed.
static func _tex(file: String) -> Texture2D:
	var path := TEX_DIR + file + ".jpg"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## World-space PBR material from assets/textures/<set>_{diff,nor,rough}.jpg,
## tiled every metres. Returns null if the set is not installed.
static func _photo(set_name: String, metres: float, tint := Color.WHITE) -> StandardMaterial3D:
	var diff := _tex(set_name + "_diff")
	if diff == null:
		return null
	var m := StandardMaterial3D.new()
	m.albedo_texture = diff
	m.albedo_color = tint
	var nor := _tex(set_name + "_nor")
	if nor:
		m.normal_enabled = true
		m.normal_texture = nor
	var rough := _tex(set_name + "_rough")
	if rough:
		m.roughness_texture = rough
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE / metres
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Roads: photographic asphalt in world space, lane paint from the ribbon UVs.
const ROAD_SHADER := """
shader_type spatial;
uniform sampler2D asphalt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paint : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float metres = 5.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float sheen = 0.0;
varying vec2 world_uv;
void vertex() {
	world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz / metres;
}
uniform sampler2D grime : filter_linear_mipmap, repeat_enable;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec3 base = texture(asphalt, world_uv).rgb * tint;
	// Patches: some 4-7 m cells were resurfaced, newer and darker or older and paler.
	vec2 cell = floor(world_uv * metres / vec2(5.5, 3.5));
	float h = hash(cell);
	if (h > 0.86) {
		base *= mix(0.72, 1.18, hash(cell + 7.0));
	}
	// Oil drips down the middle of the lane and grime towards the kerbs.
	float n = texture(grime, world_uv * 0.21).r;
	float lane = 1.0 - abs(UV.x - 0.5) * 2.0;
	float oil = smoothstep(0.62, 0.78, n) * smoothstep(0.35, 0.8, lane);
	base *= 1.0 - oil * 0.45;
	float kerb = smoothstep(0.75, 1.0, abs(UV.x - 0.5) * 2.0);
	base = mix(base, base * vec3(1.08, 1.0, 0.86), kerb * 0.6);
	// Worn paint: the asphalt grain shows through the lines.
	float p = texture(paint, UV).r * (0.75 + 0.25 * texture(asphalt_rough, world_uv * 0.37).g);
	// Israeli kerb paint on the edge lines: red-white (no stopping) or
	// blue-white (paid parking) in 1 m blocks, chosen per 60 m of street.
	vec3 paint_col = vec3(0.86, 0.85, 0.8);
	float edge = step(0.9, abs(UV.x - 0.5) * 2.0);
	vec2 stretch = floor(world_uv * metres / 60.0);
	float which = hash(stretch + 3.1);
	float block = step(0.5, fract(UV.y * 8.0));
	if (edge > 0.5 && which < 0.55) {
		vec3 colour = which < 0.3 ? vec3(0.72, 0.1, 0.08) : vec3(0.1, 0.25, 0.62);
		paint_col = mix(paint_col, colour, block);
	}
	ALBEDO = mix(base, paint_col, p);
	NORMAL_MAP = texture(asphalt_nor, world_uv).rgb;
	NORMAL_MAP_DEPTH = mix(1.0, 0.3, p);
	// At night the worn surface picks up lamps and headlights (sheen 0..1, set by DayNight).
	ROUGHNESS = mix(texture(asphalt_rough, world_uv).g, 0.55, p) * (1.0 - sheen * 0.55);
	SPECULAR = 0.5 + sheen * 0.3;
}
"""


static func _cached(key: String, maker: Callable) -> Material:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


## Noise texture helper (seamless, tiling).
static func _noise(freq: float, as_normal := false, seed_value := 1) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	t.as_normal_map = as_normal
	t.bump_strength = 4.0
	return t


static func roof() -> Material:
	return _cached("roof", func():
		# Lighter: Beer Sheva roofs are pale (silver bitumen, whitewash), not brown.
		var photo := _photo("roof", 6.0, Color(1.25, 1.24, 1.2))
		if photo:
			# Weathered concrete, tinted per building by the vertex colour.
			photo.vertex_color_use_as_albedo = true
			photo.vertex_color_is_srgb = true
			return photo
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		# Vertex colours are authored as sRGB; without this Godot reads them
		# as linear and flat roofs come out near-white in full sun.
		m.vertex_color_is_srgb = true
		m.albedo_texture = _noise(0.05, false, 5)
		m.roughness = 0.95
		return m)


## Asphalt; `marked` adds a dashed centreline (UV.y in 8 m units).
static func asphalt(marked: bool) -> Material:
	return _cached("asphalt_%s" % marked, func():
		var road := _tex("asphalt_diff")
		if road:
			# Paint mask only: white where the lines are, the shader does the rest.
			var mask := Image.create(64, 256, true, Image.FORMAT_L8)
			mask.fill(Color.BLACK)
			if marked:
				mask.fill_rect(Rect2i(30, 0, 4, 128), Color.WHITE)
			mask.fill_rect(Rect2i(1, 0, 2, 256), Color.WHITE)
			mask.fill_rect(Rect2i(61, 0, 2, 256), Color.WHITE)
			mask.generate_mipmaps()
			var shader := Shader.new()
			shader.code = ROAD_SHADER
			var sm := ShaderMaterial.new()
			sm.shader = shader
			sm.set_shader_parameter("asphalt", road)
			sm.set_shader_parameter("asphalt_nor", _tex("asphalt_nor"))
			sm.set_shader_parameter("asphalt_rough", _tex("asphalt_rough"))
			sm.set_shader_parameter("paint", ImageTexture.create_from_image(mask))
			sm.set_shader_parameter("tint", Color(0.62, 0.62, 0.64))  # the photo is a light, worn asphalt
			sm.set_shader_parameter("grime", _noise(0.02, false, 31))
			return sm
		var img := Image.create(64, 256, true, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for y in 256:
			for x in 64:
				var g := 0.2 + rng.randf() * 0.07
				img.set_pixel(x, y, Color(g, g, g * 1.03))
		if marked:
			img.fill_rect(Rect2i(30, 0, 4, 128), Color(0.9, 0.88, 0.8))
		img.fill_rect(Rect2i(1, 0, 2, 256), Color(0.85, 0.85, 0.8))  # edge lines
		img.fill_rect(Rect2i(61, 0, 2, 256), Color(0.85, 0.85, 0.8))
		img.generate_mipmaps()
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.roughness = 0.9
		m.normal_enabled = true
		m.normal_texture = _noise(0.3, true, 13)
		m.normal_scale = 0.25
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		return m)


## Night sheen on every road material (0 by day, 1 at night).
static func set_road_sheen(amount: float) -> void:
	for key in ["asphalt_true", "asphalt_false"]:
		var m = _cache.get(key)
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("sheen", amount)


static func pavement() -> Material:
	return _cached("pavement", func():
		# Square concrete slabs, ~0.5 m, the standard Israeli pavement.
		var photo := _photo("pavers", 2.0, Color(0.74, 0.8, 0.88))  # neutralise the warm photo to grey concrete
		if photo:
			return photo
		var img := Image.create(64, 64, true, Image.FORMAT_RGBA8)
		# Tuned on the PC: at 0.74 the slabs clipped to pure white under the
		# 1.6 sun + sky ambient + SDFGI bounce. Real concrete is ~0.4-0.55.
		img.fill(Color(0.55, 0.53, 0.49))
		for i in range(0, 64, 16):
			img.fill_rect(Rect2i(i, 0, 1, 64), Color(0.42, 0.4, 0.37))
			img.fill_rect(Rect2i(0, i, 64, 1), Color(0.42, 0.4, 0.37))
		img.generate_mipmaps()
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.roughness = 0.9
		return m)


## The Old City's pedestrian streets: the same slabs in faded red and pink.
static func pavement_old_city() -> Material:
	return _cached("pavement_old", func():
		var photo := _photo("pavers", 1.6, Color(0.9, 0.74, 0.67))
		if photo:
			return photo
		return color(Color(0.62, 0.42, 0.38), 0.9))


static func sand() -> Material:
	return _cached("sand", func():
		var photo := _photo("sand", 4.0, Color(0.95, 0.86, 0.72))
		if photo:
			# Large patches of darker packed earth and paler drifts, so the lots
			# are not one flat tone (PC tuning).
			var macro := _noise(0.0035, false, 41)
			photo.detail_enabled = true
			photo.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
			photo.uv2_triplanar = true
			photo.uv2_world_triplanar = true
			photo.uv2_scale = Vector3.ONE / 160.0
			photo.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
			photo.detail_albedo = macro
			return photo
		var m := StandardMaterial3D.new()
		# Was (0.86, 0.74, 0.55): read as white glare from street level.
		m.albedo_color = Color(0.74, 0.61, 0.43)
		m.albedo_texture = _noise(0.02, false, 17)
		m.normal_enabled = true
		m.normal_texture = _noise(0.06, true, 19)
		m.uv1_scale = Vector3(400, 400, 1)
		m.roughness = 1.0
		return m)


static func vertex_colored() -> Material:
	return _cached("vc", func():
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		# AREA_COLORS are sRGB values; read as linear they clipped to white.
		m.vertex_color_is_srgb = true
		m.roughness = 0.85
		# Land-use areas were one flat colour each; lay real ground grain
		# (world-space, multiplied) under the area colour.
		var grain := _tex("sand_diff")
		if grain:
			m.detail_enabled = true
			m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
			m.uv2_triplanar = true
			m.uv2_world_triplanar = true
			m.uv2_scale = Vector3.ONE / 4.0
			m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
			m.detail_albedo = grain
			m.detail_normal = _tex("sand_nor")
		return m)


static func color(c: Color, roughness := 0.6, metallic := 0.0) -> StandardMaterial3D:
	var key := "c_%s_%.2f_%.2f" % [c.to_html(), roughness, metallic]
	return _cached(key, func():
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = roughness
		m.metallic = metallic
		return m)


## Car paint: glossy clearcoat over the body colour.
static func paint(c: Color) -> StandardMaterial3D:
	var key := "paint_%s" % c.to_html()
	return _cached(key, func():
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = 0.35
		m.roughness = 0.35
		m.clearcoat_enabled = true
		m.clearcoat = 0.8
		m.clearcoat_roughness = 0.1
		return m)


static func glass() -> StandardMaterial3D:
	return _cached("glass", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.08, 0.1, 0.12, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 0.6
		m.roughness = 0.05
		return m)


static func emissive(c: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "emit_%s_%.1f" % [c.to_html(), energy]
	return _cached(key, func():
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
		return m)
