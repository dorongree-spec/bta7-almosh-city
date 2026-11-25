## The two story missions, run as one small state machine.
##   1. "הבריק לא מחכה": timed delivery in Grandma's Subara with a crispness meter.
##   2. "הסוברה של אבא": find Dad's towed Subara, take it from the municipal
##      lot and get it home with city inspectors on your tail.
## Texts come from data/world.json so the jokes stay out of the code.
class_name Missions
extends Node3D

signal objective_changed(text: String)
signal message(speaker: String, text: String, seconds: float)
signal banner(text: String)
signal reward(amount: int)

enum State { M1_OFFER, M1_GET_CAR, M1_DRIVE, M2_OFFER, M2_SULEIMAN, M2_LOT, M2_TAKE, M2_ESCAPE, DONE }

## Real-world anchors (lat, lon); each one is snapped to the nearest road.
const PLACES := {
	"grandma": Vector2(31.2398, 34.7900),   # Old City
	"emek_sara": Vector2(31.2330, 34.8150),  # industrial zone
	"dad": Vector2(31.2440, 34.7760),        # Shchuna Tet
	"tow_lot": Vector2(31.2360, 34.8030),
}
const REACH := 9.0
const M1_PAY := 400
const M2_PAY := 800
const TICKET := 500

var state := State.M1_OFFER
var _player: Player
var _city: CityBuilder
var _spawn_car: Callable
var _texts := {}
var _marker: Node3D
var _target := Vector3.ZERO
var _car: Car = null
var _chasers: Array[Car] = []
var _time_left := 0.0
var _crisp := 100.0
var _mom_called := false
var _caught_t := 0.0
var _label := ""
var _refresh_t := 0.0


func setup(city: CityBuilder, player: Player, world: Dictionary, car_spawner: Callable) -> void:
	_city = city
	_player = player
	_spawn_car = car_spawner
	for m in world.get("missions", []):
		_texts[String(m.get("id", ""))] = m
	_marker = _build_marker()
	add_child(_marker)
	_enter(State.M1_OFFER)


## Where the player should be heading, for the radar.
func goal() -> Vector3:
	return _target


func has_goal() -> bool:
	return state != State.DONE


# --- helpers ---------------------------------------------------------------------

func _text(mission: String, key: String, fallback: String) -> String:
	var m: Dictionary = _texts.get(mission, {})
	return String(m.get(key, fallback))


## Nearest drivable road point to a place: lane position, pavement and heading.
func _road_spot(place: String) -> Dictionary:
	var ll: Vector2 = PLACES[place]
	var at3 := Gangs.latlon_to_local(ll.x, ll.y)
	var at := Vector2(at3.x, at3.z)
	var best := at
	var dir := Vector2.DOWN
	var best_d := INF
	for path in _city.drive_paths:
		var pts: PackedVector2Array = path
		for i in pts.size() - 1:
			var d := pts[i].distance_to(at)
			if d < best_d:
				best_d = d
				best = pts[i].lerp(pts[i + 1], 0.5)
				dir = (pts[i + 1] - pts[i]).normalized()
	var side := Vector2(-dir.y, dir.x)
	var lane := best + side * 4.2
	var walk := best + side * 6.5
	return {
		"lane": Vector3(lane.x, 0.4, lane.y),
		"walk": Vector3(walk.x, 0, walk.y),
		"yaw": atan2(dir.x, dir.y),
	}


