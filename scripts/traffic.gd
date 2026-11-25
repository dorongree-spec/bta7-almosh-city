## Civilian traffic that follows the real road polylines. Cars keep to the
## right-hand side, pick a connected road at each end, brake for anything
## in front of them, and are recycled around the player. A second pool of
## empty cars is kept parked, two wheels on the pavement, along the side
## streets near the player, so there is always something to "borrow".
class_name Traffic
extends Node3D

const COUNT := 50  # denser streets (PC: 71-87 fps uncapped)
const CRUISE := 12.0
const SPAWN_MIN := 80.0
const SPAWN_MAX := 260.0
const DESPAWN := 340.0
## Closest a car may appear to the player when the world is first populated.
const SPAWN_NEAREST := 25.0
## Seconds before a car that found no road in range tries again.
const RETRY_DELAY := 2.0
const LANE := 1.9
const PARKED := 30
## Beyond this a moving car leaves the physics engine and is slid along its
## lane instead (PC profiling: 80 simulated VehicleBody3Ds cost ~5 ms a frame).
const GHOST_FROM := 110.0
const GHOST_UNTIL := 95.0
## Parked cars only need physics while the player could bump into them.
const PARKED_SIM := 60.0
## What is on the road, repeated by how common it is: mostly old "Subaras"
## in all three bodies and "Mazas" of every age, as in the real town.
const PARKED_KINDS := [
	"subara_dl", "subara_dl", "subara_dl_wagon", "subara_dl_wagon", "subara_dl_pickup", "subara_dl_pickup",
	"maza323", "maza323", "maza323_hatch", "maza3", "maza3", "maza3", "maza6",
	"sedan", "kia_picanta", "hilo", "subara89",
]
const KINDS := [
	"subara_dl", "subara_dl", "subara_dl", "subara_dl_wagon", "subara_dl_wagon", "subara_dl_pickup", "subara_dl_pickup",
	"maza323", "maza323", "maza323_hatch", "maza323_hatch", "maza3", "maza3", "maza3", "maza6",
	"sedan", "taxi", "taxi", "hondo_civic", "kia_picanta", "hilo", "truck", "sherut",
]

var city: CityBuilder
var player_pos := func() -> Vector3: return Vector3.ZERO

## Road graph: endpoint key -> Array of [path_index, at_start: bool].
var _ends := {}
var _agents: Array = []
var _parked: Array[Car] = []
var _parked_t := 0.0


class Agent:
	var car: Car
	var path: int
	var idx: int  # index of the next waypoint
	var dir: int  # +1 forward along the polyline, -1 backwards
	var stuck := 0.0
	var reverse := 0.0
	var waited := 0.0  # seconds held up by something ahead
	var dodge := 0.0  # > 0 while pulling out round something that is not moving
	var retry := 0.0  # > 0 while parked out of sight, waiting to respawn
	var ghost := false  # far away: out of physics, moved along the lane by script
	var settle := 0.0   # seconds of real physics left before it may become a ghost


func setup(builder: CityBuilder, player_position: Callable) -> void:
	city = builder
	player_pos = player_position
	for i in city.drive_paths.size():
		var pts: PackedVector2Array = city.drive_paths[i]
		_link(pts[0], i, true)
		_link(pts[pts.size() - 1], i, false)
	for i in COUNT:
		var a := Agent.new()
		a.car = Car.create(KINDS.pick_random())
		a.car.driver = Car.Driver.AI
		add_child(a.car)
		_agents.append(a)
		_respawn(a, true)
	for i in PARKED:
		var car := Car.create(PARKED_KINDS.pick_random())
		add_child(car)
		_parked.append(car)
		_park(car, true)


func _key(p: Vector2) -> String:
	return "%d,%d" % [roundi(p.x), roundi(p.y)]


func _link(p: Vector2, path: int, at_start: bool) -> void:
	var k := _key(p)
	if not _ends.has(k):
		_ends[k] = []
	_ends[k].append([path, at_start])


## The player stole this car: stop driving it, and put a fresh one on the
## road somewhere else so the streets do not slowly empty.
func release(car: Car) -> void:
	for a in _agents:
		if a.car == car:
			a.car = Car.create(KINDS.pick_random())
			a.car.driver = Car.Driver.AI
			add_child(a.car)
			_respawn(a)
			return


