## BTA 7 Almosh City entry point. Builds the world (sky, sun, city from real OSM
## data), spawns the player at Ha-Pina Ha-Hama on KKL street, and runs the
## on-foot / in-car loop, the chase camera and the HUD wiring.
extends Node3D

const CITY_DATA := "res://data/city.json"
const WORLD_DATA := "res://data/world.json"
## Soroka is where you wake up after passing out from the heat.
const HOSPITAL_LATLON := Vector2(31.2582, 34.8005)
const ENTER_REACH := 3.6
const HEAT_ON_FOOT := 0.35  # per second, it is Beer Sheva
const HEAT_IN_CAR := -1.5   # the AC works. Mostly.
const PARKED_KINDS := ["subara_dl", "subara_dl_wagon", "subara_dl_pickup", "maza323", "maza323_hatch", "maza3", "maza3", "maza6", "hilo", "hondo_civic", "kia_picanta", "sedan", "subara89"]
const STREET_CELL := 40.0
const RECKLESS_IMPACT := 9.0  # m/s lost in a crash before the inspectors care
const BLAST_RADIUS := 7.0     # metres within which an exploding car hurts
const ROUTE_EVERY := 1.5      # seconds between sat-nav recalculations
const RUN_OVER_SPEED := 3.5    # m/s at which a car floors a pedestrian
const BUMP_IMPACT := 4.0       # m/s lost in a crash before the other driver gets out
const PARK_ANSWER_CHANCE := 0.45  # how often leaving a car draws somebody over
const INTRO_TIME := 9.0         # seconds of the opening shot
const INTRO_HEIGHT := 420.0    # metres from the player at which the opening shot begins
const INTRO_PITCH := -0.62     # how steeply it looks down from up there (radians)
const INTRO_TURN := 2.2        # radians the camera swings round on its way down
const AREA_EVERY := 1.0        # seconds between checks of which part of town this is
const TALK_CAM_AFTER := 0.6    # seconds without mouse movement before the camera frames a talk
const TALK_CAM_ANGLE := 0.55   # radians off the line between the player and the speaker
const WEEKDAYS := ["ראשון", "שני", "שלישי", "רביעי", "חמישי", "שישי", "שבת"]
const START := Vector3(520.0, 0.0, -2505.0)   # where the game opens: Avraham Avinu 15, Shchuna Dalet
const START_WEEKDAY := 3       # the game opens on a Wednesday afternoon
const THURSDAY := 4            # the day the students go home
const RUN_OVER_LINES := ["אתה עיוור?! זה מעבר חצייה! בערך!", "אח שלי, הכיכר לא שלך.", "ביטוח חובה יש לך לפחות?"]

var city: CityBuilder
var player: Player
var traffic: Traffic
var chairs: Chairs
var gangs: Gangs
var missions: Missions
var pedestrians: Pedestrians
var encounters: Encounters
var law: Law
var props: StreetProps
var weather: Weather
var events: CityEvents
var skids: SkidMarks
var furniture: StreetFurniture
var dressing: CityDressing
var day_night: DayNight
var audio: GameAudio

var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var hud: Hud
var front: FrontEnd
var camera: Camera3D
var world_data: Dictionary = {}

var _cam_yaw := 0.0
var _cam_pitch := -0.25
var _cam_idle := 0.0
var _street_index := {}
var _street_t := 0.0
var _playing := false
var _passed_out := 0.0
var _shake := 0.0
var _title_orbit := 0.0
var _gps := Gps.new()
var _route_t := 0.0
var _weekday := START_WEEKDAY
var _last_hour := 0.0
var _last_car: Car = null          # the car the player drove most recently
var _intro_t := 0.0                # seconds of the opening shot still to run
var _area := ""                    # the part of town last announced
var _area_t := 0.0
var _tour := false                 # started with --tour: no menus, no opening shot


func _ready() -> void:
	_build_environment()
	_tour = OS.get_cmdline_user_args().has("--tour")
	hud = Hud.new()
	add_child(hud)
	hud.visible = false  # nothing of the game shows until the opening shot is over
	front = FrontEnd.new()
	add_child(front)
	front.start_pressed.connect(_start)
	front.pause_info = _pause_summary
	audio = GameAudio.new()
	add_child(audio)
	camera = Camera3D.new()
	camera.fov = 70
	camera.far = 1500
	# A touch of distance blur takes the hard edge off the far city.
	var lens := CameraAttributesPractical.new()
	lens.dof_blur_far_enabled = true
	lens.dof_blur_far_distance = 260.0
	lens.dof_blur_far_transition = 240.0
	lens.dof_blur_amount = 0.05
	# Eye adaptation like GTA V's: average scene luminance drives the exposure,
	# gradually, within limits so night stays night and noon stays bright.
	lens.auto_exposure_enabled = true
	lens.auto_exposure_scale = 0.4
	lens.auto_exposure_speed = 1.2
	lens.auto_exposure_min_sensitivity = 80.0
	lens.auto_exposure_max_sensitivity = 1200.0
	camera.attributes = lens
	add_child(camera)
	add_to_group("blast_listeners")
	camera.position = START + Vector3(0, 60, 60)
	camera.look_at(START)
	await _build_world()
	# `godot --path . -- --tour` photographs the build and quits (see photo_tour.gd).
	if _tour:
		var tour := PhotoTour.new()
		add_child(tour)
		tour.run(self)
	else:
		front.loading_done()


