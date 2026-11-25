## The far city at night. Real lights and glowing lamp heads only carry a
## couple of hundred metres; beyond that a town at night is a field of
## small steady points. This draws every street lamp, a sample of lit
## windows and the red lamps on top of the towers as one tiny camera-facing
## sprite each. No light is cast and nothing is shaded, so tens of
## thousands of them cost about as much as one car.
##
## The idea is the well-known one from published breakdowns of how big
## open-world games draw a city at night: distant lights as point sprites.
##
## Each sprite keeps a size of a few pixels however far away it is, fades
## in with distance (close up, the real lamp and the lit window texture do
## the job) and follows DayNight.darkness.
class_name FarLights
extends MultiMeshInstance3D

const WINDOW_MIN_HEIGHT := 8.0     # metres; lower buildings are hidden behind others anyway
const WINDOW_EVERY := 90.0         # square metres of wall for one lit-window sprite
const BEACON_MIN_HEIGHT := 38.0    # towers this tall carry a red lamp
const STOREY := 3.1

const LAMP_GLOW := Color(1.0, 0.74, 0.42)
const WINDOW_GLOWS := [Color(1.0, 0.84, 0.58), Color(1.0, 0.92, 0.76), Color(0.72, 0.84, 1.0), Color(1.0, 0.7, 0.4)]
const BEACON_GLOW := Color(1.0, 0.08, 0.05)

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// 0 by day, 1 in the middle of the night.
uniform float night = 0.0;
// Closer than this the real lamp is doing the job; the sprite fades in beyond it.
uniform float near_fade = 70.0;
// Sprite width per metre of distance: keeps a far light a few pixels wide.
uniform float pixel = 0.004;
uniform float energy = 2.6;

varying float glow;

void vertex() {
	// INSTANCE_CUSTOM: x = width close up (m), y = brightness, z = 1 if it blinks, w = blink phase.
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = distance(centre, CAMERA_POSITION_WORLD);
	float width = max(INSTANCE_CUSTOM.x, dist * pixel);
	float blink = mix(1.0, step(0.55, fract(TIME * 0.7 + INSTANCE_CUSTOM.w)), INSTANCE_CUSTOM.z);
	glow = night * INSTANCE_CUSTOM.y * blink * smoothstep(near_fade, near_fade * 2.5, dist);
	// Face the camera: push the corner out in view space, not in the world.
	vec4 in_view = VIEW_MATRIX * vec4(centre, 1.0);
	in_view.xy += VERTEX.xy * width;
	POSITION = PROJECTION_MATRIX * in_view;
}

void fragment() {
	// A soft round dot: bright in the middle, gone at the edge of the quad.
	float from_middle = length(UV - vec2(0.5)) * 2.0;
	float dot_shape = pow(max(0.0, 1.0 - from_middle), 2.0);
	ALBEDO = COLOR.rgb * energy;
	ALPHA = dot_shape * glow;
}
"""

var _day_night: DayNight
var _look := ShaderMaterial.new()


## Collects the lights of the whole town once. `furniture` gives the lamp
## heads, `city` the buildings, `day_night` how dark it is.
func setup(city: CityBuilder, furniture: StreetFurniture, day_night: DayNight) -> void:
	_day_night = day_night
	var rng := RandomNumberGenerator.new()
	rng.seed = 2148

	var spots := PackedVector3Array()
	var tints := PackedColorArray()
	var facts := PackedColorArray()   # what the shader reads as INSTANCE_CUSTOM

	for head in furniture.all_lamp_heads():
		spots.append(head)
		tints.append(LAMP_GLOW)
		facts.append(Color(0.7, 1.0, 0.0, 0.0))

	for building: Dictionary in city.data.get("buildings", []):
		var height: float = building.h
		if height < WINDOW_MIN_HEIGHT or Landmarks.replaces(building):
			continue
		var ring: Array = building.pts
		var storeys := int(height / STOREY)
		var middle := Vector2.ZERO
		for i in ring.size():
			var a := Vector2(ring[i][0], ring[i][1])
			var c := Vector2(ring[(i + 1) % ring.size()][0], ring[(i + 1) % ring.size()][1])
			middle += a
			var edge := c - a
			var length := edge.length()
			if length < 3.0:
				continue
			# Same outward side as the walls themselves (see city_builder.gd).
			var out := Vector2(edge.y, -edge.x) / length
			var wanted := int(length * height / WINDOW_EVERY + rng.randf())
			for n in wanted:
				var along := a + edge * rng.randf_range(0.05, 0.95) + out * 0.35
				var floor_up := (rng.randi_range(1, maxi(1, storeys - 1)) + 0.55) * STOREY
				spots.append(Vector3(along.x, minf(floor_up, height - 1.0), along.y))
				tints.append(WINDOW_GLOWS[rng.randi() % WINDOW_GLOWS.size()])
				facts.append(Color(0.5, rng.randf_range(0.35, 0.8), 0.0, 0.0))
		if height >= BEACON_MIN_HEIGHT and ring.size() > 0:
			middle /= ring.size()
			spots.append(Vector3(middle.x, height + 2.0, middle.y))
			tints.append(BEACON_GLOW)
			facts.append(Color(1.2, 1.6, 1.0, rng.randf()))

	var dots := MultiMesh.new()
	dots.transform_format = MultiMesh.TRANSFORM_3D
	dots.use_colors = true
	dots.use_custom_data = true
	dots.mesh = QuadMesh.new()   # one metre square; the shader sizes and turns it
	dots.instance_count = spots.size()
	for i in spots.size():
		dots.set_instance_transform(i, Transform3D(Basis.IDENTITY, spots[i]))
		dots.set_instance_color(i, tints[i])
		dots.set_instance_custom_data(i, facts[i])
	multimesh = dots

	var shader := Shader.new()
	shader.code = SHADER
	_look.shader = shader
	material_override = _look
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func _process(_delta: float) -> void:
	if _day_night == null:
		return
	var dark := _day_night.darkness
	visible = dark > 0.02
	if visible:
		_look.set_shader_parameter("night", dark)
