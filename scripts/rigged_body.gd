## A person with a real skeleton and motion-captured style animation.
##
## The body is the mannequin from Quaternius' Universal Animation Library
## (CC0, see assets/CREDITS.md). It ships as a plain two-colour dummy, so at
## load time every vertex is tagged by where it sits on the body (shirt,
## trousers, skin, shoes) and a tiny shader paints each instance with its own
## clothes. Humanoid falls back to its hand-built figure if the model is
## missing, so the game still runs without the asset.
class_name RiggedBody
extends Node3D

const MODEL := "res://assets/characters/mannequin.glb"
const SCALE := 0.96  # the dummy is 1.83 m tall
const LOOPS := ["Idle_Loop", "Idle_Talking_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Dance_Loop", "Sitting_Idle_Loop", "Driving_Loop"]

const SHADER_CODE := """
shader_type spatial;
uniform vec3 shirt : source_color = vec3(0.9);
uniform vec3 pants : source_color = vec3(0.2, 0.3, 0.5);
uniform vec3 skin : source_color = vec3(0.8, 0.6, 0.45);
// Real fabric (CC0, Poly Haven cotton_jersey / denim_fabric), sampled in model
// space so the weave stays on the body while it animates (PC tuning).
uniform sampler2D jersey : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D jersey_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D denim : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D denim_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float weave = 7.0;
// A real body (Universal Base Characters, CC0): its face and hands texture,
// tinted to this person's skin, shows wherever the clothes do not.
uniform bool use_body = false;
// Shorts: below this height (model space, metres) the trouser legs are bare.
uniform float hem = 0.0;
uniform sampler2D body_albedo : source_color, filter_linear_mipmap;
uniform sampler2D body_normal : hint_normal, filter_linear_mipmap;
// Outfits: 0 everyday, 1 tracksuit, 2 leopard suit, 3 leopard top, 4 long robe.
uniform int outfit = 0;
uniform bool stripes = false;      // four white stripes down legs and sleeves
uniform bool cover_head = false;   // robe hides the hair (Bedouin women)
// This material is on a garment layer (not the body underneath).
uniform bool is_layer = false;
// Sandals and flip-flops: the feet are skin, not painted shoes.
uniform bool bare_feet = false;
varying vec3 local;
varying vec3 nl;
varying vec3 rest;
void vertex() {
	local = VERTEX;
	nl = NORMAL;
	rest = CUSTOM0.xyz;
}
// Cell noise for the leopard rosettes.
vec2 cell_hash(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}
float cell_dist(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 c = o + cell_hash(i + o) * 0.8 + 0.1;
			d = min(d, length(f - c));
		}
	}
	return d;
}
vec3 leopard(vec3 p) {
	float d = cell_dist(vec2(p.x + p.z * 0.8, p.y) * 13.0);
	vec3 base = vec3(0.8, 0.6, 0.33);
	vec3 ring = vec3(0.12, 0.08, 0.05);
	vec3 inner = vec3(0.6, 0.38, 0.18);
	float rosette = smoothstep(0.18, 0.22, d) * (1.0 - smoothstep(0.3, 0.34, d));
	vec3 col = mix(base, inner, 1.0 - smoothstep(0.16, 0.2, d));
	return mix(col, ring, rosette);
}
void fragment() {
	// The tags blend across a triangle, so sleeves and collars came out as soft
	// smears of shirt into skin. Take whichever tag wins, with a thin edge.
	vec3 c = COLOR.rgb;
	float total = c.r + c.g + c.b;
	vec3 mask = vec3(
		smoothstep(-0.04, 0.04, c.r - max(c.g, c.b)),
		smoothstep(-0.04, 0.04, c.g - max(c.r, c.b)),
		smoothstep(-0.04, 0.04, c.b - max(c.r, c.g))) * smoothstep(0.4, 0.6, total);
	float shoes = 1.0 - clamp(mask.r + mask.g + mask.b, 0.0, 1.0);
	if (use_body && !is_layer) {
		// The body under its garment layer: only skin (and shoes) is left of it;
		// the edge triangles it keeps under the layer's hems must not show cloth.
		mask = vec3(0.0, 0.0, 1.0 - shoes);
	} else if (use_body) {
		// Top or trousers by the rest-pose rule itself (as _region draws it), so the
		// waist and the sleeves end on straight lines instead of along triangle edges.
		float cloth = clamp(mask.r + mask.g, 0.0, 1.0);
		float legs_here = step(rest.y, 0.92) * step(abs(rest.x), 0.32);
		mask.r = cloth * (1.0 - legs_here);
		mask.g = cloth * legs_here;
	}
	if (bare_feet) {
		mask.b += shoes;
		shoes = 0.0;
	}
	if (outfit == 4) {
		// The robe layer is all cloth; what is left of the body beneath is skin.
		mask = is_layer ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 0.0, 1.0 - shoes);
	}
	float bare = mask.g * (1.0 - step(hem, use_body ? rest.y : local.y));
	mask = vec3(mask.r, mask.g - bare, mask.b + bare);
	vec2 uv = vec2(local.x + local.z * 0.7, local.y) * weave;
	float js = dot(texture(jersey, uv).rgb, vec3(0.333)) * 0.9 + 0.55;  // softer: whites no longer clip flat
	float dn = dot(texture(denim, uv).rgb, vec3(0.333)) * 1.5 + 0.35;
	vec3 skin_col = skin;
	if (use_body) {
		// The texture is a light skin; scale it to this person's tone.
		vec3 tex = texture(body_albedo, UV).rgb;
		skin_col = mix(tex, tex * (skin / vec3(0.84, 0.66, 0.55)), 0.65);
	}
	vec3 top = shirt * js;
	vec3 legs = pants * dn;
	if (outfit == 1 || outfit == 4) {
		legs = pants * js;  // one fabric top to bottom
	}
	if (outfit == 2 || outfit == 3) {
		top = leopard(local) * js;
		if (outfit == 2) {
			legs = leopard(local) * js;
		}
	}
	if (outfit == 1) {
		// Zip jacket: a zip down the front and darker ribbed cuffs and hem.
		float zip = smoothstep(0.55, 0.7, nl.z) * (1.0 - step(0.008, abs(local.x))) * step(0.95, local.y) * (1.0 - step(1.45, local.y));
		top = mix(top, vec3(0.75), zip);
	}
	if (stripes) {
		// Four crisp bands across the side panel (was a moire of thin lines).
		float panel_s = clamp((abs(nl.x) - 0.8) / 0.2, 0.0, 1.0);
		float side = step(0.8, abs(nl.x));
		float lines = step(0.45, fract(panel_s * 3.999));
		top = mix(top, vec3(0.95), side * lines * step(0.18, abs(local.x)));
		legs = mix(legs, vec3(0.95), side * lines);
	}
	if (outfit == 4 && cover_head) {
		// Red cross-stitch: a square chest panel and two bands down the skirt,
		// the way the Negev Bedouin thob is worked (never a crossing shape).
		float front = step(0.02, rest.z);
		vec2 st = fract(rest.xy * vec2(160.0, 160.0));
		float stitch = clamp(step(abs(st.x - st.y), 0.2) + step(abs(st.x + st.y - 1.0), 0.2), 0.0, 1.0);
		float chest = front * step(1.3, rest.y) * (1.0 - step(1.43, rest.y)) * (1.0 - step(0.06, abs(rest.x)));
		float frame = chest * (1.0 - step(1.315, rest.y) * (1.0 - step(1.415, rest.y)) * (1.0 - step(0.048, abs(rest.x))));
		top = mix(top, vec3(0.55, 0.06, 0.08) * js, chest * 0.35);
		top = mix(top, vec3(0.75, 0.09, 0.1) * js, chest * max(stitch * 0.9, frame));
	}
	ALBEDO = top * mask.r + legs * mask.g + skin_col * mask.b + vec3(0.16, 0.13, 0.11) * shoes;  // leather-brown shoes, not dark bare toes
	vec3 n = mix(vec3(0.5, 0.5, 1.0), texture(jersey_nor, uv).rgb, mask.r);
	n = mix(n, texture(denim_nor, uv).rgb, mask.g);
	if (use_body) {
		n = mix(n, texture(body_normal, UV).rgb, mask.b);
	}
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = 0.86 * mask.r + 0.92 * mask.g + (use_body ? 0.68 : 0.5) * mask.b + 0.35 * shoes;
	SPECULAR = mix(0.35, 0.5, mask.b);
	SSS_STRENGTH = mask.b * 0.35;
}
"""