# --- world -------------------------------------------------------------------

## Thin high cloud for the sky dome: mostly clear, it is the Negev after all.
func _cloud_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.006
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.55
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.52)
	ramp.set_color(0, Color(0, 0, 0))
	ramp.set_offset(1, 0.85)
	ramp.set_color(1, Color(1, 1, 1))
	var clouds := NoiseTexture2D.new()
	clouds.width = 1024
	clouds.height = 512
	clouds.seamless = true
	clouds.noise = noise
	clouds.color_ramp = ramp
	return clouds


func _build_environment() -> void:
	# Low Negev hills on the horizon, travelling with the camera (PC).
	add_child(Horizon.new())
	var sky_mat := ProceduralSkyMaterial.new()
	_sky_mat = sky_mat
	sky_mat.sky_top_color = Color(0.42, 0.6, 0.82)
	sky_mat.sky_horizon_color = Color(0.9, 0.84, 0.72)
	sky_mat.ground_horizon_color = Color(0.86, 0.78, 0.62)
	sky_mat.ground_bottom_color = Color(0.55, 0.47, 0.36)
	sky_mat.sun_angle_max = 20
	sky_mat.sky_cover = _cloud_texture()
	sky_mat.sky_cover_modulate = Color(1, 1, 1, 0.55)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	# Shade in a desert city is lit by sun bouncing off sand and plaster, not
	# only by blue sky. Pure sky ambient turned every shadow saturated blue
	# (tuned by eye on the PC).
	env.ambient_light_color = Color(0.78, 0.68, 0.55)
	env.ambient_light_sky_contribution = 0.3
	# Hable / Uncharted-2 filmic, the operator GTA V uses (Courrèges' frame study);
	# A/B'd on the PC against ACES: deeper sky, more natural shade.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# A high white point lets bright walls and sky roll off softly instead of
	# clipping to pure white; the exposure is raised to keep the mid-tones.
	env.tonemap_white = 6.0
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.08
	# Desert haze: distant blocks fade into dusty beige.
	env.fog_enabled = true
	env.fog_light_color = Color(0.86, 0.78, 0.64)
	env.fog_density = Weather.CLEAR_FOG
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.1
	# Modern lighting: real-time global illumination (bounced sunlight off
	# sand and walls), indirect shadowing, reflections and light shafts.
	# SDFGI off (PC tuning): in Godot 4.3 it lights open shade straight from the
	# blue sky and ignores the ambient colour, so every shadow on the asphalt came
	# out navy (measured RGB 13/31/60 vs 68/64/63 without it). Warm ambient +
	# SSIL give a natural, GTA-like shade and free up GPU time.
	env.sdfgi_enabled = false
	env.sdfgi_cascades = 6
	env.sdfgi_min_cell_size = 0.4
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 1.3  # more bounce light into shade (PC tuning; was 1.0)
	env.ssil_enabled = true
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = Weather.CLEAR_VOLUME
	env.volumetric_fog_albedo = Color(0.9, 0.82, 0.68)
	env.volumetric_fog_length = 180.0
	env.volumetric_fog_anisotropy = 0.6
	env.adjustment_enabled = true
	# GTA-style grade (PC tuning): a gentle S-curve per channel with slightly
	# cool shadows and warm highlights, a little more contrast and colour.
	env.adjustment_saturation = 1.14
	env.adjustment_contrast = 1.08
	var grade := Gradient.new()
	grade.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	grade.colors = PackedColorArray([Color(0.0, 0.0, 0.0), Color(0.21, 0.225, 0.245),
		Color(0.515, 0.5, 0.475), Color(0.79, 0.765, 0.71), Color(1.0, 0.98, 0.93)])
	var lut := GradientTexture1D.new()
	lut.gradient = grade
	lut.width = 256
	env.adjustment_color_correction = lut
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	# Street-level cascades (PC tuning): sharp shadows near the player,
	# blended into the far ones instead of popping at the seams.
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 260
	_add_vignette()
	var lens := Lens.new()
	lens.sun = sun
	add_child(lens)
	add_child(sun)


## Tells the loading screen how far along we are, then lets it draw before
## the next (slow, blocking) piece of the city is built.
func _loading_step(done: float, what: String) -> void:
	front.set_progress(done, what)
	await get_tree().process_frame
	await get_tree().process_frame


## A soft darkening towards the corners, under the HUD: the lens look of
## modern open-world games, kept subtle (PC tuning).
func _add_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.05), Color(0, 0, 0, 0.42)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.08, 1.08)
	tex.width = 256
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	add_child(layer)


