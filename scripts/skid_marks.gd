## Black rubber left on the road when the player's car slides: a handbrake
## turn or a corner taken far too fast. The marks are short flat strips in a
## fixed pool; the oldest is reused once the pool is full.
class_name SkidMarks
extends MultiMeshInstance3D

const MAX_MARKS := 500
const STEP := 0.5           # metres of travel per strip
const WIDTH := 0.2
const LIFT := 0.09          # just above the road surface, to avoid flicker
const MIN_SPEED := 3.0      # m/s below which nothing is laid down
const FAST_CORNER := 16.0   # m/s at which full steering lock alone leaves marks

var _next := 0
var _used := 0
var _last: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _sliding := false


func _ready() -> void:
	var strip := PlaneMesh.new()  # lies flat, facing up
	strip.size = Vector2(WIDTH, STEP * 1.2)
	var rubber := StandardMaterial3D.new()
	rubber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rubber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rubber.albedo_color = Color(0.02, 0.02, 0.02, 0.55)
	strip.material = rubber

	var pool := MultiMesh.new()
	pool.transform_format = MultiMesh.TRANSFORM_3D
	pool.mesh = strip
	pool.instance_count = MAX_MARKS
	pool.visible_instance_count = 0
	multimesh = pool
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The marks end up all over town, so never cull the pool as a whole.
	custom_aabb = AABB(Vector3(-20000, -10, -20000), Vector3(40000, 20, 40000))


## Call every physics frame with the car being driven, or null on foot.
func track(car: Car) -> void:
	var sliding := car != null and _is_sliding(car)
	if not sliding:
		_sliding = false
		return
	var wheels := _rear_wheels(car)
	if not _sliding:
		# A new slide: start fresh so no strip is drawn from the last one.
		_sliding = true
		_last = wheels
		return
	for i in 2:
		var from := _last[i]
		var to := wheels[i]
		if from.distance_to(to) < STEP:
			continue
		_lay(from, to)
		_last[i] = to


func _is_sliding(car: Car) -> bool:
	var speed := absf(car.forward_speed())
	if car.global_position.y > 1.5:
		return false  # airborne
	return (car.handbrake and speed > MIN_SPEED) or (absf(car.steer_input) > 0.8 and speed > FAST_CORNER)


## Where the two rear tyres touch the road, in world space.
func _rear_wheels(car: Car) -> Array[Vector3]:
	var half_track: float = float(car.spec.wid) * 0.5 - 0.1
	var rear_z: float = -float(car.spec.len) * 0.33
	if car.spec.has("wheels"):
		var layout: Array = car.spec.wheels
		half_track = layout[0]
		rear_z = layout[2]
	var spots: Array[Vector3] = []
	for side: float in [-1.0, 1.0]:
		var spot := car.global_transform * Vector3(side * half_track, 0.0, rear_z)
		spot.y = LIFT
		spots.append(spot)
	return spots


## Puts one strip between two points on the ground.
func _lay(from: Vector3, to: Vector3) -> void:
	var along := (to - from).normalized()
	var across := Vector3.UP.cross(along).normalized()
	var xform := Transform3D(Basis(across, Vector3.UP, along), (from + to) * 0.5)
	multimesh.set_instance_transform(_next, xform)
	_next = (_next + 1) % MAX_MARKS
	_used = mini(_used + 1, MAX_MARKS)
	multimesh.visible_instance_count = _used
