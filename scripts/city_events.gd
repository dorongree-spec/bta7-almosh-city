## Things that happen to the whole street at once, every two minutes or so,
## so that the town is never just traffic and inspectors:
##
##   rockets    the "צבע אדום" siren, everybody runs, interceptors climb and
##              burst over the roofs, one or two fall in an empty lot far off
##   camels     a herder walks his camels down the middle of a nearby road
##   beggar     a man who has seen the player coming and has a story
##   sandstorm  a full sandstorm, much thicker than the ordinary haze
##
## Nobody is hurt by any of it; it is weather, in the Negev sense.
##
##   events.setup(city, player, pedestrians, weather, _nearest_pavement, _focus_position)
##   events.enabled = true   # once the opening shot is over
class_name CityEvents
extends Node3D

signal said(speaker: String, text: String, seconds: float)
## Something went off at `at`; `impact` is loudness on the crash scale (0..30).
signal boom(impact: float, at: Vector3)
## The beggar got some (shekels).
signal took_money(amount: int)

const FIRST_AFTER := 60.0               # seconds into the game
const GAP := Vector2(70.0, 150.0)       # seconds between one event ending and the next
const WEIGHTS := {"rockets": 2.0, "camels": 3.0, "beggar": 3.0, "sandstorm": 1.5}
const SOUND_SPEED := 340.0              # m/s, so far booms come late

# Rockets
const SALVO := Vector2i(3, 5)
const ROCKET_FLIGHT := 9.0              # seconds from the edge of sight to the ground
const INTERCEPT_FLIGHT := 3.0
const INTERCEPTED := 0.75               # share of rockets that are stopped
const FROM_DIRECTION := Vector3(-0.7, 0.0, -0.7)   # they come from the north-west
const LAUNCHER_OFFSET := Vector3(650.0, 0.0, 250.0)
const TRAIL_EVERY := 0.12
const TRAIL_LIFE := 3.5
const ALL_CLEAR_AFTER := 32.0

# Camels
const HERD := Vector2i(3, 5)
const CAMEL_SPACING := 3.6
const CAMEL_SPEED := 1.1
const CAMEL_COLOUR := Color(0.74, 0.58, 0.38)

# Beggar
const BEGGAR_SPEED := 1.6
const BEG_EVERY := 5.0
const BEG_AMOUNT := 5
const BEG_TIMES := 3

const LINES := {
	"siren": ["צבע אדום. צבע אדום.", "צבע אדום. כולם למרחב המוגן, גם מי שעוד לא סיים את הקפה."],
	"neighbour": ["עוד פעם? רק תליתי כביסה.", "יאללה, לממ\"ד. מי הביא את הגרעינים?", "אני לא יורדת. הברכיים שלי לא יורדות."],
	"all_clear": ["אפשר לצאת מהמרחב המוגן.", "אפשר לצאת מהמרחב המוגן. מי שלא נכנס, יכול להמשיך."],
	"camels": ["גמלים על הכביש. תעקוף בעדינות, הם היו פה לפני העירייה.", "פקק גמלים בשכונה. תגיד תודה שזה לא בשעת עומס."],
	"herder": ["הם לא חוסמים את הכביש, הכביש חוסם אותם.", "אל תצפצף, יא זלמה. הם לא מבינים צפצוף.", "רוצה לקנות אחד? מחיר חבר, ויש לו טסט."],
	"beggar_hail": ["אחי! אחי! רגע, רק שנייה!", "סליחה, אתה מפה? ראיתי שאתה מפה."],
	"beggar": ["שקל לאוטובוס? אני חוזר לאופקים מאז 2009.", "אתה נראה לי בן אדם טוב. אני טועה הרבה, אבל לא הפעם.", "אין לך סיגריה? אז תן שקל לסיגריה.", "אני לא קבצן. אני יזם בתחילת הדרך."],
	"beggar_took": ["תודה אחי. אלוהים רואה, וגם אני.", "ברכה והצלחה, מהבריאות ועד הפיס.", "עוד חמישה ואני פותח עסק."],
	"beggar_car": ["(דופק על החלון) אחי, רק שקל, אני רואה שיש לך מזגן."],
	"beggar_hit": ["על קבצן? איפה הרחמים? איפה האמא שלך?"],
	"beggar_done": ["יאללה, תודה. מחר באותה שעה, באותו מקום."],
	"sandstorm": ["סופת חול רצינית מהנגב. סגרו חלונות, הכביסה כבר אבודה.", "סופת חול. לא רואים את הקניון, אז לפחות לא רואים את הפקקים.", "סופת חול. מי שיש לו מגבים, שידליק. מי שאין לו, שיתפלל."],
}