static var _scene: PackedScene
static var _scene_checked := false
static var _tagged_mesh: ArrayMesh
## Real bodies with faces (Quaternius Universal Base Characters, CC0), bound to
## the mannequin's skeleton, which has the same bones. Missing files = mannequin.
const BODIES := {
	"male": ["res://assets/characters/ubc/Superhero_Male_FullBody.gltf", "res://assets/characters/ubc/T_Superhero_Male_Ligh.png", "res://assets/characters/ubc/T_Superhero_Male_Normal.png"],
	"female": ["res://assets/characters/ubc/Superhero_Female_FullBody.gltf", "res://assets/characters/ubc/T_Superhero_Female_Light_BaseColor.png", "res://assets/characters/ubc/T_Superhero_Female_Normal.png"],
}
const HAIR_DIR := "res://assets/characters/ubc/"
static var _bodies := {}        # sex -> PackedScene, or null when missing
static var _tagged_bodies := {} # sex -> ArrayMesh
var _real_body := false
static var _shader: Shader

## Clip played while standing still.
var idle_clip := "Idle_Loop"

var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _model: Node3D
var _current := ""
var _busy_t := 0.0
var _down := false


static func available() -> bool:
	if not _scene_checked:
		_scene_checked = true
		if ResourceLoader.exists(MODEL):
			_scene = load(MODEL) as PackedScene
	return _scene != null


## look: {shirt, pants, skin, hair: Color, prop: String} and optionally
## {height, girth: float (1 = average), long_hair: bool}
static func create(look: Dictionary) -> RiggedBody:
	var body := RiggedBody.new()
	body._build(look)
	return body


func _build(look: Dictionary) -> void:
	_model = _scene.instantiate() as Node3D
	# Women stand on the female body's own skeleton (narrower shoulders, her
	# own proportions); the mannequin's animation player moves over to it.
	var own_frame := false
	if look.get("long_hair", false) and _body_scene("female") != null:
		var female := _body_scene("female").instantiate() as Node3D
		var anims := _model.find_children("*", "AnimationPlayer", true, false)
		if not anims.is_empty() and female.find_child("Skeleton3D", true, false) != null:
			var player := anims[0] as AnimationPlayer
			player.get_parent().remove_child(player)
			player.owner = null
			_model.free()
			_model = female
			_model.add_child(player)
			player.root_node = NodePath("..")
			own_frame = true
		else:
			female.free()
	var tall: float = look.get("height", 1.0)
	var wide: float = look.get("girth", 1.0)
	_model.scale = Vector3(wide, tall, wide) * SCALE
	add_child(_model)
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if skeletons.is_empty() or players.is_empty():
		return
	_skeleton = skeletons[0] as Skeleton3D
	_player = players[0] as AnimationPlayer
	for clip: String in LOOPS:
		var found := _clip(clip)
		if found != "":
			_player.get_animation(found).loop_mode = Animation.LOOP_LINEAR

	var material := ShaderMaterial.new()
	material.shader = _clothes_shader()
	var shirt: Color = look.get("shirt", Color.WHITE)
	if String(look.get("prop", "")) == "vest":
		shirt = Color(0.96, 0.82, 0.2)  # hi-vis yellow
	# A shirt close to the skin tone reads as a bare torso (the mannequin look):
	# push it darker and a little bluer until it separates (PC tuning).
	var skin_c: Color = look.get("skin", Color(0.8, 0.6, 0.45))
	var tries := 0
	var outfit := String(look.get("outfit", ""))
	while outfit == "" and tries < 4 and Vector3(shirt.r - skin_c.r, shirt.g - skin_c.g, shirt.b - skin_c.b).length() < 0.28:
		shirt = shirt.darkened(0.3).lerp(Color(0.2, 0.3, 0.45), 0.25)
		tries += 1
	material.set_shader_parameter("shirt", shirt)
	material.set_shader_parameter("pants", look.get("pants", Color(0.2, 0.3, 0.5)))
	material.set_shader_parameter("skin", look.get("skin", Color(0.8, 0.6, 0.45)))
	material.set_shader_parameter("outfit", {"tracksuit": 1, "leopard": 2, "leopard_top": 3, "robe": 4}.get(outfit, 0))
	material.set_shader_parameter("stripes", bool(look.get("stripes", false)))
	material.set_shader_parameter("cover_head", outfit == "robe" and look.get("long_hair", false))
	for tex_name in ["jersey", "jersey_nor", "denim", "denim_nor"]:
		var file: String = tex_name.replace("_nor", "") + ("_nor" if tex_name.ends_with("_nor") else "_diff")
		var tex := CityMaterials._tex(file)
		if tex:
			material.set_shader_parameter(tex_name, tex)
	if own_frame:
		_dress_own_body("female", look, material)
	else:
		for node in _model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.skin == null:
				continue
			mi.mesh = _tag_mesh(mi.mesh)
			mi.material_override = material
		_swap_in_real_body(look, material)
	# Half the men in Beer Sheva are in shorts from April to November.
	if _real_body and outfit == "" and not look.get("long_hair", false) and randf() < 0.4:
		for node in _model.find_children("*", "MeshInstance3D", true, false):
			var m := (node as MeshInstance3D).material_override
			if m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter("hem", 0.55)

	# A natural build on the athletic base model, relaxed hands (PC).
	var shape := BodyShape.new()
	_shape = shape
	shape.slim = 0.45 if look.get("long_hair", false) else 0.65
	shape.belly = float(look.get("belly", 0.0))
	shape.stoop = 0.2 if look.get("old", false) else 0.0
	shape.pose = int(look.get("pose", 0))
	_skeleton.add_child(shape)
	if shape.pose == 4:
		# The phone, flat in the right palm (palms face down in the rest pose).
		var hr := _skeleton.get_bone_global_rest(_skeleton.find_bone("hand_r")).origin
		var phone := _slab(Vector3(0.07, 0.009, 0.145), Color(0.04, 0.04, 0.05))
		(phone.material_override as StandardMaterial3D).roughness = 0.2
		_pin("hand_r", phone, hr + Vector3(-0.075, -0.035, 0.0), Vector3.ONE)
	_dress(look)
	_play(idle_clip)