## A tall glowing beam so the goal is visible from a few streets away.
func _build_marker() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.15)
	mat.emission_energy_multiplier = 2.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ring := CylinderMesh.new()
	ring.top_radius = 3.0
	ring.bottom_radius = 3.0
	ring.height = 1.2
	var beam := CylinderMesh.new()
	beam.top_radius = 0.5
	beam.bottom_radius = 0.5
	beam.height = 60.0
	for pair in [[ring, 0.6], [beam, 30.0]]:
		var mi := MeshInstance3D.new()
		mi.mesh = pair[0]
		mi.material_override = mat
		mi.position.y = pair[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


func _aim(at: Vector3, label: String) -> void:
	_target = Vector3(at.x, 0, at.z)
	_marker.position = _target
	_marker.visible = true
	_label = label
	_refresh_t = 0.0


func _focus() -> Vector3:
	return _player.car.global_position if _player.car else _player.global_position


func _reached() -> bool:
	var f := _focus()
	return Vector2(f.x - _target.x, f.z - _target.z).length() < REACH


## True if `car` is the one the current mission is about.
func owns(car: Car) -> bool:
	return _car != null and _car == car


func _in_mission_car() -> bool:
	return _car != null and _player.car == _car


# --- state machine -------------------------------------------------------------------

func _enter(next: State) -> void:
	state = next
	match state:
		State.M1_OFFER:
			_aim(_road_spot("grandma").walk, "לך לסבתא מזל בעיר העתיקה")
		State.M1_GET_CAR:
			var spot := _road_spot("grandma")
			_car = _spawn_car.call("subara89", spot.lane, spot.yaw)
			_aim(spot.lane, "היכנס לסוברה של סבתא (F)")
			banner.emit(_text("m1_brik", "name", "הבריק לא מחכה"))
			message.emit("סבתא מזל", _text("m1_brik", "intro", "200 בריקים, 4 דקות. סע."), 6.0)
		State.M1_DRIVE:
			_time_left = float(_texts.get("m1_brik", {}).get("time_limit_sec", 240))
			_crisp = 100.0
			_mom_called = false
			_car.crashed.connect(_on_brik_crash)
			_aim(_road_spot("emek_sara").lane, "תביא את הבריקים לעמק שרה")
		State.M2_OFFER:
			_car = null
			_aim(_road_spot("dad").walk, "אבא מחכה לך בשכונה ט'")
		State.M2_SULEIMAN:
			banner.emit(_text("m2_subara", "name", "הסוברה של אבא"))
			message.emit("אבא", "הסוברה נעלמה. לך לשייח' סלימאן בעמק שרה, הוא יודע הכל.", 6.0)
			_aim(_road_spot("emek_sara").walk, "סע לשייח' סלימאן בעמק שרה")
		State.M2_LOT:
			message.emit("שייח' סלימאן", _text("m2_subara", "intro", "העירייה לקחה אותה."), 7.0)
			var lot := _road_spot("tow_lot")
			_car = _spawn_car.call("subara89", lot.lane, lot.yaw)
			_aim(lot.lane, "סע למגרש הגרירה העירוני")
		State.M2_TAKE:
			message.emit("שייח' סלימאן", "אני פורץ את השער עם הטנדר. אתה לא ראית כלום. 100 שקל.", 5.0)
			_aim(_car.global_position, "היכנס לסוברה של אבא (F)")
		State.M2_ESCAPE:
			_spawn_chasers()
			_caught_t = 0.0
			message.emit("פקח", "עצור! הרכב הזה מעוקל! יש לך גם דוח על חניה בכיכר!", 5.0)
			_aim(_road_spot("dad").lane, "תחזיר את הסוברה לשכונה ט', בלי שהפקחים יתפסו אותך")
		State.DONE:
			_marker.visible = false
			_label = "סיימת את שתי המשימות. העיר שלך."
			objective_changed.emit(_label)


func _process(delta: float) -> void:
	if _player == null or state == State.DONE:
		return
	match state:
		State.M1_OFFER:
			if _reached():
				_enter(State.M1_GET_CAR)
		State.M1_GET_CAR:
			if _in_mission_car():
				_enter(State.M1_DRIVE)
		State.M1_DRIVE:
			_tick_brik(delta)
		State.M2_OFFER:
			if _reached():
				_enter(State.M2_SULEIMAN)
		State.M2_SULEIMAN:
			if _reached():
				_enter(State.M2_LOT)
		State.M2_LOT:
			if _reached():
				_enter(State.M2_TAKE)
		State.M2_TAKE:
			if _in_mission_car():
				_enter(State.M2_ESCAPE)
		State.M2_ESCAPE:
			_tick_escape(delta)
	_refresh_t -= delta
	if _refresh_t <= 0 and state != State.DONE:
		_refresh_t = 0.25
		objective_changed.emit(_objective_line())


func _objective_line() -> String:
	var f := _focus()
	var dist := roundi(Vector2(f.x - _target.x, f.z - _target.z).length())
	var line := "%s  ·  %d מ'" % [_label, dist]
	if state == State.M1_DRIVE:
		line += "\nזמן: %d:%02d   פריכות: %d%%" % [int(_time_left) / 60, int(_time_left) % 60, roundi(_crisp)]
	return line


# --- mission 1: the brik ---------------------------------------------------------------

func _on_brik_crash(_c: Car, impact: float) -> void:
	_crisp -= impact * 1.5


func _tick_brik(delta: float) -> void:
	_time_left -= delta
	_crisp -= delta * 0.3
	var limit := float(_texts.get("m1_brik", {}).get("time_limit_sec", 240))
	if not _mom_called and _time_left < limit * 0.5:
		_mom_called = true
		message.emit("אמא", "אתה נוהג? אל תענה לי כשאתה נוהג! למה אתה לא עונה?", 5.0)
	if _car.wrecked or _time_left <= 0 or _crisp <= 0:
		_finish_brik(false)
	elif _reached() and _in_mission_car():
		_finish_brik(true)


func _finish_brik(won: bool) -> void:
	if _car.crashed.is_connected(_on_brik_crash):
		_car.crashed.disconnect(_on_brik_crash)
	if won:
		banner.emit("המשימה הושלמה  +₪%d" % M1_PAY)
		message.emit("סבתא מזל", _text("m1_brik", "success", "כפרה עליך."), 6.0)
		reward.emit(M1_PAY)
		_enter(State.M2_OFFER)
	else:
		banner.emit("המשימה נכשלה")
		message.emit("סבתא מזל", _text("m1_brik", "fail", "בושה למשפחה."), 6.0)
		_enter(State.M1_OFFER)


# --- mission 2: inspectors -----------------------------------------------------------------

func _spawn_chasers() -> void:
	var back := -_car.global_transform.basis.z
	for i in 2:
		var pos := _car.global_position + back * (18.0 + i * 9.0) + Vector3(0, 0.4, 0)
		var chaser: Car = _spawn_car.call("inspector", pos, _car.global_rotation.y)
		chaser.driver = Car.Driver.POLICE
		chaser.siren_on = true
		_chasers.append(chaser)


func _tick_escape(delta: float) -> void:
	var prey := _focus()
	var cornered := false
	for chaser in _chasers:
		if chaser.wrecked:
			continue
		var to := prey - chaser.global_position
		to.y = 0
		var dist := to.length()
		var fwd := chaser.global_transform.basis.z
		var dir := to.normalized()
		var ang := atan2(fwd.cross(dir).y, fwd.dot(dir))
		chaser.steer_input = clampf(-ang * 2.0, -1.0, 1.0)
		chaser.throttle = 0.0 if dist < 7.0 else (1.0 if absf(ang) < 1.2 else 0.4)
		chaser.handbrake = dist < 5.0
		if dist < 8.0:
			cornered = true
	var slow := _player.car == null or _player.car.speed_kmh() < 8.0
	_caught_t = _caught_t + delta if (cornered and slow) else 0.0
	if _caught_t > 3.0 or _car.wrecked:
		_finish_escape(false)
	elif _reached() and _in_mission_car():
		_finish_escape(true)


func _finish_escape(won: bool) -> void:
	for chaser in _chasers:
		chaser.siren_on = false
		chaser.driver = Car.Driver.NONE
		chaser.throttle = 0.0
		chaser.handbrake = true
	_chasers.clear()
	if won:
		banner.emit("המשימה הושלמה  +₪%d" % M2_PAY)
		message.emit("אבא", _text("m2_subara", "success", "מילאת דלק?"), 6.0)
		reward.emit(M2_PAY)
		_enter(State.DONE)
	else:
		banner.emit("קיבלת דוח  -₪%d" % TICKET)
		message.emit("פקח", _text("m2_subara", "fail", "הדוח גדל ב-500 שקל."), 6.0)
		reward.emit(-TICKET)
		# Dad's car is still out there unless it was wrecked in the chase.
		_enter(State.M2_LOT if _car.wrecked else State.M2_TAKE)
