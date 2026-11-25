## A drivable car built on Godot's raycast-wheel VehicleBody3D. The body
## shell is lofted by CarBody to the silhouette of the kind of car each
## parody imitates (no badges, no brand names).
class_name Car
extends VehicleBody3D

enum Driver { NONE, PLAYER, AI, POLICE }

## Dirty white, faded light blue, beige: what an old "Subara" comes in.
const SUBARA := [Color(0.9, 0.89, 0.84), Color(0.9, 0.89, 0.84), Color(0.62, 0.74, 0.82), Color(0.74, 0.66, 0.5), Color(0.55, 0.57, 0.58)]
const MAZA_OLD := [Color(0.55, 0.12, 0.12), Color(0.86, 0.86, 0.84), Color(0.16, 0.24, 0.42), Color(0.42, 0.45, 0.47), Color(0.2, 0.36, 0.3)]
## Mostly white, as on every young driver's car in town.
const MAZA_NEW := [Color(0.95, 0.95, 0.94), Color(0.95, 0.95, 0.94), Color(0.95, 0.95, 0.94), Color(0.1, 0.1, 0.11), Color(0.5, 0.52, 0.55), Color(0.5, 0.08, 0.1)]

## kind -> spec. Sizes in metres; power/grip tuned for arcade-ish feel.
## Optional "model" (a CC0 scene, see assets/CREDITS.md) replaces the lofted
## shell; "wheels" is then [half track, front axle z, rear axle z, radius].
const SPECS := {
	"sedan": {"label": "משפחתית אפורה", "len": 4.5, "wid": 1.8, "hgt": 1.45, "mass": 1250.0, "power": 4200.0, "top": 46.0, "grip": 2.6, "style": "sedan"},
	"hilo": {"label": "טנדר \"היילו\"", "len": 4.66, "wid": 2.0, "hgt": 1.66, "mass": 1700.0, "power": 5200.0, "top": 44.0, "grip": 2.8, "style": "pickup", "color": Color(0.94, 0.94, 0.92),
		"model": "res://assets/vehicles/pickup.gltf", "model_scale": 0.9, "wheels": [0.846, 1.70, -1.10, 0.40]},
	# The town's two favourite makes, in every body they came in. "colors"
	# is what they are seen in; "odd_bumper" is the chance one bumper came
	# off another car.
	"maza323": {"label": "\"מאזה 323\"", "len": 4.2, "wid": 1.65, "hgt": 1.4, "mass": 980.0, "power": 3300.0, "top": 40.0, "grip": 2.4, "style": "boxy", "colors": MAZA_OLD},
	"maza323_hatch": {"label": "\"מאזה 323\" האצ'בק", "len": 3.98, "wid": 1.65, "hgt": 1.39, "mass": 940.0, "power": 3500.0, "top": 42.0, "grip": 2.5, "style": "hatch", "colors": MAZA_OLD},
	"maza3": {"label": "\"מאזה 3\" לבנה", "len": 4.46, "wid": 1.78, "hgt": 1.44, "mass": 1220.0, "power": 4700.0, "top": 50.0, "grip": 2.8, "style": "hatch_new", "colors": MAZA_NEW},
	"maza6": {"label": "\"מאזה 6\"", "len": 4.86, "wid": 1.84, "hgt": 1.45, "mass": 1420.0, "power": 5300.0, "top": 52.0, "grip": 2.8, "style": "sedan", "colors": MAZA_NEW},
	"subara_dl": {"label": "\"סוברה פשע\" סדאן", "len": 4.25, "wid": 1.62, "hgt": 1.38, "mass": 950.0, "power": 3000.0, "top": 38.0, "grip": 2.3, "style": "boxy", "colors": SUBARA, "odd_bumper": 0.5},
	"subara_dl_wagon": {"label": "\"סוברה פשע\" סטיישן", "len": 4.41, "wid": 1.62, "hgt": 1.42, "mass": 1010.0, "power": 3000.0, "top": 37.0, "grip": 2.3, "style": "wagon", "colors": SUBARA, "odd_bumper": 0.5, "mattress": 0.4},
	"subara_dl_pickup": {"label": "\"סוברה פשע\" טנדר", "len": 4.33, "wid": 1.62, "hgt": 1.4, "mass": 980.0, "power": 3200.0, "top": 38.0, "grip": 2.4, "style": "ute", "colors": SUBARA, "odd_bumper": 0.5},
	"subara89": {"label": "הסוברה של אבא", "len": 4.4, "wid": 1.66, "hgt": 1.4, "mass": 1050.0, "power": 3300.0, "top": 40.0, "grip": 2.5, "style": "wagon", "color": Color(0.78, 0.7, 0.52), "tough": true},
	"hondo_civic": {"label": "\"הונדו סיוויק\" משופרת", "len": 4.41, "wid": 2.0, "hgt": 1.44, "mass": 1150.0, "power": 6200.0, "top": 58.0, "grip": 3.0, "style": "tuned",
		"model": "res://assets/vehicles/sports.gltf", "model_scale": 0.78, "wheels": [0.765, 1.375, -1.236, 0.347]},
	"kia_picanta": {"label": "\"קיה פיקנטה\" משופרת", "len": 3.6, "wid": 1.6, "hgt": 1.45, "mass": 900.0, "power": 3600.0, "top": 44.0, "grip": 2.7, "style": "tuned_small"},
	"taxi": {"label": "מונית \"שקודה\"", "len": 4.7, "wid": 1.8, "hgt": 1.46, "mass": 1300.0, "power": 4300.0, "top": 46.0, "grip": 2.6, "style": "sedan", "color": Color(0.95, 0.95, 0.93), "taxi": true},
	"truck": {"label": "משאית חלוקה", "len": 5.0, "wid": 2.4, "hgt": 2.7, "mass": 2800.0, "power": 6500.0, "top": 32.0, "grip": 2.6, "style": "pickup",
		"model": "res://assets/vehicles/truck.gltf", "model_scale": 0.95, "wheels": [0.893, 1.10, -2.04, 0.418]},
	"sherut": {"label": "מונית שירות", "len": 5.3, "wid": 1.95, "hgt": 2.15, "mass": 1900.0, "power": 4800.0, "top": 38.0, "grip": 2.5, "style": "van", "color": Color(0.96, 0.94, 0.86)},
	"inspector": {"label": "ניידת פיקוח", "len": 4.6, "wid": 1.8, "hgt": 1.5, "mass": 1350.0, "power": 5600.0, "top": 52.0, "grip": 2.9, "style": "sedan", "color": Color(0.97, 0.97, 0.98), "police": true},
}