var enabled := false

var _city: CityBuilder
var _player: Player
var _pedestrians: Pedestrians
var _weather: Weather
var _pavement: Callable
var _focus: Callable
var _rng := RandomNumberGenerator.new()
var _next_in := FIRST_AFTER
var _last := ""
var _running := ""       # the event under way, "" when the town is quiet

var _clock := 0.0        # seconds since the event started
var _jobs: Array = []    # [at, Callable] still to run, for the scripted parts
var _shots: Array[Dictionary] = []   # rockets and interceptors in the air
var _siren: AudioStreamPlayer
var _glow_rocket: StandardMaterial3D
var _glow_interceptor: StandardMaterial3D
var _smoke: StandardMaterial3D
var _puff_mesh: SphereMesh

var _herd: Array[Dictionary] = []    # {node, legs, phase}
var _herd_path: PackedVector2Array
var _herd_along := 0.0
var _herder: Humanoid
var _herder_spoke := false

var _beggar: Humanoid
var _begged := 0
var _beg_cd := 0.0
var _beggar_leaving := false
var _beggar_down := false


func setup(city: CityBuilder, player: Player, pedestrians: Pedestrians, weather: Weather, pavement: Callable, focus: Callable) -> void:
	_city = city
	_player = player
	_pedestrians = pedestrians
	_weather = weather
	_pavement = pavement
	_focus = focus
	_rng.randomize()
	_glow_rocket = _glow(Color(1.0, 0.55, 0.15), 6.0)
	_glow_interceptor = _glow(Color(1.0, 0.95, 0.8), 8.0)
	_smoke = StandardMaterial3D.new()
	_smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke.albedo_color = Color(0.9, 0.9, 0.88)
	_puff_mesh = SphereMesh.new()
	# Seen from 500 m away: the trail must be big (PC: at 1.4 m they were specks).
	_puff_mesh.radius = 3.5
	_puff_mesh.height = 7.0
	_puff_mesh.radial_segments = 8
	_puff_mesh.rings = 4
	_siren = AudioStreamPlayer.new()
	_siren.stream = _siren_wail()
	_siren.volume_db = -9.0
	add_child(_siren)


## Starts an event now, whatever the schedule says (testing; F9 in a debug run).
func trigger(kind: String) -> void:
	if not _running.is_empty():
		_finish()
	_running = kind
	_last = kind
	_clock = 0.0
	_jobs.clear()
	match kind:
		"rockets":
			_start_rockets()
		"camels":
			if not _start_camels():
				_finish()
		"beggar":
			if not _start_beggar():
				_finish()
		"sandstorm":
			_weather.storm(_rng.randf_range(60.0, 90.0))
			_say("חזאי", "sandstorm", 6.0)
			_finish()   # the weather takes it from here


## A blow at `point` (the player's fist or chair). Returns true if it hit the beggar.
func hit_at(point: Vector3) -> bool:
	if _beggar == null or _beggar_down or _beggar.global_position.distance_to(point) > 1.5:
		return false
	_beggar_down = true
	_beggar.set_knockdown(1.0)
	_say("קבצן", "beggar_hit", 4.0)
	_jobs.append([_clock + 4.0, _finish])
	return true


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		var kinds := WEIGHTS.keys()
		trigger(kinds[(kinds.find(_last) + 1) % kinds.size()])


