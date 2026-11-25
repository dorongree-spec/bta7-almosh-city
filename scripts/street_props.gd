## Loose things on the pavement: rubbish bags waiting for a collection that
## is not coming, a couch somebody put out in 2019, cones, barrels, pallets.
## Every one is a real physics body, so a car sends them flying. Like the
## pedestrians they are a fixed pool recycled around the player.
##
## Models are from Quaternius' Zombie Apocalypse Kit (CC0, assets/CREDITS.md).
## A kind whose file is missing is simply skipped.
class_name StreetProps
extends Node3D

const DIR := "res://assets/props/"
const COUNT := 70
const SPAWN_MIN := 45.0
const SPAWN_MAX := 170.0
const DESPAWN := 210.0
const PER_TICK := 8          # how many props may be moved in one pass
const TICK := 0.5
## Props live on their own layer: they feel cars, people and walls, but
## nothing is ever blocked by them (and the camera looks straight through).
const PROP_LAYER := 4
const WORLD_LAYER := 1

## file: model name; size: bounding box in metres; mass: kg; odds: how common.
const KINDS := [
	{"file": "trash_bag1", "size": Vector3(0.5, 0.55, 0.5), "mass": 5.0, "odds": 22},
	{"file": "trash_bag2", "size": Vector3(0.9, 0.5, 0.55), "mass": 8.0, "odds": 20},
	{"file": "traffic_cone1", "size": Vector3(0.5, 0.66, 0.5), "mass": 3.0, "odds": 12},
	{"file": "pallet", "size": Vector3(0.9, 0.14, 1.22), "mass": 15.0, "odds": 8},
	{"file": "wheels_stack", "size": Vector3(0.66, 0.61, 0.57), "mass": 24.0, "odds": 7},
	{"file": "plastic_barrier", "size": Vector3(1.04, 0.6, 0.34), "mass": 12.0, "odds": 7},
	{"file": "barrel", "size": Vector3(0.7, 1.15, 0.7), "mass": 20.0, "odds": 6},
	{"file": "fire_hydrant", "size": Vector3(0.52, 0.77, 0.4), "mass": 40.0, "odds": 6},
	{"file": "traffic_barrier1", "size": Vector3(1.56, 1.12, 0.88), "mass": 14.0, "odds": 5},
	{"file": "couch", "size": Vector3(3.0, 0.9, 1.2), "mass": 45.0, "odds": 4},
]

var _city: CityBuilder
var _focus: Callable
var _props: Array[RigidBody3D] = []
var _tick := 0.0
var _rng := RandomNumberGenerator.new()
var _probe := SphereShape3D.new()


func setup(city: CityBuilder, focus: Callable) -> void:
	_city = city
	_focus = focus
	_rng.randomize()
	_probe.radius = 0.9

	# Load each model once; every prop of that kind shares the mesh.
	var meshes := {}
	var total_odds := 0
	var usable: Array[Dictionary] = []
	for kind: Dictionary in KINDS:
		var mesh := _load_mesh(DIR + String(kind.file) + ".gltf")
		if mesh == null:
			continue
		meshes[kind.file] = mesh
		usable.append(kind)
		total_odds += int(kind.odds)
	if usable.is_empty():
		return

	for i in COUNT:
		var roll := _rng.randi() % total_odds
		for kind in usable:
			roll -= int(kind.odds)
			if roll < 0:
				_props.append(_make(kind, meshes[kind.file]))
				break


## The first mesh found in a model file, or null if the file is not there.
func _load_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	var mesh: Mesh = null
	if root is MeshInstance3D:
		mesh = (root as MeshInstance3D).mesh
	else:
		var found := root.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			mesh = (found[0] as MeshInstance3D).mesh
	root.free()
	return mesh


## One prop: a light rigid body with a box for a collider, parked out of
## sight until the first placement pass puts it on a pavement.
func _make(kind: Dictionary, mesh: Mesh) -> RigidBody3D:
	var size: Vector3 = kind.size
	var body := RigidBody3D.new()
	body.mass = kind.mass
	body.collision_layer = PROP_LAYER
	body.collision_mask = WORLD_LAYER | PROP_LAYER
	body.angular_damp = 1.2
	body.linear_damp = 0.2
	body.can_sleep = true
	body.freeze = true
	body.visible = false

	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(collider)

	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.visibility_range_end = 260.0
	body.add_child(visual)

	add_child(body)
	body.position = Vector3(0, -50, 0)
	return body


func _physics_process(delta: float) -> void:
	if _props.is_empty():
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	var centre: Vector3 = _focus.call()
	var moved := 0
	for body in _props:
		if body.visible and body.global_position.distance_to(centre) < DESPAWN and body.global_position.y > -5.0:
			continue
		if _place(body, centre, not body.visible):
			moved += 1
			if moved >= PER_TICK:
				break


## Puts a prop on a pavement near `centre`. `anywhere` also allows spots
## close to the player (used once, before the game is on screen).
func _place(body: RigidBody3D, centre: Vector3, anywhere: bool) -> bool:
	var c2 := Vector2(centre.x, centre.z)
	for tries in 12:
		var i := _rng.randi() % _city.drive_paths.size()
		var pts: PackedVector2Array = _city.drive_paths[i]
		if pts.size() < 2:
			continue
		var j := _rng.randi() % (pts.size() - 1)
		var d := pts[j].distance_to(c2)
		if d > SPAWN_MAX or (not anywhere and d < SPAWN_MIN):
			continue
		var a := pts[j]
		var b := pts[j + 1]
		var along := (b - a).normalized()
		var half_road: float = _city.drive_widths[i] * 0.5 if i < _city.drive_widths.size() else 4.0
		var side := (half_road + _rng.randf_range(1.6, 2.8)) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var p := a.lerp(b, _rng.randf()) + Vector2(-along.y, along.x) * side
		var spot := Vector3(p.x, 0.05, p.y)
		if _blocked(spot):
			continue
		var xform := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), spot)
		body.freeze = false
		body.visible = true
		# Rigid bodies are moved through the physics server so the move sticks.
		PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xform)
		PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
		PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
		return true
	return false


## True if a wall, a car or another prop already occupies the spot.
func _blocked(spot: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _probe
	query.transform = Transform3D(Basis.IDENTITY, spot + Vector3(0, 1.2, 0))
	query.collision_mask = WORLD_LAYER | PROP_LAYER
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