const NEON := [Color(1, 0.18, 0.58), Color(0, 0.82, 1), Color(0.62, 1, 0), Color(1, 0.8, 0), Color(0.63, 0.13, 0.94)]
## How far a wheel hub rests below its suspension mount (rest length minus static compression).
const SUSPENSION_SAG := 0.126
const AIR_DRAG := 0.42          # N per (m/s)^2: what makes a car coast down
const DOWNFORCE := 1.1          # N per (m/s)^2 pressing the car onto the road
## Driving feel, tuned on the PC with a scripted bench (docs/RUN_NOTES.md).
## SPECS grip values are relative; this maps them to ~1.3-1.6 g of cornering,
## below the ~2.2 g at which a car this wide tips over its own wheels.
const GRIP_SCALE := 0.55
const ROLL_INFLUENCE := 0.08     # how much tyre side force levers the body over
const COM_HEIGHT := 0.15         # centre of mass above the car origin (ground)
const SMOKING_BELOW := 45.0     # health at which the bonnet starts to smoke
const BURNING_BELOW := 18.0     # health at which the engine catches fire
const BURN_RATE := 7.0          # health lost per second once on fire
const TAIL_GLOW := 1.2          # tail lamps while cruising
const BRAKE_GLOW := 7.0         # and with a foot on the brake
## Body styles of the eighties and early nineties: chrome bumpers, thick dust.
var _wheel_r := 0.36
const OLD_STYLES := ["boxy", "wagon", "ute", "hatch"]
const CIVIL := [Color(0.92, 0.92, 0.92), Color(0.15, 0.15, 0.16), Color(0.6, 0.63, 0.67), Color(0.45, 0.1, 0.1), Color(0.12, 0.22, 0.45), Color(0.78, 0.7, 0.55)]

signal crashed(car: Car, impact: float)
signal exploded(car: Car)

var kind := "sedan"
var spec: Dictionary = {}
var driver := Driver.NONE
var health := 100.0
var wrecked := false
var siren_on := false

## Inputs, set by whoever drives: throttle/brake -1..1, steer -1..1 (right +).
var throttle := 0.0
var steer_input := 0.0
var handbrake := false