func _process(delta: float) -> void:
	if _player == null:
		return
	if _running.is_empty():
		if enabled:
			_next_in -= delta
			if _next_in <= 0.0:
				trigger(_pick())
		return
	_clock += delta
	for job: Array in _jobs.duplicate():
		# A job may have finished the event and cleared the rest.
		if _clock >= float(job[0]) and _jobs.has(job):
			_jobs.erase(job)
			(job[1] as Callable).call()
	match _running:
		"rockets":
			_fly_shots(delta)
		"camels":
			_walk_herd(delta)
		"beggar":
			_beg(delta)


func _pick() -> String:
	var total := 0.0
	for kind: String in WEIGHTS:
		if kind != _last and not (kind == "sandstorm" and _weather.is_hazy()):
			total += float(WEIGHTS[kind])
	var roll := _rng.randf() * total
	for kind: String in WEIGHTS:
		if kind == _last or (kind == "sandstorm" and _weather.is_hazy()):
			continue
		roll -= float(WEIGHTS[kind])
		if roll <= 0.0:
			return kind
	return "beggar"


## The event is over: clear up after it and set the next one going.
func _finish() -> void:
	_jobs.clear()
	for shot in _shots:
		(shot.node as Node3D).queue_free()
	_shots.clear()
	_siren.stop()
	for camel in _herd:
		(camel.node as Node3D).queue_free()
	_herd.clear()
	if _herder:
		_herder.queue_free()
		_herder = null
	if _beggar:
		_beggar.queue_free()
		_beggar = null
	_running = ""
	_next_in = _rng.randf_range(GAP.x, GAP.y)


func _say(speaker: String, kind: String, seconds: float) -> void:
	var lines: Array = LINES[kind]
	said.emit(speaker, String(lines[_rng.randi() % lines.size()]), seconds)


# --- rockets ---------------------------------------------------------------------------

func _start_rockets() -> void:
	var centre: Vector3 = _focus.call()
	_siren.play()
	_say("התרעה", "siren", 4.0)
	_pedestrians.panic_all(centre, 150.0, 18.0)
	_jobs.append([3.0, func(): _say("השכנה", "neighbour", 4.0)])
	_jobs.append([12.0, _siren.stop])
	var count := _rng.randi_range(SALVO.x, SALVO.y)
	for i in count:
		_jobs.append([4.0 + i * _rng.randf_range(0.5, 1.2), func(): _launch_rocket(centre)])
	_jobs.append([ALL_CLEAR_AFTER, func(): _say("התרעה", "all_clear", 5.0)])
	_jobs.append([ALL_CLEAR_AFTER + 1.0, _finish])


## One rocket over the edge of sight, falling on an empty patch 200-600 m
## from the player; most get an interceptor sent to meet them.
func _launch_rocket(centre: Vector3) -> void:
	var from := centre + FROM_DIRECTION.normalized() * 900.0 + Vector3(_rng.randf_range(-200, 200), 120.0, _rng.randf_range(-200, 200))
	var land_angle := _rng.randf() * TAU
	var to := centre + Vector3(cos(land_angle), 0.0, sin(land_angle)) * _rng.randf_range(200.0, 600.0)
	var rocket := _shot(from, to, ROCKET_FLIGHT, 260.0, _glow_rocket, 3.0, false)
	if _rng.randf() < INTERCEPTED:
		var meet_t := _rng.randf_range(0.55, 0.75)
		var meet := _arc(from, to, 260.0, meet_t)
		var launcher := centre + LAUNCHER_OFFSET
		var wait := ROCKET_FLIGHT * meet_t - INTERCEPT_FLIGHT
		_jobs.append([_clock + wait, _send_interceptor.bind(rocket, launcher, meet)])


func _send_interceptor(rocket: Dictionary, launcher: Vector3, meet: Vector3) -> void:
	if _shots.has(rocket):
		var interceptor := _shot(launcher, meet, INTERCEPT_FLIGHT, 60.0, _glow_interceptor, 1.6, true)
		interceptor["target"] = rocket