func _build_world() -> void:
	await _loading_step(0.05, "פותח את המפה")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(WORLD_DATA))
	world_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	audio.setup(world_data)

	await _loading_step(0.12, "סולל כבישים ומוסיף כיכרות")
	city = CityBuilder.new()
	add_child(city)
	city.build(CITY_DATA)
	var landmarks := Landmarks.new()
	add_child(landmarks)
	landmarks.build(city)
	_add_roundabout_sculptures()
	await _loading_step(0.5, "שותל דקלים ומדליק פנסי רחוב")
	furniture = StreetFurniture.new()
	add_child(furniture)
	furniture.build(city)
	var billboards := Billboards.new()
	add_child(billboards)
	billboards.build(city, world_data)
	hud.minimap.setup(city)
	hud.city_map.setup(city)
	_gps.build(city)
	_index_streets()

	await _loading_step(0.57, "בונה גדרות ומעלה דודי שמש לגג")
	dressing = CityDressing.new()
	add_child(dressing)
	dressing.build()
	# Rows of white and silver cars on the car parks between the blocks (PC).
	var parked_rows := ParkedRows.new()
	add_child(parked_rows)
	parked_rows.build()
	parked_rows.build_kerbs(city.data.get("roads", []))

	await _loading_step(0.65, "מחנה מכוניות על המדרכה")
	player = Player.new()
	add_child(player)
	player.global_position = _nearest_pavement(START) + Vector3(0, 0.2, 0)
	_spawn_parked_cars()

	traffic = Traffic.new()
	add_child(traffic)
	traffic.setup(city, _focus_position)

	await _loading_step(0.78, "מושיב את החבר'ה על כסאות כתר פלסטיק")
	gangs = Gangs.new()
	add_child(gangs)
	gangs.setup(city, player, world_data, _spawn_car)
	gangs.said.connect(func(who: String, text: String): hud.say(who, text))
	gangs.hurt_player.connect(func(amount: float): player.health -= amount)
	gangs.charged.connect(func(amount: int, who: String, line: String):
		player.money = maxi(0, player.money - amount)
		hud.say(who, "%s  (-₪%d)" % [line, amount], 5.0))

	chairs = Chairs.new()
	add_child(chairs)
	chairs.setup(player, _nearest_pavement, func(at: Vector3) -> bool: return _land_blow(at, true))

	missions = Missions.new()
	add_child(missions)
	missions.objective_changed.connect(func(text: String): hud.set_objective(text))
	missions.message.connect(func(who: String, text: String, seconds: float): hud.say(who, text, seconds))
	missions.banner.connect(_on_mission_banner)
	missions.reward.connect(func(amount: int): player.money = maxi(0, player.money + amount))
	missions.setup(city, player, world_data, _spawn_car)

	pedestrians = Pedestrians.new()
	add_child(pedestrians)
	pedestrians.setup(city, player, world_data, _focus_position)
	pedestrians.said.connect(func(who: String, text: String): hud.say(who, text, 3.0))
	pedestrians.hurt_player.connect(func(amount: float): player.health -= amount)
	pedestrians.arm(chairs)

	await _loading_step(0.9, "מעיר את הפקחים")
	skids = SkidMarks.new()
	add_child(skids)

	props = StreetProps.new()
	add_child(props)
	props.setup(city, _focus_position)

	var kiosks := Kiosks.new()
	add_child(kiosks)
	kiosks.setup(city, player)
	kiosks.said.connect(func(who: String, text: String): hud.say(who, text, 4.0))
	kiosks.served.connect(func(place: String, line: String, price: int, cooling: float):
		player.money -= price
		player.heat = maxf(0.0, player.heat - cooling)
		hud.say(place, "%s  (-₪%d)" % [line, price], 4.5))

	law = Law.new()
	add_child(law)
	law.setup(city, player, _spawn_car, _focus_position)
	law.level_changed.connect(func(level: int): hud.set_reports(level))
	law.said.connect(func(who: String, text: String): hud.say(who, text, 4.0))
	law.fined.connect(func(amount: int): player.money = maxi(0, player.money - amount))
	# Running someone over is a bigger deal than a slap.
	pedestrians.knocked.connect(func(by_car: bool): law.offence(2.0 if by_car else 1.0))

	encounters = Encounters.new()
	add_child(encounters)
	encounters.setup(player, Callable(pedestrians, "nearest"), _encounter_conditions, Callable(pedestrians, "send_away"))
	encounters.said.connect(func(who: String, text: String, seconds: float): hud.say(who, text, seconds))
	encounters.asked.connect(func(who: String, text: String): hud.ask(who, text))
	encounters.ask_closed.connect(func(): hud.end_ask())
	encounters.hurt_player.connect(func(amount: float): player.health -= amount)
	encounters.outcome.connect(_apply_encounter)

	day_night = DayNight.new()
	add_child(day_night)
	day_night.setup(_sun, _env, _sky_mat, furniture, _focus_position)
	# The far town at night: lamps and windows as points of light.
	var far_lights := FarLights.new()
	add_child(far_lights)
	far_lights.setup(city, furniture, day_night)

	weather = Weather.new()
	add_child(weather)
	weather.setup(_env, _focus_position)
	weather.said.connect(func(who: String, text: String): hud.say(who, text, 5.0))
	day_night.weather = weather

	events = CityEvents.new()
	add_child(events)
	events.setup(city, player, pedestrians, weather, _nearest_pavement, _focus_position)
	events.said.connect(func(who: String, text: String, seconds: float): hud.say(who, text, seconds))
	events.boom.connect(_on_far_boom)
	events.took_money.connect(func(amount: int):
		player.money = maxi(0, player.money - amount)
		hud.flash_money(-amount))
	await _loading_step(1.0, "מוכן. יותר מדי מוכן.")


