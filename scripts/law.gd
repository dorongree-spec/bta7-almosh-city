## Municipal law and order. Beer Sheva does not send the police after you;
## it sends parking inspectors. Offences (running people over, stealing a
## car, smashing into traffic) raise the "reports" level from 0 to 3, each
## level puts another inspection car on your tail, and being boxed in at a
## standstill gets you a fine. Stay out of their sight and the level drops.
## They are a nuisance, not the main event (Doron): offences weigh half,
## no more than two cars ever come, and they lose interest quickly.
class_name Law
extends Node3D

signal level_changed(level: int)
signal fined(amount: int)
signal said(speaker: String, text: String)

const MAX_LEVEL := 3
const MAX_CARS := 2         # inspection cars on the road at once, whatever the level
const OFFENCE_WEIGHT := 0.5 # an offence counts for half of what the caller says
const FINE_PER_LEVEL := 200
const SPAWN_NEAR := 70.0
const SPAWN_FAR := 130.0
const LOSE_SIGHT := 70.0
const COOL_DOWN := 10.0
const CATCH_RANGE := 8.0
const CATCH_TIME := 2.5
const TOW_AWAY := 160.0   # abandoned inspection cars vanish once this far away
const LINES := ["עצרת. זה דוח.", "נסעת. גם זה דוח.", "אני רק עושה את העבודה שלי. ואני נהנה ממנה.", "תעודת זהות ורישיונות, ועוד דוח על הדרך."]

var level := 0

var _city: CityBuilder
var _player: Player
var _spawn_car: Callable
var _focus: Callable
var _cars: Array[Car] = []
var _points := 0.0
var _unseen_t := 0.0
var _caught_t := 0.0
var _stuck := {}  # Car -> seconds without moving
var _retired: Array[Car] = []
var _sweep_t := 0.0


func setup(city: CityBuilder, player: Player, car_spawner: Callable, focus: Callable) -> void:
	_city = city
	_player = player
	_spawn_car = car_spawner
	_focus = focus


## Records an offence. Two points make one report level.
func offence(points: float) -> void:
	_points = minf(_points + points * OFFENCE_WEIGHT, MAX_LEVEL * 2.0)
	_set_level(mini(MAX_LEVEL, int(_points / 2.0 + 0.5)))
	_unseen_t = 0.0


## Wipes the slate, e.g. after the player wakes up in hospital.
func clear() -> void:
	_set_level(0)


func _set_level(next: int) -> void:
	if next == level:
		return
	level = next
	level_changed.emit(level)
	if level == 0:
		_points = 0.0
		_dismiss()


## Inspectors lose interest: lights off, engines off, cars left where they are.
func _dismiss() -> void:
	for car in _cars:
		car.siren_on = false
		car.driver = Car.Driver.NONE
		car.throttle = 0.0
		car.handbrake = true
		_retired.append(car)
	_cars.clear()
	_stuck.clear()


## Removes abandoned inspection cars once the player has left them far behind,
## so that a long crime spree does not fill the town with white saloons.
func _sweep_retired(delta: float) -> void:
	_sweep_t -= delta
	if _sweep_t > 0.0 or _retired.is_empty():
		return
	_sweep_t = 2.0
	var prey: Vector3 = _focus.call()
	for car in _retired.duplicate():
		if not is_instance_valid(car):
			_retired.erase(car)
		elif car.driver == Car.Driver.PLAYER:
			_retired.erase(car)  # stolen: it is the player's problem now
		elif car.global_position.distance_to(prey) > TOW_AWAY:
			_retired.erase(car)
			car.queue_free()


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_sweep_retired(delta)
	if level == 0:
		return
	var prey: Vector3 = _focus.call()
	while _cars.size() < mini(level, MAX_CARS):
		if not _dispatch(prey):
			break

	var nearest := INF
	for car in _cars.duplicate():
		if car.wrecked:
			_cars.erase(car)
			continue
		var gap := _chase(car, prey, delta)
		nearest = minf(nearest, gap)

	# Out of sight for long enough: one level down.
	_unseen_t = _unseen_t + delta if nearest > LOSE_SIGHT else 0.0
	if _unseen_t > COOL_DOWN:
		_unseen_t = 0.0
		_points = maxf(0.0, (level - 1) * 2.0)
		_set_level(level - 1)
		return

	var speed := _player.car.speed_kmh() if _player.car else _player.velocity.length() * 3.6
	_caught_t = _caught_t + delta if (nearest < CATCH_RANGE and speed < 8.0) else 0.0
	if _caught_t > CATCH_TIME:
		_caught_t = 0.0
		var amount := FINE_PER_LEVEL * level
		said.emit("פקח", "%s  (-₪%d)" % [LINES.pick_random(), amount])
		fined.emit(amount)
		_set_level(0)


## Sends one inspection car from a street a block or two away.
func _dispatch(prey: Vector3) -> bool:
	var p2 := Vector2(prey.x, prey.z)
	for tries in 40:
		var pts: PackedVector2Array = _city.drive_paths[randi() % _city.drive_paths.size()]
		if pts.size() < 2:
			continue
		var j := randi() % (pts.size() - 1)
		var d := pts[j].distance_to(p2)
		if d < SPAWN_NEAR or d > SPAWN_FAR:
			continue
		var to_prey := (p2 - pts[j]).normalized()
		var car: Car = _spawn_car.call("inspector", Vector3(pts[j].x, 0.4, pts[j].y), atan2(to_prey.x, to_prey.y))
		car.driver = Car.Driver.POLICE
		car.siren_on = true
		_cars.append(car)
		return true
	return false


## Steers one inspector at the player. Returns the distance between them.
func _chase(car: Car, prey: Vector3, delta: float) -> float:
	var to := prey - car.global_position
	to.y = 0
	var dist := to.length()
	var dir := to.normalized()
	var fwd := car.global_transform.basis.z
	var angle := atan2(fwd.cross(dir).y, fwd.dot(dir))
	car.steer_input = clampf(-angle * 2.0, -1.0, 1.0)
	car.throttle = 0.0 if dist < 6.0 else (1.0 if absf(angle) < 1.2 else 0.45)
	car.handbrake = dist < 4.5

	# Wedged against a wall: back out for a moment, then try again.
	var stuck: float = _stuck.get(car, 0.0)
	if dist > 10.0 and absf(car.forward_speed()) < 0.6:
		stuck += delta
	else:
		stuck = maxf(0.0, stuck - delta)
	if stuck > 1.5:
		car.throttle = -0.8
		car.steer_input = -car.steer_input
		if stuck > 3.0:
			stuck = 0.0
	_stuck[car] = stuck
	return dist