# --- real body ---------------------------------------------------------------------------

static func _body_scene(sex: String) -> PackedScene:
	if not _bodies.has(sex):
		var path: String = BODIES[sex][0]
		_bodies[sex] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	return _bodies[sex]


## Puts a real body (with a face, eyes and hands) on the mannequin's skeleton
## and hides the dummy. The clothes shader still paints shirt and trousers.
func _swap_in_real_body(look: Dictionary, material: ShaderMaterial) -> void:
	var sex := "female" if look.get("long_hair", false) else "male"
	var scene := _body_scene(sex)
	if scene == null:
		return
	var body := scene.instantiate()
	var parts := body.find_children("*", "MeshInstance3D", true, false)
	if parts.is_empty():
		body.free()
		return
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).skin != null:
			(node as MeshInstance3D).visible = false
	var albedo := load(BODIES[sex][1]) as Texture2D if ResourceLoader.exists(BODIES[sex][1]) else null
	var normal := load(BODIES[sex][2]) as Texture2D if ResourceLoader.exists(BODIES[sex][2]) else null
	var own := material.duplicate() as ShaderMaterial
	own.set_shader_parameter("use_body", albedo != null)
	if albedo:
		own.set_shader_parameter("body_albedo", albedo)
	if normal:
		own.set_shader_parameter("body_normal", normal)
	for node in parts:
		var mi := node as MeshInstance3D
		var keep_skin := mi.skin
		mi.get_parent().remove_child(mi)
		mi.owner = null
		_skeleton.add_child(mi)
		mi.transform = Transform3D.IDENTITY
		mi.skin = keep_skin
		mi.skeleton = NodePath("..")
		if String(mi.name).begins_with("SuperHero") or mi.mesh.get_aabb().size.y > 1.0:
			if not _tagged_bodies.has(sex):
				_tagged_bodies[sex] = _tag_any(mi.mesh)
			mi.mesh = _tagged_bodies[sex]
			mi.material_override = own
			_add_garments(mi, sex, own, look)
		elif String(mi.name) == "Eyebrows":
			# Keep the alpha-cut brow texture; just tint it to the hair.
			var src := mi.get_active_material(0)
			if src is StandardMaterial3D:
				var brow := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				brow.albedo_color = (look.get("hair", Color(0.1, 0.07, 0.03)) as Color).lightened(0.1)
				mi.material_override = brow
	body.free()
	_real_body = true


## The body already stands on its own skeleton: tag and paint it in place.
func _dress_own_body(sex: String, look: Dictionary, material: ShaderMaterial) -> void:
	var albedo := load(BODIES[sex][1]) as Texture2D if ResourceLoader.exists(BODIES[sex][1]) else null
	var normal := load(BODIES[sex][2]) as Texture2D if ResourceLoader.exists(BODIES[sex][2]) else null
	var own := material.duplicate() as ShaderMaterial
	own.set_shader_parameter("use_body", albedo != null)
	if albedo:
		own.set_shader_parameter("body_albedo", albedo)
	if normal:
		own.set_shader_parameter("body_normal", normal)
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh.get_aabb().size.y > 1.0:
			if not _tagged_bodies.has(sex):
				_tagged_bodies[sex] = _tag_any(mi.mesh)
			mi.mesh = _tagged_bodies[sex]
			mi.material_override = own
			_add_garments(mi, sex, own, look)
		elif String(mi.name) == "Eyebrows":
			var src := mi.get_active_material(0)
			if src is StandardMaterial3D:
				var brow := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				brow.albedo_color = (look.get("hair", Color(0.1, 0.07, 0.03)) as Color).lightened(0.1)
				mi.material_override = brow
	_real_body = true


## Region tags for any T-pose body mesh (same rule as the mannequin's).
static func _tag_any(source: Mesh) -> ArrayMesh:
	var tagged := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		colors.resize(verts.size())
		for i in verts.size():
			colors[i] = _region(verts[i])
		arrays[Mesh.ARRAY_COLOR] = colors
		# glTF custom channels need their own format flags; the shader does not use them.
		for k in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arrays[k] = null
		# CUSTOM0 carries the rest (T-pose) position, so the shaders can draw the
		# boundaries between garments as straight loops on the body, whatever the pose.
		var rest := PackedFloat32Array()
		rest.resize(verts.size() * 4)
		for i in verts.size():
			rest[i * 4] = verts[i].x
			rest[i * 4 + 1] = verts[i].y
			rest[i * 4 + 2] = verts[i].z
		arrays[Mesh.ARRAY_CUSTOM0] = rest
		tagged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, _flags(arrays))
	return tagged


## A real hairstyle (origin at the model's origin), tinted to the hair colour.
func _real_hair(file: String, hair: Color) -> void:
	var path := HAIR_DIR + file
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	var root := scene.instantiate()
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		root.free()
		return
	var mi := meshes[0] as MeshInstance3D
	mi.get_parent().remove_child(mi)
	mi.owner = null
	root.free()
	var mat := mi.get_active_material(0)
	if mat is StandardMaterial3D:
		var tinted := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		tinted.albedo_color = hair.lightened(0.15)
		mi.material_override = tinted
	_pin("Head", mi, Vector3.ZERO)


# --- garments with volume -----------------------------------------------------------------

## Clothes as a layer of their own: the body's clothed triangles, lifted off the
## skin with the same bone weights, so the layer moves with the body. The lift
## is relaxed as a membrane (smooth, never closer to the skin than the lift),
## so cloth bridges the grooves between muscles instead of following them, and
## the open edges (neck, cuffs, ankles) are snapped onto straight loops. One
## layer per body and cut, built once, cached on disk and shared. Long dresses
## and robes also get a skirt that hangs from the hips over the legs; feet get
## a shoe layer the same way.
const LAYER_VERSION := 9
static var _shells := {}   # "sex|cut" -> ArrayMesh
static var _stripped := {} # "sex|cut" -> body mesh without the triangles the layer hides


## Which body vertices a layer covers. c: region tag, p: rest position, n: rest normal.
static func _covers(cut: String, c: Color, p: Vector3, n: Vector3) -> bool:
	var hand := c.a < 0.3
	var is_head := c.a > 0.4 and c.a < 0.6
	var shoe := c.r + c.g + c.b < 0.5
	match cut:
		"shoes":
			return shoe
		"robe":
			return not hand and not is_head and not shoe
		"robe_head":
			if hand or shoe:
				return false
			if is_head:
				return not _face(p, n)
			return true
	return c.r > 0.5 or c.g > 0.5


## The open oval of the face inside a head scarf: forehead to chin, cheek to cheek.
static func _face(p: Vector3, n: Vector3) -> bool:
	return n.z > 0.2 and p.z > 0.0 and p.y > 1.528 and p.y < 1.712 and absf(p.x) < 0.07


