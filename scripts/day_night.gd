## Time of day. Moves the sun across the sky, recolours sky, fog and ambient
## light, and at dusk switches the city on: street-lamp heads glow, a small
## pool of real lights follows the player from lamp to lamp, and cars turn
## their headlights on. A full day takes DAY_MINUTES of real time.
class_name DayNight
extends Node3D

signal night_changed(is_night: bool)

const DAY_MINUTES := 18.0
const START_HOUR := 15.5
const LAMP_LIGHTS := 16  # PC tuning: 10 left most of the street black at night
const LAMP_REACH := 90.0

const SKY_TOP_DAY := Color(0.2, 0.42, 0.8)  # deeper desert blue (PC tuning; was 0.36, 0.55, 0.82)
const SKY_TOP_NIGHT := Color(0.02, 0.035, 0.09)  # a little blue in the zenith (PC tuning)
const HORIZON_DAY := Color(0.9, 0.84, 0.72)
const HORIZON_DUSK := Color(1.0, 0.47, 0.22)  # a richer desert sunset (PC tuning)
const HORIZON_NIGHT := Color(0.17, 0.11, 0.08)  # the city's sodium glow on the horizon
const FOG_DAY := Color(0.86, 0.78, 0.64)
const FOG_NIGHT := Color(0.05, 0.055, 0.09)
const HAZE_TINT := Color(0.85, 0.6, 0.36)

var hour := START_HOUR
var is_night := false
## 0 in full daylight, 1 in the middle of the night, sliding through twilight.
var darkness := 0.0
## Set by main once the weather exists; dust haze dims and tints the light.
var weather: Weather

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _furniture: StreetFurniture
var _focus: Callable
var _lamp_lights: Array[OmniLight3D] = []
var _lamp_t := 0.0


func setup(sun: DirectionalLight3D, env: Environment, sky: ProceduralSkyMaterial, furniture: StreetFurniture, focus: Callable) -> void:
	_sun = sun
	_env = env
	_sky = sky
	_furniture = furniture
	_focus = focus
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color(0.55, 0.65, 1.0)
	_moon.rotation_degrees = Vector3(-60, 140, 0)
	_moon.shadow_enabled = false
	add_child(_moon)
	for i in LAMP_LIGHTS:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.82, 0.55)
		lamp.light_energy = 6.0
		lamp.omni_range = 22.0
		lamp.omni_attenuation = 1.0
		lamp.shadow_enabled = false
		lamp.light_volumetric_fog_energy = 2.0  # a soft halo round each lamp
		lamp.visible = false
		add_child(lamp)
		_lamp_lights.append(lamp)
	_apply()


func clock_text() -> String:
	return "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60.0)]


func _process(delta: float) -> void:
	hour = fmod(hour + delta * 24.0 / (DAY_MINUTES * 60.0), 24.0)
	_apply()
	_lamp_t -= delta
	if _lamp_t <= 0.0:
		_lamp_t = 0.5
		_place_lamp_lights()


func _apply() -> void:
	# Sunrise at 06:00 in the east (+X), sunset at 18:00 in the west.
	var angle := (hour - 6.0) / 12.0 * PI
	var to_sun := Vector3(cos(angle), sin(angle), 0.35).normalized()
	var height := to_sun.y
	# 0 at night, 1 in full daylight, with a short twilight in between.
	var day := clampf(height * 4.0 + 0.2, 0.0, 1.0)
	var low_sun := clampf(1.0 - absf(height) * 4.0, 0.0, 1.0)

	if height > -0.1:
		_sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	_sun.visible = day > 0.01
	var haze := weather.haze if weather != null else 0.0
	_sun.light_energy = 1.7 * day * (1.0 - 0.55 * haze)
	_sun.light_color = Color(1.0, 0.95, 0.86).lerp(Color(1.0, 0.56, 0.3), maxf(low_sun, haze * 0.7))
	_moon.light_energy = 0.18 * (1.0 - day)

	_sky.sky_top_color = SKY_TOP_NIGHT.lerp(SKY_TOP_DAY, day)
	var horizon := HORIZON_NIGHT.lerp(HORIZON_DAY, day).lerp(HORIZON_DUSK, low_sun * day)
	_sky.sky_horizon_color = horizon
	_sky.ground_horizon_color = horizon.darkened(0.08)
	_sky.ground_bottom_color = Color(0.55, 0.47, 0.36).darkened(0.85 * (1.0 - day))
	# Clouds catch the sunset and fade to almost nothing at night.
	var cloud := Color(1, 1, 1).lerp(HORIZON_DUSK.lightened(0.3), low_sun)
	# Fuller clouds by day (PC tuning: they were faint wisps).
	_sky.sky_cover_modulate = Color(cloud.r, cloud.g, cloud.b, 1.0) * lerpf(0.04, 0.85, day)
	var fog := FOG_NIGHT.lerp(FOG_DAY, day).lerp(HORIZON_DUSK, low_sun * day * 0.5)
	_env.fog_light_color = fog.lerp(HAZE_TINT * maxf(day, 0.15), haze)
	_env.volumetric_fog_albedo = _env.fog_light_color
	# Golden hour: the low sun lights up the dust in long shafts between the
	# blocks (PC tuning, after the god rays of modern open-world sunsets).
	var golden := low_sun * day
	_sun.light_volumetric_fog_energy = lerpf(1.0, 5.0, golden)
	_env.volumetric_fog_anisotropy = lerpf(0.6, 0.82, golden)
	# The night sky is nearly black, so lift ambient light to keep streets readable.
	_env.ambient_light_energy = lerpf(4.0, 0.9, day)
	# By day shade gets a warm sand bounce (see main._build_environment); at night
	# that fixed colour times the 4x lift lit the open sand bright orange, so the
	# ambient goes back to the (dark) sky alone.
	_env.ambient_light_sky_contribution = lerpf(1.0, 0.3, day)

	var dark := 1.0 - day
	darkness = dark
	if _furniture != null and _furniture.lamp_material != null:
		_furniture.lamp_material.emission_energy_multiplier = lerpf(0.4, 9.0, dark)
	Facades.set_window_glow(dark)
	StreetFurniture.set_sign_glow(dark)
	CityMaterials.set_road_sheen(dark)

	var night_now := day < 0.35
	if night_now != is_night:
		is_night = night_now
		night_changed.emit(is_night)
		get_tree().call_group("cars", "set_headlights", is_night)


## Real light sources are expensive, so only the lamps nearest the player get one.
func _place_lamp_lights() -> void:
	if not is_night or _furniture == null:
		for lamp in _lamp_lights:
			lamp.visible = false
		return
	var centre: Vector3 = _focus.call()
	var nearest := _furniture.lamps_near(centre, LAMP_REACH, LAMP_LIGHTS)
	for i in _lamp_lights.size():
		var lamp := _lamp_lights[i]
		lamp.visible = i < nearest.size()
		if lamp.visible:
			lamp.global_position = nearest[i] + Vector3(0, -0.6, 0)