func _shot(from: Vector3, to: Vector3, flight: float, apex: float, glow: Material, size: float, trail: bool) -> Dictionary:
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	ball.mesh = mesh
	ball.material_override = glow
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ball)
	ball.global_position = from
	var shot := {"node": ball, "from": from, "to": to, "flight": flight, "apex": apex, "t": 0.0, "trail": trail, "puff_in": 0.0}
	_shots.append(shot)
	return shot


## A point on a lobbed path: a straight line from `from` to `to` lifted by a parabola.
func _arc(from: Vector3, to: Vector3, apex: float, t: float) -> Vector3:
	return from.lerp(to, t) + Vector3.UP * apex * 4.0 * t * (1.0 - t)


func _fly_shots(delta: float) -> void:
	for shot: Dictionary in _shots.duplicate():
		var ball: MeshInstance3D = shot.node
		shot.t = float(shot.t) + delta / float(shot.flight)
		var t: float = minf(1.0, shot.t)
		ball.global_position = _arc(shot.from, shot.to, shot.apex, t)
		if shot.trail:
			shot.puff_in = float(shot.puff_in) - delta
			if shot.puff_in <= 0.0:
				shot.puff_in = TRAIL_EVERY
				_puff(ball.global_position)
		if t < 1.0:
			continue
		_shots.erase(shot)
		ball.queue_free()
		if shot.has("target"):
			var rocket: Dictionary = shot.target
			if _shots.has(rocket):
				_shots.erase(rocket)
				(rocket.node as Node3D).queue_free()
			_burst(ball.global_position, 14.0, 12.0)
		else:
			_burst(ball.global_position, 6.0, 22.0)
			var dust := Puffs.make(Color(0.5, 0.45, 0.4, 0.6), 40, 5.0, Vector3(4, 1, 4), 2.0, 9.0)
			add_child(dust)
			dust.global_position = ball.global_position
			dust.one_shot = true
			dust.emitting = true
			get_tree().create_timer(7.0).timeout.connect(dust.queue_free)


## A bright flash and, a moment later (sound is slow), the bang.
func _burst(at: Vector3, size: float, loudness: float) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	flash.mesh = mesh
	flash.material_override = _glow_interceptor
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 6.0
	light.omni_range = 260.0
	flash.add_child(light)
	add_child(flash)
	flash.global_position = at
	var fade := flash.create_tween()
	fade.tween_property(flash, "scale", Vector3.ONE * 1.4, 0.35).from(Vector3.ONE * 0.4)
	fade.tween_property(flash, "scale", Vector3.ONE * 0.05, 0.6)
	fade.parallel().tween_property(light, "light_energy", 0.0, 0.9)
	fade.tween_callback(flash.queue_free)
	var gap := at.distance_to(_focus.call())
	var heard := clampf(loudness - gap / 60.0, 3.0, 30.0)
	get_tree().create_timer(gap / SOUND_SPEED).timeout.connect(func(): boom.emit(heard, at))


func _puff(at: Vector3) -> void:
	var puff := MeshInstance3D.new()
	puff.mesh = _puff_mesh
	puff.material_override = _smoke
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puff)
	puff.global_position = at
	var fade := puff.create_tween()
	# Smoke spreads, then thins away.
	fade.tween_property(puff, "scale", Vector3.ONE * 1.6, TRAIL_LIFE * 0.7).from(Vector3.ONE * 0.5)
	fade.tween_property(puff, "scale", Vector3.ONE * 0.05, TRAIL_LIFE * 0.3)
	fade.tween_callback(puff.queue_free)