## Closed roundabout rings get a municipal sculpture in the middle.
func _add_roundabout_sculptures() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 323
	for r in city.data.get("roads", []):
		if not r.get("roundabout", false):
			continue
		var pts: Array = r.pts
		if pts.size() < 4 or Vector2(pts[0][0], pts[0][1]).distance_to(Vector2(pts[-1][0], pts[-1][1])) > 1.0:
			continue
		var c := Vector2.ZERO
		for p in pts:
			c += Vector2(p[0], p[1])
		c /= pts.size()
		Props.sculpture(city, Vector3(c.x, 0, c.y), rng)


## Coarse grid cell -> street name, for the HUD location line.
func _index_streets() -> void:
	for i in city.drive_paths.size():
		var name := city.drive_names[i] if i < city.drive_names.size() else ""
		if name == "":
			continue
		for p in city.drive_paths[i]:
			var k := Vector2i(floori(p.x / STREET_CELL), floori(p.y / STREET_CELL))
			if not _street_index.has(k):
				_street_index[k] = name


func _street_at(pos: Vector3) -> String:
	var c := Vector2i(floori(pos.x / STREET_CELL), floori(pos.z / STREET_CELL))
	for r in 2:
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var k := c + Vector2i(dx, dz)
				if _street_index.has(k):
					return _street_index[k]
	return "באר שבע"


## The closest road point to `to`, pushed onto the pavement on the right.
func _nearest_pavement(to: Vector3) -> Vector3:
	var best := Vector2(to.x, to.z)
	var best_d := INF
	var side := Vector2.ZERO
	for pts in city.drive_paths:
		for i in pts.size() - 1:
			var p: Vector2 = pts[i]
			var d := p.distance_to(Vector2(to.x, to.z))
			if d < best_d:
				best_d = d
				best = p
				var dir: Vector2 = (pts[i + 1] - p).normalized()
				side = Vector2(-dir.y, dir.x)
	var spot := best + side * 6.5
	return Vector3(spot.x, 0, spot.y)


func _spawn_parked_cars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var origin := player.global_position
	var placed := 0
	var taken: Array[Vector2] = []
	for pts in city.drive_paths:
		if placed >= 14:
			break
		for i in range(0, pts.size() - 1, 3):
			var p: Vector2 = pts[i]
			if p.distance_to(Vector2(origin.x, origin.z)) > 160 or rng.randf() > 0.25:
				continue
			var dir: Vector2 = (pts[i + 1] - p).normalized()
			var spot := p + Vector2(-dir.y, dir.x) * 4.2
			# Many streets start at the same junction; without this every
			# parked car landed on the same spot and they piled up.
			if taken.any(func(t: Vector2) -> bool: return t.distance_to(spot) < 8.0):
				continue
			taken.append(spot)
			# The first one is always Dad's old Subaru, right by the start.
			var kind: String = "subara_dl" if placed == 0 else PARKED_KINDS[rng.randi() % PARKED_KINDS.size()]
			_spawn_car(kind, Vector3(spot.x, 0.4, spot.y), atan2(dir.x, dir.y))
			placed += 1
			break


func _spawn_car(kind: String, pos: Vector3, yaw: float) -> Car:
	var car := Car.create(kind)
	add_child(car)
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	if day_night != null and day_night.is_night:
		car.set_headlights(true)
	return car


func _focus_position() -> Vector3:
	if player == null:
		return START
	return player.car.global_position if player.car else player.global_position


# --- game loop -----------------------------------------------------------------

func _start() -> void:
	# Enter or the start button while the city is still being built used to
	# start the game with no player yet (null errors every frame).
	if player == null or encounters == null or _playing:
		return
	_playing = true
	hud.minimap.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _tour:
		front.enter_game()
		_end_intro()
		return
	# The opening shot: down from high over the city to the hero's shoulder.
	_intro_t = INTRO_TIME
	front.begin_intro(["באר שבע", "יום %s  ·  %s  ·  34 מעלות בצל, ואין צל" % [WEEKDAYS[_weekday], day_night.clock_text()]])


## The opening shot is over (or was skipped): the game proper begins.
func _end_intro() -> void:
	_intro_t = 0.0
	hud.visible = true
	encounters.enabled = true
	events.enabled = true
	front.end_intro()
	front.area("אברהם אבינו 15")
	hud.say("אמא", "קמת סוף סוף? באים אורחים. תביא סמבוסק מהפינה החמה, שיגיע חם, ואל תחנה איפה שחנית בפעם הקודמת.", 6.0)