func _lane_point(a: Agent, i: int) -> Vector3:
	var pts: PackedVector2Array = city.drive_paths[a.path]
	var p := pts[i]
	var j := clampi(i + a.dir, 0, pts.size() - 1)
	var k := clampi(i - a.dir, 0, pts.size() - 1)
	var dir2 := (pts[j] - pts[k]).normalized() * a.dir
	if j == k:
		dir2 = Vector2.RIGHT
	# Right-hand traffic: in Godot's x-east / z-south frame, right of d is (-d.y, d.x).
	var right := Vector2(-dir2.y, dir2.x)
	# Pulling out: aim for the other side of the road for a few seconds.
	var lp := p + right * (LANE - 3.6 * clampf(a.dodge, 0.0, 1.0))
	return Vector3(lp.x, 0.5, lp.y)


func _respawn(a: Agent, anywhere := false) -> void:
	var pp: Vector3 = player_pos.call()
	var here := Vector2(pp.x, pp.z)
	# Never drop a car right on top of the player, even at start-up.
	var min_d := SPAWN_NEAREST if anywhere else SPAWN_MIN
	var pick := Vector2i(-1, -1)
	# Random tries are cheap but the city is ~7 km wide, so most of them land
	# far outside SPAWN_MAX; fall back to scanning every road point in range.
	for tries in 40:
		var i := randi() % city.drive_paths.size()
		var pts: PackedVector2Array = city.drive_paths[i]
		if pts.size() < 2:
			continue
		var j := randi() % (pts.size() - 1)
		var d := here.distance_to(pts[j])
		if d <= SPAWN_MAX and d >= min_d and _spot_free(pts[j], a):
			pick = Vector2i(i, j)
			break
	if pick.x < 0:
		var candidates: Array[Vector2i] = []
		for i in city.drive_paths.size():
			var pts: PackedVector2Array = city.drive_paths[i]
			for j in pts.size() - 1:
				var d := here.distance_to(pts[j])
				if d <= SPAWN_MAX and d >= min_d:
					candidates.append(Vector2i(i, j))
		candidates.shuffle()
		for c in candidates.slice(0, 20):
			if _spot_free(city.drive_paths[c.x][c.y], a):
				pick = c
				break
	if pick.x < 0:
		# Nowhere to go (e.g. out in the desert). Park it frozen out of sight
		# and retry later. It used to be dropped to y = -100, under the world
		# floor, which popped every such car back up at the origin, right where
		# the player starts, in one big pile.
		# Not `freeze`: unfreezing a VehicleBody3D in Godot 4.3 turns its
		# transform into NaN on the next physics step. Disabling the node
		# takes it out of the physics space instead (disable_mode REMOVE).
		a.car.process_mode = Node.PROCESS_MODE_DISABLED
		a.car.visible = false
		a.car.global_position = Vector3(0, -100, 0)
		a.retry = RETRY_DELAY
		return
	a.path = pick.x
	a.dir = 1 if randf() < 0.5 else -1
	a.idx = pick.y + 1 if a.dir > 0 else pick.y
	var start := _lane_point(a, pick.y if a.dir > 0 else pick.y + 1)
	var target := _lane_point(a, a.idx)
	a.car.process_mode = Node.PROCESS_MODE_INHERIT
	a.ghost = false
	a.settle = 1.5  # let it drop onto its wheels before it can go kinematic
	a.car.visible = true
	a.car.linear_velocity = Vector3.ZERO
	a.car.angular_velocity = Vector3.ZERO
	a.car.global_transform = Transform3D(Basis(Vector3.UP, atan2(target.x - start.x, target.z - start.z)), start + Vector3(0, 0.3, 0))
	a.car.health = 100


## True if no other traffic car is already parked on this road point.
func _spot_free(p: Vector2, me: Agent) -> bool:
	for other in _agents:
		if other == me:
			continue
		var c: Car = other.car
		if c.visible and Vector2(c.global_position.x, c.global_position.z).distance_to(p) < 10.0:
			return false
	return true