## How far off the skin the cloth sits at rest position p (normal n).
static func _lift(cut: String, p: Vector3, n: Vector3, c: Color) -> float:
	var side := absf(p.x)
	match cut:
		"fitted":
			return 0.015
		"loose":
			return 0.03 + (0.015 if side < 0.3 and p.y > 0.95 and p.y < 1.25 else 0.0)
		"shoes":
			return 0.015
	# Robes: loose; below the chest the skirt cone takes over.
	var lift := 0.028
	if cut == "robe_head" and c.a > 0.4 and c.a < 0.6:
		# The scarf: snug round the face, fuller over the crown and the back of the head.
		lift = 0.016 + 0.035 * maxf(0.0, -n.z) + 0.02 * maxf(0.0, n.y)
	return lift


## Straight edges: the open-edge vertices of a layer are put back on the loop
## the region rule draws (neck, sleeve, wrist, ankle), so hems and cuffs are lines.
static func _snap(cut: String, p: Vector3) -> Vector3:
	var side := absf(p.x)
	var s := signf(p.x)
	if absf(p.y - 0.14) < 0.08:
		return Vector3(p.x, 0.14, p.z)
	if cut != "robe_head" and side < 0.17 and p.y > 1.4 and p.y < 1.58:
		return Vector3(p.x, _neckline(side), p.z)
	if cut.begins_with("robe"):
		if absf(side - 0.68) < 0.06 and p.y > 1.2:
			return Vector3(s * 0.68, p.y, p.z)
	elif absf(side - 0.5) < 0.06 and p.y > 1.2:
		return Vector3(s * 0.5, p.y, p.z)
	return p


static func _layer(src: ArrayMesh, sex: String, cut: String) -> ArrayMesh:
	var key := sex + "|" + cut
	if _shells.has(key):
		return _shells[key]
	var path := "user://layers/%s_%s_v%d.res" % [sex, cut, LAYER_VERSION]
	var mesh: ArrayMesh = null
	if ResourceLoader.exists(path):
		mesh = ResourceLoader.load(path) as ArrayMesh
	if mesh == null:
		mesh = _build_layer(src, cut)
		DirAccess.make_dir_recursive_absolute("user://layers")
		ResourceSaver.save(mesh, path)
	_shells[key] = mesh
	return mesh


static func _build_layer(src: ArrayMesh, cut: String) -> ArrayMesh:
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var count := verts.size()
	# Weld vertices that share a position (UV seams split them) into groups.
	var group := PackedInt32Array()
	group.resize(count)
	var by_pos := {}
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var tag := PackedColorArray()
	for i in count:
		var k := Vector3i(roundi(verts[i].x * 2000.0), roundi(verts[i].y * 2000.0), roundi(verts[i].z * 2000.0))
		if not by_pos.has(k):
			by_pos[k] = pos.size()
			pos.append(verts[i])
			nrm.append(Vector3.ZERO)
			tag.append(colors[i])
		group[i] = by_pos[k]
		nrm[group[i]] += normals[i]
	var groups := pos.size()
	for g in groups:
		nrm[g] = nrm[g].normalized()
	var keep := PackedByteArray()
	keep.resize(groups)
	for i in count:
		if _covers(cut, colors[i], verts[i], nrm[group[i]]):
			keep[group[i]] = 1
	# Only whole triangles of the layer are drawn; an edge used by one of them only is open.
	var kept := PackedInt32Array()
	var edge_use := {}
	for t in range(0, indices.size(), 3):
		var a := group[indices[t]]
		var b := group[indices[t + 1]]
		var c := group[indices[t + 2]]
		if keep[a] == 1 and keep[b] == 1 and keep[c] == 1:
			kept.append(indices[t])
			kept.append(indices[t + 1])
			kept.append(indices[t + 2])
			for e in [Vector2i(mini(a, b), maxi(a, b)), Vector2i(mini(b, c), maxi(b, c)), Vector2i(mini(c, a), maxi(c, a))]:
				edge_use[e] = int(edge_use.get(e, 0)) + 1
	var open := PackedByteArray()
	open.resize(groups)
	for e: Vector2i in edge_use:
		if edge_use[e] == 1:
			open[e.x] = 1
			open[e.y] = 1
	# Neighbours over the drawn triangles only.
	var neighbours: Array[PackedInt32Array] = []
	neighbours.resize(groups)
	for g in groups:
		neighbours[g] = PackedInt32Array()
	for e: Vector2i in edge_use:
		neighbours[e.x].append(e.y)
		neighbours[e.y].append(e.x)
	var active := PackedInt32Array()
	var lift := PackedFloat32Array()
	lift.resize(groups)
	for g in groups:
		if keep[g] == 1 and not neighbours[g].is_empty():
			active.append(g)
			lift[g] = _lift(cut, pos[g], nrm[g], tag[g])
	# The membrane: smooth, then push back out wherever it went closer to the
	# skin than the lift. Grooves get bridged, bumps are only skimmed.
	var cur := pos.duplicate()
	# Open edges are anchored close to the skin (on their straight loop): a
	# membrane with a free edge creeps back from it and the hole grows.
	for g in active:
		if open[g] == 1:
			lift[g] = 0.006
		cur[g] = pos[g] + nrm[g] * lift[g]
		if open[g] == 1:
			cur[g] = _snap(cut, cur[g])
	var rounds: int = {"fitted": 40, "loose": 34, "robe": 44, "robe_head": 44, "shoes": 40}[cut]
	var max_slide := 0.03 if cut == "shoes" else 0.015
	for it in rounds:
		var nxt := cur.duplicate()
		for g in active:
			if open[g] == 1:
				continue
			var ns := neighbours[g]
			var avg := Vector3.ZERO
			for n in ns:
				avg += cur[n]
			var p := cur[g].lerp(avg / ns.size(), 0.6)
			# Out along the normal as far as the smoothing wants (never under the
			# lift), but hardly any sliding along the skin.
			var d := p - pos[g]
			var out := d.dot(nrm[g])
			var slide := d - nrm[g] * out
			if slide.length() > max_slide:
				slide = slide.normalized() * max_slide
			nxt[g] = pos[g] + slide + nrm[g] * maxf(out, lift[g])
		cur = nxt
	# Normals from the cloth's own shape, so the light no longer finds the abs.
	var face_n := PackedVector3Array()
	face_n.resize(groups)
	for t in range(0, kept.size(), 3):
		var ga := group[kept[t]]
		var gb := group[kept[t + 1]]
		var gc := group[kept[t + 2]]
		var fn := (cur[gb] - cur[ga]).cross(cur[gc] - cur[ga])
		face_n[ga] += fn
		face_n[gb] += fn
		face_n[gc] += fn
	var out_v := PackedVector3Array()
	out_v.resize(count)
	var out_n := PackedVector3Array()
	out_n.resize(count)
	for i in count:
		var g := group[i]
		out_v[i] = cur[g]
		var fnn := face_n[g].normalized() if face_n[g].length_squared() > 1e-14 else nrm[g]
		out_n[i] = fnn if fnn.dot(nrm[g]) > 0.0 else -fnn
	arrays[Mesh.ARRAY_VERTEX] = out_v
	arrays[Mesh.ARRAY_NORMAL] = out_n
	arrays[Mesh.ARRAY_TANGENT] = null
	arrays[Mesh.ARRAY_INDEX] = kept
	return _mesh_from(arrays)