## Moves the camera along the opening shot; `delta` is the frame time.
func _run_intro(delta: float) -> void:
	_intro_t -= delta
	if _intro_t <= 0.0:
		_end_intro()
		return
	var along := 1.0 - _intro_t / INTRO_TIME               # 0 at the start, 1 at the end
	var eased := 1.0 - pow(1.0 - along, 3.0)                # fast at first, settling at the end
	var dist := lerpf(INTRO_HEIGHT, 6.0, eased)
	var pitch := lerpf(INTRO_PITCH, _cam_pitch, smoothstep(0.35, 1.0, along))
	var yaw := _cam_yaw + INTRO_TURN * (1.0 - eased)
	var target := _focus_position() + Vector3(0, 1.6, 0)
	camera.global_position = target + Vector3(0, 0, -dist).rotated(Vector3.RIGHT, -pitch).rotated(Vector3.UP, yaw)
	camera.look_at(target)


## What the pause menu says about how things stand.
func _pause_summary() -> String:
	var lines: Array[String] = [
		"יום %s, %s" % [WEEKDAYS[_weekday], day_night.clock_text()],
		"בכיס: ₪%d" % player.money,
		"דוחות פתוחים: %d" % law.level,
		"",
		"איך מסתכלים עליך:",
	]
	var names := {"tenderim": "הטנדרים", "meshuparot": "המשופרות", "ktarim": "הכתרים", "student": "הסטודנטים",
			"babushka": "הסבתות", "soldier": "החיילים", "landlord": "בעלי הבתים", "inspector": "הפקחים", "local": "השכונה"}
	var standings := encounters.standings()
	if standings.is_empty():
		lines.append("עוד לא מכירים אותך. זה ישתנה.")
	for who: String in standings:
		var score := int(standings[who])
		var mood := "חבר" if score >= 2 else ("רשום אצלם" if score <= -3 else ("מכירים" if score >= 0 else "לא אוהבים"))
		lines.append("%s: %s (%+d)" % [names.get(who, who), mood, score])
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if _intro_t > 0.0:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("action"):
			_end_intro()  # seen it already
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_cam_yaw -= event.relative.x * 0.004
		_cam_pitch = clampf(_cam_pitch - event.relative.y * 0.003, -1.1, 0.25)
		_cam_idle = 0.0
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("map"):
		hud.city_map.toggle()
	elif event.is_action_pressed("enter_exit"):
		_toggle_car()


func _physics_process(delta: float) -> void:
	if not _playing or _intro_t > 0.0:
		return
	if _passed_out > 0:
		_passed_out -= delta
		if _passed_out <= 0:
			_wake_in_hospital()
		return
	if player.car:
		_drive(delta)
	else:
		audio.engine(false, 0.0, 0.0)
		_walk(delta)
	_update_heat(delta)
	if player.global_position.y < -30:
		player.global_position = _nearest_pavement(player.global_position) + Vector3(0, 1, 0)
		player.velocity = Vector3.ZERO


## A moving car that reaches the player on foot knocks him over.
func _check_run_over() -> void:
	if player.is_down():
		return
	for node in get_tree().get_nodes_in_group("cars"):
		var car := node as Car
		if car == null:
			continue
		var speed := car.linear_velocity.length()
		if speed < RUN_OVER_SPEED:
			continue
		# Where the player is in the car's own frame: x across, z along.
		var local := car.to_local(player.global_position + Vector3(0, 0.5, 0))
		if absf(local.x) > float(car.spec.wid) * 0.5 + 0.45 or absf(local.z) > float(car.spec.len) * 0.5 + 0.9:
			continue
		var away := player.global_position - car.global_position
		if car.linear_velocity.dot(away) <= 0.0:
			continue  # the car is leaving, not arriving
		player.knock_down(car.linear_velocity * 0.7 + Vector3(0, 4, 0), speed * 2.5)
		_shake = maxf(_shake, 0.5)
		audio.punch(true)
		hud.say("", String(RUN_OVER_LINES.pick_random()), 3.0)
		return


func _walk(delta: float) -> void:
	player.camera_yaw = _cam_yaw
	_cam_idle += delta
	_check_run_over()
	skids.track(null)
	if player.step_on_foot(delta):
		var hit := _land_punch(player.swing_point())
		audio.punch(hit)
		if hit and player.has_chair:
			var before := player.chairs
			player.use_chair_hit()
			if player.chairs < before:
				hud.say("", "כיסא הכתר הפלסטיק נשבר. כמו שהבטיחו." if player.chairs == 0 else "כיסא הכתר הפלסטיק נשבר. נשארו עוד %d." % player.chairs, 3.0)
	if Input.is_action_just_pressed(Chairs.THROW_ACTION) and player.has_chair and not player.is_down():
		# Throw where the camera looks, not wherever he last walked (PC).
		player.rotation.y = _cam_yaw
		chairs.throw(player.global_position, player.rotation.y)
		player.lose_chair()
		audio.punch(false)
	var near := _nearest_car(player.global_position)
	var on_foot := "רווח - מכה   ·   F - להרים כיסא כתר פלסטיק"
	if player.has_chair:
		on_foot = "כסאות כתר פלסטיק %d/%d   ·   G - לזרוק   ·   %s" % [player.chairs, Player.MAX_CHAIRS, on_foot]
	hud.set_hint(("F - להיכנס לרכב" if near else on_foot) + "   ·   E - לדבר   ·   M - מפה")