## Puts an empty car at the kerb of a side street near the player.
func _park(car: Car, anywhere := false) -> void:
	var pp: Vector3 = player_pos.call()
	var here := Vector2(pp.x, pp.z)
	var min_d := 25.0 if anywhere else SPAWN_MIN
	# Random tries first; in a city ~7 km wide most miss SPAWN_MAX, so fall
	# back to the segments that are actually in range (same as _respawn).
	var segs: Array[Vector2i] = []
	for tries in 40:
		var i := randi() % city.drive_paths.size()
		var pts: PackedVector2Array = city.drive_paths[i]
		if pts.size() >= 2:
			segs.append(Vector2i(i, randi() % (pts.size() - 1)))
	var near: Array[Vector2i] = []
	for i in city.drive_paths.size():
		var pts: PackedVector2Array = city.drive_paths[i]
		for j in pts.size() - 1:
			var d := here.distance_to(pts[j])
			if d <= SPAWN_MAX and d >= min_d:
				near.append(Vector2i(i, j))
	near.shuffle()
	segs.append_array(near.slice(0, 60))
	for s in segs:
		var pts: PackedVector2Array = city.drive_paths[s.x]
		var width: float = city.drive_widths[s.x] if s.x < city.drive_widths.size() else 7.0
		if width > 10.0:
			continue
		var seg := pts[s.y + 1] - pts[s.y]
		if seg.length() < 8.0:
			continue
		var p := pts[s.y].lerp(pts[s.y + 1], randf_range(0.25, 0.75))
		var d := here.distance_to(p)
		if d > SPAWN_MAX or d < min_d:
			continue
		var dir := seg.normalized()
		# Half on the pavement, on the right-hand side, nose pointing with the traffic.
		var spot := p + Vector2(-dir.y, dir.x) * (width * 0.5 + 0.95)
		if not _parking_free(spot, car):
			continue
		car.process_mode = Node.PROCESS_MODE_INHERIT
		car.visible = true
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		car.global_transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(spot.x, 0.25, spot.y))
		car.set_meta("parked_at", Time.get_ticks_msec())
		return
	# No kerb in range. Dropping it to y = -100 (under the world floor) used to
	# pop every such car up at the origin, on the player's start point. Take it
	# out of physics instead (not `freeze`: see _respawn); _recycle_parked
	# tries again once it is far from the player.
	car.process_mode = Node.PROCESS_MODE_DISABLED
	car.visible = false
	car.global_position = Vector3(0, -100, 0)


## True if no other parked car is already standing on this spot.
func _parking_free(spot: Vector2, me: Car) -> bool:
	for other in _parked:
		if other != me and other.visible and Vector2(other.global_position.x, other.global_position.z).distance_to(spot) < 7.0:
			return false
	return true


## Parked cars the player has left behind are moved ahead of them again;
## one that was driven off stops being ours to move.
func _recycle_parked(pp: Vector3) -> void:
	for car in _parked.duplicate():
		if car.driver != Car.Driver.NONE or car.wrecked:
			_parked.erase(car)
			car.process_mode = Node.PROCESS_MODE_INHERIT
		elif not car.visible or car.global_position.distance_to(pp) > DESPAWN:
			_park(car)
		else:
			# Settled and out of reach: out of the physics engine until the player comes near.
			var settled: bool = Time.get_ticks_msec() - int(car.get_meta("parked_at", 0)) > 2500
			var far: bool = car.global_position.distance_to(pp) > PARKED_SIM
			car.process_mode = Node.PROCESS_MODE_DISABLED if (far and settled) else Node.PROCESS_MODE_INHERIT


func _physics_process(delta: float) -> void:
	var pp: Vector3 = player_pos.call()
	_parked_t -= delta
	if _parked_t <= 0.0:
		_parked_t = 1.0
		_recycle_parked(pp)
	for a in _agents:
		var car: Car = a.car
		if car.driver != Car.Driver.AI or car.wrecked:
			continue
		if a.retry > 0:
			a.retry -= delta
			if a.retry <= 0:
				_respawn(a)
			continue
		var d := car.global_position.distance_to(pp)
		if d > DESPAWN:
			_respawn(a)
			continue
		a.settle -= delta
		if a.ghost:
			if d < GHOST_UNTIL:
				_wake(a)
			else:
				_slide(a, delta)
				continue
		elif d > GHOST_FROM and a.settle <= 0.0 and a.dodge <= 0.0 and a.reverse <= 0.0:
			a.ghost = true
			car.process_mode = Node.PROCESS_MODE_DISABLED
			_slide(a, delta)
			continue
		_drive(a, delta)


## A far car out of the physics engine: slides along its lane at cruising
## speed, turning towards the next waypoint. Nobody can see the wheels from here.
func _slide(a: Agent, delta: float) -> void:
	var car: Car = a.car
	var pts: PackedVector2Array = city.drive_paths[a.path]
	var target := _lane_point(a, a.idx)
	var pos := car.global_position
	var to := Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	if to.length() < 2.0:
		a.idx += a.dir
		if a.idx < 0 or a.idx >= pts.size():
			_next_road(a)
		return
	var yaw := car.global_rotation.y
	var want := atan2(to.x, to.z)
	yaw = rotate_toward(yaw, want, delta * 1.6)
	var speed := CRUISE if absf(angle_difference(yaw, want)) < 0.4 else 6.0
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(sin(yaw), 0.0, cos(yaw)) * speed * delta)


