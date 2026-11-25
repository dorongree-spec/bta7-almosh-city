## A person. Uses the rigged, animated body (RiggedBody) when its model is
## installed; otherwise builds a low-poly figure with jointed limbs and a
## procedural walk cycle. Shared by the player, pedestrians, gangs and
## inspectors, who only ever talk to this class.
class_name Humanoid
extends Node3D

## look: {shirt, pants, skin, hair: Color, prop: String}
var look: Dictionary
var _body := Node3D.new()
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _phase := randf() * 10.0
var _swing_t := 0.0
var _chair: Node3D
var _rig: RiggedBody


static func create(person_look: Dictionary) -> Humanoid:
	var h := Humanoid.new()
	h.look = person_look
	h._build()
	return h


## Far from the camera: freeze the animation (see RiggedBody.set_far).
func set_mid(mid: bool) -> void:
	if _rig != null:
		_rig.set_mid(mid)


func set_far(far: bool) -> void:
	if _rig != null:
		_rig.set_far(far)


static func random_look(rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng if rng else RandomNumberGenerator.new()
	if not rng:
		r.randomize()
	var skins := [Color(0.91, 0.77, 0.63), Color(0.79, 0.6, 0.45), Color(0.66, 0.47, 0.31), Color(0.95, 0.82, 0.71), Color(0.54, 0.35, 0.23)]
	var hair := [Color(0.1, 0.07, 0.03), Color(0.23, 0.16, 0.1), Color(0.42, 0.29, 0.16), Color(0.75, 0.75, 0.75)]
	# What a Beer Sheva pavement actually wears (PC tuning): mostly white, black,
	# grey, khaki and navy tees, a few loud ones.
	var shirts := [Color(0.93, 0.94, 0.95), Color(0.95, 0.95, 0.93), Color(0.1, 0.1, 0.11), Color(0.12, 0.12, 0.13),
		Color(0.55, 0.56, 0.58), Color(0.62, 0.57, 0.45), Color(0.2, 0.26, 0.38), Color(0.36, 0.4, 0.3),
		Color(0.75, 0.22, 0.17), Color(0.18, 0.53, 0.76), Color(0.95, 0.61, 0.07), Color(0.4, 0.2, 0.25)]  # no skin-like beige: it read as naked
	var pants := [Color(0.17, 0.24, 0.31), Color(0.2, 0.29, 0.37), Color(0.12, 0.12, 0.13), Color(0.5, 0.55, 0.55),
		Color(0.36, 0.25, 0.22), Color(0.55, 0.5, 0.38), Color(0.28, 0.3, 0.24)]
	var look := {
		"shirt": shirts[r.randi() % shirts.size()], "pants": pants[r.randi() % pants.size()],
		"skin": skins[r.randi() % skins.size()], "hair": hair[r.randi() % hair.size()], "prop": "",
		# Build: nobody in a crowd is the same height or width.
		"height": r.randf_range(0.9, 1.06), "girth": r.randf_range(0.92, 1.16), "long_hair": r.randf() < 0.4,
	}
	_pick_outfit(look, r)
	# Build and age: some bellies, grey hair means older (a slight stoop),
	# and heads: kippa, cap or bald on some of the men.
	if not look.long_hair and r.randf() < 0.35:
		look.belly = r.randf_range(0.4, 1.0)
	elif r.randf() < 0.12:
		look.belly = r.randf_range(0.3, 0.6)
	look.old = (look.hair as Color).r > 0.6
	if not look.old and r.randf() < 0.1:
		# Teenagers: shorter and thinner.
		look.height = r.randf_range(0.84, 0.9)
		look.girth = r.randf_range(0.84, 0.92)
		look.erase("belly")
	# Standing about: arms down, hands in pockets, arms crossed, hand on hip, phone.
	var p := r.randf()
	look.pose = 0 if p < 0.3 else (1 if p < 0.5 else (2 if p < 0.68 else (3 if p < 0.82 else 4)))
	# Feet: sneakers mostly, sandals and flip-flops in the heat, leather on some.
	var f := r.randf()
	if look.long_hair:
		look.shoes = "sneaker" if f < 0.45 else ("flipflop" if f < 0.65 else ("sandal" if f < 0.9 else "leather"))
	else:
		look.shoes = "sneaker" if f < 0.55 else ("leather" if f < 0.7 else ("sandal" if f < 0.9 else "flipflop"))
	if not look.long_hair:
		var roll := r.randf()
		look.hat = "kippa" if roll < 0.12 else ("cap" if roll < 0.27 else ("bald" if roll < 0.37 else ""))
	return look


## Outfits of the street (Doron's list): matching pastel or leopard tracksuits
## on a quarter of the women, full Bedouin dress on one in ten, black
## tracksuits with four white side stripes on a third of the men. Sets
## look.outfit ("", "tracksuit", "leopard", "leopard_top", "robe") and colours.
static func _pick_outfit(look: Dictionary, r: RandomNumberGenerator) -> void:
	const PASTELS := [Color(0.96, 0.7, 0.78), Color(0.78, 0.68, 0.9), Color(0.66, 0.9, 0.78), Color(0.66, 0.8, 0.96), Color(0.96, 0.9, 0.55)]  # lemon, not peach (peach read as skin)
	var roll := r.randf()
	if look.get("long_hair", false):
		if roll < 0.1:
			look.outfit = "robe"
			look.shirt = Color(0.06, 0.06, 0.07)
			look.pants = Color(0.06, 0.06, 0.07)
		elif roll < 0.25:
			look.outfit = "tracksuit"
			var pastel: Color = PASTELS[r.randi() % PASTELS.size()]
			look.shirt = pastel
			look.pants = pastel
			look.stripes = false
		elif roll < 0.35:
			look.outfit = "leopard" if r.randf() < 0.5 else "leopard_top"
		elif roll < 0.42:
			look.outfit = "tracksuit"
			look.shirt = Color(0.07, 0.07, 0.08)
			look.pants = Color(0.07, 0.07, 0.08)
			look.stripes = true
	else:
		if roll < 0.33:
			look.outfit = "tracksuit"
			look.shirt = Color(0.07, 0.07, 0.08)
			look.pants = Color(0.07, 0.07, 0.08)
			look.stripes = true
		elif roll < 0.38:
			# A Bedouin man's long robe, white or grey, with the keffiyeh.
			look.outfit = "robe"
			look.shirt = Color(0.92, 0.91, 0.88) if r.randf() < 0.6 else Color(0.55, 0.55, 0.53)
			look.pants = look.shirt
			look.prop = "keffiyeh"


## One capsule hanging down from a joint.
func _segment(parent: Node3D, radius: float, length: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = length + radius * 2.0
	cap.radial_segments = 10
	cap.rings = 3
	mi.mesh = cap
	mi.material_override = CityMaterials.color(color, 0.8)
	mi.position = Vector3(0, -length / 2, 0)
	parent.add_child(mi)


## A two-part limb. Returns [upper joint, lower joint]; rotating the upper
## joint swings the whole limb, rotating the lower one bends knee or elbow.
func _limb(pivot: Vector3, radius: float, upper_len: float, lower_len: float, upper: Color, lower: Color) -> Array[Node3D]:
	var top := Node3D.new()
	top.position = pivot
	_body.add_child(top)
	_segment(top, radius, upper_len, upper)
	var joint := Node3D.new()
	joint.position = Vector3(0, -upper_len, 0)
	top.add_child(joint)
	_segment(joint, radius * 0.85, lower_len, lower)
	var parts: Array[Node3D] = [top, joint]
	return parts


func _ball(parent: Node3D, radius: float, color: Color, pos: Vector3, squash := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mi.mesh = sphere
	mi.material_override = CityMaterials.color(color, 0.75)
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)
	return mi


func _block(size: Vector3, color: Color, pos: Vector3, rough := 0.8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = CityMaterials.color(color, rough)
	mi.position = pos
	_body.add_child(mi)
	return mi


func _build() -> void:
	# Always parent _body, even when it stays empty under the rigged model;
	# otherwise every person leaked one orphan Node3D at exit.
	add_child(_body)
	if RiggedBody.available():
		_rig = RiggedBody.create(look)
		add_child(_rig)
		return
	var shirt: Color = look.shirt
	var pants: Color = look.pants
	var skin: Color = look.skin
	var torso := MeshInstance3D.new()
	var tc := CapsuleMesh.new()
	tc.radius = 0.2
	tc.height = 0.68
	torso.mesh = tc
	torso.scale = Vector3(1.15, 1, 0.72)
	torso.material_override = CityMaterials.color(shirt, 0.85)
	torso.position = Vector3(0, 1.22, 0)
	_body.add_child(torso)
	_ball(_body, 0.2, pants, Vector3(0, 0.93, 0), Vector3(1.05, 0.7, 0.72))  # hips
	_ball(_body, 0.06, skin, Vector3(0, 1.58, 0), Vector3(1, 1.3, 1))        # neck
	_ball(_body, 0.125, skin, Vector3(0, 1.7, 0), Vector3(0.92, 1.1, 1))     # head
	_ball(_body, 0.13, look.hair, Vector3(0, 1.74, -0.025), Vector3(0.95, 0.9, 1))

	var leg_l := _limb(Vector3(-0.1, 0.9, 0), 0.085, 0.42, 0.42, pants, pants)
	var leg_r := _limb(Vector3(0.1, 0.9, 0), 0.085, 0.42, 0.42, pants, pants)
	var arm_l := _limb(Vector3(-0.28, 1.46, 0), 0.055, 0.29, 0.27, shirt, skin)
	var arm_r := _limb(Vector3(0.28, 1.46, 0), 0.055, 0.29, 0.27, shirt, skin)
	_leg_l = leg_l[0]
	_knee_l = leg_l[1]
	_leg_r = leg_r[0]
	_knee_r = leg_r[1]
	_arm_l = arm_l[0]
	_elbow_l = arm_l[1]
	_arm_r = arm_r[0]
	_elbow_r = arm_r[1]
	for knee in [_knee_l, _knee_r]:
		# Shoes.
		var shoe := MeshInstance3D.new()
		var sole := BoxMesh.new()
		sole.size = Vector3(0.11, 0.08, 0.26)
		shoe.mesh = sole
		shoe.material_override = CityMaterials.color(Color(0.12, 0.12, 0.13), 0.7)
		shoe.position = Vector3(0, -0.46, 0.06)
		(knee as Node3D).add_child(shoe)
	for elbow in [_elbow_l, _elbow_r]:
		_ball(elbow, 0.05, skin, Vector3(0, -0.31, 0))  # hands

	match String(look.get("prop", "")):
		"keffiyeh":
			_block(Vector3(0.32, 0.14, 0.32), Color(0.95, 0.95, 0.95), Vector3(0, 1.82, 0))
			_block(Vector3(0.33, 0.04, 0.33), Color(0.05, 0.05, 0.05), Vector3(0, 1.87, 0))
		"tracksuit4":
			# Four stripes, because three is for poor people (per the locals).
			for i in 4:
				_block(Vector3(0.02, 0.6, 0.02), Color(0.97, 0.97, 0.97), Vector3(0.24 + i * 0.012, 1.2, 0.0))
				_block(Vector3(0.02, 0.6, 0.02), Color(0.97, 0.97, 0.97), Vector3(-0.24 - i * 0.012, 1.2, 0.0))
			_block(Vector3(0.12, 0.02, 0.02), Color(0.85, 0.7, 0.2), Vector3(0, 1.5, 0.15), 0.2)  # gold chain
		"logo":
			# Brand head to toe, logo the size of a pizza. Invented logo, obviously.
			_block(Vector3(0.22, 0.18, 0.02), Color(1, 1, 1), Vector3(0, 1.25, 0.16))
		"backpack":
			_block(Vector3(0.34, 0.42, 0.18), Color(0.2, 0.25, 0.3), Vector3(0, 1.2, -0.2))
		"vest":
			_block(Vector3(0.46, 0.4, 0.34), Color(0.96, 0.82, 0.25), Vector3(0, 1.22, 0))
			_block(Vector3(0.16, 0.22, 0.04), Color(1, 1, 1), Vector3(0.28, 1.0, 0.12))
		"kitbag":
			var bag := _block(Vector3(0.3, 0.3, 0.85), Color(0.29, 0.33, 0.13), Vector3(0, 1.25, -0.28))
			bag.rotation.x = 0.3


## speed in m/s drives the gait. Positive X rotation swings a limb backwards.
func animate(delta: float, speed: float) -> void:
	if _rig != null:
		_rig.animate(delta, speed)
		return
	_phase += delta * (2.0 + speed * 2.2)
	var stride := minf(1.0, speed / 3.0) * 0.75
	var s := sin(_phase) * stride
	var c := cos(_phase)
	_leg_l.rotation.x = s
	_leg_r.rotation.x = -s
	# A knee bends while its leg is travelling forwards, so the foot clears the ground.
	_knee_l.rotation.x = maxf(0.0, -c) * stride * 1.3
	_knee_r.rotation.x = maxf(0.0, c) * stride * 1.3
	_arm_l.rotation.x = -s * 0.8
	_arm_r.rotation.x = s * 0.8
	_elbow_l.rotation.x = -0.2 - maxf(0.0, s) * 0.7
	_elbow_r.rotation.x = -0.2 - maxf(0.0, -s) * 0.7
	if _swing_t > 0:
		_swing_t -= delta
		_arm_r.rotation.x = -2.2 + (0.35 - _swing_t) * 6.0
		_elbow_r.rotation.x = 0.0
	_body.position.y = absf(sin(_phase)) * 0.04 * stride
	# Lean into a run.
	_body.rotation.x = minf(speed, 8.0) * 0.014


## What the person does while standing still (an animation clip name; only
## the rigged body has more than one).
func set_idle(clip: String) -> void:
	if _rig != null:
		_rig.set_idle(clip)


func swing() -> void:
	if _rig != null:
		_rig.swing()
		return
	_swing_t = 0.35


func set_knockdown(t: float) -> void:
	if _rig != null:
		_rig.set_knockdown(t)
		return
	_body.rotation.x = -t * PI * 0.5
	_body.position.y = t * 0.2


func hold_chair(on: bool) -> void:
	if on and _chair == null:
		_chair = Props.chair()
		_chair.scale = Vector3.ONE * 0.85
		if _rig != null:
			var grip := _rig.hand()
			if grip == null:
				_chair.free()
				_chair = null
				return
			_chair.position = Vector3(0, -0.45, 0.1)
			grip.add_child(_chair)
		else:
			_chair.position = Vector3(0, -0.65, 0.15)
			_arm_r.add_child(_chair)
	if _chair:
		_chair.visible = on