## One swing of the fist (or the chair) at `point`. Whoever is there takes
## it, and the street has opinions. Returns true if it connected.
func _land_punch(point: Vector3) -> bool:
	return _land_blow(point, player.has_chair)


## A blow at `point`, with a fist or with a chair (swung or thrown).
func _land_blow(point: Vector3, with_chair: bool) -> bool:
	var hit := gangs.hit_at(point, with_chair) or encounters.hit_at(point, with_chair) or events.hit_at(point)
	if not hit and pedestrians.hit_at(point, with_chair):
		hit = true
		encounters.avenge(point)
	if hit and not encounters.notify("in_fight"):
		encounters.react("punch")
	return hit


func _drive(delta: float) -> void:
	var car := player.car
	if car.wrecked:
		hud.say("", "האוטו גמור. גם ככה לא היה טסט.", 3.0)
		_exit_car()
		return
	car.throttle = Input.get_axis("move_back", "move_forward")
	car.steer_input = Input.get_axis("move_left", "move_right")
	car.handbrake = Input.is_action_pressed("action")
	skids.track(car)
	audio.engine(true, absf(car.forward_speed()) / float(car.spec.top), car.throttle)
	if Input.is_action_just_pressed("horn"):
		audio.horn()
		if not encounters.notify("honks"):
			encounters.react("horn")
	if Input.is_action_just_pressed("radio"):
		_tune_radio()
	player.global_position = car.global_position
	_cam_idle += delta
	hud.set_hint("F - לצאת   ·   רווח - בלם יד   ·   R - רדיו   ·   H - צופר   ·   M - מפה")


func _update_heat(delta: float) -> void:
	var warming := HEAT_IN_CAR if player.car else HEAT_ON_FOOT * weather.heat_factor()
	player.heat = clampf(player.heat + warming * delta, 0, 100)
	if player.heat >= 100:
		player.health -= 4.0 * delta
	if player.health <= 0:
		_pass_out()


func _pass_out() -> void:
	if player.car:
		_exit_car()
	_passed_out = 3.0
	front.card("התייבשת", "שתית מים היום? לא. ברור שלא.")


func _wake_in_hospital() -> void:
	var spot := _nearest_pavement(Gangs.latlon_to_local(HOSPITAL_LATLON.x, HOSPITAL_LATLON.y))
	player.global_position = spot + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	law.clear()
	player.health = 100
	player.heat = 0
	player.money = maxi(0, player.money - 150)
	hud.say("סורוקה", "חיכית בחדר מיון 6 שעות. ₪150 השתתפות עצמית.", 5.0)


# --- people who walk up to you -----------------------------------------------------

## Thursday to Saturday the students are at their parents'. Sunday they are back.
func _on_new_day() -> void:
	var away := _weekday >= THURSDAY
	if away and not gangs.students_away:
		hud.say("", "יום חמישי. הסטודנטים נסעו הביתה עם הכביסה. העיר שוב של המקומיים.", 5.0)
	elif not away and gangs.students_away:
		hud.say("", "יום ראשון. הסטודנטים חזרו, עם קופסאות אוכל מאמא.", 5.0)
	gangs.students_away = away


## Shows the name of a part of town when the player crosses into it.
func _announce_area(delta: float) -> void:
	_area_t -= delta
	if _area_t > 0.0:
		return
	_area_t = AREA_EVERY
	var here := encounters.area_name_at(_focus_position())
	if here != _area:
		_area = here
		if here != "":
			front.area(here)


## While somebody is talking to the player and the mouse is left alone, the
## camera drifts round to look past the player's shoulder at that person,
## so the two of them are side by side on screen instead of one hiding the other.
func _frame_conversation(delta: float) -> void:
	var speaker := encounters.speaker_position()
	if speaker == Vector3.INF:
		return
	var to := speaker - player.global_position
	if Vector2(to.x, to.z).length() < 0.3:
		return
	var facing := atan2(to.x, to.z)
	# Whichever shoulder is nearer to where the camera already is.
	var side := TALK_CAM_ANGLE if angle_difference(facing, _cam_yaw) >= 0.0 else -TALK_CAM_ANGLE
	_cam_yaw = lerp_angle(_cam_yaw, facing + side, minf(1.0, delta * 2.0))
	_cam_pitch = lerpf(_cam_pitch, -0.12, minf(1.0, delta * 2.0))


## What is true right now, for encounters that depend on it.
func _encounter_conditions() -> Dictionary:
	return {
		"night": day_night.is_night,
		"dust_storm": weather.haze > 0.5,
		"fleeing": law.level > 0,
		"thursday": _weekday == THURSDAY,
		"students_away": gangs.students_away,
	}


