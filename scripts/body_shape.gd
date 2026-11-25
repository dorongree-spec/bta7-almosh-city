## Reshapes a rigged body after its animation, every frame: narrower shoulders
## and arms than the athletic base model, a belly, an older man's stoop, and
## relaxed open hands instead of the clips' clenched fists. Runs as a
## SkeletonModifier3D, so it applies on top of whatever clip is playing.
class_name BodyShape
extends SkeletonModifier3D

## 0 = the base model's build, 1 = slight. Shoulders, arms and neck.
var slim := 0.6
## 0 = flat, 1 = a proper belly.
var belly := 0.0
## Radians of forward lean in the upper back (older people).
var stoop := 0.0
var relax_hands := true
## Standing still (not fighting): straight legs at hip width, arms hanging at
## the sides; the clip only keeps the breathing in the spine and head.
var standing := true   # until animate() says he is walking
## How this person stands about: 0 arms at the sides, 1 hands in pockets,
## 2 arms crossed, 3 a hand on the hip, 4 looking at the phone in the right hand.
var pose := 0
var _head_tilt := {}     # bone index -> pose rotation (phone: looking down)
var _arm_down := {}      # bone index -> pose rotation hanging down at the side
var _t := 0.0
var _sway := randf() * TAU

var _ids := {}
var _fingers: PackedInt32Array = []
var _ready_bones := false