var _lamps: Array[MeshInstance3D] = []
var _siren_t := 0.0
var _last_velocity := Vector3.ZERO
var _rear_wheels: Array[VehicleWheel3D] = []
var _flipped_t := 0.0
var _headlight: SpotLight3D
var _smoke: GPUParticles3D
var _engine_smoke: GPUParticles3D
var _fire: GPUParticles3D
var _fire_light: OmniLight3D
var _tail_mat: StandardMaterial3D


static func create(car_kind: String) -> Car:
	var c := Car.new()
	c.kind = car_kind if SPECS.has(car_kind) else "sedan"
	c.spec = SPECS[c.kind]
	c._build()
	return c


func _build() -> void:
	add_to_group("cars")
	mass = spec.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, COM_HEIGHT, 0.1)
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	angular_damp = 0.35
	body_entered.connect(_on_body_entered)

	var L: float = spec.len
	var W: float = spec.wid
	var H: float = spec.hgt
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(W, H - 0.35, L)
	col.shape = box
	col.position = Vector3(0, 0.35 + (H - 0.35) / 2, 0)
	add_child(col)

	var color: Color = spec.get("color", NEON.pick_random() if String(spec.style).begins_with("tuned") else CIVIL.pick_random())
	if spec.has("colors"):
		color = (spec.colors as Array).pick_random()
	# [half track, front axle z, rear axle z, radius]
	# Eighties compacts ran 13-inch wheels: smaller than the default (PC tuning).
	_wheel_r = 0.31 if String(spec.style) in OLD_STYLES else 0.36
	var wheels: Array = [W / 2 - 0.10, L * 0.33, -L * 0.33, _wheel_r]
	if _build_model(color):
		wheels = spec.wheels
	else:
		_build_body(L, W, H, color)
	var radius: float = wheels[3]
	for fx in [-1, 1]:
		for front in [true, false]:
			var z: float = wheels[1] if front else wheels[2]
			# The hub hangs SUSPENSION_SAG below this point once the car settles.
			_add_wheel(Vector3(fx * float(wheels[0]), radius + SUSPENSION_SAG, z), front, radius)


## Uses a ready-made model for the body if this kind has one installed.
## The model's own wheels are hidden: ours steer, spin and ride the suspension.
func _build_model(color: Color) -> bool:
	var path := String(spec.get("model", ""))
	if path == "" or not ResourceLoader.exists(path):
		return false
	var scene := load(path) as PackedScene
	if scene == null:
		return false
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * float(spec.get("model_scale", 1.0))
	add_child(model)
	for hidden in ["FrontWheel_L", "FrontWheel_R", "BackWheels"]:
		var wheel := model.find_child(hidden, true, false) as Node3D
		if wheel != null:
			wheel.visible = false
	if String(spec.style).begins_with("tuned"):
		var neon := OmniLight3D.new()
		neon.light_color = color
		neon.light_energy = 1.5
		neon.omni_range = 3.0
		neon.position = Vector3(0, 0.1, 0)
		add_child(neon)
	return true