func _glow(colour: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	return m


## Four seconds of a rising and falling wail, looped while the alert lasts.
func _siren_wail() -> AudioStreamWAV:
	const RATE := 22050
	var seconds := 4.0
	var bytes := PackedByteArray()
	bytes.resize(int(RATE * seconds) * 2)
	var phase := 0.0
	for i in int(RATE * seconds):
		var t := float(i) / RATE
		var pitch := 800.0 - 320.0 * cos(TAU * t / seconds)
		phase += TAU * pitch / RATE
		var v := 0.6 * sin(phase) + 0.2 * sin(phase * 2.0)
		bytes.encode_s16(i * 2, int(v * 26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = int(RATE * seconds)
	return wav


# --- camels ----------------------------------------------------------------------------

## Finds a road 30-80 m away and starts the herd down the middle of it.
func _start_camels() -> bool:
	var centre: Vector3 = _focus.call()
	var c2 := Vector2(centre.x, centre.z)
	# Every road, in random order (40 random picks out of thousands almost never
	# landed within 80 m of the player, PC test).
	var order := range(_city.drive_paths.size())
	order.shuffle()
	for index in order:
		var pts: PackedVector2Array = _city.drive_paths[index]
		if pts.size() < 2 or _length(pts) < 80.0:
			continue
		var d := pts[0].distance_to(c2)
		var nearest := 0.0
		var walked := 0.0
		for i in pts.size() - 1:
			var gap := pts[i].distance_to(c2)
			if gap < d:
				d = gap
				nearest = walked
			walked += pts[i].distance_to(pts[i + 1])
		if d < 30.0 or d > 80.0:
			continue
		_herd_path = pts
		_herd_along = maxf(nearest - 40.0, HERD.y * CAMEL_SPACING)
		for n in _rng.randi_range(HERD.x, HERD.y):
			var camel := _camel()
			add_child(camel.node)
			_herd.append(camel)
		var look := Humanoid.random_look(_rng)
		look["prop"] = "keffiyeh"
		look["shirt"] = Color(0.92, 0.9, 0.84)
		look["pants"] = Color(0.92, 0.9, 0.84)
		_herder = Humanoid.create(look)
		add_child(_herder)
		_herder_spoke = false
		_say("", "camels", 5.0)
		_jobs.append([150.0, _finish])
		return true
	return false


func _walk_herd(delta: float) -> void:
	_herd_along += CAMEL_SPEED * delta
	var centre: Vector3 = _focus.call()
	if _herd_along >= _length(_herd_path) - 1.0:
		_finish()
		return
	for n in _herd.size():
		var camel: Dictionary = _herd[n]
		var place := _point_at(_herd_path, _herd_along - n * CAMEL_SPACING)
		var node: Node3D = camel.node
		node.global_position = Vector3(place[0].x, 0.0, place[0].y)
		node.rotation.y = atan2(place[1].x, place[1].y)
		camel.phase = float(camel.phase) + delta * CAMEL_SPEED * 3.2
		var legs: Array = camel.legs
		for k in legs.size():
			(legs[k] as Node3D).rotation.x = sin(float(camel.phase) + (PI if k % 3 == 0 else 0.0)) * 0.35
	var lead := _point_at(_herd_path, _herd_along + 1.5)
	var side := Vector2(-lead[1].y, lead[1].x) * 1.6
	_herder.global_position = Vector3(lead[0].x + side.x, 0.0, lead[0].y + side.y)
	_herder.rotation.y = atan2(lead[1].x, lead[1].y)
	_herder.animate(delta, CAMEL_SPEED)
	var gap := _herder.global_position.distance_to(centre)
	if not _herder_spoke and gap < 14.0:
		_herder_spoke = true
		_say("רועה", "herder", 5.0)
	if gap > 140.0:
		_finish()


## A camel: a body, a hump, a long neck and four legs that swing, with a
## solid box round it so that cars stop at it rather than drive through.
func _camel() -> Dictionary:
	var root := AnimatableBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 2.2, 2.4)
	shape.shape = box
	shape.position = Vector3(0, 1.1, 0.2)
	root.add_child(shape)
	var hide := StandardMaterial3D.new()
	hide.albedo_color = CAMEL_COLOUR.darkened(_rng.randf_range(0.0, 0.25))
	hide.roughness = 0.95
	var body := CapsuleMesh.new()
	body.radius = 0.45
	body.height = 2.0
	_part(root, body, hide, Vector3(0, 1.7, 0), Vector3(PI / 2.0, 0, 0))
	var hump := SphereMesh.new()
	hump.radius = 0.42
	hump.height = 0.6
	_part(root, hump, hide, Vector3(0, 2.15, -0.1), Vector3.ZERO)
	var neck := BoxMesh.new()
	neck.size = Vector3(0.24, 1.1, 0.3)
	_part(root, neck, hide, Vector3(0, 2.15, 1.05), Vector3(0.6, 0, 0))
	var head := BoxMesh.new()
	head.size = Vector3(0.26, 0.28, 0.62)
	_part(root, head, hide, Vector3(0, 2.62, 1.45), Vector3.ZERO)
	var legs: Array[Node3D] = []
	for corner in [Vector3(-0.22, 1.4, 0.7), Vector3(0.22, 1.4, 0.7), Vector3(-0.22, 1.4, -0.7), Vector3(0.22, 1.4, -0.7)]:
		var hip := Node3D.new()
		hip.position = corner
		root.add_child(hip)
		var leg := CylinderMesh.new()
		leg.top_radius = 0.08
		leg.bottom_radius = 0.06
		leg.height = 1.4
		_part(hip, leg, hide, Vector3(0, -0.7, 0), Vector3.ZERO)
		legs.append(hip)
	return {"node": root, "legs": legs, "phase": _rng.randf() * TAU}


func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, turn: Vector3) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation = turn
	parent.add_child(part)


func _length(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	return total


## [position, direction] `along` metres down a polyline (clamped to its ends).
func _point_at(pts: PackedVector2Array, along: float) -> Array:
	var left := maxf(0.0, along)
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if left <= seg or i == pts.size() - 2:
			var dir := (pts[i + 1] - pts[i]).normalized()
			return [pts[i] + dir * minf(left, seg), dir]
		left -= seg
	return [pts[0], Vector2.UP]


# --- the beggar ------------------------------------------------------------------------

func _start_beggar() -> bool:
	var centre: Vector3 = _focus.call()
	var angle := _rng.randf() * TAU
	var spot: Vector3 = _pavement.call(centre + Vector3(cos(angle), 0.0, sin(angle)) * 20.0)
	if spot.distance_to(centre) > 45.0:
		return false
	var look := Humanoid.random_look(_rng)
	look["shirt"] = Color(0.45, 0.4, 0.33)
	look["pants"] = Color(0.25, 0.23, 0.2)
	look["prop"] = "kitbag"
	look["long_hair"] = false
	_beggar = Humanoid.create(look)
	add_child(_beggar)
	_beggar.global_position = spot
	_begged = 0
	_beg_cd = 1.5
	_beggar_leaving = false
	_beggar_down = false
	_say("קבצן", "beggar_hail", 3.5)
	_jobs.append([60.0, _leave])
	return true


func _beg(delta: float) -> void:
	if _beggar_down:
		return
	var aim: Vector3 = _player.car.global_position if _player.car else _player.global_position
	var to := aim - _beggar.global_position
	to.y = 0.0
	var gap := to.length()
	if _beggar_leaving:
		_beggar.global_position -= to.normalized() * BEGGAR_SPEED * delta
		_beggar.rotation.y = atan2(-to.x, -to.z)
		_beggar.animate(delta, BEGGAR_SPEED)
		if gap > 40.0:
			_finish()
		return
	if gap > 60.0:
		_finish()   # he lost you; there is always tomorrow
		return
	_beggar.rotation.y = atan2(to.x, to.z)
	var stop_at := 3.0 if _player.car else 1.5
	if gap > stop_at:
		_beggar.global_position += to.normalized() * minf(BEGGAR_SPEED * delta, gap - stop_at)
		_beggar.animate(delta, BEGGAR_SPEED)
		return
	_beggar.animate(delta, 0.0)
	_beg_cd -= delta
	if _beg_cd > 0.0:
		return
	_beg_cd = BEG_EVERY
	if _player.car:
		_say("קבצן", "beggar_car", 4.0)
	elif _begged < BEG_TIMES:
		_begged += 1
		took_money.emit(BEG_AMOUNT)
		_say("קבצן", "beggar_took" if _begged > 1 else "beggar", 4.0)
	else:
		_leave()


func _leave() -> void:
	if _beggar == null or _beggar_down:
		return
	_beggar_leaving = true
	_say("קבצן", "beggar_done", 4.0)