## Applies what an encounter did to the player (the keys are listed in EncounterBank).
func _apply_encounter(change: Dictionary) -> void:
	# The car in question: the one being driven, or else the one just left.
	var car: Car = player.car
	if car == null and is_instance_valid(_last_car):
		car = _last_car
	if car != null and (car.wrecked or not car.visible):
		car = null
	if bool(change.get("take_car", false)):
		if car == null:
			hud.say("", "אין רכב, אין עסקה.", 3.0)
			return
		if missions.owns(car):
			hud.say("", "את הסוברה של אבא לא מוכרים. אמא תהרוג אותך.", 3.5)
			return
		_take_car_away(car)
		car = null
	var before := player.money
	player.money = maxi(0, player.money + int(change.get("money", 0)))
	hud.flash_money(player.money - before)
	player.heat = clampf(player.heat + float(change.get("heat", 0.0)), 0.0, 100.0)
	player.health = minf(100.0, player.health + float(change.get("health", 0.0)))
	var reports := float(change.get("reports", 0.0))
	if reports > 0.0:
		law.offence(reports)
	elif reports < 0.0:
		law.clear()
	if change.has("chair"):
		if bool(change.get("chair")):
			player.give_chair()
		else:
			player.drop_chair()
	if change.has("hold") and player.car == null:
		player.hold(float(change.get("hold")))
	if car != null:
		if bool(change.get("repair", false)):
			car.repair()
		if change.has("car_damage"):
			car.damage(float(change.get("car_damage")))


## Somebody bought (or simply kept) the car. It leaves the street; Traffic
## recycles its own cars later, which is why it is hidden and not freed.
func _take_car_away(car: Car) -> void:
	if player.car == car:
		_exit_car()
	if _last_car == car:
		_last_car = null
	car.driver = Car.Driver.NONE
	car.visible = false
	car.process_mode = Node.PROCESS_MODE_DISABLED


## Which crowd a car belongs to, going by its make ("" = nobody in particular).
func _crowd_of(car: Car) -> String:
	for id: String in Gangs.DEFS:
		if (Gangs.DEFS[id].cars as Array).has(car.kind):
			return id
	return ""