func _part(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


## Godot vehicles drive towards +Z, so the nose is at +Z. The shell comes
## from CarBody (lofted panels + glass); this adds everything bolted on.
func _build_body(L: float, W: float, H: float, color: Color) -> void:
	var paint := _dusty_paint(color, String(spec.style))
	var glass := CityMaterials.color(Color(0.03, 0.04, 0.06), 0.06, 0.85)
	var dark := CityMaterials.color(Color(0.05, 0.05, 0.05), 0.8)
	var chrome := CityMaterials.color(Color(0.8, 0.8, 0.82), 0.2, 1.0)
	var style: String = spec.style
	var stance: Array = CarBody.stance(style)
	var sill: float = stance[0]
	var belt: float = stance[1]

	var shell := MeshInstance3D.new()
	var mesh := CarBody.build(style, L, W, H)
	mesh.surface_set_material(0, paint)
	mesh.surface_set_material(1, glass)
	shell.mesh = mesh
	add_child(shell)

	# Dark wheel wells: a short drum behind each wheel, just proud of the door skin.
	var well_r := clampf(belt - 0.47, _wheel_r + 0.01, _wheel_r + 0.07)
	for fz in [-1, 1]:
		for fx in [-1, 1]:
			var well := MeshInstance3D.new()
			var drum := CylinderMesh.new()
			drum.top_radius = well_r
			drum.bottom_radius = well_r
			drum.height = 0.34
			drum.radial_segments = 20
			well.mesh = drum
			well.rotation = Vector3(0, 0, PI / 2)
			well.position = Vector3(fx * (W / 2 - 0.166), _wheel_r, fz * L * 0.33)
			well.material_override = dark
			add_child(well)

	# Bumpers, grille, lights and the yellow number plates.
	var old_school := style in OLD_STYLES
	var bumper := chrome if old_school else dark
	# One bumper from the scrapyard, in whatever colour the donor car was.
	var odd_end := 0
	if randf() < float(spec.get("odd_bumper", 0.0)):
		odd_end = -1 if randf() < 0.5 else 1
	var odd_bumper := CityMaterials.color(CIVIL.pick_random(), 0.6)
	var plate := CityMaterials.color(Color(0.95, 0.8, 0.1), 0.5)
	var nose_y := belt - (0.30 if not old_school else 0.20)
	# Each car owns its tail-lamp material so that only its own lamps flare under braking.
	_tail_mat = CityMaterials.emissive(Color(0.8, 0.05, 0.05), TAIL_GLOW).duplicate() as StandardMaterial3D
	for end in [-1, 1]:
		var z: float = end * L / 2
		_part(Vector3(W * 0.9, 0.16, 0.14), Vector3(0, sill + 0.1, z), odd_bumper if end == odd_end else bumper)
		_part(Vector3(0.5, 0.11, 0.03), Vector3(0, sill + 0.12, z + end * 0.08), plate)
		for side in [-1, 1]:
			if end > 0:
				_part(Vector3(0.36, 0.13, 0.06), Vector3(side * W * 0.3, nose_y, z - 0.01), CityMaterials.emissive(Color(1, 0.97, 0.85), 1.5))
			else:
				_part(Vector3(0.3, 0.13, 0.06), Vector3(side * W * 0.31, belt - 0.2, z + 0.01), _tail_mat)
	_part(Vector3(W * 0.36, 0.1, 0.05), Vector3(0, nose_y, L / 2 - 0.005), dark)  # grille
	# Door mirrors at the base of the windscreen.
	for side in [-1, 1]:
		_part(Vector3(0.16, 0.1, 0.07), Vector3(side * (W / 2 + 0.05), belt + 0.06, L * 0.2), dark)

	match style:
		"pickup", "ute":
			# The mattress in the load bed is canon.
			_part(Vector3(W * 0.8, 0.22, L * 0.34), Vector3(0, belt + 0.13, -L * 0.28), CityMaterials.color(Color(0.75, 0.68, 0.8), 0.9), Vector3(0.06, 0, 0))
		"wagon":
			_part(Vector3(W * 0.7, 0.05, L * 0.4), Vector3(0, H + 0.07, -L * 0.15), chrome)  # roof rack
			if randf() < float(spec.get("mattress", 0.0)):
				_part(Vector3(W * 0.74, 0.18, L * 0.44), Vector3(0, H + 0.19, -L * 0.15), CityMaterials.color(Color(0.75, 0.68, 0.8), 0.9))
		"tuned", "tuned_small":
			# The "improvements": a wing you could land a plane on, and neon.
			_part(Vector3(W * 1.02, 0.05, 0.4), Vector3(0, H + 0.02, -L / 2 + 0.25), dark)
			for side in [-1, 1]:
				_part(Vector3(0.05, H - belt + 0.1, 0.05), Vector3(side * W * 0.36, (H + belt) / 2, -L / 2 + 0.25), dark)
			var neon := OmniLight3D.new()
			neon.light_color = color
			neon.light_energy = 1.5
			neon.omni_range = 3.0
			neon.position = Vector3(0, 0.1, 0)
			add_child(neon)

	if spec.get("taxi", false):
		_part(Vector3(0.9, 0.2, 0.3), Vector3(0, H + 0.1, -L * 0.03), CityMaterials.emissive(Color(1, 0.8, 0.1), 0.8))
	if spec.get("police", false):
		for side in [-1, 1]:
			_part(Vector3(0.02, 0.14, L * 0.6), Vector3(side * (W / 2 + 0.005), belt - 0.25, 0), CityMaterials.color(Color(0.1, 0.3, 0.7), 0.5))
		_lamps.append(_part(Vector3(0.5, 0.14, 0.26), Vector3(0.28, H + 0.08, -L * 0.03), CityMaterials.emissive(Color(1, 0.1, 0.1), 0.2).duplicate()))
		_lamps.append(_part(Vector3(0.5, 0.14, 0.26), Vector3(-0.28, H + 0.08, -L * 0.03), CityMaterials.emissive(Color(0.1, 0.25, 1), 0.2).duplicate()))


## Car paint with clearcoat plus Negev dust: thick on the sills and wheel
## arches, fading up the doors, broken up by sand grain. Old boxy cars carry
## the most, tuned ones are kept almost clean. Model-space, so it stays put
## on a moving car.
const PAINT_SHADER := """
shader_type spatial;
uniform vec3 paint : source_color = vec3(0.6);
uniform float dust = 0.5;
uniform float top = 1.4;
uniform sampler2D grain : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 local;
void vertex() {
	local = VERTEX;
}
void fragment() {
	float g = texture(grain, local.xz * 0.9 + local.y * 0.37).r;
	float g2 = texture(grain, local.zy * 1.3).g;
	float height = clamp(local.y / top, 0.0, 1.0);
	float d = clamp(dust * (smoothstep(0.75, 0.05, height) * 1.2 + 0.15) * (0.55 + g * 0.9) - (g2 - 0.5) * 0.25, 0.0, 1.0);
	vec3 dirt = vec3(0.62, 0.53, 0.41) * (0.85 + g * 0.3);
	ALBEDO = mix(paint, dirt, d * 0.85);
	METALLIC = 0.3 * (1.0 - d);
	ROUGHNESS = mix(0.32, 0.92, d);
	CLEARCOAT = 0.8 * (1.0 - d);
	CLEARCOAT_ROUGHNESS = 0.08 + d * 0.5;
}
"""
static var _paint_shader: Shader


func _dusty_paint(color: Color, style: String) -> Material:
	var grain := CityMaterials._tex("sand_diff")
	if grain == null:
		return CityMaterials.paint(color)
	if _paint_shader == null:
		_paint_shader = Shader.new()
		_paint_shader.code = PAINT_SHADER
	var m := ShaderMaterial.new()
	m.shader = _paint_shader
	m.set_shader_parameter("paint", color)
	m.set_shader_parameter("grain", grain)
	m.set_shader_parameter("top", float(spec.hgt))
	var dust := randf_range(0.45, 0.85) if (style in OLD_STYLES or style == "pickup") else randf_range(0.15, 0.45)
	if style.begins_with("tuned"):
		dust = randf_range(0.0, 0.15)
	m.set_shader_parameter("dust", dust)
	return m


func _add_wheel(pos: Vector3, front: bool, radius: float) -> void:
	var w := VehicleWheel3D.new()
	w.position = pos
	w.use_as_steering = front
	w.use_as_traction = true if spec.style == "pickup" else not front  # 4x4 pickups
	if spec.style.begins_with("tuned") or spec.style in ["sedan", "hatch", "hatch_new"]:
		w.use_as_traction = front  # front-wheel drive
	w.wheel_radius = radius
	w.wheel_rest_length = 0.18
	w.suspension_travel = 0.2
	# Softer springs so the weight shows: 3-4 deg of lean in hard bends (old
	# Subaru the most), with no rollovers (PC bench, docs/RUN_NOTES.md).
	w.suspension_stiffness = 20.0 if not spec.style.begins_with("tuned") else 34.0
	w.damping_compression = 1.1
	w.damping_relaxation = 1.5
	w.wheel_friction_slip = float(spec.grip) * GRIP_SCALE
	w.wheel_roll_influence = ROLL_INFLUENCE
	var tire := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.24
	cyl.radial_segments = 16
	tire.mesh = cyl
	tire.rotation = Vector3(0, 0, PI / 2)
	tire.material_override = CityMaterials.color(Color(0.06, 0.06, 0.06), 0.9)
	w.add_child(tire)
	var rim := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = radius * 0.62
	rc.bottom_radius = radius * 0.62
	rc.height = 0.26
	rim.mesh = rc
	rim.rotation = Vector3(0, 0, PI / 2)
	# Mid-grey and a bit rough: the old bright mirror finish reflected the sky
	# and read as flat white discs from the chase camera.
	rim.material_override = CityMaterials.color(Color(0.42, 0.43, 0.45), 0.4, 0.9)
	w.add_child(rim)
	add_child(w)
	if not front:
		_rear_wheels.append(w)


## One wide beam per car is enough to light the road and costs half as much as two.
func set_headlights(on: bool) -> void:
	if _headlight == null:
		if not on:
			return
		_headlight = SpotLight3D.new()
		_headlight.light_color = Color(1.0, 0.95, 0.82)
		_headlight.light_energy = 10.0  # PC tuning: lit only a small patch before
		_headlight.spot_range = 45.0
		_headlight.spot_angle = 40.0
		_headlight.shadow_enabled = false
		_headlight.light_volumetric_fog_energy = 2.5  # visible beams in the night dust
		var length: float = spec.len
		_headlight.position = Vector3(0, 0.75, length / 2)
		# Spot lights shine along -Z; the nose of the car is +Z.
		_headlight.rotation = Vector3(deg_to_rad(-4.0), PI, 0)
		add_child(_headlight)
	_headlight.visible = on and not wrecked


func speed_kmh() -> float:
	return linear_velocity.length() * 3.6


## Signed forward speed in m/s.
func forward_speed() -> float:
	return linear_velocity.dot(global_transform.basis.z)


func _physics_process(delta: float) -> void:
	_update_damage_effects(delta)
	if wrecked:
		engine_force = 0
		brake = 20
		return
	var fwd := forward_speed()
	# Air: drag against the direction of travel, and a push onto the road
	# that grows with speed so the car stays planted through fast bends.
	var speed := linear_velocity.length()
	apply_central_force(-linear_velocity * speed * AIR_DRAG)
	apply_central_force(-global_transform.basis.y * speed * speed * DOWNFORCE)
	# A parked car the physics engine has put to sleep ignores engine force;
	# wake it as soon as the driver asks for anything (PC: tour car sat at 0 km/h).
	if sleeping and driver != Driver.NONE and (absf(throttle) > 0.05 or absf(steer_input) > 0.05):
		sleeping = false
	var top: float = spec.top
	var power: float = spec.power
	if throttle > 0.05:
		if fwd < -1.0:
			engine_force = 0
			brake = 40.0 * throttle
		else:
			brake = 0
			# Full pull most of the way up, fading only near the top speed.
			var r := clampf(fwd / top, 0.0, 1.0)
			engine_force = power * throttle * (1.0 - r * r * r * r)
	elif throttle < -0.05:
		if fwd > 1.0:
			engine_force = 0
			brake = 45.0 * -throttle
		else:
			brake = 0
			engine_force = power * 0.55 * throttle
	else:
		engine_force = 0
		brake = 2.0
	# Handbrake locks the rear axle only and lets it slide, so the tail steps out.
	var grip: float = float(spec.grip) * GRIP_SCALE
	for w in _rear_wheels:
		w.wheel_friction_slip = grip * (0.4 if handbrake else 1.0)
		if handbrake:
			w.brake = 60.0
	# Less steering lock at speed keeps it drivable on a keyboard.
	var lock := lerpf(0.6, 0.18, clampf(absf(fwd) / 35.0, 0.0, 1.0))
	steering = move_toward(steering, -steer_input * lock, delta * 2.8)

	if _tail_mat != null:
		var braking := driver != Driver.NONE and (brake > 5.0 or handbrake)
		_tail_mat.emission_energy_multiplier = BRAKE_GLOW if braking else TAIL_GLOW
	_update_tyre_smoke(fwd)
	_right_if_flipped(delta)
	_update_siren(delta)
	_last_velocity = linear_velocity


## Tyre smoke off the rear axle while the handbrake is on or the car is
## thrown hard into a bend. Only the player's car gets an emitter.
func _update_tyre_smoke(forward_speed_now: float) -> void:
	if driver != Driver.PLAYER:
		if _smoke != null:
			_smoke.emitting = false
		return
	if _smoke == null:
		_smoke = _make_smoke()
		add_child(_smoke)
	var speed := absf(forward_speed_now)
	_smoke.emitting = (handbrake and speed > 3.0) or (absf(steer_input) > 0.8 and speed > 16.0)


func _make_smoke() -> GPUParticles3D:
	# 36 bigger puffs read the same as 60 and cost far less overdraw at 1080p (PC tuning).
	var smoke := Puffs.make(Color(0.9, 0.87, 0.8), 36, 1.3, Vector3(float(spec.wid) * 0.5, 0.05, 0.25), 0.8, 1.3)
	smoke.position = Vector3(0, 0.25, -float(spec.len) * 0.33)
	return smoke


# --- damage ----------------------------------------------------------------------------

## A battered engine smokes, a wrecked one burns, and a burning one does not
## last long. Emitters are only created for cars that actually get that far.
func _update_damage_effects(delta: float) -> void:
	if health >= SMOKING_BELOW:
		return
	var bonnet := Vector3(0, float(spec.hgt) * 0.62, float(spec.len) * 0.36)
	if _engine_smoke == null:
		var grey := Color(0.75, 0.75, 0.75) if not wrecked else Color(0.07, 0.07, 0.07)
		_engine_smoke = Puffs.make(grey, 40, 2.4, Vector3(0.3, 0.05, 0.3), 2.6, 1.6)
		_engine_smoke.position = bonnet
		add_child(_engine_smoke)
	_engine_smoke.emitting = true
	if health >= BURNING_BELOW and not wrecked:
		return
	if _fire == null:
		_fire = Puffs.make(Color(1.0, 0.5, 0.12), 48, 0.7, Vector3(0.45, 0.1, 0.45), 4.5, 0.9, true)
		_fire.position = bonnet
		add_child(_fire)
		_fire_light = OmniLight3D.new()
		_fire_light.light_color = Color(1.0, 0.55, 0.2)
		_fire_light.omni_range = 9.0
		_fire_light.shadow_enabled = false
		_fire_light.position = bonnet + Vector3(0, 0.6, 0)
		add_child(_fire_light)
	_fire.emitting = true
	_fire_light.light_energy = randf_range(2.0, 3.6)  # flicker
	if not wrecked:
		damage(BURN_RATE * delta)


## The end of a car: a jolt, a fireball and thick black smoke afterwards.
func _explode() -> void:
	apply_central_impulse(Vector3.UP * mass * 3.5)
	apply_torque_impulse(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * mass * 1.5)
	var blast := Puffs.make(Color(1.0, 0.62, 0.2), 70, 0.9, Vector3(0.9, 0.5, 1.4), 3.0, 2.6, true)
	blast.one_shot = true
	blast.explosiveness = 0.95
	blast.position = Vector3(0, float(spec.hgt) * 0.5, 0)
	add_child(blast)
	blast.emitting = true
	if _engine_smoke != null:
		# Swap the grey wisps for black smoke.
		_engine_smoke.queue_free()
		_engine_smoke = null
	exploded.emit(self)
	get_tree().call_group("blast_listeners", "on_car_exploded", self)


## A car left on its roof or side puts itself back on its wheels.
func _right_if_flipped(delta: float) -> void:
	var on_side := global_transform.basis.y.y < 0.3
	_flipped_t = _flipped_t + delta if (on_side and linear_velocity.length() < 2.0) else 0.0
	if _flipped_t > 2.0:
		_flipped_t = 0.0
		global_transform = Transform3D(Basis(Vector3.UP, global_rotation.y), global_position + Vector3(0, 1.0, 0))
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


func _update_siren(delta: float) -> void:
	if _lamps.is_empty():
		return
	_siren_t += delta * 8.0
	var on := siren_on and sin(_siren_t) > 0
	(_lamps[0].material_override as StandardMaterial3D).emission_energy_multiplier = 6.0 if on else 0.2
	(_lamps[1].material_override as StandardMaterial3D).emission_energy_multiplier = 6.0 if (siren_on and not on) else 0.2


func _on_body_entered(_body: Node) -> void:
	var impact := (_last_velocity - linear_velocity).length()
	if impact < 3.0:
		return
	damage(impact * (0.25 if spec.get("tough", false) else 2.0))
	crashed.emit(self, impact)


func damage(amount: float) -> void:
	if wrecked:
		return
	health -= amount
	if health <= 0:
		wrecked = true
		driver = Driver.NONE
		siren_on = false
		for child in find_children("*", "MeshInstance3D", true, false):
			(child as MeshInstance3D).material_override = CityMaterials.color(Color(0.08, 0.07, 0.07), 1.0)
		if _headlight != null:
			_headlight.visible = false
		_explode()


## Back to full health, smoke and flames out. A wreck stays a wreck.
func repair() -> void:
	if wrecked:
		return
	health = 100.0
	for emitter: GPUParticles3D in [_engine_smoke, _fire]:
		if emitter != null:
			emitter.emitting = false
	if _fire_light != null:
		_fire_light.light_energy = 0.0