func _find(skeleton: Skeleton3D) -> void:
	for name in ["spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r",
			"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "thigh_l", "thigh_r"]:
		_ids[name] = skeleton.find_bone(name)
	for i in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(i)
		for f in ["index", "middle", "ring", "pinky"]:
			if n.begins_with(f + "_0") and not n.contains("leaf"):
				_fingers.append(i)
	_ready_bones = true
	# Rotations that hang each upper arm down from its T-pose rest, a little out
	# and forward, worked out once from the rest skeleton.
	for side in ["l", "r"]:
		var ua := skeleton.find_bone("upperarm_" + side)
		var la := skeleton.find_bone("lowerarm_" + side)
		if ua < 0 or la < 0:
			continue
		var g_ua := skeleton.get_bone_global_rest(ua)
		var g_la := skeleton.get_bone_global_rest(la)
		var now := (g_la.origin - g_ua.origin).normalized()
		var sign := 1.0 if now.x > 0.0 else -1.0
		var want := Vector3(0.16 * sign, -1.0, 0.06).normalized()
		var turn := Quaternion(now, want)
		var parent_g := skeleton.get_bone_global_rest(skeleton.get_bone_parent(ua)).basis.get_rotation_quaternion()
		var rest_g := g_ua.basis.get_rotation_quaternion()
		_arm_down[ua] = (parent_g.inverse() * turn * rest_g).normalized()
		# Forearm: its rest plus a slight bend at the elbow.
		_arm_down[la] = skeleton.get_bone_rest(la).basis.get_rotation_quaternion()
		# Pose variants: where the upper arm and the forearm point (model space,
		# +X is the person's left, +Z forward), per side; sign turns it outward.
		var aims := {}
		match pose:
			1:
				aims = {"l": [Vector3(0.16, -1.0, 0.02), Vector3(-0.2, -0.72, 0.62)], "r": [Vector3(0.16, -1.0, 0.02), Vector3(-0.2, -0.72, 0.62)]}
			2:
				aims = {"l": [Vector3(0.2, -0.8, 0.55), Vector3(-0.92, 0.14, 0.34)], "r": [Vector3(0.2, -0.8, 0.55), Vector3(-0.92, 0.02, 0.38)]}
			3:
				aims = {"l": [Vector3(0.6, -0.75, -0.2), Vector3(-0.6, -0.72, 0.35)]}
			4:
				aims = {"r": [Vector3(0.1, -1.0, 0.2), Vector3(-0.4, 0.25, 0.88)]}
		if aims.has(side):
			var d_up: Vector3 = aims[side][0]
			var d_fore: Vector3 = aims[side][1]
			_aim(skeleton, ua, la, Vector3(d_up.x * sign, d_up.y, d_up.z), Vector3(d_fore.x * sign, d_fore.y, d_fore.z))
	if pose == 4:
		for bone_name in ["neck_01", "Head"]:
			var b := skeleton.find_bone(bone_name)
			if b >= 0:
				var pg := skeleton.get_bone_global_rest(skeleton.get_bone_parent(b)).basis.get_rotation_quaternion()
				var g := Quaternion(Vector3.RIGHT, 0.2) * skeleton.get_bone_global_rest(b).basis.get_rotation_quaternion()
				_head_tilt[b] = (pg.inverse() * g).normalized()


## Upper arm along d_up, forearm along d_fore (model space), from the rest skeleton.
func _aim(skeleton: Skeleton3D, ua: int, la: int, d_up: Vector3, d_fore: Vector3) -> void:
	var g_ua := skeleton.get_bone_global_rest(ua)
	var g_la := skeleton.get_bone_global_rest(la)
	var hand := -1
	for c in skeleton.get_bone_children(la):
		hand = c
	var hand_at := skeleton.get_bone_global_rest(hand).origin if hand >= 0 else g_la.origin + (g_la.origin - g_ua.origin)
	var parent_g := skeleton.get_bone_global_rest(skeleton.get_bone_parent(ua)).basis.get_rotation_quaternion()
	var turn := Quaternion((g_la.origin - g_ua.origin).normalized(), d_up.normalized())
	var ua_g := turn * g_ua.basis.get_rotation_quaternion()
	_arm_down[ua] = (parent_g.inverse() * ua_g).normalized()
	var fore_now := turn * (hand_at - g_la.origin).normalized()
	var turn2 := Quaternion(fore_now, d_fore.normalized())
	var la_g := turn2 * turn * g_la.basis.get_rotation_quaternion()
	_arm_down[la] = (ua_g.inverse() * la_g).normalized()


func _scale(skeleton: Skeleton3D, bone: String, s: Vector3) -> void:
	var i: int = _ids.get(bone, -1)
	if i >= 0:
		skeleton.set_bone_pose_scale(i, s)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	# Only the scale and finger poses that matter at street distance; cheap enough
	# for 60 people when far walkers switch this off (RiggedBody.set_far).
	if skeleton == null:
		return
	if not _ready_bones:
		_find(skeleton)
	# Thinner arms and neck, narrower chest (scale across the bone, not along it).
	var arm := 1.0 - 0.16 * slim
	_scale(skeleton, "upperarm_l", Vector3(arm, 1.0, arm))
	_scale(skeleton, "upperarm_r", Vector3(arm, 1.0, arm))
	_scale(skeleton, "lowerarm_l", Vector3(1.0 / arm * (1.0 - 0.1 * slim), 1.0, 1.0 / arm * (1.0 - 0.1 * slim)))
	_scale(skeleton, "lowerarm_r", Vector3(1.0 / arm * (1.0 - 0.1 * slim), 1.0, 1.0 / arm * (1.0 - 0.1 * slim)))
	var chest := 1.0 - 0.12 * slim
	_scale(skeleton, "spine_03", Vector3(chest, 1.0, 1.0 - 0.08 * slim))
	_scale(skeleton, "neck_01", Vector3(1.0 / chest * (1.0 - 0.12 * slim), 1.0, 1.0 / chest * (1.0 - 0.12 * slim)))
	# The belly: the lower spine grows forward and sideways, the next bone up
	# takes the growth back out so the chest does not swell with it.
	var b := Vector3(1.0 + 0.12 * belly, 1.0, 1.0 + 0.35 * belly)
	_scale(skeleton, "spine_01", b)
	_scale(skeleton, "spine_02", Vector3(1.0 / b.x, 1.0, 1.0 / b.z))
	if stoop > 0.0:
		var i: int = _ids.get("spine_03", -1)
		if i >= 0:
			skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, stoop))
	if standing:
		_t += 1.0 / 60.0
		# Legs straight under the hips, pelvis back to its standing height.
		for leg in ["thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r"]:
			var li := skeleton.find_bone(leg)
			if li >= 0:
				skeleton.set_bone_pose_rotation(li, skeleton.get_bone_rest(li).basis.get_rotation_quaternion())
		var pelvis := skeleton.find_bone("pelvis")
		if pelvis >= 0:
			var rest_pos := skeleton.get_bone_rest(pelvis).origin
			skeleton.set_bone_pose_position(pelvis, rest_pos + Vector3(sin(_t * 0.9 + _sway) * 0.012, 0.0, 0.0))
		for bone: int in _arm_down:
			skeleton.set_bone_pose_rotation(bone, _arm_down[bone])
		for bone: int in _head_tilt:
			skeleton.set_bone_pose_rotation(bone, _head_tilt[bone])
	if relax_hands:
		# Fingers back towards their straight rest pose, just slightly curled.
		for i in _fingers:
			var rest := skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
			skeleton.set_bone_pose_rotation(i, rest * Quaternion(Vector3.RIGHT, 0.25))