## Back into the physics engine, already rolling at the speed it was sliding.
func _wake(a: Agent) -> void:
	a.ghost = false
	var car := a.car
	car.process_mode = Node.PROCESS_MODE_INHERIT
	car.linear_velocity = car.global_transform.basis.z * CRUISE * 0.8
	car.angular_velocity = Vector3.ZERO


func _drive(a: Agent, delta: float) -> void:
	var car: Car = a.car
	var pts: PackedVector2Array = city.drive_paths[a.path]
	var target := _lane_point(a, a.idx)
	var to := target - car.global_position
	to.y = 0
	if to.length() < 5.0:
		a.idx += a.dir
		if a.idx < 0 or a.idx >= pts.size():
			_next_road(a)
		return
	var fwd := car.global_transform.basis.z
	var ang := atan2(fwd.cross(to.normalized()).y, fwd.dot(to.normalized()))
	# Positive cross.y means the target is to the left.
	car.steer_input = clampf(-ang * 2.0, -1.0, 1.0)
	var want := CRUISE if absf(ang) < 0.4 else 6.0
	a.dodge = maxf(a.dodge - delta, 0.0)
	var blocker: Object = _blocker(car)
	if blocker != null:
		want = 0.0
		a.waited += delta
		# Held up by something that is going nowhere (a parked or wrecked car,
		# a queue that never clears, two cars nose to nose): pull out round it.
		var patience := 8.0 if blocker is Car and blocker.driver == Car.Driver.AI else 3.0
		if a.waited > patience and a.dodge <= 0.0:
			a.dodge = 4.0
			a.reverse = 0.8
			a.waited = 0.0
		# Still wedged and nobody is looking: put it somewhere else.
		if a.waited > 6.0 and car.global_position.distance_to(player_pos.call()) > 70.0:
			a.waited = 0.0
			_respawn(a)
			return
		if a.dodge > 0.0 and a.reverse <= 0.0:
			want = 3.0  # edge out slowly
	else:
		a.waited = 0.0
	var speed := car.forward_speed()
	car.throttle = clampf((want - speed) * 0.3, -1.0, 1.0)
	car.handbrake = want == 0.0 and speed < 1.0
	if a.reverse > 0:
		a.reverse -= delta
		car.throttle = -0.7
		car.steer_input = -car.steer_input
	elif want > 0 and absf(speed) < 0.5:
		a.stuck += delta
		if a.stuck > 3.0:
			a.stuck = 0
			a.reverse = 1.5
		if a.stuck > 2.5 and car.global_position.distance_to(player_pos.call()) > 120:
			_respawn(a)
	else:
		a.stuck = 0


## Picks a connected road at the end of the current one (no U-turns if possible).
func _next_road(a: Agent) -> void:
	var pts: PackedVector2Array = city.drive_paths[a.path]
	var end := pts[pts.size() - 1] if a.dir > 0 else pts[0]
	var options: Array = _ends.get(_key(end), []).filter(func(o): return o[0] != a.path)
	if options.is_empty():
		a.dir = -a.dir  # dead end: turn around
		a.idx = clampi(a.idx + a.dir * 2, 0, pts.size() - 1)
		return
	var pick: Array = options.pick_random()
	a.path = pick[0]
	var npts: PackedVector2Array = city.drive_paths[a.path]
	a.dir = 1 if pick[1] else -1
	a.idx = 1 if a.dir > 0 else npts.size() - 2
	a.idx = clampi(a.idx, 0, npts.size() - 1)


## Anything in a box swept ahead of the bumper (lane width, ~9 m, longer at
## speed) and not just on one centre line: a car crossing the junction at an
## angle, or nosing in from the side, is seen before the bumpers meet.
func _blocker(car: Car) -> Object:
	var space := car.get_world_3d().direct_space_state
	var reach := clampf(6.0 + car.forward_speed() * 0.6, 6.0, 14.0)
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 1.2, reach)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	var basis := car.global_transform.basis.orthonormalized()
	q.transform = Transform3D(basis, car.global_position + Vector3(0, 0.9, 0) + basis.z * (2.4 + reach * 0.5))
	q.exclude = [car.get_rid()]
	for hit in space.intersect_shape(q, 8):
		var c: Object = hit.collider
		if c is Car or c is CharacterBody3D or (c is Node and c.is_in_group("obstacle")):
			return c
	return null