## The nearest other car within `reach` metres of `mine`, or null.
func _car_beside(mine: Car, reach: float) -> Car:
	var best: Car = null
	var best_d := reach
	for node in get_tree().get_nodes_in_group("cars"):
		var other := node as Car
		if other == null or other == mine or not other.visible:
			continue
		var d := other.global_position.distance_to(mine.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best


# --- cars ----------------------------------------------------------------------

func _nearest_car(at: Vector3) -> Car:
	var best: Car = null
	var best_d := ENTER_REACH
	for node in get_tree().get_nodes_in_group("cars"):
		var c := node as Car
		if c == null or c.wrecked or not c.visible:
			continue
		var d := c.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = c
	return best


func _toggle_car() -> void:
	if player.car:
		_exit_car()
		# Leaving a car anywhere in this city is an invitation.
		if randf() < PARK_ANSWER_CHANCE and not encounters.notify("parks"):
			encounters.react("park")
		return
	if player.chairs < Player.MAX_CHAIRS and (gangs.take_chair(player.global_position) or chairs.take(player.global_position)):
		player.give_chair()
		hud.say("", "כיסא כתר פלסטיק. הנשק של העם." if player.chairs == 1 else "כיסא כתר פלסטיק מספר %d." % player.chairs, 2.5)
		encounters.react("chair")
		return
	var car := _nearest_car(player.global_position)
	if car == null:
		return
	if car.driver == Car.Driver.AI:
		traffic.release(car)
		hud.say("נהג", "יא חיה! זה האוטו של אח שלי!", 3.0)
		law.offence(2.0)
		# The owner (or his whole crew) may want a word about that.
		encounters.notify("touches_vehicle", _crowd_of(car), car.global_position - car.global_transform.basis.x * 2.5)
	car.driver = Car.Driver.PLAYER
	car.crashed.connect(_on_player_crash)
	player.car = car
	_last_car = car
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.collision_layer = 0
	_cam_yaw = car.global_rotation.y


func _exit_car() -> void:
	var car := player.car
	player.car = null
	car.driver = Car.Driver.NONE
	if car.crashed.is_connected(_on_player_crash):
		car.crashed.disconnect(_on_player_crash)
	audio.radio_off()
	car.throttle = 0
	car.steer_input = 0
	car.handbrake = true
	# Step out on the driver's side (left in a right-hand-traffic car).
	var left := car.global_transform.basis.x
	player.global_position = car.global_position + left * 1.8 + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.collision_layer = 1


## Pulls the camera in front of anything solid between it and the player,
## so walls never hide the action.
func _clear_of_walls(from: Vector3, to: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var skip: Array[RID] = [player.get_rid()]
	if player.car:
		skip.append(player.car.get_rid())
	query.exclude = skip
	query.collision_mask = StreetProps.WORLD_LAYER  # loose props never block the view
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	var hit_at: Vector3 = hit.position
	return hit_at + (from - to).normalized() * 0.35


func _on_player_crash(_car: Car, impact: float) -> void:
	audio.crash(impact)
	_shake = maxf(_shake, clampf(impact / 30.0, 0.0, 0.6))
	if impact > RECKLESS_IMPACT:
		law.offence(1.0)
	if impact > BUMP_IMPACT and player.car != null:
		var other := _car_beside(player.car, 7.0)
		if other != null:
			encounters.notify("hits_vehicle", _crowd_of(other), other.global_position + other.global_transform.basis.x * 2.0)


## A rocket or an interceptor going off somewhere over town.
func _on_far_boom(impact: float, at: Vector3) -> void:
	audio.crash(impact)
	_shake = maxf(_shake, clampf(1.0 - at.distance_to(_focus_position()) / 500.0, 0.0, 0.35))


## Called on the "blast_listeners" group by a car that has just blown up.
func on_car_exploded(car: Car) -> void:
	var gap := car.global_position.distance_to(_focus_position())
	if gap > 120.0:
		return
	audio.crash(30.0 - gap * 0.2)
	_shake = maxf(_shake, clampf(1.0 - gap / 40.0, 0.0, 1.0))
	if gap < BLAST_RADIUS and player.car != car:
		player.health -= 45.0 * (1.0 - gap / BLAST_RADIUS)
	if gap < 60.0:
		encounters.react("wreck")


func _tune_radio() -> void:
	var station := audio.next_station()
	if station.is_empty():
		hud.say("רדיו", "כבוי. סוף סוף שקט.", 2.5)
	else:
		hud.say(String(station.get("name", "רדיו")), "%s: %s" % [station.get("host", ""), station.get("bit", "")], 6.0)


# --- camera & HUD ----------------------------------------------------------------

func _process(delta: float) -> void:
	if not _playing:
		# Behind the title card the camera circles slowly over the start of town.
		_title_orbit += delta * 0.06
		camera.global_position = Vector3(sin(_title_orbit), 0.0, cos(_title_orbit)) * 150.0 + Vector3(0, 70, 0)
		camera.look_at(Vector3(0, 5, 0))
		return
	if _intro_t > 0.0:
		_run_intro(delta)
		return
	_announce_area(delta)
	var target := _focus_position() + Vector3(0, 1.6, 0)
	var dist := 6.0
	if player.car:
		# Closer than before: at 135 km/h the car was a speck 16 m ahead (PC tuning).
		dist = 7.0 + clampf(player.car.speed_kmh() / 45.0, 0, 3)
		# Swing back behind the car when the mouse is left alone.
		if _cam_idle > 1.2:
			_cam_yaw = lerp_angle(_cam_yaw, player.car.global_rotation.y, minf(1.0, delta * 2.5))
			_cam_pitch = lerpf(_cam_pitch, -0.22, minf(1.0, delta * 2.0))
	elif _cam_idle > TALK_CAM_AFTER:
		_frame_conversation(delta)
	# A negative pitch looks down at the player, so the camera has to go up:
	# turning (0, 0, -dist) about +X by a positive angle lifts it.
	var offset := Vector3(0, 0, -dist).rotated(Vector3.RIGHT, -_cam_pitch).rotated(Vector3.UP, _cam_yaw)
	var want := target + offset
	want.y = maxf(want.y, 0.8)
	want = _clear_of_walls(target, want)
	camera.global_position = camera.global_position.lerp(want, minf(1.0, delta * (16.0 if player.car else 10.0)))
	camera.look_at(target)
	if _shake > 0.01:
		# Crashes and blasts rattle the camera for a moment.
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.35
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.35
		_shake = move_toward(_shake, 0.0, delta * 1.8)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	# The view widens with speed, which sells acceleration better than any number.
	var rush := clampf(player.car.speed_kmh() / 140.0, 0.0, 1.0) if player.car else 0.0
	camera.fov = lerpf(camera.fov, 70.0 + rush * 16.0, minf(1.0, delta * 3.0))

	hud.set_stats(player.money, player.health, player.heat)
	if day_night.hour < _last_hour:
		_weekday = (_weekday + 1) % WEEKDAYS.size()  # the clock went past midnight
		_on_new_day()
	_last_hour = day_night.hour
	hud.set_clock("יום %s  %s" % [WEEKDAYS[_weekday], day_night.clock_text()])
	hud.minimap.track(_focus_position(), _cam_yaw)
	hud.minimap.set_goal(missions.goal(), missions.has_goal())
	hud.city_map.track(_focus_position(), _cam_yaw, missions.goal(), missions.has_goal(), delta)
	_route_t -= delta
	if _route_t <= 0.0:
		_route_t = ROUTE_EVERY
		var way := _gps.route(_focus_position(), missions.goal()) if missions.has_goal() else PackedVector2Array()
		hud.minimap.set_route(way)
		hud.city_map.set_route(way)
	hud.set_speed(player.car.speed_kmh() if player.car else 0.0, player.car != null)
	_street_t -= delta
	if _street_t <= 0:
		_street_t = 0.5
		hud.set_street(_street_at(_focus_position()))


## Mission news. Passing or failing a mission gets the big card across the
## screen; everything else (mission names, small fines) stays a HUD banner.
func _on_mission_banner(text: String) -> void:
	const PASSED := "המשימה הושלמה"
	const FAILED := "המשימה נכשלה"
	if text.begins_with(PASSED):
		front.card(PASSED, text.trim_prefix(PASSED).strip_edges(), UiStyle.GOLD, 3.5)
	elif text.begins_with(FAILED):
		front.card(FAILED, text.trim_prefix(FAILED).strip_edges(), UiStyle.WASTED, 3.5)
	else:
		hud.banner(text)
