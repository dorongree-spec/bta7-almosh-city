## Camera-lens look, after Adrian Courrèges' published "GTA V - Graphics Study":
## a slight barrel distortion with chromatic aberration that grows towards the
## frame edges, and a sprite sun flare (a glow and streak at the sun plus
## coloured ghosts along the sun-to-centre axis) that hides when a building
## covers the sun. Sits under the HUD, so text is never distorted.
class_name Lens
extends CanvasLayer

const LENS_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float aberration = 0.0018;
uniform float barrel = 0.025;
void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	float r2 = dot(c, c);
	vec2 uv = 0.5 + c * (1.0 + barrel * r2) / (1.0 + barrel * 0.5);
	vec2 off = c * aberration * r2 * 4.0;
	float r = texture(screen, uv + off).r;
	float g = texture(screen, uv).g;
	float b = texture(screen, uv - off * 0.7).b;
	COLOR = vec4(r, g, b, 1.0);
}
"""
## Ghosts along the axis: [position along sun->centre->beyond (0 = sun), radius px, colour].
const GHOSTS := [
	[0.35, 26.0, Color(1.0, 0.75, 0.4, 0.10)],
	[0.62, 14.0, Color(0.6, 1.0, 0.6, 0.10)],
	[1.15, 44.0, Color(0.5, 0.7, 1.0, 0.07)],
	[1.45, 18.0, Color(1.0, 0.5, 0.8, 0.09)],
	[1.8, 70.0, Color(0.9, 0.8, 0.5, 0.05)],
]

var sun: DirectionalLight3D
var _flare: Control
var _strength := 0.0


func _ready() -> void:
	layer = 0
	var post := ColorRect.new()
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = LENS_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	post.material = m
	add_child(post)
	_flare = Control.new()
	_flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flare.set_anchors_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flare.material = add
	_flare.draw.connect(_draw_flare)
	add_child(_flare)


func _process(delta: float) -> void:
	var want := _visible_strength()
	_strength = move_toward(_strength, want, delta * 3.0)
	_flare.queue_redraw()


## 0..1: how strongly the sun should flare right now.
func _visible_strength() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null or sun == null or not sun.visible or sun.light_energy < 0.2:
		return 0.0
	var to_sun := sun.global_transform.basis.z.normalized()  # lights shine along -Z
	if to_sun.y < 0.02:
		return 0.0
	var facing := (-cam.global_transform.basis.z).dot(to_sun)
	if facing < 0.6:
		return 0.0
	# Something solid between the camera and the sun puts the flare out.
	var space := cam.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + to_sun * 600.0))
	if not hit.is_empty():
		return 0.0
	return smoothstep(0.6, 0.95, facing) * clampf(sun.light_energy / 1.5, 0.0, 1.0)


func _draw_flare() -> void:
	if _strength < 0.01:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or sun == null:
		return
	var to_sun := sun.global_transform.basis.z.normalized()
	var p3 := cam.global_position + to_sun * 1000.0
	if cam.is_position_behind(p3):
		return
	var size := _flare.get_viewport_rect().size
	var at := cam.unproject_position(p3)
	var centre := size * 0.5
	var k := _strength
	# Glow and a horizontal anamorphic streak at the sun.
	for i in 4:
		_flare.draw_circle(at, 30.0 + i * 38.0, Color(1.0, 0.85, 0.6, 0.06 * k))
	_flare.draw_rect(Rect2(at.x - size.x * 0.35, at.y - 1.5, size.x * 0.7, 3.0), Color(1.0, 0.8, 0.6, 0.12 * k))
	for g in GHOSTS:
		var pos: Vector2 = at.lerp(centre, float(g[0]))
		var col: Color = g[2]
		_flare.draw_circle(pos, float(g[1]), Color(col.r, col.g, col.b, col.a * k))
