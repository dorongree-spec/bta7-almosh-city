## Keter plastic chairs ("כסאות כתר פלסטיק") lying about town, and chairs
## in the air.
##
## Chairs are scattered on the pavements around the player as he moves
## (the same chairs in the same places every time), a few more of them
## near home on Avraham Avinu street. The player picks them up, carries
## up to Player.MAX_CHAIRS, and throws them one at a time. A thrown chair
## floors whoever it meets, then lies where it fell and can be picked up
## again. People in the street throw them too: their throws carry their
## own `blow`, so a chair thrown at the player hits the player.
##
##   chairs.setup(player, _nearest_pavement, func(at): return _land_blow(at, true))
##   if chairs.take(player.global_position): player.give_chair()
##   chairs.throw(player.global_position, player.rotation.y)
##   chairs.throw(walker.global_position, yaw, func(at): return hit_by_walker(at), 11.0)
class_name Chairs
extends Node3D

const THROW_ACTION := "throw"          # the G key; added to the input map here
const CELL := 45.0                     # metres; the town is cut into squares this size
const REACH := 3                       # squares around the player that have their chairs out
const CHECK_EVERY := 0.6               # seconds between looks at which squares are near
const PICK_UP_REACH := 1.6             # metres
const HOME := Vector3(520.0, 0.0, -2505.0)   # Avraham Avinu 15 (OSM geocode: the block at x 509, z -2505)
const HOME_RADIUS := 450.0             # metres round home with an extra chair per square
const THROW_SPEED := 15.0              # metres a second, forwards
const THROW_LIFT := 4.5                # metres a second, upwards
const GRAVITY := 20.0
const HAND_HEIGHT := 1.4               # metres above the ground a throw starts from
const ARMED_AFTER := 1.3               # metres flown before a chair can hit anybody

var _player: Player
var _pavement: Callable                # (Vector3) -> Vector3: the pavement nearest a point
var _blow: Callable                    # (Vector3) -> bool: something there took the hit
var _out := {}                         # Vector2i square -> Array of chairs lying in it
var _taken := {}                       # "x_z_n" of scattered chairs already picked up
var _fallen: Array[Node3D] = []        # thrown chairs lying where they landed
var _flying: Array[Dictionary] = []    # {node, velocity, flown}
var _check_in := 0.0


func setup(player: Player, pavement: Callable, blow: Callable) -> void:
	_player = player
	_pavement = pavement
	_blow = blow
	if not InputMap.has_action(THROW_ACTION):
		var key := InputEventKey.new()
		key.physical_keycode = KEY_G
		InputMap.add_action(THROW_ACTION)
		InputMap.action_add_event(THROW_ACTION, key)


## Picks up the chair lying nearest `at`, if one is within reach.
func take(at: Vector3) -> bool:
	for chair in _fallen:
		if chair.global_position.distance_to(at) < PICK_UP_REACH:
			_fallen.erase(chair)
			chair.queue_free()
			return true
	for square: Vector2i in _out:
		var lying: Array = _out[square]
		for chair: Node3D in lying:
			if chair.global_position.distance_to(at) < PICK_UP_REACH:
				_taken[String(chair.name)] = true
				lying.erase(chair)
				chair.queue_free()
				return true
	return false


## Sends a chair flying from a hand at `from`, towards `yaw`. Without a
## `blow` of its own the chair hits whatever the player's blows hit.
func throw(from: Vector3, yaw: float, blow := Callable(), speed := THROW_SPEED) -> void:
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var chair := Props.chair()
	add_child(chair)
	chair.global_position = from + Vector3(0.0, HAND_HEIGHT, 0.0) + forward * 0.6
	chair.rotation.y = yaw
	_flying.append({"node": chair, "velocity": forward * speed + Vector3.UP * THROW_LIFT, "flown": 0.0,
		"blow": blow if blow.is_valid() else _blow})


func _process(delta: float) -> void:
	if _player == null:
		return
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = CHECK_EVERY
		_put_out_near(_player.global_position)


func _physics_process(delta: float) -> void:
	for flight: Dictionary in _flying.duplicate():
		_fly(flight, delta)


## Moves one thrown chair a step: it stops at a wall, floors the first
## person it reaches, and lies down where it meets the ground.
func _fly(flight: Dictionary, delta: float) -> void:
	var chair: Node3D = flight.node
	var velocity: Vector3 = flight.velocity
	velocity.y -= GRAVITY * delta
	var from := chair.global_position
	var to := from + velocity * delta
	var ray := PhysicsRayQueryParameters3D.create(from, to)
	ray.exclude = [_player.get_rid()]
	var wall := get_world_3d().direct_space_state.intersect_ray(ray)
	var stopped := not wall.is_empty()
	if stopped:
		to = from
	flight.flown = float(flight.flown) + from.distance_to(to)
	var blow: Callable = flight.blow
	if float(flight.flown) > ARMED_AFTER and bool(blow.call(Vector3(to.x, 0.0, to.z))):
		stopped = true
	chair.global_position = to
	chair.rotate_x(delta * 9.0)
	flight.velocity = velocity
	if stopped or to.y <= 0.05:
		_flying.erase(flight)
		chair.global_position = Vector3(to.x, 0.0, to.z)
		chair.rotation = Vector3(0.0, chair.rotation.y, 0.0)
		_fallen.append(chair)


## Puts the chairs of the squares near `centre` out and clears the far ones.
func _put_out_near(centre: Vector3) -> void:
	var middle := Vector2i(floori(centre.x / CELL), floori(centre.z / CELL))
	for square: Vector2i in _out.keys():
		if absi(square.x - middle.x) > REACH + 1 or absi(square.y - middle.y) > REACH + 1:
			for chair: Node3D in _out[square]:
				chair.queue_free()
			_out.erase(square)
	for dx in range(-REACH, REACH + 1):
		for dz in range(-REACH, REACH + 1):
			var square := middle + Vector2i(dx, dz)
			if not _out.has(square):
				_out[square] = _scatter(square)


## The chairs of one square: none, one or two, and one more near home.
## The dice are seeded by the square, so a square always holds the same chairs.
func _scatter(square: Vector2i) -> Array:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(square)
	var corner := Vector3(square.x * CELL, 0.0, square.y * CELL)
	var roll := dice.randf()
	var count := 2 if roll < 0.15 else (1 if roll < 0.55 else 0)
	if (corner + Vector3(CELL, 0.0, CELL) * 0.5).distance_to(HOME) < HOME_RADIUS:
		count += 1
	var lying := []
	for n in count:
		var guess := corner + Vector3(dice.randf() * CELL, 0.0, dice.randf() * CELL)
		var spot: Vector3 = _pavement.call(guess)
		var id := "%d_%d_%d" % [square.x, square.y, n]
		if spot.distance_to(guess) > CELL or _taken.has(id):
			continue        # no street near this square, or already picked up
		var chair := Props.chair()
		chair.name = id
		add_child(chair)
		chair.global_position = spot + Vector3(dice.randf_range(-1.2, 1.2), 0.0, dice.randf_range(-1.2, 1.2))
		chair.rotation.y = dice.randf() * TAU
		if dice.randf() < 0.25:
			chair.rotation.z = PI / 2.0      # knocked over
			chair.position.y = 0.25
		lying.append(chair)
	return lying
