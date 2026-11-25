## The protagonist on foot. Movement is camera-relative; the camera rig
## lives in Main and feeds `camera_yaw`.
class_name Player
extends CharacterBody3D

const WALK := 4.2
const RUN := 7.6
const GRAVITY := 20.0
const ACCEL := 38.0
const DOWN_TIME := 1.7  # seconds spent on the ground after being run over
const MAX_CHAIRS := 5   # plastic chairs carried at once
const CHAIR_HITS := 3   # blows a chair takes before it breaks

var humanoid: Humanoid
var health := 100.0
var money := 500
## 0..100 heat stroke meter (it is Beer Sheva).
var heat := 0.0
var car: Car = null
var camera_yaw := 0.0
## Plastic chairs carried; the top one is in his hand.
var chairs := 0
var has_chair: bool:
	get:
		return chairs > 0
var chair_hits := 0   # blows struck with the chair in his hand
var _punch_cd := 0.0
var _down_t := 0.0
var _hold_t := 0.0


func _ready() -> void:
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	cap.shape = shape
	cap.position.y = 0.9
	add_child(cap)
	humanoid = Humanoid.create({
		"shirt": Color(0.1, 0.33, 0.36), "pants": Color(0.23, 0.36, 0.56),
		"skin": Color(0.79, 0.6, 0.45), "hair": Color(0.1, 0.07, 0.03), "prop": "",
	})
	add_child(humanoid)


func is_down() -> bool:
	return _down_t > 0.0


## Hit by something heavy: thrown by `push` (m/s), hurt, and floored for a moment.
## While down the body does not block traffic, so the car is not stopped dead.
func knock_down(push: Vector3, damage: float) -> void:
	health -= damage
	velocity = push
	_down_t = DOWN_TIME
	collision_layer = 0
	humanoid.set_knockdown(1.0)


## Sliding along the ground until it is time to get up.
func _step_down(delta: float) -> void:
	_down_t -= delta
	velocity.x = move_toward(velocity.x, 0, delta * 9.0)
	velocity.z = move_toward(velocity.z, 0, delta * 9.0)
	velocity.y = 0.0 if (is_on_floor() and velocity.y <= 0.0) else velocity.y - GRAVITY * delta
	move_and_slide()
	if _down_t <= 0.0:
		collision_layer = 1
		humanoid.set_knockdown(0.0)


## Somebody has sat the player down ("shev, shev") for `seconds`: no
## walking and no punching until they are done with him.
func hold(seconds: float) -> void:
	_hold_t = maxf(_hold_t, seconds)
	humanoid.set_idle("Sitting_Idle_Loop")


func _step_held(delta: float) -> void:
	_hold_t -= delta
	velocity = Vector3(0.0, 0.0 if is_on_floor() else velocity.y - GRAVITY * delta, 0.0)
	move_and_slide()
	humanoid.animate(delta, 0.0)
	if _hold_t <= 0.0:
		humanoid.set_idle("Idle_Loop")


## Returns true on the frame a swing is thrown.
func step_on_foot(delta: float) -> bool:
	if _down_t > 0.0:
		_step_down(delta)
		return false
	if _hold_t > 0.0:
		_step_held(delta)
		return false
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var speed := 0.0
	if input.length() > 0.1:
		var fwd := Vector3(sin(camera_yaw), 0, cos(camera_yaw))
		var right := Vector3(-fwd.z, 0, fwd.x)
		var dir := (fwd * input.y + right * input.x).normalized()
		speed = (RUN if Input.is_action_pressed("sprint") else WALK) * minf(1.0, input.length())
		# Ease into the stride instead of snapping to full speed.
		velocity.x = move_toward(velocity.x, dir.x * speed, delta * ACCEL)
		velocity.z = move_toward(velocity.z, dir.z * speed, delta * ACCEL)
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 12.0))
	else:
		velocity.x = move_toward(velocity.x, 0, delta * 30)
		velocity.z = move_toward(velocity.z, 0, delta * 30)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	humanoid.animate(delta, speed)

	_punch_cd -= delta
	if Input.is_action_just_pressed("action") and _punch_cd <= 0:
		_punch_cd = 0.45
		humanoid.swing()
		return true
	return false


func swing_point() -> Vector3:
	return global_position + Vector3(sin(rotation.y), 0, cos(rotation.y)) * 1.1


## Adds a chair to the stack; false if he already carries all he can.
func give_chair() -> bool:
	if chairs >= MAX_CHAIRS:
		return false
	chairs += 1
	humanoid.hold_chair(true)
	return true


## Puts every chair down (a mission may ask for empty hands).
func drop_chair() -> void:
	chairs = 0
	chair_hits = 0
	humanoid.hold_chair(false)


## The chair in his hand is gone: thrown, or broken. The next one comes up.
func lose_chair() -> void:
	chairs = maxi(0, chairs - 1)
	chair_hits = 0
	humanoid.hold_chair(chairs > 0)


## A chair survives three hits, as the folklore demands.
func use_chair_hit() -> void:
	chair_hits += 1
	if chair_hits >= CHAIR_HITS:
		lose_chair()