static func _mesh_from(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, _flags(arrays))
	return mesh


static func _flags(arrays: Array) -> int:
	var flags := 0
	var bones = arrays[Mesh.ARRAY_BONES]
	if bones != null and bones.size() == (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 8:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	if arrays[Mesh.ARRAY_CUSTOM0] != null:
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	return flags


## The body without the triangles a layer hides completely (cheaper than
## discarding them in the shader, which broke the depth prepass: ~8 fps).
static func _strip(src: ArrayMesh, sex: String, cut: String) -> ArrayMesh:
	var key := sex + "|" + cut
	if _stripped.has(key):
		return _stripped[key]
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var kept := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		var hidden := 0
		for k in 3:
			var i := indices[t + k]
			if _covers(cut, colors[i], verts[i], normals[i]):
				hidden += 1
		if hidden < 3:
			kept.append(indices[t])
			kept.append(indices[t + 1])
			kept.append(indices[t + 2])
	arrays[Mesh.ARRAY_INDEX] = kept
	_stripped[key] = _mesh_from(arrays)
	return _stripped[key]


func _add_garments(body: MeshInstance3D, sex: String, material: ShaderMaterial, look: Dictionary) -> void:
	var outfit := String(look.get("outfit", ""))
	var cut := "robe_head" if outfit == "robe" and look.get("long_hair", false) else ("robe" if outfit == "robe" else ("loose" if outfit.begins_with("tracksuit") else "fitted"))
	var source := body.mesh as ArrayMesh
	var shell := _layer_instance(body, _layer(source, sex, cut))
	shell.name = "Garment"
	var cloth := material.duplicate() as ShaderMaterial  # its own copy: the body's paints skin
	cloth.set_shader_parameter("is_layer", true)
	shell.material_override = cloth
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # the body already casts one
	body.mesh = _strip(source, sex, cut)
	if cut.begins_with("robe"):
		_add_skirt(look)
	_add_shoes(body, source, sex, look, material)


func _layer_instance(body: MeshInstance3D, mesh: ArrayMesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.skin = body.skin
	body.get_parent().add_child(mi)
	mi.transform = body.transform
	mi.skeleton = mi.get_path_to(_skeleton)
	return mi


## Shoes: a small rigid mesh per foot, pinned to foot_l / foot_r and shaped
## from that body's own foot (slices from heel to toe, a rounded section with a
## sole), so the modelled toes disappear inside. Sneakers and leather shoes
## hide the foot beneath; sandals and flip-flops are a sole and straps over
## the bare foot.
const SHOE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 upper : source_color = vec3(0.9);
uniform vec3 sole : source_color = vec3(0.95);
uniform float sole_h = 0.02;
uniform float gloss = 0.0;
varying vec3 at;
void vertex() {
	at = VERTEX;
}
void fragment() {
	bool is_sole = at.y < sole_h || COLOR.r < 0.5;
	ALBEDO = is_sole ? sole : upper;
	ROUGHNESS = is_sole ? 0.9 : mix(0.72, 0.3, gloss);
	SPECULAR = mix(0.35, 0.6, gloss);
}
"""
static var _shoe_shader: Shader
static var _shoe_meshes := {}  # "sex|side|style" -> ArrayMesh
const SHOE_COLOURS := [Color(0.92, 0.92, 0.9), Color(0.1, 0.1, 0.11), Color(0.5, 0.52, 0.55), Color(0.2, 0.27, 0.45), Color(0.7, 0.18, 0.15), Color(0.93, 0.93, 0.92)]


func _add_shoes(body: MeshInstance3D, source: ArrayMesh, sex: String, look: Dictionary, body_material: ShaderMaterial) -> void:
	var style := String(look.get("shoes", "sneaker"))
	if String(look.get("outfit", "")) == "robe":
		style = "leather" if sex == "female" else "sandal"
	if _shoe_shader == null:
		_shoe_shader = Shader.new()
		_shoe_shader.code = SHOE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shoe_shader
	var colour: Color = look.get("shoe_colour", SHOE_COLOURS[randi() % SHOE_COLOURS.size()])
	match style:
		"sneaker":
			mat.set_shader_parameter("upper", colour)
			mat.set_shader_parameter("sole", Color(0.93, 0.92, 0.88) if colour.v < 0.8 else Color(0.25, 0.25, 0.27))
			mat.set_shader_parameter("sole_h", 0.016)
		"leather":
			mat.set_shader_parameter("upper", Color(0.07, 0.05, 0.04) if randf() < 0.6 else Color(0.26, 0.15, 0.07))
			mat.set_shader_parameter("sole", Color(0.04, 0.035, 0.03))
			mat.set_shader_parameter("sole_h", 0.008)
			mat.set_shader_parameter("gloss", 1.0)
		"sandal":
			mat.set_shader_parameter("upper", Color(0.32, 0.19, 0.09))
			mat.set_shader_parameter("sole", Color(0.22, 0.15, 0.09))
		_:
			mat.set_shader_parameter("upper", colour)
			mat.set_shader_parameter("sole", colour.darkened(0.3))
	var skin := body.skin
	for side in ["l", "r"]:
		var key := "%s|%s|%s" % [sex, side, style]
		if not _shoe_meshes.has(key):
			_shoe_meshes[key] = _shoe_mesh(source, 1.0 if side == "l" else -1.0, style)
		var mi := MeshInstance3D.new()
		mi.name = "Shoe"
		mi.mesh = _shoe_meshes[key]
		mi.material_override = mat
		var holder := BoneAttachment3D.new()
		holder.bone_name = "foot_" + side
		_skeleton.add_child(holder)
		holder.add_child(mi)
		# The mesh is in the body mesh's rest space: the skin's bind pose of the
		# foot bone takes it into the bone's own frame, on any skeleton.
		mi.transform = body.transform * _bind_pose(skin, "foot_" + side)
	var open := style == "sandal" or style == "flipflop"
	body_material.set_shader_parameter("bare_feet", open)
	if not open:
		# Closed shoes: drop the foot under them, so toes cannot poke through at toe-off.
		body.mesh = _strip_feet(body.mesh as ArrayMesh, sex + "|" + String(look.get("outfit", "")))


func _bind_pose(skin: Skin, bone: String) -> Transform3D:
	if skin != null:
		var index := _skeleton.find_bone(bone)
		for i in skin.get_bind_count():
			if String(skin.get_bind_name(i)) == bone or (skin.get_bind_name(i) == StringName() and skin.get_bind_bone(i) == index):
				return skin.get_bind_pose(i)
	return _skeleton.get_bone_global_rest(_skeleton.find_bone(bone)).affine_inverse()


static var _no_feet := {}


static func _strip_feet(src: ArrayMesh, key: String) -> ArrayMesh:
	if _no_feet.has(key):
		return _no_feet[key]
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var kept := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		if verts[indices[t]].y < 0.085 and verts[indices[t + 1]].y < 0.085 and verts[indices[t + 2]].y < 0.085:
			continue
		kept.append(indices[t])
		kept.append(indices[t + 1])
		kept.append(indices[t + 2])
	arrays[Mesh.ARRAY_INDEX] = kept
	_no_feet[key] = _mesh_from(arrays)
	return _no_feet[key]


## A shoe for the foot on side s (+1 left, -1 right) of a rest-pose body mesh,
## in that mesh's coordinates.
static func _shoe_mesh(src: ArrayMesh, s: float, style: String) -> ArrayMesh:
	var verts: PackedVector3Array = src.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var foot: Array[Vector3] = []
	var z0 := 9.0
	var z1 := -9.0
	for v in verts:
		if v.y < 0.11 and v.x * s > 0.02:
			foot.append(v)
			z0 = minf(z0, v.z)
			z1 = maxf(z1, v.z)
	const SLICES := 14
	var open := style == "sandal" or style == "flipflop"
	var margin := 0.006 if open else 0.011
	var cap := 0.105 if style == "sneaker" else 0.085
	var cx := PackedFloat32Array()
	var hw := PackedFloat32Array()
	var top := PackedFloat32Array()
	var zs := PackedFloat32Array()
	var step := (z1 - z0) / float(SLICES - 1)
	for k in SLICES:
		var z := z0 + step * k
		var lo := 9.0
		var hi := -9.0
		var h := 0.0
		for v in foot:
			if absf(v.z - z) < step * 0.75:
				lo = minf(lo, v.x)
				hi = maxf(hi, v.x)
				h = maxf(h, v.y)
		if lo > hi:
			lo = (cx[k - 1] - hw[k - 1]) if k > 0 else 0.1 * s
			hi = (cx[k - 1] + hw[k - 1]) if k > 0 else 0.1 * s
		cx.append((lo + hi) * 0.5)
		hw.append((hi - lo) * 0.5 + margin)
		top.append(minf(h + margin, cap))
		zs.append(z)
	# Round the toe and the heel off in plan, and stretch the toe a little.
	zs[0] -= margin
	zs[SLICES - 1] += margin * 1.6
	for k in [0, SLICES - 1]:
		hw[k] *= 0.55
	hw[1] *= 0.9
	hw[SLICES - 2] *= 0.85
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	if open:
		# Sole: a flat pad 2 cm thick under the foot.
		_loft(st, cx, hw, zs, PackedFloat32Array(), 0.02, -0.004)
		var sm := 0.004
		if style == "sandal":
			# Two leather straps: across the forefoot and round the instep.
			for k in [int(SLICES * 0.68), int(SLICES * 0.4)]:
				_strap(st, Vector3(cx[k], top[k] - 0.006, zs[k]), hw[k] + sm, 0.028)
		else:
			# Flip-flop: a thong from between the big toe and the next, down to both sides.
			var toe := Vector3(cx[SLICES - 3] + s * hw[SLICES - 3] * 0.25, 0.02, zs[SLICES - 3])
			var k := int(SLICES * 0.55)
			for side_x in [cx[k] - hw[k], cx[k] + hw[k]]:
				var a := Vector3(side_x, 0.015, zs[k])
				var mid := Vector3((toe.x + side_x) * 0.5, top[k] + 0.002, (toe.z + zs[k]) * 0.5)
				_bar(st, toe, mid, 0.008)
				_bar(st, mid, a, 0.008)
	else:
		_loft(st, cx, hw, zs, top, 0.0, -0.005)
	st.generate_normals()
	return st.commit()


## Rings round each slice (rounded box section), joined and capped at both ends.
static func _loft(st: SurfaceTool, cx: PackedFloat32Array, hw: PackedFloat32Array, zs: PackedFloat32Array, top: PackedFloat32Array, flat: float, bottom: float) -> void:
	const RING := 16
	var rings: Array[PackedVector3Array] = []
	for k in zs.size():
		var h := flat if top.is_empty() else top[k]
		var ring := PackedVector3Array()
		for i in RING:
			var a := TAU * float(i) / RING
			var c := cos(a)
			var sn := sin(a)
			var x := cx[k] + hw[k] * signf(c) * pow(absf(c), 0.55)
			var y := lerpf(bottom, h, 0.5 + 0.5 * signf(sn) * pow(absf(sn), 0.5 if sn > 0.0 else 0.2))
			ring.append(Vector3(x, y, zs[k]))
		rings.append(ring)
	for k in zs.size() - 1:
		for i in RING:
			var j := (i + 1) % RING
			_quad(st, rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i])
	for end in [0, zs.size() - 1]:
		var centre := Vector3.ZERO
		for p in rings[end]:
			centre += p
		centre /= RING
		for i in RING:
			var j := (i + 1) % RING
			if end == 0:
				_tri(st, centre, rings[end][j], rings[end][i])
			else:
				_tri(st, centre, rings[end][i], rings[end][j])


static func _strap(st: SurfaceTool, at: Vector3, half: float, width: float) -> void:
	var prev := Vector3.ZERO
	for i in 9:
		var a := PI * float(i) / 8.0
		var p := at + Vector3(-cos(a) * half, sin(a) * 0.012 - (1.0 - sin(a)) * (at.y - 0.012), 0.0)
		if i > 0:
			_quad(st, prev + Vector3(0, 0, -width * 0.5), p + Vector3(0, 0, -width * 0.5), p + Vector3(0, 0, width * 0.5), prev + Vector3(0, 0, width * 0.5))
		prev = p


static func _bar(st: SurfaceTool, a: Vector3, b: Vector3, w: float) -> void:
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP).normalized() * w * 0.5
	var up := Vector3.UP * w * 0.35
	_quad(st, a - side + up, b - side + up, b + side + up, a + side + up)
	_quad(st, a + side + up, b + side + up, b + side - up, a + side - up)
	_quad(st, a - side - up, b - side - up, b - side + up, a - side + up)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## The hanging part of a dress or galabiya: a flared tube from the hips to the
## ankles, pinned to the pelvis so it turns and sways with the walk.
const SKIRT_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 cloth : source_color = vec3(0.9);
uniform bool embroidered = false;
uniform sampler2D jersey : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 local;
void vertex() {
	local = VERTEX;
}
void fragment() {
	float js = dot(texture(jersey, vec2(local.x + local.z * 0.7, local.y) * 7.0).rgb, vec3(0.333)) * 0.9 + 0.55;
	vec3 col = cloth * js;
	if (embroidered) {
		// Negev Bedouin thob: two panels of red cross-stitch down the front and a band at the hem.
		float u = abs(fract(UV.x + 0.5) - 0.5);
		float panel = step(0.035, u) * (1.0 - step(0.075, u));
		float hem = step(0.88, UV.y);
		vec2 st = fract(vec2(UV.x * 260.0, UV.y * 90.0));
		float stitch = step(abs(st.x - st.y), 0.18) + step(abs(st.x + st.y - 1.0), 0.18);
		col = mix(col, vec3(0.72, 0.08, 0.1) * js, max(panel, hem) * clamp(stitch, 0.0, 1.0) * 0.9);
		col = mix(col, vec3(0.55, 0.06, 0.08) * js, max(panel, hem) * 0.35);
	}
	ALBEDO = col;
	ROUGHNESS = 0.92;
	BACKLIGHT = vec3(0.0);
}
"""
static var _skirt_shader: Shader


func _add_skirt(look: Dictionary) -> void:
	if _skirt_shader == null:
		_skirt_shader = Shader.new()
		_skirt_shader.code = SKIRT_SHADER
	var cloth := ShaderMaterial.new()
	cloth.shader = _skirt_shader
	cloth.set_shader_parameter("cloth", look.get("shirt", Color(0.06, 0.06, 0.07)))
	cloth.set_shader_parameter("embroidered", look.get("long_hair", false))
	var tex := CityMaterials._tex("jersey_diff")
	if tex:
		cloth.set_shader_parameter("jersey", tex)
	var shape := CylinderMesh.new()
	shape.top_radius = 0.168
	shape.bottom_radius = 0.3
	shape.height = 1.1
	shape.radial_segments = 24
	shape.rings = 2
	shape.cap_top = false
	shape.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = shape
	mi.material_override = cloth
	# Slightly oval, as hips are: less deep than wide.
	_pin("pelvis", mi, Vector3(0, 0.64, -0.005), Vector3(1.0, 1.0, 0.82))


# --- clothes ---------------------------------------------------------------------------

static func _clothes_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	return _shader


## The collar: a rounded crew neck, lowest at the front of the neck.
static func _neckline(side: float) -> float:
	return 1.45 + 0.6 * maxf(0.0, side - 0.06)


## Which part of the outfit a rest-pose (T-pose) vertex belongs to, as a mask
## colour: red = shirt, green = trousers, blue = skin, black = shoes.
static func _region(v: Vector3) -> Color:
	var side := absf(v.x)
	if v.y < 0.14:
		return Color(0, 0, 0)  # shoes (was 0.12: some feet came out bare)
	if v.y < 0.92 and side < 0.32:
		return Color(0, 1, 0)
	if side < 0.15 and v.y > _neckline(side):
		return Color(0, 0, 1, 0.5)  # head and neck (alpha marks it for the robe); a crew neck
	if side > 0.68:
		return Color(0, 0, 1, 0.25)  # hands
	if side > 0.5:
		return Color(0, 0, 1)  # short sleeves: forearms
	return Color(1, 0, 0)


## Rebuilds the mannequin mesh once with the region mask in vertex colours.
static func _tag_mesh(source: Mesh) -> ArrayMesh:
	if _tagged_mesh != null:
		return _tagged_mesh
	var tagged := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		colors.resize(verts.size())
		for i in verts.size():
			colors[i] = _region(verts[i])
		arrays[Mesh.ARRAY_COLOR] = colors
		var flags := 0
		var bones = arrays[Mesh.ARRAY_BONES]
		if bones != null and bones.size() == verts.size() * 8:
			flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		tagged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	_tagged_mesh = tagged
	return tagged


## Hair, sunglasses and the gang-specific extras, pinned to bones.
func _dress(look: Dictionary) -> void:
	var hair: Color = look.get("hair", Color(0.1, 0.07, 0.03))
	var prop := String(look.get("prop", ""))
	if _real_body:
		# The real body has its own face: only hair (and the odd beard) goes on.
		if prop == "keffiyeh":
			_pin("Head", _ball(0.125, Color(0.95, 0.95, 0.95)), Vector3(0, 1.74, -0.02), Vector3(1.05, 0.9, 1.1))
			_pin("Head", _slab(Vector3(0.26, 0.03, 0.26), Color(0.05, 0.05, 0.05)), Vector3(0, 1.8, -0.01))
		elif look.get("long_hair", false) and String(look.get("outfit", "")) == "robe":
			pass  # the black head covering hides the hair
		elif look.get("long_hair", false):
			_real_hair("Hair_Long.gltf", hair)
			if randf() < 0.35:
				# A ponytail (or a bun, higher and rounder).
				if randf() < 0.5:
					_pin("Head", _ball(0.055, hair), Vector3(0, 1.64, -0.14), Vector3(0.8, 1.9, 0.8))
				else:
					_pin("Head", _ball(0.06, hair), Vector3(0, 1.76, -0.1))
		else:
			var hat := String(look.get("hat", ""))
			if hat != "bald":
				_real_hair("Hair_SimpleParted.gltf" if randf() < 0.55 else "Hair_Buzzed.gltf", hair)
			if hat == "kippa":
				_pin("Head", _ball(0.075, Color(0.1, 0.12, 0.2) if randf() < 0.6 else Color(0.85, 0.85, 0.85)), Vector3(0, 1.8, -0.035), Vector3(1.0, 0.2, 1.0))
			elif hat == "cap":
				var cap_col: Color = [Color(0.1, 0.1, 0.12), Color(0.85, 0.85, 0.85), Color(0.7, 0.15, 0.12), Color(0.15, 0.25, 0.5)][randi() % 4]
				_pin("Head", _ball(0.112, cap_col), Vector3(0, 1.765, -0.01), Vector3(1.0, 0.62, 1.05))
				_pin("Head", _slab(Vector3(0.17, 0.012, 0.11), cap_col), Vector3(0, 1.74, 0.11))
			if randf() < 0.3:
				_real_hair("Hair_Beard.gltf", hair)
		if randf() < 0.3:
			# Sunglasses over the eyes (men stand on the mannequin's frame, whose
			# head sits 3 cm lower and 2 cm further forward than the body file's).
			# Two lenses and a bridge, not one bar.
			var woman: bool = look.get("long_hair", false)
			var eyes := Vector3(0, 1.656, 0.087) if woman else Vector3(0, 1.668, 0.103)
			for lens_x in [-0.031, 0.031]:
				_pin("Head", _slab(Vector3(0.05, 0.03, 0.008), Color(0.02, 0.02, 0.025)), eyes + Vector3(lens_x, 0, 0))
			_pin("Head", _slab(Vector3(0.13, 0.005, 0.01), Color(0.05, 0.05, 0.05)), eyes + Vector3(0, 0.012, -0.002))
		_dress_props(prop)
		return
	if prop == "keffiyeh":
		_pin("Head", _ball(0.125, Color(0.95, 0.95, 0.95)), Vector3(0, 1.72, -0.01), Vector3(1.05, 1.0, 1.1))
		_pin("Head", _slab(Vector3(0.27, 0.03, 0.27), Color(0.05, 0.05, 0.05)), Vector3(0, 1.79, 0))
	else:
		_pin("Head", _ball(0.112, hair), Vector3(0, 1.745, -0.025), Vector3(1.0, 0.85, 1.05))
		if look.get("long_hair", false):
			# Down the back of the neck to the shoulders.
			_pin("Head", _ball(0.1, hair), Vector3(0, 1.62, -0.085), Vector3(0.95, 1.4, 0.55))
	# A face, so people stop reading as mannequins (PC tuning): nose, mouth,
	# ears, a moustache on some men, and eyes and brows on whoever is not
	# hiding behind sunglasses.
	var skin: Color = look.get("skin", Color(0.8, 0.6, 0.45))
	_pin("Head", _ball(0.022, skin.darkened(0.05)), Vector3(0, 1.672, 0.112), Vector3(0.8, 1.25, 1.3))
	_pin("Head", _slab(Vector3(0.05, 0.009, 0.012), skin.darkened(0.45)), Vector3(0, 1.627, 0.106))
	for side in [-1.0, 1.0]:
		_pin("Head", _ball(0.026, skin), Vector3(side * 0.118, 1.69, -0.005), Vector3(0.45, 1.0, 0.8))
	if not look.get("long_hair", false) and randf() < 0.4:
		_pin("Head", _slab(Vector3(0.062, 0.016, 0.014), hair), Vector3(0, 1.645, 0.108))
	if randf() < 0.6:
		# Nobody walks around Beer Sheva at noon without sunglasses. Almost nobody.
		_pin("Head", _slab(Vector3(0.17, 0.04, 0.03), Color(0.03, 0.03, 0.04)), Vector3(0, 1.705, 0.1))
	else:
		for side in [-1.0, 1.0]:
			_pin("Head", _ball(0.012, Color(0.05, 0.04, 0.03)), Vector3(side * 0.036, 1.703, 0.104))
			_pin("Head", _slab(Vector3(0.038, 0.009, 0.012), hair.darkened(0.2)), Vector3(side * 0.037, 1.726, 0.106))
	_dress_props(prop)


## Gang and job extras: chain, logo, backpack, kitbag, vest band.
func _dress_props(prop: String) -> void:
	match prop:
		"tracksuit4":
			_pin("spine_03", _slab(Vector3(0.14, 0.02, 0.02), Color(0.85, 0.7, 0.2)), Vector3(0, 1.42, 0.13))  # gold chain
		"logo":
			_pin("spine_03", _slab(Vector3(0.2, 0.16, 0.02), Color(1, 1, 1)), Vector3(0, 1.3, 0.135))
		"backpack":
			_pin("spine_03", _slab(Vector3(0.3, 0.4, 0.16), Color(0.2, 0.25, 0.3)), Vector3(0, 1.28, -0.2))
		"kitbag":
			_pin("spine_03", _slab(Vector3(0.28, 0.75, 0.28), Color(0.29, 0.33, 0.13)), Vector3(0, 1.2, -0.26))
		"vest":
			# The hi-vis vest itself is the shirt colour (see _build); this is its reflective band.
			_pin("spine_03", _slab(Vector3(0.36, 0.05, 0.25), Color(0.85, 0.85, 0.8)), Vector3(0, 1.22, 0.0))


func _ball(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 14
	sphere.rings = 7
	mi.mesh = sphere
	mi.material_override = CityMaterials.color(color, 0.8)
	return mi


func _slab(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = CityMaterials.color(color, 0.6)
	return mi


## Transform from the model root down to the skeleton node.
func _skeleton_in_model() -> Transform3D:
	var xform := Transform3D.IDENTITY
	var node: Node3D = _skeleton
	while node != null and node != _model:
		xform = node.transform * xform
		node = node.get_parent() as Node3D
	return xform


## Fixes `item` to a bone so that, in the rest pose, it sits at `at` (model
## space, metres, +Z forward). Returns the bone attachment.
func _pin(bone: String, item: Node3D, at: Vector3, stretch := Vector3.ONE) -> Node3D:
	var index := _skeleton.find_bone(bone)
	if index < 0:
		item.free()
		return null
	var holder := BoneAttachment3D.new()
	holder.bone_name = bone
	_skeleton.add_child(holder)
	var wanted := Transform3D(Basis.from_scale(stretch), at)
	var bone_rest := _skeleton.get_bone_global_rest(index)
	item.transform = bone_rest.affine_inverse() * _skeleton_in_model().affine_inverse() * wanted
	holder.add_child(item)
	return holder


# --- level of detail ---------------------------------------------------------------------

var _far := false
var _mid := false        # 15-40 m: animation advanced every third frame
var _mid_acc := 0.0
var _mid_skip := 0


func set_mid(mid: bool) -> void:
	if mid == _mid or _player == null:
		return
	_mid = mid
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if mid else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
var _shape: BodyShape


## Far away (PC profiling: 60 animated walkers cost ~7 ms a frame): the pose
## freezes and the garment layer is dropped; up close everything comes back.
func set_far(far: bool) -> void:
	if far == _far or _player == null:
		return
	_far = far
	_player.active = not far
	if _shape:
		_shape.active = not far
	# The garment layer stays: the body under it has no clothed triangles any
	# more, so hiding it left far walkers as floating heads, hands and feet.


# --- animation -------------------------------------------------------------------------

## The name a clip actually has in the imported model, or "" if it is not
## there. Godot's importer strips a trailing "_Loop" from animation names
## (it reads it as a "please loop this" hint), so "Walk_Loop" in the file
## arrives as "Walk". Both spellings are accepted.
func _clip(wanted: String) -> String:
	if _player == null:
		return ""
	if _player.has_animation(wanted):
		return wanted
	var short := wanted.trim_suffix("_Loop")
	return short if _player.has_animation(short) else ""


func _play(clip: String, blend := 0.2, speed := 1.0) -> void:
	# The library's plain idle is a boxer's stance with fists up; standing about
	# in the street uses the relaxed talking idle instead.
	if clip == "Idle_Loop":
		clip = "Idle_Talking_Loop"
	var found := _clip(clip)
	if found == "":
		return
	if _current != found:
		_current = found
		_player.play(found, blend)
		# Not the whole street in step: start loops at a random point.
		if found.begins_with("Idle"):
			_player.seek(randf() * _player.current_animation_length, true)
	_player.speed_scale = speed


## speed in m/s picks and paces the gait.
func animate(delta: float, speed: float) -> void:
	if _mid and _player != null and not _far:
		_mid_acc += delta
		_mid_skip += 1
		if _mid_skip >= 3:
			_player.advance(_mid_acc)
			_mid_acc = 0.0
			_mid_skip = 0
	if _down:
		return
	if _busy_t > 0.0:
		_busy_t -= delta
		return
	if _shape:
		_shape.standing = speed < 0.25
	if speed < 0.25:
		_play(idle_clip, 0.25)
	elif speed < 3.0:
		_play("Walk_Loop", 0.2, clampf(speed / 1.45, 0.6, 1.8))
	elif speed < 6.5:
		_play("Jog_Fwd_Loop", 0.2, clampf(speed / 3.6, 0.8, 1.6))
	else:
		_play("Sprint_Loop", 0.15, clampf(speed / 6.5, 0.9, 1.4))


func swing() -> void:
	if _down:
		return
	_current = ""
	if _shape:
		_shape.standing = false
	_play("Punch_Jab" if randf() < 0.5 else "Punch_Cross", 0.08, 1.4)
	_busy_t = 0.45


## t > 0 knocks the person down (and keeps them there), 0 gets them back up.
func set_knockdown(t: float) -> void:
	if t > 0.0 and not _down:
		_down = true
		_current = ""
		_play("Death01", 0.1, 1.3)
	elif t <= 0.0 and _down:
		_down = false
		_busy_t = 0.0
		_play(idle_clip, 0.4)


## Returns a node to hang a carried object on: it rides the right hand and
## is upright when the arms are in the rest pose.
func hand() -> Node3D:
	var grip := Node3D.new()
	if _skeleton == null or _pin("hand_r", grip, Vector3(-0.78, 1.44, -0.02)) == null:
		return null
	return grip
